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
; Backup

        ^       0
drec_SectorSize #       1
drec_SecsPerTrk #       1
drec_Heads      #       1
drec_Density    #       1
drec_IdLen      #       1
drec_BitSize    #       1
drec_RASkew     #       1
drec_BootOpt    #       1
drec_LowSector  #       1
drec_Zones      #       1
drec_ZoneSpare  #       2
drec_Root       #       4
drec_DiscSize   #       4
drec_DiscId     #       2
drec_DiscName   #       10
drec_DiscType   #       4
drec_Unused     #       28
drec_Size * :INDEX: @
 ASSERT drec_Size = 64


; A backup window block...
;
        ^        0
bkp_taskhandle   #       4
bkp_handle       #       4
bkp_source       #       4
bkp_dest         #       4
bkp_memsize      #       4
bkp_state        #       4
bkp_oldstate     #       4
bkp_bitdiscsize  #       4
bkp_readto       #       4
bkp_writtento    #       4
bkp_databufstart #       4
bkp_mapsize      #       4
bkp_memrover     #       4
bkp_MaxFormatBarLength # 4
bkp_fulldiscref  #       8      ; enough for "ADFS::0"
bkp_shortdiscref * bkp_fulldiscref+5
bkp_discrecord   #       drec_Size
bkp_stack        #       128
bkp_StackTop     #       0
bkp_EventData    #       &100
; OSS Indirect data for window comes here, added to the total size.
bkp_IndirectData #       0
bkp_block_size  *       :INDEX: @

BkpState_Begin          *       0
BkpState_Paused         *       1
BkpState_FirstRead      *       2
BkpState_ReadTrack      *       3
BkpState_FirstWrite     *       4
BkpState_WriteTrack     *       5
BkpState_PressOK        *       6
BkpState_SetPause       *       7

        ALIGN
BkpStateMessages
        DCD     BkpMessageReading  -   BkpStateMessages
        DCD     BkpPausedMessage   -   BkpStateMessages
        DCD     BkpMessageReading  -   BkpStateMessages
        DCD     BkpMessageReading  -   BkpStateMessages
        DCD     BkpMessageWriting  -   BkpStateMessages
        DCD     BkpMessageWriting  -   BkpStateMessages
        DCD     0

ADFSBackup_Args         DCB     "Backup/S,From/E,To/E",0

TBToken                 DCB     "Backup",0 ; Backup to drive %0
OKToken                 DCB     "BOK",0 ; OK

BkpMessageReading       DCB     0
                        DCB     "Reading",0 ; Reading ...
BkpMessageWriting       DCB     0
                        DCB     "Writing",0 ; Writing ...
BkpPausedMessage        DCB     0
                        DCB     "Paused",0 ; Paused
BkpStartFailMessage     DCB     1
                        DCB     "SttFail",0 ; Insert source disc
BkpMessage_Failed       DCB     1
                        DCB     "BkpFail",0 ; Backup failed
BkpMessageInsertDest    DCB     0
                        DCB     "BkpDst",0 ; Insert destination disc
BkpReadyMessage
BkpMessageInsertSource  DCB     0
                        DCB     "BkpSrc",0 ; Insert source disc
BkpReadyMessage1        DCB     0
                        DCB     "Insert",0 ; Insert discs into drives

BkpMessage_BkpOk        DCB     0
                        DCB     "BkpOK",0 ; Backup completed OK
        ALIGN
TaskID  DCB     "TASK"

BackupMessagesList
        DCD     0

; --------------------------------------------------------------------------

; Initial entry point. OSS r10 and r11 must be the source and destination
; drives for the error handling, until they are stored in the workspace.

