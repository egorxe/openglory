#ifndef _DEVMEM_H
#define _DEVMEM_H
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int devmem_open();
int devmem_init(uintptr_t map_base, size_t map_size);
uint32_t devmem_read32(int mmap, uintptr_t addr);
void devmem_write32(int mmap, uintptr_t addr, uint32_t dat);
int devmem_find_mmap(uintptr_t addr);
void* devmem_getptr(int mmap, uintptr_t addr);

#ifdef __cplusplus
}
#endif

#endif    /* _DEVMEM_H */
