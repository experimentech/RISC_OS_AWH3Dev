; Copyright (c) 2002, Design IT
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
;**************************************************************************
; Title:       Heron Ethernet Driver Source
; Author:      Douglas J. Berry
; File:        eh_io.s
;
; Copyright (C) 1992 PSI Systems Innovations
; Copyright (C) 2000 Design IT
;
;***************************************************************************

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System

        EXPORT  eh_io_out
        EXPORT  eh_io_in

        AREA    io_etherlan,CODE,READONLY

;**********************************************************************
;
;       Copy nbytes from src out to 8-bit I/O port at dst.
;
;       No restrictions on source buffer alignment or size of transfer.
;
;       Comments;
;       Fairly optimal. Each byte requires an access to external memory.
;       Could be better to assemble bytes into words in register and then
;       send. However then have to start worrying about buffer alignment
;       and odd length transfers.
;
;       void eh_io_out(u_char *src, u_int *dst, int nbytes)
;
eh_io_out ROUT

        Push    "r4, lr"

        ANDS    r4, r2, #7
        BEQ     lpout2

lpout1  LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        SUBS    r4, r4, #1              ; Decrement byte count.
        BNE     lpout1

lpout2  MOVS    r2, r2, LSR #3
        BEQ     lpoend

lpout3  LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.

        SUBS    r2, r2, #1              ; Decrement byte count.
        BNE     lpout3

        ; Finished.
lpoend
        Pull    "r4, pc"

;
; Slow version.
;
seh_io_out ROUT

lpouts1 LDRB    r3, [r0], #1            ; Read byte from buffer and increment address.
        STRB    r3, [r1]                ; Write to DMA port.
        SUBS    r2, r2, #1              ; Decrement byte count.
        BNE     lpouts1

        MOV     pc, lr

;**********************************************************************
;
;       Transfer data from 8-bit DMA port at src to dst.
;       nbytes is always rounded up to the nearest whole number
;       of half words.
;
;       No restrictions on dst buffer alignment or size of transfer.
;
;       Comments;
;       Fairly optimal.
;
;       void eh_io_in(u_int *src, u_char *dst, int nbytes)
;
;
eh_io_in ROUT

        Push    "r4-r6, lr"

        ANDS    r4, r1, #3
        BEQ     lpin2

        ; Get *dst on a word boundary.
        SUB     r2, r2, r4              ; r2 = r2 - r4
lpin1   LDR     r3, [r0]                ; Read DMA port.
        STRB    r3, [r1], #1            ; Store byte and increment address pointer.
        SUBS    r4, r4, #1              ; Decrement byte count.
        BNE     lpin1

        ; r1 (= *dst) now on a word boundary.
lpin2   AND     r4, r2, #7              ; r4 = nbytes % 8
        MOVS    r2, r2, LSR #3          ; r2 = nbytes / 8
        BEQ     lpirem

lpin3   LDRB    r5, [r0]                ; Read DMA port.
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r5, r5, r3, LSL #8
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r5, r5, r3, LSL #16
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r5, r5, r3, LSL #24

        LDRB    r6, [r0]                ; Read DMA port.
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r6, r6, r3, LSL #8
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r6, r6, r3, LSL #16
        LDRB    r3, [r0]                ; Read DMA port.
        ADD     r6, r6, r3, LSL #24

        STMIA   r1!,{r5-r6}
        SUBS    r2, r2, #1              ; Decrement byte count.
        BNE     lpin3

        ; Now do remainder.
lpirem  MOVS    r4, r4
        BEQ     lpiend

lpin4   LDR     r3, [r0]                ; Read DMA port.
        STRB    r3, [r1], #1            ; Store byte and increment address pointer.
        SUBS    r4, r4, #1              ; Decrement byte count.
        BNE     lpin4

        ; Finished.
lpiend
        Pull    "r4-r6, pc"

;
; Slow version.
;
seh_io_in ROUT

lpins1  LDR     r3, [r0]                ; Read DMA port.
        STRB    r3, [r1], #1            ; Store byte and increment address pointer.
        SUBS    r2, r2, #1              ; Decrement byte count.
        BNE     lpins1

        MOV     pc, lr

        END

;       /* EOF Eh_io.s */
