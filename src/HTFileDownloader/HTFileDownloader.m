

//
//  HTFileDownloader.m
//  HTFileDownloader
//
//  Created by 小丸子 on 23/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTFileDownloader.h"
#import "HTDBManager.h"
#import "HTFDLogger.h"
#import "HTFileDownloader+MD5.h"
#import "HTFDThreadSafeMutableDictionary.h"

static const NSInteger MAX_CONCURRENT_DOWNLOAD_COUNT = 3;
static dispatch_queue_t htFileDownloaderBackgroundQueue;

@interface HTFileDownloader()<NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (nonatomic, strong, nullable) NSURLSession *urlSession;
@property (nonatomic, strong, nullable) NSString * rootDownloadPath;
@property (nonatomic, strong, nullable) NSString * tmpDownloadPath;
@property (nonatomic, strong, nullable) NSDictionary * httpAdditionalHeaders;
@property (nonatomic, strong, nullable) HTFDThreadSafeMutableDictionary<NSString *, HTFileTransferItem *> * allDownloadItems;
@property (nonatomic, strong, nonnull) HTFDThreadSafeMutableDictionary<NSNumber *, HTFileDownloadTask *> * activeDownloadsDictionary; // sessionTask.taskIdentifier作为key
@property (nonatomic, strong, nonnull) NSMutableArray<HTFileDownloadTask *> * waitingDownloadsArray;
@property (nonatomic, strong, nonnull) HTFDThreadSafeMutableDictionary<NSString *, HTFileDownloadTask *> * synchronizeDownloadsDictionary;
@property (nonatomic, weak, nullable) id<HTFileDownloaderDelegate> fileDownloaderDelegate;
@property (nonatomic, assign) BOOL isBackgroundMode;    //标记是否是后台session的模式
@property (nonatomic, strong) NSDate * lastDate;        //用来记录上次获取progress的时间，控制progress对象的更新和写数据库

@property (nonatomic, strong) HTDBManager * databaseManager;

@property (strong) void (^finishCallbackBlock)(NSArray<HTFileTransferItem*> *);

@end

@implementation HTFileDownloader

+(void)load{
    htFileDownloaderBackgroundQueue = dispatch_queue_create([[NSString stringWithFormat:@"HTFileDownloader.%@", self] UTF8String], NULL);
}

-(nullable instancetype)initDownloaderWithDelegate:(id<HTFileDownloaderDelegate>)delegate
                                  withDownloadPath:(NSString *)rootDownloadPath
                             withAdditionalHeaders:(NSDictionary *)additionalHeaders
                                  isBackgroundMode:(BOOL)isBackground{
    
    self = [super init];
    if (self) {
        self.maxConcurrentDownloadsCount = MAX_CONCURRENT_DOWNLOAD_COUNT;
        
        if (rootDownloadPath) {
            self.rootDownloadPath = rootDownloadPath;
        }
        else{
            self.rootDownloadPath = [HTFileDownloader localDefaultDownloadPath];
        }
        self.tmpDownloadPath = NSTemporaryDirectory();
        self.httpAdditionalHeaders = additionalHeaders;
        self.fileDownloaderDelegate = delegate;
        self.allDownloadItems = [[HTFDThreadSafeMutableDictionary alloc]init];
        self.activeDownloadsDictionary = [[HTFDThreadSafeMutableDictionary alloc]init];
        self.synchronizeDownloadsDictionary = [[HTFDThreadSafeMutableDictionary alloc]init];
        self.waitingDownloadsArray = [NSMutableArray array];
        self.databaseManager = [[HTDBManager alloc]initDatabaseWithPath:self.rootDownloadPath];
        self.lastDate = [NSDate date];
        
        if (isBackground) {
            
            NSString * backgroundDownloadSessionIdentifier = [NSString stringWithFormat:@"%@.HTFileDownloadTest23", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
            NSURLSessionConfiguration * backgroundSessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundDownloadSessionIdentifier];
            backgroundSessionConfiguration.HTTPAdditionalHeaders = additionalHeaders;
            
            if ([self.fileDownloaderDelegate respondsToSelector:@selector(HTFileDownloader: customizeBackgroundSessionConfiguration:)]){
                [self.fileDownloaderDelegate HTFileDownloader:self customizeBackgroundSessionConfiguration: backgroundSessionConfiguration];
            }
            
            self.urlSession = [NSURLSession sessionWithConfiguration:backgroundSessionConfiguration
                                                            delegate:self
                                                       delegateQueue:[NSOperationQueue mainQueue]];
        

        }
        else{
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            configuration.HTTPAdditionalHeaders = additionalHeaders;
            self.urlSession = [NSURLSession sessionWithConfiguration:configuration
                                                            delegate:self
                                                       delegateQueue:[NSOperationQueue mainQueue]];
            
        }
        // 实际上对于standard session, 前一次未完成的任务都会cancel了，所以getCompletionTask对于此类session并没用
        [self setupContextForDownloader];
    }
    return self;
    
}

-(nullable instancetype)initStandardDownloaderWithDelegate:(id<HTFileDownloaderDelegate>)delegate
                                          withDownloadPath:(NSString *)rootDownloadPath
                                     withAdditioanlHeaders:(nullable NSDictionary *)httpAdditionalHeaders{
    
    return [self initDownloaderWithDelegate:delegate withDownloadPath:rootDownloadPath withAdditionalHeaders:httpAdditionalHeaders isBackgroundMode:NO];
}

-(nullable instancetype)initBackgroundDownloaderWithDelegate:(id<HTFileDownloaderDelegate>)delegate
                                            withDownloadPath:(NSString *)rootDownloadPath
                                       withAdditionalHeaders:(nullable NSDictionary *)httpAdditionalHeaders{
    return [self initDownloaderWithDelegate:delegate withDownloadPath:rootDownloadPath withAdditionalHeaders:httpAdditionalHeaders isBackgroundMode:YES];
}

-(void)dealloc
{
    [self.urlSession invalidateAndCancel];
}

