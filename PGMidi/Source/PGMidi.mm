//
//  PGMidi.m
//  PGMidi
//

#import "PGMidi.h"
#import <mach/mach_time.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    #import <CoreMIDI/MIDINetworkSession.h>
#endif

/// A helper that NSLogs an error message if "c" is an error code
#define NSLogError(c,str) do{if (c) NSLog(@"Error (%@): %ld:%@", str, (long)c,[NSError errorWithDomain:NSMachErrorDomain code:c userInfo:nil]);}while(false)

NSString * const PGMidiSourceAddedNotification        = @"PGMidiSourceAddedNotification";
NSString * const PGMidiSourceRemovedNotification      = @"PGMidiSourceRemovedNotification";
NSString * const PGMidiDestinationAddedNotification   = @"PGMidiDestinationAddedNotification";
NSString * const PGMidiDestinationRemovedNotification = @"PGMidiDestinationRemovedNotification";
NSString * const PGMidiConnectionKey                  = @"connection";

//==============================================================================

static void PGMIDINotifyProc(const MIDINotification *message, void *refCon);
static void PGMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
static void PGMIDIVirtualDestinationReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

@interface PGMidi ()
- (void) scanExistingDevices;
- (MIDIPortRef) outputPort;
@property (nonatomic, strong) NSTimer *rescanTimer;
@end

//==============================================================================

static
NSString *NameOfEndpoint(MIDIEndpointRef ref)
{
    CFStringRef string = nil;
    OSStatus s = MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, ( CFStringRef*)&string);
    if ( s != noErr ) 
    {
        return @"Unknown name";
    }
    return (NSString*)CFBridgingRelease(string);
}

static
BOOL IsNetworkSession(MIDIEndpointRef ref)
{
    MIDIEntityRef entity = 0;
    MIDIEndpointGetEntity(ref, &entity);

    BOOL hasMidiRtpKey = NO;
    CFPropertyListRef properties = nil;
    OSStatus s = MIDIObjectGetProperties(entity, &properties, true);
    if (!s)
    {
        NSDictionary *dictionary = (__bridge NSDictionary *)properties;
        hasMidiRtpKey = [dictionary valueForKey:@"apple.midirtp.session"] != nil;
        CFRelease(properties);
    }

    return hasMidiRtpKey;
}

//==============================================================================

@implementation PGMidiConnection

- (id)initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    self = [super init];
    if (self) {
        _midi = m;
        _endpoint = e;
        _name = NameOfEndpoint(e);
        _isNetworkSession = IsNetworkSession(e);
    }
    return self;
}

- (NSString *)description
{
    NSString *isNetwork = _isNetworkSession ? @"yes" : @"no";
    return [NSString stringWithFormat:@"< PGMidiConnection: name=%@ isNetwork=%@ >", _name, isNetwork];
}

@end

//==============================================================================

@interface PGMidiSource ()
@property (strong, nonatomic, readwrite) NSHashTable *delegates;
@end

@implementation PGMidiSource

- (id)initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    self = [super initWithMidi:m endpoint:e];
    if (self) {
        self.delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return self;
}

- (void)addDelegate:(id<PGMidiSourceDelegate>)delegate
{
    if (![_delegates containsObject:delegate]) {
        [_delegates addObject:delegate];
    }
}

- (void)removeDelegate:(id<PGMidiSourceDelegate>)delegate
{
    [_delegates removeObject:delegate];
}

// NOTE: Called on a separate high-priority thread, not the main runloop
- (void)midiRead:(const MIDIPacketList *)pktlist
{
    NSHashTable *delegates = self.delegates;
    for (id<PGMidiSourceDelegate> delegate in delegates) {
        [delegate midiSource:self midiReceived:pktlist];
    }
}

static
void PGMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    @autoreleasepool
    {
        PGMidiSource *self = (__bridge PGMidiSource *)srcConnRefCon;
        [self midiRead:pktlist];
    }
}

static
void PGMIDIVirtualDestinationReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    @autoreleasepool
    {
        PGMidi *midi = (__bridge PGMidi*)readProcRefCon;
        PGMidiSource *self = midi.virtualDestinationSource;
        [self midiRead:pktlist];
    }
}

@end

//==============================================================================

@implementation PGMidiDestination

-(void)flushOutput
{
    MIDIFlushOutput(self.endpoint);
}

- (void)sendBytes:(const UInt8*)bytes size:(UInt32)size
{
    assert(size < 65536);
    Byte packetBuffer[size+100];
    MIDIPacketList *packetList = (MIDIPacketList*)packetBuffer;
    MIDIPacket *packet = MIDIPacketListInit(packetList);
    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, size, bytes);

    [self sendPacketList:packetList];
}

