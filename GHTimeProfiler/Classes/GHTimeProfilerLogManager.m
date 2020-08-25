//
//  GHLogDBManager.m
//  OC-Playground
//
//  Created by JunhuaShao on 2019/4/2.
//  Copyright © 2019 CarEagle. All rights reserved.
//

#import "GHTimeProfilerHeader.h"
#import "GHTimeProfilerLogManager.h"
#import "GHTimeProfilerLog.h"

@implementation GHTimeProfilerLogManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    [self createDBTable];
    _dbQueue = [self createDatabaseQueue];
    [self setupWhiteList];
}

- (void)setupWhiteList
{
    _logClassNameWhiteList = [NSMutableSet set];
    [_logClassNameWhiteList addObject:kGHTimeProfilerTotoalClassName];
}

- (FMDatabase *)createDatabase
{
    return [FMDatabase databaseWithPath:[self dbFilePath]];
}

- (FMDatabaseQueue *)createDatabaseQueue
{
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self dbFilePath]];
    return queue;
}

- (void)createDBTable
{
    NSString *dbFilePath = [self dbFilePath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:dbFilePath]) {
#ifdef GHTIMEPROFILER_LOG_ENABLE
        NSLog(@"[GHTimerProfiler] db file exists: %@",dbFilePath);
#endif
        return;
    }
    FMDatabase *db = [self createDatabase];
    if ([db open]) {
        NSString *createTableSql = [NSString stringWithFormat:
       @"create table gh_time_profiler "
       "("
           "log_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,"
           "class_name text,"
           "method_name text,"
           "is_class_method integer,"
           "time_cost double,"
           "call_depth integer,"
           "path text,"
           "last_call integer,"
           "frequency integer"
       ")"];
        [db executeUpdate:createTableSql];
#ifdef GHTIMEPROFILER_LOG_ENABLE
        NSLog(@"[GHTimerProfiler] Create GHTimerProfiler db file: %@",dbFilePath);
#endif

        [db close];
    }
}

- (void)clearLogs
{
    FMDatabase *db = [self createDatabase];
    if ([db open]) {
        [db executeUpdate:@"delete from gh_time_profiler"];
        [db close];
    }

#if GHTIMEPROFILER_LOG_ENABLE
    NSLog(@"[GHTimerProfiler] %s failed!",__func__);
#endif
}

- (void)addTimeProfilerLog:(GHTimeProfilerLog *)log
{
    if ([_logClassNameWhiteList containsObject:log.className]) {
        return;
    }
    
    [_dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if ([db open]) {
            FMResultSet *result = [db executeQuery:
            @"select log_id, frequency from gh_time_profiler "
            "where path = ?", log.path];
            if ([result next]) {
                NSInteger frequency = [result intForColumn:@"frequency"]+1;
                NSInteger logId = [result intForColumn:@"log_id"];
                [db executeUpdate:
                 @"update gh_time_profiler set frequency = ? "
                 "where log_id = ?", @(frequency), @(logId)];
            } else {
                NSNumber *lastCall = @(0);
                if (log.lastCall) {
                    lastCall = @(1);
                }
                [db executeUpdate:
                 @"insert into gh_time_profiler "
                 "("
                     "class_name,"
                     "method_name,"
                     "is_class_method,"
                     "time_cost,"
                     "call_depth,"
                     "path,"
                     "last_call,"
                     "frequency"
                 ") values (?,?,?,?,?,?,?,?)"
                 ,
                 log.className,
                 log.methodName,
                 @(log.isClassMethod),
                 @(log.timeCost),
                 @(log.callDepth),
                 log.path,
                 lastCall,
                 @(1)];
            }
            [db close];
        }
    }];
}

- (NSArray <GHTimeProfilerLog *> *)getTimeProfilerLogs:(NSInteger)pageIndex
{
    FMDatabase *db = [self createDatabase];
    if ([db open]) {
        FMResultSet *result = [db executeQuery:
        @"select * from gh_time_profiler "
        "where lastclass = ? order by frequency des limit ?, 20", @(1), @(pageIndex*20)];
        NSUInteger count = 0;
        NSMutableArray *mArr = [NSMutableArray array];
        while ([result next]) {
            GHTimeProfilerLog *log = [self createLogByFMResultSet:result];
            [mArr addObject:log];
            count++;
        }
        if (count > 0) {
            return mArr;
        } else {
            return nil;
        }
    }
    return nil;
}


#pragma mark- Private Method

- (GHTimeProfilerLog *)createLogByFMResultSet:(FMResultSet *)result
{
    GHTimeProfilerLog *log = [[GHTimeProfilerLog alloc] init];
    
    log.logId = [result intForColumn:@"log_id"];
    log.className = [result stringForColumn:@"class_name"];
    log.methodName = [result stringForColumn:@"method_name"];
    log.isClassMethod = [result intForColumn:@"is_class_method"];
    log.timeCost = [result doubleForColumn:@"time_cost"];
    log.callDepth = [result intForColumn:@"call_depth"];
    log.path = [result stringForColumn:@"path"];
    log.lastCall = [result intForColumn:@"last_call"];
    log.frequency = [result intForColumn:@"frequency"];
    
    return log;
}

- (NSString *)dbFilePath
{
    return [NSTemporaryDirectory() stringByAppendingString:@"gh_time_profiler_log.sqlite"];
}

@end
