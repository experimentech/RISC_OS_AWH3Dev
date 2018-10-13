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

        TTL     The Podule manager.
        SUBT    Module header => Podule.s.Module

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************

; Date       Name  Description
; ----       ----  -----------
; 12-Jan-00  PMS   Added fake podule header for EtherI interface.
; 28-Apr-00  KJB   Made 32-bit compatible.
; 27-Aug-02  RPS   Now determines as much as possible at run time
; 20-Oct-02  RPS   Got rid of the large precalculated linked list,and now generate the podule nodes dynamically

MySWIChunkBase * Module_SWISystemBase + PoduleSWI * Module_SWIChunkSize
        ASSERT  MySWIChunkBase = Podule_ReadID

Origin
        DCD     0
        DCD     InitModule - Origin                     ; Initialisation
        DCD     KillModule - Origin                     ; Finalisation
        DCD     ServiceEntry - Origin
        DCD     ModuleTitle - Origin
        DCD     HelpString - Origin
        DCD     CommandTable - Origin
        DCD     MySWIChunkBase
        DCD     SWIEntry - Origin
        DCD     SWINameTable - Origin
        DCD     0
 [ International_Help <> 0
        DCD     message_filename - Origin
 |
        DCD     0
 ]
        DCD     Flags - Origin

        GBLL    DebugModule
DebugModule     SETL    ( :LNOT: ReleaseVersion ) :LAND: {FALSE}

        GBLL    DebugInterface
DebugInterface  SETL    ( :LNOT: ReleaseVersion ) :LAND: {FALSE}

        GBLL    DebugCommands
DebugCommands   SETL    ( :LNOT: ReleaseVersion ) :LAND: {FALSE}

        GBLL    DebugLoader
DebugLoader     SETL    ( :LNOT: ReleaseVersion ) :LAND: {FALSE}

        GBLL    DebugMssgs
DebugMssgs      SETL    ( :LNOT: ReleaseVersion ) :LAND: {FALSE}

        GBLL    DebugInit
DebugInit       SETL    {FALSE}

        ; The following switches are really only of use to make the module a bit smaller

        [ :LNOT: :DEF:  NumberOfPodules
                GBLL    NumberOfPodules
NumberOfPodules SETL    8
        ] 

                GBLL    EASISpace
EASISpace       SETL    {TRUE}

        ; The reassigned interrupts nick the NIC interrupt for podule 0
        ASSERT  :LNOT: (ReassignedIOMDInterrupts :LAND: NetPodSupport)

                GBLL    NetworkPodule
NetworkPodule   SETL    NetPodSupport

                GBLL    ExtensionROMs
ExtensionROMs   SETL    ExtROMSupport

        [ NetworkPodule
MaximumPodule           *       NumberOfPodules + 1
NumberOfNetworkPodule   *       MaximumPodule - 1
        |   
MaximumPodule           *       NumberOfPodules
        ]

        [       :LNOT: ReleaseVersion
        [       NetworkPodule
        !       0, "Including support code for the NetworkPodule"
        |
        !       0, "No support for the NetworkPodule"
        ]
        [       ExtensionROMs
        !       0, "Including support code for Extension ROMs"
        |
        !       0, "No support for Extension ROMs"
        ]
        ]


FixedExtROMStart        *       &03800000               ; used when the Kernel is so old it wont tell us
Maxint                  *       &7FFFFFFF               ; magic

; IOMD capabilities format

        ^       0

Capability_DMAChannels          #       9*4             ; list of 9 pointers to DMA channel numbers (mandatory)
Capability_Features             #       4               ; this table could be extended to move IRQB and so on around
Capability_PodCount             #       4
Capability_SpeedHelper          #       4               ; code to set the speed
Capability_AddressPointers      #       9*4             ; list of 9 pointers to default podule blocks (not all required)
Capability_NIC                  *       1
Capability_IOCPod               *       2
Capability_MEMCPod              *       4
Capability_PodFIQs              *       8
Capability_PodIRQs              *       16
Capability_PodFIQsasIRQs        *       32

; Podule descriptor format
; First few are held in "NodeStatics",middle 3 are guessed at run time,rest are IOMD specific

        ^       0

PoduleNode_Link                 #       4               ; Offset from start of workspace to next podule (zero if last)
                                                        ; joined up in the order MaximumPodule... > 2 > 1 > 0 > -2 > -3
                                                        ; links for 0 to 3 probably not used
PoduleNode_LoaderOffset         #       4               ; Offset from start of workspace to loader
PoduleNode_PoduleLimit          #       4               ; Highest numbered chunk in podule space, or Maxint if not yet known
PoduleNode_EnumerationLimit     #       4               ; Highest numbered chunk we've seen in podule space, or -1 if
                                                        ; not seen any
PoduleNode_WordOffset           #       4               ; Offset from one word to next
PoduleNode_ByteOffsets          #       16              ; Offset from start of word to byte 0,1,2,3
PoduleNode_DescriptionOffset    #       4               ; Zero or offset from start of workspace to description
PoduleNode_Type                 #       2               ; Type (actually a half-word)
PoduleNode_Flags                #       1               ; bit0 => ROM is IOC podule, bit1 => ROM is EASI, bit2 => ROM is NIC
PoduleNode_IDByte               #       1               ; ID byte (byte 0) for each podule
PoduleNode_CombinedAddress      #       4
PoduleNode_DMA                  #       4
PoduleNode_EASIAddress          #       4
PoduleNode_BaseAddress          #       4               ; Hardware base of podule, or address of fake header
                                                        ; in Podule manager code in the case of fake podules
