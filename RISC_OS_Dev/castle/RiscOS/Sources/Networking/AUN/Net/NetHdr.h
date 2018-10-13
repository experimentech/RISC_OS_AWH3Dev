/*
 * Created by cmhg vsn 5.43 [18 Mar 2014]
 */

#ifndef __cmhg_NetHdr_h
#define __cmhg_NetHdr_h

#ifndef __kernel_h
#include "kernel.h"
#endif

#define CMHG_VERSION 543

#define Module_Title                     "Net"
#define Module_Help                      "Net"
#define Module_VersionString             "6.26"
#define Module_VersionNumber             626
#ifndef Module_Date
#define Module_Date                      "26 Jun 2016"
#endif
#define Module_MessagesFile              "Resources:$.Resources.Net.Messages"


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
_kernel_oserror *mns_init(const char *cmd_tail, int podule_base, void *pw);


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
_kernel_oserror *mns_final(int fatal, int podule, void *pw);


/*
 * Service call handler
 * ====================
 *
 * Return values should be poked directly into r->r[n]; the right
 * value/register to use depends on the service number (see the relevant
 * RISC OS Programmer's Reference Manual section for details).
 * pw is the private word (the 'R12' value).
 */
void mns_sc_handler(int service_number, _kernel_swi_regs *r, void *pw);


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

#define CMD_NetMap                      0
#define CMD_Networks                    1
#define CMD_NetStat                     2
#define CMD_NetProbe                    3

_kernel_oserror *mns_cli_handler(const char *arg_string, int argc, int cmd_no, void *pw);


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
 * module Net' to be returned.
 * The handler may update any of its input registers (R0-R9).
 * pw is the private word pointer ('R12') value passed into the
 * SWI handler entry veneer.
 */
#define Econet_00                       0x040000
#ifndef Econet_CreateReceive
#define Econet_CreateReceive            0x040000
#define Econet_ExamineReceive           0x040001
#define Econet_ReadReceive              0x040002
#define Econet_AbandonReceive           0x040003
#define Econet_WaitForReception         0x040004
#define Econet_EnumerateReceive         0x040005
#define Econet_StartTransmit            0x040006
#define Econet_PollTransmit             0x040007
#define Econet_AbandonTransmit          0x040008
#define Econet_DoTransmit               0x040009
#define Econet_ReadLocalStationAndNet   0x04000a
#define Econet_ConvertStatusToString    0x04000b
#define Econet_ConvertStatusToError     0x04000c
#define Econet_ReadProtection           0x04000d
#define Econet_SetProtection            0x04000e
#define Econet_ReadStationNumber        0x04000f
#define Econet_PrintBanner              0x040010
#define Econet_ReadTransportType        0x040011
#define Econet_ReleasePort              0x040012
#define Econet_AllocatePort             0x040013
#define Econet_DeAllocatePort           0x040014
#define Econet_ClaimPort                0x040015
#define Econet_StartImmediate           0x040016
#define Econet_DoImmediate              0x040017
#define Econet_AbandonAndReadReceive    0x040018
#define Econet_Version                  0x040019
#define Econet_NetworkState             0x04001a
#define Econet_PacketSize               0x04001b
#define Econet_ReadTransportName        0x04001c
#define Econet_InetRxDirect             0x04001d
#define Econet_EnumerateMap             0x04001e
#define Econet_EnumerateTransmit        0x04001f
#define Econet_HardwareAddresses        0x040020
#define Econet_NetworkParameters        0x040021
#endif

#define error_BAD_SWI ((_kernel_oserror *) -1)

_kernel_oserror *mns_swi_handler(int swi_offset, _kernel_swi_regs *r, void *pw);


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
extern void callb_entry(void);
extern void tick_entry(void);

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
_kernel_oserror *callb_handler(_kernel_swi_regs *r, void *pw);
_kernel_oserror *tick_handler(_kernel_swi_regs *r, void *pw);


/*
 * Event handler
 * =============
 *
 * This is the name of the event handler entry veneer compiled by CMHG.
 * Use this name as an argument to, for example, SWI OS_Claim, in
 * order to attach your handler to EventV.
 */
extern void mns_event_entry(void);

/*
 * This is the handler function you must write to handle the event for
 * which mns_event_entry is the veneer function.
 *
 * Return 0 if you wish to claim the event.
 * Return 1 if you do not wish to claim the event.
 *
 * 'r' points to a vector of words containing the values of R0-R9 on
 * entry to the veneer. If r is updated, the updated values will be
 * loaded into R0-R9 on return from the handler.
 *
 * pw is the private word pointer ('R12') value with which the event
 * entry veneer is called.
 */
int mns_event_handler(_kernel_swi_regs *r, void *pw);

#endif