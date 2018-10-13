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
;------------------------------------------------------------------------------
;
; RISC OS SCSI log module
;
; Author : R.C.Manby
; � Acorn Computers Ltd
;
; History
;   4-Jul-88: RCM: Started
;
;------------------------------------------------------------------------------

                GBLL trace
trace           SETL {FALSE}

        AREA |!!!Module|,CODE,READONLY

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:SCSI
        GET     Hdr:SCSIErr
        GET     Hdr:Podule
        GET     VersionASM
        GET     hdr.SCSIEquates

;==============================================================================
;
; Macro definitions
; =================
;
;------------------------------------------------------------------------------
;
        MACRO
        MySWI   $swiname
        ASSERT  SCSILogSWI_Base+(.-SCSILog_SWItable)/4 = $swiname
        B       SWI_$swiname
        MEND


        MACRO
        mess    $cond,$s1,$s2,$s3,$s4,$s5
 [ trace
        B$cond  %F11
        BAL     %F21
11
        Push    "LR"
        SWI     OS_WriteS
 [ "$s1"="NL"
 = CR,LF
 |
 = "ScsiLog: $s1"
 ]
 [ "$s2"=""
 |
  [ "$s2"="NL"
  = CR,LF
  |
  = "$s2"
  ]
  [ "$s3"=""
  |
   [ "$s3"="NL"
   = CR,LF
   |
   = "$s3"
   ]
   [ "$s4"=""
   |
    [ "$s4"="NL"
    = CR,LF
    |
    = "$s4"
    ]
    [ "$s5"=""
    |
     [ "$s5"="NL"
     = CR,LF
     |
     = "$s5"
     ]
    ]
   ]
  ]
 ]
        =       0
        ALIGN
        Pull    "LR"
21
 ]
        MEND


        MACRO
        traceswi $s1
        mess , "SWI_SCSI_$s1", NL
        MEND


        MACRO
        tracerc $s1
        mess , "   $s1", NL
        MEND
;
;
;==============================================================================



