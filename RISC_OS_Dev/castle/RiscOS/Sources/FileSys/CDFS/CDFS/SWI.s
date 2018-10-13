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

; CDFS SWI commands in here are:

; CDFS_ConvertDriveToDevice_Code 0
; CDFS_SetBufferSize_Code        1
; CDFS_GetBufferSize_Code        2
; CDFS_SetNumberOfDrives_Code    3
; CDFS_GetNumberOfDrives_Code    4
; CDFS_GiveFileType_Code         5
; CDFS_DescribeDisc_Code         6
; CDFS_WhereIsFile_Code          7
; CDFS_Truncation_Code           8

; Tables in here:
; IBMExtensions
; ArchyFileTypes


; SWI process -

; 1. Load R12 with w/s pointer

; 2. Save all registers at start of stack

; 3. Check that SWI is a valid number ( in the range 0 to x ( < 64 ) )

; 4. Branch to proc to control that part

; 5. Terminate the proc with BICS PC, R14, #Overflow_Flag or ORRVSS PC, R14,

; IF ERROR &1E6 ( SWI ... NOT KNOWN ) THEN SUICIDE ?
; ON SWI ENTRY :
;               R11 = SWI number % 64
;               R12 = private word pointer  - USE Pull & Push 
;               R13 = supervisor stack
;               R14 = return register


;*********************************************************************
CDFSSWIentry
;*********************************************************************

        LDR     R12, [ R12 ]

        ; TURN IRQS ON
      [ No26bitCode
        CLRPSR  I_bit, R10
      |
        TEQ     PC, PC
        MVNNE   R10, #I_bit    ; R10 can safely be corrupted
        TSTNEP  R10, PC
        MRSEQ   R10, CPSR
        BICEQ   R10, R10, #I32_bit
        MSREQ   CPSR_c, R10
      ]

;**************************************************************************
;                          Check SWI Number
;**************************************************************************


        CMP     R11, #( EndSWIJumpTable - StartSWIJumpTable ) / 4
        BCS     SWITooBig

