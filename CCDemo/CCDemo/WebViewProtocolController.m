//
//  WebViewProtocolController.m
//  CCDemo
//
//  Created by jw on 6/22/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "WebViewProtocolController.h"
#import "CCCandyWebCache.h"

@interface WebViewProtocolController ()<UIWebViewDelegate>
@property (nonatomic,strong) UITextField* urlInput;
@property (nonatomic,strong) UIButton* loadURLButton;
@property (nonatomic,strong) UIButton* logButton;
@property (nonatomic,strong) UIWebView* webview;
@end

@implementation WebViewProtocolController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _urlInput = [UITextField new];
    [self.view addSubview:_urlInput];
    _urlInput.backgroundColor = [UIColor grayColor];
//    _urlInput.text = @"http://www.kaola.com/webapp/pub/app.html";
    _urlInput.text = @"http://www.kaola.com/webapp/res/image/loading.gif";
    
    _loadURLButton = [[UIButton alloc]init];
    [self.view addSubview:_loadURLButton];
    [_loadURLButton setTitle:@"加载url" forState:UIControlStateNormal];
    [_loadURLButton addTarget:self action:@selector(loadURLButtonClick) forControlEvents:UIControlEventTouchUpInside];
    _loadURLButton.backgroundColor = [UIColor blueColor];
    
    _logButton = [[UIButton alloc]init];
    [self.view addSubview:_logButton];
    [_logButton setTitle:@"打印缓存信息" forState:UIControlStateNormal];
    [_logButton addTarget:self action:@selector(logButtonClick) forControlEvents:UIControlEventTouchUpInside];
    _logButton.backgroundColor = [UIColor blueColor];
    
    
    _webview = [UIWebView new];
    [self.view addSubview:_webview];
    _webview.delegate = self;
    _webview.backgroundColor = [UIColor grayColor];
    

}

- (void)viewWillLayoutSubviews
{
    _urlInput.frame = CGRectMake(0, 100, self.view.bounds.size.width, 30);
    
    _loadURLButton.frame = CGRectMake(20, 140, 100, 30);
    _logButton.frame = CGRectMake(150, 140, 150, 30);
    
    _webview.frame = CGRectMake(0, CGRectGetMaxY(_logButton.frame)+10, self.view.bounds.size.width, self.view.bounds.size.height - (CGRectGetMaxY(_logButton.frame)+10));
}

- (void)loadURLButtonClick
{
    NSString* url = _urlInput.text;
    NSURLRequest* request = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:url]];
    [_webview loadRequest:request];
}

- (void)logButtonClick
{
    NSLog(@"%@",[CCCandyWebCache defaultWebCache]);
}

#pragma mark -- UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"Webview did start, %ld", (long)[[NSDate date] timeIntervalSince1970]);
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSLog(@"Webview did end, %ld", (long)[[NSDate date] timeIntervalSince1970]);
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(nullable NSError *)error
{
    
}

@end
