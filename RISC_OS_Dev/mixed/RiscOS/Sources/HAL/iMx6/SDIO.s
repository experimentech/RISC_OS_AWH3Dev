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
;
; Copyright (c) 2012, RISC OS Open Ltd
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

        EXPORT  SDIO_InitDevices
        IMPORT  memcpy
        IMPORT  TPSRead
        IMPORT  TPSWrite
        IMPORT  HAL_CounterDelay

        ; KEEP ; for debugging

        GET     Hdr:ListOpts
        GET     Hdr:CPU.Arch
        GET     Hdr:Macros
        GET     Hdr:OSEntries
        GET     Hdr:Proc
        GET     hdr.iMx6q
        GET     HALDevice
        GET     GPIODevice
        GET     hdr.GPIO
        GET     hdr.iMx6qIRQs
        GET     hdr.StaticWS
        GET     hdr.iMx6qReg
        GET     hdr.iMx6qIOMux
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]
        IMPORT  GPIO_SetAsInput



sb      RN      9

; RISC OS device numbers for each controller's IRQ line
MMC1_IRQ * IMX_INT_USDHC1      ; used for the mother board slot
MMC2_IRQ * IMX_INT_USDHC2      ; used as part of the wifi interface
MMC3_IRQ * IMX_INT_USDHC3      ; used as cpu board/boot slot
MMC4_IRQ * IMX_INT_USDHC4      ; not used

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        MACRO
$class  HALDeviceField $field, $value
        LCLS    myvalue
      [ "$value" = ""
myvalue SETS    "$field"
      |
myvalue SETS    "$value"
      ]
        ASSERT  . - %A0 = HALDevice_$class$field
     [ ?HALDevice_$class$field = 2
        DCW     $myvalue
   ELIF ?HALDevice_$class$field = 4
        DCD     $myvalue
      |
        %       ?HALDevice_$class$field
      ]
        MEND

; Template for device blocks

Template
0
        HALDeviceField Type,               HALDeviceType_ExpCtl + HALDeviceExpCtl_SDIO
        HALDeviceField ID,                 HALDeviceID_SDIO_SDHCI
        HALDeviceField Location,           HALDeviceBus_Sys + HALDeviceSysBus_AXI
        HALDeviceField Version,            HALDeviceSDHCI_MinorVersion_HasTrigger
        HALDeviceField Description
        HALDeviceField Address,            0 ; patched up at initialisation
        HALDeviceField Reserved1,          0
        HALDeviceField Activate
        HALDeviceField Deactivate
        HALDeviceField Reset
        HALDeviceField Sleep
        HALDeviceField Device,             MMC1_IRQ ; overridden in some cases
        HALDeviceField TestIRQ
        HALDeviceField ClearIRQ,           0
        HALDeviceField Reserved2,          0
SDHCI   HALDeviceField Flags,              HALDeviceSDHCI_Flag_32bit :OR: HALDeviceSDHCI_Flag_ErrIRQbug
SDHCI   HALDeviceField Slots,              1
SDHCI   HALDeviceField SlotInfo,           0 ; patched up at initialisation
SDHCI   HALDeviceField WriteRegister,      0
SDHCI   HALDeviceField GetCapabilities,    0
SDHCI   HALDeviceField GetVddCapabilities
SDHCI   HALDeviceField SetVdd
SDHCI   HALDeviceField SetBusMode,         0
SDHCI   HALDeviceField PostPowerOn,        0
SDHCI   HALDeviceField SetBusWidth
SDHCI   HALDeviceField GetMaxCurrent
SDHCI   HALDeviceField SetSDCLK
SDHCI   HALDeviceField GetTMCLK
SDHCI   HALDeviceField SetActivity
SDHCI   HALDeviceField GetCardDetect       ; overridden in some cases
SDHCI   HALDeviceField GetWriteProtect
SDHCI   HALDeviceField TriggerCommand
        %       %A0 + HALDevice_SDHCISize - .
        ASSERT  . - %A0 = SDHCISB
        DCD     0                          ; patched up at initialisation
        ASSERT  . - %A0 = SDHCISlotInfo + HALDeviceSDHCI_SlotInfo_Flags
        DCD     0                          ; patched up at initialisation
        ASSERT  . - %A0 = SDHCISlotInfo + HALDeviceSDHCI_SlotInfo_StdRegs
        DCD     0                          ; patched up at initialisation
        ASSERT  . - %A0 = SDHCIBaseClock
        DCD     0                          ; patched up at initialisation
        ASSERT  . - %A0 = SDHCISize


        ; Init the SDHCI HAL device(s)
