//
//  BLESSynth.m
//  BLESynth
//
//  Created by Andrew Pouliot on 10/7/12.
//  Copyright (c) 2012 Darknoon. All rights reserved.
//

#import "BLESSynth.h"

#import <AVFoundation/AVAudioSession.h>
#include <AudioUnit/AudioUnit.h>
#include <vector>
#include <iostream>

using namespace std;

#define kOutputBus 0
#define kInputBus 1
#define SAMPLE_RATE 44100

typedef int BLESynthAudioBufferType;

@interface BLESSynth ()

- (void)fillBuffer:(AudioBuffer *)buffer atSampleRate:(NSUInteger)samplerate;

@end

@implementation BLESSynth {
	//Coordinate access to _targetFrequency with this queue
	dispatch_queue_t _synchronizationQueue;
	
	//Only use in high-performance thread!
	float __currentFrequency;
	float __phase;
}

@synthesize frequency = _targetFrequency;

#if 1
static float audioFunction(float phase) {
	return sinf(phase * M_PI);
}
#else
static float audioFunction(float phase) {
	return fabs(2.0 * phase - 1.0) - 0.5;
}
#endif

static BLESynthAudioBufferType valueToBufferType(float value) {
	int intv = (int)(value * 32500.0);
	intv += (intv << 16);
	return intv;
}

static OSStatus playbackCallback(void *inRefCon,
								 AudioUnitRenderActionFlags *ioActionFlags,
								 const AudioTimeStamp *inTimeStamp,
								 UInt32 inBusNumber,
								 UInt32 inNumberFrames,
								 AudioBufferList *ioData)
{	
	if (!ioData) {
		return 1;
	}
	
	for (int bufferIndex=0; bufferIndex < ioData->mNumberBuffers; bufferIndex++) {
		AudioBuffer *buffer = &ioData->mBuffers[bufferIndex];
		[(__bridge BLESSynth *)inRefCon fillBuffer:buffer atSampleRate:SAMPLE_RATE];
	}
	return noErr;
}

- (id)init;
{
    self = [super init];
    if (!self) return nil;
	
	NSError *audioSessionError = nil;
	AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
	if (audioSessionError) {
		NSLog(@"audio session error %@", audioSessionError);
		return nil;
	}
	[session setActive:YES error:&audioSessionError];
	if (audioSessionError) {
		NSLog(@"audio session error %@", audioSessionError);
		return nil;
	}
	
	_synchronizationQueue = dispatch_queue_create("BLESSynth internal synchronization", 0);
	__currentFrequency = 400;
	_targetFrequency = 400;
	__phase = 0;
    
    return self;
}


- (void)start
{
	OSStatus status;
	AudioComponentInstance audioUnit;
	
	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio units
	status = AudioComponentInstanceNew(inputComponent, &audioUnit);
	//checkStatus(status);
	
	UInt32 flag = 1;
	// Enable IO for playback
	status = AudioUnitSetProperty(audioUnit,
								  kAudioOutputUnitProperty_EnableIO,
								  kAudioUnitScope_Output,
								  kOutputBus,
								  &flag,
								  sizeof(flag));
	//checkStatus(status);
	
	// Describe format
	
	AudioStreamBasicDescription audioFormat;
	audioFormat.mSampleRate = SAMPLE_RATE;
	audioFormat.mFormatID	= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioFormat.mFramesPerPacket = 1;
	audioFormat.mChannelsPerFrame = 2;
	audioFormat.mBitsPerChannel = 16;
	audioFormat.mBytesPerPacket = 4;
	audioFormat.mBytesPerFrame = 4;
	
	// Apply format
	
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  kOutputBus,
								  &audioFormat,
								  sizeof(audioFormat));
	//  checkStatus(status);
	
	// Set output callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = playbackCallback;
	callbackStruct.inputProcRefCon = (__bridge void *)self;
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_SetRenderCallback,
								  kAudioUnitScope_Global,
								  kOutputBus,
								  &callbackStruct,
								  sizeof(callbackStruct));
	
	// Initialize
	status = AudioUnitInitialize(audioUnit);
	
	// Start playing
	
	status = AudioOutputUnitStart(audioUnit);
}

- (void)fillBuffer:(AudioBuffer *)buffer atSampleRate:(NSUInteger)samplerate;
{
	const double freqLerp = 0.999;
	const double freqLerp_1 = 1.0 - freqLerp;
	
	__block float targetFrequency;
	dispatch_sync(_synchronizationQueue, ^{
		targetFrequency = _targetFrequency;
	});
	
	//do this coordinated with writes to the target frequency
	BLESynthAudioBufferType *data = (BLESynthAudioBufferType *)buffer->mData;
	NSUInteger sampleCount = buffer->mDataByteSize / sizeof(BLESynthAudioBufferType);
	for (int sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
		__phase = fmodf(__phase + __currentFrequency / SAMPLE_RATE, 1.0f);
		
		if (isnormal(__currentFrequency)) {
			__currentFrequency = freqLerp * (double)__currentFrequency + freqLerp_1 * (double)targetFrequency;
		} else {
			__currentFrequency = targetFrequency;
		}
		
		data[sampleIndex] = valueToBufferType( audioFunction(__phase) );
	}
}

- (void)setFrequency:(float)frequency;
{
	dispatch_async(_synchronizationQueue, ^{
		_targetFrequency = frequency;
	});
}

- (float)frequency;
{
	__block float retval;
	dispatch_sync(_synchronizationQueue, ^{
		retval = _targetFrequency;
	});
	return retval;
}

@end
