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
/*-*-C-*-*/

#define DEBUG 0                 /* Set to 1 for Tube debugging support */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#include "kernel.h"
typedef _kernel_oserror os_error;

typedef int Bool;
#define TRUE 1
#define FALSE 0


#include "swis.h"
#include "misc.h"
#include "convert.h"

os_error *make_error (int num);
extern Bool do_declarations, do_extra_declarations, dont_allow_downloads,
    permanent, procremap;

#define ERROR_BASE 0x43440      /* same as SWI chunk base */

#define EBADMETRICS 1
#define EBADOUTLINES 2
#define EBADENCODING 3
#define EBADBASEENC 4
#define EWORKSPACE 5
#define ENULL 6
#define EUNKNOWNSWI 7 /* Unused */
#define EOUTPUT 8
#define EPREFIX 9
#define EBADDERIVATION 10

/* Start foreign font names we generate with one of these tags.
 * Note that downloaded fonts are never kerned.
 */

#define FONTTAG_NORMAL          "RO_"   /* These should be the same length */
#define FONTTAG_KERNED          "RK_"
#define FONTTAG_DOWNLOAD        "DL_"

/* PDriver_MiscOp subreasons */

#ifndef MiscOp_AddFont
#define MiscOp_AddFont 0
#endif

#ifndef MiscOp_EnumerateFonts
#define MiscOp_EnumerateFonts 2
#endif

#ifndef MiscOp_AddFont_Overwrite
#define MiscOp_AddFont_Overwrite 0x1    /* bits for R4 in AddFont call */
#endif

/* Size of return buffers for filenames etc */
#define TEMPMAX 256
#define LEAFMAX 11

/* Dir for Sidney encodings, etc, and OldLatin1 */

#define PRIVATEENCDIR "Printers:PS.PSfiles."
#define PUBLICENCDIR "Font:Encodings."
#define OLDLATIN1 PRIVATEENCDIR "OldLatin1"
#define BASEBASE "/Base"

#define ROALPHABET "%%RISCOS_Alphabet"
#define ROBASEDON  "%%RISCOS_BasedOn"

/* Substitute this font when we want to do a download but were told not to */
#define DEFAULTFONT "Courier"

/* Only follow a derived Outlines file if less than this size */
#define FOLLOW_MAX_SIZE 256

#if DEBUG
extern void dstring (char *s), dstringc(char *s);
extern void dint (char *s, int i);
#else
#define dstring(s)
#define dstringc(s)
#define dint(s, i)
#endif
