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

/* hostsys.h: specify details of host system when compiling CLIB */
/* Copyright (C) A.C. Norman and A. Mycroft     */
/* version 0.01a, amalgamates norcrosys+sysdep: */
/* soon rationalise to armsys.h, s370sys.h etc  */
/* The tests of #ifdef ARM must go one day.     */

#ifndef __hostsys_h
#define __hostsys_h

#include <stdio.h>
#include <stdbool.h>

#undef MACHINE
#ifdef __arm
#  ifndef __ARM
#  define __ARM 1
#  endif
#endif

#ifdef __ARM
/* The following lines could be a #include "armsys.h" etc. */
#  ifndef PLUS_APRM
/* ordinary ARM */
#    define BYTESEX_EVEN 1
#  else
/* Apple ARM */
#    define BYTESEX_ODD 1
#  endif
#  define MACHINE "ARM"
#endif
#ifdef __ACW
#  define BYTESEX_EVEN 1
#  define MACHINE "ACW"
#endif
#ifdef __ibm370
#  define BYTESEX_ODD 1
#  define MACHINE "370"
#endif
#ifndef MACHINE
#  error -D__ibm370 assumed
#  define __ibm370 1
#  define BYTESEX_ODD 1
#  define MACHINE "370"
#endif

#define memclr(p,n) memset(p,0,n)

#ifdef __ibm370
#  define MAXSTORE 0x00ffffff       /* used only by alloc.c */
#else                               /* not right! */
#  define MAXSTORE 0x03ffffff       /* used only by alloc.c */
#  define HOST_LACKS_ALLOC 1
#endif

#ifdef __ARM                          /* fpe2 features stfp/ldfp ops */
#  define HOST_HAS_BCD_FLT 1
#  ifndef SOFTWARE_FLOATING_POINT
#    define HOST_HAS_TRIG 1         /* and ieee trig functions     */
#  endif
#endif

extern char *_strerror(int n, char *v);
 /* The same as strerror, except that if an error message must be constructed
 * this is done into the array v.
 */

extern int _interrupts_off;
extern void _raise_stacked_interrupts(void);
extern void _postmortem(char *msg, int mflag);
extern void _mapstore(void);
extern void _write_profile(char *filename);
extern void _sysdie(const char *s);
extern void _init_alloc(void), _initio(char *,char *,char *),
            _terminateio(void), _lib_shutdown(void), _signal_init(void),
            _exit_init(void);
extern void _armsys_lib_init(void);

extern int _signal_real_handler(int sig);

#ifndef __size_t
#define __size_t 1
typedef unsigned int size_t;  /* see <stddef.h> */
#endif
extern void *_sys_alloc(size_t n);
extern void _init_user_alloc(void);
extern void _terminate_user_alloc(void);
extern void _sys_msg(const char *);
extern bool _sys__assert(const char *fmt, const char *expr,
                         const char *func, const char *file, int line);
extern void _exit(int n);
extern void _terminate_getenv(void);

#ifdef __ARM
typedef int FILEHANDLE;
#define TTYFILENAME ":tt"
extern int _osgbpb(int op, int fh, void *base, int len, int extra);
extern int _ttywrite(const unsigned char *buf, unsigned int len, int flag);
extern int _ttyread(unsigned char *buff, int size, int flag);
extern double _ldfp(void *x);
extern void _stfp(double d, void *p);
#endif

#ifdef __ibm370
#  if ('A' == 193)
#    define atoe(x) (x)       /* ebcdic already.                */
#    define etoa(x) (x)
#  else
#    define atoe(x) _atoe[x]  /* else translate text files etc. */
#    define etoa(x) _etoa[x]
#  endif
extern char _etoa[], _atoe[];
extern void _abend(int);
extern void *_svc_getmain(int);
extern void _svc_freemain(void *, int);
struct _svcwto { short len, mcsflags;
                 char  msg[80];
                 short desccode, routcde; };
extern void _svc_wto(const struct _svcwto *);
struct _svctime { int csecs; int yday/* 0-365 */; int year; };
extern void _svc_time(struct _svctime *);
extern void  _svc_stimer(int);
extern unsigned  _svc_ttimer(void);             /* units of 1/38400 sec  */
/* the following lines use "struct NIOPBASE" instead of "NIOPBASE" to    */
/* to reduce syntactic confusion if "niopbase.h" not included            */
typedef struct NIOPBASE *FILEHANDLE;
extern int _io_call(int fn, struct NIOPBASE *p, int arg), _io_r0;
extern struct _svcwto _io_emsg;  /* beware only 64 bytes thereof */
#endif


