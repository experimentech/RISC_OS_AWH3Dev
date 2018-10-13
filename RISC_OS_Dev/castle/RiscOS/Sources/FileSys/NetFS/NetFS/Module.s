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
        TTL     Econet filing system for Arthur. ==> &.Arthur.NetFS.Module

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc
        GET     Hdr:CMOS
        GET     Hdr:ModHand
        GET     Hdr:Heap
        GET     Hdr:Services
        GET     Hdr:Debug
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:Econet
        GET     Hdr:OsBytes
        GET     Hdr:NewErrors
        GET     Hdr:VduExt
        GET     Hdr:Tokens
        GET     Hdr:MsgTrans
        GET     Hdr:Territory
        GET     Hdr:Symbols
        GET     Hdr:Portable
        GET     Hdr:ResourceFS
        GET     VersionASM

        SUBT    Module header ==> &.Arthur.NetFS.Module

                GBLL    OldOs
OldOs           SETL    {FALSE}
                GBLL    UseMsgTrans
UseMsgTrans     SETL    {TRUE}
                GBLL    Files32Bit
Files32Bit      SETL    {FALSE}
                GBLL    Files24Bit
Files24Bit      SETL    {TRUE}
                GBLL    ReleaseVersion
ReleaseVersion  SETL    {TRUE}
                GBLS    NewLibName
NewLibName      SETS    "ArthurLib"
                GBLL    Debug
Debug           SETL    (:LNOT: ReleaseVersion) :LAND: {FALSE}
    [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL    {FALSE}                         ; Build-in Messages file and i/f to ResourceFS
    ]
    [ :LNOT: :DEF: international_help
                GBLL    international_help
international_help SETL {TRUE}                          ; Default to RISC OS 3.60+ internationalisation
    ]

        ASSERT  Files24Bit :LOR: Files32Bit             ; Must be one or other or both

NumberOfDiscs   *       4                               ; Number of discs requested by the broadcast
WriteOnlySize   *       &400                            ; Buffer size used at run time
FrameSize       *       &200
CreateSize      *       &10000                          ; Block size for *Create
EXT_Threshold   *       &20000
EXT_BlockSize   *       &10000

DiscNameSize    *       16
UserIdSize      *       21                              ; "TenChars**.TenChars**"

        AREA    |NetFS$$Code|,CODE,READONLY,PIC

Module_BaseAddr
        DCD     0                                       ; StartAsFS
        DCD     InitModule - Module_BaseAddr            ; Initialisation
        DCD     KillModule - Module_BaseAddr            ; Finalisation
        DCD     Service - Module_BaseAddr
        DCD     ModuleTitle - Module_BaseAddr
        DCD     HelpString - Module_BaseAddr
        DCD     UtilsCommands - Module_BaseAddr         ; Command Table
        DCD     NetFSSWI_Base
        DCD     SWIEntry - Module_BaseAddr
        DCD     SWINameTable - Module_BaseAddr
        DCD     0
        [ international_help
        DCD     MessageFileName - Module_BaseAddr
        |
        DCD     0
        ]
        DCD     ModuleFlags - Module_BaseAddr

        GET     Memory.s

        MACRO
        HandleFlags $R, $URD, $CSD, $LIB, $Flip
        [       "$R" = "" :LOR: "$URD" = "" :LOR: "$CSD" = "" :LOR: "$LIB" = ""
        !       1,"Syntax is: HandleFlags register, URD, CSD, LIB [, Flip]
        ]
        [       "$Flip" = ""
        MOV     $R, #(Use$URD.Handle:SHL:URDSlotShift)+(Use$CSD.Handle:SHL:CSDSlotShift)+(Use$LIB.Handle:SHL:LIBSlotShift)
        |
        MOV     $R, #(Use$URD.Handle:SHL:URDSlotShift)+(Use$CSD.Handle:SHL:CSDSlotShift)+(Use$LIB.Handle:SHL:LIBSlotShift)+FlipLibDirBit
        ]
        MEND

        MACRO
        Err     $name
        ALIGN
Error$name
        DCD     ErrorNumber_$name
        DCB     ErrorString_$name
        DCB     0
        ALIGN
        MEND

        SUBT    Module entry stuff
        OPT     OptPage
ModuleTitle
        DCB     "NetFS", 0
        ALIGN

HelpString
        DCB     "NetFS", 9, 9, "$Module_MajorVersion ($Module_Date)"
        [ Module_MinorVersion <> ""
        DCB     " $Module_MinorVersion"
        ]
        DCB     0
        ALIGN

