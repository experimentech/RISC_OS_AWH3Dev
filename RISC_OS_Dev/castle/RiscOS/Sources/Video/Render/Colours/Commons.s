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
; > Commons

;..............................................................................
;
; build_colours
;
; Fill the specified buffer with suitable data for performing palette lookups,
; the routine builds a table containing the correct data and returns R0,R1
; containing the bounds of the buffer.
;
; R6 is supplied on entry as a temporary buffer to be filled and on exit
; it will have been advanced past any data written into this buffer.
;
; R7,R8 contain pointers to routines on exit to be called to find the best
; and worst colour for the specified physical palette entry.  Whilst the
; routine is building the specified table it uses R7 as an index into a
; routine table which is then resolved on exit from the code.
;
; The cases go as follows:
;
;       default =rc_Simple
;       if 8BPP and default palette then =rc_Clever256
;       if 8BPP and default greyscale (black-to-white) palette then =rc_Grey8BPP
;
; The routine does check for the current palette being cached, if it
; is then it will return that if R0,R1 are -1 on entry.
;
; in    R0 mode to build table for / =-1 for current
;       R1 -> palette block to build mode for / =0 for default / =-1 for current
;       R2 = flags word
;       R7 -> extended flags word
;               bit 0 set => generate extended tables, else limit to eight bit per pixel tables
;
; out   V =1 => R0 -> error block
;       else,   R0,R1 contain limits of the buffer
;               R6 updated to point past last record
;               R7 ->routine to call to find best colour
;               R8 ->routine to call to find worst colour

rc_SimpleMatch  * 0
rc_Clever8BPP   * 1
rc_4444_TBGR    * 2
rc_4444_TRGB    * 3
rc_4444_ABGR    * 4
rc_4444_ARGB    * 5
rc_1555_TBGR    * 6
rc_1555_TRGB    * 7
rc_1555_ABGR    * 8
rc_1555_ARGB    * 9
rc_565_BGR      * 10
rc_565_RGB      * 11
rc_8888_TBGR    * 12
rc_8888_TRGB    * 13
rc_8888_ABGR    * 14
rc_8888_ARGB    * 15
rc_Grey8BPP     * 16

        ASSERT  :INDEX:PaletteCacheEnd =:INDEX: PaletteCacheStart +4
        ASSERT  :INDEX:PaletteBestV    =:INDEX: PaletteCacheStart +8
        ASSERT  :INDEX:PaletteWorstV   =:INDEX: PaletteCacheStart +12