SDIO_InitDevices ROUT
        Push    "a1-a4,lr"
; first lets ensure all required pins are correctly enabled
; we have 3 ports.
; port 1 is the card on the mainboard
; wp is on GPIO4_15 which is key_row 4
; CD is on GPIO_2
; port 2 is the wifi unit
; port 3 is the slot on the CPUboard, and carries the boot SD
; CD is on EIM_DA9

; set pad mux
; sd1 is mostly alt0. SD1CD is on GPIO2 (GPIO1/02)input alt5(=0 if card present)
; and wp is GPOI4/15 key_row4 as input alt5
; sd2 is mostly alt0
; sd3 is mostly alt0. CD via eim_da9 pad alt5 as GPIO3_IO09 (=0 if card present)
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
        mov     a3, #0          ; alt 0
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_DAT0-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_DAT0-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_DAT0-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_DAT1-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_DAT1-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_DAT1-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_DAT2-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_DAT2-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_DAT2-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_DAT3-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_DAT3-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_DAT3-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_CMD-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_CMD-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_CMD-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD1_CLK-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD2_CLK-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_SD3_CLK-IOMUXC_BASE_ADDR] ;

        mov     a3, #5                  ; alt5
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_DA9-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_ROW4-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_GPIO_2-IOMUXC_BASE_ADDR] ;

; set pad type
        ldr     a3, =IOMuxPadUSDHC      ; pad drive stuff uSDHC controller pins
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_DAT0-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_DAT1-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_DAT2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_DAT3-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_CMD-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD1_CLK-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_DAT0-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_DAT1-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_DAT2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_DAT3-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_CMD-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD2_CLK-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_DAT0-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_DAT1-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_DAT2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_DAT3-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_CMD-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_SD3_CLK-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_DA9-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_ROW4-IOMUXC_BASE_ADDR] ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_GPIO_2-IOMUXC_BASE_ADDR] ;

; set up relevant GPIO pins as input
        mov     a1, #(1<<5) + 2                 ; GIPO1 bit 2
        bl      GPIO_SetAsInput
