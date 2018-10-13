/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_SDFSHdr_h
#define __cmhg_SDFSHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "SDFS"
#define Module_Help                      "SDFS"
#define Module_VersionString             "0.10"
#define Module_VersionNumber             10
#ifndef Module_Date
#define Module_Date                      "08 Aug 2017"
#endif
#define Module_MessagesFile              "Resources:$.Resources.SDFS.Messages"


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
void module_service(int service_number, _kernel_swi_regs *r, void *pw);


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

#define CMD_SDFS                        0
#define CMD_SDFSdrive                   1

_kernel_oserror *module_command(const char *arg_string, int argc, int cmd_no, void *pw);


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
 * module SDFS' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define SDFS_00                         0x059040
#ifndef SDFS_DiscOp
#define SDFS_DiscOp                     0x059040
#define SDFS_01                         0x059041
#define SDFS_Drives                     0x059042
#define SDFS_FreeSpace                  0x059043
#define SDFS_04                         0x059044
#define SDFS_DescribeDisc               0x059045
#define SDFS_06                         0x059046
#define SDFS_07                         0x059047
#define SDFS_08                         0x059048
#define SDFS_MiscOp                     0x059049
#define SDFS_SectorDiscOp               0x05904a
#define SDFS_FreeSpace64                0x05904b
#define SDFS_DiscOp64                   0x05904c
#define SDFS_13                         0x05904d
#define SDFS_14                         0x05904e
#define SDFS_15                         0x05904f
#define SDFS_16                         0x059050
#define SDFS_17                         0x059051
#define SDFS_18                         0x059052
#define SDFS_19                         0x059053
#define SDFS_20                         0x059054
#define SDFS_21                         0x059055
#define SDFS_22                         0x059056
#define SDFS_23                         0x059057
#define SDFS_24                         0x059058
#define SDFS_25                         0x059059
#define SDFS_26                         0x05905a
#define SDFS_27                         0x05905b
#define SDFS_28                         0x05905c
#define SDFS_29                         0x05905d
#define SDFS_30                         0x05905e
#define SDFS_31                         0x05905f
#define SDFS_ReadCardInfo               0x059060
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *module_swi(int swi_offset, _kernel_swi_regs *r, void *pw);


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
extern void module_miscop_veneer(void);
extern void module_discop_veneer(void);

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
_kernel_oserror *module_miscop_handler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_discop_handler(_kernel_swi_regs *r, void *pw);


/*
 * Vector handlers
 * ===============
 *
 * This is the name of the vector handler entry veneer
 * compiled by CMHG. Use this name as an argument to SWI
 * OS_Claim. (EventV claimants should use a CMHG event handler).
 *
 * Note that vector handlers were previously called IRQ handlers
 * and were documented as being for attaching to IrqV. IrqV has
 * long being deprecated; you should use OS_ClaimDeviceVector and
 * a CMHG generic veneer instead.
 */
extern void module_tickerv_veneer(void);

/*
 * This is the handler function you must write to handle the
 * vector for which module_tickerv_veneer is the veneer function.
 *
 * If a handler function is installed onto a vector, then:
 *   Return 0 to intercept the call.
 *   Return 1 to pass on the call.
 * If you use a vector handler veneer for any other purpose, always
 * return non-0, and consider the use of a generic veneer instead.
 * It is not currently possible to return an error from a vector
 * handler.
 *
 * 'r' points to a vector of words containing the values of R0-R9 on
 * entry to the veneer. If r is updated, the updated values will be
 * loaded into R0-R9 on return from the handler.
 *
 * pw is the private word pointer ('R12') value with which the
 * vector entry veneer is called.
 */
int module_tickerv_handler(_kernel_swi_regs *r, void *pw);

#endif
