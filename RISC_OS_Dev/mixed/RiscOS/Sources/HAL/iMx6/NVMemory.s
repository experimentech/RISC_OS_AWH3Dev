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
; NVMemory functions

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.GPIO
        GET     hdr.iMx6q
        GET     hdr.StaticWS
        GET     hdr.Timers

        AREA    |Asm$$Code|, CODE, READONLY, PIC

        EXPORT  NVMemory_Init
        EXPORT  NVMemory_InitDevice
        EXPORT  HAL_NVMemoryType
        EXPORT  HAL_NVMemorySize
        EXPORT  HAL_NVMemoryIICAddress
        EXPORT  HAL_NVMemoryPageSize
        EXPORT  HAL_NVMemoryProtectedSize
        EXPORT  HAL_NVMemoryProtection
        EXPORT  HAL_NVMemoryRead
        EXPORT  HAL_NVMemoryWrite

        IMPORT  HAL_CounterDelay
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]
        IMPORT  IIC_DoOp_Poll
        IMPORT  HAL_NormalIICOp

; debug use.. use our compiled in CMOS rather than hunting
        GBLL    UseSoftCMOS
UseSoftCMOS     SETL {TRUE}

; Use I2C for NVRam access
        GBLL    UseIICCMOS
UseIICCMOS      SETL {TRUE}

        ; Autodetect the EEPROM at runtime in the range 2kbit to 16kbit
        GBLL    ProbeEESize
ProbeEESize     SETL {FALSE}


; mem type ..   0       none
;               1       Its on IIC bus .. OS to find it
;               2       as 1, but characteristics known
;                       ( give IIC address, size, protected stuff )
;               3       NVMemory calls process it
;       bit 8 set       has protected region at end
;       bit 9 set       it is software deprotectable
;       bit 10 set      bytes 0-15 readable
;       bit 11 set      bytes 0-15 writable
iMX6NVMemIICAddress *   &a0     ; if mem type 2
iMX6NVMemSize   *       2048
iMX6NVMemBus    *       CMOSI2C_num

 [ UseSoftCMOS

; macro to mangle physical cmos addresses given to the HAL
; into the logical addresses used by *savecmos. This means a
; stored cmos map can be taken straight from the *savecmos file
        MACRO
$label  CMOSAddrRemap  $reg
$label  cmp     $reg, #&ff
        bgt     %ft2222
        cmp     $reg, #&40
        subge   $reg, $reg, #&40
        bge     %ft2222
        cmp     $reg, #&10
        addge   $reg, $reg, #&b0
        bge     %ft2222
        add     $reg, $reg, #&f0
2222
        MEND
 ]

HAL_NVMemoryType
        LDR     a1, NVMemoryFound
        TEQ     a1, #0
        LDRNE   a1, =NVMemoryFlag_IIC+NVMemoryFlag_LowRead+NVMemoryFlag_LowWrite
        BNE     %ft10
 [ UseSoftCMOS
        LDR     a1, =NVMemoryFlag_HAL+NVMemoryFlag_LowRead+NVMemoryFlag_LowWrite
 |
        ASSERT  NVMemoryFlag_None = 0
 ]
10
;        Push    "lr"
; DebugReg a1, "NVmemtype reported "
;        Pull    "lr"

        MOV     pc, lr

HAL_NVMemorySize
        LDR     a1, NVMemoryFound
 [ UseSoftCMOS
        TEQ     a1, #0
        ldreq   a1, =SoftCMOSSize
 ]
        Push    "lr"
; DebugReg a1, "NVmemsize reported "
        Pull    "lr"
        MOV     pc, lr

HAL_NVMemoryPageSize
        MOV     a1, #16    ; Try it the same size as the original
        MOV     pc, lr

HAL_NVMemoryProtectedSize
        MOV     a1, #0     ; No protected memory
        MOV     pc, lr

HAL_NVMemoryIICAddress
        MOV     a1, #iMX6NVMemIICAddress     ;
        Push    "lr"
; DebugReg a1, "NVmemaddr reported "
        Pull    "lr"
        MOV     pc, lr

HAL_NVMemoryProtection
        MOV     pc, lr     ; No memory protection, nothing to do

