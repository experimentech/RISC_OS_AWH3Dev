; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
; 
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
; 
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
; 
;*****************************************************************************
; $Id: scheduler,v 1.9 2016-06-15 19:29:32 jlee Exp $
; $Name: HEAD $
;
; Author(s):  Ben Avison
; Project(s): Rhenium
;
; ----------------------------------------------------------------------------
; Copyright � 2004 Castle Technology Ltd. All rights reserved.
;
; ----------------------------------------------------------------------------
; Purpose: Core scheduling routines
;
; ----------------------------------------------------------------------------
; History: See source control system log
;
;****************************************************************************/


        GBLA    OverloadThreshold
OverloadThreshold SETA 50 ; centiseconds after which to only wake pre-empted threads


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:APCS.<APCS>
        GET     Hdr:FSNumbers ; for NewErrors
        GET     Hdr:NewErrors
        GET     Hdr:UpCall
        GET     Hdr:RTSupport
        GET     Hdr:CPU.Arch
        GET     Hdr:OSMisc

        GET     Hdr:Proc

        [ :LNOT: :DEF: DEBUGLIB
        GBLL    DEBUGLIB
DEBUGLIB SETL   {FALSE}
        ]

        ; IRQ stack frame layout
                        ^       0
ISF_IRQsema             #       4
ISF_R1                  #       4
ISF_R2                  #       4
ISF_R3                  #       4
ISF_R11                 #       4
ISF_R12                 #       4
ISF_CPSR                #       4
ISF_R0                  #       4
ISF_PC                  #       4
ISFSize                 *       :INDEX: @

        ; Per-thread structure, allocated in RMA
                        ^       0
Thread_R0               #       4
Thread_R12              #       4
Thread_SVCStackBase     #       4 ; use 0 for foreground to prevent stack copying
Thread_SVCStackCopy     #       4
Thread_DefaultEntry     #       4
Thread_DefaultPollword  #       4
Thread_Priority         #       4
Thread_Entry            #       4
Thread_PSR              #       4
Thread_Pollword         #       4
Thread_Timeout          #       4
Thread_TimeoutFlag      #       4
Thread_R13SVC           #       4
Thread_R10              #       4
Thread_R13SYS           #       4
Thread_StackFrame       #       4 ; must be adjacent to Thread_RecoveryRegs
Thread_RecoveryRegs     #       7*4 + 1*4 + 7*4 + 1*4
                                ; (ie r4-r10 + r14_svc + 7 stack reserved words + r14_sys)
ThreadSize              *       :INDEX: @

        ; Priority table structure
                        ^       0
Priority_Next           #       1 ; next-lowest priority with non-zero usage count, or 0 if none
Priority_Usage          #       1 ; number of routines using this priority (saturates at 255)
Priority_LastExecuted   #       2 ; most recent thread at this priority
PrioritySize            *       :INDEX: @

        AREA    |RO$$Code|, CODE, READONLY

        ; Some permanently fixed pollwords for special purposes
        EXPORT  Pollword_PreEmpted
Pollword_PreEmpted
        DCD     -1      ; thread has been pre-empted by another
                        ; 1-byte offset from here is used to indicate that this thread is
                        ; currently executing (may be pre-empted by an interrupt routine but
                        ; not yet by another thread)
        EXPORT  Pollword_TimedOut
Pollword_TimedOut
        DCD     -1      ; limiting time has been reached
Pollword_Aborted
        DCD     0       ; an exception prevents this thread from continuing
Pollword_CollateralDamage
        DCD     0       ; had the misfortune to be pre-empted when an exception occurred

        IMPORT  seriouserrorv_veneer
        EXPORT  asm_seriouserrorv_veneer
asm_seriouserrorv_veneer
        ; Pre-veneer for SeriousErrorV
        ; For some reason codes SeriousErrorV will be called in ABT mode, with the SVC stack in an unknown state. Current versions of CMHG can't deal with this (always force a switch to SVC mode), so use this pre-veneer to filter out all except the reason code we're interested in.
        TEQ     r2, #SeriousErrorV_Recover
        BEQ     seriouserrorv_veneer
        MOV     pc, lr

        AREA    |RW$$Code|, CODE ; not READONLY


