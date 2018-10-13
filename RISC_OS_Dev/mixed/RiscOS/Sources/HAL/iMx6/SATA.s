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

        GET     ListOpts
        GET     Macros
        GET     System
        GET     Machine.<Machine>
        GET     ImageSize.<ImageSize>

        GET     Proc
        GET     OSEntries

        GET     iMx6q
        GET     StaticWS
        GET     HALDevice
        GET     AHCIDevice
        GET     AHCI

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  ;HAL_ATAControllerInfo
        EXPORT  HAL_ATACableID
        EXPORT  HAL_ATASetModes
        EXPORT  SATA_Init
        IMPORT  HAL_CounterDelay
        IMPORT  memcpy
        IMPORT  vtophys

 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

; currently code only supports the first SATA lane
        GBLL Multi_AHCI_Ports
Multi_AHCI_Ports SETL {FALSE}; {TRUE}

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






HAL_PlatformName;HAL_ATAControllerInfo
        MOV     a1, #0
        MOV     pc, lr

HAL_ATACableID
        MOV     a1, #0
        MOV     pc, lr

HAL_ATASetModes
        MOV     a1, #0
        MOV     pc, lr

; do all that is needed to set up the SATA interface
; This presumes the ethernet driver has already been initted!!!
; exit a1 = 0 if OK, else NZ
SATA_Init
        Entry   "a2-a4, v1,v2"
        ldr     v1, SATA_Log            ; sata controller base address
;        DebugReg v1, "AHCI Chip address "
; init sata stuff
; 1 turn on SATA pow if controllable
        ; wandboard has no control of extrnal SATA power
