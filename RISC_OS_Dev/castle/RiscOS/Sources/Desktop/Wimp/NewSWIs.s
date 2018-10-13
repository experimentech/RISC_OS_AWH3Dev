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
; > source.NewSWIs

SWIWimp_TextOp
        MyEntry "TextOp"

        AND     userblk,R0,#255
        CMP     userblk,#4
        SETV    HI
        ADRVSL  R0,ErrorBlock_WimpBadReasonCode
        BVS     ExitWimp
        [ AllowMatrix
        TST     R0,#&20000000
        MOVNE   R14,R6
        MOVEQ   R14,#0
        ]
        CMP     userblk,#1
        [ AllowMatrix
        STRHS   R14,validationstring
        ]
        ADR     R14, %FT90
        BLO     textop_setcolours
        BEQ     textop_gettextwidth
        CMP     userblk,#3
        BLO     textop_painttext
        BEQ     textop_getsplitpoint
        BHI     textop_truncate
90
        B       ExitWimp

textop_setcolours
        Push    lr
        [ outlinefont
        LDR     R3,systemfont
        TEQ     R3,#0
        STRNE   R1,last_fg_gcol
        STRNE   R2,last_bg_gcol
        Pull    PC,NE
        ]
        MOV     R0,R2
        MOV     R3,#128                 ; bg
        MOV     R4,#0
        SWI     XColourTrans_SetGCOL
        MOVVC   R0,R1
        MOVVC   R3,#0
        SWIVC   XColourTrans_SetGCOL

        Pull    PC

