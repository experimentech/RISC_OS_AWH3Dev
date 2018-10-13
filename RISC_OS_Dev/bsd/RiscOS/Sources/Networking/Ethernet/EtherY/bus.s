; 
; Copyright (c) 2013, RISC OS Open Ltd
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

        ; Bus access functions for the EtherY network interface
        ;
        ; Net20 (podule)
        ; Flash   000000 - 7FFFFF (B wide, W spaced)
        ; Nothing 8xx000 - 8xxBFF
        ; IRQCTRL 8xxC00 - 8xxCFF (B wide, W spaced, b0 write to mask/b0 read for status)
        ; LANC111 8xxD00 - 8xxDFF (HW wide, HW spaced, 8x2 ISA style regs)
        ; LANDATA 8xxE00 - 8xxEFF (W wide, W spaced, bankless 32b access to 'DATA' reg)
        ; Nothing 8xxF00 - 8xxFFF
        ;
        ; Net21 (NIC)
        ; NIC ROM ROM:000 - 0FF (B wide, W spaced, 12 bit counter auto inc on read, flash limit => (256/4)*4096)
        ;         ROM:100 - 1FF (B wide, W spaced, no auto increment)
        ;         ROM:200 - 37F (B wide, W spaced, aliases of 100 - 1FF)
        ; COUNTER ROM:380 - 3FF (HW wide, W spaced, read/write access to 12 bit counter)
        ; IRQCTRL NIC:000 - 07F (B wide, W spaced, b0 write to mask/b0 read for status)
        ; LANC111 NIC:080 - 0BF (HW wide, DW spaced, 8x2 ISA style regs) nBE[3:0] = 1100
        ;         NIC:0C0 - 0FF (Alias of 080 - 0BF)
        ; LANDATA NIC:100 - 17F (HW wide, W spaced, bankless 16b access to 'DATA' reg)
        ; Nothing NIC:180 - 1FF
        ; LANLO   NIC:200 - 23F (HW wide, DW spaced, low byte view of LANC111 regs 0xFFLL) nBE[3:0] = 1110
        ;         NIC:240 - 27F (Alias of 200 - 23F)
        ; LANHI   NIC:280 - 2BF (HW wide, DW spaced, high byte view of LANC111 regs 0xHHFF) nBE[3:0] = 1101
        ;         NIC:2C0 - 2FF (Alias of 280 - 2BF)
        ; Nothing NIC:300 - 3FF
        
        EXPORT  bus_read_1
        EXPORT  bus_read_2
        EXPORT  bus_read_4
        EXPORT  bus_read_multi_2
        EXPORT  bus_read_multi_4

        EXPORT  bus_write_1
        EXPORT  bus_write_2
        EXPORT  bus_write_4
        EXPORT  bus_write_multi_2
        EXPORT  bus_write_multi_4
                
        AREA    bus, PIC, CODE

        ; uint8_t bus_read_1(uintptr_t base, uintptr_t offset)
bus_read_1 ROUT
        MOVS    r0, r0, LSL #1
        BCS     bus_read_1_nic
        LDRB    r0, [r0, r1]
        MOV     pc, lr