ADFSBackup_Code
        LDR     r4,[r2,#4]
        LDRB    r10,[r4,#1]
      [ debug
        dreg    r10,"Source drive "
      ]

        LDR     r5,[r2,#8]
        LDRB    r11,[r5,#1]
      [ debug
        dreg    r11,"Dest. drive "
      ]

; OSS Find out size needed for indirected data.

      [ SDFS
        ADRL    r1, str_templatefile_sdfs
        SWI     XWimp_OpenTemplate
      |
      [ SCSI
        ; ADFSFiler may not be present on all systems - so check for a copy of the templates in SCSIFiler's resources before falling back on the ADFSFiler copy that's traditionally used
        ADRL    r1, str_templatefile_scsi
        SWI     XWimp_OpenTemplate
        ADRVSL  r1, str_templatefile
        SWIVS   XWimp_OpenTemplate
      |
        ADRL    r1, str_templatefile
        SWI     XWimp_OpenTemplate
      ]
      ]
        MOVVS   r9, r0
        BVS     backup_error_r9

        MOV     r1, #-1
        MOV     r4, #-1
        ADRL    r5, w_format
        MOV     r6, #0
        BL      load_template           ; Get size required for template.
        BVS     backup_close_error

        MOV     r0,#ModHandReason_Claim
        ADD     r3, r2, #bkp_block_size ; Add indirected data size.
        SWI     XOS_Module
        BVS     backup_close_error

        MOV     r8,r2                           ; R8 is workspace pointer !
        ADD     r13,r8,#bkp_StackTop            ; Get some stack.
        STR     r10,[r8,#bkp_source]            ; Store source drive
        STR     r11,[r8,#bkp_dest]              ; Store dest drive
        ADD     r11, r8, r3                     ; r11 -> end indirected data

; Now start a WIMP Task.

        MOV     r0,#300
        LDR     r1,TaskID
        BL      MkBackupBannerIn_userdata
        ADRVC   r3,BackupMessagesList
        SWIVC   XWimp_Initialise
        BVS     backup_close_free_error

        STR     r1,[r8,#bkp_taskhandle]
        STR     r8, backup_block                ; For ADFS_Filer to kill us

      [ debug
        dline   "Backup task started"
      ]

        MOV     r0, #&2000                      ; Get minimum slot size of 8K for now.
        MOV     r1, #-1
        SWI     XWimp_SlotSize
        CMP     r0, #&2000                      ; Make sure we got enough.
      [ debug
        ADRCCL  r0, ErrorBlock_NoMem
      |
        ADRCC   r0, ErrorBlock_NoMem
      ]
        BLCC    lookuperror
        BVS     ErrorTask_CloseDown_CloseTemplate

        MOV     r1, #&8000              ; User space for template buffer
        ADD     r2, r8, #bkp_IndirectData
        MOV     r3, r11                 ; Get limit back from r11
        MOV     r4, #-1                 ; No fonts
        ADRL    r5, w_format
        MOV     r6, #0
        BL      load_template
        BVS     ErrorTask_CloseDown_CloseTemplate

; Get max size of bar, and mark bar as deleted.

        ADD     r1, r1, #w_icons + (3*i_size)   ; Third icon is bar.
        LDR     r0, [r1, #i_bbx0]               ; Icon's x0
        LDR     r2, [r1, #i_bbx1]               ; Icon's x1
        SUB     r2, r2, r0
        SUB     r2, r2, #8                      ; for border
        STR     r2, [r8, #bkp_MaxFormatBarLength]
       [ debug
        dreg    r2,"Max format bar length is "
       ]

        MOV     R0,#UpCallV
        ADRL    R1,BackupUpcallHandler
        MOV     R2,R8
        SWI     XOS_Claim
        BVS     ErrorTask_CloseDown

        SWI     XWimp_CloseTemplate
        MOVVC   r1, #&8000
        SWIVC   XWimp_CreateWindow
        BVS     ErrorTask_CloseDown
        STR     r0, [r8, #bkp_handle]

      [ debug
        dline   "Window created"
      ]

        LDR     r4,[r8,#bkp_dest]
;        dreg    r4,"bkp dest "
        ADD     r4,r4,#"0"
        ADR     r1,userdata+&100
        STR     r4,[r1]                 ; r1 -> drive number
        MOV     r2,r0                   ; r2 = window handle
        ADRL    r0,TBToken              ; r0 = title token.
        BL      SetTitle
        BVS     ErrorTask_CloseDown

      [ debug
        DLINE   "Title set"
      ]

        LDR     r4,[r8,#bkp_source]
        ADD     r3,r4,#"0"              ; Set drive number
        ADR     r1,userdata+&100        ; SetButton corrupts [userdata]
        STR     r3,[r1]
        ADRL    r0,FormatDriveToken
        MOV     r3,#0                   ; Icon 0 is drive number
        BL      SetButton
        BVS     ErrorTask_CloseDown

      [ debug
        DLINE   "Drive set"
      ]

        LDR     r4,[r8,#bkp_source]
        LDR     r5,[r8,#bkp_dest]
        TEQ     r4,r5
        ADREQL  r0,BkpReadyMessage      ; Display welcome message
        ADRNEL  r0,BkpReadyMessage1
        BL      Report
        BVS     ErrorTask_CloseDown

      [ debug
        DLINE   "Message displayed"
      ]

        ADRL    r0,OKToken              ; Set action button to "OK"
        MOV     r3,#6
        BL      SetButton
        BVS     ErrorTask_CloseDown

      [ debug
        DLINE   "Action button set"
      ]


        ADR     r1,userdata
        STR     r2,[r1,#0]
        MOV     r0,#2
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        LDR     r1,[r1,#24+8]
        LDR     r0,=&00003252           ; "R2"
        STR     r0,[r1]
        ADR     r1,userdata
        MOV     r0,#2_0001 :SHL: 28     ; Get ready to set the background colour
        STR     r0,[r1,#8]
        MOV     r0,#&f :SHL: 12         ; Set button type to never
        ORR     r0,r0,#2_1111 :SHL: 28  ; background colour 1
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState
        BVS     %FT01

      [ debug
        DLINE   "type set to never"
      ]

        ADR     r1,userdata
        ADRL    r0,ADFSPrefix
        LDR     r14,[r0]
        STR     r14,[r1]
        LDR     r14,[r0,#4]
        STR     r14,[r1,#4]
        LDR     r0,[r8,#bkp_source]
        ADD     r0,r0,#"0"
        STRB    r0,[r1,#6]
        MOV     r0,#0
        STRB    r0,[r1,#7]

        ADD     r1,r1,#5
      [ debug
        DSTRING r1
      ]
        BL      GetMediaName_nochecks   ; returns with r1 -> "adfs::discname"
      [ debug
        BVC     %FT99
        ADD     r14,r0,#4
        DSTRING r14,"Error "
99
      ]
        BVS     %FT01
      [ debug
        DSTRING   r1,"media name"
      ]

        Push    "r1"
        ADR     r1,userdata+&100
        LDR     r0,[r8,#bkp_handle]
        STR     r0,[r1]
        MOV     r0,#2
        STR     r0,[r1,#4]
        SWI     XWimp_GetIconState
        ADDVS   sp,sp,#4
        BVS     %FT01

        ADR     r1,userdata+&100
        LDR     r14,[r1,#28]
        Pull    "r1"
        ADD     r1,r1,#6
11
        LDRB    r3,[r1],#1
        STRB    r3,[r14],#1
        CMP     r3,#32
        BGE     %BT11

        ADR     r1,userdata+&100
        MOV     r0,#0
        STR     r0,[r1,#8]
        STR     r0,[r1,#12]
        SWI     XWimp_SetIconState

      [ debug
        DLINE   "Disk name set"
      ]

01
        MOVVC   r0,r2
        MOVVC   r1,#0
        MOVVC   r2,#7
        BLVC    SetBar                  ; Set bar to 0 length
        BVS     ErrorTask_CloseDown

        ADR     r1,userdata
        STR     r0,[r1]
        SWI     XWimp_GetWindowState
        MOVVC   r0,#-1
        STRVC   r0,[r1,#28]
        SWIVC   XWimp_OpenWindow
        BVS     ErrorTask_CloseDown

      [ debug
        DLINE   "Window opened"
      ]

        LDR     r0,FormatState
        LDR     r4,[r8,#bkp_source]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        ORR     r0,r0,r4
        LDR     r4,[r8,#bkp_dest]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        ORR     r0,r0,r4
        STR     r0,FormatState

        MOV     r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]
        MOV     r0,#BkpState_Begin
        STR     r0,[r8,#bkp_oldstate]

      [ debug
        DLINE   "states set"
      ]

BkpPollLoop
        MOVVS   R1,#0
        BLVS    MkBackupBannerIn_userdata
        SWIVS   XWimp_ReportError
        MOV     r0,#0
        ADD     r1,r8,#bkp_EventData
        SWI     XWimp_Poll

        ADR     LR,BkpPollLoop

        CMP     r0,#0
        BEQ     Null

        CMP     r0,#6
        BEQ     MouseClick


        CMP     r0,#2
        BNE     %FT02
        SWI     XWimp_OpenWindow
        MOV     PC,LR

02      CMP     r0,#3
        BNE     %FT03
        SWI     XWimp_CloseWindow
        B       Task_closedown

03      CMP     r0,#18
        CMPNE   r0,#17
        BEQ     bkp_message

        B       BkpPollLoop

MouseClick      ROUT
        Push    "LR"

        LDR     r0,[r1,#16]
        CMP     r0,#6
        Pull    "PC",NE

 [ {TRUE}
        ; SMC: filter out duff mouse clicks due to button type
        LDR     r0,[r1,#8]
        CMP     r0,#8
        Pull    "PC",CS
 ]

        LDR     r0,[r8,#bkp_state]
        CMP     r0,#BkpState_Paused
        BNE     %FT01

        LDR     r0,[r8,#bkp_oldstate]
        STR     r0,[r8,#bkp_state]

        MOV     r0,r0,ASL #2
        ADRL    r1,BkpStateMessages
        LDR     r0,[r1,r0]
        ADD     r0,r0,r1                ; r0 -> Message for state.
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        ADRL    r0,BPToken              ; Set action button to "Pause"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton

        Pull    "PC"

01
        CMP     r0,#BkpState_PressOK
        Pull    "LR",EQ
        BEQ     Task_closedown

        LDR     r0,[r8,#bkp_state]
        STR     r0,[r8,#bkp_oldstate]
        MOV     r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]

        ADRL    r0,BRToken              ; Set action button to "Continue"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton

        Pull    "PC"

; -------------------------------------------------------------------------

; OSS Lots of subtly different error handling routines.

backup_close_free_error
        MOV     r9, r0
        SWI     XWimp_CloseTemplate
        B       ErrorExit_r9

backup_close_error
        MOV     r9, r0
        SWI     XWimp_CloseTemplate
        B       backup_error_r9

ErrorTask_CloseDown_CloseTemplate
        MOV     r9, r0
        SWI     XWimp_CloseTemplate
        MOV     r0, r9
; ** Drop through **

ErrorTask_CloseDown
        MOV     r9, r0
        LDR     r1,TaskID
        LDR     r0,[r8,#bkp_taskhandle]
        SWI     XWimp_CloseDown                 ; Close down the WIMP task.
; ** Drop through **

ErrorExit_r9
        LDR     r10,[r8,#bkp_source]            ; Source and dest drives
        LDR     r11,[r8,#bkp_dest]              ; needed later.

        MOV     R0,#UpCallV
        ADRL    R1,BackupUpcallHandler
        MOV     R2,R8
        SWI     XOS_Release                     ; May return "not claimed"

        MOV     r0,#ModHandReason_Free          ; Free workspace.
        MOV     r2,r8
        SWI     XOS_Module
; ** Drop through **

backup_error_r9
        LDR     r0,FormatState
        MOV     r1,#1
        MOV     r4,r1,ASL r10           ; Source drive
        BIC     r0,r0,r4
        MOV     r4,r1,ASL r11           ; Dest drive
        BIC     r0,r0,r4
        STR     r0,FormatState

        MOV     r0, #0
        STR     r0, backup_block        ; Tell ADFS_Filer we are no more

        MOV     r0,r9
        SWI     OS_GenerateError
        SWI     OS_Exit                         ; Just in case !

ErrorBlock_NoMem
        DCD     0
        DCB     "NoMem",0
        ALIGN

; --------------------------------------------------------------------------

bkp_message     ROUT

        LDR     r0,[r1,#ms_action]
        CMP     r0,#0
        MOVNE   PC,LR

Task_closedown  ROUT
        BL      bkp_task_closedown
        SWIVS   OS_GenerateError
        SWI     OS_Exit

bkp_task_closedown ROUT                         ; Called externally
        MOV     r11, lr                         ; Save lr in r11
        LDR     r1,TaskID
        LDR     r0,[r8,#bkp_taskhandle]
        SWI     XWimp_CloseDown                 ; Close down the WIMP task.

        LDR     r0,FormatState
        LDR     r4,[r8,#bkp_source]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        BIC     r0,r0,r4
        LDR     r4,[r8,#bkp_dest]
        MOV     r1,#1
        MOV     r4,r1,ASL r4
        BIC     r0,r0,r4
        STR     r0,FormatState

        MOV     R0,#UpCallV
        ADRL    R1,BackupUpcallHandler
        MOV     R2,R8
        SWI     XOS_Release

        MOV     r0,#ModHandReason_Free          ; Free workspace.
        MOV     r2,r8
        SWI     XOS_Module

        MOV     r0, #0
        STR     r0, backup_block        ; Tell ADFS_Filer we are no more

        MOV     pc, r11

; --------------------------------------------------------------------------

Null    ROUT
        Push    "LR"

        LDR     r0,[r8,#bkp_state]
        ADR     LR,ChkErrors
        ADD     PC,PC,r0,ASL #2
        MOV     R0,R0

; Jump table for possible states

        B       StartBackup                     ; Start backup
        Pull    "PC"                            ; Paused.
        B       ReadTrack                       ; Read next track. (First time round)
        B       ReadTrack                       ; Read next track.
        B       FirstWrite
        B       WriteTrack
        Pull    "PC"                            ; Wait for the user to press OK.
        B       BackupSetPause                  ; Set pause caused by external event.

ChkErrors
        Pull    "PC",VC

        Push    "r0"

        LDR     r0,[r8,#bkp_state]              ; Keep copy of current state.
        STR     r0,[r8,#bkp_oldstate]           ;
        MOV     r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]              ; Pause the operation.

        ADRL    r0,BRToken                      ; Set action button to "Continue"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton

        SETV
        Pull    "r0,PC"

BackupSetPause        ROUT
        Push    "LR"

        MOV     r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]              ; Pause the operation.
        ADRL    r0,BRToken                      ; Set action button to "Continue"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton

        Pull    "PC"

ADFSDiscZero
        DCB     "$FSTitle::0",0
        ALIGN

StartBackup
        Push    "LR"

; First read the disc record to find all we need about this disc.

 [ debugbkp
        DLINE   "Start backup"
 ]

        ; Construct ADFS::N in userdata
        LDR     r1, ADFSDiscZero
        STR     r1, [r8, #bkp_fulldiscref]
        LDR     r1, ADFSDiscZero+4
        LDRB    r2, [r8, #bkp_source]
        ADD     r1, r1, r2, ASL #2*8
        STR     r1, [r8, #bkp_fulldiscref+4]

        ; Get a description of the disc
        ADD     r0, r8, #bkp_shortdiscref
        ADD     r1, r8, #bkp_discrecord
 [ debugbkp
        DSTRING r0, "XADFS_DescribeDisc ",cc
        DREG    r1, " to "
 ]
        SWI     X$SWIPrefix._DescribeDisc
        BVS     StartFail

        ; Set our Wimp slot big enough for the whole disc (if possible)
        LDR     r0, [r8, #bkp_discrecord + drec_DiscSize]
        MOV     r1, #-1
        SWI     XWimp_SlotSize
        CMP     r0, #&2000                      ; If we got less than 8K then give up.
        ADRCC   r0, ErrorBlock_NoMem
        BLCC    lookuperror
        BVS     StartFail
        STR     r0, [r8, #bkp_memsize]

        ; Work out size needed for map
        LDR     r0, [r8, #bkp_discrecord + drec_DiscSize]
        LDRB    r1, [r8, #bkp_discrecord + drec_SectorSize]
        MOV     r0, r0, LSR r1
        STR     r0, [r8, #bkp_bitdiscsize]
        ADD     r0, r0, #7
        MOV     r0, r0, LSR #3
        ADD     r0, r0, #&8000
        STR     r0, [r8, #bkp_databufstart]
        STR     r0, [r8, #bkp_memrover]

        ; Read the used space map
        SUB     r5, r0, #&8000
        MOV     r0, #FSControl_UsedSpaceMap
        ADD     r1, r8, #bkp_fulldiscref
        MOV     r2, #&8000
 [ debugbkp
        DREG    r0, "XOS_FSControl ",cc
        DSTRING r1, " of ",cc
        DREG    r2, " to ",cc
        DREG    r5, " length "
 ]
        SWI     XOS_FSControl
        BVS     StartFail

        MOV     r0,#0
        STR     r0,[r8,#bkp_readto]
        STR     r0,[r8,#bkp_writtento]

        MOV     r0,#BkpState_FirstRead
        STR     r0,[r8,#bkp_state]

 [ debugbkp
        DLINE   "Backup started"
 ]

        Pull    "PC"

StartFail
        Push    "r0"
 [ debugbkp
        ADD     r0, r0, #4
        DSTRING r0,"Start fail error:"
 ]
        LDR     r2,[r8,#bkp_handle]
        ADRL    r0,BkpStartFailMessage          ; Display welcome message
        BL      Report
        SETV
        Pull    "r0,PC"

ReadTrack
        Push    "LR"

; Set bar to correct size

        LDR     r0, [r8, #bkp_readto]
        LDR     r1, [r8, #bkp_bitdiscsize]
        MOV     r3,#100
        MUL     r2,r0,r3
        DivRem  r0,r2,r1,r14,norem

;        dreg    r0," Done %"

        LDR     r14,[r8, #bkp_MaxFormatBarLength]
        MUL     r14,r0,r14
        MOV     r2,#100
        DivRem  r1,r14,r2,r3,norem
        LDR     r0,[r8,#bkp_handle]
        MOV     r2,#10
        BL      SetBar

        LDR     r0, [r8, #bkp_source]
        MOV     r1, #1                          ; Read sectors
        LDR     r4, [r8, #bkp_readto]
        BL      TransferBytes
        STR     r4, [r8, #bkp_readto]
        BVS     ReadFailed
        Pull    "PC",NE                         ; more to read

DoWrite
        LDR     r0,[r8,#bkp_state]
        CMP     r0,#BkpState_FirstRead
        MOVEQ   r0,#BkpState_FirstWrite
        MOVNE   r0,#BkpState_WriteTrack
        STR     r0,[r8,#bkp_state]

        LDR     r5,[r8,#bkp_source]             ; Do we need to wait ?
        LDR     r6,[r8,#bkp_dest]
        TEQ     r5,r6
        STREQ   r0,[r8,#bkp_oldstate]
        MOVEQ   r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]
        ADRNEL  r0,BkpMessageWriting
        ADREQL  r0,BkpMessageInsertDest
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        TEQ     r5,r6                           ; If same drive:
        ADREQL  r0,BRToken                      ; Set action button to "Continue"
        MOVEQ   r3,#6
        LDREQ   r2,[r8,#bkp_handle]
        BLEQ    SetButton

        LDR     r0, [r8, #bkp_databufstart]
        STR     r0, [r8, #bkp_memrover]

        Pull    "PC"

ReadFailed
        MOV     r1,#0
        BL      MkBackupBannerIn_userdata
        SWI     XWimp_ReportError
        ADRL    r0,BkpMessage_Failed
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        ADRL    r0,OKToken                      ; Set action button to "OK"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton
        MOV     r0,#BkpState_PressOK
        STR     r0,[r8,#bkp_state]
        Pull    "PC"

; -----------------------------------------------------------------------
; TransferBytes
;
; In:
; r0 = drive
; r1 = DiscOp
; r4 = current position on disc
; Out:
; r4 updated
; NE if more to transfer
;
TransferBytes Push "r1-r7,lr"

 [ debugbkp
        DREG    r0, "Transfer bytes on drive ",cc
        DREG    r1, " op ",cc
        DREG    r4, " starting at "
 ]
        ; Start with 1 track's worth of sectors
        LDRB    r7, [r8, #bkp_discrecord + drec_SecsPerTrk]

        ; Then limit to whatever's left in memory
        LDR     r6, [r8, #bkp_memsize]
        ADD     r6, r6, #&8000
 [ debugbkp
        DREG    r6,"Memory end addr = "
 ]
        LDR     r5, [r8, #bkp_memrover]
        SUB     r6, r6, r5
 [ debugbkp
        DREG    r6,"Memory left = "
 ]
        LDRB    r5, [r8, #bkp_discrecord + drec_SectorSize]
        MOV     r6, r6, LSR r5
        CMP     r7, r6
        MOVHI   r7, r6

        ; Then limit to the disc's size
        LDR     r6, [r8, #bkp_bitdiscsize]
        SUB     r6, r6, r4
        CMP     r7, r6
        MOVHI   r7, r6

 [ debugbkp
        DREG    r7, "Max transfer "
 ]

        CMP     r7, #0
        BEQ     TransferDone

        MOV     r5, r4
        MOV     r6, r0                          ; Save drive number

TransferBytes_LoopStart
        BL      SkipZeroes
 [ debugbkp
        DREG    r5, "1st 1 at "
 ]
        LDRB    lr, [r8, #bkp_discrecord + drec_SectorSize]
        MOV     r2, r5, ASL lr
        BL      CountOnes
 [ debugbkp
        DREG    r3, "1 stream length "
 ]

        ; Construct the transfer parameters
        CMP     r3, #0
        BEQ     TransferEnd

        ; Prepare 'successful transfer' parameters
        ADD     r5, r5, r3
        SUB     r7, r7, r3

        LDRB    lr, [r8, #bkp_discrecord + drec_SectorSize]
        MOV     r4, r3, ASL lr
        LDR     r3, [r8, #bkp_memrover]

        ADD     lr, r8, #bkp_discrecord
        CMP     lr, #&04000000
        BHS     %FT40

        ORR     r1, r1, lr, ASL #6
        ORR     r2, r2, r6, ASL #32-3           ; Combine with drive number

 [ debugbkp
        DREG    r1, "XADFS_DiscOp(",cc
        DREG    r2,",",cc
        DREG    r3,",",cc
        DREG    r4,",",cc
        DLINE   ")"
 ]

        SWI     X$SWIPrefix._DiscOp
        B       %FT60

40
        Push    "r5"
        MOV     r5, lr
        STR     r6, [sp, #-12]!
        MOV     lr, #0
        STMIB   sp, {r2, lr}
        MOV     r2, sp
        SWI     X$SWIPrefix._DiscOp64
        ADD     sp, sp, #12
        Pull    "r5"
60
        BVS     TransferEnd

 [ debugbkp
        DLINE   "ADFS_DiscOp successful"
 ]

 [ debugbkp
        DREG    r3,"mem end:"
        DREG    r5,"address end:"
 ]
        STR     r5, [sp, #3*4]          ; r4 out
        STR     r3, [r8, #bkp_memrover]

        B       TransferBytes_LoopStart

TransferEnd
        BL      SkipZeroes
 [ debugbkp
        DREG    r5, "Final address end:"
 ]
        STR     r5, [sp, #3*4]          ; r4 out
        CMPVC   pc, #0                  ; more transfer to go (VC only)

TransferDone
        Pull    "r1-r7,pc"

; ----------------------------------------------------------------------
; SkipZeroes
;
; In:
; r5 = bit address into used space map
; Out:
; r5 advanced over zeroes
SkipZeroes Push "r0,r1,r2,lr"
        LDR     r0, [r8, #bkp_bitdiscsize]
        MOV     r1, #&8000
        B       SkipZeroesLoopGo

SkipZeroesLoopStart
        LDRB    r2, [r1, r5, LSR #3]
        AND     lr, r5, #7
        ADD     lr, lr, #1
        MOVS    r2, r2, LSR lr
        BCS     SkipZeroesExit
        ADD     r5, r5, #1

SkipZeroesLoopGo
        CMP     r5, r0
        BLO     SkipZeroesLoopStart

SkipZeroesExit
        Pull    "r0,r1,r2,pc"

; ----------------------------------------------------------------------
; CountOnes
;
; In:
; r5 = bit address into used space map
; r7 = upper limit
; Out:
; r3 = number of consecutive ones (upper bounded by r7 in)
;
CountOnes Push "r0,r1,r2,r5,lr"
        LDR     r0, [r8, #bkp_bitdiscsize]
        MOV     r1, #&8000
        MOV     r3, #0
        B       CountOnesLoopGo

CountOnesLoopStart
        LDRB    r2, [r1, r5, LSR #3]
        AND     lr, r5, #7
        ADD     lr, lr, #1
        MOVS    r2, r2, LSR lr
        BCC     CountOnesExit
        ADD     r5, r5, #1
        ADD     r3, r3, #1

CountOnesLoopGo
        CMP     r3, r7
        BHS     CountOnesExit
        CMP     r5, r0
        BLO     CountOnesLoopStart

CountOnesExit
        Pull    "r0,r1,r2,r5,pc",,^

FirstWrite
        Push    "LR"

; This is the first time we are writing to the disc, check that it has a compatible format.

        ADR     r0,userdata
        MOV     r1,#":"
        STRB    r1,[r0]
        LDR     r1,[r8,#bkp_dest]
        ADD     r1,r1,#"0"
        STRB    r1,[r0,#1]
        MOV     r1,#0
        STRB    r1,[r0,#2]
        ADR     r1,userdata+64
        SWI     X$SWIPrefix._DescribeDisc
        BVS     FirstWriteFailed

        LDRB    r0, [r1, #drec_SectorSize]
        LDRB    r2, [r8, #bkp_discrecord + drec_SectorSize]
        TEQ     r0,r2
        BNE     IncompatibleFormat

        LDRB    r0, [r1, #drec_SecsPerTrk]
        LDRB    r2, [r8, #bkp_discrecord + drec_SecsPerTrk]
        TEQ     r0,r2
        BNE     IncompatibleFormat

        LDR     r0, [r1, #drec_DiscSize]
        LDR     r2, [r8, #bkp_discrecord + drec_DiscSize]
        TEQ     r0,r2
        BNE     IncompatibleFormat

; Ok, formats ARE Compatible.

 [ chkbkpdefects
        Push    "r5"
; SMC: now make sure that the destination disc has no defects
        SUB     sp, sp, #8              ; get space for ADFS::n\0
        LDR     r0, ADFSDiscZero
        STR     r0, [sp]
        LDR     r0, ADFSDiscZero+4
        LDRB    lr, [r8, #bkp_dest]
        ADD     r0, r0, lr, ASL #2*8
        STR     r0, [sp, #4]

        MOV     r0, #41
        MOV     r1, sp
        ADR     r2, userdata
        MOV     r5, #&200
        SWI     XOS_FSControl
        ADD     sp, sp, #8              ; get rid of disc specifier
        Pull    "r5"
        BVS     FirstWriteFailed

        LDR     lr, [r2]
        TEQ     lr, #DefectList_End
        BNE     DestHasDefects
 ]

; Dismount the disc
        ADR     r0, userdata
        ADR     r1, bkp_dismount
bkp_copydismount
        LDRB    lr, [r1], #1
        TEQ     lr, #0
        STRNEB  lr, [r0], #1
        BNE     bkp_copydismount
        LDR     r1, [r8,#bkp_dest]
        ADD     r1,r1,#"0"
        STRB    r1, [r0], #1
        MOV     lr, #0
        STRB    lr, [r0], #1
        ADR     r0, userdata
        SWI     XOS_CLI
        CLRV

        MOV     r0,#BkpState_WriteTrack
        STR     r0,[r8,#bkp_state]
        Pull    "PC"

bkp_dismount DCB "$FSTitle:%Dismount :",0
        ALIGN

 [ chkbkpdefects
; SMC: complain if backup destination disc has defects
DestHasDefects
        ADR     r0, ErrorBlock_DestHasDefects
        BL      lookuperror
        B       FirstWriteFailed

ErrorBlock_DestHasDefects
        DCD     0
        DCB     "BkpDfct",0
 ]

IncompatibleFormat

        ADR     r0,ErrorBlock_IncompatibeleFormats
        BL      lookuperror

FirstWriteFailed
        MOV     r1,#0
        BL      MkBackupBannerIn_userdata
        SWI     XWimp_ReportError

        ADRL    r0,BkpMessageInsertDest
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        TEQ     r5,r6                           ; If same drive:
        ADREQL  r0,BRToken                      ; Set action button to "Continue"
        MOVEQ   r3,#6
        LDREQ   r2,[r8,#bkp_handle]
        BLEQ    SetButton

        MOV     r0,#BkpState_FirstWrite         ; Put message up and wait.
        STR     r0,[r8,#bkp_oldstate]
        MOV     r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]

        Pull    "PC"

ErrorBlock_IncompatibeleFormats
        DCD     0
        DCB     "DifDisc",0

WriteTrack
        Push    "LR"

; Set bar to correct size

        LDR     r0, [r8, #bkp_writtento]
        LDR     r1, [r8, #bkp_bitdiscsize]
        MOV     r3,#100
        MUL     r2,r0,r3
        DivRem  r0,r2,r1,r14,norem

;        dreg    r0," (Write) Done %"

        LDR     r14, [r8, #bkp_MaxFormatBarLength]
        MUL     r14,r0,r14
        MOV     r2,#100
        DivRem  r1,r14,r2,r3,norem
        LDR     r0,[r8,#bkp_handle]
        MOV     r2,#11
        BL      SetBar

        LDR     r0, [r8, #bkp_dest]
        MOV     r1, #2                          ; Write sectors
        LDR     r4, [r8, #bkp_writtento]
        BL      TransferBytes
        STR     r4, [r8, #bkp_writtento]
        BVS     ReadFailed
        Pull    "PC",NE                         ; More writing to do

        LDR     r0, [r8, #bkp_bitdiscsize]
        CMP     r4, r0
        BLO     DoRead                          ; More disc to do

EndOfDisc                                       ; Reached end of disc

        MOV     r0,#FSControl_StampImage
        LDR     r1,[r8, #bkp_dest]
        ADD     r1,r1,#"0"
        STRB    r1,[r8, #bkp_fulldiscref+6]
        ADD     r1,r8,#bkp_fulldiscref          ; -> ADFS::n[00]
        MOV     r2,#FSControl_StampImage_Now
        SWI     XOS_FSControl
        BVS     ReadFailed
        ADRL    r0,BkpMessage_BkpOk
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        ADRL    r0,OKToken                      ; Set action button to "Continue"
        MOV     r3,#6
        LDR     r2,[r8,#bkp_handle]
        BL      SetButton
        MOV     r0,#BkpState_PressOK
        STR     r0,[r8,#bkp_state]

        Pull    "PC"

DoRead
        MOV     r0,#BkpState_ReadTrack
        STR     r0,[r8,#bkp_state]

        LDR     r5,[r8,#bkp_source]             ; Do we need to wait ?
        LDR     r6,[r8,#bkp_dest]
        TEQ     r5,r6
        STREQ   r0,[r8,#bkp_oldstate]
        MOVEQ   r0,#BkpState_Paused
        STR     r0,[r8,#bkp_state]
        ADRNEL  r0,BkpMessageReading
        ADREQL  r0,BkpMessageInsertSource
        LDR     r2,[r8,#bkp_handle]
        BL      Report

        TEQ     r5,r6                           ; If same drive:
        ADREQL  r0,BRToken                      ; Set action button to "Continue"
        MOVEQ   r3,#6
        LDREQ   r2,[r8,#bkp_handle]
        BLEQ    SetButton

        LDR     r0, [r8, #bkp_databufstart]
        STR     r0,[r8,#bkp_memrover]

        Pull    "PC"

BackupUpcallHandler   ROUT                    ; Pause  window if disc might have changed.

        TEQ     r0,#UpCall_MediaSearchEnd
        MOVNE   PC,LR

        Push    "r0-r4,LR"

        LDR     r0,[r12,#bkp_state]
        TEQ     r0,#BkpState_Paused
        TEQNE   r0,#BkpState_PressOK
        TEQNE   r0,#BkpState_SetPause
        Pull    "r0-r4,PC",EQ

        STR     r0,[r12,#bkp_oldstate]
        MOV     r0,#BkpState_SetPause
        STR     r0,[r12,#bkp_state]

        Pull    "r0-r4,PC"

        [ debug :LAND: debugag
        InsertNDRDebugRoutines
        ]

        END
