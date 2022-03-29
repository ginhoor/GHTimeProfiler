//
//  GhStackFrame.h
//  
//
//  Created by sjh on 2021/8/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GhStackFrame : NSObject

+ (NSString *)gh_backtraceOfCurrentThread;
+ (NSString *)gh_backtraceOfMainThread;
+ (NSString *)gh_backtraceOfNSThread:(NSThread *)thread;
+ (NSString *)gh_backtraceOfThread:(thread_t)thread;
+ (NSString *)gh_backtraceOfAllThread;
+ (NSString *)gh_backtraceOfFlutterUIThread;
+ (NSString *)gh_backtraceOfAllFlutterThread;

@end

NS_ASSUME_NONNULL_END
