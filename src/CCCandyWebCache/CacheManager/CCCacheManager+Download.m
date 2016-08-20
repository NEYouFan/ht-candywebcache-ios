//
//  CCCacheManager+Download.m
//  Pods
//
//  Created by jw on 6/15/16.
//
//

#import "CCCacheManager+Download.h"
#import "HTFileDownloadTask.h"
#import "CCValidationChecker.h"
#import "bspatch.h"
#import "CCCacheManager+DB.h"
#import "HTFileDownloader+MD5.h"
#import "NSString+Path.h"
#import "NSString+Encrypt.h"
#import "NSDate+NSDateRFC1123.h"
#import "CCLogger.h"
#import "CCBackgroundQueue.h"
#import "ZipArchive.h"

@interface CCCacheManager ()<HTFileDownloadTaskDelegate>

@end

@implementation CCCacheManager (Download)

- (void)innerUpdateResourceOfWebAppInfo:(CCWebAppInfo*)webappInfo
{
    //应立即将资源标记为不可用状态，防止使用到老版本的资源
    webappInfo.status = CCWebAppStatusUpdating;
    
    CCWebAppInfo* waInfo = [self.webappInfos objectForKey:webappInfo.name];
    //当前webapp正在更新
    if (waInfo) {
        if (waInfo.status == CCWebAppStatusUpdating) {
            if (webappInfo != waInfo) {
                CCLogWarn(@"[CCCacheManager]:资源正在更新中,忽略更新请求：%@。",webappInfo.name);
                return;
            }else{
                //增量更新失败，全量更新逻辑
            }
        }else if(waInfo.status == CCWebAppStatusAvailable){
            //多线程情况下，判断本地正在更新或者本地已经更新完成
            BOOL shouldDownload = YES;
            if ([webappInfo.version isEqualToString:waInfo.version]) {
                shouldDownload = NO;
            }else{
                NSArray* comps = [waInfo.composeVersion componentsSeparatedByString:@"&"];
                if (comps.count == 2) {
                    if ([webappInfo.version isEqualToString:comps[1]]) {
                        shouldDownload = NO;
                    }
                }
            }
            if (!shouldDownload) {
                CCLogWarn(@"[CCCacheManager]:资源已经是最新版，忽略更新请求：%@。",webappInfo.name);
                return;
            }
        }
    }
    
    
    NSString* url = [self urlOfWebAppInfo:webappInfo];
    if ([self.delegate respondsToSelector:@selector(CCCacheManager:shouldUpdateWebAppOfURL:withInfo:)]) {
        if (![self.delegate CCCacheManager:self shouldUpdateWebAppOfURL:url withInfo:webappInfo]) {
            CCLogDebug(@"[CCCacheManager]:代理不允许更新资源。");
            return;
        }
    }

    NSString* localPath = [NSString stringWithFormat:@"%@/webapps/%@",self.rootPath,webappInfo.name];
    webappInfo.localRelativePath = [localPath stringWithPathRelativeTo:[NSString documentPath]];
    
    HTFileDownloadTask* task = [self.fileDownloader downloadTaskWithUrl:[NSURL URLWithString:url] withDelegate:self];
    if ([self.delegate respondsToSelector:@selector(CCCacheManager:willStartDownloadWebAppOfURL:withInfo:)]) {
        [self.delegate CCCacheManager:self willStartDownloadWebAppOfURL:url withInfo:webappInfo];
    }
    
    webappInfo.taskID = [task downloadID];
    
    if (waInfo) {
        webappInfo.version = [NSString stringWithFormat:@"%@%@%@",waInfo.version,@"&",webappInfo.version];
    }
    
    /**
     *  任务开始之前，先把webappinfo加入到信息列表中，如果之后遇到失败或者取消情况，需要适时的移除。
     */
    [[CCBackgroundQueue sharedInstance]dispatchSync:^{
        [self replaceOrAddWebAppInfo:webappInfo];
        CCLogDebug(@"[CCCacheManager]:开始更新资源");
        dispatch_async(dispatch_get_main_queue(), ^{
            [task resume];
            if ([self.delegate respondsToSelector:@selector(CCCacheManager:didStartDownloadWebAppOfURL:withInfo:)]) {
                [self.delegate CCCacheManager:self didStartDownloadWebAppOfURL:url withInfo:webappInfo];
            }
        });
    }];
}

//根据taskid查找对应的webappinfo
- (nonnull CCWebAppInfo*)webAppInfoForDownloadTask:(nonnull HTFileDownloadTask *)downloadTask
{
    CCWebAppInfo* info;
    for (CCWebAppInfo* i in [self.webappInfos allValues]) {
        if ([i.taskID isEqualToString:[downloadTask downloadID]]) {
            info = i;
            break;
        }
    }
    return info;
}

