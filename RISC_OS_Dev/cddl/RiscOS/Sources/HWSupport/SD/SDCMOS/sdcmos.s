;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/HWSupport/SD/SDCMOS/LICENCE.
; See the Licence for the specific language governing permissions
; and limitations under the Licence.
;
; When distributing Covered Code, include this CDDL HEADER in each
; file and include the Licence file. If applicable, add the
; following below this CDDL HEADER, with the fields enclosed by
; brackets "[]" replaced with your own identifying information:
; Portions Copyright [yyyy] [name of copyright owner]
;
; CDDL HEADER END
;
; Copyright 2012 Ben Avison.  All rights reserved.
; Portions Copyright 2012 Jeffrey Lee.
; Use is subject to license terms.
;

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc
        GET     Hdr:HighFSI
        GET     Hdr:ModHand
        GET     Hdr:OsBytes
        GET     Hdr:OsWords
        GET     Hdr:CMOS
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:Territory
        GET     Hdr:FileTypes
        GET     Hdr:Services
        GET     Hdr:MsgTrans
        GET     Hdr:RTC
        GET     Hdr:HALDevice
        GET     Hdr:HALEntries
        GET     Hdr:SDFS
        GET     VersionASM
        
        AREA    |Asm$$Code|, CODE, READONLY, PIC
        
        ENTRY
        
        DCD     0 ; Start
        DCD     Init - |Asm$$Code|
        DCD     Final - |Asm$$Code|
      [ :LNOT::DEF: StoreAtDiscAddress
        DCD     Services - |Asm$$Code|
      |
        DCD     0 ; Service call handler
      ]
        DCD     Title - |Asm$$Code|
        DCD     Help - |Asm$$Code|
        DCD     0 ; Keyword table
        DCD     0 ; SWI chunk
        DCD     0 ; SWI handler
        DCD     0 ; SWI table
        DCD     0 ; SWI decoder
        DCD     0 ; Messages
        DCD     Flags - |Asm$$Code|
        
Title   =       Module_ComponentName, 0
Help    =       Module_ComponentName, 9, 9, Module_HelpVersion, 0
        ALIGN
Flags   DCD     ModuleFlag_32bit
        
      [ :LNOT::DEF: StoreAtDiscAddress

NonCanonicalisedPath
        =       "SDFS:$.CMOS", 0
NonCanonicalisedPath2
        =       "SDFS:$.!Boot.Loader.CMOS", 0        
        ALIGN

SaveCMOS
        =       "SaveCMOS "
Len_SaveCMOS * .-SaveCMOS
        ALIGN

      ]
        
ReqdAPIMajor *  0

Init    ROUT
        Entry
        ; If the HAL proclaims hardware CMOS is present, go dormant
        MOV     r6, r8
        MOV     r1, #0
