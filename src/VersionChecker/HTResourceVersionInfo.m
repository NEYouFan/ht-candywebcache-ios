//
//  HTResourceVersionInfo.m
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import "HTResourceVersionInfo.h"

@implementation HTResourceVersionInfo

-(instancetype)init{
    
    self = [super init];
    if (self) {
        
        _resID = @"";
        _state = HTResourceVersionCheckerStateNone;
        _localVersion = @"";
        _version = @"";
        _diffUrl = @"";
        _version = @"";
        _diffMd5 = @"";
        _fullUrl = @"";
        _fullMd5 = @"";
    }
    
    return self;
}

@end
