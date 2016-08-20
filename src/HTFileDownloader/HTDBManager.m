//
//  HTDBManager.m
//  HTFileDownloader
//
//  Created by 小丸子 on 2/6/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#import "HTDBManager.h"
#import "HTFDLogger.h"

#define CREATE_TABLE @"create table if not exists downloadItems ( \
                        downloadID text primary key,              \
                        url text,                                 \
                        md5 text,                                 \
                        fileTempName text,                        \
                        fileName text,                            \
                        status   integer,                         \
                        progress real,                            \
                        totalSize integer,                        \
                        downloadedSize ingeger,                   \
                        startDownloadTime integer)"

static sqlite3 * database = nil;
static const NSString * DBNAME = @"HTFiledownloader.db"; //数据库名
static const NSString * DOWNLOADITEMS = @"DOWNLOADITEMS"; //表名
static const NSInteger DEFAULT_DOWNLOADTASK_EXPIREDTIME = 7 * 24 * 3600;


@interface HTDBManager()


@property (nonatomic, strong) NSString * databasePath;

@property (nonatomic, strong) NSString * dbFileName;

@property (nonatomic, strong) NSMutableArray * columnNamesArray;

@property (nonatomic) int affectedRows;

@property (nonatomic) long long lastInsertedRowID;

@property (nonatomic, strong) NSString * dbFullFilePath;

@property (nonatomic, strong) NSMutableArray *resultsArray;   // 用来存储查询结果

-(NSArray *)loadDataFromDB:(NSString *)query;

-(BOOL)executeQuery:(NSString *)query;

@end

@implementation HTDBManager

-(instancetype)initDatabaseWithPath:(nullable NSString *)dbPath{
    
    self = [super init];
    if (self) {
        if (dbPath == nil) {
            NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            self.databasePath = [NSString stringWithFormat:@"%@/%@", paths[0], DBNAME];
        }
        else{
            self.databasePath = [NSString stringWithFormat:@"%@/%@", dbPath, DBNAME];
        }
        
    }
    
    return self;
}

-(void)dealloc{
    
    sqlite3_close(database);
}

-(BOOL)createDatabase{
    
    BOOL result = YES;
    
    if (sqlite3_open([self.databasePath UTF8String], &database) != SQLITE_OK) {
        
        sqlite3_close(database);
        result = NO;
        //NSAssert(0, @"open database faild!");
        HTFDLogError(@"[HTFileDownloader]: %@", @"CreateDataBase", @"create or open DB failed");
    }
    else{
        char * errorMsg;
        if (sqlite3_exec(database, [CREATE_TABLE UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
            
            result = NO;
            //NSAssert(0, @"create table failed!");
            HTFDLogError(@"[HTFileDownloader]: create table failed");
        }
    }
    HTFDLogInfo(@"[HTFileDownloader]: create or open DB successfully");
    return result;
}

-(void)updateOrInsertDownloadItem:(HTFileTransferItem *)item
{
    NSString * selectSql = [NSString stringWithFormat:@"select * from downloadItems where downloadID = \"%@\"", item.downloadId];
    
     NSArray * results = [[NSArray alloc]initWithArray:[self loadDataFromDB:selectSql]];
    
    if (results.count == 0) {
        [self insertNewDownloadItem:item];
    }
    else{
        [self updateDownloadItem:item];
    }
    
}

-(BOOL)insertNewDownloadItem:(HTFileTransferItem *)item
{
    NSString * insertSql = [NSString stringWithFormat:@"insert into downloadItems (downloadID, url, md5, fileTempName, fileName, status, progress, totalSize, downloadedSize,startDownloadTime) values (\"%@\", \"%@\",\"%@\", \"%@\", \"%@\", \"%ld\", \"%f\", \"%ld\", \"%ld\", \"%ld\")", item.downloadId, item.url, item.md5, item.tempFileName, item.fileName, (long)item.status, item.progress, (long)item.totalContentLength, (long)item.totalReceivedContentLength, (long)item.startDownloadTime];
    
   return [self executeQuery:insertSql];
    
}

-(BOOL)updateDownloadItem:(HTFileTransferItem *)item
{
    NSString * updateSql = [NSString stringWithFormat:@"update downloadItems set md5 = \"%@\", fileTempName = \"%@\", fileName = \"%@\",  status = \"%ld\",progress = \"%f\", totalSize = \"%ld\", downloadedSize = \"%ld\" where downloadID = \"%@\"", item.md5, item.tempFileName, item.fileName, (long)item.status, item.progress, (long)item.totalContentLength, (long)item.totalReceivedContentLength, item.downloadId];
    
    return [self executeQuery:updateSql];
}

-(nullable HTFileTransferItem *)downloadItemWithDownloadId:(NSString *)downloadId{
    
    NSString * selectSql = [NSString stringWithFormat:@"select * from downloadItems where downloadId = \"%@\"",downloadId];
    
    [self runQuery:[selectSql UTF8String] isQueryExecutable:NO];
    NSArray * results = [[NSArray alloc] initWithArray:self.resultsArray];
    if (results.count == 1) {
        HTFileTransferItem * item = [[HTFileTransferItem alloc]init];
        item.downloadId = [[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"downloadID"]];
        item.url = [[NSURL alloc] initWithString:[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"url"]]];
        item.md5 = [[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"md5"]];
        item.status = [[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"status"]] integerValue];
        item.tempFileName = [[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"fileTempName"]];
        item.fileName = [[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"fileName"]];
        item.progress = [[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"progress"]]floatValue];
        item.totalContentLength = [[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"totalSize"]] integerValue];
        item.totalReceivedContentLength = [[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"downloadedSize"]] integerValue];
        item.startDownloadTime = [[[results objectAtIndex:0]objectAtIndex:[self.columnNamesArray indexOfObject:@"startDownloadTime"]] integerValue];
        return item;
    }
    else{
        return nil;
    }
}

