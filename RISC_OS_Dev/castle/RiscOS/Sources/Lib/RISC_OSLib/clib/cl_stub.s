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
; -*- Mode: Assembler -*-
;* Lastedit: 08 Mar 90 15:18:04 by Harry Meekings *
;* Shared C library: stub for clients to link with
;  2-Mar-89: IDJ: taken for RISC_OSLib purposes
;
; Copyright (C) Acorn Computers Ltd., 1988.
;

        GBLL    Brazil_Compatible
        GBLL    ModeMayBeNonUser
        GBLL    SharedLibrary

Brazil_Compatible  SETL  {FALSE}
ModeMayBeNonUser   SETL  {TRUE}
SharedLibrary      SETL  {TRUE}

        GET     h_Regs.s
        GET     h_Brazil.s
        GET     h_stubs.s
        GET     h_stack.s
        GET     h_workspc.s
        GET     clib.s.h_signal

        GET     Hdr:MsgTrans

        AREA    |Stub$$Code|, CODE, READONLY

        IMPORT  |__RelocCode|, WEAK
      [ Code_Destination <> "RAM"
        IMPORT  |_Shared_Lib_Module_SWI_Code|

        ; These in the RAM version are provided by the entry inclusions
        IMPORT  |_kernel_init|
        IMPORT  |_kernel_moduleinit|
        IMPORT  |_clib_initialise|
        IMPORT  |_kernel_entermodule|
        IMPORT  |TrapHandler|
        IMPORT  |UncaughtTrapHandler|
        IMPORT  |EventHandler|
        IMPORT  |UnhandledEventHandler|
        IMPORT  |_kernel_command_string|
        IMPORT  |_main|
      ]
      [ :DEF:AnsiLib
        IMPORT  |_kernel_moduleinit|
        IMPORT  |_clib_initialise|
        IMPORT  |_kernel_entermodule|
        IMPORT  |_AnsiLib_Module_Init_Statics|
      ]
        IMPORT  |Image$$RO$$Base|
        IMPORT  |RTSK$$Data$$Base|
        IMPORT  |RTSK$$Data$$Limit|
        IMPORT  |Image$$RW$$Base|
        IMPORT  |Image$$RW$$Limit|
        IMPORT  |Image$$ZI$$Base|
        IMPORT  |__root_stack_size|, WEAK
      [ :LNOT::DEF:AnsiLib
        IMPORT  |Stub$$Init$$Base|
      ]

        EXPORT  |_Lib$Reloc$Off|
        EXPORT  |_Mod$Reloc$Off|
        EXPORT  |_Lib$Reloc$Off$DP|

