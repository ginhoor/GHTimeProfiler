//
//  GHStackFrame.m
//
//
//  Created by sjh on 2021/8/10.
//  https://www.jianshu.com/p/df5b08330afd
#import <mach/mach.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/types.h>
#include <limits.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>

#import "GHStackFrame.h"



#pragma -mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define gh_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define gh_THREAD_STATE ARM_THREAD_STATE64
#define gh_FRAME_POINTER __fp
#define gh_STACK_POINTER __sp
#define gh_INSTRUCTION_ADDRESS __pc

#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define gh_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define gh_THREAD_STATE ARM_THREAD_STATE
#define gh_FRAME_POINTER __r[7]
#define gh_STACK_POINTER __sp
#define gh_INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define gh_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define gh_THREAD_STATE x86_THREAD_STATE64
#define gh_FRAME_POINTER __rbp
#define gh_STACK_POINTER __rsp
#define gh_INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define gh_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define gh_THREAD_STATE x86_THREAD_STATE32
#define gh_FRAME_POINTER __ebp
#define gh_STACK_POINTER __esp
#define gh_INSTRUCTION_ADDRESS __eip

#endif

#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

#if defined(__LP64__)
#define TRACE_FMT         "%-4d%-31s 0x%016lx %s + %lu"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#define gh_NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define gh_NLIST struct nlist
#endif

typedef struct GHStackFrameEntry {
    const struct GHStackFrameEntry *const previous; //前一个栈帧的帧地址
    const uintptr_t return_address;                 //栈帧的函数返回地址，下一个指令地址
} GHStackFrameEntry;

static mach_port_t main_thread_id;

@implementation GHStackFrame

+ (void)load {
    main_thread_id = mach_thread_self();
}

#pragma -mark Implementation of interface

+ (NSString *)backtraceOfCurrentThread {
    return [self backtraceOfNSThread:[NSThread currentThread]];
}

+ (NSString *)backtraceOfMainThread {
    return [self backtraceOfNSThread:[NSThread mainThread]];
}

+ (NSString *)backtraceOfNSThread:(NSThread *)thread {
    return backtraceOfThread(gh_machThreadFromNSThread(thread));
}

+ (NSString *)backtraceOfThread:(thread_t)thread {
    return backtraceOfThread(thread);
}

+ (NSString *)backtraceOfAllThread {
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    const task_t this_task = mach_task_self();

    kern_return_t kr = task_threads(this_task, &threads, &thread_count);
    if (kr != KERN_SUCCESS) {
        return @"Fail to get information of all threads";
    }

    NSMutableString *resultString = [NSMutableString stringWithFormat:@"Call Backtrace of %u threads:\n", thread_count];
    for(int i = 0; i < thread_count; i++) {
        [resultString appendString:backtraceOfThread(threads[i])];
    }
    return [resultString copy];
}

+ (NSString *)backtraceOfFlutterUIThread {
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    const task_t this_task = mach_task_self();

    kern_return_t kr = task_threads(this_task, &threads, &thread_count);
    if(kr != KERN_SUCCESS) {
        // "Fail to get information of all threads";
    }
    thread_t flutterUIThread = 0;
    for (NSInteger i = 0; i < thread_count; i++) {
        char name[256];
        thread_t thread = threads[i];
        pthread_t pt = pthread_from_mach_thread_np(thread);
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
        }

        if (strstr(name, "io.flutter") && strstr(name, "ui")) {
            flutterUIThread = thread;
            break;
        }
    }

    if (flutterUIThread != 0) {
        return backtraceOfThread(flutterUIThread);
    }

    return @"";
}

+ (NSString *)backtraceOfAllFlutterThread {
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    const task_t this_task = mach_task_self();

    kern_return_t kr = task_threads(this_task, &threads, &thread_count);
    if(kr != KERN_SUCCESS) {
        // "Fail to get information of all threads";
    }
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < thread_count; i++) {
        char name[256];
        thread_t thread = threads[i];
        pthread_t pt = pthread_from_mach_thread_np(thread);
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
        }
        [result appendString:[NSString stringWithFormat:@"name: %s" ,name]];
        NSString *backstrace = backtraceOfThread(thread);
        [result appendString:backstrace];
        [result appendString:@"\n"];
    }
    return result;
}

