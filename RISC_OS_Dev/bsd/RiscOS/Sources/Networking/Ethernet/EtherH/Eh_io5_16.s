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
; File:        eh_io5_16.s
;
; Copyright (C) 1993 i-cubed Ltd
; Copyright (C) 2000 Design IT
;
;***************************************************************************


        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        
        EXPORT  eh_io_in
        EXPORT  eh_io_out_5
        EXPORT  eh_io_hout_5
        EXPORT  eh_flush_output_5
        
        AREA    io_etherlan500,CODE,READONLY

oddbyte         *       &100    ; Flags whether byte buffer is occupied

;**********************************************************************
;
;       copy packet header from src out to I/O port at dst
;
;       void eh_io_hout_5(u_char *src1, u_char src2, int type, u_int *dst)
;

eh_io_hout_5 ROUT
        Push    "r4-r10, lr"

        LDRB    r4, [r0]
        LDRB    r5, [r0, #1]
        ADD     r5, r4, r5, LSL #8
        MOV     r5, r5, LSL#16

        LDRB    r4, [r0, #2]
        LDRB    r6, [r0, #3]
        ADD     r6, r4, r6, LSL #8
        MOV     r6, r6, LSL#16

        LDRB    r4, [r0, #4]
        LDRB    r7, [r0, #5]
        ADD     r7, r4, r7, LSL #8
        MOV     r7, r7, LSL#16

        LDRB    r4, [r1]
        LDRB    r8, [r1, #1]
        ADD     r8, r4, r8, LSL #8
        MOV     r8, r8, LSL#16

        LDRB    r4, [r1, #2]
        LDRB    r9, [r1, #3]
        ADD     r9, r4, r9, LSL #8
        MOV     r9, r9, LSL#16

        LDRB    r4, [r1, #4]
        LDRB    r10, [r1, #5]
        ADD     r10, r4, r10, LSL #8
        MOV     r10, r10, LSL#16

        STMIA   r3, {r5-r10}
        MOV     r2, r2, LSL#16
        STR     r2, [r3]

        ; finished

        Pull    "r4-r10, pc"

;**********************************************************************
;
;       copy nbytes from src out to I/O port at dst
;
;       void eh_io_out_5(u_char *src, u_int *dst, int nbytes, u_int *bytebuf)
;

eh_io_out_5 ROUT
        Push    "r4-r10, lr"

        ; calculate how many single byte transfers are required
        ; to word align the source ADDress, skip if zero
        MOV     r12, r2
        MVN     r2, r0
        ADD     r2, r2, #5
        ANDS    r2, r2, #3
        BEQ     l0

        ; make sure that no. to align is <= total transfer count, then
        ; MOVe data across & decrement xfer count
        CMP     r2, r12
        MOVGT   r2, r12
        BL      byte_output
        SUB     r12, r12, r2

        ; calculate no. of 16 byte block transfers required
l0      MOVS    r2, r12, LSR #4
        BEQ     l2

        ; transfer as many bytes as possiBLe using load/store multiple routines;
        ; decide which block transfer routine to call: dependant upon whether
        ; or not there is an odd byte ouTSTanding
        LDR     r4, [r3]
        TST     r4, #oddbyte
        BNE     l1
        BL      even_block_output
        B       l2
l1
        BL      odd_block_output

        ; now transfer remaining bytes oNE at a time
l2      ANDS    r2, r12, #&0f
        BLNE    byte_output

        ; finished
        Pull    "r4-r10, pc"

;**********************************************************************
;
;       flush any odd byte remaining at end of transfer
;
;       void eh_flush_output_5(u_int *dst, u_int *bytebuf)
;
eh_flush_output_5 ROUT

        LDR     r1, [r1]
        TST     r1, #oddbyte
        MOVEQ   pc, lr
        BIC     r1, r1, #oddbyte
        ORR     r1, r1, r1, LSL #8
        MOV     r1, r1, LSL #16
        STR     r1, [r0]
        MOV     pc, lr

;**********************************************************************
;
;       transfer bytes from src (incremented) to 16-bit DMA port
;       at dst. must return with byte count preserved in r2
;
;       void byte_output(u_char *src, u_int *dst, int nbytes, u_char *bytebuf)
;
byte_output  ROUT
        LDR     r6, [r3]
        MOV     r4, #0

l01     CMP     r4, r2
        STREQ   r6, [r3]
        MOVEQ   pc, lr

        ; increment byte count, then get NExt src byte into r5. test to
        ; see whether we already have an odd byte
        ADD     r4, r4, #1
        LDRB    r5, [r0], #1
        TST     r6, #oddbyte

        ; no - mark as odd byte & repeat the loop
        ORREQ   r6, r5, #oddbyte
        BEQ     l01

        ; already have an odd byte - clear oddbyte marker,
        ; build 1/2 word & write it out
        BIC     r6, r6, #oddbyte
        ORR     r5, r6, r5, LSL #8
        MOV     r5, r5, LSL #16
        STR     r5, [r1]

        ; repeat the loop
        B       l01

;**********************************************************************
;
;       transfer 16 byte blocks of data to `aligNEd' destination
;       DMA port
;
;       void even_block_output(u_char *src, u_int *dst, int niterations)
;

even_block_output ROUT
        Push    "r3, lr"

        ; transfer NExt block
l02     LDMIA   r0!, {r3-r6}

        MOV     r10, r6
        MOV     r9, r6, LSL #16

        MOV     r8, r5
        MOV     r7, r5, LSL #16

        MOV     r6, r4
        MOV     r5, r4, LSL #16

        MOV     r4, r3
        MOV     r3, r3, LSL #16
        STMIA   r1, {r3-r10}

        ; decrement & test loop counter
        SUBS    r2, r2, #1
        BNE     l02

        ; finished
        Pull    "r3, pc"

;**********************************************************************
;
;       transfer 16 byte blocks of data to `non-aligNEd' destination
;       DMA port
;
;       void odd_block_output(u_char *src, u_int *dst, int niterations, u_int *bytebuf)
;

odd_block_output ROUT
        Push    "r11-r12, lr"

        ; load buffered byte & clear extraNEous bits from it
        STR     r3, [sp, #-4]!
        LDR     r3, [r3]
        AND     r3, r3, #&ff

        ; load NExt data block & preserve byte to be buffered
l03     LDMIA   r0!, {r4-r7}
        MOV     r11, r7, LSR #24

        ; shuffle data ready for transfer to 16-bit I/O space
        MOV     r12, r7, LSL #8
        MOV     r10, r7, LSL #24
        ORR     r10, r10, r6, LSR #8

        MOV     r9, r6, LSL #8
        MOV     r8, r6, LSL #24
        ORR     r8, r8, r5, LSR #8

        MOV     r7, r5, LSL #8
        MOV     r6, r5, LSL #24
        ORR     r6, r6, r4, LSR #8

        MOV     r5, r4, LSL #8
        MOV     r4, r4, LSL #24
        ORR     r4, r4, r3, LSL #16

        ; write this out & update byte buffer
        STMIA   r1, {r4-r10, r12}

        MOV     r3, r11

        ; decrement & test loop counter
        SUBS    r2, r2, #1
        BNE     l03

        ; reset marker in buffered byte, save it away then return
        ORR     r4, r3, #oddbyte
        LDR     r3, [sp], #4
        STR     r4, [r3]
        Pull    "r11-r12, pc"

;**********************************************************************
;
;       transfer data from 16-bit DMA port at src to dst. nbytes is always
;       rounded up to the NEarest whole number of half words.
;
; NOTE:
;
;       this routiNE will only work if the caller can ensure that only the
;       last call has an odd value for nbytes (data is not buffered between
;       calls)
;
;       void eh_io_in(u_int *src, u_char *dst, int nbytes)
;
eh_io_in ROUT
        Push    "r4-r10, lr"

        ; adjust nbytes if NEcessary & calculate no. of 16 byte block
        ; transfers rEQuired
        TST     r2, #1
        MOVEQ   r12, r2
        ADDNE   r12, r2, #1
        MOVS    r2, r12, LSR #4
        BLNE    even_block_input

        ; now transfer remaining data as single bytes
        ANDS    r2, r12, #&0f
        BLNE    byte_input

        ; finished
        Pull    "r4-r10, pc"

;**********************************************************************
;
;       transfer 1/2 words from DMA port at src to dst
;
;       void byte_input(u_int *src, u_char *dst, int nbytes)
;
byte_input ROUT

        ; divide byte counter by 2
        MOV     r2, r2, LSR #1

        ; transfer another 2 bytes (1/2 word)
l04     LDR     r3, [r0]
        STRB    r3, [r1], #1
        MOV     r3, r3, LSR #8
        STRB    r3, [r1], #1

        ; decrement counter & repeat loop
        SUBS    r2, r2, #1
        BNE     l04

        ; finished
        MOV     pc, lr

;**********************************************************************
;
;       transfer 16 byte blocks of data from 16-bit DMA port at src
;       to dst
;
;       void even_block_input(u_int *src, u_char *dst, int niterations)
;

even_block_input ROUT
        Push    "r12, lr"
        MOV     r12, #&ff
        ORR     r12, r12, r12, LSL #8

        ; load another 16 bytes from DMA port then write them to
        ; main memory
l05     LDMIA   r0, {r3-r10}

        AND     r3, r3, r12
        ORR     r3, r3, r4, LSL #16

        AND     r5, r5, r12
        ORR     r4, r5, r6, LSL #16

        AND     r7, r7, r12
        ORR     r5, r7, r8, LSL #16

        AND     r9, r9, r12
        ORR     r6, r9, r10, LSL #16

        STMIA   r1!, {r3-r6}

        ; decrement & test loop counter
        SUBS    r2, r2, #1
        BNE     l05

        ; finished
        Pull    "r12, pc"

        END

;       /* EOF Eh_io5_16.s */
