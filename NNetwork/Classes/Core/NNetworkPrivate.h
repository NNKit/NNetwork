//
//  NNetworkPrivate.h
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import <NNCore/NNCore.h>
#import <NNetwork/NNURLRequestAgent.h>

NS_ASSUME_NONNULL_BEGIN

static inline NSStringEncoding kNNStringEncodingFromRequest(__kindof NNURLRequest * request) {
    // From AFNetworking 2.6.3
    NSStringEncoding stringEncoding = NSUTF8StringEncoding;
    if (request.response.textEncodingName) {
        CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)request.response.textEncodingName);
        if (encoding != kCFStringEncodingInvalidId) {
            stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
        }
    }
    return stringEncoding;
}

FOUNDATION_EXPORT NSString *const kNNetworkErrorDomain;
static inline NSError * kNNetworkError(NSInteger code, NSString * message) {
    return [NSError errorWithDomain:kNNetworkErrorDomain code:code userInfo: message ? @{@"message" :message} : nil];
}

NS_ENUM(NSUInteger) {
    NNURLRequestCacheErrorExpired = -201,
    NNURLRequestCacheErrorUnexists = -100,
    NNURLRequestCacheErrorVersionMismatch = -202,
    NNURLRequestCacheErrorInvaildCacheData = -203,
};

/** 默认请求超时时间 20s */
static CGFloat const kNNURLRequestTimeoutInterval = 20.f;

@interface NNURLRequestCacheMeta : NSObject <NSCoding>

/** request 缓存版本 */
@property (copy, nonatomic)   NSString *cachedVersion;
/** request 缓存过期时间 */
@property (copy, nonatomic)   NSDate *expiredDate;
/** request 缓存的具体数据 */
@property (copy, nonatomic)   NSData *cachedData;
/** request 缓存的response.headers */
@property (copy, nonatomic)   NSDictionary *cachedResponseHeaders;

- (instancetype)initWithRequest:(__kindof NNURLRequest *)request;
+ (instancetype)cacheMetaWithRequest:(__kindof NNURLRequest *)request;

@end

@class YYCache;
@class NNURLRequestAgent;
@interface NNURLRequest ()

@property (copy, nonatomic, readwrite, nullable)    NSData *responseData;
@property (copy, nonatomic, readwrite, nullable)    NSString *responseString;
@property (strong, nonatomic, readwrite, nullable)  id responseObject;
@property (strong, nonatomic, readwrite, nullable)  id responseJSONObject;
@property (strong, nonatomic, readwrite, nullable)  NSError *error;

@property (strong, nonatomic, readwrite)            NSURLSessionDataTask *datatask;
@property (copy, nonatomic, readwrite)              NSString *requestPath;
@property (copy, nonatomic, readwrite)              NSString *serviceIdentifier;
@property (copy, nonatomic, readwrite, nullable)    NSDictionary *requestParams;
@property (assign, nonatomic, readwrite)            NNURLRequestMethod requestMethod;

@property (assign, nonatomic) BOOL fromCache;

@property (strong, nonatomic, readonly) NNURLRequestAgent *agent;
@end
    
@class AFHTTPSessionManager;
@interface NNURLRequestAgent ()
@property (strong, nonatomic) YYCache *cache;
@property (strong, nonatomic) AFHTTPSessionManager *sessionManager;
@property (strong, nonatomic) NNMutableDictionary<NSNumber *, __kindof NNURLRequest *> *requestMappers;
@end
    
@interface NNURLRequestAgent (NNPrivate)
- (NSString *)absoluteURLStringWithRequest:(__kindof NNURLRequest *)request params:(NSDictionary * _Nullable * _Nullable)params;
- (NSString *)cacheKeyWithRequest:(__kindof NNURLRequest *)request;
@end

@interface NNURLRequest (NNPrivate)

/** 清除已经缓存的 下载数据 */
- (void)clearCachedResumeData;


/**
 缓存下载数据, 以备继续下载

 @param resumeData 已经下载的数据
 */
- (void)cacheResumeData:(nonnull NSData *)resumeData;

- (void)loadResponseObjectFromCacheWithCompletionHandler:(nonnull void(^)(id cachedObject, NSError * error))handler;

/**
 请求完成后调用
 
 @discussion  dataTask 请求完成后回调
 @param error 错误信息
 */
- (void)requestDidCompletedWithError:(nullable NSError *)error;

/**
 从缓存中获取正确缓存数据后回调
 
 @discussion  从缓存中获取数据后回到
 @param cachedResponseObject 缓存数据
 @param error 错误信息
 */
- (void)requestDidCompletedWithCachedResponseObject:(nullable id)cachedResponseObject error:(nullable NSError *)error;
@end

NS_ASSUME_NONNULL_END
