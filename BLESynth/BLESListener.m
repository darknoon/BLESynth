//
//  BLESListener.m
//  BLESynth
//
//  Created by Andrew Pouliot on 10/7/12.
//  Copyright (c) 2012 Darknoon. All rights reserved.
//

#import "BLESListener.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLESListener () <CBCentralManagerDelegate> 

@property (nonatomic) float currentRSSI;

@end

@implementation BLESListener {
	dispatch_queue_t _eventQueue;
	CBCentralManager *_manager;
	BLESListenerCallback _callback;
}

- (id)init;
{
    self = [super init];
	if (!self) return nil;
	
	_eventQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.darknoon.%@", self.class] UTF8String], 0);
	//For now, process these events as if on the main queue
	dispatch_set_target_queue(_eventQueue, dispatch_get_main_queue());
	
	_manager = [[CBCentralManager alloc] initWithDelegate:self queue:_eventQueue];
	
    return self;
}


- (void)startListeningWithCallback:(BLESListenerCallback)callback;
{
	_callback = callback;
	[self centralManagerDidUpdateState:_manager];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central;
{
	if (central.state == CBCentralManagerStatePoweredOn) {
		[_manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
	}
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI;
{
	self.currentRSSI = RSSI.floatValue;
	
	if (_callback) {
		_callback(self);
	}
}

@end