ModuleFlags
        [       :LNOT:No32bitCode
        DCD     ModuleFlag_32bit
        |
        DCD     0
        ]

        SUBT    Initialisation code
        OPT     OptPage

InitModule      ROUT
        Push    "r0-r4, lr"
        MOV     r4, r12                                 ; Preserve the pointer to give to FileSwitch
        LDR     r3, [ r12 ]
        TEQ     r3, #0
        MOVNE   wp, r3
        BNE     ReInitialisation
        MOV     r0, #0
        MOV     r1, #-1
        SWI     XEconet_SetProtection                   ; Do a read to discover if Econet is there
        BVS     EconetError
        LDR     r3, =:INDEX: TotalRAMRequired
        BL      MyClaimRMA
        BVS     ExitInitialisation
        STR     r2, [ r12 ]
        MOV     wp, r2
        ADR     r0, AliasForLogon
        SWI     XOS_CLI
        BVS     ExitInitialisation
        [       :LNOT: OldOs
        BL      TerritoryStarted
        ]
        B       StoreClaimed

AliasForLogon
        DCB     "Set Alias$$I IF NOT((""%0""=""AM"")OR(""%0""=""am"")"
        DCB     "OR(""%0""=""Am"")OR(""%0""=""aM""))"
        DCB     " THEN %I %*0 ELSE %Net|m%Logon %*1", 13
        ALIGN

EconetError
        LDR     r14, [ r0 ]
        LDR     r3, =ErrorNumber_NoSuchSWI
        TEQ     r14, r3
        [       UseMsgTrans
        BNE     ExitInitialisation
        ADR     Error, ErrorNoEco
        MOV     r1, #0
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        B       ExitInitialisation

ErrorNoEco
        DCD     ErrorNumber_NoEconet
        DCB     "NoEco", 0
        ALIGN
        |       ; UseMsgTrans
        ADREQ   r0, ErrorNoEconet
        SETV
        B       ExitInitialisation

        Err     NoEconet
        ALIGN
        ]       ; UseMsgTrans
ReInitialisation
StoreClaimed

        [ UseMsgTrans
      [ standalone
        ADRL    r0, ResourceFilesList
        SWI     XResourceFS_RegisterFiles
        BVS     ExitInitialisation
      ]
        ]

        ASSERT  ((EndOfInitialisationData - InitialisationData):AND:3)=0
        MOV     r3, #EndOfInitialisationData - InitialisationData - 4
        ADR     r2, InitialisationData
10
        LDR     r0, [ r2, r3 ]
        STR     r0, [ wp, r3 ]                          ; Note that the initialised data is
        DECS    r3, 4                                   ; at the start of workspace
        BPL     %10

        MOV     r0, #FSControl_AddFS
        ADR     r1, Module_BaseAddr
        LDR     r2, =FSInfoBlock - Module_BaseAddr
        MOV     r3, r4                                  ; The address of my private word
        SWI     XOS_FSControl
        [       :LNOT: OldOs
        MOVVC   r1, #0
        MOVVC   r2, #Dir_Current
        BLVC    SetDir
        MOVVC   r2, #Dir_Previous
        BLVC    SetDir
        MOVVC   r2, #Dir_UserRoot
        BLVC    SetDir
        MOVVC   r2, #Dir_Library
        BLVC    SetDir
        ]
        BVS     ExitInitialisation
ClaimEvent
        MOV     r0, #EventV
        ADRL    r1, Event
        MOV     r2, wp
        SWI     XOS_Claim                               ; Start up the cache task
        MOVVC   r0, #OsByte_EnableEvent
        MOVVC   r1, #Event_Econet_Rx
        SWIVC   XOS_Byte
        MOVVC   r1, #Service_NetFS
        SWIVC   XOS_ServiceCall
ExitInitialisation
        STRVS   r0, [ sp ]
        Pull    "r0-r4, pc"

ServiceTable
        DCD     0
        DCD     ServiceMain - Module_BaseAddr
        ASSERT  Service_Reset > Service_UKCommand
        ASSERT  Service_FSRedeclare > Service_Reset
        ASSERT  Service_EconetDying > Service_FSRedeclare
        ASSERT  Service_ResourceFSStarting > Service_EconetDying
        ASSERT  Service_TerritoryStarted > Service_ResourceFSStarting
        ASSERT  Service_Portable > Service_TerritoryStarted
        DCD     Service_UKCommand
        DCD     Service_Reset
        DCD     Service_FSRedeclare
        DCD     Service_EconetDying
      [ standalone
        DCD     Service_ResourceFSStarting
      ]
        [       :LNOT: OldOs
        DCD     Service_TerritoryStarted
        DCD     Service_Portable
        ]
        DCD     0

        DCD     ServiceTable - Module_BaseAddr