textop_painttext
        Push    "lr"

        TST     R0,#&20000000
        LDRNE   R3,redrawhandle
        Abs     R3,R3,NE
        LDRNE   R14,[R3,#w_wax0]
        ADDNE   R4,R4,R14
        LDRNE   R14,[R3,#w_way1]
        ADDNE   R5,R5,R14

        [ outlinefont
        LDR     R3,systemfont
        TEQ     R3,#0
        BEQ     systemfont_paint

        MOV     R2,R1
        MOV     R1,#is_deleted
        MOV     R9,#bignum
      [ CnP
        MOV     R7, #nullptr
      ]
        BL      pushfontstring

        LDR     R9,last_fg_gcol
        CMP     R9,#-1
        MOVNE   R9,R9, LSR #8
        ORRNE   R9,R9,#&0E000000
        Push    "R9",NE
        LDRNE   R9,last_bg_gcol
        MOVNE   R9,R9, LSR #8
        MOVNE   R9,R9, LSL #8
        ORRNE   R9,R9,#19               ; set font colours
        Push    "R9",NE
        ADDNE   R7,R7,#8
        SUBNE   R1,R1,#8
        MOVNE   R9,#-1
        STRNE   R9,last_fg_gcol

        TST     R0,#&40000000
        LDRNE   R14,systemfonty1
        SUBNE   R14,R14,#28             ; system font was 28 OS units above baseline
        SUBNE   R5,R5,R14 ,LSR #1

        TST     R0,#&10000000           ; vertically central
        LDRNE   R14,systemfonty1
        SUBNE   R5,R5,R14 ,LSR #1

;        LDRNE   R14,systemfonty0
;        SUBNE   R5,R5,R14 ,LSR #1
;        SUBNE   R5,R5,R14               ; p'=p-(y1-3y2)/2


test_rightjustified
        TST     R0,#&80000000
        BEQ     textop_paintfancy
; right justified
        Push    "R1-R5"
        MOV     R2,#0
        MOV     R3,#bignum
        MOV     R4,#bignum
        SWI     XFont_ScanString
        MOV     R1,R3
        SWI     XFont_ConverttoOS
        MOV     R0,R1
        Pull    "R1-R5"
        SUB     R4,R4,R0                ; R4 was RHS
textop_paintfancy
        MOV     R3,R4
;        LDR     R14,systemfonty0        ; get baseline same as system font
;        ADD     R14,R14,#4
;        SUB     R4,R5,R14
        MOV     R4,R5
        MOV     R2,#16                  ; use OS units

        LDR     R14,dx_1
        BIC     R3,R3,R14
        LDR     R14,dy_1
        ADD     R4,R4,R14               ; round up
        BIC     R4,R4,R14

        SWI     XFont_Paint

        ADD     sp,sp,R7                ; balance stack from pushfontstring
        Pull    "PC"

systemfont_paint

        ]

        TST     R0,#&10000000           ; vertically central
        SUBNE   R5,R5,#16               ; system font is 32 OS units high

        LDR     R14,dx_1
        BIC     R4,R4,R14
        LDR     R14,dy_1
        SUB     R5,R5,R14               ; round down as plotting from top left
        BIC     R5,R5,R14

        TST     R0,#&80000000           ; right justified ?
        BEQ     paint_systemfont
        MOV     R0,#0
        MOV     R7,R1
systemfontlength
        LDRB    R6,[R7],#1
        CMP     R6,#31
        ADDHI   R0,R0,#1
        BHI     systemfontlength
        MOV     R0,R0,LSL #4            ; 16 OS units per char
        SUB     R4,R4,R0
paint_systemfont
        Push    "R1"
        MOV     R1,R4
        ADD     R2,R5,#28               ; top left vs btm left
        MOV     R0,#4                   ; move abbsolute
        SWI     XOS_Plot
        Pull    "R0"
        SWI     XOS_Write0
        Pull    "PC"


textop_gettextwidth
        ; RISC OS 4.32 uses flag bit 31 to indicate that bounding box not width is required
        Push    "lr"

        MOV     R9,#bignum
        CMP     R2,#0
        MOVGT   R9,R2

        [ outlinefont
        LDR     R3,systemfont
        TEQ     R3,#0
        BEQ     textop_sysfontwidth

        MOV     R2,R1
        MOV     R1,#is_deleted
      [ CnP
        MOV     R7, #nullptr
      ]
        BL      pushfontstring
        [ true
        MOV     R2,#0
        MOV     R3,#bignum
        MOV     R4,#bignum
        SWI     XFont_ScanString
        ADD     sp,sp,R7
        MOV     R1,R3
        |
        SWI     XFont_StringBBox                        ; calls scanstring internally
        SUB     R1,R3,R1
        ADD     sp,sp,R7
        ]
        SWI     XFont_ConverttoOS
        MOV     R0,R1
        Pull    "PC"

textop_sysfontwidth
        ]
        MOV     R0,#0

textop_sysfontwidth_loop

        LDRB    R3,[R1],#1
        CMP     R3,#31
        ADDHI   R0,R0,#1
        CMPHI   R9,R0
        BHI     textop_sysfontwidth_loop
        MOV     R0,R0, LSL #4
        Pull    "PC"


textop_getsplitpoint
        ; In:
        ;  r1 -> string
        ;  r2 = width, OS units
        ;  r3 = split character
        ; Out:
        ;  r0 -> split point
        Push    "lr"

      [ outlinefont
        Push    "r3"
        LDR     r3,systemfont
        TEQ     r3,#0
        BEQ     textop_sysfontsplit

        Push    "r1,r2"
        MOV     r9,#bignum
      [ CnP
        MOV     r7,#-1
      ]
        MOV     r2,r1
        MOV     r1,#is_deleted
        BL      pushfontstring

        ADD     r3,r1,r7                ; point above stacked string
        LDMIB   r3,{r1,r8}              ; retrieve original r2,r3
        MOV     r2,#0
        SWI     XFont_Converttopoints

        MOV     r3,#0
        MOV     r4,#0
        MOV     r5,#0
        MOV     r6,#0
        Push    "r3-r6,r8"

        MOV     r5,sp
        MOV     r4,#0
        MOV     r3,r1
        MOV     r2,#1:SHL:5
        ADD     r1,sp,#20
        SWI     XFont_ScanString
        ADD     sp,sp,#20

        MOV     r2,sp
        MOV     r3,#0
        MOV     r6,#bignum
01      CMP     r2,r1
        BHS     %FT03
02      LDRB    r14,[r2]
        TEQ     r14,#26                 ; font change?
        ADDEQ   r2,r2,#2
        BEQ     %BT01                   ; skip it if so
      [ UTF8
        BL      skipcharR
      |
        ADD     r2,r2,#1
      ]
        CMP     r2,r1
        ADDLS   r3,r3,#1
        BLO     %BT02
03      ; r3 = number of characters to split point
        ADD     sp,sp,r7                ; junk pushed string
        Pull    "r2"                    ; retrieve original r1
        ADD     sp,sp,#8                ; junk original r2,r3
        CMP     r3,#0
        BEQ     %FT12
11
      [ UTF8
        BL      skipcharR
      |
        ADD     r2,r2,#1
      ]
        SUBS    r3,r3,#1
        BNE     %BT11
12      MOV     r0,r2
        Pull    "pc"

textop_sysfontsplit
        Pull    "r3"
      ]
        ; Can't cope properly with Unicode system font until appropriate APIs are designed
        MOV     r2,r2,LSR #4            ; r2 = width converted to 8-pixel-wide characters
        MOV     r0,r1                   ; initialise last-seen split character
        CMP     r2,#0
        BEQ     %FT22
        LDRB    r14,[r1],#1
21      CMP     r14,#31                 ; if we've hit the terminator
        SUBLS   r1,r1,#1                ;   then point r1 at the terminator
        BLS     %FT22                   ;   and break from loop
        LDRB    r14,[r1],#1             ; before looping (or not) to next character,
        CMP     r14,#31                 ;   see if it's going to be
        TEQLS   r14,r14                 ;   a terminator
        TEQNE   r14,r3                  ;   or a split character
        SUBEQ   r0,r1,#1                ;   and update last-seen split character if so
        SUBS    r2,r2,#1
        BNE     %BT21
        SUB     r1,r1,#1
22      CMP     r3,#-1                  ; if no split character
        MOVEQ   r0,r1                   ; then just point after last character
        Pull    "pc"


textop_truncate
        ; In:
        ;  r1 -> string
        ;  r2 -> output buffer
        ;  r3 = buffer size
        ;  r4 = max width, OS units
        ; Out:
        ;  r0 = size of buffer needed
        Push    "r1-r4,lr"
        MOV     r2,#0
        BL      textop_gettextwidth
        LDR     r4,[sp,#3*4]
        CMP     r0,r4
        BLS     %FT50

        LDR     r14,ellipsiswidth
        LDR     r1,[sp,#0*4]
        SUB     r2,r4,r14
        MOV     r3,#-1
        BL      textop_getsplitpoint

        Pull    "r1-r3"
        ADD     sp,sp,#4
        SUB     r4,r0,r1                ; r4 = length to copy from original string
        LDRB    r14,ellipsis+1
        TEQ     r14,#0
        MOVEQ   r5,#1                   ; r5 = length of ellipsis
        MOVNE   r5,#3
        ADD     r0,r4,r5
        ADD     r0,r0,#1

        CMP     r3,#0
        Pull    "pc", EQ
11      LDRB    r14,[r1],#1
        STRB    r14,[r2],#1             ; copy bytes from original string while buffer not full
        SUB     r4,r4,#1
        SUBS    r3,r3,#1
        TEQNE   r4,#0
        BNE     %BT11
        CMP     r3,#0
        Pull    "pc", EQ
        ADRL    r1,ellipsis
12      LDRB    r14,[r1],#1
        STRB    r14,[r2],#1
        SUB     r5,r5,#1
        SUBS    r3,r3,#1
        TEQNE   r5,#0
        BNE     %BT12
        CMP     r3,#0
        MOVNE   r14,#0
        STRNEB  r14,[r2]
        Pull    "pc"

50      ; String already fitted in width specified - copy into buffer
        Pull    "r1-r3"
        ADD     sp,sp,#4
        MOV     r4,#0
51      LDRB    r14,[r1,r4]
        ADD     r4,r4,#1                ; count bytes up to and including terminator
        CMP     r14,#' '
        BHS     %BT51
        ; Now r4 = buffer needed
        MOV     r0,r4
        CMP     r3,r4
        MOVHS   r3,r4
        CMP     r3,#0
        Pull    "pc", EQ
52      LDRB    r14,[r1],#1
        STRB    r14,[r2],#1             ; copy bytes including terminator, up to min (buffer size, string length)
        SUBS    r3,r3,#1
        BNE     %BT52
        Pull    "pc"


measure_ellipsis ; called from FindFont, sets things up for textop_truncate
        Entry   "r0-r5"
      [ UTF8
        BL      read_current_alphabet
        LDREQ   r0,=&A680E2             ; lookup not appropriate for UTF-8 - use &E2 &80 &A6
        BEQ     %FT05

        MOV     r1,#Service_International
        MOV     r2,#Inter_UCSTable
        LDRB    r3,alphabet
        SWI     XOS_ServiceCall
        TEQ     r1,#0                   ; not recognised? (or maybe old International module?)
        LDRNE   r0,=&2E2E2E             ; use "..." if so
        BNE     %FT05

        ADD     r4,r4,#&80*4            ; skip first &80 characters, unlikely to be ellipsis
        MOV     r3,#&80
        LDR     lr,=&2026               ; UCS-4 ellipsis is &2026
01      LDR     r0,[r4],#4
        TEQ     r0,lr
        SUBNES  r3,r3,#1
        BNE     %BT01
        TEQ     r3,#0
        LDREQ   r0,=&2E2E2E             ; use "..." if not in alphabet
        RSBNE   r0,r3,#&100             ; else use appropriate character
      |
        LDR     r0,=&2E2E2E
      ]
05      STR     r0,ellipsis

      [ outlinefont
        LDR     r0,systemfont
        TEQ     r0,#0
        BEQ     %FT50

10      SUB     sp,sp,#16
        MOV     r1,#0
        MOV     r2,#0
        MOV     r3,#0
        MOV     r4,#0
        MOV     r5,#-1
        Push    "r1-r5"
        ADRL    r1,ellipsis
        LDR     r2,=1:SHL:18 :OR: 1:SHL:8 :OR: 1:SHL:5
        MOV     r3,#bignum/16
        MOV     r4,#bignum/16
        MOV     r5,sp
        SWI     XFont_ScanString
        ADD     sp,sp,#20
        Pull    "r1-r2,r5,r14"          ; get bounding box
        CMP     r5,r1
        CMPLE   r14,r2                  ; if bounding box has zero or negative width and height
        TEQLE   r3,#0
        TEQEQ   r4,#0                   ;   and offsets are both zero
        LDREQ   r0,=&2E2E2E             ;   then consider character to be undefined, so use "..."
        LDR     r14,ellipsis
        MOVNE   r0,r14
        TEQ     r0,r14                  ; if we've just changed to "..." then measure "..." instead
        STRNE   r0,ellipsis
        LDRNE   r0,systemfont
        BNE     %BT10

        LDR     r1,dx
        MOV     r2,#0
        SWI     XFont_Converttopoints
        SUB     r1,r1,#1
        ADD     r3,r3,r1
        BIC     r1,r3,r1                ; round up to next whole number of pixels (cos ConverttoOS will round down)
        SWI     XFont_ConverttoOS

        STR     r1,ellipsiswidth
        EXIT
50
      ]
        LDR     r0,ellipsis
        CMP     r0,#&100
        MOVHS   r0,#48
        MOVLO   r0,#16
        STR     r0,ellipsiswidth
        EXIT


SWIWimp_ResizeIcon
        MyEntry "ResizeIcon"

        AcceptLoosePointer_Neg R0,nullptr
        CMP     R0,#nullptr             ; equate to iconbar per PRM
        CMPNE   R0,#nullptr2            ; let through -2 as iconbar, seems natural
        LDREQ   handle,iconbarhandle
        MOVNE   handle,R0
        BL      checkhandle
        BVS     ExitWimp
        LDR     R0,[handle,#w_nicons]
        CMP     R1,R0
        BHI     badiconhandle
        CMP     R1,#0
        BMI     badiconhandle
        LDR     R0,[handle,#w_icons]
        ADD     R0,R0,R1, LSL #i_shift
        STMIA   R0,{R2-R5}
        B       ExitWimp

        [ UseDynamicArea
wimpspritepoolarea
        DCB     "WSpr"
wimpspritepool
        DCB     "WSP",0
        ALIGN
        ]

allocatespritememory
      [ UseDynamicArea
        Push    "R1,R8,LR"

        TEQ     R0,#ModHandReason_Claim
        BNE     %FT10
        ADR     R0,wimpspritepool               ; Look up name for Wimp sprite pool.
        ADR     R2,errorbuffer                  ; Put it in a safe place for now (copied out by OS_DynamicArea).
        MOV     R3,#256
        BL      LookupToken1
        Pull    "R1,R8,PC",VS
        MOV     R8,R2
        MOV     R0,#ModHandReason_Claim         ; Restore corrupted R0.
10
        LDR     R1,wimpspritepoolarea
        BL      Dynamic_Module
        Pull    "R1,R8,PC",VC

        MyXError WimpNoSprites
        Pull    "R1,R8,PC"
      |
	Push	"LR"
	SWI	XOS_Module
	Pull	"PC"
      ]

        MakeErrorBlock WimpNoSprites

badiconhandle
        ADRL    R0,ErrorBlock_WimpBadIconHandle
        SETV
        B       ExitWimp

badextend * ExitWimp

SWIWimp_Extend  ROUT
        MyEntry "Extend"

        CMP     R0,#WimpExtend_MAX
        ADDLO   PC,PC,R0,LSL #2
        B       extend_more
00
        B       badextend
        B       extend_workspace
        B       extend_jumptable
        B       extend_swicallback
        B       extend_spritenamepointers
        B       extend_tilingcallback
        B       extend_parent
        B       extend_frontchild
        B       extend_backchild
        B       extend_siblingabove
        B       extend_siblingbehind
        B       extend_getborderinfo
        B       extend_ncerrorpointersuspend
        B       extend_spritesuffix
        ASSERT . - %BT00 = WimpExtend_MAX*4

extend_more
        SUB     R14,R0,#256
        CMP     R14,#WimpExtend_SpriteSuffix_ROL-256
        BEQ     extend_spritesuffix_rol
        B       badextend

extend_workspace
        MOV     R0,R12
        B       ExitWimp

extend_jumptable
        ADR     R0,extendjumptable
        B       ExitWimp

extend_swicallback
        LDR     R0,wimpswiintercept
        STR     R1,wimpswiintercept
        B       ExitWimp

extend_spritenamepointers
        ADR     R0,spritename
        ADRL    R1,list_at
        STR     R1,[sp]
        B       ExitWimp

extend_tilingcallback
        LDR     R0,plotsprCB
        STR     R1,plotsprCB
        B       ExitWimp

      [ ChildWindows
extend_parent
extend_frontchild
extend_backchild
extend_siblingabove
extend_siblingbehind
        ROUT
        ; In: R0 = 6 => get parent, 7,8 => get top/bottom child, 9,10 => get next/previous sibling
        ;     R1 = window handle, or -1 for top-level
        ; Out: R1 = result handle, or -1 for none
        CMP     R1,#nullptr
        BEQ     %FT05

        MOV     handle,R1
        BL      checkhandle_iconbar
        BVS     ExitWimp

        CMP     R0,#WimpExtend_FrontChild
        LDRLO   handle,[handle,#w_parent]
        BLO     %FT03

        LDREQ   handle,[handle,#w_children + lh_forwards]
        BEQ     %FT02

        CMP     R0,#WimpExtend_SiblingAbove
        LDRLO   handle,[handle,#w_children + lh_backwards]
        BLO     %FT02

        LDR     R14,[handle,#w_flags]
        TST     R14,#ws_open                    ; sibling pointers are garbage if window is not open
        MOVEQ   handle,#nullptr
        BEQ     %FT04

        CMP     R0,#WimpExtend_SiblingAbove
        LDREQ   handle,[handle,#w_active_link + ll_forwards]
        LDRHI   handle,[handle,#w_active_link + ll_backwards]

02      CMP     handle,#nullptr
        LDRNE   R14,[handle,#ll_forwards]       ; if either forward or backward pointer is null, we're at the head entry (not a window)
        CMPNE   R14,#nullptr
        LDRNE   R14,[handle,#ll_backwards]
        CMPNE   R14,#nullptr
        MOVEQ   handle,#nullptr
        SUBNE   handle,handle,#w_active_link

03      CMP     handle,#nullptr
        Rel     handle,handle,NE

04      STR     handle,[sp]
        B       ExitWimp

05      CMP     R0,#WimpExtend_FrontChild
        LDREQ   handle,activewinds + lh_forwards
        BEQ     %BT02

        CMP     R0,#WimpExtend_BackChild
        LDREQ   handle,activewinds + lh_backwards
        BEQ     %BT02

        B       ExitWimp
      |
extend_parent * badextend
extend_frontchild * badextend
extend_backchild * badextend
extend_siblingabove * badextend
extend_siblingbehind * badextend
      ]

      [ NCErrorBox
        ; Handle hiding of pointer for the duration of keyboard-driving of pointer
extend_ncerrorpointersuspend
        MOV     R0, #106
        MOV     R1, #0
        SWI     XOS_Byte        ; turn off pointer
        MOV     R0, #1
        ADRL    R14, ptrsuspendflag
        STR     R0, [R14]
        B       ExitWimp
      |
extend_ncerrorpointersuspend * badextend      
      ]

extend_spritesuffix ROUT
        ; Work out for the client what resolution suffix to append to a sprites file
        ; First available in Wimp 4.85
        ; Older Wimps don't return error, but can be detected because all registers are preserved
        ; On entry:
        ;   r0 = 13 (reason code)
        ;   r1 -> pathname of file without suffix
        ;   r2 -> buffer for result
        ;   r3 = size of buffer (0 to read size required)
        ; On exit:
        ;   r0 corrupted
        ;   r3 = space left in buffer (ie negative of size required if r3=0 on entry)
        ;   other registers preserved
        ;   contents of buffer are only valid if r3>=0
        ;   error "File not found" may be returned
        MOV     R0, R1
loop1   LDRB    LR, [R0], #1
        CMP     LR, #32
        BCS     loop1
        SUB     R0, R0, R1      ; length of original string (incl terminator)
        ADD     R0, R0, #2      ; for the moment, we know the resultant string will be at most 2 bytes longer

        SUBS    R3, R3, R0
        STR     R3, [SP, #2*4]  ; put result in stack frame
        BMI     ExitWimp        ; exit now if buffer not big enough

loop2   LDRB    LR, [R1], #1
        CMP     LR, #32
        STRCSB  LR, [R2], #1    ; copy string into buffer
        BCS     loop2
        MOV     LR, #0
        STRB    LR, [R2, #2]    ; insert terminator after two more characters

        LDRB    R5, romspr_suffix
        LDRB    R6, romspr_suffix+1
        SUB     R5, R5, #'0'
        SUB     R6, R6, #'0'
loop3
      [ SpritesA
        CMP     R5,R6
        LDREQB  R0,alphaspriteflag
        CMPEQ   R0,#255
        MOVEQ   R5,#'A'-'0'     ; Try alpha before square pixels
      ]
loop4   ADD     LR, R5, #'0'
        STRB    LR, [R2]
        ADD     LR, R6, #'0'
        STRB    LR, [R2, #1]
        MOV     R0, #&4C        ; try opening a file on File$Path (matches *SLoad etc)
        LDR     R1, [SP, #1*4]  ; retrieve pointer to start of buffer
        SWI     XOS_Find
        MOVVC   R1, R0
        MOVVC   R0, #0
        SWIVC   XOS_Find
        BVC     ExitWimp        ; buffer contains a valid file, so exit

      [ SpritesA
        CMP     R5,#'A'-'0'
        MOVEQ   R5,R6
        BEQ     loop4           ; Try square pixels if alpha failed
      ]

        TEQ     R6, #3
        MOVEQ   R6, #2
        BEQ     loop3           ; after Sprites23, try Sprites22

        CMP     R5, R6
        MOVLO   R5, R5, LSL #1
        MOVHI   R6, R6, LSL #1
        BNE     loop3           ; after rectangular pixels, try next squarer version

      [ Sprites11
        TEQ     R5, #1
        MOVEQ   R5, #2
        MOVEQ   R6, #2
        BEQ     loop3           ; after Sprites11, try Sprites22
      ]

      [ SpritesA
        LDRB    R0,alphaspriteflag
        CMP     R0,#0
        BEQ     %FT135
        MOV     R14,#'A'
        STRB    R14,[R2]
        MOV     R14,#0
        STRB    R14,[R2,#1]
        MOV     R0, #&4C
        LDR     R1, [SP, #1*4]
        SWI     XOS_Find        ; try just <filename>A before falling back to the original
        MOVVC   R1, R0
        MOVVC   R0, #0
        SWIVC   XOS_Find
        BVC     ExitWimp
135
      ]

        MOV     LR, #0
        STRB    LR, [R2]
        MOV     R0, #&4C
        LDR     R1, [SP, #1*4]
        SWI     XOS_Find        ; finally, try with no suffix
        MOVVC   R1, R0
        MOVVC   R0, #0
        SWIVC   XOS_Find
        B       ExitWimp        ; return any error we got from this last one

extend_spritesuffix_rol ROUT
        ; In:   R1 = buffer containing pathname of file with no suffix
        ; Out:  R0 = buffer passed in
        ;       R1 = 0 (to indicate call supported by Wimp version)
        ; This is effectively the same as Wimp_Extend 13, except the name is
        ; updated in-place, and no error is returned if no suitable file is
        ; found.
        ; To keep things simple, we'll just allocate a temporary buffer from the
        ; RMA and call Wimp_Extend 13.
        MOV     R3, #0
        STR     R3, [SP]
10
        LDRB    R0, [R1, R3]
        ADD     R3, R3, #1
        CMP     R0, #32
        BCS     %BT10
        ADD     R3, R3, #2
        MOV     R0, #ModHandReason_Claim
        BL     XROS_Module
        BVS     %FT90           ; Give up if no memory
        MOV     R0, #WimpExtend_SpriteSuffix
        SWI     XWimp_Extend
        BVS     %FT30
        ; Copy result to original buffer
        MOV     R3, #0
20
        LDRB    R0, [R2, R3]
        STRB    R0, [R1, R3]
        CMP     R0, #32
        ADD     R3, R3, #1
        BCS     %BT20
30
        MOV     R0, #ModHandReason_Free
        BL     XROS_Module
90
        MOV     R0, R1
        CLRV
        B       ExitWimp


extendjumptable
        B       getspriteaddr
      [ CnP
        B       extendjumptable_pushfontstring
      |
        B       pushfontstring
      ]
        B       callaswi
        B       ExitWimp
        B       ExitWimp2
        B       godrawicon
        B       exitcicon
        B       int_setcolour

      [ CnP
extendjumptable_pushfontstring
        MOV     R7, #nullptr
        B       pushfontstring
      ]
                     ^  0, userblk
furnblock_handle     #  4
furnblock_lborder    #  4
furnblock_bborder    #  4
furnblock_rborder    #  4
furnblock_tborder    #  4
furnblock_back       #  4
furnblock_close      #  4
furnblock_titlegap0  #  4
furnblock_title      #  4
furnblock_titlegap1  #  4
furnblock_iconise    #  4
furnblock_togglew    #  4
furnblock_toggleh    #  4
furnblock_vscrgap1   #  4
furnblock_up         #  4
furnblock_vscr       #  4
furnblock_down       #  4
furnblock_vscrgap0   #  4
furnblock_adjusth    #  4
furnblock_adjustw    #  4
furnblock_hscrgap1   #  4
furnblock_right      #  4
furnblock_hscr       #  4
furnblock_left       #  4
furnblock_hscrgap0   #  4

extend_getborderinfo ROUT
        ; In: R1 = pointer to block to fill with furniture dimensions
        ;     [R1,#0] = window handle to use, or 0 for generic values
        CMP     userblk, #ApplicationStart
        MyXError  WimpBadPtrInR1, LO, L
        BVS     ExitWimp                ; check pointer valid in this case

        LDR     handle, furnblock_handle
        TEQ     handle, #0
        BEQ     %FT01

        BL      checkhandle_iconbar
        BVS     ExitWimp
        ADD     R0, handle, #w_ow0
        LDMIA   R0, {cx0, cy0, cx1, cy1} ; cx0-cy1 = visible area
        LDMIA   R0, {x0, y0, x1, y1}     ; x0-y1 = visible area
        BL      calc_w_x0y0x1y1          ; x0-y1 = window outline
        SUB     R0, cx0, x0
        STR     R0, furnblock_lborder
        SUB     R0, cy0, y0
        STR     R0, furnblock_bborder
        SUB     R0, x1, cx1
        STR     R0, furnblock_rborder
        SUB     R0, y1, cy1
        STR     R0, furnblock_tborder
        SUB     x1, x1, x0               ; calc total lengths of sides - top edge
        SUB     y1, y1, y0               ; - right edge
        MOV     x0, x1                   ; - bottom edge
        LDR     R14, [handle, #w_flags]  ; load flags
        LDR     R1, [handle, #w_parent]  ; get parent
        B       %FT02

01      LDR     R0, dx                   ; assume max border widths
        STR     R0, furnblock_lborder
        LDR     R0, hscroll_height1
        STR     R0, furnblock_bborder
        LDR     R0, vscroll_width1
        STR     R0, furnblock_rborder
        LDR     R0, title_height1
        STR     R0, furnblock_tborder
        MOV     x1, #&200                ; assume reasonably large
        MOV     y1, x1
        MOV     x0, x1
        MOV     R14, #wf_iconbits        ; assume all border flags set
        MOV     R1, #-1                  ; assume a top-level window

02
        TST     R14, #wf_icon1           ; back icon?
        LDRNE   R0, back_width
        MOVEQ   R0, #0
        SUB     x1, x1, R0
        STR     R0, furnblock_back

        TST     R14, #wf_icon2           ; close / iconise icons?
        LDRNE   R0, close_width
        MOVEQ   R0, #0
        SUB     x1, x1, R0
        STR     R0, furnblock_close
      [ IconiseButton
        BEQ     %FT06
        MOV     R0, #0
        CMP     R1, #-1
        BNE     %FT06 ; no iconise button on children
        LDRB    R1, iconisebutton
        TEQ     R1, #0
        BEQ     %FT06
        LDR     R0, iconise_width
06
      |
        MOV     R0, #0
      ]
        SUB     x1, x1, R0
        STR     R0, furnblock_iconise

        TST     R14, #wf_icon4           ; toggle-size icon?
        LDRNE   R0, vscroll_width
        MOVEQ   R0, #0
        SUB     x1, x1, R0
        STR     R0, furnblock_togglew
        LDRNE   R0, title_height
        SUB     y1, y1, R0
        STR     R0, furnblock_toggleh

        TST     R14, #wf_icon3           ; title bar?
        MOVEQ   x1, #0
        STR     x1, furnblock_title

        MOV     R0, #0
        STR     R0, furnblock_titlegap0  ; provided to support future expansion
        STR     R0, furnblock_titlegap1  ; eg extra buttons, or a squashable title bar

        MVN     R0, R14
        TST     R0, #wf_icon5 :OR: wf_icon7
        TSTNE   R0, #wf_icon6            ; adjust-size / blank?
        LDREQ   R0, hscroll_height
        MOVNE   R0, #0
        SUB     y1, y1, R0
        STR     R0, furnblock_adjusth
        LDREQ   R0, vscroll_width
        SUB     x0, x0, R0
        STR     R0, furnblock_adjustw

        TST     R14, #wf_icon5           ; if no vscroll, clear the vscroll words
        MOV     R0, #0
        STREQ   R0, furnblock_vscrgap1
        STREQ   R0, furnblock_up
        STREQ   R0, furnblock_vscr
        STREQ   R0, furnblock_down
        STREQ   R0, furnblock_vscrgap0
        BEQ     %FT04

        Push    "R14"
        TEQ     handle, #0
;       MOVEQ   R0, #0                   ; gap0 = 0
        MOVEQ   R14, #0                  ; gap1 = 0
        BEQ     %FT03
      [ ChildWindows
        Push    "x0,y1"                  ; determine vertical gaps
        MOV     R0, #iconposn_vscroll
        BL      calc_w_iconposn2
        SUB     R0, y0, cy0
        SUB     R14, cy1, y1
        Pull    "x0,y1"
      ]
03      STR     R0, furnblock_vscrgap0
        STR     R14, furnblock_vscrgap1
        SUB     y1, y1, R0
        SUBS    y1, y1, R14

;       CMP     y1, #0                   ; see if vertical arrows are squashed
        MOVLE   cy0, #0                  ; arrows given 0 length if scrollbar has -ve length (it can happen!)
        MOVLE   cy1, #0
        LDRGT   cy0, down_height         ; standard lengths
        LDRGT   cy1, up_height
        ADDGT   R14, cy0, cy1
        RSBGTS  R0, y1, R14
        MOVGT   cy0, y1, LSR#1           ; which may be squashed
        SUBGT   cy1, y1, cy0
        SUB     y1, y1, cy0              ; take arrows from the bar length to give the well length
        SUB     y1, y1, cy1
        STR     cy1, furnblock_up
        STR     y1, furnblock_vscr
        STR     cy0, furnblock_down
        Pull    "R14"

04
        TST     R14, #wf_icon7           ; if no hscroll, clear the hscroll words
        MOV     R0, #0
        STREQ   R0, furnblock_hscrgap1
        STREQ   R0, furnblock_right
        STREQ   R0, furnblock_hscr
        STREQ   R0, furnblock_left
        STREQ   R0, furnblock_hscrgap0
        BEQ     ExitWimp                 ; all done

        TEQ     handle, #0
;       MOVEQ   R0, #0                   ; gap0 = 0
        MOVEQ   R14, #0                  ; gap1 = 0
        BEQ     %FT05
      [ ChildWindows
        Push    "x0"                     ; determine horizontal gaps
        MOV     R0, #iconposn_hscroll
        BL      calc_w_iconposn2
        SUB     R0, x0, cx0
        SUB     R14, cx1, x1
        Pull    "x0"
      ]
05      STR     R0, furnblock_hscrgap0
        STR     R14, furnblock_hscrgap1
        SUB     x0, x0, R0
        SUBS    x0, x0, R14

;       CMP     x0, #0                   ; see if horizontal arrows are squashed
        MOVLE   cx0, #0                  ; arrows given 0 length if scrollbar has -ve length (it can happen!)
        MOVLE   cx1, #0
        LDRGT   cx0, left_width          ; standard lengths
        LDRGT   cx1, right_width
        ADDGT   R14, cx0, cx1
        RSBGTS  R0, x0, R14
        MOVGT   cx0, x0, LSR#1           ; which may be squashed
        SUBGT   cx1, x0, cx0
        SUB     x0, x0, cx0              ; take arrows from the bar length to give the well length
        SUB     x0, x0, cx1
        STR     cx1, furnblock_right
        STR     x0, furnblock_hscr
        STR     cx0, furnblock_left
        B       ExitWimp                 ; all done

        END
