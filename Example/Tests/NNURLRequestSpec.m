//
//  NNURLRequestSpec.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/16.
//  Copyright 2017年 ws00801526. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import "NNTestAgent.h"
#import "NNTestResponseReformer.h"
#import <NNetwork/NNetwork.h>

SPEC_BEGIN(NNURLRequestSpec)

describe(@"NNURLRequest", ^{

    static NSString * const kNNTestAgentIdentifier = @"TestAgent";
    
    beforeAll(^{
        NNTestAgent *testAgent = [[NNTestAgent alloc] init];
        [NNURLRequestAgent storeAgent:testAgent withIdentifier:kNNTestAgentIdentifier];
    });
    
    __block NNURLRequest *loginRequest;
    beforeEach(^{
        loginRequest = [[NNURLRequest alloc] initWithServiceIdentifier:kNNTestAgentIdentifier
                                                           requestPath:@"/jportal/server/date/merchant/login"
                                                         requestMethod:NNURLRequestMethodPOST];
        loginRequest.cachePolicy = NNURLRequestCachePolicyInnoringCacheData;
    });
    
    context(@"test NNetwork", ^{
               
        it(@"test stored requestAgent", ^{
            
            [[[[NNURLRequestAgent storedAgents] should] haveAtLeast:1] items];
            
            NNTestAgent *storedAgent = [NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier];
            
            [[storedAgent shouldNot] beNil];
            [[[NNURLRequestAgent agentWithIdentifier:@"222"] should] beNil];
            
            [[theValue([storedAgent mode]) should] equal:@(NNURLRequestAgentModeUnknown)];
            [NNURLRequestAgent configModeForStoredAgents:NNURLRequestAgentModeDis];
            [[theValue([storedAgent mode]) should] equal:@(NNURLRequestAgentModeDis)];
            
            [[[storedAgent baseURL] should] equal:@"https://t-merchant.zuifuli.io"];
            [[[storedAgent commonParams] shouldNot] beNil];
            [[[storedAgent commonHeaders] shouldNot] beNil];
        });
        
        
        it(@"test cancel request", ^{
            
            loginRequest.ignoredCancelled = YES;
            [loginRequest startRequestWithParams:nil completionHandler:^(__kindof NNURLRequest * _Nonnull request) {

                NNLogD(@"request is cancelled : %@", request.isCancelled ?  @"YES" : @"NO");
                // if loginRequest.ignoredCancelled == YES this handler will not executed
                loginRequest.ignoredCancelled = NO;
            }];
            dispatch_after(.2f, dispatch_get_main_queue(), ^{
                [loginRequest cancelRequest];
            });
            [[expectFutureValue(theValue(loginRequest.ignoredCancelled)) shouldNotEventuallyBeforeTimingOutAfter(5.f)] beNo];
            [[expectFutureValue(theValue(loginRequest.isCancelled)) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
        });
        
        it(@"test login success", ^{

            loginRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
            [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E", @"loginType" : @"06" } completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                NNLogD(@"login success :%@",request);
            }];
            [[expectFutureValue(loginRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(loginRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(theValue([loginRequest.responseObject isKindOfClass:[NNTestResponse class]])) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
            [[expectFutureValue(theValue([(NNTestResponse *)loginRequest.responseObject code] == 0)) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
        });
        
        it(@"test request params", ^{
            
            NSDictionary *commonParams = [[NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier] commonParams];

            {   // 测试startRequestParams 重新 commonParams
                loginRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
                [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E", @"loginType" : @"01", @"testCommonString" : @"overwrite-byStart-1", @"testCommonArray":@[@"3",@"2",@"1"]} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                    NNLogD(@"login success :%@",request);
                }];
                [[theValue([[loginRequest.requestParams allKeys] containsObject:@"testCommonString"]) should] beYes];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonString"] should] equal:@"overwrite-byStart-1"];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonArray"] should] equal:@[@"3",@"2",@"1"]];
                [[theValue([[NSSet setWithArray:[commonParams allKeys]] isSubsetOfSet:[NSSet setWithArray:loginRequest.requestParams.allKeys]]) should] beYes];
            }
            
            {   // 测试paramInteceptor 重新 startRequestParams, commonParams
                loginRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
                loginRequest.paramInterceptor = [NNTestResponseReformer sharedReformer];
                [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E", @"loginType" : @"01", @"testCommonString" : @"overwrite-byStart-1", @"testCommonArray":@[@"3",@"2",@"1"]} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                    NNLogD(@"login success :%@",request);
                }];

                [[theValue([[loginRequest.requestParams allKeys] containsObject:@"testCommonString"]) should] beYes];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonString"] should] equal:@"overwrite-byStart-1"];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonArray"] should] equal:@[@"3",@"2",@"1"]];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonNumber"] should] equal:@"overwrite by paramInteceptor"];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonDictionary"] should] equal:@{@"overwrite by paramInteceptor - 1" : @1, @"overwrite by paramInteceptor -2" : @2}];
                [[theValue([[NSSet setWithArray:[commonParams allKeys]] isSubsetOfSet:[NSSet setWithArray:loginRequest.requestParams.allKeys]]) should] beYes];
            }
            
            {   // 测试sign param 重新 startRequestParams, commonParams, paramInteceptorParams
                loginRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
                loginRequest.paramInterceptor = [NNTestSignResponseReformer sharedReformer];
                [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E", @"loginType" : @"01", @"testCommonString" : @"overwrite-byStart-1", @"testCommonArray":@[@"3",@"2",@"1"]} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                    NNLogD(@"login failed :%@",request);
                }];
                
                [[[loginRequest.requestParams safeObjectForKey:@"sign"] should] equal:@"89a91e476727ae28a30d392f65572c36"];
    
                [[theValue([[loginRequest.requestParams allKeys] containsObject:@"testCommonString"]) should] beNo];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonArray"] should] beNil];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonNumber"] should] beNil];
                [[[loginRequest.requestParams safeObjectForKey:@"testCommonDictionary"] should] beNil];
                [[theValue([[NSSet setWithArray:[commonParams allKeys]] isSubsetOfSet:[NSSet setWithArray:loginRequest.requestParams.allKeys]]) should] beNo];
            }
        });
        
        it(@"test login failed wiht password error", ^{
            loginRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
            [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E22", @"loginType" : @"01" } completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                NNLogD(@"login failed :%@",request.responseJSONObject);
            }];
            [[expectFutureValue(loginRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(loginRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(theValue([loginRequest.responseObject isKindOfClass:[NNTestResponse class]])) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
            [[expectFutureValue(theValue([(NNTestResponse *)loginRequest.responseObject code] == 0)) shouldEventuallyBeforeTimingOutAfter(5.f)] beNo];
            [[expectFutureValue(theValue([(NNTestResponse *)loginRequest.responseObject code] == 205)) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
        });
        
        it(@"test request without response reformer", ^{

            [loginRequest startRequestWithParams:@{@"loginAccount" : @"zastf", @"loginPwd" : @"F379EAF3C831B04DE153469D1BEC345E", @"loginType" : @"01" } completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                NNLogD(@"login success :%@",request);
            }];
            [[expectFutureValue(loginRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(loginRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(5.f)] beNonNil];
            [[expectFutureValue(theValue([loginRequest.responseObject isKindOfClass:[NNTestResponse class]])) shouldEventuallyBeforeTimingOutAfter(5.f)] beNo];
        });
    });
});

SPEC_END
