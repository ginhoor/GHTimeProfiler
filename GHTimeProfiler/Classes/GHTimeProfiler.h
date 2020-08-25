//
//  GHTimeProfiler.h
//  OC-Playground
//
//  Created by JunhuaShao on 2019/3/22.
//  Copyright © 2019 CarEagle. All rights reserved.
//


#import <Foundation/Foundation.h>

@class GHTimeProfilerLog;
@protocol GHTimeProfilerDelegate <NSObject>

- (void)timeProfilerDidSaved:(NSArray <GHTimeProfilerLog *> *_Nullable)logs formatString:(NSString * _Nullable)formatString;

@end

NS_ASSUME_NONNULL_BEGIN

@interface GHTimeProfiler : NSObject

+ (void)setDelegate:(id<GHTimeProfilerDelegate>)delegate;
/**
 开始记录
 */
+ (void)start;

+ (void)startWithMaxDepth:(int)depth;
+ (void)startWithMinTimeCallCost:(double)ms;
+ (void)startWithMaxDepth:(int)depth minTimeCallCost:(double)ms;

/**
 停止记录，不删除记录缓存
 */
+ (void)stop;

/**
 停止记录，并且保存，随后删除记录缓存。
 */
+ (void)stopSaveAndClean;

@end

NS_ASSUME_NONNULL_END
