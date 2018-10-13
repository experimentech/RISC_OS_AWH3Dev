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
#pragma force_top_level
#pragma include_only_once

/* tgmath.h: ISO 'C' (9899:1999) library header, sections 7.22 and G.7 */
/* Copyright (C) Acorn Computers Ltd. 2003 */
/* version 1.02 */

/*
 * tgmath.h includes the headers <math.h> and <complex.h> and defines several
 * type-generic macros.
 *
 * Of the <math.h> and <complex.h> functions without an f or l suffix, several
 * have one or more parameters whose corresponding real type is double. For each
 * such function, except modf, there is a corresponding type-generic macro. The
 * parameters whose corresponding real type is double in the function synopsis
 * are generic parameters. Use of the macro invokes a function whose
 * corresponding real type and domain are determined by the arguments for the
 * generic parameters.
 *
 * Use of the macro invokes a function whose generic parameters have the
 * corresponding real type as follows:
 *
 *   - First, if any argument for generic parameters has type long double,
 *     the type determined is long double.
 *   - Otherwise, if any argument for generic parameters has type double or
 *     is of integer type, the type determined is double.
 *   - Otherwise, the type determined is float.
 */
#ifndef __tgmath_h
#define __tgmath_h

#include <math.h>
#include <complex.h>

/* Internal macros to simplify public macros */
#define _TG(o, ...)      (___select(0, o##f, o, o##l, __VA_ARGS__))(__VA_ARGS__)
#define _TG1(o, x,...)   (___select(0, o##f, o, o##l, x))(x,__VA_ARGS__)
#define _TG2(o, x,y,...) (___select(0, o##f, o, o##l, x,y))(x,y,__VA_ARGS__)

#define _TGx(f,d,l, ...) (___select(0, f, d, l, __VA_ARGS__))(__VA_ARGS__)

#define _TGZ(r,i,c, ...) (___select(1, r##f, r, r##l, \
                                       i##f, i, i##l, \
                                       c##f, c, c##l, __VA_ARGS__))(__VA_ARGS__)

#define _TGC(o, ...)     _TGZ(o,   c##o, c##o, __VA_ARGS__)
#define _TGI(o, ...)     _TGZ(o, __i##o, c##o, __VA_ARGS__)


/* Private inline functions to provide the special imaginary forms as
 * per G.7. This could be done using an expression inside ___select,
 * but that leads to explosive macro expansion with nested macros.
 * Inlining will occur for these as per <math.h>.
 */
#define _DEF_IFN1(fn, val, t, im) \
  static inline __caller_narrow t im __i##fn(t imaginary z) { return val(z/I); }

