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
/*****************************************************************************
* $Id: module,v 1.13 2016-06-15 19:29:27 jlee Exp $
* $Name: HEAD $
*
* Author(s):  Ben Avison
* Project(s): Rhenium
*
* ----------------------------------------------------------------------------
* Copyright � 2004 Castle Technology Ltd. All rights reserved.
*
* ----------------------------------------------------------------------------
* Purpose: Module entry points and C housekeeping
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include "kernel.h"
#include "swis.h"

#include "Global/NewErrors.h"
#include "Global/RISCOS.h"
#include "Global/Services.h"
#include "Global/OSRSI6.h"
#include "Global/OSMisc.h"
#include "Interface/RTSupport.h"
#include "DebugLib/DebugLib.h"

#include "debug.h"
#include "global.h"
#include "mess.h"
#include "RTSupportHdr.h"
#include "resmess.h"
#include "scheduler.h"


/*****************************************************************************
* Macros
*****************************************************************************/
#define Legacy_IRQsema ((void **)0x108)


/*****************************************************************************
* New type definitions
*****************************************************************************/

typedef struct _svcstack {
  char *ptr;
  struct _svcstack *next;
} svcstack;

/*****************************************************************************
* Constants
*****************************************************************************/
#define PAGE_SIZE 4 /* assume fixed */
#define STACK_SIZE 8
#define ROUTINES 127 /* at least 1024/STACK_SIZE - 1 */
/* There is a minimum setting due to the fact that the dynamic area must be just over 1MB to ensure we have a MB-aligned address */
#define DA_SIZE MAX(1024+STACK_SIZE+PAGE_SIZE, STACK_SIZE+STACK_SIZE+PAGE_SIZE+ROUTINES*STACK_SIZE)

#define EMERGENCY_STACKS 8 /* Keep a minimum of this many stacks allocated but unused, to ensure routines can still be registered even if we can't resize the dynamic area */


/*****************************************************************************
* File scope global variables
*****************************************************************************/
static bool static_OldKernel = false;
static void *static_MessagesBuffer;
static void *static_PriorityMessagesBuffer;
static bool static_UseSparseArea; /* True for sparse DA where SVC stacks are mapped in as-needed, false for regular DA where everything is mapped in all the time */
static uint32_t static_DANumber;
static char *static_DA;
static char *static_DAAllocPtr;
static char *static_RoutineSVCStack;
static char *static_LastStackBeforeMB;
static char *static_LastStackBeforeEnd;
static svcstack static_Stacks[ROUTINES];
static svcstack *static_FreeStacks=0; /* Stacks which aren't allocated */
static svcstack *static_EmergencyStacks=0; /* Spare stacks for when we can't change the dynamic area */
static svcstack *static_ActiveStacks=0; /* Note: don't use this list for enumerating the stack addresses of active threads. This list is only used to collect together 'free' svcstack objects, ready for re-insertion into the FreeStacks or EmergencyStacks lists upon RT_Deregister */
static int static_NumEmergency = 0; /* Number of entries in emergency list */

/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/
static _kernel_oserror *Register(uint32_t flags, const void *entry, uint32_t r0, uint32_t r12,
    volatile const uint32_t *pollword, uint32_t r10, uint32_t r13sys, uint32_t priority, thread_t ** restrict r_handle);
static _kernel_oserror *Deregister(uint32_t flags, thread_t *handle);
static _kernel_oserror *ChangePriority(uint32_t flags, thread_t * restrict handle, uint32_t priority, uint32_t * restrict r_priority);
static _kernel_oserror *ReadInfo(uint32_t reason, uint32_t *r_value);
static _kernel_oserror *RebalanceEmergencyList(void);


/*****************************************************************************
* Functions
*****************************************************************************/

/*****************************************************************************
* module_Initialise
*
* Initialisation code
*
* Assumptions
*  NONE
*
* Inputs
*  cmd_tail:    points to the string of arguments with which the module is invoked
*               (may be "", and is control-terminated, not zero terminated)
*  podule_base: 0              => first invocation, not from a podule
*               1 - 0x02FFFFFF => reincarnation number
*               >0x03000000    => first invocation, from a podule based at this address
*  pw:          the 'R12' value established by module initialisation
*
* Outputs
*  NONE
*
* Returns
*  NULL if initialisation succeeds; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_Initialise(const char *cmd_tail, int podule_base, void *pw)
{
  IGNORE(cmd_tail);
  _kernel_oserror *e = NULL;
#ifndef ROM_MODULE
  bool MessagesFileRegistered = false;
#endif
  bool MessagesOpen = false;
  bool PriorityMessagesOpen = false;
  bool DACreated = false;
  bool OnUnthreadV = false;
  bool OnTickerV = false;

  debug_initialise("RTSupport", "null:", "");
  debug_atexit();
  debug_set_taskname_prefix(false);
  debug_set_area_level_prefix(false);
  debug_set_area_pad_limit(0);
  debug_set_device(DADEBUG_OUTPUT);
  debug_set_raw_device(NULL_OUTPUT);
  debug_set_trace_device(NULL_OUTPUT);

#ifdef DEBUGLIB
  /* Set up the DADWriteC ptr used by the assembler code */
