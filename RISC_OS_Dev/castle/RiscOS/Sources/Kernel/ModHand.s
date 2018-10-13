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
        TTL     => ModHand - the Relocatable Module Handler

ExtraRMANeeded * 24*1024 ; Amount you get extra on top of what you configured


;mjs changes for Ursula  (ChocolateOSMod) - reduce stress on SysHeap
;
                     GBLL ModHand_IntrinsicBI
ModHand_IntrinsicBI  SETL {TRUE} :LAND: ChocolateOSMod  ;base module incarnation 'node' is in module node

                        GBLL ModHand_InitDieServices
ModHand_InitDieServices SETL {TRUE} :LAND: ModHand_IntrinsicBI

; The module handler needs to know the structure of the HPD, and nodes.
; See RMTidy in particular.

;**************************************************************
;
; Module chain structure: ModuleList points at a (singly-linked) list of
; nodes with following fields:

                        ^  0
Module_chain_Link       #  4    ; the link to the next module info block
Module_code_pointer     #  4    ; pointer to the module.
Module_Hardware         #  4    ; hardware base for podules; 0 for soft loaders
Module_incarnation_list #  4    ; pointer to list of incarnation specifiers
Module_ROMModuleNode    #  4    ; pointer to ROM module node if in ROM (main, podule, extn), else zero

ModInfo                 *  @

; The incarnation list is a list of sub-nodes, one for each incarnation.

                        ^  0
Incarnation_Link        #  4   ; link to next incarnation
Incarnation_Workspace   #  4   ; 4 private bytes for this life
Incarnation_Postfix     #  0   ; postfix string starts here

; Incarnations are distinguished by their postfix, which is separated
; from the module name by a special character:

Postfix_Separator       *  "%"

;**************************************************************

; Handler initialisation.
; registers preserved

; ROM module descriptor format

                        ^       0
ROMModule_Link          #       4               ; pointer to next node
ROMModule_Name          #       4               ; pointer to module name (either directly in ROM, or in an RMA block)
ROMModule_BaseAddress   #       4               ; start of module, if directly accessible
ROMModule_Version       #       4               ; BCD version number, decimal point between bits 15,16 eg "1.23" => &00012300
ROMModule_PoduleNumber  #       4               ; podule number (0..8 = normal podule, -1 = main ROM, -2..-n = extension ROM)
ROMModule_ChunkNumber   #       4               ; chunk number if in podule or extension ROM, unused (?) if in main ROM
ROMModule_OlderVersion  #       4               ; pointer to node holding the next older version of this module, 0 if none
ROMModule_NewerVersion  #       4               ; pointer to node holding the next newer version of this module, 0 if none
ROMModule_CMOSAddrMask  #       4               ; CMOS address of frugal bit (bits 0..15) and bit mask (16..23)
                                                ; and 'initialised' flag in bit 24 (bits 25..31 = 0)
ROMModule_Initialised   *       ROMModule_CMOSAddrMask + 3
ROMModule_Size          #       4               ; size of module
ROMModule_NodeSize      #       0

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

UnplugCMOSTable                         ; in reverse order
        =       Unplug17CMOS
        =       Unplug16CMOS, Unplug15CMOS
        =       Unplug14CMOS, Unplug13CMOS
        =       Unplug12CMOS, Unplug11CMOS
        =       Unplug10CMOS, Unplug9CMOS
        =       Unplug8CMOS, Unplug7CMOS
        =       FrugalCMOS+1, FrugalCMOS+0
        =       MosROMFrugalCMOS+3, MosROMFrugalCMOS+2
        =       MosROMFrugalCMOS+1
UnplugCMOSTableEnd                      ; used for backwards indexing
        =       MosROMFrugalCMOS+0
        =       0
        ALIGN

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ModuleInitForKbdScan - Start subset of ROM modules for keyboard scan
;
; in:   r0 -> comma seperated list of ROM module names
;
; out:  All registers preserved
;