HAL_NVMemoryRead
        ; In:  a1 = physical address
        ;      a2 = destination buffer
        ;      a3 = count
        ; Out: a1 = number of bytes read
        Push    "v1-v4, lr"
; DebugRegNCR a1, "NVrd addr "
; DebugRegNCR a2, "NVsrce addr "
; DebugRegNCR a3, "NVcount "
        MOV     v1, a1
        MOV     v2, a2
        MOV     v3, a3
        LDR     v4, NVMemoryFound
        teq     v4, #0          ; do we have ram here?
        beq     %ft10           ; no.. use the softcmos stuff
; do a bulk read via iic
; in:
;      r0 = b0-15 offset within IIC device to start at
;           b16-23 base IICAddress
;           b24-31 IICBus
;      r1 = buffer to read from/write to
;      r2 = pointer to number of bytes to transfer
; returns:
;      r0 = IICStatus return code
;      size = bytes successfully transferred (prior to any error)
        orr     a1, a1, #iMX6NVMemIICAddress<<16
        orr     a1, a1, #1<<16          ; read
        orr     a1, a1, #iMX6NVMemBus<<24
        Push    "a3"
        mov     a3, sp
        bl      HAL_NormalIICOp
        Pull    "v4"            ; bytes transferred
        b       %ft20
10
 [ UseSoftCMOS
        adrl    a4, SoftCMOS
111     subs    a3, a3, #1
        movge   v2, a1
        CMOSAddrRemap v2
        cmp     a3, #0
        ldrgeb  v1, [a4, v2]
        addge   a1, a1, #1
        strgeb  v1, [a2], #1
        addge   v4, v4, #1     ; v4 started at 0
        bgt     %bt111
 ]
20      mov     a1, v4
; DebugReg a1, "rdBytes xferred "
        Pull    "v1-v4, pc"

HAL_NVMemoryWrite
        ; In:  a1 = physical address
        ;      a2 = source buffer
        ;      a3 = count
        ; Out: a1 = number of bytes written
        Push    "v1-v4, lr"
; DebugRegNCR a1, "NVwr addr "
; DebugRegNCR a2, "NVwsrce addr "
; DebugRegNCR a3, "NVwcount "
        MOV     v1, a1
        MOV     v2, a2
        MOV     v3, a3
        LDR     v4, NVMemoryFound
        teq     v4, #0          ; do we have ram here?
        beq     %ft10           ; no.. use the softcmos stuff
; do a bulk write via iic
; in:
;      r0 = b0-15 offset within IIC device to start at
;           b16-23 base IICAddress
;           b24-31 IICBus
;      r1 = buffer to read from/write to
;      r2 = pointer to number of bytes to transfer
; returns:
;      r0 = IICStatus return code
;      size = bytes successfully transferred (prior to any error)
        orr     a1, a1, #iMX6NVMemIICAddress<<16
        bic     a1, a1, #1<<16          ; 0=write
        orr     a1, a1, #iMX6NVMemBus<<24
        Push    "a3"            ; need pointer to value in a3, not value
        mov     a3, sp
        bl      HAL_NormalIICOp
        Pull    "v4"            ; bytes transferred
        b       %ft20
10
 [ UseSoftCMOS
        mov     v4, a3
 |
        mov     v4, #0
 ]
20      mov     a1, v4
; DebugReg a1, "wrBytes transferred "
        Pull    "v1-v4, pc"

NVMemory_Init
        Push    "v1-v3, lr"
