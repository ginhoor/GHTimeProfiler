//
//  GHMemoryObserver.h
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/6/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GHMemoryObserver : NSObject

@property (assign, nonatomic) NSUInteger vmMemoryUsageHighRate;
@property (assign, nonatomic) NSUInteger physicalMemoryUsageHighRate;

+ (instancetype)sharedInstance;

- (void)registerWarningCallback:(void(^)(int vmMemory, int physicalMemory, int total))callback;

- (void)start;
- (void)startByInterval:(NSTimeInterval)interval;
- (void)stop;

+ (int64_t)vmMemoryUsage;
+ (int64_t)physicalMemoryUsage;
+ (int64_t)totalPhysicalMemory;

@end

NS_ASSUME_NONNULL_END
