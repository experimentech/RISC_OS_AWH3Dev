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
; >FileCore40

        TTL     "Filename and Directory operations"

; Name restriction bits

NotBit7Chars    bit 0   ;unlike others this does not generate error but sets C
                 ;MUST BE LSB
MustBeFile      bit 1   ;name must refer to file
MustBeDir       bit 2   ;name must refer to dir
NotNulName      bit 3
NotLastWild     bit 4   ;last term of name must not have wild cards
NotLastUp       bit 5   ;last term of name must not be ^
DirItself       bit 6   ;get the dir itself rather than the parent
DirToBuffer     bit 7   ;dir must be in buffer not cache
MustBeDisc      bit 8   ;name must be disc spec
LibRelBitNo * 9
LibRel          bit LibRelBitNo  ;default library relative rather CSD relative
NotDrvNum       bit 10  ;any reference to disc must be by name

MustBeRefDisc   * &10000000     ;name must be on ref disc (eg ensuring rename destination on same disc as rename source)

; special filename components

RootChar        * "$"
UserRootChar    * "&"
LibChar         * "%"
CsdChar         * "@"
BackChar        * "\\"

UpChar          * "^"

DiscSpecChar    * ":"
DelimChar       * "."

OneWildChar     * "#"
MultiWildChar   * "*"

SpecialChars
;chars that cannot appear in filename and are not wild cards
;the delimiter does not appear in this list but is tested separately

; special dir chars
 =       RootChar
 =       UserRootChar
 =       LibChar
 =       CsdChar
 =       BackChar

 =       UpChar

NDirChars       = {PC}-SpecialChars

