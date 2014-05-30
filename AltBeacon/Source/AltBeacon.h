//
//  INBlueToothService.h
//  AltBeacon (Renamed from Vicinity)
//
//  Created by Ben Ford on 10/28/13 and modified by Martin Palatnik on 02/03/2014
//
//  The MIT License (MIT)
// 
//  Copyright (c) 2013 Instrument Marketing Inc
//  Copyright (c) 2014 CharruaLabs
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import <Foundation/Foundation.h>

typedef enum {
    INDetectorRangeUnknown = 0,
    INDetectorRangeFar,
    INDetectorRangeNear,
    INDetectorRangeImmediate,
} INDetectorRange;


@class AltBeacon;
@protocol AltBeaconDelegate <NSObject>
@optional
- (void)service:(AltBeacon *)service foundDevices:(NSMutableDictionary *)devices;
- (void)service:(AltBeacon *)service bluetoothAvailable:(BOOL)enabled;
@end

@interface AltBeacon : NSObject

- (id)initWithIdentifier:(NSString *)theIdentifier;

- (void)addDelegate:(id<AltBeaconDelegate>)delegate;
- (void)removeDelegate:(id<AltBeaconDelegate>)delegate;

@property (nonatomic, readonly) BOOL isDetecting;
@property (nonatomic, readonly) BOOL isBroadcasting;

- (void)startDetecting;
- (void)stopDetecting;

- (void)startBroadcasting;
- (void)stopBroadcasting;

- (BOOL)hasBluetooth;
@end
