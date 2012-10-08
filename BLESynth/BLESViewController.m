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
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	_synth = [[BLESSynth alloc] init];
	_listener = [[BLESListener alloc] init];
	_broadcaster = [[BLESBroadcaster alloc] init];
	
	__weak BLESViewController *weakSelf = self;
	[_listener startListeningWithCallback:^(BLESListener *listener) {
		BLESViewController *self = weakSelf;
		if (!self) return;
		
		//rssi ranges between 0 and -100 or so. Map it from minfreq to maxfreq
		const float minFreq = 100;
		const float maxFreq = 800;
		const float minRSSI = -100.f;
		const float maxRSSI = -20.f;
		self->_synth.frequency = minFreq + (maxFreq - minFreq) * log( fmaxf(-minRSSI + listener.currentRSSI + maxRSSI, 0.0f)) / log(-minRSSI - maxRSSI);
		self.frequencyLabel.text = [NSString stringWithFormat:@"%.0f db > %.0lf hz", listener.currentRSSI, self->_synth.frequency];
	}];
	
	[_synth start];
	[_broadcaster startBroadcasting];
}


@end
