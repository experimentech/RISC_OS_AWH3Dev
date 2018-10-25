;Copyright (c) 2018, Tristan Mumford
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

        AREA    |ARM$$code|, CODE, READONLY, PIC

;PIO_New
;void PIOinit(uint32_t* PIO_Base)

;void SetPadMode (uint32_t port, uint32_t pad, uint32_t mode)
SetPadMode

    MOV    a4, a2, LSR#4    ;regOffset = (pad >> 4)


    MOV    a2, a2, LSL#2    ;nybble it ; 	padOffset = pad << 2
    AND    a2, a2, #&1F     ;mask it   ;    padOffset &= 0x1F
    ;a2 = pad offset with mask.
    ;now for the register
    ;regOffset
    ;reuse port next
    ;I don't think UMULL can be used like this.
    UMULL  a1, a1, #&24    ; portOffset = (port * 0x24)...
    ADD    a1, a1, a4      ; + regOffset;

    AND    a3, a3, #2_111  ;mode sanitised
    ;a1 = portOffset (address. Includes regOffset)
    ;a2 = padOffset
    ;a3 = mode
    ;a4 = was regOffset, now regData
    ;Surely I could have just added regOffset and PortOffset???

;NO!
;    dataTmp ^= (~mode ^ dataTmp ) & (7 << regOffset);
;    dataTmp ^= (~mode ^ dataTmp ) & (#2_111 < padOffset)
    BIC    a4, a4, a3, LSL a2 ;should be fine?
;rough pseudocode
;(~mode
;NOT mode, mode
; ^ dataTmp )
;XOR dataTmp, dataTmp, mode
;(#2_111 << padOffset)
;LSH mode, mode, padOffset
;&
;AND dataTmp, dataTmp, mode

;that is so long and sloppy.
;just a rotated BIC and ORR should do it.

;    dataTmp ^=
;XOR dataTmp, dataTmp, abovestuff

    LDR    a4, [PIO_BaseAddr, a1]   ;TODO check whether PIO_Base is right.
    ;clear needed bits with BIC then ORR them in.
    ;DO STUFF
    STR    a4, [PIO_BaseAddr, a1]

;uint32_t GetPadMode (uint32_t port, uint32_t pad)

;void SetPadState (uint32_t port, uint32_t pad, uint32_t state)

;uint32_t GetPadState (uint32_t port, uint32_t pad)

    END