; 2 init the sata clock
        ; wandboard SATA clk srce is the ENET_PLL
        ldr     a4, IOMUXC_Base
        ; enable SATA_CLK in CCGR5
        ldr     v2, CCM_Base
        ldr     a1, [v2, #CCM_CCGR5_OFFSET]
        orr     a1, a1, #3<<4           ; 100mhz clock on
        str     a1, [v2, #CCM_CCGR5_OFFSET]
        ; the ENET_PLL is set going in the EtherDrv code
        ; we now need to turn on the 100MHz SATA reference clock
        ldr     a3, CCMAn_Log
        ldr     a2, [a3,#HW_CCM_ANALOG_PLL_ENET_ADDR]

        orr     a2, a2, #1<<20          ; 100MHZ clk en bit
        str     a2, [a3, #HW_CCM_ANALOG_PLL_ENET_ADDR]
        ; ENET has already set ethernet ref clk to 50MHz anyway
        ; SATA timings
        ldr     a3, =&0593e4ab;&059124c6
        str     a3, [a4, #IOMUXC_GPR13 - IOMUXC_BASE_ADDR]
        MOV     a1, #1*1024 ; 1msec ish
        BL      HAL_CounterDelay
        ; now configure sata phy
        ; using the 100MHz enet clk o/p, we use default phy clk settings for
        ; HW_SATA_PHY_CLOCK_FREQ_OVRD register value


; 3 set up various regs in the sata controller
        ; set for 1ms timer
        ldr     a1, =100000             ; 100 MHz value to give 1ms
        str     a1, [v1, #HW_SATA_TIMER1MS_OFFSET]
        ; set OOBR register
        ldr     a1, = COM_Default+ (1<<BIT_SATA_OOBR_WE)
        str     a1, [v1, #HW_SATA_OOBR_OFFSET]  ; enable for writing
        bic     a1, a1, #(1<<BIT_SATA_OOBR_WE)
        str     a1, [v1, #HW_SATA_OOBR_OFFSET]  ; write, and disable for writing
        ; set staggered spinup
        ldr     a1, [v1, #HW_SATA_CAP_OFFSET]
        orr     a4, a1, #(1<<BIT_SATA_CAP_SSS)  ; support staggered spinup
        str     a4, [v1, #HW_SATA_CAP_OFFSET]
        ; detemine how many ports are implemented
        and     a4, a4, #BIT_SATA_CAP_NP_MASK   ; portmax - 1, (=0 for 1 port)
        mov     a3, a4
; DebugReg a3, "highest port Implemented "
        mov     a2, #1
001     subs    a3, a3, #1                      ; build bitmap of valid lanes
        movge   a2, a2, lsl #1
        orrge   a2, a2, #1
        bge     %bt001
        str     a2, [v1, #HW_SATA_PI_OFFSET]    ; ensure controller knows
        ; now for each port, analyse, then set it idle
        ; a4 = ports present - 1 (0  for 1 port on wandboard)
        ; initialise v2 to compensate for port address offset if needed
        mov     v2, v1                          ; set for use with first port
002     bl      CheckAHCIIdle
;  DebugReg  a1, " 0 if port idle "
        teq     a1, #0                          ; idle?
        bne     %ft004                          ; no .. abort this one
; DebugReg a4, "idle port found at "
        ; spin up port
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        orr     a2, a2, #(1<< BIT_SATA_P0CMD_SUD)
        str     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        ldr     a2, =  P0SCTL_Default
        str     a2, [v2, #HW_SATA_P0SCTL_OFFSET] ; start the process
        MOV     a1, #3*512                      ; at least 1.5 msec ish
        BL      HAL_CounterDelay
; need A TIMEOUT LOOP
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        tst     a2, #(1<< BIT_SATA_P0CMD_SUD)
; TO HERE this is NE when device spun up
        bne     %ft006                          ; ok it has spun up
        MOV     a1, #3*512                      ; at least 1.5 msec ish
        BL      HAL_CounterDelay                ; again
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        tst     a2, #(1<< BIT_SATA_P0CMD_SUD)
        beq     %004                            ; no spinup reported
006
        ldr     a2, [v2, #HW_SATA_P0SCTL_OFFSET]
        bic     a2, a2, #(SATA_P0SCTL_clear<< BIT_SATA_P0SCTL_DET)
        orr     a2, a2, #(SATA_P0SCTL_DET_disable<< BIT_SATA_P0SCTL_DET)
        str     a2, [v2, #HW_SATA_P0SCTL_OFFSET] ; disable port
        adrl    a3, SATA_WORK_START
; DebugReg a3, "Base of workspace before alignment "
        ; this needs to be at 3/4k alignment to let the CMDTB be aligned at
        ; 1k alignment
        mov     a2, #&400
        sub     a2, a2, #1      ; 1023 mask
        and     a3, a3, a2      ; base offset from 1k
; DebugReg a3, "Base offset at start "
        mov     a1, #&300
        subs    a2, a1, a3
        addlt   a2, a2, #&400
        adrl    a3, SATA_WORK_START
        add     a3, a3, a2
        str     a3, SataRXFISLog
        str     a3, SataWorkLog
; DebugReg a3, "Base of workspace "
        ; clear the workspace ram
        mov     a2, #SATA_CMDTB_END-SATA_WORK_START; must be whole number of words
        mov     a1, #0
005     subs    a2, a2, #4
        strge   a1, [a3, a2]
        bgt     %bt005

        ; tell it where its control structures are
        ; chip needs physical addresses, we need logical
; DebugReg a3, "Base of RXFIS  "
        mov     a1, a3
        bl      vtophys
        str     a1, [v2, #HW_SATA_P0FB_OFFSET] ; SATA_RXFIS_BASE
        str     a1, SataRXFISPhys
; DebugReg a1, "Phys Base of RXFIS  "
        mov     a1, #SATA_CMDHD_BASE-SATA_RXFIS_BASE
        add     a3, a3, a1
        str     a3, SataCMDHDLog
; DebugReg a3, "Base of CMDHD "
        mov     a1, a3
        bl      vtophys
        str     a1, [v2, #HW_SATA_P0CLB_OFFSET] ; SATA_CMDHD_BASE
        str     a1, SataCMDHDPhys
; DebugReg a1, "Phys Base of CMDHD "
        ; now enable the port
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        orr     a2, a2, #(1<< BIT_SATA_P0CMD_FRE)
        str     a2, [v2, #HW_SATA_P0CMD_OFFSET]



004
 [ Multi_AHCI_Ports
                                             ; any more ports to check?
        subs    a4, a4, #1
        addge   v2, v2, #SATA_CLB_SIZE
        bge     %bt002
 ]


; 4 start seeing what is there

; finally.. create a HAL_Device to pass its stuff through
satainitdone
        bl      AddAHCIDevice
        EXIT

; done on a per-port basis..
; on entry, v2->port register set
; exit a1=0 if OK, else NZ
CheckAHCIIdle
        Entry   "a2-a4, v2"
001     ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        tst     a2, #(1<< BIT_SATA_P0CMD_HPCP)
        beq     %ft002                          ; hotplug not supported
;   DebugTX "HotPlug supported "
002
        ; check if idle
        ldr     a4, = ((1<<BIT_SATA_P0CMD_ST)+(1<<BIT_SATA_P0CMD_CR)+(1<<BIT_SATA_P0CMD_FRE)+(1<<BIT_SATA_P0CMD_FR))
        tst     a2, a4                          ; is it already idle?
        moveq   a1, #0
        EXIT    EQ
        ; OK.. so push port to idle
        ; 1 clear start bit and await CR bit 0
        bic     a2, a2, #(1<<BIT_SATA_P0CMD_CR)
        str     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        mov     a4, #500                ; 500 ms max
003
        MOV     a1, #1*1024 ; 500 msec ish
        BL      HAL_CounterDelay
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        tst     a2, #(1<<BIT_SATA_P0CMD_CR)
        beq     %ft004
        subs    a4, a4, #1
        bgt     %bt003                  ; not done yet
        ; timeout if here
        mov     a1, #1
        EXIT
004
        tst     a2, #(1<<BIT_SATA_P0CMD_FRE) ; FIS rx enabled?
        beq     %ft005
        mov     a4, #500                ; 500 ms max
006
        MOV     a1, #1*1024 ; 500 msec ish
        BL      HAL_CounterDelay
        ldr     a2, [v2, #HW_SATA_P0CMD_OFFSET]
        tst     a2, #(1<<BIT_SATA_P0CMD_FR)
        beq     %ft005
        subs    a4, a4, #1
        bgt     %bt006                  ; not done yet
005
        mov     a1, #0
        EXIT


; do all that is needed to stop the SATA interface
HAL_SATAKill
        Entry   "a1-a4, v1"
        ldr     v1, SATA_Log            ; sata controller base address
;        DebugTX "entring SATAKill"



; disable SATA clock
        ldr     a4, CCM_Base
        ldr     a1, [a4, #CCM_CCGR5_OFFSET]
        bic     a1, a1, #3<<4           ; 100mhz clock off
        str     a1, [a4, #CCM_CCGR5_OFFSET]
; turn off SATA power, if controllable
        EXIT

; SATA Phy routines.. to make things a bit simpler
;
; SATA_Phycr_Poll_Ack
; Entry a1 = max count
;       a2 = expected value
;       a3 = port
; return a1
;       a1 = 0 PASS
;       a1 = 1 FAIL
SATA_Phycr_Poll_Ack
        Entry
        EXIT

; SATA_Phycr_Write
; Entry a1 = addr
;       a2 = value
;       a3 = port
; return a1
;       a1 = 0 PASS
;       a1 = 1 FAIL
SATA_Phycr_Write
        Entry
        EXIT

; SATA_Phycr_Read
; Entry a1 = addr
;       a2 -> (u32) value read
;       a3 = port
; return a1
;       a1 = 0 PASS
;       a1 = 1 FAIL
SATA_Phycr_Read
        Entry
        EXIT

; SATA_Phycr_CapAddr
; Entry a1 = addr
;       a2 = port
; return a1
;       a1 = 0 PASS
;       a1 = 1 FAIL
SATA_Phycr_CapAddr
        Entry
        EXIT

; SATA_Phy_Config_Mpll
; Entry a1 = prop       - proportional charge pump control
;       a2 = int        - interger charge pump control
;       a3 = div5       - divide by 5 control
;       a4 = div4       - divide by 4 control
;       v1 = prescale   - prescaler control
; return a1
;       a1 = 0 PASS
;       a1 = 1 FAIL
SATA_Phy_Config_Mpll
        Entry
        EXIT

AddAHCIDevice
        Entry   "a1 - a4, v1"
        ADRL    v1, AHCI_Device
        MOV     a1, v1
        ADR     a2, AHCIDeviceTemplate
        MOV     a3, #HALDevice_AHCI_Size
        BL      memcpy
        ldr     a1, SataWorkLog
        str     sb, [v1, #:INDEX:AHCI_sb]
        ldr     a1, SATA_Log
        str     a1, [v1, #HALDevice_Address]
        MOV     a1, #0
        MOV     a2, v1
; DebugReg a2, "HAL AHCI Dev Addr  "
        CallOS  OS_AddDevice

; DebugTX "Device added "
        EXIT

AHCIDeviceTemplate
        DCW     HALDeviceType_ExpCtl + HALDeviceExpCtl_AHCI
        DCW     HALDeviceID_AHCI_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI
        DCD     0               ; API version 0
        DCD     AHCIDevice_Desc
ahciadr DCD     0               ; AHCI Chip Base logical address - filled in later
        %       12              ; Reserved
        DCD     AHCIDevice_Activate
        DCD     AHCIDevice_Deactivate
        DCD     AHCIDevice_Reset
        DCD     AHCIDevice_Sleep
        DCD     IMX_INT_SATA    ; Device interrupt
        DCD     0               ; TestIRQ cannot be called
        DCD     0               ; ClrIRQ cannot be called
        %       4               ; reserved
ahciws  DCD     0               ; AHCI workspace pointer - filled in later
        DCD     0               ;  - filled later

        ASSERT (. - AHCIDeviceTemplate) = AHCIDeviceSize

AHCIDevice_Desc
        =       "i.Mx6 AHCI controller", 0
        ALIGN

AHCIDevice_Activate
        Entry   "sb"
        MOV     a1, #1
        EXIT

AHCIDevice_Deactivate
AHCIDevice_Reset
        MOV     pc, lr

AHCIDevice_Sleep
        MOV     a1, #0
        MOV     pc, lr


        END
