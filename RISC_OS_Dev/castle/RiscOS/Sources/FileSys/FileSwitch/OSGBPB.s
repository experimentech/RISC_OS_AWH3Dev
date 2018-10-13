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
        SUBT    > Sources.OSGBPB - Multi-byte data transfer

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; +                                                                           +
; +                     M U L T I P L E    S W I                              +
; +                                                                           +
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MultipleEntry. Vectored SWI level entry
; =============
;
; The dreaded heebeegeebee !

; In    r0b = Reason code
;       r1b = FileSwitch handle (if non-silly op)
;       r2  = memory address of data
;       r3  = number of bytes/names to transfer
;       r4  = file data pointer (if applicable)
;       r5  = buffer length (if applicable)
;       r6  = wildcard specifier

; Reason codes:
; =============

; Sensible data xfer ones
;       1: Write bytes from memory to file, using r4 = file data ptr
;       2: Write bytes from memory to file, using file sequential ptr
;       3: Read bytes to memory from file,  using r4 = file data ptr
;       4: Read bytes to memory from file,  using file sequential ptr

; Not-so-sensible ones
;       5: Read disc title
;       6: Read CSD name
;       7: Read LIB name
;       8: Read filenames from CSD

; New ones on Arthur
;       9: Read filenames from given directory
;      10: Read filenames and info from given directory
;      11: Read filenames, info, SIN and Date from given directory

; New ones on Risc OS 3.00
;      12: Read filenames, info and generate filetype from given directory

; Out   VC -> ok
;             r0, r1 preserved
;             r2 -> past last byte of memory used
;             r3 = number of bytes not transferred
;                CC if transfer complete, r3 = 0
;                CS if transfer could not be completed, r3 <> 0
;             r4 -> next position in file / directory
;             r5 = amount of buffer used
;       VS -> fail. If stream op, get handle with error too !

; NB. No EOF errors on OSGBPB

memadr  RN      r2
nbytes  RN      r3

MultipleEntry NewSwiEntry "r0-r1"

 [ debugosgbpbentry
 DREG  r0, "OSGBPB: rc ",cc
 TEQ   r0, #OSGBPB_ReadDiscName
 TEQNE r0, #OSGBPB_ReadCSDName
 TEQNE r0, #OSGBPB_ReadLIBName
 BEQ %FT00
 DREG r1, " ",cc
00
 DREG memadr, " ",cc
 DREG nbytes, " ",cc
 DREG fileptr, " ",cc
 TEQ r0, #OSGBPB_ReadDirEntries
 TEQNE r0, #OSGBPB_ReadDirEntriesInfo
 BNE %FT01
 DREG r5, " ",cc
 DSTRING r1, ", directory ",cc
 DSTRING r6, ", wildspec ",cc
01
 DLINE
 ]

10 ; Reentry point for below

        ADR     r14, gbpb_memadr        ; Save parms
        STMIA   r14, {memadr, nbytes, fileptr}

        ADR     lr, %FT50               ; Form a return address for routines
        CMP     r0, #OSGBPB_Max         ; NB. This has no psr bits in it!!!
        JTAB    r0, LO, OSGBPB          ; Good rc if LO
        B       %FA99
                                        ; Check reason codes against &.Hdr.File

        JTE     %FA99 ; Awkward - not defined at that macro level !

        JTE     Xfer_WriteBytes,        OSGBPB_WriteAtGiven
        JTE     Xfer_WriteBytes,        OSGBPB_WriteAtPTR
        JTE     Xfer_ReadBytes,         OSGBPB_ReadFromGiven
        JTE     Xfer_ReadBytes,         OSGBPB_ReadFromPTR

        JTE     Daft_ReadDiscName,      OSGBPB_ReadDiscName
        JTE     Daft_ReadName,          OSGBPB_ReadCSDName
        JTE     Daft_ReadName,          OSGBPB_ReadLIBName
        JTE     Daft_ReadCSDEntries,    OSGBPB_ReadCSDEntries
        JTE     Daft_ReadDirEntries,    OSGBPB_ReadDirEntries
        JTE     Daft_ReadDirEntries,    OSGBPB_ReadDirEntriesInfo
        JTE     Daft_ReadDirEntries,    OSGBPB_ReadDirEntriesCatInfo
        JTE     Daft_ReadDirEntries,    OSGBPB_ReadDirEntriesFileType

OSGBPB_Max * (.-$JumpTableName) :SHR: 2

; Routines need not preserve r0-r4 - these are always updated from parm block
; or preserved anyway

50      ADR     r14, gbpb_memadr        ; Update punter's registers
        LDMIA   r14, {memadr, nbytes, fileptr}

        CMP     nbytes, #1              ; If nbytes >= 1 then failed full xfer
                                        ; (xfer_bytes and Daft_ReadName/CSD)
 [ debugosgbpb
 BVS %FT80
 DREG memadr, "OSGBPB returns memadr ",cc
 DREG nbytes, " nbytes ",cc
 BCC %FT00
 DLINE " C",cc
00
 DREG fileptr, " fileptr ",cc
 LDR r0, [sp]
 TEQ r0, #OSGBPB_ReadDirEntries
 TEQNE r0, #OSGBPB_ReadDirEntriesInfo
 BNE %FT79
 DREG r5, " r5 ",cc
79
 DLINE
80
 ]
95
        LDR     r14, globalerror        ; Load this before destroying frame
9999    PullSwiEnv                      ; Destack all apart from lr
        B       FileSwitchExitSettingC  ; Set/Clear C for all GBPB ops now


99      CMP     r0, #&FF                ; Silly bits set ?
        ANDHI   r0, r0, #&FF            ; r0b is reason code
        BHI     %BT10                   ; Reenter

        addr    r0, ErrorBlock_BadOSGBPBReason
        BL      CopyError
        B       %BT95

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Top level now sets/clears C flag on nbytes

; In    r0  = reason. Rest of data in gbpb_block
;       r1b = file handle

; Out   r1 trashed

