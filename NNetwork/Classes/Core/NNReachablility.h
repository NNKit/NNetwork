//
//  NNReachablility.h
//  NNetwork
//
//  more info https://github.com/ibireme/YYKit/blob/master/YYKit/Utility/YYReachability.h
//  Created by XMFraker on 2017/11/17.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

typedef NS_ENUM(NSUInteger, NNReachablilityStatus) {
    /** 无网络连接 */
    NNReachablilityStatusNone = 0,
    /** 使用蜂窝数据 */
    NNReachablilityStatusWWAN,
    /** 使用WiFi中 */
    NNReachablilityStatusWiFi,
};

typedef NS_ENUM(NSUInteger, NNReachablilityWWANStatus) {
    /** 未使用蜂窝网络 */
    NNReachablilityWWANStatusNone = 0,
    /** 2G(GPRS/EDGE) 10~100Kbps*/
    NNReachablilityWWANStatus2G = 2,
    /** 3G(WCDMA/HSDPA/...) 1~10Mbps*/
    NNReachablilityWWANStatus3G = 3,
    /** 4G(eHRPD/LTE) 100Mbps*/
    NNReachablilityWWANStatus4G = 4
};

NS_ASSUME_NONNULL_BEGIN

@interface NNReachablility : NSObject

@property (assign, nonatomic, readonly) SCNetworkReachabilityFlags flags;
@property (assign, nonatomic, readonly) NNReachablilityStatus status;
@property (assign, nonatomic, readonly) NNReachablilityWWANStatus wwanStatus;
@property (assign, nonatomic, readonly, getter=isReachable) BOOL reachable;
@property (copy, nonatomic, nullable)   void(^notifyHandler)(NNReachablility * reachablility);

+ (instancetype)reachablilty;
+ (nullable instancetype)reachabliltyWithHostname:(NSString *)hostname;
+ (nullable instancetype)reachabliltyWithHostAddress:(const struct sockaddr *)hostAddress;

@end
NS_ASSUME_NONNULL_END
