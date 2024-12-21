/*
 * This code was created by Jeff Molofee '99
 * (ported to Linux/SDL by Ti Leggett '01)
 * (ported to Maemo/SDL_gles by Till Harbaum '10)
 *
 * If you've found this code useful, please let me know.
 *
 * Visit Jeff at http://nehe.gamedev.net/
 *
 * or for port-specific comments, questions, bugreports etc.
 * email to leggett@eecs.tulane.edu or till@harbaum.org
 */

#include <stdio.h>
#include <stdlib.h>

#include <GLES/gl.h>
#include <GLES/egl.h>
#include <math.h>

EGLDisplay  glDisplay;
EGLConfig   glConfig;
EGLContext  glContext;
EGLSurface  glSurface;

#ifdef USE_SDL
#include <SDL2/SDL.h>
#include <SDL2/SDL_opengles.h>
#include <SDL2/SDL_syswm.h>
#endif

/* screen width, height, and bit depth */
#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480
#define SCREEN_BPP     16

/* Define our booleans */
#define TRUE  1
#define FALSE 0

#ifdef USE_SDL
SDL_Window* glesWindow;
SDL_GLContext glcontext=NULL;
#endif

#include <sys/time.h>
#include <unistd.h>

/* return current time (in milliseconds) */
double current_time()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (double) tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

/* gluPerspective replacement for opengles */
void gluPerspective(double fovy, double aspect, double zNear, double zFar)
{
  double xmin, xmax, ymin, ymax;

  ymax = zNear * tan(fovy * M_PI / 360.0);
  ymin = -ymax;
  xmin = ymin * aspect;
  xmax = ymax * aspect;

  glFrustumf(xmin, xmax, ymin, ymax, zNear, zFar);
}

/* function to release/destroy our resources and restoring the old desktop */
void Quit(int returnCode)
{
    #ifdef USE_SDL
    /* clean up the window */
    SDL_GL_DeleteContext(glcontext);
    SDL_DestroyWindow(glesWindow);

    SDL_Quit();
    #endif

    /* and exit appropriately */
    exit(returnCode);
}

/* function to reset our viewport after a window resize */
int resizeWindow( int width, int height )
{
    /* Height / width ration */
    GLfloat ratio;
 
    /* Protect against a divide by zero */
    if ( height == 0 )
	height = 1;

    ratio = ( GLfloat )width / ( GLfloat )height;

    /* Setup our viewport. */
    glViewport( 0, 0, ( GLsizei )width, ( GLsizei )height );

    /* change to the projection matrix and set our viewing volume. */
    glMatrixMode( GL_PROJECTION );
    glLoadIdentity( );

    /* Set our perspective */
    gluPerspective( 45.0f, ratio, 0.1f, 100.0f );

    /* Make sure we're chaning the model view and not the projection */
    glMatrixMode( GL_MODELVIEW );

    /* Reset The View */
    glLoadIdentity( );

    return( TRUE );
}

/* general OpenGL initialization function */
int initGL(GLvoid)
{
    /* Enable smooth shading */
    //glShadeModel(GL_SMOOTH);

    /* Set the background black */
    //glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

    /* Depth buffer setup */
    //glClearDepthf(1.0f);

    /* Enables Depth Testing */
    glEnable(GL_DEPTH_TEST);

    /* The Type Of Depth Test To Do */
    glDepthFunc(GL_LEQUAL);

    /* Really Nice Perspective Calculations */
    //glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    glEnableClientState(GL_VERTEX_ARRAY);

    return 1;
}