10
        LDR     r0, =(HALDeviceType_SysPeri + HALDeviceSysPeri_NVRAM) :OR: (ReqdAPIMajor:SHL:16)
        MOV     r8, #OSHW_DeviceEnumerate
        SWI     XOS_Hardware
        EXIT    VS
        
        CMP     r1, #-1                 ; All done with no matches, try file
        BEQ     %FT30

        LDRH    r3, [r2, #HALDevice_ID]
        TEQ     r3, #HALDeviceID_NVRAM_24C02
        TEQNE   r3, #HALDeviceID_NVRAM_24C04
        TEQNE   r3, #HALDeviceID_NVRAM_24C08
        TEQNE   r3, #HALDeviceID_NVRAM_24C16
        BNE     %BT10                   ; Was NVRAM, but not a known one

        ADR     r0, ErrorBlock_HardwareDepends
        MOV     r1, #0
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        EXIT
20
        MakeInternatErrorBlock HardwareDepends,,HWDep
30
        MOV     r8, r6

        ; This module is designed to be included in a ROM, in which case we have
        ; to take account of the fact that SDFS::0 isn't properly initialised
        ; until the callbacks after ROM init.
        ADR     r0, CallBackFromInit
        MOV     r1, r12
        SWI     XOS_AddCallBack
        EXIT

CallBackFromInit ROUT
        Push    "lr" ; separate instructions to reduce warnings
        ADD     lr, sp, #4
        Push    "r0-r6, lr" ; yes, need to stack sp
        
      [ :LNOT::DEF: StoreAtDiscAddress
        ; We assume that we're entered during or soon after boot. In which case,
        ; if there is an SD card inserted, and if it contains a file called
        ; "CMOS" in its root directory of the correct filetype, then we must
        ; assume that it could have been used to initialise the kernel's CMOS
        ; RAM cache, and therefore needs updating whenever someone writes CMOS.

        ADR     r1, NonCanonicalisedPath
        BL      TryInit
        ADRVS   r1, NonCanonicalisedPath2
        BLVS    TryInit
        BVS     %FT90
      ]
        
        ; All good - get on ByteV
        MOV     r0, #ByteV
        ADR     r1, MyByteV
        MOV     r2, r12
        SWI     XOS_Claim
        BVS     %F90

        ; See if a CMOS reset has occurred, if so our copy on the SD card
        ; is stale and we need to write out the Kernel's clean reset copy
        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #SystemSpeedCMOS
        SWI     XOS_Byte
        MOVVS   r2, #0
        TST     r2, #CMOSResetBit
        MOVNE   r0, #OsByte_WriteCMOS
        SWINE   XOS_Byte ; just echo it back to trigger a SaveCMOS
        CLRV

        Pull    "r0-r6, lr" ; separate instructions to reduce warnings
        Pull    "pc"

90      ; Error detected during callback - kill the module and exit
        ASSERT  %F99-%F98 = 8
        ADR     r0, %F98
        LDMIA   r0, {r1-r2}
        Push    "r1-r2"
        MOV     r0, #1
        MOV     r1, sp
        ADD     r2, sp, #%F99-%F98-1
        SWI     XOS_SynchroniseCodeAreas
        MOV     r0, #ModHandReason_Delete
        ADR     r1, Title
        ADD     r2, sp, #%F99-%F98 ; point r2 at stack frame
        MOV     pc, sp
        ; This last bit is executed after the module is killed so can't safely
        ; be executed in place - do it from the stack instead
98      SWI     XOS_Module
        LDMIA   r2, {r0-r6, sp, pc} ; atomic update of sp (which makes this code volatile) with pc
99


      [ :LNOT::DEF: StoreAtDiscAddress
; In: r1 = filename
; Out: Regs corrupt
;      V set on failure
;      No error pointer returned
TryInit ROUT
        Entry
        ; Find how long the canonicalised name is
        MOV     r0, #FSControl_CanonicalisePath
        MOV     r2, #0
        MOV     r3, #0
        MOV     r4, #0
        MOV     r5, #0
        SWI     XOS_FSControl
        BVS     %F90
        
        ; Allocate a buffer for the command string - will contain "SaveCMOS "
        ; plus the canonicalised name of the file, plus a terminator
        RSB     r3, r5, #Len_SaveCMOS + 1
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        BVS     %F90
        STR     r2, [r12]
        
        ; Get the canonicalised name
        ADD     r2, r2, #Len_SaveCMOS
        MOV     r5, r3
        MOV     r0, #FSControl_CanonicalisePath
        MOV     r3, #0
        SWI     XOS_FSControl
        BVS     %F90

        ; Copy in the "SaveCMOS " part now we have a few more working registers
        ASSERT  Len_SaveCMOS = 9
        SUB     r2, r2, #Len_SaveCMOS
        ADR     r3, SaveCMOS
        LDMIA   r3!, {r4-r5}
        LDRB    r6, [r3]
        STMIA   r2!, {r4-r5}
        STRB    r6, [r2], #1

        ; Check it's a file (or image file)
        MOV     r0, #OSFile_ReadWithTypeNoPath
        MOV     r1, r2
        SWI     XOS_File
        BVS     %F90
        TST     r0, #object_file
        BEQ     %F90

        ; Check it's a sensible filetype
        LDR     r0, =FileType_Configuration
        TEQ     r6, r0
        LDRNE   r0, =FileType_MSDOS
        TEQNE   r6, r0
        BNE     %F90

        ; If there's no RTC, try restoring the time from the file timestamp
        SWI     XRTC_Features
        BVC     %F80        ; V clear -> RTC driver is active

        AND     r4, r2, #&FF
        ORRS    r0, r4, r3
        BEQ     %F80        ; Clearly duff load/exec address (timestamp)

        Push    "r3-r4"

        ; If the time is in 1970 then the kernel didn't find a real time
        ; clock, and NetTime hasn't picked up a link yet
        SUB     sp, sp, #8
        MOV     r0, #OsWord_ReadRealTimeClock
        MOV     r1, #OWReadRTC_5ByteInt
        STRB    r1, [sp]
        MOV     r1, sp
        SWI     XOS_Word
        ADDVS   sp, sp, #8
        BVS     %F60

        LDR     r3, =((71 * 365) + 18) * 86400
        MOV     r0, #100    ; want cs to end of 1970 from epoch 1900
        UMULL   r3, r4, r0, r3 
        LDR     r0, [sp, #0]
        LDRB    r1, [sp, #4]
        SUBS    r14, r0, r3
        SBCS    r14, r1, r4
        ADD     sp, sp, #8  
        BPL     %F60        ; now > 1970

        ; Use load/exec address (timestamp) as a better guess
        MOV     r0, sp
        SWI     XTerritory_SetTime
        CLRV
60
        ADD     sp, sp, #8  ; Drop load/exec address
80
        ; All good
        CLRV
        EXIT

90
        ; Something went wrong
        ; Free our workspace to avoid potential leak if TryInit called multiple times
        LDR     r2, [r12]
        CMP     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        MOV     r2, #0
        STR     r2, [r12]
        SETV
        EXIT

Services ROUT
        TEQ     r1, #Service_ShutDown
        MOVNE   pc, lr
        Push    "r0-r1, lr" ; keep original r0 in case OS_File returns an error
        LDR     r1, [r12]
        ADD     r1, r1, #Len_SaveCMOS
        MOV     r0, #OSFile_SetStamp
        SWI     XOS_File    ; stamp at shutdown so file timestamp is fresh
        Pull    "r0-r1, pc" ; and on with the shutdown (don't claim)
      ]
        
MyByteV
        TEQ     r0, #OsByte_WriteCMOS
        MOVNE   pc, lr      ; only interested in when the CMOS is written
        ADR     r0, %F10
        Push    "r0, r12"   ; set up address for claimant to return to (NB this code is not 26-bit compatible) 
        MOV     r0, #OsByte_WriteCMOS
        MOV     pc, lr      ; pass on, and...
10                          ; ... we end up here after the CMOS has been written
        Pull    "r12"       ; get our own r12 back
        Pull    "pc", VS    ; if an error, just pass it up to original claim address
      [ :DEF: StoreAtDiscAddress
        Push    "r0-r4,r6"
        MOV     r6, #0
        MOV     r0, #1
        MOV     r1, #StoreAtDiscAddress :SHR: 29
        MOV     r2, #0
        SWI     XSDFS_MiscOp
        BVS     %F75
        TEQ     r2, #1
        BNE     %F75 ; disc has been changed since boot - don't write to it
        
        MOV     r6, #256
        BL      CMOSToStack
        
        MOV     r1, #2
        LDR     r2, =StoreAtDiscAddress
        MOV     r3, sp
        MOV     r4, r6
        SWI     XSDFS_DiscOp
75
        ADD     sp, sp, r6
        STRVS   r0, [sp]
        Pull    "r0-r4,r6, pc" ; go to original claim address
      |
        Push    "r0"
        LDR     r0, [r12]
        SWI     XOS_CLI     ; save the CMOS to the file
        STRVS   r0, [sp]
        Pull    "r0, pc"    ; go to original claim address
      ]

      [ :DEF: StoreAtDiscAddress
CMOSToStack ROUT
        MOV     r4, lr
        ; Copy the CMOS RAM into a block on the stack (should be small enough)
        ; in physical address order
        SUB     sp, sp, r6
        MOV     r3, #0
30      MOV     r0, #OsByte_ReadCMOS
        MOV     r1, r3
        CMP     r3, #&10
        ADDLO   r1, r1, #&40
        CMP     r3, #&40
        ADDLO   r1, r1, #&F0
        CMP     r3, #&100
        SUBLO   r1, r1, #&40
        SWI     XOS_Byte
        MOVVS   r2, #0
        STRB    r2, [sp, r3]
        ADD     r3, r3, #1
        CMP     r3, r6
        BLO     %B30
        MOV     pc, r4
      ]

Final   ROUT
        Entry
        ; It's good practice to remove our callback here just in case we got
        ; killed before it was triggered.
        ADR     r0, CallBackFromInit
        MOV     r1, r12
        SWI     XOS_RemoveCallBack
        
        ; Get off ByteV, if we were on it
        MOV     r0, #ByteV
        ADR     r1, MyByteV
        MOV     r2, r12
        SWI     XOS_Release

        ; The block pointed at by r12 is freed for us by the kernel if nonzero
        
        CLRV
        EXIT
        
        END
