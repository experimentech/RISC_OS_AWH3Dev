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
; routines in this file are responsible for tiling the backdrops of
; windows.

        [ windowsprite

; this is a 'signed' division macro

        MACRO
$lab    DivRemS $ra,$rb,$rc,$tmp
$lab    CMP     $rb,#0
        BLT     %FT2
        DivRem  $ra,$rb,$rc,$tmp
        B       %FT4
2       RSB     $rb,$rb,#0
        DivRem  $ra,$rb,$rc,$tmp
        RSB     $rb,$rb,#0
        ; modulus should be -ve if divisor is -ve
4
        MEND


plotsprite_tile1        DCB     "tile_1",0,0
plotsprite_tile1_       DCB     "tile_1-",0

        ALIGN

plotspritebackground
        Push    "R0-R5,lr"
; first find sprite tile_1, look in window area, then wimp area
        LDR     R1,plotsprCB
        TEQ     R1,#0
        BEQ     %FT2
        wsaddr  R5,tile_sc_block
        wsaddr  R4,clipx0
        MOV     R14,PC
        MOV     PC,R1
        Pull    "R0-R5,PC"
2
        TEQ     R0,#sc_verylightgrey            ; colour 1
        SWINE   XOS_WriteI+16                   ; just clear the area
        Pull    "R0-R5,PC",NE

        LDR     R1,[handle,#w_areaCBptr]
        CMP     R1,#2
        BLO     %FT3                            ; 0 ==> system, 1 ==> wimp, else user
        MOV     R0,#SpriteReason_SelectSprite
        ORR     R0,R0,#256
        ADR     R2,plotsprite_tile1
        SWI     XOS_SpriteOp
        BVS     %FT3

        ADRL    R14,tile_sc_block               ; need to save global tile info as
                                                ; a local tile will overwrite this
        LDMIA   R14!,{R0,R3-R5}
        Push    "R0,R3-R5"
        LDMIA   R14,{R0,R3-R5}
        Push    "R0,R3-R5"

        STR     R1,thisCBptr
        STR     R2,spritename
        MOV     R0,#0
        STR     R0,lengthflags                  ; spritename is a pointer
        BL      cachespritedata
        MOV     R1,#0
        BLVC    cachespritepixtable

        LDR     R0,pixtable_at
        STR     R0,tile_temptab
        LDR     R0,sprite_log2px
        STR     R0,tile_log2px
        LDR     R0,sprite_log2py
        STR     R0,tile_log2py

        LDRB    R14,sprite_needsfactors
        TEQ     R14,#0
        ADRNE   R14,sprite_factors

        Push    R3

        LDMNEIA R14,{R0-R3}
        MOVEQ   R0,#0
        ADRL    R14,tile_sc_block
        STMIA   R14,{R0-R3}
        Pull    R3

        LDRB    R1,sprite_needsfactors          ; needs preserving
        Push    R1

        B       %FT6
3
        LDR     R2,tiling_sprite
        CMP     R2,#0                   ; disabled/not there
        BEQ     %FT4
        CMP     R2,#-1                  ; needs recache
        LDRNE   R1,baseofsprites
        BNE     %FT5
        BLEQ    findwimptilesprite
        LDRVC   R1,baseofsprites
        BVC     %FT5
4
        SWI     XOS_WriteI+16

        Pull    "R0-R5,PC"              ; can't find it? don't bother

5
        ADRL    R14,tile_sc_block               ; need to save global tile info as
                                                ; a local tile will overwrite this
        LDMIA   R14!,{R0,R3-R5}
        Push    "R0,R3-R5"
        LDMIA   R14,{R0,R3-R5}
        Push    "R0,R3-R5"

        STR     R1,thisCBptr
        STR     R2,spritename
        MOV     R0,#0
        STR     R0,lengthflags                  ; spritename is a pointer

        LDRB    R1,sprite_needsfactors          ; needs preserving
        Push    R1

        LDR     R0,tile_sc_block
        TEQ     R0, #0
        MOVNE   R0, #-1
        STRB    R0,sprite_needsfactors

        LDR     R0,tile_pixtable
        STR     R0,tile_temptab

        LDR     R3,tile_width
        LDR     R4,tile_height
6
        Push    "x0-y1"

        LDR     R0,tile_log2px
        MOV     R3,R3, LSL R0
        LDR     R0,tile_log2py
        MOV     R4,R4, LSL R0
        Push    "R3,R4"                 ; width and height now on stack
        LDR     y1,[handle,#w_way1]
        LDR     x0,[handle,#w_wax0]
        LDR     R0,[handle,#w_scx]
        DivRemS x1,R0,R3,R5             ; need to start 1 sprite left/below origin
        SUB     x0,x0,R0
        LDR     R0,[handle,#w_scy]
        DivRemS x1,R0,R4,R5
        LDR     R4,[sp,#4]
        SUB     y1,y1,R0


7


        ADR     R14,clipx0
        LDMIA   R14,{R0,y0,x1,R14}

        ADD     x1,x1,#1                        ; boundary condition

        SUB     y0,y0,#1                        ; bc
        RSB     y0,R4,y0


        ADD     R14,R14,#1                        ; boundary conditions
8
; get y1 within graphics window bounds
        CMP     y1,R14
        SUBGT   y1,y1,R4
        BGT     %BT8

        SUB     R0,R0,#1                        ; boundary conditions
9
; get x0 within bounds
        CMP     x0,R0
        ADDLT   x0,x0,R3
        BLT     %BT9
        SUB     x0,x0,R3                        ; get it back to left of window



        MOV     R4,y1
10
        MOV     R3,x0
20
        MOV     R5,#8
        BL      tile_putsprite
        LDR     R5,[sp]
        ADD     R3,R3,R5
        CMP     R3,x1
        BLT     %BT20
        LDR     R5,[sp,#4]
        SUB     R4,R4,R5
        CMP     R4,y0
        BGT     %BT10
err
        ADD     SP,SP,#8
err2

        Pull    "x0-y1"

        Pull    R0
        STRB    R0,sprite_needsfactors

        ADRL    R14,tile_log2px                         ; restore global tile info
        Pull    "R0-R3"
        STMIA   R14,{R0-R3}
        SUB     R14,R14,#16
        Pull    "R0-R3"
        STMIA   R14,{R0-R3}

        Pull    "R0-R5,PC"

        LTORG

;; Routine to stash tile_1 from wimp area
;; returns R2-> tile_1 or VS
findwimptilesprite  Entry "R0-R1"
; is tiling disabled by CMOS ?
        MOV     R0,#161
        MOV     R1,#&8c
        SWI     XOS_Byte
        TST     R2,#128
        SETV    NE
        MOVVS   R2,#0
        STRVS   R2,tiling_sprite

        EXIT    VS

        LDR     R14,log2bpp
        MOV     R0,#1
        MOV     R14,R0,LSL R14
        MOV     R0,#0
        CMP     R14,#8
        MOVHI   R0,#"6"
        CMP     R14,#16
        MOVHI   R0,#"2"
        Push    "R0"                            ; now got "2",0 or "6",0 on stack
        ADR     R2,plotsprite_tile1_
        LDMIA   R2,{R0-R1}
        Push    "R0-R1"                         ; now have "tile_1-?#",0 on stack
        CMP     R14,#8
        ADDLS   R0,R14,#"0"
        MOVHI   R0,#"1"
        CMPHI   R14,#16
        MOVHI   R0,#"3"
        STRB    R0,[sp,#7]
        BL      findwimpspritefordepth

; try again.
        ADRVS   R14,plotsprite_tile1
        LDMVSIA   R14,{R0-R1}
        Push    "R0-R2",VS                         ; routine expects 12 bytes
        BLVS    findwimpspritefordepth
        EXIT    VS

        LDR     R1,baseofsprites
        STR     R1,thisCBptr
        STR     R2,spritename
        MOV     R0,#0
        STR     R0,lengthflags
        BL      cachespritedata
        MOV     R1,#0
        BL      cachespritepixtable

        STR     R3,tile_width
        STR     R4,tile_height

        LDRB    R1,sprite_needsfactors
        Push    "R2-R3"

        LDR     R2,tile_pixtable
        BICS    R2,R2,#1                        ; incase cache invalidated before mode change
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module

        TEQ     R1,#0

        ADRNE   R14,sprite_factors

        LDMNEIA R14,{R0-R3}
        MOVEQ   R0,#0
        ADRL    R14,tile_sc_block
        STMIA   R14,{R0-R3}

        LDR     R0,pixtable_at
        STR     R0,tile_pixtable
        MOV     R0,#0
        STR     R0,pixtable_at                  ; mark as used

        LDR     R0,sprite_log2px
        STR     R0,tile_log2px

        LDR     R0,sprite_log2py
        STR     R0,tile_log2py

        Pull    "R2-R3"
        CLRV
        EXIT

findwimpspritefordepth
; Sprite name to find (tile_1 or tile_1-##) is on stack
        Push    "lr"
        LDR     R2,list_at
        CMP     R2,#0
        BNE     %FT05
        MOV     R0,#SpriteReason_SelectSprite+256
      [ SpritePriority
        LDR     R1,baseofhisprites
      |
        LDR     R1,baseofsprites
      ]
        ADD     R2,SP,#4
        SWI     XOS_SpriteOp
        BVC     %FT07
        MOV     R0,#SpriteReason_SelectSprite+256
      [ SpritePriority
        LDR     R1,baseoflosprites
      |
        LDR     R1,baseofromsprites
      ]
        ADD     R2,SP,#4
        SWI     XOS_SpriteOp
        B       %FT07
05
; do it the quick way.
        ADD     R2,SP,#4
        STR     R2,spritename
        BL      getspriteaddr
07
        MOVVS   R2,#0
        STR     R2,tiling_sprite
        Pull    "R14"
        ADD     SP,SP,#12                       ; skip name
        MOV     PC,lr

tile_putsprite
        Push    "R1-R7,LR"
;
        LDRB    R0,sprite_needsfactors
        TEQ     R0,#0                   ; do I need to translate
;
        MOVNE   R0,#SpriteReason_PutSpriteScaled
        ADRNEL  R6,tile_sc_block
        MOVEQ   R0,#SpriteReason_PutSpriteUserCoords

        LDRNE   R7,tile_temptab          ; -> translation table
        TSTNE   R7,#1
        BLNE    get_new_pixtable
;
        LDR     R1,thisCBptr
        LDR     R2,spritename
        ORR     R0,R0,#&200

        SWI     XOS_SpriteOp
        SWIVS   XOS_WriteI+16

        Pull    "R1-R7,PC"

get_new_pixtable Entry  "R0-R6"

        BIC     R7,R7,#1                ; now an address again

        MOV     R0,#0
        STR     R0,lengthflags
        BL      cachespritedata
        MOV     R1,#0
        BL      cachespritepixtable
        LDR     R0,tile_pixtable
        TEQ     R0,R7
        BNE     %FT05

        MOVS    R2,R7
        MOVNE   R0,#ModHandReason_Free
        BLNE    XROS_Module

        LDR     R7,pixtable_at
        MOV     R6,#0
        STR     R6,pixtable_at
        STR     R7,tile_pixtable
        STR     R7,tile_temptab

        EXIT

05
        ; if tile_temptab and tile_pixtable were different then we must have been
        ; tiling a window with a custom tile. Can't free it either. However, the
        ; generic table is probably stuffed as well.

        LDR     R7,tile_pixtable
        ORR     R7,R7,#1
        STR     R7,tile_pixtable

        LDR     R7,pixtable_at
        STR     R7,tile_temptab
        EXIT

        LTORG

        ]

        END
