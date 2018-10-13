/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_modhdr_h
#define __cmhg_modhdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "SCSISoftUSB"
#define Module_Help                      "SCSISoftUSB"
#define Module_VersionString             "0.21"
#define Module_VersionNumber             21
#ifndef Module_Date
#define Module_Date                      "10 Mar 2016"
#endif
#define Module_MessagesFile              "Resources:$.Resources.SCSISoftUSB.Messages"


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
_kernel_oserror *module_Init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *module_Final(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void module_Service(int service_number, _kernel_swi_regs *r, void *pw);


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

#define CMD_SCSISoftUSB_PopUpDelay      0

_kernel_oserror *module_Commands(const char *arg_string, int argc, int cmd_no, void *pw);


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
extern void module_scsiregister_cb_handler(void);
extern void module_scsiregister_handler(void);
extern void module_upcallv_handler(void);
extern void module_tickerv_handler(void);
extern void module_scsi_handler(void);
extern void module_callback_from_init(void);

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
_kernel_oserror *module_SCSIRegister_cb(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_SCSIRegister(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_UpCallVHandler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_TickerVHandler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_SCSIHandler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *module_CallbackFromInit(_kernel_swi_regs *r, void *pw);

#endif
