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
; > FSLock.s

        AREA |FSLock$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:OsBytes
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:CMOS
        GET     Hdr:NdrDebug
        GET     Hdr:MsgTrans

        GET     hdr.FSLock
        GET     VersionASM

; Workspace
                ^ 0, wp
Wsp_MsgBlock    # 16
Wsp_FSBlock     # 4
Wsp_FS_Open     # 4
Wsp_FS_File     # 4
Wsp_FS_Func     # 4
Wsp_Hard1       # 12                    ; Name of Hard Drive 1 (Drive 4)
Wsp_Hard2       # 12                    ; Name of Hard Drive 2 (Drive 5)
Wsp_Hard3       # 12                    ; Name of Hard Drive 3 (Drive 6)
Wsp_Hard4       # 12                    ; Name of Hard Drive 4 (Drive 7)
Wsp_CMOSset     # 8                     ; Workspace to copy the CMOS settings into.
Wsp_Passwrd     # 4                     ; Workspace to encrpyt new Password into.
Wsp_ScrubStart  # 0
Wsp_ReadArg     # 256                   ; OS_ReadArgs workspace.
Wsp_Crypt       # 40                    ; Space for decrypted cryption code
Wsp_ScrubEnd    # 0

Wsp_Size        # 0

; Errors
                ^ ErrorBase_AcornNZ
                                  # 1
ErrorNumber_FSLockFSAlreadyLocked # 1   ; ERR1
ErrorNumber_FSLockFSNotAct        # 1   ; ERR2
ErrorNumber_FSLockFSNotLockable   # 1   ; ERR3
                                  # 1
ErrorNumber_FSLockDiscWriteProt   # 1   ; ERR5
ErrorNumber_FSLockCannotDie       # 1   ; ERR6
ErrorNumber_FSLockBadChangeParm   # 1   ; ERR7
ErrorNumber_FSLockPasswordBad     # 1   ; ERR8
ErrorNumber_FSLockConfigProt      # 1   ; ERR9
ErrorNumber_FSLockGivePassword    # 1   ; ERR10
ErrorNumber_FSLockFatFingers      # 1   ; ERR11
ErrorNumber_FSLockInterceptTwice  # 1   ; ERR12

; Options

        GBLA    defaultfs
defaultfs       SETA 0                  ; was 8 for ADFS. 0 means fully unlocked

    [ :LNOT: :DEF: international_help
        GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
    ]
        GBLL    develop
develop         SETL {FALSE}
debug           SETL {FALSE}
        GBLL    debugdiag
debugdiag       SETL {FALSE}
        
; Module header

        ASSERT  (.-Module_BaseAddr) = 0

        DCD     0                       ; No language entry
        DCD     FSLock_Init     - Module_BaseAddr
        DCD     FSLock_Die      - Module_BaseAddr
        DCD     0                       ; No service calls
        DCD     FSLock_Title    - Module_BaseAddr
        DCD     FSLock_HelpStr  - Module_BaseAddr
        DCD     FSLock_HC_Table - Module_BaseAddr
        DCD     FSLockSWI_Base
        DCD     FSLock_SWIhandler - Module_BaseAddr
        DCD     FSLock_SWInames - Module_BaseAddr
        DCD     0                       ; No SWI decode code 
 [ international_help
        DCD     FSLock_MessageFile - Module_BaseAddr
 |
        DCD     0
 ]
 [ :LNOT:No32bitCode
        DCD     FSLock_Flags    - Module_BaseAddr
 ]

FSLock_HelpStr
        DCB     "FSLock", 9, 9, "$Module_MajorVersion ($Module_Date)" 
      [ Module_MinorVersion <> ""
        DCB     " $Module_MinorVersion"
      ]
        DCB     0
        ALIGN

 [ :LNOT:No32bitCode
FSLock_Flags
        DCD     ModuleFlag_32bit
 ]

; Initialise

FSLock_Init
        Push    "LR"
        LDR     R0, [R12]               ; R0 -> Private word
        CMP     R0, #0                  ; Non fatal init?
        BNE     init_claim              ; If so, just claim filing system
        MOV     R3, #:INDEX:Wsp_Size
        MOV     R0, #ModHandReason_Claim
        SWI     XOS_Module
        Pull    "PC", VS                ; Exit if error
        STR     R2, [R12]
        MOV     R12, R2
        MOV     R0, #0
        ADD     R3, R3, R2              ; R3 -> End Of Workspace
init_loop
        STR     R0, [R2], #4
        CMP     R2, R3
        BLT     init_loop               ; Clear workspace to 0

        ; Open the messages file
        ADR     R0, Wsp_MsgBlock
        ADR     R1, FSLock_MessageFile
        MOV     R2, #0
        SWI     XMessageTrans_OpenFile
        Pull    "PC", VS

        BL      read_CMOS

init_claim
        MOV     R0, #0
        STRB    R0, Wsp_CMOSset + 6     ; CMOS RAM protection quench off
        BL      ensure_cmos_valid       ; Determine is CMOS is valid
        LDRB    R0, Wsp_CMOSset + 4     ; R0 = Locked FS
        CMP     R0, #0                  ; Are we locking any FS?
        BLNE    claim_filingsystem      ; If so, lock it
        Pull    "PC"

FSLock_MessageFile
        DCB     "Resources:$$.Resources.FSLock.Messages", 0
        ALIGN

; Finalise

FSLock_Die
        Push    "R7-R11,LR"
        LDR     R12, [R12]              ; R12 -> Workspace
        CMP     R10, #0                 ; Is this fatal?

      [ :LNOT: develop
        BNE     %FT10                   ; If not then don't release workspace
      ]

        LDRB    R14, Wsp_CMOSset + 4
        TEQ     R14, #0
        BLNE    release_filingsystem

        ; Close the messages file
        ADR     R0, Wsp_MsgBlock
        SWI     XMessageTrans_CloseFile
        Pull    "PC", VS
        Pull    "R7-R11, PC"
10
        ADR     R0, exit_callback
        MOV     R1, #0
        SWI     XOS_AddCallBack
        ADR     R0, ErrorBlock_FSLockCannotDie
        Pull    "R7-R11,LR"
        B       MakeError

        MakeInternatErrorBlock FSLockCannotDie,,"ERR6"

exit_callback
        Push    "R0,LR"
        ADRL    R0, rminsert_cmd
        SWI     XOS_CLI
        Pull    "R0,PC"

; International lookup

MakeError
        Push    "R1-R7,LR"
        ADR     R1, Wsp_MsgBlock
        MOV     R2, #0
        ADRL    R4, FSLock_Title
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "R1-R7,PC"

GSWrite0
        Push    "R0-R3,LR"
        SUB     R13, R13, #256
        MOV     R1, R0
        ADR     R0, Wsp_MsgBlock
        MOV     R2, R13
        MOV     R3, #256
        SWI     XMessageTrans_GSLookup
        MOVVC   R0, R2
        MOVVC   R1, R3
        SWIVC   XOS_WriteN
        ADD     R13, R13, #256
        STRVS   R0, [R13]
        Pull    "R0-R3,PC"

