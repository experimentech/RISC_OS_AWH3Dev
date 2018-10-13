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
;
 [ Debug
; a2-> null terminated string
DebugTXS    ROUT
        STMFD   sp!, {a1,lr}
        SUB     a2,a2,#1
1       LDRB    a1, [a2,#1]!
        TEQ     a1, #&0
        LDMEQFD sp!, {a2,pc}
        BL      DebugTX
        B       %BT1

DebugHexTX
       stmfd    r13!, {r0-r3,lr}
       ldr      r0,[r13, #20]
       b        jbdt1
DebugHexTX2
       stmfd    r13!, {r0-r3,lr}
       ldr      r0,[r13, #20]
       b        jbdt2
DebugHexTX4
       stmfd    r13!, {r0-r3,lr}
       ldr      r0,[r13, #20]
       mov      r0,r0,ror #24          ; hi byte
       bl       jbdtxh
       mov      r0,r0,ror #24
       bl       jbdtxh
jbdt2
       mov      r0,r0,ror #24
       bl       jbdtxh
       mov      r0,r0,ror #24
jbdt1
       bl       jbdtxh
       mov      r0,#' '
       bl       DebugTX
       ldmfd    r13!, {r0-r3,pc}

DebugTXStrInline
       stmfd    r13!, {r0-r3}          ; lr points to prinstring, immediately
                                       ; following call, null terminated
       sub      r3,lr,#1
1      ldrb     r0,[r3,#1]!            ; pop next char, auto incr
       teq      r0,#0                  ; terminating null
       biceq    lr,r3,#3               ; round down address
       ldmeqfd  r13!,{r0-r3}
       addeq    pc,lr,#4               ; return to next word
       bl       DebugTX                ; else send, then
       b        %bt1                   ; loop

jbdtxh stmfd    r13!,{r0-r3,lr}        ; print byte as hex
       and      a4,a1,#&f              ; get low nibble
       and      a1,a1,#&f0             ; get hi nibble
       mov      a1,a1,lsr #4           ; shift to low nibble
       cmp      a1,#&9                 ; 9?
       addle    a1,a1,#&30
       addgt    a1,a1,#&37             ; convert letter if needed
       bl       DebugTX
       cmp      a4,#9
       addle    a1,a4,#&30
       addgt    a1,a4,#&37
       bl       DebugTX
       ldmfd    r13!,{r0-r3,pc}

DebugTX
       stmfd    r13!,{r0-r3,r8,r9,lr}
       mov      r8, #OSHW_CallHAL
       mov      r9, #EntryNo_HAL_DebugTX
       SWI      XOS_Hardware
       ldmfd    r13!,{r0-r3,r8,r9,pc}

 ]
       END
