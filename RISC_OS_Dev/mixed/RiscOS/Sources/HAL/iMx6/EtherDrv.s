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

; Initialise ethernet hardware, pins, etc to make device available later

        GET     ListOpts
        GET     Macros
        GET     System
        GET     Machine.<Machine>
        GET     ImageSize.<ImageSize>
        $GetIO

        GET     OSEntries
        GET     HALEntries
        GET     HALDevice
        GET     EtherDevice
        GET     ENET
;        GET     NewErrors
        GET     Proc

        GET     iMx6q
        GET     StaticWS

        AREA    |Asm$$Code|, CODE, READONLY, PIC
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]
        IMPORT  GPIO_SetAsInput
        IMPORT  GPIO_SetAsOutput
        IMPORT  GPIO_DeviceNumber
        IMPORT  GPIO_SetAndEnableIRQ
        IMPORT  GPIO_DisableIRQ
        IMPORT  GPIO_IRQClear
        IMPORT  GPIO_ReadBit
        IMPORT  GPIO_WriteBit
        IMPORT  GPIO_ReadBitAddr
        IMPORT  memcpy
        IMPORT  udivide

        EXPORT  Ether_Init
        EXPORT  GetIPGClk
        EXPORT  ENET_CheckForPhy

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



; set up pads and clocks to expose the ethernet hardware
; create the correct HAL device too
Ether_Init
        Entry   "a1-a3"
        ldr     a2, IOMUXC_Base
        ldr     a3, =IOMuxPadEnet             ; pad drive stuff other ENET
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_ENET_MDC-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_ENET_MDIO-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_ENET_REF_CLK-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D29-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_GPIO_18-IOMUXC_BASE_ADDR]     ;

        ldr     a3, =IOMuxPadRGMII             ; pad drive stuff RGMII
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RD0-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RD1-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RD2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RD3-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TD0-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TD1-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TD2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TD3-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TXC-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_TX_CTL-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RXC-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_RGMII_RX_CTL-IOMUXC_BASE_ADDR]     ;

        mov     a3, #0          ; select daisychain stuff for RGMII mode
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_MDIO_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXCLK_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXDATA_0_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXDATA_1_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXDATA_2_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXDATA_3_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ENET_IPP_IND_MAC0_RXEN_SELECT_INPUT-IOMUXC_BASE_ADDR]

        mov     a3, #1                  ; alt 1, sion off
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDIO-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_REF_CLK-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDC-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TXC-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TD0-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TD1-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TD2-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TD3-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_TX_CTL-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RX_CTL-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RD0-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RD1-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RD2-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RD3-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_RGMII_RXC-IOMUXC_BASE_ADDR]

        mov     a3, #5                  ; alt 5, sion off route RGMII_IRQ to GPIO1_IO28
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_TX_EN-IOMUXC_BASE_ADDR]
                                        ; alt 5 GPIO3_IO29 drives RGMII_nrst
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D29-IOMUXC_BASE_ADDR]     ;
                                        ; alt 5 GPIO7_IO13 active low turns on phy on revD1 board
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_18-IOMUXC_BASE_ADDR]      ;



;       ldr     a1, GPIO_Log
; set phy irq pin as input
        mov     a1, #(1<<5) + 28
        bl      GPIO_SetAsInput
        mov     a1, #(3<<5) + (29) + 0<<8       ; GPIO3 bit 29 as o/p, val 1 hold reset
        bl      GPIO_SetAsOutput
        mov     a1, #(7<<5) + (13) + 1<<8       ; GPIO7 bit 13 as o/p, val 1 turn off revD1 phy
        bl      GPIO_SetAsOutput

        mov     a3, #8<<16                      ; 1p2v_io setting
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_GRP_DDR_TYPE_RGMII-IOMUXC_BASE_ADDR]

        mov     a3, #0                  ; term disabled
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_GRP_RGMII_TERM-IOMUXC_BASE_ADDR]