Bad_FS_Numbers                          ; This is a Bit Stream of FS numbers.
                                        ; if a bit is set at the FS numbers bit
                                        ; position then it is an invalid FS to
                                        ; lock
        ; Bits    76543210
        DCB     2_00101001              ;   0-  7
        DCB     2_11110000              ;   8- 15
        DCB     2_01111110              ;  16- 23
        DCB     2_00000000              ;  24- 31
        DCB     2_00000000              ;  32- 39
        DCB     2_11000000              ;  40- 47
        DCB     2_00100000              ;  48- 55
        DCB     2_00000001              ;  56- 63
        DCB     2_00000000              ;  64- 71
        DCB     2_00000000              ;  72- 79
        DCB     2_00000000              ;  80- 87
        DCB     2_00000000              ;  88- 95
        DCB     2_00000000              ;  96-103
        DCB     2_00000000              ; 104-111
        DCB     2_00000000              ; 112-119
        DCB     2_00000000              ; 120-127
        DCB     2_00000000              ; 128-135
        DCB     2_00000000              ; 136-143
        DCB     2_00000000              ; 144-151
        DCB     2_00000000              ; 152-159
        DCB     2_00000000              ; 160-167
        DCB     2_00000000              ; 168-175
        DCB     2_00000000              ; 176-183
        DCB     2_00000000              ; 184-191
        DCB     2_00000000              ; 192-199
        DCB     2_00000000              ; 200-207
        DCB     2_00000000              ; 208-215
        DCB     2_00000000              ; 216-223
        DCB     2_00000000              ; 224-231
        DCB     2_00000000              ; 232-239
        DCB     2_00000000              ; 240-247
        DCB     2_00000000              ; 248-255
        ALIGN

; SWI code

FSLock_SWInames
        DCB     "FSLock", 0
        DCB     "Version", 0
      [ develop
        DCB     "Status", 0
        DCB     "ChangeStatus", 0
      |
        ; Shhh
      ]
        DCB     0
        ALIGN

FSLock_SWIhandler
        LDR     R12, [R12]
        CMP     R11, #(%FT20 - %FT10) :SHR: 2
        ADDCC   PC, PC, R11, LSL#2
        B       %FT20
10
        B       FSLock_Version_SWI
        B       FSLock_Status_SWI
        B       FSLock_ChangeStatus_SWI
20
        ADR     R0, ErrorBlock_NoSuchSWI
        B       MakeError

        MakeInternatErrorBlock NoSuchSWI,,"BadSWI"

FSLock_Version_SWI
        MOV     R0, #Module_Version     ; R0 = Version number
        MOV     R1, R12                 ; R1 = Ptr to workspace
        MOV     PC, R14

FSLock_Status_SWI
        Push    "R2-R4,LR"
        MOV     R3, #0
        LDRB    R0, Wsp_CMOSset + 4
        MOV     R4, R0                  ; R4 Workspace FS number
        CMP     R0, #0
        ADDNE   R3, R3, #1
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte                ; Read the CMOS FS Number
        CMP     R2, #0                  ; Is the CMOS FS byte set?
        ADDNE   R3, R3, #1
        MOVNE   R4, R2
        MOV     R0, R3                  ; R0 Status number
        MOV     R1, R4
        Pull    "R2-R4,PC"

FSLock_ChangeStatus_SWI
        Push    "R0-R2,LR"
        CMP     R0, #2
        ADRHI   R0, ErrorBlock_FSLockBadChangeParm
        BHI     cs_err
        CMP     R0, #1
        BHI     cs_tolocked
        BEQ     cs_tounlocked
        ; Fall through

