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

;Video.s
;Stubs. Don't get excited.
        GET     hdr.Video

        AREA    |Asm$$Code|, CODE, READONLY, PIC

;----------------------------------------------------------------------
HAL_VideoFlybackDevice
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoSetMode
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoWritePalleteEntry
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoWritePalleteEntries
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoReadPalleteEntry
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoSetInterlace
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoSetBlank
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoSetPowerSave
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoSetDAG
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoVetMode
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoPixelFormats
        MOV a1, #MODE_8BPP | MODE_16BPP | MODE_32BPP
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoFeatures
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoBufferAlignment
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoOutputFormat
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoRender
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoIICOp
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoFramestoreAddress
        ;the docs are not good for this.
        LDR a1, =FB_START
        LDR a2, =FB_SIZE
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoStartupMode
        MOV pc, lr
;----------------------------------------------------------------------
HAL_VideoPixelFormatList
        MOV pc, lr
;----------------------------------------------------------------------




        END
        
