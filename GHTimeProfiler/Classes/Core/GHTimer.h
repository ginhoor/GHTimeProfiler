//
//  GHTimer.h
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, GHTimerStatus) {
    GHTimerStatusReady,
    GHTimerStatusResume,
    GHTimerStatusSuspend,
};

@class GHTimer;
@protocol GHTimerDelegate <NSObject>
- (void)timerAction:(GHTimer *)timer;
@end

@interface GHTimer : NSObject

@property (weak, nonatomic) id<GHTimerDelegate> delegate;

@property (assign, nonatomic) GHTimerStatus status;
@property (strong, nonatomic, readonly) dispatch_source_t timerSource;

@property (strong, nonatomic) dispatch_queue_t timerQueue;
/// 单位：秒
@property (assign, nonatomic) NSTimeInterval interval;
/// 延迟启动
@property (assign, nonatomic) NSTimeInterval delay;

- (void)start;
- (void)resume;
- (void)pause;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
