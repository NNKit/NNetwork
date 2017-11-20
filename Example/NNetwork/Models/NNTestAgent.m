//
//  NNTestAgent.m
//  NNetwork_Example
//
//  Created by XMFraker on 2017/11/16.
//  Copyright © 2017年 ws00801526. All rights reserved.
//

#import "NNTestAgent.h"

@implementation NNTestAgent

#pragma mark - Getter

- (NSDictionary *)commonParams {
    
    return @{
             @"testCommonString" : @"1",
             @"testCommonNumber" : @2,
             @"testCommonArray" : @[@"1",@2,@"3"],
             @"testCommonDictionary" : @{@"1" : @1,@"2" : @2},
             };
}

- (NSDictionary<NSString *, NSString *> *)commonHeaders {
    
    return @{
             @"AVersion" : [[NSBundle mainBundle] objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey],
             @"ABundle"  : [[NSBundle mainBundle] objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleIdentifierKey]
             };
}

- (NSString *)baseURL {
    return @"https://t-merchant.zuifuli.io";
}

@end
