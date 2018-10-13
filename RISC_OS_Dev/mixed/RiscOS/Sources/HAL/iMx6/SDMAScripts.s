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
; Copyright (c) 2014, RISC OS Open Ltd
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

        GET     hdr.SDMAAsm

        EXPORT  sdma_scriptbase
        EXPORT  sdma_scriptend
        EXPORT  sdma_rectfill
        EXPORT  sdma_rectcopy

; We get loaded into SDMA RAM at program address &1800
s_baseaddr * . - &1800*2

sdma_scriptbase

sdma_rectfill   ROUT
        ; R1 = rect width (bytes, > 0)
        ; R2 = rect height (lines, > 0)
        ; R3 = dest addr
        ; R4 = row stride
        ; R5 = fill value
        ; Set address, mode
        s_stf   r3, stf_MDA
      [ {FALSE} ; Loop unrolling doesn't help, limiting factor appears to be the SDMA's interface to main memory
        ; Get width in 8 word bursts
        s_mov   r0, r1
        s_lsr1  r0
        s_lsr1  r0
        s_mov   r7, r0
        s_lsr1  r0
        s_lsr1  r0
        s_lsr1  r0
        ; Transfer bursts
        s_loop  l01
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_stf   r5, stf_MD_SZ32
        s_yield
l01
        ; Transfer words
        s_mov   r0, r7
        s_andi  r0, 7
        s_loop  l10
        s_stf   r5, stf_MD_SZ32
        s_yield
      |
        ; Get width in words
        s_mov   r0, r1
        s_lsr1  r0
        s_lsr1  r0
        ; Transfer words
        s_loop  l10
        s_stf   r5, stf_MD_SZ32
        s_yield
      ]
l10
        ; Transfer halfword
        s_tsti  r1, 2
        s_bf    l20
        s_stf   r5, stf_MD_SZ16
l20
        ; Transfer byte
        s_tsti  r1, 1
        s_bf    l30
        s_stf   r5, stf_MD_SZ8
l30
        ; Flush FIFO
        s_stf   r0, stf_MD_SZ0_FL
        ; Wait
        s_ldf   r0, ldf_MS
        s_yield
        ; Next row
        s_add   r3, r4
        s_subi  r2, 1
        s_bf    sdma_rectfill
        s_done  3
        s_jmp   sdma_rectfill ; ???

sdma_rectcopy
        ; R1 = rect width (bytes, > 0)
        ; R2 = rect height (lines, > 0)
        ; R3 = dest addr
        ; R4 = dest row stride
        ; R5 = src addr
        ; R6 = src row stride
        ; Load magic constant
        s_ldi   r7, 8
l40
        ; Set address, mode
        s_stf   r3, stf_MDA
        s_stf   r5, stf_MSA
        ; Get width in words
        s_mov   r0, r1
        s_lsr1  r0
        s_lsr1  r0
        ; Transfer bursts
l50
        s_cmphs r0, r7
        s_bf    l60
        s_stf   r7, stf_MD_CPY
        s_subi  r0, 8
        s_yield
        s_jmp   l50
l60
        ; Transfer remainder
        s_stf   r0, stf_MD_CPY
        ; Transfer halfword
        s_tsti  r1, 2
        s_bf    l70
        s_ldf   r0, ldf_MD_SZ16
        s_stf   r0, stf_MD_SZ16_FL
l70
        ; Transfer byte
        s_tsti  r1, 1
        s_bf    l80
        s_ldf   r0, ldf_MD_SZ8
        s_stf   r0, stf_MD_SZ8_FL
l80
        ; Ensure any preceeding FIFO flush is complete
        s_ldf   r0, ldf_MS
        s_yield
        ; Next row
        s_add   r3, r4
        s_add   r5, r6
        s_subi  r2, 1
        s_bf    l40
        s_done  3
        s_jmp   sdma_rectcopy ; ???

sdma_scriptend

        ALIGN

        END
