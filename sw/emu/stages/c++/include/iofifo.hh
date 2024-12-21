#ifndef _IOFIFO_HH
#define _IOFIFO_HH

#include <string> 
#include <iostream> 
#include <fstream> 
#include <cassert> 
#include <cstdlib> 
#include <cstdint> 
#include <errno.h> 

#include "oglory_gpu_defs.hh"

class IoFifo
{
    std::ofstream out_fifo;
    std::ifstream in_fifo;
    
    public:
    
    // ######################## Initialization ########################
    
    IoFifo(std::string ififo_name, std::string ofifo_name)
    {
        
        in_fifo.open(ififo_name.c_str());
        
        if (!ofifo_name.empty())
        {
            out_fifo.open(ofifo_name.c_str());
            if (!out_fifo.is_open())
            {
                std::cerr << "Failed to open output file " << ififo_name << std::endl;
                exit(ENFILE);
            }
        }
        
        if (!ififo_name.empty())
        {
            if (!in_fifo.is_open())
            {
                std::cerr << "Failed to open input file " << ififo_name << std::endl;
                exit(ENFILE);
            }
        }
    }
    
    // ######################## Basic ops ########################
    
    // Write 32-bit word to output FIFO
    void WriteToFifo32(const uint32_t x)
    {
        #if PRINT_FIFO
        printf("%08X\n", x);
        #endif
        out_fifo.write((char*)&x, sizeof(x));
    }
    
    // Write 32-bit word to output FIFO
    void WriteToFifoFloat(const float x)
    {
        #if PRINT_FIFO
        printf("%08X\n", *(uint32_t*)&x);
        #endif
        out_fifo.write((char*)&x, sizeof(x));
    }
    
    // Read 32-bit word from input FIFO
    uint32_t ReadFromFifo32()
    {
        uint32_t x;
        in_fifo.read((char*)&x, sizeof(x));
        return x;
    }
    
    // Read float from input FIFO
    float ReadFromFifoFloat()
    {
        float x;
        in_fifo.read((char*)&x, sizeof(x));
        return x;
    }
    
    // Force finish all FIFO writes from buffer
    void Flush()
    {
        out_fifo.flush();
    }
    
    
    // ######################## Complex ops ########################
    
    // Write fragment from rasterizer (uint color)
    void WriteFragment(const uint32_t x, const uint32_t y, const uint32_t z, const uint32_t c)
    {
        WriteToFifo32(GPU_PIPE_CMD_FRAGMENT); 
        WriteToFifo32((y << 16) | x); 
        WriteToFifo32(z); 
        WriteToFifo32(c); 
    }
    
    // Write fragment from rasterizer
    void WriteFragment(const uint32_t x, const uint32_t y, const uint32_t z, const float r, const float g, const float b, const float a)
    {
        WriteFragment(x, y, z, ArgbToU32(a, r, g, b)); 
    }
    
    // Write fragment with texture coords
    void WriteTexFragment(const uint32_t x, const uint32_t y, const uint32_t z, const float t_x, const float t_y)
    {
        WriteToFifo32(GPU_PIPE_CMD_TEXFRAGMENT); 
        WriteToFifo32((y << 16) | x);
        WriteToFifo32(z); 
        WriteToFifoFloat(t_x); 
        WriteToFifoFloat(t_y); 
    }
    
    // Read fragment into fragment ops
    void ReadFragment(uint32_t fragment[])
    {
        fragment[0] = ReadFromFifo32();     // x & y
        fragment[1] = (fragment[0] >> 16) & 0xFFFF;     // y
        fragment[0] &= 0xFFFF;              // x
        fragment[2] = ReadFromFifo32();     // z
        fragment[3] = ReadFromFifo32();     // 32-bit Color
    }
    
    // Bypass command with its arguments to next stage
    void BypassCmd(const int32_t cmd)
    {
        WriteToFifo32(cmd);
        for (int i = 0; i < (cmd & 0xFF00) >> 8; i++)
        {
            uint32_t tmp = ReadFromFifo32(); 
            WriteToFifo32(tmp);
        }
        Flush();
    }
};

#endif
