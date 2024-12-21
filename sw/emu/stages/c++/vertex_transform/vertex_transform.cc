#include <cstdio> 
#include <cstdlib> 
#include <cstring>  
#include <unistd.h>  

#include <cmath>  

#include <functional> 

//#define PRINT_FIFO 1
#include <gpu_pipeline.hh> 

#define PERSPECTIVE_CORRECT     1
#define TEST_MATRIXES           0


M4 model_matrix;
M4 proj_matrix;
M4 normal_matrix;

uint32_t viewport_x0, viewport_y0;
float viewport_size_x, viewport_size_y;
float depthtest_fn2, depthtest_nf2;

// TGL function declarations
void gl_M4_MulV4(Vec4 a, M4* b, Vec4 c) ;
void gl_M4_MulLeft(M4* c, M4* b);
void gl_M4_Transpose(M4* a, M4* b);
void glRotate(float angle, float x, float y, float z, bool verbose=false);

// Clipping interpolation functions
float Interpolate(float v0, float v1, float t)
{
    return v0 + t * (v1 - v0);
}

void InterpolateV4(const Vec4 &p1, const Vec4 &p2, const float t, Vec4 &vertex_out)
{
    for (int i = 0; i < 4; i++)
        vertex_out[i] = Interpolate(p1[i], p2[i], t);
}

void InterpolateV2(const Vec2 &p1, const Vec2 &p2, const float t, Vec2 &vertex_out)
{
    for (int i = 0; i < 2; i++)
        vertex_out[i] = Interpolate(p1[i], p2[i], t);
}

//Clip against plane w=W_CLIPPING_PLANE
int ClipPolygonOnWAxis(Vec4 polygon[], Vec4 colors[], Vec2 texcoord[])
{
    const float W_CLIPPING_PLANE = 0.00012207031;   // exp = 114
    const int MVPCP = 4; // max vertices per clipped polygon
    
    // check for trivial cases
    if (polygon[0][W] >= W_CLIPPING_PLANE && polygon[1][W] >= W_CLIPPING_PLANE && polygon[2][W] >= W_CLIPPING_PLANE)
        return 1;
    else if (polygon[0][W] < W_CLIPPING_PLANE && polygon[1][W] < W_CLIPPING_PLANE && polygon[2][W] < W_CLIPPING_PLANE)
        return 0;
        
    Vec4* curr_vertex;
    Vec4* prev_vertex;

    unsigned char output_count=0;
    Vec4 clipped_vertices[MVPCP];
    Vec4 clipped_colors[MVPCP];
    Vec2 clipped_texcoord[MVPCP];

    char prev_inside;
    char curr_inside;
    float t;

    int p = 2;
    prev_vertex = &polygon[p];
    prev_inside = ((*prev_vertex)[W] >= W_CLIPPING_PLANE);

    for (int i = 0; i < 3; i++)
    {
        curr_vertex = &polygon[i];
        curr_inside = ((*curr_vertex)[W] >= W_CLIPPING_PLANE);
         
        if (prev_inside)
        {
            // Insert previous vertex
            CopyV4(clipped_vertices[output_count], *prev_vertex);
            CopyV4(clipped_colors[output_count], colors[p]);
            CopyV2(clipped_texcoord[output_count], texcoord[p]);
            output_count++;
        }
    
        if (prev_inside != curr_inside)
        {
            // Need to clip against plane w=0
            
            // Calculate clipping factor t = (W_CLIP_VAL - Wp) / (Wc - Wp)
            t = (W_CLIPPING_PLANE - (*prev_vertex)[W] ) / ((*curr_vertex)[W] - (*prev_vertex)[W]);
            
            // Interpolate coords and attributes: An = Ap + t(Ac-Ap)
            InterpolateV4(*prev_vertex, *curr_vertex, t, clipped_vertices[output_count]);
            InterpolateV4(colors[p], colors[i], t, clipped_colors[output_count]);
            InterpolateV2(texcoord[p], texcoord[i], t, clipped_texcoord[output_count]);
            
            output_count++;
        }
        
        // Next vertex
        p = i;
        prev_vertex = curr_vertex;
        prev_inside = curr_inside;
    }

    // Copy clipped_vertices into the source polygon
    #define CopyClipped(x, y) {CopyV4(polygon[x], clipped_vertices[y]); CopyV4(colors[x], clipped_colors[y]); CopyV2(texcoord[x], clipped_texcoord[y]); }
    CopyClipped(0, 0);
    CopyClipped(1, 1);
    CopyClipped(2, 2);

    if (output_count == 4)
    {
        CopyClipped(3, 0);
        CopyClipped(4, 2);
        CopyClipped(5, 3);
    }
    #undef CopyClipped
    
    return output_count-2;
}

