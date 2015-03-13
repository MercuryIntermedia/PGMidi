//
//  PGMidiAllSources.mm
//  PGMidi
//

#import "PGMidiAllSources.h"

#import "PGMidi.h"

@interface PGMidiAllSources () <PGMidiDelegate, PGMidiSourceDelegate>
@end

@implementation PGMidiAllSources

- (void) dealloc
{
    self.midi = nil;
}

- (void) setMidi:(PGMidi *)newMidi
{
    _midi.delegate = nil;
    for (PGMidiSource *source in _midi.sources) [source removeDelegate:self];

    _midi = newMidi;

    _midi.delegate = self;
    for (PGMidiSource *source in _midi.sources) [source addDelegate:self];
}

#pragma mark PGMidiDelegate

- (void) midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source
{
    [source addDelegate:self];
}

- (void) midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source {}
- (void) midi:(PGMidi*)midi destinationAdded:(PGMidiDestination *)destination {}
- (void) midi:(PGMidi*)midi destinationRemoved:(PGMidiDestination *)destination {}

#pragma mark PGMidiSourceDelegate

- (void) midiSource:(PGMidiSource*)input midiReceived:(const MIDIPacketList *)packetList
{
    [_delegate midiSource:input midiReceived:packetList];
}

@end
