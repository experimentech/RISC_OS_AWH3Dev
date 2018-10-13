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
; > Serial

                GET     Hdr:ListOpts
                GET     Hdr:Macros
                GET     Hdr:System
                GET     Hdr:ModHand
                GET     Hdr:Machine.<Machine>
                GET     Hdr:FSNumbers
                GET     Hdr:HighFSI
                GET     Hdr:NewErrors
                GET     Hdr:DevNos
                GET     Hdr:Services
                GET     Hdr:Symbols
                GET     Hdr:UpCall
                GET     Hdr:NdrDebug
                GET     Hdr:DDVMacros
                GET     Hdr:CMOS
                GET     Hdr:DeviceFS
                GET     Hdr:Serial
                GET     Hdr:RS423
                GET     Hdr:Buffer
                $GetIO
                GET     Hdr:IO.IOEB
                GET     Hdr:MsgTrans
                GET     Hdr:Proc
                GET     Hdr:ResourceFS
                GET     Hdr:Portable
                GET     Hdr:HALEntries
                GET     Hdr:HostFS
                GET     Hdr:OsBytes

                AREA    |Serial$$Code|,  CODE, READONLY, PIC

                GBLL    debug
                GBLL    hostvdu
                GBLL    international
                GBLL    NewSplitScheme  ; if true, always sets hardware baud rate to RX rate
                                        ;          can set TX to something different and it
                                        ;          reads back what you set
                                        ;          opening TX stream with split baud rates gives error
                                        ; if false, always sets both rates to what you just set (RX or TX)
                                        ;          doesn't give an error from open
                GBLL    KickSerialTX    ; kick serial TX on 710/665 to work round TX irqs stopping for no reason
                GBLL    Fix710TXEnable  ; on 710 must write with TX enable clear before set
                GBLL    NewTXStrategy   ; always use FIFOs if enabled but if TX rate <= 19200 then only TX one byte at a time
                GBLL    PowerControl    ; enable power control calls

                GBLL    standalonemessages
 [ :DEF: standalone
standalonemessages SETL standalone
 |
standalonemessages SETL {FALSE}
 ]


debug           SETL    false
hostvdu         SETL    false
international   SETL    true
NewSplitScheme  SETL    false           ; (mainly because vt220 can't cope with an error from SerialOp(3))
KickSerialTX    SETL    true
Fix710TXEnable  SETL    :LNOT: KickSerialTX     ; not needed if KickSerialTX is true
NewTXStrategy   SETL    true
PowerControl    SETL    false           ; (needs HAL interface defining)

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; debug options


init            SETD    false           ; for module startup etc...
final           SETD    false           ; for module finalisation...
baud710         SETD    false           ; debugging the 710 baud setup
flags710        SETD    true            ; flag control on 710
inter           SETD    false           ; debugging of internationalisation
interface       SETD    false           ; debugging the DeviceFS to devices
open            SETD    false           ; debugging stream opening
close           SETD    false           ; debugging stream closing

                GET     VersionASM
                GET     macros.s
                GET     errors.s
                GET     main.s
                GET     common.s
                GET     serialhal.s
                GET     ioctl.s

              [ debug
                InsertNDRDebugRoutines
              ]

                END
