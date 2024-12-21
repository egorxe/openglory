#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

static int devmem_fd;

struct mmap_type
{
    uintptr_t map_addr;
    size_t map_size;
    void *base;
};

#define MAX_MMAPS   3
static int next_mmap;
struct mmap_type mmap_array[MAX_MMAPS];

int devmem_open()
{
    devmem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (devmem_fd == -1) {
        fprintf(stderr, "error opening /dev/mem.\n%s\n", strerror(errno));
        return 1;
    }
    return 0;
}

int devmem_init(uintptr_t map_base, size_t map_size)
{
    if (next_mmap >= MAX_MMAPS)
        return -1;

    /* Mapping base for memory allocation */
    mmap_array[next_mmap].base = mmap(NULL, map_size, PROT_READ | PROT_WRITE, MAP_SHARED, devmem_fd, map_base);
    if (mmap_array[next_mmap].base == (void *) -1) 
    {
        fprintf(stderr, "error mapping 0x%08lX+0x%08lX @0x%08lX.\n%s\n", (long) map_base, (long) map_size, (long) map_base, strerror(errno));
        return -2;
    }

    mmap_array[next_mmap].map_addr = map_base;
    mmap_array[next_mmap].map_size = map_size;
    
    //~ fprintf(stderr, "mapped 0x%08lX+0x%08lX to 0x%08lX.\n", (long unsigned) map_base, (long unsigned) map_size, (long unsigned) base);
    return next_mmap++;
}

int devmem_find_mmap(uintptr_t addr)
{
    for (int i = 0; i < next_mmap; ++i)
    {
        if (addr >= mmap_array[i].map_addr && addr < mmap_array[i].map_addr+mmap_array[i].map_size)
            return i;
    }
    printf("Unable to find mmaped addr for %X\n", addr);
    assert(0);
    return -1;
}

void* devmem_getptr(int mmap, uintptr_t addr)
{
    addr -= mmap_array[mmap].map_addr;
    return (char*)mmap_array[mmap].base + addr;
}

uint32_t devmem_read32(int mmap, uintptr_t addr)
{
    addr -= mmap_array[mmap].map_addr;
    return ((uint32_t*)mmap_array[mmap].base)[addr / 4];
}

void devmem_write32(int mmap, uintptr_t addr, uint32_t dat)
{
    addr -= mmap_array[mmap].map_addr;
    ((uint32_t*)mmap_array[mmap].base)[addr / 4] = dat;
}
