; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
; 
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
; 
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
; 
;-*- Mode: Assembler -*-
;
; Copyright (C) Acorn Computers Ltd., 1989.
;
; Add new entries ONLY AT THE END of the list
;

        Entry   __fpclassifyf, , , unveneered, , , [FPREGARGS]
        Entry   __fpclassifyd, , , unveneered, , , [FPREGARGS]
        Entry   __signbitf, , , unveneered, , , [FPREGARGS]
        Entry   __signbitd, , , unveneered, , , [FPREGARGS]
        Entry   __copysignd, , , unveneered, , , [FPREGARGS]
        Entry   __copysignf, , , unveneered, , , [FPREGARGS]
        Entry   nan, imported, , unveneered
        Entry   nanf, imported, , unveneered
        Entry   nextafter, , , unveneered
        Entry   nextafterf, , , unveneered
        Entry   fdim, imported, , unveneered
        Entry   fdimf, imported, , unveneered
        Entry   fmax, , , unveneered
        Entry   fmaxf, , , unveneered
        Entry   fmin, , , unveneered
        Entry   fminf, , , unveneered
        Entry   fabsf, imported, , unveneered
        Entry   hypot, , , unveneered
        Entry   hypotf, , , unveneered

        Entry   feclearexcept, imported, , unveneered
        Entry   fegetexceptflag, imported, , unveneered
        Entry   feraiseexcept, imported, , unveneered
        Entry   fesetexceptflag, imported, , unveneered
        Entry   fetestexcept, imported, , unveneered
        Entry   fegetround, imported, , unveneered
        Entry   fesetround, imported, , unveneered
        Entry   fegetenv, imported, , unveneered
        Entry   feholdexcept, imported, , unveneered
        Entry   fesetenv, imported, , unveneered
        Entry   feupdateenv, imported, , unveneered

        Entry   _snprintf, imported, , unveneered
        Entry   snprintf, imported, , unveneered
        Entry   vsnprintf, imported, , unveneered
        Entry   vfscanf, imported, , unveneered
        Entry   vscanf, imported, , unveneered
        Entry   vsscanf, imported, , unveneered

        Entry   ceilf, imported, , unveneered
        Entry   floorf, imported, , unveneered
        Entry   nearbyint, , , unveneered
        Entry   nearbyintf, , , unveneered
        Entry   rint, imported, , unveneered
        Entry   rintf, imported, , unveneered
        Entry   lrint, imported, , unveneered
        Entry   lrintf, imported, , unveneered
        Entry   round, , , unveneered
        Entry   roundf, , , unveneered
        Entry   lround, , , unveneered
        Entry   lroundf, , , unveneered
        Entry   trunc, imported, , unveneered
        Entry   truncf, imported, , unveneered
        Entry   remainder, , , unveneered
        Entry   remainderf, , , unveneered

        Entry   llabs, , , unveneered
        Entry   lldiv, , , unveneered
        Entry   atoll, imported, , unveneered
        Entry   strtoll, imported, , unveneered
        Entry   strtoull, imported, , unveneered
        Entry   imaxabs, , , unveneered
        Entry   imaxdiv, , , unveneered
        Entry   strtoimax, imported, , unveneered
        Entry   strtoumax, imported, , unveneered

        Entry   __assert2, imported, , unveneered
        Entry   _Exit, imported, , unveneered

        Entry   acosf, imported, , unveneered
        Entry   asinf, imported, , unveneered
        Entry   atanf, imported, , unveneered
        Entry   atan2f, imported, , unveneered
        Entry   cosf, imported, , unveneered
        Entry   sinf, imported, , unveneered
        Entry   tanf, imported, , unveneered
        Entry   acosh, imported, , unveneered
        Entry   acoshf, imported, , unveneered
        Entry   asinh, imported, , unveneered
        Entry   asinhf, imported, , unveneered
        Entry   atanh, imported, , unveneered
        Entry   atanhf, imported, , unveneered
        Entry   expf, imported, , unveneered
        Entry   exp2, , , unveneered
        Entry   exp2f, , , unveneered
        Entry   expm1, imported, , unveneered
        Entry   expm1f, imported, , unveneered
        Entry   frexpf, imported, , unveneered
        Entry   ilogb, imported, , unveneered
        Entry   ilogbf, imported, , unveneered
        Entry   ldexpf, imported, , unveneered
        Entry   logf, imported, , unveneered
        Entry   log10f, imported, , unveneered
        Entry   log1p, imported, , unveneered
        Entry   log1pf, imported, , unveneered
        Entry   log2, , , unveneered
        Entry   log2f, , , unveneered
        Entry   logb, imported, , unveneered
        Entry   logbf, imported, , unveneered
        Entry   modff, imported, , unveneered
        Entry   fmodf, imported, , unveneered
        Entry   scalbn, imported, , unveneered
        Entry   scalbnf, imported, , unveneered
        Entry   scalbln, imported, , unveneered
        Entry   scalblnf, imported, , unveneered
        Entry   cbrt, , , unveneered
        Entry   cbrtf, , , unveneered
        Entry   powf, , , unveneered
        Entry   sqrtf, imported, , unveneered
        Entry   erf, imported, , unveneered
        Entry   erff, imported, , unveneered
        Entry   erfc, imported, , unveneered
        Entry   erfcf, imported, , unveneered
        Entry   lgamma, imported, , unveneered
        Entry   lgammaf, imported, , unveneered
        Entry   tgamma, imported, , unveneered
        Entry   tgammaf, imported, , unveneered
        Entry   nexttoward, , , unveneered
        Entry   nexttowardf, , , unveneered
        Entry   fmaf, imported, , unveneered

        Entry   isblank, imported, , unveneered
        Entry   strtof, imported, , unveneered

        Entry   copysign, , , unveneered
        Entry   copysignf, , , unveneered
        Entry   fma, imported, , unveneered
        Entry   remquo, imported, , unveneered
        Entry   remquof, imported, , unveneered
        Entry   llrint, imported, , unveneered
        Entry   llrintf, imported, , unveneered
        Entry   llround, imported, , unveneered
        Entry   llroundf, imported, , unveneered

        Entry   _cxd_mul, imported, , unveneered, , , [FPREGARGS]
        Entry   _cxf_mul, imported, , unveneered, , , [FPREGARGS]
        Entry   _cxd_div, imported, , unveneered, , , [FPREGARGS]
        Entry   _cxf_div, imported, , unveneered, , , [FPREGARGS]
        Entry   _cxd_rdv, imported, , unveneered, , , [FPREGARGS]
        Entry   _cxf_rdv, imported, , unveneered, , , [FPREGARGS]

        Entry   cacos, imported, , unveneered
        Entry   cacosf, imported, , unveneered
        Entry   casin, imported, , unveneered
        Entry   casinf, imported, , unveneered
        Entry   catan, imported, , unveneered
        Entry   catanf, imported, , unveneered
        Entry   ccos, imported, , unveneered
        Entry   ccosf, imported, , unveneered
        Entry   csin, imported, , unveneered
        Entry   csinf, imported, , unveneered
        Entry   ctan, imported, , unveneered
        Entry   ctanf, imported, , unveneered
        Entry   cacosh, imported, , unveneered
        Entry   cacoshf, imported, , unveneered
        Entry   casinh, imported, , unveneered
        Entry   casinhf, imported, , unveneered
        Entry   catanh, imported, , unveneered
        Entry   catanhf, imported, , unveneered
        Entry   ccosh, imported, , unveneered
        Entry   ccoshf, imported, , unveneered
        Entry   csinh, imported, , unveneered
        Entry   csinhf, imported, , unveneered
        Entry   ctanh, imported, , unveneered
        Entry   ctanhf, imported, , unveneered
        Entry   cexp, imported, , unveneered
        Entry   cexpf, imported, , unveneered
        Entry   clog, imported, , unveneered
        Entry   clogf, imported, , unveneered
        Entry   cabs, imported, , unveneered
        Entry   cabsf, imported, , unveneered
        Entry   cpow, imported, , unveneered
        Entry   cpowf, imported, , unveneered
        Entry   csqrt, imported, , unveneered
        Entry   csqrtf, imported, , unveneered
        Entry   carg, imported, , unveneered
        Entry   cargf, imported, , unveneered
        Entry   cimag, imported, , unveneered
        Entry   cimagf, imported, , unveneered
        Entry   conj, imported, , unveneered
        Entry   conjf, imported, , unveneered
        Entry   cproj, imported, , unveneered
        Entry   cprojf, imported, , unveneered
        Entry   creal, imported, , unveneered
        Entry   crealf, imported, , unveneered

        Entry   _fgetpos64, imported, , unveneered
        Entry   _fopen64, imported, , unveneered
        Entry   _freopen64, imported, , unveneered
        Entry   _fseeko64, imported, , unveneered
        Entry   _fsetpos64, imported, , unveneered
        Entry   _ftello64, imported, , unveneered
        Entry   _tmpfile64, imported, , unveneered

        END