// Viewport transformation
void ViewportTransform(Vec4 &s, uint32_t x0, uint32_t y0, float size_x_2, float size_y_2, float fn2, float nf2)
{
    s[0] = size_x_2 * (s[0] + 1) + x0;
    s[1] = size_y_2 * (s[1] + 1) + y0;
    s[2] = fn2 * s[2] + nf2;
}

#if VERBOSE
void OutputVec4(Vec4 v) {
    int i = 0;
    printf("{");
    for (i = 0; i < 3; ++i) printf("%f, ", v[i]);
    printf("%f}\n", v[3]);
}
#else
#define OutputVec4(v)
#endif

// Vertex to clip coords
extern "C"
void ProcessVertexMatMul(const Vec3 vert_ptr, Vec4 &vertex_out)
{
    vertex_out[0] = vert_ptr[0];
    vertex_out[1] = vert_ptr[1];
    vertex_out[2] = vert_ptr[2];
    vertex_out[3] = 1;
    
    // multiply on model matrix
    gl_M4_MulV4(vertex_out, &model_matrix, vertex_out);
    
    // multiply on projection matrix
    gl_M4_MulV4(vertex_out, &proj_matrix, vertex_out);
}

// Clipped vertex to display coords
extern "C"
void ProcessVertexPostClip(Vec4 &vertex)
{
    assert(vertex[3] > 0);
    
    // replace W with its reciprocal as we'll only divide by it
    vertex[3] = 1/vertex[3];
    
    // normalize coordinates (produce NDC)
    vertex[0] = vertex[0]*vertex[3];
    vertex[1] = vertex[1]*vertex[3];
    vertex[2] = vertex[2]*vertex[3];

    ViewportTransform(vertex, viewport_x0, viewport_y0, viewport_size_x, viewport_size_y, depthtest_fn2, depthtest_nf2);
}

void ProcessNormal(Vec3 norm, Vec3 &normal_out, float *model_matrix_ptr)
{
    #if BUILD_LIB
    struct M4 model_matrix;
    for (int i = 0; i < 4; ++i)
        for (int j = 0; j < 4; ++j)
            model_matrix.m[i][j] = model_matrix_ptr[i*4 + j];
    #endif

    Vec4 normal = {norm[0], norm[1], norm[2], 0.f};
    
    // multiply on transposed model matrix
    gl_M4_MulV4(normal, &normal_matrix, normal);
    
    for (int i = 0; i < 3; i++)
        normal_out[i] = normal[i];
}

void gl_print_matrix(M4 m) {
    int i;

    for (i = 0; i < 4; i++) {
        printf("%f %f %f %f\n", m.m[i][0], m.m[i][1], m.m[i][2], m.m[i][3]);
    }
}

#if BUILD_BINARY
void WriteVertexToFifo(IoFifo &iofifo, const Vec4 v, const Vec4 colors)
{
    for (int i = 0; i < 4; ++i) {
        iofifo.WriteToFifoFloat(v[i]);
    }
    for (int i = 0; i < 4; ++i) {
        iofifo.WriteToFifoFloat(colors[i]);
    }
}

