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
; > SerialSpt

; **********************
; ***  Changes List  ***
; **********************
;
; 14-Mar-91 DDV 0.00 Created.
; 23-Mar-91 DDV      Added most SerialOps and OSByte interceptions.
; 23-Mar-91 DDV 0.01 Added new bits to description of SerialOp 0, for RTS, CTS + suppress.
; 25-Mar-91 DDV      OSByte interception handles the call and then passes it to kernel.
; 25-Mar-91 DDV      OSByte &F2 used to keep OS copy of SerULAreg up to date.
; 25-Mar-91 DDV      Removed my copy of 6850 control register, now read when required.
; 26-Mar-91 DDV      Added emulation of 6850 control register (via SerialOp 7)
; 27-Mar-91 DDV      Improved emulation (for speed!)
; 27-Mar-91 DDV 0.02 Moved RTS bit to correct field.
; 30-Mar-91 DDV 0.03 Changed break sending to be handled by this module, starts + ends (with counter).
; 01-Apr-91 DDV      Added new bit to serial flags.
; 01-Apr-91 DDV      Changed modify 6850 to reflect do start, end break.
; 01-Apr-91 DDV 0.04 Removed some bonus code.
; 14-Apr-91 DDV      Put hooks in for Service_SerialInstalled.
; 14-Apr-91 DDV      Now broadcasts to find the serial device driver.
; 14-Apr-91 DDV      Recoded vector claiming and releasing to only claim when vectors owned, etc...
; 14-Apr-91 DDV 0.05 Internationalised
; 15-Apr-91 DDV      Improved calling between the two devices.
; 16-Apr-91 DDV      Handling of put char, get char calls via OS_SerialOp added.
; 16-Apr-91 DDV      GetChar returns in r1 not r0 now.
; 16-Apr-91 DDV 0.06 Released as part of 2.11 build.
; 18-Apr-91 DDV 0.07 Tightened up message handling for international versions.
; 03-May-91 DDV      Fixed bug in vector claiming.
; 03-May-91 DDV 0.08 Fixed service trap not claiming vectors correctly.
; 14-May-91 DDV      Bug fix: SerialOp to set TX or RX baud now returns correct 'old' values.
; 14-May-91 DDV 0.09 Exported GetChar, PutChar to this module from the device driver.
; 31-Jul-91 TMD 0.10 Fixed bug in Service_SerialDevice (sense of claiming/releasing vectors wrong)
;                    Zero stream handles on service_reset.
;                    Only execute Service_Reset code on soft resets.
; 01-Aug-91 TMD      Fixed a few more errors.
;                    Changed to reflect new SerialFlags bits
; 02-Aug-91 TMD      Removed issuing of the serialctrl_Reset device call on 6850 reset
; 13-Aug-91 TMD 0.11 Stopped OS_Byte &9C setting UserRTSHigh bit.
; 14-Aug-91 TMD      Made SerialOps to get and put chars use device calls.
; 15-Aug-91 TMD      Initialise OS_Byte &F2 on init and service_reset.
; 22-Aug-91 TMD 0.12 Rationalised unused error messages.
; 06-Sep-91 TMD 0.15 Changed setting of OS_Byte &F2 to use the values
;                     returned from the set baud rate call, which may be different from
;                     what was requested, due to lack of split baud rates.
; 18-Nov-91 TMD 0.16 Fixed bug in OS_Byte &F2 which had RX and TX the wrong way round
; 12-Nov-93 SMC 0.18 Added OS_SerialOp 9 to enumerate serial speeds.
; 09-Dec-93 SMC 0.19 SerialControl now preserves r0 (except on error) - fixes bug in
;                       OSByte 203 handler where new threshold was being read but not set.
;

                GET     Hdr:ListOpts
                GET     Hdr:Macros
                GET     Hdr:DDVMacros
                GET     Hdr:System
                GET     Hdr:ModHand
                GET     Hdr:FSNumbers
                GET     Hdr:NewErrors
		GET	Hdr:Machine.<Machine>
                GET     Hdr:CMOS
                GET     Hdr:Symbols
                GET     Hdr:Services
                GET     Hdr:DeviceFS
                GET     Hdr:Serial
                GET     Hdr:RS423
                GET     Hdr:HostFS
                GET     Hdr:NdrDebug
                GET     Hdr:MsgTrans
                GET     Hdr:UpCall
                GET     Hdr:Proc
                GET     Hdr:SerialOp

                GBLL    debug
                GBLL    hostvdu
                GBLL    international

