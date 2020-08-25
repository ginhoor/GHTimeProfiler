//
//  GHTimeProfiler.m
//  OC-Playground
//
//  Created by JunhuaShao on 2019/3/22.
//  Copyright © 2019 CarEagle. All rights reserved.
//

#import "GHTimeProfiler.h"

#import <objc/runtime.h>
#import "GHObjcMsgSendHook.h"

#import "GHTimeProfilerHeader.h"
#import "GHTimeProfilerLog.h"
#import "GHTimeProfilerLogManager.h"

@interface GHTimeProfiler()

@end

@implementation GHTimeProfiler


static id<GHTimeProfilerDelegate> _delegate;
+ (void)setDelegate:(id<GHTimeProfilerDelegate>)delegate
{
    _delegate = delegate;
}

+ (void)start
{
    ghAnalyerStart();
}

+ (void)startWithMaxDepth:(int)depth
{
    ghSetMaxCallDepth(depth);
    ghAnalyerStart();
}

+ (void)startWithMinTimeCallCost:(double)ms
{
    ghSetMinTimeCallCost(ms*1000);
    ghAnalyerStart();
}

+ (void)startWithRecordAllThread
{
    ghSetRecordMainThreadOnly(false);
    ghAnalyerStart();
}

+ (void)startWithMaxDepth:(int)depth minTimeCallCost:(double)ms
{
    ghSetMinTimeCallCost(ms*1000);
    ghSetMaxCallDepth(depth);
    ghAnalyerStart();
}

+ (void)stop
{
    ghAnalyerStop();
}

+ (void)stopSaveAndClean
{
    [self stop];
    [self save];
    ghClearCallRecords();
}

/**
 保存记录
 */
+ (void)save
{
    NSMutableString *mStr = [NSMutableString string];
    NSArray<GHTimeProfilerLog *> *logs = [self loadRecords];
    
    [logs enumerateObjectsUsingBlock:^(GHTimeProfilerLog * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.path = [NSString stringWithFormat:@"[%@ %@]", obj.className, obj.methodName];
        [self appendRecord:obj to:mStr];
    }];
    
#if GHTIMEPROFILER_LOG_ENABLE
    NSLog(@"GHTimeProfiler\n%@", mStr);
#endif
    
    if (_delegate && [_delegate respondsToSelector:@selector(timeProfilerDidSaved:formatString:)]) {
        [_delegate timeProfilerDidSaved:logs formatString:mStr];
    }
}

/**
 获得当前的所有记录
 
 @return 处理后的记录
 */
+ (NSArray <GHTimeProfilerLog *>*)loadRecords
{
    NSMutableArray<GHTimeProfilerLog *> *mArr = [NSMutableArray array];
    int num = 0;
    // 获取记录
    GHCallRecord *records = ghGetCallRecords(&num);
    
    // 耗时总计
    GHTimeProfilerLog *totalLog = [[GHTimeProfilerLog alloc] init];
    [mArr addObject:totalLog];
    totalLog.callDepth = 0;
    totalLog.className = kGHTimeProfilerTotoalClassName;
    totalLog.methodName = @"timeCost";
    
    // 转换Model
    for (int i = 0; i < num; i++) {
        GHCallRecord *rd = &records[i];
        // 不记录当前工具类的耗时情况
//        NSString *className = NSStringFromClass(rd->cls);
//        if ([className isEqualToString:NSStringFromClass([self class])]) {
//            continue;
//        }
        GHTimeProfilerLog *model = [[GHTimeProfilerLog alloc] init];
        model.className = NSStringFromClass(rd->cls);
        model.methodName = NSStringFromSelector(rd->sel);
        model.isClassMethod = class_isMetaClass(rd->cls);
        model.timeCost = (double)rd->time / 1000000.0;
        model.callDepth = rd->depth;
        
        if (model.callDepth == 0) {
            totalLog.timeCost += model.timeCost;
        }
        
        [mArr addObject:model];
    }

    NSUInteger count = mArr.count;
    // 整理调用深度
    for (NSUInteger i = 0; i < count; i++) {
        GHTimeProfilerLog *model = mArr[i];
        if (model.callDepth > 0) {
            // 找到深度大于0的，移出队列。
            // 深度大于0表示这是个在函数内部被调用的函数
            [mArr removeObjectAtIndex:i];

            for (NSUInteger j = i; j < count - 1; j++) {
                // 这里不需要循环全部记录，函数内调用会被保存在父级函数调用的后位，是连续的。
                // 直接设置下一个，然后判断好边界就行。
                // 寻找比当前model深度更高的记录
                if (mArr[j].callDepth + 1 == model.callDepth) {
                    NSMutableArray *sub = (NSMutableArray *)mArr[j].subCosts;
                    if (!sub) {
                        sub = [NSMutableArray array];
                        mArr[j].subCosts = sub;
                    }
                    // 将当前model放入上级调用中
                    [sub insertObject:model atIndex:0];
                }
            }
            // 由于当前位置元素被移除，游标维持原位置
            i--;
            // 记录数量减一
            count--;
        }
    }
    return mArr;
}

/**
 添加记录
 
 @param cost 记录
 @param mStr 拼接字符串
 */
+ (void)appendRecord:(GHTimeProfilerLog *)cost to:(NSMutableString *)mStr
{
    [mStr appendFormat:@"%@\n>>> PATH -> %@\n", cost, cost.path];
    if (cost.subCosts.count == 0) {
        cost.lastCall = YES;
        // 记录到数据库
        [[GHTimeProfilerLogManager sharedInstance] addTimeProfilerLog:cost];
    } else {
        [cost.subCosts enumerateObjectsUsingBlock:^(GHTimeProfilerLog * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            // 不记录当前工具类的记录
            if ([obj.className isEqualToString:NSStringFromClass([self class])]) {
                *stop = YES;
            }
            // 记录方法的子方法的路径
            obj.path = [NSString stringWithFormat:@"%@ - [%@ %@]", cost.path, obj.className, obj.methodName];
            [self appendRecord:obj to:mStr];
        }];
    }
}


@end