PoduleNode_MEMCAddress          #       4
PoduleNode_ROMAddress           #       4               ; Address of start of image in ROM (for extension ROMs)
PoduleNode_FIQasIntMask         #       4
PoduleNode_IntMask              #       4
PoduleNode_FIQMask              #       4
PoduleNode_FIQasIntStatus       #       4
PoduleNode_IntStatus            #       4
PoduleNode_FIQStatus            #       4
PoduleNode_FIQasIntRequest      #       4
PoduleNode_IntRequest           #       4
PoduleNode_FIQRequest           #       4
PoduleNode_FIQasIntDeviceVector #       4
PoduleNode_IntDeviceVector      #       4
PoduleNode_CMOS                 #       4               ; CMOS base address
PoduleNode_SpareByte            #       1
PoduleNode_IntValue             #       1
PoduleNode_FIQasIntValue        #       1
PoduleNode_FIQValue             #       1
PoduleNode_Size                 *       :INDEX: @       ; size of node for normal podules
           [ :LNOT: ReleaseVersion
           !  0, "A node record is &" :CC: ((:STR: PoduleNode_Size) :RIGHT: 2) :CC: " bytes long"
           ]
PoduleNode_Checksum             #       4               ; ROM checksum (used to identify unique ROMs)
ROMNode_Size                    *       :INDEX: @       ; size of node for extension ROMs
           [ :LNOT: ReleaseVersion
           !  0, "A ROM node record is &" :CC: ((:STR: ROMNode_Size) :RIGHT: 2) :CC: " bytes long"
           ]

; Workspace layout

        ^       0,      wp

InitialisationData

        Byte    SegmentHeader, 16
        DCD     -1
        DCD     -1
        DCD     -1
        DCD     -1

        Word    message_file_block, 4                   ; File handle for MessageTrans
        DCD     -1
        DCD     -1
        DCD     -1
        DCD     -1
        Word    message_file_open                       ; Opened message file flag
        DCD     0                                       ; Flag that the message file is closed

        Word    SSpaceStart
        DCD     0

        Word    Capabilities                            ; Pointer to table of IOMD capabilities in the module,if any
        DCD     0

        Word    NumberOfExtROMs                         ; How many extension roms there are
        DCD     0                                       ; There are no extension ROMs currently
        [       ExtensionROMs
        Word    StartOfROM
        DCD     -1
        Word    EndOfROM
        DCD     -1
        ]

        Word    AddressOfMyPrivateWord
        DCD     0

        Word    NodeListHead                            ; Offset within wp of the node list (zero is end)
        DCD     0

        Word    OffsetOfNextLoader
        DCD     TotalRAMRequired


 [ :DEF: FakePodule
; ****************************************************************************
;
;       Fake podules - the podule manager can be assembled with built in podule headers
;                      to save having to put a ROM on the PCB for embedded applications
;                      see "Doc.FakePods" for more information
   [ FakePodule = 0
FakePodule SETA FakePodule0 ; inherit from Machine/Machine, else from Components file
   ]
        ; We only know how to fake up STB2 MPEG1, MPEG2 (and MPEG0) podules and EtherI Podule
        ASSERT (FakePodule = ProdType_STB2_MPEG1) :LOR: \
               (FakePodule = ProdType_STB2_MPEG2) :LOR: (FakePodule = ProdType_EtherI)
        ! 0,    "Assembling Podule Manager with fake podule header, (type $FakePodule)"

                MACRO
                CHUNK $type,$contents,$description,$end
                ; Podule chunk directories in the header are 8 bytes (see PRM4-128):
                DCD     $type                           ; Type: High nybble will be &F for NC
$len            *       ($end  - $desc)/4               ; Length of field
$offset         *       ($desc - $contents)/4           ; Offset of field from start
                DCD      $len :AND: &FF                 ; Size in bytes
                DCD     ($len :SHR:     8) :AND &FF
                DCD     ($len :SHR:    16) :AND &FF
                DCD      $offset :AND: &FF              ; Offset to chunk string
                DCD     ($offset :SHR:  8) :AND &FF
                DCD     ($offset :SHR: 16) :AND &FF
                DCD     ($offset :SHR: 24) :AND &FF
                MEND

                MACRO
                PODCHUNK $type,$contents,$desc,$end
                LCLA len
                LCLA offset
                DCD     $type                           ; Type: High nybble will be &F for NC
; len           SETA    ($end  - $desc)/4               ; Length of field
; offset        SETA    ($desc - $contents)/4           ; Offset of field from start
                DCD      (($end  - $desc)/4) :AND: &FF                  ; Size in bytes
                DCD     ((($end  - $desc)/4) :SHR:  8) :AND: &FF
                DCD     ((($end  - $desc)/4) :SHR: 16) :AND: &FF
                DCD      (($desc - $contents)/4) :AND: &FF              ; Offset to chunk string
                DCD     ((($desc - $contents)/4) :SHR:  8) :AND: &FF
                DCD     ((($desc - $contents)/4) :SHR: 16) :AND: &FF
                DCD     ((($desc - $contents)/4) :SHR: 24) :AND: &FF
                MEND

   [ FakePodule = ProdType_STB2_MPEG1 :LOR: FakePodule = ProdType_STB2_MPEG2
MachineConfig   *       (IOMD_Base + IOMD_CLINES)
MPEGfittedbit   *       IOMD_C_MPEGfitted
MPEGIDByte      *       0
   ]

   [ FakePodule = ProdType_STB2_MPEG1 :LOR: FakePodule = ProdType_STB2_MPEG2
MPEG0descoff    *       (MPEG0desc - MPEG0contents)/4           ; offset of description from start
MPEG0desclen    *       (MPEG0end  - MPEG0desc)/4               ; length of description
MPEG0contents   DCD     &00, &02, &00, (ProdType_STB2_MPEG0 :AND: &FF), (ProdType_STB2_MPEG0 :SHR: 8)
                DCD     (Manf_OnlineMedia :AND: &FF), (Manf_OnlineMedia :SHR: 8), &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
                DCD     &f5, MPEG0desclen, &00, &00, MPEG0descoff, &00, &00, &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
MPEG0desc       DCB     "Internal video hardware",0
MPEG0end
                ALIGN
     [ FakePodule = ProdType_STB2_MPEG1

MPEG1descoff    *       (MPEG1desc - MPEG1contents)/4           ; offset of description from start
MPEG1desclen    *       (MPEG1end  - MPEG1desc)/4               ; length of description
MPEG1contents   DCD     &00, &02, &00, (ProdType_STB2_MPEG1 :AND: &FF), (ProdType_STB2_MPEG1 :SHR: 8)
                DCD     (Manf_OnlineMedia :AND: &FF), (Manf_OnlineMedia :SHR: 8), &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
                DCD     &f5, MPEG1desclen, &00, &00, MPEG1descoff, &00, &00, &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
MPEG1desc       DCB     "Internal MPEG1 hardware",0
MPEG1end
                ALIGN
     |

MPEG1descoff    *       (MPEG1desc - MPEG1contents)/4           ; offset of description from start
MPEG1desclen    *       (MPEG1end  - MPEG1desc)/4               ; length of description
MPEG1contents   DCD     &00, &02, &00, (ProdType_STB2_MPEG2 :AND: &FF), (ProdType_STB2_MPEG2 :SHR: 8)
                DCD     (Manf_OnlineMedia :AND: &FF), (Manf_OnlineMedia :SHR: 8), &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
                DCD     &f5, MPEG1desclen, &00, &00, MPEG1descoff, &00, &00, &00
                DCD     0, 0, 0, 0, 0, 0, 0, 0
MPEG1desc       DCB     "Internal MPEG2 hardware",0
MPEG1end
                ALIGN
     ]
   ]

   [ FakePodule = ProdType_EtherI
EtherIcontents  DCD     &00                             ; Interrupts, IRQ and FIQ are relocated
                DCD     &03                             ; Interrupt Status Pointers and Chunk dir follow ECId
                DCD     &00                             ; Reserved
                DCD     (ProdType_EtherI :AND: &FF)     ; Product type low byte
                DCD     (ProdType_EtherI :SHR: 8)       ; Product type hight byte
                DCD     (Manf_AcornUK :AND: &FF)        ; Manufacturer code, low byte
                DCD     (Manf_AcornUK :SHR: 8)          ; Manufacturer code, high byte
                DCD     0                               ; Country code (0=UK)
                DCD     0, 0, 0, 0, 0, 0, 0, 0          ; Interrupt status pointers
                ; Chunks follow:
                PODCHUNK &f5, EtherIcontents, EtherIdesc, EtherIdescend ; Description: "10baseT Ethernet..."
                PODCHUNK &f3, EtherIcontents, EtherImod, EtherImodend   ; Modifications status byte: 4

                DCD     0, 0, 0, 0, 0, 0, 0, 0          ; End of chunk directory
EtherIdesc      DCB     "10BaseT Ethernet 64k buffer (A cycles)",0
EtherIdescend
EtherImod       DCD     '4', 0          ; Modification byte
EtherImodend
   ]
 ] ; :DEF: FakePodule
 
