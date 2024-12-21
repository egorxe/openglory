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
#include <sys/time.h>
#include <math.h>

#include <GLES/gl.h>
#include <GLES/egl.h>
#include "glues_quad.c"

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

/* Set up some booleans */
#define TRUE  1
#define FALSE 0

#ifdef USE_SDL
SDL_Window* glesWindow;
SDL_GLContext glcontext=NULL;
#endif


/* Number of textures to load */
#define NUM_TEXTURES 3

/* This is our SDL surface */
SDL_Surface *surface;

/* Whether or not lighting is on */
int light = FALSE;

GLfloat part1;     /* Start Of Disc         */
GLfloat part2;     /* End Of Disc           */
GLfloat p1 = 0;    /* Increase 1            */
GLfloat p2 = 1;    /* Increase 2            */

GLfloat xrot;      /* X Rotation            */
GLfloat yrot = 5.;      /* Y Rotation            */
GLfloat xspeed;    /* X Rotation Speed      */
GLfloat yspeed;    /* Y Rotation Speed      */
GLfloat z = -5.0f; /* Depth Into The Screen */

/* Ambient Light Values */
GLfloat LightAmbient[]  = { 0.5f, 0.5f, 0.5f, 1.0f };
/* Diffuse Light Values */
GLfloat LightDiffuse[]  = { 1.0f, 1.0f, 1.0f, 1.0f };
/* Light Position */
GLfloat LightPosition[] = { 0.0f, 0.0f, 2.0f, 1.0f };

GLUquadricObj *quadratic;     /* Storage For Our Quadratic Objects */
GLuint object = 5;            /* Which Object To Draw              */

GLuint filter = 0;            /* Which Filter To Use               */
GLuint texture[NUM_TEXTURES]; /* Storage for 3 textures            */

/* return current time (in seconds) */
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
    //SDL_GLES_DeleteContext(context);  

    /* Clean up our quadratic */
    gluDeleteQuadric( quadratic );

    /* Clean up our textures */
    //glDeleteTextures( NUM_TEXTURES, &texture[0] );

    /* clean up the window */
    #ifdef USE_SDL
    SDL_Quit( );
    #endif

    /* and exit appropriately */
    exit( returnCode );
}

/* function to load in bitmap as a GL texture */
int LoadGLTextures( )
{
 
  /* Status indicator */
    int status = FALSE;

    /* Create storage space for the texture */
    SDL_Surface *TextureImage[1]; 

    /* Load The Bitmap, Check For Errors, If Bitmap's Not Found Quit */
    if ( ( TextureImage[0] = IMG_Load( "data/wall.png" ) ) )
        {

	    /* Set the status to true */
	    status = TRUE;

	    /* Create The Texture */
	    glGenTextures( NUM_TEXTURES, &texture[0] );

	    /* Load in texture 1 */
	    /* Typical Texture Generation Using Data From The Bitmap */
	    glBindTexture( GL_TEXTURE_2D, texture[0] );

	    /* Generate The Texture */
	    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, TextureImage[0]->w,
			  TextureImage[0]->h, 0, GL_RGB,
			  GL_UNSIGNED_BYTE, TextureImage[0]->pixels );
	    
	    /* Nearest Filtering */
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
			     GL_NEAREST );
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,
			     GL_NEAREST );

	    /* Load in texture 2 */
	    /* Typical Texture Generation Using Data From The Bitmap */
	    glBindTexture( GL_TEXTURE_2D, texture[1] );

	    /* Linear Filtering */
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
			     GL_LINEAR );
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,
			     GL_LINEAR );

	    /* Generate The Texture */
	    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, TextureImage[0]->w,
			  TextureImage[0]->h, 0, GL_RGB,
			  GL_UNSIGNED_BYTE, TextureImage[0]->pixels );

	    /* Load in texture 3 */
	    /* Typical Texture Generation Using Data From The Bitmap */
	    glBindTexture( GL_TEXTURE_2D, texture[2] );

	    /* Mipmapped Filtering */
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
			     GL_LINEAR_MIPMAP_NEAREST );
	    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,
			     GL_LINEAR );

	    /* Generate The MipMapped Texture ( NEW ) */
	    //gluBuild2DMipmaps( GL_TEXTURE_2D, GL_RGB, TextureImage[0]->w,
			       //TextureImage[0]->h, GL_RGB,
			       //GL_UNSIGNED_BYTE, TextureImage[0]->pixels );
        }

    /* Free up any memory we may have used */
    #ifdef USE_SDL
    if ( TextureImage[0] )
	    SDL_FreeSurface( TextureImage[0] );
    #endif

    return status;
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

