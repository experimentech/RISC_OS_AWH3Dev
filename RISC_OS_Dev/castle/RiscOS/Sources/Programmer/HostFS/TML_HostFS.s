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
        TTL     TML_HostFS - Host Filing System via TML

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************

; Date       Name  Version Description
; ----       ----  ------- -----------
; 3-3-92     JSR      0.00 Written


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Proc
        GET     Hdr:EnvNumbers
        GET     Hdr:HostFS
        GET 	VersionASM

        LEADR   Module_LoadAddr

CR      *       13
LF      *       10
TAB     *       9

        ^     0, wp
TXEntry #       4
WSSize  *    :INDEX:@

; ****************** HostFile Module code starts here *************************

Module_BaseAddr

        DCD     0
        DCD     HostFS_Init     -Module_BaseAddr
        DCD     HostFS_Die      -Module_BaseAddr
        DCD     HostFS_Service  -Module_BaseAddr
        DCD     HostFS_Title    -Module_BaseAddr
        DCD     HostFS_Help     -Module_BaseAddr
        DCD     HostFS_HC_Table -Module_BaseAddr
        DCD     Module_SWISystemBase + TubeSWI * Module_SWIChunkSize
        DCD     HostFS_SWICode  -Module_BaseAddr
        DCD     HostFS_SWITable -Module_BaseAddr
        DCD     0
        DCD     0
        DCD     HostFS_Flags    -Module_BaseAddr

HostFS_Title
        DCB     "DA_HostFS", 0

HostFS_SWITable
        DCB     "HostFS", 0
        DCB     "HostVdu",0
        DCB     "TubeVdu",0
        DCB     "WriteC",0
        DCB     "ReadC",0
        DCB     "ReadCMaybe",0
        DCB     0

HostFS_Help
        DCB     "HostFS"
        DCB     TAB,TAB
        DCB     "$Module_MajorVersion $Module_MinorVersion ($Module_Date)", 0
        ALIGN

HostFS_Flags
        DCD     ModuleFlag_32bit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                 T U B E   C O M M A N D S   S E C T I O N
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

HostFS_HC_Table ; Name Max Min

        Command HostVdu,  0, 0
        Command TubeVdu,  0, 0
        DCB     0                       ; That's all folks !

HostVdu_Help
        DCB     "*HostVdu redirects vdu output to the BBC Host."
        DCB     CR
HostVdu_Syntax
        DCB     "Syntax: *HostVdu", 0

TubeVdu_Help
        DCB     "*TubeVdu redirects vdu output to the a500."
        DCB     CR
TubeVdu_Syntax
        DCB     "Syntax: *TubeVdu", 0

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

HostVdu_Code Entry

        SWI     XHostFS_HostVdu
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

TubeVdu_Code Entry

        SWI     XHostFS_TubeVdu
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; NB. Can't talk to Tube during initialisation, only after reset has come round

; r0-r6 trashable

HostFS_Init Entry "r8,r9"

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #WSSize
        SWI     XOS_Module
        EXIT    VS

        STR     r2, [r12, #0]
        MOV     wp, r2

        SWI     DADebugSWI_Base + Auto_Error_SWI_bit
        STR     r0, TXEntry
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Let Module handler take care of removing our workspace on fatal death
; or shunting it around on Tidy - none of it is absolute

HostFS_Die Entry

        MOV     r0, #WrchV              ; Release WrchV
        ADRL    r1, WRCHandler
        MOV     r2, wp
        SWI     XOS_Release
        CLRV

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

HostFS_Service * Module_BaseAddr

HostFS_SWICode ROUT
        LDR     wp, [r12, #0]
        CMP     r11, #MaxSwi            ; Number of valid SWI entries
        ADDLO   pc, pc, r11, LSL #2
        MOV     pc, lr

JumpTable
        B       DoHostVdu
        B       DoTubeVdu
        B       Host_WriteC
        B       Host_ReadC
        B       Host_ReadCMaybe

MaxSwi  *       (.-JumpTable) / 4


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DoHostVdu ENTRY "r0-r2"

        MOV     r0, #WrchV              ; Claim WrchV
        ADR     r1, WRCHandler
        MOV     r2, wp
        SWI     XOS_Claim
        STRVS   r0, [sp, #0]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DoTubeVdu ENTRY "r0-r2"

        MOV     r0, #WrchV              ; Release WrchV
        ADR     r1, WRCHandler
        MOV     r2, wp
        SWI     XOS_Release
        STRVS   r0, [sp, #0]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sit on WrchV printing characters to the Host

WRCHandler ROUT

        Pull    lr                      ; Claim it
        ; fall through

; In r0=char
; Out r10,r11 corrupted
Host_WriteC ROUT
        TEQ     pc, pc
        TEQNEP  lr, #0
        LDR     pc, TXEntry

; Out r0=char; r10,r11 corrupted
Host_ReadC ROUT
        ADR     r0, EscapeError
        SETV
        TEQ     pc, pc
        Pull    "r1-r3,r9,pc",EQ
        Pull    "r1-r3,r9,lr"
        ORRS    pc, lr, #V_bit

EscapeError
        DCD     17
        DCB     "Escape",0
        ALIGN

; Out r0=char or -1 of none available
Host_ReadCMaybe ROUT
        MOV     r0, #-1
        TEQ     pc, pc
        MOVEQ   pc, lr
        MOVS    pc, lr

        END