Service ROUT
        MOV     r0, r0
        TEQ     r1, #Service_FSRedeclare
        TEQNE   r1, #Service_UKCommand
        TEQNE   r1, #Service_EconetDying
        TEQNE   r1, #Service_Reset
      [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
      ]
        [       :LNOT: OldOs
        TEQNE   r1, #Service_Portable
        TEQNE   r1, #Service_TerritoryStarted
        ]
        MOVNE   pc, lr
ServiceMain
        TEQ     r1, #Service_FSRedeclare
        BEQ     RedeclareFilingSystem
        LDR     wp, [ r12 ]
        TEQ     r1, #Service_UKCommand
        BEQ     FileServerCommand
        TEQ     r1, #Service_EconetDying
        BEQ     FlushNameCache
      [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BEQ     ReRegisterResourceFiles
      ]
        [       :LNOT: OldOs
        TEQ     r1, #Service_Portable
        BEQ     Portable
        TEQ     r1, #Service_TerritoryStarted
        BEQ     TerritoryStarted
        ]
        ;       TEQ r1, #Service_Reset                  ; Falls through for Service_Reset
        ;       MOVNE pc, lr
        ;       Now check reset was NOT hard
        Push    "r0-r4, lr"
        MOV     r0, #OsByte_RW_LastResetType
        MOV     r1, #0
        MOV     r2, #255
        SWI     XOS_Byte                                ; Read last reset type, only do reset when it was soft
        TEQ     r1, #0
        BEQ     ClaimEvent
        Pull    "r0-r4, pc"

        [       :LNOT: OldOs
Portable
        TEQ     r2, #ServicePortable_TidyUp             ; Is Econet begging for it?
        MOVNE   pc, lr                                  ; No, so who cares?
        Push    "r0, r4, lr"
        BL      StopCache                               ; Release the required resources
        Pull    "r0, r4, pc"

TerritoryStarted
        Push    "r0, lr"
        MOV     r0, #-1
        SWI     XTerritory_UpperCaseTable
        SUBVSS  r0, r0, r0                              ; Zero means no table (and clear V)
        STR     r0, UpperCaseTable
        Pull    "r0, pc"
        ]

        [ standalone
ReRegisterResourceFiles
        Push    "r0, lr"
        ADRL    r0, ResourceFilesList
        MOV     lr, pc                                  ; Make a return link
        MOV     pc, r2                                  ; Enter ResourceFS
        Pull    "r0, pc"
        ]

RedeclareFilingSystem                                   ; to FileSwitch
        Push    "r0-r3, lr"
        MOV     r0, #FSControl_AddFS
        ADRL    r1, Module_BaseAddr
        LDR     r2, =FSInfoBlock - Module_BaseAddr
        MOV     r3, r12                                 ; The address of my private word
        SWI     XOS_FSControl
        Pull    "r0-r3, pc"


KillModule      ROUT                                    ; Totally ignore all errors in this section
        Push    "r0-r2, lr"
        LDR     wp, [ r12 ]
        BL      FlushNameCache
        BL      FlushAnotherTxList
        MOV     r0, #OsByte_DisableEvent
        MOV     r1, #Event_Econet_Rx
        SWI     XOS_Byte
        MOV     r0, #EventV
        ADRL    r1, Event
        MOV     r2, wp
        SWI     XOS_Release
        MOV     r1, #Service_NetFSDying
        SWI     XOS_ServiceCall
        MOV     r0, #FSControl_RemoveFS
        ADRL    r1, FilingSystemName
        SWI     XOS_FSControl
        LDR     r2, Contexts
