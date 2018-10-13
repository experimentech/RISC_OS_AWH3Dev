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
x
        MOV     ip, sp
        STMFD   sp!, {a1,a2,v1,fp,ip,lr,pc}
        SUB     fp, ip, #4
        CMPS    sp, sl
        BLLT    |x$stack_overflow|
        MOV     v1, a2
        SUB     sp, sp, #20
        MOV     a4, #0
        ADD     a3, sp, #16
        STMFD   sp!, {a3,a4}
        MOV     a3, a1
        ADD     a2, sp, #8
        MOV     a4, #0
        MOV     a1, #1
        BL      xpdriver_draw_page
        ADD     sp, sp, #8
        CMPS    a1, #0
        BNE     |L0000d8.J19.x|
        B       |L0000cc.J8.x|
|L000058.J7.x|
        MOV     a4, #0
        STMFD   sp!, {a4}
        MOV     a4, #0
        MOV     a3, #0
        MOV     a2, #0
        MOV     a1, #0
        BL      xcolourtrans_set_gcol
        ADD     sp, sp, #4
        CMPS    a1, #0
        BNE     |L0000d8.J19.x|
        MOV     a4, #0
        MOV     a3, #0
        MOV     a2, #0
        MOV     a1, #0
        STMFD   sp!, {a1,a2,a3,a4}
        MOV     a2, v1
        MOV     a4, #0
        MOV     a3, #0
        MOV     a1, #0
        BL      xfont_paint
        ADD     sp, sp, #16
        CMPS    a1, #0
        BNE     |L0000d8.J19.x|
        ADD     a2, sp, #16
        MOV     a1, sp
        MOV     a3, #0
        BL      xpdriver_get_rectangle
        CMPS    a1, #0
        BNE     |L0000d8.J19.x|
|L0000cc.J8.x|
        LDR     a2, [sp, #16]
        CMPS    a2, #0
        BNE     |L000058.J7.x|
|L0000d8.J19.x|
        LDMEA   fp, {v1,fp,sp,pc}^
