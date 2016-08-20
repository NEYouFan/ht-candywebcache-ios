//
//  HTFileTransferItem.h
//  HTFileDownloader
//
//  Created by 小丸子 on 26/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTFileTransferConst.h"

@interface HTFileTransferItem : NSObject<NSCopying>

// downloadTask的ID,
@property (nonatomic, strong, nonnull) NSString * downloadId;

// 下载目标url
@property (nonatomic, strong, nonnull) NSURL * url;

// 下载状态
@property (nonatomic, assign) HTFileTransferState status;

/*
 * 文件总大小
 */
@property (nonatomic, assign) NSInteger totalContentLength;

/*
 * 文件已接收大小
 */
@property (nonatomic, assign) NSInteger totalReceivedContentLength;

/*
 * 文件下载进度
 */
@property (nonatomic, assign) CGFloat progress;

/*
 * 临时文件名
 */
@property (nonatomic, strong, nullable) NSString * tempFileName;

/*
 * 文件名
 */
@property (nonatomic, strong, nullable) NSString * fileName;

/*
 * 下载内容的md5值，用于断点续传的完整性校验（暂时不用）
 */
@property (nonatomic, strong, nullable) NSString * md5;

/**
 *  下载首次开始的时间。会根据此时间值清理数据库。
 */
@property (nonatomic, assign) NSInteger startDownloadTime;


// http status
@property (nonatomic, assign) NSInteger lastHttpStatusCode;

// 错误的message信息
@property (nonatomic, strong, nullable) NSString* errorMessageInfo;

-(nullable HTFileTransferItem *)initWithUrl:(nonnull NSURL *)url;

-(id) copyWithZone:(NSZone *)zone;

@end
