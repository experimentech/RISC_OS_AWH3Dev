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
; > Enhanced

;;-----------------------------------------------------------------------------
;; Routines to cope with true colour pixel formats
;;-----------------------------------------------------------------------------



;;-----------------------------------------------------------------------------
;; Convert a physical colour word (8 bit red, green and blue) to a (16 bit)
;; value suitable for the graphics hardware we are driving.  The macro simply
;; takes the top bits of each gun and places them together in the right order
;; to produce the final colour value suitable for hardware.  Additionally,
;; a default alpha value can be merged in so that the colour is suitable for
;; use with framebuffers which have alpha blending enabled.
;;
;;      bits    FEDCBA9876543210
;;      gun     0bbbbbgggggrrrrr
;;
;; in   R2 = physical colour (bbbbbbbbggggggggrrrrrrrrxxxxxxxx)
;; out  R2 = colour number
;;-----------------------------------------------------------------------------
        MACRO
        BestAndWorst16 $format,$red_shift,$red_bits,$green_shift,$green_bits,$blue_shift,$blue_bits,$alpha
worst_colour_$format
        Debug   buildcolours,"worst_colour_$format in:",R2
        MVN     R2,R2                   ; Invert the colour word (gives worst colour)
best_colour_$format
        Debug   buildcolours,"best_colour_$format in:",R2
        Entry   "R3,R4"
        ColourConv R2,R2,R3,R4,LR,$red_shift,$red_bits,$green_shift,$green_bits,$blue_shift,$blue_bits,$alpha
        Debug   buildcolours,"best_colour_$format out:",R2
        EXIT
        MEND


        BestAndWorst16 4444_TBGR,0,4,4,4,8,4
        BestAndWorst16 4444_TRGB,8,4,4,4,0,4
        BestAndWorst16 4444_ABGR,0,4,4,4,8,4,&F000
        BestAndWorst16 4444_ARGB,8,4,4,4,0,4,&F000
        BestAndWorst16 1555_TBGR,0,5,5,5,10,5
        BestAndWorst16 1555_TRGB,10,5,5,5,0,5
        BestAndWorst16 1555_ABGR,0,5,5,5,10,5,&8000
        BestAndWorst16 1555_ARGB,10,5,5,5,0,5,&8000
        BestAndWorst16 565_BGR,0,5,5,6,11,5
        BestAndWorst16 565_RGB,11,5,5,6,0,5



;;-----------------------------------------------------------------------------
;; These routine cope with generating a suitable colour word for a 32 bit
;; device, with or without alpha blending.
;;
;; in   R2 = physical colour
;; out  R2 = colour word to be used
;;-----------------------------------------------------------------------------

worst_colour_8888_TBGR ROUT
        Debug buildcolours,"worst_colour_8888_TBGR in:",R2
        MVN     R2,R2                   ; Invert the colour word (gives worst colour)
best_colour_8888_TBGR ROUT
        Debug buildcolours,"best_colour_8888_TBGR in:",R2
        MOV     R2,R2,LSR #8            ; Convert from &BBGGRRXX to &00BBGGRR
        Debug buildcolours,"best_colour_8888_TBGR returning:",R2
        MOV     PC,LR                   ; Returning having done it


worst_colour_8888_TRGB ROUT
        Debug buildcolours,"worst_colour_8888_TRGB in:",R2
        MVN     R2,R2                   ; Invert the colour word (gives worst colour)
best_colour_8888_TRGB ROUT
        Debug buildcolours,"best_colour_8888_TRGB in:",R2
      [ NoARMv6
        Entry
        MOV     R2,R2,LSR #8            ; &00BBGGRR
        AND     LR,R2,#&0000FF00        ; &0000GG00
        ORR     R2,LR,R2,ROR #16        ; &GGRRGGBB
        BIC     R2,R2,#&FF000000        ; &00RRGGBB
        Debug buildcolours,"best_colour_8888_TRGB returning:",R2
        EXIT                            ; Returning having done it
      |
        REV     R2,R2                   ; Convert from &BBGGRRXX to &XXRRGGBB
        BIC     R2,R2,#&FF000000        ; Discard junk byte
        Debug buildcolours,"best_colour_8888_TRGB returning:",R2
        MOV     PC,LR                   ; Returning having done it
      ]


worst_colour_8888_ABGR ROUT
        Debug buildcolours,"worst_colour_8888_ABGR in:",R2
        MVN     R2,R2                   ; Invert the colour word (gives worst colour)
best_colour_8888_ABGR ROUT
        Debug buildcolours,"best_colour_8888_ABGR in:",R2
        MOV     R2,R2,LSR #8            ; Convert from &BBGGRRXX to &XXBBGGRR
        ORR     R2,R2,#&FF000000        ; Set alpha component
        Debug buildcolours,"best_colour_8888_ABGR returning:",R2
        MOV     PC,LR                   ; Returning having done it


worst_colour_8888_ARGB ROUT
        Debug buildcolours,"worst_colour_8888_ARGB in:",R2
        MVN     R2,R2                   ; Invert the colour word (gives worst colour)
best_colour_8888_ARGB ROUT
        Debug buildcolours,"best_colour_8888_ARGB in:",R2
      [ NoARMv6
        Entry
        MOV     R2,R2,LSR #8            ; &00BBGGRR
        AND     LR,R2,#&0000FF00        ; &0000GG00
        ORR     R2,LR,R2,ROR #16        ; &GGRRGGBB
        ORR     R2,R2,#&FF000000        ; &AARRGGBB
        Debug buildcolours,"best_colour_8888_ARGB returning:",R2
        EXIT                            ; Returning having done it
      |
        REV     R2,R2                   ; Convert from &BBGGRRXX to &XXRRGGBB
        ORR     R2,R2,#&FF000000        ; Set alpha component
        Debug buildcolours,"best_colour_8888_ARGB returning:",R2
        MOV     PC,LR                   ; Returning having done it
      ]


        END
