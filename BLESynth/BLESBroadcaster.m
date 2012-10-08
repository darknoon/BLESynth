//
//  BLESBroadcaster.m
//  BLESynth
//
//  Created by Andrew Pouliot on 10/7/12.
//  Copyright (c) 2012 Darknoon. All rights reserved.
//

#import "BLESBroadcaster.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSString *const BLESynthUUID = @"627A82D6-C436-4495-A862-798719BC28BE";

@interface BLESBroadcaster () <CBPeripheralManagerDelegate>

@end

@implementation BLESBroadcaster {
	CBPeripheralManager *_manager;
	dispatch_queue_t _eventQueue;
}

- (id)init;
{
    self = [super init];
    if (!self) return nil;
	
	_manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:_eventQueue];
    
    return self;
}


- (void)startBroadcasting;
{
	[self peripheralManagerDidUpdateState:_manager];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral;
{
	if (_manager.state == CBPeripheralManagerStatePoweredOn) {
		[_manager startAdvertising:@{
           CBAdvertisementDataLocalNameKey    : @"BLESynth",
           CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:BLESynthUUID]]
		 }];

	}
}

@end
