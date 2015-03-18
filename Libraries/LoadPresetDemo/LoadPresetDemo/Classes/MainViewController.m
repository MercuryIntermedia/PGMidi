/*
     File: MainViewController.m
 Abstract: The view controller for this app. Includes all the audio code.
  Version: 1.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */


#import "MainViewController.h"
#import <AssertMacros.h>
#import "HgSampler.h"

// some MIDI constants:
enum {
	kMIDIMessage_NoteOn    = 0x9,
	kMIDIMessage_NoteOff   = 0x8,
};

#define kLowNote  48
#define kHighNote 72
#define kMidNote  60

// private class extension
@interface MainViewController ()
@property (nonatomic, strong) HgSampler *sampler;
@end

@implementation MainViewController


#pragma mark - Lifecycle
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName: nibNameOrNil bundle: nibBundleOrNil];
    if (self) {
        self.sampler = [[HgSampler alloc] init];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    // Load the Trombone preset so the app is ready to play upon launch.
    [self loadPresetOne:self];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Actions
- (IBAction)loadPresetOne:(id)sender
{
    OSStatus status = [_sampler loadPresetWithName:@"Trombone"];
    if (status == noErr) {
        self.currentPresetLabel.text = @"Trombone";
    } else {
        self.currentPresetLabel.text = @"Error Loading Trombone";
    }
}

- (IBAction)loadPresetTwo:(id)sender
{
    OSStatus status = [_sampler loadPresetWithName:@"Vibraphone"];
    if (status == noErr) {
        self.currentPresetLabel.text = @"Vibraphone";
    } else {
        self.currentPresetLabel.text = @"Error Loading Vibraphone";
    }
}


#pragma mark - Audio control
// Play the low note
- (IBAction)startPlayLowNote:(id)sender
{
	UInt32 noteNum = kLowNote;
	UInt32 onVelocity = 127;
	UInt32 noteCommand = kMIDIMessage_NoteOn << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:onVelocity];
}

// Stop the low note
- (IBAction)stopPlayLowNote:(id)sender
{
	UInt32 noteNum = kLowNote;
	UInt32 noteCommand = kMIDIMessage_NoteOff << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:0];
}

// Play the mid note
- (IBAction)startPlayMidNote:(id)sender
{
	UInt32 noteNum = kMidNote;
	UInt32 onVelocity = 127;
	UInt32 noteCommand = kMIDIMessage_NoteOn << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:onVelocity];
}

// Stop the mid note
- (IBAction) stopPlayMidNote:(id)sender
{
	UInt32 noteNum = kMidNote;
	UInt32 noteCommand = kMIDIMessage_NoteOff << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:0];
}

// Play the high note
- (IBAction)startPlayHighNote:(id)sender
{
	UInt32 noteNum = kHighNote;
	UInt32 onVelocity = 127;
	UInt32 noteCommand = 	kMIDIMessage_NoteOn << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:onVelocity];
}

// Stop the high note
- (IBAction)stopPlayHighNote:(id)sender
{
	UInt32 noteNum = kHighNote;
	UInt32 noteCommand = 	kMIDIMessage_NoteOff << 4 | 0;
    [_sampler playMIDIWithStatus:noteCommand data1:noteNum data2:0];
}



@end