- (void)sendPacketList:(MIDIPacketList *)packetList
{
    // Send it
    OSStatus s = MIDISend(self.midi.outputPort, self.endpoint, packetList);
    NSLogError(s, @"Sending MIDI");
}

@end

//==============================================================================

@interface PGMidiVirtualSourceDestination : PGMidiDestination
@end

@implementation PGMidiVirtualSourceDestination

- (void) sendPacketList:(MIDIPacketList *)packetList
{
    // Assign proper timestamps to packetList
    MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; i++) {
        if ( packet->timeStamp == 0 ) {
            packet->timeStamp = mach_absolute_time();
        }
        packet = MIDIPacketNext(packet);
    }

    // Send it
    OSStatus s = MIDIReceived(self.endpoint, packetList);
    NSLogError(s, @"Sending MIDI");
}

@end

//==============================================================================

@implementation PGMidi

@dynamic networkEnabled;

- (id) init
{
    self = [super init];
    if (self) {
        _sources      = [NSMutableArray new];
        _destinations = [NSMutableArray new];

        OSStatus s = MIDIClientCreate((CFStringRef)@"PGMidi MIDI Client", PGMIDINotifyProc, (__bridge void *)self, &_client);
        NSLogError(s, @"Create MIDI client");

        s = MIDIOutputPortCreate(_client, (CFStringRef)@"PGMidi Output Port", &_outputPort);
        NSLogError(s, @"Create output MIDI port");

        s = MIDIInputPortCreate(_client, (CFStringRef)@"PGMidi Input Port", PGMIDIReadProc, (__bridge void *)self, &_inputPort);
        NSLogError(s, @"Create input MIDI port");

        [self scanExistingDevices];
        
        self.rescanTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(scanExistingDevices) userInfo:nil repeats:YES];
    }

    return self;
}

- (void)dealloc
{
    [_rescanTimer invalidate];
    self.rescanTimer = nil;
    
    if (_outputPort) {
        OSStatus s = MIDIPortDispose(_outputPort);
        NSLogError(s, @"Dispose MIDI port");
    }

    if (_inputPort) {
        OSStatus s = MIDIPortDispose(_inputPort);
        NSLogError(s, @"Dispose MIDI port");
    }

    if (_client) {
        OSStatus s = MIDIClientDispose(_client);
        NSLogError(s, @"Dispose MIDI client");
    }
    
    self.virtualEndpointName = nil;
    self.virtualSourceEnabled = NO;
    self.virtualDestinationEnabled = NO;
}

- (NSUInteger)numberOfConnections
{
    return _sources.count + _destinations.count;
}

- (MIDIPortRef)outputPort
{
    return _outputPort;
}

-(BOOL)networkEnabled
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    return [MIDINetworkSession defaultSession].enabled;
#else
    return NO;
#endif
}

-(void)setNetworkEnabled:(BOOL)networkEnabled
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    session.enabled = networkEnabled;
    session.connectionPolicy = MIDINetworkConnectionPolicy_Anyone;
#else
    NSLog(@"MIDINetworkSession not available on Mac OS X");
#endif
}

-(BOOL)virtualSourceEnabled
{
    return _virtualSourceDestination != nil;
}

-(void)setVirtualSourceEnabled:(BOOL)virtualSourceEnabled
{
    if (virtualSourceEnabled == self.virtualSourceEnabled) {
        return;
    }
    
    if (virtualSourceEnabled) {
        OSStatus s = MIDISourceCreate(_client, (__bridge CFStringRef)@"PGMidi Source", &_virtualSourceEndpoint);
        NSLogError(s, @"Create MIDI virtual source");
        if (s) {
            return;
        }
        
        _virtualSourceDestination = [[PGMidiVirtualSourceDestination alloc] initWithMidi:self endpoint:_virtualSourceEndpoint];

        [_delegate midi:self destinationAdded:_virtualSourceDestination];
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationAddedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:_virtualSourceDestination
                                                                                               forKey:PGMidiConnectionKey]];
        
    } else {
        [_delegate midi:self destinationRemoved:_virtualSourceDestination];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:_virtualSourceDestination
                                                                                               forKey:PGMidiConnectionKey]];

        OSStatus s = MIDIEndpointDispose(_virtualSourceEndpoint);
        NSLogError(s, @"Dispose MIDI virtual source");
        _virtualSourceEndpoint = 0;
    }
}

-(BOOL)virtualDestinationEnabled
{
    return (_virtualDestinationSource != nil);
}

