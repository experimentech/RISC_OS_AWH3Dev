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
        
