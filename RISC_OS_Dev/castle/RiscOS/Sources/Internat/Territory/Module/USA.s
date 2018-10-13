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
; RISC OS American Territory
;-----------------------------------------------------------------------------

        GBLS    Help
Help    SETS    "USA Territory"
;                |-------------|   maximum length

        GBLA    TerrNum
TerrNum SETA    TerritoryNum_$Territory

        GBLS    AlphabetName
AlphabetName SETS "Latin1"

        GBLA    AlphNum
AlphNum SETA    ISOAlphabet_$AlphabetName

        GBLA    WriteDir
WriteDir SETA   WriteDirection_LeftToRight :OR: \
                WriteDirection_UpToDown :OR: \
                WriteDirection_HorizontalLines

;-----------------------------------------------------------------------------
; Values for Territory_ReadCalendarInformation (PRM 3-839)
;-----------------------------------------------------------------------------

FirstWorkDay    *       2       ; Monday
LastWorkDay     *       6       ; Friday
NumberOfMonths  *      12

MaxAMPMLength   *       2       ; "am"
MaxWELength     *       9       ; "Wednesday"
MaxW3Length     *       3       ; "Sun"
MaxDYLength     *       2       ; "31"
MaxSTLength     *       2       ; "st"
MaxMOLength     *       9       ; "September"
MaxM3Length     *       3       ; "Jan"
MaxTZLength     *       4       ; "AKST"

;-----------------------------------------------------------------------------
; Values for Territory_ReadCurrentTimeZone (PRM 3-806)
;-----------------------------------------------------------------------------

NumberOfTZ      *       5

        GBLS    NODST0
        GBLS    NODST1
        GBLS    NODST2
        GBLS    NODST3
        GBLS    NODST4
NODST0  SETS    "EST"
NODST1  SETS    "CST"
NODST2  SETS    "MST"
NODST3  SETS    "PST"
NODST4  SETS    "AKST"

        GBLS    DST0
        GBLS    DST1
        GBLS    DST2
        GBLS    DST3
        GBLS    DST4
DST0    SETS    "EDT"
DST1    SETS    "CDT"
DST2    SETS    "MDT"
DST3    SETS    "PDT"
DST4    SETS    "AKDT"

NODSTOffset0    *       100*60*60*-5    ; Minus five hours
DSTOffset0      *       100*60*60*-4
NODSTOffset1    *       100*60*60*-6    ; Minus six hours
DSTOffset1      *       100*60*60*-5
NODSTOffset2    *       100*60*60*-7    ; Minus seven hours
DSTOffset2      *       100*60*60*-6
NODSTOffset3    *       100*60*60*-8    ; Minus eight hours
DSTOffset3      *       100*60*60*-7
NODSTOffset4    *       100*60*60*-9    ; Minus nine hours
DSTOffset4      *       100*60*60*-8

;-----------------------------------------------------------------------------
; Settings for Territory_ConvertStandardDateAndTime,
; Territory_ConvertStandardDate and Territory_ConvertStandardTime (PRM 3-809)
;-----------------------------------------------------------------------------

        GBLS    DateFormat
DateFormat SETS "%m3-%dy-%ce%yr"

        GBLS    TimeFormat
TimeFormat SETS "%24:%mi:%se"

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
IntCurr         SETS    "USD "          ; international currency symbol
Currency        SETS    "$"             ; currency symbol
MDecimal        SETS    "."             ; decimal point (monetary)
MThousand       SETS    " "             ; thousands separator (monetary)
MGrouping       SETS    "3,0"           ; digit grouping (monetary)
MPositive       SETS    ""              ; positive sign (monetary)
MNegative       SETS    "-"             ; negative sign (monetary)
int_frac_digits *       2               ; fractional digits (international monetary)
frac_digits     *       2               ; fractional digits (monetary)
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
        DCD     2_00000100000000000000000000100010 ; �
        DCD     2_00000000000000000000000000000000 ; NBSP
        DCD     2_01111111011111111111111111111111 ; �
        DCD     2_00000000000000000000000000000000 ; �
        MEND
        MACRO
        DoLowercaseTable
LowercaseTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000111111111111111111111111110 ; `
        DCD     2_11001000000000000000000001000100 ; �
        DCD     2_00000000000000000000000000000000 ; NBSP
        DCD     2_10000000000000000000000000000000 ; �
        DCD     2_11111111011111111111111111111111 ; �
        MEND
        MACRO
        DoAlphaTable
AlphaTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000111111111111111111111111110 ; @
        DCD     2_00000111111111111111111111111110 ; `
        DCD     2_11001100000000000000000001100110 ; �
        DCD     2_00000000000000000000000000000000 ; NBSP
        DCD     2_11111111011111111111111111111111 ; �
        DCD     2_11111111011111111111111111111111 ; �
        MEND
; KJB 980912 - Marked &80 (Euro) as punctuation
        MACRO
        DoPunctuationTable
PunctuationTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_11111100000000001111111111111110 ; SP
        DCD     2_11111000000000000000000000000001 ; @
        DCD     2_01111000000000000000000000000001 ; `
        DCD     2_00110011111111111111000000000001 ; �
        DCD     2_11111111111111111111111111111110 ; NBSP
        DCD     2_00000000100000000000000000000000 ; �
        DCD     2_00000000100000000000000000000000 ; �
        MEND
        MACRO
        DoSpaceTable
SpaceTable
        DCD     2_00000000000000000011111000000000 ; [00]
        DCD     2_00000000000000000000000000000001 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; �
        DCD     2_00000000000000000000000000000001 ; NBSP
        DCD     2_00000000000000000000000000000000 ; �
        DCD     2_00000000000000000000000000000000 ; �
        MEND
        MACRO
        DoAccentedTable
AccentedTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000001100110 ; �
        DCD     2_00000000000000000000000000000000 ; NBSP
        DCD     2_00111111011111101111111110111111 ; �
        DCD     2_10111111011111101111111110111111 ; �
        MEND
        MACRO
        DoForwardFlowTable
ForwardFlowTable
        DCD     2_11111111111111111111111111111111 ; [00]
        DCD     2_11111111111111111111111111111111 ; SP
        DCD     2_11111111111111111111111111111111 ; @
        DCD     2_11111111111111111111111111111111 ; `
        DCD     2_11111111111111111111111111111111 ; �
        DCD     2_11111111111111111111111111111111 ; NBSP
        DCD     2_11111111111111111111111111111111 ; �
        DCD     2_11111111111111111111111111111111 ; �
        MEND
        MACRO
        DoBackwardFlowTable
BackwardFlowTable
        DCD     2_00000000000000000000000000000000 ; [00]
        DCD     2_00000000000000000000000000000000 ; SP
        DCD     2_00000000000000000000000000000000 ; @
        DCD     2_00000000000000000000000000000000 ; `
        DCD     2_00000000000000000000000000000000 ; �
        DCD     2_00000000000000000000000000000000 ; NBSP
        DCD     2_00000000000000000000000000000000 ; �
        DCD     2_00000000000000000000000000000000 ; �
        MEND

;-----------------------------------------------------------------------------
; Tables for Territory_LowerCaseTable etc (PRM 3-828 to 3-833)
;-----------------------------------------------------------------------------

; OSmith 29-Apr-92 Went over tables with a fine tooth comb and fixed them
; all. Accent collation order is correct for Welsh, since it is irrelevent
; in English. Collation order of �� (Icelandic eth), �� (O slash), � (German
; sharp s) and �� (Icelandic thorn) is taken from ISO 6937/2-1983.

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
   DCB    "�","�","�",131,132,"�","�",135,136,137,138,139,"�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   MEND

   MACRO
   DoToUpperTable
ToUpperTable

; OSmith 29-Apr-92 � maps to Y, because there is an upper case equivalent
; of �, it's just that we haven't got a glyph for it. �, �, and � on the
; other hand stay as they are since there is no upper case version of them
; even though they are classed as lower case characters.

   DCB      0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
   DCB     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
   DCB    " ","!", 34,"#","$","%","&","'","(",")","*","+",",","-",".","/"
   DCB    "0","1","2","3","4","5","6","7","8","9",":",";","<","=",">","?"
   DCB    "@","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O"
   DCB    "P","Q","R","S","T","U","V","W","X","Y","Z","[","\\","]","^","_"
   DCB    "`","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O"
   DCB    "P","Q","R","S","T","U","V","W","X","Y","Z","{","|","}","~",127
   DCB    "�","�","�",131,132,"�","�",135,136,137,138,139,"�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","Y"
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
   DCB    "�", 23, 23,131,132, 25, 25,135,136,137,138,139,"�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB      1,  1,  1,  1,  1,  1,"�",  3,  5,  5,  5,  5,  9,  9,  9,  9
   DCB    "�", 14, 15, 15, 15, 15, 15,"�","�", 21, 21, 21, 21, 25,"�","�"
   DCB      1,  1,  1,  1,  1,  1,"�",  3,  5,  5,  5,  5,  9,  9,  9,  9
   DCB    "�", 14, 15, 15, 15, 15, 15,"�","�", 21, 21, 21, 21, 25,"�", 25
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
   DCB    "�","W","w",131,132,"Y","y",135,136,137,138,139,"�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "�","�","�","�","�","�","�","�","�","�","�","�","�","�","�","�"
   DCB    "A","A","A","A","A","A","�","C","E","E","E","E","I","I","I","I"
   DCB    "�","N","O","O","O","O","O","�","O","U","U","U","U","Y","�","�"
   DCB    "a","a","a","a","a","a","�","c","e","e","e","e","i","i","i","i"
   DCB    "�","n","o","o","o","o","o","�","o","u","u","u","u","y","�","y"
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

