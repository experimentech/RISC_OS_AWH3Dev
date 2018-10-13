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
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.Timers
        GET     hdr.GPIO
        GET     hdr.PRCM

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  I2C_Init

        EXPORT  HAL_IICBuses
        EXPORT  HAL_IICType
        EXPORT  HAL_IICDevice
        EXPORT  HAL_IICTransfer
        EXPORT  HAL_IICMonitorTransfer
        EXPORT  HAL_VideoIICOp
        EXPORT  IIC_DoOp_Poll
        EXPORT  HAL_NormalIICOp
        EXPORT  HAL_IICSetLines
        EXPORT  HAL_IICReadLines

        IMPORT  HAL_CounterDelay

; The iMX6q has 3 I2C controllers:
; (usage on wandboard)
; I2C1 - RevvB/C HDMI DDC, EEPROM, JP2 header
; I2C1 - Rev D   EEPROM, JP2 header
; I2C2 - Rev B/C SGTL5000 audio, camera header, JP2 header
; I2C2 - Rev D   HDMI DDC,SGTL5000 audio, camera header, JP2 header
; I2C3 - JP2 header

                GBLL    I2CDebug
I2CDebug        SETL    {FALSE} :LAND: Debug
;I2CDebug       SETL    {TRUE} :LAND: Debug

                GBLL    I2CDebugData ; Display bytes sent & received?
I2CDebugData    SETL    {FALSE} :LAND: I2CDebug
;I2CDebugData   SETL    {TRUE} :LAND: I2CDebug

                GBLL    I2CDebugError ; Debug unexpected_error occurences
I2CDebugError   SETL    {FALSE} :LAND: Debug
;I2CDebugError  SETL    {TRUE} :LAND: Debug

                GBLL    SWVideoIICOp ; use software I2C for VideoIICOp
SWVideoIICOp    SETL    {TRUE};{FALSE};

 [ I2CDebug :LOR: I2CDebugError
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugMemDump
        IMPORT  DebugHALPrintByte
 ]

        MACRO
$label  I2CDebugTX $str
 [ I2CDebug
$label  DebugTX "$str"
 ]
        MEND
        MACRO
$label  I2CDebugReg $reg, $str
 [ I2CDebug
$label  DebugReg "$reg", $str
 ]
        MEND
; the logical and physical I2C channel numbers differ between Rev B/C boards
; and Rev D
; Initial port address sets this up before we get here
;
I2C_Init
        Push    "v1-v3,v5,lr"

        I2CDebugTX "I2C_Init"

        ; enable clocks in CCGR2
        ; 11-10,9-8,7-6  are i2c3_serclk,i2c2, and i2c1
        ;; done in HAL startup ATM

        ; enable the pins
        ; on the wandboard:
        ; - I2C1 uses EIM_D21, EIM_D28 (HDMI DDC)
        ; - I2C2 uses KEY_COL3, KEY_ROW3
        ; - I2C3 uses GPIO_5, GPIO_16
        ;
