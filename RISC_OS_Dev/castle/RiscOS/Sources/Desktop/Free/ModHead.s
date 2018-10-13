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
; > s.ModHead

        ASSERT  (.=Module_BaseAddr)
MySWIBase       *       Module_SWISystemBase + FreeSWI * Module_SWIChunkSize

        DCD     Start          - Module_BaseAddr
        DCD     Init           - Module_BaseAddr
        DCD     Die            - Module_BaseAddr
        DCD     Service        - Module_BaseAddr
        DCD     Title          - Module_BaseAddr
        DCD     Helpstr        - Module_BaseAddr
        DCD     Helptable      - Module_BaseAddr
        DCD     MySWIBase
        DCD     Free_SWIdecode - Module_BaseAddr
        DCD     Free_SWInames  - Module_BaseAddr
        DCD     0
 [ International_Help <> 0
        DCD     message_filename - Module_BaseAddr
 |
        DCD     0
 ]
 [ :LNOT: No32bitCode
        DCD     Free_Flags     - Module_BaseAddr
 ]

; ----------------------------------------------------------------------------------------------------------------------
Helpstr DCB     "Free",9,9,"$Module_HelpVersion", 0

Title   ;DCB     "Free",0
Free_SWInames
        DCB     "Free",0                ; prefix
        DCB     "Register",0
        DCB     "DeRegister",0
        DCB     0
        ALIGN

Taskid  DCB     "TASK"
                ALIGN

 [ :LNOT: No32bitCode
Free_Flags DCD ModuleFlag_32bit
 ]

; ----------------------------------------------------------------------------------------------------------------------
;       Handle *Desktop_Free - only enter modules if after a Service_StartWimp
Desktop_Free_Code
        Push    "LR"

        LDR     r12, [r12]
        LDR     r14, mytaskhandle
        CMP     r14, #-1
        MOVEQ   r2, r0                  ; r2 --> command tail
        MOVEQ   r0, #ModHandReason_Enter
        ADREQ   r1, Title
        SWIEQ   XOS_Module
01
        ADR     r0, ErrorBlock_CantStartFree
        ADR     r1, Title
        BL      LookupError
        Pull    "PC"
; ----------------------------------------------------------------------------------------------------------------------
;       Error block for use of *Desktop_Free

ErrorBlock_CantStartFree
        DCD     0
        DCB     "UseDesk",0
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
Helptable
; ----------------------------------------------------------------------------------------------------------------------
Freecommand
        Command Desktop_Free,0,0,International_Help
        Command ShowFree,3,3,International_Help
        DCB     0
; ----------------------------------------------------------------------------------------------------------------------
 [ International_Help=0
Desktop_Free_Help
        DCB     "The Free utility displays free space information for the desktop filers"
        DCB     13,10
        DCB     "Do not use *Desktop_Free use *Desktop instead."
        DCB     0
Desktop_Free_Syntax
        DCB     "Syntax: *Desktop_Free",0
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
ShowFree_Help
        DCB     "*ShowFree shows the amount of free space on devices.",0
ShowFree_Syntax
        DCB     "Syntax: *ShowFree -FS <Filing system name>  <Device>",0
 |
Desktop_Free_Help       DCB     "HFREDFR", 0
Desktop_Free_Syntax     DCB     "SFREDFR", 0
ShowFree_Help           DCB     "HFRESHF", 0
ShowFree_Syntax         DCB     "SFRESHF", 0
 ]
ShowFreeArgs
        DCB     "FS/A/K,Device",0
        ALIGN
ErrorBlock_UnknownFileSystem
        DCD     0
        DCB     "UnkFS",0
        ALIGN
ErrorBlock_NotStarted
        DCD     0
        DCB     "NotRun",0
        ALIGN
