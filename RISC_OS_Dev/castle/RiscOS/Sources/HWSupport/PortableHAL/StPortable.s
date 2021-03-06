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
        TTL     Source.StPortable

;
; Module header and misc. functions
;
        AREA    |Portable$$Code|, CODE, READONLY, PIC

;******************************************************************************
;
; Module header
;
Module_BaseAddr
        DCD     0                               ;Start
        DCD     Init     - Module_BaseAddr
        DCD     Die      - Module_BaseAddr
        DCD     Service  - Module_BaseAddr
        DCD     Title    - Module_BaseAddr
        DCD     Help     - Module_BaseAddr
        DCD     0                               ;Command table
        DCD     Module_SWISystemBase + PortableSWI * Module_SWIChunkSize
        DCD     SWIEntry - Module_BaseAddr
        DCD     SWINameTable - Module_BaseAddr
        DCD     0                               ;SWIDecode
        DCD     0                               ;Messages
        DCD     ModFlags - Module_BaseAddr

;******************************************************************************

Title   DCB     "Portable",0
Help    DCB     "Portable",9,"$Module_HelpVersion", 0
        ALIGN

ModFlags
 [ No32bitCode
        DCD 0
 |
        DCD ModuleFlag_32bit
 ]


;******************************************************************************
;
; Errors
;
        ^               ErrorBase_Portable
        AddError        BadBMUVariable,"BadBMUVar"
        AddError        BadBMUCommand,"BadBMUCmd"
        AddError        BMUBusy,"BMUBusy"
        AddError        BadBMUVersion,"BadBMUVer"
        AddError        BMUFault,"BMUFault"
        AddError        BMUVecClaim,"BMUVecClaim"
        AddError        CantFreeze,"CantFreeze"
        AddError        FreezeFailed,"FreezeFailed"
        AddError        NoSpeed2,"NoSpeed2"
        AddError        BadSpeed2,"BadSpeed2"
        AddError        BadFlags,"BadFlags"
        AddError        BadBMU,"BadBMU"
        AddError        UKSensor,"UKSensor"

        ASSERT          @ <= (ErrorBase_Portable + ?ErrorBase_Portable)


;******************************************************************************
;
; Resources
;
;Path            DCB     "Portable$Path",0
;DefPath         DCB     "Resources:$.Resources.Portable.",0

MessageFile
messagefilename
        DCB     "Resources:$.Resources.Portable.Messages", 0
        ALIGN


;******************************************************************************
;
; Init - Module initialisation code
;
; Exit
;   R7-R11, R13 preserved
;
Init    ROUT
        Entry   "R7-R8"
        LDR     R2, [R12]
        TEQS    R2, #0                          ;already got work space if entered
        MOVNE   R12, R2
        BNE     %FT20                           ;as part of RMTidy

;private word is zero, so claim some workspace
        MOV     R0, #ModHandReason_Claim
        MOV     R3, #MemNeeded
        SWI     XOS_Module
        EXIT    VS                              ;quit if error

        STR     R2, [R12]                       ;got workspace ok, so store in private word
        MOV     R12, R2
        ; Zero workspace
        MOV     R0, #0
