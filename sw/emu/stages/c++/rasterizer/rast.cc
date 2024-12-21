#include <cstdio> 
#include <cstdlib> 
#include <cstring>  
#include <cmath>  
#include <unistd.h>  

#include <functional> 

#include <gpu_pipeline.hh> 

IoFifo *iofifo;

bool draw_front = true;
bool draw_back = true;

#if VERBOSE
void printVertex(const float *coords, const float *colors) {
    int i = 0;
    printf("{");
    for (i = 0; i < 4; ++i) printf("%f, ", coords[i]);
    for (i = 0; i < 3; ++i) printf("%f, ", colors[i]);
    printf("%f}", colors[3]); 
}

void printPolygon(const float *coords, const float *colors) {
    int i = 0;
    for (i = 0; i < 3; ++i) {
        printf("Point %d:", i + 1);
        printVertex(&coords[4*i], &colors[4*i]);
        printf("\n");
    }
}
#endif

// Matches edge function in HDL: E_01(P)=(V0.y*V1.x-V0.x*V1.y)+P.y*(V0.x-V1.x)+P.x*(V1.y-V0.y)
float edgeFunction(const Vec4 &a, const Vec4 &b, const Vec4 &c) 
{ 
    // uses FMACs to get same precision
    float cached0 = fmaf(-a[0], b[1], (a[1] * b[0]));
    float cached1 = (a[0] - b[0]);
    float cached2 = (b[1] - a[1]);
    float cached3 = fmaf(c[1], cached1, cached0);
    float edge = fmaf(c[0], cached2, cached3);
    return edge;
} 

int32_t MinCoord(float x0, float x1, float x2, int32_t lo, int32_t hi)
{
    int32_t min = std::min(std::min(x0, x1), x2);
    if (min > hi)
        return -1;
    else
    {
        int32_t max = std::max(min, lo);
        return max;
    }
} 

int32_t MaxCoord(float x0, float x1, float x2, int32_t lo, int32_t hi)
{
    int32_t max = std::max(std::max(x0, x1), x2);
    if (max < lo)
        return -1;
    else
    {
        int32_t min = std::min(max+1, hi);
        return min;
    }
}

// Calculate vertex attribs with FMACs to align precision with hardware
float fmac_attribs(float v0, float v1, float v2, float w0, float w1, float w2)
{
    return fmaf(w2, v2, fmaf(w1, v1, w0*v0));
}

float check_zero_edge(float w)
{
    //const float ZERO_VAL = 0.0078125; // exp = 120
    const float ZERO_VAL = 0.001953125; // exp = 118
    return (fabs(w) < ZERO_VAL) ? 0. : w;
}

