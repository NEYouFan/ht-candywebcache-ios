//
//  CCCacheManager.m
//  CandyWebCache
//
//  Created by jw on 6/2/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import "CCCacheManager.h"
#import "HTFileDownloader.h"
#import "CCCacheManager+DB.h"
#import "CCWebAppInfo.h"
#import "CCResourceIndexInfo.h"
#import "HTFileDownloader.h"
#import "HTFileDownloadTask.h"
#import "CCCacheManager+Download.h"
#import "HTFileDownloader+MD5.h"
#import "NSString+Path.h"
#import "CCLogger.h"
#import "NSString+MD5Encrypt.h"
#import "CCValidationChecker.h"
#import "CCBackgroundQueue.h"


@interface CCCacheManager ()<NSCacheDelegate,HTFileDownloaderDelegate>

//key:webapp名称+资源相对路径
@property (nonatomic, strong) NSCache* memCache;

//url到key的map映射缓存
@property (nonatomic, copy) NSCache* urlToKeyMapCache;
@end

@implementation CCCacheManager

- (instancetype)initWithRootPath:(NSString*)rootPath
{
    self = [super init];
    if (self) {
        _memCache = [[NSCache alloc]init];
        _memCache.totalCostLimit = 5 * 1024 * 1024;
        _memCache.delegate = self;
        _urlToKeyMapCache = [NSCache new];
        _urlToKeyMapCache.totalCostLimit = _memCache.totalCostLimit / 5;

        _webappInfos = [[CCThreadSafeMutableDictionary alloc]init];
        _resourceIndexInfos = [[CCThreadSafeMutableDictionary alloc]init];
        _domainWebappInfos = [[CCThreadSafeMutableDictionary alloc]init];
        _rootPath = rootPath;
        _state = CCCacheManagerStateUninitialed;
        
        [self setupNotification];
    }
    return self;
}

//#pragma mark -- first install
- (BOOL)isFirstInstall
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"CCCandyWebCacheEverLaunched"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CCCandyWebCacheEverLaunched"];
        return YES;
    }
    else{
        return NO;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
    
    [[NSNotificationCenter defaultCenter]removeObserver:self
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
}

- (void)initializeWithCompleteBlock:(void (^)(void))completeBlock
{
    
    __block NSArray<CCWebAppInfo*>* webappInfos;
    __block NSArray<CCResourceIndexInfo*>* resourceIndexInfos;
    
    [[CCBackgroundQueue sharedInstance] dispatchAsync:^{
        NSString* webappPath = [NSString stringWithFormat:@"%@/webapps",_rootPath];
        NSString* downloadPath = [NSString stringWithFormat:@"%@/download",_rootPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:webappPath isDirectory:nil]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:webappPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:downloadPath isDirectory:nil]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        BOOL result = [self DB_createDatabaseAtPath:[NSString stringWithFormat:@"%@/CCCache.db",webappPath]];
        if (!result) {
            CCLogError(@"[CCCacheManager]:创建数据库失败");
        }
        
        //_fileDownloader = [[HTFileDownloader alloc] initBackgroundDownloaderWithDelegate:self withDownloadPath:downloadPath withAdditionalHeaders:nil];
        _fileDownloader = [[HTFileDownloader alloc] initStandardDownloaderWithDelegate:self withDownloadPath:downloadPath withAdditioanlHeaders:nil];
        
        webappInfos = [self DB_readWebAppInfos];
        resourceIndexInfos = [self DB_readResourceIndexInfos];
        
        void (^block)(void) = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                for (CCWebAppInfo* info in webappInfos) {
                    
                    //之前正在更新的状态，置为出错状态
                    if (info.status == CCWebAppStatusUpdating) {
                        info.status = CCWebAppStatusError;
                    }
                    [_webappInfos setObject:info forKey:info.name];
                    for (NSString* domain in info.domains) {
                        [_domainWebappInfos setObject:info forKey:domain];
                    }
                }
                
                for (CCResourceIndexInfo* info in resourceIndexInfos) {
                    [_resourceIndexInfos setObject:info forKey:[NSString stringWithFormat:@"%@/%@",info.webappName,info.url]];
                }
                _state = CCCacheManagerStateAvailable;
                if (completeBlock) {
                    completeBlock();
                }
            });
        };
        
        if ([self isFirstInstall]) {
            //首次启动，进行首次安装包检测
            NSString *packagePath = [[[NSBundle mainBundle]resourcePath] stringByAppendingString:@"/CandyWebCache"];
            [self firstInitWithCheckPackagePath:packagePath completeBlock:^{
                block();
            }];
        }else{
            block();
        }
    }];
}

