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
; > DrawMod.sources.Draw

;;---------------------------------------------------------------------------
;;
;; New Draw module
;;
;; *********************************
;; ***  CHANGE LIST AND HISTORY  ***
;; *********************************
;;
;; 12-Apr-88        DJS  File created
;; 13-Apr-88        DJS  Conditional assembly for use of DrawV
;; 14-Apr-88        DJS  Translations to ProcessPath calls completed
;; 15-Apr-88        DJS  Main ProcessPath skeleton set up
;; 18-Apr-88        DJS  DrawV works, output path, count output, flatten path
;; 21-Apr-88        DJS  Fill path skeleton written
;; 04-May-88        DJS  Fill path edge tracking working
;; 06-May-88        DJS  Fill operations not involving middle of edge working
;; 09-May-88        DJS  All fill operations and thin stroke working
;; 10-May-88  0.10  DJS  First release
;; 11-May-88        DJS  Path thickening without joins and caps working
;; 18-May-88        DJS  All caps working, round and bevelled joins working
;; 18-May-88  0.11  DJS  Second release
;; 19-May-88        DJS  Double precision arithmetic added to path thickening
;; 20-May-88        DJS  Double prec. arith. used in Bresenham calculation
;; 20-May-88        DJS  Excessively long edges split before filling, to
;;                         protect against overflow. Ditto for huge Beziers
;; 24-May-88        DJS  Mitred joins added, heap space returned on BREAK
;; 24-May-88        DJS  Shapes with O(1000) edges debugged
;; 25-May-88        DJS  Dashing added and debugged
;; 26-May-88        DJS  More debugging of dash patterns
;; 27-May-88        DJS  Added subpath by subpath fill, and "plot normally"/
;;                       "plot subpath by subpath" option to Draw_Stroke
;; 27-May-88        DJS  Added standard "unimplemented" message
;; 27-May-88  0.12  DJS  Third release
;; 29-May-88        DJS  Fixed zero mitre limit bug & zero length segment bug
;; 29-May-88        DJS  Added fast skipping past empty lines
;; 30-May-88  0.13  DJS  Fourth release
;; 31-May-88        DJS  Added transformation by a matrix & various speed-ups
;; 31-May-88        DJS  Added VDU system's bounding box update
;; 01-Jun-88        DJS  Fixed "plot -infinity to +infinity" bug (didn't plot
;;                         anything at all!)
;; 01-Jun-88        DJS  Stopped module trying to plot in non-graphics modes.
;; 01-Jun-88        DJS  Added triangular cap control and squashed caps and
;;                         joins code. Debugged results.
;; 01-Jun-88        DJS  Removed plotting of spurious null paths from "plot
;;                         subpath by subpath" code.
;; 01-Jun-88  0.14  DJS  Fifth release
;; 02-Jun-88        DJS  Simplified initialisation and finalisation
;; 02-Jun-88        DJS  Code compressions in fill routine
;; 03-Jun-88        DJS  Started adding speed-ups for simple fill styles, for
;;                         Y-clipping and for advancing near-horizontal edges
;; 03-Jun-88  0.15  DJS  Sixth release, for MOS 1.75 ROMs, no speed-ups, not
;;                         a "development version"
;; 06-Jun-88        DJS  Simple fill style speed-up completed
;; 07-Jun-88        DJS  Y-clipping speed-up done
;; 07-Jun-88  0.16  DJS  Seventh release, for MOS 1.76 ROMs, two modules
;;                         released (one with speed-ups), not a "development"
;;                         version
;; 30-Jun-88        DJS  Near horizontal edge speed-up done for simple fill
;;                         styles
;; 01-Jul-88        DJS  Near horizontal edge speed-up done for other fill
;;                         styles
;; 01-Jul-88  0.17  DJS  Eighth release, for MOS 1.80 ROMs, two modules
;;                         released (one with speed-ups), not a "development"
;;                         version
;; 20-Jul-88        DJS  Specification change: only the bottom byte of the
;;                         path element type is significant
;; 20-Jul-88  0.18  DJS  Ninth release, for MOS 1.82 ROMs, two modules
;;                         released (one with speed-ups), not a "development"
;;                         version
;; 30-Aug-88        DJS  Problem with some horizontal thin strokes vanishing
;;                         fixed
;; 01-Sep-88  1.00  DJS  Released for MOS 2.00 (?), two modules released (one
;;                         with speed-ups), not a "development" version
;; 09-Sep-88        DJS  Bug fixed: path continuation was ignored if it
;;                         pointed to either type of "move to" element
;; 09-Sep-88  1.01  DJS  Released for MOS 2.00 (?), two modules released (one
;;                         with speed-ups), not a "development" version
;; 13-Nov-89        DJS  SWI interface changed to allow plotting with
;;                         background colour (under control of an assembly
;;                         time switch)
;; 22-Nov-89  1.02  DJS  Source structure changed to fit in with source
;;                         release mechanism. Retro-fitted to version 1.01
;;                         to produce a source release.
;; 15-Mar-91  1.03  ECN  Internationalised
;;  7-Oct-91        DDV  Corrected location of header files to use 'hdr:'
;;  7-Oct-91        DDV  Bug fix: M00 now defined to say no draw calls in IRQ mode
;;  7-Oct-91        DDV  Bug fix: No such SWI message uses global token
;;  7-Oct-91  1.04  DDV  Bug fix; miter limit check ensures never -ve
;;  3-Mar-92  1.05  DDV  Bug fix: text for M00 tweeked slightly.
;; 30-Jul-92  1.06  TMD  Conditional out 26 bit limits on pointers
;; 21-Sep-98  1.10  KJB  Build changed to use LocalRes$Path and srccommit.
;; 05-Aug-99  1.11  KJB  Ursula branch merged (service call table).
;; 12-May-00  1.12  KJB  32-bit compatible.
;;
;;---------------------------------------------------------------------------

;----------------------------------------------------------------------------
;
; Set up addresses, get appropriate macro files
;
;----------------------------------------------------------------------------

                AREA    |DrawMod$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:CPU.Arch

        GET     VersionASM
        GET     Version

        GET     hdr:Macros
        GET     hdr:System
        GET     hdr:PublicWS
        GET     hdr:ModHand
        GET     hdr:Services
        GET     hdr:VduExt
        GET     hdr:FSNumbers
        GET     hdr:NewErrors
        GET     hdr:Debug
        GET     hdr:Draw
        GET     hdr:Proc
        GET     hdr:MsgTrans
        GET     Hdr:OSRSI6

;----------------------------------------------------------------------------
;
; A division macro, with a debugging switch to find divisions by zero
;
;----------------------------------------------------------------------------

                GBLL    checkdivides
checkdivides    SETL    {FALSE} :LAND: BeingDeveloped

        MACRO
