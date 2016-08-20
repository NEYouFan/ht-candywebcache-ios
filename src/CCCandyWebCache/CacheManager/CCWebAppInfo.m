//
//  CCWebAppInfo.m
//  Pods
//
//  Created by jw on 6/7/16.
//
//

#import "CCWebAppInfo.h"
#import "NSString+Path.h"

@implementation CCWebAppInfo


- (instancetype)init
{
    self = [super init];
    if (self) {
        _domains = @[];
        _version = @"";
        _fullPackageMD5 = @"";
        _fullDownloadURL = @"";
        _localRelativePath = @"";
        _localFullPath = @"";
        _status = CCWebAppStatusNone;
        _updatePercent = 0.0f;
        _diskSize = 0;
        _taskID = @"";
        _isDiffTask = NO;
        _diffPackageMD5 = @"";
        _diffDownloadURL = @"";
    }
    return self;
}


- (NSString *)description
{
    NSMutableString* des = [NSMutableString new];
    [des appendString:@"======\n"];
    [des appendFormat:@"webappName:%@,\n",_name];
    [des appendFormat:@"webappVersion:%@,\n",_version];
    [des appendString:@"domains:"];
    for (NSString* domain in _domains) {
        [des appendFormat:@"%@, ",domain];
    }
    [des appendString:@"\n"];
    [des appendFormat:@"diffMD5:%@,\n",_diffPackageMD5];
    [des appendFormat:@"diffUrl:%@,\n",_diffDownloadURL];
    [des appendFormat:@"fullMD5:%@,\n",_fullPackageMD5];
    [des appendFormat:@"fullUrl:%@,\n",_fullDownloadURL];
    [des appendFormat:@"localFullPath:%@,\n",_localFullPath];
    [des appendFormat:@"status:%@,\n",_status == CCWebAppStatusAvailable ? @"可用" : @"不可用"];
    [des appendFormat:@"diskSize:%@,\n",@(_diskSize)];
    [des appendString:@"======\n"];
    return des;
}

- (void)setLocalRelativePath:(NSString *)localRelativePath
{
    _localRelativePath = localRelativePath;
    _localFullPath = [NSString stringWithFormat:@"%@/%@",[NSString documentPath],localRelativePath];
}

- (NSString*)version
{
    NSArray* comps = [_version componentsSeparatedByString:@"&"];
    if (comps.count == 2) {
        return comps[0];
    }
    return _version;
}

- (NSString*)composeVersion
{
    return _version;
}

@end
