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
 [ AltRenaming

wr_filename_validation    DCB  "s;pptr_write;A~ .:*#$&@^%\\|",34,0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; create_rename_writeable
; =======================
;
; Create the writeable icon (if mouse click is within text bounding box)
;
; In:  r4 -> directory block
;      r5 -> file block
;
; Out: EQ - click was claimed
;      NE - click not claimed

create_rename_writeable
        Entry   "r0-r12"

        MOV     r8, #0                          ; Zero -> use mouse pos

01
        ; Check if filesystem is read-only (eg. ROM), in which case rename not allowed.
        LDR     r2, [r4, #d_filesystem]
        TST     r2, #fod_readonly
        BNE     %FT08

        ; store dirviewer block and fileinfo block (so we know what to rename later)
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_dirblock
        STR     r4, [r1]
        STR     r5, [r1, #4]

        ; Copy the filename into our indirected area
        LDR     r1, [r4, #d_filenames]
        LDR     r6, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r1, r6                      ; r2 -> filename (null-terminated)
 |
        ADD     r2, r1, r6, LSR #16             ; r2 -> filename (null-terminated)
 ]
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_textstring          ; r1 -> destination
        BL      strcpy                          ; to the string copy

        LDR     r10, renaming_chunkaddr         ; Where is the icon data for our writeable icon?
        ADD     r10, r10, #re_createiconblock

        LDR     r0, windowhandle                ; Store the window handle in the first word of the
        STR     r0, [r10]                       ; block which will be passed to Wimp_CreateIcon
        ADD     r9, r10, #4                     ; make R9 the location of the icon data

        LDRB    r5, [r4, #d_viewmode]           ; load r5 with the display mode bit
        AND     r5, r5, #db_displaymode         ; (use it later)

        ADR     r0, filebox1                    ; load the bounding box for the icon clicked on
        LDMIA   r0, {r1, r2, r3, r4}

        CMP     r5, #db_dm_largeicon            ; is this a large icon
        ADDNE   r1, r1, #40                     ; no, then decrease bounding box x
        SUB     r2, r2, #2
        MOV     r4, r2                          ; Decrease the vertical bound to take the
        ADD     r4, r4, #32                     ;     writeable icon

        Push    "r0-r3"                         ; Keep r0 - r3
        MOV     r0, #-1
        MOV     r1, #5
        SWI     XOS_ReadModeVariable             ; Read the y eigen factor
        MOVCS   r2, #1

        MOV     r0, #1
        MOV     r1, r0, LSL r2

        MOV     r0, #4
;        MUL     r7, r0, r1                      ; Adjust the size of the writeable icon according
;        ADD     r4, r4, r7                      ;     to the y eigenvalue
        MLA     r4, r0, r1, r4
        Pull    "r0-r3"                         ; Restore r0 - r3

        TEQ     r8, #0
        STRNE   r3, relmousex                   ; Pretend click was on right edge of writable
        STRNE   r4, relmousey

        LDR     r6, relmousex                   ; load mouse x relative to window origin in r6
        LDR     r7, relmousey                   ; load mouse y relative to window origin in r6
        CMP     r6, r1                          ; compare x with left hand extreme of bouding box
        BLT     %FT08                           ; if less, then ignore click
        CMP     r6, r3                          ; compare x with right hand extreme of bounding box
        BGT     %FT08
        CMP     r7, r2                          ; compare y with bottom extreme of bounding box
        BLT     %FT08
        CMP     r7, r4                          ; compare y with top extreme
        BGT     %FT08

        STMIA   r9, {r1, r2, r3, r4}            ; store bounding box in icon data

        LDR     r0, windowhandle                ; put window handle in r0, plus use bounding box in r1-r4
        SWI     XWimp_ForceRedraw                ; to do wimp redraw.

        ADD     r9,r9,#16                       ; Move on r9 to next four words

        ; Now make icon flags
        MOV     r1,#7
        MOV     r4, r1,      LSL #24            ; Foreground colour   (bits 24-27)
        MOV     r1,#0
        ADD     r4, r4, r1,  LSL #28            ; Background colour   (bits 28-31)
        MOV     r1,#15
        ADD     r4, r4, r1,  LSL #12            ; Type                (bits 12-15)

        ADD     r4, r4, #if_indirected          ; Indirected          (bit 8)
        ADD     r4, r4, #if_filled              ; Filled background   (bit 5)
        ADD     r4, r4, #if_border              ; Border              (bit 2)
        ADD     r4, r4, #if_text                ; Has text            (bit 0)

        CMP     r5, #db_dm_largeicon            ; is this a large icon?
        ADDEQ   r4, r4, #if_hcentred            ; if a large sprite, centre horizontally
        ADDEQ   r4, r4, #if_sprite              ; if a large sprite, then add an invisible sprite
        ADDNE   r4, r4, #if_vcentred            ; if NOT a large sprite, then centre vertically

        ; Now make the text buffer etc. point to our memory chunk
        LDR     r5, renaming_chunkaddr
        ADD     r5, r5, #re_textstring          ; location of text buffer
        ADR     r6, wr_filename_validation      ; location of validation string
        MOV     r7,#252                         ; length of buffer
        STMIA   r9, {r4, r5, r6, r7}            ; store flags etc.

        ; Create the writeable icon
        MOV     r0,#0
        MOV     r1,r10
        SWI     XWimp_CreateIcon

        LDR     r2, renaming_chunkaddr
        ADD     r2, r2, #re_windowhandle
        STR     r0, [r2, #4]                    ; store the handle of the writeable icon

        ; Send a claim entity message
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_tempdata            ; Address of a block to put the message data
        MOV     r0, #24                         ; message size
        STR     r0, [r1]
        LDR     r0, mytaskhandle                ; my task handle
        STR     r0, [r1, #4]
        MOV     r0, #0                          ; my ref
        STR     r0, [r1, #8]
        MOV     r0, #0                          ; your ref
        STR     r0, [r1, #12]
        MOV     r0, #Message_ClaimEntity        ; message action
        STR     r0, [r1, #16]
        MOV     r0, #3                          ; bits 0 and 1 set indicating caret claim
        STR     r0, [r1, #20]

        MOV     r0, #17                         ; event code
        MOV     r2, #0                          ; 0 = broadcast message
        SWI     XWimp_SendMessage

        ; Set the caret position
        LDR     r2, renaming_chunkaddr
        LDR     r1, [r2, #re_iconhandle]        ; put icon handle in r1 for SetCaret call

        LDR     r0, windowhandle                ; put window handle in r0.
        STR     r0, [r2, #re_windowhandle]      ; store window handle

        LDR     r2, relmousex                   ; Set caret position according to mouse x and y
        LDR     r3, relmousey
        MVN     r4, #1
        MVN     r5, #1

        SWI     XWimp_SetCaretPosition

06                                              ; exit claimed click
        CMP     r0, r0
        EXIT

08                                              ; exit unclaimed click
        CMP     pc, #0
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; always_create_rename_writeable
; ==============================
;
; Like create_rename_writable, but ignores mouse pos
;
always_create_rename_writeable
        ALTENTRY
        MOV     r8, #1                          ; Non-zero -> ignore mouse pos
        B       %BT01
 ]


 [ AltRenaming
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; remove_rename_writeable
; =======================
;
; If it exists, delete the writeable icon used for renaming files
;
; In:
;
; Out: no corruption

remove_rename_writeable Entry

00
        Push    "r0-r5"
        LDR     r1, renaming_chunkaddr
        ADD     r1, r1, #re_windowhandle
        LDR     r0, [r1]
        CMP     r0, #0
        BEQ     %FT10
        SWI     XWimp_DeleteIcon
        MOV     r0,#0                       ; Update details of writeable icon to show nonexistance
        STR     r0, [r1]
        STR     r0, [r1, #4]

        ; Force a redraw
        ADD     r5, r1, #re_createwhandle   ; point to window handle
        LDMIA   r5, {r0, r1, r2, r3, r4}    ; load window handle, followed by icon bounding box
        SWI     XWimp_ForceRedraw            ; Force a redraw of that area

10
        Pull    "r0-r5"
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_redraw_window
; ===================

; In    r1 -> wimp_eventstr
;             [r1, #0]  window handle

; Out   all regs may be corrupted - going back to PollWimp

; NB. Errors generated at this level or below result in an error box with just
;  the 'Ok' button in it, which means give up redrawing window. Set a flag in
;  dirviewer to say it's dead.

event_redraw_window Entry

 [ debugredraw
 LDR r14,[r1, #r_handle]
 DREG r14,"redraw_window: window ",,Integer
 ]
        BL      read_font_widths

        SWI     XWimp_RedrawWindow      ; get wimp to redraw as much as poss.
        BVS     %FT99

        Push    "r0"                    ; save more_rectangles flag
        LDR     r0, [r1, #r_handle]
        BL      FindDir                 ; r4 -> dirviewer block
        Pull    "r0"
        BEQ     %FT02                   ; [redrawing a dirviewer]


01      CMP     r0, #0                  ; Loop doing rectangles anyway
        EXIT    EQ                      ; VClear

        ADR     r1, userdata
 [ debugredraw
 LDR r14, [r1, #u_handle]
 DREG r14, "silly call of XWimp_GetRectangle, window handle ",,Integer
 ]
        SWI     XWimp_GetRectangle
        BVC     %BT01
        B       %FT99

02
        LDRB    r14, [r4, #d_filesperrow]
 [ centralwrap
        TEQ     r14, #db_fpr_stuffed
 |
        TEQ     r14, #&ff
 ]
        BEQ     %BT01                   ; [dirviewer is stuffed, can no cope]


 ASSERT r_wax0 = 4
        LDMIB   r1, {x0, y0, x1, y1, scx, scy}
        SUB     r10, x0, #0             ; scx MUST be 0
        SUB     r11, y1, scy

        STR     r10, windowx            ; abs coords of top left of work area
        STR     r11, windowy
        BL      RedrawDirectory
        EXIT    VC

99      BL      LocalReportError

 [ centralwrap
        MOV     r14, #db_fpr_stuffed    ; dirviewer is stuffed, matey-peeps
 |
        MOV     r14, #&FF               ; dirviewer is stuffed, matey-peeps
 ]
        STRB    r14, [r4, #d_filesperrow]

        CLRV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Redraw directory viewer
;
; In     r4 -> dirviewer block
;        r0 = more_rectangles flag
;        first redraw block stored in userdata
;        [windowx], [windowy] set up
; Out    r0 -> error
;        r1-r3, r5 corrupt

RedrawDirectory ROUT
        Entry   "r6"

05      CMP     r0, #0                  ; while (more_rectangles) do ...
 [ debugredraw
 BNE %FT00
 DLINE "No more rectangles for redraw"
00
 ]
        EXIT    EQ                      ; VClear

; loop over file icons (format depends on viewmode)

 [ debugredraw
 Push "cx0-cy1"
 wsaddr r14, userdata + r_gwx0  ; current graphics window (abs)
 LDMIA  r14, {cx0, cy0, cx1, cy1}
 DREG cx0, "redraw file icons in graphics window: x0=",cc,Integer
 DREG cy0, ", y0=",cc,Integer
 DREG cx1, ", x1=",cc,Integer
 DREG cy1, ", y1=",,Integer
 Pull "cx0-cy1"
 ]
        LDR     r3, [r4, #d_nfiles]     ; r3 = no of files to do
        CMP     r3, #0
        BEQ     %FT95                   ; [nothing in this viewer]

        ADD     r5, r4, #d_headersize
        ADRL    r2, userdata + r_size
        ADR     r6, userdata + userdata_size

90
        ; Draw applications immediately, as they're likely to have unique
        ; sprites. Everything else gets queued and then sorted to avoid
        ; thrashing ColourTrans and to improve CPU cache performance.
        LDRB    r14, [r5, #df_type]
        TEQ     r14, #dft_applic
        BEQ     %FT93
        STR     r3, [r2], #4
        TEQ     r2, r6
        BNE     %FT94
        BL      SortAndDraw
        ADRL    r2, userdata + r_size
        B       %FT94
93
        BL      GetFileBox              ; get relative to work area origin
        BL      RedrawFile
        BVS     %FT99
94
        SUBS    r3, r3, #1
        ADDNE   r5, r5, #df_size
        BNE     %BT90
        ADRL    r6, userdata + r_size
        TEQ     r2, r6
        BLNE    SortAndDraw

95      ADR     r1, userdata
 [ debugredraw
 LDR r14, [r1, #u_handle]
 DREG r14, "calling XWimp_GetRectangle, window handle ",,Integer
 ]
        SWI     XWimp_GetRectangle      ; r0,r1 := more_rectangle state
        BVC     %BT05

99
        EXIT

astring DCB "r2 %d r3 %d",10,0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In     r4 -> dirviewer block
;        r2 -> end of redraw list in userdata block (nonempty!)

SortAndDraw ROUT
        Entry   "r0-r7"
        ; Heap sort the redraw block
        ADRL    r1, userdata + r_size
        SUB     r0, r2, r1
        MOV     r0, r0, LSR #2
        ADD     r3, r4, #d_headersize
        LDR     r5, [r4, #d_nfiles]
        CMP     r0, #2
        ASSERT  df_size = 7*4
        ADD     r3, r3, r5, LSL #2+3    ; *8
        SUB     r3, r3, r5, LSL #2      ; -1
        BLS     %FT25                   ; No point sorting if <=2 entries
        ADRL    r2, sort_redraw
        TST     r1, #2_111 :SHL: 29     ; use old or new SWI depending on
        BNE     %FT20                   ; address
        SWI     XOS_HeapSort
        B       %FT25
20      MOV     r7, #0
        SWI     XOS_HeapSort32
25
        ; Now draw the icons
        FRAMLDR r2
        ADRL    r1, userdata + r_size
        MOV     r6, r3
26
        LDR     r3, [r1], #4
        ASSERT  df_size = 7*4
        SUB     r5, r6, r3, LSL #2+3
        ADD     r5, r5, r3, LSL #2
        BL      GetFileBox
        BL      RedrawFile
        CMP     r1, r2
        BNE     %BT26
        EXIT         
        

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In     r4 -> dirviewer block
;        r5 -> fileinfo block
;        filebox()() set up

RedrawFile ROUT
        Entry "r1-r5, x0, y0, x1, y1"

 [ debugredraw
 DREG r4, "RedrawFile: dir ",cc
 DREG r5, ", file "
 ]

; Try drawing object icon part (sprite + text)

        ADR     r0, filebox1
        BL      checkboxcoords          ; x0, y0, x1, y1 := abs. coords of box
        BLE     RedrawInfoPart          ; [no intersection with sprite part]

; Setup name for copy into indirect buffer

        LDR     r1, [r4, #d_filenames]
        LDR     r14, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r0, r1, r14             ; r0 -> filename (null-terminated)
 |
        ADD     r0, r1, r14, LSR #16    ; r0 -> filename (null-terminated)
 ]
 [ debugredraw
 DSTRING r0, "leafname to copy: "
 ]
        ;wsaddr  r1, i_textbuffer
        LDR     r1, i_textbuffer_ptr

        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        CMP     r14, #db_dm_largeicon
        BNE     %FT50

; Large icon display

        MOV     r6, r0                   ; filename
        MOV     r7, r1                   ; icon
        LDR     r8, largeicon_truncation_mp
        BL      truncate_filename

;10      Push    "R2"
;        MOV     R2,#max_text_size
;15      LDRB    r14, [r0], #1           ; Copy name, will be centred
;        TEQ     r14, #0
;        SUBNES  r2,r2,#1
;        MOVEQ   r14, #CR
;        STRB    r14, [r1], #1
;        BNE     %BT15
;        Pull    "r2"

 [ debugredraw
 ;wsaddr r1, i_textbuffer
 LDR     r1, i_textbuffer_ptr
 DSTRING r1, "copied leafname into icon buffer "
 ]

        BL      GetBigIconName
        wsaddr  r3, dirwindow + lgi_icon_offset
        MOV     r6, #0                  ; All large icons drawn full size
        B       GoDrawIcon


; Full info or small icon display

50      MOV     r6, r0                       ; filename
        MOV     r7, r1                       ; icon
        LDR     r8, smallicon_truncation_mp  ; truncation width in millipoints
        CMP     r14, #db_dm_smallicon
        LDRNE   r8, fullinfo_truncation_mp   ; If Full Info, different width

        BL      truncate_filename

;50      MOV     r2, #0                  ; Pad to right of name with spaces
;60
;                                        ; don't pad with fancy font
;
;        LDRB    r14, [r0]
;        TEQ     r14, #0
;;        MOVEQ   r14, #space
;        ADDNE   r0, r0, #1
;;        ADD     r0, r0, #1
;        ADD     r2, r2, #1
;        CMP     r2, #max_text_size
;        MOVEQ   r14, #CR
;        STRB    r14, [r1], #1
;        BNE     %BT60

 [ debugredraw
 ;wsaddr r1, i_textbuffer
 LDR     r1, i_textbuffer_ptr
 DSTRING r1, "copied leafname into icon buffer "
 ]

        BL      GetSmallIconName
        wsaddr  r3, dirwindow + smi_icon_offset
        B       GoDrawIcon

GetSmallIconName
;In:    r4 -> dirviewer block
;       r5 -> file info block
;Out:   r2 -> icon name
;       r6 = 0 (full size) or #if_halfsize

        Push    "r3,lr"

        LDRB    r3, [r5, #df_type]      ; type
        LDMIA   r5, {r6, r7}            ; load & exec

        CMP     r3, #dft_dir            ; directories easy
 [ ShowOpenDirs
        BNE     %FT79

; Check to see if this directory is open

        LDRB    R14,[R5,#df_state]      ; get icon state
        TST     R14,#dfs_opened         ; is directory open?
        ADREQ   R2, small_dir           ; use 'small_dir'
        BEQ     %FA90
        ADR     R2, small_diro          ; use 'small_diro'
        BL      ExistsSprite
        ADRVS   R2, small_dir           ; use 'small_dir'
        B       %FA90
79
 |
        ADREQ   r2, small_dir           ; use 'small_dir'
        BEQ     %FA90
 ]
        CMP     r3, #dft_applic
        BNE     %FT80

; If 'sm!Applic' exists, use it in preference to a scaled '!Applic' sprite

        wsaddr  r1, i_spritebuffer + 4  ; temp place
        ADR     r2, sm_prefix
        MOV     r3, #' '
        BL      strcpy
        LDR     r2, [r4, #d_filenames]
        LDR     r14, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r2, r14             ; r2 -> full !Applic
 |
        ADD     r2, r2, r14, LSR #16    ; r2 -> full !Applic
 ]
        BL      strncat10               ; clamp to sprite name limit
        MOV     r6, r2                  ; keep -> full !Applic
        MOV     r2, r1                  ; r2 -> clamped sm!Applic
        BL      ExistsSprite
        BVC     %FA90                   ; ['sm!Applic' found]

; Otherwise try a scaled '!Applic'

        wsaddr  r1, i_spritebuffer + 4  ; temp place
        MOV     r2, r6                  ; recover -> full !Applic
        MOV     r3, #12
        BL      strncpy                 ; clamp to sprite name limit
        MOV     r2, r1                  ; r2 -> clamped !Applic
        BL      ExistsSprite
        ADRVS   r2, small_app           ; ['!Applic' not found]
        BVS     %FA90

        MOV     r6, #if_halfsize        ; Half-size '!Applic'
        Pull    "r3,pc"


sm_prefix       DCB     "sm", 0
small_dir       DCB     "small_dir", 0
small_diro      DCB     "small_diro", 0
small_app       DCB     "small_app", 0
                ALIGN

; At this point, r6 = load address, r7 = exec address.

80      LDR     r2, dead_file
        CMP     r6, r2          ; Is load address = &DEADDEAD
        BNE     %FT82           ; No?
        CMP     r6, r7          ; Is exec address = &DEADDEAD
        ADREQ   r2, small_unf   ; If so, then use 'small_unf'
        BEQ     %FA90
        ;Pull    "r3,pc",EQ

82      TEQ     r6, r7
        ADREQ   r2, small_lxa           ; [load=exec; use 'small_xxx' icon]
        BEQ     %FA90

        CMN     r6, #&00100000
        ADRCC   r2, small_lxa           ; [undated; use 'small_xxx' icon]
        BCC     %FA90

; If 'small_xyz' exists, use it

                                        ; Test existence of 'small_xyz'
        MOV     r0, r6, LSL #12         ; r0 := file type, only using 16 bits
        MOV     r0, r0, LSR #20
        wsaddr  r1, i_spritebuffer + 4  ; temp place
        ADR     r2, small_prefix
        BL      strcpy_advance
        MOV     r2, #5                  ; 5 byte buffer
        SWI     XOS_ConvertHex4
        wsaddr  r2, i_spritebuffer + 4
        MOV     r14, #"_"               ; replace leading '0' with '_'
        STRB    r14, [r2, #(?small_prefix)-1]

        BL      ExistsSprite
        BVC     %FA90                   ; ['small_xyz' found]

; Otherwise try a scaled 'file_xyz'

                                        ; Test existence of 'file_xyz'
        MOV     r0, r6, LSL #12         ; r0 := file type, only using 16 bits
        MOV     r0, r0, LSR #20
        wsaddr  r1, i_spritebuffer + 4  ; temp place
        ADR     r2, file_prefix
        BL      strcpy_advance
        MOV     r2, #5                  ; 5 byte buffer
        SWI     XOS_ConvertHex4
        wsaddr  r2, i_spritebuffer + 4
        MOV     r14, #"_"               ; replace leading '0' with '_'
        STRB    r14, [r2, #(?file_prefix)-1]

        BL      ExistsSprite
        MOVVC   r6, #if_halfsize        ; Half-size 'file_xyz'
        Pull    "r3,pc",VC

        ADR     r2, small_xxx           ; ['file_xyz' not found]

90      MOV     r6, #0                  ; Full-size
        Pull    "r3,pc"


small_prefix    DCB     "small", 0
small_xxx       DCB     "small_xxx", 0
small_lxa       DCB     "small_lxa",0
small_unf       DCB     "small_unf",0
                ALIGN


GetBigIconName ROUT
;In:    r4 -> dirviewer block
;       r5 -> file info block
;Out:   r2 -> icon name

        Push    "r3,lr"

        LDRB    r3, [r5, #df_type]      ; type
        LDMIA   r5, {r6, r7}            ; load & exec

        CMP     r3, #dft_dir            ; directories easy
 [ ShowOpenDirs
        BNE     %FT09

; Check to see if this directory is open
        LDRB    R14,[R5,#df_state]      ; get icon state
        TST     R14,#dfs_opened         ; is directory open?
        ADREQ   R2, directory           ; use 'directory'
        Pull    "r3,pc",EQ
        ADR     R2, directoryo          ; use 'directoryo'
        BL      ExistsSprite
        ADRVS   R2, directory           ; use 'directory'
        Pull    "r3,pc"
09
 |
        ADREQ   r2, directory           ; use 'directory'
        Pull    "r3,pc",EQ
 ]

        CMP     r3, #dft_applic
        BNE     %FT10

        LDR     r2, [r4, #d_filenames]
        LDR     r14, [r5, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r2, r14             ; r2 -> !Applic
 |
        ADD     r2, r2, r14, LSR #16    ; r2 -> !Applic
 ]
        Push    "r1"
        wsaddr  r1, i_spritebuffer + 4  ; temp place
        MOV     r3, #12
        BL      strncpy                 ; clamp to sprite name limit
        MOV     r2, r1                  ; r2 -> clamped !Applic
        BL      ExistsSprite
        Pull    "r1"
        ADRVS   r2, application         ; ['!Applic' not found]
        Pull    "r3,pc"

directory       DCB     "directory", 0
directoryo      DCB     "directoryo", 0
application     DCB     "application", 0
                ALIGN


10      LDR     r2, dead_file
        CMP     r6, r2
        BNE     %FT12
        TEQ     r6, r7
        ADREQ   r2, file_unf
        Pull    "r3,pc",EQ

12      TEQ     r6, r7
        ADREQ   r2, file_lxa            ; [load=exec; use 'file_xxx' icon]
        Pull    "r3,pc",EQ

        CMN     r6, #&00100000
        ADRCC   r2, file_lxa            ; [undated; use 'file_xxx' icon]
        Pull    "r3,pc",CC

                                        ; Test existence of 'file_xyz'
        MOV     r0, r6, LSL #12         ; r0 := file type, only using 16 bits
        MOV     r0, r0, LSR #20
        wsaddr  r1, i_spritebuffer + 4  ; temp place
        ADR     r2, file_prefix
        BL      strcpy_advance
        MOV     r2, #5                  ; 5 byte buffer
        SWI     XOS_ConvertHex4
        wsaddr  r2, i_spritebuffer + 4
        MOV     r14, #"_"               ; replace leading '0' with '_'
        STRB    r14, [r2, #(?file_prefix)-1]

        BL      ExistsSprite
        ADRVS   r2, file_xxx            ; ['file_xyz' not found]
        Pull    "r3,pc"


file_prefix     DCB     "file", 0
file_xxx        DCB     "file_xxx", 0
file_lxa        DCB     "file_lxa", 0
file_unf        DCB     "file_unf", 0
dead_file       DCD     &DEADDEAD
                ALIGN



; .............................................................................
; In    r2 -> sprite name
;       r3 -> icon to use
;       r6 = if_halfsize or 0

GoDrawIcon ROUT

        LDRB    r14, [r5, #df_state]
        TST     r14, #dfs_selected
        ORRNE   r6, r6, #is_inverted    ; Draw as selected

        wsaddr  r1, i_spritebuffer + 1  ; Don't overwrite 's'
        BL      strcpy

        MOV     r1, r3                  ; r1 -> icon
        ADR     r0, filebox1            ; Load relative coords
        LDMIA   r0, {r8, r9, r10, r11}
 ASSERT i_bbx0 = 0
        STMIA   r1, {r8, r9, r10, r11}  ; Stuff the icon
 [ debugredraw :LAND: True
 DREG  r8, "stuffing icon bbox: rel. x0 := ",cc,Integer
 DREG  r9, ", y0 := ",cc,Integer
 DREG r10, ", x1 := ",cc,Integer
 DREG r11, ", y1 := ",cc,Integer
 ;wsaddr r2, i_textbuffer
 LDR     r2, i_textbuffer_ptr
 DSTRING r2, ", text part is ",cc
 wsaddr r2, i_spritebuffer
 DSTRING r2, ", sprite part is "
 ]
        LDR     r2, [r1, #i_flags]
        BIC     r2, r2, #is_inverted
        BIC     r2, r2, #if_halfsize
        ORR     r2, r2, r6              ; Draw half-size or full-size

; fix template for fancy system font
        AND     r6,r2,#&218
        CMP     r6,#&218

        BICEQ   r2,r2, #&218            ; HVR bits
        ORREQ   r2,r2, #&10

        STR     r2, [r1, #i_flags]

        SWI     XWimp_PlotIcon
        BVC     RedrawInfoPart

        LDREQ   r14, =ErrorNumber_Sprite_DoesntExist ; Don't winge if no sprite
        TEQ     r14, r0
        EXIT    NE                      ; VSet still

; .............................................................................
; Try printing out full info part of object

RedrawInfoPart ROUT

; if 'full info', display extra data

        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        CMP     r14, #db_dm_fullinfo
        EXIT    NE                      ; [no extra info, we're done]

        ADR     r0, filebox3
        BL      checkboxcoords          ; x0, y0, x1, y1 := abs. coords of box
 [ debugbox
 BGT %FT00
 DLINE "no intersection with full info"
00
 ]
        EXIT    LE                      ; [no intersection with full info part]

 [ version >= 117
        ; Choose the colours depending on whether the item is selected or not
 [ version >= 118
        LDRB    r1, text_fgcolour
        LDRB    r2, text_bgcolour
 |
        LDRB    r0, [r5, #df_state]
        TST     r0, #dfs_selected
        LDRNEB  r1, text_bgcolour
        LDRNEB  r2, text_fgcolour
        LDREQB  r1, text_fgcolour
        LDREQB  r2, text_bgcolour
 ]

        [ {TRUE}
        ; Set foreground and background colour from r1 and r2
        MOV     r0, r1
        SWI     XWimp_SetColour
        ORRVC   r0, r2, #&80
        SWIVC   XWimp_SetColour
        ]

        [ {FALSE}
        ; Fill in the background rectangle and move the cursor
        SUBVC   r1, x1, #1
        MOVVC   r2, y0
        MOVVC   r0, #4
        SWIVC   XOS_Plot
        MOVVC   r1, x0
        ADDVC   r2, y0, #chary-1
        MOVVC   r0, #96+7
        SWIVC   XOS_Plot
        |
        MOV     r1,x0
        ADD     r2,y0,#chary-1          ; this can be zonked with below
        ]

;        LDR     r14,windowx
;        SUB     r1,r1,r14
        STR     r1,current_x0
;        LDR     r14,windowy
;        SUB     r2,r2,r14
        SUB     r2,r2,#32
        STR     r2,current_y0
 |
        LDRB    r0, text_fgcolour       ; Is this paranoia or what, we ask ???
        SWI     XWimp_SetColour
        LDRVCB  r0, text_bgcolour
        ORRVC   r0, r0, #&80
        SWIVC   XWimp_SetColour
        MOVVC   r1, x0
        ADDVC   r2, y0, #chary-1        ; -1 (chars painted on rasters 0..-n)
        MOVVC   r0, #4
 [ debugredraw
 DREG r1,"Moving to ",cc,Integer
 DREG r2,",",,Integer
 ]
        SWIVC   XOS_Plot
 ]

        EXIT    VS


        SUB     sp, sp, #256            ; Let's have a temp frame

accesslength * :LEN:"LWR/wr "

        LDR     r0, =&20202020
        MOV     r1, r0
        STMIA   sp, {r0, r1}            ; eight spaces in a buffer
 ASSERT accesslength <= 2*4

        LDRB    r0, [r5, #df_attr]      ; Access is lsb of attributes
        MOV     r1, sp
        LDRB    r14, [r5, #df_type]     ; Directories only have locked meaning
        TEQ     r14, #dft_file
      [ version < 143
        ANDNE   r0, r0, #locked_attribute      ; Show all attributes on all objects (RM)
      ]

        MOV     r2, #"L"
        TST     r0, #locked_attribute
        STRNEB  r2, [r1], #1
        TST     r0, #write_attribute
        MOV     r2, #"W"
        STRNEB  r2, [r1], #1
        MOV     r2, #"R"
        TST     r0, #read_attribute
        STRNEB  r2, [r1], #1

        TEQ     r0, #0                  ; Any attributes set at all ?
        BNE     %FT40                   ; [yes]

      [ version < 143
        LDRB    r2, [r5, #df_type]      ; If it's not a file then skip to end
        TEQ     r2, #dft_file
        BNE     %FT50
      ]

40      MOV     r2, #"/"
        STRB    r2, [r1], #1
        MOV     r2, #"w"
        TST     r0, #public_write_attribute
        STRNEB  r2, [r1], #1
        MOV     r2, #"r"
        TST     r0, #public_read_attribute
        STRNEB  r2, [r1], #1

50      MOV     r0, sp
        LDR     r1, access_length
        STR     r1, string_length
        MOV     r1, #accesslength
        ORR     r1,r1,#&10000           ; use [string_length]
        BL      myOS_WriteN
        BVS     p256exit

; Now need to diverge on object type

        LDRB    r14, [r5, #df_type]
        CMP     r14, #dft_applic        ; EQ,CS if so
        ADREQL  r1, applicstring
        TEQNE   r14, #dft_dir*4,2       ; EQ,CC if so
        ADRCC   r1, dirstring
        BEQ     printdirappinfo


sizelength * :LEN: "8192K "

        LDR     r0, [r5, #df_length]    ; Print size of file
        LDR     r1, size_length
        STR     r1, string_length
        MOV     r1, sp
        MOV     r2, #256
        SWI     XOS_ConvertFixedFileSize
        MOVVC   r1, #sizelength-2       ; Don't print ' Kbytes' part of it
        ORRVC   r1,r1, #&10000
        BLVC    myOS_WriteNjus
        LDRVCB  r0, [sp, #sizelength-1] ; Print 'K' or 'M' or ' '
        BLVC    myOS_WriteC
;        SWIVC   XOS_WriteI+space        ; And a trailing space too
        BVS     p256exit

; Print type of file

 ASSERT df_load = 0
 ASSERT df_exec = 4
        LDMIA   r5, {r1, r2}

        TEQ     r1, r2
        BEQ     undatedfile             ; [load=exec; no file type]

        CMN     r1, #&00100000
        BCC     undatedfile             ; [undated; no file type]

        MOV     r2, r1, LSR #8          ; r2 = filetype (uses bottom 12 bits)
        [ {TRUE}
        BL      getfile_type
        |
        MOV     r0, #18
        SWI     XOS_FSControl           ; read file type string
                                        ; (default &abc is given if unknown)
        ]

        LDRVC   r14, =&20202020         ; Three trailing spaces. Yuk!
 ASSERT typelength = 12
        STMVCIA sp, {r2, r3, r14}
        MOVVC   r0, sp
        LDR     R1,applic_length         ; this assumes "Application" is widest type
        STR     R1,string_length
        MOVVC   r1, #typelength
        ORR     R1,R1,#&10000
        BLVC    myOS_WriteN

rejoindirapp
        BVS     p256exit

 ASSERT df_load = 0
 ASSERT df_exec = 4
        LDMIA   r5, {r1, r2}            ; get load/exec addresses
        CMP     r1, r2                  ; unlikely to be the same. VClear
        BEQ     printloadexec           ; (trap for BBC utilities)

printdatestamp
        STR     r2, [sp, #0]            ; store low-word first
        STRB    r1, [sp, #4]
        MOV     r0, sp
        ADD     r1, sp, #8              ; r1 -> output buffer
        MOV     r2, #256 - 8            ; r2 = output buffer length
        wsaddr  r3, mydateformat
        SWI     XOS_ConvertDateAndTime

w0p256exit
        BLVC    myOS_Write0

p256exit
        ADD     sp, sp, #256
        EXIT


undatedfile                             ; Has no type
        ADR     r0, nulltypestring
        LDR     R1,applic_length         ; this assumes "Application" is widest type
        STR     R1,string_length
        BL      myOS_Write0

printloadexec
        LDRVC   r0, [r5, #df_load]
        MOVVC   r1, sp
        MOVVC   r2, #256-1              ; We'll be putting in a space ourselves
        SWIVC   XOS_ConvertHex8         ; Updates r1, r2
        MOVVC   r0, #space
        STRVCB  r0, [r1], #1
        LDRVC   r0, [r5, #df_exec]
        SWIVC   XOS_ConvertHex8
        MOVVC   r0, sp
        B       w0p256exit              ; Nothing follows exec addr


 [ version >= 118
dirstring       DCB     "Display_Directory", 0
applicstring    DCB     "Display_Application", 0
nulltypestring  DCB     "            ", 0
typelength      *       ?nulltypestring - 1
 |
dirstring       DCB     "Directory   ", 0
typelength      *       ?dirstring - 1
applicstring    DCB     "Application ", 0
nulltypestring  DCB     "            ", 0
 ]
nullsizestring  *       .-1-(typelength-sizelength)
loadexeclength  *       :LEN: "12345678 12345678"
                ALIGN

        LTORG

printdirappinfo
        LDR     r0, length_length
        STR     r0, string_length
        ADR     r0, nullsizestring
        BL      myOS_Write0
 [ version >= 118
        ADRVC   r0, messagetrans_struct
        MOVVC   r2, #0
        SWIVC   XMessageTrans_Lookup
        MOVVC   r1, r2
        BLVC    strlen
        MOVVC   r0, r1
        LDR     r1,applic_length
        STR     r1,string_length
        MOVVC   r1, r3
        ORR     r1,r1,#&10000
        BLVC    myOS_WriteN
 |
        MOVVC   r0, r1                  ; 'Directory   ' or 'Application '
        SWIVC   XOS_Write0
 ]

        B       rejoindirapp

;;=============================================================================
;; myOS_Write? routines, use the wimp icon system to print
;; Entry as standard routines and [current_x0] updated
;; originated: Neil Kelleher, Feb 25 1993
;;=============================================================================

myOS_WriteC
        CMP     R0,#256
        MOVGE   PC,lr
        Push    "lr,R0"
        Push    "R0"            ; SP is now character+'\0'
        MOV     R0,#0
        STR     R0,current_justified
        MOV     R0,SP
        BL      myOS_Write0_int
        ADD     SP,SP,#4        ; get the stack back
        LDR     R0,current_x0
        Push    "R1"
        LDR     R1,char_length
        ADD     R0,R0,R1
        Pull    "R1"
        STR     R0,current_x0  ; move along width of ("M ")
        Pull    "PC,R0"

myOS_Write0

        Push    "lr,r0-r1,r3"
        MOV     R1,#0
        STR     R1,current_justified
        BL      myOS_Write0_int
        LDR     R1,string_length
        LDR     R0,current_x0
        ADD     R1,R0,r1
        STR     R1,current_x0
        Pull    "PC,r0-r1,r3"


myOS_Write0_int

        Push    "R0-R5,lr"

        LDR     R4,current_x0
        LDR     R2,string_length

        LDR     R1,current_justified
        TEQ     R1,#0

        ADDEQ   R3,R4,R2                ; for non justified R4 to R4+len is x bbox
        MOVEQ   R2,R4

        MOVNE   R3,R4
        SUBNE   R2,R4,R2                ; for rjust R4-len to R4 is x bbox

        TEQ     R1,#0
        MOVEQ   R0,#&10000002           ; 'vertical justification'
        MOVNE   R0,#&90000002           ; right justified
        BNE     %FT01                   ; as we're right justifying, may be outside
                                        ; x0-x1, but still need to print.

        CMP     R2,x1
        Pull    "R0-R5,PC",GT

        CMP     R3,x0
        Pull    "R0-R5,PC",LT
01
        LDR     R5,current_y0

        ADDNE   R4,R4,R1
        LDR     R14,smi_height
        ADD     R5,R5,R14,LSR #1                ; so that text is aligned with small icon
        ADD     R5,R5,#smi_botgap
        LDR     R1,[sp]
        SWI     XWimp_TextOp
        Pull    "R0-R5,PC"



myOS_WriteNjus             ; right justified WriteN

        Push    "lr,R0-R2,R6-R8"
        TST     R1,#&10000
        MOVEQ   R7,R1, ASL #4
        LDRNE   R7,string_length
        EORNE   R1,R1,#&10000
        ADD     R6,R1,#4        ; yes 4, beacuse we may need space for '\0'
        STR     R7,current_justified
        BIC     R6,R6,#3
        SUB     SP,SP,R6        ; make space on stack for string
        MOV     R8,SP
oswrite_loop_j2
        LDRB    R2,[R0] ,#1
        STRB    R2,[R8], #1
        SUBS    R1,R1,#1
        BNE     oswrite_loop_j2
        MOV     R2,#0
        STRB    R2,[R8]         ; terminate string
        MOV     R0,SP
        BL      myOS_Write0_int
        LDR     R0,current_x0
        ADD     R0,R0,R7
        STR     R0,current_x0   ; update x position
        ADD     SP,SP,R6        ; get the stack back
        Pull    "PC,R0-R2,R6-R8"


myOS_WriteN
        Push    "lr,R0-R2,R6-R8"
        MOV     R7,#0
        STR     R7,current_justified
        TST     R1,#&10000
        MOVEQ   R7,R1, ASL #4
        LDRNE   R7,string_length
        EORNE   R1,R1,#&10000    ; mask off control bits
        ADD     R6,R1,#4        ; yes 4, beacuse we may need space for '\0'
        BIC     R6,R6,#3
        SUB     SP,SP,R6        ; make space on stack for string
        MOV     R8,SP
oswrite_loop
        LDRB    R2,[R0] ,#1
        STRB    R2,[R8], #1
        SUBS    R1,R1,#1
        BNE     oswrite_loop
        MOV     R2,#0
        STRB    R2,[R8]         ; terminate string
        MOV     R0,SP
        BL      myOS_Write0_int
        LDR     R0,current_x0
        ADD     R0,R0,R7
        STR     R0,current_x0   ; update x position
        ADD     SP,SP,R6        ; get the stack back
        Pull    "PC,R0-R2,R6-R8"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> block containing coords
;       windowx,y = offsets to make these absolute
;       [userdata+r_gwx0] contains absolute coords of graphics window

; Out   x0, y0, x1, y1 = coords from block having been made absolute
;       GT: block intersects graphics window
;       LE: no intersection

checkboxcoords Entry "cx0, cy0, cx1, cy1"

        LDMIA   r0, {x0, y0, x1, y1}    ; our box
 [ debugbox
 DREG x0,"rel. box coords ",cc,Integer
 DREG y0,", ",cc,Integer
 DREG x1,", ",cc,Integer
 DREG y1,", ",,Integer
 ]

        LDR     r14, windowx            ; make absolute
        ADD     x0, x0, r14
        ADD     x1, x1, r14
        LDR     r14, windowy
        ADD     y0, y0, r14
        ADD     y1, y1, r14
 [ debugbox
 DREG x0, "checkboxcoords: absolute x0 := ",cc,Integer
 DREG y0, ", y0 := ",cc,Integer
 DREG x1, ", x1 := ",cc,Integer
 DREG y1, ", y1 := ",,Integer
 ]

        wsaddr  r14, userdata + r_gwx0  ; current graphics window (abs)
        LDMIA   r14, {cx0, cy0, cx1, cy1}
 [ debugbox
 DREG cx0, "checkboxcoords: graphics window x0 = ",cc,Integer
 DREG cy0, ", y0 = ",cc,Integer
 DREG cx1, ", x1 = ",cc,Integer
 DREG cy1, ", y1 = ",,Integer
 ]

        CMP     cx1, x0
        CMPGT   x1, cx0
        CMPGT   cy1, y0
        CMPGT   y1, cy0
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A file has had its info changed, so ask for it to be redrawm

; In    r4 -> dirviewer block
;       r5 -> fileinfo block

; Out   filebox()() corrupt

UpdateFile ROUT
        Entry "r1-r5"


        BL      GetFileBox

        LDR     r0, [r4, #d_handle]
 [ version >= 117
        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        TEQ     r14, #db_dm_fullinfo
 ]
        ADR     r14, filebox1
        LDMIA   r14, {r2-r5}
 [ version >= 117
        BNE     %FT01
        Push    "r0"
        MOV     r0,#4
        SWI     XWimp_ReadSysInfo
        MOVVSS  r0,#0
        TEQ     r0,#0
        Pull    "r0"
        LDREQ   r4, filebox3 + fb_x1
01
 ]
        ADR     r1, userdata
        STMIA   r1, {r0, r2-r5}
 [ debugredraw
 DREG r0, "UpdateWindow: window ",cc,Integer
 DREG r2, ", x0 = ",cc,Integer
 DREG r3, ", y0 = ",cc,Integer
 DREG r4, ", x1 = ",cc,Integer
 DREG r5, ", y1 = ",,Integer
 ]

        [ {TRUE}
; redraw whole window if doing a lot of selections
        MOV     R14,R1
        LDR     R2,redraw_all
        TEQ     R2,#0
        BEQ     dont_redraw_all
        TEQ     R2,#1
        MOVEQ   R0,#0
        BEQ     done_redrawing
        MOV     R1,#0
        MOV     R4,#0
        MOV     R3,#&FFFFFF
        MVN     R2,#&FFFFFF
         [ {FALSE}
          SWI     XWimp_ForceRedraw
          MOVVC   R0,#0                   ; no rectangles yet
          B       done_redrawing
         |
          STMIA   R14,{R0-R4}
          MOV     R1,R14
         ]
dont_redraw_all
        SWI     XWimp_UpdateWindow
done_redrawing
        |
        SWI     XWimp_UpdateWindow      ; r0 := more_rectangles flag
        ]
        EXIT    VS

        LDR     r4, [sp, #4*3]          ; r4in

        LDRB    r14, [r4, #d_filesperrow]
 [ centralwrap
        TEQ     r14, #db_fpr_stuffed
 |
        TEQ     r14, #&FF
 ]
        BEQ     %FT80                   ; [dirviewer is stuffed, can no cope]


        LDR     r2, [r1, #u_wax0]       ; set up window x,y coords
 [ False ; scx MUST be 0
        LDR     r3, [r1, #u_scx]
        SUB     r2, r2, r3
 ]
        STR     r2, windowx

        LDR     r2, [r1, #u_way1]
        LDR     r3, [r1, #u_scy]
        SUB     r2, r2, r3
        STR     r2, windowy

        BL      RedrawDirectory
        EXIT    VC

99      BL      LocalReportError

 [ centralwrap
        MOV     r14, #db_fpr_stuffed    ; dirviewer is stuffed, matey-peeps
 |
        MOV     r14, #&FF               ; dirviewer is stuffed, matey-peeps
 ]
        STRB    r14, [r4, #d_filesperrow]



80      CMP     r0, #0                  ; Loop doing rectangles anyway
        EXIT    EQ                      ; VClear

        ADR     r1, userdata
        SWI     XWimp_GetRectangle
        BVC     %BT80

        BL      LocalReportError
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Compute the parent box size for items in the current viewing mode of a given
; dirviewer; this is used to divide up the window into a rectangular mesh.
; Hopefully this will be bigger than the combined bbox of all individual items.

; In    r4 -> dirviewer block

; Out   r11 = x size of item (same for all items in the same viewing mode)
;       r14 = y size

iconbar_height  *       140
title_height    *       40
vscroll_width   *       40

dvr_topgap      * 8
dvr_botgap      * 8
dvr_rhsgap      * 16
dvr_rhsslack    * 32

bbox_x_enlarge  * 4
bbox_y_enlarge  * 4

lgi_lhsgap      * 8
lgi_rhsgap      * 8
lgi_botgap      * 8
lgi_topgap      * 8

smi_lhsgap      * 8
smi_rhsgap      * 8
smi_botgap      * 4
smi_topgap      * 4

fui_lhsgap      * 8
fui_midgap1     * charx
fui_moreinfo    * charx*(accesslength + sizelength + typelength)
fui_midgap2     * charx
fui_rhsgap      * 8
fui_botgap      * 4
fui_topgap      * 4


GetItemBoxSize Entry

        LDRB    r14, [r4, #d_viewmode]  ; what view mode are we in?
        AND     r14, r14, #db_displaymode
        CMP     r14, #db_dm_largeicon
        BEQ     %FT10
        CMP     r14, #db_dm_smallicon
        BEQ     %FT20

; 'Full info' display

        BL      GetSmiWidth_r11
        LDR     r14, date_length        ; maximum length of date string
        ADD     r11, r11, r14           ; Only dynamic bit in pbox calc'n
        LDR     r14, size_length
        ADD     r11,r11,r14
        LDR     r14, applic_length
        ADD     r11,r11,r14
        LDR     r14,access_length
        ADD     r11,r11,r14
        LDR     r14,char_length
        ADD     r11,r11,r14             ; for good measure!!!

        ADD     r11, r11, #fui_lhsgap + fui_midgap1  + fui_midgap2 + fui_rhsgap

        LDR     r14, smi_height
        ADD     r14, r14, #fui_botgap + fui_topgap
        B       %FT30


; 'Large icon' display

10      BL      GetLgiWidth_r11
        ADD     r11, r11, #lgi_lhsgap + lgi_rhsgap
        LDR     r14, lgi_height
        ADD     r14, r14, #lgi_botgap + lgi_topgap
        B       %FT30


; 'Small icon' display

20
        BL      GetSmiWidth_r11
        ADD     r11, r11, #smi_lhsgap + smi_rhsgap
        LDR     r14, smi_height
        ADD     r14, r14, #smi_botgap + smi_topgap

30
 [ debugbox
 DREG r11, "Box size: x ",cc,Integer
 DREG r14, ", y ",,Integer
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> dirviewer block
;       r5 -> fileinfo block
;       r3 = file number (descending)

; Out   filebox1() = relative coords (x0,y0, x1,y1) of icon part of object
;       filebox3() = relative coords (x0,y0, x1,y1) of info part of object

; NB. Do NOT call this with an empty dirviewer!

GetFileBox Entry "r1-r11"

        LDR     r10, [r4, #d_nfiles]
        SUB     r10, r10, r3            ; r10 := index of file (0..n-1)
 [ debugbox :LAND: False
 DREG r10, "GetFileBox: index ",cc
 ]

        LDRB    r1, [r4, #d_filesperrow]
 [ True
  [ centralwrap
  CMP r1, #db_fpr_invalid ; Neil can sometimes call us in silly states
  CMPNE r1, #db_fpr_stuffed
  |
  CMP r1, #0 ; Neil can sometimes call us in silly states
  CMPNE r1, #&FF
  ]
 MOVEQ r1, #1
 ]
        DivRem  y0, r10, r1, r14        ; y0 := row number, r10 := column no.
 [ debugbox :LAND: False
 DREG y0, ", row ",cc
 DREG r10, ", col "
 ]

        Push    "r0"
        MOV     r0,#4
        SWI     XWimp_ReadSysInfo
        MOVVS   r0,#0
        TEQ     r0,#0
        BEQ     %FT01
        LDR     r0, [r4, #d_nfiles]
        CMP     r0,r1
        SUBGE   r10,r1,r10
        SUBGE   r10,r10,#1
        SUBLT   r10,r0,r10
        SUBLT   r10,r10,#1
01
        Pull    "r0"

        BL      GetItemBoxSize          ; r11,r14 := (x, y) size of pbox
        MUL     x0, r10, r11            ; x := col * x_per_col
        ADD     x1, x0, r11             ; x0, x1 := left/right of pbox

        MUL     y1, y0, r14             ; y := row * y_per_row
        RSB     y1, y1, #0              ; y0, y1 := bottom/top of pbox
        SUB     y1, y1, #dvr_topgap     ; Small gap at top of dirviewer
        SUB     y0, y1, r14             ; coords now relative to top left of
                                        ; the dir viewer (x +ve, y -ve)
 [ debugbox
 DREG x0,"pbox: x0 = ",cc,Integer
 DREG y0,", y0 = ",cc,Integer
 DREG x1,", x1 = ",cc,Integer
 DREG y1,", y1 = ",,Integer
 ]

                                        ; Keep pbox (parent box) relative

; Calculate icon/name boxes (depends on viewmode)

; In    x0, y0, x1, y1 = pbox (relative coords)
; Out   filebox()() set up

        LDRB    r14, [r4, #d_viewmode]
        AND     r14, r14, #db_displaymode
        CMP     r14, #db_dm_largeicon
        BEQ     %FT10
        CMP     r14, #db_dm_smallicon
        BEQ     %FT20

; 'full info' display

        ADD     cy0,  y0, #fui_botgap
        LDR     r14, smi_height
        ADD     cy1, cy0, r14

; icon bbox, same cy0,cy1

        ADD     cx0,  x0, #fui_lhsgap
        BL      GetSmiWidth
        ADD     cx1, cx0, r14

        Push    "r0"
        MOV     r0,#4
        SWI     XWimp_ReadSysInfo
        MOVVS   r0,#0
        TEQ     r0,#0
        SUBNE   cx1,x1, #fui_rhsgap   ; Variable bit, come in from rhs
        SUBNE   cx0,cx1,r14
        Pull    "r0"

        ADR     r14, filebox1           ; Must stuff here as next bit needs cx1
        STMIA   r14, {cx0, cy0, cx1, cy1}

; info bbox, same cy0,cy1

        SUBNE   cx1, cx0, #fui_midgap1
        ADDNE   cx0,  x0, #fui_lhsgap

        ADDEQ   cx0, cx1, #fui_midgap1
        SUBEQ   cx1,  x1, #fui_rhsgap   ; Variable bit, come in from rhs

        ADR     r14, filebox3
        B       %FT95


10 ; 'large icon' display - icon bbox only

        ADD     cy0,  y0, #lgi_botgap
        LDR     r14, lgi_height
        ADD     cy1, cy0, r14

        ADD     cx0,  x0, #lgi_lhsgap
        BL      GetLgiWidth
        B       %FT90


20 ; 'small icon' display - icon bbox only

        ADD     cy0,  y0, #smi_botgap
        LDR     r14, smi_height
        ADD     cy1, cy0, r14

        ADD     cx0,  x0, #smi_lhsgap
        BL      GetSmiWidth


90      ADD     cx1, cx0, r14
        ADR     r14, filebox1


95      STMIA   r14, {cx0, cy0, cx1, cy1}
        CLRV
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 = file type
;       r0 -> leafname
;       r3 -> fileblock
; Out   r2 -> sprite name

FiletypeToSpritename Entry "r0,r1"

        ; Is it a dir
        TEQ     r2, #filetype_directory
        ADREQL  r2, directory
        EXIT    EQ

        ; Is it undated
        TEQ     r2, #filetype_undated

    [ {TRUE}
        BNE     %FT04
        LDR     r1, dead_file
        LDR     r0, [r3, #df_exec]
        CMP     r0, r1
        LDREQ   r0, [r3, #df_load]
        CMP     r0, r1
        ADRL    r2, file_lxa
        ADREQL  r2, file_unf
        ADRNEL  r2, file_lxa
        EXIT
04
    |
        ADREQL  r2, file_xxx
        EXIT    EQ
    ]

        ; Is it not application
        TEQ     r2, #filetype_application
        BNE     %FT05

        ; Is application
        MOV     r2, r0
        BL      ExistsSprite
        ADRVSL  r2, application
        CLRV
        EXIT

05
        ; Object is a dated file
        ; Construct file_nnn and check it exists.
        MOV     r0, r2
        wsaddr  r1, i_spritebuffer + 4
        ADRL    r2, file_prefix
        BL      strcpy_advance
        MOV     r2, #5
        SWI     XOS_ConvertHex4
        wsaddr  r2, i_spritebuffer + 4
        MOV     r14, #"_"
        STRB    r14, [r2, #(?file_prefix) - 1]
        BL      ExistsSprite
        ADRVSL  r2, file_xxx
        CLRV
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   regs preserved, all unsure dirs recached/deleted as necessary.

RedrawIfModified

; This shouldn't happen unless it needs to

        Entry   "r0, r1, r4"
 [ debugrecache
 DLINE  "RedrawBecauseModified"
 ]

00      ADR     r1, ViewerList - d_link ; Always start at beginning of list
                                        ; each time

01      LDR     r4, [r1, #d_link]
        CMP     r4, #Nowt               ; VClear
        BEQ     %FT90

        LDRB    r14, [r4, #d_unsure]    ; Dirty ?
        TEQ     r14, #0
        MOVEQ   r1, r4
        BEQ     %BT01

 [ debugrecache
 DREG r4, "Found dirty dir "
 ]
                                        ; r1 -> dirty dirviewer block^
        BL      RecacheDir              ; r4 -> dirty dirviewer block
        BVC     %BT00                   ; back to start, list will have changed

; Maybe it's gone away. Whatever the situation, kill the window

        STR     r0, [sp]
        LDR     r0, [r4, #d_handle]     ; Must destroy failed dirviewers
        BL      DeleteDir               ; Ignore any errors caused by this

        LDR     r0, [sp]                ; Check error number
        LDR     r0, [r0]
        BICS    r14, r0, #&FF           ; Is it 'not found' from FileSwitch ?
        MOVNE   r14, r0, LSR #16
        TEQNE   r14, #&0001             ; Is it 'not found' from filesystem ?
        BNE     %FA89
        AND     r14, r0, #&FF
        TEQ     r14, #ErrorNumber_FileNotFound
        BEQ     %BT00                   ; Its a 'File not found' - check the other viewers

89      SETV                            ; Raise unexpected error to caller
        EXIT


90      ; Everything is recached (hopefully)
 [ debugrecache
 DLINE "All dirty windows cleaned"
 ]
        EXIT


;; FindSmiWidth         finds column size for a dirviewer
;; Entry R0 is dirviewer block
;; Exit R0 is column size

FindSmiWidth
        Push    "R1-R5,lr"
        Push    "r0"
        LDR     R1,smi_width
        [ debug
        DREG    R1,"default smi width: ",,Integer
        ]
        Push    "R1"
        LDR     R3,[R0,#d_nfiles]
        ; must be non-zero
        CMP     R3,#0
        BEQ     %FT15
        ADD     R2,R0,#d_headersize
        LDR     R5,[R0,#d_filenames]
10
        MOV     R0,#1                  ; get text width/max size reason
        LDR     R4,[R2,#df_fileptr]
        Push    "R2"
 [ not_16bit_offsets
        ADD     R1,R5,R4
 |
        ADD     R1,R5,R4, LSR #16
 ]
        MOV     R2,#max_text_size-1
        SWI     XWimp_TextOp
        Pull    "R2"
        ADD     R0,R0,#6+34+8           ; gap between sprite and text
                                        ; plus sprite width+margin for error!
        LDR     R4,[sp]                 ; smi width
        CMP     R0,R4
        STRGT   R0,[sp]
        SUBS    R3,R3,#1
        ADDNE   R2,R2,#df_size
        BNE     %bt10
15
        Pull    "R0"                    ; max width of icon

        Pull    "r2"
        LDRB    r1, [r2, #d_viewmode]
        AND     r1, r1,#db_displaymode
        CMP     r1, #db_dm_smallicon      ; if small icon display, truncate.
        LDRNE   r1, fullinfo_truncation   ; full info
        LDREQ   r1, smallicon_truncation  ; small icon
        ADD     r1, r1, #34+12
        CMP     r1, r0
        MOVLT   r0, r1

16

        Pull    "R1-R5,PC"


GetSmiWidth
        Push    "lr"
        LDR     r14,[r4,#d_smiwidth]
        CMP     r14,#0
        BNE     %FT33
        Push    "R0"
        MOV     R0,r4
        BL      FindSmiWidth
        STR     R0,[r4,#d_smiwidth]
        [ debug
        DREG    R0,"invalid smi width, new width= ",,Integer
        ]
        MOV     r14,R0
        Pull    "R0"
33
        Pull    "PC"

GetSmiWidth_r11
        Push    "lr"
        LDR     r11,[r4,#d_smiwidth]
        CMP     r11,#0
        BNE     %FT33
        Push    "R0"
        MOV     R0,r4
        BL      FindSmiWidth
        STR     R0,[r4,#d_smiwidth]
        [ debug
        DREG    R0,"invalid smi width, new width= ",,Integer
        ]
        MOV     r11,R0
        Pull    "R0"
33
        Pull    "PC"



;; FindLgiWidth         finds column size for a dirviewer
;; Entry R0 is dirviewer block
;; Exit R0 is column size

FindLgiWidth
        Push    "R1-R5,lr"
        LDR     R1,lgi_width
        [ debug
        DREG    R1,"default lgi width: ",,Integer
        ]
        Push    "R1"
        LDR     R3,[R0,#d_nfiles]
        ; must be non-zero
        CMP     R3,#0
        BEQ     %FT15
        ADD     R2,R0,#d_headersize
        LDR     R5,[R0,#d_filenames]
10
        MOV     R0,#1                   ; get text width reason
        LDR     R4,[R2,#df_fileptr]
 [ not_16bit_offsets
        ADD     R1,R5,R4
 |
        ADD     R1,R5,R4, LSR #16
 ]
        Push    "R2"
        MOV     R2,#0
        SWI     XWimp_TextOp
        Pull    "R2"
        
        ADD     R0,R0,#8                ; add error margin for oblique text - Colin Granville 18-Sep-2007
        LDR     R4,[sp]                 ; lgi width
        CMP     R0,R4
        STRGT   R0,[sp]
        SUBS    R3,R3,#1
        ADDNE   R2,R2,#df_size
        BNE     %bt10
15
        Pull    "R0"                    ; max width of icon
        LDR     r1, largeicon_truncation
        CMP     r1, r0
        MOVLT   r0, r1

        Pull    "R1-R5,PC"

GetLgiWidth
        Push    "lr"
        LDR     r14,[r4,#d_lgiwidth]
        CMP     r14,#0
        BNE     %FT33
        Push    "R0"
        MOV     R0,r4
        BL      FindLgiWidth
        STR     R0,[r4,#d_lgiwidth]
        [ debug
        DREG    R0,"invalid lgi width, new width= ",,Integer
        ]
        MOV     r14,R0
        Pull    "R0"
33
        Pull    "PC"

GetLgiWidth_r11
        Push    "lr"
        LDR     r11,[r4,#d_lgiwidth]
        CMP     r11,#0
        BNE     %FT33
        Push    "R0"
        MOV     R0,r4
        BL      FindLgiWidth
        STR     R0,[r4,#d_lgiwidth]
        [ debug
        DREG    R0,"invalid lgi width, new width= ",,Integer
        ]
        MOV     r11,R0
        Pull    "R0"
33
        Pull    "PC"

        [ {TRUE}
; uses a cache to maintain filetypes
; In R2 is filetype (bits 0-11), out R2,R3 is type string, R0 corrupted

getfile_type
        Push    "R8,lr"
        MOV     R8,R2
        LDR     R14,filetype_cache
        TEQ     R14,#0
        BNE     %FT05
        MOV     R0,#ModHandReason_Claim
        MOV     R3,#64                          ; first level look up is 16 words
        SWI     XOS_Module
        STRVC   R2,filetype_cache
        MOVVC   R14,R2
        BVS     getfile_type_error
        ADD     R0,R2,R3
        MOV     R3,#0
03
        STR     R3,[R0,#-4]!                    ; clear the area
        TEQ     R0,R2
        BNE     %BT03
05
        MOV     R2,R8, LSL #20                  ; make sure top bits clear
        ADD     R14,R14,R2, LSR #26
        BIC     R14,R14,#3
        LDR     R3,[R14]                        ; first level lookup
        TEQ     R3,#0
        BNE     %FT10
        Push    "R2,R14"
        MOV     R0,#ModHandReason_Claim
        MOV     R3,#64
        SWI     XOS_Module
        Pull    "R2,R14",VS
        BVS     getfile_type_error

        ADD     R0,R2,R3
        MOV     R3,#0
08
        STR     R3,[R0,#-4]!                    ; clear the area
        TEQ     R0,R2
        BNE     %BT08

        MOV     R3,R2
        Pull    "R2,R14"

        STR     R3,[R14]
10
        AND     R2,R2,#&0ff00000                ; don't need those bits anymore
        ADD     R14,R3,R2, LSR #22
        BIC     R14,R14,#3
        LDR     R3,[R14]
        TEQ     R3,#0
        BNE     %FT15

        Push    "R2,R14"
        MOV     R0,#ModHandReason_Claim
        MOV     R3,#128                         ; 16 filetypes 8 bytes each
        SWI     XOS_Module
        Pull    "R2,R14",VS
        BVS     getfile_type_error

        ADD     R0,R2,R3
        MOV     R3,#0
13
        STR     R3,[R0,#-4]!                    ; clear the area
        TEQ     R0,R2
        BNE     %BT13

        MOV     R3,R2
        Pull    "R2,R14"

        STR     R3,[R14]
15
        AND     R2,R2,#&00f00000
        LDR     R2,[R3,R2, LSR #17]!
        TEQ     R2,#0                           ; already there
        LDRNE   R3,[R3,#4]
        Pull    "R8,PC",NE
        MOV     R2,R8
        MOV     R8,R3
        MOV     R0,#18
        SWI     XOS_FSControl
        STMVCIA R8,{R2,R3}
        Pull    "R8,PC"

getfile_type_error
        CLRV
        MOV     R0,#18
        MOV     R2,R8
        SWI     XOS_FSControl

        Pull    "R8,PC"

invalidate_filetypes
        Push    "lr"
        LDR     R14,filetype_cache
        TEQ     R14,#0
        Pull    "PC",EQ
        Push    "R0-R5"
        ADD     R0,R14 ,#64
outer_loop
        LDR     R1,[R0,#-4]!
        TEQ     R1,#0
        TEQEQ   R0,R14
        Pull    "R0-R5,PC",EQ
        TEQ     R1,#0
        BEQ     outer_loop
        ADD     R2,R1,#64
inner_loop
        LDR     R3,[R2,#-4]!
        TEQ     R3,#0
        TEQEQ   R1,R2
        TEQEQ   R0,R14
        Pull    "R0-R5,PC",EQ
        TEQ     R1,R2
        TEQEQ   R3,#0
        BEQ     outer_loop
        TEQ     R3,#0
        BEQ     inner_loop
        ADD     R4,R3,#128
        MOV     R5,#0
splat_loop
        STR     R5,[R4,#-8]!
        TEQ     R4,R3
        BNE     splat_loop
        TEQ     R1,R2
        TEQEQ   R0,R14
        Pull    "R0-R5,PC",EQ
        TEQ     R1,R2
        BNE     inner_loop
        B       outer_loop

        ]


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; truncate_filename
;
; Take a filename in and output the truncated version (including ellipsis).
;
; In:   r6 -> filename
;       r7 -> icon buffer
;       r8 =  maximum width, in millipoints
;
; Out:  r10, r11 corrupted
;       All other regs preserved.

truncate_filename Entry "r0-r5"

        MOV     r1, r8
        MOV     r2, #0
        SWI     XFont_ConverttoOS
        MOV     r4, r1
        MOV     r3, #i_textbuffer_size
        MOV     r2, r7
        MOV     r1, r6
        MOV     r0, #4
        SWI     XWimp_TextOp
        EXIT    VC

        ; Drop back to our own (broken) code if this fails...

        ; Set font to desktop font
        MOV     r0, #8
        SWI     XWimp_ReadSysInfo
        CMP     r0, #0            ; If system font, skip to different routine
        BEQ     %FT30
        SWI     XFont_SetFont

        ; Where would we need to split the string to fit the maximum width?
        MOV     r1, r6
        MOV     r2, r8
        MOV     r3, r8
        MOV     r4, #-1
        MOV     r5, #256
        SWI     XFont_StringWidth
        MOV     r10, r4

        ; Now find the length of the filename string
        MOV     r1, r6
        BL      strlen
        MOV     r11, r3

        ; If the string is split before end of length, then find the new split size, taking
        ; into account the ellipsis character which we will add.
        CMP     r11, r10
        BLE     %FT20
        MOV     r1, r6
        LDR     r3, ellipsis_width
        SUB     r2, r8, r3
        MOV     r3, r8
        MOV     r4, #-1
        MOV     r5, #256
        SWI     XFont_StringWidth
        MOV     r10, r4

20      ; Copy string (upto split character) to icon buffer
        MOV     r0, r7
        MOV     r1, r6
        MOV     r2, r10
24
        LDRB    r14, [r1], #1
        STRB    r14, [r0], #1
        SUBS    r2, r2, #1
        BNE     %BT24

        ; If necessary, add ellipsis character
        CMP     r11, r10
        MOVGT   r14, #140
        STRGTB  r14, [r0], #1
        MOV     r14, #CR
        STRB    r14, [r0], #1

        EXIT

30 ; Deal with system font

        ; Covert millipoints back to OS units
        ; Shift right 5 to divide by 32 and find number of characters
        ; If less than string width, subtract 1 and add ellipsis.
        MOV     r1, r8
        MOV     r2, #0
        SWI     XFont_ConverttoOS    ; this returns max width in OS units
        MOV     r0, r1, LSR #4       ; divide max width by 16 to get number of chars

        MOV     r1, r6
        BL      strlen
        MOV     r11, r3              ; r11 = length of string
        MOV     r10, r3              ; r10 = how many characters we'll display (try for whole length)
        CMP     r10, r0              ; see if whole length will fit
        SUBGT   r10, r0, #1          ; if not, put max characters-1 (we'll ad an ellipsis)

        ; Copy string (upto split character) to icon buffer
        MOV     r0, r7
        MOV     r1, r6
        MOV     r2, r10
34
        LDRB    r14, [r1], #1
        STRB    r14, [r0], #1
        SUB     r2, r2, #1
        CMP     r2, #0
        BGT     %BT34

        ; If necessary, add ellipsis character
        CMP     r11, r10
        MOVGT   r14, #140
        STRGTB  r14, [r0], #1
        MOV     r14, #CR
        STRB    r14, [r0], #1

        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; read_font_widths
;
; Read some widths needed by the truncation code

ellipsis_str DCB "�",0

read_font_widths Entry "r0-r6"

        ; Set font to desktop font
        MOV     r0, #8
        SWI     XWimp_ReadSysInfo
        CMP     r0, #0
        SWINE   XFont_SetFont

        ; What's the width of an ellipsis in the current font?
        ADR     r1, ellipsis_str
        MOV     r2, #71680
        ADD     r2, r2, #320
        MOV     r3, r2
        MOV     r4, #-1
        MOV     r5, #1
        SWI     XFont_StringWidth
        STR     r2, ellipsis_width

        ; What's the large icon maximum width allowed, in millipoints?
        LDR     r1, largeicon_truncation
        MOV     r2, #0
        SWI     XFont_Converttopoints
        STR     r1, largeicon_truncation_mp

        ; What's the small icon maximum width allowed, in millipoints?
        LDR     r1, smallicon_truncation
        MOV     r2, #0
        SWI     XFont_Converttopoints
        STR     r1, smallicon_truncation_mp

        ; What's the full info maximum width allowed, in millipoints?
        LDR     r1, fullinfo_truncation
        MOV     r2, #0
        SWI     XFont_Converttopoints
        STR     r1, fullinfo_truncation_mp

        EXIT

        END