$label  DivRem2 $rc, $ra, $rb, $rtemp, $norem
$label
        [       checkdivides
        TEQ     $rb,#0
        SWIEQ   OS_BreakPt
        ]
        DivRem  $rc, $ra, $rb, $rtemp, $norem
        MEND

;----------------------------------------------------------------------------
;
; Module header
;
;----------------------------------------------------------------------------

        ASSERT  . = Module_BaseAddr     ;Check macros haven't produced code
        DCD     0                               ;Not an application
        DCD     initialise - Module_BaseAddr    ;Initialisation
        DCD     finalise - Module_BaseAddr      ;Finalisation
        DCD     serviceentry - Module_BaseAddr  ;Claim Draw vector on resets
        DCD     title - Module_BaseAddr         ;Title string
        DCD     helpstr - Module_BaseAddr       ;Help string
        DCD     0                               ;No help/command table
        DCD     DrawSWI_Base                       ;SWI chunk
        DCD     mySWIhandler - Module_BaseAddr  ;SWI handler
        DCD     mySWInames - Module_BaseAddr    ;SWI names
        DCD     0                               ;No special SWI decoding
        DCD     0                               ;May not be necessary!
        [ :LNOT: No32bitCode
        DCD     modflags - Module_BaseAddr      ;flags
        ]

helpstr DCB     "Drawing Module",9,"$Module_HelpVersion"
        [       BeingDeveloped
        DCB     " Development version"
        ]
        DCB     0
        ALIGN

        [ :LNOT: No32bitCode
modflags DCD    1
        ]

;----------------------------------------------------------------------------
;
; Local macros and constants
;
;----------------------------------------------------------------------------

coord_shift             EQU     Draw_LgScalingFactor
pixelsize               EQU     1:SHL:coord_shift
halfpixelsize           EQU     pixelsize:SHR:1
subpixelmask            EQU     pixelsize - 1

  [ ClippedFills
fillstylemask           EQU     FillStyle_OverallMask :OR: f_buffer :OR: f_mask
  |
fillstylemask           EQU     FillStyle_OverallMask
  ]

windingrulemask         EQU     FillStyle_RuleMask
r_nonzero               EQU     FillStyle_NonZeroRule
r_negative              EQU     FillStyle_NegativeOnlyRule
r_evenodd               EQU     FillStyle_EvenOddRule
r_positive              EQU     FillStyle_PositiveOnlyRule

f_fullexterior          EQU     FillStyle_PlotFullExterior
f_exteriorbdry          EQU     FillStyle_PlotExteriorBoundary
f_interiorbdry          EQU     FillStyle_PlotInteriorBoundary
f_fullinterior          EQU     FillStyle_PlotFullInterior

; Internal flags
   [ ClippedFills
f_buffer                EQU     &40   ; we're buffering scanlines
f_mask                  EQU     &80   ; we're using the buffered lines
   ]
f_inside                EQU     &100

                        [       BackgroundAvail
usebackground           EQU     FillStyle_UseBackground
                        ]

flagsmask               EQU     ProcessPath_FlagsMask
f_r7isboundingbox       EQU     ProcessPath_R7IsBoundingBox
f_r7isthirtytwobit      EQU     ProcessPath_R7IsThirtyTwoBit
f_closeopensubpaths     EQU     ProcessPath_CloseOpenSubpaths
f_flatten               EQU     ProcessPath_Flatten
f_thicken               EQU     ProcessPath_Thicken
f_reflatten             EQU     ProcessPath_Reflatten
f_floatingpoint         EQU     ProcessPath_Float

; Arithmetic macros

 [ UseMULL
        ! 0, "Using SMULL - StrongARM or later only"
 ]

        MACRO
        SSmultD $ra,$rb,$rl,$rh
        ; Asserts to check requirements always meet both options
        ASSERT  $rh = $rl + 1
        ASSERT  $ra <= R8
        ASSERT  $rb <= R8
        ASSERT  $rl <= R7
 [ UseMULL
    [ $ra = $rl :LOR: $ra = $rh
        ! 0, "Register clash avoided in SSmultD"
        MOV     R14, $ra
        SMULL   $rl,$rh,R14,$rb
    |
        SMULL   $rl,$rh,$ra,$rb
    ]
 |
        BL      arith_SSmultD
        DCB     $ra,$rb,$rl,0
 ]
        MEND

; Macros for normal and error returns when return link is in R14

        MACRO
$label  Return  $cond
$label  MOV$cond PC,LR
        MEND

        MACRO
$label  NoErrorReturn
$label  CLRV
        Return
        MEND

        MACRO
$label  ErrorReturn
$label  SETV
        Return
        MEND

;----------------------------------------------------------------------------
;
; SWI handler and table
;
;----------------------------------------------------------------------------

mySWIhandler
        LDR     R12,[R12]       ;Point R12 at workspace
        CMP     R11,#NumberOfDrawReasons
        BHS     swioutofrange   ;Error for out of range SWI
        Push    "R1-R11,LR"     ;Preserve registers
        MOV     R8,R11          ;Draw reason code = SWI number in chunk
        MOV     R9,#DrawV       ;Call the Draw vector
        SWI     XOS_CallAVector
        Pull    "R1-R11,PC"     ;And return

title
mySWInames
        DCB     "Draw",0
        DCB     "ProcessPath",0
        DCB     "ProcessPathFP",0
        DCB     "Fill",0
        DCB     "FillFP",0
        DCB     "Stroke",0
        DCB     "StrokeFP",0
        DCB     "StrokePath",0
        DCB     "StrokePathFP",0
        DCB     "FlattenPath",0
        DCB     "FlattenPathFP",0
        DCB     "TransformPath",0
        DCB     "TransformPathFP",0
        DCB     "FillClipped",0
        DCB     "FillClippedFP",0
        DCB     "StrokeClipped",0
        DCB     "StrokeClippedFP",0
        DCB     0
        ALIGN

;----------------------------------------------------------------------------
;
; Workspace declarations
;
;----------------------------------------------------------------------------

                ^       0,R12
wsstart         #       0

; The input arguments

args            #       0               ;ProcessPath parameters
inputptr        #       4               ;Input path pointer
flags           #       4               ;Fill style and other flags
matrix          #       4               ;Transformation matrix pointer
flatness        #       4               ;Flatness
thickness       #       4               ;Line thickness
joinsandcaps    #       4               ;Line joins and caps pointer
dashptr         #       4               ;Dash pattern pointer
outputtype      #       4               ;Output pointer or special type
endargs         #       0

; The list of processing routines

routinelist     #       4*8             ;Maximum of eight routines for now
routinelistend  #       0

; Areas used by processpath to keep track of the current subpath

subpathstart    #       4*2             ;Where the current subpath starts
subpathtype     #       4               ;The type of the current subpath