#ifndef SOFTWARE_FLOATING_POINT
#  ifdef __ibm370
#     define IBMFLOAT 1
#  else
#     define IEEE 1
/* IEEE floating point format assumed.                                   */
#     ifdef __ARM
/* For the current ARM floating point system that Acorn use the first    */
/* word of a floating point value is the one containing the exponent.    */
#        undef OTHER_WORD_ORDER_FOR_FP_NUMBERS
/*#        define DO_NOT_SUPPORT_UNNORMALIZED_NUMBERS 1*/
#     endif
#  endif
#endif

/* I/O stuff... */

extern FILEHANDLE _sys_open(const char *name, int openmode);

/* openmode is a bitmap, whose bits have the following significance ...  */
/* most correspond directly to the ANSI mode specification - the         */
/* exception is OPEN_T, an extension which requests timestamp update.    */
/* This is really a sop to implementation laziness: what is intended is  */
/* that the timestamp should be updated if the file is written to or     */
/* otherwise modified.  But that is known only when the file is closed   */
/* and RISC OS has no 'set timestamp given filehandle' operation and the */
/* name by which the file was opened may no longer be valid at the time  */
/* of its close.                                                         */
#define OPEN_R 0
#define OPEN_W 4
#define OPEN_A 8
#define OPEN_B 1
#define OPEN_PLUS 2
#define OPEN_T 16

extern int _sys_close(FILEHANDLE fh);
/* result is 0 or an error indication                                    */

extern int _sys_write(FILEHANDLE fh, const unsigned char *buf, unsigned len, int mode);
/* result is number of characters not written (ie non-0 denotes a        */
/* failure of some sort) or a negative error indicator.                  */

extern int _sys_read(FILEHANDLE fh, unsigned char *buf, unsigned len, int mode);
/* result is number of characters not read (ie len - result _were_ read),*/
/* or negative to indicate error or EOF.                                 */
/* _sys_iserror(result) distinguishes between the two possibilities.     */
/* (Redundantly, since on EOF it is required that (result & ~0x80000000) */
/* is the number of characters unread).                                  */

extern int _sys_istty(FILE *);
/* Return true if the argument file is connected to a terminal.          */
/* Used to:  provide default unbuffered behaviour (in the absence of a   */
/*           setbuf call).                                               */
/*           disallow seek                                               */

extern int _sys_seek(FILEHANDLE fh, _off64_t pos);
/* Position the file at offset pos from its beginning.                   */
/* Result is >= 0 if OK, negative for an error.                          */

extern int _sys_ensure(FILEHANDLE fh);
/* Flush any OS buffers associated with fh, ensuring that the file is    */
/* up to date on disc.  (Only required if HOSTOS_NEEDSENSURE; see above) */
/* Result is >= 0 if OK, negative for an error.                          */

extern _off64_t _sys_flen(FILEHANDLE fh);
/* Return the current length of the file fh (or a negative error         */
/* indicator).  Required to convert fseek(, SEEK_END) into (, SEEK_START)*/
/* as required by _sys_seek.                                             */

#ifdef __ARM

#define NONHANDLE (-1)

extern void _sys_tmpnam_(char *name, int sig);
/* Return the name for temporary file number  sig  in the buffer name.   */

extern char *_hostos_error_string(int no, char *buf);

#endif

#ifdef __ibm370

#define NONHANDLE ((FILEHANDLE)0)
#define _sys_istty_(fh) (((DCB *)(fh))->DCBDEVT==DCBDVTRM)
#define _sys_seek_(fh, pos) (_sysdie("Unimplemented fseek"), 0)
#define _sys_flen_(fh)      (_sysdie("Unimplemented filelen"), 0)

extern int _sys_write_(FILEHANDLE fh, unsigned char *buf, int len, int mode);
extern int _sys_read_(FILEHANDLE fh, unsigned char *buf, int len, int mode);
extern int _sys_close_(FILEHANDLE fh);
#define _sys_tmpnam_(name, sig) sprintf(name, "$.tmp.x%.8x", sig)

#endif

/* The following code is NOT PORTABLE but can stand as a prototype for   */
/* whatever makes sense on other machines.                               */

#ifdef IBMFLOAT
/* This version works with IBM 360 floating point.                       */
#define SignBit 0x80000000
#define ExpBits 0x7F000000
#define MHiBits 0x00FFFFFF

#ifdef BYTESEX_EVEN
typedef union {struct {int mhi:24, x:7, s:1; unsigned mlo; } i;
               struct {unsigned sxmhi, mlo; } w;
               double d; } fp_number;
#else
typedef union {struct {int s:1, x:7, mhi:24; unsigned mlo; } i;
               struct {unsigned sxmhi, mlo; } w;
               double d; } fp_number;
