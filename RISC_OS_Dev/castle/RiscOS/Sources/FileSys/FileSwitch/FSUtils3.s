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
        SUBT    > Sources.FSUtils3 - Count + Common bits

 [ hascount
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                    W i l d c a r d   C o u n t a l l
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountEntry
; ==========

; In    r1 -> path to count
;       r3 = bitset for count
;       r4,r5 = optional time (start)
;       r6,r7 = optional time (end)

; Out   r2 = sizeof path counted
;       r3 = number of files counted

CountEntry NewSwiEntry "r0-r1, r4-r10",utils
                                        ; CountWildObject may destroy all regs
                                        ; Extra large frame used in util
 [ debugcount
        DLINE   "FSControl_Count: options '",cc
        TST     r3, #util_confirm
        BEQ     %FT01
        DLINE   "C", cc
01
        TST     r3, #util_recurse
        BEQ     %FT01
        DLINE   "R", cc
01
        TST     r3, #util_verbose
        BEQ     %FT01
        DLINE   "V"
01
        DREG r3,"' "
 ]
        BL      Util_CommonStart
        BVS     %FA99 ; SwiExit - nothing allocated
        MOV     r8, #0                  ; no second file

        BL      CountWildObject

        BL      Util_FreeFileStrings_R7 ; Catch errors from these on SwiExit
                                        ; 'Cos it's nice to print ...

        LDR     r14, util_bitset
        TST     r14, #util_printok
        BEQ     %FT95                   ; [skip printing]

        ADR     r1, fsw_files_counted
        BL      Util_FilesDone          ; Say '65 files counted, total 1234 bytes'

        BLVS    CopyErrorExternal
        BVS     %FT99
95
        ADR     r2, util_totalsize
        LDMIA   r2, {r2-r3}

        LDR     r14, util_bitset
        TST     r14, #util_userbuffer
        LDRNE   r14, [fp, #6 * 4]       ; Get r8in
        STMNEIA r14, {r2-r3}            ; Full 64 bit result if user supplies buffer

        TEQ     r3, #0                  ; When overflowed a 32 bit result at least guarantee
        MOVNE   r2, #&7FFFFFFF          ; some number that is 'lots' rather than modulo 4G bytes
        LDR     r3, util_nfiles
99
        SwiExit

fsw_files_counted
        DCB     "Cc4", 0        ; 0
        DCB     "Cc5", 0        ; 1
        DCB     "Cc6", 0        ; 2
        DCB     "Cc7", 0        ; Many
                  ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountWildObject
; ===============

; src * : CountObject on all that match
; src - : CountObject given name

; Out   Only r7, wp preserved

CountWildObject Entry

 [ debugcount
 DLINE "CountWildObject"
 ]
        LDR     r1, [r7, #copy_leafname] ; If not wild, do single count
        BL      Util_CheckWildName
        BNE     %FT90                   ; Single count

; ...................... Wild object spec for count ..........................

        MOV     r9, r1                  ; Remember current leafname

        MOV     r14, #0
        STR     r14, util_direntry      ; Start at the beginning of dir
        STR     r14, [r7, #copy_leafname] ; 'Free' leafname !

10 ; Loop over names, match against wildcard
   ; fullname explicitly made and freed

        BL      STestEscape             ; Util grade, not copied
        BLVS    CopyErrorExternal
        BLVC    Util_ReadDirEntry       ; Get a name. Uses + updates util_diren
        BVS     %FT60                   ; Put old leafname back, exit

        CMP     r3, #0                  ; No name xferred ?
        BEQ     %FT60                   ; Means eod

        ADR     r4, util_objectname     ; What we read just now
        STR     r4, [r7, #copy_leafname] ; Use as source leafname if matches
        BL      Util_TryMatch
        BNE     %BT10                   ; Loop - try another name

        MOV     r0, r7                  ; Create fullname of each object
        BL      Util_AppendLeafToDir    ; that matched wildcard

        Push    r9                      ; Preserve wild pattern round call
        BLVC    CountObject
        Pull    r9

        LDR     r2, [r7, #copy_name]    ; Deallocate new fullname always
        BL      SFreeArea               ; Accumulate V from Count/Free
        BVC     %BT10                   ; Loop - try another name

60      STR     r9, [r7, #copy_leafname] ; Put old leafname back
        EXIT


; .......... Single object count. Must read object info ourselves ..........

; NB. Don't call CountObject - if counting dir, just recurse one level unless
; punter wants more than that

90      MOV     r0, r7                  ; Create fullname of object
        BL      Util_AppendLeafToDir    ; from existing (non-wild) leafname
        EXIT    VS

        BL      Util_SingleObjectSetup  ; Error if not found
        BVS     %FT95                   ; Deallocate error
        LDR     lr, util_objecttype
        TEQ     lr, #object_directory
        BEQ     %FT96                   ; Is it a dir ?
        BL      CountFile               ; If it's a file or partition

95      LDR     r2, [r7, #copy_name]    ; Deallocate fullname
        BL      SFreeArea               ; Accumulate V from Count/Free
        EXIT


96      BL      CountDirectory
        B       %BT95

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountObject
; ===========
;
; Count object, recursing as necessary/required
; Dirname set up for this level
; Leafname already set up after possible wildcard match
; Fullname = dirname + leafname set up

; In    r7 = source file desc^

; Out   r0-r5 corrupted by calls
;       VC: object counted, skipped by user, date, or dir & ~recurse
;       VS: failed in count, or aborted

CountObject Entry

 [ debugcount
 DLINE "CountObject"
 ]
        LDR     r14, util_objecttype    ; What is it ?

        ; Partitions get treated as files
        TEQ     r14, #object_directory
        BEQ     %FT50

; Count existing file

        BL      CountFile
        EXIT


50 ; It's a directory. Are we recursing ?

        LDR     r14, util_bitset        ; Recurse set ?
        TST     r14, #util_recurse
        BEQ     %FT70

; Count this dir, recursing

        BL      CountDirectory          ; dir & recurse
        EXIT


70      TST     r14, #util_verbose      ; dir & ~recurse. No need to INC skippd
        EXIT    EQ

        addr    r2, fsw_space_is_a_dir
        BL      Util_PrintNameNL
        BLVS    CopyErrorExternal
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountFile
; =========
;
; Count single file (which exists)
; Fullname set up in desc^.name; info read

; In    r7 = file desc^, file exists

; Out   r0, r5 corrupt
;       VC: file counted, or skipped
;       VS: failed to count file, or aborted

CountFile Entry

 [ debugcount
 DLINE "CountFile"
 ]
        BL      CountFile_Confirm       ; Ask the punter
        EXIT    VS
        BLNE    Util_IncrementSkipped
        EXIT    NE                      ; Don't count this file

; Add size to total

        BLVC    CountFile_Verbose        ; Tell them copy action is complete
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountDirectory
; ==============

; Count whole directory contents then count the directory itself
; Fullname of dir set up in desc^.name; info read

; In    r7 = dir desc^, directory exists

; Out   r0-r5 corrupt
;       VC: directory counted, or skipped
;       VS: failed to count directory, or aborted

CountDirectory Entry

 [ debugcount
 DLINE "CountDirectory"
 ]
        BL      CountDirectory_ConfirmAll
        EXIT    VS
        BLNE    Util_IncrementSkipped
        EXIT    NE

; Count contents of dir, saving quite a bit of info on stack

        ADR     r1, util_totalsize      ; Save total so far this level
        LDMIA   r1, {r1, r14}
        Push    "r1, r14"

        BL      Util_IntoDirectory
        BLVC    CountWildObject
        BL      Util_OutOfDirectory

        Pull    "r3, r4"                ; Restore size counted at this level
        ADR     r14, util_totalsize
        STMVCIA r14, {r3-r4}
        BVC     %FT10
        ADDS    r3, r3, r1
        ADC     r4, r4, r2              ; add here if error
        STMIA   r14, {r3-r4}
        SETV                            ; Ensure V still set
        EXIT
10

        BLVC    CountDirectory_Verbose  ; Tell them count dir complete
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountFile_Confirm
; =================

; If dates allow count, maybe ask punter if he wants to do it

; Out   VS: error
;       VC, EQ -> do it
;       VC, NE -> don't do it

fsw_count_file          DCB     "Cc0", 0
fsw_count_directory     DCB     "Cc1", 0
        ALIGN

CountFile_Confirm Entry "r0, r1, r2"

        BL      Util_DateRange          ; See if dates allow it
        EXIT    NE

        ADR     r2, fsw_count_file

10      LDR     r14, util_bitset        ; Entered from below
        TST     r14, #util_confirm
        EXIT    EQ

        BL      Util_PrintName
        BLVC    Util_GetConfirm
        BLVS    CopyErrorExternal
        EXIT

; .............................................................................
;
; CountDirectory_ConfirmAll
; =========================

; Out   VS: error
;       VC, EQ -> do it
;       VC, NE -> don't do it

CountDirectory_ConfirmAll ALTENTRY

        ADR     r2, fsw_count_directory
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CountFile_Verbose
; =================

; Counted the file, so print copied info if being verbose. nfiles++

; In    util_length = size of file encountered. To be added to totalsize

; Out   VS: error

fsw_file_counted        DCB     "Cc2", 0
fsw_directory_counted   DCB     "Cc3", 0
        ALIGN

CountFile_Verbose Entry "r0, r2, r3-r5, r9"

        LDR     r9, util_length         ; Always increment size counted
        ADR     r5, util_totalsize
        LDMIA   r5, {r3-r4}
        ADDS    r3, r3, r9
        ADC     r4, r4, #0
        STMIA   r5, {r3-r4}

        BL      Util_IncrementFiles_TestVerbose
        EXIT    EQ                      ; EQ -> ~verbose, so leave

        ADR     r2, fsw_file_counted

        BL      Util_PrintNameNL
        BLVS    CopyErrorExternal
        EXIT

; .............................................................................
;
; CountDirectory_Verbose
; ======================

; Counted the directory; always print info

; In    util_popsize = size of dir counted. To be added to totalsize

; Out   VS: error

CountDirectory_Verbose Entry "r0, r2, r3-r5, r9-r10"

        ADR     r9, util_popsize        ; Always increment size counted
        LDMIA   r9, {r9-r10}
        ADR     r5, util_totalsize
        LDMIA   r5, {r3-r4}
        ADDS    r3, r3, r9
        ADC     r4, r4, r10
        STMIA   r5, {r3-r4}

        BL      Util_IncrementDir_TestVerbose
        EXIT    EQ                      ; EQ -> ~verbose, so leave

        ADR     r2, fsw_directory_counted

        BL      Util_PrintName64
        SWIVC   XOS_NewLine
        BLVS    CopyErrorExternal
        EXIT
        
 ] ; hascount

 [ hasutil
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                   Common   routines   for   utilities
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Common startup - save registers + initialise. Process first name

; In    r1    = filename
;       r3    = bits for utility
;       r4,r5 = start time
;       r6,r7 = end time
;       Only have utilslocalframe unless called from copy

; Out   r7 -> util_block

Util_CommonStart Entry
 [ debugutil
        DSTRING r1, "Util_Commonstart(",cc
        DREG    r2, ",",cc
        DLINE   ")"
 ]

        TST     r3, #util_printok       ; Can't be verbose or ask for confirm
                                        ; if printing not allowed
        BICEQ   r3, r3, #util_confirm + util_verbose + util_promptchange

        TST     r3, #util_structureonly ; Force recurse if 'T' option
        ORRNE   r3, r3, #util_recurse

        TST     r3, #util_promptchange  ; If prompting then reduce n disc swaps
        BICNE   r3, r3, #util_peekdest

        TST     r3, #util_confirm       ; Remember top level confirmation
        ORRNE   r3, r3, #util_topconfirm
        STR     r3, util_bitset

        AND     r5, r5, #&FF            ; Nobble time bits to 5 byte range
        AND     r7, r7, #&FF
        ADR     r14, util_times         ; Start then end - global to the copy
        STMIA   r14, {r4-r7}

        MOV     r14, #0
        STR     r14, util_ndir
        STR     r14, util_nfiles
        STR     r14, util_nskipped
        STR     r14, util_totalsize + 0
        STR     r14, util_totalsize + 4

        BL      Process_WildPathname
        EXIT    VS
 [ debugutil
        DSTRING r1, "Tail=",cc
        DSTRING r7, " wildleaf="
 ]

;        ; Check the object exists
;        TEQ     r0, #object_nothing
;        BEQ     %FT90

        ; Store the first object's info
        STR     r0, util_objecttype
        ADR     r14, util_load
        STMIA   r14, {r2-r5}

        ; Take a copy of the strings
        BL      Util_MakeFileStrings    ; Take copies of tail, wildcard and specialfield

        BL      JunkFileStrings         ; Free the file strings as they're not needed any more
        EXIT    VS                      ; Nothing allocated (honest!)

 [ debugutil
 EXIT VS
 DLINE "Setting up r7 util block"
 ]
        ADRVC   r7, util_block
        STRVC   r0, [r7, #copy_dirprefix]
        STRVC   r1, [r7, #copy_leafname]
        STRVC   r2, [r7, #copy_special]
        STRVC   fscb, [r7, #copy_fscb]

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Prints tagged string with %0=util_nfiles in decimal and %1=util_totalsize
; in comma separated. NewLine appended

; In    r1 = address of tag list for (0, 1, 2, many files)
; tagged string has %0 = number of files and %1 for bytes message

; Out   VS: r0 -> error
;       VC: r0 corrupt

Util_FilesDone Entry "r0-r5", 112

        ADR     r0, util_nfiles
        MOV     r1, sp
        MOV     r2, #16         ; Worst 10^9 plus 3 commas
        MOV     r3, #4          ; 32 bits
        MOV     r4, #ConvertToPunctCardinal
        SWI     XOS_ConvertVariform
        ADRVC   r0, util_totalsize
        ADDVC   r1, sp, #16     ; Don't overwrite last conversion
        MOVVC   r2, #32         ; Worst 10^18 plus 6 commas
        MOVVC   r3, #8          ; 64 bits
        MOVVC   r4, #ConvertToPunctCardinal
        SWIVC   XOS_ConvertVariform
        BVS     %FT90

 [ debugutil
        DLINE   "nfiles and totalsize converted to number strings"
 ]

        ADR     r0, bytetags
        ADR     r1, util_totalsize
        LDMIA   r1, {r1, r14}
        TEQ     r14, #0
        MOVNE   r1, #-1         ; That's 'many' by anyone's measure
        BL      Util_PluralAdvanceTag

        ADD     r1, sp, #48
        MOV     r2, #Proc_LocalStack - 48
        ADD     r4, sp, #16
        BL      message_lookup21_into_buffer
        BVS     %FT90

 [ debugutil
        DLINE   "totalsize combined into <n> bytes"
 ]

        ; Select amoungst 0, 1, 2 and many for the main message
        LDR     r0, [sp, #Proc_LocalStack + 1*4]
        LDR     r1, util_nfiles
        BL      Util_PluralAdvanceTag

        MOV     r4, sp
        ADD     r5, sp, #48
 [ debugutil
        DSTRING r0, "About to write with tag "
        DSTRING r4, "p0:"
        DSTRING r5, "p1:"
 ]
        BL      message_write02
        SWIVC   XOS_NewLine
90
        STRVS   r0, [sp, #Proc_LocalStack + 0*4]
        EXIT

bytetags
        DCB     "C0", 0         ; 0
        DCB     "C1", 0         ; 1
        DCB     "C2", 0         ; 2
        DCB     "C3", 0         ; many
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In    r0 = address of tag list
;       r1 = number

; Out   r0 advanced to relevant for number

Util_PluralAdvanceTag EntryS
        CMP     r1, #0
        BLHI    %FT50
        CMP     r1, #1
        BLHI    %FT50
        CMP     r1, #2
        BLHI    %FT50
        EXITS
50
        Push    "lr"
60
        LDRB    lr, [r0], #1
        TEQ     lr, #0
        BNE     %BT60
        Pull    "pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_CheckWildName
; ==================

; Test leafname for wildness

; In    r1 -> leafname

; Out   EQ: wild spec
;       NE: not wild

Util_CheckWildName Entry "r1"

        ; NULL strings are not wildcards
        TEQ     r1, #NULL
        BNE     %FA01
        TEQ     r1, #NULL+1             ; Set NE
        EXIT

01      LDRB    r14, [r1], #1
        CMP     r14, #space             ; LO term (never space in name -> NE)
        EXIT    LS
        CMP     r14, #"*"
        CMPNE   r14, #"#"
        EXIT    EQ                      ; Either EQ -> wild or NE -> not wild
        B       %BT01

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_MakeFileStrings
; ====================

; In    r1 = Pathtail^ for object or directory for enumeration as appropriate
;       r6 = scb^ or special field^
;       r7 = wildcard^ for enumeration, or is NULL if isn't a wildcard
;       fscb^
;
; Out   r0 -> dirprefix string
;       r1 -> leafname string
;       r2 -> special string (copy of special field or scb^)

;       VS: error set

Util_MakeFileStrings Entry "r0,r1,r2"

 [ debugutil
 DLINE "Util_MakeFileStrings"
 ]

        ; No strings allocated yet
        MOV     r14, #0
        STR     r14, [sp, #Proc_LocalStack + 0*4]
        STR     r14, [sp, #Proc_LocalStack + 1*4]
        STR     r14, [sp, #Proc_LocalStack + 2*4]

        ; Get a dir prefix
        ADD     r0, sp, #Proc_LocalStack + 0*4
        BL      SNewString
        EXIT    VS

        ; Get a wildcard
        MOV     r1, r7
        ADD     r0, sp, #Proc_LocalStack + 1*4
        BL      SNewString
        BVS     %FT90

        ; Check for special field-ness
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        STREQ   r6, [sp, #Proc_LocalStack + 2*4]
        MOVNE   r1, r6
        ADDNE   r0, sp, #Proc_LocalStack + 2*4
        BLNE    SNewString
        BVS     %FT80

        EXIT

80
        ; Error exit with dirprefix and wildcard allocated
        LDR     r2, [sp, #Proc_LocalStack + 1*4]
        BL      SFreeArea

90
        ; Error exit with dirprefix allocated
        LDR     r2, [sp, #Proc_LocalStack + 0*4]
        BL      SFreeArea

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Don't need to catch errors in here; we'll get 'em on the way out !

; In fact, no error must come from these!

Util_FreeFileStrings_R7 Entry "r1-r2"

 [ debugutil
 DLINE "Freeing r7 leaf,dir"
 ]
        MOV     r1, r7

10      LDR     r2, [r1, #copy_leafname]
        BL      SFreeArea

        LDR     r2, [r1, #copy_dirprefix]
        BL      SFreeArea
        EXIT                   ; SFreeArea preserves flags, so we don't have to

; .............................................................................

Util_FreeFileStrings_R8 ALTENTRY

 [ debugcopy ; Not used by wipe
 DLINE "Freeing r8 leaf,dir"
 ]
        MOV     r1, r8
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_AppendLeafToDir
; ====================

; Create fullname in record given dirprefix and leafname

; In    r0 -> record

Util_AppendLeafToDir Entry "r1-r4"

 [ debugutil
 DLINE "Util_AppendLeafToDir"
 ]

        LDR     r1, [r0, #copy_leafname] ; Can't have null leafname

01
        Push    "r1"

        ; Calculate the length
        MOV     r3, #1                          ; For the \0
        TEQ     r1, #NULL
        BLNE    strlen_accumulate
        LDR     r1, [r0, #copy_dirprefix]       ; never NULL
        LDREQB  r14, [r1]
        TEQEQ   r14, #0
        ADDNE   r3, r3, #1                      ; For the . separator
        BL      strlen_accumulate

        ; Get the memory
        BL      SMustGetArea
        ADDVS   sp, sp, #1*4
        EXIT    VS
        STR     r2, [r0, #copy_name]

        ; Fill in the memory
        MOV     r1, r2
        LDR     r2, [r0, #copy_dirprefix]
        BL      strcpy_advance                  ; dirprefix
        LDRB    r14, [r2]
        TEQ     r14, #0
        Pull    "r2"
        TEQNE   r2, #NULL
        MOVNE   r14, #"."                       ; . separator if both are non-empty strings
        STRNEB  r14, [r1], #1
        TEQ     r2, #NULL
        STREQB  r2, [r1]
        BLNE    strcpy                          ; leafname
 [ debugutil
        LDR     r1, [r0, #copy_name]
        DSTRING r1,"Dir+Name = "
 ]

        EXIT
96
        DCB     ".", 0
        ALIGN

; .............................................................................
; In    r0 -> record
;       r1 = leafname to append

Util_AppendGivenLeafToDir ALTENTRY

        B       %BT01

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_PrintName
; ==============

; Print substituted tagged string:
; blah blah %0 blah blah %1 blah blah %2 blah blah
; %0 = expanded filename from record at r7
; %1 = expanded filename from record at r8
; %2 = filesize from r9

; In    r2 = pointer to tag of string
;       r7 = record of file to substitute into %0
;       r8 = record of file to substitute into %1
;       r9 = size to substitute into %2
;       r10= high word of size for 64 bit version

; Out   VC: r0 corrupt
;       VS: r0 -> error block

Util_PrintName Entry "r1-r7, fscb"
        ASSERT  fscb = r10
        MOV     r10, #0
        B       %FT05
        
Util_PrintName64 ALTENTRY

 [ debugutil
        DLINE   "Util_PrintName",cc
        DREG    r8, " r8 in is ",cc
        DREG    r9, " r9 in is ",cc
        DREG    r10, " r10 in is ",cc
        DREG    r11, " r11 in is ",cc
        DREG    r12, " r12 in is "
 ]
05
        ; Keep length for later conversion
        Push    "r9-r10"

        ; Get the parameters of the name
        LDMIA   r7, {r1, r6, fscb}
 [ debugutil
        DSTRING r1, "Name is "
        DSTRING r6, "Special is "
        DREG    fscb, "fscb is "
 ]
        MOV     r7, sp
        BL      int_ConstructFullPathOnStack
        MOV     r4, sp

        ; Test for presence of second filename
        TEQ     r8, #0
        MOVEQ   r5, #0
        BEQ     %FT10

        ; Get the parameters of the name
        LDMIA   r8, {r1, r6, fscb}
 [ debugutil
        DSTRING r1, "Name is "
        DSTRING r6, "Special is "
        DREG    fscb, "fscb is "
 ]
        BL      int_ConstructFullPathOnStack
        MOV     r5, sp
10
        SUB     sp, sp, #16
        Push    "r3-r4"
        MOV     r0, r7                  ; Reach up to r9,r10
        ADD     r1, sp, #2 * 4          ; Temp buffer
        MOV     r2, #16                 
        MOV     r3, #8                  ; 64 bit
        MOV     r4, #ConvertToFileSize
        SWI     XOS_ConvertVariform
        Pull    "r3-r4"
        BVS     %FT90

        MOV     r6, sp

        LDR     r0, [r7, #3*4]          ; r2 in
 [ debugutil
        DSTRING r0,"about to tag:"
        DSTRING r4,"p0:"
        DSTRING r5,"p1:"
        DSTRING r6,"p2:"
 ]
        BL      message_write03

90
        ; Drop the stack frame and r9/r10
        ADD     sp, r7, #2 * 4
 [ debugutil
        DREG    r8, " r8 out is ",cc
        DREG    r9, " r9 out is ",cc
        DREG    r10, " r10 out is ",cc
        DREG    r11, " r11 out is ",cc
        DREG    r12, " r12 out is "
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_PrintNameNL
; ================

; Print substituted tagged string:
; blah blah %0 blah blah %1 blah blah %2 blah blah
; %0 = expanded filename from record at r7
; %1 = expanded filename from record at r8
; %2 = filesize from r9

; In    r2 = pointer to tag of string
;       r7 = record of file to substitute into %0
;       r8 = record of file to substitute into %1
;       r9 = size to substitute into %2

; Out   VC: r0 corrupt
;       VS: r0 -> error block

Util_PrintNameNL Entry
        BL      Util_PrintName
        SWIVC   XOS_NewLine
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_IntoDirectory
; ==================

; Nest into directory

; In    r7, r8 contexts to nest into
;       r8 may be 0 indicating no context
;
; Out   Contexts nested, stack used
Util_IntoDirectory ROUT
        TEQ     r8, #0
        SUBNE   sp, sp, #13*4
        SUBEQ   sp, sp, #9*4
        Entry   "r0-r6,r9-r10"

        ; Save the generally applicable stuff
        LDR     r0, [r7, #copy_dirprefix] ; Push names
        LDR     r1, [r7, #copy_leafname]
        LDR     r2, [r7, #copy_name]
        LDR     r3, util_direntry       ; Push position in dir
        LDR     r4, util_bitset         ; Push flags
        LDR     r5, util_attr           ; Push srclocked state in case deleting
        LDR     r6, [r7, #copy_special]
        LDR     r9, util_nskipped
        LDR     r10, [r7, #copy_fscb]
        ADD     r14, sp, #10*4
        STMIA   r14!, {r0-r6,r9,r10}

        ; Save the r8-relative stuff
        LDRNE   r0, [r8, #copy_dirprefix]
        LDRNE   r1, [r8, #copy_leafname]
        LDRNE   r2, [r8, #copy_name]
        LDRNE   r3, [r8, #copy_special]
        STMNEIA r14, {r0-r3}

        LDRNE   r14, [r8, #copy_name]
        STRNE   r14, [r8, #copy_dirprefix]
        addr    r14, fsw_wildstar       ; Leafname := '*'
        STR     r14, [r7, #copy_leafname]
        STRNE   r14, [r8, #copy_leafname]
        MOV     r14, #0
        STR     r14, util_nskipped      ; Nothing skipped at this level
        STR     r14, util_totalsize + 0 ; Nothing copied at this level
        STR     r14, util_totalsize + 4

        LDMIA   r7, {r1,r6,fscb}
        BL      EnsureCanonicalObject
        BLVC    AssessDestinationForPathTailForDirRead
        EXIT    VS
        STMIB   r7, {r6, fscb}
        STR     r1, [r7, #copy_dirprefix]

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_OutOfDirectory
; ===================

; UnNest out of directory

; In    r7, r8 contexts to nest into
;       r8 may be 0 indicating no context
;
; Out   Contexts unnested, stack freed
;       r0 = old value of util_nskipped
;       r1,r2 = old value of util_totalsize
Util_OutOfDirectory

        Entry   "r3-r6,r9-r10"

        TEQ     r8, #0
        ADDEQ   r14, sp, #7*4 + 9*4
        ADDNE   r14, sp, #7*4 + 13*4
        LDMNEDB r14!, {r0-r3}
        STRNE   r0, [r8, #copy_dirprefix]
        STRNE   r1, [r8, #copy_leafname]
        STRNE   r2, [r8, #copy_name]
        STRNE   r3, [r8, #copy_special]

        LDMDB   r14, {r0-r6,r9-r10}

        ; Save the generally applicable stuff
        STR     r0, [r7, #copy_dirprefix] ; Push names
        STR     r1, [r7, #copy_leafname]
        STR     r2, [r7, #copy_name]
        STR     r3, util_direntry
        STR     r4, util_bitset
        STR     r5, util_attr
        STR     r6, [r7, #copy_special]
        LDR     r0, util_nskipped
        STR     r9, util_nskipped
        STR     r10, [r7, #copy_fscb]

        ADR     r1, util_totalsize
        LDMIA   r1, {r1-r2}
        ADR     r14, util_popsize
        STMIA   r14, {r1-r2}            ; Verbose mode needs size of popped dir

        Pull    "$Proc_RegList.,r14"
        ADDEQ   sp, sp, #9*4
        ADDNE   sp, sp, #13*4
 [ No26bitCode                          ; We have preserved V, which is all
        MOV     pc, lr                  ; that is necessary
 |
        MOVS    pc, lr
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_ReadDirEntry
; =================

; Read one name from directory specified by r7 record

; In    util_direntry -> dir entry to read

; Out   util_direntry -> next dir entry to read
;       r3 = number of names read. 0 if at eod
;       Info + name in util_load .. util_objectname

Util_ReadDirEntry Entry "r0-r2, r4-r6, fscb" ; FSFunc only preserves r6 up

        LDR     r4, util_direntry
 [ debugutil
 DREG r4, "Util_ReadDirEntry from dir entry ",cc,Integer
 ]
        TST     r4, #(1 :SHL: 31)       ; Already at end ? (-ve)
        MOVNE   r3, #0
        BNE     %FT50

30

        LDMIB   r7, {r6, fscb}          ; Read special + fscb, skipping name
        LDR     r1, [r7, #copy_dirprefix]

        ; Convert to normal entry sequence number
 [ debugutil
 DSTRING r1,", dirprefix "
 ]
        MOV     r0, #fsfunc_ReadDirEntriesInfo
        ADR     r2, util_load
 [ debugutil
 DREG r2, "reading to buffer at "
 ]
        MOV     r3, #1                  ; Just one at a time, please
        MOV     r5, #util_objblksize
        BL      CallFSFunc_Given
        EXIT    VS
 [ debugutil
 ADR r1, util_objectname
 DSTRING r1, "ObjectName read is "
 ]

50
; MB Fix (10/3/99)
; the original code was totally broken, someone didn't read the specs
; if the buffer overruns it results in r3 == 0 and so causes an infinite loop
; Original code:
;        ; If none read, but not at end, then try for another.
;        TEQ     r3, #0
;        BNE     %FT60
;        CMP     r4, #-1
;        BNE     %BT30

	CMP	r4,#-1			; if r4 == -1 then we are finished
	BEQ	%FT60

	TEQ	r3,#0			; if r3 == 0 then buffer overflow
	BNE	%FT60			; else read an entry ok, so return it

	; if we get here then the buffer has overflowed so return an error
	addr	r0, ErrorBlock_BuffOverflow
        BL      CopyError		; else return a buffer overflow error
	SETV

	EXIT

; end MB fix

60
 [ debugutil
 DREG r3,,cc,Integer
 DREG r4, " name(s) read, next dir entry ",,Integer
 ]
        STR     r4, util_direntry
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Get file info into util block as if it had been read using Util_ReadDirEntry

; Out   EQ: Object is a file
;       HI: Object is a directory
;       VS: fulkup or not found

Util_SingleObjectSetup Entry

        MOV     r0, #fsfile_ReadInfo
        BL      CallFSFile_Given_R7

        ADRVC   r14, fileblock_load     ; Copy all object info if file or dir
        LDMVCIA r14, {r2-r5}
        BL      AdjustObjectTypeReMultiFS
        EXIT    VS

 [ debugutil
        DSTRING r1,"Util_SingleObjectSetup->(",cc
        DREG    r0, ",", cc
        DREG    r2, ",", cc
        DREG    r3, ",", cc
        DREG    r4, ",", cc
        DREG    r5, ",", cc
        DLINE   ")"
 ]
        STR     r0, util_objecttype
        ADR     r14, util_load
        STMIA   r14, {r2-r5}

        CMP     r0, #object_file        ; VClear. Flags for result
        LDRLO   r1, [r7, #copy_name]
        BLLO    SetMagicFileNotFound    ; Else give error
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r4 -> object name
;       r9 -> wild pattern

; Out   EQ -> matched

Util_TryMatch Entry "r1,r2"

        MOV     r1, r4
        MOV     r2, r9                  ; Source pattern
        BL      WildMatch
        BLNE    Util_IncrementSkipped   ; EQ -> matched, so copy
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_SpecialDir
; ===============

; In    r1 -> pathname to check

; Out   EQ: name is special
;       NE: or not as the case may be
;       VClear always

Util_SpecialDir Entry "r1"

        LDRB    r14, [r1]               ; Is it exactly 'x' where x = special ?
        CMP     r14, #"$"               ; Root ?
        CMPNE   r14, #"&"               ; URD ?
        CMPNE   r14, #"@"               ; CSD ?
        CMPNE   r14, #"%"               ; LIB ?
        CMPNE   r14, #"\\"              ; PSD ?
        LDREQB  r14, [r1, #1]
        CMPEQ   r14, #0                 ; followed by terminator
        EXIT    EQ

        LDRB    r14, [r1], #1           ; Is it a drive spec ?
        CMP     r14, #":"
        EXIT    NE                      ; [not special]

10      LDRB    r14, [r1], #1
        CMP     r14, #0
        EXIT    EQ                      ; [yes, it's a drive spec]
        CMP     r14, #"."
        BNE     %BT10

        LDRB    r14, [r1]               ; Optional $ then terminator ?
        CMP     r14, #"$"
        LDREQB  r14, [r1, #1]
        CMPEQ   r14, #0
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_GetConfirm
; ===============

; Ask for confirmation of action without killing buffer, may be done from exec

; A(bandon): Skip object and all others at this level
; Q(uiet): Do object, turn off confirm at this level and below
; Y(es): Do object
; Other: Skip object

; ESCAPE aborts from global operation and gives error

; Out   VS: r0 -> error block
;       VC, EQ: confirmed
;       VC, NE: not confirmed

Util_GetConfirm Entry "r0-r2"
 [ debugutil
        DLINE   "Util_GetConfirm",cc
        DREG    r8, " r8 in is ",cc
        DREG    r9, " r9 in is ",cc
        DREG    r10, " r10 in is ",cc
        DREG    r11, " r11 in is ",cc
        DREG    r12, " r12 in is "
 ]

        MOV     r0, #15                 ; Flush current input buffer
        MOV     r1, #1
        SWI     XOS_Byte
 [ debugutil
        DREG    r8, "(A) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]

        ADRVCL  r0, fsw_ynqa_prompt
        BLVC    message_write0
 [ debugutil
        DREG    r8, "(B) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]
        SWIVC   XOS_Confirm
 [ debugutil
        DREG    r8, "(C) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]
        BVS     %FT99
        BCS     %FT95
        BEQ     %FT50                   ; Yes
        Internat_CaseConvertLoad r14,Upper
        Internat_UpperCase r0, r14

        MOV     r1, r0
        ADRL    r0, fsw_A_letter
        BL      message_lookup
        BVS     %FT99
        LDRB    r0, [r0]
        TEQ     r0, r1
        BNE     %FT10
 [ debugutil
        DREG    r8, "(D) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]

        MOVS    r14, #-1                ; NE -> skip (and everything else)
        STR     r14, util_direntry
        B       %FT50

10
        ADRL    r0, fsw_Q_letter
        BL      message_lookup
        BVS     %FT99
        LDRB    r0, [r0]
        TEQ     r0, r1                  ; Stop prompting and get on with it ?
        LDREQ   r14, util_bitset
        BICEQ   r14, r14, #util_confirm
        STREQ   r14, util_bitset
 [ debugutil
        DREG    r8, "(E) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]
        BEQ     %FT50                   ; EQ -> do it

        ; None of the above, must be 'no'
        ADRL    r0, fsw_N_letter
        BL      message_lookup
        BVS     %FT99
        LDRB    r0, [r0]
 [ debugutil
        DREG    r8, "(F) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]

50      SWI     XOS_WriteC              ; Tell him what he pressed
 [ debugutil
        DREG    r8, "(G) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]
        SWIVC   XOS_NewLine             ; Flags fall out from compare if lucky
 [ debugutil
        DREG    r8, "(H) r8 is ",cc
        DREG    r9, " r9 is ",cc
        DREG    r10, " r10 is ",cc
        DREG    r11, " r11 is ",cc
        DREG    r12, " r12 is "
 ]

99      STRVS   r0, [sp]
 [ debugutil
        DREG    r8, " r8 out is ",cc
        DREG    r9, " r9 out is ",cc
        DREG    r10, " r10 out is ",cc
        DREG    r11, " r11 out is ",cc
        DREG    r12, " r12 out is "
 ]
        EXIT


95
        ADR     r0, fsw_aborted
        BL      message_gswrite0
        BL      SAckEscape
        B       %BT99

fsw_ynqa_prompt DCB     "C4", 0
fsw_Y_letter    DCB     "C5", 0
fsw_N_letter    DCB     "C6", 0
fsw_Q_letter    DCB     "C7", 0
fsw_A_letter    DCB     "C8", 0
fsw_aborted     DCB     "C9", 0
fsw_yn_prompt   DCB     "C10", 0
        ALIGN

; .............................................................................
; A simpler version

Util_GetConfirmYN ALTENTRY

        MOV     r0, #15                 ; Flush current input buffer
        MOV     r1, #1
        SWI     XOS_Byte

        ADRVC   r0, fsw_yn_prompt
        BLVC    message_write0
        SWIVC   XOS_Confirm
        BVS     %BT99
        BCS     %BT95

        ADRNE   r0, fsw_N_letter
        BLNE    message_lookup
        BVS     %BT99
        LDRNEB  r0, [r0]                ; NE -> skip (and say 'N' too)

        SWI     XOS_WriteC              ; Tell him what he pressed
        SWIVC   XOS_NewLine             ; Flags fall out from compare if lucky
        B       %BT99                   ; Cheap exit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Util_DateRange
; ==============

; Check file datestamp against limits (inclusive). Silly on directories !

; Out   EQ -> ok, do it (whatever it is you propose to do !)
;       NE -> don't do it

Util_DateRange Entry "r0-r5"

        LDR     r14, util_bitset        ; Ok if no datelimit set
        TST     r14, #util_datelimit
        EXIT    EQ                      ; Do it

        ADR     r14, util_load          ; Read load/exec
        LDMIA   r14, {r0, r1}           ; r0 = load, r1 = exec
        CMN     r0, #&00100000          ; Is it dated ? CSet if so
 [ debugutil
 BCS %FT00
 DLINE "source file undated"
00
 ]
        BCC     %FT20                   ; Always ok if not dated
        AND     r0, r0, #&FF
 [ debugutil
 DREG r0,"source timestamp is ",cc,Byte
 DREG r1
 ]

        ADR     r14, util_starttime     ; Read limits
        LDMIA   r14, {r2-r5}            ; r3, r5 already masked (ex/0ld/ex/0ld)

; NB. Date comparison must be done VERY CAREFULLY. Merci beaucoup to TMD

; SUBS   t1, dl0, dl1
; MOVNE  t1, #Z_bit
; SBCS   t2, dh0, dh1
; TEQEQP t1, pc       ; If equal here, set equality on that of low words

        SUBS    r4, r1, r4              ; After end date ?
        MOVNE   r4, #Z_bit              ; lo words first
        SBCS    r5, r0, r5              ; hi words next
 [ No26bitCode
        MRSEQ   r14, CPSR
        EOREQ   r14, r14, r4
        MSREQ   CPSR_f, r14
 |
        TEQEQP  r4, pc
 ]
 [ debugutil
 BLS %FT00
 DLINE "source newer than end date"
00
 ]
        EXIT    HI                      ; NE -> no go. Watch out if change HS

        SUBS    r2, r1, r2              ; After or equal to start date ?
        MOVNE   r2, #Z_bit              ; lo words first
        SBCS    r3, r0, r3              ; hi words next
 [ No26bitCode
        MRSEQ   r14, CPSR
        EOREQ   r14, r14, r2
        MSREQ   CPSR_f, r14
 |
        TEQEQP  r2, pc
 ]
 [ debugutil
 BLO %FT00
 DLINE "source date in range"
00
 ]
        BHS     %FT20

 [ debugutil
 DLINE "source older than first date"
 ]
        CMP     pc, #0                  ; NE -> no copy. VClear
        EXIT

20      CMP     r0, r0                  ; EQ -> copy. VClear
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   EQ: Not verbose
;       NE: Verbose

Util_IncrementFiles_TestVerbose Entry

        LDR     r14, util_nfiles        ; Another one bites the dust
        ADD     r14, r14, #1
        STR     r14, util_nfiles

50      LDR     r14, util_bitset
        TST     r14, #util_verbose
        EXIT

; .............................................................................

Util_IncrementDir_TestVerbose ALTENTRY

        LDR     r14, util_ndir          ; Another one bites the dust
        ADD     r14, r14, #1
        STR     r14, util_ndir

        B       %BT50

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Must preserve flags

Util_IncrementSkipped Entry

 [ debugutil
 DLINE "Skipping object"
 ]
        LDR     r14, util_nskipped
        ADD     r14, r14, #1
        STR     r14, util_nskipped
        EXIT                            ; Haven't touched flags

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Must preserve flags

Util_DecrementDirEntry EntryS

        LDR     r14, util_direntry
 [ debugutil
 DREG r14, "Util_DecrementDirEntry from ",cc
 ]
        CMP     r14, #-1
        SUBNE   r14, r14, #1
        STRNE   r14, util_direntry
 [ debugutil
 DREG r14, " to "
 ]
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   r0 = result (if any)
;       assumes that the destination is already assessed

CallFSFile_Given_R7 Entry "r0-r6, fscb"

        LDMIA   r7, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
 [ debugutil
        DREG    r0, "FSFile(",cc
        DSTRING r1, ",",cc
 ]
        BL      AssessDestinationForPath        ; Don't need EnsureCanonicalObject as that's already been done
        EXIT    VS

        TEQ     r0, #fsfile_Delete
        BLEQ    TryGetFileClosed

 [ debugutil
        DSTRING r1, "->",cc
        DLINE   ")"
 ]
        BLVC    CallFSFile_Given

        STRVC   r0, [sp]
        EXIT

 ] ; hasutil

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   VC: Escape clear
;       VS: r0 -> error, Escape acknowledged

STestEscape Entry

        SWI     XOS_ReadEscapeState
        EXIT    CC

; .............................................................................
; Out   VS, r0 -> error, not copied

SAckEscape Entry

        MOV     r0, #&7E                ; Acknowledge ESCAPE
        SWI     XOS_Byte                ; May give error to override Escape
        BLVC    SetErrorEscape          ; Util grade, not copied
        EXIT


        LTORG

        END
