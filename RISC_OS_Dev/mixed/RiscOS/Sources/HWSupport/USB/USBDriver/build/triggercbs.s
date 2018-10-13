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

; trigger callbacks by calling OS_LeaveOS and OS_EnterOS

        GET     Hdr:ListOpts
        OPT     OptNoList
        GET     Hdr:PublicWS
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:OSRSI6
        GET     Hdr:Proc

        AREA    |C$$data|, DATA
ptr_IRQsema
        DCD     0   ; Cached IRQsema ptr

        AREA    |C$$code|, CODE, READONLY

        EXPORT  get_ptr_IRQsema
get_ptr_IRQsema
        LDR     r1, [sl,#-536]       ; Get relocation
        LDR     r3, =ptr_IRQsema
        LDR     r0, [r3, r1]!
        CMP     r0, #0
        MOVNE   pc, lr
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_IRQsema
        MOV     ip, lr
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        MOVS    r0, r2
        MOVEQ   r0, #Legacy_IRQsema
        STR     r0, [r3]
        MOV     pc, ip

        EXPORT  triggercbs
triggercbs
        Entry
        BL      get_ptr_IRQsema
        LDR     lr, [r0]
        MOVS    lr, lr
        EXIT    NE                   ; NZ is within IRQ.. so no CB allowed
        SWI     OS_LeaveOS
        SWI     OS_EnterOS
        EXIT

        LTORG

        END
