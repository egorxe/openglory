// API for OpenGlory toy GPU

#include <ostream>
#define PROFILE         0
#define SKIP_FRAMES     0 
#define SKIP_PUTBUF     0
#define LOAD_TEXTURES   1

#include "GLES/gl.h"
#include "pgl_math.hh"
#include <cstdint>
#include <iostream>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <assert.h>

#include <oglory_comm.hh>
#include <oglory_gpu_defs.hh>
#include <pseudogl.hh>

// Pseudo GL context methods
PseudoGLContext::PseudoGLContext() :
    buffer_elements(0),
    cur_matrix(PGL_MODEL_MATRIX),
    vertex_array(vertex_arrays[PGL_VERTEX_ARRAY]),
    color_array(vertex_arrays[PGL_COLOR_ARRAY]),
    normal_array(vertex_arrays[PGL_NORMAL_ARRAY]),
    texcoord_array(vertex_arrays[PGL_TEXCOORD_ARRAY]),
    material_params({{0.2, 0.2, 0.2, 1.0}, {0.8, 0.8, 0.8, 1.0}}),
    cur_color({1.0, 1.0, 1.0, 1.0}),
    light_params({{0.0, 0.0, 1.0, 0.0}, {1.0, 1.0, 1.0, 1.0}}),
    lighting_dirty(true),
    lighting_enabled(false),
    viewport_params({0, 0, PGL_WND_SIZE_X, PGL_WND_SIZE_Y}),
    depthrange_params({0., 1.}),
    depth_enabled(false),
    depth_masked(true),
    alpha_enabled(false),
    blend_enabled(false),
    viewport_dirty(true),
    rast_state_dirty(true),
    frag_state_dirty(true),
    cull_face(GPU_STATE_RAST_CULLBACK),
    front_face(true),
    new_texture_id(1),   
    binded_texture(0),
    gpu_freemem_ptr(GPU_TEX_BUF_ADDR)
{
    if (oglory_comm_init()) 
    {
        std::cerr << "Couldn't init OpenGlory connection" << std::endl;
        exit(1);
    }

    // Reset GPU
    oglory_reg_write32(1, GPU_REG_RESET_ADDR);
    SleepMs(1);
    
    // Get capabilities
    capabilities = oglory_reg_read32(GPU_REG_CAP_ADDR);
    // Init functions mentioned in capabilities
    oglory_hardware_init(capabilities);
    lighting_supported = capabilities & GPU_CAP_LIGHTING;
    
    // Set buffers
    for (int i = 0; i < PGL_MAX_CMD_BUFFERS; ++i)
        dev_buf_ptr[i] = GPU_CMD_BUF_ADDR + i*PGL_MAX_CMD_BUF_ELEMENTS*4;
    current_dev_buf = 0;
    frame_cnt = 0;

    for (int i = 0; i < PGL_MATRIX_NUM; i++)
        matrices[i] = matrix_stack[i];

    for (int a = 0; a < PGL_VERTEX_ARRAYS; a++)
        vertex_arrays[a] = {false, 3, GL_FLOAT, 0, nullptr};

    memset(&textures, 0, sizeof(textures));

    // Get board name
    char tmp_name[9];
    uint32_t name_reg = oglory_reg_read32(GPU_REG_BOARD0_ADDR);
    strncpy(tmp_name, (char*)&name_reg, 4);
    name_reg = oglory_reg_read32(GPU_REG_BOARD1_ADDR);
    strncpy(tmp_name+4, (char*)&name_reg, 4);
    tmp_name[8] = '\0';
    board_name = std::string("OpenGlory on ") + tmp_name;
    board_name.erase(board_name.find_last_not_of(" ")+1); // trim
}

// Simple profiler
void PseudoGLContext::Profile()
{
    #if PROFILE
    if (!(profile_cnt++ & 0xF))
    {
        uint32_t reg = oglory_reg_read32(GPU_REG_DEBUG_ADDR);
        profile++;
        if (reg & 0x0001)
            input_to_vertex_valid++;
        if (reg & 0x0004)
            vertex_to_rast_valid++;
        if (reg & 0x0010)
            rast_to_cc_valid++;
        if (reg & 0x0040)
            cc_to_tex_valid++;
        if (reg & 0x0100)
            tex_to_frag_valid++;
        if (reg & 0x1000)
            tex_wb++;
        if (reg & 0x2000)
            frag_wb++;
        if (reg & 0x4000)
            fb_wb++;
    }
    #endif
}

