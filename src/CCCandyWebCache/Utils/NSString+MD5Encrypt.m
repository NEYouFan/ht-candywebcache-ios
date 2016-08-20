//
//  NSString+MD5Encrypt.m
//  Pods
//
//  Created by jw on 6/24/16.
//
//

#import "NSString+MD5Encrypt.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "CCLogger.h"


static const NSString* gDESKey = @"";

static const NSUInteger md5Length = 32;

NSArray<NSNumber*>* DESKeyEncrypt(NSString* key)
{
    NSData* data = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger size = [data length] / sizeof(unsigned char);
    NSMutableArray<NSNumber*>* result = [[NSMutableArray alloc]initWithCapacity:size];
    
    unsigned char* array = (unsigned char*) [data bytes];
    for (int i = 0; i < size; i++) {
        result[i] = @((int)array[i] ^ 0x28);
    }
    return result;
    
}

NSString* DESKeyDecrypt(NSArray<NSNumber*>* arr)
{
    
    NSUInteger size = arr.count;
    unsigned char array[size];
    
    for (int i = 0; i < arr.count; i++) {
        array[i] = (unsigned char)([arr[i] intValue] ^ 0x28);
    }
    
    
    NSData* data = [NSData dataWithBytes:(const void *)array length:sizeof(unsigned char)*size];
    NSString* result = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return result;
}


@interface NSData (Base64)


/**
 *  转换为Base64编码
 */
- (NSString *)base64EncodedString;
/**
 *  将Base64编码还原
 */
+ (NSData *)base64DecodedData:(NSString*)base64String;
@end

@implementation NSData (Base64)

+ (void)load
{
    gDESKey = DESKeyDecrypt(@[@(0x19),@(0x1a),@(0x1b),@(0x1c),@(0x1c),@(0x1b),@(0x1a),@(0x19)]);
}

- (NSString *)base64EncodedString;
{
    return [self base64EncodedStringWithOptions:0];
}

+ (NSData *)base64DecodedData:(NSString*)base64String
{
    unsigned long padNum = (unsigned long)(4 - (base64String.length % 4)) % 4;
    switch (padNum) {
        case 1:
            base64String = [NSString stringWithFormat:@"%@=",base64String];
            break;
        case 2:
            base64String = [NSString stringWithFormat:@"%@==",base64String];
            break;
        case 3:
            base64String = [NSString stringWithFormat:@"%@===",base64String];
            break;
        default:
            break;
    }
    NSData* result =  [[NSData alloc] initWithBase64EncodedString:base64String options:0];;
    if (!result) {
        CCLogError(@"[CandyWebCache]:base64解码失败。");
    }
    return result;
}

@end

@implementation NSString (MD5Encrypt)

/******************************************************************************
 函数名称 : + (NSData *)DESEncrypt:(NSData *)data WithKey:(NSString *)key
 函数描述 : 文本数据进行DES加密
 输入参数 : (NSData *)data
 (NSString *)key
 输出参数 : N/A
 返回参数 : (NSData *)
 备注信息 : 此函数不可用于过长文本
 ******************************************************************************/
- (NSData *)DESEncrypt:(NSData *)data WithKey:(NSString *)key
{
    char keyPtr[kCCKeySizeAES256+1];
    bzero(keyPtr, sizeof(keyPtr));
    
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmDES,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCBlockSizeDES,
                                          NULL,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer);
    return nil;
}

/******************************************************************************
 函数名称 : + (NSData *)DESEncrypt:(NSData *)data WithKey:(NSString *)key
 函数描述 : 文本数据进行DES解密
 输入参数 : (NSData *)data
 (NSString *)key
 输出参数 : N/A
 返回参数 : (NSData *)
 备注信息 : 此函数不可用于过长文本
 ******************************************************************************/
- (NSData *)DESDecrypt:(NSData *)data WithKey:(NSString *)key
{
    NSData* result;
    char keyPtr[kCCKeySizeAES256+1];
    bzero(keyPtr, sizeof(keyPtr));
    
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [data length];
    
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmDES,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCBlockSizeDES,
                                          NULL,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return result;
}

- (NSString*)encryptedMD5
{
    if ([self isEqualToString:@""]) {
        return @"";
    }
    if (self.length != md5Length) {
        CCLogError(@"[CCCandyWebCache]:需要加密md5长度不正确:%@。",self);
        return @"";
    }
    
    NSData* data = [self DESEncrypt:[self dataUsingEncoding:NSUTF8StringEncoding] WithKey:[gDESKey copy]];
    NSString* str = [data base64EncodedString];
    return str;
}

- (NSString*)decryptedMD5
{
    if ([self isEqualToString:@""]) {
        return @"";
    }
    
    NSData* data = [self DESDecrypt:[NSData base64DecodedData:self] WithKey:[gDESKey copy]];
    NSString* md5 =[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if (md5.length != md5Length) {
        CCLogError(@"[CCCandyWebCache]:解密md5长度不正确:%@。",md5);
        return @"";
    }
    return md5;
}



@end


