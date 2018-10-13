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
;-> DiscOp

;***************************************************************************

;***************************************************************************

; This part contains :

;     Entry
;     GetDiscName
;     TestKnowDisc
;     InitialiseBufferForDisc
;     AwkwardMemory
;     ReadMainDirectory
;     StoreDirectory
;     GetUniqueNumber
;     ConvertDriveNumberToDeviceID
;     GetDiscNameNotInBuffer
;     ChangeDiscMode

; Buffer procedures:
; ----------------
;     AddDiscToBufferList
;     ClaimMemoryForBuffer           OK
;     DeleteBuffer           ( by unique number )
;     DisplayBuffers
;     FindDiscInBufferList           OK
;     FindDiscNameInDiscBuffer
;     AddDirectoryToBuffer


;***************************************************************************
TestKnowDisc ROUT; R0 = drive number, RETURNS R1 -> buffer, RETURNS R2=number
;***************************************************************************

; If the disc is found to be changed THEN
;    {
;     Read name of disc
;     If not same as disc in memory THEN
;     ELSE
;         {
;          Store this name as the new disc
;          Find disc type, block size
;          Find start LBA of main directory
;          Read in main directory into memory buffer
;         }
;     }

; R4 = disc number
; R7 -> control block for drive

        Push    "R0, R3 - R7, R14"

;*********************
; R7 -> control block for drive
;*********************

        BL      PreConvertDriveNumberToDeviceID ; R0 = drive, R7 -> control block
        BVS     ErrorExit

;*********************
; Make sure that drive is not busy
;*********************

        ; R5 = end time if need to retry

        Push    "R0"

        ; Read monotonic time into R5
        ; R5=R5 + BUSYRETRYTIME

        SWI     XOS_ReadMonotonicTime   ; returns R0 = time
        ADD     R5, R0, #BUSYRETRYTIME

        ;repeat
01
                
        SWI     XCD_DriveReady
        BVS     ErrorExit
                
        TEQ     R0, #READY
        BEQ     %FT02
                
        ; If busy then read monotonic time into R0
        ; If R0 < R5 and busy THEN retry

        SWI     XCD_StopDisc
        SWI     XOS_ReadMonotonicTime         ; returns R0 = time
                
        CMP     R0, R5
        BLT     %BT01

