#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "fishhook.h"
#import "GHCPUObserver.h"
#import "GHObjcMsgSendHook.h"
#import "GHRunloopObserver.h"
#import "GhStackFrame.h"
#import "GHTimeProfiler.h"
#import "GHTimeProfilerHeader.h"
#import "GHTimeProfilerLog.h"
#import "GHTimeProfilerLogManager.h"

FOUNDATION_EXPORT double GHTimeProfilerVersionNumber;
FOUNDATION_EXPORT const unsigned char GHTimeProfilerVersionString[];

