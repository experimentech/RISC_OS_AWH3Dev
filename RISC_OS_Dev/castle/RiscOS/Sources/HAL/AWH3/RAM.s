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

;Gutted version of OMAP3 RAM.s

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