-(void)setupContextForDownloader{
    
    [self.databaseManager createDatabase];
    //将DB里的items写到内存中
    NSArray<HTFileTransferItem*> * allDownloadItemsFromDB = [_databaseManager allDownloadItems];
    
    for (HTFileTransferItem * item in  allDownloadItemsFromDB) {
        if (item.status == HTFileTransferStateTransfering || item.status == HTFileTransferStateWaiting) {
            item.status = HTFileTransferStatePaused;
        }
        [_allDownloadItems setObject:item forKey:item.downloadId];
    }
    
     dispatch_async(htFileDownloaderBackgroundQueue, ^{
         if ([self suspendedOrFailedItems].count == 0) {
             [self cleanInvalidDownloadTempFile];
         }
         
         //按需清理DB里过期的downloadTask信息, 默认过期时间为1周
         [self.databaseManager deleteExpiredDownloadItems];
     });

}

/*-(void)setupContextForDownloader{
    
    //获取上次未完成的task，实际上对于standardSession来说，不存在这一操作
    if(self.isBackgroundMode)
    {
        [self.urlSession getTasksWithCompletionHandler:^(NSArray * dataTasksArray, NSArray * uploadTasksArray, NSArray * downloadTasksArray){
            
            //默认background模式下，接受系统处理未完成的task的能力
            [self handlerLastDownloadTasks:dataTasksArray];
            NSArray<HTFileTransferItem *> * downloadItemsArray = [self suspendedOrFailedItems];
            
            //清理无效的temp文件
            [self cleanInvalidDownloadTempFile];
            
            if (_finishCallbackBlock) {
                self.finishCallbackBlock(downloadItemsArray);
            }
            
        }];
    }
    
}*/

-(void)updateDownloadItems:(HTFileTransferItem *)downloadItem
                    isUpdate:(BOOL)isUpdate{
    
    HTFileTransferItem * item = [_allDownloadItems objectForKey:downloadItem.downloadId];
    if (item) {
        item = [downloadItem copy];
    }
    else{
        [_allDownloadItems setObject:downloadItem forKey:downloadItem.downloadId];
    }
    
    dispatch_async(htFileDownloaderBackgroundQueue, ^{
        if (isUpdate) {
            [_databaseManager updateDownloadItem:downloadItem];
        }
        else{
            [_databaseManager updateOrInsertDownloadItem:downloadItem];
        }
    });
}

-(void)deleteDownloadItem:(HTFileTransferItem *)downloadItem{
    
    if (!downloadItem) {
        return;
    }
    [_allDownloadItems removeObjectForKey:downloadItem.downloadId];
    
    dispatch_async(htFileDownloaderBackgroundQueue, ^{
        [_databaseManager deleteDownloadItem:downloadItem];
    });
}

/*
 * 如果downloadTask已经在activity中（在外面不会被start），
 */
-(void)handlerLastDownloadTasks:(NSArray<NSURLSessionDataTask*> *)downloadTasksArray{
    
    if (downloadTasksArray.count > 0) {
        
        for (NSURLSessionDataTask * sessionTask in downloadTasksArray) {
            HTFileDownloadTask * downloadTask = [[HTFileDownloadTask alloc]init];
            downloadTask.sessionDataTask = sessionTask;
            
            if (sessionTask.state == NSURLSessionTaskStateCompleted || sessionTask.state == NSURLSessionTaskStateRunning) {
                [self.activeDownloadsDictionary setObject:downloadTask forKey:@(sessionTask.taskIdentifier)];
            }
        }
    }
}

// create downloadTask with sessionTask = nil, will set it later in startWithDownloadTask,
// 查看DB，如果DB中对应有该任务被中止，而且tmp文件存在，则设置其可以进行resume的相关属性
-(nullable HTFileDownloadTask *)downloadTaskWithUrl:(NSURL *)url withDelegate:(id<HTFileDownloadTaskDelegate>)delegate{
    
    HTFileDownloadTask * downloadTask = [[HTFileDownloadTask alloc]init];
    downloadTask.fileDownloader = self;
    downloadTask.downloadTaskDelegate = delegate;
    
    NSString * downloadId = [url.absoluteString MD5];
    // check if exist in DB.
    HTFileTransferItem * item = [_allDownloadItems objectForKey:downloadId];
    if (item != nil) {
        NSString * tempFullDownloadPath = [_tmpDownloadPath stringByAppendingString:item.tempFileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:tempFullDownloadPath]) {
            downloadTask.downloadTaskData = item;
            downloadTask.tmpFullDownloadPath = tempFullDownloadPath;
            
            return downloadTask;
        }
    }
    
    // 是一个新的task
    item = [[HTFileTransferItem alloc]initWithUrl:url];
    NSString *tempFileName = [NSString stringWithFormat:@"%@_%@.tmp", @"HTFileDownload",[[NSUUID UUID] UUIDString]];
    NSString * tempFullDownloadPath = [self.tmpDownloadPath stringByAppendingString:tempFileName];
    item.tempFileName = tempFileName;
    item.startDownloadTime = [[NSDate date]timeIntervalSince1970];
    item.downloadId = downloadId;
    
    downloadTask.downloadTaskData = item;
    downloadTask.tmpFullDownloadPath = tempFullDownloadPath;
    
    HTFDLogDebug(@"[HTFileDownloader]: %@, create task succussfully", url);
    return downloadTask;
}

-(nullable HTFileDownloadTask *)downloadTaskWithDownloadItem:(HTFileTransferItem *)downloadItem withDelegate:(id<HTFileDownloadTaskDelegate>)delegate{
    
    HTFileDownloadTask * downloadTask = [[HTFileDownloadTask alloc]init];
    downloadTask.fileDownloader = self;
    downloadTask.tmpFullDownloadPath = [NSTemporaryDirectory() stringByAppendingString:downloadItem.tempFileName];
    downloadTask.downloadTaskData = downloadItem;
    downloadTask.downloadTaskDelegate = delegate;
    
    HTFDLogDebug(@"[HTFileDownloader]: %@, create task succussfully", downloadTask.downloadTaskData.url);
    return downloadTask;
}

