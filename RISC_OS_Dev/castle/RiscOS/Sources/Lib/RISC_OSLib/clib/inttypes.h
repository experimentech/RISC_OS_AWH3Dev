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

/* inttypes.h: ISO 'C' (9899:1999) library header, section 7.8 */
/* Copyright (C) Acorn Computers Ltd. 2002 */
/* version 1.03 */

#ifndef __inttypes_h
#define __inttypes_h

#include <stdint.h>

#if !defined(__cplusplus) || defined(__STDC_FORMAT_MACROS)

#define PRId8       "d"
#define PRId16      "d"
#define PRId32      "d"
#define PRIdLEAST8  "d"
#define PRIdLEAST16 "d"
#define PRIdLEAST32 "d"
#define PRIdFAST8   "d"
#define PRIdFAST16  "d"
#define PRIdFAST32  "d"
#define PRIdPTR     "d"

#define PRIi8       "i"
#define PRIi16      "i"
#define PRIi32      "i"
#define PRIiLEAST8  "i"
#define PRIiLEAST16 "i"
#define PRIiLEAST32 "i"
#define PRIiFAST8   "i"
#define PRIiFAST16  "i"
#define PRIiFAST32  "i"
#define PRIiPTR     "i"

#define PRIo8       "o"
#define PRIo16      "o"
#define PRIo32      "o"
#define PRIoLEAST8  "o"
#define PRIoLEAST16 "o"
#define PRIoLEAST32 "o"
#define PRIoFAST8   "o"
#define PRIoFAST16  "o"
#define PRIoFAST32  "o"
#define PRIoPTR     "o"

#define PRIu8       "u"
#define PRIu16      "u"
#define PRIu32      "u"
#define PRIuLEAST8  "u"
#define PRIuLEAST16 "u"
#define PRIuLEAST32 "u"
#define PRIuFAST8   "u"
#define PRIuFAST16  "u"
#define PRIuFAST32  "u"
#define PRIuPTR     "u"

#define PRIx8       "x"
#define PRIx16      "x"
#define PRIx32      "x"
#define PRIxLEAST8  "x"
#define PRIxLEAST16 "x"
#define PRIxLEAST32 "x"
#define PRIxFAST8   "x"
#define PRIxFAST16  "x"
#define PRIxFAST32  "x"
#define PRIxPTR     "x"

#define PRIX8       "X"
#define PRIX16      "X"
#define PRIX32      "X"
#define PRIXLEAST8  "X"
#define PRIXLEAST16 "X"
#define PRIXLEAST32 "X"
#define PRIXFAST8   "X"
#define PRIXFAST16  "X"
#define PRIXFAST32  "X"
#define PRIXPTR     "X"

#define SCNd8       "hhd"
#define SCNd16      "hd"
#define SCNd32      "d"
#define SCNdLEAST8  "hhd"
#define SCNdLEAST16 "hd"
#define SCNdLEAST32 "d"
#define SCNdFAST8   "d"
#define SCNdFAST16  "d"
#define SCNdFAST32  "d"
#define SCNdPTR     "d"

#define SCNi8       "hhi"
#define SCNi16      "hi"
#define SCNi32      "i"
#define SCNiLEAST8  "hhi"
#define SCNiLEAST16 "hi"
#define SCNiLEAST32 "i"
#define SCNiFAST8   "i"
#define SCNiFAST16  "i"
#define SCNiFAST32  "i"
#define SCNiPTR     "i"

#define SCNo8       "hho"
#define SCNo16      "ho"
#define SCNo32      "o"
#define SCNoLEAST8  "hho"
#define SCNoLEAST16 "ho"
#define SCNoLEAST32 "o"
#define SCNoFAST8   "o"
#define SCNoFAST16  "o"
#define SCNoFAST32  "o"
#define SCNoPTR     "o"

#define SCNu8       "hhu"
#define SCNu16      "hu"
#define SCNu32      "u"
#define SCNuLEAST8  "hhu"
#define SCNuLEAST16 "hu"
#define SCNuLEAST32 "u"
#define SCNuFAST8   "u"
#define SCNuFAST16  "u"
#define SCNuFAST32  "u"
#define SCNuPTR     "u"

