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
; > NewModels

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ConvertRGBtoHSV_Code
;
; in:   r0  = R 0 ->   1.0 (16.16 fixed)
;       r1  = G 0 ->   1.0 (16.16 fixed)
;       r2  = B 0 ->   1.0 (16.16 fixed)
;
; out:  r0  = H 0-> 360.0 (16.16 fixed)
;       r1  = S 0->   1.0 (16.16 fixed)
;       r2  = V 0->   1.0 (16.16 fixed)
;
; This function will convert the given RGB colour into the HSV colour model.
;

ConvertRGBtoHSV_Code ROUT
                Debug   input1,"ConvertRGBtoHSV: R0-R2",R0,R1,R2
                Debug   input1,"ConvertRGBtoHSV: red, green, blue",R0,R1,R2

                Push    "r3-r10, lr"

                MOV     r8, r0
                MOV     r9, r1
                MOV     r10, r2                 ; move r,g and b into r8, r9 and r10.

                MOV     r6, r0
                CMP     r1, r6
                MOVGT   r6, r1
                CMP     r2, r6
                MOVGT   r6, r2                  ; r6 = max(red,green,blue)

                MOV     r7, r0
                CMP     r1, r7
                MOVLT   r7, r1
                CMP     r2, r7
                MOVLT   r7, r2                  ; r7 = min(red,green,blue)

                SUB     r5, r6, r7              ; v =(v-temp)

        ; r5     = max-min
        ; r6     = max (value)
        ; r7     = min (temp)
        ; r8-r10 = red, green, blue

                TEQ     r6, #0                  ; is value =0?
                MOVEQ   r4, #0
                BEQ     %FT10                   ; yes, so saturation =0

                MOV     r0, r5, ASL #16
                MOV     r1, r5, ASR #16
                BL      arith_DSdivS            ; r4 = (r0,r1)/r6
                DCB     r0, r6, r4
                ALIGN

10              TEQ     r4, #0                  ; if saturation =0, then hue is undefined
                MOVEQ   r3, #-1
                BEQ     %FT20                   ; and exit.

                SUB     r0, r6, r10
                MOV     r1, r0, ASR #16
                MOV     r0, r0, ASL #16
                BL      arith_DSdivS            ; r2 = (v-b)/(v-temp)
                DCB     r0, r5, r2
                ALIGN
                Push    "r2"                    ; and push to stack

                SUB     r0, r6, r9
                MOV     r1, r0, ASR #16
                MOV     r0, r0, ASL #16
                BL      arith_DSdivS            ; r2 = (v-g)/(v-temp)
                DCB     r0, r5, r2
                ALIGN
                Push    "r2"                    ; and push to stack

                SUB     r1, r6, r8
                MOV     r2, r1, ASR #16
                MOV     r1, r1, ASL #16
                BL      arith_DSdivS            ; r2 = (v-r)/(v-temp)
                DCB     r1, r5, r0
                ALIGN

                Pull    "r1-r2"                 ; r0 =Cr, r1 =Cg, r2 =Cb.

                TEQ     r8, r6                  ; if red=value then colour between yellow and magenta
                SUBEQ   r3, r2, r1
                TEQ     r9, r6                  ; if green=value then colour between cyan and yellow
                SUBEQ   r3, r0, r2
                ADDEQ   r3, r3, #&20000
                TEQ     r10, r6                 ; if blue=value then colour between magenta and cyan
                SUBEQ   r3, r1, r0
                ADDEQ   r3, r3, #&40000

                MOV     lr, #60
                MULS    r3, lr, r3              ; convert to degrees
                ADDMI   r3, r3, #360:SHL:16     ; and ensure not -ve

