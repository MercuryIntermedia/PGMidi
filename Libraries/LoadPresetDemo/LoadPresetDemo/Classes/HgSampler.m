//
//  HgSampler.m
//  LoadPresetDemo
//
//  Created by Demetri Miller on 3/17/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

#import <AssertMacros.h>
#import "HgSampler.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import "HgSampler_iOS.h"
#endif

// some MIDI constants:
enum {
    kHgSamplerMIDIMessage_NoteOff = 0x8,
};


@implementation HgSampler
{
    AUGraph _processingGraph;
    AudioUnit _samplerUnit;
    AudioUnit _ioUnit;
}


#pragma mark - Lifecycle
+ (instancetype)sampler
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    return [[HgSampler_iOS alloc] init];
#else
    return [[HgSampler alloc] init];
#endif
}

- (id)init
{
    self = [super init];
    if (self) {
        BOOL audioSessionActivated = [self setupAudioSession];
        NSAssert (audioSessionActivated == YES, @"Unable to set up audio session.");

        [self createAUGraph];
        [self configureAndStartAudioProcessingGraph:_processingGraph];
    }
    return self;
}

- (void)dealloc
{
    [self stopAudioProcessingGraph];
}


#pragma mark - Audio Setup
- (OSStatus)loadPresetWithName:(NSString *)name
{
    NSURL *presetURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:name ofType:@"aupreset"]];
    if (presetURL) {
        NSLog(@"Attempting to load preset '%@'\n", [presetURL description]);
    }
    else {
        NSLog(@"COULD NOT GET PRESET PATH!");
    }
    
    return [self loadSynthFromPresetURL:presetURL];
}

// Load a synthesizer preset file and apply it to the Sampler unit
- (OSStatus)loadSynthFromPresetURL:(NSURL *)presetURL
{
    CFDataRef propertyResourceData = 0;
    Boolean status;
    SInt32 errorCode = 0;
    OSStatus result = noErr;
    
    // Read from the URL and convert into a CFData chunk
    status = CFURLCreateDataAndPropertiesFromResource (
                                                       kCFAllocatorDefault,
                                                       (__bridge CFURLRef) presetURL,
                                                       &propertyResourceData,
                                                       NULL,
                                                       NULL,
                                                       &errorCode
                                                       );
    
    NSAssert (status == YES && propertyResourceData != 0, @"Unable to create data and properties from a preset. Error code: %d '%.4s'", (int) errorCode, (const char *)&errorCode);
   	
    // Convert the data object into a property list
    CFPropertyListRef presetPropertyList = 0;
    CFPropertyListFormat dataFormat = 0;
    CFErrorRef errorRef = 0;
    presetPropertyList = CFPropertyListCreateWithData (
                                                       kCFAllocatorDefault,
                                                       propertyResourceData,
                                                       kCFPropertyListImmutable,
                                                       &dataFormat,
                                                       &errorRef
                                                       );
    
    // Set the class info property for the Sampler unit using the property list as the value.
    if (presetPropertyList != 0) {
        
        result = AudioUnitSetProperty(
                                      _samplerUnit,
                                      kAudioUnitProperty_ClassInfo,
                                      kAudioUnitScope_Global,
                                      0,
                                      &presetPropertyList,
                                      sizeof(CFPropertyListRef)
                                      );
        
        CFRelease(presetPropertyList);
    }
    
    if (errorRef) CFRelease(errorRef);
    CFRelease (propertyResourceData);
    
    return result;
}

