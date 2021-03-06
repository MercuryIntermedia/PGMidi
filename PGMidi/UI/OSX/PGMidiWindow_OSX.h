//
//  MidiMonitorOSXWindow.h
//  PGMidi
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import <Cocoa/Cocoa.h>
#import "PGMidi.h"

@class HgSampler;

@interface PGMidiWindow_OSX : NSWindow <PGMidiDelegate, PGMidiSourceDelegate>

@property (nonatomic, weak) IBOutlet NSTextField *countTextField;
@property (nonatomic, strong) IBOutlet NSTextView *textView;

@property (nonatomic, strong) PGMidi *midi;

- (IBAction)clearTextView:(id)sender;
- (IBAction)listAllInterfaces:(id)sender;
- (IBAction)sendMidiData:(id)sender;

@end
