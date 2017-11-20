//
//  NNReachabililtySpec.m
//  NNetwork
//
//  Created by XMFraker on 2017/11/17.
//  Copyright 2017年 ws00801526. All rights reserved.
//

#import <Kiwi/Kiwi.h>
#import <NNetwork/NNetwork.h>


SPEC_BEGIN(NNReachabililtySpec)

describe(@"NNReachabililty", ^{
    context(@"test reach", ^{
       
        NNReachablility *reachablilityMock = [NNReachablility mock];
        [[reachablilityMock should] beMemberOfClass:[NNReachablility class]];
        [[reachablilityMock should] receive:@selector(flags) andReturn:theValue(kSCNetworkReachabilityFlagsReachable)];
        [[theValue(reachablilityMock.isReachable) should] beYes];
        [[theValue(reachablilityMock.status) should] equal:@(NNReachablilityStatusWiFi)];
        [[reachablilityMock should] receive:@selector(flags) andReturn:theValue(kSCNetworkReachabilityFlagsIsWWAN)];
    });
});

SPEC_END
