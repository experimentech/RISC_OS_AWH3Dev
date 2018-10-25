;
; Copyright (c) 2012, RISC OS Open Ltd
; Copyright (c) 2012, Adrian Lees
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
; With many thanks to Broadcom Europe Ltd for releasing the source code to
; its Linux drivers, thus making this port possible.
;

        AREA    |ARM$$data|, CODE, READONLY, PIC

        GET     Hdr:ListOpts
        GET     Hdr:HALEntries
        GET     Hdr:OSEntries

        GET     StaticWS


        EXPORT  HAL_NVMemoryType
        EXPORT  HAL_NVMemorySize
        EXPORT  HAL_NVMemoryPageSize
        EXPORT  HAL_NVMemoryProtectedSize
        EXPORT  HAL_NVMemoryProtection
        EXPORT  HAL_NVMemoryRead
        EXPORT  HAL_NVMemoryWrite

HAL_NVMemoryType
        ; HAL provides calls to access NVMemory, physical locations 0-15 are read/write
        LDR     a1, =NVMemoryFlag_HAL :OR: NVMemoryFlag_LowRead :OR: NVMemoryFlag_LowWrite
        MOV     pc,lr

HAL_NVMemorySize
        MOV     a1,#?SimulatedCMOS - 4  ; Less the version word
        MOV     pc,lr

HAL_NVMemoryPageSize
        MOV     a1,#16                  ; Simulation doesn't really have a concept of pages
        MOV     pc,lr

HAL_NVMemoryProtectedSize
        MOV     a1,#0
        MOV     pc,lr

HAL_NVMemoryProtection
        MOV     pc,lr

HAL_NVMemoryRead ROUT
        ; a1 = physical address
        ; a2 = buffer
        ; a3 = number of bytes requested
        ; Returns a1 = number of bytes read
        ADR     ip,SimulatedCMOS
        ADD     ip,ip,a1
        MOVS    a1,a3
10      LDRNEB  a4,[ip],#1
        STRNEB  a4,[a2],#1
        SUBNES  a3,a3,#1
        BNE     %BT10
        MOV     pc,lr

HAL_NVMemoryWrite ROUT
        ; a1 = physical address
        ; a2 = buffer
        ; a3 = number of bytes to do
        ; Returns a1 = number of bytes written
        ADR     ip,SimulatedCMOS
        ADD     ip,ip,a1
        MOVS    a1,a3
10      LDRNEB  a4,[a2],#1
        STRNEB  a4,[ip],#1
        SUBNES  a3,a3,#1
        BNE     %BT10
        MOV     pc,lr

        END
