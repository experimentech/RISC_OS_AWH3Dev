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

; Blend into 16/32 bit per pixel, with supremacy or alpha blending
; This code is needed multiple times (once for supremacy, once for alpha) but
; is too big for a macro. So we GET it multiple times instead.


blend_putdata$routine._32bpp

        ANDS    outdata, outdata, outmask               ; ensure only relevant bits are set
        BEQ     blend_nodata

        Push    "R1-R3, LR"

        LDR     R1, blend_fgvalue                       ; get the foreground painting colour
        LDR     R2, blend_fgalpha                       ; and the foreground alpha

        ; outdata = &00000000-&00001000 (clear->solid)
        MOV     outdata, outdata, LSR # 8               ; amount of foreground to blend
        ; outdata = 0-&10 (clear-solid)
        MUL     outdata, R2, outdata                    ; scale by foreground alpha
        ; outdata = 0-&1000 (clear-solid)
        MOVS    outdata, outdata, LSR #8                ; scale back to 0-&10
        ADC     outdata, outdata, #0                    ;   and round

        RSB     LR, outdata, # 16                       ;   and the amount of background

        LDR     pchar, [ outptr ]                       ; and pick up the current background pixel data
      [ "$routine" = "S"
        MOVS    R2, pchar, LSR #24
      |
        MVNS    R2, pchar, LSR #24
      ]
        BEQ     blend_putdata_32bpp_common
        ADRL    LR, blend_putdata_32bpp_common
        ; fall through into blend_putdataS_32bpp_nonopaque

; In pchar(R0) = screen data (non-opaque)
;    outdata(R8) = anti-alias level 0-16 (clear-solid)
;    R2 = bg supremacy (0-255) (solid-clear)
;    blend_putdata's R1-R3,LR stacked
; Out: outdata and LR updated to reflect correct fg/bg weighting
;      pchar's supremacy/alpha byte updated with composite supremacy/alpha
;      R2,R3,outmask corrupted
;      may jump out to blend_nodata if applicable

; Terminology: R,G,B,A components
;              suffix t denotes top (ie text)
;                     b denotes bottom (ie screen background)
;                     c denotes composite (ie blended)
blend_putdata$routine._32bpp_nonopaque
;        Can corrupt R2-R3 freely
; First calculate composite alpha level. FG alpha (At) is in range 0-16,
; BG alpha (Ab) is in range 255-0.
; First Ac = 1 - (1 - At) * (1 - Ab)
        CMP     R2, #128
        ADDGT   R2, R2, #1      ; R2 = 1-Ab scaled 0-&100
        RSB     outmask, outdata, #16; outmask = 1-At scaled 0-&10
        MUL     R3, R2, outmask ; R3 = (1-At)*(1-Ab) - 0-&1000
        RSBS    R3, R3, #4096   ; R3 = Ac (0=clear - &1000=solid)
        BEQ     blend32$routine._nodata

; Note Ac must >= At

; s := At / Ac
        MOV     R2, outdata, LSL #16    ; R2 = At scaled 0-&100000
        DivRem  outdata, R2, R3, outmask, norem; outdata = At/Ac = s scaled 0-&100
        MOVS    outdata, outdata, LSR #4; s scaled 0-&10
        ADC     outdata, outdata, #0    ; round
        MOVS    R3, R3, LSR #4          ; R3 = Ac scaled 0-&100
        ADC     R3, R3, #0              ; round
        CMP     R3, #128
        SUBGE   R3, R3, #1              ; R3 = Ac scaled 0-&FF
      [ "$routine" = "S"
        ORR     pchar, pchar, #&FF000000
        SUB     pchar, pchar, R3, LSL #24  ; Place Ac in pchar
      |
        BIC     pchar, pchar, #&FF000000
        ORR     pchar, pchar, R3, LSL #24  ; Place Ac in pchar
      ]
        MOV     R2, LR
        RSB     LR, outdata, #16        ; t scaled 0-&10
        MOV     PC, R2

blend32$routine._nodata
        Pull    "R1-R3, LR"
        B       blend_nodata

blend_putdata$routine.M_32bpp

        ANDS    outdata, outdata, outmask
        BEQ     blend_nodata                            ; nothing to be blended therefore ignore

        Push    "outptr, R1-R3, R6, LR"

        LDR     R1, blend_fgvalue                       ; get the foreground painting colour
        LDR     R2, blend_fgalpha                       ;   and the foreground alpha
        LDR     R6, linelen                             ;   and the scaling information
        LDR     R9, this_ymagcnt

        MOV     outdata, outdata, LSR # 8               ; amount of foreground to blend
        ; outdata = 0-&10 (clear-solid)
        MUL     outdata, R2, outdata                    ; scale by foreground alpha
        ; outdata = 0-&1000 (clear-solid)
        MOVS    outdata, outdata, LSR #8                ; scale back to 0-&10
        ADC     outdata, outdata, #0                    ;   and round
        RSB     LR, outdata, # 16                       ;   and the amount of background