bus_read_1_nic
        ADD     r0, r0, r1, LSL #2
        TST     r1, #1
        LDREQB  r0, [r0, #&180]         ; Even => LANLO
        ADDNE   r0, r0, #&200           ; Odd => LANHI
        LDRNEB  r0, [r0, #1]
        MOV     pc, lr

        ; uint16_t bus_read_2(uintptr_t base, uintptr_t offset)
bus_read_2 ROUT
        MOVS    r0, r0, LSL #1
        BCS     bus_read_2_nic
        LDR     r0, [r0, r1]            ; Potentially unaligned load
        BIC     r0, r0, #&FF000000
        BIC     r0, r0, #&00FF0000
        MOV     pc, lr
bus_read_2_nic
        LDR     r0, [r0, r1, LSL #2]
        BIC     r0, r0, #&FF000000      ; Top 16 bits undefined
        BIC     r0, r0, #&00FF0000
        MOV     pc, lr

        ; uint32_t bus_read_4(uintptr_t base, uintptr_t offset)
bus_read_4 ROUT
        MOVS    r0, r0, LSL #1          
        LDRCC   r0, [r0, #&100]         ; For EASI interface only
        MOV     pc, lr

        ; void bus_read_multi_2(uintptr_t base, uintptr_t offset, uint16_t *buffer, size_t amount)
bus_read_multi_2 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
        MOVS    r0, r0, LSL #1
        BCS     bus_read_multi_2_nic
10
        LDR     r12, [r0, r1]           ; Potentially unaligned load
        STRB    r12, [r2], #1
        MOV     r12, r12, LSR #8
        STRB    r12, [r2], #1           ; Avoid STRH on IOMD
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr
bus_read_multi_2_nic
10
        LDR     r12, [r0, r1, LSL #2]
        STRB    r12, [r2], #1
        MOV     r12, r12, LSR #8
        STRB    r12, [r2], #1           ; Avoid STRH on IOMD
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        ; void bus_read_multi_4(uintptr_t base, uintptr_t offset, uint32_t *buffer, size_t amount)
bus_read_multi_4 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
        MOVS    r0, r0, LSL #1
        MOVCS   pc, lr                  ; For EASI interface only
10
        LDR     r12, [r0, #&100]        ; Offset to 'LANDATA' from base
        STR     r12, [r2], #4
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        ; void bus_write_1(uintptr_t base, uintptr_t offset, uint8_t value)
bus_write_1 ROUT
        MOVS    r0, r0, LSL #1
        BCS     bus_write_1_nic
        STRB    r2, [r0, r1]
        MOV     pc, lr
bus_write_1_nic
        ADD     r0, r0, r1, LSL #2
        TST     r1, #1
        STREQB  r2, [r0, #&180]         ; Even => LANLO
        ADDNE   r0, r0, #&200           ; Odd => LANHI
        STRNEB  r2, [r0, #1]
        MOV     pc, lr

        ; void bus_write_2(uintptr_t base, uintptr_t offset, uint16_t value)
bus_write_2 ROUT
        MOVS    r0, r0, LSL #1
        BCS     bus_write_2_nic
        STRB    r2, [r0, r1]!           ; Registers are halfword packed so can't use STR
        MOV     r2, r2, LSR #8
        STRB    r2, [r0, #1]
        MOV     pc, lr
bus_write_2_nic
        STR     r2, [r0, r1, LSL #2]
        MOV     pc, lr

        ; void bus_write_4(uintptr_t base, uintptr_t offset, uint32_t value)
bus_write_4 ROUT
        MOVS    r0, r0, LSL #1          
        STRCC   r0, [r0, r1]            ; For EASI interface only
        MOV     pc, lr

        ; void bus_write_multi_2(uintptr_t base, uintptr_t offset, const uint16_t *buffer, size_t amount)
bus_write_multi_2
        TEQ     r3, #0
        MOVEQ   pc, lr
        MOVS    r0, r0, LSL #1
        BCS     bus_write_multi_2_nic
        ADD     r0, r0, r1              ; Precalculate target
10
        LDR     r12, [r2], #2           ; Potentially unaligned load
        STRB    r12, [r0, #0]
        MOV     r12, r12, LSR #8
        STRB    r12, [r0, #1]           ; Byte addressable EASI interface
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr
bus_write_multi_2_nic
10
        LDR     r12, [r2], #2           ; Potentially unaligned load
        STR     r12, [r0, r1, LSL #2]
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        ; void bus_write_multi_4(uintptr_t base, uintptr_t offset, const uint32_t *buffer, size_t amount)
bus_write_multi_4 ROUT
        TEQ     r3, #0
        MOVEQ   pc, lr
        MOVS    r0, r0, LSL #1
        MOVCS   pc, lr                  ; For EASI interface only
10
        LDR     r12, [r2], #4
        STR     r12, [r0, #&100]        ; Offset to 'LANDATA' from base
        SUBS    r3, r3, #1
        BNE     %BT10
        MOV     pc, lr

        END
        