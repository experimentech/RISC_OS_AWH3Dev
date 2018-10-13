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
; > s.SWIs

tickspersecond  * 100
ticksperminute  * tickspersecond * 60
ticksperhour    * ticksperminute * 60
ticksperday     * ticksperhour   * 24
ticksperyear    * ticksperday    * 365  ; &BBF81E00


Territory_SWIdecode
        Push    "LR"

        CLRPSR  I_bit,R14                       ; re-enable interrupts

        LDR     wp,[R12]                        ; wp --> workspace

        CMP     r11,#FirstReservedSWI
        BLT     %FT01
        CMP     r11,#LastReservedSWI
        BLE     %FT02                           ; Issue error if reserved.

        SUB     r11,r11,#FirstManagerSWI
        CMP     R11,#maxnewmgrswi
        ADDCC   R14,R11,#(mgrswijptable-mgrswijporg-4)/4    ; bodge factor
        ADDCC   PC,PC,R14,ASL #2                ; go!
mgrswijporg
        B       %FT02


01
        CMP     R11,#maxnewswi
        ADDCC   R14,R11,#(swijptable-swijporg-4)/4    ; bodge factor
        ADDCC   PC,PC,R14,ASL #2                ; go!
swijporg
        CMP     r11,#maxterrswi
        SUBCC   r11,r11,#maxnewswi              ; Get offset
        BCC     CallTerritory

02
        ADR     R0,ErrorBlock_BadSWI
        ADRL    r1, Title
        BL      message_errorlookup
        Pull    "PC"

swijptable
        B       SWITerritory_Number                     ; These SWIs are provided by this
        B       SWITerritory_Register                   ; module
        B       SWITerritory_Deregister                 ;
        B       SWITerritory_NumberToName               ;
        B       SWITerritory_Exists                     ;
        B       SWITerritory_AlphabetNumberToName       ;
        B       SWITerritory_SelectAlphabet             ;
        B       SWITerritory_SetTime                    ;
        B       SWITerritory_ReadCurrentTimeZone        ;
        B       SWITerritory_ConvertTimeToUTCOrdinals   ;
endswijptable

maxnewswi   *   (endswijptable-swijptable)/4
maxterrswi  *   maxnewswi+entry_points

mgrswijptable
        Pull    "PC"                                    ; Not yet supported
        B       SWITerritory_Select
        B       SWITerritory_DaylightSaving
        B       SWITerritory_ConvertTimeFormats
endmgrswijptable
maxnewmgrswi   *   (endmgrswijptable-mgrswijptable)/4

ErrorBlock_BadSWI
        DCD     ErrorNumber_OutOfRange
        DCB     "BadSWI", 0
        ALIGN

Territory_SWInames                                      ;    Manager Territory
        DCB     "Territory",0                           ;    SWI     SWI
        DCB     "Number",0                              ;  0  x
        DCB     "Register",0                            ;  1  x
        DCB     "Deregister",0                          ;  2  x
        DCB     "NumberToName",0                        ;  3  x
        DCB     "Exists",0                              ;  4  x
        DCB     "AlphabetNumberToName",0                ;  5  x
        DCB     "SelectAlphabet",0                      ;  6  x
        DCB     "SetTime",0                             ;  7  x
        DCB     "ReadCurrentTimeZone",0                 ;  8  x
        DCB     "ConvertTimeToUTCOrdinals",0            ;  9  x
        DCB     "ReadTimeZones",0                       ; 10          x
        DCB     "ConvertDateAndTime",0                  ; 11          x
        DCB     "ConvertStandardDateAndTime",0          ; 12          x
        DCB     "ConvertStandardDate",0                 ; 13          x
        DCB     "ConvertStandardTime",0                 ; 14          x
        DCB     "ConvertTimeToOrdinals",0               ; 15          x
        DCB     "ConvertTimeStringToOrdinals",0         ; 16          x
        DCB     "ConvertOrdinalsToTime",0               ; 17          x
        DCB     "Alphabet",0                            ; 18          x
        DCB     "AlphabetIdentifier",0                  ; 19          x
        DCB     "SelectKeyboardHandler",0               ; 20          x
        DCB     "WriteDirection",0                      ; 21          x
        DCB     "CharacterPropertyTable",0              ; 22          x
        DCB     "LowerCaseTable",0                      ; 23          x
        DCB     "UpperCaseTable",0                      ; 24          x
        DCB     "ControlTable",0                        ; 25          x
        DCB     "PlainTable",0                          ; 26          x
        DCB     "ValueTable",0                          ; 27          x
        DCB     "RepresentationTable",0                 ; 28          x
        DCB     "Collate",0                             ; 29          x
        DCB     "ReadSymbols",0                         ; 30          x
        DCB     "ReadCalendarInformation",0             ; 31          x
        DCB     "NameToNumber",0                        ; 32          x
        DCB     "TransformString",0                     ; 33          x
        DCB     "IME",0                                 ; 34          x
        DCB     "DaylightRules",0                       ; 35          x
