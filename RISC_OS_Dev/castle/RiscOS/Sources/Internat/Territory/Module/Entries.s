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
; Sources.Entries

;--------------------------------------------------------
Alphabet
        Debug   xx,"Territory : Alphabet entry"

        MOV     r0,#AlphNum
        MOV     PC,LR

;--------------------------------------------------------
AlphabetIdent
        Debug   xx,"Territory : AlphabetIdentifier entry"

        ADR     r0,Alphabet_IdentString
        MOV     PC,LR

Alphabet_IdentString

        DCB     "$AlphabetName",0
        ALIGN


;--------------------------------------------------------
SelectKeyboardHandler

        Push    "r0-r2,LR"

        MOV     r0,#OsByte_Alphabet
        MOV     r1,#128+TerrNum
        SWI     XOS_Byte
        STRVS   r0,[SP]

        Pull    "r0-r2,PC"

;--------------------------------------------------------
WriteDirection

        MOV     r0,#WriteDir
        MOV     PC,LR

;--------------------------------------------------------
IME

        LDR     r0,=IMESWIChunk
        MOV     PC,LR

;--------------------------------------------------------


CharacterPropertyTable

        TEQ     r1,#Property_Control
        ADREQL  r0,ControlTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Uppercase
        ADREQL  r0,UppercaseTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Lowercase
        ADREQL  r0,LowercaseTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Alpha
        ADREQL  r0,AlphaTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Punctuation
        ADREQL  r0,PunctuationTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Space
        ADREQL  r0,SpaceTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Digit
        ADREQL  r0,DigitTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_XDigit
        ADREQL  r0,XDigitTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_Accented
        ADREQL  r0,AccentedTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_ForwardFlow
        ADREQL  r0,ForwardFlowTable
        MOVEQ   PC,LR
        TEQ     r1,#Property_BackwardFlow
        ADREQL  r0,BackwardFlowTable
        MOVEQ   PC,LR

        ADR     r0,ErrorBlock_UnknownProperty
        B       message_errorlookup

ErrorBlock_UnknownProperty
        DCD     TerritoryError_UnknownProperty
        DCB     "UnkProp",0
        ALIGN

;--------------------------------------------------------
GetLowerCaseTable

        ADRL    r0,ToLowerTable
        MOV     PC,LR

;--------------------------------------------------------
GetUpperCaseTable

        ADRL    r0,ToUpperTable
        MOV     PC,LR

;--------------------------------------------------------
GetControlTable

        ADRL    r0,ToControlTable
        MOV     PC,LR

;--------------------------------------------------------
GetPlainTable

        ADRL    r0,ToPlainTable
        MOV     PC,LR

;--------------------------------------------------------
GetValueTable

        ADRL    r0,ToValueTable
        MOV     PC,LR

;--------------------------------------------------------
GetRepresentationTable

        ADRL    r0,ToRepresentationTable
        MOV     PC,LR

;--------------------------------------------------------
; Collate
;     Entry:
;             R1 -> String 1   (0 terminated)
;             R2 -> String 2   (0 terminated)
;             R3 = flags
;                        bit 0 - Ignore case.
;                        bit 1 - Ignore accents
;                        bit 2 - Interpret cardinals numerically
;     Exit:
;             R0   <0 if S1 < S2
;                  =0 if S1 = S2
;                  >0 if S1 > S2
;             Other registers preserved.
;
;             Z set if equal (EQ).
;             C set and Z clear if S1 > S2 (HI)
;             N set and V clear if S1 < S2 (LT)
;
;             V set if error.

Collate

        Push    "r1-r8,LR"

        MOV     r3, r3, LSL #16
        MOV     r3, r3, LSR #16

        ; We start off ignoring case and accents
        ORR     r3,r3,#Collate_IgnoreCase :OR: Collate_IgnoreAccent
        ADRL    r4,ToLowerTable
        ADRL    r5,ToPlainForCollateTable
        ADRL    r7,SortValueTable
        ADRL    r8,ToRepresentationTable
