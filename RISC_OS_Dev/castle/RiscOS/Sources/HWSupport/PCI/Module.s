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
        SUBT    Module header => PCI.s.Module

        AREA    |!!!ModuleHeader|, CODE, READONLY, PIC

MySWIChunkBase * Module_SWISystemBase + PCISWI * Module_SWIChunkSize
        ASSERT  MySWIChunkBase = PCI_ReadID

Origin
        &       0
        &       InitModule - Origin
        &       KillModule - Origin
        &       0
        &       ModuleTitle - Origin
        &       HelpString - Origin
        &       CommandTable - Origin
        &       MySWIChunkBase
        &       SWIEntry - Origin
        &       SWINameTable - Origin
        &       0
 [ International_Help <> 0
        DCD     message_filename - Origin
 |
        DCD     0
 ]
        &       ModuleFlags - Origin

HelpString
        =       "PCI Manager", 9, "$Module_MajorVersion ($Module_Date)"
        [       Module_MinorVersion <> ""
        =       " $Module_MinorVersion"
        ]
        ALIGN

ModuleFlags
        &       ModuleFlag_32bit

        ^       0,      wp                              ; Store
        Word    message_file_block, 4                   ; File handle for MessageTrans
        Word    message_file_open                       ; Opened message file flag
        Word    ram_abort_handler, 11
        Word    pci_handle_table
        Word    pci_handle_table_size
        Word    pci_handles

        Word    pci_mem_to_phys_offset                  ; From HAL_PCIAddresses
        Word    pci_mem_lowest
        Word    pci_mem_highest
        Word    pci_io_to_phys_offset
        Word    pci_io_lowest
        Word    pci_io_highest
        Word    ram_to_pci_mem_offset

        Word    mempool_da_number
        Word    mempool_base_ppn                        ; this is a page block
        Word    mempool_base_log
        Word    mempool_base_phys
        Word    mempool_base_pci
        Word    mempool_free
        Byte    osheap7_supported
        Byte    pcibus_supported
        AlignSpace
        Byte    name_buffer, 128
        Byte    vendor_buffer, 128

HAL_RoutineList
        MACRO
        HALEntry $s
        ASSERT  EntryNo_$s < 255
        DCB     EntryNo_$s
        Word    $s._routine, 2
        MEND

        HALEntry HAL_PCIReadConfigByte
        HALEntry HAL_PCIReadConfigHalfword
        HALEntry HAL_PCIReadConfigWord
        HALEntry HAL_PCIWriteConfigByte
        HALEntry HAL_PCIWriteConfigHalfword
        HALEntry HAL_PCIWriteConfigWord
        DCB     255

        AlignSpace
TotalRAMRequired *      :INDEX: @

        ALIGN

        SUBT    Initialisation code
        OPT     OptPage

InitModule
        Push    "lr"

 [ standalone
        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_RegisterFiles
        BVS     %FT99                                   ; Give up and go home
 ]

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =TotalRAMRequired
        SWI     XOS_Module
        BVS     %FT99
        STR     r2, [r12]
        MOV     r12, r2

        MOV     r0, #0
10      SUBS    r3, r3, #4
        STRPL   r0, [r12, r3]
        BPL     %BT10

        ; Check if OS_Heap 7 (get area aligned) is supported
        ; We'll do a dummy call with a bad heap block and see what error we get
        ; back (Assumes bad reason codes will always be checked first!)
        MOV     r0, #HeapReason_GetAligned
        MOV     r1, r12 ; Valid address but not a heap
        SWI     XOS_Heap
        LDRVS   r0, [r0]
        TEQVS   r0, #ErrorNumber_HeapBadReason ; EQ if unsupported
        TEQVC   r1, r1 ; EQ if no error returned (definitely a bad sign)
        MOVNE   r0, #1
        STRNEB  r0, osheap7_supported

        BL      SetUpHAL
        ; If we get an error back there is no PCI. But do not give up,
        ; we can still provide memory management SWIs.
        BVC     %FT20
        CLRV
        B       %FT99
20
        MOV     r0, #1
        STRB    r0, pcibus_supported
        BL      ScanPCI
        BLVC    NoteSlots
99
        Pull    "pc"

SetUpHAL        ROUT
        Push    "r8,r9,lr"
        ADR     r2, HAL_PCIReadConfigByte_routine
        ADR     r3, HAL_RoutineList
        MOV     r8, #OSHW_LookupRoutine
        LDRB    r9, [r3], #1
20      SWI     XOS_Hardware
        BVS     %FT99
        STR     r1, [r2], #4
        STR     r0, [r2], #4
        LDRB    r9, [r3], #1
        TEQ     r9, #255
        BNE     %BT20

        ; Check with OS_ReadSysInfo to see if we have PCI
        ; hardware (since a NullEntry for HAL_PCIAddresses won't
        ; return with an error flag)
        MOV     r0, #8
        SWI     XOS_ReadSysInfo
        BVS     %FT99
        AND     r1, r1, r2
        TST     r1, #2 ; PCI?
        SETV    EQ
        BVS     %FT99

        ADR     a1, pci_mem_to_phys_offset
        MOV     a2, #7*4
        MOV     r8, #OSHW_CallHAL
        MOV     r9, #EntryNo_HAL_PCIAddresses
        SWI     XOS_Hardware