// Swap visible framebuffer
void PseudoGLContext::SwapBuffers()
{
    // Wait for all previous commands to finish
    frame_cnt++;
    PipelineFlush();

    oglory_reg_write32(GPU_CTRL_FBSWITCH, GPU_REG_CTRL_ADDR);

    #if PROFILE
    if (!(frame_cnt % 20))
    {
        puts("############################################################");
        printf("profile runs            %06d\n", profile);
        printf("input_to_vertex_valid   %06d %0.3f\n", input_to_vertex_valid, (float)input_to_vertex_valid/profile);
        printf("vertex_to_rast_valid    %06d\n", vertex_to_rast_valid);
        printf("rast_to_cc_valid        %06d\n", rast_to_cc_valid);
        printf("cc_to_tex_valid         %06d\n", cc_to_tex_valid);
        printf("tex_to_frag_valid       %06d\n", tex_to_frag_valid);
        printf("tex_wb                  %06d\n", tex_wb);
        printf("frag_wb                 %06d\n", frag_wb);
        printf("fb_wb                   %06d\n", fb_wb);
        puts("############################################################");

        profile = input_to_vertex_valid = vertex_to_rast_valid = rast_to_cc_valid = cc_to_tex_valid = tex_to_frag_valid = 0;
        tex_wb = frag_wb = fb_wb = 0;
    }
    #endif
}

// Send command buffer read cmd to GPU
void PseudoGLContext::CommitCmdBuffer()
{
    if (buffer_elements)
    {
        #if SKIP_FRAMES
        if (frame_cnt >= SKIP_FRAMES) {
        #endif
        // Add sync command
        PutToBuf(GPU_PIPE_CMD_SYNC);

        // Wait for GPU command buffer to become ready to switch to it
        while (oglory_reg_read32(GPU_REG_STAT_ADDR) & GPU_STAT_FULL) Profile();

        // Start GPU cmd read
        oglory_reg_write32(dev_buf_ptr[current_dev_buf], GPU_REG_CMDBASE_ADDR);
        oglory_reg_write32(buffer_elements, GPU_REG_CMDSIZE_ADDR);
        #if SKIP_FRAMES
        }
        #endif

        // Switch buffer
        if (++current_dev_buf == PGL_MAX_CMD_BUFFERS)
            current_dev_buf = 0;
        buffer_elements = 0;
    }
}

void PseudoGLContext::PutToBuf(uint32_t w, bool committable) 
{
    #if SKIP_PUTBUF
    if (frame_cnt >= SKIP_FRAMES) {
    #endif
    if (committable && (buffer_elements > PGL_MAX_CMD_BUF_ELEMENTS-PGL_MAX_CMD_LEN))
        CommitCmdBuffer();
    assert(buffer_elements<PGL_MAX_CMD_BUF_ELEMENTS);
    oglory_mem_write32(w, dev_buf_ptr[current_dev_buf]+buffer_elements*4);
    
    buffer_elements++;
    #if SKIP_PUTBUF
    }
    #endif
}

// Wait for hardware to finish all commands
void PseudoGLContext::PipelineFlush()
{
    CommitCmdBuffer();
    while(oglory_reg_read32(GPU_REG_STAT_ADDR) & GPU_STAT_FLUSH_MASK) Profile();
}

// Clear framebuffer & z-buffer
void PseudoGLContext::ClearBuffer(bool clear_fb, bool clear_zb) 
{
    if (clear_fb)
        PutToBuf(GPU_PIPE_CMD_CLEAR_FB);

    if (clear_zb)
        PutToBuf(GPU_PIPE_CMD_CLEAR_ZB);

    CommitCmdBuffer();
}

void PseudoGLContext::SetVertexArray(int array, int size, int type, size_t stride, const float* ptr) 
{
    vertex_arrays[array].size=size; 
    vertex_arrays[array].type=type; 
    vertex_arrays[array].stride=stride ? stride : type*size; 
    vertex_arrays[array].ptr=ptr;
}

void PseudoGLContext::SetVertexArrayEnabled(int array, bool e) 
{
    if (!lighting_supported && array == PGL_NORMAL_ARRAY)
        return; // hack for lighted models to show without lighting support
    vertex_arrays[array].enabled = e;
}

// Helper fetching from pointer with size
uint32_t PseudoGLContext::GetValWithSize(const void* ptr, int size, int off)
{
    switch (size)
    {
        case 0:
            return off;
        case 1:
            return ((uint8_t*)ptr)[off];
        case 2:
            return ((uint16_t*)ptr)[off];
        case 4:
            return ((uint32_t*)ptr)[off];
        default:
            assert(false);
            return 0;
    }
}