01
        LDRB    r12,[r1],#1
        LDRB    r6 ,[r2],#1


        Debug   xx,"r12,r6",r12,r6

 [ CollateDanishAA
        TEQ     r12,#'A'
        TEQNE   r12,#'a'
        TEQNE   r6, #'A'
        TEQNE   r6, #'a'
        BNE     %FT35

        TEQ     r12,#'A'
        TEQNE   r12,#'a'
        BNE     %FT33           ; r6 must be an A/a
        LDRB    r0, [r1]
        TEQ     r0, r12
        BEQ     %FT31
        TEQ     r12,#'A'
        TEQEQ   r0,#'a'
        BNE     %FT32
31
        TEQ     r12,#'A'        ; Got aa, Aa or AA.
        MOVEQ   r12,#'�'
        MOVNE   r12,#'�'
        ADD     r1, r1, #1

32
        TEQ     r6,#'A'
        TEQNE   r6,#'a'
        BNE     %FT35
33      LDRB    r0, [r2]
        TEQ     r0, r6
        BEQ     %FT34
        TEQ     r6,#'A'
        TEQEQ   r0,#'a'
        BNE     %FT35
34
        TEQ     r6,#'A'         ; Got aa, Aa or AA.
        MOVEQ   r6,#'�'
        MOVNE   r6,#'�'
        ADD     r2, r2, #1
35
 ]
        TST     r3,#Collate_InterpretCardinals
        BEQ     %FT37
        MOV     r0,r12
        BL      is_digit
        MOVEQ   r0,r6
        BLEQ    is_digit
        BEQ     %FT60           ; Both are digits
37
        TST     r3,#Collate_IgnoreAccent
        LDRNEB  r12,[r5,r12]
        LDRNEB  r6 ,[r5,r6]

        Debug   xx,"r12,r6",r12,r6

        TST     r3,#Collate_IgnoreCase
        LDRNEB  r12,[r4,r12]
        LDRNEB  r6 ,[r4,r6]

        Debug   xx,"r12,r6",r12,r6

 [ CollateLatin1Ligatures
        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        TEQNE   r6, #'�'
        TEQNE   r6, #'�'
        BNE     %FT05

        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        BNE     %FT03           ; r6 must be a ligature
        EOR     r3, r3, #&20000000
        TST     r3, #&20000000
        MOVNE   r12, #'f'
        SUBNE   r1, r1, #1
        BNE     %FT02
        TEQ     r12, #'�'
        MOVEQ   r12, #'i'
        MOVNE   r12, #'l'

02      TEQ     r6,#'�'
        TEQNE   r6,#'�'
        BNE     %FT05
03      EOR     r3, r3, #&10000000
        TST     r3, #&10000000
        MOVNE   r6, #'f'
        SUBNE   r2, r2, #1
        BNE     %FT05
        TEQ     r6, #'�'
        MOVEQ   r6, #'i'
        MOVNE   r6, #'l'
05
 ]

 [ CollateOELigatures
        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        TEQNE   r6, #'�'
        TEQNE   r6, #'�'
        BNE     %FT15

        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        BNE     %FT13           ; r6 must be a ligature
        EOR     r3, r3, #&08000000
        TST     r3, #&08000000
        BEQ     %FT11
        SUB     r1, r1, #1
        TEQ     r12,#'�'
        MOVEQ   r12,#'O'
        MOVNE   r12,#'o'
        B       %FT12
11      TEQ     r12,#'�'
        MOVEQ   r12,#'E'
        MOVNE   r12,#'e'

12      TEQ     r6,#'�'
        TEQNE   r6,#'�'
        BNE     %FT15
13      EOR     r3, r3, #&04000000
        TST     r3, #&04000000
        BEQ     %FT14
        SUB     r2, r2, #1
        TEQ     r6,#'�'
        MOVEQ   r6,#'O'
        MOVNE   r6,#'o'
        B       %FT15
14      TEQ     r6,#'�'
        MOVEQ   r6,#'E'
        MOVNE   r6,#'e'
15
 ]

 [ CollateThornAsTH
        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        TEQNE   r6, #'�'
        TEQNE   r6, #'�'
        BNE     %FT25

        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        BNE     %FT23           ; r6 must be a thorn
        EOR     r3, r3, #&02000000
        TST     r3, #&02000000
        BEQ     %FT21
        SUB     r1, r1, #1
        TEQ     r12,#'�'
        MOVEQ   r12,#'T'
        MOVNE   r12,#'t'
        B       %FT22
21      TEQ     r12,#'�'
        MOVEQ   r12,#'H'
        MOVNE   r12,#'h'

22      TEQ     r6,#'�'
        TEQNE   r6,#'�'
        BNE     %FT25
23      EOR     r3, r3, #&01000000
        TST     r3, #&01000000
        BEQ     %FT24
        SUB     r1, r1, #1
        TEQ     r6,#'�'
        MOVEQ   r6,#'T'
        MOVNE   r6,#'t'
        B       %FT25
24      TEQ     r6,#'�'
        MOVEQ   r6,#'H'
        MOVNE   r6,#'h'
25
 ]

 [ CollateGermanSharpS
        TEQ     r12, #'�'
        EOREQS  r3, r3, #&00800000
        TST     r3, #&00800000
        MOVNE   r12, #'s'
        SUBNE   r1, r1, #1

        TEQ     r6, #'�'
        EOREQS  r3, r3, #&00400000
        TST     r3, #&00400000
        MOVNE   r6, #'s'
        SUBNE   r2, r2, #1
 ]

        LDRB    r12,[r7,r12]
        LDRB    r6 ,[r7,r6]

        Debug   xx,"r12,r6",r12,r6

        SUBS    r0,r12,r6
        Pull    "r1-r8,PC",NE           ; Not equal, result is result of compare.
        TEQ     r12,#0
        BNE     %BT01                   ; Equal but not 0, get next char.
