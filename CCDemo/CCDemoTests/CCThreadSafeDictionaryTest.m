//
//  CCThreadSafeDictionaryTest.m
//  CCDemo
//
//  Created by jw on 7/6/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCThreadSafeMutableDictionary.h"

@interface CCThreadSafeDictionaryTest : XCTestCase

@end

@implementation CCThreadSafeDictionaryTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    CCThreadSafeMutableDictionary* dic = [CCThreadSafeMutableDictionary new];
    NSInteger testCount = 10;
    
    dispatch_queue_t q1 = dispatch_queue_create(@"threadSafeTest1".UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create(@"threadSafeTest2".UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q3 = dispatch_queue_create(@"threadSafeTest3".UTF8String, DISPATCH_QUEUE_SERIAL);
    
    __block int i1 = 0;
    __block int i2 = 0;
    for (int i =0; i< testCount; i++) {
        
        for (int i = 0; i < 100; i++) {
            dispatch_async(q1, ^{
                for (NSString* str in dic) {
                    i1++;
                    NSLog(@"1 = %@ %@",@(i1),str);
                }
            });
        }
        
        for (int i = 0; i < 100; i++) {
            dispatch_async(q2, ^{
                for (NSString* str in dic) {
                    i2++;
                    NSLog(@"2 = %@ %@",@(i2),str);
                }
            });
        }
            
        
        for (int i = 0; i < 100; i++) {
            dispatch_async(q3, ^{
                [dic setObject:@"3 = aa" forKey:[NSString stringWithFormat:@"%@",@(i)]];
                NSLog(@"write");
            });
            
        }
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
