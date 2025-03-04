#ifndef PROCESS_H
#define PROCESS_H

#include "memory.h"
#include "scheduler.h"

Process create_process(int pid, int priority, int cpu_burst);
void execute_process(Process *p, PageTable *pt);
#endif