-(HTFileTransferState)downloadItemStatus:(NSString *)downloadId{
    
    NSString * selectSql =[NSString stringWithFormat:@"select status from downloadItems where downloadId = \"%@\"",downloadId];
    
    [self runQuery:[selectSql UTF8String] isQueryExecutable:NO];
    NSArray * results = [[NSArray alloc] initWithArray:self.resultsArray];
    if (results.count == 1) {
        return [results[0][0] integerValue];
    }
   
    return HTFileTransferStateReady;
}

-(BOOL)deleteDownloadItem:(HTFileTransferItem *)item
{
    NSString * deleteSql = [NSString stringWithFormat:@"delete from downloadItems where downloadID=\"%@\"", item.downloadId];
    
    return [self executeQuery:deleteSql];
}

-(BOOL)deleteAllDownloadItems
{
    NSString * deleteSql = [NSString stringWithFormat:@"delete from downloadItems"];
 
    return [self executeQuery:deleteSql];
}

-(BOOL)deleteExpiredDownloadItems
{
    NSInteger startTimeOfExpiredTask = [[NSDate date] timeIntervalSince1970] - DEFAULT_DOWNLOADTASK_EXPIREDTIME;
    
    NSString * deleteSql = [NSString stringWithFormat:@"delete from downloadItems where startDownloadTime <= \"%ld\"", (long)startTimeOfExpiredTask];
    
    return [self executeQuery:deleteSql];
}

-(NSArray<HTFileTransferItem *> *)allDownloadItems
{
    NSMutableArray * downloadItems = [NSMutableArray array];
    
    NSString * selectSql = [NSString stringWithFormat:@"select * from downloadItems"];
    
    NSArray * results = [[NSArray alloc]initWithArray:[self loadDataFromDB:selectSql]];
    
    for (int i = 0; i < [results count]; ++i) {
        
        HTFileTransferItem * item = [[HTFileTransferItem alloc]init];
        item.downloadId = [[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"downloadID"]];
        item.url = [[NSURL alloc] initWithString:[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"url"]]];
        item.md5 = [[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"md5"]];
        item.status = [[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"status"]] integerValue];
        item.tempFileName = [[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"fileTempName"]];
        item.fileName = [[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"fileName"]];
        item.progress = [[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"progress"]]floatValue];
        item.totalContentLength = [[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"totalSize"]] integerValue];
        item.totalReceivedContentLength = [[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"downloadedSize"]] integerValue];
        item.startDownloadTime = [[[results objectAtIndex:i]objectAtIndex:[self.columnNamesArray indexOfObject:@"startDownloadTime"]] integerValue];
        
        [downloadItems addObject:item];
    }
    
    return downloadItems;
}