#define DADebug_GetWriteCAddress 0x531C0
  _swix(DADebug_GetWriteCAddress,_OUT(0),&asm_DADWriteC);
#endif

  /* Decide which pre-emption recovery routine to use */
  uint32_t cpuflags;
  if (_swix(OS_PlatformFeatures, _IN(0)|_OUT(0), OSPlatformFeatures_ReadCodeFeatures, &cpuflags) || !(cpuflags & CPUFlag_LoadStoreEx))
  {
    PreEmptionRecoveryPtr = PreEmptionRecovery;
  }
  else
  {
    PreEmptionRecoveryPtr = PreEmptionRecoveryCLREX;
  }

  if (getenv("RTSupport$Path") == NULL)
  {
    #define MY_PATH "Resources:$.Resources.RTSupport."
    _swix(OS_SetVarVal, _INR(0,4), "RTSupport$Path", MY_PATH, sizeof MY_PATH - 1, 0, 4);
  }
  {
#ifndef ROM_MODULE
    e = _swix(ResourceFS_RegisterFiles, _IN(0), resmess_ResourcesFiles());
  }
  if (!e)
  {
    MessagesFileRegistered = true;
#endif

    size_t MessagesSize;
    e = _swix(MessageTrans_FileInfo, _IN(1)|_OUT(2), Module_MessagesFile, &MessagesSize);
    if (!e)
    {
      static_MessagesBuffer = malloc(MessagesSize);
      if (static_MessagesBuffer == NULL)
        e = mess_MakeError(ErrorNumber_RTSupport_AllocFailed, 0);
      else
        /* Keep this cached - important because it may be needed from interrupt context */
        e = _swix(MessageTrans_OpenFile, _INR(0,2), &global_MessageFD, Module_MessagesFile, static_MessagesBuffer);
    }
  }
  if (!e)
  {
    MessagesOpen = true;
    /* Cache all the errors to avoid messagetrans lookups at runtime */
    mess_PrepareErrors(ErrorNumber_RTSupport_PollwordInUse, ErrorNumber_RTSupport_UKFlags, 0, 0);

    size_t PriorityMessagesSize;
    e = _swix(MessageTrans_FileInfo, _IN(1)|_OUT(2), "RTSupport:Priorities", &PriorityMessagesSize);
    if (!e)
    {
      static_PriorityMessagesBuffer = malloc(PriorityMessagesSize);
      if (static_PriorityMessagesBuffer == NULL)
        e = mess_MakeError(ErrorNumber_RTSupport_AllocFailed, 0);
      else
        /* Keep this cached - important because it may be needed from interrupt context */
        e = _swix(MessageTrans_OpenFile, _INR(0,2), &global_PriorityMessageFD, "RTSupport:Priorities", static_PriorityMessagesBuffer);
    }
  }
  if (!e)
  {
    PriorityMessagesOpen = true;

    /* Only a single routine on UnthreadV, please */
    if (((unsigned) podule_base) < 0x03000000 && podule_base != 0)
      e = mess_MakeError(ErrorNumber_RTSupport_DontBeSilly, 0);
  }
  if (!e)
  {
    /* Check CPU architecture version - SYS mode first available in v4 */
    uint32_t ID;
    __asm("MRC p15,0,ID,c0,c0,0");
    if ((ID & 0xF000) == 0 /* pre-ARM7 */ ||
        ((ID & 0xF000) == 0x7000 /* ARM7 */ && (ID & 0x800000) == 0 /* ARM7 v3 not v4T */ ))
      e = mess_MakeError(ErrorNumber_RTSupport_BadOS, 0);
  }
  if (!e)
  {
    /* Find IRQsema */
    if(_swix(OS_ReadSysInfo,_INR(0,2)|_OUT(2),6,0,OSRSI6_IRQsema,&IRQsema))
      IRQsema = Legacy_IRQsema;
    else if(!IRQsema)
      IRQsema = Legacy_IRQsema;
  }
  if (!e)
  {
    /* Check OS is calling UnthreadV, and cache the vector claim address in case we're */
    /* on a broken kernel */
    _swix(OS_Claim, _INR(0,2), UnthreadV, TestUnthreadV, 0);
    uint32_t t0, t1;
    _swix(OS_ReadMonotonicTime, _OUT(0), &t0);
    do
    {
      _swix(OS_ReadMonotonicTime, _OUT(0), &t1);
    }
    while (VectorClaimAddress == 0 && t1 == t0);
    _swix(OS_Release, _INR(0,2), UnthreadV, TestUnthreadV, 0);
    if (VectorClaimAddress == 0)
      e = mess_MakeError(ErrorNumber_RTSupport_BadOS, 0);
  }
  if (!e)
  {
    /* Check for specific kernels with broken implementations of UnthreadV */
    e = _swix(OS_Byte, _INR(0,2), 0, 0, 0);
    if (strstr(e->errmess, "RISC OS 5.07") != NULL)
    {
      /* Simplest for desktop use to pretend that it's not available */
      e = mess_MakeError(ErrorNumber_RTSupport_BadOS, 0);
    }
    else
    {
      if (strstr(e->errmess, "RISC OS-STB 5.0.0") != NULL ||
          strstr(e->errmess, "RISC OS-STB 5.0.1") != NULL)
      {
        /* We'll try to manage without prioritisation for these */
        static_OldKernel = true;
      }
      /* Unfortunately some ROMs (like RISC OS 5.08 and RISC OS-STB 5.0.2) were built without the new SharedCLibrary even though it was available */
      /* See if we can soft-load it instead */
      _kernel_oscli("RMEnsure SharedCLibrary 5.51 RMLoad System:Modules.CLib");
      e = _kernel_oscli("RMEnsure SharedCLibrary 5.51 Error The RTSupport module requires SharedCLibrary 5.51 or later") >= 0 ? NULL : _kernel_last_oserror();
    }
  }
  if (!e)
  {
    /* Check if we're running on a kernel with broken OS_DynamicArea 9/10 error handling */
    int ver;
    e = _swix(OS_Module,_INR(0,2) | _OUT(6),20,0,-1,&ver);
    static_UseSparseArea = (ver >= 0x51500);
  }
  if (!e)
  {
    /* Create the dynamic area to hold the SVC stacks */
    const char *da_name;
    e = mess_LookUpDirect("DA", &da_name, NULL);
    if (!e)
    {
      if(static_UseSparseArea)
        e = _swix(OS_DynamicArea, _INR(0,8)|_OUT(1)|_OUT(3), 0, -1, 0, -1, (1<<7) + (1<<10), DA_SIZE*1024, 0, 0, da_name, &static_DANumber, &static_DA);
      else
        e = _swix(OS_DynamicArea, _INR(0,8)|_OUT(1)|_OUT(3), 0, -1, DA_SIZE*1024, -1, (1<<7), DA_SIZE*1024, 0, 0, da_name, &static_DANumber, &static_DA);
      if (!e)
      {
        DACreated = true;
        static_DAAllocPtr = static_DA - STACK_SIZE*1024; /* start allocating at the base of the DA */
        static_RoutineSVCStack = (char *) (((uint32_t) static_DA + PAGE_SIZE*1024 + 0xFFFFF) & 0xFFF00000) + STACK_SIZE*1024;
        static_LastStackBeforeMB = static_DA + ((static_RoutineSVCStack - static_DA - STACK_SIZE*1024 - PAGE_SIZE*1024) &~ PAGE_SIZE*1024);
        static_LastStackBeforeEnd = static_RoutineSVCStack + PAGE_SIZE*1024 + ((static_DA - static_RoutineSVCStack + DA_SIZE*1024 - PAGE_SIZE*1024) &~ PAGE_SIZE*1024);
        /* Page in the MB-aligned part of the DA */
        if(static_UseSparseArea)
          e = _swix(OS_DynamicArea, _INR(0,3), 9, static_DANumber, static_RoutineSVCStack - STACK_SIZE*1024, STACK_SIZE*1024);
        /* Fill in pointers */
        char *ptr=static_DAAllocPtr;
        for(int i=0;i<ROUTINES;i++)
        {
          ptr += STACK_SIZE*1024;
          if (ptr == static_LastStackBeforeMB) ptr = static_RoutineSVCStack + PAGE_SIZE*1024;
          static_Stacks[i].ptr = ptr;
          static_Stacks[i].next = static_FreeStacks;
          static_FreeStacks = &static_Stacks[i];
        }
        if(static_UseSparseArea)
        {
          /* Allocate the emergency stacks */
          RebalanceEmergencyList();
        }
        else
        {
          /* Keep the code simple by moving everything onto the emergency list */
          static_EmergencyStacks = static_FreeStacks;
          static_FreeStacks = NULL;
          static_NumEmergency = ROUTINES;
        }
      }
    }
  }
  if (!e)
  {

    /* Initialise workspace for scheduler */
    e = _swix(OS_ReadSysInfo, _INR(0,2)|_OUT(2), 6, 0, OSRSI6_Danger_IRQSTK, &IRQStk);
  }
  if (!e)
  {
    strcpy(ErrorBlock_PollwordInUse.errmess, mess_MakeError(ErrorNumber_RTSupport_PollwordInUse, 0)->errmess);
    ThreadTable = malloc(sizeof (*ThreadTable));
    if (ThreadTable == NULL)
      e = mess_MakeError(ErrorNumber_RTSupport_AllocFailed, 0);
  }
  if (!e)
  {
    static thread_t foreground_thread; /* leave initialised to all zeros */
    ThreadTable[0] = &foreground_thread;
    /* Finally, get on applicable vectors */
    e = _swix(OS_Claim, _INR(0,2), UnthreadV, static_OldKernel ? MyUnthreadV_OldKernel : MyUnthreadV, 0);
  }
  if (!e)
  {
    OnUnthreadV = true;
    e = _swix(OS_Claim, _INR(0,2), TickerV, tickerv_veneer, pw);
  }
  if (!e)
  {
    OnTickerV = true;
    e = _swix(OS_Claim, _INR(0,2), SeriousErrorV, asm_seriouserrorv_veneer, pw);
  }

  if (e && OnTickerV) _swix(OS_Release, _INR(0,2), TickerV, tickerv_veneer, pw);
  if (e && OnUnthreadV) _swix(OS_Release, _INR(0,2), UnthreadV, static_OldKernel ? MyUnthreadV_OldKernel : MyUnthreadV, 0);
  if (e && DACreated) _swix(OS_DynamicArea, _INR(0,1), 1, static_DANumber);
  if (e && PriorityMessagesOpen) _swix(MessageTrans_CloseFile, _IN(0), &global_PriorityMessageFD);
  if (e) free(static_PriorityMessagesBuffer);
  if (e && MessagesOpen)
  {
    mess_DiscardErrors();
    _swix(MessageTrans_CloseFile, _IN(0), &global_MessageFD);
  }
  if (e) free(static_MessagesBuffer);
