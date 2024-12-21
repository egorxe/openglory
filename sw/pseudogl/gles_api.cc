// OpenGLES-like API for OpenGLory pseudoGPU

#include <assert.h>
#include <cmath>

#include "GLES/gl.h"
#include "EGL/egl.h"
#include "oglory_gpu_defs.hh"
#include <pseudogl.hh>

// #define STUB() std::cerr << "##PGL_GLES_STUB##: " << __func__ << std::endl
#define STUB()

static PseudoGLContext context;

// Helpers

static float Clamp(float x, float min = 0., float max = 1.)
{
    return std::min(std::max(x, min), max);
}

static void SetClientState(GLenum array, bool state)
{
    switch (array)
    {
        case(GL_COLOR_ARRAY):
            context.SetVertexArrayEnabled(PGL_COLOR_ARRAY, state);
            break;

        case(GL_VERTEX_ARRAY):
            context.SetVertexArrayEnabled(PGL_VERTEX_ARRAY, state);
            break;

        case(GL_NORMAL_ARRAY):
            context.SetVertexArrayEnabled(PGL_NORMAL_ARRAY, state);
            break;

        case(GL_TEXTURE_COORD_ARRAY):
            context.SetVertexArrayEnabled(PGL_TEXCOORD_ARRAY, state);
            break;

        default:
            assert(false);
            STUB();
    }
}

static void SetState(GLenum cap, bool state)
{
    switch (cap)
    {
        case(GL_LIGHTING):
            context.SetLighting(state);
            break;
        case(GL_CULL_FACE):
            context.SetCulling(state);
            break;
        case(GL_DEPTH_TEST):
            context.SetDepthTest(state);
            break;
        case(GL_LIGHT0):
            STUB();
            break;        
        case(GL_TEXTURE_2D):
            break;
        case(GL_ALPHA_TEST):
            context.SetAlphaTest(state);
            break;        
        case(GL_DITHER):
            assert(state == false);
            break;        
        case(GL_BLEND):
            context.SetBlending(state);
            break;
        default:
            STUB();
            assert(false);
    }
}

static size_t GlTypeSize(const int t)
{
    switch(t)
    {
        case(GL_BYTE):
            return sizeof(GLbyte);
        case(GL_UNSIGNED_BYTE):
            return sizeof(GLubyte);
        case(GL_UNSIGNED_SHORT):
            return sizeof(GLushort);
        case(GL_SHORT):
            return sizeof(GLshort);
        case(GL_FLOAT):
            return sizeof(GLfloat);
        default:
            assert(false); 
            return 0;
    }
}

static uint8_t ConvBlendFunc(const uint f)
{
    switch(f)
    {
        case(GL_ZERO): return BLENDF_ZERO;
        case(GL_ONE): return BLENDF_ZERO;
        case(GL_ONE_MINUS_SRC_COLOR): return BLENDF_ONE_MINUS_SRC_COLOR;
        case(GL_SRC_ALPHA): return BLENDF_SRC_ALPHA;
        case(GL_ONE_MINUS_SRC_ALPHA): return BLENDF_ONE_MINUS_SRC_ALPHA;
        default: assert(false); // unsupported blending function
    }
}

// OpenGL ES functions

GL_API void GL_APIENTRY glAlphaFunc (GLenum func, GLfloat ref)
{
    STUB(); 
}

GL_API void GL_APIENTRY glClearColor (GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
    STUB();
    // clear could be any color that you want as long as it is black!
    // assert(red == 0 && green == 0 && blue == 0);
}

GL_API void GL_APIENTRY glClearDepthf (GLfloat d)
{
    STUB();
}

GL_API void GL_APIENTRY glDepthRangef (GLfloat n, GLfloat f)
{
    STUB();
    // assert(n == 0.0 && f == 1.0);
    context.SetDepthRange({Clamp(n), Clamp(f)});
}

GL_API void GL_APIENTRY glColor4f (GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
    context.SetCurColor(Color({red, green, blue, alpha}));
}

GL_API void GL_APIENTRY glFrustumf (GLfloat l, GLfloat r, GLfloat b, GLfloat t, GLfloat n, GLfloat f)
{
    M4 m;
    GLfloat* rm = &m.m[0][0];

    GLfloat x,y,A,B,C,D;
    x = (2.0 * n) / (r - l);
    y = (2.0 * n) / (t - b);
    A = (r + l) / (r - l);
    B = (t + b) / (t - b);
    C = -(f + n) / (f - n);
    D = -(2.0 * f * n) / (f - n);

    rm[0] = x;
    rm[1] = 0;
    rm[2] = A;
    rm[3] = 0;
    rm[4] = 0;
    rm[5] = y;
    rm[6] = B;
    rm[7] = 0;
    rm[8] = 0;
    rm[9] = 0;
    rm[10] = C;
    rm[11] = D;
    rm[12] = 0;
    rm[13] = 0;
    rm[14] = -1;
    rm[15] = 0;

    context.MultMatrix(m);
}

