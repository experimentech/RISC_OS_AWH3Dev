/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_ToolboxHdr_h
#define __cmhg_ToolboxHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "Toolbox"
#define Module_Help                      "Toolbox"
#define Module_VersionString             "1.58"
#define Module_VersionNumber             158
#ifndef Module_Date
#define Module_Date                      "11 Feb 2018"
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
_kernel_oserror *Toolbox_init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *Toolbox_finalise(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void Toolbox_services(int service_number, _kernel_swi_regs *r, void *pw);


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
 * module Toolbox' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define Toolbox_00                      0x044ec0
#ifndef Toolbox_CreateObject
#define Toolbox_CreateObject            0x044ec0
#define Toolbox_DeleteObject            0x044ec1
#define Toolbox_CopyObject              0x044ec2
#define Toolbox_ShowObject              0x044ec3
#define Toolbox_HideObject              0x044ec4
#define Toolbox_GetObjectInfo           0x044ec5
#define Toolbox_ObjectMiscOp            0x044ec6
#define Toolbox_SetClientHandle         0x044ec7
#define Toolbox_GetClientHandle         0x044ec8
#define Toolbox_GetObjectClass          0x044ec9
#define Toolbox_GetParent               0x044eca
#define Toolbox_GetAncestor             0x044ecb
#define Toolbox_GetTemplateName         0x044ecc
#define Toolbox_RaiseToolboxEvent       0x044ecd
#define Toolbox_GetSysInfo              0x044ece
#define Toolbox_Initialise              0x044ecf
#define Toolbox_LoadResources           0x044ed0
#define Toolbox_NULL                    0x044ed1
#define Toolbox_NULL                    0x044ed2
#define Toolbox_NULL                    0x044ed3
#define Toolbox_NULL                    0x044ed4
#define Toolbox_NULL                    0x044ed5
#define Toolbox_NULL                    0x044ed6
#define Toolbox_NULL                    0x044ed7
#define Toolbox_NULL                    0x044ed8
#define Toolbox_NULL                    0x044ed9
#define Toolbox_NULL                    0x044eda
#define Toolbox_NULL                    0x044edb
#define Toolbox_NULL                    0x044edc
#define Toolbox_NULL                    0x044edd
#define Toolbox_NULL                    0x044ede
#define Toolbox_NULL                    0x044edf
#define Toolbox_NULL                    0x044ee0
#define Toolbox_NULL                    0x044ee1
#define Toolbox_NULL                    0x044ee2
#define Toolbox_NULL                    0x044ee3
#define Toolbox_NULL                    0x044ee4
#define Toolbox_NULL                    0x044ee5
#define Toolbox_NULL                    0x044ee6
#define Toolbox_NULL                    0x044ee7
#define Toolbox_NULL                    0x044ee8
#define Toolbox_NULL                    0x044ee9
#define Toolbox_NULL                    0x044eea
#define Toolbox_NULL                    0x044eeb
#define Toolbox_NULL                    0x044eec
#define Toolbox_NULL                    0x044eed
#define Toolbox_NULL                    0x044eee
#define Toolbox_NULL                    0x044eef
#define Toolbox_NULL                    0x044ef0
#define Toolbox_NULL                    0x044ef1
#define Toolbox_NULL                    0x044ef2
#define Toolbox_NULL                    0x044ef3
#define Toolbox_NULL                    0x044ef4
#define Toolbox_NULL                    0x044ef5
#define Toolbox_NULL                    0x044ef6
#define Toolbox_NULL                    0x044ef7
#define Toolbox_NULL                    0x044ef8
#define Toolbox_Memory                  0x044ef9
#define Toolbox_DeRegisterObjectModule  0x044efa
#define Toolbox_TemplateLookUp          0x044efb
#define Toolbox_GetInternalHandle       0x044efc
#define Toolbox_RegisterPostFilter      0x044efd
#define Toolbox_RegisterPreFilter       0x044efe
#define Toolbox_RegisterObjectModule    0x044eff
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *Toolbox_SWI_handler(int swi_offset, _kernel_swi_regs *r, void *pw);

#endif