; OSmith 29-Apr-92 Collation sequence is as follows:

; 01234567890123456789012345678901
; [SP][NBSP]!"#$%&'()*+,-[SHY]./0123456789:;<=>?
; @Aa��������������BbCc��Dd��Ee��������Ff��GgHhIi��������JjKkLlMm
;  Nn��Oo��������������PpQqRrSs�Tt��Uu��������VvWw��XxYy�����Zz[\]^_
; `{|}~[DEL]
; ������������������������
; ������������������������������
; �
; �

   MACRO
   DoSortValueTable
SortValueTable

   DCB     &00,&01,&02,&03,&04,&05,&06,&07,&08,&09,&0A,&0B,&0C,&0D,&0E,&0F
   DCB     &10,&11,&12,&13,&14,&15,&16,&17,&18,&19,&1A,&1B,&1C,&1D,&1E,&1F
   DCB     &20,&22,&23,&24,&25,&26,&27,&28,&29,&2A,&2B,&2C,&2D,&2E,&30,&31
   DCB     &32,&33,&34,&35,&36,&37,&38,&39,&3A,&3B,&3C,&3D,&3E,&3F,&40,&41
   DCB     &42,&43,&53,&55,&59,&5D,&67,&6B,&6D,&6F,&79,&7B,&7D,&7F,&81,&85
   DCB     &95,&97,&99,&9B,&9E,&A2,&AC,&AE,&B2,&B4,&BB,&BD,&BE,&BF,&C0,&C1
   DCB     &C2,&44,&54,&56,&5A,&5E,&68,&6C,&6E,&70,&7A,&7C,&7E,&80,&82,&86
   DCB     &96,&98,&9A,&9C,&9F,&A3,&AD,&AF,&B3,&B5,&BC,&C3,&C4,&C5,&C6,&C7

   DCB     &C8,&B0,&B1,&C9,&CA,&B6,&B7,&CB,&CC,&CD,&CE,&CF,&D0,&D1,&D2,&D3
   DCB     &D4,&D5,&D6,&D7,&D8,&D9,&DA,&DB,&DC,&DD,&91,&92,&DE,&DF,&69,&6A
   DCB     &21,&E0,&E1,&E2,&E3,&E4,&E5,&E6,&E7,&E8,&E9,&EA,&EB,&2F,&EC,&ED
   DCB     &EE,&EF,&F1,&F2,&F3,&F4,&F5,&F6,&F7,&F0,&F8,&F9,&FA,&FB,&FC,&FD
   DCB     &4B,&49,&45,&4D,&47,&4F,&51,&57,&65,&63,&5F,&61,&77,&75,&71,&73
   DCB     &5B,&83,&8D,&8B,&87,&8F,&89,&FE,&93,&AA,&A8,&A4,&A6,&B9,&A0,&9D
   DCB     &4C,&4A,&46,&4E,&48,&50,&52,&58,&66,&64,&60,&62,&78,&76,&72,&74
   DCB     &5C,&84,&8E,&8C,&88,&90,&8A,&FF,&94,&AB,&A9,&A5,&A7,&BA,&A1,&B8
   MEND

        END
