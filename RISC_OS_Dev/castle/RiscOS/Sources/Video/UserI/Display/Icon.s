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
; > Sources.Icon

icon_block
        DCD     &00003002
        DCB     "display",0,0,0,0,0
        ALIGN

ic_display_colours      *       4
ic_display_colbutton    *       3
ic_display_resolution   *       5
ic_display_resbutton    *       7
ic_display_cancel       *       6
ic_display_ok           *       1
 [ SelectFrameRate
ic_display_rate         *       9
ic_display_ratebutton   *       10
 ]

ic_mode_mode            *       0
ic_mode_ok              *       1

ic_info_version         *       3

;---------------------------------------------------------------------------
; Icon_Init
;
;       Out:    r0 corrupted
;
;       Make icon bar icon.
;
Icon_Init
        Entry   "r1-r6"

        MOV     r0, #SpriteReason_ReadSpriteSize
        ADR     r2, icon_block+4        ; r2 -> sprite name
        SWI     XWimp_SpriteOp          ; r3,r4 = size in pixels
        EXIT    VS

        MOV     r0, r6                  ; r0 = creation mode of sprite

        MOV     r1, #VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOV     r5, r3, LSL r2          ; x1 = width in OS units
        MOV     r3, #0                  ; x0 = 0

        MOV     r1, #VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        MOV     r6, r4, LSL r2          ; y1 = height in OS units
        MOV     r4, #0                  ; y0 = 0

        ADR     r1, user_data           ; Build Wimp_CreateIcon block.
        MOV     r0, #-8                 ; Place on right, scan from right.
        STMIA   r1!, {r0,r3-r6}         ; Store x0,y0,x1,y1.
        ADR     lr, icon_block
        LDMIA   lr, {r3-r6}             ; Get icon flags and data.
        STMIA   r1, {r3-r6}             ; Put in block.

        LDR     r0, =WimpPriority_ModeChooser   ; Create icon with priority.
        ADR     r1, user_data
        SWI     XWimp_CreateIcon
        STRVC   r0, icon_handle

        EXIT


;---------------------------------------------------------------------------
; Icon_SetState
;
;       In:     r0 = window handle
;               r1 = icon
;               r2 = EOR word
;               r3 = clear word
;
;       Set icon state given parameters.
;
Icon_SetState
        Entry   "r0-r3"

        MOV     r1, sp
        SWI     XWimp_SetIconState
        STRVS   r0, [sp]

        EXIT


;---------------------------------------------------------------------------
; Icon_Refresh
;
;       Get the WIMP to update the window icons.
;
Icon_Refresh
        Entry   "r0-r3"

        Debug   icon,"Icon_Refresh"

        LDR     r0, display_handle
        MOV     r1, #ic_display_colours
        MOV     r2, #0
        MOV     r3, #0
        BL      Icon_SetState
        MOVVC   r1, #ic_display_resolution
        BLVC    Icon_SetState
 [ SelectFrameRate
        MOVVC   r1, #ic_display_rate
        BLVC    Icon_SetState
 ]

        EXIT


        END
