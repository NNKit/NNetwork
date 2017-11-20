//
//  NNTestResponseReformer.h
//  NNetwork_Example
//
//  Created by XMFraker on 2017/11/16.
//  Copyright © 2017年 ws00801526. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NNetwork/NNetwork.h>


@interface NNTestResponse : NSObject

@property (assign, nonatomic) NSUInteger code;
@property (copy, nonatomic)   NSString *message;
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic) id result;


@end


@interface NNTestResponseReformer : NSObject <NNURLRequestResponseInterceptor, NNURLRequestParamInterceptor>

+ (instancetype)sharedReformer;

@end


@interface NNTestSignResponseReformer : NNTestResponseReformer

@end
