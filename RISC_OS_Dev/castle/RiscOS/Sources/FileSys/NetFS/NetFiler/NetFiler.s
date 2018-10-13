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
; > Sources.NetFiler

;;----------------------------------------------------------------------------
;; Net Filer module
;;
;; Change List
;; -----------
;; 26-May-88            Change list added, taken over by NRaine
;; 30-May-88    0.01    First working version released on the world
;;  3-Jun-88    0.02    Attempt to deal better with FS not in list problem
;; 21-Jun-88    0.03    Change to use Wimp_SpriteOp rather than BaseOfSprites
;; 27-Jun-88    0.04    Change background colour of iconbar icons to 0
;;  8-Jul-88    0.05    Use new NetFS facilities (logged-on list, service call)
;;  8-Jul-88            Change menu colours to suit GBartram's defaults
;; 11-Jul-88    0.06    Check for logon success by altering current FS number
;; 20-Jul-88    0.07    Put in code to deal with *Notify inside desktop
;; 20-Jul-88    0.08    Put in 'Free' and 'Notify' menu options
;; 29-Jul-88    0.09    Use DesktopCMOS to remember fs list options
;;  2-Aug-88    0.10    Offer Message_Notify broadcast round
;;  8-Aug-88    0.11    Logon in a separate task to allow for BASIC logons
;; 12-Aug-88            Fix bug: SELECT in fs viewer background opened :Arf
;; 12-Aug-88    0.12    When logging on, close '&' if successful before opening
;; 17-Aug-88    0.13    Fix bug: notify blocks didn't time out properly
;; 18-Aug-88    0.14    Improve error message in Desktop_NetFiler
;; 23-Aug-88    0.15    Change iconbar stuff so default icon has text under it
;; 27-Aug-88    0.16    Fix bug: notify blocks were stored in reverse order!
;;  2-Sep-88            Allow right-click in NetFiler menus
;;  2-Sep-88            Allow right-click in FS list (closes FS window)
;;  2-Sep-88            Don't call matchfsviewer unless windowhandle correct
;;  2-Sep-88    0.17    *Set Alias$<hard space>Logon net:%logon <etc>
;;                      and remember to *Unset it afterwards
;;  5-Sep-88            Redraw FS list window if list changes
;;  5-Sep-88    0.18    Change min extent of fs viewer
;; 20-Sep-88            Change to use new Make procedures
;; 10-Nov-88    0.19    Check for overflow when dealing with MonotonicTime
;; 23-May-89    0.20    Ignore Open_Window_Request for closed logon window
;; 30-May-89    0.21    Add call to NetFS_UpdateFSList when opening menu
;; 31-May-89    0.22    Alter window extent if fileserver list changes
;; 12-Jun-89    0.23    Change CMOS byte and bit allocations
;; 12-Jun-89    0.24    Change CMOS byte and bit allocations again!
;; 17-Jul-89    0.25    Fix bug in matchiconbar: leads to ghost fs icons
;;
;; =========    ====
;; 24-Sep-90    0.25 =>> Special version for level 4 fileserver with
;; =========    ====    cache_enable call (V 0.51) change
;;
;; 24-Jul-89    0.26    Treat *FS fileservers as being in *ListFS too
;;  1-Aug-89    0.27    Allow multiple columns with full info FS list
;;  1-Aug-89    0.28    Keep fileservers together with Wimp 2.21 and later
;;  2-Aug-89    0.29    Use Wimp 2.23 "poll word" facility to track logons
;; 10-Aug-89    0.30    Don't call NetFS_UpdateFSList for dummy FS
;; 30-Aug-89    0.31    Change testloggedon to check for specific error number
;;  4-Sep-89    0.32    Don't clear screen after *Free (use Wimp_CommandWindow)
;;  2-Oct-89            Change "Logon" alias so username is displayed
;;              0.33    Make WoggleIcon do nothing if no icon present
;;  4-Oct-89    0.34    Fix bug: check for UnknownStationName in testloggedon
;;  9-Oct-89    0.35    Remove 'notify' option from menu
;; 17-Oct-89    0.36    Fix bug: menu should move down a line
;;                      Remember username when logons occur (for savedesk)
;;  1-Nov-89    0.37    Check for ErrorNumber_UnknownStationNumber in testloggedon
;;  1-Nov-89    0.38    Implement interactive help
;;  3-Nov-89    0.39    Change to use MessageTrans module
;;  3-Nov-89    0.40    Use MessageTrans to create menus
;;  6-Nov-89    0.41    Fix bug: didn't close message file on exit
;;  6-Nov-89    0.42    Fix bug: reset PROC_RegList after help stuff
;; 10-Nov-89    0.43    Fix bug: reset logon submenu pointer in CopyMenus
;; 14-Nov-89            Put dotted line back into FSList submenu
;;              0.44    Display username in logon box initially
;; 16-Nov-89    0.45    Count size of "List of file servers" properly
;; 17-Nov-89    0.46    Remove initial username display from logon dbox
;;  9-Dec-89    0.47    Close "net#fsname:" on logoff, rather than "net#fsname:&"
;; 19-Feb-90    0.48    Include resource files in the module itself
;; 26-Feb-90    0.49    Use WimpPriority_Econet
;; 10-Sep-90 RM 0.50    Use *ShowFree and not *Net:%Free
;; 17-Sep-90 RM 0.51    Call NetFS_EnableCache after NetFS_EnumerateFSList/Cache
;; 08-Apr-91 RM 0.52    Added messages list and pass 300 to Wimp_Initialise.
;; 31-May-91 RM 0.53    Removed notify template.
;; 05-Jul-91 EN 0.54    Changed net#blah to net::blah in window titles
;; 16-Jul-91 EN 0.57    Text extraction
;; 22-Jul-91 EN 0.60    Stop doing Filer_CloseDir (done by NetFS/Filer)
;;                      Use Filer_OpenDir command instead of message
;; 01-Aug-91 EN 0.61    More intelligent GetPathName routine so if fs starts
;;                      with a digit it uses net#<blah> form.
;; 27-Aug-91 EN 0.64    Fixed message lookup bugs.
;; 30-Aug-91 EN 0.65    Moved Messages and Templates to Messages module
;; 04-Aug-91 EN 0.66    Added EVFF token to messages file
;; 16-Dec-91 EN 0.69    Removed cmos_fname debugging message
;; 15-Jan-92 EN 0.70    G-RO-9344 - checks for bad file name in testloggedon
;;                      G-RO-5199 - moves caret to end in writable icon
;; 15-Jan-94 NK 0.72    Made station number (in full info display) separate icon
;;                      so that fancy font desktops look tidier.
;; 29-May-97 RL 0.76    Allow file saves to root directory by dragging onto
;;                      iconbar icon.
;; 15-Jan-98 RL 0.77    Issues Message_FilerDevicePath if files are dragged onto
;;                      it's icon.
;;----------------------------------------------------------------------------

        AREA |NetFiler$$Code|, CODE, READONLY, PIC

Module_BaseAddr
        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Services
        GET     Hdr:CMOS
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:PublicWS          ; for ScratchSpace
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:Sprite
        GET     Hdr:VduExt
        GET     Hdr:Econet
        GET     Hdr:Proc
        GET     Hdr:Variables
        GET     Hdr:MsgTrans
        GET     Hdr:MsgMenus
        GET     Hdr:ResourceFS
        GET     VersionASM

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                GBLL    notify
notify          SETL    {FALSE}

                GBLL    givehelp
givehelp        SETL    {TRUE}

                GBLL    logontask
                GBLL    logontask2
logontask       SETL    {TRUE}          ; do logons in a separate task
logontask2      SETL    {TRUE}          ; get rid of woggling errorbox

                GBLL    enablecache     ; Call enable cache after fs list.
enablecache     SETL    {TRUE}          ; Set to true to make L4FS version.

                GBLL    DragsToIconBar  ; RML: Are drags from save boxes/filer windows
