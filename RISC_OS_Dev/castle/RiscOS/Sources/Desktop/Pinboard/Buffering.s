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
; > s.Buffering

;       Insert a TinyDirs icon to the buffered list
insert_tinydirs
        Push    "R0-R11,LR"
; Get buffer space for it
        MOV     r3, #icon_filename+20
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        ADDVS   sp, sp, #4
        Pull    "R1-R11,PC",VS
; R2=pointer to it. Add it to list at the end.
        ADR     r0, buffered_ptr
01
        LDR     r1, [r0,#next_ptr]
        CMP     r1, #0
        MOVGT   r0, r1
        BGT     %BT01
        STR     r2, [r0,#next_ptr]
        STR     r0, [r2,#prev_ptr]
        MOV     r0,#0
        STR     r0, [r2,#next_ptr]
; Store data
        MOV     r11, #insert_tinydir
        STR     r11,[r2,#icon_handle]
        MOV     r0, #0
        STR     r0, [r2,#icon_filename]
        Pull    "R0-R11,PC"

directory_store
        DCB     "Sdirectory",0
        ALIGN
application_store
        DCB     "Sapplication",0
        ALIGN
standard_name
unknown_store
        DCB     "Sfile_xxx",0
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
;       Install an icon on the iconbar
;               R4 - pointer to entry in list of icons
;               R2 - &FF if to insert to left of icon handle (version 003 upwards)
;       Returns R0 = icon handle (or error pointer if V set)
install_icon
        Push    "R1-R11,LR"
; Check for to left or to right of
        CMP     r2, #&ff
        MOVEQ   r7, #-3
        MOVNE   r7, #-4
        LDR     r8, [r4,#icon_handle]
        Debug   pi,"Icon handle is ",r8
        CMP     r8, #insert_pinboard
        MOVEQ   r7, #0
        ADD     r8, r4, #icon_position
; Give it an icon id
        LDR     r1, monotonic_icon_id
        STR     r1, [r4,#icon_id]
        ADD     r1, r1, #1
        STR     r1, monotonic_icon_id
; Get R9 -> Leafname of file
        ADD     r0, r4, #icon_filename
        BL      find_leafname
        MOV     r9, r0
; Check file type for finding sprite name
        LDR     r3, [r4,#icon_filetype]
        CMP     r3, #-1         ;       Unstamped files
        ADREQ   r0, unknown_store
        MOVEQ   r10, #1
        BEQ     copy_spritename
        CMP     r3, #&1000
        BGE     get_directory_sprite
; Icon is of type 'file'
        ADR     r0, standard_name
        LDMIA   r0, {r1,r2}
        ADD     r0, r4, #icon_spritename
        STMIA   r0, {r1,r2}
        ADD     r1, r0, #5      ;       Ignore Sfile
        MOV     r0, r3
        MOV     r2, #32
        SWI     XOS_ConvertHex4
        MOV     r0, #"_"
        STRB    r0, [r4, #icon_spritename+5]
        ADD     r10, r4, #icon_spritename+1
        B       check_sprite_is_known

; Icon is of type directory or application
get_directory_sprite
        LDRB    r0, [r9]
        CMP     r0, #"!"
        ADRNE   r0, directory_store
        MOVNE   r10, #1
        BNE     copy_spritename

; Icon is an application. Try 'Filer_Boot'ing it.
        MOV     r0, #&2000
        STR     r0, [r4, #icon_filetype]
        ADR     r0, dataarea
        ADR     r1, filer_boot_store
        BL      copystr_r0r1_usingr2
        ADD     r1, r4, #icon_filename
        BL      copystr_r0r1_usingr2
        ADR     r0, dataarea
        SWI     XOS_CLI
        SUBS    r0, r9, #0      ;       Clears V
        MOV     r10, #0
copy_spritename
        ADD     r3, r4, #icon_spritename
        CMP     r10, #0
        MOVEQ   r2, #"S"
        STREQB  r2, [r3], #1
        MOV     r2, r0
01
        LDRB    r1, [r2], #1
        STRB    r1, [r3], #1
        CMP     r1, #32
        BGT     %BT01
        ADD     r10, r4, #icon_spritename+1
        B       check_sprite_is_known
; Valid registers : R4 -> icon block, R9 -> leafname, R10 -> sprite name
check_sprite_is_known
        MOV     r11, r4
        MOV     r2, r10
        MOV     r0, #SpriteReason_ReadSpriteSize
        SWI     XWimp_SpriteOp
        BVC     sprite_is_known
; Unknown sprite (bad filetype,unknown application icon)
        LDR     r2, [r11,#icon_filetype]
        CMP     r2, #&1000
        ADRGE   r2, application_store
        ADRLT   r2, unknown_store
        ADD     r3, r11, #icon_spritename
01
        LDRB    r1, [r2], #1
        STRB    r1, [r3], #1
        CMP     r1, #32
        BGT     %BT01
        ADD     r2, r11, #icon_spritename+1
        MOV     r0, #SpriteReason_ReadSpriteSize
        SWI     XWimp_SpriteOp
; Valid registers r6 = sprite mode, r3,r4 = sprite width,height, r9->icon name,r10->sprite name,r11->icon
; Adjust to get OS units
sprite_is_known
        MOVVC   r0, r6                          ; creation mode of sprite
        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r5, r3, LSL r2
        MOVVC   r3, #0
        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        Pull    "R1-R11,PC",VS
        MOV     r6, r4, LSL r2
        ADD     r6, r6, #20
        MOV     r4, #-16
; Check length of name
        MOV     r0, #0
01
        LDRB    r1,[r9,r0]
        ADD     r0, r0, #1
        CMP     r1,#32
        BGT     %BT01
        SUB     r0, r0, #1
        CMP     r5, r0, LSL#4
        MOVLT   r5, r0, LSL#4
; Get flags and name
        ADR     r1, dataarea
        LDR     r0, [r11,#icon_handle]
        TEQ     r0, #0
        MOVPL   r0, r7
        MOVMI   r0, #-2
        STMIA   r1!, {r0,r3,r4,r5,r6}
        LDR     r6, icon_flags
        ADD     r10, r11, #icon_spritename
        MOV     r14, #32
        STMIA   r1!, {r6,r9,r10,r14}
; Create the icon
        ADR     r1,dataarea             ; create iconbar entry
        CMP     r7,#0
        LDREQ   r0,backdrop_handle
        STREQ   r0,[r1],#4
        LDMEQIA r1,{r3-r6}
        LDREQ   r9,[r8,#4]
        LDREQ   r8,[r8]
        ADDEQ   r3,r3,r8
        SUBEQ   r3,r3,r5, LSR #1
        ADDEQ   r4,r4,r9
        ADDEQ   r5,r3,r5
        ADDEQ   r6,r6,r9
        SUBEQ   r14,r6,r4
        SUBEQ   r4,r4,r14,LSR #1
        SUBEQ   r6,r6,r14,LSR #1
        LDREQ   r8,pinboard_icon_flags
        BLEQ    lock_to_grid
        STMEQIA r1,{r3-r6,r8}
        Debug   pi,"Bounding box is ",r3,r4,r5,r6
        SUBEQ   r1,r1,#4
        LDR     r0, [r11,#icon_handle]
        SWI     XWimp_CreateIcon
        ADR     r1,dataarea
        STR     r0,[r1,#4]
        MOV     r8,#0
        STR     r8,[r1,#8]
        STR     r8,[r1,#12]
        MOV     r8,r0
        SWI     XWimp_SetIconState
        MOV     r0,r8
        LDRVC   r1, monotonic_icon_id
        STRVC   r1, [r11,#icon_id]
        ADDVC   r1, r1, #1
        STRVC   r1, monotonic_icon_id
; Return the icon handle
        Pull    "R1-R11,PC"
icon_flags
        DCD     &1700A50B
pinboard_icon_flags
        DCD     &0700A50B
filer_boot_store
        DCB     "Filer_Boot "
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
;       Delete an icon from the active list (even if it is the DeskApps icon). Internal use only
;               R4 - pointer to entry in list of icons
delete_icon_whatever
        Push    "R0-R5,LR"
        B       do_delete_icon
; ----------------------------------------------------------------------------------------------------------------------
;       Delete an icon from the active list
;               R4 - pointer to entry in list of icons
delete_icon
        EntryS  "r0-r5"
; Decrement number of icons
do_delete_icon
        LDR     r0, [r4,#icon_window]
        TEQ     r0, #0
        LDREQ   r0, no_icons
        LDRNE   r0,pinboard_no_icons
        SUB     r0, r0, #1
        STRNE   r0, pinboard_no_icons
        STREQ   r0, no_icons
; Get previous and next icons
        LDR     r0, [r4,#prev_ptr]
        LDR     r1, [r4,#next_ptr]
; If at front of list then previous pointer is pointer to start of list
        CMP     r0, #0
        ADRLE   r0, active_ptr
; If at end of list then don't affect the next icon (coz there isn't one)
        CMP     r1, #0
; Adjust the pointers
        STR     r1, [r0,#next_ptr]
        STRGT   r0, [r1,#prev_ptr]
; Now delete the icon
        ADR     r1, dataarea
        LDR     r0, [r4,#icon_window]
        CMP     r0, #0
        MOVEQ   r0, #-1
        STR     r0, [r1]
        LDR     r2, [r4,#icon_handle]
        STR     r2, [r1,#4]
        CMP     r2, #0
        SWIGE   XWimp_GetIconState
        SWIVC   XWimp_DeleteIcon

        MOVVC   r5,r4
        ADDVC   r1,r1,#8
        LDRVC   r0,backdrop_handle
        LDMVCIA r1,{r1-r4}
        SWIVC   Wimp_ForceRedraw

; Now free the block
        MOV     r0, #ModHandReason_Free
        MOV     r2, r5
        SWI     XOS_Module

        STRVS   r0, [sp, #Proc_RegOffset]
; Return, preserving the flags (in case was called as result of an error)
        EXITS   VC
        EXIT

; ----------------------------------------------------------------------------------------------------------------------
;       Find an icon from the active list
;               R0 = icon handle
;               R1 = Window handle ( 0 = Icon bar)
;       Returns R1 -> icon block, or 0 for not found
find_icon
        EntryS  "R0,R2,R3,R4"

        Debug   pi,"Find icon"

        MOV     r3,r1

        LDR     r1, active_ptr
01
        CMP     r1, #0
        EXITS   LE
        LDR     r2, [r1,#icon_handle]
        LDR     r4, [r1,#icon_window]
        Debug   pi,"search for (i,w) , current is (i,w)",r0,r3,r2,r4
        CMP     r0, r2
        CMPEQ   r3, r4
        LDRNE   r1, [r1,#next_ptr]
        BNE     %BT01
        EXITS
; ----------------------------------------------------------------------------------------------------------------------
;       Find the leafname of a file. Preserves the flags
;               R0 = full pathname
find_leafname
        Push    "R1-R2,LR"
        MOV     r1,r0
01
        LDRB    r2,[r0],#1
        CMP     r2,#"."
        MOVEQ   r1,r0
        CMP     r2,#32
        BGT     %BT01
        MOV     r0,r1
        Pull    "R1-R2,PC"
; ----------------------------------------------------------------------------------------------------------------------
;       Release linked lists of files/icons. Note - may be in USER mode or SVC mode - can't use USER stack,
;       though, as it may not be okay. Hence not allowed to use the stack at all.
;    R2 -> pointer to start of list to kill (active_ptr or buffered_ptr)
;        DANGER - CORRUPTS R0-R3
free_list
        MOV     R3, LR
        LDR     r1, [r2,#next_ptr]
        MOV     r0, #0
        STR     r0, [r2,#next_ptr]
; Get next file in the list
01
        MOV     r0, #ModHandReason_Free
        SUBS    r2, r1, #0
        MOVLE   PC, R3
; Free the workspace
        LDR     r1, [r2,#next_ptr]
        SWI     XOS_Module
        B       %BT01
; ----------------------------------------------------------------------------------------------------------------------
; Find iconized.
;         r6 = Icon number.
; On Exit:
;         r7 - Pointer to block or 0 if not found.
;
find_iconized
        Push    "LR"


        LDR     r7,iconized_ptr
01      CMP     r7,#0
        Pull    "PC",EQ
        LDR     r14,[r7,#w_icon_handle]
        CMP     r14,r6
        LDRNE   r7,[r7,#w_next_ptr]
        BNE     %BT01

        Pull    "PC"

; ----------------------------------------------------------------------------------------------------------------------
; Find iconized icon by window handle.
;         r5 = Window handle.
; On Exit:
;         r7 - Pointer to block or 0 if not found.
;
find_window
        Push    "LR"

        LDR     r7,iconized_ptr
01      CMP     r7,#0
        Pull    "PC",EQ
        LDR     r14,[r7,#w_window_handle]
        CMP     r14,r5
        LDRNE   r7,[r7,#w_next_ptr]
        BNE     %BT01

        Pull    "PC"
; ----------------------------------------------------------------------------------------------------------------------
; Find iconized icon by task handle.
;         r5 = Task handle.
; On Exit:
;         r7 - Pointer to block or 0 if not found.
;
find_task
        Push    "LR"

        LDR     r7,iconized_ptr
01      CMP     r7,#0
        Pull    "PC",EQ
        LDR     r14,[r7,#w_task]
        CMP     r14,r5
        LDRNE   r7,[r7,#w_next_ptr]
        BNE     %BT01

        Pull    "PC"

; ----------------------------------------------------------------------------------------------------------------------
; pre quit - reopen all iconized windows.
;            delete backdrop sprite.
pre_quit

        Push     "LR"

01      LDR      r7,iconized_ptr
        CMP      r7,#0
        BEQ      %FT02
        BL       reopen_window   ; Shifts the list for us.
        B        %BT01
02
; Delete backdrop sprite

        MOV     r0,#SpriteReason_DeleteSprite
        ADRL    r2,backdrop_spritename
        SWI     XOS_SpriteOp

        LDRVC   r2,screen_size
        RSBVC   r1,r2,#0
        MOVVC   r0,#3                   ; Change sprite area
        SWIVC   XOS_ChangeDynamicArea   ; Get the memory we need.

        LDRVC   r0,backdrop_handle
        MOVVC   r1,#1 :SHL: 31
        MOVVC   r2,r1
        MOVVC   r3,#&100000
        MOVVC   r4,r3
        SWIVC   XWimp_ForceRedraw


        MOV     r0,#0
        STR     r0,backdrop_path



        Pull    "PC"

; ----------------------------------------------------------------------------------------------------------------------
; lock_to_grid
;   lock bounding box in r3-r6 to grid (if it is active)
;   also checks to see if icon would be below iconbar (NK)
;
grid_x_spacing  *       192
grid_y_spacing  *       128

lock_to_grid
        EntryS   "r0-r2,r7-r9"
        LDR      R14,icon_bar_height
        SUBS     R14,R14,R6
        ADDPL    R6,R6,R14
        ADDPL    R4,R4,R14
        LDR      r14,grid_lock
        CMP      r14,#0
        EXIT     EQ                             ; Not active

        SUB      r5,r5,r3
        SUB      r6,r6,r4
        Round    r3,r3,#grid_x_spacing          ; 12 characters
        Round    r4,r4,#grid_y_spacing

        CMP      r3,#0            ; Off the screen ?
        ADDLT    r3,r3,#grid_x_spacing       ; Next grid position.
        CMP      r4,#133          ; Under icon bar ?
        ADDLT    r4,r4,#grid_y_spacing       ; next grid position.

        RSB      r14,r5,#grid_x_spacing
        Debug    ic, "r5 is ",r5
        ADD      r3,r3,r14,LSR #1 ; Centre in grid box.

        ADD      r5,r5,r3
        ADD      r6,r6,r4

        ADR      r14,bounding_box+8
        LDMIA    r14,{r0,r1}

        CMP      r5,r0
        SUBGT    r3,r3,#grid_x_spacing
        SUBGT    r5,r5,#grid_x_spacing

        CMP      r6,r1
        SUBGT    r6,r6,#grid_y_spacing
        SUBGT    r4,r4,#grid_y_spacing

        Debug    ic,"Find next free ",r3

        BL       find_next_free

        Debug    ic,"find_next_free returned"

        EXITS

; ----------------------------------------------------------------------------------------------
; find_next_free
;
; Find next free location to place icon
; original bounding box is in r3-r6
find_next_free

        EntryS   "r0-r1"

01
        Debug    ic,"Check free position"
        BL       chk_free_position
        Debug    ic,"Check free position returned"
        EXITS    VC

        ADD      r3,r3,#grid_x_spacing
        ADD      r5,r5,#grid_x_spacing

        ADR      r14,bounding_box+8
        LDMIA    r14,{r0,r1}            ; Max x, Max y.

        CMP      r5,r0
        SUBGT    r5,r5,r3
        RSBGT    r3,r5,#grid_x_spacing
        MOVGT    r3,r3,LSR #1
        ADDGT    r5,r5,r3
        SUBGT    r4,r4,#grid_y_spacing
        SUBGT    r6,r6,#grid_y_spacing
        B        %BT01

;
;-----------------------------------------------------------------------------------------------
; chk_free_position
;
; Check that the position in r3,r4 does not contain an icon (only works for grid locked icons)
if_selected     *   1 :SHL: 20
chk_free_position

        Push   "r0-r2,r3,LR"

        Round    r3,r3,#grid_x_spacing

        Debug   ic,"Position: ",r3,r4

        LDR     r0,active_ptr
01
        CMP     r0,#0
        BLE     chk_iconized

        Debug   ic,"icons in list"
        LDR     r1,backdrop_handle
        LDR     r14,[r0,#icon_window]
        CMP     r1,r14
        BNE     %FT02

        Debug   ic,"On backdrop."
        ADRL    r1,dataarea+60
        LDR     r14,backdrop_handle
        STR     r14,[r1]
        LDR     r14,[r0,#icon_handle]
        STR     r14,[r1,#4]
        Push    "r0"
        SWI     XWimp_GetIconState
        Pull    "r0"

        LDR     r14,drag_icon            ; Is this as a result of a drag
        SUB     r14,r14,#&10000
        LDR     r2,[r0,#icon_handle]
        CMP     r14,r2
        LDREQ   r2,drag_window           ; Get icon flags
        LDREQ   r14,drag_window
        CMPEQ   r14,r2
        BEQ     %FT02                    ; Ignore selected icons, thy are being moved.

        LDR     r14,[r1,#8]
        Round   r14,r14,#grid_x_spacing
        Debug   sp,"icon's x ",r14
        CMP     r14,r3
        BNE     %FT02

        LDR     r14,[r1,#12]
        Round   r14,r14,#grid_y_spacing
        Debug   sp,"icon's y ",r14
        CMP     r14,r4
        BEQ     not_free

02
        Debug   ic,"Next icon"
        LDR     r0,[r0,#w_next_ptr]
        B       %BT01

chk_iconized
        LDR     r0,iconized_ptr
01
        CMP     r0,#0
        BLE     free

        Debug   ic,"windows in list"

        ADRL    r1,dataarea+60
        LDR     r14,backdrop_handle
        STR     r14,[r1]
        LDR     r14,[r0,#w_icon_handle]
        CMP     r14,#0
        BLT     %FT02

        STR     r14,[r1,#4]
        Push    "r0"
        SWI     XWimp_GetIconState
        Pull    "r0"

        LDR     r14,[r1,#8]
        Round   r14,r14,#grid_x_spacing
        CMP     r14,r3
        BNE     %FT02

        LDR     r14,[r1,#12]
        Round   r14,r14,#grid_y_spacing
        CMP     r14,r4
        BEQ     not_free
02
        LDR     r0,[r0,#w_next_ptr]
        B       %BT01

not_free
        Debug   ic,"Not free"
        SETV
free
        Pull    "r0-r2,r3,PC"



        LNK     Tail.s
