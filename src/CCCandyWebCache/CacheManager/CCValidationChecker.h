//
//  CCValidationChecker.h
//  CandyWebCache
//
//  Created by jw on 6/3/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCValidationChecker : NSObject


+ (BOOL)data:(NSData*)data md5Maching:(NSString*)md5String;

+ (BOOL)file:(NSString*)filePath md5Maching:(NSString*)md5String;



@end
