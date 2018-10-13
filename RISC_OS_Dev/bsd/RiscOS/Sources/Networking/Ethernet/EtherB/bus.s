; 
; Copyright (c) 2012, RISC OS Open Ltd
; All rights reserved.
; 
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met: 
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of RISC OS Open Ltd nor the names of its contributors
;       may be used to endorse or promote products derived from this software
;       without specific prior written permission.
; 
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
; 

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System

        ; Bus access functions for the EtherB NIC
        ;
        ; On the SEEQ chip A0 -> LA2
        ;                  A1 -> LA6
        ;                  A2 -> LA7
        ;                  A3 -> LA8
        ;
        ; A0 acts as a byte lane select in 8 bit mode.
        ; A0 is ignored in 16 bit mode.
        ;
        ; Therefore all the offsets passed in by the driver need shifting up
        ; by 5, then for byte accesses offsetting by extra 4 only when odd.

        EXPORT  bus_read_1
        EXPORT  bus_read_2
        EXPORT  bus_read_multi_1
        EXPORT  bus_read_multi_2

        EXPORT  bus_write_1
        EXPORT  bus_write_2
        EXPORT  bus_write_multi_1
        EXPORT  bus_write_multi_2
                
        AREA    bus, PIC, CODE

        ; uint8_t bus_read_1(uintptr_t base, uintptr_t offset)
bus_read_1 ROUT
        TST     r1, #1
        ADD     r0, r0, r1, LSL #5
        LDREQB  r0, [r0, #0]
        LDRNEB  r0, [r0, #4]
        MOV     pc, lr

        ; uint16_t bus_read_2(uintptr_t base, uintptr_t offset)
bus_read_2 ROUT
        LDR     r0, [r0, r1, LSL #5]
        BIC     r0, r0, #&FF000000      ; Top 16 bits undefined on IOC
        BIC     r0, r0, #&00FF0000
        MOV     pc, lr

        ; void bus_read_multi_1(uintptr_t base, uintptr_t offset, uint8_t *buffer, size_t amount)
bus_read_multi_1 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
        TST     r1, #1
        MOV     r1, r1, LSL #5
        ADDNE   r1, r1, #4
10
        LDRB    r12, [r0, r1]
        STRB    r12, [r2], #1
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        ; void bus_read_multi_2(uintptr_t base, uintptr_t offset, uint16_t *buffer, size_t amount)
bus_read_multi_2 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
10
        LDR     r12, [r0, r1, LSL #5]
        STRB    r12, [r2], #1
        MOV     r12, r12, LSR #8
        STRB    r12, [r2], #1           ; Avoid STRH on IOC
        SUBS    r3, r3, #1
        BNE     %BT10        
        MOV     pc, lr

        ; void bus_write_1(uintptr_t base, uintptr_t offset, uint8_t value)
bus_write_1
        TST     r1, #1
        ADD     r0, r0, r1, LSL #5
        STREQB  r2, [r0, #0]
        STRNEB  r2, [r0, #4]
        MOV     pc, lr

        ; void bus_write_2(uintptr_t base, uintptr_t offset, uint16_t value)
bus_write_2
        MOV     r2, r2, LSL #16
        ORR     r2, r2, r2, LSR #16     ; Half word duplicate for IOC
        STR     r2, [r0, r1, LSL #5]
        MOV     pc, lr

        ; void bus_write_multi_1(uintptr_t base, uintptr_t offset, const uint8_t *buffer, size_t amount)
bus_write_multi_1 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
        TST     r1, #1
        MOV     r1, r1, LSL #5
        ADDNE   r1, r1, #4
10
        LDRB    r12, [r2], #1
        STRB    r12, [r0, r1]
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        ; void bus_write_multi_2(uintptr_t base, uintptr_t offset, const uint16_t *buffer, size_t amount)
bus_write_multi_2
        TEQ     r3, #0
        MOVEQ   pc, lr
        ADD     r0, r0, r1, LSL #5      ; Claw back a register
10
        LDRB    r12, [r2], #1
        LDRB    r1, [r2], #1            ; Avoid LDRH on IOC
        ORR     r1, r12, r1, LSL #8
        ORR     r1, r1, r1, LSL #16     ; Half word duplicate for IOC
        STR     r1, [r0]
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        END
        