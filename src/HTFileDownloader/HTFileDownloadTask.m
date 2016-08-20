//
//  HTFileDownloadTask.m
//  HTFileDownloader
//
//  Created by 小丸子 on 26/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTFileDownloadTask.h"
#import "HTFileDownloader.h"
#import "HTFileDownloader+Private.h" 
#import <UIKit/UIKit.h>

@interface HTFileDownloadTask()

@end

@implementation HTFileDownloadTask

- (void)dealloc {
}

-(void)resume
{
    [self.fileDownloader startWithDownloadTask:self];
}

-(void)suspend
{
    [self.fileDownloader suspendWithDownloadTask:self];
}

-(void)cancel
{
    [self.fileDownloader deleteWithDownloadTask:self];
}

-(nonnull NSString *)downloadID
{
    return self.downloadTaskData.downloadId;
}

@end