FlushContextsLoop
        TEQ     r2, #NIL                                ; Have we got to the end of the chain ??
        BEQ     FlushContextsFinish
        LDR     r1, [ r2, #Context_Link ]               ; Get the next link
        BL      MyFreeRMA
        BVS     FlushContextsFinish
        MOV     r2, r1                                  ; Meet the entry conditions
        B       FlushContextsLoop
FlushContextsFinish
        BL      FlushAnotherTxList
        [       UseMsgTrans
        LD      r0, MessageBlockAddress                 ; Is it open?
        MOV     r1, #0
        ST      r1, MessageBlockAddress                 ; Mark it as closed
        TEQ     r0, #0
        SWINE   XMessageTrans_CloseFile                 ; Close it if it was open
      [ standalone
        ADRL    r0, ResourceFilesList
        SWI     XResourceFS_DeregisterFiles
      ]
        ]       ; UseMsgTrans
        CLRV                                            ; Note that this can't fail
        Pull    "r0-r2, pc"

MyReadCMOS
        Push    "r1, lr"
        MOV     r0, #OsByte_ReadCMOS
        SWI     XOS_Byte
        Pull    "r1, pc"

MyWriteCMOS
        Push    "r1, lr"
        MOV     r0, #OsByte_WriteCMOS
        SWI     XOS_Byte
        Pull    "r1, pc"

        [       UseMsgTrans
MakeError       ROUT
        Push    "r4, r5, lr"
        MOV     r4, #0
DoMakeError1
        MOV     r5, #0
        BL      MessageTransErrorLookup2
        Pull    "r4, r5, pc"

MakeErrorWithModuleName
        Push    "r4, r5, lr"
        ADR     r4, ModuleTitle
        B       DoMakeError1

MessageTransErrorLookup2
        Push    "r1-r3, r6, r7, lr"
        [       Debug
        ADD     r14, r0, #4
        DSTRING r14, "Looking up error token "
        ]
        LD      r1, MessageBlockAddress
        CMP     r1, #0                                  ; Clears V
        BNE     DoErrorLookup
        MOV     r7, r0
        ADR     r0, MessageBlock
        ADR     r1, MessageFileName
        MOV     r2, #0                                  ; Use the file where she lies
        SWI     XMessageTrans_OpenFile
        ADRVC   r1, MessageBlock
        STRVC   r1, MessageBlockAddress
        MOV     r0, r7                                  ; Preserve R0 even in the error case
DoErrorLookup
        MOV     r2, #0
        MOV     r3, #0
        MOV     r6, #0
        MOV     r7, #0
        SWIVC   XMessageTrans_ErrorLookup
        [       Debug
        ADD     r14, r0, #4
        DSTRING r14, "Results in "
        ]
        Pull    "r1-r3, r6, r7, pc"

MessageFileName
        DCB     "Resources:$.Resources.NetFS.Messages", 0
        ALIGN

MessageTransGSLookup0
        Push    "r4, r5, lr"
        MOV     r4, #0
        MOV     r5, #0
        BL      MessageTransGSLookup2
        Pull    "r4, r5, pc"

MessageTransGSLookup1
        Push    "r5, lr"
        MOV     r5, #0
        BL      MessageTransGSLookup2
        Pull    "r5, pc"

MessageTransGSLookup2
        Push    "r6, r7, lr"
        LD      r0, MessageBlockAddress
        CMP     r0, #0                                  ; Clears V
        BNE     DoGSLookup
        Push    "r1, r2"
        ADR     r0, MessageBlock
        ADR     r1, MessageFileName
        MOV     r2, #0                                  ; Use the file where she lies
        SWI     XMessageTrans_OpenFile
        ADRVC   r0, MessageBlock
        STRVC   r0, MessageBlockAddress
        Pull    "r1, r2"
DoGSLookup
        MOV     r6, #0
        MOV     r7, #0
        SWIVC   XMessageTrans_GSLookup
        Pull    "r6, r7, pc"

        ]       ; UseMsgTrans

MyClaimRMA
        Push    "r0, lr"
        [ {FALSE} ; Debug
        DREG    r3, "Claiming &", cc
        ]
        MOV     r0, #ModHandReason_Claim
        B       CallOSModule

MyFreeRMA
        Push    "r0, lr"
        [ {FALSE} ; Debug
        LDR     r0, [ r2, #-4 ]
        DREG    r0, "Freeing &", cc
        ]
        MOV     r0, #ModHandReason_Free
CallOSModule
        SWI     XOS_Module
        [ {FALSE} ; Debug
        DREG    r2, " bytes at &"
        ]
        STRVS   r0, [ sp, #0 ]
        Pull    "r0, pc"

ConvertStatusToError
        Push    lr
        [       UseMsgTrans
        MOV     r1, #0
        MOV     r2, #0
        |
        ADR     r1, ErrorBuffer
        MOV     r2, #?ErrorBuffer
        ]
        SWI     XEconet_ConvertStatusToError
        Pull    pc

        LTORG

        GET     Interface.s
        GET     FileSystem.s
        GET     Commands.s
        GET     Configure.s
        GET     OsFile.s
        GET     Random.s
        GET     Functions.s
        GET     Catalog.s
        GET     TokHelpSrc.s

      [ standalone
ResourceFilesList
        ResourceFile $MergedMsgs, Resources.NetFS.Messages
        DCD     0
      ]

      [ Debug
        InsertDebugRoutines
      ]

        END