20      ; r3 = hue, r4 = saturation, r6 = value

                ADDS    r0, r3, #0              ; clear V
                MOV     r1, r4
                MOV     r2, r6                  ; move values down into correct return registers

                Debug   output,"Leaving RGBToHSV: h, s, v",R0,R1,R2

                Pull    "r3-r10, pc"

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Mul_1616
;
; in:   $a = signed fixed point value
;       $b = signed fixed point value
;
; out:  $dest = result of $a*$b
;       r0, lr corrupt
;
; Multiply two 16.16 fixed point values, keeping the point at b16.
;
  [ NoARMM
           ; Long multiply not supported - do it the hard way
           MACRO
           Mul_1616 $dest, $a, $b
         [ "$a" <> "r0"
           ASSERT "$b" <> "r0"
           MOV    r0, $a
         ]
         [ "$b" <> "r1"
           MOV    r1, $b
         ]
           BL     _Mul_1616
         [ "$dest" <> "r0"
           MOV    $dest, r0
         ]
           MEND
           
_Mul_1616  ROUT

           Push  "r1-r3, lr"

           MOV    r2, r1, ASR #16       ; r2 = scale_hi
           BIC    r1, r1, r2, LSL #16   ; r1 = scale_lo
           MOV    r3, r0, ASR #16       ; r3 = input_hi
           BIC    r0, r0, r3, LSL #16   ; r0 = input_lo

           MUL    lr, r2, r0            ; lr = scale_hi * input_lo
           MLA    lr, r1, r3, lr        ; lr = scale_lo * input_hi + lr
           MUL    r0, r1, r0            ; r0 = scale_lo * input_lo
           MUL    r1, r2, r3            ; r1 = scale_hi * input_hi

           ADD    r0, lr, r0, LSR #16
           ADD    r0, r0, r1, LSL #16   ; r0 = answer!

           Pull  "r1-r3, pc"
  |
           ; Long multiply supported - inline the code
           MACRO
           Mul_1616 $dest, $a, $b
           ASSERT "$dest" <> "$b"
           ASSERT "$dest" <> "lr"
           SMULL  $dest, lr, $b, $a
           MOV    $dest, $dest, LSR #16
           ORR    $dest, $dest, lr, LSL #16
           MEND
  ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ConvertHSVtoRGB
;
; in:   r0 = H 0 -> 360.0 (16.16 fixed)
;       r1 = S 0 ->   1.0 (16.16 fixed)
;       r2 = V 0 ->   1.0 (16.16 fixed)
;
; out:  r0 = R 0 ->   1.0 (16.16 fixed)
;       r1 = G 0 ->   1.0 (16.16 fixed)
;       r2 = B 0 ->   1.0 (16.16 fixed)
;
; This routine converts from HSV to RGB colour.
;

ConvertHSVtoRGB_Code ROUT
                Debug   input1,"ConvertHSVtoRGB: R0-R2",R0,R1,R2
                Debug   input2,"ConvertHSVtoRGB: h, s, v",R0,R1,R2

                Push    "r3-r9 , lr"

        ; check for achromatic colour case

                TEQ     r1, #0                  ; is saturation =0?
                BNE     %FT10

                CMP     r0, #0                  ; is hue undefined? (will Clear V!)
                ADREQ   r0, ErrorBlock_CTBadHSV
                BLEQ    LookupError             ; Always sets the V bit
                Pull    "r3-r9 , pc",VS         ; in the achromatic colour case, hue is undefined

                MOV     r0, r2
                MOV     r1, r2                  ; setup r0, r1 to contain V
                Debug   output,"RGBToHSV: achromatic",R0,R1
                Pull    "r3-r9, pc"             ; and then return home

10      ; so its not achromatic it is infact a chromatic colour
        ; we must now calculate the R,G and B based on the positions given
        ; in the hex cone.
        ;
                CMP     r0, #360:SHL:16
                SUBGE   r0, r0, #360:SHL:16     ; ensure within nice range

                MOV     r4, r1                  ; r4 = saturation
                MOV     r5, r2                  ; r5 = value

                MOV     r1, r0, ASR #16
                MOV     r0, r0, ASL #16
                MOV     r2, #60:SHL:16          ; convert to nice whizzo value
                BL      arith_DSdivS
                DCB     r0, r2, r3              ; r3 =result of (hue/60)
                ALIGN

                MOV     r6, r3, ASR #16         ; r6 =Floor(hue)
                BIC     r3, r3, r6, ASL #16     ; r3 =fractional element of hue

                RSB     r1, r4, #&10000
                Mul_1616 r7, r5, r1             ; = v*(1-s)

                Mul_1616 r0, r4, r3             ; = (s*f)
                RSB     r0, r0, #&10000         ; = 1-(s*f)
                Mul_1616 r8, r0, r5             ; = v*(1-(s*f))

                RSB     r1, r3, #&10000
                Mul_1616 r0, r4, r1             ; = (s*(1-f)
                RSB     r0, r0, #&10000
                Mul_1616 r0, r0, r5             ; = v*(1-S*(1-f)
                ADDS    r9, r0, #0              ; clear V

        ; f=r3, s=r4, v=r5, i=r6, m=r7, n=r8, k=r9

                Debug   output,"No debugging on tail end - need rewrite!)"

                MOV     lr, pc                  ; setup return address
                ADD     pc, pc, r6, ASL #4
                Pull    "r3-r9, pc"             ; return home

                MOV     r0, r5                  ; case 0; r=v, g=k, b=m
                MOV     r1, r9
                MOV     r2, r7
                MOV     pc, lr

                MOV     r0, r8                  ; case 1; r=n, g=v, b=m
                MOV     r1, r5
                MOV     r2, r7
                MOV     pc, lr

                MOV     r0, r7                  ; case 2; r=m, g=v, b=k
                MOV     r1, r5
                MOV     r2, r9
                MOV     pc, lr

                MOV     r0, r7                  ; case 3; r=m, g=n, b=v
                MOV     r1, r8
                MOV     r2, r5
                MOV     pc, lr

                MOV     r0, r9                  ; case 4; r=k, g=m, b=v
                MOV     r1, r7
                MOV     r2, r5
                MOV     pc, lr

                MOV     r0, r5                  ; case 5; r=v, g=m, b=n
                MOV     r1, r7
                MOV     r2, r8
                MOV     pc, lr

                LTORG

                MakeEitherErrorBlock CTBadHSV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ConvertRGBtoCMYK
;
; in:   r0  = R 0 -> 1.0 (16.16 fixed)
;       r1  = G 0 -> 1.0 (16.16 fixed)
;       r2  = B 0 -> 1.0 (16.16 fixed)
;
; out:  r0  = C 0 -> 1.0 (16.16 fixed)
;       r1  = M 0 -> 1.0 (16.16 fixed)
;       r2  = Y 0 -> 1.0 (16.16 fixed)
;       r3  = K 0 -> 1.0 (16.16 fixed)
;
; Conversion of R,G and B to C,M,Y and K.
;

ConvertRGBtoCMYK_Code ROUT

                Debug   input1,"RGBtoCMYK: R0-R2",R0,R1,R2
                Debug   input2,"RGBtoCMYK: R G B",R0,R1,R2

                Push    "lr"

                RSB     r0, r0, #&10000         ; negate the colour vector to get CMY
                RSB     r1, r1, #&10000
                RSB     r2, r2, #&10000

                MOV     r3, r0
                CMP     r1, r3
                MOVLT   r3, r1
                CMP     r2, r3
                MOVLT   r3, r2                  ; get min (C,M,Y)

                SUB     r0, r0, r3
                SUB     r1, r1, r3
                SUB     r2, r2, r3              ; subtract key (equally from all colours)

                Debug   output,"RGBtoCMYK returns C M Y K",R0,R1,R2,R3

                CLRV
                Pull    "pc"

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ConvertCMYKtoRGB
;
; in:   r0 = C 0 -> 1.0 (16.16 fixed)
;       r1 = M 0 -> 1.0 (16.16 fixed)
;       r2 = Y 0 -> 1.0 (16.16 fixed)
;       r3 = K 0 -> 1.0 (16.16 fixed)
;
; out:  r0 = R 0 -> 1.0 (16.16 fixed)
;       r1 = G 0 -> 1.0 (16.16 fixed)
;       r2 = B 0 -> 1.0 (16.16 fixed)
;       r3 preserved.
;
; This routine converts from CMYK to RGB, based around the CMY colour model
; conversion with extensions for K (black).
;

ConvertCMYKtoRGB_Code ROUT

                Debug   input1,"CMYKtoRGB: R0-R3",R0,R1,R2,R3
                Debug   input2,"CMYKtoRGB: C M Y K",R0,R1,R2,R3

                Push    "r3, lr"

                ADD     r0, r0, r3              ; restore key whilst keeping in range
                CMP     r0, #&10000
                MOVGT   r0, #&10000
                ADD     r1, r1, r3
                CMP     r1, #&10000
                MOVGT   r1, #&10000
                ADD     r2, r2, r3
                CMP     r2, #&10000
                MOVGT   r2, #&10000

                RSB     r0, r0, #&10000         ; re-invert colour index
                RSB     r1, r1, #&10000
                RSB     r2, r2, #&10000

                Debug   output,"CMYKtoRGB: returning R G B",R0,R1,R2

                CLRV
                Pull    "r3, pc"

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Subroutine to divide a double precision unsigned number by a single
; precision unsigned number, yielding a single precision unsigned result.
; The word following the BL should contain the number of the register holding
; the ls part of the dividend in its bottom byte; the ms part of the dividend
; is in the next register. The next byte of the word contains the number of
; the divisor register, and the next byte the number of the register in which
; to deposit the quotient.
;   This_Code routine will only work on registers R0-R8. It assumes that the
; divisor is not zero, and that the quotient will not overflow.

arith_DSdivS
        Push    "R0-R8"
        SUB     R8,R14,PC
        ADD     R8,PC,R8                ;R8 = LR without flags + 4
        LDRB    R0,[R8,#-4]             ;Get first operand
        ADD     R0,R13,R0,LSL #2
        LDMIA   R0,{R0,R1}
        LDRB    R2,[R8,#-3]             ;Get second operand
        LDR     R2,[R13,R2,LSL #2]
        MOV     R3,#1                   ;Init. quotient with a sentinel bit
arith_DSdivS_loop
        ADDS    R0,R0,R0                ;Shift a bit up into the ms half of
        ADC     R1,R1,R1                ;  the dividend
        CMP     R1,R2                   ;Do trial subtraction, producing
        SUBCS   R1,R1,R2                ;  result bit in C
        ADCS    R3,R3,R3                ;Result bit into result, then loop
        BCC     arith_DSdivS_loop       ;  unless sentinel bit shifted out
        LDRB    R0,[R8,#-2]             ;Store the result on the stack, to be
        STR     R3,[R13,R0,LSL #2]      ;  picked up by the correct registers
        Pull    "R0-R8"
        ADD     PC,R14,#4               ;Skip the argument word on return


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


        END

