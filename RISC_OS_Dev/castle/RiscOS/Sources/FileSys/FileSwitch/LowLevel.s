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
        SUBT    > Sources.LowLevel - Calls to the real Filing Systems

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;           L O W   L E V E L   F I L I N G   S Y S T E M   C A L L S
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; I have now foolishly guaranteed that Filing Systems may use registers r0-r12
; for their own purposes within their code without having to restore them when
; returning to me - ie. it would be nice if they kept the stack flat and
; remembered the lr I passed them !
; This means they only have to keep track of which are parms for the operation
; and which should be returned. SKS 05-Feb-87

; NB. Restore wp immediately after they return - it's stacked (somewhere) !

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSFile_Given
; ================
;
; Do an OSFILE type operation
; Monitor messages are printed according to the osfile op at this level

; In    r0 = OSFILE action to perform
;       r1 -> filename to use
;       fileblock contains parms to use (load, exec, length, attr)

; Out   VC: r0 and fileblock updated
;       VS: failed

CallFSFile_Given Entry "r0-r12" ; Never (ever) trust lower level routines

 [ osfile5cache
        ; OSFile5Cache format:
        ; 5 words of OSFile5 info
        ; 1 word fscb
        ; 1 word monotonic time
        ; filename
        ; special

        TEQ     r0, #fsfile_ReadInfo
        BNE     %FT10

 [ debugfile5cache
        DSTRING r1,"Cache ",cc
 ]

        ; it's OS_File 5 - check whether we have a cache hit
        LDR     r9, OsFile5Cache
        TEQ     r9, #Nowt
 [ debugfile5cache
        BNE     %FT01
        DLINE   "presence ",cc
01
 ]
        BEQ     %FT05

        LDR     lr, [r9, #5*4]!         ; skipping over the osfile5 info
        TEQ     lr, fscb
 [ debugfile5cache
        BEQ     %FT01
        DLINE   "fscb ",cc
01
 ]
        BNE     %FT05                   ; fscb mismatch

        SWI     XOS_ReadMonotonicTime
 [ debugfile5cache
        BVC     %FT01
        DLINE   "time read VS ",cc
01
 ]
        BVS     %FT05                   ; time didn't read
        LDR     lr, [r9, #4]!
        CMP     r0, lr
 [ debugfile5cache
        BLO     %FT01
        DLINE   "timeout ",cc
01
 ]
        BHS     %FT05                   ; timed out

        ADD     r2, r9, #4
        BL      strcmp
 [ debugfile5cache
        BEQ     %FT01
        DLINE   "tail ",cc
01
 ]
        BNE     %FT05                   ; tail mismatch

        ; move over name
        ADD     r1, r9, #4
        BL      strlen
        ADD     r9, r9, r3
        ADD     r9, r9, #1+4

        LDRB    lr, [fscb, #fscb_info]
        TEQ     lr, #0
        BEQ     %FT02

        ; ordinary filing system - compare special fields
        LDRB    lr, [r9], #1
        TEQ     lr, #0
        MOVEQ   r1, #NULL
        MOVNE   r1, r9
        MOV     r2, r6
        BL      strcmp
 [ debugfile5cache
        BEQ     %FT01
        DLINE   "special ",cc
01
 ]
        BNE     %FT05

        ; match
        TEQ     r1, #NULL
        BLNE    strlen
        ADDNE   r9, r1, r3
        ADDNE   r9, r9, #1
        LDR     r9, OsFile5Cache
        LDMIA   r9, {r0,r2-r5}             ; pick up old info
 [ debugfile5cache
        DLINE   "hit"
 ]
        B       %FT15

02
        ; partition filing system - compare scbs
        ADD     r9, r9, #3              ; up to word boundary
        BIC     r9, r9, #3
        LDR     lr, [r9], #4
        TEQ     lr, r6                  ; compare scbs
 [ debugfile5cache
        BEQ     %FT01
        DLINE   "special(scb) ",cc
01
 ]
        LDREQ   r9, OsFile5Cache
        LDMEQIA r9, {r0,r2-r5}
 [ debugfile5cache
        BNE     %FT01
        DLINE   "hit"
01
 ]
        BEQ     %FT15

05
 [ debugfile5cache
        DLINE   "miss"
 ]
        ; Old stuff present, but a mismatch
        LDR     r2, OsFile5Cache
        MOV     lr, #Nowt
        STR     lr, OsFile5Cache
        BL      SFreeArea
        EXIT    VS

        ; construct new block
        MOV     r3, #5*4+4+4+1          ; info, fscb, time and 1 for the tail's terminator
        LDRB    lr, [fscb, #fscb_info]
        TEQ     lr, #0
        ADDEQ   r3, r3, #3+4            ; special is a word
        ADDNE   r3, r3, #1+1
        MOVNES  r1, r6                  ; special is a string
        BLNE    strlen_accumulate
        LDR     r1, [sp, #1*4]          ; reread tail
        BL      strlen_accumulate
        BL      SGetArea
        EXIT    VS
        BEQ     %FT09                   ; Didn't get the cache

        STR     r2, OsFile5Cache

        MOV     lr, #Nowt
        STR     lr, [r2, #5*4]          ; store fscb as Nowt before info available
        SWI     OS_ReadMonotonicTime
        EXIT    VS
        ADD     r0, r0, #200            ; 2 seconds of cache time
        STR     r0, [r2, #6*4]
        ADD     r1, r2, #7*4
        LDR     r2, [sp, #1*4]
        BL      strcpy_advance          ; copy name
        ADD     r1, r1, #1
        LDRB    lr, [fscb, #fscb_info]  ; copy special
        TEQ     lr, #0
        ADDEQ   r1, r1, #3
        BICEQ   r1, r1, #3
        STREQ   r6, [r1]
        BEQ     %FT09

        MOVS    r2, r6
        STREQB  r2, [r1]                ; no special
        MOVNE   lr, #&ff
        STRNEB  lr, [r1], #1
        BLNE    strcpy

09
        LDR     r1, [sp, #1*4]
        MOV     r0, #fsfile_ReadInfo

10
        TEQ     r0, #fsfile_Save
        TEQNE   r0, #fsfile_WriteInfo
        TEQNE   r0, #fsfile_WriteLoad
        TEQNE   r0, #fsfile_WriteExec
        TEQNE   r0, #fsfile_WriteAttr
        TEQNE   r0, #fsfile_Delete
        TEQNE   r0, #fsfile_Create
        TEQNE   r0, #fsfile_CreateDir
        BLEQ    BangFile5Cache
 ]

        CMP     r0, #fsfile_Save        ; Save in case of monitor info
        CMPNE   r0, #fsfile_Create
        ADREQ   r14, fileblock_base
        STMEQIA r14, {r2-r5}

        BL      CheckNullName           ; Reject null names unless fscb^.nullok
        EXIT    VS                      ; Also checks fscb^ valid

        LDRB    r14, [fscb, #fscb_opt1] ; Entered from below, r0-r6, fscb valid
        STRB    r14, lowfile_opt1       ; Remember OPT 1 state for after op

        TEQ     r0, #fsfile_Load        ; Must only load at r2 at this level
        MOVEQ   r3, #0                  ; Use r2 please ! Much depends on this

; Enter Filing System with :
;    r0 = file op
;    r1 -> filename
;    r2 = load addr
;    r3 = exec addr
;    r4 = data start
;    r5 = data end / file attributes
;    r6 -> special field (if present) or 0
;   r12 -> module workspace

        TEQ     r0, #fsfile_Load        ; These are the only two that
        TEQNE   r0, #fsfile_ReadInfo    ; don't modify file structure or info !
        TEQNE   r0, #fsfile_ReadInfoNoLen
        TEQNE   r0, #fsfile_ReadBlockSize
        MOVNE   r9, r0
        BLNE    DoUpCallModifyingFile

        ; Sort out the special field as late as possible - only enter 'client land' late
        BL      SortSpecialForFSEntry
        EXIT    VS

 [ debuglowfile
 DREG r0,"FSFile: calling rc ",cc,Byte
 DREG fscb,", fscb=",cc
 TEQ r0,#fsfile_ReadInfo
 BEQ %FT05
 DREG r2,", parms ",cc
 DREG r3,,cc
 TEQ r0,#fsfile_Load
 BEQ %FT05
 DREG r4,,cc
 DREG r5
05
 DSTRING r6,", special ",cc
 DSTRING r1,", filename "
 ]
        MOV     r8, #fscb_file
        BL      CallFSEntryChecked

; Filing System returns with :
;    r0 = object type
;    r2 = load addr
;    r3 = exec addr
;    r4 = length
;    r5 = file attributes
;    r6 -> unwildcarded filename of low lifetime - copy away immediately
;         so that spooling etc. don't kill it

 [ debuglowfile
 BVS %FT42
 DREG r0,"FSFile: returned type ",cc
 DREG r2,", info ",cc
 DREG r3,,cc
 DREG r4,,cc
 DREG r5
 B %FT45
42
 DLINE "Error in FSFile"
45
 ]
        ADD     fscb, sp, #4*(10-0)       ; Restore fp, wp in all cases
        LDMIA   fscb, {fscb, fp, wp}

        LDR     r1, [sp, #4*(1-0)]
        BL      SortSpecialForFSExit
 [ debuglowfile
        DSTRING r1, "Tail restored to "
 ]

        BLVS    CopyErrorExternal
        EXIT    VS

 [ osfile5cache
        ; Cache the info
        LDRB    lr, [sp]
        TEQ     lr, #fsfile_ReadInfo
        BNE     %FT14
        LDR     lr, OsFile5Cache
        TEQ     lr, #Nowt
        STMNEIA lr, {r0,r2-r5,fscb}
14
 ]

15
; Only Load/ReadInfo/Delete return object type (cat info returned to fileblock)

        LDRB    r1, [sp]                ; What was the op ?
        TEQ     r1, #fsfile_Load
        TEQNE   r1, #fsfile_ReadInfo
        TEQNE   r1, #fsfile_Delete
        TEQNE   r1, #fsfile_ReadInfoNoLen
        TEQNE   r1, #fsfile_ReadBlockSize
        STREQ   r0, [sp]                ; Update object type
        ADREQ   r14, fileblock_base     ; Update object info
        STMEQIA r14, {r2-r5}
 [ debugframe
 BNE %FT00
 DREG r14, "Thinks fileblock_base at "
00
 ]


; Only Load/Save/Create give monitor messages from OPT 1

        LDRB    r7, lowfile_opt1        ; Nothing to do if OPT 1, 0
        CMP     r7, #0
        EXIT    EQ                      ; VClear

        CMP     r1, #fsfile_Save        ; Print data that was used in save
        CMPNE   r1, #fsfile_Create      ; or create, not what comes back
        ADREQ   r14, fileblock_base
        LDMEQIA r14, {r2-r5}            ; Get original parms in r2-r5
        SUBEQ   r4, r5, r4              ; Form length, you dead grey elf pillok
        CMPNE   r1, #fsfile_Load        ; Order !
        EXIT    NE                      ; VClear


; Must copy name away in case of reentrancy (very low lifetime object anyway)

        Push    "r2, r3"
        ADR     r0, OptFilenameString
        MOV     r1, r6
        BL      SGetLinkedString_excludingspaces ; Stop on CtrlChar/space
        Pull    "r2, r3"                        ; >>>a186<<<
        EXIT    VS

; Always print name. r1 -> copy of filename. r7 = OPT 1 value

        MOV     r8, #0                  ; Print name in field of 10
20      LDRB    r0, [r1], #1
        CMP     r0, #0                  ; Now zero terminated
        ADDNE   r8, r8, #1              ; Another one bites the dust
        SWINE   XOS_WriteC              ; WriteC preserves Z
        BVS     %FT95
        BNE     %BT20                   ; Loop over all of name

; OPT 1, 2 or higher ?

        CMP     r7, #1                  ; OPT 1,1 -> just filename, no trailers
        BEQ     %FT85


; Must now pad out in field of 10, 'cos here comes the info

26      CMP     r8, #10                 ; Must allow for name overflowing !
        ADDLO   r8, r8, #1              ; Finished spacing yet ?
        SWILO   XOS_WriteI+space
        BVS     %FT95
        BLO     %BT26

27      SWIVC   XOS_WriteI+space        ; Two spaces please in any case
        SWIVC   XOS_WriteI+space
        BVS     %FT95


        CMP     r7, #2                  ; OPT 1, 2 -> Hex Load/Exec/Length
        BNE     %FT50                   ; OPT 1, 4 and above identical to 3

30      MOV     r0, r2                  ; Load address in hex. Entry from below
        BL      HexR0LongWord
        SWIVC   XOS_WriteI+space

        MOVVC   r0, r3                  ; Exec address in hex
        BLVC    HexR0LongWord
        B       %FT80                   ; Print the length as well


50 ; Interpret the load and exec addresses suitably

        CMP     r2, r3                  ; Load = exec -> BBC utility
        BEQ     %BT30
        CMN     r2, #&000100000         ; Undated ones are given in hex
        BCC     %BT30

        Push    "r2, r3"
        MOV     r2, r2, LSR #8          ; File type in bottom 12 bits
        BL      DecodeFileType
        MOV     r0, r2
        BL      PrintR0Chars
        MOVVC   r0, r3
        BLVC    PrintR0Chars
        Pull    "r2, r3"

        SUB     sp, sp, #64
        SWIVC   XOS_WriteI+space
        MOVVC   r0, sp
        STRVC   r3, [sp]
        STRVCB  r2, [sp, #4]
        ADDVC   r1, sp, #8              ; rv^
        MOVVC   r2, #64-8
        SWIVC   XOS_ConvertStandardDateAndTime
        ADDVC   r0, sp, #8
        SWIVC   XOS_Write0
        ADD     sp, sp, #64

; Exit for OPT 1, 2 and above - print a space, then the length

80      SWIVC   XOS_WriteI+space
        MOVVC   r0, r4                  ; Length in hex
        BLVC    HexR0LongWord


; Exit for OPT 1, 1

85      SWIVC   XOS_NewLine             ; Tidy up the output line

95      BLVS    CopyErrorExternal

        ADR     r0, OptFilenameString   ; Always deallocate string
        BL      SFreeLinkedArea
        EXIT

        LTORG

 [ osfile5cache
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; BangFile5Cache
;

BangFile5Cache Entry "r2"
        LDR     r2, OsFile5Cache
        MOV     lr, #Nowt
        STR     lr, OsFile5Cache
        BL      SFreeArea
        EXIT            ; Don't think we need to preserve, but SFreeArea does
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SortSpecialForFSEntry
;
; Sorts out special field->NULL for nul strings and scb^ in r6 -> MultiFS handle
;
; In    r1 = pointer to path tail
;       r6 = special field/scb^
;       fscb^
;
; Out   r6 = NULL if special field was nul, or MultiFS handle to access the contents
;       r1 string has $. stripped if appropriate
;       VS if FS can't handle special fields
;
DuffFSTable
        ; Table of 'duff' filing systems which need special forms of filenames

        ; This is the long list of them:
;fsnumber_tape1200       # 1     ;   1                   Not supported
;fsnumber_tape300        # 1     ;   2                   Not supported
;fsnumber_rom            # 1     ;   3 Rom:              Acorn
;fsnumber_telesoft       # 1     ;   6                   Not supported
;fsnumber_IEEE           # 1     ;   7                   Not supported
;fsnumber_reserved       # 1     ;   9                   Reserved for compatability with the BBC world
;fsnumber_vfs            # 1     ;  10                   Not supported
;fsnumber_acacia_ramfs   # 1     ;  16
;fsnumber_cc_rfs         # 1     ;  22 rfs:              Computer Concepts ROM board
;fsnumber_RISCiXFS       # 1     ;  24 RISCiXFS:         Acorn
;fsnumber_digitape       # 1     ;  25 DigiTape:         Digital Services Tape Streamer
;fsnumber_TVFS           # 1     ;  27 TVFS:             Mike Harrison's digitiser filing system
;fsnumber_ScanFS         # 1     ;  28 ScanFS:           Mike Harrison's scanner (Watford)
;fsnumber_Fax            # 1     ;  30 fax:              Computer Concepts Fax Pack
;fsnumber_Z88            # 1     ;  31 Z88:              Colton Software Z88 filing system
;fsnumber_SCSIDeskFS     # 1     ;  32 SCSIDeskFS:       John Balance Software
;fsnumber_Serial2        # 1     ;  34 Serial2:          The Soft Option
;fsnumber_DFSDeskFS      # 1     ;  35 DFSDeskFS:        PRES
;fsnumber_dayibmfs       # 1     ;  36 DayIBMFS:         Daylight Software IBM filing system
;fsnumber_RISCardfs      # 1     ;  38 pc:               Computer Concepts
;fsnumber_pcfs           # 1     ;  39 pcfs:             Computer Concepts
;fsnumber_BBScanFS       # 1     ;  40 BBScanFS:         Beebug
;fsnumber_loader         # 1     ;  41 BroadcastLoaderUtils: Acorn & Digital Services broadcast loader
;fsnumber_chunkfs        # 1     ;  42 chunkfs:          Computer Concepts
;fsnumber_MSDOSFS        # 1     ;  43 MSDOS:            MultiFS, Minerva, Public
;fsnumber_NoRiscFS       # 1     ;  44 NoRiscFS:         Minerva
;fsnumber_NexusFilerFS   # 1     ;  48 NexusFilerFS:     SJ Research
;fsnumber_IDEFS          # 1     ;  49 IDEFS:            Sefan Fr�hling
;fsnumber_CCPrintFS      # 1     ;  50 PrintFS:          Computer Concepts
;fsnumber_BrainsoftVFS   # 1     ;  51 VideoDigitiserFS: Brainsoft
;fsnumber_BrainsoftSFS   # 1     ;  52 SoundDigitiserFS: Brainsoft
;fsnumber_VCMNetFS       # 1     ;  55 Vcmn:             VCM-Net, David Miller
;fsnumber_ArcFS          # 1     ;  56 ArcFS:            M. Smith
;fsnumber_NexusPrintFS   # 1     ;  57 NexusPrintFS:     Tony Engeham, SJ Research
;fsnumber_AtomWide       # 1     ;  58 PIA:              Martin Coulson, Atomwide
;fsnumber_RSDosFS        # 1     ;  59 rsdos:            Rob Schrauwen, via CS
;fsnumber_SimtrondbFS    # 1     ;  60 dbFS:             Simon Wright, Simtron

;fsnumber_MenonFS        * &79   ;  121
;                          &80   ;  128 SPSTFS:          Snapshot by Lingenuity's filing system

        ; This is the concise table:



        ;               18      10      08      00
        DCD     2_11011011010000110000111011001110      ;00
        DCD     2_00011111100111110001111111011100      ;20
        DCD     2_00000000000000000000000000000000      ;40
        DCD     2_00000010000000000000000000000000      ;60
        DCD     2_00000000000000000000000000000001      ;80
        DCD     2_00000000000000000000000000000000      ;a0
        DCD     2_00000000000000000000000000000000      ;c0
        DCD     2_00000000000000000000000000000000      ;e0

SortSpecialForFSEntry EntryS "r1,r2"
 [ debuglowspecial
        DREG    r6, "Sorting special field = "
 ]
        ; Check for the MultiFS case
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        BNE     %FT05

        ; Image FS calling...
        LDR     r14, [r6, #:INDEX:scb_status]
        TST     r14, #scb_partitionbad
        addr    r0, ErrorBlock_PartitionBusy, NE
        BLNE    CopyError

        LDRVC   r6, [r6, #:INDEX:scb_ifsHandle]

        EXIT

05

        ; Convert Nowt, NULL or "" to NULL
        TEQ     r6, #NULL
        TEQNE   r6, #Nowt
        LDRNEB  r14, [r6]
        TEQNE   r14, #0
        MOVEQ   r6, #NULL
        BEQ     %FT10

 [ debuglowspecial
        DSTRING r6, "Special == string "
 ]

        ; Check if special actually present that filing system groks this
        LDR     r14, [fscb, #fscb_info]
        TST     r14, #fsinfo_special
        BLEQ    SetMagicFSNotSpecial
        EXIT    VS

10
        ; Special now sorted out - now check for $.-stripping
        LDR     r14, [fscb, #fscb_info]
        TST     r14, #fsinfo_handlesurdetc
        EXITS   NE

        ; Check if FS is duff
        AND     r14, r14, #&ff
 [ debugdollarstrip
        BREG    r14, "FS#:",cc
 ]
        ADR     r2, DuffFSTable
        LDRB    r2, [r2, r14, LSR #3]
 [ debugdollarstrip
        BREG    r2, " mask byte:",cc
 ]
        AND     r14, r14, #7
        MOV     r2, r2, LSR r14
 [ debugdollarstrip
        BREG    r2, " shifted:"
 ]
        TST     r2, #1
        EXITS   EQ

        ; FS is duff - check PassedFilename for absence of $
        LDR     r2, PassedFilename
 [ debugdollarstrip
        DSTRING r2,"Filing system is duff, checking for $s:"
 ]
        LDRB    lr, [r2], #1
40
        LDRB    lr, [r2], #1
        TEQ     lr, #"$"
        EXITS   EQ
        TEQ     lr, #0
        BNE     %BT40

        ; $-Strip now on
 [ debugdollarstrip
        DSTRING r1,"$-strip ",cc
 ]

        ; safe to $.-strip now
60
        LDRB    lr, [r1], #1
        TEQ     lr, #0
 [ debugdollarstrip
        BNE     %FT01
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
01
 ]
        EXITS   EQ
        TEQ     lr, #"$"
        BNE     %BT60

        LDRB    lr, [r1]
        TEQ     lr, #"."
        BNE     %FT80

        ; there's $. here - strip it!
70
        LDRB    lr, [r1, #1]!
        STRB    lr, [r1, #-2]
        TEQ     lr, #0
        BNE     %BT70

 [ debugdollarstrip
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
 ]
        EXITS

80
        ; there's $<something other than .> here, check for .$
        SUB     r1, r1, #2      ; point to char before the $
        LDR     lr, [sp, #Proc_RegOffset + 0*4]
        CMP     r1, lr          ; HS if not before start of string
        LDRHSB  lr, [r1]
        CMPHS   lr, #"."        ; EQ if char before $ is a .
        MOVEQ   lr, #0
        STREQB  lr, [r1]        ; truncate here as .$<anything other than . or \0> is a bug

 [ debugdollarstrip
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
 ]
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SortSpecialForFSExit
;
; Re-inserts $.
;
; In    r1 = pointer to path tail
;       fscb^
;
; Out   r1 string has $. stripped if appropriate
;
SortSpecialForFSExit EntryS "r1,r2,r3"

        LDR     lr, [fscb, #fscb_info]
        TST     lr, #&ff
        EXIT    EQ
        TST     lr, #fsinfo_handlesurdetc
        EXIT    NE

        ; Check if FS is duff
        AND     r14, r14, #&ff
        ADR     r2, DuffFSTable
        LDRB    r2, [r2, r14, LSR #3]
        AND     r14, r14, #7
        MOVS    r2, r2, LSR r14
        TST     r2, #1
        EXITS   EQ

        ; FS is duff - check PassedFilename for presence of $
        LDR     r2, PassedFilename
05
        LDRB    lr, [r2], #1
        TEQ     lr, #"$"
        EXITS   EQ
        TEQ     lr, #0
        BNE     %BT05

 [ debugdollarstrip
        DSTRING r1,"$-insert ",cc
 ]

        ; $.-stripping may have happened
        LDRB    lr, [r1]
        TEQ     lr, #":"
        BEQ     %FT10

        TEQ     lr, #"$"
        BNE     %FT20
 [ debugdollarstrip
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
 ]
        EXITS

10
        LDRB    lr, [r1, #1]!
        TEQ     lr, #0
        BEQ     %FT50
        TEQ     lr, #"."
        BNE     %BT10

        ADD     r1, r1, #1
20
        ; Insert a $. before the point pointed to by r1
        LDRB    r2, [r1, #0]
        LDRB    r3, [r1, #1]
        MOV     lr, #"$"
        STRB    lr, [r1, #0]
        MOV     lr, #"."
        STRB    lr, [r1, #1]!

        TEQ     r2, #0
        TEQNE   r3, #0
        B       %FT40
30
        LDRB    lr, [r1, #1]!
        STRB    r2, [r1, #0]
        MOV     r2, r3
        MOV     r3, lr
        TEQ     r3, #0
40
        BNE     %BT30

        STRB    r2, [r1, #1]
        TEQ     r2, #0
        STRNEB  r3, [r1, #2]

 [ debugdollarstrip
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
 ]
        EXITS

50
        ; Append .$ to the string
        MOV     lr, #"."
        STRB    lr, [r1], #1
        MOV     lr, #"$"
        STRB    lr, [r1], #1
        MOV     lr, #0
        STRB    lr, [r1]

 [ debugdollarstrip
        LDR     r1, [sp, #Proc_RegOffset]
        DSTRING r1,"->"
 ]
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSFunc_Given
; ================
;
; Lots of miscellaneous Filing System functions

; In    r0 reason code, various parms

; Out   VC: ok, r0-r5 may (or may not) be modified, but don't trust 'em
;       VS: fail

CallFSFunc_Given Entry "r6-r12", 8 ; Never (ever) trust lower level routines

 [ debuglowfunc
 DREG r0,"FSFunc: rc ",cc
 DREG r1," arg ",cc
 DREG r2," arg2 ",cc
 DREG r6,", ifsHandle/special ",cc
 DSTRING r6
 ]
; Enter Filing System with :
;    r0 = reason code
;    r1 = arg1 .. r5 = arg5
;    r6 -> special field (if present) or 0
;    r7 -> second special field (if present) or 0 for rename
;   r12 -> module workspace

 [ osfile5cache
        TEQ     r0, #fsfunc_Rename
        TEQNE   r0, #fsfunc_Access
        BLEQ    BangFile5Cache
 ]

        CMP     r0, #fsfunc_Access
        ORREQ   r9, r0, #&200
        BLEQ    DoUpCallModifyingFile

        CMP     r0, #fsfunc_Rename
        MOVNE   lr, #0
        STRNE   lr, [sp, #4]
        BNE     %FT30

        ; Rename processing

        ; Check both names are OK
        Push    r1
        MOV     r1, r2
        BL      CheckNullName
        Pull    r1
        BLVC    CheckNullName
        EXIT    VS

        ORR     r9, r0, #&200           ; fsfunc operation :OR: a bit (2xx)
        BL      DoUpCallModifyingFile

        Push    "r1,r6"
        MOV     r1, r2
        MOV     r6, r7
        BL      SortSpecialForFSEntry
        MOV     r7, r6
        MOV     r2, r1
        Pull    "r1,r6"
        EXIT    VS
        STR     r2, [sp, #4]

30
        ; Only sort out special on those funcs which need it
        TEQ     r0, #fsfunc_Opt
        TEQNE   r0, #fsfunc_Bootup
        TEQNE   r0, #fsfunc_ReadDiscName
        TEQNE   r0, #fsfunc_ReadCSDName
        TEQNE   r0, #fsfunc_ReadLIBName
        TEQNE   r0, #fsfunc_ShutDown
        TEQNE   r0, #fsfunc_PrintBanner
        TEQNE   r0, #fsfunc_SetContexts
        TEQNE   r0, #fsfunc_NewImage
        TEQNE   r0, #fsfunc_ImageClosing
        TEQNE   r0, #fsfunc_CanonicaliseSpecialAndDisc
        BLNE    SortSpecialForFSEntry
        EXIT    VS
        STRNE   r1, [sp, #0]
        MOVEQ   lr, #0
        STREQ   lr, [sp, #0]

        ; Check CanonicaliseSpecialAndDisc not being called out of order
        TEQ     r0, #fsfunc_CanonicaliseSpecialAndDisc
        BNE     %FT40

        TEQ     r1, #0
        BEQ     %FT40

        LDR     r14, [fscb, #fscb_info]
        TST     r14, #fsinfo_special
        BLEQ    SetMagicFSNotSpecial
        EXIT    VS

40
        ; Do it
        MOV     r8, #fscb_func
        BL      CallFSWithCheck

        ADD     fscb, sp, #4*(10-6) + Proc_LocalStack
        LDMIA   fscb, {fscb, fp, wp}

        Push    "r1"
        LDR     r1, [sp, #0 + 1*4]
        TEQ     r1, #0
        BLNE    SortSpecialForFSExit
        LDR     r1, [sp, #4 + 1*4]
        TEQ     r1, #0
        BLNE    SortSpecialForFSExit
        Pull    "r1"

 [ debuglowfunc
 EXIT VC
 DLINE "Error in FSFunc"
 ]
        BLVS    CopyErrorExternal
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSOpen
; ==========
;
; Try to open the file pointed to by r1 in mode r0.

; In    r0 =  &40: open for read
;             &80: create and open for update
;             &C0: open for update
;       r1 -> filename, 0
;       r3 =  FileSwitch handle allocated to the embryo stream
;       r6 = Pointer to special field or file handle as appropriate
;       fscb set for the file to open

; NB. r0 = 0 is NOT a valid parm for CallFSOpen ! Use CallFSClose instead

; Out   VC: r0  = bits 7..0 = Filing System number, bits 29..8 = FS device
;                 (normally ALL zero - only need this in the fuschia !)
;                 bits 31, 30, 29 = write/read/dir attributes of file
;           r1 <> 0: 32 bit Filing System handle. NB. not r0 !!!
;                 0: not found
;           r2  = buffer chunk size to use with this file. 0 -> unbuffered
;           r3  = file extent (for buffered files only)
;           r4  = initial allocated size on disc (for buffered files only)
;                                                 (for writeable files only)
;       VS: fail. handle = 0

CallFSOpen Entry "r5-r12" ; Never (ever) trust lowel level routines

 [ debuglowosfind
 DSTRING r1,"FSOpen file in is "
 ]

        BL      CheckNullName           ; Reject null names unless fscb^.nullok
        EXIT    VS                      ; Also checks fscb^ valid

 [ osfile5cache
        TEQ     r0, #fsopen_CreateUpdate
        TEQNE   r0, #fsopen_Update
        BLEQ    BangFile5Cache
 ]

        MOV     r0, r0, LSR #(8-2)      ; 0 -> 0, &C0 -> 3. Get RC and shift
        SUB     r0, r0, #1              ; Open mode in 0..2 now
        MOV     r2, r3                  ; Put handle where File System expects

        TEQ     r0, #fsopen_CreateUpdate
        TEQNE   r0, #fsopen_Update
        ORREQ   r9, r0, #&100           ; fsopen operation :OR: a bit(100..102)
        BLEQ    DoUpCallModifyingFile

        BL      SortSpecialForFSEntry
        EXIT    VS
        Push    "r1"


; Enter Filing System with :
;    r0 =  file open mode 0..2 (old) or 3 (new)
;    r1 -> filename
;    r2 = FileSwitch handle for this proto-stream
;    r6 -> special field (if present) or 0
;   r12 -> module workspace


 [ debuglowosfind
 DREG r0,"FSOpen: rc ",cc
 DREG r2,", FileSwitch handle ",cc
 DSTRING r6,", special ",cc
 DSTRING r1,", filename ",cc
 DREG r1, " at "
 ]
        MOV     r8, #fscb_open
        BL      CallFSEntryChecked

 [ debuglowosfind
 BVS %FT90
 DREG r1,"FSOpen: handle ",cc
 TEQ r1,#0
 BEQ %FT42
 DREG r2,", buffer size to use ",cc
 DREG r3,", file extent is ",cc
 DREG r4,", allocated space is ",cc
 AND r14,r0,#fsopen_DeviceIdentity
 DREG r14,", fs/dev ",cc
 DLINE ", attr ",cc
 TST r0,#fsopen_WritePermission
 BNE %FT01
 DLINE "w",cc
 B %FT02
01
 DLINE "W",cc
02
 TST r0,#fsopen_ReadPermission
 BNE %FT01
 DLINE "r",cc
 B %FT02
01
 DLINE "R",cc
02
 TST r0,#fsopen_IsDirectory
 BNE %FT01
 DLINE "d",cc
 B %FT02
01
 DLINE "D",cc
02
 TST r0,#fsopen_UnbufferedGBPB
 BNE %FT01
 DLINE "g",cc
 B %FT02
01
 DLINE "G",cc
02
42
 DLINE ""
 B %FT95
90
 DLINE "Error in FSOpen"
95
 ]
        Pull    "lr"

        ADD     fscb, sp, #4*(10-5)
        LDMIA   fscb, {fscb, fp, wp}

        Push    "r1"
        MOV     r1, lr
 [ debuglowosfind
        DREG    r1, "Tail out at ",cc
        DSTRING r1, " is "
        DREG    fscb, "fscb out is "
 ]
        BL      SortSpecialForFSExit
 [ debuglowosfind
        DSTRING r1, "Tail restored to "
 ]
        Pull    "r1"

        BLVS    CopyErrorExternal
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Some more macros to stop nasty reentrancy problems

        MACRO
        MakeCritical
        LDR     r14, scb_status
        ORR     r14, r14, #scb_critical
        STR     r14, scb_status
        MEND

        MACRO
        ClearCritical
        LDR     r14, scb_status
        BIC     r14, r14, #scb_critical
        STR     r14, scb_status
        MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSBGet
; ==========
;
; Get a byte from an unbuffered stream

; In    scb^ valid

; Out   VC: ok, r0 = char and flags as set by Filing System
;       VS: fail

CallFSBGet_Guts Entry "r1-r12" ; Never (ever) trust lower level routines

        MOV     r8, #fscb_get
        BL      CallFSCommon

        ADDVS   fp, sp, #4*(11-1)
        LDMVSIA fp, {fp, wp}
        BLVS    CopyErrorExternal
        EXIT

; .............................................................................

CallFSBGet Entry

        MakeCritical
        BL      CallFSBGet_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSGetBuffer
; ===============
;
; Ask Filing System to get me a new buffer of data

; In    scb^, bufmask and bcb^ valid

; Out   VC: ok
;       VS: fail

CallFSGetBuffer_Guts Entry "r0-r12" ; Never (ever) trust lower level routines

        ADR     r2, bcb_bufferdata      ; Memory to be loaded
        ADD     r3, bufmask, #1         ; Correct size to use
        LDR     r4, bcb_bufferbase

 [ debuglowxfer
 DREG r2,"CallFSGetBuffer: to ",cc
 DREG r3,", ",cc
 DREG r4," bytes <- from PTR# "
 ]

10 ; Entered from below too

; Enter Filing System with :
;    r1 = Filing System handle
;    r2 = memory address
;    r3 = number of bytes to read (guaranteed to be a multiple of bufsize)
;    r4 = file address
;   r12 -> module workspace

        MOV     r8, #fscb_get
        BL      CallFSCommon

 [ debuglowxfer
 DLINE  "LowXFer achieved"
 ]
 [ debugosgbpbirq
 Push "r0, lr"
 MOV r0, psr
 TST r0, #I_bit
 MOVEQ r0, #"1"
 MOVNE r0, #"a"
 SWI XOS_WriteC
 Pull "r0, lr"
 ]
        EXIT    VC

        ADD     fp, sp, #4*(11-0)
        LDMIA   fp, {fp, wp}
        BL      CopyErrorExternal
        EXIT

; .............................................................................
;
; CallFSGetData
; =============
;
; Ask Filing System to get data for the punter

; In    scb^ valid
;       r2 -> destination
;       r3 = number of bytes
;       r4 = file address

; Out   VC: ok
;       VS: fail

CallFSGetData_Guts ALTENTRY

 [ debuglowxfer
 DREG r2,"CallFSGetData: to ",cc
 DREG r3,", ",cc
 DREG r4," bytes <- from PTR# "
 ]
        B       %BT10

; .............................................................................

CallFSGetBuffer Entry

        MakeCritical
        BL      CallFSGetBuffer_Guts
        ClearCritical
 [ debugosgbpbirq
 Push "r0, lr"
 MOV r0, psr
 TST r0, #I_bit
 MOVEQ r0, #"2"
 MOVNE r0, #"b"
 SWI XOS_WriteC
 Pull "r0, lr"
 ]
        EXIT

; .............................................................................

CallFSGetData Entry

        MakeCritical
        BL      CallFSGetData_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSBPut
; ==========
;
; Put a byte to an unbuffered stream

; In    r0b = byte to put, scb^ valid

; Out   VC: ok
;       VS: fail

CallFSBPut_Guts Entry "r0-r12" ; Never (ever) trust lower level routines

        AND     r0, r0, #&FF            ; Just in case people don't like it
        MOV     r2, #-1                 ; Doing BPut not Multiple
        MOV     r8, #fscb_put
        BL      CallFSCommon

        ADDVS   fp, sp, #4*(11-0)
        LDMVSIA fp, {fp, wp}
        BLVS    CopyErrorExternal
        EXIT

; .............................................................................

CallFSBPut Entry

        MakeCritical
        BL      CallFSBPut_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSPutBuffer
; ===============
;
; Give Filing System a buffer of data

; May need to write under mask for Net W only files - to be sussed at leisure !

; In    scb^, bufmask and bcb^ valid

; Out   VC: ok
;       VS: fail

CallFSPutBuffer_Guts Entry "r0-r12" ; Never (ever) trust lower level routines

        ADR     r2, bcb_bufferdata      ; Memory to be loaded
        ADD     r3, bufmask, #1         ; Correct size to use
        LDR     r4, bcb_bufferbase

 [ debuglowxfer
 DREG r2,"CallFSPutBuffer: from ",cc
 DREG r3,", ",cc
 DREG r4," bytes -> to PTR# "
 ]

10 ; Entered from below too

; Enter Filing System with :
;    r1 = Filing System handle
;    r2 = memory address
;    r3 = number of bytes to read (guaranteed to be a multiple of bufsize)
;    r4 = file address
;   r12 -> module workspace

        MOV     r8, #fscb_put
        BL      CallFSCommon
        EXIT    VC

        ADD     fp, sp, #4*(11-0)
        LDMIA   fp, {fp, wp}
        BL      CopyErrorExternal
        EXIT

; .............................................................................
;
; CallFSPutData
; =============
;
; Ask Filing System to save data for the punter

; In    scb^ valid
;       r2 -> source
;       r3 = number of bytes
;       r4 = file address

; Out   VC: ok
;       VS: fail

CallFSPutData_Guts ALTENTRY

 [ debuglowxfer
 DREG r2,"CallFSPutData: from ",cc
 DREG r3,", ",cc
 DREG r4," bytes -> to PTR# "
 ]
        B       %BT10

; .............................................................................

; Called from FlushBuffer/_2/_IfNoError
; Does not mark 'data lost' automatically on error - this is done higher up

CallFSPutBuffer Entry

        MakeCritical
        BL      CallFSPutBuffer_Guts
        ClearCritical

        EXIT

; .............................................................................

CallFSPutData Entry

        MakeCritical
        BL      CallFSPutData_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSMultiple
; ==============
;
; Get many / Put many bytes from / to an fast unbuffered stream

; In    scb^ valid
;       r0 = GBPB op
;       gbpb block = r2-r4 data

; Out   VC: ok, gbpb block updated here !!!
;       VS: fail

CallFSMultiple_Guts Entry "r0-r12" ; Never (ever) trust lower level routines

        ADR     r14, gbpb_memadr
        LDMIA   r14, {memadr, nbytes, fileptr}

 [ debuglowxfer
 DREG r2,"CallFSMultiple: from ",cc
 DREG r3,", ",cc
 DREG r4," bytes -> to PTR# "
 ]
        MOV     r8, #fscb_gbpb
        BL      CallFSCommon

        ADD     fp, sp, #4*(11-0)       ; Restore fp, wp in all cases
        LDMIA   fp, {fp, wp}

        ADRVC   r14, gbpb_memadr
        STMVCIA r14, {memadr, nbytes, fileptr}

        BLVS    CopyErrorExternal
        EXIT

; .............................................................................

CallFSMultiple Entry

        MakeCritical
        BL      CallFSMultiple_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSArgs
; ==========
;
; Lots of miscellaneous file control which require open streams

; In    r0 reason code, scb^ valid, various parms

; Out   VC: ok, r2 may be modified according to r0
;       VS: fail

CallFSArgs_Guts Entry "r0-r1, r3-r12" ; Never (ever) trust lower level routines

        TEQ     r0, #fsargs_EnsureSize
        BNE     %FT10
 [ osfile5cache
        BL      BangFile5Cache
 ]
        Push    "scb"                           ; r9
        MOV     r1, scb
        MOV     r9, #upfsargs_EnsureSize
        BL      DoUpCallModifyingFile
        Pull    "scb"                           ; r9

10
 [ debuglowosargs
 DREG r0,"FSArgs: rc ",cc
 DREG r2,", r2 ",cc
 DREG r3,", r3 ",cc
 ]
        MOV     r8, #fscb_args
        BL      CallFSCommon
 [ debuglowosargs
 DREG r2,"FSArgs: r2 := "
 ]

 [ debuglowosargs
 EXIT VC
 DLINE "Error in FSArgs"
 ]
        ADDVS   fp, sp, #4*(11-3+1-0+1)
        LDMVSIA fp, {fp, wp}
        BLVS    CopyErrorExternal
        EXIT

; .............................................................................

CallFSArgs Entry

        MakeCritical
        BL      CallFSArgs_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSClose
; ===========
;
; Close a given file on the Filing System

; In    scb^ valid
;       r2, r3 are load,exec pair to DateStamp stream with
;       Both zero -> don't set DateStamp

; Out   VC: ok
;       VS: fail

CallFSClose_Guts Entry "r0-r12" ; Never (ever) trust lower level routines

 [ debuglowosfind
 DREG r2, "FSClose called with r2=",cc
 DREG r3, ", r3="
 ]
 [ osfile5cache
        BL      BangFile5Cache
 ]

        LDR     r14, scb_status         ; Only tell punter about modified
        TST     r14, #scb_modified      ; files that are being closed
        BEQ     %FT10

        ; UpCall only if modified
        Push    "scb"                   ; r9
        MOV     r1, scb
        LDR     r9, =upfsclose
        BL      DoUpCallModifyingFile
        Pull    "scb"
10

        MOV     r8, #fscb_close
        BL      CallFSCommon

 [ debuglowosfind
 EXIT VC
 DLINE "Error in FSClose"
 ]
        ADDVS   fp, sp, #4*(11-0)
        LDMVSIA fp, {fp, wp}
        BLVS    CopyErrorExternal        ; Deallocation done always by hilevel
        EXIT

; .............................................................................

CallFSClose Entry

        MakeCritical
        BL      CallFSClose_Guts
        ClearCritical
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CallFSCommon
; ============
;
; For CallFSxxx that pass Filing System handles to the underlying Filing System

; In    scb^ to be checked, r8 = routine offset in scb^.fscb to call

; Out   r1, fscb and r12 definitely trashed

CallFSCommon ROUT

 [ False ; Who ever gets this far if scb invalid ???
        TEQ     scb, #Nowt              ; Paranoia !
        MOVEQS  pc, lr                  ; Skip op if no stream (VClear)
 ]

        ASSERT  scb_fscb = scb_fshandle + 4
        ADR     r1, scb_fshandle
        LDMIA   r1, {r1, fscb}          ; Get real FS handle and fscb^

; .............................................................................
;
; CallFSWithCheck
; ===============
;
; For CallFSxxx that don't use streams, eg. File, Open, Func

; In    fscb^ to be checked, r8 = routine offset in fscb to call

CallFSWithCheck

        TEQ     fscb, #Nowt                     ; Got a valid Filing System ?
        BEQ     Lowlevel_NoFilingSystemsActive  ; Nope !

; ............................................................................
;
; CallFSEntryChecked
; ==================
;
; For CallFSxxx that have already validated fscb^. Sets up r12 for modules too

; No checking of FS entries is needed as all routines have a default

; In    fscb^ valid, r8 = routine offset in fscb to be called

; Out   r12 definitely trashed, and as many others as the Filing System saw fit

CallFSEntryChecked

        MOV     r12, sp, LSR #20                ; Stack base on 1M boundary
        SUB     r12, sp, r12, LSL #20           ; Amount of stack left
        CMP     r12, #&400                      ; Must have at least 1K left
        BMI     Lowlevel_NotEnoughStackForFSEntry ; VClear in PSR

 [ debuglowfile :LAND: {FALSE}
        DLINE   "Pick up FS private word",cc
 ]
        LDR     r12, [fscb, #fscb_privwordptr]  ; Get their private word^
 [ debuglowfile :LAND: {FALSE}
        DLINE   " done"
        Push    "r0,r1"
        DREG    fscb,"Into F/S: fscb=",cc
        DREG    r8," r8=",cc
        DREG    r12, " r12=",cc
        LDR     r0, [fscb, #fscb_file]
        DREG    r0, " fscb_file=",cc
        LDR     r1,[r0]
        DREG    r1," fscb_file[0,1]=",cc
        LDR     r1,[r0,#4]
        DREG    r1," ",cc
        LDR     r0, [fscb, #fscb_link]
        DREG    r0, " fscb_link=",cc
        LDR     r0, [fscb, #fscb_modulebase]
        DREG    r0, " fscb_modulebase="
        Pull    "r0,r1"
 ]
 [ :LNOT: No26bitCode
        BIC     lr, lr, #V_bit :OR: I_bit       ; VClear, IClear in lr
 ]

 [ anyfiledebug :LAND: False
 DREG sp, "sp on entry to fs = "
 ]
        LDR     pc, [fscb, r8]                  ; So go for it !

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CheckNullName
; =============
;
; Common routine for CallFSFile, CallFSOpen and CallFSFunc to check null names

; In    r1 -> filename to pass to Filing System
;       fscb^ valid

; Out   VC: ok
;       VS: naff name (null)

CheckNullName Entry

        CMP     fscb, #Nowt             ; Must do a quick check here to
        BEQ     %FT90                   ; prevent ye olde address extinctions

        LDRB    r14, [r1]               ; Just look at first char of name !
        CMP     r14, #0                 ; Is it a null string ? - VClear
        LDREQ   r14, [fscb, #fscb_info] ; If so, does the Filing System
        TSTEQ   r14, #fsinfo_nullnameok ; support null filenames ?
        BLEQ    SetMagicBadFileName     ; Error if not. VSet too
        EXIT

90      BL      SetErrorNoSelectedFilingSystem
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DoUpCallModifyingFile
;
; In    r1..r7 dependant on reason
;       r9 = reason code
;       fscb
;
; Out   All registers preserved
;
; This expands filenames into sensible UpCallable values from their moderately useless
; MultiFS forms.

DoUpCallModifyingFile Entry "r0-r12"    ; Push *everything* to bullet-proof against UpCall clients

 [ debugupcall
 DREG   r9, "UpCall number "
 ]

        MOV     r8, sp          ; sp in

        ; Close or EnsureSize?
        LDR     lr, =upfsclose
        TEQ     r9, lr
        TEQNE   r9, #upfsargs_EnsureSize
        BEQ     %FT30

        LDR     lr, =upfsfunc_Rename
        TEQ     r9, lr
        BNE     %FT20

        ; Rename - construct 2nd name

 [ debugupcall
 DLINE  "Rename"
 ]

        MOV     r0, r1
        MOV     r1, r2
        Swap    r6, r7
        BL      %FT90           ; Convert path onto stack

        ; Set up 2nd path and restore 1st path's values
        MOV     r2, sp  ; path 2
 [ debugupcall
 DSTRING r4, "UpCall object 2:special=",cc
 DSTRING r2, " file="
 ]
        MOV     r6, r7  ; special 1
        MOV     r7, r4  ; Special 2
        MOV     r1, r0  ; path 1

20
 [ debugupcall
 DLINE  "Process one path"
 ]

        BL      %FT90           ; Convert path onto stack

        MOV     r1, sp          ; path 1
 [ debugupcall
 DSTRING r4, "UpCall object 1:special=",cc
 DSTRING r1, " file="
 ]
        MOV     r6, r4          ; special 1
        MOV     fscb, r5        ; fscb

        B       %FT80

30
 [ debugupcall
 DREG   r1, "Close/EnsureSize stream "
 ]
        Push    "r9"
        MOV     scb, r1
        LDR     r1, scb_exthandle
        LDR     r6, scb_special
        LDR     fscb, scb_fscb
        BL      fscbscbTofscb
        MOV     fscb, r2
 [ debugupcall
 DREG   fscb, "root fscb is "
 ]
        Pull    "r9"

80

        ; Pick up r2-r5 from input parameters as they've been trashed on way through
        ADD     r14, r8, #2*4
        LDMIA   r14, {r2-r5}

        Push    "r8"            ; real sad if this gets trashed by an UpCall client!
        MOV     r0, #UpCall_ModifyingFile
        LDR     r8, [fscb, #fscb_info]

 [ debugupcall
 DREG   r9, "UpCalling from FileSwitch: r9 = ",cc
 DREG   r8, ", r8 = "
 DREG   r1, "r1-r7=",cc
 DREG   r2, ",",cc
 DREG   r3, ",",cc
 DREG   r4, ",",cc
 DREG   r5, ",",cc
 DREG   r6, ",",cc
 DREG   r7, ","
 ]
        SWI     XOS_UpCall
        Pull    "r8"

85
        MOV     sp, r8
        EXIT

; Subroutine for above:
;
; In    r1 = path
;       r6 = special
;       fscb
;
; Out   r2,r3 trashed
;       r4 = special^ for root
;       r5 = fscb^ for root
;       r11 (fp) trashed
;       sp dropped to give frame for whole path, which is filled in
90
        MOV     r11, lr

        ; Work out length
        MOV     r2, #ARM_CC_Mask
        MOV     r3, #0
        BL      int_ConstructFullPathWithoutFSAndSpecial

        ; Get stack frame
        RSB     r3, r3, #1 + 3
        BIC     r3, r3, #3
        SUB     sp, sp, r3

        ; Construct the path
        MOV     r2, sp
        BL      int_ConstructFullPathWithoutFSAndSpecial

        MOV     pc, r11


; ++++ Keep all common/changeable stuff together away from sensitive ADRs +++++

 [ anyfiledebug
        InsertDebugRoutines
 ]

 [ debugstream
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    scb, status, fileptr, extent, bufmask ok

DebugStreamInfo Entry "r0, bcb"

 DREG scb,"Stream info: scb ",cc
 DLINE " status ",cc
 TST status, #scb_unallocated
; SWIEQ XOS_WriteI+"u"
 DWriteI u, EQ
; SWINE XOS_WriteI+"U"
 DWriteI U, NE
; SWINE XOS_NewLine
 DNewLine NE
 EXITS NE ; No more info
 TST status, #scb_write
; SWIEQ XOS_WriteI+"w"
 DWriteI w, EQ
; SWINE XOS_WriteI+"W"
 DWriteI W, NE
 TST status, #scb_read
; SWIEQ XOS_WriteI+"r"
 DWriteI r, EQ
; SWINE XOS_WriteI+"R"
 DWriteI R, NE
 TST status, #scb_directory
; SWIEQ XOS_WriteI+"d"
 DWriteI d, EQ
; SWINE XOS_WriteI+"D"
 DWriteI D, NE
 TST status, #scb_modified
; SWIEQ XOS_WriteI+"m"
 DWriteI m, EQ
; SWINE XOS_WriteI+"M"
 DWriteI M, NE
 TST status, #scb_interactive
; SWIEQ XOS_WriteI+"i"
 DWriteI i, EQ
; SWINE XOS_WriteI+"I"
 DWriteI I, NE
 TST status, #scb_EOF_pending
; SWIEQ XOS_WriteI+"e"
 DWriteI e, EQ
; SWINE XOS_WriteI+"E"
 DWriteI E, NE
 TST status, #scb_critical
; SWIEQ XOS_WriteI+"c"
 DWriteI c, EQ
; SWINE XOS_WriteI+"C"
 DWriteI C, NE
 TST status, #scb_unbuffered
 BEQ %FT10
 TST status, #scb_unbuffgbpb
; SWIEQ XOS_WriteI+"g"
 DWriteI g, EQ
; SWINE XOS_WriteI+"G"
 DWriteI G, NE
 DLINE " unbuffered "
 EXITS

10 ; buffered stream
 DREG fileptr," fileptr ",cc
 DREG extent," extent ",cc
 LDR r14,scb_allocsize
 DREG r14,", size "
 LDR bcb,scb_bcb ; may not have been loaded
 CMP bcb, #Nowt; Got first ptr
 ADREQ r0,%FT49
; SWIEQ XOS_Write0
 DWrite0 EQ
 BEQ %FT40
 LDR r0, bcb_bufferbase
 DREG r0,"Buffer on stream at ",cc
 LDRB r0, bcb_status
 TST r0, #bcb_modified
; SWIEQ XOS_WriteI+"m"
 DWriteI m, EQ
; SWINE XOS_WriteI+"M"
 DWriteI M, NE
 TST r0, #bcb_valid
; SWIEQ XOS_WriteI+"v"
 DWriteI v, EQ
; SWINE XOS_WriteI+"V"
 DWriteI V, NE
40
; SWI XOS_NewLine
 DNewLine
 EXITS

49
 DCB "No buffer on stream",0
 ALIGN
 ]

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This is the end, my friend

        END
