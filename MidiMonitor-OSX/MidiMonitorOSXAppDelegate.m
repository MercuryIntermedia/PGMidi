//
//  AppDelegate.m
//  MidiMonitor-OSX
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import "MidiMonitorOSXAppDelegate.h"
#import "MidiMonitorOSXWindow.h"
#import "PGMidi.h"

@implementation MidiMonitorOSXAppDelegate

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
