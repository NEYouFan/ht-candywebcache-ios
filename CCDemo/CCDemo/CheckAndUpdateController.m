//
//  CheckAndUpdateController.m
//  CCDemo
//
//  Created by jw on 6/22/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "CheckAndUpdateController.h"
#import "CCCandyWebCache.h"

@interface CheckAndUpdateController ()<CCWebAppUpdateProtocol>
@property (nonatomic, strong) UIButton* button;
@end

@implementation CheckAndUpdateController


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _button = [[UIButton alloc]init];
    [self.view addSubview:_button];
    [_button setTitle:@"检测更新" forState:UIControlStateNormal];
    _button.backgroundColor = [UIColor blueColor];
    [_button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _button.frame = CGRectMake(100, 120, 200, 40);
}

- (void)buttonClick
{
    [[CCCandyWebCache defaultWebCache]checkAndUpdateResource];
    
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[CCCandyWebCache defaultWebCache] addObserver:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[CCCandyWebCache defaultWebCache] removeObserver:self];
}

#pragma mark -- CCWebAppUpdateDelegate
- (BOOL)CCCacheManager:(CCCacheManager*)manager shouldUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    return YES;
}

- (void)CCCacheManager:(CCCacheManager*)manager willStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    NSLog(@"CCCandyWebCache:开始更新资源，更新之前信息如下:");
    NSLog(@"%@",[CCCandyWebCache defaultWebCache]);
}

- (void)CCCacheManager:(CCCacheManager*)manager didStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    
}

- (void)CCCacheManager:(CCCacheManager*)manager updatingWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    
}

- (void)CCCacheManager:(CCCacheManager*)manager didFinishDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    
}

- (void)CCCacheManager:(CCCacheManager*)manager didUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    NSLog(@"CCCandyWebCache:完成更新资源，更新之后信息如下:");
    NSLog(@"%@",[CCCandyWebCache defaultWebCache]);
}

- (void)CCCacheManager:(CCCacheManager*)manager failedUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info error:(CCWebAppUpdateError)error
{
    switch (error) {
        case CCWebAppUpdateErrorDownload:
            NSLog(@"CCCandyWebCache:下载失败");
            break;
        case CCWebAppUpdateErrorDiffMerge:
            NSLog(@"CCCandyWebCache:增量包merge失败");
            break;
        case CCWebAppUpdateErrorNotValid:
            NSLog(@"CCCandyWebCache:下载资源md5校验");
            break;
        case CCWebAppUpdateErrorUnzip:
            NSLog(@"CCCandyWebCache:下载文件解压失败");
            break;
        case CCWebAppUpdateErrorLocalAppNotExist:
            NSLog(@"CCCandyWebCache:本地资源不存在");
            break;
            
        default:
            NSLog(@"CCCandyWebCache:反正失败了");
            break;
    }
}

@end
