//
//  NNURLRequestAgent.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import "NNURLRequestAgent.h"
#import "NNetworkPrivate.h"

#import <NNCore/NNCore.h>
#import <YYCache/YYCache.h>
#import <AFNetworking/AFNetworking.h>

/** 记录当前所有可用的service */
static NNMutableDictionary<NSString *, __kindof NNURLRequestAgent *> *kNNURLRequestAgentDictionary;

@implementation NNURLRequestAgent

#pragma mark - Life Cycle

+ (void)initialize {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kNNURLRequestAgentDictionary = [NNMutableDictionary dictionary];
    });
}

- (instancetype)init {
    return [self initWithConfiguration:nil];
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    
    if (self = [super init]) {
        
        self.requestMappers = [NNMutableDictionary dictionary];
        self.sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:configuration ? : [NSURLSessionConfiguration defaultSessionConfiguration]];
        self.sessionManager.session.configuration.HTTPMaximumConnectionsPerHost = 4;
        self.sessionManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.requestSerializerType = NNURLRequestSerializerTypeHTTP;
        self.responseSerializerType = NNResponseSerializerTypeHTTP;

        if (self.cachePath.length) {
            self.cache = [YYCache cacheWithPath:self.cachePath];
        } else {
            self.cache = [YYCache cacheWithName:@"com.XMFraker.NNetwork.cache"];
        }
    }
    return self;
}

#pragma mark - Public Methods

- (void)startRequest:(__kindof NNURLRequest *)request {
    
    NSParameterAssert(request != nil);
    NSDictionary *params = nil;
    NSString *URLString = [self absoluteURLStringWithRequest:request params:&params];

    AFHTTPRequestSerializer *serializer = self.sessionManager.requestSerializer;
    serializer.allowsCellularAccess = request.allowsCellularAccess;
    serializer.timeoutInterval = request.timeoutInterval;
    if (request.authorizationHeaderFields.count == 2) {
        [serializer setAuthorizationHeaderFieldWithUsername:[request.authorizationHeaderFields firstObject]
                                                   password:[request.authorizationHeaderFields lastObject]];
    }

    NSError *error;
    __kindof NSURLSessionTask *datatask = nil;
    switch (request.requestMethod) {
        case NNURLRequestMethodPOST:
            datatask = [self dataTaskWithHTTPMethod:@"POST" URLString:URLString params:params progressHandler:request.progressHandler constructingHandler:request.constructingHandler error:&error];
            break;
        case NNURLRequestMethodPUT:
            datatask = [self dataTaskWithHTTPMethod:@"PUT" URLString:URLString params:params progressHandler:nil constructingHandler:nil error:&error];
            break;
        case NNURLRequestMethodHEAD:
            datatask = [self dataTaskWithHTTPMethod:@"HEAD" URLString:URLString params:params progressHandler:nil constructingHandler:nil error:&error];
            break;
        case NNURLRequestMethodPATCH:
            datatask = [self dataTaskWithHTTPMethod:@"PATCH" URLString:URLString params:params progressHandler:nil constructingHandler:nil error:&error];
            break;
        case NNURLRequestMethodDELETE:
            datatask = [self dataTaskWithHTTPMethod:@"DELETE" URLString:URLString params:params progressHandler:nil constructingHandler:nil error:&error];
            break;
        case NNURLRequestMethodGET:
        {
            if (request.downloadPath.length) {
                datatask = [self downloadTaskWithDownloadPath:request.downloadPath URLString:URLString params:params progressHandler:request.progressHandler constructingHandler:nil error:&error];
            } else {
                datatask = [self dataTaskWithHTTPMethod:@"GET" URLString:URLString params:params progressHandler:nil constructingHandler:nil error:&error];
            }
        }
            break;
    }
    
    if (error) {
        [request requestDidCompletedWithError:error];
    } else {
        datatask.priority = request.priority;
        request.datatask = datatask;
        [self.requestMappers setObject:request forKey:@(datatask.taskIdentifier)];
        [datatask resume];
    }
}

#pragma mark - Private Methods

- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                          params:(nullable NSDictionary *)params
                                 progressHandler:(nullable NNURLRequestProgressHandler)progressHandler
                             constructingHandler:(nullable NNURLRequestConstructingHandler)constructingHandler
                                           error:(NSError * _Nullable __autoreleasing *)error {
    
    NSMutableURLRequest *request = nil;
    if (constructingHandler) {
        request = [self.sessionManager.requestSerializer multipartFormRequestWithMethod:method URLString:URLString parameters:params constructingBodyWithBlock:constructingHandler error:error];
    } else {
        request = [self.sessionManager.requestSerializer requestWithMethod:method URLString:URLString parameters:params error:error];
    }
    __weak typeof(self) wSelf = self;
    __block NSURLSessionDataTask *task = [self.sessionManager dataTaskWithRequest:request uploadProgress:progressHandler downloadProgress:progressHandler completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        __strong typeof(wSelf) self = wSelf;
        [self handleRequestResultWithDatatask:task responseObject:responseObject error:error];
    }];
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(nullable NSString *)downloadPath
                                                 URLString:(nullable NSString *)URLString
                                                    params:(nullable NSDictionary *)params
                                           progressHandler:(nullable NNURLRequestProgressHandler)progressHandler
                                       constructingHandler:(nullable NNURLRequestConstructingHandler)constructingHandler
                                                     error:(NSError * _Nullable __autoreleasing *)error {
    
    __weak typeof(self) wSelf = self;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    if (downloadPath.length && [self.cache.diskCache containsObjectForKey:downloadPath.md5String]) {
        
        downloadTask = [self.sessionManager downloadTaskWithResumeData:(NSData *)[self.cache.diskCache objectForKey:downloadPath.md5String] progress:progressHandler destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadPath];
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            __strong typeof(wSelf) self = wSelf;
            [self handleRequestResultWithDatatask:downloadTask responseObject:filePath error:error];
        }];
        return downloadTask;
    }
    NSMutableURLRequest *request = [self.sessionManager.requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:params error:error];
    downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:progressHandler destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:downloadPath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        __strong typeof(wSelf) self = wSelf;
        [self handleRequestResultWithDatatask:downloadTask responseObject:filePath error:error];
    }];
    return downloadTask;
}