10
        SUBS    R3, R3, #4
        STRGE   R0, [R2], #4
        BGT     %BT10
        ; Determine which WFI routine (if any) to use
        ; ARMv7+ is guaranteed(?) to have WFI instruction
        ; ARMv6 has a CP15 WFI operation
        ; Technically ARMv6K has the WFI instruction as well, but it looks
        ; patchy whether it's implemented (ARM1176JZF-S: WFI instruction is NOP,
        ; ARM11 MPCore: Appears to have both WFI and CP15 WFI)
        ; The CPU feature registers are useless for working out which of the
        ; instructions are implemented, so keep things simple and only use the
        ; CP15 WFI on ARMv6.
        ; (Also, we currently don't care about WFI on older CPUs)
    [ SupportARMv6 :LAND: NoARMv7
      [ NoARMv6
        MRC     p15,0,R1,c0,c0,0
        ANDS    LR, R1, #&0000F000              ; EQ = ARM 3/6
        TEQNE   LR, #&00007000                  ; EQ = ARM 7
        BEQ     %FT15                           ; ... not supported
        AND     LR, R1, #&000F0000              ; Get architecture number
        TEQ     LR, #&00070000                  ; ARMv6?
        TEQNE   LR, #&000F0000                  ; Use feature registers?
        BNE     %FT15                           ; <ARMv6, ignore
      ]
      [ SupportARMv7
        ; Use the cache type register to work out whether this is ARMv6 or ARMv7
        MRC     p15,0,R1,c0,c0,1
        TST     R1, #&E0000000
        ADRNE   R1, Idle_WFI
        STRNE   R1, Idle
        BNE     %FT15
      ]
        ; ARMv6 suspected, use CP15 WFI
        ADR     R1, Idle_CP15
      [ Erratum_486865 <> "NA"
        MRC     p15,0,R0,c0,c0,0
        LDR     R2, =&FFF0
        AND     R0, R0, R2
        LDR     R2, =&B760
        TEQ     R0, R2
        BNE     %FT14
        ; It's ARM11, and we want some kind of special treatment
       [ Erratum_486865 = "Workaround"
        ; Use a (cache aligned) copy of the workaround routine
        ADR     R1, WFI_code
        ADD     R1, R1, #31
        BIC     R1, R1, #31
        ADR     R0, Idle_ARM11
        ASSERT  WFI_code_size = 9*4
        LDMIA   R0, {R0,R2-R8,LR}               ; 9 words
        STMIA   R1, {R0,R2-R8,LR}
        ADD     R2, R1, #WFI_code_size-1
        MOV     R0, #1
        SWI     XOS_SynchroniseCodeAreas
       |
        ASSERT  Erratum_486865 = "Disable"
        B       %FT15
       ]
14
      ]
        STR     R1, Idle
15
    ELIF SupportARMv7
        ; ARMv7+
        ADR     R1, Idle_WFI
        STR     R1, Idle
    ]
        ; Get the DSB_Write ARMop
        LDR     R0, =MMUCReason_GetARMop+(ARMop_DSB_Write:SHL:8)
        SWI     XOS_MMUControl
        ADRVS   R0, NOProutine
        STR     R0, DSB_Write

        ; Look for a CPU clock HAL device
        LDR     R0, =HALDeviceType_SysPeri+HALDeviceSysPeri_CPUClk
        MOV     R1, #0
        MOV     R8, #OSHW_DeviceEnumerate
        SWI     XOS_Hardware
        BVS     %FT20
        CMP     R1, #-1
        BLNE    TryClockDevice
 [ DebugSpeed
        Push    "R9"
        ; Use a HAL timer to get accurate timings
        MOV     R0, #DebugTimer
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_TimerDevice
        SWI     OS_Hardware
        MOV     R9, #EntryNo_HAL_IRQDisable
        SWI     OS_Hardware
        ; Set the period to max
        ; Note that timing code won't work very well if max != &ffffffff, as it doesn't take into account wraparound
        MOV     R0, #DebugTimer
        MOV     R9, #EntryNo_HAL_TimerMaxPeriod
        SWI     OS_Hardware
        MOV     R1, R0
        MOV     R0, #DebugTimer
        MOV     R9, #EntryNo_HAL_TimerSetPeriod
        SWI     OS_Hardware
        ; Start counting
        MOV     R0, #DebugTimer
        MOV     R9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        STR     R0, LastTimer
        Pull    "R9"
 ]
20
        ; Look for BMU devices
        LDR     R0, =HALDeviceType_SysPeri+HALDeviceSysPeri_BMU
        MOV     R1, #0
        MOV     R8, #OSHW_DeviceEnumerateChrono
30
        SWI     XOS_Hardware
        BVS     %FT40
        CMP     R1, #-1
        BEQ     %FT40
        BL      AddBMUDevice
        B       %BT30        
40

 [ Debug
        InsertTMLInitialisation 0               ;my EasiStork uses podule slot 0
       ;DLINE   "Portable module initialisation"
 ]

; open messages file

        wsaddr  R0,MsgTransBlk
        addr    R1,MessageFile
        MOV     R2,#0                           ; no buffer supplied
        SWI     XMessageTrans_OpenFile
        EXIT

NOProutine
        MOV     pc, lr

        MakeErrorBlock  ModuleBadSWI
;        MakeErrorBlock  CantFreeze
;        MakeErrorBlock  FreezeFailed
        MakeErrorBlock  NoSpeed2
        MakeErrorBlock  BadSpeed2
        MakeErrorBlock  BadFlags
        MakeErrorBlock  BadBMU
        MakeErrorBlock  BMUFault
        MakeErrorBlock  BMUBusy
        MakeErrorBlock  BadBMUVariable
        MakeErrorBlock  UKSensor

        LTORG

;******************************************************************************
;
; Finalisation code - Called before killing the module
;
; Entry
;   R10 = fatality indication: 0 is non-fatal, 1 is fatal
;   R11 = instantiation number
;   R12 = pointer to private word
;
; Exit
;   R7-R11, R13 preserved
;
Die     ROUT
        Entry
        LDR     R12, [R12]                      ;get workspace pointer

        ; Deactivate BMU devices
01
        LDR     R0, BMUDevList
        TEQ     R0, #0
        BEQ     %FT09
        LDR     R2, [R0]
        BL      RemoveBMUDevice
        B       %BT01

09
        ; Deactivate CPU clock device
        LDR     R4, CPUClkDevice
        CMP     R4, #0
        BLNE    DeactivateClockDevice
10
; close message file

        wsaddr  R0,MsgTransBlk
        SWI     XMessageTrans_CloseFile

        CLRV
        EXIT

;******************************************************************************

UServTab
        DCD     0
        DCD     UService - Module_BaseAddr
        DCD     Service_Hardware
        DCD     0
        DCD     UServTab - Module_BaseAddr
Service
        MOV     R0, R0
        TEQ     R1, #Service_Hardware
        MOVNE   PC, LR
UService
        Entry   "R0-R1"
        LDR     R12, [R12]
        AND     R0, R0, #&FF
        CMP     R0, #1
        BHI     %FT90
        BEQ     %FT50
        ; Device being added
        LDR     R0, CPUClkDevice
        CMP     R0, #0
        BNE     %FT90
      [ NoARMv4
        LDR     R0, [R2, #HALDevice_Type]
        MOV     R0, R0, LSL #16
        MOV     R0, R0, LSR #16
        LDR     LR, [R2, #HALDevice_Version]
        MOV     LR, LR, LSR #16
      |
        LDRH    R0, [R2, #HALDevice_Type]
        LDRH    LR, [R2, #HALDevice_Version+2]
      ]
        LDR     R1, =HALDeviceType_SysPeri+HALDeviceSysPeri_CPUClk
        CMP     R0, R1
        CMPEQ   LR, #0 ; Major API 0
        BLEQ    TryClockDevice
        B       %FT90
50
        ; Device being removed
        LDR     R0, CPUClkDevice
        CMP     R0, R2
        BLEQ    DeactivateClockDevice
90
        CLRV
        EXIT        


;******************************************************************************

SWIEntry        ROUT
        LDR     R12,[R12]
        CMPS    R11,#(EndSWIJmpTable - SWIJmpTable) /4
        ADDCC   PC,PC,R11,LSL #2
        B       SWIUnknown

SWIJmpTable
        B       SWISpeed
        B       SWIControl
        B       SWI_ReadBMUVariable
        B       SWI_WriteBMUVariable
        B       SWI_CommandBMU
        B       SWIReadFeatures
        B       SWIIdle
        B       SWIStop
        B       SWIStatus
        B       SWIPortable_Contrast
        B       SWIRefresh
        B       SWIHalt
        B       SWISleepTime
        B       SWISMBusOp
        B       SWISpeed2
        B       SWIWakeTime
        B       SWIEnumerateBMU
        B       SWIReadBMUVariables
        B       SWIReadSensor
EndSWIJmpTable


;******************************************************************************

ModuleTitle ; Share the string
SWINameTable
        =       "Portable",0
        =       "Speed",0
        =       "Control",0
        =       "ReadBMUVariable",0
        =       "WriteBMUVariable",0
        =       "CommandBMU",0
        =       "ReadFeatures",0
        =       "Idle",0
        =       "Stop",0
        =       "Status",0
        =       "Contrast",0
        =       "Refresh",0
        =       "Halt",0
        =       "SleepTime",0
        =       "SMBusOp",0
        =       "Speed2",0
        =       "WakeTime",0
        =       "EnumerateBMU",0
        =       "ReadBMUVariables",0
        =       "ReadSensor",0
        =       0
        ALIGN

;******************************************************************************


SWIUnknown
 [ :LNOT: Speed
SWISpeed
 ]
SWIControl
SWI_WriteBMUVariable
SWI_CommandBMU
SWIStop
SWIStatus
SWIPortable_Contrast
SWIRefresh
SWIHalt
SWISleepTime
SWISMBusOp
SWIWakeTime
        Push    "r4,lr"
        ADR     r0, ErrorBlock_ModuleBadSWI
        ADR     r4, ModuleTitle
        BL      ErrorLookup1Parm
        Pull    "r4,pc"


;******************************************************************************
;
; SWI Portable_ReadFeatures
;
; Exit
;   R1  = bit 0 set to indicate SWI Portable_Speed is impletemted
;         bit 4 set to indicate SWI Portable_Idle is impletemted
;
; All other bits in R1 zeroed, all other registers preserved.
;
SWIReadFeatures ROUT
        Entry
        LDR     R1, Idle
        CMP     R1, #0
        MOVNE   R1, #PortableFeature_Idle
 [ Speed
        LDR     LR,CPUClkDevice
        CMP     LR,#0
        ORRNE   R1,R1,#PortableFeature_Speed
 ]
        EXIT

 [ Speed
;******************************************************************************
;
; SWI Portable_Speed - Read/write processor speed
;
; in:   R0 = EOR mask
;       R1 = AND mask
;
;       New value = (Old value AND R1) EOR R0
;
;       0 => fast
;       1 => slow
;
; out:  R0 = old value
;       R1 = new value
;
SWISpeed
        Push    "R2-R4,LR"
        MRS     R4,CPSR
        ORR     R3,R4,#I32_bit
        MSR     CPSR_c,R3
        

        LDR     R2,CPUSpeed
        AND     R3,R1,R2
        EOR     R3,R3,R0
        Push    "R2-R3"
        STR     R3,CPUSpeed

        ; Only call the HAL if the speed actually changed
        ; This assumes nothing else is poking around changing the CPU speed behind our back!
        EOR     R1,R2,R3
        TST     R1,#1
        BEQ     %FT10
        LDR     R0,CPUClkDevice
        CMP     R0,#0
        BEQ     %FT10
        ; Also skip calling the HAL if CPUSpeed_Fast == CPUSpeed_Slow
        LDR     R1,CPUSpeed_Fast
        LDR     R2,CPUSpeed_Slow
        CMP     R1,R2
        BEQ     %FT10

 [ DebugSpeed
        Push    "R0,R3,R8-R9,R12"
        MOV     R0, #DebugTimer
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        LDR     R1, LastTimer
        STR     R0, LastTimer
        SUB     R1,R1,R0
        Pull    "R0,R3"
        TST     R3,#1
        LDREQ   R2,SlowTime
        LDRNE   R2,FastTime
        ADD     R2,R2,R1
        STREQ   R2,SlowTime
        STRNE   R2,FastTime
        LDREQ   R1,CPUSpeed_Fast
        LDRNE   R1,CPUSpeed_Slow
 |
        TST     R3,#1
        MOVNE   R1,R2
 ]
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkSet]
        ; TODO - Error checking
 [ DebugSpeed
        MOV     R0, #DebugTimer
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        Pull    "R8-R9,R12"
        LDR     R1, LastTimer
        STR     R0, LastTimer
        SUB     R1,R1,R0
        LDR     R0, ChangeTime
        ADD     R0,R0,R1
        STR     R0, ChangeTime
 ]
10
        MSR     CPSR_cf,R4 ; Restore interrupts and V flag (which we're assuming started off as clear!)
        Pull    "R0-R4,PC"
 ]

;******************************************************************************
;
; SWI Portable_Idle - Places the system into idle mode.
;
; The CPU clock is stopped, but all other clocks run normally. This means the
; Video display and all the IO channels are active, the DRAM is refreshed, but
; the system consumes less power as the CPU is inactive. The CPU remains in
; this state until it receives a FIQ or IRQ interrupt (eg from the keyboard,
; floppy, centi-second timer etc).
;
SWIIdle
 [ DebugSpeed
        Entry   "R0-R5,R8-R9"
        MRS     R4,CPSR
        ORR     R3,R4,#I32_bit
        MSR     CPSR_c,R3
        MOV     R0, #DebugTimer
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        MOV     R5, R0
        BL      %FT50
        MOV     R0, #DebugTimer
        SWI     OS_Hardware
        SUB     R0, R5, R0
        LDR     R1, CPUSpeed
        TST     R1, #1
        LDREQ   R1, FastIdle
        LDRNE   R1, SlowIdle
        ADD     R1, R1, R0
        STREQ   R1, FastIdle
        STRNE   R1, SlowIdle
        MSR     CPSR_cf,R4
        EXIT
50
 ]
        ; Issue a DSB before the WFI to ensure any important writes have fully drained
        Entry   "R0" ; DSB ARMop may corrupt R0
        LDR     LR, Idle
        CMP     LR, #0
        LDRNE   PC, DSB_Write ; Call DSB, with tail-call to WFI code
        EXIT

 [ SupportARMv6 :LAND: NoARMv7
   [ Erratum_486865 = "Workaround"
        ; Use the ARMv6 NOP instruction, just in case MOV R0,R0 stops the workaround from working
        MACRO
        NOPinstr
        DCI     &E320F000
        MEND

Idle_ARM11
        MOV     R0, #2
10
        SUBS    R0, R0, #1
        NOPinstr
        MCREQ   p15, 0, R0, c7, c0, 4
        NOPinstr
        NOPinstr
        NOPinstr
        BNE     %BT10
        EXIT
        ASSERT  . - Idle_ARM11 = WFI_code_size
   ]

Idle_CP15
        MOV     R10, #0
        MCR     p15, 0, R10, c7, c0, 4
        EXIT
 ]

 [ SupportARMv7
Idle_WFI
        WFI
        EXIT
 ]

;******************************************************************************
;
; SWI Portable_Speed2 - Extra CPU speed controls to augment Portable_Speed
;
; Entry:
;    R0 = reason code:
;         0 = Report current CPU speed in (MHz in R0)
;         1 = Report min & max CPU speed in (MHz in R0, R1)
;         2 = Set 'slow' and 'fast' speeds in MHz (from R1, R2). Returns actual new speeds in R1, R2.
;         3 = Report current 'slow' and 'fast' speeds (MHz in R1, R2)
;         4 = Report number of speeds available (in R0)
;         5 = Convert table idx to MHz (R1->R0)
;         6 = Convert MHz to table index (R1->R0)
;         7 = Report current CPU speed (idx in R0)
;         8 = Set 'slow' and 'fast' speeds in table idx (from R1, R2). Returns actual new indices in R1, R2.
;         9 = Report current 'slow' and 'fast' speeds (idx in R1, R2)
 [ DebugSpeed
;        -1 = Report debug stats. R0=FastTime, R1=SlowTime, R2=ChangeTime, R3=FastIdle, R4=SlowIdle, R5=granularity
 ]
;
SWISpeed2
        LDR     R11,CPUClkDevice
        CMP     R11,#0
        BEQ     SWINoSpeed2
 [ DebugSpeed
        CMP     R0,#-1
        BEQ     SWISpeed2_Debug
 ]
        CMP     R0,#9
        ADDLS   PC,PC,R0,LSL#2
        B       SWIBadSpeed2
        B       SWISpeed2_ReportMHz
        B       SWISpeed2_ReportMinMaxMHz
        B       SWISpeed2_SetSlowFastMHz
        B       SWISpeed2_GetSlowFastMHz
        B       SWISpeed2_NumIdx
        B       SWISpeed2_IdxToMHz
        B       SWISpeed2_MHzToIdx
        B       SWISpeed2_ReportIdx
        B       SWISpeed2_SetSlowFastIdx
        B       SWISpeed2_GetSlowFastIdx

SWISpeed2_ReportMHz
        Entry   "R1-R3"
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkGet]
        MOV     R1,R0
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkInfo]
        CLRV
        EXIT

SWISpeed2_ReportMinMaxMHz       
        Push    "R2-R3,LR"
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkNumSpeeds]
        SUB     R1,R0,#1
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkInfo]
        Push    "R0"
        MOV     R0,R11
        MOV     R1,#0
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkInfo]
        CLRV
        Pull    "R1-R3,PC"

