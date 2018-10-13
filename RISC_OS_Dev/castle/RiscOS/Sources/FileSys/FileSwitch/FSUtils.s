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
        SUBT    > Sources.FSUtils - Copy

; Bits in the bitset used by utilities: internal defs

util_topconfirm *       1 :SHL: 31 ; Top level confirmation

; Bits in the bitset used by utilities: external defs

util_peekdest   *       1 :SHL: 14 ; Quick peek at dest before loading src ?
util_userbuffer *       1 :SHL: 13 ; Use punter's buffer during operation ?
util_newer      *       1 :SHL: 12 ; Copy files if newer (or binary) ?
util_structureonly *    1 :SHL: 11 ; Structure only (no files) ?
util_restamp    *       1 :SHL: 10 ; Restamp datestamped files ?
util_noattr     *       1 :SHL: 9  ; Don't copy attributes over ?
util_printok    *       1 :SHL: 8  ; Allow any printing during operation ?
; If not set then forces ~confirm, ~verbose, ~promptchange
util_deletesrc  *       1 :SHL: 7  ; Delete source after copy ?
util_promptchange *     1 :SHL: 6  ; Prompt for each source/dest switch ?
util_quick      *       1 :SHL: 5  ; Use apl as well as rma/wimp/user ?
util_verbose    *       1 :SHL: 4  ; Print info on objects ?
util_confirm    *       1 :SHL: 3  ; Prompt for each object ?
util_datelimit  *       1 :SHL: 2  ; Apply date range to source files ?
util_force      *       1 :SHL: 1  ; Check for overwriting ?
util_recurse    *       1 :SHL: 0  ; Recurse down directories ?

 [ hascopy
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copy_UpCallCode
; ===============
;
; Monitor UpCalls during *Copy to see if media change needed

; In    r1 = fs number
;       r2 -> media title, 0
;       wp valid

; !!! NO ERRORS COPIED HERE !!!

CC0     DCB     "CC0",0
CC1     DCB     "CC1",0
        ALIGN

Copy_UpCallCode ROUT

; Pass UpCall on to other people in chain to give them first stab at it.

        Push    "r10-r12"               ; Save state of this vector call
        Push    "pc"                    ; Fudge return address,psr = .+12
        MOV     pc, lr                  ; Pass down chain
        NOP                             ; Required for address fudge (also, PC+8 works, ie. Architecture 4)

; Vector claimer (maybe default) will always return here

        Pull    "r10-r12"               ; Restore state of this vector call

        TEQ     r0, #UpCall_MediaNotPresent
        TEQNE   r0, #UpCall_MediaNotKnown
        Pull    pc, NE                  ; Claim UpCall if it's been claimed
                                        ; or if it's not one of ours.

        Push    "r1-r5"
        SUB     sp, sp, #128

        MOV     r0, #FSControl_ReadFSName
        MOV     r2, sp
        MOV     r3, #128
        SWI     XOS_FSControl
        BVS     %FT40

        MOV     r4, sp
        LDR     r5, [sp, #128 + 4]      ; Disc name (r2in)
        LDRB    r14, [sp]
        CMP     r14, #0

        addr    r0, CC0, NE             ; Ensure %0::%1 present then press SPACE bar|M|J
        addr    r0, CC1, EQ             ; Ensure :%1 present then press SPACE bar|M|J

        BL      PromptSpaceBar          ; Doesn't copy errors
        MOVVC   r0, #UpCall_Claimed     ; UpCall processed

40      ADD     sp, sp, #128
        Pull    "r1-r5, pc"             ; Claim vector

 [ UseDynamicAreas
copy_areaname
	DCB	"CC28:*Copy buffer",0
	ALIGN
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                        W i l d c a r d   C o p y
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyEntry
; =========

; In    r1 -> path to copy from
;       r2 -> path to copy to
;       r3 = bitset for copy
;       r4,r5 = optional time (start)
;       r6,r7 = optional time (end)
;       r8 -> optional copy structure
;         [r8, #0] = buffer address     ; iff util_userbuffer
;         [r8, #4] = buffer size        ; iff util_userbuffer

CopyEntry NewSwiEntry "r0-r10",copy     ; CopyWildObject destroys all regs
                                        ; Seriously large frame for copy
 [ debugcopy
        DLINE   "FSControl_Copy: options '",cc
        TST     r3, #util_noattr
        BNE     %FT01
        DLINE   "A",cc
01
        TST     r3, #util_confirm
        BEQ     %FT01
        DLINE   "C",cc
01
        TST     r3, #util_deletesrc
        BEQ     %FT01
        DLINE   "D",cc
01
        TST     r3, #util_force
        BEQ     %FT01
        DLINE   "F",cc
01
        TST     r3, #util_newer
        BEQ     %FT01
        DLINE   "N",cc
01
        TST     r3, #util_promptchange
        BEQ     %FT01
        DLINE   "P",cc
01
        TST     r3, #util_quick
        BEQ     %FT01
        DLINE   "Q",cc
01
        TST     r3, #util_recurse
        BEQ     %FT01
        DLINE   "R",cc
01
        TST     r3, #util_restamp
        BEQ     %FT01
        DLINE   "S",cc
01
        TST     r3, #util_structureonly
        BEQ     %FT01
        DLINE   "T",cc
01
        TST     r3, #util_verbose
        BEQ     %FT01
        DLINE   "V",cc
01
        DREG    r3,"' "
 ]
        TST     r3, #util_userbuffer
        LDMNEIA r8, {r9, r10}
        MOVEQ   r9, #&4000              ; No user buffer supplied (say &4000
        MOVEQ   r10, #0                 ; so we'll load zero length files in
        STR     r9,  copy_userbuffer    ; it though - don't say &8000 as we
        STR     r10, copy_userbuffersize ; won't release apl >>>a186<<<)

        BL      Util_CommonStart
        BVS     %FA99 ; SwiExit - nothing allocated
 [ debugcopy
        LDR     r0, [r7, #copy_special]
        DSTRING r0, "src: #",cc
        LDR     r0, [r7, #copy_dirprefix]
        DSTRING r0, ":",cc
        LDR     r0, [r7, #copy_leafname]
        DSTRING r0, "."
 ]

        LDR     r14, util_bitset
        TST     r14, #util_quick :OR: util_restamp ; If we want to restamp or
        MOVNE   r0, #14                 ; might use SWI OS_Exit, note time
        ADRNE   r1, copy_startedtime
        MOVNE   r14, #3
        STRNE   r14, [r1]
        SWINE   XOS_Word                ; ReadTime shouldn't give error

        MOV     r14, #0                 ; We don't yet own apl space
        STRB    r14, copy_owns_apl_flag

        MOV     r14, #copy_at_unknown   ; Not at source or dest a ce moment
        STRB    r14, copy_src_dst_flag

        LDR     r14, util_bitset        ; Can't do upcalls if printing not ok
 [ debugcopy
        DREG    r14, "util_bitset:"
 ]
        TST     r14, #util_printok
        BEQ     %FT10

        LDRB    r14, copy_n_upcalls     ; If ~n_upcalls++ then claim
 [ debugcopy
        DREG    r14, "copy_n_upcalls:"
 ]
        TEQ     r14, #0
        ADD     r14, r14, #1
        STRB    r14, copy_n_upcalls     ; NB. This is global
        BNE     %FT10

 [ debugcopy
        DLINE   "Sit on UpCallV"
 ]

        MOV     r0, #UpCallV            ; Sit on UpCallV
        addr    r1, Copy_UpCallCode
        MOV     r2, wp
        SWI     XOS_Claim
        BLVS    CopyErrorExternal
        BVS     %FT87
10

        BL      Copy_PromptDest
        BVS     %FT87

        LDR     r1, [fp, #2*4]          ; Molest the second one (r2in)
        BL      Process_WildPathname    ; Don't care if it's not there
        ADRVS   r7, util_block
        BVS     %FT87

        ; Take a copy of the strings
        BL      Util_MakeFileStrings    ; Take copies of tail, wildcard and specialfield

        BL      JunkFileStrings         ; Free the file strings as they're not needed any more
        ADR     r7, util_block
        BVS     %FT87

 [ debugcopy
 DLINE "Setting up r8 dst copy block"
 ]
        ADR     r8, dst_copy_block
        STR     r0, [r8, #copy_dirprefix]
        STR     r1, [r8, #copy_leafname]
        STR     r2, [r8, #copy_special]
        STR     fscb, [r8, #copy_fscb]

 [ debugcopy
        LDR     r0, [r7, #copy_special]
        DSTRING r0, "src: #",cc
        LDR     r0, [r7, #copy_dirprefix]
        DSTRING r0, ":",cc
        LDR     r0, [r7, #copy_leafname]
        DSTRING r0, "."
        LDR     r0, [r8, #copy_special]
        DSTRING r0, "dst: #",cc
        LDR     r0, [r8, #copy_dirprefix]
        DSTRING r0, ":",cc
        LDR     r0, [r8, #copy_leafname]
        DSTRING r0, "."
 ]

 [ UseDynamicAreas
	; we create a dynamic area to use for the copy operation,
	; which is equal to the size of the Next slot, but we don't
	; give it any memory.

	Push	"r0-r8"

	SUB 	sp, sp, #32

	ADR	r0, copy_areaname
	MOV	r1, sp
	MOV	r2, #32

	BL	message_lookup2_into_buffer

	ADRVS	r8, copy_areaname
	MOVVC	r8, sp

	MOV	r0, #-1
	MOV	r1, #-1

	SWI	XWimp_SlotSize	; read the slot size.  if can't read it, choose 640K

	MOVVC	r5, r1
	MOVVS	r5, #640*1024	; default to 640K if we can't read it

	TEQS	r5, #0		; if no next slot then set all values to 0
	BNE	%FT15

; here if slot size was zero.  don't create the dynamic area, and write zeroes to all
; the fields

	STR	r5, copy_dynamicarea
	STR	r5, copy_dynamicnum
	STR	r5, copy_dynamicsize
	STR	r5, copy_dynamicmaxsize

	B	%FT19

15
	MOV	r0, #0
	MOV	r1, #-1
	MOV	r2, #0		; don't actually allocate any memory just yet
	MOV	r3, #-1
	MOV	r4, #(1<<7)	; green bar in task manager
	MOV	r6, #0
	MOV	r7, #0

	SWI	XOS_DynamicArea	; try to create the area

	BVS	%FT16

	STR	r1, copy_dynamicnum
	STR	r2, copy_dynamicsize
	STR	r3, copy_dynamicarea
	STR	r5, copy_dynamicmaxsize
	B	%FT18

16
	MOV	r0, #0

	STR	r0, copy_dynamicarea
	STR	r0, copy_dynamicnum
	STR	r0, copy_dynamicsize
	STR	r0, copy_dynamicmaxsize

18
	ADD	sp, sp, #32
	Pull	"r0-r8"
 ]

        BL      CopyWildObject

 [ UseDynamicAreas
	LDR	r1, copy_dynamicmaxsize
	TEQS	r1, #0
	BEQ	%FT19

	; we have an area, get rid of it

	LDR	r1, copy_dynamicnum
	MOV	r0, #1
	SWI	XOS_DynamicArea
19
 ]

        LDR     r14, util_bitset        ; Can't do upcalls if printing not ok
        TST     r14, #util_printok
        BEQ     %FT20

        LDRB    r14, copy_n_upcalls     ; If --n_upcalls then release
        SUBS    r14, r14, #1
        STRPLB  r14, copy_n_upcalls     ; NB. This is global. Paranoid PL
        BNE     %FT20

        MOV     r0, #UpCallV            ; Delink from UpCallV
        addr    r1, Copy_UpCallCode
        MOV     r2, wp
        SWI     XOS_Release
        BLVS    CopyErrorExternal
20
        BL      Util_FreeFileStrings_R8 ; 'Cos it's nice to print verbose bits
        BL      Util_FreeFileStrings_R7 ; Catch errors from these on SwiExit

        LDR     r14, globalerror        ; Give 'Not found' if no error below
        CMP     r14, #0                 ; fp is valid, of course ...
        LDREQ   r14, util_ndir          ; and no dirs or files copied
        CMPEQ   r14, #0
        LDR     r0, util_nfiles         ; r0 useful for below - load always !
        CMPEQ   r0, #0
        LDREQ   r14, util_nskipped      ; Only give error if complete wally
        CMPEQ   r14, #0
        BEQ     %FA98

        LDR     r14, util_bitset
        TST     r14, #util_verbose
        BEQ     %FT95

        TST     r14, #util_deletesrc
        ADREQ   r1, fsw_copied_total
        ADRNE   r1, fsw_moved_total
        BL      Util_FilesDone          ; eg. '3 files copied, total 1234 bytes'

90      BLVS    CopyErrorExternal       ; ep for below

95      LDRB    r14, copy_owns_apl_flag ; <> 0 -> apl space corrupted
        TEQ     r14, #0
        BEQ     %FA99 ; SwiExit

        LDR     r0, globalerror         ; Must exit, maybe error ?
        TEQ     r0, #0                  ; fp is valid, of course ...
        BEQ     %FT96

        ADD     r0, r0, #4              ; Point to error message
        SWI     XOS_Write0              ; Z would be dead if VS but see below
        SWIVC   XOS_NewLine             ; Valiantly ignore error + prettify

96 ; Prettify old style supervisor exit handling. Not needed now ?

 [ AssemblingArthur
        LDR     r1, =EnvTime            ; Set EnvTime from time we started copy
 |
        LDR     r1, EnvTimeAddr         ; Set EnvTime from time we started copy
 ]
        LDR     r0, copy_startedtime
        STR     r0, [r1]
        LDRB    r0, copy_startedtime+4
        STRB    r0, [r1, #4]

        MOV     r0, #0                  ; Can't cause error 'cause that'd
        LDR     r1, tutu_abex_string    ; return to Appl with apl trashed !
        MOV     r2, #0                  ; rc = 0. No error on exit
        SWI     OS_Exit                 ; And this sets CAO pointer to be
                                        ; not me no more, so freeing apl


85      BL      Util_FreeFileStrings_R8 ; Early deallocation errors

86

87
        BL      Util_FreeFileStrings_R7

        B       %FA99 ; SwiExit


99      SwiExit



98      addr    r0, ErrorBlock_NothingToCopy
        BL      CopyError
        B       %BT95                   ; Might have corrupt apl, so not simple


fsw_copied_total
        DCB     "CC2", 0        ; 0 - %0 files copied, total %1 bytes
        DCB     "CC22", 0       ; 1
        DCB     "CC24", 0       ; 2
        DCB     "CC26", 0       ; Many

fsw_moved_total
        DCB     "CC3", 0        ; 0 - %0 files moved, total %1 bytes
        DCB     "CC23", 0       ; 1
        DCB     "CC25", 0       ; 2
        DCB     "CC27", 0       ; Many
        ALIGN

tutu_abex_string DCB    "ABEX"          ; Picked up as a word

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyWildObject
; ==============

; src x, dst -: CopyObject single object                  eg. fred    jim
;                                                             *       jim
; src *, dst *: CopyObject on all that match              eg. fred.a* jim.*
;             : Bad copy (no substitution done)               fred.a* jim.b*
; src -, dst *: CopyObject on all that match              eg. fred    *
;             : Bad copy (must be single rhs *)               fred    b*

; Out   Only r7, r8, wp preserved

CopyWildObject Entry

 [ debugcopy
 DREG sp,"Entering CopyWildObject; sp = "
 ]
        LDR     r9, [r7, #copy_leafname] ; Hold onto existing leafname pointers
        LDR     r10, [r8, #copy_leafname]
 [ debugcopy
        DSTRING r9, "src leaf = ",cc
        DSTRING r10, " and dst leaf = "
 ]

        MOV     r1, r10
        BL      Util_CheckWildName
        BNE     %FT90                   ; Dest not wild, so try CopyObject
                                        ; (src type irrelevant)

; ...................... Wild object spec for copy ............................

        LDRB    r0, [r10]               ; No replace, so must have '*' on rhs
        TEQ     r0, #"*"
        LDREQB  r0, [r10, #1]
        TEQEQ   r0, #0
        BNE     %FA80

        ; Check for source being wild - do unwildcard copy if non-wildcard
        MOV     r1, r9
        BL      Util_CheckWildName
        BNE     %FT90

        MOV     r14, #0
        STR     r14, util_direntry      ; Start at the beginning of dir
        STR     r14, [r7, #copy_leafname] ; 'Free' leaves !
        STR     r14, [r8, #copy_leafname]
        Push    "r9, r10"               ; Save leafname pointers

10 ; Loop over source names, match wildcard bits. Leaves are NewString'ed each
   ; time round, but fullnames are always explicitly made and freed in loop

        BL      STestEscape             ; Util grade, not copied
        BLVS    CopyErrorExternal
        BLVC    Copy_PromptSource
        BLVC    Util_ReadDirEntry       ; Get a name. Uses + updates util_diren
        BVS     %FT60                   ; Deallocate new leafnames, put old
                                        ; leafnames back, exit

        CMP     r3, #0                  ; No name xferred ?
        BEQ     %FT60                   ; Means eod

        ADR     r4, util_objectname     ; What we read just now
        BL      Util_TryMatch
        BNE     %BT10                   ; Loop - try another name
        BL      Copy_MakeNewLeaves      ; Deallocate old ones, make new ones
        BVS     %FA70                   ; Will have deallocated old ones if VS

        MOV     r0, #-1                 ; Use both given leafnames
        BL      Copy_MakeFullnames      ; Deallocate new leafnames, put old
        BVS     %FT60                   ; leafnames back, exit

        Push    r9                      ; Preserve wild pattern round call
        BL      CopyObject
        Pull    r9
        BL      Copy_FreeFullnames      ; Accumulate V
        BVC     %BT10                   ; Loop - try another name

60      BL      Copy_FreeLeafnames      ; Deallocate leaves

70      Pull    "r9, r10"               ; Had to stack these
        STR     r9,  [r7, #copy_leafname] ; Put old leaves back
        STR     r10, [r8, #copy_leafname]
 [ debugcopy
 DREG sp,"Leaving CopyWildObject; sp = "
 ]
        EXIT


80      addr    r0, ErrorBlock_BadCopy
81      BL      CopyError
        EXIT


; ............ Single object copy. Must read object info ourselves ............

; NB. Don't call CopyObject - if copying dir, just recurse one level unless
; punter wants more than that

90
        ; Use src leafname for dst if dst has a '*' leafname
        ; Use dst leafname if dst leafname is null (sounds silly, but matches old behaviour before null ptr check was added)
        MOVS    r14, r10
        LDRNEB  r14, [r10]
        TEQ     r14, #"*"
 [ debugcopy
        BNE     %FT01
        DLINE   "Dst is *, use src leafname"
        B       %FT02
01
        DLINE   "Dst isn't *, use dst leafname"
02
 ]
        MOVEQ   r0, #0
        MOVNE   r0, #-1                 ; Use dst leafname

        BL      Copy_MakeFullnames
        EXIT    VS

        BL      Copy_PromptSource
        BLVC    Util_SingleObjectSetup  ; Error if not found
        BVS     %FT95                   ; Deallocate error
        LDR     lr, util_objecttype
        TEQ     lr, #object_directory
        BEQ     %FT96                   ; Is it a dir ?
        BL      CopyFile                ; If it's a file

95      BL      Copy_FreeFullnames      ; Preserves V if set
        EXIT


96
 [ debugcopy
        DLINE   "Unwildcard ",cc
 ]
        BL      CopyDirectory
        B       %BT95

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copy_MakeNewLeaves
; ==================

; Replace wildcard bits and make two new leafnames in r7, r8 records

; In    r9 -> source wild leafname
;       r10 -> dest wild leafname
;       util_objectname = name read

; Out   VS: error; all strings deallocated, old + new

Copy_MakeNewLeaves Entry "r0-r2"

 [ debugcopy
 ADR r1, util_objectname
 DSTRING r1, "Copy_MakeNewLeaves with "
 ]
; pltb assume match, no replace yet !

        ADD     r0, r7, #copy_leafname
        ADR     r1, util_objectname
        BL      SNewString
        EXIT    VS

        ADD     r0, r8, #copy_leafname
        ADR     r1, util_objectname
        BL      SNewString

        LDRVS   r2,  [r7, #copy_leafname] ; Deallocate first one if second fail
        MOVVS   r14, #0
        STRVS   r14, [r7, #copy_leafname]
        BLVS    SFreeArea               ; Accumulate V
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copy_MakeFullnames
; ==================

; Append leaf to dir for source and dest

; In    r0  = 0: use src leafname when making dst fullname
;          <> 0: use dst leafname when making dst fullname

; Out   VS: error - both strings deallocated (no such thing as old fullnames)

Copy_MakeFullnames Entry "r0-r2, r4"

 [ debugcopy
 DLINE "Copy_MakeFullnames"
 ]
        MOV     r0, r7                  ; Make source fullname
        BL      Util_AppendLeafToDir
        EXIT    VS

        LDR     r0, [sp, #0]
        TEQ     r0, #0
        LDREQ   r1, [r7, #copy_leafname]
        LDRNE   r1, [r8, #copy_leafname]

        ; Ensure got a leaf by using last element of dirprefix if leaf not there
        TEQEQ   r1, #NULL
        BNE     %FT50

 [ debugcopy
 DLINE "Faffing with src leafname - it wasn't there"
 ]

        TEQ     r0, #0
        LDREQ   r1, [r7, #copy_dirprefix]
        LDRNE   r1, [r8, #copy_dirprefix]
        MOV     r0, r1
10
        LDRB    r14, [r1], #1
        TEQ     r14, #"."
        MOVEQ   r0, r1
        CMP     r14, #space-1
        TEQHS   r14, #delete
        BHI     %BT10
        MOV     r1, r0

50

        MOV     r0, r8                  ; Make dst fullname with given leafname
 [ debugcopy
 DSTRING r1, "Appending leafname "
 ]
        BL      Util_AppendGivenLeafToDir

        LDRVS   r2, [r7, #copy_name]    ; Deallocate source fullname
        BLVS    SFreeArea               ; Accumulate V
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copy_FreeFullnames
; ==================

; Out   VS: error - both strings deallocated, else V preserved (snazzy)

Copy_FreeFullnames Entry "r0, r2-r3"

 [ debugcopy
 DLINE "Copy_FreeFullnames"
 ]
        MOV     r3, #copy_name

10      LDR     r2,  [r7, r3]           ; Deallocate source name
        BL      SFreeArea               ; Accumulate V

        LDR     r2,  [r8, r3]           ; Deallocate dest name
        BL      SFreeArea               ; Accumulate V
        EXIT

; .............................................................................

Copy_FreeLeafnames ALTENTRY

 [ debugcopy
 DLINE "Copy_FreeLeafnames"
 ]
        MOV     r3, #copy_leafname
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyObject
; ==========
;
; Copy object from A to B, recursing as necessary
; Dirnames set up for this level
; Leafnames already set up after possible wildcard match
; Fullnames already set up

; In    r7 = source file desc^
;       r8 = dest file desc^

; Out   r0-r5 corrupted by calls
;       VC: object copied, skipped, or was dir & ~recurse
;       VS: failed in copying object, or aborted

CopyObject Entry

 [ debugcopy
 DLINE "CopyObject"
 ]
        LDR     r14, util_objecttype    ; What the source ?
        TEQ     r14, #object_directory
        BEQ     %FT50                   ; [is exactly a dir]

; Copy existing file (if doing files !)

        LDR     r14, util_bitset
        TST     r14, #util_structureonly
        BLEQ    CopyFile
        EXIT


50 ; It's a directory. Are we recursing ?

        LDR     r14, util_bitset        ; Recurse set ?
        TST     r14, #util_recurse
        BEQ     %FT70                   ; [no - we've got r14 ok]

; Copy this dir, recursing

 [ debugcopy
        DLINE   "Recursing ",cc
 ]
        BL      CopyDirectory           ; dir & recurse
        EXIT


70      TST     r14, #util_verbose      ; dir & ~recurse. No need to INC skippd
        EXIT    EQ

        ADR     r2, fsw_space_is_a_dir
        BL      Util_PrintNameNL
        BLVS    CopyErrorExternal
        CMPVC   r0, r0                  ; EQ -> not copied
        EXIT


fsw_space_is_a_dir
        DCB     "IsADir", 0             ; %0 is a directory
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyFile
; ========
;
; Copy single file (which exists) from A to B, preserving attributes
; Fullnames set up in desc^.name; source info read

; In    r7 = source file desc^, source exists !
;       r8 = dest file desc^

; Out   Much corruption
;       VC: file copied or skipped
;       VS: failed to copy file

CopyFile Entry

 [ debugcopy
 DLINE "CopyFile"
 ]
        BL      CopyFile_Confirm        ; Check before trying anything
        EXIT    VS
        BLNE    Util_IncrementSkipped
        EXIT    NE                      ; [no copy wanted, nothing allocated]

        ADR     r14, util_load          ; Copy these away to a safe place
        LDMIA   r14, {r0, r1}           ; so looking at restamp won't alter
        ADR     r14, copy_realload      ; (Used in date cmp routine)
        STMIA   r14, {r0, r1}

        LDR     r14, util_bitset        ; Restamping ?
        TST     r14, #util_restamp
        BEQ     %FT01

        CMN     r0, #&00100000          ; If not dated, don't alter addresses
        MOVCS   r14, r0, ASR #8         ; &FFFFFttt
        LDRCSB  r0, copy_startedtime+4
        ORRCS   r14, r0, r14, LSL #8    ; &FFFtttdd
        STRCS   r14, util_load
        LDRCS   r14, copy_startedtime
        STRCS   r14, util_exec
 [ debugcopy
 BCC %FT00
 DLINE "setting new stamp for copy load/exec"
00
 ]

01
        LDR     r14, util_bitset
        TST     r14, #util_peekdest
        BEQ     %FT02

        ; If util_peekdest then EnsureDestFileWriteable before loading source
        BL      CopyFile_EnsureDestFileWriteable
        EXIT    VS
        EXIT    NE                      ; [no copy wanted, nothing allocated]

02
        BL      Copy_PromptSource
        EXIT    VS


; Claim appropriate area of memory to do the copy: user > wimp > rma > apl.
; NB. Memory remapping can't be done under interrupt, so we're reasonably safe.

        LDR     r4, util_length         ; Size of file we are copying
 [ debugcopy
 DREG r4, "FileSize = "
 ]

        LDR     r1, copy_userbuffersize ; Try punter's buffer first
 [ debugcopy
 DREG r1, "UserSize = "
 ]
        CMP     r1, r4
        LDRHS   r2, copy_userbuffer
        BHS     %FT15                   ; [do whole file in user buffer]

        MOV     r0, #0
 [ :LNOT: UseDynamicAreas
        STR     r0, copy_wimpfreearea   ; For eventual deallocation
        STR     r0, copy_wimpfreesize
 ]
        STR     r0, copy_rmasize
        STR     r0, copy_aplsize

 [ UseDynamicAreas

; code when using dynamic areas


	LDR	r1, copy_dynamicsize	; get current dynamic area size
	CMP	r1, r4			; check if it's already big enough
	LDRHS	r2, copy_dynamicarea
	BHS	%FT15			; already big enough

; not right size, attempt to grow or shrink the dynamic area

	LDR	r2, copy_dynamicmaxsize
	CMP	r2, r4
	MOVHS	r2, r4			; choose size to set

	SUB	r1, r2, r1		; change in size required

	LDR	r0, copy_dynamicnum	; get the area

	SWI	XOS_ChangeDynamicArea	; change the area

	BVS	%FT01

	Push	"r0-r8"

	LDR	r1, copy_dynamicnum
	MOV	r0, #2

	SWI	XOS_DynamicArea		; do dynamic area stuff

	STRVC	r2, copy_dynamicsize	; store current size

	Pull	"r0-r8"

01

  	LDR	r1, copy_dynamicsize
	LDR	r2, copy_dynamicarea
	CMPS	r1, r4
	BHS	%FT15			; have found enough memory
; end of code when using dynamic areas

 |

; code when not using dynamic areas


        MOV     r0, #1                  ; Then the Window Manager
        MOV     r1, #1
 [ debugcopy
 DREG r0,"Wimp_ClaimFreeMemory: r0 = ",cc
 DREG r1,", r1 = "
 ]
        SWI     XWimp_ClaimFreeMemory
        BVS     %FT03                   ; [no wimp]
 [ debugcopy
 DREG r2, "WimpAddr = "
 DREG r1, "WimpSize = "
 ]
        CMP     r2, #0
        BEQ     %FT03                   ; [someone else's claimed; can't move]
        STR     r1, copy_wimpfreesize   ; Remember this anyway
        CMP     r1, r4
        STRHS   r2, copy_wimpfreearea
        BHS     %FT15                   ; [do whole file in wimp buffer]

        MOV     r0, #0                  ; Must free it again
 [ debugcopy
 DREG r0,"Wimp_ClaimFreeMemory: r0 = ",cc
 DREG r1,", r1 = "
 ]
        SWI     XWimp_ClaimFreeMemory   ; Can't give error or fail


; end of code when not using dynamic areas

 ]




03      BL      SDescribeRMA
        CMP     r2, r4
        BLO     %FT04

        MOV     r3, r4                  ; Only claim right amount
        BL      SGetRMA
        EXIT    VS
        BNE     %FT15                   ; [claim ok; do whole file in RMA]

; RMA claim failed, maybe due to IRQ

04      LDR     r14, util_bitset
        TST     r14, #util_quick
        BEQ     %FT50                   ; [no way we can do whole file in RMA]

        BL      SClaimAPL               ; Out: r2 -> apl, r1 = apl size

        CMP     r1, r4
        BLO     %FT50                   ; [no way we can do whole file in apl]

        BL      SClaimAPL               ; Out: r2 -> apl

15 ; ++++++++++++++++++ Copy file by Load/Save/WriteAttr ++++++++++++++++++++++

 [ debugcopy
 DREG r2, "Got area for whole file copy: "
 ]
        STR     r2, copy_area

        ; Get the load parameters
        ASSERT  copy_name = 0
        LDMIA   r7, {r1,r6,fscb}

        ; Get a nice to print name for any possible errors
        MOV     r5, sp
        BL      int_ConstructFullPathOnStack

        ; Do the load
        MOV     r0, #object_file
        MOV     r2, sp
        LDR     r3, copy_area
        LDR     r4, util_length
        BL      int_DoLoadFile

        ; Don't need the nice name any more
        MOV     sp, r5
        BVS     %FT95                   ; Deallocate block

        LDR     r14, util_bitset
        TST     r14, #util_peekdest
        BNE     %FT17                   ; Already got dest into suitable state

        ; If not util_peekdest then EnsureDestFileWriteable after loading source
        BL      CopyFile_EnsureDestFileWriteable ; Get to dest; maybe unlock
        BVS     %FT95                   ; Deallocate block
        BNE     %FT95                   ; [don't copy: deallocate block]
        B       %FT18

17
        BL      Copy_PromptDest         ; Still need to get to dest though

18
 [ debugcopy
 DLINE "ok - writing dest file"
 ]
        LDMVCIA r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
        ADRVC   r14, util_load          ; Preserve load and exec addresses
        LDMVCIA r14, {r2, r3, r5}       ; from the source file. NB r5 := length
        LDRVC   r4, copy_area           ; So that we can save a word here
        ADDVC   r5, r4, r5              ; r5 = end address in core (order)
                                        ; r4 = start address in core

        MOVVC   r0, #object_nothing     ; Fib, but we've already checked
        BLVC    AssessDestinationForPath
        BLVC    int_DoSaveFile
        BVS     %FT95                   ; Deallocate block

        LDR     r14, util_bitset        ; Copying attributes ?
        TST     r14, #util_noattr
        LDREQ   r5, util_attr
        MOVEQ   r0, #fsfile_WriteInfo   ; Write correct attributes (with correct info)
        BLEQ    CallFSFile_Given        ; Still on dest

40 ; ................ Common end for both copy mechanisms .....................

        BLVC    Copy_DeleteSourceAfterCopy ; r5 = source attributes

        BLVC    CopyFile_Verbose        ; Tell them copy action is complete

95
        LDR     r2, copy_area           ; Free the used block
        BL      SFreeCopy               ; Accumulates V
        EXIT


50 ; ++++++++++ Copy file by OpenIn/Create/OpenUp/GBPB/Close/WriteInfo ++++++++

51 ; Loop till we get some workspace - IRQ processes may be altering RMA size

; Clip request against largest source so far
; Some sources won't alter size under interrupt

        LDR     r4, copy_userbuffersize
 [ UseDynamicAreas
	LDR	r14, copy_dynamicsize
 |
        LDR     r14, copy_wimpfreesize
 ]
        CMP     r4, r14
        MOVLO   r4, r14
        LDR     r14, copy_rmasize
        CMP     r4, r14
        MOVLO   r4, r14
        LDR     r14, copy_aplsize
        CMP     r4, r14
        MOVLO   r4, r14

; Most efficient now to round our request down to 1K bdy if possible to get
; the best out of buffering whole sectors on D format discs

        CMP     r4, #1024
        BICHI   r4, r4, #(1024-1) :AND: &FF00
        BICHI   r4, r4, #(1024-1) :AND: &00FF
 [ debugcopy
 DREG r4, "initial max block after rounding = "
 ]

        CMP     r4, #0                  ; Now failed totally? >>>a186<<<
        MOVEQ   r0, #ModHandReason_Claim ; VClear
        MOVEQ   r3, #&80000000          ; So make ludicrous claim to get
        SWIEQ   XOS_Module              ; a reasonable error message
        BLVS    CopyErrorExternal
        EXIT    VS

        LDR     r14, copy_userbuffersize
        CMP     r14, r4
        LDRHS   r14, copy_userbuffer
        BHS     %FT60                   ; [use punter's buffer]

 [ UseDynamicAreas
        LDR     r14, copy_dynamicsize
 |
        LDR     r14, copy_wimpfreesize
 ]
        CMP     r14, r4
        BLO     %FT52

 [ UseDynamicAreas
	LDR	r1, copy_dynamicsize
	LDR	r2, copy_dynamicarea
 |
        MOV     r0, #1
        MOV     r1, r4
 [ debugcopy
 DREG r0,"Wimp_ClaimFreeMemory: r0 = ",cc
 DREG r1,", r1 = "
 ]
        SWI     XWimp_ClaimFreeMemory
 [ debugcopy
 DREG r2, "WimpAddr = "
 DREG r1, "WimpSize = "
 ]
        STR     r2, copy_wimpfreearea
 ]
        CMP     r2, #0
        BNE     %FT60                   ; [use wimp buffer]

 [ :LNOT: UseDynamicAreas
        MOV     r14, #0                 ; The thing has changed its mind:
        STR     r14, copy_wimpfreesize  ; Don't reconsider this source
 ]


52      LDR     r14, copy_rmasize
        CMP     r14, r4
        BLO     %FT55

        MOV     r3, r4
 [ debugcopy
 DREG r3, "Trying to get space for GBPB buffer: "
 ]
        BL      SGetRMA
        EXIT    VS
        BNE     %FT60                   ; [block claimed; use rma]

        BL      SDescribeRMA            ; Recompute amount of rma left

55      LDR     r14, copy_aplsize       ; Will be zero if ~Q or unable to claim
        CMP     r14, r4
        BLO     %BT51                   ; [can't fit, so loop]

        BL      SClaimAPL               ; Out: r2 -> apl


60 ; Why is it so hard ???

 [ debugcopy
 DREG r2, "Got area for GBPB copy: ",cc
 DREG r3, ", "
 ]
        STR     r2, copy_area
        STR     r4, copy_blocksize

        MOV     r0, #open_read          ; Open source for read
        LDMIA   r7, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
        BL      OpenFileForCopy
        BVS     %BT95                   ; Deallocate block
        STR     r0, copy_srchandle

        LDR     r14, util_bitset        ; >>>a186<<< addition
        TST     r14, #util_peekdest
        BNE     %FT61                   ; Already got dest into suitable state

        ; If not util_peekdest then EnsureDestFileWriteable after opening source
        BL      CopyFile_EnsureDestFileWriteable ; Get to dest; maybe unlock
        BVS     %FT91                   ; Close source       >>>a186<<< fix vvv
        BNE     %FT91                   ; [don't copy: close source]
        B       %FT62

61
        BL      Copy_PromptDest         ; Still need to get to dest though

62
 [ debugcopy
 DLINE "ok - writing dest file"
 ]
        LDMVCIA r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
        MOVVC   r0, #fsfile_Create      ; Create new file with wrong load,exec
        LDRVC   r2, DeadMeat            ; so that if copy breaks down (eg.
        MOVVC   r3, r2                  ; no reply, we can restart a copy
        MOVVC   r4, #0                  ; newer. Use right length though
        LDRVC   r5, util_length         ; r4,r5 = pseudo-start,end addresses
        BLVC    AssessDestinationForPath
        BLVC    CallFSFile_Given        ; Still on dest.
        BVS     %FT91                   ; Close source

; Both source and dest are now files

        MOV     r0, #open_write + open_read ; Open dest for update
; ***^  LDMIA   r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
; ***^  BL      AssessDestinationForPath
        BL      OpenFileForCopy
        BVS     %FT91                   ; Close source
        STR     r0, copy_dsthandle

        ADR     r9, gbpb_memadr         ; Prepare for loop
        LDR     r5, util_length         ; n_left := size(src)

; Loop copying from one to t'other. NEVER have the r5 = 0 case, always OSFiled

; n_left := size(src)
; WHILE n_left > 0 DO
;   n_to_do := min(nleft, ?buffer)
;   readatptr(buffer, n_to_do)
;   writeatptr(buffer, n_to_do)
;   n_left -:= n_to_do
; OD

70      CMP     r5, #0                  ; VClear
        BEQ     %FT86                   ; [close dest only, src already closed]

        LDR     r14, copy_blocksize
        CMP     r5, r14                 ; Is n_left > ?buffer
        MOVLS   r3, r5
        MOVHI   r3, r14
        CLRV                            ; Copy_PromptSource accumulates V, could be set for files > 2G 
        SUB     r5, r5, r3              ; n_left -:= n_to_do (Exactly 0 if end)

        MOV     r10, r3
        LDR     r1, copy_srchandle
        LDR     r2, copy_area
        STMIA   r9, {r2, r3}

        BL      Copy_PromptSource
        MOVVC   r0, #OSGBPB_ReadFromPTR
        BLVC    Xfer_ReadBytes
        BVS     %FT85                   ; [close both files]

        CMP     r5, #0                  ; No more to do after this xfer? VClear
        BLEQ    Copy_CloseSrc
        BVS     %FT86                   ; [close dest only, src already closed]

        MOV     r3, r10                 ; Restore n_to_do
        LDR     r1, copy_dsthandle
        LDR     r2, copy_area
        STMIA   r9, {r2, r3}

        BL      Copy_PromptDest
        MOVVC   r0, #OSGBPB_WriteAtPTR
        BLVC    Xfer_WriteBytes
        BVC     %BT70                   ; Loop 'till bored
                                        ; else drop thru to close both


85      BL      Copy_CloseSrc           ; Accumulate V (src may be closed here
                                        ; if we got error in saving last bytes)

86      BL      Copy_CloseDst
        BVS     %BT95                   ; Deallocate block

; Note that we are now on the dest, unlike before !!! >>>a816<<< fix

        LDR     r14, util_bitset        ; Copying attributes ?
        TST     r14, #util_noattr
        LDMIA   r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
        BL      AssessDestinationForPath
        BNE     %FT88                   ; in any case (still on dest)

        MOV     r0, #fsfile_WriteInfo   ; Write correct attributes + load/exec
        ADR     r14, util_load
        LDMIA   r14, {r2, r3, r4, r5}   ; util_load,_exec,dummy(_len),_attr
        B       %FT89                   ; Write then exit. VClear


88
        MOV     r0, #fsfile_ReadInfo    ; Pick up the old attributes
        BL      CallFSFile_Given
        ADRVC   lr, fileblock_length
        LDMVCIA lr, {r4-r5}
        LDRVC   r2, util_load
        LDRVC   r3, util_exec
        MOV     r0, #fsfile_WriteInfo   ; Write them back modified

89
        BLVC    CallFSFile_Given
        B       %BT40                   ; Common exit

91      BL      Copy_CloseSrc           ; Close source, accumulating V
        B       %BT95                   ; Deallocate block >>>a186<<< fix

DeadMeat
        DCD     &DEADDEAD               ; Picked up as word

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   V preserved or set

Copy_CloseSrc Entry "r0-r2"

        LDR     r1, copy_srchandle      ; Already closed ?
        TEQ     r1, #0
        EXIT    EQ                      ; Accumulates V

        MOV     r14, #0
        STR     r14, copy_srchandle     ; Now closed

        BL      Copy_PromptSource       ; Accumulates V, preserves r1

10
        SavePSR r2
        MOV     r0, #0
        SWI     XOS_Find                ; Don't call internal routine as we
        BLVS    CopyErrorExternal       ; may have globalerror set, and the
        RestPSR r2, VC                  ; flushing code sets V if globalerror
        EXIT                            ; was set at all

; .............................................................................
; Don't need to do same trick with file handle for CloseDest

Copy_CloseDst ALTENTRY

        BL      Copy_PromptDest         ; Accumulates V

        LDR     r1, copy_dsthandle      ; Close dest
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyDirectory
; =============

; Copy whole directory contents
; Fullnames of dirs set up in desc^.name; info read

; In    r7 = dir desc^, directory exists

; Out   Only r7, r8, wp preserved
;       VC: directory copied, or skipped
;       VS: failed to copy directory, or aborted

CopyDirectory Entry

 [ debugcopy
        DLINE   "CopyDirectory ",cc
 ]
        BL      CopyDirectory_Confirm
        EXIT    VS
        BLNE    Util_IncrementSkipped
        EXIT    NE

; First, create your directory !

        LDMIA   r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
 [ debugcopy
        DSTRING r1
 ]
        BL      Util_SpecialDir         ; If special, don't create: waste of
        BEQ     %FT50                   ; time and just looks plain silly
                                        ; Don't change access either. Dubious

        ; Ensure we're set up for this object
        BL      Copy_PromptDest
        BL      EnsureCanonicalObject

        CMP     r0, #object_file
        BHI     %FT20                   ; If a dir, don't ask to recreate
        BEQ     %FA99                   ; Error if dest is a file

        MOV     r0, #fsfile_CreateDir   ; No error if already exists
        LDR     r2, =FileType_Data      ; Create directories with type=Data
        BL      SReadTime               ; Stamped now
        MOV     r4, #35                 ; Sensible n entries (not random !)
                                        ; Will give &400 dirs on Net
                                        ; Ignored by FileCore
        BL      Copy_PromptDest
        BLVC    CallFSFile_Given        ; Doesn't corrupt util_attr
        BLVC    CopyDirectory_VerboseCDir
        EXIT    VS

20 ; Copy attr of source dir to dest dir iff access copying

        LDR     r14, util_bitset        ; Copying attributes ?
        TST     r14, #util_noattr

        BNE     %FT50
 [ {TRUE} ; don't change the filetype or user access attributes of destination
          ; directory - it may be an image file!
        MOV     r0, #fsfile_ReadInfo
        BL      CallFSFile_Given
        
        LDR     lr, =&FFF               ; mask of filetype bits
        LDR     r3, util_load
        AND     r2, r2, lr, LSL #8
        BIC     r3, r3, lr, LSL #8
        ORR     r2, r2, r3
        LDR     r3, util_attr
        AND     r5, r5, #3
        BIC     r3, r3, #3
        ORR     r5, r5, r3
        LDR     r3, util_exec
 |
        LDR     r2, util_load
        LDR     r3, util_exec
        LDR     r5, util_attr
 ]

;************** Horrendous kloodge to get round NetFS not being able to
; set the load and exec of a directory!
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #fsnumber_net
        MOVNE   r0, #fsfile_WriteInfo
        MOVEQ   r0, #fsfile_WriteAttr

        BL      CallFSFile_Given
        EXIT    VS
50
; Copy contents of dir, saving info on stack

        ADR     r1, util_totalsize      ; Save total so far this level
        LDMIA   r1, {r1, r14}
        Push    "r1, r14"

        BL      Util_IntoDirectory
        BLVC    CopyWildObject
        BL      Util_OutOfDirectory

        Pull    "r3, r4"                ; Restore size copied at this level
        ADR     r14, util_totalsize
        STMVCIA r14, {r3-r4}
        BVC     %FT60
        ADDS    r3, r3, r1
        ADC     r4, r4, r2              ; add here if error
        STMIA   r14, {r3-r4}
        SETV                            ; Ensure V still set
        EXIT
60
; Contents copied. Shall we (or can we) delete the source ?

        CMP     r0, #0                  ; Did we skip any in there ? VClear
        BLNE    Util_IncrementSkipped   ; Note that we've skipped this dir del!

        BLEQ    Copy_DeleteSourceAfterCopy

        BLVC    CopyDirectory_Verbose   ; Tell them copy dir complete
        EXIT


; Destination is a file. Always an error

99      addr    r0, ErrorBlock_CopyDirOntoFile
        BL      CopyError
        EXIT

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; See if the destination file already exists or is a dir

; Out   Much corruption
;       r1, r6, fscb set up for dest

;       VS: error copied
;       VC, EQ: copy file
;       VC, NE: don't copy file

CopyFile_EnsureDestFileWriteable Entry

 [ debugcopy
 BL %FT00
 DLINE "EnsureDestFileWriteable returns ",cc
 ADRVS r0, %FT03
 BVS %FT04
 ADREQ r0, %FT01
 ADRNE r0, %FT02
04
 DSTRING r0, ""
 EXIT
01
 DCB "EQ: copy file", 0
02
 DCB "NE: don't copy file", 0
03
 DCB "error", 0
 ALIGN


00
 Entry
 DLINE "Copy_EnsureDestFileWriteable"
 ]
        LDMIA   r8, {r1, r6, fscb}      ; copy_name, copy_special, copy_fscb
        BL      Copy_PromptDest         ; when FileServer feels up to it
 [ debugcopy
        DSTRING r1, "Tail is "
        DREG    r6, "scb/special is "
        DREG    fscb, "fscb is "
 ]
        BLVC    EnsureCanonicalObject
        EXIT    VS

        TEQ     r0, #object_nothing     ; No possible objection to copy !
        EXIT    EQ                      ; EQ -> do it

        ; If is a file or source is a partition and is a partition
        TEQ     r0, #object_file
        BEQ     %FT20                   ; File may be locked, or not forcing
        LDR     lr, util_objecttype
        TEQ     lr, #object_file :OR: object_directory
        TEQEQ   r0, #object_file :OR: object_directory
        BEQ     %FT20

; Destination is a directory. Always an error

        addr    r0, ErrorBlock_CopyFileOntoDir
        BL      CopyError
        EXIT

10      BL      CopyErrorExternal
        EXIT                            ; VSet always



20 ; Destination is a file or

        LDR     r14, util_bitset        ; Is source newer than dest ?
        TST     r14, #util_newer
        BEQ     %FT65

 [ debugcopy
 DLINE "Copy if newer"
 ]
        ADR     r14, fileblock_load     ; Read load/exec of dest file
        LDMIA   r14, {r0, r4}           ; r0 = load, r4 = exec
        CMN     r0, #&00100000          ; Is dest dated ? CSet if so
 [ debugcopy
 BCS %FT00
 DLINE "destination file undated"
00
 ]
        BCC     %FT65                   ; Copy if not

        ADR     r14, copy_realload      ; Read load/exec of source file
        LDMIA   r14, {r2, r3}           ; r2 = load, r3 = exec
        CMN     r2, #&00100000          ; Is source dated ? CSet if so
 [ debugcopy
 BCS %FT00
 DLINE "source file undated"
00
 ]
        BCC     %FT65                   ; Copy if not

        AND     r0, r0, #&FF            ; Mask out junk from load addresses
        AND     r2, r2, #&FF            ; Comparison must be done unsigned !

 [ debugcopy
 DREG r2,"source datestamp is: ",cc,Byte
 DREG r3
 DREG r0,"destin datestamp is: ",cc,Byte
 DREG r4
 ]
        SUBS    r3, r3, r4              ; Another careful date comparison
        MOVNE   r3, #Z_bit              ; lo words first
        SBCS    r2, r2, r0              ; hi words next
 [ No26bitCode
        MRSEQ   r14, CPSR
        EOREQ   r14, r14, r3
        MSREQ   CPSR_f, r14
 |
        TEQEQP  r3, pc
 ]

        BHI     %FT65                   ; [yes, do copy]

        ADRLO   r2, fsw_is_less_recent
        ADREQ   r2, fsw_is_same_age     ; [equal datestamps]

; Destination is newer than (or same age as) source:
 [ False ; >>>a186<<<
;   If (c ~v) or (c v) then prompt + get input.
;   If (~c ~v) then tough luck; no info output
;   If (~c v) then print file blurb
 ]

        LDR     r14, util_bitset
 [ True ; >>>a186<<< see below
        TST     r14, #util_verbose
 |
        TST     r14, #util_verbose :OR: util_topconfirm
 ]
        BEQ     %FT70                   ; Tough if neither set ! Don't copy

        BL      Util_PrintNameNL
        BVS     %BT10

 [ True ; >>>a186<<< Don't ask the punter if datecmp fails. Sam request
        B       %FT70                   ; Don't copy
 |
        BVS     %BT10

        LDR     r14, util_bitset
        TST     r14, #util_topconfirm   ; Shall we prompt the user ?
        BNE     %FT60

        SWI     XOS_NewLine             ; [no. message ends]
        BVS     %BT10
        B       %FT70                   ; Don't copy

60      ADR     r0, fsw_Overwrite
        SWI     XOS_Write0
        BL      Util_GetConfirmYN       ; EQ -> do it
        BVS     %BT10
        EXIT    NE                      ; NE -> don't copy
        B       %FT85                   ; Override force, the punter has spoken
 ]

fsw_is_same_age                                 DCB "CC5", 0
fsw_is_less_recent                              DCB "CC6", 0
fsw_already_exists                              DCB "CC7", 0
fsw_already_exists_confirm                      DCB "CC8", 0
fsw_already_exists_and_is_locked                DCB "CC9", 0
fsw_already_exists_and_is_locked_confirm        DCB "CC10", 0

        ALIGN

65      LDR     r14, util_bitset        ; Forcing copy ?
        TST     r14, #util_force
        BNE     %FT85                   ; [yes]

 [ debugcopy
 DLINE "Not forcing"
 ]
; Not forcing:
;   If (c ~v) or (c v) then prompt + get input.
;   If (~c ~v) then tough luck; no info output
;   If (~c v) then print file blurb

        TST     r14, #util_verbose :OR: util_topconfirm
        BEQ     %FT70                   ; Tough if neither set ! Don't copy

        LDR     r5, fileblock_attr
        LDR     r14, util_bitset
        TST     r5, #locked_attribute   ; Locked ?
        BNE     %FT66

        ; Not locked
        TST     r14, #util_topconfirm
        ADREQ   r2, fsw_already_exists
        ADRNE   r2, fsw_already_exists_confirm
        B       %FT67

66
        ; Is locked
        TST     r14, #util_topconfirm
        ADREQ   r2, fsw_already_exists_and_is_locked
        ADRNE   r2, fsw_already_exists_and_is_locked_confirm

67
        BL      Util_PrintName
        BVS     %BT10

        LDR     r14, util_bitset
        TST     r14, #util_topconfirm
        BNE     %FT80

        ; Not confirming - message ends
        SWI     XOS_NewLine
        BVS     %BT10

70      BL      Util_IncrementSkipped
        CMP     pc, #0                  ; VClear
        EXIT                            ; NE -> don't copy

80      ; Confirm required
        BL      Util_GetConfirmYN       ; EQ -> do it
        BVS     %BT10
 [ True ; >>>a186<<< SKS just spotted bug, could give 'Nothing to copy' error
        BNE     %BT70                   ; [don't copy]
 |
        EXIT    NE                      ; NE -> don't copy
 ]


; The man from DelMonte, he say 'Yeh' ! - so ensure attributes ok for the copy

85      LDR     r5, fileblock_attr      ; Need to have WR~L to copy to file
 [ debugcopy
 DREG r5, "dest attributes are ",,Byte
 ]
        TST     r5, #locked_attribute   ; Locked ?
        BNE     %FT90                   ; If so, must force access

        AND     r14, r5, #(read_attribute+write_attribute) ; Already got wr ?
        TEQ     r14, #(read_attribute+write_attribute)
        EXIT    EQ                      ; If so, don't need to do access
                                        ; EQ -> do it

90      MOV     r5, #(read_attribute+write_attribute)

        ; Zap load and exec to deadmeat too
        LDR     r2, DeadMeat
        MOV     r3, r2
        MOV     r0, #fsfile_WriteInfo

        BL      CallFSFile_Given        ; Got to dest already
        CMPVC   r0, r0                  ; EQ -> do it
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r5 = source object attributes

Copy_DeleteSourceAfterCopy Entry "r1"

 [ debugcopy
 DLINE "Copy_DeleteSourceAfterCopy"
 ]
        LDR     r14, util_bitset        ; Deleting source ?
        TST     r14, #util_deletesrc
        EXIT    EQ

        LDR     r1, [r7, #copy_name]
        BL      Util_SpecialDir
        EXIT    EQ                      ; VClear. Don't try to delete $ etc.

        BL      Copy_PromptSource
        EXIT    VS

        TST     r5, #locked_attribute   ; Is source locked ?
        MOVNE   r5, #read_attribute :OR: write_attribute ; Take out attributes, esp L
        LDRNE   r2, DeadMeat
        MOVNE   r3, r2
        MOVNE   r0, #fsfile_WriteInfo
        BLNE    CallFSFile_Given_R7     ; Only if neccessary

        MOVVC   r0, #fsfile_Delete
        BLVC    CallFSFile_Given_R7     ; Still on source

        BLVC    Util_DecrementDirEntry  ; Must go back one in the dir, 'cos
        EXIT                            ; we've just deleted the one we read

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyFile_Confirm
; ================

; Ask the punter if he wants to do it (if dates allow)

; Out   VS: error
;       VC, EQ -> do it
;       VC, NE -> don't do it

CopyFile_Confirm Entry "r0, r1, r2"

        BL      Util_DateRange          ; See if dates allow it
        EXIT    NE

        ADR     r1, fsw_copy_file_as
        ADR     r2, fsw_move_file_as


10      LDR     r14, util_bitset        ; Entered from below
        TST     r14, #util_confirm      ; Use this level's confirm bit here
        EXIT    EQ

        TST     r14, #util_deletesrc
        MOVEQ   r2, r1
        BL      Util_PrintName

        BLVC    Util_GetConfirm
        BLVS    CopyErrorExternal
        EXIT


fsw_copy_file_as        DCB     "CC11", 0
fsw_move_file_as        DCB     "CC12", 0
fsw_copy_directory_as   DCB     "CC13", 0
fsw_move_directory_as   DCB     "CC14", 0
                ALIGN

; .............................................................................

CopyDirectory_Confirm ALTENTRY

        ADR     r1, fsw_copy_directory_as
        ADR     r2, fsw_move_directory_as
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyFile_Verbose
; ================

; Copied the file, so print copied info if being verbose. nfiles++

; In    util_length = size of file copied. To be added to totalsize

; Out   VS: error

CopyFile_Verbose Entry "r0, r2, r3-r5, r9"

        LDR     r9, util_length         ; Always increment size copied
        ADR     r5, util_totalsize
        LDMIA   r5, {r3-r4}
        ADDS    r3, r3, r9
        ADC     r4, r4, #0
        STMIA   r5, {r3-r4}

        BL      Util_IncrementFiles_TestVerbose
        EXIT    EQ                      ; EQ -> ~verbose, so leave

        LDR     r14, util_bitset
        TST     r14, #util_deletesrc
        ADREQ   r2, fsw_file_copied_as
        ADRNE   r2, fsw_file_moved_as

        BL      Util_PrintNameNL
        BLVS    CopyErrorExternal
        EXIT


fsw_file_copied_as      DCB     "CC15", 0       ; File %0 copied as %1, %2
fsw_file_moved_as       DCB     "CC16", 0       ; File %0 moved as %1, %2
fsw_directory_copied_as DCB     "CC17", 0       ; Directory %0 copied as %1, %2
fsw_directory_moved_as  DCB     "CC18", 0       ; Directory %0 moved as %1, %2

fsw_Created_directory_space DCB "CC19", 0       ; Created directory %1

        ALIGN

; .............................................................................
;
; CopyDirectory_Verbose
; =====================

; Copied the directory; always print info

; In    util_popsize = size of dir copied. To be added to totalsize

; Out   VS: error

CopyDirectory_Verbose Entry "r0, r2, r3-r5, r9-r10"

        ADR     r9, util_popsize        ; Always increment size copied
        LDMIA   r9, {r9-r10}
        ADR     r5, util_totalsize
        LDMIA   r5, {r3-r4}
        ADDS    r3, r3, r9
        ADC     r4, r4, r10
        STMIA   r5, {r3-r4}

        BL      Util_IncrementDir_TestVerbose
        EXIT    EQ                      ; EQ -> ~verbose, so leave

        LDR     r14, util_bitset
        TST     r14, #util_deletesrc
        ADREQ   r2, fsw_directory_copied_as
        ADRNE   r2, fsw_directory_moved_as

        BL      Util_PrintName64
        SWIVC   XOS_NewLine
        BLVS    CopyErrorExternal
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; CopyDirectory_VerboseCDir
; =========================

; Created the directory, so print

; Out   VS: error

CopyDirectory_VerboseCDir Entry "r0, r2"

        LDR     r14, util_bitset
        TST     r14, #util_verbose
        EXIT    EQ                      ; EQ -> ~verbose

        addr    r2, fsw_Created_directory_space ; 'Created directory '
        BL      Util_PrintNameNL
        BLVS    CopyErrorExternal
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Copy_PromptSource
; =================

; Out   VC: ok
;       VS: error copied, or VSet on entry

Copy_PromptSource EntryS "r0, r1"

        MOV     r1, #copy_at_source

10      LDRB    r14, copy_src_dst_flag
        CMP     r14, r1                 ; VClear
        LDRNEB  r14, util_bitset
        TSTNE   r14, #util_promptchange
        BEQ     %FT99
        TEQ     r1, #copy_at_source
        ADREQ   r0, fsw_EnsureSourceMedia
        ADRNE   r0, fsw_EnsureDestMedia
        BL      PromptSpaceBar

        BLVS    CopyErrorExternal

99      STRVCB  r1, copy_src_dst_flag
        EXITS   VC                      ; Accumulate V
        EXIT

; .............................................................................
;
; Copy_PromptDest
; ===============

Copy_PromptDest ALTENTRY

        MOV     r1, #copy_at_dest
        B       %BT10


fsw_EnsureSourceMedia   DCB     "CC20", 0       ; Ensure source media present then press SPACE bar |M|J
fsw_EnsureDestMedia     DCB     "CC21", 0       ; Ensure destination media present then press SPACE bar|M|J

        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> string to print
;       r4 = subst param 0
;       r5 = subst param 1

; Out   VC: r0 corrupt
;       VS: r0 -> error, not copied

PromptSpaceBar Entry

        BL      message_gswrite02
        BLVC    ReadC_Escape
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadC_Escape
; ============

; Out   VC: r0 = char
;       VS: r0 -> error, not copied

ReadC_Escape Entry "r1, r2"

        MOV     r0, #15                 ; Flush current input buffer
        MOV     r1, #1
        SWI     XOS_Byte

        SWIVC   XOS_ReadC
        EXIT    VS
        BLCS    SAckEscape
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   r2 = size of largest block in rma that we can/ought to claim

SDescribeRMA Entry "r0, r3"

        MOV     r0, #ModHandReason_RMADesc ; Try RMA now
        SWI     XOS_Module              ; r2 := maxblocksize; r3 := totalsize
        BLVS    CopyErrorExternal
        EXIT    VS

        TEQ     r2, #0                  ; Can get r2 = -4 >>>a186<<<
        MOVMI   r2, #0

        CMP     r2, #4096 + 1024        ; If rma reasonably big, don't use all:
        SUBHI   r2, r2, #1024           ; leave some for filing systems
        BICHI   r2, r2, #(4096-1) :AND: &FF00
        BICHI   r2, r2, #(4096-1) :AND: &00FF
 [ debugcopy
 DREG r2, "rmaSize = "
 ]
        STR     r2, copy_rmasize        ; Remember this anyway
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   r1 = apl size
;       r2 -> apl

SClaimAPL EntryS "r0, r3"

        LDRB    r14, copy_owns_apl_flag
        TEQ     r14, #0
        BNE     %FT90                   ; [already own it, just resize]

        MOV     r14, #1                 ; apl is now dead meat and ALL mine!
        STRB    r14, copy_owns_apl_flag

        MOV     r0, #FSControl_StartApplication ; Start myself up
        addr    r1, anull               ; command tail
        addr    r2, Module_BaseAddr     ; CAO pointer
        addr    r3, FileSwitch_Title    ; command name
        SWI     XOS_FSControl

90      SWI     XOS_GetEnv              ; Where can we use up to ?
        MOV     r2, #&8000
        SUB     r1, r1, r2
 [ debugcopy
 DREG r1, "aplSize = "
 ]
        STR     r1, copy_aplsize        ; Remember this anyway
        EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SFreeCopy
; =========

; In    r2 = pointer to space (user, wimp, rma, or apl)

; Out   V accumulated, block freed to appropriate owner

SFreeCopy EntryS "r0-r2"

 [ debugcopy
 DREG r2, "SFreeCopy "
 ]
 [ UseDynamicAreas
        LDR     r14, copy_dynamicarea   ; Can be at &8000, but we MUST free it
 |
        LDR     r14, copy_wimpfreearea  ; Can be at &8000, but we MUST free it
 ]
        TEQ     r14, r2
        BNE     %FT50                   ; [must be RMA that we used then]

 [ :LNOT: UseDynamicAreas
        MOV     r0, #0
 [ debugcopy
 DREG r0,"Wimp_ClaimFreeMemory: r0 = ",cc
 DREG r1,", r1 = "
 ]
        SWI     XWimp_ClaimFreeMemory   ; Can't give error
 ]
        EXITS                           ; Restore caller V

50      LDR     r14, copy_userbuffer    ; User buffer ?
        TEQ     r14, r2
        EXITS   EQ                      ; Restore caller V

        TEQ     r2, #&8000              ; apl after all ?
        EXITS   EQ                      ; Keep apl claimed, it'll be 'freed'
                                        ; when we OS_Exit

        BL      SFreeArea               ; Accumulates V
        EXITS   VC                      ; Restore caller V
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 ] ; hascopy

        END
