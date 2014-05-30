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
#define PROCESS_PERIPHERAL_INTERVAL 2.0f
#define RESTART_SCAN_INTERVAL 3.0f
#define ALT_BEACON_SERVICE @"8C422626-0C6E-4B86-8EC7-9147B233D97E"
#define ALT_BEACON_CHARACTERISTIC @"A05F9DF4-9D54-4600-9224-983B75B9D154"

@interface AltBeacon () <CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>
@end

@implementation AltBeacon {
    NSString *identifier;

    CBCentralManager *centralManager;
    CBPeripheralManager *peripheralManager;

    NSMutableSet *delegates;

    NSTimer *reportTimer;
    NSTimer *processPeripherals;
    NSTimer *restartScan;
    NSTimeInterval clearInterval;

    BOOL bluetoothIsEnabledAndAuthorized;
    NSTimer *authorizationTimer;
    NSMutableDictionary *uuidsDetected;
    NSMutableDictionary *peripheralDetected;
    NSMutableDictionary *peripheralUUIDSMatching;
    NSMutableArray *peripheralsToBeValidated;
    CBMutableCharacteristic *characteristic;
}


- (id)initWithIdentifier:(NSString *)theIdentifier {
    if ((self = [super init])) {
        identifier = theIdentifier;

        uuidsDetected = [[NSMutableDictionary alloc] init];
        peripheralDetected = [[NSMutableDictionary alloc] init];
        peripheralUUIDSMatching = [[NSMutableDictionary alloc] init];
        peripheralsToBeValidated = [[NSMutableArray alloc] init];

        delegates = [[NSMutableSet alloc] init];


        // use to track changes to this value
        bluetoothIsEnabledAndAuthorized = [self hasBluetooth];
        [self startAuthorizationTimer];
    }
    return self;
}

- (void)addDelegate:(id <AltBeaconDelegate>)delegate {
    [delegates addObject:delegate];
}

- (void)removeDelegate:(id <AltBeaconDelegate>)delegate {
    [delegates removeObject:delegate];
}

- (void)performBlockOnDelegates:(void (^)(id <AltBeaconDelegate> delegate))block {
    [self performBlockOnDelegates:block complete:nil];
}

- (void)performBlockOnDelegates:(void (^)(id <AltBeaconDelegate> delegate))block complete:(void (^)(void))complete {
    for (id <AltBeaconDelegate> delegate in delegates) {
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

- (void)startDetecting {
    if (![self canMonitorBeacons])
        return;

    [self startDetectingBeacons];
}


- (void)startScanning {

    reportTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self
                                                 selector:@selector(reportRangesToDelegates:) userInfo:nil repeats:YES];

    processPeripherals = [NSTimer scheduledTimerWithTimeInterval:PROCESS_PERIPHERAL_INTERVAL target:self
                                                        selector:@selector(processPeripherals:) userInfo:nil repeats:NO];
    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey : @(YES)};

    [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:ALT_BEACON_SERVICE]] options:scanOptions];
    //[centralManager scanForPeripheralsWithServices:nil options:scanOptions];
    _isDetecting = YES;
}

- (void)stopDetecting {
    _isDetecting = NO;

    [centralManager stopScan];
    centralManager = nil;

    [reportTimer invalidate];
    reportTimer = nil;
}

- (void)startBroadcasting {
    if (![self canBroadcast])
        return;

    [self startBluetoothBroadcast];

}

- (void)stopBroadcasting {
    _isBroadcasting = NO;

    // stop advertising beacon data.
    [peripheralManager stopAdvertising];
    peripheralManager = nil;
}

- (void)startDetectingBeacons {
    if (!centralManager)
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

}


- (void)             peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                          error:(NSError *)error {

    if (!error) {
        NSData *data = characteristic.value;
        NSString *newStr = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];


        @synchronized (self) {
            [peripheralUUIDSMatching setObject:newStr forKey:[peripheral.identifier UUIDString]];
            [peripheralsToBeValidated removeObject:peripheral];
        }
        [centralManager cancelPeripheralConnection:peripheral];

    }

}