DragsToIconBar  SETL    {TRUE}          ;      to our icon allowed?

    [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL    {FALSE}         ; Build-in Messages file and i/f to ResourceFS
    ]

    [ :LNOT: :DEF: international_help
                GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
    ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GBLL    debug
debug   SETL    {FALSE}

        GBLL    hostvdu
hostvdu SETL    {TRUE}

                GBLL    debugndr
debugndr        SETL    {FALSE}

      [ debug                  ; NB: comment out [ ] when debug is True !!!
        GET     Hdr:Debug
        GET     Hdr:HostDebug
      ]

        GET     Hdr:NDRDebug

                GBLL    debugtask
debugtask       SETL    debug :LAND: {FALSE}

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Register names
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; sp            RN      r13             ; FD stack
; wp            RN      r12

scy             RN      r11
scx             RN      r10
y1              RN      r9
x1              RN      r8
y0              RN      r7
x0              RN      r6
cy1             RN      r5              ; Order important for LDMIA
cx1             RN      r4
cy0             RN      r3
cx0             RN      r2

; r0,r1 not named

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Macro definitions
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MACRO
        max     $a, $b
        CMP     $a, $b
        MOVLT   $a, $b
        MEND

        MACRO
        min     $a, $b
        CMP     $a, $b
        MOVGT   $a, $b
        MEND

        MACRO
$label  FixDCB  $n, $string
        ASSERT  ((:LEN:"$string")<$n)
$label  DCB     "$string"
        LCLA    cnt
cnt     SETA    $n-:LEN:"$string"
        WHILE   cnt>0
        DCB     0
cnt     SETA    cnt-1
        WEND
        MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Constants
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

TAB     *       9
LF      *       10
CR      *       13
space   *       32
delete  *       127


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

bignum          *       &0FFFFFFF

initbrx         *       100
initbry         *       1024-80

brxoffset       *       64
bryoffset       *       64


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Data structure offsets
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; masks in DesktopCMOS

cmos_sortshift  *       0
cmos_viewshift  *       2
cmos_viewmode   *       3 :SHL: cmos_viewshift
cmos_sortmode   *       1 :SHL: cmos_sortshift

                     ^  0
view_largeicons      #  1
view_smallicons      #  1
view_fullinfo        #  1

view_sortbyname      *  0
view_sortbynumber    *  1 :SHL: 4

                ^       0               ; format of fileserver block in cache
fsb_link        #       4
fsb_iconhandle  #       4
fsb_station     #       1               ; these 4 bytes are word-aligned
fsb_net         #       1
fsb_drive       #       1
fsb_name        #       17              ; name is 0-terminated
fsb_smallsize   #       0               ; if no username required
fsb_username    #       22              ; allow 21 chars plus terminator
fsb_size        #       0

           ASSERT       (fsb_station :AND: 3) = 0
           ASSERT       fsb_name = fsb_station + 3

logon_flag      *       1 :SHL: 31
null_icon       *       1 :SHL: 30
unknown_flag    *       1 :SHL: 29

                ^       0
icb_link        #       4               ; list of icons on iconbar
icb_iconhandle  #       4               ; used to keep them together
icb_size        #       0

; bits in recacheflag (causes event type 13)

scan_loggedon   *       1 :SHL: 0
scan_notify     *       1 :SHL: 1


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Workspace allocation
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                ^       0, wp
mytaskhandle    #       4               ; id so we can kill ourselves
FilerHandle     #       4               ; id so we can contact Filer
privateword     #       4

wimpversion     #       4               ; version number of Wimp
iconlist        #       4               ; list of icons on iconbar

        [ givehelp
messagedata     #       4               ; pointer to message file descriptor
        ]

notifylist      #       4

mousedata       #       0
mousex          #       4
mousey          #       4
buttonstate     #       4
windowhandle    #       4
iconhandle      #       4

vduoutput       #       0
dx              #       4
dy              #       4
scrx            #       4
scry            #       4

menuhandle      #       4

windowx         #       4
windowy         #       4

relmousex       #       4
relmousey       #       4

nicons          #       4               ; number of icons on iconbar
dummynet        #       fsb_smallsize   ; put on iconbar if not logged on
cmos_fsname     *       dummynet + fsb_name

menu_whandle    #       4
menu_fsblock    #       4
menu_fsloggedon #       4               ; which drive is this fs known by?

h_fsviewer      #       4

fs_viewmode     #       1               ; fslist viewing mode plus sortmode
fs_sortmode     #       1
filesperrow     #       1
fsviewerchanged #       1               ; flag => redraw viewer this time

fs_headpointer  #       4               ; list of known fileservers
nfileservers    #       4               ; number of fileservers
scan_fslist     #       4
recacheflag     #       4
nullswanted     #       4

h_logon         #       4
ib_fsname       #       4               ; pointers to indirected buffers
ib_username     #       4
ib_password     #       4
        [ :LNOT: logontask2
ib_errorbox     #       4
ib_errormax     #       4
        ]

        [ notify
h_notify        #       4
ib_notifystation  #     4
ib_notifymessage  #     4
        ]

ram_menustart   #       0
m_fsdisplay     #       m_headersize + mi_size*5
      [ notify
m_fsmenu        #       m_headersize + mi_size*6
      |
m_fsmenu        #       m_headersize + mi_size*5
      ]
m_discmenu      #       m_headersize + mi_size*2        ; two dummy icons in here
ram_menuend     #       0

m_fsmenu_width  #       4               ; for adjusting variable menu width

       AlignSpace       64

userdata_size   *       &200
userdata        #       userdata_size            ; NB &138 are used for logon dbox

filenamebuffer  #       &100

stackbot        #       &300
stacktop        #       0

wh_fsviewer     #       &140            ; use *Showtemp to see how much
wh_fsicons      *       wh_fsviewer + w_icons

ind_logondbox   #       &A0 + &100      ; use *Showtemp to see how much
ind_fsviewer    #       &90

max_discs       EQU     16

ram_discmenu    #       m_headersize + mi_size * max_discs

NetFiler_WorkspaceSize *  :INDEX: @

 ! 0, "NetFiler workspace is ":CC:(:STR:(:INDEX:@)):CC:" bytes"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Module header
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 ASSERT (.=Module_BaseAddr)

        DCD     NetFiler_Start        -Module_BaseAddr
        DCD     NetFiler_Init         -Module_BaseAddr
        DCD     NetFiler_Die          -Module_BaseAddr
        DCD     NetFiler_Service      -Module_BaseAddr
        DCD     NetFiler_TitleString  -Module_BaseAddr
        DCD     NetFiler_HelpString   -Module_BaseAddr
        DCD     NetFiler_CommandTable -Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
 [ international_help
        DCD     str_messagefile       -Module_BaseAddr
 |
        DCD     0
 ]
        DCD     NetFiler_ModFlags     -Module_BaseAddr

NetFiler_HelpString
        DCB     "NetFiler"
        DCB     TAB
        DCB     "$Module_MajorVersion ($Module_Date)"
      [ Module_MinorVersion <> ""
        =       " $Module_MinorVersion"
      ]
        DCB     0


NetFiler_CommandTable
NetFiler_StarCommand
 [ international_help
        Command "Desktop_NetFiler", 0, 0, International_Help
        DCB     0                       ; End of table

Desktop_NetFiler_Help    DCB     "HNFLDNF", 0
Desktop_NetFiler_Syntax  DCB     "SNFLDNF", 0
 |
        Command "Desktop_NetFiler", 0, 0, 0
        DCB     0                       ; End of table

Desktop_NetFiler_Help
        DCB   "The NetFiler provides the Net icons on the icon bar, and "
        DCB   "uses the Filer to display Net directories.",13,10
        DCB   "Do not use *Desktop_NetFiler, use *Desktop instead.",0

Desktop_NetFiler_Syntax  DCB   "Syntax: *Desktop_"       ; drop through!
 ]

NetFiler_TitleString     DCB   "NetFiler", 0
NetFiler_Banner          DCB   "S03", 0
                         ALIGN
NetFiler_MaxBannerSize   EQU   40

NetFiler_ModFlags
 [ :LNOT:No32bitCode
        DCD     ModuleFlag_32bit
 |
        DCD     0
 ]

MessagesList    DCD     Message_SaveDesktop
                DCD     Message_HelpRequest
                DCD     Message_MenuWarning
                DCD     Message_Notify

                [ DragsToIconBar
                DCD     Message_DataSave
                DCD     Message_DataLoad
                ]

                DCD     0


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Had *command to enter NetFiler, so start up via module handler

Desktop_NetFiler_Code Entry "r7"

        LDR     wp, [r12]
        CMP     wp, wp, ASR #31                 ; 0 or -1
        BEQ     %FT01

        LDR     wp, [wp, #:INDEX:mytaskhandle]
        CMP     wp, #0
        MOVEQ   r0, #ModHandReason_Enter
        ADREQ   r1, NetFiler_TitleString
        SWIEQ   XOS_Module
01
        ADR     r0, ErrorBlock_CantStartNetFiler
        MOV     r1, #0
        MOV     r2, #0
        ADR     r4, NetFiler_TitleString
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

ErrorBlock_CantStartNetFiler
        DCD     0
        DCB     "UseDesk", 0
        ALIGN


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

NetFiler_ServiceTable
        DCD     0
        DCD     NetFiler_ServiceMain - Module_BaseAddr

        DCD     Service_Reset                   ; Must be ascending order
        DCD     Service_ModeChange
        DCD     Service_StartFiler
        DCD     Service_StartedFiler
        DCD     Service_FilerDying
        DCD     Service_NetFS
        DCD     Service_MessageFileClosed
 [ standalone
        DCD     Service_ResourceFSStarting
 ]
        DCD     0

        DCD     NetFiler_ServiceTable - Module_BaseAddr

NetFiler_Service ROUT

        MOV     r0, r0
        TEQ     r1, #Service_Reset
        TEQNE   r1, #Service_MessageFileClosed
 [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
 ]
        TEQNE   r1, #Service_FilerDying
        TEQNE   r1, #Service_StartFiler
        TEQNE   r1, #Service_StartedFiler
        TEQNE   r1, #Service_ModeChange
        TEQNE   r1, #Service_NetFS
        MOVNE   pc, lr

NetFiler_ServiceMain
        TEQ     r1, #Service_Reset
        BEQ     NetFiler_Service_Reset

        TEQ     r1, #Service_MessageFileClosed
        BEQ     NetFiler_Service_MessageFileClosed

 [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BEQ     NetFiler_Service_ResourceFSStarting
 ]

        TEQ     r1, #Service_FilerDying
        BEQ     NetFiler_Service_FilerDying

        TEQ     r1, #Service_StartFiler
        BEQ     NetFiler_Service_StartFiler

        TEQ     r1, #Service_StartedFiler
        BEQ     NetFiler_Service_StartedFiler

        LDR     wp, [r12]
        CMP     wp, wp, ASR #31         ; 0 or -1
        MOVEQ   pc, lr

        TEQ     r1, #Service_ModeChange
        BEQ     NetFiler_Service_ModeChange

        ;TEQ     r1, #Service_NetFS
        ;MOVNE   pc, lr

        Push    "lr"
      [ No26bitCode
        SETPSR  I_bit, r14,, r1
      |
        SETPSR  I_bit, r14
      ]
        LDR     r14, recacheflag
        ORR     r14, r14, #scan_loggedon
        STR     r14, recacheflag
      [ No26bitCode
        RestPSR r1
        MOV     r1, #Service_NetFS
        Pull    "pc"
      |
        Pull    "pc",,^
      ]


NetFiler_Service_MessageFileClosed Entry "r0,r12"

        LDR     wp, [r12]
        CMP     wp, wp, ASR #31         ; 0 or -1
        EXIT    EQ

        BL      CopyMenus               ; re-open message file etc.

        EXIT

 [ standalone
NetFiler_Service_ResourceFSStarting Entry "r0"

        ADRL    r0, resourcefsfiles
        MOV     lr, pc                  ; LR -> return address
        MOV     pc, r2                  ; R2 -> address to call

        EXIT
 ]

NetFiler_Service_ModeChange Entry "r0-r3"

        ADR     r0, vduinput
        ADR     r1, vduoutput
        SWI     XOS_ReadVduVariables

        LDMIA   r1, {r2-r5}
        MOV     r4, r4, LSL r2          ; r4 = x windlimit (external coords)
        MOV     r5, r5, LSL r3          ; r5 = y windlimit (external coords)
        MOV     r14, #1
        MOV     r2, r14, LSL r2         ; r2 = dx
        MOV     r3, r14, LSL r3         ; r3 = dy
        STMIA   r1, {r2-r5}

        EXIT

vduinput
        DCD     VduExt_XEigFactor
        DCD     VduExt_YEigFactor
        DCD     VduExt_XWindLimit
        DCD     VduExt_YWindLimit
        DCD     -1


NetFiler_Service_StartedFiler Entry

        LDR     r14, [r12]              ; cancel 'don't start' flag
        CMP     r14, #-1
        MOVEQ   r14, #0
        STREQ   r14, [r12]

        EXIT


NetFiler_Service_StartFiler Entry "r2,r3,r6"

        LDR     r2, [r12]
        CMP     r2, #0
        EXIT    NE                      ; don't claim service unless = 0

        MOV     r6, r0                  ; Filer task handle
        LDR     r3, =NetFiler_WorkspaceSize
        BL      claimblock
        MOVVS   r2, #-1                 ; avoid looping
        STR     r2, [r12]

        MOVVC   R0, #-1
        STRVC   R0, [r2, #:INDEX:fs_headpointer]
        STRVC   r0, [r2, #:INDEX:scan_fslist]
        MOVVC   r0, #0
      [ givehelp
        STRVC   r0, [r2, #:INDEX:messagedata]
      ]
        STRVC   r0, [r2, #:INDEX:recacheflag]   ; do this now cos of events
        STRVC   r0, [r2, #:INDEX:nullswanted]
        STRVC   r0, [r2, #:INDEX:mytaskhandle]
        STRVC   r12, [r2, #:INDEX:privateword]
        STRVC   r6, [r2, #:INDEX:FilerHandle]
        STRVC   r0, [r2, #:INDEX:notifylist]

        MOVVC   r0, #EventV             ; start receiving Econet events
        ADRVC   r1, myevent
        SWIVC   XOS_Claim               ; r2 -> workspace
        MOVVC   r0, #14
        MOVVC   r1, #Event_Econet_OSProc
        SWIVC   XOS_Byte

        ADRVCL  r0, NetFiler_StarCommand
        MOVVC   r1, #0                  ; Claim service

        EXIT


NetFiler_Service_Reset Entry "r0-r6"

        LDR     r2, [r12]               ; cancel 'don't start' flag
        CMP     r2, #-1
        MOVEQ   r14, #0
        STREQ   r14, [r12]

        CMP     r2, #0
        MOVHI   wp, r2
        MOVHI   r0, #0                  ; Wimp has already gone bye-bye
        STRHI   r0, mytaskhandle
        BLHI    freeworkspace

        EXIT                            ; Sorry, but no can do errors here

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

NetFiler_Init Entry "r0"

; initialise NetFiler$Path if not already done

        ADR     R0, Path
        MOV     R2, #-1
        MOV     R3, #0
        MOV     R4, #VarType_Expanded
        SWI     XOS_ReadVarVal          ; returns R2=0 if doesn't exist
        CMP     R2, #0                  ; clears V as well!

        ADREQ   R0, Path
        ADREQ   R1, PathDefault
        MOVEQ   R2, #?PathDefault
        MOVEQ   R3, #0
        MOVEQ   R4, #VarType_String
        SWIEQ   XOS_SetVarVal
 [ standalone
        ADRL    r0, resourcefsfiles
        SWI     XResourceFS_RegisterFiles
 ]
        CLRV
        EXIT

Path            DCB     "NetFiler$$Path"
                DCB     0
PathDefault     DCB     "Resources:$.Resources.NetFiler."
                DCB     0
                ALIGN


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      [ standalone
NetFiler_Die Entry "r0"

        ADRL    r0, resourcefsfiles
        SWI     XResourceFS_DeregisterFiles

        Pull    "r0, lr"                ; drop through
      |
NetFiler_Die ROUT
      ]

NetFiler_Service_FilerDying Entry "r0-r6"

        LDR     wp, [r12]
        BL      freeworkspace

        CLRV                            ; Sorry, but no can do errors here
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; buffer up notify packets
;

                ^       0
notify_link     #       4
notify_size     #       4               ; current size of block
notify_nextch   #       4               ; offset to next char
notify_station  #       4               ; station/net of relevant station
notify_time     #       4               ; monotonic time of last char
notify_realtime #       5               ; time message received
notify_message  #       11              ; leave 11 chars initially
notify_end      #       0

myevent
        TEQ     r0, #Event_Econet_OSProc
        TEQEQ   r2, #0                  ; reason code (0 = insert char)
        MOVNE   pc, lr                  ; pass it on

        LDRB    r1, [r1, #4]            ; r1 = character code
        ORR     r4, r3, r4, LSL #8      ; r4 = station/net number

        SWI     XOS_ReadMonotonicTime
        BLVC    findstation             ; don't assume V clear here!
        Pull    "pc",VS                 ; couldn't create block

        LDR     r14, nullswanted        ; set when pollword event received
        TEQ     r14, #0
        LDREQ   r14, recacheflag        ; indicate that notifies must be scanned
        ORREQ   r14, r14, #scan_notify
        STREQ   r14, recacheflag

        SWI     XOS_ReadMonotonicTime
        STR     r0, [r2, #notify_time]
        Push    "r1"                            ; save character code
        LDR     r1, [r2, #notify_nextch]
        LDR     r4, [r2, #notify_size]
        CMP     r1, r4                          ; too big?
        BLT     %FT04

        Push    "r3"
        MOV     r0, #ModHandReason_ExtendBlock
        MOV     r3, #16                         ; extend 16 bytes at a time
        SWI     XOS_Module
        Pull    "r3"
        STRVC   r2, [r3, #notify_link]          ; in case it's moved!
        ADDVC   r4, r4, #16
        STRVC   r4, [r2, #notify_size]
04
        Pull    "r14"                           ; r14 = original character code
        Pull    "pc",VS
        CMP     r14, #32
        STRCSB  r14, [r2, r1]
        ADDCS   r1, r1, #1
        STRCS   r1, [r2, #notify_nextch]
        MOV     r14, #0
        STRB    r14, [r2, r1]                   ; ensure it's always terminated
        Pull    "pc"


; In    r0 = current (monotonic) time
;       r4 = station/net to search for
; Out   r2 -> relevant block (may be created dynamically)
;       r3 -> parent block
;       V set ==> no room in RMA to create block

findstation Entry           ; NB assume V unset on entry

        ADR     r2, notifylist-notify_link
        B       %FT02
01
        LDR     r14, [r2, #notify_station]
        TEQ     r14, r4
        BNE     %FT02
        LDR     r14, [r2, #notify_time]
        SUB     r14, r0, r14
        CMP     r14, #300                         ; 3 second timeout
        BGE     %FT02
        CLRV                   ; V can be set after 6 week interval!
        EXIT
02
        MOV     r3, r2
        LDR     r2, [r2, #notify_link]
        CMP     r2, #0                          ; List end?
        BNE     %BT01

        Push    "r1,r3"

        MOV     r3, #notify_end
        BL      claimblock

        LDRVC   r3, [sp, #1*4]                  ; r3 -> last block in list
        LDRVC   r14, [r3, #notify_link]
        STRVC   r2, [r3, #notify_link]
        STRVC   r14, [r2, #notify_link]
        STRVC   r4, [r2, #notify_station]
        MOVVC   r14, #notify_end
        STRVC   r14, [r2, #notify_size]
        MOVVC   r14, #notify_message
        STRVC   r14, [r2, #notify_nextch]

        MOVVC   r0, #14                         ; read real-time clock
        ADDVC   r1, r2, #notify_realtime
        MOVVC   r14, #3                         ; in 5-byte format
        STRVCB  r14, [r1]
        SWIVC   XOS_Word

        Pull    "r1,r3,pc"


; Corrupts r0-r6

freeworkspace ROUT

        CMP     wp, #0                  ; clears V
        MOVLE   pc, lr

        MOV     r6, lr                  ; can't use stack on exit if USR mode

      [ givehelp
        BL      deallocatemessagedata   ; (can use stack until block freed)
      ]

        LDR     r0, mytaskhandle
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown         ; ignore errors from this

        LDR     r4, fs_headpointer      ; free fs list
        B       %FT02
01
        LDR     r4, [r2, #fsb_link]     ; r4 --> next one
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
02      CMP     r4, #-1
        MOVNE   r2, r4
        BNE     %BT01                   ; List end?

        MOV     r0, #13
        MOV     r1, #Event_Econet_OSProc
        SWI     XOS_Byte
        MOV     r0, #EventV             ; get off the vector!
        ADR     r1, myevent
        MOV     r2, r12
        SWI     XOS_Release

        MOV     r2, r12
        LDR     r12, privateword
        MOV     r14, #0                 ; reset flag word anyway
        STR     r14, [r12]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        MOV     pc, r6


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


CloseDownAndExit ROUT

        BL      freeworkspace
        SWI     OS_Exit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   NetFiler application entry point
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ErrorAbort
        CMP     r0, #0                  ; if r0=0, it means 'close quietly'

        MOVNE   r1, #2_010              ; 'Cancel' button
        BLNE    ReportError             ; stack is still valid here

        BL      freeworkspace           ; exits with r12 --> private word
        MOV     r0, #-1
        STR     r0, [r12]               ; marked so doesn't loop

        SWI     OS_Exit


NetFiler_Start ROUT

        LDR     wp, [r12]
        CMP     wp, wp, ASR #31         ; 0 or -1

        addr    r0, ErrorBlock_CantStartNetFiler, EQ
        MOVEQ   r1, #0                  ; Token 'UseDesk' is in global messages
        MOVEQ   r2, #0                  ; Internal buffer
        addr    r4, NetFiler_TitleString, EQ
        SWIEQ   MessageTrans_ErrorLookup

        ADRL    sp, stacktop            ; STACK IS NOW VALID!

        LDR     r0, mytaskhandle        ; close any previous incarnation
        CMP     r0, #0
        LDRGT   r1, taskidentifier
        SWIGT   XWimp_CloseDown         ; ignore errors from this
        SUB     sp, sp, #NetFiler_MaxBannerSize
        ADRL    r0, NetFiler_Banner
        MOV     r1, sp
        MOV     r2, #NetFiler_MaxBannerSize
        MOV     r3, #0
        BL      lookuptoken

        MOVVC   r0, #300                ; We know about wimp 3.00 and have a messages list.
        LDRVC   r1, taskidentifier
        MOVVC   r2, sp
        ADRVCL  r3, MessagesList
        SWIVC     XWimp_Initialise
        ADD     sp, sp, #NetFiler_MaxBannerSize
        STRVC   r0, wimpversion         ; used for iconbar control
        Debug   ndr,"Wimp version number =",R0
        STRVC   r1, mytaskhandle

        BLVC    NetFiler_Service_ModeChange

        BLVC    readcmos_fslist

        MOVVC   R0,#0
        STRVC   R0,iconlist
        STRVC   R0,nicons
        STRVC   R0,nfileservers
        STRVCB  R0,filesperrow
        ADRVC   R14,dummynet
        STRVC   R14,menu_fsblock         ; just in case
        STRVC   R0,[R14,#fsb_station]    ; 0.0 = dummy fileserver
        STRVCB  R0,[R14,#fsb_name]       ; null name
        MOVVC   R0,#null_icon
        STRVC   R0,[R14,#fsb_iconhandle]

        BLVC    LoadTemplates           ; copy menus into ram
        BLVC    CopyMenus
        BLVC    SetUpIconBar

        BVS     ErrorAbort              ; frees workspace but marks it invalid


; .............................................................................
; The main polling loop!

repollwimp ROUT

        BLVS    reporterror_ok

        SWI     XOS_ReadMonotonicTime   ; about 1/2 sec is sufficient
        ADD     r2, r0, #50

        MOV     r0, #pointerchange_bits ; disable ptr entering/leaving window
        LDR     r14, wimpversion
        CMP     r14, #223
        BLT     %FT01                   ; need null events if old version
        LDR     r14, nullswanted
        TEQ     r14, #0
        ORREQ   r0, r0, #null_bit       ; don't need null events
        ORR     r0, r0, #pollwordfast_enable
        ADR     r3, recacheflag         ; R3 -> poll word
01
        ADR     r1, userdata
        SWI     XWimp_PollIdle
        BVS     repollwimp

; In    r1 -> wimp_eventstr

        ADR     lr, repollwimp

        CMP     r0, #Null_Reason
        BEQ     event_null_reason

        CMP     r0, #PollWord_NonZero
        BEQ     event_poll_word

        CMP     r0, #Redraw_Window_Request
        BEQ     event_redraw_window

        CMP     r0, #Open_Window_Request
        BEQ     event_open_window

        CMP     r0, #Close_Window_Request
        BEQ     event_close_window

        CMP     r0, #Key_Pressed
        BEQ     event_key_pressed

        CMP     r0, #Mouse_Button_Change
        BEQ     event_mouse_click

        CMP     r0, #Menu_Select
        BEQ     event_menu_select

        CMP     r0, #User_Message
        CMPNE   r0, #User_Message_Recorded
        BEQ     event_user_message

        CMP     r0, #User_Message_Acknowledge
        BEQ     event_message_returned

        B       repollwimp


taskidentifier
        DCB     "TASK"                  ; Picked up as a word
        ALIGN

;----------------------------------------------------------------------------

; Out   [fs_viewmode], [fs_sortmode] calculated from CMOS RAM settings

readcmos_fslist
        Push    "LR"
;
        MOV     R0,#ReadCMOS
        MOV     R1,#NetFilerCMOS
        SWI     XOS_Byte
        Pull    "PC",VS
;
        AND     R14,R2,#cmos_viewmode
      [ cmos_viewshift > 0
        MOV     R14,R14,LSR #cmos_viewshift
      ]
        STRB    R14,fs_viewmode
;
        AND     R14,R2,#cmos_sortmode
      [ cmos_sortshift > 0
        MOV     R14,R14,LSR #cmos_sortshift
      ]
        STRB    R14,fs_sortmode
;
        Pull    "PC"

;.........................................................................

; In    r3 = mask to apply to input byte
;       [fs_viewmode], [fs_sortmode] = values to put in

writecmos_fslist
        EntryS  "R0-R3"
;
        MOV     R0,#ReadCMOS
        MOV     R1,#NetFilerCMOS
        SWI     XOS_Byte
        EXITS   VS
;
        LDRB    R14,fs_viewmode
        LDRB    R0,fs_sortmode
     [ cmos_viewshift = 0
        ORR     R14,R14,R0,LSL #cmos_sortshift
     |
      [ cmos_sortshift > 0
        MOV     R0,R0,LSL #cmos_sortshift
      ]
        ORR     R14,R0,R14,LSL #cmos_viewshift
     ]
;
        BIC     R2,R2,R3                ; remove relevant bits
        AND     R14,R14,R3              ; remove relevant bits
        ORR     R2,R2,R14               ; or in my view/sort mode
;
        MOV     R0,#WriteCMOS
        MOV     R1,#NetFilerCMOS
        SWI     XOS_Byte
;
        EXITS                           ; preserve flags


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Check for any logons/logoffs while I wasn't looking
; Check whether any notify messages have arrived

; NB: Because the notify stuff hangs around waiting for the rest of the
;     notify block to appear, it must not keep on grabbing event 13s, since
;     this will prevent redraws etc getting a look in.  It must therefore
;     downgrade the event even further to a null event.


event_poll_word Entry

        LDR     r14, recacheflag
        TST     r14, #scan_loggedon
        BLNE    sussloggedon            ; clears the bit

        SWI     XOS_IntOff

        LDR     r14, recacheflag
        TST     r14, #scan_notify
        BICNE   r14, r14, #scan_notify
        STRNE   r14, recacheflag
        MOVNE   r14, #1
        STRNE   r14, nullswanted        ; do this later on a null event

        Debug   ndr,"After pollword event: nullswanted =",#nullswanted

        SWI     XOS_IntOn

        EXIT

; Only look for notify blocks on null events, to avoid hogging CPU

event_null_reason Entry

        LDR     r14, wimpversion        ; if pollword events can't happen,
        CMP     r14, #223               ; do it here instead
        BLLT    event_poll_word

        SWI     XOS_ReadMonotonicTime
        SWI     XOS_IntOff              ; disable interrupts while we do this

        ADR     r2, notifylist-notify_link
        B       %FT02
01
        LDR     r14, [r2, #notify_time]
        SUB     r14, r0, r14            ; how much time has elapsed?
        CMP     r14, #200               ; about 2 seconds should do it
        BCC     %FT02         ; NB: can set V!

        LDR     r14, [r2, #notify_link] ; remove from list NOW!
        STR     r14, [r3, #notify_link]

        Push    "r2"
        SWI     XOS_IntOn               ; re-enable interrupts

        ADR     r1, userdata
        MOV     r14, #0
        STR     r14, [r1, #ms_yourref]
        LDR     r14, =Message_Notify
        STR     r14, [r1, #ms_action]
        LDR     r14, [r2, #notify_station]
        STR     r14, [r1, #msNotify_station]
        ADD     r3, r2, #notify_realtime
        ADD     r4, r1, #msNotify_timereceived
        MOV     r5, #5
11
        LDRB    r14, [r3], #1
        STRB    r14, [r4], #1
        SUBS    r5, r5, #1              ; always copy the first 5 bytes
        CMPMI   r14, #32
        BPL     %BT11

        SUB     r4, r4, r1
        ADD     r4, r4, #3
        BIC     r4, r4, #3
        STR     r4, [r1, #ms_size]

        MOV     r0, #18                 ; must be acknowledged
        MOV     r2, #0                  ; broadcast
        SWI     XWimp_SendMessage

        Pull    "r2"
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        EXIT

02
        MOV     r3, r2
        LDR     r2, [r3, #notify_link]
03      CMP     r2, #0                  ; List end?
        BNE     %BT01

        LDR     r14, notifylist
        CMP     r14, #0
        MOVEQ   r14, #0
        STREQ   r14, nullswanted        ; nulls not needed any more

        Debug   ndr,"After notify scanning: nullswanted =",#nullswanted

donescan
        SWI     XOS_IntOn               ; don't forget this!
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
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
 dreg r2, "mouse_click: buttonstate ",cc,Word
 dreg r0, ", x ",cc,Integer
 dreg r1, ", y ",cc,Integer
 dreg r3, ", window ",,Word
 ]

        STR     r3, menu_whandle        ; window handle

        TST     r2, #button_left :OR: button_right ; select or adjust ?
        BNE     click_select

        TST     r2, #button_middle      ; menu ?
        BNE     click_menu

        EXIT

; .............................................................................
; We get here if the user has double-clicked on a FS icon

; In    r3 = window handle
;       lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_select ROUT

        CMP     r3, #iconbar_whandle
        BEQ     %FT01

        LDR     r14, h_fsviewer
        TEQ     r3, r14
        EXIT    NE

        BL      matchfsviewer           ; r2 -> fs block
        EXIT    VS
        EXIT    NE                      ; click in FS list background

        LDR     r14, buttonstate
        TST     r14, #button_right
        ADRNE   r1, h_fsviewer
        SWINE   XWimp_CloseWindow
        B       openfs

01
        BL      matchiconbar            ; r2 -> fs block
        EXIT    VS
        EXIT    NE                      ; shouldn't happen

; Try to open dir using Filer

openfs
        BL      testloggedon            ; r1 -> path name used
        LDRNE   r1, h_logon
        BNE     openmenu

        ADR     r1, userdata            ; r1 -> path name
        BL      fileropendir
        EXIT

; .............................................................................
; In    lr stacked, Proc_RegList = "lr" for EXIT
;       all regs trashable

click_menu ROUT

        CMP     r3, #iconbar_whandle
        BEQ     %FT01

        LDR     r14, h_fsviewer
        TEQ     r3, r14
        EXIT    NE

        BL      matchfsviewer           ; r2 -> fs block (dummynet if none)
        EXIT    VS
        B       %FT02                   ; dummynet is never logged-on

01      BL      matchiconbar            ; r2 -> fs block
        EXIT    VS
        EXIT    NE                      ; shouldn't happen

02      ADR     r1, m_fsmenu

openmenu
        BL      CreateMenu              ; r1,r2 -> menu / fs block
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    R4 = icon handle (in icon bar)
; Out   R2 --> fs block for this fs  (Z set)
;       R2 = -1 (Z unset) if not found

matchiconbar Entry

        ADR     r2, dummynet
        LDR     r14, [r2, #fsb_iconhandle]
        TEQ     r14, r4
        EXIT    EQ                      ; it's the dummy net!

        LDR     r2, fs_headpointer
        B       %FT02
01
        LDR     r14, [r2, #fsb_iconhandle]
        TEQ     r14, r4
        EXIT    EQ
        LDR     r2, [r2, #fsb_link]
02      CMP     r2, #-1
        BNE     %BT01
        CMP     r2, #0                  ; r2 = -1, clear Z
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    mousex, mousey = mouse x,y
;       r3 = window handle
; Out   r2 -> fs block for this fs  (Z set)
;       R2 -> dummynet (Z unset) if not found
;       [relmousex/y] set up from [mousex/y]

matchfsviewer Entry "r1,x0,y0,x1,y1,scx,scy"

        LDR     r0, h_fsviewer
        STR     r0, [sp, #-u_windowstate]!
        MOV     r1, sp
        SWI     XWimp_GetWindowState

        LDMIA   r1, {r0, x0,y0,x1,y1, scx,scy}
        ADD     sp, sp, #u_windowstate

        SUB     x0, x0, scx
        SUB     y1, y1, scy

        LDR     x1, mousex
        LDR     y0, mousey
        SUB     x1, x1, x0
        SUB     y0, y0, y1
        STR     x1, relmousex
        STR     y0, relmousey
 [ debug
 dreg x1, "relmouse x=", cc, Integer
 dreg y0, ", y="
 ]
        ADRVCL  r0, icon_search
        BLVC    iconloop
01
        ADRNE   r2, dummynet            ; use this one if no match

        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = message action
;       r1 -> media name

filer_opendir
        DCB     "Filer_OpenDir "

fileropendir Entry "r1-r2"
        SUB     sp, sp, #256
        ADR     r2, filer_opendir
        MOV     r1, sp
        BL      strcpy_advance
        LDR     r2, [sp, #256]
        BL      strcpy_advance
        MOV     r0, sp
        SWI     XOS_CLI
        ADD     sp, sp, #256
        EXIT

dotdollar       DCB     "."             ; share $ with ...
dollar          DCB     "$", 0          ; directory title
                ALIGN


; Offsets of fields in a message block

                ^       0
message_size    #       4
message_task    #       4               ; thandle of sender - filled in by Wimp
message_myref   #       4               ; filled in by Wimp
message_yourref #       4               ; filled in by Wimp
message_action  #       4
message_hdrsize *       @
message_data    #       0               ; words of data to send


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 -> fs block (dummynet if none)
;       [menu_whandle] = window handle where all this started

EncodeMenu Entry "r1-r3"

        STR     r2, menu_fsblock        ; for later

; put correct string into 1st item of top-level menu
; NB: the menu width is not adjusted if either of these items is wider than any other

        LDR     r14, menu_whandle
        CMP     r14, #iconbar_whandle
        MOVEQ   r14, #0                 ; no submenu
        LDREQ   r2, menustr_fslist      ; "FS list"
        ADRNEL  r14, m_fsdisplay        ; display submenu
        LDRNE   r2, menustr_display     ; "Display"
        STR     r14, mm_display + mi_submenu
        STR     r2, mm_display + mi_icondata
        MOV     r1, #12                 ; width = 12
01      LDRB    r14, [r2], #1
        CMP     r14, #32
        ADDHS   r1, r1, #16             ; + 16 * no of chars
        BHS     %BT01
        LDR     r14, m_fsmenu_width     ; width without these
        CMP     r1, r14
        MOVLT   r1, r14                 ; take the maximum
        STR     r1, m_fsmenu + m_itemwidth

; encode displaymode menu

        ADR     r1, mm_display_largeicons + mi_itemflags
        LDRB    r2, fs_viewmode
        MOV     r3, #0
01
        TEQ     r2, #0                  ; is this the one?
        LDR     r14, [r1]
        BICNE   r14, r14, #mi_it_tick
        ORREQ   r14, r14, #mi_it_tick
        STR     r14, [r1], #mi_size

        SUB     r2, r2, #1
        ADD     r3, r3, #1
        TEQ     r3, #3                  ; switch to sortmode after 3 icons
        LDREQB  r2, fs_sortmode

        TEQ     r3, #5
        BNE     %BT01

; shade fields which can only be accessed from a logged-on fileserver
; need to search FS list for a logged-on fs with this station number

        LDR     r2, [sp, #1*4]          ; recover original r2
        LDR     r3, [r2, #fsb_station]
        MOVS    r3, r3, LSL #16         ; don't call it if 0.0
        BEQ     %F03
        MOV     r14,#&FF
        AND     r0, r14, r3, LSR #16    ; r0 = station number
        AND     r1, r14, r3, LSR #24    ; r1 = network number
        SWI     XNetFS_UpdateFSList     ; ignore errors (old NetFS)
        BL      ReadFSList              ; we need the up-to-date list
        TEQVS   r0, r0
        BVS     %FT03

; by doing that first, we ensure that if the fileserver is no longer known,
; the fields in the menu will end up shaded.

        LDR     r2, fs_headpointer
        B       %FT21
01
        LDR     r14, [r2, #fsb_station]
        TEQ     r3, r14, LSL #16
        BNE     %FT02

        LDR     r14, [r2, #fsb_iconhandle]
        TEQ     r14, #null_icon         ; logon_flag must be unset here
        STRNE   r2, menu_fsloggedon     ; remember for later (*Bye)
        BNE     %FT03
02
        LDR     r2, [r2, #fsb_link]
21      CMP     r2, #-1                 ; terminator must be -1
        BNE     %BT01
03

; Z clear ==> fs is logged on (possibly not via the same name)
; r3 = fs station/network << 16

        LDR     r14, mm_opendollar + mi_iconflags
        BICNE   r14, r14, #is_shaded
        ORREQ   r14, r14, #is_shaded
        STR     r14, mm_opendollar + mi_iconflags

        LDR     r14, mm_free + mi_iconflags
        BICNE   r14, r14, #is_shaded
        ORREQ   r14, r14, #is_shaded
        STR     r14, mm_free + mi_iconflags

        LDR     r14, mm_bye + mi_iconflags
        BICNE   r14, r14, #is_shaded
        ORREQ   r14, r14, #is_shaded
        STR     r14, mm_bye + mi_iconflags

        MOVEQ   r14, #0
        STREQ   r14, mm_opendollar + mi_submenu
        EXIT    EQ

; construct '$' menu (look for all fs blocks with this station number)
; there's bound to be at least one!

        Push    "r1,r4-r10"

        ADR     r14, m_discmenu         ; read from message file
        LDMIA   r14, {r0, r4-r9}        ; 28-byte header
        ADR     r10, ram_discmenu
        STR     r10, mm_opendollar + mi_submenu
        STMIA   r10!, {r0, r4-r9}

        ADR     r5, m_discmenu + m_title  ; r5 spare here
        MOV     r4, #-3
11      LDRB    r14, [r5], #1
        CMP     r14, #32
        ADDHS   r4, r4, #1              ; r4 = length of title - 3
        BHS     %BT11

; scan list of known fileservers
; r3 = station / network << 16

        ADR     r2, fs_headpointer - fsb_link
        MOV     r9, #0
        B       %FT02
01
        LDR     r14, [r2, #fsb_station]
        TEQ     r3, r14, LSL #16
        BNE     %FT02

        CMP     r9, #max_discs
        ADD     r9, r9, #1
        BCS     %FT03

; construct menu item data

        MOV     r5, #0                  ; itemflags = 0, submenu = 0
        MOV     r6, #0
        STMIA   r10!, {r5-r6}

        LDR     r5, =menuiconflags :OR: if_indirected
        ADD     r6, r2, #fsb_name
        MOV     r7, #-1

; count name length (for menu width)

        MOV     r8, #0
11
        LDRB    r14, [r6, r8]
        TEQ     r14, #0
        ADDNE   r8, r8, #1
        BNE     %BT11

        STMIA   r10!, {r5-r8}
        CMP     r8, r4
        MOVGT   r4, r8
02
        LDR     r2, [r2, #fsb_link]
        CMP     r2, #-1
        BNE     %BT01                   ; List end?

; update width, and mark last item (there must be at least one)

03
        MOV     r14, r4, LSL #4
        ADD     r14, r14, #12           ; r14 = chars*16 + 12
        STR     r14, ram_discmenu + m_itemwidth

        MOV     r14, #mi_it_lastitem
        STR     r14, [r10, #mi_itemflags - mi_size]

        Pull    "r1,r4-r10"
        EXIT

        LTORG


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 -> fs block (dummynet if none)

EncodeLogonWindow Entry "r1,r2"

        LDR     r1, ib_fsname
        ADD     r2, r2, #fsb_name       ; put fs name in
        BL      strcpy

        MOV     r14, #0
        LDR     r2, ib_username         ; r14 still 0 from above
        STRB    r14, [r2]               ; null username so far

        LDR     r2, ib_password
        STRB    r14, [r2]               ; null password so far
      [ :LNOT: logontask2
        LDR     r2, ib_errorbox
        STRB    r14, [r2]               ; also cancel any previous error mess
      ]
        EXIT

nullname        DCB     0
        ALIGN


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_key_pressed
; =================

; In    r1 -> wimp_eventstr
;             [r1, #0]  window handle (where caret is)
;             [r1, #4]  icon handle
;             [r1, #8]  caret offset in window x
;             [r1, #12]                        y
;             [r1, #16] caret height
;             [r1, #20] index of caret inside string
;             [r1, #24] character code of key pressed

; Out   all regs may be corrupted - going back to PollWimp

event_key_pressed Entry

        LDMIA   r1, {r0-r6}             ; window,icon, x,y,height, index, char

        LDR     r14, h_logon
        CMP     r0, r14
        BEQ     logonkey

      [ notify
        LDR     r14, h_notify
        CMP     r0, r14
        BEQ     notifykey
      ]

        MOV     r0, r6                  ; r0 = key code
        SWI     XWimp_ProcessKey        ; pass it on if not recognised
        EXIT

      [ notify
notifykey
        MOV     r7, #3                  ; max icon number
        BL      dboxkey
        EXIT    NE

; perform notify

        MOV     r1, #-1                 ; remove notify window
        SWI     XWimp_CreateMenu

        MOV     r6, #50                 ; 5 second timeout period
        MOV     r7, #10                 ; retry 10 times a second

        LDR     r1, ib_notifystation
        MOV     r2, #0                  ; Bruce!!!
        SWI     XEconet_ReadStationNumber
        EXIT    VS
 [ debug
 dreg   r2, "Station number = ",,Integer
 dreg   r3, "Network number = ",,Integer
 ]
        CMP     r3, #0
        MOVLT   r3, #0                  ; default net no = 0
        CMP     r2, #0
        ADRLT   r0, Errorblock_UnableToDefault
        BLLT    CopyError
        EXIT    VS

        LDR     r4, ib_notifymessage
01
        LDRB    r14, [r4]
        CMP     r14, #32
        EXIT    CC

        Push    "r2-r4"
        MOV     r0, #Econet_OSProcedureCall
        MOV     r1, #0                  ; send notify char
        MOV     r5, #1                  ; length = 1 char
        SWI     XEconet_DoImmediate
        BVS     %FT11

        TEQ     r0, #Status_Transmitted
        ADRNE   r1, userdata
        MOVNE   r2, #?userdata
        SWINE   XEconet_ConvertStatusToError
11
        Pull    "r2-r4"                 ; Bruce trashes these!

        ADDVC   r4, r4, #1
        BVC     %BT01
        EXIT

        MakeInternatErrorBlock UnableToDefault,,S01
      ]

; ............................................................................

; construct 'logon' string from fields in window

      [ logontask
aliascommand    DCB     "%Set Alias$",160,"Logon ",0
performalias    DCB     160,"Logon :",0
unaliascommand  DCB     "%Unset Alias$",160,"Logon",0
      ]
logonstring     DCB     "Net:%Logon %0 %1 """, 0
spacequote      DCB     " "              ; Share quote with ...
quote           DCB     """", 0
                ALIGN

logonkey
        MOV     r7, #5                  ; max icon number
        BL      dboxkey
        EXIT    NE

SendLogon ROUT ; NOENTRY

      [ :LNOT: logontask2
        LDR     r1, ib_errorbox         ; cancel previous error message
        MOV     r14, #0                 ; each time round
        STRB    r14, [r1]

        MOV     r1, #6                  ; woggle error icon to say logging on
        MOV     r2, #6                  ; r0, r1 = window, icon
        BL      WoggleIcon              ; r2 = no of times to woggle
        EXIT    VS
      ]

        ADR     r1, userdata            ; Build logon string
      [ logontask
        ADR     r2, aliascommand
        BL      strcpy_advance          ; '*%Set Alias$<hardspace>Logon '
      ]
        ADR     r2, logonstring
        BL      strcpy_advance          ; 'net:%Logon :'
        LDR     r2, ib_password
        BL      strcpy_advance          ; password
        ADR     r2, quote
        BL      strcpy_advance          ; '"'

        SWI     XNetFS_ReadFSNumber
        Push    "r0,r1"                 ; remember FS number in case of failure
        ORRS    r14, r0, r1             ; if unset, leave alone
        SWINE   XEconet_ReadLocalStationAndNet
        MOV     r1, #0                  ; NB: net 0 is the local net!
        Push    "r0,r1"                 ; set to this temporarily
        TEQ     r0, #0
        SWINE   XNetFS_SetFSNumber

     [ logontask
        ADR     r0, userdata            ; set up alias to do logon
        SWI     XOS_CLI
        ADRVC   r1, userdata
        ADRVC   r2, performalias
        BLVC    strcpy_advance          ; <hardspace>Logon :
        LDRVC   r2, ib_fsname
        BLVC    strcpy_advance          ; fs name
        MOVVC   r14, #" "
        STRVCB  r14, [r1], #1           ; ' '
        LDRVC   r2, ib_username
        BLVC    strcpy_advance          ; user name
        MOVVC   r14, #" "
        STRVCB  r14, [r1], #1           ; ' ' to balance up for centring
        MOVVC   r14, #0
        STRVCB  r14, [r1], #1
        ADRVC   r0, userdata
        SWIVC   XWimp_StartTask
        ADR     r0, unaliascommand
        SWI     XOS_CLI
     |
        ADR     r0, userdata            ; do the logon
        SWI     XOS_CLI
        BVS     %FT50
     ]

; logon succeeded, so close logon window and open 'net#fs:&'
; we must first work out which fileserver we just logged on to!

        MOV     r1, #-1
        SWI     XWimp_CreateMenu        ; forget errors here

; at this point sta/net (our station), sta/net (old fs) are on stack

postlogon

        SWI     XNetFS_ReadFSNumber     ; r0,r1 = fs station/net number
        Pull    "r2,r3"

        TEQ     r0,r2                   ; if still the same, logon failed
        TEQEQ   r1,r3
        BNE     %FT01

        Pull    "r0,r1"                 ; logon failed - restore current FS
        TEQ     r0, #0
        SWINE   XNetFS_SetFSNumber      ; don't reset if no old fs (0.0)
        EXIT                            ; leave error visible in dbox

01
        ADD     sp, sp, #8              ; leave with new FS number

        ORR     r3, r0, r1, LSL #8
        MOV     r3, r3, LSL #16         ; r3 = sta/net number << 16

        BL      sussloggedon            ; see what's changed!

        EXIT    VS

        BL      GetStationName          ; r1 -> new station name (different?)

; unless SHIFT pressed, open 'net#fs:&'

tryopen
        MOV     r0, #&81
        MOV     r1, #&FF
        MOV     r2, #&FF
        SWI     XOS_Byte
        TEQ     r1, #0                  ; forget this if SHIFT pressed

        ADREQ   r1, userdata            ; open 'net#fsname:&'
        BLEQ    fileropendir

donelogon
        MOVVC   r1, #-1
        SWIVC   XWimp_CreateMenu        ; if this works, kill off the menu
        EXIT

        LTORG

      [ :LNOT:logontask

50 ; report error in logon box, then see what damage the logon did

        LDR     r1, ib_errorbox
        LDR     r2, ib_errormax
        LDR     r7, [r0], #4            ; r7 = error number (for later)
01      SUBS    r2, r2, #1
        MOVEQ   r14, #0                 ; terminate error if too big
        LDRNEB  r14, [r0], #1
        STRB    r14, [r1], #1
        CMP     r14, #space
        BHS     %BT01

        LDR     r0, h_logon             ; display error
        MOV     r1, #6
        BL      RedrawIcon

        B       postlogon               ; see if anything happened

      ]

; ............................................................................

; In    r3 = station / net number
; Out   r1 -> full path name, constructed in [userdata..]

GetStationName Entry "r2"

        LDR     r2, fs_headpointer
        B       %FT22
02
        LDR     r14, [r2, #fsb_station]         ; look for this station
        TEQ     r3, r14, LSL #16
        LDREQ   r14, [r2, #fsb_iconhandle]      ; must be the logged-on disc
        TSTEQ   r14, #null_icon
        BEQ     %FT01                           ; found it!

        LDR     r2, [r2, #fsb_link]
22      CMP     r2, #-1
        BNE     %BT02                           ; List end?

; the current fs is not in the list - make up a name as best we can!

        LDR     r14, nethash
        ADR     r1, userdata
        STR     r14, [r1], #4
        MOV     r14, #':'
        STRB    r14, [r1], #1
        LDR     r2, ib_fsname
        BL      strcpy_advance
        ADRL    r2, colonampersand
        BL      strcpy
        B       %FT11

01      ADR     r1, userdata            ; read 'proper' name from FS list
        BL      GetPathName

11      ADR     r1, userdata
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = window handle
;       r1 = icon handle
; Out   r5 = indirected icon len
GetIconStrLen
        EntryS  "r0, r1"
        STMDB   sp!, {r0-r9}            ; R2-R9 make space for icon
        MOV     r1, sp                  ; Point at block on stack
        SWI     Wimp_GetIconState       ; Shouldn't fail
        LDR     r0, [sp, #8+20]
        MOV     r5, #0
01      LDRB    r1, [r0], #1
        CMP     r1, #0
        ADDNE   r5, r5, #1
        BNE     %b01
        ADD     sp, sp, #10*4
        EXITS

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0-r5 = caret position
;       r6 = key code
;       r7 = 'limit' icon number (after which CR means 'do it')
; Out   caret updated, Z set ==> do it!
;       Wimp_ProcessKey called if necessary

dboxkey Entry

        CMP     r6, #CR
        BNE     %FT01

        CMP     r1, r7                  ; perform operation if at last entry
        EXIT    EQ

        ADD     r1, r1, #2              ; go down to next field
        MOV     r4, #-1
        BL      GetIconStrLen
        SWI     XWimp_SetCaretPosition
        TEQ     pc, #0                  ; unset Z
        EXIT

01      LDR     r14, =&18E              ; cursor down
        CMP     r6, r14
        LDRNE   r14, =&18F              ; cursor up
        CMPNE   r6, r14
        BNE     unkey
        MOVS    r14, r6, LSR #1
        ADDCC   r1, r1, #2              ; down
        SUBCS   r1, r1, #2              ; up
        CMP     r1, #1                  ; check that it's in range 1-r7
        RSBCSS  r14, r1, r7

        MOVCS   r4, #-1
        BLCS    GetIconStrLen
        SWICS   XWimp_SetCaretPosition
        TEQ     pc, #0                  ; unset Z
        EXIT

unkey
        MOV     r0, r6                  ; r0 = key code
        SWI     XWimp_ProcessKey        ; pass it on if not recognised
        TEQ     pc, #0                  ; unset Z (leave V alone)
        EXIT

        LTORG


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = window handle
;       r1 = icon handle

RedrawIcon Entry "r0-r3", 4*4

        MOV     r2, #0                  ; set to same state to ensure redraw
        MOV     r3, #0

        STMIA   sp, {r0-r3}
        MOV     r1, sp
        SWI     XWimp_SetIconState

        STRVS   r0, [sp, #Proc_LocalStack + 0]
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; A menu is created with the title above the x,y values you feed it, with the
; top left hand corner being at the x,y position

CreateMenu Entry "r2, r3"

        BL      EncodeMenu              ; r2 -> fs block (or dummynet)
        BL      EncodeLogonWindow

        STR     r1, menuhandle
        LDR     r2, mousex
        SUB     r2, r2, #4*16
        LDR     r14, menu_whandle
        CMP     r14, #iconbar_whandle
      [ notify
        MOVEQ   r3, #96 + 6*44
      |
        MOVEQ   r3, #96 + 5*44          ; bodge to clear icon bar
      ]
        LDRNE   r3, mousey
        SWI     XWimp_CreateMenu
        BLVC    smartenlogon            ; reposition caret
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r1 --> menu tree just opened
; Out   if r1=[h_logon], caret is moved to icon #3 if icon #1 is not null

smartenlogon Entry "r1-r5"
        LDR     r0, h_logon             ; r0 = window handle
        TEQ     r1, r0
        EXIT    NE

        LDR     r14, ib_fsname
        LDRB    r14, [r14]
        CMP     r14, #32
        EXIT    LT                      ; if null, leave caret there

        MOV     r1, #3                  ; put caret into icon #3
        MOV     r2, #bignum
        MOV     r4, #-1                 ; recalculate r3,r4
        MOV     r5, #-1                 ; use x position (ie. put at rhs)
        SWI     XWimp_SetCaretPosition
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rom_menustart ; Note - must be defined in the same order as the ram menus

m_fsdisplay             Menu    T01
mo_fsdisplay_large      Item    M11
mo_fsdisplay_small      Item    M21
mo_fsdisplay_fullinfo   Item    M31,,-          ; dotted line under this
mo_fsdisplay_sortname   Item    M41
mo_fsdisplay_sortnumb   Item    M51

m_fsmenu                Menu    T00
mo_fsmenu_display       Item    M01
mo_fsmenu_logon         Item    M02,,N          ; notify with Message_MenuWarning
mo_fsmenu_opendollar    Item    M03
mo_fsmenu_free          Item    M04
mo_fsmenu_bye           Item    M05

m_discmenu              Menu    T03
mo_discmenu_display     Item    M13             ; actually "Display"
mo_discmenu_fslist      Item    M23             ; actually "FS list"

                        DCB     0               ; terminator
                        ALIGN

menustr_display *  m_discmenu + m_headersize + mi_size * mo_discmenu_display + mi_icondata
menustr_fslist  *  m_discmenu + m_headersize + mi_size * mo_discmenu_fslist  + mi_icondata

mm_display      *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_display
        [ notify
mm_notify       *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_notify
        ]
mm_logon        *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_logon
mm_opendollar   *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_opendollar
mm_free         *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_free
mm_bye          *  m_fsmenu + m_headersize + mi_size * mo_fsmenu_bye

mm_display_largeicons  *  m_fsdisplay+m_headersize+mi_size*mo_fsdisplay_large

; .............................................................................

CopyMenus Entry "r1-r3"

        BL      allocatemessagedata             ; if not already done

        LDRVC   r0, messagedata
        ADRVC   r1, rom_menustart
        ADRVC   r2, ram_menustart
        MOVVC   r3, #ram_menuend-ram_menustart
        SWIVC   XMessageTrans_MakeMenus

        LDRVC   r14, m_fsmenu + m_itemwidth
        STRVC   r14, m_fsmenu_width             ; width without "Display" / "FS list"

        LDRVC   r14, h_logon
        STRVC   r14, mm_logon + mi_submenu
      [ notify
        LDRVC   r14, h_notify
        STRVC   r14, mm_notify + mi_submenu
      ]

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; event_menu_select
; =================

; In    r1 -> wimp_eventstr

; Out   all regs may be corrupted - going back to PollWimp

event_menu_select Entry

        MOV     r2, r1
        LDR     r1, menuhandle
        BL      DecodeMenu

        ADRVC   r1, userdata            ; check for right-hand button
        SWIVC   XWimp_GetPointerInfo
        EXIT    VS

        LDR     r14, userdata+8         ; get button state
        TST     r14, #button_right
        LDRNE   r1, menuhandle
        LDRNE   r2, menu_fsblock
        BLNE    CreateMenu              ; here we go again!
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In     r1 = menu handle
;        r2 -> list of selections

DecodeMenu Entry

 [ debug
 dreg r1, "menu_select: menu handle ",cc
 LDR r14, [r2]
 dreg r14, ", selections ",cc
 LDR r14, [r2, #4]
 dreg r14, ", "
 ]

decodelp
        LDR     r14, [r2], #4           ; r1 = selection no
        ADD     pc, pc, r14, LSL #2
        EXIT

        B       fsmenu_display          ; (or fslist)
      [ notify
        B       fsmenu_notify
      ]
        B       fsmenu_logon
        B       fsmenu_opendollar
        B       fsmenu_free

fsmenu_bye
        ADR     r1, userdata            ; *net:%Bye :<station name>
        ADR     r2, byemess
        BL      strcpy_advance
        LDR     r2, menu_fsloggedon     ; set up by EncodeMenu
        ADD     r2, r2, #fsb_name
        BL      strcpy

        ADR     r0, userdata            ; issue the command
        SWI     XOS_CLI
        BLVS    reporterror_ok          ; do the rest even after error

        BL      sussloggedon
        EXIT

byemess         DCB     "Net:%Bye :", 0
                ALIGN

      [ notify
fsmenu_notify
        EXIT
      ]

fsmenu_logon
        EXIT                            ; stuff this for now

fsmenu_opendollar
        LDR     r14, [r2], #4           ; which drive was it?

        LDR     r2, menu_fsblock

        CMP     r14, #0
        ADDLT   r4, r2, #fsb_name

        ADRGEL  r4, ram_discmenu + m_headersize
        ASSERT  mi_size = 24
        ADDGE   r14, r14, r14, LSL #1   ; r14 = index * 3
        ADDGE   r4, r4, r14, LSL #3     ; r4 = &item[0] + 24*index
        LDRGE   r4, [r4, #mi_icondata + 0]

        ADR     r1, userdata
        BL      GetFullPathName         ; this gives us the '$' form
                                        ; r4 --> disc name
        ADR     r1, userdata
        BL      fileropendir
        EXIT

fsmenu_free
        ADR     r1, userdata            ; *net:%Free :<station name>
        ADR     r2, freemess
        BL      strcpy_advance
        LDR     r2, menu_fsloggedon     ; set up by EncodeMenu
        ADD     r2, r2, #fsb_name
        BL      strcpy

        ADRL    r0, userdata + :LEN:"Net:%"
        SWI     XWimp_CommandWindow

        ADR     r0, userdata            ; issue the command
        SWI     XOS_CLI
        BLVS    reporterror_ok          ; uses box / text as appropriate

        MOV     r0, #0
        SWI     XWimp_CommandWindow
        EXIT

freemess        DCB     "ShowFree -FS NET :", 0
                ALIGN

fsmenu_display
        LDR     r0, scan_fslist
        CMP     r0, #0
        MOVNE   r0, #0
        STRNE   r0, scan_fslist
        MOVNE   r1, #0
        SWINE   XNetFS_UpdateFSList
        LDR     r0, menu_whandle
        CMP     r0, #iconbar_whandle
        BEQ     fsmenu_fslist

        LDR     r1, [r2], #4
        CMP     r1, #-1
        LDRNEB  r0, fs_viewmode
        CMPNE   r1, r0
        EXIT    EQ                      ; boring

        CMP     r1, #3                  ; is this the sortmode or viewmode?
        MOVLT   r3, #cmos_viewmode
        STRLTB  r1, fs_viewmode
        MOVGE   r3, #cmos_sortmode
        SUBGE   r1, r1, #3
        STRGEB  r1, fs_sortmode
        BL      writecmos_fslist        ; update contents of CMOS RAM
                                        ; preserves flags
        BLGE    SortFSList

recalcfs
        MOV     r14, #0                 ; drop through (recalculate)
        STRB    r14, filesperrow

fsmenu_fslist

        BL      ReadFSList              ; in case not cached already
        BL      readcmos_fslist         ; in case the Filer has changed them

        ADR     r1, userdata            ; data has been trashed by now
        LDR     r0, h_fsviewer
        STR     r0, [r1]
        SWI     XWimp_GetWindowState
01
        MOVVC   r14, #-1                ; open at front
        STRVC   r14, [r1, #u_bhandle]
        BLVC    event_open_window       ; does all the messing about
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r1 -> block (as returned by Wimp_Poll)
;       r1!0 = window handle
;       r1!4..r1!28 = x0,y0,x1,y1, scx,scy, bhandle
; Out   window opened
;       if fsviewer, extent altered, force_redraw called if layout changed
;
; NB: If logon window is to be opened, refuse if it's currently closed

event_open_window Entry "cx0,cy0, r6-r9"

        LDR     r0, [r1, #u_handle]     ; R0 = window handle
        LDR     r14, h_logon
        TEQ     r0, r14
        BNE     %FT01

        ASSERT  u_handle = 0
        STR     r0, [r1, #u_windowstate]!  ; check that the logon window
        SWI     XWimp_GetWindowState       ; is currently open
        EXIT    VS

        LDR     r14, [r1, #u_wflags]    ; if not, ignore this request
        TST     r14, #ws_open           ; (bug if mode changes on logon)
        EXIT    EQ
        LDR     r0, [r1, #-u_windowstate]!
01
        LDR     r14, h_fsviewer
        TEQ     r0, r14
        BNE     %FT50

        BL      getboxsize              ; cx0,cy0 = box size
        LDR     x0, [r1, #u_wax0]
        LDR     x1, [r1, #u_wax1]
        SUB     R9, x1, x0              ; R9 = width of window
        LDR     r14, scrx
        SUB     r14, r14, #80           ; bodge - Wimp will amend coords
        CMP     R9, r14
        MOVGT   R9, r14
        ADD     R9, R9, cx0, ASR #2     ; add 1/4 of a box (bodge!)
        DivRem  R8, R9, cx0, R14, norem ; R8 = no of boxes that will fit
        CMP     R8,#1
        MOVLT   R8,#1                   ; at least 1 column!

        LDRB    R14, filesperrow
        TEQ     R14, R8
        BEQ     %FT50
        STRB    R8, filesperrow

; calculate new extent of window

        LDR     r9, nfileservers
        DivRem  r6, r9, r8, r14         ; r6 = number of rows
        TEQ     r9, #0                  ; r9 = remainder
        ADDNE   r6, r6, #1              ; round up

        LDR     r14, nfileservers
        MUL     r8, cx0, r14            ; r8 = max width of window
        MUL     r9, cy0, r6             ; r9 = max height

; make window at least wide enough to show the title

        LDR     r14, wh_fsviewer + w_titleflags
        TST     r14, #if_indirected
        ADREQL  cx0, wh_fsviewer + w_title
        LDRNE   cx0, wh_fsviewer + w_title
        MOV     r14, #100               ; width = 100
01      LDRB    cy0, [cx0], #1
        CMP     cy0, #32
        ADDHS   r14, r14, #16           ; plus no of chars * 16
        BHS     %BT01

        CMP     r8, r14
        MOVLT   r8, r14

; set the window extent from (r8, r9)

        MOV     r6, #0
        RSB     r7, r9, #0
        MOV     r9, #0
        Push    "r0-r1, r6-r9"          ; r0 = window handle
        ADD     r1, sp, #8              ; r1 --> block containing x0,y0,x1,y1
        SWI     XWimp_SetExtent         ; reset size of window
        LDRVC   r0, [r1, #-8]
        BLVC    ForceAll
        LDRVC   r1, [r1, #-4]
        ADD     sp, sp, #8 + 16

50
        SWIVC   XWimp_OpenWindow        ; r1 --> block (still)
        EXIT


event_close_window Entry

        SWI     XWimp_CloseWindow

        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r1 -> block (contains window handle)
; Out   window redrawn

event_redraw_window Entry "r1-r11"

        SWI     XWimp_RedrawWindow
        EXIT    VS

redrawloop
        TEQ     r0, #0
        EXIT    EQ

        ADR     r0, icon_redraw
        BL      iconloop

        ADR     r1, userdata
        SWI     XWimp_GetRectangle
        BVC     redrawloop

        EXIT


; In    r0 -> routine to call in middle of loop

iconloop Entry "r0-r11"

        LDRB    r14, fs_viewmode
        ADRL    r1, wh_fsicons
        ADD     r1, r1, r14, LSL #i_shift       ; r1 --> icon definition

        ADD     r14, r1, #3 * i_size
        LDMIA   r14, {cx0,cy0,cx1,cy1}
        LDMIA   r1, {x0,y0,x1,y1}
        SUB     x1, x1, x0
        SUB     y0, y0, y1
        SUB     x0, x0, cx0             ; initial file box
        SUB     y1, y1, cy1
        ADD     x1, x0, x1
        ADD     y0, y1, y0

        SUB     cx1, cx1, cx0           ; cx1, cy1 = file box size
        SUB     cy1, cy1, cy0

        Push    "x0,x1"                 ; remember initial x position

        LDR     r2, fs_headpointer
        LDRB    r10, filesperrow
        B       endloop

innerloop
        MOV     lr, pc
        LDR     pc, [sp, #2*4]          ; call user-supplied routine
        STREQ   r2, [sp, #2*4+2*4]      ; x0,x1, r0,r1,r2 on stack here
        BEQ     foundicon

        SUBS    r10, r10, #1
        LDREQB  r10, filesperrow

        LDMEQIA sp, {x0,x1}
        SUBEQ   y0, y0, cy1
        SUBEQ   y1, y1, cy1

        ADDNE   x0, x0, cx1
        ADDNE   x1, x1, cx1

        LDR     r2, [r2, #fsb_link]

endloop
        CMP     r2, #-1
        BNE     innerloop               ; List end?
        CMP     r2, #0                  ; NB: Z unset when loop finishes

foundicon
        ADD     sp, sp, #8              ; don't need these any more
        EXIT


; In    r1 -> appropriate icon definition
;       r2 -> fs block for this icon
;       x0,y0,x1,y1 = window-relative coords of this icon
; Out   Z set ==> abort the loop now and return r2

icon_redraw Entry

        LDRB    r14, fs_viewmode
        TEQ     r14, #view_fullinfo

        ADD     r14, r1, #i_flags
        LDMIA   r14, {r0, r3, r11, r14} ; only spare regs around!
        BIC     r0, r0, #if_border
        ADDNE   r3, r2, #fsb_name       ; string = fs name (for now)
        BNE     %FT01

; if full info, construct station name at the end

        Push    "r0, r1, r2, r3, r14"

        MOV     r1, r3
        ADD     r2, r2, #fsb_name
        BL      strcpy_advance

        [ {FALSE}
        SUB     r14, r1, r3             ; r14 = string length so far
        LDR     r2, [sp, #4*4]          ; buffer length
        SUB     r2, r2, r14             ; use up all available space

        MOV     r14, #" "
11      CMP     r2, #8                  ; stick spaces in until last 8 reached
        STRGTB  r14, [r1], #1
        SUBGT   r2, r2, #1
        BGT     %BT11

        LDR     r14, [sp, #2*4]         ; r14 -> fs block
        LDRB    r3, [r14, #fsb_station]
        LDRB    r14, [r14, #fsb_net]
        Push    "r3, r14"
        MOV     r0, sp
        SWI     XOS_ConvertFixedNetStation
        ADD     sp, sp, #8

        Pull    "r0, r1, r2, r3, r14"

01
        Push    "r0, r3, r11, r14"
        Push    "r1, x0,y0,x1,y1"
        ADD     r1, sp, #4              ; r1 -> temporary icon
        SWI     XWimp_PlotIcon          ; ignore errors
        LDR     r1, [sp], #4+i_size     ; recover r1 and correct stack
        TEQ     r1, #0                  ; unset Z

        |

        SUB     SP,SP,#8
        MOV     R1,SP
        LDR     r14, [sp, #2*4+8]         ; r14 -> fs block
        LDRB    r3, [r14, #fsb_station]
        LDRB    r14, [r14, #fsb_net]
        Push    "r3, r14"
        MOV     r0, sp
        MOV     R2,#8
        SWI     XOS_ConvertFixedNetStation
        ADD     sp, sp, #8

        LDR     R14,[sp,#8]                             ; flags
        AND     R14,R14,#&ff000000                      ; colour
        LDR     R0,=if_text  :OR: if_rjustify
        ORR     R0,R0,R14
        Push    R0
        Push    "x0,y0,x1,y1"
        MOV     R1,SP
        SWI     XWimp_PlotIcon
        ADD     SP,SP,#28

        Pull    "r0, r1, r2, r3, r14"

01
        Push    "r0, r3, r11, r14"
        Push    "r1, x0,y0,x1,y1"
        ADD     r1, sp, #4              ; r1 -> temporary icon
        SWI     XWimp_PlotIcon          ; ignore errors
        LDR     r1, [sp], #4+i_size     ; recover r1 and correct stack
        TEQ     r1, #0                  ; unset Z
        ]

        EXIT


; In    r1 -> appropriate icon definition
;       r2 -> fs block for this icon
;       x0,y0,x1,y1 = window-relative coords of this icon
; Out   Z set ==> abort the loop now and return r2

icon_search Entry "cx0,cy0"

        LDR     cx0, relmousex
        LDR     cy0, relmousey
        CMP     cx0, x0
        CMPGE   cy0, y0
        CMPGE   x1, cx0
        CMPGE   y1, cy0

        CMPGE   cx0, cx0                 ; set Z if icon found
 [ debug
 EXIT NE
 dreg x0, "found: box = ",cc,Integer
 dreg y0, ", ",cc,Integer
 dreg x1, ", ",cc,Integer
 dreg y1, ", ",,Integer
 CMP cx0, cx0
 ]
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    [fs_viewmode] = relevant view mode
; Out   cx0,cy0 = x,y size of box containing fs

getboxsize Entry "r1, cx1,cy1"

        ADRL    r1, wh_fsicons + i_size * 3
        LDRB    r14, fs_viewmode
        ADD     r1, r1, r14, LSL #i_shift
        LDMIA   r1, {cx0,cy0,cx1,cy1}
        SUB     cx0, cx1, cx0
        SUB     cy0, cy1, cy0
        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r0 = window handle
; Out   whole of visible area of window marked invalid

ForceAll Entry "r1-r4"

        MOV     R1,#-bignum
        MOV     R2,#-bignum
        MOV     R3,#bignum
        MOV     R4,#bignum
        SWI     XWimp_ForceRedraw

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   cx0, cy0 = coords of mouse pointer
;       other regs corrupt

GetPointerInfo ROUT

        Push    "r1, r2-r6, lr"         ; poke pointer info into stack

        ADD     r1, sp, #4
        SWI     XWimp_GetPointerInfo
        LDMVCIA r1, {cx0, cy0}

        LDR     r1, [sp], #6*4          ; Restore r1, kill temp frame
        Pull    "pc"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Set up icon bar entries for Net
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   much corruption

        MACRO
$label  IconDef $sprite, $drvspec, $title
        DCB     "   S"             ; for the validation string entry
$label  FixDCB  12, "$sprite"      ; label --> here
        FixDCB  2, "$title"        ; text field on iconbar (maybe)
        DCB     "$drvspec", CR
        ALIGN
        MEND

;
; Iconbar must always contain at least one icon (if NetFS present)
; If we are logged on anywhere, that takes precedence
; If not logged on, resort to the 'Fileserver with no name' icon
;

swiname_dofsop  DCB     "NetFS_DoFSOp",13
                ALIGN

; Out   V set, r0 = 0 ==> forget it (net is not present)

SetUpIconBar Entry

        ADR     R1,swiname_dofsop
        SWI     XOS_SWINumberFromString
        MOVVS   R0,#0
        EXIT    VS                      ; no net present

        MOV     R0,#ReadCMOS
        MOV     R1,#NetFSIDCMOS         ; CMOS location 1 = station number
        SWI     XOS_Byte
        EXIT    VS
;
        MOVS    R3,R2                   ; (0 ==> name follows instead)
        BEQ     readnetname
;
        MOV     R0,#ReadCMOS            ; non-0 ==> net number follows
        MOV     R1,#NetFSIDCMOS + 1
        SWI     XOS_Byte
;
        ORRVC   R3,R3,R2,LSL #8         ; station/net in R3 bits 0..15
        ADRVC   R1,cmos_fsname
        BLVC    ConvertNetStation       ; always gives the full number
        B       goaddnet

readnetname
        ADR     R3,cmos_fsname
;
        MOV     R0,#ReadCMOS            ; name follows in CMOS RAM
        MOV     R1,#NetFSIDCMOS + 1     ; first byte in next location
        SWI     XOS_Byte
        STRVCB  R2,[R3],#1
        MOVVC   R4,#FSNameCMOS          ; remainder in locations &9E..AD
01
        MOVVC   R0,#ReadCMOS
        MOVVC   R1,R4
        SWIVC   XOS_Byte
        EXIT    VS
        CMP     R2,#32
        STRCSB  R2,[R3],#1
        ADD     R4,R4,#1
        RSBCSS  R14,R4,#FSNameCMOS + 14 ; 1 char in NetFSID+1, 15 in FSName
        BCS     %BT01
        MOV     R1,R3

goaddnet
        MOV     R14,#0                  ; add in terminator
        STRB    R14,[R1],#1

; now see if we are logged on anywhere

        BL      sussloggedon            ; adds icons into bar if nec.

        BL      ensureicon              ; ensure that there's at least 1 icon
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    nicons = number of icons on the bar at the moment
; Out   if [nicons] was 0, the dummy net icon is added to the bar

ensureicon Entry "r2"

        LDR     r14, nicons
        CMP     r14, #0
        EXIT    GT

        ADR     r2, dummynet
        BL      AddToIconBar            ; increments [nicons]
        EXIT                            ; [r2,#fsb_iconhandle] updated


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r2 -> fs block
; Out   [r2, #fsb_iconhandle] = icon index (created on iconbar)

AddToIconBar Entry "r1-y1"

        ADR     r14, dummynet
        TEQ     r14, r2                 ; is this the dummy icon?
        BNE     %FT01

        ADRL    r14, wh_fsicons + i_size*6
        LDMIA   r14, {cx0,cy0,cx1,cy1,x0,y0,x1,y1}         ; corrupts r2
        SUB     cy1, cy1, cy0
        MOV     cy0, #-16               ; text baseline
        ADD     cy1, cy1, cy0
        MOV     r0, #-2                 ; create on FS side
        ADR     r1, userdata
        STMIA   r1, {r0, cx0,cy0,cx1,cy1, x0, y0,x1,y1}
        B       createicon
01
        MOV     r0, #SpriteReason_ReadSpriteSize + &100
        LDR     r2, wh_fsicons + i_size*0 + i_data+4
        ADD     r2, r2, #1                      ; r2 --> sprite name
        SWI     XWimp_SpriteOp                  ; r3, r4 = pixel size

        MOVVC   r0, r6                          ; creation mode of sprite

        MOVVC   r1, #VduExt_XEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   x0, #0
        ADDVC   x1, x0, r3, LSL r2              ; pixel size depends on sprite

        MOVVC   r1, #VduExt_YEigFactor
        SWIVC   XOS_ReadModeVariable
        MOVVC   y0, #20                         ; sprite baseline
        ADDVC   y1, y0, r4, LSL r2
        MOVVC   y0, #-16                        ; text baseline
        EXIT    VS

        LDR     r2, [sp, #4]
        ADD     r2, r2, #fsb_name               ; r2 --> text (fs name)
        SUB     r3, r2, #1
01      LDRB    r14, [r3, #1]!
        TEQ     r14, #0
        BNE     %BT01
        SUB     r4, r3, r2                      ; r4 = width (chars)
        CMP     x1, r4, LSL #4                  ; char width = 16 pixels
        MOVLT   x1, r4, LSL #4

        ADR     r14, userdata
        MOV     r0, #-2                         ; lhs of icon bar
        STMIA   r14!, {r0, x0, y0, x1, y1}      ; window handle, icon coords
        LDR     r0, iconbariconflags
        LDR     r3, wh_fsicons + i_size*0 + i_data+4  ; validation
        ADD     r4, r4, #1                      ; length includes terminator
        STMIA   r14, {r0, r2-r4}                ; icon flags, data

        ADR     r1, userdata

; if no other icons exist currently, just open using handle -2
; otherwise open to the right of the first icon on the list

createicon
        LDR     r14, wimpversion
        CMP     r14, #272
        LDRGT   r0, =WimpPriority_Econet
        MOVGT   r14, #-6                        ; re-write window handle
        BGT     %FT01

        CMP     r14, #221-1                     ; uses Wimp 2.21 feature
        LDRGT   r2, iconlist
        CMPGT   r2, #0
        LDRGT   r0, [r2, #icb_iconhandle]
        MOVGT   r14, #-4                         ; open to right
01      STRGT   r14, [r1, #u_handle]

        MOV     R3,#icb_size                    ; in case of errors
        BL      claimblock                      ; r2 -> new icon block

        SWIVC   XWimp_CreateIcon

        STRVC   r0, [r2, #icb_iconhandle]
        LDRVC   r14, iconlist
        STRVC   r14, [r2, #icb_link]
        STRVC   r2, iconlist
        EXIT    VS

        LDR     r14, nicons                     ; keep track of these
        ADD     r14, r14, #1
        STR     r14, nicons

        LDR     r1, dummynet + fsb_iconhandle   ; delete dummy if WAS present
        TST     r1, #null_icon

        LDR     r2, [sp, #4]                    ; update icon handle in block
        STR     r0, [r2, #fsb_iconhandle]

        ADREQ   r2, dummynet
        BLEQ    RemoveFromIconBar               ; delete this one!

        EXIT

iconbariconflags
        DCD     &1700310B       ; text
                                ; sprite
                                ; h-centred
                                ; indirected
                                ; button type 3
                                ; fcol 7, bcol 1

;............................................................................

; In    r3 = size of block to claim
; Out   r2 -> block (in RMA)


claimblock Entry "r0"

        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module

        STRVS   r0, [sp]
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r2 --> fs block
;       [r2, #fsb_iconhandle] = icon handle on iconbar
; Out   icon deleted from iconbar
;       [nicons] decreased by one

RemoveFromIconBar Entry "r1"

        LDR     r14, nicons                     ; keep track of these
        SUB     r14, r14, #1
        STR     r14, nicons

        BL      ensureicon                      ; put dummy back if all gone

        LDR     r14, menu_fsblock               ; for right-clicking
        TEQ     r2, r14
        LDREQ   r14, menu_whandle
        CMPEQ   r14, #iconbar_whandle
        ADREQ   r14, dummynet
        STREQ   r14, menu_fsblock

        LDR     r1, [r2, #fsb_iconhandle]
        TST     r1, #null_icon
        EXIT    NE                              ; not on iconbar anyway!

        BIC     r1, r1, #logon_flag :OR: unknown_flag

        Push    "r2,r3"

        ADR     r3, iconlist - icb_link
01
        LDR     r2, [r3, #icb_link]
        LDR     r14, [r2, #icb_iconhandle]
        TEQ     r14, r1                         ; found it?
        MOVNE   r3, r2
        BNE     %BT01

        LDR     r14, [r2, #icb_link]            ; delete from chain
        STR     r14, [r3, #icb_link]

        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module                      ; shouldn't give an error

        Pull    "r2,r3"

        MOV     r0, #iconbar_whandle

        Push    "r0,r1"
        MOV     r1, sp                          ; r1 --> block (window,icon)
        SWI     XWimp_DeleteIcon
        ADD     sp, sp, #8

        MOV     r14, #null_icon
        STR     r14, [r2, #fsb_iconhandle]

        EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; Template file name:  NetFiler:Templates
;           template:  logon_dbox
;           template:  FS_viewer

LoadTemplates
        Push    "LR"
;
        ADR     r1, templatefname
        SWI     XWimp_OpenTemplate
        Pull    "PC", VS

        ADR     r1, wh_fsviewer         ; keep this for later
        ADR     r2, ind_fsviewer        ; validation strings are useful
        ADD     r3, r2, #?ind_fsviewer
        ADR     r5, wn_fsviewer
        BL      ReadTemplate            ; don't actually create the window yet
        MOVVC   r14, #0
        STRVC   r14, wh_fsviewer + w_nicons
        SWIVC   XWimp_CreateWindow
        STRVC   r0, h_fsviewer

        ADRVC   r1, userdata            ; create logon dbox
        ADRVC   r2, ind_logondbox       ; Keep indirected icons for logon dbox
        ADDVC   r3, r2, #?ind_logondbox
        ADRVC   r5, wn_logon            ; NB: load this AFTER FS_viewer
        BLVC    ReadTemplate
        LDRVC   r14, [r1, #w_icons + 1*i_size + i_data]
        STRVC   r14, ib_fsname
        LDRVC   r14, [r1, #w_icons + 3*i_size + i_data]
        STRVC   r14, ib_username
        LDRVC   r14, [r1, #w_icons + 5*i_size + i_data]
        STRVC   r14, ib_password
      [ :LNOT: logontask2
        LDRVC   r14, [r1, #w_icons + 6*i_size + i_data]
        STRVC   r14, ib_errorbox
        LDRVC   r14, [r1, #w_icons + 6*i_size + i_data+8]
        STRVC   r14, ib_errormax
      ]
        SWIVC   XWimp_CreateWindow
        STRVC   r0, h_logon

     [ notify
        ADRVC   r5, wn_notify
        BLVC    ReadTemplate
        LDRVC   r14, [r1, #w_icons + 1*i_size + i_data]
        STRVC   r14, ib_notifystation
        LDRVC   r14, [r1, #w_icons + 3*i_size + i_data]
        STRVC   r14, ib_notifymessage
        SWIVC   XWimp_CreateWindow
        STRVC   r0, h_notify
     ]

        MOV     r2, r0
        SavePSR r3
        SWI     XWimp_CloseTemplate
        MOVVC   r0, r2                  ; restore original error if it closed
        RestPSR r3, VC, f

        Pull    "PC"

wn_logon        FixDCB  12, "logon_dbox"
      [ notify
wn_notify       FixDCB  12, "notify_dbox"
      ]
wn_fsviewer     FixDCB  12, "FS_viewer"

templatefname   DCB     "NetFiler:Templates", 0
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 -> user block to put template
;       r2 -> core to put indirected icons for template
;       r3 -> end of this core
;       r5 -> name of relevant entry

; Out   [r1] contains the window / icons
;       [r2] contains the indirected data

ReadTemplate Entry

        MOV     r4, #-1
        MOV     r6, #0
        SWI     XWimp_LoadTemplate
        EXIT    VS

        CMP     r6, #0
        ADREQ   r0, ErrorBlock_WimpNoTemplate
        BLEQ    CopyError
        EXIT

        MakeInternatErrorBlock WimpNoTemplate,,S02


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Read list of available fileservers using NetFS cache
; uses either the list of logged-on FS's or the list of known FS's

; In     [fs_headpointer] --> current list of fileservers
; Out    NetFS_EnumerateFS/List called, and all new ones added in
;        The list is then re-sorted using OS_HeapSort

                ^       0
nff_station     #       1               ; data returned by NetFS
nff_net         #       1
nff_drive       #       1               ; drive number
nff_name        #       17              ; fileserver/drive name (terminated)
nff_username    #       22              ; username (for NetFS_EnumerateFSContexts)
nff_reserved1   #       1
nff_reserved2   #       1
nff_size        #       0

        ASSERT  (nff_station :AND: 3) = 0       ; for word access

ReadFSList
        Push    "LR"
        BL      readFSs                 ; read logged-on fileservers
        BLVC    readFSList              ; read all fileservers
        Pull    "PC"

readFSList Entry "r1-r8"

        LDR     r2, fs_headpointer      ; mark all FS's in the list 'unknown'
        B       %FT02
01
        LDR     r14, [r2, #fsb_iconhandle]
        ORR     r14, r14, #unknown_flag
        STR     r14, [r2, #fsb_iconhandle]
        LDR     r2, [r2, #fsb_link]
02
        CMP     r2, #-1
        BNE     %BT01                   ; List end?

        MOV     r8, #1
        B       readboth

sussloggedon

readFSs Entry "r1-r8"

        MOV     r8, #0
        SWI     XOS_IntOff              ; watch out for notifies!
        LDR     r14, recacheflag
        BIC     r14, r14, #scan_loggedon
        STR     r14, recacheflag
        SWI     XOS_IntOn

; pass 1 - add NetFS list into mine, looking for matches

readboth
        MOV     r0, #0                  ; r0 = 0 ==> first time
        STRB    r0, fsviewerchanged
fsloop
        ADR     r1, userdata            ; r1 --> buffer
        MOV     r2, #?userdata          ; r2 = buffer size
        MOV     r3, #1                  ; r3 = no of entries to read
        TEQ     r8, #0
        BEQ     %FT01
        SWI     XNetFS_EnumerateFSList  ; all FS's
        B       %FT11
01
        SWI     XNetFS_EnumerateFSContexts      ; logged-on FSs with usernames
11
        EXIT    VS

        CMP     r3, #1                  ; watch out for null list!
        BLT     donefs

        MOV     r7, r0                  ; finish indicator (for next time)

        LDR     r2, fs_headpointer
        B       %FT03
02
        LDR     r5, [r1, #nff_station]
        MOV     r5, r5, LSL #16         ; only net/station are interesting
        LDR     r6, [r2, #fsb_station]  ; compare station/net
        TEQ     r5, r6, LSL #16
        BNE     notfs

; see if station names match

        ADD     r5, r1, #nff_name
        ADD     r6, r2, #fsb_name
22
        LDRB    r14, [r5], #1
        CMP     r14, #space
        MOVLS   r14, #0
        LDRB    r0, [r6], #1
        TEQ     r0, r14
        BNE     notfs
        TEQ     r0, #0
        BNE     %BT22

        TEQ     r8, #0
        LDRNEB  r14, [r1, #nff_drive]   ; copy drive if valid (ie. FS list)
        STRNEB  r14, [r2, #fsb_drive]
        BNE     foundfs                 ; don't bother with username for fslist

; see if usernames match (case insensitive) - if not, close net#fsname:&

        ADD     r5, r1, #nff_username
        ADD     r6, r2, #fsb_username
lp1     LDRB    r0, [r5], #1
        CMP     r0, #space
        MOVLS   r0, #0                  ; terminate with 0
        UpperCase r0, r14
        LDRB    r3, [r6], #1
        UpperCase r3, r14
        CMP     r0, r3
        BNE     foundfs

        SUB     r14, r2, r6
        CMP     r14, #-fsb_size         ; string length limit
        CMPHI   r0, #0
        BHI     lp1
        B       foundfs

; not found - create a new fs block

notfs
        LDR     r2, [r2, #fsb_link]
03
        CMP     r2, #-1
        BNE     %BT02

        STRB    r3, fsviewerchanged     ; R3 MUST BE NON-ZERO !!!

        MOVVC   r3, #fsb_size
        BLVC    claimblock
        EXIT    VS

        MOV     r14, #null_icon
        STR     r14, [r2, #fsb_iconhandle]
        LDR     r14, [r1, #nff_station]         ; copy in information
        STR     r14, [r2, #fsb_station]
        ADD     r5, r1, #nff_name
        ADD     r6, r2, #fsb_name
20      LDRB    r14, [r5], #1
        CMP     r14, #space
        MOVLS   r14, #0
        STRB    r14, [r6], #1
        BHI     %BT20

        LDR     r14, fs_headpointer             ; put into chain
        STR     r14, [r2, #fsb_link]
        STR     r2, fs_headpointer

        LDR     r14, nfileservers
        ADD     r14, r14, #1
        STR     r14, nfileservers

;       r1 -> fs info block returned from NetFS_EnumerateFS/List
;       r5 -> username (valid only if R8=0)
;       r2 -> fs block reserved in RMA

foundfs
        TEQ     r8, #0
        BNE     %FT52
        ADD     r5, r1, #nff_username   ; r5 -> username in FS info block
        ADD     r6, r2, #fsb_username   ; r1 -> username in RMA block
51      LDRB    r0, [r5], #1
        CMP     r0, #space              ; check for terminator
        SUBHI   r14, r2, r6             ; or buffer full
        CMPHI   r14, #-fsb_size+1
        MOVLS   r0, #0                  ; stick in 0 terminator
        STRB    r0, [r6], #1
        BHI     %BT51
52

; put onto iconbar if logged on

        TEQ     r8, #0
        LDR     r6, [r2, #fsb_iconhandle]
        BIC     r6, r6, #unknown_flag
        BLEQ    testloggedon
        ORREQ   r6, r6, #logon_flag
        STR     r6, [r2, #fsb_iconhandle]

        SUBS    r0, r7, #0
        BGT     fsloop                  ; loop until all fileservers read

donefs
        TEQ     r8, #0                  ; only scan logged-on FS's
        BNE     dopass4                 ; if *FS was issued (not *ListFS)

; pass 2 - remove icons/dirs for newly-dead fileservers

        LDR     r2, fs_headpointer
        B       %FT02
01
        LDR     r14, [r2, #fsb_iconhandle]          ; if non-null icon,
        TST     r14, #logon_flag :OR: null_icon     ; but now logged off,
        BLEQ    checklogoff                         ; remove dirs on this FS

        LDR     r2, [r2, #fsb_link]
02      CMP     r2, #-1
        BNE     %BT01

; pass 3 - add icons for new fileservers, and clear logon_flag bit

        LDR     r2, fs_headpointer
        B       %FT02
01
        LDR     r14, [r2, #fsb_iconhandle]
        TST     r14, #logon_flag
        BICNE   r14, r14, #logon_flag
        STRNE   r14, [r2, #fsb_iconhandle]
        TSTNE   r14, #null_icon
        BLNE    AddToIconBar

        LDR     r2, [r2, #fsb_link]
02      CMP     r2, #-1
        BNE     %BT01

; pass 4 - delete blocks for discnames which don't exist any more
; this is particularly important for fileservers with floppy discs
; NB: we can't get rid of fileservers which are still logged on

dopass4
        ADR     r4, fs_headpointer-fsb_link
01
        LDR     r2, [r4, #fsb_link]
        CMP     r2, #-1
        BEQ     %FT02
        LDR     r14, [r2, #fsb_iconhandle]
        TST     r14, #unknown_flag
        BICNE   r14, r14, #unknown_flag
        STRNE   r14, [r2, #fsb_iconhandle]
        TSTNE   r14, #null_icon         ; can't delete if there's an icon
        MOVEQ   r4, r2
        STRNEB  r2, fsviewerchanged     ; r2b <> 0 here (RMA boundaries)
        LDRNE   r14, nfileservers
        SUBNE   r14, r14, #1
        STRNE   r14, nfileservers
        LDRNE   r14, [r2, #fsb_link]
        STRNE   r14, [r4, #fsb_link]
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        B       %BT01
02

; if any icons have been added or removed, redraw/resize the window

        SWI     XNetFS_EnableCache

        BL      SortFSList              ; may set V


        LDRVCB  r14, fsviewerchanged
        TEQVC   r14, #0                 ; leaves V alone
        EXIT    EQ

        MOVVC   r14, #0                 ; force window to be redrawn
        STRVCB  r14, filesperrow        ;   and the extent recalculated

        ADRVC   r1, userdata
        LDRVC   r0, h_fsviewer
        STRVC   r0, [r1, #u_handle]
        SWIVC   XWimp_GetWindowState
        LDRVC   r14, [r1, #u_wflags]
        TSTVC   r14, #ws_open
        EXIT    EQ
        BLVC    event_open_window

        EXIT

; ............................................................................

; In    r2 -> fs block
;       this station is now not logged on, but previously was
;       ie. ( [r2, #fsb_iconhandle] :AND: (null_icon :OR: logon_flag) ) = 0
; Out   remove dirs starting with 'net#fsname:&'
;       if NO disc on this station logged on, remove 'net#nnn.nnn:' dirs
;       remove icon from bar

checklogoff Entry "r1-r4"


03
        BL      RemoveFromIconBar               ; remove icon for this FS
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    [fs_headpointer] --> list of fileserver blocks
;       [fs_viewmode] = sort / view mode
; Out   list sorted according to sort mode required
;       scratch space used to construct array for OS_HeapSort


SortFSList ROUT

        SWI     XOS_EnterOS             ; use SVC mode here (Scratch space)
        BL      sortfslist
        WritePSRc USR_mode, r2
        MOV     pc, lr                  ; this lot helps Tim to debug the MOS

sortfslist Entry

        ADR     r2, ScratchSpace
        LDR     r3, fs_headpointer
        CMP     r3, #-1
        EXIT    EQ                      ; can't sort a null array!
01
        STR     r3, [r2], #4
        LDR     r3, [r3, #fsb_link]
        CMP     r3, #-1
        BNE     %BT01

        ADR     r1, ScratchSpace        ; r1 --> pointer array
        SUB     r0, r2, r1
        MOV     r0, r0, LSR #2          ; r0 = number of items
        LDRB    r14, fs_sortmode        ; viewmode including flags
        TEQ     r14, #view_sortbyname
        ADREQ   r2, sort_byname         ; r2 --> subroutine
        ADRNE   r2, sort_bynumber
        MOV     r3, wp                  ; r3 passed in as r12 to routines
        Push    "r0"
        SWI     XOS_HeapSort
        Pull    "r2"                    ; r2 = number of items
        EXIT    VS

; go through the list of pointers, writing them back as links

        ADR     r1, ScratchSpace
        ADR     r3, fs_headpointer - fsb_link
01
        LDR     r14, [r1], #4
        STR     r14, [r3, #fsb_link]
        MOV     r3, r14
        SUBS    r2, r2, #1
        BNE     %BT01

        MOV     r14, #-1                ; put terminator in last one
        STR     r14, [r3, #fsb_link]

        EXIT


; In    r0 --> 1st fs block
;       r1 --> 2nd fs block
;       r0-r3 trashable
; Out   LT,GE from CMP between 1st and 2nd objects

sort_byname Entry "r0-r1, r4-r5"

        ADD     r0, r0, #fsb_name
        ADD     r1, r1, #fsb_name

01      LDRB    r4, [r0], #1
        CMP     r4, #space
        EXIT    LE                      ; shorter name is 'smaller'
        UpperCase r4, r14
        LDRB    r5, [r1], #1
        RSBS    r14, r5, #space
        EXIT    GT                      ; has GE
        UpperCase r5, r14
        CMP     r4, r5
        BEQ     %BT01

        EXIT    NE                      ; flags LT,GE ==> which is smaller

        Pull    "r0-r1, r4-r5, lr"      ; drop through to number sort

sort_bynumber Entry

        LDR     r2, [r0, #fsb_station]  ; sort on net/station/drive
        LDRB    r14, [r0, #fsb_drive]   ; (in that order)
        ORR     r2, r14, r2, LSL #16    ; shift net/station to top of word

        LDR     r3, [r1, #fsb_station]
        LDRB    r14, [r1, #fsb_drive]
        ORR     r3, r14, r3, LSL #16

        CMP     r2, r3                  ; that was easy!

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r2 -> fs block
; Out   r1 -> pathname (constructed in [userdata..] )
;       Z set ==> logged on here, Z unset ==> not logged on here

nethash         DCB     "Net:"                  ; must be one word
colonampersand  DCB     ".&", 0
oldcolonamp     DCB     ":&", 0
                ALIGN

testloggedon ROUT

        Push    "lr"
        ADR     r1, userdata            ; construct pathname in userdata
        BL      GetPathName             ; "net#fsname:&"
        ADR     r1, userdata
        Pull    "lr"

testpresent Entry "r2-r5"               ; r1 -> pathname

        MOV     r0, #OSFile_ReadInfo
 [ debug
 dstring r1, "test pathname: "
 ]
        SWI     XOS_File                ; returns an error if not logged on

        LDRVS   r0, [r0]
        LDRVS   r14, =ErrorNumber_NotLoggedOn

        Debug   ndr, "Error number is &", r0
        Debug   ndr, "Comparison is &", r14

        CLRV
        TEQ     r0, r14                 ; assume if VC then r0 <> return address!
        LDRNE   r14, =ErrorNumber_UnknownStationName
        TEQNE   r0, r14
        LDRNE   r14, =ErrorNumber_StationNotFound       ; just in case!
        TEQNE   r0, r14
        MOVNE   r14, #ErrorNumber_BadFileName
        TEQNE   r0, r14
        LDRNE   r14, =ErrorNumber_UnknownStationNumber
        TEQNE   r0, r14
        TOGPSR  Z_bit, r14
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r1 --> destination for pathname
;       r2 --> fs block
; Out   r1 --> terminating zero of pathname (net#fsname:&)
;                                      >>>>  net#sta.net:&  (if duplicate name)

GetPathName Entry "r2"

        ASSERT  ?nethash = 4                    ; load this as a word
        LDRB    r14, [r2, #fsb_name]
        SUB     r14, r14, #'0'
        CMP     r14, #10
        LDR     r14, nethash
        EORCC   r14, r14, #('#':EOR:':'):SHL:24 ; Convert ':' to '#'
        STR     r14, [r1], #4
        MOVCS   r14, #':'
        STRCSB  r14, [r1], #1

        ADD     r2, r2, #fsb_name
        BL      strcpy_advance
        ADR     r2, colonampersand
        ADRCC   r2, oldcolonamp
        BL      strcpy_advance
        EXIT

; In    r1 --> destination for pathname
;       r2 --> fs block
;       r4 --> discname
; Out   r1 --> terminating zero of pathname (net#sta.net::fsname.$)

GetFullPathName Entry "r2"

        ASSERT  ?nethash = 4            ; load this as a word
        LDR     r14, nethash
        STR     r14, [r1], #4
        MOV     r14, #":"
        STRB    r14, [r1], #1

        MOV     r2, r4
        BL      strcpy_advance          ; r2 --> fsname
        ADRL    r2, dotdollar
        BL      strcpy_advance          ; r1 --> terminating zero
        EXIT

        [ 0=1
getstationpath Entry "r3"

        ASSERT  ?nethash = 4             ; load this as a word
        LDR     r14, nethash
        STR     r14, [r1], #4

        LDR     r3, [r2, #fsb_station]  ; r3 bits 0..15 = station/net number
        BL      ConvertNetStation       ; r1 --> end of string afterwards
        EXIT    VS

        MOV     r14, #":"               ; add ":"
        STRB    r14, [r1], #1

        MOV     r14, #0
        STRB    r14, [r1]

        EXIT
        ]


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r1 --> buffer to hold textual string
;       r3 bits 0..7 = station number
;       r3 bits 8..15 = net number
; Out   r1 --> terminating zero of string (net.station)

ConvertNetStation Entry "r2"

        MOV     r0, r3, LSR #8          ; net number
        MOV     r2, #8                  ; buffer size
        SWI     XOS_ConvertCardinal1

        MOVVC   r14, #"."
        STRVCB  r14, [r1], #1

        MOVVC   r0, r3                  ; station number
        SWIVC   XOS_ConvertCardinal1

        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = window handle
;       r1 = icon handle
;       r2 = number of times to woggle

      [ :LNOT: logontask2

WoggleIcon Entry "r0-r3"

        MOV     r2, #is_inverted        ; eor value
        MOV     r3, #0                  ; bic value
        ADR     r14, userdata
        STMIA   r14, {r0-r3}
        MOV     r1, r14
        LDR     r2, [sp, #2*4]

        SWI     XOS_ReadMonotonicTime
01      MOV     r3, r0
        SWI     XWimp_SetIconState
        BVC     %FT03
        CLRV
        EXIT                            ; forget woggle if icon doesn't exist
02      SWI     XOS_ReadMonotonicTime
        SUB     r14, r0, r3
        CMP     r14, #4                 ; can (possibly!) set V
        BLT     %BT02
        SUBS    r2, r2, #1              ; clears V
        BNE     %BT01
        EXIT
      ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcat
; ======
;
; Concatenate two strings

; In    r1, r2 -> CtrlChar/r3 terminated strings

; Out   new string in r1 = "r1" :CC: "r2" :CC: 0

strcat Entry "r1-r3"

        MOV     r3, #space-1

05      LDRB    r14, [r1], #1           ; Find where to stick the appendage
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, r3
        BHI     %BT05
        SUB     r1, r1, #1              ; Point back to the term char

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, r3                 ; Any char <= r3 is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        EXIT

; .............................................................................
;
; strcpy
; ======
;
; Copy a string and terminate with 0

; In    r1 -> dest area, r2 -> CtrlChar/r3 terminated src string

strcpy ALTENTRY

        MOV     r3, #space-1
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; strcpy_advance
; ==============

; In    r1 -> dest string
;       r2 -> source string

; Out   r1 -> terminating null

strcpy_advance EntryS "r2"

10      LDRB    r14, [r2], #1           ; Copy from *r2++
        CMP     r14, #delete            ; Order, you git!
        CMPNE   r14, #space-1           ; Any char < space is a terminator
        MOVLS   r14, #0                 ; Terminate dst with 0
        STRB    r14, [r1], #1           ; Copy to *r1++
        BHI     %BT10

        SUB     r1, r1, #1
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
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
        CMP     r0, #Message_Quit
        BEQ     CloseDownAndExit

        LDR     r14, =Message_SaveDesktop
        TEQ     r0, r14
        BEQ     SaveDesktop

      [ DragsToIconBar
        LDR     r14, =Message_DataSave
        CMP     r0, r14
        BEQ     message_datasave

        LDR     r14, =Message_DataLoad
        CMP     r0, r14
        BEQ     message_dataload
      ]

      [ givehelp
        LDR     r14, =Message_HelpRequest
        CMP     r0, r14
        BEQ     returnhelp
      ]

        LDR     r14, =Message_MenuWarning
        TEQ     r0, r14
        EXIT    NE

        ADD     r1, r1, #20             ; r1 -> handle, x,y
        LDMIA   r1, {r1-r3}
        SWI     XWimp_CreateSubMenu
        BLVC    smartenlogon            ; adjust caret position
        EXIT

        LTORG




;............................................................................

; In    r1 -> message block containing help request
;       LR stacked
; Out   Message_HelpReply sent

      [ givehelp
returnhelp
        LDR     r2, [r1, #ms_data + b_window]
        LDR     r3, [r1, #ms_data + b_icon]

        MOV     r6, r2                  ; r6 = window handle indicator

        CMP     r2, #iconbar_whandle    ; try iconbar icon
        BNE     %FT01

        MOV     r4, r3
        BL      matchiconbar            ; r2 -> fileserver block
        B       %FT21

01      LDR     r14, h_fsviewer         ; try fs viewer icon
        CMP     r2, r14
        BNE     %FT02

        LDR     r14, [r1, #ms_data + b_x]
        STR     r14, mousex
        LDR     r14, [r1, #ms_data + b_y]
        STR     r14, mousey

        BL      matchfsviewer           ; r2 -> fs block for that FS
21
        MOVVC   r0, #&FF                ; &FF => on fileserver icon, not menu
22      ADDVC   r4, r2, #fsb_name       ; parameter 1 = fileserver name by default
        B       gothelpindex

02      LDR     r6, menu_whandle        ; iconbar or fs viewer

        LDR     r14, h_logon
        CMP     r2, r14
        MOVEQ   r0, #&11 + mo_fsmenu_logon  ; submenu of logon item
        LDREQ   r2, menu_fsblock
        BEQ     %BT22

      [ notify
        LDR     r14, h_notify
        CMP     r2, r14
        MOVEQ   r0, #&11 + mo_fsmenu_notify  ; submenu of notify item
        LDREQ   r2, menu_fsblock
        BEQ     %BT22
      ]

        CMP     r3, #0                  ; no help if not on an icon
        BLT     %FT99
                                        ; try menu
        Push    "r1, r2-r4"
        ADD     r1, sp, #4              ; r1 -> buffer for result
        MOV     r0, #1
        SWI     XWimp_GetMenuState
        Pull    "r1, r2-r4"             ; r2, r3 = menu selections
        BVS     %FT99

        ADDS    r0, r2, #1              ; NB: item -1 is translated into 0
        ADDGTS  r14, r3, #1
        ADDGT   r0, r0, r14, LSL #4     ; r0 = first entry + 16*second entry

        TEQ     r2, #mo_fsmenu_opendollar
        MOVNE   r3, #-1                 ; -1 => use fileserver name

        LDR     r2, menu_fsblock
        CMP     r3, #0
        ADDLT   r4, r2, #fsb_name
        ADRGE   r4, ram_discmenu
        ASSERT  mi_size = 24
        ADDGE   r4, r4, r3, LSL #4      ; r4 = menu + 16*index
        ADDGE   r4, r4, r3, LSL #3      ; r4 = menu + 24*index
        LDRGE   r4, [r4, #m_headersize + mi_icondata]  ; r4 -> indirected name

; r0 = index in menu (&FF => on fileserver icon itself)
; r2 -> fileserver block
; r4 -> parameter 1 (disc name)
; r6 = -2 => iconbar, else fs viewer
; First char is:
;       F       fileserver icon, not logged on
;       L       fileserver icon, logged on
;       E       not on a fileserver icon
; Second char is:
;       I       iconbar icon
;       V       fs viewer icon
; Third char is 2nd menu index + 1
; Fourth char is 1st menu index + 1

gothelpindex
        LDR     r14, [r2, #fsb_iconhandle]
        TST     r14, #null_icon
        MOVEQ   r14, #"L"                       ; logged on
        MOVNE   r14, #"F"                       ; not logged on
        ADR     r3, dummynet
        CMP     r2, r3
        MOVEQ   r14, #"E"

        ADD     r1, r1, #ms_data
        STRB    r14, [r1], #1

        CMP     r6, #iconbar_whandle
        MOVEQ   r14, #"I"                       ; iconbar
        MOVNE   r14, #"V"                       ; fs viewer
        STRB    r14, [r1], #1

        ADD     r3, r2, #fsb_name               ; r3 -> parameter 0

        MOV     r2, #3
        SWI     XOS_ConvertHex2

        SUBVC   r0, r0, #2              ; r0 -> token
        MOVVC   r1, r0                  ; r1 -> data field of message
        MOVVC   r2, #256-ms_data        ; r2 = buffer size
        BLVC    lookuptoken             ; on exit r2 = length of string

        ADDVC   r2, r2, #4 + ms_data    ; include terminator
        BICVC   r2, r2, #3
        STRVC   r2, [r1, #ms_size-ms_data]!
        LDRVC   r14, [r1, #ms_myref]
        STRVC   r14, [r1, #ms_yourref]
        LDRVC   r14, =Message_HelpReply
        STRVC   r14, [r1, #ms_action]
        MOVVC   r0, #User_Message
        LDRVC   r2, [r1, #ms_taskhandle]
        SWIVC   XWimp_SendMessage
99
        EXIT

;..............................................................................

; In    r0 -> token string
;       r1 -> buffer to copy message into
;       r2 = size of buffer (including terminator)
;       r3 -> parameter 0
;       [messagedata] -> message file descriptor (0 => not yet opened)
; Out   message file opened if not already open
;       [r1..] = message, terminated by 0
;       r2 = size of string, including the terminator

str_messagefile DCB     "NetFiler:Messages", 0
                ALIGN

lookuptoken Entry "r0-r5"

        DebugS  ndr,"Look up token ",R0
        DebugS  ndr,"Parameter 0 = ",R3

        BL      allocatemessagedata             ; r0 -> file desc on exit

        LDMVCIA sp, {r1-r5}
        MOVVC   r6, #0                          ; parameters 2..3 not used
        MOVVC   r7, #0
        SWIVC   XMessageTrans_Lookup

        STRVC   r3, [sp, #2*4]                  ; r2 on exit = string length
99
        STRVS   r0, [sp]
        EXIT

;..............................................................................

; In    [messagedata] -> message file desc (0 => not yet opened)
; Out   r0 = [messagedata] -> message file desc (opened if not already open)

allocatemessagedata Entry "r1, r2"

        LDR     r0, messagedata
        CMP     r0, #0
        EXIT    NE

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #16
        SWI     XOS_Module

        STRVC   r2, messagedata

        MOVVC   r0, r2
        ADRVC   r1, str_messagefile
        MOVVC   r2, #0                          ; no user buffer
        SWIVC   XMessageTrans_OpenFile

        BLVS    deallocatemessagedata           ; preserves error state

        LDRVC   r0, messagedata
        EXIT

CopyError
        Entry   r1-r7
        BL      allocatemessagedata
        EXIT    VS
        LDR     r1, messagedata
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

;..............................................................................

; In    [messagedata] -> message file desc, or = 0 if not loaded
; Out   [messagedata] = 0, OS_Module (Free) called if required, error preserved

deallocatemessagedata EntryS "r0,r2"

        LDR     r2, messagedata
        MOVS    r0, r2
        EXITS   EQ

        MOV     r14, #0
        STR     r14, messagedata

        SWI     XMessageTrans_CloseFile         ; tell the MessageTrans module

        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        EXITS
      ]

Proc_RegList    SETS    ""              ; expect LR stacked only
Proc_LocalStack SETA    0
Proc_SavedCPSR  SETL    {FALSE}

;............................................................................

; In    [R1,#msSaveDesktop_handle] = handle of file to write to
; Out   relevant logon commands put into file

SaveDesktop     ROUT
        LDR     r1, [r1, #msSaveDesktop_handle]         ; r1 = file handle
        ADR     r2, fs_headpointer - fsb_link
        B       %FT02
01
        LDR     r14, [r2, #fsb_iconhandle]
        TEQ     r14, #null_icon
        BEQ     %FT02

        ADR     r0, str_logon
        BL      writestr                ; write string at [r0] to handle r1
        ADDVC   r0, r2, #fsb_name
        BLVC    writestr
        ADRVC   r0, str_space
        BLVC    writestr
        ADDVC   r0, r2, #fsb_username
        BLVC    writestr
        ADRVC   r0, str_terminator
        BLVC    writestr
        BLVS    ack_savedesktop         ; preserves error state
        EXIT    VS
02
        LDR     r2, [r2, #fsb_link]
        CMP     r2, #-1
        BNE     %BT01

        EXIT

str_logon       DCB     "Net:Logon :", 0
str_space       DCB     " ", 0
str_terminator  DCB     10, 0
                ALIGN

;.............................................................................

; Acknowledge Message_SaveDesktop - this will abort the sequence

ack_savedesktop EntryS "R0-R2"

        ADR     R1,userdata             ; message is still in here
        LDR     R14,[R1,#ms_myref]
        STR     R14,[R1,#ms_yourref]
        LDR     R2,[R1,#ms_taskhandle]
        MOV     R0,#User_Message_Acknowledge
        SWI     XWimp_SendMessage

        EXITS                           ; preserves error state

;.............................................................................

; In    r0 -> string to write to file
;       r1 = file handle

writestr  Entry  "r2"

        MOV     r2, r0
01      LDRB    r0, [r2], #1
        TEQ     r0, #0
        BEQ     %FT02
        SWI     XOS_BPut
        BVC     %BT01
02
        EXIT

;............................................................................

event_message_returned Entry "r1"

        LDR     r0, [r1, #message_action]
        LDR     r14, =Message_Notify
        CMP     r0, r14
        EXIT    NE

        ADR     r1, userdata + &160
        LDR     r2, [sp]
        LDR     r3, [r2, #msNotify_station]
        BL      ConvertNetStation

        ADR     r0, notifymesstok
        ADR     r1, userdata + &100     ; don't trample on message
        MOV     r2, #&80
        ADR     r3, userdata + &160
        BL      lookuptoken
        EXIT    VS

        LDR     r2, [sp]
        ADD     r0, r2, #msNotify_message-4
        MOV     r1, #2_10001
        ADR     r2, userdata + &100
        SWI     XWimp_ReportError
        EXIT

notifymesstok   DCB     "S04", 0
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r1 = state for ReportError

NetFiler
        DCB     "Net Filer", 0
        ALIGN

reporterror_ok
        MOV     r1, #2_001              ; OK button only

ReportError Entry "r2,r4,r5"

        SUB     sp, sp, #NetFiler_MaxBannerSize
        MOV     r4, r0
        MOV     r5, r1
        ADRL    r0, NetFiler_Banner
        MOV     r1, sp
        MOV     r2, #NetFiler_MaxBannerSize
        MOV     r3, #0
        BL      lookuptoken
        MOV     r0, r4
        MOV     r1, r5
        MOV     r2, sp
        ADRVS   r2, NetFiler
        SWI     Wimp_ReportError
        ADD     sp, sp, #NetFiler_MaxBannerSize
        EXIT


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
        BL      strcpy
        Pull    "r1"

        ; Make up a filename
        LDR     r4, [r1, #24]            ; icon handle
        BL      matchiconbar             ; returns r2 -> fs block
        ADD     r1, r5, #44
        BL      GetPathName              ; Put pathname in message block data field
        MOV     r2, #256                 ; maximum length for append_dotdefaultdir
        BL      append_dotdefaultdir     ; add '.<NetFiler$DefaultDir>' (if it exists)
        MOV     r0, #46
        STRB    r0, [r1], #1             ; add a '.'
        ADR     r2, filenamebuffer
        BL      strcpy_advance           ; add the filename specified by the datasave message

        ; send a DataSaveAck message specifying the new pathname
        MOV     r1, r5                   ; stick wimp event structure pointer back in r1
        MOV     r0, #256
        STR     r0, [r1]
        LDR     r0, [r1, #8]
        STR     r0, [r1, #12]            ; Your ref.
        MOV     r0, #Message_DataSaveAck
        STR     r0, [r1, #16]            ; Message action
        LDR     r2, [r1, #4]             ; task handle of sender (to send back to)
        MOV     r0, #17                  ; event code
        SWI     Wimp_SendMessage

        Pull    "pc"


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
        CMP     r0, #0                   ; we only send a DataLoadAck if the DataLoad
        BNE     %FT10                    ; was in reply to a DataSaveAck

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

        BL      matchiconbar                 ; returns r2 -> fs block
        BNE     %FT50                        ; Can't find
        ADD     r1, r5, #20
        BL      GetPathName                  ; Put pathname in message block data field
        MOV     r2, #256                     ; maximum size we'll allow for media name + default path
        BL      append_dotdefaultdir         ; Append NetFiler$DefaultDir

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
        SWI     Wimp_SendMessage

; Open the directory viewer of the dir we're copying/saving to.
20
        BL      matchiconbar             ; returns r2 -> fs block
        BNE     %FT50
        BL      GetPathName
        MOV     r2, #256                 ; maximum size we'll allow for media name + default path
        BL      append_dotdefaultdir
        BL      fileropendir

50
        Pull    "pc"


netfiler_defaultdir DCB "NetFiler$$DefaultDir",0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; append_dotdefaultdir
;
; Read value of NetFiler$DefaultDir and append it to the path in r1
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

        ADR     r0, netfiler_defaultdir
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

        ADR     r0, netfiler_defaultdir
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
 ]


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG
 [ standalone
resourcefsfiles
        ResourceFile $MergedMsgs, Resources.NetFiler.Messages
        ResourceFile LocalRes:Templates, Resources.NetFiler.Templates
        DCD     0
 ]

 [ debug
        InsertDebugRoutines
        InsertHostDebugRoutines
 ]

      [ debugndr
        InsertNDRDebugRoutines
      ]

        END
