#ifndef FS_H
#define FS_H

#define FUSE_USE_VERSION 26
#include <fuse/fuse.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include "storage.h"
#include "metadata.h"
#include "cache.h"

// FUSE function prototypes
int fs_getattr(const char *path, struct stat *stbuf);
int fs_readdir(const char *path, void *buf, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info *fi);
int fs_open(const char *path, struct fuse_file_info *fi);
int fs_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *fi);
int fs_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi);
int fs_mkdir(const char *path, mode_t mode);
int fs_unlink(const char *path);
int fs_rmdir(const char *path);
int fs_truncate(const char *path, off_t size);

// File system operations struct
static struct fuse_operations fs_operations = {
    .getattr = fs_getattr,
    .readdir = fs_readdir,
    .open = fs_open,
    .read = fs_read,
    .write = fs_write,
    .mkdir = fs_mkdir,
    .unlink = fs_unlink,
    .rmdir = fs_rmdir,
    .truncate = fs_truncate,
};

#endif /* FS_H */
