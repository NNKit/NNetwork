//
//  NNReachablility.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/17.
//

#import "NNReachablility.h"
#import <objc/message.h>
#import <NNCore/NNCore.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

@interface NNReachablility ()

@property (assign, nonatomic) BOOL allowsWWAN;
@property (assign, nonatomic) BOOL scheduled;
@property (assign, nonatomic) SCNetworkReachabilityRef ref;
@property (strong, nonatomic) CTTelephonyNetworkInfo *netinfo;

@end

static NNReachablilityStatus NNReachabilityStatusFromFlags(SCNetworkReachabilityFlags flags, BOOL allowWWAN) {
    
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return NNReachablilityStatusNone;
    }
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
        (flags & kSCNetworkReachabilityFlagsTransientConnection)) {
        return NNReachablilityStatusNone;
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) && allowWWAN) {
        return NNReachablilityStatusWWAN;
    }
    
    return NNReachablilityStatusWiFi;
}

static void NNReachabliltyCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *context) {
    
    NNReachablility *reachability = ((__bridge NNReachablility *)context);
    if (target == reachability.ref && reachability.notifyHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            reachability.notifyHandler(reachability);
        });
    }
}

@implementation NNReachablility

#pragma mark - Life Cycle

- (instancetype)init {
    /*
     See Apple's Reachability implementation and readme:
     The address 0.0.0.0, which reachability treats as a special token that
     causes it to actually monitor the general routing status of the device,
     both IPv4 and IPv6.
     https://developer.apple.com/library/ios/samplecode/Reachability/Listings/ReadMe_md.html#//apple_ref/doc/uid/DTS40007324-ReadMe_md-DontLinkElementID_11
     */
    struct sockaddr_in zero_addr;
    bzero(&zero_addr, sizeof(zero_addr));
    zero_addr.sin_len = sizeof(zero_addr);
    zero_addr.sin_family = AF_INET;
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zero_addr);
    return [self initWithRef:ref];
}

- (instancetype)initWithRef:(SCNetworkReachabilityRef)ref {
    
    if (!ref) return nil;
    if (self = [super init]) {
        _ref = ref;
        _allowsWWAN = YES;
        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0) {
            _netinfo = [CTTelephonyNetworkInfo new];
        }
    }
    return self;
}

+ (instancetype)reachablilty {
    return [[self alloc] init];
}

+ (instancetype)reachabliltyWithHostname:(NSString *)hostname {
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
    return [[self alloc] initWithRef:ref];
}

+ (instancetype)reachabliltyWithHostAddress:(const struct sockaddr *)hostAddress {
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);
    return [[self alloc] initWithRef:ref];
}

- (void)dealloc {
    
    self.scheduled = NO;
    self.notifyHandler = nil;
    CFRelease(self.ref);
    NSLog(@"%@ is %@ing", self, NSStringFromSelector(_cmd));
}

#pragma mark - Setter

- (void)setNotifyHandler:(void (^)(NNReachablility * _Nonnull))notifyHandler {
    _notifyHandler = [notifyHandler copy];
    self.scheduled = notifyHandler != nil;
}

static dispatch_queue_t kNNReachabliltyDispatchQueue = nil;
- (void)setScheduled:(BOOL)scheduled {
    if (_scheduled == scheduled) { return; }
    _scheduled = scheduled;
    if (scheduled) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kNNReachabliltyDispatchQueue = dispatch_queue_create("com.XMFraker.NNetwork.kNNReachabliltyDispatchQueue", DISPATCH_QUEUE_SERIAL);
        });
        SCNetworkReachabilityContext  context = { 0, ((__bridge void *) self), NULL, NULL, NULL };
        SCNetworkReachabilitySetCallback(self.ref, NNReachabliltyCallback, &context);
        SCNetworkReachabilitySetDispatchQueue(self.ref, kNNReachabliltyDispatchQueue);
    } else {
        SCNetworkReachabilitySetDispatchQueue(self.ref, NULL);
    }
}

#pragma mark - Getter

- (BOOL)isReachable {
    return self.status != NNReachablilityStatusNone;
}

- (SCNetworkReachabilityFlags)flags {
    SCNetworkReachabilityFlags ret = 0;
    SCNetworkReachabilityGetFlags(self.ref, &ret);
    return ret;
}

- (NNReachablilityStatus)status {
    return NNReachabilityStatusFromFlags(self.flags, self.allowsWWAN);
}

- (NNReachablilityWWANStatus)wwanStatus {
    if (!self.netinfo) return NNReachablilityWWANStatusNone;
    if (!self.netinfo.currentRadioAccessTechnology) return NNReachablilityWWANStatusNone;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = @{CTRadioAccessTechnologyGPRS : @(NNReachablilityWWANStatus2G),  // 2.5G   171Kbps
                CTRadioAccessTechnologyEdge : @(NNReachablilityWWANStatus2G),  // 2.75G  384Kbps
                CTRadioAccessTechnologyWCDMA : @(NNReachablilityWWANStatus3G), // 3G     3.6Mbps/384Kbps
                CTRadioAccessTechnologyHSDPA : @(NNReachablilityWWANStatus3G), // 3.5G   14.4Mbps/384Kbps
                CTRadioAccessTechnologyHSUPA : @(NNReachablilityWWANStatus3G), // 3.75G  14.4Mbps/5.76Mbps
                CTRadioAccessTechnologyCDMA1x : @(NNReachablilityWWANStatus3G), // 2.5G
                CTRadioAccessTechnologyCDMAEVDORev0 : @(NNReachablilityWWANStatus3G),
                CTRadioAccessTechnologyCDMAEVDORevA : @(NNReachablilityWWANStatus3G),
                CTRadioAccessTechnologyCDMAEVDORevB : @(NNReachablilityWWANStatus3G),
                CTRadioAccessTechnologyeHRPD : @(NNReachablilityWWANStatus3G),
                CTRadioAccessTechnologyLTE : @(NNReachablilityWWANStatus4G)}; // LTE:3.9G 150M/75M  LTE-Advanced:4G 300M/150M
    });
    NSNumber *num = [dic safeObjectForKey:self.netinfo.currentRadioAccessTechnology];
    if (num != nil) return num.unsignedIntegerValue;
    else return NNReachablilityWWANStatusNone;
}

@end
