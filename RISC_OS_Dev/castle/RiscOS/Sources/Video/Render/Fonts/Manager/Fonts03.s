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
; > Sources.Fonts03

;;----------------------------------------------------------------------------
;; Font_FindFont
;;
;; Find font, either matching it directly or creating a new one
;; DefineFont is called to create the font header, which may call
;; FindFont recursively to find an appropriate master font.
;;
;; Entry:  R1 --> font name (terminated by space or ctrl-char)
;;                26, <font number>, {chars}, 0  =>  scaled from another
;;                null                           =>  just delete font
;;         R2,R3 = x,y point size * 16
;;         R4,R5 = x,y resolution (0 ==> use mode data)
;;         R2 < 0 => master font required (outlines or unscaled pixels)
;; Exit :  VC ==> font cache updated, R0 = font handle
;;         VS ==> R0 --> error string
;;----------------------------------------------------------------------------

terminator      *       32 + 1          ; space itself counts as a terminator

SWIFont_FindFont Entry ""

; DebugS cpm,"Font_FindFont: ",R1
; Debug  cpm,"               x,y point size * 16 =",R2,R3
; Debug  cpm,"               x,y resolution      =",R4,R5

        BL      getencodingid           ; [encbuffer] = 3-word encoding extracted from R1, or 0,0,0 if none present
        EXIT    VS
                                        ; this stuff is now set up for finding the master font
        PullEnv

IntFont_FindFont PEntry FindFont, "R6-R12"   ; called from findmaster  -  assumes [encbuffer] set up

        CheckCache "Font_FindFont entry", NoCacheOK

        MOV     R14,#0                  ; no extra transformations in Font_FindFont
        STR     R14,paintmatrix
        STR     R14,transformptr

        BL      setmodedata
        BLVC    defaultres              ; r4,r5 = proper x,y resolution
        BLVC    matchfont               ; look for a match with an existing font
        EXIT    VS
        CacheHit Font, EQ
        BNE     makenewone

; Found a match! - increment reference count and pass back handle
; NB: if slave font, and master font handle = 0, find it again
; we assume that the characteristics of the master won't have changed
; Font_UnCacheFont is responsible for clearing out the slave if required

foundit
        BL      claimfont2              ; increment reference count etc.
                                        ; R1 -> font name already
        STRVCB  R0,currentfont
        STRVCB  R0,futurefont

        PPullS  "$Proc_RegList"

;..........................................................................

; In    r1 -> font name to match with
;       r2,r3 = point size * 16
;       r4,r5 = x,y resolution (dpi)
; Out   NE => not found, else
;       r0 = font handle
;       r6 -> font header