debug           SETL    false
hostvdu         SETL    false
international   SETL    true

modify6850      SETD    false                                   ; debugging of modify6850 command
inter           SETD    false                                   ; internationalisation
sendchar        SETD    false
getchar         SETD    false
osbyte          SETD    true

                GET     VersionASM
                GET     Macros.s
                GET     Errors.s

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Define workspace and how it's to be used
;

                        ^ 0, wp
SerialDeviceHandle      # 4                                     ; handle of serial device (=0 if none)
Flags                   # 4                                     ; bit field allocated to flags used
Vectors                 # 1                                     ; bit field describing the vectors owned
RXstreamHandle          # 1                                     ; stream handles
TXstreamHandle          # 1

                      [ international
                        AlignSpace
MessagesWorkspace       # 16                                    ; 16 byte header for message trans
                      ]

workspace               * :INDEX: @                             ; amount of workspace needed

v_ByteV                 * 2_00000001
v_UpCallV               * 2_00000010
v_SerialV               * 2_00000100
v_AllVectors            * 2_00000111

f_WeHaveMessages        * 2_00000001

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Now we have a module header used by the kernel to suppy entry points etc.
;
                AREA  |SerialDeviceSupport$$Code|, CODE, READONLY, PIC

module_header   & 0
                & init -module_header                   ; => initialisation
                & final -module_header                  ; => finalisation
                & service -module_header                ; => service handler

                & title -module_header                  ; => title string
                & help -module_header                   ; => help string
                & 0
              [ :LNOT:No32bitCode
                & 0
                & 0
                & 0
                & 0
                & 0
                & modflags -module_header
              ]

title           = "SerialDeviceSupport", 0
help            = "Serial Support",9,"$Module_HelpVersion"
              [ debug
                = " Development version"
              ]
                = 0

              [ international
                ! 0, "Internationalised version"
resource_file   = "Resources:$.Resources.Serial.Messages", 0
              ]
                ALIGN

modflags        & ModuleFlag_32bit

                MakeErrorBlock Serial_NoSerialDevice
                MakeErrorBlock Serial_UnknownSerialOp

serialfile      = "devices:$.Serial", 0
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle module startup, this involves claiming some workspace and then
; grabbing the required vectors.
;

init            Entry

                LDR     r2, [wp]
                TEQ     r2, #0                          ; warm start?
                BNE     %FT10                           ; yes, so skip workspace claim

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace                  ; r3  = amount of workspace required
                SWI     XOS_Module

                EXIT    VS                              ; return if it failed

                STR     r2, [wp]
10
                MOV     wp, r2                          ; wp -> workspace allocation

                MOV     r0, #0
                STR     r0, SerialDeviceHandle
                STR     r0, Flags
                STRB    r0, Vectors                     ; mark vectors as dirty
                STRB    r0, RXstreamHandle
                STRB    r0, TXstreamHandle              ; zero the stream handles

                BL      GetDeviceHandle                 ; attempt to locate the device

                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; We must now attempt to release the vectors that we may have claimed.
;

final           Entry

                LDR     wp, [wp]                        ; wp -> workspace

                BL      free_vectors                    ; if there is some then release the vectors

              [ international
                BL      CloseMessages                   ; attempt to close messages file
              ]

                SUBS    r0, r0, r0
                STR     r0, SerialDeviceHandle          ; reset my copy of the internal handle

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Service code handling, these are general purpose messages received by the
; outside world.
;

service         ROUT
                TEQ     r1, #Service_SerialDevice
                TEQNE   r1, #Service_Reset
                MOVNE   pc, lr

                LDR     wp, [wp]                        ; -> workspace
                TEQ     r1, #Service_Reset
                BEQ     %20

                ; It is a broadcast from the serial device.

                ; Did it originate from that device?
                TEQ     r2, #0
                MOVNE   pc, lr

                Push    "r0-r3, lr"

                STR     r0, SerialDeviceHandle

                CMP     r0, #0                          ; is it the device being installed? (V:=0 anyway)
                SETV    EQ                              ; if not, then we want to free vectors
                BLVC    get_vectors                     ; if so, then claim the vectors
                BLVS    free_vectors                    ; otherwise release (also release on error)

                Pull    "r0-r3, pc"
