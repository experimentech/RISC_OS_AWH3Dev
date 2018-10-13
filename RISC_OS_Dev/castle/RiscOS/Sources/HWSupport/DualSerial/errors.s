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
; > Errors
;
;               Copyright 1996 Acorn Network Computing
;
;  This material is the confidential trade secret and proprietary
;  information of Acorn Network Computing. It may not be reproduced,
;  used, sold, or transferred to any third party without the prior
;  written consent of Acorn Network Computing. All rights reserved.
;
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                ^ ErrorBase_NCSerial
                AddError Serial_BadDeviceReasonCode,"E1"
                AddError Serial_BadBaud,            "E2"
                AddError Serial_BadData,            "E3"
                AddError Serial_BadIOCtlReasonCode, "E4"
                AddError Serial_BadIOCtlParameter,  "E5"
                AddError Serial_StreamInUse,        "E6"
                AddError Serial_NoHAL,              "E7"
                AddError Serial_UnknownSerialOp,    "E8"
                AddError Serial_BadControlOp,       "E9"
                AddError Serial_NoSplitBaudRates,   "EA"



; call/return the relevant error based on the international flag.

                MACRO
$label          DoError         $cc
              [ international
$label          B$cc    MakeError
              |
                ASSERT No32bitCode
$label          ORR$cc.S pc, lr, #VFlag
              ]
                MEND


                END

