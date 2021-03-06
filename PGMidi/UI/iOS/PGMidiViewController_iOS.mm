//
//  MidiMonitorViewController.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PGMidiViewController_iOS.h"

#import "PGMidi.h"
#import <CoreMIDI/CoreMIDI.h>

UInt8 RandomNoteNumber() { return UInt8(rand() / (RAND_MAX / 127)); }

@interface PGMidiViewController_iOS () <PGMidiDelegate, PGMidiSourceDelegate>
- (void) updateCountLabel;
- (void) addString:(NSString*)string;
- (void) sendMidiDataInBackground;
@end

@implementation PGMidiViewController_iOS

#pragma mark UIViewController

- (void)viewWillAppear:(BOOL)animated
{
    [self clearTextView];
    [self updateCountLabel];
}

#pragma mark IBActions

- (IBAction)clearTextView
{
    _textView.text = nil;
}

- (IBAction)listAllInterfaces
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

- (IBAction)sendMidiData
{
    [self performSelectorInBackground:@selector(sendMidiDataInBackground) withObject:nil];
}

#pragma mark Shenanigans

- (void)attachToAllExistingSources
{
    for (PGMidiSource *source in _midi.sources)
    {
        [source addDelegate:self];
    }
}

- (void)setMidi:(PGMidi*)m
{
    _midi.delegate = nil;
    _midi = m;
    _midi.delegate = self;

    [self attachToAllExistingSources];
}

- (void)addString:(NSString*)string
{
    NSString *newText = [_textView.text stringByAppendingFormat:@"\n%@", string];
    _textView.text = newText;

    if (newText.length) {
        [_textView scrollRangeToVisible:(NSRange){newText.length-1, 1}];
    }
}

- (void)updateCountLabel
{
    _countLabel.text = [NSString stringWithFormat:@"sources=%u destinations=%u"
                       , (unsigned)_midi.sources.count
                       , (unsigned)_midi.destinations.count];
}

- (void)midi:(PGMidi*)midi sourceAdded:(PGMidiSource *)source
{
    [source addDelegate:self];
    [self updateCountLabel];
    [self addString:[NSString stringWithFormat:@"Source added: %@", source]];
}

- (void)midi:(PGMidi*)midi sourceRemoved:(PGMidiSource *)source
{
    [self updateCountLabel];
    [self addString:[NSString stringWithFormat:@"Source removed: %@", source]];
}

- (void)midi:(PGMidi*)midi destinationAdded:(PGMidiDestination *)destination
{
    [self updateCountLabel];
    [self addString:[NSString stringWithFormat:@"Desintation added: %@", destination]];
}

- (void)midi:(PGMidi*)midi destinationRemoved:(PGMidiDestination *)destination
{
    [self updateCountLabel];
    [self addString:[NSString stringWithFormat:@"Desintation removed: %@", destination]];
}

NSString *StringFromPacket(const MIDIPacket *packet)
{
    // Note - this is not an example of MIDI parsing. I'm just dumping
    // some bytes for diagnostics.
    // See comments in PGMidiSourceDelegate for an example of how to
    // interpret the MIDIPacket structure.
    return [NSString stringWithFormat:@"  %u bytes: [%02x,%02x,%02x]",
            packet->length,
            (packet->length > 0) ? packet->data[0] : 0,
            (packet->length > 1) ? packet->data[1] : 0,
            (packet->length > 2) ? packet->data[2] : 0
           ];
}

- (void)midiSource:(PGMidiSource*)midi midiReceived:(const MIDIPacketList *)packetList
{
    [self performSelectorOnMainThread:@selector(addString:)
                           withObject:@"MIDI received:"
                        waitUntilDone:NO];

    const MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
        [self performSelectorOnMainThread:@selector(addString:)
                               withObject:StringFromPacket(packet)
                            waitUntilDone:NO];
        packet = MIDIPacketNext(packet);
    }
}

- (void)sendMidiDataInBackground
{
    for (int n = 0; n < 20; ++n)
    {
        const UInt8 note      = RandomNoteNumber();
        const UInt8 noteOn[]  = { 0x90, note, 127 };
        const UInt8 noteOff[] = { 0x80, note, 0   };

        [_midi sendBytes:noteOn size:sizeof(noteOn)];
        [NSThread sleepForTimeInterval:0.1];
        [_midi sendBytes:noteOff size:sizeof(noteOff)];
    }
}

@end
