//
//  AppDelegate.h
//  MidiMonitor-OSX
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import <Cocoa/Cocoa.h>

@class PGMidiWindow_OSX;
@class PGMidi;

@interface PGMidiAppDelegate_OSX : NSObject <NSApplicationDelegate>
{
    PGMidi *_midi;
}

@property (nonatomic, strong) IBOutlet PGMidiWindow_OSX *window;

@end