;        DebugTX " start of nvinit ^^^^^^^^^^^^^^^^^^"
   [ UseIICCMOS
        MOV     a1, #0
        BL      NVMemory_BGet
05
        CMP     a1, #-1
        MOVEQ   v3, #0     ; No reply
        MOVNE   v3, #iMX6NVMemSize

      [ ProbeEESize
        SUB     sp, sp, #256
        MOV     v2, sp
        BEQ     %FT30

        ; So there's an EEPROM of at least 256 bytes present
        MOV     v1, #255
        MOV     v3, #256   ; Must be at least 256
10
        MOV     a1, v1
        BL      NVMemory_BGet
        STRB    a1, [v2, v1]
        SUBS    v1, v1, #1
        BPL     %BT10
15
        ; Compare blocks of 2048 bits in powers of 2 until alias found
        ; This has 2 weaknesses
        ; - when the chip is initially blank it will appear to be 256 bytes
        ;   for the first boot (done during the factory test anyway)
        ; - it may underreport if the chip is filled with exact copies of the
        ;   first 256 bytes for reason (unlikely, versus a destructive test)
        MOV     v1, #255
20
        ADD     a1, v1, v3
        BL      NVMemory_BGet
        LDRB    a2, [v2, v1]
        TEQ     a1, a2
        BNE     %FT25
        SUBS    v1, v1, #1
        BPL     %BT20

        ; All 256 matched, it's an alias
        B       %FT30
25
        ; Non match, not an alias, try next power of 2
        MOV     v3, v3, LSL #1

        ; Stop probing when address wont fit in the address byte
        CMP     v3, #2_11100000000
        BLS     %BT15
30
        ADD     sp, sp, #256
      ]
   |
        MOV     v3, #0
   ]
; DebugReg v3, "NVMemFnd "
        STR     v3, NVMemoryFound
        Pull    "v1-v3, pc"

NVMemory_BGet
        ; int32_t NVMemory_BGet(uint32_t loc)
        ; Returns -1 if no ACK otherwise the byte read
        Push    "a1, v1, v2, v3, lr"
; DebugReg a1, "nvbg-addr-"
      [ ProbeEESize
        ; Bits 8-10 of loc form part of the IIC address
        AND     a2, a1, #2_11100000000
        MOV     a2, a2, LSR #7
        ORR     a1, a2, #iMX6NVMemIICAddress
      |
        MOV     a1, #iMX6NVMemIICAddress
      ]
        ORR     a1, a1, #1

        ADD     a2, sp, #1
        MOV     a3, #1
        Push    "a1-a3" ; Second block: Read 1 byte
        EOR     a1, a1, #1+(1:SHL:29) ; write with retry
        ADD     a2, sp, #12
        MOV     a3, #1
        Push    "a1-a3" ; First block: Write 1 byte
        MOV     a1, sp
        MOV     a2, #2  ; do 2 blocks
        ; If HAL_Init isn't done yet, we can't use RISCOS_IICOpV
        LDR     a3, HALInitialised
        CMP     a3, #0
        BEQ     %FT10
        LDR     a3, OSentries+4*OS_IICOpV
        BLX     a3
        B       %FT20
10
        BL      IIC_DoOp_Poll
20
        CMP     a1, #IICStatus_Completed
        MOVNE   a1, #-1
        LDREQB  a1, [sp, #12+12+1]
        ADD     sp, sp, #12+12+4
; DebugReg a1, " nvbgr-was-"
        Pull    "v1, v2, v3, pc"

NVMemory_InitDevice
        LDR     a3, NVMemoryFound
        TEQ     a3, #0
        MOVEQ   pc, lr

        ; Not probing for size, so can just add it in-place without worrying
        ; about patching in the right device ID/description
        ASSERT  :LNOT: ProbeEESize
        MOV     a1, #0
        ADR     a2, NVMemory_Device
        LDR     pc, OSentries + 4*OS_AddDevice

NVMemory_Device
        DCW     HALDeviceType_SysPeri + HALDeviceSysPeri_NVRAM
        DCW     HALDeviceID_NVRAM_24C16 ; 16 kilobit
        DCD     HALDeviceBus_Ser + HALDeviceSerBus_IIC
        DCD     0               ; API version 0
        DCD     NVMemory_Device_Desc
        DCD     0               ; Address - N/A
        %       12              ; Reserved
        DCD     NVMemory_Device_Activate
        DCD     NVMemory_Device_Deactivate
        DCD     NVMemory_Device_Reset
        DCD     NVMemory_Device_Sleep
        DCD     -1
        DCD     0
        %       8
        ASSERT  (. - NVMemory_Device) = HALDeviceSize

NVMemory_Device_Activate
        MOV     a1, #1
        MOV     pc, lr
NVMemory_Device_Sleep
        MOV     a1, #0
NVMemory_Device_Deactivate
NVMemory_Device_Reset
        MOV     pc, lr

NVMemory_Device_Desc
        DCB    "24C16 EEPROM", 0
        ALIGN

 [ UseSoftCMOS
        GET     s.SoftCMOS
 ]

        END
