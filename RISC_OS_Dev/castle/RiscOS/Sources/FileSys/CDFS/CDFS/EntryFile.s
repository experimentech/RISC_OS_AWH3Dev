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
; ->EntryFile

;*************************************************************************
;*************************************************************************

; This part deals with the FSEntry_File part of FileSwitch

; It contains:

;             LoadFile
;             ReadCatalogue
;             SaveFile       - is now in 'Error'
;             ReadBlockSize  - RISC OS 3

;*************************************************************************
;*************************************************************************

;*************************************************************************
LoadFile
;*************************************************************************

; on entry:
; R0 = 255
; R1 -> pointer to pathname
; R2 = address to load file
; R6 -> pointer to special field if present

; on exit:
; R0 is corrupted
; R2 = load address
; R3 = execution address
; R4 = file length
; R5 = file attributes
; R6 = pointer to name for printing *OPT 1 info


; R9 -> disc buffer



        Push    "R2"

        MOV     R0, R1

;*************************
; Dir: ( pathname$, RETURN pointer to block of object info, 0 if not found,
;                   RETURN R2 = 1 if a file, 2 if a directory )
;                   RETURN R3 -> start of disc buffer
;                   RETURN R4 = drive number
        MOV     R1, #0                  ; Looking for a file
        BL      Dir                     
;*************************

        MOV     r8, r4
        
        MOV     r9, r3
        
        Pull    "r2"
        
        STR     r1, temp2               ; R1 -> entry details



;------------------------------------
; Added in version 2.23 30-Aug-94
; Read mode 2 form 2 files properly
;------------------------------------

; r1 -> Object information
; r3 =  mode of disc

        MACRO__XA_WHAT_DATA_MODE r0, r1, r2, r3
                
        TEQ     r0, # 2
        BNE     LoadFile_Ordinary


;***************
; Work out actual lba start offset - for different size logical blocks
;***************