- (NSString*)urlOfWebAppInfo:(CCWebAppInfo*)webappInfo
{
    return webappInfo.isDiffTask ? webappInfo.diffDownloadURL : webappInfo.fullDownloadURL;
}

//app从前台进到后台，暂停正在进行的task
-(void)appDidEnterBackground:(NSNotification *)notification
{
    if(self.state != CCCacheManagerStateAvailable){
        return;
    }
    CCLogInfo(@"[CCCacheManager]:应用进入后台，暂停当前正在进行的任务");
    [self.fileDownloader suspendedAllDownloadItems];
}

//app从后台进到前台，resume暂停的task
-(void)appDidEnterForeground:(NSNotification *)notification
{
    if(self.state != CCCacheManagerStateAvailable){
        return;
    }
    CCLogInfo(@"[CCCacheManager]:应用进入前台，恢复之前暂停的任务");
    NSArray<HTFileTransferItem *> *suspendedItems = [self.fileDownloader suspendedOrFailedItems];
    //resume all suspended items. not failed ones.
    for (HTFileTransferItem * item in suspendedItems) {
        HTFileDownloadTask * downloadTask = [self.fileDownloader downloadTaskWithDownloadItem:item withDelegate:self];
        [downloadTask resume];
    }
}

#pragma mark -- HTFileDownloadTaskDelegate
/*-(nonnull NSMutableURLRequest *)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask customizeRequest:(nonnull NSMutableURLRequest *)request{
    
    // TODO: 从url中解析出haitao/testNOS
    NSString * date = [[NSDate date]rfc1123String];
    NSString * bucketAndObject = @"haitao/testNOS";
    NSString * key = @"467445ecf9f549cd916cb64f96664515";
    NSString * accessId = @"887fbe7bdff64097b45639112283c67c";
    //{method}\n{content-md5}\n{content-type}\n{date}\n{resource}
    NSString * signatureBaseString = [NSString stringWithFormat:@"GET\n\n\n\n%@\n/%@", date, bucketAndObject];
    NSString * signature = [signatureBaseString base64AfterSha256WithKey:key];
    //Authorization: NOS accessId:signature
    NSString * auth = [NSString stringWithFormat:@"NOS %@:%@", accessId, signature];
    [request setValue:auth forHTTPHeaderField:@"Authorization"];
    return request;
}*/
   
-(void)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask didFailedWithError:(nonnull NSError *)error;
{
    CCLogError(@"[CCCacheManager]:资源下载出错:%@",error);
    CCWebAppInfo* webappInfo = [self webAppInfoForDownloadTask:downloadTask];
    webappInfo.status = CCWebAppStatusError;
    //此处不应该删除webappinfo，因为，如果是增量更新，由于网络原因失败，删除webappInfo之后，下一次将会直接做全量更新，而不是断点下载
    if ([self.delegate respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
        [self.delegate CCCacheManager:self failedUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo] withInfo:webappInfo error:CCWebAppUpdateErrorDownload];
    }
}

