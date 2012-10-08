//
//  BLESViewController.m
//  BLESynth
//
//  Created by Andrew Pouliot on 10/7/12.
//  Copyright (c) 2012 Darknoon. All rights reserved.
//

#import "BLESViewController.h"

#import "BLESSynth.h"
#import "BLESListener.h"
#import "BLESBroadcaster.h"

@interface BLESViewController ()

@property (nonatomic) IBOutlet UILabel *frequencyLabel;

@end

@implementation BLESViewController {
	BLESSynth *_synth;
	BLESListener *_listener;
	BLESBroadcaster *_broadcaster;
	
	//Interpolate freq at 0.1 sec intervals
	float _frequency;
	float _targetFrequency;
	//TODO:
	//float _amplitude;
	//float _targetAmplitude;
	
	NSTimer *_heartbeatTimer;
}


- (void)viewDidAppear:(BOOL)animated;
{
	[super viewDidAppear:animated];
	
	[self start];
}

- (void)start;
{
	_synth = [[BLESSynth alloc] init];
	_listener = [[BLESListener alloc] init];
	_broadcaster = [[BLESBroadcaster alloc] init];
	
	_frequency = 400;
	_targetFrequency = 400;
	
	[_synth start];
	[_broadcaster startBroadcasting];
	
	__weak BLESViewController *weakSelf = self;
	[_listener startListeningWithCallback:^(BLESListener *listener) {
		BLESViewController *self = weakSelf;
		if (!self) return;
		
		[self processRSSIUpdate:listener];
	}];
	

	_heartbeatTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(_heartbeat:) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:_heartbeatTimer forMode:NSRunLoopCommonModes];
}

- (void)_heartbeat:(NSTimer *)timer;
{
	const double _lerpAmount = 0.9;
	
	_frequency = _lerpAmount * _frequency + (1.0 - _lerpAmount) * _targetFrequency;
	if (!isnormal(_frequency)) {
		_frequency = 0.0;
	}
	_synth.frequency = _frequency;
	_frequencyLabel.text = [NSString stringWithFormat:@"%.0f db > %.0lf hz", _listener.currentRSSI, self->_synth.frequency];
}

- (void)processRSSIUpdate:(BLESListener *)listener;
{
	//rssi ranges between 0 and -100 or so. Map it from minfreq to maxfreq
	const float minFreq = 120;
	const float maxFreq = 800;
	const float minRSSI = -100.f;
	const float maxRSSI = -30.f;
	
	float RSSI = listener.currentRSSI;
	float freqRatio = (RSSI - minRSSI)/(-minRSSI + maxRSSI);
	freqRatio = fminf(fmaxf(0.0f, freqRatio), 1.0f);
	
	_targetFrequency = minFreq + (maxFreq - minFreq) * freqRatio;

}

- (void)viewDidLoad
{
    [super viewDidLoad];
		
}


@end
