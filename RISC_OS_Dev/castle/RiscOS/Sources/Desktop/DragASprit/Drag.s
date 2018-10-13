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
; b/g(0) is the b/g behind the plotted sprite

; unplot:
;       Plot the b/g sprite at the relevant location
UnPlot  Entry   "r0-r11"
        BL      DoBusinessToDest

 [ debugdrag
        BVS     %FT01
        DLINE   "UnPlot"
01
 ]

        MOVVC   r3, r0
        MOVVC   r4, r1
        LDRVC   r0, =SpriteReason_PutSpriteUserCoords + &100
        LDRVC   r1, bg0sa
        ADRVC   r2, bg_name
        MOVVC   r5, #0
        SWIVC   XOS_SpriteOp
        CLRV
        EXIT

; plot:
;       Grab the b/g sprite at the required location
;       Plot the f/g sprite at the required location
Plot    Entry   "r0-r11"

        MOV     lr, #0
        STRB    lr, FirstMoveIsPlot

        BL      DoBusinessToDest

 [ debugdrag
        BVS     %FT01
        DREG    r0, "Plot at ",cc
        DREG    r1, ","
01
 ]

        ; Grab bg0 from the screen
        MOVVC   r4, r0
        MOVVC   r5, r1
        SUBVC   r6, r2, #1
        SUBVC   r7, r3, #1
        BLVC    Getbg0
        BVS     %FT10

        ; Plot fg
        LDR     r1, fgsa
        ADRL    r2, fg_name
        MOV     r3, r4
        MOV     r4, r5
        MOV     r5, #8          ; Mask is used for transparency
        BL      TranslucentPlot

10
        CLRV
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; TranslucentPlot:
;
; In    r1-r5 set up for PlotSpriteUserCoords
; Out   R0 corrupt or error
;
TranslucentPlot ROUT
        Entry   "r5-r7"
        LDRB    r7, Translucency
        CMP     r7, #1
        BLT     %FT05
        ORRGT   r5, r5, r7, LSL #8
        ORREQ   r5, r5, #16+32
        MOV     r6, #0
        LDR     r7, fgtranstable
        LDR     r0, =SpriteReason_PutSpriteScaled + &100
        SWI     XOS_SpriteOp
        EXIT    VC
        ; Translucent plot failed - fall back to regular plotting for this drag
        ; This will almost certainly fail if this is an ABGR sprite, but should
        ; succeed for standard translucent plots
        STRB    r6, Translucency ; Disable translucency
        MOV     r6, #128
        STRB    r6, TranslucencyOK ; Reset SpriteExtend state (user may have downgraded?)
        AND     r5, r5, #&F
