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
#include <math.h>
#include <assert.h>
#include <sys/time.h>

#include <GLES/gl.h>
#include <GLES/egl.h>

EGLDisplay  glDisplay;
EGLConfig   glConfig;
EGLContext  glContext;
EGLSurface  glSurface;

#ifdef USE_SDL
#include <SDL2/SDL.h>
#include <SDL2/SDL_opengles.h>
#include <SDL2/SDL_syswm.h>
#endif
#include <SDL2/SDL_image.h>

/* screen width, height, and bit depth */
#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480
#define SCREEN_BPP     16

/* Set up some booleans */
#define TRUE  1
#define FALSE 0

#ifdef USE_SDL
SDL_Window* glesWindow;
SDL_GLContext glcontext=NULL;
#endif

GLfloat xrot; /* X Rotation ( NEW ) */
GLfloat yrot; /* Y Rotation ( NEW ) */
GLfloat zrot; /* Z Rotation ( NEW ) */

GLuint texture[1]; /* Storage For One Texture ( NEW ) */

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
void Quit( int returnCode )
{
    #ifdef USE_SDL
    /* clean up the window */
    SDL_GL_DeleteContext(glcontext);
    SDL_DestroyWindow(glesWindow);

    SDL_Quit();
    #endif

    /* and exit appropriately */
    exit( returnCode );
}

/* function to load in bitmap as a GL texture */
int LoadGLTextures( )
{
    /* Status indicator */
    int stat = FALSE;

    /* Create storage space for the texture */
    SDL_Surface *TextureImage[1]; 
    
    /* Load The Bitmap, Check For Errors, If Bitmap's Not Found Quit */
    if ( ( TextureImage[0] = IMG_Load( "data/nehe.png" ) ) )
    {
        
        /* Set the status to true */
        stat = TRUE;
        
        /* Create The Texture */
        glGenTextures( 1, &texture[0] );
        
        /* Typical Texture Generation Using Data From The Bitmap */
        glBindTexture( GL_TEXTURE_2D, texture[0] );
        
        /* Generate The Texture */
        glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, TextureImage[0]->w,
                  TextureImage[0]->h, 0, GL_RGB,
                  GL_UNSIGNED_BYTE, TextureImage[0]->pixels );
        
        /* Linear Filtering */
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
    } else
        printf("Unable to load bitmap\n");

    /* Free up any memory we may have used */
    #ifdef USE_SDL
    if ( TextureImage[0] )
        SDL_FreeSurface( TextureImage[0] );
    #endif

    return stat;
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
    glViewport( 0, 0, ( GLint )width, ( GLint )height );

    /*
     * change to the projection matrix and set
     * our viewing volume.
     */
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
int initGL( GLvoid )
{
    /* Load in the texture */
    if ( !LoadGLTextures( ) )
    return FALSE;

    /* Enable Texture Mapping ( NEW ) */
    glEnable( GL_TEXTURE_2D );

    /* Enable smooth shading */
    glShadeModel( GL_SMOOTH );

    /* Set the background black */
    glClearColor( 0.0f, 0.0f, 0.0f, 0.5f );

    /* Depth buffer setup */
    //glClearDepthf( 1.0f );

    /* Enables Depth Testing */
    glEnable( GL_DEPTH_TEST );

    /* The Type Of Depth Test To Do */
    glDepthFunc( GL_LEQUAL );

    /* Really Nice Perspective Calculations */
    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

    return( TRUE );
}

