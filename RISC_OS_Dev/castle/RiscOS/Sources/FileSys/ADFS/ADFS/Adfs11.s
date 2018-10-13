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
WinnieBits  * IOMD_HardDisc_IRQ_bit

 [ NewTransferCode
; improved code that uses LDRH/STRH, and doesn't bother copying into RAM
; (because we're a cached processor, and the "ROM" is in RAM anyway!)
ReadCode ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     Read256OddAddress
        BCS     Read256HalfWordAddress
Read256WordAddress ROUT
        MOV     R0, #256-4

10      LDRH    R2, IDERegData
        LDRH    LR, IDERegData
        LDRH    R3, IDERegData
        ORR     R2, R2, LR, LSL #16
        LDRH    LR, IDERegData
        LDRH    R4, IDERegData
        ORR     R3, R3, LR, LSL #16
        LDRH    LR, IDERegData
        LDRH    R5, IDERegData
        ORR     R4, R4, LR, LSL #16
        LDRH    LR, IDERegData
        LDRH    R6, IDERegData
        ORR     R5, R5, LR, LSL #16
        LDRH    LR, IDERegData
        LDRH    R7, IDERegData
        ORR     R6, R6, LR, LSL #16
        LDRH    LR, IDERegData
        LDRH    R8, IDERegData
        ORR     R7, R7, LR, LSL #16
        LDRH    LR, IDERegData
        SUBS    R0, R0, #7*4
        ORR     R8, R8, LR, LSL #16
        STMIA   R1!,{R2-R8}
        BGT     %BT10
        LDRH    R8, IDERegData
        LDREQH  LR, IDERegData
        ORREQ   R8, R8, LR, LSL #16
        STREQ   R8, [R1], #4
        MOVEQ   PC, R10
        STRH    R8, [R1], #2
        MOV     PC, R10

Read256HalfWordAddress
        LDRH    R8, IDERegData
        MOV     R0, #256-4-2
        STRH    R8, [R1], #2
        B       %BT10


Read256OddAddress ROUT
        MOV     R0, #(256-4)/12
        BCS     Read256at4Nplus3
; so here we know that the address is 4N + 1
        LDRH    R8, IDERegData
        STRB    R8, [R1], #1
        MOV     R8, R8, LSR #8
        STRB    R8, [R1], #1
        BL      Read254odd
        MOV     PC, R10

Read254odd ROUT                 ;corrupts R0,R2,R5-R8,LR
        LDRH    R8, IDERegData
        STRB    R8, [R1],#1
        MOV     R5, R8, LSR #8

10      SUBS    R0, R0, #1              ;R5=next byte   000000Ah

        LDRH    R2, IDERegData          ;0000BhBl
        LDRH    R6, IDERegData          ;0000ChCl
        ORR     R2, R2, R6, LSL #16     ;ChClBhBl
        LDRH    R7, IDERegData          ;0000DhDl
        ORR     R6, R5, R2, LSL #8      ;ClBhBlAh
        LDRH    R5, IDERegData          ;0000EhEl
        MOV     R7, R7, LSL #8          ;00DhDl00
        LDRH    R8, IDERegData          ;0000FhFl
        ORR     R7, R7, R5, LSL #24     ;ElDhDl00
        ORR     R7, R7, R2, LSR #24     ;ElDhDlCh
        LDRH    R2, IDERegData          ;0000GhGl
        MOV     R8, R8, LSL #8          ;00FhFl00
        ORR     R8, R8, R2, LSL #24     ;GlFhFl00
        ORR     R8, R8, R5, LSR #8      ;GlFhFlEh
        STMIA   R1!, {R6-R8}
        MOV     R5, R2, LSR #8          ;000000Gh
        BNE     %BT10

        STRB    R5, [R1],#1
        MOV     PC, LR

Read256at4Nplus3 ROUT
; here we know the address is 4N + 3
        BL      Read254odd
        LDRH    R8, IDERegData
        STRB    R8, [R1],#1             ;here if 4n+2
        MOV     R8, R8, LSR #8
        STRB    R8, [R1],#1
        MOV     PC, R10

; and code that does 32-bit accesses, as many PCI controllers
; support this.
ReadCode32 ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     Read256OddAddress32
        BCS     Read256HalfWordAddress32
Read256WordAddress32 ROUT
        MOV     R0, #256-4

10      LDR     R2, IDERegData
        LDR     R3, IDERegData
        LDR     R4, IDERegData
        LDR     R5, IDERegData
        LDR     R6, IDERegData
        LDR     R7, IDERegData
        LDR     R8, IDERegData
        SUBS    R0, R0, #7*4
        STMIA   R1!,{R2-R8}
        BGT     %BT10
        LDREQ   R8, IDERegData
        STREQ   R8, [R1], #4
        MOVEQ   PC, R10
        LDRH    R8, IDERegData
        STRH    R8, [R1], #2
        MOV     PC, R10

Read256HalfWordAddress32
        LDR     R8, IDERegData          ;BBBBAAAA
        MOV     R0, #(256-4)/12
        STRH    R8, [R1], #2
        MOV     R5, R8, LSR #16         ;0000BBBB

10      LDR     R2, IDERegData          ;DDDDCCCC
        SUBS    R0, R0, #1
        ORR     R6, R5, R2, LSL #16     ;CCCCBBBB
        LDR     R5, IDERegData          ;FFFFEEEE
        MOV     R2, R2, LSR #16         ;0000DDDD
        ORR     R7, R2, R5, LSL #16     ;EEEEDDDD
        LDR     R2, IDERegData          ;HHHHGGGG
        MOV     R5, R5, LSR #16         ;0000FFFF
        ORR     R8, R5, R2, LSL #16     ;GGGGFFFF
        STMIA   R1!, {R6-R8}
        MOV     R5, R2, LSR #16         ;0000HHHH
        BNE     %BT10

        STRH    R5, [R1], #2
        MOV     PC, R10

Read256OddAddress32 ROUT
        MOV     R0, #(256-4)/12
        BCS     Read256at4Nplus3_32

Read256at4Nplus1_32
        LDR     R8, IDERegData          ;BhBlAhAl
        STRB    R8, [R1], #1
        MOV     R8, R8, LSR #8          ;00BhBlAh
        STRH    R8, [R1], #2
        MOV     R5, R8, LSR #16         ;000000Bh

10      LDR     R2, IDERegData          ;DhDlChCl
        SUBS    R0, R0, #1
        ORR     R6, R5, R2, LSL #8      ;DlChClBh
        LDR     R5, IDERegData          ;FhFlEhEl
        MOV     R2, R2, LSR #24         ;000000Dh
        ORR     R7, R2, R5, LSL #8      ;FlEhElDh
        LDR     R2, IDERegData          ;HhHlGhGl
        MOV     R5, R5, LSR #24         ;000000Fh
        ORR     R8, R5, R2, LSL #8      ;HlGhGlFh
        STMIA   R1!, {R6-R8}
        MOV     R5, R2, LSR #24         ;000000Hh
        BNE     %BT10

        STRB    R5, [R1], #1
        MOV     PC, R10

Read256at4Nplus3_32
        LDR     R8, IDERegData          ;BhBlAhAl
        STRB    R8, [R1], #1
        MOV     R5, R8, LSR #8          ;00BhBlAh

10      LDR     R2, IDERegData          ;DhDlChCl
        SUBS    R0, R0, #1
        ORR     R6, R5, R2, LSL #24     ;ClBhBlAh
        LDR     R5, IDERegData          ;FhFlEhEl
        MOV     R2, R2, LSR #8          ;00DhDlCh
        ORR     R7, R2, R5, LSL #24     ;ElDhDlCh
        LDR     R2, IDERegData          ;HhHlGhGl
        MOV     R5, R5, LSR #8          ;00FhFlEh
        ORR     R8, R5, R2, LSL #24     ;GlFhFlEh
        STMIA   R1!, {R6-R8}
        MOV     R5, R2, LSR #8          ;00HhHlGh
        BNE     %BT10

        STRH    R5, [R1], #2
        MOV     R5, R5, LSR #16         ;000000Hh
        STRB    R5, [R1], #1
        MOV     PC, R10

; In
;   r1->destination
;   IDE
;   R10 = return address
; Out
;    r1->place after transfer of 256 bytes
;    r0,r2-r9,LR trashed
;
        MACRO
        WriteIDEWord $reg, $treg
        STRH    $reg, IDERegData
        MOV     $treg, $reg, LSR #16
        STRH    $treg, IDERegData
        MEND

WriteCode ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     Write256OddAddress
        BCS     Write256HalfWordAddress

Write256WordAddress ROUT
        MOV     R0, #256
        B       %FT15

10
        LDMIA   R1!,{R2-R9}

        WriteIDEWord R2, LR
        WriteIDEWord R3, LR
        WriteIDEWord R4, LR
        WriteIDEWord R5, LR
        WriteIDEWord R6, LR
        WriteIDEWord R7, LR
        WriteIDEWord R8, LR
        WriteIDEWord R9, LR

15
        SUBS    R0, R0, #8*4
        BGE     %BT10

        CMP     R0, #-8*4
        MOVEQ   PC, R10

        ; 1/2-word aligned case - transfer the remaining 7 1/2 words
        LDMIA   R1!, {r2-r9}
        WriteIDEWord R2, LR
        WriteIDEWord R3, LR
        WriteIDEWord R4, LR
        WriteIDEWord R5, LR
        WriteIDEWord R6, LR
        WriteIDEWord R7, LR
        WriteIDEWord R8, LR
        STRH    R9, IDERegData
        SUB     R1, R1, #2              ; correction for non-transfered 1/2-word

20      MOV     PC, R10


Write256HalfWordAddress
        LDRH    R2, [R1], #2
        MOV     R0, #256-2
        STRH    R2, IDERegData          ; store the odd halfword at the start
        B       %BT15

Write256OddAddress ROUT
        BCS     Write256at4Nplus3

; so here we know the address is 4N + 1
        BIC     R1, R1, #3
        LDR     R6, [R1],#4             ; Pick up dcba to transfer dcb.
        MOV     LR, R6, LSR #8
        STRH    LR, IDERegData          ; Write out .cb. which is in LR as .dcb
        MOV     R6, R6, LSR #24         ; Put d... into r6 as ...d
        BL      Write252odd
        LDRB    R7, [R1], #1            ; get the odd byte at the end
        ORR     R2, R6, R7, LSL #8      ; combine it with the odd byte from AWrite252odd
        STRH    R2, IDERegData
        MOV     PC, R10

Write256at4Nplus3 ROUT
        LDRB    R6, [R1], #1            ; get the first odd byte
        BL      Write252odd
        LDR     R7, [R1], #3            ; Note , #3 to get r1 correctly advanced
        ORR     R2, R6, R7, LSL #8
        WriteIDEWord R2, LR
        MOV     PC, R10

Write252odd     ROUT            ;entry/exit next byte in bottom byte of R6
        MOV     R0, #(256-4)/12
10
        SUBS    R0, R0, #1

        LDMIA   R1!,{R7-R9}

        ORR     R6, R6, R7, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R7, LSR #24

        ORR     R6, R6, R8, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R8, LSR #24

        ORR     R6, R6, R9, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R9, LSR #24

        BNE     %BT10
        MOV     PC, LR


; In
;   r1->destination
;   IDE
;   R10 = return address
; Out
;    r1->place after transfer of 256 bytes
;    r0,r2-r9,LR trashed
;

WriteCode32 ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     Write256OddAddress32
        BCS     Write256HalfWordAddress32

Write256WordAddress32 ROUT
        MOV     R0, #256
        B       %FT15

10
        LDMIA   R1!,{R2-R9}

        STR     R2, IDERegData
        STR     R3, IDERegData
        STR     R4, IDERegData
        STR     R5, IDERegData
        STR     R6, IDERegData
        STR     R7, IDERegData
        STR     R8, IDERegData
        STR     R9, IDERegData
15
        SUBS    R0, R0, #8*4
        BGE     %BT10

        CMP     R0, #-8*4
        MOVEQ   PC, R10

        ; 1/2-word aligned case - transfer the remaining 7 1/2 words
        LDMIA   R1!, {r2-r9}
        STR     R2, IDERegData
        STR     R3, IDERegData
        STR     R4, IDERegData
        STR     R5, IDERegData
        STR     R6, IDERegData
        STR     R7, IDERegData
        STR     R8, IDERegData
        STRH    R9, IDERegData
        SUB     R1, R1, #2              ; correction for non-transfered 1/2-word

20      MOV     PC, R10


Write256HalfWordAddress32
        LDRH    R2, [R1], #2
        MOV     R0, #256-2
        STRH    R2, IDERegData          ; store the odd halfword at the start
        B       %BT15

Write256OddAddress32 ROUT
        MOV     R0, #(256-4)/12
        BCS     Write256at4Nplus3_32

Write256at4Nplus1_32 ROUT
        BIC     R1, R1, #3
        LDR     R6, [R1], #4            ; cba.
        MOV     R6, R6, LSR #8          ; 0cba

10      SUBS    R0, R0, #1
        LDMIA   R1!, {R7-R9}            ; gfed kjih onml
        ORR     R6, R6, R7, LSL #24     ; dcba
        STR     R6, IDERegData
        MOV     R6, R7, LSR #8          ; 0gfe
        ORR     R6, R6, R8, LSL #24     ; hgfe
        STR     R6, IDERegData
        MOV     R6, R8, LSR #8          ; 0kji
        ORR     R6, R6, R9, LSL #24     ; lkji
        STR     R6, IDERegData
        MOV     R6, R9, LSR #8          ; 0onm
        BNE     %BT10

        LDRB    R7, [R1], #1            ; 000p
        ORR     R6, R6, R7, LSL #24     ; ponm
        STR     R6, IDERegData
        MOV     PC, R10

Write256at4Nplus3_32 ROUT
        LDRB    R6, [R1], #1            ; 000a

10      SUBS    R0, R0, #1
        LDMIA   R1!, {R7-R9}            ; edcb ihgf mlkj
        ORR     R6, R6, R7, LSL #8      ; dcba
        STR     R6, IDERegData
        MOV     R6, R7, LSR #24         ; 000e
        ORR     R6, R6, R8, LSL #8      ; hgfe
        STR     R6, IDERegData
        MOV     R6, R8, LSR #24         ; 000i
        ORR     R6, R6, R9, LSL #8      ; lkji
        STR     R6, IDERegData
        MOV     R6, R9, LSR #24         ; 000m
        BNE     %BT10

        LDR     R7, [R1], #3            ; .pon
        ORR     R6, R6, R7, LSL #8      ; ponm
        STR     R6, IDERegData
        MOV     PC, R10

 |

; this lot will be relocated into RAM at LowCodeLocation
ALowReadCodeStart ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     ARead256OddAddress
        BCS     ARead256HalfWordAddress
ARead256WordAddress ROUT
        MOV     R0, #256-4

        Align16  ALowReadCodeStart
10                              ;DONT REORDER, ALIGNMENT MOD 16 TIME CRITICAL
        SUBS    R0, R0, #7*4
        LDR     R2, IDERegData
        LDR     LR, IDERegData
        AND     R2, R2, R10,LSR #8

        ORR     R2, R2, LR, LSL #16
        LDR     R3, IDERegData
        LDR     LR, IDERegData
        AND     R3, R3, R10,LSR #8

        ORR     R3, R3, LR, LSL #16
        LDR     R4, IDERegData
        LDR     LR, IDERegData
        AND     R4, R4, R10,LSR #8

        ORR     R4, R4, LR, LSL #16
        LDR     R5, IDERegData
        LDR     LR, IDERegData
        AND     R5, R5, R10,LSR #8

        ORR     R5, R5, LR, LSL #16
        LDR     R6, IDERegData
        LDR     LR, IDERegData
        AND     R6, R6, R10,LSR #8

        ORR     R6, R6, LR, LSL #16
        LDR     R7, IDERegData
        LDR     LR, IDERegData
        AND     R7, R7, R10,LSR #8

        ORR     R7, R7, LR, LSL #16
        LDR     R8, IDERegData
        LDR     LR, IDERegData
        AND     R8, R8, R10,LSR #8

        ORR     R8, R8, LR, LSL #16
        STMIA   R1!,{R2-R8}
        BGT     %BT10
        LDR     R8, IDERegData

        AND     R8, R8, R10,LSR #8
        LDREQ   LR, IDERegData          ;EQ <=> 4n
        ORREQ   R8, R8, LR, LSL #16
        STREQ   R8, [R1], #4

        LDREQ   PC, RomReturn
        STRB    R8, [R1],#1             ;here if 4n+2
        MOV     R8, R8, LSR #8
        STRB    R8, [R1],#1

        LDR     PC, RomReturn

ARead256HalfWordAddress
        LDR     R8, IDERegData
        STRB    R8, [R1],#1
        MOV     R8, R8, LSR #8

        STRB    R8, [R1],#1
        MOV     R0, #256-4-2
        B       %BT10


ARead256OddAddress ROUT
        MOV     R0, #(256-4)/12

        MOV     R4, #&FF
        BCS     ARead256at4Nplus3
; so here we know that the address is 4N + 1
        LDR     R8, IDERegData
        STRB    R8, [R1], #1

        MOV     R8, R8, LSR #8
        STRB    R8, [R1], #1
        BL      ARead254odd
        LDR     PC, RomReturn

        Align16  ALowReadCodeStart-12
ARead254odd ROUT                ;corrupts R0,R2,R5-R8,LR
        LDR     R8, IDERegData
        STRB    R8, [R1],#1
        AND     R5, R4, R8, LSR #8

10                              ;DONT REORDER, ALIGNMENT MOD 16 TIME CRITICAL
        SUBS    R0, R0, #1              ;R5=next byte
        LDR     R2, IDERegData          ;xxxxBhBl
        LDR     R6, IDERegData          ;xxxxChCl
        AND     R2, R2, R10,LSR #8      ;0000BhBl

        ORR     R2, R2, R6, LSL #16     ;ChClBhBl
        LDR     R7, IDERegData          ;xxxxDhDl
        ORR     R6, R5, R2, LSL #8      ;ClBhBlAh
        LDR     R5, IDERegData          ;xxxxEhEl

        AND     R7, R10,R7, LSL #8      ;00DhDl00
        LDR     R8, IDERegData          ;xxxxFhFl
        ORR     R7, R7, R5, LSL #24     ;ElDhDl00
        ORR     R7, R7, R2, LSR #24     ;ElDhDlCh

        MOV     R5, R5, LSL #16         ;EhEl0000
        LDR     R2, IDERegData          ;xxxxGhGl
        AND     R8, R10,R8, LSL #8      ;00FhFl00
        ORR     R8, R8, R2, LSL #24     ;GlFhFl00

        ORR     R8, R8, R5, LSR #24     ;GlFhFlEh
        STMIA   R1!, {R6-R8}
        AND     R5, R4, R2, LSR #8      ;000000Gh
        BNE     %BT10

        STRB    R5, [R1],#1
        MOV     PC, LR

ARead256at4Nplus3 ROUT
; here we know the address is 4N + 3
        BL      ARead254odd
        LDR     R8, IDERegData
        STRB    R8, [R1],#1             ;here if 4n+2
        MOV     R8, R8, LSR #8
        STRB    R8, [R1],#1

        LDR     PC, RomReturn

ALowReadCodeEnd
ALowReadCodeSize * ALowReadCodeEnd - ALowReadCodeStart


; this will all be copied down into RAM at LowCodeLocation
;
; In
;   r1->destination
;   IDE
;   RomReturn (in workspace) (don't use LR)
; Out
;    r1->place after transfer of 256 bytes
;    r0,r2-r9,LR trashed
;
        MACRO
        WriteIDEWord $reg, $treg
        MOV     $treg, $reg, ASL #16
        ORR     $treg, $treg, $treg, LSR #16
        STR     $treg, IDERegData
        MOV     $treg, $reg, LSR #16
        ORR     $treg, $treg, $treg, ASL #16
        STR     $treg, IDERegData
        MEND

ALowWriteCodeStart ROUT
        MOVS    R2, R1, LSL #31         ;NE <=> bit 0, CS <=> bit 1
        BNE     AWrite256OddAddress
        BCS     AWrite256HalfWordAddress

AWrite256WordAddress ROUT
        MOV     R0, #256
        B       %FT15

10
        LDMIA   R1!,{R2-R9}

        WriteIDEWord R2, LR
        WriteIDEWord R3, LR
        WriteIDEWord R4, LR
        WriteIDEWord R5, LR
        WriteIDEWord R6, LR
        WriteIDEWord R7, LR
        WriteIDEWord R8, LR
        WriteIDEWord R9, LR

15
        SUBS    R0, R0, #8*4
        BGE     %BT10

        CMP     R0, #-8*4
        LDREQ   pc, RomReturn

        ; 1/2-word aligned case - transfer the remaining 7 1/2 words
        LDMIA   R1!, {r2-r9}
        WriteIDEWord R2, LR
        WriteIDEWord R3, LR
        WriteIDEWord R4, LR
        WriteIDEWord R5, LR
        WriteIDEWord R6, LR
        WriteIDEWord R7, LR
        WriteIDEWord R8, LR
        MOV     LR, R9, ASL #16
        ORR     LR, LR, LR, LSR #16
        STR     LR, IDERegData
        SUB     R1, R1, #2              ; correction for non-transfered 1/2-word

20
        LDR     PC, RomReturn


AWrite256HalfWordAddress
        BIC     R1, R1, #3

        LDR     R2, [R1], #4
        MOV     R2, R2, LSR #16
        ORR     R2, R2, R2, ASL #16
        STR     R2, IDERegData          ; store the odd halfword at the start

        MOV     R0, #256-2
        B       %BT15

AWrite256OddAddress ROUT
        BCS     AWrite256at4Nplus3

; so here we know the address is 4N + 1
        BIC     R1, R1, #3
        LDR     R6, [R1],#4             ; Pick up dcba to transfer dcb.
        MOV     LR, R6, LSR #8
        ORR     LR, LR, LR, ASL #16
        STR     LR, IDERegData          ; Write out .cb. which is in LR as cbcb
        MOV     R6, R6, LSR #24         ; Put d... into r6 as ...d
        BL      AWrite252odd
        LDRB    R7, [R1], #1            ; get the odd byte at the end
        ORR     R2, R6, R7, LSL #8      ; combine it with the odd byte from AWrite256odd
        ORR     R2, R2, R2, ASL #16     ; turn it into dcdc
        STR     R2, IDERegData
        LDR     PC, RomReturn

AWrite256at4Nplus3 ROUT
        LDRB    R6, [R1], #1            ; get the first odd byte
        BL      AWrite252odd
        LDR     R7, [R1], #3            ; Note , #3 to get r1 correctly advanced
        ORR     R2, R6, R7, LSL #8
        WriteIDEWord R2, LR
        LDR     PC, RomReturn

AWrite252odd    ROUT            ;entry/exit next byte in bottom byte of R6
        MOV     R0, #(256-4)/12
10
        SUBS    R0, R0, #1

        LDMIA   R1!,{R7-R9}

        ORR     R6, R6, R7, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R7, LSR #24

        ORR     R6, R6, R8, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R8, LSR #24

        ORR     R6, R6, R9, LSL #8
        WriteIDEWord R6, R2
        MOV     R6, R9, LSR #24

        BNE     %BT10
        MOV     PC, LR

ALowWriteCodeEnd
ALowWriteCodeSize * ALowWriteCodeEnd - ALowWriteCodeStart

 [ ALowWriteCodeSize > ALowReadCodeSize
ALowCodeSize    * ALowWriteCodeSize
 |
ALowCodeSize    * ALowReadCodeSize
 ]
;Claim multiple of 8 words for low code as moved 8 words at a time
 [ ALowCodeSize :MOD: (8*4) = 0
AWorkSize * LowCodeLocation+ALowCodeSize
 |
AWorkSize * LowCodeLocation+ALowCodeSize+8*4-(ALowCodeSize :MOD: (8*4))
 ]

 ]

        END
