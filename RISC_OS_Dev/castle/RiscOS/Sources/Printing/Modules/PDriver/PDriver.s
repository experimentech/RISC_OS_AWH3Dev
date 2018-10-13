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
; > PDriver

; ********************
; *** CHANGES LIST ***
; ********************

; 23-Jul-90 0.00 GJS Created concept of PDriver sharer module.
; 24-Jul-90      GJS Created first sources.
; 13-Aug-90 3.00 GJS So good it deserves 3.00 status.
; 18-Sep-90 3.01 GJS Bug fix: Abort job (error returned accidentally)
; 14-Jan-91      OSS Added word "sharer" to help text.
; 13-Feb-91 3.05 OSS Added PDriver_DeclareFont.
; 04-Apr-91 3.06 OSS Internationalised, some minor bug fixes.
; 19-Apr-91 3.08 OSS Fixed some internationalisation bugs.
; 06-May-91      DDV Sorted out sources reformatting as required.
; 06-May-91      DDV Added better errors for declaring printers.
; 06-May-91      DDV Check for no pending jobs when killing module.
; 06-May-91      DDV Sorted out registering of the device on a callback rather than service call.
; 06-May-91      DDV Inserted a new SWI PDriver_RemovePrinter.
; 07-May-91      DDV New internationalisation code.
; 08-May-91      DDV Added returning of previous printer in R0.
; 08-May-91 3.09 DDV Bug fix: ClearJob called wrong routine to abandon call the device.
; 09-May-91      DDV PDriver_<foo>ForPrinter now take parameters in r8 not r7.
; 16-May-91      DDV Bug fix: -1 on SelectDriver does not corrupt selected device.
; 16-May-91 3.10 DDV Bug fix: r8 not being used on one of the pass through calls.
; 24-May-91 3.11 DDV Added PDriver_MiscOp and MiscOpForDriver.
; 28-May-91 3.12 DDV Fixed the broken Deregistering of PDriver modules.
; 13-Jun-91      DDV PDriver_<foo>ForDriver SWIs removed and changed some names.
; 13-Jun-91 3.13 DDV Introduced PDriver_MiscOpForDriver.
; 15-Jun-91 3.14 DDV Decided did not like 13 as a version number so upped it a bit.
; 27-Jun-91 3.15 DDV Added PDumper_SetDriver SWI.
; 22-Jul-91 3.16 DDV Added Service_PDriverChanged.
; -------------------------------- RISC OS 3.00 release version ---------------------------
; 10-Dec-91 3.17 SMC Shortened message tokens
; 30-Mar-92 3.18 DDV Bug fix: Select job failing to report the correct error.
; 13-Oct-93 3.19 NK  Added standalone flag so that it can install its messages- This is
;                    necessary on Medusa platforms as PDrivers directory is not in ROM.
; -------------------------------- RISC OS 3.50 release version ---------------------------
; 12-Sep-94      AMcC Look for Messages file in Locale directory
; 13-Sep-94 3.21 MJS changes for JPEG plot support
; 30-Sep-94 3.23 MJS change in hdr.PDriver; step version up to agree with SrcFiler
; 09-Jan-95 3.24 MJS fix PDriver_EnumerateDrivers (MED-04281)
; 20-Feb-95 3.25 MJS fix R9 corruption in several places
; 07-May-97 3.26 JRC Added InUse and NoEsc error tokens.
; 13-Aug-97 3.27 AR  Added Command SWI
; 12-May-04      JWB Compile with objasm

                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:Services
                GET     hdr:FSNumbers
                GET     hdr:ModHand
                GET     hdr:NewErrors
                GET     hdr:MsgTrans
                GET     hdr:Proc
                GET     hdr:HostFS
                GET     hdr:NDRDebug
                GET     hdr:DDVMacros
                GET     hdr:ResourceFS

                GET     VersionASM

                GBLL    debug
                GBLL    hostvdu
                GBLS    PrivMessages
 [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL    {FALSE}
 ]

debug           SETL    {FALSE}
hostvdu         SETL    {FALSE}
PrivMessages    SETS    ""                      ; no private messages
debug_file	SETS	"<PDrvDebug>"