-(void)setVirtualDestinationEnabled:(BOOL)virtualDestinationEnabled
{
    if (virtualDestinationEnabled == self.virtualDestinationEnabled) {
        return;
    }
    
    if (virtualDestinationEnabled) {
        OSStatus s = MIDIDestinationCreate(_client, (__bridge CFStringRef)@"PGMidi Destination", PGMIDIVirtualDestinationReadProc, (__bridge void*)self, &_virtualDestinationEndpoint);
        NSLogError(s, @"Create MIDI virtual destination");
        if (s) {
            return;
        }
        
        // Attempt to use saved unique ID
        SInt32 uniqueID = (SInt32)[[NSUserDefaults standardUserDefaults] integerForKey:@"PGMIDI Saved Virtual Destination ID"];
        if (uniqueID) {
            s = MIDIObjectSetIntegerProperty(_virtualDestinationEndpoint, kMIDIPropertyUniqueID, uniqueID);
            if (s == kMIDIIDNotUnique) {
                uniqueID = 0;
            }
        }
        // Save the ID
        if (!uniqueID) {
            s = MIDIObjectGetIntegerProperty(_virtualDestinationEndpoint, kMIDIPropertyUniqueID, &uniqueID);
            NSLogError(s, @"Get MIDI virtual destination ID");
            if (s == noErr) {
                [[NSUserDefaults standardUserDefaults] setInteger:uniqueID forKey:@"PGMIDI Saved Virtual Destination ID"];
            }
        }
        
        _virtualDestinationSource = [[PGMidiSource alloc] initWithMidi:self endpoint:_virtualDestinationEndpoint];

        [_delegate midi:self sourceAdded:_virtualDestinationSource];
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceAddedNotification
                                                            object:self
                                                          userInfo:[NSDictionary dictionaryWithObject:_virtualDestinationSource
                                                                                               forKey:PGMidiConnectionKey]];
    } else {
        [_delegate midi:self sourceRemoved:_virtualDestinationSource];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:_virtualDestinationSource
                                                                                               forKey:PGMidiConnectionKey]];

        OSStatus s = MIDIEndpointDispose(_virtualDestinationEndpoint);
        NSLogError(s, @"Dispose MIDI virtual destination");
        virtualDestinationEnabled = NO;
    }
}


//==============================================================================
#pragma mark Connect/disconnect

- (PGMidiSource*)getSource:(MIDIEndpointRef)source
{
    for (PGMidiSource *s in _sources) {
        if (s.endpoint == source) {
            return s;
        }
    }
    return nil;
}

- (PGMidiDestination*)getDestination:(MIDIEndpointRef)destination
{
    for (PGMidiDestination *d in _destinations) {
        if (d.endpoint == destination) {
            return d;
        }
    }
    return nil;
}

- (void)connectSource:(MIDIEndpointRef)endpoint
{
    PGMidiSource *source = [[PGMidiSource alloc] initWithMidi:self endpoint:endpoint];
    [_sources addObject:source];
    [_delegate midi:self sourceAdded:source];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceAddedNotification
                                                        object:self 
                                                      userInfo:[NSDictionary dictionaryWithObject:source 
                                                                                           forKey:PGMidiConnectionKey]];
    
    OSStatus s = MIDIPortConnectSource(_inputPort, endpoint, (__bridge void *)source);
    NSLogError(s, @"Connecting to MIDI source");
}

- (void)disconnectSource:(MIDIEndpointRef)endpoint
{
    PGMidiSource *source = [self getSource:endpoint];

    if (source) {
        OSStatus s = MIDIPortDisconnectSource(_inputPort, endpoint);
        NSLogError(s, @"Disconnecting from MIDI source");
        [_sources removeObject:source];
        
        [_delegate midi:self sourceRemoved:source];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:source 
                                                                                               forKey:PGMidiConnectionKey]];
    }
}

- (void)connectDestination:(MIDIEndpointRef)endpoint
{
    PGMidiDestination *destination = [[PGMidiDestination alloc] initWithMidi:self endpoint:endpoint];
    [_destinations addObject:destination];
    [_delegate midi:self destinationAdded:destination];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationAddedNotification
                                                        object:self 
                                                      userInfo:[NSDictionary dictionaryWithObject:destination 
                                                                                           forKey:PGMidiConnectionKey]];
}

- (void) disconnectDestination:(MIDIEndpointRef)endpoint
{
    PGMidiDestination *destination = [self getDestination:endpoint];

    if (destination) {
        [_destinations removeObject:destination];
        
        [_delegate midi:self destinationRemoved:destination];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:destination 
                                                                                               forKey:PGMidiConnectionKey]];
    }
}