; enet PLL .. set with care, SATA is dependant on this too
        ldr     a2, CCMAn_Log
        mov     a3, #1<<16              ; bypass pll
        str     a3, [a2,#HW_CCM_ANALOG_PLL_ENET_ADDR]
        mov     a3, #1<<13              ; enable clock o/p, remove bypass
                                        ; (enet ref clk is 25mhz with above)
        orr     a3, a3, #1              ; so.. set for 50MHz enet ref clock
        orr     a3, a3, #1<<20          ; 100MHZ clk en bit (sata)
        str     a3, [a2,#HW_CCM_ANALOG_PLL_ENET_ADDR]
111
        ldr     a3, [a2,#HW_CCM_ANALOG_PLL_ENET_ADDR]
;  DebugReg a3, "pll ready? "
        tst     a3, #1<<31
        beq     %bt111                  ; wait for PLL Lock
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
        ldr     a3, [a2,#IOMUXC_GPR1-IOMUXC_BASE_ADDR]     ;
        orr     a3, a3, #1<<21                             ; enet ref clock from internal
        str     a3, [a2,#IOMUXC_GPR1-IOMUXC_BASE_ADDR]     ;

        bl      AddEtherTHDevice

        EXIT

; See if we can check a RevD board presence by powering up and down the phy
; MUST preserve all registers
ENET_CheckForPhy
        Entry   "a1-a4"
        ldr     a2, IOMUXC_Base
        ldr     a3, =IOMuxPadEnet             ; pad drive stuff other ENET
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_ENET_MDIO-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_ENET_MDC-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D29-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_GPIO_18-IOMUXC_BASE_ADDR]     ;


; now set all data path pads to GPIO
        mov     a3, #5                  ; alt 5 (GPIO, sion off
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDIO-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDC-IOMUXC_BASE_ADDR]
                                        ; alt 5 GPIO3_IO29 drives RGMII_nrst
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D29-IOMUXC_BASE_ADDR]     ;
                                        ; alt 5 GPIO7_IO13 active low turns on phy on revD1 board
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_18-IOMUXC_BASE_ADDR]      ;

        mov     a1, #(3<<5) + (29) + 0<<8      ; GPIO3 bit 29 as o/p, val 0 hold Phy reset
        bl      GPIO_SetAsOutput
        mov     a1, #(7<<5) + (13) + 1<<8      ; GPIO7 bit 13 as o/p, val 1 turn off revD1 phy
        bl      GPIO_SetAsOutput

        mov     a1, #(7<<5) + (13) + 0<<8  ; GPIO7 bit 13 val 0 turn on revD1 phy
        bl      GPIO_WriteBit           ; **** test temp

        Push    "a1-a3"
        MOV     a1, #&1000000                 ; slight delay
1       DMB
        SUBS    a1, a1, #1
        bgt     %bt1                       ; loop a while to let it settle
        Pull    "a1-a3"

        mov     a1, #(3<<5) + (29) + 1<<8  ; GPIO3 bit 29 as o/p, val 0-set,1-release Phy reset
        bl      GPIO_WriteBit

        Push    "a1-a3"
        MOV     a1, #&1000000                 ; slight delay
1       DMB
        SUBS    a1, a1, #1
        bgt     %bt1                       ; loop a while to let it settle
        Pull    "a1-a3"

        ldr     a4, = MDIORdIDL            ; command to read IDL reg
        bl      DoPhyCmd
;        str     a4, BoardDetectInfo1       ; check
        ldr     a2, = PhyAR8031
        teq     a2, a4
        moveq   a1, #0
        beq     %ft1
        ldr     a2, = PhyAR8035
        teq     a2, a4
        moveq   a1, #1                     ; flag later Phy detected
        movne   a1, #3                     ; default later Phy,bad detect
1
        orr a1, a1, a2, lsl #16
        str     a1, BoardDetectInfo        ; flag appropriately

; restore desired padmux to ethernet
        ldr     a2, IOMUXC_Base
        mov     a3, #1                  ; alt 1, sion off
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDIO-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_ENET_MDC-IOMUXC_BASE_ADDR]


        EXIT
MDIORdIDH *     ((2_01)<<30) +((2_10)<<28)+((&1)<<23)+((&2)<<18)+((2_10)<<16) ; ReadID1 (IDH)reg
MDIORdIDL *     ((2_01)<<30) +((2_10)<<28)+((&1)<<23)+((&3)<<18)+((2_10)<<16) ; ReadID2 (IDL)reg

; send command in a4 to Phy, and return response in a4

DoPhyCmd
        Entry   "a1-a3"
        mov     a1, #(1<<5) + (31) + 1<<8  ; GPIO1 bit 31 val 1 MDC on/hi
        bl      GPIO_SetAsOutput
        mov     a1, #(1<<5) + (22) + 1<<8  ; GPIO1 bit 22 val 1 MDIO on/hi
        bl      GPIO_SetAsOutput

        mov     a3, #64                    ; need 64 logic 1