-(void)startWithDownloadTask:(HTFileDownloadTask *)downloadTask{
    
    BOOL isStarted = NO;
    //如果downloadID相同的task已在处理中，或者已经下载完毕，则同步task的数据并将其加入sync队列中
    HTFileTransferState stateOfTaskWithSameUrl = [self downloadTaskWithSameUrlState:downloadTask];
    
    if (stateOfTaskWithSameUrl == HTFileTransferStateWaiting || stateOfTaskWithSameUrl == HTFileTransferStateTransfering){
        
        isStarted = YES;
        [self.synchronizeDownloadsDictionary setObject:downloadTask forKey:downloadTask.downloadTaskData.downloadId];
        HTFDLogInfo(@"[HTFileDownloader]: task-%ld, %@, sync task",  downloadTask.sessionDataTask.taskIdentifier, downloadTask.downloadTaskData.url);
    }
    else if(stateOfTaskWithSameUrl == HTFileTransferStateDone){
        //2.读取数据库，如果此task已经成功完成，则同步task的数据并直接返回成功
        
        if([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didFinishSuccessWithDownloadTask:)]){
            
            [downloadTask.downloadTaskDelegate didFinishSuccessWithDownloadTask:downloadTask];
        }
        HTFDLogInfo(@"[HTFileDownloader]: task-%ld, %@, has already downloaded", downloadTask.sessionDataTask.taskIdentifier, downloadTask.downloadTaskData.url);
    }
    else if ((NSInteger)self.activeDownloadsDictionary.count < self.maxConcurrentDownloadsCount) {
        
        NSURLSessionDataTask * dataTask = nil;
        
        BOOL canResume = YES;

        if (downloadTask.downloadTaskData.totalReceivedContentLength != 0) {
            // resume的task
            NSMutableURLRequest * request = [[NSMutableURLRequest alloc]initWithURL:downloadTask.downloadTaskData.url];
            NSString * lastTempPath = [NSTemporaryDirectory() stringByAppendingString:downloadTask.downloadTaskData.tempFileName];
            long long downloadedBytes = [HTFileDownloader fileSizeForPath:lastTempPath];
            
            BOOL isTempFileExisted = [[NSFileManager defaultManager]fileExistsAtPath:lastTempPath];
            if (isTempFileExisted) {
                
                NSInteger totalReceivedContentLengthInDb = downloadTask.downloadTaskData.totalReceivedContentLength;
                NSInteger totalContentLength = downloadTask.downloadTaskData.totalContentLength;
                if (downloadedBytes == totalReceivedContentLengthInDb && totalReceivedContentLengthInDb == totalContentLength) {
                    // 认为此task已经完成，由于上次状态未更新而任务需要resume. 则直接更新状态，通知delegator,并更新db. 注意：此类task 不要加入active队列中
                    downloadTask.downloadTaskData.status = HTFileTransferStateDone;
                    if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didFinishSuccessWithDownloadTask:)]) {
                        [downloadTask.downloadTaskDelegate didFinishSuccessWithDownloadTask:downloadTask];
                    }
                    
                }
                else if(downloadedBytes >= totalReceivedContentLengthInDb && downloadedBytes < totalContentLength){
                    // 可以resume
                    NSString * requestRange = [NSString stringWithFormat:@"bytes=%ld-",(long)totalReceivedContentLengthInDb];
                    [request setValue:requestRange forHTTPHeaderField:@"Range"];
                    
                    if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:customizeRequest:)]) {
                        request = [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask customizeRequest:request];
                    }
                    dataTask = [self.urlSession dataTaskWithRequest:request];
                    downloadTask.sessionDataTask = dataTask;
                }
                else{
                    canResume = NO;
                }
            }
            else{
                canResume = NO;
            }
        }
        else if(downloadTask.downloadTaskData.totalReceivedContentLength == 0 || canResume == NO){
            // 删除DB中可能存在的记录 TODO: delete接口要修改
            [self deleteDownloadItem:downloadTask.downloadTaskData];
            // TODO: 是否要清理tmp文件
            // 新的task
            NSMutableURLRequest * request = [[NSMutableURLRequest alloc]initWithURL:downloadTask.downloadTaskData.url];
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:customizeRequest:)]) {
                request = [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask customizeRequest:request];
            }
            
            dataTask = [self.urlSession dataTaskWithRequest:request];
            downloadTask.sessionDataTask = dataTask;
        }
        // start task & update DB
        if (downloadTask.downloadTaskData.status != HTFileTransferStateDone) {
            [self.activeDownloadsDictionary setObject:downloadTask forKey:@(dataTask.taskIdentifier)];
            [downloadTask.sessionDataTask resume];
            downloadTask.downloadTaskData.status = HTFileTransferStateTransfering;
        }
        
        // if downloadTask is in waitingDic, move
        if (self.waitingDownloadsArray.count != 0 && downloadTask == self.waitingDownloadsArray[0]) {
            [self.waitingDownloadsArray removeObject:downloadTask];
        }
        
        [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:NO];
        isStarted = YES;
    }
    else{
        //达到 concurrent数上限，加入等待队列
        [self.waitingDownloadsArray addObject:downloadTask];
        downloadTask.downloadTaskData.status = HTFileTransferStateWaiting;
        
        [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:NO];
        //[self.databaseManager updateBDWithDownloadItem:downloadTask.downloadTaskData];
        HTFDLogDebug(@"[HTFileDownloader]: task-%ld, %@, waiting in queue...",  downloadTask.sessionDataTask.taskIdentifier, downloadTask.downloadTaskData.url);
    }
    
    if (isStarted) {
        
        if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didStartedWithDownloadTask:)]) {
            [downloadTask.downloadTaskDelegate didStartedWithDownloadTask:downloadTask];
        }
        HTFDLogDebug(@"[HTFileDownloader]: task-%ld, %@, start downloading...",  downloadTask.sessionDataTask.taskIdentifier, downloadTask.downloadTaskData.url);
    }
}

