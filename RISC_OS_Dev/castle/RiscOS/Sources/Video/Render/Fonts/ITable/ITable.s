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
; > s.ITable

; *********************
; ***  CHANGE LIST  ***
; *********************
;
; 08-Dec-95 0.00 DDV Created
; 11-Dec-95      DDV Added Hourglass display to show that we haven't got stuck.
; 12-Dec-95      DDV Bug fix: R and B in the table calculator needed swapped to map to VIDC format.
; 12-Dec-95      DDV Palette write operations cause inverse table to be invalidated.
; 12-Dec-95      DDV Now use ColourTrans to read palette (should cope with output to sprite).
; 12-Dec-95      DDV Added check to only recompute inverse-table when palette changes.
; 12-Dec-95      DDV Support for switching output to a sprite invalidating the tables.
; 13-Dec-95      DDV Fixed SWI chunk to one from Alan Glover (+ some reformatting).
; 13-Dec-95      DDV Errors reported out of calculate correctly.
; 13-Dec-95 0.01 DDV Uses a temporary dynamic area for storing inverse table distances buffer - when computing.
; 13-Dec-95 0.02 DDV Conditonally removed use of a dynamic area - causes Font Manager/Wimp to barf!
; 13-Dec-95      DDV Reduced workspace usage, tidied some variables
; 13-Dec-95      DDV Now uses dynamic areas properly for storing inverse and distance tables.
; 13-Dec-95 0.03 DDV Dynamic area sized to contain distance table and reduced after use.
; 01-Jul-96 0.04 SJM With standard palette it checks for one in resourcefs before creating.
; 05-Aug-99 0.08 KJB Ursula branch merged. Changed to use srccommit.
; 12-May-00 0.09 KJB 32-bit compatible.

        IMPORT  usermode_donothing

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Proc
        GET     Hdr:Services
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:VduExt
        GET     Hdr:ResourceFS
        GET     Hdr:MsgTrans
        GET     Hdr:Sprite
        GET     Hdr:ColourTran
        GET     Hdr:Hourglass
        GET     Hdr:NDRDebug
        GET     Hdr:PublicWS
        GET     Hdr:HostFS
        GET     Hdr:PaletteV

        GET     hdr.ITable                      ; our SWI information
        GET     VersionASM                      ; and version data


; ------------------------------------------------------------------------------
; Constants, macros and structures
; ------------------------------------------------------------------------------

                GBLL    debug
                GBLL    hostvdu
debug           SETL    {FALSE}
hostvdu         SETL    {FALSE}
      [ :LNOT::DEF:standalone
                GBLL    standalone
standalone      SETL    {FALSE}
      ]

                                 GBLL    UseResourceTable
UseResourceTable                 SETL    {TRUE}
                                 GBLL    UseColourTransResourceTable
UseColourTransResourceTable      SETL    {TRUE}
                                 GBLL    CallColourTransForTable
CallColourTransForTable          SETL    {TRUE}
                                 GBLL    DontAssumeRedirectionIsToggling
DontAssumeRedirectionIsToggling  SETL    {TRUE}

; Constants used for computing table

bits            * 5                             ; significant bits per gun used for table index

nbits           * 8 - bits                      ; DO NOT modify computed from bits
x               * 1 << nbits                    ; DO NOT modify computed from bits
xsqr            * 1 << ( 2 * nbits )            ; DO NOT modify computed from bits
colourmax       * 1 << bits                     ; DO NOT modify computed from bits


; Workspace allocation

                ^ 0, WP
iFlags          # 4                             ; = flags ( f_xxx )

f_PaletteV       * &00000001                    ; = 1 => palette vector has been claimed
f_TableValid     * &00000002                    ; = 1 => inverse table is valid for current destination
f_SwitchInvalid  * &00000004                    ; = 1 => Switched to a sprite, therefore if calculating the table is invalid
 [ UseResourceTable
f_StandardPal    * &00000008                    ; = 1 => The current palette is the standard one
 |
f_StandardPal    * &00000000
 ]
 [ DontAssumeRedirectionIsToggling
f_CurrentlyScreen * &00000010                   ; = 1 => currently redirected to the screen
f_TableScreen     * &00000020                   ; = 1 => the table we have is for the screen
 ]
iDynamicArea    # 4                             ; = ID of our dynamic area

pInverseTable   # 4                             ; -> current inverse table
pDistanceTable  # 4                             ; -> distance table

 [ UseResourceTable
pResourceTable  # 4
 ]

iPalette555     # 4 * 256                       ; = palette quanitised down to 5,5,5 RGB

ws_required     * :INDEX: @


; Dynamic area allocation

                ^ 0
da_iInverseTable        # colourmax * colourmax * colourmax
da_MinimumSize          * :INDEX: @

da_iDistanceTable       # ( ?da_iInverseTable ) * 4
da_MaximumSize          * :INDEX: @


; ------------------------------------------------------------------------------
; Module header and basic initialisation of the module.
; ------------------------------------------------------------------------------

        AREA    |ITable$$Code|, CODE, READONLY, PIC

module_base
        DCD     0                               ; No application entry
        DCD     Init - module_base
        DCD     Die - module_base
        DCD     Service - module_base

        DCD     Title - module_base
        DCD     Help - module_base
        DCD     0                               ; no commands

        DCD     InverseTableSWI_Base
        DCD     SWIDespatch - module_base
        DCD     SWINames - module_base
        DCD     0                               ; SWI name decode
        DCD     0                               ; messages
      [ :LNOT: No32bitCode
        DCD     ModuleFlags - module_base
      ]

Help    DCB     "Inverse Table", 9, "$Module_HelpVersion"
      [ debug
        DCB     " Development version"
      ]
        DCB     0
        ALIGN

      [ :LNOT: No32bitCode
ModuleFlags
        DCD     ModuleFlag_32bit
      ]

