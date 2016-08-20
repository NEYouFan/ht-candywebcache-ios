//
//  CCLogger.m
//  Pods
//
//  Created by jw on 6/23/16.
//
//

#import "CCLogger.h"

@implementation CCLogger
+ (void)setEnable:(BOOL)enable
{
    [HTFDLogger setEnable:enable];
}

+ (void)setLogLevel:(CCLoggerLevel)level
{
    [HTFDLogger setLogLevel:(HTFDLoggerLevel)level];
}
@end
