//
//  HTResourceVersionChecker.m
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import "HTResourceVersionChecker.h"
#import "HTThreadSafeMutableDictionary.h"

static const NSString * protocolVersion = @"0.1";

@interface HTResourceVersionChecker() <NSURLSessionDelegate>

// 服务器响应数据
@property (nonatomic, strong) NSMutableData * responseData;
@property (nonatomic, strong) HTThreadSafeMutableDictionary * localVersionForResourceDic;

@end

@implementation HTResourceVersionChecker

-(instancetype)initWithDelegate:(id<HTResourceVersionCheckerDelegate>)delegate withHost:(NSString *)host{
    
    self = [super init];
    if (self) {
        
        _versionCheckerDelegate = delegate;
        _host = host;
        //_localVersionForResourceDic = [CCThreadSafeMutableDictionary dictionary];
        _localVersionForResourceDic = [HTThreadSafeMutableDictionary dictionary];
    }
    return self;
}

/*
 {
 "appInfo":{
 "nativeId":"KaoLa",
 "nativeVersion":"20160531",
 "appInfos":{
 [
 {
 "appId":'Login',
 "version":'20160531'
 },
 {
 "appId":'Store',
 "version":'20160531'
 }
 ]
 }
 }，
 "userData":""
 }
 */

-(void)checkVersionWithType:(NSInteger)resourceType
                      appId:(nonnull NSString *)appId
                 appVersion:(nonnull NSString *)appVersion
                   resInfos:(nullable NSArray *)resInfos
                     isDiff:(BOOL)isDiff
                 isAutoFill:(BOOL)isAutoFill
     checkCompletionHandler:(void (^ _Nullable)(NSArray<HTResourceVersionInfo *> * __nullable versionInfoArray, NSError * __nullable error))checkCompletionHandler{
    
    
    NSString * checkInfoBody = [self convertToJsonStringWithApp:appId appVersion:appVersion resourceInfos:resInfos isDiff:isDiff isAutoFill:isAutoFill];
    
    //创建请求对象
    NSString * versionCheckerApiType = nil;
    if (resourceType == HTResourceTypeWebApp) {
        versionCheckerApiType = @"webapp";
    }
    else if(resourceType == HTResourceTypeHotfix){
        versionCheckerApiType = @"hotfix";
    }
    
    NSString * urlString = [NSString stringWithFormat:@"http://%@/%@/%@/%@", self.host, @"api", @"version_check", versionCheckerApiType];
    NSURL * checkUrl = [NSURL URLWithString:urlString];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:checkUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData * postBody = [NSMutableData data];
    [postBody appendData:[checkInfoBody dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:postBody];
    
    if ([self.versionCheckerDelegate respondsToSelector:@selector(HTResourceVersionChecker:customizeRequest:)]) {
        
        NSMutableURLRequest * customizedReqeust = [self.versionCheckerDelegate HTResourceVersionChecker:self customizeRequest:request];
        request = customizedReqeust;
    }
    
    NSLog(@"[D]:%@_%d %@",[[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, @"[CCCacheManager]:开始检查更新");
    //CCLogDebug(@"[CCCacheManager]:开始检查更新");
    
    //创建会话对象，设置代理
    NSURLSession * session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                           delegate:self
                                                      delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request
                                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                     
                                                     NSArray * versionInfoArray = nil;
                                                     if (error == nil) {
                                                         NSError * checkError = nil;
                                                         versionInfoArray = [self parseServerResponseData:data withError:&checkError];
                                                         
                                                         checkCompletionHandler(versionInfoArray, checkError);
                                                     }
                                                     else{
                                                         //如果request发生错误，如连接超时等
                                                         checkCompletionHandler(versionInfoArray, error);
                                                         
                                                         NSString *errorString = [[NSString alloc]initWithFormat:@"[CCCacheManager]:资源检查更新出错: %@", error ];
                                                         NSLog(@"[E]:%@_%d %@",[[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, errorString);
                                                         //CCLogError(@"[CCCacheManager]:资源检查更新出错: %@", error);
                                                     }
                                                     
                                                 }];
    [dataTask resume];
    
}

-(NSString *)convertToJsonStringWithApp:(NSString *)appId
                             appVersion:(NSString *)appVersion
                          resourceInfos:(NSArray *)resourceInfos
                                 isDiff:(BOOL)isDiff
                             isAutoFill:(BOOL)isAutoFill{
    
    NSMutableArray * resourceInfosArray = [NSMutableArray array];
    
    for(id resourceInfo in resourceInfos){
        NSMutableDictionary * resourceInfoDic = [NSMutableDictionary dictionary];
        [resourceInfoDic setValue:resourceInfo[0] forKey:@"resID"];
        [resourceInfoDic setValue:resourceInfo[1] forKey:@"resVersion"];
        [resourceInfosArray addObject:resourceInfoDic];
        if (resourceInfo[0]) {
            _localVersionForResourceDic[resourceInfo[0]] = resourceInfo[1];
        }
    }
    
    NSMutableDictionary * appInfo = [[NSMutableDictionary alloc]init];
    [appInfo setValue:protocolVersion forKey:@"version"];
    [appInfo setValue:appId forKey:@"appID"];
    [appInfo setValue:appVersion forKey:@"appVersion"];
    [appInfo setValue:@"ios" forKey:@"platform"];
    if (isDiff) {
        [appInfo setValue:@YES forKey:@"isDiff"];
    }
    else{
        [appInfo setValue:@NO forKey:@"isDiff"];
    }
    if (isDiff) {
        [appInfo setValue:@YES forKey:@"autoFill"];
    }
    else{
        [appInfo setValue:@NO forKey:@"autoFill"];
    }
    
    if (resourceInfosArray.count != 0) {
        [appInfo setValue:resourceInfosArray forKey:@"resInfos"];
    }
    
    NSError * error = nil;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:appInfo options:NSJSONWritingPrettyPrinted error:&error];
    NSString * jsonString = nil;
    if (error == nil) {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
    
}

-(NSArray<HTResourceVersionInfo*> *)parseServerResponseData:(NSData * )responseData withError:(NSError **)error{
    
    NSMutableArray<HTResourceVersionInfo *> * mutableVersionInfoArray = [NSMutableArray array];
    
    NSDictionary * responseDic = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:nil];
    
    if (responseDic.count) {
        
        NSInteger resultCode = [[responseDic objectForKey:@"code"]integerValue];
        NSString * errorMsg = [responseDic objectForKey:@"errMsg"];
        if (resultCode == HTResourceVersionCheckerSuccess) {
            
            if ([responseDic objectForKey:@"data"] != nil){
                NSDictionary * appVersionInfosDic = [responseDic objectForKey:@"data"];
                if (appVersionInfosDic != nil) {
                    
                    if ([appVersionInfosDic objectForKey:@"resInfos"] != nil){
                        NSArray<NSDictionary*> * appVersionInfosArray = [appVersionInfosDic objectForKey:@"resInfos"];
                        for (NSDictionary * appVersionInfoDic in appVersionInfosArray) {
                            
                            HTResourceVersionInfo * appVersionInfo = [[HTResourceVersionInfo alloc]init];
                            appVersionInfo.resID = [appVersionInfoDic objectForKey:@"resID"];
                            
                            appVersionInfo.state = [[appVersionInfoDic objectForKey:@"state"] integerValue];
                            
                            if (appVersionInfo.state == HTResourceVersionCheckerStateLatest || appVersionInfo.state == HTResourceVersionCheckerStateNotExisted) {
                                
                                [mutableVersionInfoArray addObject:appVersionInfo];
                                continue;
                            }
                            else if(appVersionInfo.state == HTResourceVersionCheckerStateNeedUpdate || appVersionInfo.state == HTResourceVesrionCheckerStateAutoFillResource){
                                
                                appVersionInfo.userData = [appVersionInfoDic objectForKey:@"userData"];
                                appVersionInfo.version = [appVersionInfoDic objectForKey:@"resVersion"];
                                appVersionInfo.diffUrl = [appVersionInfoDic objectForKey:@"diffUrl"];
                                appVersionInfo.diffMd5 = [appVersionInfoDic objectForKey:@"diffMd5"];
                                appVersionInfo.fullUrl = [appVersionInfoDic objectForKey:@"fullUrl"];
                                appVersionInfo.fullMd5 = [appVersionInfoDic objectForKey:@"fullMd5"];
                                
                                //TODO: _localVersionForWebappsDic中不存在对应的项会怎么样
                                if ([_localVersionForResourceDic objectForKey:appVersionInfo.resID] != nil) {
                                    appVersionInfo.localVersion = _localVersionForResourceDic[appVersionInfo.resID];
                                }
                                [mutableVersionInfoArray addObject:appVersionInfo];
                            }
                            
                        }
                        
                    }
                }
                
            }
            else{
                
                NSError * checkError = [[NSError alloc]initWithDomain:@"CheckeVersionError" code:resultCode userInfo:@{@"errMsg":errorMsg}];
                if (error) {
                    *error = checkError;
                }
            }
        }
        
    }
    
    NSArray<HTResourceVersionInfo *> * versionInfoArray = [mutableVersionInfoArray copy];
    return versionInfoArray;
}
@end
