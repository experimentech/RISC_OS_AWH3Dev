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
; > DeviceSrc

                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:ModHand
                GET     hdr:DeviceFS
                GET     hdr:Debug
                GET     hdr:DDVMacros
                 
                ^ 0, wp
device_handle   # 4                                             ; device handle / =0 if not registered
workspace       * :INDEX: @                                     ; index for workspace size

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; A test device, this simply installs itself into the system.
;                                                             
                                                              
module_start    & 0                                             ; no start code
                & init -module_start                            ; init code offset
                & final -module_start                           ; finalise code offset
                & 0

                & title -module_start                           ; start code base address
                & help -module_start                            ; help string
                & 0

title           = "TestDevice", 0
help            = "Test Device", 9, "0.00 (06 Apr 91)", 0
                ALIGN
                     
device_name     = "parasol", 0
device_name1    = "cereal", 0
device_name2    = "test.device", 0
device_name3    = "test.wobbly", 0
device_name4    = "zanadoo", 0
                ALIGN


; block required to register devices with the filing system.
;

device_block    & device_name -.                                ; offset to the device name
                & 2_11                                          ; suitable flags
                & 0
                & 1024
                & 0
                & 1024                                          ; setup the parameters
                & 0

                & 0

;                & device_name1 -.                               ; offset to the device name
;                & 2_10                                          ; suitable flags
;                & 0
;                & 1024
;                & 0
;                & 1024                                          ; setup the parameters
;
;                & device_name2 -.                               ; offset to the device name
;                & 2_10                                          ; suitable flags
;                & 0
;                & 1024
;                & 0
;                & 1024                                          ; setup the parameters
;                                
;                & device_name3 -.                               ; offset to the device name
;                & 2_10                                          ; suitable flags
;                & 0
;                & 1024
;                & 0
;                & 1024                                          ; setup the parameters
;                                
;                & device_name4 -.                               ; offset to the device name
;                & 2_10                                          ; suitable flags
;                & 0
;                & 1024
;                & 0
;                & 1024                                          ; setup the parameters
;                                
;                = 0                                             ; termiate the list correctly

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Register a device with device fs, claim some workspace and fart around.
;
                                                                         
init            ROUT

                Push    "r1-r3, lr"

                LDR     r2, [wp]
                TEQ     r2, #0                                  ; does the thing have any workspace yet?
                BNE     %10

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace
                SWI     XOS_Module                              ; attempt to claim, if V clear then r2 -> workspace
                Pull    "r1-r3, pc", VS                         ; return if it goes bang!!!!!!!!!!!

                STR     r2, [wp]
10              
                MOV     wp, r2                                  ; -> workspace

                MOV     r0, #0
                STR     r0, device_handle                       ; reset my device handle
                
                MOV     r0, #2_10                                
                ADR     r1, device_block                        ; -> device list
                ADR     r2, doofer                              ; -> device code
                MOV     r3, #0                                  ;  = private word
                MOV     r4, wp                                  ; -> workspace
                ADR     r5, validationstring
                MOV     r6, #1                                  ; max number of RX streams
                MOV     r7, #1                                  ; max number of TX streams
                SWI     XDeviceFS_Register
                STRVC   r0, device_handle

                Pull    "r1-r3, pc"

validationstring
;                =       "A/N", 0,0,0,0
                =       "ABC,DEF/N/N/NGHI,JKL,MNO/S",0
                ALIGN

doofer          
                TEQ     r0, #0                                  ; if not initialise
                MOVNES  pc, lr                                  ; then exit doing nothing

                LDR     r2, [r6, #0]
                DREG    r2, "Word 0 = "
                LDR     r2, [r6, #4]
                DREG    r2, "Word 1 = "
                LDR     r2, [r6, #8]
                DREG    r2, "Word 2 = "
                LDR     r2, [r6, #12]
                DREG    r2, "Word 3 = "

                MOV     r2, #1                                  ; return non-zero stream handle
                MOVS    pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This bit handles the device doofing around when it gets bonked!
;
                                                                 
final           ROUT

                Push    "r2-r3, lr"

                LDR     wp, [wp]                                ; -> workspace

                LDR     r0, device_handle
                TEQ     r0, #0                                  ; is the goat head registered?
                SWINE   XDeviceFS_Deregister

                Pull    "r2-r3, pc",,^                          ; return any errors

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                InsertDebugRoutines

                END


