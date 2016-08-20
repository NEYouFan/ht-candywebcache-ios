//
//  CCVersionCheckerTests.m
//  CCDemo
//
//  Created by 小丸子 on 13/6/2016.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCVersionChecker.h"

@interface CCVersionCheckerTests : XCTestCase<CCVersionCheckerDelegate>

@property (nonatomic, strong) CCVersionChecker * versionChecker;

@end

@implementation CCVersionCheckerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.versionChecker = [[CCVersionChecker alloc]initWithDelegate:nil withHost:@"10.242.27.37:9001"];
    
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

// check 返回error, versionInfo为空
- (void)testCheckVersionWithErrorParam{
    
}

-(void)testCheckVersionOnlyWithNativeappInfo{
    
    XCTestExpectation * expectation = [self expectationWithDescription:@"CheckVersion with native app info"];
    
    NSString * nativeApp = @"KaoLa";
    NSString * nativeVersion = @"20160612";
    
    [self.versionChecker checkVersionWithApp:nativeApp nativeVersion:nativeVersion webAppInfos:nil checkCompletionHandler:^(NSArray<CCVersionInfo *> * _Nullable versionInfoArray, NSError * _Nullable error) {
        
        if (error == nil){
            
            if (versionInfoArray.count != 0) {
                
                [expectation fulfill];
            }
        }
    }];
    
    [self waitForExpectationsWithTimeout:100.0 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Expectation error: %@", error);
        }
    }];

}

// check 返回error, versionInfo 为空
- (void)testCheckVersionWithErrorNotExistedApp{
    
    XCTestExpectation * expectation = [self expectationWithDescription:@"CheckVersion With app not existed"];
    
    NSString * nativeApp = @"KaoLa1";
    NSString * nativeVersion = @"20160612";
    NSMutableArray<CCWebAppInfo *>  * webAppInfoArray = [NSMutableArray array];
    for (int i = 0; i <3; i++) {
        CCWebAppInfo * webApp = [[CCWebAppInfo alloc]init];
        webApp.name = @"Login";
        webApp.version = @"20160612";
        [webAppInfoArray addObject:webApp];
    }
    
    [self.versionChecker checkVersionWithApp:nativeApp nativeVersion:nativeVersion webAppInfos:webAppInfoArray checkCompletionHandler:^(NSArray<CCVersionInfo *> * _Nullable versionInfoArray, NSError * _Nullable error) {
        
        if (error != nil && versionInfoArray.count == 0) {
            if (error.code == CCVersionCheckerErrorNotExisted) {
                
                [expectation fulfill];
            }
        }
    }];
    
    [self waitForExpectationsWithTimeout:100.0 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Expectation error: %@", error);
        }
    }];
}

// 期望：返回所有传入的webApp, 但是checkerState为Latest
- (void)testCheckVersionForAppInfoWithLatestVersion{
    
    XCTestExpectation * expectation = [self expectationWithDescription:@"CheckVersion With Latest Version"];
    
    NSString * nativeApp = @"KaoLa";
    NSString * nativeVersion = @"20160612";
    NSMutableArray<CCWebAppInfo *>  * webAppInfoArray = [NSMutableArray array];
    for (int i = 0; i <3; i++) {
        CCWebAppInfo * webApp = [[CCWebAppInfo alloc]init];
        webApp.name = @"Login";
        webApp.version = @"20160612";
        [webAppInfoArray addObject:webApp];
    }
    
    [self.versionChecker checkVersionWithApp:nativeApp nativeVersion:nativeVersion webAppInfos:webAppInfoArray checkCompletionHandler:^(NSArray<CCVersionInfo *> * _Nullable versionInfoArray, NSError * _Nullable error) {
        
        if(error == nil){
            BOOL isSatisfied = YES;
            for (CCVersionInfo * versionInfo in versionInfoArray){
                if (versionInfo.statusCode != CCVersionCheckerStateLatest) {
                    isSatisfied = NO;
                }
            }
            if (isSatisfied) {
                [expectation fulfill];
            }
        }
    }];
    
    [self waitForExpectationsWithTimeout:100.0 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Expectation error: %@", error);
        }
    }];
}

@end