01
        LDR     pchar, [ outptr ]                       ; and pick up the current background pixel data
      [ "$routine"="S"
        MOVS    R2, pchar, LSR #24
      |
        MVNS    R2, pchar, LSR #24
      ]
        BLNE    blend_putdata$routine._32bpp_nonopaque
        Blend   &000000FF, pchar, LR, R1, outdata       ;   blend them together
        Blend   &0000FF00, pchar, LR, R1, outdata
        Blend   &00FF0000, pchar, LR, R1, outdata
        STR     pchar, [ outptr ], -R6                  ; write the new pixel value out

        SUBS    R9, R9, #1
        BNE     %BT01

        Pull    "outptr, R1-R3, R6, LR"
        B       blend_nodata


blend_putdata$routine._4444

        ANDS    outdata, outdata, outmask               ; ensure only relevant bits are set
        BEQ     blend_nodata

        Push    "R1-R3, LR"

        LDR     R1, blend_fgvalue                       ; get the foreground painting colour
        LDR     R2, blend_fgalpha                       ; and the foreground alpha

        MUL     outdata, R2, outdata                    ; scale by foreground alpha

        AND     R9, outdata, #&1FC0
        ; R9 = 0-&1000 (clear-solid)
        MOVS    R9, R9, LSR #8                          ; scale back to 0-&10
        ADC     R9, R9, #0                              ;   and round

        RSB     LR, R9, # 16                            ;   and the amount of background

        LDR     pchar, [ outptr ]                       ; and pick up the current background pixel data
      [ "$routine" = "S"
        MOV     R2, pchar, LSR #12
      |
        MVN     R2, pchar, LSR #12
      ]
        ANDS    R2, R2, #15
        BLNE    blend_putdataSA_4444_nonopaque
        CMP     R9, #0
      [ "$routine" = "S"
        ORR     pchar, pchar, #&F000
        SUB     pchar, pchar, R2, LSL #12  ; Place Ac in pchar
      |
        BIC     pchar, pchar, #&F000
        ORR     pchar, pchar, R2, LSL #12  ; Place Ac in pchar
      ]
        BEQ     %FT10
        Blend   &000F, pchar, LR, R1, R9
        Blend   &00F0, pchar, LR, R1, R9
        Blend   &0F00, pchar, LR, R1, R9

10
        MOVS    R9, outdata, LSR #24                    ; 0-&10 amount of foreground to blend
        ADC     R9, R9, #0                              ;   and round

        RSB     LR, R9, # 16                            ;   and the amount of background

      [ "$routine" = "S"
        MOVS    R2, pchar, LSR #28
      |
        MVNS    R2, pchar, LSR #28
      ]
        BLNE    blend_putdataSA_4444_nonopaque
        CMP     R9, #0
      [ "$routine" = "S"
        ORR     pchar, pchar, #&F0000000
        SUB     pchar, pchar, R2, LSL #28  ; Place Ac in pchar
      |
        BIC     pchar, pchar, #&F0000000
        ORR     pchar, pchar, R2, LSL #28  ; Place Ac in pchar
      ]        
        BEQ     %FT10
        Blend   &000F0000, pchar, LR, R1, R9
        Blend   &00F00000, pchar, LR, R1, R9
        Blend   &0F000000, pchar, LR, R1, R9
10
        STR     pchar, [ outptr ], #4                   ; write the new pixel value out

        MOV     outdata, #&80000000                     ; set marker bit ready for next set of pixels
        MOV     outmask, #0

        Pull    "R1-R3, PC"