;==========================================================================
;
; Module start
;

        ASSERT  (.=Module_BaseAddr)     ; Winge if we've generated code

        DCD     0                                   ; 0  Start - Not an application
        DCD     ModInit           - Module_BaseAddr ; 4  Initialisation
        DCD     0                                   ; 8  Die (aka Finalisation)
        DCD     0                                   ; C  Service
        DCD     ModTitleStr       - Module_BaseAddr ; 10 Title
        DCD     ModHelpStr        - Module_BaseAddr ; 14 Help string
        DCD     0                                   ; 18 Combined Help/* command table
        DCD     SCSILogSWI_Base                     ; 1C Chunk number of SWIs intercepted (MySWIBase)
        DCD     SCSILog_SWIdecode - Module_BaseAddr ; 20 Offset of code to handle SWIs (MySWIDecode)
        DCD     SCSILog_SWInames  - Module_BaseAddr ; 24 SWI Decoding table (MySWINames)
        DCD     0                                   ; 28 SWI Decoding code
        DCD     0                                   ; 32 Messages filename
        DCD     ModFlags          - Module_BaseAddr ; 36 Flags

ModTitleStr
        DCB     "SCSILog",0
        ALIGN

ModHelpStr
        DCB     "SCSILog",&09,&09,"$Module_MajorVersion ($Module_Date)",0
        ALIGN

ModFlags
 [ No32bitCode
        DCD     0
 |
        DCD     ModuleFlag_32bit
 ]



;==============================================================================
;
; ModInit - Module Initialisation entry
; =======
;
; On entry (in supervisor mode)
;   R10 -> environment string
;   R11  = 0            if loaded from filing system
;        > &03000000    if loaded from a podule and is the base of the podule
;        = 1..&02FFFFFF if being reincarnated and is the number of other
;                       incarnations
;   R12 -> private word (private word <> 0 implies reinitialisation)
;   R13  = supervisor stack pointer (FD stack)
;
; Must preserve processor mode, interrupt state, R7..R11,R13
; Can corrupt R0..R6,R12,R14 and flags
;
; Return by MOV PC,R14 with VC or VS & R0->error
;
ModInit
        mess    ,"ModInit",NL
        Push    "R10,R11,LR"

        LDR     R2,[R12]                ; If reinitialisation,
        TEQ     R2,#0                   ;
        BNE     exitModInit             ; do nothing
                
        CMP     R11,#&03000000          ; Loaded from a podule,
        BHS     ModIn_20                ; R11 is podule base address
        CMP     R11,#0
        BNE     exitModInit             ; If <>0, new incarnation, do nothing

;
; R11=0, means loaded from filing system, so look for a single digit podule
; number in the environment string (R10 points after the module name).
;
ModIn_10
        LDRB    R0,[R10],#1             ; Skip leading spaces
        CMP     R0,#" "                 ;
        BEQ     ModIn_10                ;

        SUBS    R3,R0,#"0"              ; Accept "0"..."7",
        MOVLT   R3,#0                   ; assume anything else (non-digit
        CMP     R3,#7                   ; or unspecified is podule zero).
        MOVHI   R3,#0                   ;
        SWI     XPodule_HardwareAddress
        LDRVC   R14,=Podule_BaseAddressBICMask
        BICVC   R11,R3,R14              ; Zap the CMOS RAM base
        MOVVS   R11,#0
ModIn_20
        BIC     R11,R11,#PoduleSpeedMask    ;Reduce to slow access address

        SWI     XSCSI_List              ; Ask ScsiDriver for a list of Podule base
        MOVVS   R0,#0                   ; addresses
        MOV     R3,#0

        Push    R0
        BVS     ModIn_40                ; ScsiDriver not installed (or knows nothing???)
ModIn_30
        LDR     R1,[R0],#4              ; Count number of podule addresses in list
        TEQ     R1,R11                  ;  (If R11 is a duplicate of one of the list
        MOVEQ   R11,#0                  ;   values, kill it).
        TEQ     R1,#0                   ; Don't count if null terminator
        ADDNE   R3,R3,#4                  
        BNE     ModIn_30                  
ModIn_40
        Pull    "R1"
        CMP     R11,#0                  ; Include latest entry?
        ADDNE   R3,R3,#4                  
        ADD     R3,R3,#4                ; And space for null terminator

        MOV     R0,#ModHandReason_Claim
        SWI     XOS_Module              ; In R3=size, Out R2->block
        BVS     err_NoRoom_forworkspace

        STR     R2,[R12]                ; Store ->WorkSpace in private word
                                          
        TEQ     R1,#0                   ; If no list obtained from ScsiDriver
        BEQ     ModIn_60                ;  then skip
ModIn_50
        LDR     R0,[R1],#4              ; else Copy null terminated list
        TEQ     R0,#0
        STRNE   R0,[R2],#4
        BNE     ModIn_50

ModIn_60
        CMP     R11,#0
        STRNE   R11,[R2],#4             ; Add our podule address to end of list
        MOV     R11,#0
        STR     R11,[R2],#4             ; Terminate the list

exitModInit
        Pull    "R10,R11,PC"

err_NoRoom_forworkspace
        ADR     R0,ErrorBlock_SCSI_NoRoom
        SETV
        B       exitModInit

        MakeErrorBlock SCSI_NoRoom      ; "No room for SCSI workspace"
;
;
;==============================================================================


;==============================================================================
;
; SCSILog SWI names and SWI dispatch
;
;------------------------------------------------------------------------------
;
SCSILog_SWInames
        DCB     "SCSI",0
        DCB     "LogVersion",0
        DCB     "LogList",0
        DCB     0
        ALIGN
;
;
;------------------------------------------------------------------------------
;
; SWI decoding
; ============
;
; On entry
;   R11  = SWI number within SCSILog_SWI block
;   R12 -> private word
;   R13  = Stack pointer
;
; On exit
;   R0..R7 return results, or are preserved
;
; Entered in SVC_mode with callers interrupt state
;
; May corrupt R10..R12, return with MOVS PC,R14
;
SCSILog_SWIdecode
        mess    ,"SCSILog_SWIdecode - Entry", NL
        Push    "R0-R9,LR"

        LDR     WsPtr,[R12]
        CMP     R11,#maxSWI
        ASSERT  (SCSILog_SWItable-. =8) ; Table must follow code
        ADDCC   PC,PC,R11,ASL #2
        B       err_SWIunkn
SCSILog_SWItable
        MySWI   SCSI_LogVersion
        MySWI   SCSI_LogList

maxSWI  * (.-SCSILog_SWItable):SHR:2

err_SWIunkn
        ADR     R0,ErrorBlock_SCSI_SWIunkn
        SETV
        B       exitSWIdecode

        MakeErrorBlock SCSI_SWIunkn     ; "Unknown SCSI SWI number"

exitSWIdecode
        STRVS   R0,StackedR0            ; Overwrite stacked R0 with ->error
        Pull    "R0-R9,LR"
        mess    ,"SCSILog_SWIdecode - Exit", NL
      [ :LNOT:No32bitCode
        TEQ     PC,PC
        MOVEQ   PC,LR
      ]
        ORRVS   LR,LR,#V_bit            ; Stacked Link had VClear, so set if error
        MOVS    PC,LR
;
;
;==============================================================================


;==============================================================================
;
; SWI_SCSI_LogVersion
; ===================
;
; On exit
;   R0 bits 0..7  software minor version number
;      bits 8..31 software major version number (100 for 1.00)
;   R1 bitset of  software features
;
SWI_SCSI_LogVersion
        traceswi "LogVersion"
        ADR     R0,VersionBlk
        LDMIA   R0,{R0,R1}              ; Pickup return values
        STMIA   R13,{R0,R1}             ; Write to StackedR0..StackedR1
        B       exitSWIdecode           ; will be popped on return

VersionBlk
        DCD SoftwareVersionNumber
        DCD SoftwareExtensions
;
;
;==============================================================================


;==============================================================================
;
; SWI SCSI_LogList
; ================
;
; On exit
;   R0 -> Null terminated list of podule addresses
;
SWI_SCSI_LogList
        traceswi "LogList"
        STR     WsPtr,StackedR0

        B       exitSWIdecode
;
;
;==============================================================================

        END

