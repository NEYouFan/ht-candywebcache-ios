//
//  PerformanceController.m
//  CCDemo
//
//  Created by jw on 7/5/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "PerformanceController.h"
#import "CCCandyWebCache.h"

@interface PerformanceController ()
@property (nonatomic,strong) UIButton* urlMatchTestButton;
@property (nonatomic,strong) UIButton* threadSafeTestButton;
@end

@implementation PerformanceController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _urlMatchTestButton = [[UIButton alloc]init];
    [self.view addSubview:_urlMatchTestButton];
    [_urlMatchTestButton setTitle:@"url匹配性能测试" forState:UIControlStateNormal];
    _urlMatchTestButton.backgroundColor = [UIColor blueColor];
    [_urlMatchTestButton addTarget:self action:@selector(urlMatchTest) forControlEvents:UIControlEventTouchUpInside];
    
    
    
    _threadSafeTestButton = [[UIButton alloc]init];
    [self.view addSubview:_threadSafeTestButton];
    [_threadSafeTestButton setTitle:@"url匹配线程安全测试" forState:UIControlStateNormal];
    _threadSafeTestButton.backgroundColor = [UIColor blueColor];
    [_threadSafeTestButton addTarget:self action:@selector(threadSafeTest) forControlEvents:UIControlEventTouchUpInside];

}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _urlMatchTestButton.frame = CGRectMake(100, 120, 200, 40);
    
    _threadSafeTestButton.frame = CGRectMake(100, 200, 200, 40);
}


- (void)urlMatchTest
{
    CCCacheManager* manager = [CCCandyWebCache defaultWebCache].cacheManager;
    NSInteger testCount = 1000;
    NSUInteger startMilSec = [[NSDate date] timeIntervalSince1970] * 1000 * 1000;
    for (int i =0; i < testCount; i++) {
//        [manager dataForURL:[NSString stringWithFormat:@"http://www.kaola.com/r/javascript/core-v%d.0.js",i]];
        [manager dataForURL:[NSString stringWithFormat:@"http://m.kaola.com/r/core_c2e5aa4f2d71d82b7cb95d5aaed3cc6c.js"]];
    }
    NSUInteger costMilSec = [[NSDate date] timeIntervalSince1970] * 1000 * 1000 - startMilSec;
    NSUInteger averageMilSec = costMilSec/testCount;
    NSLog(@"平均每次url匹配耗时：%@微秒",@(averageMilSec));
}

- (void)threadSafeTest
{
    NSInteger testCount = 1000;
    
    dispatch_queue_t q1 = dispatch_queue_create(@"threadSafeTest1".UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create(@"threadSafeTest2".UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q3 = dispatch_queue_create(@"threadSafeTest3".UTF8String, DISPATCH_QUEUE_SERIAL);
    CCCacheManager* manager = [CCCandyWebCache defaultWebCache].cacheManager;
    for (int i =0; i< testCount; i++) {
        dispatch_async(q1, ^{
            [manager dataForURL:[NSString stringWithFormat:@"http://www.kaola.com/webapp/pub/app.html"]];
        });
        dispatch_async(q2, ^{
            [manager dataForURL:[NSString stringWithFormat:@"http://www.kaola.com/webapp/pub/app.html"]];
        });
        dispatch_async(q3, ^{
            [manager dataForURL:[NSString stringWithFormat:@"http://www.kaola.com/webapp/pub/app.html"]];
        });
    }
    
    
}

@end
