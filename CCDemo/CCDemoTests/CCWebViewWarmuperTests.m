//
//  CCWebViewWarmuperTests.m
//  CCDemo
//
//  Created by 小丸子 on 17/6/2016.
//  Copyright © 2016 jw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CCWebViewWarmuper.h"

@interface CCWebViewWarmuperTests : XCTestCase

@end

@interface CustomizeWebView : UIWebView


@end

@implementation CustomizeWebView


@end

@implementation CCWebViewWarmuperTests

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

# pragma mark - internal method
-(id)customizeWebview{
    
    CustomizeWebView * webView = [[CustomizeWebView alloc]initWithFrame:CGRectMake(0, 0, 200, 200)];
    return webView;
}

-(BOOL)isSizeEqual:(CGSize)sizeA withAnother:(CGSize)sizeB{
    
    if ((sizeA.height == sizeB.height) && (sizeA.width == sizeB.width)) {
        return YES;
    }
    else{
        return NO;
    }
}

-(void)testWarmuperSupportUserdefineWebviewClass{
    
    CCWebViewWarmuper * warmuper = [[CCWebViewWarmuper alloc]initWithWebviewClass:[CustomizeWebView class]];
                                    
    [warmuper initWebviewPool];
    
    XCTAssertTrue([[warmuper webviewInstance] class] == [CustomizeWebView class]);
}

-(void)testWarmuperSupportUserdefineWebviewFactory{
    
    CCWebViewWarmuper * warmuper = [[CCWebViewWarmuper alloc]initWithWebviewFactory:^(){
        return [[CustomizeWebView alloc]initWithFrame:CGRectMake(0,0,320,560)];
    }];
    
    [warmuper initWebviewPool];
    
    XCTAssertTrue(([[warmuper webviewInstance] class] == [CustomizeWebView class])
                  &&  ([self isSizeEqual:[[warmuper webviewInstance] frame].size withAnother:CGRectMake(0, 0, 320, 560).size]));
}

-(void)testWebviewInstanceFromWarmuperPool{
    
    CCWebViewWarmuper * warmuper = [[CCWebViewWarmuper alloc]initWithWebviewClass:[UIWebView class]];
                                    
    warmuper.warmupWebViewCount = 5;
    [warmuper initWebviewPool];
    
    // use warmuper
    UIWebView * webView = [warmuper webviewInstance];
    
    XCTAssertNotNil(webView, @"Webview 获取失败");

}

-(void)testWebviewInstanceFromEmptyWarmuperPool{
    
    CCWebViewWarmuper * warmuper = [[CCWebViewWarmuper alloc]initWithWebviewClass:[UIWebView class]];
    
    warmuper.warmupWebViewCount = 0;
    [warmuper initWebviewPool];
    
    UIWebView * webView = [warmuper webviewInstance];
    
    XCTAssertNotNil(webView, @"Webview 获取失败");
}

-(void)testWebviewInstanceFromConsumedWarmuperPool{
    
    CCWebViewWarmuper * warmuper = [[CCWebViewWarmuper alloc]initWithWebviewClass:[UIWebView class]];
    
    warmuper.warmupWebViewCount = 2;
    [warmuper initWebviewPool];
    
    for (int i = 0; i < 2; i++) {
        UIWebView * webView = [warmuper webviewInstance];
    }
    
    UIWebView * webViewNew = [warmuper webviewInstance];
    XCTAssertNotNil(webViewNew, @"webview 获取失败");
}


@end
