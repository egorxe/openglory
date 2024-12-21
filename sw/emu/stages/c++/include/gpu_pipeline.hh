#ifndef _GPU_PIPELINE_HH
#define _GPU_PIPELINE_HH

#include <cstdint>
#include <algorithm>

// custom typedefs
typedef float Vec2[2]; 
typedef float Vec3[3]; 
typedef float Vec4[4]; 
typedef unsigned char Rgb[3]; 

struct M4 {
    float m[4][4];
};

// Helper routines
static inline void CopyV2(Vec2 &destination, const Vec2 &source)
{
    for (int i = 0; i < 2; i++)
        destination[i] = source[i];
}

static inline void CopyV3(Vec3 &destination, const Vec3 &source)
{
    for (int i = 0; i < 3; i++)
        destination[i] = source[i];
}

static inline void CopyV4(Vec4 &destination, const Vec4 &source)
{
    for (int i = 0; i < 4; i++)
        destination[i] = source[i];
}

static inline uint32_t ArgbToU32(uint32_t a, uint32_t r, uint32_t g, uint32_t b)
{
    return (a << 24) | (r << 16) | (g << 8) | b;
}

static inline uint32_t ArgbToU32(float a, float r, float g, float b)
{
    return ArgbToU32((uint32_t)(a * 255), (uint32_t)(r * 255), (uint32_t)(g * 255), (uint32_t)(b * 255));
}

static inline float Clamp(const float x)
{
    return std::max(std::min(x, 1.0f), 0.0f);
}

enum { X, Y, Z, W };    // coords enum
#define PIPELINE_MAX_Z      ((1<<24)-1)

#include <iofifo.hh> 
#include <oglory_gpu_defs.hh> 

#if VERBOSE
#define verbose(...) printf(__VA_ARGS__)
#else
#define verbose(...)
#endif

#endif