GL_API void GL_APIENTRY glLightfv (GLenum light, GLenum pname, const GLfloat *params)
{
    assert(light == GL_LIGHT0);
    light &= 0xF;

    switch (pname)
    {
        case(GL_POSITION):
            context.SetLightPosition(light, params);
            break;
        case(GL_DIFFUSE):
            context.SetLightColor(light, params);
            break;
        default:
            STUB();
            assert(false);
    }
}

GL_API void GL_APIENTRY glLoadMatrixf (const GLfloat *m)
{
    M4 mx;

    for(int i = 0; i < 4; i++) 
    {
        mx.m[0][i]=m[i*4+0];
        mx.m[1][i]=m[i*4+1];
        mx.m[2][i]=m[i*4+2];
        mx.m[3][i]=m[i*4+3];
    }
    context.LoadMatrix(mx);
}

GL_API void GL_APIENTRY glMaterialfv (GLenum face, GLenum pname, const GLfloat *params)
{
    assert(face == GL_FRONT_AND_BACK);
    switch (pname)
    {
        case(GL_AMBIENT_AND_DIFFUSE):
            context.SetMaterialDiffuse(params);

        case(GL_AMBIENT):
            context.SetMaterialAmbient(params);
            break;

        case(GL_DIFFUSE):
            context.SetMaterialDiffuse(params);
            break;

        default:
            STUB();
            assert(false);
    }
}

GL_API void GL_APIENTRY glMultMatrixf (const GLfloat *m)
{
    M4 mx;

    for(int i = 0; i < 4; i++) 
    {
        mx.m[0][i]=m[i*4+0];
        mx.m[1][i]=m[i*4+1];
        mx.m[2][i]=m[i*4+2];
        mx.m[3][i]=m[i*4+3];
    }
    context.MultMatrix(mx);
}

GL_API void GL_APIENTRY glNormal3f (GLfloat nx, GLfloat ny, GLfloat nz)
{
    STUB();
    // assert(false);
}

GL_API void GL_APIENTRY glOrthof (GLfloat l, GLfloat r, GLfloat b, GLfloat t, GLfloat n, GLfloat f)
{
    M4 m;
    GLfloat* rm = &m.m[0][0];

	GLfloat rml = r - l;
	GLfloat fmn = f - n;
	GLfloat tmb = t - b;
	GLfloat inv_rml;
	GLfloat inv_fmn;
	GLfloat inv_tmb;

	inv_rml = 1.0 / rml;
	inv_fmn = 1.0 / fmn;
	inv_tmb = 1.0 / tmb;

	rm[0] = 2.0 * inv_rml;
	rm[1] = 0.0;
	rm[2] = 0.0;
	rm[3] = -(r + l) *  inv_rml;

	rm[4] = 0.0;
	rm[5] = 2.0 * inv_tmb;
	rm[6] = 0.0;
	rm[7] = -(t + b) *  inv_tmb;

	rm[8] = 0.0;
	rm[9] = 0.0;
	rm[10] = -2.0 * inv_fmn;
	rm[11] = -(f + n) * inv_fmn;

	rm[12] = 0.0;
	rm[13] = 0.0;
	rm[14] = 0.0;
	rm[15] = 1.0;

	context.MultMatrix(m);
}

GL_API void GL_APIENTRY glRotatef (GLfloat angle, GLfloat x, GLfloat y, GLfloat z)
{
    if (angle == 0.0f || (x == 0.0f && y == 0.0f && z == 0.0f))
        return;

    float u[3];
    M4 m;

    angle = angle * M_PI / 180.0;
    u[0] = x;
    u[1] = y;
    u[2] = z;

    /* normalize vector */
    float len = u[0] * u[0] + u[1] * u[1] + u[2] * u[2];
    assert (len != 0.0f);
    len = 1.0f / sqrt(len);

    x *= len;
    y *= len;
    z *= len;
    
    /* store cos and sin values */
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0f - c;

    /* fill in the values */
    m.m[3][0] = m.m[3][1] = m.m[3][2] = m.m[0][3] = m.m[1][3] = m.m[2][3] = 0.0f;
    m.m[3][3] = 1.0f;

    /* do the math */
    m.m[0][0] = c+x*x*t;
    m.m[1][0] = y*x*t+z*s;
    m.m[2][0] = z*x*t-y*s;
    m.m[0][1] = x*y*t-z*s;
    m.m[1][1] = c+y*y*t;
    m.m[2][1] = z*y*t+x*s;
    m.m[0][2] = x*z*t+y*s;
    m.m[1][2] = y*z*t-x*s;
    m.m[2][2] = z*z*t+c;

    context.MultMatrix(m);
}

