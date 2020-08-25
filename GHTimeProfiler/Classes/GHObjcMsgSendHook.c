//
//  GHObjcMsgSendHook.c
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/3/17.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

/********************************************************
 objc_msgSend Hook代码来源：https://github.com/ming1016/GCDFetchFeed
 线程局部存储：https://blog.csdn.net/vevenlcf/article/details/77882985
 ********************************************************
 */

#import "GHObjcMsgSendHook.h"

// 此Hook只支持arm64架构
#ifdef __aarch64__

//#import <objc/runtime.h>
//#import <sys/time.h>
//
//#import <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <pthread.h>

#import "fishhook.h"

/**
 Configuration
 */
// 调用记录工具开关
static bool _call_record_enabled = true;
// 设置最小耗时阈值，单位：微秒
static uint64_t _min_time_cost = 1000; //us
// 设置最大调用深度阈值
static int _max_call_depth = 3;
// 是否值检测主线程耗时
static bool _record_main_thread_only = true;

/**
 iVar
 */
// 被替换的原objc_msgSend
__unused static id (*orig_objc_msgSend)(id, SEL, ...);
// 用于和调用线程关联的key，在开启工具时初始化
static pthread_key_t _thread_key;
// 格式化的耗时记录
static GHCallRecord *_ghCallRecords;
// 格式化的耗时记录占用空间
static int _ghRecordAlloc;
// 格式化耗时记录的个数
static int _ghRecordNum;

/**
 被hook函数的调用记录
 */
typedef struct {
    // 通过 object_getClass 能够得到 Class
    id self;
    // 通过 NSStringFromClass 能够得到类名
    Class cls;
    // 通过 NSStringFromSelector 方法能够得到方法名
    SEL cmd;
    // us 调用时间（微秒）
    uint64_t time;
    // link register 用于指定下一个函数的地址
    uintptr_t lr;
} thread_call_record;

/**
 线程中函数调用栈
 */
typedef struct {
    // 当前被hook函数的调用记录
    thread_call_record *stack;
    // 当前存储空间大小
    int allocated_length;
    // 当前记录序号
    int index;
    // 是否在主线程上
    bool is_main_thread;
} thread_call_stack;

/**
 获得线程中的函数调用栈

 @return 函数调用栈
 */
static inline thread_call_stack * get_thread_call_stack() {
    /**
     int pthread_setspecific (pthread_key_t key, const void *value)
     用于将value的副本存储于一数据结构中，并将其与调用线程以及key相关联。
     参数value通常指向由调用者分配的一块内存。
     当线程终止时，会将该指针作为参数传递给与key相关联的destructor函数。
     
     void *pthread_getspecific (pthread_key_t key);
     当线程被创建时，会将所有的线程局部存储变量初始化为NULL。
     因此第一次使用此类变量前必须先调用pthread_getspecific()函数来确认是否已经于对应的key相关联，
     如果没有，那么可以通过分配一块内存并通过pthread_setspecific()函数保存指向该内存块的指针。
     */
    thread_call_stack *cs = (thread_call_stack *)pthread_getspecific(_thread_key);
    if (cs == NULL) {
        // 为函数调用栈开辟空间
        cs = (thread_call_stack *)malloc(sizeof(thread_call_stack));
        // 为hook函数记录开辟空间，大小为128个记录大小
        cs->stack = (thread_call_record *)calloc(128, sizeof(thread_call_record));
        // 初始当前存储空间为64个记录大小
        cs->allocated_length = 64;
        // 初始化序号
        cs->index = -1;
        /**
         int pthread_main_np(void); 如果在主线程上，会返回不为零的结果
         */
        cs->is_main_thread = pthread_main_np();
        // 将调用栈与线程关联
        pthread_setspecific(_thread_key, cs);
    }
    return cs;
}

static void release_thread_call_stack(void *ptr) {
    thread_call_stack *cs = (thread_call_stack *)ptr;
    if (!cs) return;
    // 释放调用栈
    if (cs->stack) free(cs->stack);
    free(cs);
}

