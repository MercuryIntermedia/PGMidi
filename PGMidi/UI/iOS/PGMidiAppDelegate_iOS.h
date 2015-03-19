//
//  MidiMonitorAppDelegate.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PGMidiViewController_iOS;
@class PGMidi;

@interface PGMidiAppDelegate_iOS : NSObject <UIApplicationDelegate>
{
    PGMidi *_midi;
}

@property (nonatomic, strong) IBOutlet UIWindow                  *window;
@property (nonatomic, strong) IBOutlet PGMidiViewController_iOS *viewController;

@end

