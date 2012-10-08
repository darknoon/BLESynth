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
		return 1; //TODO: what should we return in this case? What could trigger this?
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
	AudioComponentInstance audioUnit = NULL;
		
	// Get audio component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &(AudioComponentDescription){
		.componentType = kAudioUnitType_Output,
		.componentSubType = kAudioUnitSubType_RemoteIO,
		.componentFlags = 0,
		.componentFlagsMask = 0,
		.componentManufacturer = kAudioUnitManufacturer_Apple,
	});
	
	// Create a new instance of the RemoteIO component
	status = AudioComponentInstanceNew(inputComponent, &audioUnit);
	
	// Enable IO for playback
	status = AudioUnitSetProperty(audioUnit,
								  kAudioOutputUnitProperty_EnableIO,
								  kAudioUnitScope_Output,
								  kOutputBus,
								  &(UInt32){1},
								  sizeof(UInt32));
	
	// Describe format
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_StreamFormat,
								  kAudioUnitScope_Input,
								  kOutputBus,
								  &(const AudioStreamBasicDescription){
									  .mSampleRate = SAMPLE_RATE,
									  .mFormatID	= kAudioFormatLinearPCM,
									  .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
									  .mFramesPerPacket = 1,
									  .mChannelsPerFrame = 2,
									  .mBitsPerChannel = 16,
									  .mBytesPerPacket = 4,
									  .mBytesPerFrame = 4,
								  },
								  sizeof(AudioStreamBasicDescription));
	
	// Set output callback
	status = AudioUnitSetProperty(audioUnit,
								  kAudioUnitProperty_SetRenderCallback,
								  kAudioUnitScope_Global,
								  kOutputBus,
								  &(AURenderCallbackStruct){
									  .inputProc = playbackCallback,
									  .inputProcRefCon =(__bridge void *)self,
								  },
								  sizeof(AURenderCallbackStruct));
	
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
