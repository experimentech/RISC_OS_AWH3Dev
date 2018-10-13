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

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_key_pressed

; In    r1 -> wimp_eventstr
;       [r1, #0]  = window handle
;       [r1, #4]  = icon handle
;       [r1, #8]  = x offset of caret
;       [r1, #12] = y offset of caret
;       [r1, #16] = caret height
;       [r1, #20] = index of caret into string
;       [r1, #24] = key pressed
; Out   much corruption
event_key_pressed Entry

        ; Check if in window we're interested in
        LDR     r3, [r1, #0]
        LDR     r14, h_menuwindow_loc
        TEQ     r14, #0
        LDRNE   r14, [r14]
        CMP     r14, r3
        LDRNE   r5, renaming_chunkaddr
        BNE     %FT06

        ; Pass on if not a Carriage Return (in a writeable icon)
        LDR     r0, [r1, #24]
        MOV     r2, #0          ; No buttons were pressed
        STR     r2, buttonstate ; for reopening menus
        MOV     r4, #0          ; Icon 0 was 'clicked'
        CMP     r0, #CR
        BNE     %FT10
        B       click_menuwindow

06      ; If not the menu window, then is there a writeable icon?
        LDR     r0, [r5,#re_windowhandle] ; if windowhandle is zero,
        CMP     r0, #0                    ; there is currently no writeable icon
        BEQ     %FT30

        ; it a return in the renaming writeable icon?
        LDR     r0, [r1, #24]
        CMP     r0, #CR
        BEQ     %FT07

        ; No? What about an ESCAPE?
        CMP     r0, #&1b
        BNE     %FT10

; ESCAPE pressed in writeable icon

        [ AltRenaming
        BL      remove_rename_writeable
        ]

        B       %FT20

; RETURN pressed in writeable icon

07
        Push    "r1"
        MOV     r0, #-1
        SWI     Wimp_SetCaretPosition       ; Remove the caret

        ; What dirviewer block and file block was the renamed file?
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_dirblock
        LDR     r4, [r1]                  ; dirviewer
        LDR     r5, [r1, #4]              ; fileblock

        STR     r4, sel_dir               ; r4 -> dirblock
        STR     r5, sel_fileblock         ; r5 -> fileblock

        Push    "r14"
        LDR     r2, renaming_chunkaddr    ; copy new filename
        ADD     r2, r2, #re_textstring
        ADR     r1, ms_writeable_leafname
        BL      strcpy
        Pull    "r14"

        LDR     r2, [r4, #d_dirnamestore] ; r2 -> dirname
        STR     r2, sel_dirname

        LDR     r2, [r4, #d_filenames]
        LDR     r3, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r2, r3                ; r2 -> leafname
 |
        ADD     r2, r2, r3, LSR #16       ; r2 -> leafname
 ]
        STR     r2, sel_leafname

        BL      strcmp_sensitive          ; has the filename been altered?
        BNE     %FT08                     ; yep, then skip
        BL      remove_rename_writeable   ; else erase the icon
        B       %FT09                     ; don't perform rename
08
        Push    "r15"                     ; Push pc onto stack for return
        BL      DecodeMenu_File_Rename    ; Carry out rename
        NOP                               ; pre-StrongARM pushed R15+12
09
        Pull    "r1"

10      ; Pass the key on
        LDR     r0, [r1, #24]
15      SWI     XWimp_ProcessKey
20
        EXIT

30	; locate the directory

        LDR     r0, [r1, #0]
        BL      FindDir
        LDR     r0, [r1, #24]
        BNE     %BT15

        ; Set up selection for those operations that need it
        ;  (harmless for others)
        BL      InitSelection

        TEQ     r0, #CR                   ; Enter (Ctrl-M)
        BEQ     key_open
        TEQ     r0, #8                    ; Backspace (Ctrl-H)
        BEQ     key_open_parent
        TEQ     r0, #1                    ; Ctrl-A
        BEQ     DecodeMenu_SelectAll
        TEQ     r0, #6                    ; Ctrl-F
        BEQ     key_toggle_format
 [ AltRenaming
        TEQ     r0, #18                   ; Ctrl-R
        BEQ     key_rename
 ]
        TEQ     r0, #19                   ; Ctrl-S
        BEQ     key_toggle_sort
 [ AddSetDirectory
        TEQ     r0, #23                   ; Ctrl-W
        BEQ     DecodeMenu_SetDir
 ]
        TEQ     r0, #26                   ; Ctrl-Z
        TEQNE   r0, #27                   ; Escape
        BEQ     DecodeMenu_ClearSel

        TEQ     r0, #11                   ; Ctrl-K
        BEQ     key_delete_files

        SUB     r2, r0, #&180
        TEQ     r2, #&A                   ; TAB
        BEQ     key_next_dir
        TEQ     r2, #&1A                  ; Shift-TAB
        BEQ     key_prev_dir
        TEQ     r2, #&22                  ; Ctrl-F2
        BEQ     key_close_dir

        ; Pass on
        B       %BT15

key_open
        ; TODO
        EXIT

key_delete_files
        CMP     r5, #Nowt
        EXIT    EQ
        Push    "r15"
        BL      DecodeMenu_File_Delete
        NOP
        EXIT

key_toggle_sort
        LDRB    r0, [r4, #d_viewmode]
        MOV     r1, #1
        ADD     r0, r1, r0, LSR #dbb_sortmode
        AND     r0, r0, #db_sortmode :SHR: dbb_sortmode
        ADD     r0, r0, #mo_display_sortname
        B       DecodeMenu_Display

key_toggle_format
        LDRB    r0, [r4, #d_viewmode]
        MOV     r1, #1
        ASSERT  dbb_displaymode = 0
        ADD     r0, r1, r0
        AND     r0, r0, #db_displaymode :SHR: dbb_displaymode
        CMP	r0, #3
	MOVHS	r0, #0
        B       DecodeMenu_Display

 [ AltRenaming
key_rename
	LDR	r0, [r1, #0]
        CMP     r5, #Nowt
	EXIT	EQ

	; need bounding box for icon creation
	; r3  = selected file number
	; r4 -> selected dirviewer block
	; r5 -> selected fileinfo block

	STR	r0, windowhandle
	BL	GetFileBox

        BL      always_create_rename_writeable
        EXIT
 ]

key_open_parent
        Push    "r15"
        BL      DecodeMenu_OpenParent
        NOP
        EXIT    VS
        TEQ     r7, #0
        LDRNE   r0, [r7, #d_handle]
        BLNE    AssignFocus
        EXIT

key_close_dir ROUT  ; NOENTRY
        LDR     r1, [r4, #d_link]
        CMP     r1, #Nowt
        LDREQ   r1, ViewerList

        LDR     r0, [r4, #d_handle]
        CMP     r1, r4
        BEQ     %FT10

        ;close and pass focus to window

        BL      close_window_r0
        BLVS    LocalReportError
        LDR     r0, [r1, #d_handle]
        BL      AssignFocus
        EXIT
10      BL      close_window_r0
        EXIT

; pass input focus to the next dir in the list

key_next_dir
        LDR     r1, [r4, #d_link]
        CMP     r1, #Nowt
        LDREQ   r1, ViewerList
        LDR     r0, [r1, #d_handle]
        CMP     r1, r4
        EXIT    EQ
;        BL      AssignFocus
        BL      front
        EXIT

; pass input focus to the previous dir in the list

key_prev_dir ROUT       ; NOENTRY

        ; run down the list until we find a link to the current
        ;   viewer or we hit the end in which case we were first

        LDR     r1, ViewerList
        LDR     r0, [r1, #d_link]
10      CMP     r0, #Nowt
        CMPNE   r0, r4
        MOVNE   r1, r0
        LDRNE   r0, [r0, #d_link]
        BNE     %BT10

        LDR     r0, [r1, #d_handle]
        CMP     r1, r4
        EXIT    EQ
;        BL      AssignFocus
        BL      front
        EXIT

; Assign input focus to the given window
;
; In    r0 = window handle

AssignFocus
        Push    "r0-r5,lr"
        MOV     r1,#-1
        MOV     r2,#0
        MOV     r3,#0
        MOV     r4,#1<<25
        MOV     r5,#-1
        SWI     XWimp_SetCaretPosition
        Pull    "r0-r5,pc"

        END
