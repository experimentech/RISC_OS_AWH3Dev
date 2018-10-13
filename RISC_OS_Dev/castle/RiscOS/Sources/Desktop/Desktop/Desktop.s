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
; > Sources.Desktop
;   This is the desktop module

        AREA    |Desktop$$Code|, CODE, READONLY, PIC
Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Machine.<Machine>
        GET     Hdr:UserIF.<UserIF>
        GET     Hdr:CMOS
        GET     Hdr:Proc
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:LowFSi
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:ResourceFS
        GET     Hdr:MsgTrans
        GET     Hdr:Font
        GET     Hdr:Draw
        GET     Hdr:ColourTran
        GET     VersionASM
        GET     Hdr:NDRDebug
        GET     Hdr:Sprite
        GET     Hdr:Squash
        GET     Hdr:ADFS

        GBLL    DesktopAllAtOnce
DesktopAllAtOnce SETL {TRUE}
        GBLL    NewBanner
NewBanner SETL  {TRUE} :LAND: :LNOT: Embedded_UI
        GBLL    KeepItUp
KeepItUp SETL   {TRUE} :LAND: NewBanner
        GBLL    SquashedSprites
SquashedSprites SETL {TRUE} :LAND: NewBanner
        GBLL    DateFromKernel
DateFromKernel  SETL {TRUE} :LAND: NewBanner

        GBLL    debug
        GBLL    debugxx
        GBLL    debugwe
        GBLL    debugcr
        GBLL    debugtm
        GBLL    hostvdu

debug   SETL    {FALSE}
debugxx SETL    {TRUE} :LAND: debug
debugwe SETL    {TRUE} :LAND: debug
debugcr SETL    {TRUE} :LAND: debug
debugtm SETL    {TRUE} :LAND: debug
hostvdu SETL    {TRUE}



TAB     *       9
LF      *       10
FF      *       12
CR      *       13

                        ^       0, wp
commandtail             #       256
MessageBlock            #       16
Workspace               #       4
nactive                 #       4               ; no of active tasks when we started
nactive1                #       4
privatesprites          #       4               ; our sprites for the banner
BannerCloseTime         #       4
NewWelcomeWorkspace     #       4
IconHandle              #       4
NextPump                #       4
PumpHidden              #       4
PumpParams_0            #       4
PumpParams_1            #       4
PumpParams_2            #       4
ModeChangeCount         #       4               ; how many times we've seen Message_ModeChange
scratchbuffer1          #       256
scratchbuffer2          #       256
Working_Stack           #       128
Working_StackEnd        #       0

Desktop_WorkspaceSize * :INDEX: @


; **************** Module code starts here **********************

        ASSERT  (.-Module_BaseAddr) = 0

        DCD     Desktop_Start    - Module_BaseAddr
        DCD     Desktop_Init     - Module_BaseAddr
        DCD     Desktop_Die      - Module_BaseAddr
        DCD     Desktop_Service  - Module_BaseAddr
        DCD     Desktop_Title    - Module_BaseAddr
        DCD     Desktop_HelpStr  - Module_BaseAddr
        DCD     Desktop_HC_Table - Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
 [ International_Help <> 0
        DCD     MyMessagesFile   - Module_BaseAddr
 |
        DCD     0
 ]
        DCD     Desktop_Flags    - Module_BaseAddr

Desktop_Title
        =       "Desktop", 0

Desktop_HelpStr
        DCB     "Desktop", TAB, TAB, "$Module_HelpVersion", 0
        ALIGN

Desktop_Flags
  [ No32bitCode
        DCD     0
  |
        DCD     ModuleFlag_32bit
  ]


Desktop_HC_Table
        Command Desktop, 255, 0, International_Help
        &       0


; *****************************************************************************

 [ International_Help=0
Desktop_Help
        =       "*Desktop starts up any dormant Wimp modules, and also passes "
        =       "an optional *command or file of *commands to Wimp_StartTask."
        =       13
Desktop_Syntax
        =       "Syntax: *Desktop [<*command> | -File <filename>]",0
 |
Desktop_Help    DCB     "HDSKDSK", 0
Desktop_Syntax  DCB     "SDSKDSK", 0
 ]
        ALIGN

; *****************************************************************************
;
;       Desktop_Init - Initialisation entry
;

Desktop_Init    *       Module_BaseAddr

taskid          DCB     "TASK"
                ALIGN

; *****************************************************************************
;
;       Desktop_Die - Die entry
;

Desktop_Die     *       Module_BaseAddr

; *****************************************************************************
;
;       Desktop_Service - Main entry point for services
;
; in:   R1 = service reason code
;       R2 = sub reason code
;       R3-R5 parameters
;
; out:  R1 = 0 if we claimed it
;       R2 preserved
;       R3-R5 = ???
;

Desktop_Service *       Module_BaseAddr

; *****************************************************************************
;
;       Desktop_Code - Start up the desktop
;

Desktop_Code Entry
        MOV     R2, R0                  ; R2 --> parameter list
        ADR     R0, execcommand         ; cancel exec file (if any)
        SWI     XOS_CLI
        MOVVC   R0, #ModHandReason_Enter
        ADRVCL  R1, Desktop_Title       ; R1 --> module title
        SWIVC   XOS_Module
        EXIT

execcommand =   "EXEC", 0
        ALIGN

; *****************************************************************************
;
;       Desktop_Start - Application entry point
;
;       Start up any dormant modules (unless unplugged)
;


MyMessagesFile  DCB     "Resources:$.Resources.Desktop.Messages",0
filerboot       DCB     "Filer_Boot "
appsdir         DCB     "Resources:$.Apps", 0
plingstar       DCB     "!*", 0
spritefile      DCB     "Resources:$.Resources.Desktop.Sprites",0

; RWB - Remove welcome screen for STB
; NDT - Merged conditionals from RiscOS 3.70 and NCOS 1.06
 [ :LNOT: Embedded_UI :LAND: :LNOT: NewBanner
WelcomeString1  DCB     "RO3",0
WelcomeString2  DCB     "CopyRt",0
WelcomeString3  DCB     "Init",0
WelcomeString4  DCB     "Pre",0
WelcomeFont     DCB     "Trinity.Medium",0
WelcomeFont2    DCB     "Trinity.Bold",0
                ALIGN
Welcome_AcornPath
        DCD  &16
        DCD  &2,     &4A00,  &20400, &8, &22A00, &20400, &6,    &22A00, &26200, &1EA00
        DCD  &3AC00, &13200, &3AE00, &6, &7E00,  &3AE00, &4600, &25E00, &4A00,  &20400
        DCD  &5,     &0

        DCD  &37                ; Number of words in this path object
        DCD  &2, &3E00, &1D200, &8, &23200, &1D200, &6, &23000, &11C00, &17955
        DCD  &E2AA, &15155, &E2AA, &8, &15200, &B600, &6, &19200, &9E00, &20400
        DCD  &7000, &25400, &4E00, &8, &21E00, &3000, &6, &1A800, &7400, &EEAA
        DCD  &C200, &34AA, &EC00, &8, &3400, &10200, &6, &7B55, &F555, &C400
        DCD  &E200, &12200, &C400, &8, &12200, &E355, &6, &FA00, &E555, &4000
        DCD  &11C00, &3E00, &1D200, &5, &0

        DCD  0
 ]
                ALIGN

