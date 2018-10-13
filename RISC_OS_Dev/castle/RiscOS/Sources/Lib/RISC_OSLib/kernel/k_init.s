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
;* Shared library kernel: unshared (Brazil/Arthur) version: initialisation
;* Lastedit: 08 Mar 90 14:25:15 by Harry Meekings *
;
; Copyright (C) Acorn Computers Ltd., 1988.
;

        IMPORT  |Image$$RO$$Base|
        IMPORT  |RTSK$$Data$$Base|
        IMPORT  |RTSK$$Data$$Limit|
        IMPORT  |Image$$RW$$Limit|
        EXPORT  |_kernel_entrypoint|
        IMPORT  |__root_stack_size|, WEAK
 [ ModeMayBeNonUser
        EXPORT  |_AnsiLib_Module_Init_Statics|
 ]
        ENTRY

|_kernel_entrypoint|
        LDR     v6, =|StaticData|
        SWI     GetEnv                  ; to decide heap limit
        MOV     r4, r1
        LDR     r1, =|Image$$RW$$Limit|
        LDR     r3, =|__root_stack_size|
        CMP     r3, #0
        LDRNE   r3, [r3]
        MOVEQ   r3, #RootStackSize
        ADD     r2, r3, r1
        STR     r3, [r1, #SC_size]

        ADR     r0, k_init_block
        MOV     r3, #0
        STR     r3, [r1, #SC_SLOffset+SL_Client_Offset]
        STR     r3, [r1, #SC_SLOffset+SL_Lib_Offset]
        B       |_kernel_init|

k_init_block
        &       |Image$$RO$$Base|
        &       |RTSK$$Data$$Base|
        &       |RTSK$$Data$$Limit|

 [ ModeMayBeNonUser
|_AnsiLib_Module_Init_Statics|
; r1 -> workspace start
; r2 -> workspace limit
; r3 -> start of zero-init area
; r4 -> start of static data
; r5 -> limit of static data
        FunctionEntry "r12"
        SUBS    lr, r5, r4              ; size of client's statics
        MOVMI   lr, #0                  ; no client statics really.
        MOV     r12, sp, LSR #20
        MOV     r12, r12, ASL #20
        ADD     lr, lr, r1
CheckEnoughStore
        CMP     lr, r2                  ; must fit within available workspace
        ADRGT   r0, E_BadMemory
        BGT     Failed

        ; Copy the non-zeroed client statics
        SUBS    lr, r5, r4              ; see again whether client statics to copy
        MOVMI   r4, r1
        SUBPLS  r6, r3, r4
        BLE     ZeroInitClientStatics
CopyClientStatics
        LDR     lr, [r4], #+4
        STR     lr, [r1], #+4
        SUBS    r6, r6, #4
        BNE     CopyClientStatics

        ; Zero the client statics which need zeroing
ZeroInitClientStatics
        SUB     lr, r1, r4              ; the value for SL_Client_Offset
        SUBS    r5, r5, r3
        BLE     DoneClientStatics
        MOV     r6, #0
01      STR     r6, [r1], #4
        SUBS    r5, r5, #4
        BGT     %B01

        ; Client statics copied/zeroed, fill in SC_Client_Offset for -zm1 clients
DoneClientStatics
        STR     lr, [r12, #SC_SLOffset+SL_Client_Offset]
        MOV     lr, #0
        STR     lr, [r12, #SC_SLOffset+SL_Lib_Offset]
        MOV     r1, r12                 ; r1 on exit -> stack base
        Return  "r12"

Failed
        ; Here with r0=error block if failed for one reason or another
        BL      |_kernel_copyerror|
        SETV
        Return  "r12"

        ErrorBlock BadMemory, "Not enough memory for C library", C01
 ]

        END
