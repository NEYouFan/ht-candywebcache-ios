//
//  CCLogger.h
//  Pods
//
//  Created by jw on 6/23/16.
//
//

#import <Foundation/Foundation.h>
#import "HTFDLogger.h"

#define CCLogVerbose    HTFDLogVerbose
#define CCLogTest       HTFDLogTest
#define CCLogInfo       HTFDLogInfo
#define CCLogDebug      HTFDLogDebug
#define CCLogWarn       HTFDLogWarn
#define CCLogError      HTFDLogError




typedef NS_ENUM(NSInteger,CCLoggerLevel)
{
    CCLoggerLevelVerbose = HTFDLoggerLevelVerbose,
    CCLoggerLevelTest = HTFDLoggerLevelTest,
    CCLoggerLevelInfo = HTFDLoggerLevelInfo,
    CCLoggerLevelDebug = HTFDLoggerLevelDebug,
    CCLoggerLevelWarning = HTFDLoggerLevelWarning,
    CCLoggerLevelError = HTFDLoggerLevelWarning
};


@interface CCLogger : NSObject
+ (void)setEnable:(BOOL)enable;

+ (void)setLogLevel:(CCLoggerLevel)level;
@end