;***************************************************************************
;                    Jump table for each SWI ( very fast ) !!
;***************************************************************************

        Push    "R0 - R9, R14"

        Debug   sw,"SWI SWI"

        LDR     R14, [ PC, R11, LSL #2 ]    ; R14 corrupted !!!!!!!!!!!
        ADD     PC, PC, R14                 ;


StartSWIJumpTable

        DCD     CDFS_ConvertDriveToDevice_Code - StartSWIJumpTable - 4
        DCD     CDFS_SetBufferSize_Code - StartSWIJumpTable - 4
        DCD     CDFS_GetBufferSize_Code - StartSWIJumpTable - 4
        DCD     CDFS_SetNumberOfDrives_Code - StartSWIJumpTable - 4
        DCD     CDFS_GetNumberOfDrives_Code - StartSWIJumpTable - 4
        DCD     CDFS_GiveFileType_Code - StartSWIJumpTable - 4
        DCD     CDFS_DescribeDisc_Code - StartSWIJumpTable - 4
        DCD     CDFS_WhereIsFile_Code - StartSWIJumpTable - 4
        DCD     CDFS_Truncation_Code - StartSWIJumpTable - 4

EndSWIJumpTable

SWITooBig
        Push    "r1-r3, r14"
        addr    r0, switoobig_tag
        ADR     r1, message_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "r1-r3, r14"
        TEQ     pc, pc
        MOVEQ   pc, r14
        ORRS    pc, r14, #V_bit

;***************************************************************************
;***************************************************************************
;***************************************************************************
;***************************************************************************

;**************************************************************************
;                          Do CDFS_ConvertDriveToDevice
;**************************************************************************

CDFS_ConvertDriveToDevice_Code


; on entry:
;          R0 = drive number

; on exit:
;         R0, R2 - R10 preserved
;         R1 = composite device id ( b0..b2 = device,b3..b4=card,b5..b7=LUN)
;            + drivetype ( b8 .. b15 )
;            ( b16 .. b30 RESERVED )
;         If error, for some reason, then R1 = &ffffffff ( -1 )


;****************
; First check to see if R0 >= number of drives in my list
;****************

        Debug   sw,"Convert drive"

        LDRB    R1, numberofdrives
                
        CMP     R0, R1
                
        BLHS    AnotherDriveHasBeenAdded ; RETURNS V set if error
        BVS     %FT91 ; temp hack
                
        LDRB    R1, numberofdrives
                
        CMP     R0, #0                  ; R0 > 0 and < numberofdrives ?
        RSBHSS  R14, R0, R1             ;
        BLO     %FT90

;****************
; Give the composite device id to Leonardo
;****************

        ADRL    R14, ListOfDrivesAttached
        LDRB    R1, [ R0, R14 ]
                
        ADRL    R14, DriveTypes
        LDRB    R2, [ R0, R14 ]
        ORR     R1, R1, R2, ASL #8
                
        MOV     R10, R1

        Debug   sw,"End convert"

        Pull    "R0 - R9, R14"

        MOV     R1, R10

        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

90              
        Pull    "R0-R9, R14"
        MOV     R1, #-1
        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

91
        ADD     sp,sp,#4
        Pull    "r1-r9,pc"

;**************************************************************************
CDFS_SetBufferSize_Code   ROUT ; R0 = bit number
;**************************************************************************

        MOV     R4, R0

;**************
; Get byte currently in CMOS RAM
;**************

        MOV     R0, #OsByte_ReadCMOS
                
        MOV     R1, #CDROMFSCMOS        ; Cmos RAM location
                
        SWI     XOS_Byte                ; R2 = contents of location


;************
; Mix byte in CMOS with number
;************

        BIC     R2, R2, #BITSUSEDBYBUFFER
                
        ORR     R2, R2, R4, ASL #BUFFERSHIFT


;************
; Store mixed byte back into CMOS
;************

        MOV     R0, #OsByte_WriteCMOS
                
        MOV     R1, #CDROMFSCMOS    
                
                                        ; R2 = number
        SWI     XOS_Byte

        Pull    "R0 - R9, R14"

        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

;**************************************************************************
CDFS_GetBufferSize_Code   ROUT ; RETURNS R0 = bit number
;**************************************************************************

;**************
; Get byte currently in CMOS RAM
;**************

        MOV     R0, #OsByte_ReadCMOS
                
        MOV     R1, #CDROMFSCMOS        ; Cmos RAM location
                
        SWI     XOS_Byte                ; R2 = contents of location


;**************
; Extract the buffer value from the CMOS byte
;**************

        AND     R2, R2, #BITSUSEDBYBUFFER
                
        MOV     R2, R2, ASR #BUFFERSHIFT


        MOV     R10, R2

        Pull    "R0 - R9, R14"

        MOV     R0, R10

        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

;**************************************************************************
CDFS_SetNumberOfDrives_Code  ROUT  ; R0 = number of drives
;**************************************************************************

        MOV     R4, R0

;**************
; Get byte currently in CMOS RAM
;**************

        MOV     R0, #OsByte_ReadCMOS
                
        MOV     R1, #CDROMFSCMOS        ; Cmos RAM location
                
        SWI     XOS_Byte                ; R2 = contents of location


;************
; Mix byte in CMOS with number
;************

        BIC     R2, R2, #BITSUSEDBYDRIVENUMBER
        ORR     R2, R2, R4

;************
; Store mixed byte back into CMOS
;************

        MOV     R0, #OsByte_WriteCMOS
                
        MOV     R1, #CDROMFSCMOS    
                
                                        ; R2 = number
        SWI     XOS_Byte

        Pull    "R0 - R9, R14"

        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14                 
        MOVS    PC, R14                 

;**************************************************************************
CDFS_GetNumberOfDrives_Code  ROUT ; RETURNS R0 = number of drives
;**************************************************************************

;**************
; Get byte currently in CMOS RAM
;**************

        MOV     R0, #OsByte_ReadCMOS
                
        MOV     R1, #CDROMFSCMOS        ; Cmos RAM location
                
        SWI     XOS_Byte                ; RETURNS R2 = contents of location


;************
; Mix byte in CMOS with number
;************

        AND     R10, R2, #BITSUSEDBYDRIVENUMBER

        Pull    "R0 - R9, R14"

        MOV     R0, R10
                                        
        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14                 
        MOVS    PC, R14                 


;**************************************************************************
CDFS_GiveFileType_Code ROUT   ; R0 -> filename, RETURNS R1 = file type or 0
;**************************************************************************

; on entry:
;          R0 -> filename ( not necc. word aligned )
; on exit:
;          R1 = file type for name ( 0 if none found ) ( 0 TO &FFF )

        MOV     R8, R0                  ; Find extension ( after dot )
        MOV     R14, #0                 ; Last dot seen ( deals with 'filename.tar.gz' )
        MOV     R10, #0                 ; Get ready to fail

find_that_dot

        LDRB    R2, [ R8 ], #1
        TEQ     R2, #"."
        MOVEQ   R14, R8
        CMP     R2, #32                 ; Allow control terminated
        BHS     find_that_dot
        
        MOVS    R8, R14                 ; No dot
        BEQ     %FT20
        
        LDRB    R1, [ R8 ]              ; A dot but nothing follows it
        CMP     R1, #32
        BLT     %FT20

        ; R8 -> extension name, ie TXT

      [ UseMimeMapTranslations
        MOV     r0,#MMM_TYPE_DOT_EXTN
        MOV     r1,r8 ; -> extension
        MOV     r2,#MMM_TYPE_RISCOS
        SWI     XMimeMap_Translate
        BVS     %FT30
        MOV     r10,r3
      |
        B       %FT30
      ]
20
        ; R10 = result
        Pull    "R0 - R9, R14"
        MOV     R1, R10
        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14
30
        ; Try our lookup table
        ADR     R4, IBMExtensions
        MOV     R6, #0                  ; List index

repeat_search_for_extension

        LDRB    R1, [ R4 ]
        TEQ     R1, #0
        BEQ     %BT20                   ; Reached end of list, give up
        
        MOV     R5, R8                  ; -> extension

compare_extension_with_name             ; Compare the names with the one passed
                                        ; in
        LDRB    R2, [ R5 ], #1          ; part from name passed in
        CMP     r2,#32                  
        MOVLT   r2,#0                   


        LDRB    R1, [ R4 ], #1          ; part from list of names
        TEQ     R1, #0                  ; end of table entry?
        TEQEQ   R2, #0                  ; end user string?
        
        ADREQ   R0, ArchyFileTypes      ; Reached the end of both
        LDREQ   R10, [ R0, R6, ASL #2 ] ; Load corresponding Archy file type
        BEQ     %BT20

        ASCII_UpperCase r2, r14
        TEQ     R2, R1                  ; same
        BEQ     compare_extension_with_name

different

        TEQ     R1, #0                  ; Move to next entry in list
        LDRNEB  R1, [ R4 ], #1          ;
        BNE     different               ;
        ADD     R6, R6, #1              ; Not found
                                        ;
        B       repeat_search_for_extension

;**************************************************************************
IBMExtensions
;**************************************************************************


        ; Must be of length 4 chars ( fill with zeroes if nec. )

        DCB     "DOC", 0    ; 0
        DCB     "TXT", 0    ; 1
        DCB     "BAT", 0    ; 2
        DCB     "EXE", 0    ; 3
        DCB     "BIN", 0    ; 4
        DCB     "TIF", 0    ; 5
        DCB     "COM", 0    ; 6
        DCB     "PCD", 0    ; 7
        DCB     "MPG", 0    ; 8

        ; Insert more extensions here ( don't forget to add matching
        ;                              Archy file type below )
        ASSERT  ((. - IBMExtensions) :AND:3) = 0
        DCB     0
        ALIGN

;**************************************************************************
ArchyFileTypes
;**************************************************************************

        DCD     &AE6      ; ms-word    0
        DCD     &FFF      ; text       1
        DCD     &FDA      ; MSDOSbat   2
        DCD     &FD9      ; MSDOSexe   3
        DCD     &FFD      ; Data       4
        DCD     &FF0      ; TIFF       5
        DCD     &FD8      ; MSDOScom   6
        DCD     &be8      ; PhotoCD    7
        DCD     &BF8      ; MPEG       8

        ; Insert more Archy file types here
        ;
        DCD 0


;**************************************************************************
CDFS_DescribeDisc_Code ROUT
;**************************************************************************
; on entry:
;          R0 = drive number
;          R1 -> 64 byte block

; on exit:
;         nowt


; R9 -> 64 byte block


; 0. Is block word aligned ?

        TST     R1, #3
        BNE     swiinvalidparameter

        MOV     R9, R1


        ; Kludge any error to return

        LDR     R14, stackreturn
        Push    "R14"
        ADR     R14, return_here
        PushAllWithReturnFrame


        BL      TestKnowDisc            ; R0 = drive, RETURNS R1->buf, RETURNS R2 =disc

return_here

        STRVS   R0, swi_verytemporary
        STRVC   R1, swi_verytemporary
        PullAllFromFrame 
        LDRVC   R1, swi_verytemporary
        Pull    "R14"
        STR     R14, stackreturn

        Pull    "R0 - R9, R14", VS
        LDRVS   R0, swi_verytemporary
        TEQ     PC, PC
        TEQVC   PC, #0
        MOVEQ   PC, R14                 ; 32-bit error exit
        ORRVSS  PC, R14, #V_bit         ; 26-bit error exit

; 4. Enter details into block

        ;a. Size of disc ( 1 word )
        
        LDR     R14, [ R1, #DiscBuff_SizeOfDisc ]
                
        STR     R14, [ R9, #SIZEOFDISCOFFSETFORDESCRIBE ]

        ;b. Block size ( 1 word )
        
        LDR     R14, [ R1, #DiscBuff_BlockSize ]
                
        STR     R14, [ R9, #BLOCKSIZEOFFSETFORDESCRIBE ]

        ;c. Block number of root directory ( 1 word )
                
        LDR     R14, [ R1, #DiscBuff_LBAOfMainDir ]
                
        STR     R14, [ R9, #STARTLBAOFFSETFORDESCRIBE ]

        ;d. Disc name ( up to 32 bytes )
                
        ADD     R8, R1, #DiscBuff_DiscName
        ADD     R7, R9, #DISCNAMEOFFSETFORDESCRIBE
        ADD     R6, R7, #MAXLENGTHOFDISCNAME
01
        LDRB    R5, [ R8 ], #1
        TEQ     R5, #SPACE
        MOVEQ   R5, #0
        STRB    R5, [ R7 ], #1
                
        CMP     R7, R6
        BLE     %BT01

        ;e. Boot option ( 1 byte )
        
        MOV     R5, #0
        STRB    R5, [ R9, #BOOTOPTIONOFFSETFORDESCRIBE ]

        Pull    "R0 - R9, R14"

        ; Not grabbing the correct return registers first time around

        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

;**************************************************************************
CDFS_WhereIsFile_Code  ; R0 -> pathname RETURNS R1 = block number or -1
                       ; RETURNS R2 = length in bytes of file
;**************************************************************************
;*********************
; Dir: ( pathname$, RETURN pointer to block of object info, 0 if not found,
;                   RETURN R2 = 1 if a file, 2 if a directory )
;                   RETURN R3 -> start of disc buffer
;                   RETURN R4 = drive number

        ; Kludge any error to return

        ADR     R14, here
        PushAllWithReturnFrame
        
        CLRV
        
        MOV     R1, #2 ; Don't care what I find
        BL      Dir

here
        BVS     error_here

        TEQ     R2, #object_file        ; A file ?

        STREQ   R1, swi_verytemporary

        PullAllFromFrame

        Pull    "R0 - R9, R14"
        LDREQ   R10, swi_verytemporary
        LDREQ   R2, [ R10, #LENGTHOFFSET ]
        LDREQ   R1, [ R10, #LBASTARTOFFSET ]
        MOVEQ   R1, R1, LSR #8
        MOVNE   R1, #-1
        CMP     PC, PC                  ; clears V in 32-bit mode
        MOVEQ   PC, R14
        MOVS    PC, R14

error_here ; V is already set

        STR     R0, swi_verytemporary
        PullAllFromFrame
        Pull    "R0-R9,R14"
        LDR     R0, swi_verytemporary
        TEQ     PC, PC
        MOVEQ   PC, R14
        ORRS    PC, R14, #V_bit

;**************************************************************************
CDFS_Truncation_Code
;**************************************************************************

; on entry:
;          r0=0 THEN read current truncation type
;                    on exit:
;                            r1=current value
;               ELSE
;          r0=1
;               set truncation type
;               r1=0 then truncate from right  (default for risc os 2.00)
;               r1=1 then truncate from left
;               r1=2 then no truncation        (default for risc os 3.00 > )
;               r1=-1 then use default for os version

        TEQ     R0, #0
        Pull    "R0-R9,R14",EQ
        LDREQB  R1, truncation
        BEQ     %FT80
        
        TEQ     R0, #1
        BNE     swiinvalidparameter

        LDRB    R14, max_truncation
        CMP     R1, #-1                 ; Convert max truncation to default truncation for RISC OS version
        ANDEQ   R1, R14, #2_10          ; r14=1 or 2 convert to 0 or 2
        
        CMP     R1, #0
        RSBHSS  R3, R1, R14
        BLO     swiinvalidparameter
        
        STRB    R1, truncation

        Pull    "R0 - R9, R14"
80
        TEQ     PC, PC
        MOVEQ   PC, R14
        MOVS    PC, R14

swiinvalidparameter
        Pull    "R0-R9,R14"

        Push    "r1-r4, r14"
        addr    r0, invalidparameter_tag
        ADR     r1, message_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "r1-r4, r14"
        TEQ     pc, pc
        MOVEQ   pc, r14                 ; V set by MessageTrans
        ORRS    pc, r14, #V_bit

        LTORG

        END
