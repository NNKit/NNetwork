//
//  NNURLRequestCacheSpec.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/16.
//  Copyright 2017年 ws00801526. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import <NNetwork/NNetwork.h>

#import "NNTestAgent.h"
#import "NNTestResponseReformer.h"

SPEC_BEGIN(NNURLRequestCacheSpec)

describe(@"NNURLRequestCache", ^{
    static NSString * const kNNTestAgentIdentifier = @"TestAgent";
    
    beforeAll(^{
        NNTestAgent *testAgent = [[NNTestAgent alloc] init];
        [NNURLRequestAgent storeAgent:testAgent withIdentifier:kNNTestAgentIdentifier];
    });
    
    __block NNURLRequest *infoRequest;
    beforeEach(^{
        infoRequest = [[NNURLRequest alloc] initWithServiceIdentifier:kNNTestAgentIdentifier
                                                           requestPath:@"/jportal/server/date/merchant/getMerchantDetail"
                                                         requestMethod:NNURLRequestMethodPOST];
        infoRequest.cachePolicy = NNURLRequestCachePolicyReturnCacheDataElseLoad;
        infoRequest.responseInterceptor = [NNTestResponseReformer sharedReformer];
        infoRequest.cacheVersion = @"1.0";
        infoRequest.cacheTime = 1;
    });

    context(@"test NNetwork", ^{

        it(@"test info request", ^{
            
            infoRequest.cachePolicy = NNURLRequestCachePolicyReturnAndRefreshCacheData;
            [infoRequest startRequestWithParams:@{@"loginAccount":@"zastf"} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                NNLogD(@"login success :%@",request);
            }];
            [[expectFutureValue(theValue(infoRequest.isFromCache)) shouldEventuallyBeforeTimingOutAfter(2.f)] beYes];
            [[expectFutureValue(infoRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNonNil];
            [[expectFutureValue(infoRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNonNil];
            [[expectFutureValue(theValue([infoRequest.responseObject isKindOfClass:[NNTestResponse class]])) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
            [[expectFutureValue(theValue([(NNTestResponse *)infoRequest.responseObject code] == 0)) shouldEventuallyBeforeTimingOutAfter(5.f)] beYes];
        });
        
        it(@"test info request cache expired", ^{
           
            infoRequest.cachePolicy = NNURLRequestCachePolicyReturnCacheDataDontLoad;
            [infoRequest startRequestWithParams:@{@"loginAccount":@"zastf"} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                NNLogD(@"login success :%@",request);
            }];
            [[expectFutureValue(theValue(infoRequest.error.code)) shouldEventuallyBeforeTimingOutAfter(2.f)] equal:@(-100)];
            [[expectFutureValue(theValue(infoRequest.isFromCache)) shouldEventuallyBeforeTimingOutAfter(2.f)] beYes];
            [[expectFutureValue(infoRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNil];
            [[expectFutureValue(infoRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNil];
        });
        
        it(@"test info request mismatch version", ^{

            dispatch_after(1.f, dispatch_get_main_queue(), ^{
                
                infoRequest.cachePolicy = NNURLRequestCachePolicyReturnCacheDataElseLoad;
                infoRequest.cacheVersion = @"1.1";
                [infoRequest startRequestWithParams:@{@"loginAccount":@"zastf"} completionHandler:^(__kindof NNURLRequest * _Nonnull request) {
                    NNLogD(@"login success :%@",request);
                }];
            });

            [[expectFutureValue(theValue(infoRequest.error.code)) shouldEventuallyBeforeTimingOutAfter(2.f)] equal:@(0)];
            [[expectFutureValue(theValue(infoRequest.isFromCache)) shouldEventuallyBeforeTimingOutAfter(2.f)] beNo];
            [[expectFutureValue(infoRequest.responseObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNonNil];
            [[expectFutureValue(infoRequest.responseJSONObject) shouldEventuallyBeforeTimingOutAfter(2.f)] beNonNil];
        });
    });
});

SPEC_END