GL_API void GL_APIENTRY glScalef (GLfloat x, GLfloat y, GLfloat z)
{
    PglMatrix m; // identity

	m.m[0][0] = x;
	m.m[1][1] = y;
	m.m[2][2] = z;

	context.MultMatrix(m);
}

GL_API void GL_APIENTRY glTexEnvf (GLenum target, GLenum pname, GLfloat param)
{
    STUB(); 
}

GL_API void GL_APIENTRY glTexParameterf (GLenum target, GLenum pname, GLfloat param)
{
    STUB(); 
}

GL_API void GL_APIENTRY glTranslatef (GLfloat x, GLfloat y, GLfloat z)
{
    M4 m(IDENTITY);
    m.m[0][3] = x;
    m.m[1][3] = y;
    m.m[2][3] = z;
    context.MultMatrix(m);
}

GL_API void GL_APIENTRY glActiveTexture (GLenum texture)
{
    STUB(); 
    // assert(texture == GL_TEXTURE0);
}

GL_API void GL_APIENTRY glBindTexture (GLenum target, GLuint texture)
{
    STUB(); 
    context.BindTexture(texture);
}

GL_API void GL_APIENTRY glBlendFunc (GLenum sfactor, GLenum dfactor)
{
    context.SetBlendFunc({ConvBlendFunc(sfactor), ConvBlendFunc(dfactor)});
}

GL_API void GL_APIENTRY glClear (GLbitfield mask)
{
    assert(!(mask & ~(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)));
    context.ClearBuffer((mask & GL_COLOR_BUFFER_BIT), (mask & GL_DEPTH_BUFFER_BIT));
}

GL_API void GL_APIENTRY glClientActiveTexture (GLenum texture)
{
    STUB(); 
    // assert(texture == GL_TEXTURE0);
}

GL_API void GL_APIENTRY glColorPointer(GLint size, GLenum type, GLsizei stride, const void *pointer)
{
    assert(size == 4);
    assert(type == GL_FLOAT || GL_UNSIGNED_BYTE);
    assert(stride >= 0);

    context.SetVertexArray(PGL_COLOR_ARRAY, size, GlTypeSize(type), stride, (const GLfloat*)pointer);
}

GL_API void GL_APIENTRY glCompressedTexImage2D (GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, const void *data)
{
    STUB(); 
    assert(false);
}

GL_API void GL_APIENTRY glCullFace (GLenum mode)
{
    switch (mode)
    {
        case GL_BACK:
            context.SetCullingFace(GPU_STATE_RAST_CULLBACK);
            break;
        case GL_FRONT:
            context.SetCullingFace(GPU_STATE_RAST_CULLFRONT);
            break;        
        case GL_FRONT_AND_BACK:
            context.SetCullingFace(0);
            break;
        default:
            assert(false);
    }
}

GL_API void GL_APIENTRY glDeleteTextures (GLsizei n, const GLuint *textures)
{
    STUB(); 
    assert(false);
}

GL_API void GL_APIENTRY glDepthFunc (GLenum func)
{
    STUB();
    // assert(func == GL_LESS);
    assert(func == GL_LESS || func == GL_LEQUAL); // !! actually only less or equal 
}

GL_API void GL_APIENTRY glDepthMask (GLboolean flag)
{
    context.SetDepthMask(flag);
}

GL_API void GL_APIENTRY glDisable (GLenum cap)
{
    SetState(cap, false);
}

GL_API void GL_APIENTRY glDisableClientState (GLenum array)
{
    SetClientState(array, false);
}

GL_API void GL_APIENTRY glDrawArrays (GLenum mode, GLint first, GLsizei count)
{
    assert(mode == GL_TRIANGLES || mode == GL_TRIANGLE_STRIP || mode == GL_TRIANGLE_FAN);
    context.CopyDrawArray(first, count, mode);
}

GL_API void GL_APIENTRY glDrawElements (GLenum mode, GLsizei count, GLenum type, const void *indices)
{
    assert(type == GL_UNSIGNED_BYTE || type == GL_UNSIGNED_SHORT);
    context.CopyDrawArray(0, count, mode, indices, GlTypeSize(type));
}

GL_API void GL_APIENTRY glEnable (GLenum cap)
{
    SetState(cap, true);
}

GL_API void GL_APIENTRY glEnableClientState (GLenum array)
{
    SetClientState(array, true);
}

GL_API void GL_APIENTRY glFinish (void)
{
    context.PipelineFlushAsync();
}

GL_API void GL_APIENTRY glFlush (void)
{
    context.CommitCmdBuffer();
}

