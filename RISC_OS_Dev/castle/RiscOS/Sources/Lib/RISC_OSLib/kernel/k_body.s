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
; -*- Mode: Assembler -*-
;* Body of shared library kernel for Arthur/Brazil
;* Lastedit: 13 Dec 90 14:39:20 by Harry Meekings *
;
; Copyright (C) Acorn Computers Ltd., 1988.
;
; 23-Sep-94 AMcC  __rt_ symbols defined and exported (compatible with cc vsn 5 etc)
;

        GET     h_stack.s
        GET     h_workspc.s
        GET     h_common.s
        GET     Hdr:OSMisc

        EXPORT  |_kernel_exit|
        EXPORT  |_kernel_setreturncode|
        EXPORT  |_kernel_exittraphandler|
        EXPORT  |_kernel_unwind|
        EXPORT  |_kernel_procname|
        EXPORT  |_kernel_language|

        EXPORT  |_kernel_command_string|
        EXPORT  |_kernel_hostos|
        EXPORT  |_kernel_swi|
        EXPORT  |_kernel_swi_c|
        EXPORT  |_kernel_osbyte|
        EXPORT  |_kernel_osrdch|
        EXPORT  |_kernel_oswrch|
        EXPORT  |_kernel_osbget|
        EXPORT  |_kernel_osbput|
        EXPORT  |_kernel_osgbpb|
        EXPORT  |_kernel_osword|
        EXPORT  |_kernel_osfind|
        EXPORT  |_kernel_osfile|
        EXPORT  |_kernel_osargs|
        EXPORT  |_kernel_oscli|
        EXPORT  |_kernel_last_oserror|
        EXPORT  |_kernel_peek_last_oserror|
        EXPORT  |_kernel_system|
        EXPORT  |_kernel_getenv|
        EXPORT  |_kernel_setenv|

        EXPORT  |_kernel_register_allocs|
        EXPORT  |_kernel_register_slotextend|
        EXPORT  |_kernel_alloc|
        EXPORT  |__rt_allocauto|
        EXPORT  |__rt_freeauto|

        EXPORT  |_kernel_current_stack_chunk|
        EXPORT  |_kernel_stkovf_split_0frame|
        EXPORT  |_kernel_stkovf_split|
        EXPORT  |_kernel_stkovf_copyargs|
        EXPORT  |_kernel_stkovf_copy0args|

        EXPORT  |_kernel_udiv|
        EXPORT  |_kernel_urem|
        EXPORT  |_kernel_udiv10|
        EXPORT  |_kernel_sdiv|
        EXPORT  |_kernel_srem|
        EXPORT  |_kernel_sdiv10|

        EXPORT  |_kernel_escape_seen|
        EXPORT  |_kernel_init|
        EXPORT  |_kernel_client_is_module|
 [ ModeMayBeNonUser
        EXPORT  |_kernel_entermodule|
        EXPORT  |_kernel_moduleinit|
        EXPORT  |_kernel_irqs_on|
        EXPORT  |_kernel_irqs_off|
 ]
        EXPORT  |_kernel_irqs_disabled|
        EXPORT  |_kernel_processor_mode|
        EXPORT  |_kernel_RMAalloc|
        EXPORT  |_kernel_RMAfree|
        EXPORT  |_kernel_RMAextend|

        EXPORT  |_kernel_fpavailable|

        EXPORT  |_kernel_call_client|
        EXPORT  |_kernel_raise_error|

        EXPORT  |__rt_sdiv|
        EXPORT  |__rt_udiv|
        EXPORT  |__rt_udiv10|
        EXPORT  |__rt_sdiv10|

        EXPORT  |x$divide|
        EXPORT  |x$udivide|
        EXPORT  |x$remainder|
        EXPORT  |x$uremainder|

        EXPORT  |__counter|
 [ {CONFIG}<>26
        EXPORT  |AcquireMutex|
 ]

PSRBits         *       &FC000003
PSRZBit         *       &40000000
PSRVBit         *       &10000000

PSRIBit         *       &08000000
PSRFBit         *       &04000000
PSRMode         *       &00000003
PSRUSRMode      *       &00000000
PSRSVCMode      *       &00000003
PSRPrivileged   *       &00000003

PSR32IBit       *       &00000080
PSR32FBit       *       &00000040
PSR32Mode       *       &0000001F
PSR32USRMode    *       &00000010
PSR32SVCMode    *       &00000013
PSR32UNDMode    *       &0000001B
PSR32Privileged *       &0000000F


; A RTS$$Data area
                ^       0
lang_size       #       4
lang_codeBase   #       4
lang_codeLimit  #       4
lang_name       #       4
lang_Init       #       4
lang_Finalise   #       4
lang_Trap       #       4
lang_UncaughtTrap #     4
lang_Event      #       4
lang_UnhandledEvent #   4
lang_FastEvent  #       4
lang_Unwind     #       4
lang_ProcName   #       4

; a _kernel_unwindblock
                ^       0
uwb_r4          #       4
uwb_r5          #       4
uwb_r6          #       4
uwb_r7          #       4
uwb_r8          #       4
uwb_r9          #       4
uwb_fp          #       4
uwb_sp          #       4
uwb_pc          #       4
uwb_sl          #       4
uwb_f4          #       3*4
uwb_f5          #       3*4
uwb_f6          #       3*4
uwb_f7          #       3*4
uwb_size        #       0


        GET     Hdr:Wimp
 [ DDE
        GET     Hdr:DDEUtils
 ]
        GET     Hdr:Machine.<Machine>


        MACRO
        CallClient $r
        ; Always called with v6 = the kernel static base.
        ; If shared library, used to worry about calling standard change.
        MOV     lr, pc
        MOV     pc, $r
        MEND


