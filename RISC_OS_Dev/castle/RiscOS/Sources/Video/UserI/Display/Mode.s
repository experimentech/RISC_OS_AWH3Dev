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
; > Sources.Mode

;---------------------------------------------------------------------------
; Mode_Init
;
;       Out:    r0 corrupted
;
;       Get the current screen mode and set up indirect window data
;       appropriately.
;
Mode_Init
        Entry   "r1-r6", GVPixelFormat_Size

        Debug   mode,"Mode_Init"

        BL      Mode_GetCurrent
        MOV     r5, sp
        BLVC    Mode_GetInfo
        BLVC    Mode_TestPalette
        BLVC    Mode_SetSelection
        BLVC    Mode_SetWindowIcons
        EXIT    VS

        LDR     r1, menu_handle         ; Reopen any open menus (get ticks right).
        TEQ     r1, #0
        BLNE    Menu_Show
        EXIT


;---------------------------------------------------------------------------
; Mode_GetCurrent
;
;       Out:    r0 corrupted
;               r2 = mode specifier for current mode
;
;       Return the current mode specifier.
;
Mode_GetCurrent
        Entry   "r1"

        Debug   mode,"Mode_GetCurrent"

 [ Medusa
        MOV     r0, #ScreenModeReason_ReturnMode
        SWI     XOS_ScreenMode
        MOV     r2, r1                  ; r2=mode specifier (number or pointer)
 |
        MOV     r0, #135
        SWI     XOS_Byte
 ]

        EXIT