/*
 * 暂停task. 任务可以断点续传
 */
-(void)suspendWithDownloadTask:(HTFileDownloadTask *)downloadTask
{
    NSUInteger taskIdentifier = downloadTask.sessionDataTask.taskIdentifier;
    
    if (downloadTask.downloadTaskData.status == HTFileTransferStateTransfering) {
        
        downloadTask.downloadTaskData.status = HTFileTransferStatePaused;
        
        HTFileDownloadTask * downloadTaskFromActiveDic = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
        if (downloadTaskFromActiveDic && downloadTaskFromActiveDic == downloadTask) {
            NSURLSessionDataTask * urlSessionDataTask = downloadTask.sessionDataTask;
            if (urlSessionDataTask) {
                [urlSessionDataTask cancel];
            }
            else{
                // urlSessionDownloadTask不存在
                HTFDLogError(@"[HTFileDownloader]: task-%@, suspend failed cause no such task exist",  downloadTask.downloadTaskData.url);
                NSError *cancelledError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
                [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:cancelledError];
                downloadTask.downloadTaskData.status = HTFileTransferStateFailed;
            }
            
            [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
        }
        
    }
    else if(downloadTask.downloadTaskData.status == HTFileTransferStateWaiting){
        
        NSInteger foundIndex = [self getDownloadTaskFromWaitingDic:taskIdentifier];
        if (foundIndex != -1) {
            HTFileDownloadTask * downloadTask = self.waitingDownloadsArray[foundIndex];
            downloadTask.downloadTaskData.status = HTFileTransferStatePaused;
            
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didPausedWithDownloadTask:)]) {
                [downloadTask.downloadTaskDelegate didPausedWithDownloadTask:downloadTask];
            }
            [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
            [self.waitingDownloadsArray removeObject:downloadTask];
        }
        else{
            
            HTFDLogError(@"[HTFileDownloader]: task:%@, suspend failed cause no such task exist",  downloadTask.downloadTaskData.url);
        }
    }
}

-(void)suspendedAllDownloadItems
{
    [_activeDownloadsDictionary enumerateKeysAndObjectsUsingBlock:^(NSNumber *aDownloadNumber, HTFileDownloadTask *downloadTask, BOOL *stop) {
        [self suspendWithDownloadTask:downloadTask];
    }];
    
    [_waitingDownloadsArray enumerateObjectsUsingBlock:^(HTFileDownloadTask * _Nonnull downloadTask, NSUInteger idx, BOOL * _Nonnull stop) {
        downloadTask.downloadTaskData.status = HTFileTransferStatePaused;
        if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didPausedWithDownloadTask:)]) {
            [downloadTask.downloadTaskDelegate didPausedWithDownloadTask:downloadTask];
        }
        [self.waitingDownloadsArray removeObject:downloadTask];
        [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
    }];
}

/*
 * cancel任务，默认不支持断点续传，所以不会对此类任务进行持久化。将该task直接从active队列或者waiting队列中删除
 * 1.如果task处于active队列中，cancel并从队列中移除。这时回调URLSession:task:didCompleteWithError会被trigger,在该回调中将task从active队列remove，并通知downloadTaskDelegate回调didFailedWithError
 * 2.如果task处于waiting队列中，此task并未开始，没有产生网络请求。因此构造cancelledError, 通知downloadTaskDelegate回调didFailedWithError,
 */
-(void)deleteWithDownloadTask:(HTFileDownloadTask *)downloadTask
{
    if (downloadTask.downloadTaskData.status == HTFileTransferStatePaused) {
        
        if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didCancelledWithDownloadTask:)]) {
            [downloadTask.downloadTaskDelegate didCancelledWithDownloadTask:downloadTask];
        }
        [self.databaseManager deleteDownloadItem:downloadTask.downloadTaskData];
        return;
    }
    
    NSUInteger taskIdentifier = downloadTask.sessionDataTask.taskIdentifier;
    // if in activeDownloadTaskDic, remove from it
    HTFileDownloadTask * downloadTaskFromActiveDic = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
    
    if (downloadTaskFromActiveDic && downloadTaskFromActiveDic == downloadTask) {
        NSURLSessionDataTask * urlSessionDataTask = downloadTask.sessionDataTask;
        if (urlSessionDataTask) {
            [urlSessionDataTask cancel];
        }
        else{
            // urlSessionDownloadTask不存在
            HTFDLogError(@"[HTFileDownloader]: task-%@, delete failed cause no such task exist",  downloadTask.downloadTaskData.url);
            
            NSError *cancelledError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:cancelledError];
        }
        
        downloadTask.downloadTaskData.status = HTFileTransferStateCancelled;
    }
    else
    {
        // 如果在waiting的状态，则需构造cancel error, 通知downloadTaskDelegate选择性处理
        NSInteger foundIndex = [self getDownloadTaskFromWaitingDic:taskIdentifier];
        if (foundIndex != -1) {
            HTFileDownloadTask * downloadTask = self.waitingDownloadsArray[foundIndex];
            
            NSError *cancelledError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:cancelledError];
            
            [self.waitingDownloadsArray removeObjectAtIndex:foundIndex];
        }
        else{
            HTFDLogError(@"[HTFileDownloader]: task-%@, delete failed cause no such task exist",  downloadTask.downloadTaskData.url);
        }
    }
}

-(nonnull NSArray<HTFileTransferItem *> *)downloadItems{
    
    return  [_allDownloadItems allValues];
}

-(nullable NSArray<HTFileTransferItem *> *)suspendedOrFailedItems{

    NSArray<HTFileTransferItem *> * allDownloadItems = [self downloadItems];
    NSMutableArray<HTFileTransferItem *> * suspendedOrFailedItems = [NSMutableArray array];
    for (HTFileTransferItem * item in allDownloadItems) {
        if (item.status != HTFileTransferStateDone) {
            [suspendedOrFailedItems addObject:item];
        }
    }
    return [suspendedOrFailedItems copy];
}


