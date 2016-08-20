//
//  CCWebAppInfo.h
//  Pods
//
//  Created by jw on 6/7/16.
//
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger,CCWebAppStatus)
{
    CCWebAppStatusNone = 0,
    CCWebAppStatusAvailable = 1,
    CCWebAppStatusUpdating,
//    CCWebAppStatusExpired,
    CCWebAppStatusError
};

/**
 *  webapp信息
 */
@interface CCWebAppInfo : NSObject

/**
 *  webapp名称，全局唯一。
 */
@property (nonatomic, copy) NSString* name;

/**
 *  webapp所属域名
 */
@property (nonatomic, copy) NSArray<NSString*>* domains;

/**
 *  webapp本地版本号
 */
@property (nonatomic, copy) NSString* version;

/**
 *  webapp增量包md5值
 */
@property (nonatomic, copy) NSString* diffPackageMD5;

/**
 *  webapp增量包下载路径
 */
@property (nonatomic, copy) NSString* diffDownloadURL;

/**
 *  webapp全量包md5值
 */
@property (nonatomic, copy) NSString* fullPackageMD5;

/**
 *  webapp全量包下载路径
 */
@property (nonatomic, copy) NSString* fullDownloadURL;

/**
 *  webapp本地路径，例如rootPath/webapps/webapp1
 */
//@property (nonatomic, copy) NSString* localPath;

/**
 *  资源本地相对路径，相对于Document目录
 */
@property (nonatomic, copy) NSString* localRelativePath;

/**
 *  资源本地全路径
 */
@property (nonatomic, copy, readonly) NSString* localFullPath;

/**
 *  webapp当前状态
 */
@property (nonatomic, assign) CCWebAppStatus status;

/**
 *  webapp更新进度百分比
 */
@property (nonatomic, assign) float updatePercent;

/**
 *  webapp所占磁盘大小(字节)
 */
@property (nonatomic, assign) unsigned long long diskSize;

/**
 *  下载压缩包的任务id，用于断点下载的恢复
 */
@property (nonatomic, copy) NSString* taskID;

/**
 *  当前下载任务是否是增量更新任务，用于断点下载的恢复
 */
@property (nonatomic, assign) BOOL isDiffTask;


- (NSString*)composeVersion;

@end
