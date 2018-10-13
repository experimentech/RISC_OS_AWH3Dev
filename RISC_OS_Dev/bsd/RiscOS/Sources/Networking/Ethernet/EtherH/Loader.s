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
; Title:       Podule Loader code for EtherLan100 and 500 interface card
;                                 and EtherLan200
; Author:      Douglas J. Berry
; File:        Loader.s
;
; Copyright (C) 1995 i-cubed ltd
; Copyright (C) 2000 Design IT
;
;***************************************************************************

                GET     Hdr:ListOpts
                GET     Hdr:Macros
                GET     Hdr:System
                GET     Hdr:EnvNumbers
                GET     Hdr:Podule

                AREA    loader,CODE,READONLY

NumChunks       *       1
LoaderOffset    *       8+8+(NumChunks*8)+4     ; Assumes only 1 chunk directory.

;; The loader begins with four entry points

Loader          B       Read                    ; Read byte at virtual address R1 to R0
                B       Write                   ; Write byte R0 at virtual address R1
                B       Reset                   ; Reset to initial state
                MOV     pc,lr                   ; Call loader - NOT implemented
                DCB     "32OK"                  ; Is 32 bit compatible

;; Read entry
;;
;; On entry     R1   Address to read
;;              R11  Base of synchronous ROM space
;; On exit      R0   Returned data
;;
;; The first call made to a loader will always be Read[0]

Read            Push    "r11,lr"                ; Save return address
                ASSERT  Podule_BaseAddressBICMask = &3FF
                MOV     r14,#&FF
                ORR     r14,r14,#&300
                BIC     r11,r11,r14             ; Clear out CMOS address
                ADD     r2,r1,#LoaderSize       ; Add header size to get real address
                MOV     r3,r2,LSR#9             ; 512 byte page size
                CMP     r3,#1024                ; Page number valid?
                BCS     AddressIsTooBig
                MOV     r0,r3,LSR#8             ; Get top 2 bits for 4M bit devices.
              [ Loader24
                ; Register for EtherLan200
                MOV     r0,r0,LSL#2             ; Put in bits 2 and 3.
                STRB    r3,[r11,r0]             ; Write to page register.
                BIC     r2,r2,r3,LSL#9          ; Get offset into page
              |
                ; Register for EtherLan100 and EtherLan500
                MOV     r0,r0,LSL#10            ; Put in bits 10 and 11.
                STRB    r3,[r11]                ; Write to page register.
                BIC     r2,r2,r3,LSL#9          ; Get offset into page
                ADD     r2,r2,r0                ; Add in bits 10 and 11.
              ]
                LDRB    r0,[r11,r2,LSL#2]       ; Get byte
                MOV     r3,#0                   ; Clear page register.
                STRB    r3,[r11]                ; Write to page register.
                Pull    "r11,lr"                ; Return to caller
                RETURNVC

AddressIsTooBig
                ADR     r0,ErrorATB             ;
                Pull    "r11,lr"                ; Fetch return address
                RETURNVS                        ; Return with error

ErrorATB        DCD     0
                DCB     "Address too big", 0
                ALIGN


;; Write byte - can't write to ROM!

Write           ADR     r0,ErrorWrite           ; Address error block
                RETURNVS                        ; Return setting error indication

ErrorWrite      DCD     0
                DCB     "ROM not writeable",0
                ALIGN

;; Reset
;;
;; Set page to zero
;;
;; Assumes writing to ROM page register enabled.

Reset           MOV     r3,#0                   ; Select page
                Push    "r11,lr"                ; Save registers
                ASSERT  Podule_BaseAddressBICMask = &3FF
                MOV     r14,#&FF
                ORR     r14,r14,#&300
                BIC     r11,r11,r14             ; Remove CMOS RAM pointer if present
                STRB    r3,[r11]                ; Write D0
                Pull    "r11,lr"
                RETURNVC

LoaderSize      *       {PC}-Loader+LoaderOffset

                END
