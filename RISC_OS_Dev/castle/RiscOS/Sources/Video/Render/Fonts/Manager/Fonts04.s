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
; > Sources.Fonts04

; Cache font data from disc, processing as required
;
; Metrics: Scale from master font according to x/ysize
; Pixels:  Depends on file type in leafname:
;          f9999x9999    load directly, without scaling
;          x90y45        munge to correct format, without scaling
;          b9999x9999    load directly, without scaling
;          Outlines      load directly, without scaling
;          2             scale from 4-bpp pixel data in master font
;          3             scale from outlines to 1/4-bpp in cache
;          4             use master outlines directly

;;----------------------------------------------------------------------------
;; Set up pointers to font metrics
;; Entry:  [currentfont] = required font
;;         pixelsptr -> pixel data (or 0 if not yet calculated)
;;         [paintmatrix] -> current paint matrix
;; Exit :  metricsptr, [xoffset], [yoffset] --> metrics info
;;         [metricsmatrix] -> matrix to apply to these (0 if none)
;;         If font has been uncached, it will be recached automatically
;;         pixelsptr may have been relocated
;;         pixelsptr set to zero if scratchblock != 0 (for paintdraw)
;;
;; metricsptr      RN      R10
;; pixelsptr       RN      R9
;;----------------------------------------------------------------------------

