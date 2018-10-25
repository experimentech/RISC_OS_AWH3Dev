;Copyright (c) 2017, Tristan Mumford
;All rights reserved.
;
;Redistribution and use in source and binary forms, with or without
;modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this
;   list of conditions and the following disclaimer.
;2. Redistributions in binary form must reproduce the above copyright notice,
;   this list of conditions and the following disclaimer in the documentation
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
;ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
;ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
;LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
;The views and conclusions contained in the software and documentation are those
;of the authors and should not be interpreted as representing official policies,
;either expressed or implied, of the RISC OS project.

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