- (void)                  peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
                               error:(NSError *)error {

    if (!error) {
        if (DEBUG_PERIPHERAL)
            NSLog(@"did discover characteristics: %@", [peripheral.identifier UUIDString]);
        [peripheral readValueForCharacteristic:service.characteristics[0]];
    } else {
        [centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (!error) {
        if (DEBUG_PERIPHERAL)
            NSLog(@"did discover services: %@", [peripheral.identifier UUIDString]);
        NSArray *services = peripheral.services;
        if (services.count > 0) {
            CBUUID *uuidCharacteristic = [CBUUID UUIDWithString:ALT_BEACON_CHARACTERISTIC];
            [peripheral discoverCharacteristics:@[uuidCharacteristic] forService:services[0]];
        }
    } else {
        [centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (DEBUG_CENTRAL)
        NSLog(@"did connect peripheral: %@", [peripheral.identifier UUIDString]);
    CBUUID *uuidService = [CBUUID UUIDWithString:ALT_BEACON_SERVICE];
    peripheral.delegate = self;
    [peripheral discoverServices:@[uuidService]];

}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"fail connect peripheral: %@", error);
}

- (void)processPeripherals:(NSTimer *)timer {
    if (peripheralsToBeValidated.count > 0) {

        [reportTimer invalidate];
        reportTimer = nil;
        [centralManager stopScan];
        @synchronized (self) {
            for (CBPeripheral *peripheral in peripheralsToBeValidated) {
                [centralManager connectPeripheral:peripheral options:nil];
            }
        }
        restartScan = [NSTimer scheduledTimerWithTimeInterval:RESTART_SCAN_INTERVAL target:self
                                                     selector:@selector(restartScan:) userInfo:nil repeats:NO];
    } else {
        processPeripherals = [NSTimer scheduledTimerWithTimeInterval:PROCESS_PERIPHERAL_INTERVAL target:self
                                                            selector:@selector(processPeripherals:) userInfo:nil repeats:NO];
    }

}

- (void)restartScan:(id)restartScan {
    @synchronized (self) {
        for (CBPeripheral *peripheral in peripheralsToBeValidated) {
            if (peripheral.state == CBPeripheralStateConnecting || peripheral.state == CBPeripheralStateConnected) {
                [centralManager cancelPeripheralConnection:peripheral];
            }
        }
    }
    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey : @(YES)};

    [centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:ALT_BEACON_SERVICE]] options:scanOptions];
    reportTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self
                                                 selector:@selector(reportRangesToDelegates:) userInfo:nil repeats:YES];
    processPeripherals = [NSTimer scheduledTimerWithTimeInterval:PROCESS_PERIPHERAL_INTERVAL target:self
                                                        selector:@selector(processPeripherals:) userInfo:nil repeats:NO];
}

- (void)clearValues:(id)clearValues {
    @synchronized (self) {
        [uuidsDetected removeAllObjects];
    }
}

