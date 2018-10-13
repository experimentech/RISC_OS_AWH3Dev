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
; > OutputDump

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Specialised 24 pin PDumper.
; ---------------------------
;
                GET     ^.Generic.OutputDump.s

;..............................................................................
;
; Output monochrome sprite to the current file.
;
;  in: R0 ->Strip
;      R1 dump width in bytes
;      R2 dump height in rows
;      R3 row width in bytes (>=R3)
;      R5 Row width in bytes
;      R7 ->Job workspace
;
; out: -

output_mono_sprite ROUT

        Push    "LR"

        Debug   Dump,"Strip at",R0
        Debuga  Dump,"Width in pixels",R1
        Debug   Dump," and in bytes",R3
        Debug   Dump,"Number of scans",R4

        ADD     R7,R7,#pd_data          ; Address the sequences
04                                      ; Back for next total pass
        SWI     XOS_ReadEscapeState
        Pull    "PC",CS                 ; Return if an escape is pending

        Push    "R0"                    ; Preserve the line start for interlace
        MOV     R2,#0                   ; Vertical interlace

        LDRB    R1,[R7,#pd_interlace -pd_data]
        ADD     R1,R1,#1                ; Multiply line step by vertical interlace factor
03                                      ; Back for next vert. interlace pass
        Push    "R0-R5"

        MOV     r4, #255
        MOV     r3, r5
        BL      get24_length            ; Get the length of a 24 line
        MOVS    R3,LR,LSL #3            ; Multiply length by 8
        BLE     %FT10                   ; Skip this line if length is zero

; Adjust start position and length for leading zeros, and then modify the
; skip length to include the left margin and to be in the skip DPI, which
; is always 60 (for EPSONs) or 120 (for IBMs). Returns remainder of skip
; in R4. If we are not skipping, put the left margin in R4 instead.

        MOVS    r8, r8, LSL #3          ; Multiply skip by 8
        PDumper_GetLeftMargin R4,EQ
;<<        LDREQ   r4, [r7, #pd_leftmargin - pd_data]      ; Margin if no skip
        ADDNE   r0, r0, r8, LSR #3      ; Adjust the data start, NO multiply
        BLNE    adjust_24_skip

        MUL     R5,R1,R5
        LDRB    R9,[R7,#pd_x_interlace -pd_data]
02                                      ; Back for next X interlace pass
        Push    "R0,R3,R8,R9"           ; Preserve line start and horizontal interlace
        TEQ     R8, #0
        BEQ     %FT20                   ; No leading zero skip
        LDRB    R1, [R7, #pd_data_zero_skip]
        ADD     R1, R7, R1
        PDumper_PrintCountedString R1,R2,LR
        PDumper_PrintBinaryPair R8,R2
20                                      ; No leading zero skip
        LDRB    R1,[R7,#pd_data_line_start]
        CMP     R1,#0                   ; Line start data
        BEQ     %FT20

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,R6
20
        LDRB    R1,[R7,#pd_data_dlm]    ; Line length * dlm + dla
        ADD     LR,R4,R3                ; Add left margin or skip remainder
        LDRB    R6,[R7,#pd_data_dla]
        MLA     R6,R1,LR,R6             ; Calculate the total line length
        PDumper_PrintBinaryPair R6,R1

        LDRB    R1,[R7,#pd_data_line_start_2]
        CMP     R1,#0                   ; Is there a second line start sequence
        BEQ     %FT20

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,R6
20
        BL      send24_leading          ; Output margin/excess skip as zeros

        MOV     R2,#1                   ; Per dump_depth do R3 bits across, using R2 as mask
01                                      ; Back for next X position
        Push    "R0,R7"

        LDRB    R7,[R7,#pd_data_dht]    ;Get number of bit rows high (<=24)

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        CMP     R7,#24
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#22
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#20
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#18
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#16
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#14
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#12
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#10
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
20
        PDumper_OutputReg R6

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
20
        PDumper_OutputReg R6

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        CMP     R7,#9
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#11
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#13
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#15
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#17
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#19
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#21
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#23
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R2
        ORRNE   R6,R6,#1
80
20
        PDumper_OutputReg R6

        Pull    "R0,R7"                 ; Move to next horizontal position

        SUBS    R9,R9,#1
        LDRMIB  R9,[R7,#pd_x_interlace -pd_data]
        MOV     R2,R2,LSL #1
        CMP     R2,#128
        ADDGT   R0,R0,#1
        MOVGT   R2,#1
        SUBS    R3,R3,#1
        BGT     %BT01                   ; Go back for next horiz. position
25
        Pull    "R0,R3,R8,R9"           ; Handle the horizontal interlace
        SUBS    R9,R9,#1
        BLT     %FT10

        LDRB    R1,[R7,#pd_data_line_return]
        CMP     R1,#0                   ; Line return data
        BEQ     %FT20

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,LR
20
        B       %BT02                   ; Go back for next X interlace pass
10
        Pull    "R0-R5"

        Debug   Dump,"Line now finished"

        ADD     R8,R7,#pd_data_line_end
        LDRB    R8,[R8,R2]
        CMP     R8,#0                   ;Is there any for this pass?
        BEQ     %FT20

        ADD     R8,R7,R8
        PDumper_PrintCountedString R8,R9,R6
20
        ADD     R2,R2,#1
        ADD     R0,R0,R5
        CMP     R2,R1
        BLT     %BT03                   ; Go back for next vert. interlace

        Pull    "R0"                    ; Now move down by dht*interlace rows and do next lot

        LDRB    R8,[R7,#pd_data_dht]
        MUL     R8,R1,R8
        MLA     R0,R5,R8,R0
        SUBS    R4,R4,R8
        BGT     %BT04                   ; Go back for next total pass

        Debug   Dump,"Finished strip"

        Pull    "PC"

;..............................................................................
;
; Output a 8BPP sprite to the current file.
;
;  in: R0 ->Strip
;      R1 dump width in bytes
;      R2 dump height in rows
;      R3 row width in bytes (>=R3)
;      R5 Row width in bytes
;      R7 ->Job workspace
;
; out: -

output_grey_sprite ROUT
output_colour_sprite ROUT

        Push    "LR"

        ADD     R7,R7,#pd_data
05                                      ; Back for next total pass
        SWI     XOS_ReadEscapeState
        Pull    "PC",CS                 ; Return if escape pending

        Push    "R0"

        MOV     R2,#0                   ; Level of vertical interlace

        LDRB    R1,[R7,#pd_interlace -pd_data]
        ADD     R1,R1,#1
04                                      ; Back for next vert. interlace pass
        Push    "R0-R5"
stack_04_r0 * 0
stack_04_r5 * 20

        MUL     R5,R1,R5                ; Vertical line data step multiplied by interlace
        MOV     R6,#0                   ;Multiple ribbon passes required
03                                      ; Back for next colour pass
        MOV     R9,#1
        MOV     R4,R9,LSL R6            ; Get correct bit for this pass

        LDR     r0, [sp, #stack_04_r0]
        LDR     r3, [sp, #stack_04_r5]
        BL      get24_length
        MOVS    R3, LR                  ; Is this colour pass zero length?
        MOVLE   r1, #0                  ; Flag to say no line return please
        BLE     %FT11                   ; Go and do the next color pass

; Adjust start position and length for leading zeros, and then modify the
; skip length to include the left margin and to be in the skip DPI, which
; is always 60 (for EPSONs) or 120 (for IBMs). Returns remainder of skip
; in R4. If we are not skipping, put the left margin in R4 instead.

        TEQ     r8, #0
        PDumper_GetLeftMargin R4,EQ
;<<        LDREQ   r4, [r7, #pd_leftmargin - pd_data]      ; Margin if no skip
        ADDNE   r0, r0, r8              ; Adjust the data start.
        BLNE    adjust_24_skip          ; Tramples on mask in r4.

        LDRB    R9,[R7,#pd_x_interlace -pd_data]
02                                      ; Back for next X interlace pass
        Push    "R0,R3,R4,R6,R8,R9"
stack_02_r6 * 12

        TEQ     R8, #0
        BEQ     %FT20                   ; No leading zero skip
        LDRB    R1, [R7, #pd_data_zero_skip]
        ADD     R1, R7, R1
        PDumper_PrintCountedString R1,R2,LR
        PDumper_PrintBinaryPair R8,R2
20                                      ; No leading zero skip
        LDRB    LR,[R7,#pd_passes_per_line -pd_data]
        CMP     LR,#1                   ;Line start (pd_data_line_start+ 2*ribbonpass +2 if passes >1)
        MOV     R6,R6,ASL#1
        ADDGT   R6,R6,#2
        ADD     R6,R6,#pd_data_line_start
        LDRB    R1,[R7,R6]
        CMP     R1,#0                   ;Any sequence for this pass?
        BEQ     %FT20                   ;Obviously not

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,LR
20
        LDRB    R1,[R7,#pd_data_dlm]
        ADD     LR,R4,R3                ; Add left margin or skip remainder
        LDRB    r8,[R7,#pd_data_dla]
        MLA     r8,R1,LR,r8             ;Line length+left margin *dlm +dla
        PDumper_PrintBinaryPair r8,R1

        ADD     R6,R6,#1                ;Line start 2 data (pd_data_line_start+ 2*....

        LDRB    R1,[R7,R6]
        CMP     R1,#0                   ;Any postfixing string
        BEQ     %FT20

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,LR
20
        BL      send24_leading          ; Output margin/excess skip as zeros
        LDR     lr, [sp, #stack_02_r6]  ; Get colour pass number now that
        MOV     r4, #1                  ; we have finished with r4.
        MOV     r4, r4, LSL lr          ; Get correct bit for this pass.

        MOV     R8,R3                   ;Setup the horizontal bit count per bit slice horizontally
01                                      ; Back for next X position
        Push    "R0,R7"

        LDRB    R7,[R7,#pd_data_dht]    ;Get number of bit rows high (<=24)

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        CMP     R7,#24
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#22
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#20
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#18
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#16
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#14
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#12
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#10
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
20
        PDumper_OutputReg R6

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
20
        PDumper_OutputReg R6

        MOV     R6,#0
        CMP     R9,#0
        BNE     %FT20                   ;If at ignore point output a null

        CMP     R7,#9
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#11
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#13
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#15
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#17
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#19
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#21
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
        MOV     R6,R6,LSL #1            ;Munge in bit from pass correctly

        CMP     R7,#23
        BLT     %FT80
        LDRB    R1,[R0],R5
        TST     R1,R4
        ORRNE   R6,R6,#1
80
20
        PDumper_OutputReg R6

        Pull    "R0,R7"

        SUBS    R9,R9,#1
        LDRMIB  R9,[R7,#pd_x_interlace -pd_data]
        ADD     R0,R0,#1
        SUBS    R8,R8,#1
        BGT     %BT01                   ;Now move on to next x position

        Pull    "R0,R3,R4,R6,R8,R9"     ;Handle horizontal interlace
        SUBS    R9,R9,#1
        BLT     %FT10

        LDRB    R1,[R7,#pd_data_line_return]
        CMP     R1,#0                   ;Is there any return data?
        BEQ     %FT20

        ADD     R1,R7,R1
        PDumper_PrintCountedString R1,R2,LR
20
        B       %BT02
10
        LDRB    R1,[R7,#pd_data_line_return]
11                                      ; Come here to miss a colour pass
        LDRB    R8,[R7,#pd_passes_per_line -pd_data]
        ADD     R6,R6,#1
        CMP     R6,R8                   ;Multi-ribbon handling?
        BGE     %FT25

        CMP     R1,#0                   ;Output line return data
        BEQ     %FT20

        ADD     R8,R7,R1
        PDumper_PrintCountedString R8,R1,R2
20
        B       %BT03
25
        Pull    "R0-R5"

        ADD     R8,R7,#pd_data_line_end
        LDRB    R8,[R8,R2]
        CMP     R8,#0                   ;End of line sequence
        BEQ     %FT20                   ;There is not one

        ADD     R8,R7,R8
        PDumper_PrintCountedString R8,R9,R6
20
        ADD     R2,R2,#1                ;Move down to correct position and next interlace line
        ADD     R0,R0,R5
        CMP     R2,R1
        BLT     %BT04                   ;Loop back

        Pull    "R0"

        LDRB    R8,[R7,#pd_data_dht]
        MUL     R8,R1,R8
        MLA     R0,R5,R8,R0
        SUBS    R4,R4,R8
        BGT     %BT05                   ;Move down by dht rows and do next lot

        Pull    "PC"

;..............................................................................
;
; send24_leading .. send leading zeros for the 24 pin dumper
;
; in    R4 = number of pixels to output
;       R7 ->pd_data block
; out   V =1 => R0 -> error block

send24_leading ROUT

        Push    "R0-R1,LR"

        MOV     R0,#0
        MOV     R1,#24
        MUL     R1,R4,R1                ;Data to be sent (zeros * 24)

send24_leadingloop
        SUBS    R1,R1,#8                ;Decrease by 8 as dump depth is a multiple of 8
        Pull    "R0-R1,PC",MI           ;And return when <0

        PDumper_OutputReg R0
        B       send24_leadingloop      ;Loop back until all sent


;..............................................................................
;
; get24_length .. obtain length of a scan line, removing any trailing and
; leading zeros.
;
; Get the line length of the line to be sent.
; This routine attempts to ensure that the length of the line is valid.  The
; routine scans the line attempting to find the point where no more data is
; transmitted.  The loop has to check the complete dump depth and returns the
; byte width which you should then modify as required for you specific dumper.
;
; The routine checks all scans within the specified dump depth (a multiple
; of 8) and then returns.
;
;  in: R0 ->Strip to be scanned
;      r3 Original length of a line
;      R4 - bit mask for this pass
;      R7 ->Configuration block
; out: r0 -> adjusted start of strip
;      r8 = skip length, at printer skip DPI (usually 60 or 120)
;      LR = modified length of the line
;

get24_length Entry "R0-R2,R6"
  [ No32bitCode
stack_get24_r0 * Proc_RegOffset
  |
        SavePSR r2
        Push    r2
stack_get24_r0 * Proc_RegOffset + 4
  ]

; Find trailing zeros first.
        LDRB    R1, [R7, #pd_dump_depth -pd_data]
        MOV     R2, #-1         ; Shortest number of trailing zeros so far

get24_trail_newline
        MOV     r6, r3          ; Length of line to be printed

get24_trail_scanline
        SUB     r6, r6, #1      ; Have we finished the line yet?
        CMP     r6, r2
        BLE     get24_trail_finishedline

        LDRB    LR, [R0, r6]
        TST     LR, r4          ; Any trailing zeros?
        BEQ     get24_trail_scanline  ; Loop again until either end of line or non-zero byte

get24_trail_finishedline
        MOV     R2, r6          ; Update shortest trailing zeros found

        ADD     R0, R0, r3      ; Adjust starting position
        SUBS    R1, R1, #1      ; Have we checked all the scan lines yet?
        BGT     get24_trail_newline

        ADDS    LR, R2, #1
        LDRNEB  r1, [r7, #pd_data_version - pd_data]
        TEQNE   r1, #0          ; Check for version > 0
        LDRNEB  r1, [r7, #pd_data_zero_skip]
        TEQNE   r1, #0          ; Quit now if can't skip on this printer or
        MOVEQ   r8, #0          ; if line zero length (for speed and ease)
        BEQ     get24_length_exit


; Now find leading zeros.
        LDR     r0, [sp, #stack_get24_r0]
        LDRB    r1, [r7, #pd_dump_depth -pd_data]
        MOV     r8, lr          ; Don't go into trailing zeros

get24_lead_newline
        MOV     r6, #-1         ; Sart at beginning of line

get24_lead_scanline
        ADD     r6, r6, #1      ; Have we finished the line yet?
        CMP     r6, r8
        BGE     get24_lead_finishedline

        LDRB    r2, [r0, r6]
        TST     r2, r4          ; Any leading zeros?
        BEQ     get24_lead_scanline  ; Loop again until non-zero byte

get24_lead_finishedline
        MOV     r8, r6          ; Update shortest leading zeros found

        ADD     r0, r0, r3      ; Adjust starting position
        SUBS    r1, r1, #1      ; Have we checked all the scan lines yet?
        BGT     get24_lead_newline

; Adjust returned data length to skip the zeros.

        SUB     lr, lr, r8
get24_length_exit
  [ No32bitCode
        EXITS
  |
        Pull    r2
        RestPSR r2,,f
        EXIT
  ]


; This routine adds the left margin into the length to skip, and then
; modifies the skip to be at the skip resolution. The remainder of this is
; calculated (eg. 60 DPI skip at 180 DPI gives remainders of 0,1 or 2), to
; be output as extra zeros, effectively as a new sort of "left margin".

; In:   r8 = skip at output DPI without left margin
; Out:  r4 = skip remainder at output DPI inc. left margin
;       r8 = skip at skip DPI inc. left margin

adjust_24_skip EntryS "r0-r2"
        PDumper_GetLeftMargin lr
        ADD     r8, r8, lr      ; Add left margin to zero skip.

        LDRB    r2, [r7, #pd_data_pixel_run_up] ; 1/6 inch run-up for head
        SUBS    r8, r8, r2      ; Subtract run-up from zero skip
        ADDMI   r4, r2, r8      ; Reduce run-up if skip goes negative
        MOVMI   r8, #0          ; Ensure skip not negative
        EXITS   MI              ; Skip is zero so might as well quit

        LDR     r1, [r7, #pd_data_skip_multiplier]
        MUL     r0, r8, r1      ; Multiply by multiplier

        LDR     r4, [r7, #pd_data_skip_divider] ; Divide by divider
        TEQ     r4, #1          ; Is divider 1?
        MOVEQ   r4, r2          ; If so, remainder is run-up and
        MOVEQ   r8, r0          ; result is unaffected.
        EXITS   EQ
        DivRem  r8, r0, r4, lr  ; r4 is preserved, r0 becomes remainder

        TEQ     r1, #1          ; Is multiplier 1?
        ADDEQ   r4, r0, r2      ; Put print head run up on to remainder
        EXITS   EQ
        DivRem  r4, r0, r1, lr  ; Divide remainder by multiplier

        ADD     r4, r4, r2      ; Put print head run up on to remainder
        EXITS

        END
