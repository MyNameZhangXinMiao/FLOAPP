//
//  FLOAPPConfig.m
//  FLOAPP
//
//  Created by 360doc on 2018/4/11.
//  Copyright © 2018年 Flolangka. All rights reserved.
//

#import "FLOAPPConfig.h"

@interface FLOAPPConfig ()

@property (nonatomic, assign, readwrite) float screenWidth;
@property (nonatomic, assign, readwrite) float screenHeight;

@property (nonatomic, assign, readwrite) BOOL iPhoneX;
@property (nonatomic, assign, readwrite) float navigationBarHeight;
@property (nonatomic, assign, readwrite) float iPhoneXBottomHeight;


@end

@implementation FLOAPPConfig

static FLOAPPConfig *shareAppConfig;
+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareAppConfig = [[FLOAPPConfig alloc] init];
        [shareAppConfig config];
    });
    return shareAppConfig;
}

- (void)config {
    _screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
    _screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    
    _iPhoneX = CGSizeEqualToSize(CGSizeMake(375, 812), [[UIScreen mainScreen] bounds].size);
    _navigationBarHeight = (44 + (_iPhoneX ? 44 : 20));
    _iPhoneXBottomHeight = _iPhoneX ? 34 : 0;
}

@end