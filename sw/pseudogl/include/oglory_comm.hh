// OpenGLory pseudoGPU communication routines

#ifndef _OGLORY_COMM_HH
#define _OGLORY_COMM_HH

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

int oglory_comm_init();
uint32_t oglory_csr_read32(uint32_t addr);
void oglory_csr_write32(uint32_t val, uint32_t addr);
uint32_t oglory_reg_read32(uint32_t addr);
void oglory_reg_write32(uint32_t val, uint32_t addr);
uint32_t oglory_mem_read32(uint32_t addr);
void oglory_mem_write32(uint32_t val, uint32_t addr);
void oglory_mem_write(uint32_t *buf, int count, uint32_t addr);

void oglory_hardware_init(uint32_t capabilities);

#ifdef __cplusplus
}
#endif

#endif    /* _OGLORY_COMM_HH */