-(void)setupNotification
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)setMemCacheSize:(NSUInteger)memCacheSize
{
    _memCache.totalCostLimit = memCacheSize;
}

- (void)updateResourceOfWebAppInfo:(CCWebAppInfo*)webappInfo
{
    [self innerUpdateResourceOfWebAppInfo:webappInfo];
}

- (NSData*)dataForURL:(NSString*)url
{
    if (_state != CCCacheManagerStateAvailable) {
        CCLogWarn(@"[CCCacheManager]:CacheManager尚未初始化完成。");
        return nil;
    }
    __block NSString* key = [_urlToKeyMapCache objectForKey:url];
    if (!key){
        NSArray* strs = [url componentsSeparatedByString:@"://"];
        if (strs.count == 2) {
            url = strs[1];
        }else{
            CCLogWarn(@"[CCCacheManager]:收到非法格式url请求:%@。",url);
            return nil;
        }
        
        [_domainWebappInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull domain, CCWebAppInfo * _Nonnull webappInfo, BOOL * _Nonnull stop) {
            if ([url hasPrefix:domain]) {
                if (webappInfo.status != CCWebAppStatusAvailable) {
                    CCLogWarn(@"[CCCacheManager]:资源正在更新或已出错,请求不使用缓存，url==>:%@。",url);
                }
                key = [NSString stringWithFormat:@"%@/%@",webappInfo.name,[url substringFromIndex:domain.length+1]];
                [_urlToKeyMapCache setObject:key forKey:url];
                *stop = YES;
            }
        }];
    }
    if (!key) {
        CCLogInfo(@"[CCCacheManager]:未命中缓存:%@。",url);
        return nil;
    }
    //优先使用缓存
    NSData* data = [_memCache objectForKey:key];
    if (data) {
        CCLogInfo(@"[CCCacheManager]:内存命中缓存:%@。",url);
        return data;
    }
    CCResourceIndexInfo* resInfo = [_resourceIndexInfos objectForKey:key];
    
    if (!resInfo) {
        CCLogInfo(@"[CCCacheManager]:未命中缓存:%@。",url);
        return nil;
    }
    //此处暂时不做md5校验
    data = [NSData dataWithContentsOfFile:resInfo.localFullPath];
    if (data) {
        CCLogInfo(@"[CCCacheManager]:磁盘命中缓存:%@。",url);
        [_memCache setObject:data forKey:key cost:[data length]];
    }else{
        CCLogInfo(@"[CCCacheManager]:未命中缓存:%@。",url);
    }
    return data;
}

- (CCWebAppInfo*)webAppInfoWithName:(NSString*)webappName
{
    return [_webappInfos objectForKey:webappName];
}

- (NSString*)localResourcePathOfURL:(NSString*)url
{
    return [_resourceIndexInfos objectForKey:url].url;
}

- (NSArray<CCWebAppInfo*>*)webAppInfos;
{
    return [_webappInfos allValues];
}

- (NSUInteger)diskSizeOfWebApps
{
    if (_state != CCCacheManagerStateAvailable) {
        CCLogWarn(@"CCCacheManager尚未初始化，无法获取webapp大小。");
        return 0;
    }
    NSUInteger size = 0;
    for (CCWebAppInfo* info in [_webappInfos allValues]) {
        size += info.diskSize;
    }
    return size;
}

