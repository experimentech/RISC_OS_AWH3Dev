;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/FileSys/SDFS/SDFS/LICENCE.
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

        EXPORT  free_veneer
        EXPORT  free_init
        EXPORT  free_handle

        IMPORT  free_handler
        IMPORT  g_module_pw

        GET     ListOpts
        GET     Macros
        GET     System
        GET     APCS/$APCS

        AREA    |Asm$$Code|, CODE, READONLY

; The Free module imposes some very difficult restrictions on this entry
; point. It may be entered in USR mode or SVC mode. It must preserve all
; registers (except those returning results), can't use the USR stack, and
; (for one reason code) returns a result in the Z flag. These are well
; beyond the capabilities of a normal CMHG veneer. We need to have set up
; a stack chunk in advance, for use in the USR mode case.

free_veneer
        STR     r13, [r12, #free_caller_R13 - free_handle]
        STR     r14, [r12, #free_caller_R14 - free_handle]
        MRS     r14, CPSR
        TST     r14, #&F ; entered in USR mode?
        BNE     svc_entry
usr_entry
        ADD     r13, r12, #(free_stack_top - free_handle) :AND: 0xFF
        ADD     r13, r13, #(free_stack_top - free_handle) :AND::NOT: 0xFF
        Push    "r0-r12"
        ADD     sl, r12, #free_stack_limit - free_handle
        B       common_entry
svc_entry
        Push    "r0-r12"
        MOV     sl, sp, LSR #20
        MOV     sl, sl, LSL #20
        LDMIA   sl, {v1-v2} ; save old reloc offsets
        LDR     ip, [r12, #free_module_workspace - free_handle]
        LDMIB   ip, {fp,ip} ; get our reloc offsets from module workspace
        STMIA   sl, {fp,ip}
        ADD     sl, sl, #4*7 + 512
common_entry
        MOV     fp, #0
        MOV     a1, sp ; point at stacked registers
        SUB     sp, sp, #4
        MOV     a2, sp ; buffer to receive return flags
        BL      free_handler
        Pull    "a2"
        BIC     a2, a2, #V_bit
        TEQ     a1, #0
        ORRNE   a2, a2, #V_bit
        STRNE   a1, [sp]
        MRS     a3, CPSR
        TST     a3, #&F ; in USR mode?
        BNE     svc_exit
usr_exit
        MSR     CPSR_f, a2
        Pull    "r0-r12"
        LDR     r13, [r12, #free_caller_R13 - free_handle]
        LDR     r14, [r12, #free_caller_R14 - free_handle]
        Pull    "pc"
svc_exit
        MSR     CPSR_f, a2
        SUB     sl, sl, #4*7 + 512
        STMIA   sl, {v1-v2} ; restore old reloc offsets
        Pull    "r0-r12"
        LDR     r14, [r12, #free_caller_R14 - free_handle]
        Pull    "pc"
        
free_init
        SUB     a1, sl, #free_stack_limit - free_stack_relocations
        LDMIA   a1, {a3, a4} ; lib relocation in a3, client relocation in a4
        LDR     a2, =free_stack_relocations
        ADD     a2, a4, a2
        STMIA   a2, {a3, a4}
        LDR     a1, =g_module_pw
        LDR     a2, =free_module_workspace
        LDR     a1, [a4, a1]
        LDR     a1, [a1] ; read workspace pointer from private word
        STR     a1, [a4, a2]
        Return  , LinkNotStacked

        AREA    |Asm$$Data|, DATA

free_handle
free_caller_R13
        DCD     0
free_caller_R14
        DCD     0
free_module_workspace
        DCD     0
free_stack_chunk
        DCD     0xF60690FF                        ; sc_mark
        DCD     0                                 ; sc_next
        DCD     0                                 ; sc_prev
        DCD     free_stack_top - free_stack_chunk ; sc_size
        DCD     0                                 ; sc_deallocate
free_stack_relocations
        %       4 * 7
free_stack_extension_space
        %       512
free_stack_limit
        %       512
free_stack_top

        END
