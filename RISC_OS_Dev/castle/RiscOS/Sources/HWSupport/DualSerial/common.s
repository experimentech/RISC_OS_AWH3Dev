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
; > Common


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: SetExtent
;
; in:   r0  = reason code
;       r1  = new extent / =-1 to read
;
; out:  r1  = old value
;
; This call when made will change the handshaking extent on output streams.  The
; code will reset my copy and then call DeviceFS, which in turn calls the Buffer
; Manager to set things up correctly.
;

SetExtent       Entry   "r0,r2-r3"
                LDR     r3, InputBufferThreshold
                CMP     r1, #-1                                 ; are we just reading?
                BEQ     %FT10                                   ; yes, so return

                STR     r1, InputBufferThreshold
                MOV     r2, r1                                  ; setup new version
                LDR     r1, InputHandle
                TEQ     r1, #0
                BEQ     %FT10                                   ; if no input stream then ignore

                SWI     XDeviceFS_Threshold
                STRVS   r0, [sp]                                ; it went wrong so
                PullEnv VS
                DoError VS                                      ; return error
10
                ADDS    r1, r3, #0                              ; setup return threshold, clear V
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: CreateForTX
;
; in:   r0  = reason code
;       r2  = internal handle
;       r3  = flags for buffer
;       r4  = suggested size of buffer
;       r5  = suggested handle for buffer
;       r6  = suggested threshold value
;
; out:  r3  = modified flags
;       r4  = modified buffer size
;       r5  = suggested buffer handle
;       r6  = if -1 on exit then no threshold, else set to specified value
;
; This routine is called before the buffer is actually create, it allows the
; device to change the values (ie. buffer size) and then return.  r5 should
; contain a unique buffer handle.
;

CreateForTX     ROUT
; look to see if we wish to change the default size
                LDR     r0, OutputBufferSize
                CMP     r0, #0
                MOVNE   r4, r0
                STREQ   r4, OutputBufferSize

; and now the default threshold
                LDR     r0, OutputBufferThreshold
                CMP     r0, #0                       ; clears V
                MOVNE   r6, r0
                STREQ   r6, OutputBufferThreshold

                LDR     r0, Flags
                TST     r0, #f_DefaultPort
                BEQ     %FT10
                
                CMP     r5, #-1
                MOVEQ   r5, #Buff_RS423Out                      ; use original serial buffer handle
10
                CLRV
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: CreateForRX
;
; in:   r0  = reason code
;       r2  = internal handle
;       r3  = flags for buffer
;       r4  = suggested size of buffer
;       r5  = suggested handle for buffer
;       r6  = suggested threshold value
;
; out:  r3  = modified flags
;       r4  = modified buffer size
;       r5  = suggested buffer handle
;       r6  = if -1 on exit then no threshold, else set to specified value
;
; This routine is called before the buffer is actually create, it allows the
; device to change the values (ie. buffer size) and then return.  r5 should
; contain a unique buffer handle.
;

CreateForRX     ROUT
                ORR     r3, r3, #BufferFlags_SendThresholdUpCalls ; interested in thresholds for receive buffer

; look to see if we wish to change the default size
                LDR     r0, InputBufferSize
                CMP     r0, #0
                MOVNE   r4, r0
                STREQ   r4, InputBufferSize

; and now the default threshold
                LDR     r0, InputBufferThreshold
                CMP     r0, #0                       ; clears V
                MOVNE   r6, r0
                STREQ   r6, InputBufferThreshold

                LDR     r0, Flags
                TST     r0, #f_DefaultPort
                BEQ     %FT10

                CMP     r5, #-1
                MOVEQ   r5, #Buff_RS423In                       ; use original serial buffer handle
10
                CLRV
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       getchar - Perform OS_SerialOp 4 (get character)
;
; in:   r0 = device reason
;
; out:  C=0, r1=char if there was one
;       C=1, r1 preserved if there wasn't
;

getchar         Entry   "r0-r2,r9"
                LDR     r1, InputBufferHandle
                CMP     r1, #-1                         ; if no serial input stream open, r1 = -1, so C=1
                EXIT    EQ

                MOV     r9, #REMV
                SWI     XOS_CallAVector                 ; NB V=0 from CMP, so remove not examine
                STRVS   r0, [sp, #0*4]
                EXIT    VS                              ; shouldn't get an error, but still...
                STRCC   r0, [sp, #1*4]                  ; if got char then store into stack frame
                EXIT                                    ; and exit with flags on exit from RemV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       putchar - Perform OS_SerialOp 3 (put character)
;
; in:   r0 = device reason
;       r1 = character to send
;
; out:  C=0 => character sent
;       C=1 => no room in buffer
;

putchar         Entry   "r0-r2,r9"
                LDR     r1, OutputBufferHandle
                CMP     r1, #-1                         ; check if we have a serial output stream open
                BNE     %FT10                           ; if we have, then it's OK

                ; Construct a filename to open
                SUB     sp, sp, #12
                ADR     r0, DeviceFSBlock
                MOV     r1, sp
05
                LDRB    r2, [r0], #1
                CMP     r2, #0
                STRNEB  r2, [r1], #1
                BNE     %BT05
                MOV     r0, #':'
                STRB    r0, [r1], #1
                STRB    r2, [r1], #1

                MOV     r0, #open_write
                MOV     r1, sp
                SWI     XOS_Find
                ADD     sp, sp, #12
                STRVS   r0, [sp]
                EXIT    VS

                TEQ     r0, #0
                STRNE   r0, PutCharOutputFileHandle

                LDR     r1, OutputBufferHandle          ; now check buffer handle again
                CMP     r1, #-1                         ; if still -1 then we didn't open stream
                EXIT    EQ                              ; so exit, CS
10
                LDR     r0, [sp, #1*4]                  ; reload character to send
                MOV     r9, #INSV
                SWI     XOS_CallAVector
                STRVS   r0, [sp]
                EXIT                                    ; exit with flags as on exit from InsV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BaudRates       ; Table of supported baud rates (in 0.5 bit units).
                & 75 * 2
                & 150 * 2
                & 300 * 2
                & 1200 * 2
                & 2400 * 2
                & 4800 * 2
                & 9600 * 2
                & 19200 * 2
                & 50 * 2
                & 110 * 2
                & 134 * 2 + 1
                & 600 * 2
                & 1800 * 2
                & 3600 * 2
                & 7200 * 2
EndOldRates
                & 38400 * 2
                & 57600 * 2
                & 115200 * 2
                & 230400 * 2
EndNewRates

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       GetDeviceName - Perform OS_SerialOp 10 (get device name)
;
; in:   r0 = device reason
;
; out:  r1 -> device name
;

GetDeviceName
                ADR     r1, DeviceFSBlock
                MOV     pc, lr 


                END


