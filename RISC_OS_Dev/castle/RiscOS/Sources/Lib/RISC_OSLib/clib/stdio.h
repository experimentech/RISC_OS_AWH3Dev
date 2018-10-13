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

/* stdio.h: ISO 'C' (9899:1999) library header, section 7.19 */
/* Copyright (C) Codemist Ltd. */
/* Copyright (C) Acorn Computers Ltd., 1990, 1992 */
/* version 3.03 */

/*
 * stdio.h declares three types, several macros, and many functions for
 * performing input and output. For a discussion on Streams and Files
 * refer to sections 7.19.2 and 7.19.3 in the above ISO standard, or
 * to a modern textbook on C.
 */

#ifndef __stdio_h
#define __stdio_h

#define __LIB_VERSION 500       /* 5.00, but int for PP inequality test */

#ifndef __size_t
#define __size_t 1
typedef unsigned int size_t;   /* from <stddef.h> */
#endif

/* ANSI forbids va_list to be defined here */
typedef char *__va_list[1];       /* keep in step with <stdarg.h> */

#ifndef NULL
#  define NULL 0                /* see <stddef.h> */
#endif

typedef long int _off_t;
#if __STDC_VERSION__ >= 199901
typedef long long int _off64_t;
#endif

#ifndef _FILE_OFFSET_BITS
#define _FILE_OFFSET_BITS 32
#endif
#if __STDC_VERSION__ >= 199901 && _FILE_OFFSET_BITS == 64
typedef _off64_t fpos_t;
#elif _FILE_OFFSET_BITS == 32
typedef _off_t fpos_t;
#else
#error Unsupported _FILE_OFFSET_BITS value
#endif
   /*
    * fpos_t is an object capable of recording all information needed to
    * specify uniquely every position within a file.
    */

#if defined(_LARGEFILE_SOURCE) || defined(_LARGEFILE64_SOURCE)
typedef fpos_t off_t;
#endif
   /*
    * off_t is an object capable of recording the offset from any position
    * within a file to any other position within that file, and is used by
    * the LFS extension functions fseeko() and ftello().
    */

#if __STDC_VERSION__ >= 199901 && defined(_LARGEFILE64_SOURCE)
typedef _off64_t fpos64_t, off64_t;
#endif
   /*
    * fpos64_t and off64_t are the equivalent of fpos_t and off_t respectively,
    * and are used in their place when an application explicitly uses the
    * 64-bit LFS extension functions fgetpo64(), fseeko64(), fsetpos64() and
    * ftello64().
    */

typedef struct __FILE_struct
{ unsigned char *__ptr;
  int __icnt;      /* two separate _cnt fields so we can police ...        */
  int __ocnt;      /* ... restrictions that read/write are fseek separated */
  int __flag;
  /* AM: the following things do NOT need __ prefixes as they are          */
  /* are invisible in an ANSI-conforming program.                          */
  unsigned char *__base; /* buffer base */
  int __file;            /* RISCOS/Arthur/Brazil file handle */
  long __unused;         /* used to contain 32-bit file pointer */
  int __bufsiz;          /* maximum buffer size */
  int __signature;       /* used with temporary files */
  struct __extradata *__extrap; /* pointer to information about stream */
} FILE;
   /*
    * FILE is an object capable of recording all information needed to control
    * a stream, such as its file position indicator, a pointer to its
    * associated buffer, an error indicator that records whether a read/write
    * error has occurred and an end-of-file indicator that records whether the
    * end-of-file has been reached.
    * N.B. the objects contained in the #ifdef __system_io clause are for
    * system use only.
    */

# define _IOREAD      0x01 /* system use - open for input */
# define _IOWRITE     0x02 /* system use - open for output */
# define _IOBIN       0x04 /* system use - binary stream */
# define _IOSTRG      0x08 /* system use - string stream */
# define _IOSEEK      0x10 /* system use - physical seek required before IO */
# define _IOLAZY      0x20 /* system use - possible seek pending */
# define _IOSBF      0x800 /* system use - system allocated buffer */
# define _IOAPPEND 0x08000 /* system use - must seek to eof before write */
#define _IOEOF     0x40 /* end-of-file reached */
#define _IOERR     0x80 /* error occurred on stream */
#define _IOFBF    0x100 /* fully buffered IO */
#define _IOLBF    0x200 /* line buffered IO */
#define _IONBF    0x400 /* unbuffered IO */

