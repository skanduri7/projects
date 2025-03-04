#include "../include/cache.h"

static CacheEntry cache[MAX_CACHE_SIZE]; // Array for cached files
static int cache_count = 0; // Number of cached files

// Initialize the cache
void cache_init() {
    for (int i = 0; i < MAX_CACHE_SIZE; i++) {
        cache[i].data = NULL;
    }
}

// Read from cache
char *cache_read(const char *path, size_t *size) {
    for (int i = 0; i < cache_count; i++) {
        if (strcmp(cache[i].path, path) == 0) {
            cache[i].last_access = time(NULL);
            *size = cache[i].size;
            return cache[i].data;
        }
    }
    return NULL; // Not found in cache
}

// Write to cache
void cache_write(const char *path, const char *data, size_t size) {
    if (cache_count < MAX_CACHE_SIZE) {
        // Add new entry
        strcpy(cache[cache_count].path, path);
        cache[cache_count].data = (char *)malloc(size);
        memcpy(cache[cache_count].data, data, size);
        cache[cache_count].size = size;
        cache[cache_count].last_access = time(NULL);
        cache_count++;
    } else {
        // LRU eviction: Find oldest entry
        int oldest = 0;
        for (int i = 1; i < MAX_CACHE_SIZE; i++) {
            if (cache[i].last_access < cache[oldest].last_access) {
                oldest = i;
            }
        }
        // Replace with new data
        free(cache[oldest].data);
        strcpy(cache[oldest].path, path);
        cache[oldest].data = (char *)malloc(size);
        memcpy(cache[oldest].data, data, size);
        cache[oldest].size = size;
        cache[oldest].last_access = time(NULL);
    }
}

// Evict file from cache
void cache_evict(const char *path) {
    for (int i = 0; i < cache_count; i++) {
        if (strcmp(cache[i].path, path) == 0) {
            free(cache[i].data);
            for (int j = i; j < cache_count - 1; j++) {
                cache[j] = cache[j + 1];
            }
            cache_count--;
            return;
        }
    }
}

// Cleanup cache before exit
void cache_cleanup() {
    for (int i = 0; i < cache_count; i++) {
        free(cache[i].data);
    }
    cache_count = 0;
}
