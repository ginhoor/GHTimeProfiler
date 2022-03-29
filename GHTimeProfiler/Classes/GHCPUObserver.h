//
//  GHCPUObserver.h
//  GHTimeProfiler
//
//  Created by 大帅 on 2022/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GHCPUObserver : NSObject

+ (instancetype)sharedInstance;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
