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
; > Sources.RAMFSFiler

;;----------------------------------------------------------------------------
;; RAMFS Filer module
;;
;; Change List
;; -----------
;; 14-Apr-88    0.01    File created, change list added
;; 17-May-88            Cancel box removed from error window
;; 17-May-88    0.07    Use Desktop_RAMFSFiler to avoid confusing punter
;; 21-Jun-88    0.08    Change to use Wimp_SpriteOp rather than BaseOfSprites
;;  8-Jul-88            Change menu colours to suit GBartram's defaults
;; 18-Aug-88    0.09    Improve error message in Desktop_RAMFSFiler
;; 19-Aug-88    0.10    Check for ramfs existence in Service_StartFiler
;; 23-Aug-88    0.11    Change iconbar so "RAM" appears under sprite
;; 20-Oct-88            Change to use new Make procedures
;;  3-Aug-89    0.12    Add a Quit entry to the menu, and check whether
;;                      the RAMFS is empty before zeroing its workspace
;;  3-Nov-89    0.13    Implement right-click on menus correctly
;;  3-Nov-89    0.14    Implement message-based menus and interactive help
;;  5-Dec-89    0.15    Put OK / Cancel back to normal in Quit confirmation
;; 19-Feb-90    0.16    Include resource files inside module
;; 26-Feb-90    0.17    Use WimpPriority_RAMFS
;; 10-Sep-90    0.18    Changed free command to use *ShowFree -RAM
;; 14-Mar-91  0.19 OSS  Internationalisation - finish text extraction and
;;                      do error messages. Move Messages file out to the
;;                      UK Messages module.
;; 04-Apr-91  0.20 OSS  Fixed internationalisation bug (R1 corruption).
;; 24-Apr-91  0.22 OSS  Fixed potential STR to ROM on error lookup.
;;                      Aligned second Wimp_Initialise code with first one.
;; 19-Jul-91  0.23 ECN  Confirm shutdown on Service_Shutdown
;; 07-Oct-91  0.24 ECN  Open RAM::RamDisc0.$ instead of RAM:$
;;                      Give "RAMFSFiler is currently active" error.
;; 10-Dec-91  0.25 SMC  Removed comments from Messages file & shortened tokens
;; 16-Sep-93  0.30 SMC  Now passes on Service_ShutDown correctly.
;; 14-Dec-93  0.31 SMC  Clear V before looking up Banner token in ReportError
;;                      (so that "RAMFS Filer" appears in title rather than "Banner").
;; 29-May-97  0.33 RML  Checks for Message_DataSave, so that files can be saved in
;;                      root directory by dragging to the iconbar icon.
;; 15-Jan-98  0.34 RML  Issues Message_FilerDevicePath if files are dragged onto
;;                      it's icon.
;; 13-Jan-03  0.38 RPS  Added ability to share and name the drive
;;----------------------------------------------------------------------------

        AREA    |RAMFSFiler$$Code|, CODE, READONLY, PIC
Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Services
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:Sprite
        GET     Hdr:VduExt
        GET     Hdr:Proc
        GET     Hdr:Variables
        GET     Hdr:MsgTrans
        GET     Hdr:MsgMenus
        GET     Hdr:ResourceFS
        GET     Hdr:ShareD

        GET     VersionASM

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                GBLL    debug
debug           SETL    False

        GET     Hdr:HostFS
        GET     Hdr:Debug

                GBLL    Host_Debug
Host_Debug      SETL    debug:LAND:True

                GBLL    DragsToIconBar  ; RML: Are drags from save boxes/filer windows
DragsToIconBar  SETL    {TRUE}          ;      to our icon allowed?

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Register names
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; sp            RN      r13             ; FD stack
; wp            RN      r12

y1              RN      r9
x1              RN      r8
y0              RN      r7
x0              RN      r6

; r0,r1 not named

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Constants
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

TAB     *       9
LF      *       10
CR      *       13
space   *       32
delete  *       127

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

bignum          *       &0FFFFFFF

initbrx         *       100
initbry         *       1024-80

brxoffset       *       64
bryoffset       *       64

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Workspace allocation
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                ^       0, wp
mytaskhandle    #       4               ; id so we can kill ourselves
FilerHandle     #       4               ; id so we can contact Filer
privateword     #       4

message_file_block  #   16              ; MessageTrans file handle
message_file_open   #   4               ; Flag to say that the file is open

; OSS 16 bytes for caching the icon bar text. This is so that if the
; Messages file goes away AND doesn't come back, we can still display
; the old version safely on the icon bar. With the menus we can refuse
; to display them, but with the icon bar it is best for the icon to hang
; around even if the text in it is in the wrong language. At least the
; punter will still be able to get at his files.

icon_text       #       16      ; If you change this number, change the
end_icon_text   #       0       ; length comment in the Messages file too.

; OSS Flag so that service call handlers can tell the wimp task to re-make
; the menus and icon-bar icon on the next wimp poll. This is used as a high
; priority wimp poll word, so we always find out the file has changed BEFORE
; the wimp tries to redraw anything.

message_file_changed #  4

; OSS Flag that says whether the messages file is OK or not, so we know
; whether it is safe to put the menu up since the menu has pointers into
; the file in the RMA.

message_file_invalid #  4

mousedata       #       0
mousex          #       4
mousey          #       4
buttonstate     #       4
windowhandle    #       4
iconhandle      #       4

menuhandle      #       4
menudir         #       4
menufileblock   #       4
menufilename    #       4

windowx         #       4
windowy         #       4

relmousex       #       4
relmousey       #       4

iconbaricon     #       4
                                         ; the one the user sees
mb_namedisc     #       11               ; 10 bytes text + 1 byte terminator
                #       1                ; align
mb_tempdisc     #       11
                #       1
