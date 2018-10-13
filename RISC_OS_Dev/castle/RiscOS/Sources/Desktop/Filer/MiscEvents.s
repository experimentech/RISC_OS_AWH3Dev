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
; Out   much corruption
;
; This routine used only to send opendir and closedir requests to myself.
; Now it sends any messages queued to be sent whilst out of the desktop.
;

SendDirRequestsToMyself Entry "r10"

        SUB     sp, sp, #256

10      LDR     r10, DirRequestList      ; Reload from head each time
        TEQ     r10, #Nowt
        BEQ     %FT90                    ; [finished]

        LDR     r14, [r10, #dirreq_link]
        STR     r14, DirRequestList

        MOV     r14, #0                  ; yourref = 0 -> start of sequence
        STR     r14, [sp, #ms_yourref]
        STR     r14, [sp, #ms_data + 0]
        STR     r14, [sp, #ms_data + 4]
        LDRB    r14, [r10, #dirreq_reason]
        TEQ     r14, #drr_open
        BNE     %FT20

        ; Copy data for an open at request

        MOV     r14, #1
        STR     r14, [sp, #ms_data + 4]  ; no thank you to canonicalised paths
        LDR     r14, [r10, #dirreq_x0]
        STR     r14, [sp, #ms_data + 8]
        LDR     r14, [r10, #dirreq_y1]
        STR     r14, [sp, #ms_data + 12]
        LDR     r14, [r10, #dirreq_w]
        STR     r14, [sp, #ms_data + 16]
        LDR     r14, [r10, #dirreq_h]
        STR     r14, [sp, #ms_data + 20]
        LDRB    r14, [r10, #dirreq_viewmode]
        STRB    r14, [sp, #ms_data + 24]
        MOV     r0, #User_Message
        ADD     r1, sp, #ms_data + 25
        LDR     r14, =Message_FilerOpenDirAt
        B       %FT40

20      ;
        TEQ     r14, #drr_close
        BNE     %FT30

        ; Copy data for a closedir request

        LDR     r14, [r10, #dirreq_closeflags]
        STR     r14, [sp, #ms_data+4]
        ADD     r1, sp, #ms_data + 8
        LDR     r14, =Message_FilerCloseDir
        MOV     r0, #User_Message
        B       %FT40

30      ;
        TEQ     r14, #drr_run
        BNE     %FT35

        ; Copy data for a DataOpen request

        MOV     r14, #0
        STR     r14, [sp, #ms_yourref]
        STR     r14, [sp, #msDataTransfer_window]
        STR     r14, [sp, #msDataTransfer_icon]
        LDR     r14, xwindsize
        MOV     r14, r14, LSR #1
        STR     r14, [sp, #msDataTransfer_x]
        LDR     r14, ywindsize
        MOV     r14, r14, LSR #1
        STR     r14, [sp, #msDataTransfer_y]
        MOV     r14, #0
        STR     r14, [sp, #msDataTransfer_filesize]
        LDR     r14, [r10, #dirreq_filetype]
        STR     r14, [sp, #msDataTransfer_filetype]

        ; Initiated junk for DataOpen
        MOV     r14, #Nowt
        STR     r14, dirtoclose

        ; Establish common information
        MOV     r0, #User_Message_Recorded
        ADD     r1, sp, #msDataTransfer_filename
        LDR     r14, =Message_DataOpen
        B       %FT40

35
        ; only request left is filer_boot...

        ADD     r1, r10, #dirreq_dirname
        BL      SussPlingApplic_GivenName
        BLVS    LocalReportError
        CLRV
        B       %FT80

40      ; store the message number
        STR     r14, [sp, #ms_action]

        ADD     r2, r10, #dirreq_dirname
 [ debugtask
 DSTRING r2, ", dirname ",cc
 ]
        BL      strcpy_excludingspaces  ; stop on spaces so Neil can send wally
                                        ; dirnames at top level
        BL      strlen
        ADD     r1, r1, r3

        ADD     r1, r1, #3+1            ; round up to word size (remember null)
        BIC     r1, r1, #3
        SUB     r1, r1, sp
        STR     r1, [sp, #ms_size]

        MOV     r1, sp
        MOV     r2, #0                  ; Broadcast it
        MOV     r3, #0                  ; icon handle
 [ debugtask
 DREG r2,"Sending normal message from Filer to thandle/whandle ",,Word
 DREG r0,  "Event type "
 LDR r14, [r1, #ms_action]
 DREG r14, "Action "
 LDR r14, [r1, #ms_size]
 DREG r14, "Message size "
 ]
        SWI     XWimp_SendMessage

80
        MOV     r2, r10
        BL      SFreeArea               ; Accumulates V
        BVC     %BT10


90      ;
        ADRVC   r14, DirRequestList
        STRVC   r14, DirRequestEndLink
        ADD     sp, sp, #256
        EXIT

        LTORG

 [ version >= 113
;..............................................................................
;
; delete_closed_menu_window
;
; This routine deletes the closed menu window if it is created and closed.
;
; In - nothing
; Out - much corruption and menu window deleted if it was created
;        and closed.
;
delete_closed_menu_window       Entry   ,u_windowstate
        ; Do we think it created
        LDR     r0, h_menuwindow_loc
        TEQ     r0, #0
        EXIT    EQ                      ; Window is not created

        ; Get the menuwindow handle
        LDR     r14, [r0]

        ; Do we think it is open
        STR     r14, [sp, #u_handle]
        MOV     r1, sp
        SWI     XWimp_GetWindowState
        BVS     %FT10
        LDR     r14, [sp, #u_wflags]
        TST     r14, #ws_open
        EXIT    NE                      ; window is open

        ; Restore type_menuwindow to the location which was used for the handle
        LDR     r0, h_menuwindow_loc
        LDR     r14, type_menuwindow
        STR     r14, [r0]

        ; Make sure we think the menuwindow is deleted
        MOV     r14, #0
        STR     r14, h_menuwindow_loc

        ; Delete the window
        SWI     XWimp_DeleteWindow
        EXIT    VC
10      BL      LocalReportError
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_null_reason
; =================

; In    nothing

; Out   no preservation necessary

        [ version >= 153

event_null_reason Entry

        [       debugsched
        DLINE   "Entered nullevent",cc
        ]

        ; Zero (most of) the poll word to catch upcalls during the recache
        LDR     r10, poll_word
        AND     r1, r10, #poll_word_recache_pending
        STR     r1, poll_word

        ; Hold the old sel_dir to see if the menu might need reopening
        LDR     r9, sel_dir

        [       debugsched
        TST     r10, #poll_word_force_poll
        BEQ     %FT00
        DLINE   " **forcepoll**" , cc
00
        ]

        ; Redraw (recache) if an upcall is waiting to be processed
        ; or zero the recache delay if not
        TST     r10, #poll_word_upcall_waiting

        [       debugsched
        BNE     %FT00
        DLINE   " zeroing recache delay ",cc
00
        ]

        MOVEQ   r0, #0
        STREQ   r0, recache_delay       ; No recache wanted; zero

        [       debugsched
        BEQ     %FT00
        DLINE   " setting recache bit",cc
00
        ]

        ORRNE   r10, r10, #poll_word_recache_pending
        MOVNE   r1, #poll_word_recache_pending
        STRNE   r1, poll_word

        TST     r10, #poll_word_recache_pending
        BEQ     %FT20

; A recache is pending.
; If the current time exceeds the recache delay (or the delay is 0), then allow it to happen.

        ; read current time, for calculating whether we can recache yet.  We also
        ; use this time in the recache_delay calculation later on.
        SWI     XOS_ReadMonotonicTime   ; r0 is NOW
        LDR     r1, recache_delay       ; r1 is DELAY

        [       debugsched
        DREG    r0, " time now: ", cc
        DREG    r1, " delay till: ", cc
        ]

        TEQ     r1, #0                  ; if delay is zero, then
        BEQ     %FT02                   ; allow a recache regardless

        SUBS    r2, r0, r1              ; otherwise only recache if NOW - DELAY >= 0
        [       debugsched
        BPL     %FT00
        DLINE   " try again later ", cc
00
        ]
        BMI     %FT20                   ; this test is wraparound-safe

02
        [       debugsched
        DLINE   " RECACHE ",cc
        ]

        ; Clear recache bit, but ensure that we get called once more so that
        ; we can zero recache_delay if and when things quieten down
        MOV     r1, #poll_word_force_poll
        STR     r1, poll_word

        ; store current time in recache_delay, just for now
        STR     r0, recache_delay

        BL      RedrawIfModified
        BVS     %FT10

        ; Check whether we've got the menu
        MOV     r0, #0
        ADR     r1, userdata
        SWI     XWimp_GetMenuState
        BVS     %FT10
        LDR     r0, [r1]
        TEQ     r0, #0
        BMI     %FT15

        ; Check if our selection has disappeared
        LDR     r0, sel_whandle
        TEQ     r0, #Nowt
        BNE     %FT05

        ; Selection window disappeared - junk the menu tree
        BL      NobbleMenuTree
        B       %FT15

05      ; Check for sel_dir changing - if not, leave menus alone.
        LDR     r4, sel_dir
        TEQ     r4, r9
        BEQ     %FT15

        ; Cause the menu to recreate with the new information
        BL      RecodeAndRecreateMenu

10      BLVS    LocalReportError

15      ; Recalculate the recache_delay value
        ; The value used is Now + (time taken * 4)
        SWI     XOS_ReadMonotonicTime           ; Now is in r0
        LDR     r1, recache_delay               ; Then is in r1
        SUB     r1, r0, r1                      ; wraparound safe
        [       debugsched
        DREG    r1, " took: ", cc
        ]
        ADD     r1, r0, r1, LSL # 2             ; now + time * 4
        [       debugsched
        DREG    r1, " delay till: ", cc
        ]
        STR     r1, recache_delay

20      ; Send directory requests to myself if they're waiting
        TST     r10, #poll_word_command_waiting
        BLNE    SendDirRequestsToMyself
        BLVS    LocalReportError

        ; Process message file closed if we got hit with that service.
        TST     r10, #poll_word_messagefile_closed
        BEQ     %FT90

        [ {TRUE}
        ; if a menu window was up, then it's handle is about to be stuffed

        ; Restore type_menuwindow to the location which was used for the handle
        LDR     r0, h_menuwindow_loc
        TEQ     r0, #0
        BEQ     %FT80

        Push    R0
        BL      NobbleMenuTree
        Pull    R0

        LDR     R1,[R0]
        Push    R0
        Push    R1
        MOV     R1,sp
        SWI     XWimp_DeleteWindow
        ADD     SP,SP,#4
        Pull    R0
        LDR     r14, type_menuwindow
        STR     r14, [r0]

        ; Make sure we think the menuwindow is deleted
        MOV     r14, #0
        STR     r14, h_menuwindow_loc
        CLRV
        ]
80
        ; Copy the new menus
        BL      CopyMenus
        BLVS    LocalReportError

        ; Stuff the old ones if we own them.
        MOV     r0, #0
        ADR     r1, userdata
        SWI     XWimp_GetMenuState
        BVS     %FT85
        LDR     r0, [r1]
        TEQ     r0, #0

        BLPL    NobbleMenuTree

85      BLVS    LocalReportError

90
        ; Don't allow a null event within less than 1/2 second.
        ; Hopefully the recache took all the time and doing the
        ; redraw won't take too long.
        SWI     XOS_ReadMonotonicTime
        ADD     r0, r0, #50
        STR     r0, next_null_event_not_before_time

        [ debugsched
        DLINE   ""
        ]

        EXIT

        |
; Old version if pre-153

event_null_reason Entry

        ; Zero the poll word to catch upcalls during the recache
        LDR     r10, poll_word
        MOV     r0, #0
        STR     r0, poll_word

        ; Hold the old sel_dir to see if the menu might need reopening
        LDR     r9, sel_dir

        ; Redraw (recache) if an upcall is waiting to be processed
        TST     r10, #poll_word_upcall_waiting
        BEQ     %FT20
        BL      RedrawIfModified
        BVS     %FT10

        ; Check whether we've got the menu
        MOV     r0, #0
        ADR     r1, userdata
        SWI     XWimp_GetMenuState
        BVS     %FT10
        LDR     r0, [r1]
        TEQ     r0, #0
        BMI     %FT20

        ; Check if our selection has disappeared
        LDR     r0, sel_whandle
        TEQ     r0, #Nowt
        BNE     %FT05

        ; Selection window disappeared - junk the menu tree
        BL      NobbleMenuTree
        B       %FT20

05      ; Check for sel_dir changing - if not, leave menus alone.
        LDR     r4, sel_dir
        TEQ     r4, r9
        BEQ     %FT20

        ; Cause the menu to recreate with the new information
        BL      RecodeAndRecreateMenu

10      BLVS    LocalReportError

20      ; Send directory requests to myself if they're waiting
        TST     r10, #poll_word_command_waiting
        BLNE    SendDirRequestsToMyself
        BLVS    LocalReportError

        ; Process message file closed if we got hit with that service.
        TST     r10, #poll_word_messagefile_closed
        BEQ     %FT90

        ; Copy the new menus
        BL      CopyMenus
        BLVS    LocalReportError

        ; Stuff the old ones if we own them.
        MOV     r0, #0
        ADR     r1, userdata
        SWI     XWimp_GetMenuState
        BVS     %FT85
        LDR     r0, [r1]
        TEQ     r0, #0
        BLPL    NobbleMenuTree
85      BLVS    LocalReportError

90
        ; Don't allow a null event within less than 1/2 second.
        ; Hopefully the recache took all the time and doing the
        ; redraw won't take too long.
        SWI     XOS_ReadMonotonicTime
        ADD     r0, r0, #50
        STR     r0, next_null_event_not_before_time
        EXIT

        ]

 [ version >= 116
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_pollword_nonzero
; ======================

; In    nothing
event_pollword_nonzero Entry

        ; This exists to force a cycle around the poll loop
        ; when the poll word becomes non-zero. This enables
        ; null events to be enabled which eventually causes
        ; a recache to occur.

        EXIT
 ]

        END
