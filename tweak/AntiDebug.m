#import "AntiDebug.h"
#import <sys/sysctl.h>
#import <unistd.h>
#import <dlfcn.h>
#import <sys/syscall.h>
#import <mach/mach.h>
#import <mach/task.h>

#define PT_DENY_ATTACH 31

typedef int (*ptrace_ptr_t)(int request, pid_t pid, caddr_t addr, int data);

@implementation AntiDebug

+ (void)applyAntiDebug {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (1) {
            if ([self isDebuggerAttached]) {
                // Tự sát bằng cách sinh ra lỗi SIGTRAP hoặc crash để chống dịch ngược
                #if defined(__arm64__) || defined(__aarch64__)
                asm volatile(".inst 0xd4200020"); // BRK #1 (arm64 crash)
                #else
                __builtin_trap();
                #endif
                exit(0);
            }
            [self denyAttach];
            sleep(2); // Kiểm tra lại sau mỗi 2 giây
        }
    });
}

+ (void)denyAttach {
    // 1. Gọi ptrace bằng syscall trực tiếp để tránh bị hook hàm ptrace thường
    #ifdef SYS_ptrace
    syscall(SYS_ptrace, PT_DENY_ATTACH, 0, 0, 0);
    #else
    syscall(26, PT_DENY_ATTACH, 0, 0, 0); // 26 là mã syscall của ptrace trên iOS
    #endif

    // 2. Gọi ptrace động qua dlsym
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    ptrace_ptr_t ptrace_ptr = (ptrace_ptr_t)dlsym(handle, "ptrace");
    if (ptrace_ptr) {
        ptrace_ptr(PT_DENY_ATTACH, 0, 0, 0);
    }
    dlclose(handle);
}

+ (BOOL)isDebuggerAttached {
    // 1. Kiểm tra sysctl
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
    
    if ((info.kp_proc.p_flag & P_TRACED) != 0) {
        return YES;
    }
    
    // 2. Kiểm tra Exception Port (nếu debugger bắt các exception)
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t kr = task_get_special_port(mach_task_self(), TASK_EXCEPTION_PORT, &port);
    if (kr == KERN_SUCCESS && MACH_PORT_VALID(port)) {
        return YES;
    }
    
    // 3. Kiểm tra parent process ID (nếu được fork từ debugger)
    // Trên iOS bình thường parent là launchd (PID 1), nếu PPID > 1 và không phải là các dịch vụ hệ thống phổ biến thì đáng ngờ
    pid_t ppid = getppid();
    if (ppid > 1) {
        // Lấy tên PPID
        char ppid_name[256];
        int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, ppid};
        struct kinfo_proc parent_info;
        size_t len = sizeof(parent_info);
        if (sysctl(mib, 4, &parent_info, &len, NULL, 0) == 0) {
            NSString *parentName = [NSString stringWithUTF8String:parent_info.kp_proc.p_comm];
            if ([parentName containsString:@"debugserver"] || 
                [parentName containsString:@"lldb"] || 
                [parentName containsString:@"gdb"]) {
                return YES;
            }
        }
    }
    
    // 4. Kiểm tra xem có đang bị debug bởi checking isatty
    if (isatty(1)) {
        return YES;
    }
    
    return NO;
}

@end
