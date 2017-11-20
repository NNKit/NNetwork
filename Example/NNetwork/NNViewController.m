//
//  NNViewController.m
//  NNetwork
//
//  Created by ws00801526 on 11/14/2017.
//  Copyright (c) 2017 ws00801526. All rights reserved.
//

#import "NNViewController.h"
#import <NNetwork/NNetwork.h>

@interface NNViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) NNReachablility *reachablility;

@end

@implementation NNViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.reachablility = [NNReachablility reachabliltyWithHostname:@"www.baidu.com"];
    __weak typeof(self) wSelf = self;
    self.reachablility.notifyHandler = ^(NNReachablility * _Nonnull reachablility) {
        __strong typeof(wSelf) self = wSelf;
        NNLogD(@"Net available : %@", reachablility.isReachable ? @"YES" : @"NO");
        switch (reachablility.status) {
            case NNReachablilityStatusWiFi:
                NNLogD(@"Net status : WiFi");
                self.statusLabel.text = @"Net status : WiFi";
                break;
            case NNReachablilityStatusWWAN:
                NNLogD(@"Net status : WWAN");
            {
                switch (reachablility.wwanStatus) {
                    case NNReachablilityWWANStatus2G:
                        self.statusLabel.text = @"Net status : WWAN-2G";
                        break;
                    case NNReachablilityWWANStatus3G:
                        self.statusLabel.text = @"Net status : WWAN-3G";
                        break;
                    case NNReachablilityWWANStatus4G:
                        self.statusLabel.text = @"Net status : WWAN-4G";
                        break;
                    case NNReachablilityWWANStatusNone:
                    default:
                        self.statusLabel.text = @"Net status : WWAN-None";
                        break;
                }
            }
                break;
            default:
                NNLogD(@"Net status : None");
                self.statusLabel.text = @"Net status : None";
                break;
        }
    };
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
