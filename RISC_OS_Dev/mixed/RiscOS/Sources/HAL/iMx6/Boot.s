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
        GET     Hdr:HALSize.<HALSize>

        GET     Hdr:MEMM.VMSAv6

        GET     Hdr:Proc
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries

        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.SDRC
        GET     hdr.Timers
        GET     hdr.GPIO
        GET     hdr.Copro15ops
        GET     hdr.UART
        GET     hdr.PRCM
        GET     hdr.AHCI

; This version assumes a RISC OS image starting OSROM_HALSize after us.

; FIQs are not available on Cortex-A9 (outside the secure world)
; FIQ-based debugger - prints out the PC when the beagleboard/touchbook USER button is pressed
; The code installs itself when HAL_InitDevices is called with R0=123.
; e.g. SYS "OS_Hardware",123,,,,,,,,0,100
                GBLL    FIQDebug
FIQDebug        SETL    {FALSE}

                GBLL    MoreDebug
MoreDebug       SETL    Debug :LAND: {TRUE}

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  rom_checkedout_ok

        IMPORT  HAL_Base
        IMPORT  HAL_WsBase
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
        IMPORT  DebugCallstack
 ]
        IMPORT  TPSRead
        IMPORT  TPSWrite
        IMPORT  IIC_DoOp_Poll
        IMPORT  HWLogicalInit