// Put matrix to command buffer
void PseudoGLContext::PutMatrixToBuffer(PglMatrix &m)
{
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            PutToBuf(FloatToU32(m.m[i][j]));
    m.SetDirty(false);
}

// Put data from vertex arrays to command buffer
void PseudoGLContext::PutVertexDataToBuffer(int array, int vo, int i, const void *indices, int indice_size)
{
    VertexArrayState &v(vertex_arrays[array]);
    for (int n = 0; n < v.size; n++)
    {
        size_t offn = v.stride*(GetValWithSize(indices, indice_size, vo + i)) + n*v.type;
        uint8_t* off = ((uint8_t*)v.ptr) + offn;
        switch(v.type)
        {
            case(1):
                PutToBuf((*(uint8_t*)off)/255.f);  // only for colors?
                break;
            case(2):
                PutToBuf(FloatToU32((*(uint16_t*)off)));  // / 65535. ?
                break;
            case(4):
            {
                PutToBuf(*(float*)off);
                break;
            }
            default:
                assert(false);
        }
    }

    if (array == PGL_VERTEX_ARRAY && v.size == 2)
    {
        // add zero z
        PutToBuf(FloatToU32(0.));
    }
}

// Copy data from vertex arrays in client memory to command buffer (glDrawArrays & glDrawElements)
void PseudoGLContext::CopyDrawArray(int first, int count, int mode, const void *indices, int indice_size)
{
    // Add matrices to command buffer
    if (matrices[PGL_MODEL_MATRIX]->CheckDirty())
    {
        PutToBuf(GPU_PIPE_CMD_MODEL_MATRIX, true);
        PutMatrixToBuffer(*matrices[PGL_MODEL_MATRIX]);
        if (lighting_enabled)
        {
            // calculate normal matrix on every model matrix change (could be optimized!)
            // normal matrix is inverted & transposed model matrix
            PglMatrix normal_mx = *matrices[PGL_MODEL_MATRIX];
            normal_mx.Invert();
            normal_mx.Transpose();
            PutToBuf(GPU_PIPE_CMD_NORMAL_MATRIX, true);
            PutMatrixToBuffer(normal_mx);
        }
    }

    if (matrices[PGL_PROJ_MATRIX]->CheckDirty())
    {
        PutToBuf(GPU_PIPE_CMD_PROJ_MATRIX, true);
        PutMatrixToBuffer(*matrices[PGL_PROJ_MATRIX]);
    }

    // Add lighting & global states
    if (lighting_enabled && lighting_dirty)
    {
        PutToBuf(GPU_PIPE_CMD_LIGHT_STATE, true);
        PutToBuf(lighting_enabled ? GPU_STATE_LIGHT_ENABLE : 0);

        PutToBuf(GPU_PIPE_CMD_LIGHT_PARAMS);
        for (int i = 0; i < 4; i++)
            PutToBuf(FloatToU32(light_params.pos[i]));
        for (int i = 0; i < 4; i++)
            PutToBuf(FloatToU32(light_params.diffuse_color[i]));
        lighting_dirty = false;
    }

    // Add state commands if needed
    if (viewport_dirty)
    {
        PutToBuf(GPU_PIPE_CMD_VIEWPORT_PARAMS, true);
        PutToBuf(viewport_params.x);
        PutToBuf(viewport_params.y);
        PutToBuf(FloatToU32(viewport_params.w/2.));
        PutToBuf(FloatToU32(viewport_params.h/2.));        
        PutToBuf(FloatToU32((depthrange_params.f - depthrange_params.n)/2.));
        PutToBuf(FloatToU32((depthrange_params.n + depthrange_params.f)/2.));
        viewport_dirty = false;
    }

    if (rast_state_dirty)
    {
        PutToBuf(GPU_PIPE_CMD_RAST_STATE, true);
        assert(!(cull_face & ~GPU_STATE_RAST_CULLMASK));
        uint8_t face = cull_face;
        if (!front_face && cull_face && cull_face != GPU_STATE_RAST_CULLMASK)
            face = (~cull_face) & GPU_STATE_RAST_CULLMASK;  // invert culling in case of CW
        uint32_t state = (culling_enabled ? face : GPU_STATE_RAST_CULLMASK);
        PutToBuf(state);

        rast_state_dirty = false;
    }

    if (frag_state_dirty)
    {
        PutToBuf(GPU_PIPE_CMD_FRAG_STATE);
        uint32_t state = (depth_enabled ? GPU_STATE_FRAG_DEPTH : 0) |
                (depth_masked ? GPU_STATE_FRAG_DEPTHMASK : 0) |
                (alpha_enabled ? GPU_STATE_FRAG_ALPHA : 0) |
                (blend_enabled ? GPU_STATE_FRAG_BLEND : 0);
        state |= (blend_params.src << GPU_STATE_FRAG_BLENDSF_SHIFT) | (blend_params.dst << GPU_STATE_FRAG_BLENDDF_SHIFT);
        PutToBuf(state);

        frag_state_dirty = false;
    }

    // Generate vertex commands
    if (mode == GL_TRIANGLE_STRIP || mode == GL_TRIANGLE_FAN)
    {
        assert(count >= 3);
        count = 3 + (count-3)*3;
    }
    else
        assert(count%3 == 0);

    int n = 0;
    int so = 0;
    for (int i = first; i < first+count; i++)
    {
        int vi = (i - first) % 3;
        if (vi == 0)
        {
            assert(!(texcoord_array.enabled && normal_array.enabled));
            uint32_t cmd = GPU_PIPE_CMD_POLY_VERTEX3;
            if (texcoord_array.enabled)
                cmd = GPU_PIPE_CMD_POLY_VERTEX3TC;
            else if (lighting_enabled && normal_array.enabled) 
                cmd = GPU_PIPE_CMD_POLY_VERTEX3N3;

            PutToBuf(cmd, true);
            if (i != first)
            {
                n++;    // count triangles
                if (mode == GL_TRIANGLE_STRIP || mode == GL_TRIANGLE_FAN)
                    so -= 2;
            }
        }
        
        int vo = so;
        if ((mode == GL_TRIANGLE_STRIP) && (n & 1))
        {
            // calculate offset for strip vertex
            if (vi == 0)
                vo = so + 1;
            else if (vi == 1)
                vo = so - 1;
        }
        else if (mode == GL_TRIANGLE_FAN)
        {
            if (vi == 0)
                vo = -n*3;
        }
        
        // write vertex to buffer
        assert(vertex_array.enabled);

        if (vertex_array.enabled)
        {
            PutVertexDataToBuffer(PGL_VERTEX_ARRAY, vo, i, indices, indice_size);
        }

        if (lighting_enabled)
        {
            for (int c = 0; c < 4; c++)
                PutToBuf(FloatToU32(material_params.ambient_color[c]));
            if (lighting_supported)
                for (int c = 0; c < 4; c++)
                    PutToBuf(FloatToU32(material_params.diffuse_color[c]));
        }
        else 
        {
            if (color_array.enabled)
            {
                PutVertexDataToBuffer(PGL_COLOR_ARRAY, vo, i, indices, indice_size);
            }
            else 
            {
                for (int c = 0; c < 4; c++)
                    PutToBuf(FloatToU32(cur_color[c]));
            }
        }

        if (normal_array.enabled)  
        {  
            PutVertexDataToBuffer(PGL_NORMAL_ARRAY, vo, i, indices, indice_size);
        }

        if (texcoord_array.enabled)  
        {  
            PutVertexDataToBuffer(PGL_TEXCOORD_ARRAY, vo, i, indices, indice_size);
        }

        assert(buffer_elements < PGL_MAX_CMD_BUF_ELEMENTS);
    }
}

