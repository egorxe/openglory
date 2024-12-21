#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <assert.h>
#include <GLES/gl.h>
#include <GLES/egl.h>

EGLDisplay  glDisplay;
EGLConfig   glConfig;
EGLContext  glContext;
EGLSurface  glSurface;

#ifdef USE_SDL
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

SDL_Window *glesWindow = NULL;
#endif



/* screen width and height */
#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480

//#define COW
//#define TEAPOT0
//#define TEAPOT1
//#define SUZANNE
//#define SPOT

#if defined(COW)
#include "cow.h"
#define LIGHTING    1
#define COLOR       0
#define TEXTURING   0
#define TRANS_X      0.0f
#define TRANS_Y     -0.0f
#define TRANS_Z     -15.f
#define ROT_A        0.f
#define ROT_X        0.f
#define ROT_Y        1.f
#define ROT_Z        0.f

#elif defined(TEAPOT0)
#include "teapot0.h"
#define LIGHTING    1
#define COLOR       0
#define TEXTURING   0
#define TRANS_X      0.f
#define TRANS_Y     -1.f
#define TRANS_Z     -7.f
#define ROT_A       20.f
#define ROT_X        1.f
#define ROT_Y        0.f
#define ROT_Z       -0.f

#elif defined(TEAPOT1)
#include "teapot1.h"
#define LIGHTING    1
#define COLOR       0
#define TEXTURING   0
#define TRANS_X      0.f
#define TRANS_Y     -1.f
#define TRANS_Z     -7.f
#define ROT_A       40.f
#define ROT_X        1.f
#define ROT_Y        0.f
#define ROT_Z       -0.f

#elif defined(SUZANNE)
#include "suzanne.h"
#define LIGHTING    1
#define COLOR       0
#define TEXTURING   0
#define TRANS_X      0.f
#define TRANS_Y     -0.f
#define TRANS_Z     -10.f
#define ROT_A       20.f
#define ROT_X        1.f
#define ROT_Y        0.f
#define ROT_Z       -0.f

#elif defined(SPOT)
#include "spot.h"
#define LIGHTING    0
#define COLOR       0
#define TEXTURING   1
#define TRANS_X      0.f
#define TRANS_Y      0.f
#define TRANS_Z     -4.f
#define ROT_A       180.f
#define ROT_X        0.f
#define ROT_Y        1.f
#define ROT_Z        0.f

#else
#include "cube.h"

#define LIGHTING    0
#define COLOR       !LIGHTING
#define TEXTURING   0
#define TRANS_X     -0.f
#define TRANS_Y     -0.f
#define TRANS_Z     -3.f
#define ROT_A       45.f
#define ROT_X        1.f
#define ROT_Y        0.f
#define ROT_Z        1.f

#endif

#if TEXTURING
#include <SDL2/SDL_image.h>
#endif

void gl_print_matrix(const GLfloat* m) {
	GLint i;

	for (i = 0; i < 4; i++) {
		printf("%f %f %f %f\n", m[i], m[4 + i], m[8 + i], m[12 + i]);
	}
}

static void __gluMakeIdentityf(GLfloat* m)
{
    m[0+4*0] = 1; m[0+4*1] = 0; m[0+4*2] = 0; m[0+4*3] = 0;
    m[1+4*0] = 0; m[1+4*1] = 1; m[1+4*2] = 0; m[1+4*3] = 0;
    m[2+4*0] = 0; m[2+4*1] = 0; m[2+4*2] = 1; m[2+4*3] = 0;
    m[3+4*0] = 0; m[3+4*1] = 0; m[3+4*2] = 0; m[3+4*3] = 1;
}

#define __glPi 3.14159265358979323846

void emulateGLUperspective(GLfloat fovy, GLfloat aspect, GLfloat zNear, GLfloat zFar)
{
    GLfloat m[4][4];
    GLfloat sine, cotangent, deltaZ;
    GLfloat radians=(GLfloat)(fovy/2.0f*__glPi/180.0f);

    deltaZ=zFar-zNear;
    sine=(GLfloat)sin(radians);
    if ((deltaZ==0.0f) || (sine==0.0f) || (aspect==0.0f))
    {
        return;
    }
    cotangent=(GLfloat)(cos(radians)/sine);

    __gluMakeIdentityf(&m[0][0]);
    m[0][0] = cotangent / aspect;
    m[1][1] = cotangent;
    m[2][2] = -(zFar + zNear) / deltaZ;
    m[2][3] = -1.0f;
    m[3][2] = -2.0f * zNear * zFar / deltaZ;
    m[3][3] = 0;
    glMultMatrixf(&m[0][0]);
}

