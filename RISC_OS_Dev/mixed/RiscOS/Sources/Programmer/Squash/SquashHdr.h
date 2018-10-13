/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_SquashHdr_h
#define __cmhg_SquashHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "Squash"
#define Module_Help                      "Squash"
#define Module_VersionString             "0.30"
#define Module_VersionNumber             30
#ifndef Module_Date
#define Module_Date                      "15 Feb 2014"
#endif


/*
 * SWI handler code
 * ================
 *
 * swi_offset contains the offset of the SWI into your SWI chunk.
 * r points to the registers passed to the SWI.
 *
 * Return NULL if the SWI is handled successfully; otherwise return
 * a pointer to an error block which describes the error.
 * The veneer code sets the 'V' bit if the returned value is non-NULL.
 * The special value error_BAD_SWI may be returned if you do not
 * implement a SWI; the veneer will arrange for the appropriate
 * standard internationalised error 'SWI value out of range for
 * module Squash' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define Squash_00                       0x042700
#ifndef Squash_Compress
#define Squash_Compress                 0x042700
#define Squash_Decompress               0x042701
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *Squash_swi(int swi_offset, _kernel_swi_regs *r, void *pw);

#endif
