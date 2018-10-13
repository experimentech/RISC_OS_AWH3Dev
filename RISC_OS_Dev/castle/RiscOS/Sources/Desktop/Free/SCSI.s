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
; SCSIFS_entry
;
; Entry point for SCSIFS discs.
SCSIFS_entry

        Debug   xx,"scsi reason",r0

        TEQ     r0,#FreeReason_GetName
        BEQ     SCSIFS_GetName
        TEQ     r0,#FreeReason_GetSpace
        BEQ     SCSIFS_GetSpace
        TEQ     r0,#FreeReason_ComparePath
        BEQ     SCSIFS_ComparePath
        TEQ     r0,#FreeReason_GetSpace64
        BEQ     SCSIFS_GetSpace64

        Pull    "PC"

;-----------------------------------------------------------------------
; SCSIFS_GetName
;
; Put the name of the drive specified in r3 into the buffer at r2
;
SCSIFS_GetName

        Push    "r1-r3"

        Debug   xx,"Get name"

        MOV     r0,r3
        ADR     r1,disc_desc
        SWI     XSCSIFS_DescribeDisc
        Pull    "r1-r3,PC",VS

        ADD     r4,r1,#22

        LDRB    r14,[r4]
        CMP     r14,#" "
        MOVLE   r14,#":"
        STRLEB  r14,[r2],#1
        MOVLE   r4,r3

        MOV     r0,r2
        MOV     r3,#10
        BL      copy_r0r4r3_space  ; Copy name to buffer

        MOV     r0,#11             ; Name is 10 chars + terminator.

        Pull    "r1-r3,PC"
;-----------------------------------------------------------------------
; SCSIFS_GetSpace
;
; Put the free space on the drive specified in r3 into the buffer at r2
;
SCSIFS_GetSpace

        Push    "r1-r3"

        Debug   xx,"Get space"

        MOV     r0,r3
        ADR     r1,disc_desc
        SWI     XSCSIFS_DescribeDisc
        Pull    "r1-r3,PC",VS

        LDR     r0,[r1,#16]        ; Store disc size in buffer.
        STR     r0,[r2]

        MOV     r0,r3
        SWI     XSCSIFS_FreeSpace
        Pull    "r1-r3,PC",VS

        STR     r0,[r2,#4]         ; Free space
        LDR     r1,[r2]
        SUB     r1,r1,r0
        STR     r1,[r2,#8]         ; used space

        Pull    "r1-r3,PC"


;-----------------------------------------------------------------------
; SCSIFS_GetSpace64
;
; Put the free space on the drive specified in r3 into the buffer at r2
;

SCSIFS_GetSpace64

        Push    "r1-r5"

        ;amg: Bad code alert!
        ;scsi doesn't return 'SWI not known' when called with a undefined swi in its
        ;chunk. This means that the approach used with adfs where the error is used
        ;to indicate that FreeSpace64 is not supported can't be used. ARRRGGGGHHHHH!

        Debug   xx,"Get space64"

        MOV     r0,r3
        ADR     r1,disc_desc
        SWI     XSCSIFS_DescribeDisc
        Pull    "r1-r5,PC",VS

        LDR     r0,[r1,#16]        ; Store disc size in buffer.
        STR     r0,[r2]

        LDR     r0,[r1,#36]        ; and the high word
        STR     r0,[r2,#4]

        MOV     r0,r3
        MOV     r5,r2

        MOV     r1,#-1             ; see bad code alert above: we're going to
        MOV     r2,#-1             ; have to check whether these were modified

        SWI     XSCSIFS_FreeSpace64
        BVS     %FT02              ; this is expected to error in some circumstances, so we DO NOT
                                   ; return the VS to the caller

        CMP     r0,r3
        CMPEQ   r1,#-1             ; nothing modified, so the call actually failed!
        CMPEQ   r2,#-1
        BEQ     %FT02

        STR     r0,[r5,#8]         ; free space (low)
        STR     r1,[r5,#12]        ; free space (high)

        LDR     r3,[r5]            ; disc size (low)
        LDR     r4,[r5,#4]         ; disc size (high)

        mextralong_subtract r0,r1,r3,r4,r0,r1

        STR     r0,[r5,#16]        ; used space (low)
        STR     r1,[r5,#20]        ; used space (high)

        MOV     r0,#0              ; indicate that we handled the new reason code
02
        CLRV
        Pull    "r1-r5,PC"

;-------------------------------------------------------------------------
; SCSIFS_ComparePath
;
;

SCSIFS_ComparePath

        Push  "r0-r9"

        Debug  xx,"SCSIFS compare path"

        ADR    r1,dataarea
01
        LDRB   r0,[r2],#1
        CMP    r0,#"."
        Debug  xx,"Copy ",r0
        MOVEQ  r0,#0
        STRB   r0,[r1],#1
        CMP    r0,#0
        BNE    %BT01            ; Copy to first "."

        ADR    r3,dataarea
        MOV    r2,r3
        Push   "PC"
        B      SCSIFS_GetName
        MOV    r0,r0
        Debug  xx,"Got name ",r0

        ADR    r2,dataarea
        LDR    r3,[sp,#3*4]
        CMPSTR r2,r3

        Pull   "r0-r9,PC"


        LNK     s.NETFS