; In R9 = anti-alias level 0-16 (clear-solid)
;    R2 = bg supremacy (0-15) (solid-clear)
;    blend_putdata's R1-R3,LR stacked
; Out: R9 and LR updated to reflect correct fg/bg weighting
;      R2 is composite alpha, 0-15
;      R3,outmask corrupted

 [ "$routine" = "A" ; This routine is the same both times, only generate it once
; Terminology: R,G,B,A components
;              suffix t denotes top (ie text)
;                     b denotes bottom (ie screen background)
;                     c denotes composite (ie blended)
blend_putdataSA_4444_nonopaque
;        Can corrupt R2-R3 freely
; First calculate composite alpha level. FG alpha (At) is in range 0-16,
; BG alpha (Ab) is in range 15-0.
; First Ac = 1 - (1 - At) * (1 - Ab)
        CMP     R2, #8
        ADDGT   R2, R2, #1      ; R2 = 1-Ab scaled 0-&10
        RSB     outmask, R9, #16; outmask = 1-At scaled 0-&10
        MUL     R3, R2, outmask ; R3 = (1-At)*(1-Ab) - 0-&100
        RSBS    R3, R3, #256    ; R3 = Ac (0=clear - &100=solid)
        BEQ     blend4444_nodata

; Note Ac must >= At

; s := At / Ac
        MOV     R2, R9, LSL #12         ; R2 = At scaled 0-&10000
        DivRem  R9, R2, R3, outmask, norem ; R9 = At/Ac = s scaled 0-&100
        MOVS    R9, R9, LSR #4          ; s scaled 0-&10
        ADC     R9, R9, #0              ; round
        MOVS    R2, R3, LSR #4          ; R2 = Ac scaled 0-&10
        ADC     R2, R2, #0              ; round
        CMP     R2, #8
        SUBGE   R2, R2, #1              ; R3 = Ac scaled 0-&F
        MOV     R3, LR
        RSB     LR, R9, #16             ; t scaled 0-&10
        MOV     PC, R3

blend4444_nodata
        ; Note LR left invalid!
        CMP     R2, #8
        MOV     R9, #0
        SUBGT   R2, R2, #1
        MOV     PC, LR
 ]

blend_putdata$routine.M_4444

        ANDS    outdata, outdata, outmask
        BEQ     blend_nodata                            ; nothing to be blended therefore ignore

        Push    "outptr, R1-R4, R6, LR"

        LDR     R1, blend_fgvalue                       ; get the foreground painting colour
        LDR     R2, blend_fgalpha                       ;   and the foreground alpha
        LDR     R6, linelen                             ;   and the scaling information
        LDR     R4, this_ymagcnt

        MUL     outdata, R2, outdata                    ; scale by foreground alpha
01
        AND     R9, outdata, #&1FC0
        ; R9 = 0-&10 (clear-solid)
        MOVS    R9, R9, LSR #8                          ; scale back to 0-&10
        ADC     R9, R9, #0                              ;   and round

        RSB     LR, R9, # 16                            ;   and the amount of background

        LDR     pchar, [ outptr ]                       ; and pick up the current background pixel data
      [ "$routine"="S"
        MOV     R2, pchar, LSR #12
      |
        MVN     R2, pchar, LSR #12
      ]
        ANDS    R2, R2, #15
        BLNE    blend_putdataSA_4444_nonopaque
        CMP     R9, #0
      [ "$routine" = "S"
        ORR     pchar, pchar, #&F000
        SUB     pchar, pchar, R2, LSL #12  ; Place Ac in pchar
      |
        BIC     pchar, pchar, #&F000
        ORR     pchar, pchar, R2, LSL #12  ; Place Ac in pchar
      ]
        BEQ     %FT10
        Blend   &000F, pchar, LR, R1, R9
        Blend   &00F0, pchar, LR, R1, R9
        Blend   &0F00, pchar, LR, R1, R9

10
        MOVS    R9, outdata, LSR #24                    ; 0-&10 amount of foreground to blend
        ADC     R9, R9, #0                              ;   and round

        RSB     LR, R9, # 16                            ;   and the amount of background

      [ "$routine" = "S"
        MOVS    R2, pchar, LSR #28
      |
        MVNS    R2, pchar, LSR #28
      ]
        BLNE    blend_putdataSA_4444_nonopaque
        CMP     R9, #0
      [ "$routine" = "S"
        ORR     pchar, pchar, #&F0000000
        SUB     pchar, pchar, R2, LSL #28  ; Place Ac in pchar
      |
        BIC     pchar, pchar, #&F0000000
        ORR     pchar, pchar, R2, LSL #28  ; Place Ac in pchar
      ]        
        BEQ     %FT10
        Blend   &000F0000, pchar, LR, R1, R9
        Blend   &00F00000, pchar, LR, R1, R9
        Blend   &0F000000, pchar, LR, R1, R9
10
        STR     pchar, [ outptr ], -R6                  ; write the new pixel value out

        SUBS    R4, R4, #1
        BNE     %BT01

        Pull    "outptr, R1-R4, R6, LR"
        B       blend_nodata

        END
