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
; -> s.Taskman

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:EnvNumbers
        GET     Hdr:Messages
        GET     Hdr:UpCall
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:ResourceFS
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:MsgTrans
        GET     Hdr:FPEmulator
        GET     Hdr:PublicWS
        GET     Hdr:OSRSI6
        GET     Hdr:OSMisc
        GET     VersionASM

        GBLL    CheckBufferPointers
CheckBufferPointers SETL {FALSE}

        MACRO
        CheckPointers
      [ CheckBufferPointers
        Push    "r1,lr"
        MOV     r1, #"P"
        STRB    r1, Debug_InOut
        MOV     r1, #0
        BL      checkbufferpointers
        MOV     r1, #1
        BL      checkbufferpointers
        Pull    "r1,lr"
      ]
        MEND

        MACRO
        CheckIn
      [ CheckBufferPointers
        Push    "r1,lr"
        MOV     r1, #"I"
        STRB    r1, Debug_InOut
        MOV     r1, #0
        BL      checkbufferpointers
        MOV     r1, #1
        BL      checkbufferpointers
        Pull    "r1,lr"
      ]
        MEND

        MACRO
        CheckOut
      [ CheckBufferPointers
        Push    "r1,lr"
        MOV     r1, #"O"
        STRB    r1, Debug_InOut
        MOV     r1, #0
        BL      checkbufferpointers
        MOV     r1, #1
        BL      checkbufferpointers
        Pull    "r1,lr"
      ]
        MEND

        MACRO
        MyCLREX $temp1, $temp2
        ; Returning to code that was pre-empted, so CLREX required
    [ NoARMv6
      [ SupportARMv6
        ; Need to support both old and new architectures
        LDR     $temp1, GlobalWS
        LDR     $temp2, [$temp1, #:INDEX:PlatFeatures]
        TST     $temp2, #CPUFlag_LoadStoreEx
        SUB     $temp1, r13, #4
        STREXNE $temp2, $temp1, [$temp1]
      ]
    ELIF NoARMK
        ; ARMv6, need dummy STREX
        ; Use the word below SP
        SUB     $temp1, r13, #4
        STREX   $temp2, $temp1, [$temp1]      
    |
        ; ARMv6K+, have CLREX
        CLREX
    ]
        MEND

        GBLL StrongARM
        GBLL SASTMhatbroken
StrongARM      SETL {TRUE}
SASTMhatbroken SETL {TRUE} :LAND: StrongARM

;
; You want to change any of these settings?  You work out how to reorganise
; the R12 relative data so all the ADRs stay in range.  Took me long enough ... :-(
;

        GBLL    DebugStart
DebugStart SETL {FALSE}

        GBLL    FixDomain
FixDomain       SETL    {TRUE}

        GBLL    FixControl
FixControl      SETL    {TRUE}

        GBLL    FixReportName           ; true if task name used for Wimp_ReportError
FixReportName   SETL    {TRUE}          ; false if command string used

        GBLL    FixRedirection
FixRedirection  SETL    {TRUE}          ; NB: SWI not known overwrites GetEnv buffer!

        GBLL    FixSpool
FixSpool        SETL    {TRUE}

        GET     Messages.s

        GBLL    TerminateAndStayResident
TerminateAndStayResident SETL {TRUE}

        GBLL    FixNDR
FixNDR  SETL    {TRUE}

        GBLL    checkingcallback
checkingcallback SETL {TRUE}

        GBLL    resetingcallback
resetingcallback SETL {TRUE}

        GBLL    chainingcallback
chainingcallback SETL {TRUE}

        GBLL    Multiple
Multiple SETL   {TRUE}   ; TRUE allows multiple instantiation
                         ; FALSE disallows multiple instantiation

        GBLL    RealEscape
RealEscape SETL {FALSE}  ; TRUE allows escape to be enabled within task module
                         ; FALSE simulates it

        GBLL    EmulateEscapeChar
EmulateEscapeChar SETL {TRUE}

        GBLL    Preempt  ; TRUE allows preemption, FALSE disables it
Preempt SETL    {TRUE}

        GBLL    FPErrorHandling
FPErrorHandling SETL {FALSE} ; FP error in Wimp Poll is fatal anyway

        GBLL    UseFPPoll
UseFPPoll SETL  {TRUE}

        GBLL    DoingSwi
DoingSwi SETL   {TRUE}

        GBLL    UseInCallBack
UseInCallBack SETL {FALSE}

        GBLL    UseGotCallBack
UseGotCallBack SETL {FALSE}

        GBLL    PollIdleHandling
PollIdleHandling SETL {TRUE}

        GBLL    NiceNess
NiceNess        SETL  {TRUE}

    [ :LNOT: :DEF: standalone
        GBLL    standalone
standalone      SETL {FALSE}            ; Build-in Messages file and i/f to ResourceFS
    ]
    [ :LNOT: :DEF: international_help
        GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
    ]

        GBLL    UseTickerV
UseTickerV      SETL  {TRUE}

        GBLA    WimpVersion
WimpVersion SETA 300

        [       WimpVersion < 264
FPErrorHandling SETL {FALSE}
UseFPPoll SETL  {FALSE}
        ]

;
; Registers preserved before polling
;
        GBLS    Regs
Regs    SETS    "r1-r12, r14"
;
; Debug options
;
        GBLL    hostvdu
hostvdu SETL    {FALSE}

        GET     Hdr:NDRDebug
        GBLL    debugndr
        GBLL    debugenv
        GBLL    debugup
        GBLL    debugesc

debug           SETL    {FALSE}
debugndr        SETL    debug :LAND: {FALSE}
debugenv        SETL    debug :LAND: {FALSE}
debugup         SETL    debug :LAND: {FALSE}
debugesc        SETL    debug :LAND: {FALSE}

        GBLL    Debug
Debug   SETL    {FALSE}
        GBLL    DebugExit
DebugExit SETL  {FALSE}
        GBLL    DebugNL
DebugNL SETL    {FALSE}
        GBLL    DebugEvent
DebugEvent SETL {FALSE}
        GBLL    DebugWimp
DebugWimp SETL  {FALSE}
        GBLL    CheckSum
CheckSum SETL   {FALSE}

; **************************************************************************

;
; Byte numbers
;
EventDisable *  13
EventEnable *   14
Inkey   *       &81
EscapeSet *     125
EscapeClear *   124
EscapeAck *     126
ReadExec *      &C6
ReadSpool *     &C7
ReadFnKey *     221
EscapeChar *    229
EscapeSide *    230
;
; Characters
;
TAB     *       9
CR      *       13
LF      *       10
HSP     *       31             ; hard space
Esc     *       27
EventCount *    10

; *********************** Module code starts here *****************************

        AREA    |TaskWindow$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        DCD     Code_StartEntry   -Module_BaseAddr
        DCD     Code_InitEntry    -Module_BaseAddr
        DCD     Code_DieEntry     -Module_BaseAddr
        DCD     Code_ServiceEntry -Module_BaseAddr
        DCD     Code_TitleString  -Module_BaseAddr
        DCD     Code_HelpString   -Module_BaseAddr
        DCD     Code_CommandTable -Module_BaseAddr
        DCD     TaskWindowSWI_Base
        DCD     Code_SWIHandler   -Module_BaseAddr
        DCD     Code_SWITable     -Module_BaseAddr
        DCD     0
 [ international_help
        DCD     message_filename  -Module_BaseAddr
 |
        DCD     0
 ]
 [ :LNOT: No32bitCode
        DCD     Code_Flags        -Module_BaseAddr
 ]
Code_SWITable
Code_TitleString
        DCB     "TaskWindow", 0
        DCB     "TaskInfo", 0
        DCB     0

Code_HelpString
        DCB     "TaskWindow", TAB, "$Module_HelpVersion"
        DCB     0
        ALIGN

Code_CommandTable
      [ international_help
        Command "ShellCLI_Task",     2, 2, International_Help
        Command "ShellCLI_TaskQuit", 0, 0, International_Help
        Command "TaskWindow",      255, 1, International_Help
      |  
        Command "ShellCLI_Task",     2, 2, 0
        Command "ShellCLI_TaskQuit", 0, 0, 0
        Command "TaskWindow",      255, 1, 0
      ]
        DCB     0

      [ international_help
ShellCLI_Task_Help       DCB     "HTSWST", 0
ShellCLI_Task_Syntax     DCB     "STSWST", 0
ShellCLI_TaskQuit_Help   DCB     "HTSWSTQ", 0
ShellCLI_TaskQuit_Syntax DCB     "STSWSTQ", 0
                       [ NiceNess
TaskWindow_Help          DCB     "HTSWTSN", 0
TaskWindow_Syntax        DCB     "STSWTSN", 0
                       |
TaskWindow_Help          DCB     "HTSWTSW", 0
TaskWindow_Syntax        DCB     "STSWTSW", 0
                       ]
      |
ShellCLI_Task_Help       DCB     "*ShellCLI_Task runs an application in a window. The first argument "
                         DCB     "is an 8 digit hex. number giving the task handle of the parent "
                         DCB     "task. The second argument is an 8 digit hex. number giving a handle "
                         DCB     "which may be used by the parent task to identify the task.", CR
                         DCB     "This command is intended for use only within applications.", CR
ShellCLI_Task_Syntax     DCB     "Syntax: *ShellCLI_Task XXXXXXXX XXXXXXXX", 0
ShellCLI_TaskQuit_Help   DCB     "*ShellCLI_TaskQuit quits the current task window", CR
ShellCLI_TaskQuit_Syntax DCB     "Syntax: *ShellCLI_TaskQuit", 0
TaskWindow_Help          DCB     "The *TaskWindow command allows a background task to be started, "
                         DCB     "which will obtain a task window if it needs to do any screen I/O.", CR
                         DCB     "Options:", CR
                         DCB     TAB, "-wimpslot sets the memory to be allocated", CR
                         DCB     TAB, "-name sets the task name", CR
                         DCB     TAB, "-ctrl allows control characters through", CR
                         DCB     TAB, "-display opens the task window immediately, rather than waiting "
                         DCB           "for a character to be printed", CR
                         DCB     TAB, "-quit makes the task quit after the command even if the "
                         DCB           "task window has been opened", CR
                       [ NiceNess
                         DCB     TAB, "-nice alters number of timeslices given to task", CR
                       ]
                         DCB     "Note that fields must be in "" "" if they comprise more than one word", CR
                       [ NiceNess
TaskWindow_Syntax        DCB     "Syntax: *TaskWindow <command> [[-wimpslot] <n>K] [[-name] <taskname>] [-ctrl] [-display] [-quit] [-nice <n>]", 0
                       |
TaskWindow_Syntax        DCB     "Syntax: *TaskWindow <command> [[-wimpslot] <n>K] [[-name] <taskname>] [-ctrl] [-display] [-quit]", 0
                       ]
      ]
        ALIGN

MessagesList    DCD     Message_DataSave
                DCD     Message_RAMTransmit
                DCD     Input
                DCD     Morite
                DCD     Suspend
                DCD     Resume
                DCD     0

 [ :LNOT: No32bitCode
Code_Flags DCD ModuleFlag_32bit
 ]


; ***********************************************************************

Code_SWIHandler
        MOV     r10, lr
        SavePSR r11
        LDR     r12, [r12]
        BL      FindOwner
        MOV     r0, r12
        RestPSR r11,,f
        MOV     pc, r10

; Loop creating various variables if they don't already exist

setaliases      ROUT
        Push    "r1-r5, lr"

        ADR     r5, aliaslist

20      MOV     r0, r5                  ; Keep pointer to start of var name

        MOV     r7, r5
25      LDRB    r14, [r7], #1           ; Find start of variable value
        CMP     r14, #&FF               ; End of list ?
        BEQ     %FT40
        CMP     r14, #0                 ; End of variable name ?
        BNE     %BT25                   ; r7 -> variable value

        MOV     r5, r7                  ; Find start of next variable name
30      LDRB    r14, [r5], #1
        CMP     r14, #0                 ; End of variable value ?
        BNE     %BT30                   ; r5 -> next variable name

; Check for variable prescence first. r7 -> value to set

        MOV     r6, r0                  ; Save name^
        MOV     r3, #0
        MOV     r4, #VarType_String

34      MOV     r2, #-1                 ; r0 -> name
        SWI     XOS_ReadVarVal          ; Does it exist ? VSet misleading

        CMP     r4, #VarType_Number     ; Set if it's a number (that's silly)
        BEQ     %BT34                   ; Loop if so (maybe others)

        MOVS    r2, r2                  ; -ve -> exists
        BMI     %BT20                   ; Loop if already exists (macro,string)

35      MOV     r0, r6                  ; Restore name^
        MOV     r1, r7                  ; Restore value^
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #VarType_String
        SWI     XOS_SetVarVal           ; r0 -> name, r1 -> value
        BVC     %BT20
40
        Pull    "r1-r5, pc"

aliaslist
        DCB     "Alias$@RunType_FD7", 0
        DCB     "TaskWindow ""Obey %*0"" -name ""Task Obey"" -quit", 0

        DCB     "File$$Type_FD7", 0
        DCB     "TaskObey", 0

        DCB     "Alias$@RunType_FD6", 0
        DCB     "TaskWindow ""Exec %*0"" -name ""Task Exec"" -display", 0

        DCB     "File$$Type_FD6", 0
        DCB     "TaskExec", 0

        DCB     &FF                     ; terminator
        ALIGN

; .......................................................................

        [       DoingSwi
svc_reset
        STMDB   sp!, {r0, r1, r2, r3, lr}
        BL      Claim_SWIs
        LDR     r2, [r12]
        MOV     r0, #0
        STR     r0, [r12]
        B       svc_reset2
svc_reset1
        LDR     r12, [r2]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r2, r12
svc_reset2
        CMP     r2, #0
        BNE     svc_reset1
        LDMIA   sp!, {r0, r1, r2, r3, pc}

Claim_SWIs
        Push    "lr"
        SWI     XOS_GetEnv              ; find out where the MOS buffers are
        STRVC   r0, MOS_EnvString
        STRVC   r2, MOS_EnvTime

        MOVVC   r0, #WordV              ; claim WordV for mega-bodge to get round FileSwitch
        ADRVC   r1, MyWord              ; - it doesn't call OS_WriteEnv to update the string!
        MOVVC   r2, r12
        SWIVC   XOS_Claim
        Pull    "pc",VS

        LDR     r2, SvcTable
        LDR     r14, [r2, #4*OS_GetEnv]
        ADR     r1, MyGetEnv            ; code must live in global workspace so we can get hold of r12!
        CMP     r1, r14
        STRNE   r1, [r2, #4*OS_GetEnv]  ; only claim it if we haven't already
        STRNE   r14, MOS_GetEnv

        ADRNE   r14, MyGetEnv_Code
        ASSERT  MyGetEnv_CodeEnd-MyGetEnv_Code = 8
        ASSERT  MyGetEnv_CodeAddr = MyGetEnv+8
        LDMNEIA r14, {r1, r2}
        ADRNE   r3, MyGetEnv_ROMCode
        ADRNE   r14, MyGetEnv
        STMNEIA r14, {r1-r3}

        LDR     r2, SvcTable
        LDR     r14, [r2, #4*OS_WriteEnv]
        ADR     r1, MyWriteEnv          ; code must live in global workspace so we can get hold of r12!
        CMP     r1, r14
        STRNE   r1, [r2, #4*OS_WriteEnv]; only claim it if we haven't already
        STRNE   r14, MOS_WriteEnv

        ADRNE   r14, MyWriteEnv_Code
        ASSERT  MyWriteEnv_CodeEnd-MyWriteEnv_Code = 8
        ASSERT  MyWriteEnv_CodeAddr = MyWriteEnv+8
        LDMNEIA r14, {r1, r2}
        ADRNE   r3, MyWriteEnv_ROMCode
        ADRNE   r14, MyWriteEnv
        STMNEIA r14, {r1-r3}

        Pull    "pc"
        ]

Code_InitEntry  ROUT
        Push    "r1-r3,lr"

        Debug_Open "<Task$Debug>"

        BL      setaliases
        Pull    "r1-r3,pc",VS

        LDR     r2, [r12]               ; do we already have workspace?
        CMP     r2, #0
        MOVEQ   r0, #ModHandReason_Claim
        MOVEQ   r3, #GlobalWorkSpaceSize
        SWIEQ   XOS_Module
        STRVC   r2, [r12]
        MOVVC   r12, r2

        MOVVC   r14, #0
        STRVC   r14, FirstWord          ; no task blocks yet
        BVS     %FT90

      [ standalone
        BL      RegisterWithResourceFS
      ]

        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_Danger_SWIDispatchTable
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        CMP     r2, #0
        LDREQ   r2, =&01F033FC
        STR     r2, SvcTable

      [ NoARMv6 :LAND: SupportARMv6
        MOV     r0, #OSPlatformFeatures_ReadCodeFeatures
        SWI     XOS_PlatformFeatures
        MOVVS   r0, #0
        STR     r0, PlatFeatures
      ]

        [       DoingSwi
        BL      Claim_SWIs
        ]
    [ DebugExit
        BVS     %FT90
        LDR     r1, SvcTable
        LDR     r3, [r1, #4*OS_Exit]
        ADR     r4, exitintercept
        STR     r3, oldswiexitentry
        STR     r4, [r1, #4*OS_Exit]
      [ DebugNL
        LDR     r3, [r1, #4*OS_NewLine]
        ADR     r4, newlineintercept
        STR     r3, oldswinewlineentry
        STR     r4, [r1, #4*OS_NewLine]
      ]
    ]
90
        Pull    "r1-r3,pc"
        LTORG

MyGetEnv_Code
        SUB     r12, pc, #:INDEX:MyGetEnv+8
        LDR     pc, MyGetEnv_CodeAddr
MyGetEnv_CodeEnd

MyWriteEnv_Code
        SUB     r12, pc, #:INDEX:MyWriteEnv+8
        LDR     pc, MyWriteEnv_CodeAddr
MyWriteEnv_CodeEnd

        [       DebugExit
oldswiexitentry DCD     0
exitlink        DCD     0
oldswinewlineentry DCD     0

exitintercept
        Push    "r0-r3,lr"

        STR     r14, exitlink

        Pull    "r0-r3,lr"
        LDR     pc, oldswiexitentry
newlineintercept
        Push    "r0-r3,lr"
        SWI     OS_WriteS
        =       "OS_NewLine called", 0
        Pull    "r0-r3,lr"
        LDR     pc, oldswinewlineentry
        |
        MOV     pc, r14           ; No initialisation required
        ]
        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Code_DieEntry
;
; Must preserve r7-r11 and r13
; Only die if we have no instances of Vdu's to support
;
        Debug_Close

        LDR     r12, [r12]              ; r12 -> global workspace
        CMP     r12, #0                 ; clears V
        MOVEQ   pc, lr                  ; no workspace!

        LDR     r0, FirstWord
        CMP     r0, #0
        ADRNE   r0, ErrorBlock_TaskWindow_CantKill
        BNE     CopyError

        Push    "r1-r3,lr"

        [ DebugExit
        LDREQ   r1, oldswiexitentry
        LDREQ   r2, SvcTable
        STREQ   r1, [r2, #4*OS_Exit]
        LDREQ   r1, oldswinewlineentry
        STREQ   r1, [r2, #4*OS_NewLine]
        ]
        
      [ standalone
        BL      DeregisterWithResourceFS
      ]

        [       DoingSwi
        LDR     r2, SvcTable
        LDR     r14, [r2, #4*OS_GetEnv]
        ADR     r1, MyGetEnv                    ; in global workspace
        CMP     r1, r14                         ; so we can get wsptr
        LDREQ   r14, [r2, #4*OS_WriteEnv]
        ADREQ   r1, MyWriteEnv
        CMPEQ   r1, r14
        ADRNE   r0, ErrorBlock_TaskWindow_BadSWIEntry
        BLNE    CopyError
        LDRVC   r14, MOS_GetEnv
        STRVC   r14, [r2, #4*OS_GetEnv]
        LDRVC   r14, MOS_WriteEnv
        STRVC   r14, [r2, #4*OS_WriteEnv]

        MOVVC   r0, #WordV
        ADRVC   r1, MyWord
        MOVVC   r2, r12
        SWIVC   XOS_Release
        ]

        Pull    "r1-r3,pc"
        LTORG

        MakeInternatErrorBlock TaskWindow_CantKill,,M00
        MakeInternatErrorBlock TaskWindow_BadSWIEntry,,M01

; .............................................................................

; In    r12 -> global workspace
; Out   r0 -> environment string stored in task (if vectors claimed)
;       r1 -> memory limit
;       r2 -> 5-byte real time when command was saved
;       Exits using the BranchToSWIExit mechanism,
;       or calls the original OS_GetEnv if not claiming vectors

MyGetEnv_ROMCode
        Push    "r11, r12, lr, pc"
        SavePSR r11
        BL      FindOwner               ; r12 -> task block if found
        TEQ     r12, #0
        BLNE    gettaskenv              ; set up r0,r1,r2
        LDRNE   lr, GlobalWS
        LDRNE   lr, [lr, #:INDEX:SvcTable]
        ADDNE   lr, lr, #256*4
        LDREQ   r12, [sp, #4]
        LDREQ   lr, MOS_GetEnv          ; continue with original SWI
        RestPSR r11,,f                  ; restore flags as on entry
        STR     lr, [sp, #12]
        Pull    "r11, r12, lr, pc"      ; go to required place!
        LTORG

; In:   r12 -> task workspace
; Out:  r0 -> command string(set using OS_WriteEnv)
;       r1 -> memory limit (read using OS_ChangeEnvironment)
;       r2 -> 5-byte real time (set using OS_WriteEnv)

gettaskenv
        EntryS

        MOV     r0, #MemoryLimit
        MOV     r1, #0
        SWI     XOS_ChangeEnvironment   ; r1 -> memory limit
; ECN
; Osclibuffer is now a pointer to the buffer
        LDR     r0, OscliBuffer         ; r0 -> command in task block
        ADR     r2, OscliTime           ; r2 -> 5-byte real time

        Debug   env, "gettaskenv: r0,r1,r2 =",r0,r1,r2

        EXITS                           ; must preserve flags

; .............................................................................

; In    r12 -> global workspace
;       r0 -> environment string to be stored in task (if vectors claimed)
;       r1 -> 5-byte real time to store
;       Exits using the BranchToSWIExit mechanism,
;       or calls the original OS_WriteEnv if not claiming vectors

MyWriteEnv_ROMCode
        Push    "r11, r12, lr, pc"
        SavePSR r11
        BL      FindOwner               ; r12 -> task block if found
        TEQ     r12, #0
        BLNE    puttaskenv              ; uses r0, r1
        LDRNE   lr, GlobalWS
        LDRNE   lr, [lr, #:INDEX:SvcTable]
        ADDNE   lr, lr, #256*4          ; exit to caller
        LDREQ   r12, [sp, #4]
        LDREQ   lr, MOS_WriteEnv        ; continue with original SWI
        RestPSR r11,,f                  ; restore flags as on entry
        STR     lr, [sp, #12]
        Pull    "r11, r12, lr, pc"      ; go to required place!
        LTORG

; In    r0 -> *command
;       r1 -> start time to remember (5 bytes)
;       r12 -> task workspace
; Out   command copied to task block (if vectors claimed)

puttaskenv
        EntryS  "r0-r3"

        Debug   env, "puttaskenv: r0,r1 =",r0,r1

        MOV     r3, #5
        ADR     r2, OscliTime
01      LDRB    r14, [r1], #1
        STRB    r14, [r2], #1
        CheckPointers
        SUBS    r3, r3, #1
        BNE     %b01

; ECN
; Now handle command lines > 256. First free any previous command line for
; this task.
        MOV     r1, r0
        LDR     r2, OscliBuffer
        CMP     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
; Find the command line length
        MOV     r0, r1
03      LDRB    r14, [r0], #1
        CMP     r14, #' '
        BCS     %b03
        SUB     r3, r0, r1
; & allocate a buffer of the appropriate size
; Possibly this should be rounded up to the nearest 64 bytes
        MOV     r0, #ModHandReason_Claim
        SWI     OS_Module
        STR     r2, OscliBuffer

02      LDRB    r14, [r1], #1
        CMP     r14, #32
        MOVLO   r14, #0                 ; the copy must be 0-terminated!
        STRB    r14, [r2], #1
;        CheckPointers
        BHS     %b02

        EXITS                           ; must preserve flags

; .............................................................................

; In    r0 = OS_Word reason code
;       r1 -> OS_Word parameters
; Out   if r0=14, [r1]=3 (Read real time), and r1 -> MOS EnvTime,
;          the MOS EnvString and EnvTime buffers are copied to task space
;       We assume that if anyone updates the time manually like this,
;       they have also updated the environment string themselves

MyWord
        TEQ     r0, #14
        MOVNE   pc, lr                  ; pass it on

        Push    "r0-r2, r12, lr"

        LDRB    r14, [r1]               ; check for sub reason code 3
        TEQ     r14, #3
        LDREQ   r14, MOS_EnvTime        ; is this FileSwitch reading the time?
        TEQEQ   r1, r14
        Pull    "r0-r2, r12, pc",NE

        BL      FindOwner               ; are we on the vector?
        TEQ     r12, #0
        Pull    "r0-r2, r12, pc",EQ

        JumpAddress r2,%f20,Forward
        Push    "r2,r12"
        LDR     pc, [sp, #6*4]          ; pass on to rest of vector owners
20
        Pull    "r12"                   ; don't trust them - get my CPSR[m0:m4] and r12 back!
        LDR     r0, GlobalWS
        LDR     r0, [r0, #:INDEX:MOS_EnvString]         ; r0 -> MOS environment string
        BL      puttaskenv                              ; r12 -> task workspace (preserves all flags)

        TEQ     PC,PC
        Pull    "r0-r2, r12, lr, pc",NE,^  ; 26-bit mode exit to caller
        Pull    "r0-r2, r12, lr, pc"       ; 32-bit mode exit to caller

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ServiceTable
        ASSERT  Service_Memory < Service_Reset
        ASSERT  Service_Reset < Service_WimpCloseDown
        ASSERT  Service_WimpCloseDown < Service_WimpReportError
        ASSERT  Service_WimpReportError < Service_ResourceFSStarting   
        DCD     0                                    ; flags
        DCD     Code_UServiceEntry - Module_BaseAddr
        DCD     Service_Memory
  [ DoingSwi
        DCD     Service_Reset
  ]
        DCD     Service_WimpCloseDown
        DCD     Service_WimpReportError
      [ standalone
        DCD     Service_ResourceFSStarting
      ]
        DCD     0                                    ; terminator
        DCD     ServiceTable - Module_BaseAddr       ; table anchor
;
Code_ServiceEntry ROUT
        MOV     r0, r0                               ; magic intruction
        TEQ     r1, #Service_Memory
  [ DoingSwi
        TEQNE   r1, #Service_Reset
  ]
        TEQNE   r1, #Service_WimpCloseDown
        TEQNE   r1, #Service_WimpReportError
      [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
      ]
        MOVNE   PC, LR
;
Code_UServiceEntry
;
; Entry:- r1  = service number
;         r2  = CAO if r1 = &11 (Memory)
;             = task handle if r1 = Service_WimpCloseDown and r0 > 0
;         r12 = private word pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  All registers preserved unless
;         r1  = 11 and we're active and CAO = us, in which case r1 = 0
;
        LDR     r12, [r12]              ; r12 -> global workspace
        TEQ     r12, #0
        MOVEQ   pc, lr                  ; give up if no workspace!

        TEQ     r1, #Service_WimpCloseDown
        BEQ     %f10
        TEQ     r1, #Service_WimpReportError
        BEQ     %f20
      [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BEQ     %f60
      ]
        [       DoingSwi
        TEQ     r1, #Service_Reset
        BEQ     svc_reset
        ]
;else fall through to handle Service_Memory
        LDR     r1, FirstWord
        TEQ     r1, #0            ; Are we active?
        MOVEQ   r1, #Service_Memory
        MOVEQ   pc, r14           ; Return if not

        TEQ     pc, pc
        MOVNE   r1, #-64*&100000
        MOVEQ   r1, #1:SHL:31
        CMP     r0, r1                  ; check for Wimp's magic value
        ADREQL  r1, Module_BaseAddr     ; we don't require memory otherwise
        SUBEQS  r1, r2, r1              ; Is it us?  R1=0 if so
        MOVNE   r1, #Service_Memory
        MOV     pc, r14           ; Return if not
10
        TEQ     r0, #0
        MOVEQ   pc, r14           ; Normal closedown and return

        Push    "lr"              ; r2 = handle of task being affected
        LDR     r12, FirstWord
11      TEQ     r12, #0
        Pull    "pc", EQ          ; exit if no task has this ID
        LDR     r14, ChildTask
        CMP     r2, r14
        LDRNE   r12, NextBlock
        BNE     %b11
        ADR     r0, ErrorBlock_WimpCantKill  ; no need to set V bit
        BL      CopyError
        Pull    "pc"

20
        Push    "r0, lr"
        TEQ     r0, #0            ; Is it close?
        BEQ     %f40              ; Branch if so
;
; Now check if we have an active window
;
        BL      FindOwner
        TEQ     r12, #0
        BEQ     %f30              ; No owner anyway
        MOV     r0, #2            ; Suspend claimant
25
        STR     r0, PassOnVectors ; temporarily
30
        Pull    "r0,pc"           ; Return - service calls can corrupt flags
40
;
; See if someone was suspended
;
        LDR     r12, FirstWord    ; Point to a workspace
50
        TEQ     r12, #0
        BEQ     %b30              ; Return if nobody had em
        LDR     r0, PassOnVectors
        TEQ     r0, #2
        MOV     r0, #0
        BEQ     %b25              ; Return if this man had em
        LDR     r12, NextBlock    ; Else try the next block
        B       %b50              ; Loop

        MakeInternatErrorBlock WimpCantKill,,M07

      [ standalone
60
; ResourceFS has been reloaded - redeclare resource files
; In    R2 -> address to call
;       R3 -> workspace for ResourceFS module
        Push    "r0, lr"
        ADR     r0, resourcefsfiles
        MOV     lr, pc                  ; LR -> return address
        MOV     pc, r2                  ; R2 -> address to call
        B       %FT65

DeregisterWithResourceFS
        Push    "r0, lr"
        ADRL    r0, resourcefsfiles
        SWI     XResourceFS_DeregisterFiles ; ignore errors
        B       %FT65

RegisterWithResourceFS
        Push    "r0, lr"
        ADR     r0, resourcefsfiles
        SWI     XResourceFS_RegisterFiles   ; ignore errors
65
        Pull    "r0, lr"
        RETURN

resourcefsfiles
        ResourceFile    $MergedMsgs, Resources.TaskWindow.Messages
        DCD     0
      ]
      
; *************************************************************************
;
; *ShellCLI_Task XXXXXXXX XXXXXXXX
; Connects a text buffer to a task (may or may not be already running)
;
; *Taskwindow <command> [<options>]
; Starts up a new task, perhaps without a task window
;
; Both commands simply enter the module and let it deal with it.
;

ShellCLI_Task_Code ROUT
TaskWindow_Code  ROUT
;
; Entry:- r0 -> command tail
;         r12 = private word pointer
;
        Push    "lr"

        MOV     r2, r0
        MOV     r0, #ModHandReason_Enter
        ADRL    r1, Code_TitleString
        SWI     XOS_Module        ; Shouldn't return

        Pull    "pc"              ; pass back to caller anyway

; .........................................................................

ShellCLI_TaskQuit_Code ROUT
;
; Request to close down current incarnation
;
; Entry:- r12 = private word pointer
;
        Push    "lr"
        LDR     r12, [r12]        ; r12 -> global workspace
        BL      FindOwner         ; See who this task is
        CMP     r12, #0           ; clears V
        MOVNE   r0, #1
        STRNE   r0, ReqDie        ; Don't set moribund flag directly
                                  ; we need SendOutput to be called
        Pull    "pc"

; .........................................................................

FindWaiting     ROUT
;
; Find which instance is waiting for a text buffer
;
; Entry:- r12 -> global workspace
;
; Exit:-  r12 = correct workspace pointer for vector claimant
;             = 0 if none found
;         All other registers and flags preserved
;
        Push    "r0,lr"

        LDR     r12, FirstWord    ; Point to a workspace

10      CMP     r12, #0
        Pull    "r0,pc",EQ        ; Return if nobody got em
        LDR     r0, ParentTxt
        CMP     r0, #1
        LDRNE   r12, NextBlock    ; Else try the next block
        BNE     %b10              ; Loop

        CMP     r12, #0           ; NE => block found
        Pull    "r0,pc"

; **************************************************************************

Code_WimpStartError ROUT
;
; Entry:-  r0 -> error block
;         r12 -> task workspace
;
; Exit:-  None
;
        [       FixReportName
        LDR     r2, key_name
        |
        LDR     r2, MyParameters  ; Point to star command we used
        CMP     r2, #0            ; use "Task Window" if unset
        ADREQ   r2, taskwindowname
        ]
        MOV     r1, #6            ; Provide Cancel, not OK, and highlight
        SWI     XWimp_ReportError ; Say what happened
        BL      Unlink            ; Get rid of memory
        SWI     XWimp_CloseDown   ; No more wimp
        SWI     OS_Exit           ; Dead

taskwindowname
        DCB     "Task Window"
        DCB     0
        ALIGN

; .........................................................................

Code_StartError ROUT
;
; Error in startup sequence
; Entry:-  r0 -> error block
;         r12 -> task workspace
; Exit:-  None
;
        Push    r0
        BL      Unlink            ; Free our memory
        Pull    r0                ; Preserve error pointer
        SWI     OS_GenerateError  ; And out we go

; .........................................................................


Unlink  ROUT
;
; Remove the current instantiation from the linked memory list
;
; Entry:- r12 -> task workspace
;
; Exit:-  r0, r2 - r7 corrupt (NB: we don't have a stack!)
;
        MOV     r3, r14
        MOV     r2, r12           ; Remember r12
        LDR     r6, NextBlock     ; Get next pointer for current block
        LDR     r12, GlobalWS     ; r12 -> global workspace
        MOV     r5, r12
        LDR     r4, FirstWord     ; Point to first block
10
        TEQ     r2, r4            ; See if this block
        MOVNE   r12, r4
        LDRNE   r4, NextBlock
        BNE     %b10              ; Loop until pointing to correct block
;
; r2 points to block to be removed
; r12 points to previous block
; r5 points to private word
; r6 points to next block
;
        TEQ     r12, r5           ; See if removing head of chain
        STRNE   r6, NextBlock
        STREQ   r6, [r5]          ; Update private word
; ECN
; Free any command line buffer in use
        LDR     r4, [r2, #OscliBuffer - NextBlock]
        MOV     r0, #ModHandReason_Free
        SWI     OS_Module         ; Free it
        MOV     r2, r4
        CMP     r2, #0
        SWINE   OS_Module
        MOV     pc, r3

; .........................................................................

Code_ErrorHandler ROUT
;
; Handle application errors which it has failed to trap
; If we have vectors, and a parent task, then just print them
; otherwise pass back to wimp
; Then close down
;
;
; Entry:- r0 = my r12 value as passed to OS_ChangeEnvironment
;         No other conditions
;
; Exit:-  None!
;
        MOV     r12, r0           ; My workspace pointer
;
; First kill my error handler to avoid reentering
;
        LDRB    r0, TaskAborted   ; See if reentering
        TEQ     r0, #0
        BEQ     %f01
; ******************************debugging here
        LDR     r0, PassOnVectors
        TEQ     r0, #1
        MOVEQ   r0, #"A"
        STR     r0, PassOnVectors
        SWI     OS_Exit
        SWINE   OS_Exit           ; Leave if so
01
        MOV     r0, #"E"          ; We've had an error now
        STRB    r0, TaskAborted   ; Protect following section

        CheckIn

        MOV     r0, #ErrorHandler ; Getting rid of old handler
        ADR     r1, OldErrorHandler
        LDMIA   r1, {r1 - r3}     ; Previous values
        SWI     OS_ChangeEnvironment

        LDR     r1, PassOnVectors
        TEQ     r1, #0
        BNE     %f10              ; Branch if not my vectors

        LDR     r1, Moribund
        TEQ     r1, #0
        BNE     %f20              ; don't report error if due to task dying

        LDR     r1, ParentTask
        TEQ     r1, #0
        BEQ     %f10              ; Branch if no text window
;
; Report the error ourselves
;
        ADR     r0, ErrorBuffer+8 ; Point to error string
        SWI     OS_Write0         ; Print it
        SWI     OS_WriteS
        =       13, 10, 0
        ALIGN
        B       %f20              ; And finish
10
;
; Get the wimp to report for us
;
        ADR     r0, ErrorBuffer+4 ; Point to error number
        MOV     r1, #6            ; Provide Cancel, not OK, and highlight
        [       FixReportName
        LDR     r2, key_name
        |
        LDR     r2, MyParameters  ; Point to star command we used
        CMP     r2, #0
        ADREQL  r2, taskwindowname
        ]
        SWI     Wimp_ReportError  ; Say what happened
20
        MOV     r1, #0
        STRB    r1, TaskAborted   ; Ok, we're not worried about errors now.
        LDR     r0, PassOnVectors
        TEQ     r0, #1
; ******************************debugging here
        MOVEQ   r0, #"B"
        STR     r0, PassOnVectors

        CheckOut

        SWI     OS_Exit           ; Should come back to my exit handler
        [       FPErrorHandling

; .........................................................................

Code_FPErrorHandler ROUT
;
; Handle errors occurring during Wimp_Poll
; This should be just FP asynchronous errors
;
; Entry:- r0 -> task workspace (my r12 value as passed to OS_ChangeEnvironment)
;         User mode
;         No other conditions
;
; Exit:-  None!
;
        MOV     r12, r0           ; Workspace pointer
;
; Restore his handler
;
        MOV     r0, #ErrorHandler
        ADR     r1, PreErrorHandler
        LDMIA   r1, {r1-r3}
        SWI     OS_ChangeEnvironment ; Restore previous handler
;
; Now set ourselves up in an ok fashion
;
        ADR     r13, MyVecStack+MyStackSize ; Just in case we need a stack
;
; Note this leaves the top sixteen words untouched, we want some of them back
;
        BL      ReadWimpKeyStates ; In case they've changed
        BL      SetTaskKeyStates  ; Then put back task's versions
        BL      RestoreEscape
;
; Now restore the old SVC stack
;
        SWI     OS_EnterOS        ; Acquire SVC mode
        LDR     r10, SVCStackLimit
        BL      RestoreSVCStack   ; Put back the old SVC stack in case needed.
        ADR     r1, ErrorRegs +10*4
        LDMIA   r1, {r3-r5}       ; His r10-r12
        LDR     r2, CallBackRegs+15*4 ; User pc
        STMFD   r13!, {r2-r5}     ; Stack with his pc, r10-r12 a la SVC
;
; Note if we were called from a swi, the real values will be
; higher up the stack, and the fact that these are wrong won't be important.
;
        WritePSRc USR_mode,r1     ; User mode, interrupts on
        MOV     r1, #0            ; Intercepting again
        STR     r1, PassOnVectors
        [       UseInCallBack
        STRB    r1, InCallBack    ; No longer in call back
        ]
        ADR     r0, ErrorBuffer
        ADR     r13, ErrorRegs    ; The old register set
        LDMIB   r13, {r1-r14}     ; His values back
        SWI     OS_WriteS
        =       "+", 0
        SWI     OS_GenerateError  ; Give it to the real handler
        ]

; *******************************************************************************************
;
; Start up a new task domain, with or without an Edit buffer
;

KeyDef          DCB     ",wimpslot,name,display/K/S,quit/K/S,ctrl/K/S,task/K/E,txt/K/E,nice", 0
wimpslotcommand DCB     "WimpSlot ", 0
titlestringspace  DCB   "TaskWindow ", 0
                ALIGN

Code_StartEntry ROUT
;
; Called by Run or Enter (*ShellCLI_Task or *TaskWindow)
;
; Entry:- r12 = private word pointer
;         Parameters from GetEnv
;
        LDR     r12, [r12]        ; r12 -> global workspace

        LDR     r7, FirstWord     ; Get ws pointer
        MOV     r6, r12           ; Remember where global workspace is in case of error
        SWI     OS_EnterOS        ; Want OS r13
;
; find out if we're running in a task window already - if so, start a new task
;
        BL      FindOwner
        TEQ     r12, #0
        MOVEQ   r12, r6                 ; recover original r12 (-> global ws)
        BEQ     nowimpstarttask

        CheckIn

        MOV     r14, #1
        STR     r14, PassOnVectors      ; don't want a callback request here!

        ADR     r2, WimpTaskBuffer
        ADR     r1, titlestringspace
        BL      copy_r1r2
        MOV     r1, r0
        BL      copy_r1r2

        BL      SaveEscape        ; Do this while in SVC mode
                                  ; since it calls a user handler
        WritePSRc USR_mode,r14    ; must be user mode here
;
; Now in user mode, so r13 and r14 are new
;
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"                 ; save user regs
;
; This is unnecessarily paranoid - all that is required is: Push    "r1, r2, r14"
;
        BL      checkcallback           ; See if a callback is waiting to happen
        SWI     OS_ReadMonotonicTime    ; allow callback to occur!
;
; set state up as Wimp likes it
;
        BL      ReadExecHandle
        BEQ     %f05              ; No OS handle
        Push    r1                ; Save OS handle
        BL      CloseMyExec
        Pull    r1
        STRB    r1, ExecHandle    ; Got new handle
        CheckPointers
05
        BL      ReadSpoolHandle
        STRB    r1, SpoolHandle   ; Save OS handle
        CheckPointers

        BL      ReadTaskKeyStates ; First get what task thinks they are
        BL      SetWimpKeyStates  ; Then put back wimp's versions

        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_ChangeRedirection
        STRB    r0, CopyOfRedirectInHandle
        STRB    r1, CopyOfRedirectOutHandle
        CheckPointers
;
; send output, cos we may not be active for a while
;
        BL      SendOutput
;
; call Wimp_Poll till we get a null event, in the interests of multi-taskingness
;
06      MOV     r0, #0                  ; we want null events
        MOV     r2, #0                  ; no delay
        MOV     r3, #0                  ; no poll word
        BL      PollWimpFn              ; deals with messages if necessary
        BVS     %f07
        LDR     r14, Moribund
        CMP     r14, #0
        BNE     %f07                    ; exit so we can die!
        LDR     r0, PollWimpResult
        CMP     r0, #0
        BNE     %b06                    ; wait for a null event
;
; call Wimp_StartTask!
;
        [       DebugStart
        SWI     OS_WriteI+4
        SWI     OS_WriteS
        DCB     "Wimp_StartTask: ",0
        ALIGN
        ADR     r0, WimpTaskBuffer      ; r0 -> "TaskWindow <parameters>"
        SWI     OS_Write0
        SWI     OS_NewLine
        SWI     OS_ReadC                ; not on vectors here!!
        ]
        ADR     r0, WimpTaskBuffer      ; r0 -> "TaskWindow <parameters>"
        SWI     XWimp_StartTask
07
;
; restore state after calling Wimp
;
        SavePSR lr
        Push    "r0,r1,lr"        ; save psr state

        LDRB    r0, CopyOfRedirectInHandle
        LDRB    r1, CopyOfRedirectOutHandle
        SWI     XOS_ChangeRedirection
        BL      ReadWimpKeyStates ; In case they've changed
        BL      SetTaskKeyStates  ; Then put back task's versions

        LDRB    r1, SpoolHandle   ; Restore OS handle
        BL      WriteSpoolHandle

        Pull    "r0,r1,lr"
        RestPSR lr,,f

        Pull    "$Regs"                 ; restore user regs

        BL      RestoreEscape
        MOV     r1, #0                  ; Intercepting again
        STR     r1, PassOnVectors

        CheckOut

        SWIVS   OS_GenerateError
        SWI     OS_Exit                 ; the only way out!
;
; scan parameters first, in case we're not really starting a new task
; In:   r0 -> parameter list
;
nowimpstarttask ROUT

        [       DebugStart
        Push    "r0"
        SWI     OS_WriteI+4
        SWI     OS_WriteS
        DCB     "NewTask: ",0
        ALIGN
        SWI     OS_Write0
        SWI     OS_NewLine
        SWI     OS_ReadC               ; not on vectors here!!
        Pull    "r0"
        ]
;
; r0 now points to command string starting with my module name
; r1 = top address of my application (probably irrelevant)
; r2 = time, also irrelevant
;
        MOV     r11, r0                 ; r11 = MyParameters for now
        BL      readparenthandles       ; r1,r2 = parent task/txt handles
        MOVVS   r1, #0
        MOVVS   r2, #0
        BVS     %f10                    ; syntax error => assume other one
;
; see if this was actually meant for another task
;
        Push    "r12"           ; save our R12
        BL      FindWaiting     ; see if a task is waiting for a text buffer
        STRNE   r1, ParentTask  ; fill it in if so
        STRNE   r2, ParentTxt
        Pull    "r12"
        SWINE   OS_Exit         ; we've done our job
;
; OK, it's us - save ParentTask/Txt till we get a task block
;
        MOV     r11, #0
10
        MOV     r9, r1          ; r9-r11 = parameters
        MOV     r10,r2

;
; work out max size of SVC stack, so we can claim a block big enough
;
        MOV     r4, r13, LSL #12  ; R13 is pointer to top of stack (flat on entry)
        MOV     r5, r13
        WritePSRc USR_mode, r3    ; Back to user mode
        MOV     r4, r4, LSR #12   ; Effectively (R13 & 0x000FFFFF)
        LDR     r3, =HeapSize
        ADD     r3, r3, r4        ; Request that much
        MOV     r0, #ModHandReason_Claim
        SWI     OS_Module         ; Let the error happen
;
; Initialise our area before linking in
;
        MOV     r12, r2                         ; Now point to our memory
        ADR     r13, CommandStack+MyStackSize   ; Set up my own stack

        STR     r4, MySVCStackSize
        STR     r5, SVCStackBase
        STR     r6, GlobalWS      ; Save private word pointer

        STR     r9, ParentTask
        STR     r10, ParentTxt
        STR     r11, MyParameters

        MOV     r8, #0
        [       UseGotCallBack
        STRB    r8, GotCallBack   ; No call back handler installed yet
        ]
; ECN
; 0 command line ptr so puttaskenv does not try to free it
        STR     r8, OscliBuffer
        STR     r8, ReqDie        ; Not asked for die
        STR     r8, PollWord      ; not waiting on a Poll Word
        STR     r8, key_quit      ; normal taskwindows have no quit
        STR     r8, key_ctrl      ; and no control keys passed through
        STR     r8, key_wimpslot  ; defaults if no OS_ReadArgs used
        STRB    r8, key_fnflag
        STR     r0, PassOnVectors ; Don't want vectors here
        [ DebugExit
        STR     r8, InPollWimpFn
        ]
        [       FixDomain
        Push    "r1-r2"
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_DomainId
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        CMP     r2, #0
        LDREQ   r2, =Legacy_DomainId
        STR     r2, WimpDomain
        LDR     r0, [r2]
        Pull    "r1-r2"
        STR     r0, MyDomain
        ]
        [ NiceNess
        STR     r8, key_nice
        MOV     r8, #EventCount
        STR     r8, Nice
        ]
;
; Now copy in the vector claim state if not first incarnation
; or zero it if first incarnation
;
        ADRL    r0, GotVectors
        SUB     r1, r0, r12       ; The index
        ADD     r1, r1, r7        ; ADRL
        MOV     r9, #NumVectors
15
        TEQ     r7, #0
        LDRNE   r8, [r1], #4      ; Get old state
        STRNE   r8, [r0], #4      ; Save
        STREQ   r7, [r0], #4      ; Else clear
        SUBS    r9, r9, #1        ; Count
        BNE     %b15
;
; Now link in to the chain
;
        STR     r7, NextBlock     ; Chain in at the front
        STR     r2, [r6]          ; Private word says where memory is
;
; Having initialised the rest, try out OS_ChangeRedirection
;
        MOV     R0,#-1
        MOV     R1,#-1
        SWI     XOS_ChangeRedirection
        BVS     Code_StartError
;
; decode options now, as one of them is the task name
;
        LDR     r14, ParentTask
        CMP     r14, #0
        BNE     %f20

; *TaskWindow <command> [<options>]

        [       DebugStart
        SWI     OS_WriteI+4
        SWI     OS_WriteS
        DCB     "ReadArgs: ",0
        ALIGN
        LDR     r0, MyParameters
        SWI     OS_Write0
        SWI     OS_NewLine
        SWI     OS_ReadC
        ]

        ADR     r0, KeyDef
        LDR     r1, MyParameters        ; r1 -> command options
        ADR     r2, ParameterBuffer
        MOV     r3, #?ParameterBuffer
        SWI     XOS_ReadArgs
        BVS     Code_StartError         ; haven't called Wimp_Initialise yet

        LDR     r0, key_command
        STR     r0, MyParameters

        LDR     r0, key_task
        BL      readeval                ; r0 = value, EQ => not present
        STRNE   r0, ParentTask

        LDR     r0, key_txt
        BL      readeval                ; r0 = value, EQ => not present
        STRNE   r0, ParentTxt

        LDR     r1, key_name
        CMP     r1, #0
        BNE     %f21
20
        ADRL    r1, Code_TitleString    ; "TaskWindow" for boring tasks
        STR     r1, key_name
21
        [ NiceNess
        MOV     r0, #10
        LDR     r1, key_nice
        CMP     r1, #0
        BEQ     %FT22
        SWI     XOS_ReadUnsigned
        STRVC   r2, Nice
22
        ]
;
; Now initialise the wimp
;
        MOV     r0, #WimpVersion
        LDR     r1, Task
        LDR     r2, key_name
        ADRL    r3, MessagesList
        SWI     XWimp_Initialise  ; Non error form
        BVS     Code_StartError   ; Die if error
        STR     r1, ChildTask     ; Not sure if we need this or not

; If there's a parent task, send the Ego message

        MOV     r0, #-1
        MOV     r1, #-1
        SWI     XWimp_SlotSize
        CMP     r2, #96 * 1024
        RSBCC   r2, r2, #96 * 1024
        SUBCC   r0, r0, r2
        SWICC   XWimp_SlotSize

        LDR     r14, ParentTask
        CMP     r14, #0
        BLNE    SendEgoMessage          ; Send message to task that started us
        BVS     Code_WimpStartError

; if no parent task, set the wimpslot
; do this after Wimp_Init, so we don't appear as a module task

        ADRL    r1, wimpslotcommand
        ADR     r2, ReadLineBuffer      ; definitely not using this any more
        BL      copy_r1r2
        LDR     r1, key_wimpslot
        CMP     r1, #0
        BEQ     %f33                    ; don't touch it if not specified
        BL      copy_r1r2
        MOV     r14, #" "
        STRB    r14, [r2], #1
        BL      copy_r1r2               ; repeat the argument (-max)
        ADR     r0, ReadLineBuffer
        SWI     XOS_CLI
        BVS     Code_WimpStartError
33

; initialise the task, ready for action!

inittask        ROUT
        MOV     r1, #0
        STRB    r1, ExecHandle    ; No exec file yet
        [ CheckBufferPointers
        STR     r1, Debug_Word
        ]
        [       FixSpool
        STRB    r1, SpoolHandle   ; No spool file yet
        ]
        ADRL    r0, KeyBuffer
        STR     r0, KeyBufferFirst
        ADD     r0, r0, #?KeyBuffer
        STR     r0, KeyBufferLast
        BL      Clear
        MOV     r0, #0
        STR     r0, ExpPointer    ; No expansions yet
        STR     r0, ReceivedBytes ; No bytes received by RAMTransmit
        STR     r0, ReceivePending ; Nothing waiting yet
        ADRL    r0, OBuffer
        STR     r0, OBufferFirst
        ADD     r0, r0, #?OBuffer
        STR     r0, OBufferLast
        MOV     r1, #1
        BL      Clear
        BL      ReadWimpKeyStates ; Read the function key states for the wimp
        LDR     r1, =&F0E0D001
        STR     r1, TaskFnKeyStates
        LDR     r1, =&A0908001
        STR     r1, TaskFnKeyStates+4 ;Defaults for task window
        BL      SetTaskKeyStates  ; Set them here
;
; Now set up exit and error handlers
;
        MOV     r0, #ExitHandler
        ADR     r1, Code_ExitHandler
        MOV     r2, r12
        SWI     OS_ChangeEnvironment
        ADR     r0, OldExitHandler
        STMIA   r0, {r1-r3}
        MOV     r0, #ErrorHandler
        addr    r1, Code_ErrorHandler
        MOV     r2, r12
        ADR     r3, ErrorBuffer
        SWI     OS_ChangeEnvironment ; Dunno what we do with an error
        ADR     r0, OldErrorHandler
        STMIA   r0, {r1-r3}
        MOV     r0, #0
        STRB    r0, TaskEscape    ; Remember escape state of caller
        [       UseInCallBack
        STRB    r0, InCallBack
        ]
        STRB    r0, TaskAborted   ; Didn't abort
;
; Now intercept the vectors
;
        LDR     r0, NextBlock   ; See if this is first incarnation
        TEQ     r0, #0
        BNE     %f60

        MOV     r0, #WrchV
        ADRL    r1, MyWrchV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim WrchV. What about errors?
        MOV     r0, #1
        STR     r0, GotWrchV

        MOV     r0, #UpCallV
        ADRL    r1, MyUpCallV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim UpCallV. What about errors?
        MOV     r0, #1
        STR     r0, GotUpCallV

        MOV     r0, #RdchV
        ADRL    r1, MyRdchV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim RdchV. What about errors?
        MOV     r0, #1
        STR     r0, GotRdchV

        MOV     r0, #ByteV
        ADRL    r1, MyByteV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim ByteV. What about errors?
        MOV     r0, #1
        STR     r0, GotByteV
        [       UseTickerV
        MOV     r0, #TickerV
        |
        MOV     r0, #EventV
        ]

        ADRL    r1, MyEventV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim EventV. What about errors?
        MOV     r0, #1
        STR     r0, GotEventV

        MOV     r0, #CNPV
        ADRL    r1, MyCnpV
        LDR     r2, GlobalWS    ; Enter with r12 -> global workspace
        SWI     OS_Claim        ; Claim CnpV. What about errors?
        MOV     r0, #1
        STR     r0, GotCnpV
60
        MOV     r0, #0
        STR     r0, VSyncCount
        STR     r0, OutputCount
        STR     r0, PassOnVectors ; Got em
        STR     r0, Moribund      ; Not dying yet
        STR     r0, Suspended     ; Nor are we suspended
        [       FixControl
        STRB    r0, controlcounter
        ]
;
; Now sort out exec file on entry
;
        BL      ReadExecHandle
        STRB    r1, ExecHandle
        CheckPointers
;
; Now we should start up the application proper
;
        MOV     r0, #EscapeChar   ; Now enable Escape Key
        MOV     r1, #0
        STRB    r1, EscapeDisable
        [       RealEscape
        MOV     r2, #0            ; Overwrite on task allowed escape generation
        |
        MOV     r2, #&FF          ; Otherwise just read it
        ]
        SWI     OS_Byte
        STRB    r1, TaskEscape    ; Remember escape state of caller
        CheckPointers
        [       Preempt
        [       UseTickerV
        |
        LDR     r0, NextBlock
        TEQ     r0, #0
        MOVEQ   r0, #EventEnable
        MOVEQ   r1, #Event_VSync
        SWIEQ   OS_Byte           ; Enable VSync event
        ]
        ]
;
; If -display was specified, obtain a parent task before proceeding
;
        LDR     r14, key_display
        CMP     r14, #0
        BLNE    GetParentTask     ; no effect if there's already a parent
        SWIVS   OS_GenerateError

        B       Code_NewCommand

        MakeInternatErrorBlock BadParameters,,M08

;
; Entry:- r0 -> command to be executed
;

Code_CommandLoop  ROUT
        STR     r0, MyParameters
        SWI     OS_CLI            ; No return unless system command
        SWI     OS_Exit

Task    =       "TASK"

defhtable
        DCB    UndefinedHandler
        DCB    PrefetchAbortHandler
        DCB    DataAbortHandler
        DCB    AddressExceptionHandler
        DCB    OtherExceptionHandler
        DCB    CallBackHandler
        DCB    BreakPointHandler
        DCB    EscapeHandler
        DCB    EventHandler
        DCB    UnusedSWIHandler
        DCB    ExceptionDumpArea
enddefh
        ALIGN
        LTORG

; *************************************************************************

readparenthandles  ROUT
;
; Entry:- r0 -> parameters (two 8 byte hex numbers)
;
; Exit:-  r1 = parent task handle
;         r2 = parent text buffer handle
;         "Bad parameters" error if incorrect syntax
;
        Push    "r1-r2,lr"

10      LDRB    r14, [r0], #1
        CMP     r14, #" "
        BEQ     %b10
        SUB     r0, r0, #1        ; r0 -> first non-space

        MOV     r1, #0            ; Value
        MOV     r2, #8            ; Count
40
        BL      GetHex
        Pull    "r1-r2, pc",VS
        ADD     r1, r3, r1, LSL #4; Shift and add
        SUBS    r2, r2, #1
        BNE     %b40              ; Loop until read
        STR     r1, [sp, #0]      ; return in R1
        BL      CheckSpaces       ; Check syntax
        Pull    "r1-r2, pc",VS
;
; We should now have an eight byte hex number representing the
; parent task txt.
;
        MOV     r1, #0            ; Value
        MOV     r2, #8            ; Count
50
        BL      GetHex
        Pull    "r1-r2, pc",VS
        ADD     r1, r3, r1, LSL #4; Shift and add
        SUBS    r2, r2, #1
        BNE     %b50              ; Loop until read
        STR     r1, [sp, #4]      ; return in R2
        BL      CheckSpaces       ; Check syntax (error if wrong)

        Pull    "r1-r2, pc"

; ........................................................................

; In    r0 -> string
; Out   r1 = next non-space character
;       VC => r0 -> first non-space character
;       VS => r0 -> error "Bad parameters" - if first char wasn't space

CheckSpaces ROUT
        LDRB    r1, [r0], #1
        TEQ     r1, #" "
        ADRNEL  r0, ErrorBlock_BadParameters
        BNE     CopyError

10      LDRB    r1, [r0], #1
        CMP     r1, #" "          ; clears V
        BEQ     %b10              ; Loop ignoring spaces
        SUB     r0, r0, #1        ; Pointer to first non-space
        MOV     pc, lr

; ........................................................................

; In    r0 -> string
; Out   r3 = hex digit value (0..15)
;       VC => r0 updated
;       VS => error "Bad task or text handle"

GetHex  ROUT
        LDRB    r3, [r0], #1      ; The character
        CMP     r3, #"0"
        BCC     %f10              ; Branch on range error
        CMP     r3, #"9"          ; Clears V
        SUBLS   r3, r3, #"0"      ; Convert to numeric
        MOVLS   pc, r14           ; Return V clear
;
; Try alphabetic
;
        BIC     r3, r3, #"a"-"A"  ; Clear the lower case bit
        CMP     r3, #"A"
        BCC     %f10              ; Branch on range error
        CMP     r3, #"F"          ; Clears V
        SUBLS   r3, r3, #"A"-10   ; Convert to value
        MOVLS   pc, lr            ; Return V clear
10
        ADR     r0, ErrorBlock_TaskWindow_BadTaskHandle
        B       CopyError

        MakeInternatErrorBlock TaskWindow_BadTaskHandle,,M02

; ..............................................................................

; In    r0 -> 1-byte type followed by 4-byte value, else
; Out   EQ => no value present, NE => r0 = value

readeval        ROUT

        Push    "r1-r4,lr"

        CMP     r0, #0

        LDRNEB  r1, [r0, #1]
        LDRNEB  r2, [r0, #2]
        LDRNEB  r3, [r0, #3]
        LDRNEB  r4, [r0, #4]
        ADDNE   r0, r1, r2, LSL #8
        ADDNE   r0, r0, r3, LSL #16
        ADDNE   r0, r0, r4, LSL #24

        Pull    "r1-r4,pc"

; ..............................................................................

; In    r1 -> source string
;       r2 -> destination buffer
; Out   string copied (up to control character)
;       r2 -> terminator in buffer

copy_r1r2       ROUT

        Push    "r1,lr"

21      LDRB    r14, [r1], #1
        STRB    r14, [r2], #1
        CMP     r14, #32
        BHS     %b21

        SUB     r2, r2, #1

        Pull    "r1,pc"

; ..............................................................................

SendEgoMessage  ROUT
;
; Entry:- r12 -> task block
;         ParentTask = task handle of parent
;         ParentTxt = text buffer handle of parent
;
; Exit:-  message sent to parent, with our task handle in it
;
; Note:   When connecting to a different child, *ShellCLI_Task must get that
;         child to send a message back to !Edit, by sending a message to it.
;
        Push    "r1-r8, lr"

        MOV     r3, #24           ; Size of block
        MOV     r6, #0            ; No ref
        LDR     r7, =Ego          ; I am code
        LDR     r8, ParentTxt     ; Parent's txt object
        MOV     r0, #User_Message ; Not Acked at present, will be later
        ADR     r1, MessageBlock
        STMIA   r1, {r3-r8}       ; Set up the message block
        LDR     r2, ParentTask    ; Who to
        SWI     XWimp_SendMessage ; Send

        Pull    "r1-r8, pc"

; ..............................................................................

GetParentTask   ROUT
;
; Entry:- r12 -> task workspace
;         ParentTask = task handle of parent: if 0, we haven't got one
;
; Exit:-  ParentTask = task handle of parent
;         errors may be returned
;
        Push    "r1-r3,lr"

        LDR     r0, ParentTask
        CMP     r0, #0
        BNE     %f05

        BL      SendNewTaskMessage      ; ask !Edit for a task window
04
        MOVVC   r0, #pollwordfast_enable ; Allow nulls, and high priority poll word
        [       PollIdleHandling
        MOVVC   r2, #0                  ; no wait
        ]
        ADRVCL  r3, ParentTask          ; poll word = parent task handle
        BLVC    PollWimpFn              ; poll the wimp
        BVS     %f05

        LDR     r14, Moribund           ; return error if we're supposed to be dying
        CMP     r14, #0
        ADRNEL  r0, ErrorBlock_TaskWindow_Dying
        BLNE    CopyError
        BVS     %f05

        LDR     r14, PollWimpResult     ; if we get a null event, !Edit can't have spotted the message
        TEQ     r14, #0
        BNE     %f10

        BL      ReadTaskKeyStates
        BL      SetWimpKeyStates
        ADR     r0, edit_start
        SWI     XWimp_StartTask
        BVS     %f05
        BL      ReadWimpKeyStates
        BL      SetTaskKeyStates

        BL      SendNewTaskMessage      ; ask !Edit for a task window

        MOVVC   r0, #pollwordfast_enable ; Allow nulls, and high priority poll word
        ADRVCL  r3, ParentTask          ; poll word = parent task handle
        [       PollIdleHandling
        MOVVC   r2, #0                  ; no wait
        ]
        BLVC    PollWimpFn              ; poll the wimp
        BVS     %f05

        LDR     r14, Moribund           ; return error if we're supposed to be dying
        CMP     r14, #0
        ADRNEL  r0, ErrorBlock_TaskWindow_Dying
        BLNE    CopyError
        BVS     %f05

        LDR     r14, PollWimpResult     ; if we get a null event, !Edit can't have spotted the message
        TEQ     r14, #0
        ADREQ   r0, ErrorBlock_TaskWindow_NoEditor
        BLEQ    CopyError
        BVS     %f05

10
        LDR     r14, ParentTask         ; block till we get a parent!
        CMP     r14, #0
        BEQ     %b04                    ; then drop through and buffer the character

        BL      SendEgoMessage          ; tell !Edit who we are
05
        Pull    "r1-r3,pc"

        MakeInternatErrorBlock TaskWindow_NoEditor,,M05

edit_start
        DCB     "%Run <TaskWindow$$Server>", 0

; ..............................................................................

SendNewTaskMessage  ROUT
;
; Entry:- r12 -> task block
;         ParentTask = task handle of parent
;         ParentTxt = text buffer handle of parent
;
; Exit:-  message sent to parent, with our task handle in it
;
; Note:   When connecting to a different child, *ShellCLI_Task must get that
;         child to send a message back to !Edit, by sending a message to it.
;
        Push    "r1-r8, lr"

        MOV     r3, #20 + 3       ; Size of block so far
        ADRL    r5, MessageData
        ADRL    r4, Code_TitleString

05      LDRB    r2, [r4], #1
        STRB    r2, [r5], #1      ; Copy the command
        CheckPointers
        ADD     r3, r3, #1
        TEQ     r2, #0
        BNE     %b05              ; Loop until command copied
        BIC     r3, r3, #3        ; Rounded up to word

        MOV     r6, #0            ; No ref
        LDR     r7, =NewTask
        MOV     r0, #User_Message ; Can't send recorded cos of !Edit
        ADR     r1, MessageBlock
        STMIA   r1, {r3-r7}       ; Set up the message block
        SWI     XWimp_SendMessage ; Note r2 = 0 for broadcast

        MOVVC   r14, #1           ; Task=0, Txt=1 => have sent message
        STRVC   r14, ParentTxt

        Pull    "r1-r8, pc"

; ******************************************************************************

Code_ExitHandler ROUT
        ADR     r13, CommandStack+MyStackSize ; Set up my own stack
;
; if we get to the exit handler, and there is no parent task,
; mark MyParameters so that unless there is an exec file, we've finished!
;
        MOV     r14, #0
        STR     r14, MyParameters
;
; Temporary debug stuff
;
        [       DebugExit
        LDR     r0, PassOnVectors
        TEQ     r0, #0
        BEQ     %f02              ; Branch if on vectors
        LDR     r0, Moribund
        TEQ     r0, #0
        BNE     %f02              ; Acceptable to be off vectors if Moribund

        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,4,4,"Exit handler called from ",0
        SUB     sp,sp,#12
        LDR     r0,exitlink
        MOV     r1,sp
        MOV     r2,#12
        SWI     XOS_ConvertHex8
        SWI     XOS_Write0
        SWI     XOS_NewLine
        ADD     sp,sp,#12

        LDR     r0, PassOnVectors
        TEQ     r0, #1
        BNE     %f01
        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,4,4,"Suspicious death while off vectors",10,13,0
        [       UseInCallBack
        LDRB    r0, InCallBack
        TEQ     r0, #0
        BEQ     %f03
        SWI     OS_WriteS
        =       "While in call back",10,13,0
        ]
03      LDRB    r0, EscSem
        TEQ     r0, #0
        BEQ     %f05
        SWI     OS_WriteS
        =       "While in Wimp_Poll",10,13,0
        MOV     r0, #CallBackHandler
        MOV     r1, #0
        MOV     r2, #0
        SWI     XOS_ChangeEnvironment ; Read current callback handler
        CMP     r1, #&1800000
        BCC     %f04
        SWI     OS_WriteS
        =       "Wimp callback handler in place",10,13,0
        B       %f02
04      SWI     OS_WriteS
        =       "Appl. callback handler in place",10,13,0
        B       %f02
01      SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,4,4,"Suspicious death type"
        SWI     OS_WriteC
        SWI     OS_WriteS
        =       10,13,0
        ALIGN
        B       %f02
05
        LDRB    r0, TaskAborted
        TEQ     r0, #0
        BEQ     %f06
        SWI     OS_WriteS
        =       "task aborted",10,13,0
        ALIGN
06
        LDR     r0, Moribund
        TEQ     r0, #0
        BEQ     %f07
        SWI     OS_WriteS
        =       "moribund",10,13,0
        ALIGN
07
        LDR     r0, InPollWimpFn
        TEQ     r0, #0
        BEQ     %f08
        SWI     OS_WriteS
        =       "InPollWimpFn = ",0
        SWI     OS_WriteC
        SWI     OS_NewLine
08
        LDRB    r0, EscRestoreFlag
        TEQ     r0, #0
        BEQ     %f02
        SWI     OS_WriteS
        =       "EscRestoreFlag = ",0
        SWI     OS_WriteC
        SWI     OS_NewLine
        ]
02
        LDRB    r0, TaskAborted   ; See if died suspiciously
        TEQ     r0, #0
        LDREQ   r0, Moribund      ; Or if was killed
        TEQEQ   r0, #0
        BNE     %f20              ; Don't bother with exec stuff if so

; exit handler drops through to prompt for another command

        MOV     r0, #0            ; no command yet - prompt for one
        STR     r0, MyParameters

; ......FALLING THROUGH HERE ***.................................................

Code_NewCommand
;
; Install correct exit and error handlers each time
;
        MOV     r1, #1
        STR     r1, PassOnVectors ; Get off vectors to avoid callback requests
        MOV     r0, #ExitHandler
        ADR     r1, Code_ExitHandler
        MOV     r2, r12
        SWI     OS_ChangeEnvironment
        MOV     r0, #ErrorHandler
        ADRL    r1, Code_ErrorHandler
        MOV     r2, r12
        ADR     r3, ErrorBuffer
        SWI     OS_ChangeEnvironment ; Dunno what we do with an error
;
; restore OS defaults for abort handlers (returning to Supervisor does this)
;
        [       UseGotCallBack
        MOV     r0, #0            ; No call back handler installed yet
        STRB    r0, GotCallBack   ; (we're about to remove it anyway)
        ]
        ADR     r4, defhtable
        MOV     r5, #enddefh-defhtable
05      LDRB    r0, [r4], #1
        SWI     XOS_ReadDefaultHandler
        SWIVC   XOS_ChangeEnvironment
        SUBS    r5, r5, #1
        BNE     %BT05
;
; Now check on exec files
;
        BL      ReadExecHandle    ; Has OS got one?
        BEQ     %f10              ; Branch if not
        MOV     r2, r1
        BL      CloseMyExec       ; Get rid of mine
        STRB    r2, ExecHandle    ; Remember new one
        CheckPointers
10
        LDRB    r1, ExecHandle
        TEQ     r1, #0            ; Is there an exec handle?
        BEQ     %f12              ; Branch if not
;
; Now check if anything in exec file, and get rid of it if not
;
        MOV     r0, #OSArgs_EOFCheck
        SWI     XOS_Args
        MOVVS   r2, #1            ; treat error as EOF
        CMP     r2, #0            ; V clear, NE => EOF
        BLNE    CloseMyExec       ; Get rid of exec file if exhausted
12
;
; if no command waiting to be processed, prompt the user for one
;
        MOV     r1, #0
        STR     r1, PassOnVectors ; Want them at the moment (temporary)

        LDR     r0, MyParameters
        CMP     r0, #0
        BNE     Code_CommandLoop

        LDR     r14, ParentTask   ; if no command, and no window, give up!
        CMP     r14, #0
        BEQ     %f20

        LDR     r14, key_quit     ; if -quit specified,
        CMP     r14, #0
        LDREQ   r14, ReqDie       ; or ShellCLI_TaskQuit been called,
        CMPEQ   r14, #0
        BNE     %f15              ; give up, but this time flush the output

        ADR     r0, cli_prompt
        ADR     r1, ReadLineBuffer
        MOV     r2, #1024
        MOV     r3, #0
        MOV     r4, #3
        SWI     XOS_ReadVarVal
        MOVVC   r0, r1
        MOVVC   r1, r2
        ADRVS   r0, star_prompt
        MOVVS   r1, #1
        SWI     OS_WriteN

        ADR     r0, ReadLineBuffer
        MOV     r1, #1024         ; Max length (changed for Ursula, was 256)
        MOV     r2, #" "          ; Lowest character
        MOV     r3, #&FF          ; Highest
        SWI     XOS_ReadLine      ; Read
        BVS     %f20              ; Exit on error

        ADR     r4, ReadLineBuffer   ; r4 -> command to execute
        BCC     Code_CommandLoop  ; Try next star command if not escape

        MOV     r0, #EscapeAck    ; Acknowledge escape
        SWI     OS_Byte
        SWI     OS_NewLine
        MOV     r0, #0
        ADR     r1, esc_token
        MOV     r2, #0
        MOV     r4, r1
        SWI     XMessageTrans_Lookup
        MOVVS   r2, r4
        MOV     r1, #0
print_esc
        LDRB    r0, [r2, r1]
        CMP     r0, #32
        ADC     r1, r1, #0
        BCS     print_esc
        MOV     r0, r2
        SWI     OS_WriteN
        SWI     OS_NewLine
        B       %b12
esc_token
        DCB     "Escape", 0
cli_prompt
        DCB     "Cli$$Prompt", 0
star_prompt
        DCB     "*"
        ALIGN
15
        BL      SendOutput        ; Clear output buffer
20
        MOV     r1, #1
        STR     r1, PassOnVectors ; Don't want them at the moment
        [ DebugExit
        MOV     r14, #"b"
        STR     r14, InPollWimpFn
        ]
        MOV     r0, #EscapeChar   ; Now reset Escape enable
        LDRB    r1, TaskEscape
        MOV     r2, #0
        SWI     OS_Byte
;
; turn off OS redirection (just in case), and close the files
;
    [ FixRedirection
        MOV     r0, #0            ; MED-03156 fix: was R1 & R2 here
        MOV     r1, #0
        SWI     XOS_ChangeRedirection
        TEQ     r1, #0
        MOVNE   r0, #0
        SWINE   XOS_Find          ; ignore errors
        MOVS    r1, r2
        MOVNE   r0, #0
        SWINE   XOS_Find          ; ignore errors
    ]
;
; if there's a spool file, close it down
;
        BL      ReadSpoolHandle   ; writes OS spool handle to 0
        MOVNE   r0, #0
        SWINE   XOS_Find          ; ignore errors
;
; Handle application dies
; Should send a message to parent (if any) saying so
;
        MOV     r3, #24           ; Size of block
        MOV     r6, #0            ; No ref
        LDR     r7, =Morio        ; I die code
        LDR     r8, ChildTask     ; The name of the child
        MOV     r0, #User_Message ; Not Acked
        ADR     r1, MessageBlock
        STMIA   r1, {r3-r8}       ; Set up the message block
        LDR     r2, ParentTask    ; Who to
        CMP     r2, #0
        SWINE   Wimp_SendMessage  ; Send
;
; Now clear up the exit, error and callback handlers
;
        LDRB    r0, TaskAborted
        TEQ     r0, #0
        BNE     %f30
        MOV     r0, #ErrorHandler
        ADR     r1, OldErrorHandler
        LDMIA   r1, {r1 - r3}     ; Previous values
        SWI     OS_ChangeEnvironment
30
        [       UseGotCallBack
        LDRB    r0, GotCallBack
        TEQ     r0, #0
        MOV     r0, #0
        STRNEB  r0, GotCallBack   ; Unset flag
        MOVNE   r0, #CallBackHandler
        ADRNE   r1, OldCallBackHandler
        LDMNEIA r1, {r1 - r3}     ; Previous values
        SWINE   OS_ChangeEnvironment ; Only put back if had one anyway
        |
        MOV     r0, #CallBackHandler
        MOV     r1, #0
        MOV     r2, #0
        SWI     OS_ChangeEnvironment ; See what previous handler is
        ADRL    r0, Code_CallBackHandler
        TEQ     r0, r1            ; See if current handler is mine
        MOVEQ   r0, #CallBackHandler
        ADREQ   r1, OldCallBackHandler
        LDMEQIA r1, {r1 - r3}     ; Previous values
        SWIEQ   OS_ChangeEnvironment ; Only put back if had one anyway
        ]
        MOV     r0, #ExitHandler
        ADR     r1, OldExitHandler
        [       DebugWimp
        ADRL    r4, Code_ExitHandler
        |
        ADR     r4, Code_ExitHandler
        ]
        LDMIA   r1, {r1 - r3}     ; Previous values
        TEQ     r1, r4
        BEQ     .                 ; Loop if old handler was us
        SWI     OS_ChangeEnvironment ; If this fails, caller can have it
;
; Cease claiming vectors
;
        LDR     r0, GlobalWS
        LDR     r0, [r0]
        LDR     r0, [r0, #:INDEX: NextBlock]
        TEQ     r0, #0            ; 0 <=> this is the last block
        BNE     %f40
        [       UseTickerV
        |
        MOV     r0, #EventDisable
        MOV     r1, #Event_VSync
        SWI     OS_Byte           ; Stop VSync
        ]

        LDR     r0, GotWrchV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotWrchV
        LDRNE   r2, GlobalWS
        MOVNE   r0, #WrchV
        ADRNE   r1, MyWrchV
        SWINE   OS_Release

        LDR     r0, GotUpCallV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotUpCallV
        LDRNE   r2, GlobalWS
        MOVNE   r0, #UpCallV
        ADRNE   r1, MyUpCallV
        SWINE   OS_Release

        LDR     r0, GotRdchV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotRdchV
        LDRNE   r2, GlobalWS
        MOVNE   r0, #RdchV
        ADRNEL  r1, MyRdchV
        SWINE   OS_Release

        LDR     r0, GotByteV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotByteV
        LDRNE   r2, GlobalWS
        MOVNE   r0, #ByteV
        ADRNEL  r1, MyByteV
        SWINE   OS_Release

        LDR     r0, GotEventV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotEventV
        LDRNE   r2, GlobalWS
        [       UseTickerV
        MOVNE   r0, #TickerV
        |
        MOVNE   r0, #EventV
        ]
        ADRNE   r1, MyEventV
        SWINE   OS_Release

        LDR     r0, GotCnpV
        TEQ     r0, #0
        MOV     r0, #0
        STRNE   r0, GotCnpV
        LDRNE   r2, GlobalWS
        MOVNE   r0, #CNPV
        ADRNEL  r1, MyCnpV
        SWINE   OS_Release
40
        BL      SetWimpKeyStates  ; Fn keys back
        BL      Unlink            ; Free our memory
        SWI     Wimp_CloseDown    ; No more wimp
        LDR     r0, PassOnVectors
        TEQ     r0, #1
; ******************************debugging here
        MOVEQ   r0, #"C"
        STR     r0, PassOnVectors
        SWI     OS_Exit           ; Dead

        LTORG

; **************************************************************************************
;
; VSync event  -  used for timeslicing
;

MyEventV ROUT
;
; Handle VSync event
;
; Entry:- r0  = event number
;         r12 = global workspace pointer
;         r14 = address of real vector code
; Entered in IRQ mode
;
; Exit:-  All registers preserved
;
        [       UseTickerV
        |
        TEQ     r0, #Event_VSync  ; Is it the one I want?
        MOVNE   pc, r14           ; Return if not
        ]
;
; Now decrement all Inkey counts for all instances
;
        LDR     r0, FirstWord     ; Pointer to first block
        TEQ     r0, #0            ; See if exists
        BEQ     %f30              ; Ignore if no blocks (shouldn't happen!)
10
        MOV     r12, r0           ; Point to it
        LDR     r0, InkeyCount
        TEQ     r0, #0
        SUBNE   r0, r0, #1
        STRNE   r0, InkeyCount    ; Decrement inkey count if not timed out
        LDR     r0, NextBlock
        TEQ     r0, #0            ; See if exists
        BNE     %b10              ; Loop until all done
        LDR     r12, GlobalWS  ; Original r12
        Push    r14
        BL      FindOwner
        Pull    r14
        TEQ     r12, #0           ; See if found block
        BEQ     %f30              ; Ignore if not
        [       UseInCallBack
        LDRB    r0, InCallBack    ; Or are we in a callback?
        TEQ     r0, #0
        BNE     %f30              ; Ignore if so
        ]
        LDR     r0, VSyncCount
        ADD     r0, r0, #1        ; Increment count
        [ NiceNess
        Push    "r1"
        LDR     r1, Nice
        CMP     r0, r1            ; See if ready for call back yet
        Pull    "r1"
        |
        CMP     r0, #EventCount   ; See if ready for call back yet
        ]
        MOVCS   r0, #0
        STR     r0, VSyncCount
        [       UseTickerV
        |
        MOV     r0, #Event_VSync
        ]
        MOVCC   pc, r14           ; Return if not
;
; Now set up a callback handler ready
;
        MOV     r0, #1            ; Just in case ChangeEnvironment enables IRQ
        STR     r0, PassOnVectors ; Prevent reentrance here
        [ DebugExit
        MOV     r0, #"c"
        STR     r0, InPollWimpFn
        ]
        Push    "r1 - r5"
        SETPSR  SVC_mode,R5,,R4 ; Enter SVC mode
        MOV     r5, r14           ; Remember r14_svc
        MOV     r0, #CallBackHandler
        ADRL    r1, Code_CallBackHandler
        MOV     r2, r12
        ADR     r3, CallBackRegs
        SWI     OS_ChangeEnvironment ;Dunno what we do with an error
        [       UseGotCallBack
        LDRB    r0, GotCallBack   ; See if we had one anyway
        TEQ     r0, #0
        [       DebugWimp
        BNE     %f37                 ; Branch if we think we've got one
        TEQ     r2, r12              ; See if my r12 coming back
        BNE     %f38                 ; Branch if not
        ADRL    r2, Code_CallBackHandler
        TEQ     r2, r1               ; See if my r1 coming back
        MOVNE   r2, r12              ; Restore r2 if not
        BNE     %f38                 ; Branch if not
        ADR     r2, CallBackRegs
        TEQ     r2, r3               ; See if my r3 coming back
        MOVNE   r2, r12              ; Restore r2
        BNE     %f38
;
; My handler was old one (unexpected)
;
35
        MOV     r0, #1
        STR     r0, PassOnVectors
        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,30,"My handler found in EventV",0
        B       .
37
        TEQ     r2, r12              ; See if my r12 coming back
        BNE     %f39                 ; Branch if not
        ADRL    r2, Code_CallBackHandler
        TEQ     r2, r1               ; See if my r1 coming back
        BNE     %f39                 ; Branch if not
        ADR     r2, CallBackRegs
        TEQ     r2, r3               ; See if my r3 coming back
        MOVEQ   r2, r12              ; Restore r2
        BEQ     %f38                 ; Ok, my handler coming back as expected
39
;
; My handler wasn't old one (unexpected)
;
        MOV     r0, #1
        STR     r0, PassOnVectors
        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,30,"My handler not found in EventV",13,10,0
        CMP     r1, #&1800000
        ADRCS   r0, R1M
        ADRCC   r0, R1A
        CMPCS   r1, #&3800000
        ADRCS   r0, R1R
        SWI     OS_Write0
        B       .
R1A     =       "R1 in application space < &1800000", 0
R1M     =       "R1 in module space > &1800000 < &3800000", 0
R1R     =       "R1 in ROM > &3800000", 0
38      TEQ     r0, #0               ; Restore flag
        ]
        ADREQ   r0, OldCallBackHandler
        STMEQIA r0, {r1-r3}
        MOVEQ   r0, #1
        STREQB  r0, GotCallBack   ; Say I have handler set up
        CheckPointers
        |
        ADRL    r0, Code_CallBackHandler
        TEQ     r0, r1            ; See if previous handler is mine
        ADRNE   r0, OldCallBackHandler
        STMNEIA r0, {r1-r3}       ; Save if not
        ]
        SWI     OS_SetCallBack    ; And request the call back
        MOV     r14, r5           ; Restore svc_r14
        RestPSR r4                ; Previous mode
        Pull    "r1 - r5"         ; Register preservation
        MOV     r0, #0
        STR     r0, PassOnVectors ; Back on vectors again
30
        [       UseTickerV
        |
        MOV     r0, #Event_VSync
        ]
        MOV     pc, r14           ; And return anyway


; **************************************************************************************
;
; WrchV  -  buffer characters and task swap sometimes
;

        [       FixControl
controlnumbers
        DCB     0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0         ; chars in control sequence
        DCB     0,1,2,5,0,0,1,9,8,5,0,0,4,4,0,2         ; following the first one
        ALIGN
        ]

MyWrchV ROUT
;
; Entry:- r14 = address of next routine on vector
;         r13 = stack pointer (FD)
;         TOS = return address if we handle this call
;         r12 = Private word
;         r0  = character
; Entered in SVC mode
;
; Exit:-  To caller or next owner of vector
;         All registers except r12 preserved if passed on
;
;         r14 corrupt if handled
;         All other registers preserved
;         V clear
;
        Push    "r1, r14"
        SavePSR r1
        BL      FindOwner
        TEQ     r12, #0           ; See if someone on vectors
        BNE     %FT10
        RestPSR r1,,f
        Pull    "r1, pc"          ; Just pass on if not
10
        CheckIn

        MOV     r14, #1
        STR     r14, PassOnVectors ; Don't intercept vectors
        [ DebugExit
        MOV     r14, #"a"
        STR     r14, InPollWimpFn
        ]
        ADR     r14, VecSaveRegs  ; save regs for later
        STMIA   r14, {r0-r13}
        LDR     r14, [sp]
        STR     r14, VecSaveRegs + 4
        [       FPErrorHandling
        ADR     r14, ErrorRegs
        STMIA   r14, {r0-r12}     ; In case of FP asynchronous errors
        LDR     r14, [sp]
        STR     r14, ErrorRegs + 4
        ]

        ; Switch PSR with stacked R1 now that real R1 is safely in VecSaveRegs
        BIC     r1, r1, #V_bit
        STR     r1, [sp]

;
; r12, r14 only corrupt so far (SaveSVCStack corrupts at least R0-R7,R10)
;
        BL      SaveSVCStack
;
; Now set up new SVC stack
;
        [ DebugExit
        MOV     r14, #"B"
        STR     r14, InPollWimpFn
        ]
        [       FixNDR
        BL      SaveEscape        ; Do this while in SVC mode
                                  ; since it calls a user handler
        ]
        [ DebugExit
        MOV     r14, #"A"
        STR     r14, InPollWimpFn
        ]
        LDR     r13, SVCStackBase ; New empty SVC stack
        WritePSRc USR_mode,r2,,r1 ; must be user mode here, save flags in R1
;
; Now in user mode, so r13 and r14 are new
;
        MOV     r2, r13           ; save old User r13
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"           ; save user regs
        [       FPErrorHandling
        STR     r2, ErrorRegs+13*4
        STR     r14, ErrorRegs+14*4
        ]
;
; This is unnecessarily paranoid
; All that is required is
;       Push    "r1, r2, r14"
;
        [       FixNDR :LAND: checkingcallback
        BL      checkcallback     ; See if a callback is waiting to happen
        ]
        [ DebugExit
        MOV     r14, #"F"
        STR     r14, InPollWimpFn
        SWI     OS_ReadMonotonicTime     ; allow callback to occur!

        MOV     r14, #"G"
        STR     r14, InPollWimpFn
        ]
        [       :LNOT: FixNDR
        BL      SaveEscape
        ]
;
; check if we're in a sequence or starting one
;
        [       FixControl
        LDRB    r14, controlcounter
        SUBS    r14, r14, #1
        STRGEB  r14, controlcounter
        CheckPointers
        BGE     incontrol

        LDR     r0, VecSaveRegs
        CMP     r0, #10                 ; linefeed is not a control character!
        CMPNE   r0, #32
        BGE     notcontrol

        ADR     r14, controlnumbers
        LDRB    r14, [r14, r0]
        STRB    r14, controlcounter
        CheckPointers

incontrol
        LDR     r14, key_ctrl
        CMP     r14, #0
        BEQ     %f10                    ; don't print if ignoring ctrl

notcontrol
        ]
;
; see if we need to obtain a text buffer!
;
        BL      GetParentTask           ; send message and wait if none yet
        BVS     %f10                    ; should pass error out
;
; Buffer output, sending message only if buffer full
;
        LDR     r0, VecSaveRegs   ; Where it was saved
        MOV     r1, #1            ; Buffer number
        BL      Insert
        BCC     %f10              ; Branch if character inserted, don't poll
        BL      SendOutput        ; Send buffer if full
        BL      Insert            ; And put the character in
;
; Then poll wimp to allow other coroutines a chance if we are ready
;
        LDR     lr, OutputCount
        ADD     lr, lr, #1
        CMP     lr, #10
        MOVGE   lr, #0
        STR     lr, OutputCount
        BLT     %f10              ; Only poll every 10 buffer fulls

        MOV     r0, #0            ; Allow nulls
        STR     r0, VSyncCount
        [       PollIdleHandling
        MOV     r2, #0            ; no wait
        ]
        MOV     r3, #0
        BL      PollWimpFn        ; poll the wimp
10
        Pull    "$Regs"           ; restore user regs
        MOV     r13, r2           ; including r13

        ORRVS   r1, r1, #V_bit    ; keep error if there is one
        STRVS   r0, VecSaveRegs

        SWI     OS_EnterOS        ; back to SVC mode
        RestPSR r1                ; restore the mode

        BL      RestoreSVCStack   ; Put back real SVC stack

        [ DebugExit
        MOV     r14, #"a"
        STRB    r14, EscRestoreFlag
        ]
        STR     r4, VecSaveRegs + 16*4
        BL      RestoreEscape
        LDR     r4, VecSaveRegs + 16*4
        MOV     r1, #0            ; Intercepting again
        STR     r1, PassOnVectors
;
; if error, just return
;
        BVC     %ft15
        ADR     r0, VecSaveRegs
        LDMIA   r0, {r0-r13}
        LDR     lr, [sp], #8      ; junk the pass-it-on LR
        ORR     r14, r14, #V_bit
        RestPSR r14,,f
        Pull    "pc"              ; claim - 26-bit set flags; 32-bit mode
15
;
; Send byte to spool file, using the handle remembered before Wimp_Poll
; NB: must do this when we are back on the vectors, in case spool file blocks
;     also all registers must be on the SVC stack, to avoid reentrancy problems
;
        [       FixSpool
        MOV     r0, #ReadSpool
        MOV     r1, #0
        MOV     r2, #&FF          ; just read handle without altering it
        SWI     OS_Byte
        MOVS    r14, r1
        BEQ     %f18

        ADR     r0, VecSaveRegs   ; do this now cos of re-entrancy problems
        LDMIA   r0, {r0-r13}
        Push    "r1-r4"
        MOV     r1, r14
        SWI     XOS_BPut
        BVS     %ft16
        Pull    "r1-r4, r14"
        RestPSR r14
        TEQ     pc, pc
        Pull    "r14, pc",NE,^    ; claim - 26-bit mode
        Pull    "r14, pc"         ; claim - 32-bit mode
16
        MOV     r4, r0
        MOV     r0, #ReadSpool
        MOV     r1, #0
        MOV     r2, #0
        STRB    r1, SpoolHandle
        SWI     OS_Byte
        MOV     r0, #0
        SWI     XOS_Find
        MOV     r0, r4
        Pull    "r1-r4, lr"
        ORR     r14, r14, #V_bit
        RestPSR r14
        Pull    "r14, pc"         ; claim - 26-bit pass back flags; 32-bit mode
        ]
;
; Check if dying now
;
18      BL      CheckDying

        CheckOut

        ADR     r0, VecSaveRegs   ; do this now cos of re-entrancy problems
        LDMIA   r0, {r0-r13}
        LDR     r14, Moribund
        TEQ     r14, #0
        LDR     lr, [sp], #8      ; junk the pass-it-on LR
        BNE     %ft20
        RestPSR lr
        Pull    "pc"         ; claim - 32-bit mode
20
        RestPSR lr
        Pull    "lr"
        ADR     r0, ErrorBlock_TaskWindow_Dying
        BNE     CopyError

; **************************************************************************************
;
; UpCallV  -  watch for UpCall_Sleep (for PipeFS primarily)
;

MyUpCallV ROUT
;
; Entry:- r14 = address of next routine on vector
;         r13 = stack pointer (FD)
;         TOS = return address if we handle this call
;         r12 = Private word
;         r0  = upcall reason code (we want UpCall_Sleep only)
;         r1  = address of poll word (will become non-zero when ready)
; Entered in SVC mode
;
; Exit:-  To caller or next owner of vector
;         All registers except r12 preserved if passed on
;
;         r14 corrupt if handled
;         All other registers preserved
;         V clear
;
        Debug   up,"TaskWindow UpCall: r0,r1,r12 =",r0,r1,r12

        TEQ     r0, #UpCall_SleepNoMore
        BEQ     sleepnomore             ; return error if we're sleeping on one of these

        TEQ     r0, #UpCall_Sleep
        MOVNE   pc, lr            ; pass it on

        Push    "r0, r14"
        BL      FindOwner
        Debug   up,"UpCall_Sleep: task r12 =",r12
        TEQ     r12, #0           ; See if someone on vectors
        Pull    "r0, r14"
        MOVEQ   pc, r14           ; Just pass on if not

        CheckIn

        MOV     r14, #1
        STR     r14, PassOnVectors ; Don't intercept vectors
        [ DebugExit
        MOV     r14, #"a"
        STR     r14, InPollWimpFn
        ]
        ADR     r14, VecSaveRegs  ; save regs for later
        STMIA   r14, {r0-r13}
        [       FPErrorHandling
        ADR     r14, ErrorRegs
        STMIA   r14, {r0-r12}     ; In case of FP asynchronous errors
        ]

;
; r12, r14 only corrupt so far
;
        BL      SaveSVCStack
;
; Now set up new SVC stack
;
        [ DebugExit
        MOV     r14, #"B"
        STR     r14, InPollWimpFn
        ]
        [       FixNDR
        BL      SaveEscape        ; Do this while in SVC mode
                                  ; since it calls a user handler
        ]
        [ DebugExit
        MOV     r14, #"A"
        STR     r14, InPollWimpFn
        ]
        LDR     r13, SVCStackBase ; New empty SVC stack
        WritePSRc USR_mode,r2,,r1 ; must be user mode here, save flags in R1
;
; Now in user mode, so r13 and r14 are new
;
        MOV     r2, r13           ; save old User r13
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"           ; save user regs
        [       FPErrorHandling
        STR     r2, ErrorRegs+13*4
        STR     r14, ErrorRegs+14*4
        ]
;
; This is unnecessarily paranoid
; All that is required is
;       Push    "r1, r2, r14"
;
        [       FixNDR :LAND: checkingcallback
        BL      checkcallback     ; See if a callback is waiting to happen
        ]
        [ DebugExit
        MOV     r14, #"F"
        STR     r14, InPollWimpFn
        SWI     OS_ReadMonotonicTime     ; allow callback to occur!

        MOV     r14, #"G"
        STR     r14, InPollWimpFn
        ]
        [       :LNOT: FixNDR
        BL      SaveEscape
        ]
;
; We're waiting, so clear output buffer
;
        BL      SendOutput
;
; Sleep until the poll word becomes non-zero
; [VecSaveRegs+4] = R1 on entry (Poll word address)
;
10
        LDR     r3, VecSaveRegs+4          ; R3 -> poll word
        STR     r3, PollWord
        TEQ     r3, #0                     ; this is a yield if pollword is zero,
        MOVEQ   r0, #1
        LDRNE   r0, [r3]                   ; or contents are already nonzero,
        TEQ     r0, #0                     ; else its a sleep
15      MOVNE   r0, #0
        MOVEQ   r0, #pollword_enable       ; pollword_enable
        ORREQ   r0, r0, #null_bit          ; mask nulls
20
        [       PollIdleHandling
        MOV     r2, #0            ; no wait
        ]
        BL      PollWimpFn        ; poll the wimp, dealing with events
        MOV     r14, #0
        STR     r14, PollWord

; safer not to loop here - keep out of the innards of FileSwitch!

  ;;    LDR     r14, VecSaveRegs+4
  ;;    LDR     r14, [r14]
  ;;    MOVVS   r14, #1           ; stop looping if error returned
  ;;    TEQ     r14, #0           ; ##### (doesn't work) #####
  ;;    BEQ     %BT10

        Pull    "$Regs"           ; restore user regs
        MOV     r13, r2           ; including r13

        ORRVS   r1, r1, #V_bit    ; keep error if there is one
        STRVS   r0, VecSaveRegs

        SWI     OS_EnterOS        ; back to SVC mode
        RestPSR r1                ; restore the mode

        BL      RestoreSVCStack   ; Put back real SVC stack

        [ DebugExit
        MOV     r14, #"a"
        STRB    r14, EscRestoreFlag
        ]
        BL      RestoreEscape
        MOV     r1, #0            ; Intercepting again
        STR     r1, PassOnVectors
;
; Check if dying now
;
        BL      CheckDying

        CheckOut

        LDRB    r0, EscWasSet
        TEQ     r0, #0            ; See if we should return escape
        ADR     r0, VecSaveRegs
        LDMIA   r0, {r0-r13}
        Pull    "pc", VS          ; just return if error

        SavePSR r14
        Push    r14
        LDR     r14, Moribund
        TEQ     r14, #0
        Pull    r14
        Pull    r14, NE           ; Get return address if going to cause error
        ADRNE   r0, ErrorBlock_TaskWindow_Dying
        BNE     CopyError
        BIC     r14, r14, #V_bit  ; clear V (CopyError will set it again if needs be)
        RestPSR r14,,f            ; Restore flags
        Pull    r14               ; Get return address anyway
        ADRNE   r0, ErrorBlock_Escape
        BNE     CopyError
        MOV     r0, #UpCall_Claimed    ; we dealt with it
        MOV     pc, lr                 ; Exit without error

sleepnomore
        LDR     r12, FirstWord    ; Point to a workspace
50      CMP     r12, #0                         ; clears V
        MOVEQ   r0, #UpCall_SleepNoMore         ; don't claim this!
        MOVEQ   pc, lr
        LDR     r0, PollWord
        TEQ     r0, #0
        LDREQ   r12, NextBlock    ; If not sleeping, try the next block
        BEQ     %b50              ; Loop
        TEQ     r0, r1
        LDRNE   r12, NextBlock    ; else see if they match
        BNE     %b50
        ADR     r0, ErrorBlock_TaskWindow_FileSleep
        BL      CopyError
        Pull    "pc"

        MakeInternatErrorBlock TaskWindow_FileSleep,,M04
        MakeInternatErrorBlock Escape,,Escape

; **************************************************************************************
;
; RdchV  -  take characters from buffer and task swap if buffer empty
;

MyRdchV ROUT
;
; Entry:- r14 = address of real vector code
;         r13 = stack pointer (FD)
;         r12 = Private word
; Entered in SVC mode
;
; Exit:-  To caller
;         r0 modified, all other registers preserved
;
        Push    "r0, r1, r14"
        SavePSR r1
        BL      FindOwner
        TEQ     r12, #0           ; See if someone got vectors
        BNE     %FT05
        RestPSR r1,,f
        Pull    "r0, r1, pc"      ; Just pass on if not

05
        RestPSR r1,,f
        Pull    "r0, r1, r14"
        CheckIn

; See if any input has arrived for us

        BL      GetInput          ; Try for input either from exec or buffer
        BCS     %f10              ; No input, so do other things

; Now check we don't have escape as well

        SWI     OS_ReadEscapeState
        LDRB    r14, EscPending   ; See if existed anyway
        ADCS    r14, r14, #0      ; clears C,V,N; clears Z if r14 != 0 or SWI returned C set
        B       %f40              ; Common exit code
10
        ADR     r14, VecSaveRegs  ; save regs for later
        STMIA   r14, {r0-r13}
        [       FPErrorHandling
        ADR     r14, ErrorRegs
        STMIA   r14, {r0-r12}     ; In case of FP asynchronous errors
        ]

        MOV     r0, #1
        STR     r0, PassOnVectors
        [ DebugExit
        MOV     r0, #"d"
        STR     r0, InPollWimpFn
        ]
        BL      SaveSVCStack
        [       FixNDR
        BL      SaveEscape        ; Do in SVC mode since it may
                                  ; call a user handler
        ]
;
; Now set up new SVC stack
;
        LDR     r13, SVCStackBase ; New empty SVC stack
        WritePSRc USR_mode,r2,,r1 ; must be user mode here, save flags in R1
;
; Now in user mode, so r13 and r14 are new
;
        MOV     r2, r13           ; save old User r13
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"           ; save user regs
        [       FPErrorHandling
        STR     r2, ErrorRegs+13*4
        STR     r14, ErrorRegs+14*4
        ]
        [       FixNDR
         [ checkingcallback
        BL      checkcallback     ; See if a callback is waiting to happen
         ]
        |
        BL      SaveEscape
        ]
;
; at this stage we need a text buffer
;
        BL      GetParentTask
        BVS     %f30              ; should pass error out
;
; We're waiting, so empty output buffer
;
        BL      SendOutput
;
; Then poll wimp to allow other coroutines a chance
;
20
        MOV     r0, #1            ; Disallow nulls
        [       PollIdleHandling
        MOV     r2, #0            ; no wait
        ]
        MOV     r3, #0            ; no poll word
        BL      PollWimpFn        ; poll the wimp
;
; Now see if some input has arrived
; If so, return from this poo, otherwise loop
;
        LDRB    r0, EscPending    ; See if pending escape
        TEQ     r0, #0
        LDREQ   r0, Moribund      ; Or dying
        TEQEQ   r0, #0
        MOVNE   r0, #EscapeSet
        STRNEB  r0, EscPending    ; If we're dying, return escape condition
        CheckPointers
        BNE     %f30              ; Don't bother looking in buffer if so
        BL      GetKbInput
        BCS     %b20
        STR     r0, VecSaveRegs   ; Ready for return
30
        Pull    "$Regs"           ; restore user regs
        MOV     r13, r2           ; including r13

        ORRVS   r1, r1, #V_bit    ; keep error if there is one
        STRVS   r0, VecSaveRegs

        SWI     OS_EnterOS        ; back to SVC mode
        RestPSR r1                ; restore the mode

        BL      RestoreSVCStack   ; Put back real SVC stack
        [ DebugExit
        MOV     r14, #"b"
        STRB    r14, EscRestoreFlag
        ]
        BL      RestoreEscape
        MOV     r1, #0            ; Intercepting again
        STR     r1, PassOnVectors

;
; Check if dying now
;
        BL      CheckDying

        CheckOut

        LDRB    r0, EscWasSet
        TEQ     r0, #0            ; See if we should return escape
        ADR     r0, VecSaveRegs
        LDMIA   r0, {r0-r13}
        Pull    "pc", VS          ; just return if error
40
        SavePSR r14
        Push    r14
        LDR     r14, Moribund
        TEQ     r14, #0
        Pull    r14
        Pull    r14, NE           ; Get return address if going to cause error
        ADRNE   r0, ErrorBlock_TaskWindow_Dying
        BNE     CopyError
        ; the Z flag in the R14 PSR is important, but need V clear for good
        ; return plus we clear C for the non-ESCAPE case.
        BIC     r14, r14, #V_bit+C_bit
        TST     r14, #Z_bit       ; *Invert* R14:Z_bit into Z
        MOVEQ   r0, #Esc
        ORREQ   r14, r14, #C_bit  ; set carry if returning Escape
        RestPSR r14,,f            ; Set flags to what we want
        Pull    "pc"              ; and return

        MakeInternatErrorBlock TaskWindow_Dying,,M03

; **************************************************************************************
;
; ByteV  -  inkey and escape handling
;

MyByteV ROUT
;
; Entry:- r14 = address of real vector code
;         r13 = stack pointer (FD)
;         r12 = Private word
;         r0 - r2 as for OS_Byte
; Entered in SVC mode, IRQs disabled
;
; Exit:-  To caller
;         r0 modified, all other registers preserved
;
        Push    lr
        SavePSR lr
        TEQ     r0, #Inkey
        TSTEQ   r2, #&80
        TEQNE   r0, #EscapeAck    ; Is it escape acknowledge then?
        [       EmulateEscapeChar
        TEQNE   r0, #EscapeChar
        ]
        BEQ     %FT01
        RestPSR lr,,f
        Pull    "pc"              ; Return if not inkey, or inkey negative
01
        Push    "r0, r14"
        BL      FindOwner         ; Is anyone on the vectors now?
        TEQ     r12, #0
        BNE     %FT02
        Pull    "r0, r12, r14"
        RestPSR r12,,f
        MOV     pc, r14           ; Pass it on if not
02
        Pull    "r0"
        ; stack now contains PSR, pass on LR, claim LR
        CheckIn

        TEQ     r0, #EscapeAck
        BEQ     %f45              ; Handle escape acknowledge separately
        [       EmulateEscapeChar
        TEQ     r0, #EscapeChar
        BEQ     %f50              ; Handle escape allowed
        ]
        Pull    "r0,r14"          ; Discard pass on LR
        Push    "r0"              ; Push PSR back again
        AND     r0, r1, #&FF
        AND     r2, r2, #&FF
        ORR     r0, r0, r2, LSL #8; Get count value
        [       UseTickerV
        |
        ADD     r0, r0, #1        ; Ensure count 1 not treated as zero
        MOV     r0, r0, LSR #1    ; Divide by two for use with VSync
        ]
        STR     r0, InkeyCount

; See if any input has arrived for us

        BL      GetInput          ; Try for input either from exec or buffer
        BCS     %f05              ; No input, so do other things

; Now check we don't have escape as well

        SWI     OS_ReadEscapeState
        LDRB    r14, EscPending   ; Else see if existed anyway
        ADCS    r14, r14, #0      ; clear NCV; clear Z if R14 != 0 or C was set
        B       %f30              ; Common exit code
05
;
; Now see if timed out
;
        LDR     r14, InkeyCount
        TEQ     r14, #0
        BNE     %f10              ; Branch if not
        MOVS    r2, #&FF          ; Timeout flag, unsetting zero
        B       %f40
10
        ADR     r14, VecSaveRegs  ; save regs for later
        STMIA   r14, {r0-r13}
        [       FPErrorHandling
        ADR     r14, ErrorRegs
        STMIA   r14, {r0-r12}     ; In case of FP asynchronous errors
        ]

        MOV     r0, #1
        STR     r0, PassOnVectors
        [ DebugExit
        MOV     r0, #"e"
        STR     r0, InPollWimpFn
        ]
        BL      SaveSVCStack
        [       FixNDR
        BL      SaveEscape        ; do this in SVC mode since it calls a user handler
        ]
;
; Now set up new SVC stack
;
        LDR     r13, SVCStackBase ; New empty SVC stack
        WritePSRc USR_mode,r2,,r1 ; USR mode, IRQs enabled, old PSR in r1
;
; Now in user mode, so r13 and r14 are new
;
        MOV     r2, r13           ; save old User r13
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"           ; save user regs
        [       FPErrorHandling
        STR     r2, ErrorRegs+13*4
        STR     r14, ErrorRegs+14*4
        ]
        [       FixNDR
         [  checkingcallback
        BL      checkcallback     ; See if a callback is waiting to happen
         ]
        |
        BL      SaveEscape
        ]
;
; at this stage we need a text buffer
;
        BL      GetParentTask
;        BVS     %f25              ; should pass error out
;
; We're waiting, so empty output buffer
;
        BL      SendOutput
;
; Then poll wimp to allow other coroutines a chance
;
15
        [       PollIdleHandling
        SWI     XOS_ReadMonotonicTime
        LDR     r2, InkeyCount
        [       UseTickerV
        ADD     r2, r0, r2
        |
        ADD     r2, r0, r2, LSL#1
        ]
        ]

        MOV     r0, #0            ; Allow nulls (else we never time out!)
        MOV     r3, #0
        BL      PollWimpFn        ; poll the wimp
;
; Now see if some input has arrived
; If so, return from this poo, otherwise loop
;
        LDRB    r0, EscPending    ; See if pending escape
        TEQ     r0, #0
        LDREQ   r0, Moribund      ; Or dying
        TEQEQ   r0, #0
        BNE     %f25              ; Don't bother looking in buffer if so
        BL      GetKbInput
        BCC     %f20
;
; See if timed out
;
        LDR     r0, InkeyCount
        TEQ     r0, #0
        BNE     %b15              ; Loop if not
        MOV     r0, #-1
20
        STR     r0, VecSaveRegs   ; Ready for return
25
        Pull    "$Regs"           ; restore user regs
        MOV     r13, r2           ; including r13

        ORRVS   r1, r1, #V_bit    ; keep error if there is one
        STRVS   r0, VecSaveRegs

        SWI     OS_EnterOS        ; back to SVC mode
        RestPSR r1                ; restore the mode

        BL      RestoreSVCStack   ; Put back real SVC stack
        [ DebugExit
        MOV     r14, #"f"
        STRB    r14, EscRestoreFlag
        ]
        BL      RestoreEscape
        MOV     r1, #0            ; Intercepting again
        STR     r1, PassOnVectors
;
; Check if dying now
;
        BL      CheckDying

        CheckOut

        LDRB    r0, EscPending
        TEQ     r0, #0            ; See if we should return escape
        ADR     r0, VecSaveRegs
        LDMIA   r0, {r0-r13}
        Pull    "r14, pc", VS     ; just return if error (discard CPSR)
        BNE     %f35              ; Branch if escape to be returned
30
        MOVS    r1, r0
        MOVMI   r2, #&FF
        BMI     %f40              ; Branch if timeout
        MOVS    r2, #0            ; Set zero
35
        SavePSR r14
        LDR     r0, Moribund
        TEQ     r0, #0            ; Are we dying
        BNE     %FT42             ; Go generate error
        RestPSR r14,,f            ; Restore flags

        MOVNE   r2, #Esc
40
        MOVNE   r1, #&FF
        Pull    r14               ; get pack stacked PSR
        BICEQ   r14, r14, #C_bit  ; clear C if needs be
        ORRNE   r14, r14, #C_bit  ; set C if needs be
        RestPSR r14
        MOV     r0, #Inkey
        Pull    "pc"              ; return to caller

42
        Pull    "r0, r14"         ; Discard CPSR, get return address
        ADR     r0, ErrorBlock_TaskWindow_Dying
        B       CopyError

; .......................................................................

; EscapeAck - first see if escape exists

45
        ; stack now contains PSR, pass on LR, claim LR
        Push    "r0-r2"
        SWI     XOS_ReadEscapeState
        BLCS     %FT48            ; only action if there was an escape
        Pull    "r0-r2, lr"
        RestPSR lr
        Pull    "pc"
48
        Push    "lr"
        MOV     r0, #EscapeSide
        MOV     r1, #0
        MOV     r2, #&ff
        SWI     OS_Byte           ; See if side effects on at the moment
        TEQ     r1, #0
        BLEQ    CloseMyExec
        Pull    "pc"

; ........................................................................

; EscapeChar - simulated, so task can't get escapes without the caret

        [       EmulateEscapeChar
50
        ; stack now contains PSR, pass on LR, claim LR
        Push    "r3, r4"

        Debuga  esc,"*FX 229",R1,R2

        LDRB    r3, EscapeDisable ; Old value
        AND     r4, r2, r3
        EOR     r4, r1, r4        ; New value
        STRB    r4, EscapeDisable ; Save disable state
        CheckPointers
        MOV     r1, #1
        STR     r1, PassOnVectors ; Not on vectors now
        MOV     r2, #0
        SWI     XOS_Byte          ; Turn them off (just in case first time!)
                                  ; and get correct r2 value
        MOV     r1, #0
        STR     r1, PassOnVectors ; Back on vectors
        MOV     r1, r3            ; Old value in correct register
                                  ; r2 already correct
        Debug   esc," gives",R1,R2

        Pull    "r3-r4, r14"
        BIC     lr, lr, #V_bit
        RestPSR lr
        Pull    "r14, pc"         ; Claim - return to user.
        ]

; **************************************************************************************
;
; CnpV  -  flushing of keyboard buffer
;

MyCnpV  ROUT
;
; Entry:- r14 = address of real vector code
;         r13 = stack pointer (FD)
;         r12 = Private word
;         r1  = buffer number
;         r3  = 0 => count
;         r3  = 1 => purge
;
; Entered in SVC mode
;
; Exit:-  To caller
;         r0 undefined
;         all other registers preserved
;
        ; XXX: sbrodie 2000/05/27: WTF?? I'd like to know where this module
        ; thinks R3 gets set up, because the kernel sure doesn't set it ...
        [ {FALSE}
        TEQ     r3, #1           ; Is it purge?
        TEQEQ   r1, #0           ; Is it my buffer?
        MOVNES  pc, r14          ; Out if not
        Push    "r0, r12, r14"
        BL      FindOwner
        TEQ     r12, #0
        BLNE    Clear            ; Empty my buffer
        Pull    "r0, r12, pc",,^ ; Continue with other people on the vectors
        |
        MOVVC   pc, r14          ; VS for purge - pass on VC calls (preserve C+V)
        TEQ     r1, #0           ; Is it my buffer? (Preserve C+V!)
        MOVNE   pc, r14          ; not my buffer - pass it on preserving C+V
        Push    "r0, r12, r14"
        SavePSR r0
        BL      FindOwner
        TEQ     r12, #0
        BLNE    Clear            ; Empty my buffer
        RestPSR r0,,f
        Pull    "r0, r12, pc"
        ]

; **************************************************************************************
;
; CallBack handler  -  from time slice event or die call.
;

ErrorBlock_TaskWindow_BadMode
        DCD     0
        DCB     "M10",0
        ALIGN

Code_CallBackHandler ROUT
;
;
; Entry:- r12 = workspace pointer
;         registers saved in CallBackRegs
;
; Exit:-  via saved registers
;
; Uses:-  r11 for saved mode
;
; First remove callback handler
;
        ; XXX: sbrodie 2000/05/27: This code appears to be validating the
        ; entry conditions for the callback handler.  Why??  Removed it.
        [ {FALSE}
        SavePSR r11
        TST     r11, #1
        TSTNE   r11, #2          ; Check mode bits
        TSTNE   r11, #I_bit      ; Check interrupts off as well
        BNE     %f10
        MOV     r0, #1
        STR     r0, PassOnVectors
        ADR     r0, ErrorBlock_TaskWindow_BadMode
        BL      CopyError
        ADD     r0, r0, #4
        SWI     OS_Write0
        SWI     OS_NewLine
        SWI     OS_Exit
10
        ]
        [       UseGotCallBack
        MOV     r0, #0           ; Does the relevant NOP as well
        STRB    r0, GotCallBack  ; Not got a handler installed anyway
        ]
        ADR     r0, OldCallBackHandler
        LDMIA   r0, {r1-r3}
        MOV     r0, #CallBackHandler
        SWI     OS_ChangeEnvironment ; Dunno what we do with an error
        LDR     r11, SVCStackBase
        CMP     r11, r13
        [ NiceNess
        LDRNE   r11, Nice
        SUB     r11, r11, #1
        |
        MOV     r11, #EventCount - 1
        ]
        STRNE   r11, VSyncCount
        BNE     %f50
        [       DebugWimp
        TEQ     r2, r12              ; See if my r12 coming back
        BNE     %f15                 ; Branch if not
        ADRL    r2, Code_CallBackHandler
        TEQ     r2, r1               ; See if my r1 coming back
        BNE     %f15                 ; Branch if not
        ADR     r2, CallBackRegs
        TEQ     r2, r3               ; See if my r3 coming back
        BEQ     %f17
15
        MOV     r0, #1
        STR     r0, PassOnVectors
        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,30,"Removing call back leaves wrong handler",0
        B       .
17
        ]
;
; Stay in SVC mode
;
; Now see if I'm on vectors
;
        [       FixDomain
        BL      CheckDomain       ; check PassOnVectors and domain ID
        |
        LDR     r0, PassOnVectors
        TEQ     r0, #0
        ]
        BNE     %f40              ; DON'T check callbackflag - not set up

        CheckIn

        MOV     r0, #1
        STR     r0, PassOnVectors ; First make sure we don't get re-entered
        [ DebugExit
        MOV     r14, #"f"
        STR     r14, InPollWimpFn
        ]
        [       UseInCallBack
        STRB    r0, InCallBack    ; Say we're in a call back
        CheckPointers
        ]
        LDR     r0, Moribund      ; See if we're dying
        TEQ     r0, #0
; ******************************debugging here
        BNE     abex_exit
;
; Now for the tricky bit of polling the wimp
; and emptying the output buffer if it's not empty
;
        BL      SaveSVCStack
        [       FPErrorHandling
        ADR     r0, CallBackRegs
        ADR     r13, ErrorRegs
        LDMIB   r0!, {r1-r9}
        STMIB   r13!, {r1-r9}
        LDMIB   r0, {r1-r7}       ; His r10 - r15 and CPSR (if 32-bit)
        STMIB   r13, {r1-r7}      ; Saved
        ]
        LDR     r13, SVCStackBase ; New empty SVC stack
;
; cancel pending escape condition now, while we're still in SVC mode
;
        [ FixNDR
        BL      SaveEscape
        ]
;
; enter USR mode
;
        WritePSRc USR_mode,r2,,r1 ; user mode, irqs enabled, old CPSR saved for later
;
; Now in user mode, so r13 and r14 are new
;
        MOV     r2, r13           ; save old User r13
        ADR     r13, MyVecStack+MyStackSize
        Push    "$Regs"           ; save user regs
;
; if the task has requested a callback,
; we want to 'suspend' it until after the Wimp_Poll
;
        [ FixNDR
         [ checkingcallback
        BL      checkcallback     ; sets up [callbackflag]
         ]
        |
        BL      SaveEscape
        ]
;
; send writec output to Edit if required
;
        BL      SendOutput        ; Send buffer if full

;
; If the interrupt that brought us here occured on an unimplemented
; FP instruction (eg SIN), the FPA will be in a funny state (it will have
; set the SB bit in the FPCR, but the IRQ will have had priority over the
; undefined instruction trap, and the next FP instruction it receives will
; bounce). Solve this by "changing" FP context (see FPASC.coresrc.s.main).
; In fact we are only changing to the current (and only) context, but this
; will sort out this erroneous pending bounce.
;
; This solution was suggested by David Seal of ARM - it's partly our fault
; for attempting to do our own context switching. We should really look at
; using the MultipleContexts version of the core and getting the Wimp
; to do a ChangeContext.
;

        SWI     XFPEmulator_DeactivateContext   ; Puts old context ptr in R0
        SWI     XFPEmulator_ActivateContext     ; Reactivates old context

;
; Then poll wimp to allow other coroutines a chance
;
        MOV     r0, #0            ; Allow nulls
        [       PollIdleHandling
        MOV     r2, #0            ; no wait
        ]
        MOV     r3, #0
        BL      PollWimpFn        ; poll the wimp

        Pull    "$Regs"           ; restore user regs
        MOV     r13, r2           ; including r13

        ; can't have errors from callback

        LDR     r0, Moribund
        TEQ     r0, #0
        BNE     abex_exit

        SWI     OS_EnterOS        ; back to SVC mode
        RestPSR r1                ; restore the mode
        BL      RestoreSVCStack   ; Put back real SVC stack

        CheckOut

20
;
; restore escape condition if it was pending (may cause callback request)
;
      [ FixNDR
        [ DebugExit
        MOV     r14, #"c"
        STRB    r14, EscRestoreFlag
        ]
        BL      RestoreEscape     ; this may cause task to request a callback
;
; check for the task's escape handler having requested a callback
;
        WritePSRc USR_mode,r0,,r1 ; USR mode, IRQs enabled, old state in R1
        ADR     r13, MyVecStack+MyStackSize     ; and we've got a stack!
         [ checkingcallback
        LDRB    r14, callbackflag
        TEQ     r14, #0
        BLEQ    checkcallback                   ; sets up [callbackflag]
         ]
        SWI     OS_EnterOS
        RestPSR r1
      |
        [ DebugExit
        MOV     r14, #"c"
        STRB    r14, EscRestoreFlag
        ]
        BL      RestoreEscape     ; this may cause task to request a callback
      ]
;
; clear down our semaphores - don't go back into USR mode until we exit!
;
        MOV     r0, #0
        STR     r0, PassOnVectors ; And get on vectors again
        [       UseInCallBack
        STRB    r0, InCallBack    ; No longer in call back
        CheckPointers
        ]
;
; exit from callback - possibly passing control to the next callback handler
;
30
        [ FixNDR :LAND: checkingcallback :LAND: chainingcallback
        LDRB    r14, callbackflag
        TEQ     r14, #0
        BEQ     %f40                    ; no more callbacks pending

        MOV     r0, #CallBackHandler
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        SWI     OS_ChangeEnvironment    ; read previous handler

        Push    "R1"
        Push    "R2"
        Push    "R12"                   ; So we can recover it later
        Push    "R3"                    ; Add to stack in correct order
        Debug   ndr,"Forcing callback to",R1,R2,R3

      [ CheckBufferPointers
        LDR     r14, Debug_Word
        ADD     r14, r14, #1            ; no of times this was called
        STR     r14, Debug_Word

        CheckOut
      ]

        MyCLREX r0, r1
        ADR     r14, CallBackRegs
        LDMIA   r14, {r0-r14}^          ; get USR registers
        NOP
        Pull    "r14"                   ; SVC r14 -> USR register buffer
  [ SASTMhatbroken
        STMIA   r14!,{r0-r12}
        STMIA   r14, {r13,r14}^
        NOP
        SUB     r14, r14, #13*4
  |
        STMIA   r14, {r0-r14}^
  ]

        TEQ     PC,PC                   ; Set Z if in 32-bit mode
        LDREQ   r12, CallBackRegs+16*4
        STREQ   r12, [r14, #16*4]       ; copy the user CPSR
        Pull    "R12"

        LDR     r12, CallBackRegs+15*4
        STR     r12, [r14, #15*4]
        Pull    "r12, pc"               ; enter callback routine in SVC mode
        ]

; exit from callback without checking callbackflag if we branch here (may lose callbacks but that's tough)

40
        CheckOut
50
        MyCLREX r0, r1
        ADR     r14, CallBackRegs
        TEQ     PC,PC
        LDREQ   r0, [r14, #16*4]  ; The CPSR
        MSREQ   SPSR_cxsf, r0     ; put into SPSR_svc/SPSR_irq ready for MOVS
        LDMIA   r14, {r0-r14}^    ; Restore user registers
        NOP
        LDR     r14, [r14, #15*4] ; The pc
        MOVS    pc, r14           ; Back we go (32-bit safe - SPSR set up)

abex_exit
        MOV     r0, #0
        STR     r0, PassOnVectors

; Exit with "ABEX" so nested C proggies will quit
        ADR     r0, exit_error
        BL      CopyError
        LDR     r1, =&58454241 ; "ABEX"
        MOV     r2, #1
        SWI     OS_Exit
; Don't expect to get this error, only if Sys$RCLimit < 1 in which case
; we'll probably get a no stack for trap handler from the C library.
exit_error
        DCD     &1000
        DCB     "M09", 0
        ALIGN

        [ FixNDR :LAND: checkingcallback

;
; Entry:- r13 addresses valid stack
;         r14 = link
;         r12 points to workspace
;         Mode USR
; Exit:-  r0, r14 corrupt
;
checkcallback
        Push    "r1-r3,lr"

        MOV     r0, #CallBackHandler
        ADR     r1, callbackchecker
        MOV     r2, r12
        ADR     r3, ScratchBlock
        SWI     OS_ChangeEnvironment

        Push    "r0-r3"

        MOV     r14, #0
        STRB    r14, callbackflag

        SWI     OS_ReadMonotonicTime    ; bound to get a callback if pending!
        Pull    "r0-r3"
        SWI     OS_ChangeEnvironment    ; restore old handler (always)

        Pull    "r1-r3,pc"

callbackchecker
        MOV     r14, #"c"
        STRB    r14, callbackflag

        ADR     r14, ScratchBlock
        TEQ     PC,PC             ; Z set if 32-bit mode
        LDREQ   r0, [r14, #16*4]  ; yes - new format callback register dump
        MSREQ   SPSR_cxsf, r0     ; shove it in SPSR so it gets restored on MOVS pc, r14
        LDMIA   r14, {r0-r14}^    ; Restore user registers
        NOP
        LDR     r14, [r14, #15*4] ; The pc
        MOVS    pc, r14           ; Back we go (32-bit OK - SPSR set up correctly)

        ]

; ************************************************************************************
;
; Miscellaneous routines
;

SaveSVCStack ROUT
;
; Now copy the SVC stack into my private copy
;
; Corrupts r0 - r7, r10
;
        SavePSR r7
        [       FPErrorHandling
        STR     r13, SVCStackLimit ; In case of FP error
        ]
        MOV     r10, r13          ; Remember stack position
        ADRL    r0, MySVCStack    ; To
        LDR     r1, SVCStackBase  ; From
10
        LDMDB   r1!, {r2-r6}
        STMIA   r0!, {r2-r6}      ; Copy stack to my area
        CMP     r1, r13
        BHI     %b10
;
; Now save the seven words at the very base where C modules
; have stack chunk information stored.
;
        LDR     r6, =&000FFFFF    ; Megabyte mask
        BIC     r1, r1, r6        ; Base of stack
        LDMIA   r1!, {r2-r5}      ; The first four words
        ADRL    r0, MySVCStack    ; To
        LDR     r6, MySVCStackSize ; Size thereof
        ADD     r0, r0, r6        ; Address of slot at end
        STMDB   r0!, {r2-r5}      ; Copy them
        LDMIA   r1!, {r2-r4}      ; The other three words
        STMDB   r0!, {r2-r4}      ; Copy them
        RestPSR r7,,f
        MOV     pc, r14


RestoreSVCStack ROUT
;
; Now restore SVC stack from my private copy
;
; Entry:- r10 = old SVC stack pointer
;
; Exit:-  r13 restored from r10
; Corrupts r0 - r7
;
        SavePSR r7
        MOV     r13, r10          ; old svc_r13
        ADRL    r0, MySVCStack    ; From
        LDR     r1, SVCStackBase  ; To
10
        LDMIA   r0!, {r2-r6}
        STMDB   r1!, {r2-r6}      ; Copy stack from my area
        CMP     r1, r13
        BHI     %b10
;
; Now restore the seven words at the very base where C modules
; have stack chunk information stored.
;
        ADRL    r0, MySVCStack    ; From
        LDR     r6, MySVCStackSize ; Size thereof
        ADD     r0, r0, r6        ; Address of slot at end
        LDMDB   r0!, {r2-r5}      ; The first four words
        LDR     r6, =&000FFFFF    ; Megabyte mask
        BIC     r1, r1, r6        ; Base of stack
        STMIA   r1!, {r2-r5}      ; Copy them
        LDMDB   r0!, {r2-r4}      ; The other three words
        STMIA   r1!, {r2-r4}      ; Copy them
        RestPSR r7,,f
        MOV     pc, r14


SaveEscape ROUT
;
; Save escape state and enable state
;
; Entry:- r12 = private word
;         r13 = SVC stack
;
; Exit:-  r0 - r2, r14 corrupt
;
        [ DebugExit :LOR: FixNDR
        Push    "lr"
        ]
        SWI     OS_ReadEscapeState
        MOVCC   r0, #0            ; we don't have pending escape
        MOVCS   r0, #EscapeSet    ; we do have
        STRB    r0, EscPending
        CheckPointers
        MOVCS   r0, #EscapeClear
        [ DebugExit
        MOV     r14, #"C"
        STR     r14, InPollWimpFn
        STRCSB  r0, EscSem
        CheckPointers
        ]
        SWICS   OS_Byte           ; clear condition if it exists

        MOV     r0, #EscapeChar   ; now disable Escape Key
        MOV     r1, #1
        MOV     r2, #0
        [ DebugExit
        STRB    r2, EscSem
        MOV     r14, #"D"
        STR     r14, InPollWimpFn
        ]
        SWI     OS_Byte
        [       RealEscape        ; Leave old value alone if task can't generate escape
        STRB    r1, EscapeDisable ; and save old value
        CheckPointers
        ]

        [ DebugExit :LOR: FixNDR
        Pull    "pc"
        |
        MOV     pc, r14
        ]

RestoreEscape ROUT
;
; Put back old escape and enable state
;
; Uses r0-r4
;
        MOV     r3, r14
        SavePSR r4
        MOV     r0, #EscapeChar   ; now disable/enable Escape Key
        [       RealEscape
        LDRB    r1, EscapeDisable ; using the old value
        |
        MOV     r1, #1            ; Disable escape during task control
        ]
        MOV     r2, #0
        SWI     OS_Byte
        LDRB    r0, EscPending
        CMP     r0, #EscapeSet
        STRB    r0, EscWasSet
        MOV     r1, #0
        STRB    r1, EscPending
        CheckPointers
        SWIEQ   OS_Byte           ; restore Escape condition
        RestPSR r4,,f
        MOV     pc, r3            ; must preserve flags


ReadExecHandle
;
; Entry:- No conditions
;
; Exit:-  r0 corrupt
;         r1 = os handle
;         Zero set <=> OS has exec file
;
        Push    "r2, lr"
        MOV     r0, #ReadExec
        MOV     r1, #0
        MOV     r2, #0
        SWI     OS_Byte           ; Read and clear exec handle
        TEQ     r1, #0            ; Set flags on whether OS has exec handle
        Pull    "r2, pc"

CloseMyExec
;
; Entry:- ExecHandle = exec handle (0 => none)
;
; Exit:-  ExecHandle=0, exec file closed if was open
;         Errors when closing are ignored
;
        Push    "r0, r1, r2, lr"
        SavePSR r2
        LDRB    r1, ExecHandle
        TEQ     r1, #0
        MOVNE   r0, #0
        STRNEB  r0, ExecHandle    ; Clear my copy
        SWINE   XOS_Find
        RestPSR r2,,f
        Pull    "r0, r1,r2,pc"

ReadSpoolHandle
;
; Entry:- No conditions
;
; Exit:-  r0 corrupt
;         r1 = os handle
;         Zero set <=> OS has exec file
;
        Push    "r2, r14"
        MOV     r0, #ReadSpool
        MOV     r1, #0
        MOV     r2, #0
        SWI     OS_Byte           ; Read and clear spool handle
        TEQ     r1, #0            ; Set flags on whether OS has spool handle
        Pull    "r2, pc"

WriteSpoolHandle
;
; Entry:- r1 = os spool handle
;
; Exit:-  all preserved
;
        Push    "r0-r3, lr"
        SavePSR r3
        MOV     r0, #ReadSpool
        MOV     r2, #0
        SWI     OS_Byte           ; Write spool handle
        RestPSR r3,,f
        Pull    "r0-r3, pc"


CheckDying ROUT
;
; See if application death has been requested
; Not callable from within callback handler
; Only thing outside MyEventV that installs callback handler
; Only requests my call back if there is no outstanding callback
; from the application.
;
; Entry:- r12 = private workspace pointer for this instance
;         r13 = SVC stack pointer
;         r14 = return address
;         Mode SVC
;
; Exit:-  r0 - r4, r14 corrupt
;
        [       DebugWimp
        MOV     pc, lr
        ]
        SavePSR r4
        Push    "r4, r14"
        [ FixNDR :LAND: checkingcallback :LAND: resetingcallback
        LDRB    r0, callbackflag  ; See if user was asking for a callback
        TEQ     r0, #0
        BEQ     %f10
        SWI     OS_SetCallBack
        B       %FT20
10
        ]
        LDR     r0, Moribund
        TEQ     r0, #0
        BEQ     %FT20
        MOV     r0, #CallBackHandler
        addr    r1, Code_CallBackHandler
        MOV     r2, r12
        ADR     r3, CallBackRegs
        SWI     OS_ChangeEnvironment ;Dunno what we do with an error
        [       UseGotCallBack
        LDRB    r0, GotCallBack   ; See if had a handler installed anyway
        TEQ     r0, #0
        ADREQ   r0, OldCallBackHandler
        STMEQIA r0, {r1-r3}
        MOVEQ   r0, #1
        STREQB  r0, GotCallBack   ; Say I have handler set up
        CheckPointers
        |
        addr    r0, Code_CallBackHandler
        TEQ     r0, r1            ; See if previous handler was mine
        ADRNE   r0, OldCallBackHandler
        STMNEIA r0, {r1-r3}       ; Save it if not
        ]
        SWI     OS_SetCallBack    ; And request the call back
20
        Pull    "r4, lr"
        RestPSR r4,,f
        MOV     pc, lr            ; Return


PollWimpFn ROUT
;
; Poll the wimp, restoring the correct function key states before and after
;
; Entry:- r14 = return address
;         r13 = stack pointer
;         r0  = additional mask to determine if null events allowed
;               0 => allowed, 1 => not allowed
;         r2 = time to return
;         r3 = address of poll word (0 => none)
;
; Exit:-  r0 - r4, r14 corrupt
;         whatever is preserved by PollWimp (ugh)
;
        Push    "r0-r4,lr"
;
; First ensure no OS exec handle on entry to the wimp
;
        [ DebugExit
        MOV     r14, #"W"
        STR     r14, InPollWimpFn
        ]

        BL      ReadExecHandle
        BEQ     %f10              ; No OS handle
        Push    r1                ; Save OS handle
        BL      CloseMyExec
        Pull    r1
        STRB    r1, ExecHandle    ; Got new handle
        CheckPointers
10

        [       FixSpool
        BL      ReadSpoolHandle
        STRB    r1, SpoolHandle   ; Save OS handle
        CheckPointers
        ]

        Pull    "r0-r4"

        BL      ReadTaskKeyStates ; First get what task thinks they are
        BL      SetWimpKeyStates  ; Then put back wimp's versions

        BL      PollWimp          ; Then the real work

        BL      ReadWimpKeyStates ; In case they've changed
        BL      SetTaskKeyStates  ; Then put back task's versions

        [       FixSpool
        Push    "r0,r1"
        LDRB    r1, SpoolHandle   ; Restore OS handle
        BL      WriteSpoolHandle
        Pull    "r0,r1"
        ]

        [ DebugExit
        MOV     r14, #"X"
        STR     r14, InPollWimpFn
        ]
        Pull    pc                ; And return (possibly with error)


PollWimp ROUT
;
; Poll the Wimp once.
;
; Entry:- r14 = return address
;         r13 = stack pointer
;         r0  = additional mask to determine if null events allowed
;               also used to enable poll word checking
;         r2 = time to return
;         r3 = address of poll word (0 if none)
;
; Exit:-  r0 - r4, r14 corrupt
;         All other registers preserved
;
        Push    "r0-r3,lr"
        Push    "lr"
10                                ; sometimes we come back here!
        Pull    "lr"              ; grotbag routines expect just lr on stack
        LDMIA   sp, {r0-r3}
        BL      grotpollwimp
        STRVS   r0, [sp]
        Pull    "r0-r3,pc"

grotpollwimp
        Push    "r2, r3,lr"

        LDR     r1, ReceivePending
        TEQ     r1, #0
        BEQ     %f12
        LDR     r1, ReceivedBytes
        TEQ     r1, #0
        BICEQ   r0, r0, #1        ; Don't ignore nulls if more input to get
12
        [       UseFPPoll
        LDR     r4, =&01001832
        |
        LDR     r4, =&00001832
        ]
                                  ; Allow Null, ignore Redraw, 0, 0
                                  ; Ignore pointer movement, allow mouse, 0
                                  ; Allow key, 0, 0, ignore caret loss
                                  ; Ignore gain caret, 0, 0, 0
                                  ; 0, allow message portocols
                                  ;
                                  ; Save fp state (bit 24 set)
        ORR     r4, r4, r0        ; And maybe nulls and pollword too
        [       FPErrorHandling
;
; Now install safety net for FP errors
;
        MOV     r0, #ErrorHandler
        ADRL    r1, Code_FPErrorHandler
        MOV     r2, r12
        ADR     r3, ErrorBuffer
        SWI     OS_ChangeEnvironment ; Dunno what we do with an error
        ADR     r0, PreErrorHandler
        STMIA   r0, {r1-r3}
        ]
;
; recover poll word address and time
;
        Pull    "r2, r3"
        MOV     r5, r2              ; save wait for later

        [       DebugWimp
        BL      FindPages
        Push    "r0"
        [       CheckSum
        BL      FindSum
        Push    "r0"
        ]
        SWI     OS_WriteS
        =       4, 30, "A", 5, 0
        ]
;
; Save OS redirection handles, and write 0 into them
;
        [       FixRedirection
        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_ChangeRedirection
        STRB    r0, CopyOfRedirectInHandle
        STRB    r1, CopyOfRedirectOutHandle
        CheckPointers
        ]
;
; Now do the polling
;
        MOV     r0, r4
        ADR     r1, ScratchBlock
        [       FPErrorHandling
        Push    "r12"             ; Save my r12
        ADR     r2, ErrorRegs+4*10
        LDMIA   r2!, {r10-r12}    ; Set up user r10-r12 in case an error occurs
        LDR     r14, [r2, #8]     ; And user r14
        ]
        [       PollIdleHandling
        MOV     r2, r5
        TEQ     r2, #0
        BNE     %FT12
        SWI     XWimp_Poll
        B       %FT13
12      SWI     XWimp_PollIdle
13
        |
        SWI     XWimp_Poll
        ]

        [       FPErrorHandling
        Pull    "r12"             ; My r12 back
;
; Now restore old error handlers
;
        SavePSR r1
        Push    "r0, r1"          ; Save flags plus wimp result


        MOV     r0, #ErrorHandler
        ADR     r1, PreErrorHandler
        LDMIA   r1, {r1-r3}
        SWI     OS_ChangeEnvironment ; Restore previous handler
        Pull    "r0, lr"
        RestPSR lr,,f              ; Restore flags on exit from Wimp_Poll
        ]
;
; save Wimp_Poll action so we can (eg) wait for a specific event
;
        STR     r0, PollWimpResult
;
; Restore OS redirection handles
;
        [       FixRedirection
        SavePSR lr
        Push    "r0,r1,lr"        ; save psr state
        LDRB    r0, CopyOfRedirectInHandle
        LDRB    r1, CopyOfRedirectOutHandle
        SWI     XOS_ChangeRedirection
        Pull    "r0,r1,lr"
        RestPSR lr,,f
        ]

        [       DebugWimp
        Pull    "r1, r2"          ; r1 = previous checksum, r2 = address
        SavePSR lr
        Push    "r0, lr"          ; Save flags plus wimp result
        [       CheckSum
        MOV     r0, r2
        BL      FindSum           ; See if application space pages corrupt
        TEQ     r0, r1
        BLNE    BadSum
        MOV     r1, r2
        ]
        SWI     OS_WriteS
        =       4, 30, "B", 5, 0
        MOV     r0, r1
        BL      CheckPages        ; See if same pages now available!
        Pull    "r0, lr"
        RestPSR lr,,f             ; Restore flags on exit from Wimp_Poll
        ]

        BVS     Null              ; the safest thing to with an error is ignore it
;
; r0 is wimp return code
;
        SUBS    r0, r0, #User_Message
        BCC     Null              ; Below Send we're not interested
        CMP     r0, #1+User_Message_Acknowledge-User_Message
        ADDCC   pc, pc, r0, LSL # 2 ; Case branch
        B       Null              ; Above Ack they're not defined
        B       ESendHand
        B       ESendRecHand
;
; Ack means one of our messages failed to arrive,
; Can't send NewTask with SendRec, though, cos !Edit only accepts ESend!
;
        B       %f20                    ; just kill the task

ESendRecHand
;
; First check if it's quit
;
        LDR     r0, SMessageAction
        TEQ     r0, #Message_Quit
        BEQ     %f20
;
; Now check it's from the parent
;
        LDR     r2, SMessageMyTask ; Who from
        LDR     r1, ParentTask
        TEQ     r1, r2
        BNE     Null
;
; Now check for DataSave,
; which we may wish to reply to rather than sending Ack
;
        TEQ     r0, #Message_DataSave
        BEQ     %f70
15
;
; This ack should use a different block
;
        LDR     r0, SMessageMyRef
        STR     r0, SMessageYourRef
        MOV     r0, #User_Message_Acknowledge
        ADR     r1, ScratchBlock
        SWI     Wimp_SendMessage  ; Send
        B       %f30
20
        MOV     r0, #1
        STR     r0, Moribund      ; Remember if so
        Pull    pc


ESendHand
;
; First check if it's quit
;
        LDR     r0, SMessageAction
        TEQ     r0, #Message_Quit
        BEQ     %b20
;
; Now check it's from the parent
;
        LDR     r2, SMessageMyTask ; Who from
        LDR     r1, ParentTask
        TEQ     r1, r2
        BNE     Null              ; Ignore if not
;
; Now check for DataSave,
; which we may wish to reply to rather than sending Ack
;
        TEQ     r0, #Message_DataSave
        BEQ     %f70
30
;
; Now we have the message, what shall we do with it?
;
        LDR     r0, SMessageAction
        TEQ     r0, #Message_RAMTransmit
        BEQ     %f80
        LDR     r2, =Input
        TEQ     r0, r2            ; Wimp has character for us?
        BNE     %f50
        ADRL    r2, SMessageDataData
        LDR     r3, SMessageDataSize
        TEQ     r3, #0
        BEQ     Null
        MOV     r1, #0            ; Buffer number
40
        LDRB    r0, [r2], #1
        BL      Insert            ; Put it in the buffer
        SUBS    r3, r3, #1
        BNE     %b40              ; And see if any more
Null
;
; Now see if we've got some data waiting to arrive
;
        LDR     r0, ReceivePending
        TEQ     r0, #0
        BEQ     %f45              ; Branch if not
        LDR     r0, ReceivedBytes
        TEQ     r0, #0
        BNE     %f45              ; Branch if can't cope with it anyway
        MOV     r0, #0
        STR     r0, ReceivePending ; No longer waiting to get data
        LDR     r0, ReceivedRef   ; The ref in the DataSave
        B       %f75              ; Send the message and reenter
45
        LDR     r0, Moribund
        TEQ     r0, #0
        Pull    pc, NE            ; Always exit if trying to die
        LDR     r0, Suspended
        TEQ     r0, #0
        BNE     %b10              ; Loop if suspended
        Pull    pc                ; Finally out we go

50
        LDR     r2, =Morite
        TEQ     r0, r2            ; Is it die?
        BNE     %f60              ; Branch if not
        ASSERT  Morite <> 0
        STR     r0, Moribund      ; Remember if so
        B       abex_exit
60
        LDR     r2, =Suspend      ; Is it suspend?
        TEQ     r0, r2
        STREQ   r0, Suspended     ; Now suspended
        BEQ     %b10              ; Loop until unsuspended
        LDR     r2, =Resume       ; Is it resume?
        EORS    r0, r0, r2
        STREQ   r0, Suspended     ; Cancel if so
        B       Null
70
;
; Handle DataSave
;
        LDR     r0, ReceivePending
        TEQ     r0, #0
        BNE     %b15              ; Ack and ignore if already expecting some
;
; Possibly ought to error this case
;
        LDR     r0, ReceivedBytes ; Have we got anything in the buffer anyway?
        TEQ     r0, #0
        STRNE   r0, ReceivePending ; If so, mark the receive as pending
        LDR     r0, SMessageMyRef
        STRNE   r0, ReceivedRef
        BNE     %b15              ; And Ack
;
; Now send a RAMFetch message in reply
;
75
;
; Entered with r0 suitably set up.
;
        MOV     r1, #Message_RAMFetch
        ADR     r2, RamReceiveArea
        MOV     r3, #?RamReceiveArea
        ADRL    r4, SMessageYourRef
        STMIA   r4, {r0-r3}
        MOV     r0, #28
        STR     r0, ScratchBlock  ; Size of message
        MOV     r0, #User_Message_Recorded
        ADR     r1, ScratchBlock
        LDR     r2, ParentTask    ; To
        SWI     Wimp_SendMessage  ; Send
        B       Null              ; Exit
80
        LDR     r0, ScratchBlock+24 ; Amount of data
        STR     r0, ReceivedBytes
        ADR     r0, RamReceiveArea
        STR     r0, ReceivedPointer
        B       Null


SendOutput ROUT
;
; Send the contents of the output buffer to the parent
;
; Entry:- No conditions
;
; Exit:-  All registers and flags preserved
;
        Push    "r0-r9, r14"
        SavePSR r9
        MOV     r3, #24           ; Size of block
        ADRL    r2, SMessageDataData ; Where to put the stuff
        MOV     r1, #1            ; Buffer number
10
        BL      Extract
        STRCCB  r0, [r2], #1
        CheckPointers
        ADDCC   r3, r3, #1
        BCC     %b10              ; Loop until got all
        SUBS    r8, r3, #24
        BEQ     %f20              ; Exit if not got any
        ADD     r3, r3, #3
        BIC     r3, r3, #3        ; Round up to multiple of four
        MOV     r6, #0            ; No ref
        LDR     r7, =Output       ; What we've got
        LDR     r0, Moribund
        TEQ     r0, #0
        BNE     %f20              ; Don't bother sending if killed anyway
        MOV     r0, #User_Message ; Not Acked at present, will be later
        ADR     r1, ScratchBlock
        STMIA   r1, {r3-r8}       ; Set up the message block
        LDR     r2, ParentTask    ; Who to
        CMP     r2, #0            ; if no parent, throw it on the floor!
        SWINE   XWimp_SendMessage ; Send
20
        RestPSR r9,,f
        Pull    "r0-r9,pc"        ; Return


Insert  ROUT
;
; Routine to insert characters into buffer
;
; Entry:- r0  = character to insert
;         r1  = buffer number (0 keyboard, 1 output)
;         r12 = workspace pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  All registers preserved
;         C set <=> buffer was full
;
        Push    "r0-r3,lr"

      [ CheckBufferPointers
        BL      checkbufferpointers
      ]

        TEQ     r1, #0            ; Only test Esc on keyboard buffer
        TEQEQ   r0, #Esc          ; Is it Esc?
        LDREQB  r2, EscapeDisable ; Does appl want escape condition if so?
        TEQEQ   r2, #0
        MOVEQ   r2, #EscapeSet
        STREQB  r2, EscPending    ; Mark escape condition to be generated if so
        CheckPointers
        BEQ     %f10
        LDRB    r2, EscPending
        TEQ     r2, #0
        BNE     %f10              ; Don't buffer if application has escape
        ADR     r2, KeyBufferHead
        LDR     r2, [r2, r1, LSL #2]
        ADR     r3, KeyBufferTail
        LDR     r3, [r3, r1, LSL #2] ; Get pointers for correct buffer
        TEQ     r1, #0
        MOVEQ   r14, #?KeyBuffer
        MOVNE   r14, #?OBuffer
        SUBS    r2, r2, r3
        ADDLT   r2, r2, r14
        CMP     r2, #1
        BEQ     %f20              ; Branch if full, with C set
        STRB    r0, [r3], #1
        CheckPointers
        ADR     r2, KeyBufferLast
        LDR     r2, [r2, r1, LSL #2] ; See if off end
        TEQ     r3, r2
        ADREQ   r3, KeyBufferFirst
        LDREQ   r3, [r3, r1, LSL #2] ; And wrap if so
        ADR     r2, KeyBufferTail
        STR     r3, [r2, r1, LSL #2]
10
        MOVS    r0, #4,2          ; Clear carry
20
        Pull    "r0-r3,pc"


GetInput ROUT
;
; Exit:- r0 = character
;        Carry clear <=> got character
;
        Push    "r1-r2,lr"

        MOV     r0, #-1
        MOV     r1, #-1
        SWI     XOS_ChangeRedirection       ; find out where to get char from
        TEQ     r0, #0
        BEQ     %f05

        MOV     r1, r0
        SWI     XOS_BGet
        BLVS    urk_closeredirection
        Pull    "r1-r2,pc",VS
        Pull    "r1-r2,pc",CC           ; got character OK

        Push    "r1"                    ; CS <=> EOF
        MOV     r0, #0
        MOV     r1, #-1
        SWI     XOS_ChangeRedirection       ; turn off input redirection
        Pull    "r1"

        MOV     r0, #0
        SWI     XOS_Find
        Pull    "r1-r2,pc",VS           ; return errors closing stream
                                        ; else drop through and read ordinary char
05      BL      ReadExecHandle
        BEQ     %f10              ; No OS handle
        Push    r1                ; Save OS handle
        BL      CloseMyExec
        Pull    r1
        STRB    r1, ExecHandle    ; Got new handle
        CheckPointers
10
        LDRB    r1, ExecHandle
        TEQ     r1, #0            ; See if got non-zero exec handle
        BEQ     %f20              ; Branch if not
        SWI     XOS_BGet          ; Try for byte from filing system
        BLVS    CloseMyExec
        Pull    "r1-r2, pc",VS
        BCC     %f30              ; Branch if got one
        BL      CloseMyExec       ; File exhausted, close it
20
        BL      GetKbInput
30
        Pull    "r1-r2, pc"       ; Exit

; ..............................................................................

; Close input and output redirection files, and write handles to 0
; All registers and flags preserved

urk_closeredirection
        Push    "r0-r3,lr"
        SavePSR r3

        MOV     r0, #0
        MOV     r1, #0
        SWI     XOS_ChangeRedirection

        MOV     r2, r1
        MOVS    r1, r0
        MOVNE   r0, #0
        SWINE   XOS_Find
        MOVS    r1, r2
        MOVNE   r0, #0
        SWINE   XOS_Find

        RestPSR r3,,f
        Pull    "r0-r3,pc"

; ............................................................................

GetKbInput ROUT
;
; Routine to get keyboard input
;
; Entry:- r12 = workspace pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  r0 = character found
;         r1 corrupt
;         Carry set <=> buffer empty
;         All other registers preserved
;
        Push    "r14"
GetKbInput0
        MOV     r1, #0
        LDR     r14, ExpPointer   ; See if something buffered up
        ADDS    r14, r14, #0      ; replaces TEQ r14, #0 - this one clears CNV as well as set/clear Z
        ADRNE   r0, ExpBuffer
        SUBNE   r14, r14, #1
        LDRNEB  r0, [r0, r14]     ; Get it if so
        STRNE   r14, ExpPointer   ; Decrement pointer
        Pull    pc, NE            ; Return got (carry will be clear from ADDS earlier)
        BL      Extract           ; Try ordinary buffer first
        BCC     %f10              ; Branch if got one
        LDR     r0, ReceivedBytes
        CMP     r0, #0
        Pull    pc, EQ            ; Return if none (note carry set by CMP)
        SUB     r0, r0, #1
        STR     r0, ReceivedBytes
        LDR     r14, ReceivedPointer
        LDRB    r0, [r14], #1
        STR     r14, ReceivedPointer
10
        LDRB    r14, key_fnflag
        CMP     r14, #0
        BNE     %f15
        ADDS    r0, r0, #0        ; Compare with 0 & clear carry
        MOVEQ   r14, #1
        STREQB  r14, key_fnflag
        BEQ     GetKbInput0
        Pull    "pc"
;
; Now see if function key expansion of any sort required
;
15
        MOVS    r14, #0,2         ; barrel shifting to clear carry too
        STRB    r14, key_fnflag
        TST     r0, #&80          ; Fn key bit
        Pull    "pc", EQ          ; Return got if not (carry clear)
        Push    "r1-r4"
        MOV     r4, r0
        AND     r3, r4, #&70      ; Get section bits
        EOR     r3, r3, #&40      ; Get into right order
        MOV     r3, r3, LSR #4    ; And into bottom bits
        ADD     r0, r3, #ReadFnKey; The controlling OSByte
        MOV     r1, #0
        MOV     r2, #&ff
        SWI     OS_Byte           ; Read it
        TEQ     r1, #0
        Pull    "r1-r4, r14", EQ
        BEQ     GetKbInput        ; Ignore on zero
        TEQ     r1, #1
        BEQ     %f40
        TEQ     r1, #2
        BNE     %f30              ; Branch if not double byte
        STRB    r4, ExpBuffer     ; Save the code
        CheckPointers
        MOV     r1, #1
        STR     r1, ExpPointer
        MOVS    r0, #0,2          ; Returning 0, barrel shifting to clear carry too
        Pull    "r1-r4, pc"
30
        AND     r0, r4, #&f       ; Code modulo 16
        ADDS    r0, r0, r1        ; Add in base (clear carry)
        Pull    "r1-r4, pc"       ; Exit
40
;
; Set up for soft key expansion
;
FnKeyNameLen * 8
;
; First copy KeyDollar to a place in RAM
;
        ADRL    r0, SoftKeyDollar
        LDR     r1, KeyDollar
        MOV     r2, #0
        STMIA   r0, {r1, r2}      ; Copy string Key$, with zero termination
        MOV     r2, #4
        AND     r4, r4, #&f       ; Code modulo 16
        CMP     r4, #10           ; Greater than or equal to 10?
        MOVCS   r3, #"1"
        STRCSB  r3, [r0, r2]
        ADDCS   r2, r2, #1
        SUBCS   r4, r4, #10       ; Units
        ADD     r4, r4, #"0"      ; Convert to digit
        STRB    r4, [r0, r2]      ; And save
        CheckPointers
        ADR     r1, ScratchBlock  ; Where to put result
        MOV     r2, #256          ; Maximum length of result
        MOV     r3, #0
        MOV     r4, #3            ; Expanded string please
        SWI     XOS_ReadVarVal
        BVS     %f60              ; Branch if no string
        TEQ     r2, #0
        BEQ     %f60              ; or if zero length
        STR     r2, ExpPointer
;
; Now copy the string to the right place, reversing on the way
;
        ADR     r0, ExpBuffer
        MOV     r3, #0
50
;
; Does ReadVarVal preserve r1? Yes.
;
        SUBS    r2, r2, #1
        LDRB    r4, [r1, r3]
        STRB    r4, [r0, r2]
        CheckPointers
        ADD     r3, r3, #1
        BNE     %b50              ; Loop until all copied
60
        Pull    "r1-r4, r14"
        B       GetKbInput        ; And look again
KeyDollar
        =       "Key$"

Extract ROUT
;
; Routine to extract characters from keyboard buffer
;
; Entry:- r1  = Buffer number
;         r12 = workspace pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  r0 = character found
;         Carry set <=> buffer empty
;         All other registers preserved
;
        Push    "r1-r3,lr"

      [ CheckBufferPointers
        BL      checkbufferpointers
      ]

        ADR     r2, KeyBufferHead
        LDR     r2, [r2, r1, LSL #2]
        ADR     r3, KeyBufferTail
        LDR     r3, [r3, r1, LSL #2]
        CMP     r2, r3
        BEQ     %f10              ; Branch if empty buffer (note C set if so)
        LDRB    r0, [r2], #1      ; Get the character
        ADR     r3, KeyBufferLast
        LDR     r3, [r3, r1, LSL #2] ; See if off end
        TEQ     r3, r2
        ADREQ   r2, KeyBufferFirst; And wrap if so
        LDREQ   r2, [r2, r1, LSL #2]
        ADR     r3, KeyBufferHead
        STR     r2, [r3, r1, LSL #2]
        MOVS    r2, #4,2          ; Clear the carry by barrel shifting
10
        Pull    "r1-r3,pc"

      [ CheckBufferPointers
checkbufferpointers
        Push    "r2,r3,r4,lr"
        SavePSR r4
        CMP     r1, #1
        BHI     knacked
        ADRNEL  r2, KeyBuffer+?KeyBuffer
        ADREQL  r2, OBuffer+?OBuffer
        ADR     r3, KeyBufferLast
        LDR     r3, [r3, r1, LSL #2]
        CMP     r3, r2
        BNE     knacked
        RestPSR r4,,f
        Pull    "r2,r3,r4,pc"
knacked
        MOV     r14, #1
        STR     r14, PassOnVectors      ; just in case!
        ADR     r0, knackedstring
        SWI     XOS_Write0
        RestPSR r4,,f
        Pull    "r2,r3,r4,lr"           ; get registers back
        STR     r14, Debug_r14          ; keep this!
        MOV     r0, #0
        LDR     r0, [r0, #-4]           ; force address exception
knackedstring
        DCB     4,4,4,4,4,4,4,4,4,4,4,4,"Knackered buffer end pointer!", 0
        ALIGN
      ]

Clear   ROUT
;
; Routine to clear the keyboard buffer
;
; Entry:- r1  = Buffer number
;         r12 = workspace pointer
;         r13 = stack pointer
;         r14 = return address
;
; Exit:-  All registers preserved
;
        Push    "r0,r2"
        ADR     r0, KeyBufferFirst
        LDR     r0, [r0, r1, LSL #2]
        ADR     r2, KeyBufferHead
        STR     r0, [r2, r1, LSL #2]
        ADR     r2, KeyBufferTail
        STR     r0, [r2, r1, LSL #2]
        Pull    "r0,r2"
        MOV     pc, r14


FindOwner ROUT
;
; Find which instance owns the vectors
;
; Entry:- r12 = global workspace pointer
;         r14 = return address
;
; Exit:-  r12 = correct workspace pointer for vector claimant
;             = 0 if none found
;         All other registers and flags preserved
;
        Push    "r0,r1,lr"
        SavePSR r1
        LDR     r12, FirstWord    ; Point to a workspace
10
        TEQ     r12, #0
        BEQ     %FT20             ; Return if nobody got em
        [       FixDomain
        BL      CheckDomain
        |
        LDR     r0, PassOnVectors
        TEQ     r0, #0
        ]
        LDRNE   r12, NextBlock    ; Not got em - try the next block
        BNE     %b10              ; Loop
20
        RestPSR r1,,f
        Pull    "r0,r1,pc"        ; Return

        [       FixDomain
CheckDomain     ROUT
;
; Entry:- r12 = private word pointer
;
; Exit:-  EQ => we are on the vectors, NE => we are not
;
        Push    "r0, lr"

        LDR     r0, WimpDomain
        LDR     r0, [r0]
        LDR     r14, MyDomain
        TEQ     r0, r14
        LDREQ   r0, PassOnVectors
        TEQEQ   r0, #0

        Pull    "r0, pc"
        ]

ReadTaskKeyStates ROUT
;
; Entry:- r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r3, r14"
        ADR     r3, TaskFnKeyStates
        BL      ReadKeyStates
        Pull    "r3, pc"


SetTaskKeyStates ROUT
;
; Entry:- r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r3, r14"
        ADR     r3, TaskFnKeyStates
        BL      SetKeyStates
        Pull    "r3, pc"


ReadWimpKeyStates ROUT
;
; Entry:- r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r3, r14"
        ADR     r3, WimpFnKeyStates
        BL      ReadKeyStates
        Pull    "r3, pc"


SetWimpKeyStates ROUT
;
; Entry:- r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r3, r14"
        ADR     r3, WimpFnKeyStates
        BL      SetKeyStates
        Pull    "r3, pc"


ReadKeyStates ROUT
;
; Entry:- r3 points to save area
;         r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r0-r5, r14"
        SavePSR r5
        MOV     r4, #7
10
        ADD     r0, r4, #ReadFnKey
        MOV     r1, #0
        MOV     r2, #&ff
        SWI     OS_Byte
        STRB    r1, [r3, r4]
        CheckPointers
        SUBS    r4, r4, #1
        BCS     %b10              ; Loop until read all eight
        RestPSR r5,,f
        Pull    "r0-r5, pc"


SetKeyStates ROUT
;
; Entry:- r3 points to save area
;         r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return address
; Entered in user mode
;
; Exit:-  All registers and flags preserved
;
        Push    "r0-r5, r14"
        SavePSR r5
        MOV     r4, #7
10
        ADD     r0, r4, #ReadFnKey
        LDRB    r1, [r3, r4]
        MOV     r2, #0
        SWI     OS_Byte
        SUBS    r4, r4, #1
        BCS     %b10              ; Loop until set all eight
        RestPSR r5,,f
        Pull    "r0-r5, pc"
        LTORG
        [       DebugWimp
FindPages ROUT
        Push    "r1, lr"
        MOV     r0, #&8000        ; Start of application
        MOV     r1, r0
10      ADD     r1, r1, #&8000    ; Up a page
        SWI     XOS_ValidateAddress
        BCC     %b10              ; Loop until fault
        SUB     r0, r1, #&8000    ; Address of last valid page
        Pull    "r1, pc"

CheckPages ROUT
        Push    "r1, lr"
        MOV     r1, r0            ; End address
        MOV     r0, #&8000        ; Start of application
        SWI     XOS_ValidateAddress ; See if still all there
        BCS     %f10              ; Branch if not
        ADD     r1, r1, #&8000    ; Up a page
        SWI     XOS_ValidateAddress ; See if it's got bigger
        Pull    "r1, pc", CS      ; Return if not
;
; Oh dear, address range expanded
;
        SWI     XOS_WriteS
        =       4,4,4,4,4,4,4,4,4,30,"Address range unexpectedly expanded",0
        B       .
10      SWI     XOS_WriteS
        =       4,4,4,4,4,4,4,4,4,30,"Address range unexpectedly contracted",0
        B       .
        ]
        [       CheckSum


FindSum ROUT
;
; Entry:- r0  = Highest valid address + 1
;         r12 = private workspace pointer
;         r13 = stack pointer
;         r14 = return link
;
; Exit:-  r0  = Checksum
;         All other registers preserved
;
        Push    "r1, r2, r3, lr"
        SavePSR r3
        MOV     r1, #0
10      LDR     r2, [r0, #-4]!
        ADD     r1, r1, r2
        CMP     r0, #&8000
        BHI     %b10              ; Loop until all done
        MOV     r0, r1
        RestPSR r3,,f
        Pull    "r1, r2, r3, pc"
BadSum  Push    "lr"
        SWI     OS_WriteS
        =       4,4,4,4,4,4,4,4,4,30,"Check sum failure after Wimp_Poll", 0
        Pull    "pc"
        ]


      [ debug
        InsertNDRDebugRoutines
      ]

; ---- Internationalisation support routine -----------------------------------

message_filename
        DCB     "Resources:$.Resources.TaskWindow.Messages", 0
        ALIGN

CopyError
        STMDB   sp!, {r0-r7,lr}
        SUB     sp, sp, #16
        MOV     r0, sp
        ADR     r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        BVS     %FT99
        LDR     r0, [sp, #16]
        MOV     r1, sp
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        STR     r0, [sp, #16]
        MOV     r0, sp
        SWI     XMessageTrans_CloseFile
99      STRVS   r0, [sp, #16]
        ADD     sp, sp, #16
        SavePSR r0,VC
        ORRVC   r0, r0, #V_bit
        RestPSR r0,VC,f
        LDMIA   sp!, {r0-r7,pc}

; -----------------------------------------------------------------------------

Code_ModuleEnd
Code_ModuleSize * . -Module_BaseAddr


; ---- RMA Workspace ----------------------------------------------------------


; Global Workspace (private word -> global workspace -> chain of task blocks)

                       ^    0, r12

FirstWord              Word       ; head of chain of task blocks
MOS_EnvString          Word       ; MOS environment string
MOS_EnvTime            Word       ; MOS environment string
MyGetEnv               Word 2     ; space for RAM code
MyGetEnv_CodeAddr      Word       ; must follow MyGetEnv
MOS_GetEnv             Word       ; previous OS_GetEnv handler
MyWriteEnv             Word 2     ; space for RAM code
MyWriteEnv_CodeAddr    Word       ; must follow MyWriteEnv
MOS_WriteEnv           Word       ; previous OS_WriteEnv handler
SvcTable               Word       ; address of Kernel SWI despatch table
 [ NoARMv6 :LAND: SupportARMv6
PlatFeatures           Word       ; OS_PlatformFeatures 0 flags
 ]
GlobalWorkSpaceSize    *    :INDEX:@


; Task Block Workspace

                       ^    0, r12

NextBlock              Word       ; Pointer to next piece of RMA
TaskEscape             Byte       ; The state of escape character in the outside world
EscapeDisable          Byte       ; The state of escape disable within the task
                                  ; Normally zero
EscPending             Byte
EscWasSet              Byte

TaskAborted            Byte
        [       UseGotCallBack
GotCallBack            Byte
        ]
        [       UseInCallBack
InCallBack             Byte
        ]
        [       FixNDR
callbackflag           Byte
        ]

        [       FixRedirection
CopyOfRedirectInHandle Byte       ; OS redirection handles
CopyOfRedirectOutHandle Byte
        |
                       Byte
                       Byte
        ]
  [ DebugExit
EscSem                 Byte
EscRestoreFlag         Byte
  ]

controlcounter         Byte
; ECN
; Word align OscliTime for dodgy progs which rely on MOS_EnvTime being
; word aligned.
                       WHILE ((:INDEX: @) :MOD: 4) <> 0
                       #    1
                       WEND
OscliTime              Byte 5

dummy                  Byte 2
Debug_r14              Word       ; saved by checkbufferpointers
Debug_Word             Word
Debug_InOut            Byte

                       WHILE ((:INDEX: @) :MOD: 16) <> 0
                       #    1
                       WEND

        [       FPErrorHandling
Pad                    Word
        ]
MorePad                Word
WimpFnKeyStates        Word 2     ; 8 bytes for fx 221 - 228 for wimp
TaskFnKeyStates        Word 2     ; 8 bytes for fx 221 - 228 for task
ExpPointer             Word       ; Non zero => something in buffer
KeyBufferHead          Word
OBufferHead            Word
KeyBufferTail          Word
OBufferTail            Word
KeyBufferFirst         Word
OBufferFirst           Word
KeyBufferLast          Word
OBufferLast            Word

ExecHandle             Byte
SpoolHandle            Byte
key_fnflag             Byte
                       Byte

OldErrorHandler        Word 3
        [       FPErrorHandling
PreErrorHandler        Word 3
        ]
OldExitHandler         Word 3
OldCallBackHandler     Word 3

ErrorBuffer            Word 0
ErrorBufferPC          Word
ErrorBufferNumber      Word
ErrorBufferMsg         Word 64
        [       FPErrorHandling
ErrorRegs              Word 17    ; Where to put user registers for error (also temp copy of CallBackRegs)
        ]
ExpBuffer              Word 64    ; Where to put soft key expansions
VecSaveRegs            Word 17    ; somewhere to save on vector intercept (17th word for 32-bit systems)

MySVCStackSize         Word       ; How big the SVC stack is
        [       FPErrorHandling
SVCStackLimit          Word 4     ; Current end
        ]
ScratchBlock           Word 64    ; 256 byte block of scratch workspace
SMessageSize           *    ScratchBlock
SMessageMyTask         *    ScratchBlock+4
SMessageMyRef          *    ScratchBlock+8
SMessageYourRef        *    ScratchBlock+12
SMessageAction         *    ScratchBlock+16
SMessageData           *    ScratchBlock+20
SMessageDataSize       *    SMessageData
SMessageDataData       *    SMessageData+4
MyVecStack             Word 32    ; temp stack used during vector interception
MyStackSize            *    &80
CommandStack           Word 32    ; temp stack used during cli stuff
CallBackRegs           Word 17    ; Area in which to save the registers (32-bit OS stores R0-R15,CPSR)
GotVectors             *    @
GotRdchV               Word
GotWrchV               Word
GotUpCallV             Word
GotEventV              Word
GotByteV               Word
GotCnpV                Word
NumVectors             *    (@-GotVectors)/4 ; The number of vectors
SVCStackBase           Word       ; Where it starts
  [ DebugExit
InPollWimpFn           Word
  ]
VSyncCount             Word
  [ NiceNess
Nice                   Word
  ]
OutputCount            Word
GlobalWS               Word       ; Address of our global workspace block
MyParameters           Word
SoftKeyDollar          Word 2     ; Where to put Key$n

ParentTask             Word       ; Who called us
ParentTxt              Word       ; Their txt
ChildTask              Word       ; Our own id, to tell if messages to us.
PassOnVectors          Word
        [       FixDomain
MyDomain               Word
WimpDomain             Word
        ]
                       WHILE ((:INDEX: @) :MOD: 16) <> 0
                       #    4
                       WEND
ReadLineBuffer         Word 257   ; changed for Ursula (was 65)
InkeyCount             Word
Moribund               Word       ; Task to be killed at some appropriate time
Suspended              Word       ; Task inactive at the moment, waiting
                                  ; for resume or kill
ReceivedBytes          Word       ; Number of bytes in the receive area
ReceivedPointer        Word       ; Pointer to first byte
ReceivePending         Word       ; True <=> arcedit wants to send us more
ReceivedRef            Word       ; The your ref in the last datasave
ReqDie                 Word
PollWord               Word       ; 0 => not blocked at the moment
PollWimpResult         Word       ; latest result from PollWimpFn
OscliBuffer            Word 1     ; Ptr to (long) cmd line
LastWord               Word 0     ; unused - a placeholder for allocating space
                       WHILE ((:INDEX: @) :MOD: 16) <> 0
                       #    4
                       WEND
                       ; NOTE: RamReceiveArea must be the symbol with the memory allocation
                       ; so that ?RamReceiveArea works
MessageBlock           Word 0     ; share with the next buffer
WimpTaskBuffer         Word 0     ; share with the next buffer
RamReceiveArea         Word 256+4 ; 4*256+16 byte selection reception area
                                  ; (need space for WimpTaskBuffer)
                                  ; 64 for receive buffer and message block,
                                  ; 256 for the wimptaskbuffer,
                                  ; + 12 for the module title and space
                                  ; prepended to the CLI
ParameterBuffer        Word 256   ; 1024 byte buffer for storing parameters
KeyBuffer              Byte 256   ; 256 key input buffer
OBuffer                Byte 232   ; 232 character output buffer
; ECN
; Osclibuffer now a ptr to the buffer
                       WHILE ((:INDEX: @) :MOD: 32) <> 0
                       #    4
                       WEND
HeapSize               *    :INDEX: @

MessageSize            *    MessageBlock
MessageMyTask          *    MessageBlock+4
MessageMyRef           *    MessageBlock+8
MessageYourRef         *    MessageBlock+12
MessageAction          *    MessageBlock+16
MessageData            *    MessageBlock+20
MessageDataSize        *    MessageData
MessageDataData        *    MessageData+4

;
; Now areas sized dynamically
;

MySVCStack             Word 0     ; Open array

key_command     *       ParameterBuffer+0
key_wimpslot    *       ParameterBuffer+4
key_name        *       ParameterBuffer+8
key_display     *       ParameterBuffer+12
key_quit        *       ParameterBuffer+16
key_ctrl        *       ParameterBuffer+20
key_task        *       ParameterBuffer+24
key_txt         *       ParameterBuffer+28
key_nice        *       ParameterBuffer+32

        END
