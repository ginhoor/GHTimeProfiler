//
//  GHTimeProfilerLog.h
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/4/2.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kGHTimeProfilerTotoalClassName @"GHTimeProfiler Totoal"
NS_ASSUME_NONNULL_BEGIN

@interface GHTimeProfilerLog : NSObject

@property (nonatomic, assign) NSInteger logId;
/**
 类名
 */
@property (nonatomic, strong) NSString * _Nullable className;
/**
 方法名
 */
@property (nonatomic, strong) NSString * _Nullable methodName;
/**
 是否为类方法
 */
@property (nonatomic, assign) BOOL isClassMethod;
/**
 函数调用耗时（秒）
 */
@property (nonatomic, assign) NSTimeInterval timeCost;
/**
 调用层级
 */
@property (nonatomic, assign) NSUInteger callDepth;
/**
 调用路径
 */
@property (nonatomic, copy)   NSString * _Nullable path;
/**
 是否是原子调用（内部无其他函数调用）
 */
@property (nonatomic, assign) BOOL lastCall;
/**
 调用次数
 */
@property (nonatomic, assign) NSUInteger frequency;
/**
 内部调用过的函数
 */
@property (nonatomic, strong) NSArray <GHTimeProfilerLog *> * _Nullable subCosts;
/**
 创建时间戳
 */
@property (nonatomic, assign) NSTimeInterval createDate;

@end

NS_ASSUME_NONNULL_END
