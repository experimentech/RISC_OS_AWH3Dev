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
        TTL     => Kernel : SWI Despatch, simple SWIs
        SUBT    Arthur Variables
        OPT     4

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; handy macros:
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MACRO
        DebugReg $reg, $str
    [ DebugHALTX
     Push "$reg"
     [ "$str" <> ""      
        BL      DebugHALPrint
        =       "$str", 0
        ALIGN
     ]
     bl  DebugHALPrintReg
    ]
        MEND

        MACRO
        DebugTX $str
    [ DebugHALTX
        BL      DebugHALPrint
        =       "$str", 13,10,00
        ALIGN
    ]
        MEND

        MACRO
$l      CheckSpaceOnStack   $space, $faildest, $tmp
$l      MOV     $tmp, sp, LSR #15       ; Stack base on 32K boundary
        SUB     $tmp, sp, $tmp, LSL #15 ; Amount of stack left
        CMP     $tmp, #$space           ; Must have at least this much left
        BMI     $faildest
        MEND

        MACRO
        assert  $condition
 [ :LNOT: ($condition)
 ! 1,"Assert failed: $condition"
 ]
        MEND

; **************************************
; ***  BYTEWS - Point to OsbyteVars  ***
; **************************************
        MACRO
$label  BYTEWS  $reg
$label  LDR     $reg,=ZeroPage+OsbyteVars
        MEND

; ***************************************
; ***  LDROSB - Load Osbyte variable  ***
; ***************************************
        MACRO
