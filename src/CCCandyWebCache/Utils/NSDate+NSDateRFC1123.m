//
//  NSDate+NSDateRFC1123.m
//  HTFileDownloader
//
//  Created by 小丸子 on 24/6/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "NSDate+NSDateRFC1123.h"

@implementation NSDate (NSDateRFC1123)

-(NSString*)rfc1123String
{
    static NSDateFormatter *df = nil;
    if(df == nil)
    {
        df = [[NSDateFormatter alloc] init];
        df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    }
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: self];
    NSDate *localDate = [self dateByAddingTimeInterval: interval];
    
    return [df stringFromDate:localDate];
}

@end