; Debug code

 [ DEBUGLIB
WriteS  ROUT
        ; r1 = DADWriteC
        ; lr = string ptr
        ; r0, r3 trashable
        MOV     r3, lr
01
        LDRB    r0, [r3], #1
        CMP     r0, #0
        ADR     lr, %BT01
        MOVNE   pc, r1
        ADD     r3, r3, #3
        BIC     pc, r3, #3

WriteHex ROUT
        ; r1 = DADWriteC
        ; r4 = value
        ; r0, r3, r5-r6 trashable
        ADR     r3, %FT02
        MOV     r5, #8
        MOV     r6, lr
01
        LDRB    r0, [r3, r4, LSR #28]
        SUBS    r5, r5, #1
        MOV     r4, r4, LSL #4
        ADR     lr, %BT01
        MOVGE   pc, r1
        MOV     r0, #10
        MOV     lr, r6
        MOV     pc, r1
02
        = "0123456789abcdef"
 ]

        MACRO
        Debug   $str
 [ DEBUGLIB
        Push    "r0-r3,r14"
        LDR     r1, asm_DADWriteC
        MRS     r2, CPSR
        CMP     r1, #0
        BEQ     %FT01
        BL      WriteS
        =       "$str", 10, 0
        ALIGN
01
        MSR     CPSR_f, r2
        Pull    "r0-r3,r14"
 ]
        MEND                

        MACRO
        DebugReg $reg,$str
 [ DEBUGLIB
        Push    "r0-r6,r14"
     [ "$reg" = "r13"
        ADD     r4, r13, #8*4
     |
      [ "$reg" <> "r4"
        MOV     r4, $reg
      ]
     ]
        LDR     r1, asm_DADWriteC
        MRS     r2, CPSR
        CMP     r1, #0
        BEQ     %FT01
     [ "$str" <> ""
        BL      WriteS
        =       "$str", 0
     ]
        BL      WriteHex
01
        MSR     CPSR_f, r2
        Pull    "r0-r6,r14"
 ]
        MEND                

        ; This code has dual purpose: to determine whether UnthreadV is being called on
        ; a given system, and to cache the real vector claim address for the use of the
        ; exit case when the foreground has been resumed and has then yielded (and also
        ; for the pre-veneer required on RISC OS-STB 5.0.0/5.0.1 and RISC OS 5.07).
        EXPORT  VectorClaimAddress ; the one set up by the kernel
VectorClaimAddress
        DCD     0
        EXPORT  TestUnthreadV
TestUnthreadV
        Pull    "lr"
        STR     lr, VectorClaimAddress
        MOV     pc, lr

GetOnUpCallV
        MOV     r0, #1
        STR     r0, InBackground
        ; Save r14_svc across the SWI in case the foreground is at elevated priority and we're
        ; just about to return to it
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Push    "r1-r2,r14_svc"
        MOV     r0, #UpCallV
        ADR     r1, MyUpCallV
        MOV     r2, #0
        SWI     XOS_Claim
        Pull    "r1-r2,r14_svc"
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
        MOV     pc, r14_irq

MyUpCallV
        CMP     r0, #UpCall_SleepNoMore
        ASSERT  UpCall_SleepNoMore > UpCall_Sleep
        TEQNE   r0, #UpCall_Sleep
        MOVNE   pc, r14
        BCS     %F70

60      ; UpCall_Sleep handler
        Push    "r1-r3,r12"
        MOV     r0, #0
        BL      Yield
        MOV     r0, #UpCall_Claimed
        Pull    "r1-r3,r12,pc"

70      ; UpCall_SleepNoMore handler
        Push    "r2-r5,r9"
        MRS     r9, CPSR
        ORR     r2, r9, #I32_bit
        MSR     CPSR_c, r2
        LDR     r2, ThreadTable
        LDR     r3, NThreads
71      LDR     r4, [r2], #4
        LDR     r5, [r4, #Thread_Pollword]
        LDR     r4, [r4, #Thread_DefaultPollword]
        TEQ     r1, r4
        TEQNE   r1, r5
        MSREQ   CPSR_f, #V_bit :OR: Z_bit
        SUBNE   r3, r3, #1
        TEQNE   r3, #0 ; preserves V
        BNE     %B71
        MSR     CPSR_c, r9
        Pull    "r2-r5,r9"
        MOVVC   pc, r14 ; pass on vector, maybe TaskWindow is sleeping on the pollword
        ADRL    r0, ErrorBlock_PollwordInUse
        Pull    "pc" ; claim vector

        EXPORT  Yield
Yield
        ; In SVC mode, use-timeout flag in R0, pollword in R1, timeout in R2
        ; Return false for success (only true if in interrupt context)
        ; APCS calling convention
        FunctionEntry "r4-r9,r11"
        Debug   "Yield"
        DebugReg r0, "timeout flag="
        DebugReg r1, "pollword="
        DebugReg r2, "timeout="
        SUB     r13_svc, r13_svc, #4
        STMIA   r13_svc, {r14_usr}^

        MOV     r14, r13_svc, LSR #20
        MRS     r11, CPSR
        MOV     r14, r14, LSL #20
        LDMIA   r14, {r3-r9}
        Push    "r3-r9,r11" ; save reserved words and original PSR on the SVC stack

        MSR     CPSR_c, #I32_bit :OR: SYS32_mode

        LDR     r12, IRQsema
        LDR     r12, [r12] ; don't dereference this twice in yield case
      [ DEBUGLIB
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        DebugReg r12, "*IRQsema="
        LDR     r4, LastKnownIRQsema
        DebugReg r4, "LastKnownIRQsema="
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode
      ]
        LDR     r14, LastKnownIRQsema
        CMP     r12, #1 ; C clear iff 0
        TEQ     r12, r14
        BHI     %F99 ; must be in interrupt context - return with error
        BLNE    SomethingsGoneWrong
        MOVCC   r9, #0
        STRCC   r9, NTicks ; zero the elapsed time counter
        LDRCS   r9, NTicks

        TEQ     r0, #0
        MOV     r0, #RTExit_Rescan :OR: RTExit_PollwordGiven :OR: RTExit_EntryGiven
        ORRNE   r0, r0, #RTExit_TimeLimitGiven
      [ DEBUGLIB
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Debug   "Yielding"
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode
      ]
        BL      Yielded

        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Pull    "r3-r9,r11"
        MOV     r14, r13_svc, LSR #20
        MSR     CPSR_c, r11 ; restore caller's IRQ disable state
        MOV     r14, r14, LSL #20
        STMIA   r14, {r3-r9} ; replace reserved words

        LDMIA   r13_svc, {r14_usr}^
        MOV     r0, #0
        ADD     r13_svc, r13_svc, #4
        Return  "r4-r9,r11"
99
        MSR     CPSR_c, r11
        Debug   "Can't yield, in IRQ"
        ADD     r13_svc, r13_svc, #8*4 ; Junk reserved words, PSR
        LDMIA   r13_svc, {r14_usr}^
        MOV     r0, #1
        ADD     r13_svc, r13_svc, #4
        Return  "r4-r9,r11"


        EXPORT  Die
Die
        ; In SVC mode IRQs disabled, current thread has been deregistered
        ; Context has been decremented
        ; Only return if in an interrupt routine or in the foreground and didn't know it
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode

        LDR     r12, IRQsema
        LDR     r12, [r12]
        LDR     r3, LastKnownIRQsema
        CMP     r12, #1 ; C clear iff 0
        TEQ     r12, r3
        LDR     r2, Context
        Debug   "Die"
        DebugReg r2, "Context="
        DebugReg r12, "*IRQsema="
        DebugReg r3, "LastKnownIRQsema="
        MOV     r12, #-1
        STR     r12, Context
        BHI     %F99 ; must be in interrupt context
        BNE     %F98 ; IRQ stack has been flattened
        LDR     r12, ThreadTable
        LDR     r9, NTicks
        LDR     r3, Priority
        MOV     r10, r2
        LDR     r11, NThreads
        LDR     r14_irq, =Pollword_PreEmpted
        Debug   "Die OK"
        B       next_thread_no_check
98
        Debug   "Die - SomethingsGoneWrong"
        BL      SomethingsGoneWrong
        ; drop through...
99
        Debug   "Die - Failed, in IRQ?"
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Return  , LinkNotStacked

OldKernelExitVeneer
        ; Undo the IRQ stack fiddling done on entry, remembering that the vector claim
        ; address has already been pulled off the stack. IRQs should be off.
        Pull    "r1-r2"
        LDR     r0, IRQsema
        STR     r2, [r0]
        Push    "r1"
        LDR     pc, VectorClaimAddress

        EXPORT  MyUnthreadV_OldKernel
MyUnthreadV_OldKernel
        ; Patch up the IRQ stack before continuing as for newer kernels
        ; (note that prioritisation won't work correctly on these kernels).
        ; In IRQ mode with IRQs disabled.
        LDR     r0, IRQsema
        ADD     sp_irq, sp_irq, #4 ; we don't want the real vector claim address
        LDR     r2, [r0]
        STR     sp_irq, [r0]
        Pull    "r1"
        ADR     r0, OldKernelExitVeneer
        Push    "r0-r2"
; drop through...

        EXPORT  MyUnthreadV
MyUnthreadV
        ; We never pass this vector on for a good reason:
        ; When we pre-empt another of our own routines, we have to assume that r4-r9,r13_svc,
        ; r13_sys,r14_svc,r14_sys are all still in their original registers.
        ; This means that we cannot tolerate another threading system running concurrently, and
        ; if that is the case, there is no point in passing control along to the next claimant.
        LDR     r12, IRQsema
        LDR     r12, [r12]
        LDR     r14, LastKnownIRQsema
        LDR     r12, [r12, #ISF_IRQsema]
        CMP     r12, #1 ; C clear iff 0
        TEQ     r12, r14 ; Z set iff equal
        Pull    "pc", HI ; must be a nested interrupt - return from vector immediately
        BLNE    SomethingsGoneWrong
        Debug   "MyUnthreadV"
        STR     r9, OriginalR9
        MOVCC   r9, #0
        STRCC   r9, NTicks ; zero the elapsed time counter
        LDRCS   r9, NTicks
full_rescan ; r9 required
        MOV     r3, #255 ; initial priority
        LDR     r11, NThreads
        LDR     r12, ThreadTable
        LDR     r14_irq, =Pollword_PreEmpted
        ADRL    r0, PriorityTable
        LDRB    r2, [r0, #PrioritySize * 255 + Priority_Usage]
        TEQ     r2, #0
        LDREQB  r3, [r0, #PrioritySize * 255 + Priority_Next]
next_priority ; r0,r3,r9,r11-r12,r14 required
        TEQ     r3, #0
        BEQ     return_to_foreground
        ASSERT  PrioritySize = 4
        LDR     r2, [r0, r3, LSL #2]
        ASSERT  Priority_LastExecuted = 2
        MOV     r2, r2, LSR #16 ; thread num: start at last executed thread at this priority
        MOV     r10, r2 ; hang on to this for thread loop termination condition
        LDR     r1, [r12, r2, LSL #2] ; thread structure pointer
        LDR     r0, [r1, #Thread_Pollword]
        BIC     r0, r0, #3           ; treat the executing thread the same as pre-empted ones
        TEQ     r0, r14_irq          ; give all other threads a chance first
        BNE     next_thread_no_check ; unless resuming a pre-empted one
        LDR     r0, [r1, #Thread_Priority]
        TEQ     r0, r3
        BNE     next_thread_no_check
        B       switch_to_thread
next_thread ; r2-r3,r9-r12,r14 required
        TEQ     r2, r10
      [ DEBUGLIB
        ADREQL  r0, PriorityTable
      |
        ADREQ   r0, PriorityTable
      ]
        ASSERT  Priority_Next = 0
        LDREQB  r3, [r0, r3, LSL #2]
        BEQ     next_priority
next_thread_no_check ; r2-r3,r9-r12,r14 required
        ADD     r2, r2, #1
        TEQ     r2, r11
        MOVEQ   r2, #0
        LDR     r1, [r12, r2, LSL #2]
        LDR     r0, [r1, #Thread_Priority]
        TEQ     r0, r3
        BNE     next_thread
        LDR     r0, [r1, #Thread_Pollword]
        CMP     r9, #OverloadThreshold
        BIC     r0, r0, #3  ; treat the executing thread the same as pre-empted ones
                            ; (zero-ness of indirected value is not affected)
        TEQCS   r0, r14_irq
        BHI     next_thread ; threshold reached and not pre-empted
        LDRCC   r0, [r0]
        CMPCC   r0, #1
        BCC     next_thread ; threshold not reached and pollword not set
switch_to_thread ; r1-r3,r12 required
        ; We've found a thread that needs to be executed
        ; Get on UpCallV if necessary
        ; Must be in IRQ mode
        LDR     r0, InBackground
        Debug   "switch_to_thread"
        DebugReg r1,"thread="
        DebugReg r2,"idx="
        DebugReg r0,"InBackground="
        TEQ     r0, #0
        BLEQ    GetOnUpCallV
        ; Is it the same thread we are interrupting?
        LDR     r0, Context
        DebugReg r0,"Context="
        CMP     r0, r2
        LDREQ   r9, OriginalR9
        Pull    "pc", EQ ; can't happen if this was a yield operation, so OK to exit this way
        ; Ensure that all registers we're going to need during or after thread are in
        ; static storage
        ASSERT  PrioritySize = 4
        MOV     r10, r3, LSL #2
        ADRL    r9, PriorityTable+Priority_LastExecuted
      [ :LNOT: NoARMv4
        STRH    r2, [r9, r10]
      |
        STRB    r2, [r9, r10]!
        MOV     r10, r2, LSR #8
        STRB    r10, [r9, #1]
      ]
        STR     r2, Context
        STR     r3, Priority
        LDR     r11, IRQsema
        LDR     r14_irq, [r11]
        MOV     r11, #0
        STR     r14_irq, LastKnownIRQsema
        ; Pre-empt the current thread, if any
        CMP     r0, #-1
        BLNE    PreEmpt
resume_thread
        ; Set up new thread's environment
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode
        ADR     r14_usr, Yielded
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Debug   "resume_thread"
        DebugReg r1, "thread="
        ASSERT  Thread_R0 = 0
        ASSERT  Thread_R12 = 4
        ASSERT  Thread_SVCStackBase = 8
        ASSERT  Thread_SVCStackCopy = 12
        LDMIA   r1, {r0,r2-r4}
        MOV     r12, r2
        ADD     r1, r1, #Thread_Pollword
        LDR     r2, =Pollword_PreEmpted + 1 ; ensure we get reentered after IRQs
        MOV     r5, #0 ; timeout value is not important
        MOV     r6, #0 ; ensure timeout is not used while executing
        ASSERT  Thread_TimeoutFlag = Thread_Pollword + 8
        STMIA   r1!, {r2,r5-r6}
        ASSERT  Thread_R13SVC = Thread_TimeoutFlag + 4
        ASSERT  Thread_R10 = Thread_R13SVC + 4
        ASSERT  Thread_R13SYS = Thread_R13SVC + 8
        LDMIB   r1, {r10,r13_usr}^
        NOP     ; grr
        LDR     r13_svc, [r1], #Thread_Entry - Thread_R13SVC
        CMP     r3, r13_svc
01      LDMHIDB r4!, {r2,r5-r9,r11,r14_svc}
        STMHIDB r3!, {r2,r5-r9,r11,r14_svc}
        CMP     r3, r13_svc
        BHI     %B01
        ASSERT  Thread_PSR = Thread_Entry + 4
        LDMIA   r1, {r1, r2}
        MSR     SPSR_cxsf, r2
        MOV     r11, #0
        MOVS    pc, r1
Yielded
        MRS     r9, CPSR
        ORR     r9, r9, #SYS32_mode ; force next re-entry to be in system mode
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode ; IRQs off before we access volatiles
        LDR     r12, ThreadTable
        LDR     r3, Context
      [ DEBUGLIB
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        Debug   "Yielded"
        DebugReg r3, "Context="
        DebugReg r0, "flags="
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode
      ]
        MOV     r11, #-1
        STR     r11, Context
        LDR     r11, [r12, r3, LSL #2]
        TST     r0, #RTExit_EntryGiven
        MOVNE   r8, r14_usr
        LDREQ   r8, [r11, #Thread_DefaultEntry]
        ADD     r11, r11, #Thread_Entry
        ASSERT  Thread_PSR = Thread_Entry + 4
        STMIA   r11!, {r8-r9}
        TST     r0, #RTExit_PollwordGiven
        LDREQ   r1, [r11, #Thread_DefaultPollword - Thread_Pollword]
        ANDS    r9, r0, #RTExit_TimeLimitGiven
        MOVNE   r9, #1
        ASSERT  Thread_Pollword = Thread_PSR + 4
        ASSERT  Thread_Timeout = Thread_Pollword + 4
        ASSERT  Thread_TimeoutFlag = Thread_Pollword + 8
        STMIA   r11!, {r1-r2,r9}
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        ASSERT  Thread_R13SVC = Thread_TimeoutFlag + 4
        STR     r13_svc, [r11], #4
        ASSERT  Thread_R10 = Thread_R13SVC + 4
        ASSERT  Thread_R13SYS = Thread_R10 + 4
        STMIA   r11, {r10,r13_usr}^
        ADD     r1, r11, #Thread_SVCStackBase - Thread_R10
        ASSERT  Thread_SVCStackCopy = Thread_SVCStackBase + 4
        LDMIA   r1, {r2,r4}
        CMP     r2, r13_svc
01      LDMHIDB r2!, {r5-r11,r14_svc}
        STMHIDB r4!, {r5-r11,r14_svc}
        CMP     r2, r13_svc
        BHI     %B01

        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
        LDR     r9, NTicks
        TST     r0, #RTExit_Rescan
        BNE     full_rescan
        MOV     r2, r3
        LDR     r3, Priority
        MOV     r10, r2
        LDR     r11, NThreads
        LDR     r14_irq, =Pollword_PreEmpted
        B       next_thread_no_check

        ; Static workspace (accessed PC-relative by scheduler)

        EXPORT  ThreadTable
ThreadTable
        DCD     0       ; address of table of pointers to per-thread structures
        EXPORT  ThreadTableSize
ThreadTableSize
        DCD     1       ; size of RMA block in words
        EXPORT  NThreads
NThreads
        DCD     1       ; number of threads in table (including the foreground)
        EXPORT  Context
Context
        DCD     0       ; 0 = foreground, -1 used when nothing pertinent
        EXPORT  InBackground
InBackground
        DCD     0       ; nonzero if we're monitoring UpCall 6 and Service_Error
        EXPORT  NTicks
NTicks
        DCD     0       ; centiseconds since we were entered (for saturation recovery)
        EXPORT  LastKnownIRQsema
LastKnownIRQsema
        DCD     0       ; for distinguishing nested IRQs from interrupted real-time routines
        EXPORT  Priority
Priority
        DCD     0       ; used as a working variable round the outer dispatch loop
OriginalR9
        DCD     0       ; frees up a register for use during thread test
        EXPORT  IRQStk
IRQStk
        DCD     0       ; holds base of IRQ stack
        EXPORT  IRQsema
IRQsema
        DCD     0       ; Pointer to kernel IRQsema val
        EXPORT  PreEmptionRecoveryPtr
PreEmptionRecoveryPtr
        DCD     0       ; Which pre-emption recovery routine to use
 [ DEBUGLIB
        EXPORT  asm_DADWriteC
asm_DADWriteC
        DCD     0       ; DADebug_WriteC ptr

        LTORG
 ]

return_to_foreground
        LDR     r11, Context
        Debug   "return_to_foreground"
        DebugReg r11,"Context="
        CMP     r11, #0 ; it may be that no ready threads were found, so we can exit quickly
        LDREQ   r9, OriginalR9
        Pull    "pc", EQ ; can't happen if this was a yield operation, so OK to exit this way
        LDR     r12, [r12] ; get thread info block for foreground (thread #0)
        ; Get off UpCall 6 and Service_Error (in the case of a foreground yield when no
        ; threads were executed, we won't be on to begin with, but this does no harm)
        MOV     r2, #0
        STR     r2, InBackground
        MOV     r0, #UpCallV
        ADRL    r1, MyUpCallV
        SWI     XOS_Release ; nobody cares if r14_svc is corrupted here!
        STR     r2, Context
        STR     r2, Priority ; foreground should always specify a full rescan, but just in case
        LDR     r13_irq, IRQStk ; flatten stack
        ; The foreground may have been resumed and then yielded.
        LDR     r11, [r12, #Thread_Pollword]
        BIC     r11, r11, #3
        TEQ     r11, r14_irq
        BNE     %F50
        ; Or, the foreground may still be in a pre-empted state,
        ; but it may have been resumed, pre-empted and then demoted, so we may need to
        ; move the stack frame back to the top of the IRQ stack.
        LDR     r0, [r12, #Thread_StackFrame]!
        ADD     r0, r0, #ISFSize
        TEQ     r0, r13_irq
        LDMNEDB r0, {r0-r1,r3-r11} ; copy stack frame plus R10 and vector claim address
        STMNEDB r13_irq, {r0-r1,r3-r11}
        SUB     r13_irq, r13_irq, #ISFSize + 2*4
        STR     r2, [r13_irq, #2*4 + ISF_IRQsema]
        STR     r2, LastKnownIRQsema
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        LDR     r13_svc, [r12, #Thread_R13SVC - Thread_StackFrame]
        ASSERT  Thread_R13SYS = Thread_StackFrame - 4
        LDMDB   r12, {r13_usr}^
        NOP     ; grr
        ASSERT  Thread_RecoveryRegs = Thread_StackFrame + 4
        LDMIB   r12, {r4-r10,r14_svc}
        ADD     r12, r12, #1*4 + 7*4 + 1*4 + 7*4
        LDMIA   r12, {r14_usr}^
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
        STR     r10, [r13_irq, #4]
        Pull    "pc" ; leave the rest of the job up to the kernel

50      ; Return to a yielded foreground.
        ; Since this will be in a privileged mode, there is no need to exit via the
        ; IRQ dispatcher (no system callbacks would be triggered). This is just as well,
        ; since there are no stack frames on the IRQ stack to get its address from!
        LDR     r1, IRQsema
        STR     r2, [r1]
        STR     r2, LastKnownIRQsema
        MOV     r1, r12
        B       resume_thread

PreEmpt
        ; r0 = number of thread being pre-empted
        ; r1 -> thread structure for new thread
        ; r4-r8 = values in use by routine to pre-empt
        ; r11 = 0
        ; r12 = ThreadTable
        ; OriginalR9 and IRQ stack hold routine's R9,R10 respectively
        ; on exit only r1 need be preserved
        ; Must be in IRQ mode
        LDR     r0, [r12, r0, LSL #2]
        ADD     r2, sp_irq, #4*2 ; skip vector return address, routine R10
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode

      [ DEBUGLIB
        Debug   "PreEmpt"
        DebugReg r0, "old="
        DebugReg r1, "new="
        DebugReg r2, "frame="
        Debug   "Regs:"
        LDR     r3, [r2, #ISF_R0]
        DebugReg r3
        LDR     r3, [r2, #ISF_R1]
        DebugReg r3
        LDR     r3, [r2, #ISF_R2]
        DebugReg r3
        LDR     r3, [r2, #ISF_R3]
        DebugReg r3
        DebugReg r4
        DebugReg r5
        DebugReg r6
        DebugReg r7
        DebugReg r8
      ]

        LDR     r3, PreEmptionRecoveryPtr
        MOV     r9, #I32_bit :OR: SVC32_mode
        LDR     r10, =Pollword_PreEmpted
        MOV     r12, #0 ; timeout not valid
        ADD     r0, r0, #Thread_Entry
        ASSERT  Thread_PSR = Thread_Entry + 4
        ASSERT  Thread_Pollword = Thread_Entry + 8
        ASSERT  Thread_Timeout = Thread_Entry + 12
        ASSERT  Thread_TimeoutFlag = Thread_Entry + 16
        ASSERT  Thread_R13SVC = Thread_Entry + 20
        STMIA   r0!, {r3,r9-r13_svc}
        ADD     r10, r0, #ThreadSize - Thread_R10
        ASSERT  Thread_R10 = Thread_Entry + 24
        ASSERT  Thread_R13SYS = Thread_Entry + 28
        STMIA   r0, {r10,r13_usr}^
        ADD     r0, r0, #Thread_StackFrame - Thread_R10
        LDR     r9, OriginalR9
        LDR     r10, [r2, #-4] ; Get routine R10
      [ DEBUGLIB
        DebugReg r9
        DebugReg r10
        LDR     r3, [r2, #ISF_R11]
        DebugReg r3
        LDR     r3, [r2, #ISF_R12]
        DebugReg r3
        DebugReg r13, "r13_svc="
        DebugReg r14, "r14_svc="
        LDR     r3, [r2, #ISF_PC]
        DebugReg r3, "pc="
        LDR     r3, [r2, #ISF_CPSR]
        DebugReg r3, "CPSR="
        LDR     r3, [r0, #Thread_R13SYS-Thread_StackFrame]
        DebugReg r3, "r13_sys="
      ]
        MOV     r3, r13_svc, LSR #20
        ASSERT  Thread_RecoveryRegs = Thread_StackFrame + 4
        STMIA   r0!, {r2,r4-r10,r14_svc}
        MOV     r3, r3, LSL #20
        LDMIA   r3, {r4-r10}
        STMIA   r0, {r4-r10,r14_usr}^
      [ DEBUGLIB
        LDR     r3, [r0, #7*4]
        DebugReg r3, "r14_sys="
      ] 
        ADD     r0, r0, #Thread_SVCStackBase - (Thread_RecoveryRegs + 8*4)
        ASSERT  Thread_SVCStackCopy = Thread_SVCStackBase + 4
        LDMIA   r0, {r0,r12}
        CMP     r0, r13_svc
01      LDMHIDB r0!, {r2-r9}
        STMHIDB r12!, {r2-r9}
        CMP     r0, r13_svc
        BHI     %B01

        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
        MOV     pc, r14_irq

        EXPORT  SomethingsGoneWrong
SomethingsGoneWrong
        ; IRQsema chain has been delinked by someone else - probably an abort handler.
        ; We need to permanently kill any background threads that were executing or are
        ; currently marked as being in a preempted state.
        ; Enter with IRQs disabled, any privileged mode.
        ; Exit with all registers preserved and C clear (ie don't use APCS-R!)
        STR     r9, OriginalR9
        MRS     r9, CPSR
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode ; so we definitely have a stack
        Push    "r2-r8"
        LDR     r2, ThreadTable
        LDR     r3, NThreads
        MOV     r8, #0
        LDR     r4, Context
        Debug   "SomethingsGoneWrong!"
        DebugReg r4, "Context="
        STR     r8, Context
        TEQ     r4, r4, ASR #31 ; 0 (foreground was active) or -1 (nothing was)?
        LDRNE   r4, [r2, r4, LSL #2]
        STRNE   r8, [r4, #Thread_TimeoutFlag]
        LDRNE   r7, =Pollword_Aborted
        STRNE   r7, [r4, #Thread_Pollword] ; ensure this thread is never resumed
        SUBS    r3, r3, #2 ; if CC then also NE
        LDRCS   r6, =Pollword_PreEmpted
        LDRCS   r7, =Pollword_CollateralDamage ; different pollword for debugging purposes
10      LDRCS   r4, [r2, #4]!
        LDRCS   r5, [r4, #Thread_Pollword]
        TEQCS   r5, r6
        STREQ   r8, [r4, #Thread_TimeoutFlag]
        STREQ   r7, [r4, #Thread_Pollword]
        SUBCSS  r3, r3, #1
        BCS     %B10
        ; note that C is clear
        Pull    "r2-r8"
        MSR     CPSR_c, r9
        LDR     r9, OriginalR9
        MOV     pc, r14

        EXPORT  PreEmptionRecoveryCLREX
PreEmptionRecoveryCLREX
        ; Returning to a pre-empted routine, so we need to issue a CLREX
        ; N.B. debug code (when enabled) will ruin this if it does something
        ; which leaves the exclusive monitor in the locked state!
      [ NoARMv6
        ; No action required
      ELIF NoARMK
        ; ARMv6, need dummy STREX
        ; Use the word below SP
        SUB     r1, r13, #4
        STREX   r0, r1, [r1]
      |
        ; ARMv6K+, have CLREX
        CLREX
      ]
        ; Fall through...

        EXPORT  PreEmptionRecovery
PreEmptionRecovery
        ; Enter in SVC mode with interrupts disabled (needs to set up both r14_svc and r14_sys)
        ; with r13_svc and r13_sys already set up and r10 pointing to end of RecoveryRegs
      [ DEBUGLIB
        Debug   "PreEmptionRecovery"
        SUB     r1, r10, #Thread_RecoveryRegs + ?Thread_RecoveryRegs
        DebugReg r1, "thread="
      ]

        ; Restore environment stored in the thread structure
        MOV     r0, r13_svc, LSR #20
        LDMDB   r10, {r1-r7, r14}^ ; get reserved stack words and r14_sys
        MOV     r0, r0, LSL #20
        SUB     r10, r10, #8*4
        STMIA   r0, {r1-r7}        ; set up reserved stack words at base of SVC stack
        LDMDB   r10, {r0, r4-r10, r14_svc} ; load thread r4-r10,r14_svc; point r0 at stack frame
        ASSERT  Thread_StackFrame = Thread_RecoveryRegs - 4

      [ DEBUGLIB
        DebugReg r0, "frame="
        Debug   "Regs:"
        LDR     r3, [r0, #ISF_R0]
        DebugReg r3
        LDR     r3, [r0, #ISF_R1]
        DebugReg r3
        LDR     r3, [r0, #ISF_R2]
        DebugReg r3
        LDR     r3, [r0, #ISF_R3]
        DebugReg r3
        DebugReg r4
        DebugReg r5
        DebugReg r6
        DebugReg r7
        DebugReg r8
        DebugReg r9
        DebugReg r10
        LDR     r3, [r0, #ISF_R11]
        DebugReg r3
        LDR     r3, [r0, #ISF_R12]
        DebugReg r3
        DebugReg r13, "r13_svc="
        DebugReg r14, "r14_svc="
        LDR     r3, [r0, #ISF_PC]
        DebugReg r3, "pc="
      ]        

        ; Get registers from IRQ stack, and patch up IRQ stack to say we've resumed
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode  ; we need a spare register to do the following
        LDR     r1, [r0, #ISF_CPSR]!              ; pull interrupted CPSR from IRQ frame
      [ DEBUGLIB
        DebugReg r1, "CPSR="
        MSR     CPSR_c, #I32_bit :OR: SYS32_mode
        MOV     r2, r13
        MOV     r12, r14
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
        DebugReg r2, "r13_sys="
        DebugReg r12, "r14_sys="
      ]
        MSR     SPSR_cxsf, r1                     ; save in SPSR for now
        LDR     r14_irq, [r0, #ISF_PC - ISF_CPSR] ; pull interrupted PC from IRQ frame
        MOV     r1, #I32_bit :OR: IRQ32_mode
        STR     r1, [r0, #ISF_CPSR - ISF_CPSR]
        ADR     r1, ThreadResumed                 ; also used below
        STR     r1, [r0, #ISF_PC - ISF_CPSR]      ; mark IRQ frame as resumed

        ; Strip as many redundant stack frames from the top of the IRQ stack as possible
        ; to free up space and deal with routines being resumed out-of-order.
        LDR     r12, IRQsema
        LDR     r2, [r12]
        DebugReg r2, "*IRQsema="
        B       %FT02
01      ADD     r13_irq, r2, #ISFSize
        LDR     r2, [r2, #ISF_IRQsema]
        TEQ     r2, #0
        BEQ     %FT03
02      LDR     r11, [r2, #ISF_PC]
        TEQ     r11, r1
        BEQ     %B01
03      STR     r2, [r12]
        STR     r2, LastKnownIRQsema
      [ DEBUGLIB
        MOV     r1, r14
        MOV     r3, r13
        MSR     CPSR_c, #I32_bit :OR: SVC32_mode
        DebugReg r2, "now "
        DebugReg r1, "pc="
        DebugReg r3, "r13_irq="
        MSR     CPSR_c, #I32_bit :OR: IRQ32_mode
      ]
        ; Jump back into interrupted code
        LDMDB   r0, {r1-r3, r11, r12}
        LDR     r0, [r0, #ISF_R0 - ISF_CPSR]
        MOVS    pc, r14_irq

        EXPORT  ThreadResumed
ThreadResumed
        ; Used to reserve a unique PC address to poke into IRQ stack frames that were
        ; pre-empted and have now been resumed, to prevent stack-inspecting routines like
        ; OS_Heap from getting confused if an earlier-preempted routine is resumed before
        ; one that was pre-empted later. Shouldn't normally be executed, but just in case
        ; simply pull the next stack frame off the IRQ stack.

        ; Enter in IRQ mode with interrupts disabled.
        Debug   "ThreadResumed"
        LDR     r11, IRQsema
        LDR     r13, [r11]
        Pull    "r0"
        DebugReg r0, "IRQsema now "
        STR     r0, [r11]
        STR     r0, LastKnownIRQsema
      [ DEBUGLIB
        LDR     r0, [sp, #7*4]
        DebugReg r0, "pc="
      ]
        Pull    "r1-r3, r11, r12, lr"
        MSR     SPSR_cxsf, lr
        Pull    "r0, pc",, ^

        EXPORT  PriorityTable
PriorityTable
        %       256 * PrioritySize

        EXPORT  ErrorBlock_PollwordInUse
ErrorBlock_PollwordInUse
        DCD     ErrorNumber_RTSupport_PollwordInUse
        =       ErrorString_RTSupport_PollwordInUse ; internationalised by C code
        %       ErrorBlock_PollwordInUse + 256 - .

        END