FirstReservedSWI        *       36
        DCB     "Reserved1",0                           ; 36
        DCB     "Reserved2",0                           ; 37
        DCB     "Reserved3",0                           ; 38
        DCB     "Reserved4",0                           ; 39
        DCB     "Reserved5",0                           ; 40
        DCB     "Reserved6",0                           ; 41
        DCB     "Reserved7",0                           ; 42
        DCB     "Reserved8",0                           ; 43
        DCB     "Reserved9",0                           ; 44
        DCB     "Reserved10",0                          ; 45
        DCB     "Reserved11",0                          ; 46
        DCB     "Reserved12",0                          ; 47
        DCB     "Reserved13",0                          ; 48
        DCB     "Reserved14",0                          ; 49
        DCB     "Reserved15",0                          ; 50
        DCB     "Reserved16",0                          ; 51
        DCB     "Reserved17",0                          ; 52
LastReservedSWI         *       52
FirstManagerSWI         *       53
        DCB     "ConvertTextToString",0                 ; 53  x
        DCB     "Select",0                              ; 54  x
        DCB     "DaylightSaving",0                      ; 55  x
        DCB     "ConvertTimeFormats",0                  ; 56  x
        DCB     0
        ALIGN

;----------------------------------------------------------------
; SWI Territory_Register
;
; Entry:
;        R0 - Territory Number
;        R1 -> Buffer containing list of entry points for SWIs
;        R2 - Value of R12 on entry.
; Exit
;
;        Registers preserved.
;
SWITerritory_Register

        Push    "r0-r5"

        Debuga  xx,"Territory_Register called (territory ",R0
        Debug   xx,")"

        ; Check that the territory does not already exist.

        SWI     XTerritory_Exists
        BEQ     %FT99                    ; If it exists ignore new one.

        ; Add the territory to the list.
        ; Allocate block

        MOV     r0,#ModHandReason_Claim
        MOV     r3,#t_block_size
        SWI     XOS_Module
        ADDVS   SP,SP,#4
        Pull    "r1-r5,PC",VS

        LDR     r14,[SP]
        STR     r14,[r2,#t_number]       ; Territory number
        LDR     r14,[SP,#2*4]
        STR     r14,[r2,#t_wsptr]        ; Workspace pointer
        ; Now copy all the entry pointers

        ADD     r0,r2,#t_entries
        LDR     r1,[SP,#1*4]
        ADD     r3,r0,#(entry_points*4)
01
        LDR     r14,[r1],#4
        STR     r14,[r0],#4
        CMP     r0,r3
        BLT     %BT01

        Debug   xx,"Copied entry points"

        ; Link to list.

        LDR     r0,territories
        STR     r0,[r2,#next_ptr]
        STR     r2,territories

        ; Check to see if we just registered the configured territory.
        ; If so call Service_TerritoryStarted to let everyone know.

        LDR     r0,[r2,#t_number]
        LDR     r14, configured_territory
        CMP     r0, r14
        BLEQ    territory_selected

        Debug   xx,"Linked to list"

99
      [ :LNOT:No32bitCode
        MRS     r14, CPSR
        TST     r14, #2_11100
        MSRNE   CPSR_f, #0              ; clear V, keep NE
        Pull    "r0-r5,PC",NE
      ]
        Pull    "r0-r5,PC",,^


;----------------------------------------------------------------
; SWI Territory_Deregister
;
; Entry:
;        R0 - Territory Number
;
; Exit
;
;        Registers preserved.
;
SWITerritory_Deregister

        Push    "r0-r5"

        Debug   xx,"Territory_Deregister called"

        ADR     r1,territories
01
        LDR     r2,[r1,#next_ptr]
        CMP     r2,#0
        BEQ     %FT02                  ; Not found.

        LDR     r14,[r2,#t_number]
        CMP     r14,r0
        MOVNE   r1,r2
        BNE     %BT01

        ; Found, free block and unlink.

        LDR     r14,[r2,#next_ptr]
        STR     r14,[r1,#next_ptr]
        MOV     r0,#ModHandReason_Free
        SWI     XOS_Module
02
      [ :LNOT:No32bitCode
        MRS     r14, CPSR
        TST     r14, #2_11100
        MSRNE   CPSR_f, #0              ; clear V, keep NE
        Pull    "r0-r5,PC",NE
      ]
        Pull    "r0-r5,PC",,^


;------------------------------------------------------------------
; SWI Territory_Exists
;
; Entry:
;
;       R0 - Territory number.
; Exit:
;       R0 - Preserved.
;       Z set if territory is currently loaded.
SWITerritory_Exists

        Push    "r0-r5"

        ADR     r1,territories
01
        LDR     r1,[r1,#next_ptr]
        CMP     r1,#0
        BNE     %FT02

        CMP     r1,#1           ; Clear Z
        Pull    "r0-r5,PC"

02
        LDR     r2,[r1,#t_number]
        TEQ     r0,r2
        Pull    "r0-r5,PC",EQ   ; Return with Z set.

        B       %BT01           ; No, try the next one.

;------------------------------------------------------------------
; SWI Territory_NumberToName
;
; Entry:
;       R0 - Territory number.
;       R1 - Pointer to buffer
;       R2 - Length of buffer
; Exit:
;       [R1] - Name of territory in current territory.
SWITerritory_NumberToName

        Push    "r0-r5"


        ADR     r1,scratch_buffer
        MOV     r14,#'T'
        STRB    r14,[r1],#1
        SWI     XOS_ConvertCardinal4    ;       Get Token

        SUB     r1,r0,#1                ;       -> Token
        LDR     r2,[SP,#1*4]            ;       -> Buffer
        LDR     r3,[SP,#2*4]            ;       Buffer length
        BL      message_lookup
        CMP     r0, #1
        Pull    "r0-r5,PC",CC

        ADREQ   r0,ErrorBlock_UnknownTerritory
        BLEQ    message_errorlookup
        STR     r0,[SP]
        Pull    "r0-r5,PC"

ErrorBlock_UnknownTerritory
        DCD     TerritoryError_UnknownTerritory
        DCB     "UnkTerr",0
        ALIGN

;------------------------------------------------------------------
; SWI Territory_AlphabetNumberToName
;
; Entry:
;       R0 - Alphabet number.
;       R1 - Pointer to buffer
;       R2 - Length of buffer
; Exit:
;       [R1] - Name of alphabet in current territory.
SWITerritory_AlphabetNumberToName ROUT

        Push    "r0-r3"

        ADR     r1,scratch_buffer
        MOV     r14,#'A'
        STRB    r14,[r1],#1
        SWI     XOS_ConvertCardinal4    ;       Get Token

        SUB     r1,r0,#1                ;       -> Token
        LDR     r2,[SP,#1*4]            ;       -> Buffer
        LDR     r3,[SP,#2*4]            ;       Buffer length
        BL      message_lookup
        CMP     r0, #1
        Pull    "r0-r3,PC",CC

        ADREQ   r0,ErrorBlock_UnknownAlphabet
        BLEQ    message_errorlookup
        STR     r0,[SP]
        Pull    "r0-r3,PC"

ErrorBlock_UnknownAlphabet
        DCD     TerritoryError_UnknownAlphabet
        DCB     "UnkAlph",0
        ALIGN

;------------------------------------------------------------------
; SWI Territory_SelectAlphabet
;
; Entry:
;       R0 - Territory number or -1.
; Exit:
;       Registers preserved, correct alphabet for territory selected.
SWITerritory_SelectAlphabet

        Push    "r0-r5"

        SWI     XTerritory_Alphabet
        STRVS   r0,[SP]
        Pull    "r0-r5,PC",VS

        MOV     r1,#Service_International
        MOV     r2,#Inter_Define          ; Define range of characters
        MOV     r3,r0
        MOV     r4,#0                     ; First char to define
        MOV     r5,#255                   ; Last char to define
        SWI     XOS_ServiceCall

      [ :LNOT:No32bitCode
        MRS     r14, CPSR
        TST     r14, #2_11100
        MSRNE   CPSR_f, #0              ; clear V, keep NE
        Pull    "r0-r5,PC",NE
      ]
        Pull    "r0-r5,PC",,^

;------------------------------------------------------------------
; SWI Territory_Number
;
; Entry:
;        -
; Exit:
;        R0 - Configured territory number.
SWITerritory_Number

        LDR     r0,configured_territory

      [ :LNOT:No32bitCode
        MRS     r14, CPSR
        TST     r14, #2_11100
        MSRNE   CPSR_f, #0              ; clear V, keep NE
        Pull    "PC",NE
      ]
        Pull    "PC",,^

;------------------------------------------------------------------
; SWI Territory_Select
;
; Entry:
;        R0 - new territory number
; Exit:
;        -
SWITerritory_Select

        SWI     XTerritory_Exists
        BVS     %FT95
        BNE     %FT90

        STR     R0,configured_territory
        BL      territory_selected
        Pull    "PC"
90
        ADRL    r0,ErrorBlock_TerritoryNotPresent
        BL      message_errorlookup
95
        Pull    "PC"

;-------------------------------------------------------------------
; SWI Territory_ReadCurrentTimeZone
;
; Entry:
;        -
; Exit:
;       R0 -> Name of current time zone
;       R1 = Signed offset from UTC to current time zone.
;       R2 = Timezone within territory if R2 is magic word on entry (-1 for custom)
;
SWITerritory_ReadCurrentTimeZone
        Push    "r2-r6"

        BL      which_timezone
        MOV     R5,R0                   ; Index for Territory_ReadTimeZones
        MOV     R6,R1                   ; Centiseconds

        LDR     R4,=ReadTimeZones_Extension
        TEQ     R2,R4
        STREQ   R5,[SP]

        MOV     R0,#OsByte_ReadCMOS
        MOV     R1,#AlarmAndTimeCMOS
        SWI     XOS_Byte
        MOVVS   r2, #0
        
        CMP     R5,#-1
        BNE     %FT05

        ADR     R0,message_custom       ; Can't comment further than 'custom'
        TST     R2,#DSTCMOSBit
        LDRNE   R5,=ticksperhour        ; Assume DST is fixed +1h
        ADDNE   R6,R6,R5
        B       %FT10
05
        MOV     R0,#-1                  ; Must be the current territory
        MOV     R1,R5
        MOV     R5,R2
        SWI     XTerritory_ReadTimeZones
        Pull    "r2-r6,PC",VS

        TST     R5,#DSTCMOSBit
        MOVNE   R0,R1
        MOVNE   R6,R3                   ; Summer time
10
        MOV     R1,R6
      [ :LNOT:No32bitCode
        MRS     r14, CPSR
        TST     r14, #2_11100
        MSRNE   CPSR_f, #0              ; clear V, keep NE
        Pull    "r2-r6,PC",NE
      ]
        Pull    "r2-r6,PC",,^

;-------------------------------------------------------------------------
;SWI Territory_ConvertTimeToUTCOrdinals
;In:
; R1 = Pointer to 5 byte UTC time block
; R2 -> Word aligned buffer to hold data
;Out:
; R1 Preserved
; R2 Preserved
;   [R2]    = CS.                     ; all values are for UTC.
;   [R2+4]  = Second
;   [R2+8]  = Minute
;   [R2+12] = Hour (out of 24)
;   [R2+16] = Day number in month.
;   [R2+20] = Month number in year.
;   [R2+24] = Year number.
;   [R2+28] = Day of week.
;   [R2+32] = Day of year
SWITerritory_ConvertTimeToUTCOrdinals
        Push    "r0-r11"

        BL      GetTimeValues
        STRVS   r0,[sp]
        Pull    "r0-r11,PC",VS

        LDR     R14,[SP,#2*4]

        STR     R9, [R14],#4
        STR     R10,[R14],#4
        STR     R8 ,[R14],#4
        STR     R7 ,[R14],#4
        STR     R0 ,[R14],#4
        STR     R1 ,[R14],#4
        MOV     R1,#100
        MLA     R0 ,R5,R1,R6
        STR     R0 ,[R14],#4
        STR     R4,[R14],#4
        STR     R3,[R14]

        Pull    "r0-r11,PC"

;---------------------------------------------------------------
; GetOrdinalValues
;
; In: R1 -> UTC ordinals
; Out:
;     R0  = Time value low word
;     R1  = Time value high byte
;     or error in R0 & V set
GetOrdinalValues
        Push    "r0-r11,LR"

        MOV     R11, R1
        LDR     R0, [R11, #12]
        LDR     R1, [R11, #8]
        LDR     R2, [R11, #16]
        LDR     R3, [R11, #20]
        LDR     R4, [R11, #24]
        MOV     R6, #100
        DivRem  R5, R4, R6, R14
        LDR     R6, [R11, #4]
        LDR     R7, [R11]

        ; R0 := hours, R1 := minutes
        ; R2 := days, R3 := months
        ; R4 := year(lo), R5 := year(hi)
        ; R6 := seconds, R7 := centiseconds

        MOV     R9, #24
        SUB     R2, R2, #1              ; decrement day (day=1 => nowt to add)
        MLA     R0, R9, R2, R0          ; R0 = hours + day*24
        MOV     R9, #60
        MLA     R1, R0, R9, R1          ; R1 = mins + hours*60
        MLA     R6, R1, R9, R6          ; R6 = secs + mins*60
        MOV     R9, #100
        MLA     R7, R6, R9, R7          ; R7 = centisecs + secs*100

        ADR     R0, STMonths - 4        ; Point to table (month = 1..12)
        CMP     R3, #12
        BHI     BadYear
        LDR     R1, [R0, R3, LSL #2]    ; get word of offset
        ADD     R7, R7, R1              ; add to total

        ; if not had leap day in this year yet, then exclude this year from the
        ; leap day calculations

        CMP     R3, #3                  ; if month >= 3
        SBCS    R0, R4, #0              ; then R0,R1 = R4,R5
        MOVCC   R0, #99                 ; else R0,R1 = R4,R5 -1
        SBC     R1, R5, #0

        ; want (yl+100*yh) DIV 4 - (yl+100*yh) DIV 100 + (yl+100*yh) DIV 400
        ; = (yl DIV 4)+ (25*yh) - yh + (yh DIV 4)
        ; = (yl >> 2) + 24*yh + (yh >> 2)

        MOV     R0, R0, LSR #2          ; yl >> 2
        ADD     R0, R0, R1, LSR #2      ; + yh >> 2
        ADD     R0, R0, R1, LSL #4      ; + yh * 16
        ADD     R0, R0, R1, LSL #3      ; + yh * 8

        ; now subtract off the number of leap days in first 1900 years = 460

        SUBS    R0, R0, #460
        BCC     BadYear                 ; before 1900, so bad
        CMP     R0, #86                 ; if more than 86 days, then it's
        BCS     BadYear                 ; after 2248, so bad

        LDR     R9, =ticksperday        ; multiply by ticksperday and add to
        MLA     R7, R9, R0, R7          ; total (no overflow possible as this
                                        ; can never be more than 85+31 days)

        ; now add on (year-1900)*ticksperyear

        SUBS    R5, R5, #19             ; subtract off 1900
        BCC     BadYear
        MOV     R9, #100
        MLA     R4, R9, R5, R4          ; R4 = year-1900

        LDR     R0, =ticksperyear       ; lo word of amount to add on
        MOV     R1, #0                  ; hi word of amount to add on
        MOV     R8, #0                  ; hi word of result
10
        MOVS    R4, R4, LSR #1
        BCC     %FT15

        ADDS    R7, R7, R0              ; if bit set then add on amount
        ADCS    R8, R8, R1
        BCS     BadYear                 ; overflow => bad time value
15
        ADDS    R0, R0, R0              ; shift up amount
        ADCS    R1, R1, R1
        TEQ     R4, #0                  ; if still bits to add in
        BNE     %BT10                   ; then loop

        CMP     R8, #&100               ; R8 must only be a byte
        BCS     BadYear

        STMIA   SP, {R7-R8}

        CLRV
        Pull    "R0-R11,PC"

BadYear
        ADR     R0, ErrorBlock_BadTimeBlock
        BL      message_errorlookup
        ADD     SP,SP,#4
        Pull    "r1-r11,PC"

ErrorBlock_BadTimeBlock
        DCD     TerritoryError_BadTimeBlock
        DCB     "BadTime",0
        ALIGN

STMonths
        DCD     &00000000       ; Jan
        DCD     &0FF6EA00       ; Feb
        DCD     &1E625200       ; Mar (Feb had 28 days)
        DCD     &2E593C00       ; Apr
        DCD     &3DCC5000       ; May
        DCD     &4DC33A00       ; Jun
        DCD     &5D364E00       ; Jul
        DCD     &6D2D3800       ; Aug
        DCD     &7D242200       ; Sep
        DCD     &8C973600       ; Oct
        DCD     &9C8E2000       ; Nov
        DCD     &AC013400       ; Dec
        DCD     &F0000000       ; terminator, must be less than this (+1)

;---------------------------------------------------------------
; GetTimeValues
; In:
;     R1 -> UTC Time value
; Out:
;     R0  = Day of month                ; All values are UTC.
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

        ADR     R7, MonthLengths+1      ; R7 -> Jan(31) (Feb is stored as 29)
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

MonthLengths
        ;   F  J  F  M  A  M  J  J  A  S  O  N  D
        DCB 28,31,29,31,30,31,30,31,31,30,31,30,31
        ALIGN

;-------------------------------------------------------------------------
;SWI Territory_DaylightSaving
;In:
;      R0 - Territory number or -1.
;      R1 - Subreason
;           0 - read current DST state
;           1 - write current DST state
;           2 - supported
;           3 - apply rule to ordinals
;           4 - apply rule to 5 byte time
;           5 - get bounds for given year
;Out:
;      Depends on subreason
SWITerritory_DaylightSaving ROUT
        CMP     r1, #(dst_jmp_end - dst_jmp_start) :SHR: 2
        ADRCS   r0, ErrorBlock_UnknownSubreason
        BCS     %FT90
        ADD     PC, PC, R1, LSL #2
        NOP
dst_jmp_start
        B       %FT00                   ; Read state
        B       %FT10                   ; Write state
        B       %FT20                   ; Supported
        B       %FT30                   ; Apply to ordinals
        B       %FT40                   ; Apply to 5 byte time
        B       %FT50                   ; Bounds for year
dst_jmp_end

00
        ; Read
        CMP     r0, #-1                 ; Only apply to the active territory
        LDRNE   r14, configured_territory
        CMPNE   r0, r14
        BNE     %FT80

        Push    "r0-r1"
        MOV     r0, #DSTCMOSBit:OR:AutoDSTCMOSBit
        MOV     r1, #0
        BL      daylight_modify_cmos
        MOV     r1, r0
        MOV     r0, #0
        TST     r1, #DSTCMOSBit
        ORRNE   r0, r0, #DaylightSaving_DSTBit
        TST     r1, #AutoDSTCMOSBit
        ORRNE   r0, r0, #DaylightSaving_AutoDSTBit
        STR     r0, [SP]
        Pull    "r0-r1,PC"
10
        ; Write
        CMP     r0, #-1                 ; Only apply to the active territory
        LDRNE   r14, configured_territory
        CMPNE   r0, r14
        BNE     %FT80

        Push    "r0-r1"
        MOV     r1, #0
        TST     r2, #DaylightSaving_AutoDSTBit
        ORRNE   r1, r1, #AutoDSTCMOSBit
        MOVNE   r0, #DSTCMOSBit         ; If auto enabled, preserve DST bit
        BNE     %FT15

        TST     r2, #DaylightSaving_DSTBit
        ORRNE   r1, r1, #DSTCMOSBit     ; Not auto, do set DST bit
        MOV     r0, #0
15
        BL      daylight_modify_cmos
        BL      daylight_switch_check
        Pull    "r0-r1, pc"
20
        ; Supported
        Push    "r1"
        MOV     r1, #0                  ; RC=supported
        SWI     XTerritory_DaylightRules
        SUBVSS  r0, r0, r0              ; Set to 0 and clear V
        Pull    "r1, pc"
30
        ; Apply rule to UTC ordinals
        Push    "r0-r5"
        MOV     r1, r3
        BL      GetOrdinalValues
        Push    "r0-r1"                 ; Make time block
        LDR     r3, [r3, #24]           ; Year
        B       %FT42
40
        ; Apply rule to 5 byte time
        Push    "r0-r5"
        LDRB    r0,  [r3, #0]
        LDRB    r14, [r3, #1]
        ORR     r0, r0, r14, LSL #8
        LDRB    r14, [r3, #2]
        ORR     r0, r0, r14, LSL #16
        LDRB    r14, [r3, #3]
        ORR     r0, r0, r14, LSL #24
        LDRB    r1,  [r3, #4]
        Push    "r0-r1"                 ; Make time block
        MOV     r1, sp
        Push    "r6-r10"
        BL      GetTimeValues
        MOV     r7, #100
        MLA     r3, r5, r7, r6          ; Year
        Pull    "r6-r10"
42
        LDR     r0, [sp, #(0*4) + 8]
        MOV     r1, #1                  ; RC=bounds
        LDR     r2, [sp, #(2*4) + 8]
        SUB     sp, sp, #16
        ADD     r4, sp, #8
        MOV     r5, sp
        SWI     XTerritory_DaylightRules
        MOVVS   r0, #0                  ; No rule, default to standard time
        BVS     %FT46

        LDMIA   sp, {r0-r3}
        MOV     r1, r1, LSL #24
        MOV     r1, r1, ASR #24
        MOV     r3, r3, LSL #24
        MOV     r3, r3, ASR #24
        SUBS    r14, r0, r2             ; Calculate end - start
        SBCS    r14, r1, r3
        STMCCIA sp, {r2-r3}             ; Swap if end < start (southern hemisphere)
        STRCC   r0, [sp, #8]
        STRCC   r1, [sp, #12]
        MOVCC   r5, #DaylightSaving_DSTBit
        MOVCS   r5, #0
        STMCSIA sp, {r0-r3}             ; Resave sign extended versions

        LDR     r2, [sp, #16 + 0]
        LDR     r3, [sp, #16 + 4]
        MOV     r3, r3, LSL #24
        MOV     r3, r3, ASR #24         ; Sign extend user's time block

        LDR     r0, [sp, #8]
        LDR     r1, [sp, #12]
        SUBS    r14, r2, r0
        SBCS    r14, r3, r1             ; Check block - start
        BCC     %FT44

        LDMIA   sp, {r0-r1}
        SUBS    r14, r0, r2
        SBCS    r14, r1, r3             ; Check end - block
        MOVCS   r0, #DaylightSaving_DSTBit
44
        MOVCC   r0, #0                  ; Outside of start to end
        EOR     r0, r0, r5              ; Hemisphere adjustment
46
        ADD     sp, sp, #16 + 8 + 4
        CLRV
        Pull    "r1-r5, pc"
50
        ; Bounds for year
        Push    "r0-r1, r3"
        CMP     r3, #-1                 ; This year?
        BNE     %FT52

        SUB     sp, sp, #8

        MOV     r0, #3
        MOV     r1, sp
        STRB    r0, [r1, #0]
        MOV     r0, #OsWord_ReadRealTimeClock
        SWI     XOS_Word
        ADDVS   sp, sp, #8 + 4
        Pull    "r1, r3, pc", VS

        Push    "r2, r4-r10"
        BL      GetTimeValues
        MOV     r4, #100
        MLA     r3, r5, r4, r6          ; R3 := year
        Pull    "r2, r4-r10"

        ADD     sp, sp, #8

        LDR     r0, [sp]                ; Recover territory number
52
        MOV     r1, #1                  ; RC=bounds
        SWI     XTerritory_DaylightRules
        Pull    "r0-r1, r3, pc", VC
        Pull    "r0-r1, r3"
        ADR     r0, ErrorBlock_NoRule   ; Remap territory failure to a consistent error
        B       %FT90

        ; Errors
80
        ADRL    r0, ErrorBlock_UnknownTerritory
90
        BL      message_errorlookup
        Pull    "pc"
        
ErrorBlock_UnknownSubreason
        DCD     ErrorNumber_OutOfRange
        DCB     "UnkSub", 0
        ALIGN

ErrorBlock_NoRule
        DCD     TerritoryError_NoRuleDefined
        DCB     "NoRule", 0
        ALIGN

;-------------------------------------------------------------------------
;SWI Territory_ConvertTimeFormats
;In:
;      R0 - Territory number or -1.
;      R1 -> input block
;      R2 -> output block
;      R3 - Format to convert, and flags
;           b0-7:  Input block is
;                  0 = local ordinals
;                  1 = local 5 byte time
;                  2 = UTC ordinals
;                  3 = UTC 5 byte time
;                  4-  reserved
;           b8-15: Output block format (see b0-7)
;           b16:   Convert as though DST was in use
;           b17:   If DST calculation (b18) is unavailable, use "NoDST" instead of erroring
;           b18:   Calculate if DST was in use and adjust b16 automatically
;           b19:   Treat R4 as a signed time adjust in centiseconds
;           b20-31:Reserved
;      R4 - Timezone within territory (as used with Territory_ReadTimeZones)
;           or time in cs if flag b19 set
;Out:
;      Blocks updated, or error in R0 & V set
;Notes:
;      Output ordinals will be 36 byte format
;      Input ordinals only need to be 28 byte format
;      R0 and R4 and R3 b18-16 are only needed for UTC<->local conversions
;
;      R3 = &000x0300 is equivalent to Territory_OrdinalsToTime (x = current DST bit)
;      R3 = &000x0003 is equivalent to Territory_TimeToOrdinals (x = current DST bit)
;      R3 = &00000203 is equivalent to Territory_TimeToUTCOrdinals
SWITerritory_ConvertTimeFormats ROUT
        Push    "r0-r10"
        MOVS    r14, r3, LSR #20
        TSTEQ   r3, #&FC:SHL:TimeFormats_InFormatShift
        TSTEQ   r3, #&FC:SHL:TimeFormats_OutFormatShift
        ADRNE   r0, ErrorBlock_UnknownSubreason
        BNE     %FT95
        
        ASSERT  ((TimeFormats_Local5Byte :AND: TimeFormats_UTC5Byte) :AND: 1) = 1
        ASSERT  ((TimeFormats_LocalOrdinals :OR: TimeFormats_UTCOrdinals) :AND: 1) = 0
        TST     r3, #1
        BNE     In5Byte

InOrd
        ; At present, only Gregorian ordinals are understood. If a territory
        ; turns up that doesn't use this the local ordinal <-> 5 byte calcs
        ; will need to go via the territory module in a new ordinal translating SWI.
        BL      GetOrdinalValues
        BVS     %FT97
        B       %FT10
In5Byte
        LDRB    r0,  [r1, #0]
        LDRB    r14, [r1, #1]
        ORR     r0, r0, r14, LSL #8
        LDRB    r14, [r1, #2]
        ORR     r0, r0, r14, LSL #16
        LDRB    r14, [r1, #3]
        ORR     r0, r0, r14, LSL #24
        LDRB    r1,  [r1, #4]
10
        ; All conversions go via 5 byte (even ordinals to ordinals since
        ; the user may be finding the d-o-w or d-o-y values).
        MOV     r1, r1, LSL #24
        MOV     r1, r1, ASR #24         ; Sign extend
        Push    "r0-r1"                 ; Save 5 byte time

        LDR     r5, [sp, #(3*4) + 8]
        ASSERT  TimeFormats_InFormatShift = 0
        ASSERT  TimeFormats_OutFormatShift = 8
        ORR     r6, r5, r5, LSR #6      ; Mix %0000ooii (definitely range checked as 2 bits)
        AND     r6, r6, #&F
        ADD     pc, pc, r6, LSL #2
        NOP
        B       OutOrd                  ; LO->LO   0000
        B       OutOrd                  ; L5->LO   0001
        B       OutAddOrd               ; UO->LO   0010
        B       OutAddOrd               ; U5->LO   0011
        B       Out5Byte                ; LO->L5   0100
        B       Out5Byte                ; L5->L5   0101
        B       OutAdd5Byte             ; UO->L5   0110
        B       OutAdd5Byte             ; U5->L5   0111
        B       OutSubOrd               ; LO->UO   1000
        B       OutSubOrd               ; L5->UO   1001
        B       OutOrd                  ; UO->UO   1010
        B       OutOrd                  ; U5->UO   1011
        B       OutSub5Byte             ; LO->U5   1100
        B       OutSub5Byte             ; L5->U5   1101
        B       Out5Byte                ; UO->U5   1110
        B       Out5Byte                ; U5->U5   1111

OutAddOrd
OutAdd5Byte
OutSubOrd
OutSub5Byte
        ; Some kind of localisation needed
        TST     r5, #TimeFormats_Flag_SpecifyOffset
        BEQ     %FT18

        ; Value in R4 is a time in centiseconds
        TST     r5, #TimeFormats_Flag_UseAutoDST :OR: TimeFormats_Flag_UseStdIfNoAuto
        ADDNE   sp, sp, #8
        ADRNE   r0, ErrorBlock_UnknownSubreason
        BNE     %FT95                   ; Can't have those flags when offset is supplied
        ANDS    r0, r5, #TimeFormats_Flag_DST
        LDRNE   r0, =ticksperhour
        ADD     r2, r4, r0              ; Assume DST is fixed +1h
        B       %FT40
18
        ; Value in R4 is a timezone-within-territory
        TST     r5, #TimeFormats_Flag_UseAutoDST
        BEQ     %FT30

        ; Attempt auto DST correction
        LDR     r0, [sp, #(0*4) + 8]
        MOV     r1, #DaylightSaving_ApplyRuleToTime
        LDR     r2, [sp, #(4*4) + 8]
        MOV     r3, sp
        SWI     XTerritory_DaylightSaving
        BVC     %FT20

        TST     r5, #TimeFormats_Flag_UseStdIfNoAuto
        BEQ     %FT97                   ; Propagate the error
        MOV     r0, #0                  ; Pretend it's standard time
20
        TST     r0, #DaylightSaving_DSTBit
        BICEQ   r5, r5, #TimeFormats_Flag_DST
        ORRNE   r5, r5, #TimeFormats_Flag_DST
30
        ; Lookup the timezone offset
        LDR     r0, [sp, #(0*4) + 8]
        LDR     r1, [sp, #(4*4) + 8]
        LDR     r4, =ReadTimeZones_Extension
        SWI     XTerritory_ReadTimeZones
        ADDVS   sp, sp, #8
        BVS     %FT97

        ; Select daylight saving or standard time and adjust
        TST     r5, #TimeFormats_Flag_DST
        MOVNE   r2, r3
40
        LDMIA   sp, {r0-r1}
        TST     r6, #2                  ; Add or subtract?
        RSBNE   r2, r2, #0              ; Do addition by negative subtraction
        MOV     r3, r2, ASR #31
        SUBS    r0, r0, r2
        SBC     r1, r1, r3
        STMIA   sp, {r0-r1}

        TST     r6, #4                  ; Redespatch output format
        BNE     Out5Byte
OutOrd
        MOV     r1, sp
        BL      GetTimeValues
        LDR     r14, [sp, #(2*4) + 8]   ; Output block address
        MOV     r2, #100                ; Reuse r2, don't need week of year
        MLA     r2, r5, r2, r6          ; Year
        STMIA   r14!, {r9-r10}
        STR     r8, [r14], #4
        STR     r7, [r14], #4
        STMIA   r14!, {r0-r2, r4}
        STR     r3, [r14], #4
        B       %FT91
Out5Byte
        LDMIA   sp, {r0-r1}
        LDR     r14, [sp, #(2*4) + 8]   ; Output block address
        STRB    r0, [r14, #0]
        MOV     r0, r0, LSR #8
        STRB    r0, [r14, #1]
        MOV     r0, r0, LSR #8
        STRB    r0, [r14, #2]
        MOV     r0, r0, LSR #8
        STRB    r0, [r14, #3]
        STRB    r1, [r14, #4]

        ; Exit
91
        ADD     sp, sp, #8              ; Chuck time block
        CLRV
        Pull    "r0-r10, pc"

        ; Error exits
95
        BL      message_errorlookup
97
        ADD     sp, sp, #4
        Pull    "r1-r10, pc"

;-------------------------------------------------------------------------
;SWI Territory_SetTime
;In:
; R0 = Pointer to 5 byte UTC time block
;Out:
;   R0 preserved.
;   Clock set from time.
SWITerritory_SetTime ROUT
        Push    "R0-R2"

        ; We call OS_Word 15,5 to set the time, as it allows greater
        ; accuracy. If the kernel doesn't support it, we will catch
        ; Service_UKWord and call SetTimeTheHardWay to do it using
        ; OS_Word 15,24.

        MOV     R2,#5                   ; store reason code
        STRB    R2,error_buffer

        ADR     R1,error_buffer+1       ; copy time block in
01      LDRB    LR,[R0],#1
        SUBS    R2,R2,#1
        STRB    LR,[R1],#1
        BNE     %BT01

        MOV     R0,#OsWord_WriteRealTimeClock
        ADR     R1,error_buffer
        SWI     XOS_Word

        BLVC    daylight_switch_check

        STRVS   R0,[SP]        
        Pull    "R0-R2,PC"

;-----------------------------------------------------------------------
; Set time the hard way - called if Service_UKWord comes in
; for OSWord_15,5.
;
; On entry: R3 -> OS_Word parameter block (5-byte time at R3+1)

SetTimeTheHardWay ROUT
        Push    "R0-R4"

        ; Get string into scratch_buffer

        ADD     R1,R3,#1
        MOV     R0,#-1              ; Use default territory
        ADR     R2,error_buffer+1
        MOV     R3,#&100
        ADR     R4,timeformatstring
        SWI     XTerritory_ConvertDateAndTime
        ADDVS   SP,SP,#4
        Pull    "r1-r4,PC",VS

        ADR     R0,error_buffer+1
        DebugS  xx,"Time string is ",r0

        ; Now set the clock

        MOV     R0,#24
        STRB    R0,error_buffer
        MOV     R0,#OsWord_WriteRealTimeClock
        ADR     R1,error_buffer
        SWI     XOS_Word
        STRVS   r0,[sp]

        Pull    "r0-r4,PC"

timeformatstring
        DCB     "%W3,%DY %M3 %CE%YR.%24:%MI:%SE",0
        ALIGN

;-----------------------------------------------------------------------
CallTerritory

        CMP     r0,#-1
        LDREQ   r0,configured_territory

        Push    "r0-r1,r12"

        Debuga  xx,"Territory entry ",r11
        Debug   xx," for territory ",r0

        ; Find the territory in the list

        ADR     r1,territories
01
        LDR     r1,[r1,#next_ptr]
        CMP     r1,#0
        BEQ     NotLoaded              ; Territory not present.

        LDR     r14,[r1,#t_number]
        TEQ     r0,r14
        BNE     %BT01

        ; r1 -> territory block
        ; r11 = entry point number 
        ; corrupted r1, r0, lr

        LDR     r12, [r1, #t_wsptr]
        ADD     r14, r1, r11, ASL #2
        LDR     r11, [r14, #t_entries]  ; r11 := routine to call

        Pull    "r0-r1"
        
        MOV     r14, pc                 ; setup return address
        MOV     pc, r11                 ; call routine

      [ debugxx
        Pull    "r12"
        Debug   xx,"Module entry returned."
        Pull    "PC"
      |
        Pull    "r12,PC"
      ]
      
NotLoaded
        ADR     r0,ErrorBlock_TerritoryNotPresent
        BL      message_errorlookup
        ADD     SP,SP,#4
        Pull    "r1,r12,PC"

ErrorBlock_TerritoryNotPresent

        DCD     TerritoryError_NoTerritory
        DCB     "NoTerr",0
        ALIGN

        LNK     Tail.s