#ifdef USE_SDL
/* function to handle key press events */
void handleKeyPress( SDL_Keysym *keysym )
{
    switch ( keysym->sym )
	{
	case SDLK_f:
	    /* 'f' key was pressed
	     * this pages through the different filters
	     */
	    filter = ( filter+1 ) % 3;
	    break;
	case SDLK_l:
	    /* 'l' key was pressed
	     * this toggles the light
	     */
	    light = !light;
	    if ( !light )
		glDisable( GL_LIGHTING );
	    else
		glEnable( GL_LIGHTING );
	    break;
	case SDLK_SPACE:
	    /* Spacebar was pressed
	     * this pages through the objects
	     */
	    object = ( object+1 ) % 6;
	    break;
	case SDLK_i:
	    /* 'i' key was pressed
	     * this zooms into the scene
	     */
	    z += 0.02f;
	    break;
	case SDLK_o:
	    /* 'o' key was pressed
	     * this zooms out of the scene
	     */
	    z -= 0.02f;
	    break;
	case SDLK_UP:
	    /* Up arrow key was pressed
	     * this affects the x rotation
	     */
	    xspeed -= 0.01f;
	    break;
	case SDLK_DOWN:
	    /* Down arrow key was pressed
	     * this affects the x rotation
	     */
	    xspeed += 0.01f;
	    break;
	case SDLK_RIGHT:
	    /* Right arrow key was pressed
	     * this affects the y rotation
	     */
	    yspeed += 0.01f;
	    break;
	case SDLK_LEFT:
	    /* Left arrow key was pressed
	     * this affects the y rotation
	     */
	    yspeed -= 0.01f;
	    break;
	default:
	    break;
	}

    return;
}
#endif

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
    glClearColor( 0.0f, 0.0f, 0.0f, 0.0f );

    /* Depth buffer setup */
    glClearDepthf( 1.0f );

    /* Enables Depth Testing */
    glEnable( GL_DEPTH_TEST );

    /* The Type Of Depth Test To Do */
    glDepthFunc( GL_LEQUAL );

    /* Really Nice Perspective Calculations */
    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );

    /* Setup The Ambient Light */
    //glLightfv( GL_LIGHT0, GL_AMBIENT, LightAmbient );

    /* Setup The Diffuse Light */
    //glLightfv( GL_LIGHT0, GL_DIFFUSE, LightDiffuse );

    /* Position The Light */
    //glLightfv( GL_LIGHT0, GL_POSITION, LightPosition );

    /* Enable Light One */
    //glEnable( GL_LIGHT0 );

    /* Create A Pointer To The Quadric Object */
    quadratic = gluNewQuadric( );
    /* Create Smooth Normals */
    gluQuadricNormals( quadratic, GLU_SMOOTH );
    /* Create Texture Coords */
    gluQuadricTexture( quadratic, GL_TRUE );

    return( TRUE );
}