#ifndef ROM_MODULE
  if (e && MessagesFileRegistered) _swix(ResourceFS_DeregisterFiles, _IN(0), resmess_ResourcesFiles());
#endif
  return e;
}

/*****************************************************************************
* module_Finalise
*
* Finalisation code
*
* Assumptions
*  NONE
*
* Inputs
*  fatal, podule, pw: the values of R10, R11 and R12 (respectively) on entry
*                     to the finalisation code
*
* Outputs
*  NONE
*
* Returns
*  NULL if finalisation succeeds; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_Finalise(int fatal, int podule, void *pw)
{
  IGNORE(fatal);
  IGNORE(podule);
  dprintf(("","Finalising\n"));
  _swix(OS_Release, _INR(0,2), SeriousErrorV, asm_seriouserrorv_veneer, pw);
  _swix(OS_Release, _INR(0,2), TickerV, tickerv_veneer, pw);
  _swix(OS_Release, _INR(0,2), UnthreadV, static_OldKernel ? MyUnthreadV_OldKernel : MyUnthreadV, 0);
  _swix(OS_DynamicArea, _INR(0,1), 1, static_DANumber);
  _swix(MessageTrans_CloseFile, _IN(0), &global_PriorityMessageFD);
  free(static_PriorityMessagesBuffer);
  mess_DiscardErrors();
  _swix(MessageTrans_CloseFile, _IN(0), &global_MessageFD);
  free(static_MessagesBuffer);
#ifndef ROM_MODULE
  _swix(ResourceFS_DeregisterFiles, _IN(0), resmess_ResourcesFiles());
#endif
  return NULL;
}

/*****************************************************************************
* module_ServiceHandler
*
* Service call handler
*
* Assumptions
*  NONE
*
* Inputs
*  service_number: service call number
*  r:              pointer to registers on entry
*  pw:             the 'R12' value
*
* Outputs
*  r:              updated or not, as appropriate
*
* Returns
*  NOTHING
*****************************************************************************/
void module_ServiceHandler(int service_number, _kernel_swi_regs *r, void *pw)
{
  IGNORE(pw);
  switch (service_number)
  {
    case Service_Error:
      if (((_kernel_oserror *)(r->r[0]))->errnum & 0x80000000)
      {
        /* Exception or abort error */
        bool irqs_were_disabled = _kernel_irqs_disabled();
        if (!irqs_were_disabled) _kernel_irqs_off();
        dprintf(("","Exception/abort detected, InBackground=%d\n",InBackground));
        if (InBackground) SomethingsGoneWrong();
#ifdef DEBUGLIB
        /* Disable assembler debugging */
        asm_DADWriteC = NULL;
#endif
        if (!irqs_were_disabled) _kernel_irqs_on();
      }
      break;
  }
}