#pragma -mark Get call backtrace of a mach_thread
NSString *backtraceOfThread(thread_t thread) {
    uintptr_t backtraceBuffer[50];
    int i = 0;
    NSMutableString *resultString = [[NSMutableString alloc] init];

    if (thread == main_thread_id) {
        [resultString appendFormat:@"Backtrace of Thread %u (main):\n", thread];
    } else {
        [resultString appendFormat:@"Backtrace of Thread %u:\n", thread];
    }

    _STRUCT_MCONTEXT machineContext;
    // 获得线程信息
    if (!gh_fillThreadStateIntoMachineContext(thread, &machineContext)) {
        return [NSString stringWithFormat:@"Fail to get information about thread: %u\n", thread];
    }

    // 获得指令地址，当前调用的函数地址，PC。
    const uintptr_t instructionAddress = gh_mach_instructionAddress(&machineContext);
    backtraceBuffer[i] = instructionAddress;
    ++i;

    // 获得函数调用返回地址，当前指令执行后的下一个指令地址。
    uintptr_t linkRegister = gh_mach_linkRegister(&machineContext);
    if (linkRegister) {
        backtraceBuffer[i] = linkRegister;
        i++;
    }

    if (instructionAddress == 0) {
        return @"Fail to get instruction address\n";
    }

    GHStackFrameEntry frame = {0};
    // 获取帧地址，获得当前栈帧的栈底地址。
    const uintptr_t framePtr = gh_mach_framePointer(&machineContext);
    // read  16 byte start with fp, 8byte ->lr ,8byte -> last fp
    if (framePtr == 0 ||
        gh_mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
        return @"Fail to get frame pointer\n";
    }

    // 向前遍历最近50个栈帧的函数返回地址
    for (; i < 50; i++) {
        // 栈帧的函数返回地址，下一个调用指令地址
        backtraceBuffer[i] = frame.return_address;
        if (backtraceBuffer[i] == 0 ||
            frame.previous == 0 ||
            gh_mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
            break;
        }
    }

    // 符号化
    int backtraceLength = i;
    Dl_info symbolicated[backtraceLength];
    gh_symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0);
    for (int i = 0; i < backtraceLength; ++i) {
        [resultString appendFormat:@"%@", gh_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
    }
    [resultString appendFormat:@"\n"];
    return [resultString copy];
}


#pragma -mark Convert NSThread to Mach thread
thread_t gh_machThreadFromNSThread(NSThread *nsthread) {
    char name[256];
    mach_msg_type_number_t count;
    thread_act_array_t list;
    //查询当前所有线程
    task_threads(mach_task_self(), &list, &count);

    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSString *originName = [nsthread name];
    [nsthread setName:[NSString stringWithFormat:@"%f", currentTimestamp]];

    if ([nsthread isMainThread]) {
        return (thread_t)main_thread_id;
    }

    for (int i = 0; i < count; ++i) {
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if ([nsthread isMainThread]) {
            if (list[i] == main_thread_id) {
                return list[i];
            }
        }
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, [nsthread name].UTF8String)) {
                [nsthread setName:originName];
                return list[i];
            }
        }
    }

    [nsthread setName:originName];
    return mach_thread_self();
}

#pragma -mark GenerateBacbsrackEnrty

/// 最后路径入口
const char* gh_lastPathEntry(const char* const path) {
    if (path == NULL) {
        return NULL;
    }
    // Remember short name of process for later logging
    // C 库函数 char *strrchr(const char *str, int c) 在参数 str 所指向的字符串中搜索最后一次出现字符 c（一个无符号字符）的位置。
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

/// 调用栈的回溯入口
NSString* gh_logBacktraceEntry(const int entryNum,
                               const uintptr_t memoryAddress,
                               const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    // image 文件名
    const char* imageName = gh_lastPathEntry(dlInfo->dli_fname);
    if (imageName == NULL) {
        // 将 文件基址 打印到 faddrBuff 中
        // int sprintf ( char * str, const char * format, ... );
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo->dli_fbase);
        imageName = faddrBuff;
    }

    uintptr_t offset = memoryAddress - (uintptr_t)dlInfo->dli_saddr;
    // 符号名
    const char* sname = dlInfo->dli_sname;
    if (sname == NULL) {
        sprintf(saddrBuff, POINTER_SHORT_FMT, (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = memoryAddress - (uintptr_t)dlInfo->dli_fbase;
    }
    return [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,imageName, (uintptr_t)memoryAddress, sname, offset];
}

#pragma -mark HandleMachineContext
/// 获得线程状态
bool gh_fillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext) {
    mach_msg_type_number_t state_count = gh_THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread, gh_THREAD_STATE, (thread_state_t)&machineContext->__ss, &state_count);
    return (kr == KERN_SUCCESS);
}

