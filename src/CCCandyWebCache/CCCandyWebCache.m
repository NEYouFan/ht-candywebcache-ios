//
//  CCCandyWebCache.m
//  CandyWebCache
//
//  Created by jw on 5/27/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "CCCandyWebCache.h"
#import "CCWebViewProtocol.h"
#import "CCLogger.h"
#import "NSString+MD5Encrypt.h"


static CCCandyWebCacheConfig* defaultConfig = nil;

typedef NS_ENUM(NSInteger,CCCandyWebCacheStatus)
{
    CCCandyWebCacheStatusUnInited =1,
    CCCandyWebCacheStatusAvailable
};

@implementation CCCandyWebCacheConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _appName = @"";
        _appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        _pullInterval = 0;
        _blackListResourceTypes = [NSArray new];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *rootPath = [paths objectAtIndex:0];
        _cacheRootPath = rootPath;
        _serverAddress = @"";
        
    }
    return self;
}

@end

@interface CCCandyWebCache ()<HTResourceVersionCheckerDelegate,CCWebAppUpdateProtocol,CCWebViewProtocolDelegate>
@property (nonatomic, copy) NSString* appName;
@property (nonatomic, copy) NSString* appVersion;
@property (nonatomic, strong) HTResourceVersionChecker* versionChecker;
@property (nonatomic, copy) NSMutableArray<id<CCWebAppUpdateProtocol>>* observers;
@property (nonatomic, strong) NSTimer* checkTimer;
@property (nonatomic, copy) NSMutableSet* blackListMap;
@property (nonatomic, assign)CCCandyWebCacheStatus status;
@end


@implementation CCCandyWebCache

+ (instancetype)defaultWebCache
{
    static CCCandyWebCache* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!defaultConfig) {
            defaultConfig = [CCCandyWebCacheConfig new];
        }
        instance = [[CCCandyWebCache alloc]initWithConfiguration:defaultConfig];
    });
    return instance;
}

+ (void)setDefaultConfiguration:(CCCandyWebCacheConfig*)config
{
    if (defaultConfig) {
        CCLogError(@"[CCCandyWebCache]:配置信息必须在使用之前设置。");
        return;
    }else{
        if (config) {
            defaultConfig = config;
        }
    }
}

+ (void)setLogEnable:(BOOL)enable
{
    [CCLogger setEnable:enable];
}


+ (void)setLogLevel:(CCLoggerLevel)level
{
    [CCLogger setLogLevel:level];
}

- (instancetype)initWithConfiguration:(CCCandyWebCacheConfig*)config
{
    self = [super init];
    if (self) {
        
        _appName = config.appName;
        _appVersion = config.appVersion;
        _cacheManager = [[CCCacheManager alloc]initWithRootPath:config.cacheRootPath];
        _cacheManager.delegate = self;
        _versionChecker = [[HTResourceVersionChecker alloc]initWithDelegate:self withHost:config.serverAddress];
        [CCWebViewProtocol setWebViewProtocolDelegate:self];
        _observers = [NSMutableArray new];
        _blackListMap = [NSMutableSet setWithArray:config.blackListResourceTypes];
        _enable = YES;
        _diffEnable = YES;
        
        _status = CCCandyWebCacheStatusUnInited;
        
        void (^block)(void) = ^{
            if (_enable) {
                if (config.pullInterval > 0) {
                    _checkTimer = [NSTimer scheduledTimerWithTimeInterval:config.pullInterval target:self selector:@selector(checkAndUpdateResource) userInfo:nil repeats:YES];
                }
                //注册拦截器
                [NSURLProtocol registerClass:[CCWebViewProtocol class]];
            }
            
            _status = CCCandyWebCacheStatusAvailable;
            
            //首次启动，就检测资源更新，以恢复之前存在的断点下载
            [self checkAndUpdateResource];
        };
        
        [_cacheManager initializeWithCompleteBlock:^{
            block();
        }];
    }
    return self;
}

