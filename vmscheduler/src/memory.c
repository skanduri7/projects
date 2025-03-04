#include "../include/memory.h"
#include <stdio.h>

int translate_address(PageTable *pt, int virtual_page) {
    if (pt->pages[virtual_page].valid == 0) {
        printf("Page fault! Loading page %d into memory...\n", virtual_page);
        pt->pages[virtual_page].valid = 1;
    }
    return pt->pages[virtual_page].frame_number;
}

int find_LRU_page(PageTable *pt) {
    return 0; // Placeholder for LRU implementation
}
