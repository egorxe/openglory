// OpenGLory pseudoGPU communication routines

#ifndef _OGLORY_COMM_HH
#define _OGLORY_COMM_HH

#include <cstdint>

int oglory_comm_init();
uint32_t oglory_csr_read32(uint32_t addr);
void oglory_csr_write32(uint32_t val, uint32_t addr);
uint32_t oglory_reg_read32(uint32_t addr);
void oglory_reg_write32(uint32_t val, uint32_t addr);
uint32_t oglory_mem_read32(uint32_t addr);
void oglory_mem_write32(uint32_t val, uint32_t addr);
void oglory_mem_write(uint32_t *buf, int count, uint32_t addr);

void init_adv7511(uint8_t dev_addr);
void init_video_dma();

#endif    /* _OGLORY_COMM_HH */
