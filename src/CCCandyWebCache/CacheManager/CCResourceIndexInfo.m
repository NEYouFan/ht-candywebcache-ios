//
//  CCResourceIndexInfo.m
//  Pods
//
//  Created by jw on 6/8/16.
//
//

#import "CCResourceIndexInfo.h"
#import "NSString+Path.h"

@implementation CCResourceIndexInfo

- (instancetype)init
{
    self = [super init];
    if (self) {
        _url = @"";
        _localRelativePath = @"";
        _localFullPath = @"";
        _md5 = @"";
        _webappName = @"";
    }
    return self;
}

- (NSString*)uniqueKey
{
    return [NSString stringWithFormat:@"%@/%@",_webappName,_url];
}

- (NSString *)description
{
    NSMutableString* des = [NSMutableString new];
    [des appendFormat:@"===CCResourceIndexInfo:%@===\n",[self uniqueKey]];
    [des appendFormat:@"url:%@,\n",_url];
    [des appendFormat:@"localPath:%@,\n",_localFullPath];
    [des appendFormat:@"md5:%@,\n",_md5];
    [des appendFormat:@"webappName:%@,\n",_webappName];
    [des appendString:@"======\n"];
    return des;
}

- (void)setLocalRelativePath:(NSString *)localRelativePath
{
    _localRelativePath = localRelativePath;
    _localFullPath = [NSString stringWithFormat:@"%@/%@",[NSString documentPath],localRelativePath];
}

@end