// Single polygon rasterization
int polygon_cnt = 0;
extern "C"
int rasterize(float* polygon, u_int32_t* fragments, int SCREEN_WIDTH, int SCREEN_HEIGHT, bool do_texture) 
{
    int fragments_amount = 0;
    
    // Read input vertices & colors
    float vertices[3*4];
    float colors[3*4];
    float texcoord[3*2];
    
    // three vertices per polygon
    for (int vertex = 0; vertex < 3; ++vertex)
    {
        // four coords per vertex
        for (int i = 0; i < 4; ++i)
            vertices[vertex*4+i] = 
                #if BUILD_BINARY
                iofifo->ReadFromFifoFloat();
                #else
                polygon[vertex*8 + i];
                #endif
        
        // four color floats per vertex
        for (int i = 0; i < 4; ++i)
            colors[vertex*4+i] =
                #if BUILD_BINARY
                iofifo->ReadFromFifoFloat();
                #else
                polygon[vertex*8 + 4 + i];
                #endif
        
        // two tex coords per vertex
        if (do_texture)
        {
            for (int i = 0; i < 2; ++i)
                texcoord[vertex*2+i] = iofifo->ReadFromFifoFloat();
        }
    }
    
    #if VERBOSE
    printf("Checking polygon\n");
    printPolygon(vertices, colors);
    #endif

    // Polygon vertices
    Vec4 v0, v1, v2;
    for (int i = 0; i < 4; ++i)
        v0[i] = vertices[0+i];
    for (int i = 0; i < 4; ++i)
        v1[i] = vertices[4+i];
    for (int i = 0; i < 4; ++i)
        v2[i] = vertices[8+i];
    
    float area = edgeFunction(v0, v1, v2); 
    
    // drop degenerate triangles
    if (fabs(area) < 1.0)
        return 0;
        
    bool front_face = (area < 0);
    
    // cull faces
    if ((!front_face && !draw_back) || (front_face && !draw_front))
        return 0;
        
    // calc area reciprocal
    area = 1. / area;
    
    // Calculate bounding box (min & max coords for triangle vertexes), if -1 - triangle is out of screen
    int32_t xmin = MinCoord(v0[0], v1[0], v2[0], 0, SCREEN_WIDTH-1);
    int32_t ymin = MinCoord(v0[1], v1[1], v2[1], 0, SCREEN_HEIGHT-1);
    int32_t xmax = MaxCoord(v0[0], v1[0], v2[0], 0, SCREEN_WIDTH-1);
    int32_t ymax = MaxCoord(v0[1], v1[1], v2[1], 0, SCREEN_HEIGHT-1);

    if (xmin < 0 || ymin < 0 || xmax < 0 || ymax < 0) return 0; // skip out-of-screen triangles
    
    // Clamp colors
    for (int i = 0; i < 3*4; i++)
        colors[i] = (colors[i] < 0.) ? 0 : (colors[i] > 1.) ? 1. : colors[i];
    
    // Divide colors & texcoords on w coord in advance
    Vec4 c0 = {colors[0]*v0[3], colors[1]*v0[3], colors[2]*v0[3], colors[3]*v0[3]}; 
    Vec4 c1 = {colors[4]*v1[3], colors[5]*v1[3], colors[6]*v1[3], colors[7]*v1[3]}; 
    Vec4 c2 = {colors[8]*v2[3], colors[9]*v2[3], colors[10]*v2[3], colors[11]*v2[3]};
    Vec2 tc0 = {texcoord[0]*v0[3], texcoord[1]*v0[3]}; 
    Vec2 tc1 = {texcoord[2]*v1[3], texcoord[3]*v1[3]}; 
    Vec2 tc2 = {texcoord[4]*v2[3], texcoord[5]*v2[3]}; 
    
    for (uint32_t y = ymin; y <= ymax; ++y) 
    { 
        for (uint32_t x = xmin; x <= xmax; ++x) 
        { 
            verbose("Checking point x = %d (%d, %d), y = %d (%d, %d)\n", x, xmin, xmax, y, ymin, ymax); 
            Vec4 p = {x + 0.5f, y + 0.5f, 0, 0}; 
            float w0 = check_zero_edge(edgeFunction(v1, v2, p)); 
            float w1 = check_zero_edge(edgeFunction(v2, v0, p)); 
            float w2 = check_zero_edge(edgeFunction(v0, v1, p));

            verbose("area = %f, front_face = %d, w0 = %f, w1 = %f, w2 = %f\n", area, front_face, w0, w1, w2);
            if (((w0 >= 0.f && w1 >= 0.f && w2 >= 0.f) && !front_face) ||
               ((w0 <= 0.f && w1 <= 0.f && w2 <= 0.f) && front_face))
            {
                float fz = (v0[2] * w0 + v1[2] * w1 + v2[2] * w2) * area;
                
                if (fz < 0 || fz > 1)
                    continue;
                    
                uint32_t z = (uint32_t)(fz * PIPELINE_MAX_Z) & PIPELINE_MAX_Z;
                    
                // calculate pixel attributes
                float wn = 1. / fmac_attribs(v0[3], v1[3], v2[3], w0, w1, w2);
                    
                if (!do_texture)
                {
                    float r = fmac_attribs(c0[0], c1[0], c2[0], w0, w1, w2) * wn; 
                    float g = fmac_attribs(c0[1], c1[1], c2[1], w0, w1, w2) * wn; 
                    float b = fmac_attribs(c0[2], c1[2], c2[2], w0, w1, w2) * wn; 
                    float a = fmac_attribs(c0[3], c1[3], c2[3], w0, w1, w2) * wn; 
                    
                    iofifo->WriteFragment(x, y, z, r, g, b, a);   
                }
                else
                {
                    float t_x = fmac_attribs(tc0[0], tc1[0], tc2[0], w0, w1, w2) * wn;
                    float t_y = fmac_attribs(tc0[1], tc1[1], tc2[1], w0, w1, w2) * wn;
                    iofifo->WriteTexFragment(x, y, z, t_x, t_y);   
                }
                
                #if 0
                #if BUILD_BINARY
                iofifo->WriteFragment(x, y, z, r, g, b);   
                #else
                fragments[fragments_amount*5] = GPU_PIPE_CMD_FRAGMENT;
                fragments[fragments_amount*5 + 1] = x;
                fragments[fragments_amount*5 + 2] = y;
                fragments[fragments_amount*5 + 3] = z;
                fragments[fragments_amount*5 + 4] = ((u_int32_t)(r * 255) << 16) | ((u_int32_t)(g * 255) << 8) | (u_int32_t)(b * 255);
                fragments_amount++;
                #endif
                #endif
            } 
        } 
    }
    
    iofifo->Flush();
    
    return fragments_amount;
} 

#if BUILD_BINARY
int main(int argc, char **argv) 
{
    if (argc != 5)
    {
        puts("Wrong parameters!");
        return 1;
    }
    
    const uint32_t SCREEN_WIDTH     = atoi(argv[1]); 
    const uint32_t SCREEN_HEIGHT    = atoi(argv[2]);
        
    // Open output FIFO
    iofifo = new IoFifo(argv[3], argv[4]);
    int first = 1;
    while (1)
    {
        bool do_texture = false;
        uint32_t cmd = iofifo->ReadFromFifo32();
        switch (cmd)
        {
            case (GPU_PIPE_CMD_POLY_VERTEX4TC):
                do_texture = true;
            case (GPU_PIPE_CMD_POLY_VERTEX4):
            {
                rasterize(nullptr, nullptr, SCREEN_WIDTH, SCREEN_HEIGHT, do_texture); 
                polygon_cnt++;
                break;
            }
            case (GPU_PIPE_CMD_RAST_STATE):
            {
                uint32_t state_word = iofifo->ReadFromFifo32();
                draw_front = state_word & GPU_STATE_RAST_CULLBACK;
                draw_back = state_word & GPU_STATE_RAST_CULLFRONT;
                break;
            }
            //case (GPU_PIPE_CMD_SYNC):
                //if (first)
                    //first = 0;
                //else
                    //while(1);
            default:
            {
                // just pass to next stage everything but polygon vertices
                assert((cmd & 0xFFFF0000) == 0xFFFF0000);
                iofifo->BypassCmd(cmd);
                break;
            }
        }
        
    }
 
    return 0; 
} 
#endif
