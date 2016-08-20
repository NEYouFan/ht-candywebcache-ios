//
//  HTFileDownloader+Private.h
//  HTFileDownloader
//
//  Created by 小丸子 on 31/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTFileDownloader.h"

@interface HTFileDownloader (Private)


-(void)startWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

-(void)suspendWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

-(void)deleteWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask;

@end
