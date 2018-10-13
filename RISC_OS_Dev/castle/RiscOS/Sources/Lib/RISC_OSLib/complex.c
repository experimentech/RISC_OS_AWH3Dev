/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */

/* complex.c: ISO 'C' (9899:1999) library code, sections 7.3 and G.6 */
/* Copyright (C) Acorn Computers Ltd. 2005 */

/* version 1.00 */

#include <float.h>
#include <fenv.h>
#include <math.h>
#include <complex.h>

/* All this code uses Annex F/G-style infinity/nan/exception handling. */
/* To achieve this we use the built-in (ie FPA) versions of sin/cos etc, */
/* because the <math.h> ones still do the old HUGE_VAL/errno nonsense. */
/* When this is changed, we'll tidy this up. */

#pragma STDC FENV_ACCESS ON

#define _pi_    0x1.921FB54442D18p+1      // ..4698998C
#define _pi_2   0x1.921FB54442D18p0
#define _pi_4   0x1.921FB54442D18p-1
#define _3pi_4  0x1.2D97C7F3321D2p+1

extern double __log_cabs(double complex);
extern double _new_cosh(double x);
extern double _new_sinh(double x);
extern double _new_tanh(double x);

static complex double cfetidyexcept(const fenv_t *envp, complex double x)
{
    int exc = fetestexcept(FE_ALL_EXCEPT);
    if (exc & (FE_DIVBYZERO|FE_INVALID))
    {   if (exc & (FE_UNDERFLOW|FE_OVERFLOW|FE_INEXACT))
            feclearexcept(FE_UNDERFLOW|FE_OVERFLOW|FE_INEXACT);
    }
    else if (exc & FE_UNDERFLOW)
    {   if (!(isless(fabs(creal(x)), DBL_MIN) ||
              isless(fabs(cimag(x)), DBL_MIN)))
            feclearexcept(FE_UNDERFLOW);
    }
    feupdateenv(envp);
    return x;
}

static complex float cfetidyexceptf(const fenv_t *envp, complex float x)
{
    int exc = fetestexcept(FE_ALL_EXCEPT);
    if (exc & (FE_DIVBYZERO|FE_INVALID))
    {   if (exc & (FE_UNDERFLOW|FE_OVERFLOW|FE_INEXACT))
            feclearexcept(FE_UNDERFLOW|FE_OVERFLOW|FE_INEXACT);
    }
    else if (exc & FE_UNDERFLOW)
    {   if (!(isless(fabsf(crealf(x)), FLT_MIN) ||
              isless(fabsf(cimagf(x)), FLT_MIN)))
            feclearexcept(FE_UNDERFLOW);
    }
    feupdateenv(envp);
    return x;
}

