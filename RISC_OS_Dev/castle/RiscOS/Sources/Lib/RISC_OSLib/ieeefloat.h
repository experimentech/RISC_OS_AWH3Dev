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

/* float.h: ANSI draft (X3J11 Oct 86) library header, section 2.2.4.2 */
/* Copyright (C) A.C. Norman and A. Mycroft */
/* version 0.01 */

#ifndef __float_h
#define __float_h

/* IEEE version: the following values are taken from the above ANSI draft.  */
/* The ACORN FPE (v17) is known not to precisely implement IEEE arithmetic. */

#define FLT_RADIX     2
#define FLT_ROUNDS    1

#define FLT_MANT_DIG        24
#define DBL_MANT_DIG        53
#define LDBL_MANT_DIG       53

/* The values that follow are not achieved under Acorn's FPE version 17  */
/* but they should be correct in due course!                             */

#define FLT_EPSILON         1.19209290e-7F
#define DBL_EPSILON         2.2204460492503131e-16
#define LDBL_EPSILON        2.2204460492503131e-16L

#define FLT_DIG      6
#define DBL_DIG      15
#define LDBL_DIG     15

#define FLT_MIN_EXP  (-125)
#define DBL_MIN_EXP  (-1021)
#define LDBL_MIN_EXP (-1021)

#define FLT_MIN  1.17549435e-38F
#define DBL_MIN  2.22507385850720138e-308
#define LDBL_MIN 2.22507385850720138e-308L

#define FLT_MIN_10_EXP  (-37)
#define DBL_MIN_10_EXP  (-307)
#define LDBL_MIN_10_EXP (-307)

#define FLT_MAX_EXP  128
#define DBL_MAX_EXP  1024
#define LDBL_MAX_EXP 1024

#define FLT_MAX  3.40282347e+38F
#define DBL_MAX  1.79769313486231571e+308
#define LDBL_MAX 1.79769313486231571e+308L

#define FLT_MAX_10_EXP  38
#define DBL_MAX_10_EXP  308
#define LDBL_MAX_10_EXP 308

#endif

/* end of float.h */
