//
//  CCValidationChecker.m
//  CandyWebCache
//
//  Created by jw on 6/3/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "CCValidationChecker.h"
#import "HTFileDownloader+MD5.h"

@implementation CCValidationChecker

+ (BOOL)data:(NSData*)data md5Maching:(NSString*)md5String
{
    if (!md5String || [md5String isEqualToString:@""]) {
        return NO;
    }
    return [[data MD5] isEqualToString:md5String];
}

+ (BOOL)file:(NSString*)filePath md5Maching:(NSString*)md5String
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return NO;
    }
    return [CCValidationChecker data:[[NSFileManager defaultManager] contentsAtPath:filePath] md5Maching:md5String];
}

@end
