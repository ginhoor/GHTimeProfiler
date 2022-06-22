//
//  GHCPUObserver.h
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GHCPUObserver : NSObject

@property (assign, nonatomic) NSUInteger cpuUsageHighRate;

+ (instancetype)sharedInstance;

- (void)registerWarningCallback:(void(^)(int usage, thread_act_t thread))cpuUsageHighRateCallback;

- (void)start;
- (void)startByInterval:(NSTimeInterval)interval;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
