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
; > MainSWIs

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************
;
; Date       Name  Description
; ----       ----  -----------
; 17-Jun-94  AMcC  Replaced ScratchSpaceSize with ?ScratchSpace
;

;;-----------------------------------------------------------------------------
;; ColourTrans_SetGCOL implementation (new in Version 1.08)
;;
;; Set the current foreground or background colour to the specified physical
;; colour.  This can either be a pattern or a solid colour, using the
;; logical operation passed.
;;
;; in   R0 = physical colour
;;      R3 = flags
;;              bit 7 set => background colour
;;              bit 8 set => generate a dither pattern
;;              all other bits reserved / currently ignored
;;
;;      R4 = logic operation to be performed
;;
;; out  R0 = gcol (not for pattern if bit 8 set on entry)
;;      R2 = depth of current ouput device (as Log2 value)
;;      R3 = flags AND 0x80
;;      R4 preserved
;;-----------------------------------------------------------------------------

      [ :LNOT: usesetcolour
        ! 0,"SetGCOL needs re-coding to *NOT* use OS_SetColour if it is"
        ! 0,"to be used with RISC OS < 3.10"
      ]

setgcflag_DoBackgrond   * 1:SHL:7
setgcflag_DoPattern     * 1:SHL:8

SetOppGCOL_Code ROUT
        Debug   input1,"SetOppGCOL: R0,R3,R4",R0,R3,R4
        Debug   input2,"SetOppGCOL: Palette, f/b, action",R0,R3,R4
        Push    "LR"
        BL      ReturnOppGCOL_Code
        Pull    "LR"
        LDRB    R2,[WP,#CachedL2BPP]    ; R2 on exit contains the depth of the mode
        B       SetColour_Code          ;   and then setup the colour for plotting

SetGCOL_Code Entry   "R1,R4-R7,R10"
        Debug   input1,"SetGCOL: R0,R3,R4",R0,R3,R4
        Debug   input2,"SetGCOL: Palette entry",R0
        Debug   input2,"Flags, GCOL action",R3,R4

        LDRB    R6,[WP,#CachedL2BPP]    ; get the depth of this mode
        AND     R4,R4,#&0F              ;   make sure the logic operation is sensible

        BL      TryCache                ; can we find the entry in the cache?
        MOVEQ   R10,R1                  ;   yes, so pass a sensible cache entry pointer
        BEQ     setgcol_notcache

        Push    "R0,R3-R4"              ; preserve the physical colour
        MOV     R1,#-1                  ;   and attempt to find colour number for the current mode
        MOV     R2,#-1
        BL      ReturnColourNumberForMode_Code
        Pull    "R2"
        BVS     setgcol_exit            ; it went wrong so attempt to tidy up and exit

        TEQ     R6,#3                   ; is the depth of mode interesting?
        MOV     R1,R0
        BLEQ    ColourNumberToGCOL_Code ; if its an 8 bit-per-pixel mode then translate to GCOL
        Swap    R0,R1

        BL      WriteCacheEntry         ; poke the cache entry
        Pull    "R3-R4"                 ; restore the flags and the logic operation

setgcol_notcache
        TST     R3,#setgcflag_DoPattern
        BEQ     setgcol_notpattern      ; if its not setting the pattern then ignore

        CMP     R6,#4
        BGT     setgcol_notpattern      ; dithering not allowed if depth > 16

        Push    "R3-R4"                 ; preserve the flags and action
        ADD     R5,R10,#CachedPattern   ;   always point at the pattern we are going to use

        LDRB    R3,[R10,#CachedPatternValid]
        TEQ     R3,#255
        BNE     setgcol_wehavepattern   ; if we have a pattern then don't bother setup

        STRB    R6,[R10,#CachedPatternValid]

        LDR     R3,[R10,#CacheEntry]
        MOV     R3,R3,LSL #8            ; get the physical colour
        MOV     R4,R6                   ;   and the depth to generate for

        MOV     R0,#-1                  ; attempt to build palette table
        MOV     R1,#-1
        BuildColoursForBest

        TEQ     R4,#0                   ; is it 1 bit-per-pixel
        BLEQ    getpatternmono          ; if it is then get a monochrome pattern
        BEQ     setgcol_wehavepattern

        CMP     R4,#4                   ; is it 16 bit-per-pixel
        BLEQ    getpatterncolour16      ;   if it is then setup the relevant pattern
        BLLT    getpatterncolour

setgcol_wehavepattern
        Pull    "R3-R4"

        LDMIA   R5,{R0-R2,LR}
        Push    "R0-R2,LR"
        Push    "R0-R2,LR"              ; push the pattern to the stack

        AND     R3,R3,#&80              ; get the fg/bg bit
        ORR     R0,R4,R3,LSR #3         ;   and combine with the logical operation
        ORR     R0,R0,#1:SHL:5
        MOV     R1,sp
        SWI     XOS_SetColour

        ADD     sp,sp,#4*8              ; balance the stack for an easy life
        B       setgcol_exit

setgcol_notpattern
        AND     R3,R3,#&80              ; get the fg/bg bit
        ORR     R0,R4,R3,LSR #3         ;   and combine with the logical operation
        LDR     R1,[R10,#CachedColour]
        SWI     XOS_SetColour           ; force the colour to be set

setgcol_exit
        LDRVC   R0,[R10,#CachedGCOL]
        LDRVCB  R2,[WP,#CachedL2BPP]
        Debug   output,"Leaving SetGCOL: GCOL L2BPP",R0,R2
        EXIT


;------------------------------------------------------------------------------
;
; ColourTrans_Return<foo> implementation
;
;   Entry: R0 physical colour
;
;   Exit:  V set   => R0 ->Error block
;          V clear => R0 is either a colour number or GCOL
;
; Attempt to return the closest logical colour to the one specified in R0 based
; on the specified mode and palette.
;
;------------------------------------------------------------------------------

ReturnGCOL_Code ROUT
        Debug   input1,"ReturnGCOL: R0",R0
        Debug   input2,"ReturnGCOL: Palette entry",R0
        Push    "R1-R2,LR"

        BL      TryCache                ;In the cache?
        LDREQ   R0,[R1,#CachedGCOL]
        BEQ     %FT10

        Push    "R0,WP"
        MOV     R1,#-1                  ;Lookup colour in current mode and palette
        MOV     R2,#-1
        BL      ReturnGCOLForMode_Code
        Pull    "R2,WP"                 ;Restore physical colour and workpsace pointer
        BVS     %FT15

        LDRB    R1,[WP,#CachedL2BPP]
        TEQ     R1,#3                   ;In 8BPP modes colour numbers and GCOL values are different
        ASSERT  ModeFlag_FullPalette < 256
        LDREQB  R1,[WP,#CachedModeFlags]
        ;bug fix 11/8/93; was TEQ, so BLEQ wasn't taken for 8bpp non-full clut modes
        TSTEQ   R1,#ModeFlag_FullPalette ;And is it a full palette mode?
        MOV     R1,R0
        BLEQ    GCOLToColourNumber_Code
        BL      WriteCacheEntry         ;Setup a cache entry
        MOV     R0,R1
10
        Debug   xx,"ReturnGCOL returns",R0
15
        Debug   output,"Leaving ReturnGCOL",R0
        Pull    "R1-R2,PC"

ReturnColourNumber_Code ROUT
        Debug   input1,"ReturnColourNumber: R0",R0
        Debug   input2,"ReturnColourNumber: Palette entry",R0
        Push    "R1-R2,LR"

        BL      TryCache                ;In the cache?
        LDREQ   R0,[R1,#CachedColour]
        BEQ     %FT10

        Push    "R0,WP"
        MOV     R1,#-1                  ;Lookup colour in current mode and palette
        MOV     R2,#-1
        BL      ReturnColourNumberForMode_Code
        Pull    "R2,WP"                 ;Restore physical colour and workpsace pointer
        BVS     %FT15

        LDRB    R1,[WP,#CachedL2BPP]
        TEQ     R1,#3                   ;In 8BPP modes colour numbers and GCOL values are different
        ASSERT  ModeFlag_FullPalette < 256
        LDREQB  R1,[WP,#CachedModeFlags]
        TSTEQ   R1,#ModeFlag_FullPalette ;Is it a full clut mode
        MOV     R1,R0                   ;bugfix 10/11/93 TSTEQ was TEQEQ
        BLEQ    ColourNumberToGCOL_Code
        Swap    R0,R1
        BL      WriteCacheEntry         ;Setup a cache entry
10
        Debug   xx,"ReturnColourNumber returns",R0
15
        Debug   output,"Leaving ReturnColourNumber colour number is",R0
        Pull    "R1-R2,PC"

ReturnGCOLForMode_Code ROUT
        Debug   input1,"ReturnGCOLForMode: R0,R1,R2",R0,R1,R2
        Debug   input2,"ReturnGCOLForMode: Palette entry, dest mode/palette",R0,R1,R2
        Push    "R1-R2,LR"
        BL      ReturnColourNumberForMode_Code
        BLVC    ColourNumberToGCOL_Code_testing
        Debug   output,"Leaving ReturnGCOLForMode: GCOL",R0
        Pull    "R1-R2,PC"

;..............................................................................
;
; ReturnColourNumberForMode_Code
;
; This routine looks up the specified physical colour in the specified palette
; and then attempts to return the value.
;
; in    R0 physical colour
;       R1 mode / =-1 for current
;       R2 palette / =-1 for current / =0 for default
;
; out   V =1 => R0 -> error block
;       else,   R0 colour number

ReturnColourNumberForMode_Code ROUT
        Debug   input1,"ReturnColourNumberForMode: R0,R1,R2",R0,R1,R2
        Debug   input2,"ReturnColourNumberForMode: Palette entry, dest mode/palette",R0,R1,R2
        Push    "R0-R2,R6-R8,LR"

        MOV     R6,#ScratchSpace        ;->Temporary buffer to fill with colour table
        MOV     R0,R1                   ;Mode to build table for
        MOV     R1,R2                   ;Palette to build it for
        Pull    "R2"                    ;Restore physical colour to find
        BuildColoursForBest
        GetBestColour VC                ;Build colour table and lookup RGB (returns value into R2)
        MOVVC   R0,R2                   ;Move to suitable register for exit
        Debug   output,"Leaving ReturnColourNumberForMode: Colour",R0
        Pull    "R1-R2,R6-R8,PC"

;------------------------------------------------------------------------------
;
; ColourTrans_ReturnOpp<foo> implementation
;
;   Entry: R0 palette entry
;
;   Exit:  V set   => R0 ->Error block
;          V clear => R0 is either a colour number or GCOL
;
; Attempt to return the oppasite colour to the phsyical palette entry specified
; in R0.  The routines work by calling a common routine for any mode required.
;
;------------------------------------------------------------------------------

ReturnOppGCOL_Code ROUT
        Debug   input1,"ReturnOppGCOL: R0",R0
        Debug   input2,"ReturnOppGCOL: palette entry",R0
        Push    "R1-R2,LR"
        MOV     R1,#-1                  ;Current mode + palette
        MOV     R2,#-1
        BL      ReturnOppGCOLForMode_Code
        Debug   output,"Leaving ReturnOppGCOL, GCOL",R0
        Pull    "R1-R2,PC"

ReturnOppColourNumber_Code ROUT
        Debug   input1,"ReturnOppColourNumber: R0",R0
        Debug   input2,"ReturnOppColourNumber: palette entry",R0
        Push    "R1-R2,LR"
        MOV     R1,#-1                  ;Current mode + palette
        MOV     R2,#-1
        BL      ReturnOppColourNumberForMode_Code
        Debug   output,"Leaving ReturnOppColourNumber, colour",R0
        Pull    "R1-R2,PC"

ReturnOppGCOLForMode_Code ROUT
        Debug   input1,"ReturnOppGCOLForMode: R0-R2",R0,R1,R2
        Debug   input2,"ReturnOppGCOLForMode: palette entry, mode, pal",R0,R1,R2
        Push    "R1-R2,LR"
        BL      ReturnOppColourNumberForMode_Code
        BLVC    ColourNumberToGCOL_Code_testing
        Debug   output,"Leaving ReturnOppGCOLForMode, GCOL",R0
        Pull    "R1-R2,PC"

;..............................................................................
;
; ReturnOppColourNumberForMode_Code
;
; Given the specified physical colour and palette + mode attempt to return
; a colour number based around those values
;
; in    R0 physcial colour &BBGGRR00
;       R1 mode / =-1 if current
;       R2 palette / =-1 if current / =0 if default for mode
;
; out   V =1 => R0 -> error block
;       else,   R0 colour number

ReturnOppColourNumberForMode_Code ROUT
        Debug   input1,"ReturnOppColourNumberForMode: R0-R2",R0,R1,R2
        Debug   input2,"ReturnOppColourNumberForMode: palette entry, mode, pal",R0,R1,R2
        Push    "R0-R2,R6-R8,LR"

        MOV     R6,#ScratchSpace        ;->Temporary buffer to fill with colour table
        MOV     R0,R1                   ;Mode to build table for
        MOV     R1,R2                   ;Palette to build it for
        Pull    "R2"                    ;Restore physical colour to find
        BuildColoursForWorst
        GetWorstColour VC               ;Build colour table and lookup RGB (returns value into R2)
        MOVVC   R0,R2                   ;Move to suitable register for exit
        Debug   output,"Leaving ReturnOppColourNumberForMode, Colour",R0

        Pull    "R1-R2,R6-R8,PC"

;------------------------------------------------------------------------------
;
; ColourTrans_SelectTable / ColourTrans_GenerateTable implementation
;
;   Entry: R0 source mode number / =-1 if current
;             pointer to sprite
;             pointer to mode selector
;             new sprite mode word
;          R1 ->source palette / =-1 for current, 0 for default
;          R2 destination mode / =-1 for current
;          R3 ->destination palette / =-1 for current / =0 for default for mode
;          R4 ->return table / =0 to return size of table
;
;          IF R0 >= &100 THEN
;
;               R0 -> sprite control block
;               R1 -> sprite name (or sprite if R5, bit 0 set)
;
;          IF R0 >= &100 OR ColourTrans_GenerateTable THEN
;
;               R5 flags
;                       bit 0 set => R1 -> sprite, not sprite name (if R0 >= &100)
;                       bit 1 set => if sprite has no palette, use current instead of default
;                       bit 2 set => R6 = workspace pointer for function
;                                    R7 -> transfer function
;
;                       bit 3 set => Return GCOL numbers (rather than colour numbers)
;                       bit 4 set => Generate new style translation tables (for 16/32 bpp)
;
;                       bit 24-31 => return format of the table
;                                       = 0 => return PixTrans table
;                                       = 1 => return physical palette table
;
;                       all other bits reserved
;
;   Exit:  V set   => R0 ->Error block
;          V clear => all preserved
;
; This routine attempts to generate either a colour translation table from
; the specified mode and palette or a sprite.
;
; The buffer size can be read by setting the pointer to zero, this is the
; recomended way of calculating the buffer size, because in the future
; the requirements may change.  For instance when generating conversion
; blocks for 16 or 32BPP.
;
; Under earlier ColourTrans modules R0,R1 could only contain a mode and
; palette pointer, the new interface of sprite and sprite name pointer is
; the suggested way for translating sprites.
;
; R5 contains a flags word where bit 0 is used to control the meaining of
; R1, when set this indicates that R1 is the pointer to a sprite rather
; than the sprite name that has to be resolved.  Bit 1 is used to indicate
; that if the sprite has no palette then perform a translation using the
; current rather than the default for the mode.
;
; If bit 2 is set then it is assumed that R7 is the pointer to a routine
; to call with R0 containing the &BBGGRRxx and R6 contains the workspace
; pointer to pass in R12.  All registers except for R0 and R12 should be
; preserved and R0 should contain the resulting RGB value.
;
; These transfer functions allow the RGB to be remapped prior to it
; being converted to a suitable colour number.
;
;------------------------------------------------------------------------------
;
; From Medusa....
; R0 can be a number of different pointers or values - this is the logic
; used to separate them off:
;
; -1 - use current mode, treat as a mode number/selector
; Below 256 - it is an old screen mode number
; Above 255, and b0 is set - it is a sprite mode word
; Above 255, b0b1=0, first word pointed at has b0 set - it is a mode selector
; Above 255, b0b1=0, first word pointed at has b0 clear - it is a sprite area

tableflag_SpritePointer     * 1:SHL:0
tableflag_UseCurrentPalette * 1:SHL:1
tableflag_TransferFunc      * 1:SHL:2
tableflag_GCOLnumbers       * 1:SHL:3
tableflag_NewStyle          * 1:SHL:4

tableflag_Allowed           * &FF000000 +tableflag_SpritePointer +tableflag_UseCurrentPalette +tableflag_TransferFunc +tableflag_GCOLnumbers + tableflag_NewStyle

returnop_PixTrans           * 0
returnop_PhysicalRGB        * 1
returnop_MAX                * 2


GenerateTable_Code ROUT
        Debug   input1,"GenerateTable: R0-R7",R0,R1,R2
        Debug   input1,"",R3,R4,R5,R6,R7

        Debug   input2,"GenerateTable: Source mode/palette",R0,R1
        Debug   input2,"Destination mode/palette",R2,R3
        Debug   input2,"Buffer, Flags",R4,R5
        Debug   input2,"Transfer wksp/routine",R6,R7
        Debug   ag,"GenerateTable: Source mode/palette",R0,R1
        Debug   ag,"Destination mode/palette",R2,R3
        Debug   ag,"Buffer, Flags",R4,R5
        Debug   ag,"Transfer wksp/routine",R6,R7
        Push    "R0-R11,LR"

        LDR     LR,=tableflag_Allowed
        BICS    LR,R5,LR
        BNE     selecttable_badflags    ;Reserved flags are non-zero so return now

        MOV     R11,R5

        LDR     R6,=ScratchSpace        ;->Global scratch buffer

        Debug   selecttable,""
        Debug   selecttable,"*** Generatetable R0 on entry: ",R0
        Debug   selecttable,"*** R1-R5 on entry: ",R1,R2,R3,R4,R5

        ;was a mode number, sprite mode word, or mode selector is passed in

        CMP     R0,#-1
        BEQ     selecttable_normal

        CMP     R0,#256
        BCC     selecttable_normal      ;old mode number

        CMP     R0,#&8000               ;used accidentally by wimp
        CMPNE   R0,#256                 ;used by Draw module
        BEQ     selecttable_altentry

        TST     R0,#&01                 ;is bit0 set
        BNE     selecttable_normal      ;it is, so this is a mode word from a sprite

        LDR     R14,[R0]                ;fetch the first word pointed at
        TST     R14,#&01                ;is bit 0 set
        BNE     selecttable_normal      ;it is, so this is a mode selector block

        ;after which, it must be a pointer to a sprite!
        Debug   selecttable,"It's a pointer to a sprite"
        B       selecttable_altentry

SelectTable_Code ROUT
        Push    "R0-R11,LR"

        Debug   input1,"SelectTable: R0-R7",R0,R1,R2
        Debug   input1,"",R3,R4,R5,R6,R7

        Debug   input2,"SelectTable: Source mode/palette",R0,R1
        Debug   input2,"Destination mode/palette",R2,R3
        Debug   input2,"Buffer, Flags",R4,R5
        Debug   input2,"Transfer wksp/routine",R6,R7

        MOV     R11,#0                  ;(will be loaded from R5 after mode tests)
        LDR     R6,=ScratchSpace        ;->Global scratch buffer to be used

        Debug   selecttable,""
        Debug   selecttable,"*** SelectTable R0 on entry: ",R0
        Debug   selecttable,"*** R1-R5 on entry: ",R1,R2,R3,R4,R5
        Debug   ag,""
        Debug   ag,"*** SelectTable R0 on entry: ",R0
        Debug   ag,"*** R1-R5 on entry: ",R1,R2,R3,R4,R5

        CMP     R0,#-1
        BEQ     selecttable_normal

        CMP     R0,#256
        BCC     selecttable_normal      ;old mode number

        TST     R0,#&01                 ;is bit0 set
        BNE     selecttable_normal      ;it is, so this is a mode word from a sprite

        CMP     R0,#&8000               ;used accidentally by wimp
        CMPNE   R0,#256                 ;used by Draw module
        BEQ     %FT95

        LDR     R14,[R0]                ;fetch the first word pointed at
        TST     R14,#&01                ;is bit 0 set
        BNE     selecttable_normal      ;it is, so this is a mode selector block

95
        ; it must be a sprite area
        Debug   selecttable,"It's a sprite area"

        MOV     R11,R5                  ;now set up the flags

        LDR     LR,=tableflag_Allowed
        BICS    LR,R11,LR
        BNE     selecttable_badflags    ;Reserved flags are non-zero so return now

selecttable_altentry
        TST     R11,#tableflag_UseCurrentPalette
        BEQ     selecttable_palettedontcare2

        MOV     R3,#-1                  ;Return size about palette table
        MOV     R2,R1
        MOV     R1,R0
        LDR     R0,=SpriteReason_CreateRemovePalette +256

        TST     R11,#tableflag_SpritePointer
        ADDNE   R0,R0,#256              ;Ensure that if absolute pointer then SpriteOp works again

        Debug   selecttable,"Reason code for SpriteOp",R0
        Debuga  selecttable,"Control block at",R1
        Debug   selecttable," and sprite at",R2

        SWI     XOS_SpriteOp
        BVS     selecttable_return      ;It went wrong so exit before too much damaged is performed

        Debug   selecttable,"Does sprite have a palette?",R3

        TEQ     R3,#0                   ;Does it have a palette?

        BNE     selecttable_palettedontcare

        MOV     R0,R5
        MOV     R1,#-1                  ;Do palette for sprite mode and current palette
        ADD     R2,SP,#CallerR2
        LDMIA   R2,{R2-R4}              ;Get the original entry parameters
        B       selecttable_normal      ;and then build a suitable table based on R0,R1

selecttable_palettedontcare
        LDMIA   SP,{R0-R4}

selecttable_palettedontcare2
        MOV     R2,R6
        LDR     R3,=ScratchSpace +?ScratchSpace
        SUB     R3,R3,R2                ;R2,R3 contain bounds of buffer to fill
        MOV     R4,#0

        TST     R11,#tableflag_SpritePointer
        ORRNE   R4,R4,#1:SHL:0          ;Set bit to indicate R0,R1 are sprite pointers

        Debuga  selecttable,"*** Source mode of palette",R0
        Debug   selecttable," palette block",R1
        Debuga  selecttable,"Buffer from",R2
        Debug   selecttable," to",R3
        Debug   selecttable,"Flags",R4

        ; Determine the bpp for the source mode. If it is 16 or 32 we
        ; also need to know the bpp for the destination. If it is also
        ; 16 or 32 then we return an empty table (but no error). If the
        ; destination's bpp is below 16 we need to generate or find a
        ; 32K table for colour matches.

        ; 16/32 to 16/32 ends here, 16/32 to 8/lower skips the palette
        ; read and continues to be picked up for a 32K table later

        ; first we need the mode number
        STMFD   R13!,{R0-R4}

        CMP     R0,#256
        BCC     got_mode_number
        CMP     R0,#-1
        BEQ     got_mode_number
        CMP     R0,#&8000
        CMPNE   R0,#256
        BEQ     %FT95
        TST     R0,#&01
        BNE     got_mode_number
        LDR     LR,[R0]
        TST     LR,#&01
        BNE     got_mode_number

95
        Push    "r11"
        BL      DecodeSprite
        Pull    "r11"
        STRVS   R0,[R13]
        LDMVSFD R13!,{R0-R4}
        BVS     selecttable_return

got_mode_number
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        CMP     R2,#4
        BCC     input_is_below_16bpp

        ; now for the output.....
        LDR     R0,[SP,#CallerR3+20] ; allow for other stacked registers
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        CMP     R2,#4
        LDMFD   R13!,{R0-R4}
        BCC     selecttable_notable  ; skip the palette read attempt

        ; both are over 8bpp...
        ; never generate a table, but don't give an error either!
        MOV     R10,#0
        B       selecttable_finished

input_is_below_16bpp
        LDMFD   R13!,{R0-R4}

        BL      ReadPalette_Code
        BVS     selecttable_return      ;Return back to the caller

selecttable_notable
        Debug   selecttable,"Reached _notable"
        MOV     R1,R2                   ;->End of table +4
        MOV     R0,R6                   ;->Start of table
        MOV     R6,R1

        ADD     R2,SP,#CallerR2
        LDMIA   R2,{R2-R4}              ;Get the original entry parameters
        B       selecttable_gotsource   ;Continue as required

selecttable_normal
        ;call it even for 32/16 -> 8 or below
        BL      build_colours           ;Build colour table based on mode and palette specified
        BVS     selecttable_return      ;Return otherwise

selecttable_gotsource
        Debuga  selecttable,"Source palette from",R0
        Debug   selecttable," to",R1
        Debug   selecttable,"Flags",R11

        MOV     R5,R0
        MOV     R9,R1                   ;Store pointers to the original table

        ;find whether this is a 32K table case.

        LDR     R10,[SP,#CallerR0]      ;Source mode
        MOV     R7,R2                   ;Dest. mode

        CMP     R10,#256
        BCC     notsprite
        CMP     R10,#-1
        BEQ     notsprite

        CMP     R10,#&8000
        CMPNE   R10,#256
        BEQ     %FT95

        TST     R10,#&01
        BNE     notsprite
        LDR     LR,[R10]
        TST     LR,#&01
        BNE     notsprite

95
        MOV     R8,R4

        MOV     R0,R10
        LDR     R1,[SP,#CallerR1]
        MOV     R4,R11
        BL      DecodeSprite

        MOV     R4,R8
        STRVS   R0,[SP]
        BVS     selecttable_return
        MOV     R10,R0

notsprite
        MOV     R0,R10
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        CMP     R2,#4
        MOVCS   R4,R10                  ;Preserve source mode if we're taking 16bpp route
        MOV     R10,R2                  ;Source log2bpp

        MOV     R0,R7
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0                   ;Dest log2bpp
        STR     R2,[WP,#TargetL2BPP]    ;used only for pixtrans spacing

        Debug   selecttable,"log2bpp in:out",R10,R2

        CMP     R10,#4
        BCC     input_is_below_8bpp

        ;source is 16/32bpp

        CMP     R2,#4
        MOVCS   R10,#0
        BCS     selecttable_finished ; return an empty table
                                     ; no mapping between 16/32 and 16/32bpp

        MOV     R0,R4                ; recover the source mode
        LDR     R2,[SP,#CallerR2]    ; recover the target mode
        LDR     R3,[SP,#CallerR3]    ; recover the palette pointer
        LDR     R4,[SP,#CallerR4]    ; recover the output pointer

        CMP     R4,#0
        MOVEQ   R10,#12
        BLNE    make32Ktable
        B       selecttable_finished

input_is_below_8bpp
        MOV     R0,R7                   ;Do we require a full CLUT table?
        MOV     R1,#VduExt_ModeFlags
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        TST     R2,#ModeFlag_FullPalette
        BICNE   R11,R11,#tableflag_GCOLnumbers

        ;do a safety check in case a sprite with a full palette but an old mode
        ;number was fed through
        SUB     R1, R9, R5
        CMP     R1, #256
        MOVHI   R2, #ModeFlag_FullPalette
        BICHI   R11,R11,#tableflag_GCOLnumbers

        Debug   selecttable,"R2 = ",R2

        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Read the depth of the destination mode
        MOVCS   R2,#0                   ;If it failed then default back to zero
        CMP     R2,#3
        BICNE   R11,R11,#tableflag_GCOLnumbers
        BLE     %FT10
;;
;; This is the backwards compatibility hack, when this bit is clear and the depth
;; of the above mode is > 8 bit-per-pixel then only generate an eight bit per pixel
;; table.  In this case mode 21!
;;

        TST     R11,#tableflag_NewStyle
        MOVEQ   R0,#21
        MOVEQ   R3,#0
        ORREQ   R11,R11,#tableflag_GCOLnumbers
        MOVEQ   LR,#3
        STREQ   LR,[WP,#TargetL2BPP]    ;used only for pixtrans spacing
10
        MOV     R1,R3                   ;Setup values for the destination mode

        BuildColoursForBest
        BVS     selecttable_return      ;Return any errors from building the destination palette

        Debuga  selecttable,"Destination palette from",R0
        Debug   selecttable," to",R1
        Debuga  selecttable,"Source palette from",R5
        Debug   selecttable," to",R9
        Debug   selecttable,"Storing into",R4
        Debug   selecttable,"Temp workspace block stored at",R6

;        [ debugag
;        BL      ag_display_stack
;        ]

        ;this is wrong, because it is the source mode, and we should
        ;be acting on the destination mode. In the past it hasn't
        ;mattered since all possible permutations (ie 8bpp and below)
        ;were all rounded by to a 1byte.
        ; LDR     R7,[WP,#BuildColoursL2BPP]

        LDR     R7,[WP,#TargetL2BPP]

        Debug   selecttable,"target L2BPP is",R7
        MOV     LR,#1
        MOV     R7,LR,LSL R7
        ADD     R7,R7,#7
        MOV     R7,R7,LSR #3            ;Calculate the offset for each the pixtrans values
        Debug   selecttable,"PixTrans offset is",R7

        ;the debug call below -will- corrupt the returned table if old versions of
        ;the debug macros are used, due to their use of OS_CLI.
        ;
        ;If the following ASSERT halts assembly, go and get a newer version
        ;of hdr:ndrdebug

        [ debugselecttable
        [ :LNOT: debug_noscratchspace
          ASSERT debug_noscratchspace
        ]
        ]

        Debug   selecttable,"PixTrans offset",R1

        MOV     R3,R11,LSR #24          ;Get the return format
        CMP     R3,#returnop_MAX        ;And check to see if its kosher
        BGE     selecttable_badflags

        MOV     R10,#0                  ;Size of table generated so far

selecttable_loop
        CMP     R5,R9                   ;End of source table yet?
        BEQ     selecttable_finished    ;Yup, so return out of the loop now

        LDR     R2,[R5],#4              ;Get palette entry

        TST     R11,#tableflag_TransferFunc
        BEQ     selecttable_nofunction  ;No function so don't call one

        Push    "R0,WP"                 ;Preserve the two important registers
        ADD     WP,SP,#(8+CallerR6)     ;Point at the bank of registers to read
        MOV     R0,R2
        MOV     LR,PC                   ;Suitable return address
        LDMIA   WP,{WP,PC}              ;Call the function
        MOV     R2,R0                   ;Restore value back having been processed
        Pull    "R0,WP"                 ;Restore saved registers

; Assuming R3 is not too abusive then despatch and attempt to build
; a return colour

selecttable_nofunction
        MOV     LR,PC                   ;Setup a suitable return address
        ADD     PC,PC,R3,LSL #2         ;Despatch via reason code
        B       selecttable_loop        ;And then loop back until finished

        B       ret_PixTrans
        B       ret_PhysicalRGB

selecttable_finished
        TEQ     R4,#0                   ;Did they ask me to return the size?
        STREQ   R10,[SP,#CallerR4]      ;They did, so setup a suitable return value

selecttable_return
        [ debugselecttable
        CMP R4,#0
        BEQ %FT92
        STMFD R13!,{R0-R10}
        MOV R0,R4
        LDMFD R0,{R1-R4}
        Debug selecttable,"First four words returned ",R1,R2,R3,R4
        LDMFD R13!,{R0-R10}
92
        ]

        STRVS   R0,[SP]                 ;Store the pointer to error block
        [ debugoutput
        Pull    "R0-R11,LR"
        Debug   output,"Selecttable exiting R0-R7",R0,R1,R2
        Debug   output,"",R3,R4,R5,R6,R7
        MOV     PC,LR
        |
        Pull    "R0-R11,PC"
        ]

selecttable_badflags
        ADR     R0,ErrorBlock_CTBadFlags
        BL      LookupError             ;Resolve the token to a suitable error
        B       selecttable_return      ;And then exit returning error back to original caller
        LTORG

        MakeEitherErrorBlock CTBadFlags

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
;
; Return the PixTrans version of the physical colour in R2.
;
; in    R2 = physical colour
;       R4 -> return buffer
;       R7 = log2bpp (depth) >>>> MORE PRECISELY, HOW MANY BYTES TO STORE!
;       R10 = index into return buffer to write at
;       R11 = flags word
; out   R10 updated, all others preserved

ret_PixTrans Entry "R7"

;        Debug   selecttable,"R2 into pixtrans",R2

        GetBestColour                   ;Look up the colour for this mode

;        Debug   selecttable,"Return PixTrans R2,R4",R2,R4
;        Debug   selecttable,"R7,R10,R11",R7,R10,R11

        TST     R11,#tableflag_GCOLnumbers
        [ debuginput1 :LOR: debuginput2 :LOR: debugoutput
        ADRNEL  LR,cntogtable
        |
        ADRNE   LR,cntogtable
        ]
        LDRNEB  LR,[LR,R2,LSR #2]
        ANDNE   R2,R2,#3
        ORRNE   R2,R2,LR,LSL #2         ;Convert to GCOL value if required
10
        TEQ     R4,#0                   ;Should we store a byte?
        STRNEB  R2,[R4,R10]             ;If so then store it
        ADD     R10,R10,#1              ;Increasing the offset for the table
        SUBS    R7,R7,#1                ;Decrease the pixtrans offset (for >8bpp modes)
        MOVNE   R2,R2,LSR #8            ;Rotate to snap the next eight bits if there is more to go
        BNE     %BT10                   ;Looping if still a nice sensible number
        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .
;
; Return the physical colour in R2.
;
; in    R2 = physical colour
;       R4 -> return buffer
;       R10 = index into return buffer to write at
; out   R10 updated, all others preserved

ret_PhysicalRGB
        TEQ     R4,#0                   ;Do we need to write any data?
        STRNE   R2,[R4,R10]             ;If so then write it
        ADD     R10,R10,#4              ;But always increase the index ~ used for returning the size
        MOV     PC,LR

;------------------------------------------------------------------------------
;
; ColourTrans_SelectGCOLTable implementation
;
;   Entry: R0 source mode / =-1 for current
;          R1 -> source palette / =0 for default / =-1 for current
;          R2 destination mode / =-1 for current
;          R3 -> destination palette / =0 for default / =-1 for current
;          R4 -> byte array to be filled
;
;   Exit:  V set   => R0 ->Error block
;          V clear => all preserved
;
; Generate a table of GCOL values, these can then be used in GCOL/Tint
; calls or ColourTrans_SetColour.
;
;------------------------------------------------------------------------------

SelectGCOLTable_Code

        Push    "R5,LR"
        Debug   input1,"SelectGCOLTable: R0-R4",R0,R1,R2,R3,R4
        Debug   input2,"SelectGCOLTable: Source mode/pal",R0,R1
        Debug   input2,"Dest. mode/pal, flags",R2,R3,R4
        MOV     R5,#tableflag_GCOLnumbers
        BL      GenerateTable_Code      ; using common routine generate GCOL numbers
        Debug   output,"Leaving SelectGCOLTable R0-R4",R0,R1,R2,R3,R4
        Pull    "R5,PC"

;------------------------------------------------------------------------------
;
; ColourTrans_GCOLToColourNumber implementation
;
;   Entry: R0 GCOL number
;
;   Exit:  V set   => R0 ->Error block
;          V clear => R0 colour number
;
; Convert a GCOL to a colour number.
;
;------------------------------------------------------------------------------

GCOLToColourNumber_Code ROUT
        Debug   input1,"GCOLToColourNumber: R0",R0
        Debug   input2,"GCOLToColourNumber: GCOL",R0
        ADR     R10,gtocntable          ;Address suitable translation table
        B       translate

;------------------------------------------------------------------------------
;
; ColourTrans_ColourNumberToGCOL implementation
;
;   Entry: R0 colour number
;
;   Exit:  V set   => R0 ->Error block
;          V clear => R0 GCOL
;
; Convert a colour number back to a GCOL.
;
;------------------------------------------------------------------------------

ColourNumberToGCOL_Code_testing
        Debug   input1,"ColourNumberToGCOL: R0",R0
        Debug   input2,"ColourNumberToGCOL: Colour",R0
        Push    "R0-R2,LR"

        MOV     R0,R1
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Read the Log2BPP of the mode
        CMP     R2,#3                   ;Is it 8BPP? (clear V)
        BNE     %FT19
        MOV     R1,#VduExt_ModeFlags
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        CLRV
        TST     R2,#ModeFlag_FullPalette ;Is it a brain damaged mode?
19
        Pull    "R0-R2,LR"
        MOVNE   PC,LR                   ;If it isn't then return as translation only needed in 8BPP mode

ColourNumberToGCOL_Code
        Debug   input1,"ColourNumberToGCOL_Code: R0",R0
        Debug   input2,"ColourNumberToGCOL_Code: Colour",R0
        ADR     R10,cntogtable          ;Address table for colour numbers to gcols

translate
        LDRB    R11,[R10,R0,LSR #2]     ;Get extra tint info
        AND     R0,R0,#3
        ORR     R0,R0,R11,LSL #2        ;And include into bottom two bits
        Debug   output,"GCOL<->Colour returning",R0
        MOV     PC,LR

cntogtable
        = &0,&1,&10,&11,&2,&3,&12,&13,&4,&5,&14,&15
        = &6,&7,&16,&17,&8,&9,&18,&19,&A,&B,&1A
        = &1B,&C,&D,&1C,&1D,&E,&F,&1E,&1F,&20,&21
        = &30,&31,&22,&23,&32,&33,&24,&25,&34,&35
        = &26,&27,&36,&37,&28,&29,&38,&39,&2A,&2B
        = &3A,&3B,&2C,&2D,&3C,&3D,&2E,&2F,&3E,&3F
        ALIGN

gtocntable
        = &0,&1,&4,&5,&8,&9,&C,&D,&10,&11,&14,&15
        = &18,&19,&1C,&1D,&2,&3,&6,&7,&A,&B,&E,&F
        = &12,&13,&16,&17,&1A,&1B,&1E,&1F,&20,&21
        = &24,&25,&28,&29,&2C,&2D,&30,&31,&34,&35
        = &38,&39,&3C,&3D,&22,&23,&26,&27,&2A,&2B
        = &2E,&2F,&32,&33,&36,&37,&3A,&3B,&3E,&3F
        ALIGN

;------------------------------------------------------------------------------
;
; ColourTrans_SetColour implementation
;
;   Entry: R0 GCOL number
;          R3 Flags
;                bit 7 set => set background, else foreground
;                bit 8 set => set pattern               ; NYI
;                bit 9 set => set text colour
;
;          R4 GCOL action (not used if bit 9 set!)
;
;   Exit:  V set   => R0 ->Error block
;          V clear => all preserved.
;
; This call changes the foreground/background colour to a value as
; returned from ColourTrans_ReturnGCOL.  It should only be used for
; colour numbers returned for the current mode.
;
; Setting bit 9 of the flags word will set the text colour rather
; than the graphics colours.
;
;------------------------------------------------------------------------------

SetColour_Code ROUT

        Debug   input1,"SetColour:",R0,R3-R4
        Debug   input2,"SetColour: GCOL, flags, action",R0,R3,R4

        Push    "R0-R5,LR"

      [ usesetcolour

        MOV     R0,#-1
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Get the mode flags for the current mode
        TEQ     R2,#3                   ;Is it an 8BPP mode?
        BNE     %FT19
        MOV     R1,#VduExt_ModeFlags
        SWI     XOS_ReadModeVariable
        MOVCS   R2,#0
        TST     R2,#ModeFlag_FullPalette ;Does it have the full palette?
19
        LDR     R0,[SP,#CallerR0]
        BLEQ    GCOLToColourNumber_Code ;If it matches the above then make into a colour number

        AND     R3,R3,#(1<<7)+(1<<9)    ;Extract the foreground and text bits for the colour set

        MOV     R1,R0                   ;Get the pixel value we want to setup
        MOV     R0,R3,LSR #3            ;Move fg/bg bit into a sensible location
        ORR     R0,R0,R4                ;Combining with the logical operation
        SWI     XOS_SetColour

        STRVS   R0,[SP]                 ;Return passing back any errors
        Pull    "R0-R5,PC"

      |

        TST     R3,#1:SHL:9             ;Setting the text colour?
        BNE     settextcolour

        AND     R3,R3,#&80
        AND     R1,R0,#&FF              ;Ensure bytes are within valid range

        LDRB    R5,[R12,#CachedL2BPP]
        TEQ     R5,#3                   ;Is it an 8BPP mode?
        BEQ     setcolour8bpp

        SWI     XOS_WriteI+18           ;GCOL mode,colour
        MOVVC   R0,R4
        SWIVC   XOS_WriteC
        ORRVC   R0,R1,R3
        SWIVC   XOS_WriteC

setcolour_return
        STRVS   R0,[SP]                 ;If it errored then modify the return R0
        Pull    "R0-R5,PC"

setcolour8bpp
        SWI     XOS_WriteI+18
        MOVVC   R0,R4
        SWIVC   XOS_WriteC
        MOVVC   R0,R1,LSR #2
        ORRVC   R0,R0,R3
        SWIVC   XOS_WriteC              ;Do the GCOL for 256 colour modes
        BVS     setcolour_return

        LDR     R0,setcolour_word       ;23,17,1
        ADD     R0,R0,R3,LSL #16-7
        ORR     R0,R0,R1,LSL #30
        MOV     R1,#0
        MOV     R2,#0
        Push    "R0,R1,R2"              ;Push 23,17,<action>,<tint>,0,0,0,0,0,0

        MOV     R0,SP
        MOV     R1,#10
        SWI     XOS_WriteN              ;Attempt to change the tint
        ADD     SP,SP,#12               ;Balance the stack - don't corrupt registers

        B       setcolour_return

setcolour_word
        = 23,17,2,0
        ALIGN

      ]

;------------------------------------------------------------------------------
;
; ColourTrans_MiscOp implementation
;
;   Entry: R0 reason code
;                       =0 set colour weights
;                       =1 return pattern block
;
;   Exit:  V set   => R0 ->Error block
;          V clear => as for call
;
; Handle the despatch of MiscOp codes within ColourTrans.
;
;------------------------------------------------------------------------------

MiscOp_Code ROUT

        Debug   input1,"MiscOp ",R0
        Debug   input2,"MiscOp ",R0

        CMP     R0,#CTransMiscOp_MAX
        ADDCC   PC,PC,R0,LSL #2
        B       miscop_invalid

        B       miscop_SetWeights
        B       miscop_ReturnPattern
        B       miscop_CalibrationType

miscop_invalid
        ADR     R0,ErrorBlock_CTBadMiscOp
        B       LookupError

        MakeEitherErrorBlock CTBadMiscOp


;..............................................................................
;
; CTransMiscOp_SetWeights
;
; This routine can be used to change the weights that apply to the R,G and B
; when performing distancing functions on them.  Each element is allocated
; eight bits in the form of &WbWgWr00.
;
; in    R0 reason code
;       R1 EOR mask
;       R2 AND mask
;
;       R1 =0, R2 =-1 to read the current setting
;
; out   V =1 => R0 -> error block
;       V =0 => R1 new value
;               R2 old value

miscop_SetWeights ROUT

        Push    "R3,LR"

        LDR     LR,[WP,#ColourErrorLoading]
        AND     R3,LR,R2                ;Apply AND (result in R3)
        EOR     R1,R3,R1                ;Apply EOR (result in R1)
        STR     R1,[WP,#ColourErrorLoading]
        MOV     R2,LR                   ;Setup previous value

        TEQ     R1,R2
        BLNE    InvalidateCache_Code    ;Are they the same? if not then invalidate the cache

        CLRV
        Pull    "R3,PC"

;..............................................................................
;
; CTransMiscOp_ReturnPattern
;
; Given a physical palette entry return a suitable pattern block based on
; the current mode and palette.  The pattern data is one word wide
; and is eight words high.
;
; in    R0 reason code
;       R1 physical palette entry
;
; out   V =1 => R0 -> error block
;       else,   R0 preserved
;               R1 preserved
;               R2 log2bpp of mode
;               R3 ->pattern block

miscop_ReturnPattern ROUT

        Push    "R0-R1,R5-R7,LR"

        MOV     R2,R1                   ;Physical palette entry
        BL      getpattern              ;Return a suitable pattern
        LDMIA   R5!,{R0-R1,R6-R7}       ;Get the pattern data
        addl    R3,WP,PatternTemp+(8*4)
        STMDB   R3!,{R0-R1,R6-R7}
        STMDB   R3!,{R0-R1,R6-R7}       ;And write backwards into temporary store

        CLRV
        Pull    "R0-R1,R5-R7,PC"

;..............................................................................
;
; CTransMiscOp_CalibrationType (version 1.10 and beyond)
;
; Return the type of calibration table being used in R0.
;
; in    R0 = reason code
; out   R0 = type of table      = 0 for none
;                               = 1 for old style
;                               = 2 for new style (newcalibration must be true!)

miscop_CalibrationType ROUT

        Push    "LR"

        LDR     R0,[WP,#Calibration_ptr]
        CMP     R0,#0                   ;Is there currently a table?
        MOVNE   R0,#1                   ;If so then the return code is 1
      [ newcalibration
        LDRNE   LR,[WP,#Calibration_newtable]
        CMPNE   LR,#0                   ;If there is a a table check for a new format one
        MOVNE   R0,#2                   ;If so then the return code is 2
      ]
        Pull    "PC"


;------------------------------------------------------------------------------
;
; ColourTrans_Set[Opp]TextColour implementation
;
;   Entry: R0 physical colour (&BBGGRRxx)
;          R3 flags
;               bit 7 set => set background colour
;
;   Exit:  V =1 => R0 -> Error block
;          else,   R0 GCOL value
;
; Set the current text colour based on the specified physical colour.
;
; NB: Common code used for both normal and opp operations.
;
;------------------------------------------------------------------------------

      [ usesetcolour

SetTextColour_Code ROUT

        Debug   input1,"SetTextColour: R0 R3",R0,R3
        Debug   input2,"SetTextColour: palette entry, flags",R0,R3

        Push    "R0-R5,LR"
        BL      ReturnColourNumber_Code
        B       settextcolour

SetOppTextColour_Code ROUT

        Debug   input1,"SetOppTextColour: R0 R3",R0,R3
        Debug   input2,"SetOppTextColour: palette entry, flags",R0,R3

        Push    "R0-R5,LR"
        BL      ReturnOppColourNumber_Code

        ; ... flow down into set text colour routine - assuming R0-R5 and LR pushed!

settextcolour
        MOV     R1,R0                   ;Setup the colour byte to be used
        MOV     R0,R3,LSR #3            ;Extract the fg/bg bits for the colour
        ORR     R0,R0,#1:SHL:6          ;Setting the bit for text colour modification
        SWI     XOS_SetColour

        STRVS   R0,[SP]
        Debug   output,"Set(Opp)TextColour returns: GCOL",R0
        Pull    "R0-R5,PC"              ;Return passing back any possible errors
      |

SetTextColour_Code ROUT

        Push    "R0-R5,LR"
        BL      ReturnGCOL_Code         ;Get the relevant colour from physical value
        B       settextcolour

SetOppTextColour_Code ROUT

        Push    "R0-R5,LR"
        BL      ReturnOppGCOL_Code      ;Get the colour with the most difference

; flo down into the routine to set actual colour

;..............................................................................

; Now set the actual colour or return if there is an error (the value in R0
; is a standard GCOL value)

; in    R0 = GCOL value
;       R3 = flags
;               bit 7 set => set background colour

; Assumes: R0-R5 and LR are currently pushed to stack!

settextcolour

        STR     R0,[SP]
        Pull    "R0-R5,PC",VS           ;Return if an error (error pointer already stored)

        AND     R3,R3,#&80              ;R3 = foreground / background flag
        MOV     R4,R0                   ;R4 = value

        LDRB    R0,[WP,#CachedL2BPP]
        CMP     R0,#3                   ;Is it an 8BPP mode?
        BLEQ    dotexttint

        SWIVC   XOS_WriteI+17
        ORRVC   R0,R4,R3                ;Combine to make colour + fore/background bit
        SWIVC   XOS_WriteC
        STRVS   R0,[SP]                 ;Store error pointer if went ga-ga!

        Pull    "R0-R5,PC"

;..............................................................................

; Setup a suitable tint value for 8BPP text modes.

; in    R0 log2BPP
;       R3 foreground / background flag (bit 7)
;       R4 GCOL value (unmodified)
; out   R4 contains 00cccccc in the bottom eight bits

dotexttint ROUT

        Push    "LR"

        SWI     XOS_WriteI+23           ;VDU 23,17
        SWIVC   XOS_WriteI+17
        MOVVC   R0,R3,LSR #7            ;0 ==> text foreground / 1 ==> text background
        SWIVC   XOS_WriteC

        ANDVC   R0,R4,#2_11
        MOVVC   R0,R0,LSL #6            ;Tint value to be used
        MOVVC   R4,R4,LSR #2
        SWIVC   XOS_WriteC
        SWIVC   XOS_WriteI+0
        SWIVC   XOS_WriteI+0
        SWIVC   XOS_WriteI+0
        SWIVC   XOS_WriteI+0
        SWIVC   XOS_WriteI+0
        SWIVC   XOS_WriteI+0            ;Pad to an eight byte value

        Pull    "PC"

      ]

;        [ debugag
;ag_display_stack
;        ;stack loads of registers
;        STMFD   R13!,{R0-R12,R14}
;        MOV     R1,R5           ;r0=dest, r1=source
;        LDMFD   R0!,{R2-R9}
;        Debug   ag,"Dest palette"
;        Debug   ag,"00:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R0!,{R2-R9}
;        Debug   ag,"08:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R0!,{R2-R9}
;        Debug   ag,"10:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R0!,{R2-R9}
;        Debug   ag,"18:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R1!,{R2-R9}
;        Debug   ag,"Source palette"
;        Debug   ag,"00:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R1!,{R2-R9}
;        Debug   ag,"08:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R1!,{R2-R9}
;        Debug   ag,"10:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R1!,{R2-R9}
;        Debug   ag,"18:",R2,R3,R4,R5,R6,R7,R8,R9
;        LDMFD   R13!,{R0-R12,R15}
;        ]

        END

