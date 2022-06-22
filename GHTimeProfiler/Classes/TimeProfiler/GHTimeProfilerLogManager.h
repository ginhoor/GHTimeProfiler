//
//  GHLogDBManager.h
//  OC-Playground
//
//  Created by JunhuaShao on 2019/4/2.
//  Copyright © 2019 CarEagle. All rights reserved.
//

#import <Foundation/Foundation.h>
@import FMDB;
@class GHTimeProfilerLog;

NS_ASSUME_NONNULL_BEGIN

@interface GHTimeProfilerLogManager : NSObject

@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
@property (nonatomic, strong) NSMutableSet <NSString *> *logClassNameWhiteList;

+ (instancetype)sharedInstance;

- (void)addTimeProfilerLog:(GHTimeProfilerLog *)log;
- (NSArray <GHTimeProfilerLog *> *)getTimeProfilerLogs:(NSInteger)pageIndex;

- (NSString *)dbFilePath;

@end

NS_ASSUME_NONNULL_END