matchfont PEntry Find_Matching, "R1,R2,R7-R9"

        MOV     R9,#0                   ; search font blocks, not encodings
        MOV     R2,#"F"
        BL      findfield
        BLNE    findfield_error         ; field "\F" not found
        PExit   VS
        LDR     R2,[sp,#1*4]            ; recover R2 (R1 -> font identifier still)

        MOV     R14,#MAT_MARKER
        STR     R14,tempmatrix+mat_marker
        CMP     R2,#0                   ; if looking for master font, ignore matrix
        BLGE    parsematrix_temp        ; [tempmatrix..] = supplied font matrix
        PExit   VS

        MOV     R0,#1                   ; current font number (0 is illegal)

fflp1   LDR     R8,cacheindex
        TEQ     R8,#0
        LDRNE   R6,[R8,R0,LSL #2]       ; R6 -> font header
        TEQNE   R6,#0
        BEQ     findnext                ; no data

; check for matching names

        Push    "R0"
        ADD     R0,R6,#hdr_name         ; R0 -> 0-terminated string
        MOV     R9,#0                   ; R9=0 => scan font blocks only
        BL      comparefontid_gotfield  ; R1 -> font identifier (\F section)
        Pull    "R0"
        BNE     findnext

; check that the encodings match

        Push    "R2-R4"
        ADR     R14,encbuffer
        LDMIA   R14,{R2-R4}
        ADD     R14,R6,#hdr_encoding
        LDMIA   R14,{R7-R9}
        TEQ     R2,R7
        TEQEQ   R3,R8
        TEQEQ   R4,R9
        Pull    "R2-R4"
        BNE     findnext

; check for master font matching

        ASSERT  msf_master > msf_ramscaled
        ASSERT  msf_master > msf_normal

        CMP     R2,#-1                  ; if R2<0, we want a master font
        LDRLEB  R14,[R6,#hdr_masterflag]
        RSBLES  R14,R14,#msf_master-1
        CMPLE   R2,R2                   ; EQ => found
        PExit   EQ

; check for matching sizes / resolutions
; (no need to check xmag/ymag, cos only xscale/yscale are modified)

        LDR     R14,[R6,#hdr_xsize]
        TEQ     R14,R2
        LDREQ   R14,[R6,#hdr_ysize]
        TEQEQ   R14,R3
        LDREQ   R14,[R6,#hdr_xres]
        TEQEQ   R14,R4
        LDREQ   R14,[R6,#hdr_yres]
        TEQEQ   R14,R5
        BNE     findnext

; now check that the matrices match

        LDR     R14,tempmatrix + mat_marker
        LDR     R7,[R6,#hdr_FontMatrix]

        TEQ     R14,#MAT_MARKER
        TEQEQ   R7,#0
        PExit   EQ                      ; no matrix in either

        TEQ     R14,#MAT_MARKER
        TEQNE   R7,#0
        BEQ     findnext                ; otherwise we must have both matrices

        Push    "R0-R11"

        ASSERT  mat_enduser = 6*4       ; 6 registers required for each

        ADR     R0,tempmatrix
        LDMIA   R0,{R0-R5}              ; 6 registers
        ADD     R7,R7,#mtb_matrix
        LDMIA   R7,{R6-R11}             ; 6 registers
        TEQ     R0,R6
        TEQEQ   R1,R7
        TEQEQ   R2,R8
        TEQEQ   R3,R9
        TEQEQ   R4,R10
        TEQEQ   R5,R11

        Pull    "R0-R11"

        PExit   EQ

findnext
        ADD     R0,R0,#1
        CMP     R0,#maxf-1
        BLE     fflp1                   ; at end, NE => no match

        PExit

;.........................................................................

; no match found - construct a new font

Proc_RegList    SETS    "R6-R12"                ; continued from Font_FindFont

makenewone
        ProfOut FindFont
        ProfIn  Find_NewOne

        Debug   cc,"Look for spare handle"

        BL      makeindex                       ; R8 -> index (created if necessary)
        ProfOut ,VS
        Pull    "R6-R12,PC",VS
        MOV     R0,#1                           ; 0th font is illegal
fflp2
        LDR     R14,[R8,R0,ASL #2]
        TEQ     R14,#0
        BEQ     gothandle                       ; free handle
        ADD     R0,R0,#1
        CMP     R0,#maxf
        BCC     fflp2

; no spare handles - unload an unused font (the oldest)

        Debug   cc,"No spare handles - unload oldest unused font"

        LDR     R8,cacheindex
        LDR     R7,ageheadblock_p
        LDR     R6,ageunclaimed_p       ; NB: must skip this block as it has NO anchor pointer!
        B       fflp3a

fflp3   LDR     R14,[R6,#std_anchor]    ; look for a block with an anchor in the cache index
        SUB     R14,R14,R8              ; then deduce the handle from the anchor
        CMP     R14,#4*maxf
        BHS     fflp3a

        LDR     R0,[R6,#hdr_usage]      ; is this font claimed?
        TEQ     R0,#0
        MOVEQ   R0,R14,LSR #2
        BEQ     gothandle

fflp3a  LDR     R6,[R6,#std_link]
        TEQ     R6,R7                   ; finished if we get back to the header block
        BNE     fflp3

        B       err_nohandles

; now try to load in the font - R0 = font handle

gothandle
        Debug   cc,"Defining font:",R0

        Push    "R0-R5"                         ; save parameters!

        BL      DefineFont
        Debug   cc,"Font defined: R0 =",R0
        DebugE  err,"Error from DefineFont: "

        PPullS  "R0-R5,$Proc_RegList"

err_nohandles
        CheckCache "Font_FindFont exit"

        ProfOut
        PullEnv

        ADR     R0,ErrorBlock_FontNoHandles
        B       MyGenerateError
        MakeErrorBlock FontNoHandles    ; "No more font handles"

;.............................................................................

; In    [cacheindex] -> index, or 0 if no index present
; Out   R8 = [cacheindex] -> index, cache extended if necessary

makeindex Entry "R0,R6,R7"

        LDR     R8,cacheindex
        CMP     R8,#0
        EXIT    NE

        LDR     R6,pagesize
        CMP     R6,#cache_data                  ; must be at least this big!
        MOVLT   R6,#cache_data
        MOV     R7,#1024*1024
        BL      extendcache                     ; automatically creates index

        LDR     R8,cacheindex
        Debug   th,"makeindex: R8, fontcachesize =",R8,#fontcachesize

        EXIT    VC

        STRVS   R0,[sp]
        EXIT    VS

;.............................................................................

; In    R6 -> font header
; Out   [R6,#hdr_usage] incremented
;       R6 relocated if nec.
;       master font reclaimed if it wasn't linked in already
; Called from Font_FindFont, Font_UnCacheFile and resetfontmax

claimfont       Entry "R1-R5,R7-R11"

        ASSERT  (hdr_name :AND: 3) = 0
        ASSERT  (hdr_nameend-hdr_name) = 40     ; 10 registers required

        ADD     R14,R6,#hdr_name
        LDMIA   R14,{R1-R5,R7-R11}      ; 10 registers
        Push    "R1-R5,R7-R11"

        MOV     R1,sp                   ; R1 -> font name (copied onto stack)

        LDRB    R2,currentfont
        LDRB    R3,futurefont           ; preserve these
        BL      claimfont2              ; relocates R6, preserves R2,R3
        STRB    R2,currentfont
        STRB    R3,futurefont

        ADD     sp,sp,#hdr_nameend-hdr_name

        EXIT                            ; R6 relocated if nec.

;.............................................................................

; In    R1 -> font name
;       R6 -> font header
; Out   Font block marked 'accessed' (useful cos not marked accessed when chars accessed)

claimfont2      Entry "R7"

        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_normal         ; slave font?
        LDREQB  R14,[R6,#hdr_masterfont]
        TEQEQ   R14,#0                  ; does it already have a master?
        BLEQ    findmaster

        LDRVC   R14,[R6,#hdr_usage]     ; only claim if master font OK
        ADDVC   R14,R14,#1
        STRVC   R14,[R6,#hdr_usage]

        MOVVC   R7,R6
        BLVC    markfontclaimed_R7

        MarkAge R6, R7,R14, VC          ; mark block in R6 'accessed'

        DebugE  err,"Claimfont error:"
        EXIT

;.............................................................................

; In    R7 -> font header block
; Out   If [R7,#hdr_usage] = 1, then this and all subblocks are marked 'claimed'
;       All flags and registers preserved

markfontclaimed_R7 Entry "R3-R11"

        LDR     R14,[R7,#hdr_usage]
        TEQ     R14,#1
        EXIT    NE

        LDR     R14,[R7,#std_size]
        ORR     R14,R14,#size_claimed :OR: size_locked   ; used font headers are locked
        STR     R14,[R7,#std_size]

        LDR     R10,fontcache
        LDR     R11,fontcacheend

        MOV     R6,R7                           ; R6 -> font header

        ADD     R8,R7,#hdr_MetricsPtr

;       MOV     R9,#hdr_pixarray0 - hdr_MetricsPtr
        MOV     R9,#hdr4_PixoPtr - hdr_MetricsPtr
01      LDR     R7,[R8],#4
        CMP     R7,R10
        CMPHI   R11,R7
        LDRHI   R14,[R7,#std_size]
        ORRHI   R14,R14,#size_claimed
        STRHI   R14,[R7,#std_size]
        SUBS    R9,R9,#4
        BNE     %BT01

        MOV     R3,#size_claimed
        LDR     R9,[R6,#hdr4_nchunks]
        BL      markpixo                        ; increments R8
        LDR     R9,[R6,#hdr1_nchunks]
        BL      markpixo

; TODO: What about the transform blocks?

        CLRV
        EXIT

;.............................................................................

; In    [R8] -> pixo block (4-bpp or 1-bpp)
;       R9 = number of chunks in block
;       R3=0 => mark released; R3=size_claimed => mark claimed
;       R10 = fontcache
;       R11 = fontcacheend
; Out   This and all subblocks within the cache area are marked 'claimed' or unclaimed depending on R4
;       All flags and registers preserved

markpixo Entry "R4-R9"

        LDR     R8,[R8]
        TEQ     R8,#0
        BEQ     %FT90

        ADD     R8,R8,#pixo_pointers

02      LDR     R7,[R8],#4
        CMP     R7,R10
        CMPHI   R11,R7
        BLS     %FT04
        LDR     R6,[R7,#std_size]
        BIC     R6,R6,#size_claimed
        ORR     R6,R6,R3
        STR     R6,[R7,#std_size]

        LDR     R14,[R7,#pix_flags]
        TST     R14,#pp_splitchunk
        BEQ     %FT04

        ADD     R5,R7,#pix_index
        BIC     R6,R6,#size_flags
        SUB     R6,R6,#pix_index

03      LDR     R4,[R5],#4
        ASSERT  PIX_UNCACHED > 0
        CMP     R4,#PIX_UNCACHED
        LDRHI   R14,[R4,#std_size]
        BICHI   R14,R14,#size_claimed
        ORRHI   R14,R14,R3
        STRHI   R14,[R4,#std_size]
        SUBS    R6,R6,#4
        BNE     %BT03

04      SUBS    R9,R9,#1
        BNE     %BT02

90
        PullEnv

        ADD     R8,R8,#4                ; increment this (for convenience of caller)

        MOV     PC,LR

;.............................................................................

; In    R6 -> font header block
; Out   If [R6,#hdr_usage] = 0, then this and all subblocks are marked 'released'
;       All flags and registers preserved

markfontreleased_R6 EntryS "R3-R11"

        LDR     R14,[R6,#hdr_usage]
        TEQ     R14,#0
        EXITS   NE

        LDR     R14,[R6,#std_size]
        BIC     R14,R14,#size_claimed :OR: size_locked    ; unused font headers are NOT locked
        STR     R14,[R6,#std_size]

        MarkAge R6,R10,R11              ; mark font block newer than its children
                                        ; then only the locked subblocks will remain by the time it's deleted
        LDR     R10,fontcache
        LDR     R11,fontcacheend

        MOV     R7,R6                   ; remember font header pointer

        ADD     R8,R6,#hdr_MetricsPtr

;       MOV     R9,#hdr_pixarray0 - hdr_MetricsPtr
        MOV     R9,#hdr4_PixoPtr - hdr_MetricsPtr
01      LDR     R6,[R8],#4
        CMP     R6,R10
        CMPHI   R11,R6
        LDRHI   R14,[R6,#std_size]
        BICHI   R14,R14,#size_claimed
        STRHI   R14,[R6,#std_size]
        SUBS    R9,R9,#4
        BNE     %BT01

        MOV     R3,#0                   ; remove size_claimed bit
        LDR     R9,[R7,#hdr4_nchunks]
        BL      markpixo
        LDR     R9,[R7,#hdr1_nchunks]
        BL      markpixo

; now move the unclaimed font marker to the head of the list

        LDR     R7,ageunclaimed_p
        RemLink R7,R8,R9                        ; remove from chain first
        LDR     R9,ageheadblock_p
        LDR     R8,[R9,#std_link]
        StrLink R7,R8,R9
        STR     R7,[R9,#std_link]
        STR     R7,[R8,#std_backlink]

        EXITS

;.............................................................................

; reconnect slave font to master
; leafnames are still valid, as UnCacheFont and resetfontmax scan these
; if master is referenced, ensure header data is re-read
; NB: cached pixel data is still valid, since UnCacheFont unloads it
;
; In    R6 -> font header block
;       R1 -> font name (copied somewhere outside the cache)
;       [R6,#hdr_masterfont] = 0
; Out   [R6,#hdr_masterfont] = handle of appropriate master font
;       master font claimed, and GetPixelsHeader called on it for 1 and 4-bpp

findmaster Entry "R0,R2-R5"

; find an appropriate master font

        PushP   "findmaster: slave font header",R6

        Debug   th,"Find master font: R6,R1 =",R6,R1

        MOV     R2,#-1
        BL      IntFont_FindFont        ; R0 = master font handle  -  this call assumes [encbuffer] set up
        BVS     %FT02                   ; R4,R5 preserved

02
        PullP   "findmaster: slave font header",R6

        Debug   th,"Reconnecting slave to master:",R6,R0
        STRVCB  R0,[R6,#hdr_masterfont]

        STRVS   R0,[sp]
        EXIT

;.............................................................................

; see if font (R0) is unused - if so, Z is set on exit

testunused Entry "R8"

        LDR     R8,cacheindex
        TEQ     R8,#0
        LDRNE   R8,[R8,R0,ASL #2]
        TEQNE   R8,#0
        TOGPSR  Z_bit,R14                       ; reverse sense of Z flag
        LDREQ   R8,[R8,#hdr_usage]
        TEQEQ   R8,#0

        EXIT

;.............................................................................

; In    R1 -> string as passed to Font_FindFont
; Out   [encbuffer] = lower-cased version of encoding id, or 0,0,0 if not present

getencodingid Entry "R0-R5,R9"

        DebugS  enc,"getencodingid: ",R1

        MOV     R2,#"E"
        BL      findfield               ; EQ => R1 -> point in string where field was found
        BEQ     %FT04

        ; no encoding supplied - what default should we use?

        MOV     R9,#0                   ; R9=0 => search font blocks only
        LDR     R1,[sp,#4]              ; R1 -> original string
        BL      findblockfromID         ; try to find font block
        BVS     %FT99

        LDR     R14,[R2,#lff_flags]     ; is this a 'language font'? (ie IntMetric<n>)
        TST     R14,#lfff_langfont      ; (no longer allow more than one IntMetric file)
        BL      getalphabet_R1
        BNE     %FT04                   ; if it is, must use current alphabet as default encoding

        LDR     R14,encoding_UTF8uc     ; okay, it's a 'symbol font' (ie IntMetrics)
        LDR     R4,[R1,#0]              ; is current alphabet UTF8?
        TEQ     R4,R14
        LDREQB  R4,[R1,#4]
        TEQEQ   R4,#0                   ; if so, let that be default encoding
        BEQ     %FT04

05      MOV     R2,#0
        MOV     R3,#0
        MOV     R4,#0
        ADR     R14,encbuffer
        STMIA   R14,{R2-R4}

        CLRV
        EXIT

04      ADR     R2,encbuffer
        MOV     R5,#12
01      LDRB    R3,[R1],#1              ; R3 = next byte from font string
        CMP     R3,#"\\"
        CMPNE   R3,#32
        SUBLE   R1,R1,#1                ; LE => terminator: step back one,
        MOVLE   R3,#0                   ; so we can pad with zeros
        BLE     %FT02
        uk_LowerCase R3,R14
02      STRB    R3,[R2],#1
        SUBS    R5,R5,#1
        BNE     %BT01

; blat out "glyph" - we store this as 0,0,0
        ADR     R14,encoding_glyph
        LDMIA   R14,{R2,R3}
        ADR     R14,encbuffer
        LDMIA   R14,{R4,R5}
        TEQ     R2,R4
        TEQEQ   R3,R5
        BEQ     %BT05

        ADR     R1,encbuffer
        MOV     R9,#lfff_encoding       ; check the encoding exists, so we can return an error
        BL      findblockfromID_noqual  ; immediately, rather than later

      [ debugenc
        ADR     R14,encbuffer
        DebugS  enc,": encoding set to ",R14
      ]

        EXIT    VC

99      STRVS   R0,[sp]                 ; error exit
        DebugE  enc," - error "
        EXIT

encoding_UTF8uc  DCB     "UTF8"
encoding_glyph   DCB     "glyph",0,0,0
;encoding_UTF8   DCB     "utf8",0,0,0,0
                ALIGN                   ; just in case

;;----------------------------------------------------------------------------
;; DefineFont
;;
;; Called from FindFont to bind a font handle and definition
;; If xsize = -1, FindFont is called recursively to find the master font
;;     This is always used for obtaining the font name and metrics,
;;     but not always the pixel data (if the exact size is available on disc)
;;   The master font contains 4-bpp unscaled bitmap master and/or outlines
;;   The slave contains 1-bpp bitmaps and/or 4-bpp (possibly scaled) bitmaps
;;
;; Entry:  R0 = font number (must be in range 1..255)
;;         R1 --> font name
;;                26, <font number>, {chars}, 0  =>  scaled from another
;;                null                           =>  just delete font
;;         R2,R3 = x,y point size * 16
;;         R4,R5 = x,y resolution (0 ==> use mode data)
;;         R2 < 0 => master font required (outlines or unscaled pixels)
;; Exit :  VC ==> font cache updated, R0 = font handle
;;         VS ==> R0 --> error string
;;----------------------------------------------------------------------------

; Settings of hdr_masterflag

                ^       0
msf_normal      #       1               ; FindFont called with font name
msf_ramscaled   #       1               ; FindFont called with 26,handle
msf_master      #       1               ; FindFont called with R2 = -1

DefineFont Entry "R0"                   ; save font handle for later

        Debug   enc,"DefineFont"

        BL      deletefont              ; clear out any existing data - VDU 23,26,<font> etc.
        BVS     %FT100

        MOV     R8,#0
        LDRB    R14,[R1]                ; is this a RAM-based definition?
        TEQ     R14,#Fontchar
        LDREQB  R8,[R1,#1]
        STR     R8,incache              ; flag

        CMP     R14,#terminator
        TEQCS   R14,R14                 ; if CS, set Z flag
        TEQNE   R14,#Fontchar
        EXIT    NE                      ; null font name => just delete existing font

; claim font header block from cache
; must put it straight into the index, so we can call FindFont recursively

        BL      makeindex               ; R8 -> index (created if not present)
        ADDVC   R8,R8,R0,LSL #2
        MOVVC   R6,#hdr_end             ; reserve enough bytes in font cache
        BLVC    reservecache            ; R6 --> font header
        BVS     %FT100

        LDR     R14,[R6,#std_size]      ; lock font blocks permanently
        ORR     R14,R14,#size_locked
        STR     R14,[R6,#std_size]

        MakeLink R6,R8                  ; [R8] = R6, [R6,#std_anchor] = R8

        PushP   "Font header",R6

; initialise boring bits of font header, and subblock pointers
; must write subblocks to 0 immediately, in case font is accessed
; master font is also set to 0, in case Font_LoseFont is called

        MOV     R14,#1                  ; this is only altered for 4-bpp bitmap
        STR     R14,[R6,#hdr_xmag]
        STR     R14,[R6,#hdr_ymag]
        STR     R14,[R6,#hdr_usage]     ; in case of uncacheing!
        STR     R14,[R6,#hdr_MetSize]   ; slave fonts don't need GetMetricsHeader
        MOV     R14,#0
        ASSERT  (hdr_metricshandle :AND: 3) = 0
        STR     R14,[R6,#hdr_metricshandle]     ; clear all handles, and flags
        STR     R14,[R6,#hdr4_PixOffStart]
        STR     R14,[R6,#hdr4_nchunks]
        STR     R14,[R6,#hdr1_PixOffStart]      ; 0 => unknown, or not in a file
        STR     R14,[R6,#hdr1_nchunks]          ; number of chunks not yet known
        STRB    R14,[R6,#hdr_masterfont]
        ASSERT  msf_normal = 0
        STRB    R14,[R6,#hdr_masterflag]
        STRB    R14,[R6,#hdr_skelthresh]
        STR     R14,[R6,#hdr_oldkernsize]
        MOV     R14,#leaf_scanfontdir   ; nothing known about files yet
        STRB    R14,[R6,#hdr1_leafname]
        STRB    R14,[R6,#hdr4_leafname]
        MOV     R14,#MAT_MARKER
        STR     R14,[R6,#hdr_rendermatrix+mat_marker]
        STR     R14,[R6,#hdr_bboxmatrix+mat_marker]

; initialise all subblock pointers to 0

        MOV     R14,#0
        ADD     R9,R6,#hdr_MetricsPtr   ; R9 --> array
        MOV     R7,#nhdr_ptrs           ; R7 = counter (*4)
01
        STR     R14,[R9],#4
        SUBS    R7,R7,#1
        BNE     %BT01

; set encoding to that contained in encbuffer

        ADR     R14,encbuffer
        LDMIA   R14,{R7,R8,R9}
        ADD     R14,R6,#hdr_encoding
        STMIA   R14,{R7,R8,R9}

        MOV     R14,#base_unknown       ; mark so getmapping_fromR6 will work it out
        STR     R14,[R6,#hdr_base]

        Debug   enc,"DefineFont: R2 =",R2

; if this is a master font, read header information from disc
; NB: slave font uses pathname of master if files are loaded

        CMP     R2,#0
        BGE     slavefont

        MOV     R14,#msf_master
        STRB    R14,[R6,#hdr_masterflag]

        BL      MakePathName            ; constructs a subblock with pathname
        BLVC    GetMetricsHeader        ; read font name etc.
        DebugE  err,"FindFont (after GetMetricsHeader) "
        B       %FT99                   ; don't read outlines/x90y45 yet
                                        ; (may not be needed)

; slave font (either explicitly RAM-scaled, or done implicitly by FontMgr)
; first set up sizes and scale factors

slavefont

        STR     R2,[R6,#hdr_xsize]
        STR     R3,[R6,#hdr_ysize]
        STR     R4,[R6,#hdr_xres]       ; these are overridden by x90y45
        STR     R5,[R6,#hdr_yres]       ; (if used)

        TEQ     R4,#0                   ; resolution 0 => variable (NYI)
        BLNE    getresmatrix            ; sets up resXX/YY (resolution matrix)
        BVS     %FT99

; calculate x,yscale assuming unit matrix - this is recomputed later if there is a font matrix

        MUL     R14,R2,R4               ; used for looking for bitmap files etc
        STR     R14,[R6,#hdr_xscale]
        MUL     R14,R3,R5
        STR     R14,[R6,#hdr_yscale]    ; overridden later if there is a matrix

; setup a copy of the threshold information (if needed ie. newthresholds = true)

        Debug   setth,"Calling Setthresholds from DefineFont... R6 =",R6
        BL      setthresholds           ; setup a copy of the thresholds table

; if RAM-scaled font, look for charlist array

        LDRB    R14,[R1,#0]             ; RAM-scaled font?
        TEQ     R14,#Fontchar
        BNE     notramfont

        MOV     R14,#msf_ramscaled      ; mark as RAM-scaled font
        STRB    R14,[R6,#hdr_masterflag]

        LDRB    R14,[R1,#2]!            ; R1 --> char list
        CMP     R14,#32
        BCC     nocharlist              ; no string

        MOV     R9,R1

01      LDRB    R14,[R9],#1             ; count string
        CMP     R14,#32
        BCS     %BT01

        ADD     R8,R6,#hdr_Charlist     ; R8 --> link
        SUB     R9,R9,R1                ; length of string (inc. terminator)
        ADD     R6,R9,#std_end+3
        BIC     R6,R6,#3                ; word-align length

        BL      reservecache
        BVS     %FT99
        Debug   cc,"Charlist block at",R6

        MakeLink R6,R8                  ; link block in immediately

        LDR     R14,[R6,#std_size]      ; lock charlist array
        ORR     R14,R14,#size_locked
        STR     R14,[R6,#std_size]

        ADD     R7,R6,#std_end          ; R7 --> output
        Debuga  cc,"Copying charlist from",R1
        Debug   cc," to",R7

        Push    "R1"                    ; needed for font handle

01      LDRB    R14,[R1],#1
        STRB    R14,[R7],#1
        CMP     R14,#32
        BCS     %BT01
        Pull    "R1"

        SUB     R6,R8,#hdr_Charlist     ; R6 --> font header (poss. relocated)

; now look to see if the master font exists
; the charlist block will be discarded with the font header if it doesn't

nocharlist
        LDRB    R0,[R1,#-1]             ; master font is explicit
        BL      getfontheaderptr        ; R7 -> font header block
        BVS     %FT99
        LDR     R14,[R7,#hdr_usage]     ; ----- added by NRaine on 15th Oct 98 !!!
        ADD     R14,R14,#1              ; 'find' font
        STR     R14,[R7,#hdr_usage]     ; errors from now on must lose this
        BL      markfontclaimed_R7      ; mark master font claimed
        B       copyfontname

; if not a RAM font, we must first find a suitable master

notramfont
        Debug   matrix,"R1 on entry to FindFont(master)",R1

        Push    "R2-R5"                 ; slave font's parameters
        MOV     R2,#-1
        BL      IntFont_FindFont        ; R0 = master font handle  -  this call uses [encbuffer] contents
        DebugE  err,"Error from IntFont_FindFont: "
        Pull    "R2-R5"
        BVS     %FT99
        PullPx  "notramfont: slave font header",R6

        Debug   matrix,"R1 on exit from FindFont(master)",R1

; stash font matrix (if supplied)

        BL      parsematrix             ; read font matrix (if supplied)
        BVS     %FT99

; copy over font name, and alter it if hdr_masterflag <> msf_master
; or there is a non-null charlist parameter
;       R0 = master font handle (claimed)
;       R6 -> slave font header

copyfontname
        STRB    R0,[R6,#hdr_masterfont] ; remember master font handle

        BL      getfontheaderptr        ; font must be kosher here

        ADD     R1,R7,#hdr_name
        ADD     R9,R6,#hdr_name

01      LDRB    R14,[R1],#1             ; copy name from master to slave
        CMP     R14,#terminator         ; space counts as well
        STRCSB  R14,[R9],#1
        BCS     %BT01

        LDR     R14,[R6,#hdr_Charlist]
        TEQ     R14,#0
        LDREQB  R14,[R7,#hdr_masterflag] ; is this a 'proper' master?
        TEQEQ   R14,#msf_master
        MOVEQ   R14,#cr
        MOVNE   R14,#"*"                ; append "*" if improperly scaled

        ADD     R1,R6,#hdr_nameend

02      CMP     R9,R1                   ; don't overwrite next field
        STRLTB  R14,[R9],#1
        MOV     R14,#cr                 ; pad with <cr>
        BLT     %BT02
        STRB    R14,[R9,#-1]            ; make sure it is terminated!

; slave font must read in one set of pixel data, to initialise font bbox

        BL      setleafnames_R6         ; OK to do this now, as the master font is set up
        BVS     %FT99

        BL      GetPixels4Header
        BLVS    GetPixels1Header        ; try this as a last resort

; tidy up: delete font if error has occurred
;          must be deleted properly, cos other blocks may have been cached
;          Font_LoseFont is called, so master font is lost too

99
        DebugE  err,"FindFont (before PullP) "

        PullP   "Font header",R6

        BVC     %FT100

        DebugE  err,"FindFont (before) "

        MOV     R5,R0                   ; NB: loses master font too
        LDR     R0,[sp,#0*4]            ; get font handle
        BL      SWIFont_LoseFont
        LDR     R0,[sp,#0*4]
        BL      deletefont              ; remove all references
        BL      compactcache            ; tidy up
        MOV     R0,R5
        SETV

        DebugE  err,"FindFont (after) "

; update [currentfont] if font is OK

100     LDR     R14,[sp],#4             ; get stacked font handle
        MOVVC   R0,R14                  ; get font handle if no error
        STRVCB  R0,currentfont          ; use this font by default
        STRVCB  R0,futurefont
        Pull    "PC"

;.............................................................................

; In    R0 = font handle (1..255)
; Out   R7 -> font header block
;       R14 = usage count of font (if V clear)
; Error "Invalid font handle" if font does not exist, or not claimed

getfontheaderptr Entry ""

        Debuga  th,"getfontheaderptr: R0 =",R0

        CMP     R0,#maxf
        TEQCS   R0,R0
        TEQNE   R0,#0
        BEQ     %FT01

        LDR     R7,cacheindex
        TEQ     R7,#0
        LDRNE   R7,[R7,R0,LSL #2]
        TEQNE   R7,#0
        LDRNE   R14,[R7,#hdr_usage]
        TEQNE   R14,#0
        BLEQ    errnometricsdata        ; font does not exist

        Debug   th,", R7 =",R7

        EXIT

01      BL      xerr_BadFontNumber
        EXIT

;.............................................................................

xerr_BadFontNumber ROUT

        ADR     R0,ErrorBlock_FontBadFontNumber
        B       MyGenerateError
        MakeErrorBlock FontBadFontNumber

;.............................................................................

; In    R6 -> font header
;       [R6,#hdr_encoding] = encoding for this font, or 0,0,0
; Out   IntMetricsFName = "IntMetrics" or "Intmetrics<n>"
;       OutlinesFName = "IntMetrics" or "Intmetrics<n>"
;       No cacheing allowed in this routine (called from openmetrics)

setleafnames_R6 Entry "R1,R2,R7"

        LDRB    R0,[R6,#hdr_masterfont]
        CMP     R0,#0
        MOVEQ   R7,R6
        BLNE    getfontheaderptr                ; R7 -> master font header

        LDR     R2,[R7,#hdr_base]               ; must not be base_unknown at this stage
        CMP     R2,#0
        BGE     %FT01

        ADR     R0,outlinesfname
        STR     R0,OutlinesFName
        ADR     R0,metricsfname
        STR     R0,IntMetricsFName

        Debug   th,"IntMetrics, Outlines have no suffix"

        CLRV
        EXIT

metricsfname    DCB     "IntMetrics",0          ; must be word-aligned (for constructname)
                ALIGN
outlinesfname   DCB     "Outlines",0            ; must be word-aligned (for constructname)
                ALIGN

01
        LDR     R14,oldbaseencoding
        TEQ     R2,R14
        STRNE   R2,oldbaseencoding
        ADRNE   R0,outlinesfname
        ADR     R1,outlinesfnamebuffer
        STR     R1,OutlinesFName
        BLNE    copy_r0r1_suffixR2              ; can return "Buffer overflow"
        EXIT    VS

        ADRNE   R0,metricsfname
        ADR     R1,metricsfnamebuffer
        STR     R1,IntMetricsFName
        BLNE    copy_r0r1_suffixR2

      [ debugth
        BVC     %FT98
        LDR     R14,IntMetricsFName
        DebugS  th,"IntMetrics leafname is ",R14
        LDR     R14,OutlinesFName
        DebugS  th,"Outlines leafname is ",R14
98
      ]

        EXIT

;;----------------------------------------------------------------------------
;; MakePathName
;; Entry:  R1 --> font string as passed to Font_FindFont
;;         R6 --> font header block
;;         setleafnames_R6 has been called to set up [OutlinesFName] and [IntMetricsFName]
;; Exit:   [fontfilename] contains <Font$Path> (expanded)
;;         [R6,#hdr_fontname] = font directory name (without prefix)
;;         [R6,#hdr_PathName] -> first dir containing 'IntMetrics'
;;         [R6,#hdr_PathName2] -> alias dir, if Outlines = font name
;;
;; Only call this for the master font - the slaves can just use the master font's path info
;;
;;----------------------------------------------------------------------------

MakePathName    Entry "R1-R5,R8,R9"

        Debug   path,"MakePathName: R1 -> ",R1

; construct the pathname by looking for the block in the list

        MOV     R9,#0                   ; R9=0 => look for fonts, not encodings
        BL      getpathnamefromID       ; R1 -> full font name, R2 = length, [ R3 = offset to font name ]
        BLVC    makefontname            ; R6 -> font header, R3 -> font name to copy in
        ADDVC   R8,R6,#hdr_PathName
        BLVC    makepathblock           ; make cache block for it

        BLVC    GetFontBaseEncoding     ; must call this after [R6,#hdr_PathName] set up (see above)
        BLVC    setleafnames_R6         ; must call this to set up "Outlines<n>"

; check for aliased pixel files - if Outlines contains another font name
; NB: any outline file of length < 256 byte is assumed to contain a font name

        LDRVC   R7,OutlinesFName
        BLVC    constructname           ; R1 -> full name, R2-R5 corrupted
        MOVVC   R0,#OSFile_ReadNoPath
        SWIVC   XOS_File
        TEQ     R0,#object_file
        EXIT    NE                      ; errors also come out here!
        CMP     R4,#255
        EXIT    GT                      ; it's a normal outline file

        SUB     sp,sp,#256              ; make buffer on stack
        MOV     R0,#OSFile_LoadNoPath
        MOV     R2,sp
        MOV     R3,#0                   ; load at given
        STRB    R3,[R2,R4]              ; ensure file is terminated
        SWI     XOS_File
        MOVVC   R1,sp
        BLVC    parsematrix             ; set up font matrix block and contents
        BLVC    getpathnamefromID       ; "Font/encoding not found" is possible
        ADDVC   R8,R6,#hdr_PathName2
        BLVC    makepathblock
        ADD     sp,sp,#256              ; NB: the aliased font cannot be aliased

        EXIT

;.............................................................................

; In    R6 -> font header block
;       R3 -> font name to copy in (0-terminated)
; Out   [R6,#hdr_name..hdr_nameend] = font name (padded with <cr>)

makefontname Entry "R3,R6,R8"

        ADD     R6,R6,#hdr_name
        MOV     R8,#hdr_nameend-hdr_name-1

01      LDRB    R14,[R3],#1             ; copy up to 39 bytes of font name
        TEQ     R14,#0
        BEQ     %FT02
        STRB    R14,[R6],#1
        SUBS    R8,R8,#1
        BGT     %BT01

02      MOV     R14,#cr                 ; must have at least one <cr> in it
03      STRB    R14,[R6],#1
        SUBS    R8,R8,#1                ; V clear
        BGE     %BT03

        EXIT

;.............................................................................

; In    R1 -> string that may contain \M matrix definition, terminated by 0..31
;       R6 -> font block
; Out   [R6,#hdr_FontMatrix] -> matrix block in cache, or is left alone (should be 0)
;       R8 corrupted

parsematrix PEntry ParseMatrix, "R0-R5"

        BL      parsematrix_temp
        BVS     %FT99
        PExit   NE                             ; NE => no matrix present

      [ debugmatrix
        ADR     R0,tempmatrix
        DebugM  matrix,"  create matrix block:",R0
      ]

        ADD     R8,R6,#hdr_FontMatrix
        MOV     R6,#mtb_end
        BL      reservecache
        BVS     %FT98

        LDR     R14,[R6,#std_size]              ; lock matrix block (can't be regenerated)
        ORR     R14,R14,#size_locked
        STR     R14,[R6,#std_size]

        ASSERT  mat_enduser = 6*4
        ADR     R0,tempmatrix
        LDMIA   R0,{R0-R5}                      ; 6 registers
        ADD     R14,R6,#mtb_matrix
        STMIA   R14,{R0-R5}

        MOV     R14,#MAT_MARKER                 ; mark scaled matrix as unknown
        STR     R14,[R6,#mtb_scaledmatrix+mat_marker]

        MakeLink R6,R8                          ; store link and anchor pointer

        Debug   matrix,"Matrix cache block is at",R6

98      SUB     R6,R8,#hdr_FontMatrix           ; restore R6 (possibly relocated)

99      STRVS   R0,[sp]
        PExit

;.............................................................................

; In    R1 -> string that may contain \M matrix definition, terminated by 0..31
; Out   NE, [tempmatrix+mat_marker] = MAT_MARKER => no matrix read
;       EQ => matrix read, [tempmatrix..] = matrix

parsematrix_temp Entry "R0-R5"

        DebugS  matrix,"parsematrix_temp:",R1

        MOV     R2,#"M"
        BL      findfield
        BNE     pm_fail

        ADR     R3,tempmatrix
        MOV     R4,#mat_enduser/4               ; all numbers are read as if they were integers

01      BL      readinteger                     ; CC => no number, CS => R2 = value
        BVS     pm_error
        BCC     pm_error
        STR     R2,[R3],#4

        SUBS    R4,R4,#1
        BNE     %BT01

02      LDRB    R14,[R1],#1
        CMP     R14,#" "
        BEQ     %BT02

        MOVCC   R14,#"\\"
        TEQ     R14,#"\\"                       ; can be terminated by ctrl-char or \ (error otherwise)
        EXIT    EQ                              ; EQ => matrix was read

pm_error
        PullEnv
        ADR     R0,ErrorBlock_FontBadMatrix
        B       MyGenerateError
        MakeErrorBlock FontBadMatrix

pm_fail
        ASSERT  MAT_MARKER <> 0
        MOVS    R14,#MAT_MARKER                 ; NE => matrix not read
        STR     R14,tempmatrix+mat_marker

        EXIT

;.............................................................................

; In    R1 -> string which may contain a number, terminated by 0..32 inclusive
; Out   CC => no number, CS => R2 = value
;       R1 updated

readinteger Entry "R3"

01      LDRB    R3,[R1],#1              ; skip leading spaces
        CMP     R3,#" "
        BEQ     %BT01
        EXIT    CC                      ; no number

        TEQ     R3,#"-"
        SUBNE   R1,R1,#1

        MOV     R0,#&8000000A           ; default is decimal, check for space/ctrl terminator
        SWI     XOS_ReadUnsigned
        EXIT    VS

        TEQ     R3,#"-"                 ; negate number if required
        RSBEQ   R2,R2,#0

        CMP     PC,#0                   ; CS => number was read
        EXIT

;.............................................................................

; In    R1 -> full pathname
;       R2 = length of pathname
;       R6 -> font header block
;       R8 -> link pointer for block
; Out   block allocated and linked in
;       [R8] = [R6,#hdr_pathname(2)] -> block
;       [R6,#hdr_fontmatrix] = 0 or offset into pathname block of matrix
;       R6,R8 relocated

makepathblock Entry "R1-R4"

        PushP   "Saving font header for makepathblock",R6

        ADDVC   R6,R2,#pth_name + 3 + 1 + 12 + 12 + 3      ; allow for "encoding.leafname"
        BICVC   R6,R6,#3                                   ; word-align  ; and padding spaces
        BLVC    reservecache            ; R6 -> new block, R8 relocated
        BVS     %FT99

; copy pathname into block, ensuring that the leafname is word-aligned

        ADD     R3,R6,#pth_name
        RSB     R4,R2,#(4-pth_name-1):AND:3   ; allow for "." on end
        ANDS    R4,R4,#3                ; R4 = no of padding " "s required
        ADD     R14,R4,R2
        ADD     R14,R14,#1              ; allow for "."
        STRB    R14,[R6,#pth_leafptr]   ; offset to leafname position

        MOV     R14,#" "
01      STRNEB  R14,[R3],#1             ; insert required number of leading spaces
        SUBNES  R4,R4,#1
        BNE     %BT01

02      LDRB    R14,[R1],#1             ; copy pathname
        STRB    R14,[R3],#1
        CMP     R14,#terminator         ; space counts as a terminator
        BCS     %BT02
        MOV     R14,#"."                ; finish with a "."
        STRB    R14,[R3,#-1]

        LDR     R14,[R6,#std_size]      ; lock the pathname against deletion
        ORR     R14,R14,#size_locked
        STR     R14,[R6,#std_size]

        MakeLink R6,R8                  ; [R8] --> pathname block
99
        PullP   "restoring font header block",R6

        EXIT

;.............................................................................

; Read cached list of font blocks to find a given font
; this avoids having to search down the font path

; In    R1 -> font/encoding identifier string (look for \E or \F)
;       R9=0 => search list of fonts
;       R9=lfff_encoding => search list of encodings
; Out   R1 -> <path element><fontname>  (in [fontfilename])
;       R2 = length of font filename
;       R3 -> <fontname> (in [fontfilename])
; Error "Font not found", if no matches found

getpathnamefromID Entry ""

        Debug   path,"getpathnamefromID: R1 -> ",R1

        BL      findblockfromID
        EXIT    VS

        MOV     R1,R0                           ; copy the name as given by Font_ListFonts
        ADR     R0,fontfilename
        LDR     R3,[R2,#lff_prefixaddr]
        ADD     R3,R3,#lfpr_prefix

04      LDRB    R14,[R3],#1                     ; copy font prefix
        TEQ     R14,#0
        STRNEB  R14,[R0],#1
        BNE     %BT04

        MOV     R3,R0                           ; R3 -> font name section

05      LDRB    R14,[R1],#1                     ; copy font name (terminated by 0..32)
        CMP     R14,#terminator                 ; V clear
        STRCSB  R14,[R0],#1
        BCS     %BT05
        MOV     R14,#0
        STRB    R14,[R0]                        ; terminate (just in case)

        ADR     R1,fontfilename                 ; R1 -> full fontname
        SUB     R2,R0,R1                        ; R2 = length of [R1..]

        Debuga  path,"getpathnamefromID returns (length =",R2
        DebugS  path,") ",R1
        DebugS  path,"Font name = ",R3

        EXIT

;.............................................................................

; In    R1 -> font or encoding identifier string (look for \E or \F)
;       R9=0 => search font blocks only
;       R9=lfff_encoding => search encoding blocks only
; Out   R2 -> font block in listfonts list
;       R0 corrupt
; Error "Font/encoding not found", if no matches found

findblockfromID Entry ""

        DebugS  path,"findblockfromid: R1 -> ",R1

        TEQ     R9,#0
        MOVEQ   R2,#"F"
        MOVNE   R2,#"E"
        BL      findfield               ; ignore NE (field not found) - use string unaltered
        BL      findblockfromID_noqual

        EXIT

;.............................................................................

; In    R1 -> font or encoding identifier, terminated by "\", space or ctrl-char
;       R9=0 => search font blocks only
;       R9=lfff_encoding => search encoding blocks only
; Out   R2 -> font block in listfonts list
;       R0 corrupt
; Error "Font/encoding not found", if no matches found

findblockfromID_noqual Entry ""

        DebugS  path,"findblockfromid_noqual: R1 -> ",R1

        LDR     R2,listfonts_head
        B       %FT02

01      LDR     R14,[R2,#lff_flags]             ; check that type is that required
        AND     R14,R14,#lfff_encoding
        TEQ     R14,R9
        LDREQ   R0,[R2,#lff_identaddr]          ; R0 -> identifier in font block
        BLEQ    comparefontid_gotfield          ; R1 -> font or encoding identifier, terminated by "/" or <= 32
        EXIT    EQ
        EXIT    VS

        LDR     R2,[R2,#lff_link]
02
        TEQ     R2,#0
        BNE     %BT01

; if font not found on existing list, see if Font$Path might have changed

        BL      try_listfonts_recache           ; must ensure this is up-to-date
        EXIT    VS

        DebugS  path,"findblockfromid (after recache): R1 -> ",R1

; now try again

        LDR     R2,listfonts_head
        B       %FT12

11      LDR     R14,[R2,#lff_flags]             ; check that type is that required
        AND     R14,R14,#lfff_encoding
        TEQ     R14,R9
        LDREQ   R0,[R2,#lff_identaddr]          ; R0 -> identifier in font block
        BLEQ    comparefontid_gotfield          ; R1 -> font or encoding identifier, terminated by "/" or <= 32
        EXIT    EQ
        EXIT    VS

        LDR     R2,[R2,#lff_link]

12      TEQ     R2,#0
        BNE     %BT11

        BL      XError_fontnotfound             ; R9 => which error block to use
        EXIT

;............................................................................

; In    R0 -> target string (terminated by 0)
;       R1 -> candidate string (terminated by 0..32 or "\")
; Out   EQ => strings match (case insensitive)
;       LT => [R0] is earlier alphabetically

comparefontid_gotfield Entry "R0,R1,R2,R6,R7"

        DebugS  path,"comparefontid: target =",R0
        DebugS  path,"            candidate =",R1

10      MOV     R14,R0

01      LDRB    R6,[R0],#1
        LDRB    R7,[R1],#1
        CMP     R7,#"\\"                ; stop on "\", " " or control char
        CMPNE   R7,#" "
        MOVLE   R7,#0
        TEQ     R6,#cr                  ; cheat - font blocks contain cr-terminated font names
        MOVEQ   R6,#0
        uk_LowerCase R6,R14
        uk_LowerCase R7,R14
        CMP     R6,R7
        EXIT    NE                      ; LT => [R0..] earlier, GT => [R1..] earlier
        TEQ     R6,#0
        BNE     %BT01
        EXIT                            ; EQ => strings match

; In    R0 -> target string (terminated by 0)
;       R1 -> candidate string (terminated by 0..32 or "\")
;       R9=0 => look for "\F", else look for "\E"
; Out   EQ => strings match (case insensitive)
;       LT => [R0] is earlier alphabetically

comparefontid ALTENTRY

        TEQ     R9,#0
        MOVEQ   R2,#"F"                 ; font identifier preceded by "\F"
        MOVNE   R2,#"E"                 ; encoding identifier preceded by "\E"
        BL      findfield
        BEQ     %BT10

        BL      findfield_error
        STRVS   R0,[sp]
        EXIT                            ; exit with error "Field not found"

;............................................................................

; In    R1 -> string to look inside (control-char terminated)
;       R2 = character code of field id
; Out   EQ => R1 -> field required
;       NE => R1 preserved (field not found)

findfield Entry "R1,R3"

        LDRB    R14,[R1]                ; if string doesn't start with "\"
        TEQ     R14,#"\\"               ; assume it's just an identifier
        BEQ     %FT01

        TEQ     R2,#"F"                 ; default is font identifier field
        EXIT    EQ                      ; if starts without "\", string is space-terminated

        MOV     R3,#" "                 ; if no "\" at start, initially space counts as a terminator
        B       %FT03                   ; but space is allowed once a "\" has been encountered

01      ADD     R1,R1,#1

02      MOV     R3,#" "-1               ; now legal characters include space
        LDRB    R14,[R1],#1
        TEQ     R2,R14
        STREQ   R1,[sp]                 ; return correct value of R1
        EXIT    EQ

03      LDRB    R14,[R1],#1             ; skip to next "\" or terminator
        CMP     R14,#"\\"
        BEQ     %BT02                   ; continue if this was a "\"

        CMP     R14,R3                  ; 0..R3 count as a terminator
        BGT     %BT03

        CMP     R14,#-1                 ; NE => field not found
        EXIT

;.............................................................................

; In    R2 = character code of field id
; Out   R0 -> error block "\<field> field not found"

findfield_error Entry "R1,R2"

        MOV     R1,#"\\"
        ORR     R1,R1,R2,LSL #8
        Push    "R1"
        ADR     R0,ErrorBlock_FontFieldNotFound
        MOV     R1,sp                   ; R1 -> "\<field id>"
        MOV     R2,#0
        BL      MyGenerateError_2       ; substitute field specifier for %0
        ADD     sp,sp,#4
        EXIT
        MakeErrorBlock FontFieldNotFound

;.............................................................................

; In    R1 -> font name
; Out   R0 -> error block: "Illegal font file in <fontname>"
;       VS

xerr_badfontfile ROUT
        ADR     R0,ErrorBlock_FontBadFontFile2
        B       XError_with_fontname
        MakeErrorBlock FontBadFontFile2

;.............................................................................

; In    R0 -> error block template
;       R1 -> font name
;       R9=0 => "Font not found"
;       R9=lfff_encoding => "Encoding not found"
; Out   R0 -> error buffer, containing expanded font name
;       V flag is set
;       %0 in error block template is translated to font name (R1)
;       %1 in error block template is translated to original error (R2)
;
; Tries to use the name rather than the identifier, if not present
; NB: R9=lfff_encoding, and "\A" and "\a" not present, treats the identifier as the encoding identifier

XError_fontnotfound
        TST     R9,#lfff_encoding
        ADREQ   R0,ErrorBlock_FontNotFound
        ADRNE   R0,ErrorBlock_FontEncodingNotFound

XError_with_fontname Entry "R1-R3,R9", 256      ; buffer on stack to contain font name

        MOV     R2,#0                           ; normally R2 is unused (otherwise it's the previous error message)

xerror_with_fontname_altentry

        MOV     R9,#0                           ; R9=0 => look for font blocks
        MOV     R3,sp                           ; R3 -> output buffer on stack
        BL      get_name_from_id                ; R1 -> font name, from block or string provided

        BL      MyGenerateError_2               ; R1,R2 are parameters

        EXIT

; In    parameters as above, and also:
;       R2 -> original error message (ie. byte after error number)

XError_with_fontname_and_error ALTENTRY

        B       xerror_with_fontname_altentry

        MakeErrorBlock FontEncodingNotFound
        MakeErrorBlock FontNotFound

;;----------------------------------------------------------------------------
;; Opening / closing metrics, 1-bpp and 4-bpp files
;;----------------------------------------------------------------------------
;
; Entry:  R6 -> font block
;         R7 -> leafname within font block
;               [R7]b = data type indicator (leaf_scanfontdir => don't know)
; Exit:   If data comes from file:
;               R1 = [R6,#hdr_metrics/pixelshandle] = file handle
;               [R7..] = leafname
;         If data comes from master font:
;               R1 corrupted
;               [R7]b = data type indicator
;         R0 preserved unless error
;
; !!!! THE CACHE IS NOT ALLOWED TO MOVE INSIDE THIS ROUTINE !!!!

openmetrics Entry "R2,R7"

        BL      setleafnames_R6         ; needed for metrics, as name not stored in font header
        EXIT    VS

        MOV     R2,#hdr_metricshandle
        LDR     R7,IntMetricsFName      ; suffix set up earlier by setleafnames_R6
        B       %FT01

openpixels_R2R7 ALTENTRY
        B       %FT01                   ; values already set up

openpixels4     ALTENTRY
        MOV     R2,#hdr4_pixelshandle
        ADD     R7,R6,#hdr4_leafname
        B       %FT01

openpixels1     ALTENTRY
        MOV     R2,#hdr1_pixelshandle
        ADD     R7,R6,#hdr1_leafname
01
        Debug   cc,"Opening file handle index",R2

        STRB    R2,whichhandle          ; remember for closepixels
        LDRB    R1,[R6,R2]
        TEQ     R1,#0
        EXIT    NE                      ; file already open (R1 = handle)

        LDRB    R14,[R7]
        CMP     R14,#leaf_scanfontdir
        BLE     %FT03

        CMP     R14,#leaf_fromdisc
        EXIT    LT                      ; quick exit if derived from master font

        BL      constructname           ; R1 -> full filename
        BVC     %FT02
        EXIT

; LT => flag was 0 (none), EQ => flag was 1 (not yet scanned) - watch out for this, as it shouldn't happen!

03
      [ debugbrk
        BNE     %FT00
        LDR     LR,[sp,#8]
        Debug   brk,"LR =",LR
        BreakPt "Should have called GetPixelsHeader!",EQ
00
      ]
        BL      err_fontdatanotfound
        EXIT

; open file: R1 -> full filename, [R6,R2] = current file handle (only open file if this is 0)

02      LDRB    R14,[R6,R2]             ; don't reopen file if already set up in ScanFontDir
        TEQ     R14,#0
        MOVNE   R1,R14
        BLEQ    openfile
        STRVCB  R1,[R6,R2]

      [ debugcc
        BVS     %FT00
        Debug   cc,"Opened file handle: fonthdr,ptr,handle =",R6,R2,R1
00
      ]

; check for ROM-based fonts - these can be accessed directly

        TEQ     R2,#hdr_metricshandle
        ADDEQ   R7,R6,#hdr_metaddress-(hdr1_address-hdr1_leafname)      ; bodge R7 if IntMetrics!

        Push    "R0,R1"                 ; save actual file handle for later

        MOVVC   R0,#FSControl_ReadFSHandle
        SWIVC   XOS_FSControl

        AND     R14,R2,#&FF             ; internal file handle = address
        TEQ     R14,#fsnumber_resourcefs ; of data in ROM
        MOVNE   R1,#0
        STR     R1,[R7,#hdr1_address-hdr1_leafname]

        STRVS   R0,[sp]
        Pull    "R0,R1,$Proc_RegList,PC" ; recover file handle

;.............................................................................

; In    R6 -> font header block, with valid font name
; Out   VS, R0 -> error block "Font data for '<fontname>' not found"

err_fontdatanotfound Entry "R1"

        ADR     R0,ErrorBlock_FontDataNotFound2 ; return error if no data found (including font name)
        ADD     R1,R6,#hdr_name
        BL      XError_with_fontname

        EXIT

        MakeErrorBlock FontDataNotFound2

;.............................................................................

; In    R6 --> font header
;       [whichhandle] = index of relevant handle (ie. most recently opened)
; Out   if filing system too stingy, file closed

closemetrics    ROUT                    ; these are actually the same!
closepixels     Entry "R2,R7"

        SavePSR LR
        Push    "R0,LR"                 ; remember error state
        MOV     R0,#OSArgs_ReadInfo
        LDRB    R7,whichhandle          ; R7 = hdr1/4_pixelshandle
        LDRB    R1,[R6,R7]
        SWI     XOS_Args
        Debug   cc,"Close inquiry: OS_Args ReadInfo =",R0,R1,R2, R6
        Pull    "R0,LR"                 ; restore error state
        RestPSR LR

        TST     R2,#&FF00               ; bits 8..15 = no of open files
        MOVNE   R14,#0                  ;              (0 ==> unrestricted)
        STRNEB  R14,[R6,R7]
        BLNE    closefile               ; R1 = file handle

        EXIT

;.............................................................................

; In    R6 --> font header
; Out   metrics and pixels files closed (if open), handles = 0

tidyfiles EntryS "R0,R1"

        LDRB    R1,[R6,#hdr_metricshandle]
        Debug   cc,"Tidyfiles: fonthdr,metricshandle =",R6,R1
        BL      closefile               ; preserves error state
        LDRB    R1,[R6,#hdr4_pixelshandle]
        Debug   cc,"Tidyfiles: fonthdr,pixelshandle4 =",R6,R1
        BL      closefile               ; also does nothing if R1=0
        LDRB    R1,[R6,#hdr1_pixelshandle]
        Debug   cc,"Tidyfiles: fonthdr,pixelshandle1 =",R6,R1
        BL      closefile               ; also does nothing if R1=0

        ASSERT  (hdr_metricshandle:AND:3)=0
        MOV     R14,#0
        STR     R14,[R6,#hdr_metricshandle]

        EXITS                                      ; ignore errors

;.............................................................................

; In    R6 -> font header
;       R7 -> leafname (or 0 => IntMetrics)
; Out   pixels file closed (if open) and [R6,#hdr1/4pixelshandle] = 0

tidyfiles_R7
        EntryS  "R0,R1,R6"

        SUB     R14,R7,R6
        LDRB    R1,[R6,#hdr_metricshandle]!      ; if neither, it's metrics
        TEQ     R14,#hdr1_leafname
        LDREQB  R1,[R6,#hdr1_pixelshandle-hdr_metricshandle]!
        TEQ     R14,#hdr4_leafname
        LDREQB  R1,[R6,#hdr4_pixelshandle-hdr_metricshandle]!
        TEQ     R1,#0
        MOVNE   R14,#0
        STRNEB  R14,[R6]
        BLNE    closefile               ; can't cause cache movement

        EXITS                           ; ignore errors & preserve R0


;;----------------------------------------------------------------------------
;; ScanFontDir
;; Entry:  R6 -> font header block
;;         R7 -> leafname (word-aligned)
;;                could be 'IntMetrics'
;;                         R6 + hdr4_leafname
;;                         R6 + hdr1_leafname
;;         setleafnames_R6 has been called to set up [OutlinesFName] and [IntMetricsFName]
;; Exit:   R1 -> full name of font file (leafname appended to [hdr_PathName]
;;         R0 -> error if V set, corrupted otherwise
;;         [R7..] = new leafname (unless IntMetrics)
;;         [R7]b = 0 if data not found (no error)
;;         [R7]b unchanged if other error (error is returned)
;;         Z unset if file could not be found
;;
;; !!!! THE CACHE IS NOT ALLOWED TO MOVE INSIDE THIS ROUTINE !!!!
;;
;; All decisions about where the data for a font comes from are made here.
;; First character of leafname determines data type and how it is loaded.
;;
;; Threshold 1: max 4-bpp scaled bitmap size
;; Threshold 2: max 4-bpp scaled outline size (use 1-bpp otherwise)
;; Threshold 3: max 4-bpp cached outline size
;; Threshold 4: max 4-bpp width for subpixel positioning (horizontally)
;; Threshold 5: max 4-bpp height for subpixel positioning (vertically)
;;
;; Slave font:
;;      b9999x9999         if exact size found
;;      master outlines    1-bpp
;;      <4-bpp bitmaps>
;;
;;      f9999x9999         if exact size found
;;      x90y45             if exact size found
;;      master bitmaps     if size <= threshold (1), magnified if ratio > 1.5
;;      master outlines    4-bpp (super-sampled)
;;      <1-bpp bitmaps>
;;
;; Master font:
;;      outlines           hdr1_leafname
;;      x90y45             hdr4_leafname
;;      f9999x9999         if contents of x90y45 are 'f9999x9999'
;;
;;----------------------------------------------------------------------------

ScanFontDir Entry "R0,R2-R8"

; if master font, 1-bpp stuff is outlines, 4-bpp is x90y45

        Debug   th,"ScanFontDir: entry R6,R7 =",R6,R7

        SUB     R5,R7,R6                ; R5 = hdr1/4_leafname
        LDRB    R0,[R6,#hdr_masterflag]
        TEQ     R0,#msf_master          ; is this a master font?
        BNE     slavedir

; master font: 1-bpp => Outlines, 4-bpp => master bitmaps

        TEQ     R5,#hdr1_leafname
        BNE     %FT02

        LDR     R7,OutlinesFName        ; Outlines<n>
        BL      testfile
        B       gotleafname

; check for x90y45 containing 'f9999x9999' - if so, use that file instead

02      ADRL    R7,pixelsfname          ; x90y45
        BL      constructname           ; R1 -> full filename
        MOV     R0,#OSFile_ReadNoPath
        SWI     XOS_File
        TEQ     R0,#object_file
        BNE     gotleafname             ; errors also come out here!
        CMP     R4,#255
        BLT     %FT03

        MOV     R4,#1                   ; 'best' value must be non-zero
        STR     R4,xscale               ; avoid finding exact size
        BL      trybest_x90y45
        B       gotleafname

03      MOV     R0,#OSFile_LoadNoPath
        ADR     R2,fontfilename         ; temporary workspace
        MOV     R3,#0                   ; load at given
        STRB    R3,[R2,R4]              ; ensure file is terminated
        SWI     XOS_File

        Debuga  cc," - x90y45"
        ADRVC   R7,fontfilename
        BLVC    testfile                ; just check that it exists

; R7 -> leafname, [sp,#6*4] -> entry in font header block to put it
; Z unset => data cannot be obtained (enter null in leafname)

gotleafname
        MOVVS   R3,#leaf_scanfontdir    ; other errors (try to recover later)
        BVS     putleafname
        MOVNE   R3,#leaf_none           ; file not found
        LDMEQIA R7,{R3-R5}

; R3-R5 = leafname to put into [R7..]

putleafname
        ADD     R14,sp,#5*4
        LDMIA   R14,{R6,R7}             ; R6 -> font header, R7 -> leafname buffer

        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_master
        LDRNE   R14,transformptr        ; ignore transformptr if this is a master font!
        TEQNE   R14,#0
        STMEQIA R7,{R3-R5}              ; simple if no transformptr - just stash the leafname
        BEQ     %FT25

        Debug   th,"ScanFontDir: transform, leafname =",R14,R3

        STRB    R3,[R14,#trn_leafname]

;       SUB     R5,R7,R6
;       TEQ     R5,#hdr4_leafname
;       STREQB  R3,[R14,#trn4_leafname]
;       STRNEB  R3,[R14,#trn1_leafname]

      [ debugth
        B       %FT26
      ]
25
        DebugLeafname th,"ScanFontDir:",R6,R7   ; R6 -> font header, R7 -> leafname
26
        TEQ     R3,#leaf_none           ; return "Font data for '<fontname>' not found"
        BLEQ    err_fontdatanotfound    ; if there already was an error, R3 = leaf_scanfontdir
27
        DebugE  err,"Error from ScanFontDir:"
        STRVS   R0,[sp]
        EXIT                            ; Z unset => no data

;...........................................................................

; slave font: look for f/b9999x9999, then try scaling from master font

slavedir

        TEQ     R0,#msf_ramscaled
        BEQ     frommaster

        LDR     R14,[R6,#hdr_FontMatrix]  ; can't scale from bitmaps if matrices involved
        TEQ     R14,#0
        LDREQ   R14,transformptr        ; FIXED by NRaine on 31 Aug 98 (was NE here)
        TEQEQ   R14,#0                  ; FIXED by NRaine on 31 Aug 98 (was NE here)
        BNE     frommaster

; construct f/b9999x9999, where 9999 = xscale/72, yscale/72

        Debuga  th,"slavedir: "
        BL      getxyscale              ; [x/yscale] read from header

        TEQ     R5,#hdr1_leafname
        MOVEQ   R0,#"b"                 ; make "b9999x9999"
        MOVNE   R0,#"f"                 ; make "f9999x9999"
        ADR     R1,leafnamebuffer
        BL      convertfilename         ; R7 -> leafnamebuffer
        BVS     %FT01                   ; don't try it if too long

        BL      testfile                ; if filename fits, try it
        BVS     gotleafname
        BEQ     gotleafname

; if 4-bpp, see if we can find an exact match in x90y45

01      CMP     R5,#hdr4_leafname       ; CLRV
        BNE     frommaster

        LDR     R7,OutlinesFName        ; if outlines present,
        BL      testfile                ; don't use x90y45 if subpixel scaling
        TOGPSR  Z_bit, R14              ; Z unset => outlines present
        BLNE    getsubpixelflags_r3     ; Z unset => subpixel scaling required

        MOVEQ   R4,#exactmatch          ; must be an exact match
        BLEQ    trybest_x90y45
        BEQ     gotleafname

; derive slave font from master: Outlines or master bitmaps

frommaster

        Debug   cc,"frommaster: R6 =",R6

        LDRB    R0,[R6,#hdr_masterfont]
        BL      getfontheaderptr                ; R7 -> master font header
        BVS     gotleafname

        PushP   "frommaster: slave font header",R6
        MOV     R6,R7                           ; R6 -> master font header

        ADD     R7,R6,#hdr1_leafname
        BL      GetPixelsHeader_checknasty      ; ignores error if data not found
        ADDVC   R7,R6,#hdr4_leafname            ; but objects to nastier errors
        BLVC    GetPixelsHeader_checknasty

        MOV     R7,R6                           ; R7 -> master font
        PullP   "frommaster: slave font header",R6
        DebugE  cc,"Error in frommaster:"
        BVS     gotleafname                     ; nasty errors must escape!

; ensure that the appropriate render matrix is set up, before looking at thresholds

        ASSERT  leaf_none < leaf_scanfontdir

        LDRB    R14,[R7,#hdr1_leafname]         ; if no outlines, don't bother to recompute render matrix
        CMP     R14,#leaf_scanfontdir
        BLE     %FT35

        LDR     R14,transformptr
        TEQ     R14,#0
        ADDNE   R14,R14,#trn_rendermatrix       ; transform rendermatrix must be set up (in GetTransform)
        ADDEQ   R14,R6,#hdr_rendermatrix
        STR     R14,rendermatrix

        LDR     R14,[R14,#mat_marker]           ; recompute this matrix if it is marked invalid
        TEQ     R14,#MAT_MARKER
        BLEQ    getnewrendermatrix              ; looks at [transformptr]
        BVS     gotleafname

        Debuga  th,"frommaster: "
35      BL      getxyscale                      ; values may depend on getrendermatrix

        BL      setskelthresh                   ; sets up bits => draw skeleton?

; Comment from Chris:
;
; The way this measures the width/height is a poor approximation now that text can be
; transformed.  Consider a rotated piece of text - we're interested in the true height/width
; of the text with respect to its transformed axes, not the screen axes which this uses.
; Consequently, as you rotate text slowly near the anti-alias threshold, anti-aliasing turns
; on and off unpredictably.  See "WishList" for possible fix.

        LDR     R2,yscale                       ; R2 = font height (used for threshold decisions)
        LDR     R14,xscale
        CMP     R14,R2,LSL #1                   ; if width/2 > height, pretend height = width/2
        MOVGT   R2,R14,ASR #1

        LDR     R14,[R6,#hdr_FontMatrix]        ; always go from outlines if transformed
        TEQ     R14,#0
        LDRNE   R14,transformptr
        TEQNE   R14,#0
        BNE     %FT40

; Use master bitmaps if: 4-bpp output and height <= threshold1
;                    or: no outline file
; note that x/yscale are not set up if no outlines, but they don't matter in this case

30      TEQ     R5,#hdr1_leafname               ; if 1-bpp,
        LDRNEB  R14,[R7,#hdr4_leafname]         ; or there are no 4-bpp bitmaps
        TEQNE   R14,#leaf_none
        BEQ     %FT40                           ; try using outlines

        BL      getsubpixelflags_r3             ; Z unset => subpixel scaling required
        LDRNEB  R14,[R7,#hdr1_leafname]         ; try to use outlines
        TEQNE   R14,#leaf_none                  ; (first check that they exist)
        BNE     %FT40

        LDR     R0,[R6,#hdr_threshold1]         ; point height * res * 72 * 16
        Debug   th,"4-bpp: yscale, threshold1 =",R2,R0

        CMP     R2,R0
        LDRGTB  R14,[R7,#hdr1_leafname]
        CMPGT   R14,#leaf_none                  ; use 4-bpp anyway if no outlines!
        MOVLE   R3,#leaf_4bpp                   ; use 4-bpp if small enough
        BLE     putleafname

; Use Outlines:
;     if yscale > threshold2 or threshold3, don't use 4-bpp
;     if yscale > threshold3, don't convert outlines to bitmaps in the cache
;     if outlines marked 'mono only', don't use 4-bpp

40      LDRB    R3,[R7,#hdr1_leafname]          ; does master font have outlines?
        TEQ     R3,#leaf_none
        BEQ     putleafname                     ; no - we can't generate any bitmaps

        TEQ     R5,#hdr1_leafname
        MOVEQ   R3,#leaf_outlines_00            ; no subpixel scaling if 1-bpp
        BEQ     %FT41

        LDRB    R14,[R7,#hdr1_flags]
        TST     R14,#pp_monochrome              ; flag set in outlines header => don't use anti-aliasing
        MOVNE   R3,#leaf_none                   ; (used for things like System font)
        BNE     putleafname

        [ debugth
        ADD     R3,R6,#hdr_threshold2
        LDMIA   R3,{R3,R14}                     ; get threshold2, threshold3
        Debug   th,"4-bpp: yscale, threshold2,threshold3 =",R2,R3,R14
        ]

        LDR     R14,[R6,#hdr_threshold2]        ; use 1-bpp instead?
        CMP     R2,R14                          ; (ie. set no 4-bpp data)
        LDRLE   R14,[R6,#hdr_threshold3]
        CMPLE   R2,R14
        MOVGT   R3,#leaf_outlines_direct        ; was leaf_none - why???
        BGT     putleafname
        BL      getsubpixelflags_r3             ; R3 = leaf_outlines_xx

41      LDR     R14,[R6,#hdr_threshold3]        ; cache outlines?

        CMP     R2,R14
        MOVGT   R3,#leaf_outlines_direct
        B       putleafname                     ; R3 = leaf_outlines_<something>

;.............................................................................

; In    R6 -> font header
;       R7 -> pixels leafname (in font header)
; Out   Error => something really nasty has happened
;       If font data not found, the leafname is just set to leaf_none

GetPixelsHeader_checknasty Entry "R1"

        LDRB    R14,[R7]
        CMP     R14,#leaf_scanfontdir           ; CLRV
        BLEQ    GetPixelsHeader_R7
        EXIT    VC

        LDR     R14,=ErrorNumber_FontNotFound
        LDR     R1,[R0]
        TEQ     R1,R14
        CLRV    EQ

        DebugE  err,"Error from GetPixelsHeader_checknasty:"

        EXIT
        LTORG

;.............................................................................

; In    R6 -> slave font header
;       R7 -> master font header
;       [R7,#hdr_skelthresh] = pixel size below which skeleton lines appear
;       [x/yscale] = size of this font (pixel size * 72 * 16)
; Out   [R6,#hdr_skelthresh] bits sk_1/4onoff set up appropriately

setskelthresh Entry "R1-R4"

        MOV     R14,#72*16
        LDRB    R2,[R7,#hdr_skelthresh]
        MUL     R2,R14,R2

        MOV     R4,#0                   ; output flags

        RSBS    R14,R2,#1               ; threshold=0 => always draw skeletons

        MOVLE   R3,#2                   ; multiply by 4 for 4-bpp version
        BLLE    setskel2
        ORRLE   R4,R4,#sk4_dontbother

        MOVLE   R3,#0                   ; try 1-bpp size
        BLLE    setskel2
        ORRLE   R4,R4,#sk1_dontbother

        STRB    R4,[R6,#hdr_skelthresh]

        EXIT

;.............................................................................

; In    R2 = threshold value (pixel size * 16 * 72)
; Out   GT => draw skeleton lines, else don't bother
;       R1 corrupted

setskel2
        LDR     R1,xscale
        CMP     R2,R1,LSL R3            ; is the threshold greater?
        LDRLE   R1,yscale
        CMPLE   R2,R1,LSL R3            ; GT => draw skeleton lines
        MOV     PC,LR                   ; LE => don't bother

;.............................................................................

; In    R6 -> font header
;       [xscale], [yscale] = size of font
;       [R6,#hdr_threshold4], [R6,#hdr_threshold5] = thresholds
; Out   R3 = leaf_outlines_xx, where
;            bit 0 set => perform horizontal subpixel scaling
;            bit 1 set => perform vertical subpixel scaling
;       Z unset => subpixel scaling required

getsubpixelflags_r3 Entry "R2"

        MOV     R3,#leaf_outlines_00

        LDR     R2,xscale               ; is it small enough widthways?
        LDR     R14,[R6,#hdr_threshold4]
        CMP     R2,R14
        ORRLE   R3,R3,#pp_4xposns

        LDR     R2,yscale
        LDR     R14,[R6,#hdr_threshold5]
        CMP     R2,R14                  ; is it small enough heightways?
        ORRLE   R3,R3,#pp_4yposns

        ASSERT  pp_4xposns = 1 :LAND: pp_4yposns = 2 :LAND: trnf_swapxyposns = 1

        LDRB    R14,swapxyposnsflag     ; swap axes if this flag says we should
        EOR     R2,R3,R3,LSR #1
        AND     R2,R2,R14
        TST     R2,#trnf_swapxyposns    ; NE => x/y flags are different and we should swap them
        EORNE   R3,R3,#pp_4xposns :OR: pp_4yposns

        TST     R3,#pp_4xposns :OR: pp_4yposns

        Debug   th,"Subpixel scaling flags =",R3

        EXIT

;.............................................................................

; In    R6 -> font header, with pathname set up
;       R4 = minimum value of 'best' size which is acceptable
; Out   Z set => good enough size found
;       R1 -> full filename
;       R0,R7 corrupted
;       index entry of best match read into font header

trybest_x90y45 Entry "R2-R5"

        ADR     R7,pixelsfname          ; try for 'x90y45'
        BL      constructname           ; R1 -> full filename
        MOV     R0,#OSFile_ReadNoPath
        SWI     XOS_File
        TEQ     R0,#object_file         ; does file exist?
        EXIT    NE
        CMP     R4,#256                 ; ignore short file (no fonts in it)
        EXIT    LT                      ; Z unset => no suitable font found

        LDMIA   R7,{R2-R4}              ; open the pixels file
        ADD     R14,R6,#hdr4_leafname
        STMIA   R14,{R2-R4}
        BL      openpixels4             ; R1 = file handle
        BLVC    findbest                ; R2 = 'value' of best match
        BL      closepixels             ; preserves error state
        EXIT    VS

        Debug   th,"Best value returned =",R2

        LDR     R4,[sp,#2*4]            ; was that good enough?
        CMP     R2,R4
        MOVGE   R2,R4
        TEQ     R2,R4
        ADREQ   R7,pixelsfname
        BLEQ    constructname           ; set up R1 again! (preserves flags)
        EXIT    EQ                      ; Z set => it worked

        LDRB    R1,[R6,#hdr4_pixelshandle]
        TEQ     R1,#0
        MOVNE   R14,#0
        STRNEB  R14,[R6,#hdr4_pixelshandle]
        BLNE    closefile               ; close the file!
        TEQ     PC,#0                   ; Z unset => it didn't work
        EXIT

pixelsfname     DCB     "x90y45",0
                ALIGN

; ............................................................................

; In    R6 -> font block
;       R7 -> leafname
; Out   R1 -> full name (in pathname block of master font)
;
; b9999x9999 and f9999x9999 files are taken from <fontdir>.<encoding>.<leafname>
; all other files are taken from <fontdir>.<leafname>

constructname EntryS "R0,R2-R7"

01      LDRB    R0,[R6,#hdr_masterfont] ; always use master pathname (if any)
        TEQ     R0,#0
        BEQ     %FT02
        BL      getfontheaderptr
        MOVVC   R6,R7                   ; R6 -> master font header
        BVC     %BT01

        STR     R0,[sp, #Proc_RegOffset]
        EXITVS                          ; error exit, preserving all other flags

02      LDR     R7,[sp,#Proc_RegOffset+6*4] ; R7 -> leafname
        LDRB    R1,[R7]                 ; R1 = I, f, b, O, x, 0 (for Font_ReadFontPrefix)

        TEQ     R1,#"O"                 ; if Outlines,
        TOGPSR  Z_bit, R14
        LDRNE   R1,[R6,#hdr_PathName2]  ; prefer to use hdr_PathName2
        TEQNE   R1,#0
        LDREQ   R1,[R6,#hdr_PathName]   ; use hdr_PathName for IntMetrics, f9999x9999, b9999x9999, x90y45, null
03
      [ debugbrk
        TEQ     R1,#0
        BreakPt "constructname: no pathname for this font",EQ
      ]

        LDRB    R2,[R1,#pth_leafptr]
        ADD     R1,R1,#pth_name         ; R1 -> pathname
        ADD     R2,R1,R2                ; R2 -> space for leafname
        LDMIA   R7,{R3-R5}
        STMIA   R2,{R3-R5}              ; stuff leafname in

        DebugS  th,"Constructname returns ",R1

        EXITS                           ; must preserve flags

; ............................................................................

; In    R6 -> font header
;       R7 -> leafname (word-aligned)
; Out   R1 -> full filename of file in Outlines subdirectory (pathname2)

constructname2 Entry "R0,R2-R7"

        LDMIA   R7,{R3-R5}              ; R3-R5 = characters of leafname

01      LDRB    R0,[R6,#hdr_masterfont] ; always use master pathname (if any)
        TEQ     R0,#0
        BEQ     %FT02
        BL      getfontheaderptr
        MOVVC   R6,R7                   ; R6 -> master font header
        BVC     %BT01
        EXIT

02      LDR     R1,[R6,#hdr_PathName2]  ; use pathname2 if present, otherwise pathname
        TEQ     R1,#0
        LDREQ   R1,[R6,#hdr_PathName]

      [ debugbrk
        TEQ     R1,#0
        BreakPt "Null pathname2",EQ
      ]

        LDRB    R2,[R1,#pth_leafptr]
        ADD     R1,R1,#pth_name         ; R1 -> pathname, R2 -> leafname buffer
        ADD     R2,R1,R2
        STMIA   R2,{R3-R5}              ; store encoding identifier as leafname

        CLRV
        EXIT

; ............................................................................

; In    R6,R7 set as for ScanFontDir
; Out   R1 -> full filename
;       Z set => file exists, otherwise it doesn't

testfile Entry "R0,R2-R5"

        DebugS  cc," - testing leaf ",R7
        BL      constructname
        DebugS  cc," - testing file ",R1

        MOV     R0,#OSFile_ReadNoPath
        SWI     XOS_File                ; shouldn't set V
        TEQ     R0,#object_file         ; Z unset if error returned, too

        STRVS   R0,[sp]
        EXIT

; ............................................................................

; In    R0 = initial character
;       R1 -> buffer
;       [xscale], [yscale] set up
; Out   R7 -> filename contructed in [R1...]
; Error "Buffer overflow" if filename longer than 10 characters

convertfilename Entry "R1-R4"

        MOV     R7,R1
        STRB    R0,[R1],#1
        MOV     R2,#8+1                 ; 8 chars for numbers, 1 for terminator
        MOV     R4,#72

        LDR     R3,xscale
   ;;   MOV     R3,R3,LSR #4            ; DON'T divide down to pixels
        BL      convertcardinal_R3R4    ; preserves R0 unless error
        MOVVC   R14,#"x"
        STRVCB  R14,[R1],#1
        LDRVC   R3,yscale
   ;;   MOVVC   R3,R3,LSR #4            ; DON'T divide down to pixels
        BLVC    convertcardinal_R3R4    ; error if filename too long

        EXIT    VC

        PullEnv

        ADR     R0,ErrorBlock_FontBadFileName
        B       MyGenerateError
        MakeErrorBlock FontBadFileName

; ............................................................................

; In    R1 -> output buffer
;       R2 = space remaining
;       R3 = dividend
;       R4 = divisor
; Out   R1 -> terminator (R3/R4 expanded into buffer)
;       R2 = space remaining
;       R3 corrupted, R4 preserved, V set if buffer overflow

convertcardinal_R3R4 Entry "R0"

        DivRem  R0,R3,R4,R14,norem      ; R4 preserved
        SWI     XOS_ConvertCardinal4    ; R1,R2 updated

        STRVS   R0,[sp]
        EXIT

;;----------------------------------------------------------------------------
;; Read IntMetrics header
;; Entry:  R6 --> font header
;;         [R6,#hdr_PathName] --> block containing full path name
;; Exit:   Metrics file opened, file offsets etc. read into font block
;;         [R6,#hdr_x/ysize] = nominal size of metrics on disc (usually 16)
;; NB:     if {newlistfonts}, font name is NOT read from the metrics file
;;----------------------------------------------------------------------------

GetMetricsHeader PEntry Cac_MetDisc, "R1-R5"

        BL      openmetrics
        BVS     %FT99

        Debug   cc,"Metricshandle: fonthdr,handle =",R6,R1

        MOV     R0,#OSArgs_ReadEXT      ; find extent
        SWI     XOS_Args                ; exit: R2 = extent of file

        MOVVC   R14,#fmet_nchars        ; recache from nchars onwards
        STRVC   R14,[R6,#hdr_MetOffset]
        SUBVC   R2,R2,R14
        STRVC   R2,[R6,#hdr_MetSize]

        MOVVC   R0,#OSGBPB_ReadFromGiven   ; don't read font name (done in MakePathName)
        ADDVC   R2,R6,#hdr_xsize
        MOVVC   R3,#fmet_endhdr - fmet_xsize
        MOVVC   R4,#fmet_xsize
        BLVC    xos_gbpb                ; checks R3=0, preserves R2

        ASSERT  fmet_endhdr = fmet_nchars+4
        ASSERT  fmet_flags = fmet_nchars + 2
        LDRVC   R2,[R6,#hdr_nchars]
        MOVVC   R14,R2,LSR #16          ; R14 bits 0..7 = metrics flags
        STRVCB  R14,[R6,#hdr_metflags]
        ANDVC   R14,R2,#&FF000000
        ANDVC   R2,R2,#&FF
        ORRVC   R2,R2,R14,LSR #16
        STRVC   R2,[R6,#hdr_nchars]     ; R2 = nlo + 256*nhi

      [ debugme
        LDR     R3,[R6,#hdr_xsize]
        LDR     R4,[R6,#hdr_ysize]
        Debug   me,"GetMetricsHeader: font header,xsize,ysize,nchars",R6,R3,R4,R2
      ]

        DebugE  err,"GetMetricsHeader (before) "

        BL      closemetrics            ; preserves error state

        DebugE  err,"GetMetricsHeader (after) "
99
        PExit

;;----------------------------------------------------------------------------
;; GetPixels1/4Header (called in Font_FindFont and setpixelsptr)
;; Entry:  R6 --> font header info
;;         [R6,#hdr_x/yscale] = point size * 16 * x/y resolution
;;         [R6,#hdr_PathName] --> block containing pathname
;;         [transformptr] -> transform block (if present)
;; Exit :  font header read in (may come from x90y45 or f9999x9999)
;;         file offsets of pixel data calculated
;;         font bounding box calculated, depending on file type
;;         rendermatrix -> matrix used to compute font bbox, if from outlines
;;
;;  !!!!  THE CACHE IS NOT ALLOWED TO MOVE INSIDE THIS ROUTINE  !!!!
;;
;;         (this is due to 'openpixels' not relocating R6,R7)
;;
;; ScanFontDir looks in the font directory to decide which file to use
;; [R6,#hdr1/4_leafname] contains the one decided on
;;      0 => no data of this type available
;;      1 => not yet decided - call ScanFontDir to find out what to do
;;      2 => use master font: scale from 4-bpp bitmaps
;;      3 => use master font: paint outlines directly onto screen
;;      4..7 => use master font: construct bitmaps from outlines
;;              (bits 0..1 = subpixel scaling flags)
;;
;;----------------------------------------------------------------------------

                  ^     0
leaf_none         #     1       ; no data available (try other type)
leaf_scanfontdir  #     1       ; not yet decided
leaf_4bpp         #     1       ; scale from 4-bpp bitmaps to 4-bpp bitmaps
leaf_outlines_direct #  1       ; draw directly on the screen (1-bpp)
leaf_outlines_00  #     1       ; convert to bitmaps in the cache
leaf_outlines_01  #     1       ; ditto, with horizontal subpixel positioning
leaf_outlines_10  #     1       ; ditto, with vertical subpixel positioning
leaf_outlines_11  #     1       ; ditto, with h- and v- subpixel positioning
leaf_fromdisc     #     1       ; anything bigger than this

        ASSERT  (leaf_outlines_00 :AND: 3) = 0
        ASSERT  pp_4xposns = 1
        ASSERT  pp_4yposns = 2


GetPixelsHeader_R7 Entry "R1-R5,R7-R9"

        SUB     R14,R7,R6
        TEQ     R14,#hdr1_leafname
        MOVEQ   R2,#hdr1_pixelshandle
        MOVNE   R2,#hdr4_pixelshandle
        B       %FT01

GetPixels1Header ALTENTRY

        MOV     R2,#hdr1_pixelshandle
        ADD     R7,R6,#hdr1_leafname
        B       %FT01

GetPixels4Header ALTENTRY

        MOV     R2,#hdr4_pixelshandle
        ADD     R7,R6,#hdr4_leafname

01      LDRB    R14,[R6,#hdr_masterflag]  ; ignore transform block if this is a master font
        TEQ     R14,#msf_master
        LDRNE   R8,transformptr           ; else if [transformptr] set, use 'leafname' in transform block
        TEQNE   R8,#0
        BEQ     %FT02

; transformed getpixelsheader - input data MUST be outlines

        Debug   trn,"GetPixelsHeader: transformptr =",R8

;       TEQ     R5,#hdr1_leafname
;       LDREQB  R14,[R8,#trn1_leafname]
;       LDRNEB  R14,[R8,#trn4_leafname]

        LDRB    R14,[R8,#trn_leafname]
        CMP     R14,#leaf_scanfontdir
        EXIT    GT                      ; do nothing if already scanned
        BLLT    err_fontdatanotfound    ; return error if no data
        EXIT    VS

; this should recurse and get the information from the master outlines

        BL      setleafnames_R6         ; must set up Outlines<n>
        DebugE  trn,"setleafnames_R6 error:"
        BLVC    ScanFontDir             ; this checks for transformptr <> 0
        DebugE  trn,"ScanFontDir error:"
        BVC     masteroutlinebbox       ; VC => it must have found the outlines
        EXIT                            ; VS => just exit with error

; normal getpixelsheader - call openpixels, which calls ScanFontDir if not done already

02      LDRB    R14,[R7]                ; otherwise use leafname supplied
        CMP     R14,#leaf_scanfontdir
        EXIT    GT                      ; exit immediately if already done

      [ debugcc
        LDR     R14,[R6,#hdr_xsize]
        Debug   cc,"GetPixelsHeader: R6,R7, xsize =",R6,R7,R14
      ]

        BL      setleafnames_R6
        BLVC    ScanFontDir             ; #### moved from inside openpixels ####
        BLVC    openpixels_R2R7         ; error if no font data to find, ignores non-filename types
        EXIT    VS

      [ debugcc
        LDR     R14,[R6,#hdr_xsize]
        Debug   cc,"GetPixelsHeader: R6, xsize =",R6,R14
      ]

; first char of leafname => file, outlines, bitmap

        MOV     R14,#0                  ; flags are different for outline and bitmap files
        STRB    R14,[R7,#hdr1_flags-hdr1_leafname]

        LDRB    R14,[R7]

        Debug   cc,"GetPixelsHeader: fonthdr,R7,[R7],handle =",R6,R7,R14,R1

        TEQ     R14,#"x"                ; old format file?
        BEQ     getoldheader

        CMP     R14,#leaf_fromdisc      ; new format file?
        BGE     getnewheader

        ASSERT  leaf_outlines_00 > leaf_outlines_direct
        CMP     R14,#leaf_outlines_direct
        BGE     masteroutlinebbox       ; scale bbox from master font

      [ debugbrk
        TEQ     R14,#leaf_4bpp
        BreakPt "Bad leafname",NE       ; drop through otherwise
      ]

;......................................................................................

; Scaling from 4-bpp master font data
;   See if we should magnify the font - only applies to 4-bpp bitmap input
;     [R6,#hdr_x/ymag], [R6,#hdr_x/yscale] updated if so

xmaglimit       *       1
ymaglimit       *       1

masterbitmapbbox
        Push    "R7"

        LDRB    R0,[R6,#hdr_masterfont]
        BL      getfontheaderptr        ; R7 -> master font header
        BVS     %FT77

        Debuga  th,"masterbitmapbbox: "
        BL      getxyscale              ; [x/yscale] = hdr x/yscale * x/ymag

        LDR     R0,xscale               ; also used in computebox
        LDR     R1,[R7,#hdr_xscale]
        STR     R1,xfactor              ; for computebox
        BL      divide
        CMP     R2,#xmaglimit           ; use 'times 1' scaling if < xmaglimit
        MOVLT   R2,#1
        STR     R2,[R6,#hdr_xmag]
        MOV     R1,R2
        LDR     R0,xscale
        BL      divide
        STR     R2,[R6,#hdr_xscale]

        LDR     R0,yscale               ; also used in computebox
        LDR     R1,[R7,#hdr_yscale]
        STR     R1,yfactor              ; for computebox
        BL      divide
        CMP     R2,#ymaglimit           ; use 'times 1' scaling if < ymaglimit
        MOVLT   R2,#1
        STR     R2,[R6,#hdr_ymag]
        MOV     R1,R2
        LDR     R0,yscale
        BL      divide
        STR     R2,[R6,#hdr_yscale]

      [ debugth
        LDR     R1,[R6,#hdr_xmag]
        LDR     R2,[R6,#hdr_ymag]
        Debug   th,"x/y mag =",R1,R2
      ]

; x/yscale are multiplied by x/ymag, so this is a 'proper' bbox

        ADD     R14,R7,#hdr4_boxx0      ; this is unscaled
        LDMIA   R14,{R1-R4}
        ADD     R14,R6,#hdr4_boxx0      ; copy bbox into slave font header
        STMIA   R14,{R1-R4}
        BL      computebox              ; scale according to x/y scale/factor
77
        Pull    "R7"
        B       exitpixhdr_close

; ............................................................................

; old-style file - font index was searched in ScanFontDir

getoldheader
        ProfIn  Cac_PixDisc
        MOV     R0,#OSGBPB_ReadFromGiven
        ADD     R2,R6,#hdr_xscale       ; old font data read in
        MOV     R3,#fpix_index          ; x/yscale, x/yres, font bbox
        LDR     R4,[R6,#hdr_PixOffset]
        SUB     R4,R4,#fpix_index
        BL      xos_gbpb                ; checks R3=0, preserves R2
        ProfOut
        BVS     exitpixhdr_close

        LDR     R4,[R6,#hdr_filebbox]   ; convert from bytes to words
        MOV     R1,R4,LSL #24           ; x0 << 24
        MOV     R2,R4,LSL #16           ; y0 << 24
        MOV     R3,R4,LSL #8            ; x1 << 24
        MOV     R1,R1,ASR #24           ; x0 (sign-extended)
        MOV     R2,R2,ASR #24           ; y0 (sign-extended)
        MOV     R3,R3,ASR #24           ; x1 (sign-extended)
        MOV     R4,R4,ASR #24           ; y1 (sign-extended)
        ADD     R14,R6,#hdr4_boxx0      ; must be 4-bpp data
        STMIA   R14,{R1-R4}             ; scaled in slave font by computebox

        MOV     R14,#8
        STR     R14,[R6,#hdr4_nchunks]  ; need this to allocate pixo blocks

; master bbox is unscaled (scaled later in slave font(s))

exitpixhdr_close

        DebugE  err,"GetPixelsHeader (before):"
        MOVVS   R14,#leaf_scanfontdir   ; ensure this mistake is not terminal
        STRVSB  R14,[R7]                ; NB: R6,R7 must be up-to-date
        BLVS    tidyfiles               ; ensure ScanFontDir re-consulted
        BL      closepixels             ; preserves error state
        DebugE  err,"GetPixelsHeader (after):"

        EXIT

;.............................................................................

; f9999x9999    )
; b9999x9999    )  all share the same header format
; outlines      )

getnewheader
        DebugS  th,"getnewheader: leafname = ",R7

        ProfIn  Cac_PixDisc
        MOV     R0,#OSGBPB_ReadFromGiven
        ASSERT  ?fontfilename >= fnew_hdrsize
        ADR     R2,fontfilename         ; use as a temporary buffer
        MOV     R3,#fnew_hdrsize
        MOV     R4,#0
        BL      xos_gbpb                ; checks R3=0, preserves R2
        ProfOut
        BVS     exitpixhdr_close

        ADR     R2,fontfilename         ; used as a temporary buffer
        LDRB    R14,[R2,#fnew_version]  ; we need version >= 4 (chf_outlines)
        TEQ     R14,#4
        TEQNE   R14,#5                  ; with skeleton threshold
        TEQNE   R14,#6                  ; with dependency mask
        TEQNE   R14,#7                  ; with pixel flags at start of chunks
        TEQNE   R14,#8                  ; with extensions for > 256 characters
        LDREQ   R14,[R2,#fnew_ident]
        LDREQ   R0,fontid
        TEQEQ   R0,R14
        ADDNE   R1,R6,#hdr_name
        BLNE    xerr_badfontfile
        BVS     exitpixhdr_close

; copy the bbox into the font header (NB: hdr = x0,y0,x1,y1, file = x,y,w,h)
; NB: there are separate bboxes for 1-bpp and 4-bpp data

        LDR     R14,fontfilename + fnew_boxx0
        MOV     R3,R14,ASR #16          ; R3 = y0 sign-extended
        MOV     R14,R14,LSL #16
        MOV     R0,R14,ASR #16          ; R0 = x0 sign-extended

        LDR     R14,fontfilename + fnew_boxx1
        ADD     R5,R3,R14,LSR #16       ; R5 = y1 = y0 + height (unsigned)
        MOV     R14,R14,LSL #16
        ADD     R4,R0,R14,LSR #16       ; R4 = x1 = x0 + width (unsigned)

        ADD     R14,R7,#hdr4_boxx0 - hdr4_leafname
        STMIA   R14,{R0,R3,R4,R5}
        Debug   bb,"File font bbox (x0,y0,x1,y1) =",R0,R3,R4,R5

; check bpp to decide on the meaning of the flag word

        ASSERT  (fnew_bpp:AND:3)=0
        ASSERT  fnew_designsize = fnew_bpp+2
        LDR     R14,[R2,#fnew_bpp]
        TST     R14,#&FF                ; 0 bpp ==> outlines
        MOV     R14,R14,LSR #16

        STREQ   R14,[R6,#hdr_designsize]            ; outline font

        STRNEB  R14,[R7,#hdr1_flags-hdr1_leafname]  ; > 0 => bitmap flags
        BLNE    getnewxyscale
        BNE     notoutlinehdr

; set pixel flags to indicate whether the dependency byte is present
; note that Outlines files don't actually have a flag byte in the header

        LDRB    R14,fontfilename + fnew_version
        CMP     R14,#6
        MOV     R14,#0                          ; default for all flags is 0
        ORRGE   R14,R14,#pp_dependencies        ; version 6 onwards
        ORRGT   R14,R14,#pp_flagsinfile         ; version 7 onwards
        STRB    R14,[R7,#hdr1_flags-hdr1_leafname]
        MOVLE   R14,#0                          ; can't use old font files directly from ROM
        STRLE   R14,[R7,#hdr1_address-hdr1_leafname]
notoutlinehdr

; the outline bbox is not scaled in the master font, only in the slave(s)

; copy chunk offset array into appropriate place

;       ADD     R0,R7,#hdr4_PixOffsets-hdr4_leafname

      [ debugbrk
        LDR     R14,[R7,#hdr4_nchunks-hdr4_leafname]
        CMP     R14,#0
        BreakPt "hdr_nchunks already set in getnewheader",NE
      ]

        ADR     R14,fontfilename + fnew_PixOffsets
        LDMIA   R14!,{R2-R5}            ; get first 4 entries

        CMP     R2,R3                   ; if first offset greater than second, this must be new-format
        CMPLS   R3,R4                   ; or second greater than third
        CMPLS   R4,R5                   ; or third greater than fourth
        BHI     extendedheader

; NOTE: Since we're not allowed to move the cache here, we can't allocate the pixo block just yet!

        MOV     R14,#fnew_PixOffsets
        STR     R14,[R7,#hdr4_PixOffStart-hdr4_leafname]
        MOV     R14,#8                   ; In: R0 = number of chunks, R6,R7->font/bpp
        STR     R14,[R7,#hdr4_nchunks-hdr4_leafname]

;       MOV     R2,#8
;       STR     R2,[R7,#hdr4_nchunks-hdr4_leafname]
        MOV     R2,#256
        STR     R2,[R7,#hdr4_nscaffolds-hdr4_leafname]

; now that we know how many scaffold index entries there are, we can read the skeleton threshold

pix_getskelthresh

        LDRB    R14,fontfilename+fnew_bpp
        TEQ     R14,#0
        BNE     exitpixhdr_close                   ; forget it if not outlines

; we mustn't load the scaffold block here, cos it might move the cache
; instead we simply store the size of the block in the font header
; the actual scaffold block is loaded in cacheoutlines

        ASSERT  (fnew_tablesize:AND:3)=0
        LDRB    R14,[R7,#hdr1_flags-hdr1_leafname]
        TST     R14,#pp_bigtable
        LDR     R14,fontfilename+fnew_tablesize
        MOVEQ   R14,R14,LSL #16
        MOVEQ   R14,R14,LSR #16                 ; remove top 16 bits
        STR     R14,[R6,#hdr_scaffoldsize]

        MOV     R14,#0                          ; skeleton threshold defaults to 0
        STRB    R14,[R6,#hdr_skelthresh]

        ProfIn  Cac_PixDisc
        LDRB    R14,fontfilename + fnew_version
        CMP     R14,#5                          ; if version 5 or later,
        BLT     %FT10
        MOV     R0,#OSGBPB_ReadFromGiven        ; read extra byte from index
        ADD     R2,R6,#hdr_skelthresh
        MOV     R3,#1
        LDRB    R14,[R7,#hdr1_flags-hdr1_leafname]
        LDR     R4,[R7,#hdr1_nscaffolds-hdr1_leafname]
        TST     R14,#pp_bigtable
        MOVEQ   R4,R4,LSL #1
        MOVNE   R4,R4,LSL #2
        ADD     R4,R4,#fnew_tablesize
        BL      xos_gbpb                ; checks R3=0, preserves R2
10
        ProfOut

      [ debugth
        LDRB    R14,[R6,#hdr_skelthresh]
        Debug   th,"Skeleton threshold =",R14
      ]
        B       exitpixhdr_close                   ; close file handle, if required

fontid  DCB     "FONT"
        ASSERT  ?fontid = 4

; Version 8 onwards: what was the chunk index is now:
;
;       R2      file offset of real chunk index
;       R3      number of chunks
;       R4      number of scaffold index entries
;       R5      scaffold flags: bit 0 set => all scaffold basechars are 16-bit
;                               bit 0 clr => basechar is 16-bit <=> top bit of offset set
;                               bit 1 set => outlines are not suitable for anti-aliasing
;                               bit 2 set => use non-zero winding rule
;                               bit 3 set => scaffold index is 32-bit

extendedheader
        Debug   cc,"Version 8 header: chunk offset, nchunks, nscaffolds, scflags",R2,R3,R4,R5

; No limit on number of chunks now!
;        SUB     R14,R7,R6
;        TEQ     R14,#hdr4_leafname
;        MOVEQ   R14,#8                  ; max 8 chunks for 4-bpp stuff
;        MOVNE   R14,#MaxChunks          ; max 24 chunks for Outlines
;
;        CMP     R3,R14
;        BGT     err_toomanychunks

        STR     R2,[R7,#hdr4_PixOffStart-hdr4_leafname]
        STR     R3,[R7,#hdr4_nchunks-hdr4_leafname]
        STR     R4,[R7,#hdr4_nscaffolds-hdr4_leafname]

        LDRB    R14,[R7,#hdr4_flags-hdr4_leafname]
        AND     R5,R5,#pp_16bitscaff :OR: pp_monochrome :OR: pp_fillnonzero :OR: pp_bigtable
        ORR     R14,R14,R5
        STRB    R14,[R7,#hdr4_flags-hdr4_leafname]
        B       pix_getskelthresh

;err_toomanychunks
;        ADR     R0,ErrorBlock_FontTooManyChunks
;        ADD     R1,R6,#hdr_name
;        MOV     R9,#0
;        BL      XError_with_fontname
;        B       exitpixhdr_close
;        MakeErrorBlock FontTooManyChunks

;.............................................................................

; Read x/yscale from new-format bitmap font file
; In    R2 -> font header data (from file)
;       R6 -> font header block
; Out   [R6,#x/yscale] computed from [R2,#fnew_x/ysize/res]

getnewxyscale EntryS "R1,R3"

        ASSERT  (fnew_xsize:AND:3) = 2
        ASSERT  fnew_xsize+2 = fnew_xres
        ASSERT  fnew_xres+2 = fnew_ysize
        ASSERT  fnew_ysize+2 = fnew_yres

        LDR     R14,[R2,#fnew_xsize-2]
        MOV     R14,R14,LSR #16                 ; R14 = xsize
        LDR     R1,[R2,#fnew_xres]
        MOV     R3,R1,LSR #16                   ; R3 = ysize
        BIC     R1,R1,R3,LSL #16                ; R1 = xres
        MUL     R1,R14,R1
        STR     R1,[R6,#hdr_xscale]

        LDR     R14,[R2,#fnew_yres]
        MOV     R14,R14,LSL #16
        MOV     R14,R14,LSR #16                 ; R14 = yres
        MUL     R14,R3,R14
        STR     R14,[R6,#hdr_yscale]

        Debug   th,"new-style x/yfactor =",R1,R14

        EXITS                                   ; must preserve flags

;.............................................................................

; Scaling from outline master font data
;   Scale bbox in master font header into slave font header / transform block

masteroutlinebbox

        Debug   trn,"masteroutlinebbox: R6,R7,transformptr =",R6,R7,#transformptr
      [ debugbrk
        LDR     R14,transformptr
        TEQ     R14,#0
        LDREQB  R14,[R7]
        LDRNEB  R14,[R14,#trn_leafname]
;       BEQ     %FT00

;       SUB     R14,R7,R6
;       TEQ     R14,#hdr1_leafname
;       TEQNE   R14,#hdr4_leafname
;       BreakPt "Bad R7",NE

;       TEQ     R14,#hdr1_leafname
;       LDR     R14,transformptr
;       LDREQB  R14,[R14,#trn1_leafname]
;       LDRNEB  R14,[R14,#trn4_leafname]
;00
        ASSERT  leaf_outlines_direct < leaf_outlines_00
        CMP     R14,#leaf_outlines_direct
        RSBGES  R14,R14,#leaf_outlines_11
        BreakPt "Should be loading outlines here",LT
      ]

        Debug   trn,"masteroutlinebbox: R6,R7,transformptr =",R6,R7,#transformptr

        Push    "R7"                    ; R7 -> leafname

        LDRB    R0,[R6,#hdr_masterfont] ; this must exist (ScanFontDir)
        BL      getfontheaderptr        ; R7 -> master font header
        BVS     %FT77

; render matrix taken from font header or transform block

      [ debugbb
        LDR     R14,rendermatrix
        DebugM  bb,"Scale font bbox: rendermatrix =",R14
      ]

; calculate font bbox - (in 2.79, result coords were not << 9)

        ADD     R14,R7,#hdr1_boxx0
        LDMIA   R14,{R1-R4}

        BL      scaleoutlinebbox        ; R1-R4 = bbox (pixels) - uses [rendermatrix]

        LDR     R14,transformptr
        TEQ     R14,#0
        BNE     %FT80

        LDR     R14,[sp]                ; R14 -> leafname
        ADD     R14,R14,#hdr4_boxx0 - hdr4_leafname
        STMIA   R14,{R1-R4}

        Debug   bb,"Scaled outline bbox (pixels) =",R1,R2,R3,R4

; finished setting-up for outline->bitmap conversion

77
        Pull    "R7"
        B       exitpixhdr_close

; set up bbox in transform block

80  ;   LDR     R7,[sp]                 ; R7 -> leafname
;       SUB     R7,R7,R6                ; R7 = hdr1_leafname / hdr4_leafname
;       TEQ     R7,#hdr1_leafname
;       ADDEQ   R14,R14,#trn1_boxx0
;       ADDNE   R14,R14,#trn4_boxx0
        ADD     R14,R14,#trn_boxx0
        STMIA   R14,{R1-R4}

        Debug   bb,"Transform bbox, from outlines (pixels) =",R14,R1,R2,R3,R4

        B       %BT77

;.............................................................................

; New arithmetic routines are contained in a separate source file

        GET     Font_Arith.s

;.............................................................................

; In    R6 -> font header
;       [transformptr] -> transform block, or 0 => unit matrix
; Out   [xscale] = [R6,#hdr_xscale] * [R6,#hdr_xmag]
;       [yscale] = [R6,#hdr_yscale] * [R6,#hdr_ymag]
;
; NB: this operation is only meaningful on slave fonts

getxyscale EntryS "R1,R2"

      [ debugbrk
        LDRB    R14,[R6,#hdr_masterflag]
        TEQ     R14,#msf_normal
        TEQNE   R14,#msf_ramscaled
        BreakPt "getxyscale called on unsuitable font", NE
      ]

        Debug   trn,"getxyscale: transformptr =",#transformptr

        LDR     R14,transformptr
        TEQ     R14,#0
        LDRNE   R1,[R14,#trn_xscale]
        LDRNE   R2,[R14,#trn_yscale]
        LDRNEB  R14,[R14,#trn_flags]
        BNE     %FT01

        LDR     R14,[R6,#hdr_xscale]
        LDR     R1,[R6,#hdr_xmag]
        MUL     R1,R14,R1

        LDR     R14,[R6,#hdr_yscale]
        LDR     R2,[R6,#hdr_ymag]
        MUL     R2,R14,R2

        LDRB    R14,[R6,#hdr_flags]

01      STR     R1,xscale
        STR     R2,yscale
        STRB    R14,swapxyposnsflag

        Debug   th,"xscale, yscale, swapxyposns =",#xscale,#yscale,R14

        EXITS                           ; must preserve flags

;.............................................................................

; Entry: R1 = file handle (already open)
;        R6 -> font header block
; Exit:  R2 = 'value' of best entry found (exactmatch = &10000000)
;        [xfactor], [yfactor]   )
;        [R6,#hdr_PixOffset]    ) reflect the settings for this font
;        [R6,#hdr_PixSize]      )

findbest Entry "R2-R8"

        Debug   th,"findbest: file handle =",R1

        MOV     R4,#0                   ; file index
        MOV     R7,#0                   ; best 'value'

searchindex
        BL      readfontheader
        EXIT    VS

        LDRB    R0,fontheader           ; no more?
        TEQ     R0,#0
        BEQ     trybest

        BL      calcvalue
        CMP     R7,R0                   ; R0 = 'value' of font
        MOVCC   R7,R0
        SUBCC   R8,R4,#16               ; R8 <- best index

        B       searchindex

trybest STR     R7,[sp]                 ; R2 = best value on exit
        TEQ     R7,#0                   ; any found?
        MOVNE   R4,R8
        BLNE    readfontheader
        LDRNE   R2,filestart
        ADDNE   R2,R2,#fpix_index       ; R2 = offset of data after index
        STRNE   R2,[R6,#hdr_PixOffset]
        LDRNE   R2,filesize
        SUBNE   R2,R2,#fpix_index       ; R2 = size of remaining data
        STRNE   R2,[R6,#hdr_PixSize]

        EXIT

;.............................................................................

; Entry: R4 = index into file
; Exit:  R4 = index to next entry
;        [fontheader] = 16 bytes starting at that offset
;        [xfactor], [yfactor] set up appropriately

readfontheader PEntryS Cac_PixDisc, "R1-R3"

        MOV     R0,#OSGBPB_ReadFromGiven
        ADR     R2,fontheader           ; temporary data
        MOV     R3,#16                  ; 4 words
        BL      xos_gbpb                ; checks R3=0, preserves R2
        PExit   VS

        LDRB    R0,fontheader
        TEQ     R0,#0
        PExitS  EQ                      ; preserve flags

; work out xfactor,yfactor from header information

        LDRB    R1,fontheader           ; point size
        LDRB    R2,fontheader+2         ; x-resolution
        MUL     R14,R1,R2
        MOV     R14,R14,ASL #scbits     ; shift up by 4 bits!!!
        STR     R14,xfactor

        LDRB    R1,fontheader           ; point size
        LDRB    R2,fontheader+3         ; y-resolution
        MUL     R14,R1,R2
        MOV     R14,R14,ASL #scbits     ; shift up by 4 bits!!!
        STR     R14,yfactor

        Debug   cc,"index, xfactor, yfactor =",R4,#xfactor,#yfactor

        PExitS                          ; preserve flags

;......................................................................

; calculate 'value' of this font
; Entry:  xscale, yscale, xfactor, yfactor = relevant scale factors
; Exit:   R0 = value of font

exactmatch * &10000000

calcvalue Entry "R1"

        LDR     R0,xfactor
        LDR     R1,xscale
        TEQ     R0,R1
        LDR     R0,yfactor              ; R0 = height of font
        LDREQ   R1,yscale
        TEQEQ   R0,R1
        MOVEQ   R0,#exactmatch          ; same size is better

        Debug   th,"xfactor, yfactor, value =",#xfactor,#yfactor,R0

        EXIT

;.............................................................................

; Work out resolution for this mode if supplied ones are 0
; In    R4,R5 = resolution supplied by caller (0 => use default)
; Out   R4,R5 = actual resolution to be used

defaultres Entry "R0-R2"

        TEQ     R4,#0
        BNE     nodefx
        LDR     R0,=72000                       ; calculate OS coords/inch
        LDR     R1,xscalefactor
        BL      divide
        LDR     R14,modedata_px
        MOV     R4,R2,ASR R14                   ; calculate pixels/inch

nodefx  TEQ     R5,#0
        BNE     nodefy
        LDR     R0,=72000                       ; calculate OS coords/inch
        LDR     R1,yscalefactor
        BL      divide
        LDR     R14,modedata_py
        MOV     R5,R2,ASR R14                   ; calculate pixels/inch

nodefy  EXIT
        LTORG

;;----------------------------------------------------------------------------
;; Uncacheing logic
;;----------------------------------------------------------------------------

        GET     Funcache.s

;;----------------------------------------------------------------------------
;; Load a block of data into the top of the cache
;; Uses XOS_GBPB
;; Entry:  R1 = file handle
;;         R3 = length of data
;;         R4 = offset of data in file
;;         [cachefree]     = pointer to free space
;;         [fontcachesize] = offset of top of cache
;; Exit:   cacheptr (R7) --> data (loaded at top of cache)
;;         R6 and R8 may have been relocated
;;----------------------------------------------------------------------------

cacheblock PEntry Cac_PixDisc, "R0-R2"

        PushP   "R6 on entry to cachebock",R6

        MOV     R6,R3
        BL      reservecache2                   ; ensure there's enough memory
        BVS     %FT99

        GetReservedBlockEnd R2,R3, R14          ; R2 -> end of cache - R3
        BIC     R2,R2,#3                        ; ensure word-aligned
        MOV     cacheptr,R2

        Debug   cc,"Cacheblock: R1,R2,R3,R4 =",R1,R2,R3,R4

        MOV     R0,#OSGBPB_ReadFromGiven
        BL      xos_gbpb                ; checks R3=0, preserves R2
99
        PullP   "R6 on exit from cacheblock",R6

        STRVS   R0,[sp]
        PExit

;.............................................................................

; xos_gbpb  -  call XOS_GBPB, checking that R3=0 on exit, preserving R2
; In    R0 = reason code
;       R1 = file handle
;       R2 --> data area
;       R3 = no of bytes to transfer
;       R4 --> file offset (if spec.)
; Out   "Illegal font file" error if any bytes untransferred (ie. file is too small)
;       VC => R3=0, R4 updated

xos_gbpb Entry "R2"

        Debug   cc,"XOS_GBPB:",R0,R1,R2,R3,R4

        SWI     XOS_GBPB
        EXIT    VS
        TEQ     R3,#0
        EXIT    EQ

        PullEnv

        LDRB    R0,currentfont
        LDR     R1,cacheindex
        LDR     R1,[R1,R0,LSL #2]               ; R1 -> font header
        TEQ     R1,#0                           ; should always be one, but we'll be paranoid
        ADDNE   R1,R1,#hdr_name
        BNE     xerr_badfontfile                ; "Illegal font file in <fontname>"

        ADR     R0,ErrorBlock_FontBadFontFile
        B       MyGenerateError
        MakeErrorBlock FontBadFontFile          ; "Illegal font file"

;;----------------------------------------------------------------------------
;; Miscellaneous Service Routines
;;----------------------------------------------------------------------------

; decexpand - print value of R0 in decimal, in field width R1
; HPOS (=R9) is maintained

powersof10
        DCD     1
        DCD     10
        DCD     100
        DCD     1000
        DCD     10000
        DCD     100000
        DCD     1000000
        DCD     10000000
        DCD     100000000
        DCD     1000000000
npowers *       .-powersof10

decexpand Entry "R0-R4,suppflg,power10"

        ADR     power10,powersof10
        MOV     R2,#npowers-4
        SUB     R1,R1,#npowers/4-1              ; field width (>0 --> " ")
        MOV     suppflg,#0                      ; no digits printed yet
        MOV     R4,R0                           ; R4 = trial number

dece1   MOV     R0,#0                           ; work out next digit
        LDR     R3,[power10,R2]
dece2   SUBS    R14,R4,R3                       ; trial subtraction
        MOVCS   R4,R14
        ADDCS   R0,R0,#1
        BCS     dece2

        ADDS    suppflg,R0,suppflg              ; is this a leading 0?
        MOVEQ   R0,#" "                         ; might still be a " "
        ADDGT   R0,R0,#"0"
        CMPEQ   R1,#0                           ; print " " if width OK
        ADDGT   HPOS,HPOS,#1                    ; update HPOS
        SWIGT   XOS_WriteC
        STRVS   R0,[sp]
        EXIT    VS

        ADD     R1,R1,#1                        ; move width counter on
        SUBS    R2,R2,#4
        MOVEQ   suppflg,#1                      ; always print 1 digit
        BPL     dece1

        EXIT

;;----------------------------------------------------------------------------
;; Open a file for input, and check that it is present
;; Entry: R1 --> file name
;; Exit:  R1 = file handle, if successful
;;----------------------------------------------------------------------------

find_close      *       &00
find_openin     *       &40
find_openout    *       &80
find_openup     *       &C0

openfile Entry "R0"

        DebugS  th,"openfile: ",R1

        MOV     R0,#OSFind_ReadFile     ; error if file not found
        SWI     XOS_Find
        MOVVC   R1,R0
        EXIT    VC

        STR     R0,[sp]                 ; error exit
        EXIT

;;----------------------------------------------------------------------------
;; Close a file
;; Entry: R1 = file handle (if 0, then don't bother)
;;        if V set on entry, then remember error state
;;----------------------------------------------------------------------------

closefile EntryS "R0,R1"

        BVC     justclose
        TST     R0,#&80000000           ; is this an immediate constant?
        BNE     %FT01

        Debuga  err,"closefile: error was at",R0
        Debug   err,", LR =",LR

        ADR     R1,errorbuffer          ; copy error away
        LDR     R14,[R0],#4
        STR     R14,[R1],#4
errlp   LDRB    R14,[R0],#1
        STRB    R14,[R1],#1
        TEQ     R14,#0
        BNE     errlp

        ADR     R0,errorbuffer
        STR     R0,[sp,#Proc_RegOffset]
        LDR     R1,[sp,#Proc_RegOffset+4]
01

justclose
        MOV     R0,#find_close          ; close file
        CMP     R1,#0                   ; must clear V
        SWINE   XOS_Find

        EXITS   VC
        STRVS   R0,[sp,#Proc_RegOffset] ; if error, that takes precedence
        EXIT    VS

;------------------------------------------------------------------------------

; SWI &400A8 - lookup a font describing its characteristics
; In    R0 = handle / = 0 for current
;       R1 -> font name / = 0 use handle in R0                  ;NYI
;       R2 = flags word
;               all bits reserved for future expansion
; Out   R0-R1 preserved unless error (where R0 ->block)
;       R2 = characteristics
;               bit 0 = 1 => font is an x90y45 version (ie. bitmap only)
;               bit 1 = 1 => font is in ROM
;               bit 8 = 1 => font rendered in monochrome
;               bit 9 = 1 => font uses non-zero filling
;               all other bits reserved for future expansion
;       R3-R7 = undefined

fontlookup_Allowed              * 0

fontlookup_IsBitmap             * 1:SHL:0
fontlookup_IsInROM              * 1:SHL:1
fontlookup_IsMonochrome         * 1:SHL:8
fontlookup_IsNonZeroFill        * 1:SHL:9

SWIFont_LookupFont Entry "R0-R1,R8-R9"

        Debug   lookup,"Font_LookupFont: handle, flags =",R0,R2

        LDR     R14,=fontlookup_Allowed
        BICS    R14,R2,R14                      ; any reserved bits set?
        TEQEQ   R1,#0                           ; have they specified a font name?
        BNE     err_reserved_lookupfont

        CMP     R0,#maxf                        ; handles must be in range 1..255
        TEQCS   R0,R0
        TEQNE   R0,#0
        LDRNE   R1,cacheindex                   ; can't call getfontheaderptr,
        TEQNE   R1,#0                           ; cos it's OK to have 0 references
        LDRNE   R8,[R1,R0,LSL #2]
        TEQNE   R8,#0                           ; R8 --> slave font header
        [ checkhandles
        LDRNE   LR,[R8,#hdr_usage]
        TEQNE   LR,#0
        ]
        LDRNEB  R8,[R8,#hdr_masterfont]
        LDRNE   R8,[R1,R8,LSL #2]               ; R8 --> master font header
        TEQNE   R8,#0

        BLEQ    errnometricsdata
        BVS     %FT99

        Debug   lookup,"Master font data ->",R8

        MOV     R9,R2                           ; R9 = copy of entry flags being used
        MOV     R2,#0                           ; R2 = return flags

        LDRB    R14,[R8,#hdr1_leafname]
        CMP     R14,#leaf_scanfontdir
        BLE     %FT01                           ; not an outlines file so skip decoding

        Debug   lookup,"Master font is a outlines"

        LDRB    R14,[R8,#hdr1_flags]
        TST     R14,#pp_monochrome              ; is it to be rastered monochrome?
        ORRNE   R2,R2,#fontlookup_IsMonochrome
        TST     R14,#pp_fillnonzero             ; which fill rule is applied?
        ORRNE   R2,R2,#fontlookup_IsNonZeroFill

        LDR     R14,[R8,#hdr1_address]
        TEQ     R14,#0                          ; does the font reside in ROM?
        ORRNE   R2,R2,#fontlookup_IsInROM
01
        LDRB    R14,[R8,#hdr1_leafname]
        CMP     R14,#leaf_scanfontdir
        LDRB    R0,[R8,#hdr4_leafname]
        CMPGT   R0,#leaf_scanfontdir
        BGT     %FT99                           ; if we have already coped then exit

        CMP     R0,#leaf_scanfontdir
        BLE     %FT99

        Debug   lookup,"Master font is a 4BPP pixel data"

        LDR     R14,[R8,#hdr4_address]          ; is it in ROM?
        TEQ     R14,#0
        ORRNE   R2,R2,#fontlookup_IsInROM
        ORR     R2,R2,#fontlookup_IsBitmap      ; tag as being bitmap
99
        PPullS  "$Proc_RegList"

err_reserved_lookupfont
        BL      err_reserved
        B       %BT99                           ; complain about invalid flags word

        END