; other special chars
 =       DiscSpecChar

 =       """"
 =       "|"
; =       ","   taken out for 1.06


NBadChars       = {PC}-SpecialChars

UserRootText             ;nul names (if allowed) will be replaced by this
 = UserRootChar,0
        ALIGN


; =========
; CheckPath
; =========

; Check pathname is valid

; entry: R1 = ptr to string
;        R2 = name restriction bits

; exit:
; If error V set, R0 result
; ELSE C=1 if bit 7 set chars used

CheckPath
 [ Debug6 :LOR: DebugXd ;:LOR: DebugXr
        DSTRING R1, "checkpath( ",cc
        DREG    R2, ",",cc
        DLINE   ")"
 ]

        Push    "R0,R1,R3-R7,LR"
        baddr   R3, SpecialChars
        MOV     R4, SP          ;save SP for aborts
        MOV     R5, #MustBeFile ;will set bits on possible restrictions
10
        BL      SkipSpaces
        BCC     %FT20           ;not null name
        TSTS    R2, #NotNulName ;are we allowing nul names
        BNE     BadPath
        baddr   R1, UserRootText ;if so replace null by user root
        STR     R1, [SP,#4]
        B       %BT10
20
        TEQS    R0, #DiscSpecChar
        BEQ     %FT25
;if we are only looking for a disc spec allow disc spec char to be missing
        ASSERT  MustBeDisc=&100
        TSTS    R2, #MustBeDisc  ;C=0
        BEQ     %FT35
; Z=0, C=0
25
        BLEQ    NextChar
        BCS     BadPath         ;nul disc spec => bad name

        BL      ParseDrive
        BEQ     %FT70           ;Reject bad drive chars
        BHI     %FT30           ;Not drive number
        TSTS    R2, #NotDrvNum
        MOVNE   R0, #BadNameErr
        BNE     %FT70

30
        BL      ThisChar
        BL      CheckName
;if returns to here have parsed ':<disc spec>.'
        TSTS    R2, #MustBeDisc
        BNE     BadPath
;pass optional '$.'
        TEQS    R0, #RootChar   ;N=0
        BNE     %FT60
        BEQ     %FT50

35                              ;look for special dir chars
        MOV     R6, #(NDirChars-SpecialChars)-1
40
        LDRB    LR, [R3,R6]
        TEQS    R0, LR
        BEQ     %FT50           ;Valid dir char, N=0
        SUBS    R6, R6, #1
        BPL     %BT40
; if we fall through here we have not found leading disc spec or dir char, N=1

50
        ORRPL   R5, R5, #MustBeFile
        BLPL    CheckDelim
60
; remaining terms must be wildcarded name or UpChar
; starting new term so forget about last term
        BIC     R5, R5, #MustBeFile :OR: NotLastWild :OR: NotLastUp

        TEQS    R0, #UpChar                             ;is it UpChar
        ORREQ   R5, R5, #MustBeFile :OR: NotLastUp      ;if so refers to dir
        JumpAddress LR, %B60
        BEQ     CheckDelim
        BNE     CheckName       ;this will not return if term is terminated
        ; will return to 60

BadPath
        MOV     R0, #BadNameErr
        B       %FT70
PathChecked
;calculate return code
        ANDS    R6, R2, R5      ;mask to relevant restrictions
        MOV     R0, #0
        TSTS    R6, #NotLastWild
        MOVNE   R0, #WildCardsErr
        TSTS    R6, #NotLastUp
        MOVNE   R0, #BadUpErr
        TSTS    R6, #MustBeFile
        MOVNE   R0, #TypesErr
70
        ASSERT  NotBit7Chars=1
        MOVS    R5, R5, LSR #1  ;C=1 <=> bit 7 set chars used
        MOV     SP, R4
        BL      SetVOnR0
        STRVS   R0, [SP]
 [ Debug6
        DLINE   "string  |restrict|result - leaving checkpath"
        DREG    R1, " ",cc
        DREG    R2, " ",cc
        DREG    R0, " "
        BCC     %FT01
        DLINE   "bit 7 set chars used"
01
 ]
        Pull    "R0,R1,R3-R7,PC"


; =========
; CheckName     ONLY FOR USE WITHIN CHECKPATH
; =========

; Checks for a well formed name of legal chars & wild cards in pathname
; if bad aborts CheckPath with bad name error
; if good and terminated CheckPath done
; if good and delimited returns

; entry: R0=first char, R1 -> first char

; exit:  R1 -> first char after delimiter, R0=that char

CheckName ROUT
        Push    "LR"
        TEQS    R0, #DelimChar
        TEQNES  R0, #" "
        BEQ     BadPath         ;dont allow nul names

        TEQS    R0, #"-"        ;check for -&<disc add.> special case
        LDREQB  LR, [R1, #1]
        TEQEQS  LR, #"&"
        BEQ     %FT80

 [ :LNOT: FixTruncateOnBigDiscs
        LDRB    R6, Flags
        TST     R6, #TruncateNames
        MOVNE   R6, #NameLen    ;max length (barf)
        MOVEQ   R6, #&7fffffff  ;not a limit really (who cares!)
 ]
10
        MOV     R7, #(NBadChars-SpecialChars)-1
20                              ;check against table of illegal chars
        LDRB    LR, [R3,R7]
        TEQS    R0, LR
        BEQ     BadPath
        SUBS    R7, R7, #1
        BPL     %BT20
        TEQS    R0, #OneWildChar
        TEQNES  R0, #MultiWildChar
        ORREQ   R5, R5, #NotLastWild    ;note if wild card was used

        ASSERT  NotBit7Chars=1
        ORR     R5, R5, R0, LSR #7      ;note if bit 7 set char used

 [ :LNOT: FixTruncateOnBigDiscs
        CMPS    R0, #MultiWildChar
        SUBNES  R6, R6, #1
        BMI     BadPath         ;term too long
 ]
        BL      NextChar
        BCS     PathChecked
        TEQS    R0, #DelimChar
        BNE     %BT10
        B       CheckDelimCommon

80
        MOV     R0, #bit29
        ADD     R1, R1, #1
        Push    "R2"
        SUB     R2, R0, #1
        BL      OnlyXOS_ReadUnsigned
        Pull    "R2"
        BVS     BadPath
        ORR     R5, R5, #MustBeFile
        BL      ThisChar
        B       CheckDelim2


; ----------
; CheckDelim    ONLY FOR USE WITHIN CHECKPATH
; ----------

; have just read last char of term
;  IF   next char is terminator then CheckPath done
;  ELSE must find delimiter followed by valid char

CheckDelim ROUT
        Push    "LR"
        BL      NextChar
CheckDelim2
        BCS     PathChecked
        CMPS    R0, #DelimChar
        BNE     BadPath         ;if char after dir char it must be delimiter
CheckDelimCommon
        BL      NextChar
        BCS     BadPath         ;can't end with delimiter
        Pull    "PC"

; ==========
; SkipSpaces
; ==========

; entry: R1 -> string
; exit:  R1 -> first non space char, R0=that char
;        C=1 <=> terminator

SkipSpaces ROUT
        LDRB    R0, [R1], #1
        TEQS    R0, #" "
        BEQ     SkipSpaces
        SUB     R1, R1, #1
;FALL THROUGH TO THIS CHAR


; ========
; ThisChar
; ========

; entry: R1 -> current char
; exit:  R1 -> current char, R0=that char
;        C=1 <=> terminator

ThisChar
        SUB     R1, R1, #1
;FALL THROUGH TO NEXTCHAR


; ========
; NextChar
; ========

; entry: R1 -> current char
; exit:  R1 -> next char, R0=that char
;        C=1 <=> terminator

NextChar
        LDRB    R0, [R1,#1] !
        Push    "LR"
        CMPS    R0, #DeleteChar
        RSBNES  LR, R0, #" "
        Pull    "PC"

      [ RO3Paths ; these used to live inside code we've switched out
RootLibText     =       RootChar,".Library",0
CsdText         =       CsdChar,0
      ]

; ==========
; FullLookUp
; ==========

; Parse a path name

; entry:
;  R1 -> string
;  R2 name restriction bits

; exit:
; IF error V set, R0 result
;  R1    -> terminating char of last term IF success
;        -> terminating char of problem term IF not found
;  R2    preserved
;  R3    disc address of directory contained in (or dir itself if requested)
;  R4    -> entry in dir or next alphabetically if not found
;  R5    -> dir start
;  R6    -> first byte after dir
; IF no error (R0=0) C=1 <=> dir

; if the object is a root dir R3=(disc address of dir itself) and R4=0


FullLookUp ROUT
 [ Debug6
        DLINE   "string   restrict - entering FullLookUp"
        DREG    R1, "  ",cc
        DREG    R2, "  "
 ]

        Push    "R0,R7,R8,LR"
        BL      CheckPath
        SavePSR R6
        AND     R6, R6, #C_bit  ; R6<>0 <=> bit 7 set chars used
        BVS     %FT95

      [ :LNOT: RO3Paths
        LDR     R3, CurDir      ;Current directory is default
      ]
        MOV     R4, #0
        BL      SkipSpaces

        TEQS    R0, #DiscSpecChar
      [ :LNOT: RO3Paths
        BEQ     %FT03
        TSTS    R2, #MustBeDisc
        BEQ     %FT05           ;if path doesn't start with disc spec
03
      ]
        ; :<disc> or MustBeDisc

        ; advance to start of disc name
        BLEQ    NextChar

        ; Find it
        BL      FindDiscByName
        BVS     %FT95           ;error in parsing disc

        ; Skip past [.[$]]
        BL      Bit7Disc        ;if bit 7 set chars used must be new format
        BL      ThisChar
        BLCC    NextChar        ; skip delimiter
        TEQS    R0, #RootChar
        BLEQ    NextChar        ; skip $
      [ :LNOT: RO3Paths  ; since RO3, FileSwitch canonicalises everything so we only need the start-with-disc case above
        B       %FT25

05                               ;handle special dir chars
        TEQS    R0, #RootChar
        BNE     %FT15

        ; Path starts $
10
        CMPS    R3, #-1         ;if dir set get root of that disc
        MOVNE   R3, R3, LSR #(32-3)
        DiscRecPtr  R3,R3,NE
        LDRNE   R3, [R3,#DiscRecord_Root]
        B       %FT24

15
        TEQS    R0, #UserRootChar
        BNE     %FT20

        ; Path starts &

        ; use & or use $ of @'s disc if & not set
        LDR     R3, UserRootDir
        CMPS    R3, #-1         ;if & unset use $
        LDREQ   R3, CurDir
        BEQ     %BT10
        B       %FT24

UrdLibText      =       UserRootChar,".Library",0
RootLibText     =       RootChar,".Library",0
CsdText         =       CsdChar,0
        ALIGN

20
        ; if @ use current dir (which is already in R3)
        TEQS    R0, #CsdChar
        BEQ     %FT24          ;R3 already CSD

        ; If \ use BackDir, defaulting to $ of default drive
        TEQS    R0, #BackChar
        LDREQ   R3, BackDir
        BEQ     %FT24

; library must be last of special dir chars to be tested

        CMPS    R0, #LibChar
        ADDEQ   R1, R1, #1        ;skip Lib Char
        MOVNES  LR, R2, LSR #LibRelBitNo+1
        BCC     %FT25           ; Branch if not % and default isn't relative to library

        MOV     R7, R1           ;save string ptr
        LDR     R3, LibDir
        CMPS    R3, #-1
        BNE     %FT23           ; Branch if library set

; if lib unset, use first of   &.Library, $.Library or @   that exist as a
; temporary library
        baddr   R1, UrdLibText
        BL      %FT22
        baddr   R1, RootLibText
        BL      %FT22
        baddr   R1, CsdText
        BL      %FT22
; KJB 000524 - routine 22 used to preserve flags if it returned.
; This means V would be clear here from the equal CMP above.
        CLRV
        B       %FT95           ;if all 3 failed
22
        Push    "R2,R4,R6,LR"
        MOV     R2, #DirItself :OR: MustBeDir
        BL      FullLookUp
        Pull    "R2,R4,R6,LR"
        BVC     %FT23
        TEQS    R0, #NotFoundErr
        MOVEQ   PC, LR          ;if cant find try next
        B        %FT95
23
        SUB     R1, R7, #1        ;restore string ptr and adjust for NextChar
24
        BL      NextChar
25
        CMPS    R3, #-1
        BNE     %FT30
;if dir unset use root on default drive

        Push    "R1-R2"
        LDRB    R1, Drive
        BL      WhatDisc        ;get info on disc in this drive
; R2=disc num
; R3=disc rec ptr
        LDR     R3, [R3,#DiscRecord_Root]
        Pull    "R1-R2"
        BVS     %FT95           ;error
30
      ] ;  endif  :LNOT: RO3Paths
        ; We now have:
        ; r3 = root dir of path (may be $, &, %, \, @ or $ of default drive)
        BL      Bit7Disc        ;if bit 7 set chars used must be new format

        ; Check that MustBeRefDisc is satisfied if necessary
        TSTS    R2, #MustBeRefDisc      ;IF insisting on ref disc
        EORNE   LR, R2, R3
        TSTNES  LR, #DiscBits           ;AND it isnt
        MOVNE   R0, #NotRefDiscErr      ;THEN error
        BNE     %FT90

        BL      ThisChar
        BCS     %FT60           ;path done C=1 for dir

        ; Skip the . separator if there
        TEQS    R0, #DelimChar
        BLEQ    NextChar

        ; Generate NotFoundErr if trying to enter non-FileCore disc
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    LR, [LR, #DiscFlags]
        TST     LR, #DiscNotFileCore
        MOVNE   R0, #NotFoundErr
        BNE     %FT77

; just wildcard or ^ terms
35
        BL      FindDir ;(R3->R0,R5,R6)
        BVS     %FT95  ;error in getting dir
      [ RO3Paths
        B       %FT45
      |
        BL      ThisChar
        TEQS    R0, #UpChar
        BNE     %FT45
        MOV     R4, #0
        BL      ToParent
; R3=disc address of parent
        BL      NextChar
      ]
40
        BL      ThisChar
        BCS     %FT60  ;last term C=1 for dir
        BL      NextChar        ;read first char of next term
        B       %BT35           ;loop for next term

42
        Push    "R0,R2"
        MOV     R0, #0
        ADD     R1, R1, #1
        BL      OnlyXOS_ReadUnsigned    ;can't give error as already checked
        AND     R3, R3, #DiscBits
        ORR     R3, R3, R2
        Pull    "R0,R2"
        MOV     R4, #0
        B       %BT40

45
        TEQS    R0, #"-"
        LDREQB  LR, [R1, #1]
        TEQEQS  LR, #"&"
        BEQ     %BT42

 [ BigDir
        BL      GetDirFirstEntry
 |
        ADD     R4, R5, #DirFirstEntry
 ]
        MOV     R7, R1          ;save term ptr

;if this is not last term it must be dir
        BL      SkipTerm
        Push    "R0,R1,R2"
        TEQS    R0, #DelimChar
        MOVEQ   R2, #MustBeDir  ;If not last term only accept dirs     *A*
 [ BigDir
        BL      TestBigDir
        BNE     %FT01


        ADDS    R1, R7, #0
        BL      LookUpBigDir
        B       %FT02
01
 [ FixTruncateOnBigDiscs
        BL      %FT99           ; check the name length
 ]
        ADDS    R1, R7, #0
        BL      LookUp
02
 |
        ADDS    R1, R7, #0      ;restore term start ptr and C=0
        BL      LookUp
 ]
        Pull    "R0,R1,R2"

        MOVCS   R0, #NotFoundErr
        BCS     %FT77
        BEQ     %FT60           ;found a file

        TEQS    R0, #DelimChar
        BLEQ    ReadIndDiscAdd  ;(R3,R4->LR) enter if a dir and not last term
        MOVEQ   R3, LR
        BEQ     %BT40
        CMPS    R0, #0          ;set C=1 for dir

60     ;path parsed C=1 <=> dir

        ; Cancel C (dir) flag if DiscNotFileCore
        BLCS    DiscAddToRec    ;(R3->LR)
        LDRCSB  LR, [LR, #DiscFlags]
        TSTCS   LR, #DiscNotFileCore
        MOVHIS  LR, LR, ASL #1  ; Clear carry if CS and NE

        MOV     R8, R8, RRX     ;save C flag
        ASSERT  DirItself<&100  ;not to corrupt C

        TSTS    R2, #DirItself
        BNE     %FT65           ;want dir itself

; want parent dir
        TEQS    R4, #0
        BNE     %FT75           ;have already got parent
        BL      DiscAddToRec    ;(R3->LR)
        LDR     LR, [LR,#DiscRecord_Root]
        TEQS    R3, LR
        MOVEQ   r0, #0
        BEQ     %FT80           ;dont try to get parent of root

        BL      FindDir         ;get dir itself (R3->R0,R5,R6,V)
        BVS     %FT95
        MOV     R7, R3
        BL      ToParent        ;now get parent
        BL      FindDir         ;(R3->R0,R5,R6,V)
        BVS     %FT95
        ADD     R4, R5, #DirFirstEntry
63
 [ BigDir
        BL      TestBigDir              ;(R3->Z)
        BNE     %FT02
        BL      BigDirFinished          ;(R4,R5->Z)
        BEQ     %FT75
        BL      ReadIndDiscAdd
        TEQS    LR, R7                  ; check if OK
        BEQ     %FT75                   ; match
        ADD     R4, R4, #BigDirEntrySize

        B       %BT63
02
        LDRB    LR, [R4]
        CMPS    LR, #" "
        BLCS    ReadIndDiscAdd          ;(R3,R4->LR)
        TEQS    LR, R7                  ;preserves C
        ASSERT  NewDirEntrySz=OldDirEntrySz
        ADDHI   R4, R4, #NewDirEntrySz  ;HI <=> ~Z AND C
        BHI     %BT63                   ;if mismatch loop if more entries
        B       %FT75
 |
        LDRB    LR, [R4]
        CMPS    LR, #" "
        BLCS    ReadIndDiscAdd          ;(R3,R4->LR)
        TEQS    LR, R7                  ;preserves C
        ASSERT  NewDirEntrySz=OldDirEntrySz
        ADDHI   R4, R4, #NewDirEntrySz  ;HI <=> ~Z AND C
        BHI     %BT63                   ;if mismatch loop if more entries
        B       %FT75
 ]

65
; want the dir itself
        TEQS    R4, #0
        BLNE    ReadIndDiscAdd  ;(R3,R4->LR)
        MOVNE   R3, LR
        BL      FindDir         ;(R3->R0,R5,R6,V)
        BVS     %FT95
75
        MOV     R0, #0
77                              ;not found joins here
        TSTS    R2, #DirToBuffer
        BEQ     %FT80
        TEQS    R4, #0
        SUBNE   R4, R4, R5
        BL      GetDir          ;(R3->R0,R5,R6)
        ADDNE   R4, R4, R5
        BVS     %FT95
80
        CMPS    R8, #bit31      ;RRX'd into top bit earlier, so C=1 <=> dir
90
        BL      SetVOnR0
95
        STRVS   R0, [SP]
 [ Debug6
        DREG    R1, " ", cc
        DREG    R2, " ", cc
        DREG    R3, " ", cc
        DREG    R4, " ", cc
        DREG    R5, " ", cc
        DREG    R6, " ", cc
        DLINE   "leave FullLookUp "
        BVC     %FT01
        DREG    R0, " "
01
  [ DebugC
  BL    SanityCheckDirCache
  ]
 ]

        Pull    "R0,R7,R8,PC"

 [ FixTruncateOnBigDiscs
99      ; check name length
        ; r7 = ptr to name
        ; if name is invalid then set r0 to error ptr,
        ; Pull r0-r2 and jump to 95
        Push    "r0,r7,lr"

        LDRB    R0, Flags
        TST     R0, #TruncateNames
        Pull    "r0,r7,pc",EQ

        MOV     lr,r7
00      LDRB    r0,[r7],#1
        TEQ     r0,#127
        TEQNE   r0,#'.'
        BEQ     %FT01
        CMP     r0,#' '
        BGT     %BT00
01      SUB     r0,r7,lr
        CMP     r0,#NameLen+1
        Pull    "r0,r7,pc",LE

        Pull    "r0,r7,lr"
        Pull    "r0,r1,r2"
        MOV     r0,#BadNameErr
        BL      SetVOnR0
        B       %BT95
 ]

Bit7Disc                                ;Only new format discs can have bit 7
        MOV     R0, LR                  ;set chars in pathname
        BL      TestDir
        TSTNES  R6, #C_bit
        MOVEQ   PC, R0
        MOV     R0, #BadNameErr
        B        %BT90

; ========
; ToParent
; ========

; Looks up disc address of parent

; entry: R3=disc address of dir,  R6 -> byte after dir
; exit:  R3=disc address of parent

 [ BigDir
; if it's a big dir, then r5->dir
 ]

ToParent ROUT
 [ Debug6
        DREG    R3, " ", cc
        DLINE   " dir / parent dir "
 ]
        Push    "R0,LR"

 [ BigDir
        BL      TestBigDir
        ANDEQ   LR, R3, #DiscBits
        LDREQ   R3, [R5,#BigDirParent]
        BICEQ   R3, R3, #DiscBits
        ORREQ   R3, R3, LR
        BEQ     %FT90
 ]

        BL      TestDir      ;(R3->LR,Z)
        AND     R3, R3, #DiscBits ;remember disc num bits
        ADDEQ   R0, R6, #NewDirParent
        ADDNE   R0, R6, #OldDirParent
        BL      TestMap         ;(R3->LR)
        Read3                   ;load disc address of parent non aligned
        ORREQ   R3, R3, LR
        ORRNE   R3, R3, LR, LSL #8
90
 [ Debug6
        DREG    R3, " "
 ]
        Pull    "R0,PC"


; ==============
; FindDiscByName
; ==============

; Parse a disc name, the name must already have been checked by CheckPath

; entry:
;  R1->name
;  R2 lookup options, only MustBeRefDisc relevant (top 3 bits RefDisc if applicable)

; exit:
; IF error V set, R0 result
;  R0 result code
;  R1 incremented beyond successful parsing
;  R2 preserved
;  R3 disc address of root directory

FindDiscByName
 [ Debug6f
        DSTRING R1,">FindDiscByName(",cc
        DREG    R2,",",cc
        DLINE   ")"
 ]
        Push    "R0,R2,R4-R7,LR"
; [ DebugC
; BL     SanityCheckDirCache
; ]

        ; Check for drive number
        BL      ParseDrive
        BEQ     %FT95   ; single drive char, but not a valid drive number
        BVS     %FT05   ; not a single drive char

; It's a drive number

        ADD     R1, R1, #1      ;skip drive char
 [ Debug6f
        DREG    R0,,cc
        DLINE   "= drive | string = ",cc
        DSTRING R1
 ]

        TSTS    R2, #MustBeRefDisc
        BEQ     %FT03

; It's a drive number and must be the same as the RefDisc - separate
; from other cases to avoid unnecessary disc examinations

        MOV     R3, R2, LSR #(32-3)     ;ref disc
        DiscRecPtr  R4,R3
        LDRB    R4, [R4,#DiscsDrv]      ;IF
        RSBS    LR, R4, #7              ;    ( ref disc thought to be in drive
        Push    "R0",CS
        MOVCS   R0, R4
        BLCS    PollChange      ;(R0->LR)
        Pull    "R0",CS
        RSBCSS  LR, LR, #7              ;    AND this is certain
        TEQS    R0, R4                  ;    AND it isnt this drive )
        BHI     %FT02
                                ;  OR
        BL      PollChange      ;(R0->LR)
        MOV     R4, LR
        RSBS    LR, R4, #&7F            ;    ( drive contents certain
        TEQS    R3, R4                  ;    AND isnt ref disc )
02
        MOVHI   R0, #NotRefDiscErr      ;THEN error
        BHI     %FT95

03
; It's a drive number and may be any drive (MustBeRefDisc is clear)

 [ Debug6f
        DLINE   "It's a drive number, going to WhatDisc the drive"
 ]

        ; WhatDisc the specified drive
        Push    "R1"
        MOV     R1, R0
        BL      WhatDisc                ;(R1->R0-R3,V)
        LDRVC   R3, [R3,#DiscRecord_Root]
        Pull    "R1"
        STRVS   R0, [SP]
; [ DebugC
; BL     SanityCheckDirCache
; ]
        Pull    "R0,R2,R4-R7,PC"

05
; It's not a drive number, is it name of known disc?

        ; Try the preferred disc first
        LDRB    lr, PreferredDisc
        TEQ     lr, #&ff
        BEQ     %FT07                   ; no preferred disc

        DiscRecPtr r6,lr
        MOV     r3, lr, ASL #(32-3)

        LDRB    lr, [r6, #Priority]
        TEQ     lr, #0
        BEQ     %FT07                   ; disc unused now

        ADD     r4, r6, #DiscRecord_DiscName
        BL      TestDir
        MOVEQ   r5, #&ff
        MOVNE   r5, #&7f
        BL      LexEqv
        LDREQ   r6, [r6, #DiscRecord_Root]
        BEQ     %FT17

07
        MOV     R3, #0
        sbaddr  R4, DiscRecs+DiscRecord_DiscName

        ; These bits are used to indicate which sort of root directory
        ; has been found:
        ; bit28 clear: a directory has been found
        MOV     r6, #bit28
10
        LDRB    LR, [R4,#Priority - DiscRecord_DiscName]
        TEQS    LR, #0
        BEQ     %FT15           ;unused disc rec
        BL      TestDir         ;(R3->LR,Z)
        MOVEQ   R5, #&FF        ;set up bit 7 chars mask
        MOVNE   R5, #&7F
 [ Debug6f
        DSTRING r1, "LexEqv(",cc
        DSTRING r4, ",",cc
        DREG    r5, ",",cc
        DLINE   ")"
 ]
        BL      LexEqv          ;(R1,R4,R5->LO/EQ/HI)
        BNE     %FT15           ;mismatch
 [ Debug6f
        DLINE   "Matched!"
 ]

        ; Test for disc already found
        TST     R6, #bit28
        MOVEQ   R0, #AmbigDiscErr       ; more than one disc matched
        BEQ     %FT95

        LDR     r6, [r4, #DiscRecord_Root - DiscRecord_DiscName]

15
 [ Debug6f
        DREG    r6, "Match flags:"
 ]
        ADD     R4, R4, #SzDiscRec
        ADDS    R3, R3, #1 :SHL: (32-3) ;inc disc num bits
        BCC     %BT10                   ;loop for next disc rec

        TST     R6, #bit28
        BNE     %FT20                   ; no discs matched

17
;matched exactly one disc name
        BL      SkipTerm
        MOV     R3, R6
        BL      ClearV
 [ Debug6f
        DREG    R3,"root dir="
 ]
; [ DebugC
; BL     SanityCheckDirCache
; ]
        Pull    "R0,R2,R4-R7,PC"

20
; Disc name not found amoungst known discs
        ; If only allowing files on ref disc, and name didn't match
        ; any disc (in particular the ref disc) then error
        TSTS    R2, #MustBeRefDisc
        MOVNE   R0, #NotRefDiscErr
        BNE     %FT95
; [ DebugC
; BL     SanityCheckDirCache
; ]

23
        MOV     R4, #0  ;init upcall ctr
24
;identify drives whose contents are uncertain
; R7 = drive being considered (from 0 to Floppies+4-1 inclusive)
        MOV     R7, #0
        B       %FT35
25
        ; Test for drive valid
        MOVS    LR, R7, LSR #3  ;C=0 <=> winnie num
        LDRCCB  R0, Winnies
        SBCCCS  LR, R0, R7      ;C=1 <=> valid drv num
        BCC     %FT30

 [ Debug6f
        DREG    R7, "Checking disc "
 ]

        ; Check for disc change
        MOV     R0, R7
        BL      PollChange      ;(R0->LR)

 [ Debug6f
        DLINE   "Poll change returned"
 ]

        ; Test for certainty of drive contents
        TSTS    LR, #Uncertain
        BEQ     %FT30

        ; Drive contents uncertain - find out what's in it
        Push    "R1"
        MOV     R1, R7
        BL      WhatDisc
 [ Debug6f
        DLINE   "WhatDisc returned"
 ]
        Pull    "R1"            ;If successfully examined disc
        BVS     %FT30

        ; Disc identified - check disc name
        Push    "R4"
        ADD     R4, R3, #DiscRecord_DiscName
        LDR     R3, [R3,#DiscRecord_Root]
        BL      TestDir
        MOVEQ   R5, #&FF        ;set up bit 7 chars mask
        MOVNE   R5, #&7F
 [ Debug6f
        DSTRING r1, "LexEqv(",cc
        DSTRING r4, ",",cc
        DREG    r5, ",",cc
        DLINE   ")"
 ]
        BL      LexEqv          ;(R1,R4,R5->LO/EQ/HI)
        Pull    "R4"
 [ Debug6f
        DLINE   "LexEqv returned"
 ]
        BNE     %FT30
        BL      SkipTerm        ;move R1 past term if match
        MOV     R2, #0          ;success code
        B       %FT40           ;if matched then dont need to look any further

30
 [ Debug6f
        DLINE   "Disc mismatch...move to next disc"
 ]
        ; Disc mismatch, error or contents certain - move to next disc
        ADD     R7, R7, #1

35
        ; Stop when reached end of disc list
        LDRB    LR, Floppies    ;drive ctr
        ADD     LR, LR, #4
        CMPS    R7, LR
        BLO     %BT25

 [ Debug6f
        DLINE   "Run out of discs...UpCall_MediaNotKnown"
 ]
        ; Run out of discs to check - ask user for disc
        MOV     R0, #UpCall_MediaNotKnown
        BL      UpCall          ;(R0,R1,R4->R2-R4,C)
 [ Debug6f
        DLINE   "MediaNotKnown returned"
 ]
        BCS     %BT24           ;try again if upcall claimed

        ; User rejected it - give error
        MOV     R2, #DiscNotFoundErr

40
 [ Debug6f
        DLINE   "Answer known....MediaSearchEnd"
 ]
        ; Answer known - finish MediaSearch if necessary
        TEQS    R4, #0
        MOVNE   R0, #UpCall_MediaSearchEnd
        BLNE    OnlyXOS_UpCall
        MOV     R0, R2

 [ Debug6f
        DREG    R3,"<FindDiscByName(",cc
        DLINE   ")"
        DebugError "    FindDiscByName error"
 ]

95                              ;error exit
        BL      SetVOnR0
        STRVS   R0, [SP]
 ;[ DebugC
 ;BL     SanityCheckDirCache
 ;]
        Pull    "R0,R2,R4-R7,PC"

; ========
; SkipTerm
; ========

; entry: R1->term start

; exit:  R0 terminator or delimiter, R1 incremented past term

SkipTerm  ROUT
        Push    "R2,LR"
        SavePSR r2
10
        BL      NextChar
        TEQS    R0,#DelimChar
        BEQ     %FT20
        BCC     %BT10
20
        RestPSR r2,,f
        Pull    "R2,PC"

; =========
; TermStart
; =========

; entry:
;  R0->string start
;  R1->char after term

; exit:  R1->first char of term, must preserve C,V

TermStart ROUT
        Push    "R2,LR"
        SavePSR R2
10
        CMPS    R1, R0
        LDRHIB  LR, [R1,#-1]
        TEQHIS  LR, #DelimChar
        SUBHI   R1, R1, #1
        BHI     %BT10
        RestPSR r2,,f
        Pull    "R2,PC"


; =============
; ParseAnyDrive
; =============

; as ParseDrive but
;  a) doesn't check if drive is allowed by configure
;  b) doesn't map 0-3 to 4-7 if no winnies configured

ParseAnyDrive ROUT
        Push    "R1,R2,R3,LR"
        MOV     R3,#0
        B       ParseDriveCommon

; ==========
; ParseDrive
; ==========

; Entry: R1-> string
; Exit:  R0 drive number if success else BadDriveErr
;    LO  C=0, Z=0, V=0 => 1 char string and good drive
;    EQ  C=1, Z=1, V=1 => 1 char string but invalid
;    HI  C=1, Z=0, V=1 => not 1 char string

; Good drive numbers are:
; 0-7
; A-H
; a-h

ParseDrive ROUT
        Push    "R1,R2,R3,LR"
 [ Debug6
        DREG    R1, " ", cc
        DLINE   ">ParseDrive"
 ]
        MOV     R3, #1
ParseDriveCommon
        BL      ThisChar
        BCS     %FT10           ;reject nul string
        MOV     R2, R0          ;save drive char
        BL      NextChar        ;check terminated
        TEQS    R0, #DelimChar
        MOVEQS  R0, #2, 2       ;Delim => C=1  ie treat as terminator
        BCS     %FT20           ;is terminated
10
        CMPS    SP, #0           ;not drive string set HI
        B        %FT40

20
        CMPS    R2, #"a"
        SUBHS   R2, R2, #"a"-"A"        ; 'a'-'h' -> 'A'-'H'
        CMPS    R2, #"A"
        SUBHS   R2, R2, #"A"-"0"        ; 'A'-'H' -> '0'-'7'
        SUBS    R2, R2, #"0"            ; '0'-'7' ->  0 - 7
        RSBCSS  LR, R2, #7
        BLO     %FT30                   ; not drive char

        EOR     R2, R2, #4              ; convert to internal numbering

        ; Skip check if don't want it
        CMPS    R3, #1
        BLO     %FT40           ;V=0

        ; Check drive number versus known drives
        TSTS    R2, #4
        LDREQB  R0, Winnies
        LDRNEB  R0, Floppies
        ADDNE   R0, R0, #4
        CMPS    R2, R0
        BLO     %FT40           ;drive is present LO, V=0
30
        CMPS    R0, R0          ;bad drive char set EQ

40
        MOVLO   R0, R2
        MOVHS   R0, #BadDriveErr
        BLHS    SetV
 [ Debug6
        DREG    R0, " ", cc
        DLINE   "<ParseDrive"
 ]
        Pull    "R1,R2,R3,PC"


; ======
; LookUp
; ======

; look up wild card spec term in dir

; entry:
;  R1   -> term, terminated by control codes ,delete ,space or delimiter
;  R2   name restriction bits, only 'must be file' and 'must be dir' apply
;  R3   disc address of dir
;  R4   entry in dir to start at (or following entry if C=1)

; exit:
; IF found R4->entry in dir, Z=1 <=> file, C=0
; ELSE     R4->next alphabetical entry, C=1

LookUp  ROUT
 [ Debug6
        DREG    r1,"LookUp(wild=",cc
        DREG    r2,",restrict=",cc
        DREG    r3,",dir=",cc
        DREG    r4,",at ",cc
        DLINE   ")",cc
 ]

        Push    "R5-R7,LR"
        BL      TestDir           ;preserves C
        MOVEQ   R5, #&FF
        MOVNE   R5, #&7F                ;old format dirs cant have bit 7 set chars
 [ NewDirEntrySz=OldDirEntrySz
        SUBCC   R4, R4, #NewDirEntrySz  ;caller asked to start at this entry
 |
        MOVEQ   R6, #NewDirEntrySz
        MOVNE   R6, #OldDirEntrySz
        SUBCC   R4, R4, R6              ;caller asked to start at this entry
 ]

        MOV     r7, #0

 [ NewDirEntrySz=OldDirEntrySz
10
        ADD     R4, R4, #NewDirEntrySz
 |
10
        ADD     R4, R4, R6
 ]
        LDRB    LR, [R4]
        CMP     LR, #" "+1              ;LO (CC) <=> no more names in dir, 0 mark found
        BLO     %FT12

        BL      LexEqv                  ;(R1,R4,R5->LO/EQ/HI)
        BCC     %BT10                   ;if mismatch and name < wild try next
        BEQ     %FT15                   ;EQ=>match

12
        ;mismatch and name > wild done
        TEQ     r7, #0                  ; doesn't affect C
        MOVEQ   r7, r4
        BCS     %BT10

        ; Completion in the not found case
        MOV     r4, r7
        SEC                             ; Set carry (not found)
        B       %FT90

15
        ; Match, but...
        BL      ReadIntAtts
;LR = Atts
        TSTS    LR, #DirBit
        BNE     %FT20                ;found a dir
;found a file
        TSTS    R2, #MustBeDir
        BNE     %BT10
;fall through next few instructions as EQ
20
        TSTNES  R2, #MustBeFile
        BNE     %BT10

        TSTS    LR, #DirBit :SHL: 2,2 ;restore Z=1 <=> file, C=0
90
 [ Debug6
        DREG    r4,"->(loc=",cc
        BCC     %FT01
        DLINE   ",not found)"
        B       %FT02
01
        DLINE   ",found)"
02
 ]
        Pull    "R5-R7,PC"

 [ BigDir
; =========
; BigLexEqv
; =========

; compare wild card spec term with name (usually in dir)

; entry:
;  R1 -> term, terminated by control codes ,delete ,space or delimiter
;  R4 -> name

;  R5 =  bit mask for name chars
;  R6 =  length of name

; exit:
;  name < wild spec   C=0, Z=0, V=0
;  name = wild spec   C=1, Z=1, V=0
;  name > wild spec   C=1, Z=0, V=0

BigLexEqv
 [ DebugX
        DLINE   "wild     name     mask - enter BigLexEqv"
        DREG    R1,,cc
        DREG    R4," ",cc
        DREG    R5," "
 ]

        Push    "R0,R1,R4,R6-R11,LR"

        ; NULL name is equivalent to "" (for root object on a disc)
        TEQ     R4, #0
        baddr   R4, anull, EQ

        ADD     R6, R4, R6              ;Max Name end ptr

        MOV     R7, #0                  ;wild backtrack ptr, R8 will be name backtrack
        MOV     R10,#0                  ;clear # used flag

        SUB     R1, R1, #1
10
        BL      NextChar
        MOVCS   R0, #0           ;replace terminators by 0, for name<wild check
        TEQS    R0, #DelimChar
        MOVEQ   R0, #0          ; delimiters must be replaced by 0 too
        CMPS    R0, #MultiWildChar
        BEQ     %FT30
        BL      %FT50           ;R9=next name char
        Internat_CaseConvertLoad LR,Upper
        Internat_UpperCase  R0,LR
        CMPS    R0, #OneWildChar ;match ?
        MOVEQ   R10,#-1         ;note if # used
        CMPNES  R0, R9          ;match ?
        BEQ     %BT10           ;loop on match
        MOV     R4, R8          ;back track name
        MOVS    R1, R7          ;back track wild, and test if * used
        BNE     %FT30           ;if it was restart from backtrack
20
; not match, but was name < wild

; if wild cards force name < wild to continue dir search

        RSBS    LR, R7, #1      ; * used => C=0
        RSBCSS  LR, R10,#1      ; # used => C=0
        CMPCSS  R9, R0
 [ DebugX
        BHI     %FT01
        DLINE   "name<wild"
01
        BLO     %FT01
        DLINE   "name>wild"
01
 ]
        Pull    "R0,R1,R4,R6-R11,PC"

30
        MOV     R7, R1          ;Wild backtrack ptr -> wild card
        BL      NextChar        ;Next wild
        MOVCS   R0, #0          ;replace terminators by 0, for wild<name check
        TEQS    R0, #DelimChar
        MOVEQ   R0, #0          ;delimiters must be replaced by 0 too
        CMPS    R0, #MultiWildChar
        BEQ     %BT30           ;deal with **
        Internat_CaseConvertLoad LR,Upper
        Internat_UpperCase  R0,LR
40
        BL      %FT50           ;R9=next name char
        CMPS    R0, #OneWildChar ;match ?
        MOVEQ   R10,#-1         ;note if # used
        CMPNES  R0, R9          ;match ?
        BNE     %BT40
        MOV     R8, R4          ;name backtrack ptr -> char after match
        B       %BT10           ;loop

50
;get name char
        LDRB    R9, [R4],#1
        AND     R9, R9, R5      ;maybe mask out bit 7
        Internat_CaseConvertLoad R11,Upper
        Internat_UpperCase  R9,R11
        TEQS    R9, #DelimChar
        MOVEQ   R9, #0
        CMPS    R9, #" "+1      ;name terminated by control code ?
        MOVLO   R9, #0          ;replace terminators by 0, for wild<name check
        CMPHS   R6, R4          ;name terminated by length ?
        MOVHS   PC, LR          ;name not terminated
        MOVLO   R9, #0          ;terminator of 0 if name terminated

;name terminated, has wildcard ?
        CMPS    R0, #DelimChar
        CMPNE   R0, #0
        BLNE    ThisChar
        BCS     %FT60           ;match

        LDR     lr, [sp, #2*4]
        SUB     lr, r4, lr
        CMP     lr, #BigDirMaxNameLen
        BLO     %BT20           ;mismatch if not reached max name length

        ; Check if Truncate is configured
        LDRB    lr, Flags
        TST     lr, #TruncateNames
        BNE     %BT20           ;mismatch if barf on truncate names

        ; Now check if wildcard has terminated based on length
        LDR     lr, [sp, #1*4]  ; R1 in
        SUB     lr, r1, lr
        CMP     lr, #BigDirMaxNameLen
        BLO     %BT20           ; finished short of BigDirMaxNameLen

        ; Drop through to match situation
60
        CMPS    R0, R0          ;set equal C=1,Z=1
 [ DebugX
        DLINE   "name=wild"
 ]
        Pull    "R0,R1,R4,R6-R11,PC"

 ]

; ======
; LexEqv
; ======

; compare wild card spec term with name (usually in dir)

; entry:
;  R1 -> term, terminated by control codes ,delete ,space or delimiter
;  R4 -> name

;  R5 =  bit mask for name chars

; exit:
;  name < wild spec   C=0, Z=0, V=0
;  name = wild spec   C=1, Z=1, V=0
;  name > wild spec   C=1, Z=0, V=0

LexEqv
 [ Debug6  :LAND: {FALSE}
        mess    ,"wild     name     mask - enter LexEqv",NL
        DREG    R1
        DREG    R4
        DREG    R5
 ]

        Push    "R0,R1,R4,R6-R11,LR"

        ; NULL name is equivalent to "" (for root object on a disc)
        TEQ     R4, #0
        baddr   R4, anull, EQ

        ADD     R6, R4, #NameLen        ;Max Name end ptr

        MOV     R7, #0                  ;wild backtrack ptr, R8 will be name backtrack
        MOV     R10,#0                  ;clear # used flag

        SUB     R1, R1, #1
10
        BL      NextChar
        MOVCS   R0, #0           ;replace terminators by 0, for name<wild check
        CMPS    R0, #MultiWildChar
        BEQ     %FT30
        BL      %FT50           ;R9=next name char
        Internat_CaseConvertLoad LR,Upper
        Internat_UpperCase  R0,LR
        CMPS    R0, #OneWildChar ;match ?
        MOVEQ   R10,#-1         ;note if # used
        CMPNES  R0, R9          ;match ?
        BEQ     %BT10           ;loop on match
        MOV     R4, R8          ;back track name
        MOVS    R1, R7          ;back track wild, and test if * used
        BNE     %FT30           ;if it was restart from backtrack
20
; not match, but was name < wild

; if wild cards force name < wild to continue dir search

        RSBS    LR, R7, #1      ; * used => C=0
        RSBCSS  LR, R10,#1      ; # used => C=0
        CMPCSS  R9, R0
 [ Debug6 :LAND: {FALSE}
        mess    LO,"name<wild",NL
        mess    HI,"name>wild",NL
 ]
        Pull    "R0,R1,R4,R6-R11,PC"

30
        MOV     R7, R1          ;Wild backtrack ptr -> wild card
        BL      NextChar        ;Next wild
        MOVCS   R0, #0          ;replace terminators by 0, for wild<name check
        CMPS    R0, #MultiWildChar
        BEQ     %BT30           ;deal with **
        Internat_CaseConvertLoad LR,Upper
        Internat_UpperCase  R0,LR
40
        BL      %FT50           ;R9=next name char
        CMPS    R0, #OneWildChar ;match ?
        MOVEQ   R10,#-1         ;note if # used
        CMPNES  R0, R9          ;match ?
        BNE     %BT40
        MOV     R8, R4          ;name backtrack ptr -> char after match
        B       %BT10           ;loop

50
;get name char
        LDRB    R9, [R4],#1
        AND     R9, R9, R5      ;maybe mask out bit 7
        Internat_CaseConvertLoad R11,Upper
        Internat_UpperCase  R9,R11
        CMPS    R9, #" "+1      ;name terminated by control code ?
        MOVLO   R9, #0          ;replace terminators by 0, for wild<name check
        CMPHS   R6, R4          ;name terminated by length ?
        MOVHS   PC, LR          ;name not terminated
;name terminated, has wildcard ?
        CMPS    R0, #DelimChar
        BLNE    ThisChar
        BCS     %FT60           ;match

        ; Check if Truncate is configured
        LDRB    lr, Flags
        TST     lr, #TruncateNames
        BNE     %BT20           ;mismatch if barf on truncate names

        ; Now check if wildcard has terminated based on length
        LDR     lr, [sp, #1*4]  ; R1 in
        SUB     lr, r1, lr
        CMP     lr, #NameLen
        BLO     %BT20           ; finished short of NameLen

        ; Drop through to match situation
60
        CMPS    R0, R0          ;set equal C=1,Z=1
 [ Debug6 :LAND: {FALSE}
        mess    ,"name=wild",NL
 ]
        Pull    "R0,R1,R4,R6-R11,PC"


; ========
; ReadLoad
; ========

; read load address from directory entry

; entry: R3    dir disc address
;        R4 -> entry

; exit:  LR = load address

ReadLoad ROUT
        Push    "R0,LR"
 [ BigDir
        BL      TestBigDir
        BEQ     %FT10
 ]
        TEQS    R4, #0
        ; For root object set load for type of disc
        ; Use EOR in case types extend in the future
        BLEQ    DiscAddToRec            ;(R3->LR)
        LDREQ   LR, [LR, #DiscRecord_DiscType]
        MOV     LR, LR, LSL #8
        EOREQ   LR, LR, #&ff000000
        EOREQ   LR, LR, #&00f00000
        ADDNE   R0, R4, #DirLoad
        ReadWord NE
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= load add"
 ]
        Pull    "R0,PC"

 [ BigDir
10
        TEQS    R4, #0
        ; For root object set load for type of disc
        ; Use EOR in case types extend in the future
        BLEQ    DiscAddToRec            ;(R3->LR)
        LDREQ   LR, [LR, #DiscRecord_DiscType]
        MOV     LR, LR, LSL #8
        EOREQ   LR, LR, #&ff000000
        EOREQ   LR, LR, #&00f00000
        LDRNE   LR, [R4, #BigDirLoad]
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= load add"
 ]
        Pull    "R0,PC"
 ]

; ========
; ReadExec
; ========

; read exec address from directory entry

; entry: R4 ->entry

; exit:  LR = exec address, C and V preserved.

ReadExec ROUT
        Push    "R0,LR"
 [ BigDir
        BL      TestBigDir
        BEQ     %FT10
 ]
        TEQS    R4, #0
        MOVEQ   LR, #0
        ADDNE   R0, R4, #DirExec
        ReadWord NE
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= exec add"
 ]
        Pull    "R0,PC"

 [ BigDir
10
        TEQS    R4, #0
        MOVEQ   LR, #0
        LDRNE   LR, [R4, #BigDirExec]
  [ Debug6
        DREG    LR, " ", cc
        DLINE   "= exec add"
  ]
        Pull    "R0,PC"
 ]

; =======
; ReadLen
; =======

; read length from directory entry

; entry: R3    dir disc address
;        R4 -> entry

; exit:  LR = length

ReadLen
        Push    "R0,LR"
        ; For most cases read length from dir
  [ BigDir
        ; check if is big dirs
        BL      TestBigDir
        BNE     %FT05
        ; big dirs

        TEQS    R4, #0
        LDREQ   LR, [LR, #DiscRecord_BigDir_RootDirSize]
        LDRNE   LR, [R4, #BigDirLen]
   [ Debug6
        BEQ     %FT01
        DREG    LR, " ", cc
        DLINE   "= file len, from big dir"
01
   ]
        Pull    "R0,PC",NE

        ; big dir, but root object.  read root length from disc record
        BL      DiscAddToRec    ;(R3->LR)

        LDRB    R0, [LR, #DiscFlags]
        TST     R0, #DiscNotFileCore

        ; Contents of non-filecore disc
        LDRNE   LR, [LR, #DiscRecord_DiscSize]
  [ Debug6
        BEQ     %FT01
        DREG    LR, " ", cc
        DLINE   "= file len, from DiscSize"
01
  ]
        Pull    "R0,PC",NE

        LDR     LR, [LR, #DiscRecord_BigDir_RootDirSize]
  [ Debug6
        DREG    LR, " ",cc
        DLINE   "= file len, from RootDirSize"
  ]
        Pull    "R0,PC"

05
        ; not big dirs
        TEQS    R4, #0
        ADDNE   R0, R4, #DirLen
        ReadWord NE
   [ Debug6
        BEQ     %FT01
        DREG    LR, " ", cc
        DLINE   "= file len, from DirLen"
01
   ]
        Pull    "R0,PC",NE


        ; For root object need special processing
        BL      DiscAddToRec    ;(R3->LR)
        LDRB    R0, [LR, #DiscFlags]
        TST     R0, #DiscNotFileCore

        ; Contents of non-filecore disc
        LDRNE   LR, [LR, #DiscRecord_DiscSize]
  [ Debug6
        BEQ     %FT01
        DREG    LR, " ", cc
        DLINE   "= file len, from DiscSize"
01
  ]
        Pull    "R0,PC",NE

        ; Root dir, FileCore disc
        BL      TestDir
        MOVEQ   LR, #NewDirSize
        MOVNE   LR, #OldDirSize

  [ Debug6
        DREG    LR, " ", cc
        DLINE   "= file len, from New/OldDirSize"
  ]
 |
        BL      TestDir
        MOVEQ   LR, #NewDirSize
        MOVNE   LR, #OldDirSize
        TEQS    R4, #0
        ADDNE   R0, R4, #DirLen
        ReadWord NE
 ]
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= file len"
 ]
        Pull    "R0,PC"


; ==============
; ReadIndDiscAdd
; ==============

; read indirect disc address from directory entry

; entry: R3    dir disc address
;        R4 -> entry

; exit:  LR = indirect disc address

ReadIndDiscAdd
        Push    "R0,R7,LR"
        SavePSR R7
        TEQ     R4, #0

        ; Root object - disc add is dir disc add
        MOVEQ   LR, R3
  [ Debug6
        BNE     %FT01
        DREG    R3, "Disc add = "
01
  ]
        BEQ     %FT90

  [ BigDir
        BL      TestBigDir
        BNE     %FT01

        LDR     LR, [R4, #BigDirIndDiscAdd]

        B       %FT02
01
        BL      TestMap                 ;(R3->Z)
        ADD     R0, R4, #DirIndDiscAdd
        Read3
        MOVNE   LR, LR, LSL #8
02
  |
        BL      TestMap                 ;(R3->Z)
        ADD     R0, R4, #DirIndDiscAdd
        Read3
        MOVNE   LR, LR, LSL #8
  ]
        BIC     LR, LR, #2_111 :SHL: (32-3)     ;only to be safe for corrupt dirs
        AND     R0, R3, #2_111 :SHL: (32-3)     ;copy disc num bits
        ORR     LR, LR, R0
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= disc add"
 ]
90
        RestPSR R7,,f
        Pull    "R0,R7,PC"


; ===========
; ReadIntAtts
; ===========

; read attributes from directory entry in internal format

; entry: R3 = disc address of dir
;        R4 ->entry

 [ FullAtts
; exit:  LR has attributes, bits 7-0 7654DLWR
 |
; exit:  LR has attributes, bits 3-0     DLWR
 ]

ReadIntAtts ROUT
        Push    "R0-R1,LR"
        TEQS    R4, #0                           ;root ?
        BNE     %FT05

        ; processing of a root object
        BL      DiscAddToRec                  ;(R3->LR)
        LDRB    LR, [LR, #DiscFlags]
        TST     LR, #DiscNotFileCore
        MOVNE   LR, #ReadBit :OR: WriteBit    ; non-filecore root = disc image
        MOVEQ   LR, #DirBit :OR: IntLockedBit ; filecore root
        Pull    "R0-R1,PC"
05
 [ BigDir
        BL      TestBigDir
        LDREQB  LR, [R4, #BigDirAtts]
        BEQ     %FT20
 ]
        BL      TestDir              ;EQ <=> New format
        LDREQB  LR, [R4,#NewDirAtts]
 [ Debug6
        BNE     %FT01
        DREG    LR, " ", cc
        DLINE   "= New Atts"
01
 ]
        BEQ     %FT20
;here if old format
        MOV     R1, #4          ;att offsets ctr 01234 RWLDE
        MOV     LR, #0
10
        LDRB    R0, [R4,R1]
        MOVS    R0, R0, LSR #8  ;C=Attribute bit
        ADC     LR, LR, LR      ;shift previous bits left 1 and add in this bit
        SUBS    R1, R1, #1
        BPL     %BT10

        TSTS    LR, #EBit       ;give old E files read access
        BIC     LR, LR, #EBit
        ORRNE   LR, LR, #ReadBit
 [ Debug6
        DREG    LR, " ", cc
        DLINE   "= Old Atts"
 ]
20
        TSTS    LR, #DirBit
 [ FullAtts
        ASSERT  IntAttMask = &FF
 |
        ANDEQ   LR, LR, #IntAttMask
 ]
        ANDNE   LR, LR, #IntDirAttMask
95
        Pull    "R0-R1,PC"


; ===========
; ReadExtAtts
; ===========

; read attributes from directory entry in external format

; entry: R3 = disc address of dir
;        R4 ->entry

 [ FullAtts
; exit:  LR has attributes,  bits 7-0 7654L0WR
 |
; exit:  LR has attributes,  bits 7-0 L0WRL0WR
 ]

ReadExtAtts ROUT
        Push    "LR"
        BL      ReadIntAtts     ;(R3,R4->LR)
        ASSERT  ReadBit=1
        ASSERT  WriteBit=2
        ASSERT  IntLockedBit=4
        BIC     LR, LR, #DirBit
        ASSERT  ExtLockedBit=IntLockedBit :SHL: 1  ;move locked bit
        ADD     LR, LR, #IntLockedBit
        BIC     LR, LR, #IntLockedBit
 [ :LNOT: FullAtts
        ORR     LR, LR, LR, LSL #4      ;repeat bottom nibble in next nibble
 ]
        Pull    "PC"

; =========
; WriteLoad
; =========

; Write Load address of directory entry

; entry: R0=Load Address
;        R3= dir indirect disc address
;        R4->dir entry

WriteLoad ROUT
 [ Debug6
        DLINE   "Load add|dir ptr - enter WriteLoad"
        DREG    R0, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R1,LR"
 [ BigDir
        BL      TestBigDir              ;(R3->Z)
        BEQ     %FT10
 ]
        BL      ReadLoad                ;(R3,R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BLNE    InvalidateBufDir
        MOVNE   R1,R0
        ADDNE   R0,R4,#DirLoad
        WriteWord NE
        Pull    "R0-R1,PC"

 [ BigDir
10
        BL      ReadLoad                ;(R3,R4->LR)
        TEQS    R0,LR                   ;nothing to do if changed
        BLNE    InvalidateBufDir
        STRNE   R0, [R4, #BigDirLoad]
        Pull    "R0-R1,PC"
 ]

; =========
; WriteExec
; =========

; Write Exec address of directory entry

; entry: R0=Exec Address, R4->dir entry

WriteExec ROUT
 [ Debug6
        DLINE   "Exec add|dir ptr - enter WriteExec"
        DREG    R0, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R1,LR"
 [ BigDir
        BL      TestBigDir
        BEQ     %FT10
 ]
        BL      ReadExec                ;(R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BLNE    InvalidateBufDir
        MOVNE   R1,R0
        ADDNE   R0,R4,#DirExec
        WriteWord NE
        Pull    "R0-R1,PC"

 [ BigDir
10
        BL      ReadExec                ;(R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BLNE    InvalidateBufDir
        STRNE   R0, [R4, #BigDirExec]
        Pull    "R0-R1,PC"
 ]

; ========
; WriteLen
; ========

; Write file length to directory entry

; entry: R0=length
;        R3= dir indirect disc address
;        R4->dir entry

WriteLen ROUT
 [ Debug6
        DLINE   "Length  |dir ptr - enter WriteLen"
        DREG    R0, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R1,LR"
 [ BigDir
        BL      TestBigDir
        BEQ     %FT10
 ]
        BL      ReadLen                 ;(R3,R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BLNE    InvalidateBufDir
        MOVNE   R1,R0
        ADDNE   R0,R4,#DirLen
        WriteWord NE
        Pull    "R0-R1,PC"

 [ BigDir
10
        BL      ReadLen                 ;(R3,R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BLNE    InvalidateBufDir
        STRNE   R0, [R4, #BigDirLen]
        Pull    "R0-R1,PC"
 ]

; ===============
; WriteIndDiscAdd
; ===============

; Write file disc address to directory entry

; entry:
;  R0=disc address
;  R4->dir entry

 [ BigDir
;  R5->dir start (only if dir is big)
 ]

WriteIndDiscAdd ROUT
 [ Debug6
        DLINE   "Disc add|dir ptr - enter WriteDiscAdd"
        DREG    R0, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R1,LR"
        BL      ReadIndDiscAdd          ;(R4->LR)
        TEQS    R0,LR                   ;nothing to do if unchanged
        BEQ     %FT95
        BL      InvalidateBufDir
        BIC     R1,R0,#DiscBits
 [ BigDir
        BL      TestBigDir
        STREQ   R1, [R4, #BigDirIndDiscAdd]
        BEQ     %FT95
 ]
        BL      TestMap                 ;(R3->Z)
        MOVNE   R1,R1,LSR #8
        ADD     R0,R4,#DirIndDiscAdd
        Write3
95
        CLRV
        Pull    "R0-R1,PC"


; ============
; WriteExtAtts
; ============

; entry: R0=atts, R3=dir disc address, R4->dir entry

; write attributes from external format to dir entry

WriteExtAtts ROUT
        Push    "R0,LR"
;first convert to internal format
        AND     R0, R0, #ExtAttMask
        ASSERT  ExtLockedBit=IntLockedBit :SHL: 1
        TSTS    R0, #ExtLockedBit
        EORNE   R0, R0, #ExtLockedBit :EOR: IntLockedBit
        BL      WriteIntAtts    ;(R0,R3,R4)
        Pull    "R0,PC"


; ============
; WriteIntAtts
; ============

; write attributes from internal format to dir entry

; entry: R0=atts, R3=dir disc address, R4->dir entry

WriteIntAtts ROUT
 [ Debug6
        DLINE   "Atts    |dir add |dir ptr - enter WriteIntAtts"
        DREG    R0, " ", cc
        DREG    R3, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R2,R4,LR"
        BL      ReadIntAtts     ;(R3,R4->LR) read old atts
        TSTS    LR, #DirBit
        BICNE   R1, LR, #IntLockedBit :OR: NewAtts :OR: ReadBit :OR: WriteBit
        ANDNE   R0, R0, #IntLockedBit :OR: NewAtts
        ORRNE   R0, R1, R0
        ANDEQ   R0, R0, #IntAttMask :EOR: DirBit
        TEQS    R0, LR
        Pull    "R0-R2,R4,PC",EQ        ;no change
SetAttsCommon
        BL      InvalidateBufDir
 [ BigDir
        BL      TestBigDir
        STREQB  R0, [R4,#BigDirAtts]    ; write atts
        Pull    "R0-R2,R4,PC",EQ
 ]
        BL      TestDir
        STREQB  R0, [R4,#NewDirAtts]
;fall through rest if new format (EQ)
 [ FullAtts
        BICNE   R0, R0, #NewAtts        ;can't give full atts to old dir
 ]
        MOVNE   R1, #5
10
        LDRNEB  R2, [R4]                ;get byte from dir
        BICNE   R2, R2, #&80            ;clear old att bit
        ORRNE   R2, R2, R0, LSL #7      ;or in new bit
        MOVNE   R0, R0, LSR #1          ;shift new atts for next bit
        STRNEB  R2, [R4],#1             ;write back modified
        SUBNES  R1, R1, #1              ;loop until done
        BNE     %BT10
        Pull    "R0-R2,R4,PC"

; ==========
; SetIntAtts
; ==========

; write attributes from internal format to dir entry IGNORING PREVIOUS VALUE

; entry: R0=atts, R3=dir disc address, R4->dir entry

SetIntAtts ROUT
 [ Debug6
        DLINE   "Atts    |dir add |dir ptr - enter SetIntAtts"
        DREG    R0, " ", cc
        DREG    R3, " ", cc
        DREG    R4, " "
 ]
        Push    "R0-R2,R4,LR"
        B        SetAttsCommon


; ===========
; WriteParent
; ===========

; entry
;  R3 parent disc address
 [ BigDir
; if dir is big, then R5->dir start
 ]
;  R6 -> dir end

WriteParent
 [ Debug6
        DREG    R3, " ", cc
        DREG    R6, " ", cc
        DLINE   " WriteParent"
 ]
        Push    "R0,R1,LR"
 [ BigDir
        BL      TestBigDir
        BICEQ   R1, R3, #DiscBits
        STREQ   R1, [R5, #BigDirParent]
        Pull    "R0,R1,PC",EQ
 ]
        BL      TestDir      ;(R3->LR,Z)
        ADDEQ   R0, R6, #NewDirParent
        ADDNE   R0, R6, #OldDirParent
        BIC     R1, R3, #DiscBits
        BL      TestMap         ;(R3->Z)
        MOVNE   R1, R1, LSR #8
        Write3                  ;Parent dir disc address (R0,R1)
        Pull    "R0,R1,PC"      ; (C, V preserved)


; =======
; TestDir
; =======

; test old/new format

; entry: R3=disc address

; exit  Z=1 <=> new, C,V preserved, LR->disc rec

TestDir ROUT
        Push    "R0,LR"
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    R0, [LR,#DiscFlags]
        ASSERT  OldDirFlag<&100      ;to preserve C
        TSTS    R0, #OldDirFlag
 [ Debug6 :LAND: {FALSE}
        BNE     %FT01
        DLINE   "new dir"
        B       %FT02
01
        DLINE   "old dir"
02
 ]
        Pull    "R0,PC"


; =======
; TestMap
; =======

; test old/new format

; entry: R3=disc address

; exit  Z=1 <=> new, C,V preserved, LR->disc rec

TestMap ROUT
        Push    "R0,LR"
        BL      DiscAddToRec            ;(R3->LR)
        LDRB    R0, [LR,#DiscFlags]
        ASSERT  OldMapFlag<&100      ;to preserve C
        TSTS    R0, #OldMapFlag
 [ DebugE
        BNE     %FT01
        DLINE   "test new map"
        B       %FT02
01
        DLINE   "test old map"
02
 ]
        Pull    "R0,PC"



HugoNick
 = "Hugo"
 = "Nick"


; ========
; CheckDir
; ========

; Check dir is well formed

; entry: R3=dir disc add, R5->dir start, R6->dir end

; exit:  IF error V set, R0 result

CheckDir ROUT
 [ Debug6; :LAND: {FALSE}
        DLINE    ,"dir add |dir beg |dir end - enter CheckDir"
        DREG    R3, " ",cc
        DREG    R5, " ",cc
        DREG    R6, " "
 ]
        Push    "R0,R1,R10,R11,LR"
        MOV     R10,#1
CheckDirCommon
 [ BigDir
        BL      TestBigDir              ; is it a big directory?
        BNE     %FT01
        BL      CheckBigDir             ;(R3,R5,R6,R10->R0,V)
        MOVVC   R0,#0
        B       %FT95
01      ; not a big dir
 ]
        ADD     R0, R5, #StartName      ;Check start string
        ReadWord                        ;(R0->LR)
        baddr   R1, HugoNick
        LDMIA   R1, {R1,R11}
        TEQS    LR, R1
        MOVNE   R1, R11
        TEQNES  LR, R11

 [ Debug6; :LAND: {FALSE}
        BEQ     %FT01
        DLINE   "Failed at HugoNick"
01
 ]

        LDREQB  R0, [R5,#StartMasSeq]   ;Check master sequence numbers match
        LDREQB  LR, [R6,#EndMasSeq]
        TEQS    R0, LR

 [ Debug6; :LAND: {FALSE}
        BEQ     %FT01
        DLINE   "Failed at sequences"
01
 ]

        ADDEQ   R0, R6, #EndName        ;Check end string
        ReadWord EQ                     ;(R0->LR)
        TEQEQS  LR, R1
 [ Debug6; :LAND: {FALSE}
        BEQ     %FT01
        DLINE   "Failed at EndName"
01
 ]
        BNE     %FT90

        MOVS    R10,R10                 ;quick flag
        BLNE    TestDirCheckByte        ;(R3,R5,R6->LR,Z)
        BNE     %FT90

        BL      TestDir                 ;(R3->LR,Z)
        LDREQB  R0, [R6,#NewDirLastMark]
        LDRNEB  R0, [R6,#OldDirLastMark]
        TEQS    R0, #0
 [ Debug6; :LAND: {FALSE}
        BEQ     %FT01
        DLINE   "Failed at LastMark"
01
 ]
90
        BEQ     %FT95
        MOV     R0, #BrokenDirErr
        LDR     LR, BufDir
        TEQS    LR, R3
        BLEQ    InvalidateBufDir
        BEQ     %FT95
        BL      TryCache                ;(R3->R11,V)
        BLVC    InvalidateDirCache      ;if a dir in cache is broken, scrap whole cache
95
        BL      SetVOnR0
        STRVS   R0, [SP]
 [ Debug6; :LAND: {FALSE}
        DLINE   "dir add |dir beg |dir end |result - leave CheckDir"
        DREG    R3, " ",cc
        DREG    R5, " ",cc
        DREG    R6, " ",cc
        BVC     %FT01
        DREG    R0," "
01
 ]
        Pull    "R0,R1,R10,R11,PC"



; =============
; QuickCheckDir
; =============

; Check dir is well formed, excluding check byte

; entry: R3=dir disc add, R5->dir start, R6->dir end

; exit:  IF error V set, R0 result

QuickCheckDir ROUT
 [ Debug6
        DLINE   "dir add |dir beg |dir end - enter CheckDir"
        DREG    R3, " ", cc
        DREG    R5, " ", cc
        DREG    R6, " "
 ]
        Push    "R0,R1,R10,R11,LR"
        MOV     R10,#0
        B       CheckDirCommon

; ============
; IncDirSeqNum
; ============

; Increment dir master seqence number, also invalidates dir buffer

; entry:
;  R5 -> dir start
;  R6 -> dir end

 [ BigDir
; R3 - dir ind disc add
 ]

IncDirSeqNum
 [ BigDir
        Push    "LR"
        BL      TestBigDir
        BEQ     %FT01
        BL      InvalidateBufDir
        BL      NextDirSeqNum           ;(R5->LR)
        STRB    LR,[R5,#StartMasSeq]
        STRB    LR,[R6,#EndMasSeq]
        Pull    "PC"
01
        BL      InvalidateBufDir
        BL      NextDirSeqNum           ;(R5->LR)
        STRB    LR,[R5,#BigDirStartMasSeq]
        STRB    LR,[R6,#BigDirEndMasSeq]
        Pull    "PC"
 |
        Push    "LR"
        BL      InvalidateBufDir
        BL      NextDirSeqNum           ;(R5->LR)
        STRB    LR,[R5,#StartMasSeq]
        STRB    LR,[R6,#EndMasSeq]
        Pull    "PC"
 ]


; ============
; IncObjSeqNum
; ============

; Increment old format object seqence number, also invalidates dir buffer

; entry:
;  R3 = dir ind disc address
;  R4 -> dir entry
;  R5 -> dir start

IncObjSeqNum
        Push    "LR"
        BL      TestDir              ;(R3->LR,Z)
        Pull    "PC",EQ
        BL      InvalidateBufDir
        BL      NextDirSeqNum           ;(R5->LR)
        STRB    LR,[R4,#OldDirObSeq]
        Pull    "PC"


; =============
; NextDirSeqNum
; =============

; calculate next BCD dir sequence number

; entry: R5 -> dir start

; exit: LR = next dir seq num

NextDirSeqNum
        Push    "R0,LR"
 [ BigDir
        ASSERT  BigDirStartMasSeq=StartMasSeq
 ]
        LDRB    LR,[R5,#StartMasSeq]    ;get old master sequence number
        ADD     LR,LR,#1                ;increment in bcd
        CMPS    LR,#&9A
        MOVHS   LR,#0
        AND     R0,LR,#&F
        CMPS    R0,#&A
        ADDHS   LR,LR,#&10-10
        Pull    "R0,PC"


; =========
; IsDirFull
; =========

; only works on dirs in buffer, not in cache

; entry:
;  R3 top 3 bits disc id
;  R5 -> dir start
;  R6 -> dir end

; exit:
;  IF full V set, R0 result

IsDirFull ROUT
        Push    "R0,LR"
        BL      EndDirEntries       ;(R3,R5,R6->R0)
        BL      TestDir          ;(R3->LR,Z)
        ADDEQ   R0,R0,#-NewDirLastMark
        ADDNE   R0,R0,#-OldDirLastMark
        CMPS    R0,R6
        MOVHS   R0,#DirFullErr
        MOVLO   R0,#0
        BL      SetVOnR0
        STRVS   R0,[SP]
 [ Debug6
        BVC     %FT01
        DLINE   "Dir full"
        B       %FT02
01
        DLINE    "Dir not full"
02
 ]
        Pull    "R0,PC"

; ============
; MakeDirSpace
; ============

; make space for a new entry in RAM copy of a directory
; ASSUMES DIR IS NOT FULL can check this with IsDirFull

; entry:

 [ BigDir
;  R1 IF DIR IS BIG, R1->term
 ]

;  R3 ind disc address
;  R4 -> entry
;  R5 -> dir start
;  R6 -> dir end

; exit: must preserve flags

MakeDirSpace ROUT
 [ NewDirEntrySz=OldDirEntrySz
        Push    "R0-R2,LR"
        SavePSR LR
        Push    lr
 [ BigDir
        BL      TestBigDir
        BNE     %FT00
        BL      MakeBigDirSpace ;different code for when a big dir.
        B       %FT05
00
 ]
        SUBS    R0, R4, #NewDirEntrySz
10                              ;search for end of entries
        LDRB    LR, [R0,#NewDirEntrySz] !
        TEQS    LR, #0
        BNE     %BT10
        STRB    LR, [R0,#NewDirEntrySz] ;will mark end of extended entry list
        ADD     R1, R4, #NewDirEntrySz  ;dest
        SUBS    R2, R0, R4      ;len
        MOVNE   R0, R4          ;source
        BLNE    BlockMove       ;dont bother to do zero length move
05
        Pull    r0
        RestPSR r0,,f
        Pull    "R0-R2,PC"

 |

        Push    "R0-R2,LR"
        SavePSR LR
        Push    lr
        BL      TestDir
        MOVEQ   R2, #NewDirEntrySz
        MOVNE   R2, #OldDirEntrySz
        SUBS    R0, R4, R2
10                              ;search for end of entries
        LDRB    LR, [R0,R2] !
        TEQS    LR, #0
        BNE     %BT10
        STRB    LR, [R0,R2]     ;will mark end of extended entry list
        ADD     R1, R4, R2      ;dest
        SUBS    R2, R0, R4      ;len
        MOVNE   R0, R4          ;source
        BLNE    BlockMove       ;dont bother to do zero length move
        Pull    r0
        RestPSR r0,,f
        Pull    "R0-R2,PC"

 ]


; ========
; WriteDir
; ========

; Write out dir in dir buffer to disc

; entry: DirBuf invalid ie &FFFFFFFF
;        ind disc address of dir in CritDirBuf

; exit:  IF error V set, R0 result

WriteDir
 [ Debug6 ;:LOR: DebugXr
        DLINE   "enter WriteDir"
 ]
        Push    "R0-R11,LR"
        LDR     r3, BufDir
        CMP     r3, #-1
        LDREQ   r3, CritBufDir
        BLEQ    EnsureNewId             ;(R3->R0,V)
        BL      DisableBreak
        BLVC    CriticalWriteDir        ;CRITICAL CODE MAY CORRUPT R1-R11
        BL      RestoreBreak
        STRVS   R0,[SP]
        Pull    "R0-R11,PC"
 [ Debug6 ;:LOR: DebugXr
        DREG    R0," ",cc
        DLINE   "leave WriteDir"
 ]

        LTORG
        END