// Push matrix to stack
void PseudoGLContext::PushMatrix()
{
    assert(matrices[cur_matrix] - matrix_stack[cur_matrix] < PGL_MATRIX_STACK_DEPTH);

    *(matrices[cur_matrix] + 1) = *matrices[cur_matrix];
    matrices[cur_matrix]++;
}

// Pop matrix from stack
void PseudoGLContext::PopMatrix()
{
    assert(matrices[cur_matrix] > matrix_stack[cur_matrix]);
    matrices[cur_matrix]--;
}

// Set light color
void PseudoGLContext::SetLightPosition(int light, const float pos[4])
{
    assert(light == 0); 
    assert(pos[3] == 0.f); // only w=0 is supported for now!
    light_params.pos.Set(pos);
    light_params.pos.MulM4(*matrices[PGL_MODEL_MATRIX]); // calculate eye coordinates
    light_params.pos.Normalize();
    lighting_dirty = true;
}

// Set light position
void PseudoGLContext::SetLightColor(int light, const float color[4])
{
    assert(light == 0);
    light_params.diffuse_color.Set(color);
    lighting_dirty = true;
}

// Add commands to buffer to bind texture in hw
void PseudoGLContext::BindHWTexture() 
{
    PutToBuf(GPU_PIPE_CMD_BINDTEXTURE, true);
    PutToBuf(textures[binded_texture].gpu_ptr & GPU_ADDR_MASK);
    PutToBuf(textures[binded_texture].width | (textures[binded_texture].height << 16));
}

