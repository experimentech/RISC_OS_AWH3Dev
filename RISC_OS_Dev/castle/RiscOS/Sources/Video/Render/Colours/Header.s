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
; > Header

; ******************************
; *** CHANGES LIST / HISTORY ***
; ******************************
;
; 18-Sep-91 0.96 DDV Bug fix: When calling a buildcolours with R0 <>-1 and R1 =-1 then things act differently
; -------------------------------- RISC OS 3.00 release version ---------------------------
; 22-Sep-91      DDV Fixed the non-internationalised version to use correct Bad SWI error string
; 22-Sep-91 0.97 DDV Bug fix: Modifying error loadings does not always invalidate cache, ie. when reading
; 16-Oct-91      DDV Added ColourTrans_SelectTable with R4 =0 returns size of table generated
; 17-Oct-91      DDV Improved matching in ReturnFontColours (speed up aswell)
; 17-Oct-91      DDV Read/Write error loadings for desktop saving
; 17-Oct-91 0.98 DDV ColourTrans_WriteLoadingsToFile SWI added
; 21-Oct-91      DDV File debugging option added
; 21-Oct-91      DDV Luminance matching replaced by error comparison
; 21-Oct-91 0.99 DDV Removed bonus push in middle of return font colours
;  1-Nov-91      DDV Bug fix: If used on old Font Manager falls back to old method of setting colours
;  2-Nov-91      DDV Fixed some more internationalisation messages for compiling the RISC OS 2.00 version
;  2-Nov-91 1.00 DDV Bug fix: Can always save calibration even if default
; 30-Nov-91      DDV Implement ColourTrans_SetTextColour and SetOppTextColour
; 30-Nov-91 1.01 DDV Added set text colour bit to ColourTrans_SetColour
;  8-Jan-92 1.02 DDV Added support for OS_SetColour gives better ECF handling for foreground / background
; 13-Jan-92      DDV Added the concept of a transfer function to remap the R,G and B on select table calls
; 14-Jan-92      DDV Added ColourTrans_ProcessTable
; 14-Jan-92      DDV Bug fix: Bogus calling of transfer function
; 15-Jan-92 1.03 DDV Changed ColourTrans_ProcessTable to ColourTrans_GenerateTable
; 17-Feb-92 1.04 DDV Bug fix: RISC OS 2.00 code for SetFontColours does not corrupt R3
; 26-Mar-92 1.05 DDV Bug fix: more choosy in the way it selects the colour matching routine.
; 27-Mar-92 1.06 DDV No change - just checking into source filer properly!
; 15-Apr-92 1.07 DDV Bug fix: Font handle -1 = 0; cures bug in RISCOS_Lib
; -------------------------------- RISC OS 3.10 release version ---------------------------
; 23-Jul-92 1.08 DDV Bug fix to SelectTable to yeild colour colours
; --------------------------------- RISC OS 3.10 extra release ----------------------------
;  4-Jun-92      DDV Uses OS_SetColour rather than VDU sequences to change colour
;  6-Jun-92      DDV Changed to colour matching to work in 16 bits per pixel modes
;  6-Jun-92      DDV Build colours no longer attempts to generate a table for 16 bit per pixel modes
;  6-Jun-92      DDV ColourTrans_SelectTable generates a sensible table for 16 and 32 bit per pixel modes
; 15-Jul-92      DDV Dithering at 16 bit-per-pixel implemented
; 16-Jul-92      DDV Abused the cache structure to allow for bit colour numbers / colour words
; 17-Jul-92      DDV Recoded SetGCOL for new depth modes, more sensible about reading palette etc...
; 17-Jul-92      DDV Removed MiscOp to return pattern it was useless anyway
; 17-Jul-92      DDV Removed major bottle neck from 16/32 bit modes, now uses cached routine pointers
; 17-Jul-92      DDV Sorted out support for 256 entry CLUT modes
; 23-Jul-92      DDV Backwards compatibility hack introduced, generate 8 bit-per-pixel tables for deep modes
;  3-Aug-92      DDV Changed that backwards compatibilty hack to return GCOL values, not colour numbers
;  3-Aug-92      DDV ReturnGCOLTable now a service of SelectTable
; 10-Aug-92      DDV Error returned on read / write palette in a depth of mode >= 16 bit per pixel
;  7-Sep-92 1.09 DDV Implemented VIDC20 version of 16 bit-per-pixel handling
;
;-----------------------------------------------------------------------------
; 19-Nov-92 1.08 AMG Recreate DDV's original bug fix for 1.08
; 27-Nov-92      AMG/DDV Fix for dithering with supremacy bit set
; 14-Dec-92 1.09 amg Build non-development version with above fix
;  3-Jan-93      DDV Integeration of Tony's new calibration code finished
;  3-Jan-93      DDV Fall back to old code if old style table / commands issued - wowzer!
;  3-Jan-93      DDV Added ColourTrans_MiscOp (2) to return calibration table type
;  3-Jan-93      DDV Fixed exactly where calibration is applied - always when matching a colour
;
;(amg 16/3/93 merge divergent sources to bring the new calibration code into the Medusa sources)
; 16-Mar-93 1.20 amg Build development version, so I know which code is where!!
; 17-Mar-93      amg Introduce familiarity with new sprite mode words and
;                    pointers to mode selectors.
; 29-Mar-93      amg Select/GenerateTable don't generate a table for 16/32 to 16/32 (any
;                    combination). Table generation for 16/32 down to 8 or below still to be
;                    done.
; 29-Apr-93      amg Complete addition of 32K table generation for 16/32 to 8/lower bpp.
;  4-May-93 1.21 amg new release for return of sources to source filer
; 29-Jul-93 1.22 amg Stop corrupting R7 in Set[Opp]Gcol
; 10-Aug-93 1.23 amg Incorporate fixes from Tony Cheal to code added in 1.09
;                    Add flag to include kludges to get around Green bugs
;                    Fix bug affecting 8bpp non-full CLUT modes
; 20-Aug-93 1.24 amg Add another TCheal bug fix
; 24-Aug-93 1.25 amg Fix another transcription bug in the TCheal code
; 26-Oct-93 1.50 amg Kick the version number up to 1.50 to make space for CC ColourCard
;                    versions. Fix MED-00294. Fix MED-00288. Make bit 4 on R5 to Select/
;                    GenerateTable work. Fix bug MED-00044 (32K table routines call
;                    invalidate cache).
; 02-Nov-93 1.51 amg Fix bug MED-00743 - ReturnFontColours not returning consistent R2
; 04-Nov-93 1.52 amg Fix bug MED-00838 - Setting bit 4 of R5 on Sel/Gen table
;                    still returned bytes - historical bug - using input l2bpp
;                    instead of output l2bpp to decide table width.
; 05-Nov-93 1.53 amg Fix bug with selecttable R2=0 calls
; 06-Nov-93 1.54 amg Fix a historical bug with R0=mode, R1=-1 selecttable calls
; 10-Nov-93 1.55 amg (another day, another ColourTrans). Fix two old bugs, both contributing to
;                    ReturnGCOL sometimes returning Colour numbers instead of GCOL numbers
;                    in 8bpp modes.
; 02-Dec-93 1.56 amg Fix ReturnGCOLForMode - was returning colour numbers when it should
;                    have returned GCOLs.
; 06-Dec-93 1.57 amg No code changes, but added lots more systematic debugging facilities
;                    in readiness for deciding about sorting out what ReturnGCOL etc should
;                    be doing in 16/32bpp. New version number needed so I could lock out
;                    the sources. New debugging switches: input1, input2, output, showswis.
;                    A couple of ADRs become ADRLs when these switches are turned on.
; 07-Jan-94 1.58 amg Fix bug MED-01821. 32K table routine calls the InvalidateCache routine
;                    as a SWI to get R12 set up right.
;                    Also add some early termination tweaks in the routine core having
;                    spotted a way to use a free register.
; 28-Jan-94 1.59 amg Fix bug MED-02212 - ReturnGCOLForMode was failing to give Bad Mode error.
;                    Fix BadDepth error message - using wrong macro to make the error block,
;                    and check for others.
; 02-Feb-94 1.60 amg Fix bug MED-0???? - ColourTrans refuses to die if it has 32K tables in
;                    the rma. Flag 'immortal' controls this.
; 16-Feb-94 1.61 amg Add MED-02882 fixes to memory usage by 32K routines
; 23-Feb-94 1.62 amg Add MED-03007 fix to MED-2882 fix - corruption of R9 in one of the
;                    relocated code sections
; 12-May-99 1.69 KJB 32-bit compatible.

                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:FSNumbers
                GET     hdr:ModHand
                GET     hdr:NewErrors
                GET     hdr:VduExt
                GET     hdr:Services
                GET     hdr:Font
                GET     hdr:Sprite
                GET     hdr:PublicWS
                GET     hdr:ExtraLong
                GET     hdr:Proc
                GET     hdr:MsgTrans
                GET     hdr:DDVMacros
                GET     hdr:PaletteV
                GET     hdr:ColourTran
                GET     hdr:Symbols
                GET     hdr:HostFS
                GET     hdr:variables
                GET     hdr:HighFSI
                GET     hdr:FileTypes
                GET     hdr:Squash

                ;Debugging SelectTable with older versions of these macros which
                ;call OS_CLI and hence corrupt scratchspace can cause 'interesting'
                ;side effects....

                GBLL    debug_noscratchspace
