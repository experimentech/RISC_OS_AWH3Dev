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
        ; You'll often see these prefixed with Hdr: for historic reasons.
        ; This is no longer necessary, and in fact omitting them makes it
        ; possible to cross-compile your source code.
        GET     ListOpts
        GET     Macros
        GET     System
        GET     ModHand
        GET     Services
        GET     ResourceFS
        GET     VersionASM
        GET     Proc
        GET     FSNumbers
        GET     NewErrors
        GET     HALEntries
        GET     HALDevice
        GET     AHCIDevice
        GET     OSMisc
        GET     module
        GET     PCI
        GET     SCSI
        GET     scsicmd

; workspace definition
                ^       0,      wp      ; Store
HAL_SB          #       4
HAL_CounterDelay_p #    4
HAL_IRQClear_p  #       4
IRQTrigger      #       4
ARMop_DMB_Write_p #     4
;
ChipRXFis       #       4               ; RXFis logical address
ChipP0CLB       #       4               ; P0CLB logical address
ChipL2POffset   #       4               ; logical to physical offset of these
;
ChipCMDHd       #       0               ; CMDHd at buffer logical start
AHCIBuf_Log     #       4               ; locical base of PCIRam Claim
AHCIBuf_Phys    #       4               ; physical "
AHCIDevice      #       HALDevice_AHCI_Size
ChipBase        *       AHCIDevice+HALDevice_Address; Chip logical base address offset
ChipIRQDevice   *       AHCIDevice+HALDevice_Device


;MyCallBackPtr  #       4               ; address of function to call back
;MyCallBackR12  #       4               ; R12 to use
;MyCallBackState #      4               ; state flag
;                                       ; (see callbackstate semaphore below)
;IDCallBackPtr  #       4               ; address of function to call back
;IDCallBackR12  #       4               ; R12 to use
;IDCallBackState #      4               ; state flag
;                                       ; (see callbackstate semaphore below)
AHCIIRQMask     #       4               ; memory of ahciirq mask during irq
AHCIDevRdy      #       4               ; bit field, bit=1 means drive ready

; module state semaphore
modulestate     #       1
; module state values
mstate_dead     *       0
mstate_inactive *       1
mstate_active   *       2
;
; callback state semaphores
STcallbackstate #       1
IDcallbackstate #       1
IDcallbackport  #       1               ; port to use for ID callback
CCcallbackstate #       1
cb_unrequired   *       0
cb_required     *       1
cb_pending      *       2
;
LastLoadedSlot  #       1               ; last command slot loaded
LastClearedSlot #       1               ; last cleared command slot
 [ OSMem19
PagesUnsafeSeen #       1               ; Service_PagesUnsafe has been seen
 ]

; align to 4 byte boundary
                AlignSpace
DevFeatures     #       4 * (MaxDevCount-1); 1 word/device for features supported
DevFeature48bit *       1<<0            ; 1 = 48bit commands supported

; command slot completion and callback stuff
; If CBAddr = 0 then dont call anything when cmd completed
CBTab           #       0               ; base
CBToutOrHandl   #       4               ; timeout for this command
                                        ; or background r5 handle
CBAddr          #       4               ; address to call back
CBR12           #       4               ; R12 value for this
CBSlotAddr      #       4               ; AHCI_CMD_HEADER  addressfor this slot
CBCmdTabAddr    #       4               ; ahciCMDTab address for this
CBRXFisAddr     #       4               ; RXFis buffer for this transaction
CBR0Value       #       4               ; value of r0 and flags at start
CBR3Ptr         #       4               ; data transfer pointer
CBR4Cnt         #       4               ; transfer count total (or remaining)
CBCachePtr      #       4               ; pointer to ReCache on completion
CBFGDone        #       1               ; clear to zero when command completed
; align to 4 byte boundary
                AlignSpace
CBTEnd          #       0
CBBSize         *       (CBTEnd-CBTab)
CBrest          #       31 * CBBSize    ; parameters for other 31 command slots


; used transiently for inquiry command
IDBufferLen     *       &200
IDBuffer        #       IDBufferLen

scsicmdbuf      #       16              ; used by AHCIBlock command
SCSIIDFields    #       16              ; byte fields for active scsi IDs
                                        ; or &ff if not there
AHCIPortFields  #       16              ; map active scsi IDs to AHCI Port
                                        ; only valid if content < 16

; in later code this may need reading from device. for now....
L2SecSize       *       9               ; log 2 of sector size, 512
SecLen          *       (1<<L2SecSize)
 [ OSMem19
NullWrBuffer    #       4               ; ptr to buffer full of nulls to sector
                                        ; pad short writes
 |
NullWrBuffer    #       SecLen          ; buffer full of nulls to sector
                                        ; pad short writes. Cleared to Null
                                        ; as part of module init (!)
 ]

;    [ Debug
;DebugRamBase   # 256 ; some ram to dump debugstuff in
;    ]

TotalRAMRequired *      :INDEX: @




        ; Assembler modules are conventionally, but not necessarily,
        ; position-independent code. Area name |!| is guaranteed to appear
        ; first in link order, whatever your other areas are named.
        AREA    |!|, CODE, READONLY, PIC

        ENTRY

Module_BaseAddr
        DCD     0 ; Start
        DCD     Init - |Module_BaseAddr|
        DCD     Final - |Module_BaseAddr|
        DCD     ServiceCall - |Module_BaseAddr|; Service call handler
        DCD     Title - |Module_BaseAddr|
        DCD     Help - |Module_BaseAddr|
        DCD     HCKTab -  |Module_BaseAddr|; Keyword table
        DCD     AHCIDriverSWI_Base   ; SWI chunk
        DCD     0 - |Module_BaseAddr| ; SWI handler
        DCD     0 - |Module_BaseAddr| ; SWI table
        DCD     0 ; SWI Decoder
        DCD     0 ; Messages
        DCD     Flags - |Module_BaseAddr|

