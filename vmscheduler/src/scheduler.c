#include "../include/scheduler.h"
#include <stdio.h>

void enqueue(Queue *q, Process *p) {
    q->queue[q->rear++] = p;
}

Process *dequeue(Queue *q) {
    if (q->front == q->rear) return NULL;
    
    int highest_priority_index = q->front;
    for (int i = q->front + 1; i < q->rear; i++) {
        if (q->queue[i]->priority > q->queue[highest_priority_index]->priority) {
            highest_priority_index = i;
        }
    }
    
    Process *highest_priority_process = q->queue[highest_priority_index];
    
    // Shift remaining elements left
    for (int i = highest_priority_index; i < q->rear - 1; i++) {
        q->queue[i] = q->queue[i + 1];
    }
    q->rear--;
    
    return highest_priority_process;
}

void rev_priority(Process* p){
    p->priority = p->cpu_burst / 15;
}


void run_scheduler(Queue *q) {
    while (q->front != q->rear) {
        Process *p = dequeue(q);
        if (!p) continue;

        printf("Running process %d (Priority: %d)\n", p->pid, p->priority);
        p->cpu_burst -= 10;  // Simulate CPU execution

        rev_priority(p);

        if (p->cpu_burst > 0) {
            enqueue(q, p); // Put it back in the queue if it's not finished
        } else {
            p->state = TERMINATED;
            printf("Process %d finished execution\n", p->pid);
        }
    }
    printf("All processes have been scheduled and executed.\n");
}