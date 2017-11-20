//
//  NNURLRequestAgent.h
//  NNetwork
//
//  Created by XMFraker on 2017/11/14.
//

#import <Foundation/Foundation.h>
#import <NNetwork/NNURLRequest.h>

typedef NS_ENUM(NSUInteger, NNURLRequestAgentMode) {
    NNURLRequestAgentModeUnknown = 0,
    NNURLRequestAgentModeCustom,
    NNURLRequestAgentModeDev,
    NNURLRequestAgentModeUat,
    NNURLRequestAgentModeDis
};

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSURL * NNCreateAbsoluteDownloadPath(NSString *path);

@class AFSecurityPolicy;
@interface NNURLRequestAgent : NSObject

/** api 请求的基础路径 */
@property (copy, nonatomic, readonly)   NSString *baseURL;
/** api 一些基本通用参数 */
@property (copy, nonatomic, readonly, nullable)   NSDictionary *commonParams;
/** api 一些通用headers */
@property (copy, nonatomic, readonly, nullable)   NSDictionary<NSString *, NSString *> *commonHeaders;
/** api 请求的缓存目录  */
@property (copy, nonatomic, nullable, readonly)   NSString *cachePath;

/** api 请求通用的请求头部解析类型 默认 NNURLRequestSerializerTypeHTTP */
@property (assign, nonatomic) NNURLRequestSerializerType requestSerializerType;
/** api 请求通用的response解析类型 默认 NNResponseSerializerTypeHTTP */
@property (assign, nonatomic) NNResponseSerializerType responseSerializerType;
/** api 的默认环境类型 */
@property (assign, nonatomic) NNURLRequestAgentMode mode;
/** api 请求的证书配置 */
@property (strong, nonatomic, nullable) AFSecurityPolicy *securityPolicy;

/**
 实例化NNURLRequestAgent对象

 @param configuration SessionConfig 默认使用 [NSURLSessionConfiguration defaultConfiguration]
 @return NNURLRequestAgent 实例
 */
- (instancetype)initWithConfiguration:(nullable NSURLSessionConfiguration *)configuration;

/**
 持有NNURLRequest对象, 并开始网络请求

 @param request NNURLRequest 对象
 */
- (void)startRequest:(__kindof NNURLRequest  *)request;

@end

@interface NNURLRequestAgent (NNAgentManage)
+ (void)storeAgent:(__kindof NNURLRequestAgent *)agent withIdentifier:(NSString *)identifier;
+ (nullable __kindof NNURLRequestAgent *)agentWithIdentifier:(NSString *)identifier;
+ (nullable NSArray<__kindof NNURLRequestAgent *> *)storedAgents;
+ (void)configModeForStoredAgents:(NNURLRequestAgentMode)mode;
@end

NS_ASSUME_NONNULL_END