SWISpeed2_SetSlowFastMHz
        Entry   "R1-R3,R12"
        ; Convert to table idx
        BL      SWISpeed2_MHzToIdx
        MOVVC   R3,R0
        MOVVC   R1,R2
        BLVC    SWISpeed2_MHzToIdx
        EXIT    VS
        ; Call idx code
        FRAMLDR R12
        MOV     R2,R0
        MOV     R1,R3
        BL      SWISpeed2_SetSlowFastIdx
        PullEnv
        MOVVS   PC,LR
        ; Fall through...
        MOV     R0,#2 ; SetSlowFastMHz reason code
SWISpeed2_GetSlowFastMHz
        Entry   "R0,R3,R12"
        LDR     R1,CPUSpeed_Fast
        BL      SWISpeed2_IdxToMHz
        MOV     R2,R0
        FRAMLDR R12
        LDR     R1,CPUSpeed_Slow
        BL      SWISpeed2_IdxToMHz
        MOV     R1,R0
        EXIT

SWISpeed2_NumIdx
        Entry   "R1-R3"
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkNumSpeeds]
        CLRV
        EXIT

SWISpeed2_IdxToMHz
        ; Assume the input is in range
        Entry   "R1-R3"
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkInfo]
        CLRV
        EXIT

SWISpeed2_MHzToIdx
        Entry   "R1-R4"
        MOV     R10,R1
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkNumSpeeds]
        SUB     R4,R0,#1
