/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>


typedef NS_ENUM(NSInteger, MSNetworkStatus) {
    /**
     *  无网络
     */
    MS_NotReachable = 0,
    /**
     *  wifi
     */
    MS_ReachableVia_WiFi = 1,
    /**
     *  2G
     */
    MS_ReachableVia_WWAN2G = 2,
    /**
     *  3G
     */
    MS_ReachableVia_WWAN3G = 3,
    /**
     *  4G
     */
    MS_ReachableVia_WWAN4G = 4,
    /**
     *  未知
     */
    MS_ReachableVia_Unknown = 10
};

extern NSString *const MS_NOTIFICATION_REACHABILITYCHANGE;

#pragma mark IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.

@interface MSReachability : NSObject

/*!
 * Use to check the reachability of a given host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;

/**
 *  获取WiFi 信息，返回的字典中包含了WiFi的名称、路由器的Mac地址、还有一个Data(转换成字符串打印出来是wifi名称)
 *
 *  @return wifiInfo
 */
+ (NSDictionary *)reachabilityForLocalWiFi;


#pragma mark reachabilityForLocalWiFi
//reachabilityForLocalWiFi has been removed from the sample.  See ReadMe.md for more information.
//+ (instancetype)reachabilityForLocalWiFi;

/*!
 * Start listening for reachability notifications on the current run loop.
 */
- (BOOL)startNotifier;
- (void)stopNotifier;

- (MSNetworkStatus)currentReachabilityStatus;

/*!
 * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
 */
- (BOOL)connectionRequired;


@end


