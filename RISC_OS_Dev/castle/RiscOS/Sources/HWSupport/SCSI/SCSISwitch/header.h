/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_header_h
#define __cmhg_header_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "SCSIDriver"
#define Module_Help                      "SCSIDriver"
#define Module_VersionString             "2.14"
#define Module_VersionNumber             214
#ifndef Module_Date
#define Module_Date                      "11 Jan 2018"
#endif
#define Module_MessagesFile              "Resources:$.Resources.SCSIDriver.Messages"


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
_kernel_oserror *module_initialise(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *module_finalise(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void module_service_handler(int service_number, _kernel_swi_regs *r, void *pw);


/*
 * Command handler
 * ===============
 *
 * If cmd_no identifies a command, then arg_string gives the command tail
 * (which you may not overwrite), and argc is the number of parameters.
 * NB. arg_string is control terminated so it may not be a C string.
 * Return NULL if the command has been successfully handled; otherwise
 * return a pointer to an error block describing the failure (in this
 * case, the veneer code will set the 'V' bit).
 *
 * If cmd_no identifies a *Help entry, then arg_string denotes a buffer
 * that you can assemble your output into, and argc is the length of the
 * buffer, in bytes. cmd_handler must return NULL, an error pointer or
 * help_PRINT_BUFFER (if help_PRINT_BUFFER is returned, the zero-
 * terminated buffer will be printed).
 *
 * If cmd_no identifies a *Configure option, then arg_string may contain
 * one of the two special values arg_CONFIGURE_SYNTAX or arg_STATUS;
 * otherwise it points at the command tail, with leading spaces skipped.
 * If arg_string is set to arg_CONFIGURE_SYNTAX, the user has typed
 * *Configure with no parameter; simply print your syntax string. If
 * arg_string is set to arg_STATUS, print your current configured status.
 * Otherwise, the user has typed *Configure with one or more parameters
 * as described in the command tail. The parameter argc contains an
 * undefined value in all three cases. Return NULL, an error pointer, or
 * one of the four special values defined below.
 *
 * pw is the private word pointer ('R12') value passed into the entry
 * veneer
 */
#define help_PRINT_BUFFER         ((_kernel_oserror *) arg_string)
#define arg_CONFIGURE_SYNTAX      ((char *) 0)
#define arg_STATUS                ((char *) 1)
#define configure_BAD_OPTION      ((_kernel_oserror *) -1)
#define configure_NUMBER_NEEDED   ((_kernel_oserror *) 1)
#define configure_TOO_LARGE       ((_kernel_oserror *) 2)
#define configure_TOO_MANY_PARAMS ((_kernel_oserror *) 3)

#define CMD_SCSIDevices                 0

_kernel_oserror *module_cmd_handler(const char *arg_string, int argc, int cmd_no, void *pw);


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
 * module SCSIDriver' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define SCSI_00                         0x0403c0
#ifndef SCSI_Version
#define SCSI_Version                    0x0403c0
#define SCSI_Initialise                 0x0403c1
#define SCSI_Control                    0x0403c2
#define SCSI_Op                         0x0403c3
#define SCSI_Status                     0x0403c4
#define SCSI_5                          0x0403c5
#define SCSI_6                          0x0403c6
#define SCSI_Reserve                    0x0403c7
#define SCSI_List                       0x0403c8
#define SCSI_9                          0x0403c9
#define SCSI_10                         0x0403ca
#define SCSI_11                         0x0403cb
#define SCSI_12                         0x0403cc
#define SCSI_13                         0x0403cd
#define SCSI_14                         0x0403ce
#define SCSI_15                         0x0403cf
#define SCSI_16                         0x0403d0
#define SCSI_17                         0x0403d1
#define SCSI_18                         0x0403d2
#define SCSI_19                         0x0403d3
#define SCSI_20                         0x0403d4
#define SCSI_21                         0x0403d5
#define SCSI_22                         0x0403d6
#define SCSI_23                         0x0403d7
#define SCSI_24                         0x0403d8
#define SCSI_25                         0x0403d9
#define SCSI_26                         0x0403da
#define SCSI_27                         0x0403db
#define SCSI_28                         0x0403dc
#define SCSI_29                         0x0403dd
#define SCSI_30                         0x0403de
#define SCSI_31                         0x0403df
#define SCSI_32                         0x0403e0
#define SCSI_33                         0x0403e1
#define SCSI_34                         0x0403e2
#define SCSI_35                         0x0403e3
#define SCSI_36                         0x0403e4
#define SCSI_37                         0x0403e5
#define SCSI_38                         0x0403e6
#define SCSI_39                         0x0403e7
#define SCSI_40                         0x0403e8
#define SCSI_41                         0x0403e9
#define SCSI_42                         0x0403ea
#define SCSI_43                         0x0403eb
#define SCSI_44                         0x0403ec
#define SCSI_45                         0x0403ed
#define SCSI_46                         0x0403ee
#define SCSI_47                         0x0403ef
#define SCSI_48                         0x0403f0
#define SCSI_49                         0x0403f1
#define SCSI_50                         0x0403f2
#define SCSI_51                         0x0403f3
#define SCSI_52                         0x0403f4
#define SCSI_53                         0x0403f5
#define SCSI_54                         0x0403f6
#define SCSI_55                         0x0403f7
#define SCSI_56                         0x0403f8
#define SCSI_57                         0x0403f9
#define SCSI_58                         0x0403fa
#define SCSI_59                         0x0403fb
#define SCSI_60                         0x0403fc
#define SCSI_61                         0x0403fd
#define SCSI_Deregister                 0x0403fe
#define SCSI_Register                   0x0403ff
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *module_swi_handler(int swi_offset, _kernel_swi_regs *r, void *pw);


/*
 * Generic veneers
 * ===============
 *
 * These are the names of the generic entry veneers compiled by CMHG.
 * Use these names as an argument to, for example, SWI OS_CallEvery
 * or OS_AddCallBack.
 *
 * These veneers ensure that your handlers preserve R0-R11
 * and the processor flags (unless you return an error pointer.
 * The veneer can be entered in either IRQ or SVC mode. R12 and
 * R14 are corrupted.
 */
extern void driver_error_entry(void);
extern void driver_callback_entry(void);

/*
 * These are the handler functions that the veneers declared above
 * call.
 *
 * For a standard exit, return NULL. For handlers that can return an
 * error, return an error block pointer, and the veneer will set the
 * 'V' bit, and set R0 to the error pointer.
 *
 * 'r' points to a vector of words containing the values of R0-R9 on
 * entry to the veneer. If r is updated, the updated values will be
 * loaded into R0-R9 on return from the handler.
 *
 * pw is the private word pointer ('R12') value with which the
 * entry veneer is called.
 */
_kernel_oserror *driver_error_handler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *driver_callback_handler(_kernel_swi_regs *r, void *pw);

#endif
