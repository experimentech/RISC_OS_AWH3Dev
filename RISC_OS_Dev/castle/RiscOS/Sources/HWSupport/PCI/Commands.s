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
 SUBT => PCI.s.Commands


CommandTable
        = "PCIDevices", 0
        ALIGN
        DCD     DoStarPCIDevices - Origin
        InfoWord 0, 0, International_Help
        DCD     SyntaxOfStarPCIDevices - Origin
        DCD     HelpForStarPCIDevices - Origin
        = "PCIInfo", 0
        ALIGN
        DCD     DoStarPCIInfo - Origin
        InfoWord 1, 1, International_Help
        DCD     SyntaxOfStarPCIInfo - Origin
        DCD     HelpForStarPCIInfo - Origin
null_string
        DCB     0
        ALIGN

Token_InfDNVe
        =       "InfDNVe", 0
Token_InfDesc
        =       "InfDesc", 0
Token_InfLoc1
        =       "InfLoc1", 0
Token_InfLoc2
        =       "InfLoc2", 0
Token_InfClas
        =       "InfClas", 0
Token_InfVend
        =       "InfVend", 0
Token_InfDevi
        =       "InfDevi", 0
Token_InfRevi
        =       "InfRevi", 0
Token_InfSubV
        =       "InfSubV", 0
Token_InfSubs
        =       "InfSubs", 0

; This is a *Command handler, so r0-r6 can be trashed. r7-r11 have to
; be preserved. Register allocation during this routine is:

; r8    Exclusive PCI number limit (ie. 9 for PCI, -N for ROMs)
; r7    PCI number progression (+1 for PCI, -1 for Extension ROMs)
; r6    Current PCI number (r3 tends to hold this for a while too)
; r5    Pointer to the generated description string
; r4    MessageTrans file token address.
; r0-r3 Much used for many things.


DoStarPCIDevices   Entry "r7-r8", 12                    ; Stack frame for text conversions etc.
        LDR     wp, [ r12 ]

; Get Messages file open up front. This way we know we will not get
; "File not found" type errors when making PCI Manager SWIs.

        BL      open_message_file
        SWIVC   XPCI_ReturnNumber                       ; out: r0 = number of PCI devices, r1 = number of extension ROMs
        EXIT    VS

        TEQ     r0, #0
        EXIT    EQ

        ADD     r8, r0, #1                              ; Number of PCI in R8 (limit)

; Set up for doing PCIdevices

        MOV     r7, #1                                  ; Current number direction
        MOV     r6, #1                                  ; Current PCI number in R6

        ADR     r0, Token_PCIDevs
        MOV     r1, #0
        BL      gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT99