;------------------------------------------------
;
; MsgLookup
;
; In r1->token
; Out r1->string (error maybe)
;
MsgLookup Entry "r0,r2-r7"
        ADR     r0, MessageBlock
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVS   r0, [sp]
        MOVVC   r1, r2
        EXIT

Desktop_MessagesWanted
        DCD     0

Desktop_Start ROUT

        ; Allocate workspace
        MOV     r0, #ModHandReason_Claim
        MOV     r3, #Desktop_WorkspaceSize
        SWI     OS_Module

        MOV     r12, r2

        ; open message file
        ADR     r0, MessageBlock
        ADRL    r1, MyMessagesFile
        MOV     r2, #0
        STR     r2, privatesprites
        SWI     XMessageTrans_OpenFile
        BVS     %FT25
        
15
        ; size up sprites file
        ADRL    r1, spritefile
        MOV     r0, #OSFile_ReadNoPath
        SWI     XOS_File                ; attempting to load them will give an error

 [ SquashedSprites
        ; Allocate block to load squashed file into
        MOVVC   r0, #ModHandReason_Claim
        MOVVC   r3, r4
        SWIVC   XOS_Module
        MOVVS   r9, r0
        BVS     %FT25
        MOV     r10, r2
        MOV     r0, #OSFile_LoadNoPath
        ADRL    r1, spritefile
        MOV     r3, #0
        SWI     XOS_File

        ; Allocate the block to decompress into
        LDRVC   r3, [r10, #4]           ; get uncompressed length
        MOVVC   r0, #ModHandReason_Claim
        ADDVC   r3, r3, #4              ; make it a sprite area
        SWIVC   XOS_Module
        MOVVS   r9, r0
        BVS     %FT24
        STR     r2, privatesprites
        STR     r3, [r2, #saEnd]
        LDR     r0, =&48535153          ; "SQSH"
        LDR     r1, [r10, #0]
        TEQ     r0, r1
        BNE     %FT21

        ; Query Squash workspace
        MOV     r0, #1<<3
        MVN     r1, #0
        SWI     XSquash_Decompress

        ; Allocate Squash workspace
        MOVVC   r3, r0
        MOVVC   r0, #ModHandReason_Claim
        SWIVC   XOS_Module
        MOVVS   r9, r0
        BVS     %FT23

        ; This code will fail if Squash doesn't decompress it all in one go!
        MOV     r0, #1<<2
        MOV     r1, r2
        ADD     r2, r10, #20
        SUB     r3, r4, #20
        LDR     r4, privatesprites
        LDR     r5, [r10, #4]
        ADD     r4, r4, #4
        SWI     XSquash_Decompress
        MOV     r3, r0

        ; Free the squash workspace
        MOV     r2, r1
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module

        ; Look at status code. Non zero is bad, translate it into a failed sprite.
        CMP     r3, #0
        BEQ     %FT22
21
        LDR     r1, privatesprites
        MOV     r2, #0                  ; will fail
        STR     r2, [r1, #saEnd]
        STR     r1, [r1, #saFree]
        MOV     r0, #SpriteReason_CheckSpriteArea
        ORR     r0, r0, #256
        SWI     XOS_SpriteOp
        MOVVS   r9, r0
        BVS     %FT23
22
        ; Free squashed file buffer
        MOV     r2, r10
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        B       %FT30
23
        ; Free sprite area
        LDR     r2, privatesprites
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
24
        ; Free squashed file buffer
        MOV     r2, r10
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
 |
        MOV     r0, #ModHandReason_Claim
        ADD     r3, r4, #16
        SWI     XOS_Module
        MOVVS   r9, r0
        BVS     %FT25
        STR     r2, privatesprites
        STR     r3, [r2, #saEnd]
        MOV     r3, #0
        STR     r2, [r2, #saNumber]
        MOV     r3, #16
        STR     r3, [r2, #saFirst]
        STR     r3, [r2, #saFree]
20
        ; load sprites file
        MOV     r1, r2
        ADRL    r2, spritefile
        MOV     r0, #SpriteReason_LoadSpriteFile
        ORR     r0, r0, #256            ; load banner sprites
        SWI     XOS_SpriteOp
        BVC     %FT30
        MOV     r9, r0
        MOV     r2, r1
        MOV     r0, #ModHandReason_Free ; free failed sprite area
        SWI     XOS_Module
 ]
25
        ; something failed to open - free block and generate original error
        MOV     r2, r12
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r0, r9
        SWI     OS_GenerateError

30
        ; Give ourselves workspace and stack
        ADR     r13,Working_StackEnd

 [ debugtm
        MOV     r14, r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0"
        MOV     r0, r14
 ]

        SWI     XOS_GetEnv              ; R0 --> command line (not tail!)
 [ debugxx
        BVC     %FT01
        Debug   xx, "GetEnv error"
 ]
        BVS     Exit
01
        LDRB    R14,[R0],#1             ; skip module title
        CMP     R14,#" "
        BHI     %BT01                   ; NB old programs will supply null
        SUBLO   R0,R0,#1                ;    ie. execute null command

        ADR     R1,commandtail
02
        LDRB    R14,[R0],#1             ; copy command line into buffer
        STRB    R14,[R1],#1
        CMP     R14,#32
        BCS     %BT02

; If an exec file is open then exit to allow Shift-Break to *EXEC !Boot files

        MOV     R0, #198                ; read EXEC file handle
        MOV     R1, #0
        MOV     R2, #&FF
        SWI     OS_Byte
        TEQ     R1, #0                  ; was an EXEC file open?
        SWINE   OS_Exit                 ; exit if so

; Store number of active tasks - inhibits startup screen
; Store ROM apps start inhibit - set if there's a command tail or active tasks
        MOV     R0,#0
        SWI     XWimp_ReadSysInfo       ; read number of active tasks
 [ debugxx
        BVC     %FT99
        Debug   xx, "ReadSys error"
99
 ]
        BVS     Exit
        STR     R0,nactive1

        LDRB    R14,commandtail         ; spaces already skipped
        CMP     R14,#32                 ; don't start ROM applications
        MOVHS   R0,#1                   ; if there was a filename
        STR     R0,nactive              ; 0 => start ROM applications

        ; If ROM apps start enabled then Unset Desktop$File
        TEQ     R0,#0
        ADREQL  R0,com_unset
        SWIEQ   XOS_CLI                 ; ignore errors

        MOV     R14,#0
        STR     R14,NewWelcomeWorkspace

StartAsTask
        ; Up we come as a task
        ADRL    r1, Desktop_Title
        BL      MsgLookup
        BVS     Exit
        MOV     r2, r1
        MOV     R0, #300                ; pretend to know about Wimp 3.00
        LDR     R1, taskid
        ADR     R3, Desktop_MessagesWanted
        SWI     XWimp_Initialise
 [ debugxx
        BVC     %FT99
        ADD     r1, r0, #4
        DebugS  xx, "WimpInit error ", r1
99
 ]
        BVS     Exit

        MOV     R14, #0
        STR     R14, ModeChangeCount

 [ debugtm
        SWI     XOS_ReadMonotonicTime
        Pull    "r1"
        SUB     r0, r0, r1
        Debug   tm, "Initial faff ",r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0"
 ]

        ; Check for display of the Welcome screen
        LDR     r0,nactive1
        Debug   we,"nactive ",r0
        CMP     r0,#0
        MOVNE   r0,#0                   ; Keep it up for 0 seconds
        BNE     NoWelcome

        ; Only handle Boot$Error on start up (ie. when we display welcome screen).
        ADR     r0, str_booterror       ; Try to read Boot$Error.
        ADR     r1, scratchbuffer1
        MOV     r2, #?scratchbuffer1
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_ReadVarVal

        BVS     NoBootError             ; Do nothing if this fails
        TEQ     r2, #0                  ;   or not defined
        BEQ     NoBootError
        TEQ     r4, #VarType_String     ;   or not a string variable.
        BNE     NoBootError

        MOV     r3, #0                  ; Null terminate the string we read.
        STRB    r3, [r1, r2]

        MOV     r2, #-1                 ; Unset Boot$Error (other params from above).
        SWI     XOS_SetVarVal
        BVS     Exit

        MOV     r4, r1                  ; Make error a parameter for message lookup.
        ADR     r0, MessageBlock
        ADR     r1, token_booterror
        ADR     r2, scratchbuffer2+4
        MOV     r3, #?scratchbuffer2-4
        SWI     XMessageTrans_Lookup
        BVS     Exit

        ; Now get text for buttons.
 [ Embedded_UI
        ADR     r1, token_errorbuttons
 |
        SWI     XADFS_Drives            ; Don't offer floppy boot if no floppy drive
        MOVVS   r1, #0
        CMP     r1, #0
        ADREQ   r1, token_errorbuttons_noflop
        ADRNE   r1, token_errorbuttons
        ADR     r0, MessageBlock
 ]
        ADR     r2, scratchbuffer1
        MOV     r3, #?scratchbuffer1
        SWI     XMessageTrans_Lookup
        BVS     Exit
        MOV     r5, r2                  ; r5->button texts

        ADR     r0, scratchbuffer2      ; r0->message for error window
        MOV     r1, #0
        STR     r1, [r0]                ; Default error number.
        MOV     r1, #256+2048+512
        ADRL    r2, Desktop_Title
        MOV     r3, #0
        MOV     r4, #1
        SWI     XWimp_ReportError
        BVS     Exit

 [ Embedded_UI
        SWI     XOS_Reset               ; The only button on STB's error box is 'Retry'
 |
        CMP     R1, #4
        SWICC   XOS_Reset               ; Retry selected: don't expect to return from this!
 ]
        BEQ     ClearScreen             ; Cancel selected.

        MOV     r0, #0                  ; Floppy boot selected
        MOV     r1, #0                  ; We are the only task so no need for handle.
        SWI     XWimp_CloseDown

        ADR     r0, str_floppyboot      ; Boot from floppy.
        SWI     XOS_CLI
        BVC     %FT10                   ; Exit if it worked.

        ADD     r1, r0, #4              ; Set Boot$Error to the new error if OS_CLI failed.
        ADR     r0, str_booterror
        MOV     r2, #1024               ; Big enough value that terminator will be reached.
        MOV     r3, #0
        MOV     r4, #VarType_String
        SWI     XOS_SetVarVal
        BVC     StartAsTask             ; Go round again with new error.
10
        MOV     r9, r0                  ; Exit but don't send round ServiceStartedWimp.
        MOV     r8, pc
        B       Exit2

str_floppyboot  DCB     "Run ADFS::0.$.!Boot",0
str_booterror   DCB     "Boot$$Error",0
 [ Embedded_UI
token_booterror DCB     "BootErrSTB",0
token_errorbuttons DCB  "ErrButtSTB",0
 |
token_booterror DCB     "BootErr",0
token_errorbuttons DCB  "ErrButt",0
token_errorbuttons_noflop DCB  "ErrButtNoFlop",0
 ]
                ALIGN

ClearScreen
        MOV     r0, #-1                 ; Force redraw of whole screen.
        MOV     r1, #&FFFFFF00
        MOV     r2, #&FFFFFF00
        MOV     r3, #&00FFFFFF
        MOV     r4, #&00FFFFFF
        SWI     XWimp_ForceRedraw
        LDRVC   r0, =&1CE3972
        ADRVC   r1, scratchbuffer1
        ADR     r3, ClearScreen         ; somewhere which is non-zero
        SWIVC   XWimp_Poll

NoBootError

        MOV     R1,#Service_DesktopWelcome
        SWI     XOS_ServiceCall
        MOVVS   R0,#0
        BVS     NoWelcome
        TEQ     R1,#0                   ; Was it claimed ?
 [ :LNOT: Embedded_UI                   ; RWB - Remove welcome screen
        MOVEQ   R0,#0
        BEQ     NoWelcome

        Debug   we,"Service not claimed"

    [ KeepItUp
        BL      IconbarHack
    ]
        BL      DisplayWelcomeScreen

        SWI     XOS_ReadMonotonicTime
        MOVVS   r0, #0
        ADD     r0, r0, #400            ; Keep it up for 4 seconds

 ]
NoWelcome
        STR     r0, BannerCloseTime
        ADR     r0, StartPumpModuleApps
        STR     r0, NextPump
        MOV     r0, #1
        STR     r0, PumpHidden

PollLoop
        LDR     r0, NextPump
        TEQ     r0, #0
        BEQ     AllDone
        MOV     lr, pc
        MOV     pc, r0
        BVS     Exit
 [ DesktopAllAtOnce
        B       PollLoop
 |
        LDR     r0, PumpHidden
        TEQ     r0, #0
        BNE     PollLoop

IgnoreEvent
        ; This should only accept NULL events
        LDR     r0, =null_bit :OR: pollword_enable
        ADR     r1, scratchbuffer1
        ADR     r3, IgnoreEvent                 ; somewhere which is non-zero
        SWI     XWimp_Poll
        BVS     Exit
        TEQ     r0, #User_Message
        TEQNE   r0, #User_Message_Recorded
        BEQ     MessageGotten
        TEQ     r0, #PollWord_NonZero
        BNE     IgnoreEvent
        B       PollLoop

MessageGotten ROUT
        LDR     r0, scratchbuffer1 + ms_action
        TEQ     r0, #Message_Quit
        BNE     IgnoreEvent
        B       Exit
 ]

AllDone
 [ KeepItUp
        LDR     r2, BannerCloseTime
        TEQ     r2, #0
        BEQ     Exit                    ; Nothing to keep up... (no banner)

        BL      IconBarHackClose

KeepItUpLoop
        MOV     r0, #0
        ADR     r1, scratchbuffer1
        LDR     r2, BannerCloseTime
        SWI     XWimp_PollIdle
        BVS     Exit
1
        Push    r0
        LDR     r2, BannerCloseTime
        SWI     XOS_ReadMonotonicTime
        CMP     r0, r2
        Pull    r0
        BHS     Exit
        TEQ     r0, #Mouse_Button_Change
        BEQ     Exit
        TEQ     r0, #User_Message
        TEQNE   r0, #User_Message_Recorded
        BEQ     GotMessageKeepingItUp
        B       KeepItUpLoop

GotMessageKeepingItUp
        LDR     lr, scratchbuffer1 + ms_action
        LDR     r2, =Message_ModeChange
        TEQ     lr, r2
        LDREQ   r2, ModeChangeCount
        ADDEQ   r2, r2, #1              ; ignore ModeChange unless we've already had one
        STREQ   r2, ModeChangeCount     ; but subsequent ones are important
        TEQEQ   r2, #2                  ; because we can't be bothered to recache fonts...
        TEQNE   lr, #Message_Quit
        BEQ     Exit
        B       KeepItUpLoop

; If we just open the window, the iconbar will open later and will be in front of us. Thus
; when the pinboard opens at the back (-2), it will open in front of the (backwindow) iconbar
; and hence in front of us :-( Thus put an invisible icon on the iconbar before we start,
; then delete it when all module tasks are started (ie before any redrawing actually gets
; a chance to happen, hopefully, so it will never be seen)..
;
; A better solution would be to modify the wimp to ensure the icon bar isn't created at the front
IconbarHack
        Push    "r0-r1,lr"
        SUB     sp,sp,#36
        MOV     r1,sp
        MOV     r0,#-1
        STR     r0,[r1,#0]      ; Open at left
        MOV     r0,#0
        STR     r0,[r1,#4]      ; min x
        STR     r0,[r1,#8]      ; min y
        STR     r0,[r1,#16]     ; max y
        STR     r0,[r1,#20]     ; flags
        MOV     r0,#-16
        STR     r0,[r1,#12]     ; max x (hack to make it take up no space on iconbar)
        SWI     XWimp_CreateIcon
        STR     r0,IconHandle
        ADD     sp,sp,#36
        Pull    "r0-r1,pc"

IconBarHackClose
        Push    "r0-r1,lr"
        MOV     r0,#-2
        LDR     r1,IconHandle
        STMFD   sp!,{r0-r1}
        MOV     r1,sp
        SWI     XWimp_DeleteIcon
        ADD     sp,sp,#8
        Pull    "r0-r1,pc"
 ]
;
; call OS_Exit - exits back to Wimp if any tasks started
;
Exit
        MOV     r9, r0                  ; preserve error
        SavePSR r8                      ; preserve V flag (and others)

 [ debugtm
        Pull    "r1"
        SWI     XOS_ReadMonotonicTime
        SUB     r1, r0, r1
        Debug   tm,"*Desktop command completion ",r1
        Push    "r0"
 ]
        MOV     R1, #Service_StartedWimp ; tell them I've finished!
        SWI     XOS_ServiceCall
 [ debugtm
        Pull    "r1"
        SWI     XOS_ReadMonotonicTime
        SUB     r1, r0, r1
        Debug   tm,"Service_StartedWimp ",r1
        Push    "r0"
 ]

Exit2
 [ NewBanner
        BL      FreeFontsEtc
 ]

        ; Close messages file
        ADR     r0, MessageBlock
        SWI     XMessageTrans_CloseFile

        ; free sprites
        LDR     r2, privatesprites
        TEQ     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        MOV     r0, #0
        STR     r0, privatesprites

        ; free workspace
        MOV     r0, #ModHandReason_Free
        MOV     r2, wp
        SWI     XOS_Module

        ; Generate the original error
        TST     r8, #V_bit
        MOVNE   r0, r9
        SWINE   OS_GenerateError

        SWI     OS_Exit
        LTORG

keydef  DCB     "file/A/K",0
        ALIGN

com_unset       DCB     "%Unset "
str_desktopfile DCB     "Desktop$$File", 0

                ALIGN
;
; List of message tokens for commands required to start up the ROM
; applications
;
bootcommands
com1    DCB     com2 - com1, "Alarm", 0
com2    DCB     com3 - com2, "Printers", 0      ; was Calc
com3    DCB     com4 - com3, "Chars", 0
com4    DCB     com5 - com4, "Config", 0
com5    DCB     com6 - com5, "Draw", 0
com6    DCB     com7 - com6, "Edit", 0
com7    DCB     com8 - com7, "Help", 0
com8    DCB     com9 - com8, "Paint", 0
com9    DCB     0,0

bootbits_mask   *       (1 :SHL: 8) - 1
        ALIGN

; *****************************************************************************
;
; PumpModuleApps
;
StartPumpModuleApps Entry
        ADR     r0, PumpOneModuleApp
        STR     r0, NextPump
        B       %FT01
PumpOneModuleApp ALTENTRY
01
        Debug   tm, "Service_StartWimp"
        MOV     r1, #Service_StartWimp
        SWI     XOS_ServiceCall
        EXIT    VS
        TEQ     r1, #Service_Serviced
        BNE     %FT50
 [ debugtm
        MOV     r14, r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0,r14"
        MOV     r0,r14
 ]
        SWI     XWimp_StartTask         ; start up as new task if claimed
 [ debugtm
        Pull    "r1,r3"
        SWI     XOS_ReadMonotonicTime
        SUB     r1, r0, r1
        Debuga  tm,"Time ",r1
        DebugS  tm," app ",r3
 ]
        EXIT

50
        ADR     r0, StartPumpBootROMApps
        STR     r0, NextPump
        MOV     r0, #0
        STR     r0, PumpHidden
        EXIT

; -----------------------------------------------------------------------------
;
; PumpBootROMApps
;
; enumerate "Resources:$.Apps", and call *Filer_Boot for all these
; NB: must be done after the modules are started (Filer in particular)
;
StartPumpBootROMApps Entry

        ; Copy "Filer_Boot Resources:$.Apps." into Buffer

        ADRL    R1, filerboot           ; R1 -> "Filer_Boot Resources:$.Apps"
        ADR     R2, scratchbuffer1      ; R2 -> output buffer
11      LDRB    R14, [R1], #1
        TEQ     R14, #0
        STRNEB  R14, [R2], #1
        BNE     %BT11
        MOV     R14, #"."               ; put a "." on the end
        STRB    R14, [R2], #1

        ; Set up the PumpParams
        MOV     R4, #0                  ; R4 = 0 (start at first file)
        ADR     R5, scratchbuffer1 + ?scratchbuffer1
        SUB     R5, R5, R2              ; R5 = buffer size

        STR     r2, PumpParams_0
        STR     r4, PumpParams_1
        STR     r5, PumpParams_2

        ADR     r0, PumpOneBootROMApp
        STR     r0, NextPump
        B       %FT01

PumpOneBootROMApp ALTENTRY
01

        ; Pick up params
        MOV     r0, #OSGBPB_ReadDirEntries
        ADRL    r1, appsdir             ; r1 -> "Resources:$.Apps"
        LDR     r2, PumpParams_0        ; buffer to read to
        LDR     r4, PumpParams_1        ; position
        LDR     r5, PumpParams_2        ; buffer size
        ADRL    r6, plingstar           ; Wildcard is "!*"

        ; Read next app to boot
10
        MOV     r3, #1                  ; objects to read = 1
        SWI     XOS_GBPB                ; Wimp handles errors
        MOVVS   r4, #-1                 ; Convert error to giving up on the ROM apps
        CMP     r4, #0
        BLT     %FT50                   ; finish if finished directory
        CMP     r3, #1
        BLT     %BT10                   ; Loop if nothing matched wildcard

        STR     r4, PumpParams_1        ; to continue next time

        ; Boot the app
        ADR     R0, scratchbuffer1      ; perform *Filer_Boot Resources:$.Apps.<filename>
 [ debugtm
        MOV     r14, r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0,r14"
        MOV     r0,r14
 ]
        SWI     XOS_CLI                 ; starts a new Wimp task
 [ debugtm
        Pull    "r7,r8"
        SWI     XOS_ReadMonotonicTime
        SUB     r7, r0, r7
        Debuga  tm,"Time ",r7
        DebugS  tm," command ",r8
 ]
        EXIT

50
        ADR     r0, StartPumpStartROMApps
        STR     r0, NextPump
        EXIT
; -----------------------------------------------------------------------------
;
; PumpStartROMApps
;
; now start up the ROM-based applications,
; if the relevant bits in DeskbootCMOS are set.
;
StartPumpStartROMApps Entry
        LDR     r14, nactive            ; don't start unless this was first task
        TEQ     r14, #0
        BNE     %FT50

        MOV     r0, #ReadCMOS
        MOV     r1, #DeskbootCMOS
        SWI     XOS_Byte
        EXIT    VS

        MOV     r3, r2
        MOV     r1, #Deskboot2CMOS
        SWI     XOS_Byte
        EXIT    VS
        AND     r2, r2, #bootbits_mask :SHR: 8
        ORR     r2, r3, r2, LSL #8      ; r2 = full flag word

        ADRL    r3,bootcommands

        STR     r2, PumpParams_0
        STR     r3, PumpParams_1

        ADR     r0, PumpOneStartROMApp
        STR     r0, NextPump
        B       %FT01

PumpOneStartROMApp ALTENTRY
01
        LDR     r2, PumpParams_0
        LDR     r3, PumpParams_1
10
        MOVS    r2, r2, LSR #1          ; is next bit set?
        BNE     %FT20
        BCC     %FT50                   ; EQ and CC, ie no more commands to activate
20
        ADD     r1, r3, #1
        LDRB    r14, [r3]
        ADD     r3, r3, r14
        STR     r2, PumpParams_0
        STR     r3, PumpParams_1
        BCC     %BT10
 [ debugtm
        MOV     r14, r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0,r14"
        MOV     r0,r14
 ]
; OSS Look the command up in the Messages file.

        BL      MsgLookup
        BVS     %FT47
        MOV     r0, r1
        SWI     XWimp_StartTask
 [ debugtm
        Pull    "r7,r8"
        SWI     XOS_ReadMonotonicTime
        SUB     r7, r0, r7
        Debuga  tm,"Time ",r7
        DebugS  tm," command ",r8
 ]
        EXIT

; OSS Report a lookup error on the start command.

47
        ADRL    r1, Desktop_Title
        MOV     r2, r0                  ; Save original error
        BL      MsgLookup
        MOV     r0, r2                  ; Restore original error
        ADRVSL  r2, Desktop_Title       ; Hardcoded banner if failed
        MOVVC   r2, r1                  ; otherwise looked up one.
        MOV     r1, #1                  ; Provide an OK box.
        SWI     XWimp_ReportError
        EXIT

50
        ADR     r0, StartPumpDesktopCommands
        STR     r0, NextPump
        EXIT

; -----------------------------------------------------------------------------
;
; PumpDesktopCommands
;
; now execute the command on the parameter line
; if null, this causes a screen redraw
; it can also indicate a *Obey file, containing *WimpTask commands
;
StartPumpDesktopCommands Entry

        ADRL    r0, keydef
        ADR     r1, commandtail
        ADR     r2, scratchbuffer1
        MOV     r3, #?scratchbuffer1
        SWI     XOS_ReadArgs            ; 'Bad parameters' if -file not present
        BVC     executefile
;
; Single command - Wimp_StartTask this
        ADR     r0, commandtail
        SWI     XWimp_StartTask
        B       %FT50

; -File blah
executefile
        ADRL    r0, str_desktopfile     ; r0 -> "Desktop$File"
        LDR     r1, scratchbuffer1      ; r1 -> new value
        MOV     r2, #1                  ; create item, don't delete it
        MOV     r3, #0                  ; search whole name space
        MOV     r4, #VarType_String     ; GSTrans the value now
        SWI     XOS_SetVarVal           ; abort on error
        EXIT    VS

        MOV     r0, #OSFind_ReadFile
        LDR     r1, scratchbuffer1      ; r1 --> filename (must be present)
        SWI     XOS_Find                ; don't care if error aborts
        EXIT    VS

        STR     r0, PumpParams_0        ; file handle

        ADR     r0, PumpOneDesktopCommand
        STR     r0, NextPump

        B       %FT01

PumpOneDesktopCommand ALTENTRY
01
        ; Use whole of scratch space for reading lines of file.
        ASSERT  scratchbuffer2 = scratchbuffer1 + ?scratchbuffer1
        LDR     r1, PumpParams_0
        ADR     r2, scratchbuffer1
        MOV     r3, #?scratchbuffer1 + ?scratchbuffer2
10
        SWI     XOS_BGet
        BVS     %FT40                   ; close file on error
        BCS     %FT40                   ; eof in middle of line ==> ignore it
        SUBS    r3, r3, #1
        STRHIB  r0, [r2], #1
        CMPHI   r0, #" "
        BHS     %BT10

        CMP     r3, #0
        BEQ     %FT20

        ADR     r0, scratchbuffer1
 [ debugtm
        MOV     r14, r0
        SWI     XOS_ReadMonotonicTime
        Push    "r0,r14"
        MOV     r0,r14
 ]
        SWI     XWimp_StartTask         ; no way that error aborts can happen!
 [ debugtm
        Pull    "r7,r8"
        SWI     XOS_ReadMonotonicTime
        SUB     r7, r0, r7
        Debuga  tm,"Time ",r7
        DebugS  tm," command ",r8
 ]

        EXIT

 MakeInternatErrorBlock BuffOverflow,,BufOFlo

        ; Buffer overflow
20      ADR     r0, ErrorBlock_BuffOverflow
        MOV     r1, #0
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        LDR     r1, PumpParams_0

40
        ; Close file on completion or error
        MOV     r4, r0                  ; NB STACK CANNOT BE USED !!!!
        SavePSR r5
        MOV     r0, #0                  ; close file
        SWI     XOS_Find                ; errors blow up again
        RestPSR r5,,f
        MOVVS   r0, r4
        EXIT    VS

50
        MOV     r0, #0
        STR     r0, NextPump
        EXIT

; *****************************************************************************
;
; DisplayWelcomeScreen
;
DisplayWelcomeScreen
 [ :LNOT:NewBanner

      [ :LNOT: Embedded_UI              ; RWB - Remove welcome screen
        ^       0,sp
Welcome_font    #       4
Welcome_font1   #       4
Welcome_font2   #       4
Welcome_nx      #       4
Welcome_ny      #       4
Welcome_npix    #       4
Welcome_Matrix  #       32
Welcome_Buffer  #       20
Welcome_Count   #       4
Welcome_Area    #       4
Welcome_WSSize  * :INDEX: @

        Entry ,Welcome_WSSize

        MOV     r0,#-1
        MOV     r1,#11
        SWI     XOS_ReadModeVariable
        BVS     WelcomeError_NoFont
        MOV     r6,r2
        MOV     r1,#4
        SWI     XOS_ReadModeVariable    ;Get xeig
        BVS     WelcomeError_NoFont
        MOV     r6,r6,ASL r2
        STR     r6,Welcome_nx

        MOV     r1,#12
        SWI     XOS_ReadModeVariable
        BVS     WelcomeError_NoFont
        MOV     r7,r2
        MOV     r1,#5
        SWI     XOS_ReadModeVariable    ;Get  Yeig
        BVS     WelcomeError_NoFont
        MOV     r7,r7,ASL r2
        STR     r7,Welcome_ny

        MOV     r1,#9
        SWI     XOS_ReadModeVariable
        BVS     WelcomeError_NoFont
        STR     r2,Welcome_npix         ; npix

        Debug   we,"About to find first font"

        ADRL    r1,WelcomeFont
        MOV     r2,#32*16
        MOV     r3,r2
        MOV     r4,#0
        MOV     r5,#0
        SWI     XFont_FindFont          ; r0 = font handle
        BVS     WelcomeError_NoFont
        STR     r0,Welcome_font
        Debug   we,"First font found",r0

        LDR     r1,=&dddddd00
        LDR     r2,=&00000000
        LDR     r3,Welcome_npix
        CMP     R3,#1
        MOVEQ   r3,#0
        MOVNE   r3,#14
        SWI     XColourTrans_SetFontColours
        BVS     WelcomeError_OneFont
        Debug   we,"Colours for first font set"

        ADRL    r1,WelcomeString1
        BL      MsgLookup
        BVS     WelcomeError_OneFont
        MOV     r2,#&40000000
        MOV     r3,#&40000000
        MOV     r4,#-1
        MOV     r5,#255
        SWI     XFont_StringWidth
        BVS     WelcomeError_OneFont
        Debug   we,"width 1 found"
        MOVVC   r1,r2
        SWIVC   XFont_ConverttoOS
        BVS     WelcomeError_OneFont
        MOV     r9,r2                   ; xw1
        Debug   we,"Width of string 1 ",r9

        Debug   we,"About to find second font"
        ADRL    r1,WelcomeFont
        MOV     r2,#18*16
        MOV     r3,r2
        MOV     r4,#0
        MOV     r5,#0
        SWI     XFont_FindFont          ; r0 = font handle
        BVS     WelcomeError_OneFont
        STR     r0,Welcome_font1
        Debug   we,"Font 2 found",r0

        LDR     r1,=&dddddd00
        LDR     r2,=&00000000
        LDR     r3,Welcome_npix
        CMP     R3,#1
        MOVEQ   r3,#0
        MOVNE   r3,#14
        SWI     XColourTrans_SetFontColours
        BVS     WelcomeError_TwoFonts
        Debug   we,"Colours for second font set"

        ADRL    r1,WelcomeString2
        BL      MsgLookup
        BVS     WelcomeError_TwoFonts
        MOV     r2,#&40000000
        MOV     r3,#&40000000
        MOV     r4,#-1
        MOV     r5,#255
        SWI     XFont_StringWidth
        BVS     WelcomeError_TwoFonts
        Debug   we,"width of dtring 2 found"
        MOVVC   r1,r2
        SWIVC   XFont_ConverttoOS
        BVS     WelcomeError_TwoFonts
        MOV     r10,r2                  ; xw2
        Debug   we,"Width of string 2 ",r10

        Debug   we,"About to find third font"
        ADRL    r1,WelcomeFont2
        MOV     r2,#14*16
        MOV     r3,r2
        MOV     r4,#0
        MOV     r5,#0
        SWI     XFont_FindFont          ; r0 = font handle
        BVS     WelcomeError_TwoFonts
        STR     r0,Welcome_font2
        Debug   we,"Font 3 found",r0

        LDR     r1,=&dddddd00
        LDR     r2,=&00000000
        LDR     r3,Welcome_npix
        CMP     R3,#1
        MOVEQ   r3,#0
        MOVNE   r3,#14
        SWI     XColourTrans_SetFontColours
        BVS     WelcomeError_ThreeFonts
        Debug   we,"Colours for third font set"

        ADRL    r1,WelcomeString3
        BL      MsgLookup
        BVS     WelcomeError_ThreeFonts
        MOV     r2,#&40000000
        MOV     r3,#&40000000
        MOV     r4,#-1
        MOV     r5,#255
        SWI     XFont_StringWidth
        BVS     WelcomeError_ThreeFonts
        Debug   we,"width of string 3 found"
        MOVVC   r1,r2
        SWIVC   XFont_ConverttoOS
        BVS     WelcomeError_ThreeFonts
        MOV     r11,r2                  ; xw3
        Debug   we,"Width of string 2 ",r11

        LDR     r6,Welcome_nx
        MOV     r5,r6,LSR #1            ; x

        LDR     r7,Welcome_ny
        MOV     r4,r7,LSR #1            ; y

        Debug   we,"x y ",r4,r5

        ADD     r8,r9,#100
        CMP     r8,r10
        MOVLT   r8,r10
        ADD     r8,r8,#100
        CMP     r8,r11
        MOVLT   r8,r11                  ; lx
        Debug   we,"lx ",r8

        LDR     r1,Welcome_npix
        Debug   we,"set colour",r1
        CMP     r1,#0
        MOVEQ   r0,#7
        MOVNE   r0,#6
        SWI     XWimp_SetColour
        BVS     WelcomeError_ThreeFonts

        MOV     r0,#4                   ; Move
        SUB     r1,r5,r8,LSR #1
        ADD     r1,r1,#8
        SUB     r2,r4,#256
        SUB     r2,r2,#2
        SWI     XOS_Plot
        MOVVC   r0,#96+5                ; Filled rectangle
        ADDVC   r1,r1,r8
        ADDVC   r2,r2,#500
        SWIVC   XOS_Plot
        BVS     WelcomeError_ThreeFonts

        LDR     r1,Welcome_npix
        Debug   we,"set colour II",r1
        CMP     r1,#0
        MOVEQ   r0,#0
        MOVNE   r0,#1
        SWI     XWimp_SetColour
        BVS     WelcomeError_ThreeFonts

        MOV     r0,#4                   ; Move
        SUB     r1,r5,r8,LSR #1
        SUB     r2,r4,#250
        SWI     XOS_Plot
        MOVVC   r0,#96+5                ; Filled rectangle
        ADDVC   r1,r1,r8
        ADDVC   r2,r2,#500
        SWIVC   XOS_Plot
        BVS     WelcomeError_ThreeFonts

        MOV     r0,#7
        SWI     XWimp_SetColour
        BVS     WelcomeError_ThreeFonts

        MOV     r0,#4                   ; Move
        SUB     r1,r5,r8,LSR #1
        SUB     r2,r4,#250
        SWI     XOS_Plot
        MOVVC   r0,#5                   ; Line
        ADDVC   r1,r1,r8
        SWIVC   XOS_Plot
        ADDVC   r2,r2,#500
        SWIVC   XOS_Plot                ; Line
        SUBVC   r1,r1,r8
        SWIVC   XOS_Plot                ; Line
        SUBVC   r2,r2,#500
        SWIVC   XOS_Plot                ; Line
        BVS     WelcomeError_ThreeFonts

        LDR     r1,Welcome_npix
        Debug   we,"set colour (Acorn)",r1
        CMP     r1,#1
        MOVLT   r0,#7
        MOVEQ   r0,#5
        MOVGT   r0,#10
        SWI     XWimp_SetColour
        BVS     WelcomeError_ThreeFonts

        MOV     r0,#&3000               ; Scale factor
        STR     r0,Welcome_Matrix
        STR     r0,Welcome_Matrix+12
        MOV     r0,#0
        STR     r0,Welcome_Matrix+4
        STR     r0,Welcome_Matrix+8
        SUB     r0,r5,#75
        MOV     r0,r0,ASL #8
        STR     r0,Welcome_Matrix+16
        ADD     r0,r4,#50
        MOV     r0,r0,ASL#8
        STR     r0,Welcome_Matrix+20

        ADRL    r0,Welcome_AcornPath
11
        LDR     r1,[r0],#4
        Debug   we,"Length = ",r1
        CMP     r1,#0
        MOVNE   r1,#0
        ADRNE   r2,Welcome_Matrix
        MOVNE   r3,#0
        Push    "r0"
        SWINE   XDraw_Fill
        Pull    "r0"
        BVS     WelcomeError_ThreeFonts
        LDR     r1,[r0,#-4]
        CMP     r1,#0
        ADDNE   r0,r0,r1, ASL #2
        BNE     %BT11

        Debug   we,"Acorn plotted"

        LDR     r0,Welcome_font
        SWI     XFont_SetFont
        ADRVCL  r1,WelcomeString1
        BLVC    MsgLookup
        BVS     WelcomeError_ThreeFonts
        MOV     r2,#2_10000
        SUB     r3,r5,r9,LSR #1
        Push    "r4"
        SUB     r4,r4,#26
        SWI     XFont_Paint
        Pull    "r4"
        BVS     WelcomeError_ThreeFonts

        LDR     r0,Welcome_font1
        SWI     XFont_SetFont
        ADRVCL  r1,WelcomeString2
        BLVC    MsgLookup
        BVS     WelcomeError_ThreeFonts
        MOV     r2,#2_10000
        SUB     r3,r5,r10,LSR #1
        Push    "r4"
        SUB     r4,r4,#80
        SWI     XFont_Paint
        Pull    "r4"
        BVS     WelcomeError_ThreeFonts

        LDR     r0,Welcome_font2
        SWI     XFont_SetFont
        ADRVCL  r1,WelcomeString3
        BLVC    MsgLookup
        BVS     WelcomeError_ThreeFonts
        MOV     r2,#2_10000
        SUB     r3,r5,r11,LSR #1
        Push    "r4"
        SUB     r4,r4,#200
        SWI     XFont_Paint
        Pull    "r4"

; OSS This section used to be conditionally compiled in for pre-release
; versions to display the pre-release string. It now works by looking the
; string up in the messages file, and not displaying anything if the
; string is absent. Thus RAM loaded localisations have a extra string to
; play with for their pre-release versions as was done for the Mexico
; Amber version.

        BVS     WelcomeError_ThreeFonts
        LDR     r0,Welcome_font
        Push    "r4,r5"
        SWI     XFont_SetFont
        BVS     %FT01
        ADRL    r1,WelcomeString4
        BL      MsgLookup
        BVS     %FT01
        MOV     r2,#&40000000
        MOV     r3,#&40000000
        MOV     r4,#-1
        MOV     r5,#255
        SWI     XFont_StringWidth
01
        Pull    "r4,r5"
        BVS     WelcomeError_ThreeFonts
        Debug   we,"width of string 4 found"
        MOVVC   r1,r2
        SWIVC   XFont_ConverttoOS
        BVS     WelcomeError_ThreeFonts
        MOV     r11,r2                  ; xw3
        Debug   we,"Width of string 4 ",r11

        LDR     r1,=&77777700
        LDR     r2,=&00000000
        LDR     r3,Welcome_npix
        CMP     R3,#1
        MOVEQ   r3,#0
        MOVNE   r3,#14
        SWI     XColourTrans_SetFontColours
        BVS     WelcomeError_ThreeFonts
        Debug   we,"Colours for third(4) font set"

        ADRL    r1,WelcomeString4
        BL      MsgLookup
        BVS     WelcomeError_ThreeFonts
        DebugS  we,"Fourth string is", r1
        MOV     r2,#2_10000
        SUB     r3,r5,r11,LSR #1
        Push    "r4"
        SUB     r4,r4,#364
        SWI     XFont_Paint
        Pull    "r4"

WelcomeError_ThreeFonts
        LDR     r0,Welcome_font2
        SWI     XFont_LoseFont
WelcomeError_TwoFonts
        LDR     r0,Welcome_font1
        SWI     XFont_LoseFont
WelcomeError_OneFont
        LDR     r0,Welcome_font
        SWI     XFont_LoseFont
WelcomeError_NoFont

        EXIT
      ]
      [ debug
        InsertNDRDebugRoutines
      ]

 | ; NewBanner

        Push    "R1-R7,lr"
        ADR     R1,templatename
        SWI     XWimp_OpenTemplate
        Pull    "R1-R7,PC",VS
        MOV     R0,#ModHandReason_Claim
        MOV     R3,#1024
        SWI     XOS_Module
        Pull    "R1-R7,PC",VS
        MOV     R7,R2
        STR     R7,NewWelcomeWorkspace

        MOV     R0,#64
        MOV     R1,#0
        ADD     R3,R2,#768
05
        STR     R1,[R3],#4                      ; clear font ref count
        SUBS    R0,R0,#1
        BNE     %BT05

        MOV     r0,#-1
        MOV     r1,#11
        SWI     XOS_ReadModeVariable
        MOVVC   r6,r2
        MOVVC   r1,#4
        SWIVC   XOS_ReadModeVariable            ;Get xeig
        SUBVS   SP,SP,#12
        BVS     ExitDisplay
        MOV     r6,r6,ASL r2

        ADD     R6,R6,#16
        Push    R6

        MOV     r0,#-1
        MOV     r1,#12
        SWI     XOS_ReadModeVariable
        MOVVC   r6,r2
        MOVVC   r1,#5
        SWIVC   XOS_ReadModeVariable            ;Get yeig
        SUBVS   SP,SP,#8
        BVS     ExitDisplay
        MOV     r6,r6,ASL r2

        SUB     R6,R6,#16                       ; drop shadow
        Push    R6

        MOV     R2,R7
        ADR     R5,backdropname
        MOV     R0,#0
        BL      displaywindow

        Pull    "R5,R6"
        Push    R9

        ADD     R5,R5,#16
        SUB     R6,R6,#16

        Push    "R5,R6"                         ; make sure this pair is last on for 'displaywindow' to read

        MOV     R2,R7

        ADR     R5,desktopname
        BL      displaywindow

        SWI     XWimp_CloseTemplate
      [ DateFromKernel
        ; Modify the copyright string "    (C) Owner" to
        ;                             "(C)YYYY Owner" if possible based on OSByte 0
        SUB     SP,SP,#gi_size
        STR     R9,[SP,#gi_handle]
        MOV     R1,#6                           ; copyright string icon number
        STR     R1,[SP,#gi_iconhandle]
        MOV     R1,SP
        SWI     XWimp_GetIconState
        BVS     %FT30

        LDR     R0,[SP,#gi_iconblock+i_flags]
        TST     R0,#if_indirected
        BEQ     %FT30                           ; only deal with indirected case
        LDR     R4,[SP,#gi_iconblock+i_data+ii_buffer]
        ADD     SP,SP,#gi_size

        ; Get the version
        MOV     R0,#0
        MOV     R1,#0
        SWI     XOS_Byte
        ADD     R0,R0,#4                        ; skip error number
10
        ; Look for closing bracket
        LDRB    R1,[R0],#1
        TEQ     R1,#0
        BEQ     %FT30                           ; no bracket, nevermind, template makes sense on its own
        TEQ     R1,#")"
        BNE     %BT10
        SUB     R3,R0,#1

        ; Check for preceding YYYY digits
        SUB     R1,R3,#4
        MOV     R0,#10
        SWI     XOS_ReadUnsigned
        BVS     %FT30
        TEQ     R3,R1
        BNE     %FT30                           ; non decimals, nevermind, template makes sense on its own

        ; Move the copyright symbol back
        LDRB    R0,[R4,#5]
        STRB    R0,[R4,#0]

        ; Overlay the year then zap the null terminator
        MOV     R0,R2
        ADD     R1,R4,#2
        MOV     R2,#5
        SWI     XOS_ConvertCardinal2
        MOV     R0,#" "
        STRB    R0,[R1]
30
      ]
        MOV     R0,R9
        BL      redrawwindow                    ; fore
        LDR     R0,[SP,#2*4]
        BL      redrawwindow                    ; back

        B       ExitDisplay

templatename    DCB     "Resources:$.Resources.Desktop.Templates",0
backdropname    DCB     "backdrop",0
desktopname     DCB     "desktop",0
        ALIGN

displaywindow
        Push    "lr"
        MOV     R1,R2
        ADD     R2,R2,#512
        ADD     R3,R2,#256
        ADD     R4,R7,#768
        MOV     R6,#0
        SWI     XWimp_LoadTemplate
        ADDVS   SP,SP,#4
        BVS     ExitDisplay

        LDR     r0, privatesprites
        STR     r0, [r1, #64]                   ; use local sprite pool in the 'desktop' window
        SWI     XWimp_CreateWindow
        ADDVS   SP,SP,#4
        BVS     ExitDisplay

        STR     R0,[SP,#-44]!
        MOV     R1,SP
        SWI     XWimp_GetWindowState

        ADD     R14,R1,#4
        LDMIA   R14,{R2-R5}
        LDR     R6,[SP,#52]                     ; xpix
        SUB     R4,R4,R2                        ; width
        SUB     R2,R6,R4
        MOV     R2,R2, LSR #1
        ADD     R4,R2,R4

        LDR     R6,[SP,#48]                     ; ypix
        SUB     R5,R5,R3
        SUB     R3,R6,R5
        MOV     R3,R3, LSR #1
        ADD     R5,R3,R5

        STMIA   R14,{R2-R5}

        MOV     R14,#-1
        STR     R14,[R1,#28]                    ; make absolutely sure we open on top

        SWI     XWimp_OpenWindow
        LDRVC   R9,[R1,#0]
        ADD     SP,SP,#44
        Pull    "PC",VC
        B       ExitDisplay

redrawwindow
        Push    "LR"
        SUB     SP,SP,#44
        MOV     R1,SP
        STR     R0,[SP,#0]
        SWI     XWimp_RedrawWindow
        ADDVS   SP,SP,#44
        BVS     ExitDisplay
01
        TEQ     R0,#0
        ADDEQ   SP,SP,#44
        Pull    PC,EQ
        SWI     XWimp_GetRectangle
        ADDVS   SP,SP,#44
        BVS     ExitDisplay
        B       %BT01



ExitDisplay
        ADD     SP,SP,#12                       ; skip 3 * items on stack
 [ KeepItUp
        Pull    "R1-R7,PC"
FreeFontsEtc
        Push    "R1-R7,LR"
        LDR     R7,NewWelcomeWorkspace
        TEQ     R7,#0
        Pull    "R1-R7,PC",EQ
 ]
        Push    R0
        ADD     R1,R7,#768
        MOV     R0,#255
05
        LDRB    R14,[R1,R0]
07
        TEQ     R14,#0
08
        SUBNE   R14,R14,#1
        SWINE   Font_LoseFont

        TEQ     R14,#0
        BNE     %BT08

        SUBS    R0,R0,#1
        BNE     %BT05

        MOV     R2,R7
        MOV     R0,#ModHandReason_Free
        SWI     XOS_Module

        LDR     R2, privatesprites
        TEQ     R2,#0
        MOVNE   R0,#ModHandReason_Free
        SWINE   XOS_Module
        MOV     R0, #0
        STR     R0, privatesprites

        Pull    R0
        Pull    "R1-R7,PC"

 ]

        END
