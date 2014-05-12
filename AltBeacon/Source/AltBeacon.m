//
//  INBlueToothService.m
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


#import "AltBeacon.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "CLBeacon+Ext.h"
#import "CBPeripheralManager+Ext.h"
#import "CBCentralManager+Ext.h"
#import "CBUUID+Ext.h"

#import "GCDSingleton.h"
#import "EasedValue.h"

#define DEBUG_CENTRAL NO
#define DEBUG_PERIPHERAL NO
#define DEBUG_PROXIMITY NO

#define UPDATE_INTERVAL 1.0f

@interface AltBeacon() <CBPeripheralManagerDelegate, CBCentralManagerDelegate>
@end

@implementation AltBeacon
{
    CBUUID *identifier;
    CBUUID *identifierFound;
    INDetectorRange identifierRange;
    
    CBCentralManager *centralManager;
    CBPeripheralManager *peripheralManager;
    
    NSMutableSet *delegates;
    
    EasedValue *easedProximity;
    
    NSTimer *detectorTimer;
    NSTimer *clearTimer;
    NSTimeInterval clearInterval;
    
    BOOL bluetoothIsEnabledAndAuthorized;
    NSTimer *authorizationTimer;
    NSArray * uuidsToDetect;
    NSMutableDictionary * uuidsDetected;
}


- (id)initWithIdentifier:(NSString *)theIdentifier clearFoundDevicesInterval:(NSTimeInterval) intervalInSeconds
{
    if ((self = [super init])) {
        identifier = [CBUUID UUIDWithString:theIdentifier];
        
        uuidsDetected = [[NSMutableDictionary alloc] init];
        
        clearInterval = intervalInSeconds;
        
        delegates = [[NSMutableSet alloc] init];
        
        easedProximity = [[EasedValue alloc] init];
        
        // use to track changes to this value
        bluetoothIsEnabledAndAuthorized = [self hasBluetooth];
        [self startAuthorizationTimer];
    }
    return self;
}

- (void)addDelegate:(id<AltBeaconDelegate>)delegate
{
    [delegates addObject:delegate];
}

- (void)removeDelegate:(id<AltBeaconDelegate>)delegate
{
    [delegates removeObject:delegate];
}

- (void)performBlockOnDelegates:(void(^)(id<AltBeaconDelegate> delegate))block
{
    [self performBlockOnDelegates:block complete:nil];
}

- (void)performBlockOnDelegates:(void(^)(id<AltBeaconDelegate> delegate))block complete:( void(^)(void))complete
{
    for (id<AltBeaconDelegate>delegate in delegates) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block)
                block(delegate);
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (complete)
            complete();
    });
    
}

- (void)startDetecting:(NSArray *)uuids
{
    if (![self canMonitorBeacons])
        return;
    
    uuidsToDetect = uuids;
    
    [self startDetectingBeacons];
}

- (void)startScanning
{
    
    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(YES)};

    [centralManager scanForPeripheralsWithServices:uuidsToDetect options:scanOptions];
    _isDetecting = YES;
}

- (void)stopDetecting
{
    _isDetecting = NO;
    
    [centralManager stopScan];
    centralManager = nil;
    
    [detectorTimer invalidate];
    detectorTimer = nil;
}

- (void)startBroadcasting
{
    if (![self canBroadcast])
        return;
    
    [self startBluetoothBroadcast];
    
}

- (void)stopBroadcasting
{
    _isBroadcasting = NO;
    
    // stop advertising beacon data.
    [peripheralManager stopAdvertising];
    peripheralManager = nil;
}

- (void)startDetectingBeacons
{
    if (!centralManager)
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    detectorTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self
                                                   selector:@selector(reportRangesToDelegates:) userInfo:nil repeats:YES];

    clearTimer = [NSTimer scheduledTimerWithTimeInterval:clearInterval target:self
                                                   selector:@selector(clearValues:) userInfo:nil repeats:YES];
}

- (void)clearValues:(id)clearValues {
    @synchronized(self) {
        [uuidsDetected removeAllObjects];
    }
}

