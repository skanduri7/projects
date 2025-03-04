#include "../include/scheduler.h"
#include "../include/memory.h"
#include "../include/process.h"
#include <stdio.h>

int main() {
    PageTable pt = {0};
    Queue scheduler = {0};

    Process p1 = create_process(1, 0, 20);
    Process p2 = create_process(2, 1, 30);
    Process p3 = create_process(3, 2, 10);

    enqueue(&scheduler, &p1);
    enqueue(&scheduler, &p2);
    enqueue(&scheduler, &p3);

    run_scheduler();
    return 0;
}