/* Here goes our drawing code */
int drawGLScene( GLvoid )
{
    /* rotational vars for the triangle and quad, respectively */
    static GLfloat rtri, rquad;
    /* These are to calculate our fps */
    static double T0    = 0;
    static GLint Frames = 0;
    int tri, quad;

    /* Clear The Screen And The Depth Buffer */
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    /* Move Left 1.5 Units And Into The Screen 6.0 */
    glLoadIdentity();
    glTranslatef( -1.5f, 0.0f, -6.0f );

    /* Rotate The Triangle On The Y axis ( NEW ) */
    glRotatef( rtri, 0.0f, 1.0f, 0.0f );

    /* GLES variant of drawing a triangle */
    const GLfloat triVertices[][9] = {
      {     /* Front Triangle */
	 0.0f,  1.0f,  0.0f,               /* Top Of Triangle               */
	-1.0f, -1.0f,  1.0f,               /* Left Of Triangle              */
	 1.0f, -1.0f,  1.0f                /* Right Of Triangle             */
      }, {  /* Right Triangle */
	 0.0f,  1.0f,  0.0f,               /* Top Of Triangle               */
	 1.0f, -1.0f,  1.0f,               /* Left Of Triangle              */
	 1.0f, -1.0f, -1.0f                /* Right Of Triangle             */
      }, {  /* Back Triangle */
	 0.0f,  1.0f,  0.0f,               /* Top Of Triangle               */
	 1.0f, -1.0f, -1.0f,               /* Left Of Triangle              */
	-1.0f, -1.0f, -1.0f                /* Right Of Triangle             */
      }, {  /* Left Triangle */
	 0.0f,  1.0f,  0.0f,               /* Top Of Triangle               */
	-1.0f, -1.0f, -1.0f,               /* Left Of Triangle              */
	-1.0f, -1.0f,  1.0f                /* Right Of Triangle             */
      }
    };

    /* unlike GL, GLES does not support RGB. We have to use RGBA instead */
    const GLfloat triColors[][12] = {
      {     /* Front triangle */
        1.0f, 0.0f, 0.0f, 1.0f,            /* Red                           */
	0.0f, 1.0f, 0.0f, 1.0f,            /* Green                         */
	0.0f, 0.0f, 1.0f, 1.0f             /* Blue                          */
      }, {  /* Right triangle */
        1.0f, 0.0f, 0.0f, 1.0f,            /* Red                           */
	0.0f, 0.0f, 1.0f, 1.0f,            /* Blue                          */
	0.0f, 1.0f, 0.0f, 1.0f             /* Green                         */
      }, {  /* Back triangle */
        1.0f, 0.0f, 0.0f, 1.0f,            /* Red                           */
	0.0f, 1.0f, 0.0f, 1.0f,            /* Green                         */
	0.0f, 0.0f, 1.0f, 1.0f             /* Blue                          */
      }, {  /* Left triangle */
        1.0f, 0.0f, 0.0f, 1.0f,            /* Red                           */
	0.0f, 0.0f, 1.0f, 1.0f,            /* Blue                          */
	0.0f, 1.0f, 0.0f, 1.0f             /* Green                         */
      }
    };

    glEnableClientState(GL_COLOR_ARRAY);

    /* Loop through all Triangles */
    for(tri=0;tri<sizeof(triVertices)/(9*sizeof(GLfloat));tri++) 
    {
      glVertexPointer(3, GL_FLOAT, 0, triVertices[tri]);
      glColorPointer(4, GL_FLOAT, 0, triColors[tri]);
      
      glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
    }

    /* Move Right 3 Units */
    glLoadIdentity( );
    glTranslatef( 1.5f, 0.0f, -6.0f );

    /* Rotate The Quad On The X axis */
    glRotatef( rquad, 1.0f, 0.0f, 0.0f );

    /* GLES variant of drawing a quad */
    const GLfloat quadVertices[][12] = {
      {     /* Top Quad */
	 1.0f,  1.0f, -1.0f,  /* Top Right Of The Quad (Top)      */
	-1.0f,  1.0f, -1.0f,  /* Top Left Of The Quad (Top)       */
	 1.0f,  1.0f,  1.0f,  /* Bottom Right Of The Quad (Top)   */
	-1.0f,  1.0f,  1.0f,  /* Bottom Left Of The Quad (Top)    */
      }, {  /* Bottom Quad */
	 1.0f, -1.0f,  1.0f,  /* Top Right Of The Quad (Botm)     */
        -1.0f, -1.0f,  1.0f,  /* Top Left Of The Quad (Botm)      */
         1.0f, -1.0f, -1.0f,  /* Bottom Right Of The Quad (Botm)  */
	-1.0f, -1.0f, -1.0f,  /* Bottom Left Of The Quad (Botm)   */
      }, {  /* Front Quad */
	 1.0f,  1.0f,  1.0f,  /* Top Right Of The Quad (Front)    */
	-1.0f,  1.0f,  1.0f,  /* Top Left Of The Quad (Front)     */
	 1.0f, -1.0f,  1.0f,  /* Bottom Right Of The Quad (Front) */
	-1.0f, -1.0f,  1.0f,  /* Bottom Left Of The Quad (Front)  */
      }, {  /* Back Quad */
         1.0f, -1.0f, -1.0f,  /* Bottom Left Of The Quad (Back)   */
	-1.0f, -1.0f, -1.0f,  /* Bottom Right Of The Quad (Back)  */
	 1.0f,  1.0f, -1.0f,  /* Top Left Of The Quad (Back)      */
	-1.0f,  1.0f, -1.0f,  /* Top Right Of The Quad (Back)     */
      }, {  /* Left Quad */
	-1.0f,  1.0f,  1.0f,  /* Top Right Of The Quad (Left)     */
	-1.0f,  1.0f, -1.0f,  /* Top Left Of The Quad (Left)      */
	-1.0f, -1.0f,  1.0f,  /* Bottom Right Of The Quad (Left)  */
	-1.0f, -1.0f, -1.0f,  /* Bottom Left Of The Quad (Left)   */
      }, {  /* Right Quad */
         1.0f,  1.0f, -1.0f,  /* Top Right Of The Quad (Right)    */
	 1.0f,  1.0f,  1.0f,  /* Top Left Of The Quad (Right)     */
	 1.0f, -1.0f, -1.0f,  /* Bottom Right Of The Quad (Right) */    
	 1.0f, -1.0f,  1.0f,  /* Bottom Left Of The Quad (Right)  */
      }
    };

    const GLfloat quadColors[][3] = {
      { 0.0f,  1.0f,  0.0f }, /* Green (Top)     */
      { 1.0f,  0.5f,  0.0f }, /* Orange (Botm)   */
      { 1.0f,  0.0f,  0.0f }, /* Red (Front)     */
      { 1.0f,  1.0f,  0.0f }, /* Yellow (Back)   */
      { 0.0f,  0.0f,  1.0f }, /* Blue (Left)     */
      { 1.0f,  0.0f,  1.0f }, /* Violet (Right)  */
    };

    glDisableClientState(GL_COLOR_ARRAY);

    /* Loop through all Quads */
    for(quad=0;quad<sizeof(quadVertices)/(12*sizeof(GLfloat));quad++) 
    {
      glColor4f(quadColors[quad][0], quadColors[quad][1], 
		quadColors[quad][2], 1.0f);

      glVertexPointer(3, GL_FLOAT, 0, quadVertices[quad]);
      glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    /* Draw it to the screen */
    eglSwapBuffers(glDisplay, glSurface);

    /* Gather our frames per second */
    Frames++;
    {
        double t = current_time();
        if (t - T0 >= 5000) {
            GLfloat seconds = (t - T0) / 1000.0;
            GLfloat fps = Frames / seconds;
            if (T0 != 0)
                printf("%d frames in %g seconds = %g FPS\n", Frames, seconds, fps);
            T0 = t;
            Frames = 0;
        }
    }

    /* Increase The Rotation Variable For The Pyramid */
    rtri  += 0.8f;
    /* Decrease The Rotation Variable For The Cube */
    rquad -=0.6f;

    return( TRUE );
}

int main(int argc, char** argv)
{
    int status;

    /* main loop variable */
    int done=0;
    int isActive=1;
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
    glesWindow = SDL_CreateWindow("NeHe OpenGL lesson 5", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
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
    
    SDL_Event event;
    #endif

    /* initialize OpenGL */
    initGL();

    /* resize the initial window */
    resizeWindow( SCREEN_WIDTH, SCREEN_HEIGHT );

    /* wait for events */
    while (!done)
    {
        #ifdef USE_SDL
        /* handle the events in the queue */
        
        while ( SDL_PollEvent( &event ) )
		{
		    switch( event.type )
			{
			case SDL_MOUSEBUTTONDOWN:
 			case SDL_QUIT:
			    /* handle quit requests */
			    done = TRUE;
			    break;
			default:
			    break;
			}
		}
        #endif

        drawGLScene( );
    }

    /* clean ourselves up and exit */
    Quit(0);

    /* Should never get here */
    return 0;
}