- (void)startBluetoothBroadcast
{
    // start broadcasting if it's stopped
    if (!peripheralManager) {
        peripheralManager.delegate = self;
        peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];

    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict {
}

- (void)startAdvertising
{
    
    NSDictionary *advertisingData = @{CBAdvertisementDataLocalNameKey:@"vicinity-peripheral",
                                      CBAdvertisementDataServiceUUIDsKey:@[identifier]};
    
    // Start advertising over BLE
    [peripheralManager startAdvertising:advertisingData];
    
    _isBroadcasting = YES;
}

- (BOOL)canBroadcast
{
    // iOS6 can't detect peripheral authorization so just assume it works.
    // ARC complains if we use @selector because `authorizationStatus` is ambiguous
    SEL selector = NSSelectorFromString(@"authorizationStatus");
    if (![[CBPeripheralManager class] respondsToSelector:selector])
        return YES;
    
    CBPeripheralManagerAuthorizationStatus status = [CBPeripheralManager authorizationStatus];
    
    BOOL enabled = (status == CBPeripheralManagerAuthorizationStatusAuthorized ||
                    status == CBPeripheralManagerAuthorizationStatusNotDetermined);
    
    if (!enabled)
        NSLog(@"bluetooth not authorized");
    
    return enabled;
}

- (BOOL)canMonitorBeacons
{
    return YES;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    //NSLog(@"did discover peripheral: %@, data: %@, %1.2f", [peripheral.identifier UUIDString], advertisementData, [RSSI floatValue]);
        
    CBUUID *uuidMain = [advertisementData[CBAdvertisementDataServiceUUIDsKey] firstObject];
    CBUUID *uuidHidden = [advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] firstObject];
    //NSLog(@"service uuid: %@", [uuidMain representativeString]);
    //NSLog(@"service uuidHidden: %@", [uuidHidden representativeString]);
    
    CBUUID *uuid;
    
    if (uuidMain) {
        uuid = uuidMain;
    }else if (uuidHidden){
        uuid = uuidHidden;
    }else{
        uuid = nil;
    }
    
    if (uuid){
        @synchronized(self) {
            NSMutableArray *lastValues = [uuidsDetected objectForKey:[[uuid representativeString] uppercaseString]];
            if (!lastValues){
                [uuidsDetected setObject:[[NSMutableArray alloc] init] forKey:[[uuid representativeString] uppercaseString]];
            }else{
                [lastValues addObject:RSSI.copy];
                while (lastValues.count>25){   //rolling average
                    [lastValues removeObjectAtIndex:0];
                }
            }
        }
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (DEBUG_CENTRAL)
        NSLog(@"-- central state changed: %@", centralManager.stateString);
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self startScanning];
    }
    
}
#pragma mark -

-(NSMutableDictionary *)calculateRanges{
    NSMutableDictionary * res= [[NSMutableDictionary alloc] init];
    @synchronized(self) {
        NSArray * keys = [uuidsDetected allKeys];
        for (NSString * key in keys){
            float proximity = 0.0f;
            NSArray *lastValues = [uuidsDetected objectForKey:key];
            float i =0.0;
            for (NSNumber *value in lastValues){
                if([value floatValue]>-25){
                    float tempVal = 0;
                    if (i>0) {
                        tempVal = proximity / i;
                    }
                    if (tempVal>-25){
                        tempVal=-55;
                    }
                    proximity += tempVal;
                }else{
                    proximity += [value floatValue];
                }
                i++;

            }
            proximity = proximity / 25.0f;
            INDetectorRange range;
            if (proximity < -85){
                range = INDetectorRangeFar;
            }else if(proximity < -77){
                range = INDetectorRangeNear;
            }else if (proximity < 0){
                range = INDetectorRangeImmediate;
            }else{
                range = INDetectorRangeUnknown;
            }
            [res setObject:[NSNumber numberWithInt:range] forKey:key];

        }
    }
    return res;
    
}

- (void)reportRangesToDelegates:(NSTimer *)timer
{
    [self performBlockOnDelegates:^(id<AltBeaconDelegate>delegate) {
        NSMutableDictionary * devices = [self calculateRanges];
        
        [delegate service:self foundDevices:devices];
        
    } complete:^{
        // timeout the beacon to unknown position
        // it it's still active it will be updated by central delegate "didDiscoverPeripheral"
        identifierRange = INDetectorRangeUnknown;
    }];
}

#pragma mark - CBPeripheralManagerDelegate
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (DEBUG_PERIPHERAL)
        NSLog(@"-- peripheral state changed: %@", peripheral.stateString);
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self startAdvertising];
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (DEBUG_PERIPHERAL) {
        if (error)
            NSLog(@"error starting advertising: %@", [error localizedDescription]);
        else
            NSLog(@"did start advertising");
    }
}

- (BOOL)hasBluetooth
{
    return [self canBroadcast] && peripheralManager.state == CBPeripheralManagerStatePoweredOn;
}

- (void)startAuthorizationTimer
{
    authorizationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self
                                                        selector:@selector(checkBluetoothAuth:)
                                                        userInfo:nil repeats:YES];
}

- (void)checkBluetoothAuth:(NSTimer *)timer
{
    if (bluetoothIsEnabledAndAuthorized != [self hasBluetooth]) {
        
        bluetoothIsEnabledAndAuthorized = [self hasBluetooth];
        [self performBlockOnDelegates:^(id<AltBeaconDelegate>delegate) {
            if ([delegate respondsToSelector:@selector(service:bluetoothAvailable:)])
                [delegate service:self bluetoothAvailable:bluetoothIsEnabledAndAuthorized];
        }];
    }
}
@end
