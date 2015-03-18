//
//  MidiMonitorOSXWindow.m
//  PGMidi
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import <CoreMIDI/CoreMIDI.h>
#import "MidiMonitorOSXWindow.h"

@implementation MidiMonitorOSXWindow

#pragma mark - Getters/Setters
- (void)setMidi:(PGMidi *)midi
{
    _midi = midi;
    _midi.delegate = self;
    for (PGMidiSource *source in _midi.sources) {
        [source addDelegate:self];
    }
}


#pragma mark - Actions
- (IBAction)clearTextView:(id)sender
{
    _textView.string = @"";
}

- (IBAction)listAllInterfaces:(id)sender
{
    [self addString:@"\n\nInterface list:"];
    for (PGMidiSource *source in _midi.sources)
    {
        NSString *description = [NSString stringWithFormat:@"Source: %@", source];
        [self addString:description];
    }
    [self addString:@""];
    for (PGMidiDestination *destination in _midi.destinations)
    {
        NSString *description = [NSString stringWithFormat:@"Destination: %@", destination];
        [self addString:description];
    }
}

- (IBAction)sendMidiData:(id)sender
{
    
}


#pragma mark - Helpers
- (void)addString:(NSString*)string
{
    NSString *newText = [_textView.string stringByAppendingFormat:@"\n%@", string];
    _textView.string = newText;
    
    if (newText.length) {
        [_textView scrollRangeToVisible:(NSRange){newText.length-1, 1}];
    }
}

- (void)handlePacket:(const MIDIPacket *)packet
{
    NSMutableString *string = [[NSMutableString alloc] initWithString:@"MIDI Received: "];
    for (NSInteger i = 0; ((i < sizeof(packet->data)) && (packet->data[i] != 0)); i++) {
        Byte byte = packet->data[i];
        [string appendFormat:@"0x%02x  ", byte];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self addString:string];
    });
}

#pragma mark - PGMidiDelegate
- (void)midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source
{
    [source addDelegate:self];
}

- (void)midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source
{
    [source removeDelegate:self];
}

- (void)midi:(PGMidi *)midi destinationAdded:(PGMidiDestination *)destination {}
- (void)midi:(PGMidi *)midi destinationRemoved:(PGMidiDestination *)destination {}


#pragma mark - PGMidiSourceDelegate
- (void)midiSource:(PGMidiSource *)input midiReceived:(const MIDIPacketList *)packetList
{
    const MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i) {
        [self handlePacket:packet];
        packet = MIDIPacketNext(packet);
    }
}

@end
