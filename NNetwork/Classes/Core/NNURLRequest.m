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
        
        _priority = NSURLSessionTaskPriorityDefault;
        _requestMethod = NNURLRequestMethodGET;
        _cachePolicy = NNURLRequestCachePolicyInnoringCacheData;
        _cacheTime = -1.f;
        _timeoutInterval = kNNURLRequestTimeoutInterval;
        _userInfo = nil;
        _ignoredCancelled = YES;
    }
    return self;
}

- (instancetype)initWithServiceIdentifier:(NSString *)identifier
                              requestPath:(NSString *)requestPath
                            requestMethod:(NNURLRequestMethod)requestMethod {
    
    if (self = [super init]) {
     
        _requestPath = requestPath;
        _serviceIdentifier = identifier;
        _requestMethod = requestMethod;
    }
    return self;
}


- (void)dealloc {
    
    self.completionHandler = NULL;
    self.interceptor = nil;
    self.paramInterceptor = nil;
    self.responseInterceptor = nil;
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
    if (completionHandler) self.completionHandler = completionHandler;
    
    // 处理用户是否拦截对应请求
    if (self.interceptor && [self.interceptor respondsToSelector:@selector(request:shouldContinueWithParams:)]) {
        BOOL shouldContinue = [self.interceptor request:self shouldContinueWithParams:requestParams];
        if (!shouldContinue) {
            [self requestDidCompletedWithError:kNNetworkError(NSURLErrorCancelled, @"用户取消请求")];
            return;
        }
    }
    
    __weak typeof(self) wSelf = self;
    if (self.cachePolicy == NSURLRequestReloadIgnoringCacheData || self.downloadPath.length) {
        // 忽略缓存, 直接加载网络数据
        dispatch_async(self.agent.sessionManager.completionQueue, ^{
            __strong typeof(wSelf) self = wSelf;
            [self.agent startRequest:self];
        });
    } else {
        [self loadResponseObjectFromCacheWithCompletionHandler:^(id  _Nonnull cachedObject, NSError * _Nonnull error) {
            __strong typeof(wSelf) self = wSelf;
            switch (self.cachePolicy) {
                case NNURLRequestCachePolicyReturnCacheDataDontLoad:
                    [self requestDidCompletedWithCachedResponseObject:cachedObject error:error];
                    break;
                case NNURLRequestCachePolicyReturnCacheDataElseLoad:
                case NNURLRequestCachePolicyReturnAndRefreshCacheData:
                {
                    BOOL shouldContinue = YES;
                    if (cachedObject && !error) {
                        shouldContinue = self.cachePolicy != NNURLRequestCachePolicyReturnCacheDataElseLoad;
                        [self requestDidCompletedWithCachedResponseObject:cachedObject error:error];
                    }
                    if (shouldContinue) [self.agent startRequest:self];
                }
                    break;
                default:
                    [self.agent startRequest:self];
                    break;
            }
        }];
    }
}

- (void)cancelRequest {

    [self.datatask cancel];
    [self clearCachedResumeData];
    if (self.downloadPath.length) [self.agent.cache.diskCache removeObjectForKey:[self.agent cacheKeyWithRequest:self]];
}

- (void)suspendRequest {

    if ([self.datatask isKindOfClass:[NSURLSessionDownloadTask class]] && self.downloadPath.length) {
        __weak typeof(self) wSelf = self;
        [(NSURLSessionDownloadTask *)self.datatask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            __strong typeof(wSelf) self = wSelf;
            dispatch_async(self.agent.sessionManager.completionQueue, ^{
                __strong typeof(wSelf) self = wSelf;
                if (resumeData != nil) [self cacheResumeData:resumeData];
            });
        }];
    } else {
        [self cancelRequest];
    }
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

    if (self.datatask != nil && self.datatask.state == NSURLSessionTaskStateRunning) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isCancelled {
    
    if (self.error != nil && self.error.code == NSURLErrorCancelled) {
        return YES;
    } else if (self.datatask != nil && self.datatask.state == NSURLSessionTaskStateCanceling) {
        return YES;
    } else {
        return NO;
    }
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
