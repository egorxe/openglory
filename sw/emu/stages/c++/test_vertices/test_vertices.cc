#include <cstdio> 
#include <cstdlib> 
#include <unistd.h>  

#include <cmath>  

//#define PRINT_FIFO 1
#include <gpu_pipeline.hh> 

#define COW 0

#define VERTEX_NORMAL 0

#if COW
#include "cow.h"
#else
#include "model.h"
#endif


void WriteVertexToFifo(IoFifo &iofifo, float *vertices, float *colors, float *normal)
{
	iofifo.WriteToFifo32(GPU_PIPE_CMD_POLY_VERTEX3N3);
	for (int v = 0; v < 3; ++v) {
		for (int i = 0; i < 3; ++i)
			iofifo.WriteToFifoFloat(vertices[v*3+i]);
		for (int i = 0; i < 4; ++i) {
			iofifo.WriteToFifoFloat(colors[v*4+i]);
		}
#if VERTEX_NORMAL
		for (int i = 0; i < 3; ++i) {
			iofifo.WriteToFifoFloat(normal[i]);
		}
	}
#else
	}
	for (int i = 0; i < 3; ++i)
		iofifo.WriteToFifoFloat(normal[i]);
#endif
}

void normal_calculation(const float *vectors, Vec3 &normal_out)
{
    Vec3 v0, v1, v2;
    for (int i = 0; i < 3; ++i)
        v0[i] = vectors[0+i];
    for (int i = 0; i < 3; ++i)
        v1[i] = vectors[3+i];
    for (int i = 0; i < 3; ++i)
        v2[i] = vectors[6+i];

    // normal vector calculation
    Vec3 edge1 = {
        v1[0] - v0[0]
        , v1[1] - v0[1]
        , v1[2] - v0[2]
        };
    Vec3 edge2 = {
        v2[0] - v0[0]
        , v2[1] - v0[1]
        , v2[2] - v0[2]
        };
    Vec3 normal = {
        edge1[1]*edge2[2] - edge1[2]*edge2[1]
        , edge1[2]*edge2[0] - edge1[0]*edge2[2]
        , edge1[0]*edge2[1] - edge1[1]*edge2[0]
        };
    double len = normal[0] * normal[0]
        + normal[1] * normal[1]
        + normal[2] * normal[2];

    assert (len != 0.0f);

    len = 1.0f / sqrt(len);
    for (int i = 0; i < 3; ++i)
        normal_out[i] = normal[i] * len;
}


int main(int argc, char **argv) 
{
    if (argc != 5)
    {
        puts("Wrong parameters!");
        return 1;
    }

    // Open output FIFO
    IoFifo iofifo(argv[3], argv[4]);
   
    float w_vertices[3*3];
	float w_colors[3*4];
    while (1)
    {
        // Vertex cycle
        for (int vertex = 0; vertex < nvertices; vertex += 1)
        {
            // Add command: polygon vertex
			// And pass value to fifo
            if (vertex != 0 && (vertex % 3) == 0) {
				Vec3 normal;
				normal_calculation(w_vertices, normal);
				WriteVertexToFifo(iofifo, w_vertices, w_colors, normal);
            }
            
            // three coords per vertex
            for (int i = 0; i < 3; ++i)
            {
                w_vertices[((vertex%3)*3)+i] = vertices[vertex*3+i];
            }
            
            // four color floats per vertex    
            for (int i = 0; i < 4; ++i) {
            #if COW
				// random color
                w_colors[((vertex%3)*3)+i] = (i == (vertex/3) % 3);
            #else
                w_colors[((vertex%3)*3)+i] = colors[vertex*4+i];
            #endif
            }
        }

		Vec3 normal;
		normal_calculation(w_vertices, normal);

		WriteVertexToFifo(iofifo, w_vertices, w_colors, normal);
        
        // Add commands marking frame end
        iofifo.WriteToFifo32(GPU_PIPE_CMD_SYNC);
        iofifo.WriteToFifo32(GPU_PIPE_CMD_CLEAR_ZB);
        iofifo.Flush();
        //return 1;
    }
 
    return 0; 
} 
