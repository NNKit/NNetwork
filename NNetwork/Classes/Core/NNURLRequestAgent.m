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

NSURL * NNCreateAbsoluteDownloadPath(NSString * downloadPath) {
    
    NSString *dirPath = [[NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.XMFraker.NNetwork"];
    
    NSString *filename = downloadPath;
    if ([downloadPath componentsSeparatedByString:@"/"].count) {
        
        NSArray<NSString *> *prefixDirs = [[downloadPath componentsSeparatedByString:@"/"] subarrayWithRange:NSMakeRange(0, [downloadPath componentsSeparatedByString:@"/"].count - 1)];
        if (prefixDirs.count) {
            dirPath = [dirPath stringByAppendingPathComponent:[prefixDirs componentsJoinedByString:@"/"]];
        }
        filename = [[downloadPath componentsSeparatedByString:@"/"] lastObject];
    }
    
    BOOL isDir = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) {
        NNLogD(@"downDir is not exists or is not a dir :%@, will recreate downDir", ((isDir == NO) ? @"YES" : @"NO"));
        NSError *error = nil;
        if (!isDir) { [[NSFileManager defaultManager] removeItemAtPath:dirPath error:&error]; }
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        NNLogD(@"create dir error :%@", error);
    }
    
    NNLogD(@"downDir is :%@",dirPath);
    NSString *absolutePath = [dirPath stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
        NNLogD(@"downPath is exists some object, will remove object");
        [[NSFileManager defaultManager] removeItemAtPath:absolutePath error:nil];
    }
    NNLogD(@"downPath is :%@",absolutePath);
    return [NSURL fileURLWithPath:absolutePath];
}

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
        
        _requestMappers = [NNMutableDictionary dictionary];
        _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:configuration ? : [NSURLSessionConfiguration defaultSessionConfiguration]];
        _sessionManager.session.configuration.HTTPMaximumConnectionsPerHost = 4;
        _sessionManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
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
                NSString *cacheKey = [self cacheKeyWithRequest:request];
                if ([self.cache.diskCache containsObjectForKey:cacheKey]) {
                    datatask = [self downloadTaskWithResumeData:(NSData *)[self.cache.diskCache objectForKey:cacheKey] downloadPath:request.downloadPath progressHandler:request.progressHandler];
                } else {
                    datatask = [self downloadTaskWithDownloadPath:request.downloadPath URLString:URLString params:params progressHandler:request.progressHandler error:&error];
                }
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


- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(nonnull NSData *)resumeData
                                            downloadPath:(nonnull NSString *)downloadPath
                                         progressHandler:(nullable NNURLRequestProgressHandler)progressHandler {
    
    NSAssert(resumeData, @"resumeData should not be nil");
    __weak typeof(self) wSelf = self;
    __block NSURLSessionDownloadTask *downloadTask = [self.sessionManager downloadTaskWithResumeData:resumeData progress:^(NSProgress *progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressHandler ? progressHandler(progress) : nil;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return NNCreateAbsoluteDownloadPath(downloadPath);
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
       __strong typeof(wSelf) self = wSelf;
        [self handleRequestResultWithDatatask:downloadTask responseObject:filePath error:error];
    }];
    return downloadTask;
}


- (NSURLSessionDownloadTask *)downloadTaskWithDownloadPath:(nullable NSString *)downloadPath
                                                 URLString:(nonnull NSString *)URLString
                                                    params:(nullable NSDictionary *)params
                                           progressHandler:(nullable NNURLRequestProgressHandler)progressHandler
                                                     error:(NSError * _Nullable __autoreleasing *)error {
    
    __weak typeof(self) wSelf = self;
    NSMutableURLRequest *request = [self.sessionManager.requestSerializer requestWithMethod:@"GET" URLString:URLString parameters:params error:error];
    __block NSURLSessionDownloadTask *downloadTask = [self.sessionManager downloadTaskWithRequest:request progress:^(NSProgress *progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressHandler ? progressHandler(progress) : nil;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return NNCreateAbsoluteDownloadPath(downloadPath);
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
    if (request == nil) return; // 此处选择忽略所有不存在请求
    
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