-(NSArray<HTFileTransferItem *> *)allSuspendedOrFailedDownloadItems
{
    NSArray * allDownloadItems = [self allDownloadItems];
    NSMutableArray * suspendedOrFailedDownloadItems = [NSMutableArray array];
    for (HTFileTransferItem * item in allDownloadItems) {
        if (item.status != HTFileTransferStateDone){
            [suspendedOrFailedDownloadItems addObject:item];
        }
    }
    
    return suspendedOrFailedDownloadItems;
}

#pragma mark -- interanl methods.

-(NSArray *)loadDataFromDB:(NSString *)query
{
    [self runQuery:[query UTF8String] isQueryExecutable:NO];

    return (NSArray *)self.resultsArray;
}

-(BOOL)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable
{
    //sqlite3 * sqlite3Database;
    BOOL isSuccess;
    
    if (self.resultsArray != nil) {
        [self.resultsArray removeAllObjects];
        self.resultsArray = nil;
    }
    
    self.resultsArray = [[NSMutableArray alloc]init];
    
    if (self.columnNamesArray != nil) {
        [self.columnNamesArray removeAllObjects];
        self.columnNamesArray = nil;
    }
    
    self.columnNamesArray = [[NSMutableArray alloc] init];
    
    sqlite3_stmt * compiledStatement; // query object
    BOOL prepareStatementResult = sqlite3_prepare_v2(database, query, -1, &compiledStatement, NULL);
    if (prepareStatementResult == SQLITE_OK) {
        
        //if not executable
        if (!queryExecutable) {
            
            NSMutableArray * arrDataRow;
            
            // Loop through the results and add them to the results array row by row.
            while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
                // Initialize the mutable array that will contain the data of a fetched row.
                arrDataRow = [[NSMutableArray alloc] init];
                
                // Get the total number of columns.
                int totalColumns = sqlite3_column_count(compiledStatement);
                
                // Go through all columns and fetch each column data.
                for (int i=0; i<totalColumns; i++){
                    // Convert the column data to text (characters).
                    char *dbDataAsChars = (char *)sqlite3_column_text(compiledStatement, i);
                    
                    // If there are contents in the currenct column (field) then add them to the current row array.
                    if (dbDataAsChars != NULL) {
                        // Convert the characters to string.
                        [arrDataRow addObject:[NSString  stringWithUTF8String:dbDataAsChars]];
                    }
                    
                    // Keep the current column name.
                    if (self.columnNamesArray.count != totalColumns) {
                        dbDataAsChars = (char *)sqlite3_column_name(compiledStatement, i);
                        [self.columnNamesArray addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                    }
                }
                
                // Store each fetched data row in the results array, but first check if there is actually data.
                if (arrDataRow.count > 0) {
                    [self.resultsArray addObject:arrDataRow];
                }
            }
            isSuccess = YES;
        }
        else{
            // excutable query
            
            NSUInteger excuteQueryResults = sqlite3_step(compiledStatement);
            if (excuteQueryResults == SQLITE_DONE) {
                self.affectedRows = sqlite3_changes(database);
                
                self.lastInsertedRowID = sqlite3_last_insert_rowid(database);
                isSuccess = YES;
            }
            else {
                // If could not execute the query show the error message on the debugger.
                isSuccess = NO;
                HTFDLogError(@"[HTFileDownloader]: %s", sqlite3_errmsg(database));
            }
        }
    }
    else{
        isSuccess = NO;
        HTFDLogError(@"[HTFileDownloader]: %s", sqlite3_errmsg(database));
    }
    // Release the compiled statement from memory.
    sqlite3_finalize(compiledStatement);
    
    return isSuccess;
}

-(BOOL)executeQuery:(NSString *)query
{
    return [self runQuery:[query UTF8String] isQueryExecutable:YES];
}


@end
