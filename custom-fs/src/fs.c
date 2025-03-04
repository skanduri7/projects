#define FUSE_USE_VERSION 26  // Using FUSE 2.x
#include <fuse.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include "../include/storage.h"
#include "../include/metadata.h"
#include "../include/cache.h"

// Initialize file system
static void *fs_init(struct fuse_conn_info *conn) {
    storage_init();
    metadata_init();
    cache_init();
    return NULL;
}

static int fs_access(const char *path, int mask) {
    if (strcmp(path, "/") == 0) {
        return 0; // Allow access to root
    }

    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT; // No such file or directory
    }

    return 0; // Allow access
}


// Get file attributes (stat)
static int fs_getattr(const char *path, struct stat *stbuf) {
    memset(stbuf, 0, sizeof(struct stat));

    // Handle root directory "/"
    if (strcmp(path, "/") == 0) {
        stbuf->st_mode = S_IFDIR | 0755;
        stbuf->st_nlink = 2;
        return 0;
    }

    // Check for file metadata
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT; // File not found
    }

    if (file->is_directory) {
        stbuf->st_mode = S_IFDIR | 0755;
        stbuf->st_nlink = 2;
    } else {
        stbuf->st_mode = S_IFREG | 0666;
        stbuf->st_nlink = 1;
        stbuf->st_size = file->size;
    }

    return 0;
}


// Read directory contents
static int fs_readdir(const char *path, void *buf, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info *fi) {
    (void) offset;
    (void) fi;

    printf("fs_readdir called for path: %s\n", path);

    // Always add "." (current directory) and ".." (parent directory)
    filler(buf, ".", NULL, 0);
    filler(buf, "..", NULL, 0);

    // Retrieve stored file names
    char file_list[MAX_FILES][NAME_LEN];
    int file_count = metadata_list_files(file_list);

    printf("fs_readdir: found %d files\n", file_count);

    for (int i = 0; i < file_count; i++) {
        printf("fs_readdir: adding file: %s\n", file_list[i]);
        filler(buf, file_list[i], NULL, 0);
    }

    return 0; // Ensure we return success
}

// Create a file
static int fs_mknod(const char *path, mode_t mode, dev_t dev) {
    printf("fs_mknod: Creating file %s with mode %o\n", path, mode);
    return metadata_create_file(path, 0);
}


static int fs_create(const char *path, mode_t mode, struct fuse_file_info *fi) {
    (void) fi;
    printf("fs_create: Creating file %s with mode %o\n", path, mode);
    return fs_mknod(path, mode, 0);  // Redirect to fs_mknod
}


// Create a directory
static int fs_mkdir(const char *path, mode_t mode) {
    (void) mode;
    if (metadata_create_file(path, 1) == -1) {
        return -ENOSPC; // No space left
    }
    return 0;
}

// Delete a file
static int fs_unlink(const char *path) {
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT;
    }
    storage_free_block(file->block_index);
    cache_evict(path);
    return metadata_delete_file(path);
}

// Delete a directory
static int fs_rmdir(const char *path) {
    return fs_unlink(path); // Same logic as deleting a file
}

// Open a file
static int fs_open(const char *path, struct fuse_file_info *fi) {
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT;
    }
    return 0;
}

// Read from a file
static int fs_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
    (void) fi;
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT;
    }
    
    // Check cache first
    size_t cached_size;
    char *cached_data = cache_read(path, &cached_size);
    if (cached_data) {
        memcpy(buf, cached_data + offset, size);
        return size;
    }

    // Read from storage
    char block_data[BLOCK_SIZE];
    if (storage_read_block(file->block_index, block_data) == -1) {
        return -EIO;
    }
    memcpy(buf, block_data + offset, size);

    // Cache the file
    cache_write(path, block_data, file->size);
    
    return size;
}

// Write to a file
static int fs_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
    (void) fi;
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT;
    }

    if (file->block_index == -1) {
        file->block_index = storage_allocate_block();
        if (file->block_index == -1) {
            return -ENOSPC;
        }
    }

    char block_data[BLOCK_SIZE];
    if (storage_read_block(file->block_index, block_data) == -1) {
        memset(block_data, 0, BLOCK_SIZE);
    }
    
    memcpy(block_data + offset, buf, size);
    if (storage_write_block(file->block_index, block_data) == -1) {
        return -EIO;
    }

    file->size = offset + size;
    file->modified_at = time(NULL);

    // Update cache
    cache_write(path, block_data, file->size);

    return size;
}

// Truncate a file
static int fs_truncate(const char *path, off_t size) {
    FileMetadata *file = metadata_get_file(path);
    if (!file) {
        return -ENOENT;
    }
    file->size = size;
    return 0;
}

// File system operations struct
static struct fuse_operations fs_operations = {
    .init       = fs_init,
    .getattr    = fs_getattr,
    .readdir    = fs_readdir,
    .mknod      = fs_mknod,
    .mkdir      = fs_mkdir,
    .unlink     = fs_unlink,
    .rmdir      = fs_rmdir,
    .open       = fs_open,
    .read       = fs_read,
    .write      = fs_write,
    .truncate   = fs_truncate,
    .access     = fs_access,
    .create     = fs_create,
};

// Main function
int main(int argc, char *argv[]) {
    return fuse_main(argc, argv, &fs_operations, NULL);
}
