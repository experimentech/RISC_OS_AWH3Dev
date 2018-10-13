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
        SUBT    Magic Tables => Podule.s.Tables

        OPT     OptPage

        ; Offsets used later for readability (different IOMDs may choose to space these differently)
PoduleBase0             *       &033C0000-IOMD_Base     ; IOC podules
PoduleBase4             *       &033F0000-IOMD_Base
ModuleBase0             *       &03000000-IOMD_Base     ; MEMC podules
ModuleBase4             *       &03030000-IOMD_Base
NetworkBaseROM          *       &0302B000-IOMD_Base     ; NICs
NetworkBaseChip         *       &0302B800-IOMD_Base

PoduleIntStatus         *       IOCIRQSTAB
PoduleIntRequest        *       IOCIRQREQB
PoduleIntMask           *       IOCIRQMSKB
PoduleIntValue          *       &20                     ; Bitmask within IRQB

PoduleFIQasIntStatus    *       IOCIRQSTAB
PoduleFIQasIntRequest   *       IOCIRQREQB          
PoduleFIQasIntMask      *       IOCIRQMSKB
PoduleFIQasIntValue     *       &01                     ; Bitmask within IRQB

PoduleFIQStatus         *       IOCFIQSTA
PoduleFIQRequest        *       IOCFIQREQ           
PoduleFIQMask           *       IOCFIQMSK           
PoduleFIQValue          *       &40                     ; Bitmask within FIQ

NetworkIntStatus        *       IOCIRQSTAB
NetworkIntRequest       *       IOCIRQREQB           
NetworkIntMask          *       IOCIRQMSKB           
NetworkIntValue         *       &08                     ; Bitmask within IRQB

NetworkFIQasIntStatus   *       IOCIRQSTAB
NetworkFIQasIntRequest  *       IOCIRQREQB           
NetworkFIQasIntMask     *       IOCIRQMSKB
NetworkFIQasIntValue    *       &08                     ; Bitmask within IRQB

NetworkFIQStatus        *       IOCFIQSTA
NetworkFIQRequest       *       IOCFIQREQ           
NetworkFIQMask          *       IOCFIQMSK
NetworkFIQValue         *       &02                     ; Bitmask within FIQ

        ;       Precalculated tables of values to LDR then STR in order into the node (with address 
        ;       correction where non zero).Note that these could be calculated at run time,but their use allows
        ;       future IOMDs to have their podules splattered anywhere relative to "SSpace"
B0
        DCD     PoduleBase0+&0000,ModuleBase0+&0000,PoduleBase0+&0000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleCMOS +0
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B1
        DCD     PoduleBase0+&4000,ModuleBase0+&4000,PoduleBase0+&4000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleCMOS +4
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B2
        DCD     PoduleBase0+&8000,ModuleBase0+&8000,PoduleBase0+&8000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleCMOS +8
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B3
        DCD     PoduleBase0+&C000,ModuleBase0+&C000,PoduleBase0+&C000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleCMOS +12
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B4
        DCD     PoduleBase4+&0000,ModuleBase4+&0000,PoduleBase4+&0000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleExtraCMOS +16
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B5
        DCD     PoduleBase4+&4000,ModuleBase4+&4000,PoduleBase4+&4000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleExtraCMOS +12
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B6
        DCD     PoduleBase4+&8000,ModuleBase4+&8000,PoduleBase4+&8000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleExtraCMOS +8
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
B7
        DCD     PoduleBase4+&C000,ModuleBase4+&C000,PoduleBase4+&C000
        DCD     PoduleFIQasIntMask,   PoduleIntMask,   PoduleFIQMask
        DCD     PoduleFIQasIntStatus, PoduleIntStatus, PoduleFIQStatus
        DCD     PoduleFIQasIntRequest,PoduleIntRequest,PoduleFIQRequest
        DCD     IOMD_PFIQasIRQ_DevNo,IOMD_Podule_DevNo,PoduleExtraCMOS +4
        DCB     0,PoduleIntValue,PoduleFIQasIntValue,PoduleFIQValue
      [ NetworkPodule
B8
        DCD     NetworkBaseChip,0,NetworkBaseROM
        DCD     NetworkFIQasIntMask,   NetworkIntMask,   NetworkFIQMask
        DCD     NetworkFIQasIntStatus, NetworkIntStatus, NetworkFIQStatus
        DCD     NetworkFIQasIntRequest,NetworkIntRequest,NetworkFIQRequest
        DCD     IOMD_Network_DevNo,IOMD_Network_DevNo,PoduleExtraCMOS +0
        DCB     0,NetworkIntValue,NetworkFIQasIntValue,NetworkFIQValue
      ]

        ; The top wedge of a podule node table
