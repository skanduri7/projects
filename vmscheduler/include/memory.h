#ifndef MEMORY_H
#define MEMORY_H

#define MAX_PAGES 16

typedef struct {
    int page_number;
    int frame_number;
    int valid; // 1 if page is in memory, 0 otherwise
} PageTableEntry;

typedef struct {
    PageTableEntry pages[MAX_PAGES];
} PageTable;

int translate_address(PageTable *pt, int virtual_page);
int find_LRU_page(PageTable *pt);
#endif
