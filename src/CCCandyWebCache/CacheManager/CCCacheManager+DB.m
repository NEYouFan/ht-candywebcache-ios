//
//  CCCacheManager+DB.m
//  Pods
//
//  Created by jw on 6/8/16.
//
//

#import "CCCacheManager+DB.h"
#import "sqlite3.h"
#import "CCLogger.h"
#import "NSString+MD5Encrypt.h"

static const NSString* WEBAPPINFOS = @"WEBAPPINFOS";
static const NSString* PATHINDEXINFOS = @"PATHINDEXINFOS";
static const NSString* DOMAINMAP = @"DOMAINMAP";

static NSString* databasePath;


void logDBError(sqlite3* db)
{
    CCLogError(@"[CCCandyWebCache]: %s",sqlite3_errmsg(db));
}

NSLock* dbLock;

@implementation CCCacheManager (DB)

- (BOOL)DB_createDatabaseAtPath:(NSString*)path
{
    databasePath = path;
    
    dbLock = [[NSLock alloc]init];
    
    BOOL result = [self handleDBWithBlock:^BOOL(sqlite3 *database) {
    
        NSString *ceateSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(NAME TEXT NOT NULL, DOMAIN BLOB, LOCALVERSION TEXT, FULLMD5 TEXT, LOCALPATH TEXT, STATUS INTEGER, FULLURL TEXT,UPDATEPERCENT FLOAT, DISKSIZE INT, TASKID TEXT, ISDIFFTASK INT,DIFFMD5 TEXT, DIFFURL TEXT)",WEBAPPINFOS];
        
        char *ERROR;
        if (sqlite3_exec(database, [ceateSQL UTF8String], NULL, NULL, &ERROR)!= SQLITE_OK){
            logDBError(database);
            return NO;
        }
        
        ceateSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(URL TEXT  NOT NULL, LOCALPATH TEXT, MD5 TEXT,WEBAPPNAME TEXT)",PATHINDEXINFOS];
        if (sqlite3_exec(database, [ceateSQL UTF8String], NULL, NULL, &ERROR)!= SQLITE_OK){
            logDBError(database);
            return NO;
        }
        return YES;
    }];
    
    return result;
}