30      LDR     r12,[sp,#8]             ; Get original flags
        EORS    r12,r3,r12
        Pull    "r1-r8,PC",EQ           ; Done desired comparison - they're equal

 [ :LNOT:CollateAccentsBackwards
        LDMIA   sp,{r1,r2}              ; Restore string pointers
 ]

        TST     r12,#Collate_IgnoreAccent ; Do they want us to differ accents?
        BICNE   r3,r3,#Collate_IgnoreAccent
 [ CollateAccentsBackwards
        BNE     %FT40

        LDMIA   sp,{r1,r2}
 |
        BNE     %BT01                   ; Back to the top, doing accents this time.
 ]

        BIC     r3,r3,#Collate_IgnoreCase ; Already obeying accent directive, so
        B       %BT01                   ; must be disobeying case - check case.

 [ CollateAccentsBackwards
40
; At this point the strings have just compared equal when ignoring case and
; accents. We are about to go around again, looking at accents this time. But
; the important point is that we must scan the string backwards. This is only
; required for French as far as I know, so for now, the following assertions
; will simplify things.

        ASSERT :LNOT: CollateThornAsTH
        ASSERT :LNOT: CollateDanishAA

; We know that the two strings must be of equivalent length, so as we rewind,
; r1 and r2 will hit the start simultaneously (as long as there's nothing
; really bizarre about the ToPlainForCollate table, such as ToPlain(f)='�').

        LDR     r5, [sp,#0]             ; get back start of first string
41
        LDRB    r12,[r1,#-1]!
        LDRB    r6 ,[r2,#-1]!

        LDRB    r12,[r4,r12]            ; We must be ignoring case at this point
        LDRB    r6 ,[r4,r6]

      [ CollateLatin1Ligatures
        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        TEQNE   r6, #'�'
        TEQNE   r6, #'�'
        BNE     %FT45

        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        BNE     %FT43           ; r6 must be a ligature
        EOR     r3, r3, #&20000000
        TST     r3, #&20000000
        MOVEQ   r12, #'f'
        BEQ     %FT42
        ADD     r1, r1, #1
        TEQ     r12, #'�'
        MOVEQ   r12, #'i'
        MOVNE   r12, #'l'

42      TEQ     r6,#'�'
        TEQNE   r6,#'�'
        BNE     %FT45
43      EOR     r3, r3, #&10000000
        TST     r3, #&10000000
        MOVEQ   r6, #'f'
        BEQ     %FT45
        ADD     r2, r2, #1
        TEQ     r6, #'�'
        MOVEQ   r6, #'i'
        MOVNE   r6, #'l'
45
      ]

      [ CollateOELigatures
        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        TEQNE   r6, #'�'
        TEQNE   r6, #'�'
        BNE     %FT55

        TEQ     r12,#'�'
        TEQNE   r12,#'�'
        BNE     %FT53           ; r6 must be a ligature
        EOR     r3, r3, #&08000000
        TST     r3, #&08000000
        BNE     %FT51
        TEQ     r12,#'�'
        MOVEQ   r12,#'O'
        MOVNE   r12,#'o'
        B       %FT52
51      TEQ     r12,#'�'
        MOVEQ   r12,#'E'
        MOVNE   r12,#'e'
        ADD     r1, r1, #1

52      TEQ     r6,#'�'
        TEQNE   r6,#'�'
        BNE     %FT55
53      EOR     r3, r3, #&04000000
        TST     r3, #&04000000
        BNE     %FT54
        TEQ     r6,#'�'
        MOVEQ   r6,#'O'
        MOVNE   r6,#'o'
        B       %FT55
54      TEQ     r6,#'�'
        MOVEQ   r6,#'E'
        MOVNE   r6,#'e'
        ADD     r2, r2, #1
55
      ]

        LDRB    r12,[r7,r12]
        LDRB    r6 ,[r7,r6]

        SUBS    r0,r12,r6
        Pull    "r1-r8,PC",NE           ; Not equal, result is result of compare.
        CMP     r1, r5                  ; are we now pointing at the start of the string?
        BNE     %BT41                   ; no, so get next character
        B       %BT30                   ; finished this pass - they're equal. Back to normal processing.
 ]
60
; Cardinal compare algorithm (ignores sign, decimal point & exponents)
; * Skip leading zeros in both numbers
; * Count length of both numbers
; * If equal length, just do strcmp()
; * If different length, longest wins
        Push    "r1-r2,r4-r5"

        MOV     r0,r12
61      BL      is_zero
        LDREQB  r0,[r1],#1
        BEQ     %BT61
        SUB     r4,r1,#1                ; First non '0'
62      BL      is_digit
        LDREQB  r0,[r1],#1
        BEQ     %BT62                   ; Is a digit

        MOV     r0,r6
63      BL      is_zero
        LDREQB  r0,[r2],#1
        BEQ     %BT63
        SUB     r5,r2,#1                ; First non '0'
64      BL      is_digit
        LDREQB  r0,[r2],#1
        BEQ     %BT64                   ; Is a digit

        SUB     r1,r1,r4                ; Lengths
        SUB     r2,r2,r5
        SUBS    r0,r1,r2
        LDREQB  r12,[r4],#1
        LDREQB  r6 ,[r5],#1
        STMEQIA sp,{r4-r5}

        Pull    "r1-r2,r4-r5"

        BEQ     %BT37                   ; Carry on collating from that digit
        Pull    "r1-r8,PC"              ; We have a winner

is_digit ROUT
        ; R0 = char, R8 -> representation table
        ; Returns Z=1 if char is entry 0-9 in the table
        Push    "r1,lr"
        MOV     r1,#9
10      LDRB    r14,[r8,r1]
        TEQ     r14,r0
        Pull    "r1,PC",EQ
        SUBS    r1,r1,#1
        BPL     %BT10
        Pull    "r1,PC"                 ; R1 -ve, therefore also NE
is_zero
        Push    "r1,lr"
        MOV     r1,#0
        B       %BT10

; ------------------------------------------------------------------------
; ReadTimeZones
;
; In:
;       IF R4 = 'ZONE'
;          R1 = timezone to lookup, 0 to NumberOfTZ - 1
;
; Out:
;       R0 -> name of standard TZ if this territory was in use
;       R1 -> name of summer TZ if this territory was in use
;       R2 = Offset from UTC to standard time
;       R3 = Offset from UTC to summer time.
;       IF R4 = 'ZONE' on entry, R4 = 0
;
ReadTimeZones
        LDR     r0, =ReadTimeZones_Extension
        TEQ     r0, r4
        MOVNE   r1, #0                  ; Behave as no extension
        MOVEQ   r4, #0                  ; Denote extension is supported

        CMP     r1, #NumberOfTZ
        ADRCS   r0,ErrorBlock_NoMoreZones
        BCS     message_errorlookup

        GBLA    tz_aligned
        GBLA    tz_tableentry
tz_aligned      SETA ((MaxTZLength + 1) + 3) :AND: :NOT: 3
tz_tableentry   SETA (tz_aligned * 2) + 4 + 4
        ADR     r0, tz_table
        MOV     r3, #tz_tableentry
        MLA     r0, r1, r3, r0
        ADD     r1, r0, #tz_aligned
        LDR     r2, [r0, #0 + (2 * tz_aligned)]
        LDR     r3, [r0, #4 + (2 * tz_aligned)]
        MOV     pc, lr

ErrorBlock_NoMoreZones
        DCD     TerritoryError_NoMoreZones
        DCB     "NMZones",0
        ALIGN

tz_table
        GBLA    counter
        GBLS    suffix
        GBLS    strstd
        GBLS    strdst
        GBLS    offstd
        GBLS    offdst
        WHILE   counter < NumberOfTZ
      [ counter >= 16
suffix    SETS  :STR:counter:RIGHT:2
      |
suffix    SETS  :STR:counter:RIGHT:1
      ]
strstd  SETS    "NODST":CC:suffix
strdst  SETS    "DST":CC:suffix
offstd  SETS    "NODSTOffset":CC:suffix
offdst  SETS    "DSTOffset":CC:suffix
        DCB     $strstd, 0
        SPACE   tz_aligned - 1 - :LEN:$strstd
        DCB     $strdst, 0
        SPACE   tz_aligned - 1 - :LEN:$strdst
        DCD     $offstd
        DCD     $offdst
counter SETA    counter + 1
        WEND

; ------------------------------------------------------------------------
; ReadSymbols
;
; In:
;       R1 - Reason code:
;               0 Return pointer to 0 terminated decimal point string.
;               1 Return pointer to 0 terminated thousands separator
;               2 Return pointer byte list containing the size of each
;                 group of digits in formatted nonmonetary quantities.
;                 255   = No further grouping
;                   0   = Repeat last grouping for rest of number
;                 other = Size of current group, the next byte contains
;                         the size of the next group of dogits before the
;                          current group.
;               3 Return pointer to 0 terminated international currency symbol.
;               4 Return pointer to 0 terminated currency symbol in local alphabet.
;               5 Return pointer to 0 terminated decimal point used for monetary quantities
;               6 Return pointer to 0 terminated thousands separator for monetary quantities
;               7 Return pointer byte list containing the size of each
;                 group of digits in formatted monetary quantities.
;               8 Return pointer to 0 terminated positive sign used for monetary quantities
;               9 Return pointer to 0 terminated negative sign used for monetary quantities
;              10 Return number of fractional digits to be displayed in an internationally
;                 formatted monetay quantity
;              11 Return number of fractional digits to be displayed in a formatted monetay
;                 quantity
;              12 Return 1 If the currency symbol precedes the value for a nonnegative
;                          formatted monetary quantity
;                        0 If the currency symbol succeeds the value for a nonnegative
;                          formatted monetary quantity
;              13 Return 1 If the currency symbol is separated by a space from the value for a
;                          nonnegative formatted monetary quantity
;                        0 If the currency symbol is not separated by a space from the value for a
;                          nonnegative formatted monetary quantity
;              14 Return 1 If the currency symbol precedes the value for a negative
;                          formatted monetary quantity
;                        0 If the currency symbol succeeds the value for a negative
;                          formatted monetary quantity
;              15 Return 1 If the currency symbol is separated by a space from the value for a
;                          negative formatted monetary quantity
;                        0 If the currency symbol is not separated by a space from the value for a
;                          negative formatted monetary quantity
;
;              16 Return for a nonnegative formatted monetary quantity
;                        0 If there are parentheses arround the quantity and currency symbol.
;                        1 If the sign string precedes the quantity and currency symbol.
;                        2 If the sign string succeeds the quantity and currency symbol.
;                        3 If the sign string immediately precedes the currency symbol.
;                        4 If the sign string immediately succeeds the currency symbol.
;              17 Return for a negative formatted monetary quantity
;                        0 If there are parentheses arround the quantity and currency symbol.
;                        1 If the sign string precedes the quantity and currency symbol.
;                        2 If the sign string succeeds the quantity and currency symbol.
;                        3 If the sign string immediately precedes the currency symbol.
;                        4 If the sign string immediately succeeds the currency symbol.
;              18 Return pointer to 0 terminated list separator
; Out:
;       R0 - Requested value.
ReadSymbols
        Push    "LR"

        ADR     R14,SymbolTable
        LDR     R0,[R14,R1,ASL #2]
        CMP     R0,#20
        ADDGE   R0,R0,R14

        Pull    "PC"

SymbolTable
        DCD     decimal_point           - SymbolTable
        DCD     thousands_sep           - SymbolTable
        DCD     grouping                - SymbolTable
        DCD     int_curr_symbol         - SymbolTable
        DCD     currency_symbol         - SymbolTable
        DCD     mon_decimal_point       - SymbolTable
        DCD     mon_thousands_sep       - SymbolTable
        DCD     mon_grouping            - SymbolTable
        DCD     positive_sign           - SymbolTable
        DCD     negative_sign           - SymbolTable
        DCD     int_frac_digits
        DCD     frac_digits
        DCD     p_cs_precedes
        DCD     p_sep_by_space
        DCD     n_cs_precedes
        DCD     n_sep_by_space
        DCD     p_sign_posn
        DCD     n_sign_posn
        DCD     list_symbol             - SymbolTable

decimal_point           DCB     "$Decimal",0
thousands_sep           DCB     "$Thousand",0
grouping                DCB     $Grouping
int_curr_symbol         DCB     "$IntCurr",0
currency_symbol         DCB     "$Currency",0
mon_decimal_point       DCB     "$MDecimal",0
mon_thousands_sep       DCB     "$MThousand",0
mon_grouping            DCB     $MGrouping
positive_sign           DCB     "$MPositive",0
negative_sign           DCB     "$MNegative",0
list_symbol             DCB     "$ListSymbol",0
        ALIGN

;---------------------------------------------------------------------------------
;ReadCalendarInformation
;
;In:
;   R1 = Pointer to 5 byte UTC time value.
;   R2 = Pointer to a 12 word buffer
;
;Out:
;
;   R1,R2 Preserved.
;
;   [R2+0]  = Number of first working day in the week.
;   [R2+4]  = Number of last working day in the week.
;   [R2+8]  = Number of months in the current year.
;             (current = one in which given time falls)
;   [R2+12] = Number of days in the current month.
;             (current = one in which given time falls)
;   [R2+16] = Max length of AM/PM string.
;   [R2+20] = Max length of WE string.
;   [R2+24] = Max length of W3 string.
;   [R2+28] = Max length of DY string.
;   [R2+32] = Max length of ST string (May be 0).
;   [R2+36] = Max length of MO string.
;   [R2+40] = Max length of M3 string.
;   [R2+44] = Max length of TZ string.
;
GetCalendarInformation
        Push    "r0-r11,LR"

        ADR     LR,CalendarInfo
        LDMIA   LR,{R0,R3-R11,LR}       ; Load fixed 11 items
        STMIA   R2!,{R0,R3,R4}          ; First three
        STMIB   R2,{R5-R11,LR}          ; Skip one, then next 8

        SWI     XTerritory_ReadCurrentTimeZone
        BVS     %FT02

        MOV     R2,R1
        LDR     R1,[SP,#1*4]
        BL      GetTimeValues

        ADRL    R0,MonthLengths
        LDRB    R0,[R0,R1]              ; Get length of month
        CMP     R1,#2                   ; Is Feb ?
        BNE     %FT01

        TST     R6, #3                  ; is year multiple of 4
        MOVNE   R0,#28                  ; no, then 29 Feb is bad
        BNE     %FT01

        TEQ     R6, #0                  ; is it a century year ?
        BNE     %FT01                   ; no, then 29 Feb is good

        TST     R5, #3                  ; is it a multiple of 400 ?
        MOVNE   R0,#28                  ; no, then 29 Feb is bad
01
        LDR     R2,[SP,#2*4]
        STR     R0,[R2,#12]
02
        STRVS   r0,[SP]
        Pull    "r0-r11,PC"

CalendarInfo
        DCD     FirstWorkDay    ; First working day in week 1=Sunday 7=Saturday
        DCD     LastWorkDay     ; Last  working day in week 1=Sunday 7=Saturday
        DCD     NumberOfMonths  ; Number of month in a year

        DCD     MaxAMPMLength   ; Max length of AM PM String
        DCD     MaxWELength     ; Max length of full day name
        DCD     MaxW3Length     ; Max length of short day name
        DCD     MaxDYLength     ; Max length of day in month
        DCD     MaxSTLength     ; Max length of st nd rd th ... string
        DCD     MaxMOLength     ; Max length of full month name.
        DCD     MaxM3Length     ; Max length of short month name.
        DCD     MaxTZLength     ; Max length of time zone name.

;---------------------------------------------------------------------------------
;NameToNumber
;
;In:
;   R1 = Pointer to territory name.
;
;Out:
;   R0 = 0 - Unknown territory
;        Else territory number.
NameToNumber     ROUT
        Entry   "r1-r7",8               ; We know tokens aren't long.

        BL      open_messages_file

; Enumerate all territory name tokens (TRnn)
        ADR     r0,message_file_block
        MOV     R4,#0                   ; First call
        ADR     R7,ToLowerTable

01
        ADR     R1,territory_token
        MOV     R2,SP
        MOV     R3,#8
        SWI     XMessageTrans_EnumerateTokens
        EXIT    VS
        CMP     R2,#0
        MOVEQ   r0,#0
        EXIT    EQ

; Get Message

        DebugS  xx,"Next token is ",R2
        MOV     R1,R2                   ; Token.
        MOV     R2,#0                   ; Don't copy message !
        SWI     XMessageTrans_Lookup
        EXIT    VS

; Got message, now compare with territory name in string.

        LDR     R1,[SP,#8]              ; get user R1
02
        LDRB    R14,[R2],#1
        CMP     R14,#10
        BEQ     %FT03                   ; End of message
        LDRB    R14,[R7,R14]            ; Lower case

        LDRB    R10,[R1],#1
        CMP     R10,#0
        MOVEQ   r0,#0
        EXIT    EQ
        LDRB    R10,[R7,R10]            ; Lower case

        CMP     R14,R10
        BEQ     %BT02                   ; Try next character.
        B       %BT01                   ; Try next token.
03
        LDRB    R10,[R1],#1
        CMP     R10,#" "
        BGE     %BT01                   ; Not end of user input !

        MOV     R0,#10                  ; Check token number
        ADD     R1,SP,#2
        SWI     XOS_ReadUnsigned
        MOVVC   R0,R2
        EXIT

territory_token
        DCB     "TR*",0
        ALIGN

        LNK     Tables.s