GL_API void GL_APIENTRY glFrontFace (GLenum mode)
{
    assert(mode == GL_CW || mode == GL_CCW);
    context.SetFrontFace(mode == GL_CCW);
}

GL_API void GL_APIENTRY glGenTextures (GLsizei n, GLuint *textures)
{
    for (int i = 0; i < n; i++) 
        textures[i] = context.GenTexture();
}

GL_API GLenum GL_APIENTRY glGetError (void)
{
    STUB();
    return GL_NO_ERROR;
}

GL_API void GL_APIENTRY glHint (GLenum target, GLenum mode)
{
    STUB();
}

GL_API void GL_APIENTRY glLoadIdentity (void)
{
    context.LoadMatrix(IDENTITY);
}

GL_API const GLubyte *GL_APIENTRY glGetString (GLenum name)
{
    static const GLubyte nullstr[] = "";
    static const GLubyte vendor[] = "OpenGLory";
    static const GLubyte version[] = "OpenGL ES-CM 1.1";    // actually even far from 1.0 :)
    
    switch (name)
    {
        case(GL_RENDERER):
            return (const GLubyte*)context.GetBoardName();

        case(GL_VENDOR):
            return vendor;
            
        case(GL_VERSION):
            return version;

        default:
            return nullstr;
    }
}

GL_API void GL_APIENTRY glMatrixMode (GLenum mode)
{
    if (mode == GL_MODELVIEW)
        context.SelCurMatrix(PGL_MODEL_MATRIX);
    else if (mode == GL_PROJECTION)
        context.SelCurMatrix(PGL_PROJ_MATRIX);
    else
    {
        STUB();
        assert(false); 
    }
}

GL_API void GL_APIENTRY glNormalPointer (GLenum type, GLsizei stride, const void *pointer)
{
    assert(type == GL_FLOAT);
    assert(stride >= 0);

    context.SetVertexArray(PGL_NORMAL_ARRAY, 3, GlTypeSize(type), stride, (const GLfloat*)pointer);
}

GL_API void GL_APIENTRY glPopMatrix (void)
{
    context.PopMatrix();
}

GL_API void GL_APIENTRY glPushMatrix (void)
{
    context.PushMatrix();
}

GL_API void GL_APIENTRY glReadPixels (GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void *pixels)
{
    STUB(); 
    assert(false);
}

GL_API void GL_APIENTRY glShadeModel (GLenum mode)
{
    STUB();
}

GL_API void GL_APIENTRY glTexCoordPointer (GLint size, GLenum type, GLsizei stride, const void *pointer)
{
    assert(type == GL_FLOAT || GL_BYTE);
    assert(size == 2);
    assert(stride >= 0);

    if (type == GL_BYTE)
    {
        // !!!??? works ???!!!
    }

    context.SetVertexArray(PGL_TEXCOORD_ARRAY, size, GlTypeSize(type), stride, (const GLfloat*)pointer);
}

GL_API void GL_APIENTRY glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels)
{
    STUB();
    assert(target == GL_TEXTURE_2D);
    if (level)
        return;
    // assert(format == internalformat);
    assert(border == 0);
    
    context.AllocTexture(format, width, height);
    context.SetTexture(format, type);

    if (pixels)
    {
        context.LoadTexture((const uint8_t*)pixels, 0, 0, width, height);
    }
}

GL_API void GL_APIENTRY glTexParameteri (GLenum target, GLenum pname, GLint param)
{
    STUB();
}

GL_API void GL_APIENTRY glTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels)
{
    STUB(); 
    assert(target == GL_TEXTURE_2D);
    if (level)
        return;
    assert(pixels);

    context.SetTexture(format, type);
    context.LoadTexture((const uint8_t*)pixels, xoffset, yoffset, width, height);
}

GL_API void GL_APIENTRY glVertexPointer (GLint size, GLenum type, GLsizei stride, const void *pointer)
{
    assert(size == 2 || size == 3); 
    assert(type == GL_FLOAT);
    assert(stride >= 0);

    context.SetVertexArray(PGL_VERTEX_ARRAY, size, GlTypeSize(type), stride, (const GLfloat*)pointer);
}

GL_API void GL_APIENTRY glViewport (GLint x, GLint y, GLsizei width, GLsizei height)
{
    STUB();
    // assert(x == 0 && y == 0 && width == 640 && height == 480);
    assert(width >= 0 && height >= 0);
    context.SetViewport({(uint32_t)x, (uint32_t)y, Clamp(width, 0, PGL_WND_SIZE_X), Clamp(height, 0, PGL_WND_SIZE_Y)});
}


// EGL stub
GLAPI EGLBoolean APIENTRY eglSwapBuffers (EGLDisplay dpy, EGLSurface draw)
{
    context.SwapBuffers();
    return true;
}
