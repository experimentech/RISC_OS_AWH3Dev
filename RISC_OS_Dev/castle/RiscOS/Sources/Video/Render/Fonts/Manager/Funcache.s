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
; > Sources.Funcache

; Entry:  R6 = space required
; Exit:   R6 --> space (at end of cache)
;         R8 relocated
;         [cachefree] updated

reservecache    PEntry Res_Find, "R5-R7"

        Debug   th :LOR: debugdel,"reservecache: size",R6

      [ debugbrk
        CMP     R6,#&100000
        BLO     %FT00
        Debug   brk,"LR =",LR
        BreakPt "Requested size too large"
00
      ]

        BL      reservecache2           ; first ensure there's enough room!
        PExit   VS

        LDR     R5,[sp,#1*4]            ; R5 = size requested (R6 on entry)
        LDR     R7,cacheindex           ; must be present
        LDR     R6,[R7,#cache_free]     ; R6 -> new block (at end of cache)
        ADD     R14,R6,R5               ; new cachefree
        STR     R14,[R7,#cache_free]

        ASSERT  std_size=0 :LAND: std_link=4 :LAND: std_backlink=8

        ORR     R5,R5,#size_claimed     ; this block MUST belong to a claimed font
        LDR     R7,ageheadblock_p
        LDR     R14,[R7,#std_backlink]
        STMIA   R6,{R5,R7,R14}          ; fill in size, link and backlink (not quite same as StrLink)
        STR     R6,[R14,#std_link]
        STR     R6,[R7,#std_backlink]   ; insert before the end of the chain

        Debug   cc,"ReserveCache: new block,headptr:",R6,R8

        STR     R6,[sp,#1*4]            ; return address of block in R6
        PExit

;.............................................................................

; Reserve a space at the end of the cache, extending it if necessary
;
; On cache full:
;    First remove blocks belonging to unused fonts
;    Then extend the cache up to a maximum of FontMax
;    Then remove blocks which aren't locked
;    Then extend the cache regardless of FontMax
;    Then return "Font cache full"!
;
; On Font_LoseFont:
;    Remove unused blocks until size <= FontSize, and shrink cache
;
; On *Configure FontMax
;    Remove unlocked blocks until size <= max(FontSize,FontMax), shrink cache
;
; Entry:  R6 = space required at end of cache
; Exit:   uncacheing may have occurred
;         font cache may have been extended
;         R8 relocated

reservecache2   PEntry Res_Find, "R0,R7"

        Debug   del,"reservecache2: block of size",R6

        MOV     R7,#bigtime             ; remove only unused blocks
        BL      reservecache3
        PExit   VC

        CLRV
        LDR     R7,maxcache             ; extend up to a max of [maxcache]
        BL      extendcache
        CLRV

        MOV     R7,#0                   ; this may succeed straight away
        BL      reservecache3           ; otherwise remove unlocked blocks
        PExit   VC

        CLRV
        MOV     R7,#1024*1024           ; extend up to a max of 1024k
        BL      extendcache
        CLRV

        MOV     R7,#0                   ; if this fails, we've had it!
        BL      reservecache3

      [ debugxx
        PExit   VC
        Debug   xx,"===> Couldn't claim block of size",R6
      ]

        STRVS   R0,[sp]
        PExit

;.............................................................................

; Entry: R6 = space required at end of cache
;        R7 = max size of font cache
; Exit:  font cache extended
;        "Font cache full" returned if it can't be done

extendcache Entry "R1,R7"

        LoadCacheFree R1
        ADD     R1,R1,R6                ; new end of font cache

        Debug   sp,"extendcache: from,to,max",#fontcachesize,R1,R7

        LDR     R14,fontcache
        ADD     R7,R7,R14               ; ceiling
        CMP     R7,R1                   ; "Font cache full" if not enough room
        LDRCS   R14,fontcacheend
        SUBCSS  R1,R1,R14               ; R1 = extra space needed
        SETV    CC
        BLVC    changedynamic           ; set [cacheflag] for the duration
        EXIT    VC

        PullEnv
        Debuga  xx,"Error from extendcache: "

xerr_FontCacheFull ROUT

        ADR     R0,ErrorBlock_FontCacheFull
        B       MyGenerateError
        MakeErrorBlock FontCacheFull

;.............................................................................

; Entry: R1 = amount to change cache size by

changedynamic   ROUT
        Push    "LR"

        Debug   dy,"changedynamic: change by",R1

        MOV     R0,#4                   ; area 4
        STRB    R0,cacheflag            ; prevent [mincache] being reset
        SWI     XOS_ChangeDynamicArea   ; calls font manager to update things
        MOV     R14,#0
        STRB    R14,cacheflag           ; cancel [cacheflag]
        Pull    "PC"

;.............................................................................

; Called on exit from Font_LoseFont to reduce cache size to [mincache]

; Entry: [fontcachesize] = current font cache size
;        [mincache] = min size of font cache
; Exit:  unused blocks deleted until fontcachesize <= mincache
;        error state preserved

shrinkcache     ROUT

        EntryS  "R0-R3,R6-R8"

        Debug   sp,"shrinkcache: from,to",#fontcachesize,#mincache

        LDR     R3,fontcachesize
        LDR     R2,mincache
        SUBS    R6,R3,R2
        MOVHI   R7,#bigtime             ; delete unused blocks only
        BLHI    reservecache3

        LoadCacheFree R1
        LDR     R14,fontcache
        SUB     R1,R1,R14               ; R1 = current cache size
        CMP     R1,R2                   ; R2 = min cache size
        MOVLO   R1,R2
        SUBS    R1,R1,R3                ; amount to change cache by
        BLLO    changedynamic

        Debug   sp,"shrinkcache: new fontcachesize =",#fontcachesize

        EXITS                           ; ignore errors

;.............................................................................

; Entry: R6 = amount of space required in cache
;        R7 = 0 / bigtime ==> used blocks can / can't be deleted
; Exit:  blocks deleted as required
;        cache compacted to leave all space at top
;        V set if not enough memory was freed
;        R8 relocated

BLK_ISCHAR      *       1 :SHL: 0       ; bit 0 not used in word-aligned pointers

reservecache3   PEntry Res_Find, "R0-R1,R7"

      [ debugbrk
        CMP     R6,#0
        BreakPt "Negative memory claim",LT
      ]

        CheckCache "Entry to reservecache3", NoCacheOK

        LoadCacheFree R7                ; R7 = cachefree before compaction
        LDR     R14,fontcacheend
        SUB     R14,R14,R7              ; R14 = amount of free space
        CMP     R14,R6
        PExit   GE                      ; enough space already

        PushP   "R8 on entry to reservecache2",R8

        LoadCacheFree R7,R14,compacted  ; R7 = cachefree after compaction
        LDR     R14,fontcacheend
        SUB     R14,R14,R7              ; R14 = amount of free space
        CMP     R14,R6
        BGE     %FT99                   ; enough space once compacted

        STR     R6,spacewanted

tryagain
        MOV     R14,#0
        STRB    R14,font_to_delete      ; master font handle to delete

        LoadCacheFree R7,R14,compacted  ; R7 = cachefree after compaction
        LDR     R14,fontcacheend
        SUB     R14,R14,R7              ; R14 = amount of free space
        LDR     R6,spacewanted
        ADD     R6,R6,#2048             ; encourage multiple block deletion
        Debuga  del,"ReserveCache3: free",R14
        Debug   del,", needed",R6
        CMP     R14,R6
        BGE     %FT99

; font cache was full - uncache the oldest block in the cache

        Debug   del,"Cache full - unload oldest block"

        LDR     R8,cacheindex           ; if no cache index,
        TEQ     R8,#0
        LDRNE   R7,ageheadblock_p
        LDRNE   R6,[R7,#std_link]       ; or no blocks to delete,
        TEQNE   R6,R7
        BEQ     noblock                 ; try deleting font cache index / return error

        LDR     R14,[sp,#2*4]           ; see if we're allowed to delete claimed blocks
        TEQ     R14,#0
        MOVEQ   R8,#size_locked
        MOVNE   R8,#size_locked :OR: size_claimed
        LDRNE   R6,ageunclaimed_p       ; start from this block (marker)

find2   LDR     R14,[R6,#std_size]
        TST     R14,R8                  ; locked / locked or claimed
        LDRNE   R6,[R6,#std_link]
        TEQNE   R6,R7                   ; finished if we get back to the header block
        BNE     find2

        TST     R8,#size_claimed        ; if we needed to find an unclaimed block, move the marker
        BLNE    moveunclaimedhead       ; NB: locked unclaimed blocks are not important (deleted with the font)

        TEQ     R6,R7                   ; found a block to delete?
        LDRNE   R8,[R6,#std_anchor]
        BLNE    deleteblock             ; NB: assume parents are always younger than their children!
        BNE     tryagain                ;     (they must be marked accessed after the children are)

; if no unlocked blocks found, try deleting unclaimed fonts

        LDR     R8,cacheindex
        ASSERT  cache_free = 0
        MOV     R7,#maxf-1              ; counter

find3   LDR     R6,[R8,#4]!
        TEQ     R6,#0
        BEQ     find5

        LDR     R14,[R6,#hdr_usage]     ; don't delete claimed fonts
        TEQ     R14,#0
        BEQ     find4

find5   SUBS    R7,R7,#1
        BNE     find3
        B       noblock                 ; can't do it!

95      BVC     tryagain

99      BL      compactcache            ; call this even if error has occurred

        PullP   "R8 on exit from reservecache2",R8

        LDR     R6,spacewanted          ; restore R6
        STRVS   R0,[sp]
        PExit

find4   BL      deletefont_R6R8         ; R6,[R8] -> font block
        B       tryagain

; couldn't delete any more blocks
; (1) if multiple block deletion, try again without hysteresis
; (2) if no more blocks, try deleting the cache index as well
; if both these fail, return an error

noblock
        LoadCacheFree R7,R14,compacted  ; R7 = cachefree after compaction
        LDR     R14,fontcacheend
        SUB     R14,R14,R7              ; R14 = amount of free space
        LDR     R6,spacewanted

        Debug   del,"Try without hysteresis: free, wanted =",R14,R6

        CMP     R14,R6
        BGE     %BT99                   ; in fact there is enough space for the block

        LDR     R0,cacheindex           ; if index in cache, try deleting this too
        ADD     R1,R0,#cache_data       ; only do this if nothing else left
        TEQ     R0,#0
        LDREQ   R14,fontcache
        MOVNE   R14,R7                  ; R7 = cachefree after deleted blocks subtracted
        SUBS    R1,R14,R1               ; R1=0 => cacheindex is only thing left
        STREQ   R1,cacheindex
        BEQ     tryagain

        Debuga  xx,"Error from reservecache3: "
        BL      xerr_FontCacheFull
        B       %BT99

;.............................................................................

; In    R6 -> block which is about to be deleted
; Out   ageunclaimed block moved to just before this block

moveunclaimedhead Entry "R7-R9"

        LDR     R7,ageunclaimed_p       ; delete from previous position
        RemLink R7,R8,R9
        LDR     R8,[R6,#std_backlink]   ; insert just before R6 block
        StrLink R7,R6,R8

        EXIT

;;----------------------------------------------------------------------------
;; deletefont
;; In   R0 = handle of font to delete (1..255)
;;----------------------------------------------------------------------------

deletefont_R6R8 Entry "R0-R5,R6-R8"
        Debug   del,"Delete Font R6 R8:",R6, R8
        B       delfont_altentry

deletefont      Entry "R0-R5,R6-R8"

        Debug   del,"Delete Font:",R0

        LDR     R8,cacheindex
        TEQ     R8,#0
        LDRNE   R6,[R8,R0,ASL #2]!              ; R8 --> font index entry
        TEQNE   R6,#0
        BEQ     %FT99                           ; already deleted

        Debug   del,"Deleting R6 R8:",R6,R8

; delete the constituent parts first

delfont_altentry                        ; enter here if R6,R8 already known

        Push    "R8"                    ; NB: THIS BLOCK MUST NOT MOVE!
                                        ; (should really use relocation stack)
        ADD     R8,R6,#hdr_MetricsPtr
        MOV     R7,#hdr4_PixoPtr - hdr_MetricsPtr
01      BL      deleteblock                     ; just delete block itself
        ADD     R8,R8,#4
        SUBS    R7,R7,#4
        BNE     %BT01

        LDR     R7,[R6,#hdr4_nchunks]
        BL      deletepixo              ; delete hdr4_PixoPtr (increments R8)
        LDR     R7,[R6,#hdr1_nchunks]
        BL      deletepixo              ; delete hdr1_PixoPtr (increments R8)

        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_master
        BEQ     %FT04

;       ASSERT  hdr_transforms = hdr_pixarray1
        MOV     R7,#hdr_transformend - hdr_transforms
03      BL      deletetransforms                ; delete block and any children
        ADD     R8,R8,#4
        SUBS    R7,R7,#4
        BNE     %BT03
04
        Pull    "R8"
        BL      deleteblock_notfont             ; delete the header (avoid recursion - don't call deleteblock)
99
        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    [R8] -> chunk to be deleted
;       R7 = number of chunks within this block
; Out   [R8]=0, block deleted, cache copied down and relocated
;       all chunks within this block are also deleted
;       R8 is then incremented by four

deletepixo Entry

        PushP   "Saving pixo block pointer",R8

        LDR     R8,[R8]
        TEQ     R8,#0
        BEQ     %FT90

        ADD     R8,R8,#pixo_pointers

01      BL      deletechunk
        ADD     R8,R8,#4
        SUBS    R7,R7,#1
        BNE     %BT01
90
        PullP   "Restoring pixo block pointer",R8

        BL      deleteblock

        ADD     R8,R8,#4

        EXIT

;.............................................................................

; In    [R8] -> chunk to be deleted
; Out   [R8]=0, block deleted, cache copied down and relocated
;       If this is a split chunk, all characters are also deleted
;       R6, R8 relocated if necessary
;       R0 and flags preserved (including error state)

deletechunk EntryS "R9"

      [ debugdel
        LDR     R14,[R8]
        TEQ     R14,#0
        BEQ     %FT00
        Debug   del,"deletechunk: R8, [R8] =",R8,R14
00
      ]

        PushP   "Saving chunk parent pointer",R8

        LDR     R8,[R8]
        TEQ     R8,#0
        LDRNE   R14,[R8,#pix_flags]
        TSTNE   R14,#pp_splitchunk
        BEQ     %FT02                           ; if null, or normal chunk, just delete it

        ASSERT  std_size = 0
        LDR     R9,[R8],#pix_index-4            ; R8 -> index-4, R9 = chunk size
        BIC     R9,R9,#size_flags               ; ignore lock bit etc.
        SUB     R9,R9,#pix_index                ; R9 = counter * 4
01      LDR     R14,[R8,#4]!
        ASSERT  PIX_UNCACHED > 0
        CMP     R14,#PIX_UNCACHED
        BLHI    deletechar                      ; [R8] = PIX_UNCACHED on exit
        SUBS    R9,R9,#4
        BNE     %BT01
02
        PullP   "Restoring chunk parent pointer",R8

        BL      deleteblock
        EXITS                                   ; preserve error state (R0 and flags)

;.............................................................................

; In    [R8] -> character block
; Out   [R8] = PIX_UNCACHED, character block deleted
;       R6, R8 relocated if necessary

deletechar Entry ""

        BL      deleteblock
        MOV     R14,#PIX_UNCACHED
        STR     R14,[R8]
        Debug   del,"[R8] = PIX_UNCACHED"

        EXIT

;.............................................................................

; In    [R8] -> chain of transforms
;       R6 -> font header
; Out   [R8] = 0, transform blocks deleted
;       R6, R8 relocated if necessary

deletetransforms Entry "R1"

        MOV     R1,#0

01      LDR     R14,[R8]                ; count number of transform blocks
        TEQ     R14,#0
        ADDNE   R1,R1,#1
        ADDNE   R8,R14,#trn_link
        BNE     %BT01

02      SUBS    R1,R1,#1                ; now delete blocks from end of chain backwards
        LDRGE   R8,[R8,#std_anchor-trn_link]
        BLGE    deletetransform
        BGE     %BT02

        EXIT

;.............................................................................

; In    [R8] -> transform block to be deleted
;       R6 -> font header
; Out   [R8]=0, block deleted, cache copied down and relocated
;       Any chunks belonging to this block are also deleted
;       R6, R8 relocated if necessary
;       R0 and flags preserved (including error state)

deletetransform EntryS "R9"

      [ debugdel
        LDR     R14,[R8]
        Debug   del,"deletetransform: R8, [R8] =",R8,R14
      ]
      [ debugbrk
        LDR     R14,[R8]
        TEQ     R14,#0
        BreakPt "deletetransform must have non-0 block",EQ
      ]

        PushP   "Saving transform parent pointer",R8

        LDR     R8,[R8]
;       ASSERT  trn1_PixelsPtrs = trn4_PixelsPtrs+4*8
;       ADD     R8,R8,#trn4_PixelsPtrs-4
;       MOV     R9,#2*8
        LDR     R9,[R8,#trn_nchunks]            ; R9 = number of chunks in transform block
        Debug   trn,"deletetransform: block, nchunks =",R8,R9
        ADD     R8,R8,#trn_PixelsPtrs-4         ; R8 -> array of chunks (will be pre-incremented)
01      LDR     R14,[R8,#4]!
        TEQ     R14,#0
        BLNE    deletechunk                     ; deletes any characters contained therein
        SUBS    R9,R9,#1
        BNE     %BT01
02
        PullP   "Restoring transform parent pointer",R8

        BL      deleteblock
        EXITS                                   ; preserve error state (R0 and flags)

;.............................................................................

; In    [R8] -> block to be deleted
; Out   [R8]=0, ptrs on relocstk also =0 if referred to this block
;       [deletedblock] -> sorted list of deleted blocks
;       [deletedamount] = amount of memory in deleted blocks
;       Assumes R6,R8 did NOT point into this block (not set to 0)
;       R0 and flags preserved (including error state)
;
; NB: Do not call this unless the block in question has no children
;     Therefore ensure that parent blocks are always YOUNGER than their offspring
;     and we MUST use a Least Recently Used uncacheing method
;
;     The one exception is where the block is an unused font header - if
;     this is deleted, any locked subblocks are also deleted.
;     When a font is unclaimed, its header is unlocked and marked newest.
;     Its locked subblocks are not unlocked, however, since they must be
;     removed only when the font header goes away.

deleteblock PEntryS Res_Reloc, "R4-R7,R9"

        LDR     R5,fontcache            ; used later
        ADD     R14,R5,#4*maxf
        CMP     R8,R14                  ; is this a font header?
        BLO     %FT50                   ; take special action to remove subblocks

deleteblock_altentry                    ; remember R5 has to be set up here!

        LDR     R9, [R8]
      [ debugdel
        TEQ     R9,#0
        BEQ     %FT00
        LDR     R14,[R9,#std_size]
        Debug   del, "deleteblock: R8,[R8],size =",R8,R9,R14
00
      ]
        MOV     R14, #0                 ; delete the parent pointer
        STR     R14, [R8]

        LDR     R6, fontcacheend        ; if block not in cache, we've finished
        CMP     R9, R5                  ; R5 set up earlier
        CMPHS   R6, R9
        PExitS  LO

        RemLink R9,R7,R14               ; remove from the chain

        LDR     R5, cacheindex
        LDR     R6, [R5, #cache_deletedamount]      ; update the deletedamount count
        LDR     R7, [R9, #std_size]
        TST     R7,#size_charblock      ; EQ => normal 'null' pointer (put in parent already)
        MOVNE   R14,#PIX_UNCACHED       ; NE => R14=1 (for character blocks)
        STRNE   R14,[R8]
        BIC     R7, R7, #size_flags     ; cancel locked bit etc.
        STR     R7, [R9, #std_size]
        ADD     R6, R6, R7
        STR     R6, [R5, #cache_deletedamount]

; search chain from tail, since address order often matches usage order

        ADD     R5, R5, #cache_deletedblock
        MOV     R6, R5
01      LDR     R14, [R6, #std_backlink]
        CMP     R14, R5
        CMPNE   R9, R14                 ; EQ => reached end of list
        MOVLO   R6, R14                 ; LO => this block is lower than the one in the list (continue)
        BLO     %BT01                   ; HI => this block is higher than the one in the list (stop)

; see if we can amalgamate this block with the one before it

        Debug   del,"Age list position: block, link, backlink =",R9,R6,R14

        SavePSR R5                      ; get PSR in R5
        TST     R5, #Z_bit              ; NE => at start of list, EQ => just after existing block
        LDREQ   R5, [R14, #std_size]    ; no flag bits in deleted blocks
        ADDEQ   R4, R14, R5
        TEQEQ   R4, R9
        ADDEQ   R5, R5, R7              ; R5 = size of amalgamated block
        STREQ   R5, [R14, #std_size]
        StrLink R9, R6, R14, NE         ; otherwise link new block in
      [ debugdel
        BNE     %FT00
        Debug   del,"Amalgamated with block (size)",R14,R5
00
      ]

; delete any references to this block or its contents on the relocation stack

        wsaddr  R5, relocstk            ; delete any references on stack
        LDR     R6, relocSP
02      LDR     R14, [R5], #4
        SUB     R14, R14, R9
        CMP     R14, R7                 ; R7 = size of block
      [ debugdel
        BHI     %FT00
        LDR     R14, [R5, #-4]
        Debug   del,"Deleted reference on relocation stack:",R14
00
      ]
        MOVLO   R14, #0
        STRLO   R14, [R5, #-4]
        TEQ     R5, R6
        BNE     %BT02

        PExitS

; delete unclaimed font header

50      LDR     R6,[R8]                 ; R6 -> font header, R8 -> index
        BL      deletefont_R6R8

        PExitS                          ; preserves error state

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; delete block without checking if it's a font header (to avoid recursion)

deleteblock_notfont ALTENTRY

        ProfIn  Res_Reloc               ; shame there's no PAltEntry macro!

        LDR     R5,fontcache            ; used later inside deleteblock
        B       deleteblock_altentry

;.............................................................................

; compactcache - amalgamate deleted blocks at the top of the cache

; Macros:
;       Reloc   relocates a pointer in the cache structure
;       RelocA  relocates a pointer and updates the anchor pointer of the child
;       Reloc2  relocates a pointer on the relocation stack (may be deleted)

        MACRO
$l      Reloc   $rd,$rb,$rp,$rmin,$rmax,$rt1,$rt2 ; destblk, sourceblk, parent, min,max, temp1..2
$l
        CMP     $rb, $rmin
        CMPHI   $rmax, $rb
   ;;   MOVLS   $rd, $rb                        ; outside cache - no need to set up $rd
        LDRHI   $rd, [$rb, #std_backlink]
      [ debugcache
        BICHI   $rd, $rd, #dbg_flagbit
        STRHI   $rd, [$rb, #std_backlink]
      ]
        STRHI   $rd, [$rp]                      ; HI => block was in cache
        LDRHI   $rt2, [$rb,#std_link]           ; relocate forward link (if this block was in cache)
        LDRHI   $rt2, [$rt2, #std_backlink]
      [ debugcache
        BICHI   $rt2, $rt2, #dbg_flagbit
      ]
        STRHI   $rt2,[$rb,#std_link]
        MEND

; As above, but also update the anchor pointer (using $rt1)

        MACRO
$l      RelocA  $rd,$rb,$rp,$rmin,$rmax,$rt1,$rt2
$l      Reloc   $rd,$rb,$rp,$rmin,$rmax,$rt1,$rt2       ; doesn't use $rt1
        Debug   del,"  block,anchor =",$rb,$rt1
        STRHI   $rt1,[$rb,#std_anchor]  ; $rt1 = anchor pointer (if agelist true)
        MEND

; this one doesn't update the parent pointer
; also checks for pointer being within a deleted block

        MACRO
$l      Reloc2  $rd,$rb,$rp,$rmin,$rmax,$rt1,$rt2,$rt3 ; destblk, srcblk, parent, max, temp1..3
$l
        MOV     $rd, $rb
        CMP     $rb, $rmin
        CMPHI   $rmax, $rb
        BLS     %FT02                   ; outside cache
        LDR     $rt1, cacheindex
        LDR     $rt1, [$rt1, #cache_delhead]
01      CMP     $rt1, #0                ; NB: last link written to 0 by now!
        BEQ     %FT02
        LDR     $rt2, [$rt1, #std_size] ; always load
        SUBS    $rt3, $rb, $rt1
        BLT     %FT02
        CMP     $rt3, $rt2              ; is this inside the block?
        SUBGE   $rd, $rd, $rt2
        LDRGE   $rt1, [$rt1, #std_link]
        BGE     %BT01
        MOV     $rd, #0                 ; if matched, then was deleted
02
        MEND

; Copy $count bytes from $from to $to.
; $from,$to updated, $count=0, corrupts R6,R10,R14.

        MACRO
$l      CopyDown  $from,$count,$to
$l
        ASSERT  $from  >= R7 :LAND: $from  <= R9
        ASSERT  $count >= R7 :LAND: $count <= R9
        ASSERT  $to    >= R7 :LAND: $to    <= R9

        Debuga  del,"Copying",$count
        Debuga  del," bytes from",$from
        Debug   del," to",$to

      [ debugbrk
        CMP     $count,#0               ; might be nothing to copy ...
        BreakPt "Negative count",LT
      ]

      [ debugcpm
        TEQ     $from,$to
        BNE     %FT99
        Debug   cpm,"!! CopyDown 'from' and 'to' are the same !!"
99
      ]

; apply large sledgehammer if block size is sufficiently large...

        SUBS    $count,$count,#4*11
        BLO     %FT02

        Push    "R0-R5,R11,R12"         ; R6-R10,R14 don't need saving
01
        LDMIA   $from!,{R0-R6,R10-R12,R14} ; 11 registers
        STMIA   $to!,{R0-R6,R10-R12,R14}
        SUBS    $count,$count,#4*11
        BHS     %BT01

        Pull    "R0-R5,R11,R12"
02
        ADDS    $count,$count,#4*11
        BreakPt "Overshoot!",LT
        BEQ     %FT50
03
        LDR     R14,[$from],#4
        STR     R14,[$to],#4            ; $to --> destination
        SUBS    $count,$count,#4
        BNE     %BT03
50
        MEND

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    [deletedblocks] -> sorted list of deleted blocks
;       [deletedamount] = amount of memory in deleted blocks
; Out   cache copied down, cache pointers relocated
;       [deletedblocks], [deletedamount] = 0
;       R0 and flags preserved (error may be pending)

compactcache    PEntryS Res_Reloc, "R0-R11"

        LDR     R14, cacheindex         ; if no cacheindex, just reset all pointers
        TEQ     R14, #0
        LDRNE   R14, [R14, #cache_deletedamount]
        TEQNE   R14, #0
        BEQ     %FT90

      [ debugdel
        LDR     R14, cacheindex
        LDR     R14, [R14, #cache_deletedamount]
        Debug   del, "compactcache: deletedamount =",R14
      ]

        CheckCache "compactcache entry"

; stage 1: ascend through the cache, setting backlink to new position of each block

        LDR     R14,ageheadblock_p      ; these ones don't move
        STR     R14,[R14,#std_backlink]
        LDR     R14,ageunclaimed_p
        STR     R14,[R14,#std_backlink]

        LDR     R6,cacheindex
        LDR     R7,[R6,#cache_free]     ; R7 -> end of cache data
        ADD     R6,R6,#cache_data       ; R6 -> start of cache data

        LDR     R8,[R6,#cache_deltail - cache_data]
        MOV     R9,#0                                   ; R9 = data offset (0 initially)
        STR     R9,[R8,#std_link]                       ; rewrite last link as 0 (easier to test for)
        LDR     R8,[R6,#cache_delhead - cache_data]     ; R8 = address of first deleted block
reloc1
        CMP     R6,R8
        SUBLO   R14,R6,R9
      [ debugdel
        BHS     %FT00
        Debuga  del,"Stage 1: block at",R6
        Debug   del," moves to",R14
00
      ]
      [ debugcache
        ORRLO   R14,R14,#dbg_flagbit    ; so we can test for missing blocks
      ]
        STRLO   R14,[R6,#std_backlink]  ; re-use this to store the new position
        LDRLO   R14,[R6,#std_size]
        BICLO   R14,R14,#size_flags
        ADDLO   R6,R6,R14
        BLO     reloc1

        TEQ     R6,R7                   ; have we reached the end?
        BEQ     reloc2

        Debug   del,"Stage 1: hole at",R8

        LDR     R8,[R8,#std_link]       ; look for next deleted block
        TEQ     R8,#0
        MOVEQ   R8,R7
        LDR     R14,[R6,#std_size]
        BIC     R14,R14,#size_flags
        ADD     R6,R6,R14               ; step past deleted block
        ADD     R9,R9,R14               ; and update amount to subtract
        B       reloc1

; stage 2: Scan all pointers in the cache, replacing p with [p,#std_backlink]

reloc2
        Debug   del,"Stage 2: set backlinks to new block positions"

        LDR     R6,ageheadblock_p
        LDR     R14,[R6,#std_link]
        LDR     R14,[R14,#std_backlink]
      [ debugcache
        BIC     R14,R14,#dbg_flagbit
      ]
        STR     R14,[R6,#std_link]

        LDR     R6,ageunclaimed_p
        LDR     R14,[R6,#std_link]
        LDR     R14,[R14,#std_backlink]
      [ debugcache
        BIC     R14,R14,#dbg_flagbit
      ]
        STR     R14,[R6,#std_link]

        LDR     R10,fontcache
        LDR     R11,fontcacheend        ; R10,R11 = relocation limits

        LDR     R8,cacheindex           ; index must be present
        ASSERT  cache_free = 0          ; font 0 is actually cache_free (to be relocated)
        MOV     R7,#maxf-1              ; skip font 0 (cache_free)

reloclp LDR     R6,[R8,#4]!
        TEQ     R6,#0
        BEQ     %FT03                   ; no pointer

; relocate constituent parts of font header

        Debug   del,"Stage 2: font header at",R6

        Push    "R6-R8"                 ; remember counter, font block and ptr

        Reloc   R7,R6,R8,R10,R11, R0,R14   ; R7,[R8] := relocated form of R6
                                           ; font block anchors don't need relocating
        ADD     R0,R7,#hdr_MetricsPtr      ; R0 -> new anchor pointers
        ADD     R7,R6,#hdr_MetricsPtr-4    ; R7 -> font header (BEFORE relocation)

;       MOV     R8,#hdr_pixarray0 - hdr_MetricsPtr
        MOV     R8,#hdr4_PixoPtr - hdr_MetricsPtr
02      LDR     R6,[R7,#4]!
        RelocA  R1,R6,R7,R10,R11, R0,R14   ; R1,[R7] := relocated form of R6
        ADD     R0,R0,#4                   ; R0 = anchor pointer for next time
        SUBS    R8,R8,#4
        BNE     %BT02

        LDR     R8,[R7,#hdr4_nchunks-hdr4_PixoPtr+4]
        BL      reloc_pixo                 ; increments R7 and R0

        LDR     R8,[R7,#hdr1_nchunks-hdr1_PixoPtr+4]
        BL      reloc_pixo                 ; increments R7 and R0

        LDR     R6,[sp]
        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_master
        BEQ     %FT25

;       ASSERT  hdr_transforms = hdr_pixarray1
        ASSERT  hdr_transforms = hdr1_PixoPtr + 4
        MOV     R8,#hdr_transformend - hdr_transforms

14      LDR     R6,[R7,#4]!
        TEQ     R6,#0
        BLNE    reloc_transforms
        ADD     R0,R0,#4
        SUBS    R8,R8,#4
        BNE     %BT14
25
        Pull    "R6-R8"

03      SUBS    R7,R7,#1
        BNE     reloclp

; relocate the map blocks

        ADD     R7,R8,#cache_mapindex-4*maxf    ; R7 -> old anchor pointers
        ADD     R0,R7,#4                        ; R0 -> new anchor pointers (the same)
        MOV     R8,#MapIndexSize

15      LDR     R6,[R7,#4]!
        TEQ     R6,#0
        BLNE    reloc_mapblocks
        ADD     R0,R0,#4
        SUBS    R8,R8,#1
        BNE     %BT15

; if debugging, check that all blocks were scanned in the last pass

      [ debugcache
        BL      checkbacklinks
      ]

; relocate the relocation stack

        ADRL    R8,relocstk
        LDR     R7,relocSP              ; NB: stack can never be empty
04
        LDR     R6,[R8],#4
        Reloc2  R1,R6,R8,R10,R11, R0,R14,R9  ; R1 := relocated form of R6 (also checks for deleted blocks)
        STR     R1,[R8,#-4]             ; not done inside macro
        TEQ     R8,R7
        BNE     %BT04

; stage 3: compact the list of blocks (cannot be null)

        ProfIn  Res_Copy

        LDR     R9, cacheindex
        LDR     R9, [R9, #cache_delhead]        ; R9 -> destination address for copy
        MOV     R3, R9                          ; R3 -> next block to consider

05      LDR     R7, [R3, #std_size]
        ADD     R7, R3, R7              ; R7 -> source address for copy

        LDR     R5, [R3, #std_link]     ; R5 -> next block
        MOVS    R6, R5
        LDREQ   R6, cacheindex          ; R6 -> end address of data to copy
        LDREQ   R6, [R6, #cache_free]
        SUBS    R8, R6, R7              ; R8 = bytes to copy
        BEQ     %FT06

        CopyDown R7,R8,R9               ; updates R7,R9, corrupts R6,R8,R10,R14

06      MOVS    R3, R5                  ; R3 -> next block to consider
        BNE     %BT05

     [ debugdel
        LDR     R3, cacheindex
        LDR     R14, [R3, #cache_free]
        SUB     R14, R14, R9            ; R14 = amount copied down
        LDR     R3, [R3, #cache_deletedamount]
        Debug   del, "---- deletedamount =",R3,R14
     ]

        SetCacheFree R9, R14            ; set cachefree = R9

        ProfOut

; stage 4: traverse the age list, correcting the backlinks

        Debug   del,"Stage 4: correct backlinks"

      [ debugcache
        LDR     R10,fontcache
        LDR     R11,fontcacheend                ; R10,R11 = relocation limits

        LDR     R0,=&DEADDEAD                   ; this can't possibly occur in a backlink

        LDR     R6, ageheadblock_p
        MOV     R7, R6
57      LDR     R8, [R7, #std_link]             ; debugging: splat all backlinks to &DEADDEAD
        CMP     R8,R10                          ;            and object if we come across one
        CMPHI   R11,R8
        BreakPt "Invalid age list ptr",LS
        LDR     R14,[R8, #std_backlink]
        TEQ     R14,R0
        BreakPt "Cyclic age list",EQ
        STR     R0, [R8,#std_backlink]
        TEQ     R8, R6
        MOVNE   R7,R8
        BNE     %BT57
      ]

        LDR     R6, ageheadblock_p
        MOV     R7, R6
07      LDR     R8, [R7, #std_link]
        STR     R7, [R8, #std_backlink]
        TEQ     R8, R6
        LDRNE   R7, [R8, #std_link]             ; optimisation: do the loop again with R7 and R8 swapped!
        STRNE   R8, [R7, #std_backlink]
        TEQNE   R7, R6
        BNE     %BT07

      [ debugcache
        LDR     R9, cacheindex
        ADD     R14, R9, #cache_deletedblock
        STR     R14, [R14, #std_link]
        STR     R14, [R14, #std_backlink]
        MOV     R14, #0
        STR     R14, [R9, #cache_deletedamount]
        CheckCache "compactcache exit"
      ]

; finished - tidy up the deletedblocks stuff

90      LDR     R9, cacheindex
        TEQ     R9, #0
        ADDNE   R14, R9, #cache_deletedblock
        STRNE   R14, [R14, #std_link]
        STRNE   R14, [R14, #std_backlink]
        MOVNE   R14, #0
        STRNE   R14, [R9, #cache_deletedamount]

        ProfOut Res_Reloc               ; must quote type explicitly here!
        EXITS
        LTORG

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R0 = future address of link
;       R7 = current address of link
;       R6 -> chain of map blocks
; Out   R1,[R7] = relocated form of R6
;       R0 = R0 + 4 (for next time)
;       All map blocks in the chain are relocated

reloc_mapblocks Entry "R0,R6-R8"

01
        RelocA  R1,R6,R7,R10,R11, R0,R14        ; R1,[R7] := relocated form of R6, anchor = R0

        ADD     R7,R6,#map_link                 ; R7 -> old anchor
        LDR     R6,[R7]                         ; R6 -> block to relocate
        TEQ     R6,#0
        ADDNE   R0,R1,#map_link                 ; R0 -> new anchor
        BNE     %BT01

        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R0 = future address of link
;       R7 = current address of link
;       R6 -> chain of transform blocks
; Out   R1,[R7] = relocated form of R6
;       R0 = R0 + 4 (for next time)
;       All transform blocks in the chain, and any chunks within them, are relocated

reloc_transforms Entry "R0,R6-R8"

01
        RelocA  R1,R6,R7,R10,R11, R0,R14        ; R1,[R7] := relocated form of R6, anchor = R0

; relocate any chunks contained therein


;       ASSERT  trn1_PixelsPtrs = trn4_PixelsPtrs+4*8
        ADD     R0,R1,#trn_PixelsPtrs           ; R0 -> relocated index
        ADD     R7,R6,#trn_PixelsPtrs-4         ; R7 -> current index - 4
;       MOV     R8,#2*8                         ; R8 = counter
        LDR     R8,[R6,#trn_nchunks]            ; R8 = counter (number of chunks)

        Debug   del,"Stage 2: transform block, nchunks",R6,R8

        Push    "R0,R7"

13      LDR     R6,[R7,#4]!
        TEQ     R6,#0
        BLNE    reloc_chunk                     ; R1,[R7] := relocated form of R6
        ADD     R0,R0,#4                        ; R0 = new anchor pointer

        SUBS    R8,R8,#1
        BNE     %BT13

        Pull    "R0,R7"

        LDR     R6,[R7,#trn_link-trn_PixelsPtrs+4]!     ; old R7 was pointing just before pixelsptrs
        TEQ     R6,#0
        ADDNE   R0,R0,#trn_link-trn_PixelsPtrs          ; old R0 was pointing at pixelsptrs (new address)
        BNE     %BT01

        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    [R7,#4] -> pixo block
;       R8 = number of chunks
;       R0 = anchor pointer
; Out   R1,[R7,#4]! = relocated form of old contents
;       R0 incremented

reloc_pixo Entry "R0,R6-R8"             ; watch out for direct stack access (R7)

;       LDR     R6,[sp]
;       LDRB    R14,[R6,#hdr_masterflag]
;       TEQ     R14,#msf_master
;       MOVEQ   R8,#hdr_transformend - hdr_pixarray0
;       MOVNE   R8,#hdr_pixarray1 - hdr_pixarray0

        LDR     R6,[R7,#4]!
        STR     R7,[SP,#2*4]                    ; knobble the stack directly!

        Debug   del,"Stage 2: reloc_pixo old anchor, new anchor, block, nchunks",R7,R0,R6,R8

        CMP     R6,#0
        ADDEQ   R0,R0,#4
        STREQ   R0,[SP,#0*4]                    ; update caller's R0
        EXIT    EQ

        RelocA  R1,R6,R7,R10,R11, R0,R14        ; R1,[R7] := relocated form of R6

        ADD     R0,R0,#4
        STR     R0,[SP,#0*4]                    ; update caller's R0

        ADD     R0,R1,#pixo_pointers            ; R0 = future address of links
        ADD     R7,R6,#pixo_pointers-4          ; R7 = current address of links (-4)

12      LDR     R6,[R7,#4]!
        TEQ     R6,#0
        Debug   del,"pixo chunk old anchor, new anchor, block, counter",R7,R0,R6,R8
        BLNE    reloc_chunk
        ADD     R0,R0,#4
        SUBS    R8,R8,#1
        BNE     %BT12

        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    [R7] = R6 -> chunk
; Out   R1,[R7] = relocated form of R6
;       if this is a split chunk, any characters within it are relocated

reloc_chunk Entry "R0,R6-R8"

        RelocA  R1,R6,R7,R10,R11, R0,R14   ; R1,[R7] := relocated form of R6

        LDR     R14,[R6,#pix_flags]
        TST     R14,#pp_splitchunk
        EXIT    EQ

; relocate constituent characters of a split chunk

        Debug   del,"Stage 2: split chunk at",R6

        ADD     R0,R1,#pix_index        ; R0 -> relocated index
        ASSERT  std_size = 0
        LDR     R7,[R6],#pix_index-4
        BIC     R7,R7,#size_flags       ; ignore lock bit etc.
        SUB     R7,R7,#pix_index

13      LDR     R8,[R6,#4]!

        RelocA  R1,R8,R6,R10,R11, R0,R14   ; R1,[R6] := relocated form of R8
        ADD     R0,R0,#4                   ; R0 = anchor pointer for next time

        SUBS    R7,R7,#4
        BNE     %BT13

        EXIT

;.............................................................................

; DEBUGGING ROUTINES to check the state of the cache

      [ debugcache

; In    cache_delhead -> chain of deleted blocks
; Out   Address exception if any backlink still has dgb_flagbit set

dbg_flagbit     *       1 :SHL: 31

checkbacklinks EntryS "R6-R9"

        LDR     R6,cacheindex
        LDR     R7,[R6,#cache_free]
        ADD     R6,R6,#cache_data

        LDR     R8,[R6,#cache_deltail - cache_data]
        MOV     R9,#0                                   ; R9 = data offset (0 initially)
        STR     R9,[R8,#std_link]                       ; rewrite last link as 0 (easier to test for)
        LDR     R8,[R6,#cache_delhead - cache_data]     ; R8 = address of first deleted block

01      CMP     R6,R8
        BHS     %FT11
        LDR     R14,[R6,#std_backlink]  ; check that the flag bit is now 0
        TST     R14,#dbg_flagbit        ; ie. that the block has been scanned as part of the tree
        BreakPt "Block not scanned",NE
        LDR     R14,[R6,#std_size]
        BIC     R14,R14,#size_flags
        ADD     R6,R6,R14
        B       %BT01

11      TEQ     R6,R7                   ; have we reached the end?
        BEQ     %FT02

        Debug   del,"checkbacklinks: hole at",R8

        LDR     R8,[R8,#std_link]       ; look for next deleted block
        TEQ     R8,#0
        MOVEQ   R8,R7
        LDR     R14,[R6,#std_size]
        BIC     R14,R14,#size_flags
        ADD     R6,R6,R14               ; step past deleted block
        ADD     R9,R9,R14               ; and update amount to subtract
        B       %BT01
02
        EXITS

ccm_nocache     DCB     "(no cache present)",0
ccm_badanchor   DCB     "(bad anchor pointer)",0
ccm_badpointer  DCB     "(bad pointer)",0
ccm_badcount    DCB     "(some blocks missing)",0
ccm_badchunk    DCB     "(bad non-split chunk)",0
ccm_badsize     DCB     "(some memory missing)",0
ccm_badagelink  DCB     "(bad link in age list)",0
ccm_badagebacklink  DCB "(bad backlink in age list)",0
ccm_badparentage    DCB "(split chunk older than char(s))",0
ccm_badparentage2   DCB "(transform block older than chunk)",0
ccm_badparentage3   DCB "(transform block older than next one)",0
                ALIGN

        MACRO
$l      CheckBlock $rb,$rp
$l
        Push    "R6,R8,R14"
     [ $rp <> R6
        MOV     R6,$rb
        MOV     R8,$rp
     |
      [ $rb <> R8
        MOV     R8,$rp
        MOV     R6,$rb
      |
        !       1, "Can't do this!"
      ]
     ]
        BL      checkblock
        Pull    "R6,R8,R14"
        MEND


; In    R6 -> block to be considered
;       R8 -> parent pointer of block

total_count     DCD     0               ; it's OK - only for debugging!
total_size      DCD     0

checkblock EntryS "R0,R1,R9,R11"

        LDR     R9,fontcache
        LDR     R11,fontcacheend

        CMP     R6,R9
        CMPHS   R11,R6
        BLO     %FT01

        LDR     R14,total_count
        ADD     R14,R14,#1
        STR     R14,total_count
        LDR     R14,total_size
        LDR     R0,[R6,#std_size]
        BIC     R0,R0,#size_flags
        ADD     R14,R14,R0
        STR     R14,total_size

        LDR     R14,[R6,#std_anchor]
        TEQ     R14,R8
        addr    R1,ccm_badanchor,NE
        BNE     chkerr

        EXITS

01      CMP     R6,#PIX_UNCACHED
        EXITS   LS

        MOV     R0,#1
        SWI     XOS_ReadDynamicArea             ; out: R0 -> start of RMA, R1 = size
        ADD     R1,R0,R1
        CMP     R6,R0                           ; check that pointer is in RMA
        CMPHS   R1,R6
        EXITS   HS
        CMP     R6,#&3800000                    ; otherwise check that it's in ROM
        RSBHSS  R1,R6,#&4000000
        EXITS   HS
        CMP     R6,#&FC000000                   ; or in new ROM location
        addr    R1,ccm_badpointer,LO
        BLO     chkerr

        EXITS


; In    R0 -> string to print if this fails
;       fontcache/fontcacheend -> start/end of cache
; Out   If cache OK, exits with all registers and flags preserved
;       If cache knackered, prints out the message in R0 to the debug stream and causes an address exception.

checkcache PEntryS CheckCache, "R0-R11"

        LDR     R14,checkcache_enabled
        TEQ     R14,#0
        PExitS  EQ

;        DebugS  cache,"Checking cache for ",r0

        MOV     R14,#0
        STR     R14,total_count
        STR     R14,total_size

        LDR     R9,fontcache
        LDR     R11,fontcacheend        ; R9,R11 = font cache start/end pointers

        LDR     R8,cacheindex           ; index must be present
        CMP     R8,R9
        CMPHS   R11,R8
        addr    R1,ccm_nocache,LO       ; "no cache present"
        BLO     chkerr

; check font index

        ASSERT  cache_free = 0
        MOV     R7,#maxf-1              ; skip font 0 (cache_free)

chklp   LDR     R6,[R8,#4]!

        CheckBlock R6,R8

        TEQ     R6,#0
        BEQ     %FT03                   ; no pointer

; check constituent parts of font header

        Push    "R6-R8"                 ; remember font ptr, counter and anchor ptr

        ADD     R8,R6,#hdr_MetricsPtr-4

;       MOV     R7,#hdr_pixarray0 - hdr_MetricsPtr
        MOV     R7,#hdr4_PixoPtr - hdr_MetricsPtr
02      LDR     R6,[R8,#4]!
        CheckBlock R6,R8
        SUBS    R7,R7,#4
        BNE     %BT02

        LDR     R6,[sp]

        LDR     R7,[R6,#hdr4_nchunks]
        BL      check_pixo              ; updates R8

        LDR     R7,[R6,#hdr1_nchunks]
        BL      check_pixo              ; updates R8

        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_master
        BEQ     %FT73

; check transform blocks (4-bpp and 1-bpp)

        MOV     R7,#hdr_transformend - hdr_transforms
72      LDR     R6,[R8,#4]!
        TEQ     R6,#0
        BLNE    checktransform
        BVS     chkerr_lose3
        SUBS    R7,R7,#4
        BNE     %BT72
73
        Pull    "R6-R8"

03      SUBS    R7,R7,#1
        BNE     chklp

; check map index

        ADD     R8,R8,#cache_mapindex - 4*maxf
        MOV     R7,#MapIndexSize
04      LDR     R6,[R8,#4]!
        TEQ     R6,#0
        BLNE    checkmapblock
        BVS     chkerr
        SUBS    R7,R7,#1
        BNE     %BT04

; now scan the age list, checking that we get the same total number of blocks

        LDR     R6,ageheadblock_p
        MOV     R1,R6
        MOV     R8,#-1                  ; number of blocks so far (-1 for unclaimed marker)

50      MOV     R7,R1
        LDR     R1,[R7,#std_link]

        CMP     R1,R9
        CMPHI   R11,R1
        addr    R1,ccm_badagelink,LO
        BLO     chkerr

        LDR     R14,[R1,#std_backlink]
        CMP     R14,R7
        addr    R1,ccm_badagebacklink,LO
        BLO     chkerr

        TEQ     R1,R6                   ; continue until we reach the head pointer again
        ADDNE   R8,R8,#1
        BNE     %BT50

        LDR     R14,total_count
        TEQ     R14,R8
        addr    R1,ccm_badcount,NE
        BNE     chkerr

        LDR     R6,cacheindex
        LDR     R14,[R6,#cache_deletedamount]
        ADD     R6,R6,R14
        ADD     R6,R6,#cache_data
        LDR     R14,total_size
        ADD     R6,R6,R14               ; R6 = estimated end address

        LDR     R7,cacheindex
        LDR     R7,[R7,#cache_free]
        TEQ     R6,R7                   ; does this tally with cachefree?
   ;;   LDRNE   R8,spacewanted
   ;;   ADDNE   R6,R6,R8
   ;;   TEQNE   R6,R7                   ; (try again with new block included)
        addr    R1,ccm_badsize,NE
        BNE     chkerr

        PExitS                          ; must preserve flags and R0

chkerr_lose3
        ADD     sp,sp,#3*4              ; correct stack

chkerr

; Added by Chris Murray:
;
; Saves the corrupted font cache out as "Root:BadCache" so that we
; can examine it with *CheckCache.

      [ debugdumpcache
        ADR     R0,savebadcache
        SWI     XOS_CLI
      ]

        Debuga  cache,"Cache corrupt "
        MOV     R0,R1
 DebugS cache," - ",R0
;        BL      Neil_Write0
        Debuga  cache," at "
        LDR     R0,[sp, #Proc_RegOffset]
;        BL      Neil_Write0
 DebugS cache,"",R0
        LDR     R14,[sp,#Proc_RegOffset+12*4]
        Debug   cache,":"
        Debuga  cache,"count,size =",#total_count,#total_size
        Debuga  cache,", R6,R7,R8 =",R6,R7,R8
        Debug   cache,", LR =",R14

        ADD     sp,sp,#Proc_RegOffset
        LDMIA   sp,{R0-R11}             ; get all registers back for perusal
        MOV     R14,#0
        LDR     R14,[R14,#-4]           ; crash!
        PExitS

      [ debugdumpcache
savebadcache
        DCB "SaveFontCache Root:BadCache",0
        ALIGN
      ]

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    [R8,#4] -> pixo block
;       R7 = number of chunks within the block
; Out   block and chunks checked
;       R8 incremented

check_pixo EntryS "R3,R4,R6,R8"          ; stack is accessed directly

        LDR     R6,[R8,#4]!
        STR     R8,[SP,#Proc_RegOffset+3*4]     ; update stack directly

        CheckBlock R6,R8
        CMP     R6,#0
        EXITS   EQ

        ADD     R8,R6,#pixo_pointers-4

12      LDR     R6,[R8,#4]!
        CheckBlock R6,R8
        CMP     R6,#0
        BEQ     %FT14

        LDR     R14,[R6,#pix_flags]
        TST     R14,#pp_splitchunk
        BNE     %FT60

; check the index of a non-split chunk (sequential and within the block)

        ASSERT  std_size = 0
        LDR     R3,[R6],#pix_index
        BIC     R3,R3,#size_flags       ; R3 = size of block
        MOV     R4,#32
        TST     R14,#pp_4xposns
        MOVNE   R4,R4,LSL #2
        TST     R14,#pp_4yposns
        MOVNE   R4,R4,LSL #2            ; R4 = number of elements in index
        MOV     R2,R4,LSL #2
        SUB     R2,R2,#1                ; R2 = minimum offset (exclusive)
        SUB     R3,R3,#pix_index        ; R3 = maximum offset (exclusive)

64      LDR     R14,[R6],#4
        TEQ     R14,#0
        BEQ     %FT65
        CMP     R14,R2
        CMPHI   R3,R14
        SUBLS   R6,R6,#4
        addr    R1,ccm_badchunk,LS
        BLS     chkerr_lose3
        MOV     R2,R14                  ; R2 = minimum offset for next time

65      SUBS    R4,R4,#1
        BNE     %BT64

        B       %FT14

60      BL      checkchunk              ; check constituent characters of a split chunk
        BVS     chkerr_lose3

14      SUBS    R7,R7,#1
        BNE     %BT12

        EXITS

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R6 -> split chunk block
; Out   VS => R1 -> error message, R3,R4,R6,R7,R8 corrupted

checkchunk EntryS "R2-R8"

        MOV     R3,R6                   ; R3 = parent block pointer
        LDR     R4,ageheadblock_p       ; R4 = end of list marker
        ASSERT  std_size = 0
        LDR     R7,[R6],#pix_index-4
        BIC     R7,R7,#size_flags       ; ignore lock bit etc.
        SUB     R7,R7,#pix_index
13      LDR     R2,[R6,#4]!
        CMP     R2,#PIX_UNCACHED
        BLS     %FT79
        CheckBlock R2,R6
71      TEQ     R2,R4                   ; error if reached end of list
        BEQ     err_oldparent
        TEQ     R2,R3
        LDRNE   R2,[R2,#std_link]       ; should reach parent first (younger than child)
        BNE     %BT71
79      SUBS    R7,R7,#4
        BNE     %BT13

        EXITS

err_oldparent
        ADD     sp,sp,#Proc_RegOffset+7*4
        addr    R1,ccm_badparentage     ; split chunk must be younger than children
        SETV
        Pull    "PC"

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R6 -> transform block
;       R8 -> link pointer
; Out   VS => R1 -> error message

checkmapblock EntryS "R2-R8"

01
        CheckBlock R6,R8

        MOV     R3,R6                   ; R3 = parent block pointer
        LDR     R4,ageheadblock_p       ; R4 = end of list marker

        LDR     R2,[R3,#map_link]
        TEQ     R2,#0
        EXITS   EQ

72      TEQ     R2,R4                   ; error if reached end of list
        BEQ     err_oldparent3
        TEQ     R2,R3
        LDRNE   R2,[R2,#std_link]       ; should reach parent first (younger than child)
        BNE     %BT72

        ADD     R8,R3,#map_link
        LDR     R6,[R8]
        B       %BT01

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R6 -> transform block
;       R8 -> link pointer
; Out   VS => R1 -> error message

checktransform EntryS "R2-R8"            ; stack accessed directly

01
        CheckBlock R6,R8

        MOV     R3,R6                   ; R3 = parent block pointer
        LDR     R4,ageheadblock_p       ; R4 = end of list marker
;       ASSERT  trn1_PixelsPtrs = trn4_PixelsPtrs + 4*8
;       MOV     R7,#16
        LDR     R7,[R6,#trn_nchunks]    ; R7 = number of chunks to check
        ADD     R6,R6,#trn_PixelsPtrs-4

13      LDR     R2,[R6,#4]!             ; R2 -> block, R6 -> anchor
        TEQ     R2,#0
        BEQ     %FT79

        CheckBlock R2,R6

        MOV     R5,R6
        MOV     R6,R2
        BL      checkchunk
        EXIT    VS
        MOV     R6,R5

71      TEQ     R2,R4                   ; error if reached end of list
        BEQ     err_oldparent2
        TEQ     R2,R3
        LDRNE   R2,[R2,#std_link]       ; should reach parent first (younger than child)
        BNE     %BT71
79      SUBS    R7,R7,#1
        BNE     %BT13

        LDR     R2,[R3,#trn_link]
        TEQ     R2,#0
        EXITS   EQ

72      TEQ     R2,R4                   ; error if reached end of list
        BEQ     err_oldparent3
        TEQ     R2,R3
        LDRNE   R2,[R2,#std_link]       ; should reach parent first (younger than child)
        BNE     %BT72

        ADD     R8,R3,#trn_link
        LDR     R6,[R8]
        B       %BT01

err_oldparent2
        ADD     sp,sp,#Proc_RegOffset+7*4
        addr    R1,ccm_badparentage2    ; transform block must be younger than chunks
        SETV
        Pull    "PC"

err_oldparent3
        ADD     sp,sp,#Proc_RegOffset+7*4
        addr    R1,ccm_badparentage3    ; transform block must be younger than the next one
        SETV
        Pull    "PC"

      ]

        END
