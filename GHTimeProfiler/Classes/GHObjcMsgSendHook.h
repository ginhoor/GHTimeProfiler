//
//  GHObjcMsgSendHook.h
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/3/17.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#include <stdio.h>
#include <objc/objc.h>

typedef struct {
    // 调用的class
    __unsafe_unretained Class cls;
    // 调用方法
    SEL sel;
    // 调用耗时 单位：微秒
    uint64_t time; // us (1/1000 ms)
    // 调用深度
    int depth;
} GHCallRecord;

extern void ghAnalyerStart(void);

extern void ghAnalyerStop(void);
/**
 设置调用耗时阈值，只记录超过部分，单位：微秒。
 默认值：1000
 */
extern void ghSetMinTimeCallCost(uint64_t us); //default 1000
/**
 设置调用最大深度
 默认值：3
 */
extern void ghSetMaxCallDepth(int depth);  //default 3
/**
 获得格式化调用记录
 @param num 获得记录数量
 @return 记录指针
 */
extern GHCallRecord *ghGetCallRecords(int *num);
/**
 清空记录
 */
extern void ghClearCallRecords(void);

/**
 设置是否只统计主线程
 @param only 开关
 */
extern void ghSetRecordMainThreadOnly(int only);
