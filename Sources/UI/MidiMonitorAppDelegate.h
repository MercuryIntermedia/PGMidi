//
//  MidiMonitorAppDelegate.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MidiMonitorViewController;
@class PGMidi;

@interface MidiMonitorAppDelegate : NSObject <UIApplicationDelegate>
{
    PGMidi *_midi;
}

@property (nonatomic, strong) IBOutlet UIWindow                  *window;
@property (nonatomic, strong) IBOutlet MidiMonitorViewController *viewController;

@end

