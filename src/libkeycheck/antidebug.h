#ifndef ANTIDEBUG_H
#define ANTIDEBUG_H

int antidebug_check_ptrace(void);
int antidebug_check_proc_self(void);
int antidebug_check_tracer(void);
int antidebug_check_integrity(const char *self_path);
void antidebug_run_checks(void);

#endif
