// OpenGLory pseudoGPU communication routines

#include <bits/types/struct_timespec.h>
#include <cstdint>
#include <cstring>
#include <cassert>
#include <time.h>
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

uint32_t csr_read_simple(unsigned long addr);
void csr_write_simple(uint32_t val, unsigned long addr);
#define CSR_ACCESSORS_DEFINED

#ifdef LITEX_PATH
#include <csr.h>
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

uint32_t csr_read_simple(unsigned long addr) 
{
    return oglory_csr_read32(addr);
}

void csr_write_simple(uint32_t val, unsigned long addr) 
{
    oglory_csr_write32(val, addr);
}

#ifdef CSR_I2C_BASE // defined in csr.h in case of I2C present
// I2C control
static const int I2C_SCL    = 0x01;
static const int I2C_SDAOE  = 0x02;
static const int I2C_SDAOUT = 0x04;
static const int I2C_SDAIN  = 0x01;

static const int I2C_DELAY  = 1;

class I2C_Etherbone
{
    int started;

    public:
    I2C_Etherbone()
    {
        started = 0;

        i2c_w_write(I2C_SCL);
        // Check the I2C bus is ready
        while(!(i2c_r_read() & I2C_SDAIN))
            delay_ms(1);
    }

    void delay_us(time_t us)
    {
        struct timespec ts({0, (long)us*1000});
        nanosleep(&ts, nullptr);
    }

    void delay_ms(int ms)
    {
        delay_us(ms*1000);
    }

    uint8_t read_bit()
    {
        // Let the Slave drive data
        i2c_w_write(0);
        delay_us(I2C_DELAY);
        i2c_w_write(I2C_SCL);
        delay_us(I2C_DELAY);
        uint8_t bit = (i2c_r_read() & I2C_SDAIN);
        i2c_w_write(0);
        return bit;
    }

    void write_bit(uint8_t bit)
    {
        if (bit)
            i2c_w_write(I2C_SDAOE| I2C_SDAOUT);
        else
            i2c_w_write(I2C_SDAOE);
        delay_us(I2C_DELAY);
        // Clock stretching
        i2c_w_write(i2c_w_read() | I2C_SCL);
        delay_us(I2C_DELAY);
        i2c_w_write(i2c_w_read() & ~I2C_SCL);
    }

    void start_cond()
    {
        if (started)
        {
            // Set SDA to 1
            i2c_w_write(I2C_SDAOE| I2C_SDAOUT);
            delay_us(I2C_DELAY);
            i2c_w_write(i2c_w_read() | I2C_SCL);
            delay_us(I2C_DELAY);
        }
        // SCL is high, set SDA from 1 to 0
        i2c_w_write(I2C_SDAOE| I2C_SCL);
        delay_us(I2C_DELAY);
        i2c_w_write(I2C_SDAOE);
        started = 1;
    }

    void stop_cond()
    {
        // Set SDA to 0
        i2c_w_write(I2C_SDAOE);
        delay_us(I2C_DELAY);
        // Clock stretching
        i2c_w_write(I2C_SDAOE| I2C_SCL);
        // SCL is high, set SDA from 0 to 1
        i2c_w_write(I2C_SCL);
        delay_us(I2C_DELAY);
        started = 0;
    }

    char write(uint8_t byte)
    {
        for (int i = 0; i < 8; i++)
        {
            write_bit(byte & 0x80);
            byte <<= 1;
        }
        return !read_bit();
    }

    uint8_t read(uint8_t ack)
    {
        uint8_t byte = 0;
        for (int i = 0; i < 8; i++)
        {
            byte <<= 1;
            byte |= read_bit();
        }
        write(!ack);
        return byte;
    }

    uint8_t read_reg(uint8_t dev_addr, uint8_t addr)
    {
        start_cond();
        write(dev_addr);
        write(addr);
        start_cond();
        write(dev_addr | 1);
        uint8_t res = read(0);
        stop_cond();
        return res;
    }
        
    void write_reg(uint8_t dev_addr, uint8_t addr, uint8_t val)
    {
        start_cond();
        write(dev_addr);
        write(addr);
        write(val);
        stop_cond();
    }
};
#endif

void init_adv7511(uint8_t dev_addr)
{
    #ifdef CSR_I2C_BASE
    I2C_Etherbone i2c;
    printf("Initing video ADV7511..");
    fflush(stdout);
    i2c.write_reg(dev_addr, 0x41, 0x10);
    i2c.write_reg(dev_addr, 0x98, 0x03);
    uint8_t reg = i2c.read_reg(dev_addr, 0x9A);
    i2c.write_reg(dev_addr, 0x9A, reg | 0xE0);
    i2c.write_reg(dev_addr, 0xA2, 0xA4);
    i2c.write_reg(dev_addr, 0xA3, 0xA4);
    i2c.write_reg(dev_addr, 0xE0, 0xD0);
    i2c.write_reg(dev_addr, 0xF9, 0x00);

    i2c.write_reg(dev_addr, 0x17, 0x60);    // low polarity syncs
    printf(" done!\n");
    #else
    printf("I2C support not enabled, ADV7511 not initialized!\n");
    #endif
}

void init_video_dma()
{
    #ifdef LITEX_PATH
    printf("Initing video DMA\n");
    oglory_csr_write32(0, CSR_VIDEO_FRAMEBUFFER_DMA_ENABLE_ADDR);
    oglory_csr_write32(0, CSR_VIDEO_FRAMEBUFFER_VTG_ENABLE_ADDR);  
    oglory_reg_write32(CSR_VIDEO_FRAMEBUFFER_DMA_BASE_ADDR, 0x9000000C);    // set FB base GPU reg
    oglory_csr_write32(1, CSR_VIDEO_FRAMEBUFFER_DMA_ENABLE_ADDR);  // enable FB DMA
    oglory_csr_write32(1, CSR_VIDEO_FRAMEBUFFER_VTG_ENABLE_ADDR);  // enable FB VTG
    #endif
}
