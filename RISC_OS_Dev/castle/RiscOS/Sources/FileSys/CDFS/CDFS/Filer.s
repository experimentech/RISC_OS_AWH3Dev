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
; >Filer

;**************************************************************************
;**************************************************************************
;     This contains the routines called by 'FileMan'
;**************************************************************************
;**************************************************************************

; routines in here:

;                   SetDir                   ; RISC OS 2 only
;                   SetLib                   ; RISC OS 2 only
;                   Nothing
;                   Catalogue                ; RISC OS 2 only
;                   EX                       ; RISC OS 2 only
;                   LCAT                     ; RISC OS 2 only
;                   LEX                      ; RISC OS 2 only
;                   Info                     ; RISC OS 2 only
;                   Boot
;                   ReadBoot
;                   CurrentDirectory
;                   ReadLIBName
;                   CurrentDirObjects
;                   ObjectInfo
;                   ReadEntriesAndLength
;                   CanoncaliseName          ; RISC OS 3 only
;                   ResolveWildcard          ; RISC OS 3 only
;                   SearchRoutine ( see ReadEntriesAndLength etc; )


;**************************************************************************
SetDIR ROUT                 ; 0    *DIR ( pathname$ )
;**************************************************************************

; entry:
;       R0 = 0
;       R1 -> pointer to wildcarded directory name
;       R6 -> special field ( if present )

; exit:
;       ------- nothing

; R6 != 0 to call 'OS_FSControl 0' to set current directory, else == 0 to not set it

; First move to the correct directory, also expand name to whole path
; eg '%.fred' = '$.image03.fred'

; Then save this whole path as the current directory name IF VALID

;--- If '*dir' then *dir &

        log_on
        
        LDRB    R14, [ R1 ]
        TEQ     R14, #0
        ADREQ   R0, BlankUrd
                
        MOVNE   R0, R1
        
        MOV     r6, #1

;-------------------------------
; Set the current directory.
; This has to ---- around with the stack 'cause of the way that it is abused.
;-------------------------------
SetDir_fixed_for_mount
SetDir_fixed_for_drive

        log_on

        TEQ     r6, #1
        BEQ     %FT10

        Push    "r0-r1"
        MOV     r1, r0
             
        LDR     r8, stackreturn
        SUB     r8, r8, #4*20
        STR     r8, stackreturn
             
        MOV     r0, #FSControl_Dir
        SWI     XOS_FSControl
             
        ADD     r8, r8, #4*20
        STR     r8, stackreturn
        
        Pull    "r0-r1"
10

;************************
; Dir: ( pathname$, RETURN pointer to block of object info, 0 if not found,
;                   RETURN R2 = 1 if a file, 2 if a directory )
;                   RETURN R3 -> start of disc buffer
;                   RETURN R4 = drive number
        MOV     R1, #1                  ; Looking for a directory
        BL      Dir                     
