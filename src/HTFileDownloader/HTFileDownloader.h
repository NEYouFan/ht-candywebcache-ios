//
//  HTFileDownloader.h
//  HTFileDownloader
//
//  Created by 小丸子 on 23/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTFileDownloadTask.h"
#import "HTFileTransferItem.h"

@class HTFileDownloader;

@protocol HTFileDownloaderDelegate<NSObject>

@optional

/*
 * Optionally customize the background session configuration.
 */
-(void)HTFileDownloader:(nonnull HTFileDownloader*)fileDownloader customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration*)backgroundSessionConfiguration;


-(NSURLSessionAuthChallengeDisposition)HTFileDownloader:(nonnull HTFileDownloader*)fielDownloader
                      didReceiveAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
                                         withCredential:(NSURLCredential **)credential;

@end

@interface HTFileDownloader : NSObject

/*
 * 最大并发数。不设置则采用默认设置：6
 */
@property (nonatomic, assign) NSInteger maxConcurrentDownloadsCount;

/*
 * 下载根路径。只能在创建downloader时设置，如果不设置，则使用默认路径
 */
@property (nonatomic, strong, readonly, nonnull) NSString * rootDownloadPath;

/**
 *  定制的headers.基于downloader的所有下载请求都共享些headers。但是对于同一header项，如果单个下载请求也进行了设置，则单个请求所设置的header优先级较高
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary * httpAdditionalHeaders;


/** Attention: 同时只能存在一种类型的downloader**/

/*
 * 创建并初始化backgroundSession，支持后台下载 （暂时勿用）
 * 
 * @param: delegate, HTFileDownloaderDelegate的delegate对象,
 * @param: downloadPathUrl配置的下载路径,可以为空,为空的话,采用默认的下载路径
 * @param: httpAdditionalHeaders配置基于此downloader所有task的额外的header
 */

-(nullable instancetype)initBackgroundDownloaderWithDelegate:(nullable id<HTFileDownloaderDelegate>)aDelegate
                                            withDownloadPath:(nullable NSString *)rootDownloadPath
                                       withAdditionalHeaders:(nullable NSDictionary*)httpAdditionalHeaders;
/**
 * 创建defaultSession,不支持后台下载
 *
 * @param delegate, HTFileDownloaderDelegate对象
 * @param downloadPathUrl, 设置的下载路径，如果不设置，NSHomeDirectory()/HTFileDownlader/
 * @param: httpAdditionalHeaders配置基于此downloader所有task的额外的header
 */

-(nullable instancetype)initStandardDownloaderWithDelegate:(nullable id<HTFileDownloaderDelegate>)delegate
                                          withDownloadPath:(nullable NSString *)rootDownloadPath
                                     withAdditioanlHeaders:(nullable NSDictionary *)httpAdditionalHeaders;
/**
 *  根据url构造downloadTask
 *
 *  @param url      下载资源的url
 *  @param delegate downloadTask代理对象
 *
 *  @return downloadTask对象
 */
-(nullable HTFileDownloadTask *)downloadTaskWithUrl:(nullable NSURL *)url
                                       withDelegate:(nullable id<HTFileDownloadTaskDelegate>)delegate;

/**
 *  通过HTFileTransferItem对象创建downloadTask, 此类task主要用于重建上次未完成的任务
 *
 *  @param downloadItem 用来构造task的item对象，
 *  @param delegate     downloadTask代理对象
 *
 *  @return downloadTask对象
 */
-(nullable HTFileDownloadTask *)downloadTaskWithDownloadItem:(nullable HTFileTransferItem *)downloadItem
                                                withDelegate:(nullable id<HTFileDownloadTaskDelegate>)delegate;


/**
 *  获取所有保存记录的downloadItems，包括已完成的和未完成的
 *
 *  @return 所有记录的downloadItems集合
 */
-(nonnull NSArray<HTFileTransferItem *> *)downloadItems;


/**
 *  获取上次未完成的所有downloadItems对象。所有的downloadItem对象中包含断点续传的信息。使用者再获取这些items后，
 *  可以调用downloadTaskWithDownloadItem方法，创建task,通过调用resume方法，可以进行断点续传。
 *
 *  @return 上次未完成的所有downloadItems对象
 */
-(nullable NSArray<HTFileTransferItem *>*)suspendedOrFailedItems;

/**
 *  暂停当前所有downloadItems;
 */
-(void)suspendedAllDownloadItems;


@end
