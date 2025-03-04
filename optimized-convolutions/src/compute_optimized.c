#include <omp.h>
#include <x86intrin.h>

#include "compute.h"

void print_matrix1(matrix_t *m) {
    printf("\n%d\n", m->rows);
    printf("%d\n", m->cols);

    for (int i = 0; i < m->rows; i++) {
        for(int j = 0; j < m->cols; j++){
            printf("%d ", m->data[m->cols * i + j]);
        }
        printf("\n");
    }
}

// Computes the convolution of two matrices
int convolve(matrix_t *a_matrix, matrix_t *b_matrix, matrix_t **output_matrix) {
  // TODO: convolve matrix a and matrix b, and store the resulting matrix in
  // output_matrix
  matrix_t* c = malloc(sizeof(matrix_t));
  if (c == NULL) return -1;
  c->rows = a_matrix->rows - b_matrix->rows + 1;
  c->cols = a_matrix->cols - b_matrix->cols + 1;
  c->data = calloc(c->rows * c->cols, sizeof(int));
  if (c->data == NULL) {
      free(c);
      return -1;
  }

  matrix_t* b_f = malloc(sizeof(matrix_t));
  if (b_f == NULL) {
      free(c->data);
      free(c);
      return -1;
  }
  b_f->rows = b_matrix->rows;
  b_f->cols = b_matrix->cols;
  b_f->data = malloc(sizeof(int) * b_f->rows * b_f->cols);
  if (b_f->data == NULL) {
      free(c->data);
      free(c);
      free(b_f);
      return -1;
  }

  __m256i s = _mm256_set_epi32(0, 1, 2, 3, 4, 5, 6, 7);

  int b_size = b_matrix->rows * b_matrix->cols;
  //print_matrix1(b_f);

  //cd cdcdcdcprint_matrix1(b_matrix);
  //print_matrix1(b_f);
  //printf("hi");

  for (int i = 0; i <= b_size - 8; i += 8) {
    __m256i v = _mm256_loadu_si256((__m256i*) (b_matrix->data + i));

    __m256i s_v = _mm256_permutevar8x32_epi32(v, s);

    _mm256_storeu_si256((__m256i*)(b_f->data + b_size - 8 - i), s_v);
  }

  for (int i = 8 * (b_size / 8); i < b_size; i++){
    //printf("hi");
    b_f->data[b_size - i - 1] = b_matrix->data[i];
    //printf("%d\n", b_f->data[i]);
  }

  //memcpy(b_f->data + 8 * (b_size / 8), )

  //print_matrix1(a_matrix);
  //print_matrix1(b_matrix);
  //printf("%d\n", b_matrix->cols);
  int b_cols = (int) b_matrix->cols;

  #pragma omp parallel for collapse(2) schedule(static)
  for (unsigned int i = 0; i <= a_matrix->rows - b_matrix->rows; i++) {

      for(unsigned int j = 0; j <= a_matrix->cols - b_matrix->cols; j++) {
        
        __m256i total = _mm256_setzero_si256();
        int total_tail = 0;
        
        for (unsigned int k = 0; k < b_matrix->rows; k++) {
            for (int l = 0; l <= b_cols - 8; l += 8) {
                __m256i b = _mm256_loadu_si256((__m256i*) &(b_f->data[k * b_f->cols + l]));
                __m256i a = _mm256_loadu_si256((__m256i*) &(a_matrix->data[(k + i) * a_matrix->cols + l + j]));

                total = _mm256_add_epi32(total, _mm256_mullo_epi32(a, b));
            }
            
            for (unsigned int l = 8*(b_matrix->cols / 8); l < b_matrix->cols; l++) {
                total_tail += b_f->data[k * b_f->cols + l] * a_matrix->data[(k + i) * a_matrix->cols + l + j];
            }


        }

        //printf("hi");
        int result[8];
        _mm256_storeu_si256((__m256i*) &result, total);

        c->data[i * c->cols + j] = total_tail;
        for (int z = 0; z < 8; z++) c->data[i * c->cols + j] += result[z];



      }
  }


  *output_matrix = c;
  //print_matrix1(c);
  free(b_f->data);
  free(b_f);

  return 0;
}

// Executes a task
int execute_task(task_t *task) {
  matrix_t *a_matrix, *b_matrix, *output_matrix;

  char *a_matrix_path = get_a_matrix_path(task);
  if (read_matrix(a_matrix_path, &a_matrix)) {
    printf("Error reading matrix from %s\n", a_matrix_path);
    return -1;
  }
  free(a_matrix_path);

  char *b_matrix_path = get_b_matrix_path(task);
  if (read_matrix(b_matrix_path, &b_matrix)) {
    printf("Error reading matrix from %s\n", b_matrix_path);
    return -1;
  }
  free(b_matrix_path);

  if (convolve(a_matrix, b_matrix, &output_matrix)) {
    printf("convolve returned a non-zero integer\n");
    return -1;
  }

  char *output_matrix_path = get_output_matrix_path(task);
  if (write_matrix(output_matrix_path, output_matrix)) {
    printf("Error writing matrix to %s\n", output_matrix_path);
    return -1;
  }
  free(output_matrix_path);

  free(a_matrix->data);
  free(b_matrix->data);
  free(output_matrix->data);
  free(a_matrix);
  free(b_matrix);
  free(output_matrix);
  return 0;
}
