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
; > adfs::TimSource.!Inter.InterBody

; ************************************************************
; ***    C h a n g e   L i s t  (better late than never!)  ***
; ************************************************************

; Date       Description
; ----       -----------
; 16-Mar-88  Set UseWriteN option, removed "(WriteN version)" in module help
;            string, changed service code so it could be reassembled now that
;            Inter_Highest has changed.
; 28-Apr-88  Message compression technology added (involving splitting into
;            two versions)
; 04-May-88  Fixed bug in service code which stopped the DefineFont service
;            being claimed, due to SWI OS_WriteN call using R1.
; 11-May-88  Added *Alphabets, *Countries
; 12-May-88  Compressed "*Alphabets" in *Alphabet help
; 09-Sep-88  Removed ' supported' from *Alphabets and *Countries
;            Added Canada1, Canada2, Canada, ISO1
;            Apostrophe now vertical in Latin1-4, Greek
;            Currency symbol now a windmill in Latin1-4
; 27-Nov-89  Added GET <Hdr>.File, so it assembles again
;            (no change to object code)
; 31-Jan-90  Added first iteration of Cyrillic (ISO) and Cyrillic2 (IBM) alphabets
; 01-Feb-90  Added DBell corrections to Cyrillic(2) characters.
; 05-Mar-90  Added Hebrew alphabet / country Israel (26).
; 20-Jun-91  TMD Changed <Hdr> to Hdr:
; 08-Jul-91  ECN Message extraction
; 04-Oct-91  TMD Fixed bug G-RR-2396 - character &B9 in Latin3 (Turkish i)
;                 should not have dot
;            TMD Added Acorn extensions (characters &8C to &9F) to Latin1-4.
; 10-Oct-91  OSS Added country Mexico.
; 18-Nov-91  OSS Added country LatinAm. Also note that the Mexican Risc OS 2
;            version of this module is version 1.15, even though there
;            has been a different 1.15 in the past.
; 19-Feb-92  TMD 1.20: corrected characters &FB, &FD in Greek font (bug G-RR-2358)
;                      added Welsh characters to Latin1
; 19-Feb-92  TMD 1.21: removed use of <Hdr> in make sequence
; 19-Feb-92  TMD 1.22: removed use of <Hdr> from IntHelpBod as well!
; 21-Apr-92  RM  1.23: corrected Hebrew Final Zade character
; 22-Apr-92  TMD 1.24: removed wild cards from message filename
; 23-Apr-93  ECN 1.25: Added Austria, Belgium, Japan, MiddleEast, Netherlands
;                      Fixed � (Latin1 - char 252)
; 31-May-94  AMcC Removed quotes from GET $HelpFile
; 15-May-95  SMC 1.27: Made standalone versions possible.
; 11-Jul-97  KJB 1.30: Removed Arthur and WriteN flags. Added Dvorak(UK,USA,LH,RH)
;                      and Turkey
; 16-Jul-97  KJB 1.31: Added Wales2 and defined Welsh alphabet. Added Latin5 & Latin6.
;                      New chars: W/w diaeresis, W/w/Y/y grave.
; 17-Jul-97            Added draft Latin8 (Celtic). New chars: B,D,F,M,P,S,T (both
;                      cases) with dot above. Redrew ENG and eng.
; 15-Aug-97            Renamed characters to ISO10646 identifiers.
;                      Fixed Latin2 character &D2 - was Ntilde instead of Ncaron.
;                      Fixed Latin2 character &A9 - was scaron instead of Scaron.
;                      Fixed Latin2 character &BE - was Zcaron instead of zcaron.
;                      Made Greek characters &A1 and &A2 into more obvious quotes.
;                      Fixed Greek character &AC - was macron instead of not sign.
;                      Made accented lower case Greek characters more like normal
;                      ones, rather than just borrowing Latin glyphs.
;                      Redrew "caron" to make it more distinct from "breve".
; 18-Aug-97            Made accented "z"s distinct from accented "Z"s by scrunging
;                      them down to 4 pixels (cf accented "o"s).
;                      Made various circumflexed characters (eg y^) use a broader
;                      hat to match the original Latin1 set. Made Ocirc use a
;                      narrow hat to stop it being indistinguishable from Uring
;                      (compare acirc).
;                      Redrew many accented characters (see the comments about
;                      the NewAccents flag below).
;                      Added Latin7 and Latin9 - still need work.
; 07-Apr-98            Bracketed out Latin7/8/9. Removed DvorakLH and RH.
; 31-Jul-98  KJB 1.50: Removed Bfont and Cyrillic2 (partly because Bfont is hard
;                      to describe in terms of the UCS, and partly because
;                      they're obsolete).
;                      Added pseudo-chars for UTF8.
;                      Now supports Service_International 8 (Inter_UCSTable)
; 19-Oct-98  KJB 1.51: Changed to cope with new Hdr:CMOS.
; 05-Aug-99  KJB 1.52: Service call table added.
; 14-Sep-99  KJB 1.53: New characters added to Greek, as per ISO 8859 revision.
; 16-Sep-99  KJB 1.54: Latin7 and Latin8 added. New characters added to
;                      Hebrew, as per ISO 8859 revision.
; 28-Apr-00  KJB 1.55: Module made 32-bit compatible.
; 08-Jun-00  KJB 1.56: Alphabet for Turkey changed to Latin5.
; 21-Nov-00  SBF 1.59: Taught module about China, Brazil and South Africa (English-speaking territory)
; 19-Oct-01  KJB 1.62: Added Korea.

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:CMOS
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Proc
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:MsgTrans
        GET     Hdr:ResourceFS
        GET     Hdr:Countries
        GET     Hdr:CPU.Arch
        GET     hdr.Internatio
        GET     VersionASM

        AREA    |International$$Code|, CODE, READONLY, PIC

  [ :LNOT: :DEF: standlone
        GBLL    standalone
standalone SETL {FALSE}
  ]
  [ :LNOT: :DEF: international_help
        GBLL    international_help
international_help SETL {TRUE}        
  ]
  
; Use the new-style accented characters (taller base characters
; wherever possible and more consistent accents, on the basis
; that each accented form should try and fit in with the surrounding
; text and look as similar as possible to its unaccented form rather
; than trying to looking neat in !Chars next to all the other
; accented chars).

        GBLL    NewAccents
NewAccents SETL {TRUE}

        GBLL    DoUTF8
DoUTF8  SETL    {TRUE}

        GBLL    DoBfont
DoBfont SETL    {FALSE}

TAB     *       9
LF      *       10
FF      *       12
CR      *       13

OsbyteSetCountry * &46
OsbyteSetAlphKey * &47

NameBufferSize * 16     ; no countries that long

        GBLA    TableAddress
        GBLS    TableName

        MACRO
$label  InterTable $name
$label
TableAddress SETA $label-Module_BaseAddr
TableName SETS "$name"
        MEND

        MACRO
        InterEntry $value, $name
        [ "$name"<> "UNK001"
        DCW     ($TableName.$name-Module_BaseAddr-TableAddress):AND:&FFFF
        DCB     ($TableName.$name-Module_BaseAddr-TableAddress):SHR:16
        DCB     $value
        ]
        MEND

        MACRO
        InterEnd
        DCD     0
        MEND

        ^       0, wp

MessageFile_Block #     16              ; File handle for MessageTrans
MessageFile_Open  #     4               ; Opened message file flag

Inter_WorkspaceSize * :INDEX: @

; **************** Module code starts here **********************

Module_BaseAddr

        DCD     0
        DCD     Inter_Init    -Module_BaseAddr
        DCD     Inter_Die     -Module_BaseAddr
        DCD     Inter_Service -Module_BaseAddr
        DCD     Inter_Title   -Module_BaseAddr
        DCD     Inter_HelpStr -Module_BaseAddr
        DCD     Inter_HC_Table-Module_BaseAddr
        DCD     0
        DCD     0
        DCD     0
        DCD     0
 [ international_help
        DCD     message_filename - Module_BaseAddr
 |
        DCD     0
 ]
        DCD     Inter_Flags   -Module_BaseAddr

Inter_Title
        DCB     "International", 0

Inter_HelpStr
        DCB     "International", TAB, "$Module_HelpVersion"
      [ standalone
        DCB     " standalone"
      ]
        DCB     0
        ALIGN

Inter_Flags
        DCD     ModuleFlag_32bit

Inter_HC_Table
      [ international_help
        Command Alphabet,  1, 0, International_Help
        Command Country,   1, 0, International_Help
        Command Keyboard,  1, 0, International_Help
        Command Country,   0, 0, Status_Keyword_Flag :OR: International_Help, ConCountry
        Command Alphabets, 0, 0, International_Help
        Command Countries, 0, 0, International_Help
      |
        Command Alphabet,  1, 0, 0
        Command Country,   1, 0, 0
        Command Keyboard,  1, 0, 0
        Command Country,   0, 0, Status_Keyword_Flag, ConCountry
        Command Alphabets, 0, 0, 0
        Command Countries, 0, 0, 0
      ]
        DCD     0
        GET     TokHelpSrc.s


; *****************************************************************************


Inter_Init
        Push    "lr"

        LDR     r2, [r12]               ; Hard or soft init ?
        TEQ     r2, #0
        BNE     %FT00

; Hard init

        LDR     r3, =Inter_WorkspaceSize
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        Pull    "pc", VS

        STR     r2, [r12]

00      MOV     r12, r2

        MOV     r14, #0
        STR     r14, MessageFile_Open

 [ standalone
        ADR     r0, ResourceFiles
        SWI     XResourceFS_RegisterFiles
 ]

        ADDS    r0, r0, #0              ; clear V
        Pull    "pc"

Inter_Die
        Push    "lr"
        LDR     r12, [r12]
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        ADRNE   r0, MessageFile_Block
        SWINE   XMessageTrans_CloseFile

 [ standalone
        ADR     r0, ResourceFiles
        SWI     XResourceFS_DeregisterFiles
 ]

        ADDS    r0, r0, #0              ; clear V
        Pull    "pc"

; *****************************************************************************
;
;       Alphabets_Code - Process *ALPHABETS command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

Alphabets_Code Entry
        LDR     r12, [r12]
        ADRL    R0, AlphabetsString     ; R0 -> "Alphabets",0
        MOV     R2, #Inter_ANoToANa
        BL      PrintInfo
        EXIT

AlphabetsString
        DCB     "M06", 0

; *****************************************************************************
;
;       Countries_Code - Process *COUNTRIES command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

Countries_Code Entry
        LDR     r12, [r12]
        ADRL    R0, CountriesString     ; R0 -> "Countries",0
        MOV     R2, #Inter_CNoToCNa
        BL      PrintInfo
        EXIT

CountriesString
        DCB     "M07", 0

; *****************************************************************************
;
;       PrintInfo - Print list of alphabets/countries
;
; in:   R0 -> string to print first
;       R2 = international service sub-reason code
;

InfoBufferSize * 512

PrintInfo ROUT
        Push    R14
        BL      message_write0
        SWIVC   XOS_WriteS
        =       ":", 10, 13, 0
        ALIGN
        Pull    PC, VS
        SUB     R6, R13, #1                     ; buffer limit (allow for term)
        SUB     R13, R13, #InfoBufferSize       ; allocate buffer on stack
        MOV     R4, R13                         ; start of buffer
        MOV     R3, #0                          ; country number starts at zero
10
        SUBS    R5, R6, R4                      ; R5 = buffer length
        BCC     %FT20                           ; [buffer full]
        BL      OfferInterService               ; offer service
        MOVEQ   R1, #TAB                        ; if claimed, store TAB after
        STREQB  R1, [R4, R5]!                   ; string, then move on one more
        ADDEQ   R4, R4, #1                      ; to skip TAB character

        ADD     R3, R3, #1                      ; try next number
        EORS    R0, R3, #128                    ; do 0..127 (R0 := 0 at end)
        BNE     %BT10
20
        STREQB  R0, [R4, #-1]                   ; put zero terminator on string
        MOV     R0, R13
        SWI     XOS_PrettyPrint                 ; print out buffer
        SWIVC   XOS_NewLine
        ADD     R13, R13, #InfoBufferSize       ; junk buffer
        Pull    PC

; *****************************************************************************
;
;       Alphabet_Code - Process *ALPHABET command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

Alphabet_Code Entry
        LDR     r12, [r12]
        TEQ     R1, #0                  ; just *ALPHABET ?
        BNE     %FT10                   ; [no, so a setting of alphabet]

; print current alphabet to screen

        MOV     R1, #&7F                ; indicate just read alphabet
        MOV     R3, #Inter_ANoToANa     ; for later

; and drop thru to ...

PrintAValue                             ; used by *ALPHABET and *KEYBOARD
        MOV     R0, #OsbyteSetAlphKey
PrintAValue2                            ; used by *COUNTRY
        SWI     XOS_Byte
        EXIT    VS

; R1 = current alphabet/country number

        MOV     R2, R3                  ; appropriate reason code
        MOV     R3, R1                  ; alphabet/country no. in R3
PrintAValue3
        SUB     R13, R13, #NameBufferSize ; make room for name buffer
        MOV     R4, R13                 ; R4 -> buffer
        MOV     R5, #NameBufferSize-1
        BL      OfferInterService
        STREQB  R1, [R4, R5]            ; if claimed, terminate name with zero
        MOVEQ   R0, R4                  ; R0 -> string
        ADRNE   R0, UnknownString       ; else print unknown
        BNE     PrintAValue4
        SWI     XOS_Write0
        B       PrintAValue5
PrintAValue4
        BL      message_write0
PrintAValue5
        SWIVC   XOS_NewLine
        ADD     R13, R13, #NameBufferSize ; restore stack pointer
        EXIT

UnknownString
        =       "M03", 0
        ALIGN

; set alphabet from name pointed to by R0

10
        MOV     R3, R0                  ; R3 -> name
        MOV     R2, #Inter_ANaToANo     ; try an alphabet name first
        BL      OfferInterService

; if not an alphabet name, try a country name

        MOVNE   R2, #Inter_CNaToCNo     ; is it a country name ?
        BLNE    OfferInterService
        BNE     DoAlphabetError

; now R4 = alphabet number or country number

        MOV     R1, R4
        MOV     R0, #OsbyteSetAlphKey
        SWI     XOS_Byte
        EXIT

DoAlphabetError
        ADR     R0, AlphabetError
        BL      CopyError
        EXIT

AlphabetError MakeInternatErrorBlock UnknownAlphabet,,M00

; *****************************************************************************
;
;       Keyboard_Code - Process *KEYBOARD command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

Keyboard_Code Entry
        LDR     r12, [r12]
        TEQ     R1, #0                  ; just *KEYBOARD ?
        BNE     %FT10                   ; [no, so a setting of keyboard]

; print current keyboard to screen

        MOV     R1, #&FF                ; indicate just read keyboard
        MOV     R3, #Inter_CNoToCNa     ; for later
        B       PrintAValue

; set keyboard from name pointed to by R0

10
        MOV     R3, R0                  ; R3 -> name
        MOV     R2, #Inter_CNaToCNo     ; only allow country names
        BL      OfferInterService
        BNE     DoKeyboardError         ; unknown keyboard

; now R4 = alphabet number

        ORR     R1, R4, #&80            ; top bit set => set keyboard
        MOV     R0, #OsbyteSetAlphKey
        SWI     XOS_Byte
        EXIT

DoKeyboardError
        ADR     R0, KeyboardError
        BL      CopyError
        EXIT

KeyboardError MakeInternatErrorBlock UnknownKeyboard,,M01

; *****************************************************************************
;
;       Country_Code - Process *COUNTRY command
;
; in:   R0 -> rest of line
;       R1 = number of parameters
;
; out:  R0-R6, R12 corrupted
;

Country_Code Entry
        LDR     r12, [r12]
        TEQ     R1, #0                  ; just *COUNTRY ?
        BNE     %FT10                   ; [no, so a setting of country]

; print current country to screen

        MOV     R1, #&7F                ; indicate just read keyboard
        MOV     R3, #Inter_CNoToCNa     ; for later
        MOV     R0, #OsbyteSetCountry
        B       PrintAValue2

; set country from name pointed to by R0

10
        MOV     R3, R0                  ; R3 -> name
        MOV     R2, #Inter_CNaToCNo     ; only allow country names
        BL      OfferInterService
        BNE     DoCountryError          ; unknown keyboard

; now R4 = country number

        MOV     R1, R4                  ; country number to set
        MOV     R0, #OsbyteSetCountry
        SWI     XOS_Byte
        EXIT

DoCountryError
        ADR     R0, CountryError
        BL      CopyError
        EXIT

CountryError MakeInternatErrorBlock UnknownCountry,,M02


; *****************************************************************************

OfferInterService
        Push    R14
        MOV     R1, #Service_International
        SWI     XOS_ServiceCall
        TEQ     R1, #0                  ; NB preserves V
        Pull    PC

; *****************************************************************************
;
;       ConCountry_Code - Handle *CONFIGURE and *STATUS
;
; in:   R0 = 0 => *Configure nowt
;       R0 = 1 => *Status
;       R0 > 1 => R0 -> command tail
;
; out:  V=0 => ok
;       V=1 => error
;               R0 = 0 => Bad Configure Option error
;               R0 = 1 => Numeric Parameter Needed
;               R0 = 2 => Configure parameter too big
;               R0 = 3 => R0 -> error block
;

ConCountry_Code Entry
        LDR     r12, [r12]
        CMP     R0, #1
        BEQ     %FT10                   ; *Status
        BHI     %FT20                   ; *Configure Country something

; *Configure nowt

        BL      message_writes
        =       "M04", 0
        SWIVC   XOS_NewLine
        EXIT

space4  DCB     "    ", 0
        ALIGN

; *Status

10
        MOV     R0, #&A1                ; read from CMOS RAM
        MOV     R1, #CountryCMOS
        SWI     XOS_Byte
        EXIT    VS

        BL      message_writes
        =       "M05", 0
        ADRVC   r0, space4
        SWIVC   XOS_Write0
        EXIT    VS

        MOV     R3, R2                  ; R3 = configured country number
        MOV     R2, #Inter_CNoToCNa
        B       PrintAValue3

; *Configure Country <country name>

20
        MOV     R3, R0                  ; R3 -> name
        MOV     R2, #Inter_CNaToCNo     ; only allow country names
        BL      OfferInterService
        BNE     DoCountryError          ; unknown keyboard

; now R4 = country number

        MOV     R2, R4
        MOV     R0, #&A2                ; write to CMOS RAM
        MOV     R1, #CountryCMOS
        SWI     XOS_Byte
        EXIT

 [ standalone
ResourceFiles
        ResourceFile    Resources.UK.Messages,  Resources.Internatio.Messages
        DCD     0
 ]

; *****************************************************************************
;
;       Inter_Service - Main entry point for services
;
; in:   R1 = service reason code
;       R2 = sub reason code
;       R3-R5 parameters
;
; out:  R1 = 0 if we claimed it
;       R2 preserved
;       R3-R5 = ???
;

;Ursula format
;
        ASSERT  Service_International < Service_ResourceFSStarting
;
Inter_UServTab
        DCD     0
        DCD     Inter_UService - Module_BaseAddr
        DCD     Service_International
  [ standalone
        DCD     Service_ResourceFSStarting
  ]
        DCD     0
        DCD     Inter_UServTab - Module_BaseAddr
Inter_Service ROUT
        MOV     r0,r0
        TEQ     R1, #Service_International
  [ standalone
        TEQNE   r1,#Service_ResourceFSStarting
  ]
        MOVNE   PC,LR
Inter_UService
 [ standalone
        TEQ     R1, #Service_ResourceFSStarting
        BNE     %FT10
        Push    "lr"
        ADR     r0, ResourceFiles
        MOV     lr, pc
        MOV     pc, r2
        Pull    "pc"
10
 ]
; we know it's Service_International if we get here
        CMP     R2, #Inter_Highest      ; is it one we know ?
        ADDCC   PC, PC, R2, LSL #2      ; yes, go thru despatch
        MOV     PC, R14                 ; no, then exit

        B       DoCNaToCNo
        B       DoANaToANo
        B       DoCNoToCNa
        B       DoANoToANa
        B       DoCNoToANo
        B       DoDefine
        MOV     PC, R14                 ; new keyboard service is ignored by us
        B       DoDefineUCS
        B       DoUCSTable
        B       DoCNoToAlpha2           ; ISO3166-1 Alpha2

; *****************************************************************************
;
;       DoDefine - Define a set of chars from a particular alphabet
;
; in:   R3 = alphabet number
;       R4 = min char to define
;       R5 = max char to define
;

DoDefine Entry "R0,R2,R3,R4,R5,R6,R7"
 [ DoUTF8
        TEQ     R3, #ISOAlphabet_UTF8
        BEQ     DoDefineUTF8
05
 ]
        ADR     R6, FontPointers
        BL      LookupNumber
        TEQ     R1, #0
        EXIT    NE

; R7 now points to start of pointers for this font

 [ {TRUE}
        CMP     R5, #&FF                ; Restrict range to &20-&FF
        MOVHI   R5, #&FF
        CMP     R4, #&20
        MOVLO   R4, #&20

        CMP     R4, R5
        EXIT    HI

        MOV     R3, R4

10      CMP     R3, R5
        BHI     %FT20
        LDR     R4, [R7, R3, LSL #2]    ; look it up in the UCS tables
        TEQ     R4, #&0000007F
        MOVEQ   R4, #&00002500          ; delete = solid block
        ORREQ   R4, R4, #&0088
        CMP     R4, #&00000020
        BLGE    DoDefineUCS             ; signed comparison - don't define < &20 or -ve (ie &FFFFFFFF)
        ADDVC   R3, R3, #1
        BVC     %BT10
20
        EXIT

 |
        MOV     R6, R7                  ; save base pointer
10
        LDR     R0, [R7], #4            ; load data word
        TEQ     R0, #0                  ; end of table ?
        EXIT    EQ
        CMP     R5, R0, LSR #24         ; test if table char > max char
        EXIT    CC                      ; if so then finished
        CMP     R4, R0, LSR #24         ; test if table char < min char
        BHI     %BT10                   ; loop if so

; we have found a valid char to define

        SWI     XOS_WriteI+23
        BICVC   R2, R0, #&FF000000      ; R2 = offset to font bytes
        MOVVC   R0, R0, LSR #24         ; R0 = char to define
        SWIVC   XOS_WriteC
        ADDVC   R0, R2, R6              ; R0 now points to 8 bytes of font
        MOVVC   R1, #8
        SWIVC   XOS_WriteN
        MOV     R1, #0                  ; set R1 back to zero ALWAYS!
        BVC     %BT10
        EXIT
 ]

 [ DoUTF8
DoDefineUTF8
        CMP     R5,#&80
        BLO     %BT05                   ; if all chars are < &80, nothing special to do.
        CMP     R4, #&80
        MOVLS   R2, #&80                ; only do from &80 upwards here.
        MOVHI   R2, R4

        SUB     R13, R13, #8            ; reserve 8-bytes of stack space for character
20
        CMP     R2, R5                  ; have we finished?
        BHI     %FT30

; need to define "character" R2

        ADR     R6, Digits
        AND     R0, R2, #&0F
        ADD     R14, R6, R0, LSL #2
        ADD     R14, R14, R0            ; R14 -> 5-byte array defining lower digit
        AND     R0, R2, #&F0
        ADD     R6, R6, R0, LSR #2
        ADD     R6, R6, R0, LSR #4      ; R6 -> 5-byte array defining upper digit
        ; row 0
        LDRB    R0, [R14, #0]
        ;CMP     R2, #&C0
        ;ORRHS   R0, R0, #&E0            ; mark starter bytes
        STRB    R0, [R13, #0]
        ; row 1
        LDRB    R0, [R14, #1]
        ;ORRHS   R0, R0, #&80
        STRB    R0, [R13, #1]
        ; row 2
        LDRB    R0, [R14, #2]
        STRB    R0, [R13, #2]
        ; row 3
        LDRB    R0, [R14, #3]
        LDRB    R7, [R6, #0]
        ORR     R0, R0, R7, LSL #4
        STRB    R0, [R13, #3]
        ; row 4
        LDRB    R0, [R14, #4]
        LDRB    R7, [R6, #1]
        ORR     R0, R0, R7, LSL #4
        STRB    R0, [R13, #4]
        ; row 5
        LDRB    R7, [R6, #2]
        MOV     R0, R7, LSL #4
        STRB    R0, [R13, #5]
        ; row 6
        LDRB    R7, [R6, #3]
        MOV     R0, R7, LSL #4
        STRB    R0, [R13, #6]
        ; row 7
        LDRB    R7, [R6, #4]
        MOV     R0, R7, LSL #4
        STRB    R0, [R13, #7]

; now issue the VDU 23 sequence

        SWI     XOS_WriteI + 23
        MOVVC   R0, R2
        SWIVC   XOS_WriteC
        MOVVC   R0, R13
        MOVVC   R1, #8
        SWIVC   XOS_WriteN
        ADDVC   R2, R2, #1
        BVC     %BT20

        ADD     R13, R13, #8
        EXIT                            ; return if an error

30      ADD     R13, R13, #8
        CMP     R4, #&80                ; return if all chars >= &80
        EXIT    HS

        MOV     R3, #ISOAlphabet_Latin1
        CMP     R5, #&80                ; go back and do chars &20-&7F
        MOVHS   R5, #&7F
        B       %BT05

Digits  = &6,&9,&9,&9,&6
        = &2,&6,&2,&2,&2
        = &6,&1,&2,&4,&7
        = &6,&1,&6,&1,&6
        = &5,&5,&7,&1,&1
        = &7,&4,&6,&1,&6
        = &6,&8,&E,&9,&6
        = &7,&1,&2,&4,&4
        = &6,&9,&6,&9,&6
        = &6,&9,&7,&1,&6
        = &6,&9,&F,&9,&9
        = &E,&9,&E,&9,&E
        = &6,&9,&8,&9,&6
        = &E,&9,&9,&9,&E
        = &F,&8,&E,&8,&F
        = &F,&8,&E,&8,&8
        ALIGN
 ]

FontPointers InterTable
 [ DoBfont
        InterEntry ISOAlphabet_Bfont,    Bfont
 ]
        InterEntry ISOAlphabet_Latin1,   Latin1
        InterEntry ISOAlphabet_Latin2,   Latin2
        InterEntry ISOAlphabet_Latin3,   Latin3
        InterEntry ISOAlphabet_Latin4,   Latin4
        InterEntry ISOAlphabet_Cyrillic, Cyrillic
        InterEntry ISOAlphabet_Greek,    Greek
        InterEntry ISOAlphabet_Hebrew,   Hebrew
        InterEntry ISOAlphabet_Latin5,   Latin5
        InterEntry ISOAlphabet_Welsh,    Welsh
        InterEntry ISOAlphabet_Latin9,   Latin9
        InterEntry ISOAlphabet_Latin6,   Latin6
        InterEntry ISOAlphabet_Latin7,   Latin7
        InterEntry ISOAlphabet_Latin8,   Latin8
        InterEntry ISOAlphabet_Latin10,  Latin10
 [ DoBfont
        InterEntry Alphabet_Cyrillic2,   Cyrillic2
 ]
        InterEnd

; *****************************************************************************
;
;       DoDefineUCS - Define a character from the ISO 10646 Universal
;                     Character Set (UCS)
;
; in:   R3 = character in system font to redefine
;       R4 = UCS character number (00000000 - 7FFFFFFF)
;
; out:  service call claimed if character defined
;

DoDefineUCS
        CMP     R4, #&10000
        MOVHS   PC, LR

        Entry   "R0,R2,R6"
        ADRL    R6, UCSTable

5       LDMIA   R6!, {R0, R2}
        CMP     R4, R0
        EXIT    LO
        CMP     R4, R2
        BLS     %F10

        SUB     R2, R2, R0
        ADD     R2, R2, #2
        BIC     R2, R2, #1
        ADD     R6, R6, R2, LSL #1
        B       %B5

10      SUB     R4, R4, R0
        ; Load an unsigned halfword from the array
        LDHA    R4, R6, R4, R6
        TST     R4, #&8000
        EXIT    NE
        ADRL    R6, FontTable
        SWI     XOS_WriteI+23
        MOVVC   R0, R3
        SWIVC   XOS_WriteC
        ADDVC   R0, R6, R4
        MOVVC   R1, #8
        SWIVC   XOS_WriteN

        MOV     R1, #0
        EXIT

; *****************************************************************************
;
;       DoUCSTable - Return UCS mapping table for alphabet number
;
; in:   R3 = alphabet number
;
; out:  R4 = pointer to UCS table
;       R1 = 0 if recognised
;

DoUCSTable Entry "R0,R6,R7"
        ADR     R6, FontPointers
        BL      LookupNumber
        TEQ     R1, #0
        MOVEQ   R4, R7
        EXIT

; *****************************************************************************
;
;       DoCNoToANo - Convert country number to alphabet number
;
; in:   R3 = country number
;
; out:  R4 = alphabet number
;       R1 = 0 if recognised
;

DoCNoToANo Entry "R0,R2"
        ADR     R2, CToATable
10
        LDRB    R0, [R2], #2
        TEQ     R0, #0
        EXIT    EQ
        TEQ     R0, R3
        BNE     %BT10

        LDRB    R4, [R2, #-1]
        MOV     R1, #0
        EXIT

CToATable
        =       TerritoryNum_UK,        ISOAlphabet_Latin1
 [ DoBfont
        =       TerritoryNum_Master,    ISOAlphabet_Bfont
        =       TerritoryNum_Compact,   ISOAlphabet_Bfont
 ]
        =       TerritoryNum_Italy,     ISOAlphabet_Latin1
        =       TerritoryNum_Spain,     ISOAlphabet_Latin1
        =       TerritoryNum_France,    ISOAlphabet_Latin9
        =       TerritoryNum_Germany,   ISOAlphabet_Latin1
        =       TerritoryNum_Portugal,  ISOAlphabet_Latin1
        =       TerritoryNum_Esperanto, ISOAlphabet_Latin3
        =       TerritoryNum_Greece,    ISOAlphabet_Greek
        =       TerritoryNum_Sweden,    ISOAlphabet_Latin1
        =       TerritoryNum_Finland,   ISOAlphabet_Latin1
        =       TerritoryNum_Denmark,   ISOAlphabet_Latin1
        =       TerritoryNum_Norway,    ISOAlphabet_Latin1
        =       TerritoryNum_Iceland,   ISOAlphabet_Latin1
        =       TerritoryNum_Canada1,   ISOAlphabet_Latin9
        =       TerritoryNum_Canada2,   ISOAlphabet_Latin1
        =       TerritoryNum_Canada,    ISOAlphabet_Latin1
        =       TerritoryNum_Turkey,    ISOAlphabet_Latin5
        =       TerritoryNum_Ireland,   ISOAlphabet_Latin1
        =       TerritoryNum_Russia,    ISOAlphabet_Cyrillic
 [ DoBfont
        =       TerritoryNum_Russia2,   Alphabet_Cyrillic2
 ]
        =       TerritoryNum_Israel,    ISOAlphabet_Hebrew
        =       TerritoryNum_Mexico,    ISOAlphabet_Latin1
        =       TerritoryNum_LatinAm,   ISOAlphabet_Latin1
        =       TerritoryNum_Australia, ISOAlphabet_Latin1
        =       TerritoryNum_Austria,   ISOAlphabet_Latin1
        =       TerritoryNum_Belgium,   ISOAlphabet_Latin1
        =       TerritoryNum_Japan,     ISOAlphabet_UTF8
        =       TerritoryNum_MiddleEast,ISOAlphabet_Latin1 ; Don't ask me
        =       TerritoryNum_Netherland,ISOAlphabet_Latin1
        =       TerritoryNum_Switzerland,ISOAlphabet_Latin1
        =       TerritoryNum_Wales,     ISOAlphabet_Latin1
        =       TerritoryNum_USA,       ISOAlphabet_Latin1
        =       TerritoryNum_Wales2,    ISOAlphabet_Welsh
        =       TerritoryNum_China,     ISOAlphabet_UTF8
        =       TerritoryNum_Korea,     ISOAlphabet_UTF8
        =       TerritoryNum_Taiwan,    ISOAlphabet_UTF8
        =       TerritoryNum_Brazil,    ISOAlphabet_Latin1 ; "Wild" guess, since both Spanish and Portuguese use it
        =       TerritoryNum_SAfrica2,  ISOAlphabet_Latin1
        =       Keyboard_DvorakUK,      ISOAlphabet_Latin1
        =       Keyboard_DvorakUSA,     ISOAlphabet_Latin1
        =       ISOKeyboard_Latin1,     ISOAlphabet_Latin1
        =       ISOKeyboard_Latin2,     ISOAlphabet_Latin2
        =       ISOKeyboard_Latin3,     ISOAlphabet_Latin3
        =       ISOKeyboard_Latin4,     ISOAlphabet_Latin4
        =       ISOKeyboard_Cyrillic,   ISOAlphabet_Cyrillic
        =       ISOKeyboard_Greek,      ISOAlphabet_Greek
        =       ISOKeyboard_Hebrew,     ISOAlphabet_Hebrew
        =       ISOKeyboard_Latin5,     ISOAlphabet_Latin5
        =       0
        ALIGN

; *****************************************************************************
;
;       DoCNaToCNo - Convert country name to country number
;
; in:   R3 -> name
;
; out:  R4 = number
;       R1 = 0 if recognised
;

DoCNaToCNo Entry "R0,R2,R5,R6"
        ADR     R6, CountryStrings
ConvertNameToNumber
10
        MOV     R2, R3
        LDRB    R0, [R6], #1            ; get char from table
        TEQ     R0, #0                  ; if zero then end of table
        EXIT    EQ
20
        LDRB    R5, [R2], #1
        CMP     R5, #" "
        BLS     %FT50                   ; end of search name, so no match
        TEQ     R5, #"."
        BEQ     %FT40                   ; abbreviated
        EOR     R5, R5, R0
        BICS    R5, R5, #&20
        BNE     %FT50                   ; no match
        LDRB    R0, [R6], #1
        TEQ     R0, #0
        BNE     %BT20

; end of table name

        LDRB    R5, [R2]
        CMP     R5, #" "                ; if not end of search name
        BHI     %FT55                   ; then no match (and we're already
                                        ; pointing to byte after 0 in our
                                        ; table)
        B       %FT60

40
        LDRB    R0, [R6], #1
        TEQ     R0, #0
        BNE     %BT40
60
        LDRB    R4, [R6], #1            ; R4 = number
        MOV     R1, #0
        EXIT

; no match, so skip to end of this table name

50
        LDRB    R0, [R6], #1
        TEQ     R0, #0
        BNE     %BT50
55
        ADD     R6, R6, #1              ; move to first char of new name
        B       %BT10

; *****************************************************************************
;
;       DoANaToANo - Convert alphabet name to alphabet number
;
; in:   R3 -> name
;
; out:  R4 = number
;       R1 = 0 if recognised
;

DoANaToANo ALTENTRY
        ADRL    R6, AlphabetStrings
        B       ConvertNameToNumber

; *****************************************************************************
;
;       DoCNoToCNa - Convert country number to country name
;
; in:   R3 = number
;       R4 -> buffer for name
;       R5 = buffer size
;
; out:  R1 = 0 if recognised
;

DoCNoToCNa Entry "R0,R6,R7"
        ADR     R6, CountryList
10
        BL      LookupNumber
        TEQ     R1, #0
        BLEQ    CopyName
        EXIT

; *****************************************************************************
;
;       DoANoToANa - Convert alphabet number to alphabet name
;
; in:   R3 = number
;       R4 -> buffer for name
;       R5 = buffer size
;
; out:  R1 = 0 if recognised
;

DoANoToANa ALTENTRY
        ADR     R6, AlphabetList
        BNE     %BT10

; *****************************************************************************
;
;       DoCNoToAlpha2 - Convert country number to ISO3166-1 alpha2 code
;
; in:   R3 = number
;       R4 -> buffer for name
;       R5 = buffer size
;
; out:  R1 = 0 if recognised
;

DoCNoToAlpha2 Entry "R6,R7"
        CMP     R3, #100                ; Max country
        EXIT    CS
        ADRL    R6, Alpha2Strings
        LDHA    R7, R6, R3, R14         ; R7 := two letter string

        MOV     R14, R7, LSR #8
        TEQ     R14, #' '               ; Two letters, but one was a space? Must be unknown
        EXIT    EQ

        CMP     R5, #1                  ; Need 2 byte buffer really
        STRCSB  R7, [R4, #0]
        STRHIB  R14,[R4, #1]
        MOVHI   R5, #2
        MOV     R1, #0
        EXIT

; *****************************************************************************

CountryList InterTable String
        InterEntry      TerritoryNum_Default,     Default
        InterEntry      TerritoryNum_UK,          UK
 [ DoBfont
        InterEntry      TerritoryNum_Master,      Master
        InterEntry      TerritoryNum_Compact,     Compact
 ]
        InterEntry      TerritoryNum_Italy,       Italy
        InterEntry      TerritoryNum_Spain,       Spain
        InterEntry      TerritoryNum_France,      France
        InterEntry      TerritoryNum_Germany,     Germany
        InterEntry      TerritoryNum_Portugal,    Portugal
        InterEntry      TerritoryNum_Esperanto,   Esperanto
        InterEntry      TerritoryNum_Greece,      Greece
        InterEntry      TerritoryNum_Sweden,      Sweden
        InterEntry      TerritoryNum_Finland,     Finland
        InterEntry      TerritoryNum_Denmark,     Denmark
        InterEntry      TerritoryNum_Norway,      Norway
        InterEntry      TerritoryNum_Iceland,     Iceland
        InterEntry      TerritoryNum_Canada1,     Canada1
        InterEntry      TerritoryNum_Canada2,     Canada2
        InterEntry      TerritoryNum_Canada,      Canada
        InterEntry      TerritoryNum_Turkey,      Turkey
        InterEntry      TerritoryNum_Ireland,     Ireland
        InterEntry      TerritoryNum_Russia,      Russia
 [ DoBfont
        InterEntry      TerritoryNum_Russia2,     Russia2
 ]
        InterEntry      TerritoryNum_Israel,      Israel
        InterEntry      TerritoryNum_Mexico,      Mexico
        InterEntry      TerritoryNum_LatinAm,     LatinAm
        InterEntry      TerritoryNum_Australia,   Australia
        InterEntry      TerritoryNum_Austria,     Austria
        InterEntry      TerritoryNum_Belgium,     Belgium
        InterEntry      TerritoryNum_Japan,       Japan
        InterEntry      TerritoryNum_MiddleEast,  MiddleEast
        InterEntry      TerritoryNum_Netherland,  Netherland
        InterEntry      TerritoryNum_Switzerland, Switzerland
        InterEntry      TerritoryNum_Wales,       Wales
        InterEntry      TerritoryNum_Wales2,      Wales2
        InterEntry      TerritoryNum_USA,         USA
        InterEntry      TerritoryNum_China,       China
        InterEntry      TerritoryNum_Brazil,      Brazil
        InterEntry      TerritoryNum_SAfrica2,    SAfrica2
        InterEntry      TerritoryNum_Korea,       Korea
        InterEntry      TerritoryNum_Taiwan,      Taiwan
        InterEntry      Keyboard_DvorakUK,        DvorakUK
        InterEntry      Keyboard_DvorakUSA,       DvorakUSA
        InterEntry      ISOKeyboard_Latin1,       ISO1
        InterEnd

AlphabetList InterTable String
 [ DoBfont
        InterEntry      ISOAlphabet_BFont,    Bfont
 ]
        InterEntry      ISOAlphabet_Latin1,   Latin1
        InterEntry      ISOAlphabet_Latin2,   Latin2
        InterEntry      ISOAlphabet_Latin3,   Latin3
        InterEntry      ISOAlphabet_Latin4,   Latin4
        InterEntry      ISOAlphabet_Cyrillic, Cyrillic
        InterEntry      ISOAlphabet_Greek,    Greek
        InterEntry      ISOAlphabet_Hebrew,   Hebrew
        InterEntry      ISOAlphabet_Latin5,   Latin5
        InterEntry      ISOAlphabet_Welsh,    Welsh
 [ DoUTF8
        InterEntry      ISOAlphabet_UTF8,     UTF8
 ]
        InterEntry      ISOAlphabet_Latin9,   Latin9
        InterEntry      ISOAlphabet_Latin6,   Latin6
        InterEntry      ISOAlphabet_Latin7,   Latin7
        InterEntry      ISOAlphabet_Latin8,   Latin8
        InterEntry      ISOAlphabet_Latin10,  Latin10
 [ DoBfont
        InterEntry      Alphabet_Cyrillic2,   Cyrillic2
 ]
        InterEnd

CountryStrings
StringDefault   =       "Default",0,    TerritoryNum_Default
StringUK        =       "UK",0,         TerritoryNum_UK
 [ DoBfont
StringMaster    =       "Master",0,     TerritoryNum_Master
StringCompact   =       "Compact",0,    TerritoryNum_Compact
 ]
StringItaly     =       "Italy",0,      TerritoryNum_Italy
StringSpain     =       "Spain",0,      TerritoryNum_Spain
StringFrance    =       "France",0,     TerritoryNum_France
StringGermany   =       "Germany",0,    TerritoryNum_Germany
StringPortugal  =       "Portugal",0,   TerritoryNum_Portugal
StringEsperanto =       "Esperanto",0,  TerritoryNum_Esperanto
StringGreece    =       "Greece",0,     TerritoryNum_Greece
StringSweden    =       "Sweden",0,     TerritoryNum_Sweden
StringFinland   =       "Finland",0,    TerritoryNum_Finland
StringDenmark   =       "Denmark",0,    TerritoryNum_Denmark
StringNorway    =       "Norway",0,     TerritoryNum_Norway
StringIceland   =       "Iceland",0,    TerritoryNum_Iceland
StringCanada1   =       "Canada1",0,    TerritoryNum_Canada1
StringCanada2   =       "Canada2",0,    TerritoryNum_Canada2
StringCanada    =       "Canada",0,     TerritoryNum_Canada
StringTurkey    =       "Turkey",0,     TerritoryNum_Turkey
StringIreland   =       "Ireland",0,    TerritoryNum_Ireland
StringRussia    =       "Russia",0,     TerritoryNum_Russia
 [ DoBfont
StringRussia2   =       "Russia2",0,    TerritoryNum_Russia2
 ]
StringIsrael    =       "Israel",0,     TerritoryNum_Israel
StringMexico    =       "Mexico",0,     TerritoryNum_Mexico
StringLatinAm   =       "LatinAm",0,    TerritoryNum_LatinAm
StringAustralia =       "Australia",0,  TerritoryNum_Australia
StringAustria   =       "Austria",0,    TerritoryNum_Austria
StringBelgium   =       "Belgium",0,    TerritoryNum_Belgium
StringJapan     =       "Japan",0,      TerritoryNum_Japan
StringMiddleEast =      "MiddleEast",0, TerritoryNum_MiddleEast
StringNetherland =      "Netherlands",0,TerritoryNum_Netherland
StringSwitzerland =     "Switzerland",0,TerritoryNum_Switzerland
StringWales     =       "Wales",0,      TerritoryNum_Wales
StringWales2    =       "Wales2",0,     TerritoryNum_Wales2
StringUSA       =       "USA",0,        TerritoryNum_USA
StringChina     =       "China",0,      TerritoryNum_China
StringBrazil    =       "Brazil",0,     TerritoryNum_Brazil
StringSAfrica2  =       "SAfrica",0,    TerritoryNum_SAfrica2
StringKorea     =       "Korea",0,      TerritoryNum_Korea
StringTaiwan    =       "Taiwan",0,     TerritoryNum_Taiwan
StringDvorakUK  =       "DvorakUK",0,   Keyboard_DvorakUK
StringDvorakUSA =       "DvorakUSA",0,  Keyboard_DvorakUSA
StringISO1      =       "ISO1",0,       ISOKeyboard_Latin1
                =       0
AlphabetStrings
 [ DoBfont
StringBfont     =       "Bfont",0,      ISOAlphabet_BFont
 ]
StringLatin1    =       "Latin1",0,     ISOAlphabet_Latin1
StringLatin2    =       "Latin2",0,     ISOAlphabet_Latin2
StringLatin3    =       "Latin3",0,     ISOAlphabet_Latin3
StringLatin4    =       "Latin4",0,     ISOAlphabet_Latin4
StringCyrillic  =       "Cyrillic",0,   ISOAlphabet_Cyrillic
StringGreek     =       "Greek",0,      ISOAlphabet_Greek
StringHebrew    =       "Hebrew",0,     ISOAlphabet_Hebrew
StringLatin5    =       "Latin5",0,     ISOAlphabet_Latin5
StringWelsh     =       "Welsh",0,      ISOAlphabet_Welsh
 [ DoUTF8
StringUTF8      =       "UTF8",0,       ISOAlphabet_UTF8
 ]
StringLatin9    =       "Latin9",0,     ISOAlphabet_Latin9
StringLatin6    =       "Latin6",0,     ISOAlphabet_Latin6
StringLatin7    =       "Latin7",0,     ISOAlphabet_Latin7
StringLatin8    =       "Latin8",0,     ISOAlphabet_Latin8
StringLatin10   =       "Latin10",0,    ISOAlphabet_Latin10
 [ DoBfont
StringCyrillic2 =       "Cyrillic2",0,  Alphabet_Cyrillic2
 ]
                =       0
        ALIGN

Alpha2Strings
        DCB     "  uk    itesfrdept  " ; Countries 0-9 (the UK uses 'uk' not its allocated 'gb')
        DCB     "grsefi  dknoiscacaca" ; Countries 10-19
        DCB     "tr  iehkruruilmx  au" ; Countries 20-29  
        DCB     "atbejp  nlchuk      " ; Countries 30-39
        DCB     "                usuk" ; Countries 40-49
        DCB     "cnbrzakrtw          " ; Countries 50-59
        DCB     "                    " ; Countries 60-69
        DCB     "ukus                " ; Countries 70-79
        DCB     "                    " ; Countries 80-89
        DCB     "                    " ; Countries 90-99
        ALIGN
        
LookupNumber ROUT
        MOV     R7, R6
10
        LDR     R0, [R7], #4            ; get next word
        TEQ     R0, #0                  ; 0 => end of table
        MOVEQ   PC, R14                 ; so didn't find it
        TEQ     R3, R0, LSR #24         ; does R3 match top byte of word ?
        BNE     %BT10                   ; no, so loop
        BIC     R0, R0, #&FF000000      ; knock out top byte
        ADD     R7, R0, R6              ; and add offset to base
        MOV     R1, #0                  ; indicate found
        MOV     PC, R14



CopyName ROUT
        MOV     R6, #0                  ; start at offset 0
10
        TEQ     R6, R5                  ; if not off limits
        LDRNEB  R0, [R7, R6]            ; load byte from source
        TEQNE   R0, #0
        STRNEB  R0, [R4, R6]            ; if non-zero store to dest
        ADDNE   R6, R6, #1              ; and increment offset
        BNE     %BT10                   ; then exit loop

        MOV     R5, R6                  ; R5 = number of chars put in buffer
        MOV     PC, R14

message_writes
        Entry   r0-r7
        RSB     r0, pc, pc
        SUB     r0, lr, r0
        MOV     r2, r0
10      LDRB    r1, [r2], #1
        CMP     r1, #0
        BNE     %B10
        SUB     r2, r2, r0
        ADD     r2, r2, #3
        BIC     r2, r2, #3
        ADD     lr, lr, r2
        STR     lr, [sp, #8 * 4]
        B       message_write0_tail

message_write0 Entry r0-r7
message_write0_tail
        BL      open_messagefile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r1, r0
        ADR     r0, MessageFile_Block
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_Lookup
        STRVS   r0, [sp]
        EXIT    VS
10      LDRB    r0, [r2], #1
        CMP     r0, #32
        SWICS   XOS_WriteC
        STRVS   r0, [sp]
        EXIT    VS
        BCS     %B10
        EXIT

CopyError Entry r1-r7
        BL      open_messagefile
        EXIT    VS
        MOV     R4, #0
CopyError0
        ADR     R1, MessageFile_Block
        MOV     R2, #0
        MOV     R5, #0
        MOV     R6, #0
        MOV     R7, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT

message_filename
        DCB     "Resources:$.Resources.Internatio.Messages", 0

        ALIGN

open_messagefile Entry r0-r2
        LDR     r0, MessageFile_Open
        CMP     r0, #0
        EXIT    NE
        ADR     R0, MessageFile_Block
        ADR     R1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        STRVS   r0, [sp]
        EXIT    VS
        MOV     r0, #1
        STR     r0, MessageFile_Open
        EXIT

        LNK     InterFonts.s
