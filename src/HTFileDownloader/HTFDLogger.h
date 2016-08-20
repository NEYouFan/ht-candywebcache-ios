//
//  HTFDLogger.h
//  Pods
//
//  Created by jw on 6/23/16.
//
//

#import <Foundation/Foundation.h>

#define HTFDLOGVerbose @"V"
#define HTFDLOGTest    @"T"
#define HTFDLOGInfo    @"I"
#define HTFDLOGDebug   @"D"
#define HTFDLOGWarn    @"W"
#define HTFDLOGError   @"E"

#define HTFDLogVerbose(...)         HTFDLog(HTFDLoggerLevelVerbose, HTFDLOGVerbose __FILE__, __LINE__, __VA_ARGS__)
#define HTFDLogTest(...)            HTFDLog(HTFDLoggerLevelTest, HTFDLOGTest, __FILE__, __LINE__, __VA_ARGS__)
#define HTFDLogInfo(...)            HTFDLog(HTFDLoggerLevelInfo, HTFDLOGInfo, __FILE__, __LINE__, __VA_ARGS__)
#define HTFDLogDebug(...)           HTFDLog(HTFDLoggerLevelDebug,HTFDLOGDebug, __FILE__, __LINE__, __VA_ARGS__)
#define HTFDLogWarn(...)            HTFDLog(HTFDLoggerLevelWarning, HTFDLOGWarn, __FILE__, __LINE__, __VA_ARGS__)
#define HTFDLogError(...)           HTFDLog(HTFDLoggerLevelError,HTFDLOGError, __FILE__, __LINE__,__VA_ARGS__)

typedef NS_ENUM(NSInteger,HTFDLoggerLevel)
{
    HTFDLoggerLevelVerbose = 1,
    HTFDLoggerLevelTest,
    HTFDLoggerLevelInfo,
    HTFDLoggerLevelDebug,
    HTFDLoggerLevelWarning,
    HTFDLoggerLevelError
};

@interface HTFDLogger : NSObject

+ (void)setEnable:(BOOL)enable;

+ (void)setLogLevel:(HTFDLoggerLevel)level;

@end


void HTFDLog(HTFDLoggerLevel level,NSString * levelDescription, const char *fname, int lineno,NSString* formatString, ...);