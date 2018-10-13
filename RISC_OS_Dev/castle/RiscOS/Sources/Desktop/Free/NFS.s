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

NFS_FreeSpace  * &410c5
NFS_FreeSpace64 * &410c6
XNFS_FreeSpace * NFS_FreeSpace :OR: Auto_Error_SWI_bit
XNFS_FreeSpace64 * NFS_FreeSpace64 :OR: Auto_Error_SWI_bit

;-------------------------------------------------------------------------
;
; NFS_entry
;
; Entry point for NFS discs.
NFS_entry

        TEQ     r0,#FreeReason_GetName
        BEQ     NFS_GetName
        TEQ     r0,#FreeReason_GetSpace
        BEQ     NFS_GetSpace
        TEQ     r0,#FreeReason_ComparePath
        BEQ     NFS_ComparePath
        TEQ     r0,#FreeReason_GetSpace64
        BEQ     NFS_GetSpace64

        Pull    "PC"

;-----------------------------------------------------------------------
; NFS_GetName
;
; Put the name of the drive specified in r3 into the buffer at r2
;
NFS_GetName

        Push    "r1-r3"

        Debug   xx,"Get NFS name"

        MOV     r1,r3
        LDRB    r0,[r1]
        CMP     r0,#":"
        ADDEQ   r1,r1,#1

01
        LDRB    r0,[r1],#1
        STRB    r0,[r2],#1
        CMP     r0,#0
        BNE     %BT01

        SUB     r0,r1,r3         ; Length of string + terminator.

        Pull    "r1-r3,PC"

;-----------------------------------------------------------------------
; NFS_GetSpace
;
; Put the free space on the drive specified in r3 into the buffer at r2
;
NFS_GetSpace

        Push    "r1-r3"

        Debug   xx,"NFS Get space"

        MOV     r14,r2

        MOV     r1,r3
        SWI     XNFS_FreeSpace
        Pull    "r1-r3,PC",VS

        STR     r2,[r14]
        STR     r0,[r14,#4]         ; Free space

        SUB     r2,r2,r3
        STR     r2,[r14,#8]        ; used space

        Pull    "r1-r3,PC"

;-----------------------------------------------------------------------
; NFS_GetSpace64
;
; Put the free space on the drive specified in r3 into the buffer at r2
;
NFS_GetSpace64

        Debug   xx,"NFS Get space 64"
        SWI     XNFS_FreeSpace64
        Pull    "pc"

;-------------------------------------------------------------------------
; NFS_ComparePath
;
;

NFS_ComparePath

        Push    "r0-r9"

        Debug   xx,"NFS compare path"

        ADD     r2,r2,#1
                
        ADR     r1,dataarea
01              
        LDRB    r0,[r2],#1
        CMP     r0,#"."
        Debug   xx,"Copy ",r0
        MOVEQ   r0,#0
        STRB    r0,[r1],#1
        CMP     r0,#0
        BNE     %BT01            ; Copy to first "."
                
        ADR     r2,dataarea

        CMPSTR  r2,r3

        Pull    "r0-r9,PC"

        LNK     PCCardFS.s