Title
SWINames
        DCB     "InverseTable", 0               ; prefix
        DCB     "Calculate", 0
        DCB     "SpriteTable", 0
        DCB     0
        ALIGN

;; ------------------------------------------------------------------------------
;; Initialise, claim our workspace and set to a sensible state!
;; ------------------------------------------------------------------------------

Init    Entry   "R1-R3"

        LDR     R2, [WP]                        ; pick up the private word
        TEQ     R2, #0                          ;   do we already have our workspace?
        BNE     %FT10

        MOV     R0, #ModHandReason_Claim
        LDR     R3, =ws_required
        SWI     XOS_Module                      ; attempt to claim our workspace block
        EXIT    VS                              ;   if that fails then return

        STR     R2, [WP]                        ; set the private word to point at our workspace
10
        MOV     WP, R2

      [ standalone
        ADRL    R0, msg_area
        SWI     XResourceFS_RegisterFiles
        EXIT    VS
      ]

 [ DontAssumeRedirectionIsToggling
        MOV     R0, # f_CurrentlyScreen         ; initially we're directed at the screen
        STR     R0, iFlags
        MOV     R0, #0                          ; NULL suitable entries
 |
        MOV     R0, #0                          ; NULL suitable entries
        STR     R0, iFlags
 ]
        STR     R0, iDynamicArea
        STR     R0, pInverseTable

        MOV     R0, # -1                        ; = -1 => invalid 5,5,5 entry
        ADR     R1, iPalette555
        LDR     R2, = ?iPalette555
20
        SUBS    R2, R2, # 4
        STRGE   R0, [ R1 ], # 4
        BGE     %BT20

        Debug_Open      pipe:itable

        BL      claim_vectors                   ; try to claim the vectors
        EXIT                                    ;   and return any possible errors


;; ------------------------------------------------------------------------------
;; Tidy up as about to die!
;; ------------------------------------------------------------------------------

Die     Entry   "R1-R2"

        LDR     WP, [WP]                        ; do we have a workspace pointer currently?
        CMP     WP, # 0                         ;   if not then there is nothing to tidy up
        EXIT    EQ

        LDR     R3, iFlags
        TST     R3, # f_PaletteV                ; do we currently have the palette vector claimed?
        MOVNE   R0, # PaletteV
        ADRNE   R1, palVhandler
        MOVNE   R2, WP
        SWINE   XOS_Release

        BL      release_area                    ; if we have a dynamic area then discard it

      [ standalone
        ADRL    R0, msg_area
        SWI     XResourceFS_DeregisterFiles
      ]
        Debug_Close

        EXIT


;; ------------------------------------------------------------------------------
;; Service calls broadcast, if an interesting one then act on it - but never claim.
;; ------------------------------------------------------------------------------

        ; Ursula format
        ; 
        ASSERT  Service_Reset                   < Service_ModeChange
        ASSERT  Service_ModeChange              < Service_ResourceFSStarted
        ASSERT  Service_ResourceFSStarted       < Service_ResourceFSDying
        ASSERT  Service_ResourceFSDying         < Service_ResourceFSStarting
        ASSERT  Service_ResourceFSStarting      < Service_SwitchingOutputToSprite
        ASSERT  Service_SwitchingOutputToSprite < Service_PostInit
UServTab
        DCD     0
        DCD     UService - module_base
        DCD     Service_Reset
        DCD     Service_ModeChange
  [ UseResourceTable
        DCD     Service_ResourceFSStarted
        DCD     Service_ResourceFSDying
  ]
  [ standalone
        DCD     Service_ResourceFSStarting
  ]
        DCD     Service_SwitchingOutputToSprite
  [ UseResourceTable
        DCD     Service_PostInit
  ]
        DCD     0
        DCD     UServTab - module_base
Service ROUT
        MOV     r0, r0
        TEQ     R1, # Service_Reset             ; filter out only the ones we want
        TEQNE   R1, # Service_ModeChange
        TEQNE   R1, # Service_SwitchingOutputToSprite
 [ UseResourceTable
        TEQNE   R1, # Service_ResourceFSStarted
        TEQNE   R1, # Service_ResourceFSDying
        TEQNE   R1, # Service_PostInit
 ]
 [ standalone
        TEQNE   R1, # Service_ResourceFSStarting
 ]
        MOVNE   PC, LR
UService

        Entry   "R0-R1"

        LDR     WP, [ WP ]                      ; get workspace pointer
        LDR     R0, iFlags                      ;   and current flags word

        TEQ     R1, # Service_Reset
        BNE     %FT10

        ; It was a reset - therefore reset flags / mark as no dynamic area etc

        BIC     R0, R0, # f_TableValid :OR: f_PaletteV :OR: f_StandardPal
        STR     R0, iFlags

        MOV     R0, # 0                         ; remove the dynamic area
        STR     R0, iDynamicArea
        STR     R0, pInverseTable
        STR     R0, pDistanceTable

        BL      claim_vectors                   ; must claim the vectors again

        EXIT

