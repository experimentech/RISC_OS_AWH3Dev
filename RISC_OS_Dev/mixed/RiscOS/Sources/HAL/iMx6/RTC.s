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
        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        $GetIO
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:HALDevice
        GET     Hdr:RTCDevice
        GET     hdr:iMx6q
        GET     Hdr:iMx6qboard
        GET     hdr.StaticWS

        EXPORT  RTC_Init

        IMPORT  memcpy


        MACRO
        CallOS  $entry, $tailcall
        ASSERT  $entry <= HighestOSEntry
 [ "$tailcall"=""
        MOV     lr, pc
 |
   [ "$tailcall"<>"tailcall"
        ! 0, "Unrecognised parameter to CallOS"
   ]
 ]
        LDR     pc, OSentries + 4*$entry
        MEND

RTCAddressDAL   * &D0
                ^ 0
RTC_Public         # HALDevice_RTC_Size
RTCDeviceHAL_SB    # 4
RTCDevice_RTC_Size # 0

; HAL code for the DS1307 real time clock

        AREA    |Asm$$Code|, CODE, READONLY, PIC

RTC_Init ROUT
        Push    "lr"

        SUB     sp, sp, #12+12+4

        MOV     a1, sp
        MOV     a2, #RTCAddressDAL + 1  ; read op
        ADD     a3, sp, #12             ; -> data block
        MOV     a4, #1                  ; data block size
        STMIA   a1, {a2-a4}

        MOV     a2, #1                  ; 1 transfer
        ADD     a2, a2, #RTC_I2CNum
        CallOS  OS_IICOpV
        TEQ     a1, #IICStatus_Completed
        BNE     %FT10                   ; some failure => no RTC device

        ADD     a1, sp, #12
        MOV     a2, #RTCAddressDAL + 1  ; read op
        ADD     a3, sp, #12+12+0        ; -> data block
        MOV     a4, #1                  ; data block size
        STMIA   a1, {a2-a4}

        MOV     a2, #RTCAddressDAL
        ORR     a2, a2, #1:SHL:29       ; write op with retry
        ADD     a3, sp, #12+12+1        ; -> data block
        MOV     a4, #0
        STRB    a4, [a3]                ; start from register 0
        MOV     a4, #1                  ; data block size
        STMDB   a1!, {a2-a4}

        MOV     a2, #2                  ; 2 transfers
        ADD     a2, a2, #RTC_I2CNum
        CallOS  OS_IICOpV

        LDRB    a4, [sp, #12+12+0]
        TST     a4, #1:SHL:7            ; is the clock halted?
        BEQ     %FT05

        MOV     a1, sp
        MOV     a2, #RTCAddressDAL
        ORR     a2, a2, #1:SHL:29       ; write op with retry
        ADD     a3, sp, #12             ; -> data block
        MOV     a4, #0
        STR     a4, [a3]                ; clear clock halt bit (and seconds)
        MOV     a4, #2                  ; data block size
        STMIA   a1, {a2-a4}

        MOV     a2, #1                  ; 1 transfer
        ADD     a2, a2, #RTC_I2CNum
        CallOS  OS_IICOpV
05
        ADRL    a1, RTCDeviceStruct
        ADR     a2, RTCTemplate
        MOV     a3, #RTCDevice_RTC_Size
        BL      memcpy                  ; softcopy needed to append SB to

        STR     sb, [a1, #RTCDeviceHAL_SB]

        MOV     a2, a1                  ; device
        MOV     a1, #0                  ; flags
        CallOS  OS_AddDevice
10
        ADD     sp, sp, #12+12+4
        Pull    "pc"

RTCTemplate
        ; Public interface
        DCW     HALDeviceType_SysPeri + HALDeviceSysPeri_RTC
        DCW     HALDeviceID_RTC_DS1307
        DCD     HALDeviceBus_Ser + HALDeviceSerBus_IIC
        DCD     0                       ; API version
        DCD     RTCDesc
        DCD     0                       ; Address - N/A
        %       12                      ; Reserved
        DCD     RTCActivate
        DCD     RTCDeactivate
        DCD     RTCReset
        DCD     RTCSleep
        DCD     -1                      ; Interrupt N/A
        DCD     0
        %       8
        ; Specifics for an RTC
        DCB     RTCTimeFormat_BCD
        DCB     RTCFormatFlags_BCD_1BasedDay + \
                RTCFormatFlags_BCD_1BasedMonth + \
                RTCFormatFlags_BCD_NeedsYearHelp + \
                RTCFormatFlags_BCD_YearLOIsGood
        %       2
        DCD     RTCReadTime
        DCD     RTCWriteTime
        ASSERT  (.-RTCTemplate) = HALDevice_RTC_Size
        ; RTC's private data from here onwards
        DCD     0                       ; Copy of HAL's SB
        ASSERT  (.-RTCTemplate) = RTCDevice_RTC_Size
        ASSERT  ?RTCDeviceStruct = RTCDevice_RTC_Size

RTCDesc
        DCB     "DS1307 real-time clock", 0
        ALIGN

RTCActivate
        MOV     a1, #1
RTCDeactivate
RTCReset
        MOV     pc, lr
RTCSleep
        MOV     a1, #0                  ; Previously at full power
        MOV     pc, lr

        ; int RTCReadTime(struct rtcdevice *rtc, struct rtctime *time)
        ; Returns an RTCRetCode
RTCReadTime ROUT
        Push    "sb, v1, lr"

        MOV     v1, a2
        LDR     sb, [a1, #RTCDeviceHAL_SB]
        SUB     sp, sp, #12+12+8

        ADD     a1, sp, #12
        MOV     a2, #RTCAddressDAL + 1  ; read op
        ADD     a3, sp, #12+12+0        ; -> data block
        MOV     a4, #7                  ; data block size
        STMIA   a1, {a2-a4}

        MOV     a2, #RTCAddressDAL
        ORR     a2, a2, #1:SHL:29       ; write op with retry
        ADD     a3, sp, #12+12+7        ; -> data block
        MOV     a4, #0
        STRB    a4, [a3]                ; start from register 0
        MOV     a4, #1                  ; data block size
        STMDB   a1!, {a2-a4}

        MOV     a2, #2                  ; 2 transfers
        ADD     a2, a2, #RTC_I2CNum
        CallOS  OS_IICOpV
        TEQ     a1, #IICStatus_Completed
        MOVNE   a1, #RTCRetCode_Error
        BNE     %FT10

        ASSERT  RTCTimeStruct_BCD_Centiseconds = 0
        ASSERT  RTCTimeStruct_BCD_Seconds = 1
        ASSERT  RTCTimeStruct_BCD_Minutes = 2
        ASSERT  RTCTimeStruct_BCD_Hours = 3
        LDR     a3, [sp, #12+12+0]
        MOV     a3, a3, LSL #8          ; zero centiseconds, discard d-o-w
        STR     a3, [v1, #0]

        ASSERT  RTCTimeStruct_BCD_DayOfMonth = 4
        ASSERT  RTCTimeStruct_BCD_Month = 5
        ASSERT  RTCTimeStruct_BCD_YearLO = 6
        LDR     a3, [sp, #12+12+4]
        BIC     a3, a3, #&FF:SHL:24     ; chip regs match struct
        STR     a3, [v1, #4]

        MOV     a1, #RTCRetCode_OK
10
        ADD     sp, sp, #12+12+8
        Pull    "sb, v1, pc"

        ; int RTCWriteTime(struct rtcdevice *rtc, const struct rtctime *time)
        ; Returns an RTCRetCode
RTCWriteTime
        Push    "sb, v1-v2, lr"

        ASSERT  RTCTimeStruct_BCD_Size = 8
        LDMIA   a2, {v1-v2}

        LDR     sb, [a1, #RTCDeviceHAL_SB]
        SUB     sp, sp, #12+12

        ADD     ip, sp, #12+3           ; -> data block

        CMP     v1, #-1
        MOVNE   a4, #0                  ; start from time register
        MOVEQ   a4, #4                  ; start from date register
        STRB    a4, [ip], #1
        ASSERT  RTCTimeStruct_BCD_Centiseconds = 0
        ASSERT  RTCTimeStruct_BCD_Seconds = 1
        ASSERT  RTCTimeStruct_BCD_Minutes = 2
        ASSERT  RTCTimeStruct_BCD_Hours = 3
        MOVNE   v1, v1, LSR #8          ; no cs
        ORRNE   v1, v1, #1:SHL:24
        STRNE   v1, [ip], #4            ; s,m,h,any d-o-w

        CMP     v2, #-1
        ASSERT  RTCTimeStruct_BCD_DayOfMonth = 4
        ASSERT  RTCTimeStruct_BCD_Month = 5
        ASSERT  RTCTimeStruct_BCD_YearLO = 6
        STRNE   v2, [ip], #3            ; dom,mon,ylo

        MOV     a1, sp
        MOV     a2, #RTCAddressDAL
        ORR     a2, a2, #1:SHL:29       ; write op with retry
        ADD     a3, sp, #12+3           ; -> data block
        SUB     a4, ip, a3              ; data block size
        STMIA   a1, {a2-a4}

        MOV     a2, #1                  ; 1 transfer
        ADD     a2, a2, #RTC_I2CNum
        CallOS  OS_IICOpV
        TEQ     a1, #IICStatus_Completed
        ASSERT  IICStatus_Completed = RTCRetCode_OK
        MOVNE   a1, #RTCRetCode_Error

        ADD     sp, sp, #12+12
        Pull    "sb, v1-v2, pc"

        END

