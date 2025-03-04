#ifndef METADATA_H
#define METADATA_H

#include <time.h>

#define MAX_FILES 100      
#define NAME_LEN  64     

typedef struct {
    char filename[NAME_LEN]; 
    int size;                // File size in bytes
    int block_index;         // Storage block index
    time_t created_at;       // Timestamp of file creation
    time_t modified_at;      // Timestamp of last modification
    int is_directory;        // 1 if directory, 0 if file
} FileMetadata;

// Metadata Management
void metadata_init();                      // Initialize metadata system
int metadata_create_file(const char *filename, int is_directory); // Create a file or directory
int metadata_delete_file(const char *filename); // Delete a file
FileMetadata *metadata_get_file(const char *filename); // Get file metadata
void metadata_list();                      // List all metadata (for debugging)
int metadata_list_files(char file_list[MAX_FILES][NAME_LEN]);  // Returns file count


#endif /* METADATA_H */
