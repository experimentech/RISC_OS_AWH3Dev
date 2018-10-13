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
; > Serial6551

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: SerialACIA
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
; relevant parameters.  This is mainly to save lots of fafing around in
; the support module and moving registers about.
;

SerialACIA      ROUT

                Debug   interface, "serialACIA, reason =", r0

                TST     r0, #DeviceCall_ExternalBase
                BNE     %20                             ; is it a call from the support module?

                Debug   interface, "is an internal call from DeviceFS", r0

                CMP     r0, #(%20-%00)/4
                ADDCC   pc, pc, r0, LSL #2              ; despatch as required
                MOV     pc, lr
00
                B       openACIA                        ; initialise
                B       closeACIA                       ; finalise
                B       wakeupACIA                      ; wake up for TX
                MOV     pc, lr                          ; wake up for RX
                MOV     pc, lr                          ; sleep rx
                MOV     pc, lr                          ; enum dir
                B       CreateForTX                     ; create buffer for TX
                B       CreateForRX                     ; create buffer for RX
                B       thresholdhaltACIA
                B       thresholdresumeACIA
                MOV     pc, lr                          ; eod
                B       newstreamACIA
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
                B       resetACIA
                B       removeACIA
                B       setbaudACIA
                B       changeACIAflags
                B       changeACIAformat
                B       startbreakACIA
                B       endbreakACIA
                B       SetExtent                       ; common
                B       getchar                         ; common
                B       putchar                         ; common
                B       enumerateACIA
                B       GetDeviceName                   ; common
40
                STMIA   r11, {r1-r7}
                Pull    "r11, pc"                       ; and balance the stack

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: openACIA
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

openACIA        ROUT

                Debug   open, "Open handle", r2

                TST     r3, #2_1                        ; is it a RX or TX stream?
                STREQ   r2, InputHandle
                STRNE   r2, OutputHandle

                MOV     pc, lr                          ; store handles and then return


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: closeACIA
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

closeACIA       EntryS  "r0-r2"

                Debug   close, "Close handle", r2

                MOV     lr, #-1
                MOV     r1, #0

                LDR     r0, InputHandle
                TEQ     r0, r2                          ; Input stream being closed?
                TEQNE   r2, #0                          ; Or all streams?
                STREQ   lr, InputBufferHandle           ; Yes, invalidate input buffer handle
                STREQ   r1, InputHandle                 ;  and input handle

                LDR     r0, OutputHandle
                TEQ     r0, r2                          ; Output stream being closed?
                TEQNE   r2, #0                          ; Or all streams?
                STREQ   lr, OutputBufferHandle          ; Yes, invalidate output buffer handle
                STREQ   r1, OutputHandle                ;  and output handle

                MOV     r1, #0                          ; EOR mask (disable RX)
                MOV     r2, #-1                         ; AND mask (preserve other bits)
                BL      changeACIAflags                 ; Update h/w state (disable Rx)

                EXITS



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: newstreamACIA
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

newstreamACIA   EntryS  "r0-r2"

                Debug   open, "New stream on", r2
                Debug   open, "Buffer handle:", r3

                LDR     r0, InputHandle                 ; is it the input stream?
                TEQ     r0, r2
                STREQ   r3, InputBufferHandle           ; if so, then save input buffer handle
                STRNE   r3, OutputBufferHandle

                MOV     r1, #0                          ; EOR mask
                MOV     r2, #-1                         ; AND mask (preserve other bits)
                BL      changeACIAflags                 ; Update ACIA (i.e. enable Rx)

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; resetACIA
;
; in:   r0  = reason code.
;       SVC mode
;
; out:  -
;
; This is called by serialspt when the module is installed or on a soft reset.
; The routine configures the hardware and claims any vectors that are required.
; This call !MUST! be followed by a call to first setbaudACIA followed by
; changeACIAformat to configure a legitimate operational mode.
;

resetACIA       EntryS  "r0-r3, r10-r11"

                Debug   acia,"resetACIA"

                LDR     r0, SerialDeviceFlags
                ORR     r0, r0, #(1:SHL:SF_TXDormant)   ; Tx disabled
                STR     r0, SerialDeviceFlags

; Claim IRQ vector

                LDR     r3, Flags
                TST     r3, #f_SerialIRQ                ; IRQ handler already installed?
                BNE     %10                             ; Yes then jump

                MOV     r0, #Serial_DevNo
                ADDR    r1, irqACIA                     ; r1 -> code for handling serial device
                MOV     r2, wp                          ; r2 -> workspace for device IRQ
                SWI     XOS_ClaimDeviceVector
                STRVS   r0, [sp]
                PullEnv VS
                DoError VS                              ; return error (r0 -> block)

                ORR     r3, r3, #f_SerialIRQ
                STR     r3, Flags                       ; mark as owning the IRQ vectors

; Setup ACIA hardware

10              LDR     r11, =ACIA                      ; r11 -> ACIA
                LDR     r10, =IOC                       ; r10 -> IOC

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then set it (and R14 = I_bit)

                MOV     r1, #DIVRESET6850
                STRB    r1, ACIAReset                   ; Soft reset the ACIA

                MOV     r0, #OsByte_RW_SerialControl
                MOV     r2, #0
                SWI     XOS_Byte                        ; write new 6850 control soft copy!