05
        LDR     r0, =SpriteReason_PutSpriteUserCoords + &100
        SWI     XOS_SpriteOp
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Move:
;
; In    r0-r3 = dst
;       r4-r7 = src
;
;       Grab bg1 (by GWindow escape) at dst
;       Plot bg0 to bg1 (bg0 at src, bg1 at dst)
;       Plot fg to bg0 (fg at dst, gb0 at src)
;       Plot fg to screen (fg at dst)
;       Plot bg0 to screen (bg0 at src)
;       Swap bg0 and bg1
;
Move
        Entry   "r0-r8" , 8*4

        ; If first action is move then it must be plot instead
        LDRB    lr, FirstMoveIsPlot
        TEQ     lr, #0
        PullEnv NE
        BNE     Plot

        BL      DoBusinessToDest
        BLVC    DoBusinessToSource
        STMIA   sp, {r0-r7}

        CMP     r0, r4
        CMPEQ   r1, r5
        CMPEQ   r2, r6
        CMPEQ   r3, r7
        EXIT    EQ

 [ debugdrag
        DLINE   "Move  ",cc
        LDR     r4, bl_offset_x
        DREG    r4, "x_o=",cc
        LDR     r4, bl_offset_y
        DREG    r4, " y_o="
 ]

        ; Grab bg1 (by GWindow escape) at dst
        MOV     r4, r0
        MOV     r5, r1
        MOV     r6, r2
        MOV     r7, r3
        BL      Getbg1

        ; Plot bg0 to bg1 (bg0 at src, bg1 at dst)

        ; Switch to bg1
        LDRVC   r1, bg1sa
        BLVC    SwitchOutputToSprite
        BVS     %FT95

        Push    "r0-r3"                 ; Details to restore back to screen

        ; Plot bg0
        LDR     r0, =SpriteReason_PutSpriteUserCoords + &100
        LDR     r1, bg0sa
        ADRL    r2, bg_name
        ADD     r14, sp, #4*4 + 4*4
        LDMIA   r14, {r3,r4}
        ADD     r14, sp, #4*4 + 0*4
        LDMIA   r14, {r5,r6}
        SUB     r3, r3, r5
        SUB     r4, r4, r6
        MOV     r5, #0
        SWI     XOS_SpriteOp
        BVS     %FT90

        ; Plot fg to bg0 (fg at dst, gb0 at src)

        ; Switch to bg0
        LDR     r1, bg0sa
        BL      SwitchOutputToSprite
        BVS     %FT90
        ; Don't save details as they refer to restoring back to bg1!

        ; Plot fg
        LDR     r1, fgsa
        ADRL    r2, fg_name
        ADD     r14, sp, #4*4 + 0*4
        LDMIA   r14, {r3,r4}
        ADD     r14, sp, #4*4 + 4*4
        LDMIA   r14, {r5,r6}
        SUB     r3, r3, r5
        SUB     r4, r4, r6
        MOV     r5, #8
        BL      TranslucentPlot
        BVS     %FT90

        ; Plot fg to screen (fg at dst)

        ; Switch back to the screen
        Pull    "r0-r3"
        SWI     XOS_SpriteOp
        BVS     %FT95

        ; Plot fg
        ; We clip around the old position to avoid flicker caused by overdraw
        BL      GetGWindow
        Push    "r0-r3"
        ; Check if src and dest overlap
        ADD     r0, sp, #16
        LDMIA   r0, {r0-r7}
        CMP     r4, r2
        CMPLT   r5, r3
        CMPLT   r0, r6
        CMPLT   r1, r7
        BGE     %FT15                   ; No overlap, skip clipping
        ; Draw top/bottom portion
        MOV     r6, r5                  ; r6 = bg0 bottom
                                        ; r7 = bg0 top
        MOV     r8, r3                  ; r8 = fg top
        LDMIA   sp, {r0-r3}             ; get gwindow
        CMP     r8, r7
        BEQ     %FT10
        MOVGT   r1, r7                  ; gwindow bottom = bg0 top
        SUBLT   r3, r6, #1              ; gwindow top = bg0 bottom
        BL      SetGWindow
        LDR     r1, fgsa
        ADRL    r2, fg_name
        ADD     r14, sp, #16
        LDMIA   r14, {r3,r4}
        MOV     r5, #8
        BL      TranslucentPlot
        ; Set alternate vertical clip ready for drawing left/right portion
        LDMIA   sp, {r0-r3}
        CMP     r8, r7
        SUBGT   r3, r7, #1              ; gwindow top = bg0 top
        MOVLT   r1, r6                  ; gwindow bottom = bg0 bottom
