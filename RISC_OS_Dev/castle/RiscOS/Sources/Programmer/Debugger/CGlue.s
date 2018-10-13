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

; Glue code for connecting the assembler disassembler to the C one

        ; Specify where the relocation offset is relative to SL
        ; This is a negative offset!
        EXPORT  |_Mod$Reloc$Off|
|_Mod$Reloc$Off| * 0

VFP
        ; Call the C code
        BL      call_c_code
        ; Undefined VFP instructions should be treated as regular coprocessor instructions
        B       Coprocessor_NotFP

ASIMD
        ; Call the C code
        BL      call_c_code
        ; Undefined ASIMD instructions are truly undefined
        B       Undefined

call_c_code
        ; Common entry point for when we want to call the C disassembler
        ; Entry:
        ;   R0 -> StringBuffer
        ;   R4 = instruction
        ;   R9 = address
        ; Exit:
        ;   R0 -> end of StringBuffer
        ;   StringBuffer filled in
        ;   exit via InstructionEnd, or return to caller if instruction was undefined
        Entry   "r1-r12"

        ; Prepare arguments for C code
        MOV     r1, r4
        MOV     r2, r9
        ADR     r3, DisRegLabels
        MOV     r4, #?StringBuffer
        Push    "r4"
        ADD     sl, r12, #:INDEX:CRelocOffset ; Store workspace pointer/relocation offset in sl
        MOV     fp, #0
        IMPORT  arm_engine_fromasm
        BL      arm_engine_fromasm
        ADD     sp, sp, #4

        PullEnv
        TEQ     r0, #0
        BNE     InstructionEnd
        ADR     r0, StringBuffer
        MOV     pc, lr

        EXPORT  getmessage
getmessage
        ; Entry:
        ;  R0 = message number
        ; Exit:
        ;  R0 = pointer to string
        Entry   "r10"
        SUB     r12, sl, #:INDEX:CRelocOffset
        ADR     r10, messages
        ADD     r10, r10, r0, LSL #2
        BL      lookup_r10
        MOV     r0, r10
        EXIT

        EXPORT  getwarnmessage
getwarnmessage
        ; Entry:
        ;  R0 = message number
        ; Exit:
        ;  R0 = pointer to string
        Entry   "r10"
        SUB     r12, sl, #:INDEX:CRelocOffset
        ADR     r10, warnmessages
        ADD     r10, r10, r0, LSL #2
        BL      lookup_r10
        MOV     r0, r10
        EXIT

        EXPORT  getarchwarning
getarchwarning
        ; Entry:
        ;  R0 = message number
        ; Exit:
        ;  R0 = pointer to string
        Entry   "r10"
        SUB     r12, sl, #:INDEX:CRelocOffset
        ADR     r10, archwarnings
        ADD     r10, r10, r0, LSL #2
        BL      lookup_r10
        MOV     r0, r10
        EXIT

messages
        = "M00", 0 ; MSG_UNDEFINEDINSTRUCTION
        = "M65", 0 ; MSG_UNPREDICTABLEINSTRUCTION
        = "M00", 0 ; MSG_UNALLOCATEDHINT
        = "M00", 0 ; MSG_PERMAUNDEFINED
        = "M00", 0 ; MSG_UNALLOCATEDMEMHINT
        = "M00", 0 ; MSG_THUMB32 (impossible without Thumb disassembler being enabled)

warnmessages
        = "M80", 0 ; WARN_SUBS_PC_LR
        = "M58", 0 ; WARN_UNPREDICTABLE
        = "M58", 0 ; WARN_UNPREDICTABLE_LT_6
        = "M58", 0 ; WARN_UNPREDICTABLE_GE_7
        = "M81", 0 ; WARN_NONSTANDARD_PC_OFFSET
        = "M82", 0 ; WARN_BAD_DMB_DSB_ISB_OPTION
        = "M55", 0 ; WARN_UNPREDICTABLE_PC_WRITEBACK
        = "M83", 0 ; WARN_LDM_SP
        = "M84", 0 ; WARN_LDM_LR_PC
        = "M83", 0 ; WARN_STM_SP
        = "M85", 0 ; WARN_STM_PC
        = "M85", 0 ; WARN_STC_PC
        = "M64", 0 ; WARN_STM_WB
        = "M85", 0 ; WARN_STR_PC
        = "M86", 0 ; WARN_SWP_SWPB
        = "M58", 0 ; WARN_CPS_NONSTANDARD
        = "M87", 0 ; WARN_BAD_VFP_MRS_MSR
        = "M85", 0 ; WARN_PC_POSTINDEXED

archwarnings
        = "A00", 0 ; ARMv5Tstar
        = "A01", 0 ; ARMv5TEstar
        = "A02", 0 ; ARMv6star
        = "M00", 0 ; ARMv6Tstar (impossible with VFP-only build)
        = "A03", 0 ; ARMv6K
        = "A04", 0 ; ARMv6T2
        = "A05", 0 ; ARMv7
        = "A16", 0 ; ARMv7MP
        = "M00", 0 ; ARMv7VE (impossible with VFP-only build)
        = "M00", 0 ; ARMv7opt (impossible with VFP-only build)
        = "M00", 0 ; SecExt (impossible with VFP-only build)
        = "A14", 0 ; VFP_ASIMD_common
        = "A06", 0 ; VFPv2
        = "A07", 0 ; VFPv3
        = "A08", 0 ; VFPv3HP
        = "A09", 0 ; VFPv4
        = "A10", 0 ; ASIMD
        = "A11", 0 ; ASIMDHFP
        = "A12", 0 ; ASIMDFP
        = "A13", 0 ; ASIMDv2FP
        = "M00", 0 ; FPA (impossible with VFP-only build)
        = "A17", 0 ; XScaleDSP
        = "A18", 0 ; ARMv8

        END