#define BUFSIZ   (4096) /* system buffer size (as used by setbuf) */
#define EOF      (-1)
   /*
    * negative integral constant, indicates end-of-file, that is, no more input
    * from a stream.
    */
#define FOPEN_MAX _SYS_OPEN
   /*
    * an integral constant expression that is the minimum number of files that
    * this implementation guarantees can be open simultaneously.
    */
/* _SYS_OPEN defines a limit on the number of open files that is imposed
   by this C library */
#define _SYS_OPEN 16
#define FILENAME_MAX 80
   /*
    * an integral constant expression that is the size of an array of char
    * large enough to hold the longest filename string
    */
#define L_tmpnam FILENAME_MAX
   /*
    * an integral constant expression that is the size of an array of char
    * large enough to hold a temporary file name string generated by the
    * tmpnam function.
    */

#ifndef SEEK_SET
#define SEEK_SET 0 /* start of stream (see fseek) */
#define SEEK_CUR 1 /* current position in stream (see fseek) */
#define SEEK_END 2 /* end of stream (see fseek) */
#endif

#define TMP_MAX 1000000000
   /*
    * an integral constant expression that is the minimum number of unique
    * file names that shall be generated by the tmpnam function.
    */

#ifdef __cplusplus
#define restrict
extern "C" {
#else
#define restrict __restrict
#endif
#ifdef SYSTEM_STATICS
extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;
#else
extern FILE __iob[];
   /* an array of file objects for use by the system. */

#define stdin  (&__iob[0])
   /* pointer to a FILE object associated with standard input stream */
#define stdout (&__iob[1])
   /* pointer to a FILE object associated with standard output stream */
#define stderr (&__iob[2])
   /* pointer to a FILE object associated with standard error stream */
#endif

int remove(const char * /*filename*/);
   /*
    * causes the file whose name is the string pointed to by filename to be
    * removed. Subsequent attempts to open the file will fail, unless it is
    * created anew. If the file is open, the behaviour of the remove function
    * is implementation-defined (under RISCOS/Arthur/Brazil the operation
    * fails).
    * Returns: zero if the operation succeeds, nonzero if it fails.
    */
int rename(const char * /*old*/, const char * /*new*/);
   /*
    * causes the file whose name is the string pointed to by old to be
    * henceforth known by the name given by the string pointed to by new. The
    * file named old is effectively removed. If a file named by the string
    * pointed to by new exists prior to the call of the rename function, the
    * behaviour is implementation-defined (under RISCOS/Arthur/Brazil, the
    * operation fails).
    * Returns: zero if the operation succeeds, nonzero if it fails, in which
    *          case if the file existed previously it is still known by its
    *          original name.
    */
FILE *tmpfile(void);
#if __STDC_VERSION__ >= 199901
FILE *_tmpfile64(void);
#if _FILE_OFFSET_BITS == 64
#define tmpfile _tmpfile64
#endif
#ifdef _LARGEFILE64_SOURCE
#define tmpfile64 _tmpfile64
#endif
#endif
   /*
    * creates a temporary binary file that will be automatically removed when
    * it is closed or at program termination. The file is opened for update.
    * Returns: a pointer to the stream of the file that it created. If the file
    *          cannot be created, a null pointer is returned.
    */
char *tmpnam(char * /*s*/);
   /*
    * generates a string that is not the same as the name of an existing file.
    * The tmpnam function generates a different string each time it is called,
    * up to TMP_MAX times. If it is called more than TMP_MAX times, the
    * behaviour is implementation-defined (under RISCOS/Arthur/Brazil the
    * algorithm for the name generation works just as well after tmpnam has
    * been called more than TMP_MAX times as before; a name clash is impossible
    * in any single half year period).
    * Returns: If the argument is a null pointer, the tmpnam function leaves
    *          its result in an internal static object and returns a pointer to
    *          that object. Subsequent calls to the tmpnam function may modify
    *          the same object. if the argument is not a null pointer, it is
    *          assumed to point to an array of at least L_tmpnam characters;
    *          the tmpnam function writes its result in that array and returns
    *          the argument as its value.
    */

int fclose(FILE * /*stream*/);
   /*
    * causes the stream pointed to by stream to be flushed and the associated
    * file to be closed. Any unwritten buffered data for the stream are
    * delivered to the host environment to be written to the file; any unread
    * buffered data are discarded. Whether or not the call succeeds, the stream
    * is disassociated from the file and any buffer set by the setbuf or
    * setvbuf function is disassociated from the stream (and deallocated if it
    * was automatically allocated).
    * Returns: zero if the stream was succesfully closed, or EOF if any
    *          errors were detected or if the stream was already closed.
    */
int fflush(FILE * /*stream*/);
   /*
    * If the stream points to an output stream or an update stream in which
    * the most recent operation was not input, the fflush function causes any
    * unwritten data for that stream to be delivered to the host environment to
    * be written to the file. If the stream points to an input or update
    * stream, the fflush function undoes the effect of any preceding ungetc
    * operation on the stream.
    * If stream is a null pointer, the fflush function performs this flushing
    * action on all streams for which the behaviour is defined above.
    * Returns: EOF if a write error occurs.
    */
FILE *fopen(const char * restrict /*filename*/,
            const char * restrict /*mode*/);
#if __STDC_VERSION__ >= 199901
FILE *_fopen64(const char * restrict /*filename*/,
               const char * restrict /*mode*/);
#if _FILE_OFFSET_BITS == 64
#define fopen _fopen64
#endif
#ifdef _LARGEFILE64_SOURCE
#define fopen64 _fopen64
#endif
#endif
   /*
    * opens the file whose name is the string pointed to by filename, and
    * associates a stream with it.
    * The argument mode points to a string beginning with one of the following
    * sequences:
    * "r"         open text file for reading
    * "w"         create text file for writing, or truncate to zero length
    * "a"         append; open text file or create for writing at eof
    * "rb"        open binary file for reading
    * "wb"        create binary file for writing, or truncate to zero length
    * "ab"        append; open binary file or create for writing at eof
    * "r+"        open text file for update (reading and writing)
    * "w+"        create text file for update, or truncate to zero length
    * "a+"        append; open text file or create for update, writing at eof
    * "r+b"/"rb+" open binary file for update (reading and writing)
    * "w+b"/"wb+" create binary file for update, or truncate to zero length
    * "a+b"/"ab+" append; open binary file or create for update, writing at eof
    *
    * Opening a file with read mode ('r' as the first character in the mode
    * argument) fails if the file does not exist or cannot be read.
    * Opening a file with append mode ('a' as the first character in the mode
    * argument) causes all subsequent writes to be forced to the current end of
    * file, regardless of intervening calls to the fseek function. In some
    * implementations, opening a binary file with append mode ('b' as the
    * second or third character in the mode argument) may initially position
    * the file position indicator beyond the last data written, because of the
    * NUL padding (but not under RISCOS/Arthur/Brazil).
    * When a file is opened with update mode ('+' as the second or third
    * character in the mode argument), both input and output may be performed
    * on the associated stream. However, output may not be directly followed by
    * input without an intervening call to the fflush fuction or to a file
    * positioning function (fseek, fsetpos, or rewind), and input be not be
    * directly followed by output without an intervening call to the fflush
    * fuction or to a file positioning function, unless the input operation
    * encounters end-of-file. Opening a file with update mode may open or
    * create a binary stream in some implementations (but not under RISCOS/
    * Arthur/Brazil). When opened, a stream is fully buffered if and only if
    * it does not refer to an interactive device. The error and end-of-file
    * indicators for the stream are cleared.
    * Returns: a pointer to the object controlling the stream. If the open
    *          operation fails, fopen returns a null pointer.
    */
FILE *freopen(const char * restrict /*filename*/,
              const char * restrict /*mode*/,
              FILE * restrict /*stream*/);
#if __STDC_VERSION__ >= 199901
FILE *_freopen64(const char * restrict /*filename*/,
                 const char * restrict /*mode*/,
                 FILE * restrict /*stream*/);
#if _FILE_OFFSET_BITS == 64
#define freopen _freopen64
#endif
#ifdef _LARGEFILE64_SOURCE
#define freopen64 _freopen64
#endif
#endif
   /*
    * opens the file whose name is the string pointed to by filename and
    * associates the stream pointed to by stream with it. The mode argument is
    * used just as in the fopen function.
    * The freopen function first attempts to close any file that is associated
    * with the specified stream. Failure to close the file successfully is
    * ignored. The error and end-of-file indicators for the stream are cleared.
    * Returns: a null pointer if the operation fails. Otherwise, freopen
    *          returns the value of the stream.
    */
void setbuf(FILE * restrict /*stream*/, char * restrict /*buf*/);
   /*
    * Except that it returns no value, the setbuf function is equivalent to the
    * setvbuf function invoked with the values _IOFBF for mode and BUFSIZ for
    * size, or (if buf is a null pointer), with the value _IONBF for mode.
    * Returns: no value.
    */
int setvbuf(FILE * restrict /*stream*/, char * restrict /*buf*/,
            int /*mode*/, size_t /*size*/);
   /*
    * may be used after the stream pointed to by stream has been associated
    * with an open file but before it is read or written. The argument mode
    * determines how stream will be buffered, as follows: _IOFBF causes
    * input/output to be fully buffered; _IOLBF causes output to be line
    * buffered (the buffer will be flushed when a new-line character is
    * written, when the buffer is full, or when input is requested); _IONBF
    * causes input/output to be completely unbuffered. If buf is not the null
    * pointer, the array it points to may be used instead of an automatically
    * allocated buffer (the buffer must have a lifetime at least as great as
    * the open stream, so the stream should be closed before a buffer that has
    * automatic storage duration is deallocated upon block exit). The argument
    * size specifies the size of the array. The contents of the array at any
    * time are indeterminate.
    * Returns: zero on success, or nonzero if an invalid value is given for
    *          mode or size, or if the request cannot be honoured.
    */

#pragma -v1   /* hint to the compiler to check f/s/printf format */
int fprintf(FILE * restrict /*stream*/, const char * restrict /*format*/, ...);
   /*
    * writes output to the stream pointed to by stream, under control of the
    * string pointed to by format that specifies how subsequent arguments are
    * converted for output. If there are insufficient arguments for the format,
    * the behaviour is undefined. If the format is exhausted while arguments
    * remain, the excess arguments are evaluated but otherwise ignored. The
    * fprintf function returns when the end of the format string is reached.
    * The format shall be a multibyte character sequence, beginning and ending
    * in its initial shift state. The format is composed of zero or more
    * directives: ordinary multibyte characters (not %), which are copied
    * unchanged to the output stream; and conversion specifiers, each of which
    * results in fetching zero or more subsequent arguments. Each conversion
    * specification is introduced by the character %. For a description of the
    * available conversion specifiers refer to section 4.9.6.1 in the ANSI
    * draft mentioned at the start of this file or to any modern textbook on C.
    * The minimum value for the maximum number of characters producable by any
    * single conversion is at least 509.
    * Returns: the number of characters transmitted, or a negative value if an
    *          output error occurred.
    */
int printf(const char * restrict /*format*/, ...);
   /*
    * is equivalent to fprintf with the argument stdout interposed before the
    * arguments to printf.
    * Returns: the number of characters transmitted, or a negative value if an
    *          output error occurred.
    */
int snprintf(char * restrict /*s*/, size_t /*n*/,
             const char * restrict /*format*/, ...);
   /*
    * is equivalent to fprintf, except that the argument s specifies an array
    * into which the generated output is to be written, rather than to a
    * stream. If n is zero, nothing is written and s may be a null pointer.
    * Otherwise, output characters beyond the n-1st are discarded rather than
    * being written to the array, and a null character is written at the end
    * of the characters actually written into the array.
    * Returns: the number of characters that would have been written had n
    *          been sufficiently large, not counting the terminating null
    *          character. Thus, the null-terminated output has been completely
    *          written if and only if the returned value is nonnegative and
    *          less than n.
    */
int sprintf(char * restrict /*s*/, const char * restrict /*format*/, ...);
   /*
    * is equivalent to fprintf, except that the argument s specifies an array
    * into which the generated output is to be written, rather than to a
    * stream. A null character is written at the end of the characters written;
    * it is not counted as part of the returned sum.
    * Returns: the number of characters written to the array, not counting the
    *          terminating null character.
    */
#pragma -v2   /* hint to the compiler to check f/s/scanf format */
int fscanf(FILE * restrict /*stream*/,
           const char * restrict /*format*/, ...);
   /*
    * reads input from the stream pointed to by stream, under control of the
    * string pointed to by format that specifies the admissible input sequences
    * and how thay are to be converted for assignment, using subsequent
    * arguments as pointers to the objects to receive the converted input. If
    * there are insufficient arguments for the format, the behaviour is
    * undefined. If the format is exhausted while arguments remain, the excess
    * arguments are evaluated but otherwise ignored.
    * The format is composed of zero or more directives: one or more
    * white-space characters; an ordinary character (not %); or a conversion
    * specification. Each conversion specification is introduced by the
    * character %. For a description of the available conversion specifiers
    * refer to section 4.9.6.2 in the ANSI draft mentioned at the start of this
    * file, or to any modern textbook on C.
    * If end-of-file is encountered during input, conversion is terminated. If
    * end-of-file occurs before any characters matching the current directive
    * have been read (other than leading white space, where permitted),
    * execution of the current directive terminates with an input failure;
    * otherwise, unless execution of the current directive is terminated with a
    * matching failure, execution of the following directive (if any) is
    * terminated with an input failure.
    * If conversions terminates on a conflicting input character, the offending
    * input character is left unread in the input strem. Trailing white space
    * (including new-line characters) is left unread unless matched by a
    * directive. The success of literal matches and suppressed asignments is
    * not directly determinable other than via the %n directive.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the fscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early conflict between an input
    *          character and the format.
    */
int scanf(const char * restrict /*format*/, ...);
   /*
    * is equivalent to fscanf with the argument stdin interposed before the
    * arguments to scanf.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the scanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
int sscanf(const char * restrict /*s*/, const char * restrict /*format*/, ...);
   /*
    * is equivalent to fscanf except that the argument s specifies a string
    * from which the input is to be obtained, rather than from a stream.
    * Reaching the end of the string is equivalent to encountering end-of-file
    * for the fscanf function.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the scanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
#pragma -v0   /* back to default */
int vfprintf(FILE * restrict /*stream*/, const char * restrict /*format*/,
             __va_list /*arg*/);
   /*
    * is equivalent to fprintf, with the variable argument list replaced by
    * arg, which has been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vfprintf function does not invoke the
    * va_end function.
    * Returns: the number of characters transmitted, or a negative value if an
    *          output error occurred.
    */