#ifdef USE_SDL
void createEGLWindow(int width, int height, const char* wnd_name)
{
    int fullscreen   =   0;

    EGLint egl_config_attr[] = {
        EGL_BUFFER_SIZE,    16,
        EGL_DEPTH_SIZE,     16,
        EGL_STENCIL_SIZE,   0,
        EGL_SURFACE_TYPE,
        EGL_WINDOW_BIT,
        EGL_NONE
    };

    EGLint numConfigs, majorVersion, minorVersion;
    glesWindow = SDL_CreateWindow(wnd_name, 0, 0, width, height,
                                  fullscreen ? (SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN) : SDL_WINDOW_OPENGL);
    glDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    eglInitialize(glDisplay, &majorVersion, &minorVersion);
    eglChooseConfig(glDisplay, egl_config_attr, &glConfig, 1, &numConfigs);
    SDL_SysWMinfo sysInfo;
    SDL_VERSION(&sysInfo.version); // Set SDL version
    SDL_GetWindowWMInfo(glesWindow, &sysInfo);
    glContext = eglCreateContext(glDisplay, glConfig, EGL_NO_CONTEXT, NULL);
    glSurface = eglCreateWindowSurface(glDisplay, glConfig,
                                       (EGLNativeWindowType)sysInfo.info.x11.window, 0); // X11?
    eglMakeCurrent(glDisplay, glSurface, glSurface, glContext);
    eglSwapInterval(glDisplay, 1);
}
#endif
/* General OpenGLES initialization function */
void initGLES(void)
{
    #ifdef USE_SDL
    createEGLWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "OpenGL ES 1.1 test");
    #endif

    glEnable(GL_DEPTH_TEST);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    
    #if LIGHTING
    glEnableClientState(GL_NORMAL_ARRAY);
    static GLfloat light_pos[4] = {5.0, 5.0, 0.0, 0.0};
    glLightfv(GL_LIGHT0, GL_POSITION, light_pos);
    //const GLfloat light_diffuse[] = { 0.8f, 0.1f, 0.1f, 1.0f };
    const GLfloat light_diffuse[] = { 0.8f, 0.2f, 0.0f, 1.0f };
    //const GLfloat light_ambient[]  = { 0.5f, 0.5f, 0.5f, 1.0f };
    glLightfv(GL_LIGHT0, GL_DIFFUSE, light_diffuse);
    //glLightfv(GL_LIGHT0, GL_AMBIENT, light_ambient);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    
    #elif COLOR
    glEnableClientState(GL_COLOR_ARRAY);
    #endif
    #if TEXTURING
    glEnable(GL_TEXTURE_2D);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    SDL_Surface *texture = IMG_Load("spot_texture.png");
    assert(texture);
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, texture->w,
                  texture->h, 0, GL_RGB,
                  GL_UNSIGNED_BYTE, texture->pixels );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    #endif
}

/* Here goes our drawing code */
int drawGLScene( GLvoid )
{
    /* Clear The Screen And The Depth Buffer */
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glRotatef(1.f, 0.0f, 1.f, 0.0f);
    
    glVertexPointer(3, GL_FLOAT, 0, vertices);
    #if LIGHTING
    glNormalPointer(GL_FLOAT, 0, normals);
    #elif COLOR
    glColorPointer(4, GL_FLOAT, 0, colors);
    #endif
    #if TEXTURING
    glTexCoordPointer(2, GL_FLOAT, 0, texcoord);
    #endif

    glDrawArrays(GL_TRIANGLES, 0, nvertices);

    /* Draw it to the screen */
    eglSwapBuffers(glDisplay, glSurface);
    #ifdef USE_SDL
    SDL_Delay(20);
    #else
    usleep(20);
    #endif

    return 0;
}


int main( int argc, char **argv )
{
    /* main loop variable */
    int done = 0;
    /* used to collect events */

    /* initialize SDL & OpenGLES */
    initGLES();
    
    // init projection
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    emulateGLUperspective(45.0f, (float)SCREEN_WIDTH/(float)SCREEN_HEIGHT, 0.1, 20.0f);
    
    // init model view
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    //glShadeModel(GL_FLAT);
    
    glTranslatef(TRANS_X, TRANS_Y, TRANS_Z);
    glRotatef(ROT_A, ROT_X, ROT_Y, ROT_Z);
    
    #if DEBUG
    GLfloat matrix[16]; 
    //glGetFloatv (GL_MODELVIEW_MATRIX, matrix); 
    glGetFloatv (GL_PROJECTION_MATRIX, matrix); 
    gl_print_matrix(matrix);
    #endif

    /* wait for events */ 
    while (!done)
    {
        #ifdef USE_SDL
        /* handle the events in the queue */
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            switch( event.type )
            {
                case SDL_QUIT:
                    /* handle quit requests */
                    done = 1;
                    break;
                default:
                    break;
            }
        }
        #endif
        
        /* draw the scene */
        drawGLScene( );
    }

    #ifdef USE_SDL
    // Cleaning
    eglDestroySurface(glDisplay, glSurface);
    eglDestroyContext(glDisplay, glContext);
    eglTerminate(glDisplay);
    SDL_DestroyWindow(glesWindow);
    #endif

    /* Should never get here */
    return 0;
}