ChangeJob       SETD    {FALSE}                 ; job selection/creation.
ClearJob        SETD    {FALSE}                 ; clearing of job handles
CurrentJob      SETD    {FALSE}                 ; returning the current job handle
Enumerate       SETD    {FALSE}                 ; enumerating the current jobs
PassToDriver    SETD    {FALSE}                 ; pass to the specified driver
PassToJobR0     SETD    {FALSE}                 ; passing to job in r0
Reset           SETD    {FALSE}                 ; reseting the job list
DeclareDriver   SETD    {FALSE}                 ; declaring the printer
RemoveDriver    SETD    {FALSE}                 ; remove printer
SelectDriver    SETD    {FALSE}                 ; selecting a device
ToCurrent       SETD    {TRUE}                  ; redirect to current job
SWI             SETD    {FALSE}                 ; decoding of SWIs within the system
xx              SETD    {FALSE}                 ; misc stuff
fnt             SETD    {TRUE}                  ; FontSWI
calljobR10      SETD    {FALSE}                 ; call job with handle in R10
calldriverR10   SETD    {TRUE}                  ; calling driver with handle in R10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                        ^ 0
next_printer            # 4                     ; -> next block in list, =0 if none
branch_code             # 4                     ; -> branch routine
private_word            # 4                     ;  = private word
printer_number          # 4                     ;  = prrinter number
printer_end             * :INDEX: @

                        ^ 0, wp
SharedMessages          # 4                     ; -> shared block
MessagesOpen            # 4                     ;  = messages file open word
MessagesBlock           # 16                    ;  = messages block

printer_list            # 4                     ; -> head of printer list
current_job             # 4                     ;  = current job handle
current_printer         # 4                     ;  = current printer
job_descriptions        # 4*256                 ;  = one word pointer for each of the 256 job handle
old_job                 # 4                     ;  = previously selected job
flags                   # 4                     ;  = global flags word
error_buffer		# 256

workspace_end           * :INDEX: @

f_CallBackPending       * 1:SHL:0               ; set => callback pending should be removed.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Module header.
;
                AREA    |PDriver$$code|, CODE, READONLY

module_start    & 0
                & Initialisation -module_start                  ; init code
                & Finalisation -module_start                    ; finalisation
                & Service -module_start                         ; service code

                & Title -module_start                           ; title string offset
                & Help -module_start                            ; help string offset
                & 0

                & PrintSWI * Module_SWIChunkSize + Module_SWIApplicationBase
                & SWIHandler -module_start                      ; handler for SWIs
                & SWITable -module_start                        ; SWI decoding table
                & 0
  [ :LNOT: No32bitCode
                & 0
                & Flags -module_start
  ]

Help            = "Printer sharer", 9, "$Module_HelpVersion"
              [ debug
                = " Development version"
              ]
                = 0
                ALIGN

  [ :LNOT: No32bitCode
Flags           DCD ModuleFlag_32bit
  ]

Title
SWITable        = "PDriver", 0
                = "Info", 0
                = "SetInfo", 0
                = "CheckFeatures", 0
                = "PageSize", 0
                = "SetPageSize", 0
                = "SelectJob", 0
                = "CurrentJob", 0
                = "FontSWI", 0
                = "EndJob", 0
                = "AbortJob", 0
                = "Reset", 0
                = "GiveRectangle", 0
                = "DrawPage", 0
                = "GetRectangle", 0
                = "CancelJob", 0
                = "ScreenDump", 0
                = "EnumerateJobs", 0
                = "SetPrinter", 0
                = "CancelJobWithError", 0
                = "SelectIllustration", 0
                = "InsertIllustration", 0
                = "DeclareFont", 0
                = "DeclareDriver", 0
                = "RemoveDriver", 0
                = "SelectDriver", 0
                = "EnumerateDrivers", 0
                = "MiscOp", 0
                = "MiscOpForDriver", 0
                = "SetDriver", 0
                = "JPEGSWI", 0
                = "Command", 0
                = 0
                ALIGN

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle the despatch of SWIs within the module.

SWIHandler      ROUT

                LDR     wp, [wp]                                ; -> workspace

                Debug	ToCurrent, "PDriver SWI", r11, lr

                CMP     r11, #(%90 -%80)/4
                ADDCC   pc, pc, r11, LSL #2
                B       %90
