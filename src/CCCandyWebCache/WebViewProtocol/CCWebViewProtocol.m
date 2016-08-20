//
//  CCWebViewProtocol.m
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import "CCWebViewProtocol.h"
#import "HTFileDownloader+MD5.h"
#import "CCLogger.h"

static id<CCWebViewProtocolDelegate> webViewProtocolDelegate;
// test code
//static NSString * const MyURLProtocolHandledKey = @"MyURLProtocolHandledKey";

@interface CCWebViewProtocol() <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSMutableData * cacheData;
@property (nonatomic, strong) NSURLSession * session;
@property (nonatomic, strong) NSURLSessionDataTask * downloadTask;

@end

@implementation CCWebViewProtocol

- (NSURLSession *)session {
    
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    }
    return _session;
}

+(void)setWebViewProtocolDelegate:(id<CCWebViewProtocolDelegate>)webViewDelegate{
    
    webViewProtocolDelegate = webViewDelegate;
}

#pragma mark - test
- (NSString *)filePathWithUrlString:(NSString *)urlString {
    
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *fileName = [urlString MD5];
    return [cachesPath stringByAppendingPathComponent:fileName];
}


#pragma mark - override

+(BOOL)canInitWithRequest:(NSURLRequest *)request{
    // 判断是否拦截请求
    if (webViewProtocolDelegate && [webViewProtocolDelegate respondsToSelector:@selector(canWebViewProtocolResponseURL:)]) {
        return [webViewProtocolDelegate canWebViewProtocolResponseURL:[request.URL absoluteString]];
    }else{
        return NO;
    }
    // for test
    /*if ([NSURLProtocol propertyForKey:MyURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    
    return YES;*/
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    
    return [super requestIsCacheEquivalent:a toRequest:b];
}

-(void)startLoading{
    
    // 再次获取cacheData
    NSURL * url = self.request.URL;
    NSData * cacheData = nil;
    if ([webViewProtocolDelegate respondsToSelector:@selector(dataForWebViewProtocolWithURL:)]) {
        
        cacheData = [webViewProtocolDelegate dataForWebViewProtocolWithURL:[url absoluteString]];
        if (cacheData == nil) {
            
            // 发送网络请求
            //NSLog(@"---response through network: %@", url.absoluteString);
            self.downloadTask = [self.session dataTaskWithRequest:self.request];
            [self.downloadTask resume];
        }
        else{
            // TODO: 考虑response header的问题
            //NSLog(@"+++reponse from cache:%@", url.absoluteString);
            NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc]
                                           initWithURL:url
                                           statusCode:200
                                           HTTPVersion:@"HTTP/1.1"
                                           headerFields:[NSDictionary dictionary]];
                        
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocol:self didLoadData:cacheData];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }
    
}

-(void)stopLoading{
    
    [self.downloadTask cancel];
    self.downloadTask = nil;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    // 允许处理服务器的响应，才会继续接收服务器返回的数据
    completionHandler(NSURLSessionResponseAllow);
    /******* test code *******/
    self.cacheData = [NSMutableData data];
    /*************************/
}

-(void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didReceiveData:(nonnull NSData *)data{
    
    [self.client URLProtocol:self didLoadData:data];
    /******* test code *******/
    [self.cacheData appendData:data];
    /*************************/
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    //    下载完成之后的处理
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        //将数据存入到本地文件中
        /******* test code *******/
        [self.cacheData writeToFile:[self filePathWithUrlString:self.request.URL.absoluteString] atomically:YES];
        /*************************/
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end