cs_tofullyunlocked
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte                ;Read the CMOS FS Number.
        CMP     R2, #0                  ;Is the CMOS FS byte set?
        BEQ     cs_finished             ;No, so we're already unlocked
        LDR     R1, [R13, #4]
        BL      CheckPassword
        BVS     cs_finished

cs_unlock
        BL      release_filingsystem    ; Release the filingsystem
        MOV     R0, #0                  ; Clear out the workspace
        LDR     R2, [R13]               ; New status
        TEQ     R2, #0
        STREQ   R0, Wsp_CMOSset         ; Clear password if unlock full
        STRB    R0, Wsp_CMOSset + 4
        BL      get_cmos_sum            ; Get '' in R1
        STRB    R1, Wsp_CMOSset + 5     ; and store it
        TEQ     R2, #0
        BLEQ    write_CMOS              ; If fully unlocking write workspace to CMOS
        B       cs_finished

cs_tounlocked
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte                ;Read the CMOS FS Number.
        CMP     R2, #0                  ;Is the CMOS FS byte set?
        BEQ     cs_setnewpassword
        LDR     R1, [R13, #4]
        BL      CheckPassword
        BVS     cs_finished
        LDRB    R2, Wsp_CMOSset + 4
        CMP     R2, #0
        BNE     cs_unlock

cs_setnewpassword
        ; Check for filing system number >= 256
        CMP     R3, #256
        ADRHSL  R0, ErrorBlock_FSLockFSNotLockable
        BHS     cs_err

        ; Check for non-existant filing system
        MOV     R0, #FSControl_LookupFS
        MOV     R1, R3
        SWI     XOS_FSControl
        BVS     cs_finished
        TEQ     R2, #0
        ADREQL  R0, ErrorBlock_FSLockFSNotLockable
        BEQ     cs_err

        ; Check for an OK-to-lock filing system
        ADR     R14, Bad_FS_Numbers
        LDRB    R14, [R14, R3, LSR #3]
        AND     R0, R3, #7
        MOV     R14, R14, LSR R0
        TST     R14, #1                 ; Is the FS a bad one?
        ADRNEL  R0, ErrorBlock_FSLockFSNotLockable
        BNE     cs_err

        ; If there's an old filing system then unlock it
        LDRB    R14, Wsp_CMOSset + 4
        CMP     R14, #0                 ; VC too
        BLNE    release_filingsystem
        BVS     cs_finished

        ADRL    R0, Crypt_Passwd
        ADR     R1, Wsp_Crypt
        MOV     R2, #36
        BL      StringCopy              ; Decrypt the crypt routine

        MOV     R0, #1
        ADD     R2, R1, R2
        SWI     XOS_SynchroniseCodeAreas

        LDR     R0, [R13, #8]
        MOV     R14, PC                 ; Jump to decrypted crypt routine
        ADD     PC, R12, #:INDEX:Wsp_Crypt 
        BL      scrub_wkspace           ; Clean up any passwords left
        STR     R1, Wsp_CMOSset
        STRB    R3, Wsp_CMOSset + 4
        BL      get_cmos_sum            ; Get 'checksum' in R1
        STRB    R1, Wsp_CMOSset + 5
        BL      write_CMOS
        LDR     R14, [R13, #0]
        TEQ     R14, #2
        BEQ     cs_locknow
        MOV     R14, #0                 ; switch back to unlocked for working purposes
        STRB    R14, Wsp_CMOSset + 4
        BL      get_cmos_sum            ; Get 'checksum' in R1
        STRB    R1, Wsp_CMOSset + 5
        B       cs_finished

cs_locknow
        BL      claim_filingsystem
        B       cs_finished

cs_tolocked
        LDRB    R14, Wsp_CMOSset + 4
        CMP     R14, #0
        BLNE    CheckPassword           ; If changing password then check old one
        BVS     cs_finished

        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte                ;Read the CMOS FS Number.
        CMP     R2, #0                  ;Is the CMOS FS byte set?
        BEQ     cs_setnewpassword       ;Fully Unlocked->Locked so set new password
        LDRB    R14, Wsp_CMOSset + 4
        TEQ     R14, #0
        BNE     cs_setnewpassword       ;Locked->Locked so set new password

        ; Otherwise Unlocked->Locked so just lock the thing
        STRB    R2, Wsp_CMOSset + 4
        BL      get_cmos_sum            ; Get 'checksum' in R1
        STRB    R1, Wsp_CMOSset + 5
        B       cs_locknow

cs_err
        BL      MakeError
cs_finished
        BL      scrub_wkspace           ; Clean up any passwords left
        STRVS   R0, [R13]
        Pull    "R0-R2,PC"

CheckPassword
        ; R1=password
        Push    "R0-R2,LR"
        ADRL    R0, Crypt_Passwd
        ADR     R1, Wsp_Crypt
        MOV     R2, #36
        BL      StringCopy              ; Decrypt the crypt routine

        MOV     R0, #1
        ADD     R2, R1, R2
        SWI     XOS_SynchroniseCodeAreas

        LDR     R0, [R13, #4]
        MOV     R14, PC
        ADD     PC, R12, #:INDEX:Wsp_Crypt ; Jump to decrypted crypt routine
        LDR     R0, Wsp_CMOSset         ; Load current pw
        CMP     R0, R1                  ; Are they the same?
        ADRNE   R0, ErrorBlock_FSLockPasswordBad
        BLNE    MakeError
        STRVS   R0, [R13]
        Pull    "R0-R2,PC"

        MakeInternatErrorBlock  FSLockBadChangeParm,,"ERR7"
        MakeInternatErrorBlock  FSLockPasswordBad,,"ERR8"

; Star commands

FSLock_HC_Table
        GBLA    i_h_flag
      [ international_help
i_h_flag SETA  International_Help
      |
i_h_flag SETA  0
      ]
        Command FSLock_Lock,           0, 0, i_h_flag
        Command FSLock_Unlock,         2, 0, i_h_flag :OR: (2_11:SHL:8)
        Command FSLock_Status,         0, 0, i_h_flag 
        Command FSLock_ChangePassword, 4, 1, i_h_flag :OR: (2_11111:SHL:8)
        DCB     0
        ALIGN

      [ international_help
FSLock_Lock_Help
        DCB     "HFSLLOC", 0
FSLock_Lock_Syntax
        DCB     "SFSLLOC", 0
FSLock_Unlock_Help
        DCB     "HFSLUNL", 0
FSLock_Unlock_Syntax
        DCB     "SFSLUNL", 0
FSLock_Status_Help
        DCB     "HFSLSTA", 0
FSLock_Status_Syntax
        DCB     "SFSLSTA", 0
FSLock_ChangePassword_Help
        DCB     "HFSLCHP", 0
FSLock_ChangePassword_Syntax
        DCB     "SFSLCHP", 0
      |
FSLock_Lock_Help
        DCB     "*FSLock_Lock locks machine against modification.", 13
FSLock_Lock_Syntax
        DCB     "Syntax: *FSLock_Lock", 0
FSLock_Unlock_Help
        DCB     "*FSLock_Unlock unlocks the currently locked "
        DCB     "filing system when given the right password. If the -"
        DCB     "full flag is not given then the filing system is only"
        DCB     " unlocked till the next reset of the machine.", 13
FSLock_Unlock_Syntax
        DCB     "Syntax: *FSLock_Unlock [-full] [Password]", 0
FSLock_Status_Help
        DCB     "*FSLock_Status reports on whether a filing "
        DCB     "system is currently locked or not.", 13
FSLock_Status_Syntax
        DCB     "Syntax: *FSLock_Status", 0
FSLock_ChangePassword_Help
        DCB     "*FSLock_ChangePassword changes the password "
        DCB     "used to unlock the system.", 13
FSLock_ChangePassword_Syntax
        DCB     "Syntax: *FSLock_ChangePassword <FSName> [New [New [Old]]]", 0
      ]
        ALIGN

FSLock_Lock_Code
        Push    "LR"
        LDR     R12, [R12]              ; Get ptr to workspace

        SWI     XFSLock_Status

        ; Check if already locked
        TEQ     R0, #2
        ADREQ   R0, ErrorBlock_FSLockFSAlreadyLocked
        BLEQ    MakeError
        Pull    "PC", VS

        ; Check if there's a password to lock with
        TEQ     R0, #0
        ADREQ   R0, ErrorBlock_FSLockGivePassword
        BLEQ    MakeError
        Pull    "PC", VS

        ; Everything OK, so go ahead and lock the system
        MOV     R0, #2
        SWI     XFSLock_ChangeStatus
        Pull    "PC"

        MakeInternatErrorBlock FSLockFSAlreadyLocked,,"ERR1"
        MakeInternatErrorBlock FSLockFSNotAct,,"ERR2"
        MakeInternatErrorBlock FSLockFSNotLockable,,"ERR3"
        MakeInternatErrorBlock FSLockGivePassword,,"ERR10"

FSLock_Unlock_Code
        Push    "R0,LR"
        LDR     R12, [R12]              ; Get ptr to workspace
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte                ; Read the CMOS FS Number.
        CMP     R2, #0                  ; Is an FS currently locked?
        ADREQ   R0, ErrorBlock_FSLockGivePassword
        BLEQ    MakeError
        BVS     %FT90

        LDR     R1, [R13, #0*4]         ; R1 -> command tail
        ADR     R0, template_Unlock     ; R0 -> command template
        ADR     R2, Wsp_ReadArg         ; R2 -> ReadArg buffer
        MOV     R3, #?Wsp_ReadArg       ; R3 = length of buffer
        SWI     XOS_ReadArgs
        BVS     %FT90

        MOV     R3, R2                  ; R3 -> ReadArg buffer
        LDR     R0, [R3]                ; R0 -> password
        LDR     R6, [R3, #4]            ; R6=-full flag
        CMP     R0, #0                  ; was a password supplied? (CLRV too)
        ADDEQ   R0, R3, #8              ; No so calculate an address.
        MOVEQ   R1, #?Wsp_ReadArg-8     ; Space for password
        ADREQ   R2, PasswdPrompt
        BLEQ    read_passwd_in          ; and then read one in.
        MOVVC   R1, R0
        BLVC    CheckPassword
        BVS     %FT90

        BL      release_filingsystem    ; Release the filingsystem
        MOV     R0, #0                  ; Clear out the workspace
        TEQ     R6, #0
        STRNE   R0, Wsp_CMOSset         ; Clear password if -full
        STRB    R0, Wsp_CMOSset + 4
        BL      get_cmos_sum            ; Get '' in R1
        STRB    R1, Wsp_CMOSset + 5     ; and store it
        TEQ     R6, #0                  ; Is it set?
        BLNE    write_CMOS              ; If so, write workspace to CMOS
90
        BL      scrub_wkspace           ; Clean up any passwords left
        STRVS   R0, [R13]
        Pull    "R0,PC"                 ;   lying around and exit

template_Unlock
        DCB     "password,full/S/K", 0
PasswdPrompt
        DCB     "Passwd", 0
        ALIGN

FSLock_Status_Code
        Push    "R0-R5,LR"
        LDR     R12,[R12]
        SWI     XFSLock_Status
        BVS     %FT95

        ; Choose the text
        ADR     R5, Status_0
        TEQ     R0, #1
        ADREQ   R5, Status_1
        TEQ     R0, #2
        ADREQ   R5, Status_2
        TEQ     R0, #1
        TEQNE   R0, #2
        BNE     %FT90

        ; Look up the filing system to get a name
        MOV     R0, #FSControl_ReadFSName
        ADR     R2, Wsp_ReadArg
        MOV     R3, #?Wsp_ReadArg
        SWI     XOS_FSControl
        BVS     %FT95

        ADR     R4, Wsp_ReadArg
90
        MOV     R0, R5
        BL      GSWrite0
95
        STRVS   R0, [R13]
        Pull    "R0-R5,PC"

Status_0
        DCB     "Stat0", 0
Status_1
        DCB     "Stat1", 0
Status_2
        DCB     "Stat2", 0
        ALIGN

FSLock_ChangePassword_Code
        Push    "LR"
        LDR     R12, [R12]              ; Get ptr to workspace
        MOV     R1, R0                  ; R1 -> command tail
        ADR     R0, template_ChangePassword ; R0 -> command template
        ADR     R2, Wsp_ReadArg         ; R2 -> ReadArg buffer
        MOV     R3, #?Wsp_ReadArg       ; R3 = length of buffer
        SWI     XOS_ReadArgs
        Pull    "PC", VS                ; If there was a problem, exit now

        MOV     R6, R2                  ; R6 -> ReadArg buffer
        MOV     R0, #FSControl_LookupFS
        LDR     R1, [R6]                ; R1 -> FSName
        MOV     R2, #0                  ; Name is terminated by any ctrl
        SWI     XOS_FSControl           ; Read FS number in R1
        Pull    "PC", VS                ; If there was a problem, exit now
        CMP     R1, #&100
        ADRHS   R0, ErrorBlock_FSLockFSNotAct
        BLHS    MakeError
        Pull    "PC", VS

        STR     R1, [R6]                ; somewhere to store it for later
        ADD     R5, R6, #16             ; Unused space in ReadArgs buffer so far

        LDR     R0, [R6, #4]            ; New password 1
        TEQ     R0, #0
        ADRNE   R14, ChangePassword_GotNew1
        BNE     ChangePassword_GotOne
        STR     R5, [R6, #4]
        ADRL    R2, ChangePassword_New1Prompt
        BL      ChangePassword_ReadOne
        BVS     ChangePassword_Error
ChangePassword_GotNew1
        LDR     R0, [R6, #8]            ; New password 2
        TEQ     R0, #0
        ADRNE   R14, ChangePassword_GotNew2
        BNE     ChangePassword_GotOne
        STR     R5, [R6, #8]
        ADRL    R2, ChangePassword_New2Prompt
        BL      ChangePassword_ReadOne
        BVS     ChangePassword_Error
ChangePassword_GotNew2
        LDR     R1, [R6, #8]
        LDR     R0, [R6, #4]
ChangePassword_CheckNewNewLoop
        LDRB    R2, [R0], #1
        LDRB    R14, [R1], #1
        TEQ     R2, R14
        BNE     ChangePassword_NewsDifferent
        TEQ     R2, #0
        BNE     ChangePassword_CheckNewNewLoop
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS + 4
        SWI     XOS_Byte
        TEQ     R2, #0
        BEQ     ChangePassword_OldOptional
        LDR     R0, [R6, #12]           ; Old password
        TEQ     R0, #0
        ADRNE   R14, ChangePassword_GotOld
        BNE     ChangePassword_GotOne
        STR     R5, [R6, #12]
        ADR     R2, ChangePassword_OldPrompt
        BL      ChangePassword_ReadOne
        BVS     ChangePassword_Error
ChangePassword_GotOld
ChangePassword_OldOptional
        LDRB    R0, Wsp_CMOSset + 4
        TEQ     R0, #0
        MOVEQ   R0, #1
        MOVNE   R0, #2                  ; New status
        LDR     R1, [R6, #12]           ; Old password
        LDR     R2, [R6, #8]            ; New password
        LDR     R3, [R6, #0]            ; New filing system
        SWI     XFSLock_ChangeStatus

ChangePassword_Error
        BL      scrub_wkspace           ; Clean up any passwords left
        Pull    "PC"

ChangePassword_GotOne
        LDRB    R0, [R5], #1
        TEQ     R0, #0
        BNE     ChangePassword_GotOne
        MOV     PC, R14

ChangePassword_ReadOne
        Push    "LR"
        MOV     R0, R5
        ADD     R1, R6, #256
        SUB     R1, R1, R5
        BL      read_passwd_in
        MOVVC   R0, #0
        STRVCB  R0, [R5, R1]!
        ADDVC   R5, R5, #1
        Pull    "PC"

ChangePassword_NewsDifferent
        ADR     R0, ErrorBlock_FSLockFatFingers
        Pull    "LR"
        B       MakeError

template_ChangePassword
        DCB     "FSName,New1,New2,Old", 0
ChangePassword_New1Prompt
        DCB     "N1Pass", 0
ChangePassword_New2Prompt
        DCB     "N2Pass", 0
ChangePassword_OldPrompt
        DCB     "OldPass", 0
        ALIGN

        MakeInternatErrorBlock FSLockFatFingers,,"ERR11"

; * CMOS access
; All CMOS routines assume R12 -> workspace...

ensure_cmos_valid
        Push    "R0-R4,LR"
        BL      get_cmos_sum
        LDRB    R0, Wsp_CMOSset + 5
        CMP     R0, R1
        Pull    "R0-R4,PC", EQ
        BL      read_CMOS
        BL      get_cmos_sum
        LDRB    R0, Wsp_CMOSset + 5
        CMP     R0, R1
        Pull    "R0-R4,PC", EQ
        LDR     R0, Default_Password
        STR     R0, Wsp_CMOSset
        MOV     R0, #defaultfs
        STRB    R0, Wsp_CMOSset + 4
        BL      get_cmos_sum
        STRB    R0, Wsp_CMOSset + 5
        BL      write_CMOS
        Pull    "R0-R4,PC"

write_CMOS
        Push    "R0-R4,LR"
        MOV     R1, #1
        STRB    R1, Wsp_CMOSset + 6     ; Set the semaphore to allow access
        MOV     R0, #OsByte_WriteCMOS
        MOV     R1, #FSLockCMOS
        ADR     R3, Wsp_CMOSset
        ADD     R4, R3, #?FSLockCMOS
write_loop
        LDRB    R2, [R3], #1            ; Load byte from workspace
        SWI     XOS_Byte                ; Store it in CMOS
        ADD     R1, R1, #1              ; Inc cmos ptr
        CMP     R3, R4                  ; Have we written all the bytes
        BLT     write_loop              ; If not, loop back
        MOV     R1, #0
        STRB    R1, Wsp_CMOSset + 6     ; Set the semaphore to prevent access
        Pull    "R0-R4,PC"

read_CMOS
        Push    "R0-R4,LR"
        MOV     R0, #OsByte_ReadCMOS
        MOV     R1, #FSLockCMOS
        ADR     R3, Wsp_CMOSset
        ADD     R4, R3, #?FSLockCMOS
read_loop
        SWI     XOS_Byte                ; Read CMOS byte
        STRB    R2, [R3], #1            ; Store it in workspace
        ADD     R1, R1, #1              ; Inc cmos ptr
        CMP     R3, R4                  ; Have we read all the bytes
        BLT     read_loop               ; If not, loop back
        Pull    "R0-R4,PC"

Default_Password
        DCD     0
Default_PasswordEnd

get_cmos_sum
        Push    "R0,LR"
        ADR     R0, Wsp_CMOSset
        MOV     R1, #5
        BL      make_checksum           ; Get the checksum.
        EOR     R1, R0, #&EA
        AND     R1, R1, #&FF
        Pull    "R0,PC"

; * Checksummer - Make a checksum of some area of RAM.
; Entry - R0 -> RAM to checksum
;         R1 Number of bytes to checksum.
; Exit  - R0 A Byte checksum of the Area.
make_checksum ROUT
        Push    "R2-R3"
        ADD     R1, R1, R0              ; R1 -> End of RAM to check.
        MOV     R2, #0                  ; R2 Checksum register.
10
        LDRB    R3, [R0], #1
        EOR     R2, R3, R2, ASL#1
        CMP     R0, R1
        BLT     %BT10
        MOV     R0, R2                  ; R0 Checksum of RAM.
        Pull    "R2-R3"
        MOV     PC, R14

; * Crypt - Encrypt password
; Entry - R0 -> Password string
; Exit  - R1 = Encrypted 32 bit number
Crypt_Passwd ROUT
        Push    "R0,R2-R3,LR"
        MOV     R1, #0
10
        LDRB    R2, [R0], #1
        CMP     R2, #' '
        Pull    "R0,R2-R3,PC", LT
        ADD     R1, R2, R1, ASL#1
        TST     R2, #1                  ; Is bit 0 set?
        MOVNE   R1, R1, ROR R2
        B       %BT10
Crypt_PasswdEnd
        DCD     0                       ; Now I wonder why this is here.
        ASSERT  (. - Crypt_Passwd) = ?Wsp_Crypt

; * ClaimFS
claim_filingsystem
        Push    "R0-R4,LR"
        MOV     R0, #FSCV
        ADR     R1, Our_FSCV
        MOV     R2, R12
        SWI     XOS_Claim               ; Claim FSControl Vector
        MOV     R0, #FSControl_LookupFS
        LDRB    R1, Wsp_CMOSset + 4
        MOV     R2, #0
        SWI     XOS_FSControl
        CMP     R2, #0                  ; Is our special FS there?
        Pull    "R0-R4,PC", EQ          ; If not, sulk.
        BL      insert_foot_in_door     ; Redirect the FSBlock to US!
        ADRL    R0, Scan_DriveNames
        MOV     R1, R12
        SWI     XOS_AddCallBack         ; Get the Hard Drive Names.
        MOV     R0, #ByteV
        ADRL    R1, Our_ByteV
        MOV     R2, R12
        SWI     XOS_Claim               ; Claim the OsByte Vector.
        Pull    "R0-R4,PC"

; * ReleaseFS
release_filingsystem ROUT
        Push    "R0-R4,LR"
        BL      remove_foot_from_door   ; Put FSBlock back the way it was
        BVS     %FT10
        MOV     R0, #ByteV
        ADRL    R1, Our_ByteV
        MOV     R2, R12
        SWI     XOS_Release             ; Release the OsByte Vector.
        MOV     R0, #FSCV               ; R0 = FSControlVector
        ADR     R1, Our_FSCV
        MOV     R2, R12
        SWI     XOS_Release             ; Release FSControl Vector
10
        STRVS   R0, [R13]
        Pull    "R0-R4,PC"

; Entry - R2 -> FSBlock
;
insert_foot_in_door
        Push    "R0-R2,LR"
        LDR     R0, [R2, #FS_open]      ; Get FSBlock FS_Open
        ADR     R1, Our_FS_Open         ; Get our FS_Open
        CMP     R0, R1                  ; Are they the same?
        Pull    "R0-R2,PC", EQ          ; If so, get the **** outta here
        ; First, grab the old vectors
        STR     R2, Wsp_FSBlock
        LDR     R0, [R2, #FS_open]
        STR     R0, Wsp_FS_Open
        LDR     R0, [R2, #FS_file]
        STR     R0, Wsp_FS_File
        LDR     R0, [R2, #FS_func]
        STR     R0, Wsp_FS_Func
        ; Now stuff in the new ones
        ADR     R0, Our_FS_Open
        STR     R0, [R2, #FS_open]
        ADR     R0, Our_FS_File
        STR     R0, [R2, #FS_file]
        ADR     R0, Our_FS_Func
        STR     R0, [R2, #FS_func]
        Pull    "R0-R2,PC"

remove_foot_from_door
        Push    "R0-R2,LR"
        LDR     R2, Wsp_FSBlock         ; R2 -> The Block In Question
        CMP     R2, #0
        Pull    "R0-R2,PC", EQ

        ; Check if somebody else is on there over us
        LDR     R0, [R2, #FS_open]
        ADRL    R1, Our_FS_Open
        TEQ     R0, R1
        BNE     foot_stuck
        LDR     R0, [R2, #FS_file]
        ADRL    R1, Our_FS_File
        TEQ     R0, R1
        BNE     foot_stuck
        LDR     R0, [R2, #FS_func]
        ADRL    R1, Our_FS_Func
        TEQ     R0, R1
        BNE     foot_stuck

        ; Now remove ourselves
        LDR     R0, Wsp_FS_Open
        STR     R0, [R2, #FS_open]      ; Restore FS_Open
        LDR     R0, Wsp_FS_File
        STR     R0, [R2, #FS_file]      ; Restore FS_File
        LDR     R0, Wsp_FS_Func
        STR     R0, [R2, #FS_func]      ; Restore FS_Func
        MOV     R0, #0
        STR     R0, Wsp_FSBlock
        Pull    "R0-R2,PC"

foot_stuck
        ADR     R0, ErrorBlock_FSLockInterceptTwice
        BL      MakeError
        STR     R0, [R13]
        Pull    "R0-R2,PC"

        MakeInternatErrorBlock FSLockInterceptTwice,,"ERR12"

; ** Vector code

Our_ByteV
        CMP     R0, #OsByte_WriteCMOS   ; Is it Write to CMOS?
        MOVNE   PC, R14                 ; No so let it past.
        Push    "R11"
        LDRB    R11, Wsp_CMOSset + 6    ; Check CMOS RAM protection quench
        TEQ     R11, #0
        Pull    "R11"
        MOVNE   PC, R14
        ADR     R0, ErrorBlock_FSLockConfigProt
        Pull    "LR"                    ; It is so intercept it.
        B       MakeError

        MakeInternatErrorBlock FSLockConfigProt,,"ERR9"

Our_FSCV
        Push    "R0-R1,R8,LR"
        MRS     R8, CPSR
        CMP     R0, #FSControl_AddFS    ; Is it ADD_FS?  If not, let it past
        ADREQ   R0, CallbackCode
        MOVEQ   R1, R12
        SWIEQ   XOS_AddCallBack
        MSR     CPSR_f, R8
        Pull    "R0-R1,R8,PC"

CallbackCode
        Push    "R0-R4,LR"
        MOV     R0, #FSControl_LookupFS
        LDRB    R1, Wsp_CMOSset + 4
        MOV     R2, #0
        SWI     XOS_FSControl
        CMP     R2, #0                  ; Is our special FS there?
        BLNE    insert_foot_in_door     ; If so, redirect the FSBlock!
        Pull    "R0-R4,LR"

Our_FS_Open
        Push    "R0,R1,LR"

        Debug   diag, "FS_Open", R0, R1

        SWI     FSLock_Version
        MOV     R11, R1
        Pull    "R0,R1,LR"
        CLRV
        Push    "LR"
        BL      Check_workspace         ; Ensure workspace is okay.
        BL      Check_R1_path
        Pull    "LR"
        LDRVC   PC,[R11,#:INDEX:Wsp_FS_Open] ; Pass on the call
        CMP     R0,#fsopen_CreateUpdate ; Is this an OPENOUT?
        BEQ     abort_err               ; If so, naughty naughty! Smack hands!
        MOV     R0,#0                   ; All other open calls are OPENINs...
        LDR     R11,[R11,#:INDEX:Wsp_FS_Open] ; Pass on the call modified.
        B       clv_pass_on

Our_FS_File
        Push    "R0-R1,LR"

        Debug   diag, "FS_File", R0, R1

        SWI     FSLock_Version
        MOV     R11, R1
        Pull    "R0,R1,LR"
        CMP     R0, #fsfile_ReadInfoNoLen
        LDRHS   R11, [R11, #:INDEX:Wsp_FS_File]
        BHS     clv_pass_on             ; Pass on the call, clearing V
        CMP     R0, #fsfile_ReadInfo
        LDREQ   R11, [R11, #:INDEX:Wsp_FS_File]
        BEQ     clv_pass_on             ; Pass on the call, clearing V
        CLRV
        Push    "LR"
        BL      Check_workspace         ; Ensure workspace is okay.
        BL      Check_R1_path
        Pull    "LR"
        LDRVC   PC, [R11, #:INDEX:Wsp_FS_File] ; Pass on the call
        B       abort_err

Our_FS_Func
        Push    "R0-R1,LR"

        Debug   diag, "FS_Open", R0, R1

        SWI     FSLock_Version
        MOV     R11, R1
        Pull    "R0,R1,LR"
        CMP     R0, #fsfunc_Opt
        CMPEQ   R1, #4                  ; Is it *Opt 4 ?
        BEQ     BloodySpecialCase       ; If so, process
        CMP     R0, #fsfunc_Rename
        CMPNE   R0, #fsfunc_Access
        CMPNE   R0, #fsfunc_AddDefect
        CMPNE   R0, #fsfunc_WriteBootOption
        CMPNE   R0, #fsfunc_NameDisc
        LDRNE   R11, [R11, #:INDEX:Wsp_FS_Func]
        BNE     clv_pass_on             ; Pass on the call, clearing V
        CLRV
        Push    "R1, LR"
        BL      Check_workspace         ; Ensure workspace is okay.
        BL      Check_R1_path
        TEQ     R0, #fsfunc_Rename      ; Is this Func_Rename? (teq doesn't affect V)
        MOVEQ   R1, R2                  ; If so, we need to check r2 too
        BLEQ    Check_R1_path           ;   so check r2.
        Pull    "R1,LR"
        LDRVC   PC, [R11, #:INDEX:Wsp_FS_Func] ; Pass on the call
        B       abort_err

clv_pass_on
        CLRV
        MOV     PC, R11                 ; branch to specified address.

abort_err
        ADR     R0, ErrorBlock_FSLockDiscWriteProt
        MOV     R12, R11
        B       MakeError

        MakeInternatErrorBlock FSLockDiscWriteProt,,"ERR5"

BloodySpecialCase ROUT
        Push    "R0-R5,LR"
        SUB     R13, R13, #256
        MOV     R0, #FSControl_ReadFSName
        LDRB    R1, [R11, #:INDEX:Wsp_CMOSset + 4]
        MOV     R2, R13
        MOV     R3, #256
        SWI     XOS_FSControl
        BVS     %FT20
        MOV     R1, R13
10
        LDRB    R14, [R1, #1]!
        TEQ     R14, #0
        BNE     %BT10
        MOV     R14, #':'
        STRB    R14, [R1], #1
        MOV     R14, #'@'
        STRB    R14, [R1], #1
        MOV     R14, #0
        STRB    R14, [R1]
        MOV     R0, #FSControl_CanonicalisePath
        MOV     R1, R13
        MOV     R2, R13
        MOV     R3, #0
        MOV     R4, #0
        MOV     R5, #256
        SWI     XOS_FSControl
        BVS     %FT20
        MOV     R1, R13
        BL      Check_R1_path
        ADD     R13, R13, #256
        Pull    "R0-R5,LR"
        BVS     abort_err
        LDR     PC, [R11, #:INDEX:Wsp_FS_Func] ; Pass on the call
20
        CMP     R0, R0                  ; CLRV
        ADD     R13, R13, #256
        LDMFD   R13!, {R0-R5,R14}
        LDR     PC, [R11,#:INDEX:Wsp_FS_Func]

filepathstring
        DCB     "FileSwitch$$<FileSwitch$$CurrentFilingSystem>$$CSD", 0
        ALIGN

; * Misc

Check_R1_path ROUT
        ; Assumes the path in R1 is a full one. Or at least has the volume name
        ;   started with a colon.
        ; Returns V set if names match or V is already set. Preserves all registers.
        MOVVS   PC, R14
        Push    "R0-R3,LR"
        MOV     R0, R1

        DebugS  diag, "Rename check", R1

        BL      Find_Volume_Name        ; Extract volume name from path
        MOV     R2, R1                  ; R2 = length of volume name
        MOV     R1, R0                  ; R1 -> volume name
        ADD     R0, R11, #:INDEX:Wsp_Hard1 ; R0 -> first volume name
        BL      String_Compare_CaseInsens
        BVS     %FT20
        ADD     R0, R11, #:INDEX:Wsp_Hard2 ; R0 -> second volume name
        BL      String_Compare_CaseInsens
        BVS     %FT20
        ADD     R0, R11, #:INDEX:Wsp_Hard3 ; R0 -> third volume name
        BL      String_Compare_CaseInsens
        BVS     %FT20
        ADD     R0, R11, #:INDEX:Wsp_Hard4 ; R0 -> fourth volume name
        BL      String_Compare_CaseInsens
        BVS     %FT20
10
        CLRV
        Pull    "R0-R3,PC"
20
        CLRV
        ADD     R1, R1, R2              ; r1 -> next char after end of drive name
        Push    "R1"

        ADD     R0, R11, #:INDEX:Wsp_MsgBlock
        ADR     R1, special_path1
        MOV     R2, #0
        SWI     XMessageTrans_Lookup
        Pull    "R1", VS
        BVS     %BT10

        MOV     R0, R2
        MOV     R2, R3
        LDR     R1, [R13]
        BL      StrCmp_CaseInsens
        Pull    "R1", VS
        BVS     %BT10

        ADD     R0, R11, #:INDEX:Wsp_MsgBlock
        ADR     R1, special_path2
        MOV     R2, #0
        SWI     XMessageTrans_Lookup
        Pull    "R1", VS
        BVS     %BT10
        MOV     R0, R2                  ; String
        MOV     R2, R3                  ; Length
        LDR     R1, [R13]               ; User's
        BL      StrCmp_CaseInsens
        ADD     R13, R13, #4            ; Junk R1
        BVS     %BT10
        SETV
        Pull    "R0-R3,PC"              ; Unstack registers, exit with V set

        DCB     "SPTH"
special_path1
        DCB     "Path1", 0
        ALIGN
Rnd1
        DCD     0
Rnd1End
special_path2
        DCB     "Path2", 0
        ALIGN
Rnd2
        DCD     0
Rnd2End

read_passwd_in ROUT
; In:
;   R0 -> area where the password will be stored.
;   R1 = area size
;   R2 -> prompt token
; Out:
;   R0 -> start of password
;   R1 = length of password (excl return)
;
; Returns the start of the password back in R0
        Push    "R0,R2-R4,LR"
        MOV     R0, R2
        BL      GSWrite0
        BVS     %FT10
        LDR     R0, [R13, #0]
        MOV     R2, #0
        MOV     R3, #255
        MOV     R4, #'-'

        ASSERT  No32bitCode <> No26bitCode ; FSLock is a ROM only module, so can't be both 26/32
      [ No32bitCode
        ORR     R0, R0, #&40000000
        SWI     XOS_ReadLine
      |
        ORR     R4, R4, #&40000000
        SWI     XOS_ReadLine32
      ]
        BVS     %FT10
        BCS     read_gotescape
        LDR     R0, [R13]
        MOV     R2, #0
        STRB    R2, [R0, R1]
10
        STRVS   R0, [R13, #0]
        Pull    "R0,R2-R4,PC"

read_gotescape
        MOV     R0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte
        Pull    "R0,R2-R4,LR"
        ADR     R0, ErrorBlock_Escape
        B       MakeError

        MakeInternatErrorBlock Escape,,"Escape"

; * Scrub
scrub_wkspace ROUT
        Push    "R0-R2,LR"
        SavePSR R14
        MOV     R0, #0                  ; Colour to scrub the workspace
        ADR     R1, Wsp_ScrubStart      ; R1 -> Start of area to scrub
        ADR     R2, Wsp_ScrubEnd        ; R2 -> End of area to scrub (+1)
10
        STR     R0, [R1], #4
        CMP     R1, R2
        BLO     %BT10
        RestPSR R14,,f
        NOP
        Pull    "R0-R2,PC"

; * Check workspace
; This will check that the workspace has not been tampered with....
Check_workspace
        Push    "R0-R4,R12,LR"
        SavePSR R4
        LDR     R0, Default_Password
        ADRL    R1, Module_BaseAddr
        ADR     R2, CRC_Value
        MOV     R3, #1
        SWI     XOS_CRC
        LDR     R1, CRC_Value
        CMP     R0, R1
        BNE     Sulk

        SWI     FSLock_Version
        MOV     R12, R1
        ADR     R0, Wsp_Hard1
        ASSERT  Wsp_Hard1 + ?Wsp_Hard1 = Wsp_Hard2
        ASSERT  Wsp_Hard2 + ?Wsp_Hard2 = Wsp_Hard3
        ASSERT  Wsp_Hard3 + ?Wsp_Hard3 = Wsp_Hard4
        ASSERT  Wsp_Hard4 + ?Wsp_Hard4 = Wsp_CMOSset
        MOV     R1, #Wsp_CMOSset + 6 - Wsp_Hard1
        BL      make_checksum           ; Get the checksum of the workspace...
        AND     R0, R0, #&FF
        ADR     R1, Wsp_CMOSset + 7
        LDRB    R1, [R1]                ; Get the workspaces copy of its checksum.
        CMP     R0, R1
        Pull    "R0-R4,R12,PC", EQ      ; Return if workspace is untampered with.
        BL      ensure_cmos_valid       ; Valiate CMOS and workspace settings.
        BL      Scan_DriveNames         ; ReScan the HD names and Store CMOS checksum.
        RestPSR R4,,f
        NOP
        Pull    "R0-R4,R12,PC"

; * Get the Hard Drive names to be locked.
; Assumes the ReadArgs buffer can be corrupted.
Scan_DriveNames ROUT
        Push    "R0-R11,LR"
        ADR     R1, Wsp_CMOSset + 4
        LDRB    R1, [R1]                ; Load the FS number from Workspace.
        MOV     R0, #FSControl_ReadFSName
        ADR     R2, Wsp_ReadArg
        MOV     R11, R2                 ; R11 -> Start of String.
        MOV     R3, #?Wsp_ReadArg
        SWI     XOS_FSControl           ; Get the FS name at start of ReadArgs workspace.
        Pull    "R0-R11,PC", VS         ; Exit if V is set by FSControl SWI....
        MOV     R0, #0
10
        LDRB    R1, [R2, R0]
        ADD     R0, R0, #1
        CMP     R1, #0                  ; Is it a null?
        BNE     %BT10
        SUB     R0, R0, #1
        MOV     R1, #':'
        STRB    R1, [R2, R0]            ; Plonk an ASCII colon on the end.
        ADD     R0, R0, #1
        STRB    R1, [R2, R0]            ; Do it again. String should now look like. <FSName>::
        ADD     R0, R0, #1
        MOV     R1, #'4'                ; Drive number next...
        STRB    R1, [R2, R0]            ; Store it in the string.
        ADD     R10, R0, R2             ; R10 -> Spot to stick drive number char in...
        MOV     R1, #'.'
        ADD     R0, R0, #1
        STRB    R1, [R2, R0]            ; Put a dot on the string.
        MOV     R1, #'$'
        ADD     R0, R0, #1              ; Put a dollar sign in.
        STRB    R1, [R2, R0]
        MOV     R1, #0
        ADD     R0, R0, #1
        STRB    R1, [R2, R0]            ; Null terminate the thing. String should be <FSName>colon colon 4.$
        MOV     R9, #'4'                ; R9 = ASCII drive number 4....
        ADD     R8, R2, R0
        ADD     R8, R8, #1              ; R8 -> Buffer area for FSControl to fill in.
20
        MOV     R0, #FSControl_CanonicalisePath
        MOV     R1, R11
        MOV     R2, R8
        MOV     R3, #0
        MOV     R4, #0
        MOV     R5, #100
        CMP     R9, #'4'
        MOVEQ   R7, #:INDEX:Wsp_Hard1
        CMP     R9, #'5'
        MOVEQ   R7, #:INDEX:Wsp_Hard2
        CMP     R9, #'6'
        MOVEQ   R7, #:INDEX:Wsp_Hard3
        CMP     R9, #'7'
        MOVEQ   R7, #:INDEX:Wsp_Hard4
        ADD     R7, R7, R12             ; R7 -> Workspace to put Hard Drive name.
        SWI     XOS_FSControl           ; Get the full path name of the drive.
        BVS     %FT30
        MOV     R0, R8
        BL      Find_Volume_Name        ; Get the volume name pointers.
        MOV     R2, R1                  ; R2 No. of Bytes of Volume Name exclusive of dot.
        MOV     R1, R7
        BL      StringCopy
30
        MOVVS   R0, #0                  
        STRVS   R0, [R7]                ; If we got an error from the SWI store a null string.
        ADD     R9, R9, #1              ; Increment the ASCII drive number
        STRB    R9, [R10]               ; Alter the path to be canonaclised.
        CMP     R9, #'8'
        BLT     %BT20                   ; Keep going till all drives scanned.
        ADR     R0, Wsp_Hard1
        ASSERT  Wsp_Hard1 + ?Wsp_Hard1 = Wsp_Hard2
        ASSERT  Wsp_Hard2 + ?Wsp_Hard2 = Wsp_Hard3
        ASSERT  Wsp_Hard3 + ?Wsp_Hard3 = Wsp_Hard4
        ASSERT  Wsp_Hard4 + ?Wsp_Hard4 = Wsp_CMOSset
        MOV     R1, #Wsp_CMOSset + 6 - Wsp_Hard1
        BL      make_checksum           ; Get the checksum of the workspace...
        ADR     R1, Wsp_CMOSset + 7
        CLRV
        STRB    R0, [R1]                ; Store the workspaces copy of its checksum.
        Pull    "R0-R11,PC"

; * Sulk
; Routine to lock machine if problem encountered.
Sulk
        MOV     R0, #OsByte_RW_BreakEscapeAction
        MOV     R1, #3
        SWI     OS_Byte
        ADR     R0, SulkString
        BL      GSWrite0
        SWI     XOS_EnterOS

        ASSERT  No32bitCode <> No26bitCode ; FSLock is a ROM only module, so can't be both 26/32
      [ No32bitCode
        WritePSRc F_bit+I_bit+SVC_mode,R0  ; ->SVC26, I,F
      |
        MSR     CPSR_c, #F32_bit+I32_bit+ABT32_mode ; Confuse poor dears. Go into ABT32 and lock.
      ]
Sulk_Loop
        B       Sulk_Loop
SulkString
        DCB     "Sulk", 0
        ALIGN

Find_Volume_Name
; Expects R0 points to full path name to find volume name from.
; Returns R0 address of first character of volume name.
;         R1 length of volume name (excluding terminator)
        Push    "R2"
10
        LDRB    R2, [R0], #1            ; Load a char.
        CMP     R2, #':'                ; Is it a colon?
        BNE     %BT10
        LDRB    R2, [R0]
        CMP     R2, #':'
        ADDEQ   R0, R0, #1              ; Correct r0 if the next char is not colon
        MOV     R1, #0                  ; R1 = length of volume name.
20
        LDRB    R2, [R0, R1]            ; Load a char
        CMP     R2, #'.'
        CMPNE   R2, #0                  ; Is it a dot or a null?
        ADDNE   R1, R1, #1              ; If neither, then increment counter
        BNE     %BT20                   ;   and loop back.
        Pull    "R2"
        MOV     PC, R14                 ; Return to caller.

StringCopy ROUT
; Expects R0 to point to area to copy, R1 to destination area R2
;       the number of Bytes to move.
; Preserves all registers.
        Push    "R0-R7"
        MOV     R3, #0                  ; R3 string copy index.
        ADR     R5, FSLock_Title
        MOV     R6, #5                  ; R6 EOR string index.
10                                      
        LDRB    R4, [R0, R3]            ; R4 character to copy.
        LDRB    R7, [R5, R6]            ; R7 characer to EOR with for security.
        EOR     R4, R4, R7              ; EOR the two together.
        STRB    R4, [R1, R3]            ; Store the result.
        ADD     R3, R3, #1              
        SUBS    R6, R6, #1              ; Increment counters.
        MOVMI   R6, #5                  ; Reset counter if needed.
        CMP     R3, R2                  ; Have we copied the string?
        BLT     %BT10                   ; Nope. Keep looping.
        MOV     R4, #0                  
        STRB    R4, [R1, R3]            ; Null terminate copied string.
        Pull    "R0-R7"                 
        MOV     PC, R14                 ; Return to Caller. Midnight Caller perhaps?

String_Compare_CaseInsens ROUT
; Expects strings to be pointed to by R0,R1 & R2 contains length to
;   compare them by. Returns with V set if strings are the same.
;   R1 must be the non EOR'ed string to compare.
        Push    "R3-R8,LR"
        MOV     R3, #0                  ; R0 string index counter.
        MOV     R6, #5
        ADR     R7, FSLock_Title        ; R7 -> EOR string.
10
        LDRB    R4, [R0, R3]
        LDRB    R5, [R1, R3]
        LDRB    R8, [R7, R6]
        EOR     R4, R4, R8              ; Decrypt/EOR the char from R0.
        ASCII_LowerCase R4, R14
        ASCII_LowerCase R5, R14
        ADD     R3, R3, #1              ; Increment string index counter.
        CMP     R4, R5                  ; Are the chars the same?
        BNE     %FT40                   ; No so exit (V clear)
        SUBS    R6, R6, #1              
        MOVMI   R6, #5                  
        CMP     R3, R2                  ; Have we finished the compare?
        BLT     %BT10                   ; No so continue
        SETV
40
        Pull    "R3-R8,PC"              ; Exit to caller normally.

rminsert_cmd
        DCB     "%RMInsert "

FSLock_Title
        DCB     "FSLock", 0
FSLock_TitleEnd        
        ALIGN

StrCmp_CaseInsens ROUT
; Expects strings to be pointed to by R0,R1 & R2 contains length to
;   compare them by. Returns with V set if strings are the same.
        Push    "R3-R5,LR"
        MOV     R3, #0                  ; R0 string index counter.
50
        LDRB    R4, [R0, R3]
        LDRB    R5, [R1, R3]
        ASCII_LowerCase R4, R8
        ASCII_LowerCase R5, R8
        CMP     R4, R5                  ; Are the chars the same?
        BNE     %FT60                   ; No so exit
        ADD     R3, R3, #1              ; Increment string index counter.
        CMP     R3, R2                  ; Have we finished the compare?
        BLT     %BT50                   ; No so continue
        SETV
60
        Pull    "R3-R5,PC"              ; Exit to caller normally.

CRC_Value
        DCD     0
CRC_ValueEnd

      [ debug
        InsertNDRDebugRoutines
      ]

        ; This cheesy table gets trimmed off when the following bits of information are
        ; scrambled after linking, it avoids having to hunt for magic markers in binaries
        MACRO
        PatchInfo $label
        DCD     (($label.End - $label):SHL:24) :OR: ($label - Module_BaseAddr)
        MEND

        DCI       &E7FF1234
        PatchInfo CRC_Value
        PatchInfo Default_Password
        PatchInfo Crypt_Passwd
        PatchInfo Rnd1
        PatchInfo Rnd2
        DCI       &E7FF5678

        END
        