;---------------------------------------------------------------------------
; Mode_PixelFormatFromLog2BPP
;
;       In:     r4 = Log2BPP
;               r5 -> pixel format block
;       Out:    r5 filled in
;
Mode_PixelFormatFromLog2BPP ROUT
        Entry   "r4"
        STR     r4, [r5, #GVPixelFormat_Log2BPP]
        CMP     r4, #3
        MOVEQ   lr, #ModeFlag_FullPalette
        MOVNE   lr, #0
        STR     lr, [r5, #GVPixelFormat_ModeFlags]
        MOV     lr, #1
        MOV     r4, lr, LSL r4          ; log2bpp -> bpp
        RSB     r4, lr, lr, LSL r4      ; bpp -> ncolour
        STR     r4, [r5, #GVPixelFormat_NColour]
        EXIT

;---------------------------------------------------------------------------
; Mode_IsOldPixelFormat
;
;       In:     r1 -> pixel format block
;       Out:    EQ if can be represented as pixel depth
;
Mode_IsOldPixelFormat ROUT
        Entry   "r0,r2-r3"
        ASSERT  GVPixelFormat_NColour = 0
        ASSERT  GVPixelFormat_ModeFlags = 4
        ASSERT  GVPixelFormat_Log2BPP = 8
        LDMIA   r1, {r0,r2-r3} ; Get ncolour, modeflags, log2bpp
        CMP     r3, #5
        EXIT    HI
        CMP     r3, #3
        MOVEQ   lr, #ModeFlag_FullPalette
        MOVNE   lr, #0
        CMP     r2, lr
        EXIT    NE
        MOV     r2, #1
        MOV     r3, r2, LSL r3
        RSB     r3, r2, r2, LSL r3
        CMP     r0, r3
        EXIT

;---------------------------------------------------------------------------
; Mode_GetInfo
;
;       In:     r2 = mode specifier
;               r5 -> pixel format block
;       Out:    r0 corrupted
;               r3 = X resolution
;               r4 = Y resolution
;               r5 filled in
;               r6 = frame rate (or -1 = unknown).
;
;       Get information about given mode.
;
Mode_GetInfo    ROUT
        Entry   "r1,r2"

        Debug   mode,"Mode_GetInfo: mode =",r2

        ASSERT  mode_spec_flags = 0
        ASSERT  mode_spec_xres = mode_spec_flags + 4
        ASSERT  mode_spec_yres = mode_spec_xres + 4
        MOV     r0, r2
        CMP     r0, #256
        BCC     %FT10
        LDR     r4, [r0, #mode_spec_depth]
        BL      Mode_PixelFormatFromLog2BPP
        ; Scan mode variable list
        ADD     r3, r0, #mode_spec_vars
05
        LDR     r4, [r3], #4
        CMP     r4, #-1
        BEQ     %FT09
        LDR     r6, [r3], #4
        CMP     r4, #VduExt_NColour
        STREQ   r6, [r5, #GVPixelFormat_NColour]
        CMP     r4, #VduExt_ModeFlags
        LDREQ   r4, =ModeFlag_FullPalette :OR: ModeFlag_64k :OR: ModeFlag_ChromaSubsampleMode :OR: ModeFlag_DataFormat_Mask
        ANDEQ   r6, r6, r4
        STREQ   r6, [r5, #GVPixelFormat_ModeFlags]
        B       %BT05
09
        
        LDMIB   r0, {r3-r4}             ; get X,Y
        LDR     r6, [r0, #mode_spec_rate]
        EXIT

10
        MOV     r1, #VduExt_XWindLimit
        SWI     XOS_ReadModeVariable
        ADDVC   r3, r2, #1              ; r3 = X resolution

        MOVVC   r1, #VduExt_YWindLimit
        SWIVC   XOS_ReadModeVariable
        ADDVC   r4, r2, #1              ; r4 = Y resolution

        MOVVC   r1, #VduExt_Log2BPP
        SWIVC   XOS_ReadModeVariable
        STRVC   r2, [r5, #GVPixelFormat_Log2BPP]

        MOVVC   r1, #VduExt_NColour
        SWIVC   XOS_ReadModeVariable
        STRVC   r2, [r5, #GVPixelFormat_NColour]

        MOVVC   r1, #VduExt_ModeFlags
        SWIVC   XOS_ReadModeVariable
        LDRVC   r6, =ModeFlag_FullPalette :OR: ModeFlag_64k :OR: ModeFlag_ChromaSubsampleMode :OR: ModeFlag_DataFormat_Mask
        ANDVC   r2, r2, r6
        STRVC   r2, [r5, #GVPixelFormat_ModeFlags]

        MOVVC   r6, #-1                 ; Don't know frame rate so specify an impossible one.
        EXIT


;---------------------------------------------------------------------------
; Mode_TestPalette
;
;       In:     r5 -> pixel format
;       Out:    r0 corrupted
;               r1 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;
;       Read the current palette and determine if it is grey
;       level or colour.
;
Mode_TestPalette
        ROUT
        Entry   "r2-r4,r8,r9"

        LDR     r9, [r5, #GVPixelFormat_Log2BPP]
        Debug   mode,"Mode_TestPalette: log2bpp =",r9

        LDRB    r8, flags
        CMP     r9, #3
        BICHI   r1, r8, #f_greylevel    ; Assume high colour displays aren't greyscale
        STRHIB  r1, flags
        EXIT    HI
        
        ORR     r8, r8, #f_greylevel    ; Assume grey level until we find otherwise.

        MOV     r3, #1
        MOV     r1, r3, LSL r9          ; Log2BPP -> BPP
        MOV     r1, r3, LSL r1          ; BPP -> no of colours
        CMP     r1, #256                ; If 16 words or less then
        ADRLT   r2, user_data           ;   we can use user_data otherwise claim memory.
        MOVGT   r1, #256                ; Don't want more than 256 entries.
        MOVGE   r0, #ModHandReason_Claim
        MOVGE   r3, r1, LSL #2
        SWIGE   XOS_Module
        EXIT    VS
        Push    "r2"                    ; Remember base of block for later.

        MOV     r0, #0                  ; Start at palette entry 0.
        ORR     r1, r1, #17:SHL:24
        MOV     r3, #0
        MOV     r4, #7                  ; Read block of palette entries.
        MOV     r9, #PaletteV
        SWI     XOS_CallAVector
        BVS     %FT30

        BIC     r0, r1, #&FF000000      ; Get back number of entries we asked for.
        TEQ     r4, #0                  ; If block read didn't work then
        BNE     %FT40                   ;   try single reads.
10
        LDR     lr, [r2], #4            ; lr = &BBGGRRxx
        EOR     lr, lr, lr, LSL #8      ; lr = &BBGGRRxx ^ &GGRRxx00
        MOVS    lr, lr, LSR #16         ; Top 16 bits will be 0 if BB=GG=RR (ie. grey) so
        BICNE   r8, r8, #f_greylevel    ;   must be colour if not 0.
        BNE     %FT20
        SUBS    r0, r0, #1
        BNE     %BT10
20
        BL      freepalettemem
        STRB    r8, flags
        MOV     r1, r8
        EXIT
30
        BL      freepalettemem
        EXIT

40
        SUBS    r0, r0, #1              ; Start at last entry and work down to 0.
        BCC     %BT20                   ; If no more entries then all must be grey.

        MOV     r1, #17
        MOV     r4, #1
        SWI     XOS_CallAVector
        BVS     %BT30

        TEQ     r4, #0                  ; If no response to PaletteV then
        ADDNE   r0, r0, #1              ;   try the entry that failed again but
        BNE     %FT50                   ;   resort to OS_ReadPalette.

        EOR     r2, r2, r2, LSL #8      ; r2 = &BBGGRRxx ^ &GGRRxx00
        MOVS    r2, r2, LSR #16         ; Top 16 bits will be 0 if BB=GG=RR (ie. grey) so
        BICNE   r8, r8, #f_greylevel    ;   must be colour if not 0.
        BNE     %BT20
        B       %BT40

50
        SUBS    r0, r0, #1              ; Start at last entry and work down to 0.
        BCC     %BT20                   ; If no more entries then all must be grey.

        MOV     r1, #17
        SWI     XOS_ReadPalette
        BVS     %BT30

        EOR     r2, r2, r2, LSL #8      ; r2 = &B0G0R0xx ^ &G0R0xx00
        MOVS    r2, r2, LSR #16         ; Top 16 bits will be 0 if B=G=R (ie. grey) so
        BICNE   r8, r8, #f_greylevel    ;   must be colour if not 0.
        BNE     %BT20
        B       %BT50

freepalettemem
        Pull    r2                      ; Get back base of palette block.
      [ No32bitCode
        Push    "r0,lr"
      |
        Push    "r0,r4,lr"
        SavePSR r4
      ]
        ADR     lr, user_data
        TEQ     r2, lr                  ; If it's not the user area then free it.
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
      [ No32bitCode
        Pull    "r0,pc",,^
      |
        RestPSR r4,,f                   ; Preserve error if there is one.
        Pull    "r0,r4,pc"
      ]


;---------------------------------------------------------------------------
; Mode_SetSelection
;
;       In:     r1 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;               r3 = X resolution
;               r4 = Y resolution
;               r5 -> pixel format
;               r6 = frame rate (or -1 = unknown)
;       Out:    r0 corrupted
;               r2 -> enumerated mode descriptor (or -1 if not found)
;
;       Given the resolution and pixel depth set the menu selections
;       and mode which match.
;
Mode_SetSelection
        ROUT
        Entry   "r3-r7"

        Debug   mode,"Mode_SetSelection"

        LDR     r0, mode_classlist      ; Scan mode classes for the same resolution.
        TEQ     r0, #0                  ; If there is no class list then
        MOVEQ   r4, #&FF                ;   no selection
        BEQ     %FT20                   ;   and try colours.
        MOV     r7, #0
10
        LDR     lr, [r0], #4            ; Get pointer into mode_sortedlist.
        TEQ     lr, #0                  ; If end of list then
        MOVEQ   r4, #&FF                ;   no selection
        BEQ     %FT20                   ;   and try colours.

        LDR     lr, [lr]                ; Get pointer to mode descriptor.
        ASSERT  mode_desc0_yres = mode_desc0_xres + 4
        ASSERT  mode_desc1_xres = mode_desc0_xres
        ADD     lr, lr, #mode_desc0_xres
        LDMIA   lr, {r2,lr}             ; Get X,Y resolution.
        TEQ     r3, r2                  ; If not the same then
        TEQEQ   r4, lr
        ADDNE   r7, r7, #1              ;   move on to next class.
        BNE     %BT10

        MOV     r4, r7                  ; Found a class with required resolution.
20
        MOV     r0, r1
        BL      Mode_PixelFormatToMenuItem
        MOV     r0, #4                  ; Don't downgrade, allow non-menu modes.
        BL      Mode_FindSubClass       ; Find our copy of the mode descriptor.
        STR     r2, selected_subclass
        STRB    r3, selected_colours
        STRB    r4, selected_class
        STR     r5, selected_mode
        CLRV
        MOV     r2, r5                  ; Return mode descriptor in r2.
        EXIT


;---------------------------------------------------------------------------
; Mode_PixelFormatToMenuItem
;
;       In:     r0 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;               r5 -> pixel format
;       Out:    r0 corrupted
;               r3 = menu item
;
;       Set the colour and resolution icons to the current selection.
;
Mode_PixelFormatToMenuItem
        ROUT
        Entry
        TST     r0, #f_greylevel
        LDR     lr, [r5, #GVPixelFormat_Log2BPP]
        ADREQ   r0, log2bpp_to_colouritem
        ADRNE   r0, log2bpp_to_greyitem
        LDRB    r3, [r0, lr]            ; Get colour selection.
        TEQEQ   lr, #4                  ; 16bpp colour needs extra logic
        EXIT    NE
        LDR     lr, [r5, #GVPixelFormat_NColour]
        ADD     lr, lr, #1
        CMP     lr, #4096
        MOVEQ   r3, #mo_co_4K
        EXIT    EQ
        LDR     lr, [r5, #GVPixelFormat_ModeFlags]
        TST     lr, #ModeFlag_64k
        MOVNE   r3, #mo_co_64K
        EXIT        

log2bpp_to_greyitem     DCB     mo_co_mono,mo_co_grey4,mo_co_grey16,mo_co_grey256,mo_co_32K,mo_co_16M,mo_co_16M
log2bpp_to_colouritem   DCB     mo_co_mono,mo_co_grey4,mo_co_colour16,mo_co_colour256,mo_co_32K,mo_co_16M,mo_co_16M

                        ALIGN

;---------------------------------------------------------------------------
; Mode_DescriptorToColourMenuItem
;
;       In:     r0 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;               r6 -> mode descriptor
;       Out:    r5 = colour menu item
;
Mode_DescriptorToColourMenuItem
        ROUT
        Entry   "r0,r3,r4", GVPixelFormat_Size
        LDR     lr, [r6, #mode_desc_flags]
        TST     lr, #2
        ADDNE   r5, r6, #mode_desc1_format
        BNE     %FT30
        
        LDR     r4, [r6, #mode_desc0_depth]
        MOV     r5, sp
        BL      Mode_PixelFormatFromLog2BPP
30
        BL      Mode_PixelFormatToMenuItem
        MOV     r5, r3
        EXIT

;---------------------------------------------------------------------------
; Mode_SetWindowIcons
;
;       In:     r2 -> enumerated mode descriptor (or -1)
;               r3 = X resolution (used if r2 = -1)
;               r4 = Y resolution (used if r2 = -1)
;               r6 = frame rate (used if r2 = -1)
;       Out:    r0 corrupted
;
;       Set the colour and resolution icons to the current selection.
;
Mode_SetWindowIcons
        ROUT
        Entry   "r1-r4"

        Debug   mode,"Mode_SetWindowIcons",r2

        LDRB    r1, selected_colours    ; Do colours icon first.
        MOV     lr, #-1
        Push    "r1,lr"                 ; Create fake mode selection block.
        ADR     r1, m_coloursmenu
        MOV     r2, sp
        LDR     r3, colours_indirect
        SWI     XWimp_DecodeMenu
        ADD     sp, sp, #8              ; Balance stack.
        EXIT    VS

        LDMIA   sp, {r1-r3}             ; Restore registers for resolution icon.
        CMP     r2, #-1                 ; If not a standard mode then
        BEQ     %FT10                   ;   have to build resolution.

        LDR     r0, [r2, #mode_desc_flags]
        TST     r0, #2
        ADDEQ   r0, r2, #mode_desc0_name ; Copy mode string.
        ADDNE   r0, r2, #mode_desc1_name

        LDRB    lr, [r0]
        TEQ     lr, #0                  ; If we have a blank mode name then
        ASSERT  mode_desc0_xres = mode_desc1_xres
        ADDEQ   lr, r2, #mode_desc0_xres
        LDMEQIA lr, {r3,r4}
        BEQ     %FT10                   ;   have to build resolution.

        LDR     r1, resolution_indirect
        LDR     r2, resolution_size
        BL      Mod_CopyString
        B       %FT20
10
        LDR     r1, resolution_indirect
        LDR     r2, resolution_size

        MOV     r0, r3
        SWI     XOS_ConvertCardinal4

        ADRVC   r0, resolution_spacer
        BLVC    Mod_CopyString

        MOVVC   r0, r4
        SWIVC   XOS_ConvertCardinal4
        EXIT    VS
20
        LDR     lr, [sp, #4]                    ; Get back mode descriptor.
        CMP     lr, #-1                         ; If not a standard mode then
        MOVEQ   r0, r6                          ;   use r6
        BEQ     %FT25
        LDR     r0, [lr, #mode_desc_flags]
        TST     r0, #2
        LDREQ   r0, [lr, #mode_desc0_rate]      ;   else use rate from mode descriptor.
        LDRNE   r0, [lr, #mode_desc1_rate]

25
 [ SelectFrameRate
        CMP     r0, #-1                 ; If we don't know the frame rate then
        BEQ     %FT30                   ;   fill in "Unknown".

        LDR     r1, rate_indirect
        LDR     r2, rate_size
        SWI     XOS_ConvertCardinal4

        ADRVC   r0, mode_hz
        BLVC    Mod_CopyString
        EXIT
30
        ADR     r1, unknown
        LDR     r2, rate_indirect
        LDR     r3, rate_size
        BL      MsgTrans_Lookup
        EXIT
 |
        CMP     r0, #-1                 ; If we don't know the frame rate then
        EXIT    EQ                      ;   don't add any more.

        MOV     r3, r0

        ADR     r0, open_bracket
        BL      Mod_CopyString

        MOV     r0, r3
        SWI     XOS_ConvertCardinal4

        ADRVC   r0, close_bracket
        BLVC    Mod_CopyString
        EXIT
 ]

resolution_spacer       DCB     " x ",0
unknown                 DCB     "Unknown",0
 [ SelectFrameRate
mode_hz                 DCB     "Hz",0
 |
open_bracket            DCB     " (",0
close_bracket           DCB     "Hz)",0
 ]
xres                    DCB     "X",0
yres                    DCB     " Y",0
greys                   DCB     " G",0
colours                 DCB     " C",0
                        ALIGN


;---------------------------------------------------------------------------
; Mode_SetModeString
;
;       In:     r1 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;               r2 = mode specifier
;       Out:    r0 corrupted
;
;       Set mode string icon to the appropriate text.
;
Mode_SetModeString
        ROUT
        Entry   "r1-r3"

        Debug   mode,"Mode_SetModeString: flags,mode =",r1,r2

        CMP     r2, #256
        BCC     %FT10                   ; If it's a mode number then just print it
        MOV     r0, #ScreenModeReason_ModeSpecifierToString
        MOV     r1, r2
        LDR     r2, mode_indirect
        LDR     r3, mode_size
        SWI     XOS_ScreenMode
        ; Swallow any error/overflow and ensure string is terminated
        MOVVS   r3, #-1
        CMP     r3, #0
        MOVLT   r0, #0
        STRLTB  r0, [r2]
        EXIT
10
        MOV     r0, r2
        LDR     r1, mode_indirect
        LDR     r2, mode_size
        SWI     XOS_ConvertCardinal4
        EXIT

;---------------------------------------------------------------------------
; Mode_KeyPressed
;
;       In:     r1 -> key pressed block
;       Out:    r0 corrupted
;
;       The Wimp has informed us of a key press.
;
Mode_KeyPressed
        Entry   "r1"

        LDR     r0, [r1]                ; r0 = window handle
        LDR     lr, mode_handle
        TEQ     r0, lr                  ; If it's the mode window then
        LDREQ   r0, [r1, #24]           ;   get the character
        TEQEQ   r0, #13                 ;   and if it's return then
        BEQ     %FT10                   ;   deal with it

        SWI     XWimp_ProcessKey        ; else pass on the key press.
        EXIT

10
        MOV     r1, #0
        STR     r1, menu_handle
        MOV     r1, #-1                 ; Remove menu and dialogue.
        SWI     XWimp_CreateMenu
        BL      Mode_WimpCommand        ; Change mode.
        EXIT


;---------------------------------------------------------------------------
; Mode_WimpCommand
;
;       Out:    r0 corrupted
;
;       Pass the string in the mode dialogue box to *WimpMode.
;
Mode_WimpCommand
        Entry   "r1,r2"

        ADR     r0, command_wimpmode    ; Build *WimpMode command.
        ADR     r1, user_data
        MOV     r2, #user_data_size
        BL      Mod_CopyString

        LDR     r0, mode_indirect
        BL      Mod_CopyString

        ADR     r0, user_data           ; Do it!
 [ debugmode :LOR: {FALSE}
        SUB     r0, r0, #4
        MOV     r1, #1
        BL      Mod_ReportError
        ADD     r0, r0, #4
 ]
        SWI     XOS_CLI
        ADRVS   r0, ErrorBlock_Modes_InvalidMode
        BLVS    MsgTrans_ErrorLookup

        EXIT

command_wimpmode
        DCB     "WimpMode ",0
        ALIGN

        MakeErrorBlock  Modes_InvalidMode


;---------------------------------------------------------------------------
; Mode_GetTable
;
;       Out:    r0 corrupted
;
;       Get the list of currently available modes.
;
Mode_GetTable
        ROUT
        Entry   "r1-r7"

        Debug   mode,"Mode_GetTable"

        LDR     r2, mode_space
        TEQ     r2, #0                  ; If we already have space allocated then
        MOVNE   lr, #0                  ;   free it.
        STRNE   lr, mode_space
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module

 [ Medusa
        MOV     r0, #ScreenModeReason_EnumerateModes ; Find out how much space we need for the new one.
        MOV     r2, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XOS_ScreenMode
        EXIT    VS
 |
        MOV     r2, #-dummy_count
        ADR     r7, dummy_start
        ADRL    lr, dummy_end
        SUB     r7, r7, lr
 ]

        RSBS    r4, r2, #0              ; r4 = number of modes
        STR     r4, mode_count
        BEQ     %FT20
        RSB     r7, r7, #3
        BIC     r7, r7, #3              ; r7 = word aligned space required

        Debug   mode," count,size =",r4,r7

        ASSERT  mi_size = 24
        MOV     r3, r4, LSL #3          ; Determine max space required (start with resolution menu).
        ADD     r3, r3, r3, LSL #1      ; r3 = space for menu items (mode count * 24)
        ADD     r3, r3, #m_headersize   ; Add space for menu header.
        STR     r3, m_resolutionsize
 [ SelectFrameRate
        STR     r3, m_ratesize          ; Add space for rate menu.
        ADD     r3, r3, r3
 ]
        ADD     r3, r3, r7              ; Add space for mode table.
        ADD     r4, r4, #1
        ADD     r3, r3, r4, LSL #2      ; Add space for sorted list ((mode count + 1) * 4).
        ADD     r3, r3, r4, LSL #2      ; Add space for class list.
        ADD     r3, r3, r4, LSL #2      ; Add space for menu list.
        Debug   mode," total space allocated =",r3
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module              ; Claim the space.
        EXIT    VS
        ASSERT  mode_space = mode_sortedlist
        STR     r2, mode_sortedlist     ; Store pointers.
        ADD     r6, r2, r4, LSL #2
        STR     r6, mode_classlist
        ADD     r6, r6, r4, LSL #2
        STR     r6, mode_menulist
        ADD     r6, r6, r4, LSL #2
        STR     r6, mode_table
        ADD     r2, r6, r7
        STR     r2, m_resolutionmenu
 [ SelectFrameRate
        LDR     lr, m_resolutionsize
        ADD     r2, r2, lr
        STR     r2, m_ratemenu
 ]

 [ Medusa
        MOV     r2, #0                  ; Fill in the table.
        MOV     r0, #ScreenModeReason_EnumerateModes
        SWI     XOS_ScreenMode
        BVS     %FT10
        TEQ     r1, #0
        ADREQ   r0, ErrorBlock_Modes_CantEnumerate
        BLEQ    MsgTrans_ErrorLookup
 |
        ADR     r2, dummy_start
99
        SUBS    r7, r7, #1
        LDRCSB  lr, [r2], #1
        STRCSB  lr, [r6], #1
        BCS     %BT99
        CLRV
 ]
        BLVC    Mode_SortList
        EXIT    VC
10
        MOV     r7, r0                  ; Save error.
        LDR     r2, mode_space
        MOV     r0, #ModHandReason_Free ; Free the space we claimed.
        SWI     XOS_Module
        MOV     r0, r7                  ; Restore error.
        SETV
20
        MOV     lr, #0
        STR     lr, mode_sortedlist
        STR     lr, mode_classlist
        STR     lr, mode_menulist
        STR     lr, mode_table
        STR     lr, m_resolutionmenu
 [ SelectFrameRate
        STR     lr, m_ratemenu
 ]
        EXIT

 [ :LNOT: Medusa
        ROUT
 [ {FALSE}
dummy_count     *       0
dummy_start
dummy_end
 |
dummy_count     *       44
dummy_start

        DCD     &24,1,&420,&100,0,&46
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,1,&46
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,2,&46
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,3,&46
        DCB     "1056 x 256",0
        ALIGN

        DCD     &24,1,&420,&100,0,&3C
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,1,&3C
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,2,&3C
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,3,&3C
        DCB     "1056 x 256",0
        ALIGN

        DCD     &24,1,&420,&100,0,&32
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,1,&32
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,2,&32
        DCB     "1056 x 256",0
        ALIGN
        DCD     &24,1,&420,&100,3,&32
        DCB     "1056 x 256",0
        ALIGN

        DCD     &24,1,&420,&FA,0,&32
        DCB     "1056 x 250",0
        ALIGN
        DCD     &24,1,&420,&FA,1,&32
        DCB     "1056 x 250",0
        ALIGN
        DCD     &24,1,&420,&FA,2,&32
        DCB     "1056 x 250",0
        ALIGN
        DCD     &24,1,&420,&FA,3,&32
        DCB     "1056 x 250",0
        ALIGN

        DCD     &1C,1,&300,&120,0,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&300,&120,1,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&300,&120,2,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&300,&120,3,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&300,&120,4,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&300,&120,5,&32
        DCB     0
        ALIGN

        DCD     &1C,1,&280,&100,0,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&100,1,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&100,2,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&100,3,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&100,4,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&100,5,&32
        DCB     0
        ALIGN

        DCD     &1C,1,&280,&FA,0,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&FA,1,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&FA,2,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&FA,3,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&FA,4,&32
        DCB     0
        ALIGN
        DCD     &1C,1,&280,&FA,5,&32
        DCB     0
        ALIGN

        DCD     &24,1,&140,&100,0,&32
        DCB     "320 x 256",0
        ALIGN
        DCD     &24,1,&140,&100,1,&32
        DCB     "320 x 256",0
        ALIGN
        DCD     &24,1,&140,&100,2,&32
        DCB     "320 x 256",0
        ALIGN
        DCD     &24,1,&140,&100,3,&32
        DCB     "320 x 256",0
        ALIGN
        DCD     &24,1,&140,&100,4,&32
        DCB     "320 x 256",0
        ALIGN

        DCD     &24,1,&140,&FA,0,&32
        DCB     "320 x 250",0
        ALIGN
        DCD     &24,1,&140,&FA,1,&32
        DCB     "320 x 250",0
        ALIGN
        DCD     &24,1,&140,&FA,2,&32
        DCB     "320 x 250",0
        ALIGN
        DCD     &24,1,&140,&FA,3,&32
        DCB     "320 x 250",0
        ALIGN
        DCD     &24,1,&140,&FA,4,&32
        DCB     "320 x 250",0
        ALIGN

dummy_end
 ]
 ]

        MakeErrorBlock  Modes_CantEnumerate

;---------------------------------------------------------------------------
; Mode_ComparePixelFormatsAndFramerates
;
;       In:     r2 -> mode descriptor 1
;               r3 -> mode descriptor 2
;       Out:    CC = descriptor 2 should appear first
;               NE = descriptor 1 should appear first
;               EQ = both identical
Mode_ComparePixelFormatsAndFramerates
        ROUT
        Entry   "r0-r1,r4-r7", GVPixelFormat_Size*2
        ; Get pixel formats
        ASSERT  mode_desc0_depth = mode_desc1_format
        ASSERT  mode_desc0_rate = mode_desc0_depth+?mode_desc0_depth
        ASSERT  mode_desc1_rate = mode_desc1_format+?mode_desc1_format

        LDR     r0, [r2, #mode_desc_flags]
        MOV     r5, sp
        ADD     r2, r2, #mode_desc1_format
        TST     r0, #2
        LDMIA   r2!, {r4,r6-r7} ; Get pixel format, or just the depth
        STMNEIA r5, {r4,r6-r7}  ; Copy as-is if pixel format
        SUBEQ   r2, r2, #?mode_desc1_format-?mode_desc0_depth ; Leave r2 -> rate
        BLEQ    Mode_PixelFormatFromLog2BPP ; Convert if depth

        LDR     r0, [r3, #mode_desc_flags]
        ADD     r5, sp, #GVPixelFormat_Size
        ADD     r3, r3, #mode_desc1_format
        TST     r0, #2
        LDMIA   r3!, {r4,r6-r7}
        STMNEIA r5, {r4,r6-r7}
        SUBEQ   r3, r3, #?mode_desc1_format-?mode_desc0_depth
        BLEQ    Mode_PixelFormatFromLog2BPP

        ; Compare formats.
        ; First, we sort by the basic pixel formats available from the menu
        ; Then we sort by framerate
        ; Then, we'll sort by expected software compatibility:
      [ Allow24bpp
        ;   32bpp -> 24bpp
      ]
        ;   TBGR -> TRGB -> ABGR -> ARGB
        ; This should ensure that for a given colour depth & framerate, the
        ; most compatible mode is the one that will be selected on mode changes
        Push    "r3"
        MOV     r0, #0
        BL      Mode_PixelFormatToMenuItem
        MOV     r4, r3
        ADD     r5, sp, #4
        MOV     r0, #0
        BL      Mode_PixelFormatToMenuItem
        CMP     r4, r3
        Pull    "r3"
        EXIT    NE

        ; Sort by framerate
        LDR     r4, [r2], #4
        LDR     r5, [r3], #4
        CMP     r4, r5
        EXIT    NE

      [ Allow24bpp
        ; Handle 32bpp/24bpp case
        LDR     r0, [sp, #GVPixelFormat_Log2BPP]
        LDR     r1, [sp, #GVPixelFormat_Log2BPP+GVPixelFormat_Size]
        CMP     r1, r0
        EXIT    NE
      ]
        ; Handle transparency & RGB ordering
        ASSERT  ModeFlag_DataFormatSub_RGB < ModeFlag_DataFormatSub_Alpha ; Use &RGB order before alpha
        LDR     r0, [sp, #GVPixelFormat_ModeFlags]
        LDR     r1, [sp, #GVPixelFormat_ModeFlags+GVPixelFormat_Size]
        AND     r0, r0, #ModeFlag_DataFormatSub_Mask
        AND     r1, r1, #ModeFlag_DataFormatSub_Mask
        CMP     r1, r0
        EXIT

;---------------------------------------------------------------------------
; Mode_CheckIdentical
;
;       In:     r2 -> mode descriptor 1
;               r3 -> mode descriptor 2
;       Out:    EQ = both are identical apart from RGB/BGR order or alpha mode
;               NE = both are different
Mode_CheckIdentical
        ROUT
        Entry   "r0-r7", GVPixelFormat_Size*2

      [ SortOnPixelShape
        ; Check square pixel flag
        LDR     r0, [r2, #mode_desc_flags]
        LDR     r1, [r3, #mode_desc_flags]
        ASSERT  flags_squarepixel = 1:SHL:31
        TEQ     r0, r1
        EXIT    MI
      ]

        ; Compare width & height
        ASSERT  mode_desc0_xres = mode_desc1_xres
        ASSERT  mode_desc0_yres = mode_desc1_yres
        LDR     r0, [r2, #mode_desc0_xres]
        LDR     r1, [r2, #mode_desc0_yres]
        LDR     r4, [r3, #mode_desc0_xres]
        LDR     r5, [r3, #mode_desc0_yres]
        CMP     r0, r4
        CMPEQ   r1, r5
        EXIT    NE

        ; Get pixel formats
        ASSERT  mode_desc0_depth = mode_desc1_format
        ASSERT  mode_desc0_rate = mode_desc0_depth+?mode_desc0_depth
        ASSERT  mode_desc1_rate = mode_desc1_format+?mode_desc1_format

        LDR     r0, [r2, #mode_desc_flags]
        MOV     r5, sp
        ADD     r2, r2, #mode_desc1_format
        TST     r0, #2
        LDMIA   r2!, {r4,r6-r7} ; Get pixel format, or just the depth
        STMNEIA r5, {r4,r6-r7}  ; Copy as-is if pixel format
        SUBEQ   r2, r2, #?mode_desc1_format-?mode_desc0_depth ; Leave r2 -> rate
        BLEQ    Mode_PixelFormatFromLog2BPP ; Convert if depth

        LDR     r0, [r3, #mode_desc_flags]
        ADD     r5, sp, #GVPixelFormat_Size
        ADD     r3, r3, #mode_desc1_format
        TST     r0, #2
        LDMIA   r3!, {r4,r6-r7}
        STMNEIA r5, {r4,r6-r7}
        SUBEQ   r3, r3, #?mode_desc1_format-?mode_desc0_depth
        BLEQ    Mode_PixelFormatFromLog2BPP

        ; Check if the pixel formats decode to the same item in the colours menu
        Push    "r3"
        MOV     r0, #0
        BL      Mode_PixelFormatToMenuItem
        MOV     r4, r3
        ADD     r5, sp, #4
        MOV     r0, #0
        BL      Mode_PixelFormatToMenuItem
        CMP     r4, r3
        Pull    "r3"
        EXIT    NE

        ; Compare framerate
        LDR     r4, [r2], #4
        LDR     r5, [r3], #4
        CMP     r4, r5
        EXIT    NE

        ; Compare mode name
10
        LDRB    r4, [r2], #1
        LDRB    r5, [r3], #1
        CMP     r4, r5
        EXIT    NE
        CMP     r4, #0
        BNE     %BT10        
        
        EXIT


;---------------------------------------------------------------------------
; Mode_SortList
;
;       Out:    r0 corrupted
;
;       Fill in mode_sortedlist with a sorted list of pointers into
;       mode_table.  The modes are sorted on increasing X, increasing Y,
;       increasing pixel depth then decreasing frame rate.  This call
;       also fills in mode_classlist with pointers to class blocks in
;       mode_sortedlist (ie. block of mode pointers to modes with the
;       same resolution).  This is used to build the resolution menu.
;
Mode_SortList
        ROUT
        Entry   "r1-r6"

        Debug   mode,"Mode_SortList"

        LDR     r1, mode_sortedlist
        TEQ     r1, #0
        EXIT    EQ
        Debug   mode," sorted list at",r1

        ASSERT  mode_desc_size = 0
        ASSERT  mode_desc_flags = mode_desc_size + 4
        LDR     r2, mode_table          ; Build list of pointers to valid modes.
        LDR     r3, mode_count
        Debug   mode," table,count =",r2,r3
10
        LDMIA   r2, {r4,lr}             ; Get size and flags.
        AND     lr, lr, #&FF            ; Ignore flag bits 8-31.
        TEQ     lr, #1                  ; If flags are valid then
        BEQ     %FT28                   ;     use mode
        TEQ     lr, #3                  ; If new format, must skip unwanted pixel formats (e.g. YUV). TODO - Use a whitelist of accepted formats?
        LDR     lr, [r2, #mode_desc1_format+GVPixelFormat_Log2BPP]
      [ Allow24bpp
        CMP     lr, #6                  ; Log2BPP 7+ is YUV or completely unknown
      |
        CMP     lr, #5                  ; Log2BPP 6+ is 24bpp packed, YUV, or completely unknown
      ]
        BHI     %FT29
        LDR     lr, [r2, #mode_desc1_format+GVPixelFormat_ModeFlags]
        ASSERT  ModeFlag_DataFormatFamily_RGB = 0
        TST     lr, #ModeFlag_DataFormatFamily_Mask ; Must be RGB family
        BNE     %FT29

28
        STR     r2, [r1], #4            ;     use mode.
 [ SortOnPixelShape
        BL      Mode_PixelShape
 ]

29
        ADD     r2, r2, r4              ; Move on to next mode.
        SUBS    r3, r3, #1              ; Try next mode.
        BNE     %BT10
        STR     r3, [r1]                ; Terminate list with 0.
30
        MOV     r6, #0                  ; Bubble sort list (r6 counts the number of swaps).
        LDR     r1, mode_sortedlist
40
        LDMIA   r1, {r2,r3}             ; Get pointers to modes to compare.
        TEQ     r2, #0                  ; If either is 0 then we are at the end of the list.
        TEQNE   r3, #0
        BEQ     %FT70

        ASSERT  mode_desc0_yres = mode_desc0_xres + 4
        ASSERT  mode_desc1_xres = mode_desc0_xres
        ASSERT  mode_desc1_yres = mode_desc0_yres
 [ SortOnPixelShape
        LDR     r4, [r2, #mode_desc_flags]
        LDR     r5, [r3, #mode_desc_flags]
        AND     r4, r4, #flags_squarepixel
        AND     r5, r5, #flags_squarepixel
        TEQ     r4, r5                  ; If both square or both non-square then
        BEQ     %FT45                   ;   do more tests.
        TEQ     r4, #flags_squarepixel  ; else if first is square then second must be non-square so
        BEQ     %FT60                   ;   swap
        B       %FT50                   ; else skip.
45
 ]
        ADD     r2, r2, #mode_desc0_xres
        ADD     r3, r3, #mode_desc0_xres
        LDR     r4, [r2], #4
        LDR     r5, [r3], #4
        CMP     r5, r4                  ; If next X resolution < this X resolution then
        BCC     %FT60                   ;   swap items.
        BNE     %FT50
        LDR     r4, [r2], #-mode_desc0_yres
        LDR     r5, [r3], #-mode_desc0_yres
        CMP     r5, r4                  ; If next Y resolution < this Y resolution then
        BCC     %FT60                   ;   swap items.
        BNE     %FT50
        BL      Mode_ComparePixelFormatsAndFramerates
        BCC     %FT60                   ;   swap items
50
        ADD     r1, r1, #4              ; else try next pair.
        B       %BT40
60
        LDMIA   r1, {r2,r3}             ; Swap current pair.
        MOV     r4, r2
        STMIA   r1, {r3,r4}
        ADD     r6, r6, #1
        ADD     r1, r1, #4
        B       %BT40
70
        TEQ     r6, #0                  ; If anything was swapped then
        BNE     %BT30                   ;   do another pass.

        ; Go through and discard any modes which are identical to their
        ; predecessor, except for RGB/BGR ordering & alpha mode
        ; This avoids the framerate menu showing lots of entries which appear
        ; to be identical from the user's POV
        LDR     r0, mode_sortedlist
        ADD     r1, r0, #4
        LDR     r2, [r0]
        CMP     r2, #0
        BEQ     %FT72
71
        LDR     r3, [r1], #4
        CMP     r3, #0
        STREQ   r3, [r0, #4]
        BEQ     %FT72
        BL      Mode_CheckIdentical
        STRNE   r3, [r0, #4]!
        MOVNE   r2, r3
        B       %BT71
72

        LDR     r0, mode_classlist      ; Now build mode_classlist.
        Debug   mode," class list at",r0
        LDR     r1, mode_sortedlist
        MOV     r2, #-1                 ; Previous X resolution.
        MOV     r3, #-1                 ; Previous Y resolution.
80
        LDR     lr, [r1]                ; Get mode pointer.
        TEQ     lr, #0                  ; If at the end of mode_sortedlist then
        STREQ   lr, [r0]                ;   terminate mode_classlist
 [ SortOnPixelShape
        LDREQ   lr, mode_classlist
        SUBEQ   lr, r0, lr
        MOVEQ   lr, lr, LSR #2
        STREQB  lr, class_count
 ]
        EXIT    EQ                      ;   and exit.

        ASSERT  mode_desc0_yres = mode_desc0_xres + 4
        ASSERT  mode_desc1_xres = mode_desc0_xres
        ADD     lr, lr, #mode_desc0_xres
        LDMIA   lr, {r4,r5}             ; Get X,Y resolution.
        TEQ     r2, r4                  ; If resolution is not the same as previous then
        TEQEQ   r3, r5
        STRNE   r1, [r0], #4            ; Store pointer.
        MOVNE   r2, r4                  ; Current resolution becomes previous.
        MOVNE   r3, r5
        ADD     r1, r1, #4              ; Try next.
        B       %BT80


 [ SortOnPixelShape

;---------------------------------------------------------------------------
; Mode_PixelShape
;
;       In:     r2 -> enumerated mode descriptor
;       Out:    mode descriptor flags updated to reflect pixel shape
;
;       Set mode descriptor flag "flags_squarepixel" if the given mode has
;       square pixels.
;
Mode_PixelShape
        Entry   "r0-r3"

        MOV     r1, #0
        BL      Mode_BuildSpecifier
        MOV     r0, r2
        MOV     r1, #VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOV     r3, r2
        MOV     r1, #VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        TEQ     r2, r3
        LDR     r2, [sp, #8]
        LDREQ   lr, [r2, #mode_desc_flags]
        ORREQ   lr, lr, #flags_squarepixel
        STREQ   lr, [r2, #mode_desc_flags]

        EXIT

 ]


;---------------------------------------------------------------------------
; Mode_BuildSpecifier
;
;       In:     r1 = flags
;                       bit     meaning when set
;                       0       mode uses grey levels not colour
;                       1-31    reserved
;               r2 -> enumerated mode descriptor
;       Out:    r2 -> mode specifier
;
;       Given the mode descriptor, build a valid mode specifier.
;
Mode_BuildSpecifier
        Entry   "r0-r1,r3-r6", GVPixelFormat_Size

        ASSERT  mode_desc0_xres = mode_desc_flags + 4        
        ASSERT  mode_desc0_yres = mode_desc0_xres + 4
        ASSERT  mode_desc0_depth = mode_desc0_yres + 4
        ASSERT  mode_desc1_xres = mode_desc0_xres
        ADD     r2, r2, #mode_desc_flags
        LDMIA   r2!, {r0,r1,r3,r4}      ; Get flags,X,Y & depth (for old format)
        TST     r0, #2                  ; New or old format?
        MOV     r0, #1                  ; specifier flags = 1
        ADR     r6, user_data
        ASSERT  mode_spec_flags = 0
        ASSERT  mode_spec_xres = 4
        ASSERT  mode_spec_yres = 8
        STMIA   r6!, {r0,r1,r3}
        MOVEQ   r5, sp
        SUBNE   r5, r2, #4
        ADDNE   r2, r2, #8
        BLEQ    Mode_PixelFormatFromLog2BPP
        
        ASSERT  GVPixelFormat_NColour = 0
        ASSERT  GVPixelFormat_ModeFlags = 4
        ASSERT  GVPixelFormat_Log2BPP = 8
        LDMIA   r5, {r0,r3,r4}
        LDR     r5, [r2]                ; Grab framerate
        ASSERT  mode_spec_depth = 12
        ASSERT  mode_spec_rate = 16
        ASSERT  mode_spec_vars = 20
        MOV     lr, #VduExt_NColour
        STMIA   r6!, {r4,r5,lr}         ; depth, rate, NColour index
        ; Check if we need to set the greyscale flag
        FRAMLDR r1
        TST     r1, #f_greylevel
        ORRNE   r3, r3, #ModeFlag_GreyscalePalette
        MOV     r2, #VduExt_ModeFlags
        MOV     r4, #-1
        STMIA   r6, {r0,r2-r3,r4}       ; NColour value, ModeFlags pair, terminator
        ADR     r2, user_data
        EXIT


;---------------------------------------------------------------------------
; Mode_FindSubClass
;
;       In:     r0 = flags
;                       bit     meaning when set
;                       0       downgrade class
;                       1       downgrade colours
;                       2       allow modes which don't appear on menus
;               r3 = selected colours menu item
;               r4 = selected class
;               r6 = selected frame rate (or -1=don't care)
;       Out:    r0 corrupted
;               r2 -> possible subclass (list of pointers to suitable modes)
;               r3 = possible colours
;               r4 = possible class
;               r5 -> possible mode
;
;       Given the selected colour choice and class the mode list is
;       searched for a mode that matches.  If one is not found then the
;       specified choice is downgraded until a match is found or no more
;       downgrading is possible.  If no mode is found then the same process
;       will be applied but stepping up.  If there is still no mode found
;       then an error is returned.  On exit r2 points to a suitable subclass
;       (list of pointers to modes with the same resolution and depth).
;
;       This used to be a nice simple routine but constant demands for changes
;       to the Display Manager's behaviour have turned it into a monster!!
;
Mode_FindSubClass
        ROUT
        Entry   "r1,r3,r4,r7-r11"

        Debug   mode,"Mode_FindSubClass ",r3,r4

        MOV     r2, #-1                 ; No subclass yet.
        MOV     r5, #-1                 ; No mode yet.

        TEQ     r3, #&FF                ; If either selection is not supported then
        TEQNE   r4, #&FF
        BEQ     %FT60                   ;   return error.

        TST     r0, #4                  ; IF not allowing non-menu modes then check what we're starting from.
        BNE     %FT09
        LDR     lr, mode_classlist
        ADD     lr, lr, r4, LSL #2
        LDR     lr, [lr]                ; Get pointer to class we're starting from.
        LDR     lr, [lr]                ; Get pointer to mode descriptor.
        LDR     r10, [lr, #mode_desc_flags]
        TST     r10, #2
        LDREQB  lr, [lr, #mode_desc0_name]
        LDRNEB  lr, [lr, #mode_desc1_name]
        TEQ     lr, #0                  ; If the mode we're starting from is not on the menu then
        ORR     r0, r0, #4              ;   allow non-menu modes.

09
        MOV     r10, #-1                ; Start by stepping down.
10
        ADR     lr, colours_to_pixelformat
        ASSERT  GVPixelFormat_Size = 12
        ADD     lr, lr, r3, LSL #3
        ADD     r1, lr, r3, LSL #2      ; Get the selected pixel format.

        LDR     r7, mode_classlist
        ADD     r7, r7, r4, LSL #2
        Debug   mode," class list pointer =",r7
        LDMIA   r7, {r7,r8}             ; Get pointers to selected class and next class.
        TEQ     r7, #0                  ; If reached the end of mode_classlist then
        BEQ     %FT60                   ;   return error.
        TEQ     r8, #0
        LDRNE   r8, [r8]                ; Stop when we get to mode r8.
30
        LDR     r9, [r7], #4            ; Get pointer to mode descriptor
        TEQ     r9, r8                  ; If reached the end of this class then
        BEQ     %FT40                   ;   downgrade and try again.

        LDR     lr, [r9, #mode_desc_flags]
        TST     lr, #2
        BNE     %FT35

        ; Old format descriptor
        TST     r0, #4                  ; If not allowing modes not on menus
        LDREQB  lr, [r9, #mode_desc0_name]
        TEQEQ   lr, #0                  ;   and this mode is not on the menus then
        BEQ     %BT30                   ;   try next in class.

        BL      Mode_IsOldPixelFormat   ; If this isn't an old pixel format
        BNE     %BT30                   ;   try next in class.

        LDR     lr, [r9, #mode_desc0_depth]      ; Get pixel depth.
        LDR     r11, [r1, #GVPixelFormat_Log2BPP]
        TEQ     r11, lr                 ; If it doesn't match the selected depth then
        BNE     %BT30                   ;   try next in class.

        CMP     r2, #-1                 ; If no subclass yet then
        SUBEQ   r2, r7, #4              ;   this is it.

        CMP     r6, #-1                 ; If no frame rate specified
        LDRNE   lr, [r9, #mode_desc0_rate]
        CMPNE   lr, r6                  ;   or frame rate matches then
        MOVEQ   r5, r9                  ;     return this mode.
        STREQ   r3, [sp, #4]
        STREQ   r4, [sp, #8]
        EXIT    EQ                      ; Exit with V clear.
        B       %BT30                   ; Otherwise, continue search.

35
        ; New format descriptor
        TST     r0, #4                  ; If not allowing modes not on menus
        LDREQB  lr, [r9, #mode_desc1_name]
        TEQEQ   lr, #0                  ;   and this mode is not on the menus then
        BEQ     %BT30                   ;   try next in class.

        ; Fuzzy matching: We don't require the transparency mode or RGB order to match, as currently there's no way for the user to select those from the menus
      [ Allow24bpp
        ; We also need to deal with 24bpp vs. 32bpp packing
      ]
        LDR     lr, [r9, #mode_desc1_format+GVPixelFormat_NColour]
        LDR     r11, [r1, #GVPixelFormat_NColour]
        TEQ     r11, lr
      [ Allow24bpp
        ORRNE   lr, lr, lr, LSL #24 ; try converting 24bpp NColour to 32bpp
        TEQNE   r11, lr
      ]
        BNE     %BT30
        LDR     lr, [r9, #mode_desc1_format+GVPixelFormat_ModeFlags]
        LDR     r11, [r1, #GVPixelFormat_ModeFlags]
        EOR     lr, lr, r11
        TST     lr, #ModeFlag_FullPalette :OR: ModeFlag_64k
        BNE     %BT30
        LDR     lr, [r9, #mode_desc1_format+GVPixelFormat_Log2BPP]
        LDR     r11, [r1, #GVPixelFormat_Log2BPP]
      [ Allow24bpp
        ; If descriptor has log2bpp of 6, downgrade it to 5
        CMP     lr, #6
        MOVEQ   lr, #5
      ]
        TEQ     r11, lr
        BNE     %BT30

        CMP     r2, #-1                 ; If no subclass yet then
        SUBEQ   r2, r7, #4              ;   this is it.

        CMP     r6, #-1                 ; If no frame rate specified
        LDRNE   lr, [r9, #mode_desc1_rate]
        CMPNE   lr, r6                  ;   or frame rate matches then
        MOVEQ   r5, r9                  ;     return this mode.
        STREQ   r3, [sp, #4]
        STREQ   r4, [sp, #8]
        EXIT    EQ                      ; Exit with V clear.
        B       %BT30                   ; Otherwise, continue search.
       

40
        TST     r0, #3                  ; If can't downgrade then error.
        BEQ     %FT60

        TST     r0, #2                  ; Decide between class and colours.
        BNE     %FT50

 [ SortOnPixelShape
        SUBS    r4, r4, #1              ; If we fall off the bottom then
        LDRMIB  r4, class_count         ;   start again at the top.
        SUBMI   r4, r4, #1
        LDR     lr, [sp, #8]
        TEQ     r4, lr                  ; If back where we started then
        BEQ     %FT60                   ;   return error.
 |
        ADDS    r4, r4, r10             ; Step class.
        LDRMI   r4, [sp, #8]            ; If gone -ve then restore r4
        MOVMI   r10, #1                 ;   and start stepping up.
        ADDMI   r4, r4, r10
 ]
        B       %BT10                   ; Keep going until we hit the end.
50
        ADD     r3, r3, r10
        TEQ     r3, #mo_co_colour16     ; If it's 16 colours
        TEQNE   r3, #mo_co_grey256      ;   or 256 greys then
        ADDEQ   r3, r3, r10             ;     need an extra step.
        CMP     r3, #0
        LDRLT   r3, [sp, #4]            ; If gone -ve then restore r3
        MOVLT   r10, #1                 ;   and start stepping up.
        BLT     %BT50
        TEQ     r3, #colours_count      ; If not reached the end of the menu then
        BNE     %BT10                   ;   start search.
60
        ADR     r0, ErrorBlock_Modes_Unsupported
        BL      MsgTrans_ErrorLookup
        EXIT

colours_to_pixelformat
        ASSERT  GVPixelFormat_NColour = 0
        ASSERT  GVPixelFormat_ModeFlags = 4
        ASSERT  GVPixelFormat_Log2BPP = 8
        ASSERT  GVPixelFormat_Size = 12
        DCD     1, 0, 0 ; mo_co_mono
        DCD     3, 0, 1 ; mo_co_grey4
        DCD     15, 0, 2 ; mo_co_grey16
        DCD     15, 0, 2 ; mo_co_colour16
        DCD     255, ModeFlag_FullPalette, 3 ; mo_co_grey256
        DCD     255, ModeFlag_FullPalette, 3 ; mo_co_colour256
        DCD     4095, 0, 4 ; mo_co_4K
        DCD     65535, 0, 4 ; mo_co_32K
        DCD     65535, ModeFlag_64k, 4 ; mo_co_64K
        DCD     -1, 0, 5 ; mo_co_16M

        MakeErrorBlock  Modes_Unsupported


;---------------------------------------------------------------------------
; Mode_ChangeMode
;
;       Out:    r0 corrupted
;
;       Change to the mode which has been selected.
;
Mode_ChangeMode
        ROUT
        Entry   "r1-r6"

        Debug   mode,"Mode_ChangeMode"

        LDR     r2, selected_mode
        CMP     r2, #-1                 ; If not enumerated then
        BEQ     %FT20                   ;   try our best.

        LDRB    r3, selected_colours
10
        TEQNE   r3, #mo_co_grey16
        TEQNE   r3, #mo_co_grey256
        MOVEQ   r1, #f_greylevel
        MOVNE   r1, #0
        BL      Mode_BuildSpecifier
        BLVC    Mode_SetModeString
        BLVC    Mode_WimpCommand
        EXIT
20
        MOV     r0, #4                  ; Don't downgrade, allow non-menu modes.
        LDRB    r3, selected_colours
        LDRB    r4, selected_class
        MOV     r6, #-1                 ; Don't care about frame rate.
        BL      Mode_FindSubClass
        CMP     r5, #-1                 ; If we found something then
        MOVNE   r2, r5                  ;   use it!
        BNE     %BT10

        ADR     r0, ErrorBlock_Modes_Unsupported
        BL      MsgTrans_ErrorLookup
        EXIT


 [ LoadModeFiles

;---------------------------------------------------------------------------
; Mode_LoadFile
;
;       In:     r1 -> name of file to load
;       Out:    r0 corrupted
;
;       Load the named mode file using *LoadModeFile.
;
Mode_LoadFile
        Entry   "r1,r2"

        Debug   mode,"Mode_LoadFile"

        ADR     r0, command_loadmodefile
        ADR     r1, user_data
        MOV     r2, #user_data_size
        BL      Mod_CopyString

        LDR     r0, [sp]
        BL      Mod_CopyString

        ADR     r0, user_data
 [ debugmode :LOR: {FALSE}
        SUB     r0, r0, #4
        MOV     r1, #1
        BL      Mod_ReportError
        ADD     r0, r0, #4
 ]
        SWI     XOS_CLI

        EXIT

command_loadmodefile    DCB     "LoadModeFile ",0
                        ALIGN
 ]


        END
