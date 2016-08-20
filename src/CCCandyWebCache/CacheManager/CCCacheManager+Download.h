//
//  CCCacheManager+Download.h
//  Pods
//
//  Created by jw on 6/15/16.
//
//

#import "CCCandyWebCache.h"
#import "HTFileDownloader.h"
#import "CCWebAppInfo.h"
#import "CCResourceIndexInfo.h"
#import "CCThreadSafeMutableDictionary.h"

@interface CCCacheManager ()
@property (nonatomic, strong) HTFileDownloader* fileDownloader;
//key:appname
@property (nonatomic, copy) CCThreadSafeMutableDictionary<NSString*,CCWebAppInfo*>* webappInfos;

//key:domain
@property (nonatomic, copy) CCThreadSafeMutableDictionary<NSString*,CCWebAppInfo*>* domainWebappInfos;

//key:webapp名称+资源相对路径
@property (nonatomic, copy) CCThreadSafeMutableDictionary<NSString*,CCResourceIndexInfo*>* resourceIndexInfos;

@end


@interface CCCacheManager (Download)

- (void)innerUpdateResourceOfWebAppInfo:(CCWebAppInfo*)webappInfo;

- (void)unzipInfosWithZipFile:(NSString*)zipFile toWebAppInfo:(CCWebAppInfo*)webappInfo;

-(void)appDidEnterBackground:(NSNotification *)notification;

-(void)appDidEnterForeground:(NSNotification *)notification;

- (BOOL)replaceOrAddWebAppInfo:(CCWebAppInfo*)webappInfo;

- (BOOL)removeWebAppInfo:(CCWebAppInfo*)webappInfo;
@end