SetMetricsPtrs  PEntry Cac_Metrics, "R0-R7"

     ;; CheckCache "SetMetricsPtrs entry"

        LDRB    R0,currentfont                          ; R0 = offset
        Debug   me,"SetMetricsPtrs: currentfont =",R0
        BL      getfontheaderptr
        BVS     %FT99

        MOV     R6,R7                           ; R6 -> font header

        LDR     R14,paintmatrix                 ; recompute metrics matrix if different
        LDR     R1,oldpaintmatrix
        TEQ     R14,R1
        STRNE   R14,oldpaintmatrix
        BLNE    GetTransform                    ; can cause errors (eg. font cache full)

        BLVC    getmetricsblock                 ; this routine may recurse
        BVS     %FT99                           ; R0 = no of chars if V clear

        ASSERT  flg_nobboxes   < &100
        ASSERT  flg_noxoffsets < &100
        ASSERT  flg_noyoffsets < &100
        ASSERT  flg_prescaled  < &100
        ASSERT  flg_mapsized   < &100

        LDRB    R1,[R6,#met_flags]              ; R1 = bottom byte of flags

        ADD     metricsptr,R6,#met_chmap        ; metricsptr --> char map

        STR     R1,metflags
        TST     R1,#flg_mapsized
        LDRNEB  R4,[metricsptr],#1
        LDRNEB  R14,[metricsptr],#1
        ORRNE   R4,R4,R14,LSL #8                ; R4 = number of entries in map (0 if no map at all)
        MOVEQ   R4,#256                         ; if map not sized, there are always 256 entries
        STR     R4,metchmapsize

        TST     R1,#flg_prescaled               ; allow for 16- or 32-bit quantities
        MOVEQ   R2,R0,LSL #1
        MOVNE   R2,R0,LSL #2                    ; R2 = size of a block of n entries (R0 = n)

        TST     R1,#flg_nobboxes
        MOVNE   R14,#0
        ADDEQ   R14,metricsptr,R4               ; x0
        STR     R14,bboxx0
        ADDEQ   R14,R14,R2                      ; y0
        STR     R14,bboxy0
        ADDEQ   R14,R14,R2                      ; x1
        STR     R14,bboxx1
        ADDEQ   R14,R14,R2                      ; y1
        STR     R14,bboxy1
        ADDEQ   R14,R14,R2
        ADDNE   R14,metricsptr,R4               ; R14 -> data after bboxes

        MOV     R3,#0

        TST     R1,#flg_noxoffsets
        STRNE   R3,xoffset
        STREQ   R14,xoffset
        ADDEQ   R14,R14,R2                      ; R14 -> data after x offsets

        TST     R1,#flg_noyoffsets
        STRNE   R3,yoffset
        STREQ   R14,yoffset
        ADDEQ   R14,R14,R2                      ; R14 -> data after y offsets

; Stash offsets to the extra data areas at the end of the metrics (if present)

        TST     R1,#flg_moredata
        STREQ   R3,metmisc
        STREQ   R3,metkerns
        LDRNEB  R2,[R14,#fmet_table0]                     ; offset to the first 2 tables (combined)
        LDRNEB  R3,[R14,#fmet_table0+1]
        ADDNE   R2,R14,R2
        ADDNE   R2,R2,R3,LSL #8
        STRNE   R2,metmisc
        LDRNEB  R2,[R14,#fmet_table1]                     ; offset to the first 2 tables (combined)
        LDRNEB  R3,[R14,#fmet_table1+1]
        ADDNE   R2,R14,R2
        ADDNE   R2,R2,R3,LSL #8
        STRNE   R2,metkerns

        LDR     R14,scratchblock
        TEQ     R14,#0                          ; doesn't affect V
        MOVNE   pixelsptr,#0                    ; must reallocate scratchblock
        STRNE   pixelsptr,scratchblock

        Debug   me,"SetMetricsPtr: metricsptr,R0 =",metricsptr,R0
99
     ;; CheckCache "SetMetricsPtrs exit"

        PExit

;;----------------------------------------------------------------------------
;; Entry:  R6 --> font header
;;         [metricsmatrix] = matrix to apply to this set of metrics
;; Exit:   R6 --> metrics block (in slave or master as appropriate)
;;         R0 = no of defined characters
;;         pixelsptr may have been relocated
;; [newmapping]: x/ymetscale,x/ymetfactor set up from slave and master font headers
;;----------------------------------------------------------------------------

getmetricsblock Entry "R7,R8"

; Don't ever load metrics for a slave font - they're always scaled dynamically from the master
; Since metrics scaling is dynamic, we must make sure x/yscale and x/yfactor are set up every time here.

        ADD     R14,R6,#hdr_xsize
        LDMIA   R14,{R0,R14}
        Debug   me,"getmetricsblock: R6, metricsmatrix, xsize =",R6,#metricsmatrix,R0
        ADR     R8,xmetscale
        STMIA   R8,{R0,R14}                     ; set up xscale, yscale
        ADR     R8,xmetfactor
        STMIA   R8,{R0,R14}                     ; set up xfactor, yfactor

        LDRB    R0,[R6,#hdr_masterfont]         ; master font or slave?
        TEQ     R0,#0
        BEQ     %FT01

        BL      getfontheaderptr                ; error if master font lost
        BVS     %FT99

        MOV     R6,R7                           ; R6 -> master font header
        LDR     R14,[R6,#hdr_MetSize]           ; 0 => metrics header not cached
        TEQ     R14,#0                          ; NOTE: slave fonts have this set to 1 already!
        BLEQ    GetMetricsHeader                ; doesn't cause the cache to move
        BVS     %FT99

        MarkAge R6, R8,R14                      ; mark font block 'accessed'

        ADD     R14,R6,#hdr_xsize
        LDMIA   R14,{R0,R14}
        ADR     R8,xmetfactor
        STMIA   R8,{R0,R14}                     ; set up xfactor, yfactor
01

        Debug   me,"getmetricsblock: x/yscale, x/yfactor",#xscale,#yscale,#xfactor,#yfactor

        LDR     R14,[R6,#hdr_MetricsPtr]        ; (incorrect if slave font
        TEQ     R14,#0                          ; and not yet cached)
        LDRNE   R0,[R6,#hdr_nchars]             ; R0 = no of chars
        MOVNE   R6,R14                          ; R6 -> metrics block
        PushP   "pixelsptr",pixelsptr
        CacheHit Metrics, NE
        BLEQ    CacheMetrics                    ; returns R0,R6
        PullP   "pixelsptr",pixelsptr

        MarkAccessed R6,R14, VC                 ; mark metrics 'accessed' (if in cache)

        Debug   me,"getmetricsblock: R6, R0 on exit",R6,R0

99
        EXIT


;;----------------------------------------------------------------------------
;; CacheMetrics
;; Entry:  R6 -> font header
;; Exit:   R6 -> metrics block
;;         R0 = no of defined chars
;;         [old R6,#hdr_MetricsPtr] = new R6
;;         [old R6,#hdr_nchars] = R0 = no of defined chars
;;----------------------------------------------------------------------------

CacheMetrics PEntry Cac_Metrics, "R0-R5,cacheptr,R8"

        ADD     R8,R6,#hdr_MetricsPtr   ; R8 --> link (used later)

        LDR     R5,[R6,#hdr_nchars]     ; R5 = no of defined chars

        LDR     R2,[R6,#hdr_metaddress] ; is this a ROM font?
        TEQ     R2,#0
        LDRNE   R4,[R6,#hdr_MetOffset]
        ADDNE   R2,R2,R4                ; R2 -> metrics index
        BNE     %FT88                   ; sets R6 from R2

        LDR     R6,[R6,#hdr_MetSize]    ; make SURE block is big enough
        ADD     R6,R6,#met_nchars+3     ; (may be extra bits on the end)
        BIC     R6,R6,#3                ; word-align

        Debug   me,"Master metrics from disc: block size",R6

        BL      reservecache            ; R6 -> new block
        BVS     %FT99

; load metrics data from disc (directly into the new block)

        ProfIn  Cac_MetDisc

        ADD     R2,R6,#met_nchars       ; R2 -> destination
        SUB     R6,R8,#hdr_MetricsPtr   ; recover font block ptr
        BL      openmetrics
        BVS     %FT88                   ; get R6 back for cache recovery

        Debug   cc,"Metricshandle: fonthdr,handle =",R6,R1

        LDR     R4,[R6,#hdr_MetOffset]
        LDR     R3,[R6,#hdr_MetSize]
        MOV     R0,#OSGBPB_ReadFromGiven
        BL      xos_gbpb                ; checks R3, preserves R2

        BL      closemetrics            ; preserves error status

88      SUB     R6,R2,#met_nchars       ; R6 -> new metrics block

        ProfOut Cac_MetDisc
        BVS     exitcachemetrics

; quick check that version and flags are consistent

        ASSERT  (met_nchars :AND: 3) = 0
        ASSERT  met_nchars + 2 = met_flags
        ASSERT  met_nchars + 3 = met_nhi

        LDRB    R14,[R6,#met_version]
        CMP     R14,#2                  ; version 2 can modify anything!
        BEQ     exitcachemetrics

        CMP     R14,#1                  ; versions 0 and 1 have certain restrictions
        BEQ     err_badmetrics          ; version 1 is in fact no longer supported (kern format has changed)

        LDRLO   R3,[R6,#met_nchars]
        MOVLO   R3,R3,LSR #16           ; flags and nhi must be 0 if version 0
        ANDEQ   R3,R3,#&FF00            ; nhi must be 0 if version 1
        CMPLO   R3,#0
        BHI     err_badmetrics

; common exit for ram-scaling and disc cacheing

exitcachemetrics
        BVS     err_exitcm

        Debug   me,"Number of entries, metrics block, link",R5,R6,R8

        MakeLink R6,R8                  ; if no error, [R8] --> R6
        STR     R5,[sp]                 ; R0 = no of entries on exit

99
        DebugE  me,"Error from CacheMetrics"

        CheckCache "exit from cachemetrics"

        ProfOut Cac_Metrics
        STRVS   R0,[sp]
        Pull    "R0-R5,cacheptr,R8,PC"  ; returns V bit

err_badmetrics
        ADD     R1,R8,#hdr_name - hdr_MetricsPtr
        BL      xerr_badfontfile        ; "Illegal Font File"

err_exitcm
        DiscardBlock R6, R3,R14         ; if error, delete block (must be last one allocated)
        B       %BT99

;..............................................................................

; In    [xyscale] = multiplication factor
;       [xyfactor] = division factor
;       [cacheptr] -> input value (16-bit signed)
;       [metricsptr] -> output buffer
; Out   [metricsptr],#4 = scaled value
;       cacheptr += 2

scalexmetric Entry "R1,R2,R3,R4"

        LDR     R3,xmetscale            ; routine used only in ReadFontMetrics now
        LDR     R4,xmetfactor           ; where these are set up instead
        B       %FT01

scaleymetric ALTENTRY

        LDR     R3,ymetscale
        LDR     R4,ymetfactor

01      LDRB    R0,[cacheptr],#1
        LDRB    R1,[cacheptr],#1                ; load item (2 bytes)
        MOV     R1,R1,LSL #24
        ORR     R1,R0,R1,ASR #16                ; sign-extended

        Debuga  me2,"scalemetric:",R1
        Debuga  me2," *",#scalemets1
        Debuga  me2," /",#scalemets2

        MUL     R0,R1,R3                        ; scale up by old point size
        MOV     R1,R4                           ; scale down by old point size
        TEQ     R1,#16
        MOVEQ   R2,R0,ASR #4
        BLNE    divide
        STR     R2,[metricsptr],#4

        Debug   me2," =",R2

        CLRV
        EXIT

;..............................................................................

; In    R2,R3 = x,y offset
;       x/ymetscale, x/ymetfactor = multiplication and division factors
; Out   R2,R3 scaled

scalewidth Entry "R0,R1"

        Debug   me,"scalewidth in: x,y, x/ymetscale, x/ymetfactor",R2,R3,#xmetscale,#ymetscale,#xmetfactor,#ymetfactor

        LDR     R1,xmetscale
        MUL     R0,R1,R2
        LDR     R1,xmetfactor
        TEQ     R1,#16
        MOVEQ   R2,R0,ASR #4                    ; quick divide by 16
        BLNE    divide                          ; R2 := R0 / R1

        Debug   me,"scalewidth out: x",R2

        CMP     R3,#0                           ; most y-offsets are zero, in fact
        EXIT    EQ

        Push    "R2"
        LDR     R1,ymetscale
        MUL     R0,R1,R3
        LDR     R1,ymetfactor
        TEQ     R1,#16
        MOVEQ   R2,R0,ASR #4                    ; quick divide by 16
        BLNE    divide
        MOV     R3,R2
        Pull    "R2"

        Debug   me,"scalewidth out: y",R3

        CLRV
        EXIT

; In    R5 = x metric
;       xmetscale, xmetfactor = multiplication and division factors
; Out   R5 scaled

scalexwidth Entry "R0-R2"

        Debug   me,"scalexwidth in: x, xmetscale, xmetfactor",R5,#xmetscale,#xmetfactor

        LDR     R1,xmetscale
        MUL     R0,R1,R5
        LDR     R1,xmetfactor
        TEQ     R1,#16
        MOVEQ   R2,R0,ASR #4                    ; quick divide by 16
        BLNE    divide                          ; R2 := R0 / R1
        MOV     R5,R2
        Debug   me,"scalexwidth out: x",R5
        CLRV
        EXIT

; In    R5 = y metric
;       ymetscale, ymetfactor = multiplication and division factors
; Out   R5 scaled

scaleyheight Entry "R0-R2"

        Debug   me,"scaleyheight in: y, ymetscale, ymetfactor",R5,#ymetscale,#ymetfactor

        LDR     R1,ymetscale
        MUL     R0,R1,R5
        LDR     R1,ymetfactor
        TEQ     R1,#16
        MOVEQ   R2,R0,ASR #4                    ; quick divide by 16
        BLNE    divide                          ; R2 := R0 / R1
        MOV     R5,R2
        Debug   me,"scaleyheight out: y",R5
        CLRV
        EXIT

;;----------------------------------------------------------------------------
;; SetPixelsPtr
;; Entry:  pixelsptr --> current chunk of 32 characters (if any)
;;         metricsptr --> metrics of font (or 0)
;;         [currentfont] = current font
;;         [currentchunk] = current chunk
;;         R0 = character code required
;;         [antialiasx/y] = subpixel position (if required)
;;         [aliascolours] = font colour offset (0 => try 1-bpp first)
;; Exit:   inptr -> character header (0 => char is null)
;;         pixelsptr --> index for relevant chunk
;;         metricsptr relocated if necessary
;;         [charflags] => which type of data we have here
;;----------------------------------------------------------------------------

SetPixelsPtr    PEntry Cac_Pixels, "R0-R1,R6-R8"

     ;; CheckCache "SetPixelsPtr entry"

        TEQ     pixelsptr,#0
        BEQ     %FT01                   ; must reset it

        LDR     R14,currentchunk        ; this is set to 0 (impossible) if cacheing from outlines direct
        TEQ     R14,R0,ASR #5           ; same chunk?
        BNE     %FT01                   ;  no - must recache

        Debug   cc,"SetPixelsPtr: pixelsptr =",pixelsptr

        BL      getcharfromindex        ; yes - see if we already have this character
        CacheHit Pixels, NE
        BNE     setpix_gotchar

; currentchar and currentchunk may be altered later if we turn out to be loading from outlines direct

01      STR     R0,currentchar

        TEQ     R0,#PIX_ALLCHARS
        MOVNE   R0,R0,LSR #5            ; get chunk number from char code (UNLESS R0 = PIX_ALLCHARS)
        STRNE   R0,currentchunk

; get R6 -> font header

        LDRB    R0,currentfont          ; R0 = font handle
        BL      getfontheaderptr        ; R7 -> font header block
        MOVVC   R6,R7                   ; R6 -> font header block
        BVS     %FT99

; [paintmatrix] -> paint matrix - if unchanged, continue with the current transform block

        LDR     R0,paintmatrix          ; if no paint matrix, carry on regardless
        LDR     R14,oldpaintmatrix
        TEQ     R0,R14
        STRNE   R0,oldpaintmatrix
        BLNE    GetTransform            ; allocate transform block if necessary and obtain new rendermatrix
        BVS     %FT99

; decide whether to initialise 1-bpp or 4-bpp data - either in font header or transform block

        LDR     R7,transformptr
        TEQ     R7,#0
        BLEQ    ensureheaders_untransformed
        BLNE    ensureheaders_transformed
        DebugE  trn,"Error in SetPixelsPtr:"
        BVS     %FT99

; now get hold of the actual pixel chunk (may already be cached)

        LDR     R0,currentchar          ; recover character code
        BL      setpixelsptr            ; can recurse

        Debug   cc,"SetPixelsPtr: metricsptr, pixelsptr =",metricsptr,pixelsptr

        LDRVC   R0,currentchar          ; R0 = character code - may be different from the original
        BLVC    getcharfromindex        ; inptr -> character header

setpix_gotchar

99
     ;; CheckCache "SetPixelsPtr exit"

        ASSERT  inptr = R4              ; not stacked
        STRVS   R0,[sp]
        PExit

;.............................................................................

; In    R6 -> font header
;       [transformptr] = 0
;       [aliascolours] = 0 => monochrome, else anti-aliased
; Out   R7 = hdr1_leafname or hdr4_leafname as appropriate

ensureheaders_untransformed EntryS ""

        LDRB    R14,aliascolours
        TEQ     R14,#0
        BEQ     %FT02

        ASSERT  leaf_none < leaf_scanfontdir

        LDRB    R14,[R6,#hdr4_leafname]
        CMP     R14,#leaf_scanfontdir
        BLT     %FT02
        BLEQ    GetPixels4Header        ; try 4-bpp first
        MOVVC   R7,#hdr4_leafname
        BVC     %FT03

02      LDRB    R14,[R6,#hdr1_leafname]
        CMP     R14,#leaf_scanfontdir
        BLT     %FT21
        BLEQ    GetPixels1Header        ; try 1-bpp first / or if no 4-bpp
        MOVVC   R7,#hdr1_leafname
        BVC     %FT03

21      LDRB    R14,[R6,#hdr4_leafname]
        CMP     R14,#leaf_scanfontdir
        BLE     GetPixels4Header        ; try 4-bpp next - this time it must work or else!
        MOVVC   R7,#hdr4_leafname
03
        EXITV                           ; all flags except V preserved

;.............................................................................

; In    R6 -> font header
;       [transformptr] -> transform block
;       [aliascolours] = 0 => monochrome, else anti-aliased
; Out   R7 = hdr1_leafname or hdr4_leafname as appropriate

ensureheaders_transformed Entry "R8"

        LDR     R8,transformptr

        LDRB    R14,aliascolours
        TEQ     R14,#0
        BEQ     %FT02

        ASSERT  leaf_none < leaf_scanfontdir

        LDRB    R14,[R8,#trn_leafname]
        CMP     R14,#leaf_scanfontdir
        BLT     %FT02
        BLEQ    GetPixels4Header        ; try 4-bpp first
        MOVVC   R7,#hdr4_leafname
        BVC     %FT03

02      LDRB    R14,[R8,#trn_leafname]
        CMP     R14,#leaf_scanfontdir
        BLT     %FT21
        BLEQ    GetPixels1Header        ; try 1-bpp first / or if no 4-bpp
        MOVVC   R7,#hdr1_leafname
        BVC     %FT03

21      LDRB    R14,[R8,#trn_leafname]
        CMP     R14,#leaf_scanfontdir
        BLEQ    GetPixels4Header        ; try 4-bpp next - this time it must work or else!
        MOVVC   R7,#hdr4_leafname
03
        EXIT

;.............................................................................

; In    R0 = character code
;       [antialiasx/y] = subpixel offsets
;       pixelsptr -> character index (0 => none)
; Out   NE => inptr -> character header (0 => none)
;       EQ => character is not yet cached (loop back within SetPixelsPtr)

getcharfromindex Entry "R0,R1"

        Debug   cc,"getcharfromindex: pixelsptr, char code =",pixelsptr,R0

        MOVS    inptr,pixelsptr
        BEQ     %FT01

; work out index from char code and x,y subpixel offsets

        LDR     R14, [pixelsptr, #pix_flags - pix_index]
        TST     R14,#pp_4xposns
        MOVEQ   inptr,#0
        LDRNEB  inptr,antialiasx
        MOVNE   inptr,inptr,LSL #5      ; multiply by 32
        TSTNE   R14,#pp_4yposns
        MOVNE   inptr,inptr,LSL #2      ; times 4 if y-posns done also
        TST     R14,#pp_4yposns
        LDRNEB  R14,antialiasy
        ADDNE   inptr,inptr,R14,LSL #5  ; correct for y-posn (if nec.)
        AND     R14,R0,#&1F             ; look up relevant character
        ADD     inptr,inptr,R14

        Debuga  cc,"getcharfromindex: pixelsptr,index =",pixelsptr,inptr

; get char address by looking up address/offset in index

        LDR     inptr,[pixelsptr,inptr,LSL #2]  ; can be 1-bpp/4-bpp/outlines

        ASSERT  PIX_UNCACHED > 0
        CMP     inptr,#PIX_UNCACHED+1   ; LO => inptr=0 or PIX_UNCACHED (VS maybe!)
        LDR     R1,[pixelsptr,#pix_flags-pix_index]
        ANDHI   R14, R1, #pp_splitchunk ; (avoid TST clobbering C)
        CMPHI   R14, #0                 ; NE => inptr -> character or is 0 or PIX_UNCACHED

        ADDEQ   inptr,pixelsptr,inptr   ; EQ => inptr = character offset
        MarkAge inptr, R0,R14, HI       ; if inptr -> block, mark 'accessed' (can't be in ROM)
        ADDHI   inptr,inptr,#std_end    ; HI => inptr -> character block

        TST     R1,#pp_incache          ; set when block was loaded / created
        SUBNE   R1,pixelsptr,#pix_index
        MarkAge R1, R0,R14, NE

        LDRNE   R14,transformptr        ; block must be in cache if transform block involved
        TEQNE   R14,#0
        BNE     %FT02                   ; optimise the non-transform case
01
        Debug   cc,", value =",inptr
        CMP     inptr,#PIX_UNCACHED     ; EQ => character is not yet cached
        EXIT
02
        Debug   trn,"getcharfromindex: transformptr =",R14
        MarkAge R14, R0,R1              ; ensure transform block is younger than the chunk
        Debug   cc,", value =",inptr    ; must already be at head of transform chain
        CMP     inptr,#PIX_UNCACHED     ; EQ => character is not yet cached
        EXIT

;.............................................................................

; In    R6 -> font header
;       [paintmatrix] -> current paint matrix (0 => unit matrix)
;       [aliascolours] = 0 => 1-bpp, else 4-bpp
; Out   [transformptr] -> corresponding transform block (0 => unit matrix)
;       [rendermatrix] -> render matrix
;       [metricsmatrix] -> metrics matrix
;       R6 may be relocated
;
; NB: The most recently used transform block MUST be pulled to the head of the list
;     This is because deleteblock can only delete blocks which have no children

GetTransform Entry ""

        Debug   trn,"GetTransform: font header, paintmatrix =",R6,#paintmatrix

        LDR     R14,paintmatrix
        TEQ     R14,#0
        BNE     %FT01

        STR     R14,transformptr                ; no transform block

        ADD     R14,R6,#hdr_rendermatrix        ; render matrix in font header
        STR     R14,rendermatrix

        LDR     R14,[R6,#hdr_FontMatrix]        ; metrics matrix in fontmatrix block
        TEQ     R14,#0                          ; or 0 => no transform
        ADDNE   R14,R14,#mtb_metricsmatrix
        STR     R14,metricsmatrix

        Debug   trn,"No transform block required"

        EXIT

; hash the paintmatrix to obtain an index in the range 0..15
; if this hash function changes, Font Cache MinVersion must be updated

01
        Push    "R0-R5,R7-R11"                  ; we need 12 registers for comparison

Proc_RegList    SETS    "R0-R5,R7-R11"          ; NB: assume only LR stacked initially

        LDMIA   R14,{R0-R5}
        EOR     R14,R0,R1,ROR #31
        EOR     R14,R14,R2,ROR #31
        EOR     R14,R14,R3,ROR #31
        EOR     R14,R14,R14,ROR #16             ; make sure all bits participate!
        EOR     R14,R14,R14,ROR #8
        EOR     R14,R14,R14,ROR #4
;       AND     R14,R14,#&F                     ; R14 = index in range 0..15
        AND     R14,R14,#&7                     ; R14 = index in range 0..7
        LDRB    R8,aliascolours
        TEQ     R8,#0
        ADDEQ   R14,R14,#8                      ; map to hdr1_transforms if 1-bpp

; search the appropriate transform chain to find the block we want

        ADD     R8,R6,#hdr_transforms
        LDR     R14,[R8,R14,LSL #2]!            ; R8 -> link, R14 = value

02      TEQ     R14,#0
        BEQ     %FT03

        ADD     R14,R14,#trn_paintmatrix
        LDMIA   R14!,{R7,R9,R10,R11}            ; check xx,xy,yx,yy first
        TEQ     R0,R7
        TEQEQ   R1,R9
        TEQEQ   R2,R10
        TEQEQ   R3,R11
        LDMEQIA R14,{R7,R9}
        TEQEQ   R4,R7
        TEQEQ   R5,R9
        LDRNE   R14,[R14,#trn_link - (trn_paintmatrix + mat_X)]
        BNE     %BT02

; found it - bring this block to the head of the list and mark accessed

        SUB     R7,R14,#trn_paintmatrix+mat_X   ; R7 -> this block, R8 -> head of list

        LDR     R1,[R7,#std_anchor]             ; R1 -> link to this block
        TEQ     R1,R8
        BEQ     %FT12                           ; done if already at head

        LDR     R2,[R7,#trn_link]
        STR     R2,[R1]                         ; remove this block from the list
        TEQ     R2,#0
        STRNE   R1,[R2,#std_anchor]             ; watch out for R7 being the last block!

        LDR     R1,[R8]
        STR     R1,[R7,#trn_link]
        ADD     R14,R7,#trn_link
        STR     R14,[R1,#std_anchor]

        STR     R7,[R8]
        STR     R8,[R7,#std_anchor]             ; then replace at the head
12
        MarkAge R7, R1,R2                       ; mark transform block 'accessed'

; get render matrix etc from the transform block

        STR     R7,transformptr                 ; do this now - parameter to getnewrendermatrix

        LDR     R14,[R7,#trn_rendermatrix + mat_marker]
        TEQ     R14,#MAT_MARKER
        BLEQ    getnewrendermatrix              ; recompute this if it has been marked invalid (by Font_UnCacheFile)

        ADD     R14,R7,#trn_rendermatrix        ; [rendermatrix] -> render matrix in block
        STR     R14,rendermatrix                ; bbox matrix follows

        ADD     R14,R7,#trn_metricsmatrix
        STR     R14,metricsmatrix

        Debug   trn,"New transformptr, rendermatrix, metricsmatrix =",#transformptr,#rendermatrix,#metricsmatrix

        EXIT                                    ; if error, matrix will be marked invalid, so we'll get it again

; block does not exist - make a new one and link it in (must be at the head of the list)

03
        PushP   "Saving font header ptr",R6

;       MOV     R6,#trn_end

; Now we *must* be scaling from outlines here, as there's a transform
; This must be a slave font, so we find out how many chunks are in the master outlines

        Debug   trn,"Calculating nchunks for a new transform block"

        LDRB    R0,[R6,#hdr_masterfont]         ; must be a slave font here
        BL      getfontheaderptr                ; error if master font lost
        BVS     %FT99

; DONE: Call GetPixels1Header to read the master font nchunks
        MOV     R6,R7
        BL      GetPixels1Header
        BVS     %FT99                           ; will return error if no outlines

        LDR     R1,[R7,#hdr1_nchunks]           ; R7 -> master font header
      [ debugbrk
        CMP     R1,#0
        BreakPt "Master outlines nchunks = 0 when allocating transform block",EQ
      ]

        Debug   trn,"Allocating transform block: nchunks =",R1

        MOV     R6,#trn_PixelsPtrs
        ADD     R6,R6,R1,LSL #2
        BL      reservecache                    ; R6 -> new block
        BVS     %FT99                           ; no block to delete

        Debug   trn,"transform nchunks =",R1
        STR     R1,[R6,#trn_nchunks]

        MOV     R14,#leaf_scanfontdir           ; GetPixelsHeader sets these up properly
        STRB    R14,[R6,#trn_leafname]

      [ debugbrk
        MOV     R14,#0
        STR     R14,[R6,#trn_boxx0]
        STR     R14,[R6,#trn_boxy0]
        LDR     R14,=2   ; &DEADDEAD    ; v. small bbox - let's see if it goes wrong!
        STR     R14,[R6,#trn_boxx1]
        STR     R14,[R6,#trn_boxy1]
      ]

        MOV     R14,#0
;       MOV     R1,#trn_pixarray1-trn_pixarray0
;       ADD     R2,R6,#trn_pixarray0
        ADD     R2,R6,#trn_PixelsPtrs
04      STR     R14,[R2],#4
        SUBS    R1,R1,#1
        BNE     %BT04

; set up the new matrices in this transform block

        LDR     R14,paintmatrix
        LDMIA   R14,{R0-R5}
        ADD     R14,R6,#trn_paintmatrix
        STMIA   R14,{R0-R5}

        STR     R6,transformptr                 ; [transformptr] -> transform block
        PullPx  "Get font header back",R6       ; R6 -> font header
        BL      getnewrendermatrix              ; must not move the cache

        Debug   trn,"New transformptr, rendermatrix, metricsmatrix =",#transformptr,#rendermatrix,#metricsmatrix

; VS => block invalid, should be discarded now
; VC => block valid, should be linked into the transform chain

        LDR     R6,transformptr

        BVS     %FT95

        LDRVC   R1,[R8]
        MakeLink R6,R8, VC                      ; link in new transform block
        ADDVC   R8,R6,#trn_link
        MOVVC   R6,R1
        MakeLink R6,R8, VC                      ; put old chain head in (may be 0)
99
        PullP   "Restoring font header ptr",R6

        EXIT

95
        DiscardBlock R6,R1,R14
        B       %BT99
        LTORG

;.............................................................................

; In    R0 = character code required (PIX_ALLCHARS => all) - version 2.69 onwards
;       [antialiasx/y] = subpixel offsets (if required)
;       [currentchunk] = character chunk required (0..nchunks-1)
;       R6 -> font header block
;       R7 = #hdr1/4_leafname (depending on which type is required)
;       metricsptr --> font metrics (or 0 if not yet accessed)
;       [transformptr] -> transform block to use
; Out   pixelsptr --> index of pixel chunk
;       R6, metricsptr relocated if necessary

        ASSERT  pixelsptr  = R9
        ASSERT  metricsptr = R10

setpixelsptr Entry ""

     ;; CheckCache "setpixelsptr entry"

      [ debugbrk
        TEQ     R7,#hdr1_leafname
        TEQNE   R7,#hdr4_leafname
        BreakPt "setpixelsptr: incorrect R7",NE
      ]

        LDR     R14,transformptr
        TEQ     R14,#0
        LDREQB  R14,[R6,R7]             ; R14 <> leaf_4bpp if transform block used

        TEQ     R14,#leaf_4bpp
        MOVNE   R14,#1                  ; magnification only applies to 4-bpp
        LDREQ   R14,[R6,#hdr_xmag]
        STR     R14,xmag                ; update xmag,ymag
        LDREQ   R14,[R6,#hdr_ymag]
        STR     R14,ymag

        LDRB    R14,[R6,#hdr_skelthresh]
        STRB    R14,skeleton_threshold  ; slave font version

        PullEnv                         ; drop through

;.................................................................................

; entry point for recursion (parameters as for setpixelsptr)

setpixelsptr2   PEntry Cac_Pixels, "R2,inptr,R7-R8"

        PushP   "setpixelsptr: font header",R6

      [ debugcc :LOR: debugtrn
        Debuga  cc :LOR: debugtrn,"setpixelsptr: font header",R6
        Debuga  cc :LOR: debugtrn,", character",R0
        TEQ     R7,#hdr1_leafname
        BNE     %FT00
        Debuga  cc :LOR: debugtrn," (1-bpp)"
        B       %FT01
00
        Debuga  cc :LOR: debugtrn," (4-bpp)"
01
        Debug   cc :LOR: debugtrn," transform =",#transformptr
      ]

        LDR     R8,transformptr
        TEQ     R8,#0
        BNE     %FT05

; Non-transformed version - obtain chunk index (may have to allocate one)

        TEQ     R7,#hdr1_leafname
        LDREQ   R8,[R6,#hdr1_PixoPtr]
        LDRNE   R8,[R6,#hdr4_PixoPtr]
        Debug   cc,"pixo block was at",R8
        CMP     R8,#0
        BLEQ    readpixoblock                   ; could be direct from file, or a slave font
        BVS     %FT99
        ADD     R8,R8,#pixo_pointers
        LDR     R14,currentchunk
        Debug   cc,"pixo pointers, current chunk",R8,R14

        ADD     R2,R7,#hdr1_nchunks-hdr1_leafname
        LDR     R2,[R6,R2]                      ; R2 = number of chunks
        CMP     R14,R2                          ; HS => out of range
        MOVHS   R6,#0                           ; definitely can't cache anything if out of range
        BHS     %FT90
        LDR     R14,[R8,R14,LSL #2]!            ; R14 = [R8] = previous chunk pointer
        B       %FT06

05
        LDR     R14,currentchunk
        LDR     R2,[R8,#trn_nchunks]
        CMP     R14,R2
        MOVHS   R6,#0                           ; definitely can't cache anything if out of range
        BHS     %FT90
        ADD     R8,R8,#trn_PixelsPtrs
        LDR     R14,[R8,R14,LSL #2]!            ; R14 = [R8] = previous chunk pointer (4-bpp)

;       ADDNE   R8,R8,#trn4_PixelsPtrs
;       ADDEQ   R8,R6,#hdr4_PixelsPtrs
;       LDR     R14,[R8,R14,LSL #2]!            ; R14 = [R8] = previous chunk pointer

06      TEQ     R14,#0
        BEQ     %FT16                           ; definitely recache if not present
        LDR     R2,switch_buffer                ; always recache if going to buffer
        TEQ     R2,#0                           ; since we need the outlines
        BNE     %FT16

        TEQ     R0,#PIX_ALLCHARS
        BNE     %FT11
        LDR     R2,[R14,#pix_flags]
        TST     R2,#pp_splitchunk
        MOVEQ   R6,R14                          ; correct format chunk - OK
        BEQ     %FT90
        PushP   "metricsptr",metricsptr
        BL      deletechunk                     ; get rid of old one
        CheckCache "deletechunk exit"
        PullP   "metricsptr",metricsptr
        BLVC    CachePixels
;;      CheckCache "CachePixels exit #2"
        B       %FT90

11      ADD     pixelsptr,R14,#pix_index
        Debug   cc,"setpixelsptr2: pixelsptr =",pixelsptr
        BL      getcharfromindex                ; EQ => inptr=PIX_UNCACHED
;;      CheckCache "getcharfromindex exit"
        SUBNE   R6,pixelsptr,#pix_index
        BNE     %FT17                           ; NE => inptr -> character header

16      BL      CachePixels                     ; exit: R6 = [R8] -> pixel chunk
;;      CheckCache "CachePixels exit #3"

17
      [ debugcpm
        BVC     %FT18
        Debug   cpm,"V flag set in setpixelsptr2!"
18
      ]
        BVS     %FT99

90      MOVS    pixelsptr,R6
        ADDNE   pixelsptr,R6,#pix_index         ; pixelsptr --> index of chunk read, or is 0
        Debug   cc,"setpixelsptr: metricsptr,pixelsptr =",metricsptr,pixelsptr
99
;;      CheckCache "setpixelsptr exit"

        PullP   "setpixelsptr: font header",R6
        PExit

; ............................................................................

; In    R7 -> font header
; Out   R8 -> pixo block for the 1-bpp bit
;       R7 relocated if required
;       R0 preserved unless error

readpixoblock_outlines Entry "R6"

      [ debugcc
        LDR     R14,[R7,#hdr_xsize]
        Debug   cc,"readpixoblock_outlines: R7, xsize =",R7,R14
      ]

        MOV     R6,R7
        MOV     R7,#hdr1_leafname
        BL      readpixoblock
        MOV     R7,R6                   ; R7 relocated if required

      [ debugcc
        LDR     R14,[R7,#hdr_xsize]
        Debug   cc,"readpixoblock_outlines2: R7, xsize =",R7,R14
      ]

        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R0 = character code required
;       R6 -> font header
;       R7 = hdr1/4_leafname
; Out   R8 -> new pixo block
;       R6 relocated
;       VC => R0 preserved
;       VS => error (cache full)

readpixoblock Entry "R0-R4,R7"                  ; stack accessed directly

        Debug   cc,"readpixoblock: R6,R7 =",R6,R7

        TEQ     R7,#hdr1_leafname
        ADDEQ   R8,R6,#hdr1_PixoPtr
        ADDNE   R8,R6,#hdr4_PixoPtr

        ADD     R7,R6,R7
        LDR     R3,[R7,#hdr4_nchunks-hdr4_leafname]      ; R3 = number of chunks
        LDR     R4,[R7,#hdr4_PixOffStart-hdr4_leafname]  ; R4 = file offset of chunk table
        CMP     R4,#0
        BNE     %FT20                           ; read from file

        LDRB    R14,[R7,#hdr4_leafname-hdr4_leafname]
        TEQ     R14,#'x'
        MOVEQ   R0,#8                           ; 8 chunks for x90y45 files
        BEQ     %FT55

        LDRB    R0,[R6,#hdr_masterfont]         ; must be a slave font here
        BL      getfontheaderptr                ; error if master font lost
        BVS     %FT90

        MOV     R14,R7                          ; R14 -> master font header
        LDR     R7,[SP,#5*4]
        ADD     R7,R6,R7                        ; R7 -> slave font + hdr1/4_leafname
        LDRB    R0,[R7,#hdr4_leafname-hdr4_leafname]
      [ debugbrk
        ASSERT  leaf_4bpp = 2
        ASSERT  leaf_fromdisc = 8
        CMP     R0,#leaf_4bpp
        BLO     %FT40
        CMP     R0,#leaf_fromdisc
        BLO     %FT50
40
        BreakPt "reservepixoblock_forslave: strange data type"
50
      ]
        TEQ     R0,#leaf_4bpp
        LDREQ   R0,[R14,#hdr4_nchunks]
        LDRNE   R0,[R14,#hdr1_nchunks]
      [ debugbrk
        CMP     R0,#0
        BreakPt "reservepixoblock_forslave: master hdr_nchunks zero",EQ
        LDR     R14,[R7,#hdr1_nchunks-hdr1_leafname]
        CMP     R14,#0
        BreakPt "reservepixoblock_forslave: hdr_nchunks non-zero",NE
      ]
55      STR     R0,[R7,#hdr1_nchunks-hdr1_leafname]

        RSB     R0,R0,#0                        ; In: R0 -ve => no file offsets required
        BL      reservepixoblock                ; In: R6 -> font header, R7 -> font header + hdr1/4_leafname
        MOVVC   R8,R0
90
        STRVS   R0,[SP]
        EXIT

; Now we need to allocate a pixo block of the right size to contain the chunk file offsets and pointers
; We'll also need to open the file handle

20      ;SUB     R7,R7,R6                        ; convert to offset now so it's relocated correctly

        MOV     R0,R3
        BL      reservepixoblock                ; Out: [R0]->pixo block, R6 relocated
        MOVVC   R8,R0                           ; R8 -> new pixo block

        SUB     R7,R7,R6

      [ debugcc
        LDR     R14,[R6,#hdr_xsize]
        Debug   cc,"Before openpixels: font header, xsize, R2, R7",R6,R14,R2,R7
      ]

        TEQ     R7,#hdr1_leafname
        MOVEQ   R2,#hdr1_pixelshandle
        MOVNE   R2,#hdr4_pixelshandle
        ADD     R7,R6,R7
        BL      openpixels_R2R7                 ; Out: R1 = file handle
        BVS     %BT90

      [ debugcc
        LDR     R14,[R6,#hdr_xsize]
        Debug   cc,"After openpixels: font header, xsize, R2, R7",R6,R14,R2,R7
      ]

;       ADD     R2,R7,#hdr4_PixOffsets-hdr4_leafname    ; R2 -> PixOffsets array in font header
        ADD     R2,R8,#pixo_pointers
        ADD     R2,R2,R3,LSL #2                         ; R2 -> pixo_offsets array in pixo block
        MOV     R3,R3,LSL #2
        ADD     R3,R3,#4                                ; R3 = size (4*nchunks+4 bytes)
        MOV     R0,#OSGBPB_ReadFromGiven
        BL      xos_gbpb
        BL      tidyfiles_R7
        B       %BT90

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R0 = number of chunks in font (-ve if we don't need file offsets)
;       R6 -> font header
;       R7 -> font header + hdr1/4_leafname
; Out   R0 -> new block (initialised with nchunks and pointers set to 0)
;       R6,R7 relocated
;       [R6,#hdr1/4_PixoPtr] -> new block as well

reservepixoblock Entry "R3,R8"

        PushP   "reservepixoblock: R6",R6

        SUB     R7,R7,R6
        TEQ     R7,#hdr4_leafname
        ADDEQ   R8,R6,#hdr4_PixoPtr
        ADDNE   R8,R6,#hdr1_PixoPtr

        SUBS    R3,R0,#0
        RSBLT   R3,R3,#0                  ; -ve => no file offsets required (for slave font)
        MOVLT   R6,R3,LSL #2
        ADDLT   R6,R6,#pixo_pointers
        MOVGE   R6,R3,LSL #3              ; 8 bytes per chunks (file offset and pointer)
        ADDGE   R6,R6,#pixo_pointers + 4  ; allow for an extra 4 bytes (there are n+1 file offsets)

        Debug   cc,"pixo block nchunks, size",R3,R6

        BL      reservecache
        BVS     %FT90

        MakeLink R6,R8                  ; link block in immediately

        LDR     R14,[R6,#std_size]      ; lock pixo blocks permanently
        ORR     R14,R14,#size_claimed :OR: size_locked
        STR     R14,[R6,#std_size]

        ADD     R0,R6,#pixo_pointers

        Debug   cc,"pixo block addr,pointers,nchunks",R6,R0,R3

        MOV     R14,#0
01      STR     R14,[R0],#4             ; initialise the pointer array
        SUBS    R3,R3,#1
        BNE     %BT01

        MOV     R0,R6                   ; R0 -> new block (initialised except for file offsets)
90
        PullP   "reservepixoblock:restoring R6",R6

        ADD     R7,R6,R7                ; restore R7

        EXIT

;;----------------------------------------------------------------------------
;; CachePixels
;; Entry:  R0 = character code required, or PIX_ALLCHARS (whole chunk)
;;         [currentchunk] = chunk number required (0..nchunks-1)
;;         [antialiasx/y] = subpixel positions (ditto)
;;         R6 -> font header
;;         R7 = #hdr1/4_leafname (GetPixelsHeader already called)
;;         R8 -> link to contain address of new chunk
;;         R10 = metricsptr -> metrics data (or 0 if not decided)
;;         [transformptr] -> current transform
;; Exit:   R6 -> pixel chunk
;;         [R8] updated unless direct outlines being returned (contained in master font)
;;         [charflags] = type of data pointed to by R6
;;         R10 = metricsptr relocated if necessary
;;         [currentchar], [currentchunk] may be updated if loading from outlines direct
;;----------------------------------------------------------------------------

        ASSERT  pixelsptr  = R9
        ASSERT  metricsptr = R10

CachePixels Entry "R0-R4,cacheptr"

        CheckCache "CachePixels entry"

        PushP   "Pixels: metricsptr",metricsptr
        PushP   "Pixels: link ptr",R8

      [ debugcc
        LDR     R14,[R8]
        Debug   cc,"CachePixels: R0,R6,R7,R8,[R8] =",R0,R6,R7,R8,R14
      ]

; R7 = #hdr1/4_leafname - slave: 1-bpp/4-bpp, master: outlines/4-bpp

      [ debugbrk
        TEQ     R7,#hdr1_leafname
        TEQNE   R7,#hdr4_leafname
        BreakPt "CachePixels: incorrect R7",NE
      ]

        TEQ     R7,#hdr1_leafname
        MOVEQ   R14,#chf_1bpp
        MOVNE   R14,#0
        STRB    R14,charflags           ; parameter to cachebitmaps

        LDR     R4,switch_buffer        ; if outputting to buffer,
        TEQ     R4,#0                   ; try not to use bitmaps!
        MOVNE   R4,#leaf_outlines_direct
        BNE     %FT01                   ; (NE => R4 > &100) - no need to lock transformptr

        LDR     R1,transformptr
        TEQ     R1,#0
        BNE     %FT02

        Debug   trn,"Calling CacheChunk via Font Header",R6

        LDRB    R4,[R6,R7]              ; get flags from font header if no transform
01      BL      CacheChunk

        STRVS   R0,[R13]

        CheckCache "cachepixels untransformed exit"

        EXIT

; cache chunk via transformptr - lock transform block first

02  ;   TEQ     R7,#hdr4_leafname
    ;   LDREQB  R4,[R1,#trn4_leafname]
    ;   LDRNEB  R4,[R1,#trn1_leafname]
        LDRB    R4,[R1,#trn_leafname]

        Debug   trn,"Calling CacheChunk via transform block",R1

        LDR     R14,[R1,#std_size]
        ORR     R14,R14,#size_locked
        STR     R14,[R1,#std_size]

        BL      CacheChunk              ; returns R6 -> chunk containing char (chunk younger than char)
        STRVS   R0,[R13]
        LDR     R1,transformptr         ; relocated if nec.

        LDR     R14,[R1,#std_size]
        BIC     R14,R14,#size_locked
        STR     R14,[R1,#std_size]

        MarkAge R1, R2,R3               ; do this even if error (ensure parent younger than child)

        CheckCache "cachepixels transformed exit"

        EXIT

;.............................................................................

; In    R0 = character code or PIX_ALLCHARS
;       R4 = first character of 'leafname'
;       R6 -> font header (used to obtain master font handle)
;       R8 -> pointer which will contain chunk address (in pixo block or transform block)
;       [charflags] :AND: chf_1bpp => 1-bpp or 4-bpp
;       [currentchunk] = chunk number (for loading outlines)
;       [rendermatrix] -> render matrix
; Out   [R8] = R6 -> new pixel chunk
;       [charflags] = type of data pointed to by R6
;       R10 = metricsptr relocated if necessary

; Contents of relevant leafname => which type of data we have:
;   leaf_none        => none (try using the other type)
;   leaf_scanfontdir => not decided (call GetPixelsHeader)
;   leaf_outlines_direct => return pointer to master font outlines
;   leaf_outlines_00 => scale from master font outlines
;   leaf_outlines_01 => scale from master font outlines (h-subpixels)
;   leaf_outlines_10 => scale from master font outlines (v-subpixels)
;   leaf_outlines_11 => scale from master font outlines (hv-subpixels)
;   leaf_4bpp        => scale from master font 4-bpp bitmaps
;     f9999x9999     => load 4-bpp bitmap data directly
;     b9999x9999     => load 1-bpp bitmap data directly
;     x90y45         => load old-style 4-bpp bitmap data directly (no scaling)
;     Outlines       => load outline data directly

CacheChunk Entry "R0-R4,cacheptr"

        TEQ     R4,#"f"                 ; load from file directly
        TEQNE   R4,#"b"
        TEQNE   R4,#"O"
        BEQ     cache_newchunk
        TEQ     R4,#"x"                 ; load old-style chunk (nasty)
        BEQ     cache_x90y45            ; (no scaling involved here)

        LDRB    R0,[R6,#hdr_masterfont]
        BL      getfontheaderptr        ; R7 -> master font header
        BVS     exitpix

        LDR     R0,[sp]                 ;    R0 = character code required
                                        ; or R0 = PIX_ALLCHARS, [currentchunk] = chunk required

        LDR     R14,switch_buffer       ; always use outlines when
        TEQ     R14,#0                  ; outputting to a buffer
        BNE     cache_fromoutlines_direct

        TEQ     R4,#leaf_4bpp
        BEQ     cache_from4bpp          ; scale from master 4-bpp bitmaps

        TEQ     R4,#leaf_outlines_direct
        BEQ     cache_fromoutlines_direct  ; return master outlines

      [ debugbrk
        CMP     R4,#leaf_fromdisc
        BLT     %FT00
        BreakPt "CachePixels: invalid leafname"
00
      ]

        B       cache_fromoutlines      ; scale from outlines

;.............................................................................

; load new format chunk from disc
; In    [currentchunk] = chunk number (0..nchunks-1)
;       R6 -> font header
;       R7 = #hdr1/4_leafname
;       R8 -> link -> chunk
; Out   R6 -> chunk
;       R8 may be relocated

cache_newchunk
        LDR     R0,currentchunk
        BL      readnewchunk            ; R6 --> data block
        B       exitpix

;.............................................................................

; Load old-style 'chunk' from x90y45 file
; We must search the index to see which parts of the file are relevant
; In    [currentchunk] = chunk number (0..nchunks-1)
;       R6 -> font header
;       R8 -> link for new pixel chunk

cache_x90y45

        BL      openpixels4             ; must be 4-bpp section
        BVS     exitpix

        PushP   "Saving font header ptr",R6     ; needed to close file

; get offset/size of character index in file

        LDR     R4,[R6,#hdr_PixOffset]
        LDR     R14,[R6,#hdr_PixSize]
        STR     R4,pixfileoffset        ; save for later
        STR     R14,pixfilesize         ; used in findoffset
        Debug   cc,"Old-style pixels handle,fileoffset,size =",R1,R4,R14

; allocate a small block for the new index first
; this is in case the cache expands when loading further blocks

        MOV     R6,#pix_data+&200+32    ; room for both indexes + 32*charflags
        BL      reservecache            ; R6 --> new block
        BVS     exitpix_closefile

        CheckCache_disable              ; this block is in fact invalid, but it doesn't matter yet

        MakeLink R6,R8                  ; link into cache structure
        LDR     R14,[R6,#std_size]
        ORR     R14,R14,#size_locked    ; lock block
        STR     R14,[R6,#std_size]
        MOV     R14,#pp_incache         ; no subpixel scaling, block is in cache (not ROM)
        STR     R14,[R6,#pix_flags]     ; no subpixel scaling

; now cache the index from the file

        LDR     R4,pixfileoffset
        MOV     R3,#fpix_data-fpix_index        ; read index (at end of cache)
        BL      cacheblock                      ; R6,R8 updated if nec.
        BVS     exitpix_closefile_deleteR6

; look for offsets of start & end of chunk (in original table)
; cacheptr -> table (256 * 2-byte offsets, 0 => no char)
; In:   [currentchunk] = chunk number (0..nchunks-1)

        LDR     R0,currentchunk
        Debug   cc,"Load x90y45 chunk",R0
        BL      findoffset              ; R3 --> start of chunk
        ADD     R0,R0,#1                ; find 1st char in next chunk
        MOV     R4,R3                   ; R4 = offset (non-zero)
        STR     R4,scaleoffset          ; for correcting index

        BL      findoffset
        SUBS    R3,R3,R4                     ; R3 = length
        BEQ     exitpix_closefile_deleteR6   ; if 0, return R6=0

        LDR     R14,pixfileoffset       ; make R4 absolute
        ADD     R4,R4,R14
        SUB     R0,R0,#1                ; restore R0

        Debug   cc,"Load from offset, size",R4,R3

; Copy relevant portion of disc-file index into new block

        Push    "R3,R4"

        ADD     cacheptr,cacheptr,R0,LSL #5+1   ; start of wanted section
        ADD     pixelsptr,R6,#pix_index
        Debuga  cc,"Copying index from",cacheptr
        Debug   cc," to",pixelsptr
        MOV     R2,#32                  ; counter
        LDR     R4,scaleoffset
03
        LDRB    R14,[cacheptr],#1       ; get 2-byte element
        LDRB    R3,[cacheptr],#1
        ORR     R3,R14,R3,LSL #8
        SUB     R3,R3,R4                ; R3 = offset relative to block start
        STR     R3,[pixelsptr],#4       ; R3 < 0 => no char
        SUBS    R2,R2,#1
        BNE     %BT03

        Pull    "R3,R4"

; now read in the char data, and copy it down, relocating pointers etc.
; NB: locked output index block may move here (R6 updated)

        BL      cacheblock              ; read char data into top of cache
        BVS     exitpix_closefile_deleteR6

        Debuga  cc,"Copying pixel data at",cacheptr
        Debug   cc," down to block at",R6

        MOV     R2,#0                   ; R2 = char index (0..31)
        MOV     R4,#-1                  ; R4 = address of previous character
        ADD     pixelsptr,R6,#pix_data  ; pixelsptr -> output data
        ADD     R6,R6,#pix_index        ; R6 -> output index

01      LDR     R5,[R6,R2,LSL #2]       ; R5 = char offset - scaleoffset
        CMP     R5,#0                   ; assume scaleoffset > 0
        MOVLT   R14,#0
        BLT     %FT05

        ADD     R5,cacheptr,R5          ; R5 -> start of this character
        BL      copychardown            ; R4 -> start of previous character
        SUB     R14,pixelsptr,R6        ; where current character WILL go

05      STR     R14,[R6,R2,LSL #2]

02      ADD     R2,R2,#1
        CMP     R2,#32
        BCC     %BT01

        LDR     R5,fontcacheend         ; copy last char (if any)
        BL      copychardown

        SUB     R6,R6,#pix_index        ; R6 -> start of block
        SUB     R14,pixelsptr,R6
        ADD     R14,R14,#3              ; word-align
        BIC     R14,R14,#3

        SetBlockSize R6,R14,R5          ; R6 -> last block allocated, R14 = new size, R5 corrupted

exitpix_closefile
        Push    "R6"
        PullP   "Restoring font header pointer",R6
        BL      closepixels             ; preserves error state
        Pull    "R6"

exitpix

        PullP   "Pixels: restoring link ptr",R8
        BVS     %FT01

        TST     R6,#1                   ; if this bit set, don't store value
        BIC     R6,R6,#1                ; (set if outlines returned)
      [ debugbrk
        SavePSR LR
        Push    "LR"
        LDREQ   R14,[R8]                ; don't overwrite pointer
        MOVNE   R14,#0
        TEQ     R14,#0
        TEQNE   R14,R6                  ; OK if it's the same one!
        BreakPt "Pixels: Overwriting pointer",NE
        Pull    "LR"
        RestPSR LR,,f
      ]
        MakeLink R6,R8, EQ              ; if no error, [R8] --> R6 (if pixels)
01
        PullP   "metricsptr:",metricsptr

        CheckCache_enable               ; can't actually check cache here cos transform block isn't younger

        DebugE  cc,"Error at exitpix "

        STRVS   R0,[sp]
        EXIT

; come here if an error occurs after the index block is allocated

exitpix_closefile_deleteR6
        Debug   cc,"Deleting pixel block at, link",R6,R8
        BL      deleteblock             ; preserves error state
        MOV     R6,#0
        B       exitpix_closefile

;.............................................................................

; In    R0 = chunk number
;       cacheptr --> index
; Out   R3 = offset in file of 1st defined char

findoffset Entry "R2,cacheptr"

        ADD     cacheptr,cacheptr,R0,LSL #5+1   ; cacheptr --> start of chunk
        MOV     R2,#256
        SUBS    R2,R2,R0,LSL #5                 ; counter (till end of index)
        BLE     %FT03

01      LDRB    R14,[cacheptr],#1
        LDRB    R3,[cacheptr],#1
        ORRS    R3,R14,R3,LSL #8                ; R3 = offset
        BNE     %FT02
        SUBS    R2,R2,#1
        BNE     %BT01

03      LDR     R3,pixfilesize                  ; maximum offset within chunk
02
        Debug   cc,"Char offset in file chunk R0 is R3:",R0,R3

        EXIT

;.............................................................................

; In    R4 -> start of char to copy (-1 => nothing to do)
;       R5 -> start of next char
;       pixelsptr -> destination
; Out   data copied from [R4] to [pixelsptr], both updated

copychardown    ROUT

        Debuga  cc,"Copy char from start",R4
        Debuga  cc," end",R5
        Debug   cc," to",pixelsptr

        CMP     R4,#-1
        MOVEQ   R4,R5                   ; R4 -> start of next char
        MOVEQ   PC,LR

        Entry   ""

        MOV     R14,#0                  ; put in char flags (4-bpp)
        STRB    R14,[pixelsptr],#1
01
        CMP     R4,R5
        LDRLOB  R14,[R4],#1
        STRLOB  R14,[pixelsptr],#1
        BLO     %BT01                   ; R4 -> start of next char

        EXIT                            ; must preserve flags

;.............................................................................

; Scale master font's 4-bpp bitmaps according to x/yscale
;       R0 = character code required, or PIX_ALLCHARS => load whole chunk
;       [currentchunk] = chunk number required (0..nchunks-1)
;       R6 -> slave font header
;       R7 -> master font header

cache_from4bpp  ROUT

        PushP   "cache_from4bpp: slave font header",R6
        MOV     R6,R7
        MOV     R7,#hdr4_leafname       ; potentially recursive:
        BL      setpixelsptr2           ; pixelsptr -> master 4bpp chunk
        PullP   "cache_from4bpp: slave font header",R6
        BVS     exitpix

        CMP     pixelsptr,#0            ; slave block is null if master is!
        MOVEQ   R6,#0
        BEQ     exitpix

        LDR     R1,[R6,#hdr_Charlist]   ; R1 --> list of chars to do
        PushP   "Charlist",R1
        STR     R1,charlistptr          ; for computesize

        BL      setup_xsysxfyf          ; set up xf/yf, xs/ys
        BVS     %FT55

        MOV     R14,#-1                 ; must do this after finding master
        STR     R14,incache
        MOV     R14,#pix_data-pix_index         ; set up offset
        STR     R14,scaleoffset
        ADD     cacheptr,pixelsptr,R14  ; cacheptr -> data
        BL      computesize             ; R6 = size required
        SUB     R1,pixelsptr,#pix_index ; R1 --> master pixels block

      [ debugsc3
        STR     R6,debugloc
        B       %FT00
debugloc  DCD   0
00
        Debuga  sc3,"xs/ys/xf/yf/est/size",#xscale,#yscale,#xfactor,#yfactor,R6
      ]

        BL      lockblock               ; lock block (R1) if in cache
        PushP   "Master pixel chunk",R1

        BL      reservecache

        PullP   "Master pixel chunk",R1
        BL      unlockblock             ; unlock block (R1) if in cache

        ADDVC   cacheptr,R1,#pix_index  ; cacheptr -> input index
55
        PullP   "Charlist",R1
        BVS     exitpix                 ; no pixels block yet

        PushP   "Pixels block",R6

        MOV     R14,#size_locked        ; lock block (will be unlocked later)
        STR     R14,[R6,#std_size]
        MOV     R14,#pp_incache         ; mark block as being in cache (not ROM)
        STR     R14,[R6,#pix_flags]     ; only 1 char position

; copy index into new block

        ADD     R3,R6,#pix_index        ; R3 -> output index
        MOV     R2,#32                  ; R2 = counter

01      LDR     R14,[cacheptr],#4       ; leave cacheptr --> data
        STR     R14,[R3],#4
        SUBS    R2,R2,#1
        BNE     %BT01

        Debug   cc,"Scaling from master: cacheptr =",cacheptr

        LDR     R14,fontcacheend
        MOV     R14,R14,ASL #1          ; (convert to nibble ptr)
        STR     R14,targetword

        BL      ScalePixels             ; R1 --> Charlist to do

        PullP   "Pixels block",R6

      [ debugsc3
        LDR     R14,[R6,#std_size]
        Debug   sc3,"",R14
        LDR     R2,debugloc
        CMP     R14,R2
        BEQ     %FT02
        SWI     XOS_WriteI+7
        SWI     XOS_ReadC
02
      ]

        BVC     exitpix                 ; common exit

        DiscardBlock R6, R2,R14         ; if error, delete block

        B       exitpix

;.............................................................................

; Scale from outline data in master font
; In    [charflags] :AND: chf_1bpp already set up in CachePixels
;       R4 = leaf_outlines_xx (00..11), where bits 0..1 = subpixel flags
;       [subpixelflags] set up for cachebitmaps
;       R0 = character code required
;       [antialiasx/y] = subpixel offsets

cache_fromoutlines ROUT
        ASSERT  (leaf_outlines_00 :AND: (pp_4xposns :OR: pp_4yposns)) = 0

        AND     R4,R4,#pp_4xposns :OR: pp_4yposns
        STRB    R4,subpixelflags        ; for cachebitmaps
        BL      cachebitmaps            ; R6 -> bitmaps, scaled from outlines
        B       exitpix

;.............................................................................

; Return master outlines directly
; NB: cacheoutlines sets up design units -> pixels transformation
; Since pixels block is not created, this routine is called for each access

; In    R0 = external character code required
;       [currentchunk] = chunk required
;       R6 -> font header
; Out   [currentchar] = internal character code required (for SetPixelsPtrs)
;       VC => [currentchunk] = 0 (ensure SetPixelsPtr can't go straight to outline chunk next time)
;       R6 = outline chunk pointer OR 1

cache_fromoutlines_direct ROUT

        Debug   th,"cache_fromoutlines_direct: font",R6

01      LDRB    R14,charflags           ; ensure paintchar knows format
        ORR     R14,R14,#chf_outlines :OR: chf_1bpp
        STRB    R14,charflags           ; must be 1-bpp if drawing direct

        MOV     R4,#0                   ; no time offset (needed directly)
        BL      cacheoutlines           ; R6 -> outlines
        BVS     exitpix

        TEQ     R6,#0
        BEQ     justunlockem

        PushP   "saving master font header ptr",R7

; this chunk and any it depends on are locked at this point

        PushP   "saving outline chunk ptr",R6

        MOV     R6,#scratchsize         ; allocate scratchblock at top of cache
        BL      reservecache2

        GetReservedBlockAddr R14,,VC    ; R14 = address of new block
        STRVC   R14,scratchblock        ; used by drawchar

        PullP   "restoring outline chunk ptr",R1
        ORR     R6,R1,#1                ; don't store in [R8]

        PullP   "restoring master font header ptr",R7
justunlockem
        BL      unlockoutlines          ; R7 -> master font header

        B       exitpix

;.............................................................................

; In    pixelsptr -> index to char block
;       cacheptr -> char data
;       [scaleoffset] = amount to subtract from char offset
;       [incache] = 0 / 1 (data from disc / cache)
;       [charlistptr] -> char list (for RAM-scaling)
;       x/y factor, x/y scale = relative sizes of old/new fonts
; Out   R6 = size of block required

computesize Entry "R1-R5,cacheptr"

        LDR     R14,scaleoffset
        SUB     cacheptr,cacheptr,R14   ; cacheptr+offset -> char
        MOV     R5,#31                  ; R5 = counter
        MOV     R6,#pix_data            ; R6 = total block size so far
01
        Push    "R6"
        LDR     R0,[pixelsptr,R5,LSL #2]
        TEQ     R0,#0
        ASSERT  counter = R6
        MOVNE   R6,R5                   ; R6 = char index within chunk
        BLNE    checkchar               ; for RAM-scaling
        Pull    "R6"
        BEQ     %FT02
        ADD     R0,cacheptr,R0          ; R0 -> char header

; if [incache] set, the char header is preceded by a flag byte

        LDR     R1,incache
        TEQ     R1,#0
        LDRNEB  R1,[R0],#1
        BL      readbbox                ; R1-R4 = unmunged coords
        ADD     R3,R1,R3
        ADD     R4,R2,R4                ; x,y,w,h -> x0,y0,x1,y1
        BL      computeboxR1R4          ; R1-R4 = new coords
        SUB     R3,R3,R1
        SUB     R4,R4,R2                ; x0,y0,x1,y1 -> x,y,w,h

; output size must be 8-bit, or ScaleChar can't cope

        ORR     R14,R3,R4
        MOVS    R14,R14,LSR #8          ; anything other than bits 0..7 set?
        BNE     err_fonttoobig

        MUL     R14,R3,R4               ; R14 = no of pixels in image
        ADD     R14,R14,#1
        ADD     R6,R6,R14,LSR #1        ; round up to bytes (not word-aligned)
        ADD     R6,R6,#chr_data         ; all output headers must be 5 bytes

02      SUBS    R5,R5,#1
        BPL     %BT01

        Align   R6                      ; word-align at end of chunk

        EXIT

err_fonttoobig
        PullEnv
        ADR     R0,ErrorBlock_Font64K
        B       MyGenerateError
        MakeErrorBlock Font64K

;.............................................................................

; Set up scale factors from font header, and bodge to avoid overflow
; Entry:  R6 --> font header

setup_xsysxfyf Entry "R0,R1,R7"

        LDR     R14,[R6,#hdr_xscale]    ; set up scaling parameters
        STR     R14,xscale
        LDR     R14,[R6,#hdr_yscale]
        STR     R14,yscale

        LDRB    R0,[R6,#hdr_masterfont]
        BL      getfontheaderptr        ; shouldn't give an error
        DebugE  err,"Error in setup_xsysxfyf:"
        STRVS   R0,[sp]
        EXIT    VS

        LDR     R14,[R7,#hdr_xscale]
        STR     R14,xfactor
        LDR     R14,[R7,#hdr_yscale]
        STR     R14,yfactor

        Debug   me,"setup_xsysxfyf: xscale, yscale, xfactor, yfactor",#xscale,#yscale,#xfactor,#yfactor

        LDR     R0,xfactor
        LDR     R1,xscale

01      CMP     R0,#maxfactor           ; (ho ho)
        MOVCS   R0,R0,ASR #1
        MOVCS   R1,R1,ASR #1
        BCS     %BT01

02      STR     R0,xfactor
        STR     R1,xscale
        MOVS    R0,R0,ASR #1            ; shift down to bottom
        MOVCCS  R1,R1,ASR #1
        BCC     %BT02

        LDR     R0,yfactor
        LDR     R1,yscale

01      CMP     R0,#maxfactor           ; (ho ho)
        MOVCS   R0,R0,ASR #1
        MOVCS   R1,R1,ASR #1
        BCS     %BT01

02      STR     R0,yfactor
        STR     R1,yscale
        MOVS    R0,R0,ASR #1            ; shift down to bottom
        MOVCCS  R1,R1,ASR #1
        BCC     %BT02

        Debug   th,"x/yscale, x/yfactor =",#xscale,#yscale,#xfactor,#yfactor

        EXIT

;.............................................................................

; Do we need to process this character?
;
; In    R6 = counter = character required (within 32-char chunk)
;       [currentchunk] = chunk number (0..nchunks-1)
;       [charlistptr] --> block containing string
; Out   Z unset --> use char, else forget it

        ASSERT  counter = R6

checkchar Entry "R1,R2,counter"

        LDR     R2,charlistptr
        TEQ     R2,#0
        BEQ     %FT99                   ; OK - no string specified

        LDR     R14,currentchunk
        ADD     counter,counter,R14,ASL #5
        ADD     R2,R2,#std_end

        Debug   cc,"Check char: counter, R2 =",counter,R2

01      LDRB    R14,[R2],#1
        CMP     R14,#32
        BCC     %FT99                   ; char not present
        TEQ     R14,counter
        BNE     %BT01

99
        TOGPSR  Z_bit,R14                       ; reverse sense of Z flag

        EXIT

;;----------------------------------------------------------------------------
;; ScalePixels
;; Entry:  R6 --> chunk containing index
;;         R1 --> block containing Charlist (if present)
;;         cacheptr --> data (at end of cache) - excluding index
;;         xscale, yscale = new size of font
;;         xfactor, yfactor = old size of font
;; Exit :  [R6+pix_data] contains data scaled and copied down
;;         No uncacheing can take place!
;;----------------------------------------------------------------------------

ScalePixels Entry "R0-R11"

        PushP   "Scaling pixels ...",R6

        STR     R1,charlistptr                  ; used later

        ADD     pixelsptr,R6,#pix_index         ; index
        ADD     pixelboxptr,R6,#pix_data        ; output ptr

        Debug   sc,"Scaling: index,in,out =",pixelsptr,cacheptr,pixelboxptr

; work out the area of an output pixel

        LDR     R0,xfactor                      ; calculate xf*yf
        LDR     R1,yfactor
        MUL     R3,R0,R1
        STR     R3,xftimesyf                    ; for working out final output

; scan the index, scaling any relevant characters

        MOV     counter,#0                      ; pointer to output array
copylp6
        LDR     R0,[pixelsptr,counter,ASL #2]
        MOVS    R1,R0
        BLNE    checkchar                       ; see if char is in string
        MOVEQ   R1,#0
        SUBNE   R1,pixelboxptr,pixelsptr        ; offset to output data
        STR     R1,[pixelsptr,counter,ASL #2]

        BLNE    ScaleChar                       ; scale if there is one
        BVS     %FT99

        ADD     counter,counter,#1
        CMP     counter,#32
        BCC     copylp6

        Align   pixelboxptr             ; chars themselves not aligned

; tidy up free space pointer

99
        PullP   "Scaled pixels",R6

        ASSERT  pixelboxptr<>R6

        DiscardOrSetBlockEnd R6, pixelboxptr, R1,R14

        Debug   cc,"Scaled pixel block size =",R1

        STRVS   R0,[sp]
        EXIT

;;----------------------------------------------------------------------------
;; ScaleChar - scale the definition of a character
;; Entry:  R0 = offset to input data
;;         pixelboxptr -> output data
;;         [scaleoffset] = correction to make to R0
;; Keep:   counter, pixelsptr, cacheptr
;; Exit:   pixelboxptr --> free space (after char)
;;----------------------------------------------------------------------------

fcolbit         *       &80000000
frowbit         *       &40000000

ScaleChar Entry "pixelboxptr,counter,pixelsptr,cacheptr"

        LDR     R14,scaleoffset
        SUB     R0,R0,R14
        ADD     R0,cacheptr,R0          ; R0 -> char header

        Debug   sc,"counter,inptr,outptr =",counter,R0,pixelboxptr

        LDR     R1,incache
        TEQ     R1,#0
        LDRNEB  R1,[R0],#1
        BL      readbbox                ; R1-R4 = x,y,w,h (input)
        ADR     R14,pboxX
        STMIA   R14,{R1-R4}
        MOV     inpixelboxptr,R0        ; inpixelboxptr -> char defn
        Debug   sc,"Old char box =",#pboxX,#pboxY,#pboxW,#pboxH

; set up character origin and initial counter values

        MOV     R14,#0
        STRB    R14,[pixelboxptr,#chr_flagbyte]

        LDR     R1,xfactor                      ; scaling-down factor
        LDR     R2,xscale                       ; scaling-up factor
        LDR     R0,pboxX                        ; x0 offset
        BL      getorigin
        STRB    R3,[pixelboxptr,#chr_boxX]      ; output x0
        MOV     zf,R4                           ; initial zf

        LDR     R1,yfactor                      ; scaling-down factor
        LDR     R2,yscale                       ; scaling-up factor
        LDR     R0,pboxY                        ; y0 offset
        BL      getorigin
        STRB    R3,[pixelboxptr,#chr_boxY]      ; output y0
        MOV     zyf,R4                          ; initial zyf

        Debug   sc2,"Initial zf,zyf =",zf,zyf

; now get down to the nitty-gritty

        ADD     Ra,pixelboxptr,#chr_data
        MOV     Ra,Ra,ASL #1                    ; for nibble access
        STR     Ra,outputcell
        MOV     inputcell,inpixelboxptr,ASL #1  ; for nibble access

        LDR     zys,yscale
        LDR     ycount,pboxH
        BIC     flags,flags,#&FF                ; outycount := 0
nextrow
        ORR     flags,flags,#fcolbit            ; firstcolumn := true
        LDR     zs,xscale
        LDR     xcount,pboxW
        BIC     flags,flags,#&FF00              ; outxcount := 0
        Push    "zf"                            ; initial zf value
nextcolumn
        MOV     Ra,#0
        STR     Ra,TOTAL
        ORR     flags,flags,#frowbit            ; firstrow := true
        Push    "ycount,zys,zyf"
mainloop1
        MOV     Ra,#0                           ; sub-pixel total
        STR     Ra,XTOTAL
        Push    "inputcell,xcount,zs,zf"
mainloop2
        CMP     zs,zf
        MOVCC   z,zs
        MOVCS   z,zf

        Debug   sc2,"z =",z

; add weighted input cell to row total

        MOVS    R14,inputcell,LSR #1            ; get pixel address
        LDRB    R14,[R14]
        ANDCC   R14,R14,#&0F                    ; low-order pixel
        MOVCS   R14,R14,LSR #4                  ; high-order pixel

        LDR     Ra,XTOTAL
        MLA     Ra,z,R14,Ra
        STR     Ra,XTOTAL

        SUBS    zs,zs,z
        LDREQ   zs,xscale
        ADDEQ   inputcell,inputcell,#1          ; go right 1 column
        SUBEQ   xcount,xcount,#1
        SUBS    zf,zf,z
        TEQNE   xcount,#0
        BNE     mainloop2

        TST     flags,#frowbit                  ; if first row,
        BICNE   flags,flags,#frowbit
        ADRNE   R14,nextcoldata
        STMNEIA R14,{inputcell,zs,xcount}       ; save for later.

      [ debugsc2
        BEQ     nodebug1
        Debug   sc2,"Next column: (inputcell,zs,xcount) =",inputcell,zs,xcount
nodebug1
      ]

; add row total into cell total

        Pull    "inputcell,xcount,zs,zf"

        CMP     zys,zyf
        MOVCC   z,zys
        MOVCS   z,zyf

        Debug   sc2,"zy =",z

        LDR     Ra,TOTAL
        LDR     R14,XTOTAL
        MLA     Ra,R14,z,Ra
        STR     Ra,TOTAL

        SUBS    zys,zys,z
        LDREQ   zys,yscale
        LDREQ   R14,pboxW
        ADDEQ   inputcell,inputcell,R14         ; go up 1 row
        SUBEQ   ycount,ycount,#1
        SUBS    zyf,zyf,z
        CMPNE   ycount,#0
        BNE     mainloop1

; now divide total for this cell by (xf*yf)

        LDR     Ra,TOTAL
        LDR     Rb,xftimesyf
        ADD     Ra,Ra,Rb,ASR #1                         ; round to nearest
        DivRem  Rc,Ra,Rb,R14,norem
        CMP     Rc,#16
        MOVCS   Rc,#15                                  ; 4-bit answer

        Debug   sc2,"Output before/after:",#TOTAL,Rc

        LDR     Ra,outputcell
        MOVS    R14,Ra,LSR #1           ; get pixel value
        LDRCSB  Rb,[R14]
        ORRCS   Rc,Rb,Rc,ASL #4
        STRB    Rc,[R14]                ; store new answer

        Debug   sc2,"Output cell ptr/value:",Ra,Rc

        ADD     Ra,Ra,#1
        LDR     R14,targetword
        TEQ     R14,#0
        MOVEQ   R14,inputcell
        CMP     Ra,R14                  ; cache full if overlap
        BCS     err_cachefull
        STR     Ra,outputcell

; if first column, save data for nextrow

        TST     flags,#fcolbit                  ; if first column,
        BICNE   flags,flags,#fcolbit
        ADRNE   R14,nextrowdata
        STMNEIA R14,{inputcell,zys,ycount}      ; save for later.

      [ debugsc2
        BEQ     %FT01
        Debug   sc2,"Nextrow: (inputcell,zys,ycount) =",inputcell,zys,ycount
01
      ]

; move right one output pixel

        Pull    "ycount,zys,zyf"
        ADR     Ra,nextcoldata
        LDMIA   Ra,{inputcell,zs,xcount}
        LDR     zf,xfactor                              ; entire width
        ADD     flags,flags,#&100                       ; outxcount += 1
        CMP     xcount,#0
        BNE     nextcolumn

        Pull    "zf"
        ADR     R14,nextrowdata
        LDMIA   R14,{inputcell,zys,ycount}
        LDR     zyf,yfactor                             ; entire height
        ADD     flags,flags,#1                          ; outycount += 1
        CMP     ycount,#0
        BNE     nextrow

        Pull    "$Proc_RegList"

        Debug   sc2,"flags (outxcount/outycount) =",flags

        MOV     Ra,flags,LSR #8                         ; outxcount
        STRB    Ra,[pixelboxptr,#chr_boxW]
        STRB    flags,[pixelboxptr,#chr_boxH]           ; outycount

      [ debugsc
        LDRB    R14,[pixelboxptr,#chr_boxX]
        Debuga  sc,"New char box =",R14
        LDRB    R14,[pixelboxptr,#chr_boxY]
        Debuga  sc,"",R14
        LDRB    R14,[pixelboxptr,#chr_boxW]
        Debuga  sc,"",R14
        LDRB    R14,[pixelboxptr,#chr_boxH]
        Debug   sc,"",R14
      ]

; point pixelboxptr to byte after end of data

        LDR     pixelboxptr,outputcell
        ADD     pixelboxptr,pixelboxptr,#1              ; round up
        MOV     pixelboxptr,pixelboxptr,LSR #1

        Pull    "PC"

err_cachefull
        BreakPt "ScalePixels runs out of room"

        ADD     sp,sp,#8*4                              ; forget 8 words from the stack
        Pull    "LR"
        B       xerr_FontCacheFull

;-----------------------------------------------------------------------------
; computebox - set up 4-bpp scaled font bbox
; Entry:  R6 --> font header
;         [R6,#hdr4_boxx0..] = x0,y0,x1,y1 for input font
;         xscale, yscale, xfactor, yfactor set up
; Exit:   [R6,#hdr4_boxx0..] = x0,y0,x1,y1 for output font
;-----------------------------------------------------------------------------

computebox Entry "R1-R4,R6"

        ADD     R6,R6,#hdr4_boxx0

        LDMIA   R6,{R1-R4}
        Debug   sc,"Old font bbox (x0,y0,x1,y1) =",R1,R2,R3,R4
        BL      computeboxR1R4
        STMIA   R6,{R1-R4}
        Debug   sc,"New font bbox (x0,y0,x1,y1) =",R1,R2,R3,R4

        EXIT

;.............................................................................

; In    R1-R4 = x0,y0,x1,y1 for char/font before scaling
;       xscale, yscale, xfactor, yfactor set up
; Out   R1-R4 = x0,y0,x1,y1 for char/font after scaling
; Note: x0,y0 are inclusive; x1,y1 are exclusive

                ^       0,sp
sp_boxx0        #       4
sp_boxy0        #       4
sp_boxx1        #       4
sp_boxy1        #       4

computeboxR1R4 Entry "R1-R4"

        LDR     R1,xfactor                      ; scaling-down factor
        LDR     R2,xscale                       ; scaling-up factor
        LDR     R0,sp_boxx0                     ; x0 offset
        BL      getorigin
        STR     R3,sp_boxx0

        LDR     R1,yfactor                      ; scaling-down factor
        LDR     R2,yscale                       ; scaling-up factor
        LDR     R0,sp_boxy0                     ; y0 offset
        BL      getorigin
        STR     R3,sp_boxy0

        LDR     R1,xfactor                      ; scaling-down factor
        LDR     R2,xscale                       ; scaling-up factor
        LDR     R0,sp_boxx1                     ; x1 (not width)
        BL      getorigin
        TEQ     R4,R1
        ADDNE   R3,R3,#1                ; make exclusive
        STR     R3,sp_boxx1

        LDR     R1,yfactor                      ; scaling-down factor
        LDR     R2,yscale                       ; scaling-up factor
        LDR     R0,sp_boxy1                     ; y1 (not height)
        BL      getorigin
        TEQ     R4,R1
        ADDNE   R3,R3,#1                        ; make exclusive
        STR     R3,sp_boxy1

        CLRV
        EXIT                                    ; R1-R4 = new coords

;-----------------------------------------------------------------------------
; getorigin - search for origin of bounding box
; Entry:  R0 = offset of input pixels (signed)
;         R1 = amount to scale down by (size of output pixels)
;         R2 = amount to scale up by   (size of input pixels)
; Exit :  R3 = offset of output pixels
;         R4 = amount of output pixel within original grid (0..xf)
;-----------------------------------------------------------------------------

getorigin       ROUT

        Debug   sc2,"Shift to origin:",R0

        MOV     R4,R1                           ; whole of pixel
        MOV     R3,#0                           ; offset
        TEQ     R0,#0
        BEQ     doneorigin
        BPL     moveright

moveleft
        Debug   sc2,"move left"
        ADD     R4,R4,R2                        ; move left 1 input
again1  CMP     R4,R1                           ; gone off edge?
        SUBGT   R4,R4,R1
        SUBGT   R3,R3,#1
        BGT     again1
        ADDS    R0,R0,#1                        ; update counter
        BNE     moveleft
        B       doneorigin

moveright
        Debug   sc2,"move right"
        SUB     R4,R4,R2                        ; move right 1 input
again2  CMP     R4,#0
        ADDLE   R4,R4,R1                        ; gone off edge?
        ADDLE   R3,R3,#1
        BLE     again2
        SUBS    R0,R0,#1                        ; update counter
        BNE     moveright

doneorigin
        Debug   sc,"Output origin/remainder:",R3,R4
        MOV     PC,LR

;;-------------------------------------------
;; Arithmetic routines - used for metrics
;;-------------------------------------------

; divide
;
; Entry:  R0 = 32-bit signed dividend
;         R1 = 16-bit unsigned divisor
; Exit :  R0 = remainder
;         R2 = answer

divide
        EntryS "R3"

        CMP     R0,#0
        MVNLT   R0,R0                   ; cope with signed number
        SavePSR R3                      ; NB: rounds downwards, not to 0
        DivRem  R2,R0,R1,R14
        RestPSR R3,,f
        MVNLT   R2,R2

        EXITS                           ; must preserve flags

;-----------------------------------------------------------------------------

; In    R0 = chunk number (0..7)
;       R6 -> font header
;       R7 = #hdr1/4_leafname
;       R8 -> link -> chunk
; Out   R6 -> cached chunk
;       R6 = 0 if chunk not in file
;       R8 may be relocated
;
; Note that this call copes with requests for chunks which are off the end of the file.
; However, the higher-level routines require that no request is made for a chunk number
; greater than the number allowed for in the PixelsPtrs arrays.
; This is checked for in getmapping_fromR6.

readnewchunk    PEntry Cac_PixDisc, "R1-R5,R7"

        Debug   cc,"Read new format chunk: R6,R7,R0 =",R6,R7,R0

        TEQ     R7,#hdr1_leafname
        MOVEQ   R2,#hdr1_pixelshandle
        MOVNE   R2,#hdr4_pixelshandle
        ADD     R7,R6,R7                ; R7 -> leafname

        LDR     R3,[R7,#hdr4_nchunks-hdr4_leafname]    ; R3 = number of chunks
        CMP     R0,R3
        MOVGE   R6,#0
        PExit   GE                      ; give up if chunk off the end

        BL      openpixels_R2R7         ; R1 = file handle
        PExit   VS                      ; R0 preserved if no error

        PushP   "Saving font header ptr",R6

        LDRB    R5,[R7,#hdr1_flags-hdr1_leafname]   ; used later

;       ADD     R3,R7,#hdr1_PixOffsets-hdr1_leafname
;       LDR     R4,[R3,R0,LSL #2]!      ; R4 = file offset

        ADD     R3,R8,R3,LSL #2         ; R3 -> file offset (later in pixo block after the pointer (R8) itself)
        LDR     R4,[R3]
        LDR     R3,[R3,#4]
        SUBS    R3,R3,R4                ; R3 = no of bytes to read
        Debug   cc,"File offset,size =",R4,R3
        MOVLE   R6,#0
        BLE     %FT98                   ; no chunk to cache

        LDR     R6,[R7,#hdr1_address-hdr1_leafname]
        TEQ     R6,#0                   ; can only use ROM fonts direct
        TSTNE   R5,#pp_flagsinfile      ;   if pix_flags is in the file
        ADDNE   R6,R6,R4                ; R6 -> file block
        SUBNE   R6,R6,#pix_flags        ; block header is bad data
        BNE     %FT98                   ; but pix_flags must be present!

        TST     R5,#pp_flagsinfile      ; are the flags already in there?
        ADDNE   R6,R3,#pix_flags
        ADDEQ   R6,R3,#pix_index
        BL      reservecache
        BVS     %FT98

        ADD     R2,R6,#pix_flags        ; R2 -> output buffer
        TST     R5,#pp_flagsinfile
        STREQ   R5,[R2],#pix_index-pix_flags

        MOV     R0,#OSGBPB_ReadFromGiven
        BLVC    xos_gbpb

        LDRVC   R14,[R6,#pix_flags]     ; mark block as being in the cache
        ORRVC   R14,R14,#pp_incache     ; (speeds things up in getcharfromindex)
        STRVC   R14,[R6,#pix_flags]

98
        Push    "R6"
        PullP   "Restoring font header ptr",R6
        BL      closepixels             ; preserves error state
        Pull    "R6"

        PExit

;;----------------------------------------------------------------------------
;; New outline scaling routines
;;----------------------------------------------------------------------------

; load in scaffolding block (if any)
; In   R7 -> font header block
; Out  [R7,#hdr_Scaffold] -> scaffold block (or = 0 if no scaffolding)
;      R6,R7 relocated if nec.

loadscaffold    PEntry Cac_PixDisc, "R1-R4,R8"

        PushP   "loadscaffold: slave font header",R6

        MOV     R6,R7                   ; R6 -> master font header
        ADD     R8,R6,#hdr_Scaffold

        BL      openpixels1             ; R1 = file handle
        BVS     %FT77

        LDR     R3,[R6,#hdr_scaffoldsize]
        CMP     R3,#512                 ; is there any info?
        BLE     %FT77

        LDR     R6,[R6,#hdr1_address]   ; is this a ROM font?
        TEQ     R6,#0
        ADDNE   R6,R6,#fnew_tablesize-std_end
        STRNE   R6,[R8]                 ; no anchor pointer (it's in ROM)
        BNE     %FT70

        ADD     R6,R3,#std_end+3
        BIC     R6,R6,#3                ; word-align length
        BL      reservecache
        BVS     %FT70

        MOV     R0,#OSGBPB_ReadFromGiven
        ADD     R2,R6,#std_end
        MOV     R4,#fnew_tablesize
        BL      xos_gbpb                ; checks R3=0, preserves R2
        BVS     %FT90

        MakeLink R6,R8, VC              ; do this now, so no scaffold if failed

        LDRVC   R14,[R6,#std_size]      ; lock this until outline chunk loaded
        ORRVC   R14,R14,#size_locked
        STRVC   R14,[R6,#std_size]
70
        SUB     R6,R8,#hdr_Scaffold     ; R6 -> font header (may be relocated)
        BL      closepixels             ; preserves error state
77
        MOV     R7,R6                   ; R7 -> master font header
        PullP   "loadscaffold: slave font header",R6  ; R6 -> slave font header

        PExit

90
        DiscardBlock R6, R3,R14
        B       %BT70

;.............................................................................

; NOTE: If newmapping set, R0 = internal character code
; In    R0 = external character code, or PIX_ALLCHARS => load whole chunk
;       [currentchunk] = external chunk number (0..nchunks-1)
;       R4 = time offset to add to the age of this block
;            (0 => suppress subsequent non-zero offsets)
;       R6 -> font header, [R6,#masterfont] = master font handle
;       [R6,#hdr_encoding] => which encoding to use (0 => no remapping)
;       [paintmatrix] = current paint matrix
; Out   If [mapping2] -> mapping table,
;          R6 corrupted
;       If [mapping2] = 0 (no remapping),
;          R6 -> outline chunk
;       R7 -> master font header (if V clear)
;       R8 corrupted
;       [aspectratio] > 0 => use Super_Sample45 (else Super_Sample90)
;       [outlinefont] = handle of master font
;       [rendermatrix] -> transformation from outlines to pixels
; NB:   The various chunks that the characters in the external chunk come from,
;       as well as the chunks that those chunks depend on are loaded and locked.
;       Keep them locked while allocating memory, then call unlockoutlines.

cacheoutlines_remapping ROUT

        ; just drop through to cacheoutlines

;.............................................................................

; In    [currentchunk] = chunk number (0..nchunks-1)
;       R4 = time offset to add to the age of this block
;            (0 => suppress subsequent non-zero offsets)
;       R6 -> font header, [R6,#masterfont] = master font handle
;       [paintmatrix] = current paint matrix
; Out   R6 -> outline chunk (locked, as are dependent chunks)
;       R7 -> master font header (if V clear)
;       R8 corrupted
;       [aspectratio] > 0 => use Super_Sample45 (else Super_Sample90)
;       [outlinefont] = handle of master font
;       [rendermatrix] -> transformation from outlines to pixels
; NB:   This chunk and any that it depends on are loaded and locked.
;       Keep them locked while allocating memory, then call unlockoutlines.

cacheoutlines Entry "R0"

        BL      getoutlinesinfo         ; set up rendermatrix etc.
        LDRVC   R0,currentchunk
        BLVC    loadoutlinechunk

        STRVS   R0,[sp]
        EXIT

;.............................................................................

; In    R6 -> font header, [R6,#masterfont] = master font handle
;       [paintmatrix] = current paint matrix
; Out   R6 -> scaffold block of master font (loaded and locked)
;       R7 -> master font header (if V clear)
;       [aspectratio] > 0 => use Super_Sample45 (else Super_Sample90)
;       [outlinefont] = handle of master font
;       [rendermatrix] -> transformation from outlines to pixels

getoutlinesinfo Entry "R0,R2"

        LDR     R14,transformptr
        TEQ     R14,#0
        ADDNE   R14,R14,#trn_rendermatrix
        ADDEQ   R14,R6,#hdr_rendermatrix
        STR     R14,rendermatrix                ; in relocation stack

        Debug   cc,"cacheoutlines: rendermatrix at",R14

        LDR     R2,[R6,#hdr_xres]
        LDR     R14,[R6,#hdr_yres]
        SUB     R2,R2,R14
        RSB     R2,R14,R2,LSL #1        ; is xres > 1.5 * yres?
        STR     R2,aspectratio          ; if +ve, use Super_Sample45

        LDRB    R0,[R6,#hdr_masterfont]
        STRB    R0,outlinefont          ; needed for accessing scaffolding

        BL      getfontheaderptr        ; R7 -> master font header
        BVS     %FT99

; first load and lock the scaffold block

        LDR     R14,[R7,#hdr_Scaffold]  ; R7 -> master font header
        TEQ     R14,#0
        CacheHit Scaffold, NE
        BLEQ    loadscaffold            ; block is locked
        BVS     %FT99

        LDR     R6,[R7,#hdr_Scaffold]
        MarkAccessed R6, R14            ; update 'age' of block in R6

99      STRVS   R0,[sp]
        EXIT

;.............................................................................

; In    R0 = chunk number
;       R4 = time offset to add to the age of this block
;            (0 => suppress subsequent non-zero offsets)
;       R7 -> master font header
; Out   R6 -> outline chunk
;       R8 corrupted
; NB:   This chunk and any that it depends on are loaded and locked.
;       Keep them locked while allocating memory, then call unlockoutlines.

loadoutlinechunk Entry "R0,R2,R3"

        Debug   cc,"loadoutlinechunk: R7,R0 =",R7,R0

        BL      setoutlineptr           ; R6 -> outlines (locked)
        BVS     %FT98

; if this chunk has any dependencies, ensure those blocks are loaded too

        TEQ     R6,#0
        LDRNE   R14,[R6,#pix_flags]
        TSTNE   R14,#pp_dependencies
        BEQ     %FT99

        LDR     R0,[R7,#hdr1_nchunks]
        PushP   "Outline chunk ptr",R6

        SUB     R0,R0,#1
        Debug   cc,"nchunks-1 =",R0

loadoutlinechunk_dependenciesloop
        ASSERT  (pix_dependencies :AND: 3) = 0

        ADD     R2,R6,#pix_dependencies
        MOV     R14,R0,LSR #5           ; now allow unlimited chunks
        LDR     R2,[R2,R14,LSL #2]
        Debug   cc,"dependency flags =",R2

        TEQ     R2,#0
        BICEQ   R0,R0,#&1F
        SUBEQ   R0,R0,#1
        BEQ     %FT96

02      MOV     R14,#1
        TST     R14,R2,ROR R0
        BLNE    setoutlineptr           ; R6 -> outline chunk (locked)
        BVS     %FT97

03      TST     R0,#&1F
        SUB     R0,R0,#1
        BNE     %BT02

        PullPx  "Outline chunk ptr", R6

96      TEQ     R0,#0
        BPL     loadoutlinechunk_dependenciesloop
97
        PullP   "Outline chunk ptr",R6
98
        BLVS    unlockoutlines          ; R7 -> master font header
99
        STRVS   R0,[sp,#0*4]
        EXIT

;.............................................................................

; In    R6 -> block
; Out   If block is in cache memory, it is made into the newest.
;       [ agelist: block put at tail of list | [R6,#std_age] updated ]

markaccessed    Entry "R0"

        LDR     R14,fontcache
        CMP     R6,R14
        LDRHS   R14,fontcacheend        ; if address is inside cache limits
        CMPHS   R14,R6
        MarkAge R6, R0,R14, HS          ; mark block accessed

        CLRV
        EXIT

;.............................................................................

; In    R6 -> block (may be 0 or outside cache)
;       R8 -> parent pointer
; Out   [R8] = R6
;       [R6,#std_anchor] = R8 if R6 inside cache

makelink EntryS ""

        STR     R6, [R8]

        LDR     R14,fontcache
        CMP     R6,R14
        LDRCS   R14,fontcacheend        ; if address is inside cache limits
        CMPCS   R14,R6
        STRCS   R8,[R6,#std_anchor]     ; save anchor pointer

        EXITS

;.............................................................................

; In    R7 -> master font header
;       R0 = chunk number to load
;       R4 = time offset to add to the age of this block
; Out   R6 -> outline chunk (loaded from disc if necessary)
;       R7 may be relocated
;       R8 corrupted
;       outline chunk is locked (if any)

setoutlineptr Entry "R0"

      [ debugcc
        LDR     R14,[R7,#hdr_xsize]
        Debug   cc,"setoutlineptr: R7,R0,xsize =",R7,R0,R14
      ]

        PushP   "master font header",R7

;       ADD     R8,R7,#hdr1_PixelsPtrs
        LDR     R8,[R7,#hdr1_PixoPtr]
        CMP     R8,#0
        BLEQ    readpixoblock_outlines      ; relocates R7 if required
        BVS     %FT90
        ADD     R8,R8,#pixo_pointers
        LDR     R14,[R8,R0,LSL #2]!         ; R8 -> chunk pointer
        TEQ     R14,#0
        MOVNE   R6,R14
        MOVEQ   R6,R7                       ; R6 -> master font header
        MOVEQ   R7,#hdr1_leafname           ; put outlines in 1-bpp section
        CacheHit Outlines, NE
        BLEQ    readnewchunk
90
        PullP   "master font header",R7

        STRVS   R0,[sp]
        EXIT    VS

        MakeLink R6,R8                      ; link in immediately

        TEQ     R6,#0
        EXIT    EQ

        LDR     R14,[R7,#hdr1_address]      ; if ROM-based,
        TEQ     R14,#0                      ; don't bother with locking etc.
        EXIT    NE

; this stuff is only done if block is not in ROM

        LDR     R14,[R6,#std_size]          ; lock outline block, so it can't be deleted
        ORR     R14,R14,#size_locked
        STR     R14,[R6,#std_size]

        LDR     R14,[R6,#pix_flags]
        TEQ     R4,#0
        ORREQ   R14,R14,#pp_needoutlines    ; stop cachebitmaps making the
        STREQ   R14,[R6,#pix_flags]         ; outline block seem older

        TST     R14,#pp_needoutlines
        MarkAgeOffset R6,R4, R0,R14, NE     ; actually just calls MarkAge

        EXIT

;.............................................................................

; In    R7 -> master font header
; Out   all outline blocks, plus scaffold and mapping2 unlocked

unlockoutlines  EntryS "R1,R6-R8"

        LDR     R14,[R7,#hdr1_address]  ; ROM blocks don't need locking
        TEQ     R14,#0
        EXITS   NE

; this stuff is only done if blocks are not in ROM

        LDR     R6,[R7,#hdr_Scaffold]   ; unlock scaffold block
        TEQ     R6,#0
        LDRNE   R14,[R6,#std_size]
        BICNE   R14,R14,#size_locked
        STRNE   R14,[R6,#std_size]

;       ADD     R8,R7,#hdr1_PixelsPtrs
        LDR     R8,[R7,#hdr1_PixoPtr]
        ADD     R8,R8,#pixo_pointers
;       MOV     R1,#MaxChunks
        LDR     R1,[R7,#hdr1_nchunks]
01      LDR     R6,[R8],#4
        TEQ     R6,#0
        LDRNE   R14,[R6,#std_size]
        BICNE   R14,R14,#size_locked
        STRNE   R14,[R6,#std_size]
        SUBS    R1,R1,#1
        BNE     %BT01

        EXITS

;.............................................................................

; In    R0 = character code required (PIX_ALLCHARS => all)
;       [antialiasx/y] = subpixel offsets
;       R6 -> slave font header block
;       R8 -> link word (which will contain chunk pointer)
;       [currentchunk] = chunk number (0..nchunks-1)
;       [charflags] :AND: chf_1bpp ==> produce 1-bpp results, else 4-bpp
;       [subpixelflags] bits 0,1 => do subpixel scaling (h and v)
; Out   R6 -> new pixels block
;       R8 corrupted
; If R0=character code, this character is definitely not already cached
; If R0=PIX_ALLCHARS, there is definitely no previous chunk

cachebitmaps Entry "R0-R4,R7,R9,R11"

        Debug   cc,"cachebitmaps: slave font, R0 =",R6,R0

     ;; CheckCache "cachebitmaps entry"

        PushP   "Saving font header block",R6

        LDRB    R14,charflags

        LDR     R2,transformptr
        TEQ     R2,#0
        BEQ     %FT01

;       TST     R14,#chf_1bpp
;       ADDEQ   R2,R2,#trn4_boxx0
;       ADDNE   R2,R2,#trn1_boxx0
        ADD     R2,R2,#trn_boxx0
        B       %FT02

01      TST     R14,#chf_1bpp
        ADDEQ   R2,R6,#hdr4_boxx0
        ADDNE   R2,R6,#hdr1_boxx0

02      LDMIA   R2,{R1-R4}
        SUB     R3,R3,R1                ; convert to x,y,w,h
        SUB     R4,R4,R2
        ADR     R14,pbox                ; set up [pbox..]
        STMIA   R14,{R1-R4}

        LDR     R3,[R8]
        Debug   cc,"cachebitmaps: link, existing pixel chunk =",R8,R3

        PushP   "Saving existing pixel chunk",R3

; encourage outline block to be deleted by making it seem much older
; (this is not done if the block is required for direct outline drawing)

        TEQ     R0,#PIX_ALLCHARS
        MOVNE   R4,#0                   ; no time offset if not all chars converted
        MOVEQ   R4,#2*bigtime           ; make seem older if whole chunk done
        BL      cacheoutlines_remapping ; sets up various other variables

        PullP   "Recovering existing pixel chunk",R8
        BVS     %FT99                   ; (and sets R7 -> font header)

        Debug   cc,"Scaling from outline block at",R6

        SWI     XHourglass_On           ; ignore errors (may not be loaded)
      ; CLRV                            ; see comment below

; [subpixelflags] set up from bits 0..1 of leafname type
; R6 -> outline chunk (may be null)
; R8 -> existing pixel chunk (0 => none)

        LDR     R0,[sp]                 ; R0 = character code required
        LDRB    R4,subpixelflags        ; R4 = pixel flags for the output block
        TEQ     R0,#PIX_ALLCHARS
        ORRNE   R4,R4,#pp_splitchunk
        ORR     R4,R4,#pp_incache       ; chunk is in the cache (not ROM)
        CLRV                            ; I think we need this here. -Chris.
        BL      outputtosprite          ; redirect output to the sprite
        BVS     %FT98

; Bug fix by Chris:
;
;     If R0=1, then output wasn't switched to a sprite because the character was too
;     small, and we should return with R6=1 to prevent exitpix trying to store
;     the non-existent sprite.
;
;     If R0=0, then there is no sprite again, but we must continue otherwise we'll
;     not cache the whole chunk (Font_MakeBitmap need this).

       TEQ     R0,#1                   ; character too small?
       MOVEQ   R6,#1                   ; yes so R6=1 => no sprite
       BEQ     %FT98                   ; and exit

; we would save the previous sprite parameters here, but it's now done better

        SUB     sp,sp,#4*4              ; keep stack the same (for a quiet life)

; construct a new block to contain the bitmaps
; R6 -> outline chunk index or 0 => no outlines, space reserved at end of cache (by outputtosprite)
; R8 -> existing pixel chunk (0 => make a new one)
; [sp, #4*4] = character code (PIX_ALLCHARS => all)

        MOVS    R3,R6                   ; R3=0 => no output characters to be generated
        ADDNE   R3,R6,#pix_index        ; R3 -> input index

        Debuga  cc,"Outline index =",R3
        Debug   cc," (0 => no output sprite)"

        CMP     R8,#0
        ADDNE   R6,R8,#pix_index        ; R6 -> output index
        GetReservedBlockAddr R2,R14,NE  ; R2 -> output data
      [ :LNOT: debugbrk
        BNE     %FT11
      |
        BEQ     %FT50
        LDR     R14,[R8,#pix_flags]
        TEQ     R14,R4                  ; check that flags are the same
        BreakPt "Flags different!",NE
        B       %FT11
50
      ]

        GetReservedBlockAddr R6         ; R6 -> new block
        STR     R4,[R6,#pix_flags]      ; stash the flags
        Debug   th,"Subpixel scaling flags =",R4

        ADD     R6,R6,#pix_index        ; R6 -> output index
        MOV     R2,#pix_data-pix_index
        TST     R4,#pp_4xposns          ; R4 = pixel flags
        MOVNE   R2,R2,LSL #2
        TST     R4,#pp_4yposns
        MOVNE   R2,R2,LSL #2
        ADD     R2,R6,R2                ; R2 -> after index

11
        Debug   cc,"Input index, output index,data,flags =",R3,R6,R2,R4

; now, if R0=PIX_ALLCHARS on entry, do whole chunk, else do specified character

        LDRB    R7,antialiasx
        LDRB    R9,antialiasy
        Push    "R7,R9"                 ; must save these for PaintChar

        LDR     R0,[sp,#6*4]            ; skip R7,R9 and R0-R3 (old sprite)
        TEQ     R0,#PIX_ALLCHARS        ; NB: R0=char code needed lower down
        BEQ     %FT12

; R0 = character index of single char to do
; if block not yet initialised, fill in the index

        Debug   cc,"convert a single character"

        TEQ     R8,#0
        BNE     %FT52

        MOV     R14,#PIX_UNCACHED       ; fill in index => no chars cached
        MOV     R1,R6
51      STR     R14,[R1],#4
        CMP     R1,R2
        BLO     %BT51

        SUB     R14,R2,R6               ; also store the block size now
        ADD     R14,R14,#pix_index      ; NB: block still not linked in
        ORR     R14,R14,#size_claimed
        STR     R14,[R6,#std_size-pix_index]
52

; determine correct values for R7,R9 (set to 0 if no subpixel scaling)

        TST     R4,#pp_4xposns
        MOVEQ   R7,#0
        TSTNE   R4,#pp_4yposns
        MOVEQ   R14,R7
        MOVNE   R14,R7,LSL #2           ; times 4 if y-posns done also
        TST     R4,#pp_4yposns
        MOVEQ   R9,#0
        ADDNE   R14,R14,R9
        STRB    R14,percentadd
        BL      convertchunk            ; do the single character (R0 = character index)
        BVC     %FT04

; error exit for code above

        TEQ     R8,#0                   ; if block already existed, continue (this char is set to null)
        BNE     %FT04                   ; otherwise discard whole chunk

; error exit for code below

41
        Pull    "R7,R9"                 ; restore correct subpixel offsets
        STRB    R7,antialiasx
        STRB    R9,antialiasy
        MOV     R6,#0                   ; return null pointer and abort
        B       %FT97

; not split chunk: do all chars in the index

12
        Debug   th,"convert a whole chunk - subpixel flags =",R4

        MOV     R7,#0           ; x-offset
        STRB    R7,percentadd
01      MOV     R9,#0           ; y-offset
02      MOV     R0,#PIX_ALLCHARS        ; R0 = PIX_ALLCHARS => do all chars in chunk
        BL      convertchunk
        BVS     %BT41                   ; discard whole chunk if error occurs
        TST     R4,#pp_4yposns
        BEQ     %FT03
        ADD     R9,R9,#1
        CMP     R9,#4
        BNE     %BT02
03      TST     R4,#pp_4xposns
        BEQ     %FT04
        ADD     R7,R7,#1
        CMP     R7,#4
        BNE     %BT01

; finished - if R8=0, we need to finish off the chunk index block
; R2 -> end of memory after chunk and all chars allocated

; NB: this code may be entered with an error condition (VS)

04
        Pull    "R7,R9"                 ; restore correct subpixel offsets
        STRB    R7,antialiasx
        STRB    R9,antialiasy

        SetBlockEnd "",R2,R14,No        ; "" => don't set block size, "No" => haven't already got cacheindex pointer

        TEQ     R8,#0
        MOVNE   R6,R8                   ; NE => R6 -> block header
        SUBEQ   R6,R6,#pix_index        ; EQ => R6 -> block header
        LDREQ   R14,[sp,#4*4]           ; allow for 4 words of sprite data on stack
        TEQEQ   R14,#PIX_ALLCHARS       ; size already filled in if not allchars
        SUBEQ   R2,R2,R6
        ORREQ   R2,R2,#size_claimed
        STREQ   R2,[R6,#std_size]       ; set up correct block size

        TEQ     R8,#0
        RemLink R6,R1,R11,NE            ; remove from age list if already existed
        LDR     R1,ageheadblock_p       ; then always move to end of list
        LDR     R11,[R1,#std_backlink]
        StrLink R6,R1,R11               ; R6 -> pixels block here

      [ debugcc
        LDR     R2,[R6,#std_size]
        Debug   cc,"Pixels block, size, oldblock =",R6,R2,R8
      ]

97
        ADD     sp,sp,#4*4              ; just correct stack - defer restoreoutput
98
      [ No32bitCode
        Push    "R0,PC"
      |
        SavePSR LR
        Push    "R0,LR"
      ]

        MOV     R0,#-1                  ; stop percentages
        SWI     XHourglass_Percentage
        SWI     XHourglass_Off          ; ignore errors from this

; all outline blocks are unlocked on exit
; outline blocks are made very old unless used for direct char painting

        Pull    "R0,LR"
        RestPSR LR,,f                   ; assume no error from deleteblock

99
        PullP   "unstacking font header block",R7
        MOV     R14,#0
        STR     R14,scratchblock        ; not in use any more

      [ No32bitCode
        Push    "R0,PC"                 ; preserve error state
      |
        SavePSR LR
        Push    "R0,LR"
      ]

        LDRB    R0,[R7,#hdr_masterfont]
        BL      getfontheaderptr        ; R7 -> master font header
        BLVC    unlockoutlines

        Pull    "R0,LR"
        RestPSR LR,,f

        STRVS   R0,[sp]

        EXIT

;.............................................................................

; In    R1 -> block (may or may not be inside cache)
; Out   block locked if in cache, left alone otherwise

lockblock EntryS ""

        LDR     R14,fontcache
        CMP     R1,R14
        LDRCS   R14,fontcacheend
        CMPCS   R14,R1
        LDRCS   R14,[R1,#std_size]
        ORRCS   R14,R14,#size_locked
        STRCS   R14,[R1,#std_size]

        EXITS

;.............................................................................

; In    R1 -> block (may or may not be inside cache)
; Out   block unlocked if in cache, left alone otherwise

unlockblock EntryS ""
        LDR     R14,fontcache
        CMP     R1,R14
        LDRCS   R14,fontcacheend
        CMPCS   R14,R1
        LDRCS   R14,[R1,#std_size]
        BICCS   R14,R14,#size_locked
        STRCS   R14,[R1,#std_size]
        EXITS                   ; must preserve flags

;.............................................................................

; In    R0 = character to do (PIX_ALLCHARS => all in [currentchunk])
;       [mapping2] -> remapping table (or 0 if no remapping)
;       If mapping2=0 then R3 -> input chunk index (32 characters), or 0 => no output sprite
;                     else R3 -> index of outline chunk blocks (in master font header)
;       R6 -> output chunk index
;       R2 -> output char data
;       R7,R9 = x,y pixel offsets to apply to anti-aliased chars
;       [currentchunk] = output chunk number (0..nchunks-1)
;       [percentadd] = subpixel chunk number (0..15 depending on flags)
; Out   R2 updated, pixel characters generated

convertchunk    Entry "R1,R3-R5,R11"

        Debug   cc,"convertchunk: R0,R3,R6,R2,R7,R9 =",R0,R3,R6,R2,R7,R9

        STRB    R7,antialiasx
        STRB    R9,antialiasy

        ASSERT  (PIX_ALLCHARS :AND: &1F)=0
        AND     R11,R0,#PIX_ALLCHARS :OR: &1F
        AND     R4,R11,#&1F             ; R4 = character index within chunk (may or may not loop)

convertloop
        Push    "R2-R4"

        LDRB    R1,percentadd
        ADD     R1,R4,R1,LSL #5         ; R1 = output char index

01      MOVS    R14,R3                  ; treat char as null if no output sprite
        LDRNE   R14,[R3,R4,LSL #2]      ; otherwise obtain offset to character

        LDR     R0,currentchunk
        ADD     R4,R4,R0,LSL #5         ; R4 = char code (for scaffolding)
02
        Debuga  cc,"Input index, offset",R3,R14

        TEQ     R14,#0                  ; NE => char present, EQ => no char present
        ADDNE   R3,R3,R14               ; R3 -> outline character
        SUBNE   R14,R2,R6               ; R14 = offset within output chunk
        STR     R14,[R6,R1,LSL #2]      ; either 0 or the correct offset

        Debuga  cc," output index, offset",R1,R14
        Debug   cc," input code",R4

        BEQ     endconvertloop

; convert to a Draw module path, then draw into the sprite

        BL      getcharheader           ; [charflags] => 8- or 12-bit coords
                                        ; R3 updated
        BVS     %FT08
        LDR     R2,sprite_area          ; R2 -> sprite area
        MOV     R1,#0
        LDR     R14,sprite_params_size  ; sprite header may have been overwritten
        ADD     R14,R2,R14              ; R14 -> end of sprite area (and sprite)
        ADD     R2,R2,#saExten+spPalette; R2 -> start of sprite data
05      CMP     R2,R14                  ; blat it to zeroes
        STRLO   R1,[R2],#4
        BLO     %BT05
        MOVVC   R2,#0                   ; R2,R3,R4 = matrix,inptr,charcode
        BLVC    drawchar                ; uses [scratchblock]
      [ debugcc
;       BLVC    showsprite1bpp
      ]

; anti-alias the result (if 4-bpp)

        LDRVC   R1,sprite_area
        ADDVC   R1,R1,#saExten+spPalette   ; R1 -> input 1-bpp data
        LDRVC   R2,sprite_width            ; R2 = line spacing (words)
        MOVVC   R2,R2,LSL #2               ;      (convert to bytes)
        LDRVC   R3,sprite_height           ; R3 = number of rows (4n+3)
        MOVVC   R4,R1                      ; R4 -> output buffer (same)

        LDRB    R14,charflags
        TST     R14,#chf_1bpp
        BNE     go_stripoff

        Debug   cc,"Super sample: in,llen,nrows,out =",R1,R2,R3,R4

        ProfIn  Cac_Super

        LDR     R14,aspectratio
        TEQ     R14,#0
        BPL     go_45
go_90
        SWIVC   XSuper_Sample90
        B       ex_90
go_45
        SWIVC   XSuper_Sample45         ; always use this if wantratio=FALSE
ex_90
        ProfOut

      [ debugcc
;       BLVC    showsprite4bpp
      ]

        MOVVC   R3,R3,LSR #2            ; R3 = no of rows of anti-aliased stuff (must be >= 1)

; R1 -> sprite data, R2,R3 = width, height

go_stripoff
        LDR     R4,[sp,#0*4]            ; R4 -> output char definition
        TEQ     R11,#PIX_ALLCHARS       ; if not all chars,
        ADDNE   R4,R4,#std_end          ; skip header field

        BLVC    stripoff                ; this CAN return "Font Cache Full" if I got it wrong earlier

08      MOVVS   R4,#0                   ; if error, treat character as null

        LDR     R2,[sp,#0*4]            ; R2 -> character data
        TEQ     R4,#0
        STRNE   R4,[sp,#0*4]            ; R4=0 => null char, else new data ptr
        LDR     R14,[sp,#2*4]
        LDRB    R1,percentadd           ; convert to OUTPUT index
        ADD     R14,R14,R1,LSL #5       ; R14 = character index
        STREQ   R4,[R6,R14,LSL #2]      ; char was null (overwrite existing offset)

        BVS     endconvertloop          ; only abort now, after char has been written as null

; if single char, fill in header and link into age list (can't go wrong now)

        TEQNE   R11,#PIX_ALLCHARS       ; NE => R2 -> character block, R4 -> end
        LDRNE   R1,ageheadblock_p
        LDRNE   R5,[R1,#std_backlink]   ; NB: R14 is in use already!
        StrLink R2,R1,R5,NE
        SUBNE   R1,R4,R2                ; fill in char header size field
        ORRNE   R1,R1,#size_claimed :OR: size_charblock
        STRNE   R1,[R2,#std_size]

; now put pointer to character in chunk index (plus anchor in char header)

        STRNE   R2,[R6,R14,LSL #2]      ; chunk index contains char address in this case
        ADDNE   R14,R6,R14,LSL #2       ; R14 -> anchor address
        STRNE   R14,[R2,#std_anchor]

endconvertloop
        Pull    "R2-R4"
        EXIT    VS

        TEQ     R11,#PIX_ALLCHARS       ; give up now if only 1 char to do
        EXIT    NE

        LDRB    R0,percentadd           ; which chunk are we doing?
        ADD     R0,R4,R0,LSL #5
        LDR     R14,[sp,#2*4]           ; get pixel flags
        TST     R14,#pp_4xposns
        MOVNE   R0,R0,LSR #2            ; divide by 4 for x-posns
        TST     R14,#pp_4yposns
        MOVNE   R0,R0,LSR #2            ; divide by 4 for y-posns
        ADR     R14,percentages
        LDRB    R0,[R14,R0]
        SWI     XHourglass_Percentage   ; ignore errors (may not be loaded)

        ADD     R4,R4,#1
        CMP     R4,#32                  ; CLRV
        BCC     convertloop

        LDRB    R14,percentadd          ; next set of 32 characters
        ADD     R14,R14,#1
        STRB    R14,percentadd

        EXIT

percentages     DCB      6, 9,12,15,18,21,24,27,30,33,36,39,42,45,48,51
                DCB     54,57,60,63,66,69,72,75,78,81,84,87,90,93,96,99
                ASSERT  (.-percentages) = 32

;.............................................................................

; In    R2 -> matrix to use (0 ==> use unit matrix)
;       R3 -> input character data (header already read)
;       R4 = character code
;       [charflags] set up from character header
;       [scratchblock] -> scratch area for Draw path
;       [pboxX], [pboxY] = origin (subtracted from pixel coords)
;       [rendermatrix] -> transformation from design units -> pixels << 9
;       data from cacheoutlines is set up
; Out   scaffolding computed, Draw module used to draw character
;       (or if output switched to buffer, draw path constructed)

drawchar Entry "R1-R6,R8,R9"

        MOV     R14,#0                  ; offset = (0,0) for main char
        STR     R14,xcomponent
        STR     R14,ycomponent

        LDRB    R14,charflags
        TST     R14,#chf_composite1:OR:chf_composite2
        BNE     drawchar_composite

        BL      drawcomponent           ; R3 -> byte after terminator
        EXIT    VS

        LDRB    R14,[R3,#-1]
        TST     R14,#8                  ; bit 3 set => more components follow
        EXIT    EQ

; cacheoutlines should have made sure that all the blocks were loaded

        MOV     R6,R3                   ; R6 -> list of composite bits

        LDRB    R14,outlinefont
        LDR     R8,cacheindex           ; must be present
        LDR     R8,[R8,R14,LSL #2]      ; R8 -> outline font header
;       ADD     R8,R8,#hdr1_PixelsPtrs
        LDR     R8,[R8,#hdr1_PixoPtr]
        ADD     R8,R8,#pixo_pointers    ; R8 -> outline chunk index

; scan list of components with their offsets

        LDRB    R14,charflags
        Push    "R14"

scancomponents
        Debug   cm,"R6 complist, R8 chunk index =",R6,R8

        LDR     R14,[R13]
        LDRB    R4,[R6],#1              ; R4 = character code
        TST     R14,#chf_16bitcodes
        LDRNEB  R14,[R6],#1
        ORRNE   R4,R4,R14,LSL #8
        TEQ     R4,#0
        ADDEQ   R13,R13,#4
        EXIT    EQ                      ; finished

        Push    "R2"                    ; R2 -> matrix
        BL      getcoordpair            ; R2,R3 = coordinates
        Debug   cm,"Composite character code,x,y =",R4,R2,R3
        STR     R2,xcomponent
        STR     R3,ycomponent
        Pull    "R2"

; obtain pointer to character by looking in the outline font header

        BL      drawcomposite           ; subroutine does exactly the same!

        BVC     scancomponents          ; continue until no more

        ADD     R13,R13,#4

        EXIT

;. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R14 = [charflags] = char flags
;       R2 -> matrix
;       R3 -> [basecode] [accentcode x y]
;       All relevant outline blocks should be loaded

drawchar_composite

        LDRB    R9,outlinefont
        LDR     R8,cacheindex           ; index must be present
        LDR     R8,[R8,R9,LSL #2]       ; R8 -> outline font header
;       ADD     R8,R8,#hdr1_PixelsPtrs
        LDR     R8,[R8,#hdr1_PixoPtr]
        ADD     R8,R8,#pixo_pointers    ; R8 -> outline chunk index

        MOV     R6,R3                   ; R6 -> composite character codes

        TST     R14,#chf_composite1
        BEQ     %FT10
        LDRB    R4,[R6],#1              ; R4 = character code, R8 -> chunk index,[x/ycomponent] = origin
        TST     R14,#chf_16bitcodes
        LDRNEB  R14,[R6],#1
        ORRNE   R4,R4,R14,LSL #8
        BL      drawcomposite
10
        LDRB    R14,charflags
        TST     R14,#chf_composite2
        Pull    "R1-R6,R8,R9,PC",EQ

        LDRB    R4,[R6],#1              ; R4 = character code
        TST     R14,#chf_16bitcodes
        LDRNEB  R14,[R6],#1
        ORRNE   R4,R4,R14,LSL #8

        Push    "R2"
        BL      getcoordpair            ; R2,R3 = coordinates
        STR     R2,xcomponent
        STR     R3,ycomponent
        Pull    "R2"
        BL      drawcomposite           ; R4 = character code, R8 -> chunk index,[x/ycomponent] = origin

        Pull    "R1-R6,R8,R9,PC"

;. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

; In    R2 -> matrix
;       R4 = character code
;       R8 -> chunk index
;       [x/ycomponent] = x/y origin

drawcomposite Entry "R3"

        Debug   cm,"drawcomposite: matrix,code,index =",R2,R4,R8

        MOV     R14,R4,LSR #5
        LDR     R3,[R8,R14,LSL #2]      ; R3 -> outline chunk
        CMP     R3,#0
        BreakPt "drawcomposite: outline chunk wasn't loaded!",EQ
        ADDNE   R3,R3,#pix_index
        ANDNE   R14,R4,#31
        LDRNE   R14,[R3,R14,LSL #2]
        CMPNE   R14,#0                  ; ignore if char does not exist
        EXIT    EQ                      ; or if composite chunk not loaded (breakpt while debugging)

        ADD     R3,R3,R14               ; R3 -> char header

        LDRB    R14,charflags           ; save charflags for main char
        Push    "R14"

        BL      getcharheader           ; R3 -> outline definition
        BL      drawcomponent           ; may return an error

        Pull    "R14"
        STRB    R14,charflags

        EXIT

;.............................................................................

; In    R2 -> matrix to use (0 ==> use unit matrix)
;       R3 -> input character data (header already read)
;       R4 = character code
;       [x/ycomponent] = offset for this character component
;       [charflags] set up from character header
;       [scratchblock] -> scratch area for Draw path
;       [pboxX], [pboxY] = origin (subtracted from pixel coords)
;       [rendermatrix] -> transformation from design units to pixels << 9
;       data from cacheoutlines is set up
; Out   scaffolding computed, Draw module used to draw character
;       R3 -> byte after the outline definition
;       R0,R1,R2,R4,R5 corrupted

drawcomponent Entry "R6"

        LDRB    R14,charflags           ; no local data present in a composite character
        TST     R14,#chf_composite1:OR:chf_composite2
        EXIT    NE

        Debug   cm,"drawchar: scratchblock,R2,R3,R4 =",#scratchblock,R2,R3,R4

        BL      convertcharpath         ; Exit: R0 -> start of path
                                        ;       R1 -> end of path
        SUB     R14,R1,R0               ; R14 = length of path (used later)
        LDR     R1,switch_buffer
        TEQ     R1,#0                   ; doesn't affect V
        BNE     drawchar_tobuffer

; This code handles the Version 8 fonts with non-zero filling rules,
; we must attempt to find the outline data and check the flags and
; use the appropriate filling algorithm.

        BVS     %FT01                   ; exit if already errored (assume R0 setup)

        ProfIn  Cac_Draw

        LDRB    LR,outlinefont          ; should be defined, already checked
        LDR     R1,cacheindex
        LDR     R1,[R1,LR,LSL #2]       ; get pointer to suitable outline data
        LDRB    R1,[R1,#hdr1_flags]

        TST     R1,#pp_fillnonzero
        MOVEQ   R1,#&32                 ; fill 1/2 boundary, even-odd rule
        MOVNE   R1,#&30                 ; fill 1/2 boundary, non-zero rule

        Push    "R3"
        MOV     R3,#100                 ; suitable flatness
        SWI     XDraw_Fill              ; and then attempt to fill
        Pull    "R3"
        ProfOut

        BVS     %FT01                   ; error exit

        LDRB    R14,[R3,#-1]
        TST     R14,#1:SHL:2            ; is there a stroke path?
        BEQ     %FT01

        BL      convertpath             ; get the rest of the char
                                        ; must do this to update R3

        LDRB    R1,charflags            ; check whether we should bother
        TST     R1,#chf_1bpp
        MOVNE   R1,#sk1_dontbother
        MOVEQ   R1,#sk4_dontbother
        LDRB    R14,skeleton_threshold
        TST     R14,R1
        BNE     %FT01

        ProfIn  Cac_Draw
        Push    "R3"
        MOVVC   R1,#&18                 ; stroke boundary only
        MOVVC   R3,#100                 ; flatness
        MOVVC   R4,#0                   ; thin stroke
        MOVVC   R5,#0                   ; no special line caps
        MOVVC   R6,#0                   ; not dotted
        SWIVC   XDraw_Stroke
        Pull    "R3"
        ProfOut
01
        Debug   cm,"drawchar: exitting"

        EXIT

drawchar_tobuffer

        Debuga  cm,"drawchar: transforming path at",R0
        Debug   cm," to buffer at",R1

        BVS     %FT02

; In    R0 -> input path
;       R1 -> output path
; Out   R1 updated, [R1] updated if (switch_flags :AND: swf_justcount) = 0

        Push    "R3-R6"
        LDR     R3,switch_flags
        TST     R3,#swf_justcount
        LDREQ   R4,[R1,#4]              ; space left in buffer
        MOV     R5,#0                   ; no need for closepath yet

12      LDR     R6,[R0],#4
        CMP     R6,#path_move
        CMPNE   R6,#path_end
        CMPEQ   R5,#path_close
        BLEQ    put_word                ; R5 = word to put
        BVS     %FT19

        ASSERT  path_end = 0
        MOVS    R5,R6
        BEQ     %FT19                   ; finished

        BL      put_word

        TEQ     R6,#path_move           ; enable closepath if there is a non-null path
        MOVEQ   R5,#0
        MOVNE   R5,#path_close

        BLVC    put_coords
        TEQ     R6,#path_curve
        BNE     %FT13
        BLVC    put_coords              ; 3 coords for curves
        BLVC    put_coords

13      BVC     %BT12
19
        TST     R3,#swf_justcount
        BNE     %FT14

        MOV     R14,#path_end
        STR     R14,[R1]                ; terminate path correctly
        STR     R4,[R1,#4]

        Push    "R1"
        LDRVC   R0,switch_buffer        ; R0 -> new path
        MOVVC   R1,#0                   ; send to same path
        MOVVC   R3,#0
        SWIVC   XDraw_TransformPath     ; transform it
        Pull    "R1"
14
        Pull    "R3-R6"
        BVS     %FT02

        STR     R1,switch_buffer        ; updated pointer

        LDRB    R14,[R3,#-1]
        TST     R14,#1:SHL:2            ; is there a stroke path?

        BLNE    convertpath             ; get the rest of the char
                                        ; must do this to update R3
02
        Debug   cm,"drawchar (to buffer): exitting"

        Pull    "R6,PC"

;.............................................................................

; In    R1 -> output buffer
;       R3 = switch_flags
;       R4 = space remaining (if R3 :AND: swf_justcount) = 0
;       R5 = word to put in
; Out   R1 updated, [R1] updated if (R3 :AND: swf_justcount) = 0
;       R4 updated

put_word Entry ""

        TST     R3,#swf_justcount       ; if just counting,
        ADDNE   R1,R1,#4                ; R4 is not defined
        EXIT    NE

        SUBS    R4,R4,#4                ; see if there's room
        ADDLT   R4,R4,#4
        BLLT    xerr_buffoverflow
        STRVC   R5,[R1],#4              ; put word in if it fits

        EXIT

;.............................................................................

; In    R0 -> input buffer (x,y coords next)
;       R1 -> output buffer
;       R3 = switch_flags
;       R4 = space remaining
; Out   R0 updated
;       R1 updated, [R1] updated if (R3 :AND: swf_justcount) = 0
;       R4 updated

put_coords Entry "R5"

        LDR     R5,[R0],#4
        BL      put_word
        LDRVC   R5,[R0],#4
        BLVC    put_word

        EXIT

;.............................................................................

; In    If [mapping2] -> remapping table, then R7 -> master font header
;       If [mapping2] = 0 (no remapping), then R6 -> outline chunk
;       R4 = new block's pixel flags
;       [pbox] = font bounding box (pixels)
;       R6 -> outline chunk (if no remapping) (0 => none - don't create sprite)
;       R8 -> existing bitmap chunk index (0 => not cached)
;       [charflags] :AND: chf_1bpp => 1/4 bpp output required
;       R0 = character code required (PIX_ALLCHARS => all)
; Out   VS => R0 -> error block
;       VC => vdu output directed to sprite (if R0 <> 0)
;       R0-R3 = previous output-to-sprite settings
;       R0=0 => no sprite because character not defined
;       R0=1 => no sprite because character is less than 1*1 pixels
;       R6,R8 relocated if necessary
;       [cachefree] -> area to contain output bitmaps
;       [sprite_area] -> sprite area containing sprite
;       [sprite_width] = sprite width (words)
;       [sprite_height] = sprite height (pixels)
;       [scratchblock] -> scratch block for Draw module

outputtosprite  Entry "R4-R5,R7,R9-R11"

        ASSERT  (PIX_ALLCHARS :AND: &1F)=0
        CheckCache "before outputing to sprite"
        AND     R11,R0,#PIX_ALLCHARS :OR: &1F   ; save character index plus 'all' bit

        STR     R0,currentchar                  ; used if remapping

;       ADD     R9,R7,#hdr1_PixelsPtrs
        LDR     R9,[R7,#hdr1_PixoPtr]
        ADD     R9,R9,#pixo_pointers            ; R9 -> outline chunk array (only needed if remapping)

        Debug   cc,"outputtosprite: R0,R6,R4,R8 =",R0,R6,R4,R8

        PushP   "sprite: Save outline chunk ptr",R6

        Debug   bb2,"Font BBox (x,y,w,h) =",#pboxX,#pboxY,#pboxW,#pboxH

        LDRB    R14,charflags
        TST     R14,#chf_1bpp

; Z set => 1-bpp, else 4-bpp

        LDR     R4,pboxW                ; R4 = width (pixels)
        ADDEQ   R3,R4,#3+7              ; add 3 and round up to nearest word
        MOVEQ   R3,R3,LSR #3            ; R3 = width (words)
        ADDNE   R3,R4,#31               ; round up to nearest word
        MOVNE   R3,R3,LSR #5            ; only times 4 if 4-bpp
        STR     R3,sprite_width

        LDR     R7,pboxH                ; R1 = height (rows)
        MOVEQ   R1,R7,LSL #2            ; multiply by 4 (if 4-bpp)
        ADDEQ   R1,R1,#3                ; add 3 for anti-aliasing grid
        ORREQ   R1,R1,#3                ; R1 = 4n + 3 for some n
        MOVNE   R1,R7
        STR     R1,sprite_height

        CMP     R4,#0                   ; give up if ORIGINAL size is null
        CMPGT   R7,#0                   ; if anti-aliasing, we want the supersampled image non-null
        MOVLE   R0,#1                   ; R0=1 on exit => null sprite
        BLE     %FT98

        Debug   bb2,"Sprite width (words), height =",R3,R1

        MUL     R2,R1,R3                ; R2 = number of words in image
        MOV     R7,R2,LSL #2            ; R7 = number of bytes in image
        ADD     R7,R7,#saExten+spPalette

; (finished with Z flag)
; compute upper bound on size of new bitmap chunk

        Push    "R1,R3,R6,R7"           ; h, w, outlines, sprite size

        CMP     R8,#0                   ; if there is an existing block,
        MOVNE   R7,#0                   ; we don't need to allocate a new one
        MOVEQ   R7,#pix_data

        ADD     R6,R6,#pix_index        ; R6 -> index (one chunk only if no remapping)

; if whole chunk to do, start at first char in chunk and set counter to 32

        TST     R11,#PIX_ALLCHARS       ; NE => all chars to be done
        AND     R11,R11,#&1F            ; R11 = 0 if all chars to be done, else char index within chunk
        MOVNE   R5,#32                  ; R5 = counter (32 if all chars being done)
        BNE     %FT01

        BL      outputt_remap           ; R6 -> index, R0 = char offset (uses R10,R11,R6)

        ADD     R7,R7,#std_end          ; allow for the character header
        MOV     R5,#1                   ; just one character to do
        B       %FT11

01      BL      outputt_remap           ; R6 -> index, R0 = offset

11
        Debug   cc,"Outputtosprite: size of R6+R0, count=R5",R6,R0,R5

        TEQ     R0,#0
        BEQ     %FT02
        ADD     R0,R6,R0                ; R0 -> char header
        BL      getbbox                 ; R1-R4 = x,y,w,h for char
        Debug   cc,"char bbox =",R1,R2,R3,R4
        MUL     R2,R3,R4                ; R2 = no of pixels in bitmap
        LDRB    R14,charflags
        TST     R14,#chf_1bpp           ; how big are the output pixels?
        MOVEQ   R2,R2,LSL #2            ; R2 = no of bits in image
        ADD     R2,R2,#7
        ADD     R7,R7,R2,LSR #3         ; R7 += size of image (bytes)
        ADD     R7,R7,#chr_data2        ; be pessimistic about char size

02      SUBS    R5,R5,#1
        ADDNE   R11,R11,#1              ; increment character code
        BNE     %BT01

        ADD     R2,R7,#3                ; word-align at end
        BIC     R2,R2,#3                ; R2 = total size of new block

        Debug   cc :LOR: debugxx,"Total block size =",R2
        Pull    "R1,R3,R6,R7"

; take account of no of subpixel copies

        LDR     R14,[sp]                ; get pixel flags
        TST     R14,#pp_4xposns
        MOVNE   R2,R2,LSL #2            ; multiply by 4 for y-positioning
        TST     R14,#pp_4yposns
        MOVNE   R2,R2,LSL #2            ; multiply by 4 for x-positioning

        Debug   sc3,"PixFlags, Estimated size =",R14,R2
        STR     R2,estimatedsize        ; check this later

      [ debugbrk
        CMP     R7,#saExten+spPalette   ; check for null sprite
        BreakPt "Bad sprite size",LE
      ]

        Debug   bb2,"Sprite area size, new block size =",R7,R2

        MOV     R1,R8                   ; ensure index block is not deleted
        BL      lockblock

        CheckCache "just before reservecache2 for sprite"

        ADD     R6,R7,R2                ; allow for new block + scratch space
        ADD     R6,R6,#scratchsize
        BL      reservecache2           ; relocates R8

        CheckCache "just after reservecache2 for sprite"

        Debug   bb2,"Made it past reservecache2"

        MOV     R1,R8
        BL      unlockblock
        LDR     R1,sprite_height        ; recover this !!!
        BVS     %FT98                   ; sprite indirection failed

        GetReservedBlockAddr R14        ; R14 --> free area

        Debug   sp,"reservecache2 exit: block addr, size, spsize, blksize =",R14,R6,R7,R2

        ADD     R2,R14,R2               ; R2 --> scratch block for Draw
        STR     R2,scratchblock

; now see if we can avoid calling OS_SpriteOp (SwitchOutputToSprite)
; In    R2, R1,R3 = addr, width, height
;       R4,R5,R11 available as work registers

        LDR     R2,fontcacheend
        SUB     R2,R2,R7                ; put sprite at end of cache so it tends not to move

        ADR     R14,sprite_params
        LDMIA   R14,{R4,R5,R11}
        TEQ     R1,R4
        TEQEQ   R2,R5
        TEQEQ   R3,R11
        CacheHit  Sprite, EQ            ; output already to this sprite
        BEQ     %FT98                   ; NB: sprite header may be overwritten, but that's OK
        STMNEIA R14,{R1,R2,R3,R7}       ; save new parameters, then fill in sprite header
        STR     R7,[R2,#saEnd]          ; total size of sprite area

        Debug   cc,"Sprite area is at",R2

        MOV     R14,#1
        STR     R14,[R2,#saNumber]      ; 1 sprite defined
        MOV     R14,#saExten
        STR     R14,[R2,#saFirst]       ; offset to first sprite
        STR     R7,[R2,#saFree]         ; offset to free area (ie. end)

        SUB     R7,R7,#saExten
        ASSERT  spNext = 0
        STR     R7,[R2,#saExten]!       ; R2 -> sprite definition
        MOV     R14,#"x"                ; noddy sprite name
        STR     R14,[R2,#spName]
        MOV     R14,#0
        STR     R14,[R2,#spName+4]
        STR     R14,[R2,#spName+8]
        SUB     R14,R3,#1               ; R14 = width (words - 1)
        STR     R14,[R2,#spWidth]
        SUB     R14,R1,#1               ; R14 = height (rows - 1)
        STR     R14,[R2,#spHeight]
        MOV     R14,#0
        STR     R14,[R2,#spLBit]        ; no left-hand wastage
        MOV     R14,#31
        STR     R14,[R2,#spRBit]        ; no right-hand wastage
        MOV     R14,#spPalette
        STR     R14,[R2,#spImage]
        STR     R14,[R2,#spTrans]
        MOV     R14,#18                 ; mode 18 (1 bpp, 2x2 OS units / pixel)
        STR     R14,[R2,#spMode]

; switch output to sprite, with no save area

        SUB     R1,R2,#saExten
        MOV     R0,#SpriteReason_SwitchOutputToSprite
        ADD     R0,R0,#&200
        MOV     R3,#0                   ; no save area

        Debug   sp,"New sprite parameters =",R0,R1,R2,R3

        ProfIn  Cac_Switch
        STR     R1,sprite_area
        SWI     XOS_SpriteOp
        ProfOut

        MOVVS   R14,#0                  ; it didn't work!
        STRVS   R14,sprite_params_addr
        BVS     %FT98
        LDR     R14,sprite_switchsave   ; only save parameters if not already saved
        TEQ     R14,#0
        ADREQ   R14,sprite_switchsave
        STMEQIA R14,{R0-R3}
                                        ; if we switched to a sprite, R0 will NOT be 0 here
98
        PullP   "sprite: Restore outline chunk ptr",R6
        CheckCache "after outputing to sprite"

        EXIT

;.............................................................................

; In    R6 -> index of outline chunk, if R10=0
;       R9 -> outline chunk array (in master font header)
;       R10 -> mapping table (0 => none)
;       R11 = external character code, or code modulo 32
; Out   R6 -> index of outline chunk
;       R0 = offset from index start to character header (0 if none)

outputt_remap Entry ""

        Debuga  cc2,"outputt_remap: R6,R11 =",R6,R11

        SUBS    R0,R6,#pix_index
        LDRNE   R0,[R6,R11,LSL #2]

        Debug   cc2," chunk,offset",R6,R0

        EXIT

;.............................................................................

; In    [sprite_switchsave] <> 0 => restore output to indicated values
; Out   [sprite_switchsave] = 0, output restored if necessary

restoreoutput PEntryS Cac_Switch, "R0-R3"

        LDR     R14,sprite_switchsave
        TEQ     R14,#0
        ADRNE   R14,sprite_switchsave
        LDMNEIA R14,{R0-R3}
        MOVNE   R14,#0
        STRNE   R14,sprite_switchsave
        STRNE   R14,sprite_params_addr          ; no current output sprite
      [ debugsp
        BEQ     %FT00
        Debug   sp,"Output restored to",R0,R1,R2,R3
00
      ]
        SWINE   XOS_SpriteOp

        PExitS                                  ; preserve error state of caller

;.............................................................................

; In    R3 --> char header
; Out   [charflags] = char flags, except for chf_1bpp (preserved in charflags)
;       R3 --> char outline

getcharheader Entry ""

        LDRB    R14,charflags           ; preserve chf_1bpp bit in charflags
        TST     R14,#chf_1bpp
        LDRB    R14,[R3],#1             ; R14 = flags (outline char)
        BICEQ   R14,R14,#chf_1bpp
        ORRNE   R14,R14,#chf_1bpp
        STRB    R14,charflags

        TST     R14,#chf_outlines       ; if composite, there is no bbox to skip
        TSTNE   R14,#chf_composite1:OR:chf_composite2
        EXIT    NE

        Debug   cc,"Convertpath: char addr, flags =",R3,R14
        TST     R14,#chf_12bit
        ADDEQ   R3,R3,#4                ; 8-bit bounding box
        ADDNE   R3,R3,#6                ; 12-bit bounding box

        EXIT

;.............................................................................

; In    R3 --> character outline (immediately after the header)
;       R4 = character code (0..255)
;       [charflags] set up from character header
;       [pbox] = origin (to be subtracted from coords)
;       [outlinefont] = outline font handle (for obtaining scaffold ptr)
;       [x/ycomponent] = offset for this character component
; Out   R0 = [scratchblock] --> output path, in Draw module format
;       R1 --> next free byte in output path
;       R3 --> byte after input char path terminator

convertcharpath Entry "R2-R11"

; compute scaffold offsets

        Debug   scf2,"Scaffold computing: character code =",R4

        MOV     R14,#0
        ADR     R5,scaffoldoffsets      ; first 8 words are y-scaffolding
        MOV     R6,#15*4                ; next 8 words are x-scaffolding
01      STR     R14,[R5,R6]
        SUBS    R6,R6,#4
        BPL     %BT01

        ASSERT  swb_enabled = 31
        LDR     R14,switch_flags        ; if output switched to buffer,
        BICS    R14,R14,R14,LSL #swb_enabled-swb_scaffold
        BMI     donescaff               ; don't scaffold unless told to

; check rendermatrix to see which of x and y-scaffolding we are interested in

        MVN     R0,#0                   ; no lines known about

        LDR     R6,rendermatrix
        LDMIA   R6,{R1,R3,R6,R14}

        TEQ     R6,#0                   ; ignore x-scaffolding unless it's required
        TEQNE   R14,#0
        BICNE   R0,R0,#&00FF0000

        TEQ     R1,#0                   ; ignore y-scaffolding unless it's required
        TEQNE   R3,#0
        BICNE   R0,R0,#&FF000000

        Debug   scf,"Initial scaffold mask",R0

; get address of scaffold data (must already be cached)

        LDRB    R14,outlinefont         ; must be defined
        LDR     R6,cacheindex
        LDR     R6,[R6,R14,LSL #2]      ; must be defined (already checked)
        LDR     R14,[R6,#hdr1_nscaffolds]
        CMP     R4,R14                  ; only chars 1..R14-1 have scaffold entries
        BHS     donescaff
        LDRB    R1,[R6,#hdr1_flags]
        LDR     R6,[R6,#hdr_Scaffold]
        TEQ     R6,#0
        TEQNE   R4,#0                   ; char 0 can't have any scaffolding
        BEQ     donescaff
        ADD     R6,R6,#std_end          ; R6 -> scaffold index


; R0 = bit mask to say which lines are already known
; R1 = hdr1_flags
; R4 = current character code
; R5 --> scaffold offset array
; R6 --> scaffold table start

        MVN     R2,#0                   ; no lines defined
02
        Debug   scf,"--- Scaffold lines for char",R4
        TST     R1,#pp_bigtable
        ; Load an unsigned halfword from the array
        ; We should really use the LDHA macro for this, but the code that was originally here was a bit to complex for that macro to handle (reliance on R14 being R7<<16, and the delayed branch to getscaff32)
    [ NoARMv4
        ; We can't rely on ARMv4 features (i.e. LDRH)
      [ NoUnaligned
        ; We can't use unaligned loads. Use LDRB instead.
        ADDEQ   R14,R6,R4,LSL #1
        BNE     getscaff32
        LDRB    R7,[R14]
        LDRB    R14,[R14,#1]
        ORR     R7,R7,R14,LSL #8
      |
        ; We can use pre-ARMv6 unaligned load behaviour. Use the original code.
        LDREQ   R7,[R6,R4,LSL #1]
        BNE     getscaff32
      ]
        MOV     R14,R7,LSL #16
        MOVS    R7,R14,LSR #16          ; R7 = bits 0..15
    |
        ; We can just use LDRH
        ; Except LDRH offset + shift is only supported for Thumb 2 :(
        ADDEQ   R14, R6, R4, LSL #1
        BNE     getscaff32
        LDRH    R7, [R14]
        MOVS    R14,R7,LSL #16
    ]

        Debug   scf2," index =",R7
        BEQ     linkscaff               ; all lines done

        TST     R1,#pp_16bitscaff
        BICEQ   R7,R7,#&8000
        TSTEQ   R14,#&8000:SHL:16

08      LDRB    R4,[R7,R6]!             ; R7 --> first byte of structure, R4 = base char
        LDRNEB  R14,[R7,#1]!            ; load second byte of basechar code if 16-bit code
        ORRNE   R4,R4,R14,LSL #8

        ASSERT  scf_basebits=1
        LDRB    R9,[R7,#1]!             ; byte 0 = base x-scaffold bits
        LDRB    R14,[R7,#1]!
        ORR     R9,R9,R14,LSL #8        ; byte 1 = base y-scaffold bits
        LDRB    R14,[R7,#1]!
05      ORR     R9,R9,R14,LSL #16       ; byte 2 = local x-scaffold bits
        LDRB    R14,[R7,#1]!
        ORR     R9,R9,R14,LSL #24       ; byte 3 = local y-scaffold bits

        Debug   scf2,"Line mask =",R9

; R9 bits  0.. 7 ==> x-line is defined in the base char
; R9 bits  8..15 ==> y-line is defined in the base char
; R9 bits 16..23 ==> x-line is defined in the local definition (following)
; R9 bits 24..31 ==> y-line is defined in the local definition (following)

        MOV     R3,#0                   ; R3 = scaffold line index (0..15)
        MOV     R8,#1:SHL:16            ; R8 = bit mask

04      TST     R9,R8                   ; is this line defined locally?
        BEQ     %FT06

        LDRB    R14,[R7,#1]!            ; coord of line (must update R7)
        LDRB    R10,[R7,#1]!
        LDRB    R11,[R7,#1]!            ; width of line

        TST     R0,R8                   ; is this line already done?
        BICNE   R0,R0,R8                ; mark line dealt with
        BICNE   R2,R2,R8                ; mark line defined
        ORRNE   R14,R14,R10,LSL #8      ; save values in [scaffoldoffsets]
        ORRNE   R14,R14,R11,LSL #16     ; bit clear in R2 => line defined
        STRNE   R14,[R5,R3,LSL #2]

06      MOV     R8,R8,LSL #1
        ADD     R3,R3,#1
        CMP     R3,#16
        BNE     %BT04

        MVN     R9,R9,LSL #16           ; invert basechar bits (bits 0..15 set)
        BICS    R0,R0,R9                ; finished if all bits 0
        TEQNE   R4,#0                   ; is there a base char anyway?
        BNE     %BT02

linkscaff
      [ debugscf
        Debuga  scf,"Lines: "
        MOV     R3,#0
        MOV     R9,#1:SHL:16
00      TST     R2,R9,LSL R3
        BNE     %FT10
        Push    "R1-R2"
        SUB     sp,sp,#8
        MOV     R0,R3
        MOV     R1,sp
        MOV     R2,#8
        SWI     XOS_ConvertCardinal1
        BL      Neil_Write0
        ADD     sp,sp,#8
        Pull    "R1-R2"
        MOV     R0,#","
        BL      Neil_WriteC
10      ADD     R3,R3,#1
        CMP     R3,#16
        BCC     %BT00
        MOV     R0,#&7F
        BL      Neil_WriteC
        BL      Neil_NewLine
      ]

; now compute scaffold offsets, taking note of scaffold linkages
; R2 bits 16..31 if clear => line needs to be computed

        MOV     R3,#0
        MOV     R9,#1:SHL:16            ; R9 = bit mask for line 0
07
        Debug   scf,"#### R2,R9,R3 =",R2,R9,R3
        TST     R2,R9,LSL R3            ; bit clear => not done yet
        BLEQ    computescaffold
        ADD     R3,R3,#1
        CMP     R3,#16
        BCC     %BT07

donescaff
        Debug   scf2,"Scaffolding done"

        Pull    "R2-R11,LR"             ; slightly faster than BL, return
        B       convertpath

getscaff32
        LDR     R7,[R6,R4,LSL #2]
        Debug   scf2," index =",R7
        TEQ     R7,#0
        BEQ     linkscaff               ; all lines done

        MOVS    R14,R7,LSR #31          ; C = bit 30, Z = !bit 31
        BIC     R7,R7,#&FF000000
        BCC     %BT08
; no base character
        MOV     R4,#0
        LDRB    R9,[R7,R6]!
        MOV     R9,R9,LSL #16
        B       %BT05

        LTORG

;.............................................................................

; In    R3 --> char path (font mgr format)
;       [charflags] ==> 8- or 12-bit coords
;       [scaffoldoffsets] = scaffold offsets for this char
;       [x/ycomponent] = offset of this component
;       [pbox] = origin (to be subtracted from coords)
; Out   R0 = [scratchblock] --> output path, in Draw module format
;       R1 --> byte after end of path
;       R3 --> byte after char path terminator

convertpath PEntry Cac_Hint, "R2,R4-R11"

        LDR     R1,scratchblock         ; R1 -> output block

      [ debugbrk
        GetReservedBlockAddr R14        ; R14 -> start of 'hole'
        CMP     R1,R14
        BreakPt "Scratch area too low",CC
      ]

        MOV     R14,#0                  ; R3 -> input block (see above)
        STR     R14,[R1]
        MOV     R14,#scratchsize        ; R1!0=0, R1!4=size remaining
        SUB     R14,R14,#8
        STR     R14,[R1,#4]

        LDR     R14,[R1,#4]
        ADD     R4,R1,R14               ; R4 --> end of path - 8

        ADR     R5,drawcodes            ; 0, 2, 8, 6
        ADR     R6,nbytes               ; 4, 12, 12, 28
01
        LDRB    R11,[R3],#1             ; R11 = new segtype / scaffold index
        AND     R14,R11,#3              ; (R10 = old scaffold index)

        LDRB    R2,[R5,R14]             ; R2 = code to put down
        LDRB    R7,[R6,R14]             ; R7 = no of bytes in operation
        ADD     R14,R1,R7
        CMP     R14,R4
        BHI     err_buffoverflow        ; no room in buffer

        Debug   cc2,"Path element",R2
        STR     R2,[R1],#4
        CMP     R7,#12
        BLO     %FT12
        BEQ     %FT11
        BL      convert_xy              ; 1st curve ctrlpt uses old scaffold
        Debuga  cc2,"                     "
        MOV     R10,R11                 ; 2nd curve ctrlpt uses new scaffold
        BL      convert_xy
        Debuga  cc2,"                     "
11      MOV     R10,R11
        BL      convert_xy              ; just one for moveto and lineto
        B       %BT01
12
        SUB     R4,R4,R1                ; R4 = no of bytes remaining
        Debug   cc2," - remaining size =",R4
        STR     R4,[R1],#-4             ; R1 -> terminating 0

        LDRVC   R0,scratchblock         ; for caller's convenience
        PExit

drawcodes       DCB     0, 2, 8, 6
nbytes          DCB     4,12,12,28
                ALIGN

err_buffoverflow
        BL      xerr_buffoverflow
        Pull    "R2,R4-R11,PC"

xerr_buffoverflow
        MOVVS   PC,LR                   ; leave original error alone!

        ADR     R0,ErrorBlock_FontBuffOverflow
        B       MyGenerateError
        MakeInternatErrorBlock FontBuffOverflow,,"BufOFlo"

;.............................................................................

; In    R2 = bit mask (bits 16..31 clear => line not yet done)
;       R3 = index of scaffold line (0..15)
;       R4 = index of link line << 12 (&1000..&7000)
;       R5 -> scaffoldoffsets
;       R9 = 1 << 16
;       R10 bits 0..11 = initial coord of line
; Out   R2 updated
;       R3,R10 preserved
;       R4 = pre-offset due to linked line
;       R11 corrupted

computelink Entry "R3,R4,R10"

        EOR     R4,R3,R4,LSR #12        ; R4 = link (0..15)
        BIC     R4,R4,#8                ; get bit 3 from R3
        Debuga  scf,"Scaffold link from line",R3
        EOR     R3,R4,R3
        Debuga  scf," to",R3
        TST     R2,R9,LSL R3
        LDRNE   R10,[R5,R3,LSL #2]      ; already done
        BLEQ    computescaffold

        LDR     R4,[sp,#1*4]            ; was this a linear link?
        TST     R4,#8:SHL:12
        BEQ     %FT01

        LDR     R4,[R5,-R3,LSL #2]      ; R3 = first link
        EOR     R4,R3,R4,LSR #12        ; R4 = second link
        BIC     R4,R4,#8                ; bit 3 comes from source
        EOR     R4,R4,R3
        AND     R4,R4,#&F               ; bits 4..19 are garbage
        Debug   scf," - and",R4         ; R10 = first offset (o1)
        LDR     R11,[R5,R4,LSL #2]      ; R11 = second offset (o2)
        LDR     R3,[R5,-R3,LSL #2]      ; R3 bits 0..11 = x1
        LDR     R4,[R5,-R4,LSL #2]      ; R4 bits 0..11 = x2
        LDR     R14,[sp,#2*4]           ; R14 bits 0..11 = x
        Debuga  scf,"x,x1,x2 =",R14,R3,R4

        CMP     R3,#WID_LTANGENT:SHL:16 ; if thick line, move to centre
        ADDCC   R3,R3,R3,LSR #17
        CMP     R4,#WID_LTANGENT:SHL:16
        ADDCC   R4,R4,R4,LSR #17
        CMP     R14,#WID_LTANGENT:SHL:16
        ADDCC   R14,R14,R14,LSR #17

        SUB     R14,R14,R4
        MOV     R14,R14,LSL #20
        MOV     R14,R14,ASR #20         ; R14 = x-x2
        SUB     R3,R3,R4
        MOV     R3,R3,LSL #20
        MOVS    R3,R3,ASR #20           ; R3 = x1-x2
        RSBMI   R14,R14,#0
        RSBMI   R3,R3,#0                ; ensure divisor +ve
        Debug   scf,": (x-x2)/(x1-x2) =",R14,R3

        Debuga  scf,"Offset1,2 =",R10,R11
        SUB     R10,R10,R11             ; R10 = o1-o2
        MUL     R14,R10,R14
        CMP     R14,#0
        RSBMI   R14,R14,#0              ; ensure dividend +ve
        SavePSR R0
        DivRem  R4,R14,R3,R10,norem     ; R4 = (o1-o2)(x-x2)/(x1-x2)
        RestPSR R0,,f
        ADDPL   R10,R11,R4
        SUBMI   R10,R11,R4
01
        STR     R10,[sp,#1*4]           ; on exit R4 = pre-offset
        Debug   scf,": offset =",R10
        EXIT

;.............................................................................

; In    R2 = bit mask (bits 16..31 clear => line not yet done)
;       R3 = index of scaffold line (1..7,9..15)
;       R5 -> scaffoldoffsets (15 words before, and 16 after)
;       R9 = 1 << 16
; Out   R10 = scaffold offset
;       R4,R11 corrupted
;       [R5,R3,LSL #2] = scaffold offset (R10)
;       [R5,-R3,LSL #2] = original scaffold coord (R10)

computescaffold Entry ""

        ORR     R2,R2,R9,LSL R3         ; this line done (we hope!)

        Debug   scf,"Computescaffold:",R3

        LDR     R10,[R5,R3,LSL #2]      ; bits 0..11 = coord
        STR     R10,[R5,-R3,LSL #2]     ; needed for linear links
        ANDS    R4,R10,#&F000           ; bits 12..14 = link
        BLNE    computelink             ; recursive

        MOV     R11,R10,LSR #16         ; bits 16..23 = width
        MOV     R10,R10,LSL #20
        MOV     R10,R10,ASR #20         ; sign-extend coord

; R4 = pre-offset due to linked scaffold line
; R10 = coordinate of scaffold line + pre-offset
; R11 = width of scaffold line (254, 255 are special)

        Debuga  scf2,"Line",R3
        Debuga  scf2,": "
        CMP     R3,#8
        BLCC    computescaffoldx
        BLCS    computescaffoldy        ; R10 <-- offset to add for this
        ADD     R10,R10,R4              ; plus the initial offset
        STR     R10,[R5,R3,LSL #2]      ; store the result

        EXIT

;.............................................................................

; In    R4 = scaffold link offset
;       R10 = x-scaffold line coordinate
;       R11 = x-scaffold line width (254, 255 ==> L/R-tangent)
;       [rendermatrix] -> matrix to transform by
; Out   R10 = offset to add to points linked to this (- initial offset)

computescaffoldx EntryS "R1-R6"

        Debug   scf2,"computescaffoldx: R10,R11 = ",R10,R11

        LDRB    R6,charflags

        LDR     R3,rendermatrix
        LDR     R4,[R3,#mat_coordshift]

        MOV     R2,R10,LSL R4           ; R2 = suitably scaled x-coordinate
        LDR     R14,xcomponent
        ADD     R2,R2,R14               ; offset for this composite section

        TST     R6,#chf_1bpp
        MOVEQ   R2,R2,LSL #2            ; multiply by 4 for anti-aliasing

; inspect matrix to see whether input x => output X or Y

        DebugM  matrix,"computescaffoldx: rendermatrix =",R3
        Push    "R0"
        LDR     R14,[R3,#mat_XY]
        TEQ     R14,#0                  ; if y-contribution 0, we can use the x-contribution
        LDREQ   R1,[R3,#mat_XX]
        LDRNE   R1,[R3,#mat_YX]
      [ NoARMM
        MOV     R0,R2
        BL      mul_R0_R1               ; preserves flags
        LDREQ   R14,[R3,#mat_X]
        LDRNE   R14,[R3,#mat_Y]
        ADD     R2,R0,R14               ; R2 = output x/y-coordinate
      |
        SMULL   R0,R2,R1,R2
        LDREQ   R14,[R3,#mat_X]
        LDRNE   R14,[R3,#mat_Y]
        ADD     R0,R14,R0,LSR #16
        ADD     R2,R0,R2,LSL #16        ; R2 = output x/y-coordinate
      ]
        Pull    "R0"

; R2 = coordinate as it would have been without any scaffolding

        LDR     R14,[sp,#Proc_RegOffset+3*4]
        ADD     R2,R2,R14               ; add scaffold link offset

        TEQ     R11,#WID_LTANGENT
        BEQ     do_ltangent

        TEQ     R11,#WID_RTANGENT
        BEQ     do_rtangent

; x = transform(x)
; h1 = transform(h)
; h = -h1 & 0xFF
; if h1>64 and h>=192 then h -= 256
; answer = (((x-(h>>1)+(1<<7)) & ~0xFF) + (h>>1) - x) << 1

        MOV     R0,R11,LSL R4
        MOV     R5,R2,ASR #1            ; R5 is now in 1/256ths of a pixel
      [ NoARMM
        BL      mul_R0_R1
        MOVS    R2,R0                   ; -ve width => munge coords
      |
        SMULL   R0,R2,R1,R0
        MOV     R0,R0,LSR #16
        ADDS    R2,R0,R2,LSL #16        ; -ve width => munge coords
      ]
        RSBMI   R2,R2,#0
        SUBMI   R5,R5,R2,ASR #1         ; R5 = lower of the two coords

        Debuga  scf2,"scaled x,w*2 =",R5,R2

        MOV     R4,R2,ASR #2
        CMP     R4,#64/2+1       ; if line is wide enough,
        RSB     R4,R4,#0
        AND     R4,R4,#&7F              ; R4 = (-(scaled width) AND &FF) / 2
        CMPGE   R4,#192/2
        SUBGE   R4,R4,#256/2     ; round down if width:AND:255 < 256/4

        Debuga  scf2," w>>1 & 0xFF =",R4

        SUB     R14,R5,R4               ; x-(h>>1)
        ADD     R14,R14,#1:SHL:7        ; + (1<<7)
        BIC     R14,R14,#&FF            ; & ~0xFF
        ADD     R14,R14,R4              ; + (h>>1)
        SUB     R14,R14,R5              ; - x
        MOV     R10,R14,LSL #1          ; << 1
        Debug   scf2," offset =",R10
        EXITS

; x = transform(x)
; answer = ((x+(4<<6)) & ~0x1FF) + (1<<6) - x

do_ltangent
        TEQ     R1,#0                   ; if multiplier was -ve, swap over
        BMI     do_rtangent2
do_ltangent2
        MOV     R3,#4:SHL:6             ; cut off at 1/2 way
        MOV     R5,#1:SHL:6             ; move to 1/8 to right of boundary
        B       %FT01

; x = transform(x)
; answer = ((x-(3<<6)) & ~0x1FF) + (7<<6) - x

do_rtangent
        TEQ     R1,#0                   ; if multiplier was -ve, swap over
        BMI     do_ltangent2
do_rtangent2
        MOV     R3,#-4:SHL:6            ; cut off at 1/2 way
        MOV     R5,#7:SHL:6             ; move to 7/8 to right of boundary
01
        ADD     R10,R2,R3               ; x +- (3<<6)
        BIC     R10,R10,#&100
        BIC     R10,R10,#&0FF           ; & ~&1FF
        ADD     R10,R10,R5              ; + (1<<6) or (7<<6)
        SUB     R10,R10,R2              ; - x
        Debug   scf2," (L/R) offset =",R10
        EXITS

;.............................................................................

; In    R4 = scaffold link offset
;       R10 = y-scaffold line coordinate
;       R11 = y-scaffold line height (254, 255 ==> D/U-tangent)
;       [rendermatrix] -> matrix to transform by
; Out   R10 = offset to add to points linked to this (- initial offset)

computescaffoldy EntryS "R1-R6"

        Debug   scf2,"computescaffoldy: R10,R11 =",R10,R11

        LDRB    R6,charflags

        LDR     R2,rendermatrix
        LDR     R4,[R2,#mat_coordshift]

        MOV     R3,R10,LSL R4           ; R3 = suitably scaled y-coordinate
        LDR     R14,ycomponent
        ADD     R3,R3,R14               ; add offset for this component

        TST     R6,#chf_1bpp
        MOVEQ   R3,R3,LSL #2            ; multiply by 4 for anti-aliasing

; inspect matrix to see whether input y => output X or Y

        DebugM  matrix,"computescaffoldy: rendermatrix =",R2
        Push    "R0"
        LDR     R14,[R2,#mat_XX]
        TEQ     R14,#0                  ; if x-contribution is 0, we can use the y-contribution
        LDREQ   R1,[R2,#mat_XY]
        LDRNE   R1,[R2,#mat_YY]
      [ NoARMM
        MOV     R0,R3
        BL      mul_R0_R1               ; preserves flags
        LDREQ   R14,[R2,#mat_X]
        LDRNE   R14,[R2,#mat_Y]
        ADD     R3,R0,R14               ; R3 = output x/y-coordinate
      |
        SMULL   R0,R3,R1,R3
        LDREQ   R14,[R2,#mat_X]
        LDRNE   R14,[R2,#mat_Y]
        ADD     R0,R14,R0,LSR #16
        ADD     R3,R0,R3,LSL #16        ; R3 = output x/y-coordinate
      ]
        Pull    "R0"

        LDR     R14,[sp,#Proc_RegOffset+3*4]
        ADD     R3,R3,R14               ; add scaffold link offset

        TEQ     R11,#WID_LTANGENT
        BEQ     do_dtangent

        TEQ     R11,#WID_RTANGENT
        BEQ     do_utangent

; y = transform(y)
; h1 = transform(h)
; h = -h1 & 0xFF
; if h1>64 and h>=192 then h -= 256
; answer = (((y-(h>>1)+(1<<7)) & ~0xFF) + (h>>1) - y) << 1

        MOV     R0,R11,LSL R4
        MOV     R5,R3,ASR #1            ; R5 is now in 1/256ths of a pixel
      [ NoARMM
        BL      mul_R0_R1
        MOVS    R3,R0                   ; -ve width => munge coords
      |
        SMULL   R0,R3,R1,R0
        MOV     R0,R0,LSR #16
        ADDS    R3,R0,R3,LSL #16        ; -ve width => munge coords
      ]
        RSBMI   R3,R3,#0
        SUBMI   R5,R5,R3,ASR #1         ; R5 = lower of the two coords

        Debuga  scf2,"scaled y,h*2 =",R5,R3

        MOV     R4,R3,ASR #2
        CMP     R4,#64/2+1       ; if line is wide enough,
        RSB     R4,R4,#0
        AND     R4,R4,#&7F              ; R4 = (-(scaled width) AND &FF) / 2
        CMPGE   R4,#192/2
        SUBGE   R4,R4,#256/2     ; round down if width:AND:255 < 256/4

        Debuga  scf2," h>>1 & 0xFF =",R4

        SUB     R14,R5,R4               ; x-(h>>1)
        ADD     R14,R14,#1:SHL:7        ; + (1<<7)
        BIC     R14,R14,#&FF            ; & ~0xFF
        ADD     R14,R14,R4              ; + (h>>1)
        SUB     R14,R14,R5              ; - x
        MOV     R10,R14,LSL #1          ; << 1
        Debug   scf2," offset =",R10
        EXITS

; y = transform(y)
; answer = ((y+(3<<6)) & ~0x1FF) + (1<<6) - y

do_dtangent
        TEQ     R1,#0                   ; if multiplier was -ve, swap over
        BMI     do_utangent2
do_dtangent2
        MOV     R2,#4:SHL:6             ; cut off at 1/2 way
        MOV     R5,#1:SHL:6             ; move to 1/8 above boundary
        B       %FT01

; y = transform(y)
; answer = ((y-(3<<6)) & ~0x1FF) + (7<<6) - y

do_utangent
        TEQ     R1,#0                   ; if multiplier was -ve, swap over
        BMI     do_dtangent2
do_utangent2
        MOV     R2,#-4:SHL:6            ; cut off at 1/2 way
        MOV     R5,#7:SHL:6             ; move to 7/8 above boundary
01
        ADD     R10,R3,R2               ; +- (3<<6)
        BIC     R10,R10,#&100
        BIC     R10,R10,#&0FF           ; & ~&1FF
        ADD     R10,R10,R5              ; + (1<<6) or (7<<6)
        SUB     R10,R10,R3              ; - y
        Debug   scf2," (D/U) offset =",R10
        EXITS

;.............................................................................

; In    R1 -> output buffer (Draw module format)
;       R3 -> input buffer (outline char format)
;       R10 bits 2..4 = x-scaffold index
;       R10 bits 5..7 = y-scaffold index
;       [charflags] :AND: chf_12bit ==> 12-bit coords, else 8-bit
;       [pbox] = origin (to be subtracted from coords)
;       [antialiasx/y] = offset to add if anti-aliasing
;       [x/ycomponent] = offset to add to coords before processing
; Out   format converted, coords multiplied by [rendermatrix]

convert_xy Entry "R2,R4,R6"

        MOV     R4,R1                   ; R4 -> output path
        MOV     R6,R3                   ; R6 -> input path

        BL      getcoordpair            ; R6 -> input path, R2,R3 <= answer

        LDR     R14,xcomponent          ; shifted by appropriate amount
        ADD     R2,R2,R14
        LDR     R14,ycomponent
        ADD     R3,R3,R14

        LDR     R1,rendermatrix
        BL      transformpt             ; 1-bpp is at actual size

        Debug   matrix,"convert_xy: x,y,ox,oy =",R2,R3,#pboxX,#pboxY

        LDR     R14,pboxX
        SUB     R2,R2,R14,LSL #9        ; correct for origin

        LDR     R14,pboxY
        SUB     R3,R3,R14,LSL #9        ; correct for origin

        LDRB    R14,charflags
        TST     R14,#chf_1bpp
        BNE     %FT02

01      MOV     R2,R2,LSL #2            ; multiply by 4
        MOV     R3,R3,LSL #2

        LDRB    R14,antialiasx
        ADD     R2,R2,R14,LSL #9        ; add x-offset (pixels)
        ADD     R2,R2,#2:SHL:9          ; range from -2..1 rel. to grid centre

        LDRB    R14,antialiasy
        ADD     R3,R3,R14,LSL #9        ; add y-offset (pixels)
        ADD     R3,R3,#2:SHL:9          ; range from -1..2 rel. to grid centre

02
        Debug   matrix,"convert_xy: x,y after anti-aliasing =",R2,R3

        Push    "R4,R5"

        ADR     R14,scaffoldx
        AND     R4,R10,#7:SHL:2
        LDR     R4,[R14,R4]             ; R4 = x-scaffold offset

        ADR     R14,scaffoldy
        AND     R5,R10,#7:SHL:5
        LDR     R5,[R14,R5,LSR #3]      ; R5 = y-scaffold offset

        LDR     R14,[R1,#mat_XX]        ; R1 -> render matrix (from above)
        LDR     R1,[R1,#mat_YY]

        TEQ     R14,#0
        DebugSc scf,"x",R2,R10,R4,R5,EQ
        ADDNE   R2,R2,R4                ; output x depends on input x
        ADDEQ   R2,R2,R5                ; output x depends on input y

        TEQ     R1,#0
        DebugSc scf,"y",R3,R10,R4,R5,NE
        ADDEQ   R3,R3,R4                ; output y depends on input x
        ADDNE   R3,R3,R5                ; output y depends on input y

        Pull    "R1,R5"                 ; R1 := old R4

        STMIA   R1!,{R2,R3}             ; R1 -> output path
        MOV     R3,R6                   ; R3 -> input path

        EXIT

;.............................................................................

; In    R6 -> input path
;       [charflags] :AND: chf_12bit => 12-bit coords, else 8-bit
; Out   R2,R3 = coordinate (sign-extended)
;       R6 updated

getcoordpair Entry ""

        LDRB    R14,charflags
        TST     R14,#chf_12bit
        BEQ     get8bit                 ; less common case

        LDRB    R2,[R6],#1              ; bits 0..7 of x
        LDRB    R3,[R6],#1              ; bits 8..11 of x, bits 0..3 of y
        LDRB    R14,[R6],#1             ; bits 4..11 of y

        Debug   matrix,"getcoordpair: b0,b1,b2 =",R2,R3,R14

        MOV     R3,R3,ROR #4            ; bits 8..11 of x in bits 28..31, bits 0..3 of y in bits 0..3
        ORR     R2,R2,R3,ASR #20        ; R2 = sign-extended x-coord

        AND     R3,R3,#&F               ; bits 0..3 of y
        MOV     R14,R14,LSL #24         ; bits 4..11 of y, in bits 24..31
        ORR     R3,R3,R14,ASR #20       ; R3 = sign-extended y-coord

        Debug   matrix,"getcoordpair: R2,R3 =",R2,R3

        EXIT

get8bit
        LDRB    R2,[R6],#1
        MOV     R2,R2,LSL #24
        MOV     R2,R2,ASR #24           ; R2 = sign-extended x-coord << 9

        LDRB    R3,[R6],#1
        MOV     R3,R3,LSL #24
        MOV     R3,R3,ASR #24           ; R3 = sign-extended y-coord << 9

        EXIT

;.............................................................................

; Scan data, eliminating unused outer rows/columns and reversing vertically
;
; In    R1 -> sprite data (rows from top to bottom, word-aligned, all bits used)
;       R2,R3 = line length (bytes), number of rows
;       R4 -> output buffer
;       [pbox] = origin, width, height of font bbox
; Out   [R4..] = new char bbox, data
;       R4 -> word after end of char
;       R4=0 ==> char was completely null

stripoff PEntry Cac_Strip, "R1-R3,R5-R11"

        Debug   cc,"Skip top blank rows: R1,R2,R3 =",R1,R2,R3

      [ debugbrk
        CMP     R2,#0                   ; if either dimension is <= 0, we've got problems
        CMPGT   R3,#0
        BreakPt "Invalid sprite passed to stripoff",LE
      ]

01      LDR     R14,[R1],#4             ; skip top blank rows
        TEQ     R14,#0
        BNE     %FT11
        SUBS    R2,R2,#4
        BNE     %BT01

        LDR     R2,[sp,#1*4]
        SUBS    R3,R3,#1                ; one less row to worry about
        STRNE   R1,[sp]
        BNE     %BT01
14
        Debug   cc,"Blank char"
        MOV     R4,#0
        PExit

11      LDMIA   sp,{R1,R2}              ; R1 = start of top (non-blank) row
        STR     R3,[sp,#2*4]            ; R3 = no of rows now in sprite
        MOV     R5,#0                   ; R5 = x-origin (bits)
        MUL     R6,R3,R2                ; R6 = byte offset from top to bottom

        Debug   cc,"Skip left-hand wastage: R1,R2,R3 =",R1,R2,R3

02      LDR     R3,[sp,#2*4]
        MOV     R0,#0                   ; NB we MUST find some non-null bits
21      LDR     R14,[R1],R2
        ORR     R0,R0,R14
        SUBS    R3,R3,#1
        BNE     %BT21

        TEQ     R0,#0
        ADDEQ   R1,R1,#4
        SUB     R1,R1,R6                ; back to the top row
        ADDEQ   R5,R5,#32
        BEQ     %BT02

        Push    "R0"                    ; keep R0 in case left word = right
        MOVS    R14,R0,LSL #16          ; least-significant bits are on left
        ADDEQ   R5,R5,#16
        MOVEQ   R0,R0,LSR #16
        MOVS    R14,R0,LSL #24
        ADDEQ   R5,R5,#8
        MOVEQ   R0,R0,LSR #8
        MOVS    R14,R0,LSL #28
        ADDEQ   R5,R5,#4                ; R5 = no of 0 bits on the left
        MOVEQ   R0,R0,LSR #4

        LDRB    R14,charflags           ; more finely divided if 1-bpp
        TST     R14,#chf_1bpp
        BEQ     %FT01
        MOVS    R14,R0,LSL #30
        ADDEQ   R5,R5,#2
        MOVEQ   R0,R0,LSR #2
        MOVS    R14,R0,LSL #31
        ADDEQ   R5,R5,#1
01
        Pull    "R0"

        MOV     R7,#0                   ; R7 = no of blank pixels on the right

        LDR     R14,[sp,#0*4]           ; R14 -> top left of area
        ADD     R14,R14,R2
        SUB     R14,R14,#4              ; R14 -> last word of top row
        TEQ     R14,R1
        BEQ     %FT33                   ; we've already reached this stage

        MOV     R1,R14

      [ debugcc
        LDR     R3,[sp,#2*4]
        Debug   cc,"Skip right-hand wastage: R1,R2,R3 =",R1,R2,R3
      ]

03      LDR     R3,[sp,#2*4]            ; recover no of rows left
        MOV     R0,#0                   ; NB we MUST find some non-null bits
31      LDR     R14,[R1],R2
        ORR     R0,R0,R14
        SUBS    R3,R3,#1
        BNE     %BT31

        TEQ     R0,#0
        SUBEQ   R1,R1,#4
        SUB     R1,R1,R6                ; back to the top row
        ADDEQ   R7,R7,#32
        BEQ     %BT03

33      MOVS    R14,R0,LSR #16          ; most-significant bits are on right
        ADDEQ   R7,R7,#16
        MOVEQ   R0,R0,LSL #16
        MOVS    R14,R0,LSR #24
        ADDEQ   R7,R7,#8
        MOVEQ   R0,R0,LSL #8
        MOVS    R14,R0,LSR #28
        ADDEQ   R7,R7,#4                ; R7 = no of 0 bits on the right
        MOVEQ   R0,R0,LSL #4

        LDRB    R14,charflags           ; more finely divided if 1-bpp
        TST     R14,#chf_1bpp
        BEQ     %FT01
        MOVS    R14,R0,LSR #30
        ADDEQ   R7,R7,#2
        MOVEQ   R0,R0,LSL #2
        MOVS    R14,R0,LSR #31
        ADDEQ   R7,R7,#1
01
        LDR     R1,[sp,#0*4]
        ADD     R1,R1,R6
        SUB     R1,R1,R2                ; R1 -> start of bottom row
        STR     R1,[sp,#0*4]            ; new value on stack = bottom row
        LDR     R3,[sp,#2*4]

        Debug   cc,"Skip blank rows at bottom: R1,R2,R3 =",R1,R2,R3

04      LDR     R14,[R1],#4
        TEQ     R14,#0
        BNE     %FT41
        SUBS    R2,R2,#4
        BNE     %BT04

        LDR     R2,[sp,#1*4]
        SUB     R3,R3,#1                ; can't run out of rows this time!
        SUB     R1,R1,R2,LSL #1         ; R1 -> start of next row up
        STR     R1,[sp]
        B       %BT04

41      LDMIA   sp,{R1,R2}              ; R1 = start of bottom (non-blank) row

        Push    "R3,R8-R10"             ; R14,R8,R9,R10,R3 = flags,x,y,w,h

        LDRB    R14,charflags
        ANDS    R14,R14,#chf_1bpp       ; not packed, 8-bit coords

        LDR     R8,pboxX
        ADDEQ   R8,R8,R5,LSR #2         ; adjust x-origin by R5/4 pixels
        ADDNE   R8,R8,R5                ; correct for 1- or 4-bpp

        LDR     R9,[sp,#6*4]
        SUB     R9,R9,R3                ; R9 = no of rows skipped at bottom
        LDR     R0,pboxY
        ADD     R9,R0,R9                ; adjust x-origin by no of rows skipped

        ADDEQ   R10,R2,R2               ; R10 = original width (pixels)
        SUBEQ   R10,R10,R5,LSR #2
        SUBEQ   R10,R10,R7,LSR #2       ; subtract left and right wastage
        MOVNE   R10,R2,LSL #3
        SUBNE   R10,R10,R5
        SUBNE   R10,R10,R7              ; correct for 1- or 4-bpp

        Debug   cc,"New char x,y,w,h =",R8,R9,R10,R3

        MOV     R0,R8,LSL #24           ; see if they will fit in 8 bits
        TEQ     R8,R0,ASR #24
        MOVEQ   R0,R9,LSL #24
        TEQEQ   R9,R0,ASR #24
        MOVEQ   R0,R10,LSL #24
        TEQEQ   R10,R0,ASR #24
        MOVEQ   R0,R3,LSL #24
        TEQEQ   R3,R0,ASR #24
        ORRNE   R14,R14,#chf_12bit

        MOVNE   R0,#&F                  ; mask
        STRB    R14,[R4],#1
        STRB    R8,[R4],#1              ; R8 = x (8 or 12 bits)
        ANDNE   R14,R0,R8,ASR #8
        ORRNE   R9,R14,R9,LSL #4
        STRB    R9,[R4],#1              ; R9 = y (8 or 12 bits)
        MOVNE   R14,R9,ASR #8
        STRNEB  R14,[R4],#1
        STRB    R10,[R4],#1             ; R10 = w (8 or 12 bits)
        ANDNE   R14,R0,R10,ASR #8
        ORRNE   R3,R14,R3,LSL #4
        STRB    R3,[R4],#1              ; R3 = h (8 or 12 bits)
        MOVNE   R14,R3,ASR #8
        STRNEB  R14,[R4],#1

        Pull    "R3,R8-R10"

        Debug   cc,"Scan char: R1,R2,R3, l,r wastage =",R1,R2,R3,R5,R7

        RSB     R11,R7,R2,LSL #3
        SUB     R11,R11,R5              ; R11 = no of (useful) bits per row
        MOV     R8,R5,LSR #5            ; R8 = no of words to skip on left
        ADD     R6,R8,R7,LSR #5         ; R6 = no of words to skip on l/r
        MOV     R6,R6,LSL #2            ;      convert to bytes
        SUB     R6,R6,R2,LSL #1         ; R6 = offset between rows
        ADD     R6,R6,#4                ; correct for the word in the middle
        LDR     R2,[R1,R8,LSL #2]!      ; R1 -> first useful word of bottom row
        AND     R5,R5,#31               ; R5 = next bit in input word
        RSB     R9,R5,#32               ; R9 = 32-r5
        AND     R8,R4,#3
        LDR     R0,[R4,-R8]!            ; R0 = output word
        MOV     R8,R8,LSL #3            ; R8 = next bit in output word
        RSB     R14,R8,#32
        MOV     R0,R0,LSL R14           ; remove garbage bits
        MOV     R0,R0,LSR R14

        Debug   cc,"Regs 1,2,3,4 :",R1,R2,R3,R4
        Debug   cc,"Regs 5,6,11  :",R5,R6,R11

51
        MOV     R7,R11                  ; R7 = bits remaining on this row
        RSB     R10,R8,#32              ; R10= 32-r8
52
        MOV     R14,R2,LSR R5
        SUBS    R7,R7,#32               ; less than 32 bits left?
        BLE     %FT53
        LDR     R2,[R1,#4]!             ; r2 <- next input word
        ORR     R14,R14,R2,LSL R9       ; r14 <- r2 << 32-r5
        ORR     R0,R0,R14,LSL R8        ; (must complete output word)
        STR     R0,[R4],#4
        MOV     R0,R14,LSR R10          ; r0 <- r14 >> 32-r8
        B       %BT52
53
        CMN     R7,R5                   ; does R14 have r7+32 bits in it yet?
        LDRGT   R2,[R1,#4]!             ; get last word
        ORRGT   R14,R14,R2,LSL R9       ; now R14 has R7+32 bits in it
        ORR     R0,R0,R14,LSL R8        ; put into output word
        ADDS    R8,R8,R7                ; does this complete the word?
        STRGE   R0,[R4],#4              ; yes
        MOVGE   R0,R14,LSR R10          ; keep the remainder (32-oldR8 done)
        ADDLT   R8,R8,#32
        SUBS    R3,R3,#1
        LDRNE   R2,[R1,R6]!             ; get first word of next row
        BNE     %BT51
        CMP     R8,#0                   ; if last word not null,
        STRGT   R0,[R4],#4              ; store it!

        Debug   cc,"Done it! - R4 =",R4

        LDR     R1,scratchblock
        CMP     R4,R1                   ; have we overflowed?
        PExit   LS

        BreakPt "Scaling outlines to bitmaps has run out of room"

        BL      xerr_FontCacheFull
        PExit

;;----------------------------------------------------------------------------
;; Debugging routines to display sprite contents
;;----------------------------------------------------------------------------

      [ debugcc

showsprite1bpp  ROUT
        EntryS  "R0-R7"

        MOV     R0,#SpriteReason_SwitchOutputToSprite
        MOV     R1,#0
        MOV     R2,#0
        MOV     R3,#0
        SWI     XOS_SpriteOp            ; back to the screen

        MOV     R0,#SpriteReason_PutSpriteScaled
        ADD     R0,R0,#&200
        LDR     R1,sprite_area
        ADD     R2,R1,#saExten
        MOV     R3,#0
        MOV     R4,#0
        MOV     R5,#0
        MOV     R6,#0
        ADR     R7,dbg1
        SWI     XOS_SpriteOp
        B       dbg2
dbg1
        DCB     0,7
        ALIGN
dbg2
        MOV     R0,#SpriteReason_SwitchOutputToSprite
        ADD     R0,R0,#&200
        LDR     R1,sprite_area
        ADD     R2,R1,#saExten
        MOV     R3,#0
        SWI     XOS_SpriteOp

        EXITS


showsprite4bpp  ROUT
        EntryS  "R0-R7"

        MOV     R0,#SpriteReason_SwitchOutputToSprite
        MOV     R1,#0
        MOV     R2,#0
        MOV     R3,#0
        SWI     XOS_SpriteOp            ; back to the screen

        MOV     R0,#SpriteReason_PutSpriteScaled
        ADD     R0,R0,#&200
        LDR     R1,sprite_area
        ADD     R2,R1,#saExten
        MOV     R14,#20
        STR     R14,[R2,#spMode]
        MOV     R3,#640
        MOV     R4,#0
        MOV     R5,#0
        MOV     R6,#0
        ADR     R7,dbg1a
        SWI     XOS_SpriteOp
        B       dbg2a
dbg1a
        DCB     0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7
        ALIGN
dbg2a
        MOV     R14,#18
        STR     R14,[R2,#spMode]

        MOV     R0,#SpriteReason_SwitchOutputToSprite
        ADD     R0,R0,#&200
        LDR     R1,sprite_area
        ADD     R2,R1,#saExten
        MOV     R3,#0
        SWI     XOS_SpriteOp

        EXITS
      ]


;;----------------------------------------------------------------------------
;; Debugging routines
;;----------------------------------------------------------------------------

      [ debugprofile

; In    R0 = profile section indicator
;       R12 -> workspace
; Out   previous profile indicator and start time stacked
;       current profile indicator set to R0

profile_in      ROUT
        EntryS  "R0-R2"

        LDR     R2, profiler_workspace
        TEQ     R2, #0
        EXITS   EQ

        LDR     R1, profile_current             ; R1 = previous profile indicator
        LDR     R14, profile_SP
        STR     R1, [R14], #4
        STR     R14, profile_SP

        STR     R0, profile_current

        MOV     R1, R0
        MOV     LR, PC
        LDR     PC, profiler_setindex

        EXITS   VC

        Debuga  profile,"Error from profile_in: "
        ADD     R0,R0,#4
        BL      Neil_Write0
        BL      Neil_NewLine

        EXITS

; In    R0 = expected current profile section indicator
;       R12 -> workspace
;       previous profile indicator and start time stacked
; Out   previous profile restored
;       Profiler_AddCounter called with appropriate index
;       Debug file is written to if incorrect value current

profile_out     ROUT
        EntryS  "R1-R4"

        LDR     R2, profiler_workspace
        TEQ     R2, #0
        EXITS   EQ

        LDR     R1, profile_current

        CMP     R0, R1
        BEQ     %FT01

        Debuga  profile, "profile_out: current", R1
        Debuga  profile, " expected", R0
        LDR     LR, [sp,#Proc_RegOffset+2*4]
        Debug   profile, ": LR =", LR

01      LDR     R14, profile_SP
        LDR     R1, [R14, #-4]!         ; r1 = previous index
        STR     R14, profile_SP

        STR     R1, profile_current     ; restore previous profile indicator

        MOV     LR, PC
        LDR     PC, profiler_setindex

        EXITS   VC

        Debuga  profile,"Error from profile_out: "
        ADD     R0,R0,#4
        BL      Neil_Write0
        BL      Neil_NewLine

        EXITS
      ]

;----------------------------------------------------------------------
; Debugging routines
;----------------------------------------------------------------------

      [ debugstk

; In    relocSP = top of relocation stack
; Out   spaces printed to debug output depending on depth of stack

debugstk_spaces EntryS "R0,R1"

        LDR     R1,relocSP
        B       dbstksp_altentry

; In    R1 = top of relocation stack
; Out   spaces printed to debug output depending on depth of stack

debugstk_spaces_R1 EntryS "R0,R1"

dbstksp_altentry
        ADRL    R14,relocextra+4
        SUBS    R1,R1,R14
        BLE     %FT02
01
        Debuga  stk," "
        SUBS    R1,R1,#4
        BGT     %BT01
02
        EXITS
      ]

      [ debugbrk

checkrelocfull  EntryS

        LDR     R14,relocSP
        SUB     R14,R14,R12
        SUB     R14,R14,#:INDEX:relocend :AND: &FF00
        CMP     R14,#:INDEX:relocend :AND: &FF
        BreakPt "Relocation stack full",GE

        EXITS
      ]

      [ debug

; In    R1 -> matrix to display contents of

debug_matrix EntryS "R1-R6"

        TEQ     R1,#0
        BNE     %FT01
        Debug   ," <unit matrix>"
        EXITS

01      LDMIA   R1,{R1-R6}
        Debug   ,,R1,R2,R3,R4,R5,R6
        EXITS

; In    R1 -> matrix to display
;       R2 = number of spaces to print to align text

debug_fpmatrix EntryS "R0-R8"

        TEQ     R1,#0
        BNE     %FT02
        Debug   ," <unit matrix>"
        EXITS

02      LDR     R3,[R1,#fmat_XX]
        LDR     R4,[R1,#fmat_YX]
        LDR     R5,[R1,#fmat_XY]
        LDR     R6,[R1,#fmat_YY]
        LDR     R7,[R1,#fmat_X]
        LDR     R8,[R1,#fmat_Y]
        Debug   ,,R3,R4,R5,R6,R7,R8

        MOV     R0,#" "
01      BL      Neil_WriteC
        SUBS    R2,R2,#1
        BGT     %BT01

        LDR     R3,[R1,#fmat_XX+4]
        LDR     R4,[R1,#fmat_YX+4]
        LDR     R5,[R1,#fmat_XY+4]
        LDR     R6,[R1,#fmat_YY+4]
        LDR     R7,[R1,#fmat_X+4]
        LDR     R8,[R1,#fmat_Y+4]
        Debug   ,,R3,R4,R5,R6,R7,R8

        EXITS

        InsertNDRDebugRoutines
      ]

        END

