//
//  BLESListener.h
//  BLESynth
//
//  Created by Andrew Pouliot on 10/7/12.
//  Copyright (c) 2012 Darknoon. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLESListener;
typedef void (^BLESListenerCallback)(BLESListener *self);

@interface BLESListener : NSObject

- (void)startListeningWithCallback:(BLESListenerCallback)callback;

@property (nonatomic, readonly) float currentRSSI;

@end
