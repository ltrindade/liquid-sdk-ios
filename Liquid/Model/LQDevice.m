//
//  LQDevice.m
//  Liquid
//
//  Created by Liquid Data Intelligence, S.A. (lqd.io) on 09/01/14.
//  Copyright (c) 2014 Liquid Data Intelligence, S.A. All rights reserved.
//

#import "LQDefaults.h"
#import "LQDevice.h"
#import "NSString+LQString.h"
#import <UIKit/UIDevice.h>
#import <UIKit/UIScreen.h>
#include <sys/sysctl.h>

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>

#ifdef LIQUID_USE_IFA
#import <AdSupport/ASIdentifierManager.h>
#endif

#define kLQDeviceVendor @"Apple"
#define KLQDeviceReachabilityUrl "www.google.com"
#define kLQDeviceWifi @"WiFi"
#define kLQDeviceCellular @"Cellular"
#define kLQDeviceNoConnectivity @"No Connectivity"

@interface LQDevice ()

@property (nonatomic, assign) SCNetworkReachabilityRef networkReachability;

@end

static LQDevice *sharedInstance = nil;

@implementation LQDevice

#pragma mark - Singleton

+ (LQDevice *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)resetSharedInstance {
    sharedInstance = [[self alloc] init];
}

#pragma mark - Initializer

- (id)init {
    self = [super init];
    if(self) {
        _vendor = kLQDeviceVendor;
        _deviceModel = [LQDevice deviceModel];
        _systemVersion = [LQDevice systemVersion];
        _systemLanguage = [LQDevice systemLanguage];
        _locale = [LQDevice locale];
        _deviceName = [LQDevice deviceName];
        _carrier = [LQDevice carrier];
        _screenSize = [LQDevice screenSize];
        _uid = [LQDevice uid];
        _appBundle = [LQDevice appBundle];
        _appName = [LQDevice appName];
        _appVersion = [LQDevice appVersion];
        _releaseVersion = [LQDevice releaseVersion];
        _liquidVersion = [LQDevice liquidVersion];

        NSString *apnsTokenCacheKey = [NSString stringWithFormat:@"%@.%@", kLQBundle, @"APNSToken"];
        _apnsToken = [[NSUserDefaults standardUserDefaults] objectForKey:apnsTokenCacheKey];

        [self initReachabilityCallback];
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            [self reachabilityChanged:flags];
        } else {
            _internetConnectivity = kLQDeviceNoConnectivity;
        }
        if(_attributes == nil) {
            _attributes = [NSDictionary new];
        }
    }
    return self;
}

#pragma mark - Attributes

- (void)setAttribute:(id<NSCoding>)attribute forKey:(NSString *)key {
    if (![LQDevice assertAttributeType:attribute andKey:key]) return;

    NSMutableDictionary *mutableAttributes = [_attributes mutableCopy];
    [mutableAttributes setObject:attribute forKey:key];
    _attributes = [NSDictionary dictionaryWithDictionary:mutableAttributes];
}

- (id)attributeForKey:(NSString *)key {
    return [_attributes objectForKey:key];
}

- (void)setLocation:(CLLocation *)location {
    NSMutableDictionary *mutableAttributes = [_attributes mutableCopy];
    if(location == nil) {
        [mutableAttributes removeObjectForKey:@"latitude"];
        [mutableAttributes removeObjectForKey:@"longitude"];
    } else {
        [mutableAttributes setObject:[NSNumber numberWithFloat:location.coordinate.latitude] forKey:@"latitude"];
        [mutableAttributes setObject:[NSNumber numberWithFloat:location.coordinate.longitude] forKey:@"longitude"];
    }
    _attributes = [NSDictionary dictionaryWithDictionary:mutableAttributes];
}

+ (NSDictionary *)reservedAttributes {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @YES, @"_id",
            @YES, @"id",
            @YES, @"unique_id",
            @YES, @"platform",
            @YES, @"ip_address",
            @YES, @"created_at",
            @YES, @"updated_at", nil];
}

#pragma mark - Deallocation

