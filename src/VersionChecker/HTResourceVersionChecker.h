//
//  CCVersionChecker.h
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import <Foundation/Foundation.h>
#import "HTResourceVersionInfo.h"

typedef NS_ENUM(NSInteger, HTResourceType)
{
    HTResourceTypeNone = 0,
    HTResourceTypeWebApp,
    HTResourceTypeHotfix
};

@protocol HTResourceVersionCheckerDelegate;

@interface HTResourceVersionChecker: NSObject

/*
 * 请求VersionCheck的服务器地址
 */
@property (nonatomic, strong, nonnull) NSString * host;

/*
 * 指定额外的request header, 使用者可以通过该属性自定义请求头部
 */
@property (nonatomic, strong, nullable) NSDictionary *HTTPAdditionalHeaders;

/*
 * 指定额外的request body,使用者可以通过该属性设置自定义的request body
 */
@property (nonatomic, strong, nullable) NSString * userAdditionalData;

/*
 * HTResourceVersionChecker的代理对象
 */
@property (nonatomic, weak) id<HTResourceVersionCheckerDelegate> versionCheckerDelegate;

/*
 * 构造函数
 */
-(_Nonnull instancetype)initWithDelegate:(_Nullable id<HTResourceVersionCheckerDelegate>)delegate withHost:( NSString * _Nullable ) host;

/*
 * 指定appInfo以及资源版本信息,使用者通过调用此接口对相关资源进行版本检查, check的结果通过代理对象返回
 *
 * @param: resourceType             检查版本的资源类型
 * @param: appId,                   native appID
 * @param: appVersion,               native app version
 * @param: resInfos,                 本地资源信息信息
 * @param: checkCompletionHandler,      check结束回调
 */
-(void)checkVersionWithType:(NSInteger)resourceType
                      appId:(nonnull NSString *)appId
                 appVersion:(nonnull NSString *)appVersion
                   resInfos:(nullable NSArray *)resInfos
                     isDiff:(BOOL)isDiff
                 isAutoFill:(BOOL)isAutoFill
     checkCompletionHandler:(void (^ _Nullable)(NSArray<HTResourceVersionInfo *> * __nullable versionInfoArray, NSError * __nullable error))checkCompletionHandler;


@end


@protocol HTResourceVersionCheckerDelegate <NSObject>

@optional
/*
 * 定义request
 *
 * @param:request, 当前构造的request.
 * @return: 返回定制后的request.
 * @Info: 可通过此接口添加request header和request body
 */
-(NSMutableURLRequest *)HTResourceVersionChecker:(nonnull HTResourceVersionChecker *)versionChecker
                                customizeRequest:(nonnull NSMutableURLRequest *)request;

@end
