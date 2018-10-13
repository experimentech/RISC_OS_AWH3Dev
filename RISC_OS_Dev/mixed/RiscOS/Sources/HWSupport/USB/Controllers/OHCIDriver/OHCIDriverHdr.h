/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_OHCIDriverHdr_h
#define __cmhg_OHCIDriverHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "OHCIDriver"
#define Module_Help                      "OHCIDriver"
#define Module_VersionString             "0.53"
#define Module_VersionNumber             53
#ifndef Module_Date
#define Module_Date                      "27 Jan 2018"
#endif
#define Module_MessagesFile              "Resources:$.Resources.OHCIDriver.Messages"


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
_kernel_oserror *module_init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *module_final(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void module_services(int service_number, _kernel_swi_regs *r, void *pw);


/*
 * Generic veneers
 * ===============
 *
 * This is the name of the generic entry veneer compiled by CMHG.
 * Use this name as an argument to, for example, SWI OS_CallEvery
 * or OS_AddCallBack.
 *
 * These veneers ensure that your handlers preserve R0-R11
 * and the processor flags (unless you return an error pointer.
 * The veneer can be entered in either IRQ or SVC mode. R12 and
 * R14 are corrupted.
 */
extern void callout_entry(void);

/*
 * This is the handler function that the veneer declared above
 * calls.
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
_kernel_oserror *callout_handler(_kernel_swi_regs *r, void *pw);


/*
 * Vector handlers
 * ===============
 *
 * These are the names of the vector handler entry veneers
 * compiled by CMHG. Use these names as an argument to SWI
 * OS_Claim. (EventV claimants should use a CMHG event handler).
 *
 * Note that vector handlers were previously called IRQ handlers
 * and were documented as being for attaching to IrqV. IrqV has
 * long being deprecated; you should use OS_ClaimDeviceVector and
 * a CMHG generic veneer instead.
 */
extern void softintr_entry(void);
extern void usb_overcurrent_entry(void);
extern void usb_irq_entry(void);

/*
 * These are the handler functions you must write to handle the
 * vectors for which softintr_entry, etc. are the veneer functions.
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
int softintr(_kernel_swi_regs *r, void *pw);
int usb_overcurrent_handler(_kernel_swi_regs *r, void *pw);
int usb_irq_handler(_kernel_swi_regs *r, void *pw);

#endif