; R3 = start LBA
; R5 = block size

        LDR     r5, [ r1, # LBASTARTOFFSET ]
        MOV     r5, r5, LSR #8          ; remove objecttype rubbish
                
        STR     r5, temp1               ; temp1 = Start LBA
                
        MOV     r6, r2                  ; R6 -> start of load address
                
        LDR     r2, [ r1, # LENGTHOFFSET ]
                
        MOV     r0, r8
        BL      PreConvertDriveNumberToDeviceID
        BVS     ErrorExit
                
        MOV     r0, # 2
        BL      ChangeDiscMode          ; R0 = mode, R7 -> control block

; XCD_ReadUserData
; on entry:
;          r0 =  LBAFormat (0)
;          r1 =  block
;          r2 =  length in bytes
;          r3 -> memory
;          r7 -> control block

        CLRV
                
        MOV     r0, #LBAFormat
        MOV     r1, r5
        MOV     r3, r6
                
        CMP     r2, # 0
        SWIGT   XCD_ReadUserData
                
        BVS     ErrorExit

        ; exit neatly

02

        PullAllFromFrame
        LDR     r6, temp2
        
        LDMIB   r6, { r2, r3, r4 }
        
        LDRB    r5, [ r6, # FILEATTRIBUTESOFFSET ]
        
        ADD     r6, r6, # OBJECTNAMEOFFSET
        
        MOV     pc, r14 ; V still clear





;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
LoadFile_Ordinary

        LDR     R4, [ R1, #LENGTHOFFSET ]

        MOV     R5, #myblocksize
        DivRem  R7, R4, R5, R14, norem  ; r7 = r4 DIV r5


;***************
; Work out actual lba start offset - for different size logical blocks
;***************

; R3 = start LBA
; R5 = block size

        MOV     R4, #myblocksize
                
        LDR     R5, [ R9, #DiscBuff_BlockSize ]
                
        DivRem  R6, R4, R5, R14, norem  ; R6 = log. sec size / lbsize
                
        LDR     R5, [ R1, #LBASTARTOFFSET ]
        MOV     R5, R5, LSR #8          ; remove objecttype rubbish
                
;------------------------------------------------------
; Make sure that don't try to divide by 0 or locks up !
;------------------------------------------------------

        TEQ     r6, #0

        MOVEQ   r0, #ERROR_INTERNALERROR
        BEQ     ErrorExit

;------------------------------------------------------


        DivRem  R3, R5, R6, R14, norem  ; R3 = start LBA / R6
        
        STR     R3, temp1               ; temp1 = STart LBA
                
        MOV     R6, R2                  ; R6 -> start of load address
                
        MOV     R2, R7                  ; Load less than or equal number of blocks


; number_of_bytes - ( ( number_of_bytes DIV blocksize ) * blocksize )

; ( ABOVE function ) this gives the number of bytes left in the last block

        MOV     R0, R8
        BL      PreConvertDriveNumberToDeviceID
        BVS     ErrorExit
                
        LDRB    R0, [ R9, #DiscBuff_DiscMode ]
        BL      ChangeDiscMode          ; R0 = mode, R7 -> control block


        MOV     R0, #LBAFormat
        MOV     R1, R3
        MOV     R3, R6
                
        MOV     R4, #myblocksize
                
        CMP     R2, #0
        SWIGT   XCD_ReadData

        BVS     ErrorExit

; Load in the remaining bytes from the last block

                                 ; R2 = NUMBER_OF_BYTES DIV BLOCKSIZE

; LDR R1, [ R9, #DiscBuff_BlockSize ]
        MOV     R1, #myblocksize
                
        MUL     R3, R1, R2              ; R3 = number of bytes loaded so far
                
                
        LDR     R14, temp2
        LDR     R4, [ R14, #LENGTHOFFSET ] ; R4 = number_of_bytes
                
        SUBS    R4, R4, R3              ; No more bytes to load ?
                                        ;
        BLE     %FT02                   ; [ all done ]


                      ; Load last block into temp buffer

                      ; then transfer correct number of bytes to their mem

 ; WORK OUT POSITION TO PUT BYTES AT

 ; R6 = start address of load

 ; R4 = number of bytes left to load

 ; R3 = number of bytes loaded so far

 ; R2 = number of blocks loaded so far



                               ; = position to dump rest of data


                               ; R3 = position to copy to


        ADD     R3, R3, R6
                
        LDR     R1, temp1               ; start LBA +
        ADD     R1, R1, R2              ; number of blocks = last block
                
        MOV     R0, #LBAFormat
                
        MOV     R2, #1

 ;   OK       WRONG       OK      OK           WRONG
 ; R0 = 0, R1 = block, R2 = 1, R3 -> place, R4 = number bytes


        SWI     XCD_ReadData
                
        BVS     ErrorExit

                           ; exit neatly

02

        PullAllFromFrame
        LDR     R6, temp2
        LDMIB   R6, { R2, R3, R4 }
                
        LDRB    R5, [ R6, #FILEATTRIBUTESOFFSET ]
                
        ADDS    R6, R6, #OBJECTNAMEOFFSET ; should clear V
                
        MOV     PC, R14



;*************************************************************************
ReadCatalogue ROUT
;*************************************************************************

; entry: R0 = 5
;        R1 = pointer to pathname ( null terminated )
;        R6 = pointer to special field if present, else 0

; exit:  R0 = 0 if not found, 1 if file, 2 if directory
;        R2 = load address
;        R3 = execution address
;        R4 = file length
;        R5 = file attributes

        log_on

        MOV     R0, R1


;***********************
; Dir: ( pathname$, RETURN pointer to block of object info, 0 if not found,
;                   RETURN R2 = 1 if a file, 2 if a directory )
;                   RETURN R3 -> start of disc buffer
;                   RETURN R4 = drive number
        MOV     R1, #2    ; Don't care what I find
        BL      Dir
;***********************


;************
; Object not found ( so tell fileswitch )
;************

        TEQ     R2, #object_nothing     ; If not found then tell FS
        PullAllFromFrame EQ             ;
        SUBEQS  R0, R0, R0              ; clears V
        MOVEQ   PC, R14                 ;

;************
; Was object a directory ? ( so get information from 'TempArea' )
;************

        TEQ     R2, #object_directory
        ADREQ   R1, TempArea
        STREQB  R2, [ R1, #OBJECTTYPEOFFSET ]

;************
; Save pointer to block of information
;************

02

        STR     R1, temp1
        PullAllFromFrame
        LDR     R1, temp1

;************
; Tell fileswitch about object
;************

        LDRB    R0, [ R1, #OBJECTTYPEOFFSET ]
        ASSERT  LOADADDRESS + 4 = EXECUTIONADDRESS
        ASSERT  EXECUTIONADDRESS + 4 = LENGTH
        LDMIB   R1, { R2, R3, R4 }
        LDRB    R5, [ R1, #FILEATTRIBUTESOFFSET ]

        CLRV
        MOV     PC, R14




;**********************************************************************************************
; FUNCTION: ReadBlockSize
;
; on entry:
;          r0 =  10
;          r1 -> filename
;          r6 -> special field, or 0
; on exit:
;          r2 = natural block size of file
;
; see page 4-30 of RISC OS 3 PRMs
;**********************************************************************************************
ReadBlockSize

; Just make sure that the file exists, if it does then the natural size is 2048 bytes.
        MOV     r0, r1
        MOV     r1, #0
        BL      Dir
        PullAllFromFrame
        MOV     r2, #2048
        CLRV
        MOV     pc, r14


;**********************************************************************************************


        LTORG

        END