80
                B       PassToDriver                            ; PDriver_Info
                B       PassToDriver                            ; PDriver_SetInfo
                B       PassToDriver                            ; PDriver_CheckFeatures
                B       PassToDriver                            ; PDriver_PageSize
                B       PassToDriver                            ; PDriver_SetPageSize
                B       ChangeJob                               ; PDriver_SelectJob
                B       CurrentJob                              ; PDriver_CurrentJob
                B       PassToCurrent                           ; PDriver_FontSWI
                B       ClearJob                                ; PDriver_EndJob
                B       ClearJob                                ; PDriver_AbortJob
                B       Reset                                   ; PDriver_Reset
                B       PassToCurrent                           ; PDriver_GiveRectangle
                B       PassToCurrent                           ; PDriver_DrawPage
                B       PassToCurrent                           ; PDriver_GetRectangle
                B       PassToR0Job                             ; PDriver_CancelJob
                B       PassToDriver                            ; PDriver_ScreenDump
                B       EnumerateJobs                           ; PDriver_EnumerateJobs
                B       PassToDriver                            ; PDriver_SetPrinter
                B       PassToR0Job                             ; PDriver_CancelJobWithError
                B       ChangeJob                               ; PDriver_SelectIllustration
                B       PassToCurrent                           ; PDriver_InsertIllustration
                B       PassToCurrent                           ; PDriver_DeclareFont
                B       DeclareDriver                           ; PDriver_DeclareDriver
                B       RemoveDriver                            ; PDriver_RemoveDriver
                B       SelectDriver                            ; PDriver_SelectDriver
                B       EnumDrivers                             ; PDriver_EnumerateDrivers
                B       MiscOp                                  ; PDriver_MiscOp
                B       MiscOpForDriver                         ; PDriver_MiscOpForDriver
                B       PassToDriver                            ; PDriver_SetDriver
                B       PassToCurrent                           ; PDriver_JPEGSWI
                B	PassToDriver				; PDriver_Command
90
                ADR     r0, ErrorBlock_ModuleBadSWI
                ADDR    r1, Title                               ; -> module title
                B       LookupError                             ; -> r0 -> error block, V set

                MakeErrorBlock ModuleBadSWI

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle claiming of workspace and other stuff.
;

Initialisation  ROUT

                Push    "lr"

                LDR     r2, [wp]
                TEQ     r2, #0                                  ; do we already have workspace
                BNE     %10

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace_end                      ; amount required
                SWI     XOS_Module
                Pull    "pc", VS                                ; return it it went wrong

                STR     r2, [wp]
10
                MOV     wp, r2                                  ; -> workspace

                MOV     r0, #0
                LDR     r1, =workspace_end/4                    ; amount of workspace to zap
20
                STR     r0, [r2], #4
                SUBS    r1, r1, #1
                BNE     %20                                     ; loop until its all done

                ADR     r0, callback
                MOV     r1, wp                                  ; -> workspace
                SWI     XOS_AddCallBack
                LDRVC   r0, flags
                ORRVC   r0, r0, #f_CallBackPending
                STRVC   r0, flags                               ; mark as a callback is pending

        [ standalone
; NK, 13-10-93 PDriver now installs its messages file
; SB, 25-11-98 Only if V clear - otherwise module disappears and takes registered block with it!
        ADRVCL  R0,resourcefsfiles
        SWIVC   XResourceFS_RegisterFiles   ; ignore errors
        ]

                Pull    "pc"                                    ; return should all be OK

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle the callback code, this is called we then issue a Service call
; to allow all pdriver modules to register.
;

callback        ROUT

                Push    "r1, lr"

                LDR     r1, flags
                BIC     r1, r1, #f_CallBackPending
                STR     r1, flags                               ; mark as no call back anymore

                MOV     r1, #Service_PDriverStarting
                SWI     XOS_ServiceCall                         ; declare yourself now modules...

                Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Finalisation.
;

Finalisation    ROUT

                Push    "r1-r3, lr"

                LDR     wp, [wp]                                ; -> workspace

                LDR     r2, flags
                TST     r2, #f_CallBackPending                  ; is a callback pending?
                BEQ     %10                                     ; no...

                ADR     r0, callback
                MOV     r1, wp
                SWI     XOS_RemoveCallBack                      ; attempt to remove it
                Pull    "r1-r3, pc", VS

                BIC     r2, r2, #f_CallBackPending
                STR     r2, flags                               ; and then mark as removed
