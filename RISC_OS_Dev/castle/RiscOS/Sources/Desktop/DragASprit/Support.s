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
; DragASprite support module

                GBLL    AtPointerFlag
AtPointerFlag   SETL    {TRUE}


                ^ 0,r12
wsp             #       4       ; workspace pointer
fgsa            #       4       ; foreground sprite area
bg0sa           #       4       ; background 0 sprite area
bg1sa           #       4       ; background 1 sprite area
bl_offset_x     #       4       ; offset from drag box origin to sprite origin
bl_offset_y     #       4       ; offset from drag box origin to sprite origin
x_size          #       4       ; size in OS units of sprite
y_size          #       4       ; size in OS units of sprite
 [ AtPointerFlag
ptrbuffer       #       20      ; Wimp_GetPointerInfo buffer
 ]
fgtranstable    #       4       ; Translation table for ABGR sprite
FirstMoveIsPlot #       1
Translucency    #       1       ; Translucency value/enabled flag
                                ; 0 = disabled
                                ; 1 = no translucency (ABGR sprite)
                                ; 2+ = real translucency value
TranslucencyOK  #       1       ; Does SpriteExtend support translucency?
                                ; 255 = yes, 0 = no, 128 = dunno
AlphaOK         #       1       ; Does the kernel understand alpha sprites?
wss     *       :INDEX:@

        MACRO
$Label  SortRegs $rl, $rh
$Label  CMP     $rl, $rh
        Swap    $rl, $rh, GT
        MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module header
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Module_BaseAddr
MySWIBase       *       Module_SWISystemBase + DragASpriteSWI * Module_SWIChunkSize

        DCD     0       ; Start
        DCD     Support_Init            -Module_BaseAddr
        DCD     Support_Die             -Module_BaseAddr
        DCD     0       ; Service call
        DCD     Support_TitleString     -Module_BaseAddr
        DCD     Support_HelpString      -Module_BaseAddr
        DCD     0       ; Commands
        DCD     MySWIBase
        DCD     Support_Swi             -Module_BaseAddr
        DCD     Support_SwiList         -Module_BaseAddr
        DCD     0       ; SWI decode code
      [ :LNOT: No32bitCode
        DCD     0       ; Messages file
        DCD     Support_ModuleFlags     -Module_BaseAddr
      ]


Support_TitleString     DCB     "DragASprite", 0

Support_HelpString
        DCB     "Drag A Sprite",9, "$Module_MajorVersion ($Module_Date)", 0

Support_SwiList
        DCB     "DragASprite", 0
        DCB     "Start", 0
        DCB     "Stop", 0
        DCB     0

        ; Translucency should be supported in version 1.55+ of ROOL's version
SpriteExtendCheck
        DCB     "RMEnsure SpriteExtend 1.55", 0
        ALIGN

      [ :LNOT: No32bitCode
Support_ModuleFlags
        DCD     ModuleFlag_32bit
      ]

Support_Init ROUT
        Push    "lr"
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #wss
        SWI     XOS_Module
        STRVC   r2, [r12]
        STRVC   r12, [r2, #:INDEX:wsp]
        MOV     r12, r2
        ChkKernelVersion
        MOV     r2, #0
        STR     r2, fgsa
        STR     r2, bg0sa
        STR     r2, bg1sa
        STR     r2, fgtranstable
        MOV     r2, #128
        STRB    r2, TranslucencyOK
        ; Check kernel support for alpha sprites/modes
        MOV     r3, #0
        LDR     r0, =&78000001+(SpriteType_New32bpp<<20)+ModeFlag_DataFormatSub_Alpha
        MOV     r1, #VduExt_ModeFlags
        SWI     XOS_ReadModeVariable
        BVS     %FT10
        BCS     %FT10
        TEQ     r2, #ModeFlag_DataFormatSub_Alpha
        MOVEQ   r3, #1
10
        STRB    r3, AlphaOK
        Pull    "pc"

Support_Die Entry
        LDR     r12, [r12]
        BL      Done
        EXIT

Support_Swi ROUT
        LDR     r12, [r12]
        CMP     r11, #(SwiIssue_End - SwiIssue_Start)/4
        ADDLO   pc, pc, r11, ASL #2
        B       SwiOutOfRange
SwiIssue_Start
        B       StartUp
        B       Done
SwiIssue_End
SwiOutOfRange
        ADR     r0, ErrorBlock_NoSuchSWI
        ADR     r1, Support_TitleString
        B       LookupError

        MakeInternatErrorBlock NoSuchSWI,,BadSWI

; **********************************************************************
;
; Message token lookup function.  We only use Global messages.
;

LookupError
        Push    "r1-r7,lr"
        MOV     r4, r1
        MOV     r1, #0
        MOV     r2, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "r1-r7,pc"

        END
