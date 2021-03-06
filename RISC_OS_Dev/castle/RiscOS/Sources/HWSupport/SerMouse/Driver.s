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
; > Sources.Driver

;---------------------------------------------------------------------------
;       Minimise interrupt latency by using a re-entrancy lock.  If locked
;       this routine simply passes on the TickerV call.  If not locked then
;       the routine locks and pushes the driver address onto the stack before
;       passing on the call.  This ensures that all claimants of TickerV are
;       called BEFORE the kernel branches to our routine by pulling the address
;       off the stack.
;
TickerVHandler
        LDRB    r0, Locked
        TEQ     r0, #0                          ; If re-entrancy lock is on then
        MOVNE   pc, lr                          ;   just pass on call.

        MOV     r0, #&FF                        ; Lock.
        STRB    r0, Locked

        JumpAddress r0,DriverEntry,forward      ; Make TickerV call return to us, not caller.
        Push    "r0,r12"                        ; Stack call address and workspace pointer.
        MOV     pc, lr                          ; Pass on TickerV call.

;---------------------------------------------------------------------------
;       Handle serial input stream using a state machine.
;
DriverEntry
        Pull    r12                             ; Get the workspace pointer we stacked.
        SVCMode r11, r0                         ; Make sure we are in SVC mode, IRQs on.
        NOP
        Push    lr                              ; Save SVC lr.

NextByte
        MOV     r0, #OSArgs_EOFCheck
        LDR     r1, SerialInHandle
        SWI     XOS_Args
        BVS     ReadError

        CMP     r2, #0
        DebugIf EQ,drv,"reading..."
        SWIEQ   XOS_BGet

        DebugIf CC,drv,"...got",r0
        LDRCC   pc, State                       ; If got byte then branch to handler for current state.

DriverExit
        Debug   drv,"DriverExit"
        Pull    lr                              ; Restore SVC lr.
        SetPSR  r11                             ; Go back to old mode.
        MOV     r0, #0                          ; Unlock.
        STRB    r0, Locked
        Pull    pc                              ; Return to real TickerV caller.

ReadError
        Debug   drv,"ReadError"
        LDR     r0, [r0]                        ; Get error number.
        TEQ     r0, #ErrorNumber_Channel        ; If not invalid file handle then
        BNE     DriverExit                      ;   just exit.
        BL      OpenSerial                      ; Otherwise, make sure serial is open.
        BLVS    Disable                         ; If reopen failed then disable.
        B       DriverExit

;---------------------------------------------------------------------------
;       Idle state handler (wait for Microsoft or MSC start byte).
;
MouseIdle
        EOR     r3, r0, #&87                    ; If MSC start byte then button bits inverted
        TST     r3, #&F8                        ;     and bits 3-7 should be clear.
        ADREQ   r2, MSC_GetByte2
        BEQ     %FT10

        EOR     r3, r0, #&C0
        TST     r3, #&C0                        ; If not MS start byte then
        BNE     DriverExit                      ;   ignore it.
        ADR     r2, MS_GetByte2
10
        STRB    r3, Byte1
        STR     r2, State
        B       NextByte

;---------------------------------------------------------------------------
;       Abort interpretation of mouse data record.
;
Abort
        ADR     r3, MouseIdle                   ; Go into idle state.
        STR     r3, State
        B       MouseIdle                       ; Try to interpret invalid byte.

;---------------------------------------------------------------------------
;       State handlers for Microsoft compatible serial mouse.
;
MS_GetByte2
        EOR     r3, r0, #&80
        TST     r3, #&C0                        ; If not valid MS data then
        BNE     Abort                           ;   go back to idle state.

        STRB    r3, Byte2                       ; Remember byte2.
        ADR     r3, MS_GetByte3                 ; Set new state.
        STR     r3, State
        B       NextByte                        ; Try to get byte3.

