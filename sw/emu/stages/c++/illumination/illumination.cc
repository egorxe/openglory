#include <cstdio> 
#include <cstdlib> 
#include <cstring>  
#include <cmath>  
#include <unistd.h>  

#include <functional> 

#include <gpu_pipeline.hh> 

IoFifo *iofifo;

Vec4 light_source_position = {0.f, 0.f, 1.f, 0.f};
Vec4 diffuse_light_color = {1.f, 1.f, 1.f, 0.f};
Vec4 ambient_scene = {0.2f, 0.2f, 0.2f, 1.f};
float ambient_strength = 0.2f;

bool lighting_enabled = false;  // ignored as not needed for now

void WriteVertexToFifo(IoFifo *iofifo, Vec4 &v, float *colors)
{
    iofifo->WriteToFifoFloat(v[0]);
    iofifo->WriteToFifoFloat(v[1]);
    iofifo->WriteToFifoFloat(v[2]);
    iofifo->WriteToFifoFloat(v[3]);
    for (int i = 0; i < 4; ++i)
        iofifo->WriteToFifoFloat(colors[i]);
}

// Single process illumination
void illumination() 
{
    // Read input vertices & colors
    float vertices[3*4];
    float diffuse_colors[3*4];
    float ambient_colors[3*4];
    float normal[3*3];
    
    // three vertices per polygon
    for (int vertex = 0; vertex < 3; ++vertex) {
        // four coords per vertex
        for (int i = 0; i < 4; ++i)
            vertices[vertex*4+i] = iofifo->ReadFromFifoFloat();
        // eight color floats per vertex
        for (int i = 0; i < 4; ++i)
            ambient_colors[vertex*4+i] = iofifo->ReadFromFifoFloat();
        for (int i = 0; i < 4; ++i)
            diffuse_colors[vertex*4+i] = iofifo->ReadFromFifoFloat();
        // four coords per normal
        for (int i = 0; i < 3; ++i) {
            normal[vertex*3+i] = iofifo->ReadFromFifoFloat();
        }
    }

    // Calculate lighting for each vertex
    for (int vertex = 0; vertex < 3; ++vertex) {
        
        // background scene lighting calculation
        Vec3 ambient;
        for (int i = 0; i < 3; i++)
            ambient[i] = ambient_colors[vertex*4 + i] * ambient_scene[i];
            
        // diffuse color calculation
        // !!! only correct for light source w = 0 && vertex w = 1 !!!
        // light_source_position should be already normalized
        
        float diffuse_intensity = 0;
        for (int i = 0; i < 3; i++)
            diffuse_intensity += normal[vertex*3 + i] * light_source_position[i];
        diffuse_intensity = diffuse_intensity > 0 ? diffuse_intensity : 0;
        
        Vec3 diffuse;
        for (int i = 0; i < 3; i++)
            diffuse[i] = diffuse_colors[vertex*4 + i] * diffuse_light_color[i] * diffuse_intensity;

        // set resulting color
        for (int i = 0; i < 3; i++) {
            diffuse_colors[vertex*4 + i] = diffuse[i] + ambient[i]; 
        }
    }

    // Process polygon vertices
    Vec4 v0, v1, v2;
    for (int i = 0; i < 4; ++i)
        v0[i] = vertices[0+i];
    for (int i = 0; i < 4; ++i)
        v1[i] = vertices[4+i];
    for (int i = 0; i < 4; ++i)
        v2[i] = vertices[8+i];

    // Pass resulting vertices to next stage
    iofifo->WriteToFifo32(GPU_PIPE_CMD_POLY_VERTEX4);
    WriteVertexToFifo(iofifo, v0, &diffuse_colors[0]);
    WriteVertexToFifo(iofifo, v1, &diffuse_colors[4]);
    WriteVertexToFifo(iofifo, v2, &diffuse_colors[8]);
    
    #if 0
    for (int j = 0; j < 4; ++j) printf("%f ", v0[j]);
        printf("\n");
    for (int j = 0; j < 4; ++j) printf("%f ", v1[j]);
        printf("\n");
    for (int j = 0; j < 4; ++j) printf("%f ", v2[j]);
        printf("\n\n");
    #endif
} 

#if BUILD_BINARY
int main(int argc, char **argv) 
{
    if (argc != 5) {
        puts("Wrong parameters!");
        return 1;
    }
    
    const uint32_t SCREEN_WIDTH     = atoi(argv[1]); 
    const uint32_t SCREEN_HEIGHT    = atoi(argv[2]);
        
    // Open output FIFO
    iofifo = new IoFifo(argv[3], argv[4]);
    
    while (1)
    {
        uint32_t cmd = iofifo->ReadFromFifo32();
        switch (cmd)
        {
            case GPU_PIPE_CMD_POLY_VERTEX4N3:
                illumination();
                break;
                
            case GPU_PIPE_CMD_POLY_VERTEX3N3:
                puts("Got unsupported command in illumination");
                assert(false);
                break;

            case GPU_PIPE_CMD_LIGHT_PARAMS:
                for (int i = 0; i < 4; i++)
                    light_source_position[i] = iofifo->ReadFromFifoFloat();
                for (int i = 0; i < 4; i++)
                    diffuse_light_color[i] = iofifo->ReadFromFifoFloat();
                break;

            case GPU_PIPE_CMD_LIGHT_STATE:
                lighting_enabled = iofifo->ReadFromFifo32() & GPU_STATE_LIGHT_ENABLE;
                break;
                
            default:
                assert((cmd & 0xFFFF0000) == 0xFFFF0000);
                iofifo->BypassCmd(cmd);
                break;
        }
    }
 
    return 0; 
} 
#endif