int vfscanf(FILE * restrict /*stream*/, const char * restrict /*format*/,
            __va_list /*arg*/);
   /*
    * is equivalent to fscanf, with the variable argument list replaced by
    * arg, which has been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vfscanf function does not invoke the
    * va_end function.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vfscanf function returns the number
    *          of input items assigned, which can be fewer than provided for,
    *          or even zero, in the event of an early matching failure.
    */
int vprintf(const char * restrict /*format*/, __va_list /*arg*/);
   /*
    * is equivalent to printf, with the variable argument list replaced by arg,
    * which has been initialised by the va_start macro (and possibly subsequent
    * va_arg calls). The vprintf function does not invoke the va_end function.
    * Returns: the number of characters transmitted, or a negative value if an
    *          output error occurred.
    */
int vscanf(const char * restrict /*format*/, __va_list /*arg*/);
   /*
    * is equivalent to scanf, with the variable argument list replaced by arg,
    * which has been initialised by the va_start macro (and possibly subsequent
    * va_arg calls). The vscanf function does not invoke the va_end function.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */
int vsnprintf(char * restrict /*s*/, size_t /*n*/,
              const char * restrict /*format*/, __va_list /*arg*/);
   /*
    * is equivalent to snprintf, with the variable argument list replaced by
    * arg, which has been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vsnprintf function does not invoke the
    * va_end function.
    * Returns: the number of characters that would have been written had n
    *          been sufficiently large, not counting the terminating null
    *          character. Thus, the null-terminated output has been completely
    *          written if and only if the returned value is nonnegative and
    *          less than n.
    */
