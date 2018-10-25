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

;This needs to write some patterns and check whether they are read
;back correctly.
;By checking at certain locations it should be possible to derive
;whether the addresses are mirrored because of unused address lines.
;It is important to be careful not to overwrite any extant code.
;This however should not be an issue, as anything outside the
;initially loaded area of the ROM should be relatively safe.

;Writing to &4FFFFFFC (256MiB - 4 bytes) and checking for mirrored
;data every 256MiB seems the most logical method.
;Or alternately instead of adding, just shift some bits to multiply.
;4GiB hasn't been added both because to my knowledge none exists,
;and the aarch64 BROM lives in the top of the 4GiB space.

    GET     Hdr:ListOpts
    GET     Hdr:Macros
    GET     Hdr:System
    GET     Hdr:OSEntries
    GET     hdr.AllWinnerH3
    GET     hdr.StaticWS

    EXPORT  ram_detector
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
    AREA    |Asm$$Code|, CODE, READONLY, PIC


ram_detector ROUT
;    Push  "a1-a4, lr"
    PUSH {a1-a4, lr}
    DebugTX "RAM Detector..."
    ;a4 = test pattern
    ;a3 = test address
    ;a2 = data from test address
    ;a1 =
    ;LDR   a4, [#vals, #0] ;TODO add post increment by 4
    LDR   a4, vals
    DebugReg a4, "vals = " ;= 000000aa so the next step is screwing me.
;    LDR   a4, [a4, #0] ;because we want the data stored in vals, not the address. REMOVED
    DebugReg a4, "vals now = "

;    LDR   a3, [addrs, #0];todo post increment etc. Is this right?
    ;FIXME!
    LDR   a3, addrs ;we have the address of addrs here.
    ;reference the macro in UART.s to fix this!
    ;addrs, offset 0 is 256MB. Where we want to write.
    ;I guess...
    LDR    a3, [a3, #0]
    ;now store a4 (val) to it.
    STR    a4, [a3, #0]
    ;now we need to check the values in addrs for mirroring.
    ;dirty hack for now because it's just test code.
    ;a3 still holds 256M value.
    DSB
    ISB
    LDR    a3, vals ;This should be fine.

    LDR    a2, [a3, #4] ;512MiB
    CMP    a2, a4 ;
    BEQ    %FT20 ; Mirrored at 512MiB so 256MiB
    LDR    a2, [a3, #8] ;Test 1GiB. Yes, I know I can increment.
    CMP    a2, a4
    BEQ    %FT30 ; 512MiB
    LDR    a2, [a3, #12]
    CMP    a2, a4
    BEQ    %FT40 ;1GiB
    B      %FT100
    ;Hold on there! Don't run this. Add value to list for 4Gib maybe?
    LDR    a2, [a3, #16]
    CMP    a2, a4
    BEQ    %FT50 ;2GiB
    B      %FT60 ;Unrecognised amount.

20  ;256MiB
    DebugTX "256MiB Detected."
    B      %FT100
30  ;512MiB
    DebugTX "512MiB Detected."
    B      %FT100
40  ;1GiB
    DebugTX "1GiB Detected."
    B      %FT100
50  ;2GiB
    DebugTX "2GiB Detected."
    B      %FT100
60
    DebugTX "Unrecognised RAM amount detected."
    ;plop
100
    ;exit

    POP {a1-a4, lr}
    ;Pull  "a1-a4, lr"
    MOV    pc, lr

vals
    DCD   &aa
    DCD   &55

addrs
    DCD   &4FFFFFFC     ;256M
    DCD   &5FFFFFFC     ;512M
    DCD   &7FFFFFFC     ;1G
    DCD   &BFFFFFFC     ;2G

    END
    