- (void)startBluetoothBroadcast {
    // start broadcasting if it's stopped
    if (!peripheralManager) {
        peripheralManager.delegate = self;
        peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];

    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
    didReceiveReadRequest:(CBATTRequest *)request {

    if ([request.characteristic.UUID isEqual:characteristic.UUID]) {
        if (request.offset > characteristic.value.length) {
            [peripheralManager respondToRequest:request
                                     withResult:CBATTErrorInvalidOffset];
            return;
        }
        request.value = [characteristic.value
                subdataWithRange:NSMakeRange(request.offset,
                        characteristic.value.length - request.offset)];
        [peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

- (void)startAdvertising {
    NSDictionary *advertisingData = @{CBAdvertisementDataLocalNameKey : @"AltBeacon",
            CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:ALT_BEACON_SERVICE]]};

    // Start advertising over BLE
    CBUUID *altBeaconServiceUUID =
            [CBUUID UUIDWithString:ALT_BEACON_SERVICE];
    CBUUID *altBeaconCharacteristicUUID =
            [CBUUID UUIDWithString:ALT_BEACON_CHARACTERISTIC];

    CBMutableService *service = [[CBMutableService alloc] initWithType:altBeaconServiceUUID primary:YES];
    NSString *strUUID = identifier;
    NSData *dataUUID = [strUUID dataUsingEncoding:NSUTF8StringEncoding];

    characteristic =
            [[CBMutableCharacteristic alloc] initWithType:altBeaconCharacteristicUUID
                                               properties:CBCharacteristicPropertyRead
                                                    value:dataUUID permissions:CBAttributePermissionsReadable];
    service.characteristics = @[characteristic];
    [peripheralManager addService:service];
    [peripheralManager startAdvertising:advertisingData];

    _isBroadcasting = YES;
}

- (BOOL)canBroadcast {
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

- (BOOL)canMonitorBeacons {
    return YES;
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (DEBUG_CENTRAL)
        NSLog(@"did discover peripheral: %@, data: %@, %1.2f", [peripheral.identifier UUIDString], advertisementData, [RSSI floatValue]);


    @synchronized (self) {
        NSMutableArray *lastValues = [peripheralDetected objectForKey:[[peripheral.identifier UUIDString] uppercaseString]];
        if (!lastValues) {
            [peripheralsToBeValidated addObject:peripheral];
            [peripheralDetected setObject:[[NSMutableArray alloc] init] forKey:[[peripheral.identifier UUIDString] uppercaseString]];
        } else {
            for (NSNumber *valueRange in lastValues.copy) {
                if (valueRange.floatValue <= -205) {  //I'm alive -> remove aging values
                    [lastValues removeObject:valueRange];
                }
            }
            [lastValues addObject:RSSI.copy];

            while (lastValues.count > 10) {   //rolling average
                [lastValues removeObjectAtIndex:0];
            }
        }
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (DEBUG_CENTRAL)
        NSLog(@"-- central state changed: %@", centralManager.stateString);

    if (central.state == CBCentralManagerStatePoweredOn) {
        [self startScanning];
    }

}

#pragma mark -

- (NSMutableDictionary *)calculateRanges {
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
    @synchronized (self) {
        NSArray *keys = [uuidsDetected allKeys];
        for (NSString *key in keys) {
            float proximity = 0.0f;
            NSArray *lastValues = [uuidsDetected objectForKey:key];
            float i = 0.0;
            for (NSNumber *value in lastValues) {
                if ([value floatValue] > -25) {
                    float tempVal = 0;
                    if (i > 0) {
                        tempVal = proximity / i;
                    }
                    if (tempVal > -25) {
                        tempVal = -55;
                    }
                    proximity += tempVal;
                } else {
                    proximity += [value floatValue];
                }
                i++;

            }
            proximity = proximity / 10.0f;
            INDetectorRange range;
            if (proximity < -200) {
                range = INDetectorRangeUnknown;
            }
            else if (proximity < -90) {
                range = INDetectorRangeFar;
            } else if (proximity < -72) {
                range = INDetectorRangeNear;
            } else if (proximity < 0) {
                range = INDetectorRangeImmediate;
            } else {
                range = INDetectorRangeUnknown;
            }
            [res setObject:[NSNumber numberWithInt:range] forKey:key];

        }
    }
    return res;

}

- (void)reportRangesToDelegates:(NSTimer *)timer {
    [self performBlockOnDelegates:^(id <AltBeaconDelegate> delegate) {


        for (NSString *peripheralKey in peripheralUUIDSMatching) {
            NSMutableArray *ranges = [peripheralDetected objectForKey:peripheralKey];
            NSString *uuid = [peripheralUUIDSMatching objectForKey:peripheralKey];
            [uuidsDetected setObject:ranges forKey:uuid];

        }


        NSMutableDictionary *devices = [self calculateRanges];

        [delegate service:self foundDevices:devices];

    }                    complete:^{
        @synchronized (self) {

            NSArray *keys = [peripheralDetected allKeys];
            for (NSString *key in keys) {
                NSMutableArray *lastValues = [peripheralDetected objectForKey:key];
                [lastValues addObject:[NSNumber numberWithFloat:-205]];
            }
        }

    }];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (DEBUG_PERIPHERAL)
        NSLog(@"-- peripheral state changed: %@", peripheral.stateString);

    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self startAdvertising];
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (DEBUG_PERIPHERAL) {
        if (error)
            NSLog(@"error starting advertising: %@", [error localizedDescription]);
        else
            NSLog(@"did start advertising");
    }
}

- (BOOL)hasBluetooth {
    return [self canBroadcast] && peripheralManager.state == CBPeripheralManagerStatePoweredOn;
}

- (void)startAuthorizationTimer {
    authorizationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self
                                                        selector:@selector(checkBluetoothAuth:)
                                                        userInfo:nil repeats:YES];
}

- (void)checkBluetoothAuth:(NSTimer *)timer {
    if (bluetoothIsEnabledAndAuthorized != [self hasBluetooth]) {

        bluetoothIsEnabledAndAuthorized = [self hasBluetooth];
        [self performBlockOnDelegates:^(id <AltBeaconDelegate> delegate) {
            if ([delegate respondsToSelector:@selector(service:bluetoothAvailable:)])
                [delegate service:self bluetoothAvailable:bluetoothIsEnabledAndAuthorized];
        }];
    }
}
@end
