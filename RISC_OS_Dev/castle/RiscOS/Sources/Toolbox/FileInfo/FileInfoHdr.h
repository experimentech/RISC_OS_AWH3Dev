/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_FileInfoHdr_h
#define __cmhg_FileInfoHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "FileInfo"
#define Module_Help                      "FileInfo"
#define Module_VersionString             "0.20"
#define Module_VersionNumber             20
#ifndef Module_Date
#define Module_Date                      "18 Aug 2015"
#endif


/*
 * Initialisation code
 * ===================
 *
 * Return NULL if your initialisation succeeds; otherwise return a pointer
 * to an error block. cmd_tail points to the string of arguments with which
 * the module is invoked (may be "", and is control-terminated, not zero
 * terminated).
 * podule_base is 0 unless the code has been invoked from a podule.
 * pw is the 'R12' value established by module initialisation. You may
 * assume nothing about its value (in fact it points to some RMA space
 * claimed and used by the module veneers). All you may do is pass it back
 * for your module veneers via an intermediary such as SWI OS_CallEvery
 * (use _swix() to issue the SWI call).
 */
_kernel_oserror *FileInfo_init(const char *cmd_tail, int podule_base, void *pw);


/*
 * Finalisation code
 * =================
 *
 * Return NULL if your finalisation succeeds. Otherwise return a pointer to
 * an error block if your finalisation handler does not wish to die (e.g.
 * toolbox modules return a 'Task(s) active' error).
 * fatal, podule and pw are the values of R10, R11 and R12 (respectively)
 * on entry to the finalisation code.
 */
_kernel_oserror *FileInfo_finalise(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void FileInfo_services(int service_number, _kernel_swi_regs *r, void *pw);


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
 * module FileInfo' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define FileInfo_00                     0x082ac0
#ifndef FileInfo_ClassSWI
#define FileInfo_ClassSWI               0x082ac0
#define FileInfo_PostFilter             0x082ac1
#define FileInfo_PreFilter              0x082ac2
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *FileInfo_SWI_handler(int swi_offset, _kernel_swi_regs *r, void *pw);

#endif