/*****************************************************************************
* module_SWIHandler
*
* SWI handler
*
* Assumptions
*  NONE
*
* Inputs
*  swi_offset: offset into SWI chunk
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_SWIHandler(int swi_offset, _kernel_swi_regs *r, void *pw)
{
  IGNORE(pw);
  _kernel_oserror *e = NULL;
  switch (swi_offset)
  {
    case RT_Register - RT_00:
      e = Register(r->r[0], (const void *) r->r[1], r->r[2], r->r[3], (volatile const uint32_t *) r->r[4], r->r[5], r->r[6], r->r[7], (thread_t **) r->r);
      break;

    case RT_Deregister - RT_00:
      e = Deregister(r->r[0], (thread_t *) r->r[1]);
      break;

    case RT_Yield - RT_00:
      e = Yield(false, (volatile uint32_t *)(r->r[1]), 0) ?
        mess_MakeError(ErrorNumber_RTSupport_CantYield, 0) : NULL;
      break;

    case RT_TimedYield - RT_00:
      e = Yield(true, (volatile uint32_t *)(r->r[1]), r->r[2]) ?
        mess_MakeError(ErrorNumber_RTSupport_CantYield, 0) : NULL;
      break;

    case RT_ChangePriority - RT_00:
      e = ChangePriority(r->r[0], (thread_t *) r->r[1], r->r[2], (uint32_t *) r->r);
      break;

    case RT_ReadInfo - RT_00:
      e = ReadInfo(r->r[0], (uint32_t *) r->r);
      break;

    default:
      e = mess_MakeError(ErrorNumber_RTSupport_UKSWI, 0);
      break;
  }
  if(e)
  {
    dprintf(("","SWI %02x returning with error %x %s\n",swi_offset,e->errnum,e->errmess));
  }
  else
  {
    dprintf(("","SWI %02x OK\n",swi_offset));
  }
  return e; 
}

/*****************************************************************************
* module_TickerVHandler
*
* TickerV handler
*
* Assumptions
*  NONE
*
* Inputs
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_TickerVHandler(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);
  IGNORE(pw);
  /* Interrupts should already be off */
  NTicks++;
  uint32_t time;
  _swix(OS_ReadMonotonicTime, _OUT(0), &time); /* assume no error */
  uint32_t nthreads = NThreads;
  for (thread_t **ptr = (thread_t **) ThreadTable; nthreads-- > 0; ptr++)
  {
    thread_t *thread = *ptr;
    if (thread->timeout_flag && ((signed)(time - thread->timeout)) >= 0)
    {
      dprintf(("","Waking thread %08x from ticker routine\n",thread));
      thread->timeout_flag = false;
      thread->pollword = &Pollword_TimedOut;
    }
  }
  return NULL;
}

