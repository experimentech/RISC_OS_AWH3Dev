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

/* limits.h: ISO 'C' (9899:1999) library header, section 5.2.4.2.1 */
/* Copyright (C) Codemist Ltd., 1988 */
/* Copyright (C) Acorn Computers Ltd. 1991, 1992 */
/* version 3.01 */

#ifndef __limits_h
#define __limits_h

#define CHAR_BIT 8
    /* max number of bits for smallest object that is not a bit-field (byte) */
#define SCHAR_MIN (-0x80)
    /* mimimum value for an object of type signed char */
#define SCHAR_MAX 0x7F
    /* maximum value for an object of type signed char */
#define UCHAR_MAX 0xFF
    /* maximum value for an object of type unsigned char */
#define CHAR_MIN 0
    /* minimum value for an object of type char */
#define CHAR_MAX 0xFF
    /* maximum value for an object of type char */
#define MB_LEN_MAX 1
    /* maximum number of bytes in a multibyte character, */
    /* for any supported locale */

#define SHRT_MIN  (-0x8000)
    /* minimum value for an object of type short int */
#define SHRT_MAX  0x7FFF
    /* maximum value for an object of type short int */
#define USHRT_MAX 0xFFFF
    /* maximum value for an object of type unsigned short int */
#define INT_MIN   (~0x7FFFFFFF)
    /* minimum value for an object of type int */
#define INT_MAX   0x7FFFFFFF
    /* maximum value for an object of type int */
#define UINT_MAX  0xFFFFFFFF
    /* maximum value for an object of type unsigned int */
#define LONG_MIN  (~0x7FFFFFFFL)
    /* minimum value for an object of type long int */
#define LONG_MAX  0x7FFFFFFFL
    /* maximum value for an object of type long int */
#define ULONG_MAX 0xFFFFFFFFL
    /* maximum value for an object of type unsigned long int */
#if __STDC_VERSION__ >= 199901
#define LLONG_MIN (~0x7FFFFFFFFFFFFFFF)
    /* minimum value for an object of type long long int */
#define LLONG_MAX 0x7FFFFFFFFFFFFFFF
    /* maximum value for an object of type long long int */
#define ULLONG_MAX 0xFFFFFFFFFFFFFFFF
    /* maximum value for an object of type unsigned long long int */
#endif

#endif

/* end of limits.h */