20

                Push    "r0-r2, lr"

                MOV     r0, #&FD                        ; read last reset type
                MOV     r1, #0
                MOV     r2, #&FF
                SWI     XOS_Byte
                TEQ     r1, #0

                Pull    "r0-r2, pc",NE                  ; if hard reset, do nothing

                MOV     r0, #0
                STR     r0, SerialDeviceHandle          ; mark as not knowing about the device
                STRB    r0, Vectors                     ; mark vectors as dirty
                STRB    r0, RXstreamHandle
                STRB    r0, TXstreamHandle              ; zero the stream handles

                BL      GetDeviceHandle                 ; and then attempt to locate the device driver

                Pull    "r0-r2, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; We must now attempt to locate the device driver, this is quite a simple
; process.  We issue the service call and wait for a reply.  When the reply
; comes back and r1 is marked as the service call has been claimed then
; we store the handle.  If not then we ignore the request, also when the
; service is marked as the device is known then we can attempt to claim the
; vectors.
;

GetDeviceHandle Entry   "r0-r3"

                MOV     r1, #Service_SerialDevice
                MOV     r2, #-1                         ; service from support module
                SWI     XOS_ServiceCall

                TEQ     r1, #Service_Serviced           ; was it claimed?
                Pull    "r0-r3, pc", NE                 ; no, so return back to the caller

                STR     r0, SerialDeviceHandle          ; stash the new improved whiter than white handle

                BL      Initialise_OSByte242            ; set up serial ula soft copy
                BL      get_vectors
                BLVS    free_vectors                    ; attempt to claim, if that fails then remove ownership

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Here we claim and release vectors, this is done via a table consisting of
; the vector bit to set and the offset to the routine and vector number.
;
; Both routines use this table to ensure that they obtian the correct values.
;

get_vectors     Entry   "r0-r5"

                MOV     r2, wp                  ; r2 -> workspace
                ADR     r3, vectors             ; r3 -> vector table
                LDRB    r4, Vectors             ; r4  = flags word

10
                LDMIA   r3!, {r0-r1, r5}
                CMP     r0, #-1                 ; end of the table?
                BEQ     %FT20

                TST     r4, r5                  ; is the vector already owned?
                BNE     %BT10

                ADD     r1, r1, r3              ; r1 -> absolute routine
                SWI     XOS_Claim
                ORRVC   r4, r4, r5
                BVC     %BT10                   ; if that worked then try next entry

20
                STRB    r4, Vectors
                STRVS   r0, [sp]                ; if error store into stack frame
                EXIT


free_vectors    Entry   "r0-r5"

                MOV     r2, wp                  ; r2 -> workspace
                ADR     r3, vectors             ; r3 -> vector table
                LDRB    r4, Vectors             ; r4  = flags word

10
                LDMIA   r3!, {r0-r1, r5-r6}
                CMP     r0, #-1                 ; end of the table?
                BEQ     %FT20

                TST     r4, r5                  ; is the vector already free?
                BEQ     %BT10

                TEQ     pc, pc
                ADD     r1, r1, r3              ; r1 -> absolute routine
                SWI     XOS_Release
                B       %BT10                   ; try all the others even if that failed

20
                SUBS    r4, r4, r4              ; pretend it all worked
                STRB    r4, Vectors
                EXIT


vectors ; define the list of vectors to be claimed within the system, terminated
        ; with a -ve entry.
        ;
                VTable  HandleOSByte, ByteV, v_ByteV
                VTable  HandleSerialOp, SerialV, v_SerialV
                VTable  HandleUpCall, UpCallV, v_UpCallV
                & -1                            ; end of table - NB must be at least another two words of the module
                                                ; after this, as the above code is not tactful

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: HandleSerialOp
;
; in:   r0  = reason code
;                       = 0, read/write serial status
;                       = 1, read/write data format
;                       = 2, send break
;                       = 3, send byte
;                       = 4, read byte
;                       = 5, read/write receive baud rates
;                       = 6, read/write transmit baud rates
;                       = 7, modify 6850 control register       (new for RISC OS 2.11)
;                       = 8, set handshake extent               (new for RISC OS 2.11)
;                       = 9, get device name
;
; out:  V clear => registers defined as for SWI.
;       V set => r0 -> error block.
;
; This call handles the entries from the SerialV, ie. calls to OS_SerialOp.
;

