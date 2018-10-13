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
; Sources.Encoding

;;----------------------------------------------------------------------------
;; Work out font's base encoding
;; This routine should be called AFTER MakePathName, and before getmapping_fromR6
;;----------------------------------------------------------------------------

; In    R6 -> font header block
;       [R6,#hdr_masterfont] = handle of master font (if this is a slave)
; Out   [R6,#hdr_base] = base encoding (>= 0 => use Outlines<n> and /Base<n>)

; This routine doesn't have to actually load the encoding file.

; Under the new mapping scheme, the base encoding is deduced by seeing which font file is present in the master font.
; This allows a given target encoding to be derived from various base encodings (or a font's private encoding).
; Mappings derived from the private encoding are stored in a separate hash table in the master font header.

GetFontBaseEncoding Entry "R1-R7", 64

        Debug   enc,"GetFontBaseEncoding",R6

        LDRB    R0,[R6,#hdr_masterfont]
        CMP     R0,#0                           ; if it's already a master font, set R7=R6 (same font header)
        MOVEQ   R7,R6
        BLNE    getfontheaderptr                ; R7 -> master font header
        BVS     %FT98

        LDR     R5,[R7,#hdr_base]
        CMP     R5,#base_unknown
        STRNE   R5,[R6,#hdr_base]               ; just copy this over
        BNE     %FT98

; Right - scan the font directory to see which type of base we're using

        LDR     R1,[R7,#hdr_PathName]
        Debug   enc,"master font,slave,pathname block",R7,R6,R1
        LDRB    R2,[R1,#pth_leafptr]
        ADD     R1,R1,#pth_name
        SUB     R2,R2,#1                        ; get rid of the terminating "."
        MOV     R14,#0
        STRB    R14,[R1,R2]                     ; R1 -> directory name without trailing dot

; Aargh - we must skip leading spaces in the pathname, as OS_GBPB gets it horribly wrong otherwise!

00      LDRB    R14,[R1]
        CMP     R14,#" "
        ADDEQ   R1,R1,#1
        BEQ     %BT00

        DebugS  enc,"master font pathname",R1

        MOV     R0,#OSGBPB_ReadDirEntries
        MOV     R2,SP
        MOV     R4,#0
        MOV     R5,#64
        ADR     R6,intmetstar                   ; "IntMet*" - wildcarded name to search for

01      MOV     R3,#1
        SWI     XOS_GBPB
        BVS     %FT20
        CMP     R3,#0
        RSBLES  R14,R4,#0                       ; might need to do it again if R3=0, R4>-1
        BLE     %BT01

        CMP     R3,#1
        MOVLT   R5,#-1                          ; assume "IntMetrics" if none found (shouldn't happen anyway)
        BLT     %FT20

; Scan the IntMet* name to see if it ends with a decimal number

        DebugS  enc,"IntMet* name returned",R2

        MOV     R1,R2
02      LDRB    R14,[R1,#1]!                    ; assume at least one char before the suffix
        CMP     R14,#0
        MOVEQ   R5,#-1
        BEQ     %FT20
        CMP     R14,#"0"
        RSBGES  R14,R14,#"9"
        BLT     %BT02

        MOV     R0,#10
        SWI     OS_ReadUnsigned                 ; R2 = base (0..)
        MOV     R5,R2

; Restore master font pathname block

20      LDR     R1,[R7,#hdr_PathName]
        LDRB    R2,[R1,#pth_leafptr]
        ADD     R1,R1,#pth_name
        SUB     R2,R2,#1                        ; restore the terminating "."
        MOV     R14,#"."
        STRB    R14,[R1,R2]

        LDR     R6,[SP,#64+5*4]                 ; whoa!

        BVS     %FT98

; If we didn't find a base encoding number, check for the presence of a private encoding file

        CMP     R5,#0
        BGE     %FT30

        Push    "R7"
        ADR     R7,encodingfname
        BL      constructname                   ; R1 -> path of font's private encoding file (if present)
        MOVVC   R0,#OSFile_ReadNoPath
        SWIVC   XOS_File
        Pull    "R7"
        BVS     %FT98

        TEQ     R0,#object_file
        MOVEQ   R5,#base_private                ; we still don't know (or care) if it's UCS only or not
        MOVNE   R5,#base_default

30      STR     R5,[R7,#hdr_base]
        STR     R5,[R6,#hdr_base]

        Debug   enc,"New font,master,hdr_base",R6,R7,R5
98
        EXIT

;;----------------------------------------------------------------------------
;; Construct mapping block from two encoding files
;;----------------------------------------------------------------------------

; In    R6 -> font header block
;       [R6,#hdr_encoding] = identifier of encoding
; Out   R1 -> mapping index within map block (in font cache)
;       R1 = 0 if mapping was direct (ie. no remapping required)
;       [R6,#hdr_base] = base encoding or alphabet, depending on whether this is a direct mapping
;       R6 relocated if necessary
;       encoding block is marked newest and brought to the head of its hash chain (essential for deleteblock)

HashIndexSize   *       64

                ^       0
hash_idaddr     #       4                       ; pointer to identifier string
hash_code       #       4                       ; character code this represents
hash_link       #       4                       ; offset from hash table to next entry in hash chain
hash_ordlink    #       4                       ; offset from hash table to next entry in order chain
hash_end        #       0

hashord_referenced   *  1 :SHL: 31              ; top bit set => this char has been referenced

                ^       0
srcdst_from     #       4                       ; external character code
srcdst_to       #       4                       ; internal character code
srcdst_end      #       0

; flag settings in srcdst_to, used during creation of the table

dst_is_uni        *     1 :SHL: 31              ; bit set => this char was set with a /uniXXXX identifier

; flag settings in srcdst_to, set up in the first pass through the table and used in the second pass

dst_new_sequence  *     1 :SHL: 31              ; bit set => start a new sequence (other bit indicates type)
dst_is_table      *     1 :SHL: 30              ; bit set => use lktab table, else it's a constant offset

                ALIGN
enc_utf8        DCB     "utf8"                  ; only the first 4 bytes are used
intmetstar      DCB     "IntMet*", 0
encodingfname   DCB     "Encoding", 0
                ALIGN

getmapping_fromR6 PEntry Mapping, "R0,R2-R5,R7-R11"

        ADD     R14,R6,#hdr_encoding
        LDMIA   R14,{R2-R4}
        DebugS  enc,"Get mapping for ",R14

        MOVS    R1,R2                           ; mapping is null if encoding name = 0,0,0
        MOVEQ   R14,#base_none
        STREQ   R14,[R6,#hdr_base]
        PExit   EQ

; [R6,#hdr_base] = master font's base encoding (base_default, base_private, or >= 0)
; base_private uses the encoding hash table stored in the master font header,
; while the others use the global encoding hash table (keyed on target and base encoding).

        LDRB    R0,[R6,#hdr_masterfont]
        CMP     R0,#0                           ; if it's already a master font, set R7=R6 (same font header)
        MOVEQ   R7,R6
        BLNE    getfontheaderptr                ; R7 -> master font header
        BVS     %FT98

        LDR     R5,[R7,#hdr_base]
        STR     R5,[R6,#hdr_base]               ; copy this across for convenience later

; check for the target encoding being "glyph" - use a direct mapping in this case

42

; Now scan the hash table to see if the given target/base encoding mapping is already present.
; If R5 = base_private, we use the hash table in the master font header, otherwise we use the global hash table

        EOR     R14,R2,R3,ROR #2                 ; this hash function gets all 96 bits involved in bits 0..3
        EOR     R14,R14,R4,ROR #4
        EOR     R14,R14,R14,ROR #16
        EOR     R14,R14,R14,ROR #8
        EOR     R14,R14,R14,ROR #4
        EOR     R14,R14,R5
        ASSERT  MapIndexSize = 16
        ASSERT  ?hdr_mapindex = 4*4
        Debug   enc,"hdr_base encoding",R5
        CMP     R5,#base_private
        ANDNE   R14,R14,#15
        LDRNE   R10,cacheindex                   ; use global hash table (16 entries)
        ADDNE   R10,R10,#cache_mapindex
        ANDEQ   R14,R14,#3                      ; use master font's private hash table (4 entries)
        ADDEQ   R10,R7,#hdr_mapindex

        Debuga  enc,"Hash value =",R14
        Debug   enc,", registers",R2,R3,R4,R5

        LDR     R1,[R10,R14,LSL #2]!            ; R1 -> first map block in chain, R10 -> parent link
        STR     R10,stashed_mapindex            ; stash chain head anchor (for much later)

        MOV     R0,R10                          ; R0 = backlink

61      TEQ     R1,#0
        BEQ     getnewmap

        ADD     R14,R1,#map_encoding

        ASSERT  map_base = map_encoding + 12
        LDMIA   R14,{R7-R9,R11}

        Debuga  enc,"Map block at",R1
        Debug   enc,", registers",R7,R8,R9,R11
        TEQ     R2,R7
        TEQEQ   R3,R8
        TEQEQ   R4,R9
        TEQEQ   R5,R11
        ADDNE   R0,R1,#map_link                 ; R0 = backlink
        LDRNE   R1,[R1,#map_link]               ; R1 -> next block
        BNE     %BT61

; bring this block to the front of the age list: must also ensure that it's at the head of the linked list

        TEQ     R0,R10                          ; EQ => this is the first encoding in the list
        BEQ     %FT62

        Debug   enc,"Moving encoding to front of list: prev,curr,head =",R0,R1,R10

        LDR     R7,[R1,#map_link]!              ; remove this block from chain
        STR     R7,[R0]
        TEQ     R7,#0
        STRNE   R0,[R7,#std_anchor]

        LDR     R7,[R10]                        ; we know the chain is not null, as we weren't at the head
        STR     R1,[R7,#std_anchor]
        STR     R7,[R1],#-map_link
        STR     R1,[R10]                        ; put this block at head of list
        STR     R10,[R1,#std_anchor]
62
        MarkAge R1,R7,R8                        ; bring to front of age list

        ; direct mapping block not required under the new scheme (it would be spotted earlier)
        ADD     R1,R1,#map_lookup               ; R1 -> lookup table (external -> internal character codes)

        Debug   enc,"R1 -> map at",R1
        CLRV
        PExit

; OK, this is the big one!  Construct a map block from an encoding and its base

getnewmap
        Debug   enc,"Get new map"

        BL      grabblock_init                  ; set up pointers for grabblock_claim

        ADD     R1,R6,#hdr_encoding             ; In  R1 -> id of target encoding
        STR     R1,currentencoding
        MOV     R9,#lfff_encoding               ;     R9 => look for encodings, not fonts
        BL      findblockfromID_noqual          ; Out R2 -> encoding block, error if not found

        Debug   enc,"encoding block at",R2

        BLVC    getencodingpath                 ; In R2 -> encoding block, Out R1 -> full filename
        BLVC    getencodingfilelength           ; R4 = length of encoding file

        ADDVC   R3,R4,#1                        ; R3 = space used for first file
        BLVC    grabblock_claim                 ; R2 -> block

        BLVC    loadencodingfile                ; R2 -> where to load file, R4 = length
        BVS     %FT99

        MOV     R9,R2                           ; R9 -> start of target encoding (for later)

; Old system: Look in target encoding to see what the base encoding is
; New system: The base encoding is worked out by looking at the files in the actual font directory

; this encoding is based on another - load it in
; R6 -> slave font header

        LDR     R2,[R6,#hdr_encoding]
        LDR     R14,enc_utf8
        EORS    R2,R2,R14
        MOVNE   R2,#1                           ; 1 => target encoding is NOT unicode
        STR     R2,isnt_unicode                 ; 0 => target encoding IS unicode

        BL      getbaseencodingpath             ; R1 -> filename of base encoding, or error if none
        BLVC    getencodingfilelength           ; R4 = length of this second file

; we are now in a position to work out the required amount of memory in the font cache

        ADDVC   R3,R4,#1                        ; R3 = size required for second file
        BLVC    grabblock_claim
        BLVC    loadencodingfile                ; R2 -> where to load file, R4 = length
        BVS     %FT99

; count number of identifiers in base encoding, so we know how much space to reserve for the hash table

        Push    "R2,R9"                         ; stacked R2 -> base encoding file, R9 -> target encoding file

        MOV     R8,#0                           ; R8 = size of hash table required
        MOV     R9,#0                           ; R9 = size of srcdst table required (at least initially)
        LDR     R3,isnt_unicode

        BL      findidentifier                  ; R2 -> first identifier, or error
        BVS     %FT11

01      LDRB    R14,[R2]
        TEQ     R14,#"."                        ; ignore ".notdef" entries
        BEQ     %FT02

        CMP     R10,#-1                         ; need hash entry for non "uniXXXX" identifiers
        TEQNE   R3,#1                           ; or if target encoding not unicode
        ADDEQ   R8,R8,#hash_end
        ADDNE   R9,R9,#srcdst_end               ; need srcdst entry if uniXXXX and unicode

02      BL      findnextidentifier              ; R2 -> first identifier, or error
        BVC     %BT01
11
        Pull    "R2"                            ; go back to the start
        CLRV

;       CMP     R8,#MaxChars       ; CLRV       ; this limit no longer applies!
;       BLGT    xerr_toomanyids
;       ADDVS   SP,SP,#4                        ; ---- correct stack!!!
;       BVS     %FT99

; reserve space at end of cache - we need the actual block, plus a 64 word hash table and 12 bytes per entry
; also leave

        Debuga  enc,"Base encoding contains",R8
        Debuga  enc," non-uni identifiers and",R9
        Debug   enc," uni identifiers"

        PushP   "Saving font header pointer",R6

        MOV     R6,#map_end + HashIndexSize*4
        ADD     R6,R6,R8                        ; add space for hash table
        ADD     R6,R6,R9                        ; add space for (initial) size of srcdst table
        Debug   enc,"Block size with space for hash table is",R6
        BL      reservecache                    ; R6 -> block, size overlarge (will be reduced later)
        ADDVS   SP,SP,#4                        ; ---- correct stack!!!
        BVS     %FT90

; now go through the base encoding, building up a set of hash table entries and links
; identifiers of the form "uniXXXX" are not put in the hash table, but instead go directly into the source list

; NOTE: target encoding file ptr is already stacked at this point

        ADD     R7,R6,#map_end + HashIndexSize*4
        ADD     R7,R7,R8                        ; R7 -> srcdst table
        MOV     R9,R7                           ; R9 -> next srcdst entry to add (ie. end of list - empty so far)

        ADD     R8,R6,#map_end                  ; R8 -> end of real block (hash table)
        MOV     R14,#0
        MOV     R3,#HashIndexSize-1
02      STR     R14,[R8,R3,LSL #2]              ; initialize hash table to 0
        SUBS    R3,R3,#1
        BPL     %BT02

; hash table header offset have been set to zero: now fill in the hash table from the base encoding

        ADD     R3,R8,#HashIndexSize*4          ; R3 -> free space for hash links
        MOV     R4,#0                           ; R4 = current dest index (for identifiers that don't have them)

        ADRL    R14,ordhashhead                 ; head of ordered hash chain
        STR     R14,ordhashtail                 ; pointer to hash_ordlink in most recent entry
        STR     R4,[R14]                        ; start off with empty list

        Debug   enc,"Hash table, hash free, srcdst table",R8,R3,R7

        BL      findidentifier                  ; R2 -> next identifier
        BVS     %FT04

03      CMP     R11,#-1
        MOVEQ   R11,R4                          ; if no explicit destination code, use the current counter
        ADDEQ   R4,R4,#1

        LDRB    R14,[R2]                        ; if it starts with ".", treat as ".notdef" and ignore it
        CMP     R14,#"."
        BEQ     %FT45

        CMP     R10,#-1                         ; if it's not a "uniXXXX" character, or the target encoding
        LDRNE   R14,isnt_unicode                ; isn't unicode, it goes into the hash table
        TEQNE   R14,#1
        BEQ     %FT44

        ; add straight into srcdst table

        ASSERT  srcdst_from = 0
        ASSERT  srcdst_to   = 4
        ASSERT  srcdst_end  = 8

        Debug   enc,"Adding uni srcdst entry",R10,R11

        ORR     R11,R11,#dst_is_uni
        STMIA   R9!,{R10,R11}                   ; no need to check for reaching end of block (already counted)
        B       %FT45

        ; add into hash table

44      BL      getidentifierhash               ; R0 = hash value of identifier in R2 (0..HashIndexSize-1)
        LDR     R14,[R8,R0,LSL #2]              ; R14 = offset from R8 to next
        SUB     R5,R3,R8
        STR     R5,[R8,R0,LSL #2]               ; store offset to this one at list head
        ASSERT  hash_idaddr = 0
        ASSERT  hash_code = 4
        ASSERT  hash_link = 8
        STMIA   R3!,{R2,R11,R14}                ; store pointer to identifier and link to next block

        ASSERT  hash_ordlink = 12
        ASSERT  hash_end = 16
        LDR     R14,ordhashtail
        STR     R5,[R14]                        ; R5 = offset from hash table to this entry
        STR     R3,ordhashtail                  ; pointer to most recent entry's hash_ordlink
        MOV     R14,#0
        STR     R14,[R3],#4                     ; stick in the ordered list link

45      BL      findnextidentifier              ; R2 -> next identifier
        BVC     %BT03
04

; Check that we used the amount of space we thought we would

      [ debugbrk :LOR: debugenc
        Debug   enc,"Expected end of hash table, actual",R7,R3
        TEQ     R3,R7
        BreakPt "Wrong encoding hash table size",NE

        LDR     R14,[R6,#std_size]
        BIC     R14,R14,#size_flags
        ADD     R14,R6,R14
        Debug   enc,"Block end, srcdst table used up to",R14,R9
        TEQ     R9,R14
        BreakPt "Wrong encoding block size",NE
      ]

; now go through the target encoding, looking up the names in the hash table and extracting the values

        Pull    "R2"                            ; R2 -> start of target encoding

        PullPx  "Font header ptr",R1
        ADDS    R1,R1,#hdr_encoding             ; R1 -> encoding name (in case of error) - clearing V
        STR     R1,currentencoding              ; for error reporting

        ASSERT  hdr_base = hdr_encoding + 12
        ASSERT  map_base = map_encoding + 12
        LDMIA   R1,{R3,R4,R10,R11}
        ADD     R14,R6,#map_encoding            ; stash encoding name for next time
        STMIA   R14,{R3,R4,R10,R11}

        LDR     R14,alphabet                    ; in case there's no outlines<base> file
        STR     R14,[R6,#map_alphabet]
        MOV     R14,#0
        STR     R14,[R6,#map_flags]

; Old version used to just generate a 256-word lookup table at this point.
; New version works in 4 stages:
;       (1) Identifiers that match hash table entries are added to the srcdst table (after the "uniXXXX" entries)
;       (2) The srcdst table is sorted
;       (3) A table of (start,n,offset) or (start,n,table) entries is generated, by looking for consecutive ranges
;       (4) An extra (start,n,table) is added for the unmatched characters from the base encoding
; NOTE: All this may require a considerable amount of memory juggling, as the block needs to be extended

        DebugS  enc,"Scanning target encoding ",R1

;       ADD     R9,R6,#map_index
;       MOV     R7,#256                         ; we require exactly 256 identifiers

        MOV     R4,#0                           ; R4 = current dest index (for identifiers that don't have them)

        BL      findidentifier
        B       %FT51

05      BL      findnextidentifier              ; R2 -> next identifier
51      BVS     %FT07                           ; DON'T report error if reached end

        SUBS    R10,R11,#0                      ; R10 = external code (index within encoding file)
        MOVLT   R10,R4                          ; use current count if there isn't an explicit code
        ADDLT   R4,R4,#1                        ; (note that the R10=uniXXXX value is not relevant in this case)

        ; if target identifier is ".notdef", don't even try to match with hash entry

        LDRB    R3,[R2]
        EORS    R3,R3,#"."                      ; assume anything starting with "." is ".notdef"

        BLNE    getidentifierhash               ; R0 = hash value
        LDRNE   R3,[R8,R0,LSL #2]               ; R3 = offset to head of list

06
        Debug   enc2,"hash offset",R3

        TEQ     R3,#0                           ; if not found, it's not an error - just don't add this entry in
        BEQ     %BT05
;       BLEQ    xerr_baseidnotfound
;       BVS     %FT85

        ADD     R3,R8,R3                        ; R3 -> hash entry
        LDR     R0,[R3,#hash_idaddr]            ; R0 -> identifier for this block
        BL      compareidentifiers
        LDRNE   R3,[R3,#hash_link]              ; R3 = offset from R8 to next entry
        BNE     %BT06

        LDR     R14,[R3,#hash_ordlink]
        ORR     R14,R14,#hashord_referenced     ; mark this entry as having been referenced
        STR     R14,[R3,#hash_ordlink]

        LDR     R11,[R3,#hash_code]             ; R11 = internal character code

        MOV     R5,#srcdst_end                  ; R5 = extra space required after end of R9
        BL      ensurespace_encoding            ; extend block, relocating R6,R8,R7,R9
        BVS     %FT85                           ; error (out of memory)

        Debug   enc,"add srcdst entry",R10,R11

        STMIA   R9!,{R10,R11}                   ; stash this entry and move on

        B       %BT05

;       SUBS    R7,R7,#1
;       BNE     %BT05

;       BL      findnextidentifier              ; insist on getting an error here (should have run out)
;       BVS     %FT07
;       BL      xerr_toofewids
;       B       %FT85

07

; If target encoding is Unicode, put all unmapped entries from the base encoding at &E000 onwards
; Note that we may need to extend the current block from time to time, as we haven't preallocated the space

        LDR     R14,isnt_unicode
        TEQ     R14,#0
        BNE     qq2

        MOV     R10,#&E000                      ; unmapped codes end up in the &E000..&EFFF range
        LDR     R3,ordhashhead
        B       qq1

qq      ADD     R3,R8,R3
        LDR     R14,[R3,#hash_ordlink]
        TST     R14,#hashord_referenced
        LDREQ   R11,[R3,#hash_code]             ; R11 = internal glyph code
        BIC     R3,R14,#hashord_referenced      ; R3 = offset from hash table (R8) to next entry
        BNE     qq1

        MOV     R5,#srcdst_end                  ; R5 = extra space required after end of R9
        BL      ensurespace_encoding            ; extend block, relocating R6,R8,R7,R9
        BVS     %FT85                           ; error (out of memory)

        Debug   enc,"add srcdst entry for unmapped code",R10,R11

        STMIA   R9!,{R10,R11}                   ; stash this entry and move on

        ADD     R10,R10,#1
        CMP     R10,#&F000                      ; if we run out of codes, dump the rest!
        BGE     qq2

qq1     CMP     R3,#0
        BNE     qq

qq2

; R7 -> srcdst table at end of block - now sort it into ascending order based on the external code

        BL      grabblock_close                 ; free RMA blocks - we don't need these any more

        Debug   enc,"Sorting srcdst table (start,end)",R7,R9

        BL      grabblock_init                  ; however, we do need an array of pointers for the sort

        SUBS    R3,R9,R7                        ; CLRV
        ASSERT  srcdst_end = 8
        MOV     R3,R3,LSR #1                    ; multiply by sizeof(word) / srcdst_end
        BL      grabblock_claim
        BVS     %FT075

        SUB     R0,R9,R7
        ASSERT  srcdst_end = 8
        TST     R2,#7:SHL:29                    ; bits set at top of R2? then use new SWI
        MOV     R0,R0,LSR #3                    ; R0 = number of elements to sort
        ORREQ   R1,R2,#(1:SHL:30):OR:(1:SHL:31) ; R1 -> array of pointers (bit 30 => build it, bit 31 => reorder items)
        MOVNE   R1,R2
        ADRL    R2,compare_srcdst               ; R2 -> comparison routine
        MOV     R3,R12                          ; R3 = workspace pointer
        MOV     R4,R7                           ; R4 -> array of objects to be sorted
        MOV     R5,#srcdst_end                  ; R5 = size of an object to be sorted
        MOVNE   R7,#(1:SHL:30):OR:(1:SHL:31)
        Debug   enc2,"Parameters to OS_HeapSort",R0,R1,R2,R3,R4,R5
        BNE     %FT073
        SWI     XOS_HeapSort
        B       %FT075
073     SWI     XOS_HeapSort32
        MOV     R7,R4

075     BL      grabblock_close                 ; free temporary index
        BVS     %FT85

; eliminate duplicate entries in the srcdst table (it screws up the counting algorithm)

; Note that because we sorted first by srcdst_from, then by srcdst_to, we will be removing
; the higher-numbered glyphs. Further note that the dst_is_uni flag makes the uniXXXX-set
; mappings have a negative srcdst_to value, so they will be first, and the duplicates removed
; will be the named ones, as required by Adobe's "Unicode and Glyph Names" document.

        ASSERT  dst_is_uni = 1 :SHL: 31

        MOV     R1,R7                           ; R1 = input pointer
        MOV     R2,R7                           ; R2 = output pointer
        MOV     R3,#-1                          ; previous srcdst_from value (skip this one if same)
        B       zz
yy
        ASSERT  srcdst_end = 8
        LDMIA   R1!,{R10,R11}
        CMP     R10,R3
        BICNE   R11,R11,#dst_is_uni
        STMNEIA R2!,{R10,R11}
        MOVNE   R3,R10                          ; for next time
zz      CMP     R1,R9
        BLO     yy

        MOV     R9,R2                           ; correct end pointer

; construct the final mapping structure, by looking for consecutive runs of defined glyphs
; this is done in two passes, so we know how much space the final lookup structure will occupy
; between passes, the srcdst table is moved so it ends just before the start of the non-constant offset array

        Debug   enc,"Counting size of lookup structure required"

        Push    "R7,R8"                         ; save pointer to srcdst table

        MOV     R1,#-1                          ; start of current run
        MOV     R2,#-1                          ; next expected value at end of current run
        MOV     R3,#-1                          ; last offset in current run
        MOV     R8,#0                           ; in lktab run, counts no. of identical entries at the end

        MOV     R4,#lookup_entry0               ; size of lkent array
        MOV     R5,#0                           ; size of non-constant offset array
        B       %FT15
08
        ASSERT  srcdst_from = 0
        ASSERT  srcdst_to   = 4
        ASSERT  srcdst_end  = 8
        LDMIA   R7!,{R10,R11}                   ; R10 = external code, R11 = internal code

        SUB     R11,R11,R10                     ; R11 = offset to internal code
        MOV     R11,R11,LSL #16
        MOV     R11,R11,LSR #16                 ; (modulo &10000)

        CMP     R10,R2                          ; GT => there's a gap, LT => duplicate (ignore), EQ => continue
        BLT     %FT15                           ; ignore this entry (must be bogus if duplicate)
        BGT     %FT12                           ; gap - start a new constant sequence

        SUB     R14,R2,R1
        ADD     R14,R14,#2
        TST     R14,#lkflag_istable             ; watch out for a sequence getting too long!
        BNE     %FT12

        CMP     R8,#0                           ; non-zero if we're in a lktab sequence
        BEQ     %FT09

; when in a lktab sequence, check for the last lot of offsets being constant - we might want to split into two here

        ADD     R5,R5,#lktab_end                ; add space for another offset table entry

        CMP     R11,R3                          ; is this one the same as the last one?
        MOV     R3,R11                          ; NB: always copy this now!
        MOVNE   R8,#1
        BNE     %FT14                           ; simple case - it's different from last time, so carry on

        ADD     R8,R8,#1                        ; another one is the same
        CMP     R8,#4
        BLT     %FT14                           ; so carry on

; split the sequence just before it became constant, and convert current sequence into a constant one

        ASSERT  srcdst_end = 8
        SUB     R1,R7,R8,LSL #3                 ; R8 includes this one, so [R7,-R8] is the start of the sequence
        LDR     R14,[R1,#srcdst_to]
        ORR     R14,R14,#dst_new_sequence       ; mark beginning of this sequence
        STR     R14,[R1,#srcdst_to]

        ADD     R4,R4,#lkent_end                ; add space for new sequence
        ASSERT  lktab_end = 2
        SUB     R5,R5,R8,LSL #1                 ; we don't need these after all (NB: R8 and R5 included this one)
        SUB     R1,R10,R8
        ADD     R1,R1,#1                        ; R1 = start of current (constant) sequence
        B       %FT13                           ; start constant sequence (R2 will be incremented)

; when in a constant sequence, check whether the offset has changed

09      CMP     R11,R3
        BEQ     %FT14                           ; if offset = lastoffset, extend the current sequence

; if no gap, but the offset's changed, decide whether we should start a new sequence,
; or convert the current sequence into a non-constant array

        SUB     R14,R2,R1                       ; how long was this sequence before this entry?
        CMP     R14,#4                          ; if longer than this,
        BGE     %FT12                           ; split the sequence into two

; convert current sequence into one with an offset table

        ADD     R14,R14,#1                      ; include the current entry
        ASSERT  lktab_end = 2
        ADD     R5,R5,R14,LSL #1                ; add space for sequence so far, plus this one

        ASSERT  srcdst_end = 8
        SUB     R3,R7,R14,LSL #3                ; go back to start of previous sequence and mark as using lktab
        LDR     R8,[R3,#srcdst_to]
        ORR     R8,R8,#dst_is_table
        STR     R8,[R3,#srcdst_to]

        MOV     R3,R11                          ; R3 = value to match with next time
        MOV     R8,#1                           ; we're in a variable sequence now, with 1 constant at the end

        B       %FT14                           ; continue with this sequence

; offset changed after >= 4 entries, or there was a gap - finish off old sequence and start new one

12      ADD     R4,R4,#lkent_end                ; add space for new sequence

        MOV     R1,R10                          ; R1 = start of current sequence
        MOV     R2,R1                           ; R2 = end of sequence (will be incremented very soon!)
        MOV     R3,R11                          ; R3 = last offset

        LDR     R14,[R7,#srcdst_to - srcdst_end]
        ORR     R14,R14,#dst_new_sequence       ; indicate start of a new sequence
        STR     R14,[R7,#srcdst_to - srcdst_end]

13      MOV     R8,#0                           ; R8 = 0 => it's a constant sequence (so far anyway!)

14      ADD     R2,R2,#1                        ; R2 = end of sequence + 1 (ie. next one to look for)

15      CMP     R7,R9
        BLO     %BT08

        Pull    "R7,R8"

; right - now R4 = size of lkent array, and R5 = size of lktab array
; we need to expand the current block, and move the srcdst table so it won't be overwritten
; it's probably best to just stick it at the very end

        Debug   enc,"Allocate space for lookup entry/table",R4,R5

        ADD     R5,R4,R5
        ADD     R5,R8,R5                        ; R5 -> end of lookup structure
        SUBS    R5,R5,R7                        ; R5 = extra space required
        BLE     %FT25                           ; nothing to do unless it's getting bigger!

        BL      ensurespace_encoding            ; relocates R6,R8,R7,R9 and word-aligns R5
        BVS     %FT85

; now move srcdst table up by R5 bytes (word-aligned), so it's at the end of the block

        ADD     R5,R9,R5                        ; R5 -> new end of table

        Debug   enc,"Copying srcdst table up from,end,to",R7,R9,R5

        Push    "R5"

20      LDR     R14,[R9,#-4]!
        STR     R14,[R5,#-4]!
        CMP     R9,R7
        BHI     %BT20

        MOV     R7,R5                           ; R7 -> start of srcdst table
        Pull    "R9"                            ; R9 -> end of srcdst table

; now go through the srcdst table again - this time for real!
; R8 -> start of lookup structure
; R4 = offset to lktab structure
; R7 -> start of srcdst table
; R9 -> end of srcdst table
; srcdst_to entries are marked with dst_new_sequence and dst_is_table bits

25      ADD     R5,R8,R4                        ; R5 -> end of lktab array (empty so far)

        SUB     R4,R4,#lookup_entry0
        ASSERT  lkent_end = 8
        MOV     R4,R4,LSR #3
        ASSERT  lookup_entries = 0
        STR     R4,[R8],#lookup_entry0          ; R8 -> start of lkent array

      [ debugenc
        Debug   enc,"**** Srcdst table is:"
        Push    "R7,R9"
xx      LDMIA   R7!,{R10,R11}
        Debug   enc,"----",R10,R11
        CMP     R7,R9
        BLO     xx
        Pull    "R7,R9"
      ]

        Debuga  enc,"Constructing",R4
        Debuga  enc," lookup entries at R8 =",R8
        Debug   enc," lktab at R5 =",R5

        Push    "R7"

        MOV     R1,#-1                          ; start of current run
        MOV     R2,#-1                          ; next expected value at end of current run
        MOV     R3,#-1                          ; shouldn't matter at this stage

        MOV     R4,R5                           ; R4 -> start of lktab array

        B       %FT35
30
        ASSERT  srcdst_from = 0
        ASSERT  srcdst_to   = 4
        ASSERT  srcdst_end  = 8
        LDMIA   R7!,{R10,R11}                   ; R10 = external code, R11 = internal code

        ASSERT  dst_new_sequence = 1 :SHL: 31   ; so CS will be set if we shift this up
        ASSERT  dst_is_table     = 1 :SHL: 30   ; so MI will be set if we shift this up
        MOVS    R14,R11,LSL #1                  ; CS => new sequence, MI => it's a lktab table

        SUB     R11,R11,R10                     ; R11 = offset to internal code
        MOV     R11,R11,LSL #16
        MOV     R11,R11,LSR #16                 ; (modulo &10000)

        BCC     %FT29                           ; continue current sequence

; start of new sequence: MI => it will use the lktab table

32
        ASSERT  lkent_n      = 4                ; R3 will hold the combination of the two
        ASSERT  lkent_offset = 6
        SUBMI   R3,R5,R4                        ; MI => R3 = lktab index, with lkoff_istable set
        ASSERT  lktab_end = 2
        MOVMI   R3,R3,LSL #16-1                 ; put index into top 16 bits (note the divide by 2)
        ORRMI   R3,R3,#lkflag_istable
        MOVPL   R3,R11,LSL #16                  ; PL => R3 = offset in top 16 bits

        CMP     R1,#-1                          ; was there a sequence before this one?
        SUBNE   R2,R2,R1                        ; doesn't include the current entry
        ASSERT  lkent_n = 4
        ASSERT  lkent_offset = 6
        LDRNE   R14,[R8,#lkent_n-lkent_end]     ; update 'n' value for previous entry
        ORRNE   R14,R14,R2                      ; R2 should be between 1 and &7FFF, so it won't knobble lkflag_istable
        STRNE   R14,[R8,#lkent_n-lkent_end]

        MOV     R1,R10                          ; R1 = start of this sequence

        ASSERT  lkent_min    = 0
        ASSERT  lkent_n      = 4
        ASSERT  lkent_offset = 6
        ASSERT  lkent_end    = 8
        STMIA   R8!,{R1,R3}
        Debug   enc,"Lookup entry (without n)",R1,R3

        MOV     R2,R1                           ; R2 = end of sequence (will be incremented very soon!)

; check whether we need to output another lktab entry

29      CMP     R10,R2                          ; GT => there's a gap, LT => duplicate (ignore), EQ => continue
        BLT     %FT35                           ; ignore this entry (must be bogus if duplicate)

        TST     R3,#lkflag_istable              ; flag for a lktab sequence
        ASSERT  lktab_end = 2
        STRNEB  R11,[R5],#1
        MOVNE   R14,R11,LSR #8
        STRNEB  R14,[R5],#1                     ; stash next lktab entry

34      ADD     R2,R2,#1                        ; R2 = end of sequence + 1 (ie. next one to look for)

35      CMP     R7,R9
        BLO     %BT30

; flush out last sequence (if any)

        CMP     R1,#-1                          ; was there a sequence before this one?
        SUBNE   R2,R2,R1                        ; doesn't include the current entry
        ASSERT  lkent_n = 4
        ASSERT  lkent_offset = 6
        LDRNE   R14,[R8,#lkent_n-lkent_end]     ; update 'n' value for previous entry
        ORRNE   R14,R14,R2
        STRNE   R14,[R8,#lkent_n-lkent_end]

        Pull    "R7"

; Now R8 should = R4, and R5 should = R7, if the tables have been filled as expected

        Debug   enc,"End of lookup_entries (R8) should = start of lktab (R4)",R8,R4
        Debug   enc,"End of lktab (R5) should = start of srcdst (R7)",R5,R7

; finished - reset size of block to correct value and link into map index

        ADD     R9,R5,#3                        ; R5 -> end of lktab array
        BIC     R9,R9,#3                        ; R9 -> end of block (word-aligned)

        Debug   enc,"Lookup table finished: R9 =",R9

70      SUBS    R14,R9,R6                       ; R14 = size of block (and clear V)
        ORR     R14,R14,#size_claimed           ; treat as permanently claimed for age purposes
        STR     R14,[R6,#std_size]

        Debug   enc,"Reset block to size (end)",R6,R14,R9

        LDR     R14,cacheindex
        STR     R9,[R14,#cache_free]

; comes here from direct map block creation: R6 -> block, font header pushed

100     LDR     R5,stashed_mapindex             ; R5 -> map hash chain head
        LDR     R9,[R5]
        STR     R6,[R5]
        STR     R5,[R6,#std_anchor]
        STR     R9,[R6,#map_link]!              ; R6 -> link in block
        TEQ     R9,#0
        STRNE   R6,[R9,#std_anchor]

        ADD     R1,R6,#map_lookup - map_link    ; R1 -> lookup structure (see lookup_entries etc.)
        Debug   enc,"Map lookup is at",R1

        PullP   "Recovering font header pointer",R6

;       BL      grabblock_close                 ; this is now done earlier

        CheckCache "Exit from getmapping_fromR6"

        CLRV
        PExit

; error exit - discard block and recover R6 from relocation stack

85
        DiscardBlock R6,R2,R14                  ; reset cachefree and remove block from age list
90
        PullP   "Recovering font header pointer",R6
99
        BL      grabblock_close                 ; preserves error state

98      STRVS   R0,[sp]
        PExit

;.............................................................................

; In    R0 -> first object
;       R1 -> second object
; Out   LT -> first object is less than second
;       GT -> first object is greater than second

compare_srcdst  ROUT

        LDR     R2,[R0,#srcdst_from]
        LDR     R3,[R1,#srcdst_from]
        CMP     R2,R3

        MOVNE   PC,LR

        LDR     R2,[R0,#srcdst_to]
        LDR     R3,[R1,#srcdst_to]
        CMP     R2,R3

        MOV     PC,LR

;.............................................................................

; In    R6 -> start of map block
;       R8 -> start of hash table
;       R7 -> start of srcdst table
;       R9 -> end of srcdst table
;       R5 = extra space required after R9
; Out   Required space will be available after R9
;       R6,R8,R7,R9 relocated as necessary
;       [R6,#std_size] updated to include data < R9+R5

ensurespace_encoding   Entry  "R1,R2"

        ADD     R5,R5,#3
        BIC     R5,R5,#3                        ; round up to whole number of words

        ADD     R1,R9,R5
        LDR     R14,fontcacheend
        SUBS    R1,R1,R14
        BLS     %FT90                           ; no relocation required

        Debug   cc,"**** Relocation in encoding generation ****"

        MOV     R1,R5                           ; amount required above and beyond the existing block
        CMP     R1,#std_end
        MOVLO   R1,#std_end                     ; allocate at least this much

        Debug   cc,"R6,R7,R8,R9,fontcacheend",R6,R7,R8,R9,#fontcacheend

        SUB     R8,R8,R6
        SUB     R7,R7,R6
        SUB     R9,R9,R6

        Push    "R5,R7,R8,R9"

; Right - now we need to link this block into the cache, so it can be relocated properly
; The block also needs to be locked, so it can't be deleted,
; and afterwards it will be removed from the structure again.

        LDR     R14,[R6,#std_size]              ; save old size flags
        Push    "R14"
        ORR     R14,R9,#size_locked             ; don't allow the block to be deleted!
        STR     R14,[R6,#std_size]

        LDR     R14,cacheindex
        ADD     R9,R6,R9
        STR     R9,[R14,#cache_free]            ; end of block is now end of cache

        MOV     R8,R6                           ; R8 will be relocated

        LDR     R5,stashed_mapindex             ; R5 -> map hash chain head
        LDR     R9,[R5]
        STR     R6,[R5]
        STR     R5,[R6,#std_anchor]
        STR     R9,[R6,#map_link]!              ; R6 -> link in block
        TEQ     R9,#0
        STRNE   R6,[R9,#std_anchor]
        Debug   cc,"stashed_mapindex, old head 1",R5,R9

        MOV     R6,R1                           ; R6 = amount of extra space required
        BL      reservecache2
        MOV     R6,R8                           ; R6 -> block once more

        Pull    "R14"
        STR     R14,[R6,#std_size]              ; restore old size flags

; Now remove the block from the encoding list (it will be linked back in later on, if required)

        LDR     R5,stashed_mapindex             ; R5 -> map hash chain head
        LDR     R9,[R6,#map_link]
        TEQ     R9,#0
        STRNE   R5,[R9,#std_anchor]
        STR     R9,[R5]
        MOV     R14,#0
        STR     R14,[R6,#std_anchor]            ; I don't know if this is necessary, but...
        Debug   cc,"stashed_mapindex, old head 2",R5,R9

        Pull    "R5,R7,R8,R9"

        ADD     R8,R6,R8
        ADD     R7,R6,R7
        ADD     R9,R6,R9

        Debug   cc,"R6,R7,R8,R9,fontcacheend",R6,R7,R8,R9,#fontcacheend

        EXIT    VS

90      ADD     R1,R9,R5                        ; R1 -> new cachefree
        SUB     R2,R1,R6                        ; R2 = new block size required

        LDR     R14,[R6,#std_size]
        AND     R14,R14,#size_flags             ; keep these!
        ORR     R14,R14,R2
        STR     R14,[R6,#std_size]

        LDR     R2,cacheindex                   ; must be present
        STR     R1,[R2,#cache_free]

        EXIT

;.............................................................................

; In    R1 -> full filename of encoding file being searched
;       R2 -> point in file reached so far
; Out   R2 -> start of identifier after this one, or error if none left
;       R11 = code associated with this identifier (-1 if none (ie. old-style PostScript identifier with "/"))
;       [baseencoding] = base encoding number if encountered in a comment

findnextidentifier Entry "R0,R3"

        Debug   enc2,"findnextidentifier: R2 =",R2

01      MOV     R3,R2                   ; R3 -> point reached so far
        BL      getcharfromR2           ; skips comments and analyses them
        BL      isalphanumeric          ; keep going till we've passed the first identifier
        BHI     %BT01
        BEQ     %FT99                   ; error if reached terminator

        TEQ     R0,#";"
        MOVNE   R2,R3                   ; step back so this character is re-read
        BNE     %FT10

; if it ends with ";", we need to skip to the end of the line, then skip to the next non-separator

02      LDRB    R0,[R2],#1
        CMP     R0,#32
        BHS     %BT02

        SUB     R2,R2,#1                ; in case this was the file terminator (0)
10
        PullEnv
        B       findidentifier          ; this will skip spaces and comments

99      BL      xerr_toofewids
        STRVS   R0,[sp]
        EXIT

;.............................................................................

; In    R1 -> full filename of encoding file being searched
;       R2 -> point in file reached so far
; Out   R2 -> start of next identifier, or error if none left
;       R11 = index of this identifier (-1 if none (ie. old-style PostScript identifier with "/"))
;       R10 = Unicode value of this identifier (-1 if identifier not of form "uniXXXX" or "uXXXX")
;       [baseencoding] = base encoding number if encountered in a comment

findidentifier Entry "R0,R1,R3"

        Debug   enc2,"findidentifier: R2 =",R2

        MOV     R10,#-1
        MOV     R11,#-1                 ; assume old format unless proved otherwise

02      BL      getcharfromR2           ; R0 = next char, R2 updated
        TEQ     R0,#"/"                 ; if found "/", we've done it
        BEQ     %FT50

        TEQ     R0,#0                   ; error if reached terminator
        BEQ     %FT99

        CMP     R0,#" "                 ; allow ctrl-chars and space as separators
        BLE     %BT02

; OK, we've found something that doesn't start with "/"
; Check for [ <hex2>; ] <hex4>; <identifier>
; Ignore the <hex2> if present, set R11 to <hex4>, and R2 -> <identifier>

        SUB     R2,R2,#1
        BL      readhex                 ; R11 = hex number, R0 = number of characters read, R2 -> one after ";"
        CMP     R0,#4
        EXIT    EQ                      ; found it - R2, R11 set up correctly

        CMP     R0,#2
        BNE     %FT98                   ; error

        BL      readhex
        CMP     R0,#4
        BEQ     %FT50                   ; found it - R2, R11 set up correctly

; Error - it's not "/<identifier>", and it's not [xx;]xxxx;<identifier>

98      SUB     R2,R2,#1
        BL      xerr_idwithoutslash     ; Identifier "xxx" does not start with "/"
        STRVS   R0,[sp]
        EXIT

99      BL      xerr_toofewids
        STRVS   R0,[sp]
        EXIT

; Check for identifier being of the form "uniXXXX", and set up R10 if so
; Also handle "uXXXX" to "uXXXXXXXX"

50      LDRB    R0,[R2]
        TEQ     R0,#"u"
        EXIT    NE

        LDRB    R0,[R2,#1]
        TEQ     R0,#"n"
        LDREQB  R0,[R2,#2]
        TEQEQ   R0,#"i"
        ADDEQ   R1,R2,#3
        ADDNE   R1,R2,#1

        MOV     R3,#0

60      BL      readhexdigitforuni      ; read as many hex digits as we can (must be upper-case)
        CMP     R0,#-1
        ADDNE   R3,R0,R3,LSL #4
        BNE     %BT60

        LDRB    R0,[R2,#1]
        SUB     R14,R1,R2               ; R14 = digits read + 3 or 1
        TEQ     R0,#"n"
        BNE     %FT70

; uniXXXX case - must have four digits
        TEQ     R14,#4+3
        EXIT    NE

80      LDRB    R0,[R1]                 ; check character after hex
        BL      isalphanumeric          ; mustn't be alphanumeric (mustn't match "/uni1234z")
        MOVCC   R10,R3                  ; fill in R10
        EXIT

; uXXXX case - must have four to eight digits, no leading zeros if 5 or more
70      CMP     R14,#8+1
        EXIT    HI                      ; >8 digits, no good
        CMP     R14,#4+1
        BEQ     %BT80                   ; =4 digits, fine
        EXIT    LO                      ; <4 digits, no good
        TEQ     R0,#"0"
        BNE     %BT80
        EXIT                            ; 5-8 digits with leading 0, no good


;.............................................................................

; In    R1 -> string pointer
; Out   R0 = hex value of character pointed to by R2 (-1 if not 0-9,A-F)
;       R1 -> next character, if this one was valid, else unchanged

readhexdigitforuni ROUT
        LDRB    R0,[R1],#1              ; R0 = character, advance pointer
        CMP     R0,#'0'                 ; < '0' no good
        BLO     %FT01
        CMP     R0,#'9'                 ; <= '9' OK
        SUBLS   R0,R0,#'0'
        MOVLS   PC,LR
        CMP     R0,#'A'                 ; < 'A' no good
        BLO     %FT01
        CMP     R0,#'F'                 ; <= 'F' OK
        SUBLS   R0,R0,#'A'-10
        MOVLS   PC,LR

01      MOV     R0,#-1                  ; return -1 for bad character
        SUB     R1,R1,#1                ; make R1 point at bad character (more intuitive)
        MOV     PC,LR


;.............................................................................

; In    R2 -> string
; Out   R11 = hex number read
;       R0 = number of hex digits, if properly terminated by ";"
;       R2 -> character after ";"

readhex Entry   "R1,R3"

        MOV     R3,R2                   ; R3 = initial pointer (used later)
        MOV     R1,R2                   ; R1 -> string to convert from
        LDR     R2,=&FFFF               ; R2 = max value (4 digits)
        LDR     R0,=16+(1:SHL:29)       ; R0 = base 16, with max value in R2
        SWI     XOS_ReadUnsigned        ; error => invalid

        MOVVC   R11,R2                  ; R11 = result value
        MOVVC   R2,R1                   ; R2 -> next char
        SUBVC   R0,R2,R3                ; R0 = char count

        LDRVCB  R14,[R2],#1
        MOVVS   R14,#0
        CMP     R14,#";"                ; must end with ";"
        MOVNE   R0,#-1                  ; R0 = -1 => error

        EXIT
        LTORG

;.............................................................................

; In    R2 -> start of identifier
; Out   R0 = hash value for identifier (0..HashIndexSize-1)

getidentifierhash EntryS "R2,R3"

        DebugS  enc2,"identifier =",R2

        MOV     R3,#0

01      BL      getcharfromR2           ; R0 = next char in identifier
        BL      isalphanumeric
        MOVHI   R14,R3,LSL #1
        EORHI   R3,R14,R3,LSR #5        ; gradually rotate the bytes WITHIN 6 bits
        EORHI   R3,R0,R3
        BHI     %BT01

; Check that HashIndexSize is a power of 2

        ASSERT  (HashIndexSize :AND: -HashIndexSize) = HashIndexSize

        AND     R0,R3,#HashIndexSize-1   ; R0 = hash value in range 0..HashIndexSize-1

        Debug   enc2,"hash value =",R0

        EXITS

;.............................................................................

; In    R2 -> current position in encoding file
; Out   R0 = next non-comment character in encoding file
;       R2 -> next character after that
;       [baseencoding] updated if "%%RISCOS_BasedOn <n>" encountered
;       [alphabet] updated if "%%RISCOS_Alphabet <n>" encountered

getcharfromR2 ROUT

        LDRB    R0,[R2],#1              ; exit if next char is not the comment symbol
        TEQ     R0,#"%"
        TEQNE   R0,#"#"                 ; allow % or # for comments
        MOVNE   PC,LR

        Entry   "R1,R3"

        TEQ     R0,#"%"
        BNE     %FT02                   ; just skip rest of comment unless it was a "%"

        ADR     R1,str_riscos
01      LDRB    R14,[R1],#1             ; see if we've matched the whole string yet
        TEQ     R14,#0
        BEQ     %FT03
        LDRB    R0,[R2],#1
        TEQ     R0,R14
        BEQ     %BT01

02      CMP     R0,#32                  ; skip rest of comment (up to control-char)
        LDRGEB  R0,[R2],#1
        BGE     %BT02
        EXIT                            ; return terminator of comment

03      LDRB    R0,[R2]                 ; check to see which one we should carry on with
        Debug   enc,"%%RISCOS_",R0
        CMP     R0,#"B"
        ADRLT   R1,str_alphabet         ;;
        ADRLT   R3,alphabet             ;;

31      LDRB    R14,[R1],#1             ; see if we've matched the whole string yet
        TEQ     R14,#0
        BEQ     %FT04
        LDRB    R0,[R2],#1
        TEQ     R0,R14
        BEQ     %BT31
        B       %BT02

04
        MOV     R0,#10                  ; R0 = default base (10)
        MOV     R1,R2                   ; R1 -> string
        SWI     XOS_ReadUnsigned        ; R1 -> terminator, R2 = value
        STRVC   R2,[R3]                 ; R3 -> where to store the result
        ADDS    R2,R1,#0                ; just ignore this if not a valid number
        LDRB    R0,[R2],#1              ; continue skipping comment from terminator of number
        B       %BT02

str_riscos      DCB     "%RISCOS_", 0
str_alphabet    DCB     "Alphabet ", 0
                ALIGN

;.............................................................................

; In    R0 = character code
; Out   EQ => character is 0 (EOF)
;       CS => character is alphanumeric
;       CC => character is not alphanumeric

isalphanumeric Entry "R0,R1"

        CMP     R0,#0                   ; EQ, CS => EOF
        EXIT    EQ

        ADR     R1,alphanumtab
        LDRB    R1,[R1,R0,LSR #3]       ; R1 = flag byte
        AND     R0,R0,#7                ; R0 = bit number
        MOV     R1,R1,LSR R0            ; R1 bit 1 = value required
        AND     R1,R1,#1
        MOV     R1,R1,LSL #1
        CMP     R1,#1                   ; HI => alphanumeric, LO => not alphanumeric

        EXIT

; PostScript alphanumeric characters are anything except ( ) < > [ ] { } / % and white space
; Characters 127 and above should not appear in PostScript files - I treat them all as non-alpha
; NOTE: ";" is also not alphanumeric, since they themselves use that in their UCS encoding files

alphanumtab
        DCD     2_00000000000000000000000000000000              ; characters &1F..&00
        DCD     2_10100111111111110111110011011110              ; characters &3F..&20
        DCD     2_11010111111111111111111111111111              ; characters &5F..&40
        DCD     2_11010111111111111111111111111111              ; characters &7F..&60
        DCD     0, 0, 0, 0                                      ; can't use &80..&FF

;.............................................................................

; In    R2 -> start of identifier #1
;       R0 -> start of identifier #2
; Out   EQ => identifiers match, NE => they don't

compareidentifiers Entry "R0,R2,R3,R5"

        DebugS  enc2,"compareIDs: #1 =",R2
        DebugS  enc2,"            #2 =",R0

        MOV     R3,R0                   ; R3 -> identifier #2

01      LDRB    R0,[R2],#1              ; no need to look for comments in here
        BL      isalphanumeric
        MOVLS   R0,#0

        MOV     R5,R0                   ; R5 = character from identifier #1

        LDRB    R0,[R3],#1              ; no need to look for comments in here
        BL      isalphanumeric
        MOVLS   R0,#0                   ; R0 = character from identifier #2

        TEQ     R0,#0
        TEQEQ   R5,#0
        EXIT    EQ                      ; EQ => identifiers match

        TEQ     R0,R5
        BEQ     %BT01

        EXIT                            ; NE => identifiers don't match

;.............................................................................

; In    R6 -> font header
;       [R6,#hdr_base] indicates the base encoding
;       R1 -> full filename of target encoding (in case error message required)
; Out   R1 -> full filename of base encoding

getbaseencodingpath Entry "R2,R7,R9", 32 ; use 32 bytes on the stack (automatically removed by EXIT)

        LDR     R2,[R6,#hdr_base]
        Debug   enc,"getbaseencodingpath: R6, hdr_base",R6,R2
        CMP     R2,#base_private
        BEQ     %FT10

        CMP     R2,#0                   ; generate /Base<n> encoding name
        BGE     %FT15

        CMP     R2,#base_default
        ADREQ   R1,str_default          ; R1 -> "/Default"
        BLNE    xerr_nobaseencoding     ; should have been >=0, or base_default, or private
        B       %FT20

10      ADRL    R7,encodingfname
        BL      constructname           ; R1 -> <font dir>.Encoding
        B       %FT30

15      ADRVC   R0,str_baseenc
        MOVVC   R1,sp                   ; may need up to 10 + max length of 32-bit cardinal
        BLVC    copy_r0r1_suffixR2      ; R1 -> "/Base<n>" (on stack)

20      MOVVC   R9,#lfff_encoding
        BLVC    findblockfromID_noqual  ; R2 -> block for "/Base<n>" (may not be in same directory)
        BLVC    getencodingpath         ; R1 -> full filename of base encoding

30      LDMVCIA sp,{R2,R9,R14}
        ADRVC   R0,encbuffer2
        STMVCIA R0,{R2,R9,R14}
        STRVC   R0,currentencoding      ; for subsequent error reporting

        DebugS  enc,"getbaseencodingpath returns",R1

        EXIT

str_baseenc     DCB     "/Base", 0
str_default     DCB     "/Default", 0
                ALIGN

;.............................................................................

; In    R2 -> encoding block
; Out   R1 -> full filename (in fontfilename)
;
; NB: Does not check for overflow - this can be done when scanning the prefixes

getencodingpath Entry ""

        LDR     R0,[R2,#lff_prefixaddr]        ; R14 -> prefix block
        ADD     R0,R0,#lfpr_prefix
        ADR     R1,fontfilename
        BL      copy_r0r1

        ADR     R0,str_Encodingsdot
        BL      copy_r0r1

        LDR     R0,[R2,#lff_identaddr]
        BL      copy_r0r1

        ADR     R1,fontfilename
        DebugS  enc,"encoding pathname",R1

        CLRV
        EXIT

str_Encodingsdot        DCB     "Encodings.", 0
                        ALIGN

;.............................................................................

; In    R1 -> full filename of encoding file
; Out   R4 = length of encoding file
;       Length returned as 0 if object does not exist, or is a directory

getencodingfilelength Entry "R2,R3,R5"

        MOV     R0,#OSFile_ReadNoPath
        SWI     XOS_File
        TEQ     R0,#object_file         ; if not a file, pretend it's zero-length
        MOVNE   R4,#0                   ; (the load operation should fail)

        Debug   enc,"encoding file length =",R4

        EXIT                            ; can still return errors

;.............................................................................

; In    R1 -> full filename of encoding file
;       R2 -> where to load file
;       R4 = length of buffer
; Out   [R2..] = file contents, with a 0 stuck on the end as a terminator

loadencodingfile Entry "R1-R5"

        Debug   enc,"Loading encoding file at addr,size",R2,R4

        MOV     R0,#OSFile_LoadNoPath
        MOV     R3,#0                   ; load at specified address
        SWI     XOS_File

        DebugE  enc,"Error from loadencodingfile:"

        LDRVC   R2,[sp,#1*4]
        MOVVC   R14,#0
        STRVCB  R14,[R2,R4]             ; terminate file data

        EXIT

;-----------------------------------------------------------------------------

; Error reporting routines

        MakeErrorBlock FontBadEncodingSize
        MakeErrorBlock FontTooFewIDs
        MakeErrorBlock FontTooManyIDs
        MakeErrorBlock FontNoBaseEncoding
        MakeErrorBlock FontMustHaveSlash
        MakeErrorBlock FontIdentifierNotFound

xerr_nobaseencoding
        ADR     R0,ErrorBlock_FontNoBaseEncoding        ; drop through
        B       XError_with_encoding_noR2

xerr_badsize
        ADR     R0,ErrorBlock_FontBadEncodingSize
        B       XError_with_encoding_noR2

xerr_toofewids
        ADR     R0,ErrorBlock_FontTooFewIDs
        B       XError_with_encoding_noR2

xerr_toomanyids
        ADR     R0,ErrorBlock_FontTooManyIDs
        B       XError_with_encoding_noR2

xerr_idwithoutslash
        ADR     R0,ErrorBlock_FontMustHaveSlash
        B       XError_with_encoding

xerr_baseidnotfound
        ADR     R0,ErrorBlock_FontIdentifierNotFound    ; drop through
;.............................................................................

; In    R0 -> error block, ie. errno followed by "token:default"
;       [currentfont] = font handle
;       [cacheindex] -> font index
;       [fontheader,#hdr_encoding] = encoding
;       R2 -> identifier (if relevant) (denoted by %1)
; Out   VS, R0 -> translated error block (in errorbuffer)

XError_with_encoding Entry "R0-R4,R9", 256       ; buffer on stack for encoding name

XError_with_encoding_altentry

      [ debugxx
        ADD     R14,R0,#4
        DebugS  xx,"XError_with_encoding: ",R14
      ]

        LDR     R1,currentencoding      ; set up earlier - may be base or target encoding

        MOV     R9,#lfff_encoding
        MOV     R3,sp                   ; R3 -> buffer to contain translated name
        BL      get_name_from_id        ; R1 -> encoding name (looked up from list of known encodings)

        MOVS    R3,R2
        BEQ     %FT35

31      LDRB    R0,[R3],#1              ; R0 = next char from identifier
        SUB     R14,R2,R3
        CMP     R14,#-32                ; report 32 chars at most
        CMPGT   R0,#32                  ; stop on next space or ctrl-char
        BGT     %BT31

        MOV     R14,#0                  ; it's OK to terminate this - only non-fatal error occurs at EOF
        STRB    R14,[R3,#-1]

35      LDR     R0,[sp,#256]            ; R0 -> error block
        BL      MyGenerateError_2       ; allows 2 parameters

        STR     R0,[sp,#256]            ; set up return value
        EXIT

; In    as for XError_with_encoding, except R2 is set to 0

XError_with_encoding_noR2 ALTENTRY

        MOV     R2,#0
        B       XError_with_encoding_altentry

;.............................................................................

; In    R1 -> identifier / Font_FindFont string
;       R3 -> buffer to contain name (256 bytes long)
;       R9 = 0 => look for font name
;       R9 = lfff_encoding => look for encoding name
; Out   R1 -> font/encoding name (zero-terminated)
;             this may be held in [R3..]

; encoding name looked up if available:
;       1: in encoding block, if found
;       2: in encoding string, if \e found (with the correct language ID)
;       3: in encoding string, if \E found
;       4: encoding string itself (must be just the identifier)

get_name_from_id Entry "R0-R4"

        DebugS  xx,"get_name_from_id: ",R1

        TEQ     R1,#0                   ; if null, forget it
        EXIT    EQ

        LDRB    R14,semaphore           ; forget it if semaphore set
        Debug   xx,"get_name_from_id: semaphore =",R14
        TEQ     R14,#0
        EXIT    NE                      ; the string on exit will not be used, as MyGenerateError is also semaphored

        MOV     R14,#1
        STRB    R14,semaphore

        BL      findblockfromID         ; VC => R2 -> block, VS => block not found
        MOVVS   R2,#0
        BVS     %FT01

        LDR     R14,territory           ; only use name if territory matches
        LDR     R3,[R2,#lff_territory]
        TEQ     R14,R3
        LDREQ   R1,[R2,#lff_nameaddr]   ; R1 -> font/encoding name
        BEQ     %FT90

01      MOV     R3,R1                   ; R1 -> font/encoding identifier
        MOV     R4,R2                   ; R4 -> block (0 if not found)

        LDR     R1,[sp,#4]              ; now look for name in string provided
        TEQ     R9,#0
        MOVEQ   R2,#"f"
        MOVNE   R2,#"e"
        BL      findfield               ; R1 -> <territory> <name> (if VC)
        BNE     %FT02                   ; NE => not found

        MOV     R0,#10                  ; R0 = default base (10)
        SWI     XOS_ReadUnsigned        ; R1 -> terminator, R2 = value
        BVS     %FT02                   ; use identifier if name not found or invalid number
        LDR     R14,territory
        TEQ     R14,R2                  ; or if name's territory doesn't match the current one
        BNE     %FT02

        ADD     R0,R1,#1                ; skip number terminator
        LDR     R1,[sp,#3*4]            ; R1 -> output buffer
11      LDRB    R14,[R0],#1
        CMP     R14,#"\\"
        CMPNE   R14,#" "-1              ; space does not terminate names
        MOVLE   R14,#0
        STRB    R14,[R1],#1
        BGT     %BT11

        B       %FT32

; take identifier from block if found, and string if not

02      TEQ     R4,#0
        MOVEQ   R0,R3                   ; R0 -> identifier in string if block not found
        LDRNE   R0,[R4,#lff_identaddr]  ; R0 -> identifier in block otherwise

; copy identifier to a temporary buffer, reversing if output write direction is right to left

        LDR     R14,territory_writedir
        TST     R14,#WriteDirection_RightToLeft
        BNE     %FT04

03      LDR     R1,[sp,#3*4]            ; R1 -> output buffer
31      LDRB    R14,[R0],#1
        CMP     R14,#"\\"
        CMPNE   R14,#" "                ; space terminates identifiers
        MOVLE   R14,#0
        STRB    R14,[R1],#1
        BGT     %BT31

32      LDR     R1,[sp,#3*4]            ; R1 -> output buffer
        B       %FT90

04      LDR     R1,[sp,#3*4]
        ADD     R1,R1,#256              ; R1 -> end of output buffer
        MOV     R14,#0
41      STRB    R14,[R1,#-1]!           ; store identifier reversed (to correct for output)
        LDRB    R14,[R0],#1
        CMP     R14,#"\\"
        CMPNE   R14,#" "
        BGT     %BT41

90      STR     R1,[sp,#4]              ; R1 on exit -> identifier / name (0-terminated)
        MOV     R14,#0
        STRB    R14,semaphore

        DebugS  xx,"get_name_from_id returns ",R1

        CLRV
        EXIT                            ; no errors

;.............................................................................

; In    R0 -> error block: number followed by "token:string"
; Out   R0 -> errorbuffer, containing translated error
;       VS

MyGenerateError Entry "R1,R2"

        MOV     R1,#0
        MOV     R2,#0
        BL      MyGenerateError_2

        EXIT

;.............................................................................

; In    R0 -> error block (number followed by "token:string")
;       R1 -> parameter %0
;       R2 -> parameter %1
; Out   R0 -> errorbuffer, containing translated error
;       VS

MyGenerateError_2 EntryS "R1-R7"

      [ debugxx
        ADD     R14,R0,#4
        DebugS  xx,"GenerateError: ",R14
      ]

        LDRB    R14,semaphore           ; just return the error straight if we're inside get_name_from_id
        Debug   xx,"GenerateError: semaphore =",R14
        TEQ     R14,#0
        BNE     %FT31

        MOV     R4,R1                   ; R4 -> parameter %0
        MOV     R5,R2                   ; R5 -> parameter %1
        MOV     R6,#0
        MOV     R7,#0

        LDR     R1,messagefile          ; R1 -> message control block
        MOV     R2,#0                   ;   and copy into local buffer
        SWI     XMessageTrans_ErrorLookup
        BVS     %FT31

03      ADRVC   R0,errorbuffer
31
        EXITVS

; MessageTrans not available - we'll have to do this the hard way

01      LDRB    R14,[R1],#1             ; skip token
        TEQ     R14,#":"
        BNE     %BT01

02      LDRB    R14,[R1],#1             ; copy chars from [R1..] to [R2..]
        TEQ     R14,#"%"                ; look out for %0 and %1
        BEQ     %FT04
21      CMP     R14,#32                 ; it's not ideal, but then you should have loaded MessageTrans!
        MOVLT   R14,#0
        STRB    R14,[R2],#1
        BLT     %BT03

        SUBS    R3,R3,#1
        BGT     %BT02
        B       %FT90

04      LDRB    R14,[R1],#1
        TEQ     R14,#"0"
        MOVEQ   R0,R4
        BEQ     %FT05
        TEQ     R14,#"1"
        MOVEQ   R0,R5
        BEQ     %FT05
        TEQ     R14,#"%"                ; %% => %, %<other> => %<other>
        MOVNE   R14,#"%"
        SUBNE   R1,R1,#1
        B       %BT21

05      TEQ     R0,#0                   ; just leave as %0 or %1 if parameter is 0
        SUBEQ   R1,R1,#1
        MOVEQ   R14,#"%"
        BEQ     %BT21

06      LDRB    R14,[R0],#1             ; copy parameter in
        CMP     R14,#32
        BLT     %BT02
        SUBS    R3,R3,#1
        STRGTB  R14,[R2],#1
        BGT     %BT06

90      BL      xerr_buffoverflow       ; report "Buffer overflow" instead if error won't fit
        B       %BT03                   ; note that this particular error will never overflow!


;..............................................................................
; FullLookupR0
;
; In:   r0 -> token block (must have default text after token!!)
;       r4-r7 -> possible parameters
;
; Out:  r0 -> block to be returned.
;       r3 = length of text looked up
;       preserves all flags except V (done by Lookup)
;

FullLookupR0 Entry "r1,r2"

        MOV     r1, r0
        ADR     r2, errorbuffer
        MOV     r3, #?errorbuffer
        BL      Lookup

        EXIT


;..............................................................................
; LookupR0
;
; In:   r0 -> token block (must have default text after token!!)
;
; Out:  r0 -> block to be returned.
;       preserves all flags except V (done by Lookup)
;

LookupR0 Entry "R1-R7"

        DebugS  xx, "Lookup token ", r0

        MOV     r1, r0
        ADR     r2, errorbuffer         ; -> return buffer
        MOV     r3, #?errorbuffer       ;  = size of error buffer
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0                  ; no substitution
        BL      Lookup

        EXIT


Lookup  EntryS  "r8"

        LDR     R0,messagefile
        TEQ     R0,#0
        BEQ     %01                     ; jump into error trap code for lookup

        SWI     XMessageTrans_Lookup
        EXIT    VS
03
        ADR     R0,errorbuffer

        DebugS  xx, "Returning from lookup sequence ", r0

        EXITVC                          ; Preserve all flags except V.

01      LDRB    R14,[R1],#1             ; skip token
        TEQ     R14,#":"
        BNE     %BT01

        MOV     r8, r3
02      LDRB    R14,[R1],#1             ; copy chars from [R1..] to [R2..]
        TEQ     R14,#"%"                ; look out for %0 and %1
        BEQ     %FT04
21      CMP     R14,#32                 ; it's not ideal, but then you should have loaded MessageTrans!
        MOVLT   R14,#0
        STRB    R14,[R2],#1
        SUBLT   r3, r8, r3
        BLT     %BT03

        SUBS    R3,R3,#1
        BGT     %BT02
        B       %FT90

04      LDRB    R14,[R1],#1
        TEQ     R14,#"0"
        MOVEQ   R0,R4
        BEQ     %FT05
        TEQ     R14,#"1"
        MOVEQ   R0,R5
        BEQ     %FT05
        TEQ     R14,#"%"                ; %% => %, %<other> => %<other>
        MOVNE   R14,#"%"
        SUBNE   R1,R1,#1
        B       %BT21

05      TEQ     R0,#0                   ; just leave as %0 or %1 if parameter is 0
        SUBEQ   R1,R1,#1
        MOVEQ   R14,#"%"
        BEQ     %BT21

06      LDRB    R14,[R0],#1             ; copy parameter in
        CMP     R14,#32
        BLT     %BT02
        SUBS    R3,R3,#1
        STRGTB  R14,[R2],#1
        BGT     %BT06

90      BL      xerr_buffoverflow       ; report "Buffer overflow" instead if error won't fit
        EXITVS                          ; Preserve all flags except V.

        END

