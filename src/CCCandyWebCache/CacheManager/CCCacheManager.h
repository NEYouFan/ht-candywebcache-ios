//
//  CCCacheManager.h
//  CandyWebCache
//
//  Created by jw on 6/2/16.
//  Copyright © 2016 jw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCWebAppInfo.h"


@class CCCacheManager;

typedef NS_ENUM(NSInteger,CCCacheManagerState)
{
    CCCacheManagerStateUninitialed = 0,
    CCCacheManagerStateAvailable
};

typedef NS_ENUM(NSInteger,CCWebAppUpdateError)
{
    CCWebAppUpdateErrorDownload = 1,
    CCWebAppUpdateErrorDiffMerge,
    CCWebAppUpdateErrorNotValid,
    CCWebAppUpdateErrorUnzip,
    CCWebAppUpdateErrorLocalAppNotExist
};

@protocol CCWebAppUpdateProtocol <NSObject>

@optional
/**
 *  实现CCWebAppUpdateProtocol的对象可以判定是否更新webapp
 *
 *  @return YES:更新，NO:不更新
 */
- (BOOL)CCCacheManager:(CCCacheManager*)manager shouldUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager willStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager didStartDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager updatingWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager didFinishDownloadWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager didUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info;

- (void)CCCacheManager:(CCCacheManager*)manager failedUpdateWebAppOfURL:(NSString*)url withInfo:(CCWebAppInfo*)info error:(CCWebAppUpdateError)error;

@end


@interface CCCacheManager : NSObject

/**
 *  CCCacheManager当前状态
 */
@property (nonatomic, assign, readonly) CCCacheManagerState state;

/**
 *  资源缓存本地根路径
 */
@property (nonatomic, copy, readonly) NSString* rootPath;

/**
 *  资源下载并发数,默认5
 */
@property (nonatomic, assign) NSUInteger concurrentDownloadCount;

/**
 *  资源内存缓存最大开销（非严格）。默认5 *1024 * 1024 （5M）字节。
 */
@property (nonatomic, assign) NSUInteger memCacheSize;

/**
 *  代理对象
 */
@property (nonatomic, weak) id<CCWebAppUpdateProtocol> delegate;

/**
 *  构造函数
 *
 *  @param rootPath 资源缓存根路径
 *
 *  @return 实例
 */
- (instancetype)initWithRootPath:(NSString*)rootPath;

/**
 *  创建数据库及相关目录、从数据库异步加载数据.
 *  注意：需要调用该接口完成初始化。
 *
 *  @param completeBlock
 */
- (void)initializeWithCompleteBlock:(void (^)(void))completeBlock;

/**
 *  更新资源。非可靠，可能忽略更新，如当前正在更新资源、代理不允许更新等
 *
 *  @param webappInfo webapp信息
 *
 */
- (void)updateResourceOfWebAppInfo:(CCWebAppInfo*)webappInfo;

/**
 *  获取url对应的资源数据
 *
 *  @param url url
 *
 *  @return url对应资源数据
 */
- (NSData*)dataForURL:(NSString*)url;

/**
 *  根据webapp名称，获取其app信息
 *
 *  @param webappName webapp名称
 *
 *  @return webapp信息
 */
- (CCWebAppInfo*)webAppInfoWithName:(NSString*)webappName;

/**
 *  获取url对应本地资源路径
 *
 *  @param url url
 *
 *  @return url对应本地资源路径，如果不存在，返回nil
 */
- (NSString*)localResourcePathOfURL:(NSString*)url;

/**
 *  获取所有webapp名称
 *
 *  @return webapp名称数组
 */
- (NSArray<CCWebAppInfo*>*)webAppInfos;

/**
 *  获取webapp本地资源所占磁盘空间总大小
 *
 *  @return webapp本地资源总大小
 */
- (NSUInteger)diskSizeOfWebApps;

/**
 *  清除webapp本地资源缓存(内存+磁盘)
 *
 *  @param webappName webapp名称
 *
 */
- (void)clearCacheOfWebAppWithName:(NSString*)webappName;

/**
 *  清除webapp本地资源内存缓存
 *
 *  @param webappName webapp名称
 *
 */
- (void)clearMemCacheOfWebAppWithName:(NSString*)webappName;

/**
 *  清除所有webapp本地资源缓存(内存+磁盘）
 *
 */
- (void)clearCacheOfWebApps;

/**
 *  清除内存缓存
 *
 */
- (void)clearMemCache;

/**
 *  获取所有webapp信息
 *
 *  @return webapp信息们
 */
- (NSArray<CCWebAppInfo*>*)allWebAppInfos;

/**
 *  首次安装初始化，要求全量包命名规则是：webappName_webappVersion.zip。
 *  domain信息保存在packagePath所在目录下的domains.config文件中
 *
 *  @param packagePath 全量包所在路径
 */
- (void)firstInitWithCheckPackagePath:(NSString*)packagePath completeBlock:(void (^)(void))block;

@end