build_colours ROUT

        Debuga  buildcolours,"Build colours mode",R0
        Debuga  buildcolours,", palette",R1
        Debug   buildcolours,", flags",R7

        CMP     R0,#-1                  ;Do they want the current palette?
        CMPEQ   R1,#-1
        BNE     build_colours2          ;If not then skip caching checks

        Debug   buildcolours2,"Attempting to get current palette"

        Push    "R3,R6,LR"

        LDR     R3,[WP,#PaletteCacheStart]
        CMP     R3,#0                   ;Has the palette already been cached?
        BNE     build_colourscached

        Debug   buildcolours2,"Not already cached"

        addl    R6,WP,CurrentPalette    ;->Buffer to fill
        BL      build_colours2
        addl    R6,WP,PaletteCacheStart
        STMIA   R6,{R0,R1,R7,R8}        ;Store the start and end of cache blocks

        Debuga  buildcolours2,"Our store is from",R0
        Debug   buildcolours2," to",R1
        Debug   buildcolours2,"Best routine",R7
        Debug   buildcolours2,"Worst routine",R8

        CLRV
        Pull    "R3,R6,PC"              ;Return because done

build_colourscached
        Debug   buildcolours2,"Current palette already cached"

        addl    R0,WP,PaletteCacheStart
        LDMIA   R0,{R0,R1,R7,R8}        ;Get bounds of cache block
        Pull    "R3,R6,PC"

;..............................................................................
;
; build_colours2
;
; This routine performs the actual table building and then returns the correct
; pointers etc.
;
; in    as above
;
; out   V =1 => R0 -> error block
;       else,   as above


build_colours2

        Push    "R2-R5,R10-R11,LR"

        Debuga  buildcolours2,"Mode",R0
        Debuga  buildcolours2," palette",R1
        Debuga  buildcolours2," scratch",R6
        Debug   buildcolours2," flags",R7

        Debuga  ag,"Mode",R0
        Debuga  ag," palette",R1
        Debuga  ag," scratch",R6
        Debug   ag," flags",R7

        LDR     R10,[WP,#PaletteAt]     ;->Palette table

        CMP     R0,#-1                  ;Are we building for the current mode?
        BEQ     build_coloursvalid      ;Yup so ignore as Palette table is valid

        CMP     R1,#-1                  ;If we are not building for current mode, but current palette then
        MOVEQ   LR,#0                   ;brain damage the palette pointer
        STREQ   LR,[WP,#PaletteAt]
        ;following is intended to fix rendering 256 colour non-palette sprite into
        ;other modes, where, without this, it returns a 1:1 table of the current
        ;palette
        MOVEQ   R1,#0                   ;and force it to use the default for the mode (amg 1.54)

build_coloursvalid
        MOV     R11,R1                  ;Temporary copy of palette pointer

;amg calling modeflags at this point is only sensible for a real mode, not a sprite
;mode word

        CMP     R0,#-1
        BEQ     bc2_oldmode

        CMP     R0,#256
        BCC     bc2_oldmode

        TST     R0,#1                   ;is bit0 set ?
        BEQ     bc2_oldmode             ;it isn't - so it is a modeselector

        ;so it is a sprite mode word
        Debug   buildcolours,"It's a sprite mode word"
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Get Log2BPP into flags (R3)
        MOV     R3,R2
        CMP     R3,#3
        MOVLS   R4,#0                   ;Not setting FullPalette; allegedly causes problems with tiled desktop background (see v1.54 changes)
        BLS     bc2_skipmodeflags
        MOV     R1,#VduExt_ModeFlags    ;Get the mode flags as required (R4)
        SWI     XOS_ReadModeVariable
        MOV     R4,R2
bc2_skipmodeflags
        MOV     R1,#VduExt_NColour
        SWI     XOS_ReadModeVariable    ;Get NColour (R5)
        MOV     R5,R2        

        B       bc2_gotmodevars

bc2_oldmode
        Debug   buildcolours,"It's a mode number/selector"
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Get Log2BPP into flags (R3)
        MOVCC   R3,R2
        MOVCC   R1,#VduExt_ModeFlags
        SWICC   XOS_ReadModeVariable    ;Get the mode flags as required (R4)
        MOVCC   R4,R2
        MOVCC   R1,#VduExt_NColour
        SWICC   XOS_ReadModeVariable    ;Get NColour (R5)
        MOVCC   R5,R2
        BCC     bc2_gotmodevars

        STR     R10,[WP,#PaletteAt]     ;Restore palette table is at pointer
        Pull    "R2-R5,R10-R11,LR"
        BadMODE
        B       LookupError             ;Balance stack and return bad mode error if not valid

bc2_gotmodevars
        CMP     R3,#3                   ;Is this a sensible mode for building a table in?
        BGT     buildcoloursbigjob      ;No, generating one in this mode is silly!

        MOV     R1,#1
        MOV     LR,R1,ASL R3            ;Convert from Log2BPP to BPP
        MOV     R1,#4
        MOV     R1,R1,ASL LR            ;Get the size of the table to be generated in words

        LDR     R5,[WP,#Calibration_ptr]
        MOV     R7,#rc_SimpleMatch      ;Index for routine to call (defaults to safe jobbie)

        MOVS    R0,R11

        ADREQL  LR,defpals
        LDREQ   R0,[LR,R3,ASL #2]
        ADDEQ   R0,R0,LR                ;->Palette table or default if R1 was zero on entry

        Debug   buildcolours2,"Resolved palette pointer",R0
        Debug   buildcolours2,"Final palette size",R1
        Debug   buildcolours2,"Log2BPP",R3
        Debug   buildcolours2,"Flags",R4
        Debug   buildcolours2,"Calibration table at",R5
        Debug   buildcolours2,"Scratch space",R6

        ;nb this actually the palette pointer

        CMP     R0,#-1                  ;Build palette for current mode?
        BEQ     buildcurrent

        Debug   buildcolours2,"Build from table"

        CMP     R3,#2                   ;Is it an 8BPP mode?
        CMPLE   R5,#0                   ;Calibration table specified?
        ADDLE   R1,R1,R0
        BLE     buildcoloursexit        ;Not 8BPP and no calibration so exit now... R0 ->table & R1 ->end

        TEQ     R3,#3                   ;Is it 8PP mode?
        TSTEQ   R4,#ModeFlag_FullPalette ;Does it have a full palette?
        BNE     buildslowtable

; flow down into "buildfasttable"

;..............................................................................
;
; buildfasttable
;
; Build a fast table of colours, we know that the mode is 8bpp and brain
; damaged and so we can simply read the base 16 entires and interpolate
; from these up to the final values.
;
; in    R0 -> table
;       R1�size of table block +1
;       R5 -> calibration table
;       R6 -> scratch space
;
; out   V =1 => R0 -> error block
;       else,   R0 -> start of table    (exits via calling 'buildcoloursexit')
;               R1 -> end of table
;               R6 updated
;               R7 preserved

buildfasttable
        Push    "R4,R8-R9"

        Debug   buildcolours2,"Building from a table"

        ADRL    R2,hardmode_hardbits    ;-> bit extensions for 8BPP modes
        LDR     R8,=&70307000           ;Bit mask to munge bits around with
        MOV     R9,#255                 ;Maximum colour index within the table

buildfastloop
        AND     LR,R9,#15               ;Get index into base entries
        LDR     R4,[R0,LR,ASL #2]       ;Get the RGB of the base palette entry
        AND     R4,R4,R8
        MOV     LR,R9,LSR #4
        LDR     LR,[R2,LR,ASL #2]       ;Get tint munging values
        ORR     R4,LR,R4
        ORR     R4,R4,R4,LSR #4         ;Combine into a suitable set of colours (including *17/16)
      [ {FALSE}
        TEQ     R5,#0
        BLNE    convert_screen_colour2  ;Attempt to calibrate if table pointer <>0
      ]
        STR     R4,[R6,R9,ASL #2]       ;Store into the table

        SUBS    R9,R9,#1
        BPL     buildfastloop           ;Loop until the entire table has been built

buildfastexit
        Pull    "R4,R8-R9"              ;Restore registers
        MOV     R0,R6
        ADD     R1,R1,R0                ;Setup bounds of table in registers
        MOV     R6,R1                   ;Setup end of scratch buffer pointer
        B       buildcoloursexit

;..............................................................................
;
; buildslowtable
;
; Fill the specified table with suitable data read from the block at R0
; and then stored at R6 performing calibration if required.
;
; in    R0 ->default palette block
;       R1 size of palette block +1
;       R3 log2BPP
;       R5 ->calibration table /=0 for none
;       R6 pointer to scratch buffer
;
; out   V =1 => R0 -> error block
;       else,   R0 -> start of table    (exits via calling 'buildcoloursexit')
;               R1 -> end of table
;               R6 updated
;               R7 preserved

buildslowtable
        Debuga  buildcolours2,"Building for normal modes from",R0
        Debug   buildcolours2," at",R6

        ADD     LR,R6,R1                ;End of table
        Push    "R6,LR"                 ;Push exit R0,R1 to table
        MOV     R2,R4                   ;Take a temporary copy of R4

buildslowloop
        SUBS    R1,R1,#4
        BMI     buildslowexit           ;Exit when finished building the current table

        LDR     R4,[R0],#4              ;Get a palette entry from original table
      [ {FALSE}
        TEQ     R5,#0                   ;Is there a calibration table?
        BLNE    convert_screen_colour2
      ]
        STR     R4,[R6],#4              ;Store the colour after possible calibration
        B       buildslowloop           ;Loop until all written back

buildslowexit
        Pull    "R0,R1"
        MOV     R4,R2                   ;Setup table start, end and restore mode flags
        B       buildcoloursexit        ;And then exit from routines

;..............................................................................
;
; buildcurrent
;
; Build table of current palette entries, to do this we need to fill the table
; at R6 with suitable palette data.
;
; No optimisation has been specified for the 8BPP case of brain damaged
; but we should attempt to find it if we can.
;
; in    R0 =-1
;       R1 size of palette buffer to fill
;       R3 log2bpp
;       R4 flags
;       R5 ->calibration table
;       R6 pointer to scratch buffer
;
; out   V =1 => R0 -> error block
;       else,   R0 -> start of table    (exits via calling 'buildcoloursexit')
;               R1 -> end of table
;               R6 updated
;               R7 preserved

buildcurrent
        ADD     LR,R6,R1                ;Pointer to end of data read
        Push    "R6,LR"                 ;Store the pointers

        MOV     R0,R1,LSR #2            ;R0 index of maxmium colour
        MOV     R1,#16                  ;Setup to return &BBGGRRxx

        Debug   buildcolours2,"Number of colours",R0

        MOV     R1,#17                  ;only actually want first flash state
        BL      fast_read_whole_palette ;R6 = where to, R0 = max colour+1
                                        ;R1 = colour type (16 here)
                                        ;returns R0=0 for correct behaviour below

        MOV     R1,#16                  ;but the original routine uses 16!

buildcurrentloop
        SUBS    R0,R0,#1
        BMI     buildcurrentexit        ;Exit when finished building palette

        Push    "R3,R4"
        BL      my_read_palette         ;Will calibrate result if required
        Pull    "R3,R4"

        STRVC   R2,[R6,R0,ASL #2]       ;Store palette entry obtained
        BVC     buildcurrentloop

buildcurrentexit
        Pull    "R0,R1"                 ;Balance stack pulling the exit parameters
        MOV     R6,R1
        B       buildcoloursexit

;..............................................................................
;
; Routine for coping with 16 and 32 bit per-pixel modes.  In these cases
; we do not attempt to generate a table (would be too big!) we infact
; just setup the pointers to the routines and then let the rest fall into
; place.
;
; R3 = Log2BPP
; R4 = ModeFlags
; R5 = NColour

buildcoloursbigjob

        Debug   buildcolours,"true colour mode, R5=",R5
        ; Assuming it's RGB colour space, work out which routine we need to use
        ; First work out the base format
        MOV     LR,#-1
        MOV     R7,#rc_8888_TBGR        ;8888 by default
        CMP     R5,LR,LSR #8
        BICEQ   R4,R4,#ModeFlag_DataFormatSub_Alpha ; 888 can use 8888, just need to ignore any alpha flag
        CMP     R5,LR,LSR #16
        MOVEQ   R7,#rc_565_BGR          ;Assume 64K
        TSTEQ   R4,#ModeFlag_64k
        MOVEQ   R7,#rc_1555_TBGR        ;Unless flag not set
        CMP     R5,LR,LSR #20
        MOVEQ   R7,#rc_4444_TBGR
        ; Now apply alpha & RGB order modifiers
        CMP     R7,#rc_565_BGR
        TSTNE   R4,#ModeFlag_DataFormatSub_Alpha
        ASSERT  rc_4444_ABGR-rc_4444_TBGR = 2
        ADDNE   R7,R7,#2
        TST     R4,#ModeFlag_DataFormatSub_RGB
        ASSERT  rc_4444_TRGB-rc_4444_TBGR = 1
        ADDNE   R7,R7,#1

;..............................................................................
;
; General purpose exit routine.  Attempts to decide which routine should be used
; to match the colours.
;

buildcoloursexit
        Debug   buildcolours2,"Finished building table"

        STR     R3,[WP,#BuildColoursL2BPP]

        TEQ     R3,#3                   ;Is it an 8BPP mode?
        BNE     buildcoloursdone

      [ docalibration
        LDR     R2,[WP,#Calibration_ptr]
        TEQ     R2,#0                   ;Is there a calibration table in use?
        BNE     buildcoloursdone        ;If so we cannot perform the faster look up
      ]

        TST     R4,#ModeFlag_FullPalette ;Is it brian damaged... borring
        BNE     scannewstyle

        Debug   buildcolours2,"Check for fast colour matching (old style)"

        ADR     R2,modetwofivesix       ;Base of table for 256 colours
        MOV     R3,#16
        LDR     R4,=&70307000           ;Mask to extract colours

scanoldstyle
        SUBS    R3,R3,#1                ;Decrease the counter
        MOVMI   R7,#rc_Clever8BPP       ;Switch to fast 256 table matching
        BMI     buildcoloursdone

        LDR     LR,[R2,R3,LSL #2]       ;Get colour from my table
        LDR     R5,[R0,R3,LSL #2]
        AND     R5,R5,R4                ;Get colour from palette
        TEQ     R5,LR
        BEQ     scanoldstyle            ;Loop back until all checked

scanfailed
        Debug   buildcolours2,"Matching failed"

buildcoloursdone
        Debuga  buildcolours2,"Table from",R0
        Debuga  buildcolours2," to",R1
        Debuga  buildcolours2," scratch",R6
        Debug   buildcolours2," routine index",R7

        ADR     LR,routinetable
        ADD     R7,LR,R7,ASL #3         ;-> routine table to call
        LDMIA   R7,{R7,R8}
        ADD     R7,R7,LR                ;-> best colour routine
        ADD     R8,R8,LR                ;-> worst colour routine

        Debug   buildcolours,"Best match routine",R7
        Debug   buildcolours,"Worst match routine",R8

        STR     R10,[WP,#PaletteAt]     ;Restore the palette table pointer

        CLRV
        Pull    "R2-R5,R10-R11,PC"

scannewstyle
        TST     R4,#ModeFlag_GreyscalePalette
        MOV     R3,#256
        BNE     scangrey256
        
        Debug   buildcolours2, "Check for fast colour matching (new style)"
        ; Use modetwofivesix and hardmode_hardbits to dynamically build the
        ; default 256 colour palette and check it against the input palette
        ; (Probably quicker to have the default palette precalculated somewhere)
        ADR     R2,modetwofivesix+15*4
        ADR     R4,hardmode_hardbits+15*4
        LDR     R8,[R4],#-4             ;Get high nibble
scannewstyle_loop
        LDR     LR,[R2],#-4             ;Get low nibble
        SUB     R3,R3,#1                ;Decrease the counter
        ORR     LR,LR,R8                ;Combine nibbles
        LDR     R5,[R0,R3,LSL #2]       ;Get colour from palette
        ORR     LR,LR,LR,LSR #4         ;Expand to 8 bits
        TEQ     R5,LR
        BNE     scanfailed
        TST     R3,#15
        BNE     scannewstyle_loop
        ADR     R2,modetwofivesix+15*4  ;Reset low nibble pointer
        CMP     R3,#0
        LDR     R8,[R4],#-4             ;Fetch next high nibble value
        BNE     scannewstyle_loop
        MOV     R7,#rc_Clever8BPP       ;Switch to fast 256 table matching
        B       buildcoloursdone

scangrey256
        ; Check if this is the RISC OS 5 default greyscale palette: A linear
        ; gradient from black to white. If so, we can use our fast greyscale
        ; routines.
        MOV     R2,#&FFFFFF00
        LDR     R4,=&01010100
        Debug   buildcolours2, "Check for default 256 grey"
scangrey256_loop
        SUBS    R3,R3,#1
        MOVLT   R7,#rc_Grey8BPP
        BLT     buildcoloursdone
        LDR     LR,[R0,R3,LSL #2]
        TEQ     LR,R2
        SUB     R2,R2,R4
        BEQ     scangrey256_loop
        B       scanfailed
        
;..............................................................................
;
; Routines to be called to find suitable colours.  These routines are given
; as absolute addresses in R7,R8 on return from build_colours.
;
; The routine whilst operating attempts to increase R7 as a suitable index
; within the table so that on exit from the build_colours code it can
; setup a set of suitable pointers
;
        ASSERT  rc_SimpleMatch =0
        ASSERT  rc_Clever8BPP  =1
        ASSERT  rc_4444_TBGR   =2
        ASSERT  rc_4444_TRGB   =3
        ASSERT  rc_4444_ABGR   =4
        ASSERT  rc_4444_ARGB   =5
        ASSERT  rc_1555_TBGR   =6
        ASSERT  rc_1555_TRGB   =7
        ASSERT  rc_1555_ABGR   =8
        ASSERT  rc_1555_ARGB   =9
        ASSERT  rc_565_BGR     =10
        ASSERT  rc_565_RGB     =11
        ASSERT  rc_8888_TBGR   =12
        ASSERT  rc_8888_TRGB   =13
        ASSERT  rc_8888_ABGR   =14
        ASSERT  rc_8888_ARGB   =15
        ASSERT  rc_Grey8BPP    =16

routinetable
        & best_colour_safe       -routinetable
        & worst_colour_safe      -routinetable

        & best_colour256_safe    -routinetable
        & worst_colour256_safe   -routinetable

        & best_colour_4444_TBGR  -routinetable
        & worst_colour_4444_TBGR -routinetable

        & best_colour_4444_TRGB  -routinetable
        & worst_colour_4444_TRGB -routinetable

        & best_colour_4444_ABGR  -routinetable
        & worst_colour_4444_ABGR -routinetable

        & best_colour_4444_ARGB  -routinetable
        & worst_colour_4444_ARGB -routinetable

        & best_colour_1555_TBGR  -routinetable
        & worst_colour_1555_TBGR -routinetable

        & best_colour_1555_TRGB  -routinetable
        & worst_colour_1555_TRGB -routinetable

        & best_colour_1555_ABGR  -routinetable
        & worst_colour_1555_ABGR -routinetable

        & best_colour_1555_ARGB  -routinetable
        & worst_colour_1555_ARGB -routinetable

        & best_colour_565_BGR    -routinetable
        & worst_colour_565_BGR   -routinetable

        & best_colour_565_RGB    -routinetable
        & worst_colour_565_RGB   -routinetable

        & best_colour_8888_TBGR  -routinetable
        & worst_colour_8888_TBGR -routinetable

        & best_colour_8888_TRGB  -routinetable
        & worst_colour_8888_TRGB -routinetable

        & best_colour_8888_ABGR  -routinetable
        & worst_colour_8888_ABGR -routinetable

        & best_colour_8888_ARGB  -routinetable
        & worst_colour_8888_ARGB -routinetable

        & best_colour256_grey    -routinetable
        & worst_colour256_grey   -routinetable

        LTORG

;..............................................................................
;
; Tables required to contain default palette data for the various screen
; modes.
;
; NB: 256 colour modes are a very special case and contain only the base 16
;     entries and interpolation is performed from here to the real
;     values.
;

defpals
        DCD     modetwo         - defpals
        DCD     modefour        - defpals
        DCD     modesixteen     - defpals
        DCD     modetwofivesix  - defpals

modetwo
        DCD     &0              ;  black
        DCD     &FFFFFF00       ;  white

modefour
        DCD     &0              ;  black
        DCD     &FF00           ;  red
        DCD     &FFFF00         ;  yellow
        DCD     &FFFFFF00       ;  white

modesixteen                     ;  actual colours
        DCD     &0              ;  black
        DCD     &FF00           ;  red
        DCD     &FF0000         ;  green
        DCD     &FFFF00         ;  yellow
        DCD     &FF000000       ;  blue
        DCD     &FF00FF00       ;  magenta
        DCD     &FFFF0000       ;  cyan
        DCD     &FFFFFF00       ;  white
        DCD     &0              ;  black - flashing
        DCD     &FF00           ;  red
        DCD     &FF0000         ;  green
        DCD     &FFFF00         ;  yellow
        DCD     &FF000000       ;  blue
        DCD     &FF00FF00       ;  magenta
        DCD     &FFFF0000       ;  cyan
        DCD     &FFFFFF00       ;  white

modetwofivesix
        DCD     &0              ;  0000
        DCD     &10101000       ;  0001
        DCD     &20202000       ;  0010
        DCD     &30303000       ;  0011
        DCD     &00004000       ;  0100
        DCD     &10105000       ;  0101
        DCD     &20206000       ;  0110
        DCD     &30307000       ;  0111
        DCD     &40000000       ;  1000
        DCD     &50101000       ;  1001
        DCD     &60202000       ;  1010
        DCD     &70303000       ;  1011
        DCD     &40004000       ;  1100
        DCD     &50105000       ;  1101
        DCD     &60206000       ;  1110
        DCD     &70307000       ;  1111

hardmode_hardbits       ;  translation of top nibble of byte to RGB bits
        DCD     &0              ;  0000
        DCD     &00008000       ;  0001
        DCD     &00400000       ;  0010
        DCD     &00408000       ;  0011
        DCD     &00800000       ;  0100
        DCD     &00808000       ;  0101
        DCD     &00C00000       ;  0110
        DCD     &00C08000       ;  0111
        DCD     &80000000       ;  1000
        DCD     &80008000       ;  1001
        DCD     &80400000       ;  1010
        DCD     &80408000       ;  1011
        DCD     &80800000       ;  1100
        DCD     &80808000       ;  1101
        DCD     &80C00000       ;  1110
        DCD     &80C08000       ;  1111

;------------------------------------------------------------------------------
;
; Common routines to find the closest and furthest colour from
; a given RGB value, given a table of colour entries.
;
; The algorithms here are expressed as macros - I find this makes
; register allocation easy while preserving some self documentation
; in the register names.
;
; Colours are encoded in the standard RISC OS way:-
;
;           BBGGRRxx
;
; where ``xx'' is undefined.  This encoding is also used for the
; loading in error calculations, used when determining the closest
; or most distance colour from a given colour.  The error is calculated
; from the errors in each component (be, ge, re) as follows:-
;
;         bl*be^2 + gl*ge^2 + rl*re^2
;
; The loadings are parameterised and stored globally as a single word
; value in the above format, ie:-
;
;           blglrlxx
;
; It will be seen that the maximum loading is thus 255.  This limits
; the maximum error generated by the above calculation to 3*255^3;
; &2F708FD.
;

;
;----------------------------------------------------------------------
;
; MACRO CompErr
;
; This macro also calculates an error value, however the second colour
; is specified as three separate r, g, b values.  The registers containing
; these values can be the same, if desired.  The registers should not be
; the same as any of the other registers.  Similarly the loading values
; are held in separate registers, which can be the same as each other
; if desired
;
        MACRO
$label  CompErr $error, $col, $red, $green, $blue, $rload, $gload, $bload, $temp1, $temp2

$label
    [ NoARMv6 :LOR: SlowMultiply
      [ SlowMultiply
        SUBS    $temp2, $blue, $col, LSR #24
        RSBLT   $temp2, $temp2, #0
      |
        SUB     $temp2, $blue, $col, LSR #24
      ]
        MUL     $temp1, $temp2, $temp2
        MUL     $error, $temp1, $bload       ; loading will be small
        ; $error contains blue term
        AND     $temp1, $col, #&FF0000       ; green component, still shifted
      [ SlowMultiply
        SUBS    $temp2, $green, $temp1, LSR #16
        RSBLT   $temp2, $temp2, #0           ; |green error|
      |
        SUB     $temp2, $green, $temp1, LSR #16
      ]
        MUL     $temp1, $temp2, $temp2
        MLA     $error, $temp1, $gload, $error
        ; $error contains blue+green
        AND     $temp1, $col, #&FF00         ; red component, still shifted
      [ SlowMultiply
        SUBS    $temp2, $red, $temp1, LSR #8
        RSBLT   $temp2, $temp2, #0           ; |red error|
      |
        SUB     $temp2, $red, $temp1, LSR #8
      ]
        MUL     $temp1, $temp2, $temp2
        MLA     $error, $temp1, $rload, $error
    |
        ; Cortex-A8 optimised version
        ; Should execute in 15 cycles, compared to 32 for the above
        ; May help ARMv6 too (minimum ARMv6 required due to MUL Rd==Rn)
        SUB     $error, $blue, $col, LSR #24 ; blue error
        AND     $temp2, $col, #&FF0000       ; green component, still shifted
        AND     $temp1, $col, #&FF00         ; red component, still shifted
        MUL     $error, $error, $error
        SUB     $temp2, $green, $temp2, LSR #16 ; green error
        SUB     $temp1, $red, $temp1, LSR #8 ; red error
        MUL     $temp2, $temp2, $temp2
        MUL     $temp1, $temp1, $temp1
        MUL     $error, $error, $bload
        MLA     $error, $temp2, $gload, $error
        MLA     $error, $temp1, $rload, $error
    ]
        MEND
;
;----------------------------------------------------------------------
;
; MACRO FindCol
;
; This macro finds a colour closest to or furthest from the given colour.
; Which is found is determined by the initial value of $error and the
; test ($test) which is supplied to use when deciding whether the found
; colour is better or worse than the current best.
;
; The $test value is used in instructions conditional on the result of:-
;
;      CMP      $newerror, $error
;
; And the search goes from the top of the colour table down, hence:-
;
;   $test    Initial $error          Interpretation
;   -----    --------------          --------------
;   LS       #&FFFFFFFF      Find closest colour, favour lower indices
;   LO       #&FFFFFFFF      Find closest colour, favour higher indicies
;   HS       #&0             Find furthest colour, favour lower indices
;   HI       #&0             Find furthest colour, favour higher indices
;
; Timings for the search obviously depend on the size of the colour
; table.  The whole table is always searched.
;
; Arguments are as follows:-
;
; $test      Comparison to perform: LS, LO, HS or HI
; $list      Pointer to start of colour table         PRESERVED
; $listend   Pointer to end+4 of colour table         IN
;            Same as $list                            OUT
; $srccol    BBGGRRxx colour to check                 IN
;            Index of colour in table                 OUT
; $load      Error loading in format BBGGRRxx         IN
;            Temporary registered                     TRASHED
; $error     Error value for colour $list[$srccol]    OUT
; $red       TEMPORARY
; $green     TEMPORARY
; $blue      TEMPORARY
; $rload     TEMPORARY
; $gload     TEMPORARY
; $bload     TEMPORARY
; $col       TEMPORARY
; $temp1     TEMPORARY
; $temp2     TEMPORARY
;
        MACRO
$label  FindCol  $test, $list, $listend, $srccol, $load, $error, $red, $green, $blue, $rload, $gload, $bload, $col, $temp1, $temp2

        ; First extract the packed colour and load
$label  MOV      $blue, #255
        AND      $green, $blue, $srccol, LSR #16
        AND      $gload, $blue, $load, LSR #16
        AND      $red, $blue, $srccol, LSR #8
        AND      $rload, $blue, $load, LSR #8
        MOV      $blue, $srccol, LSR #24
        MOV      $bload, $load, LSR #24
        ;
        ; Loop round from the top of the table down
00      LDR      $col, [$listend, #-4]!
        CompErr  $load, $col, $red, $green, $blue, $rload, $gload, $bload, $temp1, $temp2
        CMP      $load, $error
        MOV$test $error, $load
        SUB$test $srccol, $listend, $list             ; index * 4
        CMP      $listend, $list
        BHI      %BT00
        MOV      $srccol, $srccol, LSR #2
        MEND
;
;----------------------------------------------------------------------
;
; MACRO Find256
;
; This macro finds the best matching colour for the *standard* ARM 256
; entry palette - the one with the R/G/B/T (tint) bits.  The algorithm
; returns a palette value encoded in the standard way (BGGRBRTT) in
; $srccol and the error in $error.  The algorithm is expressed in two
; parts; the first to find the closest ARM 24 bit colour, then the
; second to convert this to the ARM standard format.  This allows the
; basic macro to be used either for GCOL (BBGGRRTT) form or colour
; number (BGGRBRTT) form.  The timings below assume colour number form.
;
; This is an improved version of the original Find256 macro. We use a
; lookup table to map the red, green and blue components to the four
; closest VIDC components (four due to the four different tint values).
; The old code used to find the closest colours manually, but using a
; lookup table allows over half of the instructions to be removed from
; the inner loop, making this new version at least twice as fast.
;
; Arguments are as follows:-
;
;Find256
;-------
; $test                           Comparison to perform: LS, LO, HS or HI
; $srccol                         (in) source RGB (out) corrupt
; $load                           (in) error loading (out) corrupt
; $error                          (in/out) best error value
; $newcol                         (in/out) best RGB value
; $temp1-temp3                    (out) corrupt
; $srcred, $srcgreen              (out) corrupt
; $rload, $gload                  (out) corrupt
; $redvals, $greenvals, $bluevals (out) corrupt
;
; All registers must be unique!
;
;Convert24Number, Convert24GCOL
;---------------  -------------
; $col       24 bit colour value                      PRESERVED
; $number    256 palette entry colour number          OUT
; $temp1     TEMPORARY
;
; The ARM palette entries are assumed to expand a 4 bit component to an 8
; bit component using c<<4|c - this has been determined experimentally to
; give good results.
;
; The $error value and the $test condition must be as in FindCol.  Because
; the algorithm searches through the tints starting at the highest the
; behaviour is as follows:-
;
;   $test    Initial $error          Interpretation
;   -----    --------------          --------------
;   LS       #&FFFFFFFF      Find closest colour, favour lower tints
;   LO       #&FFFFFFFF      Find closest colour, favour higher tints
;   HS       #&0             Find furthest colour, favour lower tints
;   HI       #&0             Find furthest colour, favour higher tints
;

        MACRO
$label  Find256  $test, $srccol, $load, $error, $newcol, $temp1, $temp2, $temp3, $srcred, $srcgreen, $rload, $gload, $redvals, $greenvals, $bluevals

        ; Set up a couple of aliases
        LCLS     srcblue
srcblue SETS     "$srccol"
        LCLS     bload
bload   SETS     "$load"                
        
$label

        ; Get lookup table pointer
        ADR      $bluevals, Find256_Table
        ; Get source RGB & loadings into separate registers
      [ NoARMv6
        AND      $srcred, $srccol, #&FF00
        AND      $srcgreen, $srccol, #&FF0000
        MOV      $srcred, $srcred, LSR #8
        MOV      $srcgreen, $srcgreen, LSR #16
        AND      $rload, $load, #&FF00
        AND      $gload, $load, #&FF0000
        MOV      $rload, $rload, LSR #8
        MOV      $gload, $gload, LSR #16
      |
        UXTB     $srcred, $srccol, ROR #8
        UXTB     $srcgreen, $srccol, ROR #16
        UXTB     $rload, $load, ROR #8
        UXTB     $gload, $load, ROR #16
      ]
        ; Get closest RGB values
        LDR      $redvals, [$bluevals, $srcred, LSL #2]
        MOV      $srcblue, $srccol, LSR #24
        LDR      $greenvals, [$bluevals, $srcgreen, LSL #2]
        MOV      $bload, $load, LSR #24
        LDR      $bluevals, [$bluevals, $srcblue, LSL #2]
        ; Get to work!
00
    [ NoARMv6 :LOR: SlowMultiply
        ; If no ARMv6, can't use MUL with Rd==Rn
        ; This makes things a bit ugly because we don't have any spare regs
      [ SlowMultiply
        SUBS     $temp1, $srcred, $redvals, LSR #24
        RSBLT    $temp1, $temp1, #0
      |
        SUB      $temp1, $srcred, $redvals, LSR #24
      ]   
        MUL      $temp3, $temp1, $temp1         ; squared red error in temp3
      [ SlowMultiply
        SUBS     $temp2, $srcgreen, $greenvals, LSR #24
        RSBLT    $temp2, $temp2, #0
      |
        SUB      $temp2, $srcgreen, $greenvals, LSR #24
      ]
        MUL      $temp1, $temp3, $rload         ; weighted red error in temp1
        MUL      $temp3, $temp2, $temp2         ; squared green error in temp3
      [ SlowMultiply
        SUBS     $temp2, $srcblue, $bluevals, LSR #24
        RSBLT    $temp2, $temp2, #0
      |
        SUB      $temp2, $srcblue, $bluevals, LSR #24
      ]
        MLA      $temp1, $temp3, $gload, $temp1 ; accumulate weighted green error
        MOV      $redvals, $redvals, ROR #24    ; advance to next tint
        MUL      $temp3, $temp2, $temp2         ; squared blue error in temp3
        MOV      $greenvals, $greenvals, ROR #24
        MLA      $temp1, $temp3, $bload, $temp1 ; accumulate weighted blue error      
        MOV      $bluevals, $bluevals, ROR #24
        ; Final error in $temp1
    |
        ; $temp1 = red error, $temp2 = green error, $temp3 = blue error
        SUB      $temp1, $srcred, $redvals, LSR #24
        SUB      $temp2, $srcgreen, $greenvals, LSR #24
        SUB      $temp3, $srcblue, $bluevals, LSR #24
        MUL      $temp1, $temp1, $temp1
        MOV      $redvals, $redvals, ROR #24    ; advance to next tint
        MUL      $temp2, $temp2, $temp2
        MOV      $greenvals, $greenvals, ROR #24
        MUL      $temp3, $temp3, $temp3
        MOV      $bluevals, $bluevals, ROR #24
        MUL      $temp1, $temp1, $rload
        MLA      $temp1, $temp2, $gload, $temp1
        MLA      $temp1, $temp3, $bload, $temp1
        ; Final error in $temp1
    ]
        ; Speculative calculation of final RGB while waiting for MLA result
      [ NoARMT2
        MOV      $temp2, $redvals, LSL #24
        MOV      $temp2, $temp2, LSR #8
        ORR      $temp2, $temp2, $greenvals, LSL #24
        MOV      $temp2, $temp2, LSR #8
        CMP      $temp1, $error
        ORR$test $newcol, $temp2, $bluevals, LSL #24
      |
        MOV      $temp2, $bluevals, LSL #24
        BFI      $temp2, $greenvals, #16, #8
        BFI      $temp2, $redvals, #8, #8
        CMP      $temp1, $error
        MOV$test $newcol, $temp2
      ]
        MOV$test $error, $temp1
        TST      $redvals, #&3 ; Check for tint=0, indicating 4 iterations
        BNE      %BT00
        MEND

;
; Convert24Number - convert the above format to the ARM colour number
; format:-
;
;            76543210
;            BGGRBRTT
;
        MACRO
$label  Convert24Number $col, $number, $temp1

$label  AND     $temp1, $col, #&80000000        ; B   (needs >> 24)
        MOV     $number, $temp1, LSR #24
        AND     $temp1, $col, #&C00000          ; GG  (needs >> 17)
        ORR     $number, $number, $temp1, LSR #17
        AND     $temp1, $col, #&8000            ; R   (needs >> 11)
        ORR     $number, $number, $temp1, LSR #11
        AND     $temp1, $col, #&40000000        ; B   (needs >> 27)
        ORR     $number, $number, $temp1, LSR #27
        AND     $temp1, $col, #&7000            ; RTT (needs >> 12)
        ORR     $number, $number, $temp1, LSR #12
        MEND
;
; Convert24GCOL - convert the above format to the ARM colour number
; format:-
;
;            76543210
;            BBGGRRTT
;
        MACRO
$label  Convert24GCOL $col, $number, $temp1

$label  AND     $temp1, $col, #&C0000000        ; BB   (needs >> 24)
        MOV     $number, $temp1, LSR #24
        AND     $temp1, $col, #&C00000          ; GG   (needs >> 18)
        ORR     $number, $number, $temp1, LSR #18
        AND     $temp1, $col, #&F000            ; RRTT (needs >> 12)
        ORR     $number, $number, $temp1, LSR #12
        MEND
;
;----------------------------------------------------------------------
;
; INTERFACE best_colourXXX
;
; Finds the index (returned in R2) of the closest colour to the
; colour given in R2.  If two colours are equally good the one
; with the lowest index in the table is returned.
;
; This interface trashes ALL the registers EXCEPT:-
;
;    R0   colour table start             PRESERVED
;    R1   colour table end +4            IN
;         == R0 (colour table start)     OUT
;    R2   colour to check (BBGGRRxx)     IN
;         index of colour within table   OUT
;    R3   error loading value (BBGGRRxx) IN
;         used as a temporary            TRASHED
;    R4   error for given colour         OUT
;    R12  Workspace pointer              PRESERVED
;
; LR is the return address, and is trashed.  Notice that the routine
; preserves the workspace pointer in r12 - the previous best_colour
; interface did not do this (on the other hand, it did preserve
; other registers - WATCH OUT!)
;
best_colour_fast
        Push    "wp, lr"
        MOV     r4, #&FFFFFFFF                  ; initial error
        FindCol LS,r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r14
        Pull    "wp, pc"
;
; This alternative interface preserves registers; ONLY the following
; registers are used or altered:-
;
;    R0  colour table start          PRESERVED
;    R1  colour table end +4         PRESERVED
;    R2  colour to check (BBGGRRxx)  IN
;        index of colour in table    OUT
;    LR  return address              IN
;        used as a temporary         TRASHED
;
best_colour_safe
        Push    "r1,r3,r4,r5,r6,r7,r8,r9,r10,r11,lr"
      [ newcalibration
        LDR     r3, [wp, #Calibration_ptr]
        TEQ     r3, #0
        BLNE    convert_screen_colour
      ]
        LDR     r3, [wp, #ColourErrorLoading]   ; BBGGRRxx loading value
        BL      best_colour_fast
        Pull    "r1,r3,r4,r5,r6,r7,r8,r9,r10,r11,pc"

;
; Finds the index (returned in R2) of the closest ARM VIDC 256 entry
; palette colour to the colour given in R2.  If two colours are equally
; good the one with the highest tint is returned.  The value returned is
; a RISC OS colour number NOT a GCOL value.
;
;    R2  colour to check (BBGGRRxx)  IN
;        index of colour in table    OUT
;
best_colour256_safe
        Entry   "r0-r1,r3-r12"
      [ newcalibration
        LDR     r3, [wp, #Calibration_ptr]
        TEQ     r3, #0
        BLNE    convert_screen_colour
      ]
        LDR     r3, [wp, #ColourErrorLoading]   ; BBGGRRxx loading value
        MOV     r4, #&FFFFFFFF
        Find256 LO,r2,r3,r4,r0,r1,r5,r6,r7,r8,r9,r10,r11,r12,r14
        Convert24Number r0,r2,r5
        EXIT

;
;----------------------------------------------------------------------
;
; INTERFACE worst_colour_XXX
;
; Finds the index (returned in R2) of the furthest colour from the
; colour given in R2.  If two colours are equally good the one
; with the highest index in the table is returned.
;
; This interface trashes ALL the registers EXCEPT:-
;
;    R0   colour table start             PRESERVED
;    R1   colour table end +4            IN
;         == R0 (colour table start)     OUT
;    R2   colour to check (BBGGRRxx)     IN
;         index of colour within table   OUT
;    R3   error loading value (BBGGRRxx) IN
;         used as a temporary            TRASHED
;    R4   error for given colour         OUT
;    R12  Workspace pointer              PRESERVED
;
; LR is the return address, and is trashed.  As with the best_colour
; routines the work space pointer is preserved, but other things are
; damaged.
;
worst_colour_fast
        Push    "wp, lr"
        MOV     r4, #&0                  ; initial error
        FindCol HI,r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r14
        Pull    "wp, pc"
;
; There is no register preserving interface - this routine is only
; used in one place so this would be a waste of ROM space!  The
; following code is therefore commented out...
;
; This alternative interface preserves registers; ONLY the following
; registers are used or altered:-
;
;    R0  colour table start          PRESERVED
;    R1  colour table end +4         PRESERVED
;    R2  colour to check (BBGGRRxx)  IN
;        index of colour in table    OUT
;    LR  return address              IN
;        used as a temporary         TRASHED
;
worst_colour_safe
        Push    "r1,r3,r4,r5,r6,r7,r8,r9,r10,r11,lr"
      [ newcalibration
        LDR     r3, [wp, #Calibration_ptr]
        TEQ     r3, #0
        BLNE    convert_screen_colour
      ]
        LDR     r3, [wp, #ColourErrorLoading]   ; BBGGRRxx loading value
        BL      worst_colour_fast
        Pull    "r1,r3,r4,r5,r6,r7,r8,r9,r10,r11,pc"

;
;
; Finds the index (returned in R2) of the furthest ARM VIDC 256 entry
; palette colour from the colour given in R2.  If two colours are equally
; good the one with the lowest tint is returned.  The value returned is
; a RISC OS colour number NOT a GCOL value.
;
;    R2  colour to check (BBGGRRxx)  IN
;        index of colour in table    OUT
;
worst_colour256_safe
        Entry   "r0-r1,r3-r12"
      [ newcalibration
        LDR     r3, [wp, #Calibration_ptr]
        TEQ     r3, #0
        BLNE    convert_screen_colour
      ]
        LDR     r3, [wp, #ColourErrorLoading]   ; BBGGRRxx loading value
        MOV     r4, #0
        Find256 HS,r2,r3,r4,r0,r1,r5,r6,r7,r8,r9,r10,r11,r12,r14
        Convert24Number r0,r2,r5
        EXIT

;
; Core code for finding the nearest greyscale colour in standard (RISC OS 5)
; 256 grey modes (palette entry 0 = black, 255 = white). This means that
; calculation of the nearest greyscale value is as simple as:
;
; (red*rload + green*gload + blue*bload)/(rload+gload+bload)
;
; However this macro leaves the division to the caller, as best_colour256_grey
; will want to perform the division but worst_colour256_grey won't.
;
; In:
;  r2 = colour &BBGGRRxx
; Out:
;  lr = numerator
;  r0 = divisor
;  r1-r5 corrupt
;  r2 = 255 if $worst = "worst"
;
        MACRO
        Find256Grey_Core $worst
        LDR     r5, [wp, #ColourErrorLoading]   ; BBGGRRxx loading value
    [ NoARMv6
        MOV     r0, r2, LSR #24         ; red
        AND     r1, r2, #&FF0000        ; green (shifted)
        AND     r2, r2, #&FF00          ; blue (shifted)
        MOV     r3, r5, LSR #24         ; rload
        AND     r4, r5, #&FF0000        ; gload (shifted)
        AND     r5, r5, #&FF00          ; bload (shifted)
        MUL     lr, r0, r3              ; red*rload
        MOV     r1, r1, LSR #16
        MOV     r4, r4, LSR #16
        ADD     r0, r3, r5, LSR #8      ; rload+bload
        MUL     r5, r2, r5              ; blue*bload in high 16 bits
        ADD     r0, r0, r4              ; rload+gload+bload
        MLA     lr, r1, r4, lr          ; red*rload + green*gload
      [ "$worst" = "worst"
        MOV     r2, #255                ; Use up a spare cycle
      ]
        ADD     lr, lr, r5, LSR #16     ; red*rload + green*gload + blue*bload
    |
        MOV     r0, r2, LSR #24         ; red
        UXTB    r1, r2, ROR #16         ; green
        UXTB    r2, r2, ROR #8          ; blue
        MOV     r3, r5, LSR #24         ; rload
        UXTB    r4, r5, ROR #16         ; gload
        MUL     lr, r0, r3              ; red*rload
        UXTB    r5, r5, ROR #8          ; bload
        MLA     lr, r2, r5, lr          ; red*rload + blue*bload
        ADD     r0, r3, r5              ; rload+bload
        MLA     lr, r1, r4, lr          ; red*rload + blue*bload + green*gload
        ADD     r0, r0, r4              ; rload+gload+bload
      [ "$worst" = "worst"
        MOV     r2, #255                ; Use up a spare cycle
      ]
    ]
        ADD     lr, lr, r0, LSR #1      ; round to nearest during divide
        MEND

;
; Finds the index (returned in R2) of the closest greyscale colour to the
; colour given in R2.  The palette is assumed to be a linear gradient from 0
; to 255.
;
best_colour256_grey
        Entry   "r0-r1,r3-r5"
        Find256Grey_Core
        DivRem  r2, lr, r0, r1, norem
        EXIT

;
; Find the worst possible greyscale colour. This will either be black (0) or
; white (255). Implementation is basically as above, except we can skip the
; divide as we only need to compare against 128
;
worst_colour256_grey
        Entry   "r0-r1,r3-r5"
        Find256Grey_Core worst          ; will initialise r2 with 255
        CMP     lr, r0, LSL #7          ; will lr/r0 be >= 128?
        MOVGE   r2, #0                  ; yes: black is worst
        EXIT

;
; Lookup table for Find256. Generated using the following bit of BASIC,
; which is based around the code that was in the original Find256 macro.
;
; FOR srccol%=0 TO 255
; val%=0
; FOR tint%=0 TO &30 STEP 16
; temp1%=&20-tint%
; temp2%=srccol%-(srccol%>>4)
; temp1%+=temp2%
; IF temp1%>&FF THEN temp1%=&FF
; IF temp1%<0 THEN temp1%=0
; newcol%=(temp1% AND &C0)+tint%
; newcol%+=newcol%>>4
; val%+=newcol%<<(tint%/2)
; NEXT tint%
; PRINT "        DCD     &";STR$~(val%)
; NEXT srccol%
;
Find256_Table
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221100
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33221144
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33225544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &33665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665544
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77665588
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77669988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &77AA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA9988
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAA99CC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBAADDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &BBEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC
        DCD     &FFEEDDCC

        END