static inline void push_call_record(id _self, Class _cls, SEL _cmd, uintptr_t lr) {
    // 获得当前线程关联的调用栈
    thread_call_stack *cs = get_thread_call_stack();
    if (cs) {
        // 序号增一
        int nextIndex = (++cs->index);
        // 如果序号超过了当前存储空间大小
        if (nextIndex >= cs->allocated_length) {
            // 将当前存储空间增长64个记录大小
            cs->allocated_length += 64;
            // 为指针重新分配调用栈的空间，为当前存储空间大小。
            cs->stack = (thread_call_record *)realloc(cs->stack, cs->allocated_length * sizeof(thread_call_record));
        }
        // 获得当前序号对应的内存地址，创建新记录
        thread_call_record *newRecord = &cs->stack[nextIndex];
        // 记录调用对象
        newRecord->self = _self;
        // 记录调用class
        newRecord->cls = _cls;
        // 记录调用函数
        newRecord->cmd = _cmd;
        // 记录下一个调用函数地址
        newRecord->lr = lr;

        bool ready_for_record =
                                (_record_main_thread_only && cs->is_main_thread)
                                || !_record_main_thread_only;
        
        if (ready_for_record && _call_record_enabled) {
            /**
             Linux定义的timeval结构体
             __darwin_time_t            tv_sec;            //seconds
             __darwin_suseconds_t    tv_usec;        //and microseconds
             
             tv_sec为Epoch到创建struct timeval时的秒数，
             tv_usec为微秒数，即秒后面的零头。
             这里用了高精度，所以对两者进行了相加，取了最近的100秒
             */
            struct timeval now;
            // 获得当前时间
            gettimeofday(&now, NULL);
            newRecord->time = (now.tv_sec % 100) * 1000000 + now.tv_usec;
        }
    }
}

static inline uintptr_t pop_call_record() {
    // 获取当前调用栈
    thread_call_stack *cs = get_thread_call_stack();
    // 当前调用记录序号
    int curIndex = cs->index;
    // 父级函数调用记录序号
    int nextIndex = cs->index--;
    // 获取父级函数调用记录，出栈
    thread_call_record *pRecord = &cs->stack[nextIndex];
    
    bool ready_for_record =
                            (_record_main_thread_only && cs->is_main_thread)
                            || !_record_main_thread_only;
    if (ready_for_record && _call_record_enabled) {
        // 获取当前时间
        struct timeval now;
        gettimeofday(&now, NULL);
        uint64_t time = (now.tv_sec % 100) * 1000000 + now.tv_usec;
        // 如果当前时间小于上次记录的时间，则进位了，这里加上100秒
        if (time < pRecord->time) {
            time += 100 * 1000000;
        }
        // 获得耗时
        uint64_t cost = time - pRecord->time;
        // 耗时大于耗时阈值，调用深度小于最大深度，则进行记录。这里调用序号，即为深度
        if (cost > _min_time_cost && cs->index < _max_call_depth) {
            // 初始化格式化耗时记录
            if (!_ghCallRecords) {
                // 创建空间大小为1024个记录
                _ghRecordAlloc = 1024;
                _ghCallRecords = (GHCallRecord *)malloc(sizeof(GHCallRecord)*_ghRecordAlloc);
                
            }
            // 记录个数加一
            _ghRecordNum++;
            // 当前记录个数大于空间时，重新为指针分配内存，大小为比原来多1024个记录
            if (_ghRecordNum >= _ghRecordAlloc) {
                _ghRecordAlloc += 1024;
                _ghCallRecords = (GHCallRecord *)realloc(_ghCallRecords, sizeof(GHCallRecord) * _ghRecordAlloc);
            }
            // 获取当前页数对应的地址，创建格式化记录。
            GHCallRecord *log = &_ghCallRecords[_ghRecordNum - 1];
            // 保存调用class
            log->cls = pRecord->cls;
            // 保存调用深度
            log->depth = curIndex;
            // 保存调用方法
            log->sel = pRecord->cmd;
            // 保存耗时
            log->time = cost;
        }
    }
    // 返回下个函数的调用地址
    return pRecord->lr;
}

void hook_before_objc_msgSend(id self, SEL _cmd, uintptr_t lr)
{
    // 函数调用记录入栈
    push_call_record(self, object_getClass(self), _cmd, lr);
}

