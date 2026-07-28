#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <signal.h>

#ifdef __APPLE__
#include <sys/sysctl.h>
#include <mach/mach.h>
#endif

void antidebug_run_checks(void)
{
    pid_t pid = fork();
    if (pid == -1) {
        exit(-1);
    }
    if (pid == 0) {
        pid_t parent = getppid();
        if (ptrace(PTRACE_ATTACH, parent, NULL, NULL) == 0) {
            ptrace(PTRACE_DETACH, parent, NULL, NULL);
            exit(0);
        }
        _exit(1);
    }
    int status;
    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
        exit(-1);
    }
}

int antidebug_check_integrity(const char *self_path)
{
    FILE *f = fopen(self_path, "rb");
    if (!f) return 0;

    unsigned char buf[4096];
    size_t n;
    unsigned int hash = 0x811c9dc5u;

    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        for (size_t i = 0; i < n; i++) {
            hash ^= buf[i];
            hash *= 0x01000193u;
        }
    }
    fclose(f);

    static unsigned int stored_hash = 0;
    if (stored_hash == 0) {
        stored_hash = hash;
        return 1;
    }
    return hash == stored_hash;
}

static void signal_handler(int sig)
{
    _exit(-1);
}

__attribute__((constructor))
static void init_antidebug(void)
{
    signal(SIGTRAP, signal_handler);
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    antidebug_run_checks();
}
