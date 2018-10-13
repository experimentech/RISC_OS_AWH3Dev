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

; Time and date routines for territory.

        MACRO
        CDATT   $mnemonic, $stackoffset, $digits
        ASSERT  (:LEN: "$mnemonic") = 2
        ASSERT  ((CDAT$mnemonic-(CDATBranch+8)) :AND: &FFFFFC03) = 0
        ASSERT  ($stackoffset >=0) :LAND: ($stackoffset < 64)
        LCLA    digits
        [       "$digits"=""
digits  SETA    2
        |
digits  SETA    $digits
        ]
        ASSERT  (digits >= 1) :LAND: (digits <= 3)

        DCB     digits :OR: ($stackoffset :SHL: 2)
        DCB     (CDAT$mnemonic-(CDATBranch+8)) :SHR: 2
        =       "$mnemonic"
        MEND

        MACRO
        Dec2Int $res, $buffer, $offset, $ten, $tmp
        LDRB    $res, [$buffer, #0 + $offset]
        SUB     $res, $res, #'0'
        LDRB    $tmp, [$buffer, #1 + $offset]
        SUB     $tmp, $tmp, #'0'
        MLA     $res, $ten, $res, $tmp  ; (10 * 0th byte) + 1st
        MEND

tickspersecond  * 100
ticksperminute  * tickspersecond * 60
ticksperhour    * ticksperminute * 60
ticksperday     * ticksperhour   * 24
ticksperyear    * ticksperday    * 365  ; &BBF81E00


;--------------------------------------------------------------
; MessageLookup
; In:
;     R4 -> token
; Out:
;     R4 -> Translated message.
;
MessageLookup

        Push    "r0-r7,LR"

        BL      open_messages_file
        Pull    "r0-r7,pc",VS
        ADR     R0,message_file_block
        MOV     R1,R4
        ADR     R2,scratch_buffer
        MOV     R3,#?scratch_buffer
        MOV     R4,#0
        MOV     R5,#0
        MOV     R6,#0
        MOV     R7,#0
        SWI     XMessageTrans_Lookup
        STRVS   r0,[sp]
        Pull    "r0-r7,PC",VS

        ADR     R4,scratch_buffer
        STR     R4,[SP,#4*4]

        Pull    "r0-r7,PC"

;---------------------------------------------------------------
; GetTimeValues
; In:
;     R1 -> UTC Time value
;     R2  = offset from UTC to local time
; Out:
;     R0  = Day of month       ; All values are LOCAL time.
;     R1  = Month
;     R2  = Week of year
;     R3  = Day of year
;     R4  = Day of week
;     R5  = Year (HI)
;     R6  = Year (LO)
;     R7  = Hours
;     R8  = Minutes
;     R9  = Centiseconds
;     R10 = Seconds
GetTimeValues
        Push    "R14"

        LDRB    R4, [R1, #0]            ; read the 5 byte value to convert
        LDRB    R5, [R1, #1]
        ORR     R4, R4, R5, LSL #8
        LDRB    R5, [R1, #2]
        ORR     R4, R4, R5, LSL #16
        LDRB    R5, [R1, #3]
        ORR     R4, R4, R5, LSL #24     ; R4 contains bottom 4 bytes
        LDRB    R5, [R1, #4]            ; R5 contains 5th byte

        ; add signed time offset from UTC
        
        MOV     R0,R2,ASR #31           ; Sign extend to 2 words.
        ADDS    R4,R4,R2
        ADC     R5,R5,R0

        MOV     R6, R4, LSR #8
        ORR     R6, R6, R5, LSL #24     ; R6 := centiseconds DIV 256
        ASSERT  ticksperday:MOD:256 = 0
        LDR     R7, =ticksperday/256
        DivRem  R8, R6, R7, R9          ; R8 = number of days since 1900
        AND     R4, R4, #&FF            ; R4 := centiseconds MOD 256
        ORR     R6, R4, R6, LSL #8      ; R6 := centiseconds today

        ; first work out bits from R6

        LDR     R7, =ticksperhour
        DivRem  R4, R6, R7, R9          ; R4 := hours
        LDR     R7, =ticksperminute
        DivRem  R5, R6, R7, R9          ; R5 := minutes
        LDR     R7, =tickspersecond
        DivRem  R10, R6, R7, R9         ; R10 := seconds
                                        ; R6 := centiseconds
        Push    "R4,R5,R6,R10"

        ; now work out bits from R8

        ADD     R11, R8, #1             ; R11 := fudged copy of days since 1900
        MOV     R5, #7
        DivRem  R6, R11, R5, R7         ; R11 := days MOD 7 (ie day of week)
        ADD     R11, R11, #1            ; make in range 1..7

        MOV     R5, #00                 ; units of years = 00
        MOV     R4, #19                 ; hundreds of years = 19
10
        MOV     R6, #0                  ; 0 if not a leap year
        TST     R5, #3                  ; if not divis by 4 then not leap year
        BNE     %FT30
        TEQ     R5, #0                  ; elif not divis by 100 then leap
        BNE     %FT20
        TST     R4, #3                  ; elif not divis by 400 then not leap
        BNE     %FT30
20
        MOV     R6, #1                  ; 1 if leap year
30
        LDR     R7, =365                ; normally take off 365 days per year
        ADD     R7, R7, R6              ; extra day if leap year

        SUBS    R8, R8, R7              ; try taking off 365 or 366 days
        BCC     %FT40                   ; [failed the subtract]
        ADD     R5, R5, #1              ; increment year if successful
        CMP     R5, #100
        MOVEQ   R5, #0
        ADDEQ   R4, R4, #1
        B       %BT10

40
        ADD     R8, R8, R7              ; add back on if we couldn't do it
                                        ; R8 is day of year (0..365)
        Push    "R4,R5"                 ; push yearhi, yearlo

        ADD     R7, R8, #1              ; R7 = day number in range 1-366
        Push    "R7, R11"               ; push d-o-y, d-o-w

        ; now compute week number

        SUBS    R7, R11, #2             ; dow (Sun=-1, Mon=0,... ,Sat=5)
        ADDCC   R7, R7, #7              ; dow (Mon=0,... ,Sun=6)
        SUB     R7, R8, R7              ; day-of-year no. of start of week

        ADD     R7, R7, #6              ; work out week number as if
                                        ; 1st part week is week 0
        MOV     R10, #7
        DivRem  R11, R7, R10, R9        ; R11 = week number (0..53)
                                        ; R7 (remainder) indicates dayofweek
                                        ; of start of year (Mon=6,Tue=5..Sun=0)
        CMP     R7, #3                  ; if year starts on Mon..Thu
        ADDCS   R11, R11, #1            ; then 1st part week is week 1

        TEQ     R7, #4                  ; if a Wednesday
        TEQEQ   R6, #1                  ; in a leap year
        TEQNE   R7, #3                  ; or a Thursday in any year
        MOVEQ   R9, #53                 ; then allow 53 weeks in year
        MOVNE   R9, #52                 ; else only 52 weeks
        CMP     R11, R9                 ; if more than this
        MOVHI   R11, #1                 ; then week 1 of next year

        TEQ     R11, #0                 ; if not week 0
        BNE     %FT45                   ; then finished

        CMP     R7, #1                  ; HI => Fri, EQ => Sat, CC => Sun
        ADC     R11, R11, #52           ; Fri => 53, Sun => 52, Sat => dunno
        BNE     %FT45

        ; 1st day of year is Saturday
        ; if previous year was leap, then is week 53, else is week 52

        SUBS    R5, R5, #1              ; decrement year
        MOVCC   R5, #99
        SUBCC   R4, R4, #1

        TST     R5, #3                  ; if not divis by 4 then not leap year
        BNE     %FT42
        TEQ     R5, #0                  ; elif not divis by 100 then leap
        BNE     %FT45
        TST     R4, #3                  ; elif not divis by 400 then not leap
42
        MOVNE   R11, #52                ; not leap, so must be week 52
45
        Push    "R11"                   ; push weekno

        ADRL    R7, MonthLengths+1      ; R7 -> Jan(31) (Feb is stored as 29)
        EOR     R6, R6, #1              ; R6 = 1 <=> not a leap year
        MOV     R9, #1                  ; month number (1 = Jan)
50
        LDRB    R10, [R7], #1           ; get next month
        CMP     R9, #2                  ; if we're trying for Feb
        SUBEQ   R10, R10, R6            ; and not leap then subtract a day
        SUBS    R8, R8, R10             ; subtract off month value
        ADDCS   R9, R9, #1              ; if successful month +:= 1
        BCS     %BT50

        ADD     R8, R8, R10             ; add the month back on if we failed
        ADD     R8, R8, #1              ; day of month in range 1..31

        Push    "R8,R9"                 ; push d-o-m, month

        CLRV
        Pull    "R0-R10,PC"

      [ JapaneseEras

;---------------------------------------------------------------
; GetJapaneseEra
; In:
;     R0   =   Day of month
;     R1   =   Month
;     R5   =   Year (HI)
;     R6   =   Year (LO)
;     R7   =   Hours
; Out:
;     R0   =   Era number
;     R1   =   Years into era
GetJapaneseEra ROUT
        Entry   "R2,R3,R8"
        MOV     R14,#100
        MLA     R8,R14,R5,R6            ; R8 = year
        Debug   dt,"J: Year is ",R8

        ADR     R14,era_table + era_datasize
        MOV     R3,#1

05      LDR     R2,[R14,#era_year]      ; R2 = start year of next era
        Debug   dt,"J: Era ",R3
        Debug   dt,"J: Ends in ",R2
        TEQ     R2,#0
        BEQ     %FT20                   ; end of table - got it

        CMP     R8,R2
        BLO     %FT20                   ; era ends after this year - got it
10      ADDHI   R3,R3,#1                ; era ends before this year - try next
        ADDHI   R14,R14,#era_datasize
        BHI     %BT05
        ; era ends this year
        LDR     R2,[R14,#era_month]
        CMP     R1,R2
        BHI     %BT10                   ; era ends before this month - try next
        BLO     %FT20                   ; era ends after this month - got it
        ; era ends this month
        LDR     R2,[R14,#era_day]
        CMP     R0,R2
        BHI     %BT10                   ; era ends before this day - try next
        BLO     %FT20                   ; era ends after this day - got it
        ; era ends today (assume only one era change per day :)
        CMP     R7,#11                  ; are we after noon?
        BHI     %BT10                   ; era has ended - get next

20
        MOV     R0,R3                   ; R0 = era number
        LDR     R1,[R14,#era_year - era_datasize]
        SUB     R1,R8,R1
        ADD     R1,R1,#1                ; R1 = era year
        EXIT

;---------------------------------------------------------------
; SetUpEras
;
; Initialise the era array by reading the messages file
;
        ASSERT  max_eras > 7
        ASSERT  era_day = 0
        ASSERT  era_month = 4
        ASSERT  era_year = 8
        ASSERT  era_datasize = 12

SetUpEras ROUT
        Entry   "R0-R7",64+28
        ADR     R7,era_table
        MOV     R6,#0
        ADR     R5,EraStartTable

05      ADD     R4,R5,R6,LSL #2         ; look up token "JS<n>"
        BL      MessageLookup
        BVS     %FT20

        MOV     R1,R13
10      LDRB    R0,[R4],#1              ; copy onto stack - ConvertTimeStringToOrdinals
        CMP     R0,#32                  ; will trash the MessageLookup buffer
        STRHSB  R0,[R1],#1
        BHS     %BT10
        MOV     R0,#0
        STRB    R0,[R1]

        MOV     R1,#2                   ; String should be in form %W3, %DY-%M3-%CE%YR
        MOV     R2,R13                  ; in Japanese. Use this useful routine to
        ADD     R3,R13,#64              ; parse it... (Can't call SWI 'cos might not be
        BL      ConvertTimeStringToOrdinals ; registered yet...)
        BVS     %FT20

        ADD     R14,R3,#16
        LDMIA   R14,{R0-R2}
        STMIA   R7!,{R0-R2}             ; fill in day/month/year for era
        ADD     R6,R6,#1
        CMP     R6,#max_eras
        BLO     %BT05

20      MOV     R14,#0                  ; terminate the table here
        STR     R14,[R7,#era_year]
        EXIT


EraStartTable
        DCB     "JS1", 0
        DCB     "JS2", 0
        DCB     "JS3", 0
        DCB     "JS4", 0
        DCB     "JS5", 0
        DCB     "JS6", 0
        DCB     "JS7", 0

      ] ; JapaneseEras

;---------------------------------------------------------------
; Territory_ConvertDateAndTime
; Output Time in local format.
; In:
;  R1 = Pointer to 5 byte UTC time block
;  R2 = Pointer to buffer for resulting string
;  R3 = b0-b15  Size of buffer
;       b16-b27 Reserved, must be 0
;       b28     Set   => Use DST variant of timezone within territory
;       b29     Clear => R5 is an offset in centiseconds
;               Set   => R5 is a timezone within territory
;       b30     Clear => Use Territory_ReadCurrentTimezone internally
;               Set   => Use R5
;       b31     Set   => Use these flag bits
;  R4 = Pointer to format string (null terminated)
;  R5 = As defined by b29 iff b30 and b31 set
; Out:
;  R0 = Pointer to buffer (R2 on entry)
;  R1 = Pointer to terminating 0 in buffer.
;  R2 = Number of bytes free in buffer.
;  R3 = if b31 was set   R3 with b31 cleared
;              was clear R4 on entry
;  R4 - Preserved.
;  R5 - Preserved.
;
; The fields for the above are now:
;
;  CS - Centi-seconds
;  SE - Seconds
;  MI - Minutes
;  12 - Hours in 12 hour format
;  24 - Hours in 24 hour format
;  AM - AM or PM indicator in local language (may NOT be 2 characters)
;  PM - AM or PM indicator in local language (may NOT be 2 characters)
;
;  WE - Weekday in full in local language.
;  W3 - Short form of weekday name (May not be 3 characters)
;  WN - Weekday as a number
;
;  DY - Day of the month (may not be 2 characters, and may not even be
;                         numeric)
;  ST - Ordinal pre/suffix in local language (may be null)
;  MO - Month name in full
;  M3 - Short form of month name (May not be 3 characters)
;  MN - Month number.
;  CE - Century
;  YR - Year within century
;  WK - Week of the year (As calculated in the territory, may not be Mon to
;       Sun)
;  DN - Day of the year.
;  TZ - Timezone currently in effect (empty string for custom TZ)
;  0    Insert an ASCII 0 byte
;  %    Insert a '%'
;
; Special for Japan:
;
;  JE - Japanese era (Kanji)
;  J1 - Japanese era (1-letter abbrev)
;  JY - Year within Japanese era
ConvertDateAndTime ROUT

        Push    "R1-R11,R14"

        ; check for flag bits
        TST     R3, #DateAndTime_Flag_Extension
        BEQ     %FT55
        LDR     R2, =&0FFF0000          ; Reserved bits mask
        TST     R2, R3
        ADRNE   R0, ErrorBlock_CDATBadField
        BNE     CDATError
        TST     R3, #DateAndTime_Flag_UseSpecified
        BEQ     %FT55                   ; Fall back to original API
        TST     R3, #DateAndTime_Flag_SpecifyTZ
        BEQ     %FT50                   ; Given in centiseconds

        ; we're in a territory module, so when looking up the timezone
        ; within the territory it is implicitly for *this* territory

        LDR     R4, =ReadTimeZones_Extension
        MOV     R1, R5
        MOV     R5, R3
        BL      ReadTimeZones
        Pull    "R1-R11,PC",VS
        TST     R5, #DateAndTime_Flag_DST
        MOVNE   R2, R3                  ; Select DST or not
        STRNE   R1, timezone_name_ptr
        STREQ   R0, timezone_name_ptr
        B       %FT60
50
        TST     R3, #DateAndTime_Flag_DST
        ADRNE   R0, ErrorBlock_CDATBadField
        BNE     CDATError               ; Confused flag combo
        ADR     R0, NullString
        STR     R0, timezone_name_ptr
        MOV     R2, R5                  ; Use offset in R5
        B       %FT60
55
        SWI     XTerritory_ReadCurrentTimeZone
        Pull    "R1-R11,PC",VS
        STR     R0, timezone_name_ptr
        MOV     R2, R1                  ; Original API behavior
60
        LDR     R1, [SP]                ; Pointer to 5 byte value
        BL      GetTimeValues
      [ JapaneseEras
        SUB     SP, SP, #8
StackSize       * 4*13
      |
StackSize       * 4*11
      ]
        Push    "r0-r10"
      [ JapaneseEras
        BL      GetJapaneseEra
      ]
        ADD     R14,SP,#StackSize
      [ JapaneseEras
        STMDB   R14,{r0-r1}             ; tuck JE and JY at top
      ]
        LDMIA   R14,{r0-r4}             ; R0-R4 are R1-R5 on entry.
        TST     R2, #DateAndTime_Flag_Extension
        MOVNE   R2, R2, LSL #16
        MOVNE   R2, R2, LSR #16         ; knock out flags, 64k is plenty

CDATMainLoop
        SUBS    R2, R2, #1              ; decrement buffer size
        BCC     CDATBufferError         ; error: buffer too small
        LDRB    R0, [R3], #1            ; get byte from format string
        TEQ     R0, #"%"                ; is it a escape sequence ?
        BEQ     %FT65                   ; yes, then do specially
        STRB    R0, [R1], #1            ; no, then store in output buffer
        TEQ     R0, #0                  ; end of format string ?
        BNE     CDATMainLoop            ; no, then loop

        ; end of format string, so finish

        ADD     SP, SP, #StackSize + 4  ; junk dom,month,woy,doy
                                        ; junk dow,yearhi,yearlo,hours
                                        ; junk mins,secs,centisecs
                                        ; junk era,erayear
                                        ; + junk input r1
        SUB     R1, R1, #1              ; R1 := point at terminator
        Pull    "R0,R3"                 ; R0 := input R2 ready for OS_Write0
                                        ; R3 := input R3
        TST     R3, #DateAndTime_Flag_Extension
        BICNE   R3, R3, #DateAndTime_Flag_Extension
        LDREQ   R3,[SP]                 ; R3 := input R4 for old API (why??)
        Pull    "R4-R11,PC"             ; restore other registers


CDATBufferError
        ; come here if run out of buffer space for string
        ADR     R0, ErrorBlock_CDATBufferOverflow
CDATError
        ADD     SP, SP, #StackSize      ; junk dom,month,woy,doy
                                        ; junk dow,yearhi,yearlo,hours
                                        ; junk mins,secs,centisecs
                                        ; junk era,erayear
        Pull    "R1-R11,R14"            ; restore all registers apart from R0
        B       message_errorlookup

        MakeInternatErrorBlock CDATBufferOverflow,,BOvFlow

        MakeInternatErrorBlock CDATBadField,,BadFld

        ; process "%" escape sequences

65
        LDRB    R0, [R3], #1            ; get next character
        TEQ     R0, #"0"                ; if char = "0"
        MOVEQ   R0, #0                  ; convert to <0>
        TEQNE   R0, #"%"                ; or if char = "%", store "%"
        STREQB  R0, [R1], #1            ; store <0> or "%"
        BEQ     CDATMainLoop            ; and loop

        uk_UpperCase R0, R5             ; convert character to upper case
        EORS    R7, R0, #"Z"            ; zero if we have "Z" specifier
        BNE     %FT67                   ; not "Z"

        LDRB    R0, [R3], #1            ; is "Z", so get another char
        uk_UpperCase R0, R5             ; convert character to upper case
67
        TEQ     R0, #0                  ; are they a wally!
        BEQ     CDATFieldError          ; yes, then bomb out (avoid data abort)

        LDRB    R4, [R3], #1            ; get next char
        uk_UpperCase R4, R5             ; and convert that to upper case

        ORR     R0, R0, R4, LSL #8      ; 2 chars in bottom two bytes

        ADR     R4, CDATEscTab          ; point to table
        ADR     R5, CDATEscTabEnd       ; end of table
70
        TEQ     R4, R5                  ; are we at end of table
CDATFieldError
        ADREQ   R0, ErrorBlock_CDATBadField
        BEQ     CDATError               ; yes, then invalid escape sequence
        LDR     R6, [R4], #4            ; chars in top two bytes
        EOR     R6, R6, R0, LSL #16     ; if match, then must be < 1:SHL:16
        CMP     R6, #(1 :SHL: 16)
        BCS     %BT70                   ; no match, so loop

        ; found mnemonic match

        AND     R0, R6, #&03            ; R0 = number of digits to print
        AND     R4, R6, #&FC            ; R4 = stack offset
        LDR     R4, [R13, R4]           ; R4 = data item
        MOV     R6, R6, LSR #8          ; R6 = code offset in words
CDATBranch
        ADD     PC, PC, R6, LSL #2      ; go to routine

CDATEscTab
        CDATT   DY, 0
        CDATT   ST, 0
        CDATT   MN, 1
        CDATT   MO, 1
        CDATT   M3, 1
        CDATT   WK, 2
        CDATT   DN, 3, 3
        CDATT   WN, 4, 1
        CDATT   W3, 4, 1
        CDATT   WE, 4, 1
        CDATT   CE, 5
        CDATT   YR, 6
        CDATT   24, 7
        CDATT   12, 7
        CDATT   AM, 7
        CDATT   PM, 7
        CDATT   MI, 8
        CDATT   CS, 9
        CDATT   SE, 10
        CDATT   TZ, 0
      [ JapaneseEras
        CDATT   JE, 11
        CDATT   J1, 11
        CDATT   JY, 12, 3
      ]
CDATEscTabEnd

        ; routine to print R0 digits of the number held in R4,
        ; R7=0 <=> suppress leading zeroes

CDATDY
CDATMN
CDATWK
CDATDN
CDATWN
CDATCE
CDATYR
CDAT24
CDATMI
CDATCS
CDATSE
CDATJY
CDATDecR4 ROUT
        ADD     R2, R2, #1              ; undo initial subtract
        ADR     R6, PowersOfTen
10
        MOV     R5, #0
        TEQ     R0, #1                  ; if on last digit
        MOVEQ   R7, #1                  ; definitely don't suppress
20
        LDRB    R8, [R6, R0]            ; get power of ten to subtract
        SUBS    R4, R4, R8              ; subtract value
        ADDCS   R5, R5, #1
        BCS     %BT20
        ADD     R4, R4, R8              ; undo failed subract

        ORRS    R7, R7, R5              ; Z => suppress it
        BEQ     %FT30                   ; [suppressing]

        ORR     R5, R5, #"0"            ; convert to ASCII digit
        SUBS    R2, R2, #1              ; one less space in buffer
        BCC     CDATBufferError
        STRB    R5, [R1], #1            ; store character
30
        SUBS    R0, R0, #1              ; next digit
        BNE     %BT10                   ; [another digit to do]
        B       CDATMainLoop

PowersOfTen
NullString
        DCB     0, 1, 10, 100
        ALIGN

        ; Hours in 12 hour format

CDAT12
        CMP     R4, #12                 ; if in range 12..23
        SUBCS   R4, R4, #12             ; then make in range 00..11
        TEQ     R4, #0                  ; if 00
        MOVEQ   R4, #12                 ; then make 12
        B       CDATDecR4

        ; AM or PM indication

CDATAM
CDATPM
        CMP     R4, #12                 ; if earlier than 12 o'clock
        ADRCC   R4, CDATamstr           ; then am
        ADRCS   R4, CDATpmstr           ; else pm
CDATdostr
        BL      MessageLookup           ; R4 - Pointer to string, lookup as message
        BVS     CDATError
CDATdostr1
        LDRB    R0, [R4], #1            ; get byte from string
        TEQ     R0, #0                  ; if zero, then end of string
        BEQ     CDATMainLoop            ; so loop
CDATdostrloop
        STRB    R0, [R1], #1            ; we know there's room for one char
CDATdostr2
        LDRB    R0, [R4], #1            ; get byte from string
        TEQ     R0, #0                  ; if zero, then end of string
        BEQ     CDATMainLoop            ; so loop
        SUBS    R2, R2, #1              ; dec R2 for next char
        BCS     CDATdostrloop           ; OK to do another char
        B       CDATBufferError         ; ran out of buffer space

CDATST
        TEQ     R4, #1
        TEQNE   R4, #21
        TEQNE   R4, #31
        ADREQ   R4, CDATststr
        BEQ     CDATdostr
        TEQ     R4, #2
        TEQNE   R4, #22
        ADREQ   R4, CDATndstr
        BEQ     CDATdostr
        TEQ     R4, #3
        TEQNE   R4, #23
        ADREQ   R4, CDATrdstr
        ADRNE   R4, CDATthstr
        B       CDATdostr

CDATW3
        ADRL    R0, DayNameTable-4      ; Sun is 1
        B       CDATdo3
CDATM3
        ADRL    R0, MonthNameTable-4    ; Jan is month 1
CDATdo3
        ADD     R4, R0, R4, LSL #2      ; point to short month name
        B       CDATdostr               ; then do copy

CDATWE
        ADD     R4, R4, #12             ; skip months
CDATMO
        ADR     R0, LongMonthTable-1    ; Jan is month 1
        LDRB    R4, [R0, R4]            ; get offset to month string
        ADD     R4, R0, R4              ; point to start of string
        B       CDATdostr
CDATTZ
        LDR     R4,timezone_name_ptr
        B       CDATdostr1              ; No need to look it up.

      [ JapaneseEras
CDATJ1
        ADR     R0, EraNameTable-4      ; First era is 1
        B       CDATdo3

CDATJE
        ADR     R0, LongEraNameTable-5  ; First era is 1
        ADD     R0, R0, R4, LSL #2
        ADD     R4, R0, R4
        B       CDATdostr
      ]

CDATamstr
        DCB     "am", 0
CDATpmstr
        DCB     "pm", 0
CDATststr
        DCB     "st", 0
CDATndstr
        DCB     "nd", 0
CDATrdstr
        DCB     "rd", 0
CDATthstr
        DCB     "th", 0

LongMonthTable
        DCB     LongJan-(LongMonthTable-1)
        DCB     LongFeb-(LongMonthTable-1)
        DCB     LongMar-(LongMonthTable-1)
        DCB     LongApr-(LongMonthTable-1)
        DCB     LongMay-(LongMonthTable-1)
        DCB     LongJun-(LongMonthTable-1)
        DCB     LongJul-(LongMonthTable-1)
        DCB     LongAug-(LongMonthTable-1)
        DCB     LongSep-(LongMonthTable-1)
        DCB     LongOct-(LongMonthTable-1)
        DCB     LongNov-(LongMonthTable-1)
        DCB     LongDec-(LongMonthTable-1)
        DCB     LongSun-(LongMonthTable-1)
        DCB     LongMon-(LongMonthTable-1)
        DCB     LongTue-(LongMonthTable-1)
        DCB     LongWed-(LongMonthTable-1)
        DCB     LongThu-(LongMonthTable-1)
        DCB     LongFri-(LongMonthTable-1)
        DCB     LongSat-(LongMonthTable-1)

LongJan DCB     "M01L", 0
LongFeb DCB     "M02L", 0
LongMar DCB     "M03L", 0
LongApr DCB     "M04L", 0
LongMay DCB     "M05L", 0
LongJun DCB     "M06L", 0
LongJul DCB     "M07L", 0
LongAug DCB     "M08L", 0
LongSep DCB     "M09L", 0
LongOct DCB     "M10L", 0
LongNov DCB     "M11L", 0
LongDec DCB     "M12L", 0
LongSun DCB     "D01L", 0
LongMon DCB     "D02L", 0
LongTue DCB     "D03L", 0
LongWed DCB     "D04L", 0
LongThu DCB     "D05L", 0
LongFri DCB     "D06L", 0
LongSat DCB     "D07L", 0

MonthNameTable
        DCB     "M01",0
        DCB     "M02",0
        DCB     "M03",0
        DCB     "M04",0
        DCB     "M05",0
        DCB     "M06",0
        DCB     "M07",0
        DCB     "M08",0
        DCB     "M09",0
        DCB     "M10",0
        DCB     "M11",0
        DCB     "M12",0

DayNameTable
        DCB     "D01",0
        DCB     "D02",0
        DCB     "D03",0
        DCB     "D04",0
        DCB     "D05",0
        DCB     "D06",0
        DCB     "D07",0

      [ JapaneseEras
EraNameTable
        DCB     "JE1",0
        DCB     "JE2",0
        DCB     "JE3",0
        DCB     "JE4",0
        DCB     "JE5",0
        DCB     "JE6",0
        DCB     "JE7",0
        DCB     "JE8",0

LongEraNameTable
        DCB     "JE1L",0
        DCB     "JE2L",0
        DCB     "JE3L",0
        DCB     "JE4L",0
        DCB     "JE5L",0
        DCB     "JE6L",0
        DCB     "JE7L",0
        DCB     "JE8L",0
      ]

MonthLengths
        ;       F  J  F  M  A  M  J  J  A  S  O  N  D
        DCB     28,31,29,31,30,31,30,31,31,30,31,30,31
        ALIGN

;---------------------------------------------------------------
; Territory_ConvertTimeToOrdinals
; Read Time in local format.
; In:
;  R1 = Pointer to 5 byte UTC time block
;  R2 -> Word aligned buffer to hold data
; Out:
;  R1 Preserved
;  R2 Preserved
;   [R2+0]  = CS.                       ; all values are for LOCAL time
;   [R2+4]  = Second
;   [R2+8]  = Minute
;   [R2+12] = Hour (out of 24)
;   [R2+16] = Day number in month.
;   [R2+20] = Month number in year.
;   [R2+24] = Year number.
;   [R2+28] = Day of week.
;   [R2+32] = Day of year
ConvertTimeToOrdinals
        Push    "r0-r10,LR"

        SWI     XTerritory_ReadCurrentTimeZone
        STRVS   r0,[sp]
        Pull    "r0-r10,PC",VS

        MOV     R2,R1                   ; Signed offset from...
        LDR     R1,[SP,#1*4]            ; 5 byte time
        BL      GetTimeValues

        LDR     R14,[SP,#2*4]           ; Rejumble into output format

        STR     R9,[R14],#4
        STR     R10,[R14],#4
        STR     R8,[R14],#4
        STR     R7,[R14],#4
        STR     R0,[R14],#4
        STR     R1,[R14],#4
        MOV     R1,#100
        MLA     R0,R5,R1,R6
        STR     R0,[R14],#4
        STR     R4,[R14],#4
        STR     R3,[R14]

        Pull    "r0-r10,PC"

;---------------------------------------------------------------
;ConvertOrdinalsToTime
;In:
;   r1 -> Block to contain 5 byte time.
;   r2 -> Block containing:
;      [R2+0]  = CS.                    ; all values are for LOCAL time
;      [R2+4]  = Second
;      [R2+8]  = Minute
;      [R2+12] = Hour (out of 24)
;      [R2+16] = Day number in month.
;      [R2+20] = Month number in year.
;      [R2+24] = Year number.
;Out:
;  r1,r2 preserved.
;  [r1] 5 byte UTC time for given time.
ConvertOrdinalsToTime ROUT
        Push    "R0-R4,LR"

        ; The original implementation of this SWI called ReadCurrentTimeZone
        ; and applied that offset including DST (regardless of whether DST
        ; would have been active for the ordinals given), emulate that behaviour
        SWI     XTerritory_ReadCurrentTimeZone
        MOVVC   R4, R1
        MOVVC   R0, #TerrNum
        LDRVC   R1, [SP, #2*4]          ; Switch R1/R2
        LDRVC   R2, [SP, #1*4]
        ASSERT  TimeFormats_Flag_NoDST = 0             
        LDRVC   R3, =(TimeFormats_LocalOrdinals:SHL:TimeFormats_InFormatShift) :OR: \
                     (TimeFormats_UTC5Byte:SHL:TimeFormats_OutFormatShift) :OR: \
                     TimeFormats_Flag_SpecifyOffset
        SWIVC   XTerritory_ConvertTimeFormats
        STRVS   R0, [SP]
        Pull    "R0-R4,PC"

;---------------------------------------------------------------
; CheckSeparator
;
; in:   r11 = allowable character for a separator
;       r2 points to 2nd char in string
;       r9 = 1st char in string
;
; out:  r2 updated to point after 1st non space char after an optional
;          separator
;       r9 = 1st non space char
CheckSeparator
        Push    "lr"
        BL      SkipSpaces1
        CMP     r9, r11
        BLEQ    SkipSpaces
        Pull    "pc"

;---------------------------------------------------------------
; SkipSpaces
;
; in:   R2 = pointer to string
;
; out:  R2 updated to point to 1st char after 1st non space
;       R9 = 1st non space char
;
; SkipSpaces1
;
; in:   R9 = 1st char in string
;       R2 = pointer to 2nd char in string
;
; out:  R2 updated to point to 1st char after 1st non space
;       R9 = 1st non space char
SkipSpaces
        LDRB    r9, [r2], #1
SkipSpaces1
        CMP     r9, #' '
        BEQ     SkipSpaces
        MOV     pc, lr

;---------------------------------------------------------------
; GetInteger - Read integer from string
;
; in:   R9  = 1st char of string
;       R2 -> 2nd char of string
;       R11 = Upper limit of value
;
; out:  BadTimeString error if invalid string
;       R1 = value read
;       R2 incremented by number of characters read
;       R9 = Terminating character
;       Z set if result was 0
GetInteger
        SUB     r10, r9, #'0'
        CMP     r10, #10
        BCS     BadTimeString

        MOV     r1, #0
01
        ADD     r1, r1, r1, LSL #2
        ADD     r1, r10, r1, LSL #1
        LDRB    r9, [r2], #1
        SUB     r10, r9, #'0'
        CMP     r10, #10
        BCC     %B01
        CMP     r11, r1
        BCC     BadTimeString
        CMP     r1, #0

        MOV     pc, lr

;------------------------------------------------------------------------
; ConvertTimeStringToOrdinals
; In:
;     R1 = Reason code:
;            1   - String is %24:%MI:%SE
;            2   - String is %W3, %DY-%M3-%CE%YR
;            3   - String is %W3, %DY-%M3-%CE%YR.%24:%MI:%SE
;     R2 -> String
;     R3 -> Word aligned buffer to contain result.
; Out:
;   R1-R3  Preserved.
;   [R3+0]  = CS                        ; all values are for LOCAL time
;   [R3+4]  = Seconds  
;   [R3+8]  = Minutes
;   [R3+12] = Hours (out of 24)
;   [R3+16] = Day number in month.
;   [R3+20] = Month number in year.
;   [R3+24] = Year number.
; Note:
;   Values that are not present in the string are set to -1
;
ConvertTimeStringToOrdinals

        Push    "R1-R11,LR"

        DebugS  dt,"String is ",R2

        ; Skip leading spaces

        BL      SkipSpaces

        ; first do the date part of the string

        TST     R1,#2
        MOVEQ   R0,#-1                  ; If no date, set fields to -1
        STREQ   R0,[R3,#16]
        STREQ   R0,[R3,#20]
        STREQ   R0,[R3,#24]
        BEQ     %FT50

        BL      open_messages_file

        ; Test if 1st non blank char is a digit

        SUB     r10, r9, #'0'
        CMP     r10, #10
        BCC     %F02                    ; Yes => must be day of month

        ; Skip to after first ',' (ignoring day of week)

01      CMP     r9, #' '
        BCC     BadTimeString
        CMP     r9, #','
        LDRNEB  r9, [r2], #1
        BNE     %B01

        ; Skip spaces before day of month

        BL      SkipSpaces

        ; Read day of month
02
        MOV     r11, #31
        BL      GetInteger
        BEQ     BadTimeString           ; 0 for DOM illegal
        MOV     r5, r1

        ; Allow ' ' or '-' as day and month separator

        MOV     r11, #'-'
        BL      CheckSeparator

        ; R2 now points to month name.

        SUB     R6,R2,#1                ; R6 -> month

        ; Get all names from messages file

        ADR     R0,message_file_block
        MOV     R4,#0                   ; First call
        MOV     R7,#1                   ; First month.

01
        ADRL    R1,month_token
        SUB     SP,SP,#8                ; We know tokens aren't long.
        MOV     R2,SP
        MOV     R3,#8
        SWI     XMessageTrans_EnumerateTokens
        ADDVS   SP,SP,#8                ;
        Pull    "R1-R11,PC",VS
        CMP     R2,#0
        ADDEQ   SP,SP,#8
        BEQ     BadTimeString           ; Not found !

        ; Get Message

        DebugS  dt,"Next token is ",R2
        MOV     R1,R2                   ; Token.
        MOV     R2,#0                   ; Don't copy message !
        SWI     XMessageTrans_Lookup
        ADD     SP,SP,#8
        Pull    "R1-R11,PC",VS

        ; Got message, now compare with month name in string.

        DebugS  dt,"Got month name: ",R2,4
        DebugS  dt,"String pointer is now on: ",R6
        MOV     R1,R6
02
        LDRB    r9,[R2],#1
        CMP     r9,#10
        BEQ     %FT03                   ; End of token
        ORR     r9,r9,#&20

        LDRB    R10,[R1],#1
        CMP     R10,#' '
        BCC     BadTimeString
        ORR     R10,R10,#&20

        CMP     r9,R10
        BEQ     %BT02                   ; Try next character.
        ADD     R7,R7,#1
        B       %BT01                   ; Try next month.

        ; Skip remainder of chars in month (eg "uary" in "January")
        ; Allow ' ' or '-' as month - year separators
03
        LDRB    R9,[R1],#1
        CMP     R9,#' '
        BCC     BadTimeString
        CMPNE   r9,#'-'
        BNE     %B03

        MOV     r2, r1
        MOV     r11, #'-'
        BL      CheckSeparator

        ; Save pointer so we can work out length of year later to see whether it
        ; is 2 digit or 4 digit format

        MOV     r4, r2

        MOV     r11, #-1
        BL      GetInteger
        MOV     r3, r1

        ; Test if a 2 digit year is given, if so we must decide whether it is
        ; 19XX or 20XX. Dates on or after 26-Jan-66 are taken to be 19XX otherwise
        ; it is 20XX.

        SUB     r4, r2, r4      ; No. of digits in year
        CMP     r4, #3
        BCS     %F20            ; 3 or more digits
        CMP     r3, #66
        CMPEQ   r7, #1
        CMPEQ   r5, #26         ; CS if >= 26-Jan-66
        ADD     r3, r3, #2000   ; = &7D0
        SUBCS   r3, r3, #100

        ; Check no. of days in month
20
        ADRL    r0, MonthLengths
        LDRB    r10, [r0, r7]   ; Feb table entry is 29
        CMP     r7, #2          ; Check for Feb
        BNE     %FT30
        SUB     r11, r3, #2000
        CMP     r11, #-100      ; ie. 1900
        CMPNE   r11, #100       ;   & 2100
        CMPNE   r11, #200       ;   & 2200
        MOVEQ   r10, #28        ; are not leap years
        BEQ     %FT30
        TST     r3, #3
        MOVNE   r10, #28
30
        CMP     r10, r5
        BCC     BadTimeString

        ; Save date in ordinal struct

        LDR     r10, [sp, #2*4]         ; Get entry R3
        STR     r5, [r10, #16]          ; Save day no.
        STR     r7, [r10, #20]          ; Save month no.
        STR     r3, [r10, #24]          ; Save year

        MOV     r11, #'.'
        BL      CheckSeparator

        Debug   dt,"Year is ",R3
        LDR     R1,[SP]                 ; Get reason code back.
        LDR     r3, [sp, #2*4]
50
        TST     R1, #1
        MOVEQ   R0, #-1                 ; if not doing time, set hours,
        STREQ   R0,[R3]                 ; minutes seconds and cs to -1
        STREQ   R0,[R3,#4]              ;
        STREQ   R0,[R3,#8]              ;
        STREQ   R0,[R3,#12]             ;
        BEQ     %FT80                   ; [not doing time part]

        ; Allow ' ' or '.' for date - time separator

        MOV     R0,#0
        STR     R0,[R3]                 ; Zero the centiseconds

        ; Read hour

        MOV     r11, #23
        BL      GetInteger
        STR     r1, [r3, #12]

        ; Allow ':' or ' ' for hour - minute separator

        MOV     r11, #':'
        BL      CheckSeparator

        ; Read minute

        MOV     r11, #59
        BL      GetInteger
        STR     r1, [r3, #8]

        ; Allow ':' or ' ' for minute - second separator

        MOV     r11, #':'
        BL      CheckSeparator

        ; Read second

        MOV     r11, #61
        BL      GetInteger
        STR     r1, [r3, #4]

        ; No errors, buffer now contains values !
80
        CLRV
        Pull    "R1-R11,PC"

BadTimeString
        ADR     R0,ErrorBlock_BadTimeString
        BL      message_errorlookup
        Pull    "R1-R11,PC"

ErrorBlock_BadTimeString
        DCD     TerritoryError_BadTimeString
        DCB     "BadStr",0

month_token     DCB     "M??",0
        ALIGN

;---------------------------------------------------------------------------
; ConvertStandardDate        (along the lines of 12-Nov-1999)
; ConvertStandardTime        (along the lines of 12:34:56)
; ConvertStandardDateAndTime (along the lines of 12:34:56 12-Nov-1999)
; Entry:
;       R1 -> 5 byte UTC time block
;       R2 -> Buffer
;       R3 = Size of buffer and flags per Territory_ConvertDateAndTime.
;       R5 = If required by flags in R3
; Exit:
; out:  V=1 => failed conversion, R0 -> error block
;       V=0 => successful conversion
;       R0 = input value of R2
;       R1 = pointer to terminator
;       R2 = remaining size of buffer
;       R3 = b31 cleared if flags in use, else preserved
;       R5 = preserved
ConvertStandardDate ROUT
        Push    "R3,R4,LR"
        ADR     R4,StandardDateFormat
        B       %FT10

ConvertStandardTime
        Push    "R3,R4,LR"
        ADR     R4,StandardTimeFormat
        B       %FT10

ConvertStandardDateAndTime
        Push    "R3,R4,LR"
        ADR     R4,StandardDateAndTimeFormat
10
        Debug   xx,"Territory number is ",r0

        SWI     XTerritory_ConvertDateAndTime

        Pull    "R3,R4,LR"
        TST     R3, #DateAndTime_Flag_Extension
        BICNE   R3, R3, #DateAndTime_Flag_Extension
        MOV     PC, LR

StandardDateFormat        DCB "$DateFormat",0
StandardTimeFormat        DCB "$TimeFormat",0
StandardDateAndTimeFormat DCB "$DateAndTime",0
        ALIGN

;---------------------------------------------------------------------------
; DaylightRules
; This SWI is for the private use of the territory manager, 
; use Territory_DaylightSaving in application code.
;
; Entry:
;       R1 = 0 (check supported)
; Exit:
;       V=1 => no
;       V=0, R0=1 => yes
;       For the error case, no error block is needed.
;
; Entry:
;       R1 = 1 (get bounds)
;       R2 = timezone within this territory
;       R3 = year
;       R4 -> 5 byte UTC time block start
;       R5 -> 5 byte UTC time block end
; Exit:
;       V=0 rule matched, time blocks updated
;       V=1 no rule for this year
;       Where there is no rule, standard time will be assumed
;       to be used all year round.
;       This SWI abstracts the rule encoding method from
;       the user, the territory module is free to encode
;       rules however it sees fit. We use MessageTrans here.
;
DaylightRules
        CMP     r1, #1
        BHI     UnknownEntry
        MOVCC   r0, #1                  ; Supported and V clear
        MOVCC   pc, lr

        ; Getting the bounds
        Push    "r1-r5, lr"
        SUB     sp, sp, #12             ; Enough for "Zss_YYYY"

        ADD     r0, r2, #100            ; To get a leading zero
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertCardinal1

        MOVVC   r14, #'Z'
        STRVCB  r14, [r0]
        MOVVC   r14, #'_'
        STRVCB  r14, [r1], #1

        MOVVC   r0, r3
        SUBVC   r2, r2, #1
        SWIVC   XOS_ConvertCardinal2
        
        MOVVC   r4, sp
        BLVC    MessageLookup
        ADD     sp, sp, #12
        Pull    "r1-r5, pc", VS

        LDR     r2, [sp, #1*4]          ; Restore

        ; Rough check for syntax "hhhh_wd_mm-hhhh_wd_mm"
        LDRB    r0, [r4, #4]
        TEQ     r0, #'_'
        LDREQB  r0, [r4, #7]
        TEQEQ   r0, #'_'
        LDREQB  r0, [r4, #15]
        TEQEQ   r0, #'_'
        LDREQB  r0, [r4, #18]
        TEQEQ   r0, #'_'
        BEQ     %FT10

        ADR     r0, ErrorBlock_BadTimeString
        BL      message_errorlookup
        Pull    "r1-r5, pc", VS
10
        BL      DaylightBound
        LDRVC   r14, [sp, #3*4]
        STRVC   r0, [r14, #0]           ; Start time
        STRVCB  r1, [r14, #4]
        
        ADDVC   r4, r4, #:LEN:"hhhh_wd_mm-"

        BLVC    DaylightBound
        STRVC   r0, [r5, #0]
        STRVCB  r1, [r5, #4]            ; End time
        Pull    "r1-r5, pc"

DaylightBound ROUT
        ; => R2    timezone within territory
        ;    R3    year
        ;    R4    pointer to string
        ; <= R0/R1 equivalent 5 byte, or error and VS
        Push    "r2-r6, lr"
        SUB     sp, sp, #36
        MOV     r5, #10                 ; Decimal factor
        MOV     r0, #0
        STR     r0, [sp, #0]            ; Centiseconds
        STR     r0, [sp, #4]            ; Seconds

        Dec2Int r14, r4, 2, r5, r1
        STR     r14, [sp, #8]           ; Minutes

        Dec2Int r14, r4, 0, r5, r1
        STR     r14, [sp, #12]          ; Hours

        MOV     r0, #1
        STR     r0, [sp, #16]           ; Day of month

        Dec2Int r14, r4, 8, r5, r1
        STR     r14, [sp, #20]          ; Month

        STR     r3, [sp, #24]           ; Year

        ; Convert ordinals to ordinals (to get day of week the 1st falls on)
        MOV     r1, sp
        MOV     r2, sp
        LDR     r3, =(TimeFormats_LocalOrdinals:SHL:TimeFormats_InFormatShift) :OR: \
                     (TimeFormats_LocalOrdinals:SHL:TimeFormats_OutFormatShift)
        SWI     XTerritory_ConvertTimeFormats
        ADDVS   sp, sp, #36
        Pull    "r2-r6, pc", VS

        ; Check the day didn't roll by 1 (for 24:00:00)
        LDR     r6, [sp, #16]
        SUBS    r6, r6, #1
        LDRNE   r6, =ticksperday

        ; Now select the desired day
        LDR     r3, [sp, #20]           ; Month
        LDR     r5, [sp, #24]           ; Year
        ADRL    r0, MonthLengths
        LDRB    r0, [r0, r3]
        TEQ     r3, #2
        BNE     %FT10
        SUB     r14, r5, #2000
        CMP     r14, #-100              ; ie. 1900
        CMPNE   r14, #100               ;   & 2100
        CMPNE   r14, #200               ;   & 2200
        MOVEQ   r0, #28                 ; are not leap years
        BEQ     %FT10
        TST     r5, #3
        MOVNE   r0, #28
10
        LDRB    r1, [r4, #5]            ; Value '1' to '5' or 'L'
        LDRB    r14, [r4, #6]           ; Sun='1' etc or '*'
        SUB     r2, r14, #'0'
        TEQ     r14, #'*'
        BNE     %FT20

        TEQ     r1, #'L'
        STREQ   r0, [sp, #16]           ; Last day is the month length
        SUBNE   r1, r1, #'0'
        STRNE   r1, [sp, #16]           ; Otherwise it's just the given day
        B       %FT30
20
        ; r0 = month length     
        ; r1 = nth desire     
        ; r2 = dow desire     
        ; r3 = dow now
        ; r4 = dom now
        SUB     r1, r1, #'0'            ; Note 'L' becomes > number of weeks in any month
        LDR     r3, [sp, #28]
        MOV     r4, #1
25
        CMP     r2, r3
        STREQ   r4, [sp, #16]           ; Best dom so far
        SUBEQS  r1, r1, #1
        BEQ     %FT30                   ; Done

        ADD     r3, r3, #1
        CMP     r3, #8
        MOVEQ   r3, #1                  ; Wrap day of week
        ADD     r4, r4, #1
        CMP     r4, r0
        BLS     %BT25                   ; Run out of days, use the last best
30
        ; Convert local ordinals to UTC 5 byte
        MOV     r0, #TerrNum
        MOV     r1, sp
        MOV     r2, sp
        LDR     r3, =(TimeFormats_LocalOrdinals:SHL:TimeFormats_InFormatShift) :OR: \
                     (TimeFormats_UTC5Byte:SHL:TimeFormats_OutFormatShift)
        LDR     r4, [sp, #(0*4) + 36]   ; Timezone within territory on entry
        SWI     XTerritory_ConvertTimeFormats
        LDMVCIA sp, {r0-r1}
        ADD     sp, sp, #36
        Pull    "r2-r6, pc",VS

        ; Factor in the potentially carried day
        ADDS    r0, r0, r6
        ADCS    r1, r1, #0
        Pull    "r2-r6, pc"

        LNK     Transform.s
