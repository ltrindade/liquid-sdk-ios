//
//  LQDefaults.h
//  LiquidApp
//
//  Created by Liquid Data Intelligence, S.A. (lqd.io) on 3/28/14.
//  Copyright (c) 2014 Liquid Data Intelligence, S.A. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kLQVersion @"0.9.1-beta"
#define kLQBundle @"io.lqd.ios"
#define kLQDevicePlatform @"iOS"
#define kLQNotificationLQDidReceiveValues @"io.lqd.ios.Notifications:LQDidReceiveValues"
#define kLQNotificationLQDidLoadValues @"io.lqd.ios.Notifications:DidLoadValues"
#define kLQNotificationLQDidIdentifyUser @"io.lqd.ios.Notifications:DidIdentifyUser"
#define kLQBackgroundTaskName @"io.lqd.ios.BackgroundTask"

#define kLQLogLevelPaths       8
#define kLQLogLevelHttp        7
#define kLQLogLevelData        6
#define kLQLogLevelInfoVerbose 5
#define kLQLogLevelWarning     4
#define kLQLogLevelInfo        3
#define kLQLogLevelError       2
#define kLQLogLevelAssert      1
#define kLQLogLevelNone        0

#ifdef DEBUG
#    define kLQLogLevel kLQLogLevelPaths
#else
#    define kLQLogLevel kLQLogLevelAssert
#endif

#define kLQDefaultSessionTimeout 30 //seconds
#define kLQDirectory kLQBundle
#define kLQSendFallbackValuesInDevelopmentMode YES

#define kLQErrorValueNotFound 1

#define LQLog(level,...) if(level<=kLQLogLevel) NSLog(__VA_ARGS__)

#define INTERFACE_IS_PAD     (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define INTERFACE_IS_PHONE   (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