// Create an audio processing graph.
- (BOOL)createAUGraph
{
    OSStatus result = noErr;
    AUNode samplerNode, ioNode;
    
    // Specify the common portion of an audio unit's identify, used for both audio units
    // in the graph.
    AudioComponentDescription cd = {};
    cd.componentManufacturer     = kAudioUnitManufacturer_Apple;
    cd.componentFlags            = 0;
    cd.componentFlagsMask        = 0;
    
    // Instantiate an audio processing graph
    result = NewAUGraph (&_processingGraph);
    NSCAssert (result == noErr, @"Unable to create an AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    //Specify the Sampler unit, to be used as the first node of the graph
    cd.componentType = kAudioUnitType_MusicDevice;
    cd.componentSubType = kAudioUnitSubType_Sampler;
    
    // Add the Sampler unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &samplerNode);
    NSCAssert (result == noErr, @"Unable to add the Sampler unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Specify the Output unit, to be used as the second and final node of the graph
    cd.componentType = kAudioUnitType_Output;

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    cd.componentSubType = kAudioUnitSubType_RemoteIO;
#else
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
    
    // Add the Output unit node to the graph
    result = AUGraphAddNode (_processingGraph, &cd, &ioNode);
    NSCAssert (result == noErr, @"Unable to add the Output unit to the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Open the graph
    result = AUGraphOpen (_processingGraph);
    NSCAssert (result == noErr, @"Unable to open the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Connect the Sampler unit to the output unit
    result = AUGraphConnectNodeInput (_processingGraph, samplerNode, 0, ioNode, 0);
    NSCAssert (result == noErr, @"Unable to interconnect the nodes in the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain a reference to the Sampler unit from its node
    result = AUGraphNodeInfo (_processingGraph, samplerNode, 0, &_samplerUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the Sampler unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain a reference to the I/O unit from its node
    result = AUGraphNodeInfo (_processingGraph, ioNode, 0, &_ioUnit);
    NSCAssert (result == noErr, @"Unable to obtain a reference to the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    return YES;
}

// Starting with instantiated audio processing graph, configure its
// audio units, initialize it, and start it.
- (void)configureAndStartAudioProcessingGraph:(AUGraph)graph
{
    OSStatus result = noErr;
    UInt32 framesPerSlice = 0;
    UInt32 framesPerSlicePropertySize = sizeof(framesPerSlice);
    UInt32 sampleRatePropertySize = sizeof(_graphSampleRate);
    
    result = AudioUnitInitialize(_ioUnit);
    NSCAssert (result == noErr, @"Unable to initialize the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Set the I/O unit's output sample rate.
    result =    AudioUnitSetProperty (
                                      _ioUnit,
                                      kAudioUnitProperty_SampleRate,
                                      kAudioUnitScope_Output,
                                      0,
                                      &_graphSampleRate,
                                      sampleRatePropertySize
                                      );
    
    NSAssert (result == noErr, @"AudioUnitSetProperty (set Sampler unit output stream sample rate). Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Obtain the value of the maximum-frames-per-slice from the I/O unit.
    result =    AudioUnitGetProperty (
                                      _ioUnit,
                                      kAudioUnitProperty_MaximumFramesPerSlice,
                                      kAudioUnitScope_Global,
                                      0,
                                      &framesPerSlice,
                                      &framesPerSlicePropertySize
                                      );
    
    NSCAssert (result == noErr, @"Unable to retrieve the maximum frames per slice property from the I/O unit. Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Set the Sampler unit's output sample rate.
    result =    AudioUnitSetProperty (
                                      _samplerUnit,
                                      kAudioUnitProperty_SampleRate,
                                      kAudioUnitScope_Output,
                                      0,
                                      &_graphSampleRate,
                                      sampleRatePropertySize
                                      );
    
    NSAssert (result == noErr, @"AudioUnitSetProperty (set Sampler unit output stream sample rate). Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    // Set the Sampler unit's maximum frames-per-slice.
    result =    AudioUnitSetProperty (
                                      _samplerUnit,
                                      kAudioUnitProperty_MaximumFramesPerSlice,
                                      kAudioUnitScope_Global,
                                      0,
                                      &framesPerSlice,
                                      framesPerSlicePropertySize
                                      );
    
    NSAssert( result == noErr, @"AudioUnitSetProperty (set Sampler unit maximum frames per slice). Error code: %d '%.4s'", (int) result, (const char *)&result);
    
    
    if (graph) {
        
        // Initialize the audio processing graph.
        result = AUGraphInitialize (graph);
        NSAssert (result == noErr, @"Unable to initialze AUGraph object. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Start the graph
        result = AUGraphStart (graph);
        NSAssert (result == noErr, @"Unable to start audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
        
        // Print out the graph to the console
        CAShow (graph); 
    }
}

// Set up the audio session for this app.
- (BOOL)setupAudioSession
{
    _graphSampleRate = 44100.0;    // Hertz
    return YES;
}

- (void)stopAudioProcessingGraph
{
    OSStatus result = noErr;
    if (_processingGraph) {
        result = AUGraphStop(_processingGraph);
    }
    NSAssert (result == noErr, @"Unable to stop the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
}

- (void)restartAudioProcessingGraph
{
    OSStatus result = noErr;
    if (_processingGraph) {
        result = AUGraphStart(_processingGraph);
    }
    NSAssert (result == noErr, @"Unable to restart the audio processing graph. Error code: %d '%.4s'", (int) result, (const char *)&result);
}


#pragma mark - Playback
- (void)playMIDIWithStatus:(UInt32)status data1:(UInt32)data1 data2:(UInt32)data2
{
    OSStatus result = noErr;
    require_noerr (result = MusicDeviceMIDIEvent(_samplerUnit, status, data1, data2, 0), logTheError);
    
logTheError:
    if (result != noErr) {
        NSLog (@"Unable to stop playing the high note. Error code: %d '%.4s'", (int) result, (const char *)&result);
    }
}

- (void)playMIDIPacket:(const MIDIPacket *)packet
{
    UInt32 status = 0;
    UInt32 data1 = 0;
    UInt32 data2 = 0;
    for (NSInteger i = 0; ((i < sizeof(packet->data)) && (packet->data[i] != 0)); i++) {
        Byte byte = packet->data[i];
        switch (i) {
            case 0: status = byte; break;
            case 1: data1  = byte; break;
            case 2: data2  = byte; break;
                
            default:
                break;
        }
    }
    
    [self playMIDIWithStatus:status data1:data1 data2:data2];
}

- (void)sendStopPlaybackMessage
{
    [self playMIDIWithStatus:kHgSamplerMIDIMessage_NoteOff data1:0 data2:0];
}

@end