Title   =       Module_ComponentName, 0
Help    =       Module_ComponentName, 9, 9, Module_HelpVersion, 0
Flags   &       ModuleFlag_32bit

HCKTab
        Command "AHCIBlock",21, 5, 0
        Command "AHCIPortReset",0,0,0
        DCB     0
AHCIBlock_Help
        DCB     "*AHCIBlock issues a raw ATAPI command to the AHCIDriver module", 13
AHCIBlock_Syntax
        DCB     "Syntax: *AHCIBlock <r|w> length bufaddr Sectoraddress port(0-15) [ 1 byte ATAPIcommand | up to 16 bytes scsi command]", 0
AHCIPortReset_Help
        DCB     "*AHCIPortReset performs a port reset", 13
AHCIPortReset_Syntax
        DCB     "Syntax: *AHCIPortReset", 0

        ALIGN

; on entry, r0-> command line, r1 = parameter count
AHCIBlock_Code  ROUT
        Entry   "r1-r10"
        ldr     r12, [r12]
; lets just parse the command line
        sub     r3, r1, #1              ; 1 parameter taken
        ldrb    r6, [r0], #1            ; get first character .. r or w?
        teq     r6, #'w'
        teqne   r6, #'W'
        movne   r6, #1<<31
        moveq   r6, #0                  ; 0 write, 1 read
        mov     r1, r0
        mov     r0, #16
        swi     XOS_ReadUnsigned
        orr     r6, r6, r2              ; combine with length
; DebugReg r6, "r/w + length  "
        swi     XOS_ReadUnsigned
        mov     r4, r2                  ; dma address
; DebugReg r4, "dma  "
        swi     XOS_ReadUnsigned
        mov     r5, r2                  ; sector address
; DebugReg r5, "sector address "
        swi     XOS_ReadUnsigned
        mov     r9, r2                  ; port number
; DebugReg r8, "port "
        sub     r3, r3, #5              ; 5 more params have been taken
        swi     XOS_ReadUnsigned
; DebugReg r3, "params left "
        teq     r3, #0                  ; out of parameters?
        moveq   r3, r2
        beq     %ft1                    ; yes.. it is an 1 byte command
                                        ; no.. we have scsi command bytes
        adrl    r7, scsicmdbuf
        strb    r2, [r7], #1
2       swi     XOS_ReadUnsigned
        strb    r2, [r7], #1
        subs    r3, r3, #1
        bne     %bt2
        adrl    r3, scsicmdbuf
1                                       ; r3=command (or command buffer address)
; DebugReg r3, "command "
        mov     r1, r5                  ; pointer to sector address
        mov     r2, r6                  ; length +  1<<31 if read mode
        mov     r0, r4                  ; dma address
; read the command parameters
; buffer address to
; ATAPI command bytes
        mov     r5, #100                ; no timeout
        mov     r6, #0                  ; no callback  .. forground
        tst     r2, #(1<<31)
        orrne   r9,r9, #&01000000       ; rd mode fg etc
        orreq   r9,r9, #&02000000       ; wr mode fg etc
        bl      BuildandCompleteEntry

; await completion   .. return value of r0 can be error
        EXIT