#define SCNx8       "hhx"
#define SCNx16      "hx"
#define SCNx32      "x"
#define SCNxLEAST8  "hhx"
#define SCNxLEAST16 "hx"
#define SCNxLEAST32 "x"
#define SCNxFAST8   "x"
#define SCNxFAST16  "x"
#define SCNxFAST32  "x"
#define SCNxPTR     "x"

#ifdef __stdint_ll
#define PRId64      "lld"
#define PRIdLEAST64 "lld"
#define PRIdFAST64  "lld"
#define PRIdMAX     "jd"
#define PRIi64      "lli"
#define PRIiLEAST64 "lli"
#define PRIiFAST64  "lli"
#define PRIiMAX     "ji"
#define PRIo64      "llo"
#define PRIoLEAST64 "llo"
#define PRIoFAST64  "llo"
#define PRIoMAX     "jo"
#define PRIu64      "llu"
#define PRIuLEAST64 "llu"
#define PRIuFAST64  "llu"
#define PRIuMAX     "ju"
#define PRIx64      "llx"
#define PRIxLEAST64 "llx"
#define PRIxFAST64  "llx"
#define PRIxMAX     "jx"
#define PRIX64      "llX"
#define PRIXLEAST64 "llX"
#define PRIXFAST64  "llX"
#define PRIXMAX     "jX"
#define SCNd64      "lld"
#define SCNdLEAST64 "lld"
#define SCNdFAST64  "lld"
#define SCNdMAX     "jd"
#define SCNi64      "lli"
#define SCNiLEAST64 "lli"
#define SCNiFAST64  "lli"
#define SCNiMAX     "ji"
#define SCNo64      "llo"
#define SCNoLEAST64 "llo"
#define SCNoFAST64  "llo"
#define SCNoMAX     "jo"
#define SCNu64      "llu"
#define SCNuLEAST64 "llu"
#define SCNuFAST64  "llu"
#define SCNuMAX     "ju"
#define SCNx64      "llx"
#define SCNxLEAST64 "llx"
#define SCNxFAST64  "llx"
#define SCNxMAX     "jx"
#endif

#endif

#ifdef __stdint_ll
typedef struct imaxdiv_t { intmax_t quot, rem; } imaxdiv_t;
   /* type of the value returned by the imaxdiv function. */

intmax_t imaxabs(intmax_t /*j*/);
   /*
    * computes the absolute value of an integer j. If the result cannot be
    * represented, the behaviour is undefined.
    * Returns: the absolute value.
    */
imaxdiv_t imaxdiv(intmax_t /*numer*/, intmax_t /*denom*/);
   /*
    * computes numer / denom and numer % denom in a single operation.
    * Returns: a structure of type imaxdiv_t, comprising both the quotient and
    *          the remainder.
    */

intmax_t strtoimax(const char * restrict /*nptr*/,
                         char ** restrict /*endptr*/, int /*base*/);
   /*
    * equivalent to the strtoll function, except that the initial portion of the
    * string is converted to intmax_t representation.
    * Returns: the converted value if any. If no conversion could be performed,
    *          zero is returned. If the correct value is outside the range of
    *          representable values, INTMAX_MAX or INTMAX_MIN is returned
    *          (according to the sign of the value), and the value of the
    *          macro ERANGE is stored in errno.
    */
uintmax_t strtoumax(const char * restrict /*nptr*/,
                          char ** restrict /*endptr*/, int /*base*/);
   /*
    * equivalent to the strtoull function, except that the initial portion of
    * the string is converted to uintmax_t representation.
    * Returns: the converted value if any. If no conversion could be performed,
    *          zero is returned. If the correct value is outside the range of
    *          representable values, UINTMAX_MAX is returned, and the value of
    *          the macro ERANGE is stored in errno.
    */
#endif

#endif

/* end of inttypes.h */