/*****************************************************************************
* module_SeriousErrorVHandler
*
* SeriousErrorV handler
*
* Assumptions
*  SeriousErrorV_Recover reason code, IRQs disabled
*
* Inputs
*  r:          register block
*  pw:         the 'R12' value
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
_kernel_oserror *module_SeriousErrorVHandler(_kernel_swi_regs *r, void *pw)
{
  IGNORE(r);
  IGNORE(pw);
  /* The OS has just reset the stacks, and is letting us know about it */
  if (InBackground) SomethingsGoneWrong();
  LastKnownIRQsema = NULL;
#ifdef DEBUGLIB
  /* Disable assembler debugging */
  asm_DADWriteC = NULL;
#endif
  return NULL;
}

/*****************************************************************************
* Register
*
* SWI RT_Register handler
*
* Assumptions
*  NONE
*
* Inputs
*  flags:      not used (r0 on entry)
*  entry:      default entry point
*  r0:         routine r0
*  r12:        routine r12
*  pollword:   default pollword
*  r10:        initial r10 for routine
*  r13sys:     initial r13_sys for routine
*  priority:   initial priority of routine (number or string pointer)
*
* Outputs
*  r_handle:   handle for created routine
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *Register(uint32_t flags, const void *entry, uint32_t r0, uint32_t r12,
    volatile const uint32_t *pollword, uint32_t r10, uint32_t r13sys, uint32_t priority, thread_t ** restrict r_handle)
{
  dprintf(("","RT_Register: flags %08x entry %08x r0 %08x r12 %08x pollword %08x r10 %08x r13sys %08x priority ",flags,entry,r0,r12,pollword,r10,r13sys));
  if(priority < 256u)
    dprintf(("","%d\n",priority));
  else
    dprintf(("","%s\n",(char *) priority));
  if(flags)
  {
    return mess_MakeError(ErrorNumber_RTSupport_UKFlags, 0);
  }
  _kernel_oserror *e = NULL;
  if (priority > 255u)
  {
    const char *result = NULL;
    e = _swix(MessageTrans_Lookup, _INR(0,2)|_OUT(2), &global_PriorityMessageFD, priority, 0, &result);
    if (!e) e = _swix(OS_ReadUnsigned, _INR(0,1)|_OUT(2), 0xC000000A, result, &priority);
  }
  if (e || priority == 0)
  {
    e = mess_MakeError(ErrorNumber_RTSupport_BadPriority, 0);
  }
  else
  {
    bool irqs_were_disabled = _kernel_irqs_disabled();
    if (!irqs_were_disabled) _kernel_irqs_off();
    /* Look for an address to use to store the routine's SVC stack while it is paged out */
    if (!static_EmergencyStacks)
    {
      e = RebalanceEmergencyList();
      if (!static_EmergencyStacks) /* Only fail if we still have 0 stacks - in which case RebalanceEmergenctList() will have returned an error */
      {
        if (!irqs_were_disabled) _kernel_irqs_on();
        return e;
      }
    }
    /* Grab an emergency stack, then rebalance the list
       Keeps all the allocation code in one place! */
    svcstack *stack = static_EmergencyStacks;
    static_EmergencyStacks = stack->next;
    static_NumEmergency--;
    char *ptr = stack->ptr;
    stack->next = static_ActiveStacks;
    static_ActiveStacks = stack;
    RebalanceEmergencyList();
    static_DAAllocPtr = ptr;

    thread_t *new_thread = malloc(sizeof *new_thread);
    bool thread_table_realloc_failed = false;
    if (new_thread != 0 && ThreadTableSize == NThreads)
    {
      size_t new_size = NThreads + 1;
      thread_t **new_table = realloc((void *) ThreadTable, new_size * sizeof *new_table);
      if (new_table == 0) thread_table_realloc_failed = true;
      else
      {
        ThreadTable = new_table;
        ThreadTableSize = new_size;
      }
    }
    if (new_thread == 0 || thread_table_realloc_failed)
    {
      if (!irqs_were_disabled) _kernel_irqs_on();
      free(new_thread);
      e = mess_MakeError(ErrorNumber_RTSupport_AllocFailed, 0);
    }
    else
    {
      dprintf(("","Created thread %08x\n",new_thread));
      *new_thread = (thread_t) {
        .r0 = r0,
        .r12 = r12,
        .svc_stack_base = static_RoutineSVCStack,
        .svc_stack_copy = ptr + STACK_SIZE*1024,
        .default_entry = entry,
        .default_pollword = pollword,
        .priority = priority,
        .entry = entry,
        .psr = 0x11F, /* SYS32 mode with IRQs/FIQs unmasked, then from TakeReset()
                       * in B1.9.1 of DDI0406C: async aborts masked, little endian,
                       * ARM mode, with any N/Z/C/V/Q/GE/IT flags.
                       */
        .pollword = pollword,
        .r13_svc = (uint32_t) static_RoutineSVCStack,
        .r10 = r10,
        .r13_sys = r13sys,
      };
      ThreadTable[NThreads++] = new_thread;
      switch (PriorityTable[priority].usage)
      {
        case 255: /* saturated */ break;
        case 0:
          PriorityTable[priority].last_executed = NThreads - 2; /* start here */
          if (priority != 255)
          {
            uint32_t prev_priority = 255;
            uint32_t next_priority;
            while ((next_priority = PriorityTable[prev_priority].next) > priority)
              prev_priority = next_priority;
            PriorityTable[priority].next = next_priority;
            PriorityTable[prev_priority].next = priority;
          }
          /* drop through... */
        default:
          PriorityTable[priority].usage++;
          break;
      }
      if (*pollword && priority > ThreadTable[Context]->priority)
      {
        /* It needs to pre-empt us already! */
        static const uint32_t set_pollword = -1;
        dprintf(("","RT_Register yielding to new thread %08x\n",new_thread));
        Yield(false, &set_pollword, 0);
        dprintf(("","RT_Register yield complete (thread %08x)\n",new_thread));
      }
      if (!irqs_were_disabled) _kernel_irqs_on();
      *r_handle = new_thread;
    }
  }
  return e;
}

