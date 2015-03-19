//
//  MidiMonitorAppDelegate.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PGMidiAppDelegate_iOS.h"
#import "PGMidiViewController_iOS.h"
#import "PGMidi.h"

@implementation PGMidiAppDelegate_iOS

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];

    _midi                            = [[PGMidi alloc] init];
    _midi.networkEnabled             = YES;
    viewController.midi              = _midi;
    _midi.virtualDestinationEnabled  = YES;
    _midi.virtualSourceEnabled       = YES;

	return YES;
}

@end
