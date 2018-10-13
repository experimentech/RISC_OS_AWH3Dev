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
; >Directory

;**************************************************************************
;**************************************************************************

;   This will move to the correct LBA, indicated by a pathname, pointed
; at by R0.


; contains:
;               AddDiscNameInList      - puts disc into drive list
;               ConvertDotToUnderLine
;               CutSpace               - removes messy spaces from a string
;               Dir
;               FindDiscNameInList     - Looks through drive mounted list
;               FullPathName
;               LoadBlockFromDrive

;**************************************************************************
Dir
; on entry:
;          R0->pathname
;          R1=0 if looking for a file, 1 if looking for a directory
;             2 if don't care (ie opening a file)

; on exit:
;          R1 -> block of object info, 0 if not found,
;          R2 = 1 if a file, 2 if a directory )
;          R3 -> start of disc buffer
;          R4 = drive number
;          V clear, other flags corrupted
;          all other regs preserved
;**************************************************************************

; object type = FILE / NOTFOUND / DIRECTORY

; R6 = PointerToEntry
; R8 = Drive number (0..7), name is a dir(8), ultimate object(9..10)
;      end of path reached (11) if clear
; R9 = Word
; R10 = PointerToPath
; R11 = PointerToDiscBuffer ( each individual buffer, starts as main one )
; R12 -> workspace
; R13 -> FD stack

; Variables used:
; tempLength                    = length in blocks of directory
; tempBlockSize
; discnumberofdirinbuffer

        Push    "R5 - R11, R14"


;****************
; R10 -> pathname passed in ( changed later )
;****************

        MOV     R8, R1, ASL #9
        MOV     R10, R0

;****************
; This will return the drive number for a given disc ( prompts for disc name
;                                                     etc; )
;****************


        BL      FindDriveNumber         ; R0 -> pathname, RETURNS R1 = drive number

;****************
; R8 = drive number implied ( constant )
;****************

        ORR     R8, R8, R1

;****************
; If drive has not yet been used, then find its device & LUN number
;****************

        AND     R0, R8, #255

;****************
; This also validates the path
;****************

        MOV     R2, R1
        MOV     R0, R10
        AND     R1, R8, #255

        BL      FullPathName            ; RETURNS R0 -> whole name, R1 = drive number
                                        ; R2 = disc number



;****************
; R10 now points at the new pathname ( stripped of leading drive number )
;****************

        MOV     R10, R0

;****************
; This gets a pointer to the disc main directory ( and header info )
;****************

        AND     R0, R8, #255
                
        BL      TestKnowDisc            ; R0 = drive number, RETURNS R1 -> buffer
                                        ; RETURNS R2 = disc number

;****************
; R11 -> start of directory ( past header information in root directory )
;****************

        STR     R2, discnumberofdirinbuffer
                
        ; Make sure that blocky offset starts from zero
                
        MOV     R14, #0
        STR     R14, tempInk


;****************
; Remember where main directory information is
;****************

        STR     R1, maindirpointer
        ADD     R1, R1, #DiscBuff_MainDirBuffer

