//
//  GHRunloopObserver.m
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import "GHRunloopObserver.h"
#import "GHStackFrame.h"

@interface GHRunloopObserver() {
    CFRunLoopObserverRef runloopObserver;
    dispatch_semaphore_t observerSemaphore;
    // 当前Runloop对象
    CFRunLoopActivity runloopActivity;
    NSUInteger currentTimeoutIndex;
}
@property (copy, nonatomic) void(^timeoutCallback) (void);

@end

@implementation GHRunloopObserver

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _timeoutLimitCount = 3;
        _timeoutThreshold = 50;
    }
    return self;
}

- (void)registerWarningCallback:(void (^)(void))timeoutCallback {
    self.timeoutCallback = timeoutCallback;
}

- (void)start {
    [self createRunloopObserver];
}

- (void)stop {
    if (!runloopObserver) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), self->runloopObserver, kCFRunLoopCommonModes);
    CFRelease(self->runloopObserver);
    self->runloopObserver = NULL;
}

- (void)createRunloopObserver {
    if (runloopObserver) return;

    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    runloopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                              kCFRunLoopAllActivities,
                                              YES,
                                              0,
                                              &runloopCallBack,
                                              &context);
    // 注册到主线程的runloop中
    CFRunLoopAddObserver(CFRunLoopGetMain(), runloopObserver, kCFRunLoopCommonModes);
    
    // Dispatch Semaphore保证同步
    observerSemaphore = dispatch_semaphore_create(0);
    self->currentTimeoutIndex = 0;

    // 开启一个子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES) {
            long semephoreWait = dispatch_semaphore_wait(self->observerSemaphore, dispatch_time(DISPATCH_TIME_NOW, self->_timeoutThreshold * NSEC_PER_MSEC));
            if (semephoreWait != 0) {
                if (!self->runloopObserver) {
                    // 监控结束
                    return;
                }
                // 监测从BeforeSources到AfterWaiting的区间耗时，可以判断是否出现卡顿
                if (self->runloopActivity == kCFRunLoopBeforeSources ||
                    self->runloopActivity == kCFRunLoopAfterWaiting) {
                    if (++self->currentTimeoutIndex < self -> _timeoutLimitCount) {
                        continue;
                    }
                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                        // 记录超时事件
                        !self.timeoutCallback?:self.timeoutCallback();
//                        NSLog(@"[runloop] %@", [GHStackFrame backtraceOfMainThread]);
                    });
                }
            }
            self->currentTimeoutIndex = 0;
        }
    });
}

static void runloopCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    // 记录Runloop的每次变更
    GHRunloopObserver *ob = (__bridge GHRunloopObserver *)info;
    ob->runloopActivity = activity;
    
    // 用信号量通知子线程
    dispatch_semaphore_t s = ob->observerSemaphore;
    dispatch_semaphore_signal(s);
}

@end
