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

      [ international_help

Bye_Syntax              DCB "sd", 0
Bye_Help                DCB "hd", 0

CDDevices_Syntax        DCB "s3", 0
CDDevices_Help          DCB "h3", 0

CDFS_Syntax             DCB "s2", 0
CDFS_Help               DCB "h2", 0

CDROMBuffers_Syntax     DCB "s5", 0
CDROMBuffers_Help       DCB "h5", 0

CDROMDrives_Syntax      DCB "s4", 0
CDROMDrives_Help        DCB "h4", 0

CDSpeed_Syntax          DCB "sg", 0
CDSpeed_Help            DCB "hg", 0

Dismount_Syntax         DCB "si", 0
Dismount_Help           DCB "hi", 0

Drive_Syntax            DCB "sb", 0
Drive_Help              DCB "hb", 0

Eject_Syntax            DCB "s1", 0
Eject_Help              DCB "h1", 0

Free_Syntax             DCB "sj", 0
Free_Help               DCB "hj", 0

Lock_Syntax             DCB "s6", 0
Lock_Help               DCB "h6", 0

Mount_Syntax            DCB "sh", 0
Mount_Help              DCB "hh", 0

Play_Syntax             DCB "s8", 0
Play_Help               DCB "h8", 0

PlayList_Syntax         DCB "s9", 0
PlayList_Help           DCB "h9", 0

PlayMSF_Syntax          DCB "se", 0
PlayMSF_Help            DCB "he", 0

Stop_Syntax             DCB "sa", 0
Stop_Help               DCB "ha", 0

Supported_Syntax        DCB "sf", 0
Supported_Help          DCB "hf", 0

Unlock_Syntax           DCB "s7", 0
Unlock_Help             DCB "h7", 0

WhichDisc_Syntax        DCB "sc", 0
WhichDisc_Help          DCB "hc", 0

        ALIGN

      |

;-----------------------------------------------------------------------------------------------
;       This retrieves messages from the 'Messages' file for *Help, ie/ *Help CDDevices
;-----------------------------------------------------------------------------------------------

;-----------------------------------------------------------------------------------------------
; on entry:
;          r0 -> buffer to place string in
;          r1  = length of buffer
; on exit:
;          r0 -> a string to be XOS_PrettyPrinted
;          r1 - r6 and r12 can be corrupted
;-----------------------------------------------------------------------------------------------

Bye_Syntax
        DCB     "Syntax: *Bye", 0
        ALIGN
Bye_Help
        MOV     r4, #HELP_BYE
        B       %FT01

CDDevices_Syntax
        DCB     "Syntax: *CDDevices", 0
        ALIGN
CDDevices_Help
        MOV     r4, #HELP_CDDEVICES
        B       %FT01

CDFS_Syntax
        DCB     "Syntax: *CDFS", 0
        ALIGN
CDFS_Help
        MOV     r4, #HELP_CDFS
        B       %FT01

CDROMBuffers_Syntax
        DCB     "Syntax: *Configure CDROMBuffers <buffersize>", 0
        ALIGN
CDROMBuffers_Help
        MOV     r4, #HELP_CDROMBUFFERS
        B       %FT01

CDROMDrives_Syntax
        DCB     "Syntax: *Configure CDROMDrives <drives>", 0
        ALIGN
CDROMDrives_Help
        MOV     r4, #HELP_CDROMDRIVES
        B       %FT01

CDSpeed_Syntax
        DCB     "Syntax: *CDSpeed [<drive>] [<speed>]", 0
        ALIGN
CDSpeed_Help
        MOV     r4, #HELP_CDSPEED
        B       %FT01

Dismount_Syntax
        DCB     "Syntax: *Dismount [<disc spec.>]", 0
        ALIGN
Dismount_Help
        MOV     r4, #HELP_DISMOUNT
        B       %FT01

Drive_Syntax
        DCB     "Syntax: *Drive <drive>", 0
        ALIGN
Drive_Help
        MOV     r4, #HELP_DRIVE
        B       %FT01

Eject_Syntax
        DCB     "Syntax: *Eject [<drive>]", 0
        ALIGN
Eject_Help
        MOV     r4, #HELP_EJECT
        B       %FT01

Free_Syntax
        DCB     "Syntax: *Free [<disc spec.>]", 0
        ALIGN
Free_Help
        MOV     r4, #HELP_FREE
        B       %FT01

Lock_Syntax
        DCB     "Syntax: *Lock [<drive>]", 0
        ALIGN
Lock_Help
        MOV     r4, #HELP_LOCK
        B       %FT01

Mount_Syntax
        DCB     "Syntax: *Mount [<disc spec.>]", 0
        ALIGN
Mount_Help
        MOV     r4, #HELP_MOUNT
        B       %FT01

Play_Syntax
        DCB     "Syntax: *Play <track> [<drive>]", 0
        ALIGN
Play_Help
        MOV     r4, #HELP_PLAY
        B       %FT01

PlayList_Syntax
        DCB     "Syntax: *PlayList [<drive>]", 0
        ALIGN
PlayList_Help
        MOV     r4, #HELP_PLAYLIST
        B       %FT01

PlayMSF_Syntax
        DCB     "Syntax: *PlayMSF <from> <to> [<drive>]", 0
        ALIGN
PlayMSF_Help
        MOV     r4, #HELP_PLAYMSF
        B       %FT01

Stop_Syntax
        DCB     "Syntax: *Stop [<drive>]", 0
        ALIGN
Stop_Help
        MOV     r4, #HELP_STOP
        B       %FT01

Supported_Syntax
        DCB     "Syntax: *Supported", 0
        ALIGN
Supported_Help
        MOV     r4, #HELP_SUPPORTED
        B       %FT01

Unlock_Syntax
        DCB     "Syntax: *Unlock [<drive>]", 0
        ALIGN
Unlock_Help
        MOV     r4, #HELP_UNLOCK
        B       %FT01

WhichDisc_Syntax
        DCB     "Syntax: *WhichDisc", 0
        ALIGN
WhichDisc_Help
        MOV     r4, #HELP_WHICHDISC
        B       %FT01


;-----------------------------------------------------------------------------------------------
; Get the workspace pointer and reserved the return address
;-----------------------------------------------------------------------------------------------
01

        LDR     r12, [ r12 ]
        MOV     r6, r14

;-----------------------------------------------------------------------------------------------
; Build up the message tag for the *Help
; r4 = message number
;-----------------------------------------------------------------------------------------------

        ADR     r1, TempArea            ; "ha"<null>
        ADD     r4, r4, #"h"
        STR     r4, [ r1 ]

;-----------------------------------------------------------------------------------------------
; Look the message up in the 'Messages' file
;-----------------------------------------------------------------------------------------------

        ADR     r0, message_block
        ADR     r2, TempArea + 4
        MOV     r3, #128
        ASSERT  ?TempArea > 128+4
        SWI     XMessageTrans_Lookup

;-----------------------------------------------------------------------------------------------
; Swap the message file terminator for a CRLF
;-----------------------------------------------------------------------------------------------

        ADDVC   r2, r2, r3
        MOVVC   r14, #13
        STRVCB  r14, [r2], #1
        MOVVC   r14, #10
        STRVCB  r14, [r2], #1

;-----------------------------------------------------------------------------------------------
; Build up the message tag for the Syntax help
;-----------------------------------------------------------------------------------------------

        MOVVC   r14, #"s"
        STRVCB  r14, TempArea + 0

;-----------------------------------------------------------------------------------------------
; Look the message up in the 'Messages' file
;-----------------------------------------------------------------------------------------------

        ADRVC   r0, message_block
        ADRVC   r1, TempArea            ; "sa"<null>
        MOVVC   r3, #128
        ASSERT  ?TempArea > 128
        SWIVC   XMessageTrans_Lookup

;-----------------------------------------------------------------------------------------------
; Point r0 at the message, or error string
;-----------------------------------------------------------------------------------------------

        ADRVC   r0, TempArea + 4
        ADDVS   r0, r0, #4

;-----------------------------------------------------------------------------------------------
; Exit
;-----------------------------------------------------------------------------------------------

        CLRV
        MOV     pc, r6

;-----------------------------------------------------------------------------------------------

      ]

        END