AHCIPortReset_Code ROUT
        Entry   "r3,r5"
        ldr     r12, [r12]
        ; Temp disable any controller IRQs
        ldr     r5, ChipBase
        mov     r3, #(1<<BIT_AHCI_GHC_AE)
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]
        ; Do reset
        BL      IRQ_FatalError_AltEntry
        ; Re-enable IRQs
        mov     r3, #(1<<BIT_AHCI_GHC_AE)+(1<<BIT_AHCI_GHC_IE)
        str     r3, [r5, #HW_AHCI_GHC_OFFSET]
        EXIT

        ASSERT  Service_PreReset < Service_PostInit
        ASSERT  Service_PostInit < Service_PagesUnsafe
        ASSERT  Service_PagesUnsafe < Service_SCSIStarting
        ASSERT  Service_SCSIStarting < Service_SCSIDying
        ASSERT  Service_SCSIDying < Service_SCSIAttached
        ASSERT  Service_SCSIAttached < Service_SCSIDetached
ServiceCallTable
        DCD     0
        DCD     ServiceCallEntry - Module_BaseAddr
        DCD     Service_PreReset
        DCD     Service_PostInit
      [ OSMem19
        DCD     Service_PagesUnsafe
      ]
        DCD     Service_SCSIStarting
        DCD     Service_SCSIDying
        DCD     Service_SCSIAttached
        DCD     Service_SCSIDetached
        DCD     0

        DCD     ServiceCallTable - Module_BaseAddr
ServiceCall     ROUT
        MOV     r0, r0
        Push    "lr"
        LDR     lr, =Service_SCSIStarting
        TEQ     r1, #Service_PreReset
        EORNES  lr, r1, lr ; equals Service_SCSIStarting?
        TEQNE   r1, #Service_PostInit
      [ OSMem19
        TEQNE   r1, #Service_PagesUnsafe
      ]
        TEQNE   lr, #Service_SCSIDying :EOR: Service_SCSIStarting
        TEQNE   lr, #Service_SCSIAttached :EOR: Service_SCSIStarting
        TEQNE   lr, #Service_SCSIDetached :EOR: Service_SCSIStarting
        Pull    "pc", NE
        B       %FT10
ServiceCallEntry
        Entry
10
        TEQ     r1, #Service_PreReset
        beq     D_Service_PreReset
        TEQ     r1, #Service_PostInit
        beq     D_Service_PostInit
      [ OSMem19
        TEQ     r1, #Service_PagesUnsafe
        BEQ     D_Service_PagesUnsafe
      ]
        LDR     lr, =Service_SCSIStarting
        SUB     lr, r1, lr
        ADD     pc, pc, lr, LSL #2
        NOP
        B       D_Service_SCSIStarting
        ASSERT  Service_SCSIDying = Service_SCSIStarting+1
        B       D_Service_SCSIDying
        ASSERT  Service_SCSIAttached = Service_SCSIStarting+2
        B       D_Service_SCSIAttached
        ASSERT  Service_SCSIDetached = Service_SCSIStarting+3
        B       D_Service_SCSIDetached

D_Service_PostInit
        EXIT
D_Service_PreReset
        bl      ChipKillFromService
        EXIT
D_Service_SCSIAttached
; DebugReg r0,"SCSIAttached0 "
; DebugReg r1,"SCSIAttached1 "
; DebugReg r2,"SCSIAttached2 "
; DebugReg r12,"SCSIAttachedr12 "
        EXIT
D_Service_SCSIDetached
; DebugReg r0,"SCSIDetached "
        EXIT
D_Service_SCSIStarting
; DebugReg r0,"SCSIStarting "
        EXIT
D_Service_SCSIDying
; DebugReg r0,"SCSIDying "
        EXIT
      [ OSMem19
D_Service_PagesUnsafe
        LDR     r12, [r12]
        STRB    r1, PagesUnsafeSeen
        EXIT
      ]


Init    ROUT
        Push    "r8-r9,lr"
        MOV     r0, #ModHandReason_Claim
        LDR     r3, =TotalRAMRequired
        SWI     XOS_Module
        BVS     ExitInitModule

        STR     r2, [r12]
        mov     r12, r2
        MOV     r0, #0
01
        SUBS    r3, r3, #4              ; flush the RMA
        STR     r0, [r2], #4
        BGT     %BT01

        ; Get HAL routine pointers
        MOV     R8, #OSHW_LookupRoutine
        MOV     R9, #EntryNo_HAL_CounterDelay
        SWI     XOS_Hardware
        STRVC   R0, HAL_CounterDelay_p
        STRVC   R1, HAL_SB
        MOVVC   R9, #EntryNo_HAL_IRQClear
        SWIVC   XOS_Hardware
        BVS     ExitInitModule
        STR     R0, HAL_IRQClear_p

        MOV     R0, #0
        SWI     XOS_PlatformFeatures
        TST     R0, #2
        ADREQ   R1, DummyIRQTrigger
        STR     R1, IRQTrigger

        LDR     R0, =(ARMop_DMB_Write:SHL:8)+MMUCReason_GetARMop
        SWI     XOS_MMUControl
        ADRVS   R0, My_DMB_Write        ; old kernel?
        STR     R0, ARMop_DMB_Write_p

      [ OSMem19
        MOV     R0, #SecLen
        MOV     R1, #0
        MOV     R2, #0
        SWI     XPCI_RAMAlloc
        BVS     ExitInitModule
        STR     R0, NullWrBuffer
        ADD     R1, R0, #SecLen
        MOV     R2, #0
02
        STR     R2, [R0], #4
        CMP     R0, R1
        BNE     %BT02
      ]

        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_RegisterFiles   ; ignore errors
; now start the module interfaces using a callback
; this ensures our SWIs are available to other modules during interface start
        adrl    r0, StartUpRoutine      ; launch the driver on a callback
                                        ; so our SWIs can be used
        mov     r1, r12                 ; r12 to use
        swi     XOS_AddCallBack         ; assume it valid!!
        movvc   r0, #cb_pending
        strvcb  r0, STcallbackstate
        Pull    "r8-r9,pc"

ExitInitModule                            ; need to check for what is allocated
        Pull    "r8-r9,pc"

; free all and exit
Final   ROUT
        Push    "r0-r3,lr"
        LDR     r12, [r12]

; de-register callback handler
        bl      KillIDReCall

        ldrb    r0, STcallbackstate       ; pending callback to StartUpRoutine?
        teq     r0, #cb_pending         ; still pending?
        adreql  r0, StartUpRoutine
        moveq   r1, r12
        swieq   XOS_RemoveCallBack      ; ok clean up


        bl      SSKill                  ; get out of SoftSCSI stuff


        bl      ChipKill                ; silence the chip itself





        ADRL    R0,resourcefsfiles
        SWI     XResourceFS_DeregisterFiles ; ignore errors
      [ OSMem19
        LDR     R0, NullWrBuffer
        SWI     XPCI_RAMFree
      ]
        MOV     r0, #ModHandReason_Free
        mov     r2, r12
;  DebugReg r2, "freeing rma "
        SWI     XOS_Module
        CLRV

        Pull    "r0-r3,pc"


DummyIRQTrigger
        MOV     pc, lr

My_DMB_Write
        DMB     ST
        MOV     pc, lr

        LTORG
;
resourcefsfiles
        ResourceFile    Resources.AHCIDriver_Help, Resources.AHCIDriver.AHCIDriver_Help
        DCD     0                   ; terminator

        GET     s.Debug

; call back to issue the device starting service call whilst
; able to respond to SWIs
; R12 is module private word
StartUpRoutine  ROUT
        Entry   "r0, r1, r2, r3, r8"

; locate the device address.. HAL should have registered it by now
        ldr     r0, = HALDeviceType_ExpCtl + HALDeviceExpCtl_AHCI +0<<16
        mov     r1, #0                  ; first time through
        mov     r8, #4                  ; enumerate_drivers
        swi     XOS_Hardware
; DebugReg r1, "looking.. r1= "
; DebugReg r2, "DevPtr... "
        teq     r1, #0                  ; if -1, no find the ethernet device
        EXIT    LE                      ; else we cannot do anything here
; DebugReg r12, "mod pwp... "
        adrl    r1, AHCIDevice
        mov     r0, #HALDevice_AHCI_Size
1       subs    r0, r0, #4
        ldrge   lr, [r2, r0]
        strge   lr, [r1, r0]           ; copy it
        bgt     %bt1
        bl      SSInit                  ; init scsisoft stuff
        ldr     r0, ChipBase
;       DebugReg r0, "ChipBase: "
        bl      ChipInit


        EXIT

AddIDReCall  ROUT
        Entry   "r0-r2"
        adr     r0, IDRoutine
        mov     r1, r12
        swi     XOS_AddCallBack
        movvc   r0, #cb_pending         ; flag we got here
        strvcb  r0, IDcallbackstate
        EXIT

KillIDReCall  ROUT
        Entry   "r0-r2"
        ldrb    r0, IDcallbackstate
        teq     r0, #cb_pending         ; active?
        EXIT    NE                      ; no
        adr     r0, IDRoutine
        mov     r1, r12
        swi     XOS_RemoveCallBack
        EXIT


; IDRoutine, do an IDENTIFY command to device
; triggered from IRQ by callback. Set device as ready once good
;
; we'll really need a buffer for each device present
;
IDRoutine       ROUT
        Entry   "r0-r10"
        ldrb    r9, IDcallbackport      ; the device we need
        mov     r0, #cb_unrequired      ; flag we got here
        strb    r0, IDcallbackstate
        ldr     r0, AHCIDevRdy
        tst     r0, #1<<0               ; check device 0
        EXIT    EQ                      ; not ready

        mov     r0, #10*1024            ; approx 10 ms
        bl      HAL_CounterDelay        ; some things need this

        adrl    r0, IDBuffer
        mov     r2, #IDBufferLen
        mov     r1, #0
; clear the buffer
        sub     r3, r2, #4
1       str     r1, [r0, r3]
        subs    r3, r3, #4
        bge     %bt1
; now lets get going
        orr     r2, r2, #(1<<31)        ; read
        mov     r3, #ATAPI_COMMAND_IDENTIFY_DEVICE
        mov     r5, #100                ; 100cs
        mov     r6, #0                  ; no callback .. forground
        orr     r9, r9, #&10000000      ; set fg read etc to dev ID
; DebugReg r9, "IDR entry "
        bl      BuildandCompleteEntry   ; do it and await completion
; DebugReg r0, "IDR "
        teq     r0, #TARGET_GOOD
        bne     retry1                  ; try again if command failed
                                        ; TODO use a CallAfter to sleep for a while so that we don't hang the system

;; all completed.. analyse the ID stuff
;1
; DebugTX "ID Cmd done "
        adrl    r0, IDBuffer
        add     r1, r0, #512
; ldr r3, [r1, #-4]
; DebugReg r3, "IDBuf end bits "
        mov     r2, #0
1       ldrb    r3, [r0], #1
        add     r2, r2, r3
        cmp     r1, r0
        bgt     %bt1                    ; loop till all done
        ands    r2, r2, #&ff
        beq     %ft2
retry1
        ldr     r0, AHCIDevRdy
        tst     r0, #1<<0               ; check device 0
        EXIT    EQ                      ; not ready
                                        ; checksum failed
; DebugTX "Retrying ID fetch "
        ; check if device is still there
        bl      AddIDReCall
        EXIT

; analyse the configuration.
; SID_lba_total_sectors_p is mandatory.
; = sector count in logical sectors (512byte) = capacity in 28 but addressing
2
; DebugTXS "ID buffer good "
        adrl    r0, IDBuffer
        ldrh    r1, [r0, #SID_cmd_set_supp_p1]
; DebugRegNCR r1, "Features2 "
        tst     r1, #BIT_SID_CmdSup1_48BIT      ; 1 if 48bit supported
        ldr     r1, DevFeatures
        orrne   r1, r1, #DevFeature48bit
        biceq   r1, r1, #DevFeature48bit
        str     r1, DevFeatures
; DebugReg r1, "DevFeatures "
; ******************* if multi ahci ports, need to be more specific

        bl      ConvertIDTextEndian

        mov     r0, #0
        bl      SSRegister
        EXIT


; ID Data extraction routines
; on entry, r0 = Device number (0..15) to use
;           r1-> buffer for result if string
;  currently only device 0 implemented
; on exit
; either R1 = answer, or buffer at r1 filled in
;
IDVendor        ROUT
        Entry   "r3, r4"
        adrl    r3, IDBuffer
        add     r3, r3, #SID_model_num_p
        mov     r4, #7
1       ldrb    lr, [r3, r4]
        strb    lr, [r1, r4]
        subs    r4, r4, #1
        bge     %bt1
        EXIT
IDProduct       ROUT
        Entry   "r3, r4"
        adrl    r3, IDBuffer
        add     r3, r3, #SID_model_num_p+8
        mov     r4, #15
1       ldrb    lr, [r3, r4]
        strb    lr, [r1, r4]
        subs    r4, r4, #1
        bge     %bt1
        EXIT
IDRevision      ROUT
        Entry   "r3, r4"
        adrl    r3, IDBuffer
        add     r3, r3, #SID_fw_rev_p
        mov     r4, #3
1       ldrb    lr, [r3, r4]
        strb    lr, [r1, r4]
        subs    r4, r4, #1
        bge     %bt1
        EXIT
IDBlocksize     ROUT
        Entry   "r3, r4"
        ldr     r1, =&00020000          ; default logical sector size 512 bytes
        EXIT
IDCapacity      ROUT
        Entry   "r3, r4"
        adrl    r3, IDBuffer
        ldr     lr, DevFeatures
        tst     lr, #DevFeature48bit    ; nz if 48bit addressing
        moveq   r4, #(SID_lba_total_sectors_p)
        movne   r4, #(SID_max_48b_lba_addr_p)
        add     r4, r4, r3
        ldrb    r1, [r4], #1
        ldrb    lr, [r4], #1
        orr     r1, lr, r1, lsl #8
        ldrb    lr, [r4], #1
        orr     r1, lr, r1, lsl #8
        ldrb    lr, [r4], #1
        orr     r1, lr, r1, lsl #8
        EXIT    EQ
; DebugTX "48bit capacity"
        ldrb    lr, [r4], #1
        teq     lr, #0
        ldreqb  lr, [r4], #1
        teq     lr, #0
        ldreqb  lr, [r4], #1
        teq     lr, #0
        ldreqb  lr, [r4], #1
        teq     lr, #0
        movne   r1, #&ffffffff
        EXIT

; ConvertEndian - convert ID buffer to littlendian
; on entry r0->buffer, r1=length to convert, r2 = start offset
; assumes buffer is word aligned
ConvertEndian   ROUT
        Entry   "r0-r4"
        add     r0, r0, r2
1       ldrh    r3, [r0]
        mov     r4, r3, lsr #8
        orr     r4, r4, r3, lsl #8
        strh    r4, [r0], #2
        subs    r1, r1, #2
        bgt     %bt1
        EXIT

; Convert the text portions of the ID buffer to correct sense
; on entry r0->buffer
ConvertIDTextEndian ROUT
        Entry   "r0-r4"
        mov     r2, #SID_serial_p
        mov     r1, #SID_rsv7-SID_serial_p
        bl      ConvertEndian
        mov     r2, #SID_fw_rev_p
        mov     r1, #SID_rw_mult_support-SID_fw_rev_p
        bl      ConvertEndian
        EXIT

; callback system


;;Initialise callbacks
;; on entry r12->private word
;callback_init  ROUT
;       Entry
;       mov     r0, #cb_unrequired
;       strb    r0, STcallbackstate
;       mov     r2, r12
;       adr     r1, callbackhandler
;       swi     XOS_

; Macro to encapsulate handling of scatter lists
; Adapted from similar code in DMAManager
; Skips zero-length entries and any loopback entries
        MACRO
$label  NextScatter $list, $add, $count
; DebugRegNCR $list,"scatter- "
        ASSERT $count > $add
$label
111     ldmia   $list!, {$add, $count}
; DebugRegNCR $add, ""
; DebugReg $count
        cmp     $add, #ScatterListThresh
        teqhs   $count, #0
        addeq   $list, $list, $add
        subeq   $list, $list, #8        ; allow for the earlier increment
        teqne   $count, #0
        beq     %bt111
        MEND



 [ :LNOT: OSMem19

; UnCache .. render memory uncachable and return physical page addresses
; ***** the imx ahci works in 16 bit transfers, so cannot handle transfers that start
; ***** on an odd byte boundary. Consequently we need to create a replacement byte
; ***** data, aligned transfer list. For write, we copy into this buffer set the
; ***** relevant data, and for read, we need to copy it out at the end of the
; ***** transfer.
; ***** this is implemented as a 'skin' before UnCache to get replacement buffers
; ***** preload with write data, and a 'skin' after ReCache to copy read data
; ***** and free the buffer string.
; on entry,
; r0 = start address or scatter pointer
; r2 = total length
; r9 bit 26 set if its a scatterlist
; on exit
; r2-> rma block with pagelist to reenable caching subsequently
; with first word containing number of entries and the second word
; containing  an oddbyte buffer pointer or Null if it is an aligned transfer
; in the ReCache routine
; format of UnCache header
                ^       0
UcBlock         #       0
UcPblkC         #       4               ; page block count
UcOddBuff       #       4               ; OddByte start buffer pointer or NULL
UcAddr          #       4               ; Original address pointer
UcCount         #       4               ; Original byte count
UcFlags         #       4               ; original transfer flags
UcXferCount     #       4               ; transfer count we actually use
UcSpBuf         #       4               ; in case we need a couple of bytes in write
UcSpRdAddr      #       4               ; address to put last read byte
UcSafeScatter   #       4               ; store start address in case scatter
                                        ; contains an unusable address
UcSafeCount     #       4               ; and corresponding byte count
UcNonScatter    #       16              ; 2 entry scatter list for use with non
                                        ; scatter transfer
UcPlain2Scat    #       8               ; scatter pointre for 'plain' use
LABOffset       #       0               ; offset to first OS_Memory page block
;
UnCache         ROUT
        Entry   "r0-r1, r3-r11"
; DebugRegNCR r0 , "UnCacR0 "
; DebugRegNCR r2 , "UnCacR2 "

        tst     r2, #(1<<31)            ; remember r/w state in r10
        moveq   r10, #1                 ; remember as write
        movne   r10, #0                 ; remember as read
; DebugByteReg r10, "W? "
; DebugRam Save lr, r10
        bic     r2, r2, #(1<<31)        ;clear the r/~w bit if set
; it is a scatter list. This means discontiguous chunks
; first r2 = byte count. As we dont know about page start/stop stuff lets
; claim a relatively rediculous amount of ram .. twice the block count
; (based on start and stop point of each pair being in different pages)
; for building the page list
        mov     r3, r2, lsr #12         ; to 4k blocks
        add     r3, r3, #4              ; add2 + 2 word for alignment correction
        mov     lr, r3, lsl #1          ; double ; it still isnt much!
        add     r3, lr, lr, lsl #1      ; 3 words per block
; DebugReg r3, "sc-claim for block count "
        mov     r3, r3, lsl #2          ; to bytes
        mov     r11, #0                 ; used for handling odd last byte
        add     r3, r3, #LABOffset
        mov     r5, r0                  ; remember scatter pointer
        mov     r6, r2                  ; remember total byte count
        mov     r0, #ModHandReason_Claim
        swi     XOS_Module
        strvs   r0, [sp]
        EXIT    VS
        mov     r7, #&1000
        sub     r7, r7, #1              ; r7 = mask
        add     r3, r2, #LABOffset +4   ; point at first LA block logical address
        mov     r8, #0
        str     r8, [r2, #UcOddBuff]    ; flag no alignment buffer yet (null)
        str     r8, [r2, #UcSpRdAddr]   ; flag no odd byte read correction needed
        tst     r9, #(1<<ScatterListBit)
        orr     r9, r9, #(1<<ScatterListBit) ; force scatter
        orr     r4, r9, r10, lsl #31
        str     r4, [r2, #UcFlags]
        addeq   r4, r2, #UcPlain2Scat
        stmeqia r4, {r5, r6}            ; lets convert to scatter
        moveq   r5, r4                  ; and remember this fabricated scatter pointer
        str     r5, [r2, #UcSafeScatter]
        str     r6, [r2, #UcSafeCount]  ; belt and braces remember for later
goaroundagain
        mov     r4, #0                  ; initialise total transfer count achieved
; vet the scatter list.. UNSAFE to do anything within the
;  OS workspace areas above &FA000000 so move it elsewhere
; via ConvertToWordAligned

        CLRV
 [ AlwaysTestCVA
        bl      ConvertToWordAligned
 |
        ldr     r0, [r5]                ; get first buffer address
        tst     r0, #PRDDataAlignment-1 ; wrong alignment?
        blne    ConvertToWordAligned
 ]
        bvs     %ft90

; get scatter entry
2
        NextScatter r5, r0, r1          ; get next scatterlist entry
; DebugRegNCR R0, "nsaddr "
; DebugRegNCR R1, "nscount "
scatterbypass
        cmp     r1, r6                  ; don't ask more than total count remaining
        movgt   r1, r6                  ; round down if so
; DebugRegNCR R6, "totc "
; DebugRegNCR R0, "baddr "
; DebugRegNCR R1, "bcount "
; DebugRamSave lr,"r0-r1"
; check the scatter does not contain illegal addressing above
; the OS workspace start at &FA000000
        cmp     r0, #DirectAddressCeiling
        bcc     itsOK                   ; (unsigned lower)
; oops.. cannot do things directly.. unwind and restart
;  with ConvertToWordAligned routine
UnwindAndCTWA
        add     r3, r2, #LABOffset +4   ; point at first LA block logical address
        mov     r8, #0
        str     r8, [r2, #UcOddBuff]    ; flag no alignment buffer yet (null)
        str     r8, [r2, #UcSpRdAddr]   ; flag no odd byte read correction
        ldr     r5, [r2, #UcSafeScatter]
        ldr     r6, [r2, #UcSafeCount]  ; belt and braces remember for later
        mov     r4, #0                  ; initialise total transfer count
; DebugTX "about to ctwa "
        bl      ConvertToWordAligned
        bvs     %ft90
; DebugTX "done ctwa "
        b       goaroundagain
itsOK
        tst     r1, #1                  ; odd byte count?
        beq     doblockset              ; nothing to worry about
;       cmp     r1, r6                  ; if the odd count isnt at the end
;        bge    %ft1
;  DebugTX "odd b abandon "
        cmp     r1, r6                  ; if the odd count isnt at the end
1       blt     UnwindAndCTWA           ; convert it by hand
; we've a read or write with odd byte count. this means we reduce it by 1 byte,
; remembering that last byte, then merge that byte at the beginning of the
; subsequent block, shifting whole block to useful place for
; producing a byte aligned blk
;3
        cmp     r1, r6                  ; don't ask more than total count remaining
        movgt   r1, r6                  ; round down if so
        sub     lr, r1, #1
        tst     r10, #1
        ldrneb  r11, [r0, lr]            ; get last byte if write
        addeq   lr, lr, r0
        streq   lr, [r2, #UcSpRdAddr]   ; flag we need to hand xfer final byte at end

; DebugRegNCR r6, "Bytes to do "

; DebugByteReg r11, "final byte from write "
        orr     r11, r11, #(1<<31)      ; set hi bit to flag in use


        teq     r6, #1

        beq     doblockset              ; we've only got 1 byte in total.. dont revisit scatter
        subs    r1, r1, #1
        beq     %bt2                    ; this had only 1 byte
; DebugReg R1, " count now "

doblockset                              ; first time through
; DebugRegNCR r0, "dbs-Addr/Len/Max "
; DebugRegNCR r1, ""
; DebugRegNCR r6, ""
        cmp     r1, r6                  ; don't ask more than total count remaining
        movgt   r1, r6                  ; round down if so
        teq     r1, #1
        beq     entrydone
; DebugRegNCR r3, ""
; lr now in use.. no debugpr ...
        orr     lr, r0, r7              ; get page end of start address
        add     lr, lr, #1              ; past it
        add     r9, r0, r1              ; end address
        cmp     r9, lr                  ; LT means all in this page
        movlt   r9, r1                  ; .. whole byte count
        subge   r9, lr, r0              ; or length to end of this page
; lr out of use, can debugpr
        str     r0, [r3], #12           ; start page block
        str     r9, [r3,#-16]           ; byte count in unused page field
        add     r4, r4, r9              ; accumulate transfer count
; DebugRegNCR r0, "pbstrt "
        add     r8, r8, #1              ; and count
        sub     r6, r6, r9              ; take length off total
; compute to end of block
        add     r0, r0, r9              ; next block start if needed
; DebugRegNCR r8, "prdc "
; DebugRegNCR r4, " so far "
; DebugReg r9, "cnt.this.page "
        subs    r1, r1, r9              ; whats left if not all used
        bgt     doblockset

entrydone
; DebugReg r6, "bytes left after this "
        tst     r11, #(1<<31)
        bne     sortlastbyte            ; need to do last byte of odd count write
        cmp     r6, #0                  ; accounted for all byte count?
        bgt     %bt2                    ; not yet
        b       listdone

sortlastbyte
        bic     r11, r11, #(1<<31)      ; acknowledge
; teq r11, #&0
; DebugRamOn r0  ,eq

; DebugByteReg r11, "finalwrb "
; ok, we have last byte in r11, or need to read last byte, so fabricate a scatter entry
        add     r0, r2, #UcSpBuf
; DebugRamSave lr, r11
        tst     r10, #1                 ; read or write
        strne   r11, [r0]               ; save byte if write
        mov     r1, #2
        mov     r6, #2
        b       doblockset
listdone
; DebugReg r6, "mmbytes left after this "
        mov     r0, #1<<L2SecSize       ; whole sector
        sub     r0, r0, #1
        ands    r1, r4, r0              ; partial sector
        beq     %ft1                    ; no partial sector
        ldr     r0, [r2, #UcFlags]
        tst     r0, #1<<31              ; is it write
        beq     %ft1                    ; no.. irrelevant
        mov     r0, #1<<9
        sub     r1, r0, r1
;  DebugReg r1, "OddEndPad "
        mov     r6, r1
        adrl    r0, NullWrBuffer
        b       doblockset              ; 1 final but to show this
1
; DebugRegNCR r8, "block count "
        str     r8, [r2, #UcPblkC]      ; remember block count
; DebugRegNCR r2, "pointer "
; DebugRegNCR r4, "Saved byte count "
;        tst     r4, #1
; DebugReg r4, "modded Saved byte count "
        str     r4, [r2, #UcXferCount]  ; and actual transfer bytes needed

        mov     r0, #(2<<14) + (1<<9) + (1<<13) ; uncache from logical addresses
                                                ; and return physical addresses
        add     r1, r2, #LABOffset              ; start of page block list
        mov     r2, r8                  ; entry count
        swi     XOS_Memory              ; process the page list
        sub     r2, r1, #LABOffset
        bvs     %ft80
; DebugReg r2 , "UnCacR2 out "           ; return page list for later use.
                                        ; first word is number of entries
        CLRV
        EXIT

80
        ; Failed to make something uncachable
        ; TODO - Try forcing ConvertToWordAligned
        ; For now, just give up
        str     r0, [sp]
;        DebugTX "XOS_Memory uncache failed"
        mov     r4, r2
        ldr     r2, [r2, #UcOddBuff]
        mov     r0, #ModHandReason_Free
        swi     XOS_Module
        mov     r2, r4
        b       %ft91
90
        ; Failed to ConvertToWordAligned
        str     r0, [sp]
;        DebugTX "ConvertToWordAligned failed"
91
        mov     r0, #ModHandReason_Free
        swi     XOS_Module
        SETV
        EXIT


; ReCache .. render memory cachable again
; on entry,
; r0-> rma block with pagelist supplied by a call to
; UnCache routine
ReCache         ROUT
        Entry   "r0-r4"
; DebugReg r0, "ReCache "
        ldr     r2, [r0, #UcSpRdAddr]   ; hand write last rd byte?
        teq     r2, #0
; beq %ft1
        ldrneb  r4, [r0, #UcSpBuf]
        strneb  r4, [r2]                ; byte to place
;        DebugRamOn r2, ne
;        DebugReg r4, "last read "

1
        ldr     r2, [r0, #UcOddBuff]    ; alignment buffer pointer
        teq     r2, #0                  ; if buffer,
        blne    ConvertFromWordAligned  ; then sort it and clear down
; DebugTX "<>"


; DebugRegNCR r0 , "ReCac in "
        ldr     r2, [r0,#UcPblkC]       ; page count to recache
; DebugRegNCR r2, "R2 "
        add     r1, r0, #LABOffset
; DebugReg r1, "R1 "
        mov     r0,#(3<<14) + (1<<9)    ; recache from logical addresses
        swi     XOS_Memory              ; process the page list
        MOV     r0, #ModHandReason_Free
        sub     r2, r1, #LABOffset
; DebugTXS "bfr"
        swi     XOS_Module              ; now free the list
; DebugReg r0, "after"
        EXIT

; On Entry:
; r5-> odd byte aligned buffer or scatter pointer
; r6 = total byte count
; r2->UnCache buffer
; r9 is #(1<<ScatterListBit) if scatter
; r10 = 1 if write, else 0
; On exit:
; r5-> new word aligned buffer or scatter ptr
; r6 = byte count
; buffer addr stored at [r2+UcOddBuff] ..=>there is an alignment buffer to consider
; r5 stored at [r2+UcAddr]
; r6 stored at [r2+UcCount]
; r9 + (r10<<31) stored at [r2+UcFlags]
; if it is a write transaction the data has been copied over
; either scatter or non scatter.. in the end we just need a simple linear secondary buffer
; format of wordalignment buffer
                ^       0
WaBlock         #       0
WaScatter       #       16              ; dual entry scatter
WaBuffer        #       0               ; start of actual workbuffer
;
ConvertToWordAligned ROUT
        Entry   "r0-r4, r6, r9"
; now claim the buffer we need
        orr     r9, r9, r10,lsl #31
        str     r9, [r2, #UcFlags]      ; transfer flags
        str     r6, [r2, #UcCount]      ; bytecount
        str     r5, [r2, #UcAddr]       ; address
; DebugRegNCR r6 , "saving count "
; DebugRegNCR r5 , "addr "
; DebugReg r9 , "flags "
        ASSERT  PRDDataAlignment <= 4   ; OS_Module only provides 4 byte alignment - will need to use something else (PCI?) for bigger
        mov     r0, #ModHandReason_Claim
        add     r3, r6, #WaScatter      ; use first words as a scatter pointer
        add     r3, r3, r10, lsl #L2SecSize ; add an extra sector of space for write
                                        ; in case we have to pad to sector
                                        ; length
; DebugReg r3 , "claiming "
        mov     r4, r2
        swi     XOS_Module
        strvs   r0, [sp]
        EXIT    VS
        str     r2, [r4, #UcOddBuff]    ; remember buffer ptr
; DebugRegNCR r2 , "cwa buf addr"
; DebugReg r9 , "flags"
        tst     r9, #(1<<ScatterListBit); scatter
        add     r5, r2, #WaBuffer       ; point to buffer past scatter
        strne   r5, [r2, #WaScatter]    ; newc scatter src address
        strne   r6, [r2, #WaScatter+4]  ; and count
        movne   r5, r2                  ; point to scatter
        tst     r10, #1                 ; is it a write?
        EXIT    EQ                      ; read.. we're done
; its write ; r6 is total buffer, r5 is local buffer or its scatter
; r4 = Uncach buffer
        tst     r9, #(1<<ScatterListBit); scatter
        moveq   r9, r5
        addne   r9, r5, #WaBuffer       ; our data start
        ldr     r6, [r4, #UcCount]      ; bytecount
        ldr     r2, [r4, #UcAddr]       ; src addr or scatteraddress
        moveq   r3, r6                  ; non scatter if EQ
        add     r6, r9, r6              ; dest end addr
        beq     wrsc0                   ; non scatter if EQ
;
        mov     r4, r2                  ; set scatter list address
nextwrscat
        NextScatter r4, r2, r3
; check if we can use all this buffer
; r6 is total byte count dest end address
wrsc0
; DebugRegNCR r9, "dest "
; DebugRegNCR r6, "wr end "
; DebugRegNCR r3, "count "
        sub     lr, r6, r9
        cmp     r3, lr
        movgt   r3, lr                  ; only what we are allowed
; DebugReg r3, "count used "
wrsc1
        ldrb    r1, [r2], #1
        strb    r1, [r9], #1
        subs    r3, r3, #1
        bgt     wrsc1
        cmp     r9, r6
        blt     nextwrscat
        CLRV
        EXIT

; On Entry:
; r0->UnCache buffer
; if it is a read transaction, the resultant data needs copying back
ConvertFromWordAligned ROUT
        Entry   "r0-r6"
        ldr     r4, [r0, #UcOddBuff]    ; get CWA buffer
        teq     r4, #0                  ; safety...
        EXIT    EQ                      ; no buffer involved (safety
        ldr     r1, [r0, #UcFlags]
; DebugReg r1, "unc flags "
        tst     r1, #1<<31              ; is it a write?
        bne     notread                 ; yes.. all done
; it was a read, so we need to 'unpack' ther read buffer into the destination
        tst     r1, #(1<<ScatterListBit); scatter
        ldr     r2, [r0, #UcCount]      ; total byte count
        ldr     r1, [r0, #UcAddr]       ; destination address or scatter ptr
        add     r4, r4, #WaBuffer       ; bypass the scatter table
        add     r6, r4, r2              ; set srce end address
        beq     scatcpy
        mov     r5, r1                  ; dest scatter list pointer
nextscattr
        NextScatter r5, r1, r2
scatcpy
; DebugTX "notscatr "
; DebugRegNCR r1, "read dest addr "
; DebugRegNCR r4, "src "
; DebugRegNCR r6, "srcend addr "
        sub     lr, r6, r4
        cmp     r2, lr
        movgt   r2, lr                  ; its all we have left
; DebugReg r2, "using "

notsc1  ldr     r3, [r4], #4
        strb    r3, [r1], #1
        mov     r3, r3, lsr #8
        subs    r2, r2, #1
        strgtb  r3, [r1], #1
        movgt   r3, r3, lsr #8
        subgts  r2, r2, #1
        strgtb  r3, [r1], #1
        movgt   r3, r3, lsr #8
        subgts  r2, r2, #1
        strgtb  r3, [r1], #1
        subgts   r2, r2, #1
        bgt     notsc1
;  DebugRegNCR r4, "src addr "
;  DebugRegNCR r6, "srcend addr "
;  DebugReg r1, "end dest "

        cmp     r4, r6
        blt     nextscattr              ; more scatter to consider
; ldrb r2, [r1, #-1]
; DebugByteRegNCR r2, "dl "
; tst r1, #3
; bicne r1, r1, #3
; subeq r1, r1, #4
; ldr r2, [r1]
; DebugRegNCR r1, "dest last "
; DebugRegNCR r2, "data "
; tst r4, #3
; bicne r1, r4, #3
; subeq r1, r4, #4
; ldr r2, [r1]
; DebugRegNCR r1, "src last "
; DebugRegNCR r2, "data "
notread
; DebugTX "<>"
; all done with buffer?.. then free it
        ldr     r2, [r0, #UcOddBuff]    ; get buffer addr
;  DebugReg r2, "free "
        teq     r2, #0                  ; safety...
        movne     r0, #ModHandReason_Free
        swine   XOS_Module              ; now free the list
        EXIT

 |
        GET     s.scatter
 ]


; more bits..
        GET     s.chip

;
        GET     s.scsisoft


        END