/*****************************************************************************
* Deregister
*
* SWI RT_Deregister handler
*
* Assumptions
*  NONE
*
* Inputs
*  flags:      not used (r0 on entry)
*  handle:     handle for routine
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *Deregister(uint32_t flags, thread_t *handle)
{
  if(flags)
  {
    return mess_MakeError(ErrorNumber_RTSupport_UKFlags, 0);
  }
  _kernel_oserror *e = NULL;
  bool irqs_were_disabled = _kernel_irqs_disabled();
  if (!irqs_were_disabled) _kernel_irqs_off();
  dprintf(("","RT_Deregister: thread %08x\n",handle));
  uint32_t index;
  uint32_t last_index = NThreads;
  for (index = 1; index < last_index; index++)
  {
    if (ThreadTable[index] == handle) break;
  }
  if (index == last_index)
  {
    e = mess_MakeError(ErrorNumber_RTSupport_BadHandle, 0);
  }
  else
  {
    thread_t *thread = ThreadTable[index];
    /* Release the memory for the SVC stack copy */
    /* We push it onto the emergency list, then let RebalanceEmergencyList handle the rest */
    svcstack *stack = static_ActiveStacks;
    static_ActiveStacks = stack->next;
    stack->next = static_EmergencyStacks;
    stack->ptr = ((char *) thread->svc_stack_copy)-STACK_SIZE*1024;
    static_EmergencyStacks = stack;
    static_NumEmergency++;
    RebalanceEmergencyList();
    /* If it was pre-empted, patch up the IRQ stack so no attempt is made to resume it */
    bool stack_frame_needs_poking = false;
    volatile uint32_t * volatile stack_frame;
    dprintf(("","index %d Context %d *IRQsema %08x LastKnownIRQsema %08x\n",index,Context,*IRQsema,LastKnownIRQsema));
    if (thread->pollword == &Pollword_PreEmpted)
    {
      /* Thread was preempted by another thread */
      dprintf(("","Thread was preempted by another thread\n"));
      stack_frame_needs_poking = true;
      stack_frame = thread->stack_frame;
    }
    else if (index == Context && *IRQsema != LastKnownIRQsema)
    {
      /* Thread was only preempted by an IRQ (so this SWI is being called from that IRQ or a nested one) */
      /* We have to find the stack frame manually, because it didn't exist while the thread was executing */
      dprintf(("","Thread was preempted by an IRQ\n"));
      stack_frame = *IRQsema;
      while ((volatile uint32_t *) *stack_frame != LastKnownIRQsema && /* shouldn't happen, except perhaps after abort */ *stack_frame != 0)
      {
        dprintf(("","Skipping stack frame at %08x\n",stack_frame));
        stack_frame = (volatile uint32_t *) *stack_frame;
      }
      if (*stack_frame != NULL)
        stack_frame_needs_poking = true;
    }
    if (stack_frame_needs_poking)
    {
      dprintf(("","Poking stack frame at %08x\n",stack_frame));
      stack_frame[6] = 0x92; /* I32_bit | IRQ32_mode */
      stack_frame[8] = (uint32_t) ThreadResumed;
    }
    /* Sort out the priority table */
    uint32_t priority = thread->priority;
    switch (PriorityTable[priority].usage)
    {
      case 255: /* saturated */ break;
      case 1:
        if (priority != 255)
        {
          uint32_t prev_priority = 255;
          uint32_t next_priority;
          while ((next_priority = PriorityTable[prev_priority].next) > priority)
            prev_priority = next_priority;
          PriorityTable[prev_priority].next = PriorityTable[priority].next;
        }
        /* drop through... */
      default:
        PriorityTable[priority].usage--;
        break;
    }
    /* Shuffle down the later part of the thread table */
    memmove((void *) (ThreadTable + index), (void *) (ThreadTable + index + 1), (--NThreads - index) * sizeof *ThreadTable);
    /* Adjust all references to higher (or same) thread numbers */
    uint32_t original_Context = Context;
    if (original_Context >= index) Context = original_Context - 1;
    for (uint32_t priority = 255; priority != 0; priority = PriorityTable[priority].next)
    {
      if (PriorityTable[priority].last_executed >= index) PriorityTable[priority].last_executed--;
    }
    /* Free the thread structure, and finish with the current execution context if necessary */
    free(thread);
    if (original_Context == index)
    {
      dprintf(("","RT_Deregister exiting via Die() (thread %08x)\n",handle));
      Die();
      dprintf(("","RT_Deregister Die() failed (thread %08x)\n",handle));
    }
  }
  if (!irqs_were_disabled) _kernel_irqs_on();
  return e;
}

