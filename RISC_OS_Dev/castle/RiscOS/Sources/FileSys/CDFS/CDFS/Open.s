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
; Open

; PROCS:

; NumberOfNextFreeFileHandle
; INFO                              ; RISC OS 2 only
; AnotherDriveHasBeenAdded
; DisplayHeader                     ; RISC OS 2 only
; CheckDiscName
; ValidatePathName
; ShuffleStringUp       ( used by 'Directory' )
; ConvertBufferSizeToReal
; ConvertRealBufferToSize

;**************************************************************************
NumberOfNextFreeFileHandle ; Returns R0 = number of free handle, 0 if fail
;**************************************************************************

        Push    "R1, R3,R14"
                
        ADRL    R1, OpenFileList        ; R1 -> start of list
        MOV     R3, #MAXNUMBEROFOPENFILES

search_for_space                        ; look through list

        LDR     R14, [ R1 ], #4
                
        SUBS    R3, R3, #1
        TEQNE   R14, #0
        BNE     search_for_space
                
        TEQ     R14, #0
        RSBEQ   R0, R3, #MAXNUMBEROFOPENFILES
        MOVNE   R0, #0                  ; If not found then R0 = 0
                
        Pull    "R1, R3,PC"
        
        LTORG


;***************************************************************************
AnotherDriveHasBeenAdded ROUT ; R0 = drive number requested

; If an error, then V set, R0 -> error message

;***************************************************************************

        Push    "R0 - R9, R14"

        ; R5 = drive number requested
        ; R6 = device id
        ; R7 -> sparecontrolblock_offset

        LDRB    R6, numberofdrives      ; already know the drive number
        CMP     R0, R6                  ;
        Pull    "R0 - R9, PC", LO       ; exit, V (almost certainly) clear

;*******************
; Only allow the configured number of drives to be selected
;*******************

        LDR     R6, maxnumberofdrives   ; Error if not configged enough
        TEQ     R6, #0

        SUBNES  R6, R6, #1
        ; If 0 drives configged then make an exception

        RSBHSS  R14, R0, R6
        Pull    "R0 - R9, R14", LO
        
        BLO     baddrive

32

;*******************

; R3 = device id
; R4 = card number
; R5 = LUN
; R6 = drive number requested
; R7 -> control block

        MOV     R3, #0
        MOV     R4, #3

;----------------------------
; Logical unit number support
;----------------------------

        MOV     r5, #0
        MOV     R6, R0
        ADR     R7, sparecontrolblock
        
        ; 1. Find a drive that has been turned on

look_for_device


;**************
; CheckIDKnown                    ;
;**************

; R0 = composite id
; R1 -> list
; R2 -> end of list

        ORR     R0, R3, R4, LSL #3
        ORR     r0, r0, r5, LSL #5

        ADRL    R1, ListOfDrivesAttached ; R1 -> first entry
                
        LDRB    R2, numberofdrives      ; R2 -> last entry
        ADD     R2, R1, R2              ;

04

        LDRB    R14, [ R1 ], #1
                
        CMP     R1, R2
        BHI     %FT05                   ; Reached end of list - so NOT FOUND
                
        TEQ     R14, R0
                
        BNE     %BT04

;***************
; Next device
;***************
01                                      ; Found the drive - so don't bother to check

;---------------------------------
; Support for Logical Unit Numbers
;---------------------------------

        ; Faster because it searches for devices with LUN 0 first
        ADD     r3, r3, #1              ; Next device id
        ANDS    r3, r3, #2_111

        ADDEQ   r5, r5, #1              ; New LUN
        ANDS    r5, r5, #2_111

        TEQEQ   r3, #0
        SUBEQ   r4, r4, #1              ; Next card
        CMPEQ   r4, #-1                 ; Last card reached ?

        BNE     look_for_device

        Pull    "R0 - R9, R14"

        Debug   mi,"AnotherDriveHasBeenAdded returning error"

baddrive
        Push    "r1-r2, r14"
        addr    r0, baddrive_tag
        ADR     r1, message_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "r1-r2, pc"



