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
;-----------------------------------------------------------------------------
; RISC OS Korean Territory
;-----------------------------------------------------------------------------

        GBLS    Help
Help    SETS    "Korean Terr'y"
;                |-------------|   maximum length

        GBLA    TerrNum
TerrNum SETA    TerritoryNum_$Territory

        GBLS    AlphabetName
AlphabetName SETS "UTF8"

        GBLA    AlphNum
AlphNum SETA    ISOAlphabet_$AlphabetName

        GBLA    WriteDir
WriteDir SETA   WriteDirection_LeftToRight :OR: \
                WriteDirection_UpToDown :OR: \
                WriteDirection_HorizontalLines

 [ :LNOT::DEF:KoreaIMESWI_Name
KoreaIMESWI_Base * &55B00
 ]

IMESWIChunk SETA KoreaIMESWI_Base

;-----------------------------------------------------------------------------
; Values for Territory_ReadCalendarInformation (PRM 3-839)
;-----------------------------------------------------------------------------

FirstWorkDay    *       2       ; Monday
LastWorkDay     *       6       ; Friday
NumberOfMonths  *      12

MaxAMPMLength   *       6       ; "오전"
MaxWELength     *       9       ; "일요일"
MaxW3Length     *       3       ; "일"
MaxDYLength     *       2       ; "31"
MaxSTLength     *       3       ; "일"
MaxMOLength     *       5       ; "12월"
MaxM3Length     *       5       ; "12월"
MaxTZLength     *       3       ; "KST"

;-----------------------------------------------------------------------------
; Values for Territory_ReadCurrentTimeZone (PRM 3-806)
;-----------------------------------------------------------------------------

NumberOfTZ      *       1

        GBLS    NODST0
NODST0  SETS    "KST"

        GBLS    DST0
DST0    SETS    "KST"

NODSTOffset0    *       100*60*60*9     ; Nine hours
DSTOffset0      *       100*60*60*9

;-----------------------------------------------------------------------------
; Settings for Territory_ConvertStandardDateAndTime,
; Territory_ConvertStandardDate and Territory_ConvertStandardTime (PRM 3-809)
;-----------------------------------------------------------------------------

        GBLS    DateFormat
DateFormat SETS "%ce%yr년 %m3 %zdy일"

        GBLS    TimeFormat
TimeFormat SETS "%z24:%mi:%se"

        GBLS    DateAndTime
DateAndTime SETS "$TimeFormat $DateFormat"

;-----------------------------------------------------------------------------
; Values for Territory_ReadSymbols (PRM 3-836)
;-----------------------------------------------------------------------------

                GBLS    Decimal
                GBLS    Thousand
                GBLS    Grouping
                GBLS    IntCurr
                GBLS    Currency
                GBLS    MDecimal
                GBLS    MThousand
                GBLS    MGrouping
                GBLS    MPositive
                GBLS    MNegative
                GBLS    ListSymbol

Decimal         SETS    "."             ; decimal point string
Thousand        SETS    ","             ; thousands separator
Grouping        SETS    "3,0"           ; digit grouping (non-monetary quantities)
IntCurr         SETS    "KRW "          ; international currency symbol
Currency        SETS    "₩"           ; currency symbol
MDecimal        SETS    "."             ; decimal point (monetary)
MThousand       SETS    " "             ; thousands separator (monetary)
MGrouping       SETS    "3,0"           ; digit grouping (monetary)
MPositive       SETS    ""              ; positive sign (monetary)
MNegative       SETS    "-"             ; negative sign (monetary)
int_frac_digits *       0               ; fractional digits (international monetary)
frac_digits     *       0               ; fractional digits (monetary)
p_cs_precedes   *       1               ; does currency symbol precede non-negative values?
p_sep_by_space  *       0               ; currency separated by a space from non-negative values?
n_cs_precedes   *       1               ; does currency symbol precede negative values?
n_sep_by_space  *       0               ; currency separated by a space from negative values?
p_sign_posn     *       1               ; position of positive sign string with currency symbol
n_sign_posn     *       1               ; position of negative sign string with currency symbol
ListSymbol      SETS    ";"             ; list separator


