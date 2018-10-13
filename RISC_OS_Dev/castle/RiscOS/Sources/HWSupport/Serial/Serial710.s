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
; > Serial710

; This file contains the driver for the C&T 82C710/711 parts but will also
; work with register compatible devices.  The code has been extended to deal
; with parts such as the SMC FDC37C665 or C&T 82C735 which have RX and TX FIFOs.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ PCIHardware
RegSpacing              * 1
HWDeviceNo              * PCI_DeviceNo
        ! 0, "Using PCI attached serial controller"
 |
RegSpacing              * 4
HWDeviceNo              * Serial_DevNo
        ! 0, "Using IO mapped serial controller"
 ]

                        ^ 0, r11
C710_DataWord           # RegSpacing    ; byte wide data port
C710_InterruptEnable    # RegSpacing    ; interrupt enable bits
FIFO_Control            # 0             ; FIFO control register in same position as interrupt flags
C710_InterruptFlags     # RegSpacing    ; flags to indicate what sort of interrupt
C710_FormatWord         # RegSpacing    ; format word
C710_ModemControl       # RegSpacing    ; control register
C710_LineStatus         # RegSpacing    ; current line status
C710_ModemStatus        # RegSpacing    ; modem status

                        ^ 0, r11
C710_BaudDivisorLSB     # RegSpacing    ; bottom 8 bits of baud divisor (only accessable when DRAB =1)
C710_BaudDivisorMSB     # RegSpacing    ; top 8 bits of baud divisor (only accessed when DRAB =1)

; Bits in InterruptEnable

IE_Receive  *   1 :SHL: 0               ; set bit to enable receive interrupts
IE_Transmit *   1 :SHL: 1               ; set bit to enable transmit interrupts
IE_Error    *   1 :SHL: 2               ; set bit to enable error interrupts (Overrun, Parity, Framing, Break)
IE_Modem    *   1 :SHL: 3               ; set bit to enable modem line change interrupts

; Bits in FIFO_Control

FC_Enable       *       1:SHL:0         ; enable TX and RX FIFOs
FC_RXClear      *       1:SHL:1         ; clear RX FIFO
FC_TXClear      *       1:SHL:2         ; clear TX FIFO
FC_RXTrigger1   *       2_00:SHL:6      ; RX interrupt trigger level (given our IRQ latency problems use 1 byte trigger)
FC_RXTrigger4   *       2_01:SHL:6
FC_RXTrigger8   *       2_10:SHL:6
FC_RXTrigger14  *       2_11:SHL:6

FIFO_Trigger    *       FC_RXTrigger1
FIFO_Size       *       16

; Values in InterruptFlags

IF_NoInterrupt  *       1
IF_LineStatus   *       6
IF_RXFull       *       4
IF_RXTimeout    *       12
IF_TXEmpty      *       2
IF_Modem        *       0
IF_IRQBits      *       15

; Bits in ModemControl

MC_DTROn        *       1 :SHL: 0       ; set bit to turn DTR on
MC_RTSOff       *       1 :SHL: 1       ; control RTS line
MC_OUT1         *       1 :SHL: 2       ; control OUT1 line
MC_OUT2         *       1 :SHL: 3       ; set bit to enable serial interrupts to get to the rest of the chip
MC_LoopBack     *       1 :SHL: 4       ; turn on loopback

; Bits in LineStatus

LS_RXFull       *       1 :SHL: 0       ; 1 => character is in receive buffer
LS_Overrun      *       1 :SHL: 1       ; 1 => overrun error
LS_Parity       *       1 :SHL: 2       ; 1 => parity error
LS_Framing      *       1 :SHL: 3       ; 1 => framing error
LS_Break        *       1 :SHL: 4       ; 1 => break error
LS_TXEmpty      *       1 :SHL: 5       ; 1 => transmit buffer empty
LS_TXShiftEmpty *       1 :SHL: 6       ; 1 => both Transmit buffer and shift register
                                        ; are empty

; Bits in ModemStatus

MS_CTSChanged   *       1 :SHL: 0       ; 1 => CTS has changed state
MS_DSRChanged   *       1 :SHL: 1       ; 1 => DSR has changed state
MS_RIRisen      *       1 :SHL: 2       ; 1 => RI has gone from 0 to 1
MS_DCDChanged   *       1 :SHL: 3       ; 1 => DCD has changed state
MS_CTSLow       *       1 :SHL: 4       ; CTS state
MS_DSRLow       *       1 :SHL: 5       ; DSR state
MS_RIHigh       *       1 :SHL: 6       ; RI state
MS_DCDLow       *       1 :SHL: 7       ; DCD state

; Bits in FormatWord

FW_BreakEnable    *     1 :SHL: 6       ; set to enable break signal
FW_AddressDivisor *     1 :SHL: 7       ; set to access baud rate divisors

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 [ :LNOT: HAL
Combo                   * &03010000
 ]
SMIindex                * &3A8
SMIaccess               * &3AC
SMIENBL1                * &0C
serial1_bit             * 8


        MACRO
        Palette $colour, $reg1, $reg2
 [ {TRUE}
        MOV     $reg1, #&03400000
        LDR     $reg2, =$colour
        STR     $reg2, [$reg1]
 ]
        MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Serial710
;
; in:   r0  = reason code
;               if bit 31 set then
;                       r2 -> return frame containing r1-r7 for call
;               if bit 31 clear then normal call from DeviceFS
;
; out:  -
;
; This call handles the calls received from DeviceFS, the interface is slightly
; involved.  If the reason code has bit 31 clear then it is a normal DeviceFS
; call with r1..r7 containing parameters.
;
; With bit 31 set then r2 is a pointer to a command block containing the
; relevant parameters.  This is mainly to save lots of faffing around in
; the support module and moving registers about.
;

Serial710       ROUT

                Debug   interface, "serial710, reason =", r0

                TST     r0, #DeviceCall_ExternalBase
                BNE     %20                             ; is it a call from the support module?

                Debug   interface, "is an internal call from DeviceFS", r0

                CMP     r0, #(%20-%00)/4
                ADDCC   pc, pc, r0, LSL #2              ; despatch as required
                MOV     pc, lr
00
                B       open710                         ; initialise
                B       close710                        ; finalise
                B       wakeupTX710                     ; wake up for TX
                MOV     pc, lr                          ; wake up for RX
                MOV     pc, lr                          ; sleep rx
                MOV     pc, lr                          ; enum dir
                B       CreateForTX                     ; create buffer for TX
                B       CreateForRX                     ; create buffer for RX
                B       thresholdhalt710
                B       thresholdresume710
                MOV     pc, lr                          ; eod
                B       newstream710
20
                SUB     r0, r0, #DeviceCall_ExternalBase
                CMP     r0, #(%40-%30)/4
                ADRCSL  r0, ErrorBlock_Serial_BadControlOp
                DoError CS                              ; return error if invalid

                Push    "r11, lr"

                Debug   interface, "call from support module", r0
                Debug   interface, "frame at", r2
                DebugFrame interface, r2, 24

                MOV     r11, r2                         ; -> return frame
                LDMIA   r11, {r1-r7}

                MOV     lr, pc                          ; -> return address
                ADD     pc, pc, r0, LSL #2              ;    despatch as required
                B       %40
