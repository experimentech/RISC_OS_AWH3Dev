/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_WindowHdr_h
#define __cmhg_WindowHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "Window"
#define Module_Help                      "Window Object"
#define Module_VersionString             "1.79"
#define Module_VersionNumber             179
#ifndef Module_Date
#define Module_Date                      "21 Mar 2018"
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
_kernel_oserror *Window_init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *Window_final(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void Window_services(int service_number, _kernel_swi_regs *r, void *pw);


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
 * module Window' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define Window_00                       0x082880
#ifndef Window_ClassSWI
#define Window_ClassSWI                 0x082880
#define Window_PostFilter               0x082881
#define Window_PreFilter                0x082882
#define Window_GetPointerInfo           0x082883
#define Window_WimpToToolbox            0x082884
#define Window_RegisterExternal         0x082885
#define Window_DeregisterExternal       0x082886
#define Window_SupportExternal          0x082887
#define Window_RegisterFilter           0x082888
#define Window_DeregisterFilter         0x082889
#define Window_EnumerateGadgets         0x08288a
#define Window_GadgetGetIconList        0x08288b
#define Window_12                       0x08288c
#define Window_13                       0x08288d
#define Window_14                       0x08288e
#define Window_15                       0x08288f
#define Window_16                       0x082890
#define Window_17                       0x082891
#define Window_18                       0x082892
#define Window_19                       0x082893
#define Window_20                       0x082894
#define Window_21                       0x082895
#define Window_22                       0x082896
#define Window_23                       0x082897
#define Window_24                       0x082898
#define Window_25                       0x082899
#define Window_26                       0x08289a
#define Window_27                       0x08289b
#define Window_28                       0x08289c
#define Window_29                       0x08289d
#define Window_30                       0x08289e
#define Window_31                       0x08289f
#define Window_32                       0x0828a0
#define Window_33                       0x0828a1
#define Window_34                       0x0828a2
#define Window_35                       0x0828a3
#define Window_36                       0x0828a4
#define Window_37                       0x0828a5
#define Window_38                       0x0828a6
#define Window_39                       0x0828a7
#define Window_40                       0x0828a8
#define Window_41                       0x0828a9
#define Window_42                       0x0828aa
#define Window_43                       0x0828ab
#define Window_44                       0x0828ac
#define Window_45                       0x0828ad
#define Window_46                       0x0828ae
#define Window_47                       0x0828af
#define Window_48                       0x0828b0
#define Window_49                       0x0828b1
#define Window_50                       0x0828b2
#define Window_51                       0x0828b3
#define Window_52                       0x0828b4
#define Window_53                       0x0828b5
#define Window_54                       0x0828b6
#define Window_55                       0x0828b7
#define Window_56                       0x0828b8
#define Window_57                       0x0828b9
#define Window_58                       0x0828ba
#define Window_59                       0x0828bb
#define Window_60                       0x0828bc
#define Window_61                       0x0828bd
#define Window_ExtractGadgetInfo        0x0828be
#define Window_63                       0x0828bf
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *Window_SWI_handler(int swi_offset, _kernel_swi_regs *r, void *pw);

#endif