; ----------------------------------------------------------------------------------------------------------------------
ShowFree_Code

        Push    "LR"

        LDR     r12,[r12]
        CMP     r12,#0
        Pull    "PC",LE


        LDR     r14,mytaskhandle
        CMP     r14,#0
        ADRLE   r0,ErrorBlock_NotStarted
        MOVLE   r1,#0
        BLLE    LookupError
        Pull    "PC",VS

        MOV     r1,r0
        ADR     r0,ShowFreeArgs
        ADR     r2,dataarea
        MOV     r3,#&100
        SWI     XOS_ReadArgs        ; Get arguments
        Pull    "PC",VS

        MOV     r5,r2
        LDR     r1,[r2]             ; Pointer to FS name.
        DebugS  xx,"FSName is ",r1
        MOV     r2,#0
        MOV     r0,#FSControl_LookupFS
        SWI     XOS_FSControl       ; Get filing system number.

        CMP     r2,#0
        ADREQ   r0,ErrorBlock_UnknownFileSystem
        MOVEQ   r1,#0
        BLEQ    LookupError
        Pull    "PC",VS

        Debug   xx,"Filing system number ",r1

        LDR     r3,[r5,#4]              ; Pointer to device ID.
        MOV     r0,#FreeReason_GetName
        ADR     r2,dataarea
        BL      CallEntry               ; [r2] -> Name r0 = length of name.
        Pull    "PC",VS

        MOV     r5,r0                   ; Save length.

;       See if we already have a window open for this device.

        ADR     r0,windows_ptr
01
        LDR     r0,[r0,#next_ptr]
        CMP     r0,#0
        BEQ     create_window
        LDR     r14,[r0,#window_fs]
        CMP     r14,r1
        BNE     %BT01
        LDR     r14,[r0,#window_device]
        CMPSTR  r14,r2
        BNE     %BT01

        Debug   xx,"Window found"

        MOV     r14,#1 :SHL: 31
        STR     r14,[r0,#window_update]  ; Mark window for update & open at front.
        STR     r14,poll_word            ; Set poll word

        Pull    "PC"                    ; Return.

create_window                           ; Window not found, create new window block.


        MOV     r3,#window_block_size
        ADD     r3,r3,r5                ; Plus length of name.
        MOV     r0,#ModHandReason_Claim
        SWI     XOS_Module              ; Claim block.
        Pull    "PC",VS

        LDR     r0,windows_ptr
        STR     r0,[r2,#next_ptr]
        CMP     r0,#0
        STRGT   r2,[r0,#prev_ptr]
        MOV     r0,#0                   ; link to start of list.
        STR     r0,[r2,#prev_ptr]
        STR     r2,windows_ptr
        MOV     r0,#-1
        STR     r0,[r2,#window_handle]  ; Not created yet
        MOV     r0,#1:SHL:31
        STR     r0,[r2,#window_update]  ; Needs update.
        STR     r0,poll_word            ; Set poll word.
        STR     r1,[r2,#window_fs]      ; FS number
        STR     r5,[r2,#window_namelength] ; length of device ID.

        ADD     r5,r2,#window_block_size
        STR     r5,[r2,#window_device]  ; Device name.

        MOV     r0,r5
        ADR     r4,dataarea
        BL      copy_r0r4_null

        Pull    "PC"                    ; Return.


; ----------------------------------------------------------------------------------------------------------------------
;       Module initialisation point
Init    Entry

      [ standalone
        ADR     r0, resourcefiles
        SWI     XResourceFS_RegisterFiles       ; ignore errors
      ]

        LDR     r2, [r12]
        CMP     r2, #0                  ; clears V
        BNE     %FT01

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #max_running_work
        SWI     XOS_Module
        EXIT    VS

        STR     r2, [r12]

01
        MOV     r12, r2

        MOV     r0, #0
        STR     r0, windows_ptr
        STR     r0, mytaskhandle
        STR     r0, fs_list
        STR     r0, message_fopen

; Claim UpCallV

        MOV     r0,#UpCallV
        ADR     r1,UpCall_handler
        MOV     r2,r12
        SWI     XOS_Claim

; Add entry points that are in this module
        MOV     r2,r12
        ADRL    r0,adfs_entry         ; ADFS
        MOV     r1,#8
        BL      AddEntry
        ADRL    r0,RamFS_entry        ; RamFS
        MOV     r1,#23
        BL      AddEntry
        ADRL    r0,SCSIFS_entry       ; SCSI
        MOV     r1,#26
        BL      AddEntry
        ADRL    r0,NETFS_entry        ; Econet
        MOV     r1,#5
        BL      AddEntry
        ADRL    r0,NFS_entry          ; NFS
        MOV     r1,#33
        BL      AddEntry
        ADRL    r0,PCCardFS_entry     ; PCCardFS Support
        MOV     r1,#89
        BL      AddEntry

; initialise Free$Path if not already done

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

        EXIT

Path            DCB     "Free$$Path"
                DCB     0
PathDefault     DCB     "Resources:$.Resources.Free."
                DCB     0
                ALIGN

; ----------------------------------------------------------------------------------------------------------------------
;       Module service entry point
ServiceTable
        ASSERT  Service_Reset < Service_StartWimp
        ASSERT  Service_StartWimp < Service_StartedWimp
        ASSERT  Service_StartedWimp < Service_MemoryMoved
        ASSERT  Service_MemoryMoved < Service_ResourceFSStarting

        DCD     0
        DCD     ServiceUrsula - Module_BaseAddr
        DCD     Service_Reset
        DCD     Service_StartWimp
        DCD     Service_StartedWimp
        DCD	Service_MemoryMoved
      [ standalone
        DCD     Service_ResourceFSStarting
      ]
        DCD     0
        DCD     ServiceTable - Module_BaseAddr
Service
	MOV	r0,r0			; Ursula
        TEQ     r1, #Service_StartWimp
        TEQNE   r1, #Service_StartedWimp
        TEQNE   r1, #Service_Reset
        TEQNE   r1, #Service_MemoryMoved
      [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
      ]
        MOVNE   pc, lr

ServiceUrsula

        LDR     R12, [R12]

        TEQ     R1,#Service_StartWimp
        BEQ     svc_startwimp

        TEQ     R1,#Service_StartedWimp
        BEQ     svc_startedwimp

        TEQ     R1,#Service_Reset
        BEQ     svc_reset

        TEQ     R1,#Service_MemoryMoved
        BEQ     svc_memorymoved

      [ standalone
        TEQ     R1,#Service_ResourceFSStarting
        BEQ     svc_resourcefsstarting
      ]

        MOV     PC,LR

; ----------------------------------------------------------------------------------------------------------------------
;       Wimp call to ask task to start up. Claimed by setting task_handle to -1, but only if 0 to start with
svc_startwimp Entry

        LDR     r14, mytaskhandle
        TEQ     r14, #0
        MOVEQ   r14, #-1
        STREQ   r14, mytaskhandle
        ADREQL  r0,  Freecommand
        MOVEQ   R1, #0

        EXIT

; ----------------------------------------------------------------------------------------------------------------------
;       Wimp has finished starting the tasks. If task handle=-1 then start up failed, so reset to 0.
svc_startedwimp Entry

;  Test task handle to see if in starting sequence, or if started succesfully
        LDR     r14, mytaskhandle
        CMP     r14, #-1
        MOVEQ   r14, #0                  ; unset flag (so user can retry)
        STREQ   r14, mytaskhandle

        EXIT

        LTORG
; ----------------------------------------------------------------------------------------------------------------------
;       Reset button pressed. Wimp has shut down. Reset task handle to 0. Release linked lists of icons.
svc_reset Entry "r0-r3"

        Debug   xx,"FREE - RESET"

        ADR     r2, windows_ptr
        BL      free_list               ; Free buffered list
        MOV     r0, #0                  ; Clear task handle
        STR     r0, mytaskhandle

; Claim UpCallV
        MOV     r0,#UpCallV
        ADR     r1,UpCall_handler
        MOV     r2,r12
        SWI     XOS_Claim

        EXIT

      [ standalone
; ----------------------------------------------------------------------------------------------------------------------
;       ResourceFS is restarting - we need to re-register our resource files

svc_resourcefsstarting Entry "r0"

        ADR     R0, resourcefiles
        MOV     LR, PC                  ; LR -> return address
        MOV     PC, R2                  ; R2 -> code to call (R3 = workspace ptr)

        EXIT
      ]

; ----------------------------------------------------------------------------------------------------------------------
;      Memory moved , check if RAM disc removed.
svc_memorymoved Entry "r0-r1"

        MOV     r0,#5
        SWI     XOS_ReadDynamicArea

        Debug   xx,"RAM disc size is ",r1

        ADR     r0,windows_ptr
01
        LDR     r0,[r0,#next_ptr]
        CMP     r0,#0
        BEQ     %FT02

        LDR     r14,[r0,#window_fs]
        CMP     r14,#23                 ; RAMFS ?
        BNE     %BT01

        Debug   xx,"RAMFS window found."

        CMP     r1,#0
        MOVEQ   r14,#1 :SHL: 30         ; Mark for delete.
        MOVNE   r14,#1
        STR     r14,[r0,#window_update]
        STR     r14,poll_word
        B       %BT01

02
        EXIT

; ----------------------------------------------------------------------------------------------------------------------
;       RMKill'ing the module
Die     Entry   "r7-r11"

        LDR     r12, [r12]

; Close down the wimp end
        LDR     r0, mytaskhandle
        CMP     r0, #0
        LDRGT   r1, Taskid
        SWIGT   XWimp_CloseDown

; Release UpCallV
        MOV     r0,#UpCallV
        ADR     r1,UpCall_handler
        MOV     r2,r12
        SWI     XOS_Release

; Delete lists of icons
        ADR     r2, windows_ptr
        BL      free_list               ; Free buffered list
        ADR     r2, fs_list
        BL      free_list               ; Free buffered list

; Close messages file
        LDR     r0, message_fopen
        TEQ     r0, #0
        SWINE   XMessageTrans_CloseFile

      [ standalone
; Deregister ResourceFS files
        ADR     r0, resourcefiles
        SWI     XResourceFS_DeregisterFiles
      ]

        CLRV
        EXIT                            ; don't refuse to die

; ----------------------------------------------------------------------------------------------------------------------
; On UpCall 3, mark all related windows as needing update.
UpCall_handler ROUT
        TEQ     r0, #UpCall_ModifyingFile
        MOVNE   pc, lr

        Push    "LR"

 [ {FALSE}
 SWI XOS_WriteI+'?'
 ]

        ; Check for the right modifying file reason
        TEQ     r9, #upfsfile_Save
        TEQNE   r9, #upfsfile_Delete
        TEQNE   r9, #upfsfile_Create
        TEQNE   r9, #upfsfile_CreateDir
        LDRNE   r14, =upfsopen_CreateUpdate
        TEQNE   r9, r14
        LDRNE   r14, =upfsclose
        TEQNE   r9, r14
        TEQNE   r9, #upfsargs_EnsureSize

        Pull    "PC",NE

        ; Reason code's right - save the registers and start looking..
        Push    "r0-r11"
        MOV     r10, sp         ; frame pointer

 [ {FALSE}
 SWI XOS_WriteI+'U'
 TEQ r9,#upfsfile_Save
 SWIEQ XOS_WriteI+'0'
 TEQ r9,#upfsfile_Delete
 SWIEQ XOS_WriteI+'1'
 TEQ r9,#upfsfile_Create
 SWIEQ XOS_WriteI+'1'
 TEQ r9,#upfsfile_CreateDir
 SWIEQ XOS_WriteI+'2'
 TEQ r9,#upfsargs_EnsureSize
 SWIEQ XOS_WriteI+'3'
 LDR r14,=upfsopen_CreateUpdate
 TEQ r9,r14
 SWIEQ XOS_WriteI+'4'
 LDR r14,=upfsclose
 TEQ r9,r14
 SWIEQ XOS_WriteI+'5'
 ]

        ; Close or Ensure size then we want to get the filename for the file
        TEQ     r9, #upfsargs_EnsureSize
        LDRNE   r14, =upfsclose
        TEQNE   r9, r14
        BNE     %FT10

        ; Read buffer size and round up to a word
        MOV     r0, #OSArgs_ReadPath
        MOV     r2, #ARM_CC_Mask
        MOV     r5, #0
        SWI     XOS_Args
        BVS     %FT05
        RSB     r5, r5, #3+1
        BIC     r5, r5, #3
        SUB     sp, sp, r5

        ; Read the filename
        MOV     r0, #OSArgs_ReadPath
        MOV     r2, sp
        SWI     XOS_Args
        BVS     %FT05
        MOV     r1, sp

        ; Skip past the 1st ':' in <FS>::<disc>.$.....
01
        LDRB    r14, [r1], #1
        TEQ     r14, #':'
        BNE     %BT01

10
        AND     r8, r8, #&ff
        MOV     r2, r1

 [ {FALSE}
 MOV r0,r1
 SWI XOS_Write0
 SWI XOS_NewLine
 ]

        ADR     r11, windows_ptr
        B       %FT04

03
        ; If window's fs is right, window hasn't already been marked for update,
        ;       and the window's path matches ours then mark for update
        LDR     r14, [r11,#window_fs]
        CMP     r14, r8
        LDREQ   r14, [r11,#window_update]
        TEQEQ   r14, #0
        LDREQ   r3, [r11, #window_device]
        MOVEQ   r0, #FreeReason_ComparePath
        MOVEQ   r1, r8
        BLEQ    CallEntry
        BVS     %FT05

        ; Match - mark window needing update and set poll_word
        STREQ   r11, [r11, #window_update]
        STREQ   r11, poll_word

04
        LDR     r11, [r11, #next_ptr]
        CMP     r11, #0
        BNE     %BT03
05
        MOV     sp, r10
        Pull    "r0-r11,PC"

; ----------------------------------------------------------------------------------------------------------------------

      [ standalone
resourcefiles
        ResourceFile    LocalRes:Templates, Resources.Free.Templates
        ResourceFile    $MergedMsgs,        Resources.Free.Messages
        DCD     0
      ]

        ALIGN

        LNK     s.StartLoop