11      bl      ClockMDC                   ; rising edge clocks data
        subs    a3, a3, #1
        bgt     %bt11                      ; 64 bit preamble

        mov     a3, #16                    ; 16 bit to write
cmdloop mov     a1, #(1<<5) + (22) + 0<<8  ; GPIO1 bit MDIO databit lo
        movs    a4, a4, lsl #1             ; do we need a 1
        orrcs   a1, a1, #1<<8              ; yes
        bl      GPIO_WriteBit
        bl      ClockMDC                   ; clocked in on rising edge
        subs    a3, a3, #1
        bgt     cmdloop
; now read 16 bits
        mov     a1, #(1<<5) + (22)         ; GPIO1 bit databit as input MDIO
        bl      GPIO_SetAsInput
        mov     a4, #0
        mov     a3, #16
rdloop  mov     a1, #(1<<5) + (22)         ; GPIO1 bit databit as input MDIO
        bl      GPIO_ReadBit               ; returns 1 or 0
        orr     a4, a1, a4, lsl #1         ; build it up
        bl      ClockMDC                   ; rising edge samples data
        subs    a3, a3, #1
        bgt     rdloop
        EXIT


; put out low-hi clock cycle
ClockMDC
        Entry   "a1-a3"
        mov     a1, #(1<<5) + (31) + 0<<8  ; GPIO1 bit 31 val 0  MDC lo
        bl      GPIO_WriteBit
        MOV     a1, #&8                 ; slight delay
13      DMB
        SUBS    a1, a1, #1
        bgt     %bt13                      ; loop a while to let it settle
        mov     a1, #(1<<5) + (31) + 1<<8  ; GPIO1 bit 31 val 1  MDC hi
        bl      GPIO_WriteBit
        MOV     a1, #&8                 ; slight delay
14      DMB
        SUBS    a1, a1, #1
        bgt     %bt14                      ; loop a while to let it settle
        EXIT

; the following 3 entry points are to be invoked from the
; ethernet driver, and have the HAL SB value passed in a2

; a1 = 1 for enable, 0 for disable
; a2 on entry is HAL sb value as taken from the hal device table
EtherTHPhyIRQEn
        Entry   "sb"
        mov     sb, a2
; DebugReg a1, "EPhyIRQa1 "
        teq     a1, #0
        mov     a1, #(1<<5) + 28 + (0<<8)       ; active low detect
        adr     lr, %ft1
        beq     GPIO_DisableIRQ
        b       GPIO_SetAndEnableIRQ
1
        EXIT

EtherTHPhyIRQTest
        Entry   "a1,sb"
        mov     sb, a2
        mov     a1, #(1<<5) + 28
        bl      GPIO_ReadBit
        eor     a1, a1, #1                      ; return a 1 if IRQ present
        EXIT

EtherTHPhyIRQClr
        Entry   "sb"
        mov     sb, a2
; DebugTX "EPhyIRQClr"
        mov     a1, #(1<<5) + 28
        bl      GPIO_IRQClear
        EXIT

; a1 bit0 = 1 for power enable, 0 for disable
; a1 bit1 = 1 for reset set, 0 for reset clear
; a2 on entry is HAL sb value as taken from the hal device table
; if a1 bit7 set then test call  instead
EtherTHPhyPwrRst
        Entry   "sb"
        mov     sb, a2
        tst     a1, #1<<7
        bne     TestCall
        mov     a3, a1
        tst     a3, #1<<1
        moveq   a1, #(3<<5) + (29) + 1<<8       ; val 0, nreset clear
        movne   a1, #(3<<5) + (29) + 0<<8       ; val 1, nreset set
        bl      GPIO_WriteBit
        tst     a3, #1<<0
        movne   a1, #(7<<5) + (13) + 0<<8       ; val 0 turn on revD1 phy
        moveq   a1, #(7<<5) + (13) + 1<<8       ; val 1 turn off revD1 phy
        bl      GPIO_WriteBit

        EXIT
; invoke a test call to the Phy Type Presence detect code
TestCall
        bl      ENET_CheckForPhy
        EXIT


;
;


