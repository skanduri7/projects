#include "compute.h"

// Computes the convolution of two matrices
void print_matrix1(matrix_t *m){
    printf("\n%d\n", m->rows);
    printf("%d\n", m->cols);
    for (int i = 0; i < m->rows; i++) {
        for(int j = 0; j < m->cols; j++) {
            printf("%d ", m->data[m->rows * i + j]);
        }
        printf("\n");
    }

}
int convolve(matrix_t *a_matrix, matrix_t *b_matrix, matrix_t **output_matrix) {
    matrix_t* c = malloc(sizeof(matrix_t));
    if (c == NULL) return -1;
    c->rows = a_matrix->rows - b_matrix->rows + 1;
    c->cols = a_matrix->cols - b_matrix->cols + 1;
    c->data = malloc(sizeof(int) * c->rows * c->cols);
    if(c->data == NULL) {
        free(c);
        return -1;
    }
    //print_matrix1(a_matrix);
    //print_matrix1(b_matrix);

    matrix_t* b_f = malloc(sizeof(matrix_t)); // swap i with rows*cols - i - 1
    if (b_f == NULL) return -1;
    b_f->rows = b_matrix->rows;
    b_f->cols = b_matrix->cols;
    b_f->data = malloc(sizeof(int) * b_f->rows * b_f->cols);
    if (b_f->data == NULL) {
        free(b_f);
        return -1;
    }

    
    for (unsigned int i = 0; i < b_matrix->rows * b_matrix->cols; i++) {
        //printf(". %d", b_matrix->data[i]);
        b_f->data[i] = b_matrix->data[(b_matrix->rows * b_matrix->cols) - i - 1];
    }

    //print_matrix1(b_f);
    int c_i = 0;

    for (unsigned int i = 0; i <= a_matrix->rows - b_matrix->rows; i++){
        for (unsigned int j = 0; j <= a_matrix->cols - b_matrix->cols; j++){
            // we start computing the product from a(i, j)
            // top left (i, j) top right = (i + b_row - 1)
            // bot left (i, j + b_cols - 1) bot right (i + b_row - 1, j + b_cols - 1)
            int32_t total = 0;
            for (unsigned int k = i, m = 0; k < i + b_matrix->rows; k++, m++) {
                for (unsigned int l = j, n = 0; l < j + b_matrix->cols; l++, n++) {
                    //printf("b_f: %d, a: %d .", b_f->data[m * b_matrix->rows + n], a_matrix->data[k * a_matrix->rows + l]);
                    //printf("b_f index: %d, a index: %d\n", m * b_matrix->cols + n, k * a_matrix->cols + l);
                    total += b_f->data[m * b_matrix->cols + n] * a_matrix->data[k * a_matrix->cols + l];
                }
            }
            //printf("%d ", sum);

            c->data[c_i] = total;
            c_i++;

        }
    }
    //printf("\n");
    //print_matrix1(c);
    *output_matrix = c;
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
