//
//  CCMD5EncryptTest.m
//  CCDemo
//
//  Created by jw on 6/24/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+MD5Encrypt.h"

@interface CCMD5EncryptTest : XCTestCase

@end

@implementation CCMD5EncryptTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}


//for unit test
- (void) testValidationChecker
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *rootPath = [paths objectAtIndex:0];
    NSString *filePath = [rootPath stringByAppendingPathComponent:@"language.txt"];
    NSArray *array = @[@"C语言", @"JAVA",@"Objective-C", @"Swift", @"PHP", @"C++", @"C#"];
    // 数组写入文件执行的方法
    [array writeToFile:filePath atomically:YES];
    NSString* text = @"aaaaaaaabbbbbbbbccccccccdddddddd";
    NSLog(@"%@",[text encryptedMD5]);
    NSLog(@"%@",[[text encryptedMD5] decryptedMD5]);
    
    XCTAssertTrue([[[text encryptedMD5]decryptedMD5] isEqualToString:text],"not symetric");
    
    NSArray* arr = DESKeyEncrypt(@"12344321");
    NSMutableString* str = [[NSMutableString alloc]init];
    for (NSNumber* num in arr) {
        [str appendFormat:@"%0x,",num.intValue];
    }
    NSLog(@"%@",str);
    
    XCTAssertTrue([DESKeyDecrypt(DESKeyEncrypt(@"12344321")) isEqualToString:@"12344321"],"key encrypt error");
    
}
@end