- (void) scanExistingDevices
{
    const ItemCount numberOfDestinations = MIDIGetNumberOfDestinations();
    const ItemCount numberOfSources      = MIDIGetNumberOfSources();

    NSMutableArray *removedSources       = [NSMutableArray arrayWithArray:_sources];
    NSMutableArray *removedDestinations  = [NSMutableArray arrayWithArray:_destinations];
    
    for (ItemCount index = 0; index < numberOfDestinations; ++index) {
        MIDIEndpointRef endpoint = MIDIGetDestination(index);
        if (endpoint == _virtualDestinationEndpoint) {
            continue;
        }
        
        BOOL matched = NO;
        for (PGMidiDestination *destination in _destinations) {
            if (destination.endpoint == endpoint) {
                [removedDestinations removeObject:destination];
                matched = YES;
                break;
            }
        }
        if (matched) {
            continue;
        }
        
        [self connectDestination:endpoint];
    }
    
    for (ItemCount index = 0; index < numberOfSources; ++index) {
        MIDIEndpointRef endpoint = MIDIGetSource(index);
        if (endpoint == _virtualSourceEndpoint) {
            continue;
        }
        
        BOOL matched = NO;
        for (PGMidiDestination *source in _sources) {
            if (source.endpoint == endpoint) {
                [removedSources removeObject:source];
                matched = YES;
                break;
            }
        }
        if (matched) {
            continue;
        }
        
        [self connectSource:endpoint];
    }
    
    for (PGMidiDestination *destination in removedDestinations) {
        [self disconnectDestination:destination.endpoint];
    }
    
    for (PGMidiSource *source in removedSources) {
        [self disconnectSource:source.endpoint];
    }
}

//==============================================================================
#pragma mark Notifications

- (void)midiNotifyAdd:(const MIDIObjectAddRemoveNotification *)notification
{
    if (notification->child == _virtualDestinationEndpoint || notification->child == _virtualSourceEndpoint) {
        return;
    }
    
    if (notification->childType == kMIDIObjectType_Destination) {
        [self connectDestination:(MIDIEndpointRef)notification->child];
    } else if (notification->childType == kMIDIObjectType_Source) {
        [self connectSource:(MIDIEndpointRef)notification->child];
    }
}

- (void)midiNotifyRemove:(const MIDIObjectAddRemoveNotification *)notification
{
    if (notification->child == _virtualDestinationEndpoint || notification->child == _virtualSourceEndpoint) {
        return;
    }
    
    if (notification->childType == kMIDIObjectType_Destination) {
        [self disconnectDestination:(MIDIEndpointRef)notification->child];
    } else if (notification->childType == kMIDIObjectType_Source) {
        [self disconnectSource:(MIDIEndpointRef)notification->child];
    }
}

- (void)midiNotify:(const MIDINotification*)notification
{
    switch(notification->messageID)
    {
        case kMIDIMsgObjectAdded:
            [self midiNotifyAdd:(const MIDIObjectAddRemoveNotification *)notification];
            break;
        case kMIDIMsgObjectRemoved:
            [self midiNotifyRemove:(const MIDIObjectAddRemoveNotification *)notification];
            break;
        case kMIDIMsgSetupChanged:
        case kMIDIMsgPropertyChanged:
        case kMIDIMsgThruConnectionsChanged:
        case kMIDIMsgSerialPortOwnerChanged:
        case kMIDIMsgIOError:
            break;
    }
}

void PGMIDINotifyProc(const MIDINotification *message, void *refCon)
{
    PGMidi *self = (__bridge PGMidi *)refCon;
    [self midiNotify:message];
}

//==============================================================================
#pragma mark MIDI Output

- (void)sendPacketList:(const MIDIPacketList *)packetList
{
    for (ItemCount index = 0; index < MIDIGetNumberOfDestinations(); ++index) {
        MIDIEndpointRef outputEndpoint = MIDIGetDestination(index);
        if (outputEndpoint) {
            // Send it
            OSStatus s = MIDISend(_outputPort, outputEndpoint, packetList);
            NSLogError(s, @"Sending MIDI");
        }
    }
}

- (void)sendBytes:(const UInt8*)data size:(UInt32)size
{
    NSLog(@"%s(%u bytes to core MIDI)", __func__, unsigned(size));
    assert(size < 65536);
    Byte packetBuffer[size+100];
    MIDIPacketList *packetList = (MIDIPacketList*)packetBuffer;
    MIDIPacket *packet = MIDIPacketListInit(packetList);

    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, size, data);

    [self sendPacketList:packetList];
}

@end
