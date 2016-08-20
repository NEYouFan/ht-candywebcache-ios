//
//  NSString+MD5Encrypt.h
//  Pods
//
//  Created by jw on 6/24/16.
//
//

#import <Foundation/Foundation.h>

@interface NSString (MD5Encrypt)
- (NSString*)encryptedMD5;
- (NSString*)decryptedMD5;
@end


NSArray* DESKeyEncrypt(NSString* key);

NSString* DESKeyDecrypt(NSArray* arr);