; *****************************************************************************************************************
;
;       ExtensionROMLoader - Loader for reading extension ROM
;
        [       ExtensionROMs

ExtensionROMLoader
        B       ROMLoaderReadByte                       ; read a byte
        B       ROMLoaderError                          ; write a byte
        MOV     pc, lr                                  ; reset
        MOV     pc, lr                                  ; SWI Podule_CallLoader
        =       "32OK"

; ROMLoaderReadByte - Read a byte from extension ROM
;
; in:   R1 = address within ROM
;       R3 -> podule descriptor node *** NOTE actual address not offset from wp ***
;       R11 = "combined hardware address", ie ROM address in the case of extension ROMs
;       V clear
;
; out:  R0 = byte read
;       R1, R4-R9, R11,R12 preserved
;       R2,R3,R10 corrupted
;

ROMLoaderReadByte ROUT
        AND     r10, r1, #3                             ; get byte number
        ADD     r10, r3, r10, LSL #2
        LDR     r10, [r10, #PoduleNode_ByteOffsets]     ; r10 = offset from start of that word
        MOV     r2, r1, LSR #2                          ; r2 = word number
        LDR     r0, [r3, #PoduleNode_WordOffset]
        MLA     r10, r0, r2, r10                        ; r10 = byte offset in actual ROM
        LDRB    r0, [r11, r10]                          ; r0 = byte read
        MOV     pc, lr

ROMLoaderError
        SETV
        ADR     r0, ErrorAccess
        MOV     pc, lr

ExtensionROMLoaderEnd

        Byte    ROMLoader, ExtensionROMLoaderEnd - ExtensionROMLoader
        ]

; *****************************************************************************************************************
;
;       NetworkROMLoader - Loader for reading the ROM on the network card
;
        [       NetworkPodule
NetworkPoduleLoader
        B       NetworkLoaderReadByte                   ; Read a byte
        B       NetworkLoaderError                      ; Write a byte
        B       NetworkLoaderReset                      ; Reset
        MOV     pc, lr                                  ; SWI Podule_CallLoader
        =       "32OK"

;       The network ROM lives at address 'NetworkROMAddress' (R11)
;       Writes to that address reset a 12 bit counter attached to the
;       low order 12 bits of the ROMs address lines.  The address lines
;       above that are attached to LA2, LA3, LA4, etc.  So to read
;       consecutive bytes one reads location NetworkROMAddress 4096
;       times then NetworkROMAddress + 4 4096 times etc.

; NetworkLoaderReadByte - Read a byte from the Network Podule ROM
;
; in:   R1 = address within ROM
;       R3 -> podule descriptor node *** NOTE actual address not offset from wp ***
;       R11 = ROM base address
;
; out:  R0 = byte read
;       R2, R10, R11 corrupted
;       R1, R3-R9, R12 preserved

NetworkLoaderReadByte ROUT
        LDR     r2, BaseAddressANDMask
        AND     r11, r11, r2                            ; Reduce a combined address to the ROM address
        MOV     r2, r1, LSL #32-12
        MOV     r2, r2, LSR #32-12                      ; Now just the page offset
        MOV     r10, r1, LSR #12                        ; Page number
        CMP     r10, #&00000100                         ; Is this a viable address?
        BHS     NetworkLoaderTooBig
        ADD     r11, r11, r10, LSL #2                   ; Address to use to read the byte
        LDR     r10, NetworkPageCounter                 ; Soft copy of the value in the counter H/W
NetworkCounterLoop
        CMP     r2, r10                                 ; Is this the byte we want?
        LDRB    r0, [ r11, #0 ]                         ; Read it and increment the counter
        INC     r10                                     ; Increment the soft copy
   ;    BICEQ   r10, r10, #&000FF000                    ; Make sure the counter doesn't overflow
        STREQ   r10, NetworkPageCounter                 ; Update the soft copy
        MOVEQ   pc, lr                                  ; Return to the caller (V will be clear if EQ)
        BGT     NetworkCounterLoop                      ; And try again
        MOV     r10, #0
        STR     r10, NetworkPageCounter                 ; Reset the soft copy
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
   ;    STRB    r10, [ r11, #0 ]                        ; Reset the counter
        [       DebugLoader
        LDRB    r6, [ r11, #0 ]
        LDRB    r5, [ r11, #0 ]
        ORR     r6, r6, r5, LSL #8
        LDRB    r5, [ r11, #0 ]
        ORR     r6, r6, r5, LSL #16
        LDRB    r5, [ r11, #0 ]
        ORR     r6, r6, r5, LSL #24
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
   ;    STRB    r10, [ r11, #0 ]                        ; Reset the counter
        LDRB    r7, [ r11, #0 ]
        LDRB    r5, [ r11, #0 ]
        ORR     r7, r7, r5, LSL #8
        LDRB    r5, [ r11, #0 ]
        ORR     r7, r7, r5, LSL #16
        LDRB    r5, [ r11, #0 ]
        ORR     r7, r7, r5, LSL #24
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
        STRB    r10, [ r11, #0 ]                        ; Reset the counter
   ;    STRB    r10, [ r11, #0 ]                        ; Reset the counter
        MOV     r5, pc                                  ; Set flag to say reset occured
        ]
        B       NetworkCounterLoop                      ; And try again

NetworkLoaderError
        SETV
        ADR     r0, ErrorAccess
        MOV     pc, lr
        
NetworkLoaderTooBig
        SETV
        ADR     r0, ErrorNetworkLoaderTooBig
        MOV     pc, lr

ErrorNetworkLoaderTooBig
        DCD     ErrorNumber_AddressRange
        DCB     "AddressRange",0
        ALIGN

NetworkPageCounter                                      ; This is the soft copy
        DCD     0                                       ; This is OK because this is in RAM

BaseAddressANDMask
        DCD     Podule_BaseAddressANDMask

; NetworkLoaderReset
;
; in:   R11 = ROM base address
;       V clear
;
; out:  R2, R11 corrupted

NetworkLoaderReset ROUT
        LDR     r2, BaseAddressANDMask
        AND     r11, r11, r2
        MOV     r2, #0
        STRB    r2, [ r11, #0 ]                         ; Reset the counter
        STR     r2, NetworkPageCounter
        MOV     pc, lr

NetworkLoaderEnd

        Byte    NetworkLoader, NetworkLoaderEnd - NetworkPoduleLoader
        ]

        [ ExtensionROMs :LOR: NetworkPodule 
ErrorAccess
        DCD     ErrorNumber_PoduleReadOnly
        DCB     "PoduleReadOnly", 0
        ALIGN
ErrorAccessEnd
        #       ErrorAccessEnd-ErrorAccess
        ]

; *****************************************************************************************************************
;
;       Not32bitLoader - Dummy loader substituted for non 32-bit compatible ones
;

Not32bitDummyLoader
        B       Not32bitLoaderError                     ; read a byte
        B       Not32bitLoaderError                     ; write a byte
        MOV     pc, lr                                  ; reset (nothing to reset...)
        B       Not32bitLoaderError                     ; SWI Podule_CallLoader
        =       "32OK"

; in:   We know r12 is the Podule Manager global workspace. Use it to look up
;       the error

Not32bitLoaderError
        SETV
        ADR     r0, ErrorLoader26bit
        MOV     pc, lr

Not32bitLoaderEnd

        Byte    Not32bitLoader, Not32bitLoaderEnd - Not32bitDummyLoader

        AlignSpace      16

        Word    EndOfInitialisationData, 0
        [       :LNOT: ReleaseVersion
        !       0, "The end of initialisation data is at &" :CC:((:STR:(:INDEX:EndOfInitialisationData)):RIGHT:4)
        ]

        ;       The area after here is initialised to -1s

InfoBufLength * &40                                     ; buffer length for title and help strings

        Byte    RMName, InfoBufLength
        Byte    RMHelp, InfoBufLength
        Byte    ErrorLoader26bit, InfoBufLength
        Byte    ErrorReadOnly, InfoBufLength
        Byte    ErrorOffEnd, InfoBufLength

        Word    EndOfInitialisationArea, 0

TotalRAMRequired *      :INDEX: @
        [       :LNOT: ReleaseVersion
        !       0, "Total RAM required is &" :CC: ((:STR: TotalRAMRequired) :RIGHT: 4) :CC: " bytes"
        ]

        SUBT    Module entry stuff
        OPT     OptPage

HelpString
        DCB     "Podule Manager", 9, "$Module_HelpVersion"

        [       :LNOT: ReleaseVersion
        =       " ["
        [       EASISpace
        =       "+EASI"
        ]
        [       NetworkPodule
        =       "+NIC"
        ]
        [       ExtensionROMs
        =       "+ROMS"
        ]
        =       "] (development version)"
        ]
        =       0
        ALIGN

Flags
  [ No32bitCode
        DCD     0
  |
        DCD     ModuleFlag_32bit
  ]

        SUBT    Initialisation code
        OPT     OptPage

InitModule ROUT
        Push    "lr"
  [ ( DebugModule :LOR: DebugInterface :LOR: DebugCommands ) :LAND: DebugInit
        InsertTMLInitialisation 0
        BVS     ExitInitModule
  ]
        LDR     r2, [ r12 ]
        TEQ     r2, #0
 [ DebugModule
        BEQ     HardInit
        DLINE   "Podule - ReInit"
 ]
        MOVNE   r1, #0                                  ; If we already have workspace, then
        STRNE   r1, [r2, #:INDEX:message_file_open]     ; flag that the message file is closed
        BNE     ReInitialisation
 [ DebugModule
HardInit
        DLINE   "Podule - Init"
 ]
        MOV     r0, #9
        MOV     r1, #0 << 8
        SWI     XOS_Memory
        TEQ     r1, #0
        MOVNE   r0, #0
        STRNEB  r0, [r1]                                ; on hard init,force everyone to read slow (if ECTCR is available)

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =TotalRAMRequired
        SWI     XOS_Module
        BVS     ExitInitModule
      [ DebugModule
        DREG    r2, "Workspace is at &"
        DREG    r12,"Private word is at &"
      ]
        ASSERT  ( ( :INDEX: EndOfInitialisationData ) :AND: 3 ) = 0
        MOV     r3, #0
        ADRL    r5, InitialisationData

InitialisationLoop
        CMP     r3, # :INDEX: EndOfInitialisationData
        LDRLT   r0, [ r5, r3 ]
        MOVGE   r0, #-1
        STR     r0, [ r2, r3 ]                          ; Note that the initialised data is
        INC     r3, 4                                   ; at the start of workspace
        CMP     r3, # :INDEX: EndOfInitialisationArea
        BLT     InitialisationLoop

        MOV     r0, #1                                  ; We've just copied code (the ROM and
        MOV     r1, r2                                  ; network loaders) into our workspace
        ADD     r2, r2, r3
        SWI     XOS_SynchroniseCodeAreas

        MOV     r2, r1

        MOV     r0, #9
        MOV     r1, #4 << 8
        SWI     XOS_Memory
        MOVVS   r1, #IOMD_Base                          ; Kernel's too old,assume IOMD_Base
        STR     r1, [r2, #:INDEX:SSpaceStart]           ; Saves keep asking for it
        TEQ     r1, #0
        MOVEQ   r4, #0                                  ; Get an unknown id
        LDRNEB  r3, [r1, #IOMD_ID1]
        LDRNEB  r4, [r1, #IOMD_ID0]
        ORRNE   r4, r4, r3, LSL#8

        ADRL    r5, KnownIOMDs
        ADD     r3, r5, #(KnownIOMDsEnd-KnownIOMDs)
DynamicIOMD
        LDR     r0, [r5], #4
        TEQ     r0, r4
        BEQ     %FT15
        ADDS    r5, r5, #4
        TEQ     r5, r3
        BNE     DynamicIOMD
        ASSERT  IOMDCapabilities = IOMDUnknownCap
        ADRL    r5, KnownIOMDs+4                        ; There's an IOMD,but it's not in the table!
15
        LDR     r5, [r5]
        ADRL    r3, IOMDCapabilities
        ADD     r5, r3, r5
        STR     r5, [r2, #:INDEX:Capabilities]          ; Absolute address (within the module)
      [ DebugModule
        DREG    r5,"IOMD capabilities table at &"
      ]
18
        LDR     r4, [r5, #Capability_PodCount]
        TEQ     r4, #0                                  ; not a single podule
        BEQ     DynamicExtROMs
        MOV     r1, #PoduleNode_Size
        MUL     r3, r1, r4
        MOV     r0, #ModHandReason_ExtendBlock
        SWI     XOS_Module
        BVS     ExitInitModule
      [ DebugModule
        DREG    r3, "Growing workspace by &"
        DREG    r2, "New workspace at &"
      ]

        LDR     r0, [r2, #:INDEX:OffsetOfNextLoader]
        ADD     r0, r0, r3
        STR     r0, [r2, #:INDEX:OffsetOfNextLoader]    ; wouldn't want to go loading loaders over our linked list!
        MOV     r3, #:INDEX:EndOfInitialisationArea     ; hence the start of the node area
        ADD     r3, r3, r2
        SUB     r4, r4, #1                              ; convert from natural numbers
20
        BL      AddPoduleNode
        BPL     %BT20

DynamicExtROMs
      [ ExtensionROMs
        MOV     r0, #9
        MOV     r1, #5 << 8
        SWI     XOS_Memory                              ; when ExtROMSupport is required,find out where they are
        MOVVS   r1, #FixedExtROMStart
        TEQ     r1, #0
        BEQ     %FT30                                   ; nope,no extension ROMs at all
        STR     r1, [r2, #:INDEX:StartOfROM]
        ADD     r1, r1, #16*1024*1024                   ; may be less than 16M,but we'll find that out later
        STR     r1, [r2, #:INDEX:EndOfROM]
        MOV     r1, #1
        STR     r1, [r2, #:INDEX:NumberOfExtROMs]
        BL      FindExtensionROMs
30
      ]

 [ :DEF: FakePodule

   [ FakePodule = ProdType_STB2_MPEG1 :LOR: FakePodule = ProdType_STB2_MPEG2
        ; Fake MPEG podule ROM Headers
        LDR     r0, [r2, #:INDEX:NodeListHead]
        ADD     r0, r0, r2                              ; make it an absolute address

        MOV     r1, #MPEGIDByte                         ; ID byte for fake MPEG podule
        STRB    r1, [ r0, #PoduleNode_IDByte ]          ; set ID byte to make ConvertR3ToPoduleNode happy

        MOV     r1, #BitZero
        STRB    r1, [ r0, #PoduleNode_Flags ]           ; This is a (fake) Podule

        MOV     r1, #PoduleCMOS
        STR     r1, [ r0,  #PoduleNode_CMOS ]           ; We don't have no CMOS

        MOV     r1, #-1
        STR     r1, [ r0,  #PoduleNode_DMA ]            ; We don't do DMA

        ; See if MPEG is fitted and point the podule ROM address to the appropriate fake header
        ; The description string will be extracted from this block in the normal way when chunks get enumerated
        LDR     r3, =MachineConfig
        LDRB    r1, [r3]
        TST     r1, #MPEGfittedbit
        ADREQL  r1, MPEG0contents
        ADRNEL  r1, MPEG1contents
        STR     r1, [ r0, #PoduleNode_ROMAddress ]      ; Location to read header from
   ]

   [ FakePodule = ProdType_EtherI
        ; Fake EtherI podule ROM
        LDR     r0, [r2, #:INDEX:NodeListHead]
        ADD     r0, r0, r2                              ; make it an absolute address

        MOV     r1, #0                                  ; ID byte for fake EtherI podule
        STRB    r1, [ r0, #PoduleNode_IDByte ]          ; set ID byte to make ConvertR3ToPoduleNode happy

        MOV     r1, #BitZero
        STRB    r1, [ r0, #PoduleNode_Flags ]           ; This is a (fake) Podule

        MOV     r1, #PoduleCMOS
        STR     r1, [ r0,  #PoduleNode_CMOS ]           ; We don't have no CMOS

        MOV     r1, #-1
        STR     r1, [ r0,  #PoduleNode_DMA ]            ; We don't do DMA

        ; We are faking an EtherI podule ROM, so point the podule ROM address to the appropriate fake header
        ; The description string will be extracted from this block in the normal way when chunks get enumerated
        ADR     r1, EtherIcontents
        STR     r1, [ r0, #PoduleNode_ROMAddress ]      ; Location to read header from
   ]
 ] ; :DEF: FakePodule

        BL      LoadAllLoaders                          ; ensure all loaders are loaded

ReInitialisation
        ; in :  Address of workspace in R2
        ;       Address of Private word in R12
      [ DebugModule
        DREG    r2, "Workspace is at &"
        DREG    r12,"Private word is at &"
      ]
        STR     r2, [ r12 ]
        STR     r12, [ r2, #:INDEX:AddressOfMyPrivateWord ]

        MOV     wp, r2
        BL      RedoMessages                            ; Required if rmreinit'd

        CLRV
ExitInitModule
        Pull    "pc"


; Note that due to the module die entry and the service reset code being the same,
; the Messages file gets closed on Service reset. This is not a problem.

KillModule ROUT
ResetAllLoaders
        LDR     wp, [ r12 ]
        MOV     r6, lr
        MOV     r3, #:INDEX:NodeListHead
10
        ASSERT  PoduleNode_Link = 0
        LDR     r3, [ wp, r3 ] 
        TEQ     r3, #0                                  ; check node offset first,there may be none!
        BEQ     %FT15
        BL      ResetLoader
        MOVVS   pc, r6
      [ DebugModule
        DREG    r3,"Reset loader OK at "
      ]
        B       %BT10
15
        BL      close_message_file                      ; close messages file if it is open, marking it closed
        CLRV
        MOV     pc, r6

        ASSERT  Service_Reset < Service_PreReset
        ASSERT  Service_PreReset < Service_TerritoryStarted
ServiceTable
        DCD     0                        ;flags
        DCD     UServiceEntry - Origin
        DCD     Service_Reset
        DCD     Service_PreReset
        DCD     Service_TerritoryStarted
        DCD     0                        ;terminator
        DCD     ServiceTable - Origin    ;table anchor
ServiceEntry ROUT
        MOV     r0, r0                   ;magic instruction
        TEQ     r1, #Service_PreReset
        TEQNE   r1, #Service_Reset
        TEQNE   r1, #Service_TerritoryStarted
        MOVNE   pc, lr
UServiceEntry
        TEQ     r1, #Service_TerritoryStarted           ; we also rely on this to get the messages in the first
                                                        ; place,since we're at the start of ROM and MessageTrans 
                                                        ; itself hasn't started
        BEQ     %FT10

        Push    "r0-r6, lr"
        BL      ResetAllLoaders
        Pull    "r0-r6, pc"
10
        LDR     wp, [ r12 ]
RedoMessages
        Push    "r0,r2,lr"
        ADD     r2, wp, #:INDEX:ErrorLoader26bit        ; Find message strings for internal loaders
        ADRL    r0, ErrorBlock_Ldr26
        BL      SoftloadErrorMssg
        BVS     %FT15
        ADD     r2, wp, #:INDEX:ErrorReadOnly
        ADRL    r0, ErrorBlock_PoduleReadOnly
        BL      SoftloadErrorMssg
        BVS     %FT15
        ADD     r2, wp, #:INDEX:ErrorOffEnd
        ADRL    r0, ErrorBlock_AddressRange
        BL      SoftloadErrorMssg
15
        STRVS   r0, [ sp, #0 ]                          ; Pass back any error message
        Pull    "r0,r2,pc"

        LTORG

; ****************************************************************************
; 
;      AddPoduleNode - Internal routine to fill in a podule node
; 
; in:  R5 -> selected capability table
;      R4 =  podule number
;      R2 -> my workspace
;      R3 -> start of this node (absolute)
;      R0,R1,R6 = temp
; out: R4 decremented (can branch on the flags)
;      R0,R1,R6 = corrupted
;      R3 = updated to -> start of next node
;

AddPoduleNode ROUT
      [ DebugModule
        BREG    r4, "Add node for podule "
      ]
        ASSERT  Capability_DMAChannels = 0
        LDR     r6, [r5, r4, LSL#2]
        STR     r6, [r3, #PoduleNode_DMA]               ; see if the IOMD does DMA
        MOV     r0, #9
        MOV     r1, #1 << 8
        ORR     r1, r1, r4
        Push    "lr"
        SWI     XOS_Memory
        Pull    "lr"
        MOVVS   r1, #0
      [ DebugModule
        DREG    r6, " dma channel "
        TEQ     r1, #0
        BNE     %FT07
        DLINE   " no EASI space"
        BEQ     %FT08
07
        DREG    r1, " found EASI space &"
08
      ]
        STR     r1, [r3, #PoduleNode_EASIAddress]       ; stash EASI space address
        MOV     r6, r4, LSL#2
        ADD     r6, r6, #Capability_AddressPointers
        LDR     r0, [r5, r6]
        ADD     r0, r0, r5                              ; address off the podule constants table in ROM
      [ DebugModule
        DREG    r0," address pointers in table at "
        DREG    r3," node starts at "
      ]
        MOV     r1, #PoduleNode_BaseAddress
        LDR     r6, [r2, #:INDEX:SSpaceStart]
        Push    "r7"
10
        ; Copy and adjust the IOMD base address dependant entries
        LDR     r7, [r0], #4
        TEQ     r7, #0
        BEQ     %FT14
        CMP     r1, #PoduleNode_FIQasIntDeviceVector
        ADDCC   r7, r6, r7                              ; only address correct those which need it
14
        STR     r7, [r3, r1]
        ADD     r1, r1, #4
        TEQ     r1, #PoduleNode_Size
        BNE     %BT10
        Pull    "r7"

        ADRL    r0, NodeStatics                         ; Copy down the fixed entries
        MOV     r1, #PoduleNode_Link
18
        LDR     r6, [r0], #4
        STR     r6, [r3, r1]
        ADD     r1, r1, #4
        TEQ     r1, #PoduleNode_CombinedAddress
        BNE     %BT18

      [ NetworkPodule
        LDR     r6, [r5, #Capability_Features]
        TST     r6, #Capability_NIC
        BEQ     %FT20
        LDR     r6, [r5, #Capability_PodCount]
        ASSERT  NumberOfNetworkPodule = MaximumPodule-1
        SUB     r6, r6, #1
        TEQ     r6, r4
        MOVEQ   r6, #NetworkPoduleLoader-InitialisationData  
        STREQ   r6, [r3, #PoduleNode_LoaderOffset]      ; quick check for the NIC,and force use of built in loader
20
      ]
        LDR     r6, [r3, #PoduleNode_ROMAddress] 
        LDR     r0, [r3, #PoduleNode_CMOS]
        ORR     r0, r0, r6                              ; Calculate the combined address 
        STR     r0, [r3, #PoduleNode_CombinedAddress]

        ; Update the previous end of list pointer
        MOV     r1, #:INDEX:NodeListHead
        SUB     r3, r3, r2                              ; make relative to workspace again
22
        LDR     r0, [r2, r1]
        TEQ     r0, #0
        ASSERT  PoduleNode_Link = 0 
        STREQ   r3, [r2, r1]
      [ DebugModule
        BNE     %FT26
        DREG    r3, " link to next "
26      
      ]
        MOVNE   r1, r0
        BNE     %BT22

        ADD     r3, r3, #PoduleNode_Size
        ADD     r3, r3, r2                              ; should return it absolute
        SUBS    r4, r4, #1
        MOV     pc, lr

; ****************************************************************************
;
;       LoadAllLoaders - Internal routine to load all loaders on initialisation
;
; in:   R12 -> private word
;       R2 -> workspace
;
; out:  R0,R1,R3-R5 corrupted
;       R2 -> workspace (not necessarily where it used to be)
;       All others must be preserved
;
LoadAllLoaders  ROUT
        Push    "r8-r12, lr"
        SUB     sp, sp, #16                             ; Make a frame to work in
      [ DebugModule
        DLINE   "Load All Loaders called"
      ]
        STR     r12, [ r2, #:INDEX:AddressOfMyPrivateWord ]
        STR     r2, [ r12 ]
        MOV     wp, r2
   [    NetworkPodule                                   ; Reset the hardware
        LDR     r0, [ r2, #:INDEX:Capabilities]         ; Address in the module of the table
        LDR     r1, [ r0, #Capability_Features]
        TST     r1, #Capability_NIC
        BEQ     %FT09                                   ; NIC support code,but no NIC
        ASSERT  NumberOfNetworkPodule = MaximumPodule-1
        LDR     r8, [r2, #:INDEX:NodeListHead]          ; if there is a NIC,it must always be the highest numbered podule
        ADD     r8, r8, r2
      [ DebugModule
        DREG    r8,"NIC node is at "
      ]
        LDR     r8, [r8, #PoduleNode_ROMAddress]
        TEQ     r8, #0
        STRNEB  r8, [ r8 ]                              ; A write resets the counter,when present
      [ DebugModule
        BEQ     %FT05
        DLINE   " reset NIC ROM"
05
      ]
09
   ]

        LDR     r8, [r2, #:INDEX:Capabilities]
        LDR     r8, [r8, #Capability_PodCount]          ; start with podule MaximumPodule
LoadLoadersLoop
        SUBS    r8, r8, #1
        BMI     %FT21                                   ; stop at system rom (-1)
     [  DebugModule
        BREG    r8, "Doing podule &"
     ]
        MOV     r3, r8
        BL      ConvertR3ToPoduleNode
     [  DebugModule
        BVC     %14
        ADD     r14, r0, #4
        DSTRING r14, "Error from ConvertR3ToPoduleNode: "
        B       %15
14
        ADD     r14, wp, r3
        LDR     r14, [ r14, #PoduleNode_LoaderOffset ]
        DREG    r14, "Loader offset is &"
15
     ]
        BVS     LoadLoadersLoop
        MOV     r2, sp                                  ; Base of 16 byte stack frame
     [  DebugModule
        MVN     r3, #0
        STR     r3, [ sp, #0 ]
        STR     r3, [ sp, #4 ]
        STR     r3, [ sp, #8 ]
        STR     r3, [ sp, #12 ]
     ]
        MOV     r3, r8
        BL      ReadHeader                              ; Do this to get the type byte
     [  DebugModule
        BVC     %16
        ADD     r14, r0, #4
        DSTRING r14, " error from ReadHeader: "
        B       %FT17
16
        LDR     r14, [ sp, #0 ]
        DREG    r14, "Header is &", cc
        LDR     r14, [ sp, #4 ]
        DREG    r14, ", &", cc
        LDR     r14, [ sp, #8 ]
        DREG    r14, ", &", cc
        LDR     r14, [ sp, #12 ]
        DREG    r14, ", &"
17
     ]
        BVS     LoadLoadersLoop
        MOV     r0, #0                                  ; Start with chunk zero
NextChunk
        BL      EnumerateChunks                         ; Loads the loader and the description
        BVS     LoadLoadersLoop                         ; if get error, goto next podule
        TEQ     r0, #0                                  ; Is this the last chunk?
        BNE     NextChunk                               ; No, so get another one
        B       LoadLoadersLoop

21
     [  ExtensionROMs
        LDR     r9, NumberOfExtROMs                     ; r10 gets trashed by EnumerateChunks
        [  DebugModule
        BREG    r9, "There are &", cc
        DLINE   " extension ROMs"
        ]
        TEQ     r9, #0
        BEQ     ExitLoadLoaders
        MOV     r8, #-2                                 ; -1 is the system ROM,so start at -2
LoadExtensionROMLoop
        [  DebugModule
        BREG    r8, "Doing extension ROM &"
        ]
        MOV     r3, r8
        BL      ConvertR3ToPoduleNode
        [  DebugModule
        BVC     %74
        ADD     r14, r0, #4
        DSTRING r14, "Error from ConvertR3ToPoduleNode: "
74
        ]
        BVS     NextExtensionROM
        MOV     r0, #0                                  ; Start with chunk zero
ExtensionChunkLoop
        MOV     r3, r8
        BL      EnumerateChunks                         ; Loads the description
        BVS     NextExtensionROM                        ; If get error, goto next ROM
        TEQ     r0, #0                                  ; Is this the last chunk?
        BNE     ExtensionChunkLoop                      ; No, so get another one
NextExtensionROM
        DEC     r8
        DECS    r9 
        BNE     LoadExtensionROMLoop
     ]
ExitLoadLoaders
        ADD     sp, sp, #16                             ; Remove frame
        Pull    "r8-r12, lr"
        LDR     r2, [ r12 ]                             ; reload workspace ptr from priv word
        MOV     pc, lr

        END
