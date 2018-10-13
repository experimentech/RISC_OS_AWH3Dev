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

/* stdint.h: ISO 'C' (9899:1999) library header, section 7.18 */
/* Copyright (C) Acorn Computers Ltd. 2002 */
/* version 1.04 */

#ifndef __stdint_h
#define __stdint_h

#if __STDC_VERSION__ >= 199901
#  define __stdint_ll
#endif

/* Types with exactly the specified width */
typedef signed   char      int8_t;
typedef unsigned char      uint8_t;
typedef signed   short     int16_t;
typedef unsigned short     uint16_t;
typedef signed   int       int32_t;
typedef unsigned int       uint32_t;

/* The smallest types with at least the specified width */
typedef signed   char      int_least8_t;
typedef unsigned char      uint_least8_t;
typedef signed   short     int_least16_t;
typedef unsigned short     uint_least16_t;
typedef signed   int       int_least32_t;
typedef unsigned int       uint_least32_t;

/* The "fastest" types with at least the specified width */
typedef signed   int       int_fast8_t;
typedef unsigned int       uint_fast8_t;
typedef signed   int       int_fast16_t;
typedef unsigned int       uint_fast16_t;
typedef signed   int       int_fast32_t;
typedef unsigned int       uint_fast32_t;

/* Integer types capable of holding a "void *" pointer */
typedef signed   int       intptr_t;
typedef unsigned int       uintptr_t;

#ifdef __stdint_ll
typedef signed   long long int64_t;
typedef unsigned long long uint64_t;
typedef signed   long long int_least64_t;
typedef unsigned long long uint_least64_t;
typedef signed   long long int_fast64_t;
typedef unsigned long long uint_fast64_t;

/* Integer types that can hold any value of any type */
typedef signed   long long intmax_t;
typedef unsigned long long uintmax_t;
#endif

#if !defined(__cplusplus) || defined(__STDC_LIMIT_MACROS)

#define INT8_MIN         (-0x80)
#define INT8_MAX         0x7F
#define UINT8_MAX        0xFF
#define INT16_MIN        (-0x8000)
#define INT16_MAX        0x7FFF
#define UINT16_MAX       0xFFFF
#define INT32_MIN        (~0x7FFFFFFF)
#define INT32_MAX        0x7FFFFFFF
#define UINT32_MAX       0xFFFFFFFF

#define INT_LEAST8_MIN   (-0x80)
#define INT_LEAST8_MAX   0x7F
#define UINT_LEAST8_MAX  0xFF
#define INT_LEAST16_MIN  (-0x8000)
#define INT_LEAST16_MAX  0x7FFF
#define UINT_LEAST16_MAX 0xFFFF
#define INT_LEAST32_MIN  (~0x7FFFFFFF)
#define INT_LEAST32_MAX  0x7FFFFFFF
#define UINT_LEAST32_MAX 0xFFFFFFFF

#define INT_FAST8_MIN    (~0x7FFFFFFF)
#define INT_FAST8_MAX    0x7FFFFFFF
#define UINT_FAST8_MAX   0xFFFFFFFF
#define INT_FAST16_MIN   (~0x7FFFFFFF)
#define INT_FAST16_MAX   0x7FFFFFFF
#define UINT_FAST16_MAX  0xFFFFFFFF
#define INT_FAST32_MIN   (~0x7FFFFFFF)
#define INT_FAST32_MAX   0x7FFFFFFF
#define UINT_FAST32_MAX  0xFFFFFFFF

#define INTPTR_MIN       (~0x7FFFFFFF)
#define INTPTR_MAX       0x7FFFFFFF
#define UINTPTR_MAX      0xFFFFFFFF

#ifdef __stdint_ll
#define INT64_MIN        (~0x7FFFFFFFFFFFFFFF)
#define INT64_MAX        0x7FFFFFFFFFFFFFFF
#define UINT64_MAX       0xFFFFFFFFFFFFFFFF
#define INT_LEAST64_MIN  (~0x7FFFFFFFFFFFFFFF)
#define INT_LEAST64_MAX  0x7FFFFFFFFFFFFFFF
#define UINT_LEAST64_MAX 0xFFFFFFFFFFFFFFFF
#define INT_FAST64_MIN   (~0x7FFFFFFFFFFFFFFF)
#define INT_FAST64_MAX   0x7FFFFFFFFFFFFFFF
#define UINT_FAST64_MAX  0xFFFFFFFFFFFFFFFF

#define INTMAX_MIN       (~0x7FFFFFFFFFFFFFFF)
#define INTMAX_MAX       0x7FFFFFFFFFFFFFFF
#define UINTMAX_MAX      0xFFFFFFFFFFFFFFFF
#endif

#define PTRDIFF_MIN      (~0x7FFFFFFF)
#define PTRDIFF_MAX      0x7FFFFFFF

#define SIG_ATOMIC_MIN   (~0x7FFFFFFF)
#define SIG_ATOMIC_MAX   0x7FFFFFFF

#define SIZE_MAX         0xFFFFFFFF

#define WCHAR_MIN        (~0x7FFFFFFF)
#define WCHAR_MAX        0x7FFFFFFF

#endif

#if !defined(__cplusplus) || defined(__STDC_CONSTANT_MACROS)

#define INT8_C(n)    n
#define UINT8_C(n)   n##u
#define INT16_C(n)   n
#define UINT16_C(n)  n##u
#define INT32_C(n)   n
#define UINT32_C(n)  n##u
#ifdef __stdint_ll
#define INT64_C(n)   n##ll
#define UINT64_C(n)  n##ull

#define INTMAX_C(n)  n##ll
#define UINTMAX_C(n) n##ull
#endif

#endif

#endif

/* end of stdint.h */