int vsprintf(char * restrict /*s*/, const char * restrict /*format*/,
             __va_list /*arg*/);
   /*
    * is equivalent to sprintf, with the variable argument list replaced by
    * arg, which has been initialised by the va_start macro (and possibly
    * subsequent va_arg calls). The vsprintf function does not invoke the
    * va_end function.
    * Returns: the number of characters written in the array, not counting the
    *          terminating null character.
    */
int vsscanf(const char * restrict /*s*/, const char * restrict /*format*/,
            __va_list /*arg*/);
   /*
    * is equivalent to sscanf, with the variable argument list replaced by arg,
    * which has been initialised by the va_start macro (and possibly subsequent
    * va_arg calls). The sscanf function does not invoke the va_end function.
    * Returns: the value of the macro EOF if an input failure occurs before any
    *          conversion. Otherwise, the vscanf function returns the number of
    *          input items assigned, which can be fewer than provided for, or
    *          even zero, in the event of an early matching failure.
    */

int fgetc(FILE * /*stream*/);
   /*
    * obtains the next character (if present) as an unsigned char converted to
    * an int, from the input stream pointed to by stream, and advances the
    * associated file position indicator (if defined).
    * Returns: the next character from the input stream pointed to by stream.
    *          If the stream is at end-of-file, the end-of-file indicator is
    *          set and fgetc returns EOF. If a read error occurs, the error
    *          indicator is set and fgetc returns EOF.
    */