-(void)didFinishSuccessWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask
{
    CCLogDebug(@"[CCCacheManager]:资源下载成功");
    CCWebAppInfo* webappInfo = [self webAppInfoForDownloadTask:downloadTask];
    NSString* downloadedPath = downloadTask.fullDownloadPath;
    if (!webappInfo) {
        //下载完成，webappinfo已经不存在
        [[NSFileManager defaultManager] removeItemAtPath:downloadedPath error:nil];
        CCLogWarn(@"[CCCacheManager]:下载完成，但webappinfo已经不存在。");
        return;
    }
    //下载完成
    if ([self.delegate respondsToSelector:@selector(CCCacheManager:didFinishDownloadWebAppOfURL:withInfo:)]) {
        [self.delegate CCCacheManager:self didFinishDownloadWebAppOfURL:[self urlOfWebAppInfo:webappInfo]  withInfo:webappInfo];
    }
    
    [[CCBackgroundQueue sharedInstance] dispatchAsync:^{
        
        //MD5校验
        if (![CCValidationChecker file:downloadedPath md5Maching:webappInfo.isDiffTask ? webappInfo.diffPackageMD5 : webappInfo.fullPackageMD5]) {
            CCLogError(@"[CCCacheManager]:资源MD5校验失败。");
            webappInfo.status = CCWebAppStatusError;
            if ([self.delegate respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CCCacheManager:self failedUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo]  withInfo:webappInfo error:CCWebAppUpdateErrorNotValid];
                    
                });
            }
            return;
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:webappInfo.localFullPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:webappInfo.localFullPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        NSString* ultimatePath = [NSString stringWithFormat:@"%@/%@.zip",webappInfo.localFullPath,webappInfo.name];
        if (webappInfo.isDiffTask) {
            CCLogDebug(@"[CCCacheManager]:增量更新，开始增量合并。");
            //diff合并v
            NSString* oldZip = ultimatePath;
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:oldZip]) {
                CCLogError(@"[CCCacheManager]:增量更新，但本地老的资源包已不存在。");
                [[NSFileManager defaultManager] removeItemAtPath:downloadedPath error:nil];
                webappInfo.status = CCWebAppStatusError;
                [self removeWebAppInfo:webappInfo];
                if ([self.delegate respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CCCacheManager:self failedUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo]  withInfo:webappInfo error:CCWebAppUpdateErrorDiffMerge];
                    });
                    
                }
                return;
            }else{
                char* argv[4];
                char* s = "bspatch";
                argv[0] = s;
                s = (char*)[oldZip UTF8String];
                argv[1] = s;
                NSString* newZip = [NSString stringWithFormat:@"%@/%@.zip.new",webappInfo.localFullPath,webappInfo.name];
                s = (char*)[newZip UTF8String];
                argv[2] = s;
                s = (char*)[downloadedPath UTF8String];
                argv[3] = s;
                if(0 == applypatch(4, argv)){
                    NSError* error;
                    [[NSFileManager defaultManager] removeItemAtPath:oldZip error:&error];
                    if (error) {
                        CCLogError(@"[CCCacheManager]:增量更新，删除老的增量包失败:%@。",error);
                    }
                    
                    [[NSFileManager defaultManager] moveItemAtPath:newZip toPath:oldZip error:&error];
                    if (error) {
                        CCLogError(@"[CCCacheManager]:增量更新，重命名新包失败:%@。",error);
                    }
                    
                    [[NSFileManager defaultManager] removeItemAtPath:downloadedPath error:&error];
                    if (error) {
                        CCLogError(@"[CCCacheManager]:增量更新，删除下载的增量包失败:%@。",error);
                    }
                    
                }else{
                    CCLogError(@"[CCCacheManager]:增量包合并失败。");
                    webappInfo.status = CCWebAppStatusError;
                    [self removeWebAppInfo:webappInfo];
                    if ([self.delegate respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CCCacheManager:self failedUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo]  withInfo:webappInfo error:CCWebAppUpdateErrorDiffMerge];
                        });
                    }
                    return;
                };
            }
        }else{
            CCLogDebug(@"[CCCacheManager]:全量更新，开始处理全量包。");
            if ([[NSFileManager defaultManager]fileExistsAtPath:ultimatePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:ultimatePath error:nil];
            }
            
            [[NSFileManager defaultManager] moveItemAtPath:downloadedPath toPath:ultimatePath error:nil];
        }
        
        [self unzipInfosWithZipFile:ultimatePath toWebAppInfo:webappInfo];
        //清除内存缓存
        [self clearMemCache];
        CCLogDebug(@"[CCCacheManager]:资源更新完成，清理内存缓存。");
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(CCCacheManager:didUpdateWebAppOfURL:withInfo:)]) {
                [self.delegate CCCacheManager:self didUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo] withInfo:webappInfo];
            }
        });
    }];
}