NodeStatics
        DCD     0            ; Link (end of link)
        DCD     -1           ; LoaderOffset (none)
        DCD     Maxint       ; PoduleLimit
        DCD     -1           ; EnumerationLimit
        DCD     16           ; WordOffset
        DCD     0, 4, 8 ,12  ; ByteOffsets
        DCD     0            ; Description
        DCW     0            ; Type
        DCB     0            ; Flags
        DCB     255          ; IDByte
NodeStaticsEnd

        ; What they can all do
IOMDCapabilities
IOMDUnknownCap
        DCD     -1,-1,-1,-1,-1,-1,-1,-1,-1                     ; Definitely no DMA
        DCD     0,0                                            ; No capability or podules
        B       ExitSetSpeed
IOMD1Cap
      [ NetworkPodule
        DCD     &000,&010,-1,-1,-1,-1,-1,-1,&105               ; DMA on DEBI 0 and 1 plus the NIC
        DCD     2_00111111                                     ; We've included the NIC code,so declare it
      |
        DCD     &000,&010,-1,-1,-1,-1,-1,-1,-1                 ; DMA on DEBI 0 and 1
        DCD     2_00111110
      ]
        DCD     MaximumPodule
        B       HelperIOMD1
        DCD     B0-IOMD1Cap,B1-IOMD1Cap,B2-IOMD1Cap,B3-IOMD1Cap
        DCD     B4-IOMD1Cap,B5-IOMD1Cap,B6-IOMD1Cap,B7-IOMD1Cap
      [ NetworkPodule
        DCD     B8-IOMD1Cap
      ] 
IOMD75Cap
        DCD     -1,-1,-1,-1,-1,-1,-1,-1,-1                     ; No external DMA
      [ NetworkPodule
        DCD     2_00111111                                     ; We've included the NIC code,so declare it
      |
        DCD     2_00111110
      ]
        DCD     MaximumPodule
        B       HelperIOMD1
        DCD     B0-IOMD75Cap,B1-IOMD75Cap,B2-IOMD75Cap,B3-IOMD75Cap
        DCD     B4-IOMD75Cap,B5-IOMD75Cap,B6-IOMD75Cap,B7-IOMD75Cap
      [ NetworkPodule
        DCD     B8-IOMD75Cap
      ]
IOMDTCap
        DCD     -1,-1,-1,-1,-1,-1,-1,-1,-1                     ; No external DMA
        DCD     2_00111110
        DCD     4
        B       HelperIOMDT
        DCD     B0-IOMDTCap,B1-IOMDTCap,B2-IOMDTCap,B3-IOMDTCap
IOMDCapabilitiesEnd

        ; A table of the ID bytes of various ids and pointers to capabilities lists
KnownIOMDs
        DCD     0            , IOMDUnknownCap-IOMDCapabilities ; Special entry
        DCD     IOMD_Original, IOMD1Cap      -IOMDCapabilities ; Used on Risc PC
        DCD     IOMD_7500    , IOMD75Cap     -IOMDCapabilities ; Used on A7000 only
        DCD     IOMD_7500FE  , IOMD75Cap     -IOMDCapabilities ; Used all over the place
        DCD     IOMD_2       , IOMDUnknownCap-IOMDCapabilities ; Understood,but not supported at present
        DCD     IOMD_Tungsten, IOMDTCap      -IOMDCapabilities ; Used on Tungsten
KnownIOMDsEnd

        END
