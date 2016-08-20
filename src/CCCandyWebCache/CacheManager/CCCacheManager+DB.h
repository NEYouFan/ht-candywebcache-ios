//
//  CCCacheManager+DB.h
//  Pods
//
//  Created by jw on 6/8/16.
//
//

#import "CCCacheManager.h"
#import "CCWebAppInfo.h"
#import "CCResourceIndexInfo.h"

@interface CCCacheManager (DB)

/**
 *  创建数据库，包含两张表：WEBAPPINFOS和PATHINDEX
 *
 *  @param path 数据库保存路径
 *
 */
- (BOOL)DB_createDatabaseAtPath:(NSString*)path;

/**
 *  从数据库读取webapp信息
 *
 *  @return webapp信息数据
 */
- (NSArray<CCWebAppInfo*>*)DB_readWebAppInfos;

/**
 *  写入webapp信息到数据库，写入之前会清空之前数据
 *
 *  @param webAppInfos webapp信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_writeWebAppInfos:(NSArray<CCWebAppInfo*>*)webAppInfos;

/**
 *  插入单个webapp信息到数据库
 *
 *  @param webAppInfo webapp信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_insertWebAppInfo:(CCWebAppInfo*)webAppInfo;

/**
 *  删除单个webapp信息到数据库
 *
 *  @param webAppInfo webapp信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_deleteWebAppInfo:(CCWebAppInfo*)webAppInfo;

/**
 *  更新单个webapp信息到数据库
 *
 *  @param webAppInfo webapp信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_updateWebAppInfo:(CCWebAppInfo*)webAppInfo;

/**
 *  删除多个指定名称的webapp信息
 *
 *  @param webappNames 需要删除的webapp名称
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_deleteWebAppInfoWithNames:(NSArray<NSString*>*)webappNames;

/**
 *  从数据库读取资源索引信息
 *
 *  @return 资源索引信息
 */
- (NSArray<CCResourceIndexInfo*>*)DB_readResourceIndexInfos;

/**
 *  写入资源索引信息到数据库，写入之前会清空之前数据
 *
 *  @param resourceIndexInfos 资源索引信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_writeResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)resourceIndexInfos;

/**
 *  插入单个资源索引信息到数据库
 *
 *  @param resourceIndexInfo 资源索引信息
 *
 *  @return YES:成功，NO:失败
 */
- (BOOL)DB_insertResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)resourceIndexInfos;

/**
 *  删除单个资源索引信息到数据库
 *
 *  @param resourceIndexInfo 资源索引信息
 *
 *  @return YES:成功，NO:失败
 */
//- (BOOL)DB_deleteResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)resourceIndexInfos;

/**
 *  删除多个指定url的资源索引信息
 *
 *  @param webappNames 需要删除的资源url
 *
 *  @return YES:成功，NO:失败
 */
//- (BOOL)DB_deleteResourceIndexInfoWithURLs:(NSArray<NSString*>*)urls;


- (BOOL)DB_deleteResourceIndexInfoWithWebappNames:(NSArray<NSString*>*)webappNames;


@end