; In a 26-bit OS, entry flags (in both lr and psr) are indeterminate, so we can't preserve
; caller's flags anyway.
HandleSerialOp  ROUT
                Pull    "lr"

                CMP     r0, #(%10-%00)/4
                ADDCC   pc, pc, r0, LSL #2                      ; if the call is valid then issue
                B       %10
00
                B       Status
                B       DataFormat
                B       SendBreak
                B       Send
                B       Get
                B       RXBaud
                B       TXBaud
                B       Modify6850
                B       HandshakeExtent
                B       EnumerateSpeeds
                B       GetDeviceName
10
                ADDR    r0, ErrorBlock_Serial_UnknownSerialOp
                DoError                                         ; return error about naff serial op

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Status
;
; in:   r0  = 0, reason
;       r1  = XOR mask
;       r2  = AND mask
;
; out:  r1  = old value of state
;       r2  = new value of state
;
; This call is used to read/write the serial status.
;

Status          Entry   "r0"
                MOV     r0, #serialctrl_ChangeFlags
                BL      SerialControl                           ; modify the flags state
                STRVS   r0, [sp]
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: DataFormat
;
; in:   r0  = 1, reason
;       r1  = -1 to read, else set to new value
;
; out:  r1  = old value.
;
; This call is used to modify the serial data formats, the following bits
; are defined within r1.
;
;       bit     rw / ro         value   meaning
;
;       0,1     rw              0       8 bit word
;                               1       7 bit word
;                               2       6 bit word
;                               3       5 bit word
;
;       2       rw              0       1 stop bit
;                               1       2 top bits in most cases
;                                       1 stop bit if 8 bit word with parity
;                                       1.5 stop bits if 5 bit word without parity
;
;       3       rw              0       parity disabled
;                               1       parity enabled
;
;       4,5     rw              0       odd parity
;                               1       even parity
;                               2       parity always 1 on TX
;                               3       parity always 0 on TX
;
;       6..31   ro              0       always, reserved for future expansion
;

DataFormat      Entry   "r0"

                CMP     r1, #-1                                         ; are we just reading?
                BEQ     %FT10                                           ; yes, so skip the con flag modify

                Push    "r1,r2"

                AND     r1, r1, #&3F                                    ; only use bits 0..5
                ADR     lr, reverse
                LDRB    r1, [lr, r1]
                TEQ     r1, #&FF                                        ; if =&FF then don't modify
                BEQ     %FT20

                MOV     r0, #&C0
                MOV     r2, #&FF :EOR: WSB6850                          ; only modify baud rate bits
                SWI     XOS_Byte                                        ; read new copy of conflag
20
                Pull    "r1,r2"
10
                MOV     r0, #serialctrl_ChangeDataFormat
                BL      SerialControl
                STRVS   r0, [sp]

                EXIT


reverse
                = &14, &FF, &FF, &FF, &10, &FF, &FF, &FF
                = &1C, &0C, &FF, &FF, &1C, &04, &FF, &FF
                = &14, &FF, &FF, &FF, &10, &FF, &FF, &FF
                = &18, &08, &FF, &FF, &18, &00, &FF, &FF
                = &14, &FF, &FF, &FF, &10, &FF, &FF, &FF
                = &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
                = &14, &FF, &FF, &FF, &10, &FF, &FF, &FF
                = &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: SendBreak
;
; in:   r0  = reason code.
;       r1  = length of break in centi-seconds.
;
; out:  -
;
; This call sends a break for the specified length of time in centi-seconds, this
; is done by enabling IRQs and then sending a start break, waiting for the
; metrognome to reach the required value and then sending a stop break.
;
; The device can then handle things as required.
;