#pragma mark - internal methods

/*
 * 可能存在temp file没能被urlsession删除，并且可能会堆积膨胀，所以需要提供clean的操作。
 * clean的前提是db里面没有undone的task, clean工作放在初始化过程中
 */
-(void)cleanInvalidDownloadTempFile{
    
    // get temp 路径
    NSArray * paths = [[NSFileManager defaultManager]subpathsAtPath:NSTemporaryDirectory()];
    for (NSString * filePath in paths) {
        
        if ([filePath rangeOfString:@"HTFileDownload_"].length > 0) {
            
            NSString * invalidDownloadTempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            NSError * removeError = nil;
            [[NSFileManager defaultManager]removeItemAtPath:invalidDownloadTempFile error:&removeError];
            if (removeError) {
                //NSLog(@"remove %@ failed", invalidDownloadTempFile);
            }
            
        }
    }
    HTFDLogInfo(@"[HTFileDownloader]: clean files:%ld , paths:%@",  paths.count, paths);
}

/*
 * 如果waitingDic为空，直接返回
 */
-(void)startNextWaitingDownloadTask{
    
    if (self.maxConcurrentDownloadsCount == -1 || [self.activeDownloadsDictionary count] < self.maxConcurrentDownloadsCount) {
        
        if ([self.waitingDownloadsArray count] == 0) {
            return;
        }
        else{
            
            HTFileDownloadTask * downloadTask = [self.waitingDownloadsArray firstObject];
            [self startWithDownloadTask:downloadTask];
            
        }
    }
}

/*
 * 将文件从temp目录写入到持久目录，如果成功，触发download:didFinishWithSuccess:回调；如果失败，触发download:didFailedWithError:回调
 */
-(void)handleSuccessDownloadTask:(nonnull HTFileDownloadTask *)downloadTask{
    
    NSString * fileName = downloadTask.downloadTaskData.fileName;
    NSString * localFileDestinationPath = [_rootDownloadPath stringByAppendingPathComponent:fileName];
    HTFileDownloadTask * syncDownloadTask = [self.synchronizeDownloadsDictionary objectForKey:downloadTask.downloadTaskData.downloadId];
    
    if (localFileDestinationPath) {
        
        //注：对于同一url
        //如果同名文件已经存在，则重命名存储：file(1).jpg, file(2).jpg
        if ([[NSFileManager defaultManager] fileExistsAtPath:localFileDestinationPath] == YES) {
            NSString * fileExtension = [downloadTask.downloadTaskData.fileName pathExtension];
            NSString * fileNameWithoutExt = [downloadTask.downloadTaskData.fileName stringByDeletingPathExtension];
            NSInteger count = 1;
            while([[NSFileManager defaultManager] fileExistsAtPath:localFileDestinationPath] == YES){
                
                if ([fileExtension length]) {
                    fileName = [NSString stringWithFormat:@"%@(%ld).%@", fileNameWithoutExt, count, fileExtension];
                }
                else{
                    fileName = [NSString stringWithFormat:@"%@(%ld)", fileNameWithoutExt, count];
                }
                localFileDestinationPath = [_rootDownloadPath stringByAppendingPathComponent:fileName];
                count++;
            }
        }
        
        // 将下载文件从location.path移动到本地目录
        NSError * moveError;
        NSURL * tmpLocalFileURL = [NSURL fileURLWithPath:downloadTask.tmpFullDownloadPath];
        NSURL * localFileURL = [NSURL fileURLWithPath:localFileDestinationPath];
        //NSURL * localFileURL = [NSURL URLWithString:localFileDestinationPath];
        BOOL isSuccess = [[NSFileManager defaultManager] moveItemAtURL:tmpLocalFileURL
                                                                 toURL:localFileURL
                                                                 error:&moveError];
        if (isSuccess == YES) {
            
            downloadTask.fullDownloadPath = localFileDestinationPath;
            downloadTask.downloadTaskData.fileName = fileName;
            
            downloadTask.downloadTaskData.status = HTFileTransferStateDone;
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didFinishSuccessWithDownloadTask:)]) {
                [downloadTask.downloadTaskDelegate didFinishSuccessWithDownloadTask:downloadTask];
            }
            
            // sync
            if (syncDownloadTask != nil) {
                syncDownloadTask.fullDownloadPath = localFileDestinationPath;
                syncDownloadTask.downloadTaskData.fileName = fileName;
                syncDownloadTask.downloadTaskData.status = HTFileTransferStateDone;
                if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(didFinishSuccessWithDownloadTask:)]) {
                    [syncDownloadTask.downloadTaskDelegate didFinishSuccessWithDownloadTask:syncDownloadTask];
                }
            }
            HTFDLogDebug(@"[HTFileDownloader]: Succ: move file from %@ to %@",  downloadTask.tmpFullDownloadPath, localFileDestinationPath);
        }
        else{
            downloadTask.downloadTaskData.status = HTFileTransferStateFailed;
            if (moveError == nil)
            {
                moveError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCannotMoveFile userInfo:nil];
                
                if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didFailedWithError:)]) {
                    [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:moveError];
                }
                
                if (syncDownloadTask) {
                    syncDownloadTask.fullDownloadPath = localFileDestinationPath;
                    syncDownloadTask.downloadTaskData.fileName = fileName;
                    syncDownloadTask.downloadTaskData.status = HTFileTransferStateFailed;
                    if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didFailedWithError:)]) {
                        [syncDownloadTask.downloadTaskDelegate HTFileDownloadTask:syncDownloadTask didFailedWithError:moveError];
                    }
                }
            }
            NSString *errorString = [NSString stringWithFormat:@"ERR: Unable to move file from %@ to %@ (%@)", downloadTask.tmpFullDownloadPath, localFileDestinationPath, moveError.localizedDescription];
            downloadTask.downloadTaskData.errorMessageInfo = errorString;
            
            HTFDLogError(@"[HTFileDownloader]: %@",  errorString);
        }
    }

    [self.activeDownloadsDictionary removeObjectForKey:@(downloadTask.sessionDataTask.taskIdentifier)];
    
    if (syncDownloadTask) {
        [self.synchronizeDownloadsDictionary removeObjectForKey:downloadTask.downloadTaskData.downloadId];
    }
    
    [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
    [self startNextWaitingDownloadTask];
    
}

