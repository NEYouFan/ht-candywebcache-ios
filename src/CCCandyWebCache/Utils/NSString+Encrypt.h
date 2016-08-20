//
//  NSString+Encrypt.h
//  Pods
//
//  Created by 小丸子 on 23/6/2016.
//
//

#import <Foundation/Foundation.h>

@interface NSString (Encrypt)
-(NSString *)base64AfterSha256WithKey:(NSString *)key;
@end
