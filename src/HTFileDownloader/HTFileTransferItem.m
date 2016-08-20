//
//  HTFileTransferItem.m
//  HTFileDownloader
//
//  Created by 小丸子 on 26/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTFileTransferItem.h"

@interface HTFileTransferItem()

@end

@implementation HTFileTransferItem

- (nullable HTFileTransferItem *)initWithUrl:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.url = url;
    }
    
    return self;
}

-(id)copyWithZone:(NSZone *)zone{
    
    HTFileTransferItem * item = [[HTFileTransferItem allocWithZone:zone]init];
    item.downloadId = [_downloadId copy];
    item.url = [_url copy];
    item.status = _status;
    item.totalContentLength = _totalContentLength;
    item.totalReceivedContentLength = _totalReceivedContentLength;
    item.progress = _progress;
    item.tempFileName = [_tempFileName copy];
    item.startDownloadTime = _startDownloadTime;
    item.fileName = _fileName;
    return item;
}

@end
