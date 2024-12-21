#ifndef _EGLTYPES_H
#define _EGLTYPES_H

#ifdef __cplusplus
extern "C" {
#else
#include <stdbool.h>
#endif

#include <EGL/eglplatform.h>

#ifndef GLAPI
#define GLAPI GL_API
#endif

#ifndef APIENTRY
#define APIENTRY GL_APIENTRY
#endif

// bogus types
typedef int EGLDisplay;
typedef int EGLSurface;
typedef int EGLConfig;
typedef int EGLContext;
typedef bool EGLBoolean;

#ifdef __cplusplus
}
#endif

#endif    /* _EGLTYPES_H */
