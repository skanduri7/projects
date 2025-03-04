#include "../include/metadata.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static FileMetadata metadata[MAX_FILES]; // Metadata storage
static int metadata_count = 0; // Number of files

// Initialize metadata system
void metadata_init() {
    memset(metadata, 0, sizeof(metadata));
}

// Create a new file or directory
int metadata_create_file(const char *filename, int is_directory) {
    printf("metadata_create_file: Trying to create file %s\n", filename);

    // Check if the file already exists
    for (int i = 0; i < metadata_count; i++) {
        if (strcmp(metadata[i].filename, filename) == 0) {
            printf("metadata_create_file: ERROR: File %s already exists!\n", filename);
            return -EEXIST;
        }
    }

    if (metadata_count >= MAX_FILES) {
        printf("metadata_create_file: ERROR: No space left for %s\n", filename);
        return -ENOSPC; // No space left
    }

    // Add new file metadata
    strncpy(metadata[metadata_count].filename, filename, NAME_LEN);
    metadata[metadata_count].filename[NAME_LEN - 1] = '\0'; // Ensure null termination
    metadata[metadata_count].size = 0;
    metadata[metadata_count].block_index = -1; // No storage assigned yet
    metadata[metadata_count].created_at = time(NULL);
    metadata[metadata_count].modified_at = time(NULL);
    metadata[metadata_count].is_directory = is_directory;

    printf("metadata_create_file: File %s created successfully!\n", metadata[metadata_count].filename);
    metadata_count++;

    return 0;
}


// Delete a file from metadata
int metadata_delete_file(const char *filename) {
    for (int i = 0; i < metadata_count; i++) {
        if (strcmp(metadata[i].filename, filename) == 0) {
            for (int j = i; j < metadata_count - 1; j++) {
                metadata[j] = metadata[j + 1];
            }
            metadata_count--;
            return 0;
        }
    }
    return -1; // File not found
}

// Get file metadata
FileMetadata *metadata_get_file(const char *filename) {
    for (int i = 0; i < metadata_count; i++) {
        if (strcmp(metadata[i].filename, filename) == 0) {
            return &metadata[i];
        }
    }
    return NULL; // Not found
}

// Debug: List all metadata
void metadata_list() {
    printf("Metadata List:\n");
    for (int i = 0; i < metadata_count; i++) {
        printf("File: %s | Size: %d | Block: %d | Created: %ld\n",
               metadata[i].filename, metadata[i].size, metadata[i].block_index, metadata[i].created_at);
    }
}

int metadata_list_files(char file_list[MAX_FILES][NAME_LEN]) {
    int count = 0;
    printf("metadata_list_files: Scanning for stored files...\n");

    for (int i = 0; i < metadata_count; i++) {
        if (metadata[i].filename[0] != '\0') {
            strncpy(file_list[count], metadata[i].filename, NAME_LEN);
            file_list[count][NAME_LEN - 1] = '\0'; // Ensure null termination
            printf("metadata_list_files: Found file -> %s\n", file_list[count]);
            count++;
        }
    }

    printf("metadata_list_files: Returning %d files\n", count);
    return count; // Return number of files found
}


