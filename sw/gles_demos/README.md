# OpenGL ES demos

Several simple test programs for OpenGLory.

## Building

To build for regular OpenGL ES with SDL go to test directory and run:
```make sdl```

To build for pseudogl on OpenGlory go to test directory and run:
```make oglory```

Binary will be produced in build dir.

For dirs containing several tests, test could be selected via DEMO environmental variable. For draw_array test valid DEMO values are: cube, cow, suzanne, teapot0, teapot1. Example:

```cd sw/gles_demos/draw_arrays && DEMO=suzanne make oglory && ../build/suzanne.oglory```

## Original demo sources

[draw_arrays/models](https://github.com/alecjacobson/common-3d-test-models)
[gears](https://community.khronos.org/t/glesgears/1278)
[nehe](http://maemo.org/packages/source/view/fremantle_extras_free_source/nehegles/1.4.1/)

