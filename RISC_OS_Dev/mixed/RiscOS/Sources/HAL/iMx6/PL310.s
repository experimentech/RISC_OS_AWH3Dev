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
;
        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        $GetIO
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:HALDevice
        GET     Hdr:PL310

        GET     hdr.StaticWS
        GET     hdr.iMx6qMemMap
        GET     hdr.iMx6qIRQs

        EXPORT  PL310_InitDevice
        EXPORT  dmb_st

        IMPORT  memcpy


        MACRO
        CallOS  $entry, $tailcall
        ASSERT  $entry <= HighestOSEntry
 [ "$tailcall"=""
        MOV     lr, pc
 |
   [ "$tailcall"<>"tailcall"
        ! 0, "Unrecognised parameter to CallOS"
   ]
 ]
        LDR     pc, OSentries + 4*$entry
        MEND

; Basic PL310 HAL device

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        MACRO
        PL310Sync $regs, $temp
        MOV     $temp, #0
        STR     $temp, [$regs, #PL310_REG7_CACHE_SYNC]
10
        LDR     $temp, [$regs, #PL310_REG7_CACHE_SYNC]
        TST     $temp, #1
        BNE     %BT10
        MEND

PL310_InitDevice ROUT
        Push    "lr"

        ADRL    a1, PL310Device
        ADR     a2, PL310Template
        MOV     a3, #HALDeviceSize
        BL      memcpy

        ; Map in the PL310 registers
        MOV     a1, #0
        LDR     a2, =PL310_BASE_ADDR
        MOV     a3, #4096
        CallOS  OS_MapInIO
        ADRL    a2, PL310Device
        STR     a1, [a2, #HALDevice_Address]

        ; Register the device
        MOV     a1, #0
        CallOS  OS_AddDevice

        ; Leave the OS to decide when to enable it - it will need to be ready
        ; to start performing maintenance ops

        Pull    "pc"

PL310Template
        DCW     HALDeviceType_SysPeri + HALDeviceSysPeri_CacheC
        DCW     HALDeviceID_CacheC_PL310
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     0                       ; API version
        DCD     PL310Desc
        DCD     0                       ; Address - Filled in at runtime
        %       12                      ; Reserved
        DCD     PL310Activate
        DCD     PL310Deactivate
        DCD     PL310Reset
        DCD     PL310Sleep
        DCD     IMX_INT_CHEETAH_L2
        DCD     0
        %       8
        ASSERT  (.-PL310Template) = HALDeviceSize

PL310Desc
        DCB     "PL310 L2 cache controller", 0
        ALIGN

PL310Activate
        Push    "lr"
        ; The PL310 can only be enabled from secure mode. Make a call into our
        ; secure code to configure & enable it.
        LDR     a2, [a1, #HALDevice_Address] ; PL310 address passed in in a2
        MOV     a1, #1                       ; Enable
        DSB     SY
        SMC     #0
        MOV     a1, #1
        Pull    "pc"

PL310Deactivate
PL310Reset
        Push    "lr"
        ; Call the secure mode code to disable the cache
        LDR     a2, [a1, #HALDevice_Address] ; PL310 address passed in in a2
        MOV     a1, #0                       ; Disable
        DSB     SY
        SMC     #0
        Pull    "pc"

PL310Sleep
        MOV     a1, #0                  ; Previously at full power
        MOV     pc, lr

dmb_st
        Push    "a1, lr"
        ; Perform an ARM + PL310 DMB ST
        ADRL    a1, PL310Device
        LDR     a1, [a1, #HALDevice_Address]
        TEQ     a1, #0 ; Just in case we're called before PL310_InitDevice
        DMB     ST
        BEQ     %FT10
        PL310Sync a1, lr
10
        Pull    "a1, pc"

        END

