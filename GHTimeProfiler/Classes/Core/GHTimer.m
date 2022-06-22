//
//  GHTimer.m
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/5/19.
//

#import "GHTimer.h"

@interface GHTimer ()

@property (strong, nonatomic) dispatch_source_t timerSource;

@end

@implementation GHTimer

- (void)dealloc {
    [self stop];
}

- (void)start {
    [self stop];
    _timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.timerQueue);
    dispatch_source_set_timer(_timerSource, dispatch_time(DISPATCH_TIME_NOW, self.delay * NSEC_PER_SEC), self.interval * NSEC_PER_SEC, 0 * NSEC_PER_SEC);

    __weak typeof(self) _WeakSelf = self;
    dispatch_source_set_event_handler(_timerSource, ^{
        if ([_WeakSelf.delegate respondsToSelector:@selector(timerAction:)]) {
            [_WeakSelf.delegate timerAction:_WeakSelf];
        }
    });
    dispatch_resume(_timerSource);
    _status = GHTimerStatusResume;
}

- (void)resume {
    if (_status == GHTimerStatusSuspend) {
        if (_timerSource) dispatch_resume(_timerSource);
        _status = GHTimerStatusResume;
    }
}

- (void)pause {
    if (_status == GHTimerStatusResume) {
        if (_timerSource) dispatch_suspend(_timerSource);
        _status = GHTimerStatusSuspend;
    }
}

- (void)stop {
    if (_status == GHTimerStatusResume) {
        if (_timerSource) {
            dispatch_cancel(_timerSource);
            _timerSource = nil;
        }
        _status = GHTimerStatusReady;
    }
}

- (dispatch_queue_t)timerQueue {
    if (!_timerQueue) {
        NSString *radomName = [NSString stringWithFormat:@"GHTimer-%@",[NSUUID UUID].UUIDString];
        _timerQueue = dispatch_queue_create([radomName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
    }
    return _timerQueue;
}

@end
