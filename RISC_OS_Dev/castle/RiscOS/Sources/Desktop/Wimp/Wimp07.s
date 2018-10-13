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
; > Sources.Wimp07

;;----------------------------------------------------------------------------
;; Constants used by Wimp_SendMessage
;;----------------------------------------------------------------------------

                ^       0
msb_link        #       4
msb_receiver    #       4
msb_allsender   #       4               ; for R2 on exit from Wimp_Poll
msb_handle      #       4               ; remember window/icon handle
msb_reasoncode  #       4
msb_size        #       4               ; is also size of header!
msb_sender      #       4
msb_myref       #       4
msb_yourref     #       4               ; ms_xxx defined in Hdr.Messages

ms_sender       *       ms_taskhandle   ; for convenience!

min_messsize    *       ms_data         ; only applies to 17,18,19
max_messsize    *       256

msf_broadcast   *       1:SHL:31

MSToWimpMagicHandle     *       &706d6957       ; Reads "Wimp" in *memoryi, is not word aligned and has top bit (msf_broadcast) clear

        MACRO
$lab    CheckMsgQ
$lab
      [ NKmessages1
        LDR     R0,lastpointer
        SUBS    R0,R0,R2
        STREQ   R0,lastpointer
      ]
        MEND

;;----------------------------------------------------------------------------
;; Return Message to task (called by Wimp_Poll)
;; Entry:  R2 --> message to send (same as [headpointer]
;;         [headpointer] --> message blocks (linked list)
;; Exit:   [taskhandle] set up
;;         message block removed from list, if necessary
;;         code branches to ExitPoll, unless task dead or code is masked out
;;         broadcast messages of type 12:
;;           if any task acknowledges it, no more tasks get the broadcast
;;           if no tasks acknowledge it, the block is returned to sender
;;           - the code seems to have dropped out nicely !!!
;; Note:
;;         if a task or window has been subsequently deleted,
;;           the message is not delivered (returned if appropriate)
;;----------------------------------------------------------------------------

returnmessage
        [ debugpk
        LDR     R5,[R2,#msb_receiver]
        MOV     R5,R5,LSL #16
        LDR     R14,=&16840000
        TEQ     R14,R5
        BNE     glurg
        LDR     R14,[R2,#msb_reasoncode]        ; if its a message then checking
        LDR     R5,[R2,#msb_allsender]

        Debug   pk,"About to send message to TM ",R14,R5
        LDR     R14,[R2,#msb_link]
        CMP     R14,#nullptr
        BEQ     glurg

        LDR     R5,[R14,#msb_receiver]

        LDR     R14,[R14,#msb_reasoncode]
        Debug   pk,"Next reason code message is ",R14,R5

        LDR     R14,[R2,#msb_link]
        CMP     R14,#nullptr
        BEQ     glurg
        LDR     R14,[R14,#msb_link]
        CMP     R14,#nullptr
        BEQ     glurg


        LDR     R14,[R14,#msb_reasoncode]
        Debug   pk,"And the next is is ",R14

glurg
        ]

;
; set up 'sender', so ExitPoll can return R2 = sender's handle if necessary
;
        LDR     R14,[R2,#msb_allsender]
        STR     R14,sender
;
; page in appropriate task - if doing broadcast, update count
;
        LDR     R5,[R2,#msb_receiver]


        TST     R5,#msf_broadcast
        ADDNE   R14,R5,#4                       ; on to next task
        STRNE   R14,[R2,#msb_receiver]
        LDRNE   R0,=maxtaskhandle:OR:msf_broadcast
        CMPNE   R14,R0
        BICCS   R5,R5,#msf_broadcast            ; last one is just 'ordinary'
;
; if the task has died, don't send the message !!!
;
        TEQ     R5,#0                   ; if zero, don't send message
        BEQ     %FT01
;
; Catch messages to Wimp
;


        LDR     R14,=MSToWimpMagicHandle
        TEQ     R5,R14
        BEQ     autowimp_menu

        MOV     R14,R5,LSL #32-flag_versionbit
        LDR     R3,[wsptr,R14,LSR #32-flag_versionbit]  ; R3 --> task data
        TST     R3,#task_unused
        BNE     %FT01                           ; give up now!
;
        LDR     R14,[R2,#msb_reasoncode]        ; if its a message then checking

        CMP     R14,#User_Message
        CMPNE   R14,#User_Message_Recorded
        CMPNE   R14,#User_Message_Acknowledge
        BLEQ    checkformessage
;
        LDR     R3,[R3,#task_flagword]          ; R3 = flag word (if not dead)
        BIC     R14,R5,#msf_broadcast
        MOVS    R14,R14,LSR #flag_versionbit    ; if version bits set,
        TEQNE   R14,R3,LSR #flag_versionbit     ; ensure they are the same!
        MOVEQ   R14,#1
        LDREQ   R0,[R2,#msb_reasoncode]
        TSTEQ   R3,R14,LSL R0           ; check whether this code is masked out
01
        ANDNE   R5,R5,#msf_broadcast    ; mark lower bits 0 ==> don't send it!

;
; R5 (bits 0..19) = 0 ==> don't send message
;
        MOV     R14,R5,LSL #32-flag_versionbit
        MOVS    R14,R14,LSR #32-flag_versionbit
        BEQ     postposting
;
        Task    R14,,"Message return"           ; page in appropriate task
        ADD     R1,R2,#msb_size                 ; R1 --> actual message bit
        BL      calcmessagesize                 ; R3 = size of message block
        BVS     ExitPoll
;
        Debug   ms,"Message: task,rc,R1,size =",#taskhandle,R0,userblk,R3
        TEQ     R3,#0
        BEQ     postposting
        MOV     R4,userblk
01
        LDR     R14,[R1],#4                     ; copy into [userblk]
        STR     R14,[R4],#4
        SUBS    R3,R3,#4
        BNE     %BT01
;
; having copied the block out, decide whether to free the heap block
;
postposting
        TST     R5,#msf_broadcast               ; if broadcast,
        BNE     doneblock                       ; keep the block
;
        LDR     R0,[R2,#msb_reasoncode]         ; (may not have been loaded)
        TEQ     R0,#User_Message_Recorded       ; unless recorded,
        BEQ     %FT01                           ; delete block
;
        LDR     R14,[R2,#msb_link]
        STR     R14,headpointer
;
        Debug   ms,"Freeing block at:",R2
        Push    "R0"
        CheckMsgQ
        MOV     R0,#ModHandReason_Free
        BL     XROS_Module
        Pull    "R0"
        B       doneblock
01
        Debug   ms,"Marking 'return to sender':",R2
        MOV     R14,#User_Message_Acknowledge   ; mark 'return to sender'
        STR     R14,[R2,#msb_reasoncode]
        LDR     R14,[R2,#msb_sender]            ; redirect back to sender
        STR     R14,[R2,#msb_receiver]

doneblock
        BICS    R14,R5,#msf_broadcast
        BNE     ExitPoll                ; R0, [userblk] set up
        B       repollwimp              ; may call returnmessage again


;;----------------------------------------------------------------------------
;; Send Message
;; Entry:  R0 = reason code to generate
;;         R1 --> message block
;;             R1+0 = size of block
;;             R1+4 = handle of sending task (filled in by Wimp)
;;             R1+8 = my ref field           (filled in by Wimp)
;;             R1+12 = your ref field (0 if none)
;;             R1+16 = message action
;;             R1+20 = message data (format depends on [R1+16]
;;         R2 = task / window handle (Wimp can tell them apart)
;;         R2 = 0 ==> broadcast
;;         R3 = icon handle (if R2 = window handle on entry)
;; Exit:   R2 = actual task handle (or 0 if R2=0 on entry)
;;         [R1+8] = reference number of message (if R0 was 17 or 18 on entry)
;;         if [R1+12] <> 0, then any message with that myref value is killed
;; Errors: no room in RMA for message block
;;         illegal task/window handle
;;         illegal reason code (R0 on entry to Wimp_SendMessage)
;;         illegal message block size (must be <= 256, and be a multiple of 4)
;;----------------------------------------------------------------------------

SWIWimp_SendMessage

        MyEntry "SendMessage"

; first find out if application is sending a font changed message
        Push    "R0-R1"
        LDR     R0,[R1,#16]
        LDR     R1,=Message_FontChanged
        CMP     R0,R1
        Pull    "R0-R1"
        BNE     ordinary_message
        TEQ     R0,#User_Message
        BNE     ordinary_message
        [ outlinefont
        BL      FindFont                ; this will broadcast the message if it succeedes
        ]
        BLVC    BPR_invalidatewholescreen
        B       ExitWimp
ordinary_message
        BL      int_sendmessage
        STR     R2,[sp,#1*4]            ; return R2 = actual task handle
        B       ExitWimp                ; (0 if error has occurred)


int_sendmessage_fromwimp
        Push    "LR"
        LDR     R14,taskhandle
        Push    "R14"
        MOV     R14,#0                  ; fake it so sender is task 0
        STR     R14,taskhandle
        BL      int_sendmessage
        Pull    "R14"
        STR     R14,taskhandle
        Pull    "PC"


; NK's optimise
; if there is already a message_slot_size on the message queue
; for this task, then just update it rather than add another.

      [ NKmessages2

check_mem_message
        TEQ     R0,#User_Message
        MOVNE   PC,LR

        Push    "R7,LR"
        LDR     R7,=Message_SlotSize
        LDR     LR,[R1,#16]
        TEQ     LR,R7
        Pull    "R7,PC",NE

; check queue
        Push    "R0-R3"
        LDR     R0,headpointer
        LDR     R2,taskhandle
        CMP     R2,#0
        LDRGT   R14,[wsptr,R2]          ; NB task must be alive!
        LDRGT   R14,[R14,#task_flagword]
        MOVGT   R14,R14,LSR #flag_versionbit
        ORRGT   R2,R2,R14,LSL #flag_versionbit
        CMP     R0,#nullptr
        LDRNE   R0,[R0,#msb_link]       ; skip first message on stack - it may already have been delivered to some tasks
05
        CMP     R0,#nullptr
        BEQ     %FT99
        LDR     R3,[R0,#msb_reasoncode]
        TEQ     R3,#User_Message
        LDREQ   R3,[R0,#msb_sender]
        TEQEQ   R3,R2
; its the same task, is it the right message?
        LDREQ   R3,[R0,#msb_size+16]
        TEQEQ   R3,R7
        LDRNE   R0,[R0,#msb_link]
        BNE     %BT05

        LDR     R2,[R1,#24]             ; new next slot
        LDR     R1,[R1,#20]             ; new current

        STR     R1,[R0,#msb_size+20]
        STR     R2,[R0,#msb_size+24]
        Pull    "R0-R3,R7,PC"

99
        CMP     PC,#0
        Pull    "R0-R3,R7,PC"
      ]


int_sendmessage
        Push    "R3-R7,handle,LR"
;
        Debuga  ms,"*"
;
; validate receiving task / window handle
;
      [ NKmessages2
        BL      check_mem_message
        Pull    "R3-R7,handle,PC",EQ
      ]

        MOV     R6,#msh_wastask         ; assume not a window handle first
;
        CMP     R2,#0                   ; 0 ==> broadcast to all tasks
        LDREQ   R2,=(:INDEX:taskpointers):OR:msf_broadcast
        BEQ     gottaskhandle
;
        TST     R2,#3
        BEQ     trytaskhandle
;
        CMP     R2,#nullptr2            ; is this the icon bar?
        MOVNE   R6,R2                   ; R6 = window handle
        BNE     %FT01
;
        Push    "R0,R1"
        ORR     R6,R3,#msh_iconbar      ; R6 = window/icon handle
        MOV     R4,R3                   ; R4 = icon handle
        BL      findicon                ; R7 --> iconbar left/right (ignored)
        Pull    "R0,R1"
        LDREQ   R2,[R2,#icb_taskhandle]
        MOVNE   R2,#0                   ; if not found, don't deliver
        B       %FT02                   ; else add in version bits
01
        MOVS    handle,R2               ; if R2<0, treat as system window
        MOVMI   R2,#0                   ; 0 => system, -1 => menu
        BLPL    checkhandle             ; preserves flags (unless error)
        Pull    "R3-R7,handle,PC",VS    ; illegal window handle
        LDRPL   R2,[handle,#w_taskhandle]
02

; see if this window belongs to the Wimp or the menu owner
; if version 2.18 or later, menu owners can receive messages for menus

        CMP     R2,#0                   ; get the Wimp to interpret some actions
        CMPLE   R0,#Close_Window_Request
        LDRLE   R2,=MSToWimpMagicHandle ; Special Wimp window task handle for message system
        BLE     gottaskhandle

        CMP     R2,#0                   ; if this is a Wimp window,
        BGT     %FT03
        LDRLT   R2,menutaskhandle       ; see if the menu owner is clever
        CMPLT   R2,#0
        MOVLT   R2,#0
        BLE     gottaskhandle           ; don't deliver if Wimp window or no menus

        LDR     R14,[wsptr,R2]
        TST     R14,#task_unused
        MOVNE   R14,#0
        LDREQ   R14,[R14,#task_wimpver] ; does it know about Wimp 2.18?
        CMP     R14,#218
        MOVLT   R2,#0
        BLT     gottaskhandle
03

; convert internal task handle to external form

        LDR     R14,[wsptr,R2]          ; add in version bits (if alive)
        TST     R14,#task_unused
        LDREQ   R14,[R14,#task_flagword]
        MOVEQ   R14,R14,LSR #flag_versionbit
        ORREQ   R2,R2,R14,LSL #flag_versionbit
        B       gottaskhandle

trytaskhandle
        BL      validtask               ; In: R2=task, Out: R5=internal task
        BVS     %FT99                   ; don't worry if it's dead yet

; work out sender for all types of message

gottaskhandle
        LDR     R4,taskhandle           ; set up sender and myref fields
        CMP     R4,#0
        LDRGT   R14,[wsptr,R4]          ; NB task must be alive!
        LDRGT   R14,[R14,#task_flagword]
        MOVGT   R14,R14,LSR #flag_versionbit
        ORRGT   R4,R4,R14,LSL #flag_versionbit
        STR     R4,sender               ; used later when block is copied
;
; now check for user message / other reason code
;
        Debug   ms,"SendMessage: R0,R1,R2,R6 (processed) =",R0,R1,R2,R6
        TEQ     R0,#User_Message
        TEQNE   R0,#User_Message_Recorded
        TEQNE   R0,#User_Message_Acknowledge
        BNE     notusermess
;
        Push    "R3-R7"
        LDMIA   R1,{R3-R7}
        Debug   ms,"UserMessage:",R3,R4,R5,R6,R7
        Pull    "R3-R7"
;
; delete queued message if referenced by 'yourref'
; (it is being acknowledged)
;
        LDR     R3,[R1,#ms_yourref]             ; NB: ms_ not msb_ !!!
        ADR     R4,headpointer-msb_link
01
        LDR     R5,[R4,#msb_link]
        CMP     R5,#nullptr
        BEQ     doneackmess                     ; finished
        LDR     R14,[R5,#msb_myref]
        TEQ     R14,R3                          ; same id?
        MOVNE   R4,R5
        BNE     %BT01

        [ true
        LDR     R14,[R5,#msb_reasoncode]                ; WAGA WAGA WAGA!!!!
        TEQ     R14,#User_Message
        TEQNE   R14,#User_Message_Recorded
        TEQNE   R14,#User_Message_Acknowledge
        MOVNE   R4,R5

        BNE     %BT01
        ]
;
        Debug   ms,"Acknowledged block deleted:",R5
        Push    "R0-R2"
        LDR     R14,[R5,#msb_link]              ; #nullptr in version 1.43 !!!
        STR     R14,[R4,#msb_link]
        CheckMsgQ
        MOV     R0,#ModHandReason_Free
        MOV     R2,R5
        BL     XROS_Module
        Pull    "R0-R2"                 ; ignore errors
doneackmess
;
; set up sender and myref fields automatically
; NB: sender taskhandle includes version number bits!
;
        LDR     R14,myref
        ADDS    R14,R14,#1              ; clears V too!
        ADDEQ   R14,R14,#1              ; avoid 0
        STR     R14,myref
;
        LDR     R3,ROMstart
        LDR     R5,ROMend
        CMP     R1,R3                   ; don't splat the ROM!
        CMPHS   R5,R1
        LDR     R4,sender               ; worked out earlier
        STRLO   R4,[R1,#ms_sender]
        STRLO   R14,[R1,#ms_myref]
        Debug   ms,"New sender,my_ref =",R4,R14
;
; check for User_Message_Acknowledge - if it is, then don't actually send it
; (the message has already done its job)
;
        TEQ     R0,#User_Message_Acknowledge
        BEQ     %FT99                   ; return R2 = actual task handle

notusermess
        BL      calcmessagesize         ; R0,R1 = reasoncode,block;
;                                       ; on exit R3 = size
        Push    "R0-R3"                 ; reasoncode,block,receiver,size
        ADDVC   R3,R3,#msb_size
        BLVC    claimblock              ; R2 --> allocated block
        ADDVS   sp,sp,#4*4
        BVS     %FT99

; use lastpointer to determine where we should put the message

      [ NKmessages1
        LDR     R4,lastpointer
        CMP     R4,#nullptr
        ADREQ   R4,headpointer-msb_link
      |
        ADR     R4,headpointer-msb_link
01
        LDR     R14,[R4,#msb_link]
        CMP     R14,#nullptr
        MOVNE   R4,R14
        BNE     %BT01
      ]

        STR     R2,[R4,#msb_link]       ; add to end of list (FIFO)
        STR     R6,[R2,#msb_handle]     ; hope this is still intact!
      [ NKmessages1
        STR     R2,lastpointer
      ]

        Pull    "R4-R7"
;
; R4=reasoncode, R5=block, R6=receiver, R7=size
;
        MOV     R0,#nullptr
        ASSERT  msb_link = 0
        ASSERT  msb_receiver = 4
        ASSERT  msb_allsender = 8
        LDR     R14,sender
        STMIA   R2,{R0,R6,R14}
;
        STR     R4,[R2,#msb_reasoncode] ; reason code
        ADD     R2,R2,#msb_size
        B       %FT03
01
        LDR     R14,[R5,R7]
        TEQ     R4,#User_Message        ; can't be User_Message_Acknowledge!
        TEQNE   R4,#User_Message_Recorded
        BNE     %FT02
        TEQ     R7,#ms_sender
        LDREQ   R14,sender              ; in case block was in ROM
        TEQ     R7,#ms_myref
        LDREQ   R14,myref               ; ditto
02
        STR     R14,[R2,R7]
03
        SUBS    R7,R7,#4                ; now the actual message block
        BPL     %BT01
;
; message is not actually sent until the next Wimp_Poll
;
        MOVS    R2,R6                   ; on exit R2 = actual task handle
        MOVMI   R2,#0                   ; if broadcast, don't confuse punter
99
        MOVVS   R2,#0                   ; message not sent if error occurs
        Pull    "R3-R7,handle,PC"

        LTORG

; Get the Wimp to decide a message directly, if addressed at a system window
; In:   R2 -> msb message block
;       R5 = MSToWimpMagicHandle
; Out:  Goes to postposting (to junk message)
;       R2, R5 preserved

autowimp_menu
        LDR     R0,[R2,#msb_reasoncode]
        TEQ     R0,#Open_Window_Request
        BEQ     %FT01
        TEQ     R0,#Close_Window_Request
        BNE     postposting
        LDR     R0,[R2,#msb_size+u_handle]
        BL      int_close_window
        B       postposting
01
        Push    "R2,R5"
;
        LDR     R1,[R2,#msb_allsender]
        Debug   autoopen,"Open request came from task :",r1
        TEQ     r1,#0
        Pull    "R2,R5",NE
        BNE     postposting             ; refuse to open if not from WIMP.
;
        ADD     R1,R2,#msb_size
        MOV     userblk,R1
        Debug   opn,"Openning one of the wimp's windows..."
        BL      int_open_window
        Debug   opn,"Wimp window successfully opened"
        Pull    "R2,R5"
        B       postposting

;
; Entry:  R2 = external task handle
; Exit:   R5 = internal task handle, V clear (if valid)
;         R0 --> "Bad Task handle", V set (if invalid)
;         note that the version bits are not validated at this stage
;         preserves all but R5 if no error
;

validtask
        Push    "R3,LR"
;
        LDR     R5,=:INDEX:taskpointers
        MOV     R3,#maxtasks
        MOV     R14,R2,LSL #32-flag_versionbit
01
        TEQ     R14,R5,LSL #32-flag_versionbit
        Pull    "R3,PC",EQ              ; do this even if task is dead
        ADD     R5,R5,#4                ; (message is ignored later)
        SUBS    R3,R3,#1
        BNE     %BT01
        Debug   opn,"**** validtask fails handle",R2
        MyXError  WimpBadTaskHandle
        Pull    "R3,PC"
        MakeErrorBlock WimpBadTaskHandle
        LTORG

;
; Entry:  R2 = external task handle
; Exit:   R5 = internal task handle, V clear (if valid)
;         R6 --> task block (if alive)
;         R0 --> "Bad Task handle", V set (if invalid, or dead)
;

validtask_alive
        Push    "LR"
;
        BL      validtask
        Pull    "PC",VS
;
        LDR     R6,[wsptr,R5]          ; if this is not the same task
        TST     R6,#task_unused
        LDREQ   R14,[R6,#task_flagword]        ; (compare version numbers)
        MOVEQ   R14,R14,LSR #flag_versionbit
        TEQEQ   R14, R2,LSR #flag_versionbit
      [ debug
        Pull    "PC",EQ
        Debug   err,"**** validtask_alive fails handle",R2
      ]
        MyXError  WimpBadTaskHandle,NE
        Pull    "PC"

;
; Entry:  R0 = reason code
;         R1 --> user block
;

calcmessagesize
        Push    "LR"
;
        CMP     R0,#max_reason
        BCS     err_badreason
        ADR     R14,mess_sizes
        LDR     R3,[R14,R0,LSL #2]
        CMP     R3,#0
        Pull    "PC",GE                 ; < 0 ==> work it out
;
        TEQ     R0,#Menu_Select
        BEQ     go_menuselsize
        TEQ     R0,#User_Message
        TEQNE   R0,#User_Message_Recorded
        TEQNE   R0,#User_Message_Acknowledge
        BNE     err_badreason
        LDR     R3,[R1,#ms_size]
        TST     R3,#3                   ; must be a multiple of 4
        BNE     err_badmesssize
        CMP     R3,#max_messsize
        RSBLSS  R14,R3,#min_messsize   ; must include header
        Pull    "PC",LS

err_badmesssize
        MyXError  WimpBadMessageSize
        Pull    "PC"

mess_sizes
        DCD     4 * 0                   ; null
        DCD     4 * 1                   ; redraw_window
        DCD     4 * 8                   ; open_window (wh,x0,y0,x1,y1,sx,sy,bh)
        DCD     4 * 1                   ; close_window
        DCD     4 * 1                   ; ptr_leaving_window
        DCD     4 * 1                   ; ptr_entering_window
        DCD     4 * 6                   ; mouse_click (mx,my,bt,wh,ih,ob)
        DCD     4 * 4                   ; user_dragbox (x0,y0,x1,y1)
        DCD     4 * 7                   ; key_pressed (wh,ih,x,y,h,i,k)
        DCD     -1                      ; menu_select
        DCD     4 * 10                  ; scroll_window (cf. open_window)
        DCD     4 * 6                   ; lose_caret
        DCD     4 * 6                   ; gain_caret
        DCD     0               ;
        DCD     0               ; reserved (13..16)
        DCD     0               ;
        DCD     0               ;
        DCD     -1                      ; user_message
        DCD     -1                      ; user_message_recorded
        DCD     -1                      ; user_message_acknowledge
        ASSERT  (.-mess_sizes) = max_reason*4

go_menuselsize
        MOV     R3,R1                   ; R3 --> start of block
01
        LDR     R14,[R3],#4
        CMP     R14,#0                  ; stop on -1
        BGE     %BT01
        SUB     R3,R3,R1                ; R3 = size of block
        Pull    "PC"

err_badreason
        MyXError  WimpBadReasonCode
        Pull    "PC"

        MakeErrorBlock WimpBadMessageSize
        MakeErrorBlock WimpBadReasonCode

;
; mark any queued messages relating to windows/icons if window/icon deleted
; Entry:  R0 = window/icon handle
;

msh_iconbar     *       1:SHL:30
msh_wastask     *       1:SHL:29

byemessages
        Push    "R1,LR"
;
        ADR     R1,headpointer-msb_link
01
        LDR     R1,[R1,#msb_link]
        CMP     R1,#nullptr
        Pull    "R1,PC",EQ
;
        LDR     R14,[R1,#msb_handle]
        TEQ     R14,R0
        MOVEQ   R14,#0
        STREQ   R14,[R1,#msb_receiver]  ; this won't now be delivered
        B       %BT01


;;----------------------------------------------------------------------------
;; Start task
;; Entry:  R0 --> command (passed to XOS_CLI)
;; Exit:   eventually the Wimp will get back to you !!!
;;----------------------------------------------------------------------------

SWIWimp_StartTask
        MyEntry "StartTask"
;
; you can only start a task if you are a live Wimp task yourself
;
        LDR     R5,taskhandle
        LDR     R6,singletaskhandle
        TEQ     R5,R6
        LDRNE   R4,[wsptr,R5]                   ; check that parent is alive
        TEQNE   R4,#task_unused                 ; note TEQ not TST !!!
        MyXError  WimpCantTask,EQ
;
; save FP registers on Wimp_StartTask if task knows about Wimp 2.23 onwards
;
        BLVC    saveFPregs                      ; R4 -> task block
        BVS     ExitWimp
;
; save VFP context, lazily if possible
;
        Push    "R0-R1"
        MOV     R0,#0
        MOV     R1,#VFPSupport_ChangeContext_Lazy+VFPSupport_ChangeContext_AppSpace
        SWI     XVFPSupport_ChangeContext
        MOVVS   R0,#0 ; Ignore error (probably means VFPSupport isn't loaded)
        Debug   fp,"VFP on Wimp_StartTask entry",R0
        STR     R0,[R4,#task_vfpcontext]
        Pull    "R0-R1"
;
; find a spare task handle for the new task
;
        ADRL    R5,taskpointers
        MOV     R6,#maxtasks
01
        LDR     R14,[R5],#4
        TST     R14,#task_unused
        BNE     %FT02
        SUBS    R6,R6,#1
        BNE     %BT01
;
        MyXError  WimpNoTasks
        B       ExitWimp
02
        SUB     R5,R5,#4                ; R5 --> task data pointer entry
;
; now stash the parent task on the return stack, and start up the new one
;
        ADRL    R1,taskbuffer
01
        LDRB    R14,[R0],#1
        STRB    R14,[R1],#1
        CMP     R14,#32                 ; terminate on any ctrl-char
        BCS     %BT01
;
        BL      mapslotout              ; map parent out of the way
;
        LDR     R14,taskSP
        LDR     handle,polltaskhandle
        STR     handle,[R14],#4         ; empty ascending stack
        STR     R14,taskSP
        SUB     R14,R5,wsptr
        STR     R14,taskhandle
;
; we must mark the task used, so that ExitPoll can swap into it
; Version number = 0 => task is not initialised
;
        MOV     R0,#0                   ; latest known Wimp version
        BL      markinitialised         ; changes task 'version number'
        BVS     ExitWimp
;
        LDR     R14,taskhandle          ; assume single-tasking for now
        STR     R14,singletaskhandle
;
        MOV     R14,#0                  ; reset all handlers
        STR     R14,handlerword
        STR     R14,parentquithandler   ; must start application !!!
        BL      setdefaulthandlers
;
; allocate memory for the new task, then use callback to start it up
; [taskbuffer..] contains the *command to execute
;
        ADRL    R14,Module_BaseAddr
        BL      allocateslot            ; updates memorylimit
;
        ADRL    R0,taskbuffer           ; copy of *command is in here
        LDR     R5,taskhandle
        LDR     R5,[wsptr,R5]
        ADRL    R14,runthetask          ; PC must be set up explicitly
        STR     R14,[R5,#task_registers+4*15]   ; note PC has no flags, ie USR on 26-bit
        ; this next bit is harmless on a 26-bit system, as the 17th word is ignored
        MRS     R14,CPSR
        BIC     R14,R14,#2_11101111     ; get USR26/USR32, ARM, FIQs+IRQs on
        STR     R14,[R5,#task_registers+4*16]


;
; to be on the safe side, bring up a text window if any chars printed
;
        Push    "R0"                    ; this allows escape etc.
        SWI     XWimp_CommandWindow     ; in case this is a wally task
        Pull    "R0"                    ; Remember *command ptr
        CLRV

        B       ExitPoll_tochild        ; swap tasks, and end up at 'runthetask'

        MakeErrorBlock WimpCantTask
        MakeErrorBlock WimpNoTasks

;
; Entry point where we run the task!
; Entry:  R0 --> command to execute
;         entered in USR mode (I hope!)
;

runthetask
        MOV     R1,R0                   ; close down the task !!!
        SWI     Wimp_CloseDown

        MOV     R0,R1
        SWI     OS_CLI                  ; R0 --> OS_CLI command
        SWI     OS_Exit                 ; exit back to Wimp

;
; set up default environment handlers (Wimp should replace them all)
; only reset the ones corresponding to 0 bits in [handlerword]
;  0 in table ==> leave alone (MemoryLimit,ApplicationSpaceSize)
;  1 in table ==> use default handler
; >1 in table ==> use values in table
;

setdefaulthandlers
        Push    "R1-R6,LR"
;
        ADR     R4,defaulthandlers      ; R4 --> data
        LDR     R5,handlerword          ; R5 = flag word (0 bit ==> set it)
        MOV     R6,#MaxEnvNumber
01
        LDR     R1,[R4],#4              ; if zero, it's not an address offset
        TEQ     R1,#0
        RSBEQ   R0,R6,#MaxEnvNumber     ; R1=0 ==> use default handler
        SWIEQ   XOS_ReadDefaultHandler  ; NB: R0 can be set to 0 by this call!
        Pull    "R1-R6,PC",VS
        ADDNE   R1,R1,R4                ; R1 --> code address
        MOVNE   R2,wsptr
        ADRNE   R3,errorbuffer
02
        MOVS    R5,R5,LSR #1            ; has this handler been set already?
        RSBCC   R0,R6,#MaxEnvNumber
        SWICC   XOS_ChangeEnvironment
        SUBS    R6,R6,#1
        BNE     %BT01
;
        Pull    "R1-R6,PC"

;
; Default settings to pass to SWI XOS_ChangeEnvironment
;       R1 --> code address / buffer pointer
;       R2  =  returned in R12 (if R1 is an address) - maybe
;       R3 --> block           (if R1 is an address)
;

defaulthandlers
        DCD     0                       ; MemoryLimit

        DCD     0                       ; UndefinedHandler
        DCD     0                       ; PrefetchAbortHandler
        DCD     0                       ; DataAbortHandler
        DCD     0                       ; AddressExceptionHandler
        DCD     0                       ; OtherExceptionHandler

        DCD     Do_ErrorHandler-.-4
        DCD     0                       ; CallBackHandler
        DCD     0                       ; BreakPointHandler

        DCD     0                       ; EscapeHandler
        DCD     0                       ; EventHandler
        DCD     Do_ExitHandler-.-4
        DCD     0                       ; UnusedSWIHandler

        DCD     0                       ; ExceptionDumpArea
        DCD     0                       ; ApplicationSpaceSize
        DCD     Module_BaseAddr-.-4     ; CAO pointer

        DCD     0                       ; upcall handler

        ASSERT  (.-defaulthandlers)/4 = MaxEnvNumber

;
; report error contained in errorhandlerbuffer
; in USR mode here!
;

Do_ErrorHandler
        MOV     R12,R0                  ; wsptr is in R0!
      [ debugtask1
        ADRL    R13,stackspace
        Debuga  task1,"Error reported to Wimp: "
        CLI     "HostVdu"
        ADRL    R0,errorbuffer+8        ; skip saved PC & error number
        SWI     XOS_Write0
        SWI     XOS_NewLine
        CLI     "TubeVdu"
      ]
        ADRL    R0,errorbuffer+4        ; skip saved PC
        MOV     R1,#erf_cancelbox:OR:erf_htcancel:OR:erf_dontwait
        MOV     R2,#nullptr                        ; no application
        SWI     XWimp_ReportError
        SWI     XOS_Exit                ; must abort task (no error handler)

;
; delete task and exit back to the Wimp
; NB we must be in USR mode !!!
; NB Wimp_CloseDown causes the command window to be closed too
;

Do_ExitHandler
      [ debugtask1
        ADRL    R13,stackspace          ; need some stack to call debug!
      ]
        SWI     XWimp_CloseDown         ; delete task (may restore handler)
01
        MOV     R0, #198                ; read EXEC file handle
        MOV     R1, #0
        MOV     R2, #&FF
        SWI     XOS_Byte
        TEQ     R1, #0                  ; was an EXEC file open?
        BEQ     %FT02

        MOV     R0,#OSArgs_EOFCheck     ; if end of file, ignore it!
        SWI     XOS_Args
        TEQ     R2,#0
        BNE     %FT02

        ADR     r0, CliDPrompt
        ADR     r1, errorbuffer
        MOV     r2, #?errorbuffer
        MOV     r3, #0
        MOV     r4, #3
        SWI     XOS_ReadVarVal
        MOVVC   r0,r1
        MOVVC   r1,r2
        ADRVS   r0, DefaultPrompt
        MOVVS   r1, #1
        SWI     OS_WriteN

        ADR     R0,errorbuffer
        MOV     R1,#?errorbuffer
        MOV     R2,#32
        MOV     R3,#&FF
        SWI     OS_ReadLine             ; provoke errors (handler is there)
        SWICC   OS_CLI                  ; should preserve flags
        BCC     %BT01

        MOV     R0,#126                 ; acknowledge escape
        SWI     OS_Byte
        ADR     R0,ErrorBlock_Escape
        MOV     R1,#0
        MOV     R2,#0                   ; global error
        SWI     MessageTrans_ErrorLookup
        SWI     OS_GenerateError        ; generate escape error
        MakeErrorBlock Escape

02
        Debug   task1,"Exitting back to Wimp"
        ADR     R1,errorbuffer          ; ensure R1 > &8000 !!!
        SWI     XWimp_Poll              ; if task returns, it must be the last
        Debug   task1,"Poll returns - Exitting from Wimp"
        SWI     OS_Exit

CliDPrompt      =       "CLI$Prompt", 0
      [ debug
        ALIGN
      ]
DefaultPrompt   =       "*"
                ALIGN


;;-----------------------------------------------------------------------------
;; Exit point for task-switching
;;-----------------------------------------------------------------------------

; Report any errors during Wimp_Poll internally, unless single-tasking

reporterror
        LDR     R5,taskhandle
        LDR     R6,singletaskhandle
        TEQ     R5,R6
        BEQ     returnerror             ; can return errors to single task

        MOV     R1,#erf_okbox
        ADR     R2,wimp
        SWI     XWimp_ReportError
        B       repollwimp

wimp    DCB     "Wimp",0
        ALIGN

ExitPoll_tochild
        Debug   task1,"Exit to child:",#taskhandle
        MOV     R14,#-2
        STR     R14,sender              ; don't call postfilters
        B       ExitPoll

ExitPoll_toparent
        Debug   task1,"Exit to parent:",#taskhandle
        MOV     R14,#-1
        STR     R14,sender              ; don't return R2 from Wimp_StartTask

ExitPoll
        Debug   poll2, "ExitPoll"
        BVS     reporterror             ; don't return to caller
returnerror

; The Wimp MUST NOT exit to a dead task (no register data !!!)
; Wimp_Poll tries to find a live task on entry - it calls OS_Exit if none left

        LDR     handle,taskhandle
;
        LDR     R14,ptr_DomainId
        STR     handle,[R14]            ; for Stuart

        Debug   task,"Exit Poll: (old),task,reason =",#polltaskhandle,handle,R0

        TEQ     R0,#No_Reason           ; Not a null event?
 [ Stork
  [ PokeBorder
        Push    "R0-R1",NE
        LDRNE   R1, =&40FFFF00          ; cyan = fast
        MOVNE   R0, #VIDC
        STRNE   R1, [R0]
        Pull    "R0-R1",NE
  ]
        LDRNE   R14, WimpPortableFlags
        BICNE   R14, R14, #PowerSave
        STRNE   R14, WimpPortableFlags  ; (so go at full speed)
        TSTNE   R14, #PortableFeature_Speed     ; And speed switching works?
 |
        LDRNE   R14,WimpPortableFlag
        TEQNE   R14,#0                  ; And the portable module present?
 ]
        BEQ     %FT01
        Push    "R0-R1"
        MOV     R0,#0
        MOV     R1,#0
        SWI     XPortable_Speed         ; if not a null event then make it go fast
        Pull    "R0-R1"
01
      [ debugtask3
        LDR     R14,singletaskhandle
        CMP     R14,#nullptr            ; if single-tasking,
        CMPNE   R14,handle              ; we mustn't exit to anyone else!!!
        BEQ     %FT01
        Debug   task3,"Task swap: single,taskhandle =",R14,handle
01
      ]

;
      [ StartTaskPostFilter
        LDR     R14,sender
        CMP     R14,#-1
        BLT     %FT01                ; Are we starting up Wimp_StartTask?
        BNE     %FT02                ; Are we returning from Wimp_StartTask?

; We're returning from Wimp_StartTask and
; R0 = task handle of child (or 0). Wimps before 3.96
; would not call the post-filter in this case, but would
; call it if Wimp_StartTask returned 0 (so the filter
; would think a null event was happening.) Now, the
; Toolbox (and probably other filters) relies on the
; post filter to monitor the current task. If the postfilter
; doesn't get called here then there is no way of telling
; that this task has become active. So, we now call the filter
; with a null event, and ignore any attempt to claim it. (In
; the past the filter was able to claim the "null" event if
; Wimp_StartTask returned 0, causing instant death.
; This is the problem that hit Toolbox 1.33).
;
; Hopefully this shouldn't cause any problems, as filters
; will have had to be able to deal with the dummy "null"
; event for at least some Wimp_StartTask calls already.

        Push    "R0,R1"
        MOV     R0,#No_Reason
        MOV     R1,userblk
        CallFilter postfilter           ; call the post-poll filter (ignoring
        Pull    "R0,R1"                 ; R0 return)
        B       %FT01

02
      |
        CMP     R0,#max_reason          ; Valid message?
        BHS     %FT01                   ; No then jump,maybe -> *command from Wimp_StartTask
      ]

        Push    "R1"
        MOV     R1,userblk
        CallFilter postfilter           ; call the post-poll filter
        Pull    "R1"
        CMP     R0,#-1
        BEQ     repollwimp              ; if it claimed then just re-poll
01

        Push    "R0-R1"
        LDR     R4,[wsptr,handle]
        TEQ     R4,#task_unused

      [ debugtask4
; Stamp with event time for task priority and swapping

        SWINE   XOS_ReadMonotonicTime
        BEQ     %FT00
        Debug   task4,"Time",R0
00
        STRNE   R0,[R4,#task_eventtime]
      ]

; restore FP registers if they were saved (ie. save block present)

        LDRNE   R0,[R4,#task_fpblock]
        TEQNE   R0,#0                   ; NE => restore registers
        MOVEQ   R5,#C_runtime_status    ; ensure caller gets &70000 if he didn't save regs
        WFSEQ   R5
        BEQ     %FT01

        Debug   fp,"Restoring FP state from block at",R0

        MOV     R5,#0                   ; avoid FP exceptions
        WFS     R5                      ; will still occur if FPEmulator RMKilled
      [ FPE4
       [ false
        LFM     F0,4,[R0,#fp_reg0]      ; (only gets here if active previously)
        LFM     F4,4,[R0,#fp_reg4]
       |
        ; AAsm assembles the above as post-indexed not pre-indexed.
        ; Do it manually (bluch).
        DCD     &ED900200 :OR: (fp_reg0:SHR:2)
        DCD     &ED904200 :OR: (fp_reg4:SHR:2)
       ]
      |
        LDFE    F0,[R0,#fp_reg0]        ; (only gets here if active previously)
        LDFE    F1,[R0,#fp_reg1]
        LDFE    F2,[R0,#fp_reg2]
        LDFE    F3,[R0,#fp_reg3]
        LDFE    F4,[R0,#fp_reg4]
        LDFE    F5,[R0,#fp_reg5]
        LDFE    F6,[R0,#fp_reg6]
        LDFE    F7,[R0,#fp_reg7]
      ]
        LDR     R5,[R0,#fp_status]
        WFS     R5
01
; restore VFP context
        TEQ     R4,#task_unused
        LDRNE   R0,[R4,#task_vfpcontext]
        MOVNE   R1,#VFPSupport_ChangeContext_Lazy
        TEQNE   R0,#0 ; We should already be on the null context, so only call if user does have a context to restore
        DebugIf NE,fp,"VFP on Wimp_Poll exit",R0
        SWINE   XVFPSupport_ChangeContext
        Pull    "R0-R1"

      [ AutoHourglass
        Push    "R0-R2"
        LDR     R1, hourglass_status
      [ debugautohg
        Push    "handle"
        LDR     handle, taskhandle
        Debug   autohg, "Hourglass_On  at task switch: taskhandle, old status =", handle, R1
        Pull    "handle"
      ]
        TEQ     R1, #2
        SWIEQ   XHourglass_Off          ; if autohourglass is still pending or animating, turn it off
        TEQ     R1, #0
        MOVEQ   R0, #WrchV              ; get back on WrchV if necessary
        ADREQ   R1, deactivate_hourglass_on_wrchv
        BLEQ    claim

        MOV     R0, #hourglass_delay
        SWI     XHourglass_Start        ; turn on using special delay time
        CLRV                            ; ignore errors
        MOV     R1, #2
        STR     R1, hourglass_status    ; mark autohourglass fully active
        Pull    "R0-R2"
      ]
        BL      DeletePollTask          ; Delete task from polltask list

; don't need to do callback if this is the same task

        LDR     R14,polltaskhandle      ; see if this is the same task
        TEQ     handle,R14              ; NB doesn't affect V flag!!!
        BEQ     putsender_ExitWimp      ; exit, and set up R2 if required
;
; ensure that R0 and the flags are passed back to the correct task
; bodge: if same task, also keep R0 and flags now
;
      [ No32bitCode
        Push    "R0,PC"                 ; save R0 and flags
        SETPSR  I_bit, R5               ; disable interrupts
      |
        MRS     R5,CPSR
        Push    "R0,R5"
        ORR     R5,R5,#I32_bit
        MSR     CPSR_c,R5
      ]
;                                       ; NB preserve R14 in this code
        LDR     R5,[wsptr,handle]
        STR     R0,[R5,#task_registers+4*0]
      [ No32bitCode
        LDR     R0,[R5,#task_registers+4*15]
      |
        TEQ     PC,PC                           ; 32-bit system?
        LDRNE   R0,[R5,#task_registers+4*15]    ; 26-bit: modify R15
        LDREQ   R0,[R5,#task_registers+4*16]    ; 32-bit: modify CPSR
      ]
        BICVC   R0,R0,#V_bit            ; set up correct V bit
        ORRVS   R0,R0,#V_bit
      [ No32bitCode
        STR     R0,[R5,#task_registers+4*15]   ; save for new task
      |
        STRNE   R0,[R5,#task_registers+4*15]
        STREQ   R0,[R5,#task_registers+4*16]
      ]
;
; set up callback handler
; NOTE: since the task is already paged in, its handlers are set up already
; XXXX: it appears that the handlers are not always in the block yet!
;
        Debug   task1,"Setting callback handler"
;
        MOV     R0,#CallBackHandler     ; be careful when old task is dead
        ADR     R1,callbackpoll
        MOV     R2,wsptr
        LDR     R3,[wsptr,R14]          ; save old task registers
        TST     R3,#task_unused
        ADDEQ   R3,R3,#task_registers   ; be careful of dead tasks!
        ADRNEL  R3,registerbuffer       ; use temporary buffer (regs ignored)
        SWI     XOS_ChangeEnvironment
        ADR     R14,oldcallback
        STMIA   R14,{R1-R3}             ; will be restored later
;
; Exit temporarily - comes back to callback handler
; NB -- SWI XWimp_Poll must be used, since I don't know about bit 17
;
        SWI     XOS_SetCallBack         ; set call back flag
;
        Pull    "R0,R14"
      [ No32bitCode
        TEQP    R14,#0                  ; restore flags, ready for exit
      |
        MSR     CPSR_cf,R14             ; restore flags+ints, ready for exit
      ]
;
        B       ExitWimp_noswitch       ; pulls registers & exits to callback

;..............................................................................

; here R12 --> workspace (set up by ChangeEnvironment)
;
; Should enter this code in SVC mode with Ints off
; restore environment for new task

callbackpoll
      [ debugtask
        Push    "R0,LR"
;
      [ No32bitCode
        Push    "PC"
        Pull    "R0"
        AND     R0,R0,#ARM_CC_Mask
      |
        MRS     R0, CPSR
      ]
        Debug   task,"Flags on entry to callbackpoll:",R0
;
        Pull    "R0,LR"
      ]
;
        LDR     R14,taskhandle
        LDR     R4,[wsptr,R14]          ; NB task cannot be dead
        BL      getsender_R2                    ; if [R4,#task_wimpver] >= 253
        STRGE   R2,[R4,#task_registers+2*4]     ; return R2 = sender's handle

        ADR     R0,oldcallback
        LDMIA   R0,{R1-R3}
        MOV     R0,#CallBackHandler
        SWI     XOS_ChangeEnvironment   ; restore client's handler!
;
; exit to caller
;
        TEQ     PC,PC                           ; are we 26 or 32-bit?
        ADD     lr_svc,R4,#task_registers       ; lr_svc --> register block
        LDREQ   R0,[lr_svc,#16*4]
        MSREQ   SPSR_cxsf,R0
        LDMIA   lr_svc,{R0-R14}^                ; restore USR regs
        NOP
        LDR     lr_svc,[lr_svc,#15*4]
        MOVS    PC,lr_svc                       ; exit to caller, restoring flags

;..............................................................................

; WrchV routine to deactivate the autohourglass as soon as a character is output.
; The argument for this is that if the task is plotting something, you probably
; don't need the Wimp putting up an hourglass to let you know that the machine
; hasn't stiffed.
; Using this approach, the hourglass isn't shown, for example, while Paint is
; doing a screen grab (it doesn't Wimp_Poll, but it does plot a box on the screen).
; It also copes transparently with command windows, ShellCLI etc.

; On entry:  R12 -> workspace
;            [hourglass_status] = 1 or 2 (by definition)
;            processor is in SVC mode

      [ AutoHourglass
deactivate_hourglass_on_wrchv Entry "R0-R2"
        LDR     R1, hourglass_status
        Debug   autohg, "Hourglass_Off at WrchV, old status =", R1
        TEQ     R1, #2
        SWIEQ   XHourglass_Off          ; turn off hourglass if necessary
        MOV     R0, #WrchV
        ADR     R1, deactivate_hourglass_on_wrchv
        BL      release                 ; release WrchV
        MOV     R1, #0
        STR     R1, hourglass_status    ; mark fully deactivated
        EXITS                           ; pass on call (NB: nowhere to return errors to)
      ]

;.............................................................................

; In    R4 -> task block of current task
; Out   FP registers saved if FPEmulator present and task knows Wimp 2.23

saveFPregs
        EntryS  "R0-R3"

        Debug   fp,"Saving FP state for task",#taskhandle
        Debuga  fp,"Reading FP status: "

        RFS     R1                      ; <==== NB: pending trap can occur here
                                        ; so do it before claiming block!
        Debug   fp," value =",R1

        LDR     R2,[R4,#task_fpblock]           ; block may already be claimed
        CMP     R2,#0                           ; (assume will be required again)
        MOVEQ   R3,#fp_size
        BLEQ    claimblock                      ; R2 -> block address
        STRVS   R0,[sp,#Proc_RegOffset]
        EXIT    VS
        STR     R2,[R4,#task_fpblock]

        Debug   fp,"FP save block at",R2

        STR     R1,[R2,#fp_status]
        LDR     R1,=C_runtime_status            ; now C run-time status value
        WFS     R1
      [ FPE4
       [ false
        SFM     F0,4,[R2,#fp_reg0]
        SFM     F4,4,[R2,#fp_reg4]
       |
        ; AAsm assembles the above as post-indexed not pre-indexed.
        ; Do it manually (bluch).
        DCD     &ED820200 :OR: (fp_reg0:SHR:2)
        DCD     &ED824200 :OR: (fp_reg4:SHR:2)
       ]
      |
        STFE    F0,[R2,#fp_reg0]
        STFE    F1,[R2,#fp_reg1]
        STFE    F2,[R2,#fp_reg2]
        STFE    F3,[R2,#fp_reg3]
        STFE    F4,[R2,#fp_reg4]
        STFE    F5,[R2,#fp_reg5]
        STFE    F6,[R2,#fp_reg6]
        STFE    F7,[R2,#fp_reg7]
      ]
;
        EXITS                                   ; preserve flags

;.............................................................................

; In    handle = task handle of current task (must be alive)
;       R12 -> module workspace
;       [sp..] = stacked R1..
; Out   exits to Wimp with or without R2 set up (as appropriate)

putsender_ExitWimp
        SavePSR R3                      ; save flags
        LDR     R4,[wsptr,handle]
        BL      getsender_R2            ; GE => R2 = task handle of sender
        STRGE   R2,[sp,#4]              ; R2 = second word on stack
        RestPSR R3,,f                   ; restore error state
        B       ExitWimp

;.............................................................................

; In    R4 -> task block for task about to receive an event
;       R12 -> module workspace
; Out   GE => R2 = task handle of task that sent it (0 => Wimp)

getsender_R2
        LDR     R2,[R4,#task_wimpver]   ; latest known Wimp version number
        Debug   ms,"getsender_R2: handle, wimpver, sender =",#taskhandle,R4,R2,#sender
        CMP     R2,#253
        LDRGE   R2,sender               ; GE => R2 = sender's task handle
        CMPGE   R2,#0                   ; -1/-2 => this is a Wimp_StartTask
        MOV     PC,LR


;;----------------------------------------------------------------------------
;; Error reporting SWI
;;----------------------------------------------------------------------------
;
; Entry:  R1 --> icon definition
;         R2 = coords to centre on (horizontally)
; Exit:   x0,x1 = left,right of icon
;         icon definition updated
;

setbuttonx
        LDR     x0,[R1,#i_bbx0]
        LDR     x1,[R1,#i_bbx1]
        SUB     x1,x1,x0
        SUB     x0,R2,x1,ASR #1
        ADD     x1,x0,x1
        STR     x0,[R1,#i_bbx0]
        STR     x1,[R1,#i_bbx1]
        MOV     PC,LR                   ; must preserve flags

;
; Entry:  R0 --> error block
;         R1 = flags
;              bit 0 ==> OK box displayed
;              bit 1 ==> Cancel box displayed
;              bit 2 ==> highlight Cancel box (else highlight OK box)
;              bit 3 ==> dont wait for confirmation (if text-based)
;              bit 4 ==> omit 'Error from ' in title bar
;              bit 5 ==> 'poll' error window (ie. leave open & exit)
;              bit 6 ==> finish polling error window, select [r1] and close it
;              bit 7 ==> don't beep (even if WimpFlags bit 4 clear)
;              bit 8 ==> new type error report
;              bits 9-11 ==> error type
;
;         R2 --> application name (<=0 ==> Wimp has detected the error)
;         R3 --> sprite name (for new type error report)
;         R4 --> sprite area, or 1 for Wimp area (for new type error report)
;         R5 --> comma separated additional button list, or 0 for none (for new type error report)
;
; Exit:   R1 = 1 ==> Continue (OK) box was selected
;         R1 = 2 ==> Cancel box was selected
;         R1 = 3,4... ==> additional button pressed
;

;Rough outline (not gospel!) JRC 24 Jul 1997
;	Make service call ErrorStarting
;	IF	in command mode
;	THEN	report error in text
;		poll for a key press
;		return key pressed (Return/Escape)
;	ELSE	IF	closing an open error box
;		THEN	return button-click specified
;		ELSE	Create a window structure
;			Make service call WimpReportError 1
;			Switch output to screen
;			Disable file redirection
;			Enable VDU, disable Spool, printer & serial
;			Beep
;			Add the icon definitions to the window structure
;			int_open_window
;			int_redraw_window
;			int_get_rectangle
;			Smash hourglass
;			Bound pointer to window
;			Flush keyboard and mouse
;			Start IconHigh
;			DO	Read key with no time limit
;				Check mousebuttons
;			WHILE	nothing happens
;			Unbound pointer
;			int_close_window
;			Stop IconHigh
;			Make service call ErrorButtonPressed
;			Make service call ErrorEnding
;			Restore file redirection
;			Restore output to previous state
;			Make service call WimpReportError
;		FI
;	FI

errorprefix     DCB     "NoError",0
errorprefix1    DCB     "Error",0
errorprefix2    DCB     "ErrorF",0

execcom DCB     "Exec",0
        ALIGN

; tempworkspace layout
                        ^       0
errtws_spritearea       #       4  ;   +0  as passed in R4 / set by service call claimant(s)
errtws_buttonlist       #       4  ;   +4  pointer to comma-separated list of buttons
errtws_iconend          #       4  ;   +8  icon handle of (rightmost == first-in-string == highest-icon-handle) extra button, + 1
errtws_describebuttons  #       4  ;  +12  comma-separated list of buttons to use when program error is Described
errtws_icondata         #       4  ;  +16  if a "may have gone wrong" window, -> start of icon data for error window, else 0
errtws_cancelstr        #       4  ;  +20  -> "Cancel"
errtws_flags            #       4  ;  +24
errtws_mustntuse        #       4  ;  +28  corrupted by text plotting code

SWIWimp_ReportError
        MyEntry "ReportError"
;
        [ ErrorServiceCall
        Push    "R0-R5"
        Pull    "R2-R7"
        LDR     R1,=Service_ErrorStarting
        SWI     XOS_ServiceCall
        Push    "R2-R7"
        Pull    "R0-R5"
        MOV     userblk,R1
        ]

        Push    "R0-R3"
;
        [ NewErrorSystem
        STR     R4,tempworkspace+errtws_spritearea  ; R4 gets horribly corrupted
                                                    ; but is required for 3.21
        STR     R5,tempworkspace+errtws_buttonlist  ; ditto!
        ]

        LDR     R4,commandflag
        ORR     R14,R4,#cf_suspended
        STR     R14,commandflag         ; suspend this whatever
        TEQ     R14,#cf_active:OR:cf_suspended
        BNE     useerrorwindow

noerrorwindow                           ; come back here if error window dead
        TST     R1,#erf_dontwait
        ADREQ   R0,execcom              ; cancel exec file (if any)
        SWIEQ   XOS_CLI
;
        Pull    "R0-R3"
;
; report error as a line of text
;
        TST     R1,#erf_pollexit        ; finish - cancel suspended state
        ANDNE   R1,R1,#erf_okbox:OR:erf_cancelbox
        BNE     ExitError
;
        TST     R4,#cf_suspended        ; if suspended and poll bit set,
        TSTNE   R1,#erf_poll
        BNE     %FT11                   ; don't re-print the error message
;
        SWI     XOS_WriteI+4            ; just in case
        SWI     XOS_NewLine             ; textual form of error report
        ADD     R0,R0,#4
        SWI     XOS_Write0
        SWI     XOS_NewLine
;
        TST     R1,#erf_dontwait        ; R1 preserved if bit 3 was set
        BNE     ExitError
;
        TST     R1,#erf_poll            ; unless polling,
        BNE     %FT51

        Push    "R2,R3"
;
        ADRL    R0,pressspace
        ADRL    R2,errorbuffer
        MOV     R3,#?errorbuffer
        BL      LookupToken1            ; resolve the press-space to continue token
;
        ADRL    R0,errorbuffer
        SWI     XOS_Write0              ; display it
        SWI     XOS_NewLine             ; followed by a new line
;
        Pull    "R2,R3"
51
        BL      flushkbdmouse           ; only done the first time
11
        BL      powersave_tick
        BL      pollforkey
        BNE     %FT12

        LDR     R1,[sp,#0*4]
        TST     R1,#erf_poll            ; if no result, loop unless erf_poll
        BEQ     %BT11
;
        MOV     R1,#0                   ; leave command window suspended
        B       ExitError2              ; return 'no result'

12      TEQ     R1,#&1B                 ; escape key ==> non-default

        Debug   err,"ReportError: key=",R1

        MOVNE   R1,#erf_okbox
        MOVEQ   R1,#erf_cancelbox
        LDR     R14,[sp,#0*4]
        TST     R14,#erf_htcancel
        EORNE   R1,R1,#erf_okbox:EOR:erf_cancelbox
        ANDS    R14,R14,#erf_okbox:OR:erf_cancelbox
        MOVEQS  R14,#erf_okbox          ; if flags =0 it has an OK box
        ANDS    R1,R1,R14               ; can't select button that wasn't there
        TSTEQ   R14,#erf_poll
        BEQ     %BT11                   ; try again if 0 not allowed!

        Debug   err,"ReportError: return",R1

ExitError
        LDR     R14,commandflag
        BIC     R14,R14,#cf_suspended
        STR     R14,commandflag

ExitError2
        STR     R1,[sp,#0*4]
        B       ExitWimp

;
; report error in a window
;

useerrorwindow
        LDR     R8,errorhandle          ; R8 = relative error window handle
        CMP     R8,#nullptr
        BEQ     noerrorwindow           ; oops!
;
        ADRL    R0,execcom              ; always cancel exec file (if any)
        SWI     XOS_CLI
;
        Abs     handle,R8               ; handle --> window definition
;
        TST     R1,#erf_pollexit
        BEQ     %FT01

        ADD     sp,sp,#4*4              ; skip junk on stack

        TST     R4,#cf_suspended        ; is error window open?
        BEQ     ExitError               ; forget it if not (unsuspend window)

        MOV     R4,#1                   ; highlight either icon 1 or 4
        TST     R1,#erf_okbox           ; ('OK' preferably)
        MOVEQ   R4,#4
        B       finisherror             ; make selection and close error window
01
        TST     R4,#cf_suspended        ; if suspended and poll bit set,
        TSTNE   R1,#erf_poll
        Pull    "R4-R7"                 ; R4-R7 = original R0-R3
        BLEQ    starterrorbox

        MOV     R0, #229                ; Read current escape condition enable state so we can restore it later
        MOV     R1, #0
        MOV     R2, #255
        SWI     XOS_Byte
        STRB    r1, old_escape

        MOV     R0, #229                ; Disable escape conditions (Wimp hasn't actually checked for them for a long time)
        MOV     R1, #1
        MOV     R2, #0
        SWI     XOS_Byte
;
; bodge polling loop - look for mouse click in OK / Cancel boxes
;                    - also <escape> (27, or escape condition)
;

pollit
        BL      powersave_tick
        MOV     R0,#&81                 ; read key with 0 time limit
        MOV     R1,#0
        MOV     R2,#0
        SWI     XOS_Byte                ; CS => escape, else R1 = &FF => no char
        TEQ     R2,#&FF
        BEQ     %FT02                   ; no key pressed
;
        Debug   err,"ReportError: pollit key=",R1

        TEQ     R1,#&0D
        TEQNE   R1,#&1B                 ; old allow <CR> and <Esc>
        BNE     %FT02
;
        LDR     R14, tempworkspace+errtws_flags  ; to work out which button the key corresponds to, we need the current flags
                                                 ; note 1: these flags will be correct for "may have gone wrong" boxes
        Debug   err,"Error flags=",R14           ; note 2: these flags have not been checked to ensure there is at least an OK button

        MOV     R4, #-1                 ; Return button not yet determined
        MOV     R5, #-1                 ; Escape button not yet determined
        MVN     R14, R14                ; makes life easier when doing comparisons

        TST     R14, #erf_okbox
;        CMPEQ   R4, #-1                 ; have we found both buttons yet?
;        MOVEQ   R4, R5                  ; Return -> previous Escape button
        MOVEQ   R5, #1                  ; Escape -> OK button

        TST     R14, #erf_cancelbox
;        CMPEQ   R4, #-1                 ; have we found both buttons yet?
        MOVEQ   R4, R5                  ; Return -> previous Escape button
        MOVEQ   R5, #4                  ; Escape -> Cancel button

; note, the Describe button is never selected by a keypress
        TST     R14, #erf_newtype
        BNE     %FT06
        LDR     R2, tempworkspace+errtws_buttonlist
        AcceptLoosePointer_NegOrZero R2,0
        CMP     R2,R2,ASR #31
        BEQ     %FT06 ; if no extra buttons, skip next section

        LDR     R2, tempworkspace+errtws_iconend

        CMP     R2, #8                  ; are there at least 1 extra buttons?
        CMPHS   R4, #-1                 ; have we found both buttons yet?
        MOVEQ   R4, R5                  ; Return -> previous Escape button
        SUBEQ   R5, R2, #1              ; Escape -> highest-numbered (rightmost) extra button

        CMP     R2, #9                  ; are there at least 2 extra buttons?
        CMPHS   R4, #-1                 ; have we found both buttons yet?
        MOVEQ   R4, R5                  ; Return -> previous Escape button
        SUBEQ   R5, R2, #2              ; Escape -> second highest-numbered (second rightmost) extra button
06
        TST     R14, #erf_okbox :OR: erf_cancelbox :OR: erf_htcancel
        EOREQ   R4, R4, R5              ; if all three flags were set, the meanings of Return and Escape are reversed
        EOREQ   R5, R4, R5
        EOREQ   R4, R4, R5

        CMP     R5, #-1                 ; if no Escape button has been found, an OK/Continue button will have been added
        MOVEQ   R5, #1
        CMP     R4, #-1                 ; if no Return button has been found, there is only one button, so act as for Escape
        TEQNE   R1, #&1B                ; was Escape pressed?
        MOVEQ   R4, R5                  ; R4 now holds selected icon number
        Debug   err,"Icon=",R4
;
        B       finisherror
02
        LDR     R5,mousebuttons
        BL      getmouseposn            ; R0,R1 = mouse coords, R2 = buttons
        Push    "R5"
        MOV     R5,#0                   ; don't match shaded icons (not that there are any)
        BL      int_get_pointer_info    ; R3,R4 = window/icon handle
        Pull    "R5"
	;Debug	upcall, "int_get_pointer_info: w, i, oldbuttons, newbuttons:", R3, R4, R5, R2
        LDR     R14,errorhandle
        TEQ     R3,R14                  ; must be error window!
        BNE     notover
        [ NewErrorSystem
        SUB     R14, R4, #6             ; Describe button is handle 6, additional buttons are 7 to 6+maxno_error_buttons
        CMP     R14, #maxno_error_buttons
        CMPLS   R14, R14                ; set Z if in range
        ]
        TEQNE   R4,#1                   ; icon 1 = 'OK' box
        TEQNE   R4,#4                   ; icon 4 = 'Cancel' box
        BNE     notover
        [ false
        EOR	R14,R2,R5		; AR 13/8/97 look at both transitions, fixed a problem of double clicks
 	|
        BIC     R14,R2,R5               ; look for +ve edge SELECT/ADJUST
	]
        BICS    R14,R14,#button_middle  ; (ignore menu button)
        BNE     finisherror

notover
        LDR     R14,[sp,#0*4]           ; should we retry?
        TST     R14,#erf_poll
        BEQ     pollit
        MOV     R1,#0                   ; return 0 and go back to poller
        B       ExitError2              ; stores R1 in top stack entry

finisherror
        Push    "R4"                    ; R4 = 1 or 4 (icon to select)
;
	Debug	upcall, "finishing error ", r4
        MOV     R0,R4                   ; R0 = icon handle
        MOV     R1,#is_inverted         ; R1 = EOR word
        MOV     R2,#is_inverted         ; R2 = BIC word
        BL      int_set_icon_state      ; handle --> window definition
        BL      clearpointerwindow

      [ NCErrorBox
        Push    "r0-r2"
        MOV     R0, #0                  ; Unconditionally turn off IconHigh
        SWI XIconHigh_Stop
	; SJM 25Mar99 Do not restore the pointer shape here
	; anymore now that we have Wimp_Extend support
        Pull    "r0-r2"
      ]
;
        ADR     userblk,errorhandle     ; userblk --> window handle
        BL      int_close_window
        [ ChildWindows
        BL      int_flush_opens         ; this is necessary to avoid block-copying if the error box
        ]                               ; is subsequently displayed at a different size
;
        Pull    "R1"
        TEQ     R1,#4                   ; 1 ==> OK box selected
        MOVEQ   R1,#2                   ; 2 ==> Cancel box selected

        [ NewErrorSystem
        CMP     R1,#6
        BEQ     notoveryet
        SUBHI   R1,R1,#2
        LDRHI   R2,tempworkspace+errtws_iconend
        SUBHI   R1,R2,R1                ; extra icons 7-10 return 6-3
        ]

        [ ErrorServiceCall
        BL      InstallErrorButtonPressedHandlers
        MOV     R2,R1
        MOV     R0,#0
        LDR     R1,=Service_ErrorButtonPressed
        LDR     R3,tempworkspace+errtws_buttonlist
        SWI     XOS_ServiceCall
        BL      RemoveErrorButtonPressedHandlers
        CMP     R0,#0
        BEQ     servicecallend
; module wants error dialog redisplayed
redisplayerrorbox
        LDMIA   R2!,{R4-R7}
        LDMIA   R2,{R1-R2}
        ADR     R3,tempworkspace+errtws_spritearea ; also updates errtws_buttonlist
        STMIA   R3,{R1-R2}
        MOV     userblk,R5
        Push    "PC"                    ; routine returns with Pull "PC"
        B       starterrorbox_draw      ; This actually Pushes PC+12 on the stack
        NOP
        B       pollit
servicecallend
        LDR     R1,=Service_ErrorEnding
        SWI     XOS_ServiceCall
        MOV     R1,R2
        ]

        Debug   upcall,"ReportError returns R1",R1
        STR     R1,[sp,#0*4]

        [ NewErrorSystem
; now replace Quit with Cancel if necessary

        LDR     R1,tempworkspace+errtws_icondata
        TEQ     R1,#0
        BEQ     %FT05
        LDR     R6,tempworkspace+errtws_cancelstr
        STR     R6,[R1,#i_data+i_size*4]
        MOV     R1,#0
        STR     R1,tempworkspace+errtws_icondata
      [ true
        LDR     R0, progerrsaveblk + 4*1 ; retrieve flags
        TEQ     R2, #2                  ; was quit pressed, as opposed to continue?
        ANDNE   R1, R0, #erf_ocontcode
        MOVNE   R1, R1, LSR #erf_ocontcode_shift
        ANDEQ   R1, R0, #erf_ocancelcode
        MOVEQ   R1, R1, LSR #erf_ocancelcode_shift
        TSTEQ   R0, #erf_cancelbox      ; If quit clicked, but underlying window had no cancel
        TEQEQ   R1, #0                  ; and no return code has been specified either,
        MOVEQ   R1, #99                 ; flag that we'll have to call the exit handler.
        TEQ     R1, #0                  ; Otherwise, no return code means we have to pass 1 or 2 as appropriate
        MOVEQ   R1, R2                  ; for compatibility reasons.
        STR     R1, [sp]
      |
        TEQ     R2,#2                   ; was quit pressed ?
        BNE     %FT05
        LDR     R1,progerrsaveblk + 4*1
        TST     R1,#erf_cancelbox
        BNE     %FT05                   ; it asked for a cancel button, assume it will quit anyway
        MOV     R1,#99                  ; flag that control should be passed to exit handler instead
        STR     R1,[SP]
      ]
05
        ]

;
; tidy up afterwards
;
tidyupaftererror
        BL      losewindowrects         ; just in case - don't lose memory!

        ADR     R6,errorstack-14*4      ; this is where we put it previously
        LDMIA   R6!,{R1}                ; Get old VDU status

        Debug   err,"VDU status restored",R1

        TST     R1, #&80                ; Was screen disabled by VDU 21?
        SWINE   XOS_WriteI+21           ; Yes then disable it

        LDMIA   R6!,{R1}                ; Get FX3 state

        Debug   err,"FX3 status restored",R1

        MOV     R0,#3
        SWI     XOS_Byte                ; Restore it

        LDMIA   R6!,{R0,R1}             ; Get redirection handles

        Debug   err,"Redirection handles restored",R0,R1

        SWI     XOS_ChangeRedirection   ; Restore redirection

        LDMIA   R6!,{R0-R1,R2-R5}
        STR     R0,redrawhandle
        STR     R1,rlinks+windowrects
        ADR     R14,clipx0              ; restore clip window too!
        STMIA   R14,{R2-R5}

        LDMIA   r6,{R0-R3}
        SWI     XOS_SpriteOp            ; send output back to original
;
        MOV     R0,#124                 ; acknowledge escape (just in case)
        SWI     XOS_Byte
;
        LDR     R14,commandflag         ; finally un-suspend the window
        BIC     R14,R14,#cf_suspended
        STR     R14,commandflag

        [       outlinefont
        ;Restore the current font and font colours that were in force on
        ;       entry, if they've been changed. This must be done *before*
        ;        making the service call, so the code in ExitWimp is too late.
        Push    "r0-r3"
        LDR     R0, currentfont
        TEQ     R0, #0
        BEQ     ReportError_restored_font_colours
        LDR     R1, systemfont
        TEQ     R1, R0
        LDRNE   R1, currentbg
        LDRNE   R2, currentfg
        LDRNE   R3, currentoffset
        SWINE   XFont_SetFontColours
        MOV     R0, #0
        STR     R0, currentfont
ReportError_restored_font_colours
        Pull    "r0-r3"
        ]

      [ NCErrorBox
        ADRL    R14, ptrpreserveflag
        MOV     R0, #0
        STR     R0, [R14]               ; move the pointer the next time the error box is opened
      ]

        MOV     R0, #229                ; restore the old escape condition disable state
        LDRB    R1, old_escape
        MOV     R2, #0
        SWI     XOS_Byte

        MOV     R1,#Service_WimpReportError
        MOV     R0,#0                   ; closing down
        STRB    R0,errorbox_open
        SWI     XOS_ServiceCall
;
        LDR     R1,[sp]
        TEQ     R1,#99                  ; QUIT, rather than escape was pressed
        SWIEQ   XOS_Exit

        B       ExitWimp

        [ NewErrorSystem
notoveryet
        LDR     R1,tempworkspace+errtws_icondata
        LDR     R4,tempworkspace+errtws_cancelstr
        STR     R4,[R1,#i_data+i_size*4]
        MOV     R1,#0
        STR     R1,tempworkspace+errtws_icondata
        LDR     R1,tempworkspace+errtws_describebuttons  ; Get back buttons
        STR     R1,tempworkspace+errtws_buttonlist
      [ false
        ADRL    R5, ptrpreserveflag
        MOV     R4, #1
        STR     R4, [R5]                ; note not to move the pointer
      ]
        ADRL    R1,progerrsaveblk
        LDMIA   R1,{R4-R7}
        MOV     userblk,R5
        Push    "PC"                    ; routine returns with Pull "PC"
        B       starterrorbox_draw      ; This actually Pushes PC+12 on the stack
        NOP
        B       pollit

      [ ErrorServiceCall
InstallErrorButtonPressedHandlers
; Install Exit, Error and UpCall_NewApplication handlers for Service_ErrorButtonPressed client
        Entry   "R0-R4"
        ADRL    R4, errorbuttonoldhandlers
        MOV     R0, #ExitHandler
        ADR     R1, ErrorButtonExitHandler
        MOV     R2, R12
        SWI     XOS_ChangeEnvironment
        STMIA   R4!, {R1-R3}
        MOV     R0, #ErrorHandler
        ADR     R1, ErrorButtonErrorHandler
        MOV     R2, R12
        ADRL    R3, watchdogerror ; since errorbox_open is set, this won't be used by "App may have gone wrong"
        SWI     XOS_ChangeEnvironment
        STMIA   R4!, {R1-R3}
        MOV     R0, #UpCallHandler
        ADR     R1, ErrorButtonUpCallHandler
        MOV     R2, R12
        SWI     XOS_ChangeEnvironment
        STMIA   R4!, {R1-R3}
        EXIT

RemoveErrorButtonPressedHandlers
; Remove handlers installed in InstallErrorButtonPressedHandlers
        Entry   "R0-R4"
        ADRL    R4, errorbuttonoldhandlers
        MOV     R0, #ExitHandler
        LDMIA   R4!, {R1-R3}
        SWI     XOS_ChangeEnvironment
        MOV     R0, #ErrorHandler
        LDMIA   R4!, {R1-R3}
        SWI     XOS_ChangeEnvironment
        MOV     R0, #UpCallHandler
        LDMIA   R4!, {R1-R3}
        SWI     XOS_ChangeEnvironment
        EXIT

ErrorButtonErrorHandler
        ; This shouldn't ever be called, but if it is, then the SVC stack has been flattened,
        ; so we can't realistically continue execution afterwards; we also can't use an error
        ; box to display the message, since one is already open. So just print the message,
        ; then drop through the exit handler to tidy up the old error box.
        MOV     R12, R0
        ADRL    R0, watchdogerror + 8 ; skip the PC word and error number
        SWI     XOS_Write0
        SWI     XOS_NewLine
        ; drop through...
ErrorButtonExitHandler
        SWI     XOS_EnterOS     ; we need a stack
        BL      RemoveErrorButtonPressedHandlers
        LDR     R1, =Service_ErrorEnding
        MOV     R2, #2          ; fake a "Cancel" button for the purposes of this service call
        SWI     XOS_ServiceCall
        ; SVC stack has been flattened by OS_Exit, but the rest of the error box code
        ; assumes it can use the word at sp_svc to hold the R1 value to pass back from
        ; Wimp_ReportError. Use the top word of the SVC stack for this purpose instead -
        ; it'll be flattened again when *we* call OS_Exit.
        MOV     R1, #99         ; re-use magic value that causes OS_Exit to be called
        Push    "R1"
        B       tidyupaftererror

ErrorButtonUpCallHandler
        TEQ     R0, #UpCall_NewApplication
        MOVEQ   R0, #0          ; deny new application
        MOV     PC, R14
      ]

	LTORG

        MACRO
$lab    MakeInvisible   $num

        LDR     R14,[handle,#w_icons]
        LDR     R14,[R14,#i_flags+i_size*$num]
        ORR     R14,R14,#is_deleted
        LDR     R0,[handle,#w_icons]
        STR     R14,[R0,#i_flags+i_size*$num]
        MEND

        MACRO
$lab    MakeInvisibleReg   $reg

        Push    "R0,$reg"
        MOV     $reg,$reg , LSL #i_shift
        LDR     R0,[handle,#w_icons]
        ADD     R0,R0,$reg
        LDR     R14,[R0,#i_flags]
        ORR     R14,R14,#is_deleted
        STR     R14,[R0,#i_flags]
        Pull    "R0,$reg"

        MEND

; 16 byte boundaries of sprites to use

errspritetable
                DCB     "error",0,0,0
                DCD     0,0
                DCB     "information",0
                DCD     0
                DCB     "warning",0
                DCD     0,0
                DCB     "program",0
                DCD     0,0
                DCB     "question"
                DCD     0,0
                DCB     "user1",0,0,0
                DCD     0,0
                DCB     "user2",0,0,0
                DCD     0,0
                DCB     "program",0
                DCD     0,0


noprogapp       DCB     "Application",0
errorptoken     DCB     "ErrorP",0
quitlabel       DCB     "Quit",0

        ]

; In    R4-R7 = normal R0-R3 for Wimp_ReportError
;       R8 = relative handle of error window
; Out   [..errorstack] = (10 words) = stashed data
;                        original SwitchOutputToSprite values, clip window etc.

starterrorbox
        Push    "LR"

; copy error message (because messagetrans is unhelpful)
        ADRL    R0,watchdogerror
        TEQ     R0,R4                       ; is this coming from us?
        BEQ     %FT05

        ADD     R0,R4,#4
        BL      count0
        CMP     R1,#237
        BCS     %FT05
        MOV     R0,R4
        ADRL    R4,copyerror
        MOV     R1,R4
        LDR     LR,[R0],#4
        STR     LR,[R1],#4
        BL      copy0
05
        [ NewErrorSystem

; bit 31 is reserved, used internally

        BIC     R5,R5,#erf_describe
        BIC     userblk,userblk,#erf_describe

        MOV     R1,#0
        STR     R1,tempworkspace+errtws_icondata  ; make sure no label swapping

; is the error box already up? Don't need to save VDU info.

        LDRB    R1,errorbox_open
        CMP     R1,#1
        BEQ     starterrorbox_reenter

; check to see if this is a program error, if so use the watchdog area
; to create a temporary error block. and try not to use the stack!!!

        [ Bits30and23
        LDR     R0,=&C0800000                 ; bit 31 + bit 30 + bit 23
        LDR     R1,[R4]
        AND     R1,R1,R0
        TEQ     R1,#&80000000                   ; DA, AE etc.
        EOR     R0,R0,#&80000000
        TEQNE   R1,R0                           ; pgm error  (new)
        |
        LDR     R1,[R4]

        AND     R1,R1,#&80000000
        TEQ     R1,#&80000000
        BLNE    IsThisProgErr
        ]

        BNE     starterror_next
        ADRL    R1,progerrsaveblk
        STMIA   R1,{R4-R7}
        MOV     R1,#&07000000
        STR     R1,watchdogerror
        LDR     R1,errorhandle
        Abs     R1,R1                   ; real windows are Rel-ative
        LDR     R1,[R1,#w_icons]
        LDR     R2,[R1,#i_data+i_size*4]        ; cancel button
        STR     R2,tempworkspace+errtws_cancelstr
        STR     R1,tempworkspace+errtws_icondata  ; make life easier later
        ADR     R0,quitlabel            ; SMC: now lookup text for button
        ADRL    R2,quittext
        MOV     R3,#buttontextsize
        BL      LookupToken
        STR     R2,[R1,#i_data+i_size*4]
        MOVS    R4,R6
        CMPNE   R4,#nullptr
        ADREQ   R4,noprogapp
        LDRB    R14,[R4]
        TEQ     R14,#"\\"
        ADDEQ   R4,R4,#1
        ADRL    R2,watchdogerrtxt
        MOV     R3,#?watchdogerrtxt
        ADR     R0,errorptoken
        BL      LookupToken
        ADRL    R4,watchdogerror
        LDR     R1,tempworkspace+errtws_buttonlist        ; store buttons away
        STR     R1,tempworkspace+errtws_describebuttons   ; in case we need them again
                                                          ; when user hits describe
        TST     R5,#erf_newtype
      [ true
        LDR     R5,=erf_describe:OR:erf_cancelbox:OR:erf_okbox
      |
        MOV     R5,#erf_describe:OR:erf_cancelbox:OR:erf_okbox
      ]
        ORR     R5,R5,#erf_newtype                        ; continue rather than ok
        MOV     userblk,R5
        MOV     R6,#0
        MOVEQ   R7,#0                                     ; make sure no sprite if original error wasn't new type
        STREQ   R6,tempworkspace+errtws_spritearea
        STR     R6,tempworkspace+errtws_buttonlist        ; no custom buttons
        LDR     R6,progerrsaveblk + 4*2                   ; app name

starterror_next
        ]

        MOV     R1,#Service_WimpReportError
        MOV     R0,#1                   ; starting up
        STRB    R0,errorbox_open
        SWI     XOS_ServiceCall

        CLRV                                    ; just in case
        MOV     R0,#SpriteReason_SwitchOutputToSprite
        MOV     R1,#0
        MOV     R2,#0                   ; Switch to screen
        ADRL    R14,save_context
        LDR     R3,[R14]
        SWI     XOS_SpriteOp
        BVC     %FT05
;        B       %FT05

        ; if we get an error here, then its potentially quite serious...
        CLRV                            ; chances are it will happen again
        ADD     SP,SP,#4
        MOV     R1,#2
        STR     R1,[sp]                 ; cancel

        [       outlinefont
        ;Restore the current font and font colours that were in force on
        ;       entry, if they've been changed. This must be done *before*
        ;       making the service call, so the code in ExitWimp is too late.
        Push    "r0-r3"
        LDR     R0, currentfont
        TEQ     R0, #0
        BEQ     ReportError_restored_font_colours2
        LDR     R1, systemfont
        TEQ     R1, R0
        LDRNE   R1, currentbg
        LDRNE   R2, currentfg
        LDRNE   R3, currentoffset
        SWINE   XFont_SetFontColours
        MOV     R0, #0
        STR     R0, currentfont
ReportError_restored_font_colours2
        Pull    "r0-r3"
        ]

        MOV     R1,#Service_WimpReportError
        MOV     R0,#0                   ; closing down
        STRB    R0,errorbox_open
        SWI     XOS_ServiceCall

        B       ExitWimp

05

        ADR     R14,errorstack          ; FD stack
        STMDB   R14!,{R0-R3}            ; remember for later

        ADR     R0,clipx0               ; remember current clip rectangle
        LDMIA   R0,{R0-R3}
        STMDB   R14!,{R0-R3}

        LDR     R0,redrawhandle
        LDR     R1,rlinks+windowrects   ; NB requires YUK=false to work
        STMDB   R14!,{R0,R1}

; Restore normal VDU output

        MOV     R3, R14                 ; R3 = error stack

        MOV     R0,#0
        MOV     R1,#0
        SWI     XOS_ChangeRedirection   ; Disable all redirection
        STMDB   R3!,{R0,R1}             ; Save old handles

        Debug   err,"Redirected i/p, o/p handles",R0,R1

        MOV     R0,#3
        MOV     R1,#&14                 ; Enable VDU, disable Spool, printer & serial
        SWI     XOS_Byte
        STMDB   R3!,{R1}                ; Save for later

        Debug   err,"OS_Byte 3 status was",R1

        MOV     R2, #0
        MOV     R1, #0
        MOV     R0, #218
        SWI     XOS_Byte                ; Flush VDU queue

        MOV     R0,#117
        SWI     XOS_Byte                ; Read VDU status
        STMDB   R3!,{R1}                ; Save for later

        Debug   err,"VDU status is",R1

        TST     R1, #&80                ; Screen disabled by VDU 21?
        SWINE   XOS_WriteI+6            ; Yes then re-enable it with VDU 6

        LDRB    R14,sysflags            ; beep unless suppressed by user
        TST     R14,#sysflags_nobeep
        TSTEQ   R5,#erf_nobeep          ; can be suppressed in the call
        SWIEQ   XOS_WriteI+7
;
; now set up temporary state for drawing the error box
;

        STR     R8,redrawhandle
starterrorbox_reenter
        MOV     R14,#nullptr
        STR     R14,rlinks+windowrects  ; pretend there aren't any!
;

starterrorbox_draw

	Debug	err,"starterrorbox_draw"

        STR     R5, tempworkspace+errtws_flags ; for later use by pollit
        Push    "R4-R7"
      [ NewErrorSystem
; make sure we have default pointer
        MOV     R0,#SpriteReason_SetPointerShape
        ADRL    R2,ptr_default2
      [ NCErrorBox
        MOV     R3,#&41                 ; reprogram shape data, but don't switch to shape 1 yet
      |
        MOV     R3,#1
      ]
        MOV     R4,#0
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0
        SWI     XWimp_SpriteOp          ; take from Wimp's sprite area(s)
      ]

        BL      set16x32chars
        Pull    "R0-R3"                 ; R0-R3 = original registers
;
        Push    "R0"                    ; R0 --> error block
;
; construct title string (depends on R1 bit 4 and R2)
;
        Push    "R2-R5"
;
        AcceptLoosePointer_NegOrZero R2,0
        CMP     R2,R2,ASR #31           ; do they want an application name?
        ADREQL  R0,errorprefix1
        BICEQ   R1,R1,#erf_omiterror
        ADRNEL  R0,errorprefix2         ; -> suitable token

        TST     R1,#erf_omiterror
        ADRNEL  R0,errorprefix          ; include prefixing message?

        MOV     R5,#0
        MOVS    R4,R2                   ; parameter for the title string
        CMPNE   R4,#nullptr
        BEQ     %FT01
        LDRB    R14,[R4]
        TEQ     R14,#"\\"
        ADDEQ   R4,R4,#1
01
;
        MOV     R3,#?errortitle
        ADRL    R2,errortitle           ; -> title string for dialogue box
        BL      LookupToken
;
        ADRL    R2,errortitle
;
	DebugS	err,"errortitle=",R2

        Pull    "R2-R5"

        [ NewErrorSystem

; set up sprites in dialogue box

        MOV     R0,userblk
        AND     R0,R0,#erf_errortype
        addr    R14,errspritetable
        TST     userblk,#erf_newtype
        ADDNE   R0,R14,R0 , LSR #erb_errortype-4
        MOVEQ   R0,R14
        TST     userblk,#erf_describe
        ADDNE   R0,R0,#48               ; program symbol

; R14 now points to error type sprite name <= 12 chars
        LDR     R14,[handle,#w_icons]
        ADD     R14,R14,#i_data+i_size*3
        Push    "R1,R2"
        LDMIA   R0,{R0-R2}
        STMIA   R14,{R0-R2}                     ; copy name
        Pull    "R1,R2"

        ; set up app sprite
        MOV     R0,#1
        STR     R0,[handle,#w_areaCBptr]
        TST     userblk,#erf_newtype
        BEQ     oldappsprite
        AcceptLoosePointer_NegOrZero R3,0
        CMP     R3,R3,ASR #31

        LDREQ   R14,[handle,#w_icons]
        ADDEQ   R14,R14,#i_size
; make sure default says 'OK'
        ADREQ   R0,contlabel
        Push    "R2",EQ                         ; SMC: now lookup text for button but leave it to oldappsprite2 (must preserve R2)
        ADREQL  R2,conttext
        BEQ     oldappsprite2

        LDR     R2,tempworkspace+errtws_spritearea
        CMP     R2,#1
        STRHI   R2,[handle,#w_areaCBptr]
        MOV     R2,R3                           ; sprite given so use it
        LDR     R14,[handle,#w_icons]
        ADD     R14,R14,#i_size
; make sure default says 'Continue'
        ADR     R0,contlabel

        Push    "R2,R3,R14"                     ; SMC: now lookup text for button (made complicated by preserving regs)
        ADRL    R2,conttext
        MOV     R3,#buttontextsize
        BL      LookupToken
        LDR     R14,[SP,#8]
        STR     R2,[R14,#i_data]
        Pull    "R2,R3,R14"
;
        ADD     R14,R14,#i_data+i_size
        Push    "R1,R2"
        MOV     R1,#11
        B       oldapploop

oklabel
 [ :LNOT: STB
                DCB     "OK",0,0
 ]
contlabel       DCB     "Continue",0
noappname       DCB     "switcher",0
              [ true
ptr_default2    DCB     "ptr_default",0
              ]
                ALIGN

oldappsprite
        LDR     R14,[handle,#w_icons]
        ADD     R14,R14,#i_size
; make sure default says 'OK'
        ADR     R0,oklabel
        Push    "R2"                            ; SMC: now lookup text for button
        ADRL    R2,oktext
oldappsprite2
        Push    "R3,R14"                        ; SMC: must preserve registers over sub-routine call
        MOV     R3,#buttontextsize
        BL      LookupToken
        Pull    "R3,R14"
        STR     R2,[R14,#i_data]
        Pull    "R2"

        ADD     R14,R14,#i_data+i_size
        Push    "R1,R2"
        CMP     R2,R2,ASR #31
        ADREQ   R2,noappname
        MOVEQ   R1,#11
        BEQ     oldapploop
; is [R2] <= a space ?

        LDRB    R0,[R2]
        CMP     R0,#" "
        ADRLS   R2,noappname
        MOVLS   R1,#11
        BLS     oldapploop

; copy !<R2> to sprite name
        MOV     R0,#"!"
        STRB    R0,[R14],#1
        MOV     R1,#10
oldapploop
        LDRB    R0,[R2],#1
        STRB    R0,[R14],#1
        SUBS    R1,R1,#1
        BNE     oldapploop
; R1 now zero
        STRB    R1,[R14]                ; make sure its terminated
        SUB     R2,R14,#11              ; get R2 back to name that is actually used
; R2 should have a valid sprite, does it exist?
        LDR     R1,[handle,#w_areaCBptr]
      [ SpritePriority
        Push    "R2"
        CMP     R1, #1                  ; try any user area before either Wimp area
        SETPSR  V_bit, R0, EQ           ; SETV will *not* do, it corrupts Z
        MOVNE   R0, #256+SpriteReason_SelectSprite ; attempt to select sprite
        SWINE   XOS_SpriteOp
        MOVVS   R0, #256+SpriteReason_SelectSprite
        LDRVS   R1, baseofhisprites
        LDRVS   R2, [SP]
        SWIVS   XOS_SpriteOp            ; not there? try again within high-priority area
        MOVVS   R0, #256+24
        LDRVS   R1, baseoflosprites
        LDRVS   R2, [SP]
        SWIVS   XOS_SpriteOp            ; not there? try again within low-priority area
        Pull    "R2"                    ; sprite op can stuff R2
      |
        CMP     R1,#1
        LDREQ   R1,baseofsprites
        MOV     R0,#SpriteReason_SelectSprite+256 ; attempt to select sprite
        Push    "R2"
        SWI     XOS_SpriteOp
        LDRVS   R1,baseofromsprites
        MOVVS   R0,#256+SpriteReason_SelectSprite ; would have been done by the error!
        LDRVS   R2,[SP]
        SWIVS   XOS_SpriteOp            ; not there? try again within the ROM
        Pull    "R2"                    ; sprite op can stuff R2
      ]
        LDRVS   R0,[R2,#-8]             ; icon's ymax
        LDRVC   R0,[R2,#-16]            ; ymin
        SUBVC   R0,R0,#60               ; gap
        STR     R0,[R2,#+i_size-8]      ; icon 3's ymax
        Pull    "R1,R2"
doneappsprite

	Debug	err,"doneappsprite"
        MOV     R0,#-1
        Push    "R0"
; we use the stack to keep track of displayed icons

;
; put appropriate OK / Cancel box(es) into error window
;

        LDR     R14,tempworkspace+errtws_buttonlist
        TST     userblk,#erf_newtype
        AcceptLoosePointer_NegOrZero R14,0,NE,R0
        CMPNE   R14,R14,ASR #31
        BNE     %FT10

        TST     userblk,#erf_okbox:OR:erf_cancelbox
        ORREQ   userblk,userblk,#erf_okbox      ; ensure there is at least an OK
;
10
        TST     userblk,#erf_okbox
        MOV     R0,#1                   ; this is icon 1
        Push    "R0",NE                 ; displayed
        LDR     R0,[handle,#w_icons]
        LDR     R14,[R0,#i_flags+i_size*1]
        ORR     R14,R14,#is_deleted     ; will be undeleted later if necessary
        STR     R14,[R0,#i_flags+i_size*1]
;

        TST     userblk,#erf_cancelbox
        MOV     R0,#4                   ; this is icon 4
        Push    "R0",NE                 ; is displayed
        LDR     R0,[handle,#w_icons]
        LDR     R14,[R0,#i_flags+i_size*4]
        ORR     R14,R14,#is_deleted     ; will be undeleted later if necessary
        STR     R14,[R0,#i_flags+i_size*4]

        AND     R0, userblk, #erf_okbox :OR: erf_cancelbox :OR: erf_htcancel
        TEQ     R0, #erf_okbox :OR: erf_cancelbox :OR: erf_htcancel
; in this case, we must swap over the position of the OK/Cancel buttons to reflect the effect of keypresses
        MOVEQ   R0, #1
        STREQ   R0, [sp]
        MOVEQ   R0, #4
        STREQ   R0, [sp, #4]

        TST     userblk,#erf_describe
        MOV     R0,#6                   ; this is icon 6
        Push    "R0",NE                 ; is displayed
        LDR     R0,[handle,#w_icons]
        LDR     R14,[R0,#i_flags+i_size*6]
        ORR     R14,R14,#is_deleted     ; will be undeleted later if necessary
        STR     R14,[R0,#i_flags+i_size*6]


; now do dynamic icons 7,8,9,10

        LDR     R2,tempworkspace+errtws_buttonlist
        AcceptLoosePointer_NegOrZero R2,0
        CMP     R2,R2,ASR #31
        MOVEQ   R3,#7
        BEQ     markinvisibleicons

        TST     userblk,#erf_newtype
        MOVEQ   R3,#7
        BEQ     markinvisibleicons

; these are indirected captain. Can't splurge the data as it may come from ROM!
; need to copy it somewhere safe.

        MOV     R0,#-1
        Push    "R0"
        MOV     R14,#0
        ADRL    R3,errorbuttons
        MOV     R1,#errorbuttonsize
        MOV     R4,#maxno_error_buttons   ; this is the maximum number of additional buttons we can have
        Push    "R3"                      ; the first button is always at the start of the string
setupdynamicsloop
        SUBS    R1,R1,#1                  ; run out of buffer space? (one byte required for terminator)
        LDRNEB  R0,[R2],#1                ; get character from source
        TSTNE   R0,#224                   ; is it a control character?
        STREQB  R14,[R3]                  ; null-terminate the copy and finish
        BEQ     %FT06
        CMP     R0,#","                   ; is it a comma?
        STRNEB  R0,[R3],#1                ; no:  copy character and loop
        BNE     setupdynamicsloop
        STRB    R14,[R3],#1               ; yes: copy a NULL
        SUBS    R4,R4,#1                  ;      decrement buttons counter
        Push    "R3",NE                   ;      unless we've got all the buttons we can, push the button address and loop
        BNE     setupdynamicsloop
06
        [ debugerr
        Push    "R0-R8"
        ADD     R0, sp, #9*4
        LDMIA   R0,{R0-R8}
        Debug   err, "setupdynamicsloop: stack contains",R0,R1,R2,R3,R4,R5,R6,R7,R8
        Pull    "R0-R8"
        ]

; stack now holds pointers to button labels

        MOV     R3,#7
        LDR     R1,[handle,#w_icons]
        Pull    "R0"
setupiconsloop
        ADD     R2,R1,R3, LSL #i_shift  ; R2-> icon
        STR     R0,[R2,#i_data]
        Pull    "R0"
        ADD     R3,R3,#1
        CMP     R0,#-1
        BNE     setupiconsloop
        STR     R3,tempworkspace+errtws_iconend  ; number of extra buttons (+7)

        [ debugerr
        Push    "R0-R8"
        ADD     R0, sp, #9*4
        LDMIA   R0,{R0-R8}
        Debug   err, "setupiconsloop: stack contains",R0,R1,R2,R3,R4,R5,R6,R7,R8
        Pull    "R0-R8"
        ]

; now set what needs to be displayed and aligned

        SUB     R2,R3,#1
displayiconsloop
        Push    "R2"
        SUB     R2,R2,#1
        CMP     R2,#6
        BNE     displayiconsloop


markinvisibleicons
        MOV     R2,#-1
        Push    "R2"
; stack now contains list, eg:    (-1, 7, 8, 9, 10, 6, 4, 1, -1)
; if number >maxno_error_buttons, we must make some invisible, then position the rest

; unused icons need to be made invisible
markinvisloop
        CMP     R3,#7+maxno_error_buttons-1
        BHI     markinvend
        MakeInvisibleReg   R3
        ADD     R3,R3,#1
        CMP     R3,#7+maxno_error_buttons
        BLO     markinvisloop
markinvend

; count icons on stack
        ADD     R2,sp,#4                ; jump -1
        MOV     R0,#0
countstackicons
        LDR     R1,[R2],#4
        CMP     R1,#-1
        ADDNE   R0,R0,#1
        BNE     countstackicons

        CMP     R0,#maxno_error_buttons+1
        BLO     alignicons
        Pull    "R1"
        SUB     R0,R0,#maxno_error_buttons
marktoomanyicons
        Pull    "R1"
        MakeInvisibleReg  R1
        SUBS    R0,R0,#1
        BNE     marktoomanyicons
        MOV     R0,#-1
        Push    "R0"

alignicons

	Debug	err,"alignicons"

; stack now has at most maxno_error_buttons icons, R2-8 -> icon to appear on far right.

        SUB     R2,R2,#8
        LDR     R0,[handle,#w_wex1]     ; R0 is max x coord, use as running right posn
        SUB     R0,R0,#20               ; 20 OS unit border
        LDR     R1,[R2],#-4
        LDR     R14,[handle,#w_icons]

; the first icon is always a default (aka "highlighted") one
        ADD     R3, R14, R1, LSL #i_shift       ; R3 -> first icon
        LDR     R4, errbut_y0_def
        STR     R4, [R3, #i_bby0]
        LDR     R4, errbut_y1_def
        STR     R4, [R3, #i_bby1]
        LDR     R4, errbut_fl_def
        STR     R4, [R3, #i_flags]
        LDR     R4, errbut_va_def
        STR     R4, [R3, #i_data + 4]
        LDR     R4, errbut_w_def
        B       alignanddisplayicon

alignnexticon
        ADD     R3, R14, R1, LSL #i_shift       ; R3 -> icon
        LDR     R4, errbut_y0
        STR     R4, [R3, #i_bby0]
        LDR     R4, errbut_y1
        STR     R4, [R3, #i_bby1]
        LDR     R4, errbut_fl
        STR     R4, [R3, #i_flags]
        LDR     R4, errbut_va
        STR     R4, [R3, #i_data + 4]
        LDR     R4, errbut_w

alignanddisplayicon
; R1 is icon number, R14 is icon base, R0 is rhs of icon, R4 is minimum width

      [ StretchErrorButtons
        Push    "R0,R1,R2,R4,R14"
        LDR     R1,[R3,#i_flags]
	ADD	R2,R3,#i_data
	BL	seticonptrs
	LDR	R2,[R3,#i_data]
	Debug	err,">textwidth"
        BL      textwidth
	Debug	err,"<textwidth"
        ADD     R5,R4,#36                       ; allow 18 OS-units each side, in case it's a default button
        Pull    "R0,R1,R2,R4,R14"
        max     R4,R5
      ]
        MOV     R5,R0
        SUB     R0,R0,R4
        SUB     R0,R0,#20                       ; gap between buttons
        SUB     R4,R5,R4
        STR     R4,[R3,#i_bbx0]
        STR     R5,[R3,#i_bbx1]
        LDR     R1,[R2],#-4
        CMP     R1,#-1
        BNE     alignnexticon

        ADD     SP,SP,#4                        ; skip -1
clearstack
        Pull    "R1"
        CMP     R1,#-1
        BNE     clearstack

; now resize window if necessary, by moving lhs.

        CMP     R0,#0
        MOVGT   R0,#0                           ; this is the work area x0 required by the buttons

        LDR     R14, [handle, #w_icons]
        LDR     R1, errmess_x0
        ADD     R2, R14, #i_size * 0            ; R2 -> text icon definition
        ADD     R3, R0, R1                      ; stretch text icon to fit window
        STR     R3, [R2, #i_bbx0]

      [ StretchErrorText
        LDR     R0, [sp]                        ; get error block pointer
        ADD     R0, R0, #4
        STR     R0, [R2, #i_data + 0]           ; set up text pointer now, we need it to calculate the icon width

        Push    "R1-R6, R10, R14"
06
        MOV     R1, #-1
        STR     R1, linecount                   ; activate line counting
        LDR     R2, [sp, #1*4]                  ; R2 -> text icon definition
        LDMIA   R2, {x0, y0, x1, y1}            ;\.
        LDR     R1, [R2, #i_flags]              ; |
        LDR     R2, [R2, #i_data + 0]           ; | set up registers for line count
      [ outlinefont                             ; |
        LDR     R3, systemfont                  ;/
        TEQ     R3, #0
        ADREQL  R14, iconformatted_system
        ADRNEL  R14, iconformatted_fancy
      |
        ADRL    R14, iconformatted_system
      ]
        Push    "PC"                            ; PC+12 is actually stored
        MOV     PC, R14                         ; branch to appropriate routine - returns using Pull "PC"
        NOP

        LDR     R0, linecount
        Debug   err, "Error message icon line count =", R0
        CMP     R0, #errmess_maxlines
        BLE     %FT01                           ; satisfactory number of lines, we don't need to stretch any further
        LDR     R2, [sp, #1*4]                  ; R2 -> text icon definition
        LDR     R3, [R2, #i_bbx0]
        SUB     R3, R3, #errmess_increment      ; enlarge window by one step
        STR     R3, [R2, #i_bbx0]
        B       %BT06
01
        Pull    "R1-R6, R10, R14"

        LDR     R3, [R2, #i_bbx0]
        SUB     R0, R3, R1                      ; stretch window to fit icon

        MOV     R1, #0
        STR     R1, linecount                   ; deactivate line counting
      ]

        STR     R0,[handle,#w_wex0]
        LDR     R1,[handle,#w_wex1]
        STR     R0,[handle,#w_wax0]             ; horizontal centring dealt with later
        STR     R1,[handle,#w_wax1]             ; but the visible width *must* match the horizontal work area extent width

        ADD     R2, R14, #i_size * 2            ; move app sprite
        LDR     R3, [R2, #i_bbx0]
        LDR     R4, [R2, #i_bbx1]
        SUB     R4, R4, R3                      ; R4 = old width
        LDR     R3, errapp_x0
        ADD     R3, R3, R0                      ; make relative to new window edge
        ADD     R4, R4, R3
        STR     R3, [R2, #i_bbx0]
        STR     R4, [R2, #i_bbx1]

        ADD     R2, R14, #i_size * 3            ; move type sprite
        LDR     R3, [R2, #i_bbx0]
        LDR     R4, [R2, #i_bbx1]
        SUB     R4, R4, R3                      ; R4 = old width
        LDR     R3, errtype_x0
        ADD     R3, R3, R0                      ; make relative to new window edge
        ADD     R4, R4, R3
        STR     R3, [R2, #i_bbx0]
        STR     R4, [R2, #i_bbx1]

        ADD     R2, R14, #i_size * 5            ; stretch divider sprite
        STR     R0, [R2, #i_bbx0]
        STR     R1, [R2, #i_bbx1]

      [ NCErrorBox
        ADD     R2, R14, #i_size * 15           ; move left border
        STR     R0, [R2, #i_bbx0]
        ADD     R4, R0, #8                      ; magic number: width of vertical borders
        STR     R4, [R2, #i_bbx1]

        ADD     R2, R14, #i_size * 17           ; stretch top border
        STR     R0, [R2, #i_bbx0]

        ADD     R2, R14, #i_size * 18           ; stretch bottom border
        STR     R0, [R2, #i_bbx0]
      ]

; and we're done!!
        |
;
; put appropriate OK / Cancel box(es) into error window
;
        TST     userblk,#erf_okbox:OR:erf_cancelbox  ; 0 ==> just OK box
        MOVEQ   userblk,#erf_okbox
        TST     userblk,#erf_okbox
        ORREQ   userblk,userblk,#erf_htcancel   ; highlight one of them
;
        TST     userblk,#erf_okbox
        LDR     R14,[handle,#w_icons]
        LDR     R14,[R14,#i_flags+i_size*1]
        BIC     R14,R14,#is_inverted    ; ensure not inverted initially
        ORREQ   R14,R14,#is_deleted
        BICNE   R14,R14,#is_deleted
        TST     userblk,#erf_htcancel
        LDRNE   R0,unhighlighted_colour ; values read from icons initially
        LDREQ   R0,highlighted_colour   ; values read from icons initially
        BIC     R14,R14,#if_bcol:OR:if_fcol
        ORR     R14,R14,R0
        LDR     R0,[handle,#w_icons]
        STR     R14,[R0,#i_flags+i_size*1]
;
        TST     userblk,#erf_cancelbox
        LDR     R14,[handle,#w_icons]
        LDR     R14,[R14,#i_flags+i_size*4]
        BIC     R14,R14,#is_inverted    ; ensure not inverted initially
        ORREQ   R14,R14,#is_deleted
        BICNE   R14,R14,#is_deleted
        TST     userblk,#erf_htcancel
        LDREQ   R0,unhighlighted_colour ; values read from icons initially
        LDRNE   R0,highlighted_colour   ; values read from icons initially
        BIC     R14,R14,#if_bcol:OR:if_fcol
        ORR     R14,R14,R0
        LDR     R3,[handle,#w_icons]
        STR     R14,[R3,#i_flags+i_size*4]
        LDR     R2,[R3,#i_bbx0+i_size*0]
        LDR     R3,[R3,#i_bbx1+i_size*0]
        SUB     R3,R3,R2
        AND     R14,userblk,#erf_okbox:OR:erf_cancelbox
        CMP     R14,#2                  ; poss. values are 1,2,3 (L,R,BOTH)
        LDRNE   R1,[handle,#w_icons]
        ADDNE   R1,R1,#i_size*1
        ADDHI   R2,R2,R3,ASR #2         ; add 1/4 of width if both present
        ADDLO   R2,R2,R3,ASR #1         ; add 1/2 of width if 'OK' only
        BLNE    setbuttonx              ; R1-->icon,R2=centre x-coord
        ADDHS   R2,R2,R3,ASR #1         ; add 1/2 of width -> Cancel
        LDRHS   R1,[handle,#w_icons]
        ADDHS   R1,R1,#i_size*4
        BLHS    setbuttonx              ; R1-->icon,R2=centre x-coord
        ]

;
; work out window coords (use coords in template)
;
        ADD     R1,handle,#w_wax0
        ASSERT  cx0=R2

	Debug	err, "working out window coords"
;
        Push    "R1"                    ; centre the dialogue
        LDMIA   R1,{cx0,cy0,cx1,cy1}
        SUB     cx1,cx1,cx0
        SUB     cy1,cy1,cy0

        MOV     R0,#-1
        MOV     R1,#VduExt_YWindLimit
        SWI     XOS_ReadModeVariable
        MOV     y0,R2                   ; screen height in pixels
        MOV     R1,#VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        MOV     y0,y0,ASL R2
        MOV     y0,y0,LSR #1            ; half screen height in OS units

        SUB     cy0,y0,cy1,LSR #1       ; - half the box height
        ADD     cy1,cy1,cy0             ; + box height

        MOV     R1,#VduExt_XWindLimit
        SWI     XOS_ReadModeVariable
        MOV     x0,r2                   ; screen width in pixels
        MOV     R1,#VduExt_XEigFactor
        SWI     XOS_ReadModeVariable
        MOV     x0,x0,ASL r2
        MOV     x0,x0,LSR #1            ; half screen width in OS units

        SUB     cx0,x0,cx1,LSR #1
        ADD     cx1,cx1,cx0             ; - half box width + box width

        Pull    "R1"
        LDR     x0,[R1,#16]
        LDR     y0,[R1,#20]
        LDR     x1,[R1,#24]
;
; construct window block on stack, for use in OpenWindow etc.
;
        LDR     R14,[sp,#0*4]           ; get error block pointer
        ADD     R14,R14,#4
        LDR     R0,[handle,#w_icons]
        STR     R14,[R0,#0*i_size+i_data+0]
;
        ASSERT  cx0=R2
        LDR     R0,errorhandle
        Push    "R0,cx0,cy0,cx1,cy1,x0,y0,x1,R9-R12" ; 12 words needed on stack
        MOV     userblk,sp
	Debug	err,"int_open_window"
        BL      int_open_window
        [ ChildWindows
        BLVC    int_flush_opens         ; this is necessary to set the rectangles lists correctly
        ]
;
        BLVC    visibleouterportion     ; handle --> window definition already
        BLVC    int_redraw_window
        BVS     donegetr
getrlp
        TEQ     R0,#0
        BEQ     donegetr
        BL      int_get_rectangle
        BVC     getrlp

donegetr
        SWI     XHourglass_Smash        ; turn off hourglass (if displayed)
                                        ; ignore errors
        ADD     R14,handle,#w_x0        ; confine pointer to error box
        LDMIA   R14,{x0,y0,x1,y1}
        BL      pointerwindow
;
        MOV     R0, #ScreenBlankerReason_Unblank
        SWI     XScreenBlanker_Control  ; unblank screen (if blanked)
;
        BL      flushkbdmouse           ; get ready to read these
;
      [ NCErrorBox
        ADRL    R0, ptrpreserveflag
        LDR     R0, [R0]
        TEQ     R0, #0                  ; Should we move the pointer over the default action button?
        BNE     %FT01

        Push    "cx0-y0"
        LDR     R14, errorhandle
        Abs     R14, R14

        LDR     cx0, [R14, #w_wax1]
        SUB     cx0, cx0, #20           ; 20 OS unit border
        LDR     cx1, errbut_w_def
        SUB     cx0, cx0, cx1, ASR #1   ; screen x of icon centre

        LDR     cy1, [R14, #w_way1]
        LDR     y0, [R14, #w_scy]
        SUB     y0, cy1, y0             ; screen y of wao
        LDR     cy0, errbut_y0_def
        LDR     cy1, errbut_y1_def
        ADD     cy0, cy0, cy1
        ADD     cy0, y0, cy0, ASR #1    ; screen y of icon centre

        SUB     sp, sp, #8
        MOV     R1, sp
        MOV     R0, #3
        STRB    R0, [R1]
        strw    cx0, R1, 1
        strw    cy0, R1, 3
        MOV     R0, #&15
        SWI     XOS_Word                ; Set mouse position
        ADD     sp, sp, #8

        ADRL    R0, ptrsuspendflag      ; Update our copy of the coords
        LDR     R1, [R0]                ; because IconHigh reads the mouse
        TEQ     R1, #2                  ; position using Wimp_GetPointerInfo!
        MOVEQ   R1, #1                  ; If pointer is currently hidden
        STREQ   R1, [R0]                ; until the next mouse move, remember
        BL      getmouseposn            ; to discount next mouse read.
        Pull    "cx0-y0"

01      MOV     R0, #106
        MOV     R1, #0
        SWI     XOS_Byte                ; Read current pointer number (also turns it off, but we'll soon switch it back)
        ADRL    R14, ptrshlflag
        STR     R1, [R14]               ; Store old pointer shape
        MOV     R0, #2
        SWI     XIconHigh_Start         ; Unconditionally start single-tasking IconHigh
        ADRL    R14, ptrshlflag
        MOV     R0, #106
        LDR     R1, [R14]               ; Restore pointer to the way it was after Hourglass_Smash
        SWI     XOS_Byte                ; (also undoes any unwelcome changes due to IconHigh_Start)
      ]

        ADD     sp,sp,#13*4             ; forget open block / error pointer
        Pull    "PC"

        [ NewErrorSystem
errwatchdogguard   DCD     &E240569E


 LTORG
        [ :LNOT: Bits30and23

IsThisProgErr
; returns EQ is proram error, R4-> error number
        Push    "R0-R2,lr"
        LDR     R2,[R4]
        AND     R0,R2,#&3f000000        ; mask 'prog-detect'
        TEQ     R0,#27 :SHL: 24         ; escape shifted
        Pull    "R0-R2,PC",EQ

        ADR     R0,progerrslist
01
        LDR     R1,[R0],#4
        TEQ     R1,R2
        Pull    "R0-R2,PC",EQ
        CMP     R1,#-1
        BNE     %BT01
        MOVS    R1,#1                   ; NE

        Pull    "R0-R2,PC"
        ]

        ]

        END
