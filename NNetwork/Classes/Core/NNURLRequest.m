//
//  NNURLRequest.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import "NNURLRequest.h"
#import "NNURLRequestAgent.h"
#import "NNetworkPrivate.h"

#import <NNCore/NNCore.h>
#import <YYCache/YYCache.h>
#import <AFNetworking/AFNetworking.h>

@implementation NNURLRequest
@synthesize responseObject = _responseObject;

#pragma mark - Life Cycle

- (instancetype)init {
    
    if (self = [super init]) {
        self.priority = NSURLSessionTaskPriorityDefault;
        self.requestMethod = NNURLRequestMethodGET;
        self.cachePolicy = NSURLRequestReloadIgnoringCacheData;
        self.cacheTime = -1.f;
        self.timeoutInterval = kNNURLRequestTimeoutInterval;
        self.userInfo = nil;
        self.ignoredCancelled = YES;
    }
    return self;
}

- (instancetype)initWithServiceIdentifier:(NSString *)identifier
                              requestPath:(NSString *)requestPath
                            requestMethod:(NNURLRequestMethod)requestMethod {
    
    if (self = [super init]) {
     
        self.requestPath = requestPath;
        self.serviceIdentifier = identifier;
        self.requestMethod = requestMethod;
    }
    return self;
}


- (void)dealloc {
    
    self.completionHandler = NULL;
    self.interceptor = nil;
    self.paramInterceptor = nil;
    self.responseInterceptor = nil;
#if DEBUG
    NSLog(@"%@ is %@ing", self, NSStringFromSelector(_cmd));
#endif
}

#pragma mark - Override Methods

- (NSString *)description {
    
    NSMutableString *desc = [NSMutableString stringWithFormat:@"<%@: %p>{ URL: %@ } { method: %@ }", NSStringFromClass([self class]), self, self.currentRequest.URL, self.currentRequest.HTTPMethod];
    
    if (self.currentRequest.URL) {
        NSArray<NSHTTPCookie *> *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:self.currentRequest.URL];
        if (cookies.count) {
            [desc appendFormat:@"{ params: %@ } ", cookies];
        }
    }
    
    if (self.requestParams.count) {
        [desc appendFormat:@"{ params: %@ } ", self.requestParams];
    }
    if (self.error) {
        [desc appendFormat:@"{ error: %@ } ", self.error];
    }

    return [desc copy];
}

#pragma mark - Public Methods

- (void)startRequest {
    [self startRequestWithParams:nil completionHandler:NULL];
}

- (void)startRequestWithParams:(NSDictionary *)params {
    [self startRequestWithParams:params completionHandler:NULL];
}

- (void)startRequestWithParams:(NSDictionary *)params completionHandler:(NNURLRequestCompletionHandler)completionHandler {

    // 拼接agent中的通用参数
    NSAssert(self.agent, @"agent should not be nil");
    NSAssert(self.requestPath, @"you must implements requestPath in your class :%@",NSStringFromClass([self class]));

    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithDictionary:self.agent.commonParams];
    [requestParams addEntriesFromDictionary:params ? : @{}];
    
    // 拼接paramInterceptor中的参数
    if (self.paramInterceptor && [self.paramInterceptor respondsToSelector:@selector(paramsForRequest:)]) {
        [requestParams addEntriesFromDictionary:[self.paramInterceptor paramsForRequest:self]];
    }
    
    // 对现有的请求参数做加密处理
    if (self.paramInterceptor && [self.paramInterceptor respondsToSelector:@selector(signedParamsForRequest:params:)]) {
        NSDictionary *signedParams = [self.paramInterceptor signedParamsForRequest:self params:requestParams];
        [requestParams removeAllObjects];
        [requestParams addEntriesFromDictionary:signedParams ? : @{}];
    }

    self.requestParams = [requestParams copy];
    if (completionHandler) {
        self.completionHandler = completionHandler;
    }
    
    if (self.interceptor && [self.interceptor respondsToSelector:@selector(request:shouldContinueWithParams:)]) {
        BOOL shouldContinue = [self.interceptor request:self shouldContinueWithParams:requestParams];
        if (!shouldContinue) {
            [self requestDidCompletedWithError:kNNetworkError(NSURLErrorCancelled, @"用户取消请求")];
            return;
        }
    }
    
    __weak typeof(self) wSelf = self;
    switch (self.cachePolicy) {
        case NNURLRequestCachePolicyReturnCacheDataDontLoad:
        {
            [self loadReponseObjectFromCacheWithCompletionHandler:^(id cachedObject, NSError *error) {
                __strong typeof(wSelf) self = wSelf;
                [self requestDidCompletedWithCachedResponseObject:nil error:error];
            }];
        }
            break;
        case NNURLRequestCachePolicyReturnCacheDataElseLoad:
        {
            [self loadReponseObjectFromCacheWithCompletionHandler:^(id cachedObject, NSError *error) {
                __strong typeof(wSelf) self = wSelf;
                if (cachedObject && !error) {
                    [self requestDidCompletedWithCachedResponseObject:cachedObject error:error];
                } else {
                    [self.agent startRequest:self];
                }
            }];
        }
            break;
        case NNURLRequestCachePolicyReturnAndRefreshCacheData:
        {
            [self loadReponseObjectFromCacheWithCompletionHandler:^(id cachedObject, NSError *error) {
                __strong typeof(wSelf) self = wSelf;
                [self requestDidCompletedWithCachedResponseObject:cachedObject error:error];
                [self.agent startRequest:self];
            }];
        }
            break;
        case NNURLRequestCachePolicyInnoringCacheData:
        default:
        {
            dispatch_async(self.agent.sessionManager.completionQueue, ^{
                [self.agent startRequest:self];
            });
        }
            break;
    }
}