30
                B       reset710
                B       remove710
                B       setbaud710
                B       change710flags
                B       change710format
                B       break710
                B       nobreak710
                B       SetExtent                       ; common
                B       getchar                         ; common
                B       putchar                         ; common
                B       enumerate710
                B       GetDeviceName                   ; common
40
                STMIA   r11, {r1-r7}
                Pull    "r11, pc"                       ; and balance the stack

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: open710
;
; in:   r0  = reason codes
;       r1  = device handle
;       r2  = external stream handle
;       r3  = flags to indicate if for input or output
;
; out:  r2  = internal stream handle
;
; This routine is used to open a stream onto the device it must store the
; relevant handles and setup the device.
;

open710         Entry   "r0"

                Debug   open, "handle", r2
                Debug   open, "flags", r3

                BL      SetPower_On

                TST     r3, #2_1                        ; is it a RX or TX stream?
                STREQ   r2, InputHandle
                BEQ     %FT90
 [ KickSerialTX
                BL      SetTXKick                       ; if TX then set up call every to kick serial
 ]
 [ NewSplitScheme
                EXIT

                LDRB    r0, SerialRXBaud                ; check if RX baud = TX baud
                LDRB    lr, SerialTXBaud
                CMP     r0, lr
                STREQ   r2, OutputHandle                ; if equal then OK
                EXIT    EQ

                PullEnv
                ADR     r0, ErrorBlock_Serial_NoSplitBaudRates
                DoError

                MakeErrorBlock Serial_NoSplitBaudRates
 |
                STR     r2, OutputHandle
                EXIT
 ]
90
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: close710
;
; in:   r0  = reason code
;       r2  = internal handle
;       SVC mode
;
; out:  -
;
; This code handles the closing of the file.  When received then we should halt
; the relevant transmission type until the stream is re-opened.
;

close710        Entry   "r0-r2"

                Debug   close, "Close handle", r2

                MOV     lr, #-1
                MOV     r1, #0

                LDR     r0, InputHandle
                TEQ     r0, r2                          ; Input stream being closed?
                TEQNE   r2, #0                          ; Or all streams?
                STREQ   lr, InputBufferHandle           ; Yes, invalidate input buffer handle
                STREQ   r1, InputHandle                 ;  and input handle
                BLEQ    UpdateRTSForegd                 ;  and update RTS

                MOV     lr, #-1
                LDR     r0, OutputHandle
                TEQ     r0, r2                          ; Output stream being closed?
                TEQNE   r2, #0                          ; Or all streams?
                STREQ   lr, OutputBufferHandle          ; Yes, invalidate output buffer handle
                STREQ   r1, OutputHandle                ;  and output handle
 [ KickSerialTX
                BLEQ    RemoveTXKick                    ; If output/all then remove call every set up in open710
 ]
 [ FixPowerSave
                BL      SetPower_Off                    ; Attempt to power down, service call faulted if other channel open
 ]
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: newstream710
;
; in:   r0  = reason code
;       r2  = internal handle
;       r3  = buffer handle
;       SVC mode
;
; out:  -
;
; This call is issued after the stream has been created, it gives me a chance
; to setup the device correctly and start transmission etc, etc...
;

newstream710    Entry   "r0-r2"
                LDR     r0, InputHandle                         ; is it the input stream?
                TEQ     r0, r2
                STREQ   r3, InputBufferHandle                   ; save buffer handle
                STRNE   r3, OutputBufferHandle
                BLEQ    UpdateRTSForegd                         ; if opening input stream update RTS
                CLRV
                EXIT

UpdateRTSForegd EntryS  "r2, r11"
                WritePSRc SVC_mode + I_bit,lr                   ; update RTS call require IRQs off
                LDR     r2, SerialDeviceFlags                   ; and r2 = SerialDeviceFlags
                LDR     r11, HWAddress                          ; and r11 -> UART
                BL      UpdateDTRRTSTXI710
                EXITS   ,cf

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: reset710
;
; in:   r0  = reason code.
;       SVC mode
;
; out:  -
;
; This code is called to reset the CHIPS 710 controller, it will reset the modem control
; registers, enable the relevant interrupts and setup the IRQ handler for RISC OS.
;
; This routine may be called at other times than reset, if the power to the serial bits
; has been switched off and then reapplied.
;

reset710        Entry   "r0-r3, r11"
                LDR     r11, HWAddress                                  ; -> UART

                LDR     r2, SerialDeviceFlags
                ORR     r2, r2, #(1:SHL:SF_TXDormant):OR:(1:SHL:SF_NoSplitBaudRates)
                STR     r2, SerialDeviceFlags

                MVN     r1, r2                                          ; enable/disable serial FIFO depending on serial flags
                BL      SetFIFO

 [ Fix710TXEnable
                MOV     r0, #IE_Receive :OR: IE_Error :OR: IE_Modem
                STRB    r0, C710_InterruptEnable
 ]
                MOV     r0, #IE_Receive :OR: IE_Transmit :OR: IE_Error :OR: IE_Modem ; enable all interrupts
                STRB    r0, C710_InterruptEnable

                MOV     r0, #MC_DTROn :OR: MC_OUT2                      ; turn on DTR,RTS and enable serial IRQ
                STRB    r0, C710_ModemControl

                MOV     r1, #0                                          ; ensure CTS and DSR are updated in SerialFlags
                MOV     r2, #-1
                BL      change710flags

                LDR     r3, Flags                                       ; do we already own the IRQ vector?
                TST     r3, #f_SerialIRQ
                BNE     %FT10                                           ; yes, then skip

                MOV     r0, #HWDeviceNo
                ADDR    r1, irq710                                      ; -> irq routine
                MOV     r2, wp
                SWI     XOS_ClaimDeviceVector                           ; and claim the irq routine
                STRVS   r0, [sp]
                PullEnv VS
                DoError VS                                              ; return error (V set, r0 -> block)

                ORR     r3, r3, #f_SerialIRQ                            ; and we now have the IRQ vector
                STR     r3, Flags