debug_noscratchspace SETL {FALSE}
                GET     hdr:NDRDebug

                GBLL    StrongARM
StrongARM       SETL    {TRUE}

                ; True if MUL is slow when given large (or negative) numbers
                ; It seems that ARMv4 (i.e. StrongARM) is the first to have a
                ; decent MUL implementation - ARMv3 and below suffer badly with
                ; large numbers
                GBLL    SlowMultiply
SlowMultiply    SETL    NoARMv4

                GET     VersionASM

                GBLL    debug
                GBLL    hostvdu
                GBLL    file

                GBLL    newpalettestuff
                GBLL    international
                GBLL    callpaletteV
                GBLL    docalibration
                GBLL    fontcache
                GBLL    defaultpalettes
                GBLL    dither
                GBLL    checkluminance
                GBLL    usesetcolour
                GBLL    buginRISCOSLib
                GBLL    newcalibration
                GBLL    work_with_green
                GBLL    immortal

debug           SETL    false
hostvdu         SETL    false
file            SETL    true ;(:LNOT: hostvdu) :LAND: debug
debug_flush     SETL    true

; features

international   SETL    :LNOT: oldos    ; produce internationalised code
callpaletteV    SETL    true            ; call the paletteV routines
docalibration   SETL    true            ; perform calibration when reading the palette
fontcache       SETL    false           ; font colour cacheing
defaultpalettes SETL    false           ; clever palette reading
dither          SETL    true            ; dithering
usesetcolour    SETL    :LNOT: oldos    ; use OS_SetColour to set ECF patterns
buginRISCOSLib  SETL    true            ; fixes handle of -1 passed to SetFontColours
newcalibration  SETL    Module_Version > 109   ; new calibration code in V1.09 and beyond

checkluminance  SETL    Module_Version = 098   ; check using luminance, instead of error calculation
work_with_green SETL    false           ; include kludges to dodge bugs in Wimp/Draw in Green
immortal        SETL    Module_Version >= 160  ; don't die while people are using my 32K tables

                [ work_with_green
usesetcolour    SETL    false
                !       0,"WARNING: Building Green compatible version!"
                ]

; Two kludges are introduced by this switch, both resulting from bugs in Green which
; only manifest themselves when used with newer versions of ColourTrans. In the past
; it has been tolerable to feed a junk sprite area pointer to ColourTrans_SelectTable/
; ColourTrans_GenerateTable. However this pointer must now be valid to allow ColourTrans
; to tell the difference between a pointer to a mode selector and a pointer to a sprite
; area. There are two known culprits in Green:
;
; Wimp: Inadvertently uses 0x8000
; Draw: Uses 256 when it has a sprite with no area.
;
; Secondly, it suppresses the setting of the bits in the help/command table for
; Internationalisation - having these bits set break the module under RO2/3.
;
; Following a FRM decision the first of these has been retained as standard behaviour.

