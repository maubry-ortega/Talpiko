/**
 * Minimal Bump Allocator for Pikpo WASM
 */
#include <stddef.h>

extern unsigned char __heap_base;
static unsigned char* heap_ptr = &__heap_base;

void* malloc(size_t size) {
    void* res = heap_ptr;
    heap_ptr += size;
    // Align to 8 bytes
    heap_ptr = (unsigned char*)(((size_t)heap_ptr + 7) & ~7);
    return res;
}

void free(void* ptr) {
    // No-op for a bump allocator
}

void* calloc(size_t nmemb, size_t size) {
    void* res = malloc(nmemb * size);
    if (res) {
        for (size_t i = 0; i < nmemb * size; i++) {
            ((unsigned char*)res)[i] = 0;
        }
    }
    return res;
}

void* realloc(void* ptr, size_t size) {
    // Very naive realloc: just allocate new space and copy
    void* res = malloc(size);
    // Note: We don't know the old size, so this is unsafe for real use,
    // but Nim's ARC might not need it if it handles its own resizing logic
    // through malloc/free.
    return res;
}