next_pci_loop
        LDR     r0, =PCI_ReadInfo_DevFn+PCI_ReadInfo_Bus+PCI_ReadInfo_Description+PCI_ReadInfo_Vendor
        MOV     r1, sp
        MOV     r2, #16
        MOV     r3, r6
        SWI     XPCI_ReadInfo
        BVS     next_pci

        MOV     r0, r6
        MOV     r1, #3
        BL      PrintNumFormatted
        SWIVC   XOS_WriteI + " "
        LDRVC   r0, [sp, #4]
        BLVC    PrintNumFormatted
        SWIVC   XOS_WriteI + " "
        LDRVC   r0, [sp, #0]
        MOVVC   r0, r0, LSR #3
        BLVC    PrintNumFormatted
        SWIVC   XOS_WriteI + " "
        LDRVC   r0, [sp, #0]
        ANDVC   r0, r0, #7
        BLVC    PrintNumFormatted
        SWIVC   XOS_WriteI + " "
        SWIVC   XOS_WriteI + " "
        LDRVC   r0, [sp, #12]
        TEQ     r0, #0                                  ; see if we got a vendor string back
        BEQ     next_pci_description
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI + " "
next_pci_description
        LDRVC   r0, [sp, #8]                            ; always print the description
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        BVS     %FT99

next_pci
        ADD     r6, r6, #1                              ; Increment/decrement pci number
        TEQ     r6, r8                                  ; Limit is inclusive (ie. 4 for 1-4)
        BNE     next_pci_loop                           ; Not got to limit yet
99
        EXIT

        LTORG

Token_PCIDevs
        =       "PCIDevs", 0
        ALIGN

PrintNumFormatted
        Entry   "r0-r3", 12
        MOV     r3, r1
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertCardinal4
        BVS     %FT99
        SUB     r2, r1, r0
10      CMP     r2, r3
        ADDLT   r2, r2, #1
        SWILT   XOS_WriteI+" "
        BVS     %FT99
        BLT     %BT10
        SWI     XOS_Write0
99      STRVS   r0, [sp, #Proc_RegOffset]
        EXIT


DoStarPCIInfo ROUT
        ;       Syntax: *PCIInfo <PCI function number>
        MOV     r6, lr
        LDR     wp, [ r12 ]
        MOV     r1, r0                                  ; Command tail
        MOV     r0, #10                                 ; Base
        SWI     XOS_ReadUnsigned
        MOVVS   pc, r6
        Push    "r6"
        Push    "r11"
        SUB     sp, sp, #4*10
        MOV     r3, r2
        LDR     r0, =PCI_ReadInfo_DevFn+PCI_ReadInfo_Bus+PCI_ReadInfo_DeviceID+PCI_ReadInfo_RevisionID+PCI_ReadInfo_SubsystemID+PCI_ReadInfo_ClassCode+PCI_ReadInfo_Description+PCI_ReadInfo_IntDeviceVector+PCI_ReadInfo_Vendor
        MOV     r1, sp
        MOV     r2, #4*10
        SWI     XPCI_ReadInfo
        BVS     %FT95
        MOV     r4, r1

        BL      ValidateHandle                          ; set R11 for peeking
        BVS     %FT95

        LDR     r1, [r4, #32]
        TEQ     r1, #0
        ADREQ   r0, Token_InfDNVe                       ; No vendor name found,skip the %0
        ADRNE   r0, Token_InfDesc
        LDR     r2, [r4, #24]
        BL      gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT95

        SUB     sp, sp, #32

        LDR     r0, [r4, #4]
        MOV     r1, sp
        MOV     r2, #8
        SWI     XOS_ConvertCardinal1
        LDRVC   r5, [r4, #0]
        MOVVC   r0, r5, LSR #3
        ADDVC   r1, sp, #8
        MOVVC   r2, #8
        SWIVC   XOS_ConvertCardinal1
        ANDVC   r0, r5, #7
        ADDVC   r1, sp, #16
        MOVVC   r2, #8
        SWIVC   XOS_ConvertCardinal1
        ADRVC   r0, Token_InfLoc1
        ADDVC   r1, sp, #0
        ADDVC   r2, sp, #8
        BLVC    gs_lookup_print_string_two
        ADRVC   r0, Token_InfLoc2
        ADDVC   r1, sp, #16
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r0, [r4, #20]
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex6
        MOVVC   r1, r0
        ADRVC   r0, Token_InfClas
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r0, [r4, #8]
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex4
        MOVVC   r1, r0
        ADRVC   r0, Token_InfVend
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r0, [r4, #8]
        MOV     r0, r0, LSR #16
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex4
        MOVVC   r1, r0
        ADRVC   r0, Token_InfDevi
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r0, [r4, #12]
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex2
        MOVVC   r1, r0
        ADRVC   r0, Token_InfRevi
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #0
        BNE     PCIInfo_NoSubsystem

        LDR     r0, [r4, #16]
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex4
        MOVVC   r1, r0
        ADRVC   r0, Token_InfSubV
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r0, [r4, #16]
        MOV     r0, r0, LSR #16
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertHex4
        MOVVC   r1, r0
        ADRVC   r0, Token_InfSubs
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

PCIInfo_NoSubsystem
        MOV     r5, #0
        MOV     r6, #0

30      MOV     r0, #1:SHL:31
        MOV     r1, r6
        SWI     XPCI_HardwareAddress
        BVS     %FT40
32
        ADD     r2, r1, r2
        SUB     r2, r2, #1
        SUBS    r5, r5, #1
        ADRCC   r4, Token_InfAddr
        ADRCS   r4, Token_Inf____
        TEQ     r6, #6
        ORREQ   r0, r0, #1:SHL:8
        BL      PCIInfo_PrintRange
        BVS     %FT90

40      ADD     r6, r6, #1
        CMP     r6, #6
        BLO     %BT30
        BHI     %FT50

        MOV     r0, #1:SHL:31
        MOV     r1, #&100
        SWI     XPCI_HardwareAddress
        BVC     %BT32


50      LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #1
        BNE     PCIInfo_NoWindows
        MOV     r6, #0
        MOV     r0, #PCIConf1_IOBase
        MOV     r2, #2
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        AND     r4, r1, #&F0
        ORR     r5, r1, #&00FF          ; r5 = IO Limit
        ORR     r5, r5, #&0F00
        MOV     r4, r4, LSL #8          ; r4 = IO Base
        TST     r1, #&F                 ; 32-bit addressing
        BEQ     %FT51
        MOV     r0, #PCIConf1_IOBaseUpper
        MOV     r2, #4
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        ORR     r4, r4, r1, LSL #16     ; merge in upper 16 bits
        EOR     r1, r1, r4, LSR #16     ; of each
        ORR     r5, r5, r1
51      CMP     r4, r5
        BHS     %FT52
        MOV     r1, r4
        MOV     r2, r5
        MOV     r0, #1
        SUBS    r6, r6, #1
        ADRCC   r4, Token_InfAddW
        ADRCS   r4, Token_Inf____
        BL      PCIInfo_PrintRange
        BVS     %FT90

52      MOV     r0, #PCIConf1_MemoryBase
        MOV     r2, #4
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        MOV     r0, r1, LSL #16
        EOR     r2, r1, r0, LSR #16
        ADD     r2, r2, #&00100000
        SUB     r2, r2, #1
        MOV     r1, r0
        CMP     r1, r2
        BHS     %FT53
        MOV     r0, #0
        SUBS    r6, r6, #1
        ADRCC   r4, Token_InfAddW
        ADRCS   r4, Token_Inf____
        BL      PCIInfo_PrintRange
        BVS     %FT90

53      MOV     r0, #PCIConf1_PrefetchableBase
        MOV     r2, #4
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        MOV     r0, r1, LSL #16
        EOR     r2, r1, r0, LSR #16
        BIC     r2, r2, #&000F0000
        ADD     r2, r2, #&00100000
        SUB     r2, r2, #1
        BIC     r1, r0, #&000F0000
        CMP     r1, r2
        BHS     %FT54
        MOV     r0, #2_1000
        SUBS    r6, r6, #1
        ADRCC   r4, Token_InfAddW
        ADRCS   r4, Token_Inf____
        BL      PCIInfo_PrintRange
        BVS     %FT90
54

PCIInfo_NoWindows
        LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #0
        TEQNE   r0, #1
        BNE     PCIInfo_NoInterrupt
        MOV     r0, #PCIConf0_InterruptPin
        MOV     r2, #1
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        CMP     r1, #1
        BLO     PCIInfo_NoInterrupt
        CMP     r1, #4
        BHI     PCIInfo_NoInterrupt
        LDR     r0, =&40544E49                  ; "INT@"
        ADD     r0, r0, r1, LSL #24
        MOV     r1, #"#"
        STMIA   sp, {r0, r1}
        ADR     r0, Token_InfIntP
        MOV     r1, sp
        MOV     r2, #0
        BL      gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

        ADD     r4, sp, #32
        LDR     r0, [r4, #28]
        TEQ     r0, #255
        BEQ     PCIInfo_NoInterrupt
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertCardinal1
        MOV     r1, r0
        ADRVC   r0, Token_InfIntL
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

PCIInfo_NoInterrupt
        LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #0
        BNE     PCIInfo_NoMaxLat
        MOV     r0, #PCIConf0_Min_Gnt
        MOV     r2, #1
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        AND     r4, r1, #3
        MOVS    r0, r1, LSR #2
        BEQ     PCIInfo_NoMinGnt
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertCardinal1
        MOVVC   r1, r0
        ADRVC   r0, Token_InfMGnt
        ADRVC   r2, Frac4Table
        ADD     r2, r2, r4, LSL #2
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

PCIInfo_NoMinGnt
        MOV     r0, #PCIConf0_Max_Lat
        MOV     r2, #1
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        AND     r4, r1, #3
        MOVS    r0, r1, LSR #2
        BEQ     PCIInfo_NoMaxLat
        MOV     r1, sp
        MOV     r2, #32
        SWI     XOS_ConvertCardinal1
        MOVVC   r1, r0
        ADRVC   r0, Token_InfMLat
        ADRVC   r2, Frac4Table
        ADD     r2, r2, r4, LSL #2
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90

PCIInfo_NoMaxLat
        MOV     r0, #PCIConf_Command
        MOV     r2, #2
        SWI     XPCI_ConfigurationRead
        MOVVC   r2, #0
        ADRVC   r0, Token_InfCmdR
        BLVC    PCIInfo_PrintBits
        BVS     %FT90
        MOV     r0, #PCIConf_Status
        MOV     r2, #2
        SWI     XPCI_ConfigurationRead
        MOVVC   r4, r1
        ADRVC   r0, Token_InfStaR
        BLVC    PCIInfo_PrintStatus
        BVS     %FT90

        LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #1
        BNE     PCIInfo_NoSecondaryStatus
        MOV     r0, #PCIConf1_BridgeControl
        MOV     r2, #2
        SWI     XPCI_ConfigurationRead
        ADRVC   r0, Token_InfBrCR
        MOVVC   r2, #0
        BLVC    PCIInfo_PrintBits
        BVS     %FT90
        MOV     r0, #PCIConf1_SecondaryStatus
        MOV     r2, #2
        SWI     XPCI_ConfigurationRead
        ADRVC   r0, Token_InfSt2R
        BLVC    PCIInfo_PrintStatus
        BVS     %FT90

PCIInfo_NoSecondaryStatus
        BL      PCIInfo_PrintCapabilities

90      ADD     sp, sp, #32
95      ADD     sp, sp, #4*10
        Pull    "r11,pc"

Token_InfIntP
        =       "InfIntP", 0
Token_InfIntL
        =       "InfIntL", 0
Token_InfAddr
        =       "InfAddr", 0
Token_InfAddW
        =       "InfAddW", 0
Token_Inf____
        =       "Inf____", 0
Token_InfAMem
        =       "InfAMem", 0
Token_InfAIO
        =       "InfAIO", 0, 0
Token_InfAROM
        =       "InfAROM", 0
Token_InfAPre
        =       "InfAPre", 0
Token_InfCmdR
        =       "InfCmdR", 0
Token_InfStaR
        =       "InfStaR", 0
Token_InfSt2R
        =       "InfSt2R", 0
Token_InfSDS
        =       "InfSDS0", 0
        =       "InfSDS1", 0
        =       "InfSDS2", 0
        =       "InfSDS3", 0
Token_InfBrCR
        =       "InfBrCR", 0
Token_InfCaps
        =       "InfCaps", 0
Token_InfMLat
        =       "InfMLat", 0
Token_InfMGnt
        =       "InfMGnt", 0
Frac4Table
        =       0,0,0,0
        =       ".25",0
        =       ".5",0,0
        =       ".75",0,0

; in: R0 -> token base
;     R1 = value to print
;     R2 = 0 if first (ie print token base on line 1)
;          -1 if not (ie just indent)
PCIInfo_PrintBits ROUT
        Push    "r0-r2,r4-r6,lr"

        MOV     r4, r1
        MOV     r5, r2
        MOV     r6, #0

        LDMIA   r0, {r0, r1}
        STMFD   sp!, {r0, r1, r5}

10      MOV     lr, #1
        TST     r4, lr, LSL r6
        BEQ     %FT80

        SUBS    r5, r5, #1
        LDRCC   r0, [sp, #12]
        ADRCS   r0, Token_Inf____
        MOV     r1, #0
        MOV     r2, #0
        BL      gs_lookup_print_string_two

        MOVVC   r0, r6
        ADDVC   r1, sp, #6
        MOVVC   r2, #6
        SWIVC   XOS_ConvertCardinal1
        MOVVC   r0, sp
        ADDVC   r1, sp, #6
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT99

80      ADD     r6, r6, #1
        CMP     r6, #32
        BNE     %BT10

        ADD     sp, sp, #12
        Pull    "r0-r2,r4-r6,pc"

99      ADD     sp, sp, #16
        Pull    "r1-r2,r4-r6,pc"

; in: R0 = token for label
;     R1 = value
PCIInfo_PrintStatus
        Push    "r0,lr"
        MOV     r5, r1
        MOV     r2, #0
        BIC     r1, r5, #&FE00
        BL      PCIInfo_PrintBits
        BVS     %FT90
        MOVS    lr, r5, LSL #23
        ADRNE   r0, Token_Inf____
        LDREQ   r0, [sp]
        MOVVC   r1, #0
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        ADRVC   r0, Token_InfSDS
        MOVVC   r1, #0
        MOVVC   r2, #0
        ANDVC   lr, r5, #3:SHL:9
        ADDVC   r0, r0, lr, LSR #6
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        MOVVC   r2, #-1
        ANDVC   r1, r5, #&F800
        LDRVC   r0, [sp]
        BLVC    PCIInfo_PrintBits
90
        Pull    "r0,pc"

; in: R0 = flags    bit 0 => IO, else memory
;                   bit 3 => prefetchable memory
;                   bit 8 => ROM
;     R1 = base
;     R2 = limit
;     R4 -> label
PCIInfo_PrintRange ROUT
        Entry   "r0-r2",32
        MOV     r0, r4
        MOV     r1, #0
        MOV     r2, #0
        BL      gs_lookup_print_string_two
        BVS     %FT90
        LDR     r0, [sp, #Proc_RegOffset+4]
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_ConvertHex8
        LDRVC   r0, [sp, #Proc_RegOffset+8]
        ADDVC   r1, sp, #16
        MOVVC   r2, #16
        SWIVC   XOS_ConvertHex8
        BVS     %FT90
        LDR     r14, [sp, #Proc_RegOffset]
        MOV     r1, sp
        ADD     r2, sp, #16
        TST     r14, #1
        ADREQ   r0, Token_InfAMem
        ADRNE   r0, Token_InfAIO
        TST     r14, #1:SHL:8
        ADRNE   r0, Token_InfAROM
        BL      gs_lookup_print_string_two
        BVS     %FT90
        LDR     r0, [sp, #Proc_RegOffset]
        TST     r0, #2_1000
        ADRNE   r0, Token_InfAPre
        MOVNE   r1, #0
        MOVNE   r2, #0
        BLNE    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
90
        EXIT

; in: R4 = status register contents
;     R11 -> description block
;     R13 -> 12+ bytes of scratch space
; out: R0-r2, R5, R6
PCIInfo_PrintCapabilities
        Push    "lr"
        TST     r4, #PCISta_Capabilities
        BEQ     PCIInfo_NoCapabilities
        LDRB    r0, [r11, #PCIDesc_HeaderType]
        TEQ     r0, #0
        TEQNE   r0, #1
        BNE     PCIInfo_NoCapabilities

        ADR     r0, Token_InfCaps
        LDMIA   r0, {r1, r2}
        STMIB   sp, {r1, r2}

        MOV     r0, #PCIConf0_Capabilities

PCIInfo_CapabilitiesLoop
        MOV     r5, r0                  ; r5 -> previous capability item (or head)
        MOV     r2, #1
        SWI     XPCI_ConfigurationRead
        BVS     %FT90
        ANDS    r0, r1, #2_11111100
        BEQ     PCIInfo_NoCapabilities
        ASSERT  PCICap_ID = 0
        MOV     r6, r0                  ; r6 -> current capability item
        MOV     r2, #1
        SWI     XPCI_ConfigurationRead  ; r1 = capability number
        MOVVC   r0, r1
        ADDVC   r1, sp, #4+6
        MOVVC   r2, #4
        SWIVC   XOS_ConvertHex2
        BVS     %FT90

        TEQ     r5, #PCIConf0_Capabilities
        ADREQ   r0, Token_InfCaps
        ADRNE   r0, Token_Inf____
        MOV     r1, #0
        MOV     r2, #0
        BL      gs_lookup_print_string_two
        ADDVC   r0, sp, #4
        ADDVC   r1, sp, #4+6
        MOVVC   r2, #0
        BLVC    gs_lookup_print_string_two
        SWIVC   XOS_NewLine
        BVS     %FT90
        ADD     r0, r6, #PCICap_NextPtr
        B       PCIInfo_CapabilitiesLoop

PCIInfo_NoCapabilities
90
        Pull    "pc"

        LTORG

        END
