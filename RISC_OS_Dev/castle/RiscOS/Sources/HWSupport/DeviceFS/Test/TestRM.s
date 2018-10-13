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
; > TestSrc
;
                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:ModHand
                GET     hdr:DeviceFS
                GET     hdr:Buffer
                GET     hdr:NDRDebug
                GET     hdr:DDVMacros

                GBLL    debug
                GBLL    hostvdu

                GBLL    wuTX

debug           SETL    false
hostvdu         SETL    true

wuTX            SETD    false


                ^ 0, wp
device_handle   # 4                                             ; device handle / =0 if not registered
TXHandle        # 4
RXHandle        # 4
Pending         # 4

workspace       * :INDEX: @                                     ; index for workspace size

BufferSize              * &110
BufferThreshold         * 0
TXInternalHandle        * 1
RXInternalHandle        * 2

PendingFlag             * 1:SHL:31


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; A test device, this simply installs itself into the system.
; The device is full duplex and simply transfers bytes from its transmit buffer
; to its receive buffer.
;                                                             
                                                              
module_start    & 0                                             ; no start code
                & init -module_start                            ; init code offset
                & final -module_start                           ; finalise code offset
                & 0

                & title -module_start                           ; start code base address
                & help -module_start                            ; help string
                & 0

title           = "TestDevice", 0
help            = "Test Device", 9, "0.00 (06 Apr 91)", 0
                ALIGN
                     
device_name     = "Test", 0
                ALIGN


; block required to register devices with the filing system.
;

device_block    & device_name -.                                ; offset to the device name
                & 2_11                                          ; buffered, set path variable
                & 0
                & 16
                & 0
                & 16
                & 0

                & 0

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Register a device with device fs, claim some workspace and fart around.
;
                                                                         
init            ROUT

                Push    "r1-r3, lr"

                LDR     r2, [wp]
                TEQ     r2, #0                                  ; does the thing have any workspace yet?
                BNE     %10

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace
                SWI     XOS_Module                              ; attempt to claim, if V clear then r2 -> workspace
                Pull    "r1-r3, pc", VS                         ; return if it goes bang!!!!!!!!!!!

                STR     r2, [wp]
10              
                MOV     wp, r2                                  ; -> workspace

                MOV     r0, #0
                STR     r0, device_handle                       ; reset my device handle
                STR     r0, TXHandle
                STR     r0, RXHandle
                STR     r0, Pending

                MOV     r0, #2_10                               ; full duplex
                ADR     r1, device_block                        ; -> device list
                ADR     r2, handler                             ; -> device code
                MOV     r3, #0                                  ;  = private word
                MOV     r4, wp                                  ; -> workspace
                MOV     r5, #0
                MOV     r6, #1                                  ; max number of RX streams
                MOV     r7, #1                                  ; max number of TX streams
                SWI     XDeviceFS_Register
                STRVC   r0, device_handle

                Pull    "r1-r3, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This bit handles the device doofing around when it gets bonked!
;
                                                                 
final           ROUT

                Push    "r2-r3, lr"

                LDR     wp, [wp]                                ; -> workspace

                LDR     r0, device_handle
                TEQ     r0, #0                                  ; is the goat head registered?
                SWINE   XDeviceFS_Deregister

                MOV     r0, #ModHandReason_Free
                MOV     r2, wp                                  ; free workspace
                SWI     XOS_Module

                Pull    "r2-r3, pc",,^

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

handler
; handle calls from DeviceFS
                CMP     r0, #(%10-%00)/4
                ADDCC   pc, pc, r0, LSL #2
                B       %FT10
00
                B       open
                B       close
                B       wakeupTX
                MOV     pc, lr
                MOV     pc, lr
                MOV     pc, lr
                B       createTX
                B       createRX
                MOV     pc, lr
                MOV     pc, lr
                MOV     pc, lr
                MOV     pc, lr
10
                ADR     r0, Error_IllegalReasonCode
                ORR     pc, lr, #V_bit

Error_IllegalReasonCode
                DCD     0
                DCB     "Illegal reason code from DeviceFS",0
                ALIGN


open
; Open a stream.
                TST     r3, #1
                STREQ   r2, RXHandle
                STRNE   r2, TXHandle
                MOVEQ   r2, #RXInternalHandle
                MOVNE   r2, #TXInternalHandle
                MOV     pc, lr

close
; Close a stream.
                Push    "r1,lr"
                TEQ     r2, #0
                TEQNE   r2, #TXInternalHandle
                STREQ   r1, TXHandle
                TEQ     r2, #0
                TEQNE   r2, #RXInternalHandle
                STREQ   r1, RXHandle
                Pull    "r1,pc"

wakeupTX        ROUT
; Just pass bytes from transmit buffer to receive buffer.
                Push    "r1,lr"

                Debug   wuTX,"transferring bytes"

                LDR     r0, Pending                     ; byte pending from last time?
                TST     r0, #PendingFlag
                BICNE   r0, r0, #PendingFlag            ; if so then use it
                MOVNE   r1, #0                          ; and clear pending
                STRNE   r1, Pending
                BNE     %FT20                           ; and process it first
10
                Debug   wuTX,"getting byte from DeviceFS"

                LDR     r1, TXHandle                    ; get byte from transmit buffer
                TEQ     r1, #0
                Pull    "r1,pc",EQ                      ; TX stream not open so return
                SWI     XDeviceFS_TransmitCharacter
                Pull    "r1,pc",VS                      ; return any error
                Pull    "r1,pc",CS                      ; return if no bytes to pass on
20
                Debug   wuTX,"sending byte to DeviceFS"

                LDR     r1, RXHandle                    ; pass on byte to receive buffer
                TEQ     r1, #0
                BEQ     %BT10                           ; RX stream not open, just throw away
                SWI     XDeviceFS_ReceivedCharacter
                Pull    "r1,pc",VS                      ; return any error
                ORRCS   r0, r0, #PendingFlag            ; if couldn't transfer byte
                STRCS   r0, Pending                     ; then save it for next time
                Pull    "r1,pc",CS                      ; and return

                B       %BT10

createTX
; Register the transmit buffer.
                MOV     r4, #BufferSize
                MOV     r6, #BufferThreshold
                MOV     pc, lr

createRX
; Register the receive buffer.
                MOV     r4, #BufferSize
                MOV     r6, #BufferThreshold
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        [ debug
                InsertNDRDebugRoutines
        ]

                END


