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
; > Sources.Wimp03

;
; Entry:     [taskhandle] = current task handle
;         [newtaskhandle] = new task handle
; Exit:   R14, [flagword] = R0 on entry to Wimp_Poll (plus version bits)
;                 userblk = R1 on entry to Wimp_Poll
; Errors:  address exception if a dead task is paged IN here
;

pageintask
; Need to preserve flags, and return stuff in R14. Hence EntryS/EXITS are
; no good :(

      [ No32bitCode
        Push    "R0,R14"
      |
        Push    "R0,R1,R14"
        MRS     R1,CPSR
      ]
;
        Debuga  sw,"Page in task:",#newtaskhandle
        LDR     R14,newtaskhandle
        CMP     R14,#0                  ; taskhandle = -1 ==> menu owner
      [ debugsw
        BNE     %FT01
        Debug   sw," - system task"
01
      ]
        BEQ     pageintaskdone          ; 0 ==> no owner at all (ie. Wimp)
        LDRLT   R14,menutaskhandle      ; -1 ==> menus
      [ debugsw
        BGE     %FT01
        Debuga  sw," - menu task =",R14
01
      ]
        CMPLT   R14,#0
      [ debugsw
        BGE     %FT01
        Debuga  sw," - deleted!"
01
      ]
        Debug   sw,""
        BLT     pageintaskdone          ; if no menu owner, give up
        LDR     R0,taskhandle
        TEQ     R0,R14
        LDREQ   R14,flagword
        BEQ     pageintaskdone          ; DON'T RELOAD userblk if not nec.!!!
        Push    "R14"
        LDR     R14,[wsptr,R14]
        TST     R14,#task_unused
        BLEQ    mapslotout              ; map slot out, if still alive
        Pull    "R14"
        STR     R14,taskhandle
        BL      mapslotin
        LDR     R14,taskhandle
        LDR     R14,[wsptr,R14]
        TST     R14,#task_unused        ; tasks are sometimes allowed
      [ debugtask1                      ; to be dead here
        BEQ     %FT01
        Debug   task1,"Dead task paged in:",#taskhandle
01
      ]
        LDREQ   userblk,[R14,#task_registers+4*1]      ; get user R1
        LDREQ   R14,[R14,#task_flagword]
        STREQ   R14,flagword
pageintaskdone
      [ No32bitCode
        Pull    "R0,PC",,^                      ; must preserve flags
      |
        MSR     CPSR_f,R1
        Pull    "R0,R1,PC"                      ; must preserve flags
      ]

lookfornewtask
        Debug   task1,"Task dead on entry to Wimp_Poll"
;
; disconnect the task from any further contact with the Wimp
;
        LDR     R14,ptrtask
        LDR     R5,taskhandle
        TEQ     R5,R14
        MOVEQ   R14,#nullptr            ; avoid ptr_leaving_window!
        STREQ   R14,ptrwindow
;
        MOV     R0,#EscapeHandler       ; the domain is about to die -
        SWI     XOS_ReadDefaultHandler  ; prevent nasty handlers from being
        SWIVC   XOS_ChangeEnvironment   ; called when they shouldn't be!
;
        MOV     R0,#EventHandler
        SWI     XOS_ReadDefaultHandler
        SWIVC   XOS_ChangeEnvironment
;
        MOV     R0,#UpCallHandler
        SWI     XOS_ReadDefaultHandler
        SWIVC   XOS_ChangeEnvironment
;
        BL      deallocatependingtask   ; delete task block (gone for good)
                                        ; reclaim memory as well!
;
        Debug   co,"Closing down task: commandflag =",#commandflag
;
        LDR     R7,commandflag          ; R7 used further down!!!
;
        MOV     R0,#0                   ; 'Press SPACE' if anything printed
        BL      int_commandwindow       ; can't call SWI since task is dead!
        CLRV                            ; ignore errors
;
; now look for an alternative task (preserve R7 in this code)
;
        ADRL    R5,taskpointers
        MOV     R6,#maxtasks
01
        LDR     R14,[R5],#4
        TST     R14,#task_unused
        BEQ     %FT02
        SUBS    R6,R6,#1
        BNE     %BT01
;
        Debug   task1,"No tasks left - calling OS_Exit"
        SWI     XOS_Exit
02
        SUB     R5,R5,#4
        SUB     R5,R5,wsptr
        LDR     R6,taskhandle          ; R6 = previous task handle
        STR     R5,taskhandle
        LDR     userblk,[R14,#task_registers+4*1]
        Debug   task1,"Switching to task",R5
;
        BL      mapslotin               ; previous slot is already mapped out
;
; if that was the single task, change mode now!
; the rule is that the screen is reset unless the commandwindow is pending
; (used to be based on singletaskhandle)
;
        LDR     R5,singletaskhandle
        TEQ     R5,R6
        MOVEQ   R14,#nullptr            ; reset singletaskhandle BEFORE resetk
        STREQ   R14,singletaskhandle
        STREQ   R14,backwindow          ; must have been deleted
;
        TEQ     R7,#cf_pending          ; R7 set up further up !!!
        LDRNE   R0,currentmode          ; only change mode if chars printed

        BLNE    int_setmode
      [ Medusa
        ADRL    R14,greys_mode
        LDRB    R14,[R14]
        TEQ     R14,#0
        BLNE    recalc_greys_palette
      ]

        Debug   task1,"Returned from int_setmode"
;
        ADRL    R3,tempiconblk          ; forget old settings
        BL      resetkeycodes           ; *FX 4,2 etc.
;
        Debug   task1,"Paranoid resetting of state when task exits"
;
        B       taskisused



;;-----------------------------------------------------------------------------
;; Wimp_RegisterFilter - install/deinstall a filter routine
;;
;; in   R0 = filter reason
;;              =0 => pre-poll filter (prior to returning to task)
;;              =1 => post-poll filter (on return back to Wimp)
;;              =2 => block copy filter
;;              =3 => get rectangle filter
;;
;;      R1 -> filter routine / =0 for default
;;      R2 -> workspace for filter
;; out  -
;;-----------------------------------------------------------------------------

        ASSERT  postfilter =prefilter +8
        ASSERT  copyfilter =postfilter +8
        ASSERT  rectanglefilter =copyfilter +8
	ASSERT	postrectfilter =rectanglefilter +8
	ASSERT	posticonfilter =postrectfilter +8

        ASSERT  prefilterWP =prefilter -4

SWIWimp_RegisterFilter

        MyEntry "RegisterFilter"

        CMP     R0,#WimpFilter_MAX      ; filter number valid?
        BHS     err_badR0               ; if not then return an error

        TEQ     R1,#0                   ; de-register a filter
        ADREQ   R1,filtertable
        LDREQ   R2,[R1,R0,LSL #2]       ; get the default owner
        ADDEQ   R1,R1,R2                ; and resolve to an address, rather than offset

        ADRL    R14,prefilter
        ADD     R14,R14,R0,LSL #3       ; -> vector to store into
        STR     R1,[R14]
        STR     R2,[R14,#-4]            ; setup the handler correctly

        B       ExitWimp

;..............................................................................

; table of default vector owners

filtertable
        & prefilter_default -filtertable
        & postfilter_default -filtertable
        & copyfilter_default -filtertable
        & rectanglefilter_default -filtertable
        & postrectfilter_default -filtertable
	& posticonfilter_default -filtertable
        & -1

prefilter_default
postfilter_default
copyfilter_default
rectanglefilter_default
postrectfilter_default
posticonfilter_default

        MOV     PC,LR

;;-----------------------------------------------------------------------------
;; Reset the filters back to their default state, called on init and svc_reset,
;; once done issue a svc_RegisterFilters.
;;-----------------------------------------------------------------------------

defaultfilters EntryS "R0-R2"

        ADR     R0,filtertable          ; -> list of default owners
        ADRL    R1,prefilter            ; -> list of vectors to install
        MOV     R2,R0

10      LDR     R14,[R0],#4             ; get offset to routine
        CMP     R14,#-1
        ADDNE   R14,R14,R2
        STRNE   R14,[R1],#8             ; if not end of the table then store away
        BNE     %BT10

        ADR     R0,svc_callback
        MOV     R1,WsPtr
        SWI     XOS_AddCallBack         ; add the callback routine

        EXITS

;..............................................................................

; callback routine used to warn the outside world that they should register
; filters with the Window Manager.

svc_callback ROUT

        Push    "R1,LR"
        MOV     R1,#Service_WimpRegisterFilters
        SWI     XOS_ServiceCall
        Pull    "R1,PC"                 ; broadcast to the world


;;----------------------------------------------------------------------------
;; Wimp_Poll
;;
;; return codes are prioritised according to number:
;;
;;       1       Redraw_Window_Request
;;       2       Open_Window_Request
;;       3       Close_Window_Request
;;       4       Pointer_Leaving_Window
;;       5       Pointer_Entering_Window
;;       6       Mouse_Click
;;       7       User_Dragbox
;;       8       Key_Pressed
;;       9       Menu_Select
;;      10       Scroll_Request
;;
;; This is also the entry point after deleting a task
;;----------------------------------------------------------------------------

err_badR3
        MyXError  WimpBadR3
        B       ExitWimp
        MakeErrorBlock WimpBadR3

SWIWimp_PollIdle
        Debug   poll2, "Wimp_PollIdle entry"
        ORR     R0,R0,#flag_pollidle    ; time limit is in R2
        B       %FT01

SWIWimp_Poll
        Debug   poll2, "Wimp_Poll entry"
        BIC     R0,R0,#flag_pollidle    ; no time limit supplied

01
        MyEntry "Poll"

; remember task number, to allow optimisation of return to caller
;
; Entry: R0 = flag word
;        R1 = taskhandle
;        R2 = target time (if R0 & flag_pollidle) - as in ReadMonotonicTime
;        R3 -> poll word  (if R0 & flag_pollword, and Wimp 2.23 known)
;   userblk = original R1 --> poll block
;

; attempt to call a pre-poll filter routine, it may modify the flags in R0

        CallFilter prefilter
;
      [ AutoHourglass                   ; it could still be a while until the next task switch,
        LDR     R1, hourglass_status    ; so ensure the hourglass is off at this point
      [ debugautohg
	Push	"handle"
	LDR	handle, taskhandle
        Debug	autohg, "Hourglass_Off at Wimp_Poll entry: taskhandle, old status =", handle, R1
        Pull	"handle"
      ]
        TEQ     R1, #2                  ; is hourglass still pending or active?
        MOVEQ   R1, #1                  ; yes, so turn off hourglass (but keep on vector for speed reasons)
        STREQ   R1, hourglass_status
        SWIEQ   XHourglass_Off
        CLRV                            ; ignore errors
      ]

        LDR     R1,taskhandle
        LDR     R4,[wsptr,R1]           ; R4 = task data pointer
        TST     R4,#task_unused         ; if task not used, it's been deleted
        BNE     lookfornewtask

        LDR     R5,[R4,#task_flagword]  ; R5 = flag word
        LDR     R14,singletaskhandle
        TEQ     R1,R14                  ; if single-tasking
        LDREQ   R14,=masknewcodes
        ORREQ   R0,R0,R14               ; disallow new reason codes

; set up R3 -> poll word, with bottom bit set => urgent
; also validate R0,R3 (but only if task knows about Wimp 2.23)

        LDR     R14,[R4,#task_wimpver]
        CMP     R14,#223
        MOVLO   R3,#0                   ; R3=0 => no poll word
        BLLO    killfpblock             ; get rid of this!
        BLO     %FT01

; this stuff only applies to tasks that know about Wimp 2.23 or later
; bits 22,23 => poll word, bit 24 => save/restore FP registers

        TST     R0,#pollword_bit        ; if this event is disabled,
        BICNE   R0,R0,#flag_pollword    ; then there's no point polling!

        TST     R0,#flag_pollword       ; no poll word if this bit unset
        MOVEQ   R3,#0

        TST     R3,#3                   ; check that address is word-aligned
        BNE     err_badR3
        CMP     R3,#ApplicationStart    ; and not in application space

        [ Medusa
        LDRHS   R14,orig_applicationspacesize
        CMPHS   R14,R3
        |
        RSBHSS  R14,R3,#&1000000        ; APPSPACE
        ]
        BHS     err_badR3

	CLRV				; make sure we don't leave V set
        TST     R0,#flag_pollword
        TSTNE   R0,#flag_pollfast       ; bottom bit set => poll quickly
        ORRNE   R3,R3,#1

        MOV     R14,R0,LSR #flag_versionbit   ; object if others set
        BICS    R14,R14,#flag_allowed :SHR: flag_versionbit
        BNE     err_badR0                       ; error from Wimp_Poll !!!

; does the task want to save the FP registers?

        TST     R0,#flag_fpsave
        BLEQ    killfpblock                     ; preserves flags
        BLNE    saveFPregs
        BVS     ExitWimp

; save toned-down flag word in task workspace

01
        STR     R3,[R4,#task_pollword]

        LDR     R14,[R4,#task_priority]
        TST     R0,#flag_pollword
        TEQNE   R3,#0
        ORRNE   R14,R14,#priority_pollword      ; Has a poll word ?
        BICEQ   R14,R14,#priority_pollword

      [ debugpoll
        BEQ     %FT00
        Debug   poll,"New poll task: handle, posn",R1,#PollTaskPtr
00
      ]

        LDRNE   R3,PollTaskPtr
        STRNE   R1,[R3],#4                      ; Add task handle to list of polled tasks
        STRNE   R3,PollTaskPtr

        TST     R0,#flag_pollidle
        ORRNE   R14,R14,#priority_idle          ; Poll_idle ?
        BICNE   R14,R14,#priority_null
        BICEQ   R14,R14,#priority_idle
        BNE     %FT01

        TST     R0,#null_bit
        ORREQ   R14,R14,#priority_null          ; Wants Null events ?
        BICNE   R14,R14,#priority_null
01
        STR     R14,[R4,#task_priority]

        MOV     R0,R0,LSL #32-flag_versionbit   ; clear version bits
        MOV     R0,R0,LSR #32-flag_versionbit
        MOV     R5,R5,LSR #flag_versionbit      ; so we can retain the old ones
        ORR     R0,R0,R5,LSL #flag_versionbit
        STR     R0,[R4,#task_flagword]          ; remember original flags
        STR     R0,flagword
        STR     userblk,[R4,#task_registers+4*1]        ; and user R1
        STR     R2,[R4,#task_registers+4*2]             ; and target time
;
; save VFP context, lazily if possible
;
        MOV     R0,#0
        MOV     R1,#VFPSupport_ChangeContext_Lazy+VFPSupport_ChangeContext_AppSpace
        SWI     XVFPSupport_ChangeContext
        MOVVS   R0,#0 ; Ignore error (probably means VFPSupport isn't loaded)
        Debug   fp,"VFP on Wimp_Poll entry",R0
        STR     R0,[R4,#task_vfpcontext]
        CLRV
;
; check to see if there are any more outstanding parents
;
taskisused
        LDR     R14,taskSP
        ADR     R1,taskstack
        TEQ     R14,R1
        BEQ     %FT01

        LDR     R1,[R14,#-4]!           ; empty ascending stack
        STR     R14,taskSP

        LDR     R0,polltaskhandle       ; R0 = child's task handle
        LDR     R14,[wsptr,R0]          ; R14 = task block pointer
        TST     R14,#task_unused
        MOVNE   R0,#0                   ; R0=0 => child is already dead
        LDREQ   R14,[R14,#task_flagword]
        MOVEQ   R14,R14,LSR #flag_versionbit
        ORREQ   R0,R0,R14,LSL #flag_versionbit

        Task    R1,,"Parent"            ; make sure correct page swaps happen
        LDR     R14,[wsptr,R1]
        TST     R14,#task_unused        ; parent might be dead!
        BNE     lookfornewtask

        B       ExitPoll_toparent       ; exit back to parent task
01

;
; if menus marked for deletion, kill them off!
;
        LDR     R0,menus_temporary      ; -4 ==> kill menus
        TEQ     R0,#0
        STRNE   R0,menutaskhandle       ; NE ==> R0 = -4
        MOVNE   R14,#0
        STRNE   R14,menus_temporary
        BLNE    closemenus
;
; ensure that escape condition generation is disabled on entry
;
      [ debugescape
        LDR     R14,singletaskhandle
        CMP     R14,#nullptr            ; old Wimp didn't set up escape!
        BNE     %FT02
;
        Push    "R0-R2"

        MOV     R0,#229                 ; *FX 229,1 (escape ==> ascii 27)
        MOV     R1,#1
        MOV     R2,#0
        SWI     XOS_Byte
        TEQ     R1,#0                   ; was escape already disabled?
        TOGPSR  Z_bit, R14              ; NE => escape enabled
        MOVEQ   R0,#126
        SWIEQ   XOS_Byte
        TEQEQ   R1,#0                   ; or was there an escape condition?

        Pull    "R0-R2"
        BEQ     %FT02
        MyXError  WimpBadEscapeState
        B       ExitPoll                ; Wimp reports errors itself
        MakeErrorBlock WimpBadEscapeState
02
      ]
;
; re-entry point from within polling routines
;
repollwimp
        Debug   poll2, "repollwimp"
        BL      powersave_tick
        LDR     R14,taskhandle          ; get userblk back (may be corrupted)
        LDR     R14,[wsptr,R14]
        LDR     userblk,[R14,#task_registers+4*1]
;
        MOV     R0,#1
        BL      scanpollwords           ; scan high-priority tasks
        BNE     ExitPoll

        LDR     R2,headpointer          ; are there any outstanding messages?
        CMP     R2,#nullptr
        BNE     returnmessage
;
      [ MultiClose
        LDR     R2, nextwindowtoiconise
        TEQ     R2, #0
        BLNE    iconisenextwindow
        LDR     R2, headpointer         ; are there any outstanding messages now?
        CMP     R2, #nullptr
        BNE     returnmessage
      ]
;
        MOV     R14,#0
        STR     R14,sender              ; all Wimp messages from now on
        STR     R14,hotkeyptr           ; reset this if no more messages
;
; check for a recent mode change - if so, deliver Open_Window_Requests
;
        LDRB    R14,modechanged
        TEQ     R14,#0
        BEQ     nomodechange
        MOV     R14,#0
        STRB    R14,modechanged

; copy scrx1,y1 into lastmode_x1,y1 for next time

        LDR     R14,scrx1
        STR     R14,lastmode_x1
        LDR     R14,scry1
        STR     R14,lastmode_y1

; send Message_ModeChange first

        MOV     R14,#ms_data            ; size of block
        STR     R14,[sp,#-ms_data]!
        MOVVC   R0,#User_Message
        MOV     R1,sp
        MOV     R2,#0
        STRVC   R2,[R1,#ms_yourref]
        LDR     R14,=Message_ModeChange
        STRVC   R14,[R1,#ms_action]
        BLVC    int_sendmessage_fromwimp
        ADD     sp,sp,#ms_data          ; correct stack
;
        Debug   task1,"Mode change message sent"

; first make a copy of the window stack, so that changes in the order are OK
; Enumerate the window stack from back to front

        LDR     R5,activewinds+lh_backwards
01
        LDR     R4,[R5,#ll_backwards]
        CMP     R4,#nullptr
        BEQ     repollwimp
        SUB     handle,R5,#w_active_link
        MOV     R5,R4
;
        Debug   ms,"Mode Change: re-opening window handle",R0,handle
;
        LDR     R14,[handle,#w_flags]
        TST     R14,#wf_isapane         ; don't re-open panes
        BNE     %BT01
;
        Push    "R4,R5,userblk"

        LDR     R14,[handle,#w_flags]   ; ensure window is put on-screen

        LDR     R4,forceflags           ; 0 or ws_onscreenonce
        ORR     R14,R14,R4              ; R4 = 0 or ws_onscreenonce
        STR     R14,[handle,#w_flags]

        ADD     R14,handle,#w_wax0
        LDMIA   R14,{cx0,cy0,cx1,cy1,x0,y0}
        Rel     R14,handle              ; bhandle (open at same height)
        MOV     R0,R14

        Push    "R0,cx0,cy0,cx1,cy1,x0,y0,R14"
        MOV     R1,sp

        LDR     R2,[handle,#w_taskhandle]
        CMP     R2,#0                   ; if system window, open automatically
        BGT     %FT11

; Skip backwindow and iconbarwindow

      [ true
        B       %FT22
      |
        LDR     R14,backwindowhandle    ; if back window, open at full size
        TEQ     R0,R14
        LDRNE   R14,iconbarhandle
        TEQNE   R0,R14
        BEQ     %FT22                   ; ignore these (already done first)
      ]
11
        Rel     R2,handle               ; must send the handle, so that
        MOV     R0,#Open_Window_Request ; the message is lost if window deleted
        Debug   mode,"Sending open request to",R2
        BL      int_sendmessage_fromwimp
22
        ADD     sp,sp,#u_ow1            ; correct stack (& ignore errors)
        Pull    "R4,R5,userblk"
        B       %BT01

nomodechange
      [ redrawlast
        B       lookatpointer

check_redraw
      ]
;
; flush pending opens - make sure this is done BEFORE redraw stuff
;
      [ ChildWindows
        BL      int_flush_opens         ; may cause a braindead panic redraw
      ]
;
; look at invalid list to see if a redraw is necessary
;
        BL      checkredrawhandle
      [ :LNOT: ChildWindows             ; this is pointless - can't get an error from checkredrawhandle!
        BVS     ExitPoll                ; <<<< wot?
      ]
;
; Improved handling of rectangle area full:
; Redraw whole screen intelligently first, then, if that fails, draw
; all the windows from the back to the front (braindead isn't it!)

        LDR     R1,BPR_indication
        TEQ     R1,#BPR_panicnow
        BEQ     start_braindead_panic_redraw
        CMP     R1,#BPR_continuelevel
        BHS     continue_braindead_panic_redraw
        CMP     R1,#BPR_gotfullarea
        BLEQ    BPR_startintelligentredraw
;
        LDR     R1,rlinks+invalidrects
        CMP     R1,#nullptr

; Downgrade to no panic

        MOVEQ   R1,#BPR_notatall
        STREQ   R1,BPR_indication
      [ redrawlast
        BEQ     check_null
      |
        BEQ     lookatpointer           ; screen is all valid!
      ]
;
        LDR     R1,activewinds+lh_forwards

pollredrawlp
        LDR     R2,[R1,#ll_forwards]
        CMP     R2,#nullptr
        BEQ     clearrects

        SUB     handle,R1,#w_active_link

        Push    "R2"
        BL      invalidouterportion
        Pull    "R1"

        LDR     R2,rlinks+windowrects
        CMP     R2,#nullptr
        BEQ     pollredrawlp

;
; Right - windowrects is the intersection of this window's outer portion with the invalid list
; We need to check whether any of the window's children should be redrawn first
;

process_redrawable_window ROUT

        Debug   child,"process_redrawable_window",handle

      [ ChildWindows
        LDR     R2,[handle,#w_children + lh_forwards]           ; start from the top

01      LDR     R14,[R2,#ll_forwards]
        CMP     R14,#nullptr
        BEQ     %FT04

        Push    "R2"

        LDR     R14,[R2,#w_flags - w_active_link]
        TST     R14,#wf_inborder
        ADDNE   R14,handle,#w_x0                ; clip to outer box if it can go in the border
        ADDEQ   R14,handle,#w_wax0              ; clip to work area otherwise
        LDMIA   R14,{x0,y0,x1,y1}

        ADD     R14,R2,#w_x0 - w_active_link
        LDMIA   R14,{cx0,cy0,cx1,cy1}

        max     cx0,x0                          ; intersect child's outer box with parent's work area or outline
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1

        Debug   child,"process_redrawable: child rectangle",cx0,cy0,cx1,cy1
        MOV     R0,#windowrects
        MOV     R1,#torects
        BL      intrect                         ; see if this intersects with the invalid list

        Pull    "R2"

        LDR     R14,rlinks+torects
        CMP     R14,#nullptr
        BNE     %FT03

02      LDR     R2,[R2,#ll_forwards]
        B       %BT01

; Right - redraw the child first, rather than the parent

03      MOV     R0,#windowrects
        BL      assign_set                      ; calls SetRectPtrs internally
        SUB     handle,R2,#w_active_link
      [ debug
        LDR     R14,rlinks + windowrects
        Debug   child,"Detected redraw for child window,rects",handle,R14
      ]
        B       process_redrawable_window       ; in case of nested child windows
04

process_redrawable_window_actually ROUT

        Debug   child,"Actually redraw window",handle
      ]
;
; check for auto-redraw bit in window flags
;
        LDR     R14,[handle,#w_flags]
        Debug   child,"window flags are",R14
        TST     R14,#wf_autoredraw
        BEQ     tryreturnit
;
        BL      int_redraw_window
redrlp  BVS     ExitPoll                        ; <<<< wot?
        TEQ     R0,#0
        BEQ     repollwimp
 [ Twitter
        BL      checktwitter
        LDRNE   r14, getrectflags
        ORRNE   r14, r14, #getrect_twitter
        STRNE   r14, getrectflags
 ]
        BL      int_get_rectangle               ; will draw the user icons
        B       redrlp
;
; check that task did not disable Redraw_Window_Request
;
tryreturnit
        LDR     R14,[handle,#w_taskhandle]
        Task    R14,,"RedrawRq"         ; can't be a menu (auto-redraw)
        TST     R14,#redraw_bit
      [ redrawlast
        BNE     check_null
      |
        BNE     lookatpointer           ; CAN'T CARRY ON (doesn't work!)
      ]
;
; return Redraw_Window_Request (and remember the handle we want back!)
;
        Rel     R14,handle
        STR     R14,[userblk]
        STR     R14,redrawhandle
      [ debug
        LDR     R14,rlinks + windowrects
        Debug   child,"Returning Redraw_Window_Request for window,rects",#redrawhandle,R14
      ]
        MOV     R0,#Redraw_Window_Request
        B       ExitPoll

powersave_tick
        Entry   "r0"
        LDR     R14,IdlePerSec          ; update the idle information for the portable modules
        ADD     R14,R14,#1
        STR     R14,IdlePerSec
 [ Stork
        LDR     R14, WimpPortableFlags
        TST     R14, #PowerSave                 ; if power saving
        TSTNE   R14, #PortableFeature_Idle      ; and Portable_Idle works
        SWINE   XPortable_Idle                  ; then go dormant until next interrupt or centi-second tick
 ]
        EXIT

        LTORG

;
; clearrects - no more windows left, so clear the rest out
;
clearrects
        BL      defaultwindow
        LDR     R0,scrx0
        LDR     R1,scry1
        SUB     R1,R1,#1                ; default is top-left of screen
        SWI     XOS_SetECFOrigin
        MOV     R0,#4
        BL      background
;
        Push    "userblk"
        SetRectPtrs
;
        MOV     R1,#invalidrects
        B       endclearrects
clearrectslp
        getxy   R1,x,y
        BL      graphicswindow
        [ windowsprite
        Push    "R0"
        LDRB    R0,[handle,#w_wbcol]

        BL      plotspritebackground
        Pull    "R0"
        |
        SWI     XOS_WriteI+16
        ]
      [ Autoscr
        LDR     R14, dragflags
        TST     R14, #dragf_clip ; clipped dragboxes must only be redrawn within their own window
        LDRNE   R14, draghandle
        Abs     R14, R14, NE
        TEQNE   R14, handle
        BLEQ    forcedrag_on            ; put drag rectangle back if nec.
      |
        BL      forcedrag_on            ; put drag rectangle back if nec.
      ]
endclearrects
        LDR     R1,[rectlinks,R1]
        CMP     R1,#nullptr
        BNE     clearrectslp
;
        MOV     R0,#invalidrects
        BL      loserects
        BL      defaultwindow
;
        Pull    "userblk"
        B       repollwimp              ; try again!

start_braindead_panic_redraw
        Debug   bpr,"Starting braindead panic redraw"

; Clear screen to background

        BL      defaultwindow
        LDR     R0,scrx0
        LDR     R1,scry1
        SUB     R1,R1,#1                ; default is top-left of screen
        SWI     XOS_SetECFOrigin
        MOV     R0,#4
        BL      background
        SWI     XOS_WriteI+16           ; CLG

; Find the backmost window and store in BPR_indication -
; BPR_notatall is used to indicate no windows

        LDR     R14,activewinds+lh_backwards
        LDR     R0,[R14,#ll_backwards]
        CMP     R0,#nullptr
        MOVEQ   R14,#BPR_notatall
        SUBNE   R14,R14,#w_active_link
        Rel     R14,R14,NE
        STR     R14,BPR_indication

continue_braindead_panic_redraw

; Run out of windows? - done with redrawing

        LDR     handle,BPR_indication
        TEQ     handle,#BPR_notatall
        BEQ     repollwimp

        Debug   bpr,"Continuing braindead panic redraw on handle",handle

; Window gone? - start from the start again

        BL      checkhandle
        BVS     start_braindead_panic_redraw

; Window closed? - start from the start again

        LDR     R14,[handle,#w_flags]
        Debug   bpr,"handle, flags are",handle,R14
        TST     R14,#ws_open
        BEQ     start_braindead_panic_redraw

; Move BPR_indication to next window in stack (must deal with child window stacks as well)

      [ ChildWindows
        Push    "handle"

        LDR     R0,[handle,#w_children + lh_backwards]          ; go for backmost child window first
        LDR     R14,[R0,#ll_backwards]
        CMP     R14,#nullptr
        BNE     %FT02

01      LDR     R0,[handle,#w_active_link + ll_backwards]       ; then go for next sibling
        Debug   bpr,"Next sibling",handle,R0
        LDR     R14,[R0,#ll_backwards]
        CMP     R14,#nullptr
        BNE     %FT02

        LDR     handle,[handle,#w_parent]                       ; else go for parent's next sibling, etc.
        Debug   bpr,"Move up to parent",handle
        CMP     handle,#nullptr
        BNE     %BT01

02      MOVEQ   R0,#BPR_notatall
        SUBNE   R0,R0,#w_active_link
        Rel     R0,R0,NE
        STR     R0,BPR_indication

        Pull    "handle"

        Debug   bpr,"Braindead redraw: this,next",handle,R0
      |
        LDR     R0,[handle,#w_active_link+ll_backwards]
        LDR     R14,[R0,#ll_backwards]
        CMP     R14,#nullptr
        MOVEQ   R0,#BPR_notatall
        SUBNE   R0,R0,#w_active_link
        Rel     R0,R0,NE
        STR     R0,BPR_indication
      ]

; Process this window (exactly)

        BL      initrectptrs
        ADD     R0,handle,#w_x0
        LDMIA   R0,{cx0,cy0,cx1,cy1}

; If this is a child window, clip to parent's work area/outline

      [ ChildWindows
        MOV     R1,handle
        B       %FT12

11      TST     R0,#wf_inborder
        ADDNE   R14,R1,#w_x0            ; clip to outer box if allowed to overlap border
        ADDEQ   R14,R1,#w_wax0          ; clip to parent's work area otherwise
        LDMIA   R14,{x0,y0,x1,y1}
        max     cx0,x0
        max     cy0,y0
        min     cx1,x1
        min     cy1,y1

12      LDR     R0,[R1,#w_flags]
        LDR     R1,[R1,#w_parent]
        CMP     R1,#nullptr
        BNE     %BT11
      ]

; make one-rectangle list of the window's outer box (clipped to its parent's work area)

        MOV     R0,#windowrects
        MOV     R1,R0
        BL      addrect
        LDR     R14,rlinks+windowrects
        CMP     R14,#nullptr
        BEQ     continue_braindead_panic_redraw
      [ ChildWindows
        B       process_redrawable_window_actually      ; DON'T consider the children this time
      |
        B       process_redrawable_window
      ]


;;----------------------------------------------------------------------------
;; Just before looking at the mouse, check all poll words
;;----------------------------------------------------------------------------

lookatpointer
        MOV     R0,#-1
        BL      scanpollwords           ; scan all tasks with pollwords
        BNE     ExitPoll
;
; Has the ticker gone off to see if we need to look at the
; mouse co-ordinates, have they changed yet?!
;
      [ mousecache
        LDRB    R0,recacheposn
        TEQ     R0,#0                   ; do we recache the information?
        BEQ     trykeys                 ; no, so ignore
      ]
;
; now see what user input has occurred
;
        Debug   poll2, "Processing mouse"
        BL      getmouseposn            ; ie. MOUSE R0,R1,R2

      [ PoppingIconBar
	BL	checkiconbarpop
      ]
;
; are we dragging a box?
;
        LDR     R14,dragtype
        TEQ     R14,#0
        BEQ     notdragging
;
; update coords (depends on drag type) and do bound checking
;
        Push    "R0-R2"                 ; mouse x,y coords and buttons

        LDR     R14,dragoldx
        STR     R0,dragoldx
        SUB     R0,R0,R14               ; x-offset this time
        LDR     R14,dragoldy
        STR     R1,dragoldy
        SUB     R1,R1,R14

        ADR     R14,dragx0
        LDMIA   R14,{x0,y0,x1,y1}
        LDR     R14,dragtype
        TEQ     R14,#drag_size          ; do we move both coords?
        TEQNE   R14,#drag_user2         ; user rubber-box
        TEQNE   R14,#drag_subr_size     ; user-supplied subroutine, rubber box
        TEQNE   R14,#drag_subr_size2    ; user-supplied subroutine, rubber box
        ADDNE   x0,x0,R0
        ADDNE   y1,y1,R1
        ADD     x1,x1,R0
        ADD     y0,y0,R1
;
; if drag types 10 or 11, or still holding button down, update box and continue
;
        TEQ     R14,#drag_subr_posn2
        TEQNE   R14,#drag_subr_size2
        TOGPSR  Z_bit,R14               ; NE ==> it is one of these
        TSTEQ   R2,#button_left:OR:button_middle:OR:button_right
        BLEQ    nodrag
        BLNE    yesdrag                 ; updates dragx0,y0,x1,y1
        Pull    "R0-R2"
        BEQ     boxdropped
;
; check sysflags to see if continuous dragging occurs
;
        LDR     R14,dragtype
        TEQ     R14,#drag_scrollboth    ; use vscroll bit of sysflags for this
        MOVEQ   R14,#drag_vscroll
        CMP     R14,#drag_user
        BHS     notdragging             ; only system drags are elegible

        Push    "R0"
        LDRB    R0,sysflags             ; drag bits are 0..3
        MOVS    R0,R0,LSR R14
        Pull    "R0"
        BCC     notdragging             ; R0,R1 = mouse coords here

        LDR     R1,dragtype             ; R14 may not = dragtype
        B       returndrag
;
; box has been dropped
; cancel drag box, then return appropriate reason code
;
boxdropped
        Push    "x0,y0,x1,y1"
        BL      clearpointerwindow      ; corrupts x0,y0,x1,y1
        Pull    "x0,y0,x1,y1"
;
        LDR     R1,dragtype
        TEQ     R1,#drag_scrollboth
        BLEQ    pointeron

        MOV     R0,#0                           ; cancel drag operation
        STR     R0,dragtype                     ; >>> leave [draghandle] alone!
        LDR     R0,mouseflags                   ; (for compatibility)
        BIC     R0,R0,#mf_oldcoords
        STR     R0,mouseflags
;
; come here for continuous dragging as well
; R1 = drag type ([dragtype] may already be 0)
;
returndrag
        ADR     R14,dragoffx0                   ; compute box coords
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        ADD     cx0,x0,cx0
        ADD     cy0,y0,cy0
        ADD     cx1,x1,cx1
        ADD     cy1,y1,cy1
        LDR     R14,dragtask                    ; originator of drag
        TEQ     R14,#0                          ; if menu,
        ADREQL  userblk,tempiconblk             ; set up dummy userblk
        Task    R14,NE,"Drag"                   ; else point to user's block

        CMP     R1,#drag_scrollboth
        CMPNE   R1,#drag_user-1
        STMHIIA userblk,{cx0,cy0,cx1,cy1}       ; final box coords
        MOVHI   R0,#User_Dragbox
        BHI     ExitPoll                        ; return User_DragBox
;
; return Open_Window_Request to the application
; R1 = drag type
; [dragtype] = 0 (drag has terminated) - unless continuous dragging
;
        TEQ     R1,#drag_posn
        TEQNE   R1,#drag_size
        BEQ     gonewposnsize
;
        LDR     handle,draghandle
        STR     handle,[userblk]
        BL      checkhandle                     ; might have been deleted?
        BLVS    nodragging                      ; stop it looping
        BVS     notdragging
;
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{x0,y0,x1,y1}
        ADD     R14,userblk,#4
        STMIA   R14!,{x0,y0,x1,y1}
;
; scroll bar was dragged - now work out new scroll bar positions
;
        TEQ     R1,#drag_hscroll
        TEQNE   R1,#drag_scrollboth
        LDRNE   x0,[handle,#w_scx]
        BLEQ    getnewscx                       ; get x0 from cx0,cx1 etc.
;
        TEQ     R1,#drag_vscroll
        TEQNE   R1,#drag_scrollboth
        LDRNE   y0,[handle,#w_scy]
        BLEQ    getnewscy                       ; get y0 from cy0,cy1 etc.
;
        Push    "x0,y0"
        BL      calc_w_status
        Pull    "x0,y0"
        LDR     x1,[handle,#w_bhandle]          ; open at same place in stack
        ADD     R14,userblk,#u_scx
        STMIA   R14,{x0,y0,x1}
;
        B       Exit_OpenWindow

gonewposnsize
        LDR     handle,draghandle               ; handle of window to open
        STR     handle,[userblk,#u_handle]
        BL      checkhandle                     ; window deleted?
        BLVS    nodragging
        BVS     notdragging     ; CLRV
;
        TEQ     R1,#drag_size                   ; R1 = drag type
        BNE     %FT01
        LDR     R14,[handle,#w_flags]
        ORR     R14,R14,#ws_onscreenonce        ; force window onto screen!
        STR     R14,[handle,#w_flags]           ; (don't touch toggled bit)
01
        ADD     R14,handle,#w_scx
        LDMIA   R14,{x1,y1}
        ADD     R14,userblk,#u_wax0
        STMIA   R14!,{cx0,cy0,cx1,cy1}
        STMIA   R14,{x1,y1}                     ; scroll positions

        BL      calc_w_status           ; ensure bhandle up-to-date

        LDR     R2,oldbuttons
        B       openwindow_checkbuttons

	[ PoppingIconBar
	; Note - need to sort out Service_MouseTrap for all this!
	ROUT
checkiconbarpop
	Push	"R0,LR"
	LDR	R14,singletaskhandle
	CMP	R14,#nullptr
	Pull	"R0,PC",NE		; old-style tasks don't have an icon bar!
	LDR	R14,iconbar_pop_state
	ADD	PC,PC,R14,LSL #2
	NOP
	B	%F10
	B	%F20
	B	%F30
	[ OldStyleIconBar
; Icon bar is held by menu
	|
	NOP ; drops through
; Icon bar is held by menu, or fronted by keyboard
        ]
	Pull	"R0,PC"

; Icon bar is at back
10      LDRB    R14, popiconbar
        TEQ     R14, #0
        Pull    "R0, PC", EQ    ; don't bring to front if configured off

        TEQ	R1,#0		; are we at the bottom of the screen?
	Pull	"R0,PC",NE

      [ Autoscr
        ; Don't bring to front if autoscrolling
        LDR     R14, autoscr_state
        TST     R14, #af_enable
        Pull    "R0, PC", NE
      ]
	; Don't bring to front if dragging a window
	LDR	R14,dragtype
	CMP	R14,#drag_posn
	BLO	%FT11
	CMP	R14,#drag_vscroll
	Pull	"R0,PC",LO
	TEQ	R14,#drag_scrollboth
	Pull	"R0,PC",EQ

11	SWI	XOS_ReadMonotonicTime
	Pull	"R0,PC",VS
	[ true
	LDR	R14, popiconbar_pause
	ADD	R0,R0,R14
	|
	ADD	R0,R0,#pop_DelayTime
	]
	STR	R0,iconbar_pop_time
	MOV	R0,#pop_Delaying
	STR	R0,iconbar_pop_state
	Pull	"R0,PC"

; Icon bar is delaying
20	TEQ	R1,#0
	MOVNE	R14,#pop_Back
	STRNE	R14,iconbar_pop_state
	Pull	"R0,PC",NE
	SWI	XOS_ReadMonotonicTime
	LDR	R14,iconbar_pop_time
	CMP	R0,R14
	Pull	"R0,PC",LO
	MOV	R14,#pop_Front
	STR	R14,iconbar_pop_state
	MOV	R14,#0
	B	%FT50

; Icon bar is at front
30	LDR	R14,iconbarheight
	CMP	R1,R14
	Pull	"R0,PC",LE
	MOV	R14,#pop_Back
	STR	R14,iconbar_pop_state
	MOV	R14,#1

50
	MOV	R0,R14
	LDR	handle,iconbarhandle
	CMP	handle,#nullptr
	Pull	"R0,PC",EQ

;
; As we enter here, R0=0 means pop to front, else go to back (or previous position)
;
	Push	"R1-R11"
	BL	checkhandle             ; handle -> window block
	BLVC	calc_w_status           ; set up flag word
	LDRVC	R14,[handle,#w_flags]
	BVS	%FT70
	TEQ	R0,#0
	BNE	%FT60
	; Going to front. Remember where to go back to.
	[ OldStyleIconBar
	TST	R14,#wf_backwindow
	MOVNE	R6,#-2
	LDREQ	R6,[handle,#w_bhandle]
	ADRL	R0,iconbar_pop_previous
	STR	R6,[R0]
	]
	BIC	R14,R14,#wf_backwindow
	STR	R14,[handle,#w_flags]
	MOV	R6,#-1
	B	%FT65

60	; Going back to previous position.
        [ OldStyleIconBar
	ADRL	R6,iconbar_pop_previous
	LDR	R6,[R6]
	CMP	R6,#-2
	ORREQ	R14,R14,#wf_backwindow
	STREQ	R14,[handle,#w_flags]
	|
	ORR     R14, R14, #wf_backwindow
	STR     R14, [handle, #w_flags]
 [ HideIconBar
	MOV     R6, #-3
 |
	MOV     R6, #-2
 ]
	]
65
	ADD	R14,handle,#w_wax0
	LDMIA	R14,{R0-R3,R4,R5}
	Push	"R0-R6"
	LDR	R14,iconbarhandle
	Push	"R14"
	MOV	userblk,sp
	BL	int_open_window
	ADD	sp,sp,#8*4
70
	Pull	"R1-R11"
	Pull	"R0,PC"
	]

;;----------------------------------------------------------------------------
;; Check for pointer changing window
;;----------------------------------------------------------------------------

notdragging

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

      ; CLRV                            ; ignore errors if they reach here
        MOV     R5,#0                   ; don't match shaded icons
        BL      int_get_pointer_info    ; R3,R4 = window/icon handle

        LDR     R14,dragtype            ; We've just changed icon, do we
        TEQ     R14,#0                  ; to change pointer shape?
        BNE     %FT92
        LDR     R14,mouseflags
        TST     R14,#mf_waitdrag
        BNE     %FT92

        Push    "r0"

        ADRL    r0,old_icon
        LDR     R14,[r0]
        TEQ     R3,R14
        STRNE   R3,[r0]
        ADRL    r0,old_window
        LDREQ   R14,[r0]
        TEQEQ   R4,R14
        STRNE   R4,[r0]

        Pull    "r0"

        BEQ     %FT92

        Push    "R0-R7,handle"

        Abs     R14,R3
        LDR     R14,[R14,#w_taskhandle]
        CMP     R14,#-1                 ; is the task -1, ie. owned by a menu
        BNE     %FT01
;
        SWI     XOS_ReadMonotonicTime
        LDR     R1,automenu_timelimit
        ADD     R1,R1,R0                ; reset the time limit
        STR     R1,automenu_timeouttime
      [ ClickSubmenus
        MOV     R14, #0
        STRB    R14, submenuopenedbyclick
      ]
01
        CMP     R3,#nullptr
        BEQ     %FT90
        CMP     R4,#nullptr
        CMPNE   R4,#nullptr2
        BEQ     %FT90
;        TST     R3,#1
;        BEQ     %FT90

        Debug   bo,"New window,icon",r3,r4

        LDR     r14,iconbarhandle
        CMP     r14,r3
        Debug   bo,"iconbar handle , handle",r14,r3
        TEQ     r14,r3
        BNE     %FT01

        Push    "R1-R4,R7"
        BL      findicon
        LDR     R14,[R2,#icb_taskhandle]
        Task    R14,,"Icon bar pointer shape check"
        Pull    "R1-R4,R7"
        Abs     r14,r3
        B       ptr_iconbar_icon

01
        Abs     R14,r3
        LDR     r3,[r14,#w_taskhandle]
        Push    "R14"
        Task    r3
        Pull    "R14"

ptr_iconbar_icon
        LDR     R14,[R14,#w_icons]
        ADD     R14,R14,R4,ASL #i_shift ; Point at the icon.
        LDR     r3,[r14,#i_flags]
        TST     r3,#if_text
        TSTNE   r3,#if_indirected       ; Is it indirected text ?
        BEQ     %FT90

        MOV     r2,#WimpValidation_Pointer
        LDR     r3,[r14,#i_data+4]      ; Pointer to validation string.
        AcceptLoosePointer_NegOrZero r3,-1
        CMP     r3,r3,ASR #31
        BEQ     %FT90
        DebugS  bo,"Validation string is ",r3
        BL      findcommand
        BNE     %FT90

        ADRL    r2,pointer_sprite
        Debug   bo,"Copy Sprite name"
88
        LDRB    R14,[r3],#1
        CMP     R14,#","
        MOVEQ   R14,#-1
        CMP     R14,#";"
        MOVEQ   R14,#0
        CMP     R14,#" "
        STRGTB  r14,[r2],#1
        BGT     %BT88

        MOV     R4,#0                   ; Default active point is 0,0
        MOV     R5,#0
        STRB    R4,[r2]                 ; Terminate the sprite name.

        CMP     R14,#-1
        BNE     %FT02

        Debug   bo,"Sprite name copied"

        BL      getnumber
        MOV     R4,R0                   ; Returns 0 if not found.

        LDRB    R14,[R3],#1
        CMP     R14,#","
        BNE     %FT02
        BL      getnumber
        MOV     R5,R0                   ; Returns 0 if not found.

        [ debugbo
         ADRL    r2,pointer_sprite
         DebugS  bo,"Sprite name is :",r2
        ]
02
        MOV     R0,#SpriteReason_SetPointerShape
        ADRL    R2,pointer_sprite
        MOV     R3,#1
      [ Autoscr
        LDR     R14, autoscr_state      ; don't reprogram pointer if autoscrolling is enabled
        TST     R14, #af_enable
        ORRNE   R3, R3, #&10
      ]
        MOV     R6,#0
        MOV     R7,#0
        SWI     XWimp_SpriteOp          ; take from Wimp's sprite area(s)
        MOV     R14,#-1
        ADRL    R1,special_pointer
        STR     R14,[r1]
        B       %FT91
90
        ADRL    R1,special_pointer
        LDR     R14,[R1]
        CMP     R14,#0
        MOVNE   R14,#0
;        ADRNEL  R1,special_pointer
        STRNE   R14,[r1]
        MOVNE   R3,#1
        BLNE    doubleptr_off
91
        Pull    "r0-r7,handle"
92

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; if icon changes while drag pending, return code now!

        LDR     R14,pending_window      ; if icon changes while drag pending
        TEQ     R3,R14                  ; do it now!
        LDREQ   R14,pending_icon
        TEQEQ   R4,R14
        LDRNE   R7,mouseflags
        TSTNE   R7,#mf_waitdrag
        ORRNE   R7,R7,#mf_oldcoords     ; avoid missing clicks

        BNE     waitdrag_action         ; pre-emptive strike!

      [ Autoscr
; do we need to do something about autoscrolling?
        LDR     R14, autoscr_state
        TST     R14, #af_enable
        BLNE    poll_autoscroll         ; may or may not return, preserves flags if it does
        BNE     %FT01                   ; don't scroll icon bar if scrolling something else!
      ]

; if in iconbar, check whether we should scroll automatically

 [ false
        LDR     R14,iconbarhandle
        CMP     R14,#nullptr
        BEQ     %FT01                   ; no iconbar
        TEQ     R3,R14
        BNE     %FT01                   ; this isn't it!
;
        LDR     R14,scrx0
        ADD     R14,R14,#iconbarsepgap
        CMP     R0,R14
        MOVLT   R8,#-16                 ; scroll left
        BLT     %FT02
        LDR     R14,scrx1
        SUB     R14,R14,#iconbarsepgap
        CMP     R0,R14
        MOVGT   R8,#16                  ; scroll right
        BLE     %FT01
02
        Push    "R0-R8,handle,userblk"
        Abs     handle,R3
        BL      calc_w_status           ; ensure bhandle is correct
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{R1-R7}             ; x0,y0,x1,y1,scx,scy,bhandle
        LDR     R8,[sp,#8*4]
        ADD     R5,R5,R8                ; add in appropriate offset
        LDR     R0,iconbarhandle
        Push    "R0,R1-R7"              ; first word is window handle
        MOV     userblk,sp
        BL      int_open_window
        ADD     sp,sp,#4*8              ; handle,x0,y0,x1,y1,scx,scy,bhandle
        Pull    "R0-R8,handle,userblk"
  |
        LDR     R14,iconbarhandle
        CMP     R14,#nullptr
        BEQ     %FT01                   ; no iconbar
        TEQ     R3,R14
	MOVNE	R14,#0
	STRNE	R14,iconbar_scroll_start_time
        BNE     %FT01                   ; this isn't it!
;
        LDR     R14,scrx0
        ADD     R14,R14,#iconbarsepgap
        CMP     R0,R14
        LDRLT   R8, iconbar_scroll_speed
        MVNLT   R8, R8 ; ensure msb set                        ; scroll left
        BLT     %FT02
;
        LDR     R14,scrx1
        SUB     R14,R14,#iconbarsepgap
        CMP     R0,R14
	MOVLE	R14,#0
	STRLE	R14,iconbar_scroll_start_time
        BLE     %FT01
        LDRGT   R8, iconbar_scroll_speed                       ; scroll right
02
        Push    "R0-R8,handle,userblk"
        Abs     handle,R3
        BL      calc_w_status           ; ensure bhandle is correct
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{R1-R7}             ; x0,y0,x1,y1,scx,scy,bhandle
        LDR     R8,[sp,#8*4]

	SWI	XOS_ReadMonotonicTime
	LDR	R14,iconbar_scroll_start_time
	TEQ	R14,#0
	STREQ	R0,iconbar_scroll_start_time
	STREQ	R5,iconbar_scroll_start_scx
	BEQ	%FT04
	; The following formula gives speed = iconbar_scroll_speed+iconbar_scroll_accel * time
	Push	"R2"
	LDR	R5,iconbar_scroll_start_scx
	LDR	R2,iconbar_scroll_start_time
	SUB	R2,R0,R2		; R2=time since scroll start (in centi-seconds)
	CMP     R2, #&3800              ;; much more than this, and accel*time^2 will overflow
	MOVHI   R2, #&3800              ;; when maximum acceleration is configured
	LDR	LR, iconbar_scroll_accel
	MUL	LR,R2,LR		; LR=accel * time (cs)
	MOV     LR, LR, ASR#6
	ADD     LR, LR, LR, ASR#2       ; LR=accel * time (s) (within 3%)
	CMP	R8,#0
	ADDGE	R8,R8,LR
	SUBLT	R8,R8,LR		; R8=(+/-)(speed + accel*time)
	ADDLT   R8, R8, #1              ; adjust because we used NOT(speed) rather than -(speed) for velocity
	MUL	R8,R2,R8		; R8=(+/-)(speed + accel*time) * time (cs)
	ADD     R8, R8, R8, ASR#2
	ADD	R5,R5,R8,ASR #6		; R5+=(+/-)(speed + accel*time) * time (s)
	Pull	"R2"

        LDR     R0,iconbarhandle
        Push    "R0,R1-R7"              ; first word is window handle
        MOV     userblk,sp
        BL      int_open_window
        ADD     sp,sp,#4*8              ; handle,x0,y0,x1,y1,scx,scy,bhandle
04
        Pull    "R0-R8,handle,userblk"
  ]
01

; if dragging, treat as window -1 (do this after iconbar scrolling)

        LDR     R14,dragtype            ; avoid ptr_changing events
        TEQ     R14,#0
        TEQNE   R14,#drag_subr_posn2
        TEQNE   R14,#drag_subr_size2
        MOVNE   R3,#nullptr

; Ptr_Entering/Leaving_Window treats system area as window -1

        Push    "R3"                    ; actual window handle
      [ Autoscr
; also treat as window -1 (but just for the purposes of Pointer Leaving/Entering Window events) if
; we're autoscrolling (which is not necessarily a subset of if dragging)
        LDR     R14, autoscr_state
        TST     R14, #af_enable
        MOVNE   R3, #nullptr
      ]
        LDR     R14,iconbarhandle
        TEQ     R3,R14                  ; treat as window handle -1:
        LDRNE   R14,backwindow          ; (a) if in back window
        TEQNE   R3,R14
        LDRNE   R14,backwindowhandle    ;     (either of them)
        TEQNE   R3,R14
        CMPNE   R4,#nullptr2            ; (b) if in iconbar window
        MOVEQ   R3,#nullptr             ; (c) if in system area
        LDR     R14,ptrwindow
        CMP     R3,R14                  ; same window?
        Pull    "R3",EQ                 ; actual window handle
        BEQ     cantchange
        Debug   ptr,"pointer new,old",R3,r14


;
; if old window not null, return 'leaving window', and set ptrwindow to null
; otherwise set ptrwindow to new window, and return 'entering window'
; in both cases set mf_oldcoords bit.
;
        Push    "R0"                    ; now R0,R3 on stack
        CMP     R14,#nullptr
        BEQ     entering
leaving
        MOV     R8,R14                  ; old handle
        LDR     R9,ptrtask              ; old task

        CMP     R9,#nullptr
        LDRNE   R14,[wsptr,R9]          ; Check if old task is dead
        TSTNE   R14,#task_unused        ; If so, just return 'entering window'
        BEQ     %FT01
        CMP     R3,#nullptr             ; Unless new window is null !!
        BNE     entering                ;
        STR     R3,ptrwindow
        Pull    "r0,r3"
        B       cantchange
01
        MOV     R3,#nullptr             ; set ptrwindow to null
        MOV     R0,#Pointer_Leaving_Window
        MOV     R14,#ptrleaving_bit
        B       ptrboth

entering
        Abs     handle,R3
        LDR     R9,[handle,#w_taskhandle]

        MOV     R8,R3                   ; new handle
        MOV     R0,#Pointer_Entering_Window
        MOV     R14,#ptrentering_bit

ptrboth
        STR     R3,ptrwindow
;
        Push    "R14"
        CMP     R3,#nullptr          ; if ptrwindow not null, task is relevant
        Abs     handle,R3,NE
        LDRNE   R14,[handle,#w_taskhandle]
        STRNE   R14,ptrtask             ; not nec. same as taskhandle
        Pull    "R14"
;
        CMP     R9,#0                   ; if this is a menu or a system window
        Pull    "R0,R3",LE
        BLE     cantchange              ; ignore it!
;
        Push    "R14"
        Task    R9,,"PtrWindow"
        MOV     R9,R14                  ; get flag word
        Pull    "R14"

        TST     R9,R14                  ; see if relevant bit is set
        STREQ   R0,[sp]                 ; keep 'action' flag
        Pull    "R0,R3"
        BNE     cantchange              ; user isn't interested!
;
        LDR     R14,mouseflags
        ORR     R14,R14,#mf_oldcoords
        STR     R14,mouseflags           ; use same values again!
;
        STR     R8,[userblk]            ; R0 = reason code already
        B       ExitPoll


;;----------------------------------------------------------------------------
;; Check for interesting mouse clicks
;;   -  depends on 'button type' of relevant icon
;;----------------------------------------------------------------------------

;
; button attributes
;

ibb_notpressed  *       2_000000000001
ibb_select      *       2_000000000010
ibb_writeable   *       2_000000000100      ; for writeable icons
ibb_canreport   *       2_100000000000

ibb_waitrepeat  *       2_000000001000
ibb_waitclick   *       2_000000010000
ibb_waitdrag    *       2_000000100000
ibb_waitrelease *       2_000001000000
ibb_wait2clicks *       2_000010000000
ibb_waitremove  *       2_000100000000
ibb_pending     *       2_000111111000
ibb_report5     *       2_001000000000
ibb_report6     *       2_010000000000

ibb_justselect  *       ibb_pending :AND: (:NOT:ibb_waitdrag)

bb_setflags     *       3               ; bit number of pending flags


buttonattributes
        DCD     2_000000000000  ; 0 never report
        DCD     2_100000000001  ; 1 always report
        DCD     2_100000001000  ; 2 report if button clicked (auto-repeat)
        DCD     2_100000000000  ; 3 report if button clicked
        DCD     2_100101000010  ; 4 select if clicked, report if released
        DCD     2_100010000010  ; 5 select if clicked, report if 2 clicks
        DCD     2_100000100000  ; 6 as for (3), but can also drag
        DCD     2_100001100010  ; 7 as for (4), but can also drag
        DCD     2_100010100010  ; 8 as for (5), but can also drag
        DCD     2_100100010011  ; 9 select always, report if clicked
        DCD     2_101010100010  ;10 report 1 or 2 clicks (:SHL:8 if 1 click)
        DCD     2_100000100010  ;11 as (8), but select+notify on single click
        DCD     2_110010100010  ;12
        DCD     2_100010000000  ;13
        DCD     2_100000100100  ;14 writeable, but also report as for (6)
        DCD     2_000000000100  ;15 writeable icon (don't report)

        ALIGN

; R0,R1 = mouse coords (absolute)
;    R2 = mouse button state
; R3,R4 = actual window/icon handles (R3 not forced to -1 for background)

cantchange
        LDR     R14,dragtype
        TEQ     R14,#0
        TEQNE   R14,#drag_subr_posn2
        TEQNE   R14,#drag_subr_size2
        BNE     trykeys                 ; don't recognise any other buttons
;
        BL      scanmenus               ; preserves task if it returns here
        BVS     ExitPoll
;
; window handle can come back -1 if we clicked on a greyed-out menu item
;
        CMP     R3,#nullptr             ; should only happen for grey menu items
        BEQ     trykeys
;
; translate icon -2 to appropriate system icon handle
;
        CMP     R4,#nullptr2            ; in system area?
        BNE     %FT01

        BL      setwimpicon             ; set up R4 and R5
        B       gotbttype
;
; obtain 'button type' of user icon
;
01      CMP     R4,#nullptr
        LDREQ   R5,[handle,#w_workflags]; look up work area button type
        LDRNE   R5,[handle,#w_icons]
        ADDNE   R5,R5,#i_flags
        LDRNE   R5,[R5,R4,ASL #i_shift] ; R5 = flag word
;
; always report the menu button unless in border region
;

gotbttype
        CMP     R4,#nullptr2
        BLE     issystemarea
        LDR     R14,oldbuttons
        BIC     R14,R2,R14
        TST     R14,#button_middle      ; look for +ve edge of MENU button
        BNE     justtellhim
        BIC     R2,R2,#button_middle    ; pretend it's off!

issystemarea

;
; for select and adjust, check the button type
;
        AND     R14,R5,#if_buttontype           ; use field as index offset
        MOVS    R14,R14,LSR #ib_buttontype
        ADR     R6,buttonattributes
        LDR     R6,[R6,R14,ASL #2]              ; R6 = internal flag word
        LDR     R7,mouseflags                   ; R7 = mouse flags
        LDR     R8,oldbuttons                   ; R8 = old button state

; R0,R1 => x,y mouse co-ordinates
; R2 => button state
; R4 => icon handle
; R6 => button attributes
; R7 => mouse flag
; R8 => old button state
; handle => internal window handle

        Push    "R0-R2,handle"
;
        BL      modifytool                      ; attempt to handle window tools changing (when possible)
;
        TST     R2,#button_left+button_right
        BNE     %FT01                           ; if not released then ignore
;
        ASSERT  nullptr = windowicon_workarea
;
        LDR     R0,border_iconselected          ; may have changed!
        CMP     R0,#windowicon_workarea
        BLE     %FT01                           ; if -VE then ignore its not worth the hassle
;
        MOV     R1,#0
        MOV     R2,#is_inverted
        LDR     handle,border_windowselected
        BL      int_set_icon_state              ; modify the tool icon
;
        MOV     R0,#nullptr
        STR     R0,border_iconselected
        STR     R0,border_windowselected        ; flag as no icon / window selected
01
        Pull    "R0-R2,handle"
;
; cancel certain pending actions if icon has changed
;
        LDR     R14,pending_window
        TEQ     R3,R14
        LDREQ   R14,pending_icon
        TEQEQ   R4,R14
        BEQ     sameicon
;
        TST     R7,#mf_waitremove               ; cancel previous icon
        BEQ     dontpratabout
        Push    "R0,R4,handle"
        LDR     handle,pending_window
        BL      checkhandle                     ; IGNORE errors!
        LDRVC   R4,pending_icon
        BLVC    deselecticon
        Pull    "R0,R4,handle"                  ; V cleared lower down

dontpratabout
        TST     R7,#mf_wait2clicks              ; reset pointer shape if nec.
        BLNE    doubleptr_off
        BIC     R7,R7,#mf_pendingexceptdrag     ; cancel pending (except drag)
        STR     R7,mouseflags
;
sameicon
        TST     R7,#mf_waitdrag
        BLNE    waitdrag                        ; may or may not return here
        TST     R7,#mf_waitrelease
        BNE     waitrelease
        TST     R7,#mf_wait2clicks
        BNE     wait2clicks
        TST     R7,#mf_waitclick
        BNE     waitclick
        TST     R7,#mf_waitrepeat
        BNE     waitrepeat
;
testbutton
        CMP     R3,#nullptr             ; can't have select or adjust here!
        BEQ     trykeys
;
        BIC     R2,R2,R8                ; look for +ve edges
;
        TST     R6,#ibb_notpressed      ; unless notpressed, check key is down
        TSTEQ   R2,#button_left:OR:button_middle:OR:button_right
        BEQ     trykeys
;
; icon responds - set up appropriate pending flags
;
        AND     R14,R6,#ibb_pending
        BIC     R7,R7,#mf_pending
        ORR     R7,R7,R14,LSL #mfb_setflags-bb_setflags  ; set up mouseflags
        STR     R7,mouseflags

        TST     R14,#ibb_waitrepeat
        BLNE    getfx12                 ; get auto-repeat settings
        LDRNEB  R14,repeatdelay
        STRNEB  R14,repeatlimit
;
        LDR     R14,timeblk             ; go!
        STR     R14,pending_time
;
        ADR     R14,pending_x
        STMIA   R14,{R0-R4}             ; saves x,y,buttons,window,icon

; change pointer shape for double-clicks to help wally users

        TST     R7,#mf_wait2clicks
        BLNE    doubleptr_on            ; if current shape = 1, set double ptr

; see if the icon reports back, or is just selected

        TST     R6,#ibb_writeable       ; special code for writeable icons
        BLNE    clickonwriteable        ; will return here
        TST     R6,#ibb_canreport
        BEQ     trykeys                 ; type 15 is writeable but can't report
        TST     R6,#ibb_select
        BEQ     justtellhim             ; report direct to the user!
        TST     R6,#ibb_report5         ; report 1 click as well
        MOVNE   R2,R2,LSL #8            ; shift up by 8 bits
        BNE     justtellhim
        TST     R6,#ibb_report6
        BNE     trykeys                 ; don't tell him!
;
; implicit selection takes place (don't tell the user!)
;
        CMP     R4,#nullptr             ; don't select work or system area
        BLGT    selecticon              ; take note of ESG's etc.
;
        TST     R6,#ibb_justselect      ; if no pending actions,
        BEQ     justtellhim             ; notify the user AS WELL as selecting
;
        TST     R6,#ibb_waitclick       ; button could go down AT THE SAME TIME
        BICNES  R14,R2,R8               ; as the pointer enters the icon!
        BNE     justtellhim
;
        B       trykeys

;
; check for pending icon
;

waitrelease
        TST     R2,#button_left:OR:button_middle:OR:button_right
        BICEQ   R7,R7,#mf_waitrelease
        STREQ   R7,mouseflags
        LDREQ   R2,pending_buttons      ; remember original button press
        BEQ     justtellhim
        B       trykeys                 ; keep waiting!

wait2clicks

; new version changes the pointer shape during the double-click period

        LDRB    R5,doubleclick_movelimit
        BL      checkpointermoved       ; sets C if pointer moved too far

        LDR     R5,doubleclick_timelimit
        BLCC    pendingtime             ; preserves flags
        CMPCC   R14,R5
        BCS     %FT01                   ; too late!

        BICS    R2,R2,R8                ; doesn't affect C flag
        BEQ     testbutton

        LDR     R14,pending_buttons     ; can't double-click with different buttons
        TST     R2,R14
        CMPEQ   R2,R2                   ; set C => don't do the double-click
01
        BIC     R7,R7,#mf_wait2clicks
        STR     R7,mouseflags

        BL      doubleptr_off           ; preserves flags
        BCS     testbutton              ; CS: don't do the double-click
        B       justtellhim             ; CC: do the double-click

; In    R0,R1 = current mouse position
;       R5 = movement limit (OS units)
;       [pending_x/y] = mouse position when initial click occurred
; Out   CS => mouse has moved away from that position

checkpointermoved

        Push    "R6,LR"
        LDR     R14,pending_x           ; get chicago dist. from orig. point
        SUBS    R14,R14,R0
        RSBMI   R14,R14,#0
        LDR     R6,pending_y            ; R5 not used any more
        SUBS    R6,R6,R1
        RSBMI   R6,R6,#0
        ADD     R6,R6,R14
        CMP     R6,R5
        Pull    "R6,PC"                 ; CS => pointer has moved away

waitclick
        BICS    R14,R2,R8
        BEQ     testbutton              ; not interested
        B       justtellhim

waitrepeat
        LDR     R14,pending_buttons
        TST     R2,R14                  ; still held down?
        BICEQ   R7,R7,#mf_waitrepeat
        STREQ   R7,mouseflags
        BEQ     testbutton
;
        BL      pendingtime
        Push    "R2"
        LDRB    R2,repeatlimit
        CMP     R14,R2
        Pull    "R2"
        BCC     trykeys                 ; still waiting
;
        LDR     R14,timeblk             ; reset timer
        STR     R14,pending_time
        BL      getfx12
        LDRB    R14,repeatrate          ; different delay this time!
        STRB    R14,repeatlimit
        MOV     R14,#1
        STRB    R14,autorepeating
        B       justtellhim             ; return button press

getfx12
        Push    "R0-R2,LR"
        MOVNE   R0,#&C4
        MOVNE   R1,#0
        MOVNE   R2,#&FF
        SWINE   XOS_Byte
        STRNEB  R1,repeatdelay
        STRNEB  R2,repeatrate
        Pull    "R0-R2,PC"

waitdrag
        Push    "LR"
;
        TST     R2,#button_left:OR:button_middle:OR:button_right
        BICEQ   R7,R7,#mf_waitdrag      ; button released!
        STREQ   R7,mouseflags
        Pull    "PC",EQ
;
        LDRB    R5,drag_movelimit
        BL      checkpointermoved       ; CS => pointer has moved
        BLCC    pendingtime             ; can't return an error
        LDRCC   R5,drag_timelimit
        CMPCC   R14,R5
        Pull    "PC",CC                 ; still waiting
        Pull    "LR"                    ; drop through
;
; This code is also called from higher up, if the window/icon have changed
; Entry:  R7 = current mouseflags
; Exit:   drag buttons reported to the application
;
waitdrag_action
        BL      mousetrap               ; buttons haven't changed
;
        BIC     R7,R7,#mf_waitdrag      ; don't cancel others!
        STR     R7,mouseflags
        ADR     R14,pending_x
        LDMIA   R14,{R0-R4}
        STR     R0,mousexpos            ; to fool Drag_Box if called
        STR     R1,mouseypos
        MOV     R2,R2,ASL #4            ; 'alias' to different buttons
                                        ; drop through

;-----------------------------------------------------------------------------
; Return mouse buttons to the user
; Entry:  R0,R1 = mouse x,y coords
;         R2 = mouse buttons:

;              bits 0-3  = normal response    (depends on button type)
;              bits 4-7  = 'drag' operation   (button held down)
;              bits 8-11 = 'select' operation (ie. 1 click if it's that type)
;         R3,R4 = window/icon handles (-1 if none)
; Exit:   data put into [userblk], and Mouse_Click returned
;-----------------------------------------------------------------------------

justtellhim
        CMP     R4,#nullptr2
        BLE     wimpaction              ; click in system area
;
; if R3 is really -1, then we shouldn't return it to anyone
; (menu clicks on background only work in single-tasking mode)
;
        LDR     R14,backwindowhandle    ; this counts as the background too!
        CMP     R3,R14
        CMPNE   R3,#nullptr
        BEQ     repollwimp
;
; page in correct task (again) - R3 may be changed by waitdrag
;
        LDR     R14,iconbarhandle
        CMP     R14,#nullptr            ; don't do this if no iconbar!
        BEQ     notiniconbar
        TEQ     R3,R14
        BNE     notiniconbar
;
        Push    "R0-R4"                 ; save mouse data!
        BL      findicon                ; finds icon R4 in iconbar
        LDREQ   R14,[R2,#icb_taskhandle]
        Task    R14,EQ,"IconBar"
        Pull    "R0-R4"
        BNE     repollwimp              ; unrecognised!
        MOV     R3,#nullptr2            ; return window handle -2 for iconbar
        B       returnclick
;
; ensure that correct task is paged in
; NB ptrwindow may not be the same as R3 (eg. drag button activates later)
;
notiniconbar
        CMP     R3,#nullptr
        BEQ     repollwimp              ; window has been deleted!!!
        Abs     handle,R3
        LDR     R14,[handle,#w_taskhandle]
        Task    R14,,"ReturnClick"
;
        LDR     R14,flagword
        TST     R14,#buttonchange_bit
        BNE     trykeys
;
; if backwindow, pretend it's really window -1
;
        LDR     R14,backwindow
        TEQ     R3,R14
        MOVEQ   R3,#nullptr             ; (for menu clicks in singletask mode)
;
        CMP     R3,#nullptr             ; is it a real window?
        BEQ     %FT10                   ; if not then icon
;
        CMP     R4,#0
        BMI     %FT10                   ; if its the background then ignore it
;
	TST	R2,#button_middle	; ignore menu clicks for slabbing
	BNE	%FT10

        Push    "R0-R3"

; R3 = window handle / handle => window defn ( <= 0 if none )
; R4 = icon handle

        LDR     R14,[handle,#w_icons]
        ADD     R14,R14,R4,LSL #i_shift ; R14 -> icon defn
;
        LDR     R1,[R14,#i_flags]
        LDR     R3,[R14,#i_data+4]      ; get flags, -> validation string
      [ true
        AND     R14, R1, #if_buttontype ; border_icon/windowselected behaviour is only suitable for a few button types
        MOV     R14, R14, LSR #ib_buttontype
        TEQ     R14, #ibt_autorepeat
        TEQNE   R14, #ibt_click
        TEQNE   R14, #ibt_clickrelease
        TEQNE   R14, #ibt_click2
        TEQNE   R14, #ibt_dclick
        TEQNE   R14, #ibt_dclickrelease
        TEQNE   R14, #ibt_dclick2
        BNE     %FT03
      ]
        BL      getborder               ; decode to setup the border information
;
        TEQ     R0,#border_action
        TEQNE   R0,#border_defaultaction
	BNE	%FT03
;
	LDR	R14,border_windowselected    ; Make sure previous selected icon
	CMP	R14,#nullptr                 ; is unslabbed
	BEQ	%F1
	TEQ	R14,handle
	LDR	R0,border_iconselected
	CMP	R0,#nullptr
	BLE	%F1
	TEQ	R0,R4
	TEQEQ	R14,handle
	BEQ	%F2
	Push	"handle"
	MOV	handle,R14
	MOV	R1,#0
	MOV	R2,#is_inverted
	BL	int_set_icon_state
	Pull	"handle"

1       STR     handle,border_windowselected
        STR     R4,border_iconselected
;
2       LDRB    R0,autorepeating
        CMP     R0,#0
3       MOVNE   R0,#0
        STRNEB  R0,autorepeating
	BNE	%F5

        MOV     R0,R4                   ; R1 => icon handle
        MOV     R1,#is_inverted
        MOV     R2,#0
        BL      int_set_icon_state      ; and then select the icon
;
5
        Pull    "R0-R3"
10
;
; to ensure that Message_MenusDeleted arrives before the next click,
; send mouse clicks as messages if the message queue is not empty
;

returnclick
        LDR     R14,oldbuttons
        STMIA   userblk,{R0,R1,R2,R3,R4,R14}
        MOV     R0,#Mouse_Click

        LDR     R14,headpointer
        CMP     R14,#nullptr
        BEQ     ExitPoll                ; return directly for efficiency

        MOV     R1,userblk
        LDR     R2,taskhandle
        BL      int_sendmessage_fromwimp
        B       repollwimp              ; deliver outstanding messages


;----------------------------------------------------------------------------
; Check for a key press
;----------------------------------------------------------------------------

trykeys
        Debug   poll2, "Processing keys"
 [ UTF8
        ; First, check if caret task is queueing keypresses for later handling
        LDR     handle, caretdata + 0
        CMP     handle, #nullptr
        BEQ     %FT11                   ; still read character (may be hot!)
        BL      checkhandle             ; check it hasn't been deleted!
        MOVVS   handle, #nullptr
        STRVS   handle, caretdata + 0   ; if deleted, turn it off
        BVS     %FT11

        LDR     R14, [handle, #w_taskhandle]
        CMP     R14, #0
        LDRMI   R14, menutaskhandle
        LDR     R14, [wsptr, R14]
        LDR     R14, [R14, #task_flagword]
        TST     R14, #keypress_bit
        BNE     nothing                 ; queue for later handling
11

        ; See if we're in the middle of a multi-byte external key event
        LDRB    R14, keyout_buflen
        TEQ     R14, #0
        BEQ     trykeys_getinternalkeycode
        ADRL    R1, keyout_buffer
        LDRB    R6, [R1]                ; next byte to process
        ADD     R2, R1, R14
01      LDRB    R0, [R1, #1]            ; copy the other bytes down
        STRB    R0, [R1], #1
        CMP     R1, R2
        BLO     %BT01
        SUB     R14, R14, #1            ; decrement byte count
        STRB    R14, keyout_buflen

        LDR     R14, singletaskhandle
        CMP     R14, #nullptr
        BLEQ    topmost_window
        STREQ   R0, hotkeyptr           ; initialise hotkey system, unless we're single-tasking
        ADRL    R14, savedcaretdata     ; get caret data
        LDMIA   R14, {R0-R5}
        CMP     R0, #nullptr            ; is there a caret?
        BNE     %FT02
        BL      int_processkey          ; if not, send hotkey
        B       repollwimp              ; (no need to check if single-tasking, as we won't get here otherwise)
02      MOV     handle, R0
        BL      checkhandle             ; check savedcaret window hasn't been deleted
        MOVVS   R0, #0
        STRVSB  R0, keyout_buflen       ; if it has (!) then delete continuation byte queue
        BVS     trykeys                 ; and restart key processing
        LDR     R14, [handle, #w_taskhandle]
        CMP     R14, #0
        LDRMI   R14, menutaskhandle
        Task    R14,, "KeyPressed continuation"
        STMIA   userblk, {R0-R6}
        MOV     R0, #Key_Pressed
        B       ExitPoll                ; return Key_Pressed event

trykeys_getinternalkeycode
        ; Get the next "key" from the expanded function key (if applicable)
        ADR     R5, keystring_buffer
        ADRL    R7, keystring_buflen
        BL      get_internal_keycode_from_buffer
        CMP     R6, #-1                 ; was there one?
        BNE     trykeys_gotinternalkeycode

        ; Get the next task-generated key
        ADR     R5, keyprocess_buffer
        ADRL    R7, keyprocess_buflen
        BL      get_internal_keycode_from_buffer
        CMP     R6, #-1                 ; was there one?
        BNE     trykeys_gotinternalkeycode

        ; Fill our keyboard input buffer from kernel keyboard buffer (needed so we can look ahead)
        LDRB    R3, keyin_buflen
        ADRL    R5, keyin_buffer
      [ true
        MOV     R0, #&81                ; OS_Byte 129 (INKEY)
        MOV     R1, #0
        MOV     R2, #0                  ; time limit 0
        SWI     XOS_Byte
        TEQ     R2, #&FF
        BEQ     %FT02                   ; break if no byte available
        STRB    R1, [R5, R3]            ; stick byte in my buffer
        ADD     R3, R3, #1
        TEQ     R1, #0                  ; null byte (=> either a null or a function key) ?
        MOVEQ   R7, #2
        BEQ     %FT01
        BL      read_current_alphabet
        BNE     %FT02                   ; except in UTF-8, all chars are one byte
        MOV     R0, R1
        BL      estimate_UTF8_char_len  ; may return length 0, but that's okay because we've already read one byte
        MOV     R7, R1
01      CMP     R3, R7
      |
01      CMP     R3, #6
      ]
        BHS     %FT02                   ; break from loop if full
        MOV     R0, #&81                ; OS_Byte 129 (INKEY)
        MOV     R1, #0
        MOV     R2, #0                  ; time limit 0
        SWI     XOS_Byte
        TEQ     R2, #&FF
        BEQ     %FT02                   ; break if no byte available
        STRB    R1, [R5, R3]            ; stick byte in my buffer
        ADD     R3, R3, #1
        B       %BT01
02      STRB    R3, keyin_buflen

        ; Get a key from our input buffer
        ADRL    R7, keyin_buflen        ; R5 already set up
        BL      get_internal_keycode_from_buffer
        CMP     R6, #-1                 ; was there one?
        BEQ     nothing                 ; no keys to handle

trykeys_gotinternalkeycode
        ; *All* Key_Pressed events now return caretdata as it is at this time
        ; - ie. before the writable icon handling messes around with it.
        ; This saves on the horrible kludge of storing the Key_PressedOldData
        ; event number in order to specify where to get the caret data from.
        Push    "R0-R5"
        ADR     R14, caretdata
        LDMIA   R14, {R0-R5}
        ADRL    R14, savedcaretdata
        STMIA   R14, {R0-R5}
        Pull    "R0-R5"

        ; Page in correct task
        CMP     handle, #nullptr
        BEQ     %FT01
        LDR     R14, [handle, #w_taskhandle]
        CMP     R14, #0
        LDRMI   R14, menutaskhandle
        Task    R14,, "KeyPressed"
01

        ; KeyboardMenus gets a look in first
      [ KeyboardMenus
        LDR     R4, menuSP
        CMP     R4, #0
        BLT     %FT00                   ; no menu open so don't grab special keys

        ADR     R5, menudata            ; if it's a dbox then don't grab keys
        LDR     R5, [R5, R4]
        TST     R5, #3
        BNE     %FT00

        ADR     R14, menuhandles        ; if menu has caret then don't grab keys
        LDR     R14, [R14, R4]
        LDR     R0, menucaretwindow
        TEQ     R0, R14
        BEQ     %FT00

        TEQ     R6, #13                 ; check for return and cursor keys
        BEQ     handlemenukey
        TST     R6, #1:SHL:31
        BEQ     %FT00
        BIC     R14, R6, #1:SHL:31
        TEQ     R14, #&8C
        TEQNE   R14, #&8D
        TEQNE   R14, #&8E
        TEQNE   R14, #&8F
        SUBEQ   R6, R14, #(&8C-136)     ; map onto range 136-139
        BEQ     handlemenukey
00
      ]

        ; Handle escape keypresses
        TEQ     R6,#&1B                 ; escape?
        BNE     %FT02
      [ KeyboardMenus
        CMP     r4, #0                  ; if no menu open then skip
        BLT     %FT02
        TST     r5, #3                  ; check for dialogue
        SUBNE   r0, r4, #4              ; if dialogue open then just remove it
        MOVEQ   r0, #-4                 ; otherwise remove whole menu tree
        CMP     r0, #0
        BLLT    menusdeleted            ; send Message_MenusDeleted if whole menu going (preserves r0)
        BL      closemenus
      |
        LDR     R0,menuSP
        CMP     R0,#0
        BLT     %FT02

        BL      menusdeleted            ; send Message_MenusDeleted
        MOVVC   R0,#-4
        BLVC    closemenus
      ]
        BVC     nothing                 ; absorb escape if used to close menus
        B       ExitPoll                ; report error if any

02      ; Examine caret state to determine what to do with keypress
        ADRL    R14, savedcaretdata
        LDMIA   R14, {R0-R5}
        CMP     R0, #nullptr
        BEQ     tryhotkeys              ; no input focus
        CMP     R1, #nullptr
        BNE     processkey              ; wimp gets first bash at this one!

keypressed
; Return a Key_Pressed event to the caret-owning task
        BL      prepare_external_key_event
        STMIA   userblk, {R0-R6}
        MOV     R0,#Key_Pressed         ; task handle already set up
        B       ExitPoll

tryhotkeys
; Initiate hotkey chain of events
        BL      prepare_external_key_event
        MOVGT   R0, #0
        STRGTB  R0, keyout_buflen       ; don't cache the other bytes if we're single-tasking!
        BLLE    int_processkey
        B       repollwimp


; Support routines for the above

prepare_external_key_event
; Munges internal keycode back into UTF-8 / external keycode format, and initialises hotkey system
; Entry: R6 = internal key code
; Exit:  R6 = first external key code
;        keyout_buffer filled with any remaining external keycodes
;        hotkeyptr set up (unless we're not multitasking)
;        LE => we are multitasking
        Entry   "R0,R4,R5"
        TST     R6, #1:SHL:31           ; was it a function key?
        ANDNE   R6, R6, #&FF
        ORRNE   R6, R6, #&100           ; convert into external form if so
        BNE     %FT01

        BL      read_current_alphabet   ; are we in UTF-8 alphabet?
        ANDNE   R6, R6, #&FF
        BNE     %FT01                   ; return bottom byte if not

        SUB     sp, sp, #8
        MOV     R5, sp
        BL      convert_UCS4_to_UTF8
        LDRB    R6, [sp]                ; first byte
        SUB     R4, R4, #1
        STRB    R4, keyout_buflen       ; held-over byte count
        ADD     R14, R5, R4             ; -> last byte in sequence
        ADRL    R4, keyout_buffer
02      LDRB    R0, [R5, #1]!
        STRB    R0, [R4], #1
        CMP     R5, R14
        BLO     %BT02
        ADD     sp, sp, #8

01      LDR     R14, singletaskhandle
        CMP     R14, #nullptr
        BLEQ    topmost_window          ; if we're multitasking, get top window handle
        STREQ   R0, hotkeyptr           ; and store it as the first hotkey window
        EXIT                            ; leave flags as they are

get_internal_keycode_from_buffer
; Reads a key from one of keyin_buffer, keyprocess_buffer or keystring_buffer,
; from a range appropriate to the current alphabet
; Skips any malformed characters
; Entry: R5 -> buffer
;        R7 -> buffer length byte
; Exit:  R6 = internal keycode : -1 means no character
;                                &800000xx represents a function key
;                                else character code ( <= &7FFFFFFF if UTF-8 alphabet, <= &FF otherwise )
        Entry   "R0-R4"
        LDRB    R3, [R7]                ; get buffer length
get_internal_keycode_restartpoint
        CMP     R3, #0                  ; nothing in my buffer?
        MOVLE   R6, #-1
        EXIT    LE

        LDRB    R6, [R5]
        TEQ     R6, #0                  ; first byte null => either a null or a function key
        BNE     get_internal_keycode_isntafunctionkey

get_internal_keycode_isafunctionkey
        TEQ     R3, #1                  ; if it's just one null byte, it's a malformed character
        MOVEQ   R4, #1
        MOVEQ   R6, #-1
        BEQ     get_internal_keycode_removefrombuffer

        LDRB    R6, [R5, #1]
        TEQ     R6, #0
        ORRNE   R6, R6, #1:SHL:31       ; unless a null, set top bit to indicate function key status
        MOV     R4, #2                  ; either way, it's a 2-byte character
        B       get_internal_keycode_removefrombuffer

get_internal_keycode_isntafunctionkey
        BL      read_current_alphabet
        MOVNE   R4, #1                  ; if not UTF-8, then it's got to be a valid 1-byte character
        BNE     get_internal_keycode_removefrombuffer

        MOV     R6, R5
        MOV     R4, R3
        BL      convert_UTF8_to_UCS4    ; sets up R4 and R6

get_internal_keycode_removefrombuffer
        ; R6 = internal Wimp key number, or -1 if malformed
        ; R4 = number of bytes of keyboard buffer it used
        SUB     R3, R3, R4              ; number of bytes that will still be in buffer after removal
        STRB    R3, [R7]
        ADD     R1, R5, R3              ; -> byte after final byte in buffer (after copying down)
        MOV     R2, R5                  ; rover
01      LDRB    R0, [R2, R4]
        STRB    R0, [R2], #1            ; copy down
        CMP     R2, R1
        BLO     %BT01

        CMP     R6, #-1                 ; was it a malformed character?
        BEQ     get_internal_keycode_restartpoint  ; swallow it if so!

        EXIT

 | ; else not UTF8...

 [ KeyboardMenus
        MOV     r6, #-1                 ; so we can tell later on if we read a key
        LDR     r4, menuSP
        CMP     r4, #0
        BLT     %FT00                   ; no menu open so don't grab special keys

        ADR     r5, menudata            ; if it's a dbox then don't grab keys
        LDR     r5, [r5, r4]
        TST     r5, #3
        BNE     %FT00

        ADR     r14, menuhandles        ; if menu has caret then don't grab keys
        LDR     r14, [r14, r4]
        LDR     r0, menucaretwindow
        TEQ     r0, r14
        BEQ     %FT00

        MOV     r0, #4                  ; allow us to read cursor keys
        MOV     r1, #1
        SWI     XOS_Byte
        MOV     r3, r1
        MOV     r0, #&81                ; INKEY(0)
        MOV     r1, #0
        MOV     r2, #0
        SWI     XOS_Byte
        MOV     r6, r1
        MOV     r7, r2
        MOV     r0, #4                  ; restore cursor key state
        MOV     r1, r3
        SWI     XOS_Byte
        CMP     r7, #&FF                ; was there a key?
        BEQ     nothing

        TEQ     r6, #13                 ; check for return and cursor keys
        TEQNE   r6, #136
        TEQNE   r6, #137
        TEQNE   r6, #138
        TEQNE   r6, #139
        BEQ     handlemenukey
 ]
00
        LDR     handle,caretdata+0
        CMP     handle,#nullptr
        BEQ     %FT01                   ; still read character (may be hot!)
;
        BL      checkhandle             ; check it hasn't been deleted!
        MOVVS   handle,#nullptr
        STRVS   handle,caretdata+0      ; if deleted, turn it off
        BVS     %BT00
;
        LDR     R14,[handle,#w_taskhandle]
        CMP     R14,#0
        LDRMI   R14,menutaskhandle

        LDR     R14,[wsptr,R14]
        LDR     R14,[R14,#task_flagword]
        TST     R14,#keypress_bit
        BNE     nothing                 ; temporarily disabled

01
 [ KeyboardMenus
        CMP     r6, #0
        BGE     %FT22
        BL      inkey0                  ; if we don't have a key yet then get one
        MOVS    r6, r1
22
 |
        BL      inkey0                  ; may branch elsewhere
        MOVS    R6,R1                   ; actual key value
 ]
        BNE     %FT01
        BL      inkey0                  ; may branch elsewhere!
        MOVS    R6,R1
        ADDNE   R6,R6,#&100             ; add &100 to the value (unless 0)
01
        LDR     R14,caretdata+0
        CMP     R14,#nullptr
        LDRNE   R14,[handle,#w_taskhandle]
        LDREQ   R14,menutaskhandle
        Task    R14,,"KeyPressed"       ; page in correct task

        TEQ     R6,#&1B                 ; escape?
        BNE     %FT02

 [ KeyboardMenus
        CMP     r4, #0                  ; if no menu open then skip
        BLT     %FT02
        TST     r5, #3                  ; check for dialogue
        SUBNE   r0, r4, #4              ; if dialogue open then just remove it
        MOVEQ   r0, #-4                 ; otherwise remove whole menu tree
        CMP     r0, #0
        BLLT    menusdeleted            ; send Message_MenusDeleted if whole menu going (preserves r0)
        BL      closemenus
 |
        LDR     R0,menuSP
        CMP     R0,#0
        BLT     %FT02

        BL      menusdeleted            ; send Message_MenusDeleted
        MOVVC   R0,#-4
        BLVC    closemenus
 ]
        BVC     nothing                 ; absorb escape if used to close menus
        B       ExitPoll                ; report error if any

02      ADR     R14,caretdata
        LDMIA   R14,{R0-R5}
        CMP     R0,#nullptr
        BEQ     tryhotkeys              ; no input focus
        CMP     R1,#nullptr
        BNE     processkey              ; wimp gets first bash at this one!

keypressed
        STMIA   userblk,{R0-R6}         ; including the key value
        LDR     R14,singletaskhandle
        CMP     R14,#nullptr
        BLEQ    topmost_window
        STREQ   R0,hotkeyptr
;

        MOV     R0,#Key_Pressed         ; task handle already set up
        B       ExitPoll

tryhotkeys
        LDR     R14,singletaskhandle
        CMP     R14,#nullptr

; Set hotkeyptr to topmost window

        BLEQ    topmost_window
        STREQ   R0,hotkeyptr
        BLEQ    int_processkey          ; R6 = key code
        B       repollwimp

inkey0
        Push    "LR"
        MOV     R0,#&81                 ; INKEY(0)
        MOV     R1,#0
        MOV     R2,#0
        SWI     XOS_Byte
        Pull    "LR"
        BVS     ExitPoll                ; wot?
;
        CMP     R2,#&FF                 ; was there a key?
        BEQ     nothing
        MOV     PC,LR

 ] ; end UTF8 conditional


 [ KeyboardMenus
; In:   r4 = menuSP
;       r5 -> menu data
;       r6 = key pressed
;
handlemenukey
        LDR     R14, menutaskhandle
        Task    R14,,"KeyPressed"       ; page in correct task

        LDR     r14, mousexpos
        STR     r14, lastxpos
        LDR     r14, mouseypos
        STR     r14, lastypos

        ADR     r14, menuselections
        LDR     r1, [r14, r4]           ; r1 = previous selection index

        TEQ     r6, #13
        BNE     trymenucursorkeys
        CMP     r1, #0                  ; handle return
        BLT     nothing                 ; do nothing if no selection
        STR     r4, whichmenu
        MOV     r2, #4                  ; fake SELECT mouse button
        B       gomenuselect

trymenucursorkeys
        TEQ     r6, #137                ; check for right (sub-menu)
        BNE     trymenuleft
        CMP     r1, #0                  ; handle right
        BLT     nothing
        ADD     r7, r1, r1, LSL #1      ; r7 = selected item * 3 (also used later)
        ADD     r6, r5, r7, LSL #3      ; r6 -> selected menu item
        LDR     r1, [r6, #mi_submenu]   ; r1 -> sub-menu data block
        AcceptLoosePointer_NegOrZero r1,0
        CMP     r1, r1, ASR #31         ; check for sub-menu/dbox
        BEQ     nothing
        ADR     r14, menuhandles        ; get menu window handle
        LDR     handle, [r14, r4]
        BL      checkhandle
        BVS     nothing
        LDR     r2, reversedmenu
        CMP     r2, #"\\"
        LDREQ   r2, [handle, #w_wax0]   ; get menu x
        LDRNE   r2, [handle, #w_wax1]
        LDR     r14, [handle, #w_icons]
        ADD     r14, r14, #i_bby1
        ADD     r7, r7, #1              ; r7 = middle icon
        LDR     r3, [r14, r7, ASL #i_shift]
        LDR     r14, [handle, #w_way1]
        ADD     r3, r3, r14             ; get menu y
        LDR     r14, [handle, #w_scy]
        SUB     r3, r3, r14             ; adjust for scrolling
 [ NCMenus
        ADD     r3, r3, #24             ; adjust for NCMenus border
 ]
        LDR     r14, [r6, #mi_mflags]
        TST     r14, #mif_warning
        BLNE    sendmenuwarning         ; preserves flags
        BLEQ    int_create_menu
        B       nothing

trymenuleft
        TEQ     r6, #136
        BLNE    trymenuupdown           ; preserves flags
        BNE     nothing
        SUBS    r0, r4, #4              ; handle left
        BLGE    closemenus
        B       nothing

trymenuupdown
; In:   r1 = current selected menu item
;       r4 = menuSP
;       r5 -> menu data
;       r6 = key pressed
; Out:  Could corrupt almost anything
;       Flags preserved
;
        EntryS
        MOV     r7, #0                  ; determine how many items in menu
00
        ADD     r7, r7, #1
        LDR     r0, [r5], #mi_size
        TST     r0, #mif_lastone
        BEQ     %BT00

        CMP     r1, #-1
        SUBEQ   r1, r7, #1
        MOV     r0, r1                  ; start with current menu item
trynextupdown
        TEQ     r6, #138                ; check for down
        BNE     trymenuupkey
        ADD     r0, r0, #1              ; handle down key
        CMP     r0, r7
        MOVGE   r0, #0                  ; wrap if necessary
        B       %FT10

trymenuupkey
        TEQ     r6, #139                ; check for up
        BNE     %FT20
        SUBS    r0, r0, #1              ; handle up key
        SUBLT   r0, r7, #1              ; wrap if necessary
10
        TEQ     r0, r1                  ; if all menu items grey then don't loop forever
        BEQ     %FT20

        ADR     r14, menuhandles
        LDR     handle, [r14, r4]       ; get menu window handle
        BL      checkhandle
        BVS     %FT20
        Push    "r6,r7"
        BL      menuhighlight
        Pull    "r6,r7"
        BVS     %FT20
        TEQ     r14, #0
        BEQ     trynextupdown           ; if item greyed out then try next
20
        EXITS
 ]

;----------------------------------------------------------------------------
; Return to next task with null event
; The 'PollIdle' class of tasks is considered first,
; followed by the 'Poll' tasks (if none of the others have timed-out)
; The current task is taken as the starting point.
;----------------------------------------------------------------------------

nothing
      [ redrawlast
        B       check_redraw

check_null
      ]

        SWI     XOS_ReadMonotonicTime
        BVS     ExitPoll                ; wot?
;
; if an old-style program is running, the other clients are ignored
;
        LDR     R14,polltaskhandle
        LDR     R5,singletaskhandle
        TEQ     R14,R5
        BEQ     nullexit
;
; Wimp_Poll treated as Wimp_PollIdle but with immediate timeout
;
        LDR     R5,nulltaskhandle
        ADD     R5,wsptr,R5             ; R5 --> current task data
        ADD     R5,R5,#4                ; start at next one along
        ADRL    R7,taskpointers+maxtasks*4 ; R7 = wrap address
        MOV     R6,#maxtasks            ; R6 = number to try
01
        CMP     R5,R7
        ADRCSL  R5,taskpointers
        LDR     R4,[R5],#4
        TST     R4,#task_unused
        LDREQ   R14,[R4,#task_flagword]
        TSTEQ   R14,#null_bit
        BNE     %FT02
        TST     R14,#flag_pollidle
        BEQ     returnnull
        LDR     R2,[R4,#task_registers+2*4]
        CMP     R0,R2
        BPL     returnnull              ; time's up! (use PL not CS)
02
        SUBS    R6,R6,#1
        BNE     %BT01
        B       triggercallbacks        ; no 'null return' tasks

returnnull

        SUB     R14,R5,#4
        SUB     R14,R14,wsptr           ; R14 = task handle
        STR     R14,nulltaskhandle
        Task    R14,,"Null"

        MOV     R0,#No_Reason           ; null reason code
        B       ExitPoll

nullexit
        LDR     R14,flagword            ; single-tasking exit
        TST     R14,#null_bit
        BNE     triggercallbacks
        MOV     R0,#No_Reason           ; null reason code
        B       ExitPoll

triggercallbacks
        ; No null events to deliver, so try triggering callbacks
      [ UseLeaveOS
        SWI     XOS_LeaveOS
      |
      [ Medusa
        MRS     r0, CPSR
        BIC     r0, r0, #&F             ; drop to same 32-bitness of USR mode
        MSR     CPSR_c, r0
      |
        TEQP    pc, #0
        NOP
      ]
        SWI     XOS_IntOn               ; callbacks will be triggered on exit
      ]
        SWI     XOS_EnterOS
        B       repollwimp

;-----------------------------------------------------------
; Remove task from list of tasks with pollwords
;
; In:
;   handle = task to remove (if found)
;
; Out:
;   None, preserves flags
;
;-----------------------------------------------------------


DeletePollTask  EntryS "R0,R1"
        ADR     R0,PollTasks            ; Get -> start of polltask list
        LDR     R1,PollTaskPtr          ; Get -> first free slot
01
        CMP     R0,R1                   ; End of list?
        EXITS   HS                      ; Yes then exit, not found

        LDR     LR,[R0],#4              ; Get polled task handle
        TEQ     LR,handle               ; Match?
        BNE     %BT01                   ; No then try next polled task

        LDR     LR,[R1,#-4]!            ; Get last entry
        STR     LR,[R0,#-4]!            ; Overwrite current entry
        STR     R1,PollTaskPtr          ; New end of list

        Debug   poll,"Delete poll: handle, posn, new, end",handle,R0,LR,R1

        EXITS



;;----------------------------------------------------------------------------
;; Check tasks' poll words to see if they are non-zero
;;----------------------------------------------------------------------------

; In    R0 = mask word to apply to poll words (only consider if word & R0 set)
; Out   NE => R0=reason code, correct task paged in
;       [userblk,#0] = poll word address
;       [userblk,#4] = poll word contents, as read (once) by Wimp


scanpollwords   Entry "R1-R4"
        ADR     R1,PollTasks            ; Get -> start of polltask list
        LDR     R2,PollTaskPtr          ; Get -> first free slot
01
        TEQ     R1,R2                   ; End of list?
        EXIT    EQ                      ; Yes then exit, not found

        LDR     LR,[R1],#4              ; Read polled task handle
        LDR     R3,[LR,wsptr]           ; Read address of task data
        LDR     R3,[R3,#task_pollword]  ; Task pollword
        TST     R3,R0                   ; NE => consider this
        BICNE   R3,R3,#1                ; Can't combine this with LDR because non-rotated value mus be stored below
        LDRNE   R4,[R3]                 ; Read pollword
        TEQNE   R4,#0                   ; NE => word non-zero!
        BEQ     %BT01                   ; Jump if not found

        Debug   poll,"Pollword non-zero: task,list,address",LR,R1,R3

        Task    LR,,"Poll word"         ; preserves flags
        MOV     R0,#PollWord_NonZero    ; R0 = reason code
        STMIA   userblk,{R3,R4}

        EXIT                            ; Returns NE




;-----------------------------------------------------------------------------

pendingtime
        Push    "R2,LR"
;
        LDR     R14,timeblk
        LDR     R2,pending_time
        SUB     R14,R14,R2              ; R14 = elapsed time since 1st press
;
        Pull    "R2,PC"                 ; preserves flags


;----------------------------------------------------------------------------
; Routine to select an icon
; Also deselects any other icons in the same ESG
; Entry:  handle,R4 = window/icon to select
;         R2 = button state causing selection
;----------------------------------------------------------------------------

selecticon
        EntryS  "R0-R8"
;
        LDR     R5,[handle,#w_icons]
        ADD     R5,R5,#i_flags

        LDR     R6,[R5,R4,ASL #i_shift]         ; get flags
        ANDS    R14,R6,#if_esg2                 ; get ESG field
        MOVEQ   R2,#0                           ; invert state if on it's own
        BEQ     goselect
;
        TST     R6,#if_canadjust                ; can we select multiply?
        TSTNE   R2,#button_right
        BNE     dontcancel                      ; allow 'adjust' to work
        MOV     R6,R14                          ; get ESG
;
        LDR     R8,[handle,#w_nicons]
sellp
        SUBS    R8,R8,#1
        BMI     dontcancel                      ; finished
        CMP     R8,R4
        BEQ     sellp                           ; ignore this one
;
        LDR     R7,[R5,R8,ASL #i_shift]
        AND     R14,R7,#if_esg2                 ; see if same ESG
        TEQ     R14,R6
        BNE     sellp
;
        TST     R7,#is_inverted
        MOVNE   R0,R8
        MOVNE   R1,#0                   ; EOR value
        MOVNE   R2,#is_inverted         ; BIC value
        BLNE    int_set_icon_state
        B       sellp

dontcancel
        LDR     R2,[R13,#Proc_RegOffset+8] ; get button state again!
        TST     R2,#button_right
        MOVNE   R2,#0
        BNE     goselect                ; invert state if using ADJUST
;
        LDR     R14,[R5,R4,ASL #i_shift]        ; don't bother if already done
        TST     R14,#is_inverted
        BNE     exitselect
;
        MOV     R2,#is_inverted         ; BIC value (ie. set this state)
goselect
        MOV     R0,R4                   ; icon handle
        MOV     R1,#is_inverted         ; EOR value
        BL      int_set_icon_state
;
exitselect
        STRVS   R0,[R13,#Proc_RegOffset]
        EXITV                           ; preserve V


;;----------------------------------------------------------------------------
;; Wimp system icon detection
;; Entry:  R0,R1 = coords of mouse pointer
;;         R4 = -2 (in system area)
;;         handle -> window definition
;; Exit :  R4 = -2 to -n (corresponding to which icon the pointer is over)
;;         R5 = appropriate flag word
;;         other registers preserved (inc. flags)
;;----------------------------------------------------------------------------

setwimpicon
        CMP     R3,#nullptr
        MOVEQ   PC,LR                           ; forget it!
;
        Push    "R2,R3,x0,y0,x1,y1,LR"
;
        MOV     R3,#wf_icon1
        MOV     R4,#1
        LDR     R2,[handle,#w_flags]
01
        TST     R2,R3
        BEQ     %FT02
05
        Push    "R0,R1"
        MOV     R0,R4
        BL      calc_w_iconposn
        Pull    "R0,R1"
        CMP     R0,x0
        CMPGT   R1,y0
        CMPGT   x1,R0
        CMPGT   y1,R1
        BLE     %FT02
;        Debug   ub,"on an icon !"
;
        CMP     R4,#5                   ; icon 5 is really 3 icons
        BEQ     check_v_arrows
        ADDHI   R4,R4,#2
        CMP     R4,#7+2                 ; fudge!
        BEQ     check_h_arrows          ; icon 7 is also really 3 icons
      [ IconiseButton
        ADDHI	R4,R4,#3		; and skip -13 (which is the border)
      ]
03
      [ BounceClose
        LDRB    R14, buttontype
        TEQ     R14, #0
        ADREQ   R14, wiconflags - 4
        ADRNE   R14, wiconflags_release - 4
      |
        ADR     R14,wiconflags-4
      ]
        LDR     R5,[R14,R4,ASL #2]
        CMP     R5,#-1
        MOVEQ   R5,#ibt_click:SHL:ib_buttontype
        TSTEQ   R2,#wf_userscroll2      ; debounced form of userscroll
        MOVEQ   R5,#ibt_autorepeat:SHL:ib_buttontype
        MOV     R14,#-1
        SUB     R4,R14,R4               ; R4 in range -2 to -n
        Pull    "R2,R3,x0,y0,x1,y1,PC"

check_v_arrows
      [ ChildWindows
        LDR     R14,up_height           ; if scrollbar is small, only the arrows are shown (scaled down)
        LDR     R5,down_height
        ADD     R5,R14,R5
        SUB     R14,y1,y0
        CMP     R5,R14
        BLE     %FT10

        ADD     R14,y0,R14,LSR #1
        CMP     R1,R14
        ADDLT   R4,R4,#2                ; down arrow
        B       %BT03
10
      ]
        LDR     R14,up_height
        SUB     R14,y1,R14
        CMP     R1,R14
        ADDLT   R4,R4,#1                ; not up-arrow
        LDR     R14,down_height
        ADD     R14,y0,R14
        CMP     R1,R14
        ADDLT   R4,R4,#1                ; not middle bit
        B       %BT03

check_h_arrows
      [ ChildWindows
        LDR     R14,left_width          ; if scrollbar is small, only the arrows are shown (scaled down)
        LDR     R5,right_width
        ADD     R5,R14,R5
        SUB     R14,x1,x0
        CMP     R5,R14
        BLE     %FT11

        ADD     R14,x0,R14,LSR #1
        CMP     R0,R14
        ADDGT   R4,R4,#2                ; right arrow
        B       %BT03
11
      ]
        LDR     R14,left_width
        ADD     R14,x0,R14
        CMP     R0,R14
        ADDGT   R4,R4,#1                ; not left-arrow
        LDR     R14,right_width
        SUB     R14,x1,R14
        CMP     R0,R14
        ADDGT   R4,R4,#1                ; not middle bit
        B       %BT03

02
        MOVS    R3,R3,ASL #1
        ADD     R4,R4,#1
        CMP     R4,#8
        BLO     %BT01
      [ IconiseButton
	BHI	%FT04
	LDR	R2,[handle,#w_flags]
	TST	R2,#wf_icon2
	BEQ     %FT04
	LDR     R2, [handle, #w_parent]
	CMP     R2, #-1
	BNE     %FT04
	LDRB    R2, iconisebutton
	TEQ     R2, #0
	BNE     %BT05
04
      ]
;
        MOV     R4,#bordericon                          ; in the border
        MOV     R5,#ibt_never :SHL: ib_buttontype       ; has no effect
        Pull    "R2,R3,x0,y0,x1,y1,PC"


wiconflags
        DCD     ibt_click        :SHL: ib_buttontype        ; back
        DCD     ibt_click        :SHL: ib_buttontype        ; quit
        DCD     ibt_click        :SHL: ib_buttontype        ; move BLOBBY
        DCD     ibt_click        :SHL: ib_buttontype        ; toggle
        DCD     -1                                          ; scup
        DCD     ibt_click        :SHL: ib_buttontype        ; scvert
        DCD     -1                                          ; scdown
        DCD     ibt_click        :SHL: ib_buttontype        ; size
        DCD     -1                                          ; scleft
        DCD     ibt_click        :SHL: ib_buttontype        ; schoriz
        DCD     -1                                          ; scright
bordericon      *       -2 - (.-wiconflags)/4
	[ IconiseButton
	DCD	-1
	DCD	ibt_click        :SHL: ib_buttontype	    ; iconise
	]

    [ BounceClose
wiconflags_release
        DCD     ibt_clickrelease :SHL: ib_buttontype        ; back
        DCD     ibt_clickrelease :SHL: ib_buttontype        ; quit
        DCD     ibt_click        :SHL: ib_buttontype        ; move BLOBBY
        DCD     ibt_clickrelease :SHL: ib_buttontype        ; toggle
        DCD     -1                                          ; scup
        DCD     ibt_click        :SHL: ib_buttontype        ; scvert
        DCD     -1                                          ; scdown
        DCD     ibt_click        :SHL: ib_buttontype        ; size
        DCD     -1                                          ; scleft
        DCD     ibt_click        :SHL: ib_buttontype        ; schoriz
        DCD     -1                                          ; scright
	[ IconiseButton
	DCD	-1
	DCD	ibt_clickrelease :SHL: ib_buttontype	    ; iconise
	]
    ]

wimpaction
        CMP     R3,#nullptr             ; is this a real window?
        BLNE    pageinicontask_R3R4     ; takes note of iconbar

        TST     R2,#button_left:OR:button_right
        BEQ     trykeys                         ; menu not allowed here!
        ADR     R14,wiconjump-8
        SUB     PC,R14,R4,ASL #2                ; wow!

wiconjump
        B       wicon_back
        B       wicon_quit
        B       wicon_move
        B       wicon_toggle
        B       wicon_scup
        B       wicon_scvert
        B       wicon_scdown
        B       wicon_size
        B       wicon_scleft
        B       wicon_schoriz
        B       wicon_scright
	[ IconiseButton
	MOV	PC,#0
	B	wicon_iconise
	]


;;----------------------------------------------------------------------------
;; jump destinations for possible wimp icons
;;----------------------------------------------------------------------------

wicon_size
        MOV     R0,#drag_size
        BL      int_drag_box            ; handle,R0 are params
        B       trykeys

wicon_move
        MOV     R0,#drag_posn
        BL      int_drag_box            ; handle,R0 are params
        B       trykeys

wicon_toggle
        MOV     R1,#wf_isapane          ; we want to ignore panes
        BL      go_get_window_state     ; 2nd entry point - uses R1
        LDR     R14,[handle,#w_flags]
      [ togglebits
        TST     R14,#ws_toggled :OR: ws_toggled2
        BIC     R14,R14,#ws_toggled2
      |
        TST     R14,#ws_toggled
      ]
        ORR     R14,R14,#ws_toggling     ; set up to toggle when opened
        ORREQ   R14,R14,#ws_onscreenonce ; keep on-screen this time
        STR     R14,[handle,#w_flags]
        BNE     makesmall
;
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{cx0,cy0,cx1,cy1}
        ADD     R14,handle,#w_bwax0     ; remember old position
        STMIA   R14!,{cx0,cy0,cx1,cy1}
        LDR     x0,[handle,#w_scx]
        LDR     y0,[handle,#w_scy]
        LDR     x1,[handle,#w_bhandle]

        STMIA   R14,{x0,y0,x1}
;
        ADD     R14,handle,#w_wex0      ; add max size to get other coords
        LDMIA   R14,{x0,y0,x1,y1}
        SUB     x1,x1,x0
        SUB     y1,y1,y0
        ADD     cx1,cx0,x1
        SUB     cy0,cy1,y1

; Now check to see if <shift> is depressed, either will do.  If it
; is then attempt to toggle the window to a sensible size, not obscuring
; the icon bar.

        Push    "R0-R2,R4,R6"

      [ ChildWindows
        LDR     R14,[handle,#w_parent]
        CMP     R14,#nullptr
        BNE     %FT01                   ; this stuff only applies to top-level windows
      ]

	LDR	R4,iconbarheight
	SUB	R4,R4,#8;-40
	LDR	R14,[handle,#w_flags]
	TSTS	R14,#wf_icon7
        LDRNE   R14,hscroll_height
        ADDNE   R4,R4,R14               ; area not to be obscured

        SUBS    R6,cy0,R4               ; does the bottom of the window obscure the icon bar?
        BGE     %FT01                   ; if not then don't bother faffing around

        MOV     R0,#121
        MOV     R1,#&80
        SWI     XOS_Byte                ; scan for shift being depressed

      [ togglebits
        Push    "R1"
        MOV     R0,#ReadCMOS
        MOV     R1,#FileSwitchCMOS
        SWI     XOS_Byte                ; check for special <shift> toggle action
        TST     R2,#WimpShiftToggleCMOSBit
        Pull    "R1"
        EORNE   R1,R1,#255              ; if active then invert the action
      ]

        TEQ     R1,#&FF
        BNE     %FT01                   ; if it isn't then ignore the munging of the bits

        MOV     cy0,R4
        SUB     cy1,cy1,R6              ; setup the new co-ordinates for bottom & top Y's

	LDR	R6,scry1
      [ togglebits
        LDR     R14, [handle, #w_flags]
        TST     R14, #wf_icon3          ; we can still have a toggle-size button without a title bar!
        LDRNE   R14, title_height
        SUBNE   R6, R6, R14
      |
	LDR	R14,title_height
	SUB	R6,R6,R14
      ]
	LDR	R14,iconbarheight
	SUB	R14,R14,#8
	SUB	R0,R6,R14
	LDR	R14,[handle,#w_flags]
	TSTS	R14,#wf_icon7
	LDRNE	R14,hscroll_height
	SUBNE	R0,R0,R14		; R0 = max window height that can fit on screen
	CMPS	y1,R0
	MOVGT	cy1,R6		        ; window won't fit at maximum extent, so carefully trim
	SUBGT	y1,cy1,cy0

      [ togglebits
        LDR     R14,[handle,#w_flags]   ; set toggled in silly way bit
        ORR     R14,R14,#ws_toggled2
        STR     R14,[handle,#w_flags]
      ]
01
        Pull    "R0-R2,R4,R6"

        ADD     R14,userblk,#u_wax0
        STMIA   R14,{cx0,cy0,cx1,cy1}
;
      [ togglebits
        SUB     cx0,cx1,cx0
        SUB     cy0,cy1,cy0             ; work out the area really shown
;
        ASSERT  w_toggleheight = w_togglewidth +4
        ADD     R14,handle,#w_togglewidth
        STMIA   R14,{cx0,cy0}           ; push the co-ordinates away
      ]
;
        BL      calc_w_status           ; ensure bhandle up-to-date

      [ BounceClose
        LDR     R2,pending_buttons      ; Horrible hack so adjust works even with release buttons
      |
        LDR     R2,mousebuttons         ; bhandle depends on adjust button
      ]

openwindow_checkbuttons
        TST     R2,#button_right        ; if adjust used, open at same level,
      [ true
        LDR     R14,[handle,#w_bhandle]
        BNE     %FT02
        ; first the special cases: if *this* window is a pane or a foreground window, use a bhandle of -1
        MOV     R4,#wf_isapane
        ORR     R4,R4,#wf_inborder      ; wf_isapane:OR:wf_inborder isn't a valid immediate constant
        LDR     R3,[handle,#w_flags]
        TST     R3,R4
        MOVNE   R14,#nullptr
        BNE     %FT02
        ; now check the windows above us in our window stack: if they're all either panes or foreground
        ; windows, then don't attempt any reordering, otherwise we end up in an endless loop opening
        ; panes in front of their main windows and vice versa, and nobody else gets any processor time
        LDR     R1,[handle,#w_active_link+ll_backwards]
01      LDR     R2,[R1,#ll_backwards]
        CMP     R2,#nullptr             ; if we've reached the front of the window stack
        BEQ     %FT02                   ; then break leaving R14 = current bhandle
        LDR     R3,[R1,#w_flags-w_active_link]
        TST     R3,R4
        MOVNE   R1,R2
        BNE     %BT01
        MOV     R14,#nullptr            ; found a non-pane non-foreground window: move drag window to top of stack
02
      |
        MOVEQ   R14,#nullptr            ; otherwise open window at front
        LDRNE   R14,[handle,#w_bhandle]
      ]
        STR     R14,[userblk,#u_bhandle]
;
        B       Exit_OpenWindow


makesmall
        ADD     R14,handle,#w_bwax0
        LDMIA   R14,{cx0,cy0,cx1,cy1,x0,y0,x1}  ; Load previous x0,y0,x1,y1,scx,scy,bhandle

        ; SMC: 18th January 1995
        ; Correct fix for MED-03674, original fix (amg: 28th September 1994) was too simple
        ; and caused MED-04376 which the following also fixes.

        CMP     x1, #nullptr                    ; If this window was at the top
        BEQ     %FT20                           ; then open it there.

        Push    "r2,r3"
      [ ChildWindows
        LDR     r14, [handle, #w_parent]            ; depending on whether this window is at the top-level,
        CMP     r14, #nullptr
        LDREQ   r2, activewinds+lh_forwards         ; scan the list of topmost windows
        LDRNE   r2, [r14, #w_children+lh_forwards]  ; or the list of siblings
      |
        LDR     r2, activewinds+lh_forwards     ; Otherwise, scan down the list of windows.
      ]
        BIC     r3, x1, #3                      ; Align bhandle for comparisons (should really use the Abs macro)
10
        LDR     r2, [r2, #ll_forwards]
        CMP     r2, #nullptr                    ; If we hit the end,
        LDRNE   r14, [r2, #w_flags-w_active_link]
        ANDNE   r14, r14, #wf_backwindow
        TEQNE   r14, #wf_backwindow             ; or if we hit a backwindow
        MOVEQ   x1, #-2                         ; then open our window at the bottom.
        SUBNE   r14, r2, #w_active_link
        TEQNE   r14, handle                     ; If we hit this window???
        TEQNE   r14, r3                         ; or the one to open behind then drop out and open behind stored window
        BNE     %BT10                           ; else go round loop again.
        Pull    "r2,r3"
20

        ADD     R14,userblk,#u_wax0
        STMIA   R14,{cx0,cy0,cx1,cy1,x0,y0,x1}
        B       Exit_OpenWindow

wicon_back
        BL      int_get_window_state
      [ true
        MOV     R0, #121
        MOV     R1, #&80
        SWI     XOS_Byte                ; Scan keyboard for Shift key
        TEQ     R1, #&FF
      ]
      [ true :LOR: RO4
        LDR     R14,pending_buttons
        AND     R14,R14,#button_right
        BEQ     %FT12                   ; Branch if so
        ASSERT  button_right = (nullptr - nullptr2)
11      ADD     R14,R14,#nullptr2
      |
        MOV     R14,#nullptr2                   ; will not match
      ]
        STR     R14,[userblk,#u_bhandle]        ; so will go to bottom
        B       Exit_OpenWindow

      [ true
12      LDR     R0,[userblk,#u_handle]
        Abs     R0,R0
        ADD     R0,R0,#w_active_link
        MOV     R2,#wf_isapane
        ORR     R2,R2,#wf_grabkeys
        TEQ     R14,#button_right
        MOVEQ   R3,#ll_backwards
        MOVNE   R3,#ll_forwards
        BNE     %FT14                   ; need to search 1 window down, or 2 windows up
13      LDR     R0,[R0,R3]
        LDR     R1,[R0,R3]
        CMP     R1,#nullptr             ; hit the stops?
        BEQ     %BT11                   ; yes, so behave as though shift wasn't pressed
        LDR     R1,[R0,#w_flags - w_active_link]
        TST     R1,R2
        BNE     %BT13                   ; skip over any panes or hotkey windows
14      LDR     R0,[R0,R3]
        LDR     R1,[R0,R3]
        CMP     R1,#nullptr             ; hit the stops?
        BEQ     %BT11                   ; yes, so behave as though shift wasn't pressed
        LDR     R1,[R0,#w_flags - w_active_link]
        TST     R1,#wf_backwindow       ; hit a backwindow (presumably going down)?
        BNE     %BT11                   ; don't open behind it!
        TST     R1,R2
        BNE     %BT14                   ; skip over any panes or hotkey windows
        SUB     R0,R0,#w_active_link
        Rel     R0,R0
        STR     R0,[userblk,#u_bhandle]
        B       Exit_OpenWindow
      ]

      [ IconiseButton
wicon_iconise
        Push	"r0-r4"
      [ MultiClose
        TST     R2, #button_right       ; Ctrl-Alt-*Adjust* isn't special
        MOVNE   R1, #0                  ; flag as due to iconise button
        BNE     %FT20

        MOV     R0, #121
        MOV     R1, #&81                ; Scan keyboard for Ctrl key
        SWI     XOS_Byte
        MOV     R4, R1
        MOV     R1, #&82                ; Scan keyboard for Alt key
        SWI     XOS_Byte
        TEQ     R4, #&FF
        TEQEQ   R1, #&FF
        MOVNE   R1, #0                  ; flag as due to iconise button
        BNE     %FT20

        ; Iconise all top-level windows that have close buttons (except hotkey windows)
        LDR     handle, activewinds + lh_forwards
        SUB     R0, handle, #w_active_link
        Rel     R0, R0
        STR     R0, nextwindowtoiconise
        BL      iconisenextwindow
        Pull    "R0-R4"
        B       trykeys

      |
        MOV     R1, #0                  ; NOT a shift+click on close icon
        B	%FT20
      ]
      ]

wicon_quit
        Push    "r0-r4"

        [ StickyMenus
        LDR     R0,[handle,#w_taskhandle]
        CMP     R0,#-1
        Pull    "r0-r4",EQ
        BEQ     not_alt                 ; can't iconise menu
        ]

        TST     R2,#button_right        ; If adjust, ignore it.
        Pull    "r0-r4",NE
        BNE     not_alt

      [ MultiClose
        MOV     R0, #121
        MOV     R1, #&81                ; Scan keyboard for Ctrl key
        SWI     XOS_Byte
        MOV     R4, R1
        MOV     R1, #&82                ; Scan keyboard for Alt key
        SWI     XOS_Byte
        TEQ     R4, #&FF
        TEQEQ   R1, #&FF
        BNE     %FT66

      [ BounceClose
        LDR     R2, pending_buttons
        STR     R2, mousebuttons        ; The usual Horrible Hack
      ]
        ; Close all windows at this level that have close buttons (except hotkey windows)
        LDR     handle, [handle, #w_parent]
        CMP     handle, #nullptr
        LDREQ   handle, activewinds + lh_backwards
        LDRNE   handle, [handle, #w_children + lh_backwards]
01      LDR     R0, [handle, #ll_backwards]
        CMP     R0, #nullptr
        BEQ     %FT02
        LDR     R14, [handle, #w_flags - w_active_link]
        TST     R14, #wf_icon2
        ANDNE   R14, R14, #wf_grabkeys
        TEQNE   R14, #wf_grabkeys
        MOVEQ   handle, R0
        BEQ     %BT01
        ; Found such a window; send close request message
        Push    "R0"
        SUB     handle, handle, #w_active_link
        SUB     sp, sp, #4
        Rel     R2, handle
        STR     R2, [sp]
        MOV     R0, #Close_Window_Request
        MOV     R1, sp
        BL      int_sendmessage_fromwimp
        ADD     sp, sp, #4
        Pull    "handle"
        B       %BT01
02
        Pull    "R0-R4"
        B       trykeys
66
      ]

        MOV     R0,#121                 ; Scan keyboard for shift key
        MOV     R1,#&80
        SWI     XOS_Byte

        CMP     R1,#&FF

        Pull    "r0-r4",NE
        BNE     not_alt

        [ ChildWindows
        LDR     R0, [handle, #w_parent] ; don't do anything if Shift-close on child windows
        CMP     R0, #-1
        Pull    "r0-r4",NE
        BNE     trykeys
        ]
20
      [ MultiClose
        LDR     r2, mousexpos
        LDR     r4, mouseypos
      ]
        BL      sendiconisemessages
        Pull    "r0-r4"
        B       trykeys

not_alt
        [ StickyMenus
;        LDR     R0,[handle,#w_taskhandle]
;        CMP     R0,#-1
;        BNE     %FT05
        LDR     R14,menuSP
        CMP     R14,#-4
        BEQ     %FT05                           ; no menu open

        LDR     R14,menuhandles
        Abs     R14,R14
        TEQ     handle,R14

        BNE     %FT02
        BL      menusdeleted
        MOVVC   R0,#-4
        BLVC    closemenus
        B       nothing                         ; swallow it.
02
        LDR     R14,menuSP
        ADD     R14,R14,#4
        ADR     R0,menuhandles
03
        LDR     R1,[R0,R14]
        Abs     R1,R1
        TEQ     R1,handle
        BEQ     %FT04
        SUBS    R14,R14,#4
        BGE     %BT03
        B       %FT05
04
        SUB     R0,R14,#4
        BL      closemenus              ; close down to one above
        B       nothing
05
        ]
	[ BounceClose
	STR	R2,mousebuttons		; Horrible hack so apps can tell that adjust was pressed
	]
        STR     R3,[userblk]
        MOV     R0,#Close_Window_Request
        B       ExitPoll

      [ MultiClose
iconisenextwindow
        Entry   "R0-R4,handle"
        LDR     handle, nextwindowtoiconise
        BL      checkhandle             ; make sure it's still valid
        TEQVS   PC, #0                  ; \ set Z = not (V)
        TEQVC   R0, R0                  ; /
        LDREQ   R14, [handle, #w_flags]
        ANDEQ   R0, R14, #ws_open
        CMPEQ   R0, #ws_open            ; and open
        ADDEQ   handle, handle, #w_active_link
        LDRNE   handle, activewinds + lh_forwards ; if not, restart from top
01
        LDR     R0, [handle, #ll_forwards]
        CMP     R0, #nullptr             ; have we reached the header?
        MOVEQ   R0, #0
        STREQ   R0, nextwindowtoiconise
        EXIT    EQ                       ; stop if we have
        LDR     R14, [handle, #w_flags - w_active_link]
        TST     R14, #wf_backwindow
        MOVNE   R0, #0
        STRNE   R0, nextwindowtoiconise
        EXIT    NE                       ; don't re-iconise already-iconised windows!
        TST     R14, #wf_icon2
        ANDNE   R14, R14, #wf_grabkeys
        TEQNE   R14, #wf_grabkeys
        MOVEQ   handle, R0
        BEQ     %BT01
        ; Found a suitable window; work out suitable entry conditions for sendiconisemessages
        Push    "R0"
        SUB     handle, handle, #w_active_link
        MOV     R0, #iconposn_iconise
        BL      calc_w_iconposn          ; x0-y1 = button bbox
        ADD     R2, x0, x1
        ADD     R4, y0, y1
        MOV     R2, R2, LSR#1
        MOV     R4, R4, LSR#1
        MOV     R1, #0
        Rel     R3, handle
        BL      sendiconisemessages
        ; Now store the next window to process (if any)
        Pull    "handle"
        LDR     R0, [handle, #ll_forwards]
        CMP     R0, #nullptr
        MOVEQ   R0, #0
        SUBNE   R0, handle, #w_active_link
        Rel     R0, R0, NE
        STR     R0, nextwindowtoiconise
        EXIT
      ]

sendiconisemessages
; Entry: R1 = &FF => caused by click on close icon; R1 = 0 => caused by click on iconise icon
;        R3 = relative window handle to send
; and if MultiClose enabled,
;        R2 = mouse x
;        R4 = mouse y
        Entry

        [ IconiseButton
        ; Send a Message_IconizeAt (RML)
        Push    "r3"
        SUB     sp, sp, #48

        CMP     r1, #&FF                 ; If a Shift+Click on close
        MOVEQ   r0, #1                   ; then bit 0 of flags is set
        MOVNE   r0, #0
        STR     r0, [sp, #ms_data+16]

        MOV     r1, sp
      [ MultiClose
        STR     r2, [r1, #ms_data+8]
        SUB     r4, r4, #32+17
        STR     r4, [r1, #ms_data+12]
      |
        LDR     r0, mousexpos
        STR     r0, [r1,#ms_data+8]
        LDR     r0, mouseypos
        SUB     r0, r0, #(32+17)
        STR     r0, [r1,#ms_data+12]
      ]
        MOV     r0, #40
        STR     r0, [r1,#ms_size]        ; size
        MOV     r0, #0
        STR     r0, [r1, #ms_yourref]    ; your ref
        LDR     r0, =Message_IconizeAt   ; (Message number 22)
        STR     r0, [r1, #ms_action]     ; message action
        STR     r3, [r1, #ms_data+0]     ; window handle

        ; Work out task handle
      [ MultiClose
        LDR     R2, [handle, #w_taskhandle]
      |
        LDR     r2, taskhandle
      ]
        LDR     r4, [wsptr, r2]          ; add in version bits (if alive)
        TST     r4, #task_unused
        LDREQ   r4, [r4, #task_flagword]
        MOVEQ   r4, r4, LSR #flag_versionbit
        ORREQ   r2, r2, r4, LSL #flag_versionbit
        STR     r2, [r1, #ms_data+4]

        MOV     r0, #User_Message
        MOV     r2, #0
        BL      int_sendmessage_fromwimp

        ADD     sp, sp, #48
        Pull    "r3"
        ]
                                                ; Shift-quit, send Message_Iconize.
        MOV     R14,#ms_data+8+20       ; size of block (Window,Task,20 byte from title ).
        STR     R14,[sp,#-(ms_data+8+20)]!
        MOV     R0,#User_Message
        MOV     R1,sp
        STR     R3,[R1,#ms_data]

      [ MultiClose
        LDR     R2, [handle, #w_taskhandle]
        LDR     R14, [handle, #w_titleflags]
        TST     R14, #if_indirected
        Task    "R2", NE, "Iconise: reading indirected title string"
      |
        LDR     R2,taskhandle
      ]
        LDR     R14,[wsptr,R2]          ; add in version bits (if alive)
        TST     R14,#task_unused
        LDREQ   R14,[R14,#task_flagword]
        MOVEQ   R14,R14,LSR #flag_versionbit
        ORREQ   R2,R2,R14,LSL #flag_versionbit
        STR     R2,[R1,#ms_data+4]

        ADD     R2,handle,#w_title
        LDR     R14,[handle,#w_titleflags]
        TST     R14,#if_indirected
        LDRNE   R2,[R2]                     ; If indirected get real address

00      LDRB    R3, [R2]                    ; always skip leading spaces
        TEQ     R3, #&20
        ADDEQ   R2, R2, #1
        BEQ     %BT00

        MOV     R14,R2                      ; Find first space or control terminator
01      LDRB    R3,[R14]
        CMP     R3,#&20
        ADDHI   R14,R14,#1
        BHI     %BT01

02      LDRB    R3,[R14]                    ; Go back to last '.'
        CMP     R14,R2
        CMPNE   R3,#"."
        SUBNE   R14,R14,#1
        BNE     %BT02

        CMP     R3,#"."                     ; Skip '.'
        ADDEQ   R14,R14,#1

        LDRB    R3, [R14]
        CMP     R3, #&20
        MOVLS   R14, R2                     ; if we'd get a null string, then jump back to start

        MOV     R4,#ms_data+8
03      LDRB    R3,[R14],#1
        CMP     R3,#&20
        BLS     %FT04
        STRB    R3,[R1,R4]
        ADD     R4,R4,#1
        CMP     R4,#27+ms_data
        BLO     %BT03

04      MOV     R3,#0                      ; Store zero terminator.
        STRB    R3,[R1,R4]

        MOV     R2,#0
        STR     R2,[R1,#ms_yourref]
        LDR     R14,=Message_Iconize
        STR     R14,[R1,#ms_action]
        BL      int_sendmessage_fromwimp
        ADD     sp,sp,#(ms_data+8+20)     ; correct stack

        EXIT

wicon_scup
        TST     R2,#button_right
        BNE     wicon_scdown2
wicon_scup2
        MOV     R14,#32
        LDR     R1,[handle,#w_wey1]             ; can't scroll up past top
        B       scrolly

wicon_scdown
        TST     R2,#button_right
        BNE     wicon_scup2
wicon_scdown2
        MOV     R14,#-32
        LDR     R1,[handle,#w_way0]
        LDR     R2,[handle,#w_way1]
        SUB     R1,R2,R1                        ; height of window
        LDR     R2,[handle,#w_wey0]
        ADD     R1,R2,R1                        ; min y-scroll coord (-ve)

scrolly
        LDR     R0,[handle,#w_flags]
        TST     R0,#wf_userscroll
        MOVNE   R1,#0                           ; x-scroll
        MOVNE   R2,R14,ASR #5                   ; scale down to +-1
        BNE     userscroll
;
        LDR     R0,[handle,#w_scy]
        TEQ     R0,R1
        BEQ     trykeys
;
        Push    R14
        BL      int_get_window_state
        LDR     R14,[handle,#w_bhandle]         ; open at same posn in stack
        STR     R14,[userblk,#u_bhandle]
        LDR     R0,[userblk,#u_scy]
        Pull    R14
        ADD     R0,R0,R14
        STR     R0,[userblk,#u_scy]
;
        B       Exit_OpenWindow

wicon_scleft
        TST     R2,#button_right
        BNE     wicon_scright2
wicon_scleft2
        MOV     R14,#-32
        LDR     R1,[handle,#w_wex0]             ; can't scroll left past wex0
        B       scrollx

wicon_scright
        TST     R2,#button_right
        BNE     wicon_scleft2
wicon_scright2
        MOV     R14,#32
        LDR     R1,[handle,#w_wax0]
        LDR     R2,[handle,#w_wax1]
        SUB     R1,R2,R1                        ; width of window
        LDR     R2,[handle,#w_wex1]
        SUB     R1,R2,R1                        ; max x-scroll coord

scrollx
        LDR     R0,[handle,#w_flags]
        TST     R0,#wf_userscroll
        MOVNE   R1,R14,ASR #5                   ; scale down to +-1
        MOVNE   R2,#0                           ; y-scroll
        BNE     userscroll
;
        LDR     R0,[handle,#w_scx]
        TEQ     R0,R1
        BEQ     trykeys
;
        Push    R14
        BL      int_get_window_state
        LDR     R14,[handle,#w_bhandle]         ; open at same posn in stack
        STR     R14,[userblk,#u_bhandle]
        LDR     R0,[userblk,#u_scx]
        Pull    R14
        ADD     R0,R0,R14
        STR     R0,[userblk,#u_scx]

;
; Get window opened
; Entry:  handle --> window definition
;         userblk --> data (handle,x0,y0,x1,y1,scx,scy,bhandle)
;

Exit_OpenWindow
        BL      calc_w_status                   ; ensure bhandle is correct
        ADD     R14,handle,#w_wax0
        LDMIA   R14!,{cx0,cy0,cx1,cy1}
        LDMIA   userblk,{R0,x0,y0,x1,y1}

        Push    R14
        LDR     R14,dx_1
        BIC     cx0,cx0,R14
        BIC     cx1,cx1,R14
        BIC     x0,x0,R14
        BIC     x1,x1,R14

        LDR     R14,dy_1
        BIC     cy1,cy1,R14
        BIC     cy0,cy0,R14
        BIC     y0,y0,R14
        BIC     y1,y1,R14
        Pull    R14

        TEQ     cx0,x0
        TEQEQ   cy0,y0
        TEQEQ   cx1,x1
        TEQEQ   cy1,y1
        LDMEQIA R14,{cx0,cy0,cx1}               ; scx,scy,bhandle
        ADDEQ   R14,userblk,#5*4                ; skip handle,x0,y0,x1,y1
        LDMEQIA R14,{x0,y0,x1}

        Push R14
        LDR     R14,dx_1
        BIC     cx0,cx0,R14
        BIC     x0,x0,R14

        LDR     R14,dy_1
        BIC     cy0,cy0,R14
        BIC     y0,y0,R14
        Pull    R14

        TEQEQ   cx0,x0
        TEQEQ   cy0,y0
        TEQEQ   cx1,x1
      [ togglebits
        LDR     R14, [handle, #w_flags]         ; don't mask out requests during a toggle operation!
        TSTEQ   R14, #ws_toggling
      ]
        BEQ     trykeys                         ; go to next bit of polling
;
        LDR     R14,[handle,#w_taskhandle]
        CMP     R14,#0                          ; <= 0 ==> system window
   ;    Task    R14,GT,"OpenWindow"     ; force errors into the open!
        MOVGT   R0,#Open_Window_Request
        BGT     ExitPoll
;
        BL      int_open_window         ; menus are opened automatically
        B       repollwimp

userscrollpage
        MOV     R2,R0                   ; R2 = cx0, so it's in R0 instead

userscroll
        Push    "R1,R2"
        BL      int_get_window_state
        LDR     R14,[userblk,#u_handle]         ; open at same posn in stack
        STR     R14,[userblk,#u_bhandle]
        Pull    "R1,R2"
        ADD     R14,userblk,#u_scroll
        STMIA   R14,{R1,R2}
;
        LDR     R14,[handle,#w_taskhandle]
        Task    R14,,"ScrollRequest"
        MOV     R0,#Scroll_Request
        B       ExitPoll

        LTORG


wicon_scvert
        BL      getvscrollcoords
        MOV     R1,#0                   ; x-scroll = 0
        LDR     R14,mouseypos
        CMP     R14,cy0
        MOVLT   R0,#-2                  ; R2 = cx0, so use R0 instead
        BLT     pagevert
        CMP     R14,cy1
        MOVGT   R0,#2
        BGT     pagevert
;
        LDR     R14,[handle,#w_flags]
        TST     R14,#wf_icon7           ; if there is a horizontal scroll bar,
        LDRNE   R14,mousebuttons        ; and the right-hand button is used
        TSTNE   R14,#button_right       ; allow 2-way scrolling
        MOVEQ   R0,#drag_vscroll
        MOVNE   R0,#drag_scrollboth
        BL      int_drag_box
        B       trykeys

wicon_schoriz
        BL      gethscrollcoords
        MOV     R0,#0                   ; y-scroll = 0
        LDR     R14,mousexpos           ; R2 = cx0, so use R0 instead
        CMP     R14,cx0
        MOVLT   R1,#-2
        BLT     pagehoriz
        CMP     R14,cx1
        MOVGT   R1,#2
        BGT     pagehoriz
;
        LDR     R14,[handle,#w_flags]
        TST     R14,#wf_icon5           ; if there is a vertical scroll bar,
        LDRNE   R14,mousebuttons        ; and the right-hand button is used
        TSTNE   R14,#button_right       ; allow 2-way scrolling
        MOVEQ   R0,#drag_hscroll
        MOVNE   R0,#drag_scrollboth
        BL      int_drag_box
        B       trykeys

pagevert
        LDR     R14,mousebuttons        ; reverse direction if r-button used
        TST     R14,#button_right
        RSBNE   R0,R0,#0
;
        LDR     R14,[handle,#w_flags]
        TST     R14,#wf_userscroll
        BNE     userscrollpage
;
        Rel     R1,handle
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{cx0,cy0,cx1,cy1,x0,y0,x1}
        SUB     R14,cy1,cy0
        TEQ     R0,#0                   ; y scroll direction
        ADDPL   y0,y0,R14
        SUBMI   y0,y0,R14
        ASSERT  (u_handle=0)
        STMIA   userblk,{R1,cx0,cy0,cx1,cy1,x0,y0,x1}
        STR     R1,[userblk,#u_bhandle]         ; same posn in stack
;
        B       Exit_OpenWindow

pagehoriz
        LDR     R14,mousebuttons        ; reverse direction if r-button used
        TST     R14,#button_right
        RSBNE   R1,R1,#0
;
        LDR     R14,[handle,#w_flags]
        TST     R14,#wf_userscroll
        BNE     userscrollpage
;
        Rel     R0,handle
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{cx0,cy0,cx1,cy1,x0,y0,x1}
        SUB     R14,cx1,cx0
        TEQ     R1,#0                   ; x scroll direction
        ADDPL   x0,x0,R14
        SUBMI   x0,x0,R14
        ASSERT  (u_handle=0)
        STMIA   userblk,{R0,cx0,cy0,cx1,cy1,x0,y0,x1}
        STR     R0,[userblk,#u_bhandle]         ; same posn in stack
;
        B       Exit_OpenWindow


;;----------------------------------------------------------------------------
;; Get_Pointer_Info - find out where the mouse pointer is
;;----------------------------------------------------------------------------

SWIWimp_GetPointerInfo
        MyEntry "GetPointerInfo"
;
        LDR     R0,mousexpos                    ; just read old values
        LDR     R1,mouseypos
        LDR     R2,mousebuttons
        MOV     R5,#wf2_shadedhelp              ; match shaded icons if this bit is set in window flags 2 byte
        BL      int_get_pointer_info

        CMP     R4, #nullptr2
        BNE     %FT01
	LDR     R14,singletaskhandle            ; if single-tasking,
	CMP     R14,#nullptr
	MOVNE   R4,#nullptr                     ; don't confuse punter!
        BLEQ    setwimpicon                     ; if new task, work out which icon it is
01
        LDR     R14,backwindowhandle
        TEQ     R3,R14
        LDRNE   R14,backwindow                  ; window -1 for either of these
        TEQNE   R3,R14
        MOVEQ   R3,#nullptr
;
        LDR     R14,iconbarhandle
        CMP     R14,#nullptr
        BEQ     %FT01
        TEQ     R3,R14
        MOVEQ   R3,#nullptr2                    ; return -2 for iconbar
01
   ;    LDR     R14,oldbuttons                  ; WAS last parameter
        STMIA   userblk,{R0,R1,R2,R3,R4}
        B       ExitWimp


;-----------------------------------------------------------------------------
; getmouseposn - takes note of mouseflags
;-----------------------------------------------------------------------------

getmouseposn
        Push    "LR"
;
        LDR     R14,mouseflags
        TST     R14,#mf_oldcoords
        BIC     R14,R14,#mf_oldcoords   ; test and reset bit
        STR     R14,mouseflags
        BEQ     newmouseposn
;
        LDR     R0,mousexpos
        LDR     R1,mouseypos
        LDR     R2,mousebuttons
        Pull    "PC"
;
newmouseposn
        LDR     R14,mousebuttons
        STR     R14,oldbuttons          ; copy only if want new buttons

        Push    "R3"

        MOV     R3,#0                   ; see if R3 is set up!

      [ mousecache

; if recacheposn is zero then no need to read the mouse values as they
; will not have been updated, instead read from our workspace and
; wait for the value to go non-zero.

        ASSERT  mouseypos = mousexpos +4
        ASSERT  mousebuttons = mouseypos +4
        ASSERT  mousetime = mousebuttons +4

        LDRB    R0,recacheposn
        TEQ     R0,#0                   ; do we have a cached posn for the mouse?
        ADREQ   R0,mousexpos            ; if they are then pick them up from our workspace
        LDMEQIA R0,{R0,R1,R2,R3}
        BEQ     %FT10

        STRB    R3,recacheposn
      ]

        SWI     XOS_Mouse
        LDR     R14,dx_1                ; R14 <- dx-1
        BIC     R0,R0,R14
        LDR     R14,dy_1                ; R14 <- dy-1
        BIC     R1,R1,R14

      [ mousecache
        ADR     R14,mousexpos
        STMIA   R14,{R0,R1,R2,R3}
      |
        STR     R0,mousexpos
        STR     R1,mouseypos
        STR     R2,mousebuttons
      ]
      [ NCErrorBox
        Push    "R0-R6"
        ASSERT  ptrsuspendflag = ptrsuspenddata + 12
        ADRL    R14, ptrsuspenddata
        LDMIA   R14, {R3-R6}

        TEQ     R6, #1                  ; waiting for keyboard-generated move?
        MOVEQ   R3, #2
        STMEQIA R14, {R0-R3}            ; store mouse state and new flag value

        TEQ     R6, #2                  ; waiting for mouse-generated move?
        BNE     %FT06
        TEQ     R0, R3
        TEQEQ   R1, R4
;        TEQEQ   R2, R5
        BEQ     %FT06                   ; no change

        ADRL    R14, ptrsuspendflag
        MOV     R0, #0
        STR     R0, [R14]               ; store new flag value
        MOV     R0, #106
        MOV     R1, #1
        SWI     XOS_Byte                ; turn on pointer
        TEQ     R1, #0
        SWINE   XOS_Byte                ; just in case it's been turned on by someone else already!
06
        Pull    "R0-R6"
      ]
10
        TEQ     R3,#0                   ; was it set up?
        BEQ     bodgetime
        STR     R3,timeblk
        Pull    "R3,PC"

bodgetime
        Push    "R0-R2"
        MOV     R0,#1
        ADR     R1,timeblk
        SWI     XOS_Word                ; make a note of the time
        Pull    "R0-R3,PC"


;-----------------------------------------------------------------------------
; int_get_pointer_info - called by Poll_Wimp
; look for a match with a window / user icon
; Entry :  R0,R1 = coords of mouse pointer
;          R5 = bits in windowflags2 that can be set to indicate shaded icons should b included
; Exit :   R3 = window handle (relative)
;          R4 = button index (or -1 if none)
;          handle --> window definition (if any)
;          If clicked in work area, [mousexyrel] = relative coordinates
;-----------------------------------------------------------------------------

int_get_pointer_info

        ADRL    R4,activewinds+lh_forwards-ll_forwards
      [ ChildWindows
        MOV     R3,#0                   ; ignore wf_inborder bit for top-level windows
      ]

; In:   R4 -> list head ( activewinds or [handle,#w_children] )
;       R3 = wf_inborder if we're to search only windows which have this bit
;       R3 = 0 if we're to search all windows in the list

int_get_pointer_info_R4                 ; for ChildWindows

      [ ChildWindows
        Push    "userblk,LR"

        MOV     userblk,R3              ; userblk = wf_inborder or 0
      |
        Push    "LR"
      ]

findwlp
        LDR     R4,[R4,#ll_forwards]
        LDR     R14,[R4,#ll_forwards]
        CMP     R14,#nullptr
        MOVEQ   R3,#nullptr
        MOVEQ   R4,#nullptr
      [ ChildWindows
        Pull    "userblk,PC",EQ
      |
        Pull    "PC",EQ
      ]
        SUB     handle,R4,#w_active_link
        Rel     R3,handle

      [ ChildWindows
        LDR     R14,[handle,#w_flags]
        AND     R14,R14,userblk
        TEQ     R14,userblk                     ; ignore window if userblk = wf_inborder and bit not
        BNE     findwlp
      ]

        ADD     R14,handle,#w_x0
        LDMIA   R14,{x0,y0,x1,y1}

        CMP     R0,x0
        CMPGE   R1,y0
        BLT     findwlp
        CMP     x1,R0
        CMPGT   y1,R1
        BLE     findwlp

;        Debug   child,"Click within outer box of",handle

; decide whether the click is inside or outside the work area

        Push    "R0-R3,R5-R9"
        ADD     R14,handle,#w_wax0
        LDMIA   R14,{cx0,cy0,cx1,cy1,x0,y0}
;
        Push    "cx0,cy0,cx1,cy1"
        LDR     R14,dx
        SUB     cx0,cx0,R14                     ; include border!
        LDR     R14,dy
        SUB     cy0,cy0,R14
        CMP     R0,cx0                          ; check inside work area
        CMPGE   R1,cy0
        CMPGE   cx1,R0
        CMPGE   cy1,R1
        Pull    "cx0,cy0,cx1,cy1"
      [ :LNOT: ChildWindows
        BLT     noficon2
      ]

; right - a click inside the work area
; first check to see if it's inside any of the window's children

      [ ChildWindows
        Push    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk"
        MOVLT   R3,#wf_inborder                 ; click was in border area (so only scan children that overlap the border)
        MOVGE   R3,#0                           ; click was in work area (scan all children)
        MOV     userblk,R3
        ADD     R4,handle,#w_children + lh_forwards - ll_forwards
        LDR     R5,[SP,#(10+4)*4]               ; get back original R5
        BL      int_get_pointer_info_R4         ; scan child window stack for a hit
        CMP     R3,#nullptr
        ADDNE   SP,SP,#10*4
        STRNE   R3,[SP,#3*4]
        BNE     exitp4                          ; click found in one of the children
        TEQ     userblk,#0
        Pull    "cx0,cy0,cx1,cy1,x0,y0,x1,y1,handle,userblk"
        BNE     noficon2                        ; click was in border area
      ]
;
; now scan the icon list for a hit (starting at the frontmost, ie. the highest-numbered)
;
        SUB     x1,cx0,x0                       ; coords of top-left
        SUB     y1,cy1,y0
        SUB     R0,R0,x1                        ; make mouse coords relative
        SUB     R1,R1,y1
;
        LDR     R4,[handle,#w_nicons]           ; R4 = no of icons
        LDR     R2,[handle,#w_icons]            ; R2 --> start of icons
        ADD     R2,R2,R4,ASL #i_shift           ; R3 --> end of list
        LDR     R5,[SP,#4*4]                    ; R5 on entry
ficlp
        SUBS    R4,R4,#1
        BMI     noficon                         ; no more left
        SUB     R2,R2,#i_size                   ; point to current icon
;
        LDR     R14,[R2,#i_flags]
        TST     R14,#is_deleted                 ; always ignore deleted icons
        BNE     ficlp
        TST     R14,#is_shaded                  ; only ignore shaded icons
        LDRNE   R14,[handle,#w_taskhandle]      ; if they're not in a menu
        CMPNE   R14,#nullptr                    ; -1 => menu
        BEQ     %FT01
        LDRB    R14,[handle,#w_flags2]
        TST     R14,R5                          ; do we want to match shaded icons in windows?
        BEQ     ficlp
01
        ASSERT  (i_bbx0=0)                      ; check LDMIA is OK
        ASSERT  cx1 = r4
        Push    "cx1,cy1"
        LDMIA   R2,{cx1,cy1,x0,y0}
        CMP     R0,cx1                          ; see if pointer is inside
        CMPGE   R1,cy1
        Pull    "cx1,cy1"
        BLT     ficlp
        CMP     R0,x0
        CMPLT   R1,y0
        BLT     endficon                ; got it!!!
        B       ficlp
;
noficon2
        MOV     R4,#nullptr2            ; if in border, set icon = -2
        B       endficon
noficon
        MOV     R4,#nullptr
endficon
        STR     R0,mousexrel            ; may be needed later
        STR     R1,mouseyrel
exitp4                                  ; for ChildWindows
      [ ChildWindows
        Pull    "R0-R3,R5-R9,userblk,PC" ; restore mouse coords etc.
      |
        Pull    "R0-R3,R5-R9,PC"        ; restore mouse coords etc.
      ]

        END
