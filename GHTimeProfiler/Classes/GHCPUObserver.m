//
//  GHCPUObserver.m
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import <mach/mach.h>
#import "GHCPUObserver.h"
#import "GhStackFrame.h"

@interface GHCPUObserver ()

@property (nonatomic, strong) NSTimer *timer;

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

- (void)start {
    // 每3秒获取一次cpu信息
    if (self.timer) {
        return;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:3
                                                  target:self
                                                selector:@selector(updateCPUInfo)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stop {
    if (!self.timer) {
        return;
    }
    
    [self.timer invalidate];
    self.timer = nil;
}

- (void)updateCPUInfo {
    // CPU使用率 80%
    int cpuUsageHighRate = 80;

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
                if (cpuUsage > cpuUsageHighRate) {
                    // 打印当前线程的堆栈
                    NSLog(@"[thread] cpu over usage(%d)\n %@",cpuUsage,[GhStackFrame gh_backtraceOfThread:threads[i]]);
                }
            }
        }
    }
}



@end
