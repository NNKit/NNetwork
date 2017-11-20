//
//  NNTestResponseReformer.m
//  NNetwork_Example
//
//  Created by XMFraker on 2017/11/16.
//  Copyright © 2017年 ws00801526. All rights reserved.
//

#import "NNTestResponseReformer.h"

@implementation NNTestResponse

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
    
    return @{
             @"code" : @"resultCode",
             @"message" : @"message",
             @"result" : @"content"
             };
}


@end

@implementation NNTestResponseReformer

- (id)responseObjectForRequest:(__kindof NNURLRequest *)request error:(NSError *)error {
    
    NNTestResponse *response = [NNTestResponse yy_modelWithJSON:request.responseObject];
    return response ? : request.responseJSONObject;
}

- (BOOL)requestShouldCacheResponse:(__kindof NNURLRequest *)request {
    
    NNTestResponse *response = request.responseObject;
    return response.code == 0;
}

- (NSDictionary *)paramsForRequest:(__kindof NNURLRequest *)request {
    return @{
             @"testCommonNumber" : @"overwrite by paramInteceptor",
             @"testCommonDictionary" : @{@"overwrite by paramInteceptor - 1" : @1, @"overwrite by paramInteceptor -2" : @2},
             };
}

+ (instancetype)sharedReformer {
    static id reformer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reformer = [[self alloc] init];
    });
    return reformer;
}
@end

@implementation NNTestSignResponseReformer

+ (instancetype)sharedReformer {
    static id reformer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reformer = [[self alloc] init];
    });
    return reformer;
}

- (NSDictionary *)signedParamsForRequest:(__kindof NNURLRequest *)request params:(NSDictionary *)params {

    if (params) {
        return @{@"sign":[[NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:nil] md5String]};
    }
    return nil;
}

@end