;************************

        TEQ     R2, #object_directory   ; If it is a file, or not found then error
        MOVNE   r0, #ERROR_NOTFOUND
        BNE     ErrorExit


        LDRB    R14, CurrentDriveNumber ; Preserve drive number for *DIR \�
                
        STRB    R14, olddrivenumber     ; used by *DIR \�
                
        STRB    R4, CurrentDriveNumber  ; change to that drive
                
        Push    "R0"

        MOV     R0, R4
        BL      PreGetUniqueNumber      ; R0 = drive number, RETURNS R1 = number
        
        ;--- Update the list of discs mounted

        ADRL    R14, discsMounted
        STR     R1, [ R14, R0, LSL #2 ]

        ; keep the full pathname, eg :FreddyDisc.$.pathname

        ADR     r1, TempArea

        MOV     R0, R4                  ; Keep the name of the CSD disc
        MOV     R2, R3                  
        BL      GetDiscName             ; R0 = drive, R1 -> place to put name, R2 -> buffer
        MOV     R0, R1                  ;
        BL      CutSpace                ;
        
        Push    "R0"                    ; R0 = drive number
        MOV     R0, R4                  ; R1 -> disc name
        BL      AddDiscNameInList       ;
        Pull    "R0"                    ;
        
        Pull    "R0"

        CLRV
        PullAllFromFrameAndExit

BlankUrd
        DCB     "&", 0
        ALIGN

;**************************************************************************
Nothing ROUT
;**************************************************************************

        log_on

        PullAllFromFrameAndExit

;-----------------------------------------------------------------------------------------------
ReadBoot_OS3 ROUT                ; 11
;
; on entry:
;          R0 = 11
;          R2 = memory address to put data at   ( how big ??? )
;          R6 = 0 ( cannot specify a context )
; on exit:
;          --------
; Layout of memory:
;                  < length of name byte >< disc name >< boot option byte >
;
; This is the RISC OS 3 version of ReadBoot
;  BJGA 2002: NB since we set bit 23 of the filing system information word,
;             this is never called by modern FileSwitch!
;
;-----------------------------------------------------------------------------------------------

        MOV     r5, r2


        LDRB    r0, CurrentDriveNumber
        BL      TestKnowDisc
        ADD     r1, r1, #DiscBuff_DiscName

;------------------------------------
; Copy the name into a RISC OS buffer
;------------------------------------

        MOV     r2, #0

01
        LDRB    r0, [ r1 ], #1
        STRB    r0, [ r5 ], #1
        ADD     r2, r2, #1
        CMP     r0, #32
        BGT     %BT01

;------------------------------------
; Store the boot option
;------------------------------------
      [ BootFromCD
        MOV     lr, #2
        STRB    lr, [ r5 ]
      |
        STRB    r6, [ r5 ]
      ]

;------------------------------------
; Store the length byte
;------------------------------------
        STRB      r2, [ r5, -r2 ]

        PullAllFromFrameAndExit         ; V is clear


;**************************************************************************
CurrentDirObjects ROUT       ; 14   ( OS_GBPB 8 )
;**************************************************************************

; This is the same as 15, but only returns the names in the directory

; This is used to make a list of the contents of a directory

;entry:
;      R0 = 14
;      R1 -> pointer to directory name
;      R2 = memory address to put data
;      R3 = number of object names to read
;      R4 = offset of first item to read in directory
;      R5 = buffer length
;      R6 = pointer to special field if present ( network ? )

;exit:

;     R3 = number of records read
;     R4 = offset of next item to read in directory ( -1 if end )

        log_on
        
        MOV     R11, #0
        B       SearchRoutine           ; R0 -> routine




;**************************************************************************
ObjectInfo ROUT             ; 15 ( OS_GBPB 10 )
;**************************************************************************

; This is used to make a list of the contents of a directory

; All the way through, the latest entry is updated into loadaddress,

; execaddress, LBA ( used for copying ), temp4

;entry:
;      R0 = 15
;      R1 -> pointer to directory name
;      R2 = memory address to put data
;      R3 = number of object names to read
;      R4 = offset of first item to read in directory
;      R5 = buffer length
;      R6 = pointer to special field if present ( network ? )

;exit:

;     R3 = number of records read
;     R4 = offset of next item to read in directory ( -1 if end )

        log_on
        
        ADR     R11, ObjectInfo15

;**************************************************************************
SearchRoutine ROUT        ; R11 -> routine to call when needed OR 0
;**************************************************************************

; expects the following to be true:
; frame pushed with PushAllWithReturnFrame

;          R1 -> pointer to path
;          R2 = address of Archy buffer
;          R3 = number of objects to read
;          R4 = offset to read from
;          R5 = buffer length
;          R6 = pointer to special field


; during this procedure:

; R1 = number of objects left to read / or offset so far
; R2 -> current place where data is put in their buffer
; R3 = number of objects to read
; R4 = offset reached
; R5 -> end of buffer
; R6 -> start of entry in my buffer
; R8 = count
; ----R9 = !!!!!! number of object names matching wildcarded name
; ----R10 -> filename
; R11 -> routine to call

; The routine to call can use the following regs safely:
; R0, R7

; Return from your routine with MOV PC, R14

; Bit dodgy 'cause it uses a variable set by the 'Dir' procedure

        MOV     R7, R2
        ADD     R5, R5, R2           ; R5 -> end of Archies buffer
        SUB     R5, R5, #4
                
        MOV     R0, R1

;****************
; Find file name from pathname
;****************

; Dir: ( pathname$, RETURN pointer to block of object info, 0 if not found,
;                   RETURN R2 = 1 if a file, 2 if a directory )
;                   RETURN R3 -> start of disc buffer
;                   RETURN R4 = drive number
        Push    "R1 - R4"
        
        MOV     R1, #1                  ; Must find a directory
        
        BL      Dir
        
        TEQ     R2, #object_directory   ; If it is a file, or not found then error
        MOVNE   r0, #ERROR_NOTFOUND
        BNE     ErrorExit
        
        MOV     R6, R1                  ; R6 CORRECT HERE
        
        STRB    R4, tempdrivenumber
        
        LDR     R1, tempBlock
        STR     R1, lastblocknumber
                
        LDR     R1, discnumberofdirinbuffer
        STR     R1, lastdiscnumber

I_ll_be_back

        Pull    "R1 - R4"

        MOV     R8, #0
        MOV     R2, R7
        ADD     R3, R3, R4

02                                      ; Move to correct start pos.
        LDR     R0, [ R6, #0 ]          ; Empty directory ?
        TEQ     R0, #0                  ;
        BLEQ    %FT08                   ; [ yes ]

        ; --- Reached starting offset ? ---

        CMP     R8, R4
                
        BGE     %FT04
                
        ADD     R8, R8, #1

;*****************
; Move to next object in buffer
;*****************

        ADD     R6, R6, #OBJECTNAMEOFFSET + 1

03

        LDRB    R0, [ R6 ], #1
        TEQ     R0, #0
        LDRNEB  R0, [ R6 ], #1
        TEQNE   R0, #0
        BNE     %BT03

        ALIGNREG R6
        B       %BT02

04

06
        LDR     R0, [ R6, #0 ]
        TEQ     R0, #0
        BLEQ    %FT08

;********************
; Invoke specialised routine ( only if routine specified )
;********************
                
        TEQ     R11, #0
        MOVNE   R14, PC
        MOVNE   PC, R11

;******************** Returns to this point (!)

        ADD     R6, R6, #OBJECTNAMEOFFSET

05
        LDRB    R0, [ R6 ], #1
        STRB    R0, [ R2 ], #1
        
        CMP     R2, R5                  ; Run out of buffer space ?
        BGT     %FT07                   ; [ yes ]
        
        TEQ     R0, #0
        BNE     %BT05
        
        TEQ     R11, #0                 ; Only GBPB 9 & 10 need to be aligned
        TSTNE   R2, #3                  ;
        ADDNE   R2, R2, #4              ;
        BICNE   R2, R2, #3              ;
        
        ALIGNREG R6
        
        ADD     R8, R8, #1
        
        CMP     R8, R3
        
        BLT     %BT06


;************
; Done all that was asked for, or filled buffer
;************
07

        STR     R8, verytemporary
        
        PullAllFromFrame
        LDR     R0, verytemporary       ; R3=number of entries read ( matching wildname )
                                        ; R4 = next offset
        SUB     R3, R0, R4
        SUBS    R4, R0, #0              ; clears V
        
        MOV     PC, R14

;************
; Reached end of directory, but not end of buffer
; I NOW HAVE TO CHECK TO SEE IF ANY MORE DIRECTORY SPACE

; R14 is return address if needed

;************

08

        LDR     R0, tempBlockSize
                
        CMP     R0, #myblocksize
        MOVLT   R0, #myblocksize
                
        LDR     R10, tempLength
        SUBS    R10, R10, R0

end_of_search
        STRLE   R8, verytemporary
        PullAllFromFrame LE                      
        LDRLE   R3, verytemporary       ; [ yes ]
        SUBLE   R3, R3, R4
        MOVLE   R4, #-1                 ; ( That was the last entry )
        MOVLE   PC, R14                 ; (V almost certainly clear) GETS HERE, BUT AFTER ?
        
        STR     R10, tempLength
        
        LDR     R6, tempBlock
        ADD     R6, R6, #MAX_BLOCKS_BUFFERED
        STR     R6, tempBlock
                
        MOV     R6, #2

        ; Get next directory r2 r3 r4 r5 r6 r7 r8 ON ENTRY r6=2 or 0
09

        ; --- Keep up to date with object number found

        Push    "R1-R5,R7,R14"

        LDR     R2, tempBlock
                
        LDR     R0, discnumberofdirinbuffer
       
        ; r0=disc number, R2 = block, returns r1->buffer, CC if found
       
        BL      FindDiscInBufferList    ; Found details ?


        MOVCC   R6, R1                  ; [ yes ]
        Pull    "R1-R5,R7,PC", CC       ;

        ; Need to load this by hand
        ; r0 =start LBA, r1->put here, r3=disc type, r4=blocksize, r5=drive number
        ; r6=0 then skip 2 entries, else don't RETURNS r6=size used
        LDR     R0, tempBlock
        ADRL    R1, sparedirectorybuffer + DiscBuff_MainDirBuffer
        LDRB    R3, tempDisctype
        LDR     R4, tempBlockSize
        LDRB    R5, tempdrivenumber
        BL      StoreDirectory


        ;--------------------------------------------------------------
        ; Was block empty ? Just in case of funny discs, ie/ Revelation
        ;--------------------------------------------------------------
        
        TEQ     R6, #4
        BEQ     end_of_search           ; [ yes - so exit ]

        ;--------------------------------------------------------------

        MOV     R2, R0
        MOV     R3, R1
                
        MOV     R1, R6
        MOV     R6, R3
                
        LDR     R0, discnumberofdirinbuffer

        ; R0 = disc, R1 = size, R2 = block, R3->dire

        BL      AddDirectoryToBuffer

        Pull    "R1-R5, R7,PC"

WildSentence
        DCB     "*", 0
        ALIGN

;**************************************************************************
ReadEntriesAndLength ROUT  ; 19 ( OS_GBPB 11 )
;**************************************************************************

; on entry:
;          R0 = 19
;          R1 -> pointer to path
;          R2 = address of Archy buffer
;          R3 = number of objects to read
;          R4 = offset to read from
;          R5 = buffer length
;          R6 = pointer to special field


; on exit:
;         R3 = number of records read
;         R4 = offset of next item to read ( -1 if end )

        log_on
        
        ADR     R11, ObjectInfo19
        B       SearchRoutine           ; R0 -> routine


;**************************************************************************
ObjectInfo15 ROUT
;**************************************************************************
; Corruptable regs: R0, R7, R9, R10
; This corrupts R0 and R7 and R10

        LDR     R0, [ R6, #LOADADDRESSOFFSET ]
        LDR     R7, [ R6, #EXECUTIONADDRESSOFFSET ]
        
        STMIA   R2!, { R0, R7 }
        
        LDR     R0, [ R6, #LENGTHOFFSET ]
        LDRB    R7, [ R6, #FILEATTRIBUTESOFFSET ]
                
        LDRB    R10, [ R6, #OBJECTTYPEOFFSET ]
        STMIA   R2!, { R0, R7, R10 }
        
        MOV     PC, R14

;**************************************************************************
ObjectInfo19
;**************************************************************************
; Corruptable regs: R0, R7, R9, R10
; This corrupts R0, R7 and R9

        LDR     R0, [ R6, #LOADADDRESSOFFSET ]
        LDR     R7, [ R6, #EXECUTIONADDRESSOFFSET ]
        
        LDR     R9, [ R6, #LENGTHOFFSET ]
        LDRB    R10, [ R6, #FILEATTRIBUTESOFFSET ]
        STMIA   R2!, { R0, R7, R9, R10 }
        
        LDRB    R0, [ R6, #OBJECTTYPEOFFSET ]
        MOV     R7, #0                  ; System internal name
        
        LDR     R10, [ R6, #TIMEDATEOFFSET ]
        STMIA   R2!, { R0, R7, R10 }
                
        LDRB    R0, [ R6, #TIMEDATEHIBYTEOFFSET ] ; Date stamp
        STRB    R0, [ R2 ], #1                    
        
        MOV     PC, R14

;-----------------------------------------------------------------------------------------------

      [ BootFromCD
BootFromCDFS ROUT
; on entry:
;          r0  = 10
        LDR     r1, stackreturn
        ADR     r0, BootCommand
        SWI     XOS_CLI
        STR     r1, stackreturn
        B       common_end

BootCommand
        DCB     "Run $.!BOOT", 0
        ALIGN
      ]


CanonicaliseName ROUT
; on entry:
;          r0  = 23
;          r1 -> special field or 0
;          r2 -> disc name or 0
;          r3 -> buffer to hold canonical special field or 0 to return required length
;          r4 -> buffer to hold canonical disc name, or 0 to return required length
;          r5  = length of buffer to hold canonical special field
;          r6  = length of buffer to hold canonical disc name
; on exit:
;          r1 -> canonical special field or 0
;          r2 -> canonical disc name or 0
;          r3 = bytes overflow from special field buffer
;          r4 = bytes overflow from canonical disc name

; See page 4-47 of RISC OS 3 PRMs
;-----------------------------------------------------------------------------------------------

        ;----------------------------
        ; Is the disc name required ?
        ;----------------------------
        TEQ     r2, #0
        BEQ     disc_name_done
        
        TEQ     r4, #0
        MOVEQ   r6, #0
        
        
        ;--------------------------
        ; Get the drive number/name
        ;--------------------------
        MOV     r9, r2
        
        
        MOV     r0, #10
        MOV     r1, r2
        SWI     XOS_ReadUnsigned        ; r2 = value
        MOVVC   r0, r2
        BVC     %FT00
        MOV     r0, r9
        BL      FindDiscNameInList
        MOV     r0, r1
00

        ;---------------------------------------
        ; Disc name not found so ask User for it
        ;---------------------------------------
        CMP     r0, #-1
        BNE     %FT19
        LDRB    r1, CurrentDriveNumber
        MOV     r0, r9
        BL      PromptForDisc
        MOV     r0, r1

19
        BL      TestKnowDisc            ; r0 = drive, RETURNS r1 -> buffer
        ADD     r1, r1, #DiscBuff_DiscName



        ;--- Update the list of discs mounted
        Push    "r1"
        BL      AddDiscNameInList
        
        BL      PreGetUniqueNumber      ; R0 = drive number, RETURNS R1 = number
        
        ADRL    r14, discsMounted
        STR     r1, [ r14, r0, LSL #2 ]
        Pull    "r1"

        ;---------------------------------
        ; Find the length of the disc name, and copy to the caller
        ;---------------------------------

02

        MOV     r8, #0
01
        LDRB    r14, [ r1 ], #1
        
        SUBS    r6, r6, #1
        CMPHI   r4, #0                  ; pointers can be negative!
        STRHIB  r14, [ r4 ], #1
        
        CMP     r14, #32
        ADDGT   r8, r8, #1
        BGT     %BT01
        
        RSBS    r6, r6, #0
        MOVMI   r6, #0
        STR     r6, verytemporary
        PullAllFromFrame
        ADDS    r2, r4, #0              ; clears V
        LDR     r4, verytemporary
        MOV     pc, r14

disc_name_done

        CLRV
        PullAllFromFrameAndExit


;-----------------------------------------------------------------------------------------------

ResolveWildcard ROUT
; on entry:
;          r1 -> directory path
;          r2 -> buffer to hold resolved name, or 0
;          r3 -> wildcarded object name
;          r4 ???
;          r5 =  length of buffer
;          r6 -> special field or 0
; on exit:
;          r1   preserved
;          r2 = -1 if not found, else preserved
;          r3   preserved
;          r4 = -1 if fileswitch should work it out itself, else bytes overflow from buffer
;          r5   preserved
;
; see page 4-48 RISC OS 3 PRMs
;
;-----------------------------------------------------------------------------------------------

        PullAllFromFrame
        MOV     r4, #-1
        CLRV
        MOV     pc, r14



      [ BootFromCD
;-----------------------------------------------------------------------------------------------
ReadBoot2 ROUT
; on entry:
;          r1 -> pathname of any object on image
;          r6 -> special field or 0
; on exit:
;          r2 = boot option
;-----------------------------------------------------------------------------------------------
        PullAllFromFrame                         
        MOV     r2, #2                  ; Run
        MOV     pc, r14                 
      ]



;-----------------------------------------------------------------------------------------------
ReadFreeSpace ROUT
; on entry:
;          r1 -> pathname of any object on image
;          r6 -> special field or 0
; on exit:
;          r0 = free space (0)
;          r1 = biggest creatable object (0)
;          r2 = disc size
;-----------------------------------------------------------------------------------------------
        BL      ReadFreeSpaceCommon
        TEQ     r4, #0
        MOVNE   r2, #-1
        MOVEQ   r2, r3
        PullAllFromFrameAndExit AL, 3


;-----------------------------------------------------------------------------------------------
ReadFreeSpace64 ROUT
; on entry:
;          r1 -> pathname of any object on image
;          r6 -> special field or 0
; on exit:
;          r0 = lsw of free space (0)
;          r1 = msw of free space (0)
;          r2 = biggest creatable object (0)
;          r3 = lsw of disc size
;          r4 = msw of disc size
;-----------------------------------------------------------------------------------------------
        BL      ReadFreeSpaceCommon
        PullAllFromFrameAndExit AL, 5


ReadFreeSpaceCommon
        Push    "r14"
        MOV     r0, r1
        BL      FindDriveNumber
        MOVVC   r0, r1
        BLVC    PreConvertDriveNumberToDeviceID
        
        SUB     sp, sp, #8
        MOVVC   r0, #LBAFormat
        MOVVC   r1, sp
        SWIVC   XCD_DiscUsed
        Pull    "r1,r2"
        Pull    "pc", VS
        
        MOV     r14, r1, LSL #16
        MOV     r1, r1, LSR #16         ; r1 = mshw of block count
        MOV     r0, r14, LSR #16        ; r0 = lshw of block count
        
        MUL     r14, r1, r2
        MUL     r3, r0, r2
        MOV     r4, r14, LSR #16
        ADDS    r3, r3, r14, LSL #16
        ADC     r4, r4, #0
        
        MOV     r0, #0
        MOV     r1, #0
        MOV     r2, #0
        Pull    "pc"

;-----------------------------------------------------------------------------------------------

        LTORG
        
        END