/*****************************************************************************
* ChangePriority
*
* SWI RT_ChangePriority handler
*
* Assumptions
*  NONE
*
* Inputs
*  flags:      not used (r0 on entry)
*  handle:     handle for routine
*  priority:   new priority (number or string pointer)
*
* Outputs
*  r_priority: previous priority setting (number)
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *ChangePriority(uint32_t flags, thread_t * restrict handle, uint32_t priority, uint32_t * restrict r_priority)
{
  if(flags)
  {
    return mess_MakeError(ErrorNumber_RTSupport_UKFlags, 0);
  }
  dprintf(("","RT_ChangePriority: handle %08x priority ",handle));
  if(priority < 256u)
    dprintf(("","%d\n",priority));
  else
    dprintf(("","%s\n",(char *) priority));

  _kernel_oserror *e = NULL;
  if (priority > 255u)
  {
    const char *result = NULL;
    e = _swix(MessageTrans_Lookup, _INR(0,2)|_OUT(2), &global_PriorityMessageFD, priority, 0, &result);
    if (!e) e = _swix(OS_ReadUnsigned, _INR(0,1)|_OUT(2), 0xC000000A, result, &priority);
  }
  if (e || (priority == 0 && handle != NULL))
  {
    e = mess_MakeError(ErrorNumber_RTSupport_BadPriority, 0);
  }
  else
  {
    bool irqs_were_disabled = _kernel_irqs_disabled();
    if (!irqs_were_disabled) _kernel_irqs_off();
    uint32_t index;
    uint32_t last_index = NThreads;
    if (handle == NULL)
    {
      handle = ThreadTable[0];
      index = 0;
    }
    else
    {
      for (index = 1; index < last_index; index++)
      {
        if (ThreadTable[index] == handle) break;
      }
    }
    if (index == last_index)
    {
      if (!irqs_were_disabled) _kernel_irqs_on();
      e = mess_MakeError(ErrorNumber_RTSupport_BadHandle, 0);
    }
    else
    {
      if (priority != handle->priority)
      {
        /* Decrement count of threads at old priority */
        switch (PriorityTable[handle->priority].usage)
        {
          case 255: /* saturated */ break;
          case 1:
            if (handle->priority != 255)
            {
              uint32_t prev_priority = 255;
              uint32_t next_priority;
              while ((next_priority = PriorityTable[prev_priority].next) > handle->priority)
                prev_priority = next_priority;
              PriorityTable[prev_priority].next = PriorityTable[handle->priority].next;
            }
            /* drop through... */
          default:
            PriorityTable[handle->priority].usage--;
            break;
        }
        /* Increment count of threads at new priority */
        switch (PriorityTable[priority].usage)
        {
          case 255: /* saturated */ break;
          case 0:
            if (priority != 255)
            {
              uint32_t prev_priority = 255;
              uint32_t next_priority;
              while ((next_priority = PriorityTable[prev_priority].next) > priority)
                prev_priority = next_priority;
              PriorityTable[priority].next = next_priority;
              PriorityTable[prev_priority].next = priority;
            }
            /* drop through... */
          default:
            PriorityTable[priority].usage++;
            break;
        }

        *r_priority = handle->priority;
        handle->priority = priority;
        /* If the routine was set to a higher priority than we are executing at, or if we are demoting ourselves, we need to yield */
        if ((Context != index && priority > Priority && *handle->pollword) ||
            (Context == index && priority < Priority))
        {
          static const uint32_t set_pollword = -1;
          dprintf(("","RT_ChangePriority yielding (%s, thread %08x)\n",(Context==index?"Demoted ourselves":"Promoted pending thread"),handle));
          Yield(false, &set_pollword, 0); /* scope here for a version that only starts scanning at current thread's priority */
          dprintf(("","RT_ChangePriority yield complete (thread %08x)\n",handle));
        }
      }
      if (!irqs_were_disabled) _kernel_irqs_on();
    }
  }
  return e;
}

