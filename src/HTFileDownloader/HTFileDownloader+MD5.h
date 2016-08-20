//
//  HTFileDownloader+MD5.h
//  HTFileDownloader
//
//  Created by 小丸子 on 17/6/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTFileDownloader.h"

@interface NSData (MD5)
- (NSString *)MD5;
@end

@interface NSString (MD5)
- (NSString *)MD5;
@end