;
ram_menustart   #       0
m_ramfs         #       m_headersize + mi_size * 4      ; Three menu entries
name_menustart  #       0
m_nameit        #       m_headersize + mi_size * 1      ; Just the one
share_menustart #       0
m_shareit       #       m_headersize + mi_size * 3      ; Also 3 entries
ram_menuend     #       0
;
userdata_size   *       &200
userdata        #       userdata_size
end_userdata    #       0

filenamebuffer  #       &100

stackbot        #       &100
stacktop        #       0

RAMFSFiler_WorkspaceSize *  :INDEX: @

 ! 0, "RAMFSFiler workspace is ":CC:(:STR:(:INDEX:@)):CC:" bytes"

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module header
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 ASSERT (.=Module_BaseAddr)

        DCD     RAMFSFiler_Start        -Module_BaseAddr
        DCD     0 ; No initialisation entry
        DCD     RAMFSFiler_Die          -Module_BaseAddr
        DCD     RAMFSFiler_Service      -Module_BaseAddr
        DCD     RAMFSFiler_TitleString  -Module_BaseAddr
        DCD     RAMFSFiler_HelpString   -Module_BaseAddr
        DCD     RAMFSFiler_CommandTable -Module_BaseAddr
        DCD     0 ; No SWI chunk
        DCD     0
        DCD     0
        DCD     0
 [ International_Help <> 0
        DCD     message_filename        -Module_BaseAddr
 |
        DCD     0
 ]
        DCD     RAMFSFiler_ModuleFlags  -Module_BaseAddr


RAMFSFiler_HelpString
        DCB     "RAMFSFiler"
        DCB     TAB
        DCB     "$Module_MajorVersion ($Module_Date)", 0

 [ International_Help=0
Desktop_RAMFSFiler_Help
        DCB   "The RAMFSFiler provides the RAMFS icon on the icon bar, and "
        DCB   "uses the Filer to display RAMFS directories.",13,10
        DCB   "Do not use *Desktop_RAMFSFiler, use *Desktop instead.",0

Desktop_RAMFSFiler_Syntax DCB   "Syntax: *Desktop_"       ; drop through!
 |
Desktop_RAMFSFiler_Help         DCB     "HRFLDFL", 0
Desktop_RAMFSFiler_Syntax       DCB     "SRFLDFL", 0
 ]

RAMFSFiler_TitleString    DCB   "RAMFSFiler", 0


; Token for banner to be looked up in Messages file

RAMFSFiler_Banner_Token   DCB   "Banner", 0



RAMFSFiler_CommandTable ; Name Max min

RAMFSFiler_StarCommand
        Command Desktop_RAMFSFiler,     0, 0, International_Help

        DCB     0                       ; End of table
        ALIGN

RAMFSFiler_ModuleFlags DCD ModuleFlag_32bit

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Had *command to enter RAMFSFiler, so start up via module handler

Desktop_RAMFSFiler_Code Entry

        LDR     r12, [r12]
        CMP     r12, #0
        BLE     %FT01

        MOV     r0, #ModHandReason_Enter
        ADR     r1, RAMFSFiler_TitleString
        SWI     XOS_Module
01
        ADR     r0, ErrorBlock_CantStartRAMFSFiler
        ADR     r1, RAMFSFiler_TitleString
        BL      copy_error_one          ; Always sets the V bit
        EXIT

ErrorBlock_CantStartRAMFSFiler
        DCD     0
        DCB     "UseDesk", 0
        ALIGN


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Table of service calls we want

        ASSERT  Service_Reset > Service_Memory

ServiceTable
        DCD     0
        DCD     ServiceUrsula - Module_BaseAddr
        DCD     Service_Reset
        DCD     Service_StartFiler
        DCD     Service_StartedFiler
        DCD     Service_FilerDying
        DCD     Service_MessageFileClosed
        DCD     Service_ShutDown
        DCD     0
        DCD     ServiceTable - Module_BaseAddr


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

RAMFSFiler_Service ROUT

        MOV     r0, r0                  ; Indicates there is a service call table

; OSS Changed to be as fast as possible in the case that we are not
; interested, which is true 99% of the time.

        TEQ     r1, #Service_Reset
        TEQNE   r1, #Service_MessageFileClosed
        TEQNE   r1, #Service_FilerDying
        TEQNE   r1, #Service_StartFiler
        TEQNE   r1, #Service_StartedFiler
        TEQNE   r1, #Service_ShutDown
        MOVNE   pc, lr

ServiceUrsula

        TEQ     r1, #Service_Reset
        BEQ     RAMFSFiler_Service_Reset

        TEQ     r1, #Service_MessageFileClosed
        BEQ     RAMFSFiler_Service_MessageFileClosed

        TEQ     r1, #Service_FilerDying
        BEQ     RAMFSFiler_Service_FilerDying

        TEQ     r1, #Service_StartFiler
        BEQ     RAMFSFiler_Service_StartFiler

        TEQ     r1, #Service_ShutDown
        BEQ     RAMFSFiler_Service_Shutdown

; *** Drops through here - StartedFiler is the only one left ***

RAMFSFiler_Service_StartedFiler Entry

        LDR     r14, [r12]              ; cancel 'don't start' flag
        CMP     r14, #0
        MOVLT   r14, #0
        STRLT   r14, [r12]

        EXIT

RAMFSFiler_Service_Shutdown
        STMDB   sp!, {r0-r5, lr}
        LDR     r12, [r12]
        MOV     R0,#OSFile_ReadInfo
        ADRL    R1,ramfile              ; R1 -> "ram::0.$.*" (assume 1 drive)
        SWI     XOS_File                ; R0 = 0 => RAM filing system is empty
        MOVVS   R0,#0
        CMP     R0,#0                   ; CLRV  ; see if it's empty
        LDMEQIA sp!, {r0-r5, pc}
        ADRL    r1, ramfsnotempty               ; Token.
        ADR     r2, userdata+4                  ; Use our buffer for string.
        MOV     r3, #(end_userdata-userdata)-4  ; Buffer length
        BL      lookup_nopars                   ; Get the string.
        ADRVC   r0, userdata                    ; Success, so turn string
        MOVVC   r1, #1                          ; into an error block
        STRVC   r1, [r0]                        ; (error number 1 - why?).

        MOV     r1, #2_00010011         ; OK (highlight)/Cancel/no "Error from"
        BL      ReportError
        TEQ     R1,#1                   ; unless OK selected, forget it
        LDMIA   sp!, {r0-r5, lr}
        MOVNE   R1,#0
        MOV     pc,lr

