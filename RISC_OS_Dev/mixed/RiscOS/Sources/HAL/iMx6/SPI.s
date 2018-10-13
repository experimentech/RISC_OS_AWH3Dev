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
        GET     Hdr:SPIDevice
        GET     Hdr:SPIDriver

        GET     hdr.iMx6q
        GET     hdr.iMx6qIRQs
        GET     hdr.StaticWS
        GET     hdr.SPI
        GET     hdr.PRCM
        GET     SPIDevice
        GET     hdr.CoPro15ops

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  SPI_Init
        IMPORT  memcpy
        IMPORT  GPIO_SetAsOutput
        IMPORT  GPIO_WriteBit
        IMPORT  GPIO_SetAsInput

 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
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

; iMx6 wandboard has 1 SPI interface exposed
; it has 2 chipselect lines within the interface, and there are
; 8 additional I/O lines on the connector. These can be optionally
; requested by setting the relevant bit in
; the relevant call to the hal device
; main pins: CSPI1_(MOSI,MISO,SCLK,CS0,CS1)
; additional GPIO pins which are bitmapped.
; MOSI  via pin EIM_D18  alt 1 i/o
; MISO          EIM_D17  alt 1 i/o
; SCLK          EIM_D16  alt 1 i/o
; SS0           EIM_EB2  alt 1 i/o
; SS1           Key_Col2 alt 0 i/o
; bit 0 gpio3_11 via pin EIM_DA11 mux alt 5
; bit 1 gpio3_27     pin EIM_D27  mux alt 5
; bit 2 gpio6_31     pin EIM_BCLK  mux alt 5
; bit 3 gpio1_24     pin ENET_RX_ERR mux alt 5
; bit 4 gpio7_8      pin SD3_RST  mux alt 5
; bit 5 gpio3_26     pin EIM_D26  mux alt 5
; bit 6 gpio3_8      pin EIM_DA8  mux alt 5
; bit 7 gpio4_5      pin GPIO_19  mux alt 5



SPI_Init        ROUT
        Entry   "a1 - a3, v1"
 DebugTX "SPI init"
; set the pins up
        ldr     a2, [sb, #:INDEX:IOMUXC_Base]
; first the pad control stuff
        ldr     a3, =IOMuxPadSPI             ; pad drive stuff for SPI pins
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D18-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D17-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_D16-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_EIM_EB2-IOMUXC_BASE_ADDR]     ;
        str     a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_COL2-IOMUXC_BASE_ADDR]     ;


