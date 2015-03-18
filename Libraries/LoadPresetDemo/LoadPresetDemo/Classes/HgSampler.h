//
//  HgSampler.h
//  LoadPresetDemo
//
//  Created by Demetri Miller on 3/17/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <Foundation/Foundation.h>

@interface HgSampler : NSObject
{
    Float64 _graphSampleRate;
}

+ (instancetype)sampler;

/// Audio Setup method for subclassing
- (BOOL)setupAudioSession;
- (void)restartAudioProcessingGraph;
- (void)stopAudioProcessingGraph;
- (void)sendStopPlaybackMessage;


/// Audio Setup
- (OSStatus)loadPresetWithName:(NSString *)name;
- (OSStatus)loadEXS24WithName:(NSString *)name;


/// Playback
/** Convenience method for MIDI playback of the common case */
- (void)playMIDIWithStatus:(UInt32)status data1:(UInt32)data1 data2:(UInt32)data2;

/** Takes a MIDIPacketList, extracts the bytes, and passes them to our audio sampler. */
- (void)playMIDIPacket:(const MIDIPacket *)packet;


@end
