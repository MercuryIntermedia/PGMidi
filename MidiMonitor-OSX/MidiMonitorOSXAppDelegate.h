//
//  AppDelegate.h
//  MidiMonitor-OSX
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import <Cocoa/Cocoa.h>

@class MidiMonitorOSXWindow;
@class PGMidi;

@interface MidiMonitorOSXAppDelegate : NSObject <NSApplicationDelegate>
{
    PGMidi *_midi;
}

@property (nonatomic, strong) IBOutlet MidiMonitorOSXWindow *window;

@end

