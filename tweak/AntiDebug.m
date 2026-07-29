#import "AntiDebug.h"
#import <sys/sysctl.h>
#import <unistd.h>

@implementation AntiDebug

+ (void)applyAntiDebug {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (1) {
            if ([self isDebuggerAttached]) {
                // Tự sát bằng cách crash ứng dụng để chống dịch ngược
                #if defined(__arm64__) || defined(__aarch64__)
                asm volatile(".inst 0xd4200020"); // BRK #1 (arm64 crash)
                #else
                __builtin_trap();
                #endif
                exit(0);
            }
            sleep(3); // Kiểm tra định kỳ mỗi 3 giây
        }
    });
}

+ (BOOL)isDebuggerAttached {
    // Kiểm tra sysctl của chính tiến trình (getpid()).
    // Đây là phương pháp chính thống, an toàn 100% trong Sandbox của iOS và không bao giờ bị văng/vi phạm quyền.
    int name[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    info.kp_proc.p_flag = 0;
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        return NO;
    }
    
    // Nếu cờ P_TRACED được bật, tức là lldb/gdb đang đính kèm vào app
    if ((info.kp_proc.p_flag & P_TRACED) != 0) {
        return YES;
    }
    
    return NO;
}

@end