MS_GetByte3
        EOR     r3, r0, #&80
        TST     r3, #&C0                        ; If not valid MS data then
        BNE     Abort                           ;   go back to idle state.

        LDRB    r2, Byte1                       ; Build Y movement to r1 (get byte1).
        AND     r1, r2, #&0C                    ; Mask off Y7 and Y6 in byte1.
        ORR     r1, r3, r1, LSL #4              ; Combine with byte3 to make 8-bit signed value.
        MOV     r1, r1, LSL #24
        MOV     r1, r1, ASR #24                 ; Sign extend it to 32 bits.

        LDRB    r3, Byte2                       ; Build X movement to r0 (get byte2).
        AND     r0, r2, #&03                    ; Mask off X7 and X6 in byte1.
        ORR     r0, r3, r0, LSL #6              ; Combine with byte2 to make 8-bit signed value.
        MOV     r0, r0, LSL #24
        MOV     r0, r0, ASR #24                 ; Sign extend it to 32 bits.

        MOV     r2, r2, LSR #3                  ; Build button states in r2 (r2 = 00000LRx)
        ORR     r2, r2, #&09                    ; r2 = 00001LR1
        AND     r2, r2, r2, LSR #1              ; r2 = 00001LR1 & 000001LR = 00000LMR (M = L & R)
        TST     r2, #&02                        ; If M bit set from L & R
        BICNE   r2, r2, #&05                    ;   then clear L and R bits.

        ADR     lr, MouseData
        LDMIA   lr, {r3,r10}                    ; Get DeltaX,DeltaY and Buttons.
        ADD     r0, r0, r3
        SUB     r1, r10, r1
        STMIA   lr, {r0-r2}

        ADR     r3, MS_GetByte4                 ; Set new state (could still get byte4).
        STR     r3, State

        B       DriverExit

MS_GetByte4
        EOR     r3, r0, #&80
        TST     r3, #&C0                        ; If not valid MS byte 4 then
        BNE     Abort                           ;   go back to idle state.

        LDR     r0, Buttons                     ; Get current button states.
        MOV     r3, r3, LSR #5                  ; r3 = 0000000M
        BIC     r0, r0, #&02                    ; Clear M bit.
        ORR     r0, r0, r3, LSL #1              ; Set new M bit.
        STR     r0, Buttons

        ADR     r3, MouseIdle                   ; Go back to idle state.
        STR     r3, State

        B       DriverExit

;---------------------------------------------------------------------------
;       State handlers for Mouse Systems Corporation compatible serial mouse.
;
MSC_GetByte2
        STRB    r0, Byte2                       ; Remember first X movement.
        ADR     r3, MSC_GetByte3                ; Set new state.
        STR     r3, State
        B       NextByte                        ; Try to get byte3.

MSC_GetByte3
        STRB    r0, Byte3                       ; Remember first Y movement.
        ADR     r3, MSC_GetByte4                ; Set new state.
        STR     r3, State
        B       NextByte                        ; Try to get byte4.

MSC_GetByte4
        STRB    r0, Byte4                       ; Remember second X movement.
        ADR     r3, MSC_GetByte5                ; Set new state.
        STR     r3, State
        B       NextByte                        ; Try to get byte5.

MSC_GetByte5
        LDRB    r2, Byte2                       ; Get first X movement.
        MOV     r2, r2, LSL #24                 ; Sign extend it.
        MOV     r2, r2, ASR #24
        LDRB    r3, Byte4                       ; Get second X movement.
        MOV     r3, r3, LSL #24                 ; Sign extend it and
        ADD     r2, r2, r3, ASR #24             ;   add to first.

        LDRB    r3, Byte3                       ; Get first Y movement.
        MOV     r3, r3, LSL #24                 ; Sign extend it.
        MOV     r3, r3, ASR #24
        MOV     r0, r0, LSL #24                 ; Sign extend second Y movement and
        ADD     r3, r3, r0, ASR #24             ;   add to first.

        ADR     lr, MouseData
        LDMIA   lr, {r0,r1}                     ; Get DeltaX,DeltaY.
        ADD     r0, r0, r2                      ; Adjust DeltaX.
        ADD     r1, r1, r3                      ; Adjust DeltaY.
        LDRB    r2, Byte1                       ; Get buttons.
        STMIA   lr, {r0-r2}                     ; Update DeltaX,DeltaY,Buttons.

        ADR     r3, MouseIdle                   ; Go back to idle state.
        STR     r3, State

        B       DriverExit

        END