#endif

#else
#define SignBit 0x80000000
#define ExpBits 0x7FF00000
#define MHiBits 0x000FFFFF
#define ExpBits_S 0x7F800000
#define MBits_S   0x007FFFFF

#ifdef BYTESEX_EVEN
typedef union {struct {int m:23, x:8, s:1; } i;
               unsigned w;
               float s; } fp_number_single;
#else
typedef union {struct {int s:1, x:8, m:23; } i;
               unsigned w;
               float s; } fp_number_single;
#endif
#ifndef OTHER_WORD_ORDER_FOR_FP_NUMBERS
/* This version works with the ARM floating point emulator - it may have */
/* to be reworked when or if floating point hardware is installed        */

#  ifdef BYTESEX_EVEN
typedef union {struct {int mhi:20, x:11, s:1; unsigned mlo; } i;
               struct {unsigned sxmhi, mlo; } w;
               double d; } fp_number;
#  else
typedef union {struct {int s:1, x:11, mhi:20; unsigned mlo; } i;
               struct {unsigned sxmhi, mlo; } w;
               double d; } fp_number;
#  endif

#else   /* OTHER_WORD_ORDER_FOR_FP_NUMBERS */
#  ifdef BYTESEX_EVEN
typedef union {struct {unsigned mlo; int mhi:20, x:11, s:1; } i;
               struct {unsigned mlo, sxmhi; } w;
               double d; } fp_number;
#  else
typedef union {struct {unsigned mlo; int s:1, x:11, mhi:20; } i;
               struct {unsigned mlo, sxmhi; } w;
               double d; } fp_number;
#  endif
#endif  /* OTHER_WORD_ORDER_FOR_FP_NUMBERS */

#endif

/* the object of the following macro is to adjust the floating point     */
/* variables concerned so that the more significant one can be squared   */
/* with NO LOSS OF PRECISION. It is only used when there is no danger    */
/* of over- or under-flow.                                               */

/* This code is NOT PORTABLE but can be modified for use elsewhere       */
/* It should, however, serve for IEEE and IBM FP formats.                */

#define _fp_normalize(high, low)                                          \
    {   fp_number temp;        /* access to representation     */         \
        double temp1;                                                     \
        temp.d = high;         /* take original number         */         \
        temp.i.mlo = 0;        /* make low part of mantissa 0  */         \
        temp1 = high - temp.d; /* the bit that was thrown away */         \
        low += temp1;          /* add into low-order result    */         \
        high = temp.d;                                                    \
    }

#if 0
/* The next line is not very nice, but since I want to declare a      */
/* function of type (FILE *) is seems to be needed. If you do not     */
/* want <stdio.h> included, tough luck!                               */
/* Note also the use of __system_io to alter the amount of detail     */
/* revealed by <stdio.h>.                                             */
#include <stdio.h>
extern FILE *_fopen_string_file(const char *data, int length);
#endif


#if defined __ARM && defined SHARED_C_LIBRARY

#  define _call_client_0(f) \
     _kernel_call_client(0, 0, 0, (_kernel_ccproc *)(f))
#  define _call_client_1(f,a) \
     _kernel_call_client((int)(a), 0, 0, (_kernel_ccproc *)(f))
#  define _call_client_2(f,a,b) \
     _kernel_call_client((int)(a), (int)(b), 0, (_kernel_ccproc *)(f))
#  define _call_client_3(f,a,b,c) \
     _kernel_call_client((int)(a), (int)(b), (int)(c), (_kernel_ccproc *)(f))

#else

#  define _call_client_0(f)       (*(f))()
#  define _call_client_1(f,a)     (*(f))(a)
#  define _call_client_2(f,a,b)   (*(f))((a), (b))
#  define _call_client_3(f,a,b,c) (*(f))((a), (b), (c))

#endif

#ifdef DEFAULT_TEXT
extern char *_kernel_getmessage(char *msg, char *tag);
extern char *_kernel_getmessage2(char *msg, char *tag, char *dst, size_t len);
#define _kernel_getmessage_def(msg, tag) _kernel_getmessage(msg, tag)
#else
extern char *_kernel_getmessage(char *tag);
extern char *_kernel_getmessage2(char *tag, char *dst, size_t len);
extern char *_kernel_getmessage_def(char *msg, char *tag);
#define _kernel_getmessage(msg, tag) _kernel_getmessage(tag)
#define _kernel_getmessage2(msg, tag, dst, len) _kernel_getmessage2(tag, dst, len)
#endif
extern char *decimal_point;

extern int __counter( void );

#endif

/* end of hostsys.h */