- (void)unzipInfosWithZipFile:(NSString*)zipFile toWebAppInfo:(CCWebAppInfo*)webappInfo
{
    webappInfo.diskSize += (unsigned int)[[[NSFileManager defaultManager]attributesOfItemAtPath:zipFile error:nil] fileSize];
    //解压到webapp/res.tmp目录下
    ZipArchive * zip = [[ZipArchive alloc]init];
    
    BOOL unzipResult = [zip UnzipOpenFile:zipFile] && [zip UnzipFileTo:[NSString stringWithFormat:@"%@/res.tmp",webappInfo.localFullPath] overWrite:YES];
    
    if (!unzipResult) {
        CCLogError(@"[CCCacheManager]:解压失败:%@。",zipFile);
        webappInfo.status = CCWebAppStatusError;
        [self removeWebAppInfo:webappInfo];
        if ([self.delegate respondsToSelector:@selector(CCCacheManager:failedUpdateWebAppOfURL:withInfo:error:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CCCacheManager:self failedUpdateWebAppOfURL:[self urlOfWebAppInfo:webappInfo]  withInfo:webappInfo error:CCWebAppUpdateErrorUnzip];
            });
        }
        return;
    }
    
    NSString* oldResPath = [NSString stringWithFormat:@"%@/res",webappInfo.localFullPath];
    [[NSFileManager defaultManager] removeItemAtPath:oldResPath error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/res.tmp",webappInfo.localFullPath] toPath:oldResPath error:nil];
    
    //创建CCResourceIndexInfo
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:oldResPath]
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey,NSURLNameKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:^BOOL(NSURL *url, NSError *error)
                                         {
                                             NSLog(@"CCCacheManager Error: %@ (%@)", error, url);
                                             return YES;
                                         }];
    
    NSMutableArray<CCResourceIndexInfo*>* indexInfos = [NSMutableArray new];
    for (NSURL *fileURL in enumerator) {
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        
        NSString *fileName;
        [fileURL getResourceValue:&fileName forKey:NSURLNameKey error:nil];
        
        if ([isDirectory boolValue]) {
            continue;
        }else{
            if ([[fileName pathExtension] isEqualToString:@"zip"]) {
                continue;
            }
            NSString* fullPath = [[fileURL URLByResolvingSymlinksInPath]path];
            webappInfo.diskSize += [[[NSFileManager defaultManager]attributesOfItemAtPath:fullPath error:nil] fileSize];
            CCResourceIndexInfo* indexInfo = [CCResourceIndexInfo new];
            indexInfo.url = [fullPath stringWithPathRelativeTo:oldResPath];
            indexInfo.md5 = [[NSData dataWithContentsOfFile:fullPath]MD5];
            indexInfo.webappName = webappInfo.name;
            indexInfo.localRelativePath = [fullPath stringWithPathRelativeTo:[NSString documentPath]];
            [indexInfos addObject:indexInfo];
        }
    }
    [self addResourceIndexInfos:indexInfos];
    
    webappInfo.taskID = @"";
    NSArray* comps = [webappInfo.composeVersion componentsSeparatedByString:@"&"];
    if (comps.count == 2) {
        webappInfo.version = comps[1];
    }
    webappInfo.status = CCWebAppStatusAvailable;
    CCLogInfo(@"[CCCacheManager]:资源解压成功，资源可用。");
    [self DB_updateWebAppInfo:webappInfo];
}

-(void)HTFileDownloadTask:(nonnull HTFileDownloadTask *)downloadTask didUpdatedWithProgress:(CGFloat)progress receivedSize:(NSInteger)receivedSize totalSizeExpected:(NSInteger) totalSizeExpected totalSizeReceived:(NSInteger) totalSizeReceived
{
    CCLogInfo(@"[CCCacheManager]:资源下载进度:%@。",@(progress));
    CCWebAppInfo* webappInfo = [self webAppInfoForDownloadTask:downloadTask];
    webappInfo.updatePercent = progress;
    //更新进度
    if ([self.delegate respondsToSelector:@selector(CCCacheManager:updatingWebAppOfURL:withInfo:)]) {
        [self.delegate CCCacheManager:self updatingWebAppOfURL:[self urlOfWebAppInfo:webappInfo] withInfo:webappInfo];
    }
}

-(void)didCancelledWithDownloadTask:(nonnull HTFileDownloadTask *)downloadTask
{
    CCLogWarn(@"[CCCacheManager]:资源下载取消。");
    CCWebAppInfo* webappInfo = [self webAppInfoForDownloadTask:downloadTask];
    webappInfo.updatePercent = 0;
    webappInfo.status = CCWebAppStatusError;
}

#pragma mark -- hanld webappInfo

- (BOOL)replaceOrAddWebAppInfo:(CCWebAppInfo*)webappInfo
{
    CCWebAppInfo* waInfo = [self.webappInfos objectForKey:webappInfo.name];
    if (waInfo) {
        [self.webappInfos removeObjectForKey:webappInfo.name];
        for (NSString* domain in webappInfo.domains) {
            [self.domainWebappInfos removeObjectForKey:domain];
        }
        [self DB_deleteWebAppInfo:webappInfo];
    }
    
    [self.webappInfos setObject:webappInfo forKey:webappInfo.name];
    for (NSString* domain in webappInfo.domains) {
        [self.domainWebappInfos setObject:webappInfo forKey:domain];
    }
    
    return [self DB_updateWebAppInfo:webappInfo];
}

- (BOOL)removeWebAppInfo:(CCWebAppInfo*)webappInfo
{
    if (!webappInfo) {
        return YES;
    }
    
    [self.webappInfos removeObjectForKey:webappInfo.name];
    for (NSString* domain in webappInfo.domains) {
        [self.domainWebappInfos removeObjectForKey:domain];
    }
    [[NSFileManager defaultManager]removeItemAtPath:webappInfo.localFullPath error:nil];
    return [self DB_deleteWebAppInfo:webappInfo];
}

- (BOOL)addResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)indexInfos
{
    for (CCResourceIndexInfo* info in indexInfos) {
        [self.resourceIndexInfos setObject:info forKey:[NSString stringWithFormat:@"%@/%@",info.webappName,info.url]];
    }
    return [self DB_insertResourceIndexInfos:indexInfos];
}

@end
