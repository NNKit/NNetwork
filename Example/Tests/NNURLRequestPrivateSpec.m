//
//  NNURLRequestPrivateSpec.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/16.
//  Copyright 2017年 ws00801526. All rights reserved.
//

#import <Kiwi/Kiwi.h>

#import "NNTestAgent.h"
#import <NNetwork/NNetworkPrivate.h>
#import "NNTestResponseReformer.h"
#import <NNetwork/NNetwork.h>


SPEC_BEGIN(NNURLRequestPrivateSpec)

describe(@"NNURLRequestPrivate", ^{
    
    static NSString * const kNNTestAgentIdentifier = @"TestAgent";
    __block NNURLRequest *mockRequest;
    beforeAll(^{
        NNTestAgent *testAgent = [[NNTestAgent alloc] init];
        [NNURLRequestAgent storeAgent:testAgent withIdentifier:kNNTestAgentIdentifier];
        
        mockRequest = [NNURLRequest mock];
        [[mockRequest should] receive:@selector(requestParams) andReturn:@{} withCountAtLeast:0];
        [[mockRequest should] receive:@selector(requestPath) andReturn:@"/jportal/server/date/merchant/login" withCountAtLeast:0];
        [[mockRequest should] receive:@selector(serviceIdentifier) andReturn:kNNTestAgentIdentifier withCountAtLeast:0];
        [[mockRequest should] receive:@selector(requestMethod) andReturn:@(NNURLRequestMethodPOST) withCountAtLeast:0];
    });
    
    context(@"test Private Methods", ^{
        
        it(@"test absolute URLString", ^{
            
            {
                NSString *URLString = [[NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier] absoluteURLStringWithRequest:mockRequest params:nil];
                [[URLString should] equal:@"https://t-merchant.zuifuli.io/jportal/server/date/merchant/login"];
            }
            
            {
                [[mockRequest should] receive:@selector(requestPath) andReturn:@"jportal/server/date/merchant/login" withCountAtLeast:0];
                NSString *URLString = [[NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier] absoluteURLStringWithRequest:mockRequest params:nil];
                [[URLString should] equal:@"https://t-merchant.zuifuli.io/jportal/server/date/merchant/login"];
            }
            
            {
                [[mockRequest should] receive:@selector(requestPath) andReturn:@"https://merchant.zuifuli.io/jportal/server/date/merchant/login" withCountAtLeast:0];
                NSString *URLString = [[NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier] absoluteURLStringWithRequest:mockRequest params:nil];
                [[URLString should] equal:@"https://merchant.zuifuli.io/jportal/server/date/merchant/login"];
            }
            
            {
                [[mockRequest should] receive:@selector(requestPath) andReturn:@"https://merchant.zuifuli.io/:j/{s}/:d/{m}/login"];
                [[mockRequest should] receive:@selector(requestParams) andReturn:@{@"j" : @"jportal", @"s" : @"server", @"d" : @"date", @"m" : @"merchant"} withCountAtLeast:0];
                NSString *URLString = [[NNURLRequestAgent agentWithIdentifier:kNNTestAgentIdentifier] absoluteURLStringWithRequest:mockRequest params:nil];
                [[URLString should] equal:@"https://merchant.zuifuli.io/jportal/server/date/merchant/login"];
            }
        });
        
        it(@"test cache key", ^{

            [[mockRequest should] receive:@selector(requestPath) andReturn:@"/jportal/server/date/merchant/login" withCountAtLeast:0];
            NSString *cacheKeyWithOutParams = [[NNTestAgent agentWithIdentifier:kNNTestAgentIdentifier] cacheKeyWithRequest:mockRequest];
            [[mockRequest should] receive:@selector(requestParams) andReturn:@{@"1" : @1, @"2" : @2} withCountAtLeast:0];
            NSString *cacheKeyWithParams = [[NNTestAgent agentWithIdentifier:kNNTestAgentIdentifier] cacheKeyWithRequest:mockRequest];
            [[mockRequest should] receive:@selector(requestParams) andReturn:@{@"2" : @2, @"1" : @1} withCountAtLeast:0];
            NSString *cacheKeyWithParams2 = [[NNTestAgent agentWithIdentifier:kNNTestAgentIdentifier] cacheKeyWithRequest:mockRequest];

            [[cacheKeyWithOutParams shouldNot] equal:cacheKeyWithParams];
            [[cacheKeyWithParams should] equal:cacheKeyWithParams2];
        });
        
        it(@"test download path", ^{
            NSURL *path = NNCreateAbsoluteDownloadPath(@"download/path/file").absoluteString;
            
        });
        
    });
});

SPEC_END
