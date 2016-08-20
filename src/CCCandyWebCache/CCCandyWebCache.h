//
//  CCCandyWebCache.h
//  CandyWebCache
//
//  Created by jw on 5/27/16.
//  Copyright © 2016 jw. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "CCCacheManager.h"
#import "HTResourceVersionChecker.h"
#import "CCLogger.h"


@class CCCandyWebCache;

@interface CCCandyWebCacheConfig : NSObject

/**
 *  app名称
 */
@property (nonatomic, copy) NSString* appName;

/**
 *  app版本号，默认为工程app version
 */
@property (nonatomic, copy) NSString* appVersion;

/**
 *  资源更新检测时间间隔。单位秒，默认是0，表示不做定期资源更新检测。
 */
@property (nonatomic,assign) NSInteger pullInterval;

/**
 *  资源类型黑名单，名单中的文件将不使用缓存资源。
 */
@property (nonatomic, copy) NSArray<NSString*>* blackListResourceTypes;

/**
 *  资源缓存本地根路径
 */
@property (nonatomic, copy) NSString* cacheRootPath;

/**
 *  CandyWebCache服务器地址
 */
@property (nonatomic, copy) NSString* serverAddress;

@end


@interface CCCandyWebCache : NSObject

/**
 *  设置默认单例的配置信息，只允许设置一次。如要设置config，需要在第一次使用defaultWebCache之前调用该方法。
 *
 *  @param config 配置信息。如果传nil，则使用默认配置信息。
 */
+ (void)setDefaultConfiguration:(CCCandyWebCacheConfig*)config;


/**
 *  默认单例。获取实例之前，要求已经调用initDefaultConfiguration接口。
 *
 *  @return 实例
 */
+ (instancetype)defaultWebCache;

/**
 *  打印log信息控制
 *
 *  @param enable YES:打印log，NO:关闭log
 */
+ (void)setLogEnable:(BOOL)enable;

/**
 *  日志级别，只有大于等于设定日志级别的日志会被打印
 *
 *  @param level 日志级别
 */
+ (void)setLogLevel:(CCLoggerLevel)level;

/**
 *  资源管理器，可以直接对该对象进行配置。
 */
@property (nonatomic, strong, readonly) CCCacheManager* cacheManager;

/**
 *  CandyWebCache全局开关。默认打开
 */
@property (nonatomic, assign) BOOL enable;

/**
 *  CandyWebCache增量更新开关。默认打开
 */
@property (nonatomic, assign) BOOL diffEnable;


/**
 *  检查并更新资源信息。(非可靠，可能根据内部状态拒绝)
 */
- (void)checkAndUpdateResource;

/**
 *  收到推送更新消息，更新资源信息。
 *
 *  @param pushInfo 更新消息
 */
//- (void)updateWithPushInfo:(NSDictionary*)pushInfo;

/**
 *  根据webapp信息，更新一组webapp资源信息。
 *
 *  @param webappsInfos webapp信息
 */
- (void)updateWithWebAppsInfos:(NSArray<NSDictionary*>*)webappsInfos;//暂时不做

/**
 *  添加资源更新监听器（强引用）。需要在合适的时机调用removeObserver防止内存泄露。
 *  注意：如果observer实现了CCCacheManager:shouldUpdateWebAppOfURL:withInfo:方法，则只要有一个observer返回了NO,webapp都不会更新。
 */
- (void)addObserver:(id<CCWebAppUpdateProtocol>)observer;

/**
 *  添加资源更新监听器（弱引用）。
 */
//- (void)addWeakObserver:(id<CCWebAppUpdateDelegate>)weakObserver;//暂时不做

/**
 *  删除资源更新监听器。
 */
- (void)removeObserver:(id<CCWebAppUpdateProtocol>)observer;

@end
