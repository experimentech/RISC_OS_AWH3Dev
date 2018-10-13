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

/* wchar.h: ISO 'C' (9899:1999) library header, section 7.24 */
/* Copyright (C) Acorn Computers Ltd. 2004 */
/* version 1.00 */

/*
 * wchar.h declares four types, one tag, four macros, and many functions.
 */

#ifndef __wchar_h
#define __wchar_h

#ifndef __wchar_t
#  define __wchar_t 1
   typedef int wchar_t;            /* from <stdlib.h> */
#endif

#ifndef __size_t
#  define __size_t 1
   typedef unsigned int size_t;    /* from <stddef.h> */
#endif

typedef struct __mbstate_t_struct
{
    wchar_t __c; // current character?
    int __n; // pending bytes?
    wchar_t __min;
} mbstate_t;
   /*
    * an object type other than an array type that can hold the conversion
    * state information necessary to convert between sequences of multibyte
    * characters and wide characters
    */

typedef int wint_t;
   /*
    * an integer type unchanged by default argument promotions that can hold
    * any value corresponding to members of the extended character set, as
    * well as at least one value that does not correspond to any member of
    * the extended character set (see WEOF below)
    */

struct tm;                      /* see <time.h> */
struct __FILE_struct;           /* see <stdio.h> */

#ifndef NULL
#  define NULL 0                /* see <stddef.h> */
#endif

#ifndef WCHAR_MIN
#  define WCHAR_MIN      (~0x7FFFFFFF)    /* see <stdint.h> */
#  define WCHAR_MAX      0x7FFFFFFF
#endif

#define WEOF (-1)
   /*
    * constant expression of type wint_t whose value does not correspond
    * to any member of the extended character set. It is accepted (and
    * returned) by several functions in this header to indicate end-of-file,
    * that is, no more input from a stream. It is also used as a wide
    * character value that does not correspond to any member of the extended
    * character set.
    */

