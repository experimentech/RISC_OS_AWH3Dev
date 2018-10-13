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

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  TPSRead
        EXPORT  TPSWrite

; A couple of utility functions for reading/writing registers from the TWL4030/TPS65950 IC
; (although the protocol is probably generic enough to work with many other IIC devices)

; For the majority of uses, v1 simply needs to be initialised as follows:
; LDR  v1, OSentries+4*OS_IICOpV
; i.e. the IIC transfer will be performed on IIC bus 0, via RISCOS_IICOpV. This means that 0
; will be returned on success, or an OS error block pointer on failure!
; When using OS_IICOpV, v2 can be left uninitialised.

TPSRead
        ; a1 = IIC address(*2)
        ; a2 = buffer
        ; a3 = count
        ; a4 = start register
        ; v1 = IIC func
        ; v2 = IIC param
        ; out:
        ; a1 = return code
        ; ip corrupted
        ; buffer updated
        ORR     a1, a1, #1 ; read
        Push    "a1-a4,lr" ; Push regs and second iic_transfer block
        EOR     a1, a1, #1+(1:SHL:29) ; write with retry
        ADD     a2, sp, #12
        MOV     a3, #1
        Push    "a1-a3" ; push first iic_transfer block
        MOV     a1, sp
        MOV     a2, #2
        MOV     a3, v2
        BLX     v1
        ADD     sp, sp, #16
        Pull    "a2-a4,pc"

TPSWrite
        ; a1 = IIC address(*2)
        ; a2 = buffer
        ; a3 = count
        ; a4 = start register
        ; v1 = IIC func
        ; v2 = IIC param
        ; out:
        ; a1 = return code
        ; ip corrupted
        ORR     a1, a1, #1:SHL:31 ; Write (no start bit)
        Push    "a1-a4,lr" ; Push regs and second iic_transfer block
        EOR     a1, a1, #(1:SHL:29)+(1:SHL:31) ; Write (retries)
        ADD     a2, sp, #12
        MOV     a3, #1
        Push    "a1-a3" ; push first iic_transfer block
        MOV     a1, sp
        MOV     a2, #2
        MOV     a3, v2
        BLX     v1
        ADD     sp, sp, #16
        Pull    "a2-a4,pc"

        END