02
        Pull    "R0"

        BL      PreGetUniqueNumber ; R0 = drive number, RETURNS R1 = unique number
                                   ; R2 = 0, report errors

        ; Preserve disc changed flag
        MOV     r6, r2

        ; Preserve drive number
        Push    "r0"

        MOV     R0, R1
        MOV     R2, #PVD                ; or the SVD if appropriate
        BL      FindDiscInBufferList    ; R0 = disc number, RETURNS R1 -> buffer
                                        ; R2 = block ( main dir = PVD )
                                        ; C set if not found, else C clear
        MOV     R2, R0

        Pull    "r0"

        BCS     %FT01                   ; Should only need to set disc mode when disc unchanged

        LDRB    r3, [ r1, #DiscBuff_DiscMode ]

        ADRL    r0, buffer
        SWI     XCD_GetParameters
        BVS     ErrorExit

        LDR     r14, [ r0, # 8 ]
        TEQ     r14, r3

        MOVNE   r0, r3
        BLNE    ChangeDiscMode          ; R0 = disc mode to change to

        CLRV
        Pull    "r0, r3 - r7, pc"

01

        ;----------------------------------------------------------------
        ; Find the name of the disc held in memory for the current drive
        ;( R0 = drive number, RETURNS R1 -> buffer, R2 = unique disc number )


;******************************
; Read main directory into w/s
;******************************

        MOV     R4, R2                  ; R4 = unique
                
        ADRL    R1, sparedirectorybuffer ; CANNOT SHORTEN
        MOV     R7, R1                  ; preserve offset for later

        BL      ReadMainDirectory       ; R0 = drive, R1 -> disc buffer, RETURNS R2 = size

;******************************
; Claim space for main directory ( just long enough )
;******************************

        Push    "r2"

        MOV     R0, R2
        MOV     r2, #0
        BL      ClaimMemoryForBuffer    ; R0 = size, r2 = 0 (remove PVD), RETURNs R1 -> buffer 

;******************************
; Add the claimed buffer to the list
;******************************

        MOV     R0, R4
        LDRB    R2, [ R7, #DiscBuff_LBAOfVolDesc ]
        MOV     R3, #PVD                ; Flag for buffer list (might be SVD)
        BL      AddDiscToBufferList     ; R0 = disc, R1 -> buffer, R2 = block, R3 = vol desc flag

        Pull    "r3"                    ; size (for CD_ByteCopy)

;******************************
; Copy from w/s to claimed area
;******************************

        LDR     R0, discbuffersize      ; Don't need to copy if no buffers
        TEQ     R0, #0                  ;

        Push    "R1,R4"
                
        MOVNE   R2, R1
        MOVNE   R1, R7
        CD_ByteCopy NE                  ; R1 -> from, R2 -> to
                                        ; R3 = length

        Pull    "R1,R2"

        CLRV
        Pull    "R0, R3 - R7, PC"       ; disc in drive

        LTORG
CDROM     DCB   "CDROM"
CD001     DCB   "CD001"
CDIString DCB   "CD-I"
        ALIGN

;***************************************************************************
ReadMainDirectory ROUT;( R0 = drive, R1 -> disc buffer,
                      ; RETURN R2=size )
;***************************************************************************

        ; R5 = drive number

        Push    "R0 - R1, R3 - R9, R14"

        MOV     R5, R0

        ; Find disc mode

        Push    "R1"
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive, R7 -> control block
        MOVVC   R0, #LBAFormat
        MOVVC   R1, #PVD                ; R1 = some valid block number that always exists 
        SWIVC   XCD_EnquireDataMode     ; RETURNS R0 = disc mode
        BVS     ErrorExit

        BL      ChangeDiscMode          ; R0 = disc mode ( 1 to 2 )
                
        LDR     R1, [sp]                ; Recover disc buffer pointer
        STRB    R0, [ R1, #DiscBuff_DiscMode ]
        MOV     R0, R5

;*******************************************************************************************
; This will check for ISO / HISIERRA / CD-I standard
;*******************************************************************************************

        ; R0 = drive number, R1 -> disc buffer
        ; Check for ISO 9660 / Hi-Sierra / CD-I disc or unknown format disc

        Push    "R0 - R7"
                
        MOV     R3, R0
        MOV     R7, R1                  ; Backup R7 -> disc buffer
        MOV     R8, R0                  ; Backup R8 = drive number
        MOV     R0, #PVD
        STRB    R0, [ R7, #DiscBuff_LBAOfVolDesc ]
        MOV     R2, #1
        BL      PreLoadBlockFromDrive   ; R0 = block, R1 = memory, R2 = no. blocks
                                        ; R3 = drive

        Push    "R1"                    ; sector buffer memory
                
        addr    R0, CDROM               ; IS IT A HISIERRA DISC ?
        ADD     R1, R1, #HiSierraVolDescId
        MOV     R2, #?CDROM
        BL      CompareStrings          ; returns 'EQ' or 'NE'
        MOVEQ   R3, #DISCTYPE_HISIERRA  ;
        BEQ     TKD_SortedDiscType      ; [ yes ]

        addr    R0, CD001
        SUB     R1, R1, #HiSierraVolDescId - IsoVolDescId
        ASSERT  ?CDROM = ?CD001
        BL      CompareStrings          ; returns 'EQ' or 'NE'
        BNE     %FT10

        ADRL    R0, buffer
        MOV     R1, R8
        BL      TryLoadingSVD           ; R0 -> PVD buffer; R1 = drive
        AND     R3, R0, #255
        MOV     R0, R0, LSR #8
        STRB    R0, [ R7, #DiscBuff_LBAOfVolDesc ]
        B       TKD_SortedDiscType


10
        addr    r0, CDIString
        ASSERT  CdiVolDescId = IsoVolDescId 
        MOV     r2, #?CDIString
        BL      CompareStrings          ; returns 'EQ' or 'NE'
        MOVEQ   r3, #DISCTYPE_CDI

        MOVNE   r0, #ERROR_NOTISO
        BNE     ErrorExit

TKD_SortedDiscType
        STRB    R3, [ R7, #DiscBuff_DiscType ]

        Pull    "R1"

;*****************************     Find logical 'blocksize'

        Push    "r3"

        TST     r3, #DISCTYPE_ISO
        LDRNEB  R4, [ R1, #IsoVolDescLogicalBlockSize + 0 ]
        LDRNEB  R0, [ R1, #IsoVolDescLogicalBlockSize + 1 ]
        LDREQB  R4, [ R1, #HiSierraVolDescLogicalBlockSize + 0 ]
        LDREQB  R0, [ R1, #HiSierraVolDescLogicalBlockSize + 1 ]

        ;----------------------------------------------------------------------
        ; CD-I doesn't write out the little endian format, only big
        ; who invented compact disc ?
        ;----------------------------------------------------------------------

        TST     r3, #DISCTYPE_CDI
        LDRNEB  r0, [ r1, #IsoVolDescLogicalBlockSize + 2 ]
        LDRNEB  r4, [ r1, #IsoVolDescLogicalBlockSize + 3 ]

        ORR     R0, R4, R0, LSL #8            ; SEE BELOW IF CHANGE THIS REG
        STR     R0, [ R7, #DiscBuff_BlockSize ]

;*****************************  Find LBA of main directory

        TST     r3, #DISCTYPE_ISO

        ADDNE   R14, R1, #IsoVolDescDirRecordRoot + DirRecLBAOfFile
        ADDEQ   R14, R1, #HiSierraVolDescDirRecordRoot + DirRecLBAOfFile

        LDRB    R3, [ R14, #0 ]
        LDRB    R4, [ R14, #1 ]
        LDRB    R5, [ R14, #2 ]
        LDRB    R6, [ R14, #3 ]
        ORR     R3, R3, R4, LSL #8
        ORR     R3, R3, R5, LSL #16
        ORR     R3, R3, R6, LSL #24
        LDRNEB  r6, [ r1, #IsoVolDescDirRecordRoot + DirRecLBAOfFile - 1 ]  ; XAR NC and MW
        ADDNE   r3, r3, r6

        Pull    "r14"

        ;----------------------------------------------------------------------
        ; CD-I places the LBA of the root directory in the path table entry,
        ; and points to a CD-I root directory. It's big endian too.
        ;----------------------------------------------------------------------
        TST     r14, #DISCTYPE_CDI
        LDRNEB  r3, [ r1, #CdiVolDescLocOfMPathTable + 3 ]
        LDRNEB  r4, [ r1, #CdiVolDescLocOfMPathTable + 2 ]
        LDRNEB  r5, [ r1, #CdiVolDescLocOfMPathTable + 1 ]
        LDRNEB  r6, [ r1, #CdiVolDescLocOfMPathTable + 0 ]

        ORRNE   r3, r3, r4, LSL #8
        ORRNE   r3, r3, r5, LSL #16
        ORRNE   r3, r3, r6, LSL #24
        ADDNE   r3, r3, # 1

        STR     R3, [ R7, #DiscBuff_LBAOfMainDir ]

;***************************** ; Size of main directory

        TST     r14, #DISCTYPE_ISO
        ADDNE   R2, R1, #IsoVolDescDirRecordRoot + DirRecExtentOfFile + 4
        ADDEQ   R2, R1, #HiSierraVolDescDirRecordRoot + DirRecExtentOfFile + 4

        ;-----------------------------------------------------------
        ; Don't know size of root directory for CD-I so overestimate
        ;-----------------------------------------------------------

        TST     r14, #DISCTYPE_CDI
        MOVNE   r6, # 4

        LDREQB  R6, [ R2, #3 ]          ; R2 -> start of size of main dir
        LDREQB  R3, [ R2, #2 ]          ;
        LDREQB  R4, [ R2, #1 ]          ;
        LDREQB  R5, [ R2, #0 ]          ;
        ORREQ   R6, R6, R3, LSL #8      ;
        ORREQ   R6, R6, R4, LSL #16     ;
        ORREQ   R6, R6, R5, LSL #24     ;

        STR     R6, [ R7, #DiscBuff_SizeOfMainDir ]
        LDRB    R14, [ R7, #DiscBuff_DiscType ]

        Pull    "R0 - R7"
        
        MOV     R0, R14                            ; R0 = disc type
        ADD     R1, R1, #DiscBuff_DiscName         ; R1 -> disc name in a buffer
        BL      GetDiscNameFromVolDesc             ; assumes 'buffer' contains PVD
        
        MOV     R0, R1
        BL      CutSpace

        Pull    "R1"

I_Know_The_Details

        LDR     R0, [ R1, #DiscBuff_LBAOfMainDir ] ; R0 = start block of main dir
        LDR     R4, [ R1, #DiscBuff_BlockSize ]    ; R4 = blocksize
        LDRB    R3, [ R1, #DiscBuff_DiscType ]     ; R3 = disc type
        ADD     R1, R1, #DiscBuff_MainDirBuffer

        ; R0 = start LBA, R1 -> place to put, R2 NOT USED
        ; R3 = disc type, R4 = blocksize, R5 = drive number, RETURNS R6 = size of mem
                
        MOV     R6, #0
        BL      StoreDirectory
                
        ADD     R2, R6, #DiscBuff_MainDirBuffer

        ; --- Find size of disc --- NEED THIS FOR SOFTWARE SOLUTIONS NETWORK ?

        MOV     R4, R1
                
        ADRL    R1, buffer
        MOV     R0, #LBAFormat
        SWI     XCD_DiscUsed               ; r0 = 0, R1 -> BUFFER, R7 -> control block
        LDR     R14, [ R1, #0 ]            ; number of blocks
        LDR     R9, [ R4, #DiscBuff_BlockSize - DiscBuff_MainDirBuffer ]
        MUL     R8, R9, R14
                
        STR     R8, [ R4, #DiscBuff_SizeOfDisc - DiscBuff_MainDirBuffer ]

        Pull    "R0 - R1, R3 - R9, PC"


;***************************************************************************
StoreDirectory ROUT;
; on entry:
;          R0 = start LBA
;          R1 -> place to put
;          R2  NOT USED
;          R3 = disc type
;          R4 = blocksize
;          R5 = drive number
;          R6 = 0 THEN skip 2 entries, ELSE don't skip any
; on exit:
;          R6 = size of mem, =0 if reached end of directory, =4 if empty dir
;          flags not preserved
;***************************************************************************

        ; temp3 Lobyte = replace _ with !
        ; temp3+1 = length of name ( - 1 if ';' )
        ; R5 = tempDiscType
        ; R6 = last LBA
        ; R7 =
        ; R8 = 1 if ARCHY, 0 if PC object
        ; R9 -> place to put in memory
        ; R10 -> place to get from ( 'buffer' )
        ; R11 = substitute filetype
        
        Push    "R0 - R5, R7 - R11, R14"
        
        MOV     R9, R1

        ; Work out logical sector size from logical block size and block number
        ASSERT  myblocksize = 2048
      [ {FALSE}
        MUL     R8, R0, R4
        MOV     R0, R8, LSR #11        ; R0=( startLBA * log. block size ) / log. sector size
      |
        ; The logical block size is specified in ISO9660 as 2^(n+9) for n >= 0
        ; so we can preshift the calculation to avoid overflowing (up to 2TB-1 anyway)
        MOV     R8, R4, LSR #9
        MUL     R8, R0, R8
        MOV     R0, R8, LSR #11-9      ; R0=( startLBA * log. block size ) / log. sector size
      ]

        ; Lookup the substitute type
        Push    "R0-R1,R3"
        SUB     SP, SP, #12
        ADRL    R0, DollarDefaultType
        MOV     R1, SP
        MOV     R2, #12                ; Max 8 letter due to Service_LookupFiletype
        MOV     R3, #0
        MOV     R4, #VarType_Expanded
        SWI     XOS_ReadVarVal
        MOVVC   R0, #FSControl_FileTypeFromString
        SWIVC   XOS_FSControl
        MOVVC   R11, R2
        LDRVS   R11, =FileType_Data    ; No variable, too long, or not known - use data 
        ADD     SP, SP, #12
        Pull    "R0-R1,R3"

        Swap    R5, R3

        MOV     R2, #1
        BL      PreLoadBlockFromDrive  ; R0 = block, R1 -> memory, R2 =length, R3 =drive

        MOV     R10, R1

        ; --- skip past first 2 null entries ? ---
        ; ALSO check to see if entry is 0, ie/ no more entries / early end

        TEQ     R6, #0                  

        ASSERT  DirRecRecordSize = 0                                        
        LDRB    R2, [ R10 ]             ; R2 = length of current entry
        LDREQB  R2, [ R10, R2 ]!        ; R0 = R0 + R2 = start of next entry
        LDREQB  R2, [ R10, R2 ]!        ; R0 = R0 + R2 = start of next entry

        TEQ     R2, #0                  ; empty directory
        STREQ   R2, [R9, #0]
        MOVEQ   R6, #4
        Pull    "R0-R5,R7-R11,PC", EQ   ; exit on empty directory

;***************
; Set up start of loop stuff
;***************

repeat_get_dir_contents

        ADD     R2, R10, #DirRecLBAOfFile  ; MUST ALSO PUT IN THE LBA start of file
                                        
        LDW     R3, R2, R0, R4          

        TST     r5, #DISCTYPE_CDI          ; Big endian only on CD-I
        LDRNEB  r3, [ r10, #DirRecLBAOfFile + 7 ]
        LDRNEB  r0, [ r10, #DirRecLBAOfFile + 6 ]
        LDRNEB  r2, [ r10, #DirRecLBAOfFile + 5 ]
        LDRNEB  r14,[ r10, #DirRecLBAOfFile + 4 ]
        ORRNE   r3, r3, r0, LSL #8
        ORRNE   r3, r3, r2, LSL #16
        ORRNE   r3, r3, r14, LSL #24

        ; if there is an extended record byte, then add it

        LDRB    R2, [ R10, #DirRecXASize ]
        ADD     R3, R3, R2

        ; If block = 0, then probably because 0 length.
        ; 0 LBA signifies no more entries !!!!!

        MOVS    R3, R3, LSL #8
        MOVEQ   R3, #1:SHL:8
                
        STR     R3, [ R9, #LBASTARTOFFSET ]

;****************
; Copy file name into 'temparea' and convert to uppercase
;****************

        ADD     R2, R10, #DirRecName    ; R2 -> name
        LDRB    R1, [ R10, #DirRecNameSize ] ; R1 = length of name

        ; RockRidge extensions
        
        LDRB    R3,[R10,#DirRecRecordSize]
        ADD     R4,R10,R3               ; r4 -> eof
        LDRB    R14,[R2,R1]!            ; r2 -> start of extended info
        TEQ     R14,#0                  
        ADDEQ   R2,R2,#1                ; skip null byte if there
rrloop   
        CMP     R2,R4                   ; eof yet?
        BGE     rrfinishup              
        LDRB    R14,[R2],#1             
        TEQ     R14,#'N'                ; check for "NM" signature
        LDREQB  R14,[R2]                
        TEQEQ   R14,#'M'                
        BEQ     rrfoundnm               
        LDRB    R14,[R2,#1]
        TEQ     R14,#0                  
        ADD     R2,R2,R14               
        SUBNE   R2,R2,#1                
        B       rrloop                  
rrfoundnm
        ADD     R2,R2,#1                ; [N] [M] [length] [version] [flags] = 5
        LDRB    R14,[R2],#3
        SUB     R14,R14,#5              ; Length of just the name portion
        ADD     R1,R14,R2
        B       rrdone
rrfinishup
        TST     R5, #DISCTYPE_JOLIET
        LDRNEB  R2, [ R10, #DirRecNameSize ]
        ADDNE   R1, R10, #DirRecName
        MOVNE   R0, R5
        BLNE    CrunchUCS2String
        
        ADD     R2, R10, #DirRecName    ; go back to ISO name area
        LDRB    R1, [ R10, #DirRecNameSize ] ; R1 = length of name
        ADD     R1, R1, R2
rrdone
        ADR     R4, TempArea
        MOV     R0, R4

        ; R1 -> end of name
        ; R2 -> start of name
01
        LDRB    R3, [ R2 ], #1
        STRB    R3, [ R4 ], #1

        TEQ     R2, R1                  ; Termination ?
        TEQNE   R3, #";"                ; [ yes ]
        BNE     %BT01

        TEQ     R3, #";"                ; Chop off ';' if there
        MOV     R3, #0                  ;
        STREQB  R3, [ R4, #-1 ]!        ;
        STRNEB  R3, [ R4 ]              ;

        LDRB    R3, [ R4, #-1 ]         ; Should not be terminated with '.'
        TEQ     R3, #DOT                ;
        MOVEQ   R3, #0                  
        STREQB  R3, [ R4, #-1 ]!        

        SUB     R4, R4, R0              ; Save length of name
        STRB    R4, temp3+1             ;

;******************
; Is it an Archy disc ?
;******************

        LDRB    R2, [ R10 ]             ; Is it an Archy file ?
                
        SUB     R2, R2, #ARCHYFIELD
                
        ADD     R1, R2, R10
        ADRL    R0, ARCHIMEDES
        MOV     R2, #:LEN:"ARCHIMEDES"
                
        MOV     R6, R9                  ; R6 -> start of object info
                
        BL      CompareStrings          ; returns 'eq' or 'ne'

        ; remember if object was Archy or PC (other)

        BICNE   R8, R8, #1
        ORREQ   R8, R8, #1

        BEQ     archy_do                ; Branch to extracting Archy info

;****************
; Not an Archy disc, so lie
;****************

        ; on entry:
        ; R5 = ISO / HISIERRA / CDI disc
        ; R6 -> start of object info
        ; R9 -> start of object info
        
        ; on exit: ( B archy_done )
        ; R5 = ISO / HISIERRA / CDI disc
        ; R6 -> start of object info
        ; R9 -> end of object name

        MOV     R3, #read_attribute :OR: public_read_attribute
        STRB    R3, [ R9, #FILEATTRIBUTESOFFSET ]
                                                
        ADR     R0, TempArea       
        SWI     XCDFS_GiveFileType      ; returns R1 = file type
        TEQ     R1, #0                          
        MOVEQ   R1, R11                 ; not a known extension, so lie

        LDR     R3, =&FFF00000
        ORR     R3, R3, R1, LSL #8
        STR     R3, [ R9, #LOADADDRESSOFFSET ]
        MOV     R3, #0
        STR     R3, [ R9, #EXECUTIONADDRESSOFFSET ]

;***************
; Copy name into buffer, truncate length, and put in '!' if needed
;***************

; name ( in any case ) is already at 'TempArea'
; R0 -> copy from
; R1 -> copy to
; R2 = 0 if no pling, else pling set

        ADD     R9, R9, #OBJECTNAMEOFFSET
        LDRB    R4, [ R10, #32 ]
        ADR     R0, TempArea

;*************
; If no '.' in name
;*************

        LDRB    R14, truncation
        Debug   mi, "Truncate mode", R14
        LDR     R1, [ PC, R14, LSL #2 ]
        ADD     PC, PC, R1
jump
        DCD     truncate_from_right - jump - 4
        DCD     truncate_from_left - jump - 4
        DCD     no_truncate - jump - 4

no_truncate
        LDRB    R1, [ R0 ], #1
        ReplaceBadCharacters  r1
        STRB    R1, [ R9 ], #1
        TEQ     R1, #0
        BNE     no_truncate
        B       done_archy

truncate_from_left
        LDRB    R14, temp3+1            ;This truncates from the left
        SUBS    R1, R14, #10            
        ADDGE   R0, R1, R0              
        ADDGE   R2, R0, #11             
        ADDLT   R2, R0, R14             
        ADDLT   R2, R2, #1              

; R0 = current char
; R1 = start of name
; R2 -> end of name
; R3 -> char to get next
; R9 -> put name here
; R14 = corrupted

        MOV     R1, R0                  ; This truncates from the left
01
        LDRB    R3, [ R0 ], #1
        ReplaceBadCharacters  r3
        STRB    R3, [ R9 ], #1          ; Save char if not at end
        CMP     R0, R2                  ; End of length of name ?
        BLT     %BT01                   ; [ no ]
        TEQ     R3, #0
        TEQNE   R3, #REPLACEMENTFORDOT  ; null terminate
        MOVNE   R14, #0
        STRNEB  R14, [ R9 ], #1
        B       done_archy

truncate_from_right
        LDRB    R2, temp3+1             
        CMP     R2, #10 + 1             ; Max length for Risc OS 2.00
        ADDGE   R2, R0, #10 + 1         ;
        ADDLT   R2, R2, R0              
        ADDLT   R2, R2, #1              

;***************
; Sort out name properly
;***************

; R0 = current char
; R1 = start of name
; R2 -> end of name
; R3 -> char to get next
; R9 -> put name here
; R14 = corrupted

        MOV     R1, R0

01
        LDRB    R3, [ R0 ], #1
        ReplaceBadCharacters  r3
        STRB    R3, [ R9 ], #1          ; Save char if not at end
        
        CMPNE   R0, R2                  ; End of length of name or found dot ?
                                        ;
        BLT     %BT01                   ; [ no ]

;***************
; If found a dot and length of name > MAXLENGTHOFNAME + 1 THEN truncate
;***************

        ; If no dot THEN null terminate, go and check extension ( 02 )

        TEQ     R3, #REPLACEMENTFORDOT   
        MOVNE   R3, #0                  ; null terminate
        STRNEB  R3, [ R9, #-1 ]         
        BNE     done_archy              

        ; If name length < MAXNAMELENGTH THEN copy rest of name THEN B %FT02
        LDRB    R14, temp3+1            ; R14 = length of name
        CMP     R14, #10 + 1
        BLT     %BT01
        
        ; NOW -
        ; 1. Make R0 -> end of object name on disc
        ADD     R0, R1, R14

        ; 2. Is [R0] = ";" - yes then R0 = R0 -1

        LDRB    R14, [ R0 ]
        TEQ     R14, #";"
        SUBEQ   R0, R0, #1

        ; 3. copy from ( R0 - 3 ) to ( R6 + offset + maxlengthofname - 3 ) length 3
        ;   check for 'dot' while copying
        ;
        ; R1 = start copying from
        ; R9 = copy to
        ; R0 = end of copying from
        ; R14 = char

        ADD     R9, R6, #OBJECTNAMEOFFSET + 10 - 4
        SUB     R1, R0, #3
                
        MOV     R14, #REPLACEMENTFORDOT
        STRB    R14, [ R9 ], #1

06
        LDRB    R14, [ R1 ], #1
        ReplaceBadCharacters  r14
        STRB    R14, [ R9 ], #1
        
        CMP     R1, R0
        BLE     %BT06
        
        ; R9 should point at end of name
        
        MOV     R3, #0
        STRB    R3, [ R9, #-1 ]
        B       done_archy

;**************
; It is an Archy prog so ...
;**************

archy_do

        ADD     R3, R1, #:LEN:"ARCHIMEDES"
                
        LDW     R4, R3, R2, R14
        STR     R4, [ R9, #LOADADDRESSOFFSET ]
                
        ADD     R3, R3, #4
                
        LDW     R4, R3, R2, R14
        STR     R4, [ R9, #EXECUTIONADDRESSOFFSET ]
                
        ADD     R3, R3, #4              ; Load whole word, but only
        LDW     R4, R3, R2, R14         ; save low byte
                                        ; bit 8 = pling bit
        STRB    R4, [ R9, #FILEATTRIBUTESOFFSET ]


;********* Archy name copy ( null terminated )

; R0 -> copy from
; R1 -> copy to
; R4 = file attributes + plingbit
; R14 = temp

        ADR     R0, TempArea
        ADD     R1, R9, #OBJECTNAMEOFFSET

05
        LDRB    R14, [ R0 ], #1
        ReplaceBadCharacters R14
        STRB    R14, [ R1 ], #1
        TEQ     R14, #0
        BNE     %BT05

        TST     R4, #ARCHYPLINGBIT
        MOVNE   R4, #"!"
        STRNEB  R4, [ R9, #OBJECTNAMEOFFSET ]

        MOV     R6, R9
        MOV     R9, R1

;****************
; Take care of rest, no matter what type of disc
;****************

done_archy

; on entry:
; R5 = ISO / HISIERRA / CDI
; R6 -> start of object info
; R9 -> end of object name in object info

;******************
; File or directory ?
;******************

        TST     R5, #DISCTYPE_ISO
        LDRNEB  R4, [ R10, #DirRecFlags ]
        LDREQB  R4, [ R10, #DirRecHiSierraFlags ]

        ;-------------------------------------------------------
        ; CDI doesn't seem to use the normal ISO directory flag
        ;-------------------------------------------------------
        TST     r5, #DISCTYPE_CDI
        LDRNEB  r4, [ r10, #DirRecRecordSize ]
        SUBNE   r4, r4, # CDI_ADDINFO_LENGTH - CDI_ADDINFO_FLAGS
        LDRNEB  r4, [ r10, r4 ]
        MOVNE   r4, r4, LSR # CDI_DIRECTORY_TYPE_SHIFT

      [ CDFix_OpaqueFiles
        TST     R4, #DirRecFlags_Opaque ; Mac opaque types
        BLNE    FixOpaqueFile           
      ]
        TST     R4, #DirRecFlags_Dir
        MOVEQ   R4, #object_file
        MOVNE   R4, #object_directory
        STRB    R4, [ R6, #OBJECTTYPEOFFSET ]

;******************
; Keep data length
;******************

        ADD     r4, r10, #DirRecExtentOfFile
        LDW     r3, r4, r2, r14

        TST     r5, #DISCTYPE_CDI       ; Big endian only on CD-I
        LDRNEB  r3, [ r10, #DirRecExtentOfFile + 7 ]
        LDRNEB  r4, [ r10, #DirRecExtentOfFile + 6 ]
        LDRNEB  r2, [ r10, #DirRecExtentOfFile + 5 ]
        LDRNEB  r14,[ r10, #DirRecExtentOfFile + 4 ]
        ORRNE   r3, r3, r4, LSL # 8
        ORRNE   r3, r3, r2, LSL # 16
        ORRNE   r3, r3, r14, LSL # 24

        ;-----------------------------------------------------------------------------------------------
        ; CD-ROM XA (and CD-I) records the file length as being less than it should be for certain files
        ; According to the spec. real-time interleaved files AND CD-DA files are recorded as being
        ; (end_block - start_block) * 2048
        ; This means I have to check for these files AND make sure that they contain mode 2 form 2
        ; sectors, divide them by 2048 then multiply them by 2324 bytes to get the real size.
        ;-----------------------------------------------------------------------------------------------

        ; r3  =  size of file (from directory entry)
        ; r10 -> start of directory entry

        Push    "r0-r2,r4-r5"

        ; If this is an old (green book) CD-I disc, then lie and assume all data is mode 2 form 2
        ; The length of the file does need to change
        TST     r5, #DISCTYPE_CDI
        MOVNE   r5, # ATTRIBUTES__XA_MODE_2_FORM_2
        BNE     SD_CalculateNewLength

        ; r5 = XA attributes
        MOV     r5, # 0
        
        ; Is this a CD-ROM XA/CD-I file ?
        LDRB    r0, [ r10, # 0 ]
        SUB     r0, r0, # XA__LENGTH
        CMP     r0, # 34                ; minimum directory entry size
        BLT     SD_XAJazzOver
        
        LDRB    r0, [ r10, # 32 ]       ; length of file name
        TST     r0, # 1
        ADDEQ   r0, r0, # 33 + 1
        ADDNE   r0, r0, # 33
        ADD     r0, r0, r10
        
        ; r0 -> CD-ROM XA system use information
        
        LDRB    r1, [ r0, # XA__SIGNATURE_1 ]
        TEQ     r1, # ID__XA_SIGNATURE_1
        LDREQB  r1, [ r0, # XA__SIGNATURE_2 ]
        TEQEQ   r1, # ID__XA_SIGNATURE_2
        BNE     SD_XAJazzOver
        
        ; Is this a CD-DA file ?
        LDRB    r1, [ r0, # XA__ATTRIBUTES_2 ]
        LDRB    r2, [ r0, # XA__ATTRIBUTES_1 ]
        ORR     r5, r1, r2, LSL # 8
        ; r5 = XA attributes

        ; Does this file contain mode 2 form 2 sectors ?
        TST     r5, # ATTRIBUTES__XA_MODE_2_FORM_2
        BEQ     SD_XAJazzOver           ; [ no - not mode 2 form 2 ]



SD_CalculateNewLength

        ; Alter the length of the file
        ; ((r3 / 2048) * 2324) + (r3 AND 2047)
        MOV     r1, r3, LSR # 11
        EOR     r2, r3, r1, LSL # 11
        LDR     r14, =USER_DATA_SIZE
        MLA     r3, r14, r1, r2

SD_XAJazzOver

        ; Keep the XA attributes
        STRB    r5, [ r6, # OBJECT__XA_ATTRIBUTES_LO ]
        MOV     r5, r5, LSR # 8
        STRB    r5, [ r6, # OBJECT__XA_ATTRIBUTES_HI ]

        Pull    "r0-r2,r4-r5"

        STR     r3, [ r6, # LENGTHOFFSET ] ; data length

;******************
; Get archy date from ISO / HISIERRA
;******************

        ADD     R0, R10, #DirRecTimeDate   ; R0 -> 6 byte ISO date block
        ADD     R1, R6, #TIMEDATEOFFSET    ; R1 -> put 5 byte Archy block here
        
        ; Work out the date stamped on the ISO / HISIERRA file

        ConvertToArchyDate R0, R1, R2, R3, R4, R7, R14

        ; If object was not an Archy object, then fake a load/exec address

        TST     R8, #1
        ADDEQ   R14, R6, #LOADADDRESSOFFSET
        LDMEQIA R14, { R0, R1 }

        ; CHECK TO SEE IF TIME=0 IF SO, THEN COPY FROM TIMEDATEOFFSET

        TEQEQ   R1, #0
                
        LDREQB  R1, [ R6, #TIMEDATEHIBYTEOFFSET ]
        ORREQ   R0, R1, R0
        LDREQ   R1, =&FFF00000
        ORREQ   R0, R0, R1
        LDREQ   R1, [ R6, #TIMEDATEOFFSET ]
        STMEQIA R14, { R0, R1 }

        ALIGNREG R9                     ; Word align R9

        LDRB    R14, [ R10, #DirRecRecordSize ]
        LDRB    R14, [ R10, R14 ]!      ; R10 = R10 + R14 = start of next entry
        TEQ     R14, #0
                
        BNE     repeat_get_dir_contents

01
        STR     R14, [ R9, #0 ]         ; null terminate if last
        ADD     R6, R9, #4              ; ( allow some room )
        Pull    "R0 - R5, R7- R11, R14" ; R6 = size of mem used
        SUB     R6, R6, R1              ;
        MOV     PC, R14                 ;

ARCHIMEDES
        DCB     "ARCHIMEDES", 0
DollarDefaultType
        DCB     "CDFS$$DefaultType", 0
        ALIGN        

      [ CDFix_OpaqueFiles
FixOpaqueFile
        Push    "r0,r14"
        MOV     r0,#"!"
        STRB    r0,[r9,#-1]
        MOV     r0,#0
        STRB    r0,[r9],#1
        Pull    "r0,pc"
      ]


;***************************************************************************
ClaimMemoryForBuffer ROUT
;
; on entry:
;          r0 = size
;          r2 = disc number of PVD to preserve
; on exit:
;          r1 -> buffer
;          all other regs preserved
;
; History: CDFS 2.16 extra register (r2) added to keep PVDs when searching.
;
;***************************************************************************

        Push    "R0, R2 - R5, R14"

        MOV     r5, r2                  ; r5 = 0 if remove PVDs, <> 0 to preserved PVDs

        LDR     R2, discbuffersize      ; If configured buffers = 0
        TEQ     R2, #0                  ; then use sparedirectorybuffer for it
        ADREQL  R1, sparedirectorybuffer
        Pull    "R0, R2 - R5, PC", EQ
                
        LDRB    R2, numberofbuffersused ; Even if there is enough space for the buf
        LDR     R3, maxnumberofbuffers  ; there may not be enough pointer space
        CMP     R2, R3
        BGE     fnar_fnar

        ADR     R2, discbufferpointer
        LDMIA   R2, { R2, R3, R4 }

        SUB     R2, R3, R2              ; R2 = amount of mem used so far
        SUB     R4, R4, R2              ; R4 = amount of mem left for this buffer
                                        
        CMP     R4, R0                  ; If enough mem left then assign new lot

        MOVGE   R1, R3                  ; new disc buffer = bottom of last one
                
        ADDGE   R3, R3, R0              ; move bottom pointer down
        STRGE   R3, disclastpointer     ;

        Pull    "R0, R2 - R5, PC", GE

fnar_fnar

; Need to delete an old buffer, so:
;
; REPEAT
;
; Delete first disc buffer in list
;
; UNTIL disclastpointer - discbufferpointer >= size required
;
; Move R1 = disclastpointer
; Move disclastpointer down by 'size required'

        MOV     R4, R0                  ; R4 = size required
        LDR     R3, pointerToBufferList ; R0 = unique disc number of first in list

REPEAT_free_space_enough

        LDR     R0, [ R3, #DISC ]
        LDR     R1, [ R3, #BLOCK ]
        LDRB    R2, [ R3, #ISVOLDESC ]

        ;----------------------------------------
        ; If it's a PVD then should I remove it ?
        ;----------------------------------------
        TEQ     r2, #PVD
        TEQEQ   r5, r0
        ADDEQ   r3, r3, #SIZEOFBUFFERENTRY
        BEQ     REPEAT_free_space_enough

        BL      DeleteBuffer            ; R0 = unique disc number, R1 = block

                
        ADR     R0, discbufferpointer
        LDMIA   R0, { R0, R1, R2 }
        SUB     R0, R1, R0            ; amount used
        SUB     R0, R2, R0            ; amount left
        CMP     R4, R0

        BGT     REPEAT_free_space_enough

no_sir
        ADD     R4, R4, R1
        STR     R4, disclastpointer

        Pull    "R0, R2 - R5, PC"

;***************************************************************************
AddDiscToBufferList ROUT; R0 = disc, R1 -> buffer, R2 = block number, R3 = vol desc flag
;***************************************************************************

        ; This automatically saves the truncation type with the buffer details

        Push    "R0 - R7,R14"           
                                        
        LDR     R4, discbuffersize      ; If configured buffer size = 0
        CMP     R4, #0                  ; then redirect to sparebuffer
        Pull    "R0 - R7,PC", EQ        

        ; R0 = disc to add
        ; R1 = buffer to add
        ; R2 = block
        ; R3 -> list of discs buffered
        ; R4 = buffer pointer
        ; R6 = wasted
        ; R7 = combined buffer flags

        ASSERT  TRUNCATION = BUFFERFLAGS + 0
        ASSERT  ISVOLDESC = BUFFERFLAGS + 1
        LDRB    R7, truncation
        ORR     R7, R7, R3, LSL #8

        LDR     R3, pointerToBufferList ; Find end of list
01
        LDMIA   R3!, { R4, R5, R6, R14 }; R3 -> buffer pointer
        TEQ     R5, #0
        BNE     %BT01

        SUB     R4, R3, #SIZEOFBUFFERENTRY
        STMIA   R4, { R0, R1, R2, R7 }

        STR     R5, [ R3, #DISC ]       ; clear last entry
        STR     R5, [ R3, #POINTER ]    
        STR     R5, [ R3, #BLOCK ]
        STR     R5, [ R3, #BUFFERFLAGS ]

        LDRB    R6, numberofbuffersused
        ADDS    R6, R6, #1 ; clears V (unless there are an awful lot of buffers)
        STRB    R6, numberofbuffersused
                
        Pull    "R0 - R7, PC"

;***************************************************************************
DeleteBuffer ROUT; R0 = unique disc number, R1 = block
;***************************************************************************

        Push    "R0 - R9, R14"
                
        LDR     R3, discbuffersize      ; If configured buffer size = 0
        CMP     R3, #0                  ; then cannot delete a buffer !
        Pull    "R0 - R9, PC", EQ       ; ( so ignore )

        ; R1 = disc number
        ; R2 = pointer
        ; R3 -> list of discs
        ; R4 = block number in list
        ; R5 -> list of blocks
        ; R6 = block number to find

        LDR     R3, pointerToBufferList
        MOV     R6, R1

01

        LDMIA   R3!, { R1, R2, R4, R9 } ; R1 = disc number; R2 = pointer to disc buffer
                                        ; R4 = block, R9 = flags)
        TEQ     R2, #0                  ; Not found
        Pull    "R0 - R9, PC", EQ       

        TEQ     R1, R0                  ; Not right disc
        TEQEQ   R4, R6                  ; Not right block
        BNE     %BT01

        ; R1 = disc number, R2 = pointer to buffer, R3 = place found at + 12

        LDRB    R4, numberofbuffersused ; numberofbuffers - = 1
        SUB     R4, R4, #1              ;
        STRB    R4, numberofbuffersused ;
        
        SUB     R4, R3, #SIZEOFBUFFERENTRY

02                                      ; Shuffle list over top of deleted entry
        LDMIA R3!, { R0, R1, R6, R9 }   ; R0 = unique, R1 = pointer to disc
        STMIA R4!, { R0, R1, R6, R9 }   ; R6 = block
        TEQ   R1, #0
        BNE   %BT02

                                        ; R2 -> disc buffer

; REPEAT
;
; Find next disc buffer in memory
; If there is one THEN {
;                      Copy from that one up to the deleted one
;                      Alter pointer in list for new position ( and number )
;                      }
; UNTIL no disc buffer below

; Adjust pointer to bottom of used disc buffer



;REPEAT_scrub_little_buffer

; R0 = disc buffer from list
; R1 -> current pos. in list
; R2 -> disc buffer to delete                         Delete this buffer
; R3 = next disc buffer ( in ascending memory order ) Move this up
; R4 -> R5 ( = place R5 was from in list )
; R5 = unique disc number of buffer to delete

        MOV     R6, R2                  ; R6 -> buffer to delete

move_more

        LDR     R3, disclastpointer
                
        LDR     R1, pointerToBufferList
        ADD     R1, R1, #POINTER
                
        MOV     R8, #0
        MOV     R5, #0
        MOV     R4, #0

03                                      ; Make R3 = next buffer after R2

        LDR     R0, [ R1 ], #SIZEOFBUFFERENTRY                           
                                                                         
        TEQ     R0, #0                                                   
        BEQ     wish_you_were_here                                       
                                                                         
        CMP     R0, R3                                                   
        BGE     %BT03                                                    
        CMP     R0, R2                                                   
        BLE     %BT03                                                    
                                                                         
        MOV     R3, R0                                                   
        LDR     R5, [ R1, #DISC - POINTER - SIZEOFBUFFERENTRY ]          ; R5 = disc
        LDR     R8, [ R1, #BLOCK - POINTER - SIZEOFBUFFERENTRY ]         ; R8 = block
        LDR     R9, [ R1, #BUFFERFLAGS - POINTER - SIZEOFBUFFERENTRY ]   ; R9 = flags
        SUB     R4, R1, #POINTER + SIZEOFBUFFERENTRY                     ; R4 -> next buf

        B       %BT03

wish_you_were_here

        TEQ     R5, #0
        STREQ   R6, disclastpointer     ; move bottom of disc pointer up
                                        
        Pull    "R0 - R9, PC",EQ        ;
        
        LDR     R7, disclastpointer
                
        LDR     R1, pointerToBufferList
        ADD     R1, R1, #POINTER

04                                      ; Make R7 -> buffer after R3

        LDR     R0, [ R1 ], #SIZEOFBUFFERENTRY
                
        CMP     R0, #0
        BEQ     deal_with_next_buffer
                
        CMP     R0, R7
        BGE     %BT04
                
        CMP     R0, R3
        BLE     %BT04
                
        MOV     R7, R0
        B       %BT04

deal_with_next_buffer

        STMIA   R4, { R5, R6, R8, R9 }

        ; R2 -> buffer to write over ( delete )
        ; R3 -> next buffer after R2
        ; R4 -> position in list of R3
        ; R6 -> position to copy to
        ; R7 -> next buffer after R3
        
        ; Copy from R3 to ( ( R3 - R2 ) + discbufferpointer ), length ( R7 - R3 )

        Push    "R0, R2 - R4"
        
        MOV     R0, R3                  
        MOV     R1, R6                  
        SUB     R2, R7, R3
        ADD     R6, R6, R2              ; R6 = R6 + size of buffer
        
        Push    "R1"
        
        MOV     R3, R2
        MOV     R2, R1
        MOV     R1, R0
        CD_ByteCopy                     ; R1 -> From, R2 -> to, R3 = length
        
        Pull    "R1"
        
        Pull    "R0, R2 - R4"
        
        MOV     R2, R3
        
        B       move_more               ; R3 -> next buffer

        ; no_more_buffers


;***************************************************************************
FindDiscInBufferList ROUT; R0 = disc number, R2 = block
                         ; Iff R2 = PVD then the volume descriptor for this disc is returned
                         ;          even though it might actually be the SVD
                         ; RETURNS R1 -> buffer
                         ;         C=1 if not found, else C=0

; THIS AUTOMATICALLY CHECKS TO MAKE SURE THAT THE BUFFER WAS SAVED WITH
; THE CURRENT TRUNCATION METHOD !
;***************************************************************************

        Push    "R0, R2 - R7, R14"

        ; R0 = disc from list
        ; R1 -> buffer
        ; R2 = block to look for
        ; R3 = disc
        ; R4 -> list of discs in buffers
        ; R5 -> list of blocks from which directories came
        ; R6 = block from list

        LDRB    R7, truncation
        LDR     R4, pointerToBufferList
        MOV     R3, R0

01
        ASSERT  POINTER = DISC + 4
        ASSERT  BLOCK = POINTER + 4
        ASSERT  BUFFERFLAGS = BLOCK + 4
        LDMIA   R4!, { R0, R1, R5, R6 } ; R0 = disc number, R1 -> buffer, R5 = block
                                        ; R6 = flags
        
        SUBS    R1, R1, #0              ; Last entry in list ?
        Pull    "R0, R2 - R7, PC", EQ   ; [ yes ] - Carry set by test
        
        TEQ     R3, R0                  ; Disc in list = Disc wanted ?
        ASSERT  TRUNCATION = BUFFERFLAGS + 0
        ANDEQ   R14, R6, #255
        TEQEQ   R14, R7                 ; Right truncation method ?
        BNE     %BT01                   ; [ no ]

        TEQ     R2, #PVD                ; Special check for PVD or SVD ?
        ASSERT  ISVOLDESC = BUFFERFLAGS + 1
        ANDEQ   R14, R6, #255:SHL:8
        TEQEQ   R14, #PVD:SHL:8         ; Is this the PVD or SVD ?

        TEQNE   R2, R5                  ; Right directory ?
        BNE     %BT01                   ; [ no ]
        
        CMN     R0, #0                  ; CLC
        Pull    "R0, R2 - R7, PC"       ; Found it

;***************************************************************************

PreGetUniqueNumber                      ; Sets up for GetUniqueNumber

        MOV     R2, #0

;***************************************************************************
GetUniqueNumber ROUT         ; R0 = drive number, 
                             ; R2 =0 to error, R2=1 return R1=0
; RETURNS R1 = unique number and r2 = 0 if disc not changed, else = 1 if changed
;***************************************************************************

        Push    "R0, R3 - R8, R14"

        MOV     R6, R0                  ; R6 := drive number

;******************
; Make a control block from the drive number
;******************

        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> block
        BVS     ErrorExit

;******************
; Has the disc changed since last time I was called ?
;******************

        SWI     XCD_DiscChanged
        BVS     please_give_disc        ; If error THEN handle it
                
        CMP     R0, #0                  ; disc has changed if = 1


;******************
; Disc has not changed, so use remembered number
;******************

        ADREQL  R7, ListOfDiscsInDrives
        LDREQ   R1, [ R7, R6, LSL #2 ]  ; R1 = unique disc number
        MOVEQ   r2, #0                  ; Disc not changed

        Pull    "R0, R3 - R8, PC", EQ

;******************
; Find the size of the disc using the control block
;******************

        ADRL    R1, buffer
        MOV     R0, #LBAFormat
        SWI     XCD_DiscUsed
        BVS     please_give_disc        ; If error THEN handle it

        LDR     R8, [ R1 ]              ; R8 = size of disc ( in blocks )

;******************
; Load PVD from the drive
;******************

        MOV     R0, #LBAFormat
        MOV     R1, #PVD                ; Only used for CRC, PVD always exists unlike an SVD
        MOV     R2, #1
        ADRL    R3, buffer
        MOV     R4, #myblocksize
        SWI     XCD_ReadData

;******************
; If everything is well, then CRC data ELSE CRC check = 0
;******************


        MOV     R0, #0                  ; Perform cyclic redundancy check on
        MOVVC   R1, R3                  ; the first 60 bytes in the PVD
        ADDVC   R2, R1, #60             ;
        MOVVC   R3, #1                  ;

        SWIVC   XOS_CRC                 ; RETURNS R0 = CRC value

;******************
; Exclusive OR the redundancy check with the size of the disc
;******************

        EOR     R1, R0, R8              ; R1 = disc number
                                        ; R6 = drive number
        ADRL    R4, ListOfDiscsInDrives
        STR     R1, [ R4, R6, LSL #2 ]

        MOV     r2, #1                  ; Disc changed

        CLRV
        Pull    "R0, R3 - R8, PC"

;******************
; Test the error ( if drive empty THEN caller may want to know )
;******************

please_give_disc

        LDR     R14, [ R0 ]
                
        LDR     R1, =CDFSDRIVERERROR__NO_CADDY ; is the error no disc ?
        TEQ     R1, R14                 ;
        TEQNE   R2, #1                  ; was R2 specified anyway ?
        BNE     ErrorExit               ; [ no ]

        MOV     R1, #0                  ; indicate that an error occurred (no disc)

        MOV     r2, #1                  ; Disc changed

        CLRV
        Pull    "R0, R3 - R8, PC"

;***************************************************************************

PreConvertDriveNumberToDeviceID  ; This sets R7->controlblock

        ADR     R7, sparecontrolblock   ; IMPORTANT r7 right on exit

;***************************************************************************
ConvertDriveNumberToDeviceID ROUT; R0 = drive number, R7 -> controlblock
;***************************************************************************

        Push    "R1 - R5, R7, R14"

        ; This should:
        ;  1. Check to make sure that many drives are attached
        ;  2. Load the corresponding drive number from the list
        ;  3. Convert the real drive number into device, LUN, card
        ;  4. Save the device, LUN, card in the block

;****************
; Add another drive ( it won't if it already knows it )
;****************

        BL      AnotherDriveHasBeenAdded ; RETURNS 'V' set if error

        Pull    "R1 - R5, R7, PC", VS

;****************
; Convert the drive to control block
;****************

        ADRL    R1, ListOfDrivesAttached
        LDRB    R4, [ R1, R0 ]          ; R4 = device id of found drive

        AND     R1, R4, #2_111          ; device
        MOV     R2, R4, LSR #3          ;
        AND     R2, R2, #2_11           ; card
        MOV     R3, R4, LSR #5          ;
        AND     R3, R3, #2_111          ; LUN
                
        ADRL    R5, DriveTypes          ; drive type
        LDRB    R4, [ R5, R0 ]          ;

        MOV     R5, #0                  ; RESERVED

        STMIA   R7, { R1 - R5 }

        Pull    "R1 - R5, R7, PC"       ; V still clear

;***************************************************************************
GetDiscNameFromVolDesc ROUT; ( R0 = disc type, R1 -> disc name$, 'buffer' pre loaded with vol desc )
;***************************************************************************

        Push    "R0 - R7, R14"

        MOV     R7, R1                  ; R7 -> place to put disc name
        MOV     R5, R1

        ASSERT  CdiVolDescVolumeId = IsoVolDescVolumeId
        TST     R0, #DISCTYPE_HISIERRA
        ADRNEL  R1, buffer + :INDEX:HiSierraVolDescVolumeId
        ADREQL  R1, buffer + :INDEX:IsoVolDescVolumeId
        TST     R0, #DISCTYPE_JOLIET
        MOVNE   R2, #?IsoVolDescVolumeId
        BLNE    CrunchUCS2String        ; r0 = disc type; r1 -> string; r2 = buffer size
        B       matched
        
;***************************************************************************
GetDiscName ROUT; ( R0 = drive, R1 -> disc name$, R2 -> disc buffer )
;***************************************************************************

        Push    "R0 - R4, R14"

        LDR     R4, discbuffersize      ; If no disc buffers used, THEN get name
        TEQ     R4, #0                  ;

        ; --- Already know about this ---

        MOVNE   R3, R1
        ADDNE   R1, R2, #DiscBuff_DiscName         ; Copy from
        MOVNE   R2, R3                             ; Copy to
        MOVNE   R3, #MAXLENGTHOFDISCNAME - 2       ; Copy length
                                                   ; Read disc name into area
        CD_ByteCopy NE

        TEQ     R4, #0

        Pull    "R0 - R4, PC", NE

        ; ******* Load name from drive if no buffer *******

        MOV     R3, R0
        MOV     R0, #PVD                ; Start with PVD, might end up with SVD
        MOV     R2, #1

        BL      PreLoadBlockFromDrive   ; R0 = block, R1 = memory, R2 = no. blocks
                                        ; R3 = drive

        Pull    "R0 - R4, R14"   ; Allow to roll on

;***************************************************************************
GetDiscNameNotInBuffer ROUT    ; R0 = drive, R1 -> name of disc in drive
                               ; This expects the PVD to be already loaded into 'buffer'
;***************************************************************************

        Push    "R0 - R7, R14"
                
        MOV     R7, R1                  ; R7 -> place to put disc name
        MOV     R5, R1
        MOV     R3, R0

;*****************************  ; Find disc type ( ISO / HISIERRA / CD-I )

        addr    R0, CDROM
        ADRL    R1, buffer + :INDEX:HiSierraVolDescId
        MOV     R2, #?CDROM
        BL      CompareStrings          ; returns 'eq' or 'ne'
        ADDEQ   R1, R1, #HiSierraVolDescVolumeId - HiSierraVolDescId
        BEQ     matched

        addr    R0, CD001
        ADRL    R1, buffer + :INDEX:IsoVolDescId
        ASSERT  ?CDROM = ?CD001
        BL      CompareStrings          ; returns 'eq' or 'ne'
        BNE     %FT10

        ADRL    R0, buffer
        MOV     R1, R3
        BL      TryLoadingSVD           ; r0 -> PVD buffer; r1 = drive
        AND     R0, R0, #255
        TEQ     R0, #DISCTYPE_ISO
        ADRL    R1, buffer + :INDEX:IsoVolDescVolumeId
        MOVNE   R2, #?IsoVolDescVolumeId
        BLNE    CrunchUCS2String        ; r0 = disc type; r1 -> string; r2 = buffer size
        B       matched
10
        addr    r0, CDIString
        ASSERT  CdiVolDescId = IsoVolDescId
        MOV     r2, #?CDIString
        BL      CompareStrings          ; returns 'EQ' or 'NE'
        ADDEQ   R1, R1, #CdiVolDescVolumeId - CdiVolDescId

        MOVNE   r0, #ERROR_NOTISO
        BNE     ErrorExit

matched                                 
        ; R1 -> disc name
        ; R2 -> end of disc name buffer (exclusive)
        ; R4 -> last position seen that was not a 0 or a space
        ADD     R2, R1, #MAXLENGTHOFDISCNAME
        MOV     R4, R5

        MOV     R14, R5

        ; If disc name starts with a number, panic, and change it to 'Q'.
        ; Why Q??? Also, FileSwitch allows names beginning with numbers, provided they're
        ; unambiguous with drive numbers (2 or more digits, or followed by non digits)
        LDRB    R3, [ R1 ]
        CMP     R3, #"0"                ; Character was a digit
        RSBGES  R3, R3, #"9"
        MOVGE   R3, #"Q"
        STRGEB  R3, [ R14 ], #1
        ADDGE   R1, R1, #1

01
        LDRB    R3, [ R1 ], #1          ; copy name to caller
        STRB    R3, [ R14 ], #1         ;
        TEQ     R3, #SPACE
        TEQNE   R3, #0                  ; The SUN CD is dodgy - name = 0's !!!
        MOVNE   R4, R14

        TEQ     R1, R2                  ; Reached the end?
        BNE     %BT01                   

;****************
; null terminate entry
;****************

        MOV     R3, #0
        STRB    R3, [ R14 ]

;****************
; Give disc with no name a name
;****************

        ; R5 -> place to put disc name

        TEQ     R4, R5
        
        MOVEQ   R2, R5
        addr    R1, NameForNoName, EQ
        MOVEQ   R3, #NameForNoNameEnd - NameForNoName
        CD_ByteCopy EQ          ; R1 -> from, R2 -> to, R3 = length ( + null )

        TEQ     R4, R5
        Pull    "R0 - R7, PC", EQ

;****************
; A disc name can contain spaces ! ( see SUN OS 4.1 )
; Convert to uppercase ( SUN OS 4.1 seems to break the ISO spec ! )
;****************

; R7 -> start of disc name
; R4 -> last character in disc name
; R5 = scrap
; R14 = scrap

02

        LDRB    R14, [ R4, #-1 ]!
        TEQ     R14, #SPACE
      [ AllowHardSpaceInDiscName
        MOVEQ   r14, #&A0
      ]
        TEQNE   r14, # "."
    [ CDFix
      [ :LNOT: AllowCommaInDiscName
        TEQNE   r14, # ","
      ]
      [ :LNOT: AllowHyphenInDiscName
        TEQNE   r14, # "-"
      ]
        TEQNE   r14, #WILDCHAR
        TEQNE   r14, #WILDANY
        TEQNE   r14, #SYSTEMURD
        TEQNE   r14, #SYSTEMROOT
        TEQNE   r14, #SYSTEMCSD
        TEQNE   r14, #SYSTEMLIB
        TEQNE   r14, #SYSTEMCOLON
        TEQNE   r14, #SYSTEMQUOTE
        TEQNE   r14, #SYSTEMLT
        TEQNE   r14, #SYSTEMGT
        TEQNE   r14, #SYSTEMDEL
        TEQNE   r14, #SYSTEMPARENT
      [ :LNOT: AllowSlashInDiscName
        TEQNE   r14, # "/"
      ]
    ]
        MOVEQ   R14, #REPLACEMENTFORSYSTEM
        
        STRB    R14, [ R4 ]
        
        CMP     R4, R7
        BGT     %BT02

        DebugS  mi,"GetDiscName",R7
        
        Pull    "R0 - R7, PC"

;***************************************************************************
TryLoadingSVD ROUT; R0 -> preloaded PVD buffer, R1 = drive
                  ; Returning R0 = b0-7 disc type, b8-15 block number of SVD
;***************************************************************************
        Push    "r1-r3, lr"
        ; The buffer already contains the PVD. If it turns out there is no
        ; SVD then we want to restore the PVD without having to reread it, so copy
        ; the bulk of it out of the way. Only copy the bits before the application data
        ; area as there's < 1k of interesting bits and bobs in the PVD anyway.
        SUB     sp, sp, #1024
        MOV     r2, #1024
10
        SUBS    r2, r2, #4
        LDRPL   r14, [r0, r2]
        STRPL   r14, [sp, r2]
        BPL     %BT10

        MOV     r3, r1
        MOV     r2, #1
        MOV     r1, r0
        MOV     r0, #PVD
20
        ; Loop loading each volume descriptor until the last (or silly number)
        ADD     r0, r0, #1
        BL      LoadBlockFromDrive      ; R0 = block, R1 = memory, R2 = no. blocks
                                        ; R3 = drive
        LDRB    r14, [r1, #IsoVolDescType]
        TEQ     r14, #IsoVolDescType_Supplementary
        BEQ     %FT40

        TEQ     r14, #IsoVolDescType_Terminator
        BEQ     %FT30

        MOVS    r14, r0, LSR #8
        BEQ     %BT20
30
        ; No SVD found, restore the PVD and admit defeat
        MOV     r2, #1024
35
        SUBS    r2, r2, #4
        LDRPL   r14, [sp, r2]
        STRPL   r14, [r1, r2]
        BPL     %BT35
        MOV     r14, #DISCTYPE_ISO
        MOV     r0, #PVD
        B       %FT50
40
        ; Check this supplementary has an ISO9660 id
        Push    "r0-r2"
        addr    r0, CD001
        ADD     r1, r1, #IsoVolDescId
        MOV     r2, #?CD001
        BL      CompareStrings          ; returns 'EQ' or 'NE'
        Pull    "r0-r2"
        BNE     %BT20

        ; Check version 1
        LDRB    r14, [r1, #IsoVolDescVersion]
        TEQ     r14, #1
        BNE     %BT20

        ; Check for a recognised ISO2375 escape sequence
        LDRB    r14, [r1, #IsoVolDescFlags]
        TST     r14, #IsoVolDescFlags_EscSeqNotISO2375
        LDREQB  r14, [r1, #IsoVolDescEscapeSequences + 0]
        TEQEQ   r14, #'%'
        LDREQB  r14, [r1, #IsoVolDescEscapeSequences + 1]
        TEQEQ   r14, #'/'
        BNE     %BT20

        LDRB    r14, [r1, #IsoVolDescEscapeSequences + 2]
        TEQ     r14, #'@'
        MOVEQ   r14, #DISCTYPE_JOLIET1
        BEQ     %FT50
        TEQ     r14, #'C'
        MOVEQ   r14, #DISCTYPE_JOLIET2
        BEQ     %FT50
        TEQ     r14, #'E'
        MOVEQ   r14, #DISCTYPE_JOLIET3
        BNE     %BT20
50
        ; Balance stack and return type and block number
        Debug   jo, "Disc type from PVD/SVD is", R14
        Debug   jo, "Vol desc at block", R0
        ORR     r0, r14, r0, LSL #8
        ADD     sp, sp, #1024
        Pull    "r1-r3, pc"

;***************************************************************************
CrunchUCS2String ROUT; R0 = disc type, R1 -> string to transform in situ, R2 = length
;***************************************************************************
        Push    "r0, r2, lr"
        BICS    r2, r2, #1
        Pull    "r0, r2, pc", EQ
        MOV     r0, #1                  ; Please don't hate me for ignoring the UCS level
10
        LDRB    r14, [r1, r0]
        STRB    r14, [r1, r0, LSR #1]
        SUBS    r2, r2, #2
        ADDNE   r0, r0, #2
        BNE     %BT10

        ; Fill from the end of buffer back to half way with nulls
        MOV     r14, #0
        MOV     r2, r0, LSR #1
20
        STRB    r14, [r1, r0]
        SUB     r0, r0, #1
        TEQ     r0, r2
        BNE     %BT20
        
        Pull    "r0, r2, pc"

;***************************************************************************
ChangeDiscMode ROUT; R0 = mode, R7 -> control block
; uses 'buffer'
;***************************************************************************

        Push    "R0 - R5, R14"
        
        MOV     r3, r0
        ADRL    R0, buffer
        SWI     XCD_GetParameters
        BVS     ErrorExit
        
        ; Only change disc mode if not currently correct
        LDR     r14, [ r0, # 8 ]
        TEQ     r14, r3
        Pull    "r0 - r5, pc", EQ
        
        STR     r3, [ r0, #8 ]
        SWI     XCD_SetParameters
        
        BVS     ErrorExit
        
        Pull    "R0 - R5, PC"

;***************************************************************************
      [ bufferlist
DisplayBuffers ROUT  ; Displays buffer pointers, disc names etc;
;***************************************************************************

        Push    "R0 - R6, R14"
        
        ; R1 -> disc entry in list ( at buffer pointer )
        ; R2 -> disc buffer

        LDR     R1, pointerToBufferList
        TEQ     R1, #0
        Pull    "R0 - R6, PC", EQ

01
        LDMIA   R1!, { R2, R3, R4, R6 }; R2 = disc, R3 = pointer, R4 = block,R6=offset
        TEQ     R3, #0
        
        Pull    "R0 - R6, PC", EQ


        SWI     XOS_WriteS
        DCB     " block number = ", 0
        ALIGN
        Display R4

        TEQ     R4, #PVD
        BNE     no_name

        SWI     XOS_WriteS
        DCB     " Disc name = ",0
        ALIGN

        ADD     R0, R3, #DiscBuff_DiscName
        SWI     XOS_Write0

no_name

        SWI     XOS_WriteS
        DCB     " Disc number = &",0
        ALIGN
        MOV     R5, R2
        Display R5
        
        SWI     XOS_WriteS
        DCB     "  buffer pointer = ",0
        ALIGN

        MOV     R5, R3
        Display R5
        
        SWI     XOS_NewLine
        
        LDR     R5, disclastpointer
        SWI     XOS_WriteS
        DCB     " Last pointer = &",0
        ALIGN
        Display R5
        
        LDRB    R5, numberofbuffersused
        SWI     XOS_WriteS
        DCB     " Number of buffers = &",0
        ALIGN
        Display R5
        
        SWI     XOS_NewLine
        
        SWI     XOS_WriteS
        DCB     " Blocky offset = ",0
        ALIGN
        Display R6
        
        SWI     XOS_NewLine
        B       %BT01

letters = "0123456789abcdef"
      ]

;***************************************************************************
AddDirectoryToBuffer ROUT ; R0 = disc, R1 = size, R2 = block, R3->directory
;***************************************************************************

        Push    "R0 - R6, R14"

        ; Is there enough space to keep the buffer ?

        LDR     R5, disclastpointer
        LDR     R14, discbufferpointer
        SUB     R5, R5, R14
        LDR     R14, discbuffersize
                
        CMP     R14, #0                 ; No buffer space configured
        Pull    "R0 - R6, PC", EQ       ; exit, V clear

        SUB     R5, R14, R5
        ADD     R5, R5, #50
                
        CMP     R5, R1                  ; Not enough space left, so try deleting an
        BLLT    %FT01                   ; old buffer ( NOT A MAIN DIRECTORY ! )

;****************
; There might be enough space, but are there enough pointers ?
;****************

        LDRB    R5, numberofbuffersused
        LDR     R14, maxnumberofbuffers
        CMP     R5, R14
        BLGE    %FT01

;****************
; Claim some space

        Push    "r0, r2"

        MOV     r2, r0
        MOV     R0, R1
        BL      ClaimMemoryForBuffer    ; R0 = size, r2 = disc number, RETURNS R1 -> buffer

        MOV     R4, R0
        
        Pull    "r0, r2"

        ; Add the buffer to the list

        MOV     R3, #0
        BL      AddDiscToBufferList     ; R0 = disc, R1 -> buffer, R2 = LBA, R3 = vol desc flag
        LDR     R3, [SP, #3*4]

        ; Copy from R3 to the claimed buffer
        
        MOV     R2, R1
        MOV     R1, R3
        MOV     R3, R4
        CD_ByteCopy                     ; R1 -> from, R2 -> to, R3 = length

        CLRV
        Pull    "R0 - R6, PC"

;************************
; This part aims to remove an old buffer that does not hold a main directory
;************************

01

        Push    "R0 - R4, R14"

        LDR     R4, pointerToBufferList
        ADD     R4, R4, #BLOCK

02

        LDR     R1, [ R4 ], #SIZEOFBUFFERENTRY
        LDR     r2, [ R4, #DISC-SIZEOFBUFFERENTRY-BLOCK ]
        LDRB    r3, [ R4, #ISVOLDESC-SIZEOFBUFFERENTRY-BLOCK ]

        CMP     R1, #0                  ; reached end of list with no success
        Pull    "R0 - R4, R14", EQ      ;
        Pull    "R0 - R6, PC", EQ       ; exit, V clear

        TEQ     R3, #PVD                ; don't delete the disc's main directory
        TEQEQ   r0, r2
        BEQ     %BT02

        LDR     R0, [ R4, #DISC-SIZEOFBUFFERENTRY-BLOCK ]

        BL      DeleteBuffer            ; R0 = disc, R1 = block

        Pull    "R0 - R4, R14"

        LDR     R5, disclastpointer
        LDR     R6, discbufferpointer
        SUB     R5, R5, R6              ; R5 = amount used so far
        LDR     R6, discbuffersize
        SUB     R5, R6, R5
        CMP     R5, R1

        Pull    "R0 - R6, PC", LT       ; Still not enough memory, exit with V clear

        MOV     PC, R14

;***************************************************************************

        LTORG

        END