|_Lib$Reloc$Off|        *       -SL_Lib_Offset
|_Mod$Reloc$Off|        *       -SL_Client_Offset
|_Lib$Reloc$Off$DP|     *       ((-SL_Lib_Offset):SHR:2)+&F00
                                ; A version of _Lib$Reloc$Off suitable for
                                ; insertion into a DP instruction

 [ :LNOT::DEF:Module_Only :LAND: :LNOT::DEF:AnsiLib
        ENTRY

|_kernel_entrypoint|
        SWI     GetEnv
 [ APCS_Type <> "APCS-R" :LAND: Code_Destination = "RAM"
        MOV     sp, r1
        BL      EnsureCLib
;        SWIVS   GenerateError
 ]
        MOV     r2, r1
        LDR     r1, =|Image$$RW$$Limit|
        MOV     r3, #-1
        MOV     r4, #0
        MOV     r5, #-1                 ; no copying of our statics wanted

; need r1 pointer to workspace start
;      r2 pointer to workspace end
;      r3 pointer to the base of zero-init statics
;      r4 pointer to start of our statics to copy
;      r5 pointer to end of statics to copy
;      r6 = requested stack size (in K) << 16
;      r6 bit 0 indicates 32-bit mode

        LDR     r0, =|Stub$$Init$$Base|
;        ADR     r0, |_lib_init_table|
        LDR     r6, =|__root_stack_size|
        CMP     r6, #0
        MOVEQ   r6, #RootStackSize
        LDRNE   r6, [r6]
        MOV     r6, r6, ASR #10
        MOV     r6, r6, ASL #16
  [ APCS_Type <> "APCS-R"
        MOV     r14, #0
        MRS     r14, CPSR       ; will be a NOP for 26-bit only processors
        TST     r14, #&1C       ; all these bits are clear if 26-bit
        ORRNE   r6, r6, #1
  ]
  [ Code_Destination = "RAM"
     [ APCS_Type = "APCS-R"
        SWI     X:OR:Lib_Init + 1
     |
        SWI     X:OR:Lib_Init + 3
     ]
   |
        ; For ROM BL to the SWI code directly (yuck!)
     [ APCS_Type = "APCS-R"
        MOV     r11, #1         ; SWI offset 1 for APCS-R
     |
        MOV     r11, #3         ; SWI offset 3 for APCS-32
     ]
        SWI     EnterSVC
        BL      |_Shared_Lib_Module_SWI_Code|
        WritePSR USR_mode
  ]
; returns r1 stack base
;         r2 stack top (sp value)
;         r6 library version (but preserved if old library)
; other registers preserved
  [ Code_Destination = "RAM"
        BVC     NoCLibError
        LDR     r14, [r0, #0]
        LDR     r6, =Error_UnknownSWI
        TEQ     r14, r6                 ; V unaffected
        BEQ     OldSharedLibrary
  ]
        SWIVS   GenerateError

  [ Code_Destination = "RAM"
NoCLibError
        MOV     r6, r6, ASL #16
        CMP     r6, #LibraryVersionNumber :SHL: 16
        MOVGE   r4, r0
        ADRGE   r0, |_k_init_block|
        MOVGE   r3, #0
        BGE     |_kernel_init|

OldSharedLibrary
        ADR     r0, E_OldSharedLibrary
LookupError
        MOV     r3, r0
        ; Find ClibWord
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_CLibWord
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        CMP     r2, #0
        LDREQ   r2, =Legacy_CLibWord
        MOV     r0, r3
        LDR     r1, [r2]
        TEQ     r1, #0
        SWIEQ   GenerateError           ; Can we borrow CLib's message file?
        ADD     r0, r0, #4
04      LDRB    r14, [r0], #1           ; Skip over default message
        TEQ     r14, #0
        BNE     %B04
        ADD     r0, r0, #3
        BIC     r0, r0, #3
        MOV     r2, #0
        MOV     r4, #0
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     MessageTrans_ErrorLookup

        ErrorBlock SharedLibraryNeeded, "Shared C library not loaded", C62
        ErrorBlock OldSharedLibrary, "Shared C library is out of date", C63
   |
        MOV     r4, r0
        ADR     r0, |_k_init_block|
        MOV     r3, #0
        B       |_kernel_init|
  ]
 ]


 [ :LNOT::DEF:Apps_Only
  [ ModeMayBeNonUser

|_kernel_moduleentry|
        ; r0 is non-0 if the module is to be capable of multiple instantiation
        ; (statics need copying) - if so, we must allocate RMA to hold them.
        ; Note that finalise always discards the RMA (whether fatal or not)
        ; so initialise always acquires it.  Is this reasonable?
        STR     r14, [sp, #-4]!
   [ APCS_Type <> "APCS-R" :LAND: Code_Destination = "RAM" :LAND: :LNOT::DEF:AnsiLib
        BL      EnsureCLib
;        LDMVSFD sp!, {pc}
   ]
        MOV     r9, r0                  ; save 'copy statics' flag
;      [ Code_Destination = "RAM"
; Old versions of RelocCode would "return" the last field of the
; relocation table (which would be -1) in R0. Current versions
; return the address of the relocation table.
        LDR     r0, =|__RelocCode|      ; if __RelocCode is present, call it and
        TEQ     r0, #0                  ; note the address of the relocation table
        MOVEQ   r0, #-1                 ; in r8, else just set r8 to -1
        BLNE    __RelocCode             ; BL<cond> 32-bit OK
        MOV     r8, r0
;      ]
        MOV     r4, #0
        MOV     r5, #-1
        CMP     r9, #0
        MOVEQ   r3, #fixedwssize

        LDRNE   r4, =|Image$$RW$$Base|
        LDRNE   r5, =|Image$$RW$$Limit|
        SUBNE   r3, r5, r4
        ADDNE   r3, r3, #fixedwssize
        MOV     r0, #Module_Claim
        SWI     Module
        LDRVS   pc, [sp], #4
        STR     r2, [r12]               ; set private word to address our data
        STR     r3, [r2]                ; first word is size

        MOV     r9, r12
        LDR     r12, [r12]
        ADD     r1, r12, #fixedwssize   ; Pointer to low end of block
        LDR     r2, [r12, #blocksize]
        ADD     r2, r2, r12             ; Pointer to high end of block
        LDR     r3, =|Image$$ZI$$Base|
 [ :DEF:AnsiLib
        BL      _AnsiLib_Module_Init_Statics
 |
        LDR     r0, =|Stub$$Init$$Base|
;        ADR     r0, |_lib_init_table|
        LDR     r6, =|__root_stack_size|
        CMP     r6, #0
        MOVEQ   r6, #RootStackSize :SHL: 6
        LDRNE   r6, [r6]
        MOV     r6, r6, ASR #10
        MOV     r6, r6, ASL #16
  [ APCS_Type <> "APCS-R"
        MOV     r14, #0
        MRS     r14, CPSR       ; will be a NOP for 26-bit only processors
        TST     r14, #&1C       ; all these bits are clear if 26-bit
        ORRNE   r6, r6, #1
  ]
      [ Code_Destination = "RAM"
       [ APCS_Type = "APCS-R"
        STMFD   sp!, {r8}
        SWI     X:OR:Lib_Init + 2
        LDMFD   sp!, {r8}               ; KJB - why preserve here???
       |
        SWI     X:OR:Lib_Init + 4
       ]
      |
        ; For ROM BL to the SWI code directly (yuck!)
        STMFD   r13!,{r8,r11,r12}
       [ APCS_Type = "APCS-R"
        MOV     r11,#2          ; SWI offset
       |
        MOV     r11,#4          ; SWI offset
       ]
        MOV     r12,#-3         ; A number liable to address exception if used
        BL      |_Shared_Lib_Module_SWI_Code|
        LDMFD   r13!,{r8,r11,r12}
      ]
 ]
        BVS     %F99

; [ Code_Destination = "RAM"
        ; Chunk of code to relocate all the pointers in the data area
        STMFD   sp!, {r1-r5}
        LDR     r1, [r12]
        CMP     r1, #12
        BEQ     %F80
        CMP     r8, #-1
        BEQ     %F80
        LDR     r1, =|Image$$RO$$Base|  ; r1 = pointer to code
        LDR     r2, =|Image$$RW$$Base|  ; r2 = pointer to data template in module code area
        ADD     r3, r12, #fixedwssize   ; r3 = pointer to our real data area (XXXX what if r0 was 0 on entry?? XXXX)
        SUB     r3, r3, r2              ; r3 = offset from data template to real data
        ADD     r1, r1, r3              ; r1 = code + data offset (odd, but saves work below)
70      LDR     r4, [r8], #4            ; get a word from the relocation table
        MOVS    r4, r4, ASR #2
        BMI     %F80                    ; if top bit set, it's the end of the table
        BCC     %B70                    ; if bit 1 not set, it's not a data relocation
        LDR     r5, [r1, r4, LSL #2]    ; read in the word to be relocated from the data area
        ADD     r5, r5, r3              ; add the magic offset
        STR     r5, [r1, r4, LSL #2]    ; and put it back
        B       %B70
80      LDMFD   sp!, {r1-r5}

 [ Code_Destination = "RAM" :LAND: :LNOT::DEF:AnsiLib
        MOV     r6, r6, ASL #16
        CMP     r6, #LibraryVersionNumber :SHL: 16
        BLT     OldSharedLibrary
 ]

        ADD     r8, r1, #SC_SLOffset+SL_Lib_Offset
        LDMIA   r8, {r7, r8}            ; move relocation offsets
        STMIB   r12, {r7, r8}           ; to standard place in RMA
        MOV     r4, r0
        ADR     r0, |_k_init_block|
        B       |_kernel_moduleinit|    ; Can't get error
99
        MOV     r1, r0                  ; Free workspace and return
        MOV     r0, #Module_Free        ; with error.
        MOV     r2, r12
        SWI     Module
        MOV     r0, #0
        STR     r0, [r9]
        MOV     r0, r1
      [ {CONFIG}=26
        LDMIA   sp!, {lr}
        ORRS    pc, lr, #V_bit
      |
        CMP     r0, #&80000000
        CMNVC   r0, #&80000000          ; Set V bit
        LDR     pc, [sp], #4
      ]

   [ APCS_Type <> "APCS-R" :LAND: Code_Destination = "RAM" :LAND: :LNOT::DEF:AnsiLib
EnsureCLib
        STMFD   sp!, {r0,lr}
;        ADR     r0, RMEnsure1
;        SWI     CLI
        ADR     r0, RMEnsure2
        SWI     CLI
;        ADRVC   r0, RMEnsure3
;        SWIVC   CLI
        ADRVC   r0, RMEnsure4
        SWIVC   CLI
;        ADRVC   r0, RMEnsure5
;        SWIVC   CLI
        ADRVC   r0, RMEnsure6
        SWIVC   CLI
;        ADRVC   r0, RMEnsure7
;        SWIVC   CLI
        STRVS   r0, [sp]
        LDMFD   sp!, {r0,pc}

;RMEnsure1
;        = "RMEnsure UtilityModule 3.10", 0
RMEnsure2
        = "RMEnsure UtilityModule 3.70 RMEnsure CallASWI 0.02 RMLoad System:Modules.CallASWI", 0
;RMEnsure3
;        = "RMEnsure UtilityModule 3.70 RMEnsure CallASWI 0.02", 0
RMEnsure4
        = "RMEnsure FPEmulator 4.03 RMLoad System:Modules.FPEmulator", 0
;RMEnsure5
;        = "RMEnsure FPEmulator 4.03", 0
RMEnsure6
        = "RMEnsure SharedCLibrary 5.17 RMLoad System:Modules.CLib", 0
;RMEnsure7
;        = "RMEnsure SharedCLibrary 5.34", 0
        ALIGN
   ]

        EXPORT  |_clib_initialisemodule|
|_clib_initialisemodule|
        STR     r14, [sp, #-4]!
        BL      |_kernel_moduleentry|
        LDRVS   pc, [sp], #4
        STR     r9, [sp, #-4]!          ; save preserved private word ptr
        BL      |_clib_initialise|
      [ {CONFIG}=26
        LDMFD   sp!, {r0, pc}^          ; return saved private word ptr
      |
        ADDS    r0, r0, #0              ; clear V
        LDMFD   sp!, {r0, pc}           ; return saved private word ptr
      ]

        EXPORT  |_clib_entermodule|
|_clib_entermodule|
        ; User-mode entry to a module.  The module's intialisation has always
        ; been called, so stubs have been patched and relocation entries are
        ; correct.  Almost everything can be done inside the shared library.
        ADR     r0, |_k_init_block|
        MOV     r8, r12
        MOV     r12, #-1
        LDR     r6, =|__root_stack_size|
        CMP     r6, #0
        MOVEQ   r6, #RootStackSize
        LDRNE   r6, [r6]
        B       |_kernel_entermodule|

  ]
 ]

|_k_init_block|
        &       |Image$$RO$$Base|
        &       |RTSK$$Data$$Base|
        &       |RTSK$$Data$$Limit|

        LTORG

 [ :LNOT::DEF:AnsiLib

        GET clib.s.cl_init

        LTORG

        AREA    |Stub$$Init|, CODE, READONLY

|_lib_init_table|
        &       1
        &       |_k_entries_start|
        &       |_k_entries_end|
        &       |_k_data_start|
        &       |_k_data_end|

        &       2
        &       |_clib_entries_start|
        &       |_clib_entries_end|
        &       |_clib_data_start|
        &       |_clib_data_end|

 [ :DEF:RISC_OSStubs
  [ Code_Destination = "ROM"
; rlib only available to ROM
        &       3
        &       |_rlib_entries_start|
        &       |_rlib_entries_end|
        &       |_rlib_data_start|
        &       |_rlib_data_end|
  ]
 ]

        AREA    |Stub$$InitEnd|, CODE, READONLY

        &       -1

        AREA    |Stub$$Entries|, CODE, READONLY

; Don't GET the stub entries if in ROM

        GBLS    GetRoundObjAsm
|_k_entries_start|
      [ Code_Destination = "RAM"
GetRoundObjAsm SETS "        GET     kernel.s.k_entries"
      |
GetRoundObjAsm SETS ""
      ]
$GetRoundObjAsm
|_k_entries_end|
      [ Code_Destination = "RAM" :LAND: APCS_Type <> "APCS-R"
        %       |_k_entries_end| - |_k_entries_start|
      ]

|_clib_entries_start|
      [ Code_Destination = "RAM"
GetRoundObjAsm SETS "        GET     clib.s.cl_entries"
      |
GetRoundObjAsm SETS ""
      ]
$GetRoundObjAsm
|_clib_entries_end|
      [ Code_Destination = "RAM" :LAND: APCS_Type <> "APCS-R"
        %       |_clib_entries_end| - |_clib_entries_start|
      ]

|_rlib_entries_start|
 [ Code_Destination = "RAM":LAND::DEF:RISC_OSStubs
GetRoundObjAsm SETS "        GET     rlib.s.rl_entries"
 |
GetRoundObjAsm SETS ""
 ]
$GetRoundObjAsm
|_rlib_entries_end|
      [ Code_Destination = "RAM" :LAND: APCS_Type <> "APCS-R"
        %       |_rlib_entries_end| - |_rlib_entries_start|
      ]

        AREA    |Stub$$Data|, DATA, NOINIT

|_k_data_start|
        GET     kernel.s.k_data
|_k_data_end|

|_clib_data_start|
        GET     clib.s.cl_data
        GET     clib.s.clibdata
|_clib_data_end|

        GBLS    Bodge1
        GBLS    Bodge2
|_rlib_data_start|
 [ :DEF:RISC_OSStubs
Bodge1 SETS " GET     rlib.s.rl_data"
Bodge2 SETS " GET     rlib.s.rlibdata"
 |
Bodge1 SETS ""
Bodge2 SETS ""
 ]
$Bodge1
$Bodge2
|_rlib_data_end|

 ] ; :LNOT::DEF:AnsiLib

        END