uintptr_t hook_after_objc_msgSend() {
    // 函数调用记录出栈
    return pop_call_record();
}
// replacement objc_msgSend (arm64)
// https://blog.nelhage.com/2010/10/amd64-and-va_arg/
// http://infocenter.arm.com/help/topic/com.arm.doc.ihi0055b/IHI0055B_aapcs64.pdf
// https://developer.apple.com/library/ios/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
#define call(b, value) \
__asm volatile ("stp x8, x9, [sp, #-16]!\n"); \
__asm volatile ("mov x12, %0\n" :: "r"(value)); \
__asm volatile ("ldp x8, x9, [sp], #16\n"); \
__asm volatile (#b " x12\n");

#define save() \
__asm volatile ( \
"stp x8, x9, [sp, #-16]!\n" \
"stp x6, x7, [sp, #-16]!\n" \
"stp x4, x5, [sp, #-16]!\n" \
"stp x2, x3, [sp, #-16]!\n" \
"stp x0, x1, [sp, #-16]!\n");

#define load() \
__asm volatile ( \
"ldp x0, x1, [sp], #16\n" \
"ldp x2, x3, [sp], #16\n" \
"ldp x4, x5, [sp], #16\n" \
"ldp x6, x7, [sp], #16\n" \
"ldp x8, x9, [sp], #16\n" );

#define link(b, value) \
__asm volatile ("stp x8, lr, [sp, #-16]!\n"); \
__asm volatile ("sub sp, sp, #16\n"); \
call(b, value); \
__asm volatile ("add sp, sp, #16\n"); \
__asm volatile ("ldp x8, lr, [sp], #16\n");

#define ret() __asm volatile ("ret\n");

__attribute__((__naked__))
static void hook_Objc_msgSend() {
    // Save parameters.
    save();
    
    __asm volatile ("mov x2, lr\n");
    __asm volatile ("mov x3, x4\n");
    
    // Call our before_objc_msgSend.
    call(blr, &hook_before_objc_msgSend);
    
    // Load parameters.
    load();
    
    // Call through to the original objc_msgSend.
    call(blr, orig_objc_msgSend);
    
    // Save original objc_msgSend return value.
    save();
    
    // Call our after_objc_msgSend.
    call(blr, &hook_after_objc_msgSend);
    
    // restore lr
    __asm volatile ("mov lr, x0\n");
    
    // Load original objc_msgSend return value.
    load();
    
    // return
    ret();
}

void ghAnalyerStart() {
    _call_record_enabled = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_key_create(&_thread_key, &release_thread_call_stack);
        rebind_symbols((struct rebinding[6]){
            {"objc_msgSend", (void *)hook_Objc_msgSend, (void **)&orig_objc_msgSend},
        }, 1);
    });
}

void ghAnalyerStop() {
    _call_record_enabled = false;
}

void ghSetMinTimeCallCost(uint64_t us) {
    _min_time_cost = us;
}

void ghSetMaxCallDepth(int depth) {
    _max_call_depth = depth;
}

void ghSetRecordMainThreadOnly(int only) {
    _record_main_thread_only = only;
}

GHCallRecord *ghGetCallRecords(int *num) {
    if (num) {
        *num = _ghRecordNum;
    }
    return _ghCallRecords;
}

void ghClearCallRecords() {
    if (_ghCallRecords) {
        free(_ghCallRecords);
        _ghCallRecords = NULL;
    }
    _ghRecordNum = 0;
}

#else

void ghAnalyerStart() {}
void ghAnalyerStop() {}
void ghSetMinTimeCallCost(uint64_t us) {}
void ghSetMaxCallDepth(int depth) {}
GHCallRecord *ghGetCallRecords(int *num) {
    if (num) {
        *num = 0;
    }
    return NULL;
}
void ghClearCallRecords() {}
void ghSetRecordMainThreadOnly(int only) {}

#endif

/**
 下面是Hook objc_msgSend的相关部分汇编源码
 .macro MethodTableLookup
 
 // push frame
 SignLR
 stp    fp, lr, [sp, #-16]!
 mov    fp, sp
 
 // save parameter registers: x0..x8, q0..q7
 sub    sp, sp, #(10*8 + 8*16)
 stp    q0, q1, [sp, #(0*16)]
 stp    q2, q3, [sp, #(2*16)]
 stp    q4, q5, [sp, #(4*16)]
 stp    q6, q7, [sp, #(6*16)]
 stp    x0, x1, [sp, #(8*16+0*8)]
 stp    x2, x3, [sp, #(8*16+2*8)]
 stp    x4, x5, [sp, #(8*16+4*8)]
 stp    x6, x7, [sp, #(8*16+6*8)]
 str    x8,     [sp, #(8*16+8*8)]
 
 // receiver and selector already in x0 and x1
 mov    x2, x16
 bl    __class_lookupMethodAndLoadCache3
 
 // IMP in x0
 mov    x17, x0
 
 // restore registers and return
 ldp    q0, q1, [sp, #(0*16)]
 ldp    q2, q3, [sp, #(2*16)]
 ldp    q4, q5, [sp, #(4*16)]
 ldp    q6, q7, [sp, #(6*16)]
 ldp    x0, x1, [sp, #(8*16+0*8)]
 ldp    x2, x3, [sp, #(8*16+2*8)]
 ldp    x4, x5, [sp, #(8*16+4*8)]
 ldp    x6, x7, [sp, #(8*16+6*8)]
 ldr    x8,     [sp, #(8*16+8*8)]
 
 mov    sp, fp
 ldp    fp, lr, [sp], #16
 AuthenticateLR
 
 .endmacro
 */