#define _DEF_IFN(im, fn, val) \
    _DEF_IFN1(fn,    val,    double, im) \
    _DEF_IFN1(fn##f, val##f, float, im) \
    _DEF_IFN1(fn##l, val##l, long double, im)

_DEF_IFN(imaginary, asin,  I*asinh)
_DEF_IFN(imaginary, atan,  I*atanh)
_DEF_IFN(imaginary, asinh, I*asin)
_DEF_IFN(imaginary, atanh, I*atan)
_DEF_IFN(         , cos,   cosh)
_DEF_IFN(imaginary, sin,   I*sinh)
_DEF_IFN(imaginary, tan,   I*tanh)
_DEF_IFN(         , cosh,  cos)
_DEF_IFN(imaginary, sinh,  I*sin)
_DEF_IFN(imaginary, tanh,  I*tan)
_DEF_IFN(         , abs,   fabs)

#undef _DEF_IFN
#undef _DEF_IFN1

/*
 * For each unsuffixed function in <math.h> for which there is a function in
 * <complex.h> with the same name except for a c prefix, the corresponding
 * type-generic macro (for both functions) has the same name as the function in
 * <math.h>. The corresponding type-generic macro for fabs and cabs is fabs.
 *
 * If at least one argument for a generic parameter is complex, then use of
 * the macro invokes a complex function; otherwise, if an argument is imaginary,
 * the macro expands to an expression whose type is real, imaginary or complex,
 * as appropriate for the particular function; otherwise, use of the macro
 * invokes a real function.
 */
#undef acos
#undef asin
#undef atan
#undef acosh
#undef asinh
#undef atanh
#undef cos
#undef sin
#undef tan
#undef cosh
#undef sinh
#undef tanh
#undef exp
#undef log
#undef pow
#undef sqrt
#undef fabs

#define acos(z)  _TGC(acos, z)
#define asin(z)  _TGI(asin, z)
#define atan(z)  _TGI(atan, z)
#define acosh(z) _TGC(acosh, z)
#define asinh(z) _TGI(asinh, z)
#define atanh(z) _TGI(atanh, z)
#define cos(z)   _TGI(cos, z)
#define sin(z)   _TGI(sin, z)
#define tan(z)   _TGI(tan, z)
#define cosh(z)  _TGI(cosh, z)
#define sinh(z)  _TGI(sinh, z)
#define tanh(z)  _TGI(tanh, z)
#define exp(z)   _TGC(exp, z)
#define log(z)   _TGC(log, z)
#define pow(x,y) _TGC(pow, x,y)
#define sqrt(z)  _TGC(sqrt, z)
#define fabs(z)  _TGZ(fabs,__iabs,cabs, z)

/*
 * For each unsuffixed function in <math.h> without a c-prefixed counterpart in
 * <complex.h>, the corresponding type-generic macro has the same name as the
 * function.
 *
 * If all arguments for generic parameters are real, then use of the macro
 * invokes a real function; otherwise, use of the macro results in undefined
 * behaviour.
 */
#undef atan2
#undef cbrt
#undef ceil
#undef copysign
#undef erf
#undef erfc
#undef expm1
#undef fdim
#undef floor
#undef fma
#undef fmax
#undef fmin
#undef fmod
#undef frexp
#undef hypot
#undef ilogb
#undef ldexp
#undef lgamma
#undef llrint
#undef llround
#undef log10
#undef log1p
#undef log2
#undef logb
#undef lrint
#undef lround
#undef nearbyint
#undef nextafter
#undef nexttoward
#undef remainder
#undef remquo
#undef rint
#undef round
#undef scalbn
#undef scalbln
#undef tgamma
#undef trunc

#define atan2(y,x)      _TG(atan2, y,x)
#define cbrt(x)         _TG(cbrt, x)
#define ceil(x)         _TG(ceil, x)
#define copysign(x,y)   _TG(copysign, x,y)
#define erf(x)          _TG(erf, x)
#define erfc(x)         _TG(erfc, x)
#define expm1(x)        _TG(expm1, x)
#define fdim(x,y)       _TG(fdim, x,y)
#define floor(x)        _TG(floor, x)
#define fma(x,y,z)      _TG(fma, x,y,z)
#define fmax(x,y)       _TG(fmax, x,y)
#define fmin(x,y)       _TG(fmin, x,y)
#define fmod(x,y)       _TG(fmod, x,y)
#define frexp(v,e)      _TG1(frexp, v,e)
#define hypot(x,y)      _TG(hypot, x,y)
#define ilogb(x)        _TG(ilogb, x)
#define ldexp(x,e)      _TG1(ldexp, x,e)
#define lgamma(x)       _TG(lgamma, x)
#define llrint(x)       _TG(llrint, x)
#define llround(x)      _TG(llround, x)
#define log10(x)        _TG(log10, x)
#define log1p(x)        _TG(log1p, x)
#define log2(x)         _TG(log2, x)
#define logb(x)         _TG(logb, x)
#define lrint(x)        _TG(lrint, x)
#define lround(x)       _TG(lround, x)
#define nearbyint(x)    _TG(nearbyint, x)
#define nextafter(x,y)  _TG(nextafter, x,y)
#define nexttoward(x,y) _TG1(nexttoward, x,y)
#define remainder(x,y)  _TG(remainder, x,y)
#define remquo(x,y,q)   _TG2(remquo, x,y,q)
#define rint(x)         _TG(rint, x)
#define round(x)        _TG(round, x)
#define scalbn(x,n)     _TG1(scalbn, x,n)
#define scalbln(x,n)    _TG1(scalbln, x,n)
#define tgamma(x)       _TG(tgamma, x)
#define trunc(x)        _TG(trunc, x)

/*
 * For each unsuffixed function in <complex.h> that is not a c-prefixed
 * counterpart to a function in <math.h>, the corresponding type-generic macro
 * has the same name as the function.
 *
 * Use of the macro with any real, imaginary or complex argument invokes a
 * complex function.
 */
#undef carg
#undef cimag
#undef conj
#undef cproj
#undef creal

#define carg(z)         _TG(carg, z)
#define cimag(z)        _TG(cimag, z)
#define conj(z)         _TG(conj, z)
#define cproj(z)        _TG(cproj, z)
#define creal(z)        _TG(creal, z)

/* Ensure inlining still happens, unless requested otherwise */
#ifndef __TGMATH_NO_INLINING
#undef atan
#undef fabs
#undef floor
#undef ceil
#undef trunc
#undef rint
#undef lrint
#undef remainder
#undef cimag
#undef conj
#undef creal
#define atan(z)  (___select(1, __r_atan, __d_atan, atanl, \
                               __iatanf, __iatan, __iatanl,\
                               catanf, catan, catanl, z))(z)
