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
        SUBT => &.Arthur.NetFS.Functions

        ; *******************
        ; ***  F U N C T  ***
        ; *******************

        [       OldOs
Funct           ROUT
        LDR     wp, [ r12 ]
        [       Debug ; False
        DREG    r0, "FSFunct - Arg = &"
        ]
        CMP     r0, #FunctionTableSize
        BICGTS  pc, lr, #VFlag                          ; Nop unknown operations
        Push    lr
        TEQ     r0, #fsfunc_Bootup                      ; Skip for functions with no R6
        TEQNE   r0, #fsfunc_ShutDown
        TEQNE   r0, #fsfunc_PrintBanner
        BEQ     DoFunction                              ; Any of these? Skip using R6
        BL      UseNameToSetTemporary
        Pull    pc, VS
        BL      ClearFSOpFlags
DoFunction
        ADD     pc, pc, r0, LSL #2
        NOP
FunctionTableStart
        B       DoStarDir
        B       DoStarLib
        B       Catalog
        B       Examine
        B       CatalogLibrary
        B       ExamineLibrary
        B       DoMultipleFileInfo                      ; *Info
        B       DoStarOpt
        B       DoStarRename
        B       DoStarAccess
        B       CauseBootAction
        B       ReadDiscName
        B       ReadDirectoryName
        B       ReadLibraryName
        B       EnumerateObjectNames
        B       EnumerateObjectInfo
        B       ShutDown
        B       PrintBanner
        Pull pc                                         ; B SetDirectoryContexts
        B       EnumerateObjectsForCatalog
        B       DoSingleFileInfo                        ; *FileInfo

FunctionTableSize * ( ( . - FunctionTableStart ) / 4 ) - 1

        |       ; OldOs

Funct   ROUT
        LDR     wp, [ r12 ]
        [       Debug ; False
        DREG    r0, "FSFunct - Arg = &"
        ]
        Push    lr
        BL      ClearFSOpFlags
        TEQ     r0, #fsfunc_CanonicaliseSpecialAndDisc
        BEQ     CanonicaliseSpecialAndDisc
        TEQ     r0, #fsfunc_ReadDirEntriesInfo
        BEQ     EnumerateObjectInfo
        TEQ     r0, #fsfunc_ReadDirEntries
        BEQ     EnumerateObjectNames
        TEQ     r0, #fsfunc_Access
        BEQ     DoStarAccess
        TEQ     r0, #fsfunc_ResolveWildcard
        BEQ     ResolveWildcard
        TEQ     r0, #fsfunc_Rename
        BEQ     DoStarRename
        TEQ     r0, #fsfunc_Cat
        BEQ     Catalog
        TEQ     r0, #fsfunc_Ex
        BEQ     Examine
        TEQ     r0, #fsfunc_ReadBootOption
        BEQ     ReadBootOption
        TEQ     r0, #fsfunc_CatalogObjects
        BEQ     EnumerateObjectsForCatalog
        TEQ     r0, #fsfunc_Opt
        BEQ     DoStarOpt
        TEQ     r0, #fsfunc_Bootup
        BEQ     CauseBootAction
        TEQ     r0, #fsfunc_ShutDown
        BEQ     ShutDown
        TEQ     r0, #fsfunc_PrintBanner
        BEQ     PrintBanner
        TEQ     r0, #fsfunc_WriteBootOption
        BEQ     WriteBootOption
        TEQ     r0, #fsfunc_DirIs
        BEQ     DirectoryIsNow
        TEQ     r0, #fsfunc_FileInfo
        BEQ     DoSingleFileInfo
        CLRV
        Pull    pc
        ]

        LTORG

        [       OldOs
ReadDiscName ROUT
        Push    "r1, r3"
        LDR     r14, Current
        ADD     r1, r14, #Context_DiscName
        MOV     r0, #0
10
        LDRB    r3, [ r1, r0 ]
        INC     r0
        CMP     r3, #" "
        STRGTB  r3, [ r2, r0 ]
        BGT     %10
        LDRB    r3, [ r14, #Context_BootOption ]
        STRB    r3, [ r2, r0 ]
        DEC     r0
        STRB    r0, [ r2 ]
        Pull    "r1, r3, pc"

ReadLibraryName
        BL      SetFSOpLIBFlag
        ; Note Drop through

ReadDirectoryName
        Push    "r1-r3"
        MOV     r0, #6                                  ; Argument
        STRB    r0, [ r2, #0 ]
        MOV     r0, #13                                 ; Data
        STRB    r0, [ r2, #1 ]
        MOV     r0, #FileServer_ReadObjectInfo
        MOV     r1, r2                                  ; Destination
        MOV     r2, #2                                  ; Bytes to send
        MOV     r3, #15
        BL      DoFSOp
        Pull    "r1-r3, pc", VS
20
        LDRB    r0, [ r1, #1 ]
        STRB    r0, [ r1 ], #1
        DECS    r3
        BPL     %20
        Pull    "r1-r3, pc"
        ]

        [       Files24Bit :LAND: Files32Bit
        !       0, "There is no enumeration code for a 24/32 bit version"
        |       ; Files24Bit :LAND: Files32Bit
        [       Files24Bit
EnumerateObjectNames ROUT
        MOV     r9, #2
        MOV     r8, #11
        CMP     r3, #64                                 ; Arbitrary
        MOVGT   r3, #64
        B       StandardEnumeration

EnumerateObjectInfo
        MOV     r9, #0
        MOV     r8, #27
        CMP     r3, #32
        MOVGT   r3, #32
        B       StandardEnumeration

EnumerateObjectsForCatalog
        MOV     r9, #0
        MOV     r8, #27
        CMP     r3, #32
        MOVGT   r3, #32

StandardEnumeration
        [       Debug
        DLINE   "Entry to an enumeration"
        DREG    r0, "Function code (R0) = &", cc
        DREG    r1, "  Address of directory name (R1) = &"
        DSTRING r1, "Value of directory name "
        DREG    r6, "Special field of the name (R6) is at &", cc
        DSTRING r6, " and is "
        DREG    r2, "Buffer (R2) = &", cc
        DREG    r5, " and is (R5) &", cc
        DLINE   " bytes long"
        DREG    r3, "Number of names to get (R3) = &", cc
        DREG    r4, "  Start with name number &"
        DREG    r7, "R7  = &", cc
        DREG    r8, "   R8  = &", cc
        DREG    r9, "   R9  = &"
        DREG    r10, "R10 = &", cc
        DREG    r11, "   R11 = &", cc
        DREG    r12, "   WP  = &"
        DREG    r13, "SP  = &", cc
        DREG    r14, "   LR  = &", cc
        DREG    r15, "   PC/PSR = &"
        ]       ; Debug
        ;       Entered with lr on stack
        ;       R0 => Function code
        ;       R1 => Directory name
        ;       R2 => Pointer to core
        ;       R3 => Number of object names required (after limiting)
        ;       R4 => Entry number in directory to start at (0...)
        ;       R5 => Buffer length
        ;       R6 => Special field (will be zero)
        ;       R8 => Size of record returned by FS
        ;       R9 => Argument to function examine
        ;       R3 <= Number of objects read
        ;       R4 <= Next entry in the directory
        ;       R5 <= Amount of the buffer used
        [       :LNOT: OldOs
        Push    "r0-r5"                                 ; Must preserve the entry value of R1
        BL      UseNameToSetTemporary                   ; Not the returned normalised value
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r5, pc", VS
        B       DoEnumerate

        ]       ; OldOS

Enumerate
        Push    lr
EnumerateEntry                                          ; Called from the cataloging routines
        Push    "r0-r5"
DoEnumerate
        MOV     r7, r1                                  ; Keep the pointer to the name
        [       :LNOT: OldOs
        CMP     r4, #0                                  ; Is this the first time?
        BLEQ    CacheDirectoryName                      ; Trashes R0, R1, R2, R4, R5
        BVS     %99
        ]       ; OldOS
        MUL     r4, r8, r3                              ; Size calculated
        INC     r4, 5                                   ; One byte spare
        MOV     r3, r4                                  ; Copy into right register for Claim, preserving R4 for Create
        BL      MyClaimRMA
        BVS     %99
        Push    r2                                      ; Address of the block, for the exit code
        MOV     r3, r2
        SWI     XEconet_AllocatePort
        BVS     ExitFromEnumerate
        MOV     r11, r0                                 ; Save port
        LDR     r6, Temporary
        ADD     r14, r6, #Context_Station
        LDMIA   r14, { r1, r2 }
        SWI     XEconet_CreateReceive
        BVS     ExitFromEnumerate
        MOV     r10, r0                                 ; The RxHandle
        ADR     r1, CommandBuffer
        STRB    r11, [ r1, #0 ]                         ; Put reply port in 'TxHeader'
        MOV     r0, #FileServer_Examine
        STRB    r0, [ r1, #1 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_RootDirectory ]
        STRB    r0, [ r1, #2 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_Library ]
        STRB    r0, [ r1, #4 ]                          ; Put in 'TxHeader'
        STRB    r9, [ r1, #5 ]                          ; Argument
        LDR     r0, [ sp, #20 ]                         ; Entry point
        STRB    r0, [ r1, #6 ]
        LDR     r0, [ sp, #16 ]                         ; Number
        STRB    r0, [ r1, #7 ]
        MOV     r0, r7                                  ; Directory name
        MOV     r2, #8
        BL      CopyPathNameInDoingTranslation
        LD      r3, FSOpHandleFlags
        [       Debug
        AND     r14, r3, #URDSlotMask
     ;  ASR     r14, URDSlotShift
        BREG    r14, "URD = &", cc
        AND     r14, r3, #CSDSlotMask
        myASR   r14, CSDSlotShift
        BREG    r14, "  CSD = &", cc
        AND     r14, r3, #LIBSlotMask
        myASR   r14, LIBSlotShift
        BREG    r14, "  LIB = &"
        ]       ; Debug
        AND     r3, r3, #CSDSlotMask
        ADD     r0, r6, #Context_RootDirectory
        LDRB    r0, [ r0, r3, LSR #CSDSlotShift ]
        STRB    r0, [ r1, #3 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_Domain ]
        MOV     r5, r2                                  ; Length
        MOV     r4, r1                                  ; Buffer
        ADD     r14, r6, #Context_Station
        LDMIA   r14, { r2, r3 }
        MOV     r1, #Port_FileServerCommand
        LD      r7, FSTransmitDelay
        LD      r6, FSTransmitCount
        SWI     XEconet_DoTransmit
        BVS     ExitFromEnumerate
        MOV     r5, r0                                  ; Return status
        TEQ     r5, #Status_Transmitted
        MOV     r0, r10
        BEQ     WaitForReplies
        SWI     XEconet_AbandonReceive
        BVS     ExitFromEnumerate
        MOV     r0, r5
45
        BL      ConvertStatusToError
        B       ExitFromEnumerate

        LTORG

WaitForReplies
        LD      r1, FSReceiveDelay
        MOV     r2, pc                                  ; Non-zero => ESCapable
        SWI     XEconet_WaitForReception
        BVS     ExitFromEnumerate
        TEQ     r0, #Status_Received
        BNE     %45
        MOV     r0, r5
        BL      ConvertFSError
        BVS     ExitFromEnumerate
        ADD     r1, r5, #4
        LDR     r2, [ sp, #12 ]                         ; User buffer
        LDR     r7, [ sp, #24 ]                         ; User's buffer size
        LDRB    r8, [ r1, #-2 ]                         ; Number of entries returned
        ;       Exit with the following :
        ;       R3 <= Number of objects read
        ;       R4 <= Next entry in the directory
        ;       R5 <= Amount of the buffer used
        MOV     r3, #0
        TEQ     r8, #0                                  ; Exit with special conditions for FileSwitch
        MOVEQ   r4, #-1                                 ; R3=0, R4=-1
        BEQ     ExitLoop
        LDR     r4, [ sp, #20 ]
        MOV     r5, #0
        TEQ     r9, #2                                  ; Just names or info as well
        ADDNE   r7, r2, r7                              ; Calculate the end of the user's buffer
        BNE     CopyOverInfo
EnumerateNamesLoop
        DECS    r8                                      ; Number of entries sent
        BMI     ExitLoop
        INC     r1                                      ; Step over the length field
60
        TEQ     r5, r7                                  ; Are we at the end of the users buffer
        BEQ     ExitLoop
        LDRB    r0, [ r1 ], #1
        TEQ     r0, #&80
        MOVEQ   r0, #0                                  ; Get special case at the end
        CMP     r0, #" "
        MOVLE   r0, #0                                  ; Terminate
        STRB    r0, [ r2, r5 ]
        INC     r5
        BGT     %60                                     ; Not at end of name yet
        DEC     r1, 2                                   ; Step back in amazement
65
        LDRB    r0, [ r1, #1 ] !
        TEQ     r0, #" "                                ; Find next record
        BEQ     %65
        INC     r3                                      ; Number done
        INC     r4                                      ; Next entry in directory
        B       EnumerateNamesLoop

CopyOverInfo
        ; The info is returned from the file server in 27=&1B byte records
        ; 00 Byte 10 ; Object name, padded with spaces
        ; 0A Word    ; Load address
        ; 0E Word    ; Execute address
        ; 12 Byte    ; Type and access
        ; 13 Bytes 2 ; Date in FS format
        ; 15 Bytes 3 ; SIN
        ; 18 Bytes 3 ; Length
        ; 1B Next object
        ; ========================================
        ; The value at [ SP, #4 ] is the original reason code, this is the
        ; only difference between the two cases (info and catalog data).
        ; ========================================
        ; The info is returned to the user as follows
        ;    ALIGN
        ; 00 Word    ; Load address
        ; 04 Word    ; Execute address
        ; 08 Word    ; Length
        ; 0C Word    ; Attributes (as per XOS_File R5)
        ; 10 Word    ; Type (as per XOS_File R0)
        ; 14 Byte ?? ; Object name
        ; xx Byte    ; Terminating zero
        ; ========================================
        ; The catalog data is returned to the user as follows
        ;    ALIGN
        ; 00 Word    ; Load address
        ; 04 Word    ; Execute address
        ; 08 Word    ; Length
        ; 0C Word    ; Attributes (as per XOS_File R5)
        ; 10 Word    ; Type (as per XOS_File R0)
        ; 14 Word    ; S.I.N.
        ; 18 Bytes 5 ; Date
        ; 1D Byte ?? ; Object name
        ; xx Byte    ; Terminating zero
        ; ========================================
        DECS    r8                                      ; Number of entries sent
        BMI     ExitInfoLoop
        INC     r2, 3
        BIC     r2, r2, #2_11                           ; Align pointer
        SUB     r0, r7, r2                              ; Are we near the end of the users buffer
        CMP     r0, #&28                                ; The minimum required is &28 bytes
        BGE     %70
        LDR     r14, [ sp, #4 ]
        TEQ     r14, #fsfunc_ReadDirEntriesInfo         ; Function code for ReadObjectInfo
        BNE     ExitInfoLoop
        CMP     r0, #&1F                                ; The minimum required is &1F bytes
        BLT     ExitInfoLoop
70
        ADD     r14, r1, #&0A                           ; Address of load address
        LDW     r0, r14, r10, r11
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&0E                           ; Address of execute address
        LDW     r0, r14, r10, r11
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&18                           ; Address of the length
        LDW     r0, r14, r10, r11
        AND     r0, r0, #&00FFFFFF
        STR     r0, [ r2 ], #4
        MOV     r0, r1
        LDRB    r1, [ r0, #&12 ]                        ; FS format protection
        BL      ConvertProtectionFromFS                 ; In R5
        MOV     r1, r0
        LDRB    r0, [ r1, #&13 ]
        ORR     r5, r5, r0, LSL #8
        LDRB    r0, [ r1, #&14 ]
        ORR     r5, r5, r0, LSL #16
        STR     r5, [ r2 ], #4                          ; Attributes
        LDRB    r0, [ r1, #&12 ]
        ANDS    r0, r0, #BitFive
        MOVEQ   r0, #1
        MOVNE   r0, #2
        STR     r0, [ r2 ], #4                          ; Type 1=File 2=Dir
        STRB    r0, [ r1, #10 ]                         ; Terminate the returned name
        LDR     r14, [ sp, #4 ]
        TEQ     r14, #fsfunc_ReadDirEntriesInfo         ; Function code for ReadObjectInfo
        BEQ     %75                                     ; Skip SIN, and Date
        ADD     r14, r1, #&15                           ; Address of the S.I.N.
        LDW     r0, r14, r10, r11
        AND     r0, r0, #&00FFFFFF
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&13                           ; Address of the File server format date
        LDW     r0, r14, r10, r11
        BL      ConvertFileServerDate                   ; From R0 into R10 and R11b
        BVS     ExitFromEnumerate
        STMIA   r2, { r10, r11 }                        ; Stores 8 bytes of which only 5 are valid
        INC     r2, 5
75
        ADD     r14, r1, #0                             ; Start of the name
80
        LDRB    r0, [ r14 ], #1
        CMP     r0, #" "
        MOVLE   r0, #0                                  ; Terminate
        STRB    r0, [ r2 ], #1
        BLE     %90                                     ; At the end of the name
        TEQ     r2, r7
        BEQ     ExitInfoLoop
        B       %80

90
        INC     r1, &1B                                 ; Step to next record
        INC     r3                                      ; Number done
        INC     r4                                      ; Next entry in directory
        B       CopyOverInfo

ExitInfoLoop
        LDR     r5, [ sp, #12 ]                         ; Start of the user's buffer
        SUB     r5, r2, r5
ExitLoop
        ADD     r14, sp, #16                            ; Point into the stack at R3-R5
        CMP     r4, #&100                               ; Have we gone past the end of a viable directory
        MOVHS   r4, #-1                                 ; If so, indicate this fact.  Copes with -1.
        STMIA   r14, { r3, r4, r5 }
ExitFromEnumerate
        MOV     r5, r0
        SavePSR r4                                      ; Save flags
        ADR     r1, CommandBuffer
        LDRB    r0, [ r1, #0 ]
        SWI     XEconet_DeAllocatePort
        Pull    r2
        BL      MyFreeRMA
        MOV     r0, r5                                  ; Restore error
        RestPSR r4,,f                                   ; Restore flags
99
        INC     sp, 4                                   ; Don't return R0
        [       Debug
        Pull    "r1-r5, lr"
        DLINE   "Exit from enumeration"
        DREG    r0, "R0 = &", cc
        DREG    r1, "   R1 = &", cc
        DREG    r2, "   R2 = &"
        DREG    r3, "Number of names returned (R3) = &", cc
        DREG    r4, "  Start again with name number &"
        DREG    r5, "Amount of the buffer used is (R5) &", cc
        DLINE   " bytes"
        DREG    r6, "R6 = &"
        DREG    r7, "R7  = &", cc
        DREG    r8, "   R8  = &", cc
        DREG    r9, "   R9  = &"
        DREG    r10, "R10 = &", cc
        DREG    r11, "   R11 = &", cc
        DREG    r12, "   WP  = &"
        DREG    r13, "SP  = &", cc
        DREG    r14, "   LR  = &", cc
        DREG    r15, "   PC/PSR = &"
        MOV     pc, lr
        |
        Pull    "r1-r5, pc"
        ]       ; Debug
        ]       ; Files24Bit
        [       Files32Bit
        !       0, "The code for 32 bit enumeration isn't finished yet"
EnumerateObjectNames ROUT
        MOV     r9, #2
        MOV     r8, #11
        CMP     r3, #64                                 ; Arbitrary
        MOVGT   r3, #64
        B       StandardEnumeration

EnumerateObjectInfo
        MOV     r9, #0
        MOV     r8, #27
        CMP     r3, #32
        MOVGT   r3, #32
        B       StandardEnumeration

EnumerateObjectsForCatalog
        MOV     r9, #0
        MOV     r8, #27
        CMP     r3, #32
        MOVGT   r3, #32

StandardEnumeration
        [       Debug
        DLINE   "Entry to a 32 bit enumeration"
        DREG    r0, "Function code (R0) = &", cc
        DREG    r1, "  Address of directory name (R1) = &"
        DSTRING r1, "Value of directory name "
        DREG    r6, "Special field of the name (R6) is at &", cc
        DSTRING r6, " and is "
        DREG    r2, "Buffer (R2) = &", cc
        DREG    r5, " and is (R5) &", cc
        DLINE   " bytes long"
        DREG    r3, "Number of names to get (R3) = &", cc
        DREG    r4, "  Start with name number &"
        DREG    r7, "R7  = &", cc
        DREG    r8, "   R8  = &", cc
        DREG    r9, "   R9  = &"
        DREG    r10, "R10 = &", cc
        DREG    r11, "   R11 = &", cc
        DREG    r12, "   WP  = &"
        DREG    r13, "SP  = &", cc
        DREG    r14, "   LR  = &", cc
        DREG    r15, "   PC/PSR = &"
        ]       ; Debug
        ;       Entered with lr on stack
        ;       R0 => Function code
        ;       R1 => Directory name
        ;       R2 => Pointer to core
        ;       R3 => Number of object names required (after limiting)
        ;       R4 => Entry number in directory to start at (0...)
        ;       R5 => Buffer length
        ;       R6 => Special field (will be zero)
        ;       R8 => Size of record returned by FS
        ;       R9 => Argument to function examine
        ;       R3 <= Number of objects read
        ;       R4 <= Next entry in the directory
        ;       R5 <= Amount of the buffer used
        [       :LNOT: OldOs
        Push    "r0-r5"                                 ; Must preserve the entry value of R1
        BL      UseNameToSetTemporary                   ; Not the returned normalised value
        STRVS   r0, [ sp, #0 ]
        Pull    "r0-r5, pc", VS
        B       DoEnumerate

        ]       ; OldOs
EnumerateEntry                                          ; Called from the cataloging routines
        Push    "r0-r5"
DoEnumerate
        MOV     r7, r1                                  ; Keep the pointer to the name
        [       :LNOT: OldOs
        CMP     r4, #0                                  ; Is this the first time?
        BLEQ    CacheDirectoryName                      ; Trashes R0, R1, R2, R4, R5
        BVS     %99
        ]
        MUL     r4, r8, r3                              ; Size calculated
        INC     r4, 5                                   ; One byte spare
        MOV     r3, r4                                  ; Copy into right register for Claim, preserving R4 for Create
        BL      MyClaimRMA
        BVS     %99
        Push    r2                                      ; Address of the block, for the exit code
        MOV     r3, r2
        SWI     XEconet_AllocatePort
        BVS     ExitFromEnumerate
        MOV     r11, r0                                 ; Save port
        LDR     r6, Temporary
        ADD     r14, r6, #Context_Station
        LDMIA   r14, { r1, r2 }
        SWI     XEconet_CreateReceive
        BVS     ExitFromEnumerate
        MOV     r10, r0                                 ; The RxHandle
        ADR     r1, CommandBuffer
        STRB    r11, [ r1, #0 ]                         ; Put reply port in 'TxHeader'
        MOV     r0, #FileServer_Examine
        STRB    r0, [ r1, #1 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_RootDirectory ]
        STRB    r0, [ r1, #2 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_Library ]
        STRB    r0, [ r1, #4 ]                          ; Put in 'TxHeader'
        STRB    r9, [ r1, #5 ]                          ; Argument
        LDR     r0, [ sp, #20 ]                         ; Entry point
        STRB    r0, [ r1, #6 ]
        LDR     r0, [ sp, #16 ]                         ; Number
        STRB    r0, [ r1, #7 ]
        MOV     r0, r7                                  ; Directory name
        MOV     r2, #8
        BL      CopyPathNameInDoingTranslation
        LD      r3, FSOpHandleFlags
        [       Debug
        AND     r14, r3, #URDSlotMask
     ;  ASR     r14, URDSlotShift
        BREG    r14, "URD = &", cc
        AND     r14, r3, #CSDSlotMask
        myASR   r14, CSDSlotShift
        BREG    r14, "  CSD = &", cc
        AND     r14, r3, #LIBSlotMask
        myASR   r14, LIBSlotShift
        BREG    r14, "  LIB = &"
        ]
        AND     r3, r3, #CSDSlotMask
        ADD     r0, r6, #Context_RootDirectory
        LDRB    r0, [ r0, r3, LSR #CSDSlotShift ]
        STRB    r0, [ r1, #3 ]                          ; Put in 'TxHeader'
        LDRB    r0, [ r6, #Context_Domain ]
        MOV     r5, r2                                  ; Length
        MOV     r4, r1                                  ; Buffer
        ADD     r14, r6, #Context_Station
        LDMIA   r14, { r2, r3 }
        MOV     r1, #Port_FileServerCommand
        LD      r7, FSTransmitDelay
        LD      r6, FSTransmitCount
        SWI     XEconet_DoTransmit
        BVS     ExitFromEnumerate
        MOV     r5, r0                                  ; Return status
        TEQ     r5, #Status_Transmitted
        MOV     r0, r10
        BEQ     WaitForReplies
        SWI     XEconet_AbandonReceive
        BVS     ExitFromEnumerate
        MOV     r0, r5
45
        BL      ConvertStatusToError
        B       ExitFromEnumerate

        LTORG

WaitForReplies
        LD      r1, FSReceiveDelay
        MOV     r2, pc                                  ; Non-zero => ESCapable
        SWI     XEconet_WaitForReception
        BVS     ExitFromEnumerate
        TEQ     r0, #Status_Received
        BNE     %45
        MOV     r0, r5
        BL      ConvertFSError
        BVS     ExitFromEnumerate
        ADD     r1, r5, #4
        LDR     r2, [ sp, #12 ]                         ; User buffer
        LDR     r7, [ sp, #24 ]                         ; User's buffer size
        LDRB    r8, [ r1, #-2 ]                         ; Number of entries returned
        ;       Exit with the following :
        ;       R3 <= Number of objects read
        ;       R4 <= Next entry in the directory
        ;       R5 <= Amount of the buffer used
        MOV     r3, #0
        TEQ     r8, #0                                  ; Exit with special conditions for FileSwitch
        MOVEQ   r4, #-1                                 ; R3=0, R4=-1
        BEQ     ExitLoop
        LDR     r4, [ sp, #20 ]
        MOV     r5, #0
        TEQ     r9, #2                                  ; Just names or info as well
        ADDNE   r7, r2, r7                              ; Calculate the end of the user's buffer
        BNE     CopyOverInfo
EnumerateNamesLoop
        DECS    r8                                      ; Number of entries sent
        BMI     ExitLoop
        INC     r1                                      ; Step over the length field
60
        TEQ     r5, r7                                  ; Are we at the end of the users buffer
        BEQ     ExitLoop
        LDRB    r0, [ r1 ], #1
        TEQ     r0, #&80
        MOVEQ   r0, #0                                  ; Get special case at the end
        CMP     r0, #" "
        MOVLE   r0, #0                                  ; Terminate
        STRB    r0, [ r2, r5 ]
        INC     r5
        BGT     %60                                     ; Not at end of name yet
        DEC     r1, 2                                   ; Step back in amazement
65
        LDRB    r0, [ r1, #1 ] !
        TEQ     r0, #" "                                ; Find next record
        BEQ     %65
        INC     r3                                      ; Number done
        INC     r4                                      ; Next entry in directory
        B       EnumerateNamesLoop

CopyOverInfo
        ; The info is returned from the file server in 27=&1B byte records
        ; 00 Byte 10 ; Object name, padded with spaces
        ; 0A Word    ; Load address
        ; 0E Word    ; Execute address
        ; 12 Byte    ; Type and access
        ; 13 Bytes 2 ; Date in FS format
        ; 15 Bytes 3 ; SIN
        ; 18 Bytes 3 ; Length
        ; 1B Next object
        ; ========================================
        ; The value at [ SP, #4 ] is the original reason code, this is the
        ; only difference between the two cases (info and catalog data).
        ; ========================================
        ; The info is returned to the user as follows
        ;    ALIGN
        ; 00 Word    ; Load address
        ; 04 Word    ; Execute address
        ; 08 Word    ; Length
        ; 0C Word    ; Attributes (as per XOS_File R5)
        ; 10 Word    ; Type (as per XOS_File R0)
        ; 14 Byte ?? ; Object name
        ; xx Byte    ; Terminating zero
        ; ========================================
        ; The catalog data is returned to the user as follows
        ;    ALIGN
        ; 00 Word    ; Load address
        ; 04 Word    ; Execute address
        ; 08 Word    ; Length
        ; 0C Word    ; Attributes (as per XOS_File R5)
        ; 10 Word    ; Type (as per XOS_File R0)
        ; 14 Word    ; S.I.N.
        ; 18 Bytes 5 ; Date
        ; 1D Byte ?? ; Object name
        ; xx Byte    ; Terminating zero
        ; ========================================
        DECS    r8                                      ; Number of entries sent
        BMI     ExitInfoLoop
        INC     r2, 3
        BIC     r2, r2, #2_11                           ; Align pointer
        SUB     r0, r7, r2                              ; Are we near the end of the users buffer
        CMP     r0, #&28                                ; The minimum required is &28 bytes
        BGE     %70
        LDR     r14, [ sp, #4 ]
        TEQ     r14, #fsfunc_ReadDirEntriesInfo         ; Function code for ReadObjectInfo
        BNE     ExitInfoLoop
        CMP     r0, #&1F                                ; The minimum required is &1F bytes
        BLT     ExitInfoLoop
70
        ADD     r14, r1, #&0A                           ; Address of load address
        LDW     r0, r14, r10, r11
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&0E                           ; Address of execute address
        LDW     r0, r14, r10, r11
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&18                           ; Address of the length
        LDW     r0, r14, r10, r11
        AND     r0, r0, #&00FFFFFF
        STR     r0, [ r2 ], #4
        MOV     r0, r1
        LDRB    r1, [ r0, #&12 ]                        ; FS format protection
        BL      ConvertProtectionFromFS                 ; In R5
        MOV     r1, r0
        LDRB    r0, [ r1, #&13 ]
        ORR     r5, r5, r0, LSL #8
        LDRB    r0, [ r1, #&14 ]
        ORR     r5, r5, r0, LSL #16
        STR     r5, [ r2 ], #4                          ; Attributes
        LDRB    r0, [ r1, #&12 ]
        ANDS    r0, r0, #BitFive
        MOVEQ   r0, #1
        MOVNE   r0, #2
        STR     r0, [ r2 ], #4                          ; Type 1=File 2=Dir
        STRB    r0, [ r1, #10 ]                         ; Terminate the returned name
        LDR     r14, [ sp, #4 ]
        TEQ     r14, #fsfunc_ReadDirEntriesInfo         ; Function code for ReadObjectInfo
        BEQ     %75                                     ; Skip SIN, and Date
        ADD     r14, r1, #&15                           ; Address of the S.I.N.
        LDW     r0, r14, r10, r11
        AND     r0, r0, #&00FFFFFF
        STR     r0, [ r2 ], #4
        ADD     r14, r1, #&13                           ; Address of the File server format date
        LDW     r0, r14, r10, r11
        BL      ConvertFileServerDate                   ; From R0 into R10 and R11b
        BVS     ExitFromEnumerate
        STMIA   r2, { r10, r11 }                        ; Stores 8 bytes of which only 5 are valid
        INC     r2, 5
75
        ADD     r14, r1, #0                             ; Start of the name
80
        LDRB    r0, [ r14 ], #1
        CMP     r0, #" "
        MOVLE   r0, #0                                  ; Terminate
        STRB    r0, [ r2 ], #1
        BLE     %90                                     ; At the end of the name
        TEQ     r2, r7
        BEQ     ExitInfoLoop
        B       %80

90
        INC     r1, &1B                                 ; Step to next record
        INC     r3                                      ; Number done
        INC     r4                                      ; Next entry in directory
        B       CopyOverInfo

ExitInfoLoop
        LDR     r5, [ sp, #12 ]                         ; Start of the user's buffer
        SUB     r5, r2, r5
ExitLoop
        ADD     r14, sp, #16                            ; Point into the stack at R3-R5
        CMP     r4, #&100                               ; Have we gone past the end of a viable directory
        MOVHS   r4, #-1                                 ; If so, indicate this fact.  Copes with -1.
        STMIA   r14, { r3, r4, r5 }
ExitFromEnumerate
        MOV     r5, r0
        MOV     r4, psr                                 ; Save flags
        ADR     r1, CommandBuffer
        LDRB    r0, [ r1, #0 ]
        SWI     XEconet_DeAllocatePort
        Pull    r2
        BL      MyFreeRMA
        MOV     r0, r5                                  ; Restore error
        TEQP    r4, #0                                  ; Restore flags
99
        INC     sp, 4                                   ; Don't return R0
        [       Debug
        Pull    "r1-r5, lr"
        DLINE   "Exit from enumeration"
        DREG    r0, "R0 = &", cc
        DREG    r1, "   R1 = &", cc
        DREG    r2, "   R2 = &"
        DREG    r3, "Number of names returned (R3) = &", cc
        DREG    r4, "  Start again with name number &"
        DREG    r5, "Amount of the buffer used is (R5) &", cc
        DLINE   " bytes"
        DREG    r6, "R6 = &"
        DREG    r7, "R7  = &", cc
        DREG    r8, "   R8  = &", cc
        DREG    r9, "   R9  = &"
        DREG    r10, "R10 = &", cc
        DREG    r11, "   R11 = &", cc
        DREG    r12, "   WP  = &"
        DREG    r13, "SP  = &", cc
        DREG    r14, "   LR  = &", cc
        DREG    r15, "   PC/PSR = &"
        MOV     pc, lr
        |
        Pull    "r1-r5, pc"
        ]       ; Debug
        ]       ; Files32Bit
        ]       ; Files32Bit :LAND: Files24Bit

ConvertFileServerDate ROUT                              ; From R0 into R10 and R11b
        ; ==========================================
        ; Bits 12 - 15  =>  Year since 1981
        ; Bits  5 - 7   =>  Multiply year by 16 times this
        ; Bits  8 - 11  =>  Month (1..12)
        ; Bits  0 -  4  =>  Day of the month (1..31)
        ; ==========================================
        Push    "r8, r9, lr"
        ADR     r10, BaseYear
        LDMIA   r10, { r10, r11 }
        ANDS    r8, r0, #2_11111                        ; Mask out the day number
        BEQ     %80                                     ; Zero is an illegal day
10
        DECS    r8
        BLE     %20
        BL      AddOneDay
        B       %10

20
        AND     r9, r0, #2_11100000                     ; Get high order bits of the year
        myASR   r9, 1                                   ; Align to the correct place
        AND     r8, r0, #2_1111000000000000             ; Change to &1000*(0..15), the year since 1981
        ORRS    r8, r9, r8, ASR #12                     ; Change to (0..127), note leap years end in 2_xx11
        INC     r8                                      ; Change to (1..128), now leap years end in 4_xxx0
        Push    r8
30
        DECS    r8
        BEQ     %40
        LDR     r9, OneYear
        ADDS    r10, r10, r9
        ADC     r11, r11, #0
        ANDS    r9, r8, #4_0003
        ; TEQ r9, #4_0000                               ; Leap year
        BLEQ    AddOneDay                               ; Leap year
        B       %30

40
        ANDS    r8, r0, #2_111100000000                 ; Make up to &100*(1..12), the month
        BEQ     %70                                     ; Zero is an illegal month
        CMP     r8, #12*&100
        BHI     %70                                     ; 13, 14, and 15 are illegal months
        ADR     r14, DayTable - 1
        LDRB    r14, [ r14, r8, LSR #8 ]                ; Maximum days in month
        TEQ     r8, #2*&100                             ; Is this February?
        LDR     r9, [ sp, #0 ]                          ; Get saved year out of stack
        TSTEQ   r9, #2_0011                             ; EQ for leap year
        ADDEQ   r14, r14, #1                            ; Leap year so February has an extra day
        AND     r9, r0, #2_11111                        ; Mask out the day number
        CMP     r9, r14                                 ; Are there too many days for this month?
        BHS     %70
        Pull    r9                                      ; The year
        myLSR   r8, 6                                   ; Align as a word address
        DECS    r8, 8                                   ; Reduce to 4*(-1..10)
        BMI     %60                                     ; Nothing to do in Jan, so it's now 4*(0..10)
        BEQ     %50                                     ; If still in Feb skip adding possible leap day
        ANDS    r9, r9, #2_0011
        ; TEQ r9, #2_0000                               ; Leap year
        BLEQ    AddOneDay
50
        ADR     r9, MonthTable
        LDR     r9, [ r9, r8 ]
        ADDS    r10, r10, r9
        ADC     r11, r11, #0
60
        CLRV
        Pull    "r8, r9, pc"

DayTable
        ; Use BHS to check except Feb in leap year increment first
        DCB     32, 29, 32, 31, 32, 31
        DCB     32, 32
        DCB     31, 32, 31, 32
        ALIGN

70
        INC     sp, 4                                   ; Adjust for the single word on the stack
80
        ADRL    r0, ErrorBadFileServerDate
        Pull    "r8, r9, lr"
        [       UseMsgTrans
        B       MakeError
        |
        ORRS    pc, lr, #VFlag
        ]

AddOneDay
        LDR     r9, OneDay
        ADDS    r10, r10, r9
        ADC     r11, r11, #0
        MOV     pc, lr

BaseYear                                                ; 00:00:00 01-Jan-1981
        DCB     &00, &36, &CE, &83
        DCB     &3B, &00, &00, &00

OneYear
        DCD     &BBF81E00

MonthTable
        DCD     &0FF6EA00                               ; End of Jan
        DCD     &1E625200                               ; End of Feb
        DCD     &2E593C00                               ; End of Mar
        DCD     &3DCC5000                               ; End of Apr
        DCD     &4DC33A00                               ; End of May
        DCD     &5D364E00                               ; End of Jun
        DCD     &6D2D3800                               ; End of Jul
        DCD     &7D242200                               ; End of Aug
        DCD     &8C973600                               ; End of Sep
        DCD     &9C8E2000                               ; End of Oct
        DCD     &AC013400                               ; End of Nov

OneDay
        DCD     &0083D600

ShutDown        ROUT                                    ; LR on stack already
        MOV     r0, #0
        STR     r0, Current                             ; Make sure that there isn't a current FS
ShutDownLoop
        LDR     r0, Contexts                            ; Get the first from the list
        TEQ     r0, #NIL
        Pull    pc, EQ                                  ; No contexts to shut down
        BL      ValidateContext
        BVS     ErrorInShutDown                         ; Head of list invalid nothing more can be done
        MOV     r5, r0                                  ; Keep the pointer
        [       Debug
        DREG    r0, "Shuting down context &"
        ]

        LDR     r14, [ r0, #Context_RootDirectory ]
        TEQ     r14, #0                                 ; Are we logged on here?
        BEQ     SafeToRemove                            ; No so don't send *Bye command

        BL      LogoffGivenFileServer
        BVC     ShutDownLoop                            ; Get the next one
        BL      ErrorAsShutdownWarning                  ; Report the trouble we had
        LDR     r0, Contexts
        TEQ     r0, r5                                  ; See if this record is still there
        BNE     ShutDownLoop                            ; If not then it was removed
        LDR     r0, [ r5, #Context_Link ]               ; Get the next record in the chain
        TEQ     r0, #NIL                                ; If there isn't one then it is safe
        BEQ     SafeToRemove
        BL      ValidateContext                         ; Or if it is valid, then it is safe to remove the original
        BVS     ErrorInShutDown                         ; Head of list invalid nothing more can be done
SafeToRemove
        MOV     r0, r5
        BL      RemoveContext
        B       ShutDownLoop

ErrorInShutDown
        MOV     r14, #NIL
        STR     r14, Contexts                            ; Orphan the list, there is no choice
        Pull    pc

        [       UseMsgTrans
ErrorAsShutdownWarning ROUT
        Push    "r0-r5, lr"
        ADR     r1, Token_ShutdownWarning
        B       InsertErrorInWarning

ErrorAsLogoffWarning
        Push    "r0-r5, lr"
        ADR     r1, Token_LogoffWarning
InsertErrorInWarning
        ADR     r2, TemporaryBuffer
        MOV     r3, #?TemporaryBuffer
        LDR     r4, [ sp ]                              ; Get incoming error
        ADD     r4, r4, #4                              ; Skip past error number to error string
        ADR     r5, TextBuffer                          ; File server name
        BL      MessageTransGSLookup2
        MOVVC   r0, r2                                  ; The passed buffer
        MOV     r1, r3                                  ; Length of the resultant string
        SWIVC   XOS_WriteN
        STRVS   r0, [ sp ]
        Pull    "r0-r5, pc"

Token_ShutdownWarning
        DCB     "Shutdwn", 0
Token_LogoffWarning
        DCB     "LogOff", 0
        ALIGN
        |       ; UseMsgTrans
ErrorAsShutdownWarning ROUT
        Push    "r0, r1, lr"
        ADR     r1, %80
        B       %60

ErrorAsLogoffWarning
        Push    "r0, r1, lr"
        ADR     r1, %90
60
        ADR     r0, %70
        SWI     XOS_Write0
        Pull    r14                                     ; Get incoming error
        ADDVC   r0, r14, #4                             ; Skip past error number to error string
        SWIVC   XOS_Write0
        MOVVC   r0, r1                                  ; Tail of message
        SWIVC   XOS_Write0
        ADRVC   r0, TextBuffer
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI+":"
        SWIVC   XOS_NewLine
        Pull    "r1, pc"

70
        DCB     "Warning: ", 0
80
        DCB     " during shutdown of Net#", 0
90
        DCB     " during logoff from Net#", 0
        ALIGN
        ]       ; UseMsgTrans

        [       :LNOT: OldOs
CanonicaliseSpecialAndDisc
        ;        In      r1 = Special field or 0 if not present
        ;                r2 = disc name or 0 if not present
        ;                r3 = memory to fill special field in or 0 if just return length
        ;                r4 = memory to fill disc name in or 0 if just return length
        ;                r5 = length of special field memory block
        ;                r6 = length of disc name memory block
        ;        Out     r1 = pointer to canonical special field or 0 if not present
        ;                r2 = pointer to canonical disc name or 0 if not present
        ;                r3 = length of overflow from block or special field length
        ;                r4 = length of overflow from block or disc name length
        ;                r5 = unchanged
        ;                r6 = unchanged
        ;
        ;       The canonical form is Net::<name>  The transforms are as follows:
        ;       Net:                    ==> Net::<name>         where name is the current FS name
        ;       Net#<name>:             ==> Net::<name>         easy
        ;       Net#<number>:           ==> Net::<name>         search for number to get name
        ;       Net::<name>             ==> Net::<name>         easy no action required
        ;       Net#<name1>::<name2>    ==> Net::<name2>        confirm name1 and name2 on same FS
        ;       Net#<number>::<name>    ==> Net::<name>         confirm name is on number
        ;
        ;       Possible extension to the special field is to add the username
        ;       e.g. Net#<userid>@<disc>: or Net#<userid>::<disc>
        ;
        [       Debug
        [ {TRUE}
        Push    "r0, lr"
        SWI     XOS_WriteS
        DCB     "Canonicalise ""Net", 0
        ALIGN
        MOVS    r0, r1
        SWINE   XOS_WriteI + "#"
        SWINE   XOS_Write0
        SWI     XOS_WriteI + ":"
        MOVS    r0, r2
        SWINE   XOS_WriteI + ":"
        SWINE   XOS_Write0
        SWI     XOS_WriteS
        DCB     """", 10, 13, 0
        ALIGN
        Pull    "r0, lr"
        |
        DREG    r1, "In  Special field at &", cc
        DSTRING r1, " is ", cc
        DREG    r3, "  R3 = &", cc
        DREG    r5, "  R5 = &"
        DREG    r2, "In  Disc name     at &", cc
        DSTRING r2, " is ", cc
        DREG    r4, "  R4 = &", cc
        DREG    r6, "  R6 = &"
        ]
        ]
        Push    "r1-r6"
        TEQ     r1, #0                                  ; Test for the presence of the special field
        BEQ     NoSpecialField
        MOV     r0, r1                                  ; Save the pointer
        LDRB    r1, [ r1 ]
        BL      IsItANumber
        MOVNE   r2, r0
        BNE     SplitSpecialField                       ; Non-numeric, might be a@b
        MOV     r1, r0
        BL      ReadStationNumber                       ; Returns R4.R3
        BVS     ExitCanonicalise
        CMP     r3, #-1
        CMPNE   r4, #-1
        BEQ     SpecialMustBeFullNumber
        BL      FindValidNumberedContext
        BVS     ExitCanonicalise
        B       SpecialFieldResolvedToContext

SplitSpecialField
        LDRB    r14, [ r0 ], #1                         ; Get character from special field
        TEQ     r14, #0
        BEQ     SpecialFieldIsNameOnly
        TEQ     r14, #"@"
        BNE     SplitSpecialField
        ;       R2 points at "@" terminated userid
        ;       R0 points at 0 terminated discname
        [       Debug
        DSTRING r2, "User name is: "
        DSTRING r0, "Disc name is: "
        ]
        LDRB    r14, [ r0, #0 ]
        TEQ     r14, #0                                 ; Is it of the form Net#<name>@: ?
        LDREQ   r0, Current
        BEQ     CheckUserId
        [       Debug
        DSTRING r0, "GetSpecialContext: "
        ]
        LDRB    r1, [ r0 ]
        BL      IsItANumber
        MOV     r1, r0
        BNE     ResolveSpecialAsAName
        MOV     r5, r2                                  ; Save R2 over ReadStationNumber
        BL      ReadStationNumber                       ; Returns R4.R3
        MOV     r2, r5                                  ; Restore R2
        BVS     ExitCanonicalise
        CMP     r3, #-1
        CMPNE   r4, #-1
        BEQ     SpecialMustBeFullNumber
        BL      FindNumberedContext
        B       ContextFound

SpecialMustBeFullNumber
        ADRL    r0, ErrorUnableToDefault
        BL      MakeError                               ; Translate, setting V
        B       ExitCanonicalise

ResolveSpecialAsAName
        BL      ValidateDiscName
        BLVC    FindNamedContext
ContextFound
        BVS     ExitCanonicalise
CheckUserId                                             ; UserId in R2, context in R0
        TEQ     r0, #0
        LDRNE   r14, [ r0, #Context_RootDirectory ]
        TEQNE   r14, #0
        ADREQL  Error, ErrorNotLoggedOn
        BLEQ    MakeError                               ; Translate, setting V
        BVS     ExitCanonicalise
        MOV     r5, r0                                  ; Keep the context
        LDR     r14, UpperCaseTable
        ADD     r0, r5, #Context_UserId
UserIdMatchLoop
        TEQ     r14, #0
        LDRB    r1, [ r0 ], #1
        LDRNEB  r1, [ r14, r1 ]                         ; Map to upper case
        LDRB    r3, [ r2 ], #1
        LDRNEB  r3, [ r14, r3 ]                         ; Map to upper case
        [       Debug
        Push    "r0, r14"
        DLINE   "Comparing '", cc
        MOV     r0, r1
        SWI     OS_WriteC
        DLINE   "' with '", cc
        MOV     r0, r3
        SWI     OS_WriteC
        DLINE   "'."
        Pull    "r0, r14"
        ]
        CMP     r1, #" "
        MOVLE   r1, #0
        TEQ     r3, #"@"
        MOVEQ   r3, #0
        TEQ     r3, r1
        BNE     UserIdMatchFails
        TEQ     r3, #0                                  ; Was this the exact match?
        BNE     UserIdMatchLoop                         ; If it was then that is OK
        MOV     r0, r5                                  ; Original context value
        B       SpecialFieldResolvedToContext

SpecialFieldIsNameOnly
        LDR     r1, [ sp, #0 ]                          ; Restore R1, special field pointer
        MOV     r0, r1
        BL      ValidateDiscName
        BLVC    FindNamedContext
        BVS     ExitCanonicalise
SpecialFieldResolvedToContext
        LDR     r2, [ sp, #4 ]                          ; Restore R2, disc name pointer
        TEQ     r2, #0
        ADDEQ   r2, r0, #Context_DiscName               ; No disc name
        BEQ     ProcessResolvedDiscName                 ; So use the name of the context
        MOV     r3, r0                                  ; Keep the context
        MOV     r0, r2
        BL      ValidateDiscName
        BVS     ExitCanonicalise
        ;       Now confirm that the disc name in R2 is on the context in R3
        MOV     r1, r2
        BL      FindNamedContext
        BVS     %52
        TEQ     r0, r3
        BEQ     ProcessResolvedDiscName
52
        MOV     r4, r2
        DEC     sp, (DiscNameSize + 1 + 3) :AND: &FFFFFFFC
        MOV     r14, sp
        ADD     r0, r3, #Context_DiscName               ; File server name, this is " " terminated
        MOV     r5, r14                                 ; Start of 0 terminated FS name
43
        LDRB    r6, [ r0 ], #1
        CMP     r6, #" "
        MOVLE   r6, #0                                  ; Convert to 0 terminated
        STRB    r6, [ r14 ], #1
        BGT     %43
        ADR     r0, ErrorDiscAndFileServerDontMatch
        BL      MessageTransErrorLookup2
        INC     sp, (DiscNameSize + 1 + 3) :AND: &FFFFFFFC
        B       ExitCanonicalise

ErrorDiscAndFileServerDontMatch
        DCD     ErrorNumber_DiscAndFileServerDontMatch
        DCB     "NoDisc", 0
        ALIGN

NoSpecialField
        TEQ     r2, #0                                  ; Test for the presence of the disc name
        BNE     DiscNameWithNoSpecialField
NoSpecialFieldOrDiscName
        LDR     r14, Current
        TEQ     r14, #0                                 ; Is there a current context?
        LDRNE   r2, [ r14, #Context_RootDirectory ]     ; If so, is it logged on?
        TEQNE   r2, #0
        ADDNE   r2, r14, #Context_DiscName              ; It is so use this name
        BNE     ProcessResolvedDiscName                 ; Result is in R2
        ADRL    Error, ErrorNotLoggedOn
        BL      MakeError                               ; Translate, setting V
        B       ExitCanonicalise

DiscNameWithNoSpecialField
        MOV     r0, r2
        BL      ValidateDiscName                        ; Original disc name still in R2
        MOV     r1, r2
        BLVC    FindNamedContext
        BVS     ExitCanonicalise
ProcessResolvedDiscName                                 ; R2 now points to the disc name to use
        LDR     r1, [ sp, #3*4 ]                        ; Entry value of R4, buffer for disc name
        TEQ     r1, #0                                  ; Is this just a count operation?
        BNE     CopyDiscName                            ; No, so go copy disc name in
        MOV     r4, #0                                  ; Yes, so count how long the disc name is
CountDiscNameLength
        LDRB    r14, [ r2 ], #1
        [       Debug ; False
        BREG    r14, " &", cc
        ]
        CMP     r14, #" "
        ADDHI   r4, r4, #1                              ; The length value
        BGT     CountDiscNameLength
        [       Debug ; False
        SWI     OS_NewLine
        ]
        MOV     r2, #0                                  ; Show that there is no disc name returned
        B       ExitCanonicalise

CopyDiscName
        LDR     r4, [ sp, #5*4 ]                        ; R6 in (buffer size)
CopyDiscNameLoop
        LDRB    lr, [ r2 ], #1
        [       Debug ; False
        BREG    lr, " &", cc
        ]
        CMP     lr, #" "
        MOVLS   lr, #0
        SUBS    r4, r4, #1
        STRPLB  lr, [ r1 ], #1
        TEQ     lr, #0
        BNE     CopyDiscNameLoop
        [       Debug ; False
        SWI     OS_NewLine
        ]
        ; Sort out the buffer overflow indication
        RSBS    r4, r4, #0
        MOVLT   r4, #0
        LDR     r2, [ sp, #3*4 ]                        ; Entry value of R4
        [       Debug
        MOV     r1, #0                                  ; No special field ever
        MOV     r3, #0
        ADD     sp, sp, #4*4                            ; Remove R1-R4 from stack
        Push    "r0"
        SWI     XOS_WriteS
        DCB     "To ""Net", 0
        ALIGN
        MOVS    r0, r1
        SWINE   XOS_WriteI + "#"
        SWINE   XOS_Write0
        SWI     XOS_WriteI + ":"
        MOVS    r0, r2
        SWINE   XOS_WriteI + ":"
        SWINE   XOS_Write0
        SWI     XOS_WriteS
        DCB     """", 10, 13, 0
        ALIGN
        Pull    "r0, r5-r6, pc"
        ]
ExitCanonicalise
        MOV     r1, #0                                  ; No special field ever
        MOV     r3, #0
        ADD     sp, sp, #4*4                            ; Remove R1-R4 from stack
        [       Debug
        Pull    "r5-r6"
        Pull    "pc", VS
        DREG    r1, "Out Special field at &", cc
        DSTRING r1, " is ", cc
        DREG    r3, "  R3 = &", cc
        DREG    r5, "  R5 = &"
        DREG    r2, "Out Disc name     at &", cc
        DSTRING r2, " is ", cc
        DREG    r4, "  R4 = &", cc
        DREG    r6, "  R6 = &"
        Pull    "pc"
        |
        Pull    "r5-r6, pc"
        ]

UserIdMatchFails
        LDR     r2, [ sp, #0 ]                          ; Entry value of special field
        DEC     sp, (DiscNameSize + 1 + UserIdSize + 1 + 3) :AND: &FFFFFFFC
        MOV     r14, sp
        ADD     r0, r5, #Context_DiscName               ; File server name, this is " " terminated
        MOV     r4, r14                                 ; Start of 0 terminated FS name
18
        LDRB    r6, [ r0 ], #1
        CMP     r6, #" "
        MOVLE   r6, #0                                  ; Convert to 0 terminated
        STRB    r6, [ r14 ], #1
        BGT     %18
        MOV     r5, r14                                 ; Start of 0 terminated User Id
19
        LDRB    r6, [ r2 ], #1
        TEQ     r6, #"@"
        MOVEQ   r6, #0                                  ; Convert to 0 terminated
        STRB    r6, [ r14 ], #1
        BNE     %19
        ADR     r0, ErrorNotLoggedOnToAs
        BL      MessageTransErrorLookup2
        INC     sp, (DiscNameSize + 1 + UserIdSize + 1 + 3) :AND: &FFFFFFFC
        B       ExitCanonicalise

ErrorNotLoggedOnToAs
        DCD     ErrorNumber_NotLoggedOn
        DCB     "NLogOnU", 0
        ALIGN


ResolveWildcard
        ;        In      r1 = Path to a directory
        ;                r2 = Address of block to place name, or 0 if none
        ;                r3 = wildcarded object name
        ;                r5 = size of block
        ;                r6 = Special field
        ;        Out     r1 = unchanged
        ;                r2 = -1 if not found, or pointer to filled in name, or 0 if no block
        ;        passed in.
        ;                r3 = unchanged
        ;                r4 = overflow of block, 0 if no overflow, -1 if FileSwitch should
        ;        resolve this wildcard itself
        ;                r5 = unchanged
        MOV     r4, #-1                                 ; I am unable to help
        Pull pc

ReadBootOption  ROUT
        ;       R1 => Pointer to name of thing to find the boot option for
        ;       R6 => Pointer to the special field (now always zero)
        ;       R2 <= Boot option
        [       Debug
        DLINE   "ReadBootOption"
        ]
        BL      UseNameToSetTemporary
        LDRVC   r2, Temporary
        LDRVCB  r2, [ r2, #Context_BootOption ]
        [       Debug
        BREG    r2, "Returns &"
        ]
        Pull    pc

WriteBootOption ROUT
        ;       R1 => Pointer to name of thing to write the boot option on
        ;       R2 => Boot option
        ;       R6 => Pointer to the special field (now always zero)
        BL      UseNameToSetTemporary
        Pull    pc, VS
        B       SetBootOptionOnTemporary

DirectoryIsNow  ROUT
        ;       This is called by FileSwitch when the user does *Dir or *Lib
        ;       R1 => Pointer to a canonical name
        ;       R2 => Directory that is being set
        ;       R6 => Pointer to the special field, should be empty
        ;       SP => Return address
        TEQ     r2, #Dir_Current
        TEQNE   r2, #Dir_Library
        Pull    pc, NE
        [       Debug
        BREG    r2, "Directory type &", cc
        DSTRING r1, " has been set to "
        ]
        MOV     r5, r1                                  ; Preserve the canonical name
        ;       The first part of the name (up to the ".") should be the FS name
        ;       We should find the relevant FS and update its <Dir>Name string
        DEC     sp, SmallBufferSize                     ; Enough space for a disc name
        MOV     r4, sp                                  ; Copy the name to the stack
10
        LDRB    r14, [ r1, #1 ] !                       ; Skipping the first character ":"
        TEQ     r14, #"."                               ; Terminate at the "."
        MOVEQ   r14, #0
        STRB    r14, [ r4 ], #1
        BNE     %10
        MOV     r1, sp
        BL      FindNamedContext                        ; Get a pointer to the context
        INC     sp, SmallBufferSize                     ; Remove stack frame
        Pull    pc, VS
        TEQ     r2, #Dir_Current                        ; Note that V is clear
        ADDNE   r4, r0, #Context_LibraryName            ; The address of the string
        ADDEQ   r4, r0, #Context_DirectoryName
        BLEQ    MaybeChangeFS                           ; May have to change "&"
        B       %20

SetString
        ;       R4 => Address in the record of the pointer to the string
        ;       R5 => Pointer to the name to set
        ;       Trashes R0, R1, R2, R3, R5
        Push    lr
20
        MOV     r3, #0                                  ; Count the size so we can get some space
30
        LDRB    r14, [ r5, r3 ]
        INC     r3
        CMP     r14, #" "                               ; Unknown terminator
        MOVLS   r14, #0
        BHI     %30
        BL      MyClaimRMA
        Pull    pc, VS
        MOV     r3, #0
50
        LDRB    r14, [ r5 ], #1
        CMP     r14, #" "                               ; Unknown terminator
        MOVLS   r14, #0
        STRB    r14, [ r2, r3 ]
        INC     r3
        BHI     %50
        LDR     r1, [ r4 ]
        STR     r2, [ r4 ]
        CMP     r1, #0
        [       Debug
        DSTRING r2, "Storing ", cc
        DREG    r2, " at &"
        DREG    r1, "Previous pointer was &"
        ]
        MOVNE   r2, r1
        BLNE    MyFreeRMA
        Pull    pc

MaybeChangeFS
        ;       R0 => Context to make current
        ;       PSR <= EQ for no change, NE for change
        ;       Trashes R0, r1, r2, r3
        Push    lr
        LDR     r3, Current
        TEQ     r3, r0                                  ; Have we just looked up the current FS?
        Pull    pc, EQ
        STR     r0, Current
        DEC     sp, SmallBufferSize
        LDR     r1, [ r0, #Context_RootDirectory ]
        TEQ     r1, #0
        BEQ     UnSetURD
        MOV     r1, sp
        MOV     r14, #":"
        STRB    r14, [ r1, #0 ]
        MOV     r2, #1
        ADD     r0, r0, #Context_DiscName
        BL      CopyNameIn
        SUB     r2, r2, #1
        ADRL    r0, DotAmpersand
        BL      CopyNameIn
UnSetURD
        MOV     r2, #Dir_UserRoot
        [       Debug
        DSTRING r1, "User Root (&) := ", cc
        DREG    r1, " from address &"
        ]
        BL      SetDir
        INCS    sp, SmallBufferSize
        Pull    pc
        ]       ; OldOs

        LTORG

        END
