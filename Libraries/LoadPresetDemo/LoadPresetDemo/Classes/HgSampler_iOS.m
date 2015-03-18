//
//  HgSampler-iOS.m
//  PGMidi
//
//  Created by Demetri Miller on 3/17/15.
//
//

#import "HgSampler_iOS.h"

@implementation HgSampler_iOS

- (id)init
{
    self = [super init];
    if (self) {
        [self registerForUIApplicationNotifications];
    }
    return self;
}


#pragma mark - Audio Setup
- (BOOL)setupAudioSession
{
    [super setupAudioSession];
    AVAudioSession *mySession = [AVAudioSession sharedInstance];
    
    // Specify that this object is the delegate of the audio session, so that
    //    this object's endInterruption method will be invoked when needed.
    [mySession setDelegate: self];
    
    // Assign the Playback category to the audio session. This category supports
    //    audio output with the Ring/Silent switch in the Silent position.
    NSError *audioSessionError = nil;
    [mySession setCategory: AVAudioSessionCategoryPlayback error: &audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error setting audio session category."); return NO;}
    
    // Request a desired hardware sample rate.
    _graphSampleRate = 44100.0;    // Hertz
    
    [mySession setPreferredHardwareSampleRate:_graphSampleRate error:&audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error setting preferred hardware sample rate."); return NO;}
    
    // Activate the audio session
    [mySession setActive: YES error: &audioSessionError];
    if (audioSessionError != nil) {NSLog (@"Error activating the audio session."); return NO;}
    
    // Obtain the actual hardware sample rate and store it for later use in the audio processing graph.
    _graphSampleRate = [mySession currentHardwareSampleRate];

    return YES;
}


#pragma mark - Application state management
// The audio processing graph should not run when the screen is locked or when the app has
//  transitioned to the background, because there can be no user interaction in those states.
//  (Leaving the graph running with the screen locked wastes a significant amount of energy.)
//
// Responding to these UIApplication notifications allows this class to stop and restart the
//    graph as appropriate.
- (void) registerForUIApplicationNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver:self
                           selector:@selector(handleResigningActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:[UIApplication sharedApplication]];
    
    [notificationCenter addObserver:self
                           selector:@selector(handleBecomingActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:[UIApplication sharedApplication]];
}


- (void)handleResigningActive:(id)notification
{
    [self sendStopPlaybackMessage];
    [self stopAudioProcessingGraph];
}

- (void)handleBecomingActive:(id)notification
{
    [self restartAudioProcessingGraph];
}


#pragma mark Audio session delegate methods

// Respond to an audio interruption, such as a phone call or a Clock alarm.
- (void)beginInterruption
{
    // Stop any notes that are currently playing.
    [self sendStopPlaybackMessage];
    
    // Interruptions do not put an AUGraph object into a "stopped" state, so
    //    do that here.
    [self stopAudioProcessingGraph];
}


// Respond to the ending of an audio interruption.
- (void)endInterruptionWithFlags:(NSUInteger)flags
{
    NSError *endInterruptionError = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&endInterruptionError];
    
    if (endInterruptionError != nil) {
        NSLog (@"Unable to reactivate the audio session.");
        return;
    }
    
    if (flags & AVAudioSessionInterruptionFlags_ShouldResume) {
        
        /*
         In a shipping application, check here to see if the hardware sample rate changed from
         its previous value by comparing it to graphSampleRate. If it did change, reconfigure
         the ioInputStreamFormat struct to use the new sample rate, and set the new stream
         format on the two audio units. (On the mixer, you just need to change the sample rate).
         
         Then call AUGraphUpdate on the graph before starting it.
         */
        
        [self restartAudioProcessingGraph];
    }
}


@end
