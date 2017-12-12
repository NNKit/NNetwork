//
//  NNURLRequest.h
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NNURLRequestMethod) {
    
    NNURLRequestMethodGET = 0,
    NNURLRequestMethodPOST,
    NNURLRequestMethodHEAD,
    NNURLRequestMethodPUT,
    NNURLRequestMethodDELETE,
    NNURLRequestMethodPATCH,
};

typedef NS_ENUM(NSUInteger, NNURLRequestSerializerType) {
    /** 默认请求头部的 Content-Type = application/x-www-form-urlencoded */
    NNURLRequestSerializerTypeHTTP = 0,
    /** 默认请求头部的 Content-Type = application/json */
    NNURLRequestSerializerTypeJSON,
};

typedef NS_ENUM(NSUInteger, NNResponseSerializerType) {
    /** 默认接收返回头部的 Content-Type = application/x-www-form-urlencoded */
    NNResponseSerializerTypeHTTP = 0,
    /** 默认接收返回头部的 Content-Type = application/json */
    NNResponseSerializerTypeJSON,
    NNResponseSerializerTypeXML
};

typedef NS_ENUM(NSUInteger, NNURLRequestCachePolicy) {
    /** 不使用缓存数据 */
    NNURLRequestCachePolicyInnoringCacheData = 0,
    /** 如果存在缓存数据则使用, 否则加载失败, 不去发起网络请求 */
    NNURLRequestCachePolicyReturnCacheDataDontLoad,
    /** 如果存在缓存数据则使用, 否则发起网络请求, 加载缓存数据 */
    NNURLRequestCachePolicyReturnCacheDataElseLoad,
    /** 如果存在缓存数据先使用, 并且发起网络请求, 刷新缓存数据 */
    NNURLRequestCachePolicyReturnAndRefreshCacheData
};

@class NNURLRequest;
@protocol AFMultipartFormData;
typedef void(^NNURLRequestCompletionHandler)(__kindof NNURLRequest *request);
typedef void(^NNURLRequestConstructingHandler)(id<AFMultipartFormData> formData);
typedef void(^NNURLRequestProgressHandler)(NSProgress * progress);

@protocol NNURLRequestInterceptor <NSObject>

@optional

/**
 请求参数全部处理完成后
 
 @param request 具体请求
 @param params  将要发送的请求参数
 @return YES or NO
 */
- (BOOL)request:(__kindof NNURLRequest *)request shouldContinueWithParams:(nullable NSDictionary *)params;

@end

@protocol NNURLRequestParamInterceptor <NSObject>

@optional

/**
 对拼接完成的请求参数 做加密处理

 @discussion 实现此方法后, 会重置所有的请求参数, 直接使用Returns返回的请求参数
 @param request NNURLRequest对象
 @param params  已经拼接完成的请求参数 startParams + commonParams + paramInterceptorParams
 @return 新的请求参数
 */
- (nullable NSDictionary *)signedParamsForRequest:(__kindof NNURLRequest *)request params:(nullable NSDictionary *)params;

/**
 实现request的请求参数代理

 @discussion 此方法中参数,可以覆盖 startParams, commonParams
 @param request NNURLRequest对象
 @return request对应的请求参数
 */
- (nullable NSDictionary *)paramsForRequest:(__kindof NNURLRequest *)request;

@end

@protocol NNURLRequestResponseInterceptor <NSObject>

@optional

/**
 请求完成后, 根据请求结果用户可以自己决定是否缓存当前request请求结果
 可以根据业务结果选择是否缓存请求结果
 
 @param request 具体请求对象
 @return YES or NO
 */
- (BOOL)requestShouldCacheResponse:(__kindof NNURLRequest *)request;

@required

/**
 对request.responseObject进行重新赋值操作
 可以自行处理解析responseObject等操作
 
 @param request NNRequest对象
 @param error   处理报错, 可能是网络请求的错误信息, 或者缓存相关错误
 @return 解析后的responseObject or nil
 */
- (nullable id)responseObjectForRequest:(__kindof NNURLRequest *)request error:(nullable NSError *)error;
@end

@interface NNURLRequest : NSObject

#pragma mark - Property

@property (weak, nonatomic, nullable) id<NNURLRequestInterceptor> interceptor;
@property (weak, nonatomic, nullable) id<NNURLRequestParamInterceptor> paramInterceptor;
@property (weak, nonatomic, nullable) id<NNURLRequestResponseInterceptor> responseInterceptor;
@property (copy, nonatomic, nullable) NNURLRequestCompletionHandler completionHandler;
@property (copy, nonatomic, nullable) NNURLRequestProgressHandler progressHandler;
@property (copy, nonatomic, nullable) NNURLRequestConstructingHandler constructingHandler;;

