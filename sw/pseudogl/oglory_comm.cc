// OpenGLory pseudoGPU communication routines

#include <cstdint>
#include <cstring>
#include <cassert>
#include <cstdio>
#include <string>

#include <oglory_comm.hh>
#include <oglory_gpu_defs.hh>

// #define OGLORY_COMM_ETHERBONE 1
// #define OGLORY_COMM_DEVMEM 1

// LiteX Etherbone routines
#if OGLORY_COMM_ETHERBONE
#include "libeb-c/etherbone.h"
#elif OGLORY_COMM_DEVMEM
#include "devmem.h"
#else
#error "One of OGLORY_COMM methods should be defined!"
#endif

#ifdef LITEX_PATH
#include "litex_init.h"
#endif

// OpenGLory communication routines (only slow & dumb Etherbone 32-bit access and direct /dev/mem for now)

#if OGLORY_COMM_ETHERBONE
static struct eb_connection *eb;

int oglory_comm_init()
{
    const char *eb_address = getenv("EB_ADDRESS");
    char port[] = "1234";
    if (!eb_address)
        eb_address = "127.0.0.1";

    std::string saddr(eb_address);
    int is_direct = 1;
    if (saddr == "127.0.0.1" || saddr == "localhost")
        is_direct = 0;

    eb = eb_connect(eb_address, port, is_direct);
    if (!eb)
        return -1;
    printf("Connected to %s %s\n", eb_address, port);
    
    return 0;
}

uint32_t oglory_reg_read32(uint32_t addr) 
{
    return eb_read32(eb, addr);
}

void oglory_reg_write32(uint32_t val, uint32_t addr) 
{
    return eb_write32(eb, val, addr);
}

uint32_t oglory_csr_read32(uint32_t addr) 
{
    return eb_read32(eb, addr);
}

void oglory_csr_write32(uint32_t val, uint32_t addr) 
{
    eb_write32(eb, val, addr);
}

uint32_t oglory_mem_read32(uint32_t addr) 
{
    return eb_read32(eb, addr);
}

void oglory_mem_write32(uint32_t val, uint32_t addr) 
{
    eb_write32(eb, val, addr);
}

void oglory_mem_write(uint32_t *buf, int count, uint32_t addr)
{
    for (int i = 0; i < count; i++)
        eb_write32(eb, buf[i], addr + i*4);
}

#elif OGLORY_COMM_DEVMEM

enum {
    oglory_regs_mmap,
    oglory_buf_mmap,
    oglory_csr_mmap
};

int oglory_comm_init()
{
    if (devmem_open())
        return 1;
    if (devmem_init(GPU_REG_BASE_ADDR, GPU_REGS_LEN) != oglory_regs_mmap)
        return 2;
    if (devmem_init(GPU_MEMBUF_ADDR, GPU_MEMBUF_LEN) != oglory_buf_mmap)
        return 2;
    if (devmem_init(0xF0000000, 0x100000) != oglory_csr_mmap)
        return 2;
    return 0;
}

uint32_t oglory_reg_read32(uint32_t addr) 
{
    return devmem_read32(oglory_regs_mmap, addr);
}

void oglory_reg_write32(uint32_t val, uint32_t addr) 
{
    return devmem_write32(oglory_regs_mmap, addr, val);
}

uint32_t oglory_csr_read32(uint32_t addr) 
{
    return devmem_read32(oglory_csr_mmap, addr);
}

void oglory_csr_write32(uint32_t val, uint32_t addr) 
{
    devmem_write32(oglory_csr_mmap, addr, val);
}

uint32_t oglory_mem_read32(uint32_t addr) 
{
    return devmem_read32(oglory_buf_mmap, addr);
}

void oglory_mem_write32(uint32_t val, uint32_t addr) 
{
    devmem_write32(oglory_buf_mmap, addr, val);
}

void oglory_mem_write(uint32_t *buf, int count, uint32_t addr)
{
    void* dst = devmem_getptr(oglory_buf_mmap, addr);
    memcpy(dst, buf, count*4);
}

#endif

void oglory_hardware_init(uint32_t capabilities)
{
    #ifdef LITEX_PATH
    if (capabilities & GPU_CAP_SDRAMINIT)
    {
        printf("Initing SDRAM\n");
        litex_init_sdram();
    }
    if (capabilities & GPU_CAP_VIDEODMA)
    {
        printf("Initing video DMA\n");
        litex_init_video_dma();
    }
    if (capabilities & GPU_CAP_ADV7511)
    {
        printf("Initing ADV7511 video chip\n");
        litex_init_adv7511(0x72);
    }
    #else
    if (capabilities & (GPU_CAP_SDRAMINIT | GPU_CAP_VIDEODMA | GPU_CAP_ADV7511))
        printf("LITEX_BOARD is not defined, or path not found. Some hardware functions may be uninitialized.");
    #endif
}