|_kernel_call_client|
 [ :LNOT:(SharedLibrary :LAND: {CONFIG}=26)
        MOV     pc, a4
   |
  ; If we're 26-bit and a shared library, we need to cope with APCS-32
  ; clients not preserving flags
        FunctionEntry
        MOV     lr, pc
        MOV     pc, a4
        Return
 ]


 [ ModeMayBeNonUser
|_kernel_moduleinit|
; Preserve r9 (== v6) across this call
        ADD     sl, r1, #SC_SLOffset

        LoadStaticBase ip, r1
        LDMIB   r0, {r1-r2}
        MOV     r0, #0
        STMIA   ip, {r0-r2}
        ADR     r0, |_kernel_RMAalloc|
        STR     r0, [ip, #O_allocProc]  ; default alloc proc
        ADR     r0, |_kernel_RMAfree|
        STR     r0, [ip, #O_freeProc]   ; and no dealloc proc
        LDR     pc, [sp], #4
 ]

|_kernel_irqs_disabled|
 [ {CONFIG} = 26
        AND     a1, lr, #PSRIBit
 |
        MRS     a1, CPSR
        AND     a1, a1, #PSR32IBit
 ]
        Return  ,LinkNotStacked

 [ ModeMayBeNonUser
|_kernel_RMAalloc|
        FunctionEntry
|_kernel_RMAalloc_from_extend|
        MOVS    r3, a1
        Return  ,,EQ
        MOV     r0, #Module_Claim
        SWI     Module
        MOVVS   a1, #0
        MOVVC   a1, r2
        Return

|_kernel_RMAextend|
        FunctionEntry
        CMP     a1, #0
        MOVEQ   a1, a2
        BEQ     |_kernel_RMAalloc_from_extend|
        CMP     a2, #0
        BEQ     |_kernel_RMAfree_from_extend|
        LDR     r3, [a1, #-4]
        SUB     r3, r3, #4              ; Correct to useable size
        SUB     r3, a2, r3
        MOV     r2, a1
        MOV     r0, #Module_Extend
        SWI     Module
        MOVVS   a1, #0
        MOVVC   a1, r2
        Return

|_kernel_RMAfree|
        FunctionEntry
|_kernel_RMAfree_from_extend|
        MOVS    r2, a1
        MOVNE   r0, #Module_Free
        SWINE   Module
        MOV     a1, #0
        Return

  |

|_kernel_RMAalloc|
|_kernel_RMAextend|
|_kernel_RMAfree|
        MOV     a1, #0
        Return  ,LinkNotStacked

 ]

; Don't corrupt a1-a4 in these two routines, please.
; __counter relies on it, for one.
|_kernel_irqs_on|
 [ {CONFIG}=26
        BICS    pc, lr, #PSRIBit        ; 32-bit OK - in {CONFIG}=26
 |
   [ NoARMv6
|_kernel_irqs_on_NoARMv6|
        MRS     ip, CPSR
        BIC     ip, ip, #PSR32IBit
        MSR     CPSR_c, ip
        Return  ,LinkNotStacked
   ]
   [ SupportARMv6 :LAND: (:LNOT: NoARMv6 :LOR: SHARED_C_LIBRARY)
|_kernel_irqs_on_SupportARMv6|
        CPSIE   i
        Return  ,LinkNotStacked
   ]
 ]

|_kernel_irqs_off|
 [ {CONFIG}=26
        ORRS    pc, lr, #PSRIBit
 |
   [ NoARMv6
|_kernel_irqs_off_NoARMv6|
        MRS     ip, CPSR
        ORR     ip, ip, #PSR32IBit
        MSR     CPSR_c, ip
        Return  ,LinkNotStacked
   ]
   [ SupportARMv6 :LAND: (:LNOT: NoARMv6 :LOR: SHARED_C_LIBRARY)
|_kernel_irqs_off_SupportARMv6|
        CPSID   i
        Return  ,LinkNotStacked
   ]
 ]

|_kernel_processor_mode|
      [ {CONFIG}=26
        AND     a1, lr, #3      ; the question is anyway about the caller's
        MOVS    pc, lr          ; state, not ours - the answers are probably
                                ; the same.
      |
        MRS     a1, CPSR
        AND     a1, a1, #PSR32Mode
        MOV     pc, lr
      ]

|_kernel_client_is_module|
        LoadStaticBase a1, ip
      [ {CONFIG}=26
        TST     r14, #PSRPrivileged
      |
        MRS     ip, CPSR
        TST     ip, #PSR32Privileged
      ]
        MOVNE   a1, #0
        LDREQ   a1, [a1, #O_moduleDataWord]
        Return  ,LinkNotStacked

 [ ModeMayBeNonUser
|_kernel_entermodule|
        ; user entry to a module.  Need to allocate a stack in application
        ; workspace.
        ; r0 points to a kernel init block
        ; (for old stubs) r12 is the module's private word pointer.
        ; (for new stubs) r12 is -1
        ;                r8 is the module's private word pointer
        ;                r6 is the requested root stack size
        MOV     r9, r0
        SWI     GetEnv
        MOV     r4, r1
        MOV     r1, #Application_Base
        CMPS    r12, #0
        MOVLT   r12, r8
        MOVGE   r6, #OldRootStackSize
        STR     r6, [r1, #SC_size]
        LDR     r12, [r12]
        LDMIB   r12, {r2, r3}           ; relocation offsets
        ADD     r5, r1, #SC_SLOffset+SL_Lib_Offset
        STMIA   r5, {r2, r3}            ; transfer to user stack chunk
        ADD     r2, r1, r6
        MOV     r3, #1                  ; 'is a module' flag
        MOV     r0, r9
 ]

|_kernel_init|
        ; r0 points to a kernel init block.
        ; r1 = base of root stack chunk
        ; r2 = top of root stack chunk (= initial sp)
        ; r3 = 0 if ordinary application, 1 if module
        ; r4 = end of workspace (= heap limit).
        ; Always in user mode.
        MOV     sp, r2
        ADD     sl, r1, #SC_SLOffset
        MOV     fp, #0                  ; mark base of stack
        STR     fp, [r1, #SC_next]
        STR     fp, [r1, #SC_prev]
        STR     fp, [r1, #SC_deallocate]
        LDR     r5, =IsAStackChunk
        STR     r5, [r1, #SC_mark]

        LoadStaticBase v6, ip
        STR     r1, [v6, #O_heapBase]
        STR     r1, [v6, #O_rootStackChunk]
        LDMIA   r0, {r0-r2}
        CMP     r3, #0                  ; if module, imagebase (in RMA) isn't
        MOVNE   r0, #Application_Base   ; interesting
        STMIA   v6, {r0-r2}

        ; Copy the argument string (in SWI mode), so we can access it
        ; (assumed in page 0), while all user access to page 0 is disabled
        MOV     r6, sp                  ; (sp may be different in SWI mode)
        SWI     EnterSVC
        SWI     GetEnv
        MOV     r1, r0
01      LDRB    r5, [r1], #+1
 [ DDE
        CMP     r5, #' '                ; I seem to be getting LF terminated
        BCS     %B01                    ; commands. I don't know why.
 |
        CMP     r5, #0
        BNE     %B01
 ]
        SUB     r1, r1, r0
        ADD     r1, r1, #3
        BIC     r1, r1, #3
02      SUBS    r1, r1, #4
        LDR     r5, [r0, r1]
        STR     r5, [r6, #-4]!
        BNE     %B02
        WritePSRc 0, r5                  ; back to user mode
 [ DDE
        SWI     XDDEUtils_GetCLSize
        MOVVS   r0, #0
        CMP     r0, #0
        BEQ     %F04
        ADD     r0, r0, #3
        BIC     r0, r0, #3
        SUB     r1, r6, r0
        MOV     r0, r1
03      LDRB    r2, [r6], #+1
        CMP     r2, #' '
        MOVCC   r2, #' '
        STRB    r2, [r0], #+1
        BCS     %B03
        SWI     XDDEUtils_GetCl
        MOV     r6, r1
04
 ]
        STR     r6, [v6, #O_ArgString]

        ADRL    r0, |_kernel_malloc|
        STR     r0, [v6, #O_allocProc]  ; default alloc proc
        ADRL    r0, |_kernel_free|
        STR     r0, [v6, #O_freeProc]   ; and no dealloc proc

        ; set up a small stack chunk for use in performing stack extension.
        ; We needn't bother with most of the fields in the description of
        ; this chunk - they won't ever be used.  We must set mark (to be
        ; not IsAStackChunk) and SL_xxx_Offset. Also prev.
        STR     sp, [v6, #O_extendChunk]
      [ {CONFIG}<>26
        MOV     r0, #OSPlatformFeatures_ReadCodeFeatures
        SWI     XOS_PlatformFeatures
        MOVVS   r0, #0
        ; _swp_available is used as a bitfield:
        ; bit 0 => SWP available
        ; bit 1 => LDREX/STREX available
        ; bit 2 => LDREX[B|D|H]/STREX[B|D|H] available
        ; This is a simple manipulation of the PlatformFeatures return flags
        ASSERT  CPUFlag_NoSWP                 = 1:SHL:11
        ASSERT  CPUFlag_LoadStoreEx           = 1:SHL:12
        ASSERT  CPUFlag_LoadStoreClearExSizes = 1:SHL:13
        EOR     r0, r0, #CPUFlag_NoSWP
        MOV     r1, #7
        AND     r1, r1, r0, LSR #11
        STR     r1, [v6, #O__swp_available]
      |
        BL      CheckIfSwpAvailable
      ]
        MOV     r0, #1
        STR     r0, [v6, #O_extendChunkNotInUse]
        ADD     r0, sl, #SL_Lib_Offset
        LDMIA   r0, {r1, r2}
        ADD     r0, sp, #SC_SLOffset+SL_Lib_Offset
        STMIA   r0, {r1, r2}
        STR     sp, [sp, #SC_mark]
        STR     fp, [sp, #SC_prev]      ; 0 to mark end of chain
        MOV     r0, #ExtendStackSize
        STR     r0, [sp, #SC_size]
        ADD     sp, sp, #ExtendStackSize
        STR     sp, [v6, #O_heapTop]    ; save updated value for heap base
        STR     r4, [v6, #O_heapLimit]
        MOV     sp, r6

        MOV     r0, #1
        STRB    r0, [v6, #O_callbackInactive]
        STR     fp, [v6, #O_hadEscape]
        STR     r3, [v6, #O_moduleDataWord]
        STRB    fp, [v6, #O_escapeSeen]

        ; Determine whether FP is available (to decide whether fp regs need
        ; saving over _kernel_system)
        ; The SWI will fail if it isn't
        SWI     FPE_Version
        MOVVC   r0, #&70000     ; IVO, DVZ, OFL cause a trap
        WFSVC   r0
        MOVVC   r0, #1
        MOVVS   r0, #0
        STRB    r0, [v6, #O_fpPresent]

        ; Check where the stacks are
        ASSERT  O_svcStack = O_undStack + 4
        MOV     r0, #6
        ADR     r1, RSI6_List
        ADD     r2, v6, #O_undStack
        SWI     XOS_ReadSysInfo
        LDRVS   r0, =&01E02000
        LDRVS   r1, =&01C02000
        STMVSIA r2, {r0, r1}

        ADD     r4, v6, #O_IIHandlerInData
        ADR     r5, IIHandlerInDataInitValue
        BL      CopyHandler
        ADD     r4, v6, #O_PAHandlerInData
        ADR     r5, PAHandlerInDataInitValue
        BL      CopyHandler
        ADD     r4, v6, #O_DAHandlerInData
        ADR     r5, DAHandlerInDataInitValue
        BL      CopyHandler
        ADD     r4, v6, #O_AEHandlerInData
        ADR     r5, AEHandlerInDataInitValue
        BL      CopyHandler

 [ StrongARM   ;CopyHandler does some dynamic code
        MOV     r0, #1
        ASSERT  O_IIHandlerInData < O_PAHandlerInData
        ASSERT  O_PAHandlerInData < O_DAHandlerInData
        ASSERT  O_DAHandlerInData < O_AEHandlerInData
        ADD     r1, v6, #O_IIHandlerInData
        ADD     r2, v6, #O_AEHandlerInData + 16
        SWI     XOS_SynchroniseCodeAreas
 ]

        MOV     r0, #0
        BL      InstallHandlers

        MOV     r0, #0
        SWI     XWimp_ReadSysInfo
        MOVVS   r0, #0                  ; error - presumably Wimp not present
        CMP     r0, #0
        MOVNE   r0, #1
        STRB    r0, [v6, #O_underDesktop]

        LDREQ   r1, [v6, #O_heapLimit]
        MOVNE   r0, #Env_ApplicationSpace
        MOVNE   r1, #0
        SWINE   ChangeEnv
        STR     r1, [v6, #O_knownSlotSize]
        STR     r1, [v6, #O_initSlotSize]

        MOV     v1, #0
        LDMIB   v6, {v2, v3}
CallInitProcs Keep
        CMP     v2, v3
        BGE     EndInitProcs
        LDR     v4, [v2, #lang_size]
        CMP     v4, #lang_Init
        BLE     NoInitProc
        LDR     a1, [v2, #lang_Init]
        CMP     a1, #0
        BEQ     NoInitProc
        CallClient a1
        CMP     a1, #0
        MOVNE   v1, a1
NoInitProc
        ADD     v2, v2, v4
        B       CallInitProcs
EndInitProcs
        CMP     v1, #0
        BEQ     NoMainProgram
        CallClient v1

NoMainProgram
        BL      Finalise
        ADR     r0, E_NoMainProgram
        BL      |_kernel_copyerror|
FatalError Keep
        SWI     GenerateError

 [ {CONFIG}=26
; v6 = static base
; sp -> extendChunk, which we will use as workspace
; assumed entered in USR mode with SVC stack empty
CheckIfSwpAvailable
        STMIA   sp!, {r0-r12,r14}      ; error handler might corrupt anything
        MOV     r0, #0                 ; start off assuming error will happen
        STR     r0, [v6, #O__swp_available]

        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        SWI     XOS_ChangeEnvironment           ; read existing error handler
        STMIA   sp!, {r1-r3}
        MOV     r0, #6
        ADR     r1, %FT01
        MOV     r2, sp
        MOV     r3, sp
        SWI     XOS_ChangeEnvironment           ; set temp error handler

        SWP     r0, r0, [sp]                    ; try a SWP

        MOV     r0, #1
        STR     r0, [v6, #O__swp_available]     ; note we were successful
        B       %FT02
01
        MOV     sp, r0                          ; put back sp after error
02
        MOV     r0, #6
        LDMDB   sp!, {r1-r3}
        SWI     XOS_ChangeEnvironment           ; restore error handler
        LDMDB   sp!, {r0-r12,pc}
 ]

;StrongARM - there is dynamic code here, but this is sorted in _kernel_init, after
;all calls to CopyHandler
CopyHandler
        LDMIA   r5!, {r6, r7}                   ; first 2 instructions
        STMIA   r4!, {r6, r7}
        LDR     r6, =&E51FF004                  ; LDR PC,<nextword>
        STR     r6, [r4], #4
        STR     r5, [r4]                        ; address of main handler
        MOV     pc, r14

        LTORG

RSI6_List
        DCD     OSRSI6_UNDSTK, OSRSI6_SVCSTK, -1

|Sys$RCLimit|
        DCB     "Sys$$RCLimit", 0
        ALIGN

|_kernel_exit|
 [ ModeMayBeNonUser
        [ {CONFIG} = 26
        TST     r14, #3
        |
        MRS     ip, CPSR
        TST     ip, #PSR32Privileged
        ]
        BEQ     |_kernel_user_exit|
        MOV     ip, sp
        SUB     sp, sp, #4*12              ; set up an unwind block
        STR     sl, [sp, #-4]!
        STMFD   sp!, {a1, r3-r9, fp, ip, r14}  ; r3 to reserve an extra word
        BL      |_kernel_exittraphandler|
01      ADD     a1, sp, #8
        ADD     a2, sp, #4
        BL      |_kernel_unwind|
        CMP     a1, #0
        BNE     %B01
        MOV     r0, #1                  ; get base address of RMA
        SWI     XOS_ReadDynamicArea
        MOVVC   r14, r0
        MOVVS   r14, #&01800000         ; default to fixed base if SWI fails
        LDR     a1, [sp], #4
        CMP     a1, r14
        ADRCC   a1, E_Exit
        BLCC    |_kernel_copyerror|     ; BL<cond> 32-bit OK
        [ {CONFIG}=26
        LDMIB   sp, {r4-r9, fp, sp, pc}^
        |
      [ {FALSE} ; this instruction is now deprecated
        LDMIB   sp, {r4-r9, fp, sp, pc}
      |
        LDMIB   sp, {r4-r9, fp, ip, lr}
        MOV     sp, ip
        MOV     pc, lr
      ]
        ]

        ALIGN

        ErrorBlock Exit, "Exit called", C49

|_kernel_user_exit|
 ]
        LoadStaticBase v6, ip
; the work of finalisation gets done in the Exit handler.
; Due to a bug in the RISC OS kernel where the PC value in the error block
; is incorrectly written if OS_Exit is called with a return value outside
; the range 0 .. Sys$RCLimit we perform the check ourselves and call
; GenerateError directly
        LDR     r2, [v6, #O_returnCode]
        CMP     r2, #0
        SWIEQ   Exit
        ADR     r0, |Sys$RCLimit|
        ADD     r1, v6, #O_returnCodeLimit
        MOV     r2, #4
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_ReadVarVal
        MOVVS   r3, #&100
        BVS     KernelExit1
        MOV     r3, #0
KernelExit2
        LDRB    r0, [r1], #1
        SUB     r0, r0, #'0'
        CMP     r0, #10
        BCS     KernelExit1
        ADD     r3, r3, r3, LSL #2
        ADD     r3, r0, r3, LSL #1
        B       KernelExit2
KernelExit1
        ADR     r0, E_BadReturnCode
        BL      |_kernel_copyerror|
        LDR     r2, [v6, #O_returnCode]
        CMP     r2, #0
        ADDLTS  r2, r2, r3
        CMPNE   r2, r3
        LDR     r1, ABEXString
        SWICC   Exit
        STR     r0, [sp, #-4]!
        BL      Finalise
        LDR     r0, [sp],  #4
        SWI     GenerateError

; Generate an external error. Re-init the stack to the root stack chunk.
; The stack contents are not needed since this is an external error.
; In some cases we must re-init the stack (eg. stack overflow).
; The only case where it might may a difference is under a debugger in which
; case tough luck, you don't get a backtrace.
|_kernel_raise_error|
        TEQ     r0, #0
        Return  ,LinkNotStacked, EQ
 [ ModeMayBeNonUser
        [ {CONFIG}=26
        TST     r14, #3
        |
        MRS     ip, CPSR
        TST     ip, #PSR32Privileged
        ]
        BNE     |_kernel_exit|
 ]
        LoadStaticBase v6, ip
        LDR     sl, [v6, #O_rootStackChunk]
        LDR     sp, [sl, #SC_size]
        ADD     sp, sl, sp
        ADD     sl, sl, #SC_SLOffset
        MOV     fp, #0
        STR     a1, [sp, #-4]!
        BL      Finalise
        LDR     a1, [sp], #4
        SWI     GenerateError

Finalise
        STR     lr, [sp, #-4]!
        LDMIB   v6, {v2, v3}
CallFinaliseProcs
        CMP     v2, v3
        BGE     EndFinaliseProcs
        LDR     v4, [v2, #lang_size]
        CMP     v4, #lang_Finalise
        BLE     NoFinaliseProc
        LDR     v1, [v2, #lang_Finalise]
        CMP     v1, #0
        BEQ     NoFinaliseProc
        CallClient v1
NoFinaliseProc
        ADD     v2, v2, v4
        B       CallFinaliseProcs
EndFinaliseProcs
 [ SharedLibrary
        ; Then do finalisation for the shared library (if we are one)
        ; Not CallClient here, because change of calling standards is
        ; inappropriate.
        LDR     v2, =|RTSK$$Data$$Base|
        LDR     v3, =|RTSK$$Data$$Limit|
CallFinaliseProcs_SL
        CMP     v2, v3
        BGE     EndFinaliseProcs_SL
        LDR     v4, [v2, #lang_size]
        CMP     v4, #lang_Finalise
        BLE     NoFinaliseProc_SL
        ; Before doing a shared library module finalisation we must check it
        ; was initialised by the client. Do this by comparing the language
        ; names.
        STMDB   sp!, {v1, v2, v3}
        LDR     v1, [v2, #lang_name]
        LDMIB   v6, {v2, v3}
CheckClientInit
        CMP     v2, v3
        LDMGEIA sp!, {v1, v2, v3}
        BGE     NoFinaliseProc_SL ; No client init found so can't finalise
        MOV     a1, v1
        LDR     a2, [v2, #lang_name]
CompareClientAndLibraryNames
        LDRB    a3, [a1], #1
        LDRB    a4, [a2], #1
        CMP     a3, a4
        LDRNE   a1, [v2, #lang_size]
        ADDNE   v2, v2, a1
        BNE     CheckClientInit
        CMP     a3, #0
        BNE     CompareClientAndLibraryNames
        LDMIA   sp!, {v1, v2, v3}
        LDR     v1, [v2, #lang_Finalise]
        CMP     v1, #0
        MOVNE   lr, pc
        MOVNE   pc, v1
NoFinaliseProc_SL
        ADD     v2, v2, v4
        B       CallFinaliseProcs_SL
EndFinaliseProcs_SL
 ]
        LDR     lr, [sp], #4
        B       RestoreOSHandlers


|_kernel_setreturncode|
        LoadStaticBase ip, a2
        STR     a1, [ip, #O_returnCode]
        Return  ,LinkNotStacked

|_kernel_fpavailable|
        LoadStaticBase ip, a1
        LDRB    a1, [ip, #O_fpPresent]
        Return  ,LinkNotStacked

ABEXString
        =       "ABEX"

        ErrorBlock BadReturnCode, "Return code too large", C50
        ErrorBlock NoMainProgram, "No main program", C51

        LTORG

 ;*-------------------------------------------------------------------*
 ;* Abort Handlers                                                    *
 ;*-------------------------------------------------------------------*

; The handlers called by the OS are in my static data, written there on
; startup, because that's the only way they can find out where the static data
; is.  They don't do much, other than save some registers and load r12 with
; the static base.  They are all the same length, and all immediately precede
; the real handler; when they are installed, a branch to the real handler is
; tacked on the end.

IIHandlerInDataInitValue
        STMFD   r13!, {r0-r4, r12, r14, pc}
        SUB     r12, pc, #O_IIHandlerInData+12

; Now the bits of the abort handlers which get executed from the code.
; r12 is the address of my static data; the user's values of r0 and r12 are
; on the SVC stack.  (SVC mode, interrupts disabled).

IIHandler Keep
        SUB     r14, r14, #4
        STR     r14, [r12, #O_registerDump + 15 * 4]

        LDR     r14, [r12, #O_oldAbortHandlers + 0]
        STR     r14, [r13, #28]
        B       Aborted


PAHandlerInDataInitValue
        STMFD   r13!, {r0-r4, r12, r14, pc}
        SUB     r12, pc, #O_PAHandlerInData+12
PAHandler Keep
        SUB     r14, r14, #4
        STR     r14, [r12, #O_registerDump + 15 * 4]

        LDR     r14, [r12, #O_oldAbortHandlers + 4]
        STR     r14, [r13, #28]
        B       Aborted

DAHandlerInDataInitValue
        STMFD   r13!, {r0-r4, r12, r14, pc}
        SUB     r12, pc, #O_DAHandlerInData+12
DAHandler Keep
        SUB     r14, r14, #8
        STR     r14, [r12, #O_registerDump + 15 * 4]

        LDR     r14, [r12, #O_oldAbortHandlers + 8]
        STR     r14, [r13, #28]
        B       Aborted2

AEHandlerInDataInitValue
        STMFD   r13!, {r0-r4, r12, r14, pc}
        SUB     r12, pc, #O_AEHandlerInData+12
AEHandler Keep
        SUB     r14, r14, #8
        STR     r14, [r12, #O_registerDump + 15 * 4]

        LDR     r14, [r12, #O_oldAbortHandlers + 12]
        STR     r14, [r13, #28]
;       B       Aborted2

Aborted2 Keep
; Abort which may be in the FP emulator, and if so should be reported
; as occurring at the instruction being emulated.
; Try the FPEmulator_Abort SWI

        LDR     r2, [sp, #24]
        ADD     r2, r2, #8              ; original r14
        LDR     r1, [sp, #20]           ; original r12
      [ {CONFIG}=26
        BIC     r2, r2, #PSRBits
      |
        TEQ     pc, pc
        BICNE   r2, r2, #PSRBits
        MRSEQ   r3, CPSR
        BICEQ   r0, r3, #PSR32Mode
        ORREQ   r0, r0, #PSR32SVCMode
        MSREQ   CPSR_c, r0              ; if in 32-bit mode, probably ABT
        STREQ   lr, [sp, #-4]!          ; so switch to SVC to preserve R14_svc
      ]
        MOV     r0, #-2                 ; current context
        SWI     XFPEmulator_Abort       ; WILL NOT ERROR ON SOME OLD FPEs - acts as
                                        ; if FPEmulator_Version, hence returning a
                                        ; small number
      [ {CONFIG}<>26
        TEQ     pc, pc
        LDREQ   lr, [sp], #4            ; get back R14_svc
        MSREQ   CPSR_c, r3              ; back to original mode
       [ StrongARM_MSR_bug
        NOP                             ; avoid StrongARM bug
       ]
      ]
        BVS     NoFPEAbortSWI           ; in case someone really does error
        TEQ     r0, #0                  ; check for real "not FP abort" return
        LDMEQFD sp, {r0-r2}
        BEQ     Aborted                 ; not in FPEmulator
        CMP     r0, #&01000000          ; check for a bogus result
        BLO     NoFPEAbortSWI
        B       FPEFault

NoFPEAbortSWI
; If in user mode, can't be in FPE
      [ {CONFIG}=26
        LDR     r1, [sp, #24]
        TST     r1, #PSRPrivileged
      |
        TEQ     pc, pc
        LDRNE   r1, [sp, #24]
        ANDNE   r1, r1, #PSRMode        ; obtain aborter's mode from R14
        MRSEQ   r1, SPSR                ; obtain aborter's mode from SPSR
        TST     r1, #PSR32Privileged
      ]
        LDMEQFD sp, {r0-r4}
        BEQ     Aborted

; Otherwise, find out where the FPE module is
      [ {CONFIG} <> 26
        TST     r2, #2_11100
      ]
        STMFD   sp!, {r0 - r6}
      [ {CONFIG} = 26
        BIC     r6, r14, #PSRBits
      |
        BICEQ   r6, r14, #PSRBits       ; 32-bit OK (26-bit cond)
        MOVNE   r6, r14
      ]
        MOV     r0, #18
        ADR     r1, FPEName
        SWI     Module
        LDMVSFD sp!, {r0 - r6}
        BVS     Aborted
; (r3 = code base of FPE; word before is length of FPE code)
        CMP     r6, r3
        LDRGE   r4, [r3, #-4]
        ADDGE   r3, r3, r4
        CMPGE   r3, r6
        LDMFD   sp!, {r0 - r6}
        BLT     Aborted

; It was a storage fault in the FP emulator.
; We assume FPEmulator 4.00 or later - r0
; will point to a full register save. The format differs slightly
; depending on whether the FPEmulator is 32-bit or not. If we're
; in a 32-bit mode, we know the FPEmulator will be. If not, check
; to see if the saved r12 is in the UND stack.
FPEFault
        ADD     r14, r12, #O_registerDump
        LDMIA   r0!, {r1-r4}            ; copy R0-R15
        STMIA   r14!, {r1-r4}
        LDMIA   r0!, {r1-r4}
        STMIA   r14!, {r1-r4}
        LDMIA   r0!, {r1-r4}
        STMIA   r14!, {r1-r4}
        LDMIA   r0!, {r1-r4}
        SUB     r4, r4, #4              ; adjust PC back 4
        STMIA   r14!, {r1-r4}
      [ {CONFIG}<>26
        TEQ     pc, pc
        BEQ     FPEFault_32on32
      ]
        LDR     r3, [r12, #O_undStack]
        MOV     r2, r1, LSR #20         ; we're on a 26-bit system
        TEQ     r2, r3, LSR #20         ; is the stack frame in the UND stack?
        BEQ     FPEFault_32on26
FPEFault_26on26
        B       FPEFault_Continue

FPEFault_32on26
        LDR     r2, [r0, #-72]          ; get the SPSR
        AND     r2, r2, #PSRBits
        BIC     r4, r4, #PSRBits
        ORR     r4, r4, r2
        STR     r4, [r14, #-4]          ; merge it with pc in register dump
      [ {CONFIG}<>26
        B       FPEFault_Continue

FPEFault_32on32
        LDR     r2, [r0, #-72]          ; get the SPSR
        STR     r2, [r14]               ; store it in the register dump
      ]

FPEFault_Continue
        LDMFD   r13!, {r0-r4, r12, r14, pc}

        ErrorBlock  PrefetchAbort,      "Prefetch Abort", C60
        ErrorBlock  DataAbort,          "Data Abort", C61
        ErrorBlock  AddressException,   "Address Exception", C53
        ErrorBlock  IllegalInstruction, "Illegal Instruction", C54
FPEName =       "FPEmulator",0
        ALIGN

Aborted Keep
        ADD     r14, r12, #O_registerDump
  [ SASTMhatbroken
        STMIA   r14!, {r0-r12}
        STMIA   r14, {r13,r14}^
        NOP
        SUB     r14, r14, #13*4
  |
        STMIA   r14, {r0-r14}^
        NOP
  ]

        LDR     r0, [r13, #20]
        STR     r0, [r14, #r12*4]

        TEQ     pc, pc
        MOVNE   r3, pc
        ANDNE   r3, r3, #PSRBits
        MRSEQ   r3, CPSR
        LDRNE   r0, [sp, #24]
        ANDNE   r0, r0, #PSRMode        ; obtain aborter's mode from R14
        MRSEQ   r0, SPSR                ; obtain aborter's mode from SPSR
        STREQ   r0, [r14, #16*4]        ; store aborter's SPSR if in 32-bit mode
        TST     r0, #PSR32Privileged
        BEQ     NotPrivileged
        LDR     r0, [r14, #r14*4]       ; if abort in a privileged mode, save
        STR     r0, [r14, #pc*4]        ; PC as user R14
        LDR     r0, [r12, #O_svcStack]  ; switch to SVC mode and look at R13_svc
        ADD     r4, r14, #10 * 4        ; reg ptr into unbanked register
        TEQ     pc, pc
        MSREQ   CPSR_c, #PSR32SVCMode+PSR32IBit+PSR32FBit
        TEQNEP  pc, #PSRSVCMode+PSRIBit+PSRFBit
        MOV     r1, r0, LSR #20         ; r0 = stack top
        MOV     r1, r1, LSL #20         ; r1 = stack base
        SUB     r2, r0, #12             ; r2 = stack top - 12
        CMP     r13, r1                 ; r1 <= r13 <= r2?
        CMPHS   r2, r13
        LDMHSDB r0, {r0-r2}             ; Pull R10-R12 off of top of SVC stack
        STMHSIA r4, {r0-r2}             ; if there were at least 3 words on it
        TEQ     pc, pc
        MSREQ   CPSR_cxs, r3
        TEQNEP  pc, r3
        NOP
NotPrivileged
        LDMFD   r13!, {r0-r4, r12, r14, pc}

AbortFindHandler Keep
; We can only call an abort handler if we had a stack at the
; time of the abort.  If not, we have to say 'uncaught trap'.
; There is a problem as soon as interrupts are enabled, that an event may
; arrive and trash the register dump.  If there's a stack, this is solved
; by copying the dump onto it.  Otherwise, we protect ourselves while
; constructing the error by pretending there's a callback going on.
; Entry may be in SWI mode (faults) or user mode (stack overflow,
; divide by zero).
; r0 is the address of an error block describing the fault.
; r12 is the address of our static data.

        MOV     v6, r12
        BL      CopyErrorV6OK
        LDRB    r2, [v6, #O_inTrapHandler]
        CMP     r2, #0
        BNE     RecursiveTrap
        LDRB    r2, [v6, #O_unwinding]
        CMP     r2, #0
        BNE     duh_abort
        MOV     r2, #1
        STRB    r2, [v6, #O_inTrapHandler]

        ADD     r11, v6, #O_registerDump+17*4
        LDR     r10, [v6, #O_registerDump+sl*4]
        LDR     r1, [v6, #O_heapBase]
        LDR     r2, [v6, #O_heapLimit]

        LDR     r12, [v6, #O_registerDump+sp*4]
        ; Stack pointer and stack limit must both be word aligned
        ; Frame pointer might not be (bottom bit used as flag), so don't check for that (_kernel_unwind will check it before using it anyway)
        TST     r10, #3
        TSTEQ   r12, #3
        BNE     Trap_NoStackForHandler
        CMP     r12, r1
        CMPHI   r2, r12
        ADDHI   r1, r12, #256
        CMPHI   r1, r10
        BLS     Trap_NoStackForHandler
        LDR     r3, =IsAStackChunk
        LDR     r4, [r10, #SC_mark-SC_SLOffset]
        EOR     r4, r4, r3
        BICS    r4, r4, #&80000000 ; a chunk marked 'handling extension' will do
        BNE     Trap_NoStackForHandler
        LDR     v1,  [v6, #O_registerDump+fp*4]

        ; At this point, r12 is the user mode stack pointer and r11 points just past
        ; the 17th entry of the register dump.
        LDMDB   r11!, {a1-a4, v2-v5, lr}
        STMDB   r12!, {a1-a4, v2-v5, lr}
        LDMDB   r11!, {a1-a4, v2-v5}
        STMDB   r12!, {a1-a4, v2-v5}
        ; Some agony here about preventing an event handler running
        ; (on the user stack) while the registers describing the stack
        ; (sp & sl) haven't both been updated.
 [ ModeMayBeNonUser
        MOV     a1, #0
        MRS     a1, CPSR
        TST     a1, #2_11100
        BEQ     %FT01                                   ; 26-bit mode
     [ {CONFIG}=26
        MSR     CPSR_c, #PSR32IBit + PSRUSRMode         ; USR26, I set
     |
        MSR     CPSR_c, #PSR32IBit + PSR32USRMode       ; USR32, I set
     ]
        MSR     CPSR_f, #PSRVBit                        ; set V for calling IntOn.
        B       %FT02
01      LDR     a1, [v6, #O_registerDump+pc*4]
        TST     a1, #PSRIBit
        ORREQ   a1, a1, #PSRVBit
        BICNE   a1, a1, #PSRVBit
        TEQP    a1, #0
02
   |
     [ No32bitCode
        TEQP    pc, #PSRIBit:OR:PSRVBit                 ; user mode
     |
        MRS     a1, CPSR
        ORR     a1, a1, #PSR32IBit                      ; may not need this
        ORR     a1, a1, #PSRVBit
      [ {CONFIG}=26
        BIC     a1, a1, #PSR32Privileged                ; into USR26 mode
      |
        BIC     a1, a1, #PSR32Mode                      ; into USR32 mode
      ]
        MSR     CPSR_cf, a1                             ; switch to user mode
     ]
 ]

        NOP
        MOV     sp, r12
        MOV     sl, r10
        MOV     fp, v1
        SWIVS   IntOn

        LDR     v1, [v6, #O_errorNumber]
        MOV     r0, sp
        MOV     v2, #lang_Trap
        BL      FindAndCallHandlers

        MOV     r0, sp
        MOV     v2, #lang_UncaughtTrap
        BL      FindAndCallHandlers

        BL      RestoreOSHandlers
        MOV     v5, sp
        ADD     fp, v6, #O_errorNumber
        ADR     ip, E_UncaughtTrap
        B       FatalErrorX

Trap_NoStackForHandler
        ADR     ip, E_NoStackForTrapHandler
        B       FatalErrorY

        ErrorBlock NoStackForTrapHandler, "No stack for trap handler", C55

RecursiveTrap Keep
        ADR     ip, E_RecursiveTrap
FatalErrorY
        ; Pointer to error block in ip. (beware, RestoreOSHandlers
        ; corrupts r0-r8).
        MOV     fp, r0
        MOV     r0, #0
        STRB    r0, [v6, #O_callbackInactive]
        WritePSRc 0, lr
        BL      RestoreOSHandlers
        ADD     v5, v6, #O_registerDump
FatalErrorX
 [ SharedLibrary
        LDR     a1, [v5, #pc*4]
        ADD     a2, v6, #O_pc_hex_buff
        BL      HexOut
        MOV     a1, v5
        ADD     a2, v6, #O_reg_hex_buff
        BL      HexOut
        MOV     r0, ip
  [ :DEF:DEFAULT_TEXT
        ADD     r0, r0, #4
10      LDRB    r2, [r0], #1
        CMP     r2, #0
        BNE     %B10
        ADD     r0, r0, #3
        BIC     r0, r0, #3
  ]
        SavePSR v4
        SWI     EnterSVC
        BLVC    open_messagefile        ; BL<cond> 32-bit OK
        RestPSR v4
        MOV     r0, r0
        ; We just trample all over the start of our workspace.
        ; Fine, as we've removed handlers and are about to go pop.
        ADD     r2, v6, #O_FatalErrorBuffer
        MOV     r3, #256
        ADD     r4, fp, #4
        ADD     r5, v6, #O_pc_hex_buff
        ADD     r6, v6, #O_reg_hex_buff
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
 |
        MOV     r0, ip
        BL      |_kernel_copyerror|
        MOV     a4, r0
        ADD     a2, v6, #O_FatalErrorBuffer
        BL      CopyError2
        SUB     a2, a2, #1
        ADR     a4, str1
        BL      CopyErrorString
        SUB     a2, a2, #1
        ADD     a4, fp, #4
        BL      CopyErrorString
        SUB     a2, a2, #1
        ADR     a4, str2
        BL      CopyErrorString
        SUB     a2, a2, #1
        LDR     a1, [v5, #pc*4]
        BL      HexOut
        MOV     a4, a2
        [ :DEF:DEFAULT_TEXT
        ADR     a1, str3
        ADR     a2, str3tok
        |
        ADR     a1, str3tok
        ]
        BL      |_kernel_getmessage|
        MOV     a2, a4
        MOV     a4, r0
        BL      CopyErrorString
        SUB     a2, a2, #1
        MOV     a1, v5
        BL      HexOut
        MOV     a1, #0
        STRB    a1, [a2]
        ADD     r0, v6, #O_FatalErrorBuffer
 ]
        B       FatalError

str1    = ": ", 0
str2    = ", pc = ", 0
 [ :DEF:DEFAULT_TEXT
str3    = ": registers at ", 0
 ]
str3tok = "C56", 0
        ALIGN

; a1 = Hex value to convert
; a2 = Buffer
HexOut  MOV     a4, #8
01      MOV     a1, a1, ROR #28
        AND     a3, a1, #15
        CMP     a3, #10
        ADDLT   a3, a3, #"0"
        ADDGE   a3, a3, #"A"-10
        STRB    a3, [a2], #+1
        SUBS    a4, a4, #1
        BNE     %B01
 [ SharedLibrary
        STRB    a4, [a2]
 ]
        Return  ,LinkNotStacked


|_kernel_exittraphandler|
        LoadStaticBase ip, a1
        MOV     a1, #0
        STRB    a1, [ip, #O_inTrapHandler]
        MOV     a1, #1
        STRB    a1, [ip, #O_callbackInactive]
        Return  ,LinkNotStacked

FindAndCallHandlers Keep
        ; Finds a handler of type offset v2 in a language description,
        ; responsible for the current pc value.  If one (non-zero) is found,
        ; calls it, and resumes the program if it so requests.
        ; Otherwise, unwinds the stack and repeats the operation.
        ; r0 addresses the register dump
        ; v1 is the first argument for the handler (fault / event code)
        ; v2 is the handler offset
        ; v6 is my static data base

        ; set up an initial unwind block.  For our purposes, we don't care
        ; about the values of callee-save registers (ARM or FP).
        STMFD   sp!, {r0, r14}
        MOV     v3, fp
        MOV     v4, sp
        LDR     v5, [r0, #pc*4]
        MOV     ip, sl
        MOV     r1, v5
        SUB     sp, sp, #uwb_size+4
        ADD     v4, sp, #uwb_fp+4
        STMIA   v4, {v3, v4, v5, ip}
FCH_NextFrame
        [ {CONFIG}=26
        BIC     r1, r1, #PSRBits
        |
        MRS     v4, CPSR
        TST     v4, #2_11100
        BICEQ   r1, r1, #PSRBits
        ]
        LDMIB   v6, {v4, v5}
FCH_NextLanguage Keep
        ; find to which language the current pc corresponds (between which
        ; language's code bounds it lies).
        CMP     v4, v5
        BGE     FCH_NoHandlerFound

        LDMIA   v4, {r0, r2, r3}
        CMP     r1, r2
        CMPGE   r3, r1
        ADDLT   v4, v4, r0
        BLT     FCH_NextLanguage

        ; If the language has a handler procedure of the right type, call it
        ; (it may not have one either by not having a large enough area, or
        ;  a zero entry).
        CMP     r0, v2
        BLE     FCH_Unwind
        LDR     r2, [v4, v2]
        CMP     r2, #0
        BEQ     FCH_Unwind

        ; arguments for the handler are
        ;   fault or event code
        ;   pointer to dumped registers
        ; return value is non-zero to resume; otherwise, search continues
        LDR     a1, =|RTSK$$Data$$Limit|
        CMP     v5, a1
        MOV     a1, v1
        LDR     a2, [sp, #uwb_size+4]
        BNE     FCH_CallClient
        MOV     lr, pc
        MOV     pc, r2
        B       FCH_ClientCalled
FCH_CallClient
        CallClient r2
FCH_ClientCalled
        CMP     v2, #lang_Event  ; event handlers are only allowed to pass escape
        BNE     FCH_NotEvent
        CMP     v1, #-1
        BNE     FCH_Exit
FCH_NotEvent
        CMP     a1, #0
        BEQ     FCH_Unwind
        ; if resuming after a trap, clear the 'in trap handler' status
FCH_Exit
        SUBS    r0, v2, #lang_Trap
        SUBNES  r0, v2, #lang_UncaughtTrap
        STREQB  r0, [v6, #O_inTrapHandler]
        LDR     r0, [sp, #uwb_size+4]
        B       ReloadUserState

FCH_NoHandlerFound Keep
        ; pc is not within a known code area in the image.  Perhaps it is
        ; within a library area (if the image uses a shared library).
 [ SharedLibrary
        LDR     r0, =|RTSK$$Data$$Limit|
        CMP     v5, r0
        MOVNE   v5, r0
        LDRNE   v4, =|RTSK$$Data$$Base|
        BNE     FCH_NextLanguage
 ]
FCH_Unwind  Keep
        ADD     a1, sp, #4
        MOV     a2, sp
        BL      |_kernel_unwind|
        CMP     a1, #0
        LDRGT   r1, [sp, #uwb_pc+4]
        BGT     FCH_NextFrame

        ADD     sp, sp, #uwb_size+4+4
        [ {CONFIG}=26
        LDMFD   sp!, {pc}^
        |
        LDR     pc, [sp], #4
        ]

        ErrorBlock UncaughtTrap, "Uncaught trap", C57
        ErrorBlock RecursiveTrap, "Trap while in trap handler", C58

RestoreOSHandlers Keep
        ; (there may not be a valid sp)
        STR     lr, [v6, #O_lk_RestoreOSHandlers]
        BL      InstallCallersHandlers
        LDRB    r1, [v6, #O_underDesktop]
        CMP     r1, #0
        LDRNE   r1, [v6, #O_knownSlotSize]
        LDRNE   r0, [v6, #O_initSlotSize]
        CMPNE   r1, r0
        LDR     lr, [v6, #O_lk_RestoreOSHandlers]
        BNE     SetWimpSlot
        Return  ,LinkNotStacked

SetWimpSlot_Save_r4r5
        STMFD   sp!, {r4, r5}
SetWimpSlot  Keep
        ; Set the wimp slot to r0 - ApplicationBase.
        ; Destroys r4, r5
        ; May need to set MemoryLimit temporarily to the slot size,
        ; in order that Wimp_SlotSize not refuse.
        ; (Note that preservation of r4 is required anyway because of
        ;  fault in Wimp_SlotSize which corrupts it).
        ; Returns the slot size set.
        MOV     r4, r0
        MOV     r0, #Env_MemoryLimit
        MOV     r1, #0
        SWI     ChangeEnv
        MOV     r5, r1                          ; r5 = current memory limit
        MOV     r0, #Env_ApplicationSpace
        MOV     r1, #0
        SWI     ChangeEnv
        CMP     r1, r5                          ; is memory limit=application space?
        BNE     SetWimpSlot_DoFudge             ; if not, make it so.
        SUB     r0, r4, #Application_Base
        MOV     r1, #-1
        SWI     XWimp_SlotSize                  ; change slot size
        Return  ,LinkNotStacked

SetWimpSlot_DoFudge
        MOV     r0, #Env_MemoryLimit
        SWI     ChangeEnv
        SUB     r0, r4, #Application_Base
        MOV     r1, #-1
        SWI     XWimp_SlotSize                  ; change slot size
        MOV     r4, r0
        MOV     r0, #Env_MemoryLimit
        MOV     r1, r5
        SWI     ChangeEnv
        MOV     r0, r4
        Return  ,LinkNotStacked

; Our own exit handler, which restores our parent's environment then exits.
; Just in case a C program manages to (call something which) does a SWI Exit.
; Necessary otherwise because of Obey.
; The register state prevailing when exit was called is completely undefined;
; all we can rely on is that r12 addresses our static data.  The stack
; description may be junk so we reset the stack to its base.
ExitHandler Keep
        MOV     v6, r12
        LDR     sl, [v6, #O_rootStackChunk]
        LDR     sp, [sl, #SC_size]
        ADD     sp, sl, sp
        ADD     sl, sl, #SC_SLOffset
        MOV     fp, #0
  ; so the user can get to hear about faults in his atexit procs, unset
  ;  inTrapHandler.  This is safe (will terminate) because all finalisation
  ; is one-shot.
        STRB    fp, [v6, #O_inTrapHandler]
        STMFD   sp!, {r0-r2}
        BL      Finalise
        LDMIA   sp!, {r0-r2}
        SWI     Exit

UpCallHandler
        TEQ     r0, #256
        MOVNE   pc, r14
; Entered in SWI mode.  A new application is starting (not started by system,
; for which there's a different UpCall handler).  It has the same MemoryLimit
; as this application, so is free to overwrite it.  We'd better close ourselves
; down.
; The register state is undefined, except that r13 must be the SWI stack
; pointer.
        STMFD   sp!, {r0-r3, v1-v6, sl, fp, lr}
        MOV     v6, r12
        WritePSRc PSRUSRMode, r0
        LDR     sl, [v6, #O_rootStackChunk]
        LDR     sp, [sl, #SC_size]
        ADD     sp, sl, sp
        ADD     sl, sl, #SC_SLOffset
        MOV     fp, #0
        BL      Finalise
        SWI     EnterSVC
        LDMFD   sp!, {r0-r3, v1-v6, sl, fp, pc}

InstallHandlers Keep
        ; r0 is zero for the initial call (previous values for the handlers
        ; to be saved).
        ; If non-zero, it is the value memoryLimit should be set to.
        STR     r0, [sp, #-4]!
        MOV     r8, r0
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        ADD     r4, v6, #O_IIHandlerInData
        ADD     r5, v6, #O_PAHandlerInData
        ADD     r6, v6, #O_DAHandlerInData
        ADD     r7, v6, #O_AEHandlerInData
        SWI     SetEnv
        CMP     r8, #0
        ADDEQ   r8, v6, #O_oldAbortHandlers
        STMEQIA r8!, {r4-r7}

        MOV     r0, #Env_ExitHandler
        ADR     r1, ExitHandler
        MOV     r2, v6
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2}

        MOV     r0, #Env_MemoryLimit
        LDR     r1, [sp], #4
        SWI     ChangeEnv
        STREQ   r1, [r8], #4

        MOV     r0, #Env_ErrorHandler
        ADR     r1, ErrorHandler
        MOV     r2, v6
        ADD     r3, v6, #O_errorBuffer
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2, r3}

        ; callback, escape and event handlers must be updated atomically
        SWI     IntOff

        MOV     r0, #Env_CallBackHandler
        ADR     r1, CallBackHandler
        MOV     r2, v6
        ADD     r3, v6, #O_registerDump
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2, r3}

        MOV     r0, #Env_EscapeHandler
        ADR     r1, EscapeHandler
        MOV     r2, v6
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2}

        MOV     r0, #Env_EventHandler
        ADR     r1, EventHandler
        MOV     r2, v6
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2}

        SWI     IntOn

        MOV     r0, #Env_UpCallHandler
        ADR     r1, UpCallHandler
        MOV     r2, v6
        SWI     ChangeEnv
        STMEQIA r8!, {r1, r2}

        Return  ,LinkNotStacked


InstallCallersHandlers Keep
        ADD     r8, v6, #O_oldAbortHandlers
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        LDMIA   r8!, {r4-r7}
        SWI     SetEnv

        MOV     r0, #Env_ExitHandler
        LDMIA   r8!, {r1, r2}
        SWI     ChangeEnv

        MOV     r0, #Env_MemoryLimit
        LDR     r1, [r8], #4
        SWI     ChangeEnv
        MOV     r4, r1

        MOV     r0, #Env_ErrorHandler
        LDMIA   r8!, {r1, r2, r3}
        SWI     ChangeEnv

        ; callback, escape and event handlers must be updated atomically
        SWI     IntOff

        MOV     r0, #Env_CallBackHandler
        LDMIA   r8!, {r1, r2, r3}
        SWI     ChangeEnv

        MOV     r0, #Env_EscapeHandler
        LDMIA   r8!, {r1, r2}
        SWI     ChangeEnv

        MOV     r0, #Env_EventHandler
        LDMIA   r8!, {r1, r2}
        SWI     ChangeEnv

        SWI     IntOn

        MOV     r0, #Env_UpCallHandler
        LDMIA   r8!, {r1, r2}
        SWI     ChangeEnv

        Return  ,LinkNotStacked



 ;*-------------------------------------------------------------------*
 ;* Error handler                                                     *
 ;*-------------------------------------------------------------------*

ErrorHandler Keep
; Now Brazil compatibility is discarded and all SWI calls in the library
; are X-bit set (other than _kernel_swi if non-X bit set has been explicitly
; asked for), any error is treated as fatal here.
;
; Entry with static data base in r0.  User mode, interrupts on
; Since it would be nice to preserve as much as possible for the FP fault case
; we switch back to SWI mode to save the registers.
        SWI     EnterSVC

        LDR     r14, [r0, #O_errorNumber]
        TEQ     r14, #Error_IllegalInstruction
        TEQNE   r14, #Error_PrefetchAbort
        TEQNE   r14, #Error_DataAbort
        TEQNE   r14, #Error_AddressException
  [ SASTMhatbroken
        ADDNE   r14, r0, #O_registerDump
        STMNEIA r14!, {r0-r12}
        STMNEIA r14, {r13,r14}^
        NOP
        SUBNE   r14, r14, #13*4
  |
        STMNEIA r14, {r0-r14}^
  ]

        MOV     r12, r0
        ADD     r0, r0, #O_errorNumber
        BEQ     AbortFindHandler

        LDMDA   r0, {r1, r2}            ; r1 is error pc, r2 error number
        MOV     r14, #0
        STR     r14, [r12, #O_registerDump+16*4]        ; zero PSR
        MRS     r14, CPSR
        TST     r14, #2_11100
        BICEQ   r1, r1, #&fc000003      ; Sanitize PC value
        CMP     r2, #Error_BranchThroughZero
        MOVEQ   r1, #0
        STR     r1, [r12, #O_registerDump+pc*4]
        B       AbortFindHandler

 ;*-------------------------------------------------------------------*
 ;* Escape and event handling                                         *
 ;*-------------------------------------------------------------------*

|_kernel_escape_seen|
      [ No32bitCode
        MOV     a4, r14
        LoadStaticBase a3, ip
        MOV     a2, #0
        TST     r14, #PSRSVCMode
        SWIEQ   EnterSVC
        TEQP    pc, #PSRIBit+PSRSVCMode  ; interrupts off, for atomic read and update
        LDRB    a1, [a3, #O_escapeSeen]
        STRB    a2, [a3, #O_escapeSeen]
        MOVS    pc, a4
      |
        LoadStaticBase a3
      [ SupportARMK :LAND: NoARMK
        LDR     a4, [a3, #O__swp_available]
        TST     a4, #4 ; CPU supports LDREXB?
      ]
        MOV     a2, #0
        ADD     a3, a3, #O_escapeSeen :AND: :NOT: &FF
        ADD     a3, a3, #O_escapeSeen :AND: &FF         ; Yuckeroo
      [ SupportARMK
       [ NoARMK
        SWPEQB  a1, a2, [a3]
        BEQ     %FT02
       ]
01      LDREXB  a1, [a3]
        STREXB  a4, a2, [a3]
        TEQ     a4, #1
        BEQ     %BT01
02
      |
        SWPB    a1, a2, [a3]
      ]
        Return  "", LinkNotStacked
      ]

EventHandler Keep
        TEQ     r0, #4
        MOVEQ   pc, lr
        STMFD   r13!, {r11, r14}
        STR     r0, [r12, #O_eventCode]
        ADD     r11, r12, #O_eventRegisters
      [ {FALSE} ; this instruction is now deprecated
        STMIA   r11, {r0-r10, r13}
      |
        STMIA   r11, {r0-r10}
        STR     r13, [r11, #11*4]
      ]

        STMDB   r11, {r13}^
        MOV     v6, r12
        MOV     v2, r11
        LDMIB   r12, {v4, v5}
02      CMP     v4, v5
        BGE     EndFastEventHandlers
        LDR     v1, [v4]
        CMP     v1, #lang_FastEvent
        LDRGT   r1, [v4, #lang_FastEvent]
        CMPGT   r1, #0
        BLE     %F01
        MOV     a1, v2
        MOV     v1, r12
        MOV     fp, #0                          ; nb fp is NOT r13
        ; SL not set up - handlers must not have stack checking on,
        ; and may not require relocation of data references.
        MOV     r14, pc
        MOV     pc, r1
        MOV     r12, v1
01      ADD     v4, v4, v1
        B       %B02
EndFastEventHandlers
        ; If callback is possible (not already in a callback), set r12 to 1 to
        ; request it.
        LDRB    r12, [v6, #O_callbackInactive]

        ADD     v6, v6, #O_eventRegisters
        LDMIA   v6, {r0-r10}
        LDMFD   r13!, {r11, pc}


EscapeHandler Keep
        TSTS    r11, #&40
        BNE     haveEscape
        STR     r0, [r13, #-4]!
        MOV     r0, #0
        STRB    r0, [r12, #O_hadEscape]
        LDR     r0, [r13], #4
        MOV     pc, r14         ; ignore flag going away

haveEscape
        ; In Arthur, it is NEVER safe to call a handler now: we always have to
        ; wait for CallBack.
        STR     r0, [r13, #-4]!
        MOV     r0, #-1
        STRB    r0, [r12, #O_hadEscape]
        LDRB    r0, [r12, #O_eventCode]
        STRB    r0, [r12, #O_escapeSeen]
        STR     r0, [r12, #O_eventCode]
        LDRB    r11, [r12, #O_callbackInactive]
        CMP     r11, #0
        MOVNE   r12, #1
        LDR     r0, [r13], #4
        MOV     pc, r14

; Callback handler - entered in either SWI or IRQ mode, interrupts disabled,
; just before OS return to user mode with interrupts on.
CallBackHandler Keep
        ; Set 'in callback' to prevent callback being reentered before it finishes
        ; when we enable interrupts later on.
        MOV     r0, #0
        STRB    r0, [r12, #O_callbackInactive]

        MRS     r0, CPSR
        TST     r0, #2_11100

        MOV     v6, r12                 ; get SB into our standard place
        ; Copy the register set from our static callback buffer, onto the stack
        ; (If we appear to have a valid stack pointer).  Otherwise, we just
        ; ignore the event.
        ADD     r11, v6, #O_registerDump+16*4
        LDR     r10, [v6, #O_registerDump+sl*4]
        LDR     r1, [v6, #O_heapBase]
        LDR     r2, [v6, #O_heapLimit]
        LDR     r3, =IsAStackChunk

        ; if in a 26-bit mode - mark PSR in register dump as invalid.
        MOVEQ   r12, #-1
        STREQ   r12, [r11]

        LDR     r12, [v6, #O_registerDump+sp*4]
        LDR     v5, [v6, #O_registerDump+fp*4]
        CMP     r12, r1
        CMPHI   r2, r12         ; sp within heap and ...
        CMPHI   r10, r1
        CMPHI   r2, r10         ; sl within heap and ...
        CMPHI   r12, r10        ; sp > sl and ...
        BLS     Event_BadStack
        TST     r10, #3         ; sl word aligned
        TSTEQ   r12, #3         ; sp word aligned
        LDREQ   r4, [r10, #SC_mark-SC_SLOffset]
        CMPEQ   r4, r3          ; sl points at stack chunk
        BEQ     Event_StackOK
Event_BadStack
        MOV     r12, #-1
        B       Event_NoStackForHandler

Event_StackOK

        LDMDA   r11!, {r0-r7, r14}
        STMDB   r12!, {r0-r7, r14}
        LDMDA   r11!, {r0-r7}
        STMDB   r12!, {r0-r7}

Event_NoStackForHandler
        WritePSRc PSRIBit+PSRSVCMode, r1; we want the testing for an escape and
        MOV     r1, #1                  ; allowing callbacks to be indivisible
        LDRB    r0, [v6, #O_hadEscape]  ; (otherwise an escape may be lost).
        STRB    r1, [v6, #O_callbackInactive]
        MOV     r1, #0
        STRB    r1, [v6, #O_hadEscape]
        LDR     v1, [v6, #O_eventCode]
        TEQ     r0, #0                  ; if hadEscape = 0
        CMPEQ   v1, #-1                 ; and it's an escape event
        BEQ     %FT02                   ; then the escape's gone.
        CMP     r0, #0
        BEQ     %FT01
        MOV     r0, #126                ; acknowledge escape
        SWI     Byte
        MOV     v1, #-1                 ; escape overrides everything else
01
        [ {CONFIG}=26
        TEQP    pc, #PSRIBit            ; to user mode, with interrupts off
        NOP
        |
        WritePSRc PSRIBit+PSRUSRMode, r0
        ]

        CMP     r12, #0
        BGE     CallEventHandlers
02
        ADD     r0, v6, #O_registerDump
        B       ReloadUserState

CallEventHandlers
        MOV     sp, r12
        ASSERT  sl = r10
        MOV     fp, v5
        SWI     IntOn
        MOV     r0, sp
        MOV     v2, #lang_Event
        BL      FindAndCallHandlers

        MOV     r0, sp
        MOV     v2, #lang_UnhandledEvent
        BL      FindAndCallHandlers

        MOV     r0, sp
ReloadUserState
        ; Here we must unset the 'callback active' flag and restore our state
        ; from the callback buffer atomically. 3u ARMs unsupported now
        ; User r13, r14 must be reloaded from user mode.
        SWI     EnterSVC
        [ {CONFIG}=26
        TEQP    pc, #PSRIBit+PSRSVCMode
        NOP
        |
        LDR     r1, [r0, #16*4]
        CMP     r1, #-1
        MSRNE   CPSR_c, #PSR32IBit+PSR32SVCMode
        MSREQ   CPSR_c, #PSR32IBit+PSRSVCMode
        MSRNE   SPSR_cxsf, r1
        ]
        ADD     r14, r0, #pc*4
        LDMDB   r14, {r0-r14}^
        NOP
        LDMIA   r14, {pc}^

        LTORG

 ;*-------------------------------------------------------------------*
 ;* Debugging support                                                 *
 ;*-------------------------------------------------------------------*

FindHandler Keep
        ; find to which language the r1 corresponds (between which
        ; language's code bounds it lies).
        LDMIB   v6, {v4, v5}
01      CMP     v4, v5
        BHS     FH_NoHandlerFound
        LDMIA   v4, {r0, r2, r3}
        CMP     r1, r2
        CMPHS   r3, r1
        ADDLO   v4, v4, r0
        BLO     %B01

        ; If the language has a handler procedure of the right type, return
        ; it in r2 (otherwise 0)
        CMP     r0, v2
        LDRGT   r2, [v4, v2]
        MOVLE   r2, #0
        Return  ,LinkNotStacked

FH_NoHandlerFound
 [ SharedLibrary
        LDR     r0, =|RTSK$$Data$$Limit|
        CMP     v5, r0
        MOVNE   v5, r0
        LDRNE   v4, =|RTSK$$Data$$Base|
        BNE     %B01
 ]
        MOV     r2, #0
        Return  ,LinkNotStacked

; char *_kernel_language(int pc);
|_kernel_language|
        FunctionEntry "v2, v4-v6"
        LoadStaticBase v6, ip
        MOV     v2, #lang_name
        RemovePSRFromReg a1, lr, r1
        BL      FindHandler
        MOV     a1, r2
        Return  "v2, v4-v6"

; char *_kernel_procname(int pc);
|_kernel_procname|
        FunctionEntry "v2, v4-v6"
        LoadStaticBase v6, ip
        MOV     v2, #lang_ProcName
        RemovePSRFromReg a1, lr, r1
        BL      FindHandler
        CMP     r2, #0
        MOVEQ   a1, #0
        Return  "v2, v4-v6",,EQ

        MOV     a1, r1
 [ {CONFIG}=26
        MOV     lr, pc
        MOV     pc, r2          ; can't tail-call as may be APCS-32
        Return  "v2, v4-v6"
 |
        LDMFD   sp!, {v2, v4-v6, r14}
        MOV     pc, r2
 ]

; int _kernel_unwind(_kernel_unwindblock *inout, char **language);
|_kernel_unwind|
        FunctionEntry "a1, a2, v2, v4-v6"
        LoadStaticBase v6, ip
        LDR     r1, [a1, #uwb_pc]
        RemovePSRFromReg r1, lr
        MOV     v2, #lang_Unwind
        BL      FindHandler
        CMP     r2, #0
        BEQ     call_default_unwind_handler

 [ {CONFIG}=26                   
        LDMFD   sp!, {a1, a2}
        MOV     lr, pc
        MOV     pc, r2          ; can't tail-call as may be APCS-32
        Return  "v2, v4-v6"
 |
        LDMFD   sp!, {a1, a2, v2, v4-v6, r14}
        MOV     pc, r2
 ]

call_default_unwind_handler
        LDMFD   sp!, {a1, a2, v2, v4-v6, r14}
default_unwind_handler Keep
        STMFD   sp!, {v1-v6, r14}
        LoadStaticBase v6
        MOV     v2, #1
        STRB    v2, [v6, #O_unwinding]
        LDR     a4, [a1, #uwb_fp]
        BICS    a4, a4, #ChunkChange
        MOVEQ   v5, #0
        BEQ     duh_exit

        ; a minimal sensibleness check on the FP's value
        ; (bottom bit used to mark stack extension, masked out above).

        TST     a4, #&00000002
        BNE     duh_corrupt

        LDR     a3, [a4, #frame_entrypc]
        RemovePSRFromReg a3, v1

        TST     a3, #3                  ; If low bits of PC set...
        BNE     duh_corrupt             ; ...then either stack corrupt or was in Thumb mode (and if Thumb, the STM check below will fail anyway)

        STMFD   sp!, {a1-a2}
        MOV     a1, #0
        SWI     XOS_PlatformFeatures
        MOVVS   a1, #0
        TST     a1, #8                  ; Is it PC+8 or PC+12?
        ADDNE   a3, a3, #4
        LDMFD   sp!, {a1-a2}

        LDR     v1, [a3, #-12]

        ; check that the save mask instruction is indeed the right sort of STM
        ; If not, return indicating stack corruption.
        MOV     ip, v1, LSR #16
        EOR     ip, ip, #&e900
        EORS    ip, ip, #&002d          ; STMFD sp!, ... (sp = r13)
        BNE     duh_corrupt

        ; update register values in the unwindblock which the save mask says
        ; were saved in this frame.
        MOV     ip, #1
        ADD     v2, a4, #frame_prevfp
        MOV     v3, #v6
        ADD     v4, a1, #uwb_r4-r4*4
01      TST     v1, ip, ASL v3
        LDRNE   r14, [v2, #-4]!
        STRNE   r14, [v4, v3, ASL #2]
        SUB     v3, v3, #1
        CMP     v3, #v1
        BGE     %B01

        ; skip over saved arguments
16      TST     v1, ip, ASL v3
        SUBNE   v2, v2, #4
        SUBS    v3, v3, #1
        BGE     %B16

        ; now look for floating point stores immediately after the savemask
        ; instruction, updating values in the saveblock if they are there.
        SUB     a3, a3, #8
        LDR     v1, [a3]                ; check for SUB fp, ip, #n
        LDR     v4, =&e24cb             ; (assumes fp=r11, ip=r12)
        CMP     v4, v1, LSR #12
        ADDEQ   a3, a3, #4              ; skip over it

        ; first look for SFM F4,<count>,[sp,#-count*12]!
        LDR     v4, =&ed2d4200          ; assume sp = r13 if SFM
        LDR     v1, [a3]
        LDR     r14, =&004080ff         ; ignore count + offset
        BIC     r14, v1, r14
        CMP     r14, v4
        BNE     UnwindNotSFM            ; it's not SFM

        LDRB    v3, [v6, #O_fpPresent]
        TEQ     v3, #0
        BEQ     UnwindEndFP             ; can only unwind this if FP present
        AND     v3, v1, #&FF            ; v3 = offset
        AND     v4, v1, #&8000          ; v4 = bottom bit of count
        TST     v1, #&400000
        ORRNE   v4, v4, #&10000         ; add in top bit
        MOVS    v4, v4, LSR #15
        MOVEQ   v4, #4                  ; v4 = count
        ADD     v4, v4, v4, LSL #1      ; v4 = count * 3
        TEQ     v4, v3
        BNE     UnwindEndFP             ; count didn't match offset

        ADD     v3, a1, #uwb_f4         ; v3 -> uwb_f4
        SUB     v2, v2, v4, LSL #2      ; pull v2 down to base of stored FP regs
15      LFM     f0, 1, [v2], #12
        SUBS    v4, v4, #3
        STFE    f0, [v3], #12
        BNE     %B15
        B       UnwindEndFP

        ; or alternatively multiple STFE Fn,[sp,#-12]!
UnwindNotSFM
        LDR     v4, =&ed6c0103
02      LDR     v1, [a3], #+4
        BIC     r14, v1, #&17000        ; sp = r12 or r13
        CMP     r14, v4
        BNE     UnwindEndFP
        MOV     v1, v1, LSR #10
        AND     v1, v1, #&1c
        ADD     v1, v1, v1, ASL #1
        ADD     v1, a1, v1
        LDR     r14, [v2, #-4]!
        STR     r14, [v1, #uwb_f4-r4*4*3+8]
        LDR     r14, [v2, #-4]!
        STR     r14, [v1, #uwb_f4-r4*4*3+4]
        LDR     r14, [v2, #-4]!
        STR     r14, [v1, #uwb_f4-r4*4*3]
        B       %B02

UnwindEndFP
        LDMDB   a4, {a3, a4, v1}        ; saved fp, sp, link
        ; if the new fp is in a different stack chunk, must amend sl
        ; in the unwind block.
        TST     a3, #ChunkChange
        BIC     a3, a3, #ChunkChange
        LDR     v3, [a1, #uwb_sl]
        LDRNE   v3, [v3, #SC_prev-SC_SLOffset]
        ADDNE   v3, v3, #SC_SLOffset
        ADD     ip, a1, #uwb_fp
        STMIA   ip, {a3, a4, v1, v3}
        MOV     v3, a2
        RemovePSRFromReg v1, v2, r1
        MOV     v2, #lang_name
        BL      FindHandler
        STR     r2, [v3]
        MOV     v5, #1
duh_exit
        MOV     a1, #0
        STRB    a1, [v6, #O_unwinding]
        MOV     a1, v5
        Return  "v1-v6"

duh_abort
        LDR     r12, [v6, #O_registerDump+r12*4]  ; abort handling trampled this.
        MOV     r14, #0
        MRS     r14, CPSR
        TST     r14, #2_11100
        LDRNE   r14, [v6, #O_registerDump+16*4]
        MSRNE   CPSR_c, r14
        LDREQ   r14, [v6, #O_registerDump+pc*4]
        TEQEQP  r14, #0                 ; Back to the mode and interrupt
                                        ; status before we got the abort
        NOP
duh_corrupt
        MOV     v5, #-1
        B       duh_exit


 ;*-------------------------------------------------------------------*
 ;* SWI interfaces                                                    *
 ;*-------------------------------------------------------------------*


|_kernel_hostos|
        EnterLeafProcContainingSWI
        MOV     r0, #0
        MOV     r1, #1
        SWI     Byte
        MOV     a1, r1
        ExitLeafProcContainingSWI

; Abort handlers assume that lr is preserved
|_kernel_swi_c|
        FunctionEntry "a3, a4, v1-v6", makeframe
        BIC     r12, a1, #&80000000
        TST     a1, #&80000000          ; non-X bit requested?
        ORREQ   r12, r12, #X
        LDMIA   r1, {r0-r9}
        SWI     XOS_CallASWIR12
        LDMFD   sp!, {ip, lr}
        STMIA   ip, {r0 - r9}
        MOV     ip, #0
        MOVCS   ip, #1
        MOVVS   ip, #0
        STR     ip, [lr]
        MOVVC   a1, #0
        BLVS    CopyError               ; BL<cond> 32-bit OK
        Return  "v1-v6", fpbased

; Abort handlers assume that lr is preserved
|_kernel_swi|
        FunctionEntry "a3, v1-v6"
        BIC     r12, a1, #&80000000
        TST     a1, #&80000000
        ORREQ   r12, r12, #X
        LDMIA   r1, {r0-r9}
        SWI     XOS_CallASWIR12
        LDR     ip, [sp]
        STMIA   ip, {r0-r9}
        MOVVC   a1, #0
        BLVS    CopyError               ; BL<cond> 32-bit OK
        Return  "a3, v1-v6"


|_kernel_command_string|
        LoadStaticBase a1
        LDR     a1, [a1, #O_ArgString]
        Return  ,LinkNotStacked

|_kernel_osbyte|
        FunctionEntry "v6"
        SWI     Byte
        BVS     ErrorExitV6Stacked
        AND     a1, a2, #&ff
        ORR     a1, a1, a3, ASL #8
        MOV     a1, a1, ASL #16
        ADC     a1, a1, #0
        MOV     a1, a1, ROR #16
        Return  "v6"

|_kernel_osrdch|
        FunctionEntry "v6"
        SWI     ReadC
        BVS     ErrorExitV6Stacked
        Return  "v6",,CC
        CMPS    a1, #27         ; escape
        MOVEQ   a1, #-27
        MOVNE   a1, #-1         ; other error, EOF etc
        Return  "v6"

|_kernel_oswrch|
        FunctionEntry "v6"
        SWI     XOS_WriteC
        Return  "v6",,VC
ErrorExitV6Stacked
        BL      CopyError
        MOV     a1, #-2
        Return  "v6"

|_kernel_osbget|
        FunctionEntry "v6"
        MOV     r1, a1
        SWI     BGet
        BVS     ErrorExitV6Stacked
        MOVCS   a1, #-1
        Return  "v6"

|_kernel_osbput|
        FunctionEntry "v6"
        SWI     BPut
        Return  "v6",,VC
        BVS     ErrorExitV6Stacked

|_kernel_osgbpb|
; typedef struct {
;         void * dataptr;
;         int nbytes, fileptr;
;         int buf_len;
;         char * wild_fld;
; } _kernel_osgbpb_block;
; int _kernel_osgbpb(int op, unsigned handle, _kernel_osgbpb_block *inout);
        FunctionEntry "r4, r5, r6, r7, v6"
        MOV     r7, a3
        LDMIA   a3, {r2 - r6}
        SWI     Multiple
        STMIA   r7, {r2 - r6}
        BLVS    CopyError               ; BL<cond> 32-bit OK
        MOVCS   a1, #-1                 ; CopyError preserves C and V
        MOVVS   a1, #-2
        Return  "r4, r5, r6, r7, v6"

|_kernel_osword|
        FunctionEntry "v6"
        SWI     Word
        BVS     ErrorExitV6Stacked
        MOV     a1, r1
        Return  "v6"

|_kernel_osfind|
        FunctionEntry "v6"
        SWI     XOS_Find
        Return  "v6",,VC
        BVS     ErrorExitV6Stacked

|_kernel_osfile|
; typedef struct {
;         int load, exec;
;         int start, end;
; } _kernel_osfile_block;
; int _kernel_osfile(int op, const char *name, _kernel_osfile_block *inout);
        FunctionEntry "r4-r6,v6"
        MOV     r6, a3
        LDMIA   a3, {r2 - r5}
        SWI     XOS_File
        STMIA   r6, {r2 - r5}
        BLVS    CopyError               ; BL<cond> 32-bit OK
        MOVVS   a1, #-2
        Return  "r4-r6,v6"

|_kernel_osargs|
        FunctionEntry "v6"
        MOV     ip, a1
        ORR     ip, ip, a2
        SWI     Args
        BVS     ErrorExitV6Stacked
        CMP     ip, #0
        MOVNE   a1, r2
        Return  "v6"

|_kernel_oscli|
        FunctionEntry "v6"
        SWI     CLI
        BVS     ErrorExitV6Stacked
        MOV     a1, #1      ; return 1 if OK
        Return  "v6"

|_kernel_last_oserror|
        LoadStaticBase ip, a1
        LDR     a1, [ip, #O_errorBuffer]
        CMP     a1, #0
        ADDNE   a1, ip, #O_errorNumber
        MOVNE   a2, #0
        STRNE   a2, [ip, #O_errorBuffer]
        Return  ,LinkNotStacked

|_kernel_peek_last_oserror|
        LoadStaticBase ip, a1
        LDR     a1, [ip, #O_errorBuffer]
        TEQ     a1, #0
        ADDNE   a1, ip, #O_errorNumber
        Return  ,LinkNotStacked

|_kernel_system|
; Execute the string a1 as a command;  if a2 is zero, as a subprogram,
; otherwise a replacement.
;
        STMFD   sp!, {v1-v6, r14}
        LoadStaticBase  v6, ip
        LDRB    v5, [v6, #O_fpPresent]
        CMPS    v5, #0
        SFMNEFD f4, 4, [sp]!
        RFSNE   v5
        STMFD   sp!, {a1, v5}

        LDR     v5, [v6, #O_heapLimit]
        LDR     v4, [v6, #O_heapTop]
        LDR     v3, [v6, #O_imageBase]
        ; if the heap has been extended, copying the image is futile at best
        ; (and maybe harmful if it has a hole)
        LDR     v2, [v6, #O_initSlotSize]
        CMP     v5, v2
        MOVGT   v4, v5                  ; so pretend top = limit.

; Calculate len of image and size of gap.  We will not bother copying at all if gap
; is too small (but can't fault, because the command may not be an application)
        SUB     r0, v4, v3              ; Len = heapTop - imageBase
        ADD     r0, r0, #15
        BIC     v2, r0, #15             ; rounded Len, multiple of 16
        SUB     r14, v5, v3             ; heapLimit - imageBase
        SUB     r14, r14, v2            ; Gap = (heapLimit -imageBase) - Len
        ; if gap is too small, don't bother with copy.  1024 is an arbitrary
        ; small number, but what this is mainly aiming to avoid is the
        ; (otherwise possible) case of v6 < 0.
        CMP     r14, #1024
        MOVLT   r14, #0
      [ {FALSE} ; this instruction is now deprecated
        STMFD   sp!, {a2, v2-v5, r14, r15}   ; save them away
      |
        SUB     sp, sp, #4
        STMFD   sp!, {a2, v2-v5, r14}        ; save them away
      ]
                                        ;subr/chain, len, base, top, limit, gap
                                        ; hole for memoryLimit

        BL      InstallCallersHandlers  ; sets r4 to current memoryLimit
        STR     r4, [sp, #24]
        ADD     r14, sp, #16
        LDMIA   r14, {v5, r14}          ; recover limit, gap

        LDRB    r0, [v6, #O_underDesktop]  ; if under desktop, find what the
        CMP     r0, #0                     ; Wimp slot size currently is, so we
        MOVNE   r0, #Env_ApplicationSpace  ; can reset it later on
        MOV     r1, #0
        SWINE   ChangeEnv

        STR     r1, [sp, #-4]!          ; remember slot size
        ; All registers must be preserved whose values are wanted afterwards.
        ; v1 to v6 are already on the stack.
        ADD     ip, sp, r14
        ADD     r5, v6, #O_languageEnvSave
        STMIA   r5, {sl, fp, ip}        ; save ptr to moved stack
        ADD     v6, v6, r14             ; now points to the to be copied data
        ; Be careful with stack usage from here on out - anything we push now
        ; might get lost or overwritten. Once s_Exit restores sp everything
        ; will be OK again.

; The following loop copies the image up memory. It avoids overwriting
; itself by jumping to its copied copy as soon as it has copied itself,
; unless, of course, it's running in the shared C library...
; The image is copied in DECREASING address order.
CopyUp  CMP     r14, #0
        BEQ     CopyUpDone
        LDR     v2, [sp, #8]            ; image base
        LDR     v3, [sp, #12]           ; Len
        ADD     r1, v3, v2              ; imageBase + Len = initial src
        RemovePSRFromReg pc, v4, v4     ; where to copy down to before jumping
        CMP     v4, v5                  ; copy code > limit?
        ADDHI   v4, v3, #16             ; yes => in shared lib so fake v4
        MOVHI   v2, #0                  ; and don't jump to non-copied code
        MOVLS   v2, r14                 ; else jump to copied code
01      LDMDB   r1!, {r0,r2-r4}
        STMDB   v5!, {r0,r2-r4}
        CMP     r1, v4                  ; r1 < %B01 ?
        BHI     %B01                    ; no, so keep going...
  [ StrongARM
    ;in case we are jumping to code we have just copied here (ie not shared Clib)...
    CMP   v2, #0
    MOVNE r0, #0 ; Inefficient, but this is only for static lib version (also danger here with the call to SetWimpSlot_Save_r4r5?)
    SWINE XOS_SynchroniseCodeAreas
  ]
        ADD     r0, pc, v2              ; ... go to moved image
        MOV     pc, r0                  ; and continue copying up...
01      LDMDB   r1!, {r0,r2-r4}
        STMDB   v5!, {r0,r2-r4}
        CMP     r1, v3                  ; src > imageBase ?
        BHI     %B01                    ; yes, so continue

  ;StrongARM - no need to synchronise for rest of copied code here, since we will not
  ;be executing it (we have to synchronise later, after copying down)

CopyUpDone
        ; ip is the relocated sp.
        LDR     r0, [ip, #4]           ; chain/subr
        CMP     r0, #0
        BNE     %FT01

        MOV     r0, #Env_MemoryLimit
        LDR     r1, [v6, #O_imageBase]
        ADD     r1, r1, r14
        SWI     ChangeEnv

        MOV     r0, #Env_ErrorHandler
        ADR     r1, s_ErrHandler
        MOV     r2, v6
        ADD     r3, v6, #O_errorBuffer
        SWI     ChangeEnv

        MOV     r0, #Env_ExitHandler
        ADR     r1, s_ExitHandler
        MOV     r2, v6
        SWI     ChangeEnv

        MOV     r0, #Env_UpCallHandler  ; We don't really want one of these, ...
        ADR     r1, s_UpCallHandler     ; but RISCOS rules say we must have it
        MOV     r2, v6
        SWI     ChangeEnv

01      LDR     r0, [ip, #32]           ; the CLI string to execute
        ADD     r0, r0, r14             ; ... suitably relocated...

        SWI     OS_CLI                  ; force non-X variant
        B       s_Exit

s_UpCallHandler
        MOV     pc, r14

s_ErrHandler
        MOV     v6, r0
        MOV     r0, #-2
        B       s_Exit2

s_ExitHandler
        MOV     v6, r12
s_Exit
        MOV     r0, #0
s_Exit2
        ADD     r5, v6, #O_languageEnvSave
      [ {FALSE} ; this instruction is now deprecated
        LDMIA   r5, {sl, fp, sp}
      |
        LDMIA   r5, {sl, fp}
        LDR     sp, [r5, #2*4]
      ]
        LDMFD   sp!, {a2, a3, v1-v5}    ; slotsize,
                                        ;subr/chain, Len, Base, Top, Limit, Gap
        STR     r0, [sp, #4]            ; ... over prev saved r0...
        CMP     a3, #0
        SWINE   Exit
        MOVS    a1, a2
        BEQ     %FT01
        BL      SetWimpSlot_Save_r4r5   ; set slot size back to value before CLI
        LDMFD   sp!, {r4, r5}

01
  [ StrongARM
        STR     v2, [sp, #-4]!          ; remember base for later
  ]
        SUB     sp, sp, v5              ; and relocate sp...
        SUB     v6, v6, v5              ; ...and the static data ptr

; The following loop copies the image down memory. It avoids overwriting
; itself by jumping to its copied copy as soon as it has copied itself,
; unless of course, this code is running in the shared C library...
; The image is copied in ASCENDING address order.
        CMP     v5, #0
        BEQ     CopyDnDone
CopyDn
        SUB     r0, v4, v1              ; limit - L = init src
        RemovePSRFromReg pc, v3, v3     ; == BIC v3, pc, #&FC000003 in 26bit
        ADD     v3, v3, #%F02-.-4       ; where to copy to before jumping
        CMP     v3, v4                  ; copy code > limit?
        SUBHI   v3, v4, #16             ; yes => in shared lib so fake v3
        MOVHI   v1, #0                  ; and don't jump to not copied code...
        MOVLS   v1, v5                  ; else jump...
01      LDMIA   r0!, {r1-r3,ip}
        STMIA   v2!, {r1-r3,ip}
        CMP     r0, v3                  ; copied the copy code?
        BLO     %B01                    ; no, so continue...
  [ StrongARM
    ;in case we are jumping to code we have just copied here (ie not shared Clib)...
    MOV   r1, r0
    CMP   v1, #0
    MOVNE r0, #0 ; Inefficient, but this is only for static lib version
    SWINE XOS_SynchroniseCodeAreas
    MOV   r0, r1
  ]
        SUB     ip, pc, v1              ; yes => copied this far ...
        MOV     pc, ip                  ; ... so branch to copied copy loop
01      LDMIA   r0!, {r1-r3,ip}
        STMIA   v2!, {r1-r3,ip}
        CMP     r0, v4                  ; finished copying?
        BLO     %B01                    ; no, so continue...
02
CopyDnDone
  [ StrongARM
    ;you've guessed it
    MOV    r0, #1
    LDR    r1, [sp], #4
    MOV    r2, v2
    CMP    r1, r2
    SWINE  XOS_SynchroniseCodeAreas
  ]
        LDR     r0, [sp], #4            ; old memoryLimit
        BL      InstallHandlers

        LDMFD   sp!, {a1, v5}
        LDRB    v4, [v6, #O_fpPresent]
        CMPS    v4, #0
        WFSNE   v5
        LFMNEFD f4, 4, [sp]!
        Return  "v1-v6"

CopyError  Keep ; a1 is the address of an error block (may be ours)
                ; we want to copy its contents into our error block,
                ; so _kernel_last_oserror works.
        ; This routine MUST preserve the C and V flags across the call.
        ; The BICS only affects N and Z (C not changed as barrel shifter not used)
        LoadStaticBase v6, a2
CopyErrorV6OK
        MOV     a4, a1
        ADD     a2, v6, #O_errorNumber
CopyError2
        STR     pc, [a2, #-4]           ; mark as valid
        LDR     a3, [a4], #4
        STR     a3, [a2], #4
CopyErrorString
01      LDRB    a3, [a4], #+1
        STRB    a3, [a2], #+1
        BICS    a3, a3, #&1F            ; replaces CMP a3, #' '
        BNE     %B01                    ; replaces BCS %B01
        MOV     pc, lr

|_kernel_getenv|
; _kernel_oserror *_kernel_getenv(const char *name, char *buffer, unsigned size);
        FunctionEntry "v1,v2,v6", frame
        LoadStaticBase v6, ip
        SUB     r2, r2, #1
        MOV     r3, #0
        MOV     r4, #3
        SWI     XOS_ReadVarVal
        MOVVC   a1, #0
        STRVCB  a1, [r1, r2]
        BLVS    CopyError               ; BL<cond> 32-bit OK
        Return  "v1,v2,v6", "fpbased"

|_kernel_setenv|
; _kernel_oserror *_kernel_setenv(const char *name, const char *value);
        FunctionEntry "v1,v6"
        LoadStaticBase v6, ip
        ; Apparently, we need to say how long the value string is as well
        ; as terminating it.
        TEQ     a2, #0
        MOV     a3, #-1
01      ADDNE   a3, a3, #1
        LDRNEB  ip, [a2, a3]
        CMPNE   ip, #0
        BNE     %B01
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_SetVarVal
        MOVVC   a1, #0
        BLVS    CopyError               ; BL<cond> 32-bit OK
        Return  "v1,v6"

 ;*-------------------------------------------------------------------*
 ;* Storage management                                                *
 ;*-------------------------------------------------------------------*

|_kernel_register_allocs|
; void _kernel_register_allocs(allocproc *malloc, freeproc *free);
        LoadStaticBase ip, a3
        ADD     ip, ip, #O_allocProc
        STMIA   ip, {a1, a2}
        Return  ,LinkNotStacked


|_kernel_register_slotextend|
        LoadStaticBase ip, a3
        MOVS    a2, a1
        LDR     a1, [ip, #O_heapExtender]
        STRNE   a2, [ip, #O_heapExtender]
        Return  ,LinkNotStacked

|_kernel_alloc|
; unsigned _kernel_alloc(unsigned minwords, void **block);
;  Tries to allocate a block of sensible size >= minwords.  Failing that,
;  it allocates the largest possible block of sensible size.  If it can't do
;  that, it returns zero.
;  *block is returned a pointer to the start of the allocated block
;  (NULL if none has been allocated).
        LoadStaticBase ip, a3

        CMP     r0, #2048
        MOVLT   r0, #2048

        ADD     ip, ip, #O_heapTop
        LDMIA   ip, {r2, r3}

        SUB     r3, r3, r0, ASL #2      ; room for a block of this size?
        CMP     r3, r2                  ; if so, ...
        BGE     alloc_return_block

        ; There's not going to be room for the amount required.  See if
        ; we can extend our workspace.
        LDRB    r3, [ip, #O_underDesktop-O_heapTop]
        CMP     r3, #0
 [ SharedLibrary
; See if we are allowed to extend the wimp-slot - depends on the stub vintage
; if running under the shared library. If not shared, we can do it provided
; we're running under the desktop.
        LDRNEB  r3, [ip, #O_kallocExtendsWS-O_heapTop]
        CMPNE   r3, #0
 ]
        BEQ     alloc_cant_extend       ; not under desktop or old stubs

        STMFD   sp!, {r0, r1, lr}

        LDR     r3, [ip, #O_heapExtender-O_heapTop]
        CMP     r3, #0
        BEQ     alloc_no_extender
        LDR     r0, [sp], #-4           ; ask for the amount we were asked for
        MOV     r0, r0, ASL #2          ; (since what we are given may well
                                        ;  not be contiguous with what we had
                                        ;  before).
        ; Set to a silly value, guaranteed not to be equal to initSlotSize, to ensure
        ; reset on exit.
        STR     r3, [ip, #O_knownSlotSize-O_heapTop]
        MOV     r1, sp
        MOV     lr, pc
        MOV     pc, r3
        LoadStaticBase ip, a3           ; restore our static base
        ADD     ip, ip, #O_heapTop
        LDR     r1, [sp], #+4           ; base of area acquired
        CMP     r0, #0                  ; size (should be 0 or big enough)
        BEQ     alloc_cant_extend_0

        LDMIA   ip, {r2, lr}
        CMP     lr, r1
        SUBNE   r3, lr, r2              ; if not contiguous with old area, amount free
        ADD     lr, r1, r0              ; adjust heapLimit
        MOVNE   r0, r2                  ; if not contiguous, remember old heapTop
        MOVNE   r2, r1                  ; and adjust
        STMIA   ip, {r2, lr}
        CMPNE   r3, #0                  ; if contiguous, or old area had no free space,
        BEQ     alloc_cant_extend_0     ; return from new area

        ADD     sp, sp, #4              ; otherwise, return block from top of old area
        LDMFD   sp!, {r1, lr}           ; first (malloc will try again and get from
        STR     r0, [r1]                ; new area).
        MOV     r0, r3, ASR #2
        Return  ,LinkNotStacked

alloc_no_extender
        ; if current slotsize = heap limit, try to extend the heap by the
        ; amount required (or perhaps by just enough to allow allocation
        ; of the amount required)
        ADD     lr, r2, r0, ASL #2      ; heaptop if request could be granted
        MOV     r0, #Env_ApplicationSpace ; find current slotsize
        MOV     r1, #0
        SWI     ChangeEnv
        LDR     r0, [ip, #O_knownSlotSize-O_heapTop]
        CMP     r1, r0
        BNE     alloc_cant_extend_0

        ; If the extension will be contiguous with the current heap top,
        ; then we need just enough to allow the requested allocation.
        LDMIA   ip, {r2, r3}
        CMP     r3, r0
        BEQ     alloc_extend_slot
        ; Otherwise, we must extend by the amount requested.  If there's still
        ; some space left in the previous area, give that back first.
        CMP     r2, r3
        BNE     alloc_cant_extend_0
        STR     r0, [ip, #O_heapTop-O_heapTop]
        LDR     r2, [sp]
        ADD     lr, r0, r2, ASL #2
alloc_extend_slot
        ; lr holds the slot size we want.  r1 is the current memory limit.
        ; Now if memory limit is not slot size, we must reset memory limit
        ; temporarily over the call to Wimp_SlotSize (or it will refuse).
        MOV     r0, lr
        BL      SetWimpSlot_Save_r4r5
        LDMFD   sp!, {r4, r5}
        ADD     r0, r0, #Application_Base
        STR     r0, [ip, #O_knownSlotSize-O_heapTop]
        STR     r0, [ip, #O_heapLimit-O_heapTop]

alloc_cant_extend_0
        LDMFD   sp!, {r0, r1, lr}
alloc_cant_extend
        LDMIA   ip, {r2, r3}

        SUB     r3, r3, r0, ASL #2      ; room for a block of this size?
        CMP     r3, r2                  ; if so, ...

alloc_return_block
        STRGE   r2, [r1]                ; return it above the previous heapTop
        ADDGE   r2, r2, r0, ASL #2      ; and update heapTop
        STRGE   r2, [ip]
        Return  ,LinkNotStacked, GE

        ADD     r0, r0, r3, ASR #2      ; otherwise, return whatever is free
        SUB     r0, r0, r2, ASR #2
        CMP     r0, #0
        BGT     alloc_return_block

        STR     r0, [r1]                ; (if none, returned block is NULL,
        Return  ,LinkNotStacked         ; and don't update heapTop)


|_kernel_malloc|
; void * _kernel_malloc(int numbytes);
;  Allocates numbytes bytes (rounded up to number of words), and returns
;  the block allocated.  If it can't, returns NULL.
;  Normally, this will be replaced by the real malloc very early in the
;  startup procedure.
        LoadStaticBase ip, a2

        ADD     ip, ip, #O_heapTop
        LDMIA   ip, {r2, r3}

        SUB     r3, r3, r0              ; room for a block of this size?
        CMP     r3, r2                  ; if so, ...
        ADDGE   r3, r2, r0
        MOVGE   r0, r2                  ; return it above heapTop
        STRGE   r3, [ip]
        MOVLT   r0, #0
        Return  ,LinkNotStacked

|_kernel_free|
; void free(void *);
;  Frees the argument block.
;  Normally, this will be replaced by the real free very early in the
;  startup procedure.
;  I don't think there's much point in providing a real procedure for this;
;  if I do, it complicates malloc and alloc above.
        Return  ,LinkNotStacked

; In future these could be sophisticated allocators that associate
; allocated blocks with stack chunks, allowing longjmp() et al to
; clear them up. But for now, this suffices for C99's VLAs.
|__rt_allocauto|
        FunctionEntry
        LoadStaticBase ip, a2
        MOV     lr, pc
        LDR     pc, [ip, #O_allocProc]
        TEQ     a1, #0
        Return  ,,NE
        LoadStaticBase ip, a1
        LDR     lr, [sp], #4
        ADD     ip, ip, #O_registerDump
      [ {FALSE} ; this instruction is now deprecated
        STMIA   ip, {a1 - r14}
      |
        STMIA   ip, {a1 - r12}
        STR     r13, [ip, #13*4]
        STR     r14, [ip, #14*4]
      ]
        ADR     r0, E_StackOverflow
        BL      |_kernel_copyerror|
        SWI     GenerateError

|__rt_freeauto|
        LoadStaticBase ip, a2
        LDR     pc, [ip, #O_freeProc]


 ;*-------------------------------------------------------------------*
 ;* Stack chunk handling                                              *
 ;*-------------------------------------------------------------------*

|_kernel_current_stack_chunk|
        SUB     a1, sl, #SC_SLOffset
        Return  ,LinkNotStacked

 ;*-------------------------------------------------------------------*
 ;* Stack overflow handling                                           *
 ;*-------------------------------------------------------------------*

|_kernel_stkovf_split_0frame|
; Run out of stack.
; Before doing anything else, we need to acquire some work registers
; as only ip is free.
; We can save things on the stack a distance below fp which allows the
; largest possible list of saved work registers (r0-r3, r4-r9 inclusive,
; plus fp, sp, lr = 13 regs in total) plus a minimal stack
; frame for return from StkOvfExit (a further 4 words, giving 17 in total)
; plus 4 extended floating point registers (a further 3*4 words)
        MOV     ip, sp
|_kernel_stkovf_split|
        SUB     ip, sp, ip              ; size required
        SUB     sp, fp, #29*4
        STMFD   sp!, {a1, a2, v1-v6, lr}; to save a1-a2, v1-v6
 [ 0 = 1
        LoadStaticAddress disable_stack_extension, a1, lr
        LDR     a1, [a1]
        CMP     a1, #0
        BNE     StackOverflowFault
 ]
        ADD     v4, ip, #SC_SLOffset    ; required size + safety margin
        SUBS    v1, fp, #30*4           ; save area ptr, clear V flag
        BL      GetStackChunk
        BVS     StackOverflowFault
; Get here with v2 pointing to a big enough chunk of size v3
; (Not yet marked as a stack chunk)
        ADD     sl, v2, #SC_SLOffset    ; make the new sl
        ADD     sp, v2, v3              ; and initial sp
        LDR     a1, =IsAStackChunk
        STR     a1, [sl, #SC_mark-SC_SLOffset]
; v1 is save area in old frame... will be temp sp in old frame
        ADD     a1, v1, #4*4            ; temp fp in old frame
        LDMDA   fp, {v3-v6}             ; old fp, sp,lr, pc

        STMFD   sp!,{a1-a2}
        MOV     a1,#0
        SWI     XOS_PlatformFeatures
        MOVVS   a1,#0
        TST     a1,#8                   ; Stores PC+8 or PC+12?
        ADREQ   v6, StkOvfPseudoEntry+12
        ADRNE   v6, StkOvfPseudoEntry+8
        LDMFD   sp!,{a1-a2}

        STMDA   a1, {v3-v6}             ; new return frame in old chunk...
        ADR     lr, StackOverflowExit
        MOV     a2, sp                  ; saved sp in old frame = NEW sp
                                        ; (otherwise exit call is fatal)
        STMDB   fp, {a1, a2, lr}        ; pervert old frame to return here...
        [ {CONFIG}=26
        LDMDA   v1, {a1, a2, v1-v6, pc}^
        |
        LDMDA   v1, {a1, a2, v1-v6, pc}
        ]

|_kernel_stkovf_copy0args|
; Run out of stack.
; Before doing anything else, we need to acquire some work registers
; (IP is free in the StkOvf case, but not in the StkOvfN case).
; We can save things on the stack a distance below FP which allows the
; largest possible list of saved work registers (R0-R3, R4-9 inclusive,
; plus FP, SP, LR, entry PC, = 14 regs in total) plus 4 extended floating
; point registers, a further 3*4 words
        MOV     ip, #0                  ; STKOVF not STKOVFN
|_kernel_stkovf_copyargs|
; the (probable) write below sp here is inevitable - there are no registers
; free.  The only way to make this safe against events is to pervert sl
; temporarily.
        ADD     sl, sl, #4
        STR     lr, [fp, #-26*4]        ; save LR
        SUB     lr, fp, #26*4           ; & use as temp SP
        STMFD   lr!, {a1, a2, v1-v6}    ; to save A1-A2, V1-V6
       [ 0 = 1
        LoadStaticAddress disable_stack_extension, a1, lr
        LDR     a1, [a1]
        CMP     a1, #0
        BNE     StackOverflowFault
       ]
        SUB     v4, fp, sp              ; needed frame size
        ADD     v4, v4, #SC_SLOffset    ; + safety margin
        MOV     sp, lr                  ; got an SP now...
        SUB     sl, sl, #4
        ; We do not drop SL here : the code that gets called to acquire a new
        ; stack chunk had better not check for stack overflow (and also had
        ; better not use more than the minimum that may be available).
        SUBS    v1, fp, #26*4           ; save area ptr, clear V flag
        BL      GetStackChunk
        BVS     StackOverflowFault      ; out of stack

; Get here with V2 pointing to a big enough chunk of size V3
        ADD     sl, v2, #SC_SLOffset    ; make the new SL
        ADD     sp, v2, v3              ; and initial SP
        LDR     a1, =IsAStackChunk
        STR     a1, [sl, #SC_mark-SC_SLOffset]
; Copy over 5th and higher arguments, which are expected on the stack...
        CMP     ip, #0
        BLE     DoneArgumentCopy
01      LDR     v5, [fp, ip, ASL #2]    ; copy args in high->low
        STR     v5, [sp, #-4]!          ; address order
        SUBS    ip, ip, #1
        BNE     %B01
DoneArgumentCopy
; Now create a call frame in the new stack chunk by copying
; over stuff saved in the frame in the old stack chunk to the
; new, perverting LR so that, on return, control comes back to
; this code and perverting SP and FP to give us a save area
; containing none of the V registers.
        MOV     v1, fp                  ; old chunk's frame pointer
        SUB     ip, v4, #SC_SLOffset    ; needed frame size, no margin
        LDMDA   v1!, {a1, a2, v2-v6}    ; 1st 7 of possible 14 saved regs
        ADR     v5, StackOverflowExit
        MOV     v4, sp                  ; SP in NEW chunk
        ORR     v3, fp, #ChunkChange    ; new FP in old chunk
        SUB     fp, sp, #4              ; FP in new chunk
        STMFD   sp!, {a1, a2, v2-v6}    ; 1st 7 copied frame regs
        LDMDA   v1!, {a1, a2, v2-v6}    ; and the 2nd 7 regs
        STMFD   sp!, {a1, a2, v2-v6}    ; copied to the new frame

; Now adjust the PC value saved in the old chunk to say "no registers"
        MOV     a1,#0
        SWI     XOS_PlatformFeatures
        MOVVS   a1,#0
        TST     a1,#8                   ; PC+8 or PC+12?
        ADREQ   v2, StkOvfPseudoEntry+12
        ADRNE   v2, StkOvfPseudoEntry+8

        STR     v2, [v1, #26*4]
; Set the SP to be FP - requiredFrameSize and return by reloading regs
; from where they were saved in the old chunk on entry to STKOVF/N
        SUB     sp, fp, ip
        [ {CONFIG}=26
        LDMDA   v1, {a1, a2, v1-v6, pc}^
        |
        LDMDA   v1, {a1, a2, v1-v6, pc}
        ]

StkOvfPseudoEntry
        STMFD   sp!, {fp, ip, lr, pc}   ; A register save mask

StackOverflowExit Keep
; We return here when returning from the procedure which caused the
; stack to be extended. FP is in the old chunk SP and SL are still
; in the new one.

        ; We need to move sp and sl back into the old chunk.  Since this happens
        ; in two operations, we need precautions against events while we're
        ; doing it.
        ADD     sl, sl, #4              ; (an invalid stack-chunk handle)
        SUB     sp, fp, #3*4            ; get a sensible sp in the old chunk
        STMFD   sp!, {a1-a2, v1-v4}     ; Save some work regs
        MOV     v4, r14                 ; Remember if register permute needed
; Now see if the new chunk has a next chunk and deallocate it if it has.
        SUB     v1, sl, #4
        LDR     v2, [v1, #SC_next-SC_SLOffset]
        LDR     sl, [v1, #SC_prev-SC_SLOffset]
        LDR     a1, [sl, #SC_mark]      ; make not a stack chunk (before making
        EOR     a1, a1, #&40000000      ; sl a proper stackchunk handle).
        STR     a1, [sl, #SC_mark]
        ADD     sl, sl, #SC_SLOffset
        SUB     sp, sp, #4
DeallocateChunkLoop
        CMP     v2, #0                  ; is there a next next chunk?
        BEQ     DoneDeallocateChunks    ; No! - do nothing
        LDR     v3, [v2, #SC_next]      ; next chunk
        MOV     a1, v2
        LDR     ip, [v2,#SC_deallocate] ; deallocate proc for this chunk
        CMPS    ip, #0                  ; is there a proc?
        MOVEQ   v1, v2                  ; no deallocate proc: try next chunk
        BEQ     DeallocateChunkLoopSkip ; go around next chunk
        MOV     lr, pc
        MOV     pc, ip                  ; there was, so call it...
        MOV     a2, #0
        STR     a2, [v1, #SC_next-SC_SLOffset] ; and unhook next chunk
DeallocateChunkLoopSkip
        MOV     v2, v3
        B       DeallocateChunkLoop
DoneDeallocateChunks
; Clear the chunk change bit, and return to caller by reloading the saved work
; regs and the frame regs that were adjusted at the time the stack was extended
        LDR     a1, =IsAStackChunk
        STR     a1, [sl, #SC_mark-SC_SLOffset]
        BIC     fp, fp, #ChunkChange
; Return
        Return  "a1-a2, v1-v4", fpbased

GetStackChunk Keep
; Naughty procedure with non-standard argument conventions.
; On entry, V1 = save area ptr in case of error return; V4 = needed size;
; On exit, V1, and V4 are preserved, V2 points to the newly inserted chunk
; and V3 is the chunk's size. In case of error, V is set.
StkOvfGetChunk
      [ {CONFIG}=26
        TST     r14, #PSRSVCMode        ; in SWI mode, stack overflow is fatal
        ORRNES  pc, r14, #PSRVBit       ; (could have been detected earlier,
                                        ; but deferral to now is simpler).
      |
        MRS     v2, CPSR
        MOVS    v2, v2, LSL #28
        TEQHI   v2, #&F0000000          ; allow stack extension in SYS mode
        MSRNE   CPSR_f, #V_bit          ; maintain NE
        MOVNE   pc, lr
      ]
; Check that the current chunk really is a stack chunk...
        STMFD   sp!, {a3, a4, ip, lr}   ; save args not saved before
        LDR     v2, =IsAStackChunk      ; magic constant...
        LDR     v3, [sl, #SC_mark-SC_SLOffset]
        CMP     v2, v3                  ; matches magic in chunk?
        BNE     StkOvfError             ; No! - die horribly
        EOR     v3, v3, #&80000000      ; make not a stack chunk, so recursive
        STR     v3, [sl, #SC_mark-SC_SLOffset] ; extension faults
; We have a chunk, see if there's a usable next chunk...
        SUB     v2, sl, #SC_SLOffset
02      LDR     v2, [v2, #SC_next]
        CMP     v2, #0
        BEQ     StkOvfGetNewChunk       ; No! - so make one
        LDR     v3, [v2, #SC_size]
        CMP     v4, v3                  ; is it big enough?
        BGT     %B02                    ; No! so try next chunk
; unlink the usable chunk from the chain...
        LDR     a1, [v2, #SC_prev]      ; previous chunk
        LDR     a2, [v2, #SC_next]      ; next chunk
        STR     a2, [a1, #SC_next]      ; prev->next = next
        CMPS    a2, #0                  ; next == NULL ?
        STRNE   a1, [a2, #SC_prev]      ; next->prev = prev
        B       StkOvfInsertChunk
StkOvfGetNewChunk Keep
        ; Now we swap to the special extension chunk (to give a reasonable
        ; stack size to malloc).
        LoadStaticBase v2, ip
03      MOV     a1, #0
        ADD     a2, v2, #O_extendChunkNotInUse
      [ {CONFIG}=26
        LDR     lr, [v2, #O__swp_available]
        TEQ     lr, #0
        SWPNE   a1, a1, [a2]
        BLEQ    Arm2Swp
      |
       [ SupportARMv6
        [ NoARMv6
        LDR     lr, [v2, #O__swp_available]
        TST     lr, #2 ; CPU supports LDREX?
        SWPEQ   a1, a1, [a2]
        BEQ     %FT02
        ]
        MOV     lr, #0
01      LDREXB  a1, [a2]
        STREXB  a3, lr, [a2]
        TEQ     a3, #1
        BEQ     %BT01
02
       |
        SWP     a1, a1, [a2]
       ]
      ]
        TEQ     a1, #0
        BLEQ    Sleep                     ; preserves Z
        BEQ     %BT03
        LDR     a2, [v2, #O_extendChunk]
        LDR     a3, [a2, #SC_size]
        ADD     a3, a2, a3                ; new sp
      [ {FALSE} ; this instruction is now deprecated
        STMFD   a3!, {sl, fp, sp}         ; save old stack description
      |
        STR     sp, [a3, #-4]!
        STMFD   a3!, {sl, fp}             ; save old stack description
      ]
        MOV     sp, a3
        ADD     sl, a2, #SC_SLOffset
        MOV     fp, #0

        MOV     a1, #RootStackSize; new chunk is at least this big
        CMP     a1, v4            ; but may be bigger if he wants a huge frame
        MOVLT   a1, v4
        LDR     ip, [v2, #O_allocProc]
        CMPS    ip, #0
        BEQ     %F01                    ; (restore stack chunk, then error)
        LDR     lr, [v2, #O_freeProc]
        STMFD   sp!, {a1, lr}           ; chunk size in bytes, dealloc proc
        MOV     lr, pc
        MOV     pc, ip
        MOV     lr, v2
        MOVS    v2, a1
        LDMFD   sp!, {v3, ip}           ; size in bytes, dealloc
01
      [ {FALSE} ; this instruction is now deprecated
        LDMFD   sp, {sl, fp, sp}        ; back to old chunk
      |
        LDMFD   sp!, {sl, fp}           ; back to old chunk
        LDR     sp, [sp]
      ]
        MOV     a1, #1
        STR     a1, [lr, #O_extendChunkNotInUse]
        BEQ     StkOvfError
        STR     v3, [v2, #SC_size]
        STR     ip, [v2, #SC_deallocate]
        LDR     a1, [sl, #SL_Lib_Offset]
        STR     a1, [v2, #SL_Lib_Offset+SC_SLOffset]
        LDR     a1, [sl, #SL_Client_Offset]
        STR     a1, [v2, #SL_Client_Offset+SC_SLOffset]
; and re-link it in its proper place...
StkOvfInsertChunk
        SUB     a1, sl, #SC_SLOffset    ; chunk needing extension...
        LDR     a2, =IsAStackChunk
        STR     a2, [a1, #SC_mark]      ; remark as stack chunk
        LDR     a2, [a1, #SC_next]      ; its next chunk
        STR     a2, [v2, #SC_next]      ; this->next = next
        STR     v2, [a1, #SC_next]      ; prev->next = this
        STR     a1, [v2, #SC_prev]      ; this->prev = prev
        CMPS    a2, #0
        STRNE   v2, [a2, #SC_prev]      ; next->prev = this
        STR     pc, [v2, #SC_mark]      ; Not a stack chunk (for safe non-atomic
                                        ; update of sp and sl).
        Return  "a3, a4, ip"            ; restore extra saved regs
StkOvfError
        [ {CONFIG}=26
        LDMFD   sp!, {a3, a4, ip, lr}
        ORRS    pc, lr, #PSRVBit        ; return with V set
        |
        MSR     CPSR_f, #V_bit
        LDMFD   sp!, {a3, a4, ip, pc}
        ]

StackOverflowFault Keep
        LoadStaticBase ip, a1
        MOV     sp, v1
        LDMDA   v1, {a1, a2, v1-v6, lr}
        ADD     ip, ip, #O_registerDump
      [ {FALSE} ; this instruction is now deprecated
        STMIA   ip, {a1 - r14}
      |
        STMIA   ip, {a1 - r12}
        STR     r13, [ip, #13*4]
        STR     r14, [ip, #14*4]
      ]
        ADR     r0, E_StackOverflow
        BL      |_kernel_copyerror|
        SWI     GenerateError

        LTORG
        ErrorBlock StackOverflow, "Stack overflow", C45

 [ {CONFIG}=26
Arm2Swp ; like SWP a1,a1,[a2] but corrupts a3, lr and flags
        SWI     IntOff
        LDR     a3, [a2]
        STR     a1, [a2]
        SWI     IntOn
        MOV     a1, a3
        MOV     pc, lr
 |
AcquireMutex
        FunctionEntry
        MOV     a2, a1
  [ SupportARMv6
   [ NoARMv6
        LoadStaticBase a4, ip
        LDR     a1, [a4, #O__swp_available]
        TST     a1, #2 ; does CPU support LDREX?
        BEQ     %FT03
   ]
        MOV     a3, #0
  ]
        B       %FT02
  [ SupportARMv6
01      MOV     a1, #6
        SWI     XOS_UpCall
02      LDREX   a1, [a2]
        STREX   a4, a3, [a2]
        TEQ     a4, #1
        BEQ     %BT02
        TEQ     a1, #0
        BEQ     %BT01
        Return
  ]
  [ NoARMv6
01      MOV     a1, #6
        SWI     XOS_UpCall
02
03      MOV     a1, #0
        SWP     a1, a1, [a2]
        TEQ     a1, #0
        BEQ     %BT01
        Return
  ]
 ]

Sleep
; a2 -> pollword
; must exit with Z set
        MOV     a1, #6
        SWI     XOS_UpCall
        CMP     a1, a1
        MOV     pc, lr

 ;*-------------------------------------------------------------------*
 ;* Arithmetic                                                        *
 ;*-------------------------------------------------------------------*

|__rt_udiv|
|_kernel_udiv|
|x$udivide|
; Unsigned divide of a2 by a1: returns quotient in a1, remainder in a2
; Destroys a3 and ip
      [ NoARMVE
|_kernel_udiv_NoARMVE|
        MOV     a3, #0
        RSBS    ip, a1, a2, LSR #3
        BCC     u_sh2
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&FF000000
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&00FF0000
        RSBS    ip, a1, a2, LSR #8
        MOVCS   a1, a1, LSL #8
        ORRCS   a3, a3, #&0000FF00
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, #0
        BCS     dividebyzero
u_loop  MOVCS   a1, a1, LSR #8
u_sh7   RSBS    ip, a1, a2, LSR #7
        SUBCS   a2, a2, a1, LSL #7
        ADC     a3, a3, a3
u_sh6   RSBS    ip, a1, a2, LSR #6
        SUBCS   a2, a2, a1, LSL #6
        ADC     a3, a3, a3
u_sh5   RSBS    ip, a1, a2, LSR #5
        SUBCS   a2, a2, a1, LSL #5
        ADC     a3, a3, a3
u_sh4   RSBS    ip, a1, a2, LSR #4
        SUBCS   a2, a2, a1, LSL #4
        ADC     a3, a3, a3
u_sh3   RSBS    ip, a1, a2, LSR #3
        SUBCS   a2, a2, a1, LSL #3
        ADC     a3, a3, a3
u_sh2   RSBS    ip, a1, a2, LSR #2
        SUBCS   a2, a2, a1, LSL #2
        ADC     a3, a3, a3
u_sh1   RSBS    ip, a1, a2, LSR #1
        SUBCS   a2, a2, a1, LSL #1
        ADC     a3, a3, a3
u_sh0   RSBS    ip, a1, a2
        SUBCS   a2, a2, a1
        ADCS    a3, a3, a3
        BCS     u_loop
        MOV     a1, a3
        Return  ,LinkNotStacked
      ]
      [ SupportARMVE :LAND: (:LNOT: NoARMVE :LOR: SHARED_C_LIBRARY)
|_kernel_udiv_SupportARMVE|
; Long delay on UDIV result makes it faster to divide and then check for error
        UDIV    a3, a2, a1
        TEQ     a1, #0
        BEQ     dividebyzero
        MLS     a2, a3, a1, a2
        MOV     a1, a3
        Return  ,LinkNotStacked
      ]

; Unsigned remainder of a2 by a1: returns remainder in a1
; Could be faster (at expense in size) by duplicating code for udiv,
; but removing the code to generate a quotient.  As it is, a sensible
; codegenerator will call udiv directly and use the result in a2

|_kernel_urem|
|x$uremainder|
        FunctionEntry
        BL      |_kernel_udiv|
        MOV     a1, a2
        Return

; Fast unsigned divide by 10: dividend in a1
; Returns quotient in a1, remainder in a2

|__rt_udiv10|
|_kernel_udiv10|
      [ NoARMM
|_kernel_udiv10_NoARMM|
        SUB     a2, a1, #10
        SUB     a1, a1, a1, LSR #2
        ADD     a1, a1, a1, LSR #4
        ADD     a1, a1, a1, LSR #8
        ADD     a1, a1, a1, LSR #16
        MOV     a1, a1, LSR #3
        ADD     a3, a1, a1, LSL #2
        SUBS    a2, a2, a3, LSL #1
        ADDPL   a1, a1, #1
        ADDMI   a2, a2, #10
        Return  ,LinkNotStacked
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
|_kernel_udiv10_SupportARMM|
; For small numbers, UDIV would be faster than this, but not enough to make it
; worth dynamically switching between algorithms.
        LDR     a2, =&CCCCCCCD ; (8^32) / 10
        UMULL   ip, a3, a2, a1
        MOV     a3, a3, LSR #3 ; Accurate division by 10
        SUB     a2, a1, a3, LSL #1
        MOV     a1, a3
        SUB     a2, a2, a3, LSL #3
        Return  ,LinkNotStacked
      ]


|__rt_sdiv|
|_kernel_sdiv|
|x$divide|
; Signed divide of a2 by a1: returns quotient in a1, remainder in a2
; Quotient is truncated (rounded towards zero).
; Sign of remainder = sign of dividend.
; Destroys a3, a4 and ip
      [ NoARMVE
|_kernel_sdiv_NoARMVE|
; Negates dividend and divisor, then does an unsigned divide; signs
; get sorted out again at the end.

        ANDS    a3, a1, #&80000000
        RSBMI   a1, a1, #0
        EORS    a4, a3, a2, ASR #32
        RSBCS   a2, a2, #0
        RSBS    ip, a1, a2, LSR #3
        BCC     s_sh2
        RSBS    ip, a1, a2, LSR #8
        BCC     s_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&FF000000
        RSBS    ip, a1, a2, LSR #4
        BCC     s_sh3
        RSBS    ip, a1, a2, LSR #8
        BCC     s_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&00FF0000
        RSBS    ip, a1, a2, LSR #8
        MOVCS   a1, a1, LSL #8
        ORRCS   a3, a3, #&0000FF00
        RSBS    ip, a1, a2, LSR #4
        BCC     s_sh3
        RSBS    ip, a1, #0
        BCS     dividebyzero
s_loop  MOVCS   a1, a1, LSR #8
s_sh7   RSBS    ip, a1, a2, LSR #7
        SUBCS   a2, a2, a1, LSL #7
        ADC     a3, a3, a3
s_sh6   RSBS    ip, a1, a2, LSR #6
        SUBCS   a2, a2, a1, LSL #6
        ADC     a3, a3, a3
s_sh5   RSBS    ip, a1, a2, LSR #5
        SUBCS   a2, a2, a1, LSL #5
        ADC     a3, a3, a3
s_sh4   RSBS    ip, a1, a2, LSR #4
        SUBCS   a2, a2, a1, LSL #4
        ADC     a3, a3, a3
s_sh3   RSBS    ip, a1, a2, LSR #3
        SUBCS   a2, a2, a1, LSL #3
        ADC     a3, a3, a3
s_sh2   RSBS    ip, a1, a2, LSR #2
        SUBCS   a2, a2, a1, LSL #2
        ADC     a3, a3, a3
s_sh1   RSBS    ip, a1, a2, LSR #1
        SUBCS   a2, a2, a1, LSL #1
        ADC     a3, a3, a3
s_sh0   RSBS    ip, a1, a2
        SUBCS   a2, a2, a1
        ADCS    a3, a3, a3
        BCS     s_loop
        EORS    a1, a3, a4, ASR #31
        ADD     a1, a1, a4, LSR #31
        RSBCS   a2, a2, #0
        Return  ,LinkNotStacked
      ]
      [ SupportARMVE :LAND: (:LNOT: NoARMVE :LOR: SHARED_C_LIBRARY)
|_kernel_sdiv_SupportARMVE|
        SDIV    a3, a2, a1
        TEQ     a1, #0
        BEQ     dividebyzero
        MLS     a2, a3, a1, a2
        MOV     a1, a3
        Return  ,LinkNotStacked
      ]

; Signed remainder of a2 by a1: returns remainder in a1

|_kernel_srem|
|x$remainder|
        FunctionEntry
        BL      |_kernel_sdiv|
        MOV     a1, a2
        Return

; Fast signed divide by 10: dividend in a1
; Returns quotient in a1, remainder in a2
; Quotient is truncated (rounded towards zero).

|__rt_sdiv10|
|_kernel_sdiv10|
      [ NoARMM
|_kernel_sdiv10_NoARMM|
        MOVS    a4, a1
        RSBMI   a1, a1, #0
        SUB     a2, a1, #10
        SUB     a1, a1, a1, LSR #2
        ADD     a1, a1, a1, LSR #4
        ADD     a1, a1, a1, LSR #8
        ADD     a1, a1, a1, LSR #16
        MOV     a1, a1, LSR #3
        ADD     a3, a1, a1, LSL #2
        SUBS    a2, a2, a3, LSL #1
        ADDPL   a1, a1, #1
        ADDMI   a2, a2, #10
        MOVS    a4, a4
        RSBMI   a1, a1, #0
        RSBMI   a2, a2, #0
        Return  ,LinkNotStacked
      ]
      [ SupportARMM :LAND: (:LNOT: NoARMM :LOR: SHARED_C_LIBRARY)
|_kernel_sdiv10_SupportARMM|
; Using SMULL here would be tricky due to the need to round towards zero
        MOVS    a4, a1
        LDR     a2, =&CCCCCCCD ; (8^32) / 10
        RSBMI   a1, a1, #0
        UMULL   ip, a3, a2, a1
        MOV     a3, a3, LSR #3 ; Accurate division by 10
        SUB     a2, a1, a3, LSL #1
        MOV     a1, a3
        SUB     a2, a2, a3, LSL #3
        RSBMI   a1, a1, #0
        RSBMI   a2, a2, #0
        Return  ,LinkNotStacked
      ]

        RoutineVariant _kernel_udiv, ARMVE, UDIV_SDIV, MLS
        RoutineVariant _kernel_udiv10, ARMM, UMULL_UMLAL
        RoutineVariant _kernel_sdiv, ARMVE, UDIV_SDIV, MLS
        RoutineVariant _kernel_sdiv10, ARMM, UMULL_UMLAL
      [ {CONFIG}=26
        EXPORT  |_kernel_irqs_on$variant|
        EXPORT  |_kernel_irqs_off$variant|
|_kernel_irqs_on$variant| * |_kernel_irqs_on|
|_kernel_irqs_off$variant| * |_kernel_irqs_off|
      |
        RoutineVariant _kernel_irqs_on, ARMv6, SRS_RFE_CPS
        RoutineVariant _kernel_irqs_off, ARMv6, SRS_RFE_CPS
      ]

        EXPORT  __rt_div0
__rt_div0
dividebyzero
        ; Dump all registers, then enter the abort code.
        ; We need to discover whether we were doing a divide (in which case,
        ; r14 is a valid link), or a remainder (in which case, we must retrieve
        ; the link from the stack).
        LoadStaticBase ip, a3
        ADD     ip, ip, #O_registerDump
      [ {FALSE} ; this instruction is now deprecated
        STMIA   ip, {r0-r13}
      |
        STMIA   ip, {r0-r12}
        STR     r13, [ip, #13*4]
      ]
        RemovePSRFromReg r14, r1, r0            ; == BIC r0, r14, #PSRBits  IFF 26bit
        SUBS    r1, pc, r0
        ADRGE   r1, |_kernel_udiv|
        CMPGE   r0, r1
        LDRGE   r14, [sp], #4
        STR     r14, [ip, #r14*4]
        ADR     r0, E_DivideByZero
10
        SUB     r14, r14, #4
        STR     r14, [ip, #pc*4]

        BL      |_kernel_copyerror|

        SWI     EnterSVC
        LDR     r14, [ip, #pc * 4]
        LDMIB   ip, {r1-r14}^
        NOP
        STMDB   sp!, {r10, r11, r12}
        STR     r14, [sp, #-4]!
        SWI     GenerateError

        EXPORT  |_kernel_fault|
|_kernel_fault|
        ; r0 points to an error block;
        ; original r0 is on the stack.
        ; r14 is the place to pretend the fault happened
        STMFD   sp!, {r1, ip}
        LoadStaticBase ip, r1
        ADD     ip, ip, #O_registerDump
      [ {FALSE} ; this instruction is now deprecated
        STMIA   ip, {r0-r14}
      |
        STMIA   ip, {r0-r12}
        STR     r13, [ip, #13*4]
        STR     r14, [ip, #14*4]
      ]
        LDMFD   sp!, {r1, r2, r3}
        STR     r3, [ip]
        STR     r2, [ip, #ip*4]
        STR     r1, [ip, #r1*4]
        B       %B10

        ErrorBlock DivideByZero, "Divide by zero", C06

; --- International message lookup routines ----------------------------

        EXPORT  |_kernel_copyerror|
        EXPORT  |_kernel_getmessage|
        EXPORT  |_kernel_getmessage_def|
        EXPORT  |_kernel_getmessage2|

        [ SharedLibrary   ; Only works with module for the moment

        GET     Hdr:MsgTrans

n_module_claim      EQU  6
n_module_lookupname EQU 18

; Lookup an error message
;
; On entry:
;   R0 = Pointer to "international" error block.
;        +--------------------+
;        | Default error no.  | - Default error no and str are used if message file
;        +--------------------+   cannot be opened or an error occurs trying to read
;        | Default error str. |   the message file.
;        +--------------------+
;        | Pad. to word align |
;        +--------------------+
;        | Error no.          | - Real error numbers (may be same as default)
;        +--------------------+
;        | Error message tag  |   Message tag in message file
;        +--------------------+
; Return:
;   R0 = Pointer to selected error block (default or from message file)
;
|_kernel_copyerror|
        FunctionEntry "r1-r7,r12"
        BL      open_messagefile
        MOV     r2, #0
        ADR     r4, module_name
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        Return  "r1-r7,r12"

; Try to get a message from the message file
;
; On entry:
;   R0 = Message to use if failed to get message from message file
;   R1 = Message tag
;
; Return:
;   R0 = Message
;
      [ :DEF:DEFAULT_TEXT
|_kernel_getmessage|
      ]
|_kernel_getmessage_def|
        FunctionEntry "r0-r7,r12"
        BL      open_messagefile
        MOV     r0, r1
        LDR     r1, [sp, #4]
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVC   r2, [sp]
        Return  "r0-r7,r12"

      [ :LNOT::DEF:DEFAULT_TEXT
; On entry:
;   R0 = Message tag
;
; Return:
;   R0 = Message
;
|_kernel_getmessage|
        FunctionEntry "r1"
        MOV     r1, r0
        BL      |_kernel_getmessage_def|
        Return  "r1"
      ]

; On entry:
; [ DEFAULT_TEXT
;   R0 = Message to use if failed to get message from message file
;   R1 = Message tag
;   R2 = Destination buffer
;   R3 = Size of buffer
; |
;   R0 = Message tag
;   R1 = Destination buffer
;   R2 = Size of buffer
; ]
;
; Return:
;   R0 = Message
;
|_kernel_getmessage2|
        FunctionEntry "r0-r7"
        BL      open_messagefile
        MOV     r0, r1
      [ :DEF:DEFAULT_TEXT
        LDR     r1, [sp, #4]
      |
        MOV     r3, r2
        LDR     r2, [sp, #4]
        LDR     r1, [sp]
      ]
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVC   r2, [sp]
        Return  "r0-r7"


message_filename
        DCB     "SharedCLibrary:Messages", 0
        ALIGN

module_name
        DCB     "SharedCLibrary", 0
        ALIGN

; Try to open the message file.
;
open_messagefile
        FunctionEntry "r0,r2-r5"
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_CLibWord
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        MOVS    r5, r2
        LDREQ   r5, =Legacy_CLibWord
        LDR     r1, [r5]
        CMP     r1, #0
        Return  "r0,r2-r5",,NE
        MOV     r0, #Module_Claim
        MOV     r3, #Module_WorkSpace
        SWI     XOS_Module
        Return  "r0,r2-r5",,VS                  ; NB R1 = 0
        SavePSR r1
        SWI     XOS_EnterOS
        STR     r2, [r5]
        RestPSR r1
        MOV     r0, r2
        ADR     r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        MOVVC   r1, r0
        Return  "r0,r2-r5",,VC
        MOV     r0, #Module_Free
        LDR     r2, [r5]
        SWI     XOS_Module
        MOV     r1, #0
        Return  "r0,r2-r5"

        |

|_kernel_copyerror|
        Return  ,LinkNotStacked

|_kernel_getmessage|
|_kernel_getmessage_def|
|_kernel_getmessage2|
        Return  ,LinkNotStacked

        ]

|__counter|
        MOV     ip, lr
 [ {CONFIG}=26
        MOV     a4, pc
 |
        MRS     a4, CPSR
 ]
        MOV     a1, #6
        MOV     a2, #0
        MOV     a3, #OSRSI6_CLibCounter
        SWI     XOS_ReadSysInfo
        MOVVS   a3, #0
        CMP     a3, #0
        LDREQ   a3, =Legacy_CLibCounter
        SWI     EnterSVC
        MOV     a2, ip
        BL      |_kernel_irqs_off|      ; Disable IRQs round update.
        LDRB    a1, [a3]
        ADD     ip, a1, #1
        STRB    ip, [a3]
 [ {CONFIG}=26
        TEQP    pc, a4                  ; Restore mode and IRQs
 |
        MSR     CPSR_c, a4              ; Restore mode and IRQs
 ]
        Return  ,LinkNotStacked,,a2


        END