;-----------------------------------------------------------------------------
; Tables for Territory_CharacterPropertyTable (PRM 3-826)
;-----------------------------------------------------------------------------
;
; Basic point here is that as the Alphabet is UTF8, we musn't touch bytes
; 80-FF. Collation will work for ASCII - anything outside ASCII will be
; sorted into UCS order.
;
; Note that the binary numbers in the flag tables have to be read backwards.
; The table below should help in this:

                ; 10987654321098765432109876543210
                ; ?>=<;:9876543210/.-,+*)('&%$#"!
                ; _^]\[ZYXWVUTSRQPONMLKJIHGFEDCBA@
                ;  ~}|{zyxwvutsrqponmlkjihffedcba`
                ; ��������������������������������
                ; ��������������������������������
                ; ��������������������������������
                ; ��������������������������������

        MACRO
        DoUppercaseTable
UppercaseTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000111111111111111111111111110 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoLowercaseTable
LowercaseTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000111111111111111111111111110 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoAlphaTable
AlphaTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000111111111111111111111111110 ; @
        DCD     2_00000111111111111111111111111110 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoPunctuationTable
PunctuationTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_11111100000000001111111111111110 ; SP
        DCD     2_11111000000000000000000000000001 ; @
        DCD     2_01111000000000000000000000000001 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoSpaceTable
SpaceTable
        DCD     2_00000000000000000011111000000000 ; [00]
        DCD     2_00000000000000000000000000000001 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoAccentedTable
AccentedTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoForwardFlowTable
ForwardFlowTable
        DCD     2_11111111111111111111111111111111 ; [00]
        DCD     2_11111111111111111111111111111111 ; SP
        DCD     2_11111111111111111111111111111111 ; @
        DCD     2_11111111111111111111111111111111 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND
        MACRO
        DoBackwardFlowTable
BackwardFlowTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; [80]
        DCD     2_00000000000000000000000000000000 ; [A0]
        DCD     2_00000000000000000000000000000000 ; [C0]
        DCD     2_00000000000000000000000000000000 ; [E0]
        MEND

;-----------------------------------------------------------------------------
; Tables for Territory_LowerCaseTable etc (PRM 3-828 to 3-833)
;-----------------------------------------------------------------------------

   MACRO
   DoToLowerTable
ToLowerTable
   DCB     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    " ","!", 34,"#","$","%","&","'","(",")","*","+",",","-",".","/"
   DCB    "0","1","2","3","4","5","6","7","8","9",":",";","<","=",">","?"
   DCB    "@","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o"
   DCB    "p","q","r","s","t","u","v","w","x","y","z","[","\\","]","^","_"
   DCB    "`","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o"
   DCB    "p","q","r","s","t","u","v","w","x","y","z","{","|","}","~",127
   DCB    128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
   DCB    144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
   DCB    160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
   DCB    176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
   DCB    192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
   DCB    208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
   DCB    224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
   DCB    240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
   MEND

   MACRO
   DoToUpperTable
ToUpperTable
   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    " ","!", 34,"#","$","%","&","'","(",")","*","+",",","-",".","/"
   DCB    "0","1","2","3","4","5","6","7","8","9",":",";","<","=",">","?"
   DCB    "@","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O"
   DCB    "P","Q","R","S","T","U","V","W","X","Y","Z","[","\\","]","^","_"
   DCB    "`","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O"
   DCB    "P","Q","R","S","T","U","V","W","X","Y","Z","{","|","}","~",127
   DCB    128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
   DCB    144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
   DCB    160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
   DCB    176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
   DCB    192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
   DCB    208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
   DCB    224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
   DCB    240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
   MEND

   MACRO
   DoToControlTable
ToControlTable
   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    " ",  1, 34,  3,  4,  5,  7,"'",  9,  0,  8,"+",",", 31,".","/"
   DCB      0,  1,  0,  3,  4,  5, 30,  7,  8,  9,":",";","<","=",">","?"
   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    "`",  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,"~",127
   DCB    128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
   DCB    144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
   DCB    160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
   DCB    176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
   DCB    192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
   DCB    208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
   DCB    224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
   DCB    240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
   MEND

   MACRO
   DoToPlainTable
ToPlainTable
ToPlainForCollateTable
   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    " ","!", 34,"#","$","%","&","'","(",")","*","+",",","-",".","/"
   DCB    "0","1","2","3","4","5","6","7","8","9",":",";","<","=",">","?"
   DCB    "@","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O"
   DCB    "P","Q","R","S","T","U","V","W","X","Y","Z","[","\\","]","^","_"
   DCB    "`","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o"
   DCB    "p","q","r","s","t","u","v","w","x","y","z","{","|","}","~",127
   DCB    128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
   DCB    144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
   DCB    160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
   DCB    176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
   DCB    192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
   DCB    208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
   DCB    224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
   DCB    240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
   MEND

   MACRO
   DoToValueTable
ToValueTable
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  0,  0,  0,  0,  0,  0
   DCB      0, 10, 11, 12, 13, 14, 15,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0, 10, 11, 12, 13, 14, 15,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   DCB      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
   MEND

   MACRO
   DoToRepresentationTable
ToRepresentationTable
   DCB    "0123456789ABCDEF"
   MEND

;------------------------------------------------------------------------------
; Table for Territory_Collate and Territory_TransformString (PRM 3-834 & 3-842)
;------------------------------------------------------------------------------

; Collation sequence is as follows:

; 01234567890123456789012345678901
;  !"#$%&'()*+,-./0123456789:;<=>?
; @AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoP
; pQqRrSsTtUuVvWwXxYyZz[\]^_`{|}~[DEL]
; [80..FF]

   MACRO
   DoSortValueTable
SortValueTable
   DCB     &00,&01,&02,&03,&04,&05,&06,&07,&08,&09,&0A,&0B,&0C,&0D,&0E,&0F
   DCB     &10,&11,&12,&13,&14,&15,&16,&17,&18,&19,&1A,&1B,&1C,&1D,&1E,&1F
   DCB     &20,&21,&22,&23,&24,&25,&26,&27,&28,&29,&2A,&2B,&2C,&2D,&2E,&2F
   DCB     &30,&31,&32,&33,&34,&35,&36,&37,&38,&39,&3A,&3B,&3C,&3D,&3E,&3F
   DCB     &40,&41,&43,&45,&47,&49,&4B,&4D,&4F,&51,&53,&55,&57,&59,&5B,&5D
   DCB     &5F,&61,&63,&65,&67,&69,&6B,&6D,&6F,&71,&73,&75,&76,&77,&78,&79
   DCB     &7A,&42,&44,&46,&48,&4A,&4C,&4E,&50,&52,&54,&56,&58,&5A,&5C,&5E
   DCB     &60,&62,&64,&66,&68,&6A,&6C,&6E,&70,&72,&74,&7B,&7C,&7D,&7E,&7F

   DCB     &80,&81,&82,&83,&84,&85,&86,&87,&88,&89,&8A,&8B,&8C,&8D,&8E,&8F
   DCB     &90,&91,&92,&93,&94,&95,&96,&97,&98,&99,&9A,&9B,&9C,&9D,&9E,&9F
   DCB     &A0,&A1,&A2,&A3,&A4,&A5,&A6,&A7,&A8,&A9,&AA,&AB,&AC,&AD,&AE,&AF
   DCB     &B0,&B1,&B2,&B3,&B4,&B5,&B6,&B7,&B8,&B9,&BA,&BB,&BC,&BD,&BE,&BF
   DCB     &C0,&C1,&C2,&C3,&C4,&C5,&C6,&C7,&C8,&C9,&CA,&CB,&CC,&CD,&CE,&CF
   DCB     &D0,&D1,&D2,&D3,&D4,&D5,&D6,&D7,&D8,&D9,&DA,&DB,&DC,&DD,&DE,&DF
   DCB     &E0,&E1,&E2,&E3,&E4,&E5,&E6,&E7,&E8,&E9,&EA,&EB,&EC,&ED,&EE,&EF
   DCB     &F0,&F1,&F2,&F3,&F4,&F5,&F6,&F7,&F8,&F9,&FA,&FB,&FC,&FD,&FE,&FF
   MEND

        END