; pad drive
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
        ldr     a3, =IOMuxPadDDC             ; HDMI DDC pad drive stuff
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D21-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_COL3-IOMUXC_BASE_ADDR]
        ldr     a3, =IOMuxPadI2C             ; pad drive stuff
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D28-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_GPIO_5-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_GPIO_16-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_ROW3-IOMUXC_BASE_ADDR]
; input select
        mov     a3, #SEL_EIM_D21_ALT6                   ; I2C1 SCL
        str     a3, [a2,#IOMUXC_I2C1_IPP_SCL_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_EIM_D28_ALT1                   ; I2C1 SDA
        str     a3, [a2,#IOMUXC_I2C1_IPP_SDA_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_KEY_COL3_ALT4                  ; I2C2 SCL
        str     a3, [a2,#IOMUXC_I2C2_IPP_SCL_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_KEY_ROW3_ALT4                  ; I2C2 SDA
        str     a3, [a2,#IOMUXC_I2C2_IPP_SDA_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_GPIO_5_ALT6                    ;I2C3 SCL
        str     a3, [a2,#IOMUXC_I2C3_IPP_SCL_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_GPIO_16_ALT6                   ; I2C3 SDA
        str     a3, [a2,#IOMUXC_I2C3_IPP_SDA_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
; pad mode & bypass
 [ SWVideoIICOp
        LDR     a4, BoardDetectInfo
        TST     a4, #1
        moveq   a3, #5 | (SION_ENABLED<<4)                   ;gpio3 bit 21
        movne   a3, #6 | (SION_ENABLED<<4)                   ; I2C1 SCL
        movne   v1, #5 | (SION_ENABLED<<4)                   ;gpio4 bit 12
        moveq   v1, #4 | (SION_ENABLED<<4)                   ; I2C2 SCL
        moveq   v2, #5 | (SION_ENABLED<<4)                   ;gpio3 bit 28
        movne   v2, #1 | (SION_ENABLED<<4)                   ; I2C1 SDA
        movne   v3, #5 | (SION_ENABLED<<4)                   ;gpio4 bit 13
        moveq   v3, #4 | (SION_ENABLED<<4)                   ; I2C2 SDA
 |
        mov     a3, #6 | (SION_ENABLED<<4)                   ; I2C1 SCL
        mov     v1, #4 | (SION_ENABLED<<4)                   ; I2C2 SCL
        mov     v2, #1 | (SION_ENABLED<<4)                   ; I2C1 SDA
        mov     v3, #4 | (SION_ENABLED<<4)                   ; I2C2 SDA
 ]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D21-IOMUXC_BASE_ADDR]
        str     v1, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_COL3-IOMUXC_BASE_ADDR]
        str     v2, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D28-IOMUXC_BASE_ADDR]
        str     v3, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_ROW3-IOMUXC_BASE_ADDR]

        mov     a3, #6 | (SION_ENABLED<<4)                  ; alt6, SION enabled
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_5-IOMUXC_BASE_ADDR]   ; I2C3 SCL
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_16-IOMUXC_BASE_ADDR]  ; I2C3 SDA
 [ SWVideoIICOp
        LDR     a2, GPIO_Log
        ADDEQ   a2, a2, #GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
        LDREQ   a3, [a2, #GPIO_GDIR]
        ORREQ   a3, a3, #1<<21
        ORREQ   a3, a3, #1<<28
        STREQ   a3, [a2, #GPIO_GDIR]       ; set bits as o/p for I2C1 Rev B/C
        ADDNE   a2, a2, #GPIO4_BASE_ADDR-GPIO1_BASE_ADDR
        LDRNE   a3, [a2, #GPIO_GDIR]
        ORRNE   a3, a3, #1<<12
        ORRNE   a3, a3, #1<<13
        STRNE   a3, [a2, #GPIO_GDIR]       ; set bits as o/p for I2C2 RevD
 ]

        ; 2. Initialise each I2C controller
        MOV     v1, #I2C_BusCount
        ADR     v2, I2C_Table
10
        I2CDebugReg  v1, "remaining busses: "

        LDR     v3, [v2, #I2C_XHW]
        CMP     v3, #0
        BEQ     %FT30 ; Skip unused busses
; [ SWVideoIICOp
;        LDR     a4, [v2, #I2C_XIONum]
;        TEQ     a4, #VideoI2C_num
;        BEQ     %FT30 ; Skip VideoIIC bus
; ]
        ; First we'll reset the controller
        LDRH    a4, [v3, #I2C_CR]
        TST     a4, #I2C_CRIEN
        BEQ     %FT20
        MOV     a4, #0
        STRH    a4, [v3, #I2C_CR]
20
        ; Run at 400kbps for now (video at 100khz
        LDR     a4, [v2, #I2C_XIONum]
        TEQ     a4, #VideoI2C_num
        MOVEQ   a4, #I2C_ClkDiv100
        MOVNE   a4, #I2C_ClkDiv400
        STRH    a4, [v3, #I2C_FDiv]
        ; Program own address
        MOV     a4, #01
        STRH    a4, [v3, #I2C_SlAddr]
        ; Enable the controller
        MOV     a4, #I2C_CRIEN
        STRH    a4, [v3, #I2C_CR]
        ; Next!
        SUBS    v1, v1, #1
        ADD     v2, v2, #I2CBlockSize
        BNE     %BT10
        ; Done
30
        I2CDebugTX "I2C_Init complete"
        Pull    "v1-v3,v5,pc"


HAL_IICBuses
        MOV     a1, #I2C_BusCount
        MOV     pc, lr

HAL_IICType
        ; todo - set the 'missing flags' alluded to in Kernel.Docs.HAL.MoreEnts?
        ;        (multi-master & slave operation)
        MOV     a2, #I2C_BusCount
        CMP     a1, a2
        MOVHS   a1, #0
 [ SWVideoIICOp
        MOVHS   pc, lr
        TEQ     a1, #VideoI2C_num
        LDREQ   a1, =IICFlag_LowLevel+IICFlag_Fast
        LDRNE   a1, =IICFlag_HighLevel+IICFlag_Fast+IICFlag_Background+(210:SHL:20)
 |
        LDRLO   a1, =IICFlag_HighLevel+IICFlag_Fast+IICFlag_Background+(210:SHL:20)
 ]
         MOV     pc, lr

; HAL_IICDevice
; in:
;       r0 = bus number
; out:
;       r0 = device number
;
HAL_IICDevice
        MOV     a3, #I2C_BusCount
        CMP     a1, a3
        MOVHS   a1, #-1
        MOVLO   a3, #I2CBlockSize
        MULLO   a3, a1, a3
        ADRLOL  a4, I2C_Table + I2C_XIRQ
        LDRLO   a1, [a4, a3]
        MOV     pc, lr

; HAL_IICTransfer
; in:
;      r0 = bus number
;      r1 = number of transfers
;      r2 = iic_transfer array ptr
; out:
;      r0 = IICStatus return code
; Transfer list format:
;      typedef struct iic_transfer
;      {
;        unsigned addr:8;          b0:Rd/~Wr B7-1: addr
;        unsigned :22;
;        unsigned checksumonly:1;      B30:1=CKSum only
;        unsigned nostart:1;           B31:no restart
;        union
;        {   unsigned checksum;
;            void *data;
;        } d;
;        unsigned len;
;      } iic_transfer;

HAL_IICTransfer
        MOV     a4, #I2C_BusCount
        CMP     a1, a4
        MOVHS   a1, #IICStatus_Error
        MOVHS   pc, lr
        ; Quickly validate the transfer list
        ; We have several constraints:
        ; 1. Must have 1 or more iic_transfers
        ; 2. First transfer must not have nostart bit set
        CMP     a2, #0
        MOVLT   a1, #IICStatus_Error
        MOVLT   pc, lr
        LDR     a4, [a3]
        TST     a4, #1:SHL:31   ; First transfer has nostart set!
        MOVNE   a1, #IICStatus_Error
        MOVNE   pc, lr
        STMFD   sp!, {v1-v5,lr}
        I2CDebugTX "HAL_IICTransfer"
        I2CDebugReg a1, "bus="
        I2CDebugReg a2, "num="
        I2CDebugReg a3, "iic_transfer="
        ADR     v5, I2C_Table
        MOV     v4, #I2CBlockSize
        MLA     v5, a1, v4, v5
        MRS     ip, CPSR
        ORR     a4, ip, #I32_bit
        MSR     CPSR_c, a4              ; disable interrupts for atomic claim
        LDR     a4, [v5, #I2C_XStart]
        TEQ     a4, #0                  ; in use already?
        STREQ   a3, [v5, #I2C_XStart]   ; if not, claim it
        MSR     CPSR_c, ip
        MOVNE   a1, #IICStatus_Busy     ; if it is, return "BUSY"
 [ I2CDebug
        BEQ     %FT10
        I2CDebugReg a4, "BUSY: XStart="
        LDMFD   sp!, {v1-v5,pc}
10
        I2CDebugTX "OK"
 |
        LDMNEFD sp!, {v1-v5,pc}
 ]
        SUB     a2, a2, #1              ; a2 = transfers - 1 (needed below)
        ADD     v1, a3, a2, LSL #3
        ADD     v1, v1, a2, LSL #2
        STR     v1, [v5, #I2C_XEnd]
        LDR     v4, [v5, #I2C_XHW]
        ; Make sure controller is enabled, since we don't do any initialisation atm!
        LDRH    a4, [v4, #I2C_CR]
        TST     a4, #I2C_CRIEN
        LDREQH  v3, [v4, #I2C_SR]
 [ I2CDebugError
        BNE     %FT10
        I2CDebugTX "Controller not enabled!"
        B       unexpected_error
10
 |
        BEQ     unexpected_error
 ]
        MOV     v1, a3
        MRS     a4, CPSR
        BIC     a4, a4, #I32_bit
start_transfer
        ; Start the transfer in v1
        ; a1-a3 free
        ; a4 = CPSR with IRQs enabled (if possible)
        ; v1 = iic_transfer to start
        ; v2-v3 free
        ; v4 = I2C controller ptr
        ; v5 = I2C state ptr
        I2CDebugReg v1, "start_transfer: "
        STR     v1, [v5, #I2C_XCurrent]
        MOV     lr, #0
        STR     lr, [v5, #I2C_XBytes]
        ; Get its info
        LDMIA   v1, {a1-a3}
        I2CDebugReg a1, "addr="
        I2CDebugReg a2, "data="
        I2CDebugReg a3, "len ="
        ; If it's a read op, we need to calculate the length of this and any
        ; following non-repeated-start xfers
        TST     a1, #1
        BEQ     %FT30
        ; And if it's a checksum-only read, clear the initial checksum value
        TST     a1, #1:SHL:30
        MOVNE   a2, #0
        STRNE   a2, [v1, #4]
        MOV     v2, v1
        LDR     ip, [v5, #I2C_XEnd]
10
        CMP     ip, v2
        BEQ     %FT20
        ADD     v2, v2, #12
        LDMIA   v2, {a1-a2,v3} ; Get transfer info
        TST     a1, #1:SHL:31
        ADDNE   a3, a3, v3 ; nostart is set; increment length and loop around
        BNE     %BT10
20
        I2CDebugReg a3, "XRemain="
        STR     a3, [v5, #I2C_XRemain]
        LDMIA   v1, {a1-a2} ; Recover details of current block
30
        ; If this is the first transfer, we must wait for the bus to be idle
        LDR     lr, [v5, #I2C_XStart]
        TEQ     lr, v1
        BNE     %FT50
35
        ; IRQs on while we wait
        MRS     a2, CPSR
        MSR     CPSR_c, a4
        MOV     v2, #50*1024 ; timeout - this should be more than adequate (with a CPU of 500MHz, there'd be 1250 CPU clock cycles per 400kbps I2C clock cycle)
40
        LDRH    ip, [v4, #I2C_SR]
        TST     ip, #I2C_SRIBB                ; bus busy bit
        BEQ     %FT45
        SUBS    v2, v2, #1
        BNE     %BT40
        MSR     CPSR_c, a2
        I2CDebugReg ip, "I2C Bus Busy timeout: "
        ; HAL IIC spec says we can wait indefinitely
        ; but that could lead to lockout.. so..
;        LDRH    v2, [v4, #I2C_CR]
;        MOV     a1, #IICStatus_Error         ; abandon
;        B       clear_and_return
        B       BlockedI2CRecover
45
        MSR     CPSR_c, a2
50
        ; Clear any old interrupts
        MOV     a4, #0
        STRH    a4, [v4, #I2C_SR]
        ; set master, enabled, IRQ enabled, transmit mode
        MOV     a4,  #(I2C_CRIEN + I2C_CRIIEN + I2C_CRMSTA + I2C_CRMTX)
        ; set repeated start if not first xfer
        LDR     lr, [v5, #I2C_XStart]
        TEQ     lr, v1
        ORRNE   a4, a4, #I2C_CRRSTA
        STRH    a4, [v4, #I2C_CR]
        BEQ     %FT55
        ; The manual warns that there must be a delay of two module clock cycles
        ; (up to 78ns) between setting RSTA and writing to DR.
        ; This presumably makes up for the fact that we skip the wait for the
        ; bus to become busy (since it's already busy when we set RSTA)
        DSB                                ; Ensure write has occured
        Push    "a1-a4"
        MOV     a1, #1
        BL      HAL_CounterDelay           ; Do a short delay
        Pull    "a1-a4"
        B       %FT70                      ; all ready ours, Skip the wait below

55
        ; Wait for the bus to become busy
        MOV     v2, #50*1024 ; timeout
60
        LDRH    v3, [v4, #I2C_SR]
        TST     v3, #I2C_SRIBB
        BNE     %FT70
        SUBS    v2, v2, #1
        BNE     %BT60
        I2CDebugReg v3, "BB timeout: I2C_SR="
        B       BlockedI2CRecover
;        LDRH    v2, [v4, #I2C_CR]
;        MOV     a1, #IICStatus_Error
;        B       clear_and_return          ; abandon
70
        ; Send the address byte
 [ I2CDebugData
        I2CDebugReg a1, "Addr "
 ]
        STRH    a1, [v4, #I2C_DR]
        ; Now we just sit back and wait for the interrupts?
 [ I2CDebug
        DebugTX "Transfer started"
 ]
        MOV     a1, #IICStatus_InProgress
        LDMFD   sp!, {v1-v5,pc}


; Return IICStatus state for transfer on bus a1  (0 - xx)
; Called on appropriate interrupt
HAL_IICMonitorTransfer
        ; Process the interrupts,
        STMFD   sp!, {v1-v5,lr}
        I2CDebugReg a1, "HAL_IICMonitorTransfer: bus "
;  DebugReg a1, "HAL_IICMonitorTransfer: bus "
        ADR     v5, I2C_Table
        MOV     v4, #I2CBlockSize
        MLA     v5, a1, v4, v5
        LDR     v4, [v5, #I2C_XHW]
        LDR     a1, [v5, #I2C_XStart]
        I2CDebugReg a1, "XStart="
        LDRH    v2, [v4, #I2C_CR]          ; Control.. whats happening?
        LDRH    v3, [v4, #I2C_SR]          ; status .. whats happening?
        I2CDebugReg v2, "I2C_CR="
        I2CDebugReg v3, "I2C_SR="
        TEQ     a1, #0 ; If no transfer, shut off all interrupts
        ASSERT  IICStatus_Completed=0
 [ I2CDebug
        BNE     %FT10
        I2CDebugTX "No XStart!"
        TEQ     a1, #0 ; reset EQ condition
10
 ]
        MOV     a1,#0
        STREQH  a1, [v4, #I2C_SR]          ; clr irq
        LDMEQFD sp!, {v1-v5,pc}            ; and out
        ;
        TST     v3, #I2C_SRIAL
        BNE     i2c_arbitrationlost
        tst     v3, #I2C_SRIIF             ; pending IRQ?
        MOVEQ   a1, #IICStatus_InProgress  ; If nothing interesting happened, claim everything is OK (required for polling-mode transfers, e.g. HAL_VideoIICOp)
        LDMEQFD sp!, {v1-v5,pc}            ; no..and out
        ;
        bic     v3, v3, #I2C_SRIIF
        STRH    v3, [v4, #I2C_SR]          ; clr irq
        LDR     v1, [v5, #I2C_XCurrent]
        LDR     a1, [v5, #I2C_XBytes]
        I2CDebugReg v1, "XCurrent="
        I2CDebugReg a1, "XBytes="
        LDMIA   v1, {a2-a4}                ; Get transfer block
        ; Implement master mode processing as per fig 35-5 in IMX6DQRM.pdf
        TST     v2, #I2C_CRMTX             ; TX/RX?
        BEQ     i2c_rx
        ; TX
        TEQ     a1, a4                     ; Transmitted last byte?
        BLEQ    i2c_nextxfer
        TST     v3, #I2C_SRRXACK
        BNE     i2c_norxack
        ; If we've just sent the address byte, and we're meant to be doing an
        ; RX transfer (low bit of address byte 1), switch to RX mode
        EOR     a4, a2, #1
        TEQ     a1, #0
        TSTEQ   a4, #1
        BEQ     i2c_startrx
        ; Transmit next data byte
        LDRB    a4, [a3, a1]
        ADD     a1, a1, #1
        STR     a1, [v5, #I2C_XBytes]
 [ I2CDebugData
        I2CDebugReg a4, "TX "
 ]
        STRH    a4, [v4, #I2C_DR]
        MOV     a1, #IICStatus_InProgress
        LDMFD   sp!, {v1-v5, pc}

i2c_startrx
        I2CDebugTX "i2c_startrx"
        BIC     v2, v2, #I2C_CRMTX
        ; Not shown in the flowchart, but if we're only reading one byte then
        ; we must also set the ack bit (i.e. no ack)
        LDR     ip, [v5, #I2C_XRemain]
        SUBS    ip, ip, #1
        STR     ip, [v5, #I2C_XRemain]
        ORREQ   v2, v2, #I2C_CRTXAK       ; ACK hi (missing) on last one
        STRH    v2, [v4, #I2C_CR]
        ; Do a dummy read of data register to kick-start the hardware
        LDRH    v2, [v4, #I2C_DR]
        MOV     a1, #IICStatus_InProgress
        LDMFD   sp!, {v1-v5, pc}

i2c_norxack
        I2CDebugTX "i2c_norxack"
        MOV     a1, #IICStatus_NoACK
        B       clear_and_return

i2c_nextxfer
      [ I2CDebug
        MOV     ip, lr
        I2CDebugReg v1, "i2c_nextxfer "
        MOV     lr, ip
      ]
        ; Advance to the next transfer block, or return to caller if next block
        ; isn't repeated-start
        LDR     ip, [v5, #I2C_XEnd]
        TEQ     v1, ip
        BEQ     i2c_stop
        ADD     v1, v1, #12
        LDMIA   v1, {a2-a4}
        TST     a2, #1<<31                 ; No start bit?
        MRSEQ   a4, CPSR
        BEQ     start_transfer             ; Start the new xfer
        TST     a2, #1<<30                 ; Checksum operation?
        MOVNE   a3, #0
        STRNE   a3, [v1, #4]               ; Clear checksum value
        TEQ     a4, #0                     ; Skip zero-length non-repeated start xfers
        BEQ     i2c_nextxfer
        MOV     a1, #0
        STR     a1, [v5, #I2C_XBytes]
        STR     v1, [v5, #I2C_XCurrent]
      [ I2CDebug
        MOV     ip, lr
        I2CDebugReg v1, "continue "
        MOV     pc, ip
      |
        MOV     pc, lr
      ]

i2c_stop
        I2CDebugTX "i2c_stop"
        MOV     a1, #IICStatus_Completed
        B       clear_and_return

i2c_rx
        I2CDebugTX "i2c_rx"
        ; RX is a pain because we must read the data register after we've done
        ; all other register updates. We cope with this by pushing an extra
        ; stack frame which will handle the read for us.
        ADR     lr, i2c_rxbyte
        ; Loaded as:  v1  v2  v3  v4  v5  pc
        STMFD   sp!, {a1, a2, a3, v1, v4, lr}
        ; Advance byte count, as if we performed the read
        ADD     a1, a1, #1
        STR     a1, [v5, #I2C_XBytes]
        ; Now that we've done that, the flow is rather simple
        TEQ     a1, a4                     ; Is this the last byte?
        BLEQ    i2c_nextxfer
        ; TXAK processing
        LDR     ip, [v5, #I2C_XRemain]
        SUBS    ip, ip, #1
        STR     ip, [v5, #I2C_XRemain]
        ORREQ   v2, v2, #I2C_CRTXAK       ; ACK hi (missing) on last one
        STREQH  v2, [v4, #I2C_CR]
      [ I2CDebug
        BNE     %FT10
        I2CDebugTX "TXAK"
10
      ]
        ; Wait for next interrupt (+ do delayed rx)
        MOV     a1, #IICStatus_InProgress
        LDMFD   sp!, {v1-v5, pc}

i2c_rxbyte
        ; Handle the delayed byte RX
        ; v1 = byte offset
        ; v2 = iic_transfer word 0
        ; v3 = iic_transfer word 1
        ; v4 = iic_transfer ptr
        ; v5 = I2C controller registers
        ; a1 must be preserved
        I2CDebugTX "i2c_rxbyte"
        LDRH    ip, [v5, #I2C_DR]
 [ I2CDebugData
        I2CDebugReg ip, "RX "
 ]
        ; Is this a checksum or data xfer?
        TST     v2, #1<<30
        ADDNE   v3, v3, ip                 ; Increment checksum
        STREQB  ip, [v3, v1]               ; Store data byte
        STRNE   v3, [v4, #4]               ; Store updated checksum
        LDMFD   sp!, {v1-v5, pc}

i2c_arbitrationlost
        I2CDebugTX "i2c_arbitrationlost"
        ; Clear the IRQ
        MOV     v3, #0
        STRH    v3, [v4, #I2C_SR]
        ; Disable the controller to clear the IBB bit
        STRH    v3, [v4, #I2C_CR]
        ; Clear MSTA, this will trigger a stop bit to be sent
        BIC     v2, v2, #I2C_CRMSTA+I2C_CRIIEN
        STRH    v2, [v4, #I2C_CR]
        ; Now start again from the beginning
        LDR     v1, [v5, #I2C_XStart]
        MRS     a4, CPSR
        B       start_transfer

clear_and_return
        ; Clear MSTA, this will trigger a stop bit to be sent
        BIC     v2, v2, #I2C_CRMSTA+I2C_CRIIEN
        STRH    v2, [v4, #I2C_CR]
        ; Mark transfer chain as complete
        MOV     ip, #0
        STR     ip, [v5, #I2C_XStart]
        LDMFD   sp!, {v1-v5, pc}

unexpected_error
        I2CDebugTX "unexpected_error"
        MOV     a1, #IICStatus_Error
        ; Mark transfer chain as complete
        MOV     ip, #0
        STR     ip, [v5, #I2C_XStart]
        LDMFD   sp!, {v1-v5, pc}

; int HAL_NormalIICOp(uint32_t op, uint8_t *buffer, uint32_t *size)
; in:
;      r0 = b0-15 offset within IIC device to start at
;           b16-23 base IICAddress
;           b24-31 IICBus num
;      r1 = buffer to read from/write to
;      r2 = pointer to number of bytes to transfer
; returns:
;      r0 = IICStatus return code
;      size = bytes successfully transferred (prior to any error)

HAL_NormalIICOp
        Push    "a1-a3,lr"
        LDR     a3, [a3]
        UBFX    a4, a1, #24, #8       ; get bus number
        b       HAL_IICOPCompleter    ; complete it
; int HAL_VideoIICOp(uint32_t op, uint8_t *buffer, uint32_t *size)
; in:
;      r0 = b0-15 offset within IIC device to start at (currently assumed 8 bit)
;           b16-23 base IICAddress
;           b24-31 zero
;      r1 = buffer to read from/write to
;      r2 = pointer to number of bytes to transfer
; returns:
;      r0 = IICStatus return code
;      size = bytes successfully transferred (prior to any error)

HAL_VideoIICOp
        ; Make sure we've got a valid IIC bus to use
        MOV     a4, #VideoI2C_num
        CMP     a4, #255
        MOV     ip, #0
        STREQ   ip, [a3]
        MOVEQ   a1, #IICStatus_Error
        MOVEQ   pc, lr
        ; Check if this is an EDID read or write
        UBFX    a4, a1, #16, #8
        TEQ     a4, #&a0 ; Don't allow writing to EDID for safety reasons
        STREQ   ip, [a3]
        MOVEQ   a1, #IICStatus_Error
        MOVEQ   pc, lr
        TEQ     a4, #&a1
        TSTNE   a1, #&ff00 ; If not EDID read, limit to 0-255 offset in device
        STRNE   ip, [a3]
        MOVNE   a1, #IICStatus_Completed
        MOVNE   pc, lr
        Push    "a1-a3,lr"
        LDR     a3, [a3]
        MOV     a4, #VideoI2C_num

HAL_IICOPCompleter
        ; Build a set of iic_transfer blocks and call RISCOS_IICOpV
        ; We construct (up to) three iic_transfer blocks
        ; - First block is an (optional) single byte write to the EDID segment
        ;   pointer (i.e. ram page address)
        ; - Second block is a single byte write containing the start address
        ;   (lower 8 bits of r0)
        ; - Third block is a read. r2 bytes written to r1.
        ; The E-EDID EEPROM spec says that the segment pointer should
        ; auto-increment when a sequential (i.e. block) read occurs, so we
        ; shouldn't have to worry about splitting requests into 256 byte blocks
        ; and manually writing the pointer each time.
        ; Block 3:
        UBFX    a1, a1, #16, #8 ; Extract base IICAddress
; DebugRegNCR a1, "Blk3 "
; DebugRegNCR a2, ""
; DebugRegNCR a3, ""
        Push    "a1-a3"         ; Push the block on the stack (a2 & a3 are already correct)
        ; Block 2:
        BIC     a1, a1, #1      ; Clear RnW of base address
        ADD     a2, sp, #12     ; sp+12 should point to the 8 bit offset
        MOV     a3, #1
; DebugRegNCR a1, "Blk2 "
; DebugRegNCR a2, ""
; DebugRegNCR a3, ""
        Push    "a1-a3"
        ; Block 1:
        MOV     a1, #&60        ; Write to segment pointer
        ADD     a2, a2, #1      ; With bits 8-15 of the offset
; DebugRegNCR a1, "Blk1 "
; DebugRegNCR a2, ""
; DebugRegNCR a3, ""
        Push    "a1-a3"
        ; Work out if block 1 is needed or not
        LDR     a2, [sp, #36]   ; Get r0
        TST     a2, #&ff00      ; If segment == 0
        MOVEQ   a2, #0          ; ... then avoid matching address &A0/&A1
        AND     a2, a2, #&fe0000
        TEQ     a2, #&a00000
        ; Now attempt to start the transfer
; DebugRegByte a4, "Bus "
        MOV     a2, a4, LSL #24
        ADD     a2, a2, #3
        MOV     a1, sp
        SUBNE   a2, a2, #1      ; Skip block 1 if segment == 0 or not EDID addr
        ADDNE   a1, a1, #12
        ; If HAL_Init isn't done yet, we can't use RISCOS_IICOpV
        LDR     a3, HALInitialised
        CMP     a3, #0
        BEQ     %FT10
        LDR     a3, OSentries+4*OS_IICOpV
        BLX     a3
        B       %FT20
10
        BL      IIC_DoOp_Poll
20
IIC_Completer_Exit
        ; In case of error, assume nothing got transferred at all
        CMP     a1, #IICStatus_Completed
        LDREQ   a4, [sp, #(12*2)+(2*4)] ; Block 3 request size
        MOVNE   a4, #0
; DebugReg a4, "XferCountleft "
        ADD     sp, sp, #12*3           ; Junk the iic_transfer blocks
        STR     a1, [sp, #0]            ; Propagate return code
        LDR     a3, [sp, #8]
        STR     a4, [a3]                ; Actual transfer size
        Pull    "a1-a3,pc"

IIC_DoOp_Poll
        ; IIC transfer function that performs a polling transfer, similar to HAL_VideoIICOp
        ; This allows us to do IIC transfers before RISC OS is fully initialised (e.g. from inside HAL_Init)
        ; Parameters are identical to RISCOS_IICOpV:
        ; r0 = iic_transfer array ptr
        ; r1 = bits 0-23: iic_transfer count
        ;      bits 24-31: bus number
        ; Returns IICStatus return code in R0 (0 success, anything else failure)
        Push    "v1,lr"
 [ {FALSE}
        ; If IRQs and IIC IRQ are enabled, panic
        Push    "a1-a4"
        MRS     a1, CPSR
        TST     a1, #I32_bit
        BNE     %FT10
        ADR     a1, BoardConfig_HALI2CIRQ
        LDRB    a1, [a1, a2, LSR #24]
        IMPORT  HAL_IRQDisable
        BL      HAL_IRQDisable
        CMP     a1, #0
        BEQ     %FT10
;        DebugTX "Warning - IIC_DoOp_Poll called with IIC IRQ enabled!"
        B       .
10
        Pull    "a1-a4"
 ]
        MOV     a3, a1
        MOV     a1, a2, LSR #24
        BIC     a2, a2, #&ff000000
        MOV     v1, a1
        BL      HAL_IICTransfer
        ; Now just poll until we're done
10
        CMP     a1, #IICStatus_InProgress ; Done?
        Pull    "v1,pc", NE
        ADR     lr, %BT10
        MOV     a1, v1
        B       HAL_IICMonitorTransfer

; from time to time, if some bus error occurs, the slave may be
; holding the data line low as it has missed or gained a few clocks
; to get out of this we need to provide some extra clocks on the
; SCL line until the SDA line is released to the high state
; On iMx6 the way we do this is to set the relevant SCL line
; to GPIO mode and toggle the line
; i2c channel is held in I2C_XIONum ref v5
BlockedI2CRecover
; 1 deduce bus number to locate clock details
        LDR     a1, [v5,#I2C_XACTIONum]      ; get the real channel in use
 I2CDebugReg a1,"blkdi2crec "
 I2CDebugReg v4,"i2caddr "
        MOV     a2, #BI2CRTableSize
        MUL     a2, a2, a1
        ADR     v1, BI2CRTable-BI2CRTableSize ; I2C channel number starts at 1
        ADD     v1, v1, a2                   ; relevant lookup table
        LDR     a1, [v1, #sclgp1-BI2CRTable]
        LDR     v3, GPIO_Log
        ADD     v3, v3, a1                   ; relevant GPIO block
        LDRB    a3, [v1, #gpbit1-BI2CRTable]
        MOV     a4, #1
        MOV     a4, a4, LSL a3
 I2CDebugReg v3," gpio "
 I2CDebugReg a4," gpio mask "
        LDR     a3, [v3,#GPIO_DR]
        BIC     a3, a3, a4                   ; set to o/p 0
        STR     a3, [v3,#GPIO_DR]
        LDR     a3, [v3,#GPIO_GDIR]
        ORR     a3, a3, a4                   ; set as o/p
        STR     a3, [v3,#GPIO_GDIR]          ;
; switch to GPIO to toggle 0,1
; at 400khz, each low or high is 2.5us
        LDR     a2, [v1, #sclmux1-BI2CRTable]
        LDR     v2, IOMUXC_Base
        ADD     v2, v2, a2
 I2CDebugReg v2," iomux "
        LDRB    a3, [v1, #gpalt1-BI2CRTable]
        STR     a3, [v2]                    ; switch to gpio - set clock low
 I2CDebugReg a3," sclalt "
        MOV     a2, #9
        LDR     a3, [v3,#GPIO_DR]
100     BIC     a3, a3, a4                  ; set to o/p 0
        STR     a3, [v3,#GPIO_DR]
        Push    "a2-a4"
        MOV     a1, #2                      ; 2 uS
        BL      HAL_CounterDelay
        Push    "a2-a4"
        ORR     a3, a3, a4                   ; set to o/p 0
        STR     a3, [v3,#GPIO_DR]
        Pull    "a2-a4"
        MOV     a1, #2                      ; 2 uS
        BL      HAL_CounterDelay
        Pull    "a2-a4"
        LDRH    ip, [v4, #I2C_SR]
        TST     ip, #I2C_SRIBB              ; bus busy bit
        SUBNES  a2, a2, #1                  ; yes .do it up to 9 times
        BGT     %BT100

22      LDRB    a3, [v1, #sclalt1-BI2CRTable]
        STR     a3, [v2]                    ; switch to scl - set clock high
 I2CDebugReg a3," gpioalt "

        LDRH    v2, [v4, #I2C_CR]
        BIC     a1, v2, #I2C_CRIEN
        STRH    a1, [v4, #I2C_CR]           ; reset chip
        DSB                                 ; ensure it has got to the chip
        STRH    v2, [v4, #I2C_CR]           ; reenable
        DSB

        MOV     a1, #IICStatus_Error        ; abandon
        B       clear_and_return

; table with locations to use for manual clocking for error recovery
BI2CRTable
sclmux1 DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_D21-IOMUXC_BASE_ADDR
sclgp1  DCD     GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
phadd1  DCD     I2C1_BASE_ADDR                  ; to confirm correct table
sclalt1 DCB     6 | (SION_ENABLED<<4)
gpalt1  DCB     5 | (SION_ENABLED<<4)           ; gpio3 bit 21
gpbit1  DCB     21
        ALIGN
BI2CRTableSize * (.-BI2CRTable)
sclmux2 DCD     IOMUXC_SW_MUX_CTL_PAD_KEY_COL3-IOMUXC_BASE_ADDR
sclgp2  DCD     GPIO4_BASE_ADDR-GPIO1_BASE_ADDR
phadd2  DCD     I2C2_BASE_ADDR
sclalt2 DCB     4 | (SION_ENABLED<<4)
gpalt2  DCB     5  | (SION_ENABLED<<4)          ; gpio4 bit 12
gpbit2  DCB     12
        ALIGN
sclmux3 DCD     IOMUXC_SW_MUX_CTL_PAD_GPIO_5-IOMUXC_BASE_ADDR
sclgp3  DCD     GPIO1_BASE_ADDR-GPIO1_BASE_ADDR
phadd3  DCD     I2C3_BASE_ADDR
sclalt3 DCB     4 | (SION_ENABLED<<4)
gpalt3  DCB     5 | (SION_ENABLED<<4)           ; gpio1 bit 5
gpbit3  DCB     5
        ALIGN
 [ SWVideoIICOp
; in:  a1 = bus, a2 = SDA, a3 = SCL
; out: a1 = SDA, a2 = SCL
; ignore a1 i/p as we only implement software IIC for video
HAL_IICSetLines
        Push   "a4"
        LDR     a4, BoardDetectInfo
        TST     a4, #1
        LDR     a1, GPIO_Log

        ADDEQ   a1, a1, #GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
        LDREQ   ip, [a1, #GPIO_DR]
        BICEQ   ip, ip, #(1<<28)
        BICEQ   ip, ip, #(1<<21)
        ANDEQ   a2, a2, #1
        ANDEQ   a3, a3, #1
        ORREQ   ip, ip, a2, lsl #28
        ORREQ   ip, ip, a3, lsl #21
        STREQ   ip, [a1, #GPIO_DR]

        ADDNE   a1, a1, #GPIO4_BASE_ADDR-GPIO1_BASE_ADDR
        LDRNE   ip, [a1, #GPIO_DR]
        BICNE   ip, ip, #(1<<13)
        BICNE   ip, ip, #(1<<12)
        ANDNE   a2, a2, #1
        ANDNE   a3, a3, #1
        ORRNE   ip, ip, a2, lsl #13
        ORRNE   ip, ip, a3, lsl #12
        STRNE   ip, [a1, #GPIO_DR]
        BNE     %ft11
10      LDR     ip, [a1, #GPIO_PSR]
        TST     ip, #1<<28
        MOVEQ   a1, #0
        MOVNE   a1, #1
        TST     ip, #1<<21
        MOVEQ   a2, #0
        MOVNE   a2, #1
        Pull    "a4"
        MOV     pc, lr

11      LDR     ip, [a1, #GPIO_PSR]
        TST     ip, #1<<13
        MOVEQ   a1, #0
        MOVNE   a1, #1
        TST     ip, #1<<12
        MOVEQ   a2, #0
        MOVNE   a2, #1
        Pull    "a4"
        MOV     pc, lr

HAL_IICReadLines
        Push    "a4"
        LDR     a4, BoardDetectInfo
        TST     a4, #1
        LDR     a1, GPIO_Log
        ADDEQ   a1, a1, #GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
        BEQ     %BT10
        ADD     a1, a1, #GPIO4_BASE_ADDR-GPIO1_BASE_ADDR
        B       %BT11
 |
HAL_IICReadLines
HAL_IICSetLines
        MOV     pc, lr
 ]

        END
