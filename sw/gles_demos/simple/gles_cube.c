#include <stdbool.h>
#include <stdio.h>
#include <math.h>

// GLES
#include <GLES/gl.h>

// EGL
#include <GLES/egl.h>

#ifdef USE_SDL
// SDL2
#include <SDL2/SDL.h> // For Events
#include <SDL2/SDL_syswm.h>
#endif

EGLDisplay  glDisplay;
EGLConfig   glConfig;
EGLContext  glContext;
EGLSurface  glSurface;

#ifdef USE_SDL
SDL_Window *glesWindow = NULL;
#endif

float mCubeRotation = 0.0f;

float vertices[] = {
    -1.0f, -1.0f, -1.0f,
     1.0f, -1.0f, -1.0f,
     1.0f,  1.0f, -1.0f,
    -1.0f,  1.0f, -1.0f,
    -1.0f, -1.0f,  1.0f,
     1.0f, -1.0f,  1.0f,
     1.0f,  1.0f,  1.0f,
    -1.0f,  1.0f,  1.0f
};

float colors[] = {
    0.0f,  1.0f,  0.0f,  1.0f,
    0.0f,  1.0f,  0.0f,  1.0f,
    1.0f,  0.5f,  0.0f,  1.0f,
    1.0f,  0.5f,  0.0f,  1.0f,
    1.0f,  0.0f,  0.0f,  1.0f,
    1.0f,  0.0f,  0.0f,  1.0f,
    0.0f,  0.0f,  1.0f,  1.0f,
    1.0f,  0.0f,  1.0f,  1.0f
};

char indices[] = {
    0, 4, 5, 0, 5, 1,
    1, 5, 6, 1, 6, 2,
    2, 6, 7, 2, 7, 3,
    3, 7, 4, 3, 4, 0,
    4, 7, 6, 4, 6, 5,
    3, 0, 1, 3, 1, 2
};

void gl_print_matrix(const GLfloat* m) {
	GLint i;

	for (i = 0; i < 4; i++) {
		printf("%f %f %f %f\n", m[i], m[4 + i], m[8 + i], m[12 + i]);
	}
}

void emulateGLUperspective(GLfloat fovY, GLfloat aspect, GLfloat zNear,
                           GLfloat zFar)
{
    GLfloat fW, fH;
    fH = tan(fovY / 180 * M_PI) * zNear / 2;
    fW = fH * aspect;
    glFrustumf(-fW, fW, -fH, fH, zNear, zFar);
}

void init_GLES(void)
{
    
    int screenwidth  = 640;
    int screenheight = 480;
    
    #ifdef USE_SDL
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
    glesWindow = SDL_CreateWindow("LOR_GLES_DEMO", 0, 0, screenwidth, screenheight,
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
    #endif
    //glClearColor(0.0f, 0.0f, 0.0f, 0.5f);
    //glClearDepthf(1.0f);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    glViewport(0, 0, screenwidth, screenheight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    emulateGLUperspective(45.0f, (float) screenwidth / (float) screenheight, 0.1f, 100.0f);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

void draw_frame()
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();
    glTranslatef(0.0f, 0.0f, -10.0f);
    glRotatef(mCubeRotation, 1.0f, 1.0f, 1.0f);
    glFrontFace(GL_CW);
    //glEnable(GL_CULL_FACE);
    glVertexPointer(3, GL_FLOAT, 0, vertices);
    glColorPointer(4, GL_FLOAT, 0, colors);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_BYTE, indices);
    
    #if 0
    glEnable(GL_BLEND);
    glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_COLOR);
    glDisableClientState(GL_COLOR_ARRAY);
    //glEnableClientState(GL_VERTEX_ARRAY);
    glColor4f(1.0, 0, 0, 0.5);
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_BYTE, indices);
    glDisable(GL_BLEND);
    #endif
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);
    glLoadIdentity();
    mCubeRotation -= 0.50f;
}

int main(void)
{
    int loop = 1;
    #ifdef USE_SDL
    SDL_Event event;
    #endif
    init_GLES();

    while (loop) {
        #ifdef USE_SDL
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_QUIT: {
                    loop = 0;
                    break;
                }
            }
        }
        #endif

        draw_frame();
        eglSwapBuffers(glDisplay, glSurface);
    }

    #ifdef USE_SDL
    // Cleaning
    eglDestroySurface(glDisplay, glSurface);
    eglDestroyContext(glDisplay, glContext);
    eglTerminate(glDisplay);
    SDL_DestroyWindow(glesWindow);
    #endif

    return 0;
}
