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
;
;               Copyright 1996 Acorn Network Computing
;
;  This material is the confidential trade secret and proprietary
;  information of Acorn Network Computing. It may not be reproduced,
;  used, sold, or transferred to any third party without the prior
;  written consent of Acorn Network Computing. All rights reserved.
;
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;



; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; workspace

                        ^ 0, wp
Flags                   # 4     ; global f_ flags
BuffManWkSpace          # 4     ; buffer manager workspace
BuffManService          # 4     ; address of buffer manager routine
MessagesWorkspace       # 16    ; needed for messages routines
DeviceHandle            # 4     ; handle returned from DeviceFS_Register
WaitForIRQsToFire       # 4     ; -> routine to allow pending IRQs to fire

InputHandle             # 4     ;  = DeviceFS handle used for input stream
OutputHandle            # 4     ;  = DeviceFS handle used for output stream

InputFSHandle           # 4     ;  = file switch handle of input stream
OutputFSHandle          # 4     ;  = file switch handle of output stream

InputBufferHandle       # 4     ;  = buffer handle used for input stream  (-1 if none)
OutputBufferHandle      # 4     ;  = buffer handle used for output stream (-1 if none)

InputBufferPrivId       # 4     ;  = buffer managers private buffer id
OutputBufferPrivId      # 4     ;  = buffer managers private buffer id

PutCharOutputFileHandle # 4     ;  = file handle for putchar stream (0 if none)

PortNumber              # 4     ;
IRQDeviceNumber         # 4     ;
HAL_UARTStartUp         # 4     ; setup the uart
HAL_UARTShutdown        # 4     ; shutdown the uart
HAL_UARTFeatures        # 4     ; report features
HAL_UARTReceiveByte     # 4     ; receive a byte, optionally return status
HAL_UARTTransmitByte    # 4     ; transmit a byte
HAL_UARTLineStatus      # 4     ; return status (of last reveived byte)
HAL_UARTInterruptEnable # 4     ; enable interrupts
HAL_UARTRate            # 4     ;
HAL_UARTFormat          # 4     ;
HAL_UARTFIFOSize        # 4     ;
HAL_UARTFIFOClear       # 4     ;
HAL_UARTFIFOEnable      # 4     ;
HAL_UARTFIFOThreshold   # 4     ;
HAL_UARTInterruptID     # 4     ;
HAL_UARTBreak           # 4     ;
HAL_UARTModemControl    # 4     ;
HAL_UARTModemStatus     # 4     ;
HAL_UARTDevice          # 4     ;
HAL_IRQClear            # 4
    ! 0, "Assuming only one base address for the moment"
HAL_StaticBase          # 4


SerialDeviceFlags       # 4     ;  = serial flags
SerialRXBaud            # 1     ;  = baud rate (8bit) for RX
SerialTXBaud            # 1     ;  = baud rate (8bit) for TX
SerialXONXOFFChar       # 1     ;  = serial XON/XOFF character (8bit)
SerialCurrentError      # 1     ;  = current internal error code (8bit)
InputBufferSize         # 4     ;  = buffer size in bytes
OutputBufferSize        # 4     ;
InputBufferThreshold    # 4     ;  = input buffer threshold value being used
OutputBufferThreshold   # 4     ;
 [ :LNOT: NewTXStrategy
SerialBaudDivisor       # 4     ;  = current baud divisor (for 710/711/665)
 ]
SerialTxByteCount       # 1     ;  = used by TX IRQ routine to count bytes left to send
FIFOSize                # 1     ;  = TX FIFO size
FIFOTrigger             # 1     ;  = RX FIFO trigger value
                        # 1     ;  = unused

                        AlignSpace
DeviceFSBlock_size      * 40
DeviceFSBlock           # DeviceFSBlock_size
workspace               * :INDEX: @

f_SerialIRQ             * 1:SHL:0       ; set => IRQ owned for serial device
f_WeHaveMessages        * 1:SHL:1       ; set => we have messages
f_UseFIFOs              * 1:SHL:2       ; set => we can use FIFOs
f_FIFOsEnabled          * 1:SHL:3       ; set => FIFOs are enabled
f_Registered            * 1:SHL:4       ; set => registered with DeviceFS
f_DefaultPort           * 1:SHL:5       ; set => we get used for OS_SerialOp
f_HW_RTS_CTS            * 1:SHL:6       ; set => hardware RTS/CTS is used
f_TX_Threshold          * 1:SHL:7       ; set => transmitter empty IRQ is actually "TX FIFO under threshold", and may only change state once level is crossed (so on startup IRQ may not be firing). Use new LS_TXFull flag to know when to stop pushing bytes.

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; standard module declarations
                AREA  |DualSerial$$Code|, CODE, READONLY, PIC

