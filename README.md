AltBeacon
=========

AltBeacon is an alternative to iBeacon that allows iOS devices to be advertised in the background, which is not currently possible with iBeacon. **It is based on the open source project Vinicity (thanks Ben Ford)** https://github.com/Instrument/Vicinity. In addition to the great job done in Vicinity, AltBeacons adds the possibility to detect many AltBeacons with different UUIDS and the accuracy of the range was improved. It is important to notice that by advertising in the background a whole new range of use cases are possible that require people to interact with nearby people, for example a messaging app for nearby people. We are currenlty using this framework to develop a product that will be soon in the AppStore. 

Titanium
----
There is also a Titanuim for available @ https://github.com/mfferreira/TiAltBeacon

How does it work
----

The key behind AltBeacon is that the Bluetooth Low Energy stack of iOS allows background advertising when acting as a Peripheral (In android this is still not possible but we are working in a workaround). However, when advertising in background it is only possible to discover UUIDs that you know previously (this is mentioned in the BLE documentation of apple but it was also tested by us). Using the following call:

    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(YES)};
    [centralManager scanForPeripheralsWithServices:nil options:scanOptions];

Will find all the AltBeacons around that are advertising in the foreground but none that is advertising in the background. So this is not a valid alternative. 

The solution is to discover AltBeacons by using a general UUID known by all of them.

    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(YES)};
    [centralManager scanForPeripheralsWithServices:ALT_BEACON_GENERAL_UUID options:scanOptions];

Then AltBeacons (Centrals) scan for other AltBeacons (Peripherals) with a General UUID already known by all the AltBeacons. When they find the AltBeacon (Peripheral), they connect to that peripheral and obtain a Specific UUID for that peripheral using services and characteristics. It is important to notice that we use 2 different UUIDs. The General AltBeacon UUID is always the same for all the AltBeacons and allows us to find them , and distinguish them from other devices using BLE. The Specific AltBeacon UUID is different for all the AltBeacons and allows us to identify and differentiate the AltBeacons form each other. It is important to know that the connection between the peripheral and the central happens only once, after that the central AltBeacon can remember the peripheral and it only needs to sense for the range, there is no need to reconnect (less battery usage).  


Version
----

0.3

Changelog
----

0.3 
- Now it is possible to detect any AltBeacon, no need to know location previously.
- Some fixes in the reporting of the ranges


Installation
----

Copy the source folder into your xcode project. Or install via cocoapods 

pod 'AltBeacon'

Usage
----

**There is a Demo project inside the source code showing how to use AltBeacon. Please check it.**

Otherwise check the following instructions. **Remember to add the background mode: Act as a Bluetooth LE accesory.**

Define the UUIDS of the AltBeacons. In a real project you would generate them automatically (NSString *uuid = [[NSUUID UUID] UUIDString]) and store them in a database. 

    #define kUuidBeaconOne @"5F22CA05-8F6C-49B6-AEAE-B278FDFE9287"
    #define kUuidBeaconTwo @"9F3E9E58-5073-4F78-BD04-87050DAFB604"
    #define kUuidBeaconThree @"177383C7-8347-444F-B14E-1581131A16E2"


Then start create the beacons broadcasting and detecting. 

    // Initialize the IBeacon UUDI@
    self.beaconOne =  [[AltBeacon alloc ]initWithIdentifier:kUuidBeaconOne clearFoundDevicesInterval:CLEAR_INTERVAL];
    self.beaconTwo =  [[AltBeacon alloc ]initWithIdentifier:kUuidBeaconTwo clearFoundDevicesInterval:CLEAR_INTERVAL];
    self.beaconThree =  [[AltBeacon alloc ]initWithIdentifier:kUuidBeaconThree clearFoundDevicesInterval:CLEAR_INTERVAL];
    [self.beaconOne addDelegate:self];
    [self.beaconTwo addDelegate:self];
    [self.beaconThree addDelegate:self];