/*
 * 1. pause, DB中更新downloadItem;
 * 2. cancel, DB中删除downloadItem;
 * 3. failed, DB中更新downloadItem;
 */
-(void)handleDownloadTaskWithError:(nonnull NSError*)error
                  withDownloadTask:(nonnull HTFileDownloadTask *)downloadTask{
    
    HTFileDownloadTask * syncDownloadTask = [self.synchronizeDownloadsDictionary objectForKey:downloadTask.downloadTaskData.downloadId];
    syncDownloadTask.downloadTaskData.status = downloadTask.downloadTaskData.status;
    
    // 需要先清理队列中的task,以免对didPausedWithDownloadTask等回调的可能实现产生影响
    [self.activeDownloadsDictionary removeObjectForKey:@(downloadTask.sessionDataTask.taskIdentifier)];
    if (syncDownloadTask) {
        [self.synchronizeDownloadsDictionary removeObjectForKey:downloadTask.downloadTaskData.downloadId];
    }
    
    if ([error.domain isEqualToString:NSURLErrorDomain] && (error.code == NSURLErrorCancelled)) {
        
        if (downloadTask.downloadTaskData.status == HTFileTransferStatePaused) {
            [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didPausedWithDownloadTask:)]) {
                [downloadTask.downloadTaskDelegate didPausedWithDownloadTask:downloadTask];
            }
            // sync
            if (syncDownloadTask) {
                if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(didPausedWithDownloadTask:)]) {
                    [syncDownloadTask.downloadTaskDelegate didPausedWithDownloadTask:syncDownloadTask];
                }
            }
        }
        else if(downloadTask.downloadTaskData.status == HTFileTransferStateCancelled){
            [self.databaseManager deleteDownloadItem:downloadTask.downloadTaskData];
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(didCancelledWithDownloadTask:)]) {
                [downloadTask.downloadTaskDelegate didCancelledWithDownloadTask:downloadTask];
            }
            //sync
            if (syncDownloadTask) {
                if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(didCancelledWithDownloadTask:)]) {
                    [syncDownloadTask.downloadTaskDelegate didCancelledWithDownloadTask:syncDownloadTask];
                }
            }
        }
    }
    else{
        
        downloadTask.downloadTaskData.status = HTFileTransferStateFailed;
        
        if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didFailedWithError:)]) {
            [self.databaseManager updateDownloadItem:downloadTask.downloadTaskData];
            [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:error];
        }
        
        //sync
        if (syncDownloadTask) {
            if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didFailedWithError:)]) {
                [syncDownloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didFailedWithError:error];
            }
        }
    }
    
    if ([error.userInfo objectForKey:@"NSURLErrorBackgroundTaskCancelledReasonKey"] &&
        ([[error.userInfo objectForKey:@"NSURLErrorBackgroundTaskCancelledReasonKey"] integerValue] == NSURLErrorCancelledReasonUserForceQuitApplication)) {
        
        //NSLog(@"INFO: Task is cancelled by app force quit!");
        
        
    } else {
        [self startNextWaitingDownloadTask];
    }
    
}