99
        Pull    "r8,r9,pc"

KillModule
        LDR     wp, [r12]
        MOV     r6, lr

        MOV     r3, #0
        LDR     r4, pci_handle_table
        LDR     r1, pci_handles
        CMP     r1, #0
        BEQ     %FT40
30      LDR     r2, [r4, r3, LSL #2]
        CMP     r2, #-1
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        ADD     r3, r3, #1
        CMP     r3, r1
        BLO     %BT30

        BL      KillDA

        MOV     r0, #ModHandReason_Free
        MOV     r2, r4
        SWI     XOS_Module
40
        BL      close_message_file

 [ standalone
        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_DeregisterFiles   ; ignore errors
 ]

        CLRV
        MOV     pc, r6

EasyLookup ROUT
        ;       In:  R1 Pointer to token
        ;       In:  R4 Single parameter to substitute
        ;       Out: R2 Pointer to looked up message in an error buffer
        ;       Out: R3 Length including terminator

        Push    "r0, r1, r3, r5, r6, r7, lr"
        BL      open_message_file
  [  DebugModule
        BVC     %71
        ADD     r14, r0, #4
        DSTRING r14, "Error from open_message_file: "
71
  ]
        ADRVC   r0, message_file_block                  ; Message file handle
        MOV     r2, #0                                  ; No buffer, expand in place
        MOV     r3, #0
        MOV     r5, #0                                  ; No %1
        MOV     r6, #0                                  ; No %2
        MOV     r7, #0                                  ; No %3
  [ DebugModule :LOR:  DebugCommands
        BVS     ExitEasyLookup
        DREG    r0, "R0 = &", cc
        Push    r14
        LDR     r14, [ r0, #0 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #4 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #8 ]
        DREG    r14, ", &", cc
        LDR     r14, [ r0, #12 ]
        DREG    r14, ", &"
        Pull    r14
        DREG    r1, "R1 = &", cc
        DSTRING r1, " token is: "
        DREG    r2, "R2 = &"
        DREG    r3, "R3 = &"
        DREG    r4, "R4 = &", cc
        DSTRING r4, " %0 is: "
        DREG    r5, "R5 = &", cc
        DSTRING r5, " %1 is: "
        DREG    r6, "R6 = &", cc
        DSTRING r6, " %2 is: "
        DREG    r7, "R7 = &", cc
        DSTRING r7, " %3 is: "
        DREG    r8, "R8 = &"
        DREG    r9, "R9 = &"
        DREG    r10, "R10 = &"
        DREG    r11, "R11 = &"
        DREG    r12, "R12 = &"
        DREG    r13, "R13 = &"
        DREG    r14, "R14 = &"
        DREG    r15, "R15 = &"
  ]
        SWIVC   XMessageTrans_Lookup
  [  DebugModule
        BVC     %76
        ADD     r14, r0, #4
        DSTRING r14, "Error from XMessageTrans_Lookup: "
76
  ]
        BVS     ExitEasyLookup
        ADD     r3, r3, #1                              ; Allow for the terminator
        STR     r3, [ sp, #8 ]                          ; Poke into the return frame
        LDR     r0, [ sp, #4 ]                          ; Get the token pointer
        DEC     r0, 4                                   ; Pretend it is an error pointer
        ADR     r1, message_file_block                  ; Message file handle
        MOV     r2, #0                                  ; No buffer, expand into a buffer
        MOV     r3, #0
  [ {FALSE} ; DebugModule
        DREG    r0, "R0 = &"
        DREG    r1, "R1 = &"
        DREG    r2, "R2 = &"
        DREG    r3, "R3 = &"
        DREG    r4, "R4 = &"
        DREG    r5, "R5 = &"
        DREG    r6, "R6 = &"
        DREG    r7, "R7 = &"
        DREG    wp, "WP = &"
        DREG    sp, "SP = &"
  ]
        SWI     XMessageTrans_ErrorLookup
  [  DebugModule
        ADD     r14, r0, #4
        DSTRING r14, "Error from XMessageTrans_ErrorLookup: "
  ]
        CLRV
        ADD     r2, r0, #4                              ; Skip over the error number
ExitEasyLookup
  [ DebugModule :LOR:  DebugCommands
        Push    "r0, r1"
        ADR     r0, message_file_block                  ; Message file handle
        DREG    r0, "R0 = &", cc
        LDR     r1, [ r0, #0 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #4 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #8 ]
        DREG    r1, ", &", cc
        LDR     r1, [ r0, #12 ]
        DREG    r1, ", &"
        Pull    "r0, r1"
  ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, r1, r3, r5, r6, r7, pc"

        ROUT

        LTORG

        [ :LNOT: ReleaseVersion
        InsertDebugRoutines
        ]

        [ standalone
resourcefsfiles
        ResourceFile    $MergedMsgs, Resources.PCI.Messages
        DCD     0
        ]

        END
