#ifndef _LITEX_INIT_H
#define _LITEX_INIT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

void litex_init_sdram();
void litex_init_adv7511(uint8_t dev_addr);
void litex_init_video_dma();

#ifdef __cplusplus
}
#endif


#endif    /* _LITEX_INIT_H */
