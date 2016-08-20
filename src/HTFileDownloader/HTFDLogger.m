//
//  HTFDLog.m
//  Pods
//
//  Created by jw on 6/23/16.
//
//

#import "HTFDLogger.h"

static HTFDLoggerLevel gLogLevel = HTFDLoggerLevelDebug;
static BOOL gLogEnable = NO;

@implementation HTFDLogger

+ (void)setEnable:(BOOL)enable
{
    gLogEnable = enable;
}

+ (void)setLogLevel:(HTFDLoggerLevel)level
{
    gLogLevel = level;
}


@end

void HTFDLog(HTFDLoggerLevel level, NSString * levelString, const char *fname, int lineno,NSString* formatString, ...)
{
    if (gLogEnable && level >= gLogLevel) {
        va_list args;
        va_start(args, formatString);
        NSString* filename = [NSString stringWithUTF8String:fname];
        NSLog(@"[%@]:%@_%d %@",levelString, [filename lastPathComponent],lineno,[[NSString alloc] initWithFormat:formatString arguments:args]);
        va_end(args);
    }
}