; then the daisychain stuff
        mov     a3, #0          ; select daisychain stuff for CSPI1
        str     a3, [a2,#IOMUXC_ECSPI1_IPP_CSPI_CLK_IN_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ECSPI1_IPP_IND_MISO_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ECSPI1_IPP_IND_MOSI_SELECT_INPUT-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_ECSPI1_IPP_IND_SS_B_0_SELECT_INPUT-IOMUXC_BASE_ADDR]
        mov     a3, #SEL_KEY_COL2_ALT0          ; select daisychain stuff for CSPI1 SS1
        str     a3, [a2,#IOMUXC_ECSPI1_IPP_IND_SS_B_1_SELECT_INPUT-IOMUXC_BASE_ADDR]

; finally the pad mux stuff
        mov     a3, #1                  ; alt 1, sion off
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D18-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D17-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_D16-IOMUXC_BASE_ADDR]
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_EIM_EB2-IOMUXC_BASE_ADDR]
        mov     a3, #0                  ; alt 0, sion off
        str     a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_COL2-IOMUXC_BASE_ADDR]

        ; set up ECSPI clock frequency
        ; input clock is 480/8MHZ = 60MHz
        ldr     a2, CCM_Base
        ldr     a3, [a2, #CCM_CSCDR2_OFFSET]
        bic     a3, a3, # (&3f<<24)
        orr     a3, a3, # (0<<24)        ; ECSPI_clk div 2^0 = 1
        str     a3, [a2, #CCM_CSCDR2_OFFSET]
ECSPIClkIn      *       60000000         ; 60 MHz clk rate
ECSPISlowClkIn  *       32768            ; 32khz slow clock



; at this stage, ignore the extra IO..20151012jwb






; now initialise the actual device
; just hold it in reset till the device activation call is made
; it is probable set this way anyway, but .. belt and braces
        bl      SPIResetInternal


; now report device presence
        ADRL    v1, SPI_Device
        MOV     a1, v1
        ADR     a2, SPIDeviceTemplate
        MOV     a3, #SPIDeviceSize
        BL      memcpy
        mov     a1, v1          ; SPI_sb referenced to from device
        str     sb, SPI_sb
        ldr     a1, SPI_Log
        str     a1, [v1, #SPIadr-SPIDeviceTemplate]
        MOV     a1, #0
        MOV     a2, v1
        CallOS  OS_AddDevice
; DebugTX "Device added "
        EXIT


; Generic HAL device used for all board types
SPIDeviceTemplate
        DCW     HALDeviceType_Comms + HALDeviceComms_SPI
        DCW     HALDeviceID_SPI_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     0               ; API version
        DCD     SPIDesc         ; Description
SPIadr  DCD     0               ; Address (filled in later)
        %       12              ; Reserved
        DCD     SPIActivate
        DCD     SPIDeactivate
        DCD     SPIReset
        DCD     SPISleep
        DCD     -1              ; Device (none)
        DCD     0               ; TestIRQ
        DCD     0               ; ClearIRQ
        %       4
        ASSERT  (.-SPIDeviceTemplate) = HALDeviceSize
SPI_cap DCD     SPICapabilities
SPI_cnf DCD     SPIConfigure
SPI_tfr DCD     SPITransfer
SPI_pin DCD     SPIPinMap       ; routine to control pins for io decode
        DCD     4
        DCD     4
        DCD     4
        ASSERT  (.-SPIDeviceTemplate) = HALDevice_SPI_Size

SPIDesc
        =       "iMx6 SPI interface", 0
        ALIGN

; routine to handle available io pins for iodecode
; and to claim pins and map them in for use
; on entry a1->this HAL_SPIDevice
; if a2 = 0 then return ptr to SPI_PinMapList
;    a1-> SPI_PinMapList on exit
; if a2 = 1 then map pin in a2 to decode bit in a4
;       a3 = pin specifier as reported in report call a0=0
;       a4 bits7-4 = relevant chip select, 3-0 = bit significance
; if a2 = 2 then set pins value to
;       a4 bits7-4 = relevant chip select, 3-0 = value
; if a2 = 44 and a3 =-44 then free all mapping to start again
SPIPinMap
        Entry   "v1,v2,v3,sb"
        ldr     sb, SPI_sb
        teq     a2, #0
        bne     %ft1
; report available pins
        adr     a1, SPI_PinMapList
        EXIT
1       teq     a2, #1
        bne     %ft2
; map pin in.. initialise for output
        and    lr, a4, #&f<<4
        cmp    lr, #SPI_Max_CSCount<<4       ; valid CS line?
        mov    lr, lr, lsr #2                ; as byte offset
        EXIT   GE                            ; no
        and    a4, a4, #&f                   ; isolate bit signifier
        cmp    a4, #4
        EXIT   GE                            ; we dont support more than 4 bits
        add    a4, a4, lr                    ; offset to relevant pin byte
; now select pin as o/p and initialise state
;       find which entry (a3 = pinspec, a4 = offset to hal pin store loc)
        adr    lr, SPI_PinMapList + SPIP_pin
12      ldr    v3, [lr]
        teq    v3, a3
        beq    %ft11
        cmp    v3, #0
        EXIT   EQ                            ; list end found
        add    lr, lr, #SPIP_len
        b      %bt12
11      ldr    v3, IOMUXC_Base
;       setup the mux
        ldr    v1, [lr, #SPIP_internal1]
        ldr    v2, [lr, #SPIP_internal3]          ; mux value
        str    v2, [v3, v1]

;       set up the pad ctl
        ldr    v1, [lr, #SPIP_internal2]
        ldr    v2, =IOMuxPadSPI              ; pad value
        str    v2, [v3, v1]
;       set it as output
        adrl   lr, SPI_Pins0
        strb   a3, [lr, a4]                  ; set it in place
        mov    a1, a3
        bl     GPIO_SetAsOutput              ; pin is now an output
        EXIT
2       teq     a2, #2
        beq     SetPinsAdd
3       teq     a2, #44
        EXIT    NE
        adds    a2, a2, a3
        EXIT    NE               ; oops.. a2 <> -a3
; flush all pin mapping
        mov     v2, #8           ; we only handle 8 pins (4 per channel)
        adrl    v1, SPI_Pins0
        mov     a2, #0
32      ldrb    v3, [v1], #1
        teq     v3, #0
        beq     %ft31
        strb    a2, [v1, #-1]    ; flush entry
        bl      GPIO_SetAsInput  ; not quite disable, set pin to read state
31      subs    v2, v2, #1
        bgt     %bt32
        EXIT

; at this point sb already pointed correctly..
; and a1->HALDevice, preserved
; this address called
SetPinsAddress ALTENTRY
; set relevant pinset to required value
;
; this address jumped to from above
SetPinsAdd
        mov     a2, a4, lsr #4
        cmp     a2, #SPI_Max_CSCount
        EXIT    GE
        Push    "a1"
        mov     v2, #4
        adrl    v1, SPI_Pins0     ; referenced from a1
        mov     a3, #4            ; 4 pins per channel
        mul     a3, a2, a3        ; point to correct pinset
        add     v1, v1, a3
22      ldrb    a1, [v1], #1      ; 1 byte per pin
        teq     a1, #0
        beq     %ft21
        tst     a4, #1<<0
        biceq   a1, a1, #1<<8
        orrne   a1, a1, #1<<8
        bl      GPIO_WriteBit
21      subs    v2, v2, #1
        mov     a4, a4, lsr #1   ; next bit
        bgt     %bt22
        Pull    "a1"
        EXIT


; list of mappable GPIO pins -- usable as I/O decode pins
; format is
; int     HAL Pin Specifier (GPIO#<<5 (1-7) + bitno (0-31) + initial state<<8)
; int     hardware address for pad mux register
; int     hardware address for pad ctl register
; char[12] pin name, null terminated
;
SPI_PinMapList
        DCD     ((3<<5)+11+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_DA11-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_EIM_DA11-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO3_11",0         ; must be 9 to 12 chars inc null
        ALIGN
        DCD     ((3<<5)+27+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_D27-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_EIM_D27-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO3_27",0
        ALIGN
        DCD     ((6<<5)+31+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_BCLK-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_EIM_BCLK-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO6_31",0
        ALIGN
        DCD     ((1<<5)+24+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_ENET_RX_ER-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_ENET_RX_ER-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO1_24",0
        ALIGN
        DCD     ((7<<5)+8+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_SD3_RST-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_SD3_RST-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO7_8",0,0
        ALIGN
        DCD     ((3<<5)+26+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_D26-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_EIM_D26-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO3_26",0
        ALIGN
        DCD     ((3<<5)+8+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_EIM_DA8-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_EIM_DA8-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO3_8",0,0
        ALIGN
        DCD     ((4<<5)+5+(0<<8))
        DCD     IOMUXC_SW_MUX_CTL_PAD_GPIO_19-IOMUXC_BASE_ADDR
        DCD     IOMUXC_SW_PAD_CTL_PAD_GPIO_19-IOMUXC_BASE_ADDR
        DCD     5
        =       "GPIO4_5",0,0
        ALIGN
        DCD     0              ; end of list
        ALIGN

; enable and initial config of spi interface
; on entry a1->this HAL_SPIDevice
SPIActivate
        Entry   "sb"
        ldr     sb, SPI_sb
        ldr     a2, CCM_Base
        ldr     a3, [a2, #CCM_CCGR1_OFFSET]
        orr     a3, a3, #3<<0           ; ECSPI1 clock on
        str     a3, [a2, #CCM_CCGR1_OFFSET]


        EXIT


; deactivate and reset behave the same, and put the device in reset state
SPIResetInternal
        Entry   "sb"
        ldr     a4, SPI_Log
        b       %ft1
; external call.
; on entry a1->this HAL_SPIDevice
SPIDeactivate
SPIReset
        ALTENTRY
        ldr     sb, SPI_sb
        ldr     a4, [a1,#SPIadr-SPIDeviceTemplate]
1       mov     a3, #0
        str     a3, [a4, #ECSPI_CONREG_OFFSET]
        ldr     a2, CCM_Base
        ldr     a3, [a2, #CCM_CCGR1_OFFSET]
        bic     a3, a3, #3<<0           ; ECSPI1 clock off
        str     a3, [a2, #CCM_CCGR1_OFFSET]
        EXIT

SPISleep
        MOV     a1, #0
        MOV     pc, lr

SPIClkPreDiv     *       &f                        ; represents div by 1 to 16
SPIClkPostDiv    *       &f                        ; div by 2^0 to 2^15
; on entry, a1-> this HAL_SPIDevice
;           a2-> spi_capabilities structure to fill in
SPICapabilities
        Entry   "sb"
        ldr     sb, SPI_sb
        str     a1, [a2,#SPIR_spidevice]
        ldr     a1, [a1,#SPIadr-SPIDeviceTemplate]
; word values
        add     a1, a1, #ECSPI_RXDATA_OFFSET
        str     a1, [a2, #SPIR_rdfifoaddr]
        add     a1, a1, #ECSPI_TXDATA_OFFSET-ECSPI_RXDATA_OFFSET
        str     a1, [a2, #SPIR_wrfifoaddr]
        add     a1, a1, #ECSPI_STATREG_OFFSET-ECSPI_TXDATA_OFFSET
        str     a1, [a2, #SPIR_wrpolladdr]
        str     a1, [a2, #SPIR_rdpolladdr]
        mov     a1, #1<<1                          ; bit 1, active hi
        str     a1, [a2, #SPIR_wrpollmask]         ; (tx fifo not full)
        mov     a1, #1<<3                          ; bit 3, active hi
        str     a1, [a2, #SPIR_rdpollmask]         ; (rx fifo not empty)
        ldr     a1, =ECSPIClkIn                    ; fast clock in Hz
        str     a1, [a2,#SPIR_fastclock]
        ldr     a1, =ECSPISlowClkIn                ; slow clock in Hz
        str     a1, [a2,#SPIR_slowclock]
        mov     a1, #&1000                         ; max burst length in bits
        str     a1, [a2,#SPIR_maxburstbitlength]
        mov     a1, #&0                            ; max HT burst length in bits
        str     a1, [a2,#SPIR_maxhtbits]
        mov     a1, #64*4                          ; fifo length bytes
        str     a1, [a2,#SPIR_rxfifosize]
        str     a1, [a2,#SPIR_txfifosize]
        mov     a1, #16*4                          ; msg data fifo length bytes
        str     a1, [a2,#SPIR_msgdatafifosize]
        mov     a1, #63                            ; max chip select delay
        str     a1, [a2,#SPIR_maxdelaySS2CLK]
        ldr     a1, =&7fff                         ; max sample period clocks
        str     a1, [a2,#SPIR_maxSPdelay]
; byte values
        mov     a1, #4                             ; data register 4 bytes wide
        strb    a1, [a2,#SPIR_datawidth]
        mov     a1, #SPIClkPreDiv                  ; max prediv (div 1 to 16)
        strb    a1, [a2,#SPIR_SPIClockprediv]
        mov     a1, #SPIClkPostDiv                 ; max postdiv 2^15
        strb    a1, [a2,#SPIR_SPIClockpostdiv]
        mov     a1, #(1<<0)+(1<<1)                 ; 2 channels can be masters
        strb    a1, [a2,#SPIR_mastermode]
        mov     a1, #(1<<0)+(1<<1)                 ; 2 channels can be slave
        strb    a1, [a2,#SPIR_mastermode]
        mov     a1, #(0<<0)+(1<<1)+(1<<2)+(1<<3)
        strb    a1, [a2,#SPIR_modes]
        mov     a1, #(1<<0)+(1<<1)                 ; 2 channels can be set
        strb    a1, [a2,#SPIR_SCLKrest]
        strb    a1, [a2,#SPIR_SDATArest]
        strb    a1, [a2,#SPIR_SSctl]
        strb    a1, [a2,#SPIR_SCLKpol]
        strb    a1, [a2,#SPIR_SSCLKphase]
        EXIT

; read config structure and program chip accordingly
; on entry, a1-> this HAL_SPIDevice
;           a2-> spi_settings structure to set to device
SPIConfigure
        Entry   "v1,v2,sb"
        ldr     sb, SPI_sb
        ldr     a4, [a1,#SPIadr-SPIDeviceTemplate]
; disable device
        mov     a3, #0                            ; disable
        str     a3, [a4, #ECSPI_CONREG_OFFSET]
; set the configuration
        ldr     a1, [a2,#SPIS_clock]              ; clock wanted
        bl      ComputeClockSettings
        str     a1, [a2,#SPIS_clock]              ; clock wanted
; at this point a3 contains the clock bits needed in ECSPI_CONREG_OFFSET
        ldr     a1, [a2,#SPIS_burstlength]        ;
        cmp     a1, #0
        subgt   a1, a1, #1                        ; correct to 0 = 1 bit
        orr     a3, a3, a1, lsl #20               ; to place
        ldrb    a1, [a2,#SPIS_drcontrol]          ;
        cmp     a1, #2                            ; sanity check
        movgt   a1, #0
        orr     a3, a3, a1, lsl #16
        ldrb    a1, [a2,#SPIS_mode]               ;
        cmp     a1, #3                            ; sanity check . 2 channel max
        movgt   a1, #0                            ; all as slave mode
        orr     a3, a3, a1, lsl #4
        ldrb    a1, [a2,#SPIS_modebits]           ;
        orr     a1, a1, #1<<4                     ; flag we've used these
        strb    a1, [a2,#SPIS_modebits]           ;
        and     a1, a1, #&f                       ; sanity check
        and     lr, a1, #(1<<1)
        orr     a3, a3, lr, lsl #2                ; SMC bit
        and     lr, a1, #(1<<2)
        orr     a3, a3, lr                        ; XCH bit
        ldr     lr, [a4, #ECSPI_PERIODREG_OFFSET]
        tst     a1, #(1<<3)                       ; slow clock for delay
        biceq   lr, lr, #(1<<15)                  ; use normal spi clock
        orrne   lr, lr, #(1<<15)                  ; use slow clock
        str     lr, [a4, #ECSPI_PERIODREG_OFFSET]
        ldrb    lr, [a2,#SPIS_SCLKlevel]          ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        mov     v1, lr, lsl #20                   ; SCLK_CTL
        ldrb    lr, [a2,#SPIS_SDATAlevel]         ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        orr     v1, v1, lr, lsl #16               ; DATA_CTL
        ldrb    lr, [a2,#SPIS_SSlevel]            ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        orr     v1, v1, lr, lsl #12               ; SS_POL
        ldrb    lr, [a2,#SPIS_SPIburst]           ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        orr     v1, v1, lr, lsl #8                ; SS_CTL
        ldrb    lr, [a2,#SPIS_SCLKpol]            ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        orr     v1, v1, lr, lsl #4                ; SCLK_POL
        ldrb    lr, [a2,#SPIS_SCLKphase]          ;
        cmp     lr, #3                            ; sanity check . 2 channel max
        movgt   lr, #3                            ; all as inactive high
        orr     v1, v1, lr, lsl #0                ; SCLK_PHA

;reenable the device
        orr     a3, a3, #(1<<0)                   ; enable
        str     a3, [a4, #ECSPI_CONREG_OFFSET]
        str     v1, [a4, #ECSPI_CONFIG_OFFSET]    ; and then configure
        ldr     lr, =((0<<16) + 32)               ; rx and tx fifo threashold
        str     lr, [a4, #ECSPI_DMAREG_OFFSET]

        EXIT

; on entry, a1 = desired clock rate
; on exit a3 = achieved clock rate
;         v1 contains required ECSPI_CONREG bits set for pre & post divider
ComputeClockSettings
        Entry   "a2,a4,v1,v2"
refclk  RN      a2
wantclk RN      a1
divi    RN      a4
pre     RN      v1
post    RN      v2
work    RN      a3
temp    RN      lr
        ldr     refclk, =ECSPIClkIn         ; ref clock rate
        DivRem  divi, refclk, wantclk, temp ; divi = refclk/wantedclk
        ldr     refclk, =ECSPIClkIn         ; ref clock rate
        DivRem  work, refclk, divi, temp    ; refclk/divi
        cmp     work, wantclk               ; > wanted?
        addgt   divi, divi, #1              ; yes.. make divi bigger
        mov     pre, #1                     ; initialise
        mov     post, #0                    ;   ditto
001     mov     work, #1
        mov     work, work, lsl post        ; 1<<post
        mul     work, pre, work             ; pre * (1<<post)
        cmp     work, divi                  ; less than divi?
        cmplt   post, #16                   ; and post value legit
        bge     %ft002                      ; completed if either too big
004     mov     work, #1
        mov     work, work, lsl post
        mul     work, pre, work
        cmp     work, divi
        cmplt   pre, #17
        bge     %ft003                      ; completed if either too big
        addlt   pre, pre, #1
        blt     %bt004
003     cmp     pre, #16
        addgt   post, post, #1
        movgt   pre, #1
        b       %bt001
002
        ldr     wantclk, =ECSPIClkIn        ; ref clock rate
        mov     work, pre                   ;
        DivRem  refclk, wantclk, work, temp ; first divider
        mov     work, #1
        mov     work, work, lsl post
        DivRem  wantclk, refclk, work, temp
        sub     pre, pre, #1               ; correct for value 0 = div 1
        mov     work, pre, lsl #12
        orr     work, work, post, lsl #8   ; and the clock elements needed
        EXIT

; initiate spi transfer
; on entry, a1-> this HAL_device
;           a2-> spi_transfer structure for this transfer
SPITransfer
        Entry   "v1,v2,sb"
        ldr     sb, SPI_sb
        ldr     a4, [a1,#SPIadr-SPIDeviceTemplate]
        ldrb    a3, [a2,#SPIT_dma_mode]
        Push    "a1,a2"
        ldr     a2, [a2, #SPIT_spisettings]
        ldrb    a1, [a2,#SPIS_modebits]    ;
        tst     a1, #1<<4                  ; have we set up yet?
        bleq    SPIConfigure               ; no? .. do so
        Pull    "a1,a2"
        ldr     lr, [a4, #ECSPI_CONREG_OFFSET]
        mov     lr, lr, lsl #14            ; clear burst and channel select bits
        mov     lr, lr, lsr #14
        ldrb    a3, [a2,#SPIT_channel]     ;
        and     v1, a3, #3<<4
        orr     lr, lr, v1, lsl #14        ; channel select

        Push    "a1-a4, lr"
        and     a4, a3, #&f
        bl      SetPinsAddress
        Pull    "a1-a4, lr"

        ldr     a3, [a2,#SPIT_burstlength] ;
        cmp     a3, #0
        subgt   a3, a3, #1                 ; correct burst len 0 = 1 bit
        orr     lr, lr, a3, lsl #20        ; to place
        ldrb    a3, [a2,#SPIT_channel]     ;
        and     a3, a3, #3<<4
        bic     lr, lr, #3<<14
        orr     lr, lr, a3
        str     lr, [a4, #ECSPI_CONREG_OFFSET] ; insert this burst len

        tst     a3, #1<<0                  ; check if dma needed
        bne     SPITdma
        ; its a non dma transfer, so we just need to make sure the
        ; settings are in place, and launch the transfer
        ; check whether we need to initiate with XCH or rely on write to fifo
        ; this may need more work
        EXIT
SPITdma                                    ; dma needed for this transfer
        EXIT

        END