10
 [ HAL
                Push    "r8,r9"
                MOV     r0, #HWDeviceNo
                MOV     r8, #0
                MOV     r9, #EntryNo_HAL_IRQEnable
                SWI     XOS_Hardware
                Pull    "r8,r9"
 |
 [ PhoebeHardware
                LDR     r1, =Combo
 |
                LDR     r1, =IOC
 ]
                SETPSR  I_bit, lr,,r3                                   ; disable IRQs while IOCIRQMSKB updated
 [ PhoebeHardware
                MOV     r0, #SMIENBL1
                STR     r0, [r1, #SMIindex]
                LDR     r0, [r1, #SMIaccess]
                ORR     r0, r0, #serial1_bit
                STR     r0, [r1, #SMIaccess]
 |
                LDRB    r0, [r1, #IOCIRQMSKB]
                ORR     r0, r0, #serial_bit
                STRB    r0, [r1, #IOCIRQMSKB]                           ; enable serial IRQs from 710
 ]
                RestPSR r3                                              ; restore interrupt state
 ]
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: remove710
;
; in:   SVC mode
;
; out:  -
;
; This code is called when the device should detach itself from the various
; vectors that mean that it has a grasp on IRQ chains.
;

remove710       Entry   "r0-r3"
                LDR     r3, Flags
                TST     r3, #f_SerialIRQ                ; serial IRQ handler still setup?
                EXIT    EQ

                MOV     r0, #HWDeviceNo
                ADDR    r1, irq710                      ; r1 -> code for handling serial device
                MOV     r2, wp                          ; r2 -> workspace for device IRQ
                SWI     XOS_ReleaseDeviceVector
                STRVS   r0, [sp]
                PullEnv VS
                DoError VS                              ; return error (r0 -> block)

                BIC     r3, r3, #f_SerialIRQ
                STR     r3, Flags                       ; mark as not owning the IRQ vectors
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: setbaud710
;
; in:   r0  = reason code
;       r1  = RX baud rate / -1 to read
;       r2  = TX baud rate / -1 to read
;       SVC mode
;
; out:  r1  = new RX baud (not necessarily what you asked for)
;       r2  = new TX baud (-------------""-------------------)
;       r3  = old RX baud
;       r4  = old TX baud
;
; This call is used to set the RX/TX baud rates, it should be noted that the 710
; controller does not support split baud rates and we must decide on which one
; to use.
;
; If both are specified as -1, ie. read then we simply setup the registers and
; return.
;
; In the old split scheme, if either r1 or r2 is -1 then the baud was changed to the value specified in the
; non -ve register.  If both were setup then we used r1 (RX). We return with both r1 and r2 set to the new value.
;
; In the new split scheme, we remember both RX and TX rates separately, but store the RX rate into the hardware.
; If an output stream is opened when split baud rates are set, an error is returned
;

setbaud710      Entry   "r0, r5, r11"

                LDRB    r3, SerialRXBaud
                LDRB    r4, SerialTXBaud                                ; read existing baud rates

                Debug   baud710, "baud710: rx, tx original baud rates", r3, r4

                MOV     r5, #-1

                CMP     r2, #0                                          ; if setting TX to zero
                MOVEQ   r2, #7                                          ; then use 7 (9600)
                CMP     r2, #-1                                         ; if reading TX
                MOVEQ   r2, r4                                          ; then use old value
 [ :LNOT: NewSplitScheme
                MOVNE   r5, r2                                          ; if setting TX then use this as baud
 ]

                CMP     r1, #0                                          ; if setting RX to zero
                MOVEQ   r1, #7                                          ; then use 7 (9600)
                CMP     r1, #-1                                         ; if reading RX
                MOVEQ   r1, r3                                          ; then use old value
                MOVNE   r5, r1                                          ; if setting RX then use this as baud
                                                                        ; (overrides TX if setting both)

                Debug   baud710, "baud710: actual values being set", r1, r2

                CMP     r1, r3                                          ; will the call invoke any change?
                CMPEQ   r2, r4
                EXIT    EQ                                              ; no, so don't bother return now!

                Debug   baud710, "baud710: rx, tx baud rates:", r1, r2
 [ NewBaudRates
                CMP     r1, #serialbaud_NewMAX                          ; if either baud rate is invalid
                CMPCC   r2, #serialbaud_NewMAX                          ; then complain
 |
                CMP     r1, #serialbaud_OldMAX                          ; if either baud rate is invalid
                CMPCC   r2, #serialbaud_OldMAX                          ; then complain
 ]
                PullEnv CS
                ADRCSL  r0, ErrorBlock_Serial_BadBaud                   ; r0 -> error block
                DoError CS                                              ; return error

                Debug   baud710, "baud710: specified baud:", r5

                PHPSEI

 [ NewSplitScheme
                STRB    r1, SerialRXBaud                                ; store both rates separately
                STRB    r2, SerialTXBaud
                CMP     r5, #-1                                         ; if not setting RX
                BEQ     %FT10                                           ; then skip hardware programming
 |
                STRB    r5, SerialRXBaud                                ; mark them both the same
                STRB    r5, SerialTXBaud                                ; (because they will be)
                MOV     r1, r5                                          ; return new rates as both the same
                MOV     r2, r5
 ]

                LDR     r11, HWAddress                                  ; r11 -> uart base

                ADR     r0, bauddivisors
                LDR     r5, [r0, r5, LSL #2]                            ; get baud rate crystal divisor

 [ NewTXStrategy
                CMP     r5, #6
                LDR     r0, SerialDeviceFlags
                ORRCC   r0, r0, #1:SHL:SF_FillTXFIFO
                BICCS   r0, r0, #1:SHL:SF_FillTXFIFO
                STR     r0, SerialDeviceFlags
 |
                STR     r5, SerialBaudDivisor
 ]

                LDRB    r0, C710_FormatWord
                ORR     r0, r0, #FW_AddressDivisor                      ; set DRAB to allow reprogram of baud generators
                STRB    r0, C710_FormatWord

                STRB    r5, C710_BaudDivisorLSB
                MOV     r5, r5, LSR #8
                STRB    r5, C710_BaudDivisorMSB                         ; write the baud value as 16b across two 8b registers
                BIC     r0, r0, #FW_AddressDivisor
                STRB    r0, C710_FormatWord                             ; and then restore the DRAB bit to original state

 [ :LNOT: NewTXStrategy
                Push    "r1,r2,lr"
                LDR     r2, SerialDeviceFlags
                TST     r2, #1:SHL:SF_UseFIFOs
                MVNNE   r1, r2
                BLNE    SetFIFO
                Pull    "r1,r2,lr"
 ]

10
                PLP
                CLRV
                EXIT

                ; table used to convert the specified baud value into a clock divisor
                ; as used by the 710 UART.

bauddivisors
                & 12    ; 9600
                & 1536  ; 75
                & 768   ; 150
                & 384   ; 300
                & 96    ; 1200
                & 48    ; 2400
                & 24    ; 4800
                & 12    ; 9600
                & 6     ; 19200
                & 2304  ; 50
                & 1047  ; 110
                & 857   ; 134.5
                & 192   ; 600
                & 64    ; 1800
                & 32    ; 3600
                & 16    ; 7200
 [ NewBaudRates
                & 3     ; 38400
                & 2     ; 57600
                & 1     ; 115200
  [ PCIHardware
                & 32770 ; 230400
  ]
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: change710flags
;
; in:   r0  = reason code
;       r1  = EOR mask
;       r2  = AND mask
;       SVC mode
;
; out:  r1  = OLD flags
;       r2  = NEW flags
;
; This code will modify the flags within the 710 controller, it is also used
; to return the state in the top 16 bits.  When called the routine will
; attempt to reprogram the values as required, it also compiles the
; status bits.
;
; This call is used to read/write the serial status.
;
;       bit     rw / ro         value   meaning
;
;       0       r/w             0       No software control. Use RTS handshaking if bit 5 clear.
;
;                               1       Use XON/XOFF protocol. Bit 5 ignored.
;
;       1       r/w             0       Use ~DCD bit.  If ~DCD bit in the status
;                                       register goes high, then cause a serial
;                                       event.  Also, if a character is received when
;                                       ~DCD is high then cause a serial event, and do not enter the
;                                       character into the buffer.
;
;                               1       Ignore the ~DCD bit.  Note that some serial chips (GTE and CMD)
;                                       have reception and transmission problems if this bit is high.
;
;       2       r/w             0       Use the ~DSR bit.  If the ~DSR bit in the status
;                                       register is high, then do not transmit characters.
;
;                               1       Ignore ~DSR bit.
;
;       3       r/w             0       DTR on (normal operation).
;                               1       DTR off (on 6551 cannot use serial in this state).
;
;       4       r/w             0       Use the ~CTS bit. If the ~CTS bit in the status
;                                       register is high, then do not transmit characters.
;
;                               1       Ignore ~CTS bit (not supported on 6551 hardware).
;
;       5       r/w             0       Use RTS handshaking if bit 0 is clear.
;                               1       Do not use RTS handshaking.
;                                       This bit is ignored if bit 0 is set.
;
;       6       r/w             0       Input not suppressed.
;                               1       Input is suppressed.
;
;       7       r/w             0       RTS controlled by handshaking system (low if no RTS handshaking)
;                               1       RTS high.
;                                       Users should only modify this bit if RTS handshaking is NOT in use.
;
;       8       r/w             0       Do not use FIFOs (if present)
;                               1       Use FIFOs (if present)
;
;       9..15   ro              0       Reserved for future expansion.
;
;       16      ro              0       XOFF not received
;                               1       XOFF has been received.  Transmission is stopped by this occurence.
;
;       17      ro              0       The other end is intended to be in XON state.
;                               1       The other state is intended to be in XOFF state.  When this
;                                       bit is set, then it means that an XOFF has been sent and it will be cleared
;                                       when an XON is sent by the buffering software.  Note that the fact that this
;                                       bit is set does not imply that the other end has received
;                                       an XOFF yet.
;
;       18      ro              0       The ~DCD bit is low, ie. carrier present.
;                               1       The ~DCD bit is high, ie. no carrier.
;                                       This bit is stored in the variable and updated on modem status interrupts
;
;       19      ro              0       The ~DSR bit is low, ie. 'ready' state.
;                               1       The ~DSR bit is high, ie. 'not-ready' state.
;                                       This bit is stored in the variable and updated on modem status interrupts
;
;       20      ro              0       The ring indicator bit is low.
;                               1       The ring indicator bit is high.
;                                       This bit is not stored in the variable but is read directly from the hardware.
;
;       21      ro              0       CTS low -> clear to send
;                               1       CTS high -> not clear to send
;                                       This bit is stored in the variable and updated on modem status interrupts.
;
;       22      ro              0       User has not manually sent an XOFF
;                               1       User has manually sent an XOFF
;
;       23      ro              0       Space in receive buffer above threshold
;                               1       Space in receive buffer below threshold
;
;       24..27  ro              0       Reserved for future expansion.
;
;       28      ro              0       Not using serial FIFOs
;                               1       Using serial FIFOs
;
;       29      ro              0       We have normal characters to transmit
;                               1       No normal characters to transmit (excluding breaks, XON/XOFFs)
;
;       30      ro              0       Not sending a break signal
;                               1       Currently sending a break signal
;
;       31      ro              0       Not trying to stop a break
;                               1       Trying to stop sending a break
;


change710flags  Entry   "r7-r11"

                BL      SetPower_On

                LDR     r11, HWAddress                                  ; r11 -> UART base

                LDR     r10, = :NOT: SF_ModifyBits
                BIC     r1, r1, r10                                     ; EOR mask cannot modify these bits
                ORR     r2, r2, r10                                     ; AND mask must preserve these bits

; disable IRQs round this bit because
; a) we are updating SerialDeviceFlags, which gets modified under IRQ
; b) if ModemStatus changes (and generates an IRQ) after we read it but
;    before we update SerialDeviceFlags, we'd be writing an old state into
;    the flags

                SETPSR  I_bit, lr,,r7                                   ; disable IRQs
                LDRB    r8, C710_ModemStatus

                Debug   flags710, "flags710: 710 modem status", r8

                LDR     r10, SerialDeviceFlags                          ; get global serial state flags

                Debug   flags710, "flags710: serial device flags", r10
                Debug   flags710, "flags710: uart base", r11

                BIC     r10, r10, #(1:SHL:SF_DCDHigh):OR:(1:SHL:SF_DSRHigh):OR:(1:SHL:SF_Ringing):OR:(1:SHL:SF_CTSHigh)

                TST     r8, #MS_CTSLow                                  ; OR in state of CTS
                ORREQ   r10, r10, #1:SHL:SF_CTSHigh

                TST     r8, #MS_DSRLow                                  ; OR in state of DSR
                ORREQ   r10, r10, #1:SHL:SF_DSRHigh

                TST     r8, #MS_RIHigh                                  ; OR in state of RI
                ORRNE   r10, r10, #1:SHL:SF_Ringing

                TST     r8, #MS_DCDLow
                ORREQ   r10, r10, #1:SHL:SF_DCDHigh

                AND     r9, r10, r2
                EOR     r2, r9, r1
                MOV     r1, r10                                         ; well munge them together and what ya got...
                STR     r2, SerialDeviceFlags                           ; store serial device flags (new!)

                Debug   flags710, "flags710: old, new:", r1, r2

                TEQ     r1, r2                                          ; any change ?
                BEQ     %FT10
                BL      SetFIFO                                         ; if so, then update FIFO
                BL      UpdateDTRRTSTXI710                              ; if so, then update DTR, RTS and TXI
10
                RestPSR r7
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       SetFIFO
;
; Update state of FIFO
;
; in:   r1 = old flags
;       r2 = new flags
;       r11 -> C710_UART
;
; out:  r2 possibly updated
;       All other regs preserved
;

SetFIFO         Entry   "r1"

                EOR     lr, r1, r2                                      ; if bit not changed then
                TST     lr, #1:SHL:SF_UseFIFOs
                EXIT    EQ                                              ;   nothing to do

                LDR     lr, Flags
                TST     lr, #f_UseFIFOs                                 ; if we have no FIFOs then
                BICEQ   r2, r2, #1:SHL:SF_UseFIFOs                      ;   make sure bit is clear
                BEQ     %FT40                                           ;   and exit

                MOV     r1, #FIFO_Size                                  ; We're enabling/disabling FIFOs so clear RX data first
10
                LDRB    lr, C710_DataWord
                SUBS    r1, r1, #1
                BNE     %BT10

                TST     r2, #1:SHL:SF_UseFIFOs                          ; Enable/disable FIFOs based on flags passed in
 [ NewTXStrategy
                MOVEQ   lr, #0
                MOVNE   lr, #FC_Enable :OR: FC_RXClear :OR: FC_TXClear :OR: FIFO_Trigger
 |
                BEQ     %FT20

                LDR     lr, SerialBaudDivisor
                CMP     lr, #12                                                                 ; If current baud rate <= 9600 then
                BCS     %FT20                                                                   ;   disable FIFOs
                MOV     lr, #FC_Enable :OR: FC_RXClear :OR: FC_TXClear :OR: FIFO_Trigger        ; else enable FIFOs
                ORR     r2, r2, #1:SHL:SF_FIFOsEnabled
                B       %FT30
20
                MOV     lr, #0                                          ; Disable FIFOs
                BIC     r2, r2, #1:SHL:SF_FIFOsEnabled
30
 ]
                STRB    lr, FIFO_Control
40
                STR     r2, SerialDeviceFlags
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       UpdateDTRRTSTXI710
;
; Update DTR, RTS and TXI from SerialDeviceFlags and other state
;
; in:   r2 = SerialDeviceFlags
;       r11 -> C710_UART
;       Works in IRQ or SVC mode
;       IRQs disabled
;
; out:  All preserved
;

UpdateDTRRTSTXI710 Entry   "r0"
                LDRB    r0, C710_ModemControl                           ; get the status and control registers
                Debug   flags710, "flags710: old control register:", r0

; first work out DTR state

                TST     r2, #1:SHL:SF_DTROff                            ; change DTR?
                BICNE   r0, r0, #MC_DTROn
                ORREQ   r0, r0, #MC_DTROn

; now work out RTS state

                TST     r2, #1:SHL:SF_UserRTSHigh                       ; if user forcing RTS high
                BNE     setrtshigh710                                   ; then set high
                TST     r2, #(1:SHL:SF_XONXOFFOn):OR:(1:SHL:SF_NoRTSHandshake) ; if not using RTS handshaking
                BNE     setrtslow710                                    ; then set low
                TST     r2, #1:SHL:SF_Thresholded                       ; if not enough space in RX buffer
                BNE     setrtshigh710                                   ; then set high
                LDR     lr, InputBufferHandle
                CMP     lr, #-1
                BEQ     setrtshigh710
setrtslow710
                ORR     r0, r0, #MC_RTSOff
                B       %FT10

setrtshigh710
                BIC     r0, r0, #MC_RTSOff
10
                STRB    r0, C710_ModemControl

                Debug   flags710, "flags710: new control register:", r0

; now update TXI state

                TST     r2, #1:SHL:SF_StoppingBreak                     ; if stopping break
                BNE     disableTXI710                                   ; then don't transmit anything
                TST     r2, #1:SHL:SF_BreakOn                           ; if transmitting break
                BNE     enableTXI710                                    ; then always enable it (to transmit nulls)

                TST     r2, #1:SHL:SF_CTSHigh                           ; if CTS low, then skip
                BEQ     %FT20
                TST     r2, #1:SHL:SF_CTSIgnore                         ; else if CTS high and not ignoring CTS
                BEQ     disableTXI710                                   ; disable TXI
20
                TST     r2, #1:SHL:SF_DSRHigh                           ; if DSR low, then skip
                BEQ     %FT30
                TST     r2, #1:SHL:SF_DSRIgnore                         ; else if DSR high and not ignoring DSR
                BEQ     disableTXI710                                   ; disable TXI
30
                LDRB    lr, SerialXONXOFFChar                           ; if we have an XON or XOFF to send
                TEQ     lr, #0
                BNE     enableTXI710                                    ; then enableTXI

                TST     r2, #1:SHL:SF_HeXOFFedMe                        ; if he XOFFed me
                TSTEQ   r2, #1:SHL:SF_TXDormant                         ; or if no chars to send
                BNE     disableTXI710                                   ; then disableTXI
enableTXI710
                LDRB    lr, C710_InterruptEnable
 [ Fix710TXEnable
                BIC     lr, lr, #IE_Transmit
                STRB    lr, C710_InterruptEnable
 ]
                ORR     lr, lr, #IE_Transmit
                STRB    lr, C710_InterruptEnable
                EXIT

disableTXI710
                LDRB    lr, C710_InterruptEnable
                BIC     lr, lr, #IE_Transmit
                STRB    lr, C710_InterruptEnable

                MOV     lr, #0                                          ; make sure we put no more in FIFO (if we have one)
                STRB    lr, SerialTxByteCount

                EXIT

                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: change710format
;
; in:   r0  = reason code
;       r1  = new format / -1 to read
;       SVC mode
;
; out:  r1  = old format
;
; This call modifies the format register for the 710 controller, it will
; setup the stop bits, word length and parity checking bits.
;
; The soft copy, SerialDataFormat, is only maintained so we can restore the correct data format
; if the power is switched off since we last set it.
;

; in format register                                    in r1
; ------------------                                    -----
;
; b0, b1        => word length                          b0, b1          => word length
;
; 0   0         => 5 bits                               0   0           => 8 bit word
; 0   1         => 6 bits                               0   1           => 7 bit word
; 1   0         => 7 bits                               1   0           => 6 bit word
; 1   1         => 8 bits                               1   1           => 5 bit word
;
;
; b2            => stop bits                            b2              => stop bits
;
; 0             => 1                                    0               => 1
; 1             => 1.5 (5 bit word)                     1               => 1.5 (5 bit word)
; 1             => 2 (6 bit word)                       1               => 2 (6 bit word)
; 1             => 2 (7 bit word)                       1               => 2 (7 bit word)
; 1             => 2 (8 bit word)                       1               => 2 (8 bit word no parity)
;                                                       1               => 1 (8 bit word with parity)
;                                                       (we assume no-one will use this option)
;
;
; b3            => parity enable                        b3              => parity enable
;
; 0             => disabled (no parity)                 0               => disabled (no parity)
; 1             => enabled (lots of parity)             1               => enabled (lots of parity)
;
;
; b4, b5        => parity type (if b3 =1)               b4, r5          => parity type (if b3 =1)
;
; 0   0         => odd parity                           0   0           => odd parity
; 1   0         => even parity                          1   0           => even parity
; 0   1         => 1                                    0   1           => 1
; 1   1         => 0                                    1   1           => 0

change710format Entry   "r9-r11"

                LDR     r11, HWAddress                                  ; -> 710 uart

                PHPSEI  ,r9                                             ; disable IRQs round updates to FormatWord

                LDRB    r10, C710_FormatWord                            ;  = 710 format register

; now mangle bits 0,1 to convert to old format:

; 00 -> 11
; 01 -> 10
; 10 -> 01
; 11 -> 00

; this is just an EOR with 3, unlike what the original 82C710 spec said

                AND     r9, r10, #2_00111111
                EOR     r9, r9, #3                      ; mangle chip's bits into user format
                CMP     r1, #-1                         ; if writing then
                ANDNE   r1, r1, #2_00111111             ; mask out strange bits
                CMPNE   r1, r9                          ; if reading or if writing the same state
                BEQ     %FT10                           ; then don't update

                EOR     r1, r1, #3                      ; mangle user bits into chip's format
                BIC     r10, r10, #2_00111111
                ORR     r10, r10, r1
                STRB    r10, C710_FormatWord
10
                PLP
                MOV     r1, r9
                EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: break710
;
; in:   r0  = reason code
;       SVC mode
;
; out:  -
;
; This code sets the 710 sending a break.
;
; Load a NULL character to transmit register now.
; Set bit 6 of FormatWord after the next transmit buffer empty occurs.
;

break710        EntryS  "r0, r11"

                BL      SetPower_On

                WritePSRc SVC_mode + I_bit, lr                  ; disable IRQs round this bit

                LDR     r11, HWAddress
                MOV     r0, #0                                  ; stick a null in the transmit data register now
                STRB    r0, C710_DataWord

                LDRB    r0, C710_InterruptEnable                ; enable transmit interrupts
 [ Fix710TXEnable
                BIC     r0, r0, #IE_Transmit
                STRB    r0, C710_InterruptEnable
 ]
                ORR     r0, r0, #IE_Transmit
                STRB    r0, C710_InterruptEnable

                LDR     lr, SerialDeviceFlags                   ; and set the bit in SerialDeviceFlags
                ORR     lr, lr, #1:SHL:SF_BreakOn
                STR     lr, SerialDeviceFlags
                EXITS   ,cf

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: nobreak710
;
; in:   r0  = reason code
;       SVC_mode
;
; out:  -
;
; This code stops sending the break for the 710.
;
;

nobreak710      Entry   "r0,r6-r7,r11"

                BL      SetPower_On

 [ No32bitCode
                MOV     lr, pc
                AND     lr, lr, #I_bit
                EOR     lr, lr, #I_bit                  ; value to EOR with PC to toggle between IRQs off
                                                        ; and entry state

                TEQP    lr, pc                          ; disable IRQs first
 |
                MRS     r7, CPSR
                ORR     lr, r7, #I32_bit
                MSR     CPSR_c, lr                      ; disable IRQs first
 ]

                LDR     r11, HWAddress
                LDR     r6, WaitForIRQsToFire

                LDR     r0, SerialDeviceFlags
                ORR     r0, r0, #1:SHL:SF_StoppingBreak ; indicate that we wish to stop break
                STR     r0, SerialDeviceFlags

                LDRB    r0, C710_InterruptEnable
                BIC     r0, r0, #IE_Transmit            ; disable transmit interrupts
                STRB    r0, C710_InterruptEnable

; now go into a loop, polling the transmitter empty bit, but processing any line status errors we get
; (since reading line status clears these!)

10
                LDRB    r0, C710_LineStatus
                TST     r0, #LS_Overrun :OR: LS_Parity :OR: LS_Framing :OR: LS_Break
                BNE     %FT50                           ; if a line status error, then process it
15
                TST     r0, #LS_TXShiftEmpty
                BNE     %FT20                           ; transmitter has finished shifting, so can clear break bit

 [ No32bitCode
                TEQP    lr, pc                          ; restore IRQ state for a bit
 |
                MSR     CPSR_c, r7                      ; restore IRQ state for a bit
 ]
                TEQ     r6, #0
                MOVNE   lr, pc
                MOVNE   pc, r6                          ; if needed do enough of a delay interrupts to occur
 [ No32bitCode
                TEQP    lr, pc                          ; then disable them again
 |
                ORR     lr, r7, #I32_bit                ; then disable them again
                MSR     CPSR_c, lr
 ]
                B       %BT10

20
                LDRB    r0, C710_FormatWord
                BIC     r0, r0, #FW_BreakEnable         ; disable break signal
                STRB    r0, C710_FormatWord

                LDR     r0, SerialDeviceFlags
                BIC     r0, r0, #(1:SHL:SF_BreakOn):OR:(1:SHL:SF_StoppingBreak) ; finished the break completely
                STR     r0, SerialDeviceFlags

                LDRB    lr, C710_InterruptEnable
 [ Fix710TXEnable
                BIC     lr, lr, #IE_Transmit
                STRB    lr, C710_InterruptEnable
 ]
                ORR     lr, lr, #IE_Transmit            ; enable transmit interrupts again
                STRB    lr, C710_InterruptEnable

 [ No32bitCode
                EXITS
 |
                MSR     CPSR_c, r7
                EXIT
 ]

50
                Push    "lr"
                BL      ProcessLineStatusError710
                Pull    "lr"
                B       %BT15

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: enumerate710
;
; in:   r0 = reason code
;
; out:  r1 -> table of supported serial speeds (in 0.5 bit/sec)
;       r2 = number of entries in table
;
; Return a pointer to a table of supported serial speeds.
;

enumerate710
                ADRL    r1, BaudRates
                MOV     r2, #(EndNewRates - BaudRates) :SHR: 2
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ProcessLineStatusError710 - Generate serial error event from line status
;
; in:   r0 = line status register
;       r11 -> C710_UART
;       IRQ or SVC mode
;

ProcessLineStatusError710 Entry "r1, r2"
        TST     r0, #LS_RXFull          ; if there's a character
        LDRNEB  r2, C710_DataWord       ; then read it and pass to event

; now translate error bits

        ANDS    r1, r0, #LS_Overrun
        MOVNE   r1, #SerialError_Overrun
        TST     r0, #LS_Parity
        ORRNE   r1, r1, #SerialError_Parity
        TST     r0, #LS_Framing :OR: LS_Break   ; map framing or break errors onto framing
        ORRNE   r1, r1, #SerialError_Framing
        BL      giveerror710
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: irq710
;
; in:   r3 -> IOC
;       IRQ mode
;
; out:  -
;
; This code handles the serial interrupts from the 710 controller, this
; routine basically handles all the communication with this chip, RX and
; TX of characters.
;

irq710          Entry   "r11"

                LDR     r11, HWAddress
irq710pollloop
                LDRB    r1, C710_InterruptFlags
                AND     r1, r1, #IF_IRQBits
                TST     r1, #IF_NoInterrupt                     ; if no more interrupt causes
                BNE     irq710exit
                TEQ     r1, #IF_LineStatus
                BEQ     handle_linestatus
                TEQ     r1, #IF_RXFull
                TEQNE   r1, #IF_RXTimeout                       ; byte in RX FIFO longer than 4 character times
                BEQ     handle_rxfull
                TEQ     r1, #IF_TXEmpty
                BEQ     handle_txempty

; if none of the above, it must be...

handle_modemstatus
                LDRB    r1, C710_ModemStatus
                LDR     lr, SerialDeviceFlags
                BIC     r2, lr, #(1:SHL:SF_DCDHigh):OR:(1:SHL:SF_DSRHigh):OR:(1:SHL:SF_Ringing):OR:(1:SHL:SF_CTSHigh)

                TST     r1, #MS_CTSLow                          ; OR in state of CTS
                ORREQ   r2, r2, #1:SHL:SF_CTSHigh

                TST     r1, #MS_DSRLow                          ; OR in state of DSR
                ORREQ   r2, r2, #1:SHL:SF_DSRHigh

                TST     r1, #MS_RIHigh                          ; OR in state of RI
                ORRNE   r2, r2, #1:SHL:SF_Ringing

                TST     r1, #MS_DCDLow
                ORREQ   r2, r2, #1:SHL:SF_DCDHigh

                STR     r2, SerialDeviceFlags

; if DCD just went high and we're not ignoring it, then generate a serial error event

                TST     r2, #1:SHL:SF_DCDHigh                   ; if DCD not high now
                BEQ     DCDOK                                   ; then skip
                TST     lr, #1:SHL:SF_DCDHigh                   ; else if DCD was high already
                TSTEQ   lr, #1:SHL:SF_DCDIgnore                 ; or we're ignoring DCD
                BNE     DCDOK                                   ; then skip

                MOV     r1, #0                                  ; indicate none of PE,OV or FE
                BL      giveerror710
DCDOK

; now update TXI etc since CTS or DSR may have gone low

                BL      UpdateDTRRTSTXI710
                B       irq710pollloop                          ; go back to test other interrupts

; handle line status interrupt

handle_linestatus
                LDRB    r0, C710_LineStatus
                BL      ProcessLineStatusError710
                B       irq710pollloop                          ; go back to test other interrupts

; handle receive interrupt (even in FIFO mode we must go round poll loop for each char in case of errors)

handle_rxfull
                LDRB    r2, C710_DataWord                       ; get byte received
                LDR     r0, SerialDeviceFlags
                TST     r0, #1:SHL:SF_DCDIgnore                 ; if not ignoring DCD
                ORREQ   lr, r0, #1:SHL:SF_DCDHigh               ;     and DCD is high then
                TEQEQ   lr, r0
                BEQ     %FT20                                   ;   deal with error

                TST     r0, #1:SHL:SF_XONXOFFOn                 ; if not doing xon/xoff
                BEQ     %FT10                                   ; then skip

                TEQ     r2, #XOFFChar                           ; if it's the XOFF character
                ORREQ   r0, r0, #(1:SHL:SF_HeXOFFedMe)          ; then set bit
                STREQ   r0, SerialDeviceFlags
                BEQ     irq710pollloop                          ; and go back

                TEQ     r2, #XONChar                            ; if it's the XON character then
                BEQ     %FT30                                   ;   deal with it
10
                TST     r0, #(1:SHL:SF_RXIgnore)                ; is input supressed currently?
                BNE     irq710pollloop                          ; if so, then throw character away

                LDR     r1, InputBufferHandle                   ; get buffer handle to insert into
                CMP     r1, #-1                                 ; if there is a buffer (handle <> -1)
                BEQ     irq710pollloop

                WritePSRc SVC_mode + I_bit,r0                   ; switch to SVC mode so we can save lr_svc
                MOV     r0, #OsByte_InsertBufferCharWithEsc     ; then insert character, checking for Escape if appropriate
                Push    "lr"
                SWI     XOS_Byte                                ; NB this may cause thresholdhalt710 to be called
                Pull    "lr"
                WritePSRc IRQ_mode + I_bit,r0                   ; switch back
                B       irq710pollloop

20
                MOV     r1, #0                                  ; indicate no other errors besides DCD
                BL      giveerror710
                B       irq710pollloop

30
                BIC     r0, r0, #(1:SHL:SF_HeXOFFedMe)          ; got XON so clear bit
                STR     r0, SerialDeviceFlags

                LDRB    lr, C710_InterruptEnable
 [ Fix710TXEnable
                BIC     lr, lr, #IE_Transmit
                STRB    lr, C710_InterruptEnable
 ]
                ORR     lr, lr, #IE_Transmit                    ; and enable transmit IRQ
                STRB    lr, C710_InterruptEnable
                B       irq710pollloop

; handle transmit interrupt (in FIFO mode we can send FIFO_Size bytes)

handle_txempty
 [ NewTXStrategy
                LDR     r3, SerialDeviceFlags
                TST     r3, #1:SHL:SF_UseFIFOs                  ; if FIFOs are disabled then
                MOVEQ   r0, #0                                  ;   can only send one byte
                MOVNE   r0, #1                                  ; else assume sending 2 with FIFO enabled (would be 1 but 665 screws up timing)
                TSTNE   r3, #1:SHL:SF_FillTXFIFO                ; if we want to fill whole FIFO then
                MOVNE   r0, #FIFO_Size-1                        ;   FIFO_Size-1 bytes left to send
 |
                LDR     r3, SerialDeviceFlags
                TST     r3, #1:SHL:SF_FIFOsEnabled              ; if FIFOs are enabled then
                MOVNE   r0, #FIFO_Size-1                        ;   we have a further FIFO_Size-1 bytes to send
                                                                ;   but at a lower priority than all interrupts
                MOVEQ   r0, #0                                  ; else no further bytes to send
 ]
                STRB    r0, SerialTxByteCount
                BL      irq710txbyte                            ; send one byte now in response to interrupt
                B       irq710pollloop

irq710txbyte
; in:   r3=SerialDeviceFlags
                TST     r3, #1:SHL:SF_StoppingBreak             ; if trying to stop break then
                BNE     %FT80                                   ;   go disable TXI

                TST     r3, #1:SHL:SF_BreakOn                   ; if sending break then
                BNE     %FT60                                   ;   go do it

                MOV     r0, r3                                  ; don't corrupt r3
                TST     r0, #1:SHL:SF_CTSIgnore                 ; if ignoring CTS
                BICNE   r0, r0, #1:SHL:SF_CTSHigh               ;   then pretend its low
                TST     r0, #1:SHL:SF_DSRIgnore                 ; if ignoring DSR
                BICNE   r0, r0, #1:SHL:SF_DSRHigh               ;   then pretend its low
                TST     r0, #(1:SHL:SF_CTSHigh):OR:(1:SHL:SF_DSRHigh) ; if CTS or DSR high and not ignored,
                BNE     %FT80                                         ;   then just disable TXI

                LDRB    r2, SerialXONXOFFChar                   ; if we have to send an XON or an XOFF
                TEQ     r2, #0
                MOVNE   r1, #0
                STRNEB  r1, SerialXONXOFFChar                   ; then zero the byte to send
                BNE     %FT50                                   ; and go send the byte

                TST     r3, #(1:SHL:SF_HeXOFFedMe)              ; if we are XOFFed
                TSTEQ   r3, #(1:SHL:SF_TXDormant)               ; or no chars to send
                BNE     %FT80                                   ; then disable TXI
40
                LDR     r1, OutputBufferHandle
                CMP     r1, #-1                                 ; if no output buffer then
                BEQ     %FT70                                   ;   sleep and disable TXI

                WritePSRc SVC_mode + I_bit, r0                  ; go into SVC mode no IRQs for SWI
                NOP
                Push    "r9,lr"                                 ; save SVC_lr
                MOV     r9, #REMV
                CLRV
                SWI     XOS_CallAVector                         ; C=0 => r2=char, C=1 => buffer empty
                Pull    "r9,lr"                                 ; restore SVC_lr
            [ No32bitCode
                MOV     r0, #SVC_mode :EOR: IRQ_mode
                TEQP    r0, pc                                  ; go back to IRQ mode, preserving C (IRQ_lr unchanged)
            |
                MRS     r0, CPSR
                EOR     r0, r0, #SVC_mode :EOR: IRQ_mode
                MSR     CPSR_c, r0                              ; go back to IRQ mode, preserving C (IRQ_lr unchanged)
            ]
                BCS     %FT70                                   ; if buffer empty then sleep and disable TXI

                TST     r3, #1:SHL:SF_XONXOFFOn                 ; if not using XON/XOFF then
                BEQ     %FT50                                   ;   send the byte

                TEQ     r2, #XOFFChar                           ; else if XOFF char
                ORREQ   r3, r3, #1:SHL:SF_UserXOFFedHim         ;   then set user bit
                TEQ     r2, #XONChar                            ; else if XON char
                BICEQ   r3, r3, #1:SHL:SF_UserXOFFedHim         ;   then clear user bit
                STR     r3, SerialDeviceFlags                   ;   and store modified serial device flags
                BNE     %FT50                                   ;   and skip if not an XON character.....

                TST     r3, #1:SHL:SF_IXOFFedHim                ; if we're trying to XOFF him
                BNE     %BT40                                   ; then don't send XON, go and look for another byte
50
                STRB    r2, C710_DataWord                       ; send the byte
                MOV     pc, lr

60
                LDRB    r1, C710_FormatWord                     ; send break
                ORR     r1, r1, #FW_BreakEnable
                STRB    r1, C710_FormatWord
                MOV     r2, #0
                B       %BT50

70
                ORR     r3, r3, #1:SHL:SF_TXDormant             ; go to sleep
                STR     r3, SerialDeviceFlags
80
                LDRB    r1, C710_InterruptEnable                ; disable Tx interrupt and exit
                BIC     r1, r1, #IE_Transmit
                STRB    r1, C710_InterruptEnable

                MOV     r1, #0                                  ; don't send any more bytes
                STRB    r1, SerialTxByteCount

                MOV     pc, lr

; no more interrupt causes at present so see if we have any more bytes to stuff in the FIFO (if there is one)
; this is done here so that filling any FIFO takes a lower priority than servicing other interrupts

irq710exit
                LDRB    r1, SerialTxByteCount
                SUBS    r1, r1, #1
                EXIT    CC                                      ; exit when no more bytes to be sent
                STRB    r1, SerialTxByteCount                   ; otherwise, update count
                LDR     r3, SerialDeviceFlags                   ; and send another byte
                BL      irq710txbyte
                B       irq710pollloop                          ; then check for more interrupts

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Wake up the serial device driver for transmitting, because there are some more chars in TX buffer
;
; in:   SVC mode
;
; out:  -
;

wakeupTX710     EntryS  "r1, r11"
                LDR     r11, HWAddress
                WritePSRc SVC_mode + I_bit, lr          ; disable IRQs
                LDR     r2, SerialDeviceFlags
                BIC     r2, r2, #1:SHL:SF_TXDormant     ; indicate TX buffer no longer dormant
                STR     r2, SerialDeviceFlags
                BL      UpdateDTRRTSTXI710              ; enable TXI if appropriate
                EXITS   ,cf                             ; exit with r0 preserved => become active

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       thresholdhalt710 - Called when number of spaces in receive buffer has gone below threshold
;
; in:   r0 = reason code
;       r2 = internal handle
;       SVC mode
;

thresholdhalt710 EntryS  "r2,r11"
                LDR     lr, InputHandle                 ; only interested on input stream
                TEQ     lr, r2
                EXIT    NE

;               Palette &0000000F, r2, r11

                LDR     r11, HWAddress
                WritePSRc SVC_mode + I_bit, lr          ; disable IRQs
                LDR     r2, SerialDeviceFlags
                ORR     r2, r2, #1:SHL:SF_Thresholded

                TST     r2, #1:SHL:SF_XONXOFFOn         ; if doing XON/XOFF
                ORRNE   r2, r2, #1:SHL:SF_IXOFFedHim    ; then indicate we're XOFFing him
                STR     r2, SerialDeviceFlags

                MOVNE   lr, #XOFFChar
                STRNEB  lr, SerialXONXOFFChar           ; try to send an XOFF

                BL      UpdateDTRRTSTXI710              ; update RTS, TXI

;               Palette &00000008, r2, r11

                EXITS   ,cf

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       thresholdresume710 - Called when number of spaces in receive buffer goes back above threshold
;
; in:   r0 = reason code
;       r2 = internal handle

thresholdresume710 EntryS "r2, r11"
                LDR     lr, InputHandle
                TEQ     lr, r2
                EXIT    NE

;               Palette &400000F0, r2, r11

                LDR     r11, HWAddress
                WritePSRc SVC_mode + I_bit, lr          ; disable IRQs
                LDR     r2, SerialDeviceFlags
                BIC     r2, r2, #1:SHL:SF_Thresholded

                TST     r2, #1:SHL:SF_XONXOFFOn
                BICNE   r2, r2, #1:SHL:SF_IXOFFedHim    ; clear my XOFF bit
                STR     r2, SerialDeviceFlags
                BEQ     %FT10

                TST     r2, #1:SHL:SF_UserXOFFedHim     ; if user not XOFFing him
                MOVEQ   lr, #XONChar                    ; then send an XON
                STREQB  lr, SerialXONXOFFChar
10
                BL      UpdateDTRRTSTXI710              ; update RTS and TXI

;               Palette &40000080, r2, r11

                EXITS   ,cf

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This code generates an event about a serial error ie framing error, overrun, parity error or DCD high
;
; in:   r1 = PE, OV and FE bits where you want them
;       r2 = character if there was one (pretty useless since you don't know if there was!)
; out:  must preserve flags
;

giveerror710    EntryS  "r0-r3"
                LDR     lr, SerialDeviceFlags
                TST     lr, #1:SHL:SF_DCDHigh
                ORRNE   r1, r1, #SerialError_DCD
                TST     lr, #1:SHL:SF_DSRHigh
                ORRNE   r1, r1, #SerialError_DSR

                SETPSR  SVC_mode, lr,, r3                               ; switch into SVC mode
                NOP

                Push    "lr"
                MOV     r0, #Event_RS423Error
                SWI     XOS_GenerateEvent                               ; and then generate event
                Pull    "lr"                                            ; preserve SVC LR

                RestPSR r3                                              ; restore original mode
                NOP

                EXITS   ,cf

 [ KickSerialTX

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SetTXKick - set up a call every to kick serial TX every 0.5s
;
; out:  all registers and flags preserved
;
; This works round a problem with the SMC665 and C&T710 where TX irqs can stop
; dead for no apparent reason. The call every 0.5s toggles the TX enable bit if
; set so that TX irqs are kept going. The call back is harmless in normal
; operation.
;

SetTXKick
                Entry   "r0-r2"
                MOV     r0, #49                                         ; 50cs - 1
                ADR     r1, KickTX
                LDR     r2, HWAddress
                SWI     XOS_CallEvery
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RemoveTXKick
;
; out:  all registers and flags preserved
;
; Remove the call every set up above.
;

RemoveTXKick
                Entry   "r0,r1"
                ADR     r0, KickTX
                LDR     r1, HWAddress
                SWI     XOS_RemoveTickerEvent
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; KickTX
;
; Called every 0.5s when serial output is open. Toggles TX interrupt enable bit
; if TX irqs are enabled. This fixes problem with TX irqs stopping for no
; apparent reason on SMC665 and C&T710.
;

KickTX
                Entry   "r0"
                LDRB    r0, [r12, #:INDEX:C710_InterruptEnable]
                TST     r0, #IE_Transmit
                BICNE   lr, r0, #IE_Transmit
                STRNEB  lr, [r12, #:INDEX:C710_InterruptEnable]
                STRNEB  r0, [r12, #:INDEX:C710_InterruptEnable]
                EXIT

 ]

                END

