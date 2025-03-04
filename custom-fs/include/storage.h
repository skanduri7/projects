#ifndef STORAGE_H
#define STORAGE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BLOCK_SIZE 4096   // 4KB blocks
#define MAX_BLOCKS 1024   // 4MB total storage

// Storage Management
void storage_init();                                // Initialize storage system
int storage_allocate_block();                      // Allocate a new block
void storage_free_block(int block_index);          // Free an allocated block
int storage_read_block(int block_index, char *buffer);  // Read data from a block
int storage_write_block(int block_index, const char *buffer); // Write data to a block
void storage_sync();                               // Persist storage data

#endif /* STORAGE_H */