$label  LDROSB  $reg, $var, $cond
$label  LDR$cond $reg, =ZeroPage
        LDR$cond.B $reg, [$reg, #OsbyteVars+$var-OSBYTEFirstVar]
        MEND

; ****************************************
; ***  STROSB - Store Osbyte variable  ***
; ****************************************
        MACRO
$label  STROSB  $reg, $var, $temp, $cond
$label  LDR$cond $temp, =ZeroPage
        STR$cond.B $reg, [$temp, #OsbyteVars+$var-OSBYTEFirstVar]
        MEND

; ****************************************************
; ***  VDWS - Point to our new VduDriverWorkSpace  ***
; ****************************************************
        MACRO
$label  VDWS    $reg
$label  LDR     $reg, =ZeroPage+VduDriverWorkSpace
        MEND

; *******************************************************************
; ***  MyCLREX - Manually clear exclusive monitor                 ***
; ***  Consult the ARM ARM for details of when this is required!  ***
; *******************************************************************
        MACRO
        MyCLREX $temp1, $temp2
      [ NoARMv6
        ASSERT  :LNOT: SupportARMv6
        ; No action required
      ELIF NoARMK
        ; ARMv6, need dummy STREX
        ; Use the word below SP
        SUB     $temp1, r13, #4
        STREX   $temp2, $temp1, [$temp1]
      |
        ; ARMv6K+, have CLREX
        CLREX
      ]
        MEND

; *****************************************************
; ***  Call Get4KPTE/Get64KPTE/Get1MPTE functions,  ***
; ***  with arbitrary in/out regs                   ***
; *****************************************************
        MACRO
        GetPTE  $out, $size, $addr, $flags
        Push    "r0-r3,lr"
      [ $flags <> r1
        MOV     r1, $flags
      ]
      [ $addr <> r0
        ASSERT  $addr <> r1
        MOV     r0, $addr
      ]
        LDR     r3, =ZeroPage
        LDR     r2, [r3, #MMU_PPLTrans]
        LDR     r3, [r3, #MMU_PCBTrans]
        BL      Get$size.PTE
      [ :INDEX:$out < 4
        STR     r0, [sp, #:INDEX:$out * 4]
      |
        MOV     $out, r0
      ]
        Pull    "r0-r3,lr"
        MEND

; *******************************************************************
; ***  Convert RWX flags to OS_Memory 24 flags                    ***
; ***  N.B. this is using the inverted executability sense (i.e.  ***
; ***  bit set if executable) - see notes in CheckMemoryAccess    ***
; *******************************************************************
        MACRO
        GenPPLAccess $flags
        LCLA    access
access  SETA    0
      [ ($flags :AND: 1) <> 0
access  SETA    access :OR: CMA_Partially_UserXN
      ]                
      [ ($flags :AND: 2) <> 0
access  SETA    access :OR: CMA_Partially_UserW
      ]                
      [ ($flags :AND: 4) <> 0
access  SETA    access :OR: CMA_Partially_UserR
      ]                
      [ ($flags :AND: 8) <> 0
access  SETA    access :OR: CMA_Partially_PrivXN
      ]                
      [ ($flags :AND: 16) <> 0
access  SETA    access :OR: CMA_Partially_PrivW
      ]                
      [ ($flags :AND: 32) <> 0
access  SETA    access :OR: CMA_Partially_PrivR
      ]
        DCD     access
        MEND

; **********************************************************
; ***  PageTableSync - Sync the CPU after overwriting a  ***
; ***  faulting page table entry. Corrupts r0, lr.       ***
; **********************************************************
        MACRO
        PageTableSync$cond
    [ SyncPageTables
      [ MEMM_Type = "VMSAv6"
        ; DSB + ISB required to ensure effect of page table write is fully
        ; visible (after overwriting a faulting entry)
        myDSB   $cond,r0
        myISB   $cond,r0,,y
      |
        ; For < ARMv6 draining the write buffer should be sufficient
        ; (write-through or bufferable page tables)
        LDR$cond r0, =ZeroPage
        ARMop    DSB_ReadWrite,$cond,,r0 ; N.B. assume that this op won't corrupt NZCV
      ]
    ]
        MEND        

; one that builds a module command table entry:
; set Module_BaseAddr to module base before use.

                GBLA    Module_BaseAddr
Module_BaseAddr SETA    0

;

a1      RN      0
a2      RN      1
a3      RN      2
a4      RN      3
v1      RN      4
v2      RN      5
v3      RN      6
v4      RN      7
v5      RN      8
v6      RN      9
sb      RN      9
v7      RN      10
v8      RN      11

; Set sb up ready for CallHAL.
        MACRO
        AddressHAL $zero
 [ "$zero" <> ""
        LDR     sb, [$zero, #HAL_Workspace]
 |
        LDR     sb, =ZeroPage
        LDR     sb, [sb, #HAL_Workspace]
 ]
        MEND

; Calls the HAL. $rout is the routine. sb must have been set up by AddressHAL
        MACRO
        CallHAL $rout, $cond
        MOV$cond lr, pc
        LDR$cond pc, [sb, #-(EntryNo_$rout+1) * 4]
        MEND

; Checks whether a HAL routine exists. If it does, $ptr points to it, and Z is
; clear. lr corrupted.
        MACRO
        CheckHAL $rout, $ptr
      [ "$ptr"=""
        LDR     a1, [sb, #-(EntryNo_$rout+1) * 4]
        ADRL    lr, NullHALEntry
        TEQ     a1, lr
      |
        LDR     $ptr, [sb, #-(EntryNo_$rout+1) * 4]
        ADRL    lr, NullHALEntry
        TEQ     $ptr, lr
      ]
        MEND


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Various constants
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

PageSize          * (4*1024)       ;MMU page size (normal pages)
Log2PageSize      * 12             ;for shifts

MinAplWork * 40*1024         ; minimum size of AplWork

; Fixed addresses

MEMCADR  * &03600000
        GBLL    ROMatTop
ROM      * &FC000000
ROMatTop SETL {TRUE}

; Manifests

CR * 13
LF * 10
space * " "

; Callback byte bits:
CBack_OldStyle  * 1
CBack_Postpone  * 2
CBack_VectorReq * 4

; AMBControl definitions - required by GetAppSpaceDANode macro

        GET     s.AMBControl.Options
        GET     s.AMBControl.Workspace

        MACRO
        GetAppSpaceDANode $out, $zero
      [ "$zero" <> ""
        LDR     $out, [$zero, #AMBControl_ws]
      |
        LDR     $out, =ZeroPage+AMBControl_ws
        LDR     $out, [$out]
      ]
        TEQ     $out, #0
        LDRNE   $out, [$out, #:INDEX:AMBMappedInNode]
        TEQNE   $out, #0
        ADDNE   $out, $out, #AMBNode_DANode
      [ "$zero" <> "" :LAND: "$zero" <> "$out"
        ADDEQ   $out, $zero, #AppSpaceDANode
      |
        LDREQ   $out, =ZeroPage+AppSpaceDANode
      ]
        MEND

        SUBT    Arthur Code
        OPT     4

        ORG     ROM + OSROM_HALSize

        AREA    |!!!!OSBase|,CODE,READONLY

        ENTRY                   ; Not really, but we need it to link
KernelBase

; *****************************************************************************
;
;  Now ready to start the code: off we go!
;
; *****************************************************************************

; RISC OS image header
RISCOS_Header
        =       "OSIm"
        DCD     OSHdrFlag_SupportsCompression
        DCD     OSROM_ImageSize*1024 - OSROM_HALSize
        DCD     RISCOS_Entries - RISCOS_Header
        DCD     (RISCOS_Entries_End - RISCOS_Entries) / 4
        DCD     OSROM_ImageSize*1024 - OSROM_HALSize
        DCD     0
        DCD     EndOfKernel - RISCOS_Header
        ASSERT  (. - RISCOS_Header) = OSHdr_size 

RISCOS_Entries
        DCD     RISCOS_InitARM   - RISCOS_Entries
        DCD     RISCOS_AddRAM    - RISCOS_Entries
        DCD     RISCOS_Start     - RISCOS_Entries
        DCD     RISCOS_MapInIO   - RISCOS_Entries
        DCD     RISCOS_AddDevice - RISCOS_Entries
        DCD     RISCOS_LogToPhys - RISCOS_Entries
        DCD     RISCOS_IICOpV    - RISCOS_Entries
RISCOS_Entries_End

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This bit (up to EndFiq) is copied to location 0.  Processor vectors are
; indirected through 0 page locations so that they can be claimed using
; OS_ClaimProcessorVector.  IRQs are initially handled specially so that the
; keyboard can be handled during reset but the load is replaced with the
; standard one later on.

MOSROMVecs
        LDR     pc, MOSROMVecs+ProcVec_Branch0
        LDR     pc, MOSROMVecs+ProcVec_UndInst
        LDR     pc, MOSROMVecs+ProcVec_SWI
        LDR     pc, MOSROMVecs+ProcVec_PrefAb
        LDR     pc, MOSROMVecs+ProcVec_DataAb
        LDR     pc, MOSROMVecs+ProcVec_AddrEx
        LDR     pc, MOSROMVecs+InitIRQHandler
EndMOSROMVecs

        ASSERT  InitIRQHandler >= EndMOSROMVecs - MOSROMVecs

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This is the table of default processor vectors which is copied to 0 page.

DefaultProcVecs
        &       Branch0_NoTrampoline
        &       UndPreVeneer
        &       SVC
        &       PAbPreVeneer
        &       DAbPreVeneer
        &       AdXPreVeneer
        &       Initial_IRQ_Code

        ASSERT  (.-DefaultProcVecs) = ProcVec_End-ProcVec_Start

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; These are preveneers which must be copied to 0 page locations so that the
; relevant handler can be branched to.  This is mainly for non-ARM600 platforms
; although the address exception preveneer (which should not actually be required
; on ARM600) is always copied.

DefaultPreVeneers
UndPreVeneer    *       ZeroPage+ProcVecPreVeneers+(.-DefaultPreVeneers)
        LDR     PC, DefaultPreVeneers-ProcVecPreVeneers+UndHan
   [ AMB_LazyMapIn
        DCD     0
   |
PAbPreVeneer    *       ZeroPage+ProcVecPreVeneers+(.-DefaultPreVeneers)
        LDR     PC, DefaultPreVeneers-ProcVecPreVeneers+PAbHan
   ]
        DCD     0
AdXPreVeneer    *       ZeroPage+ProcVecPreVeneers+(.-DefaultPreVeneers)
        LDR     PC, DefaultPreVeneers-ProcVecPreVeneers+AdXHan

        ASSERT  (.-DefaultPreVeneers) = ProcVecPreVeneersSize

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; This is the trampoline in the system heap used to handle branch through 0.

Branch0_Trampoline
        STR     r1, Branch0_Trampoline + Branch0_Trampoline_SavedR1
        STR     lr, Branch0_Trampoline + Branch0_Trampoline_SavedR14
        ADD     lr, pc, #4
        LDR     pc, .+4
        &       Branch0_FromTrampoline
Branch0_Trampoline_Init     * .-Branch0_Trampoline
Branch0_Trampoline_SavedR1  * .-Branch0_Trampoline
Branch0_Trampoline_SavedR14 * .-Branch0_Trampoline+4
Branch0_Trampoline_Size     * .-Branch0_Trampoline+8


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Now some initialised workspace/vectors that go at &100

; All the stuff from here to after the DirtyBranch instruction is read
; consecutively out of ROM, so don't put anything in between without changing
; the code


StartData
        ASSERT IRQ1V = &100
        & DefaultIRQ1V

        ASSERT ESC_Status = IRQ1V+4
        & &00FF0000       ; IOCControl set to FF on reset

        ASSERT IRQsema = ESC_Status+4
        & 0
EndData

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI return handler: checks callback
; no branches or interlocks in the common case: V clear, no callback

SVCDespatcher ROUT

SWIRelocation * SVCDespatcher-SWIDespatch

SLVK_SetV * {PC}-SWIRelocation

        ORR     lr, lr, #V_bit

SLVK_TestV * {PC}-SWIRelocation
 ! 0,"SLVK_TestV at ":CC:(:STR:SLVK_TestV)

        ORRVS   lr, lr, #V_bit

SLVK * {PC}-SWIRelocation
 ! 0,"SLVK       at ":CC:(:STR:SLVK)
Local_SLVK

        LDR     r12, [sp], #4
      [ ZeroPage = 0
        MOV     r10, #0
      |
        LDR     r10, SWIRelocationZeroPage
      ]
        MSR     CPSR_c, #I32_bit + SVC32_mode           ; IRQs off makes CallBackFlag atomic; 32bit so ready for SPSR use
        LDRB    r11, [r10, #CallBack_Flag]

        TST     lr, #V_bit
        BNE     %FT50

SWIReturnWithCallBackFlag * {PC}-SWIRelocation
 ! 0,"SWIReturnWithCallBackFlag at ":CC:(:STR:SWIReturnWithCallBackFlag)

40      TEQ     r11, #0

        MSREQ   SPSR_cxsf, lr
        LDREQ   lr, [sp], #4
        Pull    "r10-r12", EQ
        MOVEQS  pc, lr

        B       callback_checking + SWIRelocation

 ! 0,"VSetReturn at ":CC:(:STR:({PC}-SWIRelocation))
50
        ; Some programs abuse XOS_GenerateError by using it purely as a method
        ; to trigger callbacks, or to convert null terminated strings to BASIC
        ; strings. This means the R0 value might be complete garbage, and if we
        ; were to try checking it then bad things would happen.
        ; Luckily XOS_GenerateError is essentially a no-op as far as errors are
        ; concerned, so we can avoid crashing here (or corrupting the caller's
        ; R0 value) by simply ignoring the call.
        EOR     r10, r12, #Auto_Error_SWI_bit
        TEQ     r10, #OS_GenerateError
        BEQ     callback_checking + SWIRelocation       ; it's an X SWI, so jump straight to callback checks
        ; Attempt to detect bad error pointers - both to try and avoid crashing
        ; and to make bad pointers easier to debug
        CMP     r0, #&4000
        BLO     BadErrPtr + SWIRelocation
        TST     r0, #3
        LDREQ   r10, [r0]                               ; If we crash here, R12 will be the SWI number that returned the bad pointer (better than crashing later with no clue what SWI caused the problem)
      [ CheckErrorBlocks
        TSTEQ   r10, #&7f :SHL: 24                      ; Check reserved bits in error number
        BNE     BadErrPtr2 + SWIRelocation
      |
        BNE     BadErrPtr + SWIRelocation
      ]
BadErrPtrReturn * {PC}-SWIRelocation
        TST     r12, #Auto_Error_SWI_bit
        BNE     callback_checking + SWIRelocation       ; we need to do this for X errors even if the callback flags
                                                        ; are all clear, so that the postpone flag can be set

        B       VSet_GenerateError + SWIRelocation

      [ ZeroPage <> 0
SWIRelocationZeroPage
        DCD     ZeroPage
      ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The SWI Despatch routine

SVC * {PC}-SWIRelocation

        Push    "r10-r12"
 [ SupportARMT
        MRS     r12, SPSR               ; r12 = saved PSR
        TST     r12, #T32_bit           ; depending on processor state (ARM/Thumb)
        LDREQ   r11, [r14, #-4]         ; extract SWI number to r11
        LDRNEB  r11, [r14, #-2]         ; (ordering to prevent interlocks)
        BICEQ   r11, r11, #&FF000000
 |
        LDR     r11, [r14, #-4]         ; extract SWI number to r11
        MRS     r12, SPSR               ; r12 = saved PSR
        BIC     r11, r11, #&FF000000    ; (ordering to prevent interlocks)
 ]

        Push    "r11,r14"               ; push SWI number and return address

        AND     r10, r12, #I32_bit+F32_bit
        ORR     r10, r10, #SVC2632      ; set IFTMMMMM = IF0x0011
        MSR     CPSR_c, r10             ; restore caller's IRQ state

        BIC     r14, r12, #V_bit        ; clear V (some SWIs need original PSR in r12)

SVC_CallASWI * {PC}-SWIRelocation       ; CallASWI,CallASWIR12 re-entry point

        BIC     r11, r11, #Auto_Error_SWI_bit

        CMP     r11, #OS_WriteI
        LDRLO   pc, [pc, r11, LSL #2]

        B       NotMainMOSSwi + SWIRelocation

 ASSERT {PC}-SVCDespatcher = SWIDespatch_Size

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The SWI table

JTABLE  & SWIWriteC
        & SWIWriteS
        & SWIWrite0
        & SWINewLine

; next section is one where VectorNumber = SWINumber
        & VecSwiDespatch        ; readc
        & VecSwiDespatch        ; cli
        & NoIrqVecSwiDespatch   ; byte
        & NoIrqVecSwiDespatch   ; word
        & VecSwiDespatch        ; file
        & VecSwiDespatch        ; args
        & BGetSWI               ; bget
        & BPutSWI               ; bput
        & VecSwiDespatch        ; gbpb
        & VecSwiDespatch        ; find
        & ReadLineSWI

        & SCTRL
        & SWI_GetEnv_Code
        & SEXIT
        & SSTENV
        & SINTON
        & SINTOFF
        & SCALLB
        & SENTERSWI
        & SBRKPT
        & SBRKCT
        & SUNUSED
        & SSETMEMC
        & SSETCALL
        & VecMouse
        & HeapEntry
        & ModuleHandler
        & ClaimVector_SWICode
        & ReleaseVector_SWICode
        & ReadUnsigned_Routine
        & GenEvent
        & ReadVarValue
        & SetVarValue
        & GSINIT
        & GSREAD
        & GSTRANS
        & BinaryToDecimal_Code
        & FSControlSWI
        & ChangeDynamicSWI
        & GenErrorSWI
        & ReadEscapeSWI
        & ReadExpression
        & SwiSpriteOp
        & SWIReadPalette
        & Issue_Service_SWI
        & SWIReadVduVariables
        & SwiReadPoint
        & DoAnUpCall
        & CallAVector_SWI
        & SWIReadModeVariable
        & SWIRemoveCursors
        & SWIRestoreCursors
        & SWINumberToString_Code
        & SWINumberFromString_Code
        & ValidateAddress_Code
        & CallAfter_Code
        & CallEvery_Code
        & RemoveTickerEvent_Code
        & InstallKeyHandler
        & SWICheckModeValid
        & ChangeEnvironment
        & SWIClaimScreenMemory
        & ReadMetroGnome
        & XOS_SubstituteArgs_code
        & XOS_PrettyPrint_code
        & SWIPlot
        & SWIWriteN
        & Add_ToVector_SWICode
        & WriteEnv_SWICode
        & RdArgs_SWICode
        & ReadRAMFSLimits_Code
        & DeviceVector_Claim
        & DeviceVector_Release
        & Application_Delink
        & Application_Relink
        & HeapSortRoutine
        & TerminateAndSodOff
        & ReadMemMapInfo_Code
        & ReadMemMapEntries_Code
        & SetMemMapEntries_Code
        & AddCallBack_Code
        & ReadDefaultHandler
        & SWISetECFOrigin
        & SerialOp
        & ReadSysInfo_Code
        & Confirm_Code
        & SWIChangedBox
        & CRC_Code
        & ReadDynamicArea
        & SWIPrintChar
        & ChangeRedirection
        & RemoveCallBack
        & FindMemMapEntries_Code
        & SWISetColour
        & NoSuchSWI                     ; Added these to get round OS_ClaimSWI and
        & NoSuchSWI                     ; OS_ReleaseSWI (should not have been allocated here).
        & PointerSWI
        & ScreenModeSWI
        & DynamicAreaSWI
        & NoSuchSWI                     ; OS_AbortTrap
        & MemorySWI
        & ClaimProcVecSWI
        & PerformReset
        & MMUControlSWI
        & ResyncTimeSWI
        & PlatFeatSWI
        & SyncCodeAreasSWI
        & CallASWI
        & AMBControlSWI
        & CallASWIR12
; The following SWIs are not available in this kernel.
        & NoSuchSWI     ; SpecialControl
        & NoSuchSWI     ; EnterUSR32SWI
        & NoSuchSWI     ; EnterUSR26SWI
        & NoSuchSWI     ; VIDCDividerSWI
; End of unavailable SWIs.
        & NVMemorySWI
        & NoSuchSWI
        & NoSuchSWI
        & NoSuchSWI
        & HardwareSWI
        & IICOpSWI
        & SLEAVESWI
        & ReadLine32SWI
        & XOS_SubstituteArgs32_code
        & HeapSortRoutine32


 ASSERT (.-JTABLE)/4 = NCORESWIS
 ASSERT NCORESWIS < OS_ConvertStandardDateAndTime

; SWIs for time/date conversion are poked in specially

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; The fudge branch to exit a dirty SWI handler

DirtyBranch
        B       SLVK +DirtyBranch-BranchToSWIExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;SWI number passed in r10
CallASWI ROUT
        LDR     r11, [sp, #8]        ;pick-up target SWI code (r10 pushed by dispatcher)
        BIC     r11, r11, #&FF000000 ;just in case
        STR     r11, [sp, #0]        ;CallASWI now incognito as target SWI
        B       SVC_CallASWI         ;re-dispatch

;SWI number passed in r12 (better for C veneers)
CallASWIR12 ROUT
        LDR     r11, [sp, #16]       ;pick-up target SWI code (r12 pushed by dispatcher)
        BIC     r11, r11, #&FF000000 ;just in case
        STR     r11, [sp, #0]        ;CallASWIR12 now incognito as target SWI
        B       SVC_CallASWI         ;re-dispatch

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    return address, r10-r12 stacked, lr has SPSR for return

VSet_GenerateError ROUT

        Push    lr
        BIC     lr, lr, #&0F
        ORR     lr, lr, #SVC_mode
        MSR     CPSR_c, lr              ; Set caller's interrupt state and 26/32bitness
        MOV     r1, #Service_Error
        BL      Issue_Service

        MOV     r10, #ErrorV
        BL      CallVector              ; Normally gets to default handler...

        Pull    lr                      ; which raises error; otherwise just
        BIC     lr, lr, #V_bit          ; return with V clear: error claimed!

        LDR     r10, =ZeroPage          ; set up r10 and r11 as required
        MSR     CPSR_c, #I32_bit + SVC32_mode   ; IRQs off makes CallBackFlag atomic; 32bit so ready for SPSR use
        LDRB    r11, [r10, #CallBack_Flag]
        B       SWIReturnWithCallBackFlag

      [ CheckErrorBlocks
; In: r10-r12 stacked
;     r0 = error pointer
;     r10 = error number (maybe)
;     r11 = CallBack_Flag
;     r12 = SWI number
;     lr has SPSR for SWI return
BadErrPtr2
        TST     r0, #3                  ; Repeat pointer validity check; if this is OK we know we've arrived here because of a bad error number
        BNE     BadErrPtr
        ; With RISC OS 3.5+, Wimp_ReportError interprets error numbers with bits
        ; 24-29 set to 011011 as being a program error
        EOR     r10, r10, #27 :SHL: 24
        TST     r10, #&3F000000
        BEQ     BadErrPtrReturn
        ; The PRM describes FileCore as returning errors in the form &0001XXYY,
        ; where XX = filesystem number and YY = error code. However for disc
        ; errors it breaks this rule and uses error numbers of the form
        ; &ZZ01XXC7, where ZZ = disc error code and &C7 = "disc error". The
        ; obvious problem with this is that makes use of the reserved bits in
        ; the error number, so do an extra check here to detect that format of
        ; error number and allow it through.
        BIC     r10, r10, #&FF000000
        BIC     r10, r10, #&0000FF00
        EOR     r10, r10, #&00010000
        TEQ     r10, #&C7
        BEQ     BadErrPtrReturn
        ; Some types of error lookup code work by passing a bogus error number
        ; into MessageTrans_ErrorLookup and then fixing it up afterwards. To
        ; avoid breaking such code, and to maintain compatibility with
        ; "legitimate" [1] uses of this approach, we'll ignore any bad error
        ; numbers from XMessageTrans_ErrorLookup. Non-X form will still be
        ; caught, since there's no way the caller can expect to fix up the
        ; error number.
        ;
        ; [1] - The NVRAM module has a reserved bit set in its error numbers so
        ; that it knows it needs to translate them; after translation the bit is
        ; cleared. This does assume that the code in NVRAM will never see a
        ; translated error that has that reserved bit set - so is perhaps not
        ; entirely kosher (although the kernel now requires reserved bits to be
        ; clear too) - but it does avoid a redundant copy of the error token to
        ; the stack.
        LDR     r10, =XMessageTrans_ErrorLookup
        TEQ     r10, r12
        BEQ     BadErrPtrReturn
      ] ; CheckErrorBlocks
; In: r10-r12 stacked
;     r11 = CallBack_Flag
;     r12 = SWI number
;     lr has SPSR for SWI return
BadErrPtr ROUT
        Push    "r1-r4,lr"
        SUB     sp, sp, #12
        MOV     r1, sp
        MOV     r2, #12
        BIC     r0, r12, #Auto_Error_SWI_bit
        SWI     XOS_ConvertHex6         ; SWI argument is 00xxxxxx

        MOV     r4, r0                  ; now strip leading 0s
02      LDRB    r2, [r4], #1
        CMP     r2, #"0"
        BEQ     %BT02

        SUB     r4,r4,#1
        ADR     r0, ErrorBlock_BadErrPtr
        BL      TranslateError_UseR4
        ADD     sp, sp, #12
        Pull    "r1-r4,lr"
        B       BadErrPtrReturn

        MakeErrorBlock BadErrPtr

        LTORG

; ....................... default owner of ErrorV .............................
; In    r0  -> error in current error block

; Out   Exits to user's error handler routine as given by ErrHan
;       r1-r9 possibly corrupt. Indeed r10-r12 MAY be duff ... eg. REMOTE

ErrHandler ROUT

        BL      OscliTidy               ; close redirection, restore curr FS

        LDR     r10, =ZeroPage
        Push    "r0-r2"
        LDR     r1, [r10, #ErrHan]
        ; Check that the error handler points somewhere sensible
        ; Can be ROM or RAM or pretty much anywhere, but must be user-read
        ; Also require it to be word aligned, since we don't really support thumb
        MOV     r0, #24
        ADD     r2, r1, #4
        SWI     XOS_Memory
        TST     r1, #CMA_Completely_UserR
        TSTEQ   r2, #3
        BEQ     %FT05
        LDR     r1, [r10, #ErrBuf]
        MOV     r0, #24
        ADD     r2, r1, #256+4
        ; Must be SVC-writable, user+SVC readable, word aligned
        SWI     XOS_Memory
        AND     r1, r1, #CMA_Completely_UserR+CMA_Completely_PrivR+CMA_Completely_PrivW
        TEQ     r1, #CMA_Completely_UserR+CMA_Completely_PrivR+CMA_Completely_PrivW
        TSTEQ   r2, #3
        BEQ     %FT10
05
        BL      DEFHAN                  ; Restore default error (+escape) handler if the ones we've been given are obviously duff
10
        Pull    "r0-r2"
        LDR     r11, [r10, #ErrBuf]     ; Get pointer to error buffer

        LDR     sp_svc, =SVCSTK-4*4     ; Just below top of stack
        Pull    r14
        STR     r14, [r11], #4          ; Return PC for error

        LDR     r14, [r0], #4           ; Copy error number
        STR     r14, [r11], #4

        ; Copy error string - truncating at 252
        MOV     r12, #256-4

10      LDRB    r14, [r0], #1
        SUBS    r12, r12, #1
        MOVLS   r14, #0
        STRB    r14, [r11], #1
        TEQ     r14, #0
        BNE     %BT10

        LDR     r14, [r10, #ErrHan]     ; And go to error handler
        STR     r14, [r10, #Curr_Active_Object]
        LDR     r0,  [r10, #ErrHan_ws]  ; r0 is his wp

        MRS     r12, CPSR
        BIC     r12, r12, #I32_bit+F32_bit+&0F  ; USR26/32 mode, ARM, IRQs enabled

        MSR     CPSR_c, #I32_bit+SVC32_mode ; disable interrupts for SPSR use and CallBackFlag atomicity
        LDRB    r11, [r10, #CallBack_Flag]
        CMP     r11, #0
        MSREQ   SPSR_cxsf, r12

        Pull    "r10-r12", EQ
        MOVEQS  pc, r14                 ; USR mode, IRQs enabled

        Push    r14                     ; Stack return address
        MOV     r14, r12                ; Put PSR in R14
        B       Do_CallBack             ; Can't need postponement, r0,r14,stack
                                        ; such that callback code will normally
                                        ; call error handler

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; check for CallBack possible
; r0 = SWI error ptr
; r11 = CallBack_Flag
; lr = PSR

callback_checking

        TST     lr, #I32_bit+&0F        ; user 26/32 mode, ints enabled?
        MSRNE   SPSR_cxsf, lr
        LDRNE   lr, [sp], #4
        Pull    "r10-r12", NE
        MOVNES  pc, lr                  ; Skip the branch for SVC code speed

; Further checks: postpone callback if returning V set and R0->RAM

        TST     lr, #V_bit              ; if no error then do callbacks
        LDR     r10, =ZeroPage
        BEQ     Do_CallBack
        TST     r11, #CBack_Postpone
        TSTNE   r11, #CBack_OldStyle :OR: CBack_VectorReq ; can only postpone if not already or if no callbacks pending
        BNE     Do_CallBack
 [ ROMatTop
        CMP     r0, #ROM
        BHS     Do_CallBack
 |
        CMP     r0, #ROM
        RSBHIS  r12, r0, #ROMLimit
        BHI     Do_CallBack
 ]
        ORR     r11, r11, #CBack_Postpone      ; signal to IRQs
        STRB    r11, [r10, #CallBack_Flag]
back_to_user
back_to_user_irqs_already_off
        MSR     SPSR_cxsf, lr
        LDR     lr, [sp], #4
        Pull    "r10-r12"
        MOVS    pc, lr

Do_CallBack                                    ; CallBack allowed:
        ; Entered in SVC32 mode with IRQs off, r10 = ZeroPage
        TST     r11, #CBack_Postpone
        BICNE   r11, r11, #CBack_Postpone
        STRNEB  r11, [r10, #CallBack_Flag]
Do_CallBack_postpone_already_clear
        TST     r11, #CBack_VectorReq          ; now process any vector entries
        MOV     r12,lr
        BLNE    process_callback_chain
        MOV     lr,r12

        MyCLREX r11, r12                       ; CLREX required for the case where transient callbacks have been triggered on exit from IRQ handling

        LDRB    r11, [r10, #CallBack_Flag]     ; non-transient callback may have been set during transient callbacks
        TST     r11, #CBack_OldStyle
        BEQ     back_to_user
; Check that SVC_sp is empty (apart from r14,r10-r12), i.e. system truly is idle

        LDR     r12, =SVCSTK-4*4                ; What SVC_sp should be if system idle
        CMP     sp, r12                         ; Stack empty?
        BLO     back_to_user                    ; No then no call back
        BIC     r11, r11, #CBack_OldStyle
        STRB    r11, [r10, #CallBack_Flag]

        LDR     R12, [R10, #CallBf]
        STR     r14, [r12, #4*16]             ; user PSR
        Pull    r14
        STR     r14, [r12, #4*15]             ; user PC
        MOV     r14, r12
        Pull   "r10-r12"
  [ SASTMhatbroken
        STMIA   r14!,{r0-r12}
        STMIA   r14,{r13,r14}^                ; user registers
        NOP                                   ; doesn't matter that r14 is different
  |
        STMIA   r14, {r0-r14}^                ; user registers
  ]

        LDR     R12, =ZeroPage+CallAd_ws
        LDMIA   R12, {R12, PC}                ; jump to CallBackHandler


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Also called from source.pmf.key, during readc

process_callback_chain ROUT

        Push   "r0-r6, r10-r12, lr"             ; save some for the callee too.
        MRS     r0, CPSR
        Push   "r0"
        LDR     r10, =ZeroPage

        MSR     CPSR_c, #I32_bit + SVC2632      ; ints off while flag updated
        LDRB    r11, [r10, #CallBack_Flag]
        BIC     r11, r11, #CBack_VectorReq
        STRB    r11, [r10, #CallBack_Flag]

01
        MSR     CPSR_c, #I32_bit + SVC2632      ; ints off while flag updated
        LDR     r2, [r10, #CallBack_Vector]
        TEQ     r2, #0
        Pull   "r0", EQ
        MSREQ   CPSR_c, r0                      ; restore original interrupt state and 32bitness
        Pull   "r0-r6, r10-r12, PC",EQ

        LDMIA   r2, {r1, r11, r12}             ; link, addr, r12
        MOV     r0, #HeapReason_Free
        STR     r1, [r10, #CallBack_Vector] ; Keep head valid

        MSR     CPSR_c, #SVC2632                ; enable ints for long bits

  [ ChocolateSysHeap
        ASSERT  ChocolateCBBlocks = ChocolateBlockArrays + 0
        LDR     r1, [r10, #ChocolateBlockArrays]
        BL      FreeChocolateBlock
        LDRVS   r1, =SysHeapStart
        SWIVS   XOS_Heap
  |
        LDR     r1, =SysHeapStart
        SWI     XOS_Heap
  ]
      [ NoARMv5
        MOV     lr, pc
        MOV     pc, r11                         ; call im, with given r12
      |
        BLX     r11                             ; call im, with given r12
      ]

        B       %BT01                           ; loop

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_WriteC

; In    r11 = 0 (look, up there ^) !

SWIWriteC ROUT

        MSR     CPSR_c, #SVC2632        ; enable interrupts

        Push    lr

 [ ROMatTop
      [ ZeroPage <> 0
        LDR     r11, =ZeroPage
      ]
        LDR     r11, [r11, #VecPtrTab+WrchV*4] ; load top node pointer
        CMP     r11, #ROM
        BCC     WrchThruVector
        Push    pc, CS                 ; need to get to ReturnFromVectoredWrch - push PC+12 (old ARM) or PC+8 (StrongARM)
        BCS     PMFWrchDirect
        MOV     R0,R0                  ; NOP for PC+8
 |
        B       WrchThruVector
 ]
ReturnFromVectoredWrch
        Pull    lr
        B       SLVK_TestV


WrchThruVector
        MOV     r10, #WrchV
        BL      CallVector
        B       ReturnFromVectoredWrch

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SWINewLine ROUT

        MOV     r11, lr
        SWI     XOS_WriteI+10
        SWIVC   XOS_WriteI+13
        MOV     lr, r11
        B       SLVK_TestV

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_WriteI+n

SWIWriteI ROUT

        MOV     r10, r0
        AND     r0, r11, #&FF
        MOV     r11, lr                 ; NB. Order !!!
        SWI     XOS_WriteC
        MOVVC   r0, r10
        MOV     lr, r11
        B       SLVK_TestV              ; return setting V

; .............................................................................
; define module SWI node format

ModSWINode_CallAddress * 0
ModSWINode_MListNode   * 4
ModSWINode_Link        * 8
ModSWINode_Number      * 12
ModSWINode_Size        * 16     ; not a field - the node size!

        MACRO
$l      ModSWIHashvalOffset     $swino, $startreg
     [ "$startreg"=""
$l      MOV     $swino, $swino, LSR #4
     |
$l      MOV     $swino, $startreg, LSR #4
     ]
        AND     $swino, $swino, #(ModuleSHT_Entries-1)*4
        MEND

        MACRO
$l      ModSWIHashval   $swino, $startreg
$l      ModSWIHashvalOffset $swino, $startreg
        ADD     $swino, $swino, #ModuleSWI_HashTab
      [ ZeroPage <> 0
        ASSERT ZeroPage = &FFFF0000
        ADD     $swino, $swino, #&FF000000
        ADD     $swino, $swino, #&00FF0000
      ]
        MEND



NotMainMOSSwi ; Continuation of SWI despatch

        CMP     R11, #&200
        BCC     SWIWriteI

; .............................................................................
; Look round RMs to see if they want it

ExtensionSWI ROUT

        Push    "lr"

        BIC     r12, r11, #Module_SWIChunkSize-1
        ModSWIHashvalOffset r10, r12
      [ ZeroPage = 0
        LDR     r10, [r10, #ModuleSWI_HashTab]
      |
        LDR     lr, =ZeroPage+ModuleSWI_HashTab
        LDR     r10, [r10, lr]
      ]
loopoverhashchain
        CMP     r10, #0
        BEQ     VectorUserSWI
        LDR     lr, [r10, #ModSWINode_Number]
        CMP     lr, r12
        LDRNE   r10, [r10, #ModSWINode_Link]
        BNE     loopoverhashchain

        LDMIA   r10, {r10, r12}
        LDR     r12, [r12, #Module_incarnation_list]  ; preferred life
        CMP     r12, #0
        ANDNE   r11, r11, #Module_SWIChunkSize-1
        ADDNE   r12, r12, #Incarnation_Workspace
        ADRNE   lr, %FT02
        MOVNE   pc, r10


VectorUserSWI                   ; Not in a module, so call vec
        MOV     r10, #UKSWIV    ; high SWI number still in R11
        BL      CallVector


02
        Pull    "lr"
        MRS     r10, CPSR
      [ NoARMT2
        BIC     lr, lr, #&FF000000      ; Can mangle any/all of punter flags
        AND     r10, r10, #&FF000000
        ORR     lr, lr, r10
      |
        MOV     r10, r10, LSR #24
        BFI     lr, r10, #24, #8        ; Can mangle any/all of punter flags
      ]
        B       SLVK

; ....................... default owner of UKSWIV .............................
; Call UKSWI handler
; Also used to call the upcall handler

; In    r12 = HiServ_ws (or UpCallHan_ws)

CallUpcallHandler
HighSWI ROUT                          ; no one on vec wants it: give to handler

        Pull    lr                    ; the link pointing at %BT02 to pass in.
        LDMIA   r12, {r12, pc}

; ........................ default UKSWI handler ..............................

NoSuchSWI ROUT

        Push    lr
        BL      NoHighSWIHandler
        Pull    lr
        B       SLVK_SetV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; .................... default Unused SWI handler .............................

NoHighSWIHandler ROUT

        LDR     r0, =ZeroPage
        LDR     r0, [r0, #IRQsema]
        CMP     r0, #0
        ADR     r0, ErrorBlock_NoSuchSWI ; Must return static error here
        BEQ     %FT01
        SETV
        MOV     pc, lr
01

; Not in IRQ: can safely build a dynamic error
      [ International
        Push    "r1-r4, lr"
        SUB     sp, sp,#12
        MOV     r1, sp
        MOV     r2, #12
        MOV     r0, r11
        SWI     XOS_ConvertHex6         ; SWI argument is 00xxxxxx

        MOV     r4, r0                  ; now strip leading 0s
02      LDRB    r2, [r4], #1
        CMP     r2, #"0"
        BEQ     %BT02

        SUB     r4,r4,#1
        ADR     r0, ErrorBlock_NoSuchSWI1
        BL      TranslateError_UseR4
        ADD     sp,sp,#12

        Pull    "r1-r4, lr"
        SETV
        MOV     pc, lr

        MakeErrorBlock NoSuchSWI1

      |
        Push    "r1-r3, lr"
        LDR     r1, =EnvString
        LDMIA   r0!, {r2, r3}           ; number, "SWI "
        STMIA   r1!, {r2, r3}
        MOV     r2, #"&"
        STRB    r2, [r1], #1
        MOV     r3, r0
        MOV     r0, r11
        MOV     r2, #256
        SWI     XOS_ConvertHex6         ; SWI argument is 00xxxxxx

; now strip leading 0s

        MOV     r1, r0
02      LDRB    r2, [r1], #1
        CMP     r2, #"0"
        BEQ     %BT02
        CMP     r2, #0
        ADDEQ   r1, r0, #1
        BEQ     %FT03
04      STRB    r2, [r0], #1
        LDRB    r2, [r1], #1
        CMP     r2, #0
        BNE     %BT04
        MOV     r1, r0
03      MOV     r2, #" "
01      STRB    r2, [r1], #1
        CMP     r2, #0
        LDRNEB  r2, [r3], #1
        BNE     %BT01

        Pull    "r1-r3, lr"
        LDR     r0, =EnvString
        SETV
        MOV     pc, lr
       ]

        MakeErrorBlock NoSuchSWI


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Fast SWI handlers for BGet and BPut caches

BGetSWI ROUT                            ; Done separately for highest speed

        Push    lr
        MOV     r10, #BGetV             ; Cache hit failed, call victor
        BL      CallVector
        Pull    lr                      ; Punter lr has VClear
        BIC     lr, lr, #C_bit          ; Copy C,V to punter lr
        ORRCS   lr, lr, #C_bit
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BPutSWI ROUT                            ; Done separately for highest speed

        Push    "lr"
        MOV     r10, #BPutV                     ; Cache hit failed, call victor
        BL      CallVector
        Pull    "lr"                            ; Destack lr(VC)
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI handlers for all the vectored SWIs that have vecnum=swinum

; All defined to affect C & V at most

FSControlSWI ROUT

        MOV     r11, #FSCV              ; Pretend to be vecnum = swinum swi
                                        ; and just drop through to ...

VecSwiDespatch ROUT

        Push    lr                      ; this is user's link (or PSR in 32-bit case)
        MOV     r10, r11                ; SWI number from R11->R10

        MRS     r11, CPSR
      [ NoARMT2
        AND     r14, r14, #&F0000000    ; extract caller's CCs
        BIC     r11, r11, #&F0000000    ; mask out ours
        BIC     r11, r11, #I32_bit      ; enable IRQs   
        ORR     r11, r11, r14           ; add in CCs
      |
        MOV     r14, r14, LSR #28
        BIC     r11, r11, #I32_bit      ; enable IRQs   
        BFI     r11, r14, #28, #4       ; add in caller's CCs
      ]
        MSR     CPSR_cf, r11            ; and set it all up

        BL      CallVector

; So the vectored routine can update the pushed link CCodes if wanted
; No update return is therefore LDMIA stack!, {PC}^ (sort of)
; Update return pulls lr, molests it, then MOVS PC, lr
; Note either return enables IRQ, FIQ

; ???? Is the DEFAULT owner allowed to corrupt r10,r11 IFF he claims it ????

        Pull    lr                      ; Punter lr has VClear
        BICCC   lr, lr, #C_bit          ; Copy C,V to punter lr
        ORRCS   lr, lr, #C_bit
        B       SLVK_TestV


NoIrqVecSwiDespatch ROUT

        Push    lr                      ; this is user's link
        MOV     r10, r11                ; SWI number from R11->R10
        MRS     r11, CPSR
      [ NoARMT2
        AND     r14, r14, #&F0000000    ; extract caller's CCs
        BIC     r11, r11, #&F0000000    ; mask out ours
        ORR     r11, r11, #I32_bit      ; disable IRQs
        ORR     r11, r11, r14           ; add in CCs
      |
        MOV     r14, r14, LSR #28
        ORR     r11, r11, #I32_bit      ; disable IRQs
        BFI     r11, r14, #28, #4       ; add in caller's CCs
      ]
        MSR     CPSR_cf, r11            ; and set it all up
        BL      CallVector
        Pull    lr                      ; Punter lr has VClear
        BICCC   lr, lr, #C_bit          ; Copy C,V to punter lr
        ORRCS   lr, lr, #C_bit
        B       SLVK_TestV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_GetEnv

SWI_GetEnv_Code ROUT

        LDR     r0, =EnvString
        LDR     r1, =ZeroPage
        LDR     r1, [r1, #MemLimit]
        LDR     r2, =ZeroPage+EnvTime
        B       SLVK

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_Exit

SEXIT ROUT

        BL      OscliTidy               ; shut redirection, restore FS

; now see if it's an abort Exit

        LDR     r12, ABEX
        CMP     r1, r12
        TSTEQ   r0, #3
        MOVNE   r2,  #0
        LDR     r12, =ZeroPage
        STR     r2,  [r12, #ReturnCode]
        LDR     r12, [r12, #RCLimit]
        CMP     r2, r12
        SWIHI   OS_GenerateError        ; really generate an error

        ADD     sp, sp, #8              ; junk SWI no and R14 on stack
        Pull    "r10-r12"
        LDR     r0, =ZeroPage
        LDR     lr, [r0, #SExitA]
        STR     lr, [r0, #Curr_Active_Object]
        LDR     r12, [r0, #SExitA_ws]
        LDR     sp_svc, =SVCSTK
        MRS     r0, CPSR
        MSR     CPSR_c, #I32_bit+SVC2632 ; IRQs off (to protect SPSR_svc)
        BIC     r0, r0, #I32_bit+F32_bit+&0F
        MSR     SPSR_cxsf, r0            ; Get ready for USR26/32, IRQs on
        MOVS    pc, lr                  ; lr->pc, SPSR->CPSR

ABEX    =       "ABEX"                  ; Picked up as word

        LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_CallBack: Set/read callback buffer and handler

SCALLB  MOV     r10, #CallBackHandler

handlecomm
        Push    "r2, r3, lr"
        MOV     r3, r0          ; buffer
        MOV     r0, r10
        BL      CallCESWI
        MOV     r0, r3
        Pull    "r2, r3, lr"
        B       SLVK_TestV

; .............................................................................
; SWI OS_BreakSet: Set/read breakpoint buffer and handler

SBRKCT  MOV     r10, #BreakPointHandler
        B       handlecomm

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_ReadEscapeState

ReadEscapeSWI ROUT

        LDR     r10, =ZeroPage
        LDRB    r10, [r10, #ESC_Status]
        TST     r10, #1 :SHL: 6
        BICEQ   lr, lr, #C_bit
        ORRNE   lr, lr, #C_bit
        B       SLVK

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_ServiceCall

Issue_Service_SWI ROUT

        Push    lr
        BL      Issue_Service
        Pull    lr
        B       SLVK

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_PlatformFeatures
;
;     r0 = reason code:
;          0 -> read code features
;          1 -> read MMU features (ROL, unimplemented here)
;          2-31 -> reserved just in case ROL have used them
;          32 -> read processor vectors location
;          33 -> read cache information
;          34 -> read CPU features
;          35 -> read routine to clear the exclusive monitor lock

PlatFeatSWI ROUT
        Push    lr
        CMP     r0, #OSPlatformFeatures_ReadProcessorVectors ;Is it a known reason code?
        BEQ     %FT30
        CMP     r0, #OSPlatformFeatures_ReadCacheInfo
        BEQ     %FT40
        CMP     r0, #OSPlatformFeatures_ReadCPUFeatures
        BEQ     PlatFeatSWI_ReadCPUFeatures
        CMP     r0, #OSPlatformFeatures_ReadClearExclusive
        BEQ     %FT50
        CMP     r0, #OSPlatformFeatures_ReadCodeFeatures
        BNE     %FT75                   ; No, so error

        ;Ok, it's the 'code_features' reason code.
      [ ZeroPage <> 0
        LDR     r0, =ZeroPage
      ]
        LDR     r0,[r0, #ProcessorFlags]
        TST     r0, #CPUFlag_InterruptDelay
        ADRNE   r1, platfeat_irqinsert  ;Yep, so point R1 to the delay routine
        MOVEQ   r1, #0
        Pull    lr
        B       SLVK                    ;Return

platfeat_irqinsert
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
        MOV     r0, r0
        MOV     pc, lr

30
        ; Return processor vectors base + size
        LDR     r0, =ProcVecs
        MOV     r1, #256                ; Currently only 256 bytes available for FIQ handlers
        Pull    lr
        B       SLVK

40
        ; Read cache information
        ; In:  r1 = cache level (0-based)
        ; Out: r0 = Flags
        ;           bits 0-2: cache type:
        ;              000 -> none
        ;              001 -> instruction
        ;              010 -> data
        ;              011 -> split
        ;              100 -> unified
        ;              1xx -> reserved
        ;           Other bits: reserved
        ;      r1 = D line length
        ;      r2 = D size
        ;      r3 = I line length
        ;      r4 = I size
        ;      r0-r4 = zero if cache level not present
        ARMop   Cache_Examine
        Pull    lr
        B       SLVK

50
        ; Read clear the exclusive routine
        LDR     r14, =ZeroPage
        LDR     r14, [r14, #ProcessorFlags]
        TST     r14, #CPUFlag_LoadStoreEx :OR: CPUFlag_LoadStoreClearExSizes
        ADRNE   r1, platfeat_clrex      ; Can set the lock, so point R1 to the clear routine
        MOVEQ   r1, #0
        Pull    lr
        B       SLVK

platfeat_clrex
        ; => SP = a full descending stack
        ;    LR = return address
        ; <= all registers preserved, lock cleared
        Push    "r0, lr"
        MyCLREX r0, r14
        Pull    "r0, pc"

75      ; Get here if bad reason
        ADR     R0, ErrorBlock_BadPlatReas
    [ International
        BL      TranslateError
    ]
        Pull    lr
        B       SLVK_SetV

        MakeErrorBlock BadPlatReas

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI OS_GenerateError

GenErrorSWI * SLVK_SetV

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        END