/*****************************************************************************
* ReadInfo
*
* SWI RT_ReadInfo handler
*
* Assumptions
*  NONE
*
* Inputs
*  reason:     reason code
*
* Outputs
*  r_value:    value to return
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *ReadInfo(uint32_t reason, uint32_t *r_value)
{
  _kernel_oserror *e = NULL;
  switch (reason)
  {
    case RTReadInfo_Handle:
    {
      if (*IRQsema != LastKnownIRQsema)
        *r_value = -1;
      else if (Context == 0)
        *r_value = 0;
      else
      {
        bool irqs_were_disabled = _kernel_irqs_disabled();
        if (!irqs_were_disabled) _kernel_irqs_off();
        *r_value = (uint32_t) ThreadTable[Context];
        if (!irqs_were_disabled) _kernel_irqs_on();
      }
      break;
    }

    case RTReadInfo_Priority:
      if (*IRQsema != LastKnownIRQsema)
        *r_value = -1;
      else
        *r_value = Priority;
      break;

    case RTReadInfo_SVCStk:
      *r_value = (uint32_t) static_RoutineSVCStack;
      break;

    default:
      e = mess_MakeError(ErrorNumber_RTSupport_UKReason, 0);
      break;
  }
  return e;
}

/*****************************************************************************
* RebalanceEmergencyList
*
* Tries to make sure we have exactly EMERGENCY_STACKS in the emergency list
*
* Assumptions
*  Assumes function will not be re-entered
*
* Inputs
*  NONE
*
* Outputs
*  NONE
*
* Returns
*  NULL if successful; otherwise pointer to error block
*****************************************************************************/
static _kernel_oserror *RebalanceEmergencyList(void)
{
  _kernel_oserror *e = NULL;
  svcstack *stack;
  if(!static_UseSparseArea)
  {
    /* Not much to do if we're not using a sparse area */
    if(!static_EmergencyStacks)
      return mess_MakeError(ErrorNumber_RTSupport_Exhausted, 0);
    return NULL;
  }
  while (static_NumEmergency < EMERGENCY_STACKS)
  {
    stack = static_FreeStacks;
    if(!stack)
      return mess_MakeError(ErrorNumber_RTSupport_Exhausted, 0);
    e = _swix(OS_DynamicArea,_INR(0,3),9,static_DANumber,stack->ptr,STACK_SIZE*1024);
    if(e)
      return e; /* Assume that if one alloc fails, all subsequent ones will fail */
    static_FreeStacks = stack->next;
    stack->next = static_EmergencyStacks;
    static_EmergencyStacks = stack;
    static_NumEmergency++;
  }
  while (static_NumEmergency > EMERGENCY_STACKS)
  {
    stack = static_EmergencyStacks;
    e = _swix(OS_DynamicArea,_INR(0,3),10,static_DANumber,stack->ptr,STACK_SIZE*1024);
    if(e)
      return NULL; /* Assume that an error means that no memory was moved. Also, the caller doesn't care about errors when freeing memory, so just return NULL */
    static_EmergencyStacks = stack->next;
    stack->next = static_FreeStacks;
    static_FreeStacks = stack;
    static_NumEmergency--;
  }
  return NULL;    
}

/*****************************************************************************
* END OF FILE
*****************************************************************************/