- (void)setEnable:(BOOL)enable
{
    _enable = enable;
    static NSTimeInterval interval = 0;
    if (_enable) {
        [NSURLProtocol registerClass:[CCWebViewProtocol class]];
        if (interval > 0) {
            _checkTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(checkAndUpdateResource) userInfo:nil repeats:YES];
        }
        
    }else{
        [NSURLProtocol unregisterClass:[CCWebViewProtocol class]];
        if (_checkTimer) {
            interval = _checkTimer.timeInterval;
            [_checkTimer invalidate];
            _checkTimer = nil;
        }
    }
}

- (void)checkAndUpdateResource
{
    if (!_enable) {
        CCLogWarn(@"[CCCandyWebCache]:已禁用");
        return;
    }
    if (_status == CCCandyWebCacheStatusUnInited) {
        return;
    }
    //读取本地webapp信息,检查webapp信息更新
    NSArray<CCWebAppInfo*>* webappInfos = [_cacheManager allWebAppInfos];
    __weak CCCandyWebCache* weakSelf = self;
    
    NSMutableArray * resInfos = [NSMutableArray array];
    for (CCWebAppInfo * webAppInfo in webappInfos) {
        NSMutableArray * subArray = [[NSMutableArray alloc]initWithCapacity:2];
        [subArray addObject:webAppInfo.name];
        [subArray addObject:webAppInfo.version];
        [resInfos addObject:subArray];
    }
    
    [_versionChecker checkVersionWithType:HTResourceTypeWebApp
                                    appId:_appName
                               appVersion:_appVersion
                                 resInfos:resInfos
                                   isDiff:_diffEnable
                               isAutoFill:@YES
                   checkCompletionHandler:^(NSArray<HTResourceVersionInfo *> * _Nullable versionInfoArray, NSError * _Nullable error) {
        
        for (HTResourceVersionInfo* versionInfo in versionInfoArray) {
            
            //更新
            if (versionInfo.state == HTResourceVersionCheckerStateNeedUpdate) {
                CCLogDebug(@"[CCCandyWebCache]:资源需要%@更新:%@",versionInfo.diffUrl ? @"增量":@"全量",versionInfo.resID);
                CCWebAppInfo* webappInfo = [CCWebAppInfo new];
                if (!versionInfo.resID) {
                    CCLogWarn(@"[CCCandyWebCache]:resID为空。");
                    continue;
                }
                webappInfo.name = versionInfo.resID;
                webappInfo.version = versionInfo.version;
                webappInfo.diffPackageMD5 = [versionInfo.diffMd5 decryptedMD5];
                webappInfo.diffDownloadURL = versionInfo.diffUrl;
                webappInfo.fullPackageMD5 = [versionInfo.fullMd5 decryptedMD5];
                webappInfo.fullDownloadURL = versionInfo.fullUrl;
                webappInfo.isDiffTask = _diffEnable ? (versionInfo.diffUrl ? YES : NO) : NO;
               // NSDictionary * userData =[NSJSONSerialization J:versionInfo.userData options:kNilOptions error:nil];
                webappInfo.domains = [[NSJSONSerialization JSONObjectWithData:[versionInfo.userData dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil] objectForKey:@"domains"];

                [weakSelf.cacheManager updateResourceOfWebAppInfo:webappInfo];
            }else if(versionInfo.state == HTResourceVersionCheckerStateNotExisted){
                //删除
                CCLogWarn(@"[CCCandyWebCache]:请求更新不存在，删除本地资源:%@",versionInfo.resID);
                [_cacheManager clearCacheOfWebAppWithName:versionInfo.resID];
            }else if(versionInfo.state == HTResourceVersionCheckerStateLatest){
                CCLogDebug(@"[CCCandyWebCache]:本地是最新包，不需要更新:%@",versionInfo.resID);
            }
        }
    }];
}

//- (void)updateWithPushInfo:(NSDictionary*)pushInfo
//{
//
//}

- (void)updateWithWebAppsInfos:(NSArray<NSDictionary*>*)webappsInfos
{
    //暂时不做
}

- (void)addObserver:(id<CCWebAppUpdateProtocol>)observer
{
    [_observers addObject:observer];
}

- (void)removeObserver:(id<CCWebAppUpdateProtocol>)observer
{
    [_observers removeObject:observer];
}

- (void)dealloc
{
    if (_checkTimer) {
        [_checkTimer invalidate];
    }
}


- (NSString *)description
{
    NSMutableString* des = [NSMutableString new];
    [des appendString:@"******CandyWebCache Begin******\n"];
    [des appendString:[_cacheManager description]];
    [des appendString:@"******CandyWebCache End******\n"];
    return des;
}

#pragma mark -- CCWebAppUpdateDelegate

- (BOOL)CCCacheManager:(CCCacheManager*)manager shouldUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:shouldUpdateWebAppOfURL:withInfo:)]) {
            if (![observer CCCacheManager:manager shouldUpdateWebAppOfURL:url withInfo:info]) {
                return NO;
            }
        }
    }
    return YES;
}