- (void)dealloc{
    if (self.networkReachability) {
        SCNetworkReachabilitySetCallback(self.networkReachability, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(self.networkReachability, NULL);
        self.networkReachability = nil;
    }
}

#pragma mark - JSON

- (NSDictionary *)jsonDictionary {
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    [dictionary addEntriesFromDictionary:_attributes];
    [dictionary setObject:_vendor forKey:@"vendor"];
    [dictionary setObject:_deviceModel forKey:@"model"];
    [dictionary setObject:_systemVersion forKey:@"system_version"];
    [dictionary setObject:_systemLanguage forKey:@"system_language"];
    [dictionary setObject:_locale forKey:@"locale"];
    [dictionary setObject:_deviceName forKey:@"name"];
    [dictionary setObject:_screenSize forKey:@"screen_size"];
    [dictionary setObject:_carrier forKey:@"carrier"];
    [dictionary setObject:_internetConnectivity forKey:@"internet_connectivity"];
    if (_appBundle) {
        [dictionary setObject:_appBundle forKey:@"app_bundle"];
    }
    if (_appName) {
        [dictionary setObject:_appName forKey:@"app_name"];
    }
    if (_appVersion) {
        [dictionary setObject:_appVersion forKey:@"app_version"];
    }
    if (_releaseVersion) {
        [dictionary setObject:_releaseVersion forKey:@"release_version"];
    }
    if (_apnsToken) {
        [dictionary setObject:_apnsToken forKey:@"push_token"];
    }
    [dictionary setObject:_liquidVersion forKey:@"liquid_version"];
    [dictionary setObject:self.uid forKey:@"unique_id"];
    [dictionary setObject:kLQDevicePlatform forKey:@"platform"];

    return [NSDictionary dictionaryWithDictionary:dictionary];
}


#pragma mark - Device Info

+ (NSString*)carrier {
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier.carrierName.length) {
        return  carrier.carrierName;
    }
    return @"No Carrier";
}

+ (NSString*)screenSize {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    NSInteger width = screenSize.width  *scale;
    NSInteger height = screenSize.height  *scale;
    return [NSString stringWithFormat:@"%ldx%ld", (unsigned long)width, (unsigned long)height];
}

+ (NSString*)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *deviceModel = [NSString stringWithUTF8String:machine];
    free(machine);
    return deviceModel;
}

+ (NSString*)systemVersion {
    return [[UIDevice currentDevice] systemVersion];
}

+ (NSString*)liquidVersion {
    return kLQVersion;
}

+ (NSString*)systemLanguage {
    return [[NSLocale preferredLanguages] firstObject];
}

+ (NSString*)locale {
    return [[NSLocale currentLocale] objectForKey:NSLocaleIdentifier];
}

+ (NSString*)deviceName {
    return [[UIDevice currentDevice] name];
}

+ (NSString *)appleIFA {
    NSString *ifa = nil;
#ifndef LIQUID_NO_IFA
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *advertisingIdentifier = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        ifa = [advertisingIdentifier UUIDString];
    }
#endif
    return ifa;
}

+ (NSString *)appleIFV {
    NSString *ifv = nil;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
        if (NSClassFromString(@"UIDevice")) {
            ifv = [[UIDevice currentDevice].identifierForVendor UUIDString];
        }
    }
    return ifv;
}

+ (NSString *)generateRandomDeviceIdentifier {
    return [NSString generateRandomUUID];
}

+ (NSString*)uid {
    NSString *liquidUUIDKey = [NSString stringWithFormat:@"%@.%@", kLQBundle, @"UUID"];
    NSString *uid = [[NSUserDefaults standardUserDefaults]objectForKey:liquidUUIDKey];
    if(uid == nil) {
        NSString *newUid = [LQDevice appleIFA];
        if (newUid == nil) newUid = [LQDevice appleIFV];
        if (newUid == nil) newUid = [LQDevice generateRandomDeviceIdentifier];
        [[NSUserDefaults standardUserDefaults]setObject:newUid forKey:liquidUUIDKey];
        [[NSUserDefaults standardUserDefaults]synchronize];
        uid = newUid;
    }
    return uid;
}

#pragma mark - Application Info

+ (NSString*)appName {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleNameKey];
}

+ (NSString*)appBundle {
    return [[NSBundle mainBundle] bundleIdentifier];
}

+ (NSString*)appVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

+ (NSString*)releaseVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

#pragma mark - Reachability

