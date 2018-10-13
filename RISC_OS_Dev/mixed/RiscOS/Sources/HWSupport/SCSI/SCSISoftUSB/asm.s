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
; /*****************************************************************************
; * $Id: asm,v 1.4 2012-06-03 14:26:02 jlee Exp $
; * $Name: HEAD $
; *
; * Author(s):  Ben Avison
; * Project(s):
; *
; * ----------------------------------------------------------------------------
; * Purpose: Assembler stubs
; *
; * ----------------------------------------------------------------------------
; * History: See source control system log
; *
; *****************************************************************************/

        GET     hdr:ListOpts
        GET     hdr:Macros
        GET     hdr:System
        GET     hdr:APCS.<APCS>
        GET     hdr:UpCall

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  asm_DoTransferCompleteCallback
        EXPORT  asm_CallBufferManager
        EXPORT  asm_UpCallHandler
        EXPORT  asm_RTSupportWrapper
        IMPORT  RTSupportWrapper

; extern void asm_DoTransferCompleteCallback(_kernel_oserror *error,
;                                            uint32_t status_byte,
;                                            void (*callback)(void),
;                                            size_t amount_not_transferred,
;                                            void *priv,
;                                            void *workspace);

asm_DoTransferCompleteCallback
        FunctionEntry "v1-v2"
        CMP     a1, #0                  ; clear V
        SETV    NE                      ; set V if returning error pointer
        MOVVC   a1, a2                  ; else return status byte in R0
        MOV     v1, a4                  ; amount not transferred goes in R4
        ADD     v2, sp, #3*4
        LDMIA   v2, {v2, ip}            ; get R5, R12 off stack
        MOV     lr, pc
        MOV     pc, a3                  ; do callback
        Return  "v1-v2"


; extern uint32_t asm_CallBufferManager(uint32_t reason,
;                                       uint32_t buffer_id,
;                                       void *block,
;                                       size_t length,
;                                       void *ws,
;                                       void (*rout)(void));

asm_CallBufferManager
        FunctionEntry
        MOV     lr, pc
        LDMIB   sp, {ip, pc}
        MOV     a1, a3
        Return

; asm_UpCallHandler isn't called directly from C

asm_UpCallHandler
        TEQ     r0, #UpCall_StreamCreated
        STREQ   r4, [r12]
        MOV     pc, lr

; extern __value_in_regs rtsupport_routine_result asm_RTSupportWrapper(uint32_t *reloc)
; Wrapper for RTSupportWrapper to get us out of SYS mode and into SVC mode
; (required so we can safely use the other asm calls)
; Note - no need for us to preserve the current relocation offsets in the stack,
; RTSupport will handle that for us

asm_RTSupportWrapper
        LDMIA   r0, {r0-r1}             ; Load relocation offsets
        MSR     CPSR_c, #SVC32_mode
        MOV     r10, r13, LSR #20
        MOV     r10, r10, LSL #20
        STMIA   r10, {r0-r1}
        ADD     r10, r10, #540
        BL      RTSupportWrapper
        MSR     CPSR_c, #SYS32_mode     ; Must return to RTSupport in SYS mode
        MOV     pc, lr

        END
