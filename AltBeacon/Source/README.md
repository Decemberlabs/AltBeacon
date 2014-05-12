AltBeacon
=========

AltBeacon is an alternative to iBeacon to advertise Bluetooth Low Enery in the background, which is not possible in iBeacon. It is based on the open source project Vinicity (thanks Ben Ford) https://github.com/Instrument/Vicinity.


Version
----

0.3

Installation
--------------

Copy the folders into your xcode project. (Soon I will add a cocoapod as well)

Usage
--------------

Use a source uuid to advertise
    INBeaconService * beaconService;
    beaconService = [[INBeaconService alloc] initWithIdentifier:source.uuid]
    [beaconService addDelegate:self];

Then start broadcasting and detecting. You have to tell which uuids to detect, up to a maximum of 30 uuids. You can use location for example to get the uuids of the nearby devices in a radius of X kilometers. Or you can test for all the devices if you have not that many.

    [beaconService startBroadcasting];
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    NSString * UUID = (__bridge NSString*)string;
    [uuids addObject: [CBUUID UUIDWithString:UUID]];
    [beaconService startDetecting:uuids];
    
Implement the delegate to receive the information when the devices are found
    - (void)service:(INBeaconService *)service foundDevices:(NSMutableDictionary *)devices


License
----

MIT

    