;****************
; tempbufferpointer -> start of this directory buffer
;****************

        STR     R1, tempbufferpointer
        LDR     R4, [ R1, #DiscBuff_SizeOfMainDir - DiscBuff_MainDirBuffer ]
        STR     R4, tempLength

;****************
; Remember block size
;****************
    
        LDR     R4, [ R1, #DiscBuff_BlockSize - DiscBuff_MainDirBuffer ]
        STR     R4, tempBlockSize

;****************
; Remember disc type
;****************

        LDRB    R3, [ R1, #DiscBuff_DiscType - DiscBuff_MainDirBuffer ]
        STRB    R3, tempDisctype

;****************
; Remember block start
;****************

        LDR     R9, [ R1, #DiscBuff_LBAOfMainDir - DiscBuff_MainDirBuffer ]
        STR     R9, tempBlock

;****************
; Start with branch/leaf 1
;****************

        MOV     R9, #0                  ; Word = 1

;*******************************************
try_again
;*******************************************

        ; R11 -> directory details ( past header info, so have to back track )
        MOV     R11, R1

;****************
; Move to next branch/leaf in path
;****************

        ADD     R9, R9, #1

;****************
; Put next leaf/branch in 'tempbuffer'
;****************

        MOV     R0, R10
        ADR     R1, tempbuffer
       
        ; R0 -> pathname$,R1 -> word$, R9 = word number
        ; R0 & R2 - R5 corrupted
        
        MOV     R5, #0
        MOV     R4, R1

;*****************
; First move to correct '.'
;*****************

01

        LDRB    R3, [ R0 ], #1          
                                        
        TEQ     R3, #0                  ; Reached end of path, but didn't find word ?
        BEQ     directory               
                                        
        TEQ     R3, #ARCHYDIVIDER            
        ADDEQ   R5, R5, #1              ; Increase word count if found '.'
                                        
        CMP     R5, R9                  
                                        
        BLT     %BT01                   

;**************
; Found start position, now copy word to caller
;**************

02

        LDRB    R3, [ R0 ], #1
        STRB    R3, [ R4 ], #1
        TEQ     R3, #ARCHYDIVIDER
        TEQNE   R3, #0
                
        BNE     %BT02

        ; --- End of path ? BUT DID I WANT A DIRECTORY OR A FILE ? ---

        TEQ     R3, #0
        ORRNE   R8, R8, #1:SHL:11
        BICEQ   R8, R8, #1:SHL:11

        TST     R8, #512                
        ORRNE   R8, R8, #256            ; Directory
        BICEQ   R8, R8, #256            ; File

        ; --- If divider following, then must be a directory wanted ---

        TEQ     R3, #ARCHYDIVIDER            
        ORREQ   R8, R8, #256            ; Directory
        BICNE   R8, R8, #256            ; File

        ; --- Get rid of last dot ---

        MOV     R3, #0
        STRB    R3, [ R4, #-1 ]

;****************
; Look through directory for the branch/leaf name [ Vset if not found ]
;****************

        MOV     R0, R11

        ; R0 -> memory, R1 -> name$, RETURN R2 = position  Vset if not found

        MOV     R5, R0
        MOV     R0, R1

01

        ADD     R1, R5, #OBJECTNAMEOFFSET ; R0 -> wildcarded string
                                          ; R1 -> prepared string in buffer

        ; --- Do I care what I'm looking for ? ---

        CLRV

        TST     R8, #1024               
        BNE     %FT11                   ; [ no ]

        ; --- If haven't reached end of path, then must look for a directory ---

        TST     R8, #256                ; If it's a directory that you want
                                        ; but you don't find one, ignore it
        LDRB    R14, [ R5, #OBJECTTYPEOFFSET ]
        TEQNE   R14, #object_directory
        SETV    NE

11

;-------------------------------------------------------------------
; RISC OS 3 finds it's wildcarded filenames differently
;-------------------------------------------------------------------
        Push    "r0-r3"
15
        LDRB    r2, [ r0 ], #1
        LDRB    r3, [ r1 ], #1
        CMP     r3,#'a'
        RSBGES  r14,r3,#'z'
        SUBGE   r3,r3,#&20
        CMP     r2,#'a'
        RSBGES  r14,r2,#'z'
        SUBGE   r2,r2,#&20
        TEQ     r2, r3

        ; not found
        Pull    "r0-r3", NE
        BNE     %FT16

        CMP     r2, #32
        BGE     %BT15

        ; found
        Pull    "r0-r3"
        MOV     r2, r5
        B       %FT02
16

        ADD     R5, R5, #OBJECTNAMEOFFSET + 1

04
        LDRB    R4, [ R5 ], #1
        TEQ     R4, #0
        BNE     %BT04

        ALIGNREG R5

        LDR     R4, [ R5, #LBASTARTOFFSET ]
        MOVS    R4, R4, LSR #8
                
        BNE     %BT01

        ; Move to next block, if there is one

        LDR     R14, tempLength
                
        LDR     R0, tempBlockSize
        SUBS    R14, R14, R0
                
        MOVLE   R1, #0                  ; NOT FOUND
        MOVLE   R2, #object_nothing     ;
        Pull    "R5 - R11, PC", LE      ;
                
        STR     R14, tempLength
                
        LDR     R14, tempInk
        ADD     R14, R14, #MAX_BLOCKS_BUFFERED
        STR     R14, tempInk
        LDR     R0, tempBlock           ; need to keep this as start block
        ADD     R0, R14, R0             ; 'cause use in other procedures (sorry)
                
        SUB     R9, R9, #1              ; 'cause I haven't found anything
                
        B       more_blocky

02      ; Found

;****************
; R6 -> entry details
;****************

        ; blocky offset back to zero

        MOV     R6, #0
        STR     R6, tempInk
                
        MOV     R6, R2

;****************
; Copy entry details into 'TempArea' ( so that 'ReadCatalogue' can use it )
;****************

        MOV     R1, R6                                      ; Copy from
        ADR     R2, TempArea                                ; Copy to
        MOV     R3, #OBJECTNAMEOFFSET + MAXLENGTHOFNAME + 1 ; Copy length
        CD_ByteCopy

;****************
; The object was a file ? [ yes - then end search ]
;****************

        LDRB    R4, [ R6, #OBJECTTYPEOFFSET ]
        TEQ     R4, #object_file        ; If it is A FILE then the end has been reached
        BNE     %FT23

        TST     R8, #1:SHL:11           ; end of path ?
        MOVNE   R1, #0                  ; [ no - so NOT FOUND ]
        MOVNE   R2, #object_nothing     ;
                                        
        MOVEQ   R0, R10                 ; [ yes - so return file details ]
        MOVEQ   R1, R6                  ;
        MOVEQ   R2, #object_file        ;
        LDREQ   R3, maindirpointer      ;
        ANDEQ   R4, R8, #255            ;

        CLRV
        Pull    "R5 - R11, PC"

23

;****************
; Work out real length of dir/file from block size and length
;****************

        LDR     R5, [ R6, #LENGTHOFFSET ]
        STR     R5, tempLength

;*******
; R0 = LBA of start of next dir ( LBA is stored packed )
;*******

        LDR     R0, [ R6, #LBASTARTOFFSET ]
        MOV     R0, R0, LSR #8
        STR     R0, tempBlock

more_blocky


;*************
; This will store a directory in the buffer, if possible ( or not there )
;*************

; R0 = Start LBA
; R1 ~
; R2 ~
; R3 ~
; R4 ~
; R5 ~
; R6 ~

        Push    "R0, R2"
        MOV     R2, R0
        LDR     R0, discnumberofdirinbuffer
        BL      FindDiscInBufferList    ; R0 = disc, RETURNS R1 -> buf, R2 = LBA
                                        ; C set if not found, else C clear

;*************
; Make R1 -> directory if found, else R1 -> place to put dir
;*************

        ADRCSL  R1, sparedirectorybuffer + :INDEX:DiscBuff_MainDirBuffer
        STR     R1, tempbufferpointer
                
        Pull    "R0, R2"
        BCC     try_again

;*************
; This will store a directory in the buffer, if not cached
;*************


        ; R0 = start LBA, R1 -> place to put, R2 UNUSED
        ; R3 = disc type, R4 = blocksize, R5 = drive number, RETURNS R6 = size of mem
        
        Push    "R0 - R5"
        
        ADR     R3, tempBlockSize
        LDMIA   R3, { R4, R6 }
        
        LDRB    R3, tempDisctype
        
        AND     R5, R8, #255
        
        BL      StoreDirectory


;----------------------------------------------------------------------------
; Check for Revelation CD which claims to use 4 blocks but really only uses 2
;----------------------------------------------------------------------------

        ; If there was nothing in that directory block AND expected something then exit
        CMP     r6, # 4
        BNE     D_FullBlock
        
        LDR     r14, tempLength
        LDR     r2, tempBlockSize
        TEQ     r14, r2
        
        Pull    "r0 - r5", NE
        MOVNE   r1, #0                  ; NOT FOUND
        MOVNE   r2, #object_nothing     ;
        Pull    "r5 - r11, pc", NE      ;

D_FullBlock

        MOV     R2, R0
        MOV     R3, R1
        MOV     R1, R6
        LDR     R0, discnumberofdirinbuffer
        BL      AddDirectoryToBuffer    ; R0 = disc, R1 = size, R2 = block, R3->dire

        ; Refresh pointer to the main directory (the buffers may have moved)
        LDR     r0, discnumberofdirinbuffer
        MOV     r2, #PVD
        BL      FindDiscInBufferList
        MOVCS   r0, #ERROR_INTERNALERROR
        BCS     ErrorExit               ; It's gone! That's bad
                
        STR     r1, maindirpointer

        Pull    "R0-R5"

        B       try_again

        ; --- Reached end of path, but didn't find word ? ---

directory


        MOV     R0, R10                 ; R0 -> expanded pathname
        MOV     R1, R11                 ; R1 -> current buffer
        MOV     R2, #object_directory   ; R2 = directory attrib
        LDR     R3, maindirpointer      ; R3 -> main dir header
        AND     R4, R8, #255            ; R4 = drive number
        CLRV
        Pull    "R5 - R11, PC"

;********************************************************************
; Compare 2 strings
;entry:
; R0 -> first string
; R1 -> second string
; R2 = length
; exit:
; Z = 1 if found, else Z = 0
; All other flags preserved

CompareStrings ROUT
;********************************************************************
; If length = 0 THEN must be same !

        TEQ     R2, #0
        MOVEQ   PC, R14

        ; R2 -> end of R1

        Push    "R0 - R4"

        ADD     R2, R2, R1

01
        LDRB    R4, [ R0 ], #1
        LDRB    R3, [ R1 ], #1
        TEQ     R4, R3
                
        Pull    "R0 - R4", NE
        MOVNE   PC, R14

        CMP     R1, R2
        BLT     %BT01

        ; Z is now set
        Pull    "R0 - R4"
        MOV     PC, R14

;********************************************************************
; Strip leading and trailing spaces from a string ( R0 -> string )
CutSpace ROUT
;********************************************************************

        Push    "R0 - R4, R14"

        MOV     R3, R0                  ; Find the length of the string
01
        LDRB    R2, [ R3 ], #1          
        TEQ     R2, #0                  
        BNE     %BT01

        MOV     R1, R3                  ; R3 -> byte *after* null terminator
        SUB     R3, R3, #2              ; R3 -> last char of string

;***************
; First chop the trailing spaces
;***************

02
        LDRB    R4, [ R3 ], #-1
        TEQ     R4, #SPACE
        BNE     %FT05

        CMP     R3, R0                  ; If string is all spaces
        BCS     %BT02
        
        MOV     R4, #0
        STRB    R4, [ R3, #1 ]
        Pull    "R0 - R4, PC"
05
        MOV     R4, #0
        STRB    R4, [ R3, #2 ]!         ; R3 -> terminating null

;***************
; Now chop the leading spaces
;***************

        MOV     R1, R0
10
        LDRB    R4, [ R1 ], #1
        CMP     R1, R3
        Pull    "R0 - R4, PC", CS
                
        TEQ     R4, #SPACE
        BEQ     %BT10

        SUB     R1, R1, #1              ; R1 -> left trimmed start
        CMP     R1, R0
        Pull    "R0 - R4, PC", LS

;**************
; Shuffle string back if needed
;**************

15
        LDRB    R4, [ R1 ], #1
        STRB    R4, [ R0 ], #1
        CMP     R1, R3
        BLS     %BT15                   ; shuffle up to and including terminator
                
        Pull    "R0 - R4, PC"


;------------------------------------------------------------------------------------------
FullPathName ROUT;( RETURNS R0 -> pathname, R1 = drive number, R2 =disc number )

        Push    "r1-r4, r14"
        
        LDRB    r3, [ r0 ]
        TEQ     r3, #":"
        Pull    "r1-r4, pc", NE
        
        ADD     r0, r0, #1
        
02      
        LDRB    r3, [ r0 ], #1
        TEQ     r3, #"."
        BNE     %BT02
        
        Pull    "r1-r4, pc"


;********************************************************************

PreLoadBlockFromDrive ; This sets R1=buffer in preparation

        ADRL    R1, buffer
        ; Fall through

;********************************************************************
LoadBlockFromDrive ROUT ; R0 = block, R1 -> memory, R2 = length ( blocks )
                   ; R3 = drive number
;********************************************************************

        Push    "R0 - R7, R14"

        MOV     R4, R0
        MOV     R5, R1
        
        MOV     R0, R3
        BL      PreConvertDriveNumberToDeviceID   ; R0 = drive number, R7 -> memory

        MOVVC   R0, #LBAFormat
        MOVVC   R1, R4
        MOVVC   R3, R5
        MOVVC   R4, #myblocksize
        SWIVC   XCD_ReadData
        BVS     ErrorExit
                
        Pull    "R0 - R7, PC"

;********************************************************************
FindDriveNumber ROUT ;( R0 -> pathname, RETURNS R1 = drive )
;********************************************************************

        Push    "R0, R2 - R7, R14"

        MOV     R6, R0
01
        LDRB    R2, [ R6 ]
        STRB    R2, [ R6 ], #1
        TEQ     R2, #0
        BNE     %BT01
                
        MOV     R6, R0
                
        LDRB    R1, [ R6 ]
        TEQ     R1, #":"                ; drive specified in pathname
        BEQ     %FT02                   ; either by name, or number ?
                                        ; [ must mean current drive number ]

        TEQ     R1, #"\\"               ; Use the old drive number ! if previous
        LDREQB  R1, olddrivenumber      ; path is required
        LDRNEB  R1, CurrentDriveNumber  ;
        Pull    "R0, R2 - R7, PC"       ;

02
        ADD     R1, R0, #1              ; Copy into a safe area
        
        LDRB    R3, [ R1 ]              ; Nothing specified ? ( no name, no number )
        TEQ     R3, #0                  ;
        MOVEQ   r0, #ERROR_BADNAME
        BEQ     ErrorExit

        ADR     R3, TempArea
        MOV     R4, R3                     

04                              
        LDRB    R2, [ R1 ], #1          ; 
        STRB    R2, [ R3 ], #1          ; 
        TEQ     R2, #"."                ; 
        TEQNE   R2, #0                  ; 
        TEQNE   R2, #&0D                ; 
        TEQNE   R2, #SPACE              ; 
        BNE     %BT04                   ; 

        ; Make sure that 'drive.&', 'drive.%', 'drive.\', 'drive.@'
        ; give a 'bad name' error

        TEQ     R2, #0
        BEQ     fine

        LDRB    R2, [ R1 ]
        TEQ     R2, #"&"
        TEQNE   R2, #"%"
        TEQNE   R2, #"\\"
        TEQNE   R2, #"@"

        MOVEQ   r0, #ERROR_BADNAME
        BEQ     ErrorExit

fine

        MOV     R2, #0                  ; Null terminate entry
        STRB    R2, [ R3, #-1 ]         
        MOV     R1, R4                  

        Push    "R0"

        MOV     R0, #10
        SWI     XOS_ReadUnsigned

        Pull    "R0"                    ; must be a name
        BVS     SoItIsADiscName
                                        ; was a number

        CMP     R2, #MAXNUMBEROFDRIVESSUPPORTED
        MOVGT   r0, #ERROR_BADDRIVE
        BGT     ErrorExit

        MOV     R1, R2

        Pull    "R0, R2 - R7, PC"

;******************
SoItIsADiscName
;******************

        MOV     R0, R4
        BL      CheckDiscName           ; R0 -> disc name, RETURNS R1 TRUE/FALSE

        TEQ     R1, #FALSE
        MOVEQ   r0, #ERROR_BADNAME
        BEQ     ErrorExit

        BL      FindDiscNameInList      ; R0 -> disc name, RETURNS R1 = drive number

        CMP     R1, #-1                 ; Disc known ?
        LDREQB  R1, CurrentDriveNumber  ; [ no ]
        BL      PromptForDisc           ; R0 -> disc name to prompt for, R1 = drive

        Pull    "R0, R2 - R7, PC"       ; 'V' already cleared


;********************************************************************
PromptForDisc ROUT ; R0 -> name of disc, R1 = drive number
;********************************************************************

        Push    "R0 - R8, R14"
        
        ; First look at disc in drive to see if known
        
        MOV     R6, R0
        MOV     R8, R1
        MOV     R2, R0
                
        LDR     R14, discbuffersize
        TEQ     R14, #0
        BEQ     fiddle_buffer_for_prompt

;-----------------------------
; Is disc in drive already ?
;-----------------------------

        ; Is drive mounted ?
        ; Is disc in drive same ?
        ; Is disc_name in disc list ?        - no so not_in_memory

        BL      FindDiscNameInList      ; R0 -> disc name, RETURNS R1 = drive number
        CMP     R1, #-1                 ; Disc known ?
        BEQ     fiddle_buffer_for_prompt

        ; Is drive same as requested drive ? - no so not_in_memory
        TEQ     R8, R1
        BNE     fiddle_buffer_for_prompt

        ; Is disc in drive same as requested disc ?
        Push    "R2"

        MOV     R2, #1
        MOV     R0, R8
        BL      GetUniqueNumber
        TEQ     R1, #0
        Pull    "R2"
        BEQ     fiddle_buffer_for_prompt

        ADRL    R14, discsMounted
        LDR     R14, [ R14, R0, LSL #2 ]
        CMP     R14, R1
        ; Yes so exit without prompt
        Pull    "R0 - R8, PC", EQ

        B       fiddle_buffer_for_prompt

;-----------------------------

not_in_memory

        MOV     R0, R6

prompt_for_disc

        MOV     R1, #fsnumber_CDFS      ; R1 = CDFS
        MOV     R2, R0                  ; R2 -> disc name
        MOV     R3, R8                  ; R3 = drive number
        MOV     R0, #UpCall_MediaNotPresent
        MOV     R4, #0                  ; R4 = iteration count
        MOV     R5, #-1                 ; R5 = Timeout never
        ADR     R6, COMPACTDISC         ; R6 = media type name
        SWI     XOS_UpCall

        MOVVS   r0, #ERROR_DISCNOTFOUND
        BVS     ErrorExit


        TEQ     R0, #0                  ; Forget it ?
        MOVNE   r0, #ERROR_DISCNOTFOUND
        BNE     ErrorExit

fiddle_buffer_for_prompt

        MOV     R0, R8
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> controlblock
        BVS     ErrorExit

;********
; Is drive ready ?
;********

        SWI     XCD_DriveStatus
        TEQ     R0, #1                  ; Drive not ready so try again
        SETV    NE                      ;
        LDMVSIA sp, {R0 - R8, R14}      ; Recover entry regs
        MOVVS   R8, R1                  ;
        BVS     prompt_for_disc         ;
                
        MOV     R0, #LBAFormat          ;
        MOV     R1, #PVD                ; R1 = some valid block number that always exists  
        SWI     XCD_EnquireDataMode     ; make sure that disc is in mode 1 or 2

        ; This just makes sure that it's not an audio disc
        TEQ     r0, #0
        SETV    EQ
        LDMVSIA sp, {r0 - r8, r14}      ; Recover entry regs
        MOVVS   r8, r1
        BVS     prompt_for_disc

        SWI     XCD_DiscHasChanged


        Push    "R2 - R3"
        MOV     R0, #PVD                ; Call to GetDiscNameNotInBuffer tries the SVD if needed
        MOV     R2, #1
        MOV     R3, R8
        BL      PreLoadBlockFromDrive   ; R0 = block, R1 -> memory, R2 = length ( blocks )
                                        ; R3 = drive number
        Pull    "R2 - R3"

        MOV     R0, R8                  
        BL      GetDiscNameNotInBuffer  ; R0 = drive, R1 -> name of disc in drive
        MOV     R0, R1                  
        BL      CutSpace                ; R0 -> disc name
                                        
        MOV     R1, R2                  ; R0 -> disc name to hope for

        LengthOfString R0, R2, R14
        LengthOfString R1, R3, R14

        TEQ     R2, R3
        BLEQ    CompareStrings          ; returns 'eq' or 'ne'

        LDMNEIA sp, {R0 - R8, R14}      ; Recover entry regs
        MOVNE   R8, R1
        BNE     prompt_for_disc

        ; Found the right disc, now tell UpCall about it
        MOV     R0, #UpCall_MediaSearchEnd
        SWI     XOS_UpCall
                
        Pull    "R0 - R8, PC"

COMPACTDISC
        DCB     "CD-ROM", 0             ; Keep together
        ALIGN

;********************************************************************
FindDiscNameInList ROUT    ; R0 -> disc name, RETURNS R1 = drive number
                           ;                          R1 = -1 if not found
;********************************************************************

; R2 -> disc name in list
; R5 = number of discs left to search
; R6 -> disc name to search for
; R8 = -1 if no names found so far, else = drive found at

        Push    "R0, R2 - R8, R14"
                
        MOV     R8, #-1
        MOV     R5, #MAXNUMBEROFDRIVESSUPPORTED
        MOV     R7, R0
        ADRL    R2, DiscNameList

REPEAT_find_disc_name

        MOV     R4, R2                  ; R4 -> disc name in list
        MOV     R6, R7                  ; R6 -> start of name to search for
        ADD     R0, R4, #MAXLENGTHOFDISCNAME ; R0 -> end of R4

REPEAT_compare_disc_names               ; Is disc name in list = disc name ?
                                        ;
        LDRB    R3, [ R4 ], #1          ;
        LDRB    R1, [ R6 ], #1          ;

        CMP     R4, R0                  ; End of disc name ?
        BGE     disc_name_not_found     ; [ yes ]

        TEQ     R3, #0                  ;
        TEQEQ   R1, #0                  ; If both terminate at same time,must be same
        BEQ     UNTIL_compare_disc_names

        CMP     r3,#'A'
        RSBGES  r14,r3,#'Z'
        SUBGE   r3,r3,#&20
        CMP     r1,#'A'
        RSBGES  r14,r1,#'Z'
        SUBGE   r1,r1,#&20
        TEQ     r3,r1
        BEQ     UNTIL_compare_disc_names

        TEQ     R3, R1                    
        BEQ     REPEAT_compare_disc_names 
                                        ;
                                        ; [ no ]

disc_name_not_found

        SUBS    R5, R5, #1
        ADDNE   R2, R2, #MAXLENGTHOFDISCNAME
        BNE     REPEAT_find_disc_name
                
        CMP     R8, #-1                 ; Name occurs once, ie/ NOT Ambig name
        MOVNE   R1, R8                  ;
        Pull    "R0, R2 - R8, PC", NE


        MOV     R1, #-1                 ; not found
                                        ;
        Pull    "R0, R2 - R8, PC"       ;


UNTIL_compare_disc_names

        CMP     R8, #-1                 ; Ambiguous disc name check
        BEQ     %FT10

        addr    r0, AmbiguousDiscNameError_tag
        ADR     r1, message_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        BVS     ErrorExit
10
        RSB     R8, R5, #MAXNUMBEROFDRIVESSUPPORTED ; drive found at = 28 - R5
        
        SUBS    R5, R5, #1
        ADDNE   R2, R2, #MAXLENGTHOFDISCNAME
        BNE     REPEAT_find_disc_name
        
        MOV     R1, R8
        Pull    "R0, R2-R8,PC"

;********************************************************************
AddDiscNameInList ; R0 = drive number, R1 -> disc name
 ROUT
;********************************************************************

        Push    "R0 - R7, R14"

        ; Find where to put the name

        ADRL    R2, DiscNameList         ; R2 -> start of list place to put name
      [ MAXLENGTHOFDISCNAME<>32
        MOV     R3, #MAXLENGTHOFDISCNAME ;
        MLA     R2, R0, R3, R2           ;
      |
        ADD     R2, R2, R0, LSL #5
      ]
        ADD     R3, R2, #MAXLENGTHOFDISCNAME ; R3 -> end of disc name in list
        MOV     R5, R2

REPEAT_copy_disc_name

        LDRB    R4, [ R1 ], #1
        STRB    R4, [ R2 ], #1
        CMP     R2, R3

        BLT     REPEAT_copy_disc_name
                
        MOV     R2, #0
        STRB    R2, [ R3, #-2 ]
                
        Pull    "R0 - R7, PC"           ; V clear

;********************************************************************

        LTORG

        END