- (void)handleRequestResultWithDatatask:(nonnull __kindof NSURLSessionTask *)datatask
                         responseObject:(nullable id)responseObject
                                  error:(nullable NSError *)error {
    
    NNURLRequest *request = [self.requestMappers safeObjectForKey:@(datatask.taskIdentifier)];
    if (!request) {
        // 此处选择忽略所有不存在请求
        return;
    }
    
    if ([responseObject isKindOfClass:[NSData class]]) {
        request.responseObject = request.responseData = responseObject;
        request.responseString = [[NSString alloc] initWithData:responseObject encoding:kNNStringEncodingFromRequest(request)];
    } else if ([NSJSONSerialization isValidJSONObject:responseObject]) {
        request.responseObject = request.responseJSONObject = responseObject;
        request.responseData = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil];
        request.responseString = [[NSString alloc] initWithData:request.responseData encoding:kNNStringEncodingFromRequest(request)];
    } else if ([responseObject isKindOfClass:[NSURL class]]) {
        // 处理
        request.responseObject = responseObject;
        request.responseString = [(NSURL *)responseObject absoluteString];
    } else {
        request.responseObject = responseObject;
    }
    
    [request requestDidCompletedWithError:error];
    [self.requestMappers removeObjectForKey:@(request.datatask.taskIdentifier)];

    NNLogD(@"receive responseObject :%@ -- mainThread: %@",responseObject, [NSThread isMainThread] ? @"YES" : @"NO");
}

#pragma mark - Setter

- (void)setRequestSerializerType:(NNURLRequestSerializerType)requestSerializerType {
    
    AFHTTPRequestSerializer *serializer = nil;
    if (requestSerializerType == NNURLRequestSerializerTypeJSON) {
        serializer = [AFJSONRequestSerializer serializer];
    } else {
        serializer = [AFHTTPRequestSerializer serializer];
    }
    serializer.timeoutInterval = kNNURLRequestTimeoutInterval;
    serializer.HTTPShouldHandleCookies = YES;
    serializer.cachePolicy = NSURLRequestUseProtocolCachePolicy;
    if (self.commonHeaders) {
        [self.commonHeaders enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            [serializer setValue:obj forHTTPHeaderField:key];
        }];
    }
    self.sessionManager.requestSerializer = serializer;
}

- (void)setResponseSerializerType:(NNResponseSerializerType)responseSerializerType {
    
    AFHTTPResponseSerializer *serializer = nil;
    if (responseSerializerType == NNResponseSerializerTypeHTTP) {
        serializer = [AFJSONResponseSerializer serializer];
    } else if (responseSerializerType == NNResponseSerializerTypeXML){
        serializer = [AFXMLParserResponseSerializer serializer];
    } else {
        serializer = [AFHTTPResponseSerializer serializer];
    }
    self.sessionManager.responseSerializer = serializer;
}

- (void)setSecurityPolicy:(AFSecurityPolicy *)securityPolicy {
    self.sessionManager.securityPolicy = securityPolicy;
}

#pragma mark - Getter

- (AFSecurityPolicy *)securityPolicy {
    return self.sessionManager.securityPolicy;
}

- (NNURLRequestSerializerType)requestSerializerType {
    return [self.sessionManager.requestSerializer isKindOfClass:[AFJSONRequestSerializer class]] ? NNURLRequestSerializerTypeJSON : NNURLRequestSerializerTypeHTTP;
}

- (NNResponseSerializerType)responseSerializerType {
    
    AFHTTPResponseSerializer *serializer = self.sessionManager.responseSerializer;
    if ([serializer isKindOfClass:[AFJSONResponseSerializer class]]) {
        return NNResponseSerializerTypeJSON;
    } else if ([serializer isKindOfClass:[AFXMLParserResponseSerializer class]]) {
        return NNResponseSerializerTypeXML;
    } else {
        return NNResponseSerializerTypeHTTP;
    }
}

- (NSDictionary *)commonParams { return @{}; }
- (NSDictionary *)commonHeaders { return @{}; }
- (NSString *)baseURL { return @""; }


@end

@implementation NNURLRequestAgent (NNAgentManage)
#pragma mark - Class Methods

+ (void)storeAgent:(__kindof NNURLRequestAgent *)agent withIdentifier:(NSString *)identifier {
    NSParameterAssert(agent);
    NSParameterAssert([identifier isNotBlank]);
    [kNNURLRequestAgentDictionary setObject:agent forKey:identifier];
}

+ (nullable __kindof NNURLRequestAgent *)agentWithIdentifier:(NSString *)identifier {
    NSParameterAssert([identifier isNotBlank]);
    return [kNNURLRequestAgentDictionary safeObjectForKey:identifier];
}

+ (nullable NSArray<__kindof NNURLRequestAgent *> *)storedAgents {
    return [kNNURLRequestAgentDictionary allValues];
}

+ (void)configModeForStoredAgents:(NNURLRequestAgentMode)mode {
    [[NNURLRequestAgent storedAgents] execute:^(__kindof NNURLRequestAgent * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.mode = mode;
    }];
}
@end