char *fgets(char * restrict /*s*/, int /*n*/, FILE * restrict /*stream*/);
   /*
    * reads at most one less than the number of characters specified by n from
    * the stream pointed to by stream into the array pointed to by s. No
    * additional characters are read after a new-line character (which is
    * retained) or after end-of-file. A null character is written immediately
    * after the last character read into the array.
    * Returns: s if successful. If end-of-file is encountered and no characters
    *          have been read into the array, the contents of the array remain
    *          unchanged and a null pointer is returned. If a read error occurs
    *          during the operation, the array contents are indeterminate and a
    *          null pointer is returned.
    */
int fputc(int /*c*/, FILE * /*stream*/);
   /*
    * writes the character specified by c (converted to an unsigned char) to
    * the output stream pointed to by stream, at the position indicated by the
    * asociated file position indicator (if defined), and advances the
    * indicator appropriately. If the file position indicator is not defined,
    * the character is appended to the output stream.
    * Returns: the character written. If a write error occurs, the error
    *          indicator is set and fputc returns EOF.
    */
int fputs(const char * restrict /*s*/, FILE * restrict /*stream*/);
   /*
    * writes the string pointed to by s to the stream pointed to by stream.
    * The terminating null character is not written.
    * Returns: EOF if a write error occurs; otherwise it returns a nonnegative
    *          value.
    */