/** request.userInfo */
@property (copy, nonatomic, nullable) NSDictionary *userInfo;
/** 网络请求task, 如果从缓存中获取数据 */
@property (strong, nonatomic, readonly, nullable) __kindof NSURLSessionTask *datatask;
/** datatask.currentRequest 快捷方式 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *currentRequest;
/** datatask.originalRequest 快捷方式 */
@property (strong, nonatomic, readonly, nullable) NSURLRequest *originalRequest;
/** datatask.response 快捷方式 */
@property (strong, nonatomic, readonly, nullable) NSHTTPURLResponse *response;
/** response.statusCode 快捷方式 */
@property (assign, nonatomic, readonly)           NSInteger responseStatusCode;
/** response.allHeaderFields 快捷方式 */
@property (copy, nonatomic, readonly, nullable)   NSDictionary *responseHeaders;

/** 当前请求是否正在请求中 */
@property (assign, nonatomic, readonly, getter=isExecuting) BOOL isExecuting;
/** 当前请求是否被取消的请求 */
@property (assign, nonatomic, readonly, getter=isCancelled) BOOL isCancelled;
/** 最终请求发出后使用的请求参数 */
@property (copy, nonatomic, readonly, nullable)   NSDictionary *requestParams;

/// ========================================
/// @name   相关返回结果
/// ========================================

/** 此responseObject 可能是经过responseInterceptor 处理过的responseObject **/
@property (strong, nonatomic, readonly, nullable) id responseObject;
@property (copy, nonatomic, readonly, nullable)   NSData *responseData;
@property (copy, nonatomic, readonly, nullable)   NSString *responseString;
@property (strong, nonatomic, readonly, nullable) id responseJSONObject;
@property (strong, nonatomic, readonly, nullable) NSError *error;
/** request 数据 是否存cache中获取的 */
@property (assign, nonatomic, readonly, getter=isFromCache) BOOL fromCache;

/// ========================================
/// @name   子类必须实现的属性
/// ========================================

@property (copy, nonatomic, readonly)   NSString *requestPath;
@property (copy, nonatomic, readonly)   NSString *serviceIdentifier;
@property (assign, nonatomic, readonly) NNURLRequestMethod requestMethod;

/// ========================================
/// @name   Properties For Subclass Override
/// ========================================

/** 请求优先级 默认 .5f */
@property (assign, nonatomic) float priority;
/** 请求超时时间 默认 20.f*/
@property (assign, nonatomic) NSTimeInterval timeoutInterval;
/** 是否忽略被取消的请求, 不会执行completionHander 默认YES */
@property (assign, nonatomic) BOOL ignoredCancelled;
/** HTTP 请求授权使用的userName,password 示例 @[@"username",@"password"] */
@property (copy, nonatomic, nullable)   NSArray<NSString *> *authorizationHeaderFields;

/**
 *  是否允许网络请求使用蜂窝网络数据
 *
 *  @see NSMutableURLRequest -setAllowsCellularAccess:
 *  默认 YES
 **/
@property (assign, nonatomic, getter=isAllowsCellularAccess) BOOL allowsCellularAccess;

/** 下载文件的下载地址 默认存放 ~/Downloads/com.XMFraker.NNetwork + downloadPath */
@property (copy, nonatomic, nullable)   NSString *downloadPath;

/// ========================================
/// @name   缓存相关属性设置
/// ========================================

/** request 缓存版本 */
@property (copy, nonatomic)   NSString *cacheVersion;
/** request 缓存时间 */
@property (assign, nonatomic) NSTimeInterval cacheTime;
/** request 缓存策略 默认  NNURLRequestCachePolicyInnoringCacheData **/
@property (assign, nonatomic) NNURLRequestCachePolicy cachePolicy;

#pragma mark - Life Cycle

/**
 实例化NNURLRequest

 @param identifier      NNURLRequestAgent.serviceIdentifier
 @param requestPath     NNURLRequest.requestPath
 @param requestMethod   NNURLRequest.requestMethod
 @return NNURLRequest
 */
- (instancetype)initWithServiceIdentifier:(NSString *)identifier
                              requestPath:(NSString *)requestPath
                            requestMethod:(NNURLRequestMethod)requestMethod;

#pragma mark - Request Method

/** 开始请求 */
- (void)startRequest;

/**
 开始请求

 @param params 请求参数
 */
- (void)startRequestWithParams:(nullable NSDictionary *)params;


/**
 开始请求

 @param params 请求参数
 @param completionHandler 请求完成回调
 */
- (void)startRequestWithParams:(nullable NSDictionary *)params
             completionHandler:(nullable NNURLRequestCompletionHandler)completionHandler;

/**
 取消请求任务
 @discussion 如果是下载任务, 统一调用[NSURLSessionDataTask cancel], 不会存储已下载的数据
 
 */
- (void)cancelRequest;

/**
 暂停请求
 @discussion 如果是下载任务,并且存在downloadPath, 则调用 [NSURLSessionDownloadTask cancelByProducingResumeData:], 其他作用等同于cancelRequest
 
 */
- (void)suspendRequest;

@end

NS_ASSUME_NONNULL_END