SendBreak       Entry   "r0-r2"

                MOV     r0, #serialctrl_StartBreak
                BL      SerialControl                           ; start the break sequence
                BVS     %FT20                                   ; return any errors generated!

                WritePSRc SVC_mode,r0,,r2                       ; enable IRQs

                SWI     XOS_ReadMonotonicTime                   ; r0 = monotonic time
                ADD     r1, r1, r0                              ; r1 = destination time
10
                SWI     XOS_ReadMonotonicTime
                CMP     r0, r1                                  ; have we reached the required time?
                BMI     %BT10                                   ; nope.  (NB: NOT BLT - these are clock numbers!)

                RestPSR r2                                      ; restore old IRQ state

                MOV     r0, #serialctrl_StopBreak
                BL      SerialControl                           ; end the break sequence
20
                EXIT    VC
                ADD     sp, sp, #4                              ; junk stacked r0
                Pull    "r1,r2, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Send
;
; in:   r0  = reason code
;       r1  = character to be sent
;
; out:  C set, character not sent.
;       C clear, character was sent.
;
; Send a character via the serial device.
;


Send            Entry   "r0"

                MOV     r0, #serialctrl_PutChar
                BL      SerialControl                           ; send character, returning if no room

 [ debug
                BCS     %FT10
                Debug   sendchar, "Send char succeeded"
                B       %FT20
10
                Debug   sendchar, "Send char failed"
20
 ]

                STRVS   r0, [sp]
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Get
;
; in:   r0  = reason code
;
; out:  C clear => r1  = character
;       C set => no character obtained
;
; This code will get a character from the device, this is done by calling
; the device driver to read a character
;

Get             Entry   "r0"

                MOV     r0, #serialctrl_GetChar
                BL      SerialControl                           ; get character, returning if none

 [ debug
                BCS     %FT10
                Debug   getchar, "Get char succeeded, char =", r1
                B       %FT20
10
                Debug   getchar, "Get char failed"
20
 ]
                STRVS   r0, [sp]
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: RXBaud
;
; in:   r0  = reason code
;       r1  = new RX baud rate / -1 to read
;
; out:  r1  = previous state
;
; This call allows you to modify the serial receive baud rate.
;

RXBaud          Entry   "r0-r4"
                MOV     r0, #serialctrl_ChangeBaud
                MOV     r2, #-1                                 ; = -1, read TX baud
                BL      SerialControl
                STRVS   r0, [sp]                                ; if we got an error then store error pointer
                EXIT    VS                                      ; and exit

