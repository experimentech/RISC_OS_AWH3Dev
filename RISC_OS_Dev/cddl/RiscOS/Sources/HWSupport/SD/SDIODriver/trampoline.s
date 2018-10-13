;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/HWSupport/SD/SDIODriver/LICENCE.
; See the Licence for the specific language governing permissions
; and limitations under the Licence.
;
; When distributing Covered Code, include this CDDL HEADER in each
; file and include the Licence file. If applicable, add the
; following below this CDDL HEADER, with the fields enclosed by
; brackets "[]" replaced with your own identifying information:
; Portions Copyright [yyyy] [name of copyright owner]
;
; CDDL HEADER END
;
; Copyright 2012 Ben Avison.  All rights reserved.
; Use is subject to license terms.
;

        EXPORT  trampoline_unshared
        EXPORT  trampoline_vectored
        EXPORT  trampoline_offset_pointer
        EXPORT  trampoline_offset_privateword
        EXPORT  trampoline_offset_cmhgveneer
        EXPORT  trampoline_length

        GET     ListOpts
        GET     Macros
        GET     HALDevice

        AREA    |Asm$$Code|, CODE, READONLY

        ; On entry r12 -> SDHCI controller HAL device, r14 = return address
        ; On exit r0-r3 and r12 may be corrupted
trampoline_unshared ROUT
        Push    "lr"
        MOV     a1, r12
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_TestIRQ]
        Pull    "lr"
        TEQ     a1, #0
        MOVEQ   pc, lr          ; bogus IRQ so return - kernel should mask this IRQ in interrupt controller
        ADR     r3, %0
        LDMIA   r3, {r0,r12,pc} ; common case where IRQ is genuine
trampoline_offset_pointer * (.-trampoline_unshared) / 4
0       DCD     0       ; patch with sdhcinode_t * for this controller
trampoline_offset_privateword * (.-trampoline_unshared) / 4
        DCD     0       ; patch with module private word
trampoline_offset_cmhgveneer * (.-trampoline_unshared) / 4
        DCD     0       ; patch with cmhg generic veneer
trampoline_length * .-trampoline_unshared

        ; On entry r12 -> SDHCI controller HAL device, [r13] = claim address, r14 = pass-on address
        ; On exit r0-r3 and r12 may be corrupted
trampoline_vectored ROUT
        Push    "lr"
        MOV     a1, r12
        MOV     lr, pc
        LDR     pc, [a1, #HALDevice_TestIRQ]
        TEQ     a1, #0
        Pull    "pc", EQ ; pass on vectored IRQ since we're not claiming it - do first since unexecuted conditional LDM is often slow
        Pull    "r2, lr" ; junk pass-on address and get claim address from stack
        ADR     r3, %0
        LDMIA   r3, {r0,r12,pc}
        ASSERT  trampoline_offset_pointer = (.-trampoline_vectored) / 4
0       DCD     0       ; patch with sdhcinode_t * for this controller
        ASSERT  trampoline_offset_privateword = (.-trampoline_vectored) / 4
        DCD     0       ; patch with module private word
        ASSERT  trampoline_offset_cmhgveneer = (.-trampoline_vectored) / 4
        DCD     0       ; patch with cmhg generic veneer
        ASSERT  trampoline_length = .-trampoline_vectored

        END
