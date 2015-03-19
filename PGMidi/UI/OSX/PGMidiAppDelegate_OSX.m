//
//  AppDelegate.m
//  MidiMonitor-OSX
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import "PGMidiAppDelegate_OSX.h"
#import "PGMidiWindow_OSX.h"
#import "PGMidi.h"

@implementation PGMidiAppDelegate_OSX

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _midi                            = [[PGMidi alloc] init];
    _midi.networkEnabled             = YES;
    _window.midi                     = _midi;
    _midi.virtualDestinationEnabled  = YES;
    _midi.virtualSourceEnabled       = YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
