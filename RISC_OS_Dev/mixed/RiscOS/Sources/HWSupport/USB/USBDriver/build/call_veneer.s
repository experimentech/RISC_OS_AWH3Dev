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

; little assembler stub to call an interrupt handler with an argument i r12
        GET     Hdr:ListOpts
        OPT     OptNoList
        GET     Hdr:Macros              ; system wide macro definitions
        GET     Hdr:System              ; swis and hardware declarations
        GET     Hdr:Proc


        AREA    |C$$code|, CODE, READONLY
        EXPORT  init_veneer
        IMPORT  memcpy

init_veneer
        Entry

        ; claim memory for block, exit with NULL on error
        MOV     r0, #6
        MOV     r3, #magic_end - magic_start
        SWI     XOS_Module
        MOVVS   a1, #0
        EXIT    VS

        ; memcpy the existing block
        MOV     a1, r2
        ADR     a2, magic_start
        MOV     a3, #magic_end - magic_start
        BL      memcpy

        ; poke the magic words
        SUB     sl, sl, #540
        LDMIA   sl, {a2,a3}
        STMIA   a1, {a2,a3}
        ADD     sl, sl, #540

        ; Flush the cache!
        MOV     a2, a1
        ADD     a3, a2, #magic_end - magic_start
        MOV     a1, #1
        SWI     XOS_SynchroniseCodeAreas
        MOV     a1, a2

        ; return pointing to the block
        EXIT

magic_start
mwords  DCD     0
        DCD     0

common  Entry   "v1,v2,fp"
        SUB     sl, sl, #540
        LDMIA   sl, {v1,v2}
        ADR     fp, mwords
        LDMIA   fp, {fp,lr}
        STMIA   sl, {fp,lr}
        ADD     sl, sl, #540
        MOV     fp, #0
        MOV     lr, pc
        MOV     pc, ip
        SUB     sl, sl, #540
        STMIA   sl, {v1,v2}
        ADD     sl, sl, #540
        EXIT
magic_end

; hal_veneer(code, ws)  up to 2 arguments supported
        EXPORT  hal_veneer2

hal_veneer2
        Entry   "r9"
        MOV     ip, a1
        MOV     r9, a2
        MOV     a1, a3
        MOV     a2, a4
        MOV     lr, pc
        MOV     pc, ip
        EXIT



        END
