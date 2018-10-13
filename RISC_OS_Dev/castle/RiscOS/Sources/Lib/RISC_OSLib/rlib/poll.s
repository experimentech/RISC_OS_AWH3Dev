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
;/************************************************************************/
;/* � Acorn Computers Ltd, 1992.                                         */
;/*                                                                      */
;/* This file forms part of an unsupported source release of RISC_OSLib. */
;/*                                                                      */
;/* It may be freely used to create executable images for saleable       */
;/* products but cannot be sold in source form or as an object library   */
;/* without the prior written consent of Acorn Computers Ltd.            */
;/*                                                                      */
;/* If this file is re-distributed (even if modified) it should retain   */
;/* this copyright notice.                                               */
;/*                                                                      */
;/************************************************************************/

; Title  : s.poll
; Purpose: interface to wimp poll for C programs
; History: IDJ: 07-Feb-92: prepared for source release

        GBLL    ModeMayBeNonUser
ModeMayBeNonUser   SETL  {FALSE}

        GET     Hdr:ListOpts
        GET     Hdr:APCS.Common
        GET     Hdr:Macros

XWimp_Poll     * (1 :SHL: 17) :OR: &400C7
XWimp_PollIdle * (1 :SHL: 17) :OR: &400E1

        AREA |C$$code|, CODE, READONLY

|x$codeseg|

        IMPORT  |_kernel_fpavailable|
        EXPORT  wimp_poll

; os_error * wimp_poll(wimp_emask mask, wimp_eventstr * result) ;
; a1 is poll mask, a2 is pointer to event structure

wimp_poll
        FunctionEntry "v1-v2", frame
        MOV     v2, a1
        MOV     v1, a2

        BL      |_kernel_fpavailable|
        TEQ     a1, #0
        LDRNE   a1, =poll_preserve_fp
        LDRNE   a1, [a1]
        TEQNE   a1, #0
        BLNE    save_fp_state
        MOV     lr, a1

        MOV     a1, v2                    ; restore mask
        ADD     a2, v1, #4                ; point at eventstr->data
        SWI     XWimp_Poll

        SUB     a2, a2, #4                ; point back at eventstr
        STR     a1, [a2, #0]              ; set reason code
        MOVVC   a1, #0                    ; no error

        CMP     lr, #0
        BLNE    restore_fp_state

        Return  "v1-v2", "fpbased"

; os_error *wimp_pollidle(wimp_emask mask, wimp_eventstr *result, int earliest)
; a1 mask, a2 eventstr, a3 earliest

        EXPORT  wimp_pollidle
wimp_pollidle
        FunctionEntry "v1-v3", frame
        MOV     v2, a1
        MOV     v1, a2
        MOV     v3, a3

        BL      |_kernel_fpavailable|
        TEQ     a1, #0
        LDRNE   a1, =poll_preserve_fp
        LDRNE   a1, [a1]
        TEQNE   a1, #0
        BLNE    save_fp_state
        MOV     lr, a1

        MOV     a1, v2                    ; restore mask
        ADD     a2, v1, #4                ; point at eventstr->data
        MOV     a3, v3                    ; restore time
        SWI     XWimp_PollIdle

        CMP     lr, #0
        BLNE    restore_fp_state

        SUB     a2, a2, #4                ; point back at eventstr
        STR     a1, [a2, #0]              ; set reason code
        MOVVC   a1, #0                    ; no error
        Return  "v1-v3", "fpbased"

; Only f4..f7 defined preserved over procedure call
; can corrupt a2-a4
save_fp_state
        RFS     a2                      ; read FP status
        STR     a2, [sp, #-4]!
        MOV     a2, #0
        WFS     a2
        SUB     sp, sp, #4*12           ; emulated a lot faster than writeback
        STFE    f4, [sp, #0*12]
        STFE    f5, [sp, #1*12]
        STFE    f6, [sp, #2*12]
        STFE    f7, [sp, #3*12]
        MOV     pc, lr

; v1, v2 trashable
restore_fp_state
        MOV     v1, #0
        WFS     v1
        LDFE    f4, [sp, #0*12]
        LDFE    f5, [sp, #1*12]
        LDFE    f6, [sp, #2*12]
        LDFE    f7, [sp, #3*12]
        ADD     sp, sp, #4*12           ; emulated a lot faster than writeback
        LDR     v1, [sp], #4
        WFS     v1
        MOV     pc, lr

        [ :LNOT:UROM
        EXPORT  wimp_save_fp_state_on_poll
wimp_save_fp_state_on_poll
        LDR   a1, =poll_preserve_fp
        MOV   a2, #1
        STR   a2, [a1]
        MOV   pc, lr
        ]

        [ :LNOT:UROM
        EXPORT  wimp_corrupt_fp_state_on_poll
wimp_corrupt_fp_state_on_poll
        LDR   a1, =poll_preserve_fp
        MOV   a2, #0
        STR   a2, [a1]
        MOV   pc, lr
        ]

        LTORG

    AREA |C$$data|
|x$dataseg|

poll_preserve_fp  DCD  1

    END