module          & 0
                & init    -module               ; => initalise routine
                & final   -module               ; => finalise routine
                & service -module               ; => service trap

                & title -module                 ; => title string
                & help  -module                 ; => help string
                & 0                             ; => command table

 [ :LNOT: No32bitCode
                & 0
                & 0
                & 0
                & 0
                & 0
                & moduleflags - module          ; => module flags
 ]

title           = "Serial", 0

help            = "Serial", 9, 9, "$Module_MajorVersion ($Module_Date)"
 [ Module_MinorVersion <> ""
                = " $Module_MinorVersion"
 ]
 [ debug
                = " (Debug on)", 0
 ]
                = 0

                ALIGN

 [ :LNOT: No32bitCode
moduleflags     DCD ModuleFlag_32bit
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS declarations
device_name     = "Serial"
device_n        = "n", 0
                ALIGN
device_block    & device_name - device_block
                & DeviceFlag_BufferedDevice + DeviceFlag_DefinePathVariable
                & 8                             ; default RX buffer flags
                & 1024                          ; default RX buffer size
                & 8                             ; default TX buffer flags
                & 512                           ; default TX buffer size
                & 0                             ; reserved field (must be zero)

                & 0                             ; end of table
                ALIGN
device_block_end

                ASSERT  device_block_end - device_name = DeviceFSBlock_size

device_validation = "baud/ndata/nstop/nnoparity,even,odd/snohandshake,rts,xon,dtr/ssize/nthres/n",0
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Globals
resource_file = "Resources:$.Resources.DualSerial.Messages", 0

default_baud            * 0 ; i.e. 9600
default_data            * 0 ; i.e. 8n1, no parity
default_threshold       * 32
default_fifo_trigger    * 4

xonchar  * &11
xoffchar * &13

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Error declarations

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        MakeErrorBlock Serial_NoHAL
        MakeErrorBlock Serial_BadControlOp
        MakeErrorBlock Serial_BadBaud
        MakeErrorBlock Serial_StreamInUse

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This code handles the startup of the module, the routine must claim the
; required workspace and then initialise the driver.
;
init            Entry   "r7-r11", 20

                TEQ     R11, #0                 ; Loaded from filing system
                CMPNE   R11, #&03000000         ; ROM loaded
                BLO     %FT7                    ; We're a reincarnation

; Messages are registered by the base instantiation
 [ standalonemessages
                ADRL    r0, resource_file_block
                SWI     XResourceFS_RegisterFiles   ; ignore errors (starts on Service_ResourceFSStarting)
 ]

                LDR     r9, =EntryNo_HAL_UARTPorts
                MOV     r8, #0
                SWI     XOS_Hardware
                BVC     %FT2
                ADR     r0, ErrorBlock_Serial_NoHAL
                BL      MakeError
 [ standalonemessages
                MOV     r6, r0
              [ international
                BL      CloseMessages           ; close any messages files
              ]
                ADRL    r0, resource_file_block
                SWI     XResourceFS_DeregisterFiles
                MOV     r0, r6
 ]
                SETV
                EXIT

                ; We have to build the instantations in a callback, so that
                ; they know who they are, otherwise they think they're the base
2
                MOVS    r1, r0
                EXIT    EQ                      ; exit if no ports
                ADR     r0, build_instants
                SWI     XOS_AddCallBack

                EXIT

7
                LDR     r2, [r12]               ; r2 = &wp
                TEQ     r2, #0                  ; any workspace / warm start?
                BNE     %10

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace          ; r3  = amount of workspace

                SWI     XOS_Module
                EXIT    VS                      ; return if didn't work

                STR     r2, [wp]                ; wp = r2
10
                MOV     wp, r2                  ; wp -> workspace


                MOV     r0, #0
                STR     r0, Flags
                STR     r0, BuffManService
                STR     r0, BuffManWkSpace

                MOV     r0, #0                          ; Read feature flags and address of IRQ delay routine too
                MOV     r1, #0                          ; In case of unknown SWI error
                SWI     XOS_PlatformFeatures
                STR     r1, WaitForIRQsToFire

                SUB     r0, r11, #1             ; start counting at 0
                STR     r0, PortNumber
                BL      establish_device
;                BL      hardware_claim
                EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Callback to finish off initialisation
; On entry, r12 = number of instantiations.
;

build_instants Entry "r0-r4", 20
                ADR     r1, title
                MOV     r3, sp
3               LDRB    r2, [r1], #1           ; Copy over module name
                TEQ     r2, #0
                STRNEB  r2, [r3], #1
                BNE     %BT3
                MOV     r2, #'%'
                STRB    r2, [r3], #1

                ADD     r2, r12, #'0'            ; Start at top port
5               MOV     r4, r3                  ; remember current pointer
                STRB    r2, [r4], #1
                MOV     lr, #0
                STRB    lr, [r4], #1
                MOV     r0, #ModHandReason_NewIncarnation
                MOV     r1, sp
                SWI     XOS_Module
                SUBVC   r2, r2, #1
                TEQVC   r2, #'0'
                MOVVSS  r2, #0
                BNE     %BT5

                EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                LTORG
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle module close down.
;

final           Entry   "r0-r1"

                LDR     wp, [r12]               ; wp -> workspace
                TEQ     r12, #0
                BEQ     %FT40
; see if any streams are in use
                LDR     r0, InputHandle
                CMP     r0, #0
                LDREQ   r0, OutputHandle
                CMPEQ   r0, #0
                BEQ     %30

; generate an error
20
                PullEnv
                ADR     r0, ErrorBlock_Serial_StreamInUse
                B       MakeError
30
;                BL      hardware_release

; sort the hardware out
                MOV     r0, #serialctrl_Dying
                BL      CallDevice              ; ensure device quiescent
                BL      unregister_device
                EXIT
40
              [ international
                BL      CloseMessages           ; close any messages files
              ]
 [ standalonemessages
                ADRL    R0, resource_file_block
                SWI     XResourceFS_DeregisterFiles
 ]
                CLRV
                EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle service calls received by the module.
;
; Quickly test to see if they are of interest to use and pass on.

                ASSERT  Service_ResourceFSStarting < Service_DeviceFSStarting
                ASSERT  Service_DeviceFSStarting < Service_DeviceFSDying
                ASSERT  Service_DeviceFSDying < Service_SerialDevice
                ASSERT  Service_SerialDevice < Service_DeviceFSCloseRequest
servicetable    DCD     0
                DCD     serviceentry -module
 [ standalonemessages
                DCD     Service_ResourceFSStarting
 ]
                DCD     Service_DeviceFSStarting
                DCD     Service_DeviceFSDying
                DCD     Service_SerialDevice
                DCD     Service_DeviceFSCloseRequest
                DCD     0

                DCD     servicetable -module
service         ROUT
                MOV     r0, r0
                TEQ     r1, #Service_DeviceFSStarting
                TEQNE   r1, #Service_DeviceFSDying
                TEQNE   r1, #Service_DeviceFSCloseRequest
                TEQNE   r1, #Service_SerialDevice
 [ standalonemessages
                TEQNE   r1, #Service_ResourceFSStarting
 ]
                MOVNE   pc, lr

serviceentry
                LDR     wp, [r12]
                Entry   "r0"
                TEQ     wp, #0
                BEQ     serviceentry_base

; handle devicefs starting up
                TEQ     r1, #Service_DeviceFSStarting
                BNE     %10
                BL      register_device

                EXIT
10
; handle devicefs going down
                TEQ     r1, #Service_DeviceFSDying
                BNE     %20

                LDR     r0, Flags
                BIC     r0, r0, #f_Registered
                STR     r0, Flags
                MOV     r0, #0
                STR     r0, DeviceHandle

                EXIT
20
                TEQ     r1, #Service_DeviceFSCloseRequest
                BNE     %FT30

                LDR     lr, PutCharOutputFileHandle
                TEQ     lr, r2
                EXIT    NE                              ; if not our handle, then pass on service

                MOV     r0, #0                          ; our file handle is not in use any more
                STR     r0, PutCharOutputFileHandle     ; so zero it
                MOV     r1, r2
                SWI     XOS_Find                        ; close file, ignore errors
                MOV     r1, #0                          ; claim success (even if we got an error?)
                EXIT

30
                TEQ     r1, #Service_SerialDevice
                CMPEQ   r2, #-1                         ; is it from Serial Support?
                EXIT    NE
                LDR     lr, Flags      
                TST     lr, #f_DefaultPort              ; and we are the default serial port?
                PullEnv
                LDRNE   r0, DeviceHandle                ; yes, so setup device handle
                MOVNE   r1, #Service_Serviced
                MOV     pc, lr

                
serviceentry_base
 [ standalonemessages
                TEQ     r1, #Service_ResourceFSStarting
                BNE     %FT50                                   ; no so continue

                Push    "r0-r3"
                ADRL    r0, resource_file_block
                MOV     lr, pc
                MOV     pc, r2
                Pull    "r0-r3"
50
 ]
                EXIT


; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; establish device
;
                MACRO
                GetHalEntry $entry

                MOV     r9, #EntryNo_$entry
                SWI     OS_Hardware
                STR     r0, $entry
                MEND

establish_device Entry "r0-r3,r8-r9"

                MOV     r8, #0
                LDR     r9, =EntryNo_HAL_UARTDefault
                MVN     r0, #0
                SWI     XOS_Hardware
                MVNVS   r0, #0
                LDR     r1, PortNumber
                TEQ     r0, r1
                LDREQ   r1, Flags
                ORREQ   r1, r1, #f_DefaultPort
                STREQ   r1, Flags
                
                MOV     r0, #0
                STR     r0, DeviceHandle
                STR     r0, InputHandle
                STR     r0, OutputHandle
                STR     r0, InputFSHandle
                STR     r0, OutputFSHandle
                STR     r0, PutCharOutputFileHandle
                STR     r0, SerialDeviceFlags
                STRB    r0, SerialRXBaud
                STRB    r0, SerialTXBaud
                STRB    r0, SerialXONXOFFChar
                STRB    r0, SerialCurrentError
                STR     r0, InputBufferSize
                STR     r0, InputBufferThreshold
                STR     r0, OutputBufferSize
                STR     r0, OutputBufferThreshold
              [ :LNOT: NewTXStrategy
                STR     r0, SerialBaudDivisor
              ]
                STRB    r0, SerialTxByteCount

; set private buffer handles to invalid values
                MOV     r0, #-1
                STR     r0, InputBufferHandle
                STR     r0, OutputBufferHandle
                STR     r0, InputBufferPrivId
                STR     r0, OutputBufferPrivId

; set up hal calls
                CLRV
                MOV     R8, #1
                GetHalEntry HAL_UARTStartUp
                GetHalEntry HAL_UARTShutdown
                GetHalEntry HAL_UARTFeatures
                GetHalEntry HAL_UARTReceiveByte
                GetHalEntry HAL_UARTTransmitByte
                GetHalEntry HAL_UARTLineStatus
                GetHalEntry HAL_UARTInterruptEnable
                GetHalEntry HAL_UARTRate
                GetHalEntry HAL_UARTFormat
                GetHalEntry HAL_UARTFIFOSize
                GetHalEntry HAL_UARTFIFOClear
                GetHalEntry HAL_UARTFIFOEnable
                GetHalEntry HAL_UARTFIFOThreshold
                GetHalEntry HAL_UARTInterruptID
                GetHalEntry HAL_UARTBreak
                GetHalEntry HAL_UARTModemControl
                GetHalEntry HAL_UARTModemStatus
                GetHalEntry HAL_UARTDevice
                GetHalEntry HAL_IRQClear
                STR     R1, HAL_StaticBase

                STRVS   r0, [sp]
                EXIT    VS

                MOV     r9, r1
                CallHAL HAL_UARTDevice
                STR     r0, IRQDeviceNumber

                CallHAL HAL_UARTFeatures
                TST     r0, #1
                LDR     r1, Flags
                ORRNE   r1, r1, #f_UseFIFOs
                TST     r0, #1<<3
                ORRNE   r1, r1, #f_HW_RTS_CTS
                TST     r0, #1<<4
                ORRNE   r1, r1, #f_TX_Threshold
                STR     r1, Flags

                SUB     sp, sp, #4
                MOV     r1, #0
                MOV     r2, sp
                CallHAL HAL_UARTFIFOSize
                LDR     r0, [sp], #4
                CMP     r0, #255
                MOVHS   r0, #255
                STRB    r0, FIFOSize

                LDR     r1, Flags
                TST     r1, #f_DefaultPort
                LDREQ   r0, =default_fifo_trigger
                LDRNE   r0, =FC_RXTrigger1
                STRB    r0, FIFOTrigger

                BL      register_device
                STRVS   r0, [sp]
                EXIT    VS

                LDR     r1, Flags
                MOV     r0, #0
                TST     r1, #f_UseFIFOs                 ; if we can use FIFOs then
                MOVNE   r0, #1:SHL:SF_UseFIFOs          ;    flag in device flags
                TST     r1, #f_DefaultPort              ; if we aren't the default port
                ORREQ   r0, r0, #1:SHL:SF_DCDIgnore     ;    ignore DCD (old DualSerial always ignored DCD)
                STR     r0, SerialDeviceFlags


                MOV     r0, #serialctrl_Reset
                BL      CallDevice                      ; reset the serial device

                TST     r1, #f_DefaultPort
                BEQ     %FT10

                ; Initialise using programmed CMOS values

                MOV     r0, #ReadCMOS
                MOV     r1, #PSITCMOS
                SWI     XOS_Byte
                MOVVC   r2, r2, LSR #2                  ; if succeeded, shift bits down
                ANDVC   r2, r2, #2_111                  ; extract relevant bits (0 => 75, ... ,7 => 19200)
                ADDVC   r2, r2, #1                      ; 1 => 75, ... ,8 => 19200
                MOVVS   r2, #0                          ; use 9600 if error

                Debug   init, "RX/TX baud rates:", r2

                MOV     r0, #serialctrl_ChangeBaud
                MOV     r1, r2                          ; RX = TX
                BL      CallDevice

                MOV     r0, #ReadCMOS
                MOV     r1, #DBTBCMOS
                SWI     XOS_Byte
                MOVVC   r2, r2, LSR #5
                ANDVC   r2, r2, #2_111                  ; r2 => serial data format
                MOVVS   r2, #4                          ; default to 8n2 if error
                ADR     r1, datatable
                LDRB    r1, [r1, r2]                    ; convert from configured value to usable value

                Debug   init, "Data format word:", r1

                MOV     r0, #serialctrl_ChangeDataFormat
                BL      CallDevice                      ; call device informing of format changes

                MOV     r0, #&CB
                MOV     r1, #0
                MOV     r2, #&FF                        ; read buffer minimum space
                SWI     XOS_Byte
                MOVVS   r1, #17                         ; if that failed then setup a value
                STR     r1, InputBufferThreshold        ; and store it away in workspace

 [ PowerControl
                BL      SetPower_Off                    ; power not needed
 ]

                EXIT

10
                ; Initialise using default values from DualSerial of old
                LDR     r0, =default_threshold
                STR     r0, InputBufferThreshold
                LDR     r2, =default_baud
                MOV     r0, #serialctrl_ChangeBaud
                MOV     r1, r2                          ; RX = TX
                BL      CallDevice
                LDR     r1, =default_data
                MOV     r0, #serialctrl_ChangeDataFormat
                BL      CallDevice                      ; call device informing of format changes

                EXIT                                

datatable
                = (1:SHL:0)+ (1:SHL:4)+ (1:SHL:2)+ (1:SHL:3)
                = (1:SHL:0)+ (0:SHL:4)+ (1:SHL:2)+ (1:SHL:3)
                = (1:SHL:0)+ (1:SHL:4)+ (0:SHL:2)+ (1:SHL:3)
                = (1:SHL:0)+ (0:SHL:4)+ (0:SHL:2)+ (1:SHL:3)
                = (0:SHL:0)+ (0:SHL:4)+ (1:SHL:2)+ (0:SHL:3)
                = (0:SHL:0)+ (0:SHL:4)+ (0:SHL:2)+ (0:SHL:3)
                = (0:SHL:0)+ (1:SHL:4)+ (0:SHL:2)+ (1:SHL:3)
                = (0:SHL:0)+ (0:SHL:4)+ (0:SHL:2)+ (1:SHL:3)

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; register device
;
register_device Entry "r0-r8"

; have we already been registered
                LDR     r0, Flags
                TST     r0, #f_Registered
                EXIT    NE

; don't... copy the device block onto the workspace
                ADD     r0, r12, # :INDEX:DeviceFSBlock
                ADRL    r1, device_name
                ADRL    r3, device_block_end
10              LDR     r2, [r1], #4
                STR     r2, [r0], #4
                CMP     r1, r3
                BLT     %BT10

                ADD     r0, r12, # :INDEX:DeviceFSBlock
                LDR     r2, PortNumber
    ! 0, "This module only handles port numbers up to 1 - 9"
                ADD     r2, r2, #'1'
                STRB    r2, [r0, #device_n - device_name]
                MOV     r1, r0

                ADD     r1, r1, #device_block - device_name
                ; r1 now points to a valid devicefs block.

                MOV     r0, #ParentFlag_FullDuplex :OR: ParentFlag_DeviceUpcalls
                ADDR    r2, Serial710                   ; -> handler
                MOV     r3, #0
                MOV     r4, wp                          ; -> workspace
                ADDR    r5, device_validation           ; vaidation
                MOV     r6, #1                          ; max RX stream
                MOV     r7, #1                          ; max TX stream
                SWI     XDeviceFS_Register
                STRVS   r0, [sp]
                EXIT    VS
                STR     r0, DeviceHandle

; show we are registered
                LDR     r1, Flags
                ORR     r1, r1, #f_Registered
                STR     r1, Flags

                TST     r1, #f_DefaultPort
                EXIT    EQ

                MOV     r1, #Service_SerialDevice
                MOV     r2, #0                          ; from me to Serial Support module
                SWI     XOS_ServiceCall

                EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; unregister device
;
unregister_device Entry "r0"

; have we been registered
                LDR     r0, Flags
                TST     r0, #f_Registered
                EXIT    EQ

                LDR     r0, DeviceHandle
                CMP     r0, #0
                EXIT    EQ
                SWI     XDeviceFS_Deregister
                SUBS    r0, r0, r0                      ; R0=0, V cleared
                STR     r0, DeviceHandle

; show we are unregistered
                LDR     r0, Flags
                BIC     r0, r0, #f_Registered
                STR     r0, Flags

                EXIT
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Generalised internationalisation routines, these ensure that messages files
; are correctly opened and then return the relevant data.
;
              [ international


; Attempt to open the messages file.

OpenMessages    Entry   "r0-r3"
                LDR     r3, Flags
                TST     r3, #f_WeHaveMessages                   ; do we have an open messages block?
                BNE     %FT90                                   ; yes, so don't bother again

                ADR     r0, MessagesWorkspace
                ADRL    r1, resource_file                       ; -> path to be opened
                MOV     r2, #0                                  ; allocate some wacky space in RMA
                SWI     XMessageTrans_OpenFile
                LDRVC   r3, Flags
                ORRVC   r3, r3, #f_WeHaveMessages
                STRVC   r3, Flags                               ; assuming it worked mark as having messages
90              CMP     r0, #0
                EXIT                                            ; always return VC, cos don't want to corrupt r0
                                                                ; (will hold a real error pointer)

; Attempt to close the messages file.

CloseMessages   Entry   "r0"
                CMP     r12, #0                                 ; workspace allocated? (+ clear V)
                LDRNE   r0, Flags
                TSTNE   r0, #f_WeHaveMessages                   ; do we have any messages?
                EXIT    EQ                                      ; and return if not!

                ADR     r0, MessagesWorkspace
                SWI     XMessageTrans_CloseFile                 ; yes, so close the file
                LDRVC   r0, Flags
                BICVC   r0, r0, #f_WeHaveMessages
                STRVC   r0, Flags                               ; mark as we don't have them
                CMP     r0, #0                                  ; clear V
                EXIT

; Generate an error based on the error token given.  Does not assume that
; the messages file is open.  Will attempt to open it, then look it up.

MakeError       Entry   "r1-r7"
                LDR     r1, Flags
                TST     r1, #f_WeHaveMessages                   ; has the messages file been closed?
                BLEQ    OpenMessages

                LDR     r1, Flags
                TST     r1, #f_WeHaveMessages
                BEQ     %FT99                                   ; if still not open then return with V set

                ADR     r1, MessagesWorkspace                   ; -> message control block
                MOV     r2, #0
                MOV     r3, #0
                MOV     r4, #0
                MOV     r5, #0
                MOV     r6, #0
                MOV     r7, #0                                  ; no substitution + use internal buffers
                SWI     XMessageTrans_ErrorLookup

                BL      CloseMessages                           ; attempt to close the doofer

99
                SETV
                EXIT                                            ; return, r0 -> block, V set

              ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: CallDevice
;
; in:   r0  = reason code
;   r1..r7  = parameters
;
; out:  -
;
; This routine will call the device with the parameters setup in r1..r7.
;

CallDevice      Entry   "r1-r7"
                MOV     r2, sp                                  ; -> return frame to be used
                BL      Serial710                               ; call device with return frame setup
                EXIT                                            ; and return back to the caller!

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This bit of apparently harmless code will bind a messages file into the code
; in the case of a standalone module. The macro ResourceFile will create the
; stuff and the label resource_file is used to point to the block required by
; ResourceFS

 [ standalonemessages
resource_file_block
        ResourceFile LocalRes:Messages, Resources.DualSerial.Messages
        DCD     0
 ]

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                END
