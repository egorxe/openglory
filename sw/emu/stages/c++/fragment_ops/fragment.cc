#include <cstdio> 
#include <cstdint> 
#include <cstdlib> 
#include <cstring>

#include <gpu_pipeline.hh> 

#define DRAW_DEPTH_BUF  0

void blend_factor(float *factor, const float *src, const float *dst, uint16_t func)
{
    switch (func)
    {
        case BLENDF_ZERO:
            std::fill(factor, factor + 4, 0);
            break;
        case BLENDF_ONE:
            std::fill(factor, factor + 4, 1);
            break;
        case BLENDF_ONE_MINUS_SRC_COLOR:
            for (int i = 0; i < 4; ++i) factor[i] = 1 - src[i];
            break;
        case BLENDF_SRC_ALPHA:
            std::fill(factor, factor + 4, src[3]);
            break;
        case BLENDF_ONE_MINUS_SRC_ALPHA:
            std::fill(factor, factor + 4, 1 - src[3]);
            break;
        default:
            assert(false);  // TODO: add error message
            break;
    }
}

uint32_t blending(uint32_t src_color, uint16_t src_func, uint32_t dst_color, uint16_t dst_func)
{
    float src_weight = 1;
    float dst_weight = 1;
    float src[] = {
        ((uint8_t*)&src_color)[2] / float(255),
        ((uint8_t*)&src_color)[1] / float(255),
        ((uint8_t*)&src_color)[0] / float(255),
        ((uint8_t*)&src_color)[3] / float(255),
    };  // argb => rgba
    float src_factor[4];
    float dst[] = {
        ((uint8_t*)&dst_color)[2] / float(255),
        ((uint8_t*)&dst_color)[1] / float(255),
        ((uint8_t*)&dst_color)[0] / float(255),
        ((uint8_t*)&dst_color)[3] / float(255),
    };
    float dst_factor[4];

    blend_factor(src_factor, src, dst, src_func);
    blend_factor(dst_factor, src, dst, dst_func);

    float result[4];
    for (int i = 0; i < 4; ++i) {
        result[i] = Clamp(src[i] * src_factor[i] + dst[i] * dst_factor[i]);
    }

    return ArgbToU32(result[3], result[0], result[1], result[2]);
}


int main(int argc, char **argv) 
{
    if (argc != 5)
    {
        puts("Wrong parameters!");
        return 1;
    }
    
    const uint32_t SCREEN_WIDTH     = atoi(argv[1]); 
    const uint32_t SCREEN_HEIGHT    = atoi(argv[2]);
    
    bool depth_test_enabled = false;
    bool alpha_test_enabled = false;
    bool mask_depth_update = false;
    bool blending_enabled = false;
    uint16_t blend_src_func = BLENDF_ONE;
    uint16_t blend_dst_func = BLENDF_ZERO;
    
    // Fill depth buffer with large vals
    uint32_t depth_buffer[SCREEN_WIDTH*SCREEN_HEIGHT];
    for (int i = 0; i < SCREEN_WIDTH; ++i)
        for (int j = 0; j < SCREEN_HEIGHT; ++j)
            depth_buffer[i*SCREEN_HEIGHT + j] = PIPELINE_MAX_Z;


    // Fill frame buffer with zeroes
    uint32_t frame_buffer[SCREEN_WIDTH*SCREEN_HEIGHT];
    for (int i = 0; i < SCREEN_WIDTH; ++i)
        for (int j = 0; j < SCREEN_HEIGHT; ++j)
            frame_buffer[i*SCREEN_HEIGHT + j] = 0;

        
    // Open input & output FIFOs
    IoFifo iofifo(argv[3], argv[4]);
    
    while (1)
    {
        uint32_t cmd = iofifo.ReadFromFifo32();
        switch (cmd)
        {
            case (GPU_PIPE_CMD_CLEAR_ZB):
            {
                #if DRAW_DEPTH_BUF
                for (uint32_t x = 0; x < SCREEN_WIDTH; ++x) 
                { 
                    for (uint32_t y = 0; y < SCREEN_HEIGHT; ++y) 
                    { 
                        uint32_t c = 255 - (uint32_t)((depth_buffer[y * SCREEN_WIDTH + x]) * 255. / PIPELINE_MAX_Z);
                        iofifo.WriteFragment(x, y, 0, (c << 16) | (c << 8) | c);
                    }
                }
                #endif
                
                // fill depth buffer with max Z vals
                for (int i = 0; i < SCREEN_WIDTH; ++i)
                    for (int j = 0; j < SCREEN_HEIGHT; ++j)
                        depth_buffer[i*SCREEN_HEIGHT + j] = PIPELINE_MAX_Z;
                break;
            }
            case (GPU_PIPE_CMD_FRAGMENT):
            {
                // Read input fragments
                uint32_t fragment[4];
                iofifo.ReadFragment(fragment);
                
                uint32_t x = fragment[0];
                uint32_t y = fragment[1];
                uint32_t z = fragment[2];
                uint32_t color = fragment[3];
                uint32_t a = (color & 0xFF000000) >> 24;
                
                // Depth buffer test
                if (depth_test_enabled)
                {
                    if (z > depth_buffer[y * SCREEN_WIDTH + x])    // passes on LESS OR EQUAL
                        continue;
                    if (mask_depth_update)
                        depth_buffer[y * SCREEN_WIDTH + x] = z; 
                }
                
                if (alpha_test_enabled && a <= 171)                 // passes on GREATER
                    continue;

                if (blending_enabled)
                {
                    color = blending(color, blend_src_func, frame_buffer[y * SCREEN_WIDTH + x], blend_dst_func);
                }
                frame_buffer[y * SCREEN_WIDTH + x] = color; 

                #if !DRAW_DEPTH_BUF
                iofifo.WriteFragment(x, y, z, color);
                iofifo.Flush();
                #endif
                break;
            }
            case (GPU_PIPE_CMD_FRAG_STATE):
            {
                // Update state
                uint32_t state_word = iofifo.ReadFromFifo32();
                depth_test_enabled = (state_word & GPU_STATE_FRAG_DEPTH);
                mask_depth_update = (state_word & GPU_STATE_FRAG_DEPTHMASK);
                alpha_test_enabled = (state_word & GPU_STATE_FRAG_ALPHA);
                blending_enabled = (state_word & GPU_STATE_FRAG_BLEND);
                
                blend_src_func = (state_word >> GPU_STATE_FRAG_BLENDSF_SHIFT) & 0xF;
                blend_dst_func = (state_word >> GPU_STATE_FRAG_BLENDDF_SHIFT) & 0xF;
                verbose("Fragment config: depth_test %d depth_update_mask %d alpha_test %d blending %d\n", depth_test_enabled, mask_depth_update, alpha_test_enabled, blending_enabled);
                break;
            }
            case (GPU_PIPE_CMD_CLEAR_FB):
            {
                // fill frame buffer with zero vals
                for (int i = 0; i < SCREEN_WIDTH; ++i)
                    for (int j = 0; j < SCREEN_HEIGHT; ++j)
                        frame_buffer[i*SCREEN_HEIGHT + j] = 0;
                iofifo.BypassCmd(cmd);  // in emulator it is required to pass clear command to the end
                break;
            }
            default:
            {
                // just pass to next stage all unknown commands
                assert((cmd & 0xFFFF0000) == 0xFFFF0000);
                iofifo.BypassCmd(cmd);
                break;
            }
        }
    }
 
    return 0; 
} 
