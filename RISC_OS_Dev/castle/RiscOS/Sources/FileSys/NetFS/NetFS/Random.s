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
        SUBT => &.Arthur.NetFS.Random

        ; *****************
        ; ***  O P E N  ***
        ; *****************

Open            ROUT
        ;       R0 => Mode of open
        ;       R1 => Pointer to name
        ;       R2 => FileSwitch External handle
        ;       R6 => Pointer to special field or zero
        ;       R0 <= Bit 30 set if we have Read.  Bit 31 set if we have Write.
        ;       R1 <= Handle, zero for not found
        ;       R2 <= Buffer size to use (&400)
        ;       R3 <= File's extent
        ;       R4 <= File's size (occupied space)
        ;       R6 <= File's attributes (FS format for internal use)
        ;       R7 <= Name of file used (by the file server)
        ;       Trash R5, R9 - R12

        Push    lr
        LDR     wp, [ r12 ]
        [       Debug
        DREG    r0, "OS_Find_Open, mode = &"
        ]
        BL      UseNameToSetTemporary
        BVS     ExitFromOpen
        BL      ClearFSOpFlags
        B       CommonOpen

NastyOpen
        Push    lr
CommonOpen
        CMP     r0, #1                                  ; Type of open
        MOV     r0, r1                                  ; Name
        MOV     r7, r1                                  ; For later
        MOV     r10, r2                                 ; For later
        ADR     r1, CommandBuffer
        MOV     r3, #1                                  ; Default
        MOV     r4, #0                                  ; Default
        MOVEQ   r3, #0                                  ; OpenOut
        MOVLT   r4, #1                                  ; OpenIn
        STRB    r3, [ r1, #0 ]
        STRB    r4, [ r1, #1 ]
        MOV     r2, #2
        BL      CopyObjectNameInDoingTranslation
        BVS     FileNotOpened
        [       Files24Bit :LAND: Files32Bit
        LD      r14, Temporary
        LDRB    r14, [ r14, #Context_Flags ]
        TST     r14, #Context_Flags_32Bit
        [       Debug
        BEQ     %11
        DLINE   "Using OpenExtended"
11
        ]
        MOVEQ   r0, #FileServer_Open
        MOVNE   r0, #FileServer_OpenExtended
        |
        [       Files24Bit
        MOV     r0, #FileServer_Open
        ]
        [       Files32Bit
        MOV     r0, #FileServer_OpenExtended
        ]
        ]
        BL      DoFSOp
        BVS     FileNotOpened
        LDRB    r11, [ r1 ]                             ; File server's handle
        MOV     r3, #Size_FCB
        BL      MyClaimRMA                              ; Returns R2
        BVS     ExitFromOpenWithClose
        MOV     r9, r2                                  ; Address of FCB
        LDR     r14, =FCBIdentifier
        STR     r14, [ r9, #FCB_Identifier ]
        STR     r9, [ r9, #FCB_Handle ]
        STRB    r10, [ r9, #FCB_TuTuHandle ]
        LDR     r0, Temporary
        STR     r0, [ r9, #FCB_Context ]
        STRB    r11, [ r9, #FCB_Channel ]               ; Loaded earlier
        MOV     r0, #NIL
        STR     r0, [ r9, #FCB_Buffer ]

        [       Files24Bit :LAND: Files32Bit
        LD      r11, Temporary
        LDRB    r11, [ r11, #Context_Flags ]
        TST     r11, #Context_Flags_32Bit
        LDRNEB  r6, CommandBuffer + 2                   ; Attributes from OpenExtended
        LDRNEB  r14, CommandBuffer + 3
        BNE     AttributesRead
        MOV     r0, #5                                  ; Argument to 'read object info' for 'read everything'
        ADR     r1, CommandBuffer
        STRB    r0, [ r1, #0 ]
        MOV     r0, r7                                  ; The name
        MOV     r2, #1
        BL      CopyObjectNameInDoingTranslation
        MOVVC   r0, #FileServer_ReadObjectInfo
        BLVC    DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        LDRB    r6, [ r1, #12 ]                         ; Access and type byte
        LDRB    r14, [ r1, #15 ]                        ; Ownership byte
AttributesRead
        |
        [       Files24Bit
        MOV     r0, #5                                  ; Argument to 'read object info' for 'read everything'
        ADR     r1, CommandBuffer
        STRB    r0, [ r1, #0 ]
        MOV     r0, r7                                  ; The name
        MOV     r2, #1
        BL      CopyObjectNameInDoingTranslation
        MOVVC   r0, #FileServer_ReadObjectInfo
        BLVC    DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        LDRB    r6, [ r1, #12 ]                         ; Access and type byte
        LDRB    r14, [ r1, #15 ]                        ; Ownership byte
        ]
        [       Files32Bit
        LDRB    r6, CommandBuffer + 2                   ; Attributes from OpenExtended
        LDRB    r14, CommandBuffer + 3
        ]
        ]
        TEQAL   r6, #2_00100001                         ; D/R  ==> /spl file on SJ systems
        TEQNE   r6, #2_00100011                         ; D/WR ==> /prt file on SJ systems
        MOVEQ   r6, #2_00000100                         ; R/ gives us access to them
        [       Files24Bit :LAND: Files32Bit
        ASSERT  Context_Flags_32Bit = FCB_Status_32Bit
        AND     r2, r11, #Context_Flags_32Bit           ; FCB gets value from context
        |
        [       Files24Bit
        MOV     r2, #0                                  ; Destined to be the status byte
        ]
        [       Files32Bit
        MOV     r2, #FCB_Status_32Bit
        ]
        ]
        MOV     r10, #fsopen_IsDirectory                ; Destined to be the returned access, default dir
        TST     r6, #BitFive                            ; Is it a dir ??
        ORRNE   r2, r2, #FCB_Status_Directory           ; Set the dir bit
        TEQ     r14, #&FF                               ; Public or Owner ??
        MOV     r0, r6                                  ; Copy for modifying
        myASR   r0, 2, NE                               ; Move Owner bits where public were 'R' Bit0, 'W' Bit1
        AND     r0, r0, #BitZero+BitOne
        TEQ     r0, #2_10                               ; Write allowed, Read not allowed
        ORREQ   r2, r2, #FCB_Status_WriteOnly           ; Set write only bit
        STRB    r2, [ r9, #FCB_Status ]
        BEQ     ExitWithWriteOnlyFile
        TST     r2, #FCB_Status_Directory               ; Was it a directory ??
        MOVNE   r3, #0
        MOVNE   r4, #0
        BNE     ReturnOpenInfo                          ; Fake the random access info
        MOV     r10, r0, ROR #2                         ; Soon to be the FileSwitch access bits (31 and 30)

        [       Files24Bit :LAND: Files32Bit
        TST     r11, #Context_Flags_32Bit
        LDMNEIA r1, { r1, r3, r4 }                      ; Read trash, Extent and Size
        BNE     ExtentAndSizeRead
        ; Must return Extent (actual length of data) in R3
        ; And the Size (disc area occupied) in R4
        ; We can't use the value returned by ReadObjectInfo above
        ; because this varies (on open files) from server to server!
        LDRB    r0, [ r9, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #1                                  ; Read extent
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
        BL      DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        LDR     r4, [ r1 ]                              ; Load the extent
        AND     r4, r4, #&00FFFFFF                      ; Reduce to 24 bits
        LDRB    r0, [ r9, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #2                                  ; Read size
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
        BL      DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        MOV     r3, r4
        LDR     r4, [ r1 ]                              ; Load the size
        AND     r4, r4, #&00FFFFFF                      ; Reduce to 24 bits
ExtentAndSizeRead
        |
        [       Files24Bit
        ; Must return Extent (actual length of data) in R3
        ; And the Size (disc area occupied) in R4
        ; We can't use the value returned by ReadObjectInfo above
        ; because this varies (on open files) from server to server!
        LDRB    r0, [ r9, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #1                                  ; Read extent
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
        BL      DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        LDR     r4, [ r1 ]                              ; Load the extent
        AND     r4, r4, #&00FFFFFF                      ; Reduce to 24 bits
        LDRB    r0, [ r9, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #2                                  ; Read size
        STRB    r0, [ r1, #1 ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
        BL      DoFSOp
        BVS     ExitFromOpenWithDeAllocate
        MOV     r3, r4
        LDR     r4, [ r1 ]                              ; Load the size
        AND     r4, r4, #&00FFFFFF                      ; Reduce to 24 bits
        ]
        [       Files32Bit
        LDMIA   r1, { r1, r3, r4 }                      ; Read trash, Extent and Size
        ]
        ]
ReturnOpenInfo
        LDR     r2, =&400                               ; Sector or buffer size, in bytes
        LDR     r1, [ r9, #FCB_Handle ]
        LDR     r0, FCBs
        STR     r0, [ r9, #FCB_Link ]                   ; Make this the first in the list
        STR     r9, FCBs                                ; Then add it to the list
        MOV     r0, r10                                 ; Access for FileSwitch
        B       ExitFromOpen                            ; V still clear from DoFSOp

ExitWithWriteOnlyFile
        MOV     r3, #WriteOnlySize
        BL      MyClaimRMA
        BVS     ExitFromOpenWithDeAllocate              ; Exit after freeing the FCB
        LDR     r0, FCBs
        STR     r0, [ r9, #FCB_Link ]                   ; Make this the first in the list
        STR     r9, FCBs                                ; Then add it to the list
        STR     r2, [ r9, #FCB_Buffer ]
        MOV     r0, #fsopen_WritePermission + fsopen_UnbufferedGBPB
        LDR     r1, [ r9, #FCB_Handle ]
        MOV     r2, #0                                  ; Show that the file is unbuffered
        STR     r2, [ r9, #FCB_Pointer ]
        STR     r2, [ r9, #FCB_BufferBase ]
        STR     r2, [ r9, #FCB_BufferExtent ]
        B       ExitFromOpen                            ; V still clear from XOS_Module

FileNotOpened
        LDRB    r2, [ r0 ]                              ; The error number
        EORS    r1, r2, #ErrorNumber_FileNotFound :AND: &FF ; Return a handle of zero
        CLRV    EQ
        B       ExitFromOpen

ExitFromOpenWithDeAllocate
        MOV     r2, r9                                  ; Now clean up deleting the FCB
        MOV     r9, r0                                  ; Preserve original error
        BL      MyFreeRMA
        MOV     r0, r9                                  ; We don't care if this went bang
ExitFromOpenWithClose
        MOV     r9, r0
        ADR     r1, CommandBuffer
        STRB    r11, [ r1 ]                             ; Original file server handle
        MOV     r0, #FileServer_Close
        MOV     r2, #1
        BL      DoFSOp
        SETV
        MOV     r0, r9                                  ; We don't care if this went bang
ExitFromOpen
        Pull    pc

        ; ***************************
        ; ***  P U T   B Y T E S  ***
        ; ***************************

PutBytes        ROUT
        TEQ     r0, #1                                  ; Operation must be a write
        TEQNE   r0, #2
        MOVNE   pc, lr
        LDR     wp, [ r12 ]
        MOV     r11, #NIL                               ; So that we can tell it is a PutBytes rather than a Save
        STR     r11, LoadOrSaveAddress
        Push    "r0, r1, lr"
        MOV     r0, #NetFS_StartPutBytes
        MOV     r1, r3
        BL      DoUpCall
        STRVS   r0, [ sp ]
        Pull    "r0, r1, lr"
        MOVVS   pc, lr
        Push    "r0-r4, lr"
        BL      FindFCB
        BLVC    FlushWriteOnly
        STRVS   r0, [ sp ]
        Pull    "r0-r4"
        Pull    pc, VS
        ADR     lr, ReturnFromPutBuffer
        Push    r3
        Push    "r0-r11, lr"
        BL      ClearFSOpFlags
        BL      FindFCB
        Push    r2
        BVS     GetBufferFailed
        ; Success : R2^ is the record and R3^ is the one before it in the list (or so)
        ;         : R4 is the next link
        LDR     r14, [ sp, #4 ]
        TEQ     r14, #2                                 ; Is it write at the current pointer?
        LDREQ   r14, [ r2, #FCB_Pointer ]
        STREQ   r14, [ sp, #20 ]
        B       RearEntryForFlush
ReturnFromPutBuffer
        Pull    r3
        Pull    "pc", VS
        ADD     r2, r2, r3                              ; Set exit vaule for core pointer
        ADD     r4, r4, r3                              ; Set exit value for file pointer
        MOV     r3, #0                                  ; Bytes not transfered
        Push    "r1-r4"
        BL      FindFCB
        MOV     r14, r2
        Pull    "r1-r4"
        STRVC   r4, [ r14, #FCB_Pointer ]
        Pull    pc

        ; *****************************
        ; ***  P U T   B U F F E R  ***
        ; *****************************

PutBuffer       ROUT
        LDR     wp, [ r12 ]
        MOV     r11, #NIL                               ; So that we can tell it is a PutBytes rather than a Save
        STR     r11, LoadOrSaveAddress
        Push    "r0, r1, lr"
        MOV     r0, #NetFS_StartPutBytes
        MOV     r1, r3
        BL      DoUpCall
        STRVS   r0, [ sp ]
        Pull    "r0, r1, lr"
        MOVVS   pc, lr
NastyPutBuffer
        Push    "r0-r11, lr"
        BL      ClearFSOpFlags
        BL      FindFCB
        Push    r2
        BVS     GetBufferFailed
        ; Success : R2^ is the record and R3^ is the one before it in the list (or so)
        ;         : R4 is the next link
        LDRB    r10, [ r2, #FCB_Status ]
        TST     r10, #FCB_Status_WriteOnly
        BNE     PutToWriteOnlyFile
RearEntryForFlush
        LDR     r10, [ sp, #16 ]                        ; Original R3 is the length
        TEQ     r10, #0                                 ; Check the special case
        BEQ     PutBufferSuceeded
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STR     r0, [ r1, #0 ]                          ; Includes writing 0 to CommandBuffer+1 'use given offset'
        LDRB    r0, [ r2, #FCB_Status ]
        AND     r0, r0, #FCB_Status_Sequence
        STRB    r0, FSOpSequenceNumber
        LDR     r0, [ sp, #20 ]                         ; Original R4 ; File pointer
        MOV     r0, r0, LSL #8                          ; Align this 24 bit quantity
        STR     r0, [ r1, #4 ]
        STRB    r10, [ r1, #2 ]                         ; Do this 24 bit quantity the hard way
        MOV     r10, r10, ROR #8                        ; R10 has the size in
        STRB    r10, [ r1, #3 ]
        MOV     r10, r10, ROR #8
        STRB    r10, [ r1, #4 ]
        MOV     r10, r10, ROR #16                       ; Restore R10 to its previous value
        MOV     r2, #8                                  ; Number of bytes to send
        MOV     r0, #FileServer_PutBytes
        BL      DoFSOp
        BVS     PutBufferFailed
        LDR     r9, [ sp, #12 ]                         ; Original R2, the address in core
        LDRB    r11, [ r1, #1 ]                         ; Low byte of block size
        LDRB    r8, [ r1, #2 ]                          ; High byte of block size
        ORR     r8, r11, r8, LSL #8                     ; Join
        LDRB    r11, [ r1, #0 ]                         ; The data port as supplied

        ; R8 = Block size   R9 = Core address
        ; R10= Length       R11= Data port
PutNextBlock
        CMP     r10, r8                                 ; Length with block size
        MOVHI   r5, r8
        MOVLS   r5, r10
        SUB     r10, r10, r5                            ; Length for next time
        MOV     r4, r9                                  ; Core address
        ADD     r9, r9, r5                              ; Calculate next start address
        LDR     r2, [ sp ]
        LDRB    r0, [ r2, #FCB_Status ]
        AND     r0, r0, #FCB_Status_Sequence
        MOV     r1, r11                                 ; Use the supplied data port
        LDR     r2, [ r2, #FCB_Context ]
        ADD     r2, r2, #Context_Station
        LDMIA   r2, { r2, r3 }
        LDR     r6, FSTransmitCount
        LDR     r7, FSTransmitDelay
        SWI     XEconet_DoTransmit
        BVS     PutBufferFailed
        TEQ     r0, #Status_Transmitted
        BEQ     WaitForPutAck
        BL      ConvertStatusToError
PutBufferFailed
        LDR     r14, LoadOrSaveAddress
        TEQ     r14, #NIL                               ; Check for PutBytes used from Save
        BNE     ExitPutBuffer
        MOV     r4, r0                                  ; Save the error
        MOV     r0, #NetFS_FinishPutBytes
        BL      DoUpCall
        MOV     r0, r4
ExitPutBuffer
        STR     r0, [ sp, #4 ] !                        ; Trash FCB address, and store original error
        BL      ReleasePorts                            ; Ignoring errors
        Pull    "r0-r11, lr"
        SETV
        MOV     pc, lr

WaitForPutAck
        TEQ     r10, #0                                 ; Is this the last one ??
        LDREQB  r0, CurrentReplyPort
        LDRNEB  r0, CurrentAuxiliaryPort
        MOV     r1, r3
        MOV     r2, r4
        ADR     r3, CommandBuffer
        MOV     r4, #?CommandBuffer
        SWI     XEconet_CreateReceive
        BLVC    WaitForFSReply
        BVS     PutBufferFailed
        LDR     r1, [ sp, #16 ]
        SUB     r1, r1, r10                             ; How much we have so far
        LDR     r0, LoadOrSaveAddress
        TEQ     r0, #NIL                                ; Check for PutBytes used from Save
        MOVEQ   r0, #NetFS_PartPutBytes
        ADDNE   r1, r1, r0                              ; Add in the offset within a Save
        MOVNE   r0, #NetFS_PartSave
        BL      DoUpCall
        BVS     PutBufferFailed
        TEQ     r10, #0                                 ; Is this the last one ??
        BNE     PutNextBlock
        ADR     r0, CommandBuffer
        BL      ConvertFSError                          ; Check return code
        BVS     PutBufferFailed
GoodBufferPut
        LDRB    r0, CommandBuffer + 3                   ; Low byte of data transfer size
        LDR     r1, CommandBuffer + 4                   ; Top 16 bits of data transfer size
        MOV     r1, r1, LSL #16                         ; Trash the other 16 bits
        ORR     r0, r0, r1, LSR #8                      ; Align and join together
        LDR     r1, [ sp, #16 ]                         ; Requested size
        SUB     r0, r1, r0
        STR     r0, [ sp, #16 ]                         ; Return in R3
        LDR     r2, [ sp ]
        LDRB    r0, [ r2, #FCB_Status ]
        EOR     r0, r0, #FCB_Status_Sequence
        STRB    r0, [ r2, #FCB_Status ]
PutBufferSuceeded
        LDR     r0, LoadOrSaveAddress
        TEQ     r0, #NIL                                ; Check for PutBytes used from Save
        BNE     PutBufferWasSave
        MOV     r0, #NetFS_FinishPutBytes
        BL      DoUpCall
        BVS     PutBufferFailed
PutBufferWasSave
        INC     sp, 4                                   ; Trash FCB address
        BL      ReleasePorts
        STRVS   r0, [ sp ]
        Pull    "r0-r11, pc"

PutToWriteOnlyFile
        ADD     r3, r2, #FCB_Pointer
        LDMIA   r3, { r3, r4, r5 }                      ; Pointer, Buffer, Extent
        LDRB    r0, [ sp, #4 ]
        STRB    r0, [ r4, r5 ]
        INC     r3
        STR     r3, [ r2, #FCB_Pointer ]
        INC     r5
        STR     r5, [ r2, #FCB_BufferExtent ]
        CMP     r5, #WriteOnlySize
        BLEQ    FlushWriteOnly                          ; Record in R2
        BVS     PutBufferFailed
        B       PutBufferSuceeded

FlushWriteOnly
        ; Preserves all registers, except maybe R0, record is in R2
        Push    "r0-r5, lr"
        CLRV
        LDRB    r14, [ r2, #FCB_Status ]
        TST     r14, #FCB_Status_WriteOnly
        Pull    "r0-r5, pc", EQ
        ADR     lr, ReturnFromFlush
        MOV     r5, r2
        LDR     r2, [ r5, #FCB_Buffer ]
        LDR     r3, [ r5, #FCB_BufferExtent ]
        LDR     r4, [ r5, #FCB_BufferBase ]
        Push    "r0-r11, lr"
        MOV     r2, r5
        Push    r5
        B       RearEntryForFlush
ReturnFromFlush
        LDRVC   r1, [ r5, #FCB_BufferBase ]
        LDRVC   r2, [ r5, #FCB_BufferExtent ]
        ADDVC   r1, r1, r2
        MOVVC   r2, #0
        STRVC   r1, [ r5, #FCB_BufferBase ]
        STRVC   r2, [ r5, #FCB_BufferExtent ]
        STRVS   r0, [ sp ]
        Pull    "r0-r5, pc"

        ; *****************************
        ; ***  G E T   B U F F E R  ***
        ; *****************************

GetBuffer       ROUT
        LDR     wp, [ r12 ]
        MOV     r11, #NIL                               ; So that we can tell it is a GetBytes rather than a Load
        STR     r11, LoadOrSaveAddress
        Push    "r0, r1, lr"
        MOV     r0, #NetFS_StartGetBytes
        MOV     r1, r3
        BL      DoUpCall
        STRVS   r0, [ sp ]
        Pull    "r0, r1, lr"
        BVS     FileBadExit
NastyGetBuffer
        Push    "r0-r7, lr"
        BL      ClearFSOpFlags
        BL      FindFCB
        Push    r2
        BVS     GetBufferFailed
        ; Success : R2^ is the record and R3^ is the one before it in the list (or so)
        ;         : R4 is the next link
        LDR     r3, [ sp, #16 ]                         ; Original R3 ; Length
        TEQ     r3, #0                                  ; Check the special case
        BEQ     GetBufferSuceeded
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STR     r0, [ r1, #0 ]                          ; Includes writing 0 to CommandBuffer+1 'use given offset'
        LDRB    r0, [ r2, #FCB_Status ]
        AND     r0, r0, #FCB_Status_Sequence
        STRB    r0, FSOpSequenceNumber
        LDR     r0, [ sp, #20 ]                         ; Original R4 ; File pointer
        MOV     r0, r0, LSL #8                          ; Align this 24 bit quantity
        STR     r0, [ r1, #4 ]
        STRB    r3, [ r1, #2 ]                          ; Do this 24 bit quantity the hard way
        MOV     r3, r3, LSR #8
        STRB    r3, [ r1, #3 ]
        MOV     r3, r3, LSR #8
        STRB    r3, [ r1, #4 ]
        MOV     r2, #8
        MOV     r0, #FileServer_GetBytes
        BL      DoFSOp
        BVS     GetBufferFailed
        ADD     r0, sp, #12
        LDMIA   r0, { r3, r4 }
NextBufferSection
        STR     r4, LoadOrSaveLength                    ; Remaining in this transfer
        LDRB    r0, CurrentAuxiliaryPort
        LDR     r1, Temporary
        ADD     r1, r1, #Context_Station
        LDMIA   r1, { r1, r2 }
        SWI     XEconet_CreateReceive
        BLVC    WaitForFSReply
        BVS     GetBufferFailed
        LDR     r1, LoadOrSaveLength
        SUBS    r4, r1, r6                              ; Calculate remaining data to transfer
        ADD     r3, r5, r6                              ; Calculate next transfer address
        LDR     r1, [ sp, #16 ]
        SUB     r1, r1, r4                              ; How much we have so far
        LDR     r0, LoadOrSaveAddress
        TEQ     r0, #NIL                                ; Check for GetBytes used from Load
        MOVEQ   r0, #NetFS_PartGetBytes
        ADDNE   r1, r1, r0                              ; Add in the offset within a Load
        MOVNE   r0, #NetFS_PartLoad
        BL      DoUpCall
        BVS     GetBufferFailed
        TEQ     r4, #0
        BNE     NextBufferSection

        LDRB    r0, CurrentReplyPort
        LDR     r1, Temporary
        ADD     r1, r1, #Context_Station
        LDMIA   r1, { r1, r2 }
        ADR     r3, CommandBuffer
        MOV     r4, #?CommandBuffer
        SWI     XEconet_CreateReceive
        BLVC    WaitForFSReply
        ADRVC   r0, CommandBuffer                       ; UpdateFromLastReturn
        BLVC    ConvertFSError                          ; Check return code
        BVS     GetBufferFailed
GoodBufferGet
        LDRB    r0, CommandBuffer + 3                   ; Low byte of data transfer size
        LDR     r1, CommandBuffer + 4                   ; Top 16 bits of data transfer size in the bottom of the word
        MOV     r1, r1, LSL #16                         ; Trash the other 16 bits
        ORR     r0, r0, r1, LSR #8                      ; Align and join together
        LDR     r1, [ sp, #16 ]                         ; Requested size
        SUB     r0, r1, r0                              ; Compute bytes NOT read
        STR     r0, [ sp, #16 ]                         ; Return in R3
        LDR     r2, [ sp ]
        LDRB    r0, [ r2, #FCB_Status ]
        EOR     r0, r0, #FCB_Status_Sequence
        STRB    r0, [ r2, #FCB_Status ]
GetBufferSuceeded
        LDR     r0, LoadOrSaveAddress
        TEQ     r0, #NIL                                ; Check for GetBytes used from Load
        BNE     NoUpCallNeeded
        MOV     r0, #NetFS_FinishGetBytes
        BL      DoUpCall
        BVS     ExitGetBuffer
NoUpCallNeeded
        INC     sp, 4                                   ; Trash FCB address
        BL      ReleasePorts
        STRVS   r0, [ sp ]
        Pull    "r0-r7, pc"

GetBufferFailed ; V is set
        LDR     r14, LoadOrSaveAddress
        TEQ     r14, #NIL                               ; Check for GetBytes used from Load
        BNE     ExitGetBuffer
        MOV     r4, r0                                  ; Preserve the error
        MOV     r0, #NetFS_FinishGetBytes
        BL      DoUpCall
        MOV     r0, r4
ExitGetBuffer
        STR     r0, [ sp, #4 ] !                        ; Trash FCB address, and store original error
        BL      ReleasePorts                            ; Ignoring errors
        SETV
        Pull    "r0-r7, pc"

        LTORG

        ; *****************
        ; ***  A R G S  ***
        ; *****************

Args            ROUT
        LDR     wp, [ r12 ]
NastyArgs
        [       Debug
        DREG    r0, "OS_Args &"
        DREG    r1, "Handle = &"
        DREG    r2, "Argument = &"
        ]
        Push    "r1-r5, lr"
        CMP     r0, #ArgsTableSize
        BCC     %10
20
        ADR     r0, ErrorUnknownFunctionCode
        Pull    "r1-r5, lr"
        [       UseMsgTrans
        B       MakeErrorWithModuleName

ErrorUnknownFunctionCode
        DCD     ErrorNumber_UnknownFunctionCode
        DCB     "BadFSOp", 0
        ALIGN
        |       ; UseMsgTrans
        RETURNVS

        Err     UnknownFunctionCode
        ALIGN
        ]       ; UseMsgTrans
10
        BL      ClearFSOpFlags
        MOV     r5, r0, LSL #3                          ; Map function code 0,1,2... to 0,8,16...
        BL      FindFCB                                 ; Also sets the Temporary FS
        Pull    "r1-r5, pc", VS
        [       Debug
        DREG    r2, "FCB found at &"
        ]
        LDRB    r14, [ r2, #FCB_Status ]
        TST     r14, #FCB_Status_WriteOnly              ; Look for a locally buffered file
        ADDNE   r5, r5, #4                              ; WriteOnly Ops are every second one; 4,12,20...
        [       Files24Bit :LAND: Files32Bit
        TST     r14, #FCB_Status_32Bit
        ADDNE   r5, r5, #(ArgsTableSize*8)              ; 32Bit ops are in the second table
        ADD     pc, pc, r5
        NOP
ArgsTableStart
        B       ReadPTR_24                              ; 0
        B       WriteOnlyReadPTR_24                     ; 0
        B       SetPTR_24                               ; 1
        B       WriteOnlySetPTR_24                      ; 1
        B       ReadEXT_24                              ; 2
        B       WriteOnlyReadEXT_24                     ; 2
        B       SetEXT_24                               ; 3
        B       WriteOnlySetEXT_24                      ; 3
        B       ReadSize_24                             ; 4
        B       WriteOnlyReadSize_24                    ; 4
        B       EOFCheck_24                             ; 5
        B       WriteOnlyEOFCheck_24                    ; 5
        B       Flush_24                                ; 6
        B       WriteOnlyFlush_24                       ; 6
        B       EnsureSize_24                           ; 7
        B       WriteOnlyEnsureSize_24                  ; 7
        B       WriteZeroes_24                          ; 8
        B       WriteOnlyWriteZeroes_24                 ; 8
        B       ReadLoadExec_24                         ; 9
        B       WriteOnlyReadLoadExec_24                ; 9
        B       ReadPTR_32                              ; 0
        B       WriteOnlyReadPTR_32                     ; 0
        B       SetPTR_32                               ; 1
        B       WriteOnlySetPTR_32                      ; 1
        B       ReadEXT_32                              ; 2
        B       WriteOnlyReadEXT_32                     ; 2
        B       SetEXT_32                               ; 3
        B       WriteOnlySetEXT_32                      ; 3
        B       ReadSize_32                             ; 4
        B       WriteOnlyReadSize_32                    ; 4
        B       EOFCheck_32                             ; 5
        B       WriteOnlyEOFCheck_32                    ; 5
        B       Flush_32                                ; 6
        B       WriteOnlyFlush_32                       ; 6
        B       EnsureSize_32                           ; 7
        B       WriteOnlyEnsureSize_32                  ; 7
        B       WriteZeroes_32                          ; 8
        B       WriteOnlyWriteZeroes_32                 ; 8
        B       ReadLoadExec_32                         ; 9
        B       WriteOnlyReadLoadExec_32                ; 9

ArgsTableSize * ( ( . - ArgsTableStart ) / 16 )
        |
        ADD     pc, pc, r5
        NOP
ArgsTableStart
        [       Files24Bit
        B       ReadPTR_24                              ; 0
        B       WriteOnlyReadPTR_24                     ; 0
        B       SetPTR_24                               ; 1
        B       WriteOnlySetPTR_24                      ; 1
        B       ReadEXT_24                              ; 2
        B       WriteOnlyReadEXT_24                     ; 2
        B       SetEXT_24                               ; 3
        B       WriteOnlySetEXT_24                      ; 3
        B       ReadSize_24                             ; 4
        B       WriteOnlyReadSize_24                    ; 4
        B       EOFCheck_24                             ; 5
        B       WriteOnlyEOFCheck_24                    ; 5
        B       Flush_24                                ; 6
        B       WriteOnlyFlush_24                       ; 6
        B       EnsureSize_24                           ; 7
        B       WriteOnlyEnsureSize_24                  ; 7
        B       WriteZeroes_24                          ; 8
        B       WriteOnlyWriteZeroes_24                 ; 8
        B       ReadLoadExec_24                         ; 9
        B       WriteOnlyReadLoadExec_24                ; 9
        ]
        [       Files32Bit
        B       ReadPTR_32                              ; 0
        B       WriteOnlyReadPTR_32                     ; 0
        B       SetPTR_32                               ; 1
        B       WriteOnlySetPTR_32                      ; 1
        B       ReadEXT_32                              ; 2
        B       WriteOnlyReadEXT_32                     ; 2
        B       SetEXT_32                               ; 3
        B       WriteOnlySetEXT_32                      ; 3
        B       ReadSize_32                             ; 4
        B       WriteOnlyReadSize_32                    ; 4
        B       EOFCheck_32                             ; 5
        B       WriteOnlyEOFCheck_32                    ; 5
        B       Flush_32                                ; 6
        B       WriteOnlyFlush_32                       ; 6
        B       EnsureSize_32                           ; 7
        B       WriteOnlyEnsureSize_32                  ; 7
        B       WriteZeroes_32                          ; 8
        B       WriteOnlyWriteZeroes_32                 ; 8
        B       ReadLoadExec_32                         ; 9
        B       WriteOnlyReadLoadExec_32                ; 9
        ]
ArgsTableSize * ( ( . - ArgsTableStart ) / 8 )
        ]

        [       Files24Bit
WriteOnlyReadEXT_24
WriteOnlyReadSize_24
        [       Debug
        DLINE   "Args - WriteOnlyReadEXT_24 - WriteOnlyReadSize_24"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        ASSERT  ReadEXT_24 = ReadSize_24
ReadPTR_24
SetPTR_24
ReadEXT_24
ReadSize_24
DoArgs_24
        [       Debug
        DLINE   "Args - ReadPTR_24s - SetPTR_24 - ReadEXT_24 - ReadSize_24 - DoArgs_24"
        ]
        ADRL    r1, CommandBuffer + 2
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOVS    r0, r5, LSR #4                          ; The bottom (R/W) bit of the function code now in Carry
        STRB    r0, [ r1, #1 ]                          ; The argument to the file server
        BCC     ReadArgs_24
        LDR     r0, [ sp, #4 ]                          ; Original R2, the argument
        CMP     r0, #&01000000                          ; Does this exceed the 24 bit limit?
        BHS     ExitArgsTooBig_24
        STR     r0, [ r1, #2 ]                          ; Known to be word aligned
        MOV     r2, #5
        MOV     r0, #FileServer_SetArguments
        B       ArgsFSOp_24

ReadArgs_24
        [       Debug
        DLINE   "Args - ReadArgs_24"
        ]
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
ArgsFSOp_24
        [       Debug
        DLINE   "Args - ArgsFSOp_24"
        ]
        BL      DoFSOp
        LDW     r3, r1, r2, r4                          ; Load the return value
ReturnFromArgs_24
        [       Debug
        DLINE   "Args - ReturnFromArgs_24"
        ]
        ANDVC   r3, r3, #&00FFFFFF                      ; Reduce to 24 bits
        STRVC   r3, [ sp, #4 ]                          ; And return it in R2
        [       Debug
        BVS     %88
        DREG    r3, "Exit value of R2 is &"
88
        ]
        Pull    "r1-r5, pc"

SetEXT_24
        [       Debug
        DLINE   "Args - SetEXT_24"
        ]
        ;       First we read the actual extent from the file server
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #1                                  ; Read extent
        STRB    r0, [ r1, #1 ]
        Push    r2                                      ; Preserve the FCB pointer
        MOV     r2, #2
        MOV     r0, #FileServer_ReadArguments
        BL      DoFSOp
        Pull    r2
        BVS     ReturnFromArgs_24
        LDR     r4, [ r1, #0 ]
        AND     r4, r4, #&00FFFFFF                      ; Reduce to 24 bits
        LDR     r3, [ sp, #4 ]                          ; Original R2, the argument
        SUBS    r1, r3, r4                              ; Compute signed increase in extent
        CLRV
        BEQ     ReturnFromArgs_24
        CMP     r1, #EXT_Threshold                      ; Too big to do as one?
        BLE     DoArgs_24
        MOV     r0, #NetFS_StartCreate
        BL      DoUpCall
SetEXTLoop_24
        MOV     r0, #NetFS_PartCreate
        SUB     r1, r3, r1
        BL      DoUpCall
        ADRL    r1, CommandBuffer + 2                   ; Help the alignment
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #1                                  ; Reason code for Set Extent
        STRB    r0, [ r1, #1 ]                          ; The argument to the file server
        ADD     r4, r4, #EXT_BlockSize
        STR     r4, [ r1, #2 ]                          ; Known to be word aligned
        Push    "r2, r3"
        MOV     r2, #5
        MOV     r0, #FileServer_SetArguments
        BL      DoFSOp
        Pull    "r2, r3"
        BVS     ExitSetEXT_24
        SUB     r1, r3, r4                              ; Compute increase still remaining
        CMP     r1, #EXT_BlockSize                      ; Less than one block?
        BHI     SetEXTLoop_24
        MOV     r0, #NetFS_FinishCreate
        BL      DoUpCall
        TEQ     r1, #0
        BEQ     ReturnFromArgs_24
        MOV     r5, #fsargs_SetEXT :SHL: 3              ; Restore the entry value
        B       DoArgs_24

ExitSetEXT_24
        [       Debug
        DLINE   "Args - ExitSetEXT_24"
        ]
        Push    r0
        MOV     r0, #NetFS_FinishCreate
        BL      DoUpCall
        SETV
        Pull    "r0-r5, pc"

ReadLoadExec_24
WriteOnlyReadLoadExec_24
        [       Debug
        DLINE   "Args - ReadLoadExec_24 - WriteOnlyReadLoadExec_24"
        ]
        MOV     r0, #0                                  ; Bodged for now
        STR     r0, [ sp, #4 ]                          ; The return value for R2
        STR     r0, [ sp, #8 ]                          ; The return value for R3
EOFCheck_24
Flush_24
        [       Debug
        DLINE   "Args - EOFCheck_24 - Flush_24"
        ]
        CLRV
        Pull    "r1-r5, pc"

WriteOnlyWriteZeroes_24
        [       Debug
        DLINE   "Args - WriteOnlyWriteZeroes_24"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
WriteZeroes_24
        [       Debug
        DLINE   "Args - WriteZeroes_24"
        ]
        MOV     r0, #OSArgs_ReadEXT
        LDRB    r1, [ r2, #FCB_TuTuHandle ]
        MOV     r5, r2                                  ; Save the FCB address (but not on stack)
        SWI     XOS_Args
        Pull    "r1-r5, pc", VS
        LDMIB   sp, {r3,r4}                             ; Get file offset and number of zeroes to write
        [       Debug
        DREG    r2, "Current extent = &"
        DREG    r3, "File offset = &"
        DREG    r4, "Zero count = &"
        ]
        ADD     lr, r3, r4
        CMP     lr, r2                                  ; If new extent < current extent then
        Pull    "r1-r5, pc", CC                         ;   we can't write zeroes by extending the file so abort

        LDMIA   sp, {r1-r4}                             ; Restore parameters
        STR     lr, [ sp, #4 ]                          ; Set up new extent for ContinueWriteZeroes_24
        Push    r5                                      ; Save the FCB address on the stack
        MOV     r5, #fsargs_SetEXT :SHL: 3              ; Fake the entry value
        ADR     lr, ContinueWriteZeroes_24
        Push    "r1-r5, lr"                             ; Set up the stack
        LDR     r2, [ sp, #24 ]                         ; Restore the FCB address
        B       SetEXT_24

ContinueWriteZeroes_24
        Pull    r2                                      ; Restore the FCB address
        MOV     r5, #fsargs_SetEXT :SHL: 3              ; Fake the entry value
        STR     r5, [ sp, #16 ]
        B       SetEXT_24

WriteOnlyEnsureSize_24
        [       Debug
        DLINE   "Args - WriteOnlyEnsureSize_24"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
EnsureSize_24
        [       Debug
        DLINE   "Args - EnsureSize_24"
        ]
        Push    r2                                      ; Save the FCB address
        LDR     r2, [ sp, #8 ]                          ; Restore the entry R2
        MOV     r5, #fsargs_SetEXT :SHL: 3              ; Fake the entry value
        ADR     lr, ContinueEnsureSize_24
        Push    "r1-r5, lr"                             ; Set-up the stack
        LDR     r2, [ sp, #24 ]                         ; Restore FCB address
        B       SetEXT_24

ContinueEnsureSize_24
        Pull    r2                                      ; Restore FCB address
        Pull    "r1-r5, pc", VS
        MOV     r5, #fsargs_ReadSize :SHL: 3            ; Fake the entry value
        B       ReadSize_24

WriteOnlyReadPTR_24
        [       Debug
        DLINE   "Args - WriteOnlyReadPTR_24"
        ]
        LDR     r3, [ r2, #FCB_Pointer ]
        B       ReturnFromArgs_24

WriteOnlySetPTR_24
        [       Debug
        DLINE   "Args - WriteOnlySetPTR_24"
        ]
        LDR     r3, [ sp, #4 ]                          ; The new pointer value
        LDR     r4, [ r2, #FCB_BufferExtent ]
        TEQ     r4, #0                                  ; If the extent is zero then it is an easy case
        BEQ     SetWriteOnlyBase_24
        LDR     r0, [ r2, #FCB_BufferBase ]
        CMP     r3, r0
        BLT     PointerGoingUnderBuffer_24
        ADD     r0, r0, r4                              ; PTR# value for the end of the buffer
        CMP     r3, r0
        BLE     SetWriteOnlyPointer_24
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        STR     r3, [ r2, #FCB_Pointer ]
        STR     r3, [ r2, #FCB_BufferBase ]
        B       SetPTR_24

PointerGoingUnderBuffer_24
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
SetWriteOnlyBase_24
        STR     r3, [ r2, #FCB_BufferBase ]
SetWriteOnlyPointer_24
        STR     r3, [ r2, #FCB_Pointer ]
        B       ReturnFromArgs_24

WriteOnlySetEXT_24
        [       Debug
        DLINE   "Args - WriteOnlySetEXT_24"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        LDR     r14, [ sp, #4 ]
        LDR     r4, [ r2, #FCB_Pointer ]
        CMP     r4, r14
        STRGT   r14, [ r2, #FCB_Pointer ]
        STRGT   r14, [ r2, #FCB_BufferBase ]
        B       SetEXT_24

WriteOnlyEOFCheck_24
WriteOnlyFlush_24
        [       Debug
        DLINE   "Args - WriteOnlyEOFCheck_24 - WriteOnlyFlush_24"
        ]
        BL      FlushWriteOnly
        B       ReturnFromArgs_24

ExitArgsTooBig_24
        Pull    "r1-r5, lr"
        ADR     r0, ErrorFileServerOnly24Bit
        [       UseMsgTrans
        B       MakeError

ErrorFileServerOnly24Bit
        DCD     ErrorNumber_FileServerOnly24Bit
        DCB     "FS24Bit", 0
        ALIGN
        |
        RETURNVS

        Err     FileServerOnly24Bit
        ]
        ]



        [       Files32Bit
ReadPTR_32
        [       Debug
        DLINE   "Args - ReadPTR_32"
        ]
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #0
        STRB    r0, [ r1, #1 ]
        MOV     r0, #FileServer_ReadRandomAccessInfoExtended
        MOV     r2, #2
        BL      DoFSOp
        LDRVC   r2, CommandBuffer
ExitFromSimpleRead
        STRVC   r2, [ sp, #4 ]                          ; And return it in R2
        [       Debug
        BVS     %81
        DREG    r2, "Exit value of R2 is &"
81
        ]
        Pull    "r1-r5, pc"

WriteOnlyReadPTR_32
        [       Debug
        DLINE   "Args - WriteOnlyReadPTR_32"
        ]
        LDR     r2, [ r2, #FCB_Pointer ]
        B       ExitFromSimpleRead

SetPTR_32
        [       Debug
        DLINE   "Args - SetPTR_32"
        ]
        ADRL    r1, CommandBuffer + 2
        LDRB    r0, [ r2, #FCB_Channel ]
        [       Debug
        DREG    r2, "FCB is at &"
        BREG    r0, "FS handle is &"
        ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #0
        STRB    r0, [ r1, #1 ]
        LDR     r0, [ sp, #4 ]                          ; Original R2, the argument
        STR     r0, [ r1, #2 ]
        MOV     r0, #FileServer_SetRandomAccessInfoExtended
        MOV     r2, #6
        BL      DoFSOp
        Pull    "r1-r5, pc"

WriteOnlySetPTR_32
        [       Debug
        DLINE   "Args - WriteOnlySetPTR_32"
        ]
        LDR     r3, [ sp, #4 ]                          ; The new pointer value
        LDR     r4, [ r2, #FCB_BufferExtent ]
        TEQ     r4, #0                                  ; If the extent is zero then it is an easy case
        BEQ     SetWriteOnlyBase_32
        LDR     r0, [ r2, #FCB_BufferBase ]
        CMP     r3, r0
        ! 1, "Can't use a signed compare on a 32 bit PTR"
        BLT     PointerGoingUnderBuffer_32
        ADD     r0, r0, r4                              ; PTR# value for the end of the buffer
        CMP     r3, r0
        BLE     SetWriteOnlyPointer_32
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        STR     r3, [ r2, #FCB_Pointer ]
        STR     r3, [ r2, #FCB_BufferBase ]
        B       SetPTR_32

PointerGoingUnderBuffer_32
        [       Debug
        DLINE   "Args - PointerGoingUnderBuffer_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
SetWriteOnlyBase_32
        STR     r3, [ r2, #FCB_BufferBase ]
SetWriteOnlyPointer_32
        STR     r3, [ r2, #FCB_Pointer ]
        Pull    "r1-r5, pc"

ReadEXT_32
WriteOnlyReadEXT_32
        [       Debug
        DLINE   "Args - ReadEXT_32 - WriteOnlyReadEXT_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #0
        STRB    r0, [ r1, #1 ]
        MOV     r0, #FileServer_ReadRandomAccessInfoExtended
        MOV     r2, #2
        BL      DoFSOp
        LDRVC   r2, CommandBuffer + 4
        B       ExitFromSimpleRead

SetEXT_32
        [       Debug
        DLINE   "Args - SetEXT_32"
        ]
        ADRL    r1, CommandBuffer + 2
        LDRB    r0, [ r2, #FCB_Channel ]
        [       Debug
        DREG    r2, "FCB is at &"
        BREG    r0, "FS handle is &"
        ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #1
        STRB    r0, [ r1, #1 ]
        LDR     r0, [ sp, #4 ]                          ; Original R2, the argument
        STR     r0, [ r1, #2 ]
        MOV     r0, #FileServer_SetRandomAccessInfoExtended
        MOV     r2, #6
        BL      DoFSOp
        Pull    "r1-r5, pc"

WriteOnlySetEXT_32
        [       Debug
        DLINE   "Args - WriteOnlySetEXT_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        LDR     r14, [ sp, #4 ]
        LDR     r4, [ r2, #FCB_Pointer ]
        CMP     r4, r14
        ! 1, "Can't use a signed compare on a 32 bit EXT"
        STRGT   r14, [ r2, #FCB_Pointer ]
        STRGT   r14, [ r2, #FCB_BufferBase ]
        B       SetEXT_32

ReadSize_32
WriteOnlyReadSize_32
        [       Debug
        DLINE   "Args - ReadSize_32 - WriteOnlyReadSize_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #0
        STRB    r0, [ r1, #1 ]
        MOV     r0, #FileServer_ReadRandomAccessInfoExtended
        MOV     r2, #2
        BL      DoFSOp
        LDRVC   r2, CommandBuffer + 8
        B       ExitFromSimpleRead

EOFCheck_32
WriteOnlyEOFCheck_32
        [       Debug
        DLINE   "Args - EOFCheck_32 - WriteOnlyEOFCheck_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc"

Flush_32
WriteOnlyFlush_32
        [       Debug
        DLINE   "Args - Flush_32 - WriteOnlyFlush_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc"

EnsureSize_32
        [       Debug
        DLINE   "Args - EnsureSize_32"
        ]
        Push    r2                                      ; Save the FCB address
        LDR     r2, [ sp, #8 ]                          ; Restore the entry R2
        ADR     lr, ContinueEnsureSize_32
        Push    "r1-r5, lr"                             ; Set-up the stack
        LDR     r2, [ sp, #4*6 ]                        ; Restore FCB address
        B       SetEXT_32

ContinueEnsureSize_32
        [       Debug
        DLINE   "Args - ContinueEnsureSize_32"
        ]
        Pull    r2                                      ; Restore FCB address
        Pull    "r1-r5, pc", VS
        B       ReadSize_32

WriteOnlyEnsureSize_32
        [       Debug
        DLINE   "Args - WriteOnlyEnsureSize_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
        B       EnsureSize_32

WriteOnlyWriteZeroes_32
        [       Debug
        DLINE   "Args - WriteOnlyWriteZeroes_32"
        ]
        BL      FlushWriteOnly
        Pull    "r1-r5, pc", VS
WriteZeroes_32
        [       Debug
        DLINE   "Args - WriteZeroes_32"
        ]
        MOV     r0, #OSArgs_ReadEXT
        LDRB    r1, [ r2, #FCB_TuTuHandle ]
        MOV     r5, r2                                  ; Save the FCB address (but not on stack)
        SWI     XOS_Args
        Pull    "r1-r5, pc", VS
        LDMIB   sp, {r3,r4}                             ; Get file offset and number of zeroes to write
        ADD     lr, r3, r4
        CMP     lr, r2                                  ; If new extent < current extent then
        Pull    "r1-r5, pc", CC                         ;   we can't write zeroes by extending the file so abort

        LDMIA   sp, {r1-r4}                             ; Restore parameters
        STR     lr, [ sp, #4 ]                          ; Set new file extent for ContinueWriteZeroes_32
        Push    r5                                      ; Save the FCB address on the stack
        ADR     lr, ContinueWriteZeroes_32
        Push    "r1-r5, lr"                             ; Set up the stack
        LDR     r2, [ sp, #24 ]                         ; Restore the FCB address
        B       SetEXT_32

ContinueWriteZeroes_32
        Pull    r2                                      ; Restore the FCB address
        B       SetEXT_32

ReadLoadExec_32
WriteOnlyReadLoadExec_32
        [       Debug
        DLINE   "Args - ReadLoadExec_32 - WriteOnlyReadLoadExec_32"
        ]
        ADR     r1, CommandBuffer
        LDRB    r0, [ r2, #FCB_Channel ]
        STRB    r0, [ r1, #0 ]
        MOV     r0, #0
        STRB    r0, [ r1, #1 ]
        MOV     r0, #FileServer_ReadRandomAccessInfoExtended
        MOV     r2, #2
        BL      DoFSOp
        ADR     r1, CommandBuffer + 12
        LDMVCIA r1, { r2, r3 }
        ADD     r1, sp, #4
        STMVCIA r1, { r2, r3 }
        [       Debug
        BVS     %82
        DREG    r2, "Exit value of R2 is &"
        DREG    r3, "Exit value of R3 is &"
82
        ]
        Pull    "r1-r5, pc"
        ]


        ; *******************
        ; ***  C L O S E  ***
        ; *******************

Close           ROUT
        ;       R1 ==> Handle to close
        ;       R2 ==> New LOAD address } Date stamp
        ;       R3 ==> New EXEC address }
        LDR     wp, [ r12 ]
NastyClose                                              ; FCB_Handle in R1
        Push    "r0-r5, lr"
        [       Debug
        DREG    r1, "OS_Find_Close &"
        ]
        BL      ClearFSOpFlags
        MOV     r5, #0                                  ; Set the "No error" flag
        BL      FindFCB                                 ; Sets the temporary FS number
        MOVVS   r5, r0                                  ; Store the error if there was one
        BVS     ExitClose
        ; Success : R2^ is the record and R3^ is the one before it in the list (or so)
        ;         : R4 is the next link
        STR     r4, [ r3, #FCB_Link ]                   ; Unlink
        MOV     r4, r2                                  ; Hold the FCB pointer in R4
        LDRB    r14, [ r4, #FCB_Status ]
        TST     r14, #FCB_Status_WriteOnly              ; Is it WriteOnly?
        BEQ     NoNeedToFlush                           ; No, so no data held by me
        BL      FlushWriteOnly
        MOVVS   r5, r0                                  ; Store the error if there was one
        LDR     r2, [ r4, #FCB_Buffer ]
        BL      MyFreeRMA
        MOVVS   r5, r0                                  ; Store the error if there was one
NoNeedToFlush
        [       Files32Bit
        [       Files24Bit
        LDRB    r14, [ r4, #FCB_Status ]
        TST     r14, #FCB_Status_32Bit
        BEQ     NoUpdateToDateStamp
        ]
        [       Debug
        DLINE   "Close - Setting date stamp"
        ]
        ADR     r1, CommandBuffer                       ; We are actually going to use CommandBuffer + 2
        MOV     r0, #&02000000                          ; Reason code 2
        LDRB    r14, [ r4, #FCB_Channel ]
        ORR     r0, r0, r14, LSL#16                     ; Now &02cc0000
        ADD     r14, sp, #8                             ; Original R2 and R3, the LOAD & EXEC arguments
        LDMIA   r14, { r2, r3 }
        STMIA   r1, { r0, r2, r3 }
        ADD     r1, r1, #2                             ; Point to CommandBuffer + 2
        MOV     r0, #FileServer_SetRandomAccessInfoExtended
        MOV     r2, #10
        BL      DoFSOp
        MOVVS   r5, r0                                  ; Store the error if there was one
NoUpdateToDateStamp
        ]
        MOV     r2, r4                                  ; FCB pointer
        LDRB    r4, [ r2, #FCB_Channel ]                ; Handle that needs closing
        [       Debug
        BREG    r4, "Trying to close file server handle &"
        ]
        BL      MyFreeRMA
        MOVVS   r5, r0                                  ; Store the error if there was one
        LDR     r1, Temporary                           ; Get the Context we have just closed on
        LDR     r2, FCBs                                ; The start of the chain
        MOV     r3, #0                                  ; Handle that will actually get closed
        B       %30

10
        LDR     r0, [ r2, #FCB_Context ]
        TEQ     r0, r1                                  ; Is this FCB on the same Context?
        BNE     %20                                     ; This record not our FS so try next record
        LDRB    r0, [ r2, #FCB_Status ]
        TST     r0, #FCB_Status_Directory               ; Is this a directory?
        MOVEQ   r3, r4                                  ; No, not a directory, an open file on our FS, so no CLOSE#0
        BEQ     DoClose                                 ; Go and do the close immediately
20
        LDR     r2, [ r2, #FCB_Link ]
30
        TEQ     r2, #NIL
        BNE     %10                                     ; Not at the end of the list yet
DoClose
        ADR     r1, CommandBuffer                       ; Drop through ==> no open files found so do a CLOSE#0
        STRB    r3, [ r1, #0 ]                          ; Either zero or the handle
        MOV     r2, #1
        MOV     r0, #FileServer_Close
        [       Debug
        BREG    r3, "Actually doing a CLOSE#&"
        ]
        BL      DoFSOp
        MOVVS   r5, r0                                  ; Store the error if there was one
ExitClose
        MOVS    r0, r5                                  ; Get the last error back, zero ==> "No error"
        SETV    NE                                      ; There was an error
        STRVS   r0, [ sp ]
        Pull    "r0-r5, pc"

        LTORG

FindFCB         ROUT
        ;       R1 => Handle of FCB to find
        ;       R2 <= Pointer to the FCB that matches the handle
        ;       R3 <= Pointer to the previous FCB in the list, for possible FCB removal
        ;       R4 <= Pointer to the next FCB in the list, for possible FCB removal
        ;       Trashes R0
        ADR     r3, FCBs - FCB_Link
        LDR     r4, FCBs                                 ; Special for the first case
        B       %20

FindFCBLoop
        MOV     r2, r4                                  ; The next link value
        LDR     r4, [ r2, #FCB_Link ]
        LDR     r0, [ r2, #FCB_Handle ]
        TEQ     r0, r1
        BEQ     FCBFound
        MOV     r3, r2                                  ; Hold on to previous value
20
        TEQ     r4, #NIL
        BNE     FindFCBLoop                             ; Not at the end of the list yet
        ADR     r0, ErrorBadNetFSHandle
        [       UseMsgTrans
        B       MakeError

ErrorBadNetFSHandle
        DCD     ErrorNumber_BadNetFSHandle
        DCB     "Channel", 0
        ALIGN
        |       ; UseMsgTrans
        RETURNVS

        Err     BadNetFSHandle
        ALIGN
        ]       ; UseMsgTrans

FCBFound
        Push    lr
        LDR     r0, [ r2, #FCB_Context ]
        BL      ValidateContext
        STRVC   r0, Temporary
        Pull    pc

        END
