#include "../include/storage.h"

static char storage[MAX_BLOCKS][BLOCK_SIZE]; // Storage array
static int block_usage[MAX_BLOCKS]; // Block allocation tracking

// Initialize storage system
void storage_init() {
    memset(storage, 0, sizeof(storage));
    memset(block_usage, 0, sizeof(block_usage));
}

// Allocate a new storage block
int storage_allocate_block() {
    for (int i = 0; i < MAX_BLOCKS; i++) {
        if (block_usage[i] == 0) {
            block_usage[i] = 1;
            return i; // Return allocated block index
        }
    }
    return -1; // No free block available
}

// Free an allocated block
void storage_free_block(int block_index) {
    if (block_index >= 0 && block_index < MAX_BLOCKS) {
        block_usage[block_index] = 0;
    }
}

// Read data from a block
int storage_read_block(int block_index, char *buffer) {
    if (block_index < 0 || block_index >= MAX_BLOCKS || !block_usage[block_index]) {
        return -1; // Invalid read
    }
    memcpy(buffer, storage[block_index], BLOCK_SIZE);
    return 0;
}

// Write data to a block
int storage_write_block(int block_index, const char *buffer) {
    if (block_index < 0 || block_index >= MAX_BLOCKS) {
        return -1; // Invalid write
    }
    memcpy(storage[block_index], buffer, BLOCK_SIZE);
    block_usage[block_index] = 1;
    return 0;
}

// Sync storage (Simulate writing to disk)
void storage_sync() {
    FILE *file = fopen("storage.bin", "wb");
    if (file) {
        fwrite(storage, sizeof(storage), 1, file);
        fclose(file);
    }
}