AddEtherTHDevice
        Entry   "a3, a4, v1"
        ADRL    v1, EtherTH_Device
        MOV     a1, v1
        ADR     a2, EtherTHDeviceTemplate
        MOV     a3, #HALDevice_ENET_Size
        BL      memcpy
        ldr     a1, ENET_Log
        str     a1, [v1, #ethaddr-EtherTHDeviceTemplate]
        mov     a1, #(1<<5) + 28
        bl      GPIO_DeviceNumber
        str     a1, [v1, #etphyd-EtherTHDeviceTemplate]
        mov     a1, #(1<<5)
        bl      GPIO_ReadBitAddr
        add     a1, a1, #GPIO_ISR_OFFSET-GPIO_DR_OFFSET
        str     a1, [v1, #etrdba-EtherTHDeviceTemplate]
        mov     a1, #1<<28      ; create bit test mask
        str     a1, [v1, #etrdbn-EtherTHDeviceTemplate]
        bl      GetIPGClk
        str     a1, [v1, #ethclk-EtherTHDeviceTemplate]
        str     sb, [v1, #ethws-EtherTHDeviceTemplate]
; DebugReg a1, "Computed Clk  "
; DebugReg v1, "Eth Dev Addr  "
        MOV     a1, #0
        MOV     a2, v1
        CallOS  OS_AddDevice
        EXIT

; Out: a1 = IPG clock rate
GetIPGClk
        Entry   "a2-a4"
        ldr     a1, CCM_Base
        ldr     a4, [a1, #CCM_CBCMR_OFFSET]
        and     a4, a4, #3<<18
        adr     a2, pll2_clocks
        add     a4, a2, a4, lsr #16

        ldr     a2, [a1, #CCM_CBCDR_OFFSET]
; DebugReg a2, "CBCDR  "
; add a1, a1, #CCM_CBCDR_OFFSET
; DebugReg a1, "CBCDR addr  "
        and     a3, a2, #&3<<8          ; ipg_podf bits
        mov     a3, a3, lsr #8
        and     a1, a2, #7<<10          ; ahb_podf bits
        mov     a1, a1, lsr #10
        add     a1, a1, #1
        ldr     a2, [a4]                ; retrieve actual pll2 clock rate
; DebugReg a2, "pll Clk  "
        bl      udivide
; DebugReg a1, "pll Clk 1st div "
        mov     a2, a1
        add     a1, a3, #1
        bl      udivide
        EXIT

pll2_clocks
        DCD     528000000
        DCD     396000000
        DCD     352000000
        DCD     198000000

EtherTHDeviceTemplate
        DCW     HALDeviceType_Comms + HALDeviceComms_EtherNIC
        DCW     HALDeviceID_EtherNIC_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     0               ; API version 0
        DCD     EtherTHDevice_Desc
ethaddr DCD     0               ; Address - filled in later
        %       12              ; Reserved
        DCD     EtherTHDevice_Activate
        DCD     EtherTHDevice_Deactivate
        DCD     EtherTHDevice_Reset
        DCD     EtherTHDevice_Sleep
        DCD     IMX_INT_ENET    ; Device interrupt
        DCD     0               ; TestIRQ cannot be called
        DCD     0               ; ClrIRQ cannot be called
        %       4               ; reserved
        ASSERT (. - EtherTHDeviceTemplate) = HALDeviceSize
etphyd  DCD     0                       ; IRQ dev number for phy irq (shared)
        DCD     EtherTHPhyIRQEn         ; phy irq enable/disable
        DCD     EtherTHPhyIRQTest       ; phy irq test active
        DCD     EtherTHPhyIRQClr        ; phy irq acknowledge
                                        ; (still need a HAL_IRQClr)
etrdba  DCD     0                       ; irq active bit test address
etrdbn  DCD     0                       ; irq active bit test bit
ethws   DCD     0               ; HAL workspace pointer - filled in later
ethclk  DCD     0               ; ethernet clock - filled later
        DCD     EtherTHPhyPwrRst        ; phy power enable and reset
        ASSERT (. - EtherTHDeviceTemplate) = HALDevice_ENET_Size

EtherTHDevice_Desc
        =       "iMx6 ethernet controller", 0
        ALIGN

EtherTHDevice_Activate
        Entry   "sb"
        MOV     a1, #1
        EXIT

EtherTHDevice_Deactivate
EtherTHDevice_Reset
        MOV     pc, lr

EtherTHDevice_Sleep
        MOV     a1, #0
        MOV     pc, lr




        END
