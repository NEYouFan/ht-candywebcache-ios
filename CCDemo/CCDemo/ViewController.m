//
//  ViewController.m
//  CCDemo
//
//  Created by jw on 6/3/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "ViewController.h"
#import "CCCacheManager.h"
#import "CCWebViewProtocol.h"
#import "HTFileDownloader+MD5.h"
#import "CCCandyWebCache.h"
#import "CheckAndUpdateController.h"
#import "WebViewProtocolController.h"
#import "WebAppCleanController.h"
#import "PerformanceController.h"

@interface ViewController () <UIWebViewDelegate,UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong) CCCacheManager* ccm;
@property (nonatomic,strong) CCCandyWebCache* webcache;
@property (nonatomic,strong) UITableView* tableView;
@property (nonatomic,copy) NSArray<Class>* testVCs;
@property (nonatomic,copy) NSArray<NSString*>* testNames;
@end

@implementation ViewController

-(id)createWebView{
    return [[UIWebView alloc]initWithFrame:CGRectMake(0,0,320,560)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _tableView = [UITableView new];
    [self.view addSubview:_tableView];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    _testNames = @[@"检测更新",
                   @"资源拦截",
                   @"资源清理",
                   @"性能测试"];
    _testVCs = @[CheckAndUpdateController.class,
                 WebViewProtocolController.class,
                 WebAppCleanController.class,
                 PerformanceController.class
                 ];
    
    CCCandyWebCacheConfig* config = [CCCandyWebCacheConfig new];
    
    //    config.serverAddress = @"10.242.27.37:9001";
    //    config.appName = @"KaoLa";
    config.serverAddress = @"127.0.0.1:8080";
    config.appName = @"kaola";
    config.appVersion = @"1.0.1";
    config.blackListResourceTypes = @[@"html"];
    [CCCandyWebCache setDefaultConfiguration:config];

    [CCCandyWebCache setLogEnable:YES];
    [CCCandyWebCache setLogLevel:CCLoggerLevelVerbose];
    
    [CCCandyWebCache defaultWebCache].enable = YES;
    [CCCandyWebCache defaultWebCache].diffEnable = YES;
    [[CCCandyWebCache defaultWebCache] checkAndUpdateResource];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _tableView.frame = self.view.bounds;
}

#pragma mark -- UITableViewDelegate
#pragma mark -- UITableViewDataSource
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _testVCs.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIViewController* vc = [[_testVCs objectAtIndex:indexPath.row] new];
    vc.title = _testNames[indexPath.row];
    [self.navigationController pushViewController:vc animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    if (!cell) {
        cell = [UITableViewCell new];
        // RGB
        UIColor *randomRGBColor = [[UIColor alloc] initWithRed:arc4random()%256/256.0
                                                         green:arc4random()%256/256.0
                                                          blue:arc4random()%256/256.0
                                                         alpha:0.3];
        cell.backgroundColor = randomRGBColor;
    }
    cell.textLabel.text = _testNames[indexPath.row];
    return cell;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}
//#pragma mark - webViewProtocol 测试
//-(void) testWebViewProtocol{
//    
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]];
//    
//    [self.webView loadRequest:request];
//    self.webView.delegate = self;
//    
//    self.webView.scalesPageToFit = YES;
//    
//}
//
//- (NSString *)filePathWithUrlString:(NSString *)urlString {
//    
//    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
//    NSString *fileName = [urlString MD5];
//    return [cachesPath stringByAppendingPathComponent:fileName];
//}
//
//-(NSData *)CCWebViewProtocol:(CCWebViewProtocol *)protocol dataForURL:(NSURL *)requestURL{
//    
//    NSData * data = [NSData dataWithContentsOfFile:[self filePathWithUrlString:requestURL.absoluteString]];
//    
//    return data;
//}
//
//#pragma mark - webViewWarmup 测试
//-(void) webViewDidStartLoad:(UIWebView *)webView{
//    
//    NSLog(@"Webview did started, %ld", (long)[[NSDate date] timeIntervalSince1970]);
//}
//
//-(void) webViewDidFinishLoad:(UIWebView *)webView{
//    NSLog(@"Webview did finished, %ld", (long)[[NSDate date] timeIntervalSince1970]);
//}


@end