double complex cacos(double complex z)
{
    double x = creal(z), y = cimag(z);
    int cx, cy;

    if (signbit(y)) return conj(cacos(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cx == FP_ZERO)
    {   if (cy == FP_ZERO) return _pi_2 - I*0;
        if (cy == FP_NAN) return _pi_2 - I*y;
    }
    else if (cx == FP_INFINITE)
    {   if (cy == FP_NAN) return y - I * INFINITY;
        if (cy == FP_INFINITE) return (x < 0 ? _3pi_4 : _pi_4) - I * INFINITY;
        return (x < 0 ? _pi_ : +0.0) - I * INFINITY;
    }
    else if (cy == FP_INFINITE)
    {   if (cx == FP_NAN) return x - I * INFINITY;
        return _pi_2 - I * INFINITY;
    }

    return (2/I)*clog(csqrt(0.5*(1+z))+I*csqrt(0.5*(1-z)));
}

static float complex narrow(double complex func(double complex), float complex z)
{
    fenv_t env;
    feholdexcept(&env);
    return cfetidyexceptf(&env, (float complex) func(z));
}

float complex cacosf(float complex z)
{
    return narrow(cacos, z);
}

double complex casin(double complex z)
{
    return -I*casinh(I*z);
}

float complex casinf(float complex z)
{
    return -I*casinhf(I*z);
}

double complex catan(double complex z)
{
    return -I*catanh(I*z);
}

float complex catanf(float complex z)
{
    return -I*catanhf(I*z);
}

double complex ccos(double complex z)
{
    return ccosh(I*z);
}

float complex ccosf(float complex z)
{
    return ccoshf(I*z);
}

double complex csin(double complex z)
{
    return -I*csinh(I*z);
}

float complex csinf(float complex z)
{
    return -I*csinhf(I*z);
}

double complex ctan(double complex z)
{
    return -I*ctanh(I*z);
}

float complex ctanf(float complex z)
{
    return -I*ctanhf(I*z);
}

double complex cacosh(double complex z)
{
    double x = creal(z), y = cimag(z);
    int cx, cy;

    if (signbit(y)) return conj(cacosh(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cy == FP_INFINITE)
    {
        if (cx == FP_INFINITE) return +INFINITY + (x > 0 ? I*_pi_4 : I*_3pi_4);
        if (cx == FP_NAN) return +INFINITY + I*y;
    }

    return 2*clog(csqrt(0.5*(z+1))+csqrt(0.5*(z-1)));
}

float complex cacoshf(float complex z)
{
    return narrow(cacosh, z);
}

double complex casinh(double complex z)
{
    double x = creal(z), y = cimag(z);
    int cx, cy;

    if (signbit(x)) return -casinh(-z);
    if (signbit(y)) return conj(casinh(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cy == FP_INFINITE)
    {   if (cx == FP_NAN) return y + I*x;
        if (cx == FP_INFINITE) return +INFINITY + I*_pi_4;
        return +INFINITY + I*_pi_2;
    }
    else if (cy == FP_NAN)
    {   if (cx == FP_NAN || cx == FP_INFINITE) return z;
        return y + I*y;
    }
    else if (cx == FP_INFINITE)
    {   return x;
    }
    else if (cx == FP_NAN)
    {   if (cy == FP_ZERO) return z;
        return x + I*x;
    }

    return clog(z+csqrt(1+z*z));
}

float complex casinhf(float complex z)
{
    return narrow(casinh, z);
}

double complex catanh(double complex z)
{
    double x = creal(z), y = cimag(z);
    int cx, cy;

    if (signbit(x)) return -casinh(-z);
    if (signbit(y)) return conj(catanh(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cy == FP_NAN)
    {   if (cx == FP_ZERO || cx == FP_INFINITE) return 0 + I*y;
        if (cx == FP_NAN) return z;
        return y + I*y;
    }
    else if (cx == FP_INFINITE || cy == FP_INFINITE)
    {   return 0 + I*_pi_2;
    }
    else if (cx == FP_NAN)
    {   return x + I*x;
    }
    else if (cy == FP_ZERO)
    {   if (x == 1) return x / y; /* +INFINITY; DIVBYZERO */
    }

    return 0.5*(clog(1+z)-clog(1-z));
}

float complex catanhf(float complex z)
{
    return narrow(catanh, z);
}

double complex ccosh(double complex z)
{
    double x = creal(z), y = cimag(z);
    double rx, ry;
    int cx, cy;
    fenv_t fe;

    if (signbit(x) != signbit(y)) return conj(ccosh(conj(z)));

    x = fabs(x); y = fabs(y);
    cx = fpclassify(x), cy = fpclassify(y);

    if (cx == FP_NAN)
    {   if (cy == FP_ZERO || cy == FP_NAN) return x + I*y;
        return x + I*x;
    }
    else if (cy == FP_NAN)
    {   if (cx == FP_ZERO) return y + I*0;
        if (cx == FP_INFINITE) return x + I*y;
        return y + I*y;
    }
    else if (cx == FP_INFINITE)
    {   if (cy == FP_ZERO) return x + I*y;
        if (cy == FP_INFINITE) return x + I*__d_sin(y);
    }
    else if (cy == FP_INFINITE)
    {   if (cx == FP_ZERO) return __d_cos(y) + I*0;
    }

    /* Remaining cases:                                                      */
    /* finite          + I*finite            just need to check for overflow */
    /* finite non-zero + I*infinity          will generate NaN+i*NaN +IVO    */
    /* infinity        + I*finite non-zero   inf*cis(y), clear INX after     */

    feholdexcept(&fe);

    rx = _new_cosh(x) * __d_cos(y);
    ry = _new_sinh(x) * __d_sin(y);

    if (isnan(ry) && y == 0)
    {   ry = 0;
        feclearexcept(FE_INVALID);
    }
    if (cx == FP_INFINITE)
        feclearexcept(FE_INEXACT);

    return cfetidyexcept(&fe, rx + I * ry);
}

float complex ccoshf(float complex z)
{
    return narrow(ccosh, z);
}

double complex csinh(double complex z)
{
    double x = creal(z), y = cimag(z);
    double rx, ry;
    int cx, cy;
    fenv_t fe;

    if (signbit(x)) return -csinh(-z);
    if (signbit(y)) return conj(csinh(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cx == FP_NAN)
    {   if (cy == FP_ZERO || cy == FP_NAN) return x + I*y;
        return x + I*x;
    }
    else if (cy == FP_NAN)
    {   if (cx == FP_ZERO || cx == FP_INFINITE) return x + I*y;
        return y + I*y;
    }
    else if (cy == FP_INFINITE)
    {   if (cx == FP_ZERO || cx == FP_INFINITE) return x + I*__d_sin(y);
    }
    else if (cx == FP_INFINITE)
    {   if (cy == FP_ZERO) return x + I*y;
    }

    /* Remaining cases:                                                      */
    /* finite          + I*finite            just need to check for overflow */
    /* finite non-zero + I*infinity          will generate NaN+i*NaN +IVO    */
    /* infinity        + I*finite non-zero   inf*cis(y), clear INX after     */

    feholdexcept(&fe);

    rx = _new_sinh(x) * __d_cos(y);
    ry = _new_cosh(x) * __d_sin(y);

    if (isnan(ry) && y == 0)
    {   ry = 0;
        feclearexcept(FE_INVALID);
    }
    if (cx == FP_INFINITE)
        feclearexcept(FE_INEXACT);

    return cfetidyexcept(&fe, rx + I * ry);
}

float complex csinhf(float complex z)
{
    return narrow(csinh, z);
}

double complex ctanh(double complex z)
{
    double x = creal(z), y = cimag(z);
    double complex r;
    int cx, cy;
    fenv_t fe;

    if (signbit(x)) return -ctanh(-z);
    if (signbit(y)) return conj(ctanh(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);
    if (cx == FP_NAN)
    {   if (cy == FP_ZERO || cy == FP_NAN) return x + I*y;
        return x + I*x;
    }
    else if (cy == FP_NAN)
    {   if (cx == FP_INFINITE) return 1 + I*0;
        return y + I*y;
    }
    else if (cy == FP_INFINITE)
    {   if (cx == FP_INFINITE) return 1 + I*0;
        return __d_tan(y) * (1+I);
    }

    /* Remaining cases:                                                      */
    /* finite          + I*finite            just need to check for overflow */
    /* infinity        + I*finite            1 + i0 sin(2y), clear INX after */

    feholdexcept(&fe);

    #define _asinh_DBL_MAX__4 0x1.633CE8FB9F87Ep+7 /* asinh(DBL_MAX)/4 */
    if (x > _asinh_DBL_MAX__4)
    {   r = I*0*__d_sin(2*y);
        feclearexcept(FE_INEXACT);
        if (fetestexcept(FE_OVERFLOW|FE_INVALID))
        {   /* Don't really want to return a NAN for large y - act as for */
            /* infinite y */
            feclearexcept(FE_ALL_EXCEPT);
            r = I*0;
        }
        r += _new_tanh(x);
    }
    else
    {   double t = __d_tan(y);
        /* Note that t will be finite if in range - overflow is impossible. */
        /* A range error leading to a NaN is possible, of course. */
        double beta = 1 + t*t;
        double s = _new_sinh(x);
        double c = __d_sqrt(1 + s*s);
        r = (beta*c*s + I*t) / (1 + beta*s*s);
    }

    return cfetidyexcept(&fe, r);
}

float complex ctanhf(float complex z)
{
    return narrow(ctanh, z);
}

double complex cexp(double complex z)
{
    double x = creal(z), y = cimag(z);
    double ex, rx, ry;
    int cx, cy;
    fenv_t fe;
    if (signbit(y)) return conj(cexp(conj(z)));

    cx = fpclassify(x), cy = fpclassify(y);

    if (cx == FP_NAN)
    {   if (cy == FP_ZERO || cy == FP_NAN) return z;
        return x + I*x;
    }
    else if (cy == FP_NAN)
    {   if (cx == FP_INFINITE) return signbit(x) ? 0 : z;
        return y + I*y;
    }
    else if (cy == FP_INFINITE)
    {   if (cx == FP_INFINITE) return signbit(x) ? 0 : INFINITY + I*__d_sin(y);
        return __d_cos(y) + I*__d_sin(y); /* Just to get right sort of NaN */
    }

    feholdexcept(&fe);

    ex = __d_exp(x);
    if (isinf(ex) && y == 0) /* Either infinite x, or overflow */
    {   rx = ex;
        ry = 0;
    }
    else
    {   rx = ex * __d_cos(y);
        ry = ex * __d_sin(y);
        /* If x was infinite, result is exact - clear inexact from cos/sin */
        if (isinf(x)) feclearexcept(FE_INEXACT);
    }
    feupdateenv(&fe);
    return rx + I*ry;
}

float complex cexpf(float complex z)
{
    return narrow(cexp, z);
}

double complex clog(double complex z)
{
    /* For once, the standard formula gets all exceptional cases right */
    /* We use a special log_cabs function to avoid overflow though */
    return __log_cabs(z) + I*carg(z);
}

float complex clogf(float complex z)
{
    return narrow(clog, z);
}

double complex cpow(double complex x, double complex y)
{
    /* Simplistic implementation - the standard does allow it */
    return cexp(y * clog(x));
}

float complex cpowf(float complex x, float complex y)
{
    fenv_t env;
    feholdexcept(&env);
    return cfetidyexceptf(&env, (float complex) cpow(x,y));
}

/* end of complex.c */
