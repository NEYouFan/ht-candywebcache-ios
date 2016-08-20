//
//  CCCacheManagerDBTests.m
//  CCDemo
//
//  Created by jw on 6/14/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCWebAppInfo.h"
#import "CCResourceIndexInfo.h"
#import "CCCacheManager.h"
#import "CCCacheManager+DB.h"

@interface CCCacheManagerDBTests : XCTestCase

@end

@implementation CCCacheManagerDBTests

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

//for test
- (void)testDatabase
{
    NSMutableDictionary<NSString*,CCWebAppInfo*>* webappInfos;
    NSMutableDictionary<NSString*,CCResourceIndexInfo*>* resourceIndexInfos;
    webappInfos = [[NSMutableDictionary alloc]init];
    resourceIndexInfos = [[NSMutableDictionary alloc]init];
    for (int i = 0; i < 10; i++) {
        CCWebAppInfo* info = [CCWebAppInfo new];
        info.name = [NSString stringWithFormat:@"webapp%@",@(i)];
        info.domains = @[@"www.126.com",@"www.163.com",@"mm.blog.net/public"];
        info.version = @"1.0.0";

        info.fullPackageMD5 = @"221312213213";
        info.fullDownloadURL = @"www.126.com";
        info.localRelativePath = @"aaa/bbb/webapp1";
        info.status = 1;
        info.updatePercent = 0.85;
        info.diskSize = 2048;
        
        [webappInfos setObject:info forKey:info.name];
    }
    
    
    for (int i = 0; i < 10; i++) {
        CCResourceIndexInfo* info = [CCResourceIndexInfo new];
        info.url = [NSString stringWithFormat:@"www.126.com/%@.html",@(i)];
        info.localRelativePath = @"aaa/bbb/webapp1";
        info.md5 = @"221312213213";
//        info.webappName = [NSString stringWithFormat:@"webapp%@",@(i)];
        
        [resourceIndexInfos setObject:info forKey:info.url];
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *rootPath = [paths objectAtIndex:0];
   
    
    CCCacheManager* cacheManager = [[CCCacheManager alloc]initWithRootPath:rootPath];
    XCTAssertNotNil(cacheManager,@"创建CCCacheManager失败");
    
    XCTAssertTrue([cacheManager DB_writeWebAppInfos:webappInfos.allValues],@"写入webappinfo失败");
    
    NSArray* arr = [cacheManager DB_readWebAppInfos];
    XCTAssertTrue(arr.count == 10,@"读取webappinfo失败");
    
    CCWebAppInfo* info = [CCWebAppInfo new];
    info.name = [NSString stringWithFormat:@"webapp11"];
    info.domains = @[@"www.126.com",@"www.163.com",@"mm.blog.net/public"];
    info.version = @"1.0.0";
    
    info.fullPackageMD5 = @"221312213213";
    info.fullDownloadURL = @"www.126.com";
    info.localRelativePath = @"aaa/bbb/webapp1";
    info.status = 1;
    info.updatePercent = 0.85;
    info.diskSize = 2048;
    
    XCTAssertTrue([cacheManager DB_insertWebAppInfo:info],@"webappinfo失败");
    arr = [cacheManager DB_readWebAppInfos];
    XCTAssertTrue(arr.count == 11,@"读取webappinfo失败");
    
    
    XCTAssertTrue([cacheManager DB_writeResourceIndexInfos:resourceIndexInfos.allValues],@"写入resource index info失败");
    arr = [cacheManager DB_readResourceIndexInfos];

    XCTAssertTrue(arr.count == 10,@"读取resource index info失败");
    
    NSMutableArray* resIndexInfos = [NSMutableArray new];
    for (int i = 0; i < 3; i++) {
        CCResourceIndexInfo* info = [CCResourceIndexInfo new];
        info.url = [NSString stringWithFormat:@"www.126.com/%@.html",@(i+20)];
        info.localRelativePath = @"aaa/bbb/webapp1";
        info.md5 = @"221312213213";
        //        info.webappName = [NSString stringWithFormat:@"webapp%@",@(i)];
        
        [resIndexInfos addObject:info];
    }
    
    XCTAssertTrue([cacheManager DB_insertResourceIndexInfos:resIndexInfos],@"插入resource index info失败");
    arr = [cacheManager DB_readResourceIndexInfos];
    XCTAssertTrue(arr.count == 13,@"读取resource index info失败");
    
    NSMutableArray* urls = [NSMutableArray new];
    for (CCResourceIndexInfo* info in resIndexInfos) {
        [urls addObject:info.url];
    }
    
//    XCTAssertTrue([cacheManager DB_deleteResourceIndexInfoWithURLs:urls],@"删除resource index info失败");
//    arr = [cacheManager DB_readResourceIndexInfos];
//    XCTAssertTrue(arr.count == 10,@"读取resource index info失败");
//    
//    XCTAssertTrue([cacheManager DB_deleteWebAppInfoWithNames:@[@"webapp3"]],@"删除webapp信息失败");
//    XCTAssertTrue([cacheManager DB_deleteResourceIndexInfoWithURLs:@[@"www.126.com/3.html"]],@"删除resouce index信息失败");
}

@end
