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


     GET     Hdr:ListOpts
     GET     Hdr:Macros
     GET     Hdr:System
     GET     Hdr:OSEntries
;     GET     Hdr:Machine.<Machine>
;     GET     Hdr:ImageSize.<ImageSize>



    GET     hdr.AllWinnerH3
    GET     hdr.StaticWS
    GET     hdr.Registers    ;might not need this
 [ Debug
    GET     Debug
    IMPORT  HAL_DebugTX
    IMPORT  HAL_DebugRX
    IMPORT  DebugHALPrint
    IMPORT  DebugHALPrintReg
    IMPORT  DebugMemDump
    IMPORT  DebugHALPrintByte
    IMPORT  DebugCallstack
 ]




;This file is for the lower level handling of the processor IO pads.
    AREA    |ARM$$code|, CODE, READONLY, PIC

;--------------------------------------------------------------
;void     SetPadMode (uint32_t port, uint32_t pad, uint32_t mode);
;--------------------------------------------------------------

SetPadMode
    ;just borrowing v1 for now.
    Push "a4, v1, lr"
    ;I guess take the number and feed it through the algorithm
    ;in the datasheet.
    ;WHAT AM I DOING???
    ;Px configure register n
    ;Pn_CFG0 = n*0x24+0x00
    ;Pn_CFG1 = n*0x24+0x04
    ;Pn_CFG2 = n*0x24+0x08
    ;Pn_CFG3 = n*0x24*0x0C
    ;We need to work out which REGISTER the PAD belongs to.
    ;THEN we need to work out which BITS of the REGISTER need to
    ;be fiddled. Got it?
    ;
    ;Pn_CFG0 = (n * 0x24) + 0x00


    ;mul by 24. (n << 5) + 4? hmm. no.
    ; n is port (a1)
    ;so this gives us port and reg. Not the pad.
    ;Pn_CFGx = (n * 0x24) + x << 2
    ;a1 port
    ;a2 pad
    ;a3 mode
    ;PIO_BaseAddr

    ;Step 1. Which register do we need?
    ;*Each port has 4 CFG registers.
    ;*Each port (not register) has 32 pads (maximum)  ???
    ;*Each pad has 3 bits + 1 empty. So 4 bits logically.
    ;
    ; n << 2 to find nybble offset from Pn_CFGx
    ;That could be dangerous on it's own.
    ;Maybe use mask and shift to get word address for which register.
    ;or a divide or something. Hopefully not.

    ; Work out Pn_CFG0 from n * 0x24 //+ 0x00
    ; n being numerical representation of port letter. A = 0, B = 1 etc.
    ;mask and split at 5 bits? max 31
    ;bits above can be shifted back to 0 for word offset
    ;Just do a read, modify, write.
    ;Port L needs special handling. In different address range.
    ;MOV   a4, #&24
    ;MLA   a4, a1, a4

    ;bit shift desired pad number right by 3 to get word (register)number.
    ;8 pads per reg. 32 / 8 = 4
    ;4 bits per reg. so n = (pad# / 4) -1 to find reg # I guess?
    ; n = (pad# >> 2) -1

    ;use a4 for scratch
    MOV    a4, a2 >> 1
    BIC    a4, a4, #2_11

    ;a4 = byte offset of pad.
    ;v1 = word offset of pad.
    MOV    v1, a2 >> 1
    BIC    v1, v1, #2_111111
    ;a4 /should/ have byte offset of the config register now.
    ; mask 5:0 to get word only?
    ;Putting 5:0 and <5 into their own registers may be beneficial.
    LDR


    ;MOV   a4, a2 >> 4
    ;SUB   a4, a4, #1
    ;a4 now holds the number of req'd CFG reg;
    ;hold on. Leave it as is and I have a word offset.
    ;FIXME. Just BIC bits 2:0 in a4.


    LDR   a4, PIO_BaseAddr

    Pull "a4, v1, lr"
    MOV   pc, lr


;--------------------------------------------------------------
;uint32_t GetPadMode (uint32_t port, uint32_t pad);
;--------------------------------------------------------------
GetPadMode
    Push "lr"

    Pull "lr"
    MOV   pc, lr

;--------------------------------------------------------------
;void     SetPadData (uint32_t port, uint32_t pad, uint32_t drv);
;--------------------------------------------------------------
SetPadData
    Push "lr"


    Pull "lr"
    MOV   pc, lr

;--------------------------------------------------------------
;uint32_t GetPadData (uint32_t port, uint32_t pad);
;--------------------------------------------------------------
GetPadData
    Push "lr"

    Pull "lr"
    MOV   pc, lr


    END