#pragma mark - NSURLSessionDelegate
//只要访问的是HTTPS的路径就会调用 ，给方法的作用是处理服务器返回的证书，需要在该方法中告诉系统是否需要安装服务器返回的证书
-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    //对于challenge的处理方式
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([self.fileDownloaderDelegate respondsToSelector:@selector(HTFileDownloader:didReceiveAuthenticationChallenge:withCredential:)]) {
        disposition = [self.fileDownloaderDelegate HTFileDownloader:self didReceiveAuthenticationChallenge:challenge withCredential:&credential];
    } else {
        //判断服务器返回的证书是否是服务器信任的
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            if (credential) {
                disposition = NSURLSessionAuthChallengeUseCredential;
            }
            else{
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    //安装证书
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    
}

/*
 * 在session被invalidate后，会触发些回调；
 */
-(void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    
    
}

#pragma mark - NSURLSessionTaskDelegate

/*
 * didFinishDownloadingToURL回调之后，task结束后触发回调
 * 如果error=nil，并不表明下载成功，需要check server error(httpStatus code); 
 * 如果httpStatus Code有效（default:200-299有效code),判断finalLocalFileURL,以确保文件成功从temp目录转移。
 * 如果error!=nil，则为client-side error,可以通过error获取错误信息，进行处理
 */
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    
    HTFileDownloadTask * downloadTask = self.activeDownloadsDictionary[@(task.taskIdentifier)];
    
    if (downloadTask) {
        
        NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)task.response;
        NSInteger httpStatusCode = httpResponse.statusCode;
        downloadTask.downloadTaskData.lastHttpStatusCode = httpStatusCode;
        if (error == nil) {
            // 判断http status code
            BOOL isInvalidForHttpStatusCode = NO;
            
            if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:isInvalidForHttpStatusCode:)]){
                
                isInvalidForHttpStatusCode = [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask isInvalidForHttpStatusCode:httpStatusCode];
            }
            else{
                
                isInvalidForHttpStatusCode = [HTFileDownloader isInvalidForHttpStatusCode:httpStatusCode];
            }
            
            if (isInvalidForHttpStatusCode) {
                
                [self handleSuccessDownloadTask:downloadTask];
            }
            else{
                // server error
                downloadTask.downloadTaskData.errorMessageInfo = [NSString stringWithFormat:@"Invalid http status code:%ld", httpStatusCode];
                
                NSError * finalError = [[NSError alloc]initWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil];
                [self handleDownloadTaskWithError:finalError withDownloadTask:downloadTask];
                HTFDLogError(@"[HTFileDownloader]: Err: %@",  downloadTask.downloadTaskData.errorMessageInfo);
            }
        }
        else{
            
            [self handleDownloadTaskWithError: error withDownloadTask:downloadTask];
            HTFDLogError(@"[HTFileDownloader]: Err: %@",  error.localizedDescription);
        }
    }
    else{
        HTFDLogError(@"[HTFileDownloader]: Err: Task not found)", NSStringFromClass([self class]));
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    HTFileDownloadTask * downloadTask = self.activeDownloadsDictionary[@(task.taskIdentifier)];
    
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didReceiveAuthenticationChanllenge:withCredential:)]) {
        disposition = [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask didReceiveAuthenticationChanllenge:challenge withCredential:&credential];
    } else {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            if (credential) {
                disposition = NSURLSessionAuthChallengeUseCredential;
            }
            else{
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    //安装证书
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark - NSURLSessionDataDelegate
//当接收到服务器响应时调用，该方法只会调用一次
//TODO : 处理server error
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
    HTFileDownloadTask * downloadTask = [self.activeDownloadsDictionary objectForKey:@(dataTask.taskIdentifier)];
    BOOL requestFailed = NO;
    
    if (downloadTask != nil) {
        
        NSHTTPURLResponse * res = (NSHTTPURLResponse*)response;
        downloadTask.fullDownloadPath =[self.rootDownloadPath stringByAppendingPathComponent:res.suggestedFilename];
        downloadTask.downloadTaskData.fileName = res.suggestedFilename;
        if (res.statusCode == 200) {
            downloadTask.downloadTaskData.totalContentLength = res.expectedContentLength;
        }
        else if(res.statusCode == 206){
            // 断点续传的响应code, partial content
            NSString * contentRange = [res.allHeaderFields valueForKey:@"Content-Range"];
            if ([contentRange hasPrefix:@"bytes"]) {
                NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
                if ([bytes count] == 4) {
                    downloadTask.downloadTaskData.totalContentLength = [[bytes objectAtIndex:3] longLongValue];
                }
            }
        }
        else if(res.statusCode == 416){
            NSString * contentRange = [res.allHeaderFields valueForKey:@"Content-Range"];
            // 但是并不是所有的response都包含这个，所有如果downloadedBytes = totalbytes,如果这样处理的话，会出问题
            if ([contentRange hasPrefix:@"bytes"]) {
                NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
                if ([bytes count] == 3) {
                    downloadTask.downloadTaskData.totalContentLength = [[bytes objectAtIndex:2] longLongValue];
                    if (downloadTask.downloadTaskData.totalReceivedContentLength == downloadTask.downloadTaskData.totalContentLength) {
                        //已经下完
                        return ;
                    }
                }
            }
            requestFailed = YES;
        }
        else{
            requestFailed = YES;
        }
        
        if (requestFailed) {
            NSError * error = [[NSError alloc]initWithDomain:NSURLErrorDomain code:res.statusCode userInfo:res.allHeaderFields];
            HTFDLogError(@"[HTFileDownloader]: request error: %ld, %@", res.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:res.statusCode]);
            [self handleDownloadTaskWithError:error withDownloadTask:downloadTask];
            return;
        }
    }
    
    
   
    //创建临时文件
    NSFileManager * fileManager =[NSFileManager defaultManager];
    NSString * tmpPathForDownloadItem = downloadTask.tmpFullDownloadPath;
    if (![fileManager fileExistsAtPath:tmpPathForDownloadItem]) {
        [fileManager createFileAtPath:tmpPathForDownloadItem contents:nil attributes:nil];
    }
    
    if (completionHandler) {
        completionHandler(disposition);
    }
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
    HTFileDownloadTask * downloadTask = [self.activeDownloadsDictionary objectForKey:@(dataTask.taskIdentifier)];
    
    if (downloadTask != nil) {
        //向文件中追加数据
        NSFileHandle * fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:downloadTask.tmpFullDownloadPath];
        [fileHandle seekToEndOfFile]; //将节点跳到文件的末尾
        [fileHandle seekToFileOffset:downloadTask.downloadTaskData.totalReceivedContentLength];
        [fileHandle writeData:data];//追加写入数据
        
        [fileHandle closeFile];
        
        downloadTask.downloadTaskData.totalReceivedContentLength += data.length;
        downloadTask.downloadTaskData.progress = (CGFloat)downloadTask.downloadTaskData.totalReceivedContentLength/downloadTask.downloadTaskData.totalContentLength;
        //更新progress.
        if ([downloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didUpdatedWithProgress:receivedSize:totalSizeExpected:totalSizeReceived:)]) {
            [downloadTask.downloadTaskDelegate HTFileDownloadTask:downloadTask
                                 didUpdatedWithProgress:downloadTask.downloadTaskData.progress
                                           receivedSize:data.length
                                      totalSizeExpected:downloadTask.downloadTaskData.totalContentLength
                                      totalSizeReceived:downloadTask.downloadTaskData.totalReceivedContentLength];
        }
        
        //如果syncDic中有此task, 也需调用delegate
        HTFileDownloadTask * syncDownloadTask = [self.synchronizeDownloadsDictionary objectForKey:downloadTask.downloadTaskData.downloadId];
        if (syncDownloadTask != nil) {
            syncDownloadTask.downloadTaskData.totalReceivedContentLength = downloadTask.downloadTaskData.totalReceivedContentLength;
            syncDownloadTask.downloadTaskData.totalContentLength = downloadTask.downloadTaskData.totalContentLength;
            syncDownloadTask.downloadTaskData.progress = downloadTask.downloadTaskData.progress;
            if ([syncDownloadTask.downloadTaskDelegate respondsToSelector:@selector(HTFileDownloadTask:didUpdatedWithProgress:receivedSize:totalSizeExpected:totalSizeReceived:)]) {
                [syncDownloadTask.downloadTaskDelegate HTFileDownloadTask:syncDownloadTask
                                     didUpdatedWithProgress:downloadTask.downloadTaskData.progress
                                               receivedSize:data.length
                                          totalSizeExpected:downloadTask.downloadTaskData.totalContentLength
                                          totalSizeReceived:downloadTask.downloadTaskData.totalReceivedContentLength];
            }
        }
        
        //更新DB
        
        NSDate * currentDate = [NSDate date];
        NSTimeInterval time = [currentDate timeIntervalSinceDate:_lastDate];
        if (time >= 1 || downloadTask.downloadTaskData.totalContentLength == downloadTask.downloadTaskData.totalReceivedContentLength){
            _lastDate = currentDate;
            [self updateDownloadItems:downloadTask.downloadTaskData isUpdate:YES];
            
             HTFDLogInfo(@"[HTFileDownloader]: Progress update: %f - %ld - %ld)",  downloadTask.downloadTaskData.progress, downloadTask.downloadTaskData.totalReceivedContentLength, downloadTask.downloadTaskData.totalContentLength);
        }
    }
}


