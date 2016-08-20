//
//  NSString+Encrpt.m
//  Pods
//
//  Created by 小丸子 on 23/6/2016.
//
//

#import "NSString+Encrypt.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSString (Encrypt)

-(NSString *)base64AfterSha256WithKey:(NSString *)key{
    
    const char *cKey = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [self cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSData *HMACData = [NSData dataWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString * base64String = [HMACData base64EncodedStringWithOptions:0];
    return base64String;
}
@end