10
                ADR     r0, job_descriptions                    ; -> jobs descriptions list
                MOV     r1, #256
15
                LDR     r2, [r0], #4
                TEQ     r2, #0                                  ; is the job record empty?
                BNE     %90

                SUBS    r1, r1, #1
                BNE     %15                                     ; loop back until all checked

                BL      CloseMessages                           ; tidy up the messages files

        [ standalone
; free up resource fs
        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_DeregisterFiles   ; ignore errors
        CLRV                                  ; clear V
        ]

                CLRV
                Pull    "r1-r3, pc"
90
                ADR     r0, ErrorBlock_PrintInUse
                BL      LookupSingle                            ; expand error message
                Pull    "r1-r3, pc"                             ; return with r0 and v intact.

                MakeInternatErrorBlock PrintInUse,,PDrUsed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Service code handling.
;
	ASSERT	Service_ResourceFSStarting < Service_PDriverGetMessages

serviceentry_ServTab
	DCD	0
        DCD     Service_FastEntry - module_start
	[ standalone
	DCD	Service_ResourceFSStarting
	]
 	DCD	Service_PDriverGetMessages         ; finding messages block?
	DCD	0
        DCD     serviceentry_ServTab - module_start  ;anchor for table

Service         ROUT
	MOV	R0, R0
Service_FastEntry
        TEQ     r1, #Service_PDriverGetMessages         ; finding messages block?
        LDREQ   wp, [wp]
        BEQ     ServiceMessages

        [ standalone
; NK resource handling
        TEQ     R1,#Service_ResourceFSStarting
        MOVNE   PC,LR
        Push    "R0, LR"
        ADRL    R0, resourcefsfiles ; R0 -> ResourceFS file structure
        MOV     LR, PC          ; LR -> return address
        MOV     PC, R2          ; call ResourceFS routine
        Pull    "R0, PC"
        ]


                MOV    pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ChangeJob (SelectJob, SelectIllustration)
;
; in:   r0   = new job handle
;       r1   = job title
;       r11  = size number of SWI to call in printers code.
;
; bit bit 5 or r11 set then:-
;       r8   = printer driver number
;
; else:-
;       use current
;
; out:  -
;
; This code is called when the job is about to be changed, ie. on a SelectJob
; or SelectIllustration.
;

ChangeJob       ROUT

                Debuga  ChangeJob, "change job in:", r0,r1,r2,r3,r4,r5
                Debug   ChangeJob, "",r6,r7,r8,r9

                CMP     r0, #255                                ; is the handle valid?
                BLS     %00                                     ; yes...

                ADDR    r0, ErrorBlock_PrintNoSuchJob
                B       LookupSingle                            ; return an error