10                                              ; if resourcefs changed get the new ptr
 [ UseResourceTable
        TEQ     R1, # Service_ResourceFSStarted
        TEQNE   R1, # Service_ResourceFSDying
        TEQNE   R1, # Service_PostInit
        BNE     %ft20

        BL      check_resource

        LDR     R1, pResourceTable              ; if table has vanished then clear the StandardPal bit
        CMP     R1, #0                          ; and set the table to invalid
        BICEQ   R0, R0, # f_TableValid
        STREQ   R0, iFlags

        EXIT

20
 ]
 [ standalone
        TEQ     R1, # Service_ResourceFSStarting
        BNE     %FT30

        ADRL    R0, msg_area                    ; reinstall the resource block
        MOV     LR, PC
        MOV     PC, R2
        EXIT
30
 ]
        TEQ     R1, # Service_ModeChange
        BICEQ   R0, R0, # f_TableValid          ; mode change, therefore table bad
        TEQ     R1, # Service_SwitchingOutputToSprite
 [ DontAssumeRedirectionIsToggling
        BNE     %FT40
        ; we're changing redirection
        ORR     R0, R0, # f_SwitchInvalid       ; output gone to sprite - maybe invalid

        TEQ     R3,#0                           ; sprite area
        TEQEQ   R4,#0                           ; sprite name/pointer (both 0 if going to screen)
        BICNE   R0, R0, # f_CurrentlyScreen
        ORREQ   R0, R0, # f_CurrentlyScreen

        TST     R0, # f_TableValid              ; if the table is already invalid
        TSTNE   R0, # f_CurrentlyScreen         ; ... or if we're not going to the screen now
        BEQ     %FT40                           ; ... we don't care
        TST     R0, # f_TableScreen             ; is the table for the screen ?
        BICNE   R0, R0, # f_SwitchInvalid       ; if so, then the table /is/ valid again
40
 |
        EOREQ   R0, R0, # f_SwitchInvalid       ; output gone to sprite - maybe invalid
 ]
        STR     R0, iFlags

        EXIT


;; ------------------------------------------------------------------------------
;; Perform SWI dispatch, first ensuring :
;;
;;  - SWI is within our supported range
;;  - IRQs are enabled as we take some time
;; ------------------------------------------------------------------------------

SWIDespatch ROUT

        LDR     WP, [WP]                        ; de-reference the workspace pointer
        WritePSRc SVC_mode, R10                 ;   ensure that IRQ's get re-enabled

        Push    "LR"
        BL      SWIDespatchInternal
        Pull    "LR"

      [ No32bitCode
        ORRVSS  PC, LR, #V_bit                  ; mark that an error occurred
        MOVS    PC, LR
      |
        TEQ     PC, PC                          ; preserves V
        MOVEQ   PC, LR                          ; 32 bit exit
        ORRVSS  PC, LR, #V_bit                  ; 26 bit error exit
        MOVS    PC, LR
      ]

        MakeInternatErrorBlock ModuleBadSWI,,BadSWI

msg_filename
        DCB     "Resources:$.Resources.ITable.Messages", 0
        ALIGN

SWIDespatchInternal

        CMP     R11, #( %90-%00 ) / 4           ; is the index valid for our swi table
        ADDCC   PC, PC, R11, LSL # 2            ;   if it is then despatch
        B       %FT90
00
        B       ITable_Calculate
        B       ITable_SpriteTable
90
        ADR     R0, ErrorBlock_ModuleBadSWI
make_error
        Push    "R1-R7,LR"
        SUB     SP, SP, #16                     ; temporary MessageTrans structure

        MOV     R7, R0                          ; Push R0
        MOV     R0, SP
        ADR     R1, msg_filename
        MOV     R2, #0
        SWI     XMessageTrans_OpenFile
        BVS     %FT95                           ; someone ate my messages file
        MOV     R0, R7                          ; Pull R0

        MOV     R1, SP
        MOV     R2, #0                          ; use MessageTrans internal buffer
        ADRL    R4, Title
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup

        MOV     R7, R0                          ; Push R0
        MOV     R0, SP
        SWI     XMessageTrans_CloseFile
        MOV     R0, R7                          ; Pull R0
95
        ADD     SP, SP, #16                     ; finished with the structure
        SETV
        Pull    "R1-R7,PC"

;; ------------------------------------------------------------------------------
;; Claim vectors used by the modules
;; ------------------------------------------------------------------------------

claim_vectors Entry "R1-R3"

        CLRV
        LDR     R3, iFlags
        TST     R3, # f_PaletteV                ; is paletteV claimed currently
        EXIT    EQ

        MOV     R0, #PaletteV
        ADR     R1, palVhandler
        MOV     R2, WP
        SWI     XOS_Claim                       ; attempt to claim the palette vector
        ORRVC   R3, R3, # f_PaletteV            ;  if that worked then mark as claimed

        STR     R3, iFlags

        EXIT

; . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .

palVhandler ROUT

        TEQ     R4, # paletteV_Set
        TEQNE   R4, # paletteV_SetDefaultPalette
        TEQNE   R4, # paletteV_BulkWrite
        MOVNE   PC, LR                          ; not a modifying palette operation

        Entry   "WP"

        TEQ     R4, # paletteV_Set              ; are we writing an entry?
        BNE     %FT01

        CMP     R1, # 24                        ; is it the border or cursor colour?
        EXIT    GE
01
        LDR     LR, iFlags
        BIC     LR, LR, # f_TableValid          ; table is no longer valid
        STR     LR, iFlags

        EXIT

