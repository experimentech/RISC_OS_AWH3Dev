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
;       Buffered list is non-empty

empty_buffer
        Push    "LR"

        LDR     r1,backdrop_redraw
        CMP     r1,#-1
        BNE     next_buffer_slot

        LDR     r0,backdrop_handle
        MOV     r1,#-1
        MOV     r2,#-1
        MOV     r3,#&10000
        MOV     r4,#&10000
        SWI     XWimp_ForceRedraw

        MOV     r0,#0
        STR     r0,backdrop_redraw

        Debug   sp,"Forced redraw."

next_buffer_slot
        LDR     r0, buffered_ptr
        CMP     r0, #0
        Pull    "PC",LE
; Unlink block from buffered list (note that it is at the front of list, so it has no previous block)
        MOV     r4, r0
        LDR     r0, [r4, #next_ptr]
        STR     r0, buffered_ptr
        CMP     r0, #0
        MOVGT   r1, #0
        STRGT   r1, [r0,#prev_ptr]
        LDRGT   r0, [r0,#icon_handle]
        Debug   pi,"next icon's handle ",r0
; Find position in active list to place it
        MOV     r0, #OsByte_INKEY
        MOV     r1, #&ff                ; Shift key
        MOV     r2, #&ff
        SWI     XOS_Byte
        ADR     r0, active_ptr
        LDR     r3, [r4, #icon_handle]
        Debug   pi,"empty buffer handle ",r3
        CMP     r3, #remove_normal
        ASSERT  remove_normal > remove_tinydir
        BLE     remove_command_entry
        CMP     r3, #insert_tinydir
        BEQ     install_tinydirs
02
        LDR     r1, [r0,#next_ptr]
        CMP     r1, #0
        BLE     found_insertion_point
        CMP     r3, #-2
        BEQ     found_insertion_point
        LDR     r5, [r1, #icon_handle]
        CMP     r5, r3
        TEQEQ   r2, #&ff
        BEQ     found_insertion_point
        MOV     r0, r1
        CMP     r5, r3
        BNE     %BT02
        LDR     r1, [r0,#next_ptr]
; Link block into active list (r0->before,r1->after)
found_insertion_point
        STR     r0, [r4,#prev_ptr]
        STR     r4, [r0,#next_ptr]
        STR     r1, [r4,#next_ptr]
        CMP     r1, #0
        STRGT   r4, [r1,#prev_ptr]
; Install the icon
        BL      install_icon
; We can't be in a drag so clear drag icon.
        MOV     r1,#-1
        STR     r1,drag_icon
; If there was an error then unlink the icon and return
        STRVS   r1, [r11,#icon_handle]
        BLVS    delete_icon
        Pull    "PC",VS
; Store the icon handle
        LDR     r1, [r4,#icon_handle]
        STR     r0, [r4,#icon_handle]
        MOV     r3, r0
        CMP     r1, #insert_pinboard
        LDRNE   r0, no_icons
        LDREQ   r0, pinboard_no_icons
        ADD     r0, r0, #1
        STREQ   r0, pinboard_no_icons
        ADDNE   r0, r0, #1
        STRNE   r0, no_icons
; Check icon handle - if inserting at end then okay, else change all icon entries in buffered list
        CMP     r1, #-1
        BEQ     next_buffer_slot
        CMP     r1, #insert_pinboard
        BEQ     next_buffer_slot
        ADR     r0, buffered_ptr
02
        LDR     r0, [r0,#next_ptr]
        CMP     r0, #0
        BLE     next_buffer_slot
        LDR     r2, [r0,#icon_handle]
        CMP     r2, r1
        STREQ   r3, [r0,#icon_handle]
        B       %BT02
; ----------------------------------------------------------------------------------------------------------------------
install_tinydirs
        LDR     r0, tinydir_icon
        CMP     r0, #0
        Pull    "PC",GE
; Delete icon block
        MOV     r2, r4
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        Pull    "PC",VS
; Add Tinydirs icon
        ADR     r2, tinydirs_icon_name
        MOV     r0, #SpriteReason_ReadSpriteSize
        SWI     XWimp_SpriteOp
; Valid registers r6 = sprite mode, r3,r4 = sprite width,height, r9->icon name,r10->sprite name,r11->icon
        MOVVC   r0, r6                          ; creation mode of sprite
        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   r5, r3, LSL r2
        MOVVC   r3, #0
        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        Pull    "PC",VS
        MOV     r6, r4, LSL r2
        ADD     r6, r6, #20
        MOV     r4, #20
; Transfer data
        ADR     r1, tinydirs_icon_block
        LDMIA   r1, {r7,r8,r9,r10}
        ADR     r1, dataarea
        MOV     r2, #-2
        STMIA   r1, {r2,r3,r4,r5,r6,r7,r8,r9,r10}
        SWI     XWimp_CreateIcon
        Pull    "PC",VS
        STR     r0, tinydir_icon
        B       next_buffer_slot
tinydirs_icon_block
        DCD     &0000301A
tinydirs_icon_name
        DCB     "Directory",0,0,0
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
remove_command_entry
        CMP     r3, #remove_tinydir
        BNE     %FT99
; Delete tinydir icon
        LDR     r3, tinydir_icon
        CMP     r3, #-2
        MOVEQ   r3, #-1
        STREQ   r3, tinydir_icon
        CMP     r3, #0
        Pull    "PC",LT
        MOV     r2, #-1
        STR     r2, tinydir_icon
; Delete icon block
        MOV     r2, r4
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        Pull    "PC",VS
; Add Tinydirs icon
        ADR     r1, dataarea
        STR     r3, [r1,#4]
        MOV     r3, #-1
        STR     r3, [r1]
        SWI     XWimp_DeleteIcon
        Pull    "PC",VS
        B       next_buffer_slot

; Find first active icon which matches the monotonic number
99
        CMP     r3, #remove_monotonic
        BNE     %FT99
        ADR     r1, active_ptr
01
        LDR     r1, [r1,#next_ptr]
        CMP     r1, #0
        BLE     removed_all_entries
        LDR     r2, [r4, #icon_id]
        LDR     r3, [r1, #icon_id]
        CMP     r2, r3
        BNE     %BT01
; Get icon handle of icon to left of deleting one
        Push    "r4"
        LDR     r5, [r1,#icon_handle]
        ADR     r7, active_ptr
        LDR     r6, [r1,#prev_ptr]
        CMP     r6, #0
        CMPNE   r6, r7
        MOVEQ   r6, #-2
        LDRNE   r6, [r6,#icon_handle]
        MOV     r4, r1
        BL      delete_icon
        Pull    "r4,PC",VS
; Find all occurences of Add to right of in buffered list, and change to icon to left of this
; Check icon handle - if inserting at end then okay, else change all icon entries in buffered list
        Pull    "r4"
        ADR     r0, buffered_ptr
02
        LDR     r0, [r0,#next_ptr]
        CMP     r0, #0
        BLE     removed_all_entries
        LDR     r2, [r0,#icon_handle]
        CMP     r2, r5
        STREQ   r6, [r0,#icon_handle]
        B       %BT02

; Find first active icon which matches the name
99
        ADR     r1, active_ptr
01
        LDR     r1, [r1,#next_ptr]
        CMP     r1, #0
        BLE     removed_all_entries
        Pull    "PC",LE
        ADD     r2, r4, #icon_filename
        ADD     r3, r1, #icon_filename
02
        LDRB    r0, [r2], #1
        LDRB    r5, [r3], #1
        CMP     r0, #32         ;       End of source (and dest?)
        BLE     end_of_source_active
        CMP     r5, #32         ;       End of dest but not source -> failure
        BLE     %BT01
        UpperCase  r0, r6
        UpperCase  r5, r6
        CMP     r0, r5          ;       Source<>Dest -> failure
        BNE     %BT01
        B       %BT02
end_of_source_active            ;       End of source
        CMP     r5, #32
        BGT     %BT01           ;       But not dest -> failure
; Icon name at r1 matches that at r4
        Push    "r1,r4"
found_removal
; Get icon handle of icon to left of deleting one
        LDR     r5, [r1,#icon_handle]
        ADR     r7, active_ptr
        LDR     r6, [r1,#prev_ptr]
        CMP     r6, #0
        CMPNE   r6, r7
        MOVEQ   r6, #-2
        LDRNE   r6, [r6,#icon_handle]
        MOV     r4, r1
        BL      delete_icon
        Pull    "r1,r4,PC",VS
; Find all occurences of Add to right of in buffered list, and change to icon to left of this
; Check icon handle - if inserting at end then okay, else change all icon entries in buffered list
        Pull    "r1,r4"
        ADR     r0, buffered_ptr
02
        LDR     r0, [r0,#next_ptr]
        CMP     r0, #0
        BLE     %BT01
        LDR     r2, [r0,#icon_handle]
        CMP     r2, r5
        STREQ   r6, [r0,#icon_handle]
        B       %BT02
; Delete icon block
removed_all_entries
        MOV     r2, r4
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        Pull    "PC",VS
        B       next_buffer_slot
; ----------------------------------------------------------------------------------------------------------------------
        LNK     Mouse.s