- (NSArray<CCWebAppInfo*>*)DB_readWebAppInfos
{
    __block NSArray<CCWebAppInfo*>* infos = nil;
    [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *quary = [NSString stringWithFormat:@"SELECT * FROM %@",WEBAPPINFOS];
        sqlite3_stmt *stmt;
        
        if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            NSMutableArray<CCWebAppInfo*>* tmpArray = [[NSMutableArray alloc]init];
            while (sqlite3_step(stmt)==SQLITE_ROW) {
                CCWebAppInfo* info = [CCWebAppInfo new];
                
                char *name = (char *)sqlite3_column_text(stmt, 0);
                info.name = [self stringFromChars:name];
                
                NSData *domains = [NSData dataWithBytes:sqlite3_column_blob(stmt, 1) length:sqlite3_column_bytes(stmt, 1)];
                info.domains = [NSKeyedUnarchiver unarchiveObjectWithData:domains];
                
                char *local_version = (char *)sqlite3_column_text(stmt, 2);
                info.version = [[NSString alloc] initWithUTF8String:local_version];
                
                char *md5 = (char *)sqlite3_column_text(stmt, 3);
                info.fullPackageMD5 = [self stringFromChars:md5].decryptedMD5;
                
                char *local_path = (char *)sqlite3_column_text(stmt, 4);
                info.localRelativePath = [self stringFromChars:local_path];
                
                info.status = sqlite3_column_int(stmt, 5);
            
                char *fullURL = (char *)sqlite3_column_text(stmt, 6);
                info.fullDownloadURL = [self stringFromChars:fullURL];
                
                info.updatePercent = sqlite3_column_double(stmt, 7);
                
                info.diskSize = sqlite3_column_int64(stmt, 8);
                
                char *taskID = (char *)sqlite3_column_text(stmt, 9);
                info.taskID = [self stringFromChars:taskID];
                
                info.isDiffTask = sqlite3_column_int64(stmt, 10) == 1 ? YES : NO;
                
                char *diffmd5 = (char *)sqlite3_column_text(stmt, 11);
                info.diffPackageMD5 = [self stringFromChars:diffmd5].decryptedMD5;
                
                char *diffURL = (char *)sqlite3_column_text(stmt, 12);
                info.diffDownloadURL = [self stringFromChars:diffURL];
                
                [tmpArray addObject:info];
            }
            infos = tmpArray;
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
    
    return infos;
}

- (BOOL)DB_writeWebAppInfos:(NSArray<CCWebAppInfo*>*)webAppInfos
{
    [self clearTable:WEBAPPINFOS];
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *sqlString=[NSString stringWithFormat:@"INSERT INTO %@ (NAME, DOMAIN, LOCALVERSION, FULLMD5, LOCALPATH, STATUS, FULLURL, UPDATEPERCENT, DISKSIZE, TASKID, ISDIFFTASK, DIFFMD5, DIFFURL) values (?,?,?,?,?,?,?,?,?,?,?,?,?)",WEBAPPINFOS];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [sqlString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            for (CCWebAppInfo* info in webAppInfos) {
                sqlite3_bind_text(stmt, 1, info.name.UTF8String, -1, NULL);
        
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:info.domains];
                sqlite3_bind_blob(stmt, 2, [data bytes], (int)[data length], NULL);
                sqlite3_bind_text(stmt, 3, info.version.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 4, info.fullPackageMD5.encryptedMD5.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 5, info.localRelativePath.UTF8String, -1, NULL);
                sqlite3_bind_int(stmt, 6, info.status);
                sqlite3_bind_text(stmt, 7, info.fullDownloadURL.UTF8String, -1, NULL);
                sqlite3_bind_double(stmt, 8, info.updatePercent);
                sqlite3_bind_int64(stmt, 9, info.diskSize);
                sqlite3_bind_text(stmt, 10, info.taskID.UTF8String, -1, NULL);
                sqlite3_bind_int64(stmt, 11, info.isDiffTask ? 1 : 0);
                sqlite3_bind_text(stmt, 12, info.diffPackageMD5.encryptedMD5.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 13, info.diffDownloadURL.UTF8String, -1, NULL);
                if(sqlite3_step(stmt) != SQLITE_DONE){
                    logDBError(database);
                    result = NO;
                    break;
                }
                sqlite3_reset(stmt);
            }
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

- (BOOL)DB_insertWebAppInfo:(CCWebAppInfo*)webAppInfo
{
    if (!webAppInfo) {
        return NO;
    }
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *sqlString=[NSString stringWithFormat:@"INSERT INTO %@ (NAME, DOMAIN, LOCALVERSION, FULLMD5, LOCALPATH, STATUS, FULLURL, UPDATEPERCENT, DISKSIZE, TASKID, ISDIFFTASK, DIFFMD5, DIFFURL) values (?,?,?,?,?,?,?,?,?,?,?,?,?)",WEBAPPINFOS];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [sqlString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            CCWebAppInfo* info = webAppInfo;
            sqlite3_bind_text(stmt, 1, info.name.UTF8String, -1, NULL);
            
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:info.domains];
            sqlite3_bind_blob(stmt, 2, [data bytes], (int)[data length], NULL);
            sqlite3_bind_text(stmt, 3, info.version.UTF8String, -1, NULL);
            sqlite3_bind_text(stmt, 4, info.fullPackageMD5.encryptedMD5.UTF8String, -1, NULL);
            sqlite3_bind_text(stmt, 5, info.localRelativePath.UTF8String, -1, NULL);
            sqlite3_bind_int(stmt, 6, info.status);
            sqlite3_bind_text(stmt, 7, info.fullDownloadURL.UTF8String, -1, NULL);
            sqlite3_bind_double(stmt, 8, info.updatePercent);
            sqlite3_bind_int64(stmt, 9, info.diskSize);
            sqlite3_bind_text(stmt, 10, info.taskID.UTF8String, -1, NULL);
            sqlite3_bind_int64(stmt, 11, info.isDiffTask ? 1 : 0);
            sqlite3_bind_text(stmt, 12, info.diffPackageMD5.encryptedMD5.UTF8String, -1, NULL);
            sqlite3_bind_text(stmt, 13, info.diffDownloadURL.UTF8String, -1, NULL);
            if(sqlite3_step(stmt) != SQLITE_DONE){
                logDBError(database);
                result = NO;
            }
            sqlite3_reset(stmt);
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

- (BOOL)DB_deleteWebAppInfo:(CCWebAppInfo*)webAppInfo
{
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *sqlString = [NSString stringWithFormat:@"DELETE FROM %@ WHERE NAME = ?",WEBAPPINFOS];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [sqlString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, webAppInfo.name.UTF8String, -1, NULL);
            if (sqlite3_step(stmt)!=SQLITE_DONE){
                logDBError(database);
                result = NO;
            }
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

- (BOOL)DB_updateWebAppInfo:(CCWebAppInfo*)webAppInfo
{
    return [self DB_deleteWebAppInfo:webAppInfo] && [self DB_insertWebAppInfo:webAppInfo];
}

- (NSArray<CCResourceIndexInfo*>*)DB_readResourceIndexInfos
{
    __block NSArray<CCResourceIndexInfo*>* infos = nil;
    [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *quary = [NSString stringWithFormat:@"SELECT * FROM %@",PATHINDEXINFOS];
        sqlite3_stmt *stmt;
        
        if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            NSMutableArray<CCResourceIndexInfo*>* tmpArray = [[NSMutableArray alloc]init];
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                CCResourceIndexInfo* info = [CCResourceIndexInfo new];
                
                char *url = (char *)sqlite3_column_text(stmt, 0);
                info.url = [self stringFromChars:url];
                
                char *local_path = (char *)sqlite3_column_text(stmt, 1);
                info.localRelativePath = [self stringFromChars:local_path];
                
                char *md5 = (char *)sqlite3_column_text(stmt, 2);
                info.md5 = [self stringFromChars:md5].decryptedMD5;
                
                char *webappName = (char *)sqlite3_column_text(stmt, 3);
                info.webappName = [self stringFromChars:webappName];
                
                [tmpArray addObject:info];
            }
            infos = tmpArray;
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
    
    return infos;
}

- (BOOL)DB_writeResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)resourceIndexInfos
{
    [self clearTable:PATHINDEXINFOS];
    return [self DB_insertResourceIndexInfos:resourceIndexInfos];
}

- (BOOL)DB_insertResourceIndexInfos:(NSArray<CCResourceIndexInfo*>*)resourceIndexInfos
{
    if (resourceIndexInfos.count <= 0) {
        return YES;
    }
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *sqlString=[NSString stringWithFormat:@"INSERT INTO %@ (URL, LOCALPATH, MD5, WEBAPPNAME) values (?,?,?,?)",PATHINDEXINFOS];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [sqlString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            for (CCResourceIndexInfo* info in resourceIndexInfos) {
                sqlite3_bind_text(stmt, 1, info.url.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 2, info.localRelativePath.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 3, info.md5.encryptedMD5.UTF8String, -1, NULL);
                sqlite3_bind_text(stmt, 4, info.webappName.UTF8String, -1, NULL);
                if(sqlite3_step(stmt) != SQLITE_DONE){
                    logDBError(database);
                    result = NO;
                    break;
                }
                sqlite3_reset(stmt);
            }
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

//- (BOOL)DB_deleteResourceIndexInfo:(CCResourceIndexInfo*)resourceIndexInfo
//{
//    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
//        BOOL result = YES;
//        NSString *sqlString = [NSString stringWithFormat:@"DELETE FROM %@ WHERE URL = ?",PATHINDEXINFOS];
//        sqlite3_stmt *stmt;
//        if (sqlite3_prepare_v2(database, [sqlString UTF8String], -1, &stmt, nil) == SQLITE_OK) {
//            sqlite3_bind_text(stmt, 1, resourceIndexInfo.url.UTF8String, -1, NULL);
//            if (sqlite3_step(stmt)!=SQLITE_DONE){
//                logDBError(database);
//                result = NO;
//            }
//        }else{
//            logDBError(database);
//            result = NO;
//        }
//        sqlite3_finalize(stmt);
//        return result;
//    }];
//}

- (BOOL)DB_deleteWebAppInfoWithNames:(NSArray<NSString*>*)webappNames
{
    if (webappNames.count <= 0) {
        return YES;
    }
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *quary = [NSString stringWithFormat:@"DELETE FROM %@ WHERE NAME = ?",WEBAPPINFOS];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            for (NSString* webappName in webappNames) {
                sqlite3_bind_text(stmt, 1, webappName.UTF8String, -1, NULL);
                if (sqlite3_step(stmt) != SQLITE_DONE){
                    logDBError(database);
                    result = NO;
                    break;
                }
                sqlite3_reset(stmt);
            }
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

//- (BOOL)DB_deleteResourceIndexInfoWithURLs:(NSArray<NSString*>*)urls
//{
//    if (urls.count <= 0) {
//        return YES;
//    }
//    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
//        BOOL result = YES;
//        NSString *quary = [NSString stringWithFormat:@"DELETE FROM %@ WHERE URL = ?",PATHINDEXINFOS];
//        sqlite3_stmt *stmt;
//        if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
//            for (NSString* url in urls) {
//                sqlite3_bind_text(stmt, 1, url.UTF8String, -1, NULL);
//                if (sqlite3_step(stmt) != SQLITE_DONE){
//                    logDBError(database);
//                    result = NO;
//                    break;
//                }
//                sqlite3_reset(stmt);
//            }
//        }else{
//            logDBError(database);
//            result = NO;
//        }
//        sqlite3_finalize(stmt);
//        return result;
//    }];
//}

- (BOOL)DB_deleteResourceIndexInfoWithWebappNames:(NSArray<NSString*>*)webappNames
{
    if (webappNames.count <= 0) {
        return YES;
    }
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        sqlite3_stmt *stmt;
        for (NSString* webappName in webappNames) {
            NSString *quary = [NSString stringWithFormat:@"DELETE FROM %@ WHERE WEBAPPNAME = ?",PATHINDEXINFOS];
            if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
                sqlite3_bind_text(stmt, 1, webappName.UTF8String, -1, NULL);
                if (sqlite3_step(stmt) != SQLITE_DONE){
                    logDBError(database);
                    result = NO;
                    break;
                }
            }else{
                logDBError(database);
                result = NO;
            }
            sqlite3_reset(stmt);
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

#pragma mark -- private helper method

- (NSString*)stringFromChars:(char*)chars
{
    if (chars != NULL) {
        return [[NSString alloc] initWithUTF8String:chars];
    }
    return @"";
    
}

- (BOOL)clearTable:(const NSString*)tableName
{
    return [self handleDBWithBlock:^BOOL(sqlite3 *database) {
        BOOL result = YES;
        NSString *quary = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(database, [quary UTF8String], -1, &stmt, nil) == SQLITE_OK) {
            if (sqlite3_step(stmt)!=SQLITE_DONE){
                logDBError(database);
                result = NO;
            }
        }else{
            logDBError(database);
            result = NO;
        }
        sqlite3_finalize(stmt);
        return result;
    }];
}

- (BOOL)handleDBWithBlock:(BOOL (^)(sqlite3* database))block
{
    sqlite3 *database;
    if (sqlite3_open([databasePath UTF8String], &database) != SQLITE_OK) {
        logDBError(database);
        sqlite3_close(database);
        return NO;
    }
    BOOL result = YES;
    if (block) {
        [dbLock lock];
        result = block(database);
        [dbLock unlock];
    }
    sqlite3_close(database);
    return result;
}

@end