#define fabs(z)  (___select(1, __r_abs, __d_abs, fabsl, \
                               __iabsf, __iabs, __iabsl,\
                               cabsf, cabs, cabsl, z))(z)
#define floor(x) _TGx(__r_floor, __d_floor, floorl, x)
#define ceil(x)  _TGx(__r_ceil, __d_ceil, ceill, x)
#define trunc(x) _TGx(__r_trunc, __d_trunc, truncl, x)
#define rint(x)  _TGx(__r_rint, __d_rint, rintl, x)
#define lrint(x) _TGx(__r_lrint, __d_lrint, lrintl, x)
#define remainder(x,y) _TGx(__r_rem, __d_rem, remainderl, x,y)
#define cimag(z) ___select(0, (float _Imaginary)(z)/_Imaginary_I, \
                              (double _Imaginary)(z)/_Imaginary_I, \
                              (long double _Imaginary)(z)/_Imaginary_I, z)
#define conj(z)  ___select(0, __conj (float _Complex) (z), \
                              __conj (double _Complex) (z), \
                              __conj (long double _Complex) (z), z)
#define creal(z) ___select(0, (float)(z), \
                              (double)(z), \
                              (long double)(z), z)
#ifdef __MATH_FORCE_INLINING
#undef acos
#undef asin
#undef cos
#undef sin
#undef tan
#undef sqrt
#undef log
#undef exp
#undef log10
#define acos(z)  (___select(1, __r_acos, __d_acos, acosl, \
                               __iacosf, __iacos, __iacosl,\
                               cacosf, cacos, cacosl, z))(z)
#define asin(z)  (___select(1, __r_asin, __d_asin, asinl, \
                               __iasinf, __iasin, __iasinl,\
                               casinf, casin, casinl, z))(z)
#define cos(z)   (___select(1, __r_cos, __d_cos, cosl, \
                               __icosf, __icos, __icosl,\
                               ccosf, ccos, ccosl, z))(z)
#define sin(z)   (___select(1, __r_sin, __d_sin, sinl, \
                               __isinf, __isin, __isinl,\
                               csinf, csin, csinl, z))(z)
#define tan(z)   (___select(1, __r_tan, __d_tan, tanl, \
                               __itanf, __itan, __itanl,\
                               ctanf, ctan, ctanl, z))(z)
#define sqrt(z)  (___select(1, __r_sqrt, __d_sqrt, sqrtl, \
                               csqrtf, csqrt, csqrtl,\
                               csqrtf, csqrt, csqrtl, z))(z)
#define log(z)   (___select(1, __r_log, __d_log, logl, \
                                clogf, clog, clogl,\
                                clogf, clog, clogl, z))(z)
#define exp(z)   (___select(1, __r_exp, __d_exp, expl, \
                                cexpf, cexp, cexpl,\
                                cexpf, cexp, cexpl, z))(z)
#define log10(z)  _TGx(__r_lg10, __d_lg10, log10l, x)
#endif
#define cimag(z) ___select(0, (float _Imaginary)(z)/_Imaginary_I, \
                              (double _Imaginary)(z)/_Imaginary_I, \
                              (long double _Imaginary)(z)/_Imaginary_I, z)
#define conj(z)  ___select(0, __conj (float _Complex) (z), \
                              __conj (double _Complex) (z), \
                              __conj (long double _Complex) (z), z)
#define creal(z) ___select(0, (float)(z), \
                              (double)(z), \
                              (long double)(z), z)
#endif

#endif

/* end of tgmath.h */
