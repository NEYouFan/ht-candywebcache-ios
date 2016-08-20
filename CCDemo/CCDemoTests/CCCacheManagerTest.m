//
//  CCCacheManagerTest.m
//  CCDemo
//
//  Created by jw on 6/21/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCCacheManager.h"

@interface CCCacheManagerTest : XCTestCase

@end

@implementation CCCacheManagerTest

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


- (void)testFirstInstall
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *rootPath = [paths objectAtIndex:0];
    CCCacheManager* manager = [[CCCacheManager alloc]initWithRootPath:rootPath];
    [manager firstInitWithCheckPackagePath:rootPath completeBlock:^{
        
    }];

}

@end