GLvoid drawGLCube( GLvoid )
{
    int quad;

    /* Enable vertices and texcoords arrays */
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

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
         
    const GLfloat texCoords[][8] = {
      {    /* Front Face */
        0.0f, 1.0f,               /* Bottom Left Of The Texture */
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

    const GLfloat normVectors[][3] = {
      {  0.0f,  0.0f,  1.0f },    /* Normal Pointing Towards Viewer */
      {  0.0f,  0.0f, -1.0f },    /* Normal Pointing Away From Viewer */
      {  0.0f,  1.0f,  0.0f },    /* Normal Pointing Up */
      {  0.0f, -1.0f,  0.0f },    /* Normal Pointing Down */
      {  1.0f,  0.0f,  0.0f },    /* Normal Pointing Right */
      { -1.0f,  0.0f,  0.0f },    /* Normal Pointing Left */
    };

    /* Loop through all Quads */
    for(quad=0;quad<sizeof(quadVertices)/(12*sizeof(GLfloat));quad++) 
    {
      glNormal3f(normVectors[quad][0], normVectors[quad][1], normVectors[quad][2]);

      glVertexPointer(3, GL_FLOAT, 0, quadVertices[quad]);
      glTexCoordPointer(2, GL_FLOAT, 0, texCoords[quad]);
      glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
}

/* Here goes our drawing code */
int drawGLScene( GLvoid )
{
    /* These are to calculate our fps */
    static GLint T0     = 0;
    static GLint Frames = 0;

    /* Clear The Screen And The Depth Buffer */
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    /* Reset the view */
    glLoadIdentity( );

    /* Translate Into/Out Of The Screen By z */
    glTranslatef( 0.0f, 0.0f, z );

    glRotatef( xrot, 1.0f, 0.0f, 0.0f); /* Rotate On The X Axis By xrot */
    glRotatef( yrot, 0.0f, 1.0f, 0.0f); /* Rotate On The Y Axis By yrot */

    /* Select A Texture Based On filter */
    glBindTexture( GL_TEXTURE_2D, texture[filter] );

    /* Determine what object to draw */
    switch( object )
	{
	case 0:
	    /* Draw our cube */
	    drawGLCube( );
	    break;
	case 1:
	    /* Draw a cylinder */
	    glTranslatef( 0.0f, 0.0f, -1.5f );
	    gluCylinder( quadratic, 1.0f, 1.0f, 3.0f, 32, 32 );
	    break;
	case 2:
	    /* Draw a disk */
	    gluDisk( quadratic, 0.5f, 1.5f, 32, 32 );
	    break;
	case 3:
	    /* Draw a sphere */
	    gluSphere( quadratic, 1.3f, 32, 32 );
	    break;
	case 4:
	    /* Draw a cone */
	    glTranslatef( 0.0f, 0.0f, -1.5f );
	    gluCylinder( quadratic, 1.0f, 0.0f, 3.0f, 32, 32 );
	    break;
	case 5:
	    /* Create a partial disk */
	    part1 += p1;
	    part2 += p2;
	    if ( part1 > 359 )
		{
		    p1    = 0;
		    part1 = 0;
		    p2    = 1;
		    part2 = 0;
		}
	    if ( part2 > 359 )
		{
		    p1 = 1;
		    p2 = 0;
		}

	    gluPartialDisk( quadratic, 0.5f, 1.5f, 32, 32,
			    part1, part2 - part1 );
	    break;
	};

    /* Draw it to the screen */
    eglSwapBuffers(glDisplay, glSurface);

    /* Gather our frames per second */
    Frames++;
    {
        GLint t = current_time();
        if (t - T0 >= 5) {
            GLfloat seconds = (t - T0);
            GLfloat fps = Frames / seconds;
            printf("%d frames in %g seconds = %g FPS\n", Frames, seconds, fps);
            T0 = t;
            Frames = 0;
        }
    }

    xrot += xspeed; /* Add xspeed To xrot */
    yrot += yspeed; /* Add yspeed To yrot */

    return( TRUE );
}

int main( int argc, char **argv )
{
    /* main loop variable */
    int done = FALSE;
    /* whether or not the window is active */
    int isActive = TRUE;
    
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
    glesWindow = SDL_CreateWindow("NeHe OpenGL lesson 18", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT,
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
    SDL_Event event;

    /* initialize OpenGL */
    if ( initGL( ) == FALSE )
	{
	    fprintf( stderr, "Could not initialize OpenGL.\n" );
	    Quit( 1 );
	}

    /* resize the initial window */
    resizeWindow( SCREEN_WIDTH, SCREEN_HEIGHT );

    /* wait for events */
    while ( !done )
	{
	    /* handle the events in the queue */

	    #ifdef USE_SDL
        while ( SDL_PollEvent( &event ) )
		{
		    switch( event.type )
			{
            #if 0
			case SDL_ACTIVEEVENT:
			    /* Something's happend with our focus
			     * If we lost focus or we are iconified, we
			     * shouldn't draw the screen
			     */
			    if ( event.active.gain == 0 )
				isActive = FALSE;
			    else
				isActive = TRUE;
			    break;			    
            #endif
			case SDL_KEYDOWN:
			    /* handle key presses */
			    handleKeyPress( &event.key.keysym );
			    break;
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

	    /* draw the scene */
	    if ( isActive )
		drawGLScene( );
	}

    /* clean ourselves up and exit */
    Quit( 0 );

    /* Should never get here */
    return( 0 );
}
