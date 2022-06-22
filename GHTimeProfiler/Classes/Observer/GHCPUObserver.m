//
//  GHCPUObserver.m
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import <mach/mach.h>
#import "GHCPUObserver.h"
#import "GHStackFrame.h"
#import "GHTimer.h"
@interface GHCPUObserver ()

@property (nonatomic, strong) GHTimer *timer;
@property (copy, nonatomic) void (^cpuUsageHighRateCallback)(int usage, thread_act_t thread);

@end

@implementation GHCPUObserver

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)registerWarningCallback:(void (^)(int usage, thread_act_t thread))cpuUsageHighRateCallback {
    self.cpuUsageHighRateCallback = cpuUsageHighRateCallback;
}

- (void)startByInterval:(NSTimeInterval)interval {
    if (self.timer) return;

    if (self.cpuUsageHighRate == 0) {
        self.cpuUsageHighRate = 80;
    }

    self.timer = [[GHTimer alloc] init];
    self.timer.interval = interval;
    self.timer.delay = 0;
    self.timer.delegate = self;
    [self.timer start];
}

- (void)timerAction:(GHTimer *)timer {
    [self updateCPUInfo];
}

/// 每3秒获取一次cpu信息
- (void)start {
    [self startByInterval:3];
}

- (void)stop {
    if (!self.timer) return;
    
    [self.timer stop];
    self.timer = nil;
}

- (void)updateCPUInfo {

    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    task_t thisTask = mach_task_self();
    // 获得所有线程
    kern_return_t kr = task_threads(thisTask, &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        return;
    }
    
    for (int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        thread_basic_info_t threadBaseInfo;
        kern_return_t ret = thread_info((thread_act_t)threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount);
        if (ret == KERN_SUCCESS) {
            threadBaseInfo = (thread_basic_info_t)threadInfo;
            // 线程非闲置状态
            if (!(threadBaseInfo->flags & TH_FLAGS_IDLE)) {
                integer_t cpuUsage = threadBaseInfo->cpu_usage / 10;
                // CPU使用率高于阈值
                if (cpuUsage > self.cpuUsageHighRate) {
                    // 打印当前线程的堆栈
                    thread_act_t thread = threads[i];
                    !self.cpuUsageHighRateCallback?:self.cpuUsageHighRateCallback(cpuUsage, thread);
//                    NSLog(@"[thread] cpu over usage(%d)\n %@",cpuUsage,[GHStackFrame gh_backtraceOfThread:threads[i]]);
                }
            }
        }
    }
}

@end
