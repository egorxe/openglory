#ifndef _OGLORY_GPU_DEFS_HH
#define _OGLORY_GPU_DEFS_HH

#include <cstdint>


// Pipeline commands (2 bytes - 0xFFFF, 1 byte - number of argument words, 1 byte - command code)
const uint32_t GPU_PIPE_CMD_POLY_VERTEX3    = 0xFFFF1500;
const uint32_t GPU_PIPE_CMD_POLY_VERTEX4    = 0xFFFF1800;
const uint32_t GPU_PIPE_CMD_POLY_VERTEX3N3  = 0xFFFF2A01;
const uint32_t GPU_PIPE_CMD_POLY_VERTEX4N3  = 0xFFFF2D01;
const uint32_t GPU_PIPE_CMD_POLY_VERTEX3TC  = 0xFFFF1B02;
const uint32_t GPU_PIPE_CMD_POLY_VERTEX4TC  = 0xFFFF1E02;
const uint32_t GPU_PIPE_CMD_SYNC            = 0xFFFF0010;
const uint32_t GPU_PIPE_CMD_CLEAR_FB        = 0xFFFF0011;
const uint32_t GPU_PIPE_CMD_CLEAR_ZB        = 0xFFFF0012;
const uint32_t GPU_PIPE_CMD_FRAGMENT        = 0xFFFF0320;
const uint32_t GPU_PIPE_CMD_TEXFRAGMENT     = 0xFFFF0421;
const uint32_t GPU_PIPE_CMD_MODEL_MATRIX    = 0xFFFF1030;
const uint32_t GPU_PIPE_CMD_PROJ_MATRIX     = 0xFFFF1031;
const uint32_t GPU_PIPE_CMD_NORMAL_MATRIX   = 0xFFFF1035;
const uint32_t GPU_PIPE_CMD_RAST_STATE      = 0xFFFF0140;
const uint32_t GPU_PIPE_CMD_FRAG_STATE      = 0xFFFF0141;
const uint32_t GPU_PIPE_CMD_LIGHT_STATE     = 0xFFFF0142;
const uint32_t GPU_PIPE_CMD_VIEWPORT_PARAMS = 0xFFFF0650;
const uint32_t GPU_PIPE_CMD_LIGHT_PARAMS    = 0xFFFF0851;
const uint32_t GPU_PIPE_CMD_BLEND_PARAMS    = 0xFFFF0152;
const uint32_t GPU_PIPE_CMD_BINDTEXTURE     = 0xFFFF0260;
const uint32_t GPU_PIPE_CMD_NOP             = 0xFFFF00F0;


// Addresses
const uint32_t GPU_MEMBUF_ADDR              = 0x40000000;
const uint32_t GPU_CMD_BUF_ADDR             = GPU_MEMBUF_ADDR + 0x900000;
const uint32_t GPU_CMD_BUF_SIZE             = 0x00040000;
const uint32_t GPU_CMD_FB_SIZE              = 0x200000; // ! depends on resolution !
const uint32_t GPU_TEX_BUF_ADDR             = 0x43000000; //GPU_CMD_BUF_ADDR + GPU_CMD_BUF_SIZE + GPU_CMD_FB_SIZE*2;
const uint32_t GPU_ADDR_MASK                = 0x0FFFFFFF;

const uint32_t GPU_REG_BASE_ADDR            = 0x90000000;
const uint32_t GPU_REG_CTRL_ADDR            = GPU_REG_BASE_ADDR + 0x00;
const uint32_t GPU_REG_CMDSIZE_ADDR         = GPU_REG_BASE_ADDR + 0x04;
const uint32_t GPU_REG_CMDBASE_ADDR         = GPU_REG_BASE_ADDR + 0x08;
const uint32_t GPU_REG_STAT_ADDR            = GPU_REG_BASE_ADDR + 0x00;
const uint32_t GPU_REG_FRAME_ADDR           = GPU_REG_BASE_ADDR + 0x08;
const uint32_t GPU_REG_CAP_ADDR             = GPU_REG_BASE_ADDR + 0x0C;
const uint32_t GPU_REG_BOARD0_ADDR          = GPU_REG_BASE_ADDR + 0x10;
const uint32_t GPU_REG_BOARD1_ADDR          = GPU_REG_BASE_ADDR + 0x14;
const uint32_t GPU_REG_RESET_ADDR           = GPU_REG_BASE_ADDR + 0x18;
const uint32_t GPU_REG_DEBUG_ADDR           = GPU_REG_BASE_ADDR + 0x3C;

const uint32_t GPU_REGS_LEN                 = 0x100;
const uint32_t GPU_MEMBUF_LEN               = GPU_TEX_BUF_ADDR - GPU_MEMBUF_ADDR + 32*1024*1024;

// Control reg
const uint32_t GPU_CTRL_CMD                 = 0x01;
const uint32_t GPU_CTRL_FBSWITCH            = 0x02;

// Status reg
const uint32_t GPU_STAT_FULL                = 0x08;
const uint32_t GPU_STAT_EMPTY               = 0x10;
const uint32_t GPU_STAT_FLUSH_MASK          = 0x07;

// Capabilities reg
const uint32_t GPU_CAP_LITEXDMA             = 0x00000001;
const uint32_t GPU_CAP_LIGHTING             = 0x00000100;
const uint32_t GPU_CAP_ADV7511              = 0x00010000;

// State commands bits
const uint32_t GPU_STATE_RAST_CULLBACK      = 0x00000001;
const uint32_t GPU_STATE_RAST_CULLFRONT     = 0x00000002;
const uint32_t GPU_STATE_RAST_CULLMASK      = GPU_STATE_RAST_CULLBACK | GPU_STATE_RAST_CULLFRONT;

const uint32_t GPU_STATE_FRAG_DEPTH         = 0x00000001;
const uint32_t GPU_STATE_FRAG_DEPTHMASK     = 0x00000002;
const uint32_t GPU_STATE_FRAG_ALPHA         = 0x00000004;
const uint32_t GPU_STATE_FRAG_BLEND         = 0x00000008;

const uint32_t GPU_STATE_FRAG_BLENDF_MASK   = 0x000FF000;
const uint32_t GPU_STATE_FRAG_BLENDSF_SHIFT = 12;
const uint32_t GPU_STATE_FRAG_BLENDDF_SHIFT = 16;

const uint32_t GPU_STATE_LIGHT_ENABLE       = 0x00000001;

// Blending function enum
enum
{
    BLENDF_ZERO,
    BLENDF_ONE,
    BLENDF_SRC_COLOR,
    BLENDF_ONE_MINUS_SRC_COLOR,
    BLENDF_DST_COLOR,
    BLENDF_ONE_MINUS_DST_COLOR,
    BLENDF_SRC_ALPHA,
    BLENDF_ONE_MINUS_SRC_ALPHA,
    BLENDF_DST_ALPHA,
    BLENDF_ONE_MINUS_DST_ALPHA,
    BLENDF_SRC_ALPHA_SATURATE
};


#endif    /* _OGLORY_GPU_DEFS_HH */
