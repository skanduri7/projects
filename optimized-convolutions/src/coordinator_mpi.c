#include <mpi.h>

#include "coordinator.h"

#define READY 0
#define NEW_TASK 1
#define TERMINATE -1

int main(int argc, char *argv[]) {
  if (argc < 2) {
    printf("Error: not enough arguments\n");
    printf("Usage: %s [path_to_task_list]\n", argv[0]);
    return -1;
  }

  // TODO: implement Open MPI coordinator
  int num_tasks;
  task_t** tasks;
  task_t done = {NULL};
  task_t curr_task;
  curr_task.path = NULL;

  if (read_tasks(argv[1], &num_tasks, &tasks)) {
      printf("Error reading task list from %s\n", argv[1]);
      return -1;
  }

  //printf("%d\n", num_tasks);

  MPI_Init(&argc, &argv);

  int r;
  int s;

  MPI_Comm_rank(MPI_COMM_WORLD, &r);
  MPI_Comm_size(MPI_COMM_WORLD, &s);

  MPI_Datatype task_type;
  int block_lens[1] = {1};
  MPI_Aint offsets[1] = {offsetof(task_t, path)};
  MPI_Datatype types[1] = {MPI_CHAR};

  MPI_Type_create_struct(1, block_lens, offsets, types, &task_type);
  MPI_Type_commit(&task_type);



  //printf("%d %d\n", s, r);


  if (r == 0) {

      int ind = 0;

      while(ind < num_tasks) {

          int free_process;

          //printf("hi");

          MPI_Recv(&free_process, 1, MPI_INT, MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, MPI_STATUS_IGNORE);

          printf("%d\n", ind);
          MPI_Send(tasks[ind], 1, task_type, free_process, NEW_TASK, MPI_COMM_WORLD);
          ind++;
      }

      for (int i = 1; i < s; i++)
          MPI_Send(&done, 1, task_type, i, TERMINATE, MPI_COMM_WORLD);
  } else {

      while (true) {
          //printf("hi");
          MPI_Send(&r, 1, MPI_INT, 0, READY, MPI_COMM_WORLD);
          MPI_Status status;
          MPI_Recv(&curr_task, 1, task_type, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

          if (status.MPI_TAG == TERMINATE) break;
          
          if (execute_task(&curr_task)) {
              printf("Task %d failed\n", r);
              MPI_Abort(MPI_COMM_WORLD, 1);
          }
          free(curr_task.path);
      }
  }

  MPI_Finalize();
  return 0;
}
