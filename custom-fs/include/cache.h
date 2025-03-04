#ifndef CACHE_H
#define CACHE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_CACHE_SIZE 10    // Maximum number of cached files

typedef struct {
    char path[256];          // File path
    char *data;              // Cached file contents
    size_t size;             // File size
    time_t last_access;      // Last accessed timestamp
} CacheEntry;

// Cache Operations
void cache_init();                              // Initialize cache
char *cache_read(const char *path, size_t *size); // Read from cache
void cache_write(const char *path, const char *data, size_t size); // Write to cache
void cache_evict(const char *path);             // Remove specific file from cache
void cache_cleanup();                           // Cleanup cache on exit

#endif /* CACHE_H */