#ifdef __cplusplus
#define restrict
extern "C" {
#endif

#pragma -v1   /* hint to the compiler to check f/s/wprintf format */
int fwprintf(struct __FILE_struct * restrict /*stream*/,
             const wchar_t * restrict /*format*/, ...);
   /*
    * writes output to the stream pointed to by stream, under control of the
    * wide string pointed to by format that specifies how subsequent arguments
    * are converted for output. If there are insufficient arguments for the
    * format, the behaviour is undefined. If the format is exhausted while
    * arguments remain, the excess arguments are evaluated but otherwise
    * ignored. The fwprintf function returns when the end of the format string
    * is encountered. The format is composed of zero or more directives:
    * ordinary wide characters (not %), which are copied unchanged to the
    * output stream; and conversion specifications, each of which results in
    * fetching zero or more subsequent arguments, converting them, if
    * applicable, according to the corresponding conversion specifier, and then
    * writing the result to the output stream. Each conversion specification is
    * introduced by the wide character %. For a description of the available
    * conversion specifiers refer to section 7.24.2.1 in the ISO standard
    * mentioned at the start of this file or to any modern textbook on C.
    * The minimum value for the maximum number of wide characters producable by
    * any single conversion is at least 4095.
    * Returns: the number of wide characters transmitted, or a negative value
    *          if an output or encoding error occurred.
    */
int wprintf(const wchar_t * restrict /*format*/, ...);
   /*
    * is equivalent to fwprintf with the argument stdout interposed before the
    * arguments to wprintf.
    * Returns: the number of wide characters transmitted, or a negative value
    *          if an output or encoding error occurred.
    */
int swprintf(wchar_t * restrict /*s*/, size_t n,
             const wchar_t * restrict /*format*/, ...);
   /*
    * is equivalent to fwprintf, except that the argument s specifies an array
    * of wide characters into which the generated output is to be written,
    * rather than written to a stream. No more than n wide characters are
    * written, including a terminating null wide character, which is always
    * added (unless n is zero).
    * Returns: the number of wide characters written in the array, not counting
    *          the terminating null wide character, or a negative value if an
    *          encoding error occurred or if n or more wide characters were
    *          requested to be written.
    */
#pragma -v2   /* hint to the compiler to check f/s/wscanf format */
int fwscanf(struct __FILE_struct * restrict /*stream*/,
            const wchar_t * restrict /*format*/, ...);
   /*
    * reads input from the stream pointed to by stream, under control of the
    * wide string pointed to by format that specifies the admissible input
    * sequences and how they are to be converted for assignment, using
    * subsequent arguments as pointers to the objects to receive the converted
    * input. If there are insufficient arguments for the format, the behaviour
    * is undefined. If the format is exhausted while arguments remain, the
    * excess arguments are evaluated (as always) but are otherwise ignored.
    * The format is composed of zero or more directives: one or more
    * white-space wide characters; an ordinary wide character (neither % nor
    * a white-space wide character); or a conversion specification. Each
    * conversion specification is introduced by the wide character %. For a
    * description of the available conversion specifiers refer to section
    * 7.24.2.2 in the ISO standard mentioned at the start of this file, or to
    * any modern textbook on C.
    * If end-of-file is encountered during input, conversion is terminated. If
    * end-of-file occurs before any characters matching the current directive
    * have been read (other than leading white space, where permitted),
    * execution of the current directive terminates with an input failure;
    * otherwise, unless execution of the current directive is terminated with a
    * matching failure, execution of the following directive (if any) is
    * terminated with an input failure.
    * If conversions terminates on a conflicting input character, the offending
    * input character is left unread in the input strem. Trailing white space
    * (including new-line wide characters) is left unread unless matched by a
    * directive. The success of literal matches and suppressed asignments is
    * not directly determinable other than via the %n directive.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the fwscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
int wscanf(const wchar_t * restrict /*format*/, ...);
   /*
    * is equivalent to fwscanf with the argument stdin interposed before the
    * arguments to wscanf.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the scanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
int swscanf(const wchar_t * restrict /*s*/,
            const wchar_t * restrict /*format*/, ...);
   /*
    * is equivalent to fwscanf except that the argument s specifies a wide
    * string from which the input is to be obtained, rather than from a stream.
    * Reaching the end of the wide string is equivalent to encountering
    * end-of-file for the fwscanf function.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the swscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
#pragma -v0   /* back to default */
int vfwprintf(struct __FILE_struct * restrict /*stream*/,
              const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to fwprintf, with the variable argument list replaced by
    * arg, which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vfwprintf function does not invoke the
    * va_end macro.
    * Returns: the number of wide characters transmitted, or a negative value if
    *          an output or encoding error occurred.
    */
int vfwscanf(struct __FILE_struct * restrict /*stream*/,
             const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to fwscanf, with the variable argument list replaced by
    * arg, which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vfwscanf function does not invoke the
    * va_end macro.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vfwscanf function returns the number
    *          of input items assigned, which can be fewer than provided for,
    *          or even zero, in the event of an early matching failure.
    */
int vwprintf(const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to wprintf, with the variable argument list replaced by arg,
    * which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vwprintf function does not invoke the
    * va_end macro.
    * Returns: the number of wide characters transmitted, or a negative value if
    *          an output or encoding error occurred.
    */
int vwscanf(const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to wscanf, with the variable argument list replaced by arg,
    * which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vwscanf function does not invoke the va_end
    * macro.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vwscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
int vswprintf(wchar_t * restrict /*s*/, size_t n,
              const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to swprintf, with the variable argument list replaced by
    * arg, which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vswprintf function does not invoke the
    * va_end macro.
    * Returns: the number of wide characters written in the array, not counting
    *          the terminating null wide character, or a negative value if an
    *          encoding error occurred or if n or more wide characters were
    *          requested to be generated.
    */
int vswscanf(const wchar_t * restrict /*s*/,
             const wchar_t * restrict /*format*/, __valist /*arg*/);
   /*
    * is equivalent to swscanf, with the variable argument list replaced by arg,
    * which shall have been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vswscanf function does not invoke the
    * va_end macro.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vswscanf function returns the number
    *          of input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */

wint_t fgetwc(struct __FILE_struct */*stream*/);
   /*
    * obtains the next wide character (if present) as a wchar_t converted to
    * a wint_t, from the input stream pointed to by stream, and advances the
    * associated file position indicator (if defined).
    * Returns: the next wide character from the input stream pointed to by
    *          stream.
    *          If the stream is at end-of-file, the end-of-file indicator is
    *          set and fgetwc returns WEOF. If a read error occurs, the error
    *          indicator is set and fgetwc returns WEOF. If an encoding error
    *          occurs (including too few bytes), the value of the macro EILSEQ
    *          is stored in errno and fgetwc returns WEOF.
    */
wchar_t *fgetws(wchar_t * restrict /*s*/, int n,
                struct __FILE_struct * restrict /*stream*/);
   /*
    * reads at most one less than the number of wide characters specified by n
    * from the stream pointed to by stream into the array pointed to by s. No
    * additional wide characters are read after a new-line wide character (which
    * is retained) or after end-of-file. A null wide character is written
    * immediately after the last wide character read into the array.
    * Returns: s if successful. If end-of-file is encountered and no characters
    *          have been read into the array, the contents of the array remain
    *          unchanged and a null pointer is returned. If a read or encoding
    *          error occurs during the operation, the array contents are
    *          indeterminate and a null pointer is returned.
    */
wint_t fputwc(wchar_t c, struct __FILE_struct */*stream*/);
   /*
    * writes the wide character specified by c to the output stream pointed to
    * by stream, at the position indicated by the associated file position
    * indicator (if defined), and advances the indicator appropriately. If the
    * file position indicator is not defined, the character is appended to the
    * output stream.
    * Returns: the wide character written. If a write error occurs, the error
    *          indicator is set and fputwc returns WEOF. If an encoding error
    *          occurs, the value of the macro EILSEQ is stored in errno and
    *          fputwc returns WEOF.
    */
int fputws(const wchar_t * restrict /*s*/,
           struct __FILE_struct * restrict /*stream*/);
   /*
    * writes the wide string pointed to by s to the stream pointed to by stream.
    * The terminating null wide character is not written.
    * Returns: EOF if a write or encoding error occurs; otherwise it returns a
    *          nonnegative value.
    */
wint_t getwc(struct __FILE_struct */*stream*/);
   /*
    * is equivalent to fgetwc except that if it is implemented as a macro,
    * it may evaluate stream more than once, so the argument should never be an
    * expression with side effects.
    * Returns: the next wide character from the input stream pointed to by
    *          stream, or WEOF.
    */
wint_t getwchar(void);
   /*
    * is equivalent to getwc with the argument stdin.
    * Returns: the next wide character from the input stream pointed to by
    *          stdin, or WEOF.
    */
wint_t putwc(wchar_t /*c*/, struct __FILE_struct */*stream*/);
   /*
    * is equivalent to fputwc except that if it is implemented as a macro,
    * it may evaluate stream more than once, so that argument should never be an
    * expression with side effects.
    * Returns: the wide character written, or WEOF.
    */
wint_t putwchar(wchar_t /*c*/);
   /*
    * is equivalent to putwc with the second argument stdout.
    * Returns: the wide character written, or WEOF.
    */
wint_t ungetwc(wint_t /*c*/, struct __FILE_struct */*stream*/);
   /*
    * pushes the wide character specified by c back onto the input stream
    * pointed to by stream. Pushed-back wide characters will be returned by
    * subsequent reads on that stream in the reverse order of their pushing.
    * A successful intervening call (with the stream pointed to by stream) to
    * a file positioning function (fseek, fsetpos, or rewind) discards any
    * pushed-back wide characters. The external storage corresponding to the
    * stream is unchanged.
    * One wide character of pushback is guaranteed. If the ungetwc function is
    * called too many times on the same stream without an intervening read or
    * file positioning operation on that stream, the operation may fail.
    * If the value of c equals that of the macro WEOF, the operation fails and
    * the input stream is unchanged.
    * A successful call to the ungetwc function clears the end-of-file
    * indicator for the stream. The value of the file position indicator for
    * the stream after reading or discarding all pushed-back wide characters
    * is the same as it was before the wide characters were pushed back. For a
    * text or binary stream, the value of the file position indicator after a
    * successful call to the ungetwc function is unspecified until all
    * pushed-back wide characters are read or discarded.
    * Returns: the wide character pushed back, or WEOF if the operation fails.
    */
int fwide(struct __FILE_struct */*stream*/, int /*mode*/);
   /*
    * determines the orientation of the stream pointed to by stream. If mode is
    * greater than zero, the function first attempts to make the stream wide
    * oriented. If mode is less than zero, the function first attempts to make
    * the strpeam byte oriented. Otherwise, mode is zero and the function does
    * not alter the orientation of the stream.
    * Returns: a value greater than zero if, after the call, the stream has wide
    *          orientation, a value less than zero if the stream has byte
    *          orientation, or zero if the stream has no orientation.
    */

double wcstod(const wchar_t * restrict /*nptr*/,
              wchar_t ** restrict /*endptr*/);
float wcstof(const wchar_t * restrict /*nptr*/,
             wchar_t ** restrict /*endptr*/);
long double wcstold(const wchar_t * restrict /*nptr*/,
                    wchar_t ** restrict /*endptr*/);
   /*
    * convert the initial portion of the wide string pointed to by nptr to
    * double, float and long double representation, respectively. First, they
    * decompose the input string into three parts: an initial, possibly empty,
    * sequence of white-space characters (as specified by the iswspace
    * function), a subject sequence resembling a floating point constant or
    * representing an infinity or NaN; and a final wide string of one or more
    * unrecognised wide characters, including the terminating null wide
    * character of the input wide string. Then, they attempt to convert the
    * subject sequence to a floating point number, and return the result.
    * A pointer to the final wide string is stored in the object pointed to by
    * endptr, provided that endptr is not a null pointer.
    * Returns: the converted value, if any. If no conversion could be performed,
    *          zero is returned. If the correct value is outside the range of
    *          representable values, plus or minus HUGE_VAL, HUGE_VALF, or
    *          HUGE_VALL is returned (according to the return type and sign of
    *          the value), and the value of the macro ERANGE is stored in errno.
    *          If the result underflows (ISO Standard, section 7.12.1), the
    *          functions return a value whose magnitude is no greater than the
    *          smallest normalised positive number in the return type, and the
    *          value of the macro ERANGE is stored in errno.
    */
long int wcstol(const wchar_t * restrict /*nptr*/,
                wchar_t ** restrict /*endptr*/, int /*base*/);
long long int wcstoll(const wchar_t * restrict /*nptr*/,
                      wchar_t ** restrict /*endptr*/, int /*base*/);
unsigned long int wcstoul(const wchar_t * restrict /*nptr*/,
                          wchar_t ** restrict /*endptr*/, int /*base*/);
unsigned long long int wcstoull(const wchar_t * restrict /*nptr*/,
                                wchar_t ** restrict /*endptr*/, int /*base*/);
   /*
    * convert the initial portion of the wide string pointed to by nptr to
    * long int, long long int, unsigned long int and unsigned long long int
    * representation, respectively. First, they decompose the input string into
    * three parts: an initial, possibly empty, sequence of white-space wide
    * characters (as determined by the iswspace function), a subject sequence
    * resembling an integer represented in some radix determined by the value of
    * base, and a final wide string of one or more unrecognised wide characters,
    * including the terminating null wide character of the input wide string.
    * Then, they attempt to convert the subject sequence to an integer, and
    * return the result. If the value of base is zero, the expected form of
    * the subject sequence is that of an integer constant as described for the
    * corresponding single-byte characters in ISO Standard section 6.4.4.1,
    * optionally preceeded by a plus or minus sign, but not including an integer
    * suffix. If the value of base is between 2 and 36 (inclusive), the expected
    * form of the subject sequence is a sequence of letters and digits
    * representing an integer with the radix specified by base, optionally
    * preceeded by a plus or minus sign, but not including an integer suffix.
    * The letters from a (or A) through z (or Z) are ascribed the values
    * 10 through 35; only letters whose ascribed values are less than that of
    * base are permitted. If the value of base is 16, the wide characters 0x or
    * 0X may optionally precede the sequence of letters and digits, following
    * the sign if present. A pointer to the final wide string is stored in the
    * object pointed to by endptr, provided that endptr is not a null pointer.
    * Returns: the converted value if any. If no conversion could be performed,
    *          zero is returned. If the correct value is outside the range of
    *          representable values, LONG_MIN, LONG_MAX, LLONG_MIN, LLONG_MAX,
    *          ULONG_MAX, or ULLONG_MAX is returned (according to the return
    *          type and sign of the value, if any), and the value of the macro
    *          ERANGE is stored in errno.
    */

wchar_t *wcscpy(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/);
   /*
    * copies the wide string pointed to by s2 (including the terminating null
    * wide character) into the array pointed to by s1.
    * Returns: the value of s1.
    */
wchar_t *wcsncpy(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/,
                 size_t /*n*/);
   /*
    * copies not more than n wide characters (characters that follow a null
    * wide character are not copied) from the array pointed to by s2 into the
    * array pointed to by s1. If the array pointed to by s2 is a wide string
    * that is shorter than n wide characters, null wide characters are
    * appended to the copy in the array pointed to by s1, until n wide
    * characters in all have been written.
    * Returns: the value of s1.
    */
wchar_t *wmemcpy(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/,
                 size_t /*n*/);
   /*
    * copies n wide characters from the object pointed to by s2 into the
    * object pointed to by s1.
    * Returns: the value of s1.
    */
wchar_t *wmemmove(wchar_t */*s1*/, const wchar_t */*s2*/, size_t /*n*/);
   /*
    * copies n wide characters from the object pointed to by s2 into the
    * object pointed to by s1. Copying takes place as if the n wide characters
    * from the object pointed to by s2 are first copied into a temporary array
    * of n wide characters that does not overlap the objects pointed to by s1
    * or s2, and then the n wide characters from the temporary array are
    * copied into the object pointed to by s1.
    * Returns: the value of s1.
    */

wchar_t *wcscat(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/);
   /*
    * appends a copy of the wide string pointed to by s2 (including the
    * terminating null wide character) to the end of the wide string pointed
    * to by s1. The initial wide character of s2 overwrites the null wide
    * character at the end of s1.
    * Returns: the value of s1.
    */
wchar_t *wcsncat(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/,
                 size_t /*n*/);
   /*
    * appends not more than n wide characters (a null wide character and
    * those that follow it are not appended) from the array pointed to by s2
    * to the end of the wide string pointed to by s1. The initial wide
    * character of s2 overwrites the null wide character at the end of s1. A
    * terminating null wide character is always appended to the result.
    * Returns: the value of s1.
    */

/*
 * Unless explictly stated otherwise, the comparison functions order two wide
 * characters the same way as two integers of the underlying integer type
 * designated by wchar_t.
 */

int wcscmp(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * compares the wide string pointed to by s1 to the wide string pointed to
    * by s2.
    * Returns: an integer greater than, equal to, or less than zero,
    *          accordingly as the wide string pointed to by s1 is greater
    *          than, equal to, or less than the wide string pointed to by s2.
    */
int wcsncmp(const wchar_t */*s1*/, const wchar_t */*s2*/, size_t /*n*/);
   /*
    * compares not more than n wide characters (those that follow a null wide
    * character are not compared) from the array pointed to by s1 to the array
    * pointed to by s2.
    * Returns: an integer greater than, equal to, or less than zero,
    *          accordingly as the wide string pointed to by s1 is greater
    *          than, equal to, or less than the wide string pointed to by s2.
    */
int wcscoll(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * compares the wide string pointed to by s1 to the wide string pointed to by
    * s2, both interpreted as appropriate to the LC_COLLATE category of the
    * current locale.
    * Returns: an integer greater than, equal to, or less than zero, accordingly
    *          as the wide string pointed to by s1 is greater than, equal to, or
    *          less than the wide string pointed to by s2 when both are
    *          interpreted as appropriate to the current locale.
    */
size_t wcsxfrm(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/,
               size_t /*n*/);
   /*
    * transforms the wide string pointed to by s2 and places the resulting wide
    * string into the array pointed to by s1. The transformation is such that
    * if the wcscmp function is applied to two transformed wide strings, it
    * returns a value greater than, equal to or less than zero, corresponding to
    * the result of the wcscoll function applied to the same two original
    * strings. No more than n wide characters are placed into the resulting
    * array pointed to by s1, including the terminating null wide character. If
    * n is zero, s1 is permitted to be a null pointer.
    * Returns: the length of the transformed wide string (not including the
    *          terminating null wide character). If the value returned is n or
    *          more, the contents of the array pointed to by s1 are
    *          indeterminate.
    */

int wmemcmp(const wchar_t */*s1*/, const wchar_t */*s2*/, size_t /*n*/);
   /*
    * compares the first n wide characters of the object pointed to by s1 to
    * the first n wide characters of the object pointed to by s2.
    * Returns: an integer greater than, equal to, or less than zero,
    *          accordingly as the object pointed to by s1 is greater than,
    *          equal to, or less than the object pointed to by s2.
    */

wchar_t *wcschr(const wchar_t */*s1*/, wchar_t /*c*/);
   /*
    * locates the first occurence of c in the wide string pointed to by s.
    * The terminating null wide character is considered to be part of the
    * wide string.
    * Returns: a pointer to the located wide character, or a null pointer if
    *          the wide character does not occur in the wide string.
    */
size_t wcscspn(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * computes the length of the maximum initial segment of the wide string
    * pointed to by s1 which consists entirely of wide characters not from the
    * wide string pointed to by s2.
    * Returns: the length of the segment.
    */
wchar_t *wcspbrk(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * locates the first occurence in the wide string pointed to by s1 of any
    * wide character from the wide string pointed to by s2.
    * Returns: returns a pointer to the wide character in s1, or a null
    *          pointer if no wide character from s2 occurs in s1.
    */
wchar_t *wcsrchr(const wchar_t */*s1*/, wchar_t /*c*/);
   /*
    * locates the last occurrence of c in the wide string pointed to by s. The
    * terminating null wide character is considered to be part of the wide
    * string.
    * Returns: returns a pointer to the wide character, or a null pointer if c
    *          does not occur in the wide string.
    */
size_t wcsspn(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * computes the length of the maximum initial segment of the wide string
    * pointed to by s1 which consists entirely of wide characters from the
    * wide string pointed to by s2.
    * Returns: the length of the segment.
    */
wchar_t *wcsstr(const wchar_t */*s1*/, const wchar_t */*s2*/);
   /*
    * locates the first occurrence in the wide string pointed to by s1 of the
    * sequence of wide characters (excluding the terminating null wide
    * character) in the wide string pointed to by s2.
    * Returns: a pointer to the located wide string, or a null pointer if the
    *          wide string is not found. If s2 points to a wide string with
    *          zero length, the function returns s1.
    */
wchar_t *wcstok(wchar_t * restrict /*s1*/, const wchar_t * restrict /*s2*/,
                wchar_t ** restrict /*ptr*/);
   /*
    * A sequence of calls to the wcstok function breaks the wide string
    * pointed to by s1 into a sequence of tokens, each of which is delimited
    * by a wide character from the wide string pointed to by s2. The third
    * argument points to a caller-provided wchar_t pointer into which the
    * wcstok function stores information necessary for it to continue scanning
    * the same wide string.
    * The first call in the sequence has a non-null first argument and stores
    * an initial value in the object pointed to by ptr. Subsequent calls in
    * the sequence have a null first argument and the object pointed to by ptr
    * is required to have the value stored by the previous call in the
    * sequence, which is then updated. The separator string pointed to by s2
    * may be different from call to call.
    * The first call in the sequence searches the wide string pointed to by
    * s1 for the first wide character that is not contained in the current
    * separator wide string s2. If no such wide character is found, then there
    * are no tokens in s1 and the wcstok function returns a null pointer. If
    * such a wide character is found, it is the start of the first token.
    * The wcstok function then searches from there for a wide character that
    * is contained in the current separator wide string. If no such wide
    * character is found, the current token extends to the end of the wide
    * string pointed to by s1, and subsequent searches in the same wide string
    * for a token return a null pointer. If such a wide character is found,
    * it is overwritten by a null wide character, which terminates the current
    * token.
    * In all cases, the wcstok function stores sufficient information in the
    * pointer pointed to by ptr so that subsequent calls, with a null pointer
    * for s1 and the unmodified pointer value for ptr, shall start searching
    * just past the element overwritten by a null wide character (if any).
    * Returns: a pointer to the first wide character of a token, or a null
    *          pointer if there is no token.
    */
wchar_t *wmemchr(const wchar_t */*s1*/, wchar_t /*c*/, size_t /*n*/);
   /*
    * locates the first occurrence of c in the initial n wide characters of
    * the object pointed to by s.
    * Returns: a pointer to the located wide character, or a null pointer if
    *          the wide character does not occur in the object.
    */

size_t wcslen(const wchar_t */*s*/);
   /*
    * computes the length of the wide string pointed to by s.
    * Returns: the number of wide characters that precede the terminating null
    *          wide character.
    */
wchar_t *wmemset(wchar_t */*s*/, wchar_t /*c*/, size_t /*n*/);
   /*
    * copies the value of c into each of the first n wide characters of the
    * object pointed to by s.
    * Returns: the value of s.
    */

size_t wcsftime(wchar_t * restrict /*s*/, size_t maxsize,
                const wchar_t * restrict /*format*/,
                const struct tm * restrict /*time*/);
   /*
    * equivalent to the strftime function, except that:
    *  - The argument s points to the initial element of an array of wide
    *    characters into which the generated output is to be placed.
    *  - The argument maxsize indicates the limiting number of wide characters.
    *  - The argument format is a wide string and the conversion specifiers are
    *    replaced by corresponding sequences of wide characters.
    *  - The return value indicates the number of wide characters.
    * Returns: If the total number of resulting wide characters including the
    *          terminating null wide character is not more than maxsize, the
    *          wcsftime function returns the number of wide characters placed
    *          into the array pointed to by s not including the terminating
    *          null wide character. Otherwise, zero is returned and the
    *          contents of the array are indeterminate.
    */

wint_t btowc(int /*c*/);
   /*
    * determines whether c constitutes a valid single-byte character in the
    * initial shift state.
    * Returns: WEOF if c has the value EOF or if (unsigned char)c does not
    *          constitute a valid single-byte character in the initial
    *          shift state. Otherwise, it returns the wide character
    *          representation of that character.
    */
int wctob(wint_t /*c*/);
   /*
    * determines whether c corresponds to a member of the extended character
    * set whose multibyte character representation is a single byte when in
    * the initial shift state.
    * Returns: EOF if c does not correspond to a multibyte character with
    *          length one in the initial shift state. Otherwise, it returns
    *          the single-byte representation of that character as an
    *          unsigned char converted to an int.
    */

int mbsinit(const mbstate_t */*ps*/);
   /*
    * If ps is not a null pointer, the mbsinit function determines whether the
    * pointed-to mbstate_t object describes an initial conversion state.
    * Returns: nonzero if ps is a null pointer or if the pointed-to object
    *          describes an initial conversion state; otherwise, it returns
    *          zero.
    */

/*
 * Restartable Multibyte/Wide Character Conversion Functions
 * These functions differ from the corresponding multibyte character functions
 * in <stdlib.h> (mblen, mbtowc and wctomb) in that they have an extra
 * parameter, ps, of type pointer to mbstate_t that points to an object that can
 * completely describe the current conversion state of the associated multibyte
 * character sequence. If ps is a null pointer, each function uses its own
 * internal mbstate_t object instead, which is initialised at program startup to
 * the initial conversion state. The implementation behaves as if no library
 * function calls these functions with a null pointer for ps.
 * Also unlike their corresponding functions, the return value does not
 * represent whether the encoding is state-dependent.
 */
size_t mbrlen(const char * restrict /*s*/, size_t /*n*/,
              mbstate_t * restrict /*ps*/);
   /*
    * is equivalent to the call:
    *     mbrtowc(NULL, s, n, ps != NULL ? ps : &internal)
    * where internal is the mbstate_t object for the mbrlen function, except
    * that the expression designated by ps is evaluated only once.
    * Returns: a value between zero and n inclusive, (size_t)(-2) or
    *          (size_t)(-1).
    */
size_t mbrtowc(wchar_t * restrict /*pwc*/, const char * restrict /*s*/,
               size_t /*n*/, mbstate_t * restrict /*ps*/);
   /*
    * inspects at most n bytes beginning with the byte pointed to by s to
    * determine the number of bytes needed to complete the next multibyte
    * character (including any shift sequences). If the function determines that
    * the next multibyte character is complete and valid, it determines the
    * value of the corresponding wide character and then, if pwc is not a null
    * pointer, stores that value in the object pointed to by pwc. If the
    * corresponding wide character is the null wide character, the resulting
    * state described is the initial conversion state.
    * If s is a null pointer, the mbrtowc function is equivalent to the call:
    *     mbrtowc(NULL, "", 1, ps)
    * In this case, the value of the parameters pwc and n are ignored.
    * Returns: 0            if the next n or fewer bytes complete the multibyte
    *                       character that corresponds to the null wide
    *                       character (which is the value stored).
    *          positive     if the next n or fewer bytes complete a valid
    *                       multibyte character (which is the value stored);
    *                       the value returned is the number of bytes that
    *                       complete the multibyte character.
    *          (size_t)(-2) if the next n bytes contribute to an incomplete
    *                       (but potentially valid) multibyte character, and
    *                       all n bytes have been processed (no value is
    *                       stored).
    *          (size_t)(-1) if an encoding error occurs, in which case the next
    *                       n or fewer bytes do not contribute to a complete and
    *                       valid multibyte character (no value is stored); the
    *                       value of the macro EILSEQ is stored in errno, and
    *                       the conversion state is unspecified.
    */
size_t wcrtomb(char * restrict /*s*/, wchar_t /*wc*/,
               mbstate_t * restrict /*ps*/);
   /*
    * determines the number of bytes needed to represent the multibyte character
    * than corresponds to the wide character given by wc (including any shift
    * sequences), and stores the multibyte character representation in the
    * array whose first element is pointed to by s. At most MB_CUR_MAX bytes are
    * stored. If wc is a null wide character, a null byte is stored, preceded by
    * any shift sequence needed to restore the initial shift state; the
    * resulting state described is the initial conversion state.
    * If s is a null ponter, the wcrtomb function is equivalent to the call:
    *     wcrtomb(buf, L'\0', ps)
    * where buf is an internal buffer.
    * Returns: the number of bytes stored in the array object (including any
    *          shift sequences). When wc is not a valid wide character, an
    *          encoding error occurs: the function stores the value of the
    *          macro EILSEQ in errno and returns (size_t)(-1); the conversion
    *          state is unspecified.
    */

/*
 * Restartable Multibyte/Wide String Conversion Functions
 * These functions differ from the corresponding multibyte string functions
 * in <stdlib.h> (mbstowcs and wcstombs) in that they have an extra parameter,
 * ps, of type pointer to mbstate_t that points to an object that can completely
 * describe the current conversion state of the associated multibyte character
 * sequence. If ps is a null pointer, each function uses its own internal
 * mbstate_t object instead, which is initialised at program startup to the
 * initial conversion state. The implementation behaves as if no library
 * function calls these functions with a null pointer for ps.
 * Also unlike their corresponding functions, the conversion source parameter,
 * src, has a pointer-to-pointer type. When the function is storing the results
 * of its conversions (that is, when dst is not a null pointer), the pointer
 * object pointed to by this parameter is updated to reflect the amount of the
 * source processed by that invocation.
 */
size_t mbsrtowcs(wchar_t * restrict /*dst*/, const char ** restrict /*src*/,
                 size_t /*n*/, mbstate_t * restrict /*ps*/);
   /*
    * converts a sequence of multibyte characters that begins in the conversion
    * state described by the object pointed to by ps, from the array indirectly
    * pointed to by src into a sequence of corresponding wide characters. If
    * dst is not a null pointer, the converted characters are stored into the
    * array pointed to by dst. Conversion continues up to and including a
    * terminating null character, which is also stored. Conversion stops earlier
    * in two cases: when a sequence of bytes is encountered that does not form
    * a valid multibyte character, or (if dst is not a null pointer) when len
    * wide characters have been stored into the array pointed to by dst. Each
    * conversion takes place as if by a call to the mbrtowc function.
    * If dst is not a null pointer, the pointer object pointed to by src is
    * assigned either a null pointer (if conversion stopped due to reaching a
    * terminating null character) or the address just past the last multibyte
    * character converted (if any). If conversion stopped due to reaching a
    * terminating null character and dst is not a null pointer, the resulting
    * state described is the initial conversion state.
    * Returns: the number of multibyte characters successfully converted, not
    *          including the terminating null character (if any). If the
    *          input conversion encounters a sequence of bytes that do not form
    *          a valid multibyte character, an encoding error occurs: the
    *          mbsrtowcs function stores the value of the macro EILSEQ in errno
    *          and returns (size_t)(-1); the conversion state is unspecified.
    */
size_t wcsrtombs(char * restrict /*dst*/, const wchar_t ** restrict /*src*/,
                 size_t /*len*/, mbstate_t * restrict /*ps*/);
   /*
    * converts a sequence of wide characters from the array indirectly pointed
    * to by src into a sequence of corresponding multibyte characters that
    * begins in the conversion state described by the object pointed to by ps.
    * If dst is not a null pointer, the converted characters are then stored
    * into the array pointed to by dst. Conversion continues up to and including
    * a terminating null wide character, which is also stored. Conversion stops
    * earlier in two cases: when a wide character is reached that does not
    * correspond to a valid multibyte character, or (if dst is not a null
    * pointer) when the next multibyte character would exceed the limit of len
    * total bytes to be stored into the array pointed to by dst. Each conversion
    * takes place as if by a call to the wcrtomb function.
    * If dst is not a null pointer, the pointer object pointed to by src is
    * assigned either a null pointer (if conversion stopped due to reaching a
    * terminating null wide character) or the address just past the last wide
    * character converted (if any). If conversion stopped due to reaching a
    * terminating null wide character, the resulting state described is the
    * initial conversion state.
    * Returns: the number of bytes in the resulting multibyte character
    *          sequence, not including the terminating null character (if any).
    *          If conversion stops because a wide character is reached that does
    *          not correspond to a valid multibyte character, an encoding error
    *          occurs: the wcsrtombs function stores the value of the macro
    *          EILSEQ in errno and returns (size_t)(-1); the conversion state is
    *          unspecified.
    */

#ifdef __cplusplus
}
#undef restrict
#endif

#endif

/* end of wchar.h */