; Update SerialDeviceFlags

                LDR     r0, SerialDeviceFlags
                LDRB    lr, ACIAStatus
                AND     lr, lr, #(ACIADSR :OR: ACIADCD)
                ORR     r0, r0, lr, LSL #DCDDSRShift    ; Setup DCD/DSR bits
                STR     r0, SerialDeviceFlags           ; Update Serial flags

                LDRB    r0, ACIACommand
                ORR     r0, r0, #ACIARIRD               ; DTR negated, RTS negated, Tx disabled, no Rx Irq
                STRB    r0, ACIACommand

                LDRB    r0, [r10, #IOCIRQMSKB]
                ORR     r0, r0, #serial_bit
                STRB    r0, [r10, #IOCIRQMSKB]          ; enable IOC IRQs from ACIA

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: removeACIA
;
; in:   SVC mode
;
; out:  -
;
; This code is called when the device should detach itself from the various
; vectors that mean that it has a grasp on IRQ chains.
;

removeACIA      EntryS  "r0-r3,r11"

                Debug   final, "Remove acia"

                LDR     r3, Flags
                TST     r3, #f_SerialIRQ                ; Hooked onto device vector?
                EXITS   EQ                              ; No then exit

; Disable IOC serial interrupts

                LDR     r11, =IOC
                PHPSEI                                  ; Disable IRQ's
                LDRB    r0, [r11, #IOCIRQMSKB]
                BIC     r0, r0, #serial_bit
                STRB    r0, [r11, #IOCIRQMSKB]          ; Disable IOC IRQs from ACIA
                PLP                                     ; Restore IRQ's

                LDR     r11, =ACIA                      ; r11 -> ACIA
                MOV     r1, #DIVRESET6850
                STRB    r1, ACIAReset                   ; Soft reset the ACIA

                MOV     r0, #OsByte_RW_SerialControl
                MOV     r2, #0
                SWI     XOS_Byte                        ; write new 6850 control soft copy!

                LDRB    r0, ACIACommand
                ORR     r0, r0, #ACIARIRD               ; DTR negated, RTS negated, Tx disabled, no Rx Irq
                STRB    r0, ACIACommand

                MOV     r0, #Serial_DevNo
                ADDR    r1, irqACIA                     ; r1 -> code for handling serial device
                MOV     r2, wp                          ; r2 -> workspace for device IRQ
                SWI     XOS_ReleaseDeviceVector
                STRVS   r0, [sp]
                PullEnv VS
                DoError VS                              ; return error (r0 -> block)

                BIC     r3, r3, #f_SerialIRQ
                STR     r3, Flags                       ; mark as not owning the IRQ vectors
                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: setbaudACIA
;
; in:   r0  = reason code
;       r1  = RX baud rate / -1 to read
;       r2  = TX baud rate / -1 to read
;       SVC mode
;
; out:  r1  = new Rx value
;       r2  = new Tx value
;       r3  = old RX value
;       r4  = old TX value
;
; This call allows the caller to modify the RX/TX baud rates being used by
; the serial hardware.
;

setbaudACIA     EntryS  "r0, r11"

                Debug   baudACIA, "New ACIA RxBaud",r1
                Debug   baudACIA, "New ACIA TxBaud",r2

                LDRB    r3, SerialRXBaud                ; get previous values (for return)
                LDRB    r4, SerialTXBaud

                CMP     r1, #-1                         ; if reading RX
                MOVEQ   r1, r3                          ; then use old value
                CMP     r1, #0                          ; if setting to zero
                MOVEQ   r1, #7                          ; then use 7 (9600)

                CMP     r2, #-1                         ; if reading TX
                MOVEQ   r2, r4                          ; then use old value
                CMP     r2, #0                          ; if setting to zero
                MOVEQ   r2, #7                          ; then use 7 (9600)

                TEQ     r1, r3                          ; Any change to Rx baud
                TEQEQ   r2, r4                          ; Or Tx baud?
                EXITS   EQ                              ; No, so return

; Check baud rates valid for old hardware

                CMP     r1, #serialbaud_OldMAX          ; is new RX valid?
                CMPCC   r2, #serialbaud_OldMAX          ; yes, is new TX valid?
                PullEnv CS
                ADRCSL   r0, ErrorBlock_Serial_BadBaud
                DoError CS                              ; return error

; Save new rates

                STRB    r1, SerialRXBaud                ; store new RX/TX baud rates
                STRB    r2, SerialTXBaud

                ADR     r0, mapoldnew
                LDRB    r1, [r0, r1]
                LDRB    r2, [r0, r2]                    ; translate to internal handles

; Setup ACIA Tx baud rate

                PHPSEI                                  ; Disable IRQ's

                ADR     r0, TXBaudTable
                TEQ     r1, r2                          ; Set EQ if Tx baud = Rx baud
                LDRB    r2, [r0, r2]                    ; r2  = internal UART value (TX)

                LDR     r11, =ACIA                      ; r11 -> ACIA
                LDRB    r0, ACIAControl                 ; replace old baud bits with new
                AND     r0, r0, #(ACIASBN :OR: ACIAWL1 :OR: ACIAWL0)
                ORR     r0, r0, r2                      ; external RX clock by default
                ORREQ   r0, r0, #&10                    ; if RX=TX then use internal RX clock
                STRB    r0, ACIAControl

                PLP                                     ; Restore IRQ's

                Debug   baudACIA, "ACIAcontrol",r0

                BEQ     %10                             ; And skip IOC programming

; Setup IOC timer 2 for Rx baud rate

                ADR     r0, RXBaudTable
                LDR     r1, [r0, r1, LSL #2]            ; r1  = timer value (RX)

                Debug   baudACIA, "IOCT2",r1

                LDR     r0, =IOC                        ; r0 -> IOC
                STRB    r1, [r0, #Timer2LL]
                MOV     r1, r1, LSR #8
                STRB    r1, [r0, #Timer2LH]             ; program new value for Timer2
                STRB    r1, [r0, #Timer2GO]             ; and then restart the timer
10
                LDRB    r1, SerialRXBaud                ; Return new RX/TX baud rates
                LDRB    r2, SerialTXBaud

                Debug   acia, "R1 out", r1
                Debug   acia, "R2 out", r2
                Debug   acia, "R3 out", r3
                Debug   acia, "R4 out", r4

                EXITS

; tables used when programming the baud counters/ timers.

mapoldnew       = 4, 7, 3, 5, 1, 6, 2, 4, 0, 11, 13, 9, 14, 10, 12, 8, 15
                ALIGN

TXBaudTable     = Baud19200, Baud1200, Baud4800, Baud150, Baud9600, Baud300, Baud2400, Baud75
                = Baud7200, Baud135, Baud1800, Baud50, Baud3600, Baud110, Baud600, BaudUndef
                ALIGN

RXBaudTable     & 2, 51, 12, 416, 6, 207, 25, 832, 8, 463, 34, 1249, 16, 568, 103, 0
                ALIGN



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: changeACIAflags
;
; in:   r0  = reason code
;       r1  = EOR mask
;       r2  = AND mask
;       SVC mode
;
; out:  r1  = OLD flags
;       r2  = NEW flags
;
; This code will modify the flags within the ACIA, it is also used
; to return the state in the top 16 bits.  When called the routine will
; attempt to reprogram the values as required
;
; This call is used to read/write the serial status.
;
;       bit     rw / ro         value   meaning
;
;       0       r/w             0       No software control. Use RTS
;                                        handshaking if bit 5 clear.
;
;                               1       Use XON/XOFF protocol. Bit 5 ignored.
;
;       1       r/w             0       Use ~DCD bit.  If ~DCD bit in the status
;                                       register goes high, then cause a serial
;                                       event.  Also, if a character is received
;                                       when ~DCD is high then cause a serial
;                                       event, and do not enter the character
;                                       into the buffer.
;
;                               1       Ignore the ~DCD bit.  Note that some
;                                       serial chips (Rockwell, GTE and CMD) have reception
;                                       and transmission problems if this bit is high.
;
;       2       r/w             0       Use the ~DSR bit.  If the ~DSR bit in the
;                                       status register is high, then do not transmit
;                                       characters.
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
;       7       r/w             0       RTS controlled by handshaking system
;                                         (low if no RTS handshaking)
;                               1       RTS high.
;                                         Users should only modify this bit if RTS
;                                         handshaking is NOT in use.
;
;       10..15  ro              0       Reserved for future expansion.
;
;       16      ro              0       XOFF not received
;                               1       XOFF has been received.
;                                         Transmission is stopped by this occurence.
;
;       17      ro              0       The other end is intended to be in XON state.
;                               1       The other state is intended to be in XOFF state.
;                                       When this bit is set, then it means that an
;                                       XOFF has been sent and it will be cleared
;                                       when an XON is sent by the buffering software.
;                                       Note that the fact that this bit is set does
;                                       not imply that the other end has received
;                                       an XOFF yet.
;
;       18      ro              0       The ~DCD bit is low, ie. carrier present.
;                               1       The ~DCD bit is high, ie. no carrier.
;                                       This bit is stored in the variable and updated
;                                       on modem status interrupts
;
;       19      ro              0       The ~DSR bit is low, ie. 'ready' state.
;                               1       The ~DSR bit is high, ie. 'not-ready' state.
;                                       This bit is stored in the variable and updated
;                                       on modem status interrupts
;
;       20      ro              0       The ring indicator bit is low.
;                               1       The ring indicator bit is high.
;                                       This bit is not stored in the variable but is
;                                       read directly from the hardware.
;
;       21      ro              0       CTS low -> clear to send
;                               1       CTS high -> not clear to send
;                                       This bit is stored in the variable and updated
;                                       on modem status interrupts.
;
;       22      ro              0       User has not manually sent an XOFF
;                               1       User has manually sent an XOFF
;
;       23      ro              0       Space in receive buffer above threshold
;                               1       Space in receive buffer below threshold
;
;       24..28  ro              0       Reserved for future expansion.
;
;       29      ro              0       We have normal characters to transmit
;                               1       No normal characters to transmit
;                                        (excluding breaks, XON/XOFFs)
;
;       30      ro              0       Not sending a break signal
;                               1       Currently sending a break signal
;
;       31      ro              0       Not trying to stop a break
;                               1       Trying to stop sending a break
;

changeACIAflags EntryS  "r9-r11"

                LDR     r10, = :NOT:(SF_ModifyBits :OR: (1:SHL:SF_CTSIgnore)) ; get bits that can't be modified
                BIC     r1, r1, r10                     ; EOR mask must have these clear
                ORR     r2, r2, r10                     ; AND mask must have them set

; Disable interrupts while SerialDeviceFlags and 6551 h/w state updated

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then set it

                LDR     r10, SerialDeviceFlags

; Update RI bit in flags

                LDR     lr, =IOC                        ; point at IOC
                LDRB    lr, [lr, #IOCIRQSTAA]
                TST     lr, #ring_bit                   ; read ring indicator
                BICEQ   r10, r10, #1:SHL:SF_Ringing
                ORRNE   r10, r10, #1:SHL:SF_Ringing     ; and reflect in flags word

; Manipulate flags according to r1/r2

                AND     r9, r10, r2
                EOR     r2, r9, r1                      ; Get new flags state
                MOV     r1, r10                         ; Return old flags

                EOR     r10, r2, r1                     ; Get changed bits
                TST     r10, #1:SHL:SF_XONXOFFOn        ; check for changed XON/XOFF
                BICNE   r2, r2, #(1:SHL:SF_HeXOFFedMe):OR:(1:SHL:SF_IXOFFedHim):OR:(1:SHL:SF_UserXOFFedHim)

                Debug   flagsACIA, "changeACIAflags from",r1

                STR     r2, SerialDeviceFlags           ; store new serial device flags


; Update 6551 h/w

                LDR     r11, =ACIA
                BL      UpdateDTR_RTS_TXIACIA           ; Update DTR, RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       UpdateDTR_RTS_TXIACIA
;
; Update DTR, RTS and TXI from SerialDeviceFlags and other state
;
; in:   r11 -> 6551 ACIA
;       Works in IRQ or SVC mode
;       ACIA IRQs disabled
;
; out:  All preserved
;

UpdateDTR_RTS_TXIACIA   EntryS  "r0,r2"
                LDR     r2, SerialDeviceFlags           ; Get new flags

                Debug   flagsACIA, "UpdateACIA flags:",r2

; Update DTR state

                LDRB    r0, ACIACommand                 ; Read DTR bit
                TST     r2, #1:SHL:SF_DTROff            ; Negate DTR?
                BICNE   r0, r0, #ACIADTR                ; Yes then clear DTR bit
                ORREQ   r0, r0, #ACIADTR                ; Else set it

; Form RTS state

                BIC     r0, r0, #RonTena:OR:RonTdis
                ORR     r0, r0, #RonTena                ; RTS asserted (lo), Tx enabled

                TST     r2, #(1:SHL:SF_TXDormant)       ; Tx dormant?
                BEQ     %FT05                           ; No then jump

                LDR     lr, OutputBufferHandle
                CMP     lr, #-1                         ; Output buffer unassigned?
                LDREQ   lr, InputBufferHandle
                CMPEQ   lr, #-1                         ; And Input buffer unassigned?
                BICEQ   r0, r0, #ACIADTR                ; Yes then clear DTR bit
                BEQ     %FT10                           ; And jump, disable RTS

05              TST     r2, #1:SHL:SF_UserRTSHigh       ; user forcing RTS?
                BNE     %FT10                           ; Yes, then jump - force hi

                TST     r2, #(1:SHL:SF_XONXOFFOn):OR:(1:SHL:SF_NoRTSHandshake) ; Using XON/XOFF or no RTS?
                BNE     %FT20                           ; Yes then jump - RTS asserted

                TST     r2, #1:SHL:SF_Thresholded       ; Space in RX buffer?
                BEQ     %FT20                           ; Yes then jump - RTS asserted

; Negate RTS

10              BIC     r0, r0, #RonTena:OR:RonTdis     ; Negate ~RTS (drive hi)

                Debug   flagsACIA, "RTS disabled"

; Check if sending break

20              TSTS    r2, #(1:SHL:SF_BreakOn)         ; Sending break?
                ORRNE   r0, r0, #RonBreak               ; Yes then set break state (RTS lo, Tx off)
 [ debug
                BEQ     %FT00
                Debug   flagsACIA, "Sending break"
00
 ]
                BNE     %FT40                           ; And jump

; Check if Tx to be disabled

                TST     r2, #1:SHL:SF_DSRHigh           ; Is DSR asserted (lo)?
                BEQ     %FT30                           ; Yes then jump
                TST     r2, #1:SHL:SF_DSRIgnore         ; DSR is negated, ignoring DSR?
                BEQ     %FT35                           ; No then jump - disable Tx

30              LDRB    lr, SerialXONXOFFChar           ; XON or XOFF to send?
                TEQ     lr, #0
 [ debug
                BEQ     %FT00
                Debug   flagsACIA, "Enable Tx for XON/OFF"
00
 ]
                BNE     %FT40                           ; Yes then jump - Tx enabled

                TST     r2, #1:SHL:SF_HeXOFFedMe        ; if not XOFFed
 [ debug
                BEQ     %FT00
                Debug   flagsACIA, "Tx Xoffed"
00
 ]
                TSTEQ   r2, #1:SHL:SF_TXDormant         ; and chars to send
                BEQ     %FT40                           ; Yes then jump, Tx enabled

; Disable Tx

35              TSTS    r0, #RonTena                    ; RTS asserted & tx enabled?
                EORNE   r0, r0, #(RonTena:OR:RonTdis)   ; Yes then force tx disabled

                Debug   flagsACIA, "Tx disabled"

; Check if Rx enabled

40              BIC     r0, r0, #ACIARIRD               ; Assume receive Irq's enabled
                LDR     lr, InputBufferHandle
                CMP     lr, #-1                         ; Input buffer assigned?
                BNE     %FT50                           ; Yes then jump

                LDR     lr, OutputBufferHandle
                CMP     lr, #-1                         ; Output buffer unassigned?
                TSTNES  r2, #(1:SHL:SF_XONXOFFOn)       ; Or XON/XOFF not used?
 [ debug
                BNE     %FT00
                Debug   flagsACIA, "Rx disabled"
00
 ]
                ORREQ   r0, r0, #ACIARIRD               ; Yes then disable receive Irq's

; Update 6551 command register

50              LDRB    lr, ACIACommand                 ; Read command register

                Debug   flagsACIA, "New ACIACommand",r0

                TEQS    lr, r0                          ; Change in command state?
                STRNEB  r0, ACIACommand                 ; Yes then write back

                EXITS

                LTORG


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: changeACIAformat
;
; in:   r0 reason code
;       r1  = new format, -1 to read
;       SVC mode
;
; out:  r1  = old format
;
; This call modifies the command register in the 6551, it will
; setup the stop bits, word length and parity checking bits.
;
;               bits 0,1 : 0 => 8 bit word
;                          1 => 7 bit word
;                          2 => 6 bit word
;                          3 => 5 bit word
;
;                  bit 2 : 0 => 1 stop bit
;                          1 => 2 stop bits
;                       OR 1.5 stop bits if 5 bit word without parity
;                       OR 1   stop bit if 8 bit word with parity
;
;                  bit 3 : 0 => parity disabled (no parity bit)
;                          1 => parity enabled
;
;               bits 4,5 : 0 => odd parity
;                          1 => even parity
;                          2 => parity bit always 1 on TX (ignored on RX)
;                          3 => parity bit always 0 on TX (ignored on RX)
;
; bits 0...2 goto bits 5...7 of control register and bits 3..5 go to bits 5..7 of command
; register.
;

changeACIAformat EntryS "r9-r12"
                Debug   baudACIA, "ACIA format:",r1

                LDR     r11, =ACIA                      ; -> base of serial

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then set it

; Read word length

                LDRB    r10, ACIAControl                ; get control register
                MOV     r9, r10, LSR #5
                EOR     r10, r10, r9, LSL #5            ; leave baud rate bits

; Read parity

                LDRB    lr, ACIACommand
                AND     r12, lr, #(ACIAPME :OR: ACIAPMC0 :OR: ACIAPMC1)
                EOR     lr, lr, r12                     ; get command register non-format

; Writing new format?

                ORR     r9, r9, r12, LSR #5-3           ; complete old state
                CMP     r1, #-1                         ; just reading the old state?
                BEQ     %FT10                           ; Yes then jump

; Write new format

                ORR     r10, r10, r1, LSL #5            ; new control register
                STRB    r10, ACIAControl

                MOV     r10, r1, LSR #3
                ORR     lr, lr, r10, LSL #5             ; new command register
                STRB    lr, ACIACommand

10              MOV     r1, r9                          ; r1 = previous state
                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: startbreakACIA
;
; in:   r0  = reason code
;       SVC mode
;
; out:  -
;
; Start sending a break, this is used by the send a break for x centi-seconds.
;

startbreakACIA  EntryS  "r11"

                Debug   acia, "Start break"

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then disable irq's

                LDR     lr, SerialDeviceFlags
                ORR     r11, lr, #(1:SHL:SF_BreakOn)    ; Break on
                TEQS    r11, lr                         ; Any change?
                STRNE   r11, SerialDeviceFlags
                LDRNE   r11, =ACIA
                BLNE    UpdateDTR_RTS_TXIACIA           ; if so, then update DTR, RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: endbreakACIA
;
; in:   r0  = reason code
;       SVC_mode
;
; out:  -
;
; Finish the break sequence for the ACIA
;

endbreakACIA    EntryS  "r11"

                Debug   acia, "End break"

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then disable irq's

                LDR     lr, SerialDeviceFlags
                BIC     r11, lr, #(1:SHL:SF_BreakOn)    ; Stop break
                TEQS    r11, lr                         ; Any change?
                STRNE   r11, SerialDeviceFlags
                LDRNE   r11, =ACIA
                BLNE    UpdateDTR_RTS_TXIACIA           ; if so, then update DTR, RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: enumerateACIA
;
; in:   r0 = reason code
;
; out:  r1 -> table of supported serial speeds (in 0.5 bit/sec)
;       r2 = number of entries in table
;
; Return a pointer to a table of supported serial speeds.
;

enumerateACIA
                ADRL    r1, BaudRates
                MOV     r2, #(EndOldRates - BaudRates) :SHR: 2
                MOV     pc, lr


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: irqACIA
;
; in:   r3 -> IOC
;       wp -> Workspace
;       IRQ mode
;
; out:  -
;       Trashes r0, r1 and r2
;
; This code handles interrupts from the ACIA ACIA.
; Handles all the RX and TX of characters and changes in DSR & DCD
;

irqACIA         EntryS  "r11"

; Disable serial interrupts in IOC

                LDR     r11, =IOC                       ; I know r3-> IOC but I'm paranoid
                LDRB    r0, [r11, #IOCIRQMSKB]
                BIC     r0, r0, #serial_bit
                STRB    r0, [r11, #IOCIRQMSKB]          ; disable IOC IRQs from ACIA

                MOV     r11, pc                         ; Save CPU mode
 [ {TRUE}
                TEQP    pc, #SVC_mode + I_bit           ; Goto SVC mode, but don't enable IRQs

 |
                TEQP    pc, #SVC_mode                   ; Goto SVC mode, IRQ's enabled!!
 ]
                NOP
                Push    "r11,lr"                        ; Save CPU mode on SVC stack

                LDR     r11, =ACIA

; Poll ACIA for pending interrupt

PollACIAIrq     LDRB    r2, ACIAStatus                  ; clear interrupt and read status
                TST     r2, #ACIAIrq                    ; request pending?
                BEQ     irqACIAexit                     ; No then jump, exit interrupt routine

; Find source of interrupt

10              LDR     r1, SerialDeviceFlags           ; get old DCD,DSR bits
                EOR     r0, r1, r2, LSL #DCDDSRShift    ; get the difference between the two
                ANDS    r0, r0, #(1:SHL:SF_DCDHigh):OR:(1:SHL:SF_DSRHigh)
                BICNE   r2, r2, #ACIAIrq                ; Irq source found
                BLNE    ModemStatusACIA                 ; Process modem status if changed

                TSTS    r2, #ACIARDRF                   ; Rx full?
                BICNE   r2, r2, #ACIAIrq                ; Irq source found
                BLNE    RxFullACIA                      ; Yes then receive character

                TSTS    r2, #ACIATDRE                   ; Tx empty?
                BICNE   r2, r2, #ACIAIrq                ; Yes, Irq source found
                BLNE    TxEmptyACIA                     ; Yes then send another character

; If no other cause CTS became negated

                TST     r2, #ACIAIrq                    ; Irq claimed?
 [ debug
                BEQ     %FT00
                Debug   acia, "No CTS",r2
00
 ]
                ORRNE   r1, r1, #(1:SHL:SF_CTSHigh)     ; No then set CTS high (negated)
                STRNE   r1, SerialDeviceFlags           ; Update serial flags

                B       PollACIAIrq                     ; Check if done


; Return from interrupt

irqACIAexit     Pull    "r11, lr"
                TEQP     r11, #0                        ; Restore CPU mode, IRQ disabled
                NOP

                LDR     r11, =IOC
                LDRB    r0, [r11, #IOCIRQMSKB]
                ORR     r0, r0, #serial_bit
                STRB    r0, [r11, #IOCIRQMSKB]          ; enable IOC IRQs from ACIA

                EXITS                                   ; Return from interrupt


; Process changes in DSR/DCD.  r2= ACIAStatus, r1 = SerialDeviceFlags, r0 = changed bits

ModemStatusACIA EntryS  "r2"

                Debug   statusACIA, "Status change - oldFlags, delta",r2,r1,r0

                EOR     r1, r1, r0                      ; r1 = new flags
                STR     r1, SerialDeviceFlags           ; and store new version

                TST     r0, #(1:SHL:SF_DCDHigh)         ; DCD changed state?
 [ debug
                BEQ     %FT00
                Debug   statusACIA, "DCD changed"
00
 ]
                TSTNE   r1, #(1:SHL:SF_DCDHigh)         ; And DCD negated?
                BEQ     %FT10                           ; No then jump
                TST     r1, #(1:SHL:SF_DCDIgnore)       ; Ignoring DCD?
                MOVEQ   r2, #0                          ; No then indicate none of PE,OV or FE
                BLEQ    giveerrorACIA                   ; And generate Rx error event

10              TST     r0, #(1:SHL:SF_DSRHigh)         ; DSR changed state?
 [ debug
                BEQ     %FT00
                Debug   statusACIA, "DSR changed"
00
 ]
                BLNE    UpdateDTR_RTS_TXIACIA           ; Yes then update Tx enable state
                EXITS


; Receiver full, r2 = ACIA status

RxFullACIA      EntryS  "r2"
                LDRB    r0, ACIARxData                  ; Read the data to clear RDRF

                Debug   rxACIA, "RxData",r0

                LDR     r1, SerialDeviceFlags
                MOV     r3, #(ACIAOverRun :OR: ACIAFramingError :OR: ACIAParityError) ; Error bits
                TST     r1, #1:SHL:SF_DCDIgnore         ; Ignoring DCD?
                ORREQ   r3, r3, #ACIADCD                ; No then test DCD status as well
                ANDS    lr, r2, r3                      ; Test for Rx errors
                MOVNE   r2, lr                          ; Error bits
 [ debug
                BEQ     %FT00
                Debug   rxACIA, "Rx error",r2
00
 ]
                BLNE    giveerrorACIA                   ; Yes then generate error event
                EXITS   NE                              ; And exit

                TST     r1, #(1:SHL:SF_XONXOFFOn)       ; xon/xoff enabled?
                BEQ     %FT25                           ; No then jump

                TEQ     r0, #XOFFChar                   ; XOFF char?
                BNE     %FT20                           ; No then jump

                Debug   rxACIA, "Xoff'd"

                ORR     r1, r1, #(1:SHL:SF_HeXOFFedMe)  ; set XOFF'd bit
                STR     r1, SerialDeviceFlags           ; store back modified flags word
                BL      UpdateDTR_RTS_TXIACIA           ; update Tx enable state
                EXITS

20              TEQ     r0, #XONChar                    ; XON char?
                BNE     %FT25                           ; No then jump

                Debug   rxACIA, "Xon'd"

                TSTS    r1, #(1:SHL:SF_HeXOFFedMe)      ; Xoff'd?
                EXITS   EQ                              ; No then exit

                BIC     r1, r1, #(1:SHL:SF_HeXOFFedMe)  ; Clear Xoff'd
                STR     r1, SerialDeviceFlags           ; update flags
                BL      UpdateDTR_RTS_TXIACIA           ; enable Tx etc.
                BL      TxEmptyACIA                     ; Send char
                EXITS

; Received character is valid

25              TST     r1, #(1:SHL:SF_RXIgnore)        ; input suppressed?
 [ debug
                BEQ     %FT00
                Debug   rxACIA, "Ignoring RxD"
00
 ]
                EXITS   NE                              ; Yes then ignore character

                LDR     r1, InputBufferHandle           ; get buffer handle to insert into
                CMP     r1, #-1                         ; buffer handle valid?
 [ debug
                BNE     %FT00
                Debug   rxACIA, "No buffer for RxD"
00
 ]
                EXITS   EQ                              ; No then jump

; Insert character into buffer

                MOV     r2, r0                          ; Character received
                MOV     r0, #OsByte_InsertBufferCharWithEsc  ; then insert character, checking for Escape if appropriate
                SWI     XOS_Byte                        ; NB this may cause thresholdhaltACIA to be called
 [ debug
                BCC     %FT00
                Debug   rxACIA, "Rx buffer full"
00
 ]

; Check if sender XOFF'd

                LDR     r1, SerialDeviceFlags           ; Get flags
                TST     r1, #(1:SHL:SF_IXOFFedHim)      ; Sender Xoff'd?
                TSTNE   r1, #(1:SHL:SF_TXDormant)       ; And Tx inactive (= XOFF sent)
                EXITS   EQ                              ; No then exit

; Send another XOFF

                MOV     lr, #XOFFChar
                STRB    lr, SerialXONXOFFChar           ; request another XOFF
                BIC     r1, r1, #(1:SHL:SF_TXDormant)   ; Show Tx active
                STR     r1, SerialDeviceFlags
                BL      UpdateDTR_RTS_TXIACIA           ; Enable TXI

                EXITS


; Tx empty interrupt, r2 = ACIA status

TxEmptyACIA     EntryS  "r2"

                Debug   txACIA, "TxEmpty"

                LDR     r1, SerialDeviceFlags
                BIC     r1, r1, #(1:SHL:SF_CTSHigh)     ; CTS is asserted
                STR     r1, SerialDeviceFlags           ; Update serial flags
                TST     r1, #(1:SHL:SF_BreakOn)         ; Sending break?
 [ debug
                BEQ     %FT00
                Debug   txACIA, "Break inhibits Tx"
00
 ]
                EXITS   NE                              ; Yes then exit

                TST     r1, #(1:SHL:SF_DSRIgnore)       ; ignore DSR?
                BNE     %FT30                           ; Yes then jump
                TST     r1, #(1:SHL:SF_DSRHigh)         ; DSR high (negated)?
 [ debug
                BEQ     %FT00
                Debug   txACIA, "DSR inhibits Tx"
00
 ]
                EXITS   NE                              ; Yes then exit, can't send

30              LDRB    r2, SerialXONXOFFChar           ; is there an XON or XOFF
                TEQ     r2, #0                          ; to send (R0 =0 if not!)
                MOVNE   lr, #0                          ; if so then zero the character
                STRNEB  lr, SerialXONXOFFChar
 [ debug
                BEQ     %FT00
                Debug   txACIA, "Send XON/XOFF",r2
00
 ]
                BNE     %FT55                           ; and send this character

                TST     r1, #(1:SHL:SF_HeXOFFedMe)      ; XOFF'd?
                TSTEQ   r1, #(1:SHL:SF_TXDormant)       ; Or no chars to send?
 [ debug
                BEQ     %FT00
                Debug   acia, "Tx is XOFF'd or Dormant"
00
 ]
                EXITS   NE                              ; Yes then exit, can't send

; Get character from buffer

35              LDR     r1, OutputBufferHandle          ; get output buffer handle
                CMP     r1, #-1                         ; valid buffer?
 [ debug
                BNE     %FT00
                Debug   acia, "O/p buffer invalid"
00
 ]
                BEQ     %FT40                           ; No then jump, disable Tx

                MOV     r0, #OsByte_ExtractBufferedChar ; remove char from buffer
                SWI     XOS_Byte                        ; C=0 => r2=char, C=1 => no char
 [ debug
                BCC     %FT00
                Debug   acia, "Tx buffer empty"
00
 ]
                BCC     %FT50                           ; if char, then jump

; No more to transmit.  Set TXDormant bit, and disable TXI

40              LDR     r0, SerialDeviceFlags
                ORR     r0, r0, #1:SHL:SF_TXDormant     ; Tx dormant (nothing to send)
                STR     r0, SerialDeviceFlags
                BL      UpdateDTR_RTS_TXIACIA           ; update Tx enable state
                EXITS

; Send a character in r2

50              LDR     r1, SerialDeviceFlags
                TST     r1, #(1:SHL:SF_XONXOFFOn)       ; if xon/xoff not on
                BEQ     %FT55                           ; then skip the checking

                TEQ     r2, #XOFFChar                   ; else if XOFF char
                ORREQ   r1, r1, #(1:SHL:SF_UserXOFFedHim) ; then set user bit
                TEQ     r2 , #XONChar                   ; else if XON char
                BICEQ   r1, r1, #(1:SHL:SF_UserXOFFedHim) ; then clear the user bit
                STR     r1, SerialDeviceFlags           ; store back flags that may have been modified
                BNE     %FT55                           ; and skip if not XON char

                TST     r1, #(1:SHL:SF_IXOFFedHim)      ; trying to send XOFF?
 [ debug
                BEQ     %FT00
                Debug   acia, "Attempt to send XON while XOFF'd"
00
 ]
                BNE     %BT35                           ; Yes then jump, get another char

55              STRB    r2, ACIATxData                  ; write data

                Debug   txACIA, "Tx char",r2

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Wake up the serial device driver for transmitting, because there are
; some more chars in TX buffer
;
; in:   SVC mode
;
; out:  -
;

wakeupACIA      EntryS  "r1, r2, r11"

                Debug   acia, "WakeupACIA"

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then disable irq's

                LDR     r11, SerialDeviceFlags
                BIC     r1, r11, #(1:SHL:SF_TXDormant)  ; Tx no longer dormant
                TEQS    r11, r1                         ; Any change?
                EXITS   EQ                              ; No then exit

                STR     r1, SerialDeviceFlags
                LDR     r11, =ACIA
                BL      UpdateDTR_RTS_TXIACIA           ; Update RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; thresholdhaltACIA
;
; Called when number of spaces in the receive buffer has fallen below threshold
;
; in:   r0 = reason code
;       r2 = internal handle
;       SVC mode
;

thresholdhaltACIA EntryS "r2,r11"

                Debug   acia, "ThresholdHaltACIA"

                LDR     lr, InputHandle                 ; only interested on input stream
                TEQ     lr, r2                          ; Input stream threshold?
                EXITS   NE                              ; No then exit

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then disable irq's

                LDR     r2, SerialDeviceFlags
                ORR     r11, r2, #(1:SHL:SF_Thresholded) ; Rx buffer below threshold

                TST     r11, #(1:SHL:SF_XONXOFFOn)      ; XON/XOFF mode?
                ORRNE   r11, r11, #(1:SHL:SF_IXOFFedHim) ; Yes then request transmission of XOFF
                BICNE   r11, r11, #(1:SHL:SF_TXDormant) ; Tx is active
                MOVNE   lr, #XOFFChar
                STRNEB  lr, SerialXONXOFFChar

                TEQS    r11, r2                         ; Any change in flags?
                STRNE   r11, SerialDeviceFlags
                LDRNE   r11, =ACIA
                BLNE    UpdateDTR_RTS_TXIACIA           ; Yes, then update DTR, RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; thresholdresume710
;
; Called when number of spaces in receive buffer rises above threshold
;
; in:   r0 = reason code
;       r2 = internal handle

thresholdresumeACIA EntryS "r2, r11"

                Debug   acia, "ThresholdResumeACIA"

                LDR     lr, InputHandle                 ; only interested on input stream
                TEQ     lr, r2                          ; Input stream threshold?
                EXITS   NE                              ; No then exit

                MOV     lr, #I_bit
                TST     lr, PC                          ; is I_bit set ?
                TEQEQP  lr, PC                          ; no, then disable irq's

                LDR     r2, SerialDeviceFlags
                BIC     r11, r2, #(1:SHL:SF_Thresholded) ; Rx buffer above threshold
                TST     r11, #(1:SHL:SF_XONXOFFOn)      ; XON/XOFF mode?
                BICNE   r11, r11, #(1:SHL:SF_IXOFFedHim) ; Yes then request transmission of XON
                BEQ     %FT10                           ; Jump if not

                TST     r11, #(1:SHL:SF_UserXOFFedHim)  ; User not XOFFing him
                MOVEQ   lr, #XONChar                    ; No, then send an XON
                STREQB  lr, SerialXONXOFFChar
                BICEQ   r11, r11, #(1:SHL:SF_TXDormant) ; Tx is active

10              TEQS    r11, r2                         ; Any change in flags?
                STRNE   r11, SerialDeviceFlags
                LDRNE   r11, =ACIA
                BLNE    UpdateDTR_RTS_TXIACIA           ; Yes, then update DTR, RTS and TXI

                EXITS


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This code handles errors from the 6551.  It generates an RS423
; error event using a 6850 compatible error code.
;
; in
;   r0 = character
;   r2 = PE, OV and FE bits where you want them
;   SVC mode
;
; out -

giveerrorACIA   EntryS  "r0-r2"

                Debug   acia, "GiveErrorACIA",r2
 [ debug
                TST     r2, #ACIAFramingError
                BEQ     %FT00
                TEQ     r0, #0                          ; Framing error and 0 char?
                BNE     %FT00                           ; No then jump
                Debug   acia, "Break"
00
 ]

                MOVS    r1, r2, LSR #1                  ; bit 1 =OV, bit 0 =FE, C =PE
                MOV     r1, r1, LSL #3                  ; bit 4 =OV, bit 3 =FE
                AND     r1, r1, #2_00011000             ; remove other bits
                ORRCS   r1, r1, #2_00100000             ; bit 5 =PE, bit 4 =OV, bit 3 =FE
                AND     r2, r2, #2_01100000             ; r2, bit 6 =DSR, bit 5 =DCD
                ORR     r1, r1, r2, LSR #4              ; 0 | 0 | PE | OV | FE | DSR | DCD | 0

                MOV     r2, r0                          ; character (if recieve)
                MOV     r0, #Event_RS423Error
                SWI     XOS_GenerateEvent               ; and generate an event

                EXITS

                LTORG

                END
