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

; boot.s
;NOTES
;Can this be split up?
;

;put call to RISCOS_AddRAM, OS_Start and beyond!
;Use RAM.s to actually init the RAM.

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
;        GET     Hdr:ImageSize.<ImageSize>

        GET     Hdr:MEMM.VMSAv6

        GET     Hdr:HALSize.<HALSize>
        GET     Hdr:Proc
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries

        ;GETs in HAL source
        GET     hdr.AllWinnerH3
        GET     HDMI_Regs
        GET     board
        GET     RAMMap
        GET     UART
        GET     Interrupts
        ;UART is just there for testing.
  	GET     StaticWS

 [ Debug
        GET     Debug
 ]
;sb      RN      9
;??????????????????????

;=============================================================================
;
;=============================================================================


        AREA    |Asm$$Code|, CODE, READONLY, PIC

;------ Macros ---------------------------------------------------------------

; v8 is used as pointer to RISC OS entry table throughout pre-MMU stage.
        MACRO
        CallOSM $entry, $reg
        LDR     ip, [v8, #$entry*4]
        MOV     lr, pc
        ADD     pc, v8, ip
        MEND
;------ Macros End------------------------------------------------------------

;------ IMPORTs and EXPORTs---------------------------------------------------

        ;EXPORT clearram
	EXPORT rom_checkedout_ok
        EXPORT addram
	EXPORT osstart
        IMPORT HAL_Base
;        IMPORT DWCToSunXi

        IMPORT USB_ReportRegs
;        IMPORT workspace
;        IMPORT OSentries
         ;from hdmi.s
        IMPORT  my_video_init

;;removed. Opting for GraphicsV module.
;        IMPORT  VideoDevice_Init

 [ Debug
         IMPORT DebugHALPrint

         IMPORT HAL_DebugTX
         IMPORT HAL_DebugRX
 ]
;        IMPORT STACK_SIZE
;        IMPORT STACK_BASE
;------ IMPORTs and EXPORTs end-----------------------------------------------
;

;void *RISCOS_AddRAM(unsigned int flags, void *start, void *end,
;                    uintptr_t sigbits, void *ref)
; CallOSM OS_AddRAM
;for compatibility between my old top.s and the OMAP3 based one.

;------Code jumps here from Top.s
rom_checkedout_ok
addram
;Stack ops shouldn't be needed, but I'm covering all bases.
         Push "lr"
 [ Debug
         DebugTX "About to add RAM"
 ]
 Pull "lr"
; [ Debug
;        PUSH {a1, lr}
;        BL   DebugHALPrint
;        =    "About to add RAM\r\n", 0
;        POP  {a1, lr}
; ]
;        PUSH {LR}
        ;This is just going to hardcode everything for now
        ;I need the boot to get a little further so I can
        ;start implementing things.
        ; I think I need to leave the RO image out of this.
        ;r0 = a1 = flags
        ;r1 = a2 = *start
        ;r2 = a3 = *end
        ;r3 = a4 = sigbits????
        ;r4 = v1 = *ref
        ;RAM below the kernel
        ; MOV a1, #2_000100000000

        ;v1 goes on the stack. APCS compliant. duuuhhh
        ;BCM2835 has flags set to 0?
        MOV a1, #0
        ;STR a1, [sp, #-4] ;storing a1 on the stack
;        Push "lr"    ;just trying to work out what breaks.
        Push "a1"
        ;null reference for block 0
        LDR a1, =BLOCK_0_FLAGS
        LDR a2, =BLOCK_0_START
        LDR a3, =BLOCK_0_END
        LDR a4, =&FFFFFFFF


        CallOSM OS_AddRAM

        ;I have to manually remove the pushed params from the stack.
        ADD sp, sp, #4
        ;MOV a4, a1 ;reference for OS_Start
;        Pull "lr"
;        MOV a4, a1 ;

 [ True
        ;video memory
        MOV v1, a1
        Push "v1" ;*ref from previous entry


        LDR a1, =VRAM_FLAGS
        LDR a2, =VRAM_START
        LDR a3, =VRAM_END
        LDR a4, =&FFFFFFFF
        CallOSM OS_AddRAM
        ADD sp, sp, #4

 ]
        MOV a4, a1
        ;put *ref in the right register for OS_Start

         Push "lr"
         DebugTX "RAM added"
         Pull "lr"

        ;show how far we've made it.
; [ Debug
;        PUSH {a1, lr}
;        BL   DebugHALPrint
;        =    "RAM Added\r\n", 0
;        POP  {a1, lr}
; ]
 ;Something after this point is throwing an undefined instruction�abort
 ;copro maybe?

        ;MOV a1, #'3'
        ;bl HAL_DebugTX
        ;BL uart_send_char
        ;BL uart_newline


;        POP {LR}
;it can push and pop. who cares.
;        mov pc, lr
;drop through. The branching was unnecessary.
osstart
       ;set interrupt vectors back to &0
       ;may cause havoc with cache thing in Misc.s
       MOV    r0,  #0   ;Address for vector base.
       MCR    p15, #0, r0, c12, c0
       MOV    a1,   #2_01001
       ;LDR a1, =2_01001     ;flags
       ;LDR a2, =&0          ;pointer to RO header
       ;LDR a3, =&0          ;pointer to HAL descriptor
       ;MOV a4, v1          ;pointer to last ADDRam ref.

       ADRL    a2, HAL_Base + OSROM_HALSize
       ADR     a3, HALdescriptor
;       MOV     a4, v1

       CallOSM OS_Start
       ;program disappears through here.
;===================================================================
;===================================================================

HALdescriptor   DATA
        DCD     HALFlag_NCNBWorkspace
        DCD     HAL_Base - HALdescriptor
        DCD     OSROM_HALSize
        DCD     HAL_EntryTable - HALdescriptor
        DCD     HAL_Entries
        DCD     HAL_WsSize

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


        MACRO
        HALEntry $name
        ASSERT  (. - HAL_EntryTable) / 4 = EntryNo_$name
        DCD     $name - HAL_EntryTable
        MEND

        MACRO
        NullEntry
        DCD     HAL_Null - HAL_EntryTable
        MEND

        ;IMPORT   Video_Init
        IMPORT   Interrupt_Init
        IMPORT   Timers_Init
        ;IMPORT   HAL_CleanerSpace
        ;IMPORT   Timer_Init
        ;IMPORT   PRCM_SetClocks
        IMPORT   USB_Init
        ;IMPORT   I2C_Init
        ;IMPORT   SDMA_Init
        ;IMPORT   VideoDevice_Init
        ;IMPORT   Audio_Init

        ;IMPORT   NIC_Init

        ;IMPORT   GPIO_Init
        ;IMPORT   GPIOx_SetAsOutput
        ;IMPORT   GPIO_InitDevice
        ;IMPORT   SDIO_InitDevices
        ;IMPORT   BoardConfigNames


        IMPORT   HAL_IRQEnable
        IMPORT   HAL_IRQDisable
        IMPORT   HAL_IRQClear
        IMPORT   HAL_IRQSource
        IMPORT   HAL_IRQStatus
        IMPORT   HAL_FIQEnable
        IMPORT   HAL_FIQDisable
        IMPORT   HAL_FIQDisableAll
        IMPORT   HAL_FIQClear
        IMPORT   HAL_FIQSource
        IMPORT   HAL_FIQStatus
        IMPORT   HAL_IRQMax

        IMPORT   HAL_Timers
        IMPORT   HAL_TimerDevice
        IMPORT   HAL_TimerGranularity
        IMPORT   HAL_TimerMaxPeriod
        IMPORT   HAL_TimerSetPeriod
        IMPORT   HAL_TimerPeriod
        IMPORT   HAL_TimerReadCountdown
        IMPORT   HAL_TimerIRQClear
        IMPORT   HAL_TimerIRQStatus
        IMPORT   HAL_CounterRate
        IMPORT   HAL_CounterPeriod
        IMPORT   HAL_CounterRead
        IMPORT   HAL_CounterDelay

        ;IMPORT   HAL_IICBuses
        ;IMPORT   HAL_IICType
        ;IMPORT   HAL_IICDevice
        ;IMPORT   HAL_IICTransfer
        ;IMPORT   HAL_IICMonitorTransfer

        IMPORT   HAL_NVMemoryType
        IMPORT   HAL_NVMemorySize
        IMPORT   HAL_NVMemoryPageSize
        IMPORT   HAL_NVMemoryProtectedSize
        IMPORT   HAL_NVMemoryProtection
        IMPORT   HAL_NVMemoryRead
        IMPORT   HAL_NVMemoryWrite

        ;IMPORT   HAL_VideoIICOp ; Implemented in s.I2C


        IMPORT   HAL_UARTPorts
        IMPORT   HAL_UARTStartUp
        IMPORT   HAL_UARTShutdown
        IMPORT   HAL_UARTFeatures
        IMPORT   HAL_UARTReceiveByte
        IMPORT   HAL_UARTTransmitByte
        IMPORT   HAL_UARTLineStatus
        IMPORT   HAL_UARTInterruptEnable
        IMPORT   HAL_UARTRate
        IMPORT   HAL_UARTFormat
        IMPORT   HAL_UARTFIFOSize
        IMPORT   HAL_UARTFIFOClear
        IMPORT   HAL_UARTFIFOEnable
        IMPORT   HAL_UARTFIFOThreshold
        IMPORT   HAL_UARTInterruptID
        IMPORT   HAL_UARTBreak
        IMPORT   HAL_UARTModemControl
        IMPORT   HAL_UARTModemStatus
        IMPORT   HAL_UARTDevice
        IMPORT   HAL_UARTDefault

        IMPORT   HAL_DebugRX
        IMPORT   HAL_DebugTX

        IMPORT   HAL_KbdScanDependencies

        IMPORT   HAL_Watchdog
        IMPORT   HAL_USBControllerInfo
        IMPORT   HAL_ControllerAddress
        IMPORT   HAL_Reset

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
        NullEntry ;HAL_NVMemoryIICAddress
        HALEntry HAL_NVMemoryRead
        HALEntry HAL_NVMemoryWrite

        NullEntry ;HALEntry HAL_IICBuses
        NullEntry ;HALEntry HAL_IICType
        NullEntry ; HAL_IICSetLines
        NullEntry ; HAL_IICReadLines
        NullEntry ;HALEntry HAL_IICDevice
        NullEntry ;HALEntry HAL_IICTransfer
        NullEntry ;HALEntry HAL_IICMonitorTransfer

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



        NullEntry ; HALEntry HAL_VideoFlybackDevice
        NullEntry ; HALEntry HAL_VideoSetMode
        NullEntry ; HALEntry HAL_VideoWritePaletteEntry
        NullEntry ; HALEntry HAL_VideoWritePaletteEntries
        NullEntry ; HALEntry HAL_VideoReadPaletteEntry
        NullEntry ; HALEntry HAL_VideoSetInterlace
        NullEntry ; HALEntry HAL_VideoSetBlank
        NullEntry ; HALEntry HAL_VideoSetPowerSave
        NullEntry ; HALEntry HAL_VideoUpdatePointer
        NullEntry ; HALEntry HAL_VideoSetDAG
        NullEntry ; HALEntry HAL_VideoVetMode
        NullEntry ; HALEntry HAL_VideoPixelFormats
        NullEntry ; HALEntry HAL_VideoFeatures
        NullEntry ; HALEntry HAL_VideoBufferAlignment
        NullEntry ; HALEntry HAL_VideoOutputFormat
 ]
        NullEntry ; HALEntry HAL_MatrixColumns
        NullEntry ; HALEntry HAL_MatrixScan

        NullEntry ; HALEntry HAL_TouchscreenType
        NullEntry ; HALEntry HAL_TouchscreenRead
        NullEntry ; HALEntry HAL_TouchscreenMode
        NullEntry ; HALEntry HAL_TouchscreenMeasure

        NullEntry ;HALEntry HAL_MachineID

        HALEntry HAL_ControllerAddress
        NullEntry ;HALEntry HAL_HardwareInfo
        NullEntry ;HALEntry HAL_SuperIOInfo
        NullEntry ;HALEntry HAL_PlatformInfo
        NullEntry ;HALEntry HAL_CleanerSpace

        HALEntry HAL_UARTPorts
        NullEntry ;HALEntry HAL_UARTStartUp
        NullEntry ;HALEntry HAL_UARTShutdown
        HALEntry HAL_UARTFeatures
        HALEntry HAL_UARTReceiveByte
        HALEntry HAL_UARTTransmitByte
        HALEntry HAL_UARTLineStatus
        HALEntry HAL_UARTInterruptEnable
        HALEntry HAL_UARTRate
        NullEntry ;HALEntry HAL_UARTFormat
        HALEntry HAL_UARTFIFOSize
        HALEntry HAL_UARTFIFOClear
        HALEntry HAL_UARTFIFOEnable
        HALEntry HAL_UARTFIFOThreshold
        HALEntry HAL_UARTInterruptID
        HALEntry HAL_UARTBreak
        NullEntry ;HALEntry HAL_UARTModemControl
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

        NullEntry ;HALEntry HAL_PlatformName
        NullEntry
        NullEntry

        HALEntry HAL_InitDevices

        HALEntry HAL_KbdScanDependencies
        NullEntry
        NullEntry
        NullEntry

        NullEntry ;HALEntry HAL_PhysInfo

        HALEntry HAL_Reset

        HALEntry HAL_IRQMax

        HALEntry HAL_USBControllerInfo
        NullEntry ; HAL_USBPortPower
        NullEntry ; HAL_USBPortIRQStatus
        NullEntry ; HAL_USBPortIRQClear
        NullEntry ; HAL_USBPortDevice

        HALEntry HAL_TimerIRQClear
        HALEntry HAL_TimerIRQStatus

        NullEntry ;HALEntry HAL_ExtMachineID

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
        NullEntry ;HALEntry HAL_VideoIICOp
        HALEntry  HAL_Watchdog
HAL_Entries     * (.-HAL_EntryTable)/4

;----------------------------------------------------------------------
;    SetUpOSEntries
;----------------------------------------------------------------------
SetUpOSEntries  ROUT

        STR     a1, OSheader
        LDR     a2, [a1, #OSHdr_NumEntries]
        CMP     a2, #HighestOSEntry+1
        MOVHI   a2, #HighestOSEntry+1

        ADR     a3, OSentries
        LDR     a4, [a1, #OSHdr_Entries]
        ADD     a4, a4, a1

05      SUBS    a2, a2, #1
        LDR     ip, [a4, a2, LSL #2]
        ADD     ip, ip, a4
        STR     ip, [a3, a2, LSL #2]
        BNE     %BT05

        ; Fall through
;besides this fallthrough, this seems to be boilerplate
;------Bits to shut it up.
HAL_Null
        MOV     pc, lr

;----------------------------------------------------------------------
;    HAL_InitDevices
;----------------------------------------------------------------------
HAL_InitDevices
    Entry    "v1-v3"
    DebugTX "HAL_InitDevices called"
    DebugTX "Trying video test code"
    DebugTX "Running PHY Init"
    BL    my_video_init
    DebugTX "Exited PHY Init"
    ;;Removed. Using GraphicsV
;;    BL    VideoDevice_Init
    EXIT


;=======================================================================
;    HAL_Init --- This is where the awesome stuff happens!!!
;=======================================================================

HAL_Init
	Entry	"v1-v3"
;Registers and stuff from Kernel.s.HAL:
;
;        LDR     a1, =ZeroPage
;        STR     v1, [a1, #InitUsedBlock]
;        STR     v2, [a1, #InitUsedEnd]
;
;        LDR     a1, =RISCOS_Header
;        LDR     a2, =HALWorkspaceNCNB
;        AddressHAL
;        CallHAL HAL_Init
;

   STR   a2, NCNBWorkspace
   STR   a2, NCNBAllocNext
;   MOV   v5, a2       ;?

;Apparently I'm responsible for turning on caches etc.
   MOV    a4, #1
   MRC    p15, #0, a3, c1, c0, #0 ;Load SCTLR
   ;doing this the slow way solely for transparency.
   ORR    a3, a3, a4, LSL#1 ;alignment fault checking enabled
   ORR    a3, a3, a4, LSL#2 ;data and unified caches enabled.
   ORR    a3, a3, a4, LSL#12;Instruction cache enabled.
   MCR    p15, #0, a3, c1, c0, #0
   DSB
   ISB



;----INSANITY ALERT----
;Temporarily mapping vectors again until Kernel calls InitVectors.
;    ADRL    a1, HAL_Base
;    MCR     p15, 0, a1, c12, c0

     ;grab current vector table location.
     ;MRC     p15, #0, a1, c12, c0

   ;ADRL  sb, workspace  ;that kills it too!
   ;PUSH {lr}
   BL    SetUpOSEntries
   ;POP  {lr}
   ; i dunno.

   MOV a1, #0
   STR a1, DefaultUART
   ;TODO: UART IRQs. Listed in UART.hdr
   ;Cheaty packed UART IRQs.
    LDR a1, =&23222120
    STR a1, HALUARTIRQ

;Mapping the SRAM as IO. I have no idea what else to do with it.
;Could be commented out.
    MOV a1, #0
    MOV a2, #SRAM_A1
    MOV a3, #SRAM_A1_Size
    CallOS  OS_MapInIO
    STR a1, SRAM_A1_BaseAddr


    MOV a1, #0
    MOV a2, #SRAM_A2
    MOV a3, #SRAM_A2_Size
    CallOS  OS_MapInIO
    STR a1, SRAM_A2_BaseAddr


    MOV a1, #0
    MOV a2, #SRAM_C
    MOV a3, #SRAM_C_Size
    CallOS  OS_MapInIO
    STR a1, SRAM_C_BaseAddr

 [ False
;end SRAM
;VRAM. Mapped as IO because AddRAM has a stroke when VRAM is
;added above OS space.
    MOV a1, #0 ;really need to check these flags.
    LDR a2, =VRAM_START
    LDR a3, =VRAM_SIZE
    CallOS  OS_MapInIO
    STR a1, VRAM_BaseAddr
 ]

;You know what? I'm going to map all this in as one big slab!
;----Main chunk of IO----;
;DE is the start of the main block of IO
	MOV a1, #0
    LDR a2, =IO_Base
	LDR a3, =IO_Size
	CallOS  OS_MapInIO
	STR a1, IO_BaseAddr ;that's fine

        ;let's get a logical offset from a physical one.
	;first, let's shift the IO_BaseAddr
;not a function yet
;unsigned int PhysToLog(phys_addr, phys_io_base, *log_io_base);
	;IO_BaseAddr kept safe in a4 for now.
	MOV a4, a1
;map in UARTS
	LDR a1, =UART_Base
	LDR a2, =IO_Base
	MOV a3, a4 ;IO base address.

	bl PhysToLog
	;returns a1; logical address
	STR a1, HALUART_Log ;should also update UART_0_Log
	STR a1, DebugUART ;hardcoding to UART 0 for now.
	ADD a1, a1, #UART_Offset ;0x400
	STR a1, UART_1_Log
	ADD a1, a1, #UART_Offset
	STR a1, UART_2_Log
	ADD a1, a1, #UART_Offset
	STR a1, UART_3_Log

 	Push "lr"
    DebugReg a4, " IO_BaseAddr= "
    Pull "lr"


    DebugReg sb, "Workspace pointer sb= "
;let's just put this probably useless hardcoded packed UART IRQ thing here.



   DebugTX "UARTs mapped in"


    MRC     p15, #0, a1, c12, c0
    DebugReg a1, "Vectors currently at: "
    ;it shouldn't have been clobbered, but just in case.
    LDR a4, IO_BaseAddr  ;logical IO base address

;Map in SCU and GIC stuff
	LDR a1, =SCU
	LDR a2, =IO_Base     ;Physical base address
	MOV a3, a4
	bl PhysToLog
	STR a1, SCU_BaseAddr
	STR a1, MPU_INTC_Log ;I know they are the same thing in StaticWS.

 [ Debug
    DebugReg a1, " SCU_BaseAddr= "
 ]

    LDR a1, MPU_INTC_Log
    ADD a2, a1, #GIC_DIST_Offset
    STR a2, GIC_DISTBaseAddr
    ADD a2, a1, #GIC_CPUIF_Offset
    STR a2, GIC_CPUIFBaseAddr


;Timer base
    LDR a1, =TIMER
    LDR a2, =IO_Base
    MOV a3, a4
    bl PhysToLog
    STR a1, TIMER_Log
 [ Debug
    DebugReg a1, " TIMER_Log= "
 ]
   ;Add CPUCFG base. Needed for CNT64
   LDR a1, =R_CPUCFG
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, CPUCFG_BaseAddr
;--USB_HCI0
   LDR a1, =USB_HCI0
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, USB_Host_BaseAddr
;--USB OTG  --working on obsoleting.
   LDR a1, =USB_OTG_Dev
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, USB_OTG_BaseAddr
;--PIO
   LDR a1, =PIO
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, PIO_BaseAddr

;--PIO Port L
   LDR a1, =R_PIO
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, R_PIO_BaseAddr



;--HDMI
   LDR a1, =HDMI
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, HDMI_BaseAddr
   DebugTX "GIC, SCU and TIMER  added to StaticWS"

;--CCU
   LDR a1, =CCU
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, CCU_BaseAddr

;--MMC
   LDR a1, =SDMMC_0
   LDR a2, =IO_Base
   MOV a3, a4
   BL  PhysToLog
   STR a1, MMC_BaseAddr



;Basic IO mapping complete.
;------------Init hardware-----------------

   DebugTX "Going into Interrupt_Init"

    ;PUSH {lr}
    BL Interrupt_Init
    ;POP  {lr}

   DebugTX "Out of Interrupt_Init"


   DebugTX "About to init timer"

   ;PUSH {lr}
   BL   Timers_Init
   ;POP  {lr}

   DebugTX "Out of Timers_Init"

	    ; I for init complete.
        ;MOV a1, #'I'
        ;bl  HAL_DebugTX
        ;LDR a1, initdone
        ;bl  DebugHALPrint
;        BL uart_send_char
;        BL uart_newline
         ;set up OS entries
         ;map in IO CallOS OS_MapInIO ???
         ;CallOS OS_LogToPhys (workspace?>
   DebugTX "About to init USB clocks etc"

   BL    USB_ReportRegs

   BL    USB_Init

   DebugTX "USB PreInit finished."

   BL    USB_ReportRegs

   DebugTX "End of HAL_Init reached"
 [ Debug


 ;this is wrong. These regs need another base offset.
;   DebugTX "Trying unscrambled HDMI regs"
;        LDR a3, HDMI_BaseAddr
;
;        LDR a1, =HDMI_DESIGN_ID
;        ADD a1, a1, a3
;        LDR a2, [a1, #0]
;        DSB
;        DebugReg a2, "HDMI_DESIGN_ID= "
;        LDR a1, =HDMI_FC_VSYNCINWIDTH
;        ADD a1, a1, a3
;        LDR a2, [a1, #0]
;        DSB
 ;       DebugReg a2, "HDMI_FC_VSYNCINWIDTH= "

;----
;        DebugTX "Trying scrambled HDMI regs"
;        LDR a1, =HDMI_FC_VSYNCINWIDTH
;        BL  DWCToSunXi
;        ADD a1, a1, a3
;        LDR a2, [a1, #0]
;        DebugReg a2, "HDMI_FC_VSYNCINWIDTH= "
;
;        LDR a1, =HDMI_DESIGN_ID
;        BL  DWCToSunXi
;        ADD a1, a1, a3
;        LDR a2, [a1, #0]
;        DebugReg a2, "HDMI_DESIGN_ID= "



 ]
        EXIT

PhysToLog
	;a1 physical address
	;a2 physical IO base
	;a3 pointer to logical IO base
	;physical address will be larger than the physical IO base
	;The goal is to work out the offset, then apply it to
	;the logical balue.
	; offset = a1 - a2;
	; log_offset = log_io_base + offset
	SUB a1, a1, a2
	ADD a1, a3, a1
	MOV pc, lr


initdone DCB "HAL_Init finished\r\n"
;uart_dbg_Log        ;Pardon?
        END