; Modified flatness limit (default applied, multiplied by 4 for simpler
; comparisons).

flatlimit       #       4

; The transformed point cache

beforetransform #       4*2
aftertransform  #       4*2

; Areas used to keep track of joins and caps

joincapstate    #       4               ;Flags indicating state of joins
                                        ;  and caps algorithm
initialvertex   #       4*2             ;Initial vertex of subpath
initialoffset   #       4*2             ;Initial offset vertex of subpath
finaloffset     #       4*2             ;Final offset vertex of subpath
circlecontrol   #       4               ;Precalculated circle control point
currentoffset   #       4*2             ;Offset currently being used

; Areas used to keep track of the dash pattern

dashstate       #       4               ;Either gaptoET or linetoET
dashindex       #       4               ;Current index into dash pattern
dashdistance    #       4               ;Distance left for current dash/gap

; What a winding number of 1 in user space translates into in standard
; space. Normally 1, but -1 if a negative determinant matrix is used!

userspacewinding #      4

; Areas used by out_fill and out_subpaths. "workspacehead" and "extrachunk"
; have permanently valid values, as the code to return heap space on BREAK
; uses them. Others are only valid at appropriate points within out_fill and
; out_subpaths.

fillstyle       #       4               ;Modified fill style
workspacehead   #       4               ;Head of list of allocated workspace
extrachunk      #       4               ;Possible extra workspace chunk
currentwinding  #       4               ;Winding number of current subpath
edgecount       #       4               ;How many edges there are
currentchunk    #       4               ;Pointer to current workspace chunk
pointers        #       4               ;Start of pointers table
endwaiting      #       4               ;End of pointers to lines waiting for
                                        ;  activation
startactive     #       4               ;Start of pointers to active lines
endpointers     #       4               ;End of pointers table
fivewordlist    #       4               ;Start of list of free 5 word areas
outptrandcnt    #       4*2             ;Save area for outptr and outcnt

; This module's bounding box area and address of the OS's ChangedBox

boundingbox     #       4*4
changedboxaddr  #       4

; Area for out_subpaths to keep track of whether there is a current subpath

gotasubpath     #       4

; Area to read VDU variables into

vduvars         #       0
lcol            #       4               ;All sides of graphics window (pixels)
brow            #       4
rcol            #       4
trow            #       4
orgx            #       4               ;Graphics origin, OS units
orgy            #       4
xfactor         #       4               ;Log base 2 of OS unit to pixel
yfactor         #       4               ;  conversion factors
hline           #       4
modeflags       #       4
endvduvars      #       0

  [ ClippedFills
clippointers     #       4
clippointerssize #       4
clipagainst      #       4
clipsize         #       4
clipused         #       4
clipcount        #       4
  ]

; Pointer to kernel's IRQsema

ptr_IRQsema      #       4

; Area for messagetrans stuff

MessageFile_Block # 16
MessageFile_Open  # 4

; End of workspace

wsend           #       0
wslength        EQU     wsend-wsstart

;----------------------------------------------------------------------------
;
; Initialisation and finalisation
;
;----------------------------------------------------------------------------

initialise
        Push    "LR"
        LDR     R2,[R12]        ;On re-initialisation, only claim vector
        CMP     R2,#0           ;NB clears V
        BNE     claimvector