; v8 is used as pointer to RISC OS entry table throughout pre-MMU stage.
        MACRO
        CallOSM $entry, $reg
        LDR     ip, [v8, #$entry*4]
        MOV     lr, pc
        ADD     pc, v8, ip
        MEND

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

rom_checkedout_ok
; DebugTX "Start to add ram "

        ; On entry, v8 -> OS entry table, sb -> HAL workspace
        ; v4 = 1 past end of ram
        ; Register the attached RAM
        ;
        ; At this stage, we assume that we have 1 contiguous block of RAM
        ; starting at 0x10000000

        mov     a2, #&10000000
        mov     a3, v4
;        DebugReg a2, "Adding RAM from "
;        DebugReg a3, "Adding RAM to "
        MVN     a4, #0
        MOV     a1, #0
        STR     a1, [sp, #-4]!  ;reference handle (NULL for first call)
        CallOSM OS_AddRAM
;        DebugTX  "Added "


        ; check for reset cause: test PRM_RSTST.GLOBAL_COLD_RST
;        LDR     a3, =L4_PowerMan
;        ADD     a3, a3, #DEVICE_PRM
;        LDR     a2, [a3, #PRM_RSTST]
;        STR     a2, [a3, #PRM_RSTST]    ; clear old status
;        TST     a2, #1                  ; GLOBAL_COLD_RST
        MOV     a4, a1
;        MOVNE   a1, #(OSStartFlag_RAMCleared :OR: OSStartFlag_POR)
;        MOVEQ   a1, #OSStartFlag_RAMCleared
        MOV     r0, #0
        MCR     p15,0,r0,c12,c0           ; set the vector base to 0 ready for MMU on

      [ ClearRAM
        MOV   a1, #(OSStartFlag_RAMCleared :OR: OSStartFlag_POR)
      |
        MOV   a1, #OSStartFlag_POR
      ]
        ADRL    a2, HAL_Base + OSROM_HALSize - IVTLoaderSize  ; a2 -> RISC OS image
        ADR     a3, HALdescriptor
        CallOSM OS_Start


HALdescriptor   DATA
        DCD     HALFlag_NCNBWorkspace
        DCD     HAL_Base - HALdescriptor - IVTLoaderSize; 4 k aligned
        DCD     OSROM_HALSize ;- IVTLoaderSize        ; needs to be 4k multiple
        DCD     HAL_EntryTable - HALdescriptor
        DCD     HAL_Entries
        DCD     HAL_WsSize


        MACRO
        HALEntry $name
        ASSERT  (. - HAL_EntryTable) / 4 = EntryNo_$name
        DCD     $name - HAL_EntryTable
        MEND

        MACRO
        NullEntry
        DCD     HAL_Null - HAL_EntryTable
        MEND

        IMPORT  Interrupt_Init
        IMPORT  Timer_Init
        IMPORT  PRCM_SetClocks
        IMPORT  USB_Init
        IMPORT  I2C_Init
        IMPORT  RTC_Init
        IMPORT  VideoDevice_Init
        IMPORT  Audio_Init
        IMPORT  Audio_InitDevices
        IMPORT  Ether_Init
        IMPORT  GPIO_Init
        IMPORT  SPI_Init
        IMPORT  GPIO_DeviceInit
        IMPORT  SDIO_InitDevices
        IMPORT  DMA_Init
        IMPORT  DMA_InitDevices
        IMPORT  NVMemory_Init
        IMPORT  NVMemory_InitDevice
        IMPORT  PL310_InitDevice

        IMPORT  HAL_IRQEnable
        IMPORT  HAL_IRQDisable
        IMPORT  HAL_IRQClear
        IMPORT  HAL_IRQSource
        IMPORT  HAL_IRQStatus
        IMPORT  HAL_FIQEnable
        IMPORT  HAL_FIQDisable
        IMPORT  HAL_FIQDisableAll
        IMPORT  HAL_FIQClear
        IMPORT  HAL_FIQSource
        IMPORT  HAL_FIQStatus
        IMPORT  HAL_IRQMax

        IMPORT  HAL_Timers
        IMPORT  HAL_TimerDevice
        IMPORT  HAL_TimerGranularity
        IMPORT  HAL_TimerMaxPeriod
        IMPORT  HAL_TimerSetPeriod
        IMPORT  HAL_TimerPeriod
        IMPORT  HAL_TimerReadCountdown
        IMPORT  HAL_TimerIRQClear

        IMPORT  HAL_CounterRate
        IMPORT  HAL_CounterPeriod
        IMPORT  HAL_CounterRead
        IMPORT  HAL_CounterDelay

        IMPORT  HAL_IICBuses
        IMPORT  HAL_IICType
        IMPORT  HAL_IICSetLines
        IMPORT  HAL_IICReadLines
        IMPORT  HAL_IICDevice
        IMPORT  HAL_IICTransfer
        IMPORT  HAL_IICMonitorTransfer

        IMPORT  HAL_NVMemoryType
        IMPORT  HAL_NVMemoryIICAddress
        IMPORT  HAL_NVMemorySize
        IMPORT  HAL_NVMemoryPageSize
        IMPORT  HAL_NVMemoryProtectedSize
        IMPORT  HAL_NVMemoryProtection
        IMPORT  HAL_NVMemoryRead
        IMPORT  HAL_NVMemoryWrite

 [ VideoInHAL
        IMPORT  Video_init
        IMPORT  HAL_VideoFlybackDevice
        IMPORT  HAL_VideoSetMode
        IMPORT  HAL_VideoWritePaletteEntry
        IMPORT  HAL_VideoWritePaletteEntries
        IMPORT  HAL_VideoReadPaletteEntry
        IMPORT  HAL_VideoSetInterlace
        IMPORT  HAL_VideoSetBlank
        IMPORT  HAL_VideoSetPowerSave
        IMPORT  HAL_VideoUpdatePointer
        IMPORT  HAL_VideoSetDAG
        IMPORT  HAL_VideoVetMode
        IMPORT  HAL_VideoPixelFormats
        IMPORT  HAL_VideoFeatures
        IMPORT  HAL_VideoBufferAlignment
        IMPORT  HAL_VideoOutputFormat
        IMPORT  HAL_VideoFramestoreAddress
        IMPORT  HAL_VideoStartupMode
        IMPORT  HAL_VideoPixelFormatList
 ]
        IMPORT  HAL_VideoIICOp ; Implemented in s.I2C

        IMPORT  HAL_UARTPorts
        IMPORT  HAL_UARTStartUp
        IMPORT  HAL_UARTShutdown
        IMPORT  HAL_UARTFeatures
        IMPORT  HAL_UARTReceiveByte
        IMPORT  HAL_UARTTransmitByte
        IMPORT  HAL_UARTLineStatus
        IMPORT  HAL_UARTInterruptEnable
        IMPORT  HAL_UARTRate
        IMPORT  HAL_UARTFormat
        IMPORT  HAL_UARTFIFOSize
        IMPORT  HAL_UARTFIFOClear
        IMPORT  HAL_UARTFIFOEnable
        IMPORT  HAL_UARTFIFOThreshold
        IMPORT  HAL_UARTInterruptID
        IMPORT  HAL_UARTBreak
        IMPORT  HAL_UARTModemControl
        IMPORT  HAL_UARTModemStatus
        IMPORT  HAL_UARTDevice
        IMPORT  HAL_UARTDefault

        IMPORT  HAL_DebugRX
        IMPORT  HAL_DebugTX

        IMPORT  HAL_PlatformName

        IMPORT  HAL_KbdScanDependencies

        IMPORT  HAL_USBControllerInfo
        IMPORT  HAL_USBPortPower
        IMPORT  HAL_USBPortIRQStatus
        IMPORT  HAL_USBPortIRQClear

        IMPORT  SATA_Init
        IMPORT  HAL_Watchdog
        IMPORT  CPU_Speed_Init


HAL_EntryTable  DATA
        HALEntry HAL_Init

        HALEntry HAL_IRQEnable
        HALEntry HAL_IRQDisable
        HALEntry HAL_IRQClear
        HALEntry HAL_IRQSource
        HALEntry HAL_IRQStatus
        HALEntry HAL_FIQEnable
        HALEntry HAL_FIQDisable
        HALEntry HAL_FIQDisableAll
        HALEntry HAL_FIQClear
        HALEntry HAL_FIQSource
        HALEntry HAL_FIQStatus

        HALEntry HAL_Timers
        HALEntry HAL_TimerDevice
        HALEntry HAL_TimerGranularity
        HALEntry HAL_TimerMaxPeriod
        HALEntry HAL_TimerSetPeriod
        HALEntry HAL_TimerPeriod
        HALEntry HAL_TimerReadCountdown

        HALEntry HAL_CounterRate
        HALEntry HAL_CounterPeriod
        HALEntry HAL_CounterRead
        HALEntry HAL_CounterDelay

        HALEntry HAL_NVMemoryType
        HALEntry HAL_NVMemorySize
        HALEntry HAL_NVMemoryPageSize
        HALEntry HAL_NVMemoryProtectedSize
        HALEntry HAL_NVMemoryProtection
        HALEntry HAL_NVMemoryIICAddress
        HALEntry HAL_NVMemoryRead
        HALEntry HAL_NVMemoryWrite

        HALEntry HAL_IICBuses
        HALEntry HAL_IICType
        HALEntry HAL_IICSetLines
        HALEntry HAL_IICReadLines
        HALEntry HAL_IICDevice
        HALEntry HAL_IICTransfer
        HALEntry HAL_IICMonitorTransfer

 [ VideoInHAL
        HALEntry HAL_VideoFlybackDevice
        HALEntry HAL_VideoSetMode
        HALEntry HAL_VideoWritePaletteEntry
        HALEntry HAL_VideoWritePaletteEntries
        HALEntry HAL_VideoReadPaletteEntry
        HALEntry HAL_VideoSetInterlace
        HALEntry HAL_VideoSetBlank
        HALEntry HAL_VideoSetPowerSave
        HALEntry HAL_VideoUpdatePointer
        HALEntry HAL_VideoSetDAG
        HALEntry HAL_VideoVetMode
        HALEntry HAL_VideoPixelFormats
        HALEntry HAL_VideoFeatures
        HALEntry HAL_VideoBufferAlignment
        HALEntry HAL_VideoOutputFormat
 |
        NullEntry ; HAL_VideoFlybackDevice
        NullEntry ; HAL_VideoSetMode
        NullEntry ; HAL_VideoWritePaletteEntry
        NullEntry ; HAL_VideoWritePaletteEntries
        NullEntry ; HAL_VideoReadPaletteEntry
        NullEntry ; HAL_VideoSetInterlace
        NullEntry ; HAL_VideoSetBlank
        NullEntry ; HAL_VideoSetPowerSave
        NullEntry ; HAL_VideoUpdatePointer
        NullEntry ; HAL_VideoSetDAG
        NullEntry ; HAL_VideoVetMode
        NullEntry ; HAL_VideoPixelFormats
        NullEntry ; HAL_VideoFeatures
        NullEntry ; HAL_VideoBufferAlignment
        NullEntry ; HAL_VideoOutputFormat
 ]

        NullEntry ; HALEntry HAL_MatrixColumns
        NullEntry ; HALEntry HAL_MatrixScan

        NullEntry ; HALEntry HAL_TouchscreenType
        NullEntry ; HALEntry HAL_TouchscreenRead
        NullEntry ; HALEntry HAL_TouchscreenMode
        NullEntry ; HALEntry HAL_TouchscreenMeasure

        HALEntry HAL_MachineID
        HALEntry HAL_ControllerAddress
        HALEntry HAL_HardwareInfo
        HALEntry HAL_SuperIOInfo
        HALEntry HAL_PlatformInfo
        NullEntry ; HALEntry HAL_CleanerSpace

        HALEntry HAL_UARTPorts
        HALEntry HAL_UARTStartUp
        HALEntry HAL_UARTShutdown
        HALEntry HAL_UARTFeatures
        HALEntry HAL_UARTReceiveByte
        HALEntry HAL_UARTTransmitByte
        HALEntry HAL_UARTLineStatus
        HALEntry HAL_UARTInterruptEnable
        HALEntry HAL_UARTRate
        HALEntry HAL_UARTFormat
        HALEntry HAL_UARTFIFOSize
        HALEntry HAL_UARTFIFOClear
        HALEntry HAL_UARTFIFOEnable
        HALEntry HAL_UARTFIFOThreshold
        HALEntry HAL_UARTInterruptID
        HALEntry HAL_UARTBreak
        HALEntry HAL_UARTModemControl
        HALEntry HAL_UARTModemStatus
        HALEntry HAL_UARTDevice
        HALEntry HAL_UARTDefault

        HALEntry HAL_DebugRX
        HALEntry HAL_DebugTX

        NullEntry ; HAL_PCIFeatures
        NullEntry ; HAL_PCIReadConfigByte
        NullEntry ; HAL_PCIReadConfigHalfword
        NullEntry ; HAL_PCIReadConfigWord
        NullEntry ; HAL_PCIWriteConfigByte
        NullEntry ; HAL_PCIWriteConfigHalfword
        NullEntry ; HAL_PCIWriteConfigWord
        NullEntry ; HAL_PCISpecialCycle
        NullEntry ; HAL_PCISlotTable
        NullEntry ; HAL_PCIAddresses

        HALEntry HAL_PlatformName;was HAL_ATAControllerInfo
        NullEntry ; HAL_ATASetModes
        NullEntry ; HAL_ATACableID

        HALEntry HAL_InitDevices

        HALEntry HAL_KbdScanDependencies
        NullEntry ; Unused
        NullEntry ; Unused
        NullEntry ; Unused

        HALEntry HAL_PhysInfo

        HALEntry HAL_Reset

        HALEntry HAL_IRQMax

        HALEntry HAL_USBControllerInfo
        HALEntry HAL_USBPortPower
        HALEntry HAL_USBPortIRQStatus
        HALEntry HAL_USBPortIRQClear
        NullEntry ; HAL_USBPortDevice

        HALEntry HAL_TimerIRQClear
        NullEntry ; HAL_TimerIRQStatus

        HALEntry HAL_ExtMachineID

 [ VideoInHAL
        HALEntry HAL_VideoFramestoreAddress
 |
        NullEntry ; HAL_VideoFramestoreAddress
 ]
        NullEntry ; HAL_VideoRender
 [ VideoInHAL
        HALEntry HAL_VideoStartupMode
        HALEntry HAL_VideoPixelFormatList
 |
        NullEntry ; HAL_VideoStartupMode
        NullEntry ; HAL_VideoPixelFormatList
 ]
        HALEntry HAL_VideoIICOp

        HALEntry HAL_Watchdog


HAL_Entries     *       (. - HAL_EntryTable) / 4


;--------------------------------------------------------------------------------------

; sb should -> hal workspace
; a1 =RISCOS_Header
; a2 =HALWorkspaceNCNB

HAL_Init
        Entry   "v1-v3"

        STR     a2, NCNBWorkspace
        STR     a2, NCNBAllocNext

        BL      SetUpOSEntries

        ; Map in the main IO ranges and then store the offsets to the components
        ; we're interested in
        MOV     a1, #0
        MOV     a2, #CPU_IOBase
        MOV     a3, #CPU_IOBaseSize
        CallOS  OS_MapInIO
        STR     a1, CPUIOBase              ; new logical address

; PCIe
        MOV     a1, #0
        MOV     a2, #PCIe_Base
        MOV     a3, #PCIe_BaseSize
        CallOS  OS_MapInIO
        STR     a1, PCIeBase

; main IO
        MOV     a1, #0
        MOV     a2, #Main_IOBase
        MOV     a3, #Main_IOBaseSize
        CallOS  OS_MapInIO
        STR     a1, MainIOBase              ; new logical address
        adrl    v1, HAL_WsBase              ; address in hal image
        sub     a1, a1, #Main_IOBase        ; convert to offset

        bl      HWLogicalInit               ; set up logical addresses of any
                                            ; hardware blocks we may use



 [ MoreDebug
        DebugTX "Starting HAL_Init"
 ]
       ; WhooWhoo.. once we're here we are back in charge
       ; we have a debug port working, if we need it
       ; and we know how to get at hardware in logical space.
       ; We've mapped in the 3 main i/o spaces, so..
       ;
       ; Lets get on with mapping and initialising!!
        LDR     a2, CPUIOBase             ; get logical address
; DebugReg a2, " CPUIOBase  "
        LDR     a2, MainIOBase            ; get logical address
; DebugReg a2, " MainIOBase "





 [ MoreDebug
        DebugTX "HAL_Init"
        DebugTime a1, "@ "
 ]

  [ MoreDebug
        DebugTX "PRCM Set Clocks"
 ] ; MoreDebug
       BL      PRCM_SetClocks  ; Calls Timer_init & starts GPTIMER5

 [ MoreDebug
        DebugTX "I2C_init"
 ] ; MoreDebug
        BL      I2C_Init        ; Uses GPTIMER5

        ; Make sure all GPIO IRQs are disabled before we potentially start enabling them
 [ MoreDebug
        DebugTX "GPIO_init"
 ] ; MoreDebug
        BL      GPIO_Init

 [ MoreDebug
        DebugTX "Audio_Init"
 ] ; MoreDebug
        BL      Audio_Init

        LDR     a2, HDMI_Log             ; HDMI base address
  DebugReg a2, "HDMI_Log "

 [ VideoInHAL
   [ MoreDebug
        DebugTX "Video_init"
   ] ; MoreDebug
        BL      Video_init      ; Uses GPTIMER5
 ] ; VideoInHAL

 [ MoreDebug
        DebugTX "USB_Init"
 ] ; MoreDebug
        BL      USB_Init        ;

 [ MoreDebug
        DebugTX "NVMemory_Init"
 ] ; MoreDebug
        BL      NVMemory_Init

 [ MoreDebug
        DebugTX "Timer_Init"
 ] ; MoreDebug
        BL      Timer_Init      ; Re-inits timers

 [ MoreDebug
        DebugTX "Interrupt_Init"
 ] ; MoreDebug
        BL      Interrupt_Init

 [ MoreDebug
        DebugTX "DMA_Init"
 ] ; MoreDebug
        BL      DMA_Init

; mov a1,#0
; ldr a2, =10000
; bl HAL_TimerSetPeriod
;11
; ldr a1, =2000000
; bl HAL_CounterDelay

; ldr a1,Timers_Log
; LDR a2, [a1, #GPT_GPTSR_OFFSET]
; tst a2, #1
; beq   %bt11
; mov a2, #1
; STR a2, [a1, #GPT_GPTSR_OFFSET]
; subs a3,a3,#1
; bgt %bt11
; mov a3, #100
; DebugReg a2
; b %bt11




        MOV     v1, #UART_Count
10      SUBS    v1, v1, #1
 [ Debug
        BLT     %FT20
        ; Don't reset the debug UART
        LDR     a3, DebugUART
        ADD     a2, sb, v1, LSL #2
        LDR     a2, [a2, #:INDEX:UART_Base]
        CMP     a3, a2
        BEQ     %BT10
        MOV     a1, v1
        ADR     lr, %BT10
        B       HAL_UARTStartUp
 |
        MOVGE   a1, v1
        ADRGE   lr, %BT10
        BGE     HAL_UARTStartUp
 ]
20

        ; Mark HAL as initialised
        STR     pc, HALInitialised ; Any nonzero value will do
 [ MoreDebug
        DebugTime a1, "HAL initialised @ "
 ]
        EXIT

;; Dodgy phys->log conversion using the mapped in IO ranges
;; In/out: a1 = offset into sb of address to get/put
;; Out: a2 = log addr
;; Corrupts a3
;phys2log
;        LDR     a3, [sb, a1]
;        CMP     a3, #0 ; Null pointers are valid; ignore them
;        MOVEQ   a2, #0
;        MOVEQ   pc, lr
;        LDR     a2, =L3_ABE
;        SUB     a2, a3, a2
;        CMP     a2, #L3_ABE_Size
;        LDRLO   a3, L3_Log
;        BLO     %FT10
;
;        SUB     a2, a3, #L4_Per
;        CMP     a2, #L4_Per_Size
;        LDRLO   a3, L4_Per_Log
;        BLO     %FT10
;
;        SUB     a2, a3, #L4_ABE
;        CMP     a2, #L4_ABE_Size
;        LDRLO   a3, L4_ABE_Log
;        BLO     %FT10
;
;        SUB     a2, a3, #L4_Core
;        CMP     a2, #L4_Core_Size
;        LDRLO   a3, L4_Core_Log
;        SUBHI   a2, a2, #(L4_Wakeup - L4_Core)
;        LDRHI   a3, L4_Wakeup_Log
;10
;        ADD     a2, a2, a3
;        STR     a2, [sb, a1]
;        MOV     pc, lr

; Initialise and relocate the entry table.
SetUpOSEntries  ROUT
        STR     a1, OSheader
        LDR     a2, [a1, #OSHdr_NumEntries]
        CMP     a2, #(HighestOSEntry + 1)
        MOVHI   a2, #(HighestOSEntry + 1)

        ADR     a3, OSentries
        LDR     a4, [a1, #OSHdr_Entries]
        ADD     a4, a4, a1

05      SUBS    a2, a2, #1
        LDR     ip, [a4, a2, LSL #2]
        ADD     ip, ip, a4
        STR     ip, [a3, a2, LSL #2]
        BNE     %BT05
        ; Fall through

HAL_Null
        MOV     pc, lr

HAL_InitDevices
 [ FIQDebug
        CMP     a1, #123
        BNE     %FT10
        LDR     a1, =&E51FF004
        ADR     a2, FIQRoutine
        MOV     a4, #&1C
        STMIA   a4,{a1-a2,sb}
        ; Sync cache
        MOV     a1, #0
        MCR     p15, 0, a1, c7, c11, 1 ; Clean DCache by VA to PoU
        myDSB ; wait for clean to complete
        MCR     p15, 0, a1, c7, c5, 1 ; invalidate ICache entry (to PoC)
        MCR     p15, 0, a1, c7, c5, 6 ; invalidate entire BTC
        myDSB ; wait for cache invalidation to complete
        myISB ; wait for BTC invalidation to complete?
        ; Now reconfigure the USER button (GPIO 7) to fire an FIQ
        LDR     a1, L4_GPIO1_Log
        LDR     a2, [a1, #GPIO_OE]
        ORR     a2, a2, #1:SHL:7 ; Configure as input
        STR     a2, [a1, #GPIO_OE]
        MOV     a2, #0
        STR     a2, [a1, #GPIO_LEVELDETECT0]
        STR     a2, [a1, #GPIO_LEVELDETECT1]
        STR     a2, [a1, #GPIO_FALLINGDETECT]
        MOV     a2, #1:SHL:7
        STR     a2, [a1, #GPIO_RISINGDETECT] ; Enable IRQ on rising edge
        STR     a2, [a1, #GPIO_IRQENABLE1] ; Set MPU as interrupt target
        MOV     a1, #29 ; GPIO1 IRQ
        ; tail-optimised, repeating the HAL device init would be a bad thing!
        B       HAL_FIQEnable
10
 ]
        Entry   "v1-v3"
;        DebugReg a1, "HAL_InitDevices @ "
        ; Common HAL devices
;        DebugTX "GPIO_HALDevice"
        BL      GPIO_DeviceInit
;        DebugTX "rtc"
        BL      RTC_Init
;        DebugTX "sdma"
        BL      DMA_InitDevices
;        DebugTX "vdev"
        BL      VideoDevice_Init
;        DebugTX "audio"
        BL      Audio_InitDevices
;        DebugTX "ethernet"
        BL      Ether_Init        ; SATA is dependant on enet pll, so init before sata
;        DebugTX "SATA"
        BL      SATA_Init
;        DebugTX "SDIO"
        BL      SDIO_InitDevices
;        DebugTX "SPI"
        BL      SPI_Init
        BL      PL310_InitDevice
        BL      NVMemory_InitDevice

        DebugTX "CPUSpeed device"
        bl      CPU_Speed_Init
        DebugTX "done"
        ; Board-specific HAL devices
;        LDR     pc, [sb, #BoardConfig_InitDevices]

Board_InitDevices_None
        EXIT



HAL_ControllerAddress
        MOV     a1, #0
        MOV     pc, lr

HAL_HardwareInfo
        LDR     ip, =&FFFFFF00
        STR     ip, [a1]
        MOV     ip, #0
        STR     ip, [a2]
        LDR     ip, =&00FFFF00
        STR     ip, [a3]
        MOV     pc, lr

HAL_PlatformInfo
        ; TouchBook can do soft-off, others can't (yet)
;        LDR     ip, [sb, #BoardConfig_MachID]
;        LDR     a1, =MachID_TouchBook
        CMP     ip, a1
        MOVNE   ip, #2_10000    ; no podules,no PCI cards,no multi CPU,no soft off,and soft ROM
        MOVEQ   ip, #2_11000
        STR     ip, [a2]
        MOV     ip, #2_11111    ; mask of valid bits
        STR     ip, [a3]
        MOV     pc, lr

HAL_SuperIOInfo
        MOV     ip, #0
        STR     ip, [a1]
        STR     ip, [a2]
        MOV     pc, lr

HAL_MachineID
        Entry   "v1, v2, v3"
        ldr     ip, OCOTP_Log
        mov     a4, lr              ; lr to a4 to preserve
        ldr     a1, [ip, #OCOTP_MAC_LOW_OFFSET]
; DebugReg a3, "MAC-lo "
        ldr     a2, [ip, #OCOTP_MAC_HI_OFFSET]
; DebugReg a3, "MAC-hi "
        AND     a3, a1, #&ff000000
        MOV     a3, a3, LSR #24
        ORR     a2, a3, a2, LSL #8
        MOV     a1, a1, LSL #8
        ORR     a1, a1, #&81
        BIC     a2, a2, #&ff000000
; now encapsulate with crc
        MOV     a3, #0                 ;
        MOV     a4, #7                 ; number of bytes to do
gbyte                                  ;
        AND     v2, a1, #&ff           ; get next byte. shift reg round 8 byte
        AND     v3, a2, #&ff           ; shift reg round 8 byte
        MOV     v1, v2, lsl #24
        MOV     v3, v3, lsl #24
        ORR     a1, v3, a1,lsr #8      ; shift reg round 8 byte
        ORR     a2, v1, a2,lsr #8      ; shift reg round 8 byte

        EOR     a3, a3, v2             ;
        MOV     v1, #8                 ; number of bits to do
gbit                                   ;
        MOVS    a3, a3, LSR #1         ; shift bit out into carry
        EORCS   a3, a3, #&8C           ; feedback carry into other bits
        SUBS    v1, v1, #1             ; one less bit to do
        BNE     gbit                   ; loop until done whole byte
        SUBS    a4, a4, #1             ; one less byte to do
        BNE     gbyte                  ; loop until done all 7 bytes

        AND     v2, a1, #&ff           ; get next byte. shift reg round 8 byte
        AND     v3, a2, #&ff           ; shift reg round 8 byte
        MOV     v1, v2, lsl #24
        MOV     v3, v3, lsl #24
        ORR     a1, v3, a1,lsr #8      ; shift reg round 8 byte
        ORR     a2, v1, a2,lsr #8      ; shift reg round 8 byte

        ORR     a2, a2, a3, lsl #24    ; insert crc into hi byte
; DebugReg a1, "HAL-Lo "
; DebugReg a2, "HAL-Hi "
        EXIT

HAL_ExtMachineID
        MOVS    ip, a1
        MOV     a1, #0
        MOV     pc, lr

; Shifts to determine number of bytes/words to allocate in table.
NibbleShift     *       12 ; 1<<12 = 4K ARM page size
ByteShift       *       NibbleShift + 1
WordShift       *       ByteShift + 2

; Bit patterns for different types of memory.
NotPresent      *       &00000000
DRAM_Pattern    *       &11111111
VRAM_Pattern    *       &22222222
ROM_Pattern     *       &33333333
IO_Pattern      *       &44444444
NotAvailable    *       &88888888

        IMPORT  memset

HAL_PhysInfo
        TEQ     a1, #PhysInfo_GetTableSize
        MOVEQ   a1, #1:SHL:(32-ByteShift)
        STREQ   a1, [a2]
        MVNEQ   a1, #0             ; Supported
        MOVEQ   pc, lr

        TEQ     a1, #PhysInfo_HardROM
        MOVEQ   a1, #0             ; No hard ROM, since the NAND flash isn't yet supported
        MOVEQ   a2, #0
        STMEQIA a3, {a1-a2}
        MVNEQ   a1, #0             ; Supported
        MOVEQ   pc, lr

        TEQ     a1, #PhysInfo_WriteTable
        MOVNE   a1, #0
        MOVNE   pc, lr

        ; Do the PhysInfo_WriteTable table output
        Push    "v1-v2,lr"
        MOV     a1, #&80000000     ; Physical RAM from &80000000 and up?
        LDR     lr, =&FFFFE000-1
        STMIA   a3, {a1,lr}
        MOV     v1, a2

        ADR     v2, HAL_PhysTable
10      LDMIA   v2, {a1, a2, lr}
        SUB     a3, lr, a1
        ADD     a1, v1, a1, LSR #ByteShift
        MOV     a3, a3, LSR #ByteShift
        BL      memset
        LDR     a1, [v2, #8]!
        TEQ     a1, #0
        BNE     %BT10

        MVN     a1, #0             ; Supported
        Pull    "v1,v2,pc"

; HAL_PhysInfo uses memset to fill the table, so all regions
; must be byte-aligned (ie double-page-aligned addresses).
HAL_PhysTable
        DCD     &00000000, NotPresent  :OR: NotAvailable ; GPMC
        DCD     &40000000, IO_Pattern  :OR: NotAvailable ; All I/O registers
        DCD     &80000000, NotPresent  :OR: NotAvailable ; SDRC-SMS/SDRAM
        DCD     &FFFFE000, NotPresent  :OR: NotAvailable ; SDRC-SMS/SDRAM
        DCD     0

HAL_Reset
; hardware reset is achieved by writing the watchog timer
        ldr      a1, WDOG1_Log
        mov      a2, #&4
        strb     a2, [a1]
        DebugTX "HAL_Reset failed!"
        B       . ; Just in case

        LTORG

        EXPORT  vtophys
vtophys
        CallOS  OS_LogToPhys, tailcall

        EXPORT  mapinio
mapinio
        CallOS  OS_MapInIO, tailcall

 [ FIQDebug
FIQRoutine
        ; Dump PC value to the serial port
        MOV     r8, #&24
        LDR     sb, [r8]
        LDR     r8, [sb, #BoardConfig_DebugUART]
        ADR     r9, hextab
        MOV     r10, #8
        MOV     r11, lr ; Preserve return address
10
        LDRB    r12, [r8, #UART_LSR]
        TST     r12, #UART_LSR_THRE
        BEQ     %BT10
        LDRB    r12, [r9, r11, LSR #28]
        STRB    r12, [r8, #UART_THR]
        MOV     r11, r11, LSL #4
        SUBS    r10, r10, #1
        BNE     %BT10
10
        LDRB    r12, [r8, #UART_LSR]
        TST     r12, #UART_LSR_THRE
        BEQ     %BT10
        MOV     r12, #13
        STRB    r12, [r8, #UART_THR]
10
        LDRB    r12, [r8, #UART_LSR]
        TST     r12, #UART_LSR_THRE
        BEQ     %BT10
        MOV     r12, #10
        STRB    r12, [r8, #UART_THR]
        ; Clear interrupt
        MOV     r8, #&24
        LDR     sb, [r8]
        LDR     r8, L4_GPIO1_Log
        LDR     r10, [r8, #GPIO_IRQSTATUS1]
        STR     r10, [r8, #GPIO_IRQSTATUS1]
        LDR     r8, IRQC_Log
        MOV     r10, #2
        STR     r10, [r8, #INTCPS_CONTROL]
        ; Data synchronisation barrier to make sure INTC gets the message
        myDSB
   [ {FALSE} ; Code to call DebugCallstack on any button press
        ; Switch back to original mode
        MRS     r8, CPSR
        MRS     r9, SPSR
        BIC     r8, r8, #&1F
        AND     r9, r9, #&1F
        ORR     r8, r8, r9
        MSR     CPSR_c, r8
        ; Dump the callstack & other regs
        Push    "sb" ; preserve original sb so it can be dumped
        MOV     sb, #&24
        LDR     sb, [sb]
        B       DebugCallstack
   ]
        ; Now return
        SUBS    pc, lr, #4

hextab  DCB "0123456789abcdef"
 ]

        END