Xfer_ReadBytes Entry "scb, $streaminfo"

        AND     r1, r1, #&FF            ; r1b is file handle
        ADR     r14, streamtable
        LDR     scb, [r14, r1, LSL #2]  ; Get scb^

        ReadStreamInfo

10 ; Reentry point for below

        EOR     r14, status, #scb_read  ; Must be set
        TST     r14, #scb_read :OR: scb_directory :OR: scb_EOF_pending :OR: scb_unallocated
        TSTEQ   r14, #scb_critical
        BNE     %FT40                   ; [strange bits set/clear]
                                        ; >>>a186<<< was wrong label

        TST     status, #scb_unbuffered
        BNE     %FT30                   ; >>>a186<<< was wrong label

        BL      BufferedMultipleRead

 [ appendhandle
49      BLVS    AppendHandleToError     ; For all errors in ReadMultiple
 ]
        EXIT


30      BL      UnbufferedMultiple
 [ appendhandle
        B       %BT49                   ; Catch errors on way out (code space)
 |
        EXIT
 ]


40 ; Complicated ReadBytes - flags set

        TST     status, #scb_unallocated        ; Not a stream ?
        BNE     %FT92

        TST     status, #scb_critical           ; Return - done nothing to file
        EXIT    NE

        TST     status, #scb_EOF_pending        ; Always clear this on read
        BICNE   status, status, #scb_EOF_pending ; (unlike BGet)
        STRNE   status, scb_status
        BNE     %BT10                           ; Reenter

        TST     status, #scb_directory          ; Can't read from a directory
        BNE     %FT94

        BL      SetErrorNotOpenForReading       ; Must have no read access
 [ appendhandle
        B       %BT49
 |
        EXIT
 ]

; .............................................................................
; Top level now sets/clears C flag on nbytes

; In    r0  = reason. Rest of data in gbpb_block
;       r1b = handle

; Out   r1 trashed

Xfer_WriteBytes ALTENTRY

        AND     r1, r1, #&FF            ; r1b is file handle
        ADR     r14, streamtable
        LDR     scb, [r14, r1, LSL #2]  ; Get scb^

        ReadStreamInfo

60 ; Reentry point for below

        EOR     r14, status, #scb_write + scb_modified ; Must be/should be set
        TST     r14, #scb_write :OR: scb_directory :OR: scb_EOF_pending :OR: scb_modified :OR: scb_unallocated
        TSTEQ   r14, #scb_critical
        BNE     %FT90                   ; [strange bits set/clear]

        TST     status, #scb_unbuffered
        BNE     %FT80                   ; >>>a186<< changed label to clarify

        BL      BufferedMultipleWrite

 [ appendhandle
99      BLVS    AppendHandleToError     ; For all errors in WriteMultiple
 ]
        EXIT


80      BL      UnbufferedMultiple
 [ appendhandle
        B       %BT99                   ; Catch errors on way out (code space)
 |
        EXIT
 ]


90 ; Complicated WriteBytes - flags set

        TST     status, #scb_unallocated        ; Not a stream ?
        BNE     %FT92

        TST     status, #scb_critical           ; Return - done nothing to file
        EXIT    NE

        TST     status, #scb_EOF_pending        ; Always clear this on write
        BICNE   status, status, #scb_EOF_pending
        STRNE   status, scb_status
        BNE     %BT60                           ; Reenter

        TST     status, #scb_modified           ; Always modify stream
        ORREQ   status, status, #scb_modified
        STREQ   status, scb_status
        BEQ     %BT60                           ; Reenter

        TST     status, #scb_directory          ; Can't read from a directory
        BNE     %FT94

        BL      SetErrorNotOpenForUpdate        ; Must have no write access
 [ appendhandle
        B       %BT99
 |
        EXIT
 ]


92      BL      SetErrorChannel
 [ appendhandle
        B       %BT99
 |
        EXIT
 ]

94      BL      SetErrorStreamIsDirectory
 [ appendhandle
        B       %BT99
 |
        EXIT
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; UnbufferedMultiple
; ==================
;
; Do file gbpb on an unbuffered stream, eg. vdu:

; In    r0 = reason, scb^ valid. Rest of data in gbpb_block

UnbufferedMultiple Entry "r5-r7" ; We can use r0-r4 here (restored by toplevel)

        TST     status, #scb_unbuffgbpb ; Can FS do this quickly ?
        BEQ     %FT01                   ; Nope !

 [ debugosgbpb
 DLINE "Doing fast unbuffered GBPB"
 ]
        BL      CallFSMultiple          ; Gets/updates block itself
        EXIT


01      MOV     r7, r0                  ; Remember GBPB op

        TEQ     r0, #OSGBPB_ReadFromGiven ; Need to reset PTR# before op ?
        TEQNE   r0, #OSGBPB_WriteAtGiven
        BNE     %FT05

        MOV     r0, #fsargs_SetPTR      ; Set PTR# unbuffered first
        LDR     r2, gbpb_fileptr
        BL      CallFSArgs
        EXIT    VS


05      ADR     r14, gbpb_memadr        ; memadr -> memory for transfer
        LDMIA   r14, {memadr, nbytes}   ; nbytes = number of bytes to transfer
        ADD     r5, memadr, nbytes      ; Calculate end address

        TEQ     r7, #OSGBPB_ReadFromGiven ; Read op [3..4] ?
        TEQNE   r7, #OSGBPB_ReadFromPTR
        BEQ     %FT65

; else drop into ... Writing to unbuffered file at seqptr

25      CMP     memadr, r5              ; Reached end address ?
        BEQ     %FT70                   ; Use common exit if so
        LDRB    r0, [memadr], #1        ; Get byte from memory++
        BL      CallFSBPut
        BVC     %BT25
        EXIT


; Reading from unbuffered file at seqptr

65      CMP     memadr, r5              ; Reached end address ?
        BEQ     %FT70                   ; Use common exit if so
        BL      CallFSBGet
        EXIT    VS
        STRCCB  r0, [memadr], #1        ; Put byte to memory++
        BCC     %BT65                   ; If CSet, byte invalid, EOF happening


; Common exit for read/write data ops

70      SUB     nbytes, r5, memadr      ; Require nbytes NOT transferred
        ADR     r14, gbpb_memadr
        STMIA   r14, {memadr, nbytes}   ; Update user's memadr, nbytes

        MOV     r0, #fsargs_ReadPTR     ; Read PTR# after operation
        BL      CallFSArgs
        STRVC   r2, gbpb_fileptr        ; Update user's file pointer
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; We can use r0-r2 as temporaries after preserving r1 (for error on way out)
; r3(status) isn't needed, so can use this
; r4(fileptr) will be updated by op
; Keep r5(extent)-r6(bufmask) ok !

        ASSERT  extent >= r5 ; Need to use r0-r3 freely here. Just status dead

; No need to invalidate caches as appropriate routines will do so

BufferedMultipleRead Entry "r1, bcb"

        TEQ     r0, #OSGBPB_ReadFromGiven ; Only difference between the two ops
        ADR     r14, gbpb_memadr
        LDMNEIA r14, {memadr, nbytes}   ; Use fileptr from stream
        LDMEQIA r14, {memadr, nbytes, fileptr}
                                        ; Correct if transfer off eof, no mods

        CMP     fileptr, extent         ; Nothing to do if startptr >= extent
 [ No26bitCode
        BLO     %FT03
        CLRV
        EXIT
03
 |
        EXITS   HS                      ; No need to update the punter either
                                        ; Assumes VClear in entry lr
 ]

        SUB     r14, memadr, fileptr    ; Calc address in core where the byte
                                        ; at offset 0 in the file would be put
        STR     r14, memadr_filebase    ; (to add to file offsets later)

; Work out what we are doing; ie. real nbytes for xfer

        SUB     r14, extent, fileptr    ; nbytes_available    := extent-startptr
        CMP     r14, nbytes             ; can I fulfill the request?
        MOVCS   r0, #0                  ; Yes nbytes_notdoing := 0
                                        ;     nbytes_doing    := nbytes
        SUBCC   r0, nbytes, r14         ; No  nbytes_notdoing := nbytes-nbytes_available
        MOVCC   nbytes, r14             ;     nbytes_doing    := nbytes_available

        ; This is done before the 0-bytes transfer check to ensure the returned
        ; file pointer is correct, for the read at pointer case
        ADD     r14, fileptr, nbytes    ; endptr  := startptr  + nbytes_doing
        STR     r14, gbpb_fileptr
        STR     r14, scb_fileptr        ; Also update stream's copy of PTR

        CMP     nbytes, #0              ; Doing anything at all ? If not, quit
        EXIT    EQ                      ; leaving punter registers unmolested
                                        ; VClear

        STR     r0, gbpb_nbytes         ; He gets number not done

; memadr  +:= nbytes_doing
; fileptr +:= nbytes_doing

        ADD     r14, memadr, nbytes     ; endaddr := startaddr + nbytes_doing
        STR     r14, gbpb_memadr

; Unfortunate side effect is that stream info remains updated even if error

; startptr = fileptr(r4), nbytes_doing = nbytes, punter's memory at memadr

 [ debugosgbpb
 DREG nbytes, "BufferedMultipleRead: nbytes_doing ",cc
 DREG fileptr, " from PTR ",cc
 DREG r14, ", endptr = "
 ]

; ********* Loop over valid partial, then whole, buffers at start *************

05      BL      FindFileBuffer          ; Valid buffer at startptr ?
        BNE     %FT10                   ; NE -> found: use that then

; If startptr isn't buffer aligned, then we'll need to get a buffer + use it

        TST     fileptr, bufmask        ; Doing aligned start ?
        BEQ     %FT20                   ; Include this buffer in middle + end

        BL      GetFileBuffer
        EXIT    VS

10 ; Valid buffer at startptr - supply as much data as possible from that

        AND     r0, fileptr, bufmask    ; Offset of start point in buffer
 [ debugosgbpb
 DREG r0, "Copying data to memory from buffer offset "
 ]
        ADR     r1, bcb_bufferdata
        ADD     r1, r1, r0              ; My address of start point
        SUB     r0, bufmask, r0         ; n_possible := bufsize - startoffset
        ADD     r0, r0, #1
        CMP     r0, nbytes              ; n_doing := min (n_possible, n_bytes)
        MOVHI   r0, nbytes
        Push    "r0, r2, r3"            ; Remember n_doing(r0) for after loop
                                        ; NB. This is never zero here !
        MOV     r3, r0
        BL      MoveBytes

        Pull    "r0, r2, r3"
        ADD     memadr, memadr, r0

        SUBS    nbytes, nbytes, r0      ; Completed whole xfer ?
        EXIT    EQ                      ; VClear

; Force aligned data transfer at next file position 0000..00FF -> 0100

        BIC     fileptr, fileptr, bufmask
        ADD     fileptr, fileptr, bufmask
        ADD     fileptr, fileptr, #1    ; File address of next whole buffer


; If multiple buffers ever arrive, we could loop back to %BT05 and try more


20 ; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Done the start bit, memadr/fileptr -> start of whole memory/sectors for xfer

; If multiple buffers, loop down from end of whole buffer section

        Push    nbytes                  ; Remember you're a womble
        BICS    nbytes, nbytes, bufmask ; How many bytes in whole xfer ?
        ADD     r0, memadr, nbytes
        ADD     r1, fileptr, nbytes     ; Where the end is (may be here !)
        Push    "r0, r1"
        BEQ     %FA35                   ; Skip if no middle

 [ debugosgbpb
 DREG nbytes, "Doing whole buffer xfers: getting "
 ]
        BLNE    CallFSGetData           ; Send it directly to the punter
        Pull    "r0, r1, nbytes", VS    ; if any requested
        EXIT    VS

 [ debugosgbpb
 DLINE "Whole buffer section complete"
 ]

; ******** Use data if there's a modified buffer in whole block range *********

        LDR     bcb, scb_bcb            ; No buffers ?
        CMP     bcb, #Nowt
        BEQ     %FA35                   ; Suss end

; Again, assumption of single buffered world here

        LDR     r14, bcb_bufferbase     ; Is buffer in whole range ?
        ADD     r0, fileptr, nbytes     ; nbytes still whole buffer multiple
        CMP     r14, fileptr            ; (bp => fp) and (fp+nb > bp)
        CMPHS   r0, r14
        BLS     %FA35                   ; Suss end. NB. kinky conditionals

        LDR     r14, bcb_status
        TST     r14, #bcb_modified
        BEQ     %FA35                   ; Suss end

        LDR     r0, bcb_bufferbase      ; Use data from modified buffer
        ADD     r1, bufmask, #1
        BL      FillFromBuffer          ; Tolerable, as this case never
                                        ; really occurs in practise

; *********************** Partial buffer at end ? *****************************

35      Pull    "r0, r1, nbytes"
        ANDS    nbytes, nbytes, bufmask ; How much more left ?
        EXIT    EQ                      ; We've done it, boys !

        MOV     memadr, r0
        MOV     fileptr, r1             ; File position of end buffer

 [ debugosgbpb
 DREG nbytes, "Doing end section of ",cc
 DLINE " bytes"
 ]
        BL      FindFileBuffer          ; Valid buffer at endptr ?
        BLEQ    GetFileBuffer           ; NE -> found : use that then
        EXIT    VS

; Valid buffer at endptr - supply rest of data from that

 [ debugosgbpb
 DLINE "Copying data to memory from buffer offset 0"
 ]
        ADR     r1, bcb_bufferdata      ; Copy nbytes from offset 0 onwards
                                        ; NB. nbytes is never zero here !
        BL      MoveBytes               ; r2 -> punter memory
        EXIT                            ; VClear

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FillFromBuffer
; ==============
;
; Supply data from buffer to user memory (determined by memadr_filebase)

; In    bufmask, bcb^ valid, at right file address
;       r0 = start point in file
;       r1 = number of bytes to do

; Out   r1 = number of bytes done

FillFromBuffer Entry "r0-r3" ; Result poked into stack

 [ debugosgbpb
 DREG r0, "FillFromBuffer: fileptr ",cc
 DREG r1, ", nbytes_reqested "
 ]
        AND     r0, r0, bufmask         ; Offset in buffer

        LDR     r2, bcb_bufferbase      ; Base fileptr of buffer
        LDR     r14, memadr_filebase    ; Add punter base addr to this base ptr
        ADD     r2, r2, r14             ; Punter address of buffer start

        ADD     r14, bufmask, #1        ; Limit xfer to this buffer
        ADD     r3, r0, r1              ; start offset + nbytes_reqested
        CMP     r3, r14                 ; Over the end; if so reduce nbytes
        SUBHI   r3, r14, r0             ; nbytes := buffer size - start offset
        MOVS    r3, r1
        STR     r3, [sp, #4]            ; Otherwise do nbytes_requested (r1)
                                        ; Poke result into stack
        EXIT    EQ                      ; Exit if nothing to do. VClear

        ADR     r1, bcb_bufferdata      ; My address of buffer start
        ADD     r1, r1, r0              ; My address of xfer start
        ADD     r2, r2, r0              ; Punter address of xfer start

 [ debugosgbpb
 DREG r0, "Using buffered data up from offset ",cc
 DREG r2, " in buffer -> memory ",cc
 DREG r3, ", nbytes_doing "
 ]
        BL      MoveBytes               ; Corrupts r0-r3
 [ No26bitCode
        CLRV
        EXIT
 |
        EXITS                           ; Assumes VClear in entry lr
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; We can use r0-r2 as temporaries after preserving r1 (for error on way out)
; r3(status) isn't needed, so can use this
; r4(fileptr) will be updated by op
; Keep r5-r6 ok !

; No need to invalidate caches as appropriate routines will do so

BufferedMultipleWrite EntryS "r1, bcb"

        TEQ     r0, #OSGBPB_WriteAtGiven ; Only difference between the two ops
        LDREQ   fileptr, gbpb_fileptr

        LDR     nbytes, gbpb_nbytes

        ADDS    r1, fileptr, nbytes     ; endptr := startptr + nbytes
        BCS     %FA99                   ; [file too big]
        STR     r1, endptr              ; remember to rewrite scb_extent at end

; If we have a file buffer that will be totally invalidated by the operation
; then discard it now

        MOV     r0, fileptr
        BL      DiscardBuffersBetween   ; fileptr..endptr-1
        EXIT    VS

        CMP     r1, extent              ; Need to make file bigger ?
        BLS     %FT01

        BL      GBPBExtendFile          ; r1 still endptr
        EXIT    VS

01 ; File is now correct size to take data

        ; Adjust gbpb_fileptr even if no bytes transfered for the write at ptr case
        ADD     r14, fileptr, nbytes    ; endptr  := startptr  + nbytes_doing
        STR     r14, gbpb_fileptr

        CMP     nbytes, #0              ; Doing anything at all ? If not, quit
        BEQ     %FA85                   ; (may have done 0 byte xfer extending)

        LDR     memadr, gbpb_memadr     ; Begin to need to know this now

        MOV     r14, #0                 ; nbytes_notdoing := 0 (always full)
        STR     r14, gbpb_nbytes
        ADD     r14, memadr, nbytes     ; endaddr := startaddr + nbytes_doing
        STR     r14, gbpb_memadr

; ;;;;;;startptr = fileptr(r4), nbytes_doing = r3, punter's memory at r2 ; ;;;;;

 [ debugosgbpb
 DREG nbytes, "BufferedMultipleWrite: nbytes_doing ",cc
 DREG fileptr, " to PTR ",cc
 DREG r14, ", endptr = "
 ]

; ********* Loop over valid partial, then whole, buffers at start *************

05      BL      FindFileBuffer          ; Valid buffer at startptr ?
        BNE     %FT10                   ; NE -> found: use that then


; If startptr isn't buffer aligned, then we'll need to get a buffer + use it

        TST     fileptr, bufmask        ; Doing aligned start ?
        BEQ     %FT20                   ; Include this buffer in middle + end

        BL      GetFileBuffer           ; Only get underlay if fileptr<=scb_ext
        EXIT    VS                      ; (gets memory to use though !)
 [ debugosgbpbirq
 Push "r0, lr"
 MOV r0, psr
 TST r0, #I_bit
 MOVEQ r0, #"4"
 MOVNE r0, #"d"
 SWI XOS_WriteC
 Pull "r0, lr"
 ]


10 ; Valid buffer at startptr - write as much data as possible to that

        LDRB    r14, bcb_status         ; Buffer modified
        ORR     r14, r14, #bcb_modified
        STRB    r14, bcb_status

        AND     r0, fileptr, bufmask    ; Offset of start point in buffer
 [ debugosgbpb
 DREG r0, "Copying data from memory to buffer offset "
 ]
        ADR     r1, bcb_bufferdata
        ADD     r1, r1, r0              ; My address of start point
        SUB     r0, bufmask, r0         ; n_possible := bufsize - startoffset
        ADD     r0, r0, #1
        CMP     r0, nbytes              ; n_doing := min (n_possible, n_bytes)
        MOVHI   r0, nbytes
        Push    "r0, r2, r3"            ; Remember n_doing(r0) for after loop
                                        ; NB. This is never zero here !
        MOV     r3, r0
        Swap    r1, r2                  ; Exchange pointers
        BL      MoveBytes

        Pull    "r0, r2, r3"
        ADD     memadr, memadr, r0

        SUBS    nbytes, nbytes, r0      ; Completed whole xfer ?
        BEQ     %FA85                   ; VClear

; Force aligned data transfer at next file position 0000..00FF -> 0100

        BIC     fileptr, fileptr, bufmask
        ADD     fileptr, fileptr, bufmask
        ADD     fileptr, fileptr, #1    ; File address of next whole buffer


; If multiple buffers ever arrive, we could loop back to %BT05 any try more


; To get write-behind to go properly, flush this buffer before rather than
; after the whole buffer section as it is earlier in the file

 [ debugosgbpbirq
 Push "r0, lr"
 MOV r0, psr
 TST r0, #I_bit
 MOVEQ r0, #"5"
 MOVNE r0, #"e"
 SWI XOS_WriteC
 Pull "r0, lr"
 ]
        TST     nbytes, bufmask         ; Will we require a partial end buffer?
        BLNE    FlushBuffer_IfNoError   ; keeps data if I/O error occurs
        EXIT    VS                      ; (stream not marked 'data lost')

20 ; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Done the start bit, memadr/fileptr -> start of whole memory/sectors for xfer

; If we had multiple buffers, we'd need to loop down from aligned end getting
; data out of them rather than off disc

        Push    nbytes                  ; Remember you're a womble
        BICS    nbytes, nbytes, bufmask ; How many bytes in whole xfer? psr imp
        ADD     r0, memadr, nbytes
        ADD     r1, fileptr, nbytes     ; Where the end is (may be here !)
        Push    "r0, r1"
        BEQ     %FA35                   ; Skip if no middle

 [ debugosgbpb
 DREG nbytes, "Doing whole buffer xfers: putting "
 ]
        BL      CallFSPutData           ; Get it directly from the punter
        Pull    "r0, r1, nbytes", VS    ; if any requested
        EXIT    VS

 [ debugosgbpb
 DLINE "Whole buffer section complete"
 ]

; *********************** Partial buffer at end ? *****************************

35      Pull    "r0, r1, nbytes"
        ANDS    nbytes, nbytes, bufmask ; How much more left ?
        BEQ     %FA85                   ; We've done it, boys !

        MOV     memadr, r0
        MOV     fileptr, r1             ; File position of end buffer

 [ debugosgbpb
 DREG nbytes, "Doing end section of ",cc
 DLINE " bytes"
 ]
        BL      GetFileBuffer           ; Only get underlay if fileptr<=scb_ext
        EXIT    VS                      ; (gets memory to use though !)

; Valid buffer at endptr - supply rest of data to that

        LDRB    r14, bcb_status         ; Buffer modified
        ORR     r14, r14, #bcb_modified
        STRB    r14, bcb_status

 [ debugosgbpb
 DLINE "Copying data from memory to buffer offset 0"
 ]
        MOV     r1, r2
        ADR     r2, bcb_bufferdata      ; Copy nbytes from offset 0 onwards
                                        ; NB. nbytes never zero here !

        BL      MoveBytes


85      LDR     r14, endptr             ; If new extent > old extent, rewrite
        CMP     r14, extent
        STRHI   r14, scb_extent
        LDR     r14, gbpb_fileptr       ; stream fileptr updated if no error
        STR     r14, scb_fileptr
        EXITS                           ; Assumes VClear on entry


99      addr    r0, ErrorBlock_FSFileTooBig
        BL      CopyError
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; GBPBExtendFile
; ==============

; In    fileptr = length of file to extend and fill with zeroes to
;       extent  = old extent of file
;       r1      = new extent of file (endptr), known nonzero

; WriteMultiple needs to extend the file

GBPBExtendFile Entry "r0-r2, fileptr, extent"

; Make file large enough to take data - if file extension takes place, tell
; filing system the old extent as well as the new size, so only valid data gets
; moved on the disc if the file gets moved around

 [ debugosgbpb
 DREG r1, "WriteMultiple causing file extension, new endptr "
 ]
        ADD     r2, r1, bufmask         ; Round xx001 -> xx100, but not xx000
        BICS    r2, r2, bufmask
        MOVEQ   r2, #&FFFFFFFF          ; Saturate at 4G-1 
        BL      EnsureFileSize          ; Uses scb_extent
        EXIT    VS

; May have to write zeroes between old extent and start of block we're going to
; write if fileptr > extent

        CMP     fileptr, extent         ; Need to write block of zeroes ?
 [ No26bitCode
        BHI     %FT10
        CLRV
        EXIT
10
 |
        EXITS   LS                      ; No - assumes VClear in entry lr
 ]

 [ debugstream
 DREG fileptr, "WriteMultiple extending with zeroes to fileptr ",cc
 DREG extent, " from old extent "
 ]
        TST     extent, bufmask
        MOVEQ   r2, extent              ; Start point in file
        BEQ     %FT20                   ; [no partial update needed]

; Old extent unaligned, so we need to write zeroes to that buffer

        MOV     fileptr, extent         ; Get buffer at old extent
        BL      EnsureBufferValid
        EXIT    VS

        AND     r0, extent, bufmask     ; Offset of old extent in buffer
        BL      ZeroBufferFromPosition  ; Clear from old extent to eob

        LDR     fileptr, [sp, #4*3]     ; reload fileptr
        BIC     r14, fileptr, bufmask   ; Is extent in same buffer as fileptr ?
        BIC     r2, extent, bufmask
        CMP     r14, r2
        EXIT    EQ                      ; [yes, so no more to do here]
                                        ; don't flush in this case, as we'll
                                        ; reload in just a minute to do first
                                        ; partial data xfer to this point

        ADD     r2, r2, bufmask         ; Start point in file = roundup(extent)
        ADD     r2, r2, #1

        BL      FlushBuffer_IfNoError   ; data NOT lost if error occurs
        EXIT    VS                      ; motion to do now rather than after
                                        ; WriteZeroes call and subsequent load)


20 ; Write zeroes to file ? extent now aligned. r2 = start point in file

        BIC     r14, fileptr, bufmask

        SUBS    r1, r14, r2             ; How much to do
        BLNE    ZeroFileFromPosition
        EXIT    VS

; Do we need to create a partial buffer full of zeroes at fileptr ?

        TST     fileptr, bufmask
        EXIT    EQ                      ; No

        BL      EnsureBufferValid

        MOVVC   r0, #0                  ; Zap the lot
        BLVC    ZeroBufferFromPosition
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The wally GBPB ops - ReadCSDName and ReadLIBName

; In    r2 -> memory to put info

Daft_ReadName Entry "r2,r3,r5,fscb", 4

 [ debugdaftgbpb
        DREG    r2, "Daft_ReadName to "
 ]

        ; Construct the dir variable name
        TEQ     r0, #OSGBPB_ReadCSDName
        MOVEQ   r2, #Dir_Current
        MOVNE   r2, #Dir_Library
        BL      ReadTempFS
        EXIT    VS
        MOV     fscb, r0

        TEQ     fscb, #Nowt
        BLEQ    SetErrorNoSelectedFilingSystem
        EXIT    VS

        MOV     r0, sp
        ADR     r3, Unset
        BL      ReadDirWithSuppliedDefault
        EXIT    VS

        LDR     r1, [sp]

        ; Find the last :, . or start of string
        BL      strlen
        B       %FT10
05
        LDRB    r0, [r1, r3]
        TEQ     r0, #":"
        TEQNE   r0, #"."
        BEQ     %FT15
10
        SUBS    r3, r3, #1
        BPL     %BT05
15
        ADD     r3, r3, #1
        ADD     r1, r1, r3
        BL      strlen
        MOV     r2, r1

        ; Copy \0, <len>, string (with nul terminator)
        LDR     r1, [sp, #Proc_LocalStack + 0*4]
 [ debugdaftgbpb
        DREG    r1, "Actually putting stuff to "
 ]
        MOV     r14, #0
        STRB    r14, [r1], #1
        STRB    r3, [r1], #1
        BL      strcpy

50
        MOV     r0, sp
        BL      SFreeLinkedString

 [ debugdaftgbpb
        DLINE   "Daft_ReadName done"
 ]
        EXIT

ColonUnset
        DCB     ":"
Unset
        DCB     """Unset""",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The wally GBPB op ReadDiscName

; In    r2 -> memory to put info

Daft_ReadDiscName Entry "r0,r1,r2,r3,r4,r5", 4

        ; Save destination in r4
        MOV     r4, r2

        ; Get the TempFS and make sure there is one
        BL      ReadTempFS
        TEQ     r0, #Nowt
        BLEQ    SetErrorNoSelectedFilingSystem
        EXIT    VS

        ; Get the value
        MOV     fscb, r0
        MOV     r0, sp
        MOV     r2, #Dir_Current
        ADR     r3, ColonUnset
        BL      ReadDirWithSuppliedDefault
        EXIT    VS

        ; Skip the special (if present)
        LDR     r1, [sp]
        LDRB    r14, [r1]
        TEQ     r14, #"#"
        BNE     %FT10

        MOV     r0, #":"
        BL      strchr
        ADRNE   r1, ColonUnset

10
        ; Extract the disc name, mapping not present to 'Unset'
        BL      GetDiscFromPath
        TEQ     r2, #NULL
        ADREQ   r2, Unset

        ; Store <strlen><disc name><\0>
        MOV     r1, r2
        BL      strlen
        MOV     r1, r4
        STRB    r3, [r1], #1
        BL      strcpy

50
        MOV     r0, sp
        BL      SFreeLinkedString

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Daft_ReadCSDEntries
; ===================
;
; Read entries out of CSD

; In    r2 -> memory to put info
;       r3 =  number of names to read
;       r4 =  offset in directory (starting at 0)

; Out   gbpb_nbytes  = number of names NOT read
;       gbpb_fileptr = next offset in directory

Daft_ReadCSDEntries Entry "r0-r6" ; GBPB saves r0-r1; FSFunc saves r6-wp

        ; Do business for '@'
        ADR     r1, %F90
        MOV     r2, #NULL
        addr    r3, anull
        MOV     r5, #2_000
        BL      TopPath_DoBusinessForDirectoryRead
        EXIT    VS

        ; Get the parameters back from the stack
        ADD     r14, sp, #2*4
        LDMIA   r14, {r2,r3,r4}

        ADD     r14, r3,  r3, LSL #3    ; *9
        ADD     r14, r14, r3, LSL #1    ; *11
        ADD     r5, r2, r14             ; Check buffer for at least r3 names
                                        ; of size 10 (+1 for length byte)
        BL      ValidateR2R5_WriteToCore
        BVS     %FT95

        MOV     r0, #fsfunc_ReadDirEntries
        MOV     r5, #&100000
        Push    "r2"
        BL      CallFSFunc_Given
        Pull    "r2"
        BVS     %FT95

        MOV     r5, r3          ; Remember how many to mutate

        LDR     r14, gbpb_fileptr
        CMP     r3, #0          ; If none read, leave fileptr at end of dir
        MOVNE   r14, r4
        STRNE   r14, gbpb_fileptr

        LDR     r14, gbpb_nbytes
        SUB     r14, r14, r3    ; Return number of entries NOT read
        STR     r14, gbpb_nbytes

        MOV     r1, r2          ; First name^

50      SUBS    r5, r5, #1      ; Finished ?
        BMI     %FT95           ; VClear. Deallocate exit
        BL      strlen
        ADD     r14, r1, r3     ; Point to the zero
55      CMP     r14, r1         ; Done them all ?
        LDRNEB  r0, [r14, #-1]  ; Load char from byte below posn
        MOVEQ   r0, r3          ; Length byte if last one
        STRB    r0, [r14], #-1  ; Put in place, and decrement for next
        BNE     %BT55
        ADD     r1, r1, r3      ; Skip to next name
        ADD     r1, r1, #1
        B       %BT50
90
        DCB     "@", 0
        ALIGN

95
        BL      JunkFileStrings
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Daft_ReadDirEntries
; ===================
;
; Read entries out of a given directory, matching against given wildcarded name

; In    r0 = reason code
;       r1 -> directory name
;       r2 -> memory to put info
;       r3 =  number of names to read
;       r4 =  offset in directory (starting at 0)
;       r5 =  buffer length
;       r6 =  wildcard specifier (0 -> use '*')

; Out   r0-r6 preserved, gbpb_nbytes, gbpb_fileptr updated at this level
;       r3 at SWI level = number of names read (will be zero if eod)
;       r4 at SWI level = next offset in directory

Daft_ReadDirEntries Entry "r0-r10" ; FSFunc only preserves r6 up

; Common code to start us off

        CMP     r3, #0                  ; Silly request ?
        BEQ     Daft_ReadDirEntriesNullExit

        TST     r4, #(1 :SHL: 31)       ; Already at end ? (-ve)
        BNE     Daft_ReadDirEntriesNullExit

        ADD     r5, r2, r5              ; Check buffer
        BL      ValidateR2R5_WriteToCore
        EXIT    VS

        MOV     r2, #NULL
        addr    r3, anull
        MOV     r5, #2_000
        BL      TopPath_DoBusinessForDirectoryRead
        EXIT    VS

        ; Pick up Op
        LDR     r0, [sp, #0*4]  ; op
        LDR     r2, gbpb_memadr ; buff
        LDR     r5, [sp, #5*4]  ; buflen

 ;r0=op
 ;r1=tail
 ;r2=buf
 ;r5=buflen
 ;r6=special
 ;fscb (r10)
 ;fp (r11)
 ;wp (r12)

        ; Determine the following parameters of the conversion:
        ; Low level reason code
        ; Source number of bytes for that reason code
        ; Destination number of bytes for the user reason code (more)
        ; Routine to copy down and expand extra words

        ; Everybody understands and gets right a plain ReadDirEntries
        TEQ     r0, #OSGBPB_ReadDirEntries
        MOVEQ   r0, #fsfunc_ReadDirEntries
        ADREQ   r7, ReadDirEntries_NowtToCopyDown
        BEQ     %FT05

        ; Everybody understands ReadDirEntriesInfo, but some people mess up doing it
        TEQ     r0, #OSGBPB_ReadDirEntriesInfo
        MOVEQ   r0, #fsfunc_ReadDirEntriesInfo
        MOVEQ   r3, #RDE_name+1+1+2
        MOVEQ   r4, #0
        ADREQ   r7, ReadDirEntries_CopyDownInfoStraight
        BEQ     %FT02

        ; ReadDirEntriesFileType needs frigging by FileSwitch (and some
        ; filing systems mess up the ReadDirEntries)
        TEQ     r0, #OSGBPB_ReadDirEntriesFileType
        MOVEQ   r0, #fsfunc_ReadDirEntriesInfo
        MOVEQ   r3, #RDE_name+1+1+2
        MOVEQ   r4, #4
        ADREQ   r7, ReadDirEntries_CopyDownInfoToFileType
        BEQ     %FT02

        ; ReadDirEntriesCatInfo is all that's left
;       TEQ     r0, #OSGBPB_ReadDirEntriesCatInfo
        LDRB    r0, [fscb, #fscb_info]
        TEQ     r0, #0
        MOVNE   r0, #fsfunc_CatalogObjects
        MOVNE   r3, #RDE_name+9+1+1+1
        MOVNE   r4, #0
        ADRNE   r7, ReadDirEntries_CopyDownCatObj
        MOVEQ   r0, #fsfunc_ReadDirEntriesInfo
        MOVEQ   r3, #RDE_name+1+1+2
        MOVEQ   r4, #12
        ADREQ   r7, ReadDirEntries_CopyDownInfoToCatObj

02
        ; r0 = low-level op to use
        ; r1 = path tail
        ; r2 = buffer
        ; r3 = basic op size of a minimum entry
        ; r4 = maximum expansion an entry may have
        ; r5 = buffer length
        ; r6 = special
        ; r7 = copy-down routine
        ; r10 = fscb

        Push    "r0"

        ; Stage (i) buffer adjustment:
        ; This adjusts the buffer for the expansion caused by contents expansion.
        ; Size reduction is (B+g)/(g+m) * g
        ; B = old buffer size
        ; g = growth per record
        ; m = minimum record size

        ADD     r0, r5, r4              ; B+g
        ADD     r9, r3, r4              ; g+m
        DivRem  r8, r0, r9, r14, norem  ; (B+g)/(g+m) (note we *DO* want the round-down here)
        MUL     r8, r4, r8              ; (B+g)/(g+m) * g
        ADD     r2, r2, r8              ; Adjust buffer start
        SUB     r5, r5, r8              ; Adjust buffer length

 [ debugdaftgbpb
        DREG    r8, "Expansion-adjust:"
 ]

 [ kludgeforNFS
        ; Stage (ii) buffer adjustment:
        ; This adjusts the buffer for duff filing systems (NFS) which don't count
        ; the ALIGN between each entry when totting up the length.
        ; Buffer reduction is (B+g-1)/(g+m) * g
        ; g is 3 here
        ; Difference of expression is due to the gaps only being duff.

        ADD     r0, r5, #2              ; B+g-1
        ADD     r9, r3, #3              ; g+m
        DivRem  r8, r0, r9, r14, norem  ; (B+g-1)/(B+m)
        ADD     r8, r8, r8, ASL #1      ; (B+g-1)/(B+m) * g
        SUB     r5, r5, r8              ; Adjust buffer size only

  [ debugdaftgbpb
        DREG    r8, "NFS adjust:"
  ]
 ]
 [ debugdaftgbpb
        DREG    r5, "New buffer size:"
 ]

        Pull    "r0"

05 ; Reentry point for below loop
        ; r0 = low level op
        ; r1 = path tail
        ; r2 = buffer
        ; r5 = buffer length
        ; r6 = special
        ; r7 -> routine to copy down fixed fields
        ; r10 = fscb

        LDR     r3, gbpb_nbytes
        LDR     r4, gbpb_fileptr

 [ debugdaftgbpb
        DREG    r0,"In r0=",cc
        DSTRING r1," r1=",cc
        DREG    r2," r2=",cc
        DREG    r3," r3=",cc
        DREG    r4," r4=",cc
        DREG    r5," r5=",cc
        DSTRING r6," r6="
 ]
        ; In r0-r6,fscb
        ; Out
        ; r0-r2 trashed
        ; r3=number read
        ; r4=continuation
        ; r5-r6 trashed
        Push    "r0,r2"
        BL      CallFSFunc_Given
        Pull    "r0,r2"
        BVS     Daft_ReadDirEntriesDeallocate
 [ debugdaftgbpb
        DREG    r3, "Returned ",cc
        DREG    r4, " names; next dir position "
 ]

        STR     r4, gbpb_fileptr        ; Update punter r4 here, r3 after match

        CMP     r3, #0                  ; Nothing from filing system ?
        BNE     %FT10

        CMP     r4, #-1                 ; All done ?
        BEQ     Daft_ReadDirEntriesExit ; Exit updating punter r3, deall string

07
        addr    r0, ErrorBlock_BuffOverflow ; r3 = 0, r4 <> -1 -> error !
        BL      CopyError
        B       Daft_ReadDirEntriesDeallocate


10
        ; a non-0 number of names read
        ; r0 = low-level op
        ; r2 = source
        ; r3 = number read
        ; r7 = copy-down routine

        TEQ     r0, #fsfunc_ReadDirEntries
        MOVEQ   r5, #0
        TEQ     r0, #fsfunc_ReadDirEntriesInfo
        MOVEQ   r5, #RDE_name
        TEQ     r0, #fsfunc_CatalogObjects
        MOVEQ   r5, #RDE_name+9

        MOV     r9, r3                  ; Number of names returned
        MOV     r3, #0                  ; How many matched so far
        LDR     r0, gbpb_memadr         ; dst
        MOV     r1, r2

        LDR     r2, [sp, #6*4]
        TEQ     r2, #0
        addr    r2, fsw_wildstar, EQ

        ; r0 = dst
        ; r1 = src
        ; r2 = wildcard
        ; r3 = count of matches
        ; r5 = size of src prefix stuff
        ; r7 = copy-down routine
        ; r9 = src count


30
        ADD     r1, r1, r5
        BL      WildMatch
        BNE     %FT40

        ; It's a match
        SUB     r1, r1, r5

        ADD     r3, r3, #1

        ; copy down the name-prefix gumph
        MOV     r14, pc
        MOV     pc, r7
ReadDirEntries_NowtToCopyDown

        ; copy down the name
35
        LDRB    r14, [r1], #1
        STRB    r14, [r0], #1
        CMP     r14, #space
        BHS     %BT35

        ; Align src and dst if necessary
        TEQ     r5, #0
        ADDNE   r0, r0, #3
        BICNE   r0, r0, #3
        B       %FT45

40
        ; It's a non-match: skip over name
        LDRB    r14, [r1], #1
        CMP     r14, #space
        BHS     %BT40

        ; Align again if there's need
        TEQ     r5, #0
45
        ADDNE   r1, r1, #3
        BICNE   r1, r1, #3

50
        SUBS    r9, r9, #1
        BNE     %BT30

; .............................................................................

Daft_ReadDirEntriesExit

 [ debugdaftgbpb
 DREG r3, "Number of items matched = "
 ]
        STR     r3, gbpb_nbytes         ; Update punter r3

Daft_ReadDirEntriesDeallocate

        BL      JunkFileStrings
        EXIT


Daft_ReadDirEntriesNullExit

        MOV     r3, #0
        MOV     r4, #-1
 ASSERT gbpb_fileptr = gbpb_nbytes+4
        ADR     r14, gbpb_nbytes
        STMIA   r14, {r3, r4}
        EXIT

; Now the routines to copy down the various fixed parts of
; the various read dir ops.
; In
;    r0 = dst
;    r1 = src
;    r14 = return address
; Out
;    r0 advanced past copied-down fixed record
;    r1 advanced past copied-down fixed part
;    r2,r3,r5,r7,r9,r11,r12,r13 preserved
;    r4,r6,r8,r10,r14 up for grabs
;

; Copy down the five words which is the straight file info
; Adjust files into partitions as appropriate
ReadDirEntries_CopyDownInfoStraight ROUT
        Push    "r0,r2,r3,lr"
        LDMIA   r1!, {r2,r3,r4,r6,r8}
        MOV     r0, r8
        BL      AdjustObjectTypeReMultiFS
        MOV     r8, r0
        Pull    "r0"
        STMIA   r0!, {r2,r3,r4,r6,r8}
        Pull    "r2,r3,pc"

; Copy down the straight file info, expand with file type
; Adjust files into partitions
ReadDirEntries_CopyDownInfoToFileType ROUT
        Push    "r0,r2,r3,r5,lr"
        LDMIA   r1!, {r2,r3,r4,r5,r6}
        MOV     r0, r6
        BL      AdjustObjectTypeReMultiFS
        MOV     r6, r0
        MOV     r10, r2
        BL      InfoToFileType
        MOV     r8, r2
        MOV     r2, r10
        Pull    "r0"
        STMIA   r0!, {r2,r3,r4,r5,r6,r8}
        Pull    "r2,r3,r5,pc"

; Copy down the catalogue info adjusting files into partitions as appropriate
ReadDirEntries_CopyDownCatObj ROUT
        Push    "r0,r2,r3,r5,lr"
        LDMIA   r1!, {r2,r3,r4,r5,r6,r8,r10}
        MOV     r0, r6
        BL      AdjustObjectTypeReMultiFS
        MOV     r6, r0
        Pull    "r0"
        STMIA   r0!, {r2,r3,r4,r5,r6,r8,r10}
        LDRB    r14, [r1], #1
        STRB    r14, [r0], #1
        Pull    "r2,r3,r5,pc"

; Copy down info to be catalogue info. Adjusts files into partitions.
; Copies date stamp into time/date, or sets time/date to 0 if unstamped.
; Sets SIN to 0
ReadDirEntries_CopyDownInfoToCatObj ROUT
        Push    "r0,r2,r3,r5,lr"
        LDMIA   r1!, {r2,r3,r4,r5,r6}
        MOV     r0, r6
        BL      AdjustObjectTypeReMultiFS
        BL      IsFileTyped
        MOV     r6, r0
        Pull    "r0"
        MOV     r8, #0
        MOVEQ   r10, r3
        MOVNE   r10, #0
        STMIA   r0!, {r2,r3,r4,r5,r6,r8,r10}
        STREQB  r2, [r0], #1
        STRNEB  r10, [r0], #1
        Pull    "r2,r3,r5,pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; MoveBytes(source, dest, size in bytes) - fast data copier from RCM
; =========

; SKS Reordered registers and order of copying to suit FileSwitch

; ** Not yet optimised to do transfers to make most of 1N,3S feature of MEMC **

; In:   r1 = src^ (byte address)
;       r2 = dst^ (byte address)
;       r3 = count (byte count - never zero!)

; Out:  r0-r3, lr corrupt

mbsrc1   RN 0
mbsrcptr RN 1
mbdstptr RN 2
mbcnt    RN 3
mbsrc2   RN 14                          ; Note deviancy, so care in LDM/STM
mbsrc3   RN 4
mbsrc4   RN 5
mbsrc5   RN 6
mbsrc6   RN 7
mbsrc7   RN 8
mbsrc8   RN 9
mbsrc9   RN 10
mbshftL  RN 11                          ; These two go at end to save a word
mbshftR  RN 12                          ; and an extra Pull lr!

MoveBytes Entry

 [ debugosgbpb
 DREG r1, "Copying data from ",cc
 DREG r2, " to ",cc
 DREG r3, ", nbytes_doing "
 ]
        TST     mbdstptr, #3
        BNE     MovByt100               ; [dst^ not word aligned]

MovByt20 ; dst^ now word aligned. branched back to from below

        TST     mbsrcptr, #3
        BNE     MovByt200               ; [src^ not word aligned]

; src^ & dst^ are now both word aligned
; cnt is a byte value (may not be a whole number of words)

; Quick sort out of what we've got left to do

        SUBS    mbcnt, mbcnt, #4*4      ; Four whole words to do (or more) ?
        BLT     MovByt40                ; [no]

        SUBS    mbcnt, mbcnt, #8*4-4*4  ; Eight whole words to do (or more) ?
        BLT     MovByt30                ; [no]

        Push    "mbsrc3-mbsrc8"         ; Push some more registers
MovByt25
 [ debugosgbpb
 DREG mbsrcptr,"Copying 8 words from "
 ]
        LDMIA   mbsrcptr!, {mbsrc1, mbsrc3-mbsrc8, mbsrc2} ; NB. Order!
        STMIA   mbdstptr!, {mbsrc1, mbsrc3-mbsrc8, mbsrc2}

        SUBS    mbcnt, mbcnt, #8*4
        BGE     MovByt25                ; [do another 8 words]
        Pull    "mbsrc3-mbsrc8"         ; Outside loop (silly otherwise)

        CMP     mbcnt, #-8*4            ; Quick test rather than chaining down
        EXIT    EQ                      ; [finished]


MovByt30
        ADDS    mbcnt, mbcnt, #8*4-4*4  ; Four whole words to do ?
        BLT     MovByt40

        Push    "mbsrc3-mbsrc4"         ; Push some more registers

 [ debugosgbpb
 DREG mbsrcptr,"Copying 4 words from "
 ]
        LDMIA   mbsrcptr!, {mbsrc1, mbsrc3-mbsrc4, mbsrc2} ; NB. Order!
        STMIA   mbdstptr!, {mbsrc1, mbsrc3-mbsrc4, mbsrc2}

        Pull    "mbsrc3-mbsrc4"

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #4*4


MovByt40
        ADDS    mbcnt, mbcnt, #4*4-2*4  ; Two whole words to do ?
        BLT     MovByt50

 [ debugosgbpb
 DREG mbsrcptr,"Copying 2 words from "
 ]
        LDMIA   mbsrcptr!, {mbsrc1, mbsrc2}
        STMIA   mbdstptr!, {mbsrc1, mbsrc2}

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #2*4


MovByt50
        ADDS    mbcnt, mbcnt, #2*4-1*4  ; One whole word to do ?
        BLT     MovByt60

 [ debugosgbpb
 DREG mbsrcptr,"Copying 1 word from "
 ]
        LDR     mbsrc1, [mbsrcptr], #4
        STR     mbsrc1, [mbdstptr], #4

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #1*4


MovByt60
        ADDS    mbcnt, mbcnt, #1*4-0*4  ; No more to do ?
        EXIT    EQ                      ; [finished]


        LDR     mbsrc1, [mbsrcptr]      ; Store remaining 1, 2 or 3 bytes
MovByt70
 [ debugosgbpb
 DREG mbsrcptr,"Copying 1 byte from "
 ]
        STRB    mbsrc1, [mbdstptr], #1
        MOV     mbsrc1, mbsrc1, LSR #8
        SUBS    mbcnt, mbcnt, #1
        BGT     MovByt70

        EXIT


; Initial dest^ not word aligned. Loop doing bytes (1,2 or 3) until it is

MovByt100
        LDRB    mbsrc1, [mbsrcptr], #1
        STRB    mbsrc1, [mbdstptr], #1
        SUBS    mbcnt, mbcnt, #1
        EXIT    EQ                      ; Finished after 1..3 bytes
        TST     mbdstptr, #3
        BNE     MovByt100

        B       MovByt20                ; Back to mainline code



MovByt200 ; dst^ now word aligned, but src^ isn't

 ASSERT "$Proc_RegList" = "" ; ie. just lr stacked at the moment
Proc_RegList SETS "mbshftL, mbshftR"

        Push    "mbshftL, mbshftR"      ; Need more registers this section

        AND     mbshftR, mbsrcptr, #3   ; Offset
        BIC     mbsrcptr, mbsrcptr, #3  ; Align src^

        MOV     mbshftR, mbshftR, LSL #3 ; rshft = 0, 8, 16 or 24 only
        RSB     mbshftL, mbshftR, #32    ; lshft = 32, 24, 16 or 8  only

        LDR     mbsrc1, [mbsrcptr], #4
        MOV     mbsrc1, mbsrc1, LSR mbshftR ; Always have mbsrc1 prepared

; Quick sort out of what we've got left to do

        SUBS    mbcnt, mbcnt, #4*4      ; Four whole words to do (or more) ?
        BLT     MovByt240               ; [no]

        SUBS    mbcnt, mbcnt, #8*4-4*4  ; Eight whole words to do (or more) ?
        BLT     MovByt230               ; [no]

        Push    "mbsrc3-mbsrc9"         ; Push some more registers
MovByt225
        LDMIA   mbsrcptr!, {mbsrc3-mbsrc9, mbsrc2} ; NB. Order!
        ORR     mbsrc1, mbsrc1, mbsrc3, LSL mbshftL

        MOV     mbsrc3, mbsrc3, LSR mbshftR
        ORR     mbsrc3, mbsrc3, mbsrc4, LSL mbshftL

        MOV     mbsrc4, mbsrc4, LSR mbshftR
        ORR     mbsrc4, mbsrc4, mbsrc5, LSL mbshftL

        MOV     mbsrc5, mbsrc5, LSR mbshftR
        ORR     mbsrc5, mbsrc5, mbsrc6, LSL mbshftL

        MOV     mbsrc6, mbsrc6, LSR mbshftR
        ORR     mbsrc6, mbsrc6, mbsrc7, LSL mbshftL

        MOV     mbsrc7, mbsrc7, LSR mbshftR
        ORR     mbsrc7, mbsrc7, mbsrc8, LSL mbshftL

        MOV     mbsrc8, mbsrc8, LSR mbshftR
        ORR     mbsrc8, mbsrc8, mbsrc9, LSL mbshftL

        MOV     mbsrc9, mbsrc9, LSR mbshftR
        ORR     mbsrc9, mbsrc9, mbsrc2, LSL mbshftL

        STMIA   mbdstptr!, {mbsrc1, mbsrc3-mbsrc9}

        MOV     mbsrc1, mbsrc2, LSR mbshftR ; Keep mbsrc1 prepared

        SUBS    mbcnt, mbcnt, #8*4
        BGE     MovByt225               ; [do another 8 words]
        Pull    "mbsrc3-mbsrc9"

        CMP     mbcnt, #-8*4            ; Quick test rather than chaining down
        EXIT    EQ                      ; [finished]


MovByt230
        ADDS    mbcnt, mbcnt, #8*4-4*4  ; Four whole words to do ?
        BLT     MovByt240

        Push    "mbsrc3-mbsrc5"         ; Push some more registers
        LDMIA   mbsrcptr!, {mbsrc3-mbsrc5, mbsrc2} ; NB. Order!
        ORR     mbsrc1, mbsrc1, mbsrc3, LSL mbshftL

        MOV     mbsrc3, mbsrc3, LSR mbshftR
        ORR     mbsrc3, mbsrc3, mbsrc4, LSL mbshftL

        MOV     mbsrc4, mbsrc4, LSR mbshftR
        ORR     mbsrc4, mbsrc4, mbsrc5, LSL mbshftL

        MOV     mbsrc5, mbsrc5, LSR mbshftR
        ORR     mbsrc5, mbsrc5, mbsrc2, LSL mbshftL

        STMIA   mbdstptr!, {mbsrc1, mbsrc3-mbsrc5}
        Pull    "mbsrc3-mbsrc5"

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #4*4
        MOV     mbsrc1, mbsrc2, LSR mbshftR ; Keep mbsrc1 prepared


MovByt240
        ADDS    mbcnt, mbcnt, #2*4      ; Two whole words to do ?
        BLT     MovByt250

        Push    "mbsrc3"
        LDMIA   mbsrcptr!, {mbsrc3, mbsrc2} ; NB. Order!
        ORR     mbsrc1, mbsrc1, mbsrc3, LSL mbshftL

        MOV     mbsrc3, mbsrc3, LSR mbshftR
        ORR     mbsrc3, mbsrc3, mbsrc2, LSL mbshftL

        STMIA   mbdstptr!, {mbsrc1, mbsrc3}
        Pull    "mbsrc3"

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #2*4
        MOV     mbsrc1, mbsrc2, LSR mbshftR ; Keep mbsrc1 prepared


MovByt250
        ADDS    mbcnt, mbcnt, #2*4-1*4  ; One whole word to do ?
        BLT     MovByt260

        LDR     mbsrc2, [mbsrcptr], #4
        ORR     mbsrc1, mbsrc1, mbsrc2, LSL mbshftL
        STR     mbsrc1, [mbdstptr], #4

        EXIT    EQ                      ; [finished]
        SUB     mbcnt, mbcnt, #1*4
        MOV     mbsrc1, mbsrc2, LSR mbshftR ; Keep mbsrc1 prepared


MovByt260
        ADDS    mbcnt, mbcnt, #1*4-0*4
        EXIT    EQ                      ; [finished]

        CMP     mbshftL, mbcnt, LSL #3  ; Store remaining 1, 2 or 3 bytes
        LDRLO   mbsrc2, [mbsrcptr]
        ORR     mbsrc1, mbsrc1, mbsrc2, LSL mbshftL
MovByt270
        STRB    mbsrc1, [mbdstptr], #1
        MOV     mbsrc1, mbsrc1, LSR #8
        SUBS    mbcnt, mbcnt, #1
        BGT     MovByt270

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

        END
