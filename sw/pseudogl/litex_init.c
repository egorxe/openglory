#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <time.h>
#include <bits/types/struct_timespec.h>

#include "oglory_comm.hh"

uint32_t csr_read_simple(unsigned long addr) 
{
    return oglory_csr_read32(addr);
}

void csr_write_simple(uint32_t val, unsigned long addr) 
{
    oglory_csr_write32(val, addr);
}

#define CSR_ACCESSORS_DEFINED
#include <generated/csr.h>

void cdelay(int i)
{
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = (long)i*1000;
    nanosleep(&ts, NULL);
}

#ifdef CSR_I2C_BASE // defined in csr.h in case of I2C present
// I2C control
static const int I2C_SCL    = 0x01;
static const int I2C_SDAOE  = 0x02;
static const int I2C_SDAOUT = 0x04;
static const int I2C_SDAIN  = 0x01;

static const int I2C_DELAY  = 1;

static int i2c_started;

static void i2c_init()
{
    i2c_started = 0;

    i2c_w_write(I2C_SCL);
    // Check the I2C bus is ready
    while(!(i2c_r_read() & I2C_SDAIN))
        cdelay(1000);
}

static uint8_t i2c_read_bit()
{
    // Let the Slave drive data
    i2c_w_write(0);
    cdelay(I2C_DELAY);
    i2c_w_write(I2C_SCL);
    cdelay(I2C_DELAY);
    uint8_t bit = (i2c_r_read() & I2C_SDAIN);
    i2c_w_write(0);
    return bit;
}

static void i2c_write_bit(uint8_t bit)
{
    if (bit)
        i2c_w_write(I2C_SDAOE| I2C_SDAOUT);
    else
        i2c_w_write(I2C_SDAOE);
    cdelay(I2C_DELAY);
    // Clock stretching
    i2c_w_write(i2c_w_read() | I2C_SCL);
    cdelay(I2C_DELAY);
    i2c_w_write(i2c_w_read() & ~I2C_SCL);
}

static void i2c_start_cond()
{
    if (i2c_started)
    {
        // Set SDA to 1
        i2c_w_write(I2C_SDAOE| I2C_SDAOUT);
        cdelay(I2C_DELAY);
        i2c_w_write(i2c_w_read() | I2C_SCL);
        cdelay(I2C_DELAY);
    }
    // SCL is high, set SDA from 1 to 0
    i2c_w_write(I2C_SDAOE| I2C_SCL);
    cdelay(I2C_DELAY);
    i2c_w_write(I2C_SDAOE);
    i2c_started = 1;
}

static void i2c_stop_cond()
{
    // Set SDA to 0
    i2c_w_write(I2C_SDAOE);
    cdelay(I2C_DELAY);
    // Clock stretching
    i2c_w_write(I2C_SDAOE| I2C_SCL);
    // SCL is high, set SDA from 0 to 1
    i2c_w_write(I2C_SCL);
    cdelay(I2C_DELAY);
    i2c_started = 0;
}

static char i2c_write(uint8_t byte)
{
    for (int i = 0; i < 8; i++)
    {
        i2c_write_bit(byte & 0x80);
        byte <<= 1;
    }
    return !i2c_read_bit();
}

static uint8_t i2c_read(uint8_t ack)
{
    uint8_t byte = 0;
    for (int i = 0; i < 8; i++)
    {
        byte <<= 1;
        byte |= i2c_read_bit();
    }
    i2c_write(!ack);
    return byte;
}

static uint8_t i2c_read_reg(uint8_t dev_addr, uint8_t addr)
{
    i2c_start_cond();
    i2c_write(dev_addr);
    i2c_write(addr);
    i2c_start_cond();
    i2c_write(dev_addr | 1);
    uint8_t res = i2c_read(0);
    i2c_stop_cond();
    return res;
}
    
static void i2c_write_reg(uint8_t dev_addr, uint8_t addr, uint8_t val)
{
    i2c_start_cond();
    i2c_write(dev_addr);
    i2c_write(addr);
    i2c_write(val);
    i2c_stop_cond();
}
#endif

// SDRAM init (only for basic SDRAM!)
#define DFII_CONTROL_SEL 0x01
#define DFII_CONTROL_CKE 0x02
#define DFII_CONTROL_ODT 0x04
#define DFII_CONTROL_RESET_N 0x08

#define DFII_COMMAND_CS 0x01
#define DFII_COMMAND_WE 0x02
#define DFII_COMMAND_CAS 0x04
#define DFII_COMMAND_RAS 0x08
#define DFII_COMMAND_WRDATA 0x10
#define DFII_COMMAND_RDDATA 0x20

#define SDRAM_PHY_HALFRATEGENSDRPHY
#define SDRAM_PHY_XDR 1
#define SDRAM_PHY_DATABITS 16
#define SDRAM_PHY_DFI_DATABITS 16
#define SDRAM_PHY_PHASES 2
#define SDRAM_PHY_CL 2
#define SDRAM_PHY_CWL 2
#define SDRAM_PHY_RDPHASE 0
#define SDRAM_PHY_WRPHASE 0
#define SDRAM_PHY_DQ_DQS_RATIO 8
#define SDRAM_PHY_MODULES 2
#define SDRAM_PHY_SDR
#define SDRAM_PHY_SUPPORTED_MEMORY 0x0000000002000000ULL