;       ldr     a1, GPIO_Log
;       ldr     a3, [a1, #4]
;       bic     a3, a3, #1<<2                   ; set as input SD1CD
;       str     a3, [a1, #4]
;       add     a1, a1, #GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
        mov     a1, #(3<<5) + 9                 ; GPIO3 bit 9
        bl      GPIO_SetAsInput
;       ldr     a3, [a1, #4]
;       bic     a3, a3, #1<<9                   ; set as input SD3CD
;       str     a3, [a1, #4]
;       add     a1, a1, #GPIO4_BASE_ADDR-GPIO3_BASE_ADDR
        mov     a1, #(4<<5) + 15                ; GPIO4 bit 15
        bl      GPIO_SetAsInput
;       ldr     a3, [a1, #4]
;       bic     a3, a3, #1<<15                  ; set as input SD1WP
;       str     a3, [a1, #4]

; setup any daisychain needed
; none detected??

; enable clocks

        MOV     a3, #0
        ADRL    a4, SDIOWS
        BL      InitDevice
        MOV     a3, #1
        ADRL    a4, SDIOWS+SDHCISize
        BL      InitDevice
        MOV     a3, #2
        ADRL    a4, SDIOWS+SDHCISize*2
        BL      InitDevice
        Pull    "a1-a4,pc"

        ; Init one SDHCI HAL device
        ; a3 = device number
        ; a4 -> workspace for this device
InitDevice ROUT
        Push    "a1-a4,lr"
        MOV     a1, a4
        ADR     a2, Template
        MOV     a3, #SDHCISize
        BL      memcpy

        Pull    "a1-a4"

        ; Address and SlotInfo_StdRegs
        LDR     lr, SDIO_Log
        ASSERT  USDHC2_BASE_ADDR-USDHC1_BASE_ADDR=(1<<14)
        ADD     lr, lr, a3, LSL #14
        STR     lr, [a4, #HALDevice_Address]
        STR     lr, [a4, #SDHCISlotInfo + HALDeviceSDHCI_SlotInfo_StdRegs]

        ; Might as well do hardware initialisation here while we have the address...
        LDR     a2, =&08800880
        STR     a2, [lr, #USDHC_WML_OFFSET]

        ; Device
        CMP     a3, #1
        MOVLO   lr, #MMC1_IRQ
        MOVEQ   lr, #MMC2_IRQ
        CMP     a3, #2
        MOVEQ   lr, #MMC3_IRQ
        MOVHI   lr, #MMC4_IRQ
        STR     lr, [a4, #HALDevice_Device]

        ; SlotInfo
        ADD     lr, a4, #SDHCISlotInfo
        STR     lr, [a4, #HALDevice_SDHCISlotInfo]

        ; SDHCISB
        STR     sb, [a4, #SDHCISB]

        ; SlotInfo_Flags
        CMP     a3, #1
        MOV     lr, #HALDeviceSDHCI_SlotFlag_Bus4Bit
        ORREQ   lr, lr, #HALDeviceSDHCI_SlotFlag_Integrated
        STR     lr, [a4, #SDHCISlotInfo + HALDeviceSDHCI_SlotInfo_Flags]

        ; BaseClock
        BL      GetBaseClock
        STR     a1, [a4, #SDHCIBaseClock]
; DebugRegNCR a1, "Init:BaseClk is "
        ; GetCardDetect
        CMP     a3, #1
        ADREQL  lr, GetCardDetect_NonRemovable
        STREQ   lr, [a4, #HALDevice_SDHCIGetCardDetect]

        MOV     a1, #0 ; flags
        MOV     a2, a4
;  DebugReg a4, "HALDevice at "
        Pull    "lr"
        LDR     pc, OSentries+4*OS_AddDevice ; tail call

GetBaseClock
        ; Get base USDHC clock
        ; In:
        ; a3 = device number
        ; Out:
        ; a1 = clock rate in kHz
        Entry   "a2-a4"
        ; Get PFD from usdhcX_clk_sel
        LDR     a1, CCM_Base
        LDR     a2, [a1, #CCM_CSCMR1_OFFSET]
; DebugReg a2,"ccm_cscmr1 "
        MOV     a4, #1<<16
        TST     a2, a4, LSL a3
        LDREQ   a4, =396*1000 ; 396M PFD
        LDRNE   a4, =352*1000 ; 352M PFD
        ; Get divisor from usdhcX_podf
        LDR     a2, [a1, #CCM_CSCDR1_OFFSET]
        MOV     a2, a2, LSR #11
        CMP     a3, #1
        MOVGE   a2, a2, LSR #5
        CMP     a3, #3
        MOVEQ   a2, a2, LSR #3
        MOVGT   a2, a2, LSR #6
        AND     a2, a2, #7
        ADD     a2, a2, #1
        DivRem  a1, a4, a2, ip
; DebugReg a1, "Base clk khz "
        EXIT

Description DATA
        =       "Freescale i.MX6 uSDHC", 0
        ALIGN

NOPEntry ROUT
        MOV     pc, lr

Activate ROUT
        MOV     a1, #1  ; mark successful activation
        MOV     pc, lr

Deactivate * NOPEntry

Reset ROUT
        Entry   "sb"
        LDR     sb, [a1, #SDHCISB]
        LDR     a1, [a1, #HALDevice_Address]
;        DebugReg a1, "resetting hal device at "
        ; Set the RSTA bit of SYSCTRL
        LDR     a2, [a1, #USDHC_SYSCTRL_OFFSET]
        ORR     a2, a2, #1<<24
        STR     a2, [a1, #USDHC_SYSCTRL_OFFSET]
        ; Wait for completion
10
        LDR     a2, [a1, #USDHC_SYSCTRL_OFFSET]
        TST     a2, #1<<24
        BNE     %BT10
        ; XXX also clear DMA mode
        LDR     a2, [a1, #USDHC_PROCTL_OFFSET]
        BIC     a2, a2, #3<<8
        STR     a2, [a1, #USDHC_PROCTL_OFFSET]
        EXIT

Sleep ROUT
        ; Could probably turn clock to controller on/off to
        ; save power, but for now don't support power saving
        MOV     a1, #0
        MOV     pc, lr

TestIRQ ROUT
        ; Not a shared interrupt, so it must be our fault
        MOV     a1, #1
        MOV     pc, lr

GetVddCapabilities ROUT
        ; On the Wandboard all three interfaces are fixed at 3.3V
        MOV     a1, #1
        MOV     pc, lr

SetVdd * NOPEntry ; There is no software control of Vdd for this board

SetBusWidth ROUT
        Entry   "v1,sb"
        LDR     sb, [a1, #SDHCISB]
        LDR     a1, [a1, #HALDevice_Address]
;  DebugRegNCR a3, "SetBusWidth "
;  DebugReg a1, "for "
        ; uSDHC has nonstandard layout of this register
        LDR     a2, [a1, #USDHC_PROCTL_OFFSET]
        MOV     a3, a3, LSR #2 ; 00 -> 1 bit, 01 -> 4 bit, 10 -> 8 bit
        BFI     a2, a3, #1, #2
        STR     a2, [a1, #USDHC_PROCTL_OFFSET]
        EXIT

GetMaxCurrent ROUT
        ; TODO - Check this. For now stick with a low value as per BCM HAL
        MOV     a1, #100
        MOV     pc, lr

SetSDCLK ROUT
        Entry   "v1,sb"
        LDR     sb, [a1, #SDHCISB]
        ; The clock frequency is specified by use of a prescaler (1 to 1/256,
        ; power of 2) and a divisor (1-16) which act on the base clock
        LDR     v1, [a1, #SDHCIBaseClock]
        LDR     a1, [a1, #HALDevice_Address]
;   DebugRegNCR a3, "SetSDCLK "
;   DebugRegNCR a1, "for "
;   DebugReg v1, "base "

        ADD     a2, v1, a3
        SUB     a2, a2, #1 ; round divider up so we round frequency down
        DivRem  a4, a2, a3, ip
;   DebugReg a4, "need divisor "
        MOV     ip, #1
        ; Shift right until we have a suitable divisor
10
        CMP     a4, #16
        BLS     %FT15
        MOVS    a4, a4, LSR #1
        ADDCS   a4, a4, #1
        MOV     ip, ip, LSL #1
        B       %BT10

        ; It's also recommended to keep the divisor as low as possible, so keep
        ; shifting as far as it will go
15
        CMP     ip, #256
        MOVHI   ip, #256 ; Clamp on overflow
        MOVHI   a4, #16
        BHS     %FT16
        TST     a4, #1
        MOVEQ   a4, a4, LSR #1
        MOVEQ   ip, ip, LSL #1
        BEQ     %BT15
16
;    DebugRegNCR ip, "prescaler "
;    DebugReg a4, "divisor "

        ; Wait until clock is stable
20
        LDR     a2, [a1, #USDHC_PRSSTATE_OFFSET]
        TST     a2, #8
        BEQ     %BT20

        ; Disable FRC_SDCLK_ON? We never set this bit, so shouldn't need to clear it
;USDHC_VENDSPEC_OFFSET * 0xC0
;        LDR     a2, [a1, #USDHC_VENDSPEC_OFFSET]
;        BIC     a2, a2, #256
;        STR     a2, [a1, #USDHC_VENDSPEC_OFFSET]

        ; Pack into SYS_CTRL register
        LDR     a2, [a1, #USDHC_SYSCTRL_OFFSET]
        MOV     ip, ip, LSR #1
        SUB     a4, a4, #1
        BFI     a2, ip, #8, #8
        BFI     a2, a4, #4, #4
        ORR     a2, a2, #&F
        STR     a2, [a1, #USDHC_SYSCTRL_OFFSET]

        ; Wait until clock is stable
30
        LDR     a3, [a1, #USDHC_PRSSTATE_OFFSET]
        TST     a3, #8
        BEQ     %BT30
; DebugRegNCR ip,"ip="
; DebugRegNCR v1,"baseclk="
; DebugRegNCR a4,"a4="
; DebugReg a2,"a2="
        ; Calculate actual frequency for return
        MOVS    ip, ip, LSL #1
        ADD     a4, a4, #1
        MULNE   a4, ip, a4
        DivRem  a1, v1, a4, a2

;   DebugReg a1, "actual freq "

        EXIT

GetTMCLK ROUT
        Entry   "sb"
        ; SDCLK is reused for TMCLK
        LDR     sb, [a1, #SDHCISB]
        LDR     a3, [a1, #SDHCIBaseClock]
        LDR     a1, [a1, #HALDevice_Address]
        LDR     a2, [a1, #USDHC_SYSCTRL_OFFSET]
        UBFX    ip, a2, #8, #8
        UBFX    a4, a2, #4, #4
; DebugRegNCR ip,"ip="
; DebugRegNCR a3,"baseclk="
; DebugRegNCR a4,"a4="
; DebugReg a2,"a2="
        ; Calculate actual frequency for return
        MOVS    ip, ip, LSL #1
        ADD     a4, a4, #1
        MULNE   a4, ip, a4
        DivRem  a1, a3, a4, a2

;    DebugReg a1, "tmclk freq "

        EXIT

SetActivity * NOPEntry ; No generic implementation in SDIODriver


; card 1 (wifi) has no CD bit, do if a1==SDIO_Log then it is card0, else card2
GetCardDetect ROUT
        Entry   "a2, sb"
        LDR     sb, [a1, #SDHCISB]
        ldr     a2, SDIO_Log
        LDR     a1, [a1, #HALDevice_Address]
        TEQ     a1, a2
        ldr     a2, GPIO_Log
        addne   a2, a2, #GPIO3_BASE_ADDR-GPIO1_BASE_ADDR
        ldr     a1, [a2]
        mvn     a1, a1          ; invert it
        UBFXEQ  a1, a1, #2, #1
        UBFXNE  a1, a1, #9, #1
        EXIT

GetCardDetect_NonRemovable ROUT
        MOV     a1, #1
        MOV     pc, lr

GetWriteProtect ROUT
 [ {TRUE}
        ; Wandboard only supports micro-SD cards, these cannot be write-protected
        MOV     a1, #0
        MOV     pc, lr
 |
        Entry   "sb"
        LDR     sb, [a1, #SDHCISB]
; DebugRegNCR a1, "GWPAddr "
        ldr     lr, SDIO_Log
        LDR     a1, [a1, #HALDevice_Address]
        TEQ     a1, lr
        movne   a1, #0
        EXIT    NE
        add     a1, lr, #GPIO4_BASE_ADDR-GPIO1_BASE_ADDR
        ldr     a1, [a1]
;        MVN     a1, a1 ; Invert so that 1=write protect, 0=write enable
        UBFX    a1, a1, #15, #1
; DebugReg a1, "wp="
        EXIT
 ]

TriggerCommand ROUT
        ; The Transfer Mode register is in a non-standard place on i.MX6
        LDR     a1, [a1, #HALDevice_Address]
        ORR     a3, a3, #0x80000000
        MOV     a4, a4, LSL #16
        STR     a3, [a1, #USDHC_MIXCTRL_OFFSET]
        STR     a4, [a1, #USDHC_XFERTYP_OFFSET]
        MOV     pc, lr

        END