RAMFSFiler_Service_StartFiler Entry "r2,r3,r6"

        LDR     r2, [r12]
        CMP     r2, #0
        EXIT    LT                      ; don't claim service unless = 0
        BEQ     %FT01
        BL      testramfs               ; Z set => ramfs exists
        BNE     %FT02                   ; otherwise start up (kill ramfsfiler)
        EXIT                            ; NB: we've already got the block!
01
        MOV     r6, r0                  ; Filer task handle
        MOV     r0, #ModHandReason_Claim
        LDR     r3, =RAMFSFiler_WorkspaceSize
        SWI     XOS_Module
        MOVVS   r2, #-1                 ; avoid looping
        STR     r2, [r12]

        MOVVC   r0, #0
        STRVC   r0, [r2, #:INDEX:message_file_open]     ; Messages file closed
        STRVC   r0, [r2, #:INDEX:mytaskhandle]
        STRVC   r0, [r2, #:INDEX:icon_text]             ; No icon text yet
        STRVC   r0, [r2, #:INDEX:message_file_changed]  ; File is ok (closed!)
        STRVC   r12, [r2, #:INDEX:privateword]
        STRVC   r6, [r2, #:INDEX:FilerHandle]
02
        ADRVCL  r0, RAMFSFiler_StarCommand
        MOVVC   r1, #0                  ; Claim service

        EXIT



RAMFSFiler_Service_Reset Entry "r0-r6"

        LDR     r2, [r12]               ; cancel 'don't start' flag
        CMP     r2, #0
        MOVLT   r2, #0
        STRLT   r2, [r12]

        MOVGT   wp, r2
        MOVGT   r0, #0                  ; Wimp has already gone bye-bye
        STRGT   r0, mytaskhandle
        BLGT    freeworkspace

        EXIT                            ; Sorry, but no can do errors here


RAMFSFiler_Service_MessageFileClosed Entry "r0"

        LDR     r12, [r12]              ; are we active?
        CMP     r12, #0
        EXIT    LE                      ; No, so exit.

 [ debug
        DLINE   "Our message file closed"
 ]
        MOV     r0, #1                  ; Tell the wimp task about it
        STR     r0, message_file_changed
        STR     r0, message_file_invalid; File is no good now
        EXIT


RAMFSFiler_Die ROUT                     ; Module die entry - free worspace
RAMFSFiler_Service_FilerDying Entry "r0-r6"

        LDR     wp, [r12]
        BL      freeworkspace

        CLRV
        EXIT                            ; Sorry, but no can do errors here


; Corrupts r1-r6. MUST preserve r0, but not V bit.

freeworkspace ROUT

        CMP     wp, #0
        MOVLE   pc, lr

        MOV     r6, lr                  ; can't use stack on exit if USR mode
        MOV     r5, r0                  ; Save any error pointer

        MOV     r0, #0
        ADR     r1, mb_tempdisc
        SWI     XShareD_StopShare       ; ignore errors,it might not be shared

        LDR     r0, mytaskhandle
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown         ; ignore errors from this

        BL      close_message_file      ; can use the stack until block freed

        MOV     r2, r12
        LDR     r12, privateword
        MOV     r14, #0                 ; reset flag word anyway
        STR     r14, [r12]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        MOV     r0, r5                  ; Restore any error
        MOV     pc, r6                  ; Return

taskidentifier
        DCB     "TASK"                  ; Picked up as a word

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        ALIGN

CloseDownAndExit ROUT

        BL      freeworkspace
        SWI     OS_Exit


; List of Wimp messages that we are interested in.

MessagesList
        DCD     Message_HelpRequest
        [ DragsToIconBar
        DCD     Message_DataSave
        DCD     Message_DataLoad
        ]
        DCD     Message_Quit            ; Zero ie. terminates the list


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   RAMFSFiler application entry point
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; banner_abort_error() should be called to report an error when there is a
; good chance that the 'RAMFSBanner' token can be found in the Messages file.

banner_abort_error
        MOV     r1, #2_010              ; 'Cancel' button
        BL      ReportError             ; stack is still valid here

; ** Drop through **

abort_quietly
        BL      freeworkspace           ; exits with r12 --> private word
        MOV     r0, #-1
        STR     r0, [r12]               ; marked so doesn't loop
        SWI     OS_Exit


; OSS This is for reporting errors and dying when the banner cannot be found.

no_banner_abort_error
        BL      freeworkspace           ; exits with r12 --> private word
        MOV     r1, #-1
        STR     r1, [r12]               ; marked so doesn't loop
        SWI     OS_GenerateError        ; Never returns


; OSS We have a problem in this routine. We have no workspace, and since we
; are in User mode we have no stack either. Easiest solution is to drop
; into SVC mode to get some stack so we can open the Messages file to
; translate the error.

start_abort_error_no_stack
        SWI     XOS_EnterOS             ; Give me some stack man!
        ADRVC   r0, ErrorBlock_CantStartRAMFSFiler
        ADRVCL  r1, RAMFSFiler_TitleString
        BLVC    copy_error_one
        SWI     OS_GenerateError        ; Never returns (thank God!)

ErrorBlock_RAMFSFilerActive
        DCD     0
        DCB     "FActive", 0
        ALIGN

RAMFSFiler_Start ROUT

        LDR     wp, [r12]
        CMP     wp, #0
        BLE     start_abort_error_no_stack

        ADRL    sp, stacktop            ; STACK IS NOW VALID!

        BL      testramfs
        BNE     abort_quietly           ; forget it if no ram: present!

        LDR     r0, mytaskhandle        ; close any previous incarnation
        CMP     r0, #0
        ADRGT   r0, ErrorBlock_RAMFSFilerActive
        MOVGT   r1, #0
        BLGT    copy_error_one
        SWIVS   OS_GenerateError

        addr    r1, RAMFSFiler_Banner_Token
        ADR     r2, userdata            ; Use my buffer please
        MOV     r3, #end_userdata-userdata      ; Size of buffer
        BL      lookup_nopars           ; Open file and lookup banner
        BVS     no_banner_abort_error   ; Moan and quit if no file/token

; r2 now points to the banner
        MOV     r0, #300                ; has messages list
        LDR     r1, taskidentifier
        ADR     r3,MessagesList
        SWI     XWimp_Initialise        ; OSS There is another Wimp_Init later
        STRVC   r1, mytaskhandle

        BLVC    copy_menus              ; Translate menu tree (indirect items)
        ADD     r14, pc, #4
        STR     r14, [r13,#-4]!         ; fake up a return address for EXIT
        BLVC    go_unshare

; find out what the RAM disc is called at present
        MOVVC   r0, #37
        ADRVCL  r1, ramfs_media_name
        ADRVC   r2, userdata
        MOVVC   r3, #0
        MOVVC   r4, #0
        MOVVC   r5, #userdata_size
        SWIVC   XOS_FSControl
        BVS     banner_abort_error
        ADR     r1, mb_namedisc
        ADD     r2, r2, #5              ; skip the RAM:: bit
05
        LDRB    r3, [r2], #1
        TEQ     r3, #'.'
        MOVEQ   r3, #0
        ASSERT  (mb_tempdisc-mb_namedisc)=12
        STRB    r3, [r1, #12]
        STRB    r3, [r1], #1
        BNE     %BT05

        BLVC    AllocateIcon
        BVS     banner_abort_error      ; frees workspace but marks it invalid

; ............................................................................
; The main polling loop!

repollwimp ROUT

        MOVVS   r1, #2_001              ; 'Ok' button
        BLVS    ReportError
        BVS     banner_abort_error      ; error from reporterror!

; Disable as many events that we are not interested in as is possible
; and reasonable, without invoking queuing. Also, enable the fast poll word.

        LDR     r0, =(null_bit + pointerchange_bits + pollwordfast_enable)
        ADR     r1, userdata
        ADR     r3, message_file_changed        ; Address of poll word
        SWI     XWimp_Poll
        BVS     repollwimp              ; Handle any error

; In    r1 -> wimp_eventstr

        ADR     lr, repollwimp

        CMP     r0, #PollWord_NonZero
        BEQ     event_poll_word_non_zero

        CMP     r0, #Mouse_Button_Change
        BEQ     event_mouse_click

        CMP     r0, #Menu_Select
        BEQ     event_menu_select

        CMP     r0, #User_Message
        CMPNE   r0, #User_Message_Recorded
        BEQ     event_user_message

        B       repollwimp

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Our poll word (high priority) went non zero. This means the messages file
; has gone away or comer back or both. Thus we try to open the new one,
; re-make the menu tree, change our task name, and re-read the icon text.

event_poll_word_non_zero Entry

 [ debug
        DLINE   "Poll word went non-zero"
 ]
        BL      copy_menus
        MOV     r2, #0                   ; Flag that OK now (may not be but
        STR     r2, message_file_changed ; we tried and failed in that case).
        EXIT    VS

; If we got this far, the Messages file is almost certainly in a fairly
; sane state, so it is now safe to try to change our task name. To do this,
; I do a Wimp_CloseDown and then a Wimp_Initialise. I get the task name
; up front and hang on to it, so that once I have started I am guaranteed
; of being able to finish. I don't want to do a CloseDown only to find
; on return that the Wimp let someone else in (unlikely) and now I can't
; do the Wimp_Initialise!

        addr    r1, RAMFSFiler_Banner_Token
        ADR     r2, userdata            ; Use my buffer please
        MOV     r3, #end_userdata-userdata      ; Size of buffer
        BL      lookup_nopars           ; Lookup banner
        EXIT    VS                      ; Rats - couldn't get the banner.

; We have the new banner, so do the CloseDown.

        LDR     r0, mytaskhandle
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown         ; Ignore errors from this.

; Now do the Initialise.

        MOV     r0, #300                ; has messages list
        LDR     r1, taskidentifier
        ADR     r2, userdata
        ADR     r3, MessagesList
        SWI     XWimp_Initialise
        MOVVS   r1, #0                  ; Error, so set task handle to zero.
        STR     r1, mytaskhandle
        EXIT    VS                      ; Bad scene.

; At this point we have lost our icon on the icon bar. This is OK, as I need
; to change the text in it anyway. The only other way (if we didn't bounce
; the wimp task) would be to delete the icon and then re-create it.

        BL      AllocateIcon
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_mouse_click
; =================

; In    r1 -> wimp_eventstr
;             [r1, #0]  pointer x
;             [r1, #4]          y
;             [r1, #8]  new button state
;             [r1, #12] window handle (-1 if background/icon bar)
;             [r1, #16] icon handle (-1 if none)

; Out   all regs may be corrupted - going back to PollWimp

event_mouse_click Entry

        LDMIA   r1, {r0-r4}             ; set mousex, mousey, buttonstate
        ADR     r14, mousedata          ; windowhandle, iconhandle
        STMIA   r14, {r0-r4}
 [ debug
 DREG r2, "mouse_click: buttonstate ",cc,Word
 DREG r0, ", x ",cc,Integer
 DREG r1, ", y ",cc,Integer
 DREG r3, ", window ",,Word
 ]

        CMP     r3, #iconbar_whandle    ; window handle of icon bar
        EXIT    NE

        TST     r2, #button_left :OR: button_right ; select or adjust ?
        BNE     click_select_iconbar

        TST     r2, #button_middle      ; menu ?
        BNE     click_menu_iconbar

        EXIT

; .............................................................................
; We get here if the user has double-clicked on a FS icon

; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select_iconbar ROUT

; Try to open dir using Filer

        MOV     r0, #User_Message_Recorded
        ADR     r1, ramfsmessage
        LDR     r2, FilerHandle
 [ debug
 DREG r2, "click select: Filer handle "
 ]
        SWI     XWimp_SendMessage
        EXIT

ramfsmessage
        DCD     messageend-ramfsmessage
        DCD     0                       ; filled in by Wimp
        DCD     0                       ; filled in by Wimp
        DCD     0
        DCD     Message_FilerOpenDir
        DCD     fsnumber_ramfs          ; filing system number
        DCD     0                       ; please canonicalise the pathname for me
        DCB     "RAM::0.$", 0           ; pathname
        ALIGN
messageend

; Offsets of fields in a message block

                ^       0
message_size    #       4
message_task    #       4               ; filled in by Wimp
message_myref   #       4               ; filled in by Wimp
message_yourref #       4
message_action  #       4
message_hdrsize *       @
message_data    #       0               ; words of data to send

; ............................................................................
; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_menu_iconbar ROUT

        ADR     r1, m_ramfs
        BL      CreateMenu

        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A menu is created with the title above the x,y values you feed it, with the
; top left hand corner being at the x,y position

CreateMenu Entry "r2, r3"

; OSS If file is invalid, then try to get it. This will usually result in
; us getting the same error again.



        LDR     r2, message_file_invalid
        TEQ     r2, #0
        BLNE    copy_menus
        EXIT    VS

        STR     r1, menuhandle
        Push    "r1"

        MOV     r0, #ModHandReason_LookupName    ; call OS_Module 18 to check if ShareD
        ADR     r1, Sharemodule                  ; module has been loaded; if not, then
        SWI     XOS_Module                       ; shade share entry in the RAMFS menu
        LDR     r1, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_iconflags
        ORRVS   r1, r1, #is_shaded
        BICVC   r1, r1, #is_shaded
        STR     r1, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_iconflags

        LDR     r1, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_itemflags
        TST     r1, #mi_it_tick
        LDR     r1, m_ramfs+m_headersize+mi_size*mo_fl_namedisc+mi_iconflags
        ORRNE   r1, r1, #is_shaded
        BICEQ   r1, r1, #is_shaded
        STR     r1, m_ramfs+m_headersize+mi_size*mo_fl_namedisc+mi_iconflags

        Pull    "r1"
        LDR     r2, mousex
        SUB     r2, r2, #4*16
        MOV     r3, #96 + 4*44
        SWI     XWimp_CreateMenu
        EXIT

Sharemodule     DCB     "ShareFS"
                DCB     0
                ALIGN


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_menu_select
; =================

; In    r1 -> wimp_eventstr

; Out   all regs may be corrupted - going back to PollWimp

event_menu_select Entry
        MOV     r2, r1
        SUB     sp, sp, #b_size
        MOV     r1, sp
        SWI     XWimp_GetPointerInfo
        LDRVC   r1, menuhandle
        BLVC    DecodeMenu
        LDRVC   r1, [sp, #b_buttons]
        ADD     sp, sp, #b_size
        EXIT    VS
        TST     r1, #button_right
        BNE     click_menu_iconbar              ; expects LR on stack
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In     r1 = menu handle
;        r2 -> list of selections

DecodeMenu Entry

 [ debug
 DREG r1, "menu_select: menu handle ",cc
 LDR r14, [r2]
 DREG r14, ", selections ",cc
 LDR r14, [r2, #4]
 DREG r14, ", "
 ]

        LDR     r14, [r2, #4]
        CMP     r14, #-1
        LDR     r14, [r2]
        BEQ     decodelp

        CMP     r14, #1
        BNE     go_nd_namedisc

decodeshare
        LDR     r14, [r2, #4]
        ADD     pc, pc, r14, LSL #2
        EXIT                            ; selection = -1
        B       go_unshare
        B       go_shareprot
        B       go_shareunprot

decodelp
        ADD     pc, pc, r14, LSL #2

        EXIT                            ; selection = -1
        EXIT                            ; selection = 0 (name submenu)
        EXIT                            ; selection = 1 (share submenu)
        B       go_fl_free              ; selection = 2
                                        ; selection = 3 (fall through)

go_fl_quit
        MOV     R0,#OSFile_ReadInfo
        ADR     R1,ramfile              ; R1 -> "ram::0.$.*" (assume 1 drive)
        SWI     XOS_File                ; R0 = 0 => RAM filing system is empty
        MOVVS   R0,#0
        CMP     R0,#0                   ; CLRV  ; see if it's empty
        BEQ     %FT01

        ADR     r1, ramfsnotempty               ; Token.
        ADR     r2, userdata+4                  ; Use our buffer for string.
        MOV     r3, #(end_userdata-userdata)-4  ; Buffer length
        BL      lookup_nopars                   ; Get the string.
        ADRVC   r0, userdata                    ; Success, so turn string
        MOVVC   r1, #1                          ; into an error block
        STRVC   r1, [r0]                        ; (error number 1 - why?).

        MOV     r1, #2_00010011         ; OK (highlight)/Cancel/no "Error from"
        BL      ReportError
        TEQ     R1,#1                   ; unless OK selected, forget it
        EXIT    NE
01
        ADR     r0, filerclosecommand
        SWI     XOS_CLI

        MOV     R0,#ModHandReason_ReInit
        ADR     R1,ramfstitle
        SWI     XOS_Module

        MOV     R0,#5                   ; RAM disc memory area
        MOV     R1,#&80000000           ; -2GB
        SWI     XOS_ChangeDynamicArea   ; ignore errors

        B       CloseDownAndExit

ramfsnotempty
        DCB     "HasData", 0
messagefromramfsfiler
        DCB     "RFSMess", 0
ramfile
        DCB     "RAM::0.$.*", 0
ramfstitle
        DCB     "RAMFS", 0
filerclosecommand
        DCB     "%Filer_CloseDir RAM::0", 0
        ALIGN
error_namedisc  
        DCD     1
        DCB     "TooShrt",0
namedisccmnd
        DCB     "-RAM-namedisc 0 ",0
        ALIGN

go_nd_namedisc
        LDRB    r14, mb_namedisc        ; check that new name is >= 2 chars
        CMP     r14, #32
        LDRHSB  r14, mb_namedisc+1
        CMPHS   r14, #32
        ADRLO   r0, error_namedisc
        MOVLO   r1, #0
        BLLO    copy_error_one
        EXIT    VS

        ; Copy new validated disc name at mb_namedisc
        ASSERT  (?mb_namedisc + 1)=12
        ASSERT  (mb_tempdisc - mb_namedisc)=12
        ADR     r0, mb_namedisc
        LDMIA   r0!, {r1-r3}
        STMIA   r0, {r1-r3}

        ; Shut any stale viewers
        ADR     r0, filerclosecommand
        SWI     XOS_CLI

        ; Do the dead
        ADR     r1, userdata
        ADRL    r2, namedisccmnd        ; Build a *Namedisc command
        BL      strcpy_advance
        ADR     r2, mb_tempdisc
        BL      strcpy_advance
        ADR     r0, userdata
        SWI     XOS_CLI

        CLRV
        EXIT

go_fl_free
        ADR     r0, freecommand
        SWI     XWimp_CommandWindow
        EXIT    VS
        ADR     r0, freecommand
        SWI     XOS_CLI
        BVC     %FT01

        SWI     XOS_NewLine
        ADD     r0, r0,#4
        SWI     XOS_Write0
        SWI     XOS_NewLine

01
        MOV     r0, #0
        SWI     XWimp_CommandWindow
        EXIT

freecommand     DCB     "ShowFree -FS RAM 0", 0
                ALIGN

go_unshare ROUT
        MOV     r0, #0
        ADRL    r1, mb_tempdisc
        SWI     XShareD_StopShare
        ADR     r2, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_itemflags
        LDR     r1, [r2]
        BIC     r1, r1, #mi_it_tick
        STR     r1, [r2]                ; untick the top level
        ADR     r3, m_shareit+m_headersize+mi_size*mo_ss_notshd+mi_itemflags
        B       %FT05

go_shareprot
        MOV     r0, #1                  ; flags are share protected
        ADR     r3, m_shareit+m_headersize+mi_size*mo_ss_shdprot+mi_itemflags
        B       %FT03

go_shareunprot
        MOV     r0, #0                  ; flags are share unprotected
        ADR     r3, m_shareit+m_headersize+mi_size*mo_ss_shdunprot+mi_itemflags
03
        ADR     r2, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_itemflags
        LDR     r1, [r2]
        ORR     r1, r1, #mi_it_tick
        STR     r1, [r2]                ; tick the top level

        ADRL    r1, mb_tempdisc         ; the last "OK"d disc name
        ADRL    r2, ramfs_media_name
        SWI     XShareD_CreateShare
05

ticksharemenu
        ; In:  r3 -> item to tick
        ; Out: all registers preserved
        Push    "r1,r2"
        ADR     r1, m_shareit+m_headersize+mi_itemflags
        LDR     r2, [r1]
        BIC     r2, r2, #mi_it_tick
        STR     r2, [r1], #mi_size
        LDR     r2, [r1]
        BIC     r2, r2, #mi_it_tick
        STR     r2, [r1], #mi_size
        LDR     r2, [r1]
        BIC     r2, r2, #mi_it_tick
        STR     r2, [r1], #mi_size      ; untick all entries

        LDR     r2, [r3]
        ORR     r2, r2, #mi_it_tick     ; tick the specified one
        STR     r2, [r3]
        Pull    "r1,r2"
        CLRV
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Code to test RAMFS existence.
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Out   EQ ==> ramfs exists, NE ==> doesn't
;       all regs preserved

testramfs Entry   "r0-r2"
        BL      readfs
        MOV     r3, r0                  ; r3 = original fs
        MOV     r2, #0
        BL      writefs                 ; write fs 0
        MOV     r2, #23 ;fsnumber_ramfs
        BL      writefs                 ; try fs in question
        BL      readfs
        MOV     r1, r2
        MOV     r2, r3
        BL      writefs                 ; re-write original fs
        TEQ     r0, r1                  ; did it work?
        EXIT

readfs  Entry   "r1-r2"
        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_Args
        EXIT                            ; r0 = current fs

writefs Entry   "r0-r2"
        MOV     r0, #&8F                ; try filing system r2
        MOV     r1, #18
        SWI     XOS_Byte
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   VC => r0 = icon index, flags trashed
;       VS => r0 -> error, flags trashed

;                          r6  r7  r8  r9

AllocateIcon Entry "r1-r4, x0, y0, x1, y1, r10"

; OSS Size can depend on text, so do the lookup now before we run into
; register use problems.

        ADR     r1, ic_text_token               ; Token.
        ADR     r2, icon_text                   ; Buffer in workspace.
        MOV     r3, #end_icon_text-icon_text    ; Length of buffer.
        BL      lookup_nopars                   ; Get real icon text.
        EXIT    VS
        MOV     r10, r3                         ; Save length for later

        MOV     r0, #SpriteReason_ReadSpriteSize
        ADR     r2, ic_spritename               ; r2 -> sprite name
        SWI     XWimp_SpriteOp                  ; r3, r4 = pixel size
        MOVVC   r0, r6                          ; creation mode of sprite

        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        EXIT    VS

        MOV     x0, #0
        ADD     x1, x0, r3, LSL r2              ; pixel size depends on sprite
        CMP     x1, r10, LSL #4                 ; Compare with length*16
        MOVLT   x1, r10, LSL #4                 ; allow for text width

        MOV     r1, #VduExt_YEigFactor
        SWI     XOS_ReadModeVariable
        EXIT    VS

        MOV     y0, #20                         ; sprite baseline
        ADD     y1, y0, r4, LSL r2
        MOV     y0, #-16                        ; text baseline

        ADR     r14, userdata
        MOV     r0, #-6                       ; lhs of icon bar, with priority
        STMIA   r14!, {r0, x0, y0, x1, y1}      ; window handle, icon coords

        LDR     r0, ic_flags
        ADR     r1, icon_text                   ; Local buffered icon text
        ADR     r2, ic_validation
        MOV     r3, r10                         ; Get text length back
        STMIA   r14, {r0-r3}                    ; icon flags, data

        LDR     r0, =WimpPriority_RAMFS
        ADR     r1, userdata
        SWI     XWimp_CreateIcon

        STRVC   r0, iconbaricon                 ; Save the icon handle.
        EXIT

        LTORG

ic_flags        DCD     &1700310B       ; sprite + text, h-centred, indirected
                                        ; button type 3
                                        ; fcol 7, bcol 1

ic_text_token   DCB     "IconTxt",0
ic_validation   DCB     "S"
ic_spritename   DCB     "ramfs",0
                ALIGN

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_user_message (and _recorded)
; ==================

; In    r1 -> wimp_eventstr
;             [r1, #0]     block size
;             [r1, #12]    your ref
;             [r1, #16]    message action
;             [r1, #20...] message data

; Out   all regs may be corrupted - going back to PollWimp

event_user_message Entry

        LDR     r0, [r1, #message_action]

        LDR     r14, =Message_HelpRequest
        CMP     r0, r14
        BEQ     returnhelp

        [ DragsToIconBar
        LDR     r14, =Message_DataSave
        CMP     r0, r14
        BEQ     message_datasave

        LDR     r14, =Message_DataLoad
        CMP     r0, r14
        BEQ     message_dataload
        ]

        CMP     r0, #Message_Quit
        EXIT    NE

        B       go_fl_quit
;       NOEXIT


;............................................................................
; In    r1 -> message block containing help request
;       LR stacked
; Out   Message_HelpReply sent

returnhelp
        LDR     r2, [r1, #ms_data + b_window]
        LDR     r3, [r1, #ms_data + b_icon]

        CMP     r2, #iconbar_whandle    ; try iconbar icon
        MOVEQ   r0, #"F"
        BEQ     %FT08

        CMP     r3, #0                  ; no help if not on an item
        BLT     %FT99

        Push    "r1, r2-r4"
        ADD     r1, sp, #4              ; r1 -> buffer for result
        MOV     r0, #1
        SWI     XWimp_GetMenuState
        Pull    "r1, r2-r4"             ; r2, r3 = menu selections
        BVS     %FT99

        CMP     r3, #-1
        BEQ     %FT02                   ; top level menu
        CMP     r2, #0
        MOVEQ   r2, #"E"-"1"
        ADDNE   r2, r3, #4              ; share submenu
        B       %FT06
02
        TEQ     r2, #0
        BNE     %FT04
        LDR     r0, m_ramfs+m_headersize+mi_size*mo_fl_namedisc+mi_iconflags
        TST     r0, #is_shaded
        MOVNE   r2, #"G"-"1"

04      TEQ     r2, #1
        BNE     %FT06
        LDR     r0, m_ramfs+m_headersize+mi_size*mo_fl_share+mi_iconflags
        TST     r0, #is_shaded
        MOVNE   r2, #"N"-"1"
06
        ADD     r0, r2, #"1"            ; NB: item -1 is translated into 0
08
        ADD     r2, r1, #ms_data        ; r2 -> output buffer
        MOV     r3, #256-ms_data        ; r3 = buffer size
        Push    "r0"
        MOV     r1, sp                  ; r1 -> char, 0
        BL      lookup_nopars           ; sets r4..r7=0 automatically
        ADD     sp, sp, #4

        SUBVC   r1, r2, #ms_data
        ADDVC   r3, r3, #4 + ms_data    ; include terminator
        BICVC   r3, r3, #3
        STRVC   r3, [r1, #ms_size]
        LDRVC   r14, [r1, #ms_myref]
        STRVC   r14, [r1, #ms_yourref]
        LDRVC   r14, =Message_HelpReply
        STRVC   r14, [r1, #ms_action]
        MOVVC   r0, #User_Message
        LDRVC   r2, [r1, #ms_taskhandle]
        SWIVC   XWimp_SendMessage
99
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcpy_advance
; ==============

; In    r1 -> dest string
;       r2 -> source string

; Out   r1 -> terminating null

strcpy_advance Entry "r2"

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, #space-1           ; Any char < space is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        SUB     r1, r1, #1
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In:   r0 -> error block
;       r1 = state for ReportError

; Out:  r1 = What buttons pressed

ReportError Entry "r2-r5"
        MOV     r4, r0                          ; Save error
        ADDS    r5, r1, #0                      ; Save flags; clear V to lookup token.

        addr    r1, RAMFSFiler_Banner_Token     ; Token for banner.
        MOV     r2, #0                          ; Direct pointer please.
        BL      lookup_nopars
        addr    r2, RAMFSFiler_Banner_Token, VS ; Token is banner on error.

        MOV     r1, r5                          ; Get flags back.
        MOV     r0, r4                          ; Get error back.
        SWI     XWimp_ReportError
        EXIT

        LTORG


 [ DragsToIconBar
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; message_datasave
;
; handles the datasave message for when a user drags a file onto an iconbar icon
; to save.
;
; In: r1 -> wimp event structure
;
; Out : registers may be corrupted - going back to wimp poll.

message_datasave

        MOV     r5, r1                   ; Stick r1 into r5 for later

        ; Copy the name specified in the message to the filenamebuffer
        Push    "r1"
        ADR     r1, filenamebuffer
        ADD     r2, r5, #44
        BL      strcpy_advance
        Pull    "r1"

        ; Make up a filename
        ADR     r2, ramfspath
        ADD     r1, r5, #44
        BL      strcpy_advance
        ADR     r2, mb_tempdisc
        BL      strcpy_advance
        MOV     r2, #'.'
        STRB    r2, [r1], #1
        MOV     r2, #'$'
        STRB    r2, [r1], #1
        MOV     r2, #256                 ; maximum length for append_dotdefaultdir 
        STRB    r2, [r1]
        BL      append_dotdefaultdir     ; add '.<RAMFiler$DefaultDir>' (if it exists)
        MOV     r0, #46
        STRB    r0, [r1], #1             ; add a '.'
        ADR     r2, filenamebuffer
        BL      strcpy_advance

        ; send a DataSaveAck message specifying the new pathname
        MOV     r1, r5                   ; put wimp event structure pointer back in r1
        MOV     r0, #256
        STR     r0, [r1]
        LDR     r0, [r1, #8]
        STR     r0, [r1, #12]            ; Your ref.
        MOV     r0, #Message_DataSaveAck
        STR     r0, [r1, #16]            ; Message action
        LDR     r2, [r1, #4]             ; task handle of sender (to send back to)
        MOV     r0, #17                  ; event code
        SWI     XWimp_SendMessage

        Pull    "pc"

ramfspath       DCB "RAM::",0
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; message_dataload
;
; handles dataload messages
;
; In: r1 -> wimp event structure
;
; Out : registers may be corrupted - going back to wimp poll.

message_dataload

        LDR     r4, [r1, #24]            ; icon handle (for opening viewer)

        ; Check why we've got this message
        LDR     r0, [r1, #12]
        CMP     r0, #0
        BNE     %FT10

; Case 1: Message is because user has tried to copy a selection of files to an
; icon bar device, so send a Message_FilerDevicePath.

        LDR     r6, [r1, #4]                 ; task handle of sender (to send back to)
        MOV     r5, r1                       ; store message block pointer in r5

        MOV     r0, #256
        STR     r0, [r1]                     ; Length of message
        MOV     r0, #0
        STR     r0, [r1, #12]                ; Your ref.
        LDR     r0, =Message_FilerDevicePath ; Message action
        STR     r0, [r1, #16]                ; Message action
        ADD     r1, r5, #20
        ADR     r2, ramfspath                ; Specify RamFS media name
        BL      strcpy_advance
        ADR     r2, mb_tempdisc
        BL      strcpy_advance
        MOV     r2, #'.'
        STRB    r2, [r1], #1
        MOV     r2, #'$'
        STRB    r2, [r1], #1
        MOV     r2, #256                     ; Maximum size for default path
        STRB    r2, [r1]
        BL      append_dotdefaultdir         ; append RAMFiler$DefaultDir

        MOV     r1, r5                       ; location of message data
        MOV     r2, r6                       ; task handle of sender (to send back to)
        MOV     r0, #17                      ; event code
        SWI     XWimp_SendMessage            ; send the message
        B       %FT20

; Case 2: Message is part of a save protocol, because user has saved a file
; to an icon bar device, so send the Message_DataLoadAck.
10
        LDR     r0, [r1, #8]
        STR     r0, [r1, #12]            ; Your ref.
        MOV     r0, #Message_DataLoadAck
        STR     r0, [r1, #16]            ; Message action
        LDR     r2, [r1, #4]             ; task handle of sender (to send back to)
        MOV     r0, #17                  ; event code
        SWI     XWimp_SendMessage

; Open the directory viewer of the dir we're copying/saving to.

20
        ADR     r1,userdata
        ADRL    r2,FilerOpenDirCommand       ; Build a *Filer_OpenDir command
        BL      strcpy_advance
        ADR     r2,mb_tempdisc
        BL      strcpy_advance
        MOV     r2, #'.'
        STRB    r2, [r1], #1
        MOV     r2, #'$'
        STRB    r2, [r1], #1
        MOV     r2, #256                     ; Maximum size for default path
        STRB    r2, [r1]
        BL      append_dotdefaultdir         ; append RAMFiler$DefaultDir

        ADR     r0,userdata
        SWI     XOS_CLI                      ; Issue the command

        Pull    "pc"

ramfs_media_name DCB "RAM::0.$",0                 ; ShareFS is happy with this
FilerOpenDirCommand DCB "%Filer_OpenDir RAM::",0  ; Has the drive name appended later
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; append_dotdefaultdir
;
; Read value of RAMFiler$DefaultDir and append it to the path in r1
; (ie. does string1 becomes string1.value)
;
; In: r1 -> destination buffer
;     r2 -> size of buffer
;
; Out: r0 = corrupted
;      r1 -> next free byte in buffer
;      r2 = corrupted.
;      All other regs preserved.

append_dotdefaultdir Entry "r3-r7"

        MOV     r7, r1
        MOV     r6, r2

        ADR     r0, ramfsfiler_defaultdir
        MOV     r2, #-1
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_ReadVarVal
        CMP     r2, #0
        EXIT    EQ                       ; exit if variable doesn't exist

        MVN     r0, r2
        ADD     r0, r0, #1
        CMP     r0, r6
        EXIT    GT                       ; exit if buffer not big enough

        ADR     r0, ramfsfiler_defaultdir
        ADD     r1, r7, #1
        MOV     r2, #256
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_ReadVarVal           ; Put variable into buffer, leaving room for '.'

        ADD     r1, r1, r2
        MOV     r0, #46
        STRB    r0, [r7]                 ; Put '.' before variable's value
        MOV     r0, #0
        STRB    r0, [r1]                 ; Put NULL at end of whole string.

        EXIT

ramfsfiler_defaultdir DCB "RAMFiler$$DefaultDir",0
 ]


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GET     MsgCode.s

 [ debug
        InsertDebugRoutines
 ]

        END