int __filbuf(FILE * /*stream*/);
   /*
    * SYSTEM USE ONLY, called by getc to refill buffer and or sort out flags.
    * Returns: first character put into buffer or EOF on error.
    */
#define getc(p) \
    (--((p)->__icnt) >= 0 ? *((p)->__ptr)++ : __filbuf(p))
#ifndef __cplusplus
int (getc)(FILE * /*stream*/);
#endif
   /*
    * is equivalent to fgetc except that it may be (and is under
    * RISCOS/Arthur/Brazil) implemented as a macro. stream may be evaluated
    * more than once, so the argument should never be an expression with side
    * effects.
    * Returns: the next character from the input stream pointed to by stream.
    *          If the stream is at end-of-file, the end-of-file indicator is
    *          set and getc returns EOF. If a read error occurs, the error
    *          indicator is set and getc returns EOF.
    */
#define getchar() getc(stdin)
#ifndef __cplusplus
int (getchar)(void);
#endif
   /*
    * is equivalent to getc with the argument stdin.
    * Returns: the next character from the input stream pointed to by stdin.
    *          If the stream is at end-of-file, the end-of-file indicator is
    *          set and getchar returns EOF. If a read error occurs, the error
    *          indicator is set and getchar returns EOF.
    */
char *gets(char * /*s*/);
   /*
    * reads characters from the input stream pointed to by stdin into the array
    * pointed to by s, until end-of-file is encountered or a new-line character
    * is read. Any new-line character is discarded, and a null character is
    * written immediately after the last character read into the array.
    * Returns: s if successful. If end-of-file is encountered and no characters
    *          have been read into the array, the contents of the array remain
    *          unchanged and a null pointer is returned. If a read error occurs
    *          during the operation, the array contents are indeterminate and a
    *          null pointer is returned.
    */
int __flsbuf(int /*c*/, FILE * /*stream*/);
   /*
    * SYSTEM USE ONLY, called by putc to flush buffer and or sort out flags.
    * Returns: character put into buffer or EOF on error.
    */
#define putc(ch, p) \
    (--((p)->__ocnt) >= 0 ? (*((p)->__ptr)++ = (ch)) : __flsbuf(ch,p))
#ifndef __cplusplus
int (putc)(int /*c*/, FILE * /*stream*/);
#endif
   /*
    * is equivalent to fputc except that it may be (and is under
    * RISCOS/Arthur/Brazil) implemented as a macro. stream may be evaluated
    * more than once, so the argument should never be an expression with side
    * effects.
    * Returns: the character written. If a write error occurs, the error
    *          indicator is set and putc returns EOF.
    */
#define putchar(ch) putc(ch, stdout)
#ifndef __cplusplus
int (putchar)(int /*c*/);
#endif
   /*
    * is equivalent to putc with the second argument stdout.
    * Returns: the character written. If a write error occurs, the error
    *          indicator is set and putc returns EOF.
    */
int puts(const char * /*s*/);
   /*
    * writes the string pointed to by s to the stream pointed to by stdout, and
    * appends a new-line character to the output. The terminating null
    * character is not written.
    * Returns: EOF if a write error occurs; otherwise it returns a nonnegative
    *          value.
    */