- (void)cancelRequest {

    [self.datatask cancel];
}

- (void)suspendRequest {

    if ([self.datatask isMemberOfClass:[NSURLSessionDownloadTask class]] && self.downloadPath.length) {
        __weak typeof(self) wSelf = self;
        [(NSURLSessionDownloadTask *)self.datatask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            dispatch_async(self.agent.sessionManager.completionQueue, ^{
                __strong typeof(wSelf) self = wSelf;
                if (resumeData != nil) [self cacheResumeData:resumeData];
            });
        }];
    } else {
        [self cancelRequest];
    }
}

#pragma mark - Private Methods

- (void)cacheResumeData:(nonnull NSData *)resumeData {
    [self.agent.cache.diskCache setObject:resumeData forKey:self.downloadPath.md5String];
}

- (void)loadReponseObjectFromCacheWithCompletionHandler:(nonnull void(^)(id cachedObject, NSError * error))handler {
    
    dispatch_async(self.agent.sessionManager.completionQueue, ^{
        NSString *cacheKey = [self.agent cacheKeyWithRequest:self];
        if ([self.agent.cache containsObjectForKey:cacheKey]) {
            NNURLRequestCacheMeta *cacheMeta = (NNURLRequestCacheMeta *)[self.agent.cache objectForKey:cacheKey];
            if (!cacheMeta.cachedData) {
                [self.agent.cache removeObjectForKey:cacheKey];
                handler(nil, kNNetworkError(NNURLRequestCacheErrorInvaildCacheData, @"缓存数据出错"));
                NNLogD(@"cache data is invalid");
            } else if (![cacheMeta.cachedVersion isEqualToString:self.cacheVersion]) {
                [self.agent.cache removeObjectForKey:cacheKey];
                handler(nil, kNNetworkError(NNURLRequestCacheErrorVersionMismatch, @"缓存数据版本不符"));
                NNLogD(@"cache data version is invalid");
            } else if ([cacheMeta.expiredDate timeIntervalSinceDate:[NSDate date]] <= 0) {
                [self.agent.cache removeObjectForKey:cacheKey];
                handler(nil, kNNetworkError(NNURLRequestCacheErrorExpired, @"缓存数据已过期"));
                NNLogD(@"cache data is expired");
            } else {
                handler([cacheMeta.cachedData jsonValueDecoded], nil);
            }
        } else {
            handler(nil, kNNetworkError(NNURLRequestCacheErrorExpired, @"缓存数据不存在"));
        }
    });
}

#pragma mark - Getter

- (NSURLRequest *)currentRequest {
    return self.datatask.currentRequest;
}

- (NSURLRequest *)originalRequest {
    return self.datatask.originalRequest;
}

- (NSHTTPURLResponse *)response {
    return (NSHTTPURLResponse *)self.datatask.response;
}

- (NSInteger)responseStatusCode {
    return self.response.statusCode;
}

- (NSDictionary *)responseHeaders {
    return self.response.allHeaderFields;
}

- (BOOL)isExecuting {
    if (self.datatask) { return self.datatask.state == NSURLSessionTaskStateRunning; }
    else return NO;
}

- (BOOL)isCancelled {
    
    if (self.error && self.error.code == NSURLErrorCancelled) { return YES; }
    else if (self.datatask && self.datatask.state == NSURLSessionTaskStateCanceling) { return YES; }
    else return NO;
}

- (BOOL)isAllowsCellularAccess {
    return _allowsCellularAccess;
}

- (NNURLRequestAgent *)agent {
    NSAssert(self.serviceIdentifier, @"you must implements serviceIdentifier in your class :%@",NSStringFromClass([self class]));
    return [NNURLRequestAgent agentWithIdentifier:self.serviceIdentifier];
}

- (BOOL)isFromCache {
    return _fromCache;
}

@end
