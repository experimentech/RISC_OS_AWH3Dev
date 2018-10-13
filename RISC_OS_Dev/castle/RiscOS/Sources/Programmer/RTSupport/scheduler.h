/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
#if !defined(RTSUPPORT_SCHEDULER_H) /* file used if not already included */
#define RTSUPPORT_SCHEDULER_H
/*****************************************************************************
* $Id: scheduler,v 1.5 2016-06-15 19:29:30 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Rhenium
*
* ----------------------------------------------------------------------------
* Copyright © 2004 Castle Technology Ltd. All rights reserved.
*
* ----------------------------------------------------------------------------
* Purpose: Core scheduling routines
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdbool.h>
#include <stdint.h>
#include "kernel.h"


/*****************************************************************************
* Macros
*****************************************************************************/


/*****************************************************************************
* New type definitions
*****************************************************************************/
typedef struct
{
  uint32_t r0;
  uint32_t r12;
  volatile char *svc_stack_base;
  volatile char *svc_stack_copy;
  const void *default_entry;
  volatile const uint32_t *default_pollword;
  volatile uint32_t priority;
  const void * volatile entry;
  volatile const uint32_t psr;
  volatile const uint32_t * volatile pollword;
  volatile uint32_t timeout;
  volatile bool timeout_flag;
  volatile uint32_t r13_svc;
  volatile uint32_t r10;
  volatile uint32_t r13_sys;
  volatile uint32_t * volatile stack_frame;
  volatile uint32_t recovery_regs[16];
}
thread_t;

typedef __packed volatile struct
{
  uint8_t next;
  uint8_t usage;
  uint16_t last_executed;
}
priority_t;


/*****************************************************************************
* Constants
*****************************************************************************/

/* The following have to be declared as code so that the compiler does not */
/* attempt to relocate them. */
extern void Pollword_PreEmpted(void);
#define Pollword_PreEmpted (*(const uint32_t *) Pollword_PreEmpted)
extern void Pollword_TimedOut(void);
#define Pollword_TimedOut (*(const uint32_t *) Pollword_TimedOut)


/*****************************************************************************
* Global variables
*****************************************************************************/
extern thread_t * volatile * volatile ThreadTable;
extern volatile size_t ThreadTableSize;
extern volatile size_t NThreads;
extern volatile uint32_t Context;
extern volatile bool InBackground;
extern volatile uint32_t NTicks;
extern volatile void *LastKnownIRQsema;
extern volatile uint32_t Priority;
extern void **IRQsema;
extern void *IRQStk;
extern void *PreEmptionRecoveryPtr;
extern const void * const volatile VectorClaimAddress;
extern priority_t PriorityTable[256];
extern _kernel_oserror ErrorBlock_PollwordInUse;

#ifdef DEBUGLIB
extern uint32_t asm_DADWriteC;
#endif


/*****************************************************************************
* Function prototypes
*****************************************************************************/

/* The following have to be declared as data although they are really code */
/* in order to persuade the compiler to relocate them. They could arguably */
/* be declared as const since the compiler will relocate const data with */
/* external linkage for backwards compatibility, but that might change in */
/* the future. */
/* Routines with APCS calling conditions are prototyped in comments. */

extern uint32_t TestUnthreadV[];
extern uint32_t Yield[];
#define Yield(timed,pollword,timeout) \
  ((*(bool (*)(bool, volatile const uint32_t *, uint32_t)) Yield)(timed, pollword, timeout))
/* extern bool Yield(bool timed, volatile const uint32_t *pollword, uint32_t timeout); */
extern uint32_t Die[];
#define Die (*(void (*)(void)) Die)
/* extern void Die(void); */
extern uint32_t MyUnthreadV_OldKernel[];
extern uint32_t MyUnthreadV[];
extern uint32_t SomethingsGoneWrong[];
#define SomethingsGoneWrong (*(void (*)(void)) SomethingsGoneWrong)
/* extern void SomethingsGoneWrong(void); */
extern uint32_t PreEmptionRecoveryCLREX[];
extern uint32_t PreEmptionRecovery[];
extern uint32_t ThreadResumed[];


#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
