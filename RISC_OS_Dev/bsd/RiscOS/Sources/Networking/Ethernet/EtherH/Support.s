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
; Assembler helper functions

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Services

        EXPORT  eh_microdelay
        EXPORT  eh_call_protocol
        EXPORT  eh_call_back

        AREA    Support,CODE,READONLY

;**********************************************************************
;
;       implement an n-microsecond delay: this code assumes the card
;       is set to Podule_Speed_TypeA and will do dummy reads from
;       a location that has no side effects.
;       For 'fast' podules this is 5 cycles of 8MHz => 625ns
;       For 'easi/nic' this is 9 cycles of 16MHz => 562ns
;       so two dummy reads will ensure at least 1us per loop.
;
;       void eh_microdelay(int micros, const char *rom);
;
eh_microdelay ROUT
        TEQ     r0, #0
        TEQNE   r1, #0
        MOVEQ   pc, lr                  ; Duff caller
10
        LDRB    r2, [r1]
        LDRB    r2, [r1]
        SUBS    r0, r0, #1
        BNE     %BT10
        MOV     pc, lr

;**********************************************************************
;
;       void eh_call_protocol(DibRef, struct mbuf *, void *, int);
;

eh_call_protocol ROUT
        Push    "r12, lr"
        MOV     r12, r2
        MOV     lr, pc
        MOV     pc, r3
        Pull    "r12, pc"

;**********************************************************************
;
;       eh_call_back r12 -> pointer to Dib for device starting
;

eh_call_back ROUT
        Push    "r0-r3, lr"
        MOV     r0, r12
        MOV     r1, #Service_DCIDriverStatus
        MOV     r2, #0                  ; DCIDRIVER_STARTING
        LDR     r3, =406                ; DCIVERSION
        SWI     XOS_ServiceCall
        TEQ     pc, pc
        Pull    "r0-r3, pc", EQ
        Pull    "r0-r3, pc", NE, ^      ; Don't confuse a 26 bit OS

        END