;
; Claim workspace
;
        MOV     R0,#ModHandReason_Claim
        LDR     R3,=wslength
        SWI     XOS_Module
        STRVC   R2,[R12]
        MOVVC   R0,#0                   ;Initialise workspace pointers
        STRVC   R0,[R2,#:INDEX:workspacehead]
        STRVC   R0,[R2,#:INDEX:extrachunk]
  [ ClippedFills
        STRVC   R0,[R2,#:INDEX:clipagainst]
        STRVC   R0,[R2,#:INDEX:clipsize]
        STRVC   R0,[R2,#:INDEX:clipused]
        STRVC   R0,[R2,#:INDEX:clippointers]
        STRVC   R0,[R2,#:INDEX:clippointerssize]
  ]
        BVS     claimvector
        MOV     R12, R2
        MOV     R0, #6
        MOV     R1, #0
        MOV     R2, #OSRSI6_IRQsema
        SWI     XOS_ReadSysInfo
        MOVVS   R2, #0
        CMP     R2, #0
        MOVEQ   R2, #Legacy_IRQsema
        STR     R2, ptr_IRQsema
        MOV     R2, R12
;
; Claim DrawV vector - note R2 already set up
;
claimvector
        MOVVC   R0,#DrawV
        ADRVCL  R1,defaultroutine
        SWIVC   XOS_Claim
;
; Reset message file open flag so any error will try open it
;
        MOV     r1, #0
        STR     r1, [r2, #:INDEX:MessageFile_Open]
;
; Initialisation has now been done
;
        Pull    "PC"

finalise
;
; This tries to finalise the module, in reverse order to the initialisation.
; Development versions complain if an error occurs, others keep quiet!
;
        Push    "LR"
        LDR     r12, [r12]
;
; Release DrawV vector - note we must do this on ALL finalisations
;
        MOV     R0,#DrawV
        ADRL    R1,defaultroutine
        MOV     R2, R12
        SWI     XOS_Release
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile

        [       BeingDeveloped
        Pull    "PC",VC
        SWI     OS_WriteS
        DCB     "Disaster during Draw finalisation - error is:",13,10,0
        ALIGN
        ADD     R0,R0,#4
        SWI     OS_Write0
        SWI     OS_NewLine
        ]

        CLRV
        Pull    "PC"

;----------------------------------------------------------------------------
;
; The service entry
;
;----------------------------------------------------------------------------

;Ursula format
;
UServTab
        DCD     0
        DCD     UService - Module_BaseAddr
        DCD     Service_Reset
        DCD     0
        DCD     UServTab - Module_BaseAddr
serviceentry
        MOV     r0,r0
        TEQ     R1,#Service_Reset       ;If not reset, return
        MOVNE   PC,LR
UService
        LDR     R12,[R12]
        Push    "R0-R2,LR"
        BL      freeworkspace           ;Free any temporary workspace that
                                        ;  happened to be allocated at the
                                        ;  time of the reset
        MOV     R0,#DrawV               ;Claim Draw vector
        ADRL    R1,defaultroutine
        MOV     R2,R12
        SWI     XOS_Claim
        Pull    "R0-R2,PC"

; Subroutine to free all temporary workspace claimed by the module.
; Corrupts R0,R1,R2; uses normal error conventions.

freeworkspace
        Push    "LR"
        MOV     R0,#ModHandReason_Free
        LDR     R2,extrachunk           ;Does extra workspace chunk exist?
        CMP     R2,#0                   ;(Note V cleared by this)
        SWINE   XOS_Module              ;Free it if so
        Pull    "PC",VS                 ;Pass back errors
        MOV     R2,#0                   ;Signal this chunk no longer claimed
        STR     R2,extrachunk
        LDR     R1,workspacehead        ;Point at first workspace chunk
freeworkspace_loop                      ;(Note V clear at this point)
        STR     R1,workspacehead        ;Record where we've got to
        MOVS    R2,R1                   ;Does current workspace chunk exist?
        Pull    "PC",EQ                 ;Finished if not
        LDR     R1,[R1]                 ;Point at next workspace chunk
        SWI     XOS_Module              ;Free this workspace chunk
        BVC     freeworkspace_loop      ;Loop provided no error occurred
        Pull    "PC"                    ;Pass back errors

;----------------------------------------------------------------------------
;
; The default drawing routine
;   Note this always claims the call, so no need to keep LR
;
;----------------------------------------------------------------------------

defaultroutine
        CMP             R8,#NumberOfDrawReasons
        ADDLO           PC,PC,R8,LSL #2
        B               reasonoutofrange        ;Out of range
mainbranchtable
        B               processpath     ;Draw_ProcessPath
        B               unimplemented   ;Draw_ProcessPathFP
        B               fill            ;Draw_Fill
        B               fill            ;Draw_FillFP
        B               stroke          ;Draw_Stroke
        B               stroke          ;Draw_StrokeFP
        B               strokepath      ;Draw_StrokePath
        B               strokepath      ;Draw_StrokePathFP
        B               flattenpath     ;Draw_FlattenPath
        B               flattenpath     ;Draw_FlattenPathFP
        B               transformpath   ;Draw_TransformPath
        B               transformpath   ;Draw_TransformPathFP
    [ ClippedFills
        B               fillclipped     ;Draw_FillClipped
        B               fillclipped     ;Draw_FillClippedFP
        B               strokeclipped   ;Draw_StrokeClipped
        B               strokeclipped   ;Draw_StrokeClippedFP
    |
        B               fill            ;Draw_FillClipped
        B               fill            ;Draw_FillClippedFP
        B               stroke          ;Draw_StrokeClipped
        B               stroke          ;Draw_StrokeClippedFP
    ]
        ASSERT          .-mainbranchtable = 4*NumberOfDrawReasons

;----------------------------------------------------------------------------
;
; The default fill routine
;   This modifies the call to an appropriate call to ProcessPath or
; ProcessPathFP. The same routine suffices for both fixed and floating
; point versions.
;
;----------------------------------------------------------------------------

fill
        [       BackgroundAvail
        TST     R1,#fillstylemask       ;Produce default fill style
        ORREQ   R1,R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask+usebackground
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        |
        TEQ     R1,#0                   ;Produce default fill style
        MOVEQ   R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask   ;Error if reserved bits non-zero
        BNE     reservedbitsnotzero
        ]
        ORR     R1,R1,#f_closeopensubpaths+f_flatten    ;Convert to fixed
                                        ;  point, don't thicken or re-flatten
        MOV     R6,#0                   ;Don't apply a dash pattern
        MOV     R7,#DrawSpec_Fill
        B       changetoprocesspath


    [ ClippedFills
;----------------------------------------------------------------------------
;
; Fill routine, using a clipping path
;   This modifies the call to an appropriate call to ProcessPath or
; ProcessPathFP. The same routine suffices for both fixed and floating
; point versions.
;
;----------------------------------------------------------------------------

; => R0-> path to plot
;    R1 = fill style for path to plot
;    R2-> transformation matrix for path to plot
;    R3 = flatness
;    R4-> clip description block
;          +0-> path to clip against
;          +4 = fill style for path
;          +8-> transformation matrix
fillclipped

        [       BackgroundAvail
        TST     R1,#fillstylemask       ;Produce default fill style
        ORREQ   R1,R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask+usebackground
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        LDR     r14,[r4,#4]
        TST     R14,#fillstylemask       ;Produce default fill style
        ORREQ   R14,R14,#f_fullinterior+f_interiorbdry
        BICS    R14,R14,#fillstylemask+usebackground
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        |
        TEQ     R1,#0                   ;Produce default fill style
        MOVEQ   R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask   ;Error if reserved bits non-zero
        BNE     reservedbitsnotzero
        LDR     r14,[r4,#4]
        TEQ     R14,#0                   ;Produce default fill style
        MOVEQ   R14,#f_fullinterior+f_interiorbdry
        BICS    R14,R14,#fillstylemask   ;Error if reserved bits non-zero
        BNE     reservedbitsnotzero
        ]

        Push    "r0-r3"

  ; put us into the 'clipping' path stage
        LDMIA   r4,{r0,r1,r2}
        [       BackgroundAvail
        TST     R1,#fillstylemask       ;Produce default fill style
        ORREQ   R1,R1,#f_fullinterior+f_interiorbdry
        |
        TEQ     R1,#0                   ;Produce default fill style
        MOVEQ   R1,#f_fullinterior+f_interiorbdry
        ]
     ; flatness remains the same

        MOV     r14,#0
        STR     r14,clipused
        STR     r14,clipcount

  ; now generate the clip path
        ORR     R1,R1,#f_closeopensubpaths+f_flatten    ;Convert to fixed
                                        ;  point, don't thicken or re-flatten
        ORR     r1,r1,#f_buffer
        MOV     R6,#0                   ;Don't apply a dash pattern
        MOV     R7,#DrawSpec_Fill
        BL      changetoprocesspath_andreturn

  ; then sort the buffer that we've been given
        BL      clipped_sort
        BVS     %FT99

  ; put us into the 'clipping' path stage
        LDMIA   sp,{r0-r3}   ; this may not tally with Push...

  ; do the masked plotting (ick,ick,ick!)
        ORR     R1,R1,#f_closeopensubpaths+f_flatten    ;Convert to fixed
                                        ;  point, don't thicken or re-flatten
        ORR     r1,r1,#f_mask
        MOV     R6,#0                   ;Don't apply a dash pattern
        MOV     R7,#DrawSpec_Fill
        BL      changetoprocesspath_andreturn
99
        Pull    "r0-r3,pc"

; sort the clipping scanline buffer so that we have high y's at the top
clipped_sort
        Push    "lr"
        LDR     r0,clipcount
        ADD     r3,r3,r0,LSL #1 ; count * 3
        LDR     r1,clippointerssize
        CMP     r1,r3,LSL #2
        BGE     %FT20
  ; we need to allocate/reallocate our pointers array
        LDR     r2,clippointers
        TEQ     r2,#0
        MOVEQ   r0,#ModHandReason_Claim
        MOVNE   r0,#ModHandReason_ExtendBlock
        MOV     r3,r3,LSL #2
        SWI     XOS_Module
        BVS     %FT99 ; ick, failed to allocate
        STR     r2,clippointers
        STR     r3,clippointerssize
20
        LDR     r0,clipcount
        LDR     r1,clippointers
        ADR     r2,clip_sorter
        MOV     r3,#0
        LDR     r4,clipagainst
        MOV     r5,#3*4
        MOV     r6,#0
        TST     r1,#7<<29
        BNE     %FT40
        ORR     r1,r1,#(1<<30) :OR: (1<<31)
        SWI     XOS_HeapSort
        B       %FT80

40      MOV     r7,#(1<<30) :OR: (1<<31)
        SWI     XOS_HeapSort32
80
        LDR     r4,clipagainst

99
        Pull    "pc"

;----------------------------------------------------------------------------
;
; Stroke routine, using a clipping path
;   This modifies the call to an appropriate call to ProcessPath or
; ProcessPathFP. The same routine suffices for both fixed and floating
; point versions.
;
;----------------------------------------------------------------------------

; => R0-> path to plot
;    R1 = fill style for path to plot
;    R2-> transformation matrix for path to plot
;    R3 = flatness
;    R4 = thickness
;    R5-> join/cap block
;    R6-> dashing pattern
;    R7-> clip description block
;          +0-> path to clip against
;          +4 = fill style for path
;          +8-> transformation matrix
strokeclipped

        Push    "r0-r6"

  ; put us into the 'clipping' path stage
        LDMIA   r7,{r0,r1,r2}
        [       BackgroundAvail
        TST     R1,#fillstylemask       ;Produce default fill style
        ORREQ   R1,R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask+usebackground
        Pull    "r0-r6",NE
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        |
        TEQ     R1,#0                   ;Produce default fill style
        MOVEQ   R1,#f_fullinterior+f_interiorbdry
        BICS    R14,R1,#fillstylemask   ;Error if reserved bits non-zero
        Pull    "r0-r6",NE
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        ]
  ; flatness remains the same

        MOV     r14,#0
        STR     r14,clipused
        STR     r14,clipcount

  ; now generate the clip path
        ORR     R1,R1,#f_closeopensubpaths+f_flatten    ;Convert to fixed
                                        ;  point, don't thicken or re-flatten
        ORR     r1,r1,#f_buffer
        MOV     R6,#0                   ;Don't apply a dash pattern
        MOV     R7,#DrawSpec_Fill
        BL      changetoprocesspath_andreturn

  ; then sort the buffer that we've been given
        BL      clipped_sort
        Pull    "r0-r6"

        Pull    "pc",VS ; if it failed to sort

  ; we return you to your normal stroking code...
        AND     R7,R8,#1        ;Zero width? Yes if R4 = 0 (fixed point) or
        MOVS    R7,R4,LSL R7    ;  if R4 = +/- 0 (floating point)
        MOV     R9,#f_flatten + f_thicken       ;Always flatten and thicken
        ORRNE   R9,R9,#f_reflatten              ;Only reflatten if wide
        MOVEQ   R14,#f_interiorbdry+f_exteriorbdry
                                ;Default fill style if zero width
        MOVNE   R14,#f_fullinterior+f_interiorbdry
                                ;Default fill style if non-zero width
        TEQ     R1,#0           ;Set up correct fill routine
        MOVPL   R7,#DrawSpec_FillBySubpaths
        MOVMI   R7,#DrawSpec_Fill
        [       BackgroundAvail
        BIC     R1,R1,#&80000000
        TST     R1,#fillstylemask
        ORREQ   R1,R1,R14       ;Change to default fill style if wanted
        BICS    R14,R1,#fillstylemask+usebackground
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        |
        BICS    R1,R1,#&80000000
        MOVEQ   R1,R14          ;Change to default fill style if wanted
        BICS    R14,R1,#fillstylemask   ;Error if reserved bits non-zero
        BNE     reservedbitsnotzero
        ]
        ORR     R1,R1,R9        ;Tell ProcessPath what to do
        ORR     r1,r1,#f_mask
        B       changetoprocesspath

; sort the clipping blocks by their y coordinates
clip_sorter
        LDR     r2,[r0,#4] ; read y0
        LDR     r3,[r1,#4] ; read y1
        CMP     r1,r0
        MOVNE   pc,lr      ; ascending order
        LDR     r2,[r0,#0] ; read x0
        LDR     r3,[r1,#0] ; read x1
        CMP     r1,r0
        MOV     pc,lr      ; and the left side, too
    ]

;----------------------------------------------------------------------------
;
; The default stroke routine
 ;   Translate into an appropriate call to ProcessPath or ProcessPathFP. With
; a little bit of manipulation for generating default fill styles, the same
; routine suffices for fixed or floating point.
;
;----------------------------------------------------------------------------

stroke
        AND     R7,R8,#1        ;Zero width? Yes if R4 = 0 (fixed point) or
        MOVS    R7,R4,LSL R7    ;  if R4 = +/- 0 (floating point)
        MOV     R9,#f_flatten + f_thicken       ;Always flatten and thicken
        ORRNE   R9,R9,#f_reflatten              ;Only reflatten if wide
        MOVEQ   R14,#f_interiorbdry+f_exteriorbdry
                                ;Default fill style if zero width
        MOVNE   R14,#f_fullinterior+f_interiorbdry
                                ;Default fill style if non-zero width
        TEQ     R1,#0           ;Set up correct fill routine
        MOVPL   R7,#DrawSpec_FillBySubpaths
        MOVMI   R7,#DrawSpec_Fill
        [       BackgroundAvail
        BIC     R1,R1,#&80000000
        TST     R1,#fillstylemask
        ORREQ   R1,R1,R14       ;Change to default fill style if wanted
        BICS    R14,R1,#fillstylemask+usebackground
        BNE     reservedbitsnotzero     ;Error if reserved bits non-zero
        |
        BICS    R1,R1,#&80000000
        MOVEQ   R1,R14          ;Change to default fill style if wanted
        BICS    R14,R1,#fillstylemask   ;Error if reserved bits non-zero
        BNE     reservedbitsnotzero
        ]
        ORR     R1,R1,R9        ;Tell ProcessPath what to do
        B       changetoprocesspath

;----------------------------------------------------------------------------
;
; The default strokepath routine
;   Translate into an appropriate call to ProcessPath or ProcessPathFP. As
; above, the same routine suffices for fixed or floating point.
;
;----------------------------------------------------------------------------

strokepath
        TST     R1,#3                   ;Error if path pointer is out of
        BNE     invalidpointer          ;  range or not word-aligned
        MOVS    R7,R1                   ;Output to the given buffer
        MOVEQ   R7,#DrawSpec_Count      ;  or count buffer size, as requested
        AND     R1,R8,#1                ;Zero width? Yes if R4 = 0 (fixed)
        MOVS    R1,R4,LSL R1            ;  or if R4 = +/- 0 (floating)
        MOV     R1,#f_flatten + f_thicken       ;Always flatten and thicken
        ORRNE   R1,R1,#f_reflatten              ;Only reflatten if wide
        B       changetoprocesspath

;----------------------------------------------------------------------------
;
; The default flattenpath routine
;   Translate into an appropriate call to ProcessPath or ProcessPathFP. As
; above, the same routine suffices for fixed or floating point.
;
;----------------------------------------------------------------------------

flattenpath
        TST     R1,#3                   ;Error if path pointer is out of
        BNE     invalidpointer          ;  range or not word-aligned
        MOVS    R7,R1                   ;Output to the given buffer
        MOVEQ   R7,#DrawSpec_Count      ;  or count buffer size, as requested
        MOV     R3,R2                   ;Put flatness in correct register
        MOV     R1,#f_flatten           ;Flatten the path
        TST     R8,#1                   ;Floating point version?
        ORRNE   R1,R1,#f_floatingpoint  ;If so, output is also floating point
        MOV     R2,#0                   ;No transformation
        MOV     R6,#0                   ;No dashing
        B       changetoprocesspath

;----------------------------------------------------------------------------
;
; The default transformpath routine
;   Translate into an appropriate call to ProcessPath or ProcessPathFP. As
; above, the same routine suffices for fixed or floating point.
;
;----------------------------------------------------------------------------

transformpath
        TST     R1,#3                   ;Error if path pointer is out of
        BNE     invalidpointer          ;  range or not word-aligned
        MOV     R7,R1                   ;Output to given path or in situ
        BICS    R14,R3,#f_floatingpoint ;Error if reserved bits set
        BNE     reservedbitsnotzero
        MOV     R1,R3                   ;Flags clear except maybe floatingp.
        MOV     R6,#0                   ;No dashing
        B       changetoprocesspath

;----------------------------------------------------------------------------
;
; Code to change the call to ProcessPath or ProcessPathFP, then put it
; through the vector again, then exit
;
;----------------------------------------------------------------------------

changetoprocesspath
        AND     R8,R8,#1        ;Reduce reason code to ProcessPath(FP)
        ASSERT  DrawReas_ProcessPath = 0
        ASSERT  DrawReas_ProcessPathFP = 1
        MOV     R9,#DrawV       ;Call the Draw vector
        SWI     XOS_CallAVector
        Pull    "PC"

changetoprocesspath_andreturn
        Push    "lr"
        AND     R8,R8,#1        ;Reduce reason code to ProcessPath(FP)
        ASSERT  DrawReas_ProcessPath = 0
        ASSERT  DrawReas_ProcessPathFP = 1
        MOV     R9,#DrawV       ;Call the Draw vector
        SWI     XOS_CallAVector
        Pull    "PC"

;----------------------------------------------------------------------------
;
; The default ProcessPath routine
;   This routine works by producing a list of routines, each of which accepts
; a path element, processes it in some way (which may include expanding it
; into more than one path element) and (unless it is the last routine in the
; list) passes the results on to the next routine. This results in a
; tree-wise expansion of the path, with only the last routine in the list
; using significant quantities of workspace. This last routine is called the
; output routine.
;
; The interface to the processing routines is as follows:
;
; On entry:  R8 contains a path element type (endpathET-linetoET, as defined
;              below). Path element type continueET will never occur
;              naturally (as it is filtered out at the top level) and is used
;              as a "start of path" signal, to get the routines to initialise
;              themselves.
;            R0,R1 contain the X,Y co-ordinates of the current point, when
;              this is significant (i.e. only if there is a current subpath).
;            R2-R7 hold further details of the path element, as follows:
;              R8=endpathET or startpathET:
;                R2-R7 undefined.
;              R8=movetoET, specialmovetoET, gaptoET or linetoET:
;                R2-R5 undefined; R6,R7 hold X,Y co-ordinates of the final
;                point.
;              R8=closewithgapET or closewithlineET:
;                R2-R5 undefined; R6,R7 hold X,Y co-ordinates of start of
;                subpath.
;              R8=beziertoET:
;                R2,R3 hold X,Y co-ordinates of first control point; R4,R5
;                those of second control point; R6,R7 those of final point.
;            R9 is output routine's output pointer.
;            R10 is output routine's output count.
;            R11 points to list of addresses of the rest of the path
;              modification/disposal routines.
;            Area of memory at 'args' holds the original parameters to
;              Draw_ProcessPath.
;
; On exit:   R0,R1 are updated, usually to contain the new current point's
;              co-ordinates, but to contain the returned value in the case
;              of R8=endpathET on entry.
;            R2-R8 are corrupt.
;            R9,R10 are updated as necessary.
;            R11 is preserved.
;            If error occurred: V set and R0 points to error block as
;              usual. R1-R10 corrupt.
;
;
;----------------------------------------------------------------------------

; The path element types

endpathET       EQU     0
continueET      EQU     1
startpathET     EQU     continueET      ;as this is also used to signal new
                                        ;  path is starting - see above
movetoET        EQU     2
specialmovetoET EQU     3
closewithgapET  EQU     4
closewithlineET EQU     5
beziertoET      EQU     6
gaptoET         EQU     7
linetoET        EQU     8

; Register names

oldX            RN      R0
oldY            RN      R1
cont1X          RN      R2
cont1Y          RN      R3
cont2X          RN      R4
cont2Y          RN      R5
t1              RN      cont1X  ;cont1X-cont2Y only needed for Bezier
t2              RN      cont1Y  ;  curves, so we have these registers
t3              RN      cont2X  ;  as scratch registers in other cases
t4              RN      cont2Y
newX            RN      R6
newY            RN      R7
t5              RN      newX    ;These registers are also free for
t6              RN      newY    ;  startpathET and endpathET elements
type            RN      R8
outptr          RN      R9
outcnt          RN      R10
nextrtnptr      RN      R11

; Macro to call the next routine. Corrupts R14. Preserves nextrtnptr
; unless requested not to.

        MACRO
$label  CallNextRoutine $forgetnextrtnptr
$label  MOV             LR,PC
        LDR             PC,[nextrtnptr],#4
        [               "$forgetnextrtnptr" = ""
        SUB             nextrtnptr,nextrtnptr,#4
        ]
        MEND

; The default ProcessPath routine itself

processpath
        WritePSRc SVC_mode,R14  ;Re-enable interrupts - this may take some
                                ;  time

; Must not be run from IRQ mode (as ScratchSpace may be used, and quite
; probably for other reasons as well!)

        LDR     R14,ptr_IRQsema
        LDR     R14,[R14]
        CMP     R14,#0
        BNE     notinirqmode

; Store the input arguments

        ADR     R14,args
        STMIA   R14,{R0-R7}
        ASSERT  endargs-args = 4*8

; Check for some obvious errors

        [       BackgroundAvail
        BIC     R14,R1,#fillstylemask+usebackground
        BICS    R14,R14,#flagsmask     ;Error if reserved bits set in R1
        BNE     reservedbitsnotzero    ;  (NB one instruction not possible)
        |
        BIC     R14,R1,#fillstylemask
        BICS    R14,R14,#flagsmask     ;Error if reserved bits set in R1
        BNE     reservedbitsnotzero    ;  (NB one instruction not possible)
        ]
        TST     R0,#AddressMask        ;Error if bad input path pointer
        TSTEQ   R2,#AddressMask        ;  or bad matrix pointer
        TSTEQ   R6,#AddressMask        ;  or bad dash pattern pointer
        BNE     invalidpointer

; Next step is to produce the list of routines. This is done in reverse
; order to the order in which they will be called.

        ADR     nextrtnptr,routinelistend       ;Point at end of list

; Set up the output routine. This is a bit complicated!

        TST     R1, #f_r7isthirtytwobit ;Find where to look for the bbox flag
        BEQ     %FT10                   ;  flag is stashed in R7
        TST     R1, #f_r7isboundingbox
        BNE     outputboundingbox       ;R7->bbox
        B       %FT15
10
        TST     R1, #f_r7isboundingbox  ;Naughty
        BNE     reservedbitsnotzero
        MOVS    R7, R7                  ;Top bit of R7 decides what to do
        BICMI   R7, R7, #&80000000
        BMI     outputboundingbox       ;R7 AND &7FFFFFFF->bbox
15
        CMP     R7,#NumberOfSpecialDraws
        ADDCC   PC,PC,R7,LSL #2         ;Otherwise branch to correct routine
        B       outputistopath          ;R7->path
        B       outputinsitu            ;DrawSpec_InSitu
        B       outputbyfilling         ;DrawSpec_Fill
        B       outputbyfilling         ;DrawSpec_FillBySubpaths
        B       outputlengthofpath      ;DrawSpec_Count

outputinsitu
        TST     R1,#f_thicken           ;Thickening with non-zero width
        TEQNE   R4,#0                   ;  will (probably) expand path
        TSTEQ   R1,#f_closeopensubpaths + f_flatten + f_reflatten
                                        ;So will all of these
        TEQEQ   R6,#0                   ;So will dashing
        ADRNE   R0,ErrorBlock_MayExpandPath
        BNE     errorandpullpc          ;Error if length likely to increase
        ADRL    R14,out_replace
        B       outputroutineknown

outputlengthofpath
        ADRL    R14,out_count
        B       outputroutineknown

outputboundingbox
        TST     R7,#AddressMask         ;Check for invalid pointer
        BNE     invalidpointer
        ADRL    R14,out_box             ;Get offset to "output bounding box"
        B       outputroutineknown      ;  routine and branch to common code

outputistopath
        TST     R7,#AddressMask         ;Check for invalid path pointer
        BNE     invalidpointer
        ADRL    R14,out_path            ;Get offset to "output path" routine
        B       outputroutineknown

outputbyfilling
        MOV     R0,#-1
        SWI     XOS_ChangedBox
        Pull    "PC",VS
        STR     R1,changedboxaddr
        TST     R0,#1
        BLNE    initbox
        TEQ     R7,#DrawSpec_Fill,0     ;EQ if normal fill, NE if by subpaths
        ADREQL  R14,out_fill
        ADRNEL  R14,out_subpaths
        STR     R14,[nextrtnptr,#-4]!
        ADR     R0,vduvarsspec
        ADR     R1,vduvars
        SWI     XOS_ReadVduVariables
        SWIVC   XOS_RemoveCursors
        Pull    "PC",VS
        LDR     R14,modeflags
        TST     R14,#1
        BNE     restorenotagraphicsmode
        LDR     R1,flags
        ADRL    R14,process_longedgeprotect

outputroutineknown
        STR     R14,[nextrtnptr,#-4]!   ;  and add it to list

; Set up the float routine, if required

        TST     R1,#f_floatingpoint
        ADRNEL  R14,process_float
        STRNE   R14,[nextrtnptr,#-4]!

; Set up the transformation by a matrix, if required

        TEQ     R2,#0
        ADRNEL  R14,process_transform
        STRNE   R14,[nextrtnptr,#-4]!

; Set up the re-flattening routine, if required

        TST     R1,#f_reflatten
        ADRNEL  R14,process_flatten
        STRNE   R14,[nextrtnptr,#-4]!

; Set up the correct thickening routine, if required
        TST     R1,#f_thicken
        BEQ     dontthicken
        TEQ     R4,#0
        ADREQL  R14,process_zerothicken
        ADRNEL  R14,process_thicken
        TSTNE   R5,#AddressMask         ;Error if bad joins and caps pointer,
        BNE     restoreinvalidpointer   ;  but only if width is non-zero
        STR     R14,[nextrtnptr,#-4]!
dontthicken

; Set up the dash pattern, if required

        TEQ     R6,#0
        ADRNEL  R14,process_dash
        STRNE   R14,[nextrtnptr,#-4]!

; Set up the flattening routine, if required

        TST     R1,#f_flatten
        ADRNEL  R14,process_flatten
        STRNE   R14,[nextrtnptr,#-4]!

; By default, user space winding numbers equal standard space winding
; numbers. This will be changed by process_transform when it initialises
; if it discovers that the given matrix has negative determinant.

        MOV     R14,#1
        STR     R14,userspacewinding

; The routine list is now complete. Next job is to send a startpathET element
; down the list to initialise all the routines. When we've done that, we
; should despatch each path element in turn down the list, except for those
; of type continueET (which should be dealt with here).
;
; During the course of this, we also:
;   (a) keep track of the start and type of the current subpath, and fill
;       in the subpath start for close path operations. We use endpathET
;       to indicate there is no current subpath during this process.
;   (b) check for and deal with bad path elements and sequencing errors.
;   (c) pass errors from the list of routines back to our caller.
;
; Note we mostly rely on the routines in the list to keep the registers oldX,
; oldY, outptr, outcnt and nextrtnptr up to date.

; Set up start of path element, then drop through to code to ensure there
; is no current subpath.

        MOV     type,#startpathET
nocurrentsubpath

; Set current subpath type to endpathET to indicate no current subpath. Then
; pass current element down list of routines.

        MOV     R14,#endpathET
        STR     R14,subpathtype
        CallNextRoutine         ;Pass down list of routines
        BVS     passuperror     ;Pass errors back to caller
mainprocessingloop

; Get an input element, then:
;   If out of range, generate error.
;   If beziertoET, gaptoET or linetoET, pick up rest of element, check
;     sequencing and pass down list of routines.
;   If another type, branch to appropriate handler.

        LDR     R14,inputptr    ;Get input path pointer
trynewelement
        LDRB    type,[R14],#4
        CMP     type,#linetoET+1
        ADDLO   PC,PC,type,LSL #2
        B       restorebadpath  ;Out of range - error
        B       pathfinished    ;endpathET - pass down, then stop
        B       changeaddress   ;continueET - new address and retry
        B       startsubpath    ;movetoET - start new subpath
        B       startsubpath    ;specialmovetoET - start new subpath
        B       endsubpath      ;closewithgapET - close old subpath
        B       endsubpath      ;closewithlineET - close old subpath
        LDMIA   R14!,{cont1X,cont1Y,cont2X,cont2Y}
                                ;beziertoET - get control points
        NOP                     ;beziertoET, gaptoET, linetoET - get endpoint
        LDMIA   R14!,{newX,newY}
        STR     R14,inputptr    ;Preserve input path pointer
        LDR     R14,subpathtype ;Check there is a current subpath
        TEQ     R14,#endpathET  ;Error if not
        BEQ     restoresequencing
passdownelement
        CallNextRoutine         ;Send element down list of routines
        BVC     mainprocessingloop
passuperror
        BL      restorecursors
        Pull    "PC"            ;Pass errors back to caller

; If endpathET, tell list of routines about this and pass back any
; results or errors to caller, after possibly closing an open subpath.

pathfinished
        BL      closeopensubpath
        BVS     passuperror
        MOV     type,#endpathET ;Regenerate original endpathET element
        CallNextRoutine ForgetR11
        BL      restorecursors
        Pull    "PC"

; If continueET, get address of new chunk of path and re-enter loop.

changeaddress
        LDMIA   R14,{R14}
        STR     R14,inputptr
        B       trynewelement

; If movetoET or specialmovetoET, start new subpath. We may first have to
; close an open subpath - but note that only subpaths started with
; "movetoET" are ever considered to be open. Ones started with
; "specialmovetoET" can be thought of as being closed double paths that
; affect boundary decisions but not winding numbers.

startsubpath
        BL      closeopensubpath
        BVS     passuperror
        LDR     R14,inputptr            ;Recover original element
        LDRB    type,[R14],#4
        LDMIA   R14!,{newX,newY}
        STR     R14,inputptr            ;Preserve input path pointer
        ADR     R14,subpathstart
        STMIA   R14,{newX,newY,type}    ;Record new subpath's start & type
        ASSERT  type > newX
        ASSERT  type > newY
        ASSERT  subpathtype = subpathstart+8
        B       passdownelement

; If closewithgapET or closewithlineET, pick up start of subpath, then
; go into no current subpath state

endsubpath
        STR     R14,inputptr            ;Preserve input path pointer
        ADR     R14,subpathstart
        LDMIA   R14,{newX,newY,R14}
        ASSERT  subpathtype = subpathstart+8
        TEQ     R14,#endpathET          ;Seq. error if no current subpath
        BNE     nocurrentsubpath        ;But otherwise enter that state!
restoresequencing
        BL      restorecursors
sequencing
        ADR     R0,ErrorBlock_BadPathSequence
        B       errorandpullpc

        MakeInternatErrorBlock  BadPathSequence,,M05

; Subroutine to close the current subpath if it is open and open subpaths
; are to be closed.

closeopensubpath
        LDR     type,flags
        TST     type,#f_closeopensubpaths
        BEQ     %FT99
        ADR     type,subpathstart
        LDMIA   type,{newX,newY,type}
        ASSERT  type > newX
        ASSERT  type > newY
        ASSERT  subpathtype = subpathstart+8
        TEQ     type,#movetoET  ;Return if current subpath is of wrong type
        BNE     %FT99
        Push    "LR"
        MOV     type,#closewithlineET
        CallNextRoutine         ;Generate and pass down closure
        Pull    "PC"
99
        CLRV
        Return

; Subroutine to restore the cursors if necessary. Preserves R0-R13 and flags.
; Also updates the OS's ChangedBox variable if necessary (this is done even
; if an error occurred, because some errors are only detected after some
; plotting has been done).

restorecursors
        EntryS
        LDR     R14,outputtype
        CMP     R14,#DrawSpec_Fill
        CMPNE   R14,#DrawSpec_FillBySubpaths
        EXITS   NE
        SWI     XOS_RestoreCursors
        LDR     R14,changedboxaddr
        LDR     R14,[R14]
        TST     R14,#1
        BLNE    updatechangedbox
        EXITS

; Errors

        MakeInternatErrorBlock  MayExpandPath,,M06

notinirqmode
        ADR     R0,ErrorBlock_NoDrawInIRQMode
        BL      CopyError
        Pull    "PC"

        MakeInternatErrorBlock  NoDrawInIRQMode,,M00

swioutofrange
        ADR     R0,ErrorBlock_ModuleBadSWI
        B       CopyError

        MakeErrorBlock ModuleBadSWI

reasonoutofrange
        ADR     R0,ErrorBlock_BadDrawReasonCode
errorandpullpc
        BL      CopyError
        Pull    "PC"

        MakeInternatErrorBlock  BadDrawReasonCode,,M01

reservedbitsnotzero
        ADR     R0,ErrorBlock_ReservedDrawBits
        B       errorandpullpc

        MakeInternatErrorBlock  ReservedDrawBits,,M02

restoreinvalidpointer
        BL      restorecursors
invalidpointer
        ADR     R0,ErrorBlock_InvalidDrawAddress
        B       errorandpullpc

        MakeInternatErrorBlock  InvalidDrawAddress,,M03

restorebadpath
        BL      restorecursors
badpath
        ADR     R0,ErrorBlock_BadPathElement
        B       errorandpullpc

        MakeInternatErrorBlock  BadPathElement,,M04

unimplemented
        ADR     R0,ErrorBlock_UnimplementedDraw
        B       errorandpullpc

        MakeInternatErrorBlock  UnimplementedDraw,,M12

restorenotagraphicsmode
        BL      restorecursors
        ADR     R0,ErrorBlock_DrawNeedsGraphicsMode
        B       errorandpullpc

        MakeInternatErrorBlock  DrawNeedsGraphicsMode,,M11

; The list of VDU variables used

vduvarsspec     DCD     VduExt_GWLCol
                DCD     VduExt_GWBRow
                DCD     VduExt_GWRCol
                DCD     VduExt_GWTRow
                DCD     VduExt_OrgX
                DCD     VduExt_OrgY
                DCD     VduExt_XEigFactor
                DCD     VduExt_YEigFactor
                DCD     VduExt_HLineAddr
                DCD     VduExt_ModeFlags
                DCD     -1

        LTORG

        LNK     DrProcess.s