; debugging options

xx              SETD    false           ; misc code
xx2             SETD    false           ; temporary stuff
calibrate       SETD    true            ; debugging calibration
palettes        SETD    false           ; palette reading and writing
fontcolours     SETD    false           ; font colour setting
fontcolours2    SETD    false           ; more conclusive debugging
fontcolours3    SETD    false           ; finally the lowest of the low debugging
buildcolours    SETD    false           ; build colours function
buildcolours2   SETD    false           ; more in-depth debugging of build colours
selecttable     SETD    false           ; processing of select table calls
dither          SETD    false           ; debugging of dither routines
dither2         SETD    false           ; more indepth dithering information
enhanced        SETD    false           ; enhanced graphics modes (16 and 32
                                        ; bit per pixel)
newcalibrate    SETD    true            ; new calibration stuff
ag              SETD    false           ; amg misc debugging - could be
                                        ;   anywhere!
table32K        SETD    true            ; 32K translation tables for Select/GenerateTable
input1          SETD    false           ; terse information on input parameters
input2          SETD    false           ; verbose information on input parameters
output          SETD    false           ; information on returned parameters
showswis        SETD    false           ; details on all SWIs handled

;------------------------------------------------------------------------------
;
; Define workspace
;
;------------------------------------------------------------------------------

; Define structure of cache entries

                        ^ 0

CacheEntry              # 3     ;Check word &00BBGGRR
CacheValid              # 1     ;top byte of first word in cache entry: non-zero implies invalid

CachedColour            # 4     ;Colour number (now 32 bits)
CachedGCOL              # 4     ;As are GCOL values
CachedPattern           # 4*4   ;Pattern block as used for dithering

CachedPatternValid      # 1     ; =-1 if CachedPattern is invalid
CachedSpare             # 3     ; Spare bytes in cache entries. Some get reused for module workspace!

                        ASSERT  (:INDEX: @)<=32
                        AlignSpace 32

CacheEntrySize          * :INDEX: @

CacheEntries            * 64    ;Must be power of 2
CacheTotalSize          * CacheEntries *CacheEntrySize


; Workspace hidden in the spare cache entry bytes

                        ASSERT ?CachedSpare = 3
CacheEmpty              * CachedSpare   ; =0 if cache is fully empty, allows us to avoid needless invalidation loops
                        ASSERT ((:INDEX: CachedModeFlags) :AND: 1)=0
CachedModeFlags         * CachedSpare+1 ; cached bits 0-15 of mode flags
CachedL2BPP             * CachedSpare+CacheEntrySize ; cached L2BPP of current mode
CachedL2NColour         * CachedSpare+CacheEntrySize+1 ; cached log2 of (NColour+1)

; Define structure of font colour cache block.

                        ^ 0
FontCol_Link            # 4
FontCol_Back            # 4     ; background colour (&BBGGRR00 + max col offset in bits 0..7)
FontCol_Fore            # 4     ; foreground colour (&BBGGRR00)
FontCol_Data            # 4*16
FontCol_Size            * :INDEX: @

; Define main workspace layout.

                        ^ 0

Cache                   # CacheTotalSize

Calibration_ptr         # 4     ; -> calibration table for screen
Calibration_pending     # 4     ; *command
Calibration_remaining   # 4     ; *command
                      [ newcalibration
Calibration_newtable    # 4     ; non-zero then new format table (else old style)
                      ]
                        AlignSpace 16

text_buffer12           # 12    ; Whilst writing text
                        AlignSpace 16

PaletteFlags            # 4     ; Flags used when reading palette from area
PaletteAt               # 4     ; Pointer to palette table (=0 if screen)
PaletteCopy             # 4     ; Copy of palette pointer used to see if cache is valid

PaletteCacheStart       # 4     ; Start of cached palette / =0 if not
PaletteCacheEnd         # 4     ; End of palette cache
PaletteBestV            # 4     ; Best routine for this palette to find colour
PaletteWorstV           # 4     ; Worst routine for this palette to find colour

                      [ fontcache
FontColourHead          # 4     ; Pointer to list of font colour blocks
                      ]

ColourErrorLoading      # 4     ; &BlGlRl00

BestColourV             # 4     ; Pointer to best colour routine
WorstColourV            # 4     ; Pointer to worst colour routine
FontColourCodeAt        # 4     ; Pointer to routine to advance the pointers
;;;FontColourCode          # 4*4   ; Four words for self compiling code for font colour caching - not used now

PatternTemp             # 4*8   ; Temporary store for expanding pattern tables into

                      [ international
MessagesBlock           # 16    ; Block used to open messages file
MessagesOpen            # 4     ; When non-zero then messages file is open
                      ]

BuildColoursL2BPP       # 4     ; Log2 value for the previous build colours
TargetL2BPP             # 4     ; Log2 value for dest - used to dimension
                                ; return spacing

grey8bpp_palette        # 4     ; Default 8bpp greyscale palette (black -> white), in ResourceFS cache

                        AlignSpace 16
; These are for the 32K table stuff.
anchor_resourcefs       # 4     ; Initial pointer to chain of ResourceFS palettes
                        AlignSpace 16
anchor_tables           # 4     ; Initial pointer to built/loaded 32K tables
                        AlignSpace 16
temp_palette            # 4     ; Temporary pointer within 32K generation
                        AlignSpace 16
temp_table              # 4     ; Temporary pointer within 32K generation
                        AlignSpace 16
temp_errortable         # 4     ; Temporary pointer within 32K generation
                        AlignSpace 16
temp_gbpb               # 128   ; for gbpb calls and filename expansion
                        [ immortal
persist                 # 4     ; Don't die flag
                        ]

                        AlignSpace 256

CurrentPalette          # 256*4 ; Store for the default palette

ws_required             * :INDEX: @

; Define some other constants required

DefaultErrorLoading     * &01040200

; Format of new style calibration tables

                        ^ 0