;;-----------------------------------------------------------------------------
;;
;; Check on the resource file presence

 [ UseResourceTable
table_filename
  [ UseColourTransResourceTable
        DCB     "Resources:$.Resources.Colours.Tables.8desktop", 0
  |
        DCB     "Resources:$.Resources.ITable.Tables.8desktop", 0
  ]
        ALIGN

check_resource
        Entry   "r0-r11"

        Debug1  ,"check_resource"

        MOV     R0, #0                          ; zero the pointer first
        STR     R0, pResourceTable

        MOV     R0, #open_read :OR: open_nopath :OR: open_nodir
        ADR     R1, table_filename
        SWI     XOS_Find
        EXIT    VS

        MOVS    R11, R0                         ; save the file handle in R11
        EXIT    EQ                              ; exit if zero (can't open file)

        MOV     R1, R0                          ; get the fs number
        MOV     R0, #OSArgs_ReadInfo
        SWI     XOS_Args
        BVS     %ft99

        AND     R0, R2, #&FF                    ; is it ResourceFS?
        CMP     R0, #fsnumber_resourcefs
        BNE     %ft99

        MOV     R0, #FSControl_ReadFSHandle     ; get the internal handle
        SWI     XOS_FSControl
        BVS     %ft99

        STR     R1, pResourceTable              ; save the direct pointer to the file

        Debug   ,"pResourceTable",R1

99      MOV     R0, #0                          ; close the file
        MOV     R1, R11
        SWI     XOS_Find

        EXIT
 ]

;;-----------------------------------------------------------------------------
;; InverseTable_Calculate implementation
;;
;; Return the pointers to the inverse colour table.  If the table is marked
;; as invalid then we must recompute it, also if output has been switched
;; to a sprite we must also recompute it.
;;
;; The table validity is marked by a flag in our flags word (f_TableValid),
;; when this == 1 then the table has been correctly cached, and therefore
;; does not need recomputing.
;;
;; Another bit is used to indicate if output is being swithced to a sprite,
;; this bit is toggled each time output is toggled.  Therefore if this SWI
;; is called and 'f_SwitchInvalid' == 1 then output it redirected to the
;; sprite and we must recompute the inverse table.
;;
;; The two tables returned allow the quick mapping for colour index to
;; 5,5,5 RGB, and 5,5,5 RGB to colour index (the later is often refered
;; to as an inverse table).
;;
;; 5,5,5 RGB contains the data where each gun is represented as 5 bits:
;;
;;      < b14-10 == B >
;;                     < b9-5 == G >
;;                                  < b4-0 == R >
;;
;; So using a colour number as an index into the table at R0 will yield
;; a 32 bit word containing the above data.
;;
;; To convert that word back to a colour number then the 5,5,5 RGB
;; can be used as an index into the byte array of colour numbers.
;;
;; This SWI should only be called if the mode is == 8 bit per pixel,
;; all other depths will result in a 'Bad MODE error'.
;;
;; NB: If the SWI does error then R1 will be corrupt.
;;
;; in   -
;; out  R0 -> index to 5,5,5 RGB data
;;      R1 -> 5,5,5 RGB data to index table
;;-----------------------------------------------------------------------------

ITable_Calculate Entry "R2"

        MOV     R0, #-1
        MOV     R1, #VduExt_Log2BPP
        SWI     XOS_ReadModeVariable            ; read the log2 bits per pixel for this mode
        TEQ     R2, #3                          ;   if this is not 8 bit then exit
        ADRNE   R0, ErrorBlock_BadMODE
        BLNE    make_error
        BVS     %FT90

        LDR     R2, iFlags                      ; check to see if table is valid
        TST     R2, # f_SwitchInvalid
        BICNE   R2, R2, # f_TableValid :OR: f_SwitchInvalid
        TST     R2, # f_TableValid
        BLEQ    build_itable                    ; if not valid then build the inverse table

 [ UseResourceTable
        EXIT    VS

        LDR     R2, iFlags                      ; reload flags as they may have changed
        ADR     R0, iPalette555                 ; -> RGB 5,5,5 table ( index => 5,5,5 )
        TST     R2, # f_StandardPal
        LDRNE   R1, pResourceTable              ; if bit is not set
        CMPNE   R1, #0                          ; or resource table is not present
        LDREQ   R1, pInverseTable               ; use the built table

        Debug   ,"ITable_Calculate",R0,R1,R2
 |
        ADRVC   R0, iPalette555                 ; -> RGB 5,5,5 table ( index => 5,5,5 )
        LDRVC   R1, pInverseTable               ; -> inverse table (5,5,5 => colour number)
 ]
90
        EXIT

        MakeInternatErrorBlock BadMODE,,BadMODE

;;-----------------------------------------------------------------------------
;; InverseTable_SpriteTable implementation
;;
;; As per InverseTable_Calculate, except we perform the conversion for a
;; user-supplied palette, into a user-supplied destination buffer.
;;
;; As an optimisation we're allowed to replace the user's buffer pointers
;; with pointers of our own if we've got the data cached already. At the
;; moment we only bother to do this if they're requesting a table for the
;; current mode.
;;
;; This SWI should only be called if the mode is == 8 bit per pixel,
;; all other depths will result in a 'Bad MODE error'.
;;
;; in   R0 -> buffer to fill with index to 5,5,5 table
;;      R1 -> buffer to fill with 5,5,5 to index table
;;      R2 = sprite area/mode (same as R0 of ColourTrans_ReadPalette)
;;      R3 = sprite pointer/palette (same as R1 of ColourTrans_ReadPalette)
;;           note: No way of specifying a sprite name
;; out  R0 -> index to 5,5,5 RGB data
;;      R1 -> 5,5,5 RGB data to index table
;;-----------------------------------------------------------------------------

ITable_SpriteTable
        CMP     R2, #-1
        CMPEQ   R3, #-1
        BEQ     ITable_Calculate                ; branch through to InverseTable_Calculate if they're interested in the current mode

        Entry   "R0-R11"

        MOV     R0, R2
        MOV     R4, #0
        
        ; Have we been given a sprite or a mode?
        CMP     R2, #256
        BLO     %FT10
        TST     R2, #1
        BNE     %FT10

        ; Should be a sprite area
        LDR     R0, [R3, #spMode]
        MOV     R4, #1
10
        MOV     R1, #VduExt_Log2BPP
        SWI     XOS_ReadModeVariable            ; read the log2 bits per pixel for this mode
        TEQ     R2, #3                          ;   if this is not 8 bit then exit
        ADRNE   R0, ErrorBlock_BadMODE
        BLNE    make_error
        STRVS   R0, [sp]
        BVS     %FT90

        ; Fetch the palette
        LDR     R0, [sp, #8] ; Recover R2
        MOV     R1, R3
        LDR     R2, [sp] ; Recover R0
        MOV     R3, #1024
        ; R4 already initialised above
        SWI     XColourTrans_ReadPalette
        STRVS   R0, [sp]
        BVS     %FT90

        SWI     XHourglass_On                   ; this could take some time

        ; If we're using ColourTrans, fetch the table now using the palette
        ; we just fetched
   [ CallColourTransForTable
        LDR     r0, =1 :OR: (5<<27) :OR: (90<<1) :OR: (90<<14) ; source mode,
                                                               ; resolution not relevant but should be valid
        MOV     r1, #-1                                        ; the current palette
        SUB     r3, r2, #1024                                  ; destination palette
        LDR     r2, =1 :OR: (4<<27) :OR: (90<<1) :OR: (90<<14) ; destination mode (8bpp, will be treated as full palette)
        LDR     r4, [sp, #4]                                   ; decent sized buffer for the output
                                                               ; note: the output should be 3 words
        MOV     r5, #0                                         ; flags
        SWI     XColourTrans_GenerateTable
        STRVS   r0, [sp]
        BVS     %FT85                                          ; error is just fatal
        ; check it's something we understand
        LDR     r0, word_32k
        LDMIA   r4, {r1,r2,r3}
        TEQ     r0, r1
        TEQEQ   r0, r3
        BNE     %FT30                                          ; no idea what that is, do it ourselves
        
        ; now copy it to the user's buffer
        MOV     r0, # (colourmax * colourmax * colourmax)
        MOV     r1, r4
        ; r0 = entries
        ; r1->destination
        ; r2->source
16
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 8 registers = 4*8 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 16 registers = 4*16 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 24 registers = 4*24 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 32 registers = 4*32 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        SUBS    r0, r0, #32*4
        BNE     %BT16

        B       %FT40
   ]

30

        ; Generate the table
        BL      claim_area                      ; The dynamic area is needed for temp storage of the distance table
        LDMVCIA SP, {R0-R1}
        BLVC    build_itable_core
        STRVS   R0, [SP]
        BVS     %FT85

40
        ; Convert the palette we fetched earlier to 555
        LDR     R0, [sp]
        ADD     R2, R0, #1024
50
        LDR     R1, [R2, #-4]!
        AND     R3, R1, #&0000F800
        AND     R4, R1, #&00F80000
        MOV     R3, R3, LSR #8+3
        AND     R5, R1, #&F8000000
        ORR     R1, R3, R4, LSR #16+3-5
        ORR     R1, R1, R5, LSR #24+3-10
        CMP     R0, R2
        STR     R1, [R2]
        BNE     %BT50
85
        SavePSR LR
        Push    "R0,LR"
        SWI     XHourglass_Off                  ; remove hourglass
        Pull    "R0,LR"                         ;   preserving error condition around call
        RestPSR LR,,cf
90
        EXIT


;; ------------------------------------------------------------------------------
;; Dynamic area management code.
;;
;; We keep the inverse table in a dynamic area, we create this dynamic area with
;; enough room to grow and contain the distance table as-well, although this is
;; only claimed when the distance table is needed - therefore we can keep
;; our memory footprint nice and small.
;; ------------------------------------------------------------------------------

claim_area Entry "R1-R8"

        LDR     R0, iDynamicArea
        CMP     R0, # 0                         ; have we already allocated our dynamic area?
        EXIT    NE

        MOV     R0, # 0                         ; = 0 => create dynamic area
        MOV     R1, # -1
        LDR     R2, = da_MinimumSize            ; minimum size (size of inverse table)
        MOV     R3, # -1
        MOV     R4, # ( 1:SHL:7)
        LDR     R5, = da_MaximumSize            ; maximum size (inverse table + distance table)
        MOV     R6, # 0
        MOV     R7, # 0
        ADRL    R8, Title                       ; -> name for dynamic area (Task Manager)
        SWI     XOS_DynamicArea
        STRVC   R1, iDynamicArea
        STRVC   R3, pInverseTable

        EXIT

release_area Entry "R0-R1"

        LDR     R1, iDynamicArea
        CMP     R1, # 0                         ; has a dynamic area been created
        EXIT    EQ

        MOV     R0, # 1                         ; = 1 => discard dynamic area
        SWI     XOS_DynamicArea
        CLRV
        EXIT


;; ------------------------------------------------------------------------------
;; Compute both the inverse colour table, and quantise the 24 bit palette
;; down to its 5,5,5 representation.
;;
;; This code implementes the Incremental Distance algorithm for inverse table generation
;; as outlined in Graphics Gems pp116-119 (see that for the exact details).  Basically,
;; we have an array which contains the position within the colour cube of every
;; entry we are going to visit (based on the 5,5,5 indexes).
;;
;; This table is initialised to -1, ie. all entries must match.  We then
;; have three loops (b,g,r in that order).  And we scan along each axis of the
;; cube seeing if the distance for the colour at this point is greater
;; than the previously stored distance for this point.  If it is then we
;; replace it.
;;
;; Before we can start computing the table we read the current palette, via
;; ColourTrans - this will cope with output directed to a sprite and return
;; the one for that, or the screen palette expanded to full 24 bit.
;;
;; We then quanitise the palette down, by taking the top 5 bits of each
;; gun and composing the 5,5,5 palette data.  Whilst doing this we compare
;; it to the previous entries we have for the 5,5,5 table, if there is
;; no change then we do not need to compute the inverse table (which is
;; a lengthy process and should be avoided).
;;
;; Assuming we have taken the above steps and have determined that the
;; palette has changed then we compute the inverse table.  We make use of
;; the Hourglass to indicate how far through this process we are - therefore
;; the user gets some impression of how long before their compute comes
;; back to life - the process takes about 7 seconds, on a RPC 600.
;;
;; NB: This code uses scratch space.
;;
;; ------------------------------------------------------------------------------

        ; Temporary workspace usage

                ^ ScratchSpace
scratch_palette # 256 * 4


        ; Register allocations

pITable         RN 0    ;                       ---- always ---
pDistances      RN 1    ;                       ---- always ---

rDist           RN 2    ; (outerloop)
gDist           RN 3    ; (outerloop)
bDist           RN 4    ; (outerloop)

rInc            RN 5    ; (outerloop)
gInc            RN 6    ; (outerloop)
bInc            RN 7    ; (outerloop)

r               RN 8    ;              (r inner loop)
g               RN 9    ;                             (g inner loop)
b               RN 10   ;                                            (b inner loop)

scratch         RN 10   ; (outer loop)
iColours        RN 11   ; (outer loop)                  (doubles as return value register)


        ; Table used to set hourglass percentage values

percent_table
        DCB      0,  3, 6,   9, 12, 15, 19, 22
        DCB     25, 28, 31, 35, 38, 41, 44, 47
        DCB     51, 54, 57, 60, 63, 67, 70, 73
        DCB     76, 79, 83, 86, 89, 92, 95, 99
        ALIGN

        ; Do it....

build_itable Entry "R1-R11"

        SWI     XHourglass_On                   ; this could take some time

        ; Get palette for current screen mode / destination

        MOV     R0, # -1                        ; read palette for current destination
        MOV     R1, # -1
        LDR     R2, = scratch_palette           ; into this buffer
        LDR     R3, = ?scratch_palette          ;   which is so big
        MOV     R4, # 0
        SWI     XColourTrans_ReadPalette
        BVS     %FT90

        ; Convert palette from 24 bit RGB to 5,5,5 RGB

        LDR     R0, = scratch_palette
        ADRL    R1, iPalette555
        LDR     R2, = ?scratch_palette
        MOV     R5, # 1                         ; table has not been modified yet

 [ UseResourceTable
        ADRL    R6, StandardPalette             ; standard 8 bit palette
        MOV     R7, # 1                         ; 1 = palette matches standard
 ]
10
        LDR     R3, [ R0 ], #4                  ; pick up 24 bit palette entry
        AND     R4, R3, #&f8000000              ;   and convert to 5,5,5 RGB
        AND     LR, R3, #&00f80000
        ORR     R4, R4, LR, LSL # 3
        AND     R3, R3, #&0000f800
        ORR     R3, R4, R3, LSL # 6
        MOV     R3, R3, LSR # 17

        LDR     LR, [ R1 ]
        TEQ     LR, R3                          ; has the colour changed?
        MOVNE   R5, # 0                         ;   yes, so must re-compute the inverse table
        STR     R3, [ R1 ], #4

 [ UseResourceTable
      [ NoARMv4
        LDRB    R4, [ R6, # 1 ]
        LDRB    LR, [ R6 ], #2
        ORR     LR, LR, R4, LSL # 8
      |
        LDRH    LR, [ R6 ], #2
      ]
        TEQ     LR, R3                          ; is the colour different from the standard
        MOVNE   R7, # 0                         ;   yes, then we can't use the standard table
 ]
        SUBS    R2, R2, # 4
        BGT     %BT10                           ; loop until *ENTIRE* palette converted

        Debug   ,"build_itable changed",R5

        CMP     R5, #0                          ; has the palette actually changed?
 [ UseResourceTable
        LDRNE   LR, pInverseTable               ;   if not then is there a table present
        CMPNE   LR, #0
 ]
        BNE     %FT85                           ;   if so then don't bother re-calculating the colour table

 [ UseResourceTable
        Debug   ,"build_itable standard",R7

        LDR     LR, iFlags

        CMP     R7, # 0                         ; is it actually the standard palette?
        BICEQ   LR, LR, #f_StandardPal          ;   no - clear flag, store and carry on
        STREQ   LR, iFlags
        BEQ     %FT20

        ORR     LR, LR, #f_StandardPal          ;   yes - set flag
        LDR     R7, pResourceTable              ;   check if we have the resource table
        CMP     R7, # 0
        ORRNE   LR, LR, # f_TableValid          ;     yes - then table is now valid
 [ DontAssumeRedirectionIsToggling
        STREQ   LR, iFlags
        BEQ     %FT90

        ; remember what this table was for - the screen or a sprite
        TST     LR, # f_CurrentlyScreen
        BICEQ   LR, LR, # f_TableScreen
        ORRNE   LR, LR, # f_TableScreen
        STR     LR, iFlags
        B       %FT90
 |
        STR     LR, iFlags
        BNE     %FT90                           ;     and exit, else carry on
 ]

20
 ]

        ; Ensure that we have the dynamic area

        BL      claim_area                      ; attempt to claim the dynamic area ready to build the table
        BVS     %FT90

   [ CallColourTransForTable
        LDR     r0, =1 :OR: (5<<27) :OR: (90<<1) :OR: (90<<14) ; source mode,
                                                               ; resolution not relevant but should be valid
        MOV     r1, #-1                                        ; the current palette
        MOV     r2, #-1                                        ; destination mode
        MOV     r3, #-1                                        ; default palette for that mode
        LDR     r4, pInverseTable                              ; decent sized buffer for the output
                                                               ; note: the output should be 3 words
        MOV     r5, #0                                         ; flags (nothing special)
        SWI     XColourTrans_GenerateTable
        BVS     %FT90                                          ; error is just fatal
        ; check it's something we understand
        LDR     r0, word_32k
        LDMIA   r4, {r1,r2,r3}
        TEQ     r0, r1
        TEQEQ   r0, r3
        BNE     %FT17                                          ; no idea what that is, do it ourselves

        ; in theory at this point we can just remember r2, but the current algorithms used mean
        ; that itable could end up remembering a buffer after it had been discarded by CT
        ; so we'll just copy the buffer.
        
        ; now copy it to our buffer
        MOV     r0, # (colourmax * colourmax * colourmax)
        MOV     r1, r4
        ; r0 = entries
        ; r1->destination
        ; r2->source
16
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 8 registers = 4*8 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 16 registers = 4*16 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 24 registers = 4*24 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        LDMIA   r2!, {r3,r4,r5,r6,r7,r8,r9,r10} ; 32 registers = 4*32 bytes
        STMIA   r1!, {r3,r4,r5,r6,r7,r8,r9,r10}
        SUBS    r0, r0, #32*4
        BNE     %BT16

        ; done, jump to tail of routine
        B       %FT85

        ; ColourTrans magic word
word_32k
        DCB     "32K."
   ]

        ; here we start to generate the table ourselves
17
        LDR     R0, =scratch_palette
        LDR     R1, pInverseTable
        BL      build_itable_core
85
        LDR     LR, iFlags
        ORR     LR, LR, # f_TableValid          ; table is now valid
  [ DontAssumeRedirectionIsToggling
        ; remember what this table was for - the screen or a sprite
        TST     LR, # f_CurrentlyScreen
        BICEQ   LR, LR, # f_TableScreen
        ORRNE   LR, LR, # f_TableScreen
  ]
        STR     LR, iFlags
90
        SavePSR LR
        Push    "R0,LR"
        SWI     XHourglass_Off                  ; remove hourglass
        Pull    "R0,LR"                         ;   preserving error condition around call
        RestPSR LR,,cf

        EXIT

; Actually build a table
;
; On entry:
; R0 = dest palette (as &BBGGRR00)
; R1 = dest buffer
; DA must exist
; Hourglass on
; On exit:
; All regs corrupt

build_itable_core ROUT
        Entry   "R0-R1"
        LDR     R0, iDynamicArea
        MOV     R1, # ?da_iDistanceTable
        SWI     XOS_ChangeDynamicArea           ; expand to contain our distances table
; JRF note: I believe that this may leak some memory if the claim wasn't completely
;           satisfied; it /may/ return that only part of the claim took place - we
;           rely here on the fact that da_iDistanceTable is a multiple of the page
;           size long. fortunately, it is and we know it.
        STRVS   R0, [SP]                        ;   if that fails then return
        EXIT    VS

        LDR     R0, pInverseTable
        ASSERT  da_iDistanceTable > 0
        ADD     R0, R0, # da_iDistanceTable     ; -> distance table in dynamic area
        STR     R0, pDistanceTable

        ; Initialise the distance table to -1 (assumes R0 points at it!)

        MOV     R1, # -1                        ; initialise the distances table to -1
        LDR     R2, = ( colourmax * colourmax * colourmax )
15
        SUBS    R2, R2, # 1                     ; decrease counter
        STRPL   R1, [ R0 ], #4                  ;   write initial value for distance
        BPL     %BT15                           ;   and loop...

        MOV     iColours, # 0
20
        CMP     iColours, # ?scratch_palette / 4
        BGE     %FT80

        ; Compute steps and build inverse table

        LDR     LR, [SP]
        LDR     LR, [ LR, iColours, LSL # 2 ]   ; pick up RGB value

        AND     rDist, LR, #&FF00
        MOV     rDist, rDist, LSR # 8
        MOV     rInc, rDist, LSL # nbits        ; rInc = rDist (r) << nBits
        RSB     rInc, rInc, # xsqr
        MOV     rInc, rInc, LSL # 1             ; rInc = 2 * ( xsqr - ( r << nbits ) )
        SUB     rDist, rDist, # x / 2           ; rDist = r - ( x / 2 )

        AND     gDist, LR, #&FF0000
        MOV     gDist, gDist, LSR # 16
        MOV     gInc, gDist, LSL # nbits        ; gInc = gDist (g) << nbits
        RSB     gInc, gInc, # xsqr
        MOV     gInc, gInc, LSL # 1             ; gInc = 2 * ( xsqr - ( g << nbits ) )
        SUB     gDist, gDist, # x / 2           ; gDist = g - ( x / 2 )

        MOV     bDist, LR, LSR # 24
        MOV     bInc, bDist, LSL # nbits        ; bInc = bDist (b) << nbits
        RSB     bInc, bInc, # xsqr
        MOV     bInc, bInc, LSL # 1             ; bInc = 2 * ( xsqr - ( b << nbits ) )
        SUB     bDist, bDist, # x / 2           ; bDist = b - ( x / 2 )

        MOV     scratch, bDist
        MUL     bDist, scratch, bDist           ; bDist  = ( bDist * bDist )
        MOV     scratch, gDist
        MLA     bDist, scratch, gDist, bDist    ; bDist += ( gDist * gDist )
        MOV     scratch, rDist
        MLA     bDist, scratch, rDist, bDist    ; bDist += ( rDist * rDist )

        ADR     R0, percent_table
        LDRB    R0, [ R0, iColours, LSR # 3 ]
        SWI     XHourglass_Percentage           ; set the hourglass percentage value

        MOV     b, #0                           ; b = 0

        LDR     pITable, [SP, #4]
        LDR     pDistances, pDistanceTable      ; -> distance table

blue_loop
        ; enable other time critical tasks to continue
        Push    "r0-r3, r12"
        BL      usermode_donothing
        Pull    "r0-r3, r12"
        ; and continue
        CMP     b, # colourmax                  ; finished the red loop
        ADDGE   iColours, iColours, # 1         ;   iColours += 4
        BGE     %BT20                           ;     and advance to the next colour

        MOV     gDist, bDist                    ; gDist = bDist
        MOV     g, #0                           ; g = 0

        Push    "gInc"

green_loop
        CMP     g, # colourmax                  ; finished the green loop
        BGE     end_green_loop

        MOV     rDist, gDist                    ; rDist = gDist
        MOV     r, # 0                          ; r = 0

        Push    "rInc"

red_loop
        CMP     r, # colourmax                  ; blue loop finished?
        BGE     end_red_loop

        TEQ     iColours, #0                    ; is this colour zero?
        STREQ   rDist, [ pDistances ]
        STREQB  iColours, [ pITable ]
        BEQ     %FT30

        LDR     LR, [ pDistances ]
        CMP     LR, rDist                       ; is it closer to this colour
        STRGT   rDist, [ pDistances ]
        STRGTB  iColours, [ pITable ]
30
        ADD     rDist, rDist, rInc              ; rDist += rInc
        ADD     r, r, # 1                       ; r++
        ADD     rInc, rInc, # xsqr * 2          ; rInc += xsqr * 2

        ADD     pITable, pITable, # 1           ; pITable += 1
        ADD     pDistances, pDistances, # 4     ; pDistances += 4

        B       red_loop

end_red_loop
        Pull    "rInc"

        ADD     gDist, gDist, gInc              ; gDist += gInc
        ADD     g, g, # 1                       ; g++
        ADD     gInc, gInc, # xsqr * 2          ; gInc += xsqr * 2

        B       green_loop

end_green_loop
        Pull    "gInc"

        ADD     bDist, bDist, bInc              ; bDist += bInc
        ADD     b, b, #1                        ; b++
        ADD     bInc, bInc, # xsqr * 2          ; bInc += xsqr * 2

        B       blue_loop

        ; Handle the exit conditions - removing temporary memory etc

80
        LDR     R0, iDynamicArea
        LDR     R1, = - ( ?da_iDistanceTable )
        SWI     XOS_ChangeDynamicArea           ; remove distance table from dynamic area
        CLRV
        EXIT

 [ UseResourceTable

StandardPalette
        DCW     &0000,&0842,&1084,&18C6
        DCW     &0008,&084A,&108C,&18CE
        DCW     &2000,&2842,&3084,&38C6
        DCW     &2008,&284A,&308C,&38CE
        DCW     &0011,&0853,&1095,&18D7
        DCW     &0019,&085B,&109D,&18DF
        DCW     &2011,&2853,&3095,&38D7
        DCW     &2019,&285B,&309D,&38DF
        DCW     &0100,&0942,&1184,&19C6
        DCW     &0108,&094A,&118C,&19CE
        DCW     &2100,&2942,&3184,&39C6
        DCW     &2108,&294A,&318C,&39CE
        DCW     &0111,&0953,&1195,&19D7
        DCW     &0119,&095B,&119D,&19DF
        DCW     &2111,&2953,&3195,&39D7
        DCW     &2119,&295B,&319D,&39DF
        DCW     &0220,&0A62,&12A4,&1AE6
        DCW     &0228,&0A6A,&12AC,&1AEE
        DCW     &2220,&2A62,&32A4,&3AE6
        DCW     &2228,&2A6A,&32AC,&3AEE
        DCW     &0231,&0A73,&12B5,&1AF7
        DCW     &0239,&0A7B,&12BD,&1AFF
        DCW     &2231,&2A73,&32B5,&3AF7
        DCW     &2239,&2A7B,&32BD,&3AFF
        DCW     &0320,&0B62,&13A4,&1BE6
        DCW     &0328,&0B6A,&13AC,&1BEE
        DCW     &2320,&2B62,&33A4,&3BE6
        DCW     &2328,&2B6A,&33AC,&3BEE
        DCW     &0331,&0B73,&13B5,&1BF7
        DCW     &0339,&0B7B,&13BD,&1BFF
        DCW     &2331,&2B73,&33B5,&3BF7
        DCW     &2339,&2B7B,&33BD,&3BFF
        DCW     &4400,&4C42,&5484,&5CC6
        DCW     &4408,&4C4A,&548C,&5CCE
        DCW     &6400,&6C42,&7484,&7CC6
        DCW     &6408,&6C4A,&748C,&7CCE
        DCW     &4411,&4C53,&5495,&5CD7
        DCW     &4419,&4C5B,&549D,&5CDF
        DCW     &6411,&6C53,&7495,&7CD7
        DCW     &6419,&6C5B,&749D,&7CDF
        DCW     &4500,&4D42,&5584,&5DC6
        DCW     &4508,&4D4A,&558C,&5DCE
        DCW     &6500,&6D42,&7584,&7DC6
        DCW     &6508,&6D4A,&758C,&7DCE
        DCW     &4511,&4D53,&5595,&5DD7
        DCW     &4519,&4D5B,&559D,&5DDF
        DCW     &6511,&6D53,&7595,&7DD7
        DCW     &6519,&6D5B,&759D,&7DDF
        DCW     &4620,&4E62,&56A4,&5EE6
        DCW     &4628,&4E6A,&56AC,&5EEE
        DCW     &6620,&6E62,&76A4,&7EE6
        DCW     &6628,&6E6A,&76AC,&7EEE
        DCW     &4631,&4E73,&56B5,&5EF7
        DCW     &4639,&4E7B,&56BD,&5EFF
        DCW     &6631,&6E73,&76B5,&7EF7
        DCW     &6639,&6E7B,&76BD,&7EFF
        DCW     &4720,&4F62,&57A4,&5FE6
        DCW     &4728,&4F6A,&57AC,&5FEE
        DCW     &6720,&6F62,&77A4,&7FE6
        DCW     &6728,&6F6A,&77AC,&7FEE
        DCW     &4731,&4F73,&57B5,&5FF7
        DCW     &4739,&4F7B,&57BD,&5FFF
        DCW     &6731,&6F73,&77B5,&7FF7
        DCW     &6739,&6F7B,&77BD,&7FFF
 ]

      [ standalone
msg_area
        ResourceFile    $MergedMsgs, Resources.ITable.Messages
        DCD     0
      ]
      [ debug
        InsertNDRDebugRoutines
      ]

        END