- (void)clearCacheOfWebAppWithName:(NSString*)webappName
{
    if (_state != CCCacheManagerStateAvailable) {
        CCLogWarn(@"CCCacheManager尚未初始化，无法清理webapp:%@。",webappName);
        return;
    }

    if (!webappName || [webappName isEqualToString:@""]) {
        return;
    }
    
    CCWebAppInfo* webappInfo = [_webappInfos objectForKey:webappName];
    if (!webappInfo) {
        return;
    }
    if (webappInfo.status == CCWebAppStatusUpdating) {
        CCLogWarn(@"webapp正在更新，不允许清理:%@。",webappName);
        return;
    }
    
    NSMutableArray* urlArray = [NSMutableArray new];
    [_resourceIndexInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CCResourceIndexInfo * _Nonnull info, BOOL * _Nonnull stop) {
        if ([info.webappName isEqualToString:webappName]) {
            [urlArray addObject:key];
        }
    }];
    
    //删除内存缓存
    [self clearMemCacheOfWebAppWithName:webappName];
    
    //删除磁盘数据、删除数据库
    [[CCBackgroundQueue sharedInstance] dispatchAsync:^{
        NSError* error;
        [[NSFileManager defaultManager] removeItemAtPath:webappInfo.localFullPath error:&error];
        if (error) {
            CCLogError(@"[CCCacheManager]:删除磁盘数据出错:%@",error);
        }
        [self DB_deleteWebAppInfoWithNames:@[webappName]];
        [self DB_deleteResourceIndexInfoWithWebappNames:@[webappName]];
    }];
    
    //删除数据
    [_webappInfos removeObjectForKey:webappName];
    [webappInfo.domains enumerateObjectsUsingBlock:^(NSString * _Nonnull domain, NSUInteger idx, BOOL * _Nonnull stop) {
        [_domainWebappInfos removeObjectForKey:domain];
    }];
    [urlArray enumerateObjectsUsingBlock:^(id  _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        [_resourceIndexInfos removeObjectForKey:url];
    }];
}

- (void)clearMemCacheOfWebAppWithName:(NSString*)webappName
{
    [_resourceIndexInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CCResourceIndexInfo * _Nonnull info, BOOL * _Nonnull stop) {
        if ([info.webappName isEqualToString:webappName]) {
            NSString* key = [info uniqueKey];
            [_memCache removeObjectForKey:key];
        }
    }];
    [_urlToKeyMapCache removeAllObjects];
}

- (void)clearCacheOfWebApps
{
    [[CCBackgroundQueue sharedInstance] dispatchAsync:^{
        [_webappInfos enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull webappName, CCWebAppInfo * _Nonnull obj, BOOL * _Nonnull stop) {
            [self clearCacheOfWebAppWithName:webappName];
        }];
    }];
}

- (void)clearMemCache
{
    [_memCache removeAllObjects];
    [_urlToKeyMapCache removeAllObjects];
}

- (void)cache:(NSCache *)cache willEvictObject:(id)obj
{
    CCLogDebug(@"内存缓存释放一个缓存对象。");
}

- (NSArray<CCWebAppInfo*>*)allWebAppInfos
{
    return [self.webappInfos allValues];
}