ModuleInitForKbdScan Entry "r0-r12"

        MOV     r0, #HeapReason_Init                    ; first initialise the heap
        MOV     r1, #RMAAddress
        LDR     r3, [r1, #:INDEX: hpdend]               ; saved for us during init.
        SWI     XOS_Heap

        ASSERT  ROMModule_Link = 0

        ADRL    r6, SysModules_Info+4

        LDR     r9, =ZeroPage+ROMModuleChain            ; pointer to 'previous' node
        MOV     r8, #0                                  ; initial head ptr is zero
        STR     r8, [r9]                                ; set up null list

        LDR     r0, [sp, #0*4]
        CMP     r0, #-1                                 ; no list?
        BNE     %FT10

; just init the podule manager - this must be the second module (ie the 1st after UtilityModule)

        LDR     r1, [r6, #-4]
        ADD     r1, r6, r1
        LDR     r14, [r1, #-4]
        TEQ     r14, #0
        MOVNE   r0, #ModHandReason_AddArea
        SWINE   XOS_Module
        EXIT

; now for each module in the main ROM needed for KbdScan, create a node for it
10
        MOV     r3, #-1                                 ; podule -1 is main ROM
        MOV     r10, #0                                 ; chunk number 0 to start
20
        LDR     r7, [r6, #-4]                           ; get size of this module
        TEQ     r7, #0                                  ; if zero
        BEQ     %FT50                                   ; then no more main rom modules

        LDR     r4, [r6, #Module_TitleStr]              ; r4 = offset to module name
        ADD     r4, r6, r4                              ; r4 -> module name
        LDR     r5, [r6, #Module_HelpStr]               ; r5 = help offset
        TEQ     r5, #0                                  ; if no help string
        ADDEQ   r5, r6, #Module_HelpStr                 ; then use help offset as string (null string)
        ADDNE   r5, r6, r5                              ; otherwise point to help string

        CMP     r10, #FirstUnpluggableModule            
        BCC     %FT30                                   ; unconditional since not unpluggable anyway

        LDR     r11, [sp, #0*4]
        BL      CompareTitleWithCSV
        BNE     %FT40                                   ; if your name's not on the list you can't come in
30
        ADR     r11, UnplugCMOSTable
        SUBS    r14, r10, #FirstUnpluggableModule       ; subtract number of first module that has an unplug bit
        MOVCS   r1, r14, LSR #3                         ; get byte number
        ANDCS   r14, r14, #7                            ; get bit number
        ADDCS   r14, r14, #16                           ; bit mask stored in bits 16 onwards
        RSBCSS  r1, r1, #(UnplugCMOSTableEnd-UnplugCMOSTable) ; invert table offset, and check in range
        LDRCSB  r11, [r11, r1]                          ; load table value if in range
        MOVCS   r12, #1
        ORRCS   r11, r11, r12, LSL r14                  ; merge with bit mask
        MOVCC   r11, #0                                 ; otherwise zero

        BL      AddROMModuleNode
        BVS     %FT50                                   ; if failed then can't add any more ROMs!
40
        MOV     r9, r2                                  ; this node is now previous one
        ADD     r6, r6, r7                              ; go on to next module
        ADD     r10, r10, #1                            ; chunk number +=1
        B       %BT20

; now start them
50
        LDR     r12, =ZeroPage+ROMModuleChain
        LDR     r12, [r12]
60
        TEQ     r12, #0                                 ; if no more modules
        BEQ     %FT90                                   ; then skip

        MOV     r11, r12                                ; start with current one
        BL      InitialiseROMModuleAtInit

        LDR     r12, [r12, #ROMModule_Link]
        B       %BT60
90
      [ DebugROMInit
        SWI     XOS_WriteS
        =       "mod init (kbdscan) done",0
        SWI     XOS_NewLine
      ]
        MOV     r1, #RMASizeCMOS
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        LDR     r0, =ZeroPage
        LDR     r0, [r0, #Page_Size]
        MUL     r3, r0, r2
        ADD     r3, r3, #ExtraRMANeeded
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        EXIT

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       ModuleInit - Start the remaining ROM modules, checking podules and extension ROMs
;
; out:  All registers preserved
;

ModuleInit   Entry "r0-r12"

; now for each module in the main ROM, create a node for it

        ASSERT  ROMModule_Link = 0

        ADRL    r6, SysModules_Info+4

        LDR     r9, =ZeroPage+ROMModuleChain            ; pointer to 'previous' node
        LDR     r12, [r9]
        Push    "r12"                                   ; keep keyboard scan chain anchor
        MOV     r8, #0                                  ; initial head ptr is zero
        STR     r8, [r9]                                ; set up null list

        MOV     r3, #-1                                 ; podule -1 is main ROM
        MOV     r10, #0                                 ; chunk number 0 to start
10
        LDR     r7, [r6, #-4]                           ; get size of this module
        TEQ     r7, #0                                  ; if zero
        BEQ     %FT20                                   ; then no more main rom modules

        LDR     r4, [r6, #Module_TitleStr]              ; r4 = offset to module name
        ADD     r4, r6, r4                              ; r4 -> module name
        LDR     r5, [r6, #Module_HelpStr]               ; r5 = help offset
        TEQ     r5, #0                                  ; if no help string
        ADDEQ   r5, r6, #Module_HelpStr                 ; then use help offset as string (null string)
        ADDNE   r5, r6, r5                              ; otherwise point to help string

        ADR     r11, UnplugCMOSTable
        SUBS    r14, r10, #FirstUnpluggableModule       ; subtract number of first module that has an unplug bit
        MOVCS   r1, r14, LSR #3                         ; get byte number
        ANDCS   r14, r14, #7                            ; get bit number
        ADDCS   r14, r14, #16                           ; bit mask stored in bits 16 onwards
        RSBCSS  r1, r1, #(UnplugCMOSTableEnd-UnplugCMOSTable) ; invert table offset, and check in range
        LDRCSB  r11, [r11, r1]                          ; load table value if in range
        MOVCS   r12, #1
        ORRCS   r11, r11, r12, LSL r14                  ; merge with bit mask
        MOVCC   r11, #0                                 ; otherwise zero

        BL      AddROMModuleNode
        BVS     %FT50                                   ; if failed then can't add any more ROMs!

        LDR     r12, [sp, #0*4]                         ; keyboard scan chain may have seen this module
12
        TEQ     r12, #0
        BEQ     %FT18

        LDR     r5, [r12, #ROMModule_BaseAddress]
        LDR     r14, [r2, #ROMModule_BaseAddress]
        TEQ     r5, r14                                 ; for main ROM an address compare is sufficient
        BNE     %FT16

        MOV     r14, #1
        STRB    r14, [r2, #ROMModule_Initialised]       ; remember it's already done
        LDR     r11, =ZeroPage+Module_List
14
        LDR     r11, [r11, #Module_chain_Link]
        TEQ     r11, #0
        BEQ     %FT16

        LDR     r14, [r11, #Module_ROMModuleNode]
        TEQ     r12, r14
        STREQ   r2, [r11, #Module_ROMModuleNode]        ; point at newly created node
        BNE     %BT14
16
        LDR     r12, [r12, #ROMModule_Link]
        B       %BT12
18
        MOV     r9, r2                                  ; this node is now previous one
        ADD     r6, r6, r7                              ; go on to next module
        ADD     r10, r10, #1                            ; chunk number +=1
        B       %BT10

; now do podule ROMs

20
        MOV     r3, #0                                  ; start at podule 0
21
        MOV     r10, #0                                 ; for each podule start at chunk 0
        CMP     r3, #-1
        MOVGT   r12, #0                                 ; if real podule then start at CMOS bit number 0 for this podule
                                                        ; else carry on from where we're at
22
        MOV     r0, r10
        SWI     XPodule_EnumerateChunksWithInfo
        BVS     %FT40                                   ; bad podule or some such
        CMP     r0, #0                                  ; no more chunks?
        BEQ     %FT45                                   ; then step to next podule
        CMP     r2, #OSType_Module
        MOVNE   r10, r0
        BNE     %BT22

; now claim a block to copy module title into

        MOV     r7, r1                                  ; pass size in r7
        Push    "r0, r3, r4"
        MOV     r3, #0
23
        LDRB    r14, [r4, r3]                           ; find length of title string
        ADD     r3, r3, #1                              ; increment length (include zero at end)
        TEQ     r14, #0
        BNE     %BT23

        BL      ClaimSysHeapNode
        Pull    "r0, r3, r14"                           ; restore chunk no., podule no., old ptr to title
        BVS     %FT50                                   ; if error then no more ROMs (doesn't matter that error ptr is naff)

        MOV     r4, r2                                  ; save pointer to block
24
        LDRB    r1, [r14], #1                           ; now copy string into block
        STRB    r1, [r2], #1
        TEQ     r1, #0
        BNE     %BT24
        MOV     r14, #(1 :SHL: 16)                      ; bit mask ready to shift
        CMP     r3, #-1
        BLT     %FT30

; doing podule ROM

        ASSERT  ?PoduleFrugalCMOS = 8                   ; ensure we're using the correct Hdr:CMOS
        CMP     r12, #7                                 ; if bit number <= 7
        CMPLS   r3, #8                                  ; then if podule number <= 8
        ADDCC   r11, r3, #PoduleFrugalCMOS              ;      then use one of the 8 PoduleFrugalCMOS bytes
        MOVEQ   r11, #NetworkFrugalCMOS                 ;      elif podule number = 8 then use network card CMOS
        MOVHI   r11, #0                                 ; otherwise no CMOS
        ORRLS   r11, r11, r14, LSL r12                  ; OR in bit mask
        B       %FT36

; doing extension ROM
30
        CMP     r12, #16                                ; 2 bytes of CMOS for extension ROMs
        MOVCC   r1, #ExtnUnplug1CMOS                    ; form CMOS address in r1
        ADDCC   r1, r1, r12, LSR #3
        ANDCC   r11, r12, #7                            ; get bit mask
        ORRCC   r11, r1, r14, LSL r11                   ; and OR in
35
        MOVCS   r11, #0                                 ; if out of range then no CMOS
36
        ADD     r12, r12, #1                            ; increment bit
        BL      AddROMModuleNode
        BVS     %FT50

        MOV     r10, r0                                 ; go onto next chunk
        MOV     r9, r2                                  ; this node is now previous one
        B       %BT22

40
        CMP     r3, #0                                  ; are we doing extension ROMs
        BMI     %FT50                                   ; if so, then stop if we get an error
45
        TEQ     r3, #0                                  ; if doing extension ROMs
        SUBMI   r3, r3, #1                              ; then go backwards
        BMI     %BT21
        ADD     r3, r3, #1                              ; go onto next podule
        CMP     r3, #16                                 ; more podules than you could ever fit
        MOVEQ   r3, #-2                                 ; if got to end, try extension ROMs
        MOVEQ   r12, #0                                 ; start by using bit 0 of CMOS
        B       %BT21

50

; free the keyboard scan chain as it's redundant now

        Pull    "r9"                                    ; recover keyboard scan chain anchor
51
        TEQ     r9, #0
        BEQ     %FT58

        MOV     r2, r9
        LDR     r9, [r9, #ROMModule_Link]
  [ ChocolateSysHeap
        ASSERT  ChocolateMRBlocks = ChocolateBlockArrays + 12
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#12]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]
        B       %BT51
58

; now go down ROM module chain, initialising things

60
        LDR     r12, =ZeroPage+ROMModuleChain
        LDR     r12, [r12]
62
        TEQ     r12, #0                                 ; if no more modules
        BEQ     %FT90                                   ; then skip

        LDR     r3, [r12, #ROMModule_CMOSAddrMask]      ; get CMOS for LOCATION version
        ANDS    r2, r3, #&FF
        MOVNE   r1, r2
        MOVNE   r0, #ReadCMOS                           ; if there is a CMOS address
        SWINE   XOS_Byte                                ; then read it
        TST     r2, r3, LSR #16                         ; test bit
        BNE     %FT80                                   ; [LOCATION unplugged, so don't initialise here]

        MOV     r11, r12                                ; start with current one

; now find the newest version that isn't unplugged

; first find the newest version

63
        LDR     r14, [r11, #ROMModule_NewerVersion]
        TEQ     r14, #0                                 ; if there is a newer version
        MOVNE   r11, r14                                ; then link to it
        BNE     %BT63                                   ; and loop

; now work backwards until we find a version that isn't unplugged - there must be one, since LOCATION version is not unplugged

65
        TEQ     r11, r12                                ; back to LOCATION version?
        BEQ     %FT67                                   ; [yes, so use that version]
        LDR     r3, [r11, #ROMModule_CMOSAddrMask]      ; get CMOS for CODE version
        ANDS    r2, r3, #&FF
        MOVNE   r1, r2
        MOVNE   r0, #ReadCMOS                           ; if there is a CMOS address
        SWINE   XOS_Byte                                ; then read it
        TST     r2, r3, LSR #16                         ; test bit
        LDRNE   r11, [r11, #ROMModule_OlderVersion]     ; CODE is unplugged, so try next older version
        BNE     %BT65

67
        LDR     r7, [r12, #ROMModule_PoduleNumber]      ; get podule number (for LOCATION version)
        CMP     r7, #-1                                 ; is it the main ROM
        BNE     %FT69

        LDRB    r10, [r12, #ROMModule_Initialised]      ; already initialised?
        TEQ     r10, #0
        BNE     %FT80
69
        CMP     r7, #-1                                 ; is it an extension ROM
        BGE     %FT70                                   ; if not then initialise newer one

; it's an extension ROM, so only initialise if it's the newest, and hasn't yet been initialised

        TEQ     r11, r12
        LDREQB  r10, [r11, #ROMModule_Initialised]      ; only initialise if this is zero and r11=r12
        TEQEQ   r10, #0
        BNE     %FT80                                   ; don't initialise

; not an extension ROM, so initialise the newest version (r11) of this module

70
        BL      InitialiseROMModuleAtInit
80
        LDR     r12, [r12, #ROMModule_Link]
        B       %BT62

90
      [ DebugROMInit
        SWI     XOS_WriteS
        =       "mod init done",0
        SWI     XOS_NewLine
      ]
        EXIT

;******************************************************************************************************
;
;       InitialiseROMModule - Initialise a ROM module
;
; in:   r11 -> ROM module node for CODE version
;       r12 -> ROM module node for LOCATION version
;
; out:  All registers preserved
;

InitialiseROMModule Entry "r0-r12"
        MOV     r14, #1
        STRB    r14, [r11, #ROMModule_Initialised]      ; indicate it's been initialised
        LDR     r2, [r11, #ROMModule_ChunkNumber]
        LDR     r3, [r11, #ROMModule_PoduleNumber]
        LDR     r4, [r11, #ROMModule_Name]
        LDR     r6, [r11, #ROMModule_BaseAddress]
        LDR     r7, [r12, #ROMModule_PoduleNumber]
        ADRL    r1, crstring
        ADR     lr, %FT20
10
        Push    "r0-r7,r9,lr"
        LDR     r1, [r11, #ROMModule_Size]
        MOV     r5, r11                                 ; r5 -> ROM module node
        B       APMInitEntry
20
        STRVS   r0, [sp]                                ; if error, preserve r0
        EXIT

InitialiseROMModuleAtInit Entry "r0-r1"
      [ DebugROMInit                                    ; print names in ROM module init for debugging
        SWI     XOS_WriteS
        =       "init mod ",0
        ALIGN
        LDR     r0, [r11, #ROMModule_Name]
        SWI     XOS_Write0
      ]
        BL      InitialiseROMModule
      [ DebugROMInit
        BVC     %FT10
        SWI     XOS_WriteS
        =       " => error: ",0
        ALIGN
        ADDVC   r0, r0, #4
        SWIVC   XOS_Write0
10
        WritePSRc SVC_mode+I_bit,r14                    ; this bit of gymnastics ensures that requested
        LDR     r0, =ZeroPage                           ; callbacks don't fire when doing the page scroll check
        LDRB    r1, [r0, #CallBack_Flag]                ; in the VDU driver because of the new line. Otherwise,
        BIC     r14, r1, #CBack_VectorReq               ; callbacks scheduled during ROM init are ordered
        STRB    r14, [r0, #CallBack_Flag]               ; differently for DebugROMInit {TRUE} than {FALSE}

        SWI     XOS_NewLine                             ; enables interrupts itself

        WritePSRc SVC_mode+I_bit,r14
        TST     r1, #CBack_VectorReq
        LDRNEB  r1, [r0, #CallBack_Flag]
        ORRNE   r1, r1, #CBack_VectorReq                ; re-insert that request
        STRNEB  r1, [r0, #CallBack_Flag]
        WritePSRc SVC_mode,r14
      ]
        EXIT

;******************************************************************************************************
;
;       AddROMModuleNode - Create a ROM module node and link it with the chain
;
; in:   R3 = podule number
;       R4 -> module name
;       R5 -> module help string
;       R6 -> module base if directly executable, otherwise zero
;       R7 = module size
;       R8 = 0
;       R9 -> previous node
;       R10 = chunk number
;       R11 = CMOS address (in bits 0..15) and bit mask (in bits 16..23) for unplugging (0 if none)
;
; out:  R2 -> node created
;       All other registers preserved, except if error (when R0 -> error)
;

AddROMModuleNode Entry "r0,r1,r3-r12"
  [ ChocolateSysHeap
        ASSERT  ChocolateMRBlocks = ChocolateBlockArrays + 12
        LDR     r3,=ZeroPage+ChocolateBlockArrays
        LDR     r3,[r3,#12]
        BL      ClaimChocolateBlock
        MOVVS   r3, #ROMModule_NodeSize
        BLVS    ClaimSysHeapNode
  |
        MOV     r3, #ROMModule_NodeSize                 ; claim a rom module node
        BL      ClaimSysHeapNode                        ; r0,r1 corrupted, r2 -> block
  ]
        STRVS   r0, [stack]
        EXIT    VS

        STR     r8, [r2, #ROMModule_Link]               ; set link for this node to 0
        STR     r7, [r2, #ROMModule_Size]               ; store size in node
        STR     r4, [r2, #ROMModule_Name]               ; store pointer to title string
        STR     r6, [r2, #ROMModule_BaseAddress]        ; store base address
        MOV     r0, r5
        BL      GetVerNoFromHelpString                  ; read version number in BCD into r1
        STR     r1, [r2, #ROMModule_Version]            ; store version number
        LDR     r3, [stack, #2*4]                       ; reload podule number
        STR     r3, [r2, #ROMModule_PoduleNumber]       ; store podule number
        STR     r10, [r2, #ROMModule_ChunkNumber]       ; store chunk number
        STR     r11, [r2, #ROMModule_CMOSAddrMask]      ; store CMOS address and mask

; now check if module is a copy of one already on the list

        MOV     r10, #0                                 ; next oldest node
        MOV     r11, #0                                 ; next newest node
        CMP     r3, #-1                                 ; if in main ROM, no need to look for duplicates
        BEQ     %FT40

        MOV     r1, r4                                  ; make r1 -> additional module's name
        MOV     r4, #0                                  ; zero terminator for Module_StrCmp
        MOV     r12, #0                                 ; search from start of chain
        BL      FindROMModule
        TEQ     r12, #0                                 ; did we find it?
        BEQ     %FT40                                   ; no, then module is unique

        TEQ     r6, #0                                  ; set r6 to 1 if extra is directly executable, otherwise 0
        MOVNE   r6, #1
        CMP     r3, #-1                                 ; set r3 to 1 if extra is an extension ROM, otherwise 0
        MOVGE   r3, #0
        MOVLT   r3, #1
        LDR     r1, [r2, #ROMModule_Version]            ; reload version number of extra node
        BL      CompareVersions                         ; compare r2 version with r12 version
        BCC     %FT30                                   ; extra one is older than this one, so search down older chain

; extra one is newer than this one, so search down newer chain

20
        MOV     r10, r12                                ; old = this
        LDR     r12, [r12, #ROMModule_NewerVersion]     ; this = newer(this)
        MOVS    r11, r12                                ; new = this
        BEQ     %FT40                                   ; if no newer then that's it!
        BL      CompareVersions
        BCS     %BT20

; extra one is older than this one, so search down older chain

30
        MOV     r11, r12                                ; new = this
        LDR     r12, [r12, #ROMModule_OlderVersion]     ; this = older(this)
        MOVS    r10, r12                                ; old = this
        BEQ     %FT40
        BL      CompareVersions
        BCC     %BT30

40
        STR     r10, [r2, #ROMModule_OlderVersion]      ; older(extra)=old
        STR     r11, [r2, #ROMModule_NewerVersion]      ; newer(extra)=new
        TEQ     r10, #0                                 ; if old <> 0
        STRNE   r2, [r10, #ROMModule_NewerVersion]      ; then newer(old)=extra
        TEQ     r11, #0                                 ; if new <> 0
        STRNE   r2, [r11, #ROMModule_OlderVersion]      ; then older(new)=extra

        STR     r2, [r9]                                ; point previous node at this one
        CLRV
        EXIT

;******************************************************************************************************
;
;       CompareVersions - Test two for newness against another (existing) node
;
; in:   R1 = version as BCD
;       R3 = base address
;       R6 = podule number
;       R12 -> node
;
; out:  CC of compare
;       All other registers preserved
;

CompareVersions Entry
        LDR     r14, [r12, #ROMModule_Version]          ; r14 = version(this)
        CMP     r1, r14
        EXIT    NE                                      ; exit with this condition codes, unless equal
        LDR     r14, [r12, #ROMModule_BaseAddress]
        TEQ     r14, #0                                 ; set r14 to 1 if this one is directly executable, otherwise 0
        MOVNE   r14, #1
        CMP     r6, r14
        EXIT    NE                                      ; directly executables are "newer"
        LDR     r14, [r12, #ROMModule_PoduleNumber]
        CMP     r14, #-1                                ; set r14 to 1 if ext. ROM, otherwise 0
        MOVGE   r14, #0
        MOVLT   r14, #1
        CMP     r3, r14                                 ; extension ROMs are "newer" than anything else
        EXIT                                            ; if equal in all other respects, the later one is "newer"

;******************************************************************************************************
;
;       CompareTitleWithCSV - Test two for newness against another (existing) node
;
; in:   R11 = comma separated string of titles
;       R4 -> title string of a module
;
; out:  EQ if title is in the list
;       All other registers preserved
;

CompareTitleWithCSV Entry "r0, r6, r11"
10
        MOV     r6, r4                                  ; char in title string
20
        LDRB    r0, [r11], #1
        LDRB    r14, [r6], #1
        TEQ     r0, #0                                  ; (terminator OR
        TEQNE   r0, #","                                ;                separator)
        TEQEQ   r14, #0                                 ;                           AND terminator
        EXIT    EQ

        TEQ     r0, r14
        BEQ     %BT20
30
        TEQ     r0, #0
        BNE     %FT40                                   ; no more values

        MOVS    r0, #1
        EXIT    NE
40
        TEQ     r0, #","                                
        BEQ     %BT10                                   ; try next value

        LDRB    r0, [r11], #1
        B       %BT30

;******************************************************************************************************
;
;       FindROMModule - Find a named module in the ROM module list
;
; in:   R1 -> name to match
;       R4 = potential additional termintor for R1 string
;       R12 -> node before 1st node to be checked (0 => search from start)
;
; out:  R12 -> found node, or 0 if no match
;       If match, then R1 -> terminator of R1 string, otherwise preserved
;       All other registers preserved
;

FindROMModule Entry
        TEQ     r12, #0                                 ; if zero passed in on entry
        LDREQ   r12, =ZeroPage+ROMModuleChain           ; then search from start of chain
10
        LDR     r12, [r12, #ROMModule_Link]             ; go to next module
        TEQ     r12, #0                                 ; any more modules?
        EXIT    EQ                                      ; no, then exit
        Push    "r1, r3"
        LDR     r3, [r12, #ROMModule_Name]              ; point to name of module on chain
        BL      Module_StrCmp                           ; compare names
        STREQ   r1, [sp]                                ; if match, then patch stacked r1
        Pull    "r1, r3"
        BNE     %BT10                                   ; if different then try next one
        EXIT

; start of module handler SWI

     GBLA  mhrc
mhrc SETA 0

     MACRO
$l   ModuleDispatchEntry $entry
$l   B      Module_$entry
     ASSERT ModHandReason_$entry = mhrc
mhrc SETA   mhrc + 1
     MEND

ModuleHandler ROUT

     CMP      r0, #(NaffSWI - (.+12))/4     ; Range check
     ADDLO    pc, pc, r0, LSL #2            ; dispatch
     B        NaffSWI

     ModuleDispatchEntry Run
     ModuleDispatchEntry Load
     ModuleDispatchEntry Enter
     ModuleDispatchEntry ReInit
     ModuleDispatchEntry Delete
     ModuleDispatchEntry RMADesc
     ModuleDispatchEntry Claim
     ModuleDispatchEntry Free
     ModuleDispatchEntry Tidy
     ModuleDispatchEntry Clear
     ModuleDispatchEntry AddArea
     ModuleDispatchEntry CopyArea
     ModuleDispatchEntry GetNames
     ModuleDispatchEntry ExtendBlock
     ModuleDispatchEntry NewIncarnation
     ModuleDispatchEntry RenameIncarnation
     ModuleDispatchEntry MakePreferred
     ModuleDispatchEntry AddPoduleModule
     ModuleDispatchEntry LookupName
     ModuleDispatchEntry EnumerateROM_Modules
     ModuleDispatchEntry EnumerateROM_ModulesWithInfo
     ModuleDispatchEntry FindEndOfROM_ModuleChain

NaffSWI                                     ; Set V and return
        ADR     R0, ErrorBlock_BadModuleReason
      [ International
BumDealInModule_Translate
        Push    "lr"
        BL      TranslateError
        Pull    "lr"
      ]
BumDealInModule
        B       SLVK_SetV

     MakeErrorBlock BadModuleReason

;*************************************************************

Module_Run      ROUT
       WritePSRc SVC_mode, R12              ; interrupts on
       Push    "R9, lr"
       BL       Load_Module
       BVS      LoadFailed
  ;     BL       EnvStringSkipName - done in load
EnterIt
 ; R9 now ptr to node, R10 ptr to command string to set up.
 ; Enters preferred incarnation.

       LDR      R12, [R9, #Module_incarnation_list]
       ADD      R12, R12, #Incarnation_Workspace

       LDR      R9, [R9, #Module_code_pointer]
       LDR      R11, [R9, #Module_Start]
       TEQ      R11, #0
       Pull    "R9, lr", EQ
       ExitSWIHandler EQ

       Push    "R1-R3"
       MOV      R1, R10
       MOV      R0, #FSControl_StartApplication
       MOV      R2, R9
       LDR      R3, [R9, #Module_TitleStr]  ; prefix with module title
       ADD      R3, R3, R9

       SWI      XOS_FSControl
       BVS      CantGoIntoModule

       LDR      stack, =SVCSTK
       MOV      R0, R10
       WritePSRc 0, R14
       MOV      r0, r0                      ; NOP because we've changed mode

       TST      R11, #ARM_CC_Mask           ; check for B startit, etc.
       MOVNE    R11, #0
       ADD      PC, R9, R11

CantGoIntoModule
       Pull    "R1-R3"
LoadFailed
       Pull    "R9, lr"
       B        BumDealInModule

;*************************************************************

Module_Load     ROUT
        WritePSRc SVC_mode, R12             ; interrupts on
        Push    "R9, lr"
        BL      Load_Module
        Pull    "R9, lr"
        B       SLVK_TestV

;*************************************************************

Module_Enter    ROUT
       Push    "R9, lr"                     ; ready for EnterIt
       Push    "R0-R4"
       BL       lookup_commoned

       STRVS    R0, [stack]
       Pull    "R0-R4, R9, lr", VS
       BVS      BumDealInModule

       BLNE     PreferIncarnation
       Pull    "R0-R4"
       MOV      R10, R2                     ; envstring pointer
       B        EnterIt

;*************************************************************

Module_ReInit   ROUT
       Push    "R0-R4, R9, lr"

       BL       lookup_commoned
       BVS      %FT01

       ADDEQ    R3, R9, #Module_incarnation_list
       LDREQ    R12, [R9, #Module_incarnation_list]

 ;    R12 -> incarnation node, R3  -> previous incarnation

       MOV      R10, #1                     ; fatal die
       BL       CallDie
       BVS      %FT03
     [ ModHand_InitDieServices
       BL       IssueServicePostFinal
     ]

       SUB      R10, R1, #1
       BL       EnvStringSkipName

       BL       CallInit
       BLVS     LoseModuleSpace_if_its_the_only_incarnation
       STRVC    R12, [R3, #Incarnation_Link]
     [ ModHand_InitDieServices
       BLVC     IssueServicePostInit
     ]
03     STRVS    R0, [stack]
       Pull    "R0-R4, R9, lr"
        B       SLVK_TestV


01     LDR      R11, [R0]
       LDR      R2, =ErrorNumber_RMNotFound
       CMP      R11, R2
       BEQ      %FT02
05
       SETV
       B        %BT03

02     MOV      R0, #0
       BL       AddModuleIfInROM
       B        %BT03

;*************************************************************

Module_Delete   ROUT
       Push    "R0-R4, R9, lr"
       BL       lookup_commoned
       BVS      %FT01

       ADDEQ    R3, R9, #Module_incarnation_list
       LDREQ    R12, [R9, #Module_incarnation_list]

 ;    R12 -> incarnation node, R3  -> previous incarnation

       BL       KillIncarnation
01     STRVS    R0, [stack]
       Pull    "R0-R4, R9, lr"
       B        SLVK_TestV

;*************************************************************

Module_Free      ROUT
Module_RMADesc
         Push   "R0, R1, lr"

         SUB     R0, R0, #(ModHandReason_RMADesc-HeapReason_Desc)
 ASSERT HeapReason_Desc-HeapReason_Free=ModHandReason_RMADesc-ModHandReason_Free
         MOV     R1, #RMAAddress
         SWI     XOS_Heap
         STRVS   R0, [stack]
         Pull   "R0, R1, lr"
         B       SLVK_TestV

;*************************************************************

Module_Claim  ROUT
         Push   "R0, R1, lr"
         BL      RMAClaim_Chunk
         STRVS   R0, [stack]
         Pull   "R0, R1, lr"
         B       SLVK_TestV

;*************************************************************
; Garbage collect the RMA. We know there's always one module,
; and some RMA space.

Module_Tidy
         ; on Medusa we do nothing, because we would always fail
         ; due to FSLock being Captain Scarlet
         B       SLVK

;****************************************************************************

Module_Clear Entry "r0-r3"
        WritePSRc SVC_mode, r3                          ; interrupts on
        MOV     r3, #0                                  ; position in chain

; now find entry in chain to kill : one with successor = R3

MHC_GetEndOne
        LDR     r2, =ZeroPage+Module_List               ; prevnode for killing
        LDR     r0, [r2, #Module_chain_Link]
        CMP     r0, r3
        PullEnv EQ
        ExitSWIHandler EQ
MHC_StepOn
        LDR     r1, [r0, #Module_chain_Link]
        CMP     r1, r3
        MOVNE   r2, r0
        MOVNE   r0, r1
        BNE     MHC_StepOn

        LDR     r11, [r0, #Module_ROMModuleNode]        ; don't kill if it's a ROM module (note that this would also
        CMP     r11, #1                                 ; account for squeezed ROM modules, so the invincible bit in the
        LDRCC   r11, [r0, #Module_code_pointer]         ; die entry is not strictly necessary any more, but never mind!)
        LDRCC   r11, [r11, #Module_Die]                 ; Check for invincible module
        CMPCC   r11, #&80000000                         ; (die entry has top bit set)
        MOVCS   r3, r0                                  ; step if not about to delete
                                                        ; - don't assassinate ROM modules.
        BLCC    KillAndFree
        BVC     MHC_GetEndOne

        LDR     r3, [r2, #Module_chain_Link]
        STR     r0, [stack]
        LDR     r0, [stack, #4*4]
        ORR     r0, r0, #V_bit
        STR     r0, [stack, #4*4]
        B       MHC_GetEndOne

;*************************************************************
; AddArea:
; Entry;  R1 -> module in memory to add, leaving it in place.
; Return: registers preserved, V set if problem
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Module_AddArea   ROUT
         Push   "R9, lr"
         WritePSRc SVC_mode, R10             ; interrupts on
         ADRL    R10, crstring               ; null environment
         BL      ModuleIn_CheckForDuplicate  ; altentry to Load_Module
         Pull   "R9, lr"
        B       SLVK_TestV

;*************************************************************
; CopyArea
;    R1 -> area of memory to add to the module list,
;          copying into the RMA
;    R2 =  size of the area.

Module_CopyArea  ROUT
         Push   "R0-R5, R9, lr"
         WritePSRc SVC_mode, lr

  ; R1 address, R2 size
         BL      CheckHeader
         BVS     AreaFail

         MOV     R10, R1

         LDR     R1, [R10, #Module_TitleStr]
         ADD     R1, R1, R10
         BL      LookUp_Module               ; check for duplicate
         BLNE    KillAndFree
         STRVS   R0, [stack]
         Pull   "R0-R5, R9, lr", VS
         BVS     SLVK_TestV

; R10 points at area
         LDR     R3, [stack, #4*2]           ; get size back
         BL      RMAClaim_Chunk
         ADRVSL  R0, ErrorBlock_MHNoRoom
       [ International
         BLVS    TranslateError
       ]
         BVS     AreaFail

         MOV     R9, R2                      ; new module pointer

; copy R3 bytes from R10 to R2
01       LDR     R1, [R10], #4
         STR     R1, [R2], #4
         SUBS    R3, R3, #4
         BHI     %BT01                       ; was BPL, which is wrong!

         ADRL    R10, crstring               ; no environment string
         MOV     R11, #0                     ; not podular
         BL      LinkAndInit

AreaFail
         STRVS   R0, [stack]
         Pull   "R0-R5, R9, lr"
        B       SLVK_TestV

;*************************************************************
; Enumerate modules
; Entry:  R0 Reason code
;         R1 module number
;         R2 incarnation number
; Exit:   R1, R2 updated to refer to next existing module
;         R3 -> module code
;         R4    private word contents
;         R5 -> postfix string

Module_GetNames  ROUT
         WritePSRc SVC_mode, R11             ; interrupts on
         MOV     R11, R1
         MOV     R12, R2
         LDR     R10, =ZeroPage+Module_List
01       LDR     R10, [R10, #Module_chain_Link]
         CMP     R10, #0
         BEQ     %FT10                       ; no more modules
         SUBS    R11, R11, #1
         BPL     %BT01
         LDR     R3, [R10, #Module_code_pointer]
         ADD     R10, R10, #Module_incarnation_list
02       LDR     R10, [R10, #Incarnation_Link]
         CMP     R10, #0
         BEQ     %FT11                       ; no more incarnations
         SUBS    R12, R12, #1
         BPL     %BT02
         LDR     R4, [R10, #Incarnation_Workspace]
         ADD     R5, R10, #Incarnation_Postfix
         LDR     R10, [R10, #Incarnation_Link]
20       CMP     R10, #0
         ADDNE   R2, R2, #1
         MOVEQ   R2, #0
         ADDEQ   R1, R1, #1
         ExitSWIHandler

10       ADR     R0, ErrorBlock_NoMoreModules
       [ International
         B       BumDealInModule_Translate
       |
         B       BumDealInModule
       ]
         MakeErrorBlock NoMoreModules

11       CMP     r2, #0
         LDREQ   r4, =&DEADDEAD
         MOVEQ   r10, #0
         BEQ     %BT20         ; fudge for modules that go bang in init/die
         ADR     R0, ErrorBlock_NoMoreIncarnations
       [ International
         B       BumDealInModule_Translate
       |
         B       BumDealInModule
       ]
         MakeErrorBlock NoMoreIncarnations
         LTORG

;*************************************************************

Module_ExtendBlock ROUT
         Push   "R0, r1, R3, lr"

         ADD     R3, R3, #31
         BIC     R3, R3, #31

         MOV     R0, #HeapReason_ExtendBlock
         BL      DoRMAHeapOpWithExtension

         STRVS   R0, [stack]
         Pull   "R0, r1, R3, lr"
         B       SLVK_TestV

;*************************************************************
; New Incarnation
;    R1 -> module%newpostfix

Module_NewIncarnation ROUT
         Push   "R0-R4, R9, lr"
         WritePSRc SVC_mode, lr
         BL      LookUp_Module
         BEQ     CheckTheROM
         CMP     R12, #0
         BEQ     Incarnation_needed
         CMP     R12, #-1
         BNE     Incarnation_exists
         MOV     R9, R0                      ; node pointer
         MOV     R0, R1                      ; postfix
         MOV     R10, R1
         BL      EnvStringSkipName           ; envstring ptr in R10
         BL      Add_Incarnation
       [ ModHand_InitDieServices
         BLVC    IssueServicePostInit
       ]
01       STRVS   R0, [stack]
         Pull   "R0-R4, R9, lr"
         B      SLVK_TestV

CheckTheROM
         MOV     R0, #Postfix_Separator      ; passed string must have postfix
         LDR     R1, [stack, #1*4]
         BL      AddModuleIfInROM
         B       %BT01

Incarnation_needed
         Pull   "R0-R4, R9, lr"
         ADR     R0, ErrorBlock_PostfixNeeded
       [ International
         B       BumDealInModule_Translate
       |
         B       BumDealInModule
       ]
         MakeErrorBlock PostfixNeeded

Incarnation_exists
         Pull   "R0-R4, R9, lr"
         ADR     R0, ErrorBlock_IncarnationExists
       [ International
         B       BumDealInModule_Translate
       |
         B       BumDealInModule
       ]
         MakeErrorBlock IncarnationExists

;*************************************************************
; Rename Incarnation
; R1 -> current module title
; R2 -> new postfix.

Module_RenameIncarnation ROUT
         Push   "R0-R4, R9, lr"
         BL      lookup_commoned
         BVS     %FT01

; R12 -> incarnation node    (0 for not specified)
; R3  -> previous incarnation

         MOV     R11, R12
         MOV     R0, R9                      ; check incarnation
         LDR     R1, [stack, #4*2]           ; not already there
         Push    R3                          ; preserve pointer to
         BL      FindIncarnation
         Pull    R3                          ; previous incarnation
         BNE     %FT03                       ; already exists
         MOV     R12, R11

         CMP     R12, #0
         ADDEQ   R3, R9, #Module_incarnation_list
         LDREQ   R12, [R9, #Module_incarnation_list]
         MOV     R11, R3

         ADD     R1, R12, #Incarnation_Postfix
         BL      %FT10                       ; old postfix length -> R0
         MOV     R10, R0
         LDR     R1, [stack, #4*2]           ; new postfix
         BL      %FT10                       ; new length - > R0
         SUB     R3, R0, R10

         MOV     R2, R12                     ; incarnation node
         MOV     R0, #HeapReason_ExtendBlock
         BL      DoSysHeapOpWithExtension
         BVS     %FT01

         STR     R2, [R11, #Incarnation_Link] ; relink
         ADD     R2, R2, #Incarnation_Postfix
         LDR     R1, [stack, #4*2]
02       LDRB    R0, [R1], #1
         CMP     R0, #" "
         MOVLE   R0, #0
         STRB    R0, [R2], #1
         BGT     %BT02
01       STRVS   R0, [stack]
         Pull   "R0-R4, R9, lr"
         B      SLVK_TestV

03       ADR     R0, ErrorBlock_IncarnationExists
       [ International
         Push   "LR"
         BL     TranslateError
         Pull   "LR"
       |
         SETV
       ]
         B       %BT01

10       MOV     R0, #0
11       LDRB    R3, [R1, R0]
         CMP     R3, #" "
         ADDGT   R0, R0, #1
         BGT     %BT11
         MOV     PC, lr

;*************************************************************
; MakePreferred
;   R1 -> name

Module_MakePreferred ROUT
        Push    "R0-R4, R9, lr"
        BL      lookup_commoned
        BVS     %FT01
        BLNE    PreferIncarnation       ; only prefer it if found!
01
        STRVS   R0, [sp, #0]
        Pull    "R0-R4, R9, lr"
        B       SLVK_TestV

;*************************************************************
; AddPoduleModule
;
; in:   R1 -> envstring
;       R2 = chunk number
;       R3 = podule number
;
; out:  All registers preserved

Module_AddPoduleModule Entry
        WritePSRc SVC_mode, lr                  ; interrupts on
        BL      APMEntry
        PullEnv
        B       SLVK_TestV

APMEntry Entry "r0-r7,r9"
        MOV     r0, r2
        SWI     XPodule_EnumerateChunksWithInfo ; out: r1=size, r2=type, r4->name, r5->help string, r6=module address if in ROM
        BVS     %FT99
        CMP     r2, #OSType_Module
        BNE     %FT98

        MOV     r7, r3
        MOV     r5, #0                          ; indicate not a ROM module (although strictly speaking, it is!)
APMInitEntry
        Push    "r1"                            ; size
        MOV     r1, r4
        BL      LookUp_Module                   ; check for duplicate
        BLNE    KillAndFree
        Pull    "r3"                            ; get size back
        BVS     %FT99

        MOVS    r1, r6                          ; if module address non-zero, then it's a directly executable ext. ROM
        BNE     %FT10                           ; and don't claim a block, or read the chunk

        BL      RMAClaim_Chunk
        BVS     %FT99
        LDR     r0, [stack, #4*2]
        LDR     r3, [stack, #4*3]
        SWI     XPodule_ReadChunk
        MOV     r1, r2                          ; r1 = address of module
10
        LDR     r2, [r1, #-4]                   ; r2 = size
        BLVC    CheckHeader
        BVS     %FT97                           ; free space too (doesn't matter that it fails for extension ROM)

        MOV     r9, r1
        LDR     r10, [stack, #4]                ; envptr

        MOVS    r3, r7                          ; if not a podule (r7 < 0)
        MOVMI   r11, #0                         ; then use hardware address zero
        BMI     %FT20
        Push    "r1"                            ; else compute hardware address from 'fake' podule number
        SWI     XPodule_HardwareAddresses       ; get raw hardware address for podule r3 into r0 (r1 = combined)
        Pull    "r1"
        BVS     %FT97
        MOV     r11, r0                         ; move into r11
20
        BL      LinkAndInit
        STRVC   r5, [r9, #Module_ROMModuleNode] ; store zero or pointer to ROM module node (if no error in init)
99
        STRVS   r0, [stack]
        EXIT

98
        ADR     r0, ErrorBlock_ChunkNotRM
      [ International
        BL      TranslateError
      ]
96
        SETV
        B       %BT99
        MakeErrorBlock ChunkNotRM

97
        MOV     r2, r1                          ; free claimed RMA space
        MOV     r1, #RMAAddress
        Push    "r0"
        MOV     r0, #HeapReason_Free
        SWI     XOS_Heap
        Pull   "r0"
        B       %BT96

        LTORG

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; LookupName
;    Take module name, return info on it suitable for use with Enumeration
;      (e.g. to get all incarnations of it)
;  In :   R1 -> name
;  Out:   R1 module number          \  of THIS module; first enumerate
;         R2 incarnation number     /  call will give back this module
;         R3 -> module code
;         R4    private word contents
;         R5 -> postfix string

Module_LookupName ROUT
         Push   "R0-R4, R9, lr"
         BL      lookup_commoned
         BVC     %FT01
         STR     R0, [stack]
         Pull   "R0-R4, R9, lr"
         B      SLVK_SetV

01       MOV     R1, #0               ; module number
         LDR     R0, =ZeroPage+Module_List

; R9  -> module chain node
; R12 -> incarnation node    (0 for not specified, -1 for not found)

         LDREQ   R12, [R9, #Module_incarnation_list]  ; preferred inc.

02       LDR     R0, [R0]
         CMP     R0, R9
         ADDNE   R1, R1, #1
         BNE     %BT02
         ADD     R0, R0, #Module_incarnation_list
         MOV     R2, #0
03       LDR     R0, [R0]
         CMP     R0, R12
         ADDNE   R2, R2, #1
         BNE     %BT03
         LDR     R3, [R9, #Module_code_pointer]
         LDR     R4, [R12, #Incarnation_Workspace]
         ADD     R5, R12, #Incarnation_Postfix
         LDR     r0, [sp], #5*4            ; Load r0, skip r1-r4
         Pull   "R9, lr"
         ExitSWIHandler

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; EnumerateROM_Modules and EnumerateROM_ModulesWithInfo
;
;  In :   R1 = module number
;         R2 = -1    => ROM
;            = other => Podule R2
;
;  Out:   R1 = incremented: next call will return next module
;         R2 = preserved
;         R3 -> name
;         R4 = -1 => unplugged
;            =  0 => inserted but not currently in the module chain
;            =  1 => active
;            =  2 => running
;         R5 =  chunk number of podule RM
;         If R0 = ModHandReason_EnumerateROM_ModulesWithInfo then
;          R6 = BCD version number of module (decimal point between top and bottom half-words)

Module_EnumerateROM_Modules ROUT
Module_EnumerateROM_ModulesWithInfo ROUT
        LDR     r12, =ZeroPage+ROMModuleChain
        MOV     r10, r1                                 ; module count
10
        LDR     r12, [r12, #ROMModule_Link]             ; follow link to next module
        TEQ     r12, #0                                 ; if no more modules
        ADREQL  r0, ErrorBlock_NoMoreModules
      [ International
        Push    "lr",EQ
        BLEQ    TranslateError
        Pull    "lr",EQ
      ]
        BEQ     SLVK_SetV                               ; then report error
        LDR     r11, [r12, #ROMModule_PoduleNumber]
        CMP     r2, #-1                                 ; if searching for podule -1, then this one must be ">="
        BEQ     %FT30
        BGT     %FT20                                   ; searching from normal podules onwards

; searching from extension ROMs onwards

        CMP     r11, r2                                 ; so if r11 > r2 then not there yet
        BGT     %BT10

; searching from normal podules onwards

20
        CMP     r11, #-1                                ; if found one is extension ROM
        BLT     %FT30                                   ; then will be OK
        CMP     r11, r2                                 ; else is only OK if r11 >= r2
        BLT     %BT10
30
        CMP     r11, r2                                 ; check for equality
        MOVNE   r1, #0                                  ; if not correct podule then this is the one to return
        BNE     %FT50

        SUBS    r10, r10, #1                            ; decrement module count
        BCS     %BT10                                   ; not there yet, so go back
50
        Push    "r0-r2, lr"
        LDR     r10, [r12, #ROMModule_CMOSAddrMask]     ; get CMOS address and mask
        ANDS    r2, r10, #&FF                           ; extract address
        MOVNE   r1, r2                                  ; if there is a CMOS address
        MOVNE   r0, #ReadCMOS
        SWINE   XOS_Byte                                ; then read it
        TST     r2, r10, LSR #16                        ; test bit
        Pull    "r0-r2"
        Push    "r8, r9"
        MOVNE   r4, #-1                                 ; indicate unplugged
        BNE     %FT90

; not unplugged, so check for module in module list

        LDR     r4, =ZeroPage+Module_List
60
        LDR     r4, [r4, #Module_chain_Link]
        TEQ     r4, #0                                  ; module not active
        BEQ     %FT90
        LDR     r11, [r4, #Module_ROMModuleNode]        ; get active module's pointer to ROM module node
        TEQ     r11, r12                                ; if it matches
        BNE     %BT60
        LDR     r10, [r4, #Module_code_pointer]         ; get pointer to code
        LDR     r11, =ZeroPage
        LDR     r11, [r11, #Curr_Active_Object]
        LDR     r4, [r10, #-4]                          ; node size of code
        ADD     r4, r4, r10
        CMP     r11, r10
        CMPCS   r4, r11
        MOVHI   r4, #2                                  ; indicate running
        MOVLS   r4, #1                                  ; indicate just active
90
        LDR     r2, [r12, #ROMModule_PoduleNumber]      ; reload podule number
        CMP     r2, #-1                                 ; if not main ROM
        LDRNE   r5, [r12, #ROMModule_ChunkNumber]       ; then load chunk number
        LDR     r3, [r12, #ROMModule_Name]              ; load pointer to name
        ADD     r1, r1, #1                              ; move module number onto next one
        TEQ     r0, #ModHandReason_EnumerateROM_ModulesWithInfo
        LDREQ   r6, [r12, #ROMModule_Version]
        Pull    "r8, r9, lr"                            ; restore registers
        ExitSWIHandler                                  ; and exit

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; FindEndOfROM_ModuleChain
;
;  In :   R1 = -1    => ROM
;            = other => reserved
;
;  Out:   R1 = preserved
;         R2 -> first word after ROM module chain

Module_FindEndOfROM_ModuleChain ROUT
        CMP     r1, #-1                                 ; Only works for the system ROM at present
        ADRNEL  r0, ErrorBlock_BadParameters
      [ International
        Push    "lr",NE
        BLNE    TranslateError
        Pull    "lr",NE
      ]
        BNE     SLVK_SetV

        ADRL    r2, SysModules_Info + 4                 ; Step through until the end of the module chain
10      LDR     r11, [r2, #-4]
        TEQ     r11, #0
        ADDNE   r2, r2, r11
        BNE     %BT10

        ExitSWIHandler                                  ; and exit

;*************************************************************
; Support routines.
;
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Load_Module
;     takes filename pointer in R1, and loads and initialises the given file.
;     Returns R9 as a pointer to the node claimed
;     and  V/current error set if fails

Load_Module ROUT

        Push   "R0-R5, lr"

        MOV     r0, #OSFile_ReadInfo
        SWI     XOS_File
        BVS     modfailxit              ; return FileSwitch error
        CMP     r0, #object_file
        BNE     HeNotFile

        MOV     R2, R2, ASR #8          ; low byte ignored by me.
        CMP     R2, #&FFFFF000 :OR: FileType_Module
        BNE     NotAModule

; it's a module, so try and claim.
        MOV     R10, R1                 ; keep string pointer
        MOV     R3, R4                  ; size of vector needed
        BL      RMAClaim_Chunk
        BVS     modfailxit

02      MOV     R9, R2                  ; keep a copy of node ptr.
        MOV     R1, R10
        MOV     R3, #0                  ; load to R2 posn
        MOV     R0, #OSFile_Load
        SWI     XOS_File
        BVS     modfailxit              ; return FileSwitch error

50      MOV     R11, #0                 ; not loaded from hardware.

; R9 address, R9!-4 size
        MOV     R1, R9
        LDR     R2, [R9, #-4]
        BL      CheckHeader
        BVS     Duplicate_Immortal      ; actually means naff header field

; now we've got it, see if any other modules have the same name.

        LDR     R1, [R9, #Module_TitleStr]
        ADD     R1, R1, R9
        BL      LookUp_Module
        BEQ     %FT01                   ; no module at all
        CMP     R12, #0
        BNE     nopostfixwanted         ; postfix given: bad name
        BL      KillAndFree
        BVS     Duplicate_Immortal

; now claim a link
; R9 module pointer, R10 environment

01      BL      EnvStringSkipName
        BL      LinkAndInit             ; takes R2 prevnode from lookup

        STRVS   R0, [stack]
        Pull   "R0-R5, pc"

Duplicate_Immortal                      ; free space claimed for loading
        STR     R0, [stack]
        MOV     R2, R9
        MOV     R0, #HeapReason_Free
        MOV     R1, #RMAAddress
        SWI     XOS_Heap
        SETV
        Pull   "R0-R5, PC"

        MakeErrorBlock MHNoRoom

nopostfixwanted
        ADR     R0, ErrorBlock_ModulePostfix
      [ International
        BL      TranslateError
      ]
        B       modfailxit

        MakeErrorBlock ModulePostfix

        MakeErrorBlock NotMod

NotAModule
        ADR     R0, ErrorBlock_NotMod
      [ International
        BL      TranslateError
      ]
modfailxit
        STR     R0, [stack]
        SETV
        Pull   "R0-R5, PC"

HeNotFile
        MOV     r2, r0
        MOV     r0, #OSFile_MakeError
        SWI     XOS_File
        B       modfailxit

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; ModuleIn_CheckForDuplicate
; Altentry to Load_Module for AddArea: module already in, initialise it.

ModuleIn_CheckForDuplicate
         Push   "R0-R5, lr"
         MOV     R9, R1           ; move module ptr to handy place
         B       %BT50

;*************************************************************
; AddModuleIfInROM
; in: R1 -> name
;     R0 = Postfix_Separator => called from AddNewIncarnation when module is not active
;                               find newest version in ROM, and initialise it in its own location (even if unplugged)
;                               then rename the base incarnation of it to specified postfix
;
;        = 0                 => called from ReInit when module is not active
;                               plug in all versions of module, and initialise newest one in its own location
;
; out: R5-R8 preserved
;      Other registers may be corrupted
;

AddModuleIfInROM Entry "r5-r8"
        MOV     r4, r0
        MOV     r12, #0                                 ; search entire ROM set
        MOV     r7, r1                                  ; save pointer to beginning of name
        BL      FindROMModule
        TEQ     r12, #0
        BNE     %FT10
        BL      MakeNotFoundError                       ; in:  r1 -> module name 'foo'
                                                        ; out: r0 -> "Module 'foo' not found" error, V=1
        EXIT

10
        MOV     r6, r1                                  ; save pointer to terminator of module name
15
        LDR     r14, [r12, #ROMModule_OlderVersion]     ; find oldest version
        TEQ     r14, #0
        MOVNE   r12, r14
        BNE     %BT15

20
        TEQ     r4, #0                                  ; if doing AddIncarnation rather than ReInit
        BNE     %FT30                                   ; then don't plug module in
        MOV     r5, #&FF                                ; set up byte mask (and indicate found)
        LDR     r1, [r12, #ROMModule_CMOSAddrMask]
        AND     r3, r5, r1, LSR #16                     ; get bit mask
        ANDS    r1, r1, r5
        BEQ     %FT30                                   ; if no CMOS, then look for another module
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        EXIT    VS
        TST     r2, r3                                  ; test if module unplugged
        BEQ     %FT30                                   ; if not, then don't write to CMOS (so RMReInit works when FSLock enabled)
        BIC     r2, r2, r3                              ; otherwise clear bit
        MOV     r0, #WriteCMOS
        SWI     XOS_Byte
        EXIT    VS
30
        LDR     r14, [r12, #ROMModule_NewerVersion]
        TEQ     r14, #0
        MOVNE   r12, r14
        BNE     %BT20

        TEQ     r4, #0                                  ; if AddIncarnation then check that name terminator is "%"
        LDRNEB  r14, [r6], #1                           ; load next character (and skip it)
        TEQNE   r14, #Postfix_Separator
        BEQ     %FT40
        ADRL    r0, ErrorBlock_PostfixNeeded
      [ International
        BL      TranslateError
      |
        SETV
      ]
        EXIT

40
        MOV     r11, r12
        BL      InitialiseROMModule                     ; in both cases initialise newest version
                                                        ; (in AddIncarnation case it may still be unplugged)
        EXIT    VS

        TEQ     r4, #0                                  ; if ReInit then we've finished (V=0 from above)
        EXIT    EQ

        SUB     r8, r6, r7                              ; length of module name including '%'
        ADD     r8, r8, #4+1+3                          ; allow for 'Base<0>' and round up to whole number of words
        BIC     r8, r8, #3
        SUB     stack, stack, r8

        MOV     r0, stack
50
        LDRB    r14, [r7], #1                           ; copy name, including '%'
        STRB    r14, [r0], #1
        TEQ     r7, r6
        BNE     %BT50

        ADR     r1, base_postfix
60
        LDRB    r14, [r1], #1                           ; copy 'Base<0>'
        STRB    r14, [r0], #1
        TEQ     r14, #0
        BNE     %BT60

        MOV     r0, #ModHandReason_RenameIncarnation
        MOV     r1, stack                               ; pointer to '<module>%Base<0>'
        MOV     r2, r6                                  ; pointer to 'newinc'
        SWI     XOS_Module
        ADD     stack, stack, r8                        ; junk name
        EXIT

;*************************************************************
; LinkAndInit :
;     module pointer in R9
;     module list position in R2 : added at end if posn not found
;     environment string pointer in R10
;    "hardware" in R11
;     returns module node pointer in R9

LinkAndInit Entry "r2, r3"


  [ ChocolateSysHeap
        ASSERT  ChocolateMABlocks = ChocolateBlockArrays + 16
        LDR     r3,=ZeroPage+ChocolateBlockArrays
        LDR     r3,[r3,#16]
        BL      ClaimChocolateBlock
    [ ModHand_IntrinsicBI
        MOVVS   r3, #ModInfo + Incarnation_Postfix + 8   ;enough for 'Base',0
    |
        MOVVS   r3, #ModInfo
    ]
        BLVS    ClaimSysHeapNode
  |
    [ ModHand_IntrinsicBI
        MOV     r3, #ModInfo + Incarnation_Postfix + 8   ;enough for 'Base',0
    |
        MOV     r3, #ModInfo
    ]
        BL      ClaimSysHeapNode
  ]
        EXIT    VS

        STR     r9, [r2, #Module_code_pointer]
        STR     r11, [r2, #Module_Hardware]
        MOV     r9, r2                                  ; keep node pointer

        MOV     r0, #0
        STR     r0, [r2, #Module_ROMModuleNode]         ; assume not a ROM module
        STR     r0, [r2, #Module_incarnation_list]      ; terminate list
        ADR     r0, base_postfix
  [ ModHand_IntrinsicBI
        BL      Add_intrinsic_Incarnation               ; add Base incarnation
  |
        BL      Add_Incarnation                         ; add Base incarnation
  ]
        BVS     %FT01

        Pull    "r2"
        LDR     r0, =ZeroPage+Module_List
05
        LDR     r1, [r0, #Module_chain_Link]
        CMP     r1, #0
        CMPNE   r0, r2
        MOVNE   r0, r1
        BNE     %BT05

; add module to chain end - give ROM modules priority.

        STR     r1, [r9, #Module_chain_Link]
        STR     r9, [r0, #Module_chain_Link]
      [ ModHand_InitDieServices
        BL      IssueServicePostInit
      ]
        Pull    "r3, pc"                                ; V clear from EQ compare with 0

01
        Push    "r0"
        LDR     r2, [r9, #Module_code_pointer]
        MOV     r1, #RMAAddress
        MOV     r0, #HeapReason_Free
        SWI     XOS_Heap
        MOV     r2, r9                                  ; node pointer
  [ ChocolateSysHeap
        ASSERT  ChocolateMABlocks = ChocolateBlockArrays + 16
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#16]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]
        SETV
        Pull    "r0, r2, r3, pc"

base_postfix
        =       "Base",0                                ; postfix used for 1st incarnation
        ALIGN

        LTORG

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  [ ModHand_IntrinsicBI
Add_intrinsic_Incarnation  ROUT
         Push   "R0-R3, lr"
         ADD    r2, r9, #ModInfo              ;base incarnation at end of node
         MOV    r3, #Incarnation_Postfix + 5
         B      Add_Incarnation_AltEntry
  ]

; Add_Incarnation
;       takes postfix pointer in R0 (terminated by <= space
;       module node pointer in R9
;       envstring in R10
;   Adds an incarnation node, reinitialises the module

Add_Incarnation  ROUT
         Push   "R0-R3, lr"

         MOV     R3, #Incarnation_Postfix      ; node size needed
01       LDRB    R1, [R0], #1
         ADD     R3, R3, #1
         CMP     R1, #" "
         BGT     %BT01
         BL      ClaimSysHeapNode
         STRVS   R0, [stack]
         Pull   "R0-R3, PC", VS

         LDR     R0, [stack]
Add_Incarnation_AltEntry
         ADD     R3, R2, #Incarnation_Postfix
02       LDRB    R1, [R0], #1
         CMP     R1, #" "
         STRGTB  R1, [R3], #1
         BGT     %BT02
         MOV     R1, #0
         STRB    R1, [R3]

         MOV     R3, #0
         STR     R3, [R2, #Incarnation_Workspace] ; zero private word
         MOV     R12, R2
         BL      CallInit
;         BLVS    FreeIncarnation done by CallInit
         STRVS   R0, [stack]

         LDRVC   R3, [R9, #Module_incarnation_list]
         STRVC   R3, [R2, #Incarnation_Link]
         STRVC   R2, [R9, #Module_incarnation_list]
         Pull   "R0-R3, PC"

;*************************************************************
CallInit         ROUT
;    take R9  -> module node
;         R12 -> incarnation node
;         R10 -> envstring
;    set R11 appropriately
;    initialise module with R10 given

        Push   "R0-R6, R11, R12, lr"

 [ SqueezeMods
        BL      CheckForSqueezedModule                  ; unsqueeze module if squeezed
        BVS     %FT02
 ]

  ; if ChocolateService, we must not add to service chains yet, because we have
  ; to make sure module's init entry is called before service entry (command
  ; and SWI hashing don't have these worries - they won't be used yet)

 [ Oscli_HashedCommands
  ; see if we need to update command hash nodes
        BL      AddCmdHashEntries
        BVS     %FT02
 ]

  ; see if we need to set up a module swi node

        BL      CheckForSWIEntries
        LDR     R12, [stack, #4*(6+2)]
        BNE     %FT03

  ; the module really does have a SWI chunk. Add node to hashtable.
  ; KJB - after v3.71 add new modules at end, on grounds that first-registered
  ; modules are probably more important. Exception is when a second module wants
  ; an already used SWI chunk - it should get priority.

        MOV     R4, R0
        MOV     R11, R1
  [ ChocolateSysHeap
        ASSERT  ChocolateMSBlocks = ChocolateBlockArrays + 20
        LDR     r3,=ZeroPage+ChocolateBlockArrays
        LDR     r3,[r3,#20]
        BL      ClaimChocolateBlock
        MOVVS   R3, #ModSWINode_Size
        BLVS    ClaimSysHeapNode
  |
        MOV     R3, #ModSWINode_Size
        BL      ClaimSysHeapNode
  ]
        BVS     %FT02
        STR     R9,  [R2, #ModSWINode_MListNode]
        STR     R4,  [R2, #ModSWINode_CallAddress]
        STR     R11, [R2, #ModSWINode_Number]
        ModSWIHashval R3,R11
        LDR     R4, [R3]
        B       %FT09
   ; top of loop: R4 = node under consideration, R3 = pointer to this node from previous
08      LDR     R14, [R4, #ModSWINode_Number]
        TEQ     R11, R14                        ; if numbers match, jump to end. This also sets
        BEQ     %FT10                           ;     the new node's link to this node
        ADD     R3, R4, #ModSWINode_Link        ; update R3 to this node's link
        LDR     R4, [R3]                        ; and move R4 to next node
09      TEQ     R4, #0
        BNE     %BT08                           ; if no next node, exit loop and tack on new one
10      STR     R4, [R2, #ModSWINode_Link]
        STR     R2, [R3]

03  ; now prepared to look at module

        LDR     R3, [R9, #Module_code_pointer]

        LDR     R4, [R9, #Module_ROMModuleNode]
        CMP     R4, #0
        BNE     %FT04                           ;It's a ROM module, so it already knows it's code
        Push    "r0-r2"
        LDR     r4, [r3, #-4]                   ;Read the length of the module from the RMA.
        MOV     r0, r3                          ;start address
        MOV     r2, r4                          ;length
        MOV     r1, #&B9                        ;Service_ModulePreInit ; a chance to patch things
        SWI     XOS_ServiceCall
        MOV     r0, #1                          ;It's a ranged synchronisation
        MOV     r1, r3                          ;Start address
        ADD     r2, r3, r4                      ;End address
        SWI     XOS_SynchroniseCodeAreas
        Pull    "r0-r2"
04

        LDR     R4, [R3, #Module_Init]
        CMP     R4, #0
  [ ChocolateService
        BEQ     %FT05
  |
        Pull   "R0-R6, R11, R12, PC", EQ      ; V clear
  ]

        ADD     R12, R12, #Incarnation_Workspace
        MOV     R11, #0
        ADD     R5, R9, #Module_incarnation_list - Incarnation_Link
01      LDR     R5, [R5, #Incarnation_Link]
        CMP     R5, #0                        ; count incarnations
        ADDNE   R11, R11, #1
        BNE     %BT01
        CMP     R11, #0
        LDREQ   R11, [R9, #Module_Hardware]

  ; R11, R12 now set: initialise

        MOV     lr, PC                        ; pseudo BL
        ADD     PC, R3, R4                    ; call 'im

  [ ChocolateService
    ;now safe to try to add to service chains (init entry has been called)
    ;note that AddToServiceChains may cause error (ran out of room)
05
        LDRVC   R12, [stack, #4*(6+2)]
        BLVC    AddToServiceChains
  ]
        Pull   "R0-R6, R11, R12, PC", VC

02      LDR     R12, [stack, #4*(6+2)]
        BL      FreeIncarnation
  [ Oscli_HashedCommands
        BL      FreeCmdHashEntries
  ]
  [ ChocolateService
        BL      RemoveFromServiceChains
  ]
        BL      FreeSWIEntry
        STR     R0, [stack]
        Pull   "R0-R6, R11, R12, PC"           ; V set return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Enter with module pointer in R1
;              "    size    in R2

CheckHeader ROUT
        Push   "R3, lr"
        LDR     R3, [R1, #Module_HC_Table]
        BL      %FT11
        LDR     R3, [R1, #Module_HelpStr]
        BL      %FT11
        LDR     R3, [R1, #Module_TitleStr]
        BL      %FT11
        LDR     R3, [R1, #Module_Service]
        BL      %FT10
        LDR     R3, [R1, #Module_Die]
        BIC     R3, R3, #&80000000              ; ignore top-bit (means cannot be RMCleared)
        BL      %FT10
        LDR     R3, [R1, #Module_Init]
        TST     R3, #&80000000
        BLEQ    %FT10                           ; only check init offset if an unsqueezed module
; Need to go through extra checks to see that (a) we have a module
; flags table, and (b) it says that we're 32-bit
        LDR     R3, [R1, #Module_SWIChunk]
        TST     R3, #&FF000000
        TSTEQ   R3, #Module_SWIChunkSize-1
        BNE     %FT88
        LDR     R3, [R1, #Module_SWIEntry]
        BL      %FT20
        LDR     R3, [R1, #Module_NameTable]
        BL      %FT21
        LDR     R3, [R1, #Module_NameCode]
        BL      %FT20
        LDR     R3, [R1, #Module_MsgFile]
        BL      %FT20
        LDR     R3, [R1, #Module_FlagTable]
        BL      %FT20
        LDR     R3, [R1, R3]
        TST     R3, #ModuleFlag_32bit
        BEQ     %FT88
        CLRV
        Pull   "R3, PC"

10      TST     R3, #3
        BNE     %FT99
11      CMP     R3, R2
        MOVLO   PC, lr
99
        ADR     R0, ErrorBlock_BadRMHeaderField
      [ International
        BL      TranslateError
      |
        SETV
      ]
        Pull   "R3, PC"

20      TST     R3, #3
        BNE     %FT88
21      CMP     R3, R2
        MOVLO   PC, lr
88
        ADR     R0, ErrorBlock_RMNot32bit
      [ International
        MOV     R3, R4
        LDR     R4, [R1, #Module_TitleStr]
        ADD     R4, R1, R4
        BL      TranslateError_UseR4
        MOV     R4, R3
      |
        SETV
      ]
        Pull   "R3, PC"
        MakeErrorBlock RMNot32bit

        MakeErrorBlock BadRMHeaderField

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Enter with module node pointer in R9
; Sets R12 to module code pointer, R0 SWI code offset, R1 to SWI number
; Only returns SWIs extant if no incarnations of module yet

CheckForSWIEntries ROUT
         LDR     R12, [R9, #Module_incarnation_list]
         CMP     R12, #0
         LDREQ   R12, [R9, #Module_code_pointer]
         LDREQ   R1, [R12, #Module_SWIChunk]
         BICEQ   R1, R1, #Auto_Error_SWI_bit
         TSTEQ   R1, #Module_SWIChunkSize-1
         TSTEQ   R1, #&FF000000
         MOVNE   PC, lr                         ; naff chunk number.
         CMP     R1, #0
         LDRNE   R0, [R12, #Module_SWIEntry]
         CMPNE   R0, #0
         BEQ     %FT02
         TST     R0, #3
         MOVNE   PC, lr
         Push   "R5"
         LDR     R5, [R12, #-4]
         CMP     R5, R0
         Pull   "R5"
01       BLS     %FT02
         ADD     R0, R0, R12
         CMP     R0, R0
         MOV     PC, lr                         ; EQ for success
02       CMP     PC, #0
         MOV     PC, lr                         ; NE return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Takes R9 pointer to module node; frees any module SWI hashtab node

FreeSWIEntry ROUT
         Push   "R0-R5, R12, lr"
         MRS     R5, CPSR
         BL      CheckForSWIEntries
         BEQ     %FT05
         MSR     CPSR_f, R5
         Pull   "R0-R5, R12, PC"
05
         MOV     R3, R1                ; copy of SWIno
         ModSWIHashval R1
         LDR     R2, [R1], #-ModSWINode_Link

  ; R1 predecessor, R2 currnode, R0 call address, R3 SWIno
  ; look down chain until find right call address and number
01       CMP     R2, #0
         BNE     %FT03
         MSR     CPSR_f, R5
         Pull   "R0-R5, R12, PC"
03
         LDR     R4, [R2, #ModSWINode_CallAddress]
         CMP     R4, R0
         LDREQ   R4, [R2, #ModSWINode_Number]
         CMPEQ   R4, R3
         MOVNE   R1, R2
         LDRNE   R2, [R2, #ModSWINode_Link]
         BNE     %BT01
         LDR     R4, [R2, #ModSWINode_Link]
         STR     R4, [R1,#ModSWINode_Link]
  [ ChocolateSysHeap
         ASSERT  ChocolateMSBlocks = ChocolateBlockArrays + 20
         LDR     r1,=ZeroPage+ChocolateBlockArrays
         LDR     r1,[r1,#20]
         BL      FreeChocolateBlock
         BLVS    FreeSysHeapNode
  |
         BL      FreeSysHeapNode
  ]
         MSR     CPSR_f, R5
         Pull   "R0-R5, R12, PC"

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  [ Oscli_HashedCommands

         ASSERT  Oscli_MHashValMask = &ff

;entry: R11 -> module cmd table, R4-> 8-word (256-bit) sieve workspace
;exit:  sieve updated, R0-R3,R5,R6 trashed
;
CmdHashSieve ROUT
         MOV     R0,R4
         MOV     R1,#0
         MOV     R2,#8
10
         STR     R1,[R0],#4                        ;zero the sieve
         SUBS    R2,R2,#1
         BNE     %BT10
         ;commands with either of these flags set in information word won't be of interest:
         MOV     R5,#FS_Command_Flag :OR: Status_Keyword_Flag
         MOV     R0,R11
18
         MOV     R6,#0                             ;hash value accumulator
         LDRB    R1,[R0],#1
         CMP     R1,#0
         BEQ     %FT40                             ;no more entries
20
         UpperCase R1,R2
         ADD     R6,R6,R1                          ;hash value is sum of upper cased char values
         LDRB    R1,[R0],#1
         CMP     R1,#0
         BNE     %BT20
         ADD     R0,R0,#3
         BIC     R0,R0,#3                          ;align to word boundary
         LDR     R1,[R0,#4]                        ;pick up information word
         TST     R1,R5
         BNE     %FT30                             ;not interested in this type of command
         AND     R6,R6,#&FF                        ;hash value (256-wide)
         AND     R2,R6,#&1F
         MOV     R3,#1
         MOV     R3,R3,LSL R2                      ;position in sieve word
         MOV     R6,R6,LSR #5                      ;sieve word index
         LDR     R1,[R4,R6,LSL #2]
         ORR     R1,R1,R3                          ;set bit in sieve for this hash value
         STR     R1,[R4,R6,LSL #2]
30
         ADD     R0,R0,#4*4                        ;next command entry (skip 4 word fields)
         B       %BT18
40
         MOV     PC,LR

;
;entry: R0 -> Oscli_CmdHashLists array
;       R6 =  hash index
;exit:  node created/expanded if necessary to allow room for at least 1 more hash ptr
;       R1 -> node (may have moved, or been created)
;       OR V set, error returned if no room
;
; - a cmd hash node is:
;           1 word  = max count (according to current size of node)
;           1 word  = current count (N)
;           N words = the entries themselves (entries are module node pointers)
;
CheckRoomForNewCmdHash ROUT
         Push    "R0,R2,R3,LR"
         LDR     R1,[R0,R6,LSL #2]     ;pick up list for this hash value
         CMP     R1,#0
         BNE     %FT10
         Push    "R0,R1"
         MOV     R3,#(5+2)*4           ;enough for 5 entries, plus the two count words
         BL      ClaimSysHeapNode
         STRVS   R0,[SP]
         Pull    "R0,R1"
         BVS     %FT90
         MOV     R1,R2
         MOV     R3,#5
         STR     R3,[R1,#0]            ;set the max count word
         MOV     R3,#0
         STR     R3,[R1,#4]            ;zero the current count word
         STR     R1,[R0,R6,LSL #2]     ;store pointer to node in array
         B       %FT90
10
         LDR     R3,[R1,#0]            ;pick up the max count
         LDR     R2,[R1,#4]            ;pick up thr current count
         ADD     R2,R2,#1              ;need one more entry
         CMP     R2,R3
         BLS     %FT90
         Push    "R0"
         MOV     R0,#HeapReason_ExtendBlock
         MOV     R2,R1
         MOV     R3,#4*4               ;enough for 4 more entries
         BL      DoSysHeapOpWithExtension
         STRVS   R0,[SP]
         Pull    "R0"
         BVS     %FT90
         MOV     R1,R2
         STR     R1,[R0,R6,LSL #2]     ;store pointer to node in array (may have moved)
         LDR     R3,[R1,#0]
         ADD     R3,R3,#4
         STR     R3,[R1,#0]            ;bump max count by 4
90
         STRVS   R0,[SP]
         Pull    "R0,R2,R3,PC"
;
;
;entry: R9 -> module node
;exit:  module entered into command hash table(s) where appropriate
;       OR V set, error returned if no room
;
AddCmdHashEntries ROUT
         Push    "R0-R6,R11,R12,LR"
         LDR     R12,[R9,#Module_incarnation_list]
         CMP     R12,#0
         BNE     %FT90                             ;only do stuff if no incarnations yet
         LDR     R12,[R9,#Module_code_pointer]
         LDR     R11,=UtilityMod
         CMP     R12,R11
         BEQ     %FT90                             ;ignore UtilityModule (Oscli deals directly with it)
         LDR     R11,[R12,#Module_HC_Table]
         CMP     R11,#0
         BEQ     %FT90                             ;no commands
         ADD     R11,R12,R11                       ;R11 -> command table
         SUB     SP,SP,#8*4                        ;256-bit workspace for 256-wide hashing sieve
         MOV     R4,SP
         BL      CmdHashSieve
         ;now our sieve has a bit set for each hash value that this module occupies for commands
         LDR     R0,=ZeroPage
         LDR     R0,[R0,#Oscli_CmdHashLists]
         MOV     R6,#0
42
         AND     R2,R6,#&1F
         MOV     R3,#1
         MOV     R3,R3,LSL R2                      ;position in sieve word
         MOV     R5,R6,LSR #5                      ;sieve word index
         LDR     R1,[R4,R5,LSL #2]
         TST     R1,R3
         BEQ     %FT50                             ;module does not occupy this hash value
         BL      CheckRoomForNewCmdHash            ;returns R1 -> cmd hash node
         BVS     %FT88
         LDR     R2,[R1,#4]                        ;current no. of entries on list
         ADD     R2,R2,#1
         STR     R2,[R1,#4]
         ADD     R1,R1,#4
         STR     R9,[R1,R2,LSL #2]                 ;store ptr to module node at end of list
50
         ADD     R6,R6,#1                          ;next hash value
         CMP     R6,#256
         BLO     %BT42
88
         ADD     SP,SP,#8*4                        ;drop sieve workspace
90
         STRVS   R0,[SP]
         Pull    "R0-R6,R11,R12,PC"
;
;
;entry: R9 -> module node
;exit:  module removed from cmd hash table(s) as necessary
;
FreeCmdHashEntries ROUT
         Push    "R0-R7,R11,R12,LR"
         MRS     R7,CPSR
         LDR     R12,[R9,#Module_incarnation_list]
         CMP     R12,#0
         BNE     %FT90                             ;only do stuff if no incarnations
         LDR     R12,[R9,#Module_code_pointer]
         LDR     R11,=UtilityMod
         CMP     R12,R11
         BEQ     %FT90                             ;ignore UtilityModule (Oscli deals directly with it)
         LDR     R11,[R12,#Module_HC_Table]
         CMP     R11,#0
         BEQ     %FT90                             ;no commands
         ADD     R11,R12,R11                       ;R11 -> command table
         SUB     SP,SP,#8*4                        ;256-bit workspace for 256-wide hashing sieve
         MOV     R4,SP
         BL      CmdHashSieve
         ;now our sieve has a bit set for each hash value that this module occupies for commands
         LDR     R0,=ZeroPage
         LDR     R0,[R0,#Oscli_CmdHashLists]
         MOV     R6,#0
42
         AND     R2,R6,#&1F
         MOV     R3,#1
         MOV     R3,R3,LSL R2                      ;position in sieve word
         MOV     R5,R6,LSR #5                      ;sieve word index
         LDR     R1,[R4,R5,LSL #2]
         TST     R1,R3
         BEQ     %FT50                             ;module does not occupy this hash value
         LDR     R1,[R0,R6,LSL #2]                 ;pick up list for this hash value
         LDR     R2,[R1,#4]                        ;current no. of entries on list
         SUB     R2,R2,#1
         STR     R2,[R1,#4]
         ADD     R1,R1,#8                          ;scrunch list to remove module (R9)
         MOV     R3,R1
         CMP     R2,#0
         BEQ     %FT50
         ADD     R2,R2,#1
40
         LDR     R5,[R1],#4
         CMP     R5,R9
         STRNE   R5,[R3],#4
         SUBS    R2,R2,#1
         BNE     %BT40
50
         ADD     R6,R6,#1                          ;next hash value
         CMP     R6,#256
         BLO     %BT42
         ADD     SP,SP,#8*4                        ;drop sieve workspace
90
         MSR     CPSR_f,R7
         Pull    "R0-R7,R11,R12,PC"                ;MUST preserve flags
;
  ] ;Oscli_HashedCommands

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  [ ChocolateService

     LTORG

; must maintain service call chains, all attached to the 3 moorings in
; kernel workspace:
;
;   - Serv_SysChains holds a fixed array of chain anchors for the 'system'
;     service calls, in the range 1..ServMinUsrNumber
;   - Serv_UsrChains holds an array of hashed list headers, each header
;     holds an array of chains (open ended service number handling for
;     service numbers >= ServMinUsrNumber)
;   - Serv_AwkwardChain is a simple anchor for a single chain of non-compliant
;     modules (either old format, or new format without table) that do not
;     say what service calls they are interested in
;
;  The order of modules on the chains is just a convenient as-seen order, so
;  there will be subtle changes in the order of modules receiving service calls
;  compared to their order in the active module list. This only affects cases
;  where a service call may be claimed. Essentially, the new kernel does not
;  guarantee who gets a chance to claim first, but this was never defined
;  anyway.

;
;a service call chain is a block looking like this:
;  word 0 = current capacity (max entries*entry_size before block must grow)
;  word 1 = current size (current number of entries*entry_size)
;  - followed by an array of the current entries in the chain (cache friendly stuff)
;  - each entry is 3 words and looks like this:
;  word 0 = address of client service handler code
;  word 1 = workspace value for client service handler code
;  word 2 = R1 value for client (will be index for branch table), or 0 meaning pass service number
;
                         ^  0
ServChain_Capacity       #  4
ServChain_Size           #  4
ServChain_Entries        #  0
ServChain_HdrSIZEOF      #  0
;
                         ^  0
ServEntry_Code           #  4
ServEntry_WSpace         #  4
ServEntry_R1             #  4
ServEntry_SIZEOF         #  0
;

;Usr service numbers are those >= ServMinUsrNumber (see below)
;A Usr service array of chains is a block looking like this:
;  word 0 = current capacity max entries*entry_size before block must grow)
;  word 1 = current size (current number of entries*entry_size)
;  - followed by an array of the current entries in the array of chains
;  - each entry is 2 words and looks like this:
;  word 0 = service call number for chain
;  word 1 = anchor for chain (or 0 if no chain allocated)
;
                         ^  0
ServUChArray_Capacity    #  4
ServUChArray_Size        #  4
ServUChArray_Entries     #  0
ServUChArray_HdrSIZEOF   #  0
;
                         ^  0
ServUChEntry_ServiceNo   #  4
ServUChEntry_ChainAnchor #  4
ServUChEntry_SIZEOF      #  0


ServMinUsrNumber         * 256       ;'System' services in range 1..255, 'User' services >= 256
ServUsrHashSize          * 16        ; power of 2

ServMagicInstruction     * &E1A00000 ; (MOV R0,R0) indicates new module format with service table
ServIndexInR1            * 1         ; bit 0 of table flags word, if set, means pass index in R1
                                     ; to handler, rather than service number
                                     ; index corresponds directly to the position of the service
                                     ; number in the table, and starts at 1 (0 is reserved for service claim)

ServInitChainCapacity  * 4         ;no. of entries to start at for a chain block
ServBumpChainCapacity  * 4         ;no. of entries to grow by for a chain block


;hashing function for Usr service numbers is (number + (number>>8)) AND (hashsize-1)
;
        MACRO
        ServHashFunction $result,$service_number
        ADD    $result,$service_number,$service_number,LSR #8
        AND    $result,$result,#ServUsrHashSize-1
        MEND

;
;entry: [R1] -> chain block ([R1] = 0 if no block created yet)
;       R5 = Code for entry, R6 = WSpace for entry, R7 = R1 value for entry
;exit:  [R1] -> chain block (may have been created, or moved if had to grow)
;       V clear if done, V set and error if ran out of room
;
AddServChainEntry  ROUT
         Push    "R0-R4,LR"
         LDR     R2,[R1]            ;get pointer to chain block from anchor
         CMP     R2,#0
         BNE     %FT10
         MOV     R3,#ServChain_HdrSIZEOF + ServInitChainCapacity*ServEntry_SIZEOF
         Push    "R1"
         BL      ClaimSysHeapNode   ;need to create block
         Pull    "R1"
         BVS     %FT90
         STR     R2,[R1]
         MOV     R0,#ServInitChainCapacity*ServEntry_SIZEOF
         STR     R0,[R2,#ServChain_Capacity]
         MOV     R0,#0
         STR     R0,[R2,#ServChain_Size]
10
         LDR     R0,[R2,#ServChain_Size]
         LDR     R3,[R2,#ServChain_Capacity]
         CMP     R0,R3
         BLO     %FT20
         Push    "R0,R1"
         MOV     R3,#ServBumpChainCapacity*ServEntry_SIZEOF
         MOV     R0, #HeapReason_ExtendBlock
         BL      DoSysHeapOpWithExtension   ;need to grow block
         STRVS   R0,[SP]
         Pull    "R0,R1"
         BVS     %FT90
         STR     R2,[R1]
         LDR     R3,[R2,#ServChain_Capacity]
         ADD     R3,R3,#ServBumpChainCapacity*ServEntry_SIZEOF
         STR     R3,[R2,#ServChain_Capacity]
20
         ADD     R3,R2,#ServChain_HdrSIZEOF
         ADD     R3,R3,R0
         STR     R5,[R3,#ServEntry_Code]
         STR     R6,[R3,#ServEntry_WSpace]
         STR     R7,[R3,#ServEntry_R1]
         LDR     R3,[R2,#ServChain_Size]
         ADD     R3,R3,#ServEntry_SIZEOF
         STR     R3,[R2,#ServChain_Size]
90
         STRVS   R0,[SP]
         Pull    "R0-R4,PC"

;
;entry: R2 -> chain block, R5 = Code for entry to remove, R6 = WSpace for entry to remove
;exit:  registers preserved, entry removed and chain scrunched if entry was found
;
RemoveServChainEntry ROUT
         Push    "R0-R4,LR"
         CMP     R2,#0
         BEQ     %FT90
         LDR     R1,[R2,#ServChain_Size]
         CMP     R1,#0
         BEQ     %FT90
         ADD     R3,R2,#ServChain_HdrSIZEOF      ;start of chain
         ADD     R1,R1,R3                        ;end of chain
10
         LDR     R4,[R3,#ServEntry_Code]
         LDR     R0,[R3,#ServEntry_WSpace]
         TEQ     R4,R5
         TEQEQ   R0,R6
         BEQ     %FT20
         ADD     R3,R3,#ServEntry_SIZEOF
         CMP     R3,R1
         BLO     %BT10
         B       %FT90
20
         ADD     R3,R3,#ServEntry_SIZEOF        ;found, scrunch up rest of chain
         CMP     R3,R1
         BHS     %FT30
         LDR     R4,[R3,#ServEntry_Code]
         STR     R4,[R3,#ServEntry_Code - ServEntry_SIZEOF]
         LDR     R4,[R3,#ServEntry_WSpace]
         STR     R4,[R3,#ServEntry_WSpace - ServEntry_SIZEOF]
         LDR     R4,[R3,#ServEntry_R1]
         STR     R4,[R3,#ServEntry_R1 - ServEntry_SIZEOF]
         B       %BT20
30
         LDR     R1,[R2,#ServChain_Size]
         SUB     R1,R1,#ServEntry_SIZEOF
         STR     R1,[R2,#ServChain_Size]
90
         Pull    "R0-R4,PC"

;
;entry: R9 -> module node, R4 -> start of module, R5 -> service handler specified by module header
;exit:  R0 is -> table, or 0 if no table
;
FindServTable ROUT
        Push   "R1-R2,LR"
        MOV    R0,#0
        LDR    R1,[R5]
        LDR    R2,=ServMagicInstruction
        TEQ    R1,R2                    ;check for new format
        BNE    %FT90                    ;nope
        LDR    R0,[R5,#-4]              ;yes, so previous word is anchor (offset) for table
        CMP    R0,#0                    ;if anchor is 0, new format but no table specified
        ADDNE  R0,R0,R4                 ;else get address by adding module start to offset
90
        Pull   "R1-R2,PC"

;
;entry: R2 -> array of chains, R3 = service number, R5,R6,R7 = Code,WSpace,R1 for chain entry
;exit:  R0=1 if success,service number added to array if necessary, entry added to appropriate chain,
;       R0=0 if fail, because service number not yet in array, and array is full (grow not attempted)
;       or V set, error returned if no room (for chain extension)
;
AddServUsr_Hashed ROUT
        Push   "R1-R4,LR"
        ADD    R1,R2,#ServUChArray_HdrSIZEOF    ;chain start
        LDR    R0,[R2,#ServUChArray_Size]
        ADD    R0,R0,R1                         ;chain end
10
        CMP    R1,R0
        BHS    %FT20
        LDR    R4,[R1,#ServUChEntry_ServiceNo]
        TEQ    R4,R3
        ADDNE  R1,R1,#ServUChEntry_SIZEOF
        BNE    %BT10
;found entry for this service number in array
        ADD    R1,R1,#ServUChEntry_ChainAnchor  ;R1 is address of anchor for chain
        BL     AddServChainEntry
        MOVVC  R0,#1
        B      %FT90                            ;succeeded (or OS error because no room)
;
20
;entry for this service number not found, add it if array has room
        LDR    R0,[R2,#ServUChArray_Capacity]
        LDR    R4,[R2,#ServUChArray_Size]
        CMP    R4,R0
        MOVHS  R0,#0
        BHS    %FT90                             ;failed (array needs extension)
        STR    R3,[R1,#ServUChEntry_ServiceNo]   ;add entry at end of current list
        MOV    R4,#0
        STR    R4,[R1,#ServUChEntry_ChainAnchor] ;no chain yet
        LDR    R4,[R2,#ServUChArray_Size]
        ADD    R4,R4,#ServUChEntry_SIZEOF
        STR    R4,[R2,#ServUChArray_Size]
        ADD    R1,R1,#ServUChEntry_ChainAnchor   ;R1 is address of anchor for chain
        BL     AddServChainEntry
        MOVVC  R0,#1
90
        Pull   "R1-R4,PC"

;
;entry: R2 -> hash header array, R3 = service number, R5,R6,R7 = Code,WSpace,R1 for chain entry
;exit:  service number added to array on appropriate hash list if necessary, entry added to appropriate chain,
;       or V set, error returned if no room (for either chain or chain array extension)
;
AddServUsr ROUT
        Push   "R0-R4,LR"
        ServHashFunction R4,R3          ;result in R4
        ADD    R1,R2,R4,LSL #2          ;R1 -> entry for this service number in hash header array
        LDR    R2,[R1]                  ;pick up anchor for array of chains
        CMP    R2,#0
        BNE    %FT10
;must create array of chains
        Push   "R1,R3"
        MOV    R3,#ServUChArray_HdrSIZEOF + 4*ServUChEntry_SIZEOF  ;initially room for 4 entries
        BL     ClaimSysHeapNode
        Pull   "R1,R3"
        BVS    %FT90
        STR    R2,[R1]
        MOV    R0,#4*ServUChEntry_SIZEOF
        STR    R0,[R2,#ServUChArray_Capacity]
        MOV    R0,#0
        STR    R0,[R2,#ServUChArray_Size]
10
        BL     AddServUsr_Hashed
        BVS    %FT90
        CMP    R0,#1
        BEQ    %FT90                          ;add succeeded, done
;add failed, so we need to grow the array of chains
        Push   "R1,R3"
        MOV    R3,#4*ServUChEntry_SIZEOF      ;bump up capacity by 4 entries
        MOV    R0, #HeapReason_ExtendBlock
        BL     DoSysHeapOpWithExtension
        Pull   "R1,R3"
        BVS    %FT90
        STR    R2,[R1]
        LDR    R0,[R2,#ServUChArray_Capacity]
        ADD    R0,R0,#4*ServUChEntry_SIZEOF
        STR    R0,[R2,#ServUChArray_Capacity]
;now we can do the add and it cannot fail
        BL     AddServUsr_Hashed
90
        STRVS  R0,[SP]
        Pull   "R0-R4,PC"

;
;entry: R3 = service number, R5,R6,R7 = Code,WSpace,R1 for chain entry
;exit:  registers preserved, entry added to appropriate chain,
;       or V set, error returned if no room
;
AddServSysOrUsr ROUT
        Push   "R0-R4,LR"
        CMP    R3,#ServMinUsrNumber
        BHS    %FT50
        LDR    R1,=ZeroPage+Serv_SysChains
        LDR    R2,[R1]
        CMP    R2,#0
        BNE    %FT30
;need to create array of service chain anchors, for service codes 0 to ServMinUserNumber-1
;(0 is not used, because reserved for service cliamed, but done for convenience)
        Push   "R1,R3"
        MOV    R3,#ServMinUsrNumber*4
        BL     ClaimSysHeapNode
        Pull   "R1,R3"
        BVS    %FT90
        STR    R2,[R1]
        MOV    R0,#0
        MOV    LR,#ServMinUsrNumber
        MOV    R4,R2
10
        STR    R0,[R4],#4             ;zero the anchors (no chains yet)
        SUBS   LR,LR,#1
        BNE    %BT10
30
        ADD    R1,R2,R3,LSL #2        ;address of anchor for this Sys service number
        BL     AddServChainEntry      ;add to chain
        B      %FT90
;
50
        LDR    R1,=ZeroPage+Serv_UsrChains
        LDR    R2,[R1]
        CMP    R2,#0
        BNE    %FT70
;need to create array of hash headers for Usr chain arrays
        Push   "R1,R3"
        MOV    R3,#ServUsrHashSize*4
        BL     ClaimSysHeapNode
        Pull   "R1,R3"
        BVS    %FT90
        STR    R2,[R1]
        MOV    R0,#0
        MOV    LR,#ServUsrHashSize
        MOV    R4,R2
60
        STR    R0,[R4],#4             ;zero the hash headers
        SUBS   LR,LR,#1
        BNE    %BT60
70
        BL     AddServUsr
90
        STRVS  R0,[SP]
        Pull   "R0-R4,PC"

;
;entry: R9 -> module node, R12 -> incarnation node
;exit:  module incarnation added onto service call chains as necessary
;       OR V set, error returned if no room
;
; IRQs are disabled during update to make sure service distribution does not happen
; under interrupt, with possibly incomplete chains still under construction. A little
; worrying that this may mean interrupts are sometimes off for a while, but there you go.
;
AddToServiceChains ROUT
        Push   "R0-R8,LR"
        MRS    R8,CPSR
        ORR    R4,R8,#I32_bit
        MSR    CPSR_c,R4                     ;IRQs off for update of chain structures
        LDR    R4,[R9,#Module_code_pointer]  ;start of module
        LDR    R5,[R4,#Module_Service]
        CMP    R5,#0
        BEQ    %FT90
        ADD    R5,R5,R4
        ADD    R6,R12,#Incarnation_Workspace
        BL     FindServTable
        CMP    R0,#0
        BEQ    %FT50
        LDR    R1,[R0],#4            ;flags word from table
        LDR    R5,[R0],#4            ;handler code offset from table
        ADD    R5,R5,R4              ;handler code address
        MOV    R2,#0
10
        ADD    R2,R2,#1              ;next index in table (start at 1)
        LDR    R3,[R0],#4            ;next service call number from table
        CMP    R3,#0                 ;table terminated by 0
        BEQ    %FT90
        TST    R1,#ServIndexInR1
        MOVNE  R7,R2                 ;we must pass index to handler
        MOVEQ  R7,#0                 ;we must pass service number
        BL     AddServSysOrUsr
        BVS    %FT90
        B      %BT10
;
50      ;awkward customer, with no service table
        MOV    R7,#0                 ;must pass service number to handler (there is no index)
        LDR    R1,=ZeroPage+Serv_AwkwardChain
        BL     AddServChainEntry
90
        STRVS  R0,[SP]
        MSR    CPSR_c,R8             ;restore IRQ state (26-bit code used to corrupt V!)
        Pull   "R0-R8,PC"

;
;entry: R9 -> module node, R12 -> incarnation node
;exit:  module incarnation removed from service call chains as necessary
;       flags preserved
;
; IRQs are disabled during update to make sure service distribution does not happen
; under interrupt, with possibly incomplete chains still under construction. A little
; worrying that this may mean interrupts are sometimes off for a while, but there you go.
;
RemoveFromServiceChains ROUT
        Push   "R0-R8,R10,LR"
        MRS    R10,CPSR
        ORR    R4,R10,#I32_bit
        MSR    CPSR_c,R4                     ;IRQs off for update of chain structures
        LDR    R4,[R9,#Module_code_pointer]
        LDR    R5,[R4,#Module_Service]
        CMP    R5,#0
        BEQ    %FT90
        ADD    R5,R5,R4
        ADD    R6,R12,#Incarnation_Workspace
        BL     FindServTable
        CMP    R0,#0
        BEQ    %FT50
        LDR    R1,[R0],#4            ;flags word from table
        LDR    R5,[R0],#4            ;handler code offset from table
        ADD    R5,R5,R4              ;handler code address
10
        LDR    R3,[R0],#4            ;next service call number from table
        CMP    R3,#0                 ;table terminated by 0
        BEQ    %FT90
        CMP    R3,#ServMinUsrNumber
        BHS    %FT20
        LDR    R1,=ZeroPage+Serv_SysChains
        LDR    R1,[R1]
        CMP    R1,#0
        BEQ    %BT10
        ADD    R1,R1,R3,LSL #2
        LDR    R2,[R1]               ;pick up anchor for Sys chain
        BL     RemoveServChainEntry
        B      %BT10
;
20
        ServHashFunction R4,R3       ;result in R4
        LDR    R1,=ZeroPage+Serv_UsrChains
        LDR    R1,[R1]
        CMP    R1,#0
        BEQ    %BT10
        LDR    R1,[R1,R4,LSL #2]     ;pick up anchor for array of chains
        CMP    R1,#0
        BEQ    %BT10
        LDR    R8,[R1,#ServUChArray_Size]
        ADD    R4,R1,#ServUChArray_HdrSIZEOF  ;chain start
        ADD    R8,R8,R4                       ;chain end
30
        CMP    R4,R8
        BHS    %BT10
        LDR    LR,[R4,#ServUChEntry_ServiceNo]
        TEQ    LR,R3
        ADDNE  R4,R4,#ServUChEntry_SIZEOF
        BNE    %BT30
        LDR    R2,[R4,#ServUChEntry_ChainAnchor]
        BL     RemoveServChainEntry
        B      %BT10
;
50
        LDR    R1,=ZeroPage+Serv_AwkwardChain
        CMP    R1,#0
        BEQ    %FT90
        LDR    R2,[R1]
        BL     RemoveServChainEntry
90
        MSR    CPSR_cf,R10                ;restore IRQ state
        Pull   "R0-R8,R10,PC"             ;MUST preserve flags

  ] ;ChocolateService

        LTORG

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

FreeIncarnation  ROUT
  ; copy error, free any workspace, incarnation link.
  ;   R12 incarnation pointer, R9 module node pointer
         Push   "R0-R2,R5,lr"
         MRS     R5, CPSR
         BL      Module_CopyError
         STR     R0, [stack]
         LDR     R2, [R12, #Incarnation_Workspace]
         CMP     R2, #0
         MOV     R0, #HeapReason_Free
         MOV     R1, #RMAAddress
         SWINE   XOS_Heap
  [ ModHand_IntrinsicBI
         SUB     R2, R12, R9
         CMP     R2, #ModInfo
         BEQ     FreeIncarnation_Exit   ;if equal, this is the intrinsic incarnation 'node'
  ]
         MOV     R2, R12
         BL      FreeSysHeapNode
FreeIncarnation_Exit
         MSR     CPSR_f, R5
         Pull   "R0-R2,R5,PC"

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; KillAndFree:
;      R0 -> module
;      R2 -> prevmodule
;  Kills all incarnations, frees all space.

KillAndFree      ROUT
         Push   "R2, R3, R9, R12, lr"
         MOV     R9, R0
         ADDS    R3, R9, #Module_incarnation_list  ; ensure V clear
01       LDR     R12, [R9, #Module_incarnation_list]
         BL      KillIncarnation
         Pull   "R2, R3, R9, R12, PC", VS
         CMP     R9, #0
         BNE     %BT01                      ; more incarnations yet
         Pull   "R2, R3, R9, R12, PC"

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; KillIncarnation
;     R9  module ptr
;     R12 incarnation ptr
;     R3  previous incarnation
;     R2  previous module
; Exit: R9 zeroed if module completely gone
;
KillIncarnation  ROUT
         Push   "R0-R2, R6, R10, lr"
         MRS     R6, CPSR
         MOV     R10, #1                     ; fatal die
         CMP     r12, #0                     ; fudge for 0 incarnations:
         BLNE    CallDie                     ; tidy up anyway
         STRVS   R0, [stack]
         Pull   "R0-R2, R6, R10, PC", VS
       [ ModHand_InitDieServices
         BL      IssueServicePostFinal
       ]
  [ ModHand_IntrinsicBI
         SUB     R2, R12, R9
         CMP     R2, #ModInfo
         BEQ     %FT01         ;if equal, this is the intrinsic incarnation 'node'
  ]
         MOV     R2, R12
         BL      FreeSysHeapNode                ; free incarnation node
01       LDR     R0, [R9, #Module_incarnation_list]
         CMP     R0, #0                      ; last incarnation?
         LDREQ   R2, [stack, #2*4]
         BLEQ    DelinkAndFreeModule
         MOVEQ   R9, #0
         MSR     CPSR_f, R6
         Pull   "R0-R2, R6, R10, PC"

LoseModuleSpace_if_its_the_only_incarnation
         Push   "R0-R2, R6, R10, lr"
         MRS     R6, CPSR
         B       %BT01

;*************************************************************
; CallDie
;    take R9  -> module node
;         R12 -> incarnation node
;         R3  -> previous incarnation
;         R10 =  fatality
; check against CAO
; delink incarnation, issue die, deal with workspace.

CallDie ROUT
         Push   "R0-R7, R11, R12, lr"
         MRS     R7, CPSR

         LDR     R11, =ZeroPage
         LDR     R11, [R11, #Curr_Active_Object]

 ; check killability

         LDR     R0,  [R9, #Module_code_pointer]
         BL      %FT10                        ; is_CAO?
         BLO     %FT04                        ; code block is CAO

 ; check if workspace block could be CAO: may have handler in there

         LDR     R0, [R12, #Incarnation_Workspace]
         BL      %FT20                        ; check block before getting size
         BVS     ModuleIsntCAO                ; not heap block - we don't
         BL      %FT10                        ; know what's going on.
         BHS     ModuleIsntCAO                ; not CAO

04       CMP     R10, #0                      ; fatal?
         BNE     CantKill
         LDR     R0, [R12, #Incarnation_Workspace]
         BL      %FT20
         BVS     ModuleIsntCAO                ; soft die of non-heap module OK
CantKill
         ADR     R0, ErrorBlock_CantKill
       [ International
         BL      TranslateError
       ]
01       STR     R0, [stack]
         LDR     R3, [stack, #4*3]
         LDR     R12, [stack, #4*(7+2)]
         STR     R12, [R3, #Incarnation_Link] ; relink
         ORR     R7, R7, #V_bit
         MSR     CPSR_f, R7
         Pull   "R0-R7, R11, R12, PC"
         MakeErrorBlock CantKill

ModuleIsntCAO
         MOV     R11, #0                     ; set R11 to incarnation number.
         LDR     R0, [R9, #Module_incarnation_list]
03       CMP     R0, R12
         ADDNE   R11, R11, #1
         LDRNE   R0, [R0, #Incarnation_Link]
         BNE     %BT03

  [ ChocolateService
         ;remove from service chains now, as part of delink
         BL      RemoveFromServiceChains
  ]
         LDR     R0, [R12, #Incarnation_Link]
         STR     R0, [R3, #Incarnation_Link] ; delink
         ADD     R12, R12, #Incarnation_Workspace
         LDR     R1, [R9, #Module_code_pointer]
         LDR     R0, [R1, #Module_Die]
         BIC     R0, R0, #&80000000          ; knock out invincibility bit
         CMP     R0, #0                      ; WARNING: don't try to combine these 2 instructions in a BICS - it wouldn't clear V
         MOV     lr, PC
         ADDNE   PC, R1, R0                  ; call.
  [ ChocolateService
         BVC     HaveKilled
         ;add back to service chains as part of relink (cant error through lack of memory, since we had room before delink)
         LDR     R12, [stack, #4*(7+2)]
         BL      AddToServiceChains
         B       %BT01
HaveKilled
  |
         BVS     %BT01
  ]
  [ Oscli_HashedCommands
         BL      FreeCmdHashEntries
  ]
         BL      FreeSWIEntry

         CMP     R10, #0                     ; soft die?
         BEQ     %FT02

         LDR     R12, [stack, #4*(7+2)]
         LDR     R2, [R12, #Incarnation_Workspace]
         CMP     R2, #0
         MOVNE   R1, #RMAAddress
         MOVNE   R0, #HeapReason_Free
         SWINE   XOS_Heap
         MOV     R0, #0
         STR     R0, [R12, #Incarnation_Workspace]   ; orgone
02
         BIC     R7, R7, #V_bit
         MSR     CPSR_f, R7
         Pull   "R0-R7, R11, R12, PC"

; check if block @ R0 contains address R11
10       LDR     R1, [R0, #-4]
         ADD     R1, R1, R0
         CMP     R0, R11
         CMPLS   R11, R1
         MOV     PC, lr                      ; return LO for Yes

; check block @ R0 is a valid RMA heap block
20
         Push   "R0-R3, lr"
         MOV     R2, R0
         MOV     R0, #HeapReason_ExtendBlock
         MOV     R1, #RMAAddress
         MOV     R3, #0
         SWI     XOS_Heap
         Pull   "R0-R3, PC"                 ; V set if not.

;*************************************************************
; DelinkAndFreeModule
;       R9 -> Module
;       R2 -> prevmodule

DelinkAndFreeModule ROUT
        Push    "R0-R2,R5,lr"
        MRS     R5, CPSR

;   loop here to find predecessor; make death re-entrant
        LDR     R0, =ZeroPage+Module_List
01
        LDR     R1, [R0, #Module_chain_Link]
        CMP     R1, R9
        MOVNE   R0, R1
        BNE     %BT01

        LDR     R1, [R9, #Module_chain_Link]
        STR     R1, [R0, #Module_chain_Link] ; delinked

        LDR     R2, [R9, #Module_code_pointer]
        MOV     R1, #RMAAddress
        MOV     R0, #HeapReason_Free
        SWI     XOS_Heap

        MOV     R2, R9
  [ ChocolateSysHeap
        ASSERT  ChocolateMABlocks = ChocolateBlockArrays + 16
        LDR     r1,=ZeroPage+ChocolateBlockArrays
        LDR     r1,[r1,#16]
        BL      FreeChocolateBlock
        BLVS    FreeSysHeapNode
  |
        BL      FreeSysHeapNode
  ]

        MSR     CPSR_f, R5
        Pull   "R0-R2,R5,PC"

;*************************************************************************
;  common lookup for reinit, enter, die
;
; Exits with EQ if incarnation not specified, NE if incarnation specified
; and found.

lookup_commoned ROUT
       Push    "lr"
       WritePSRc SVC_mode, lr               ; we will exit with IRQs enabled
       BL       LookUp_Module               ; node ptr in R0
       BEQ      %FT01                       ; not found
       CMP      R12, #-1
       BEQ      %FT02                       ; incarnation not found
       CMP      R12, #0
       MOV      R9, R0
       Pull    "PC"
01
       ADR      R0, ErrorBlock_RMNotFound
       Push    "r1-r6"
       LDR      r3, =ZeroPage
       LDR      r3, [r3, #IRQsema]
       CMP      r3, #0
       BNE      %FT03
     [ International
       MOV      R4, R1
       BL       TranslateError_UseR4
       Push     "r0"
     |
       BL       GetOscliBuffer
       Push     r5
       LDR      r2, [r0], #4
       STR      r2, [r5], #4
       BL       rmecopystr
copynfrmname
       LDRB     r2, [r1], #1
       CMP      r2, #32
       STRGTB   r2, [r5], #1
       BGT      copynfrmname

       BL       rmecopystr
       STRB     r2, [r5]                   ; terminate
     ]
       Pull    "r0-r6"


03
       SETV
       Pull    "PC"
       MakeErrorBlock  RMNotFound
02
       ADR      R0, ErrorBlock_IncarnationNotFound
     [ International
       BL      TranslateError
     ]
       B        %BT03
       MakeErrorBlock  IncarnationNotFound

MakeNotFoundError                         ; r1 -> module name
       Push     lr
       B        %BT01

;*************************************************************
; Lookup_Module
; Entry:  R1  -> module name
; Exit:   R0  -> module chain node   (0 for not found)
;         R1  -> postfix of name
;         R12 -> incarnation node    (0 for not specified, -1 for not found)
;         R2  -> previous module      for potential delinking
;         R3  -> previous incarnation  "      "         "
;         NE for found/EQ for not


LookUp_Module ROUT
         Push   "R4, R5, lr"

         WritePSRc SVC_mode, R2              ; interrupts on
         LDR     R2, =ZeroPage+Module_List
01       LDR     R0, [R2, #Module_chain_Link]
         CMP     R0, #0
         Pull   "R4, R5, PC", EQ             ; return if not found
         LDR     R4, [R0, #Module_code_pointer]
         LDR     R3, [R4, #Module_TitleStr]
         ADD     R3, R3, R4                  ; got ptr to title
         MOV     R4, #Postfix_Separator      ; allowed terminator for StrCmp
         BL      Module_StrCmp               ; compare with abbreviation.
         MOVNE   R2, R0
         BNE     %BT01                       ; loop if not found
         LDRB    R4, [R1], #1                ; get terminator
         CMP     R4, #Postfix_Separator
         BEQ     %FT02

   ; now a quick fudge to spot recursive ModHand calls during module death.
         LDR     R12, [R0, #Module_incarnation_list]
         CMP     R12, #0
         MOVEQ   R12, #-1                    ; no incarnations!
         MOVNE   R12, #0                     ; no postfix/incarnation specified
         CMP     PC, #0
         Pull   "R4, R5, PC"                 ; back with NE

02       LDRB    R4, [R1]
         CMP     R4, #" "
         BGT     %FT03
         CMP     R1, R1                      ; force EQ
         Pull   "R4, R5, PC"                 ; not found: naff postfix
03
         Push   "R1"                         ; updated value to return
         BL      FindIncarnation
         MOVEQ   R12, #-1                    ; failed to find postfix.
         CMP     PC, #0                      ; force NE
         Pull   "R1, R4, R5, PC"             ; back with NE

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; FindIncarnation
;    R0 is node pointer, need to loop to find incarnation ($R1)
;    Return EQ if not found,
;           NE => R12 -> incarnation, R3 -> previnc

FindIncarnation  ROUT
         Push   "lr"
         ADD     R3, R0, #Module_incarnation_list  ; previnc
03       LDR     R12, [R3, #Incarnation_Link]
         CMP     R12, #0
         Pull   "PC", EQ                     ; failed to find postfix.
         Push   "R3,R4"
         ADD     R3, R12, #Incarnation_Postfix
         MOV     R4, #0                      ; no special terminator
         BL      Module_StrCmp
         Pull   "R3,R4"
         MOVNE   R3, R12
         BNE     %BT03
         CMP     PC, #0                      ; force NE
         Pull   "PC"

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       Module_StrCmp
;
; Do a string comparison, given pointers in R1, R3.
; Ignore case, allow $R1 to be an abbreviation of $R3
; Strings are terminated by ctrl-char, or ASC(R4) for $R1
;
; out:  EQ => match found, R1 -> terminator of R1 string
;       NE => match not found, R1 preserved
;       R3 corrupted in all cases
;

Module_StrCmp Entry "r1,r2,r5-r7"
        MOV     r2, #0
01
        LDRB    r7, [r1], #1
        LDRB    r5, [r3], #1
        CMP     r7, r4
        CMPNE   r7, #32
        CMPLE   r5, #32
        BLE     %FT02
        UpperCase r7, r6
        UpperCase r5, r6
        CMP     r7, r5
        ADDEQ   r2, r2, #1
        BEQ     %BT01
        CMP     r2, #0
        TOGPSR  Z_bit, r2                       ; invert EQ/NE
        CMPEQ   r7, #"."                        ; success if abbreviation
        EXIT    NE
        CMP     r5, #" "                        ; reject abbreviation
        EXIT    LT                              ; after full match
        ADD     r1, r1, #1
02
        SUB     r1, r1, #1
        CMP     r2, #0                          ; reject 0-length match
        TOGPSR  Z_bit, r2                       ; invert EQ/NE
        STREQ   r1, [stack]                     ; r1 -> terminator
        EXIT                                    ; return with success

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

EnvStringSkipName ROUT
         Push   "R0"
01       LDRB    R0, [R10], #1
         CMP     R0, #" "
         BGT     %BT01
02       LDREQB  R0, [R10], #1
         CMP     R0, #" "
         BEQ     %BT02
         SUB     R10, R10, #1
         Pull   "R0"
         MOV     PC, lr

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; PreferIncarnation
;    R9  -> module node
;    R12 -> incarnation node
;    R3  -> previous incarnation
PreferIncarnation
         Push   "R0"
         LDR     R0,  [R12, #Incarnation_Link]
         STR     R0,  [R3,  #Incarnation_Link]
         LDR     R0,  [R9,  #Module_incarnation_list]
         STR     R0,  [R12, #Incarnation_Link]
         STR     R12, [R9,  #Module_incarnation_list]
         Pull   "R0"
         MOV     PC, R14

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Module_CopyError ROUT
; grab an oscli buffer for the error,
; rather than having a permanent module buffer
       Push     "R0, R2, R5, R6, lr"
       BL        GetOscliBuffer

       STR       R5, [stack]
       LDR       R2, [R0], #4
       STR       R2, [R5], #4
01     LDRB      R2, [R0], #1
       STRB      R2, [R5], #1
       CMP       R2, #0
       BNE       %BT01
       Pull     "R0, R2, R5, R6, PC"

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;  Claim chunk from RMA : increase RMA if can,
;  force size to multiple of 32 -4 to keep alignment OK

RMAClaim_Chunk   ROUT
         MOV     R0, #HeapReason_Get
         Push   "R0, R3, lr"

         ADD     R3, R3, #31+4               ; now force size to 32*n-4
         BIC     R3, R3, #31                 ; so heap manager always has
         SUB     R3, R3, #4                  ;  8-word aligned blocks

         B       IntoRMAHeapOp

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DoRMAHeapOpWithExtension
         Push   "R0, R3, lr"

IntoRMAHeapOp
         MOV     R1, #RMAAddress
         SWI     XOS_Heap
         Pull   "R0, R3, PC", VC

         LDR     r14, [r0]                   ; look at error number
         TEQ     r14, #ErrorNumber_HeapFail_Alloc
         STRNE   r0, [stack]
         Pull   "r0, r3, PC", NE            ; can only retry if ran out of room

         Push    r3                         ; in case extension
         LDR     r1, [stack, #4]
         CMP     r1, #HeapReason_ExtendBlock
         BNE     notRMAextendblock
         Push   "r5, r6"
         LDR     r1, [r2, #-4]               ; pick up block size
         ADD     r5, r1, r2                  ; block end +4
         SUB     r5, r5, #4                  ; TMD 02-Aug-93: block size includes size field (optimisation was never taken)
         MOV     r6, #RMAAddress
         LDR     r6, [r6, #:INDEX:hpdbase]
         ADD     r6, r6, #RMAAddress         ; free space
         CMP     r5, r6                      ; does block butt against end?
         ADDNE   r3, r3, r1                  ; max poss size needed
         Pull   "r5, r6"

  ; note that this doesn't cope well with a block at the end preceded by a
  ; free block, but tough.

notRMAextendblock
         MOV     r1, #RMAAddress
         LDR     R0, [R1, #:INDEX: hpdbase]
         LDR     R1, [R1, #:INDEX: hpdend]
         SUB     R1, R1, R0                  ; bytes free
         SUB     R1, R3, R1                  ; bytes needed

         Pull    r3
         ADD     R1, R1, #8                  ; safety factor

         MOV     R0, #1                      ; try and expand RMA.
         SWI     XOS_ChangeDynamicArea
         Pull   "R0"                         ; heap reason code back
         MOV     R1, #RMAAddress
         SWIVC   XOS_Heap
01
         ADRVSL  R0, ErrorBlock_MHNoRoom
       [ International
         Push   "LR",VS
         BLVS    TranslateError
         Pull   "LR",VS
       ]
         Pull   "r3, PC"

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Data

crstring =       13
         ALIGN

;*****************************************************************************
; *Unplug code.

Unplug_Code Entry "r7-r9"
        CMP     r1, #0
        BNE     ZapTheModule

; If name not given, list unplugged modules

;       MOV     r1, #0                          ; start with module 0 (r1 is already zero indicating no parameters to command!)
        MOV     r2, #-1                         ; start with main ROMs
        MOV     r7, #0                          ; flag indicating whether we've had any unplugged modules already
10
        MOV     r0, #ModHandReason_EnumerateROM_ModulesWithInfo
        SWI     XOS_Module
        BVS     %FT30                           ; no more, so finish off
        CMP     r4, #-1                         ; is it unplugged?
        BNE     %BT10                           ; no, then go for another one

        MOV     r8, r1                          ; save module and podule numbers
        MOV     r9, r2
        TEQ     r7, #0                          ; if already printed header message
        BNE     %FT20                           ; then skip
      [ International
        BL      WriteS_Translated
        =       "Unp:Unplugged modules are:", 10, 13, 0
        ALIGN
      |
        ADR     r0, AreUnpluggedMessage
        SWI     XOS_Write0
      ]
        EXIT    VS
        MOV     r7, #1
20
        MOV     r0, r3
        SWI     XOS_Write0
        EXIT    VS
        CMP     r2, #-1
        BEQ     %FT25                           ; if a main ROM, then no blurb after name (and V=0)
      [ International
        MOV     r4, r2
      |
        ADRGT   r4, podbra                      ; is a podule module
        ADRLT   r4, extnbra                     ; is an extn rom module
      ]
        MVNLT   r2, r2                          ; so invert number
        SUB     r0, r0, r3                      ; length of module name
        RSB     r0, r0, #24                     ; number of spaces to pad out to column 24 (may be -ve)
21
        SWI     XOS_WriteI + " "                ; always print at least one space
        EXIT    VS
        SUBS    r0, r0, #1
        BGT     %BT21
      [ :LNOT: International
        MOV     r0, r4
        SWI     XOS_Write0
        EXIT    VS
      ]
        SUB     sp, sp, #3*4                    ; make buffer on stack
        MOV     r0, r2
        MOV     r1, sp
        MOV     r2, #3*4
        SWI     XOS_ConvertCardinal4
      [ International
        CMP     r4,#-1
        MOV     r4,r0                           ; r4 -> number
        BLT     %FT23
        BL      WriteS_Translated_UseR4
        =       "Podule:(Podule %0)",0
        ALIGN
        B       %FT24
23
        BL      WriteS_Translated_UseR4
        =       "Extn:(Extn ROM  %0)",0
        ALIGN
24
        ADD     sp, sp, #3*4                    ; restore stack
      |
        SWIVC   XOS_Write0
        ADD     sp, sp, #3*4                    ; restore stack
        SWIVC   XOS_WriteI + ")"
      ]
25
        SWIVC   XOS_NewLine
        MOVVC   r1, r8                          ; restore module and podule number
        MOVVC   r2, r9
        BVC     %BT10
        EXIT

30
        CMP     r7, #0                          ; NB will clear V in any case
      [ International
        BNE     %FT31
        BL      WriteS_Translated
        =       "NoUnp:No modules are unplugged", 10, 13, 0
        ALIGN
31
        EXIT
      |
        ADREQ   r0, NoUnpluggedMessage
        SWIEQ   XOS_Write0
        EXIT                                    ; exit with V=0 unless error in Write0

AreUnpluggedMessage
        =       "Unplugged modules are:", 10, 13, 0
NoUnpluggedMessage
        =       "No modules are unplugged", 10, 13, 0
podbra
        =       "("
rommposp
        =       "Podule ", 0
extnbra
        =       "("
rommposer
        =       "Extn ROM ", 0
        ALIGN
      ]

ZapTheModule
        MOV     r9, #0                          ; indicate unplug, not insert
UnplugInsertEntry
        MOV     r12, #0                         ; search from start of chain
        MOV     r7, r0                          ; name pointer
        MOV     r4, #0                          ; no extra terminator
        MOV     r5, #0                          ; indicate no versions found yet

        MOV     r6, #0                          ; indicate no version found that was initialised
        MOV     r1, r7
        BL      SkipToSpace                     ; leaves r1 pointing to 1st space or control char
        BL      SkipSpaces                      ; leaves r1 -> 1st non-space, r0 = 1st non-space char
        CMP     r0, #&7F
        CMPNE   r0, #" "                        ; if a ctrl char, then
        MOVLS   r8, #&80000000                  ; indicate to unplug all versions
        BLS     %FT40
        CMP     r0, #"-"
        ADDEQ   r1, r1, #1
        MOVEQ   r8, #-1
        MOVNE   r8, #1
        MOV     r0, #1 :SHL: 31                 ; check terminator is control char or space
        SWI     XOS_ReadUnsigned
        EXIT    VS
        MUL     r8, r2, r8                      ; apply sign
40
        MOV     r1, r7
        BL      FindROMModule
        TEQ     r12, #0
        BEQ     %FT60                           ; no versions of this module found, so report error

42
        LDR     r14, [r12, #ROMModule_OlderVersion]     ; find oldest version of this module
        TEQ     r14, #0
        MOVNE   r12, r14
        BNE     %BT42

45
        TEQ     r8, #&80000000                  ; if not doing any old podule
        LDRNE   r14, [r12, #ROMModule_PoduleNumber]
        TEQNE   r14, r8                         ; and podule number doesn't match
        BNE     %FT50                           ; then skip this one

        LDRB    r14, [r12, #ROMModule_Initialised] ; if this version of CODE was initialised then keep pointer to it
        TEQ     r14, #0
        MOVNE   r6, r12                         ; save pointer to it
        MOV     r5, #&FF                        ; set up byte mask (and indicate found)
        LDR     r1, [r12, #ROMModule_CMOSAddrMask]
        AND     r3, r5, r1, LSR #16             ; get bit mask
        ANDS    r1, r1, r5
        BEQ     %FT50                           ; if no CMOS, then look for another module
        MOV     r0, #ReadCMOS
        SWI     XOS_Byte
        EXIT    VS
        TEQ     r9, #0
        ORREQ   r2, r2, r3                      ; set unplug bit
        BICNE   r2, r2, r3                      ; or clear it as appropriate
        MOV     r0, #WriteCMOS
        SWI     XOS_Byte
        EXIT    VS
50
        LDR     r14, [r12, #ROMModule_NewerVersion] ; go to next newer version
        TEQ     r14, #0
        MOVNE   r12, r14
        BNE     %BT45

60
        TEQ     r5, #0                          ; if we've seen any versions, then don't report error
        BNE     %FT70
        ADR     r0, ErrorBlock_RMNotFoundInROM
      [ International
        BL      TranslateError
      |
        SETV
      ]
        EXIT

70
        CMP     r9, #1                          ; if doing unplug not insert
        CMPNE   r6, #0                          ; and we found a match on an initialised version (else V=0)
 [ 1 = 1
;RCM's fix for MED-04173
        EXIT    EQ

; see if module is active, by checking for module in module list
        LDR     r0, =ZeroPage+Module_List
60
        LDR     r0, [r0, #Module_chain_Link]
        TEQ     r0, #0                          ; module not active
        BEQ     %FT90
        LDR     r1, [r0, #Module_ROMModuleNode] ; get active module's pointer to ROM module node
        TEQ     r1, r12                         ; if it matches
        BNE     %BT60

        MOV     r0, #ModHandReason_Delete       ; then tell him he's dead
        LDR     r1, [r6, #ROMModule_Name]
        SWI     XOS_Module
90
 |
        MOVNE   r0, #ModHandReason_Delete       ; then tell him he's dead
        LDRNE   r1, [r6, #ROMModule_Name]
        SWINE   XOS_Module
 ]
        EXIT

RMInsert_Code ALTENTRY
        MOV     r9, #1                          ; indicate insert, not unplug
        B       UnplugInsertEntry

        MakeErrorBlock RMNotFoundInROM

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ ModHand_InitDieServices
; IssueServicePostInit
; On entry
;  R9  -> module chain node
;  R12 -> incarnation node
; On exit
;  R0-R3 corrupted
;  flags preserved

IssueServicePostInit
        Push    "R4-R5, lr"
        MRS     R5, CPSR

        ASSERT  ModHand_IntrinsicBI     ; can't be bothered to support old world

        LDR     R2, [R9, #Module_code_pointer]
        LDR     R0, [R2, #Module_HelpStr]
        ADD     R0, R2, R0
        BL      GetVerNoFromHelpString
        MOV     R0, R2
        LDR     R2, [R0, #Module_TitleStr]
        ADD     R2, R0, R2
        MOV     R4, R1
        MOV     R1, #Service_ModulePostInit
        SUB     R3, R12, R9
        SUBS    R3, R3, #ModInfo        ; R3 = 0 if intrinsic base incarnation
        ADDNE   R3, R12, #Incarnation_Postfix
        SWI     XOS_ServiceCall

        MSR     CPSR_f, R5
        Pull    "R4-R5, pc"

; IssueServicePostFinal
; On entry
;  R9  -> module chain node
;  R12 -> incarnation node (incarnation workspace is already freed)
; On exit
;  R0 corrupted
;  flags corrupted

IssueServicePostFinal
        Push    "R1-R4, lr"

        ASSERT  ModHand_IntrinsicBI     ; can't be bothered to support old world

        LDR     R2, [R9, #Module_code_pointer]
        LDR     R0, [R2, #Module_HelpStr]
        ADD     R0, R2, R0
        BL      GetVerNoFromHelpString
        MOV     R0, R2
        LDR     R2, [R0, #Module_TitleStr]
        ADD     R2, R0, R2
        MOV     R4, R1
        MOV     R1, #Service_ModulePostFinal
        SUB     R3, R12, R9
        SUBS    R3, R3, #ModInfo        ; R3 = 0 if intrinsic base incarnation
        ADDNE   R3, R12, #Incarnation_Postfix
        SWI     XOS_ServiceCall

        Pull    "R1-R4, pc"
 ]

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        END