;**************
; CheckDevice                     ; Is device a CDROM drive ?
;**************
05
        ; Make sparecontrolblock = device id
        MOV     R8, #0

        ;----------------------------------
        ; Preserve the Logical Unit Numbers
        ;----------------------------------

        STMIA   R7, { R3 - R5, R8 }
        STR     R8, [ R7, #16 ]

        ;-----------------------------------
        ; Not a good idea to forget the LUN
        ;-----------------------------------

06

        ; 2. Add drive number to list

        SWI     XCD_Identify
        BVS     %BT01
        
        CMP     r2, #-1
        BEQ     %BT01
        
        MOV     r9, r2

        ; R9 = drive type

        LDRB    R0, numberofdrives
                
        ADRL    R14, ListOfDrivesAttached
                
        ORR     R2, R3, R4, LSL #3

        ;---------------------------------
        ; Support for logical unit numbers
        ;---------------------------------

        ORR     r2, r2, r5, LSL #5
        STRB    R2, [ R14, R0 ]
                
        ADRL    R14, DriveTypes
        STRB    R9, [ R14, R0 ]
                
        ADD     R0, R0, #1
        STRB    R0, numberofdrives

;************
; Set SCSIControl          ; set the error response of the drive
;************              ;

        MOV     R0, #1
        SWI     XCD_Control             ; R0 = error level, R7 -> control block
                                        
                                        
        LDRB    R0, numberofdrives      ; Another drive been attached ?
                                        ;
        CMP     R0, R6                  ;
                                        ;
                                        
        BLS     look_for_device         
                                        
        Pull    "R0 - R9, PC"           



;***************************************************************************
CheckDiscName ROUT; R0 -> name, RETURNS R1 = TRUE/FALSE
;***************************************************************************

; ISO Spec allows the following characters in a disc name:

;               A - Z             0 - 9        _

; Justin allows the following characters in a disc name:

;               /   (because otherwise I can't open the linux CD)
;               -   (because otherwise I can't open Jan 1998 MSDN Platform
;                    Archive disc 1)
;               ,   (because someone said they'd found a disc that used that)

; JB .. also allow hard space &A0 and lowercase letters
; This routine converts CR to a null

        Push    "R0, R2"

01

        LDRB    R1, [ R0 ], #1
                                        
        TEQ     R1, #&0D                ; Convert CR to null
        TEQNE   R1, #SPACE              ; Convert SPACE to null
        MOVEQ   R1, #0                  ;
        CMP     R1, #32                 
        MOVLE   R1, #0                  
                                        
        STRB    R1, [ R0, #-1 ]         ; Converted to uppercase, and terminated
                                        
        Pull    "R0, R2", LE            ; last entry
        MOVLE   R1, #TRUE               ;
        MOVLE   PC, R14                 ;
                                        
        BIC     R2, R1, #32             ; clear the upper/lowercase bit
        CMP     R2, #"A"                ; characters 'A - Z'
        RSBHSS  R2, R2, #"Z"            ;
        BHS     %BT01                   ;
                                        
        CMP     R1, #"0"                ; characters '0 - 9'
        RSBHSS  R2, R1, #"9"            ;
        BHS     %BT01                   ;
                                        
        TEQ     R1, #"_"                ; character 'underline'
      [ AllowSlashInDiscName            
        TEQNE   R1, #"/"                ; character 'slash' (by Justin)
      ]                                 
      [ AllowHyphenInDiscName           
        TEQNE   R1, #"-"                ; character 'hyphen' (by Justin)
      ]                                 
      [ AllowCommaInDiscName            
        TEQNE   R1, #","                ; character 'comma' (by Justin)
      ]                                 
      [ AllowHardSpaceInDiscName        
        TEQNE   R1, #&A0                ; character 'hard space' (by Jwb)
      ]                                 
        BEQ     %BT01                   ;

02
        Pull    "R0, R2"
        MOV     R1, #FALSE
        MOV     PC, R14

;***************************************************************************
ConvertBufferSizeToReal ROUT ; R0 = CMOS number, RETURNS R1 = size in K
;    FLAGS CORRUPTED
;***************************************************************************

        Push    "R0, R14"

;**************
; Convert number into a Kbytes value
;**************

        TEQ     R0, #0
                
        MOVEQ   R1, #0
                
        MOVNE   R1, #1
        ADDNE   R0, R0, #2
        MOVNE   R1, R1, ASL R0
                
        Pull    "R0, PC"

;***************************************************************************
ConvertRealBufferToSize ROUT    ; R0 = number of K, RETURNS R1 = bit setting
;***************************************************************************

        Push    "R0, R2"

;**************
; Calculate the actual number to go in the CMOSRAM byte
; This is done by taking the top bit set in R0 ( from bits 9 to 0 )
; K    to  number
; 0    to    0
; 8    to    1
; 16   to    2
; 32   to    3
; 64   to    4
; 128  to    5
; 256  to    6
; 512  to    7
;**************

        MVN     R0, R0, ASL #22
        MOV     R2, #7
01                                      ; Top bit set or done enough bits ?
                                        ;
        MOVS    R0, R0, ASL #1          ;
        SUBCSS  R2, R2, #1              ;
        BCS     %BT01                   ; [ no ]


        CMP     R2, #0                  ; R2 = number to go in CMOS RAM
        MOVLT   R1, #0                  ;
        MOVGE   R1, R2

        Pull    "R0, R2"

        MOV     PC, R14

        LTORG

        END
