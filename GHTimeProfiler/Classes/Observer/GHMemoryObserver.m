//
//  GHMemoryObserver.m
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/6/22.
//

#import <mach/mach.h>

#import "GHMemoryObserver.h"

#import "GHStackFrame.h"
#import "GHTimer.h"

@interface GHMemoryObserver ()

@property (nonatomic, strong) GHTimer *timer;
@property (copy, nonatomic) void (^callback)(int vmMemory, int physicalMemory, int total);

@end

@implementation GHMemoryObserver

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)registerWarningCallback:(void(^)(int vmMemory, int physicalMemory, int total))callback {    self.callback = callback;
}

- (void)startByInterval:(NSTimeInterval)interval {
    if (self.timer) return;

    if (self.vmMemoryUsageHighRate == 0) {
        self.vmMemoryUsageHighRate = 50;
    }

    if (self.physicalMemoryUsageHighRate == 0) {
        self.physicalMemoryUsageHighRate = 50;
    }

    self.timer = [[GHTimer alloc] init];
    self.timer.interval = interval;
    self.timer.delay = 0;
    self.timer.delegate = self;
    [self.timer start];
}

- (void)timerAction:(GHTimer *)timer {
    [self captureInfo];
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

- (void)captureInfo {
    int64_t vmMemoryUsage = [[self class] vmMemoryUsage];
    int64_t physicalMemoryUsage = [[self class] physicalMemoryUsage];
    int64_t totalMemoryUsage = [[self class] totalPhysicalMemory];

    if (vmMemoryUsage/totalMemoryUsage > self.vmMemoryUsageHighRate) {
        !self.callback?:self.callback(vmMemoryUsage, physicalMemoryUsage, totalMemoryUsage);
    }

    if (physicalMemoryUsage/totalMemoryUsage > self.physicalMemoryUsageHighRate) {
        !self.callback?:self.callback(vmMemoryUsage, physicalMemoryUsage, totalMemoryUsage);
    }
}

+ (int64_t)vmMemoryUsage {
    int64_t memoryUsageInByte = 0;
    struct task_basic_info taskBasicInfo;
    mach_msg_type_number_t size = sizeof(taskBasicInfo);
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t) &taskBasicInfo, &size);

    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) taskBasicInfo.resident_size;
//        NSLog(@"Memory in use (in bytes): %lld", memoryUsageInByte);
    } else {
//        NSLog(@"Error with task_info(): %s", mach_error_string(kernelReturn));
    }
    return memoryUsageInByte;
}

+ (int64_t)physicalMemoryUsage {
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernelReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if(kernelReturn == KERN_SUCCESS) {
        memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
//        NSLog(@"Memory in use (in bytes): %lld", memoryUsageInByte);
    } else {
//        NSLog(@"Error with task_info(): %s", mach_error_string(kernelReturn));
    }
    return memoryUsageInByte;
}

+ (int64_t)totalPhysicalMemory {
    int64_t totalMemory = [[NSProcessInfo processInfo] physicalMemory];
    if (totalMemory < -1) totalMemory = -1;
    return totalMemory;
}


@end
