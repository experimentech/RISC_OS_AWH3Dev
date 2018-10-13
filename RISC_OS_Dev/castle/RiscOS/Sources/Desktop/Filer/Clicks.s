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
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_mouse_click
; =================

; In    r1 -> wimp_eventstr
;             [r1, #0]  pointer x
;             [r1, #4]          y
;             [r1, #8]  new button state
;             [r1, #12] window handle (-1 if background/-2 if iconbar)
;             [r1, #16] icon handle (-1 if none)
;             [r1, #20] old button state

; Out   all regs may be corrupted - going back to PollWimp

event_mouse_click Entry

        LDMIA   r1, {r0-r4}             ; set absmousex, absmousey, buttonstate
        ADR     r14, mousedata          ;     windowhandle, iconhandle
        STMIA   r14, {r0-r4}            ; (old button state uninteresting)
 [ debug
 DREG r2, "mouse_click: buttonstate ",cc,Word
 DREG r0, ", x ",cc,Integer
 DREG r1, ", y ",cc,Integer
 DREG r3, ", window ",,Integer
 ]
        CMP     r3, #-1                 ; [background = -1]
        EXIT    EQ

        MOV     r0, r3                  ; window handle
        BL      GetWorkAreaCoords       ; x0, y1 := origin of work area where
        STR     x0, windowx             ;           we got the mouse click in
        STR     y1, windowy             ; (cheaper as subroutine !)

        ; Separate processing for dsavebox clicks
        LDR     r14, h_menuwindow_loc
        TEQ     r14, #0
        LDRNE   r14, [r14]
        CMP     r3, r14
        BEQ     click_menuwindow

        LDR     r0, absmousex           ; restore absmousex
; ***^  LDR     r1, absmousey           ; absmousey(r1) ok here still
        SUB     r0, r0, x0              ; make relative to work area origin
        SUB     r1, r1, y1
        STR     r0, relmousex
        STR     r1, relmousey
 [ debug
 DREG r0, "relmouse: x ",cc,Integer
 DREG r1, ", y ",,Integer
 ]

; In    r0,r3/windowhandle = window handle
;       r2/buttonstate     = new button state
;       r4/iconhandle      = icon handle (if there was one)
;       r1                 = not useful
;       windowx,y          = origin of window that mouse clicked in
;       absmousex,y        = abs. coords of pointer
;       relmousex,y        = rel. coords of pointer

        MOV     r0, r3                  ; window handle in r0 as well

        TST     r2, #button_left_10 :OR: button_right_10 ; SELect or EXTtend
        BNE     click_select_type10     ; We get this first (type 10 button)

        TST     r2, #button_left :OR: button_right ; SELect or EXTend?
        BNE     click_select            ; Then either this one or that one ...

        TST     r2, #button_left_drag :OR: button_right_drag ; SEL or EXT drag?
        BNE     click_select_drag

        TST     r2, #button_middle      ; MENU?
        BNE     click_menu

 [ debug
 DLINE "strange click in a window: ignored"
 ]
        EXIT


 [ version >= 113
 |
50 ; Clicked on icon bar

        TST     r2, #button_left :OR: button_right ; SELect or EXTend?
        BNE     click_select_iconbar

        TST     r2, #button_middle      ; menu?
        BNE     click_menu_iconbar

  [ debug
 DLINE "strange click on iconbar: ignored"
  ]
        EXIT
 ]

click_menuwindow        ROUT    ; NOENTRY
        ; Clicked in a menu box
        LDR     r14, type_menuwindow
        CMP     r14, #menuwindow_copysave
        BEQ     click_copysave
        CMP     r14, #menuwindow_newdir
        BEQ     click_newdir
        CMP     r14, #menuwindow_newdir
        BEQ     click_newdir
        CMP     r14, #menuwindow_setaccess
        BEQ     click_setaccess
        EXIT

; .............................................................................
; Menu clicked in one of our windows

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_menu ROUT ; NOENTRY

 [ debugmenu
 DLINE "click_menu"
 ]
        [ AltRenaming
        BL      remove_rename_writeable
        ]

        BL      NobbleMenuSelection     ; Remove previous context sensitive
        EXIT    VS                      ; selection

        BL      FindDir                 ; r4 -> dirviewer block
 [ debugmenu
 BEQ %FT00
 DLINE "click_menu not in a dirviewer: ignored"
00
 ]
        EXIT    NE                      ; [not a dirviewer]

        BL      FindFile
        BNE     %FT30

        Push    "r3-r5"                 ; If any selections exist then

        [ :LNOT: MenuClearsSelection
        LDR     r4, ViewerList          ; don't select object with MENU
        ]

10      CMP     r4, #Nowt               ; VClear
        BEQ     %FA29                   ; [end of dirviewer list]

        LDR     r3, [r4, #d_nfiles]
        TEQ     r3, #0
        BEQ     %FT25                   ; [no files here]

        ADD     r5, r4, #d_headersize   ; Run over all files. VClear

20      LDRB    r14, [r5, #df_state]
        TST     r14, #dfs_selected
        BNE     %FA29                   ; [file selected, so we're in trouble]

        SUBS    r3, r3, #1
        ADDNE   r5, r5, #df_size
        BNE     %BT20                   ; Process next file

25
        [ :LNOT: MenuClearsSelection
        LDR     r4, [r4, #d_link]
        B       %BT10                   ; Process next dirviewer
        ]

29      Pull    "r3-r5"                 ; NE -> other selections exist

        MOVNE   r14, #0                 ; [already got a good selection]
        MOVEQ   r14, #&FF               ; [making context sensitive selection]
        STRB    r14, menu_causedselection

        [ MenuClearsSelection
        BNE     %FT30
        BL      ClearAllSelections
        ]

        LDREQB  r14, [r5, #df_state]    ; Select file if no other selections
        ORREQ   r14, r14, #dfs_selected
        STREQB  r14, [r5, #df_state]
        BLEQ    UpdateFile
        EXIT    VS


30      STR     r4, sel_dir             ; Remember dir where selection is

        LDR     r14, relmousex
        STR     r14, menu_relmousex
        LDR     r14, relmousey
        STR     r14, menu_relmousey

; Menu clicked in one of our dirviewers

        BL      EncodeAndCreateMenu
 [ debugmenu
 DLINE "leaving click_menu"
 ]
        EXIT

 [ version >= 113
 |
; .............................................................................
; Menu clicked on icon bar

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_menu_iconbar ROUT ; NOENTRY

 [ debugmenu
 DREG r4,"click_menu_iconbar: iconhandle "
 ]
        BL      NobbleMenuSelection     ; Remove previous context sensitive
        EXIT    VS                      ; selection

        MOV     r0, r4
        BL      FindIconBarDir
 [ debugmenu
 BEQ %FT00
 DLINE "click_menu_iconbar ignored"
00
 ]
        EXIT    NE                      ; [not a tiny dir]

; Do something wally to it
 [ debugmenu
 DLINE "leaving click_menu_iconbar"
 ]
        EXIT
 ]

; .............................................................................
; SELect or EXTend clicked in one of our dirviewers

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select_type10 ROUT ; NOENTRY

        BL      AssignFocus

 [ debug
 DLINE "click_select_type10"
 ]
        [ AltRenaming
        BL      remove_rename_writeable
        ]

        BL      NobbleMenuSelection     ; Remove previous context sensitive
        EXIT    VS                      ; selection

        BL      FindDir                 ; r4 -> dirviewer block
        EXIT    NE                      ; [not a dirviewer]

        Push    "r2"
        MOV     r2,r4
        BL      ClearAllSelections      ; select or adjust click => clear all selections in other windows
        Pull    "r2"

        BL      FindFile                ; r5 -> fileinfo block, r3 = file no
                                        ; filebox()() set up

 [ debug
 BEQ %FT00
 DLINE "click_select_type10 ignored"
00
 ]
        BNE     %FT70                   ; [no file found, so clear all if sel]


; Select/Deselect file(s) as appropriate

        TST     r2, #button_left_10     ; SELect pressed ?
        BEQ     %FT50                   ; VClear from above, we hope


        [ AltRenaming
; Check if ALT is being pressed

        MOV     r0,#129
        MOV     r1,#253
        MOV     r2,#255
        SWI     XOS_Byte
        CMP     r1,#255
        BNE     %FT08

        BL      create_rename_writeable ; if so, create the writeable icon
        EXIT    EQ                      ; only continue if click wasn't claimed (eg. if outside text bbox)
08
        ]

; SELect pressed on an object:
; - if already selected, ignore
; - if not selected, deselect all others first

        LDRB    r1, [r5, #df_state]     ; Already selected ?
        TST     r1, #dfs_selected
        EXIT    NE                      ; [yes, so ignore]

        MOV     r2, #Nowt               ; Clear 'em all everywhere
        BL      ClearAllSelections
        EXIT    VS


10      ORR     r1, r1, #dfs_selected   ; Select the file
 [ debugsel
 BVS %FT00
 DREG r5,"Selecting file "
00
 ]

20      STRB    r1, [r5, #df_state]     ; ep for below to deselect file


        BL      UpdateFile

        EXIT


; EXTend pressed on an object
; - if already selected, deselect
; - if not selected, select

50      LDRB    r1, [r5, #df_state]     ; Already selected ?
        TST     r1, #dfs_selected
        BEQ     %BT10                   ; [no, so add to selection]

 [ debugsel
 DREG r5,"deselecting file "
 ]
        BIC     r1, r1, #dfs_selected   ; Deselect the file
        B       %BT20


70      TST     r2, #button_left_10

        MOVNE   r2, #Nowt
        BLNE    ClearAllSelections      ; SELect pressed in empty space
        EXIT


; .............................................................................
; SELect or EXTend double-clicked in one of our dirviewers
;   or:
; SELect or EXTend clicked on button in other windows

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select ROUT ; NOENTRY

 [ debug
 DLINE "click_select"
 ]
 [ version >= 113
 |
        LDR     r3, accesssubmenu
        TEQ     r3, r0
        BEQ     %FT50                   ; [clicked in menu access dbox]
 ]

        BL      FindDir                 ; r4 -> dirviewer block
        BLEQ    FindFile                ; r5 -> fileinfo block, r3 = file no
                                        ; filebox()() set up
 [ debug
 BEQ %FT00
 DLINE "click_select ignored"
00
 ]
        EXIT    NE


; Double-clicked on object in dirviewer

; Need some global state left over for when DataOpen bounces ...

 [ debugsel
 DREG r2, "buttonstate for setting dirtoclose "
 ]
        TST     r2, #button_left        ; If EXTend pressed, we we'll want
        MOVEQ   r14, r4                 ; to close this dir
        MOVNE   r14, #Nowt
        STR     r14, dirtoclose         ; Remember for when we get to open/run
                                        ; or get ack'ed

        MOV     r0, #&81                ; Store initiating SHIFT state
        MOV     r1, #&FF                ;
        MOV     r2, #&FF                ;
        SWI     XOS_Byte                ;
        STRB    r1, initshiftstate      ; &FF -> SHIFT depressed

        CMP     r1, #&FF                ; is shift depressed?
        BEQ     %FT07                   ; if so, skip doubleclick-and-hold

        ; check for doubleclick-and-hold
        LDR     r0, dclickhold_delay    ; get dclickhold_delay
        TEQ     r0, #0                  ; if it == 0, ie off?
        BEQ     %FT07                   ; if so, skip doubleclick-and-hold

        ; check if second click is held down long enough
        SWI     XOS_ReadMonotonicTime   ; read monotonic time
        MOV     r14, r0                 ; keep it safe in r14

06
        Push    "r3"                    ; keep r3 safe
        SWI     XOS_Mouse               ; get mouse status
        Pull    "r3"                    ; restore r3
        LDR     r1, buttonstate         ; button initially pressed
        TEQ     r2, r1                  ; is this button still pressed?
        BNE     %FT07                   ; if not, no doubleclick-and-hold

        SWI     XOS_ReadMonotonicTime   ; get monotonic time again
        LDR     r1, dclickhold_delay    ; get dclickhold_delay
        SUB     r0, r0, r14             ; how much time has elapsed
        CMP     r0, r1                  ; is it >= dclickhold_delay?
        BLT     %BT06                   ; if not, go round once more

        ; it is a doubleclick-and-hold, pretend it was a Shift-click
        MOV     r14, #&FF               ; &FF => SHIFT depressed
        STRB    r14, initshiftstate     ; Store initiating SHIFT state

07
        [ AltRenaming
        ; Check if ALT is being pressed
        MOV     r0,#129
        MOV     r1,#253
        MOV     r2,#255
        SWI     XOS_Byte
        CMP     r1,#255
        BNE     %FT08

        BL      create_rename_writeable ; if so, create the writeable icon
        EXIT    EQ                      ; only continue if click wasn't claimed (eg. if outside text bbox)
08
        ]

; Deselect this file (if not already done so by EXTend-double-click)

        LDRB    r1, [r5, #df_state]     ; Already deselected ?
        TST     r1, #dfs_selected
        BICNE   r1, r1, #dfs_selected   ; Deselect the file if not
        STRNEB  r1, [r5, #df_state]
        BLNE    UpdateFile
        EXIT    VS


; Open subdirectory/run file from dirviewer

 [ version < 139
        LDR     r14, [r4, #d_filesystem] ; This will NOT get any chance to be
        STR     r14, setplusfilesystem   ; changed as messages are highest prio
                                         ; events (unlike drag, where we + the
                                         ; rest of the world get nulls etc.)
 ]
 [ debugsel
 DREG r14, "remember set + filesystem "
 ]
        STR     r4, sel_dir

        LDR     r1, [r4, #d_dirname]
        LDR     r14, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r1, r14             ; r2 -> leafname
 |
        ADD     r2, r1, r14, LSR #16    ; r2 -> leafname
 ]
        LDR     r1, [r4, #d_dirnamestore]

        BL      FindFileType            ; r3 := file type
      [ version >= 143
        LDRB    r14,[r5,#df_type]
        TEQ     r14,#dft_partition
        MOVEQ   r3,#filetype_directory
      ]

        CMP     r3, #filetype_directory
 [ ShowOpenDirs
        BNE     %FT00

        LDRB    R14, initshiftstate
        CMP     R14, #&FF                               ; If SHIFT not pressed then
        BNE     %FT01                                   ;   just open it.
        LDRB    R14, [R5, #df_state]
        TST     R14, #dfs_opened                        ; If directory not open then
        BEQ     %FT01                                   ;   go and open it.

        ;ADR     R1, dirnamebuffer                       ; Otherwise, copy directory name,
        LDR     R1, dirnamebuffer                       ; Otherwise, copy directory name,
        LDR     R2, [R4, #d_dirname]
        BL      strcpy
        LDR     R2, [R4, #d_filenames]                  ;   append leaf name
        LDR     R14, [R5, #df_fileptr]
 [ not_16bit_offsets
        ADD     R2, R2, R14
 |
        ADD     R2, R2, R14, LSR #16
 ]
        BL      AppendLeafnameToDirname
        MOV     R2, #0                                  ;   and close the open directory.
        BL      Queue_CloseDir_Request_To_Self
        BLVC    CloseInitiatingDir
        EXIT
00
 |
        BEQ     %FT01
 ]
        LDRB    r14, initshiftstate
        CMP     r14, #&FF
        BNE     %FT01
        CMP     r3, #filetype_application
        MOVEQ   r3, #filetype_directory ; SHIFTED app => directory
        LDRNE   r3, =&FFF               ; SHIFTed file => text file
01
        MOV     r4, #0                  ; broadcast to all and sundry
        MOV     r5, #0                  ; r5(ihandle) irrelevant on broadcast
        BL      SendDataOpenMessage
 [ debugsel
 DLINE "leaving click_select"
 ]
        EXIT


 [ version >= 113
 |
50 ; Copy selected access rights onto object(s)

        CMP     r4, #0                  ; Only clicks on Icon 0 'Update' matter
 [ debugsel
 BEQ %FT00
 DLINE "click_select ignored: not 'Update' icon"
00
 ]
        EXIT    NE

; Read new access state back from icons

        MOV     r6, #0                  ; No access at all
        MOV     r2, #1                  ; Icon 1 == Locked bit
        BL      GetIconState            ; r3 = window handle still
        ORRNE   r6, r6, #locked_attribute
        BVS     %FT96                   ; [error, kill menu tree]

 [ :LNOT: actionwind
        LDRB    r7, access_objecttype   ; If a dir. no more attributes to read
        TEQ     r7, #dft_file           ; Indeed, no more icons!
        BNE     %FT60
 ]

        MOVVC   r2, #2                  ; Icon 2
        BLVC    GetIconState
        ORRNE   r6, r6, #read_attribute
        MOVVC   r2, #3                  ; Icon 3
        BLVC    GetIconState
        ORRNE   r6, r6, #write_attribute
        MOVVC   r2, #4                  ; Icon 4
        BLVC    GetIconState
        ORRNE   r6, r6, #public_read_attribute
        MOVVC   r2, #5                  ; Icon 5
        BLVC    GetIconState
        ORRNE   r6, r6, #public_write_attribute
 [ actionwind
        MOVVC   r2, #6                  ; Icon 6
        BLVC    GetIconState
        MOVNE   r7, #Action_OptionRecurse
        MOVEQ   r7, #0
 ]
        BVS     %FT96                   ; [error, kill menu tree]

      [ debugaccess
        DREG    r6,"New access is "
      ]


60      LDR     r0, sel_whandle         ; If this has changed, we can do nowt
        TEQ     r0, #Nowt
 [ debugsel
 BNE %FT00
 DLINE "Selection handle has been zapped in the background. Goodbye"
00
 ]
        BEQ     %FT95                   ; We may have to kill menu tree though!

        BL      FindDir
        BLEQ    InitSelection
        BNE     %FT96                   ; [Waarg! Dir/Sel vanished, kill tree]

 [ actionwind
        STR     r6, userdata
      [ version >= 138                  ; Check if configuration calls for filer_action
       [ debugaccess
        DLINE "Check CMOS ********************"
       ]
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
      [ version >= 113
        MOV     r0, #Filer_Action_Memory_Others
      ]
        BL      StartActionWindow
      ]
        BVS     %FT70
        TEQ     r0, #0
        BEQ     %FT70
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT70
        BL      SendSelectedFiles
        BVS     %FT70
        MOV     r1, #Action_Setting_Access
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        ORR     r2, r2, r7
        ADR     r3, userdata
        MOV     r4, #4
        SWI     XFilerAction_SendStartOperation
        B       %FT95
70      ;
        CLRV
 ]

 [ debugaccess
        DLINE   "Set access by steam"
 ]

90      TEQ     r5, #Nowt
        BEQ     %FT95                   ; [finished]

 [ debugaccess
        DLINE   "Selection found"
 ]

        LDRB    r14, [r5, #df_type]     ; Only apply to right object types
        TEQ     r14, r7
;        BNE     %FT94

 [ clearsel_file_access
        BL      ClearSelectedItem       ; Only clear selected items we're using
                                        ; Can do this here; not a CommandWindow
 ]
        ;wsaddr  r1, dirnamebuffer, VC
        LDRVC   r1, dirnamebuffer
        LDRVC   r2, sel_dirname
        BLVC    strcpy_excludingspaces
        LDRVC   r2, sel_leafname
        BLVC    AppendLeafnameToDirname

        MOVVC   r0, #OSFile_WriteAttr
        MOVVC   r5, r6                  ; THIS IS NOT GOOD (RM)
 [ debugmenu
 BVS %FT00
 DSTRING r1,"Setting access on ",cc
 DREG r5, "to "
00
 ]
        SWIVC   XOS_File
        BVS     %FT96                   ; [error, kill menu tree]

94      BL      GetSelection
        B       %BT90


; Normal exit point for access dbox click. Things are quite different if
; we click in a dbox hanging off menu tree ... Neil assumes menu tree
; staying up unless WE kill it.

95      LDRB    r14, menu_reopen
        TEQ     r14, #0
        LDRNE   r14, buttonstate        ; Trying to keep menu tree open ?
        TSTNE   r14, #button_right
        BEQ     %FT96

        BL      RecreateMenu
 [ debugmenu
 DLINE "leaving click_select"
 ]
        EXIT


96      BL      NobbleMenuTree          ; WE have to kill menu tree

        BL      NobbleMenuSelection     ; Remove context sensitive selection
 [ debugmenu
 DLINE "leaving click_select"
 ]
        EXIT                            ; Accumulates V, r0 preserving
 ]

 [ version >= 113
 |
; .............................................................................
; SELect or EXTend clicked on icon bar

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select_iconbar ROUT ; NOENTRY

 [ debug
 DREG r4,"click_select_iconbar: iconhandle "
 ]
        MOV     r0, r4
        BL      FindIconBarDir
 [ debug
 BEQ %FT00
 DLINE "click_select_iconbar ignored"
00
 ]
        EXIT    NE                      ; [not a tiny dir]

        MOV     r7, r4
        LDR     r3, initwindowx         ; Open at default coords
        LDR     r4, initwindowy
        BL      MakeDirWindow
 [ debug
 DLINE "leaving click_select_iconbar"
 ]
        EXIT
 ]

; .............................................................................
; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select_drag ROUT ; NOENTRY

 [ debug
 DLINE "click_select_drag"
 ]
        BL      FindDir                 ; r4 -> dirviewer block
        BLEQ    FindFile                ; r5 -> fileinfo block, r3 = file no
                                        ; filebox()() set up




 [ debug
 BEQ %FT00
 DLINE "click_select_drag ignored"
00
 ]
 [ version >= 114
        BNE     %FT50                   ; Not dragging a file, so drag around many
 |
        EXIT    NE                      ; [not dragging a file]
 ]


 [ AltRenaming
; Check if we're trying to drag the writeable icon - if so, ignore.
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_windowhandle
        LDR     r0, [r1]                ; load the windowhandle of the window which contains the renaming writeable icon
        CMP     r0, #0                  ; if zero, this is currently no writeable icon
        BEQ     %FT07                   ; so continue with drag

        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_fileblock
        LDR     r0, [r1]                ; load the address of the fileblock for the writeable icon
        CMP     r0, r5                  ; if it matches the icon we're trying to drag...
        EXIT    EQ                      ; then exit - don't do drag
07
 ]

; Dragging a selection

 [ debug
 DREG r2, "buttonstate for setting dirtoclose "
 ]
        TST     r2, #button_left_drag   ; If EXTend pressed, we we'll want
        MOVEQ   r14, r4                 ; to close this dir
        MOVNE   r14, #Nowt
        STR     r14, dirtoclose         ; Remember for when we get to drop

        MOV     r0, #&81                ; Store initiating SHIFT state
        MOV     r1, #&FF
        MOV     r2, #&FF
        SWI     XOS_Byte
        STRB    r1, initshiftstate      ; &FF -> SHIFT depressed

; Select this file (if it's been deselected by EXTend-drag)

        LDRB    r1, [r5, #df_state]     ; Still selected ?
        TST     r1, #dfs_selected
        ORREQ   r1, r1, #dfs_selected   ; Reselect the file if not
        STREQB  r1, [r5, #df_state]
        BLEQ    UpdateFile
        EXIT    VS

 [ DragASprite
        BL      GetBigIconName
        Push    "r2"
 ]

        LDR     r0, [r4, #d_handle]     ; Remember this window handle
        STR     r0, sel_whandle

        BL      InitSelection
        EXIT    NE                      ; EXTend-drag may have deselected file!
                                        ; Surely this can't happen says SKS
                                        ; see above !!!

        ; Note that we're starting a file drag
        MOV     r14, #drag_file
        STRB    r14, drag_type

; Work out bbox for icons to drag

        BL      GetFileBox
        ADR     r14, filebox1
        LDMIA   r14, {x0, y0, x1, y1}   ; relative to work area origin

 [ version >= 117
        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        TEQ     r14, #db_dm_fullinfo
        LDREQ   x1, filebox3 + fb_x1
 ]

 [ DragASprite
        MOV     r11,#0
 ]
10 ; Loop making bbox bigger!
 [ DragASprite
        ADD     r11,r11,#1
 ]
 [ debug
 DREG x0,"bbox now: ",cc,Integer
 DREG y0,", ",cc,Integer
 DREG x1,", ",cc,Integer
 DREG y1,", ",,Integer
 ]
        BL      GetSelection
        TEQ     r5, #Nowt
        BEQ     %FT20

 [ debug
 DREG r3,"file number "
 DREG r4,"dirviewer^  "
 DREG r5,"fileblock^  "
 ]
        BL      GetFileBox
 [ version >= 117
        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        TEQ     r14, #db_dm_fullinfo
 ]
        ADR     r14, filebox1
        LDMIA   r14, {cx0, cy0, cx1, cy1} ; relative to work area origin
 [ version >= 117
        LDREQ   cx1, filebox3 + fb_x1
 ]
 [ debug
 DREG cx0,"merging bbox with ",cc,Integer
 DREG cy0,", ",cc,Integer
 DREG cx1,", ",cc,Integer
 DREG cy1,", ",,Integer
 ]

        min     x0, cx0                 ; add in to bbox
        min     y0, cy0
        max     x1, cx1
        max     y1, cy1
        B       %BA10


20      LDR     r14, windowx            ; add in work area origin (x0,y1)
        ADD     cx0, x0, r14
        ADD     cx1, x1, r14
        LDR     r14, windowy
        ADD     cy0, y0, r14
        ADD     cy1, y1, r14

        SUB     cx0, cx0, #bbox_x_enlarge ; prettify: enlarge bbox by an amount
        ADD     cx1, cx1, #bbox_x_enlarge
        SUB     cy0, cy0, #bbox_y_enlarge
        ADD     cy1, cy1, #bbox_y_enlarge

 [ DragASprite
        CMP     r11,#1                          ; Set r11->sprite name
        ADRNE   r11,package
        STRNE   r11,[sp]
        Pull    "r11"
 [ debug
 DSTRING r11,"Drag icon name: "
 ]
        MOV     r10, #1                         ; Centre on mouse coords.
 ]

        B       start_drag

package DCB     "package",0
        ALIGN

 [ version >= 114
50 ; Start drag around many objects
        ; Store these away for when the drag finishes
        ; This is safe as a click at the same location will have
        ; happened before hand
        STR     r0, sel_whandle
        STR     r4, sel_dir

        SUB     sp, sp, #40
        LDR     r0, windowhandle
        STR     r0, [sp]
        MOV     r1, sp
        SWI     XWimp_GetWindowState
        ADDVS   sp, sp, #40
        EXIT    VS

        ; Move the window visible area to be the bounding box
        ADD     r0, sp, #4
        LDMIA   r0, {r1-r4}
        ADD     r0, sp, #24
        STMIA   r0, {r1-r4}

        ; Start rectangle is the start point of the drag
      [ {TRUE}
        MOV     r0, #4
        MOV     r1, #5
        MOV     r2, #-1
        Push    "r0-r2"
        SUB     sp, sp, #8
        ADD     r0, sp, #8
        MOV     r1, sp
        SWI     XOS_ReadVduVariables
        Pull    "r2,r3"
        LDR     r0, absmousex
        LDR     r1, absmousey
        ADD     sp, sp, #12
        MOV     lr, #1
        MOV     r2, lr, LSL r2                  ; pixel width
        MOV     r3, lr, LSL r3                  ; pixel height
        ADD     r2, r0, r2                      ; make exclusive!
        ADD     r3, r1, r3
        ADD     lr, sp, #8
        STMIA   lr, {r0-r3}
      |
        LDR     r1, absmousex
        LDR     r2, absmousey
        ADD     r0, sp, #8
        STMIA   r0, {r1-r2}
        ADD     r0, sp, #16
        STMIA   r0, {r1-r2}
      ]

        ; rubber rotating dash
        MOV     r1, #6
        STR     r1, [sp, #4]

        MOV     r1, sp

        [ autoscroll
        LDR     r2, taskword                    ; 'TASK'
        MOV     r3, #3                          ; allow pointer out of window workspace
        MOV     r0, #&7F00                      ; y max
        STR     r0, [r1, #36]
        MOV     r0, #&8000                      ; y min
        STR     r0, [r1, #28]
        ]

        SWI     XWimp_DragBox
        ADD     sp, sp, #40
        EXIT    VS

        [ autoscroll
        BL      start_autoscroll                ; start autoscrolling.
        ]

        ; Notify ourselves which sort of drag has started
        LDR     r1, buttonstate
        TST     r1, #button_left_drag
        MOVNE   r1, #drag_selectmany
        MOVEQ   r1, #drag_adjustmany
        STRB    r1, drag_type
        EXIT
 ]

 [ autoscroll
taskword DCB "TASK"
 ]

click_copysave  ROUT    ; NOENTRY
        CMP     r4, #0          ; OK icon
        BEQ     click_copysave_click

        ; Note that the drag is for saving display
        MOV     r14, #drag_copysave
        STRB    r14, drag_type

        CMP     r4, #2          ; Filetype icon
        BEQ     click_savegeneral_drag
        EXIT

click_newdir  ROUT    ; NOENTRY
        CMP     r4, #0          ; OK icon
        BEQ     click_newdir_click

        ; Note that the drag is for saving display
        MOV     r14, #drag_newdirsave
        STRB    r14, drag_type

        CMP     r4, #2          ; Filetype icon
        BEQ     click_savegeneral_drag
        EXIT

click_setaccess ROUT    ; NOENTRY

        ; Check OK button was pressed
        TEQ     r4, #0  ; OK box
        BEQ     DoSetAccess

        TEQ     r4, #6          ; Recurse button
        EXIT    NE

        ; Process the Recursive button - its really a toggle always button.
        LDR     r3, h_menuwindow_loc
        LDR     r3, [r3]
        MOV     r2, #6          ; Recurse button
        BL      GetIconState
        MOV     r4, #is_inverted        ; We're going to toggle selected bit
        MOV     r5, #0
        MOV     r2, #6          ; Recurse button again
        BL      SetIconState

        EXIT

DoSetAccess
; Copy selected access rights onto object(s)

        ; Get the icon state of the recurse button, if selected we do it recursively.
        LDR     r3, h_menuwindow_loc
        LDR     r3, [r3]
        MOV     r2, #6          ; Recurse button
        BL      GetIconState
        EXIT    VS

        MOVNE   r7, #Action_OptionRecurse
        MOVEQ   r7, #0

; Read new access state back from icons
        LDR     r3, h_menuwindow_loc
        LDR     r3, [r3]
        LDR     r6, =&ffff0000          ; No change to access at all
        MOV     r2, #7                  ; Icon 7 == Lockclear bit
        BL      GetIconState
        BVS     %FT96
        BICNE   r6, r6, #locked_attribute :SHL: 16
        MOV     r2, #8                  ; Icon 8 == readclear bit
        BL      GetIconState
        BVS     %FT96
        BICNE   r6, r6, #read_attribute :SHL:16
        MOV     r2, #9                  ; Icon 9 == writeclear bit
        BL      GetIconState
        BVS     %FT96
        BICNE   r6, r6, #write_attribute :SHL: 16
        MOV     r2, #10                 ; Icon 10 == public read clear bit
        BL      GetIconState
        BVS     %FT96
        BICNE   r6, r6, #public_read_attribute :SHL: 16
        MOV     r2, #11                 ; Icon 11 == public write clear bit
        BL      GetIconState
        BVS     %FT96
        BICNE   r6, r6, #public_write_attribute :SHL: 16
        MOV     r2, #1                  ; Icon 1 == Lockset bit
        BL      GetIconState
        BVS     %FT96
        ORRNE   r6, r6, #locked_attribute
        BICNE   r6, r6, #locked_attribute :SHL: 16
        MOV     r2, #2                  ; Icon 2 == readset bit
        BL      GetIconState
        BVS     %FT96
        ORRNE   r6, r6, #read_attribute
        BICNE   r6, r6, #read_attribute :SHL:16
        MOV     r2, #3                  ; Icon 3 == writeset bit
        BL      GetIconState
        BVS     %FT96
        ORRNE   r6, r6, #write_attribute
        BICNE   r6, r6, #write_attribute :SHL: 16
        MOV     r2, #4                  ; Icon 4 == public read set bit
        BL      GetIconState
        BVS     %FT96
        ORRNE   r6, r6, #public_read_attribute
        BICNE   r6, r6, #public_read_attribute :SHL: 16
        MOV     r2, #5                 ; Icon 5 == public write set bit
        BL      GetIconState
        BVS     %FT96
        ORRNE   r6, r6, #public_write_attribute
        BICNE   r6, r6, #public_write_attribute :SHL: 16


        ; Having sorted out what's to be done, do it....


        LDR     r0, sel_whandle         ; If this has changed, we can do nowt
        TEQ     r0, #Nowt
        BEQ     %FT95                   ; We may have to kill menu tree though!

        BL      FindDir
        BLEQ    InitSelection
        BNE     %FT96                   ; [Waarg! Dir/Sel vanished, kill tree]

        STR     r6, userdata
      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_Others
        BLEQ    StartActionWindow
      |
        MOV     r0, #Filer_Action_Memory_Others
        BL      StartActionWindow
      ]
        BVS     %FT70
        TEQ     r0, #0
        BEQ     %FT70
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT70
        BL      SendSelectedFiles
        BVS     %FT70
        MOV     r1, #Action_Setting_Access
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        ORR     r2, r2, r7
        ADR     r3, userdata
        MOV     r4, #4
        SWI     XFilerAction_SendStartOperation
        B       %FT95
70      ;
        CLRV

90      ; Filer Action window failed, do it by steam
        TEQ     r5, #Nowt
        BEQ     %FT95                   ; [finished]

        LDRB    r14, [r5, #df_type]     ; Only apply to right object types
        TEQ     r14, r7
;        BNE     %FT94

 [ clearsel_file_access
        BL      ClearSelectedItem       ; Only clear selected items we're using
                                        ; Can do this here; not a CommandWindow
 ]
        ;wsaddr  r1, dirnamebuffer, VC
        LDRVC   r1, dirnamebuffer
        LDRVC   r2, sel_dirname
        BLVC    strcpy_excludingspaces
        LDRVC   r2, sel_leafname
        BLVC    AppendLeafnameToDirname


      [ version >= 148
        Push    "r1-r4"
        MOVVC   r0, #OSFile_ReadInfo
        SWIVC   XOS_File
        Pull    "r1-r4"                 ; r5 = old access setting.

 [ debugaccess
        DREG    r5,"Old access is "
        DREG    r6,"Mask "
 ]
      ]

        MOVVC   r0, #OSFile_WriteAttr
      [ version >= 148
        MOVVC   r14,r6,LSR #16          ; Bits to ignore
        ANDVC   r5,r5,r14               ; Correct in bits to ignore, 0 in others
        BICVC   r14,r6,r14              ; Bottom 16 bits are access to set (Clear all bits to ignore)
        MOVVC   r14,r14,ASL #16
        EORVC   r5,r5,r14,LSR #16
 [ debugaccess
        DREG    r5,"New access is "
 ]
      |
        MOVVC   r5, r6                  ; THIS IS NOT GOOD (RM)
      ]
        SWIVC   XOS_File
        BVS     %FT96                   ; [error, kill menu tree]

94      BL      GetSelection
        B       %BT90

95      ; Its simple to recreate the menus on an upcall

        ; Stuff the menu tree if the right button wasn't the one used.
        LDR     r14, buttonstate
        TST     r14, #button_right
        BEQ     %FT96

        EXIT

96      BL      NobbleMenuTree          ; WE have to kill menu tree

        BL      NobbleMenuSelection     ; Remove context sensitive selection
        EXIT                            ; Accumulates V, r0 preserving


click_newdir_click    ROUT    ; NOENTRY

        BL      ClearAllSelections
        ;BL      NobbleMenuTree

        ADR     r1, userdata
        ADR     r2, cdir_command
        BL      strcpy

        LDR     r1, newdirbox_text
        BL      FindLeafname
        CMP     r1, r2
        BEQ     %FT08

        MOV     r2, r1
        ADR     r1, userdata
        BL      strcat_excludingspaces
        B       %FT10
08
        ADR     r1, userdata
        LDR     r2, sel_dirname
        BL      strcat_excludingspaces
        LDR     r2, newdirbox_text
        BL      AppendLeafnameToDirname
10
        MOV     r0, r1
        BL      DoOSCLIInBox

        LDR     r14, buttonstate        ; Trying to keep menu tree open ?
        TST     r14, #button_right
        EXIT    NE

        BL      NobbleMenuTree

        EXIT

cdir_command
        DCB     "CDir ", 0              ; Needs space
        ALIGN

click_copysave_click    ROUT    ; NOENTRY

        LDR     r0, sel_whandle         ; If this has changed, we can do nowt
        TEQ     r0, #Nowt
        BEQ     %FT96                   ; Nobble the menu
        BL      FindDir
        BNE     %FT96                   ; Dir vanished - nobble the menu tree
        BL      InitSelection           ; Doesn't matter if no selection here

      [ version >= 138                  ; Check if configuration calls for filer_action
        MOV     R0,#&A1
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   R2,#0
        TST     R2,#InteractiveCopyCMOSBit
        MOVNE   r0,#0
        MOVEQ   r0, #Filer_Action_Memory_CopyRename
        BLEQ    StartActionWindow
      |
        MOV     r0, #Filer_Action_Memory_CopyRename
        BL      StartActionWindow
      ]
        BVS     %FT01
        TEQ     r0, #0
        BEQ     %FT01
        LDR     r1, sel_dirname
        SWI     XFilerAction_SendSelectedDirectory
        BVS     %FT01
        BL      SendSelectedFiles
        BVS     %FT01
        LDR     r1, csavebox_text
        BL      strlen
        ADD     r4, r3, #1
        MOV     r3, r1
        MOV     r1, #Action_CopyLocal
        [ OptionsAreInRAM
        LDRB    r2, fileraction_options
        |
        BL      ExtractCMOSOptions
        ]
        SWI     XFilerAction_SendStartOperation
        B       %FT99

01      ;
        CLRV

        addr    r2, star_copy_prefix    ; 'Copy menudir.leafname menudir.newname opt1 opt2'
        BL      PutSelNamesInBuffer
        addr    r2, aspace              ; +space
        BL      strcat

        ; Only stick the dirname on the front of a leaf-only string.
        MOV     r0, r1
        LDR     r1, csavebox_text
        BL      FindLeafname
        TEQ     r1, r2                  ; EQ => just a leaf
        MOV     r1, r0
        LDREQ   r2, sel_dirname         ; +dirname (if necessary)
        BLEQ    strcat_excludingspaces
        LDR     r2, csavebox_text
        BLEQ    AppendLeafnameToDirname ; sticks a '.' on the end of dirs if necessary
        BLNE    strcat

        addr    r2, star_copy_postfix   ; +static options
        BL      strcat
        addr    r2, copydrag_postfix    ; +dynamic options
        BL      strcat
        BL      AppendConfirmVerboseForceAndNewer

        MOV     r0, r1
        addr    r1, copy_commandtitle
        BL      DoOSCLIInBoxLookup      ; SMC: look up command window title

99      ;
  [ clearsel_file_copy
        MOV     r2, #Nowt
                                        ; That may force a recache of this dir
                                        ; so we may as well ... >>>a186<<<
        BL      ClearAllSelections      ; Remove all selections
  ]


; Normal exit point for copysave dbox click. Things are quite different if
; we click in a dbox hanging off menu tree ... Neil assumes menu tree
; staying up unless WE kill it.
        LDR     r14, buttonstate        ; Trying to keep menu tree open ?
        TST     r14, #button_right
        BEQ     %FT96

        ; Don't recreate menu selection - it won't be correct and also causes
        ; the access box to be permanently closed for this menu up.
        EXIT

        ; Nobble the menu - right button wasn't used
96
        BL      NobbleMenuTree          ; WE have to kill menu tree
        EXIT                            ; Accumulates V, r0 preserving


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; click/drag on obey icon in display save box
click_savegeneral_drag ROUT ; NOENTRY
        ; Record starting button state
        STR     r2, init_buttonstate


        ; Get original location of save icon relative to window
        LDR     r14, csavebox_ptr
        LDR     cx0, [r14, #w_icons + 2*i_size + i_bbx0]
        LDR     cx1, [r14, #w_icons + 2*i_size + i_bbx1]
        LDR     cy0, [r14, #w_icons + 2*i_size + i_bby0]
        LDR     cy1, [r14, #w_icons + 2*i_size + i_bby1]
        ; Offset by window position to get actual position on screen
        LDR     r14, windowx
        ADD     cx0, cx0, r14
        ADD     cx1, cx1, r14
        LDR     r14, windowy
        ADD     cy0, cy0, r14
        ADD     cy1, cy1, r14

 [      DragASprite

        LDRB    r10, drag_type
        CMP     r10, #drag_newdirsave
        LDREQ   r11, newdirbox_ptr
        LDRNE   r11, csavebox_ptr
        ADDEQ   r11, r11, #newdirboxiconname_offset
        ADDNE   r11, r11, #saveboxiconname_offset


        MOV     r10,#0                  ; Don't centre on mouse coords
        ;LDR     r11,csavebox_ptr
        ;ADD     r11,r11,#saveboxiconname_offset
 ]
        B       start_drag


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Start a all-screen drag of box {cx0, cx1, cy0, cy1}
start_drag ROUT ; NOENTRY

; Have to fudge limit coords such that drag box can go off-screen, but pointer
; constrained to screen (and not some smaller part of it)

        LDR     x0, absmousex          ; Where mouse was clicked
        LDR     y0, absmousey

 [ DragASprite
        Push    "r0-r2"
        MOV     r0,#&A1
        MOV     r1,#FileSwitchCMOS
        SWI     XOS_Byte
        MOVVS   r2,#0
        TST     r2,#DragASpriteCMOSBit
        Pull    "r0-r2"
        BEQ     %FT60

      [ :LNOT: ursuladragasprite
        ; Centre on mouse coords if required
        CMP     r10,#0
        SUBNE   x1,cx1,cx0
        SUBNE   y1,cy1,cy0
        SUBNE   cx0,x0,x1,LSR#1
        ADDNE   cx1,cx0,x1
        SUBNE   cy0,y0,y1,LSR#1
        ADDNE   cy1,cy0,y1
      ]

        Push    "cx0, cy0, cx1, cy1"
        MOV     r0, #DS_HJustify_Centre :OR: DS_VJustify_Centre :OR: DS_BoundTo_Screen :OR: DS_Bound_Pointer
      [ ursuladragasprite
        ORR     r0, r0, #DS_DropShadow_Present :OR: DS_SpriteAtPointer
      |
        ORR     r0, r0, #DS_DropShadow_Present
      ]
        MOV     r1, #1                  ; Wimp sprite area
        MOV     r2,r11
        MOV     r3, sp
        SWI     XDragASprite_Start
        ADD     sp, sp, #4*4
        EXIT
 ]
60
        LDR     x1, xwindsize          ; rhs of screen
        ADD     x1, x1, cx1
        SUB     x1, x1, x0             ; allow rhs slop

        LDR     y1, ywindsize          ; top of screen
        ADD     y1, y1, cy1
        SUB     y1, y1, y0             ; allow top slop

        SUB     x0, cx0, x0            ; allow lhs slop

        SUB     y0, cy0, y0            ; allow bottom slop

        Push    "cx0, cy0, cx1, cy1, x0, y0, x1, y1"

        LDR     r0, windowhandle
        MOV     r1, #5                  ; user drag box - fixed size
        Push    "r0, r1"

        MOV     r1, sp                  ; point at frame
        SWI     XWimp_DragBox

        ADD     sp, sp, #4*10           ; free frame
        EXIT


 [ autoscroll
start_autoscroll Entry "r0-r2"

        SUB     sp, sp, #32
        MOV     r1, sp
        LDR     r0, windowhandle
        STR     r0, [r1]
        MOV     r0, #12                 ; pause zone
        STR     r0, [r1, #4]
        STR     r0, [r1, #8]
        STR     r0, [r1, #12]
        STR     r0, [r1, #16]
        MOV     r0, #0                  ; pause duration
        STR     r0, [r1, #20]
        MOV     r0, #1                  ; use Wimp pointer shape routine
        STR     r0, [r1, #24]
        MOV     r0, #2                  ; vertical scrolling only
        SWI     XWimp_AutoScroll
        ADD     sp, sp, #32
        EXIT

  ]



        END
