#include "../include/process.h"
#include <stdio.h>

Process create_process(int pid, int priority, int cpu_burst) {
    Process p = {pid, priority, READY, cpu_burst, {0, 1, 2, 3}};
    return p;
}

void execute_process(Process *p, PageTable *pt) {
    printf("Executing process %d\n", p->pid);
}