- (void)initReachabilityCallback {
    BOOL reachabilityInitated = NO;
    self.networkReachability = SCNetworkReachabilityCreateWithName(NULL, KLQDeviceReachabilityUrl);
    if (self.networkReachability != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(self.networkReachability, LQDeviceNetworkReachabilityCallback, &context)) {
            dispatch_queue_t queue  = dispatch_queue_create("LQReachabilityQueue", DISPATCH_QUEUE_SERIAL);
            if (SCNetworkReachabilitySetDispatchQueue(self.networkReachability, queue)) {
                reachabilityInitated = YES;
            } else {
                // cleanup callback if setting dispatch queue failed
                SCNetworkReachabilitySetCallback(self.networkReachability, NULL, NULL);
            }
        }
    }
    if (!reachabilityInitated) {
        //NSLog(@"%@ failed to set up reachability callback: %s", self, SCErrorString(SCError()));
    }
}

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags {
    if(flags & kSCNetworkReachabilityFlagsReachable) {
        if(flags & kSCNetworkReachabilityFlagsIsWWAN) {
            _internetConnectivity = kLQDeviceCellular;
        } else {
            _internetConnectivity = kLQDeviceWifi;
        }
    } else {
        _internetConnectivity = kLQDeviceNoConnectivity;
    }
}

static void LQDeviceNetworkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    if (info != NULL && [(__bridge NSObject*)info isKindOfClass:[LQDevice class]]) {
        @autoreleasepool {
            LQDevice *device = (__bridge LQDevice *)info;
            [device reachabilityChanged:flags];
        }
    } else {
        //NSLog(@"Reachability: Unexpected info");
    }
}

- (BOOL)reachesInternet {
    if (_internetConnectivity == nil || ![_internetConnectivity isEqualToString:kLQDeviceNoConnectivity]) {
        return true;
    } else {
        return false;
    }
}

#pragma mark - NSCoding & NSCopying

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _vendor = [aDecoder decodeObjectForKey:@"vendor"];
        _deviceModel = [aDecoder decodeObjectForKey:@"deviceModel"];
        _systemVersion = [aDecoder decodeObjectForKey:@"systemVersion"];
        _systemLanguage = [aDecoder decodeObjectForKey:@"systemLanguage"];
        _locale = [aDecoder decodeObjectForKey:@"locale"];
        _deviceName = [aDecoder decodeObjectForKey:@"deviceName"];
        _carrier = [aDecoder decodeObjectForKey:@"carrier"];
        _screenSize = [aDecoder decodeObjectForKey:@"screenSize"];
        _uid = [aDecoder decodeObjectForKey:@"uid"];
        _appBundle = [aDecoder decodeObjectForKey:@"appBundle"];
        _appName = [aDecoder decodeObjectForKey:@"appName"];
        _appVersion = [aDecoder decodeObjectForKey:@"appVersion"];
        _releaseVersion = [aDecoder decodeObjectForKey:@"releaseVersion"];
        _liquidVersion = [aDecoder decodeObjectForKey:@"liquidVersion"];
        _internetConnectivity = [aDecoder decodeObjectForKey:@"internetConnectivity"];
        _apnsToken = [aDecoder decodeObjectForKey:@"apnsToken"];
        _attributes = [aDecoder decodeObjectForKey:@"attributes"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_vendor forKey:@"vendor"];
    [aCoder encodeObject:_deviceModel forKey:@"deviceModel"];
    [aCoder encodeObject:_systemVersion forKey:@"systemVersion"];
    [aCoder encodeObject:_systemLanguage forKey:@"systemLanguage"];
    [aCoder encodeObject:_locale forKey:@"locale"];
    [aCoder encodeObject:_deviceName forKey:@"deviceName"];
    [aCoder encodeObject:_carrier forKey:@"carrier"];
    [aCoder encodeObject:_screenSize forKey:@"screenSize"];
    [aCoder encodeObject:_uid forKey:@"uid"];
    [aCoder encodeObject:_appBundle forKey:@"appBundle"];
    [aCoder encodeObject:_appName forKey:@"appName"];
    [aCoder encodeObject:_appVersion forKey:@"appVersion"];
    [aCoder encodeObject:_releaseVersion forKey:@"releaseVersion"];
    [aCoder encodeObject:_liquidVersion forKey:@"liquidVersion"];
    [aCoder encodeObject:_internetConnectivity forKey:@"internetConnectivity"];
    [aCoder encodeObject:_apnsToken forKey:@"apnsToken"];
    [aCoder encodeObject:_attributes forKey:@"attributes"];
}

@end
