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
        TTL     > SystemDevs - System Devices (vdu:, rawvdu:, kbd:, rawkbd:, null:, zero:, random:, urandom:)

; ***********************************
; ***    C h a n g e   L i s t    ***
; ***********************************

; Date       Name  Version Description
; ----       ----  ------- -----------
; 09-Sep-87  SKS    1.01   Fixed WriteC error problem in hex output on vdu:
;                          Also fixed printer: not working twice !
; 10-Sep-87  SKS    1.02   Fixed printer: with *fx5,4 problem (no ^C before)
;                          Add printer#user: and printer#nnn: features
; 08-Feb-88  SKS    1.03   Fixed serial: to allow multiple streams (even though
;                          same device) and this stops init mess
; 17-Feb-88  SKS    1.04   Fixed vdu:, rawvdu: to allow openup
; 14-Apr-88  SKS    1.05   Changed $ to &; also TTL
; 20-Apr-88  SKS    1.06   Made serial: input restore fx2 to 2 not 0 so that
;                          input is not corrupted (MOS flushes RDR on change
;                          from a non-recieve mode to recieve mode)
; 09-May-88  SKS    1.07   Made serial: use OS_SerialOp rather than OS_Byte 3
;                          and OS_WriteC. Fixed adding devices (forgot VC)
; 01-Jun-88  SKS    1.08   Reuse of xxx: in error messages for opt info
; 27-Jul-88  SKS    1.09   Fixed FSArgsCommon; was trying (but failing) to NOP
;                          flush notify!
; 28-Jul-88  SKS    1.10   Made printer: use OS_PrintChar, rawvdu: use WriteN
; 01-Aug-88  SKS    1.11   Made serial: use OS_SerialOp for i/p, also fx2,2
; 09-Sep-88  SKS    1.12   Attempted to fix printer#xxx: (would leave wrong
;                          printer stream selected). Also fixed errors from
;                          OS_PrintChar to be returned. Parallel and serial
;                          were transposed! All this time too!
; 13-Sep-88  SKS    1.13   printer: could not be opened due to missing
;                          MOV r7, r6
; 23-Nov-89  TMD    1.13   Added GET &.Hdr.CMOS - no change to object
; 01-Dec-89  TMD    1.14   Allow OS_File(6) on pseudo-fs's
; 11-Dec-91  DDV    1.15   Conditional removal of 'printer:' & 'serial:'
; 21-Feb-91  DDV           Printer: re-installed only Serial: assembled out.
; 25-Feb-91  DDV           The rehack of printer: to use multiple streams.
; 26-Feb-91  DDV           Added block-write to the printer device.
; 27-Feb-91  DDV    1.16   Added setting up of PrinterType$0 Null:
; 05-Mar-91  TMD    1.17   Fixed bug in kbd: due to length only being stored in
;                           one byte
;                          Made EOF persistent
; 11-Mar-91  OSS    1.18   Internationalised - only has error blocks
; 28-Mar-91  OSS    1.19   Change internationalisation to use generic tokens
; 18-Apr-91  OSS    1.20   Fixed R1 corruption on error translations.
; 18-Apr-91  OSS    1.21   Turn serial: off - serial manager exists now!
; 25-Jul-91  TMD    1.22   Fixed OS_File Save where variable exists (length was -ve)
; 26-Jul-91  TMD    1.23   Stopped selection of fast streams or failed selection of the slow
;                           stream overwriting old printer type to restore when slow stream closes.
;                          Made printer#special: select the correct printer again.
; 05-Aug-91  TMD    1.24   Fixed bug in open_message_file which assumed V=0 on entry.
;                          Fixed bug in unknown vdu/rawvdu args or func calls that caused
;                           branch thru zero.
; 02-Sep-91  TMD    1.25   Converted one error message to use global message, shortened token for
;                           another.
;                          Added stand-alone option.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:Proc
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:NewErrors
        GET     Hdr:OsBytes
        GET     Hdr:CMOS
        GET     Hdr:Variables
        GET     Hdr:MsgTrans
        GET     Hdr:ResourceFS

        GET     VersionASM

        AREA    |SystemDevices$$Code|, CODE, READONLY, PIC

                GBLL    debug
debug           SETL    {FALSE}

                GBLS    get1
                GBLS    get2
                GBLS    get3
              [ debug
get1            SETS    " GET Hdr:Debug"
get2            SETS    " GET Hdr:HostFS"
get3            SETS    " GET Hdr:HostDebug"
              ]
$get1
$get2
$get3

                GBLL    export_serial           ; =true for exported serial:
export_serial   SETL    {FALSE}

                GBLL    Host_Debug
Host_Debug      SETL    {TRUE}

              [ :LNOT: :DEF: standalone
                GBLL    standalone
standalone      SETL {FALSE}                    ; Build-in Messages file and i/f to ResourceFS
              ]

TAB     *       9
LF      *       10
FF      *       12
CR      *       13


                ^       0, wp

KbdHandle       #       4
KbdIndex        #       4
KbdLength       #       4

PrinterHandle   #       4       ; !=0 if in use, ==0 if free, only used if Opening the variable fails.
PrinterType     #       4       ; 0..255 or -1 if not changed by SussSpecial

SourceRandSeed  #       4

GSFormat        #       1
LastChar        #       1
RdchSrc         #       1
WrchDest        #       1

FilenameBuffer  #       0       ; both Kbd / PrinterSussType use this buffer
KbdBuffer       #       256

message_file_block  #   16      ; File handle for MessageTrans
message_file_open   #   4       ; Opened message file flag

SystemDevices_WorkspaceSize * :INDEX: @

addr_verbose    SETA    0

; **************** SystemDevices Module code starts here **********************

Module_BaseAddr

        DCD     0
        DCD     SystemDevices_Init    -Module_BaseAddr
        DCD     SystemDevices_Die     -Module_BaseAddr
        DCD     SystemDevices_Service -Module_BaseAddr
        DCD     SystemDevices_Title   -Module_BaseAddr
        DCD     SystemDevices_HelpStr -Module_BaseAddr
        DCD     0
 [ :LNOT: No32bitCode
        DCD     0, 0, 0, 0      ; SWI entries
        DCD     0               ; International messages
        DCD     SystemDevices_Flags   -Module_BaseAddr
 ]


SystemDevices_Title
        DCB     "SystemDevices", 0