- (void)CCCacheManager:(CCCacheManager*)manager willStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:willStartDownloadWebAppOfURL:withInfo:)]) {
            [observer CCCacheManager:manager willStartDownloadWebAppOfURL:url withInfo:info];
        }
    }
}

- (void)CCCacheManager:(CCCacheManager*)manager didStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:didStartDownloadWebAppOfURL:withInfo:)]) {
            [observer CCCacheManager:manager didStartDownloadWebAppOfURL:url withInfo:info];
        }
    }
}

- (void)CCCacheManager:(CCCacheManager*)manager updatingWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:updatingWebAppOfURL:withInfo:)]) {
            [observer CCCacheManager:manager updatingWebAppOfURL:url withInfo:info];
        }
    }
}

- (void)CCCacheManager:(CCCacheManager*)manager didFinishDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:didFinishDownloadWebAppOfURL:withInfo:)]) {
            [observer CCCacheManager:manager didFinishDownloadWebAppOfURL:url withInfo:info];
        }
    }
}

- (void)CCCacheManager:(CCCacheManager*)manager didUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info
{
    CCLogInfo(@"[CCCandyWebCache]:更新webapp成功===>%@",info.name);
    //更新成功，清除内存缓存
    [_cacheManager clearMemCacheOfWebAppWithName:info.name];
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:didUpdateWebAppOfURL:withInfo:)]) {
            [observer CCCacheManager:manager didUpdateWebAppOfURL:url withInfo:info];
        }
    }
}

- (void)CCCacheManager:(CCCacheManager*)manager failedUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info error:(CCWebAppUpdateError)error
{
    //增量更新失败，自动全量更新
    if (info.isDiffTask && info.fullDownloadURL) {
        info.isDiffTask = NO;
        CCLogWarn(@"[CCCandyWebCache]:增量更新失败，开始全量更新:%@",info.name);
        [_cacheManager updateResourceOfWebAppInfo:info];
        return;
    }
    
    for (id<CCWebAppUpdateProtocol> observer in _observers) {
        if ([observer respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
            [observer CCCacheManager:manager failedUpdateWebAppOfURL:url withInfo:info error:error];
        }
    }
}

#pragma mark -- CCWebViewProtocolDelegate
-(BOOL)canWebViewProtocolResponseURL:(NSString *)url
{
    if (_blackListMap.count >0) {
        NSString* suffix = [url pathExtension];
        if (suffix && [_blackListMap containsObject:suffix]) {
            CCLogWarn(@"[CCCandyWebCache]:请求黑名单类型资源类型:%@",url);
            return NO;
        }
    }
    return [_cacheManager dataForURL:url] ? YES : NO;
}

- (NSData *)dataForWebViewProtocolWithURL:(NSString*)url
{
    return [_cacheManager dataForURL:url];
}

@end
