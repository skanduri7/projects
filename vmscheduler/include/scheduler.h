#ifndef SCHEDULER_H
#define SCHEDULER_H

#define MAX_PROCESSES 10

typedef enum { READY, RUNNING, WAITING, TERMINATED } ProcessState;

typedef struct {
    int pid;
    int priority;
    ProcessState state;
    int cpu_burst;
    int memory_pages[4];
} Process;

typedef struct {
    Process *queue[MAX_PROCESSES];
    int front, rear;
} Queue;

void enqueue(Queue *q, Process *p);
Process *dequeue(Queue *q);
void run_scheduler();
#endif