#define DFII_CONTROL_SOFTWARE (DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N)
#define DFII_CONTROL_HARDWARE (DFII_CONTROL_SEL)

__attribute__((unused)) static inline void command_p0(int cmd)
{
	sdram_dfii_pi0_command_write(cmd);
	sdram_dfii_pi0_command_issue_write(1);
}
__attribute__((unused)) static inline void command_p1(int cmd)
{
	sdram_dfii_pi1_command_write(cmd);
	sdram_dfii_pi1_command_issue_write(1);
}

#define DFII_PIX_DATA_SIZE CSR_SDRAM_DFII_PI0_WRDATA_SIZE

static inline unsigned long sdram_dfii_pix_wrdata_addr(int phase)
{
	switch (phase) {
		case 0: return CSR_SDRAM_DFII_PI0_WRDATA_ADDR;
		case 1: return CSR_SDRAM_DFII_PI1_WRDATA_ADDR;
		default: return 0;
	}
}
static inline unsigned long sdram_dfii_pix_rddata_addr(int phase)
{
	switch (phase) {
		case 0: return CSR_SDRAM_DFII_PI0_RDDATA_ADDR;
		case 1: return CSR_SDRAM_DFII_PI1_RDDATA_ADDR;
		default: return 0;
	}
}

static void sdram_software_control_on(void) {
	unsigned int previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to software control */
	if (previous != DFII_CONTROL_SOFTWARE) {
		sdram_dfii_control_write(DFII_CONTROL_SOFTWARE);
	}
}

static void sdram_software_control_off(void) {
	unsigned int previous;
	previous = sdram_dfii_control_read();
	/* Switch DFII to hardware control */
	if (previous != DFII_CONTROL_HARDWARE) {
		sdram_dfii_control_write(DFII_CONTROL_HARDWARE);
	}
}


// Init functions

void litex_init_sdram(void)
{
    sdram_software_control_on();

	/* Bring CKE high */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	sdram_dfii_control_write(DFII_CONTROL_CKE|DFII_CONTROL_ODT|DFII_CONTROL_RESET_N);
	cdelay(20000);

	/* Precharge All */
	sdram_dfii_pi0_address_write(0x400);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);

	/* Load Mode Register / Reset DLL, CL=2, BL=2 */
	sdram_dfii_pi0_address_write(0x121);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);

	/* Precharge All */
	sdram_dfii_pi0_address_write(0x400);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_WE|DFII_COMMAND_CS);

	/* Auto Refresh */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_CS);
	cdelay(4);

	/* Auto Refresh */
	sdram_dfii_pi0_address_write(0x0);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_CS);
	cdelay(4);

	/* Load Mode Register / CL=2, BL=2 */
	sdram_dfii_pi0_address_write(0x21);
	sdram_dfii_pi0_baddress_write(0);
	command_p0(DFII_COMMAND_RAS|DFII_COMMAND_CAS|DFII_COMMAND_WE|DFII_COMMAND_CS);
	cdelay(200);

    sdram_software_control_off();
}

void litex_init_adv7511(uint8_t dev_addr)
{
    #ifdef CSR_I2C_BASE
    i2c_write_reg(dev_addr, 0x41, 0x10);
    i2c_write_reg(dev_addr, 0x98, 0x03);
    uint8_t reg = i2c_read_reg(dev_addr, 0x9A);
    i2c_write_reg(dev_addr, 0x9A, reg | 0xE0);
    i2c_write_reg(dev_addr, 0xA2, 0xA4);
    i2c_write_reg(dev_addr, 0xA3, 0xA4);
    i2c_write_reg(dev_addr, 0xE0, 0xD0);
    i2c_write_reg(dev_addr, 0xF9, 0x00);

    i2c_write_reg(dev_addr, 0x17, 0x60);    // low polarity syncs
    #else
    printf("I2C support not enabled, ADV7511 not initialized!\n");
    #endif
}

void litex_init_video_dma()
{
    oglory_csr_write32(0, CSR_VIDEO_FRAMEBUFFER_DMA_ENABLE_ADDR);
    oglory_csr_write32(0, CSR_VIDEO_FRAMEBUFFER_VTG_ENABLE_ADDR);  
    oglory_reg_write32(CSR_VIDEO_FRAMEBUFFER_DMA_BASE_ADDR, 0x9000000C);    // set FB base GPU reg
    oglory_csr_write32(1, CSR_VIDEO_FRAMEBUFFER_DMA_ENABLE_ADDR);  // enable FB DMA
    oglory_csr_write32(1, CSR_VIDEO_FRAMEBUFFER_VTG_ENABLE_ADDR);  // enable FB VTG
}