Then tell the beacon to start detecting and advertising (broadcasting). 

    - (void)start:(AltBeacon *)beacon {

        // start broadcasting
        [beacon startBroadcasting];
        [beacon startDetecting];
    }

    - (void)stop:(AltBeacon *)beacon {
        
        // start broadcasting
        [beacon stopBroadcasting];
        [beacon stopDetecting];
    }

    
Implement the delegate to receive the information when the devices are found. You receive a dictionary with the uuid as a key and the range and enum with Immediate, Near and Far as the value. The range indicates how close you are to the UUIDS that were detected. This callback is called once a second and the list of uuids find is cleared every a few seconds. You can define the clearance time in the AltBeacon constructor. 

    // Delegate methods
    - (void)service:(AltBeacon *)service foundDevices:(NSMutableDictionary *)devices {

        for(NSString *key in devices) {
            NSNumber * range = [devices objectForKey:key];
            if (range.intValue == INDetectorRangeUnknown){
                if ([key  isEqualToString:kUuidBeaconOne]){
                    self.labelDisplayResultBeacon1.text = @"";
                }
                else if ([key  isEqualToString: kUuidBeaconTwo]){
                    self.labelDisplayResultBeacon2.text =  @"";
                }
                else if ([key  isEqualToString: kUuidBeaconThree]){
                    self.labelDisplayResultBeacon3.text = @"";
                }
            }else{

                NSString *result = [self convertToString:range];
                NSString *beaconName = @"";
                if ([key  isEqualToString:kUuidBeaconOne]){
                    beaconName = @"Beacon one!";
                    self.labelDisplayResultBeacon1.text = [NSString stringWithFormat:@"%@ %@ %@ %@", beaconName, @"was found",result, @"meters away"];
                }
                else if ([key  isEqualToString: kUuidBeaconTwo]){
                    beaconName = @"Beacon two!";
                    self.labelDisplayResultBeacon2.text = [NSString stringWithFormat:@"%@ %@ %@ %@", beaconName, @"was found",result, @"meters away"];
                }
                else if ([key  isEqualToString: kUuidBeaconThree]){
                    beaconName = @"Beacon three!";
                    self.labelDisplayResultBeacon3.text = [NSString stringWithFormat:@"%@ %@ %@ %@", beaconName, @"was found",result, @"meters away"];
                }
            }
        }
    }

Other things
----
**Please notice that this library is under development, please feel free to contribute and mention design alternatives and possibilities.** Contacts us at martin@decemberlabs.com

Martin Palatnik -> 
e-mail:  martin@decemberlabs.com
Twitter: @mpalatnik

Historical
----
A previous version of the AltBeacon worked quite differently. As we are still evaluating the current version performance, we add a small explanation of the previous version here as well. 

The previous solutions was based on scanning directly for several Specific AltBeacons UUIDS at a time, instead of first scanning for a General UUID.  The trick was to use CoreLocation and store the Location of all the AltBeacons in a database and then define a radius of a few km to filter most of them. Then search only for the AltBeacons in that radius. Our experiments showed that you can scan for a maximum of 7 UUIDS at a time. If you scan for more than that then the CentralManager returns as correct some UUIDs that are not really there. The following call, if it contains less than 7 UUIDS, will find them correctly.

    NSDictionary *scanOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(YES)};
    [centralManager scanForPeripheralsWithServices:uuidsToDetect options:scanOptions];

Considering that it takes a few hundred milliseconds to find the AltBeacons that you are scanning for, in a minute you can scan for hundred of beacons. In addition if you limit the number of AltBeacons using CoreLocation and database to a radius of a couple of kilometers then this approach is quite scalable.

An important problem with this previous version was that when more that one app was using the BLE stack at a time to advertise in background, the scanning AltBeacon would incorrectly report the findings. 

Disambiguation
----
If you are looking for the Open and Interoperable Proximity Beacon Specification with the same name please go to:
http://altbeacon.org/

License
----

MIT

    