/**
 栈帧
 每一次函数的调用，都会在调用栈(call stack)上维护一个独立的栈帧(stack frame)。
 每个独立的栈帧一般包括：
 1、函数的返回地址和参数。
 2、临时变量：包括函数的非静态局部变量以及编译器自动生成的其他临时变量。
 3、函数调用的上下文
 栈是从高地址向低地址延伸，一个函数的栈帧用 ebp 和 esp 这两个寄存器来划定范围。
 ebp 指向当前的栈帧的底部，esp 始终指向栈帧的顶部。
 ebp 寄存器又被称为帧指针(Frame Pointer);
 esp 寄存器又被称为栈指针(Stack Pointer);
 */

/// 帧指针
uintptr_t gh_mach_framePointer(mcontext_t const machineContext) {
    return machineContext->__ss.gh_FRAME_POINTER;
}

/// 栈指针
uintptr_t gh_mach_stackPointer(mcontext_t const machineContext) {
    return machineContext->__ss.gh_STACK_POINTER;
}

/// 指令地址
uintptr_t gh_mach_instructionAddress(mcontext_t const machineContext) {
    return machineContext->__ss.gh_INSTRUCTION_ADDRESS;
}

/// 函数调用的返回地址，链接寄存器，用于保存函数调用的返回地址。
uintptr_t gh_mach_linkRegister(mcontext_t const machineContext) {
#if defined(__i386__) || defined(__x86_64__)
    return 0;
#else
    return machineContext->__ss.__lr;
#endif
}

/**
 kern_return_t vm_read_overwrite(
 vm_map_t target_task,       // task任务
 vm_address_t address,      // 栈帧指针FP
 vm_size_t size,                   // 结构体大小 sizeof（StackFrameEntry）
 vm_address_t data,            // 结构体指针 StackFrameEntry
 vm_size_t *outsize             // 赋值大小
 );
 */
/// 栈帧结构体
kern_return_t gh_mach_copyMem(const void *const src, void *const dst, const size_t numBytes) {
    vm_size_t bytesCopied = 0;
    // read  16 byte start with fp, 8byte ->lr ,8byte -> last fp
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

#pragma mark - 符号化
/// 符号化
void gh_symbolicate(const uintptr_t* const backtraceBuffer,
                    Dl_info* const symbolsBuffer,
                    const int numEntries,
                    const int skippedEntries) {
    int i = 0;
    if (skippedEntries != 0 && i < numEntries) {
        // pc寄存器，不需要考虑内存对齐的情况
        gh_dladdr(backtraceBuffer[i], &symbolsBuffer[i]);
        i++;
    }

    for (; i < numEntries; i++) {
        gh_dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(backtraceBuffer[i]), &symbolsBuffer[i]);
    }
}

/// 获得某个地址的符号信息
bool gh_dladdr(const uintptr_t memoryAddress, Dl_info* const info) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;

    // 查询image索引
    const uint32_t idx = gh_imageIndexContainingAddress(memoryAddress);
    if (idx == UINT_MAX) {
        return false;
    }
    const struct mach_header* header = _dyld_get_image_header(idx);
    // ASLR 随机内存地址偏移量
    const uintptr_t imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
    // 偏移前地址
    const uintptr_t VMAddress = memoryAddress - imageVMAddrSlide;
    // 偏移前基址 = __LINKEDIT.VM_Address - __LINK.File_Offset + silde的改变值
    // 获得image中 link_edit_segment偏移前的基址。
    const uintptr_t linkEditSegmentBase = gh_linkEditSegmentBaseOfImageIndex(idx) + imageVMAddrSlide;
    if (linkEditSegmentBase == 0) {
        return false;
    }

    // image模块名称
    info->dli_fname = _dyld_get_image_name(idx);
    // image的header地址
    info->dli_fbase = (void*)header;

    // Find symbol tables and get whichever symbol is closest to the address.
    // 搜索符号表，获得最接近地址的符号。
    const gh_NLIST* bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = gh_firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return false;
    }
    for (uint32_t cmdIdx = 0; cmdIdx < header->ncmds; cmdIdx++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        // 查找symbol_table类型的 load command
        // LC_SEGMENT_64 里面没有包含里面的 sections 信息，需要配合 LC_SYMTAB 来解析 symbol table 和 string table。
        if (loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command* symtabCmd = (struct symtab_command*)cmdPtr;
            /**
             struct nlist {
             union {
             uint32_t n_strx;  //符号名在字符串表中的偏移量
             } n_un;
             uint8_t n_type;
             uint8_t n_sect;
             int16_t n_desc;
             uint32_t n_value;    //符号在内存中的地址，类似于函数虚拟地址指针
             };
             */
            // 符号表地址，一块连续的地址来存储mach-o所有的函数符号，存储结构为nlist
            // symoff：符号表偏移地址，存储在LC_SYMTAB的cmd中，symoff为相对基址的偏移量
            // symbolTab_addr = base_addr + symoff
            const gh_NLIST* symbolTable = (gh_NLIST*)(linkEditSegmentBase + symtabCmd->symoff);
            // 符号表地址，一块连续的地址来存储mach-o所有的字符串指针
            // stroff：符号表偏移地址，存储在LC_SYMTAB的cmd中，stroff为相对基址的偏移量。
            // strTab_addr = base_addr + stroff
            const uintptr_t stringTable = linkEditSegmentBase + symtabCmd->stroff;
            // 遍历符号表中的符号
            for (uint32_t symIdx = 0; symIdx < symtabCmd->nsyms; symIdx++) {
                // If n_value is 0, the symbol refers to an external object.
                if (symbolTable[symIdx].n_value != 0) {
                    // 符号基址
                    uintptr_t symbolBase = symbolTable[symIdx].n_value;
                    // 偏移后地址与符号基址的距离
                    uintptr_t currentDistance = VMAddress - symbolBase;
                    if (currentDistance >= 0 && currentDistance <= bestDistance) {
                        bestMatch = symbolTable + symIdx;
                        bestDistance = currentDistance;
                    }
                }
            }
            if (bestMatch != NULL) {
                // 最近符号的地址（偏移后）
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide);
                // 符号的名字，在字符串表中查询
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                if (*info->dli_sname == '_') {
                    info->dli_sname++;
                }
                // This happens if all symbols have been stripped.
                if (info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return true;
}

/// 获取 Mach-O -> mach_header -> segments command -> image address
/// mach_header 中保存了文件的 magic、cputype 、文件大小等一些基本信息。
/// 获取header中第一个Load Command
uintptr_t gh_firstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0;  // Header is corrupt
    }
}

