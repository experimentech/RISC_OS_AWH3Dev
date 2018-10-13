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
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO
        GET     Hdr:Proc

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     HALDevice
        GET     GPIODevice
        GET     hdr.GPIO

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  GPIO_Init
        EXPORT  GPIO_SetAsOutput
        EXPORT  GPIO_SetAsInput
        EXPORT  GPIO_WriteBit
        EXPORT  GPIO_ReadBit
        EXPORT  GPIO_SetAndEnableIRQ
        EXPORT  GPIO_DisableIRQ
        EXPORT  GPIO_IRQClear
        EXPORT  GPIO_DeviceNumber
        EXPORT  GPIO_ReadBitAddr
        EXPORT  GPIO_DeviceInit
        IMPORT  TPSRead
        IMPORT  TPSWrite
        IMPORT  memcpy
        IMPORT  IIC_DoOp_Poll
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
 ]

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

;  These routines handle 'stuff' to do with the GPIO registers
;  No effort is made here to handle signal multiplexing to get the
;  'bit' routed to the GPIO port.
;
;
GPIO_Init
; Don't bother resetting - just make sure no IRQs are enabled
        ldr     a1, GPIO_Log
        mov     a2, #7
        mov     a3, #0
10      str     a3, [a1, #GPIO_IMR]               ; mask
        str     a3, [a1, #GPIO_EDGE_SEL]          ; irq edge override
        add     a1, a1, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        subs    a2, a2, #1
        bgt     %bt10
        mov     pc, lr

GPIO_DeviceInit
        Entry   "a1 - a3, v1"
        ADRL    v1, GPIO_Device
        MOV     a1, v1
        ADR     a2, GPIODeviceTemplate
        MOV     a3, #HALDevice_GPIO_Size
        BL      memcpy
        ldr     a1, SRC_Log
        ldr     a1, [a1, #SRC_SBMR_OFFSET]
        tst     a1, #1<<27       ; check whether rev B1 or C1
        moveq   a1, #GPIORevision_iMx6Q_WBrevB
        streq   a1, [v1, #GPIORev-GPIODeviceTemplate]
        ldr     a1, GPIO_Log
        str     a1, [v1, #GPIOadr-GPIODeviceTemplate]
        MOV     a1, #0
        MOV     a2, v1
        CallOS  OS_AddDevice
; DebugTX "Device added "
        EXIT


; set GPIO bit as an output
; a1 = GPIO#<<5 (1-7) + bitno (0-31) + initial state<<8
GPIO_SetAsOutput
        Entry   "a1-a4"
; DebugReg a1, "GPSetAsOP "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7      ; clear out the state bit
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        mov     a3, a1, lsr #8  ; get the iobit state
        and     a3, a3, #1
        and     a1, a1, #&1f    ; get bit number
        mov     a2, #1
        mov     a2, a2, lsl a1
        ldr     a1, [a4, #GPIO_DR]
        teq     a3, #0
        biceq   a1, a1, a2
        orrne   a1, a1, a2
        str     a1, [a4, #GPIO_DR]    ; set bit state
        ldr     a1, [a4, #GPIO_GDIR]
        orr     a1, a1, a2
        str     a1, [a4, #GPIO_GDIR]  ; set as output
        DMB     ST
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31)
GPIO_SetAsInput
        Entry   "a1-a4"
; DebugReg a1, "GPSetAsIP "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        and     a1, a1, #&1f    ; get bit number
        mov     a2, #1
        mov     a2, a2, lsl a1
        ldr     a1, [a4, #GPIO_GDIR]
        bic     a1, a1, a2
        str     a1, [a4, #GPIO_GDIR]  ; set as input
        DMB     ST
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31) + state<<8
GPIO_WriteBit
        Entry   "a1-a4"
; DebugReg a1, "writeBit "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7      ; clear out the state bit
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        tst     a1, #1<<8       ; test the state bit
        mov     a3, #1
        and     a1, a1, #&1f    ; get bit number
        mov     a3, a3, lsl a1
        ldr     a1, [a4, #GPIO_DR]
        biceq   a1, a1, a3
        orrne   a1, a1, a3
        str     a1, [a4, #GPIO_DR]    ; set bit state
        DMB     ST
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31)
        ; This clears the irq status bit in GPIO. HAL_IRQClr still needs calling
GPIO_IRQClear
        Entry   "a1-a4"
; DebugRegNCR a1, "GPIRQClr "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7      ; clear out the state bit
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        mov     a3, #1
        and     a1, a1, #&1f    ; get bit number
        mov     a3, a3, lsl a1
; DebugReg a3, "GPIRQClr bit "
        str     a3, [a4, #GPIO_ISR]    ; Write bit to clear
        DMB     ST
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31)
        ; returns address of the bit in a1
GPIO_ReadBitAddr
        Entry   "a2-a4"
; DebugRegNCR a1, "GPReadBitAddr "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        add     a1, a4, #GPIO_DR
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31)
        ; returns a1 = 0 or 1
GPIO_ReadBit
        Entry   "a2-a4"
; DebugRegNCR a1, "GPReadBit "
        ldr     a4, GPIO_Log
        mov     a2, a1, lsr #5
        and     a2, a2, #7
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        and     a1, a1, #&1f
        ldr     a3, [a4, #GPIO_DR]
;  DebugRegNCR a3,"got "
        mov     a1, a3, lsr a1
        and     a1, a1, #1
;  DebugReg a1,"gave "
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31)
        ; +  IRQ type flags <<8
        ;      (0<<8) = LEVELDETECT0
        ;      (1<<8) = LEVELDETECT1
        ;      (2<<8) = RISINGDETECT
        ;      (3<<8) = FALLINGDETECT
GPIO_SetAndEnableIRQ
        Entry   "a1-a4"
; DebugReg a1, "GPSet&EnableIRQ "
        mov     a2, a1, lsr #8
        and     a2, a2, #3
        and     a1, a1, #&ff
        mov     a4, a1, lsr #5
        sub     a4, a4, #1      ; get to 0-6
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     lr, a3, a4
        ldr     a4, GPIO_Log
        add     a4, a4, lr      ; locate relevant GPIO
        mov     a3, #1
        and     a1, a1, #&1f    ; get bit number
        mov     a3, a3, lsl a1
        ldr     lr, [a4, #GPIO_IMR]
        orr     lr, lr, a3
        str     lr, [a4, #GPIO_IMR]    ; set bit state
        ; now set the edge/level stuff from value in a2
        ; first sort the bit
        add     a1, a1, a1      ; 2 bits
        tst     a1, #1<<5       ; above 32?
        addne   a4, a4, #4      ; yes.. go to second reg
        bicne   a1, a1, #1<<5
; DebugReg a1, "use bit-"
        ldr     lr, [a4, #GPIO_ICR1]
        mov     a3, #3
        bic     lr, lr, a3, lsl a1
        orr     lr, lr, a2, lsl a1
        str     lr, [a4, #GPIO_ICR1]
        DMB     ST
        EXIT

        ; a1 = GPIO#<<5 (1-7) + bitno (0-31) + possible stuff <<8
GPIO_DisableIRQ
        Entry   "a1-a4"
; DebugReg a1, "GPDisable irq "
        ldr     a4, GPIO_Log
        and     a1, a1, #&ff
        mov     a2, a1, lsr #5
        sub     a2, a2, #1
        mov     a3, #GPIO2_BASE_ADDR-GPIO1_BASE_ADDR
        mul     a2, a3, a2
        add     a4, a4, a2      ; locate relevant GPIO
        mov     a3, #1
        and     a1, a1, #&1f    ; get bit number
        mov     a3, a3, lsl a1
        ldr     a1, [a4, #GPIO_IMR]
        bic     a1, a1, a3
        str     a1, [a4, #GPIO_IMR]    ; clr bit state
        DMB     ST
        EXIT

; return a1=Device no (IRQ no) for specified GPIO bit
; a1 = GPIO#<<5 (1-7) + bitno (0-31)
GPIO_DeviceNumber
        Entry   "a2"
        sub     a1, a1, #1<<5   ; move GPIO range to 0-6
        cmp     a1, #8
        bgt     %ft1
        adrl    a2, GPIO_GDTab1
        ldr     a1, [a2, a1, lsl #2]
        EXIT
1       mov     a1, a1, lsr #4  ; div 16
        adrl    a2, GPIO_GDTab2
        ldr     a1, [a2, a1, lsl #2]
        EXIT


GPIO_GDTab1
        DCD     IMX_INT_GPIO1_INT7
        DCD     IMX_INT_GPIO1_INT6
        DCD     IMX_INT_GPIO1_INT5
        DCD     IMX_INT_GPIO1_INT4
        DCD     IMX_INT_GPIO1_INT3
        DCD     IMX_INT_GPIO1_INT2
        DCD     IMX_INT_GPIO1_INT1
        DCD     IMX_INT_GPIO1_INT0
GPIO_GDTab2
        DCD     IMX_INT_GPIO1_INT15_0
        DCD     IMX_INT_GPIO1_INT31_16
        DCD     IMX_INT_GPIO2_INT15_0
        DCD     IMX_INT_GPIO2_INT31_16
        DCD     IMX_INT_GPIO3_INT15_0
        DCD     IMX_INT_GPIO3_INT31_16
        DCD     IMX_INT_GPIO4_INT15_0
        DCD     IMX_INT_GPIO4_INT31_16
        DCD     IMX_INT_GPIO5_INT15_0
        DCD     IMX_INT_GPIO5_INT31_16
        DCD     IMX_INT_GPIO6_INT15_0
        DCD     IMX_INT_GPIO6_INT31_16
        DCD     IMX_INT_GPIO7_INT15_0
        DCD     IMX_INT_GPIO7_INT31_16


; Generic HAL device used for all board types
GPIODeviceTemplate
        DCW     HALDeviceType_Comms + HALDeviceComms_GPIO
        DCW     HALDeviceID_GPIO_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     1               ; API version 0.1
        DCD     GPIODesc        ; Description
GPIOadr DCD     0               ; Address (filled in later)
        %       12              ; Reserved
        DCD     GPIOActivate
        DCD     GPIODeactivate
        DCD     GPIOReset
        DCD     GPIOSleep
        DCD     -1              ; Device (none)
        DCD     0               ; TestIRQ
        DCD     0               ; ClearIRQ
        %       4
        ASSERT  (.-GPIODeviceTemplate) = HALDeviceSize
GPIOType DCD    GPIOType_iMx6Q
GPIORev DCD     GPIORevision_iMx6Q_WBrevC1
        ASSERT  (.-GPIODeviceTemplate) = HALDevice_GPIO_Size
; extra bits for API 0.1
        DCD     GPIO_ReadBit
        DCD     GPIO_WriteBit
        DCD     GPIO_SetAsInput
        DCD     GPIO_SetAsOutput
        DCD     GPIO_SetAndEnableIRQ
        DCD     GPIO_IRQClear
        DCD     GPIO_DisableIRQ
        DCD     GPIO_ReadBitAddr
        DCD     GPIO_DeviceNumber
        DCD     0;GPIO_ReservedAPI1
        ASSERT  (.-GPIODeviceTemplate) =HALDevice_GPIO_Size_0_1














GPIODesc
        =       "iMX6 GPIO interface", 0
        ALIGN

        ; These don't do much
GPIOActivate
        MOV     a1, #1
GPIODeactivate
GPIOReset
        MOV     pc, lr

GPIOSleep
        MOV     a1, #0
        MOV     pc, lr



        END
