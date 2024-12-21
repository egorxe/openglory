#include <cassert> 
#include <cmath> 
#include <cstdio> 
#include <cstring> 

#include <gpu_pipeline.hh>

extern M4 model_matrix;

void M4_print(M4 m)
{
    for (int i = 0; i < 4; ++i)
    {
        for (int j = 0; j < 4; ++j)
        {
            printf("%f ", m.m[i][j]);
        }
        puts("");
    }
}

void gl_M4_MulV4(Vec4 a, M4* b, Vec4 c) 
{
    Vec4 tmp;
    tmp[0] = b->m[0][0] * c[0] + b->m[0][1] * c[1] + b->m[0][2] * c[2] + b->m[0][3] * c[3];
    tmp[1] = b->m[1][0] * c[0] + b->m[1][1] * c[1] + b->m[1][2] * c[2] + b->m[1][3] * c[3];
    tmp[2] = b->m[2][0] * c[0] + b->m[2][1] * c[1] + b->m[2][2] * c[2] + b->m[2][3] * c[3];
    tmp[3] = b->m[3][0] * c[0] + b->m[3][1] * c[1] + b->m[3][2] * c[2] + b->m[3][3] * c[3];
    memcpy(a, tmp, 4*sizeof(float));
}


void gl_M4_MulLeft(M4* c, M4* b) 
{
    int i, j, k;
    float s;
    M4 a;

    a = *c;
    for (i = 0; i < 4; i++)
        for (j = 0; j < 4; j++) {
            s = 0.0;
            for (k = 0; k < 4; k++)
                s += a.m[i][k] * b->m[k][j];
            c->m[i][j] = s;
        }
}

void gl_M4_Transpose(M4* a, M4* b) 
{
    M4 tmp;
    {
        tmp.m[0][0] = b->m[0][0];
        tmp.m[0][1] = b->m[1][0];
        tmp.m[0][2] = b->m[2][0];
        tmp.m[0][3] = b->m[3][0];

        tmp.m[1][0] = b->m[0][1];
        tmp.m[1][1] = b->m[1][1];
        tmp.m[1][2] = b->m[2][1];
        tmp.m[1][3] = b->m[3][1];

        tmp.m[2][0] = b->m[0][2];
        tmp.m[2][1] = b->m[1][2];
        tmp.m[2][2] = b->m[2][2];
        tmp.m[2][3] = b->m[3][2];

        tmp.m[3][0] = b->m[0][3];
        tmp.m[3][1] = b->m[1][3];
        tmp.m[3][2] = b->m[2][3];
        tmp.m[3][3] = b->m[3][3];
    }
    *a = tmp;
}

void glRotate(float angle, float x, float y, float z, bool verbose=false) 
{
    if (verbose) {
        printf("Rotation matrix for angle=%f, x=%f, y=%f, z=%f\n", angle, x, y, z);
    }
    
    float u[3];
    M4 m;

    angle = angle * M_PI / 180.0;
    u[0] = x;
    u[1] = y;
    u[2] = z;

    float cost, sint;

    /* normalize vector */

    float len = u[0] * u[0] + u[1] * u[1] + u[2] * u[2];
    assert (len != 0.0f);
    len = 1.0f / sqrt(len);

    x *= len;
    y *= len;
    z *= len;
    /* store cos and sin values */
    cost = cos(angle);
    sint = sin(angle);
    float c = cos(angle);
    float s = sin(angle);
    float t = 1 - c;

    /* fill in the values */
    m.m[3][0] = m.m[3][1] = m.m[3][2] = m.m[0][3] = m.m[1][3] = m.m[2][3] = 0.0f;
    m.m[3][3] = 1.0f;

    /* do the math */
    //m.m[0][0] = u[0] * u[0] + cost * (1 - u[0] * u[0]);
    //m.m[1][0] = u[0] * u[1] * (1 - cost) - u[2] * sint;
    //m.m[2][0] = u[2] * u[0] * (1 - cost) + u[1] * sint;
    //m.m[0][1] = u[0] * u[1] * (1 - cost) + u[2] * sint;
    //m.m[1][1] = u[1] * u[1] + cost * (1 - u[1] * u[1]);
    //m.m[2][1] = u[1] * u[2] * (1 - cost) - u[0] * sint;
    //m.m[0][2] = u[2] * u[0] * (1 - cost) - u[1] * sint;
    //m.m[1][2] = u[1] * u[2] * (1 - cost) + u[0] * sint;
    //m.m[2][2] = u[2] * u[2] + cost * (1 - u[2] * u[2]);
    m.m[0][0] = c+x*x*t;
    m.m[1][0] = y*x*t+z*s;
    m.m[2][0] = z*x*t-y*s;
    m.m[0][1] = x*y*t-z*s;
    m.m[1][1] = c+y*y*t;
    m.m[2][1] = z*y*t+x*s;
    m.m[0][2] = x*z*t+y*s;
    m.m[1][2] = y*z*t-x*s;
    m.m[2][2] = z*z*t+c;

    //gl_M4_Transpose(&m, &m);
    if (verbose) {
        M4_print(m);
    }
    gl_M4_MulLeft(&model_matrix, &m);
    //gl_M4_Transpose(&model_matrix, &model_matrix);
}

