//
//  GHRunloopObserver.h
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GHRunloopObserver : NSObject
/// 主线程连续响应超时的次数，默认3次
@property (assign, nonatomic) NSInteger timeoutLimitCount;
/// 卡顿阈值，默认为 50ms
@property (assign, nonatomic) NSInteger timeoutThreshold;

+ (instancetype)sharedInstance;

- (void)registerWarningCallback:(void(^)(void))timeoutCallback;

- (void)start;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