SystemDevices_HelpStr
        DCB     "System Devices", TAB, "$Module_HelpVersion", 0
        ALIGN

 [ :LNOT: No32bitCode
SystemDevices_Flags
        DCD     ModuleFlag_32bit
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; r0-r6 trashable

SystemDevices_Init Entry

        LDR     r2, [r12]               ; Coming from hard reset ?
        TEQ     r2, #0
        BNE     %FT50

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =SystemDevices_WorkspaceSize
        SWI     XOS_Module
        EXIT    VS                      ; 'No room in RMA' is acceptable msg
        STR     r2, [r12]

50
        MOV     wp, r2                  ; Dereference on all resets !

 [ standalone
        ADRL    r0, resourcefsfiles
        SWI     XResourceFS_RegisterFiles
        EXIT    VS
 ]

; OSS Flag that the message file is closed.

        MOV     r0, #0
        STR     r0, message_file_open

        MOV     r0, #1                  ; ISO9899:1999 7.20.2.2
        STR     r0, SourceRandSeed

        MOV     r0, #OsByte_ReadCMOS    ; Read configured DumpFormat
        MOV     r1, #PrintSoundCMOS
        SWI     XOS_Byte
        ANDVC   r1, r2, #2_1111         ; Mask out all but my bits
        STRVCB  r1, GSFormat

        MOVVC   r14, #0
        STRVCB  r14, LastChar
        STRVC   r14, PrinterHandle
        STRVC   r14, KbdHandle

        BLVC    AddDevices

        ADRVC   r0, nullcommand                 ; setup system variables
        SWIVC   XOS_CLI
        ADRVC   r0, zerocommand
        SWIVC   XOS_CLI
        ADRVC   r0, randomcommand
        SWIVC   XOS_CLI
        ADRVC   r0, urandomcommand
        SWIVC   XOS_CLI

        EXIT

        LTORG

nullcommand
        = "Set PrinterType$0 null:",0
zerocommand
        = "Set zero$$Path source#zero:",0
randomcommand
        = "Set random$$Path source#random:",0
urandomcommand
        = "Set urandom$$Path source#urandom:",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SystemDevices_ServiceTable
        ASSERT  Service_FSRedeclare < Service_ResourceFSStarting
        DCD     0
        DCD     SystemDevices_ServiceEntry-Module_BaseAddr
        DCD     Service_FSRedeclare
 [ standalone
        DCD     Service_ResourceFSStarting
 ]
        DCD     0

        DCD     SystemDevices_ServiceTable-Module_BaseAddr

SystemDevices_Service ROUT

        MOV     r0, r0
        TEQ     r1, #Service_FSRedeclare
 [ standalone
        TEQNE   r1, #Service_ResourceFSStarting
 ]
        MOVNE   pc, lr

SystemDevices_ServiceEntry

 [ standalone
        TEQ     r1, #Service_ResourceFSStarting
        BNE     %FT30
        Push    "r0-r3,lr"
        ADRL    r0, resourcefsfiles
        MOV     lr, pc
        MOV     pc, r2
        Pull    "r0-r3,pc"
30
 ]
        Entry   "r0"
        LDR     wp, [r12]
        BL      AddDevices
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 trashable

AddDevices Entry "r1-r3"

        MOV     r0, #FSControl_AddFS
        ADR     r1, Module_BaseAddr
        MOV     r3, wp

        MOV     r2, #(null_FSInfoBlock-Module_BaseAddr)
        SWI     XOS_FSControl

        MOVVC   r2, #(source_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

        MOVVC   r2, #(vdu_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

        MOVVC   r2, #(rawvdu_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

        MOVVC   r2, #(kbd_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

        MOVVC   r2, #(rawkbd_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

        MOVVC   r2, #(printer_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl

  [ export_serial
        MOVVC   r2, #(serial_FSInfoBlock-Module_BaseAddr)
        SWIVC   XOS_FSControl
  ]

        EXIT

; Collect all module headers together here in ADR range of AddDevices

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; null - notpermanent, alwaysopen, nullok

null_ModuleBase  *      Module_BaseAddr

null_Commands    *      null_ModuleBase ; ie. 0 - no commands or help
null_StartupText *      null_ModuleBase

null    FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_null

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; source - notpermanent, alwaysopen, nullok, read only, specials

source_ModuleBase  *    Module_BaseAddr

source_Commands    *    source_ModuleBase ; ie. 0 - no commands or help
source_StartupText *    source_ModuleBase
source_Put         *    source_ModuleBase

source  FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsinfo_readonly + fsinfo_special + fsnumber_Source

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; vdu - notpermanent, alwaysopen, nullok

vdu_ModuleBase  *       Module_BaseAddr

vdu_Commands    *       vdu_ModuleBase ; ie. 0 - no commands or help
vdu_StartupText *       vdu_ModuleBase
vdu_GBPB        *       vdu_ModuleBase
vdu_Get         *       vdu_ModuleBase

vdu     FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_vdu

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; rawvdu - notpermanent, alwaysopen, nullok

rawvdu_ModuleBase  *    Module_BaseAddr

rawvdu_Commands    *    rawvdu_ModuleBase ; ie. 0 - no commands or help
rawvdu_StartupText *    rawvdu_ModuleBase
rawvdu_GBPB        *    rawvdu_ModuleBase
rawvdu_Get         *    rawvdu_ModuleBase

rawvdu  FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_rawvdu

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; kbd - notpermanent, alwaysopen, nullok

kbd_ModuleBase  *       Module_BaseAddr

kbd_Commands    *       kbd_ModuleBase ; ie. 0 - no commands or help
kbd_StartupText *       kbd_ModuleBase
kbd_GBPB        *       kbd_ModuleBase
kbd_Put         *       kbd_ModuleBase

kbd     FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_kbd

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; rawkbd - notpermanent, alwaysopen, nullok

rawkbd_ModuleBase  *    Module_BaseAddr

rawkbd_Commands    *    rawkbd_ModuleBase ; ie. 0 - no commands or help
rawkbd_StartupText *    rawkbd_ModuleBase
rawkbd_GBPB        *    rawkbd_ModuleBase
rawkbd_Put         *    rawkbd_ModuleBase

rawkbd  FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_rawkbd

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; printer - specials, notpermanent, alwaysopen, nullok

printer_ModuleBase  *   Module_BaseAddr

printer_Commands    *   printer_ModuleBase ; ie. 0 - no commands or help
printer_StartupText *   printer_ModuleBase
;printer_GBPB        *   printer_ModuleBase
printer_Get         *   printer_ModuleBase

printer FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_printer + fsinfo_special

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; serial - specials, notpermanent, alwaysopen, nullok

  [ export_serial

serial_ModuleBase  *   Module_BaseAddr

serial_Commands    *   serial_ModuleBase ; ie. 0 - no commands or help
serial_StartupText *   serial_ModuleBase
serial_GBPB        *   serial_ModuleBase

serial FSHeader fsinfo_notpermanent + fsinfo_nullnameok + fsinfo_alwaysopen + fsnumber_serial

  ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

NullOptString           DCB     "null:", 0
VduOptString            DCB     "vdu:", 0
RawVduOptString         DCB     "rawvdu:", 0
PrinterOptString        DCB     "printer:", 0
 [ export_serial
SerialOptString         DCB     "serial:",0
 ]

null_Name               DCB     "null", 0
source_Name             DCB     "source", 0
vdu_Name                DCB     "vdu", 0
rawvdu_Name             DCB     "rawvdu", 0
kbd_Name                DCB     "kbd", 0
rawkbd_Name             DCB     "rawkbd", 0
printer_Name            DCB     "printer", 0
 [ export_serial
serial_Name             DCB     "serial", 0
 ]

CloseNullFiles          DCB   "null:close", 0
CloseSourceFiles        DCB   "source:close", 0
CloseVduFiles           DCB   "vdu:close", 0
CloseRawVduFiles        DCB   "rawvdu:close", 0
CloseKbdFiles           DCB   "kbd:close", 0
CloseRawKbdFiles        DCB   "rawkbd:close", 0
ClosePrinterFiles       DCB   "printer:close", 0
  [ export_serial
CloseSerialFiles        DCB   "serial:close", 0
  ]

        MakeErrorBlock  BadFilingSystemOperation

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Let Module handler take care of removing our workspace on fatal death
; Or shunting it around on Tidy - none of it is absolute

SystemDevices_Die Entry "r0-r1"
        LDR     wp, [r12]

        ADR     r0, CloseNullFiles
        ADR     r1, null_Name
        BL      CloseAndRemoveDevice

        ADR     r0, CloseSourceFiles
        ADR     r1, source_Name
        BL      CloseAndRemoveDevice

        ADR     r0, CloseVduFiles
        ADR     r1, vdu_Name
        BL      CloseAndRemoveDevice

        ADR     r0, CloseRawVduFiles
        ADR     r1, rawvdu_Name
        BL      CloseAndRemoveDevice

        ADR     r0, CloseKbdFiles
        ADR     r1, kbd_Name
        BL      CloseAndRemoveDevice

        ADR     r0, CloseRawKbdFiles
        ADR     r1, rawkbd_Name
        BL      CloseAndRemoveDevice

        ADR     r0, ClosePrinterFiles
        ADR     r1, printer_Name
        BL      CloseAndRemoveDevice

  [ export_serial
        ADR     r0, CloseSerialFiles
        ADR     r1, serial_Name
        BL      CloseAndRemoveDevice
  ]

; OSS Close the Messages file if it is open, and then flag it as closed.
; OK so even if it is closed I flag it as closed, but this is hardly speed
; critical code.

        LDR     r0, message_file_open
        TEQ     r0, #0
        ADRNE   r0, message_file_block
        SWINE   XMessageTrans_CloseFile
        MOV     r0, #0
        STR     r0, message_file_open

 [ standalone
        ADRL    R0, resourcefsfiles
        SWI     XResourceFS_DeregisterFiles
 ]
        CLRV
        EXIT                           ; Mustn't refuse to die.

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 -> string to OS_CLI
;       r1 -> fs name

CloseAndRemoveDevice Entry

        SWI     XOS_CLI
        MOV     r0, #FSControl_RemoveFS
        SWI     XOS_FSControl
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Some common routines

; Out   EQ -> ok

CommonArgs_Write Entry

        SavePSR lr
        ORR     lr, lr, #Z_bit
        CMP     r0, #fsargs_EOFCheck    ; EOF always
        MOVEQ   r2, #-1
        RestPSR lr,EQ,f                 ; preserve N - do we really have to do this? grrr.
        EXIT    EQ                      ; EQ
        B       %FT10

CommonArgs ALTENTRY
        SavePSR lr
        ORR     lr, lr, #Z_bit
10
        BIC     lr, lr, #V_bit

        CMP     r0, #fsargs_Flush       ; nop
        CMPNE   r0, #fsargs_EnsureSize  ; nop. r2out = r2in
        RestPSR lr,EQ,f
        EXIT    EQ                      ; EQ

        CMP     r0, #fsargs_ReadLoadExec ; Undated file - don't restamp
        MOVEQ   r2, #0
        MOVEQ   r3, #0
        RestPSR lr,EQ,f
        EXIT    EQ                      ; EQ

        CMP     r0, #fsargs_ReadPTR     ; Return PTR#, EXT#, SizeOf# = 0
        CMPNE   r0, #fsargs_ReadEXT
        CMPNE   r0, #fsargs_ReadSize
        MOVEQ   r2, #0
        CMPNE   r0, #fsargs_SetPTR      ; nop
        CMPNE   r0, #fsargs_SetEXT      ; nop

        EXIT                            ; EQ/NE from above

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   EQ -> ok

CommonFunc Entry
        SavePSR lr
        BIC     lr, lr, #V_bit
        ORR     lr, lr, #Z_bit

        CMP     r0, #fsfunc_ShutDown    ; nop
        CMPNE   r0, #fsfunc_Bootup      ; nop
        RestPSR lr,EQ,f
        EXIT    EQ

        CMP     r0, #fsfunc_ReadDirEntries
        CMPNE   r0, #fsfunc_ReadDirEntriesInfo
        MOVEQ   r3, #0                  ; No files returned
        MOVEQ   r4, #-1                 ; Don't call me again
        MOVEQ   r5, #0                  ; No buffer usage

        EXIT                            ; EQ/NE from above

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Out   EQ -> ok

CommonFile_Write ROUT

        CMP     r0, #fsfile_Create
        CMPNE   r0, #fsfile_CreateDir
        MOVEQ   pc, lr

CommonFile

        CMP     r0, #fsfile_WriteInfo   ; All these must be at least nop
        CMPNE   r0, #fsfile_WriteLoad
        CMPNE   r0, #fsfile_WriteExec
        CMPNE   r0, #fsfile_WriteAttr
        CMPNE   r0, #fsfile_ReadInfo
        CMPNE   r0, #fsfile_Delete      ; allow delete
        MOVEQ   r0, #object_nothing
        MOV     pc, lr                  ; EQ/NE from above

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                          N U L L   S T R E A M
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; null: supports multiple open files, all distinct
; Input streams always return EOF
; Output is always discarded

; In    r0 = op, r1 -> name, r2 = load, r3 = exec, r4 = start, r5 = end

null_File Entry

        addr    r6, NullOptString       ; Filename to return for monitor msg

        CMP     r0, #fsfile_Save        ; nop
        BLNE    CommonFile_Write
        EXIT    EQ

        B       NaffNullOp

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

null_Func Entry

        BL      CommonFunc

null_ArgsFunc

        EXIT    EQ                      ; EQ -> op done ok or nop'ed

; .............................................................................
; Entered with stacked lr

NaffNullOp
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, null_Name
        BL      copy_error_one           ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP

null_Open ROUT

        MOV     r0, #fsopen_WritePermission+fsopen_ReadPermission+fsopen_UnbufferedGBPB
                                        ; Zero devid; unbuffered GBPB for fast
                                        ; byte sink !
        EOR     r1, r3, #fsnumber_null :SHL: 24 ; Munged FileSwitch handle
        MOV     r2, #0                  ; Single byte job

; .............................................................................

null_Close

        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Always return EOF - FileSwitch will suss multiple reads at EOF error

null_Get
        SEC                             ; clears NVZ, sets C
        MOV     pc, lr                  ; EOF

null_GBPB

        ASSERT  OSGBPB_WriteAtGiven < OSGBPB_WriteAtPTR
        CMP     r0, #OSGBPB_WriteAtPTR  ; nop reads (ie. nothing done)
        ADDLS   r2, r2, r3              ; Update memory^ for pedants
        ADDLS   r4, r4, r3              ; Also fileptr for that same crowd
        MOVLS   r3, #0                  ; All done if write / no xfer if read
                                        ; r2-r4 unmodified if reading

null_Put                                ; Discard output
        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

null_Args Entry

        BL      CommonArgs_Write
        B       null_ArgsFunc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                         S O U R C E   S T R E A M
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; source: supports multiple open files, all distinct
; Special field determines which source it is. Currently implemented are
; 'zero'    Input is infinite zeros
; 'random'  Input is from PRNG
; 'urandom' Input is from PRNG
; Output is not permitted

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Open ROUT
        CMP     r0, #fsopen_ReadOnly    ; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP
        BNE     source_OpInvalid

        ADR     r2, source_Specials
10
        LDRB    r4, [r2]                ; Length to match
        TEQ     r4, #0                  ; Give up, end of table
        BEQ     source_OpInvalid
        ADD     r5, r2, #2              ; Start of template
20
        SUBS    r4, r4, #1
        BMI     %FT40
        LDRB    r0, [r5, r4]            ; From table
        LDRB    r1, [r6, r4]            ; From special string
        ASCII_LowerCase r1, r3
        TEQ     r0, r1
        BEQ     %BT20
30
        LDRB    r4, [r2], #2            ; Mismatch, jump to next
        ADD     r2, r2, r4
        B       %BT10
40
        LDRB    r4, [r2]                ; Template match, guard against substrings
        LDRB    r1, [r6, r4]
        TEQ     r1, #0
        TEQNE   r1, #'.'
        TEQNE   r1, #','
        TEQNE   r1, #';'
        BNE     %BT30                   ; No acceptable terminator found

        MOV     r0, #fsopen_ReadPermission + fsopen_UnbufferedGBPB
                                        ; Zero devid, read only, bulk GBPB source of 0's
        LDRB    r1, [r2, #1]            ; Munge special string to a (non zero) sub-FS identifier
        MOV     r2, #0                  ; Unbuffered
        RETURNVC

source_Specials
        DCB     4, 1, "zero"
        DCB     6, 2, "random"
        DCB     7, 3, "urandom"
        DCB     0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Get
        SUBS    r0, r1, #1              ; Which source?
        BEQ     source_GetZero          ; r0 => 0

source_GetRandom
        MOV     r4, lr
        BL      source_Rand
        MOVS    r0, r0, LSR #24
        MOV     lr, r4
        ; Fall through

source_GetZero
        CMP     r0, #256                ; C & V clear
        RETURN
        
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Args Entry
        CMP     r0, #fsargs_EOFCheck    ; Not EOF. Ever
        MOVEQ   r2, #0

        BLNE    CommonArgs
        B       source_OpProcessed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Close
        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_File Entry
        BL      CommonFile              ; Can't do Load/Save/Create
        B       source_OpProcessed      ; so no monitor filename needed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Func Entry
        BL      CommonFunc
        B       source_OpProcessed      ; so no monitor filename needed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_GBPB Entry
        TEQ     r0, #OSGBPB_ReadFromGiven
        TEQNE   r0, #OSGBPB_ReadFromPTR
        PullEnv NE
        BNE     source_OpInvalid        ; Only reads please

        ADD     r4, r4, r3              ; New file pointer
10
        TEQ     r3, #0                  ; Anything to do?
        EXIT    EQ

        SUBS    r0, r1, #1              ; Which source?
        BLNE    source_Rand

        TST     r2, #3
        BNE     %FT20

        CMP     r3, #4
        STRCS   r0, [r2], #4
        SUBCS   r3, r3, #4
        BCS     %BT10
20                                      ; Not aligned or < one word left
        STRB    r0, [r2], #1
        SUB     r3, r3, #1
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

source_Rand
        LDR     r1, SourceRandSeed
        LDR     r2, =1103515245
        LDR     r0, =12345
        MLA     r0, r1, r2, r0          ; ISO9899:1999 7.20.2.2
        STR     r0, SourceRandSeed
        MOV     pc, lr

source_OpProcessed
        EXIT    EQ                      ; EQ -> op done ok or nop'ed
        PullEnv                         ; NE -> make some noise
        
source_OpInvalid
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1, lr"
        addr    r1, source_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                            V D U   S T R E A M S
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; vdu: supports multiple streams
; Input is not permitted
; Output is directed to the screen via OS_WriteC, either filtered or unfiltered

; In    r0 = op, r1 -> name, r2 = load, r3 = exec, r4 = start, r5 = end

vdu_File Entry

        addr    r6, VduOptString        ; Filename to return for monitor msg

        BL      CommonFile_Write
        EXIT    EQ                      ; VClear

        CMP     r0, #fsfile_Save        ; Send block to vdu drivers
        BNE     NaffVduOp

        BL      EnableJustVdu
        EXIT    VS
20      CMP     r4, r5                  ; Finished yet ?
        BEQ     %FT50                   ; VClear
        LDRB    r0, [r4], #1
        BL      vdu_wrch
        BVC     %BT20

50      BL      SelectWrchDest
        EXIT


rawvdu_File ALTENTRY

        addr    r6, RawVduOptString     ; Filename to return for monitor msg

        BL      CommonFile_Write
        EXIT    EQ                      ; VClear

        CMP     r0, #fsfile_Save        ; Send block to vdu drivers
        BNE     NaffRawVduOp

        BL      EnableJustVdu
        EXIT    VS

        MOV     r0, r4                  ; Unfiltered case rather easy
        SUB     r1, r5, r4
        SWI     XOS_WriteN
        B       %BT50

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

vdu_Func Entry

        BL      CommonFunc

vdu_ArgsFunc

        EXIT    EQ                  ; EQ -> op done ok or nop'ed

; otherwise drop thru to...

NaffVduOp                               ; Entered with stacked lr
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, vdu_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawvdu_Func Entry

        BL      CommonFunc

rawvdu_ArgsFunc

        EXIT    EQ                  ; EQ -> op done ok or nop'ed

; otherwise drop thru to...

NaffRawVduOp                            ; Entered with stacked lr
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, rawvdu_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP

; Can only write to the vdu streams, but we can have many streams open at once.

rawvdu_Open

        CMP     r0, #fsopen_ReadOnly
        Push    "lr", EQ
        BEQ     NaffRawVduOp

        EOR     r1, r3, #fsnumber_rawvdu :SHL: 24 ; Munged FileSwitch handle
        B       %FT50

vdu_Open
        CMP     r0, #fsopen_ReadOnly
        Push    "lr", EQ
        BEQ     NaffVduOp

        EOR     r1, r3, #fsnumber_vdu :SHL: 24 ; Munged FileSwitch handle

50      MOV     r0, #fsopen_WritePermission
        MOV     r2, #0                  ; Single byte job

rawvdu_Close
vdu_Close
        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

vdu_Put Entry

        BL      EnableJustVdu
        BLVC    vdu_wrch
        BL      SelectWrchDest
        EXIT                            ; V from wrch


rawvdu_Put Entry

        BL      EnableJustVdu
        SWIVC   XOS_WriteC
        BL      SelectWrchDest
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

vdu_Args Entry

        BL      CommonArgs_Write
        B       vdu_ArgsFunc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawvdu_Args Entry

        BL      CommonArgs_Write
        B       rawvdu_ArgsFunc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Filter + interpret the vdu: stream (much like Panos vdu:)

vdu_wrch Entry

        TEQ     r0, #LF                 ; Have to bodge pairs of these
        TEQNE   r0, #CR
        BEQ     %FT90

        STRB    r0, LastChar
        CMP     r0, #""""               ; Don't display quotes in GSRead though
        CMPNE   r0, #"<"                ; Or left angle
        CMPNE   r0, #FF                 ; CLS ok too
        BEQ     %FT50
        BL      PrintCharInGSFormat
        EXIT

50      SWI     XOS_WriteC
        EXIT

90      LDRB    r14, LastChar           ; NewLine if same as last time eg LF,LF
        TEQ     r14, r0
        BEQ     %FT95

        TEQ     r14, #LF                ; Don't give another NewLine if we've
        TEQNE   r14, #CR                ; had CR,LF or LF,CR
        MOVEQ   r0, #0                  ; Reset st. no more LF/CR get absorbed
        STRB    r0, LastChar
        EXIT    EQ

95      SWI     XOS_NewLine
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0b = char to print using current listopt

; Out   r0 corrupt

listopt RN      r4

forcetbsrange   * 2_00001000
allowtbschar    * 2_00000100
unprintangle    * 2_00000010
unprinthex      * 2_00000001
unprintdot      * 2_00000001

PrintCharInGSFormat Entry "r1, listopt"

        LDRB    listopt, GSFormat
        AND     r0, r0, #&FF    ; Just in case

        TST     listopt, #forcetbsrange ; Forcing tbs into 00..7F ?
        BIC     listopt, listopt, #forcetbsrange
        BICNE   r0, r0, #&80            ; Take top bit out if so

        CMP     r0, #" "        ; Do we need to do this at all ?
        RSBGES  r14, r0, #&7E
        BLT     %FT10           ; LT if not in range &20-&7E
        CMP     r0, #"|"        ; Solidus ? VClear
        CMPNE   r0, #""""       ; Quote ?
        CMPNE   r0, #"<"        ; Left angle ?
        BEQ     %FT10
        SWI     XOS_WriteC      ; Nope, so let's print the char and exit
        EXIT


10      TST     listopt, #allowtbschar  ; International format bit ?
        BIC     listopt, listopt, #allowtbschar
        BEQ     %FT15
        CMP     r0, #&80
        BHS     %FT45                   ; Print tbs char and exit

15      TST     listopt, #unprintangle  ; Angle bracket format ?
        BNE     %FT50

        TST     listopt, #unprintdot    ; Doing unprintable dot format (2_01) ?
        BEQ     %FT16

        CMP     r0, #" "                ; Only space to twiddle are printable
        RSBGES  r14, r0, #&7E
        MOVLT   r0, #"."                ; All others are dot
        B       %FT45                   ; Print char and exit


; Normal BBC GSREAD format (2_00)

16      CMP     r0, #&80                ; Deal with tbs first
        BIC     r0, r0, #&80
        BLO     %FT17
        SWI     XOS_WriteI+"|"
        SWIVC   XOS_WriteI+"!"
        EXIT    VS

17      CMP     r0, #&7F                ; Delete ? -> |?. VClear
        MOVEQ   r0, #"?"
        CMPNE   r0, #""""               ; Quote ? -> |"
        CMPNE   r0, #"|"                ; Solidus ? -> ||
        SWIEQ   XOS_WriteI+"|"
        EXIT    VS
        CMP     r0, #&1F                ; CtrlChar ? -> |<char+@>. VClear
        ADDLS   r0, r0, #"@"
        SWILS   XOS_WriteI+"|"

45      SWIVC   XOS_WriteC              ; Used from above
        EXIT


50 ; Angle bracket format, either hex (2_11) or decimal (2_10)

        SWI     XOS_WriteI+"<"
        TST     listopt, #unprinthex
        BNE     %FT60
        MOV     r1, #0                  ; Strip leading spaces
        BLVC    PrintR0Decimal
        B       %FT70


60      SWIVC   XOS_WriteI+"&"
        BLVC    HexR0Byte
70      SWIVC   XOS_WriteI+">"
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = number to print
;       r1 = 0 -> strip spaces
;            1 -> print leading spaces

; Number gets printed RJ in a field of 4 if possible, or more as necessary

PrintR0Decimal Entry "r0-r3"

        SUB     sp, sp, #16
        MOV     r3, r1                  ; Save flag
        MOV     r1, sp
        MOV     r2, #16
        SWI     XOS_BinaryToDecimal     ; Only error is buffer overflow
        CMP     r3, #0                  ; Doing spaces ?
        RSBNES  r3, r2, #4              ; How many spaces do we need ?
        BLE     %FT10

05      SWI     XOS_WriteI+" "          ; But errors in here are bad
        BVS     %FT99
        SUBS    r3, r3, #1
        BNE     %BT05

10      LDRB    r0, [r1], #1
        SWI     XOS_WriteC
        BVS     %FT99
        SUBS    r2, r2, #1
        BNE     %BT10

99      ADD     sp, sp, #16
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = byte to print

HexR0Byte Entry "r0"

        SUB     sp, sp, #12
        MOV     r1, sp
        MOV     r2, #12
        SWI     XOS_ConvertHex2
        SWIVC   XOS_Write0
        ADD     sp, sp, #12
        STRVS   r0, [sp]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                          K B D   S T R E A M S
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; kbd: takes input from ReadLine using current ReadC source, therefore by using
; fx2,n one may change the i/p source
; rawkbd: forces keyboard + not serial i/p

; In    r0 = op, r1 -> name, r2 = load, r3 = exec, r4 = start, r5 = end

kbd_File Entry

        BL      CommonFile              ; Can't do Load/Save/Create
        B       kbd_ArgsFuncFile        ; so no monitor filename needed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP

; Can only have one stream open to kbd: at once

kbd_Open ROUT

        CMP     r0, #fsopen_ReadOnly
        BNE     NaffKbdOp_nolr

        LDR     r1, KbdHandle           ; Already got a kbd stream ?
        CMP     r1, #0                  ; VClear. Handle zero if already open
        MOVNE   r1, #0
        MOVEQ   r0, #(fsopen_ReadPermission + fsopen_Interactive)
                                        ; Zero devid, read only
        EOREQ   r1, r3, #fsnumber_kbd :SHL: 24 ; Munged FileSwitch handle
        STREQ   r1, KbdHandle
        MOVEQ   r2, #0                  ; Single byte job
        MOVEQ   r3, #-1                 ; Buffer empty
        STREQ   r3, KbdIndex
        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

kbd_Close ROUT

        SUBS    r1, r1, r1              ; Clear handle (R1=0, V cleared)
        STR     r1, KbdHandle
        RETURNVC VC                     ; conditional for optimal code in 32-bit case

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

kbd_Get Entry "r1-r4"

        LDR     r14, KbdIndex           ; Is there a valid buffer ?
        CMP     r14, #-1
        BNE     %FT50

        ADR     r0, KbdBuffer           ; Get a line of input. Dont' prompt
        MOV     r1, #?KbdBuffer-1       ; (that's up to the punter)
        MOV     r2, #0
        MOV     r3, #&FF
        SWI     XOS_ReadLine
        EXIT    VS
        BLCS    SAckEscape
        EXIT    VS                      ; Null line = single byte (CR) read

        MOV     r14, #CR                ; Force lineterm = CR
        STRB    r14, [r0, r1]
        ADD     r1, r1, #1              ; Consider lineterm as part of sequence
        STR     r1, KbdLength
        MOV     r14, #0                 ; Initial index = 0

50      ADR     r0, KbdBuffer
        LDRB    r0, [r0, r14]           ; Get char
        CMP     r0, #4                  ; if EOF then don't increment index
        BEQ     %FT60                   ; but do store back in case we dropped thru to 50

        ADD     r14, r14, #1            ; Index +:= 1
        LDR     r1, KbdLength
        CMP     r14, r1                 ; Finished buffer ?
        MOVEQ   r14, #-1                ; then mark buffer empty
60
        STR     r14, KbdIndex           ; update index

        CMP     r0, #4                  ; VClear, CSet if EOF read (^D)
        CMPNE   r0, #&100               ; VClear, CClear if not EOF
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SAckEscape Entry "r1"

        MOV     r0, #OsByte_AcknowledgeEscape
        SWI     XOS_Byte
        ADRVC   r0, ErrorBlock_Escape
        MOVVC   r1, #0                  ; No %0
        BLVC    copy_error_one          ; Always sets the V bit
        EXIT

        MakeErrorBlock Escape

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

kbd_Args Entry

        CMP     r0, #fsargs_EOFCheck
        BNE     %FT10

        MOV     r2, #0                  ; EOF iff char at PTR is ^D
        LDR     r14, KbdIndex           ; -> must have a valid buffer !
        CMP     r14, #-1
        EXIT    EQ                      ; ~EOF

        ADR     r0, KbdBuffer
        LDRB    r14, [r0, r14]
        CMP     r14, #4
        MOVEQ   r2, #-1
        EXIT


10      BL      CommonArgs
        B       kbd_ArgsFuncFile

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

kbd_Func Entry

        BL      CommonFunc

kbd_ArgsFuncFile

        EXIT    EQ                  ; EQ -> op done ok or nop'ed

; .............................................................................
; Entered with stacked lr

NaffKbdOp

        PullEnv

; .............................................................................
; Entered with unstacked lr

NaffKbdOp_nolr

        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1, lr"
        addr    r1, kbd_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawkbd_File Entry

        BL      CommonFile              ; Can't do Load/Save/Create
        B       rawkbd_ArgsFuncFile     ; so no monitor filename needed

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Can have multiple files open on rawkbd:

rawkbd_Open ROUT

        CMP     r0, #fsopen_ReadOnly    ; VClear
        BNE     NaffRawKbdOp_nolr

        MOV     r0, #(fsopen_ReadPermission + fsopen_Interactive)
                                        ; Zero devid, read only
        EOR     r1, r3, #fsnumber_rawkbd :SHL: 24 ; Munged FileSwitch handle
        MOV     r2, #0                  ; Single byte job

; .............................................................................

rawkbd_Close

        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawkbd_Get Entry

        BL      EnableJustKbdRead
        EXIT    VS
        SWI     XOS_ReadC
        BVS     %F90
        BLCS    SAckEscape
90
        SavePSR r1
        BL      SelectRdchSrc
        RestPSR r1,,f                   ; V from before / OSByte
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawkbd_Args Entry

        CMP     r0, #fsargs_EOFCheck    ; Not EOF. Ever
        MOVEQ   r2, #0

        BLNE    CommonArgs
        B       rawkbd_ArgsFuncFile

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

rawkbd_Func Entry

        BL      CommonFunc

rawkbd_ArgsFuncFile

        EXIT    EQ                  ; EQ -> op done ok or nop'ed

; .............................................................................
; Entered with stacked lr

NaffRawKbdOp

        PullEnv

; .............................................................................
; Entered with unstacked lr

NaffRawKbdOp_nolr

        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1, lr"
        addr    r1, rawkbd_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                      P R I N T E R   S T R E A M
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; printer: only one stream is available; osfiles are not permitted when this
; stream is being used. Printer type is assumed to be preserved
; Input is not permitted
; Output is sent to the printer by OS_PrintChar
;
; In    r0 = op, r1 -> name, r2 = load, r3 = exec, r4 = start, r5 = end, r6=sp

printer_File Entry ; lr only

        MOV     r7, r6
        addr    r6, PrinterOptString    ; Filename to return for monitor msg

        BL      CommonFile_Write
        EXIT    EQ                      ; VClear

        CMP     r0, #fsfile_Save        ; Send block to printer drivers
        BNE     NaffPrinterOp

 [ {FALSE}
        SWI     XOS_WriteS
        =       "OS_File Save on Printer:, special field = '", 0
        ALIGN
        MOVS    r0, r7
        SWINE   XOS_Write0
        SWI     XOS_WriteS
        =       "'", 10, 13, 0
        ALIGN
 ]
        BL      SussSpecialPrinter      ; Select type by name, if present
        BLVC    SussPrinterVar          ; does printer var exist?
        EXIT    VS
        BNE     filetovar

        LDR     r0, PrinterHandle       ; Printer in use ?
        CMP     r0, #0
        BNE     %FT90

        STR     r1, PrinterType         ; now safe to set up printer type
        BL      SelectPrinterType
50
        CMP     r4, r5                  ; Finished yet ? VClear if so
        BEQ     %FT60
        LDRB    r0, [r4], #1
        SWI     XOS_PrintChar
        BVC     %BT50

60      BL      EndPrinterJob
        EXIT

filetovar
        MOV     r0, #OSFile_Save        ; use OS_File to save file
        ADR     r1, FilenameBuffer      ; r1 -> filename
        SWI     XOS_File                ; r2-r5 as passed to us
        EXIT                            ; return any errors generated

90
        ADR     r0, ErrorBlock_PrinterInUse
        Push    "r1"
        ADRL    r1, printer_Name        ; make error "The filing system printer: is already in use"
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

        MakeInternatErrorBlock PrinterInUse,,"FSInUse"  ; does an ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

printer_Func Entry

        BL      CommonFunc

printer_ArgsFunc

        EXIT    EQ

; .............................................................................
; Entered with stacked lr

NaffPrinterOp
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, printer_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP

printer_Open Entry ; lr only

        CMP     r0, #fsopen_ReadOnly
        BEQ     NaffPrinterOp

; Can only write to the printer stream

        MOV     r7, r6
        BL      SussSpecialPrinter      ; Select type by name
        BLVC    SussPrinterVar          ; can we use fast printer var stuff?
        EXIT    VS

        BNE     printer_OpenFast        ; use fast transfer system

printer_OpenSlow
        LDR     r0, PrinterHandle       ; Already got a printer stream?
        CMP     r0, #0                  ; VClear. Handle non-zero if already open
        MOVNE   r1, #0
        EXIT    NE

        STR     r1, PrinterType
        BL      SelectPrinterType
        MOV     r0, #fsopen_WritePermission ; Zero devid, write only
        EOR     r1, r3, #fsnumber_printer :SHL: 24 ; Munged FileSwitch handle
        STR     r1, PrinterHandle
        MOV     r2, #0                  ; Single byte job
        EXIT

printer_OpenFast
        MOV     r0, #open_write         ; create for output
        ADR     r1, FilenameBuffer      ; r1 -> filename
        SWI     XOS_Find
        EXIT    VS

        MOVS    r1, r0, LSL #8          ; handle in b8->15
        ORRNE   r1, r1, r3              ; munge with file switch one
        ORRNE   r1, r1, #fsnumber_printer :SHL:24
        MOVNE   r2, #0                  ; r2 =0, not a buffered file
        MOVNE   r0, #fsopen_WritePermission+fsopen_UnbufferedGBPB

        EXIT                            ; return ack home now....

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

printer_Close Entry

        ANDS    r14, r1, #&FF00         ; special file object?
        BNE     printer_CloseFile

        MOV     r14, #0                 ; Clear handle
        STR     r14, PrinterHandle

        BL      EndPrinterJob
        EXIT

printer_CloseFile
        MOV     r0, #0                  ; r0  =0, close file
        MOV     r1, r14, LSR #8         ; r1  =handle
        SWI     XOS_Find
        EXIT                            ; V setup already, r0 from SWI *maybe error ->*

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

printer_Put Entry

        ANDS    r1, r1, #&FF00          ; file specified?
        BNE     printer_PutToObject

        SWI     XOS_PrintChar
        EXIT

printer_PutToObject
        MOV     r1, r1, LSR #8
        SWI     XOS_BPut                ; yes, so r1 = handle, r0 =byte
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; GBPB handling for the unbuffered system devices module.
;
; in:  r0 = reason (only 2 allowed!)   r1 = file handle, r2 -> start address, r3 = number of bytes
;

printer_GBPB Entry

        TEQ     r0, #OSGBPB_WriteAtPTR  ; only write with no pointer supported!
        BNE     NaffPrinterOp

        AND     r1, r1, #&FF00
        MOV     r1, r1, LSR #8          ; r1  = handle for object
        SWI     XOS_GBPB

        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

printer_Args Entry

        BL      CommonArgs_Write
        B       printer_ArgsFunc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

EndPrinterJob Entry "r0-r3"

 [ debug
 DLINE "EndPrinterJob"
 ]
        SavePSR r3
        MOV     r0, #OsByte_PrinterDormant ; End job
        SWI     XOS_Byte                   ; Note that this doesn't wait
                                           ; till all bytes are out, that's fx5

        BL      SelectPrinterType
        BICVC   r3, r3, #V_bit
        ORRVS   r3, r3, #V_bit
        STRVS   r0, [sp]
        RestPSR r3
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Try to match the appropriate printer

; In    r7 -> special field or 0 (NB. NOT r6 !!!)
; Out   r1 = printer type (or -1 for don't change)
;       NB NOT stored in PrinterType cos this may hold the old FX5 value to restore
;       if we've got a slow stream open at the time

SussSpecialPrinter Entry "r0,r2-r4, r6"

 [ debug
 DSTRING r7,"SussSpecialPrinter: r7 "
 ]
        ADDS    r6, r7, #0              ; Don't change if no special field (NB V:=0)
        MOVEQ   r1, #-1                 ; Not changing. VClear
        BEQ     %FT50                   ; Note this please

        LDRB    r1, [r6]                ; Is it numeric ?
        CMP     r1, #"&"
        BEQ     %FT80
        CMP     r1, #"0"
        RSBCSS  r14, r1, #"9"
        BCS     %FT70

; Special field is non-numeric

        ADR     r0, printer_Types       ; Point to first name in list

10      MOV     r2, r6                  ; Restore search name each time

15      LDRB    r1, [r0], #1            ; Get char from stored name
        TEQ     r1, #&FF                ; Ended all stored names ?
        BEQ     %FT80
        LDRB    r3, [r2], #1            ; Get char from special buffer
        CMP     r1, #" "                ; Ended both names together ?
        CMPLS   r3, #0
        BLS     %FT50                   ; Found it if so
        LowerCase r3, r4                ; Name stored Lowercased
        CMP     r1, r3                  ; Loop if still matching
        BEQ     %BT15

        SUB     r0, r0, #1              ; Point back one char in stored name
20      LDRB    r1, [r0], #1            ; Skip to start of next stored name
        CMP     r1, #" "
        BHI     %BT20
        B       %BT10                   ; r0 -> next name to try

50
        STRVS   r0, [sp]
        EXIT

; Special field is a number

70      MOV     r0, #10 + (2_110 :SHL: 29) ; No bad terms, restrict to byte
        MOV     r1, r6
        SWI     XOS_ReadUnsigned
        MOVVC   r1, r2
        B       %BT50


80      ADR     r0, ErrorBlock_UKPrinterType
        MOV     r1, r7                  ; %0 -> type that was Unknown
        BL      copy_error_one          ; Sets V flag always
        B       %BT50

        MakeInternatErrorBlock UKPrinterType, NOALIGN, E01

printer_Types ; Allow expansion (may need extra synonyms, for instance)

        DCB     "null",       0
        DCB     "sink",       0
        DCB     "parallel",   1
        DCB     "centronics", 1
        DCB     "rs423",      2
        DCB     "serial",     2
        DCB     "user",       3

; no printer#net: - use netprint: instead!

        DCB     &FF             ; End of table
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SussPrinterVar.
;
; This routine will suss the given printer variable,, eg. it will look
; for a printer variable for the current printer destination.  Once it
; has found this any routine interested in performing anytype of
; output should then indirect to the returned filename.
;
; EQ => filename not found, use original approach.
; NE => FilenameBuffer contains data => filename found and expanded.
;
; in:   r1 = printer type to try
;

SussPrinterVar ROUT

        Push    "r0-r4, lr"

        SavePSR lr
        Push    lr

        ADR     r0, varprefix           ; r0 -> start of variable name
        ADR     r1, FilenameBuffer      ; r1 -> filename buffer

00      LDRB    r2, [r0], #1
        TEQ     r2, #0                  ; any more characters?
        STRNEB  r2, [r1], #1
        BNE     %00                     ; loop until the complete thing copied

        LDR     r0, [sp, #1*4]          ; r0  = printer type (stacked r1)
        CMP     r0, #-1                 ;       not specified in special field?
        BNE     %10

        Push    "r1"

        MOV     r0, #OsByte_RW_PrinterDriver
        MOV     r1, #0
        MOV     r2, #&FF
        SWI     XOS_Byte
        MOV     r0, r1                  ; r0 => printer type

        Pull    "r1"                    ; preserve r1, -> string to concatinate with

10      MOV     r2, #8                  ; r2  = 8, max size of expanded var
        SWI     XOS_ConvertCardinal1

        ADRVC   r0, FilenameBuffer      ; r0 -> var in buffer
        MOVVC   r1, r0                  ; r1 -> return buffer
        MOVVC   r2, #255                ; r2  = size of buffer
        MOVVC   r3, #0                  ; r3  = 0, first read
        MOVVC   r4, #VarType_Expanded
        SWIVC   XOS_ReadVarVal
        MOVVC   lr, #0
        STRVCB  lr, [r1, r2]            ; terminate 'cos not already

        MOVVS   r2, #0                  ; if went wrong assume no system var
        TEQ     r2, #0                  ; did it exist?

        Pull    lr
        BIC     lr, lr, #V_bit :OR: Z_bit ; ensure V=0.
        ORREQ   lr, lr, #Z_bit
        RestPSR lr,,f
        Pull    "r0-r4, pc"

varprefix
        = "PrinterType$",0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Input source setups. Should preserve flags + r0 unless error

SelectRdchSrc Entry "r0-r2"

        SavePSR r0
        Push    r0
        LDRB    r1, RdchSrc
        TEQ     r1, #0
        MOVEQ   r1, #2                  ; Must set back to 2 as 0 is silly

05      MOV     r0, #OsByte_SpecifyInputStream
        SWI     XOS_Byte
        STRVCB  r1, RdchSrc

10      STRVS   r0, [sp]
        Pull    r0
        ORRVS   r0, r0, #V_bit
        BICVC   r0, r0, #V_bit
        RestPSR r0,,f
        EXIT


EnableJustKbdRead ALTENTRY

        SavePSR r1
        Push    r1
        MOV     r1, #0                  ; Enable kbd i/p only
        B       %BT05

EnableJustSerialRead ALTENTRY

        SavePSR r1
        Push    r1
        MOV     r1, #1                  ; Enable serial i/p only
        B       %BT05

; .............................................................................
; Output destination setups. Should preserve flags + r0 unless error

SelectWrchDest ALTENTRY

        LDRB    r1, WrchDest

25      SavePSR r0
        Push    r0
        MOV     r0, #OsByte_SpecifyOutputStream
        SWI     XOS_Byte
        STRVCB  r1, WrchDest

        B       %BA10


EnableJustVdu ALTENTRY

        MOV     r1, #2_00010100         ; Enable vdu o/p only
        B       %BA25

EnableJustSerial ALTENTRY

        MOV     r1, #2_00010111         ; Enable serial o/p only
        B       %BA25

; .............................................................................
; Printer type setup. Should preserve flags + r0 unless error

SelectPrinterType ALTENTRY

        SavePSR r0
        LDR     r1, PrinterType         ; Did we alter the printer type ?
 [ debug
 DREG r1,"SelectPrinterType ",,Integer
 ]
        CMP     r1, #-1
        BNE     %FT90
        RestPSR r0,,f
        EXIT

90
        Push    r0
        MOV     r0, #OsByte_PrinterDriver
        SWI     XOS_Byte
 [ debug
 DREG r1, "OSByte(5) returns ",,Integer
 ]
        STRVC   r1, PrinterType
        B       %BA10


  [ export_serial

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;                        R S 4 2 3   S T R E A M S
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In:   r0 = op, r1 -> name, r2 = load, r3 = exec, r4 = start, r5 = end

serial_File Entry

        addr    r6, SerialOptString     ; Filename to return for monitor msg

        BL      CommonFile_Write
        EXIT    EQ                      ; VClear

        CMP     r0, #fsfile_Save        ; Send block to serial drivers
        BNE     NaffSerialOp

40      CMP     r4, r5                  ; Finished yet ? VClear if so
        EXIT    EQ

        LDRB    r1, [r4], #1
        MOV     r0, #3                  ; Send byte to rs423, waking Tx process
50      SWI     XOS_SerialOp
        EXIT    VS
        BCS     %BT50                   ; [buffer full, try again]
        B       %BT40

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

serial_Func Entry

        BL      CommonFunc

serial_ArgsFunc

        EXIT    EQ

; .............................................................................
; Entered with stacked lr

NaffSerialOp
        addr    r0, ErrorBlock_BadFilingSystemOperation
        Push    "r1"
        addr    r1, serial_Name
        BL      copy_error_one          ; Will set the V bit
        Pull    "r1, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 0 -> OPENIN, 1 -> OPENOUT, 2 -> OPENUP

; Side effect is to enable rs423 input

serial_Open Entry

; All open modes are valid on the serial stream

        MOV     r0, #OsByte_SpecifyInputStream    
        MOV     r1, #2                  ; Set FX2,2 state (ie rs423 enable)
        SWI     XOS_Byte
        EXIT    VS

        CMP     r1, #1                  ; If we were in FX2,1, set that back
        SWIEQ   XOS_Byte
        EXIT    VS

        MOV     r0, #fsopen_WritePermission + fsopen_ReadPermission
                                        ; Zero devid
        EOR     r1, r3, #fsnumber_serial :SHL: 24 ; Munged FileSwitch handle
        MOV     r2, #0                  ; Single byte job
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

serial_Close

        RETURNVC

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

serial_Get Entry

10      MOV     r0, #4                  ; Get byte from rs423
        SWI     XOS_SerialOp
        EXIT    VS
        BCS     %BT10                   ; [loop till char ready]
        MOV     r0, r1
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

serial_Put Entry

        MOV     r1, r0
        MOV     r0, #3                  ; Send byte to rs423, waking Tx process
50      SWI     XOS_SerialOp
        EXIT    VS
        BCS     %BT50                   ; [buffer full, try again]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

serial_Args Entry

        CMP     r0, #fsargs_EOFCheck    ; Not EOF. Ever
        MOVEQ   r2, #0

        BLNE    CommonArgs
        B       serial_ArgsFunc

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  ]

        GET     MsgCode.s

 [ debug
        InsertDebugRoutines
 ]

 [ standalone
resourcefsfiles
        ResourceFile $MergedMsgs, Resources.SystemDevs.Messages
        DCD     0
 ]
        END