00
                Push    "r1-r5, lr"

                ADR     r3, job_descriptions                    ; -> descriptions list
                LDR     r2, current_job
                STR     r2, old_job                             ; store old job handle

                Debug   ChangeJob, "pointer to job records", r3
                Debug   ChangeJob, "current job is", r2

                TEQ     r0, #0                                  ; selecting a new job?
                BNE     %10
                TEQ     r2, #0                                  ; are we changing from no job to no job?
                BEQ     %50                                     ; return correctly

                LDR     r2, [r3, r2, LSL #2]                    ; get printer handle of job
                B       %40
10
                LDR     r2, [r3, r0, LSL #2]
                TEQ     r2, #0                                  ; does the job have a printer?
                BNE     %30

                LDR     r2, current_printer                     ; get current device
                TEQ     r2, #0                                  ; is there one?
                BEQ     nocurrentdriver
25
                Debug   ChangeJob, "driver to be used", r2

                STR     r2, [r3, r0, LSL #2]                    ; store the printer number
30
                Debug   ChangeJob, "record setup to select printer"

                LDR     r4, current_job
                TEQ     r4, #0                                  ; is there a current job?
                BEQ     %40

                LDR     r5, [r3, r4, LSL #2]
                CMP     r2, r5                                  ; do we need to deselect the current one?
                BEQ     %40

                Debug   ChangeJob, "deselecting old job!"

                MOV     r4, r0

                Push    "r2, r4, r11, wp"
                MOV     r10, r5
                MOV     r0, #0                                  ; no current job
                AND     r11, r11, #31                           ; mask out unwanted bits
                BL      calldriverR10
                Pull    "r2, r4, r11, wp"                       ; preserve them
                BVS     %60

                MOV     r0, r4
40
                Debug   ChangeJob, "selecting new job, handle is", r0

                STR     r0, current_job
                MOV     r10, r2

                Debug   ChangeJob, "new driver handle", r2

                Push    "r2, r10-r11, wp"
                AND     r11, r11, #31
                BL      calldriverR10                           ; call driver in R10
                Pull    "r2, r10-r11, wp"
                DebugE
                BVC     %50

                Debug   ChangeJob, "selecting new job went wrong!"
                DebugE  ChangeJob, "error return is"

                SavePSR lr
                Push    "r0, wp, lr"
                LDR     r2, current_job
                ADR     r3, job_descriptions
                MOV     r0, #0
                STR     r0, [r3, r2, LSL #2]
                STR     r0, current_job                         ; no longer an active job
                BL      calldriverR10                           ; call driver and inform
                Pull    "r0, wp, lr"

                RestPSR lr,,f                                   ; restore the flags
                B       %60
50
                LDR     r0, old_job                             ; = old job handle
55
                Debug   ChangeJob, "previous job handle is", r0
60
                Pull    "r1-r5, lr"

                Debuga  ChangeJob, "exiting with", r0,r1,r2,r3,r4,r5
                Debug   ChangeJob, "",r6,r7,r8,r9
                DebugE  ChangeJob, "and an error: "

                MOVVS   pc, lr
                TEQ     pc, pc
                MOVNES  pc, lr
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ClearJob
;
; in:   r0   = handle.
;
; out:  -
;
; Handle the clearing of a job within the system, called on EndJob or
; AbortJob.
;

ClearJob        ROUT

                EntryS  "R0,WP"

                MOVS    R10, R0                                 ; copy to r10
                LDREQ   R10, current_job                        ; setup to current job if =0

                Debug   ClearJob, "clear job handle", r10

                BL      calljobR10                              ; call to pass onto the device
                DebugE  ClearJob, "oopsy doopsy it went wrong"

                STRVS   R0, [SP, #Proc_RegOffset]
                EXIT    VS                                      ; return if device went wrong

                Debug   ClearJob, "managed to call the device"

                ASSERT (Proc_RegOffset = 0) :LOR: (Proc_RegOffset = 4)
                [ Proc_RegOffset = 0
                LDMIA   SP,{R0, WP}                             ; get a nice copy from the stack
                |
                LDMIB   SP,{R0, WP}                             ; get a nice copy from the stack
                ]

                LDR     R10, current_job
                TEQ     R10, R0
                MOV     R10, #0
                STREQ   R10, current_job
                Push    "R9"
                ADR     R9, job_descriptions
                STR     R10, [R9, R0, LSL #2]
                Pull    "R9"

                EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: CurrentJob
;
; in:   -
;
; out:  r0   = job handle.
;
; Return the currently selected job.
;

CurrentJob      ROUT

                LDR     r0, current_job                         ; = job handle to be returned
                Debug   CurrentJob, "returning job handle", r0

                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: EnumerateJobs
;
; in:   r0   = job handle to start searching for
;
; out:  r0   = next job handle / =0 if none
;
; Enumerate the current known about jobs within the sharing system.
;

EnumerateJobs   ROUT

                ADR     r10, job_descriptions                   ; -> head of descriptions list

                Debug   Enumerate, "enumerating from list at", r10
00
                ADD     r0, r0, #1
                CMP     r0, #256
                BGE     %10

                Debug   Enumerate, "does this handle exist?", r0

                Push    "r9"
                LDR     r9, [r10, r0, LSL #2]
                CMP     r9, #0                                  ; if there is a job then return home (clear V)
                Pull    "r9"
                MOVNE   pc, lr                                  ; return now

                Debug   Enumerate, "obviously not!"

                B       %00                                     ; loop back otherwise
10
                SUBS    r0, r0, r0                              ;  MOV     r0, #0 : CLRV
                MOV     pc, lr                                  ; no more jobs, r0 =0, V clear.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: EnumerateDrivers
;
; in:   r0  = next printer / =0 if first
;
; out:  r0 updated to contain correct value / =0 if none
;       r1  = global printer type to be returned.
;
; This call allows you to enumerate all the printers within the system,
; scanning from the first (with r0 specified to be 0 on entry), until r0
; is returned to be zero.
;

EnumDrivers     ROUT

                TEQ     R0, #0                                  ; start from head of list?
                ADREQ   R0, printer_list                        ; yes, so -> start

                CMP     R0, #0                                  ; any more? (clear V)
                MOVEQ   R1, #-1
                LDRNE   R0, [R0, #next_printer]
                LDRNE   R1, [R0, #printer_number]               ; get printer number / =-1 if none

                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: PassToDriver (Info, SetInfo, CheckFeatures, PageSize, SetPageSize,
;                     ScreenDump, SetPrinter).
;
; in:   r0   = job handle
;       r1.. = parameters for call
;       r11  = SWI number in printers code, bit 5 set => r8 => driver handle
;
; out:  -
;
; This code passes on the call to the specified printer driver or the currently
; active one.
;

PassToDriver    ROUT

                Debug   PassToDriver, "Pass to driver SWI number", r11

                LDR     r10, current_printer
                B       calldriverR10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: PassToCurrent (FontSWI, GiveRectangle, DrawPage, GetRectangle,
;                      InsertIllustration, DeclareFont, JPEGSWI).
;
; in:   r0   = job handle
;       r1...  parameters
;       r11  = SWI number required
;
; out:  -
;
; Pass onto the current job record selected.
;

PassToCurrent   ROUT

		[	debug
		TEQ	r11, #7
		DebugIf	EQ, fnt, "PDriver_FontSWI", r8
		]

                Debug   ToCurrent, "PassToCurrentJob with handle of", r0
                Debug   ToCurrent, "PassToCurrentJob SWI number", r11
                Debug   ToCurrent, "PassToCurrentJob lr", lr

                LDR     r10, current_job                        ; -> current job
                B       calljobR10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: PassToR0Job (CancelJob, CancelJobWithError)
;
; in:   r0   = job handle
;       r1...
;       r11  = number of the SWI to be called.
;
; out:  -
;
; This passes the event to the job specified in r10.
;

PassToR0Job     ROUT

                Debug   PassToJobR0, "PassToR0Job with handle of", r0
                Debug   PassToJobR0, "PassToR0Job SWI number", r11

                MOV     r10, r0
                B       calljobR10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Reset
;
; in:   -
;
; out:  -
;
; Reset all jobs within the system.
;

Reset           ROUT

                Push    "r1-r3, lr"

                Debug   Reset, "Resetting the job lists"

                LDR     r10, printer_list                       ; -> head of printer list
00
                TEQ     r10, #0                                 ; end of the list yet?
                BEQ     %20                                     ; yes, so clear the list

                MOV     r11, #&0A                               ; reset the device
                Push    "r10, wp"
                BL      calldriverR10                           ; call driver in r10
                Pull    "r10, wp"

                LDR     r10, [r10, #next_printer]               ; -> next printer
                B       %00
20
                MOV     r1, #0
                STR     r1, current_job                         ; no longer a current job

                ADR     r2, job_descriptions
                MOV     r3, #256                                ; reset all the job records
30
                STR     r1, [r2], #4
                SUBS    r3, r3, #1
                BNE     %30                                     ; loop back until all reset

                ; V will be clear
                Pull    "r1-r3, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: DeclareDriver
;
; in:   r0  -> branch code / =0 to remove a printer object.
;       r1   = WP for branch code
;       r2   = printer number (must be unique)
;
; out:  -
;
; Attempt to register a printer driver within the system, if r0 =0 then we remove it,
; all other registers must be setup correctly.
;
; Then we can allocate a block and store its vital statistics.
;

DeclareDriver  ROUT

                Push    "r1-r4, r9-r10, lr"

                Debug   DeclareDriver, "declaring with branch code at", r0
                Debug   DeclareDriver, "workspace for call", r1
                Debug   DeclareDriver, "unique printer id", r2

                ADR     r9, printer_list                        ; -> printer list
00
                LDR     r10, [r9, #next_printer]
                TEQ     r10, #0                                 ; is the next printer in the list?
                BEQ     %20

                LDR     r4, [r10, #printer_number]
                TEQ     r2, r4                                  ; does this printer exist?
                BEQ     %10

                MOV     r9, r10                                 ; advance the pointer
                B       %00                                     ; and loop again
10
                Debug   DeclareDriver, "Are we attempting to remove", r0

                TEQ     r0, #0                                  ; are we attempting undeclare a printer?
                BEQ     %50                                     ; yes, so don't give uniqueness error.

                Debug   DeclareDriver, "Oh fiddle sticks we are not"

                ADR     r0, ErrorBlock_PrintDuplicateNumber
                BL      LookupSingle
                B       %90                                     ; return a suitable error, r0 -> error block.
20
                Debug   DeclareDriver, "Make new record, pointer to last found", r9

                MOV     r10, r0
                MOV     r4, r2

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =printer_end                        ; amount of workspace needed
                SWI     XOS_Module
                BVS     %90                                     ; it didn't work so give up now

                STR     r2, [r9, #next_printer]                 ; store forwards link for previous record

                STR     r1, [r2, #private_word]
                STR     r4, [r2, #printer_number]
                STR     r10, [r2, #branch_code]
                MOV     r10, #0
                STR     r10, [r2, #next_printer]                ; setup the record to correspond to specified data

                B       %90                                     ; return accordingly.
50
                Debug   DeclareDriver, "Remove handle", r10

                LDR     r4, [r10, #next_printer]
                STR     r4, [r9, #next_printer]                 ; fix the chain

                LDR     r4, current_printer
                TEQ     r4, r10                                 ; is the current printer this one?
                Debug   DeclareDriver, "Same as current device", r4,r10

                MOVEQ   r4, #0
                STREQ   r4, current_printer                     ; yes, so deselect it

                MOV     r0, #ModHandReason_Free
                MOV     r2, r10
                SWI     XOS_Module                              ; release the memory block
90
                Pull    "r1-r4, r9-r10, pc", VS
                TEQ     pc, pc
                Pull    "r1-r4, r9-r10, pc", NE, ^              ; return clearing V (26-bit case)
                Pull    "r1-r4, r9-r10, pc"

                MakeInternatErrorBlock PrintDuplicateNumber,,DupNum

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: RemoveDriver
;
; in:   r0   = printer name.
;
; out:  -
;
; This code will remove a printer that has been registered using PDriver_DeclareDriver.
;

RemoveDriver    ROUT

                Debug   RemoveDriver, "remove printer of ID", r0

                MOV     r2, r0
                MOV     r1, #0
                MOV     r0, #0
                B       DeclareDriver                           ; attempt to remove

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: SelectDriver
;
; in:   r0  = driver number / =-1 to no active driver / =-2 to just read
;
; out:  r0  = previous driver
;
; This code will select the current printer device to be used, or return the
; number of the one currently selected.
;

SelectDriver    ROUT

                Push    "r1-r2, lr"

                LDR     r11, current_printer                    ; current printer
                CMP     r11, #0                                 ; is there one?
                MOVEQ   r11, #-1
                LDRNE   r11, [r11, #printer_number]

                TEQ     R0, R11                                 ; no change in device?
                BEQ     %20

                CMP     R0, #-1                                 ; is device to be unset?
                MOVEQ   R0, #0
                STREQ   R0, current_printer
                BLE     %20                                     ; yes, so no longer active and return

                LDR     r10, printer_list                       ; -> printer list
00
                TEQ     r10, #0
                BEQ     %10                                     ; select printer in r10

                LDR     r1, [r10, #printer_number]
                TEQ     r0, r1                                  ; the one we are looking for?
                MOVEQ   r0, r11
                BEQ     %10                                     ; yes, so select it

                LDR     r10, [r10, #next_printer]
                B       %00                                     ; loop back
10
                TEQ     r10, #0                                 ; did we match a device?
                BEQ     %15

                STR     r10, current_printer                    ; yes, so store new device number

                MOV     r1, #Service_PDriverChanged
                LDR     r2, [r10, #printer_number]
                SWI     XOS_ServiceCall                         ; broadcast to the outside world about the new driver
20
                MOVVC   r0, r11                                 ; previous device selected
                Pull    "r1-r2, pc", VS
                TEQ     pc, pc
                Pull    "r1-r2, pc", NE, ^
                Pull    "r1-r2, pc"
15
                ADR     r0, ErrorBlock_PrintUnknownNumber
                BL      LookupSingle                            ; otherwise give an error
                B       %20                                     ; jumping to the a suitable point to balance the stack

                MakeInternatErrorBlock PrintUnknownNumber,,BadPDNo

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PDriver_MiscOp implementation
;
;   Entry: R0  = reason code (with bit 31 set => for specific device)
;          R1..R7 as required by call.
;
;          IF PDriver_MiscOpForPrinter then r8 =id of device to direct call at.
;
;   Exit:  V set, R0 -> error block.
;          V clear; as specified by call.
;
; MiscOp functions to be handled by printer driver, some are handled by
; the printer independent code and some are passed to the back end code.
;
; Two SWIs are supported by the PDriver module for this type of operation,
; one directs calls at the current device and the other at the one specified
; in R8.  If no device is specified then we must resolve the pointer by
; loading the current printer.  If a device is specified then we have to
; scan the list of printers and call the relevant one or generate an
; error if that one is not known.
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        ASSERT  next_printer =0

MiscOp  ROUT

        Push    "R10,LR"

        LDR     R10,current_printer     ;->Current printer job
        B       miscop_alt              ;Jump in because R10 already points to record

MiscOpForDriver ROUT

        Push    "R10,LR"

        ADR     R10,printer_list        ;Address the printer list correctly

miscop_finddevice
        LDR     R10,[R10,#next_printer]
        TEQ     R10,#0                  ;End of the list of devices yet?
        BEQ     miscop_devicenotfound

        LDR     LR,[R10,#printer_number]
        TEQ     LR,R8                   ;Is this the device we are looking for?
        BNE     miscop_finddevice       ;No so loop again until found

miscop_alt
        BL      calldriverR10
        Pull    "R10,PC"                ;Call device and then return (r0 and V carried through)

miscop_devicenotfound
        ADR     R0,ErrorBlock_PrintUnknownNumber
        Pull    "R10,LR"
        B       LookupSingle            ;Convert token to a suitable message




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: calljobR10
;
; in:   r0..  = parameters
;       r10   = job handle to pass calls to,  =0 then ignore
;       r11   = SWI number to pass through.
;
; out:  -
;
; Pass call to the job specified in r10.
;

calljobR10      ROUT

                Debug   calljobR10, "calljobR10, job handle", r10
                Debug   calljobR10, "calljobR10, swi number", r11

                TEQ     r10, #0
                CMPNE   r10, #256                               ; is handle within suitable range?
                BGE     %90                                     ; no, so bog off!

                Push    "r9"
                ADR     r9, job_descriptions
                LDR     r10, [r9, r10, LSL #2]
                Pull    "r9"
                TEQ     r10, #0                                 ; is there a printer associated with this job?
                BNE     calldriverR10                           ; yes, so call it
90
                ADR     r0, ErrorBlock_PrintNoSuchJob
                B       LookupSingle                            ; handle was duff!!!

                MakeInternatErrorBlock PrintNoSuchJob,,NoJob

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: calldriverR10
;
; in:   r0.. = parameters
;       r10  = driver to call, 0 ignore call.
;       r11  = SWI number
;
; out:  -
;
; Call the device specified in r10.
;

calldriverR10   ROUT

                Debug   calldriverR10, "calldriver handle", r10
                Debug   calldriverR10, "calldriver SWI number", r11
                Debug   calldriverR10, "calldriver lr", lr

                CMP     r10, #0                                 ; is there a current driver? (clears V)
                LDRNE   wp, [r10, #private_word]                ; -> workspace
                LDRNE   pc, [r10, #branch_code]                 ;    call the doofer
nocurrentdriver
                ADR     r0, ErrorBlock_PrintNoCurrentDriver
                B       LookupSingle                            ; give an error because no current driver

                MakeInternatErrorBlock PrintNoCurrentDriver,,NoDrive

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                LTORG

                GET     MsgCode.s

              [ debug
                InsertNDRDebugRoutines
              ]

        [ standalone
resourcefsfiles
        ResourceFile    $MergedMsgs, Resources.PDrivers.Messages
        DCD     0
        ]

                END