/* Here goes our drawing code */
int drawGLScene( GLvoid )
{
    /* These are to calculate our fps */
    static double T0    = 0;
    static GLint Frames = 0;
    int quad;

    /* Clear The Screen And The Depth Buffer */
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    /* Move Into The Screen 5 Units */
    glLoadIdentity( );
    glTranslatef( 0.0f, 0.0f, -5.0f );

    glRotatef( xrot, 1.0f, 0.0f, 0.0f); /* Rotate On The X Axis */
    glRotatef( yrot, 0.0f, 1.0f, 0.0f); /* Rotate On The Y Axis */
    glRotatef( zrot, 0.0f, 0.0f, 1.0f); /* Rotate On The Z Axis */

    /* Select Our Texture */
    glBindTexture( GL_TEXTURE_2D, texture[0] );

    const GLfloat quadVertices[][12] = {
      {    /* Front Face */
    -1.0f, -1.0f,  1.0f,      /* Bottom Left Of The Quad */
     1.0f, -1.0f,  1.0f,      /* Bottom Right Of The Quad */
    -1.0f,  1.0f,  1.0f,      /* Top Left Of The Quad */
     1.0f,  1.0f,  1.0f,      /* Top Right Of The Quad */
      }, { /* Back Face */
    -1.0f, -1.0f, -1.0f,      /* Bottom Right Of The Quad */
    -1.0f,  1.0f, -1.0f,      /* Top Right Of The Quad */
     1.0f, -1.0f, -1.0f,      /* Bottom Left Of The Quad */
     1.0f,  1.0f, -1.0f,      /* Top Left Of The Quad */
      }, { /* Top Face */
    -1.0f,  1.0f, -1.0f,      /* Top Left Of The Quad */
    -1.0f,  1.0f,  1.0f,      /* Bottom Left Of The Quad */
     1.0f,  1.0f, -1.0f,      /* Top Right Of The Quad */
     1.0f,  1.0f,  1.0f,      /* Bottom Right Of The Quad */
      }, { /* Bottom Face */
    -1.0f, -1.0f, -1.0f,      /* Top Right Of The Quad */
     1.0f, -1.0f, -1.0f,      /* Top Left Of The Quad */
    -1.0f, -1.0f,  1.0f,      /* Bottom Right Of The Quad */
     1.0f, -1.0f,  1.0f,      /* Bottom Left Of The Quad */
      }, { /* Right face */
     1.0f, -1.0f, -1.0f,      /* Bottom Right Of The Quad */
     1.0f,  1.0f, -1.0f,      /* Top Right Of The Quad */
     1.0f, -1.0f,  1.0f,      /* Bottom Left Of The Quad */
     1.0f,  1.0f,  1.0f,      /* Top Left Of The Quad */
      }, {/* Left Face */
    -1.0f, -1.0f, -1.0f,      /* Bottom Left Of The Quad */
    -1.0f, -1.0f,  1.0f,      /* Bottom Right Of The Quad */
    -1.0f,  1.0f, -1.0f,      /* Top Left Of The Quad */
    -1.0f,  1.0f,  1.0f,      /* Top Right Of The Quad */
      }
    };
         
    /* NOTE:
     *   The x coordinates of the texture coordinates need to inverted
     * for SDL because of the way SDL_LoadBmp loads the data. So where
     * in the tutorial it has glTexCoord2f( 1.0f, 0.0f ); it should
     * now read 0.0f, 0.0f
     */
    const GLfloat texCoords[][8] = {
      {    /* Front Face */
    0.0f, 1.0f,                  /* Bottom Left Of The Texture */
    1.0f, 1.0f,               /* Bottom Right Of The Texture */
    0.0f, 0.0f,               /* Top Left Of The Texture */
    1.0f, 0.0f,               /* Top Right Of The Texture */
      },{ /* Back Face */
    0.0f, 0.0f,               /* Bottom Right Of The Texture */
    0.0f, 1.0f,               /* Top Right Of The Texture */
    1.0f, 0.0f,               /* Bottom Left Of The Texture */
    1.0f, 1.0f,               /* Top Left Of The Texture */
      },{ /* Top Face */
    1.0f, 1.0f,               /* Top Left Of The Texture */
    1.0f, 0.0f,               /* Bottom Left Of The Texture */
    0.0f, 1.0f,               /* Top Right Of The Texture */
    0.0f, 0.0f,               /* Bottom Right Of The Texture */
      },{ /* Bottom Face */
    0.0f, 1.0f,               /* Top Right Of The Texture */
    1.0f, 1.0f,               /* Top Left Of The Texture */
    0.0f, 0.0f,               /* Bottom Right Of The Texture */
    1.0f, 0.0f,               /* Bottom Left Of The Texture */
      },{ /* Right face */
    0.0f, 0.0f,               /* Bottom Right Of The Texture */
    0.0f, 1.0f,               /* Top Right Of The Texture */
    1.0f, 0.0f,               /* Bottom Left Of The Texture */
    1.0f, 1.0f,               /* Top Left Of The Texture */
      },{ /* Left Face */
    1.0f, 0.0f,               /* Bottom Left Of The Texture */
    0.0f, 0.0f,               /* Bottom Right Of The Texture */
    1.0f, 1.0f,               /* Top Left Of The Texture */
    0.0f, 1.0f,               /* Top Right Of The Texture */
      }
    };

    /* Loop through all Quads */
    for(quad=0;quad<sizeof(quadVertices)/(12*sizeof(GLfloat));quad++) 
    {
      glVertexPointer(3, GL_FLOAT, 0, quadVertices[quad]);
      glTexCoordPointer(2, GL_FLOAT, 0, texCoords[quad]);
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
    

    xrot += 0.3f; /* X Axis Rotation */
    yrot += 0.2f; /* Y Axis Rotation */
    zrot += 0.4f; /* Z Axis Rotation */

    return( TRUE );
}

int main( int argc, char **argv )
{
    /* main loop variable */
    int done = FALSE;
    
    /* whether or not the window is active */
    int isActive = TRUE;

    #ifdef USE_SDL
    /* used to collect events */
    SDL_Event event;
    
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
    glesWindow = SDL_CreateWindow("NeHe OpenGL lesson 6", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
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

    /* initialize OpenGL */
    assert(initGL( ));

    /* resize the initial window */
    resizeWindow( SCREEN_WIDTH, SCREEN_HEIGHT );

    /* wait for events */
    while ( !done )
    {
        #ifdef USE_SDL
        /* handle the events in the queue */

        while ( SDL_PollEvent( &event ) )
        {
            switch( event.type )
            {
            case SDL_QUIT:
                /* handle quit requests */
                done = TRUE;
                break;
            default:
                break;
            }
        }
        #endif

        /* draw the scene */
        if ( isActive )
        drawGLScene( );
    }

    /* clean ourselves up and exit */
    Quit( 0 );

    /* Should never get here */
    return( 0 );
}