10
        ; Draw left/right portion
        LDR     r6, [sp, #16+16+0]      ; r6 = bg0 left
        LDR     r7, [sp, #16+16+8]      ; r7 = bg0 right
        LDR     r8, [sp, #16+8]         ; r8 = fg right
        CMP     r8, r7
        BEQ     %FT20
        MOVGT   r0, r7                  ; gwindow left = bg0 right
        SUBLT   r2, r6, #1              ; gwindow right = bg0 left
        BL      SetGWindow
15
        LDR     r1, fgsa
        ADRL    r2, fg_name
        ADD     r14, sp, #16
        LDMIA   r14, {r3,r4}
        MOV     r5, #8
        BL      TranslucentPlot
20
        Pull    "r0-r3"
        BL      SetGWindow

        ; Plot bg0 to screen (bg0 at src)

        ; Plot bg0
        LDR     r0, =SpriteReason_PutSpriteUserCoords + &100
        LDR     r1, bg0sa
        ADRL    r2, bg_name
        ADD     r14, sp, #4*4
        LDMIA   r14, {r3,r4}
        MOV     r5, #0
        SWI     XOS_SpriteOp
        BVS     %FT95

        ; Swap bg0 and bg1

        LDR     r0, bg0sa
        LDR     r1, bg1sa
        STR     r0, bg1sa
        STR     r1, bg0sa

        EXIT                    ; V clear

90
        ; Error switched to a sprite
        Pull    "r0-r3"
        SWI     XOS_SpriteOp
95
        CLRV
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Getbg0
;
; In    r4 = x0         inc
;       r5 = y0         inc
;       r6 = x1         exc
;       r7 = y1         exc
;
; Out   sprite bg gotten
;
Getbg0  Entry   "r0-r7"

 [ debugdrag
        DLINE   "Getbg0"
 ]

        ; Get the screen to bg1
        LDR     r0, =SpriteReason_GetSpriteUserCoords + &100
        LDR     r1, bg1sa
        ADRL    r2, bg_name
        MOV     r3, #0          ; no palette
        [ {FALSE}
; these cause breakage in EX0 EY0 modes
        SUB     r6, r6, #1
        SUB     r7, r7, #1
        ]
        SWI     XOS_SpriteOp

        ; Get the graphics window
        BLVC    GetGWindow
        EXIT    VS
        Push    "r0-r3"         ; current screen GWindow

        ; Switch output to bg0
        LDR     r1, bg0sa
        BL      SwitchOutputToSprite
        BVS     %FT90
        Push    "r0-r3"

        ; Set the gwindow in the switched area, bounded to the switched area

        ; Get the screen gwindow off the stack
        ADD     r14, sp, #4*4
        LDMIA   r14, {r0-r3}

        ; Correct for the redirection to the sprite
        SUB     r0, r0, r4
        SUB     r1, r1, r5
        SUB     r2, r2, r4
        SUB     r3, r3, r5

        ; Bound to the sprite
        CMP     r0, #0
        MOVLT   r0, #0
        CMP     r1, #0
        MOVLT   r1, #0
        SUB     r6, r6, r4
        SUB     r7, r7, r5
        CMP     r2, r6
        MOVGT   r2, r6
        CMP     r3, r7
        MOVGT   r3, r7

        ; Source clip if no intersection
        CMP     r0, r6
        CMPLE   r1, r7
        RSBLES  r14, r2, #0
        RSBLES  r14, r3, #0
        BGT     %FT10

        ; It intersects - set it
        BL      SetGWindow

        ; Plot the grabbed sprite
        LDRVC   r0, =SpriteReason_PutSpriteUserCoords + &100
        LDRVC   r1, bg1sa
        ADRVCL  r2, bg_name
        MOVVC   r3, #0          ; x coord
        MOVVC   r4, #0          ; y coord
        MOVVC   r5, #0          ; plot method (overwrite)
        SWIVC   XOS_SpriteOp

        BVS     %FT80

10
        ; Switch output back to the screen
        Pull    "r0-r3"
        SWI     XOS_SpriteOp

        ; Drop the original graphics window
        ADD     sp, sp, #4*4

        ; All done
        EXIT

80
        ; Error exit with output switched to the sprite
        STR     r0, [sp, #4*4]

        ; Switch output back to the screen
        Pull    "r0-r3"
        SWI     XOS_SpriteOp
        Pull    "r0-r3"

 [ debugdrag
        DLINE   "Urgk"
 ]
        EXIT

90

 [ debugdrag
        DLINE   "Urgk"
 ]
        ADD     sp, sp, #4*4
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Getbg1
;
; In    r4 = x0         inc
;       r5 = y0         inc
;       r6 = x1         exc
;       r7 = y1         exc
;
; Out   sprite bg gotten
;
Getbg1  Entry   "r0-r7"

 [ debugdrag
        DLINE   "Getbg1 ",cc
 ]

        ; Get the old gwindow
        BL      GetGWindow
        BVS     %FT90
        Push    "r0-r3"         ; The old gwindow

        ; Escape the GWindow to the whole screen
        BL      GetScreenGWindow
        BLVC    SetGWindow

        ; Get the screen to bg1
        LDRVC   r0, =SpriteReason_GetSpriteUserCoords + &100
        LDRVC   r1, bg1sa
        ADRVCL  r2, bg_name
        MOVVC   r3, #0          ; no palette
        SUBVC   r6, r6, #1      ; Translate to inclusive coords
        SUBVC   r7, r7, #1
        SWIVC   XOS_SpriteOp
        BVS     %FT85

        ; Restore the screen gwindow
        Pull    "r0-r3"
        BL      SetGWindow
        BVS     %FT90

 [ debugdrag
        DLINE   "done"
 ]

        ; All done
        EXIT

85
        ; Error exit with screen GWindow set
        STR     r0, [sp, #4*4 + 0*4]
        Pull    "r0-r3"
        BL      SetGWindow
        SETV
        LDR     r0, [sp]

90
        ; Error exit
        STR     r0, [sp, #0*4]
 [ debugdrag
        ADD     r1, r0, #4
        DSTRING r1, "exiting with error:"
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GetGWindow
;
; In    -
;
; Out   r0-r3 are the graphics window
;
GetGWindow      Entry   "r4-r7", 6*4
        ADR     r0, GWindGetBlock
        MOV     r1, sp
        SWI     XOS_ReadVduVariables
        MOVVC   r0, #-1
        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r4, r2
        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r5, r2
        LDMVCIA sp, {r0-r3,r6,r7}

        ; gwindow is ic gwindow left shift by EigFactors, subtract the origin
        RSBVC   r0, r6, r0, ASL r4
        RSBVC   r1, r7, r1, ASL r5
        ADD     r2, r2, #1              ; Convert to external
        RSBVC   r2, r6, r2, ASL r4
        SUB     r2, r2, #1              ; Convert back to internal
        ADD     r3, r3, #1              ; Convert to external
        RSBVC   r3, r7, r3, ASL r5
        SUB     r3, r3, #1              ; Convert back to internal

 [ debuggwindow
        DREG    r0, "Current GWindow returned is ",cc
        DREG    r1, ",",cc
        DREG    r2, ",",cc
        DREG    r3, ","
 ]
        EXIT

GWindGetBlock
        DCD     VduExt_GWLCol
        DCD     VduExt_GWBRow
        DCD     VduExt_GWRCol
        DCD     VduExt_GWTRow
        DCD     VduExt_OrgX
        DCD     VduExt_OrgY
        DCD     -1

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GetScreenGWindow
;
; In    -
;
; Out   r0-r3 are the gwindow to set for the whole screen
;
GetScreenGWindow Entry  "r4",2*4
        ; Get the graphics origin
        ADR     r0, GOrgGetBlock
        MOV     r1, sp
        SWI     XOS_ReadVduVariables

        ; Parameters for this mode
        MOVVC   r0, #-1

        ; Generate the Y upper limit in OS units, inclusive
        MOVVC   r1, #VduExt_YWindLimit
        SWIVC   XOS_ReadModeVariable
        ADDVC   r4, r2, #1
        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r3, r4, ASL r2
        SUBVC   r3, r3, #1

        ; Generate the X upper limit in OS units, inclusive
        MOVVC   r1, #VduExt_XWindLimit
        SWIVC   XOS_ReadModeVariable
        ADDVC   r4, r2, #1
        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r2, r4, ASL r2
        SUBVC   r2, r2, #1

        ; Correct for the graphics origin
        LDMVCIA sp, {r0,r1}
        SUBVC   r2, r2, r0
        SUBVC   r3, r3, r1
        RSBVC   r0, r0, #0
        RSBVC   r1, r1, #0

 [ debuggwindow
        DREG    r0, "Screen GWindow returned is ",cc
        DREG    r1, ",",cc
        DREG    r2, ",",cc
        DREG    r3, ","
 ]

        EXIT

GOrgGetBlock
        DCD     VduExt_OrgX
        DCD     VduExt_OrgY
        DCD     -1

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SetGWindow
;
; In    r0-r3 the GWindow to set
;
; Out   The GWindow set
;
SetGWindow      Entry   "r6-r7"
 [ debuggwindow
        DREG    r0, "Setting GWindow ",cc
        DREG    r1, ",",cc
        DREG    r2, ",",cc
        DREG    r3, ","
 ]
        MOV     r7, #&ff
        MOV     r6, r0
        SWI     XOS_WriteI+24
        ANDVC   r0, r7, r6
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r6, LSR #8
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r1
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r1, LSR #8
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r2
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r2, LSR #8
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r3
        SWIVC   XOS_WriteC
        ANDVC   r0, r7, r3, LSR #8
        SWIVC   XOS_WriteC
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SwitchOutputToSprite
;
; In    r1 -> sprite area to switch output to
;
; Out   r0-r3 Restore output parameters
;
SwitchOutputToSprite Entry
        LDR     r0, =SpriteReason_SwitchOutputToSprite + &100
        ADRL    r2, bg_name
        MOV     r3, #0          ; No save area
        SWI     XOS_SpriteOp
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DoBusinessToDest
;
; In    r0-r3 destination of drag
;
; Out   r0-r3 sorted and rounded to pixels
;
DoBusinessToDest Entry  "r0-r5"

        ; Get the EigFactors
        MOV     r0, #-1
        MOV     r1, #VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOVVC   r4, r2
        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r5, r2

        ; Convert to 2^n-1
        MOV     r3, #1
        MOV     r4, r3, ASL r4
        SUB     r4, r4, #1
        MOV     r5, r3, ASL r5
        SUB     r5, r5, #1

        ; Get the dest and sort it
        LDMIA   sp, {r0-r3}
        SortRegs r0,r2
        SortRegs r1,r3

        ; Adjust to the rectangle we want
        LDR     lr, bl_offset_x
        ADD     r0, r0, lr
        LDR     lr, bl_offset_y
        ADD     r1, r1, lr
        LDR     lr, x_size
        ADD     r2, r0, lr
        LDR     lr, y_size
        ADD     r3, r1, lr

        ; Round bottom left down
        BIC     r0, r0, r4
        BIC     r1, r1, r5

        ; Round top right up
        ADD     r2, r2, r4
        BIC     r2, r2, r4
        ADD     r3, r3, r5
        BIC     r3, r3, r5

        STMIA   sp, {r0-r3}
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DoBusinessToSource
;
; In    r4-r7 source of drag
;
; Out   r4-r7 sorted and rounded to pixels
;
DoBusinessToSource Entry  "r0-r3"
        SortRegs r4,r6
        SortRegs r5,r7

        ; Adjust to the rectangle we want
        LDR     lr, bl_offset_x
        ADD     r4, r4, lr
        LDR     lr, bl_offset_y
        ADD     r5, r5, lr
        LDR     lr, x_size
        ADD     r6, r4, lr
        LDR     lr, y_size
        ADD     r7, r5, lr

        MOV     r0, #-1
        MOV     r1, #VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        MOVVC   r3, r2
        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        STRVS   r0, [sp]
        EXIT    VS

        ; Convert to 2^n-1
        MOV     r1, #1
        MOV     r2, r1, ASL r2
        SUB     r2, r2, #1
        MOV     r3, r1, ASL r3
        SUB     r3, r3, #1

        ; Round bottom left down
        BIC     r4, r4, r2
        BIC     r5, r5, r3

        ; Round top right up
        ADD     r6, r6, r2
        BIC     r6, r6, r2
        ADD     r7, r7, r3
        BIC     r7, r7, r3

        EXIT

        END
