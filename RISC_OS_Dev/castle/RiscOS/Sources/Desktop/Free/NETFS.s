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
;-------------------------------------------------------------------------
;
; NETFS_entry
;
; Entry point for NETFS discs.
NETFS_entry

        TEQ     r0,#FreeReason_GetName
        BEQ     NETFS_GetName
        TEQ     r0,#FreeReason_GetSpace
        BEQ     NETFS_GetSpace
        TEQ     r0,#FreeReason_ComparePath
        BEQ     NETFS_ComparePath


        Pull    "PC"

;-----------------------------------------------------------------------
; NETFS_GetName
;
; Put the name of the drive specified in r3 into the buffer at r2
;
NETFS_GetName

        Push    "r1-r3"

        Debug   xx,"Get NETFS name"

        ADD     r3,r3,#1         ; Skip ':'
        MOV     r1,r3

01
        LDRB    r0,[r1],#1
        CMP     r0,#32
        MOVLT   r0,#0
        STRB    r0,[r2],#1       ; Copy to buffer
        BGE     %BT01

        SUB     r0,r1,r3         ; Length of string + terminator.

        Pull    "r1-r3,PC"
;-----------------------------------------------------------------------
; NETFS_GetSpace
;
; Put the free space on the drive specified in r3 into the buffer at r2
;
NETFS_GetSpace

        Push    "r1-r6"

        MOV     r5,r3
        MOV     r14,r2

        Debug   xx,"NETFS Get space - Enumerate File servers."
        DebugS  xx,"looking for ",r3

        MOV     r0,#0
01
        ADR     r1,dataarea
        MOV     r2,#&100
        MOV     r3,#1
        SWI     XNetFS_EnumerateFSList
        Pull    "r1-r6,PC",VS

        ADD     r2,r1,#3
        CMPSTR  r2,r5                      ; Is this the disc we are looking for ?
        BEQ     %FT02

        CMP     r0,#-1
        BNE     %BT01

        ADR     r0,ErrorBlock_NotLoggedOn  ; Not found.
        MOV     r1,#0
        BL      LookupError
        Pull    "r1-r6,PC"

02
        Debug   xx,"Found server"

        SUB     r6,r0,#1          ; Server number.

        MOV     r0,#FileServer_ReadDiscFreeSpace  ; Get Disc free space
        ADD     r1,r1,#3          ; Pointer to FS name
        MOV     r2,r1             ; Compute disc name.

77      LDRB    r3,[r2],#1
        CMP     r3,#32
        MOVLE   r3,#&0D
        STRLEB  r3,[r2,#-1]       ; Put CR at end !!!!!!!!!
        BGT     %BT77

        SUB     r2,r2,r1          ; Get length.

        MOV     r3,#&100          ; Size of buffer.
        LDRB    r4,[r1,#-3]       ; Station number
        LDRB    r5,[r1,#-2]       ; Net number
        Debug   xx,"r4 r5",r4,r5
        SWI     XNetFS_DoFSOpToGivenFS
        Pull    "r1-r6,PC",VS
        Debug   xx,"r4 r5",r4,r5

        Debug   xx,"Read free disc space & disc size."

        LDRB    r0,[r1,#2]        ; Store disc size in buffer.
        LDRB    r2,[r1,#1]
        ADD     r0,r2,r0,ASL #8
        LDRB    r2,[r1,#0]
        ADD     r0,r2,r0,ASL #8   ; r0 = free disc space
        MOV     r0,r0,ASL #8

        LDRB    r3,[r1,#5]        ; Store disc size in buffer.
        LDRB    r2,[r1,#4]
        ADD     r3,r2,r3,ASL #8
        LDRB    r2,[r1,#3]
        ADD     r3,r2,r3,ASL #8   ; r3 = Total disc space
        MOV     r3,r3,ASL #8

        STR     r3,[r14]          ; Store size
        SUB     r3,r3,r0
        STR     r3,[r14,#8]       ; Used space.

;        MOV     r0,r6;
        ADR     r1,dataarea+40
;        MOV     r2,#&100
;        MOV     r3,#1
;        SWI     XNetFS_EnumerateFSList
;        Pull    "r1-r6,PC",VS


        MOV     r2,#1             ; Send <CR>
        MOV     r3,#&100          ; Size of buffer.
;        LDRB    r4,[r1]           ; Station number
;        LDRB    r5,[r1,#1]        ; Net number
        MOV     r0,#&0d
        STRB    r0,[r1]
        MOV     r0,#FileServer_ReadUserFreeSpace   ; Get user free space
        Debug   xx,"Read free space from n,s",r5,r4
        SWI     XNetFS_DoFSOpToGivenFS
        Pull    "r1-r6,PC",VS

        LDR     r0,[r1]
        Debug   xx,"Read user free space.",r0

        STR     r0,[R14,#4]

        LDR     r1,[r14]
        LDR     r2,[r14,#8]      ; Used space
        SUB     r1,r1,r2         ; r1 = free disc space
        CMP     r0,r1            ; if greater
        STRCS   r1,[R14,#4]      ; store disc size as free space.
        CLRV

        Pull    "r1-r6,PC"
;-------------------------------------------------------------------
ErrorBlock_NotLoggedOn
        DCD 0
        DCB "NotLogd",0
        ALIGN

;-------------------------------------------------------------------------
; NETFS_ComparePath
;
;

NETFS_ComparePath

        Debug  xx,"NETFS compare path"

        CMP     r6,#0
        Pull    "PC",EQ
        CMPSTR  r3,r6
        Pull    "PC"

        LNK     s.NFS
