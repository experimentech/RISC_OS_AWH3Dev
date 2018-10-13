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
;
;               Copyright 1996 Acorn Network Computing
;
;  This material is the confidential trade secret and proprietary
;  information of Acorn Network Computing. It may not be reproduced,
;  used, sold, or transferred to any third party without the prior
;  written consent of Acorn Network Computing. All rights reserved.
;

ioctl_read      * 1:SHL:30
ioctl_write     * 1:SHL:31

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: ioctl
;
; in:   r0 = devicefs reason code
;       r2 = device driver stream handle
;       r3 -> ioctl control block
;
; where control block is
;       word one - bits 0-15  : reason code
;                  bits 16-29 : group code
;                  bit  30    : read
;                  bit  31    : write
;       word two - data
;
; This is the ioctl entry point.

ioctl           ROUT

                LDR     r0, [r3, #0]            ; load reason code

; mask off top 16 bits of r0 to obtain reason code
                MOV     r0, r0, LSL #16
                MOV     r0, r0, LSR #16

                CMP     r0, #(%20-%10)/4        ; validate reason code
                ADDCC   pc, pc, r0, LSL #2      ; despatch
                B       %20
10
                MOV     pc, lr                  ; 0 nothing
                B       ioctl_baud              ; 1 set baud rate
                B       ioctl_data              ; 2 set data format
                B       ioctl_handshake         ; 3 set handshaking
                B       ioctl_buffer_size       ; 4 set buffer size
                B       ioctl_buffer_thres      ; 5 set buffer threshold
                B       ioctl_ctrl_lines        ; 6 set control lines
                B       ioctl_fifo_trig         ; 7 set fifo threshold
                B       ioctl_read_bauds        ; 8 return number of bauds
                B       ioctl_read_baud         ; 9 return baud rate
                B       ioctl_flush_buffer      ; 10 flush buffer
20
                ADDR    r0, ErrorBlock_Serial_BadIOCtlReasonCode
                DoError

                MakeErrorBlock Serial_BadIOCtlReasonCode
                MakeErrorBlock Serial_BadIOCtlParameter

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_baud      Entry   "r0-r4,r9"

                LDR     r9, HAL_StaticBase

                LDR     r4, [r3, #0]            ; load flags
                LDR     r0, [r3, #4]            ; load data

; are we writing the baud
                TST     r4, #ioctl_write
                BEQ     %10
                BL      hardware_set_baud
10
; do we wish to read current
                TST     r4, #ioctl_read
                BEQ     %20

                MOV     r4, r3                  ; save r3 over HAL call
                MOV     r1, #-1                 ; read port
                CallHAL HAL_UARTRate
                MOV     r0, r0, LSR#4           ; call returned baud * 16

                STR     r0, [r4, #4]
20
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_data      Entry   "r0-r6, r9"

                MOV     r6, r3
                LDR     r9, HAL_StaticBase

                MOV     r1, #-1
                CallHAL HAL_UARTFormat          ; read current format in case of out-of-range parameter

                MOV     r5, r0                  ; remember in case we're reading current state

                LDR     r4, [r6, #0]            ; load flags
                LDR     r1, [r6, #4]            ; load data

; are we writing the data
                TST     r4, #ioctl_write
                BEQ     %10

; handle data format
                AND     r2, r1, #&ff
                SUB     r2, r2, #5
                CMP     r2, #3
                BICLS   r0, r0, #3
                ORRLS   r0, r0, r2

; handle stop options
                AND     r2, r1, #&ff00
                CMP     r2, #&200
                ORREQ   r0, r0, #4
                BICNE   r0, r0, #4         

; handle parity options
                AND     r2, r1, #&ff0000
                CMP     r2, #&10000
                BIC     r1, r0, #&38
                ORREQ   r1, r1, #&18
                ORRGT   r1, r1, #&08

                MOV     r5, r1                  ; remember in case we're reading current state

; update hardware
                CallHAL HAL_UARTFormat

10
; do we wish to read current
                TST     r4, #ioctl_read
                BEQ     %FT20

; extract data format
                AND     r0, r5, #3
                ADD     r0, r0, #5

; extract stop options
                TST     r5, #4
                ADDNE   r0, r0, #&200
                ADDEQ   r0, r0, #&100

; extract parity options
                AND     r5, r5, #&38
                CMP     r5, #&18
                ADDEQ   r0, r0, #&10000
                CMP     r5, #&08
                ADDEQ   r0, r0, #&20000

                STR     r0, [r6, #4]

20
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_handshake Entry "r1-r2,r4-r5"

                LDR     r5, [r3, #0]            ; load flags
                LDR     r4, [r3, #4]            ; load data

; are we writing the data
                TST     r5, #ioctl_write
                MOVEQ   r1, #0
                MVNEQ   r2, #0
                BEQ     %10

                MOV     r1, #(1:SHL:SF_DSRIgnore)+(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                CMP     r4, #1
                MOVEQ   r1, #(1:SHL:SF_DSRIgnore)
                CMP     r4, #2
                MOVEQ   r1, #(1:SHL:SF_XONXOFFOn)+(1:SHL:SF_DSRIgnore)+(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                CMP     r4, #3
                MOVEQ   r1, #(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                LDR     r2, =:NOT: ((1:SHL:SF_XONXOFFOn)+(1:SHL:SF_DSRIgnore)+(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)+(1:SHL:SF_IXOFFedHim))
10
                BL      change710flags                

; do we wish to read current
                CLRV
                TST     r5, #ioctl_read
                EXIT    EQ
                AND     r2, r2, #(1:SHL:SF_XONXOFFOn)+(1:SHL:SF_DSRIgnore)+(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                MOV     r1, #0
                CMP     r2, #(1:SHL:SF_DSRIgnore)
                MOVEQ   r1, #1
                CMP     r2, #(1:SHL:SF_XONXOFFOn)+(1:SHL:SF_DSRIgnore)+(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                MOVEQ   r1, #2
                CMP     r2, #(1:SHL:SF_CTSIgnore)+(1:SHL:SF_NoRTSHandshake)
                MOVEQ   r1, #3
                
                STR     r1, [r3, #4]

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_buffer_size Entry "r0-r4"

                LDR     r4, [r3, #0]            ; load flags
                LDR     r1, [r3, #4]            ; load data

                LDR     r0, InputHandle

; are we writing the data
                TST     r4, #ioctl_write
                BEQ     %10

                TEQ     r0, r2
                STREQ   r1, InputBufferSize
                STRNE   r1, OutputBufferSize
10
; do we wish to read current
                TST     r4, #ioctl_read
                EXIT    EQ

                TEQ     r0, r2
                LDREQ   r1, InputBufferSize
                LDRNE   r1, OutputBufferSize
                STR     r1, [r3, #4]            ; write back to data block

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_buffer_thres Entry "r0-r5"

                LDR     r4, [r3, #0]            ; load flags
                LDR     r1, [r3, #4]            ; load data

                LDR     r5, InputHandle

; are we writing the data
                TST     r4, #ioctl_write
                BEQ     %10

                TEQ     r5, r2
                LDREQ   r0, InputBufferHandle
                LDRNE   r0, OutputBufferHandle
                SWI     XBuffer_Threshold       ; set buffer threshold
                EXIT    VS                      ; return if it didn't work

; store new value in workspace if call succeeded
                STREQ   r1, InputBufferThreshold
                STRNE   r1, OutputBufferThreshold

10
; do we wish to read current
                TST     r4, #ioctl_read
                EXIT    EQ

                TEQ     r5, r2
                LDREQ   r1, InputBufferThreshold
                LDRNE   r1, OutputBufferThreshold
                STR     r1, [r3, #4]            ; write back to data block

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_ctrl_lines Entry "r0-r4,r9"

                LDR     r9, HAL_StaticBase

                LDR     r4, [r3, #0]            ; load flags
                LDR     r0, [r3, #4]            ; load data

; are we writing the data
                TST     r4, #ioctl_write
                MOV     r1, #0
                MVNEQ   r2, #0
                BEQ     %10

                TST     r0, #1:SHL:0            ; check dtr
                ORREQ   r1, r1, #(1:SHL:SF_DTROff)
                TST     r0, #1:SHL:1            ; check rts
                ORREQ   r1, r1, #(1:SHL:SF_UserRTSHigh)
                MVN     r2, #(1:SHL:SF_DTROff)+(1:SHL:SF_UserRTSHigh)
10
                BL      change710flags
                CLRV

; do we wish to read current
                TST     r4, #ioctl_read
                EXIT    EQ

                MOV     r1, #0
                TST     r2, #(1:SHL:SF_DTROff)
                ORREQ   r1, r1, #1:SHL:0
                TST     r2, #(1:SHL:SF_UserRTSHigh)
                ORREQ   r1, r1, #1:SHL:1
                TST     r2, #(1:SHL:SF_CTSHigh)
                ORREQ   r1, r1, #1:SHL:16
                TST     r2, #(1:SHL:SF_DSRHigh)
                ORREQ   r1, r1, #1:SHL:17
                TST     r2, #(1:SHL:SF_Ringing)
                ORRNE   r1, r1, #1:SHL:18
                TST     r2, #(1:SHL:SF_DCDHigh)
                ORREQ   r1, r1, #1:SHL:19
                TST     r2, #(1:SHL:SF_FillTXFIFO)
                ORRNE   r1, r1, #1:SHL:20

                STR     r1, [r3, #4]            ; write back to data block

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_fifo_trig Entry "r0-r4,r9"

                LDR     r9, HAL_StaticBase

                MOV     r4, r3

                LDR     r1, [r4, #0]            ; load flags

; are we writing the data
                TST     r1, #ioctl_write
                BEQ     %10

                LDR     r1, [r4, #4]            ; load data
                CMP     r1, #255
                MOVHI   r1, #255
                STRB    r1, FIFOTrigger
                
                CallHAL HAL_UARTFIFOThreshold

; ensure FIFOs are enabled
                LDR     r2, SerialDeviceFlags
                ORR     r1, r2, #1:SHL:SF_UseFIFOs
                BL      SetFIFO
                
                CLRV
10
; do we wish to read current
                LDR     r1, [r4, #0]
                TST     r1, #ioctl_read
                EXIT    EQ

                LDRB    r0, FIFOTrigger
                STR     r0, [r4, #4]            ; write back to data block

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_read_bauds Entry "r0-r3"

    ! 0, "ioctl_read_bauds not implemented"
;               ADRL    r1, baud_table
;               ADRL    r2, baud_table_end
;
;               SUB     r0, r2, r1
;               MOV     r0, r0, LSR #3
;
;               STR     r0, [r3, #4]            ; store data

                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_read_baud Entry "r0-r5"

    ! 0, "ioctl_read_baud not implemented"

;               LDR     r4, [r3, #4]            ; load data
;; calc number of bauds again
;               ADRL    r1, baud_table
;               ADRL    r2, baud_table_end
;               SUB     r5, r2, r1
;               MOV     r5, r5, LSR #3
;; check for invalid index values
;               MOV     r0, #0
;               CMP     r4, #0
;               BLT     %10
;               CMP     r4, r5
;               BGE     %10
;
;; calc address of baud rate
;               MOV     r4, r4, LSL #3
;               ADD     r1, r1, r4
;               LDR     r0, [r1]
;10
;               STR     r0, [r3, #4]            ; store data

                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ioctl_flush_buffer Entry "r0-r3"

                LDR     r1, [r3, #0]            ; load flags

                LDR     r3, InputHandle

; are we writing?
                TST     r1, #ioctl_write
                BEQ     %F10

                TEQ     r2, r3
                LDREQ   r1, InputBufferPrivId
                LDRNE   r1, OutputBufferPrivId

; check for valid internal buffer id
                CMP     r1, #-1
                BEQ     %F10

                MOV     r0, #BufferReason_PurgeBuffer
                CallBuffMan

; reading returns undefined value in data field of ioctl block
10
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                END
