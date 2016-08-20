//
//  HTResourceVersionInfo.h
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import <Foundation/Foundation.h>

/**
 * HTResourceVersionCheckerState:定义对应WebApp的版本状态
 */
typedef NS_ENUM(NSInteger, HTResourceVersionCheckerState)
{
    HTResourceVersionCheckerStateNone = -1,   // 初始化状态
    HTResourceVersionCheckerStateLatest,     // 本地app已最新
    HTResourceVersionCheckerStateNeedUpdate, // 需要更新
    HTResourceVersionCheckerStateNotExisted,  // 资源不存在
    HTResourceVesrionCheckerStateAutoFillResource //请求中未携带资源信息，是自动补全资源信息
};

/**
 * HTResourceVersionCheckerror:定义本次check/update返回的错误码
 */
typedef NS_ENUM(NSInteger, HTResourceVersionCheckerError)
{
    HTResourceVersionCheckerSuccess = 200,
    HTResourceVersionCheckerErrorProtocolVersion = 401,	// 协议版本不支持
    HTResourceVersionCheckerErrorAppID = 401, // appID不支持
    HTResourceVersionCheckerErrorServer = 501,  // 服务端错误
    HTResourceVersionCheckerErrorUnknown //其他未知错误
};

/**
 * HTResourceVersionInfo: 定义返回的版本信息的类对象结构
 */
@interface HTResourceVersionInfo : NSObject

@property (nonatomic, strong,nonnull) NSString * resID;               // 资源 Id
@property (nonatomic, assign) HTResourceVersionCheckerState state;    // 资源更新状态码
@property (nonatomic, strong, nullable) NSString * localVersion;      // 资源本地版本
@property (nonatomic, strong, nullable) NSString * version;           // 资源最新的版本，
@property (nonatomic, strong, nullable) NSString * diffUrl;           // 增量包的下载url
@property (nonatomic, strong, nullable) NSString * diffMd5;           // 增量包的md5值，用于完整性校验
@property (nonatomic, strong, nullable) NSString * fullUrl;           // 全量包的下载url
@property (nonatomic, strong, nullable) NSString * fullMd5;           // 全量包的md5值，用于完整性校验
@property (nonatomic, strong, nullable) NSString * userData;          // 用户自定义数据

@end
