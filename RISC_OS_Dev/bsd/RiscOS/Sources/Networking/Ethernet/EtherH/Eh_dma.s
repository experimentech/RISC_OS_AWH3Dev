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
; Title:       Ethernet Driver Source
; Author:      Gary Stephenson
; File:        dma.s
;
; Copyright (C) 1995 Network Solutions
; Copyright (C) 2000 Design IT
;
;***************************************************************************

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System

        EXPORT  eh_enable_dma
        EXPORT  eh_disable_dma
        EXPORT  eh_start_dma
        EXPORT  eh_completed_dma
        EXPORT  eh_sync_dma

        IMPORT  completed_dma_entry

        AREA    exit_control,CODE,READONLY

;   **********************************************************************
;

eh_enable_dma ROUT

        Push    "r0-r11, lr"            ; On some stack

        MRS     r9, CPSR
        BIC     r8, r9, #2_1111
        ORR     r8, r8, #2_0011         ; For SVC26 or SVC32 as appropriate
        MSR     CPSR_c, r8
        Push    "r9, lr"                ; On SVC stack

        ;SWI    XOS_WriteS
        ;= "Enable DMA ",0
        ;ALIGN

        ! 0,    "There's no need to change mode just to poke ctrl_reg"
        LDR     r0, [r11, #4]           ; get address of ctrl_reg
        MOV     r1, #3
        STRB    r1, [r0]                ; write ENABLE_DMA to enable DMA

        Pull    "r9, lr"
        MSR     CPSR_cf, r8

        TEQ     pc, pc
        Pull    "r0-r11, pc", EQ
        Pull    "r0-r11, pc", NE, ^     ; Don't confuse 26 bit DMA manager

;   **********************************************************************
;

eh_disable_dma ROUT
        MOV     pc, lr

;   **********************************************************************
;

eh_start_dma ROUT
        MOV     pc, lr

;   **********************************************************************
;

eh_completed_dma ROUT

        Push    "r0-r3, r12, lr"
        MOV     r0, r11
        BL      completed_dma_entry
        TEQ     pc, pc
        Pull    "r0-r3, r12, pc", EQ
        Pull    "r0-r3, r12, pc", NE, ^ ; Don't confuse 26 bit DMA manager

;   **********************************************************************
;

eh_sync_dma ROUT
        MOV     pc, lr

        END

;       /* EOF dma.s */