10
        MOV     R0,R11
        MOV     R1,R4
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkInfo]
        SUBS    R4,R4,#1
        CMPGE   R0,R10
        BGT     %BT10 ; new R4>=0 and R0 > R10
        ADD     R0,R4,#1 ; Cancel out the pre-decrement
        EXIT

SWISpeed2_ReportIdx
        Entry   "R1-R3"
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkGet]
        EXIT
       
SWISpeed2_SetSlowFastIdx
        Entry   "R1-R4,R12"
        ; Interrupts off to keep this atomic
        MRS     R4,CPSR
        ORR     R3,R4,#I32_bit
        MSR     CPSR_c,R3
        ; Clamp input values, ensure fast >= slow
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkNumSpeeds]
        LDMIA   R13,{R1-R2}
        CMP     R1,#0
        MOVLT   R1,#0
        CMP     R2,#0
        MOVLT   R2,#0
        CMP     R1,R0
        SUBGE   R1,R0,#1
        CMP     R2,R0
        SUBGE   R2,R0,#1
        CMP     R1,R2
        MOVGE   R1,R2
        ; Remember the new values
        STMIA   R13,{R1-R2}
        FRAMLDR R12
        STR     R1,CPUSpeed_Slow
        STR     R2,CPUSpeed_Fast
        ; Update speed depending on current slow/fast value
        LDR     R3,CPUSpeed
        TST     R3,#1
        MOVEQ   R1,R2
        MOV     R0,R11
        MOV     LR,PC
        LDR     PC,[R0,#HALDevice_CPUClkSet]
        MSR     CPSR_cf,R4 ; Restore interrupts and V flag (which we're assuming started off as clear!)
        EXIT

SWISpeed2_GetSlowFastIdx
        LDR     R1,CPUSpeed_Slow
        LDR     R2,CPUSpeed_Fast
        MOV     PC,LR

 [ DebugSpeed
SWISpeed2_Debug
        Entry   "R6,R8-R9"
        MRS     R6, CPSR
        ORR     R0,R6,#I32_bit
        MSR     CPSR_c,R0
        ; Grab granularity
        MOV     R0, #DebugTimer
        MOV     R8, #OSHW_CallHAL
        MOV     R9, #EntryNo_HAL_TimerGranularity
        SWI     OS_Hardware
        MOV     R5, R0
        MOV     R0, #DebugTimer
        MOV     R9, #EntryNo_HAL_TimerReadCountdown
        SWI     OS_Hardware
        LDR     R1, LastTimer
        STR     R0, LastTimer
        SUB     R8, R1, R0
        LDR     R1, CPUSpeed
        ADR     R9, FastTime
        TST     R1, #1
        LDMIA   R9, {R0-R4} ; Grab return values
        ADDEQ   R0, R0, R8 ; Make sure time is up to date
        ADDNE   R1, R1, R8
        ; Zero out cumulative values
        MOV     R8, #0
        STR     R8, FastTime
        STR     R8, SlowTime
        STR     R8, ChangeTime
        STR     R8, FastIdle
        STR     R8, SlowIdle
        MSR     CPSR_cf,R6
        EXIT
 ]

SWINoSpeed2
        ADRL    r0, ErrorBlock_NoSpeed2
        B       ErrorLookupNoParms

SWIBadSpeed2
        ADRL    r0, ErrorBlock_BadSpeed2
        B       ErrorLookupNoParms

;******************************************************************************

;
; Entry:
;    R2 -> BMU HAL device
;
; Exit:
;    All regs preserved
;
AddBMUDevice ROUT
        Entry   "r0-r3,r9"
        ; Check this device isn't already listed
        LDR     r0, BMUDevCount
        LDR     r1, BMUDevList
        MOV     r3, #0
10
        TEQ     r0, r3
        BEQ     %FT20
        LDR     r9, [r1, r3, LSL #2]
        TEQ     r9, r2
        EXIT    EQ
        ADD     r3, r3, #1
        B       %BT10
20
        ; Realloc memory
        MOVS    r2, r1
        MOV     r3, #4
        MOVEQ   r0, #ModHandReason_Claim
        MOVNE   r0, #ModHandReason_ExtendBlock
        SWI     XOS_Module
        EXIT    VS
        STR     r2, BMUDevList
        ; Activate device
        LDR     r0, [sp, #8]
        Push    "r12"
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_Activate]
        Pull    "r12"
        TEQ     r0, #1
        BNE     %FT30
        ; Success!
        LDR     r0, BMUDevCount
        LDR     r1, BMUDevList
        LDR     r2, [sp, #8]
        STR     r2, [r1, r0, LSL #2]
        ADD     r0, r0, #1
        STR     r0, BMUDevCount
        ; If this device powers the system, and we don't have a dev 0 yet, use it for dev 0
        LDR     r0, BMUDev0
        CMP     r0, #0
        EXIT    NE
        LDR     r0, [sp, #8]
        LDR     r1, [r0, #HALDevice_BMUFlags]
        TST     r1, #PortableBMUDF_System
        STRNE   r0, BMUDev0
        EXIT
30
        ; Failed to init, free the extra memory we claimed
        LDR     r1, BMUDevCount
        LDR     r2, BMUDevList
        TEQ     r0, #0
        MOVEQ   r0, #ModHandReason_Free
        MOVNE   r0, #ModHandReason_ExtendBlock
        MOVNE   r3, #-4
        SWI     XOS_Module
        TEQ     r1, #0
        MOVEQ   r2, #0
        STRVC   r2, BMUDevList
        EXIT

;
; Entry:
;    R2 -> BMU HAL device
;
; Exit:
;    All regs preserved
;
RemoveBMUDevice ROUT
        Entry   "r0-r3,r9"
        ; Find the device in the list
        LDR     r0, BMUDevCount
        LDR     r1, BMUDevList
        MOV     r3, #0
10
        TEQ     r0, r3
        EXIT    EQ
        LDR     r9, [r1, r3, LSL #2]
        TEQ     r9, r2
        ADDNE   r3, r3, #1
        BNE     %BT10
        ; Shuffle all the other entries down
        ADD     r1, r1, r3, LSL #2
        ADD     r3, r3, #1
20
        TEQ     r0, r3
        BEQ     %FT30
        LDR     r9, [r1, #4]
        STR     r9, [r1], #4
        B       %BT20
30
        SUB     r0, r0, #1
        STR     r0, BMUDevCount
        ; Deactivate device
        Push    "r12"
        MOV     r0, r2
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_Deactivate]
        Pull    "r12"
        ; Free memory
        LDR     r1, BMUDevCount
        LDR     r2, BMUDevList
        TEQ     r0, #0
        MOVEQ   r0, #ModHandReason_Free
        MOVNE   r0, #ModHandReason_ExtendBlock
        MOVNE   r3, #-4
        SWI     XOS_Module
        TEQ     r1, #0
        MOVEQ   r2, #0
        STRVC   r2, BMUDevList
        ; Discard dev 0 if this was it
        ; Note that we don't attempt to look for another device to replace it (for the moment we assume the device was created by the HAL and won't go missing anyway)
        LDR     r0, [sp, #8]
        LDR     r1, BMUDev0
        CMP     r0, r1
        MOVEQ   r0, #0
        STREQ   r0, BMUDev0
        EXIT

;
; Entry:
;    R0 = Previous BMU index (-1 to start enumeration)
;    R1 = Extra flags (reserved, should be 0)
;
; Exit:
;    R0 = This BMU index, -1 for none
;    R1 = BMU flags          (only valid if R0<>-1)
;    R2 = Supported status flags      " "
;
;    R1-R2 corrupt on error
;
SWIEnumerateBMU ROUT
        TEQ     r1, #0
        ADRNEL  r0, ErrorBlock_BadFlags
        BNE     ErrorLookupNoParms
        LDR     r1, BMUDevCount
        TEQ     r1, #0
        BEQ     Error_BadBMU
        ADDS    r0, r0, #1
        BEQ     %FT10
        ADD     r1, r1, #1
        CMP     r0, r1
        BHI     Error_BadBMU
        MOVEQ   r0, #-1
        MOVEQ   pc, lr
15
        LDR     r1, BMUDevList
        SUB     r1, r1, #4
        LDR     r1, [r1, r0, LSL #2]
20
        LDR     r2, [r1, #HALDevice_BMUStatusFlagsMask]
        LDR     r1, [r1, #HALDevice_BMUFlags]
        MOV     pc, lr

10
        ; Does BMU 0 exist?
        LDR     r1, BMUDev0
        TEQ     r1, #0
        BNE     %BT20
        ; BMU 0 doesn't exist, return BMU 1
        MOV     r0, #1
        B       %BT15


;
; Entry:
;    R0 = BMU index
;    R1 = Number of variables to read
;    R2 = Pointer to PortableReadBMUVars list
;
; Exit:
;    List updated
;    All regs preserved
;
SWIReadBMUVariables ROUT
        Entry   "r0-r3,r12"
        TEQ     r0, #0
        BNE     %FT05
        LDR     r0, BMUDev0
        TEQ     r0, #0
        BEQ     %FT10
        B       %FT08
05
        LDR     r3, BMUDevCount
        SUB     r0, r0, #1
        CMP     r0, r3
        BHI     %FT10
        LDR     r3, BMUDevList
        LDR     r0, [r3, r0, LSL #2]
08
        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_BMUReadVariables]
        CLRV
        EXIT
10
        PullEnv
Error_BadBMU
        ADRL    r0, ErrorBlock_BadBMU
        B       ErrorLookupNoParms


;
; Entry:
;    R0  bits 0-23 = variable index
;        bits 24-31 = BMU index
;
; Exit:
;    R1 = variable value
;    All other regs preserved
;
SWI_ReadBMUVariable ROUT
        Entry   "r0-r2"
        ; Construct a PortableReadBMUVars item on the stack
        BIC     r1, r0, #&ff000000
        MOV     r0, r0, LSR #24
        ASSERT  PortableReadBMUVars_VarNo = 0
        STR     r1, [sp, #-PortableReadBMUVars_Size]!
        MOV     r1, #1
        MOV     r2, sp
        BL      SWIReadBMUVariables
        BVS     %FT90
        LDR     r0, [sp, #PortableReadBMUVars_Result]
        TEQ     r0, #PortableBMUR_Unknown
        MOVEQ   r1, #-1 ; Return -1 for unknown (deviation from original spec which used 255 due to 8 bit var width)
        BEQ     %FT70
        TEQ     r0, #PortableBMUR_Success
        BNE     %FT80
        LDR     r1, [sp, #PortableReadBMUVars_Value]
70
        ADD     sp, sp, #PortableReadBMUVars_Size
        STR     r1, [sp, #4]
        EXIT
80
        ; Translate PortableBMUR error
        ADR     r1, PortableBMUR_ErrorTable
        LDR     r0, [r1, r0, LSL #2]
        ADD     r0, r0, r1
        STR     r0, [sp, #PortableReadBMUVars_Size]!
        PullEnv
        B       ErrorLookupNoParms
90
        ; Exit with error in R0
        STR     r0, [sp, #PortableReadBMUVars_Size]!
        EXIT

        MACRO
        BMURE   $result, $error
        ASSERT  . - PortableBMUR_ErrorTable = PortableBMUR_$result*4
        DCD     ErrorBlock_$error - PortableBMUR_ErrorTable
        MEND
        
PortableBMUR_ErrorTable
        ; Success is handled above
        ASSERT  PortableBMUR_Success = 0
        DCD     0
        BMURE   Error, BMUFault
        BMURE   Busy, BMUBusy
        BMURE   Unsupported, BadBMUVariable
        ; Unknown is handled above
        ASSERT  . - PortableBMUR_ErrorTable = PortableBMUR_Unknown*4
        DCD     0


;
; Entry:
;    R0 = Sensor index
;         0 => temperature (scaled to 0.1K per LSB) 
;         others => reserved for future use
;    R1 = Unit type
;         0 => CPU die
;         1 => BMU
;         others => reserved for future use
;    R2 = Unit index
;         0-N => as appropriate for unit N
;
; Exit:
;    R0 = Sensor value
;    All other regs preserved
;
SWIReadSensor ROUT
        Entry   "R1-R3"
        CMP     r0, #PortableReadSensor_Temperature
        BNE     %FT90                   ; Reserved sensor

        CMP     r1, #PortableRS_Temperature_Max
        ADDLO   pc, pc, r1, LSL #2
        B       %FT90                   ; Out of range temperature sensor
RS_Table
        B       RS_CPUDie
        B       RS_BMU
        B       %FT90                   ; } Sensors with
        B       %FT90                   ; } no HAL
        B       %FT90                   ; } backend 
        ASSERT  (. - RS_Table) :SHR: 2 = PortableRS_Temperature_Max

RS_CPUDie
        TEQ     r2, #0                  
        BNE     %FT90                   ; No multicore :-(

        LDR     r0, CPUClkDevice
        LDR     r2, [r0, #HALDevice_Version]
        CMP     r2, #(0:SHL:16):OR:2    
        BCC     %FT90                   ; Need API 0.2

        MOV     lr, pc
        LDR     pc, [r0, #HALDevice_CPUClkGetDieTemperature]
        EXIT

RS_BMU        
        MOV     r0, #PortableBMUV_Temperature
        ORR     r0, r0, r2, LSL #24     ; Nth BMU
        SWI     XPortable_ReadBMUVariable
        MOVVC   r0, r1
        EXIT
90
        PullEnv
        ADRL    r0, ErrorBlock_UKSensor
        B       ErrorLookupNoParms

;******************************************************************************

ErrorLookupNoParms      Entry   "R1-R7"
;
; Entry:
;    R0 -> error block with tokenised message
;
; Exit:
;    R0 -> error block with real message
;    V set

        MOV     R4,#0                           ; no parameter 0
        B       ErrorLookupContinue

ErrorLookup1Parm        ALTENTRY
;
; Entry:
;    R0 -> error block with tokenised message
;    R4 -> parameter to substitute into error
;
; Exit:
;    R0 -> error block with real message
;    V set

ErrorLookupContinue

        wsaddr  R1,MsgTransBlk
        MOV     R2,#0                           ; use internal buffer
        MOV     R5,#0                           ; no parameter 0
        MOV     R6,#0                           ; no parameter 0
        MOV     R7,#0                           ; no parameter 0
        SWI     XMessageTrans_ErrorLookup
        EXIT

;******************************************************************************

TryClockDevice  ROUT
;
; Entry:
;    R2 -> CPUClk HAL device
;
        Entry   "R0-R3,R8,R12"
        MOV     R8, R2
        MOV     R0, R2
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_Activate]
        FRAMLDR R12
        CMP     R0, #1
        EXIT    NE
        ; Set up some default slow & fast speeds. For now just use min & max clock speed.
        MOV     R0, #0
        STR     R0, CPUSpeed_Slow
        MOV     R0, R8
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_CPUClkNumSpeeds]
        FRAMLDR R12
        SUB     R1, R0, #1
        STR     R1, CPUSpeed_Fast
        ; Go fast!
        MOV     R0, R8
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_CPUClkSet]
        FRAMLDR R12
        ; Make device available
        STR     R8, CPUClkDevice
        EXIT

DeactivateClockDevice ROUT
        Entry   "R0-R3,R8,R12"
        LDR     R8, CPUClkDevice
        MOV     R0, #0
        STR     R0, CPUClkDevice
        ; Go fast
        MOV     R0, R8
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_CPUClkNumSpeeds]
        SUB     R1, R0, #1
        MOV     R0, R8
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_CPUClkSet]
        ; Now deactivate
        MOV     R0, R8
        MOV     LR, PC
        LDR     PC, [R0, #HALDevice_Deactivate]
        EXIT

;******************************************************************************

 [ Debug
        InsertDebugRoutines
 ]

;******************************************************************************

        END