- (void)firstInitWithCheckPackagePath:(NSString*)packagePath completeBlock:(void (^)(void))block
{
    __weak CCCacheManager* weakSelf = self;
    
    [[CCBackgroundQueue sharedInstance] dispatchAsync:^{
        NSString* configFile = [NSString stringWithFormat:@"%@/WebappInfo.json",packagePath];
        if(![[NSFileManager defaultManager] fileExistsAtPath:configFile])
        {
            CCLogWarn(@"[CCCacheManager]:首次安装包配置文件不存在。");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) {
                    block();
                }
            });
            return;
        }
        
        CCThreadSafeMutableDictionary<NSString*,CCWebAppInfo*>* webAppInfos = [CCThreadSafeMutableDictionary new];
        NSData* data = [NSData dataWithContentsOfFile:configFile];
        NSError* error = nil;
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            CCLogError(@"[CCCacheManager]:解析打包资源webapp信息文件出错:%@",error);
        }
        NSArray* webappJson = [json objectForKey:@"appVersionInfos"];
        for (NSDictionary* dic in webappJson) {
            CCWebAppInfo* info = [CCWebAppInfo new];
            info.name = [dic objectForKey:@"appId"];
            info.version = [dic objectForKey:@"version"];
            info.domains = [dic objectForKey:@"domains"];
            info.fullPackageMD5 = [[dic objectForKey:@"fullMd5"] decryptedMD5];
            info.fullDownloadURL = [dic objectForKey:@"fullUrl"];
            [webAppInfos setObject:info forKey:info.name];
        }
        
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:packagePath]
                                                                 includingPropertiesForKeys:@[NSURLIsDirectoryKey,NSURLNameKey]
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler:^BOOL(NSURL *url, NSError *error)
                                             {
                                                 return YES;
                                             }];
        for (NSURL *fileURL in enumerator) {
            NSNumber *isDirectory;
            [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            
            NSString *fileName;
            [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];
            
            if ([isDirectory boolValue]) {
                [enumerator skipDescendants];
                continue;
            }else{
                if ([[fileName pathExtension] isEqualToString:@"zip"]) {
                    NSString* webappName = [fileName stringByDeletingPathExtension];
                    CCLogInfo(@"[CCCacheManager]:首次安装webapp:%@",webappName);
                    CCWebAppInfo* webappInfo = [webAppInfos objectForKey:webappName];
                    if (!webappInfo) {
                        CCLogError(@"[CCCacheManager]:webapp信息文件与资源包未同步",@([webAppInfos count]));
                        continue;
                    }
                    
                    if (![CCValidationChecker file:fileURL.path md5Maching:webappInfo.fullPackageMD5]) {
                        CCLogError(@"[CCCacheManager]:首次安装包MD5校验失败:%@",webappName);
                        continue;
                    }
                    
                    NSString* localWebappPath = [NSString stringWithFormat:@"%@/webapps/%@",weakSelf.rootPath,webappName];
                    [[NSFileManager defaultManager] removeItemAtPath:localWebappPath error:nil];
                    [[NSFileManager defaultManager]createDirectoryAtPath:localWebappPath withIntermediateDirectories:YES attributes:nil error:nil];
                    webappInfo.localRelativePath = [localWebappPath stringWithPathRelativeTo:[NSString documentPath]];
                    
                    NSString* zipPath = [NSString stringWithFormat:@"%@/webapps/%@/%@.zip",weakSelf.rootPath,webappName,webappName];
                    [[NSFileManager defaultManager] copyItemAtPath:[fileURL path] toPath:zipPath error:&error];
                    if (error) {
                        CCLogError(@"[CCCacheManager]:首次启动，移动压缩包到指定目录失败:%@",error);
                        continue;
                    }
                    
                    [weakSelf replaceOrAddWebAppInfo:webappInfo];
                    [weakSelf unzipInfosWithZipFile:zipPath toWebAppInfo:webappInfo];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (block) {
                block();
            }
        });
    }];
}

- (NSString *)description
{
    NSMutableString* des = [NSMutableString new];
    [des appendString:@"WebappInfos ===>\n"];
    for (CCWebAppInfo* info in [_webappInfos allValues]) {
        [des appendString:[info description]];
    }
//    [des appendString:@"ResourceInfos ===>\n"];
//    for (CCResourceIndexInfo* info in [_resourceIndexInfos allValues] ) {
//        [des appendString:[info description]];
//    }
    return des;
}
@end
