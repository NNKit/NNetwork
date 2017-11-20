//
//  NNetworkPrivate.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import "NNetworkPrivate.h"
#import <NNCore/NNCore.h>
#import <YYCache/YYCache.h>

NSString *const kNNetworkErrorDomain = @"com.XMFraker.NNetwork.Error";

@implementation NNURLRequestCacheMeta

+ (instancetype)cacheMetaWithRequest:(__kindof NNURLRequest *)request {
    
    return [[NNURLRequestCacheMeta alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(__kindof NNURLRequest *)request {
    
    if (self = [super init]) {

        self.cachedResponseHeaders = request.responseHeaders;
        self.cachedData = [request.responseObject yy_modelToJSONData];
        self.cachedVersion = request.cacheVersion;
        self.expiredDate = [NSDate dateWithTimeIntervalSinceNow:request.cacheTime];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    return [self yy_modelEncodeWithCoder:aCoder];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self yy_modelInitWithCoder:aDecoder];
}

@end

@implementation NNURLRequest (NNPrivate)

- (void)requestDidCompletedWithError:(NSError *)error {

    self.error = error;
    if (self.responseInterceptor && [self.responseInterceptor respondsToSelector:@selector(responseObjectForRequest:error:)]) {
        self.responseObject = [self.responseInterceptor responseObjectForRequest:self error:self.error];
    }

    if (self.error == nil) {
        BOOL shouldCache = (self.cachePolicy != NNURLRequestCachePolicyInnoringCacheData) && self.cacheTime > .0f;
        if (self.responseInterceptor && [self.responseInterceptor respondsToSelector:@selector(requestShouldCacheResponse:)]) {
            shouldCache = [self.responseInterceptor requestShouldCacheResponse:self];
        }
        if (shouldCache) {
            NNURLRequestCacheMeta *cacheMeta = [NNURLRequestCacheMeta cacheMetaWithRequest:self];
            NSString *cacheKey = [self.agent cacheKeyWithRequest:self];
            [self.agent.cache setObject:cacheMeta forKey:cacheKey];
            NNLogD(@"request will cache responseObject");
        } else {
            NNLogD(@"request will not cache responseObject");
        }
    }
    
    if (self.ignoredCancelled && self.isCancelled) {
        NNLogD(@"%@ is ignored request", self);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.completionHandler ? self.completionHandler(self) : nil;
    });
}

- (void)requestDidCompletedWithCachedResponseObject:(id)cachedResponseObject error:(NSError *)error {
    
    self.error = error;
    self.responseObject = self.responseJSONObject = cachedResponseObject;
    if (self.responseInterceptor && [self.responseInterceptor respondsToSelector:@selector(responseObjectForRequest:error:)]) {
        self.responseObject = [self.responseInterceptor responseObjectForRequest:self error:self.error];
    }
    self.fromCache = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.completionHandler ? self.completionHandler(self) : nil;
    });
}

@end

@implementation NNURLRequestAgent (NNPrivate)

- (NSString *)absoluteURLStringWithRequest:(__kindof NNURLRequest *)request params:(NSDictionary **)params {

    __block NSString *requestPath = request.requestPath;
    NSMutableDictionary *remainParams = [NSMutableDictionary dictionaryWithDictionary:request.requestParams];
    NSMutableArray *removedKeys = [NSMutableArray array];
    [request.requestParams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        
        NSString *pathKey = [NSString stringWithFormat:@"{%@}",key];
        if ([requestPath containsString:pathKey]) {
            requestPath = [requestPath stringByReplacingOccurrencesOfString:pathKey withString:[NSString stringWithFormat:@"%@",obj]];
            [removedKeys addObject:key];
        }
        
        pathKey = [NSString stringWithFormat:@":%@",key];
        if ([requestPath containsString:pathKey]) {
            requestPath = [requestPath stringByReplacingOccurrencesOfString:pathKey withString:[NSString stringWithFormat:@"%@",obj]];
            [removedKeys addObject:key];
        }
    }];
    removedKeys.count ? [remainParams removeObjectsForKeys:removedKeys] : nil;
    params ? *params = [remainParams copy] : nil;
    return [NSURL URLWithString:requestPath relativeToURL:[NSURL URLWithString:self.baseURL]].absoluteString;
}

- (NSString *)cacheKeyWithRequest:(__kindof NNURLRequest *)request {
    
    NSMutableString *ret = [NSMutableString stringWithString:[self absoluteURLStringWithRequest:request params:nil]];
    if (ret.length && [NSURL URLWithString:ret]) {

        NSArray<NSHTTPCookie *> *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:ret]];
        NSString *cookieMD5 = [[[cookies map:^id _Nonnull(NSHTTPCookie * _Nonnull obj, NSInteger index) {
            return [[[obj properties] yy_modelToJSONData] md5String];
        }] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
        if (cookieMD5 && cookieMD5.length) {
            [ret appendFormat:@"Cookie :%@\n",cookies];
        }
    }
    [ret appendFormat:@"Method :%lu\n",(unsigned long)request.requestMethod];
    [ret appendFormat:@"Params :%@\n",request.requestParams ? : @{}];
    return [ret md5String];
}

@end