calib_version           # 4     ; Revision of carlibation table ( = 0 then new style )
calib_idealblack        # 4     ; Ideal black for calibration table
calib_idealwhite        # 4     ; Ideal white for calibration table
calib_postprocessSWI    # 4     ; SWI for post processing the colour
calib_tablecount        # 4     ; number of tables (1 or 3)
calib_gammatables       # 0     ; start of the tables

calib_gammasize         * 256

                        ASSERT :INDEX: calib_gammatables = 20

;------------------------------------------------------------------------------
;
; Define some common macros
;
;------------------------------------------------------------------------------

        MACRO                           ; Compile a suitable error block for international versions
$l      MakeEitherErrorBlock $name, $noalign
      [ international
$l      MakeInternatErrorBlock $name, $noalign
      |
$l      MakeErrorBlock $name, $noalign
      ]
        MEND

        MACRO                           ; Jump to best colour routine
$l      GetBestColour $cc
$l      MOV$cc  LR,PC                   ; Setup a return address
        LDR$cc  PC,[WP,#BestColourV]    ; Jump to routine (assumes vector setup)
        MEND

        MACRO                           ; Jump to worst colour routine
$l      GetWorstColour $cc
$l      MOV$cc  LR,PC                   ; Setup a suitable return address
        LDR$cc  PC,[WP,#WorstColourV]   ; Jump to routine (assumes vector setup)
        MEND

        MACRO
$l      BuildColoursForBest
$l
        BL      build_colours           ; Build colour table as required
        STR     R7,[WP,#BestColourV]
        MEND

        MACRO
$l      BuildColoursForWorst
$l
        BL      build_colours           ; Build colour table as required
        STR     R8,[WP,#WorstColourV]
        MEND

        MACRO
$l      BadMODE $cc
      [ international
        addr    R0,ErrorBlock_BadMODE,$cc
      |
        addr    R0,ErrorBlock_NaffMODE,$cc
      ]
        MEND

;------------------------------------------------------------------------------
;
; Define the module header
;
;------------------------------------------------------------------------------

        AREA    |ColourTrans$$Code|, CODE, READONLY, PIC
        ENTRY

ModuleStart
        & 0                             ;not an application
        & Initialise -ModuleStart
        & Die -ModuleStart
        & ServiceCalls -ModuleStart
        & Title -ModuleStart
        & Help -ModuleStart
        & Commands -ModuleStart
        & ColourTransSWI *Module_SWIChunkSize +Module_SWISystemBase
        & SWIs -ModuleStart
        & SWItable -ModuleStart
        & 0                             ;no special decoding
 [ international
        & Filename -ModuleStart
 |
        & 0
 ]
        & ModuleFlags -ModuleStart

Help    = "Colour Selector",9,"$Module_HelpVersion"
      [ oldos
        = " for $whofor"
      ]
      [ debug
        = " Development version"
      ]
        = 0
        ALIGN

ModuleFlags
 [ :LNOT: No32bitCode
        & ModuleFlag_32bit
 |
        & 0
 ]

Commands
        = "ColourTransMapSize",0        ;*ColourTransMapSize
        ALIGN
        & ColourTransMapSize_Code -ModuleStart
        [ work_with_green
        & &00030703
        |
        & &00030703 :OR: International_Help
        ]
        & 0
        & HelpStarCommands -ModuleStart

        = "ColourTransMap",0            ;*ColourTransMap
        ALIGN
        & ColourTransMap_Code -ModuleStart
        [ work_with_green
        & &00FF0001
        |
        & &00FF0001 :OR: International_Help
        ]
        & 0
        & HelpStarCommands -ModuleStart

        = "ColourTransLoadings",0       ;*ColourTransLoadings
        ALIGN
        & ColourTransLoadings_Code -ModuleStart
        [ work_with_green
        & &00030703
        |
        & &00030703 :OR: International_Help
        ]
        & 0
        & HelpStarCommands -ModuleStart

        & 0                             ;end of table

HelpStarCommands
 [ work_with_green
        = "ColourTrans commands are for internal use only",0
 |
 [ international
        = "HCLTINT", 0
 |
        = "ColourTrans commands are for internal use only",0
 ]
 ]

Title
SWItable
        = "ColourTrans", 0
        = "SelectTable", 0
        = "SelectGCOLTable", 0
        = "ReturnGCOL",0
        = "SetGCOL",0
        = "ReturnColourNumber",0
        = "ReturnGCOLForMode",0
        = "ReturnColourNumberForMode",0
        = "ReturnOppGCOL",0
        = "SetOppGCOL",0
        = "ReturnOppColourNumber",0
        = "ReturnOppGCOLForMode",0
        = "ReturnOppColourNumberForMode",0
        = "GCOLToColourNumber",0
        = "ColourNumberToGCOL",0
        = "ReturnFontColours",0
        = "SetFontColours",0
        = "InvalidateCache",0
        = "SetCalibration",0
        = "ReadCalibration",0
        = "ConvertDeviceColour",0
        = "ConvertDevicePalette",0
        = "ConvertRGBToCIE",0
        = "ConvertCIEToRGB",0
        = "WriteCalibrationToFile",0
        = "ConvertRGBToHSV",0
        = "ConvertHSVToRGB",0
        = "ConvertRGBToCMYK",0
        = "ConvertCMYKToRGB",0
        = "ReadPalette",0
        = "WritePalette",0
        = "SetColour",0
        = "MiscOp",0
        = "WriteLoadingsToFile",0
        = "SetTextColour",0
        = "SetOppTextColour",0
        = "GenerateTable",0
        = "",0
        ALIGN

;------------------------------------------------------------------------------
;
; Initalise
;
; Handle the module startup, basicly claim the ColourV ready for calls into the
; module.
;
; in    WP -> workspace of the module
; out   V =1 => R0 -> error block

Initialise ROUT

        Push    "R0-R2,LR"

      [ file
        Debug_Open "<ColourTrans$$Debug>"
      ]

        MOV     R0,#ColourV
        ADRL    R1,ColourVCode
        MOV     R2,WP
        SWI     XOS_Claim               ;Attempt to reclaim the ColourV for SWIs

        STRVS   R0,[SP]
        Pull    "R0-R2,PC"              ;Return any fatal errors

;..............................................................................
;
; validateworkspace
;
; The module has been called, it needs its workspace so we must now attempt to claim
; and reset it.
;
; in    WP -> private word (=0)
;
; out   V =1 => R0 -> error block
;       else,   [Entry WP] -> workspace block
;               WP -> workspace

validateworkspace ROUT
        Push    "R0-R9,LR"

        LDR     LR,[WP]
        CMP     LR,#0                   ;Do I already have the workspace?
        MOVNE   WP,LR
        Pull    "R0-R9,PC",NE           ;Yes so return V will be clear; WP ->Workspace

        MOV     R0,#ModHandReason_Claim
        LDR     R3,=ws_required
        SWI     XOS_Module              ;Attempt to claim the workspace
        STRVS   R0,[SP]
        Pull    "R0-R9,PC",VS           ;Return if it errors; R0 -> error block

        STR     R2,[WP]
        MOV     WP,R2                   ;Setup private word and workspace pointer

	MOV	R0, #-1
	STRB	R0, [WP,#CacheEmpty]	;Force a cache flush

        MOV     R0,#0                   ;Performing default calibration
        [ immortal
        STR     R0,[WP,#persist]        ;We may die
        ]
        STR     R0,[WP,#Calibration_ptr]
        STR     R0,[WP,#Calibration_pending]
        [ newcalibration
        STR     R0,[WP,#Calibration_newtable]
        ]
        STR     R0,[WP,#PaletteAt]      ;Palette currently at screen
        STR     R0,[WP,#PaletteCopy]
        STR     R0,[WP,#PaletteFlags]
        STR     R0,[WP,#BestColourV]    ;Reset the two best and worst colour vectors within workspace
        STR     R0,[WP,#WorstColourV]
      [ fontcache
        STR     R0,[WP,#FontColourHead]
      ]
      [ international
        STR     R0,[WP,#MessagesOpen]
      ]

        ;set up the pointers for 32K tables
        STR     R0,[WP,#anchor_resourcefs]
        STR     R0,[WP,#grey8bpp_palette]

        [ debugtable32K
        ADD     R1,WP,#anchor_resourcefs
        Debug   table32K,"anchor_resourcefs is at",R1
        ]

        STR     R0,[WP,#anchor_tables]

        [ debugtable32K
        ADD     R1,WP,#anchor_tables
        Debug   table32K,"anchor_tables is at",R1
        ]

        STR     R0,[WP,#temp_palette]
        STR     R0,[WP,#temp_table]
        STR     R0,[WP,#temp_errortable]

        LDR     R0,=DefaultErrorLoading ;Setup default error loading
        STR     R0,[WP,#ColourErrorLoading]

        BL      InitCache               ;Reset the cache areas

        Debug   table32K,"Performing initial scan of resourcefs"

        BL      scan_resourcefs

        CLRV
        Pull    "R0-R9,PC"

scan_resourcefs ROUT
        Push    "R0-R7,LR"

        Debug   table32K,"Rebuilding resourcefs structure"

        ; try to build the palette lookup structure
        MOV     R4,#0                   ;Initial offset
10
        MOV     R0,#10
        ADRL    R1,palettedir
        ADD     R2,WP,#temp_gbpb
        MOV     R3,#1
        MOV     R5,#32
        MOV     R6,#0
        SWI     XOS_GBPB
        MOV     R7,R4
        BVS     %FT30

        Debug   table32K,"#entries read:",R3

        CMP     R3,#1
        BNE     %FT30                    ;nothing read

        LDR     R3,[WP,#temp_gbpb+8]     ;length
        Debug   table32K,"File length",R3
        ADD     R3,R3,#cachedtable_palette+16 ; 4 bytes for ROM pointer + 12 bytes extra for name
        MOV     R2,#0
        MOV     R0,#ModHandReason_Claim
        Debug   table32K,"Claiming",R3
        SWI     XOS_Module
        BVS     %FT30
        MOV     R6,R2

        ;link it in to the structure
        LDR     R0,[WP,#anchor_resourcefs]
        TEQ     R0,#0

        STREQ   R2,[WP,#anchor_resourcefs]
        BEQ     %FT20
21
        LDR     R1,[R0,#cachedtable_next] ;fetch the next pointer
        TEQ     R1,#0
        MOVNE   R0,R1
        BNE     %BT21

        STR     R2,[R0,#cachedtable_next]

20      ;now it is linked, fill it
        MOV     R0,#0
        STR     R0,[R2,#cachedtable_next]
        LDR     R3,[WP,#temp_gbpb+8]     ;length
        STR     R3,[R2,#cachedtable_palsize]
        MOV     R3,#32768 ; only 32K colour resfs tables supported atm
        STR     R3,[R2,#cachedtable_tabsize]

        MOV     R0,#12
        ADRL    R4,palettepath
        ADD     R2,R2,#cachedtable_palette
        MOV     R3,#0
        ADD     R1,WP,#temp_gbpb
        ADD     R1,R1,#20
        SWI     XOS_File
        BVS     %FT30

        ADD     R6,R6,#cachedtable_palette

        ; If this was the default 8bpp greyscale palette, remember it so we can use elsewhere
        LDR     R3,[WP,#temp_gbpb+20]
        LDR     R4,grey8bpp_name
        TEQ     R3,R4
        LDREQ   R3,[WP,#temp_gbpb+24]
        LDREQ   R4,grey8bpp_name+4
        BICEQ   R3,R3,#&FF000000
        TEQEQ   R3,R4
        STREQ   R6,[WP,#grey8bpp_palette]

        LDR     R3,[WP,#temp_gbpb+8]     ;length
        ADD     R6,R6,R3

        ;copy the name across
        MOV     R3,#0
        STR     R3,[R6],#4
        LDR     R3,[WP,#temp_gbpb+20]
        STR     R3,[R6],#4
        LDR     R3,[WP,#temp_gbpb+24]
        STR     R3,[R6],#4
        LDR     R3,[WP,#temp_gbpb+28]
        STR     R3,[R6]

        MOV     R4,R7

        B       %BT10

30
        Pull    "R0-R7,PC"

palettedir     = "Resources:$.Resources.Colours.Palettes",0
palettepath    = "Resources:$.Resources.Colours.Palettes.",0
        ALIGN
grey8bpp_name  = "8greys",0,0
        ALIGN

;------------------------------------------------------------------------------
;
; Die
;
; Handle the module die entry.  When recieved we must attempt to tidy up our
; workspace and then return.
;
; in    R10 non-zero if RMReiniting
;       WP -> Workpace block
;
; out   V =1 => R0 -> error block

Die     ROUT

        Push    "LR"

        LDR     R1,[WP]
        TEQ     R1,#0                   ;Do I own any workspace?
        BEQ     %FT10                   ;No, so return

        ; release anything for the 32K tables that still claimed

        [ immortal
        LDR     R2,[R1,#persist]
        TEQ     R2,#0
        MOVNE   WP,R1
        Pull    "LR",NE
        BNE     cannotdie
        ]

        LDR     R2,[R1,#anchor_tables]
        BL      Free32KChain
        MOV     R2,#0
        STR     R2,[R1,#anchor_tables]

        LDR     R2,[R1,#anchor_resourcefs]
        BL      Free32KChain
        MOV     R2,#0
        STR     R2,[R1,#anchor_resourcefs]
        STR     R2,[R1,#grey8bpp_palette]

        LDR     R2,[R1,#temp_palette]
        BL      Free32K
        MOV     R2,#0
        STR     R2,[R1,#temp_palette]

        LDR     R2,[R1,#temp_table]
        BL      Free32K
        MOV     R2,#0
        STR     R2,[R1,#temp_table]

        LDR     R2,[R1,#temp_errortable]
        BL      Free32K
        MOV     R2,#0
        STR     R2,[R1,#temp_errortable]

      [ fontcache
        ADD     R2,R1,#FontColourHead
        BL      FreeChain               ;Release cache of font colours
      ]

        MOVVC   R0,#ModHandReason_Free
        ADDVC   R3,R1,#Calibration_ptr
        BLVC    removeblock             ;Attempt to remove the current calibration tables
        addl    R3,R1,Calibration_pending
        BLVC    removeblock             ;And any pending ones
        Pull    "PC",VS

      [ international

        LDR     R0,[R1,#MessagesOpen]
        TEQ     R0,#0                   ;Is the messages file open yet?
        addl    R0,R1,MessagesBlock,NE
        SWINE   XMessageTrans_CloseFile
      ]
10
        MOV     R0,#ColourV
        ADR     R1,ColourVCode          ;->Routine to trap colour vector calls
        MOV     R2,WP
        SWI     XOS_Release             ;And then remove it from the vector chain

      [ file
        Debug_Close
      ]

        CLRV
        Pull    "PC"

Free32K ROUT
        Push    "LR"
        Debug   table32K,"Freeing",R2

        TEQ     R2,#0
        MOVNE   R0,#ModHandReason_Free
        SWINE   XOS_Module              ;Assumes R0 contains reason code
        Pull    "PC"

Free32KChain ROUT
        Push    "R4,LR"
        Debug   table32K,"Freeing(32k)",R2
10
        TEQ     R2,#0                   ;is this a valid link ?
        Pull    "R4,PC",EQ

        LDR     R4,[R2,#cachedtable_next] ;yes, so see where it goes next
        MOV     R0,#ModHandReason_Free
        SWI     XOS_Module              ;Assumes R0 contains reason code
        MOV     R2,R4                   ;Is next link non-zero ?
        B       %BT10                   ;yes, so go and release it

;..............................................................................
;
; remove block
;
; in    R3 contains address of word block hanging from
;       R10 from init call contains the rmreinit flags
;
; out   V =1 => R0 -> error block
;       else    [R3] updated to contain zero if block released

removeblock ROUT

        Push    "R1,R3,LR"

        LDR     R2,[R3]
        CMP     R2,#0                   ;Is there a block hanging from word?
        Pull    "R1,R3,PC",EQ

        TEQ     R10,#0                  ;Is this an attempt to RMTidy the module?
        BNE     %FT10

        SWI     XOS_Module              ;Assumes R0 contains reason code
        MOVVC   R2,#0
        STRVC   R2,[R3]                 ;Mark as released if worked
        Pull    "R1,R3,PC"
10
      [ immortal
cannotdie
      ]
      [ international
        ADR     R0,ErrorBlock_CantKill
        B       LookupError             ;Complain if unable to kill ColourTrans

        MakeErrorBlock CantKill
      |
        ADR     R0,ErrorBlock_CantKill2
        B       LookupError             ;Complain if unable to kill ColourTrans

        MakeErrorBlock CantKill2
      ]

;-------------------------------------------------------------------------------
;
; Service entry
;
; Process service calls recieved by the module.
;
; in    R1 reason code for call
; out   all should be preserved unless documented

;Ursula format
;
        ASSERT  Service_Reset              < Service_ModeChange
        ASSERT  Service_ModeChange         < Service_ResourceFSStarted
        ASSERT  Service_ResourceFSStarted  < Service_CalibrationChanged
        ASSERT  Service_CalibrationChanged < Service_WimpSaveDesktop
        ASSERT  Service_WimpSaveDesktop    < Service_SwitchingOutputToSprite
;
UServTab
        DCD     0
        DCD     UService - ModuleStart
        DCD     Service_Reset
        DCD     Service_ModeChange
        DCD     Service_ResourceFSStarted
      [ debugcalibrate
        DCD     Service_CalibrationChanged
      ]
        DCD     Service_WimpSaveDesktop
        DCD     Service_SwitchingOutputToSprite
        DCD     0
        DCD     UServTab - ModuleStart
ServiceCalls ROUT
        MOV     r0, r0
UService
      [ debugcalibrate
        TEQ     R1,#Service_CalibrationChanged
        BNE     %FT90                   ;Has the calibration changed

        LDR     WP,[WP]
        Debug   calibrate,"Service_CalibrationChanged recieved"
        MOV     PC,LR
      ]
90
        TEQ     R1,#Service_WimpSaveDesktop
        BEQ     save_desktop_to_file    ;Handle desktop saving

        TEQ     R1,#Service_Reset
        BEQ     Initialise              ;Attempt to get back on the vector after reset

        TEQ     R1,#Service_SwitchingOutputToSprite
        BEQ     output_to_sprite        ;Handle tracking of output to sprites

        TEQ     R1,#Service_ResourceFSStarted
        BEQ     rescan_resourcefs

        TEQ     R1,#Service_ModeChange
        MOVNE   PC,LR

        LDR     WP,[WP]
        TEQ     WP,#0                   ;Any workpsace allocated yet?
        MOVEQ   PC,LR                   ;If not then we must return as cache is invalidated later

        ;also throw away the current collection of 32K tables and release
        ;the space

        STMFD   R13!,{R0-R3,LR}
        LDR     R2,[WP,#anchor_tables]
        BL      Free32KChain
        MOV     R0,#0
        [ immortal
        STR     R0,[WP,#persist]        ;so we can die if told to
        ]
        STR     R0,[WP,#anchor_tables]
        LDMFD   R13!,{R0-R3,LR}

        B       InvalidateCache_Code    ;Yes, so invalidate the cache

rescan_resourcefs
        ; The contents of ResourceFS has changed, which could be because
        ; more palettes and tables have been added - rescan them.

        LDR     WP,[WP]
        TEQ     WP,#0                   ;Any workpsace allocated yet?
        MOVEQ   PC,LR                   ;If not then we must return

        Push    "R0-R4,LR"

        Debug   table32K,"Resourcefs has changed - discarding all cached tables"

        ; release anything for the 32K tables that still claimed
        ; (junk both lists so that anything previously built can be reconsidered
        ; in the light of new palette files)

        MOV     R4,#0
        LDR     R2,[WP,#anchor_resourcefs]
        STR     R4,[WP,#anchor_resourcefs]
        STR     R4,[WP,#grey8bpp_palette]
        BL      Free32KChain

        LDR     R2,[WP,#anchor_tables]
        STR     R4,[WP,#anchor_tables]
        BL      Free32KChain

        BL      scan_resourcefs

        Pull    "R0-R4,PC"

;------------------------------------------------------------------------------
;
; SWI despatching
;
; Handle the despatch of SWIs within the module.  This simply involves calling
; the ColourV so that anyone hanging onto it can recieve the calls.
;
; in    R11 =SWI number minus base
;       WP ->private word
;
; out   V =1 => R0 -> error block

SWIs    ROUT

        WritePSRc SVC_mode, R10         ;Enable IRQs

      [ debugshowswis
        STMFD   R13!,{R11,R12,R14}
        ADRL    R12,SWItable
        ADD     R12,R12,#12              ; Skip "ColourTrans",0 prefix
        TEQ     R11,#0
        BEQ     %FT10
02
        LDRB    R14,[R12],#1
        TEQ     R14,#0
        BNE     %BT02
        SUBS    R11,R11,#1
        BNE     %BT02
10
        DebugS  showswis,"ColourTrans SWI ",R12
        Debug   showswis,"R0-R5",R0,R1,R2,R3,R4,R5
        LDMFD   R13!,{R11,R12,R14}
      ]

        Push    "R8-R9,LR"

        MOV     R8,R11                  ;Get the modol SWI number
        MOV     R9,#ColourV
        SWI     XOS_CallAVector         ;Pass down the vector (number in R9)

       [ :LNOT: No32bitCode
        MRS     R10,CPSR
        TST     R10,#2_11100
        Pull    "R8-R9,PC",NE           ;32-bit return
       ]
        ; 26-bit return
        Pull    "R8-R9,LR"
        MOVVCS  PC,LR
        ORRVSS  PC,LR,#V_bit            ;Return any errors, but preserve other flags

;..............................................................................
;
; ColourVCode
;
; Handle the despatch of events via the ColourV as SWIS within the module, when
; called we may not own any workspace so the workspace pointer needs to be
; validated, also we check to see if we need to invalidate the cache when output
; has been switched away to a sprite
;
; in    R0.. parameters for the call
;       R8 reason code
;       WP -> private word
;       LR -> routine to return to if passing on
;      {LR} routine to return to if claiming
;
; out   V =1 => R0 -> error block
;       as documented

ColourVCode ROUT

        TEQ     R8,#ColourTrans_InvalidateCache -ColourTrans_SelectTable
        TEQNE   R8,#ColourTrans_WriteCalibrationToFile -ColourTrans_SelectTable
        LDREQ   LR,[WP]
        TEQEQ   LR,#0                   ;If not suitable if workspace not owned then return
        Pull    "PC",EQ

        BL      validateworkspace       ;Resolve workspace pointer
        Pull    "PC",VS

        Push    "R0-R1"

        addl    R0,WP,PaletteAt
        LDMIA   R0,{R0,R1}
        TEQ     R0,R1                   ;Have we switched output to a sprite etc?
        BLNE    InvalidateCache_Code

        Pull    "R0-R1,LR"

        CMP     R8,#(%20-%10)/4         ;Within range?
        ADDCC   PC,PC,R8,LSL #2         ;If so then despatch via the table
        B       %20
10
        B       SelectTable_Code
        B       SelectGCOLTable_Code
        B       ReturnGCOL_Code
        B       SetGCOL_Code
        B       ReturnColourNumber_Code
        B       ReturnGCOLForMode_Code
        B       ReturnColourNumberForMode_Code
        B       ReturnOppGCOL_Code
        B       SetOppGCOL_Code
        B       ReturnOppColourNumber_Code
        B       ReturnOppGCOLForMode_Code
        B       ReturnOppColourNumberForMode_Code
        B       GCOLToColourNumber_Code
        B       ColourNumberToGCOL_Code
        B       ReturnFontColours_Code
        B       SetFontColours_Code
        B       InvalidateCache_Code
        B       SetCalibration_Code
        B       ReadCalibration_Code
        B       ConvertDeviceColour_Code
        B       ConvertDevicePalette_Code
        B       ConvertRGBToCIE_Code
        B       ConvertCIEToRGB_Code
        B       WriteCalibrationToFile_Code
        B       ConvertRGBtoHSV_Code
        B       ConvertHSVtoRGB_Code
        B       ConvertRGBtoCMYK_Code
        B       ConvertCMYKtoRGB_Code
        B       ReadPalette_Code
        B       WritePalette_Code
        B       SetColour_Code
        B       MiscOp_Code
        B       WriteLoadingsToFile_Code
        B       SetTextColour_Code
        B       SetOppTextColour_Code
        B       GenerateTable_Code
20
      [ international
        ADR     R0,ErrorBlock_ModuleBadSWI
      |
        ADR     R0,ErrorBlock_NaffSWI
      ]
        B       LookupError                             ;Return invalid call to ColourV

      [ international
        MakeErrorBlock ModuleBadSWI
        MakeEitherErrorBlock BadMODE
      |
        MakeErrorBlock NaffSWI
        MakeEitherErrorBlock NaffMODE
      ]

;------------------------------------------------------------------------------
;
; ColourTrans_InvalidateCache implementation
;
;   Entry: -
;
;   Exit:  V set   => R0 ->Error block
;          V clear => -
;
; Handle the invalidation of the ColourTrans cache.  This should be called
; when output is switched to a sprite and when ever the palette has changed.
;
; The routine will attempt to invalidate the normal colours cache and
; free the chain of blocks containing the font colours.
;
;------------------------------------------------------------------------------

InvalidateCache_Code ROUT
        Debug   input1,"InvalidateCache"
        Debug   input2,"InvalidateCache"
        Push    "R0-R2,LR"

        BL      InitCache               ;Clear the colour cache

      [ fontcache
        ADDVC   R2,R12,#FontColourHead
        BLVC    FreeChain               ;Attempt to release the font colours
      ]

        STRVS   R0,[SP]                 ;Return any errors generated
        Pull    "R0-R2,PC"

;..............................................................................
;
; FreeChain
;
; Attempt to release the list of font colours attached to the word passed in
; at R2.  The routine loops releasing them all and then marks the word addressed
; by R2 as zero on exit.
;
; in    R2 -> head of the chain
; out   V =1 => R0 -> error block
;       else,   chain of blocks in [R2] freed (=0) on exit

      [ fontcache

        ASSERT  FontCol_Link =0

FreeChain ROUT

        EntryS  "R0-R2"

        Debug   xx,"Releasing font colour cache at",R2

        LDR     R1,[R2]                 ;Get pointer to the first block
        NOV     R14,#0
        STR     R14,[R2]                ;Zero the first element of the chain
01
        MOVS    R2,R1
        EXITS   EQ                      ;Return when the end of the chain has been reached

        LDR     R1,[R2]                 ;R1 -> next block
        SWI     XOS_Module
        B       %BT01                   ;Loop back until all released

      ]

;..............................................................................
;
; InitCache
;
; This code will reset the contents of the cache.
;
; in    -
; out   V =1 => R0 -> error block

InitCache ROUT

        Push    "LR"

        MOV     R0,#-1
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable    ;Attempt to read the current Log2BPP
        STRB    R2,[WP,#CachedL2BPP]

        Debug   xx,"Init cache Log2BPP is",R2

        MOV     R1,#VduExt_ModeFlags
        SWI     XOS_ReadModeVariable    ;Attempt to read the mode flags
        MOVCS   R2,#0
      [ debug
        Debug   xx,"Cache mode flags",R2
      ]
      [ NoARMv4
        STRB    R2,[WP,#CachedModeFlags]
        MOV     R2,R2,LSR #8
        STRB    R2,[WP,#CachedModeFlags+1]
      |
        STRH    R2,[WP,#CachedModeFlags]
      ]


        MOV     R1,#VduExt_NColour
        SWI     XOS_ReadModeVariable    ;Attempt to read NColour
        MOVCS   R2,#0                   ;Is there much point handling errors here?
        ; These code snippets will produce nonsense results for YUV modes
      [ NoARMv5
        MOV     R1,#0
10
        MOVS    R2,R2,LSR #1
        ADDCS   R1,R1,#1
        BCS     %BT10
      |
        CLZ     R1,R2
        RSB     R1,R1,#32
      ]
        STRB    R1,[WP,#CachedL2NColour]
        
        Debug   xx,"Cache L2NColour",R1

        LDR     R0,[WP,#PaletteAt]
        STR     R0,[WP,#PaletteCopy]    ;Mark as source of palette for cached entries

        MOV     R0,#0                   ;Mark as palette not cached
        STR     R0,[WP,#PaletteCacheStart]

        LDRB    R0,[WP,#CacheEmpty]
        CMP     R0,#0                   ;Is the cache currently empty? (clears V!)
        Pull    "PC",EQ

        Debug   xx,"Clearing the cache workspace"

; Loop from end of cache through all entries stonking over them making them
; all clean and tidy

        LDR     R0,=(CacheEntries-1)*CacheEntrySize + CacheValid
        MOV     R1,#-1
50
        STRB    R1,[WP,R0]
        SUB     R0,R0,#CacheValid-CachedPatternValid
        STRB    R1,[WP,R0]
        SUBS    R0,R0,#CacheEntrySize+CachedPatternValid-CacheValid
        BPL     %BT50                   ;Loop back zonking the cache

        MOV     R0,#0
        STRB    R0,[WP,#CacheEmpty]     ;Mark as the cache is empty now

        MOV     R1,#Service_InvalidateCache
        SWI     XOS_ServiceCall         ;Broadcast ignoring errors that cache is now invalid

        Debug   xx,"Cache has been invalidated"

        CLRV
        Pull    "PC"

        LTORG

        GET     Commons.s
        GET     MainSWIs.s
        GET     Cache.s
        GET     FontColour.s

        GetIf   s.Dither, dither
        $GetConditionally

        GET     NewModels.s
        GET     Palettes.s
        GET     MsgCode.s

        GET     FileCal.s
        GET     Calibrate.s
        GET     DevicePal.s

        GetIf   s.DevicePal2, newcalibration
        $GetConditionally

        GET     Enhanced.s
        GET     Tables32K.s

      [ debug
        InsertNDRDebugRoutines
      ]

        END