int ungetc(int /*c*/, FILE * /*stream*/);
   /*
    * pushes the character specified by c (converted to an unsigned char) back
    * onto the input stream pointed to by stream. The character will be
    * returned by the next read on that stream. An intervening call to the
    * fflush function or to a file positioning function (fseek, fsetpos,
    * rewind) discards any pushed-back characters. The external storage
    * corresponding to the stream is unchanged.
    * One character pushback is guaranteed. If the unget function is called too
    * many times on the same stream without an intervening read or file
    * positioning operation on that stream, the operation may fail.
    * If the value of c equals that of the macro EOF, the operation fails and
    * the input stream is unchanged.
    * A successful call to the ungetc function clears the end-of-file
    * indicator. The value of the file position indicator after reading or
    * discarding all pushed-back characters shall be the same as it was before
    * the characters were pushed back. For a text stream, the value of the file
    * position indicator after a successful call to the ungetc function is
    * unspecified until all pushed-back characters are read or discarded. For a
    * binary stream, the file position indicator is decremented by each
    * successful call to the ungetc function; if its value was zero before a
    * call, it is indeterminate after the call.
    * Returns: the character pushed back after conversion, or EOF if the
    *          operation fails.
    */

size_t fread(void * restrict /*ptr*/,
             size_t /*size*/, size_t /*nmemb*/, FILE * restrict /*stream*/);
   /*
    * reads into the array pointed to by ptr, up to nmemb members whose size is
    * specified by size, from the stream pointed to by stream. The file
    * position indicator (if defined) is advanced by the number of characters
    * successfully read. If an error occurs, the resulting value of the file
    * position indicator is indeterminate. If a partial member is read, its
    * value is indeterminate. The ferror or feof function shall be used to
    * distinguish between a read error and end-of-file.
    * Returns: the number of members successfully read, which may be less than
    *          nmemb if a read error or end-of-file is encountered. If size or
    *          nmemb is zero, fread returns zero and the contents of the array
    *          and the state of the stream remain unchanged.
    */
size_t fwrite(const void * restrict /*ptr*/,
              size_t /*size*/, size_t /*nmemb*/, FILE * restrict /*stream*/);
   /*
    * writes, from the array pointed to by ptr up to nmemb members whose size
    * is specified by size, to the stream pointed to by stream. The file
    * position indicator (if defined) is advanced by the number of characters
    * successfully written. If an error occurs, the resulting value of the file
    * position indicator is indeterminate.
    * Returns: the number of members successfully written, which will be less
    *          than nmemb only if a write error is encountered.
    */

int fgetpos(FILE * restrict /*stream*/, _off_t * restrict /*pos*/);
#if __STDC_VERSION__ >= 199901
int _fgetpos64(FILE * restrict /*stream*/, _off64_t * restrict /*pos*/);
#if _FILE_OFFSET_BITS == 64
#define fgetpos _fgetpos64
#endif
#ifdef _LARGEFILE64_SOURCE
#define fgetpos64 _fgetpos64
#endif
#endif
   /*
    * stores the current value of the file position indicator for the stream
    * pointed to by stream in the object pointed to by pos. The value stored
    * contains unspecified information usable by the fsetpos function for
    * repositioning the stream to its position at the time  of the call to the
    * fgetpos function.
    * Returns: zero, if successful. Otherwise nonzero is returned and the
    *          integer expression errno is set to an implementation-defined
    *          nonzero value (under RISCOS/Arthur/Brazil fgetpos cannot fail).
    */
int fseek(FILE * /*stream*/, long int /*offset*/, int /*whence*/);
int _fseeko(FILE * /*stream*/, _off_t /*offset*/, int /*whence*/);
#if defined(_LARGEFILE_SOURCE) || defined(_LARGEFILE64_SOURCE)
#if _FILE_OFFSET_BITS == 64
#define fseeko _fseeko64
#else
#define fseeko _fseeko
#endif
#endif
#if __STDC_VERSION__ >= 199901
int _fseeko64(FILE * /*stream*/, _off64_t /*offset*/, int /*whence*/);
#ifdef _LARGEFILE64_SOURCE
#define fseeko64 _fseeko64
#endif
#endif
   /*
    * sets the file position indicator for the stream pointed to by stream.
    * For a binary stream, the new position is at the signed number of
    * characters specified by offset away from the point specified by whence.
    * The specified point is the beginning of the file for SEEK_SET, the
    * current position in the file for SEEK_CUR, or end-of-file for SEEK_END.
    * A binary stream need not meaningfully support fseek calls with a whence
    * value of SEEK_END.
    * For a text stream, either offset shall be zero, or offset shall be a
    * value returned by an earlier call to the ftell function on the same
    * stream and whence shall be SEEK_SET.
    * The fseek function clears the end-of-file indicator and undoes any
    * effects of the ungetc function on the same stream. After an fseek call,
    * the next operation on an update stream may be either input or output.
    * Returns: nonzero only for a request that cannot be satisfied.
    */
