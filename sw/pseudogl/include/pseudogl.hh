// OpenGLES-like API for OpenGlory pseudoGPU

#ifndef _PSEUDOGL_HH
#define _PSEUDOGL_HH

#include <iostream>
#include <functional>
#include <array>
#include <thread>
#include <cstring>
#include <cassert>

#include "pgl_math.hh"

const size_t PGL_MAX_CMD_BUFFERS        = 9;    // ! should be at least cmd fifo length +1
const size_t PGL_MAX_CMD_BUF_ELEMENTS   = 1024;
const size_t PGL_MAX_CMD_LEN            = 48;
const size_t PGL_MATRIX_STACK_DEPTH     = 64;
const size_t PGL_MAX_TEXTURES           = 512;
const size_t PGL_MAX_TEXTURE_SIZE       = 1024;

const int PGL_WND_SIZE_X = 640;
const int PGL_WND_SIZE_Y = 480;

enum
{
    PGL_MODEL_MATRIX,
    PGL_PROJ_MATRIX,

    PGL_MATRIX_NUM
};

enum
{
    PGL_VERTEX_ARRAY,
    PGL_COLOR_ARRAY,
    PGL_NORMAL_ARRAY,
    PGL_TEXCOORD_ARRAY,

    PGL_VERTEX_ARRAYS
};

struct VertexArrayState
{
    bool enabled;
    int size;
    int type;
    size_t stride;
    const float *ptr;
};

typedef std::array<VertexArrayState, PGL_VERTEX_ARRAYS> VertexArraysStates;

typedef PglVec4 Color;
typedef PglVec4 Position4;

struct LightParams
{
    Position4 pos;
    Color diffuse_color;
};

struct MaterialParams
{
    Color ambient_color;
    Color diffuse_color;
};

struct ViewportParams
{
    uint x;
    uint y;
    float w;
    float h;
};

struct DepthRangeParams
{
    float n;
    float f;
};

struct BlendParams
{
    uint8_t src;
    uint8_t dst;
};

typedef uint32_t TexId;

struct TextureState
{
    uint width;
    uint height;
    uint vpp;
    uint size;
    uint format;
    uint type;
    uint32_t gpu_ptr;
};

typedef std::array<TextureState, PGL_MAX_TEXTURES> TextureArray;

class PseudoGLContext
{
    public:
    PseudoGLContext();

    // Interface functions
    void SetVertexArray(int array, int size, int type, size_t stride, const float* ptr);
    void SetVertexArrayEnabled(int array, bool e);
    void CopyDrawArray(int first, int count, int mode, const void *indices = nullptr, int indice_size = 0);

    void SelCurMatrix(int mx_num) {cur_matrix = mx_num;}
    void LoadMatrix(const PglMatrix &m) {*matrices[cur_matrix] = m; matrices[cur_matrix]->SetDirty();}
    void MultMatrix(const PglMatrix &m) {matrices[cur_matrix]->MulLeft(m);}
    void PopMatrix();
    void PushMatrix();

    void SetLightPosition(int light, const float pos[4]);
    void SetLightColor(int light, const float color[4]);
    void SetMaterialDiffuse(const float material[4]) {material_params.diffuse_color.Set(material);};
    void SetMaterialAmbient(const float material[4]) {material_params.ambient_color.Set(material);};
    void SetCurColor(const Color &color) {cur_color = color;}

    void SetLighting(bool v) {lighting_enabled = v; lighting_dirty = true;}
    void SetCulling(bool v) {culling_enabled = v; rast_state_dirty = true;}
    void SetCullingFace(uint8_t f) {cull_face = f; rast_state_dirty = true;}
    void SetFrontFace(bool v) {front_face = v; rast_state_dirty = true;}
    void SetDepthTest(bool v) {depth_enabled = v; frag_state_dirty = true;}
    void SetDepthMask(bool v) {depth_masked = v; frag_state_dirty = true;}
    void SetAlphaTest(bool v) {alpha_enabled = v; frag_state_dirty = true;}
    void SetBlending(bool v) {blend_enabled = v; frag_state_dirty = true;}

    void SetViewport(ViewportParams vp) {viewport_params = vp; viewport_dirty = true;}
    void SetDepthRange(DepthRangeParams drp) {depthrange_params = drp; viewport_dirty = true;}
    void SetBlendFunc(BlendParams bp) {blend_params = bp; frag_state_dirty = true;}

    uint32_t GenTexture() {assert(new_texture_id < PGL_MAX_TEXTURES); return new_texture_id++;}
    void BindHWTexture();
    void BindTexture(TexId tex);
    void AllocTexture(const uint format, const uint width, const uint height);
    void SetTexture(const uint format, const uint type);
    void LoadTexture(const uint8_t* pixels, const uint xoff, const uint yoff, const uint width, const uint height);

    const char* GetBoardName() const {return board_name.c_str();}

    void SwapBuffers();
    void ClearBuffer(bool clear_fb, bool clear_zb);
    void PipelineFlushAsync() {PipelineFlush();}
    void CommitCmdBuffer();

    private:
    // Internal helper funcs
    static uint32_t FloatToU32(float f) {return *(uint32_t*)(&f);}
    static uint32_t GetValWithSize(const void* ptr, int size, int off);

    void PutToBuf(uint32_t w, bool committable = false);
    void PutToBuf(float f) {PutToBuf(FloatToU32(f));}
    void PutMatrixToBuffer(PglMatrix &m);
    void PutStateToBuffer();
    void PutVertexDataToBuffer(int array, int vo, int i, const void *indices, int indice_size);
    
    void SleepMs(int ms) {std::this_thread::sleep_for(std::chrono::milliseconds(ms));}

    void Profile();
    void PipelineFlush();

    // Draw array variables
    VertexArraysStates vertex_arrays;
    VertexArrayState &vertex_array;
    VertexArrayState &color_array;
    VertexArrayState &normal_array;
    VertexArrayState &texcoord_array;

    // State variables
    Color cur_color;
    LightParams light_params;
    MaterialParams material_params;
    ViewportParams viewport_params;
    DepthRangeParams depthrange_params;
    BlendParams blend_params;

    uint8_t cull_face;
    bool front_face;

    bool rast_state_dirty;
    bool frag_state_dirty;
    bool lighting_dirty;
    bool viewport_dirty;

    bool lighting_enabled;
    bool depth_enabled;
    bool depth_masked;
    bool culling_enabled;
    bool alpha_enabled;
    bool blend_enabled;

    // Texture variables
    TexId new_texture_id;
    TexId binded_texture;
    TextureArray textures;

    // Matrix variables
    int cur_matrix;
    PglMatrix* matrices[PGL_MATRIX_NUM];
    PglMatrix matrix_stack[PGL_MATRIX_NUM][PGL_MATRIX_STACK_DEPTH];

    // Device variables
    uint32_t capabilities;
    bool lighting_supported;
    std::string board_name;
    uint32_t cmd_buffer[PGL_MAX_CMD_BUF_ELEMENTS];
    int current_dev_buf;
    uint32_t dev_buf_ptr[PGL_MAX_CMD_BUFFERS];
    int buffer_elements;
    uint32_t gpu_freemem_ptr;

    // Profile vars
    int frame_cnt;
    int profile, profile_cnt;
    int input_to_vertex_valid, vertex_to_rast_valid, rast_to_cc_valid, cc_to_tex_valid, tex_to_frag_valid;
    int tex_wb, frag_wb, fb_wb;
};

#endif    /* _PSEUDOGL_HH */
