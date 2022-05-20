//
//  GhStackFrame.h
//  
//
//  Created by sjh on 2021/8/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GhStackFrame : NSObject

+ (NSString *)backtraceOfCurrentThread;
+ (NSString *)backtraceOfMainThread;
+ (NSString *)backtraceOfNSThread:(NSThread *)thread;
+ (NSString *)backtraceOfThread:(thread_t)thread;
+ (NSString *)backtraceOfAllThread;
+ (NSString *)backtraceOfFlutterUIThread;
+ (NSString *)backtraceOfAllFlutterThread;

@end

NS_ASSUME_NONNULL_END
