#include <cstdio> 
#include <cstdlib> 
#include <cstring>  
#include <cmath>  
#include <unistd.h>  
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <gpu_pipeline.hh> 

#define CHECKERBOARD    0

#if !CHECKERBOARD
class SharedMem
{
    public:
    
    SharedMem()
    {
        // mmap shared memory from parent
        int ppid = getppid();
        struct stat st;
        char fname[100];
        // quite ugly & a lot of ways for it to fail (if python has other capabilities set for example)
        snprintf(fname, 100, "/proc/%d/fd/3", ppid);    // !! better to find actual fdnum by link name !!
        memfd = open(fname, O_RDWR);   
        assert(memfd > 0);
        assert(!fstat(memfd, &st));
        mmap_len = st.st_size;
        mmap_addr = (uint8_t*)mmap(NULL, mmap_len, PROT_READ , MAP_SHARED, memfd, 0);
        assert(mmap_addr != MAP_FAILED);
        
        bpp = 4;
        SetMemOffset(0x400000);
    }
    
    ~SharedMem()
    {
        munmap(mmap_addr, mmap_len);
        close(memfd);
    }
    
    uint32_t ReadMemWord(ssize_t off)
    {
        assert(off < mmap_len);
        return ((uint32_t*)mmap_addr)[off/4];
    }
    
    void WriteMemWord(ssize_t off, uint32_t data)
    {
        assert(off < mmap_len);
        ((uint32_t*)mmap_addr)[off/4] = data;
    }
    
    uint32_t GetColor(int x, int y, int width)
    {
        return *((uint32_t*)&(mmap_addr[mem_offset + (y*width+x)*bpp])); 
    }
    
    void SetMemOffset(ssize_t off) 
    {
        mem_offset = off; 
    }
    
    private:
    int memfd;
    uint8_t* mmap_addr;
    ssize_t mmap_len;
    
    //int width, height;
    int bpp;
    ssize_t mem_offset;
};

SharedMem shmem;
int tex_w, tex_h;
#endif

float linear_filter(float a, float b, float color[4])
{
    return Clamp((1 - a)*(1 - b)*color[0] + a*(1 - b)*color[1] + (1 - a)*b*color[2] + a*b*color[3]);
}

IoFifo *iofifo;

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
    
    while (1)
    {
        uint32_t cmd = iofifo->ReadFromFifo32();
        switch (cmd)
        {
            case (GPU_PIPE_CMD_TEXFRAGMENT):
            {
                uint32_t x = iofifo->ReadFromFifo32();
                uint32_t y = (x >> 16) & 0xFFFF;
                x &= 0xFFFF;
                uint32_t z = iofifo->ReadFromFifo32();
                float t_x = iofifo->ReadFromFifoFloat();
                float t_y = iofifo->ReadFromFifoFloat();
                float r, g, b, a;
                #if CHECKERBOARD
                const int M = 8;
                //bool check = ((fmod(t_x * M, 1.0) > 0.5) ^ (fmod(t_y * M, 1.0) < 0.5)) > 0.5;
                bool check = (((int(t_x * 64) & 0x8) == 0) ^ ((int(t_y * 64) & 0x8) == 0));
                r = 0;
                g = check ? 1.0 : 0;
                b = !check ? 1.0 : 0;
                a = 1.0;
                #else
                // Wrap Mode REPEAT
                float s = t_x - floor(t_x);
                float t = t_y - floor(t_y);
                float u = s * tex_w;  // width = 2 ^ n
                float v = t * tex_h;  // height = 2 ^ m
                
                #if 1
                // TEXTURE_MIN_FILTER == NEAREST
                int i_vt = s < 1 ? floor(u) : tex_w - 1;
                int j_vt = t < 1 ? floor(v) : tex_h - 1;
                uint32_t tex_color = shmem.GetColor(i_vt, j_vt, tex_w);
                r = ((tex_color >>  0) & 0xFF) / 255.;
                g = ((tex_color >>  8) & 0xFF) / 255.;
                b = ((tex_color >> 16) & 0xFF) / 255.;
                a = ((tex_color >> 24) & 0xFF) / 255.;
                #else
                uint32_t lf_pixels[4];
                int i0_vt = (u - 0.5) >= 0 ? floor(u - 0.5) : tex_w + floor(u - 0.5);   // !!! edges ???????????????????????????????
                int j0_vt = (v - 0.5) >= 0 ? floor(v - 0.5) : tex_h + floor(v - 0.5);
                int i1_vt = i0_vt + 1 < tex_w ? i0_vt+1 : i0_vt-tex_w;
                int j1_vt = j0_vt + 1 < tex_h ? j0_vt+1 : j0_vt-tex_h;
                //int j1_vt = (v + 1) < tex_h ? floor(v + 1) : floor(v) - tex_h;
                lf_pixels[0] = shmem.GetColor(i0_vt, j0_vt, tex_w);
                lf_pixels[1] = shmem.GetColor(i1_vt, j0_vt, tex_w);
                lf_pixels[2] = shmem.GetColor(i0_vt, j1_vt, tex_w);
                lf_pixels[3] = shmem.GetColor(i1_vt, j1_vt, tex_w);
                Vec4 lf_r, lf_g, lf_b, lf_a;
                for (int i = 0; i < 4; i++)
                {
                    lf_r[i] = ((lf_pixels[i] >>  0) & 0xFF) / 255.;
                    lf_g[i] = ((lf_pixels[i] >>  8) & 0xFF) / 255.;
                    lf_b[i] = ((lf_pixels[i] >> 16) & 0xFF) / 255.;
                    lf_a[i] = ((lf_pixels[i] >> 24) & 0xFF) / 255.;
                }
                
                float tmp;
                float alpha = modff(u - 0.5, &tmp);
                float beta  = modff(v - 0.5, &tmp);
                
                r = linear_filter(alpha, beta, lf_r);
                g = linear_filter(alpha, beta, lf_g);
                b = linear_filter(alpha, beta, lf_b);
                a = linear_filter(alpha, beta, lf_a);
                #endif
                #endif
                
                iofifo->WriteFragment(x, y, z, r, g, b, a);   
                break;
            }
            case (GPU_PIPE_CMD_BINDTEXTURE):
            {
                uint32_t ptr = iofifo->ReadFromFifo32();
                uint32_t size = iofifo->ReadFromFifo32();
                #if !CHECKERBOARD
                tex_w = size & 0xFFFF;
                tex_h = (size >> 16) & 0xFFFF;
                verbose("Set texture ptr %X\n", ptr);
                shmem.SetMemOffset(ptr);
                #endif
                break;
            }
            default:
            {
                // just pass to next stage everything but texturing commands
                assert((cmd & 0xFFFF0000) == 0xFFFF0000);
                iofifo->BypassCmd(cmd);
                break;
            }
        }
        
    }
 
    return 0; 
} 
