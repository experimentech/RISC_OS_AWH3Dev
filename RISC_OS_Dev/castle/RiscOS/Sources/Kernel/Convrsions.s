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
        TTL     => Convrsions : various number to string routines

despatchConvert ROUT

        ; Pick off the non table driven ones
        CMP     R11, #OS_ConvertVariform
        BNE     %FT10
        Push    "lr"
        BL      VariformInternal
        Pull    "lr"
        B       SLVK_TestV
10
        CMP     R11, #OS_ConvertStandardDateAndTime
        BEQ     StandardDateTime_Code
        CMP     R11, #OS_ConvertDateAndTime
        BEQ     DateTime_Code

        ASSERT  OS_ConvertFixedFileSize > OS_ConvertFixedNetStation
        CMP     R11, #OS_ConvertFixedFileSize
        BGE     FileSize_Code
        CMP     R11, #OS_ConvertFixedNetStation
        BGE     NetStation_Code

        ; Use SWI number as index into tables mapping to OS_ConvertVariform
        Push    "r0, r3-r4, lr"
        MOV     r0, sp

        SUB     r4, r11, #OS_ConvertHex1 - 3
        ADR     r14, ConvertSizesTable
        LDRB    r3, [r14, r4]
        ADR     r14, ConvertTypesTable
        LDRB    r4, [r14, r4, LSR #2]
        
        BL      VariformOutput
        ADD     sp, sp, #4
        Pull    "r3-r4, lr"
        B       SLVK_TestV

ConvertSizesTable
        DCB     0, 0, 0, 1, 2, 4, 6, 8, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4
        ASSERT  (. - ConvertSizesTable) :AND: 3 = 0
ConvertTypesTable
        DCB     ConvertToHex, ConvertToHex, ConvertToCardinal, ConvertToInteger
        DCB     ConvertToBinary, ConvertToSpacedCardinal, ConvertToSpacedInteger
        ALIGN

TenTimesTable
        DCD     1                       ; 10^0
        DCD     10
        DCD     100
        DCD     1000
        DCD     10000
        DCD     100000
        DCD     1000000
        DCD     10000000
        DCD     100000000
        DCD     1000000000              ; 10^9
TenTimesBigTable
        DCQ     10000000000             ; 10^10
        DCQ     100000000000
        DCQ     1000000000000
        DCQ     10000000000000
        DCQ     100000000000000
        DCQ     1000000000000000
        DCQ     10000000000000000
        DCQ     100000000000000000
        DCQ     1000000000000000000     ; 10^18

CommaPositions
        DCD     2_01001001001001001001001001001000

SuffixSI
        DCB     "byte"        
PrefixSI
        DCB     " kMGTPE"               ; units/kilo/mega/giga/tera/peta/exa
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; VariformInternal
; ----------------
; The guts behind OS_ConvertVariform but callable as a subroutine
; In  : R0 pointer to input value (word alignment)
;       R1 pointer to buffer
;       R2 max buffer length, or -ve to read space required
;       R3 bytes to use from input value (or nybbles if hex output reqd)
;       R4 type to convert to
; Out : R0 pointer to buffer
;       R1 pointer to terminator
;       R2 free bytes in buffer, or NOT space required if R2 -ve on entry
;       V Set if buffer overflow

VariformInternal
        ; Check if it's a read space operation
        MOVS    r2, r2
        BPL     VariformOutput

VariformCount
        ; Some of them are calculable
        TEQ     r4, #ConvertToBinary
        MOVEQ   r2, r3, LSL #3          ; 8 output chars for every 1 input byte
        BEQ     %FT30
        TEQ     r4, #ConvertToHex
        TEQNE   r4, #ConvertToHexLowercase
        MOVEQ   r2, r3, LSL #1          ; 2 output chars for every 1 input nybble
        BEQ     %FT30
        TEQ     r4, #ConvertToFixedFileSize
        MOVEQ   r2, #4 + 1 + 1 + 5      ; Always '1234 kbytes'
        BEQ     %FT30
        TEQ     r4, #ConvertToEUI
        ADDEQ   r2, r3, r3, LSL #1      ; 3 output chars for every 1 input byte (inc term)
        SUBEQ   r2, r2, #1              ; Don't count the terminator
        BEQ     %FT30
        TEQ     r4, #ConvertToUUID
        MOVEQ   r2, #(16 * 2) + 4       ; 128b in hex with 4 hyphens
        BEQ     %FT30
10
        ; A hard length to know, just do it
        Push    "r1, lr"
        SUB     sp, sp, #44             ; Longest is currently IPv6 output
        MOV     r1, sp
        MOV     r2, #44
        BL      VariformOutput
        SUB     r2, r1, r0              ; Length = term - start
        ADD     sp, sp, #44
        Pull    "r1, lr"
        ; Fall through
30
        MVN     r2, r2
40
        ADRL    r0, ErrorBlock_BuffOverflow
      [ International
        Push    "lr"
        BL      TranslateError
        Pull    "pc"
      |
        SETV
        MOV     pc, lr
      ]

VariformOutputChar
        TEQ     r2, #0
        BEQ     %BT40
        CMP     r0, #0                  ; Clears V too
        STREQB  r0, [r1]
        STRNEB  r0, [r1], #1            ; Adjust pointers except for terminating null
        SUBNE   r2, r2, #1
        MOV     pc, lr

VariformOutput ROUT
        Push    "lr"
        TEQ     r3, #0                  ; Ask for nothing, get a null string
        BNE     %FT10
        MOV     r0, #0
        BL      VariformOutputChar
        MOVVC   r0, r1
        Pull    "pc"
10
        ASSERT  ConvertToHex = 0
        CMP     r4, #(VariformHighest - VariformLowest) / 4
        ADDCC   pc, pc, r4, LSL #2
        BCS     VariBadConv
VariformLowest
        B       VariformOutputBinHex    ; ConvertToHex           
        B       VariformOutputDec       ; ConvertToCardinal      
        B       VariformOutputDec       ; ConvertToInteger       
        B       VariformOutputBinHex    ; ConvertToBinary        
        B       VariformOutputDecSpaced ; ConvertToSpacedCardinal
        B       VariformOutputDecSpaced ; ConvertToSpacedInteger
        B       VariformOutputDecPunct  ; ConvertToPunctCardinal
        B       VariformOutputDecPunct  ; ConvertToPunctInteger
        B       VariformOutputFileSize  ; ConvertToFixedFileSize
        B       VariformOutputFileSize  ; ConvertToFileSize
        B       VariformOutputDotColon  ; ConvertToIPv4          
        B       VariformOutputDotColon  ; ConvertToEUI           
        B       VariformOutputIPv6      ; ConvertToIPv6
        B       VariformOutputShortIPv6 ; ConvertToShortestIPv6  
        B       VariformOutputBinHex    ; ConvertToHexLowercase  
        B       VariformOutputUUID      ; ConvertToUUID  
VariformHighest

VariBadConv
        ADR     r0, ErrorBlock_UnConv   ; Unsupported conversion
        B       %FT20
        MakeErrorBlock UnConv
        
VariBadNumb
        ADRL    r0, ErrorBlock_BadNumb  ; Bad number
20
      [ International
        BL      TranslateError
      |
        SETV
      ]
        Pull    "pc"

VariformOutputDecPunct ROUT
        Push    "r0-r1"
        MOV     r0, #-1
        MOV     r1, #1
        SWI     XTerritory_ReadSymbols
        STRVS   r0, [sp]
        Pull    "r0-r1, pc", VS
        LDRB    r10, [r0]               ; Thousands separator
        Pull    "r0-r1"
        B       %FT10

VariformOutputDecSpaced
        MOV     r10, #' '               ; Spaces between 1000's
        B       %FT10
        
VariformOutputDec
        MOV     r10, #0                 ; No gaps between 1000's
10
        CMP     r3, #8                  ; Deal with up to 2^(8*8) or 64 bit
        BHI     VariBadNumb

        Push    "r1, r5-r9"
        ADD     r12, r0, r3             ; Input block
        MOV     r14, r3
        MOV     r5, #0
        MOV     r6, #0
20
        LDRB    r0, [r12, #-1]!
        CMP     r14, #4
        ORRHI   r6, r0, r6, LSL #8      ; Hi input word
        ORRLS   r5, r0, r5, LSL #8      ; Lo input word
        SUBS    r14, r14, #1
        BNE     %BT20

        TEQ     r4, #ConvertToInteger
        TEQNE   r4, #ConvertToSpacedInteger
        TEQNE   r4, #ConvertToPunctInteger
        BNE     %FT40                   ; Treat unsigned

        TEQ     r3, #4
        MOVEQ   r6, r5, ASR #31         ; Extend lo to hi
        ANDS    r11, r3, #3
        BEQ     %FT30                   ; For 4 & 8, no further action
        RSB     r11, r11, #4
        MOV     r11, r11, LSL #3        ; Sign extend shift of (4 - (length MOD 4)) * 8 bit
        CMP     r3, #4
        MOVHI   r6, r6, LSL r11
        MOVHI   r6, r6, ASR r11
        MOVLS   r5, r5, LSL r11
        MOVLS   r5, r5, ASR r11
        MOVLS   r6, r5, ASR #31         ; Extend lo to hi too
30
        CMP     r6, #0                  ; Is it overall negative?
        BPL     %FT50
        MOV     r0, #'-'
        BL      VariformOutputChar
        Pull    "r1, r5-r9, pc", VS
        MVN     r5, r5
        MVN     r6, r6
        ADDS    r5, r5, #1
        ADC     r6, r6, #0              ; Take ABS(r5,r6)
40
        TEQ     r6, #0
50
        MOVEQ   r11, #9                 ; Maximum power of 10 to consider
        MOVNE   r11, #18
        MOV     r9, #0                  ; Supress leading zeros
60
        MOV     r0, #'0'                ; This digit
        CMP     r11, #10
        ADRCC   r12, TenTimesTable
        LDRCC   r7, [r12, r11, LSL #2]
        MOVCC   r8, #0
        ADRCS   r12, TenTimesBigTable - (10 * 8)
        LDRCS   r7, [r12, r11, LSL #3]!
        LDRCS   r8, [r12, #4]
70
        SUBS    r5, r5, r7
        SBCS    r6, r6, r8
        ADDPL   r0, r0, #1              ; Subtracted OK
        BPL     %BT70

        ADDS    r5, r5, r7
        ADC     r6, r6, r8              ; Correct the undershoot
        TEQ     r9, #0
        SUBEQS  r9, r0, #'0'            ; Reevaluate supression if supressing
        BEQ     %FT80
        BL      VariformOutputChar
        Pull    "r1, r5-r9, pc", VS
        MOV     r14, #1
        MOV     r14, r14, LSL r11
        LDR     r0, CommaPositions
        TST     r14, r0                 ; V still clear
        MOVNE   r0, r10
        BLNE    VariformOutputChar
        Pull    "r1, r5-r9, pc", VS
80
        SUBS    r11, r11, #1
        BNE     %BT60

        ADD     r0, r5, #'0'            ; Units column is simple
        BL      VariformOutputChar
        MOVVC   r0, #0
        BLVC    VariformOutputChar 
        Pull    "r1, r5-r9, pc", VS
        Pull    "r0, r5-r9, pc"

VariformOutputFileSize ROUT
        CMP     r3, #8                  ; Deal with up to 2^(8*8) or 64 bit
        BHI     VariBadNumb
        
        Push    "r1, r5-r6"
        ADD     r12, r0, r3             ; Input block
        MOV     r14, r3
        MOV     r5, #0
        MOV     r6, #0
10
        LDRB    r0, [r12, #-1]!
        CMP     r14, #4
        ORRHI   r6, r0, r6, LSL #8      ; Hi input word
        ORRLS   r5, r0, r5, LSL #8      ; Lo input word
        SUBS    r14, r14, #1
        BNE     %BT10

        MOV     r10, #0                 ; SI unit index
20
        CMP     r6, #1
        CMPCC   r5, #4096               ; Keep dividing until < 4096
        BCC     %FT30
        MOV     r14, r6, LSL #22
        MOV     r6, r6, LSR #10
        MOVS    r5, r5, LSR #10
        ORR     r5, r14, r5
        ADCS    r5, r5, #0              ; Round up lost bit
        ADC     r6, r6, #0
        ADD     r10, r10, #1            ; Next 10^3 up
        B       %BT20
30
        TEQ     r4, #ConvertToFileSize
        BEQ     %FT50                   ; Don't do leading spaces

        MOV     r0, #' '                ; Do leading spaces
        CMP     r5, #1000
        BLCC    VariformOutputChar
        CMP     r5, #100
        BLCC    VariformOutputChar
        CMP     r5, #10
        BLCC    VariformOutputChar
        Pull    "r1, r5-r6, pc", VS
50
        Push    "r3-r5, r10"
        ADD     r0, sp, #8              ; Use R5
        MOV     r3, #2
        MOV     r4, #ConvertToCardinal
        BL      VariformOutput
        Pull    "r3-r5, r10"

        MOVVC   r0, #' '                ; Always need that space
        BLVC    VariformOutputChar
        Pull    "r1, r5-r6, pc", VS

        ADR     r14, PrefixSI
        LDRB    r0, [r14, r10]
        TEQ     r4, #ConvertToFileSize
        MOVNE   r10, #' '
        MOVEQ   r10, #0
        TEQEQ   r0, #' '
        MOVEQ   r0, #0                  ; Supress padding SI unit too
        BL      VariformOutputChar      ; Catch overflows when doing the suffix

        LDR     r0, SuffixSI
60
        BL      VariformOutputChar
        Pull    "r1, r5-r6, pc", VS
        MOVS    r0, r0, LSR #8
        BNE     %BT60

        CMP     r5, #1                  ; I am the one and only
        MOVNE   r0, #'s'
        MOVEQ   r0, r10
        BL      VariformOutputChar

        MOVVC   r0, #0                  ; Terminate
        BLVC    VariformOutputChar
        Pull    "r1, r5-r6, pc", VS
        Pull    "r0, r5-r6, pc"

VariformOutputShortIPv6 ROUT
        TST     r3, #1                  ; Must be a halfword multiple
        BNE     VariBadNumb

        Push    "r1, r3-r9"
        MOV     r12, r0                 ; Input block
        MOV     r10, #0                 ; Index loop
        MOV     r5, #0                  ; Set thisstart = 0
        MOV     r6, #0                  ;     thisrun = 0
        MOV     r7, #0                  ; Set maxstart = length
        MOV     r8, #0                  ;     maxrun = 0
        MOV     r9, #2_10               ; Set last != 0, current = 0
10
        LDRB    r11, [r12], #1          ; Hi
        LDRB    r14, [r12], #1          ; Lo
        ORRS    r14, r14, r11, LSL #8

        ORRNE   r9, r9, #2_01
        ANDS    r9, r9, #3              
        ADDEQ   r6, r6, #1              ; Case 2_00 : last & current zero -> in a run
                                        ; Case 2_01 : last is zero, current is not -> end of a run
        CMP     r9, #2_10               ; Case 2_10 : last is nonzero, current is -> start of a run
        MOVEQ   r6, #1                  ; Case 2_11 : not interesting
        MOVEQ   r5, r10

        CMP     r6, r8                  ; max = MAX(max, this)
        MOVCS   r8, r6
        MOVCS   r7, r5                  

        MOV     r9, r9, LSL #1          ; last = current
        ADD     r10, r10, #2
        TEQ     r10, r3
        BNE     %BT10

        MOV     r4, #ConvertToIPv6
        MOV     r5, r0                  ; Keep original start
        CMP     r8, #1                  ; Longest run was only 1, don't compact this
        MOVLS   r7, r3                  ; Make maxstart = length
        BLS     %FT30

        ADD     r8, r7, r8, LSL #1      ; maxstart + maxcount
        
        SUB     r3, r3, r8              ; Do length - (maxstart + maxcount) to the end
        ADD     r0, r0, r8              ; At original start + (maxstart + maxcount)
        BL      VariformOutput

        MOVVC   r0, #':'                ; Skip maxcount, abbreviate to '::'
        BLVC    VariformOutputChar
        BLVC    VariformOutputChar
30
        MOVVC   r3, r7                  ; Lowest maxstart bytes
        MOVVC   r0, r5                  ; From original start
        BLVC    VariformOutput

        Pull    "r1, r3-r9, pc", VS
        Pull    "r0, r3-r9, pc"

VariformOutputIPv6
        TST     r3, #1                  ; Must be a halfword multiple
        BNE     VariBadNumb

        Push    "r1, r3"
        ADD     r12, r0, r3             ; Input block
10
        LDRB    r11, [r12, #-1]!        ; Hi
        LDRB    r0, [r12, #-1]!         ; Lo
        ORR     r0, r0, r11, LSL #8

        Push    "r3-r4, r12"
        MOV     r3, #1                  ; Must output at least 1 digit
        MOVS    r0, r0, LSR #4
        ADDNE   r3, r3, #1
        MOVS    r0, r0, LSR #4
        ADDNE   r3, r3, #1
        MOVS    r0, r0, LSR #4
        ADDNE   r3, r3, #1
        MOV     r4, #ConvertToHexLowercase
        MOV     r0, r12
        BL      VariformOutput          ; Up to 4 nybbles please
        Pull    "r3-r4, r12"
        Pull    "r1, r3, pc", VS

        SUBS    r3, r3, #2
        MOVNE   r0, #':'                ; Separator
20
        MOVEQ   r0, #0                  ; Terminator
        BL      VariformOutputChar
        Pull    "r1, r3, pc", VS

        TEQ     r3, #0
        Pull    "r0, r3, pc", EQ        ; Done
        B       %BT10                   ; More

VariformOutputUUID
        TEQ     r3, #16                 ; Must be exactly 128b
        BNE     VariBadNumb

        Push    "r1, r3"
        MOV     r12, r0                 ; Input block
10
        Push    "r3-r4, r12"
        MOV     r3, #2
        MOV     r4, #ConvertToHexLowercase
        MOV     r0, r12
        BL      VariformOutput          ; 2 lowercase nybbles please
        Pull    "r3-r4, r12"
        Pull    "r1, r3, pc", VS

        TEQ     r3, #17 - 4
        TEQNE   r3, #17 - 6
        TEQNE   r3, #17 - 8
        TEQNE   r3, #17 - 10
        MOVEQ   r0, #"-"                ; Separator
        BLEQ    VariformOutputChar
20
        SUBS    r3, r3, #1
        ADDNE   r12, r12, #1
        BNE     %BT10                   ; More

        MOV     r0, #0                  ; Terminator
        BL      VariformOutputChar
        Pull    "r1, r3, pc", VS
        Pull    "r0, r3, pc"            ; Done

VariformOutputDotColon ROUT
        Push    "r1, r3-r4"
        ADD     r12, r0, r3             ; Input block
        TEQ     r4, #ConvertToIPv4
        MOVEQ   r4, #ConvertToCardinal
        MOVEQ   r10, #'.'
        MOVNE   r4, #ConvertToHex
        MOVNE   r10, #':'
10
        LDRB    r11, [r12, #-1]!        ; Not actually used

        Push    "r3, r10, r12"
        TEQ     r4, #ConvertToHex
        MOVEQ   r3, #2                  ; Two nybbles please
        MOVNE   r3, #1                  ; One octet please
        MOV     r0, r12
        BL      VariformOutput
        Pull    "r3, r10, r12"
        Pull    "r1, r3-r4, pc", VS

        SUBS    r3, r3, #1
        MOVNE   r0, r10                 ; Separator
        MOVEQ   r0, #0                  ; Terminator
        BL      VariformOutputChar
        Pull    "r1, r3-r4, pc", VS

        TEQ     r3, #0
        Pull    "r0, r3-r4, pc", EQ     ; Done
        B       %BT10                   ; More

VariformOutputBinHex ROUT
        Push    "r1, r5"
        TEQ     r4, #ConvertToBinary
        MOVEQ   r5, #1                  ; Step size in bits
        MOVNE   r5, #4
        ADDEQ   r12, r0, r3             ; Input block
        ADDNE   r12, r3, #1
        ADDNE   r12, r0, r12, LSR #1    ; Input block adjusted for nybbles and bytes
        MOVEQ   r10, r3, LSL #3
        MOVNE   r10, r3, LSL #2         ; Total bit count
10
        TEQ     r10, #0
        BNE     %FT20
        MOV     r0, #0
        BL      VariformOutputChar      ; Terminate even if nothing
        Pull    "r1, r5, pc", VS
        Pull    "r0, r5, pc"
20
        LDRB    r11, [r12, #-1]!        ; Current byte
        TST     r10, #7
        MOVEQ   r11, r11, LSL #24       ; Work at top for LSL and LSR
        MOVNE   r11, r11, LSL #28       ; Partial nybble
30
        RSB     r0, r5, #32             ; Shift of 8 - step + 24
        MOV     r0, r11, LSR r0
        CMP     r0, #10
        ADDCC   r0, r0, #'0'
        ADDCS   r0, r0, #'A' - 10
        TEQ     r4, #ConvertToHexLowercase
        ORREQ   r0, r0, #&20            ; Lowercasify (0-9 unaffected)
        BL      VariformOutputChar
        Pull    "r1, r5, pc", VS

        MOV     r11, r11, LSL r5
        SUB     r10, r10, r5
        TST     r10, #7
        BNE     %BT30
        B       %BT10                   ; Either the end or need a new byte

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OS_BinaryToDecimal
; ------------------
; Convert int32_t to string SWI (with no terminator)
; prefixed '-' if negative, leading zeros always stripped.
; In  : R0 signed 32-bit integer
;       R1 pointer to buffer
;       R2 max buffer length
; Out : R0, R1 unmodified
;       R2 actual chars given
;       V Set if buffer overflow

BinaryToDecimal_Code ROUT
        Push    "R0, R3-R5"
        MOV     R12, R2                 ; Keep buffer length
        MOV     R2, #0
        CMP     R0, #0
        BPL     %FT01
        SUBS    R12, R12, #1            ; Check enough buffer for '-'
        BMI     %FT10
        MOV     R11, #"-"
        STRB    R11, [R1]               ; Place the '-'
        MOV     R2, #1
        RSB     R0, R0, #0

        ; now do digits.
01      RSB     R0, R0, #0              ; get negative so minint works.
        ADRL    R3, TenTimesTable
        MOV     R10, #9                 ; max entry 10^9
        MOV     R4, #0                  ; non-0 had flag
02      LDR     R11, [R3, R10, LSL #2]
        MOV     R5, #-1                 ; digit value
03      ADDS    R0, R0, R11
        ADD     R5, R5, #1
        BLE     %BT03
        SUB     R0, R0, R11
        CMP     R5, #0
        CMPEQ   R4, #0
        BNE     %FT05                   ; put digit
04      SUBS    R10, R10, #1
        BPL     %BT02                   ; next digit
        CMP     R4, #0
        BEQ     %FT05                   ; finished, nothing output, must be '0'
        Pull    "R0, R3-R5"
        B       SLVK

05      SUBS    R12, R12, #1
        BMI     %FT10                   ; naff Exit
        ADD     R5, R5, #"0"
        MOV     R4, #-1                 ; set flag, a non-zero had
        STRB    R5, [R1, R2]
        ADD     R2, R2, #1
        B       %BT04
10
        ADRL    R0, BufferOFloError
    [ International
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
    ]
        ADD     SP, SP, #4              ; discard R0 in
        Pull    "R3-R5"
        B       SLVK_SetV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OS_ConvertFileSize
; OS_ConvertFixedFileSize
; -----------------------
; Do length as xxxx bytes or xxxx kbytes or xxxx Mbytes
; In  : R0 file size in bytes
;       R1 pointer to buffer
;       R2 max buffer length
; Out : R0 pointer to buffer
;       R1 pointer to terminator
;       R2 free bytes in buffer
;       V Set if buffer overflow

FileSize_Code ROUT
        Push    "r0, r3-r4, lr"
        MOV     r0, sp

        MOVEQ   r4, #ConvertToFixedFileSize
        MOVNE   r4, #ConvertToFileSize

        MOV     r3, #4                  ; Always 4 bytes
        
        BL      VariformOutput
        ADD     sp, sp, #4
        Pull    "r3-r4, lr"
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OS_ConvertNetStation
; OS_ConvertFixedNetStation
; -------------------------
; EcoNet conversions of the form 'nnn.sss' for the fixed variant, or shorter
; In  : R0 pointer to two word net/station number block
;       R1 pointer to buffer
;       R2 max buffer length
; Out : R0 pointer to buffer
;       R1 pointer to terminator
;       R2 free bytes in buffer
;       V Set if buffer overflow

rStn    RN      10
rNet    RN      12
NetStation_Code ROUT
        Push    "r1, r9, lr"

        ASSERT  rStn < rNet
        LDMIA   r0, { rStn, rNet }
        CMP     rNet, #256
        ADRCS   r0, ErrorBlock_BadNetwork
        BCS     %FT40

        CMP     rStn, #0
        CMPNE   rStn, #256
        ADRCS   r0, ErrorBlock_BadStation
        BCS     %FT40

        TEQ     r11, #OS_ConvertNetStation
        MOVNE   r9, #' '                ; Select padding
        MOVEQ   r9, #0
        BL      NetToDec
        BVS     %FT30

        MOV     r0, #'.'                ; Dot normally
        CMP     rNet, #1                ; Prepare carry
        TEQ     r11, #OS_ConvertNetStation
        BNE     %FT10
        MOVCC   r0, #0                  ; Nothing for net of zero
        MOV     r9, #0                  ; Then no padding regardless
        B       %FT20
10
        MOVCC   r0, #' '                ; Space next if net of zero
        MOVCC   r9, #' '                ; Prepad with space
        MOVCS   r9, #'0'                ; or 0
20
        BL      VariformOutputChar
        MOVVC   rNet, rStn
        BLVC    NetToDec                ; Includes terminator
30
        Pull    "r0, r9, lr", VC
        Pull    "r1, r9, lr", VS
        B       SLVK_TestV
40
      [ International
        BL      TranslateError
        Pull    "r1, r9, lr"
        B       SLVK_SetV
      |
        Pull    "r1, r9, lr"
        B       SLVK_SetV
      ]

NetToDec
        Push    "lr"
        MOV     r0, r9
        CMP     rNet, #100
        BLCC    VariformOutputChar
        CMP     rNet, #10
        BLCC    VariformOutputChar

        TEQ     rNet, #0                ; Can't have a station of zero anyway
        BNE     %FT50
        BL      VariformOutputChar      ; Pad instead of "0"
        Pull    "pc"
50
        MOV     r0, rNet
        SWI     XOS_ConvertCardinal1
        Pull    "pc"

        MakeInternatErrorBlock BadNetwork,,BadNet        

        MakeInternatErrorBlock BadStation,,BadStn

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OS_ConvertStandardDateAndTime
; -----------------------------
; Convert from 5-byte cs representation to format specified in <SYS$DateFormat>
; In  : R0 -> time block
;       R1 -> buffer to accept conversion
;       R2 = size of buffer
;
; Out : R0 = input value of R1, or error block
;       R1 = updated pointer to buffer
;       R2 = updated size of buffer
;       V Set if error

StandardDateTime_Code ROUT
        Push    "R3, R14"
        MOVS    R3, R2                  ; Territory SWI wants things one register up
        BMI     %FT10                   ; Actively reject unlikely buffer sizes        
        MOV     R2, R1
        MOV     R1, R0
        MOV     R0, #-1                 ; Use configured territory
        SWI     XTerritory_ConvertStandardDateAndTime
        Pull    "R3, R14"
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; OS_ConvertDateAndTime
; ---------------------
; Convert from 5-byte cs representation to format specified by user
; In  : R0 -> time block
;       R1 -> buffer to accept conversion
;       R2 = size of buffer
;       R3 -> format string
;
; Out : R0 = input value of R1, or error block
;       R1 = updated pointer to buffer
;       R2 = updated size of buffer
;       V Set if error

DateTime_Code
        Push    "R3-R4, R14"
        MOV     R4, R3                  ; Territory SWI wants things one register up.
        MOVS    R3, R2
        BMI     %FT10                   ; Actively reject unlikely buffer sizes
        MOV     R2, R1
        MOV     R1, R0
        MOV     R0, #-1                 ; Use configured territory.
        SWI     XTerritory_ConvertDateAndTime
        Pull    "R3-R4, R14"
        B       SLVK_TestV
10
        ADRL    R0, ErrorBlock_BuffOverflow
      [ International
        BL      TranslateError
      ]
        B       SLVK_SetV

        END
