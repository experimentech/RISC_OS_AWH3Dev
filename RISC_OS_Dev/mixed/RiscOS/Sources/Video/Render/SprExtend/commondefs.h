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
/* h.commondefs
   Don't endlessly define these everywhere
*/

#ifndef commondefs_h_
#define commondefs_h_

/**************************************************************************
*                                                                         *
*    Common definitions.                                                  *
*                                                                         *
**************************************************************************/

#define BOOL      int

#define UNUSED(k) (k)=(k)   /* When compiler warnings get in the way of quality */
#undef MAX
#define MAX(a,b)  ((a) > (b) ? (a) : (b))
#undef MIN
#define MIN(a,b)  ((a) < (b) ? (a) : (b))

#define CMTOINCH_NUM        254
#define CMTOINCH_DEN        100
#define STANDARDDPI         90

#define ERROR_NO_MEMORY     1
#define ERROR_BAD_JPEG      2
#define ERROR_FATAL         4
#define ERROR_UNSUPP_JPEG   8
#define ERROR_PROG_JPEG_ERR 16
#define ERROR_BAD_SPR_TYPE  32
#define ERROR_BAD_COLMAP    64

/**************************************************************************
*                                                                         *
*    Switches.                                                            *
*                                                                         *
**************************************************************************/

#undef  DEBUG               /* Define this (along with switch 'debug' in the assembler) to get the dprintf() output */
#define ASMjpeg             /* Defines which mirror the equivalent GBLL in the assembler code */
#undef  ASMdoublepixel_bodge

/**************************************************************************
*                                                                         *
*    Low-level debugging output.                                          *
*                                                                         *
**************************************************************************/

#ifdef DEBUG
 void do_printf(const char *, const char *, ...);
 void do_sprintf(char *, const char *, ...);
 void do_assert(const char *, int, BOOL, int, const char *);
 void do_comment(const char *);
 #define dprintf(args)    do_printf args
 #define dsprintf(args)   do_sprintf args
 #define assert(x, y)     do_assert(__FILE__, __LINE__, x, y, #x)
 #define comment(ws,text) do_comment(text)
 #define newline()        dprintf(("", "\n"));
 #define EXIT_OSERROR(e)  { dprintf(("", "error %08x %s at %s %d\n", e->errnum, e->errmess, __FILE__, __LINE__)); exit_oserror(e); }
#else
 #define dprintf(args)    /* Nothing */
 #define dsprintf(args)   /* Nothing */
 #define assert(x, y)     {if (!(x)) exit_erl(y, __LINE__);}
 #define comment(ws,text) /* Nothing */
 #define newline()        /* Nothing */
 #define EXIT_OSERROR     exit_oserror
#endif

/**************************************************************************
*                                                                         *
*    Assembler functions (provided in Sources.PutScaled)                  *
*                                                                         *
**************************************************************************/

extern void exit(int reason);
extern void exit_erl(int reason, int line);
extern void exit_oserror(_kernel_oserror *err);
typedef enum { AREA_COEF = 0, AREA_TRAN, AREA_WKSP0 } area_t;
extern void *area_resize(area_t, size_t *, size_t);
extern void area_remove(area_t);

#endif