/// segment_command 结构体中保存着结构体的基本信息，包括在文件中偏移地址,占用文件大小，虚拟地址，虚拟地址大小，用于解析 macho 文件，像一个索引一样，真正的指向的数据在下一部分的 data 部分。
/// 通过image的index获得 存储符号表信息的segment VM的基址。
uintptr_t gh_linkEditSegmentBaseOfImageIndex(const uint32_t idx) {
    // 遍历加载的image，通过idx获得对应镜像。
    const struct mach_header* header = _dyld_get_image_header(idx);
    // Look for a segment command and return the file image address.
    // 查找第一个 load command
    uintptr_t cmdPtr = gh_firstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return 0;
    }
    // 遍历mach_header中的 load command
    for (uint32_t i = 0;i < header->ncmds; i++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        // 只处理 load command类型是segment的 segment command，这里保存代码段。
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command* segmentCmd = (struct segment_command*)cmdPtr;
            // 动态链接器使用的符号或字符串。
            if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                // 返回地址
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        } else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64* segmentCmd = (struct segment_command_64*)cmdPtr;
            if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        //继续遍历
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}

/// 通过偏移后地址来反查 image的index
uint32_t gh_imageIndexContainingAddress(const uintptr_t memoryAddress) {
    // 加载的image模块总数
    const uint32_t imageCount = _dyld_image_count();
    const struct mach_header* header = 0;
    // 遍历镜像
    for (uint32_t imgIdx = 0; imgIdx < imageCount; imgIdx++) {
        header = _dyld_get_image_header(imgIdx);
        if (header != NULL) {
            // 模块偏移前基址（0x100000000） = 模块偏移后的基地址（0x100758000）- ASLR偏移量（0x0000000000758000）
            uintptr_t VMAddress = memoryAddress - (uintptr_t)_dyld_get_image_vmaddr_slide(imgIdx);
            uintptr_t cmdPtr = gh_firstCmdAfterHeader(header);
            if (cmdPtr == 0) {
                continue;
            }
            for (uint32_t cmdIdx = 0; cmdIdx < header->ncmds; cmdIdx++) {
                const struct load_command* loadCmd = (struct load_command*)cmdPtr;
                if (loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
                    // segment command的内存分配区域 包含目标地址。
                    if (VMAddress >= segCmd->vmaddr &&
                        VMAddress < segCmd->vmaddr + segCmd->vmsize) {
                        return imgIdx;
                    }
                }
                else if (loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64* segCmd = (struct segment_command_64*)cmdPtr;
                    if (VMAddress >= segCmd->vmaddr &&
                        VMAddress < segCmd->vmaddr + segCmd->vmsize) {
                        return imgIdx;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }
    return UINT_MAX;
}


@end
