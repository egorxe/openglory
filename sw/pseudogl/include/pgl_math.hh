#ifndef _PGL_MATH_HH
#define _PGL_MATH_HH

#include <cstdio>
#include <cstring>
#include <cmath>
#include <array>

// Matrix class
struct M4 
{
    float m[4][4];
};

class PglMatrix : public M4
{
    public:
    // construct identity matrix by daffault
    PglMatrix() :
        M4({{
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1},
        }}),
        dirty(true)
    {
    }

    PglMatrix(M4 _m) :
        dirty(true)
    {
        Set(_m);
    }

    void Set(M4 _m)
    {
        std::memcpy(&m, &_m.m, sizeof(m));
        dirty = true;
    }

    void MulLeft(const M4& b) 
    {
        int i, j, k;
        float s;
        M4 a = *this;

        for (i = 0; i < 4; i++)
        {
            for (j = 0; j < 4; j++) 
            {
                s = 0.0;
                for (k = 0; k < 4; k++)
                    s += a.m[i][k] * b.m[k][j];
                this->m[i][j] = s;
            }
        }

        dirty = true;
    }

    void Invert()
    {
        M4 tmp;
        double determinant = 0;
        int i = 0;
        for (int j = 0; j < 4; j++) 
        {
            int k = (i + j) % 2 ? -1 : 1;
            double complement = CalcComplement(i, j);
            determinant += k * m[i][j] * complement;
            tmp.m[j][i] = k * complement;
        }
        for (int j = 0; j < 4; j++)
            tmp.m[j][i] /= determinant;
        for (i = 1; i < 4; i++) 
        {
            for (int j = 0; j < 4; j++) 
            {
                int k = (i + j) % 2 ? -1 : 1;
                tmp.m[j][i] = (k * CalcComplement(i, j));
                tmp.m[j][i] /= determinant;
            }
        }
        Set(tmp);
    }

    void Transpose()
    {
        M4 tmp;
        for (int i = 0; i < 4; i++)
            for (int j = 0; j < 4; j++)
                tmp.m[i][j] = m[j][i];
        Set(tmp);
    }

    void PrintMatrix()
    {
        puts("");
        for (int i = 0; i < 4; i++)
        {
            for (int j = 0; j < 4; j++)
                printf("%0.4f ", m[i][j]);
            puts("");
        }
        puts("");
    }

    void SetDirty(bool d = true) {dirty = d;}

    bool CheckDirty()
    {
        bool d = dirty;
        dirty = false;
        return d;
    }

    private:

    static float Determinant(const float m3[3][3]) 
    {
        return m3[0][0] * m3[1][1] * m3[2][2]
            + m3[0][1] * m3[1][2] * m3[2][0]
            + m3[0][2] * m3[1][0] * m3[2][1]
            - m3[0][2] * m3[1][1] * m3[2][0]
            - m3[0][1] * m3[1][0] * m3[2][2]
            - m3[0][0] * m3[1][2] * m3[2][1];
    }

    float CalcComplement(int row, int col) const
    {
        float minor[3][3];
        int minorRow = 0, minorCol = 0;
        for (int i = 0; i < 4; i++) 
        {
            if (i == row)
                continue;
            minorCol = 0;
            for (int j = 0; j < 4; j++) 
            {
                if (j == col)
                    continue;
                minor[minorRow][minorCol] = m[i][j];
                // assert(minorRow < 3 && minorCol < 3);
                minorCol += 1;
            }
            minorRow += 1;
        }
        return Determinant(minor);
    }

    bool dirty;
};

const PglMatrix IDENTITY;

// Vector class
class PglVec4 : public std::array<float, 4>
{
    public:
    void MulM4(M4 &mx) 
    {
        PglVec4 tmp;
        tmp[0] = mx.m[0][0] * (*this)[0] + mx.m[0][1] * (*this)[1] + mx.m[0][2] * (*this)[2] + mx.m[0][3] * (*this)[3];
        tmp[1] = mx.m[1][0] * (*this)[0] + mx.m[1][1] * (*this)[1] + mx.m[1][2] * (*this)[2] + mx.m[1][3] * (*this)[3];
        tmp[2] = mx.m[2][0] * (*this)[0] + mx.m[2][1] * (*this)[1] + mx.m[2][2] * (*this)[2] + mx.m[2][3] * (*this)[3];
        tmp[3] = mx.m[3][0] * (*this)[0] + mx.m[3][1] * (*this)[1] + mx.m[3][2] * (*this)[2] + mx.m[3][3] * (*this)[3];
        *this = tmp;
    }

    void Set(const float f[4])
    {
        std::copy(f, f + 4, this->begin());
    }

    void Normalize()
    {
        float len = 0;
        for (int i = 0; i < 4; i++)
            len += (*this)[i] * (*this)[i];
        len = std::sqrt(len);
        for (int i = 0; i < 4; i++)
            (*this)[i] /= len;
    }
};

#endif    /* _PGL_MATH_HH */