; r1 = new RX rate, r2 = new TX rate, r3 = old RX rate, r4 = old TX rate

                STR     r3, [sp, #1*4]                          ; return old RX rate in r1
                BL      UpdateOSByteF2
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: TXBaud
;
; in:   r0  = reason code.
;       r1  = new TX baud rate / -1 to read
;
; out:  r1  = previous value.
;
; This call can be used to change the serial baud rate.
;

TXBaud          Entry   "r0-r4"
                MOV     r0, #serialctrl_ChangeBaud
                MOV     r2, r1                                  ; setting TX baud
                MOV     r1, #-1                                 ; not affecting RX
                BL      SerialControl
                STRVS   r0, [sp]                                ; if we got an error then store error pointer
                EXIT    VS                                      ; and exit

; r1 = new RX rate, r2 = new TX rate, r3 = old RX rate, r4 = old TX rate

                STR     r4, [sp, #1*4]                          ; return old TX rate in r1
                BL      UpdateOSByteF2
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       UpdateOSByteF2 - Update OS_Byte &F2 from given baud rates
;
; in:   r1 = RX baud rate
;       r2 = TX baud rate
;
; out:  r0-r2 corrupt
;

UpdateOSByteF2  Entry
                ADR     lr, serbaudtable

                CMP     r1, #16                 ; if RX baud < 16
                LDRCCB  r1, [lr, r1]            ; then look up in table
                MOVCS   r1, #15                 ; else use "unknown"

                CMP     r2, #16                 ; if TX baud < 16
                LDRCCB  r2, [lr, r2]            ; then look up in table
                MOVCS   r2, #15                 ; else use "unknown"

                TST     r2, #8                  ; bit 3 of TX moves to bit 7
                EORNE   r2, r2, #&88
                ORR     r1, r2, r1, LSL #3      ; and RX in bits 3..6

                MOV     r0, #&F2                ; write all of OS_Byte 242
                MOV     r2, #0
                SWI     XOS_Byte
                EXIT

serbaudtable
                =       4, 7, 3, 5, 1, 6, 2, 4, 0, 11, 13, 9, 14, 10, 12, 8
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Initialise_OSByte242 - Set up OS_Byte 242 variable from current baud rates
;
; in:   -
;
; out:  -
;

Initialise_OSByte242 Entry "r0-r2"
                MOV     r0, #serialctrl_ChangeBaud
                MOV     r1, #-1                 ; read both RX and TX
                MOV     r2, #-1
                BL      SerialControl
                BLVC    UpdateOSByteF2
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: HandshakeExtent
;
; in:   r0  = reason code
;       r1  = handshaking extent / -1 to read
;
; out:  r1  = previous value
;
; This routine is used to change the serial handshaking extent.  This used to
; be supplied by an OS_Byte call.
;

HandshakeExtent Entry   "r0"

                MOV     r0, #serialctrl_SetHandshakeExtent
                BL      SerialControl                           ; modify the extent
                STRVS   r0, [sp]

                EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: EnumerateSpeeds
;
; in:   r0  = reason code (9)
;
; out:  r0 preserved
;       r1 -> table of words containing supported speeds in 0.5bit/sec
;       r2 = number of entries in table
;
; This routine returns a pointer to a table of supported serial speeds.
;

EnumerateSpeeds Entry   "r0"

                MOV     r0, #serialctrl_EnumerateBaud
                BL      SerialControl
                STRVS   r0, [sp]

                EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: GetDeviceName
;
; in:   r0  = reason code (10)
;
; out:  r0 preserved
;       r1 -> device name within DeviceFS, e.g. 'Serial', 'Serial1', etc.
;
; This routine returns the name of the serial device
;

GetDeviceName   Entry   "r0"

                MOV     r0, #serialctrl_GetDeviceName
                BL      SerialControl
                STRVS   r0, [sp]

                EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: Modify6850
;
; in:   r0  = reason code
;       r1  = XOR mask
;       r2  = AND mask
;
; out:  r1  = old value
;       r2  = new value.
;
; This call allows the modification of the 6850 controller used within the original
; BBC B, this is provided for backwards compatibility.  Access to this is also provided
; via OS_Byte calls.
;

Modify6850      Entry   "r0, r3-r5"

                MOV     r3, r1
                MOV     r4, r2                                  ; take copy of entry r1, r2

                MOV     r0, #&C0
                SWI     XOS_Byte                                ; update current flags (r1 on exit is old state)
                BVS     %FT90

                AND     r5, r1, r4
                EOR     r5, r5, r3                              ; play around (via AND, XOR sequence)

                Debug   modify6850, "modify6850: old, new:", r1, r5
                Debug   modify6850, "modify6850: AND, XOR:", r4, r3

; ignore bits 0 and 1 of register (divide by 1,16,64 or reset)

; first look at the word select bits, if they've changed

                MVN     r2, r4                                  ; NOT(AND mask)
                ORR     r2, r2, r3                              ; EOR (mask) OR NOT (AND mask) - ie. bits being modified
                TST     r2, #WSB6850                            ; if zero then not modifying
                BEQ     %FT20                                   ; and then skip format changes

                Push    "r1"                                    ; preserve important registers

                MOV     r0, #SerialOp_DataFormat
                AND     r1, r5, #WSB6850                        ; extract new format bits
                ADR     lr, formattable
                LDRB    r1, [lr, r1, LSR #WSBSHIFT]             ; get new-style format bits

                Debug   modify6850, "modify6850: new format bits:", r1

                SWI     XOS_SerialOp
                Pull    "r1"                                    ; balance the stack correctly
                BVS     %FT90                                   ; (leave if it errored!)
20

; now look at transmitter control bits

                AND     r2, r5, #RTBITS6850                     ; r2 = new transmitter control bits
                EOR     lr, r1, r5                              ; differences between old and new
                TST     lr, #RTBITS6850                         ; if transmitter control bits are the same
                BEQ     %FT30

                TEQ     r2, #RHIBRK6850                         ; if we are not sending break now, then skip
                BNE     %FT22

                MOV     r0, #serialctrl_StartBreak              ; we are sending break, and we weren't before
                BL      SerialControl                           ; so start the break
                BVS     %FT90
22
                AND     lr, r1, #RTBITS6850                     ; if we were not sending break, then skip
                TEQ     lr, #RHIBRK6850
                BNE     %FT30

                MOV     r0, #serialctrl_StopBreak               ; we were sending break, and we aren't now
                BL      SerialControl                           ; so stop the break
                BVS     %FT90
30
 [ {FALSE}                                      ; don't affect UserRTSHigh bit any more, it's too permanent
                Push    "r1"

                TEQ     r2, #RLOTXD6850                         ; if we're disabling RTS
                MOVEQ   r1, #1 :SHL: SF_UserRTSHigh             ; then set bit in mask
                MOVNE   r1, #0                                  ; else clear it

                MOV     r0, #SerialOp_Status                    ; SerialOp modify flags reason
                MVN     r2, #(1:SHL:SF_UserRTSHigh)
                SWI     XOS_SerialOp
                Pull    "r1"                                    ; restore r1 (balancing stack (even if VS))

                BVS     %FT90
 ]
                MOV     r2, r5                                  ; return new value in r2 (from r5)
                CLRV
                EXIT
90
                ADD     sp, sp, #4
                Pull    "r3-r5, pc"                              ; r0 -> error, V =1.


formattable     ; convert between old 6850 format bits and a suitable value
                ; for passing into OS_SerialOp 1.
                ;

                NewBits 1, 1, 1, 1                              ; 7 bits, even parity, 2 stop bits
                NewBits 1, 1, 1, 0                              ; 7 bits, odd parity, 2 stop bits
                NewBits 1, 0, 1, 1                              ; 7 bits, even parity, 1 stop bit
                NewBits 1, 0, 1, 0                              ; 7 bits, odd parity, 1 stop bit
                NewBits 0, 1, 0, 0                              ; 8 bits, 2 stop bits
                NewBits 0, 0, 0, 0                              ; 8 bits, 1 stop bit
                NewBits 0, 0, 1, 1                              ; 8 bits, even parity, 1 stop bit
                NewBits 0, 0, 1, 0                              ; 8 bits, odd parity, 1 stop bit

                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: HandleOSByte
;
; in:   r0  = OS Byte
;       r1  = X
;       r2  = Y
;
; out:  -
;
; This code handles the interception of the OS_Byte calls within the kernel, it is
; called on a vector.  Interception should be handled as quickly as possible, ie.
; check they are the calls we want quickly and pass on if not.
;

HandleOSByte    ROUT
                TEQ     r0, #&CB                                ; if neither read/write handshake extent
                TEQNE   r0, #&CC                                ; nor read/write input suppression
                MOVNE   pc, lr                                  ; then pass it on

                Push    "r0-r4, lr"
                Debug   osbyte,"HandleOSByte",r0

                TEQ     r0, #&CB                                ; read/write handshake extent
                BNE     %10

                MOV     r0, #serialctrl_SetHandshakeExtent
                MOV     r1, #-1                                 ; read current handshake extent
                Debug   osbyte," call 1 parms:",r0,r1
                BL      SerialControl

                LDMVCIB sp, {r3, r4}                            ; read AND / XOR masks
                ANDVC   r1, r1, r4
                EORVC   r1, r1, r3                              ; new = (old AND Y) XOR X
                DebugIf VC,osbyte," call 2 parms:",r0,r1
                BLVC    SerialControl

                STRVS   r0, [sp]
                Pull    "r0-r4, pc"

; must be input suppression osbyte (&CC)

10
                MOV     r0, #SerialOp_Status                    ; reason 0, modify flags
                MOV     r1, #0
                MOV     r2, #-1                                 ; r1 =0, r2 =-1, read state
                SWI     XOS_SerialOp
                BVS     %15                                     ; catch the old rogue error

                ANDS    r1, r1, #(1 :SHL: SF_RXIgnore)          ; zero if not ignoring RX
                MOVNE   r1, #&FF                                ; else use &FF

                LDMIB   sp, {r3, r4}                            ; get AND/XOR masks
                AND     r1, r1, r4
                EORS    r1, r1, r3                              ; new = (old AND Y) XOR X
                MOVNE   r1, #1 :SHL: SF_RXIgnore
                MVN     r2, r1                                  ; preserve all but RXIgnore bit
                SWI     XOS_SerialOp
15
                STRVS   r0, [sp]                                ; store r0 onto frame (if errored!)
                Pull    "r0-r4, pc"

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: SerialControl
;
; in:   registers setup correctly
;
; out:  -
;
; This call calls the actual device driver.
;

SerialControl   Entry   "r0-r7"                                 ; create stack frame for device

                LDR     r1, SerialDeviceHandle
                TEQ     r1, #0                                  ; do we know the handle for serial?
                PullEnv EQ
                ADREQL  r0, ErrorBlock_Serial_NoSerialDevice
                DoError EQ                                      ; return an error if needed

                ADD     r2, sp, #4                              ; point at stacked registers
                SWI     XDeviceFS_CallDevice
                STRVS   r0, [sp]
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Generalised internationalisation routines, these ensure that messages files
; are correctly opened and then return the relevant data.
;
              [ international


; Attempt to open the messages file.

OpenMessages    ROUT

                Push    "r0-r3, lr"

                LDR     r3, Flags
                TST     r3, #f_WeHaveMessages                   ; do we have an open messages block?
                Pull    "r0-r3, pc", NE                         ; yes, so don't bother again

                ADR     r0, MessagesWorkspace
                ADRL    r1, resource_file                       ; -> path to be opened
                MOV     r2, #0                                  ; allocate some wacky space in RMA
                SWI     XMessageTrans_OpenFile
                LDRVC   r3, Flags
                ORRVC   r3, r3, #f_WeHaveMessages
                STRVC   r3, Flags                               ; assuming it worked mark as having messages

                Pull    "r0-r3, pc"                             ; returning VC, VS from XSWI!


; Attempt to close the messages file.

CloseMessages   ROUT

                Push    "r0, lr"

                LDR     r0, Flags
                TST     r0, #f_WeHaveMessages                   ; do we have any messages?
                Pull    "r0, pc", EQ                            ; and return if not!

                ADR     r0, MessagesWorkspace
                SWI     XMessageTrans_CloseFile                 ; yes, so close the file
                LDRVC   r0, Flags
                BICVC   r0, r0, #f_WeHaveMessages
                STRVC   r0, Flags                               ; mark as we don't have them

                CLRV
                Pull    "r0, pc"


; Generate an error based on the error token given.  Does not assume that
; the messages file is open.  Will attempt to open it, then look it up.

MakeError       ROUT

                Push    "r1-r7, lr"

                LDR     r1, Flags
                TST     r1, #f_WeHaveMessages                   ; has the messages file been closed?
                BLEQ    OpenMessages

                LDR     r1, Flags
                TST     r1, #f_WeHaveMessages
                Pull    "r1-r7, lr", EQ
                BEQ     %FT99                                   ; if still not open then return with V set

                ADR     r1, MessagesWorkspace                   ; -> message control block
                MOV     r2, #0
                MOV     r3, #0
                MOV     r4, #0
                MOV     r5, #0
                MOV     r6, #0
                MOV     r7, #0                                  ; no substitution + use internal buffers
                SWI     XMessageTrans_ErrorLookup

                BL      CloseMessages                           ; attempt to close the doofer

99
                SETV
                Pull    "r1-r7, pc"                             ; return, r0 -> block, V set

              ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle trapping the UpCall vector as required, this means that we look for
; stream created/closed and then from here we can set and clear flags as needed.
;

HandleUpCall    Entry   "r3"

                LDR     lr, SerialDeviceHandle

                TEQ     r0, #UpCall_StreamCreated
                TEQNE   r0, #UpCall_StreamClosed
                TEQEQ   r1, lr                                  ; correct up call, what about device?
                EXIT    NE

                TEQ     r0, #UpCall_StreamClosed
                MOVEQ   r3, #0                                  ; zap handle if being closed!

                TEQ     r2, #0                                  ; is it an RX or TX stream?
                STREQB  r3, RXstreamHandle
                STRNEB  r3, TXstreamHandle                      ; store the handle as required

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


              [ debug
                InsertNDRDebugRoutines
              ]

                END
