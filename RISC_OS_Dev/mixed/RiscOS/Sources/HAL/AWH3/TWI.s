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
;TWI.s
;This isn't being built. Just a skeleton.
        AREA    |Asm$$Code|, CODE, READONLY, PIC

;int HAL_IICBuses (void)
HAL_IICBuses
        MOV a1, #TWI_BusCount
        MOV pc, lr

;unsigned int HAL_IICType(int bus)
HAL_IICType
        MOV pc, lr

;low level
;__value_in_regs IICLines HAL_IICSetLines(int bus, IICLines lines
;typedef struct {int SDA, SCL } IICLines;
HAL_IICSetLines
        MOV pc, lr

;__value_in_regs IICLines HAL_IICReadLines(int bus)
HAL_IICReadLines
        MOV pc, lr

;high level

;int HAL_IICDevice(int bus)
HAL_IICDevice   ;returns device (IRQ#) of bus
        CMP a1, #0
        MOVEQ a1, #INT_TWI_0
        MOVEQ pc, lr
        CMP a1, #1
        MOVEQ a1, #INT_TWI_1
        MOVEQ pc, lr
        CMP a1, #2
        MOVEQ a1, #INT_TWI_2

        MOV pc, lr

;int HAL_IICTransfer(int bus, unsigned int n, iic_transfer transfer[static n]
HAL_IICTransfer
        MOV pc, lr

;int HAL_IICMonitorTransfer(int bus)
HAL_IICMonitorTransfer
        MOV pc, lr


        END
