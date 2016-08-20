//
//  CCWebViewProtocol.h
//  Pods
//
//  Created by 小丸子 on 7/6/2016.
//
//

#import <Foundation/Foundation.h>

@class CCWebViewProtocol;

/*
 * 此protocol定义了获取cacheData的接口
 */
@protocol  CCWebViewProtocolDelegate <NSObject>

@required

/**
 *  获取指定url资源的本地缓存数据。delegate必须实现此接口
 *
 *  @param protocol   CCWebViewProtocol实例对象
 *  @param requestURL 被请求资源的url
 *
 *  @return 资源的本地缓存数据。 如果本地没有缓存数据，则为nil，表明需要向网络请求资源
 */
-(NSData *)dataForWebViewProtocolWithURL:(NSString *)requestURL;

/**
 *  代理是否能响应url
 *
 *  @param requestURL 被请求资源的url
 *
 *  @return YES or NO
 */
-(BOOL)canWebViewProtocolResponseURL:(NSString *)requestURL;

@end;

@interface CCWebViewProtocol : NSURLProtocol

/*
 * 设置单例的delegate对象
 */
+(void)setWebViewProtocolDelegate:(nonnull id<CCWebViewProtocolDelegate>)webViewDelegate;

@end

