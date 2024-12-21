import sdl2
import sdl2.ext
import ctypes
import numpy
import os

COEF_X = 3
COEF_Y = 2
# COEF_X = 1
# COEF_Y = 1

class GpuDisplay():
    
    def __init__(self, size_x, size_y, draw_backbuffer = 0):
        self.size_x = size_x 
        self.size_y = size_y 
        
        # init framebuffer
        self.framebuffer = numpy.zeros((size_x*COEF_X, size_y*COEF_Y), dtype='uint32')
        
        # init SDL
        sdl2.ext.init()
        self.window = sdl2.ext.Window("OpenGLory virtual display", size=(self.size_x * COEF_X, self.size_y * COEF_Y))
        self.window.show()
        self.surface = self.window.get_surface()
        
        self.fragments = 0
        if "DRAW_BACKBUFFER" in os.environ:
            self.draw_backbuffer = int(os.environ["DRAW_BACKBUFFER"])
        else:
            self.draw_backbuffer = draw_backbuffer
        
    def SetArrayPixel(self, x, y, c):
        for i in range(x*COEF_X,x*COEF_X+COEF_X):
            for j in range(y*COEF_Y,y*COEF_Y+COEF_Y):
                self.framebuffer[i][j] = c
        
    def PutPixel(self, pixel):
        # put pixel to buffer (reverse Y axis from OpenGL style to SDL style)
        # OpenGL puts coord origin to lower left corner but SDL to upper left
        self.SetArrayPixel(pixel[0], self.size_y-1-pixel[1], pixel[2])
        
    def PutFragment(self, frag):
        self.PutPixel((frag[0], frag[1], frag[3]))
        if self.draw_backbuffer and frag[3]:
            if (self.fragments == self.draw_backbuffer):
                self.fragments = 0
                pixels = sdl2.ext.pixels2d(self.surface)
                numpy.copyto(pixels, self.framebuffer) 
                self.window.refresh()
            else:
                self.fragments += 1
    
    def ClearScreen(self):
        sdl2.ext.fill(self.surface, sdl2.ext.Color(0, 0, 0), (0, 0, self.size_x * COEF_X, self.size_y * COEF_Y))  
        pass
    
    def DrawFramebuffer(self):
        # copy framebuffer to screen
        # if not self.draw_backbuffer:
        pixels = sdl2.ext.pixels2d(self.surface)
        numpy.copyto(pixels, self.framebuffer) 
        self.window.refresh()
    
    def ClearFramebuffer(self):    
        self.framebuffer.fill(0)
        
    def Tick(self):
        finish = False
        event = sdl2.events.SDL_Event()
        ret = 1
        while (ret == 1):
            ret = sdl2.events.SDL_PollEvent(ctypes.byref(event), 1)
            if event.type == sdl2.events.SDL_QUIT:
                finish = True
        # self.window.refresh()
        return finish
        
