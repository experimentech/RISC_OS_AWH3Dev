/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_TextGadgetHdr_h
#define __cmhg_TextGadgetHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "TextGadgets"
#define Module_Help                      "TextGadgets"
#define Module_VersionString             "0.44"
#define Module_VersionNumber             44
#ifndef Module_Date
#define Module_Date                      "09 Feb 2018"
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
_kernel_oserror *TextGadgets_init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *TextGadgets_final(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void TextGadgets_services(int service_number, _kernel_swi_regs *r, void *pw);


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
 * module TextGadgets' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define TextGadgets_00                  0x140180
#ifndef TextGadgets_TextArea
#define TextGadgets_TextArea            0x140180
#define TextGadgets_TextField           0x140181
#define TextGadgets_ScrollList          0x140182
#define TextGadgets_Scrollbar           0x140183
#define TextGadgets_RedrawAll           0x140184
#define TextGadgets_Filter              0x140185
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *TextGadgets_SWI_handler(int swi_offset, _kernel_swi_regs *r, void *pw);

#endif
