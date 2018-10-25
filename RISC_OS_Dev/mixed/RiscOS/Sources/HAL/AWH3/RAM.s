;Copyright (c) 2017, Tristan Mumford
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

        GET      hdr.AllWinnerH3
        EXPORT   clear_ram
; Using the DMA controller to clear RAM is much faster than doing it with the CPU (with the cache/write buffer off, at least)
                 GBLL Use_DMA_Clear
Use_DMA_Clear    SETL {FALSE}

         AREA    |Asm$$Code|, CODE, READONLY, PIC


;What does the proper clear_ram use for params?

;a1 = start of hal. top? comes from v5
;perhaps bottom is the bottom of RAM
;a1 is the top
;a2 is the bottom
clear_ram
     PUSH {a3}
     MOV a3, #0
     ;LDR a2, =SDRAM
10
     ;incrememnts and zeroes address of a2, which is incremented.
     ;very slow but equally simple.
     STR a3,[a2], #4
     CMP a2, a1
     BNE %BT10
     POP {a3}
     MOV pc, lr

     END
