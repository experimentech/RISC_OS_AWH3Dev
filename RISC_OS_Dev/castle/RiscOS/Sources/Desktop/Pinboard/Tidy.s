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
; s.Tidy
; Tidying and placing of icons

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; tidy_icons
;
; Tidies either the file icons or the window icons. Which is done depends
; on the value PinboardFlag_UseWindowList (set tidy window icons, clear
; tidy file icons).
;
; In:  Nothing.
;
; Out: All regs preserved.

tidy_icons Entry "r0-r11"

        MOV     r9, sp                              ; r9 is now data pointer

        LDR     r8, Pinboard_options
        TST     r8, #PinboardFlag_PinboardFull
        BICNE   r8, r8, #PinboardFlag_PinboardFull  ; Assume pinboard isn't yet full
        ORR     r8, r8, #PinboardFlag_SkipSelected
        STR     r8, Pinboard_options

        ; Decide starting position
        BL      decide_list_origin                  ;
        BL      tidy_find_next_free                 ;

        ; Where's the icon data?
        TST     r8, #PinboardFlag_UseWindowList     ;
        LDRNE   r11, iconized_ptr                   ; First window icon in list
        LDREQ   r11, Icon_list                      ; First file icon in list

        ; Now, go through all the icons and move them, if selected.
50      CMP     r11, #0                             ; have we reached the end of list?
        EXIT    EQ

        LDR     r0, backdrop_handle
        LDR     r1, [r11, #ic_window]
        CMP     r0, r1                              ; is the next icon on the backdrop?
        BNE     %FT70

        BL      tidy_move_icon_if_selected          ; move icon, if selected.
        BLEQ    tidy_find_next_icon_space           ; if we've moved an icon, find where to put next

70      LDR     r11, [r11, #ic_next]                ; find next icon data block
        B       %BT50

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; tidy_find_next_icon_space
;
; Where will the next icon we tidy go?
;
; In: r3, r4 = x and y co-ordinates of current grid position.
;
; Out: r3, r4 = x and y co-ordinates of next free grid position.

tidy_find_next_icon_space Entry "r0-r2"

        ; Find the next grid position
        TST     r8, #PinboardFlag_UseWindowList
        MOVEQ   r2, r8, LSR #3                  ; shift the flags if files, so they look like
        MOVNE   r2, r8                          ; window flags.
        BL      find_next_x_and_y
        BNE     %FT10                           ; NE if the screen was filled up with this call

        ; If the screen is already full, then we don't bother to check for clashes anymore
        TST     r8, #PinboardFlag_PinboardFull
        EXIT    NE

        ; Screen not full - try and find the next free space
        BL      tidy_find_next_free
        EXIT    EQ

        ; The screen is now full - reset to origin
10      ORR     r8, r8, #PinboardFlag_PinboardFull
        STR     r8, Pinboard_options
        BL      decide_list_origin
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; decide_list_origin
;
; Decide where the origin of a list is. By that we mean the x and y
; co-ordinates of the grid position of the corner where the list starts.
;
; In: Nothing.
;
; Out: r3, r4 = x and y co-ordinates of start grid position.

decide_list_origin Entry "r0-r2, r5-r6"

        LDR     r5, Pinboard_options                 ; Pinboard options
        ADR     r0, bounding_box                     ; Screen bouding box

        TST     r5, #PinboardFlag_UseWindowList      ; check which we're working on
        MOVNE   r14, #PinboardOption_WinToCornerLR   ; if windows, then we'll test WinToCornerLR bit
        MOVEQ   r14, #PinboardOption_TidyToCornerLR  ; if files, then we'll test TidyToCornerLR bit
        TST     r5, r14                              ; test the bit, 0 = Left (EQ), 1 = Right (NE)
        LDR     r1, [r0, #8]                         ; Decide on initial left/right positioning
        MOVEQ   r3, #0                               ;
        MOVNE   r14, #grid_x_spacing                 ;
        SUBNE   r3, r1, r14                          ;

        TST     r5, #PinboardFlag_UseWindowList      ; check which we're working on
        MOVNE   r14, #PinboardOption_WinToCornerTB   ; if windows, then we'll test WinToCornerTB bit
        MOVEQ   r14, #PinboardOption_TidyToCornerTB  ; if files, then we'll test TidyToCornerTB bit
        TST     r5, r14                              ; test the bit, 0 = Top (EQ), 1 = Bottom (NE)
        LDR     r1, [r0, #12]                        ; Decide on initial up/down positioning
        MOVEQ   r14, #grid_y_spacing                 ;
        SUBEQ   r4, r1, r14                          ;
        LDRNE   r4, icon_bar_height                  ;

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; tidy_move_icon_if_selected
;
; Check if icon whose details are in the structure in r11 is selected and
; if so, move it to the grid co-ordinates pointed to by r2, r3.
;
; In: r3, r4 = x, y grid co-ordinate to move to
;     r11 -> icon data structure
;
; Out: NE = didn't move icon
;      EQ = did move icon.

tidy_move_icon_if_selected Entry "r0-r10"

        SUB     sp, sp, #48                     ; Use stack for temporary storage.
        MOV     r1, sp                          ; -> temporary workspace

        MOV     r2, r3                          ;
        MOV     r3, r4                          ;

        LDR     r9, backdrop_handle             ;
        LDR     r8, Pinboard_options            ;

        ; If pinboard full, we offset the icons a little
        TST     r8, #PinboardFlag_PinboardFull
        MOVNE   r10, #(grid_x_spacing/2)
        MOVEQ   r10, #0

        ; Get the current wimp state of the icon
        STR     r9, [r1]                        ; Backdrop handle
        LDR     r0, [r11, #ic_icon]             ; Icon handle
        STR     r0, [r1, #4]                    ;
        SWI     XWimp_GetIconState              ;
        BVS     %FT10                           ;

        ; We'll only move it if it's selected
        LDR     r0, [r1, #24]                   ; icon flags
        TST     r0, #is_selected                ;
        BEQ     %FT10                           ;

        ; Resize it...
        LDR     r4, [r1, #8]                    ; How wide is the icon?
        LDR     r5, [r1, #16]                   ;
        SUB     r6, r5, r4                      ;
        LDR     r4, [r1, #12]                   ; How tall is the icon?
        LDR     r5, [r1, #20]                   ;
        SUB     r7, r5, r4                      ;

        MOV     r0, #grid_x_spacing             ; Adjust for centre alignment
        SUBS    r1, r0, r6                      ; x1
        ADDPL   r2, r2, r1, LSR #1              ; x2
        SUBMI   r1, r6, r0                      ;
        SUBMI   r2, r2, r1, LSR #1              ;

        ADD     r4, r2, r6                      ; x2

        MOV     r0, #grid_y_spacing             ; Adjust for centre alignment
        SUBS    r1, r0, r7                      ; y1
        ADDPL   r3, r3, r1, LSR #1              ; y2
        SUBMI   r1, r7, r0                      ;
        SUBMI   r3, r3, r1, LSR #1              ;

        ADD     r5, r3, r7                      ; y2

        ADD     r2, r2, r10                     ; icon offset if pinboard full
        ADD     r4, r4, r10                     ; icon offset if pinboard full

        TST     r8, #PinboardFlag_UseWindowList ; are we tidying window icons?
        STREQ   r2, [r11, #ic_x]                ; if not, store x and store y
        STREQ   r3, [r11, #ic_y]                ;

        MOV     r0, r9                          ; r0 = backdrop handle
        LDR     r1, [r11, #ic_icon]             ; r1 = icon handle
        SWI     XWimp_ResizeIcon                ; Move icon to new x and y
        BVS     %FT10

        ; Change its state so it is no longer selected
        ; (this will also redraw icon at new position)
        MOV     r1, sp                          ;
        MOV     r0, #is_selected                ;
        STR     r0, [r1, #8]                    ;
        MOV     r0, #0                          ;
        STR     r0, [r1, #12]                   ;
        SWI     XWimp_SetIconState              ;
        BVS     %FT10                           ;

        TST     r8, #PinboardFlag_UseWindowList ;
        LDREQ   r0, Pinboard_Selected           ;
        LDRNE   r0, Windows_Selected            ;
        SUB     r0, r0, #1                      ;
        STREQ   r0, Pinboard_Selected           ;
        STRNE   r0, Windows_Selected            ;

        ADD     sp, sp, #48                     ; exit EQ
        CMP     r8, r8
        EXIT

10      ADD     sp, sp, #48
        CMP     pc, r8                          ; exit NE
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; tidy_find_next_free
;
; Given an initial grid position, check if it's space is occupied. If it
; is, then move to the next position and try again.
;
; In: r3, r4 = x and y co-ordinates
;
; Out: r3, r4  = next free slot
;      r0 - r2 = corrupted.

tidy_find_next_free Entry

10
        LDR     r2, Pinboard_options            ;
        BL      is_something_there
        BNE     %FT20

        TST     r2, #PinboardFlag_UseWindowList ;
        MOVEQ   r2, r2, LSR #3                  ; shift the flags if files, so they look like window flags.

        BL      find_next_x_and_y
        EXIT    NE
        B       %BT10

20
        CMP     r0, r0
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; is_something_there
;
; Test if a grid position is occupied. We'll test against both lists and
; return NE if there's no icons overlapping the proposed grid position.
; Checking of selected icons is controlled by PinboardFlag_SkipSelected,
; if set selected icons will be skipped (tidying), if clear they'll be
; checked as well (iconizing).
;
; In: r3, r4 = x and y co-ordinate of grid position
;
; Out: EQ if something there, NE if not.
;      All regs. preserved.

is_something_there Entry "r2, r5-r11"

        SUB     sp, sp, #40                     ; grab some stack space to put data block
        MOV     r9, sp                          ;

        MOV     r8,#1                           ; 1 => use window icon list, 0 => use file icon list

10      ; next list
        CMP     r8,#1                           ; are we checking the window list
        LDREQ   r11, iconized_ptr               ; if so, -> first icon in window list
        LDRNE   r11, Icon_list                  ; if not, -> first icon in file icon list

20      ; next icon
        CMP     r11, #0                         ; is this the end of the linked list?
        BEQ     %FT90                           ; if so, see if we've done both lists

        BL      get_next_icon_bbox              ; get the icon's bounding box
        CMP     r10, #0                         ; icon not on backdrop if r10 is zero
        BEQ     %FT80                           ;

        TST     r2,#PinboardFlag_SkipSelected   ; should we skip selected icons?
        LDRNE   r14,[r10,#16]                   ; if not, get icon flags
        TSTNE   r14,#selected                   ; .. is the icon selected?
        BNE     %FT80                           ; .. if so, don't check this icon

        ; make r3, r4, r5, r6 the proposed bounding box.
        MOV     r14, #grid_x_spacing            ;
        ADD     r5, r3, r14                     ;
        MOV     r14, #grid_y_spacing            ;
        ADD     r6, r4, r14                     ;

        ; Check the proposed icon's left and right bounds against the current stored icon
        LDR     r7, [r10]
        CMP     r5, r7                          ; Check proposed x2 <= icon x1
        BLE     %FT80                           ; If it is, then this icon presents no problems - try next
        LDR     r7, [r10, #8]
        CMP     r3, r7                          ; Check proposed x1 >= icon x2
        BGE     %FT80                           ; If it is, then this icon presents no problems - try next

        ; Check the proposed icon's top and bottom bounds against the current stored icon
        LDR     r7, [r10, #4]
        CMP     r6, r7                          ; Check proposed y2 <= icon y1
        BLE     %FT80                           ; If it is, then this icon present no problems.
        LDR     r7, [r10, #12]
        CMP     r4, r7                          ; Check proposed y1 >= store y2
        BGE     %FT80                           ; If it is, then this icon presents no problems

70      ; Exit EQ
        ADD     sp, sp, #40                     ;
        CMP     sp, sp                          ;
        EXIT

80      ; this icon doesn't occupy the space - try next
        LDR     r11, [r11, #ic_next]            ;
        B       %BT20                           ;

90      SUBS    r8,r8,#1                        ;
        BPL     %BT10                           ;

        ; something ISN'T there - Exit NE
        ADD     sp, sp, #40                     ;
        CMP     sp, #0                          ;
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; next_grid_row_or_column
;
; Depending on PinboardOption_WinToCornerXX, return the X and Y
; co-ordinate of the start of the next row or column.
;
; In: r2     = options
;     r3, r4 = x and y co-ordinate of grid position

;
; Out: r3, r4 = x and y co-ordinate of next row or column

next_grid_row_or_column Entry "r5-r7"

        ADR     r5, bounding_box
        MOV     r6,#grid_x_spacing
        MOV     r7,#grid_y_spacing

        TST     r2, #PinboardOption_WinToCornerHV ; Are we dealing with rows or columns?
        BNE     %FT20

10      ; rows - reset x to left/right and move up/down a row
        LDR     r0, [r5, #8] ; x2
        TST     r2, #PinboardOption_WinToCornerLR
        SUBNE   r3, r0, r6
        MOVEQ   r3, #0

        TST     r2, #PinboardOption_WinToCornerTB
        ADDNE   r4, r4, r7
        SUBEQ   r4, r4, r7

        ; Check we haven't moved up/down too far
        LDR     r0, [r5, #12] ; y2
        SUB     r0, r0, r7
        CMP     r4, r0
        SUBGT   r4, r4, r7

        LDR     r0, icon_bar_height
        CMP     r4, r0
        ADDLT   r4, r4, r7
        EXIT

20      ; columns - reset y to top/bottom and move left/right a column
        LDR     r0, [r5, #12] ; y2
        TST     r2, #PinboardOption_WinToCornerTB
        LDRNE   r4, icon_bar_height
        SUBEQ   r4, r0, r7

        TST     r2, #PinboardOption_WinToCornerLR
        SUBNE   r3, r3, r6
        ADDEQ   r3, r3, r6

        ; Check we haven't moved left/right too far
        LDR     r0, [r5, #8] ; x2
        SUB     r0, r0, r6
        CMP     r3, r0
        SUBGT   r3, r3, r6

        CMP     r3, #0
        ADDLT   r3, r3, r6
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; get_iconise_position
;
; Decide where to put the icon for a window that's just been iconized.
; The process involves choosing a location, then searching first the window list, then the
; file list, to see if the space is occupied. If it is, then we move to the next space
; (dependent on PinboardOption_WinToCorner...) and check through each list again.
;
; In: Nothing.
;
; Out: The memory locations iconise_x and iconise_y are set to the position for the icon.
;      All regs preserved.

get_iconise_position

        Entry   "r0-r12"

        LDR     r2, Pinboard_options                ; Pinboard options
        ORR     r2, r2, #PinboardFlag_UseWindowList ; we need the origin of the window list
        BIC     r2, r2, #PinboardFlag_SkipSelected  ; ensure selected icons are checked too
        STR     r2, Pinboard_options                ; write back Pinboard options

        BL      decide_list_origin                  ; get origin of window list

        ; Now loop through linked list of icons and see if they present a problem
        ; (occupy the space that our 'proposed' icon is going to use). If so, try
        ; another space. If not, then we can use the coords.

10      BL      is_something_there                  ; is proposed space occupied?
        STRNE   r3, iconize_x                       ; if not, set x,y for iconised icon
        STRNE   r4, iconize_y                       ; .. and exit
        BLEQ    find_next_x_and_y                   ; if so, find next space (NB alters Z!)
        BEQ     %BT10                               ; .. and see if that's free

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; get_next_icon_box
;
; Given a pointer to a data block, find the icon's bounding box.
; PinboardFlag_UseWindowList sets if the block is in the window or file list
;
; In: r2 = Pinboard_options
;     r11 -> icon data block
;     r9  -> 40 byte block of temporary memory (typically stack)
;
; Out: r10 -> bounding box (which will be 16 bytes within the 40 bytes)
;             if r10 is zero, icon is not on backdrop.
;      r0, r1 corrupted

get_next_icon_bbox Entry

        MOV     r10, #0
        TST     r2, #PinboardFlag_UseWindowList ; Is the data -> by r9 in the window or file list?
        BNE     %FT20

10      ; find the icon handle from the file icon list
        LDR     r0, [r11, #ic_icon]
        B       %FT30

20      ; find the icon handle from the window icon list
        LDR     r0, backdrop_handle
        LDR     r1, [r11, #w_icon_id]
        CMP     r0, r1
        EXIT    NE                              ; icon not on backdrop - exit
        LDR     r0, [r11, #w_icon_handle]

30      ; found an icon handle - get it's bounding box
        STR     r0, [r9, #4]
        LDR     r0, backdrop_handle
        STR     r0, [r9]
        MOV     r1, r9
        SWI     Wimp_GetIconState
        ADD     r10, r1, #8

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; find_next_x_and_y
;
; What are x and y co-ordinates of the next spot on the grid?
; This depends on the start corner and the direction of stacking.
;
; In: r2 = pinboard options
;     r3 = x co-ord.
;     r4 = y co-ord.
;
; Out: r3, r4 = x and y co-ordinates
;      NE     = Screen full
;      EQ     = Found new position (in r3, r4)
;      r0, r1 = corrupted.

find_next_x_and_y Entry

        ; Which way are we stacking?
        TST     r2, #PinboardOption_WinToCornerHV ; 0 = horizontally (EQ), 1 = vertically (NE)
        BEQ     find_next_horizontal
        BNE     find_next_vertical


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

find_next_vertical

        ADR     r0, bounding_box
        LDR     r1, [r0, #12]
        MOV     r14, #grid_y_spacing
        SUB     r1, r1, r14
        LDR     r0, icon_bar_height

        TST     r2, #PinboardOption_WinToCornerTB ; 0 = top (EQ) 1 = bottom (NE)
        BNE     %FT12

        ; move down
        SUBS    r4, r4, r14
        MOVMI   r4, r1
        BMI     %FT16
        CMP     r4, r0
        MOVLT   r4, r1
        BLT     %FT16
        B       find_next_found

12      ; move up
        ADD     r4, r4, r14
        CMP     r4, r1
        MOVGE   r4, r0
        BGE     %FT16
        B       find_next_found

16      ; we've hit the edge - move left/right
        ADR     r0, bounding_box
        TST     r2, #PinboardOption_WinToCornerLR
        BEQ     %FT18

        ; move left
        MOV     r14, #grid_x_spacing
        SUBS    r3, r3, r14
        BMI     find_next_screen_full
        B       find_next_found

18      ; move right
        MOV     r14, #grid_x_spacing
        ADD     r3, r3, r14
        LDR     r1, [r0, #8]
        SUB     r1, r1, r14
        CMP     r3, r1
        BGT     find_next_screen_full
        B       find_next_found

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

find_next_horizontal

        ADR     r0, bounding_box
        MOV     r14, #grid_x_spacing
        LDR     r1, [r0, #8]
        SUB     r1, r1, r14

        ; which direction do we move?
        TST     r2, #PinboardOption_WinToCornerLR ; 0 = left (EQ), 1 = right (NE)
        BEQ     %FT22

        ; move left
        SUBS    r3, r3, r14
        MOVMI   r3, r1
        BMI     %FT26
        B       find_next_found

22      ; move right
        ADD     r3, r3, r14
        CMP     r3, r1
        MOVGE   r3, #0
        BGE     %FT26
        B       find_next_found

26      ; we've hit the edge - move up/down
        TST     r2, #PinboardOption_WinToCornerTB
        BNE     %FT28

        ; move down
        MOV     r14, #grid_y_spacing
        SUBS    r4, r4, r14
        BMI     find_next_screen_full
        LDR     r1, icon_bar_height
        CMP     r4, r1
        BLT     find_next_screen_full
        B       find_next_found

28      ; move up
        MOV     r14, #grid_y_spacing
        ADD     r4, r4, r14
        LDR     r1, [r0, #12]
        SUB     r1, r1, r14
        CMP     r4, r1
        BGT     find_next_screen_full
        B       find_next_found


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

find_next_found

        ; We've found the next slot - exit EQ
        MOV     r0, #24
        CMP     r0, #24
        EXIT


find_next_screen_full

        ; The screen was full - exit NE
        MOV     r0, #24
        CMP     r0, #23
        EXIT


        LNK     Tail.s