int fsetpos(FILE * /*stream*/, const _off_t * /*pos*/);
#if __STDC_VERSION__ >= 199901
int _fsetpos64(FILE * /*stream*/, const _off64_t * /*pos*/);
#if _FILE_OFFSET_BITS == 64
#define fsetpos _fsetpos64
#endif
#ifdef _LARGEFILE64_SOURCE
#define fsetpos64 _fsetpos64
#endif
#endif
   /*
    * sets  the file position indicator for the stream pointed to by stream
    * according to the value of the object pointed to by pos, which shall be a
    * value returned by an earlier call to the fgetpos function on the same
    * stream.
    * The fsetpos function clears the end-of-file indicator and undoes any
    * effects of the ungetc function on the same stream. After an fsetpos call,
    * the next operation on an update stream may be either input or output.
    * Returns: zero, if successful. Otherwise nonzero is returned and the
    *          integer expression errno is set to an implementation-defined
    *          nonzero value (under RISCOS/Arthur/Brazil the value that of EDOM
    *          in math.h).
    */
long int ftell(FILE * /*stream*/);
_off_t _ftello(FILE * /*stream*/);
#if defined(_LARGEFILE_SOURCE) || defined(_LARGEFILE64_SOURCE)
#if _FILE_OFFSET_BITS == 64
#define ftello _ftello64
#else
#define ftello _ftello
#endif
#endif
#if __STDC_VERSION__ >= 199901
_off64_t _ftello64(FILE * /*stream*/);
#ifdef _LARGEFILE64_SOURCE
#define ftello64 _ftello64
#endif
#endif
   /*
    * obtains the current value of the file position indicator for the stream
    * pointed to by stream. For a binary stream, the value is the number of
    * characters from the beginning of the file. For a text stream, the file
    * position indicator contains unspecified information, usable by the fseek
    * function for returning the file position indicator to its position at the
    * time of the ftell call; the difference between two such return values is
    * not necessarily a meaningful measure of the number of characters written
    * or read.
    * Returns: if successful, the current value of the file position indicator.
    *          On failure, the ftell function returns -1L and sets the integer
    *          expression errno to an implementation-defined nonzero value
    *          (under RISCOS/Arthur/Brazil ftell cannot fail).
    */
void rewind(FILE * /*stream*/);
   /*
    * sets the file position indicator for the stream pointed to by stream to
    * the beginning of the file. It is equivalent to
    *          (void)fseek(stream, 0L, SEEK_SET)
    * except that the error indicator for the stream is also cleared.
    * Returns: no value.
    */

void clearerr(FILE * /*stream*/);
   /*
    * clears the end-of-file and error indicators for the stream pointed to by
    * stream. These indicators are cleared only when the file is opened or by
    * an explicit call to the clearerr function or to the rewind function.
    * Returns: no value.
    */

#define feof(stream) ((stream)->__flag & _IOEOF)
#ifndef __cplusplus
int (feof)(FILE * /*stream*/);
#endif
   /*
    * tests the end-of-file indicator for the stream pointed to by stream.
    * Returns: nonzero iff the end-of-file indicator is set for stream.
    */
#define ferror(stream) ((stream)->__flag & _IOERR)
#ifndef __cplusplus
int (ferror)(FILE * /*stream*/);
#endif
   /*
    * tests the error indicator for the stream pointed to by stream.
    * Returns: nonzero iff the error indicator is set for stream.
    */
void perror(const char * /*s*/);
   /*
    * maps the error number  in the integer expression errno to an error
    * message. It writes a sequence of characters to the standard error stream
    * thus: first (if s is not a null pointer and the character pointed to by
    * s is not the null character), the string pointed to by s followed by a
    * colon and a space; then an appropriate error message string followed by
    * a new-line character. The contents of the error message strings are the
    * same as those returned by the strerror function with argument errno,
    * which are implementation-defined.
    * Returns: no value.
    */
#ifdef __cplusplus
}
#endif
#undef restrict

#endif

/* end of stdio.h */
