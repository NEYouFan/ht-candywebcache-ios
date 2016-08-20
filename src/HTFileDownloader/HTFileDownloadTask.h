//
//  HTFileDownloadTask.h
//  HTFileDownloader
//
//  Created by 小丸子 on 26/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTFileTransferConst.h"

@protocol HTFileDownloadTaskDelegate;
@class HTFileDownloader;
@class HTFileTransferItem;

@interface HTFileDownloadTask : NSObject

/*
 * 优先级
 */
@property (nonatomic, assign) float priority;

/*
 * task相关的数据信息，（readonly)
 */
@property (nonatomic, strong, nullable) HTFileTransferItem * downloadTaskData;

/*
 * urlsession dataTask 对象
 */
@property (nonatomic, strong, nullable) NSURLSessionDataTask * sessionDataTask;

/*
 * 资源本地存储路径
 */
@property (nonatomic, strong, nullable) NSString * fullDownloadPath;

/*
 * 临时存储路径
 */
@property (nonatomic, strong, nullable) NSString * tmpFullDownloadPath;

/*
 * downloader对象
 */
@property (nonatomic, weak, nullable) HTFileDownloader * fileDownloader;

/*
 * 代理对象
 */
@property (nonatomic, nullable) id<HTFileDownloadTaskDelegate> downloadTaskDelegate;

/*
 * 任务start入口
 */
-(void)resume;

/*
 * 暂停任务。被暂停的任务可以调用resume,继续下载
 */
-(void)suspend;

/*
 * 取消任务。被取消的任务(删除),不被downloader继续管理，所以的数据信息也会被删除。被取消的任务不支持断点继续下载
 */
-(void)cancel;

/**
 *  获取downloadTask的downloadID
 *
 *  @return downloadID
 */
-(nonnull NSString *)downloadID;

@end


@protocol HTFileDownloadTaskDelegate <NSObject>
@optional

/**
 *  cutomize 请求header或body. 可通过此方法设置额外的header或body.
 *
 *  @param downloadTask 下载任务对象
 *  @param request      当前request对象
 *
 *  @return 定制后的request对象
 */
-(nonnull NSMutableURLRequest *)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask customizeRequest:(nonnull NSMutableURLRequest *)request;

/**
 *  任务出错回调
 *
 *  @param downloadTask 当前fail的task对象，包含失败时刻task的下载状态、进度
 *  @param error        下载出错信息，错误类型：client-error, server-error, local-error
 *  @Info: 使用者可以根据错误类型选择性尝试重新下载。eg:如果是client-error:connection lost,可以检测网络正常连接后再尝试重新下载
 */
-(void)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask didFailedWithError:(nonnull NSError *)error;

/**
 *  任务resume失败
 *
 *  @param downloadTask 失败的task对象
 *  @param error        出错信息
 *  @Info:提供默认的处理方式，重新构建新的request,从新开始下载。
 */
-(void)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask didResumeFailedWithError:(nonnull NSError *)error;

/**
 * 使用者判断httpStatus，决定是否存在server response error。
 *
 *  @prarm httpStatusCode    response中获取的return code.
 *  @Info: 默认的判断200-299都是合法的return code. 否则，存在server error.
 */
-(BOOL)HTFileDownloadTask:(nonnull HTFileDownloadTask*)downloadTask isInvalidForHttpStatusCode:(NSInteger)httpStatusCode;

/**
 *  <#Description#>
 *
 *  @param downloadTask <#downloadTask description#>
 *  @param challenge    <#challenge description#>
 *  @param credential   <#credential description#>
 *
 *  @return <#return value description#>
 */
-(NSURLSessionAuthChallengeDisposition)HTFileDownloadTask:(nonnull HTFileDownloadTask*)downloadTask
                       didReceiveAuthenticationChanllenge:(nonnull NSURLAuthenticationChallenge *)challenge
                                               withCredential:(NSURLCredential **)credential;


/**
 * 进度更新回调
 */
-(void)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask
    didUpdatedWithProgress:(CGFloat)progress
    receivedSize:(NSInteger)receivedSize
    totalSizeExpected:(NSInteger) totalSizeExpected
    totalSizeReceived:(NSInteger) totalSizeReceived;

/**
 * 下载任务成功结束回调。
 */
-(void)didFinishSuccessWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

/**
 * 任务中止回调。
 */
-(void)didPausedWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

/**
 * 任务取消回调
 */
-(void)didCancelledWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

/**
 * 任务开始回调
 */
-(void)didStartedWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;




@end