#pragma mark - utility

-(NSInteger)getDownloadTaskFromWaitingDic:(NSInteger)taskIdentifier{
    
    for (int index = 0; index < [self.waitingDownloadsArray count]; index++) {
        
        if (self.waitingDownloadsArray[index].sessionDataTask.taskIdentifier == taskIdentifier) {
            return index;
        }
    }
    return -1;
}

// TODO: 对于已经下载完成的，还是重新让他下载吧，不过需要先把DB里面对应downloadId的那条记录删除
-(HTFileTransferState)downloadTaskWithSameUrlState:(HTFileDownloadTask *)task{
    
    __block HTFileTransferState state = HTFileTransferStateNone;
    [_allDownloadItems enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, HTFileTransferItem * _Nonnull downloadItem, BOOL * _Nonnull stop) {
       
        if ([downloadItem.downloadId isEqualToString:task.downloadTaskData.downloadId]) {
            task.fullDownloadPath = [_rootDownloadPath stringByAppendingPathComponent:downloadItem.fileName];
            task.tmpFullDownloadPath = [NSTemporaryDirectory() stringByAppendingString:downloadItem.tempFileName];
            state = downloadItem.status;
            
            if (state == HTFileTransferStateDone) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:task.fullDownloadPath ]){
                    task.downloadTaskData = [downloadItem copy];
                    state = HTFileTransferStateDone;
                }
                else{
                    //不存在，返回None,重新下载, 需要首先delete掉相同downloadId的记录
                    [self deleteDownloadItem:downloadItem];
                    state = HTFileTransferStateNone;
                }

            }
            *stop = YES;
        }
    }];

    return state;
}

+(nonnull NSString *)localDefaultDownloadPath{
    
    NSURL *localDefaultDownloadPath = nil;
    NSError * error = nil;
    
    NSArray *documentDirectoryURLsArray = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL * documentDirectoryURL = documentDirectoryURLsArray[0];
    
    if (documentDirectoryURL)
    {
        localDefaultDownloadPath = [documentDirectoryURL URLByAppendingPathComponent:@"HTFileDownloader/"];
       
        if ([[NSFileManager defaultManager] fileExistsAtPath:localDefaultDownloadPath.path] == NO)
        {
            BOOL isSuccess = [[NSFileManager defaultManager] createDirectoryAtURL:localDefaultDownloadPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (isSuccess == NO)
            {
                HTFDLogError(@"[HTFileDownloader]: ERR on create directory: %@ )",  error);
            }
        }
    }
    
    return localDefaultDownloadPath.path;
}

/*
 * 默认200-299之间valide
 */
+(BOOL)isInvalidForHttpStatusCode:(NSInteger)statusCode{
    
    if (statusCode >= 200 && statusCode <=299) {
        return YES;
    }
    return NO;
}

/*
 * 检测resumeData是否有效
 * @return: 返回有效的resumeData或者nil
 */
- (NSData *)isValidResumeData:(NSData *)data{
    if (!data || [data length] < 1)
        return nil;
    
    NSError *error;
    NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:data
                                                                               options:NSPropertyListImmutable
                                                                                format:NULL
                                                                                 error:&error];
    
    if (!resumeDictionary || error)
        return nil;
    
    NSString *tmpName;
    
    // iOS 8及以下版本，取出tmp绝对路径，检查tmp文件是否存在，并修改tmp绝对路径，重新赋值
    // iOS 9及以上版本，取出tmp文件名，检查tmp文件是否存在
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_8_4) {
        NSString *localFilePath = resumeDictionary[@"NSURLSessionResumeInfoLocalPath"];
        tmpName = [localFilePath lastPathComponent];
    } else {
        tmpName = resumeDictionary[@"NSURLSessionResumeInfoTempFileName"];
    }
    
    if (tmpName.length == 0) {
        return nil;
    }
    
    NSString *currentLocalFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpName];
    BOOL isFileExists =  [[NSFileManager defaultManager] fileExistsAtPath:currentLocalFilePath];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_8_4) {
        if (isFileExists) {
            NSMutableDictionary *tmpResumMutableDictionary = [NSMutableDictionary dictionaryWithDictionary:resumeDictionary];
            tmpResumMutableDictionary[@"NSURLSessionResumeInfoLocalPath"] = currentLocalFilePath;
            
            NSData *currentData = [NSPropertyListSerialization dataWithPropertyList:tmpResumMutableDictionary
                                                                             format:NSPropertyListBinaryFormat_v1_0
                                                                            options:NSPropertyListImmutable
                                                                              error:&error];
            return currentData;
        }
    }
    
    return isFileExists ? data : nil;
}

+(NSInteger)fileSizeForPath:(NSString *)path{
    long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager new]; // not thread safe
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

@end