// Bind texture in client & hw
void PseudoGLContext::BindTexture(TexId tex) 
{
    assert(tex < PGL_MAX_TEXTURES); 
    binded_texture = tex; 
    if (textures[binded_texture].gpu_ptr)
        BindHWTexture();
}

// Create texture structure
void PseudoGLContext::AllocTexture(const uint format, const uint width, const uint height)
{
    assert(width <= PGL_MAX_TEXTURE_SIZE && height <= PGL_MAX_TEXTURE_SIZE);

    TextureState &tex = textures[binded_texture];
    tex.width = width;
    tex.height = height;
    tex.format = format;
}

// Fill/change texture structure
void PseudoGLContext::SetTexture(const uint format, const uint type)
{
    TextureState &tex = textures[binded_texture];

    uint vpp = 0;
    uint size = 0;
    switch (tex.format)
    {
        case (GL_RGB):
            switch (type)
            {
                case (GL_UNSIGNED_BYTE):
                    vpp = 3;
                    size = 1;
                    break;
                case (GL_UNSIGNED_SHORT_5_6_5):
                    vpp = 1;
                    size = 2;
                    break;
                default:
                    assert(false);
            }
            break;        
        case (GL_RGBA):
            switch (type)
            {
                case (GL_UNSIGNED_BYTE):
                    vpp = 4;
                    size = 1;
                    break;
                case (GL_UNSIGNED_SHORT_4_4_4_4):
                    vpp = 1;
                    size = 2;
                    break;
                default:
                    assert(false);
            }
            break;        
        case (GL_LUMINANCE):
            assert(type == GL_UNSIGNED_BYTE);
            vpp = 1;
            size = 1;
            break;        
        case (GL_LUMINANCE_ALPHA):
            assert(type == GL_UNSIGNED_BYTE);
            vpp = 2;
            size = 1;
            break;
        default:
            assert(false);
    }
    assert(vpp*size > 0);
    
    tex.vpp = vpp;
    tex.size = size;
    tex.format = format;
    tex.type = type;
}

// Copy texture to hw memory
void PseudoGLContext::LoadTexture(const uint8_t* pixels, const uint xoff, const uint yoff, const uint width, const uint height) 
{
    assert(pixels); 
    
    // Copy texture to GPU memory
    TextureState &tex = textures[binded_texture];
    
    // primitive "GPU memory management", just alloc, never free
    if (!tex.gpu_ptr)
    {
        tex.gpu_ptr = gpu_freemem_ptr;
        gpu_freemem_ptr += tex.width*tex.height*4;
    }

    #if LOAD_TEXTURES
    for (uint y = 0; y < height; y++)
    {
        for (uint x = 0; x < width; x++)
        {
            const uint8_t *ptr = pixels + (y * width + x)*tex.size*tex.vpp;
            uint32_t gpu_off = tex.gpu_ptr + ((yoff+y) * tex.width + (x+xoff))*4;
            
            if (tex.size == 1)
            {
                if (tex.format == GL_RGB || tex.format == GL_RGBA)
                {
                    uint32_t word = *(const uint32_t*)ptr | (tex.vpp==3 ? 0xFF000000 : 0);
                    oglory_mem_write32(word, gpu_off);
                }
                else if (tex.format == GL_LUMINANCE || tex.format == GL_LUMINANCE_ALPHA)
                {
                    uint8_t l = *ptr;
                    oglory_mem_write32(l | (l<<8) | (l<<16) | (tex.vpp==1 ? 0xFF000000 : *(ptr + 1) << 24), gpu_off);
                }
                else
                    assert(false);
            }
            else if (tex.size == 2)
            {
                uint16_t word = *(const uint16_t*)ptr;
                uint32_t r, g, b, a;
                if (tex.type == GL_UNSIGNED_SHORT_5_6_5)
                {
                    b = ((word & 0x001F) >>  0) * 255 / 31;
                    g = ((word & 0x07E0) >>  5) * 255 / 63;
                    r = ((word & 0xF800) >> 11) * 255 / 31;
                    a = 0xFF;
                }
                else if (tex.type == GL_UNSIGNED_SHORT_4_4_4_4)
                {
                    a = ((word & 0x000F) >>  0) * 255 / 15;
                    b = ((word & 0x00F0) >>  4) * 255 / 15;
                    g = ((word & 0x0F00) >>  8) * 255 / 15;
                    r = ((word & 0xF000) >> 12) * 255 / 15;
                }
                else
                    assert(false);
                oglory_mem_write32(r | (g<<8) | (b<<16) | (a<<24), gpu_off);
            }
            else
                assert(false);
        }
    }
    #endif

    BindHWTexture();
}