void WriteVertexToFifoLighting(IoFifo &iofifo, Vec4 v, const Vec4 colors, const Vec4 colors2, const Vec3 normal)
{
    WriteVertexToFifo(iofifo, v, colors);
    
    for (int i = 0; i < 4; ++i) {
        iofifo.WriteToFifoFloat(colors2[i]);
    }
    
    for (int i = 0; i < 3; ++i) {
        iofifo.WriteToFifoFloat(normal[i]);
    }
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
    
    viewport_size_x = SCREEN_WIDTH/2;
    viewport_size_y = SCREEN_HEIGHT/2;
    depthtest_fn2 = 0.5;
    depthtest_nf2 = 0.5;
        
    // Open output FIFO
    IoFifo iofifo(argv[3], argv[4]);
    
    // Create matrixes
    #if TEST_MATRIXES
    // for test
    // position on coordinate 3 on Z axis & rotate 45
    model_matrix = {{
         {0.804738, -0.310617, 0.505879, 0.000000},
         {0.505879, 0.804738 -0.310617, 0.000000},
         {-0.310617, 0.505879, 0.804738, -3.000000},
         {0.000000, 0.000000, 0.000000, 1.000000},
    }};
    // perspective projection from gluPerspective(45, 4./3., 0.1, 10);
    proj_matrix = {{
        {1.810660,  0,          0,          0           },
        {0,         2.414213,   0,          0           },
        {0,         0,          -1.020202,  -0.202020   },
        {0,         0,          -1.000000,  0           },
    }};
    #else
    model_matrix = {{
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1},
    }};
    
    proj_matrix = {{
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1},
    }};
    #endif

    #if VERBOSE
    printf("Model matrix:\n");
    gl_print_matrix(model_matrix);
    #endif
    
    while (1)
    {
        bool do_normals = false;
        bool do_texture = false;
        uint32_t cmd = iofifo.ReadFromFifo32();

        switch (cmd)
        {
            case GPU_PIPE_CMD_POLY_VERTEX3N3:
                do_normals = true;
                goto v3;
            case GPU_PIPE_CMD_POLY_VERTEX3TC:
                do_texture = true;
            case GPU_PIPE_CMD_POLY_VERTEX3:
            {
                v3:
                // Read input vertices & colors
                Vec3 vertices[3];
                Vec4 colors[3];
                Vec4 colors2[3];
                Vec3 normals[3];
                Vec2 texcoord[3];
                
                // three vertices per polygon
                for (int vertex = 0; vertex < 3; ++vertex)
                {
                    // three coords per vertex
                    for (int i = 0; i < 3; ++i)
                        vertices[vertex][i] = iofifo.ReadFromFifoFloat();

                    // four color floats per vertex
                    for (int i = 0; i < 4; ++i)
                        colors[vertex][i] = iofifo.ReadFromFifoFloat();

                    if (do_texture)
                    {
                        // two texcoord floats per vertex
                        for (int i = 0; i < 2; ++i)
                            texcoord[vertex][i] = iofifo.ReadFromFifoFloat();
                    }

                    if (do_normals)
                    {
                        // four additional colors in case of lighting
                        for (int i = 0; i < 4; ++i)
                            colors2[vertex][i] = iofifo.ReadFromFifoFloat();
                            
                        // three coords per normal
                        for (int i = 0; i < 3; ++i)
                            normals[vertex][i] = iofifo.ReadFromFifoFloat();
                    }
                }

                Vec4 polygon[3];

                // Process polygon vertices (pre-clipping)
                for (int v = 0; v < 3; ++v)
                    ProcessVertexMatMul(vertices[v], polygon[v]);
                
                // Clip polygons    
                Vec4 clip_polygon[3*2]; // maximum 2 polygons after clipping
                Vec4 clip_colors[3*2]; 
                Vec2 clip_texcoord[3*2];
                for (int v = 0; v < 3; ++v)
                { 
                    CopyV4(clip_polygon[v], polygon[v]);
                    CopyV4(clip_colors[v], colors[v]);
                    CopyV2(clip_texcoord[v], texcoord[v]);
                }
                                        
                int clipped_polygons;
                if (!(clipped_polygons = ClipPolygonOnWAxis(clip_polygon, clip_colors, clip_texcoord)))
                    continue;
                assert(clipped_polygons == 1 || clipped_polygons == 2);
                
                // Process clipped polygons
                for (int i = 0; i < clipped_polygons; ++i)
                {
                    for (int v = 0; v < 3; ++v)
                    {
                       CopyV4(polygon[v], clip_polygon[i*3 + v]);
                       CopyV4(colors[v], clip_colors[i*3 + v]);
                       CopyV2(texcoord[v], clip_texcoord[i*3 + v]);
                    }
                        
                    // Send relevant command
                    if (do_normals)
                        iofifo.WriteToFifo32(GPU_PIPE_CMD_POLY_VERTEX4N3);
                    else if (do_texture)
                        iofifo.WriteToFifo32(GPU_PIPE_CMD_POLY_VERTEX4TC);
                    else
                        iofifo.WriteToFifo32(GPU_PIPE_CMD_POLY_VERTEX4);
                        
                    // Pass resulting vertices to next stage
                    for (int v = 0; v < 3; ++v)
                    {
                        ProcessVertexPostClip(polygon[v]);
                        
                        if (do_normals) 
                        {
                            Vec3 normal;
                            ProcessNormal(normals[v], normal, nullptr);
                            WriteVertexToFifoLighting(iofifo, polygon[v], colors[v], colors2[v], normal);
                        }
                        else
                            WriteVertexToFifo(iofifo, polygon[v], colors[v]);
                        
                        if (do_texture)
                        {    
                            iofifo.WriteToFifoFloat(texcoord[v][0]);
                            iofifo.WriteToFifoFloat(texcoord[v][1]);
                        }
                    }
                }
                
                #if 0
                for (int j = 0; j < 4; ++j) printf("%f ", v0[j]);
                printf("\n");
                for (int j = 0; j < 4; ++j) printf("%f ", v1[j]);
                printf("\n");
                for (int j = 0; j < 4; ++j) printf("%f ", v2[j]);
                printf("\n\n");
                #endif
                
                iofifo.Flush();
                
                break;
            }

            case GPU_PIPE_CMD_MODEL_MATRIX:
            {
                for (int i = 0; i < 4; ++i)
                    for (int j = 0; j < 4; ++j)
                        model_matrix.m[i][j] = iofifo.ReadFromFifoFloat();
                break;
            }
            
            case GPU_PIPE_CMD_PROJ_MATRIX:
            {
                for (int i = 0; i < 4; ++i)
                    for (int j = 0; j < 4; ++j)
                        proj_matrix.m[i][j] = iofifo.ReadFromFifoFloat();
                break;
            }
            
            case GPU_PIPE_CMD_NORMAL_MATRIX:
            {
                for (int i = 0; i < 4; ++i)
                    for (int j = 0; j < 4; ++j)
                        normal_matrix.m[i][j] = iofifo.ReadFromFifoFloat();
                break;
            }
            
            case GPU_PIPE_CMD_VIEWPORT_PARAMS:
            {
                viewport_x0 = iofifo.ReadFromFifo32();
                viewport_y0 = iofifo.ReadFromFifo32();
                viewport_size_x = iofifo.ReadFromFifoFloat();
                viewport_size_y = iofifo.ReadFromFifoFloat();
                depthtest_fn2 = iofifo.ReadFromFifoFloat();
                depthtest_nf2 = iofifo.ReadFromFifoFloat();
                break;
            }
            
            default:
            {
                // just pass to next stage everything but polygon vertices & matrix commands
                //printf("vertex bypass %X\n", cmd);
                assert((cmd & 0xFFFF0000) == 0xFFFF0000);
                iofifo.BypassCmd(cmd);
            }
        }
    }
 
    return 0; 
} 
#endif
