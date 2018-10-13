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
; -> CDFS module

;*****************************************************************
;                   Procedures in this file
;*****************************************************************

; initialisingcode     ; Start up as a filing system
; finalisingcode       ; Kill filing system and claimed RMA space
; servicecode          ; Service call handler
; registerFS           ; Register module as a filing system
; InformationBlock     ; Block used by FileSwitch

;*****************************************************************
;                       Include other files
;*****************************************************************

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:MsgTrans
        GET     Hdr:ModHand
        GET     Hdr:Free
        GET     Hdr:FSNumbers
        GET     Hdr:FileTypes
        GET     Hdr:HighFSI
        GET     Hdr:LowFSI
        GET     Hdr:Services
        GET     Hdr:Variables
        GET     Hdr:OsBytes
        GET     Hdr:MimeMap
        GET     Hdr:CDROM
        GET     Hdr:CDErrors
        GET     Hdr:CMOS
        GET     Hdr:HostFS
        GET     Hdr:UpCall
        GET     Hdr:Proc
        GET     Hdr:NdrDebug
        GET     hdr.Options             ; Link in options
        GET     hdr.Hashes              ; Link in hash define file
        GET     hdr.MyMacros            ; Link in macro file
        GET     hdr.CDFS
        GET     VersionASM              ; Date/version strings

;*****************************************************************
;                       MODULE HEADER
;*****************************************************************

        AREA    |CDFS$$Code|, CODE, READONLY, PIC
        ENTRY

Module_BaseAddr

        DCD     0
        DCD     initialisingcode - Module_BaseAddr
        DCD     finalisingcode - Module_BaseAddr
        DCD     servicecode - Module_BaseAddr
        DCD     title - Module_BaseAddr
        DCD     help - Module_BaseAddr
        DCD     KeywordTable - Module_BaseAddr
        DCD     CDROMFSSWI_Base
        DCD     CDFSSWIentry - Module_BaseAddr
        DCD     CDFStableofswinames - Module_BaseAddr
        DCD     0                       ; decoding code
      [ international_help
        DCD     message_filename - Module_BaseAddr
      |
        DCD     0                       ; international help
      ]
        DCD     ModuleFlags - Module_BaseAddr

message_filename
        ; CANNOT USE CDFS$Path 'cause it screws up *dir cdfs::0
        DCB     "CDFSMessages:Messages", 0
Path
        DCB     "CDFSMessages$$Path", 0
PathDefault
        DCB     "Resources:$.Resources.CDFS."
PathDefaultEnd
        ALIGN

ModuleFlags
        DCD     ModuleFlag_32bit

;-----------------------------------------------------------------------------------------------
initialisingcode ROUT
;
; on entry:
;          R10 -> enviroment string ( see page 631 )
;          R11 = I/O base or instantiation number
;          R12 -> currently preferred instantiation of module
;          R13 -> supervisor stack
;
; on exit:
;         must preserve R7 - R11, and R13, forget the rest
;
;-----------------------------------------------------------------------------------------------

        Push    "r14"

;----------------------------------------------------------
; initialise CDFSMessages$Path if not already done
;----------------------------------------------------------

        ADR     r0, Path                
        MOV     r2, #-1                 
        MOV     r3, #0                  
        MOV     r4, #VarType_Expanded                  
        SWI     XOS_ReadVarVal          ; returns R2=0 if doesn't exist
        CMP     r2, #0                  ; clears V as well!
                                        
        ADREQ   r0, Path                
        ADREQ   r1, PathDefault         
        MOVEQ   r2, #PathDefaultEnd - PathDefault       
        MOVEQ   r3, #0                  
        MOVEQ   r4, #VarType_String                  
        SWIEQ   XOS_SetVarVal           

;-----------------------------------------------------------------------------------------------
; Read configured number of drives.
;-----------------------------------------------------------------------------------------------

        MOV     r0, #OsByte_ReadCMOS
        MOV     r1, #CDROMFSCMOS        ; Cmos RAM location
        SWI     XOS_Byte                ; R2 = contents of location

      [ CheckConfiguredDrives
        TST     r2, #BITSUSEDBYDRIVENUMBER

        BNE     %FT00

        SUB     r13, r13, #16           ; local buffer for MessageTrans file descriptor
        MOV     r0, r13                 ; open message file
        ADR     r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile

        ADRVCL  r0, noconfigureddrives_tag ; lookup error (or use error from OpenFile)
        MOVVC   r1, r13
        SWIVC   XMessageTrans_ErrorLookup

        MOV     r1, r0                  ; at this point we definitely have an error of some sort
        MOV     r0, r13
        SWI     XMessageTrans_CloseFile
        MOV     r0, r1                  ; ignore any error from CloseFile

        ADD     r13, r13, #16           ; free buffer and return error (don't start up)
        SETV
        Pull    "pc"
00
      ]

        MOV     r6, r2

;-----------------------------------------------------------------------------------------------
; Claim space from RMA for workspace
;-----------------------------------------------------------------------------------------------

        MOV     r0, #ModHandReason_Claim
        LDR     r3, =SIZEOFRMA          ; Amount of memory required
        SWI     XOS_Module
        MOVVS   r4, r0
        BVS     kill_filing_system

        STR     r2, [ r12 ]             ; Save it in the private word

        MOV     r12, r2

;-----------------------------------------------------------------------------------------------
; Clear the reserved memory
;-----------------------------------------------------------------------------------------------

        MOV     r1, #0                  ; R1 = Wiper
        MOV     r0, r12                 ; R0 -> Start of wipe
        LDR     r3, =SIZEOFRMA          ; R3 -> end of wipe
        ADD     r3, r3, r12             
03                                      
        STR     r1, [r0], #4            
        CMP     r0, r3                  
        BLE     %BT03                   

;----------------------------------------------------------
; Set up MessageTrans expecting the CDSFSResources module
; to have put the files into ResourceFS
;----------------------------------------------------------

        ADR     r0, message_block
        ADR     r1, message_filename
        MOV     r2, #0
        SWI     XMessageTrans_OpenFile
        MOVVS   r4, r0
        BVS     free_workspace

;--------------------------------------------------------------------------
; Extract the buffer value from the CMOS byte
;--------------------------------------------------------------------------

        AND     r0, r6, #BITSUSEDBYBUFFER

        MOV     r0, r0, LSR #BUFFERSHIFT


        ; First find out how big the buffer size is

        BL      ConvertBufferSizeToReal ; R0 = bit size, RETURNS R1 = number of K


        TEQ     r1, #0                  ; If no memory is needed then do not claim it
        MOVEQ   r1, #6                  ; Cheat - claim a minimum amount of 6K
                                        
        MOV     r5, r1                  ; preserve R1
                                        
        MOV     r3, r1, ASL #10         ; R1 = number of K * 1024 = number of bytes
        STR     r3, discbuffersize

        MOV     r0, #6

        SWI     XOS_Module              ; R0 = 6, R3 = amount required
                                        ; RETURNS R2 -> claimed block
                                        
        MOVVS   r2, #0                  ; If cannot get memory then use 0 buffers
        STRVS   r2, discbuffersize      ; ( Display message )
        BVS     display_no_buffers      ;

        STR     r2, discbufferpointer
        STR     r2, disclastpointer

;--------------------------------------------------------------------------
; Clear the disc buffer space ; R2 -> start, R3 = length, R14 = temp
;--------------------------------------------------------------------------

        ADD     r3, r3, r2              ; R3 -> end of space
        MOV     r14, #0                 ; R14 = wiper
02                                      
        STR     r14, [r2], #4
        CMP     r2, r3                  
        BLT     %BT02                   

;--------------------------------------------------------------------------
; Claim space for pointers  ( length depends on size of configured buffer )
;--------------------------------------------------------------------------

; R5 = size of cache in K

        MOV     r3, r5, ASL #2
        STR     r3, maxnumberofbuffers

; R3 = ( size_of_cache_in_K * 4 * 3 * 2 ) + 4 just in case
;    = ( R5 * 8 * 3 ) + 4

; R5 = 32
; R3 = 32 * 8 = 256
; R3 = 256 * 3 = 768
; R3 = 768 + 4 = 772

      [ SIZEOFBUFFERENTRY<>16
        ! 0, " See 'Main' "
      ]

        MOV     r3, r5, ASL #6          ; xK * 4 * 16
        
        ADD     r3, r3, #SIZEOFBUFFERENTRY + 4
        
        MOV     r0, #6
        
        SWI     XOS_Module              ; R3 = total size of cache required
        MOVVS   r4, r0
        BVS     free_disc_cache
        
        STR     r2, pointerToBufferList
        
        
        ADD     r3, r3, r2
        MOV     r4, #0
        MOV     r1, r2
04      
        STR     r4, [r1], #4
        CMP     r1, r3
        BLT     %BT04

no_disc_buffer

;--------------------------------------------------------------------------
; Read the configure option, if 0 drives configured, then look for one
;--------------------------------------------------------------------------

;----------------------------------
; Seperate byte in CMOS from number
;----------------------------------

        ANDS    r0, r6, #BITSUSEDBYDRIVENUMBER

        STR     r0, maxnumberofdrives

;----------------------------------
; Set module up as a filing system
;----------------------------------

        BL      registerFS
        MOVVS   r4, r0
        BVS     free_pointer_list

;------------------------------
; Register with the Free module
;------------------------------
        MOV     r0, #fsnumber_CDFS
        ADRL    r1, Free_Entry
        MOV     r2, r12
        SWI     XFree_Register
        ; It's not fatal if this produces an error

;---------------------------------------------------
; Set disc has changed value for all possible drives
;---------------------------------------------------

        Push    "r7"                    ; SMC: Don't want to corrupt r7, do we!

        ADR     r7, sparecontrolblock
        MOV     r6, #0
01
        SWI     XCD_DiscHasChanged
        ADD     r6, r6, #1
        AND     r2, r6, #2_111          ; R2 = device number
        MOV     r3, r6, ASR #3          ; R3 = card number
        AND     r3, r3, #2_11
        MOV     r4, r6, ASR #5          ; R4 = LUN
        AND     r4, r4, #2_11
        STMIA   r7, { r2, r3, r4 }
        CMP     r6, #2_1111111          ; If device =7,LUN=3,card=3 THEN end
        BLE     %BT01

        Pull    "r7"

      [ log
        ADRL    R14, log_memory
        STR     R14, log_pointer
      ]

;----------------------------------
; Check for presence of RISC_OS 3.0
;----------------------------------

        ADR     r0, rmensure
        SWI     XOS_CLI                 ; No error, so must be OK (?) !!!
                                        
        MOV     r0, #2                  ; default of 0 for RISC OS 2, and 2 for RISC OS 3+                  
        STRVCB  r0, truncation
        MOVVS   r0, #1
        STRVCB  r0, max_truncation

;----------------------------------------------------------
; Set the PhotoCD file type to read 'PhotoCD'
;----------------------------------------------------------

        ADR     r0, photocd_filetype
        SWI     XOS_CLI

;----------------------------------------------------------
; End Initialisation process
;----------------------------------------------------------
        CMP     R0,#0
        Pull    "pc"

;----------------------------------------------------------

photocd_filetype
        DCB     "Set File$$Type_BE8 PhotoCD", 0

rmensure
        DCB     "RMENSURE UtilityModule 3.00", 0
        ALIGN
        
;*****************
display_no_buffers
; If the disc buffer space not available
; Then print a message and use 0 buffers
;*****************

        ADRL    r0, nospace_tag
        ADR     r1, message_block
        MOV     r2, #0
        SWI     XMessageTrans_ErrorLookup
        ADD     r0, r0, #4
        SWI     XOS_Write0
                
        SWI     XOS_NewLine
                
        SWI     XOS_ReadMonotonicTime   ; RETURNS R0 = time in centi-seconds since
                                        ; last hard reset
        ADD     R1, R0, #2*100
06
        SWI     XOS_ReadMonotonicTime   ; RETURNS R0 = time in centi-seconds since
                                        ; last hard reset
        CMP     R0, R1
        BLT     %BT06

        B       no_disc_buffer


;-----------------------------------------------------------------------------------------------
finalisingcode ROUT
;
; on entry:
;          r4  = 0 or -> error block ( may have jumped in from InitialisationCode )
;          R10 = fatality indicator, 0 = non-fatal, 1 = fatal
;          R11 = instantiation number
;          R12 -> private word
;          R13 -> supervisor stack
;
; on exit:
;          R7 - R11 and R13 must be preserved, forget the rest
;-----------------------------------------------------------------------------------------------

        Push    "r14"
        MOV     r4, #0
        LDR     r12, [ r12 ]

;----------------------------------------------------------
; Close the message trans file for RISC OS 3
; added: 9-June-93 for CDFS v 2.16
;----------------------------------------------------------

        ADR     r0, message_block
        SWI     XMessageTrans_CloseFile

;--------------------------------
; Deregister from the Free module
;--------------------------------
        MOV     r0, #fsnumber_CDFS
        ADRL    r1, Free_Entry
        MOV     r2, r12
        SWI     XFree_DeRegister

;----------------------------------------------------------
; free the pointer list - if it was claimed
;----------------------------------------------------------
free_pointer_list

        LDR     r14, discbuffersize
        TEQ     r14, #0
        MOVNE   r0, #ModHandReason_Free
        LDRNE   r2, pointerToBufferList
        SWI     XOS_Module              ; R0 = 7, R2 -> RMA to free

;----------------------------------------------------------
; free the disc cache space
;----------------------------------------------------------
free_disc_cache

        LDR     r14, discbuffersize
        TEQ     r14, #0
        MOVNE   r0, #ModHandReason_Free
        LDRNE   r2, discbufferpointer
        SWI     XOS_Module              ; R0 = 7, R2 -> RMA to free

;--------------------------------------------------------------------------
; free the workspace
;--------------------------------------------------------------------------
free_workspace

        MOV     r0, #ModHandReason_Free
        MOV     r2, r12
        SWI     XOS_Module              ; R0 = 7, R2 -> RMA to free

;--------------------------------------------------------------------------
; Kill module as a filing system
;--------------------------------------------------------------------------
kill_filing_system

        MOV     r0, #FSControl_RemoveFS
        ADRL    r1, FilingSystemName
        SWI     XOS_FSControl

;--------------------------------------------------------------------------
; Exit returning error
;--------------------------------------------------------------------------

        MOVS    r0, r4                  ; Tell about the error
        Pull    "pc", EQ
        SETV
        Pull    "pc"

;--------------------------------------------------------------------------
ServiceTable
        DCD     0                       ; flag word
        DCD     serviceursula - Module_BaseAddr
        DCD     Service_FSRedeclare
        DCD     0
        DCD     ServiceTable - Module_BaseAddr

servicecode ROUT
;
; on entry:
;          r1 = service call reason code
;          other registers service call specific
;
; on exit:
;          r1 = 0 (service claimed) or preserved (service not claimed)
;          other registers service call specific
;--------------------------------------------------------------------------
        MOV     r0,r0                   ; nop to indicate service table present
        TEQ     r1, #Service_FSRedeclare
        MOVNE   pc, lr

serviceursula
        LDR     r12, [r12]
        ; Drop through to...

;--------------------------------------------------------------------------
registerFS ROUT
;
; Register our filing system.
;--------------------------------------------------------------------------

        Push    "r0-r3,lr"
                
        MOV     r0, #FSControl_AddFS
        addr    r1, Module_BaseAddr
        ADR     r2, InformationBlock
        SUB     r2, r2, r1
        MOV     r3, r12                 ; Passed in R12 when call to filing system
        SWI     XOS_FSControl
                
        Pull    "r0-r3,pc"

;--------------------------------------------------------------------------
;        This next block is used by FileSwitch

; All of the routines are held in the file 'FileMan'
;--------------------------------------------------------------------------

InformationBlock

        DCD     FilingSystemName - Module_BaseAddr              ; &00
        DCD     StartUpText - Module_BaseAddr                   ; &04
        DCD     OpenFile - Module_BaseAddr                      ; &08
        DCD     GetByte - Module_BaseAddr                       ; &0c
        DCD     PutByte - Module_BaseAddr                       ; &10
        DCD     ControlOpenFile - Module_BaseAddr               ; &14
        DCD     CloseFile - Module_BaseAddr                     ; &18
        DCD     WholeFile - Module_BaseAddr                     ; &1c
        DCD     FS_INFORMATIONWORD                            ; &20
        DCD     FSOperations - Module_BaseAddr                  ; &24
        DCD     0                                             ; &28  GBPB not supported
      [ (FS_INFORMATIONWORD :AND: fsinfo_extrainfo) = 0 
        DCD     FS_EXTRAINFORMATIONWORD                       ; &2c
      ]

; Not part of Information Block

        GET     Args.s                  ; deals with FSEntry_Args (ControlFile)
        GET     Strings.s               ; Any old string
        GET     Misc.s                  ; Deals with miscellaneous *COMMANDS
        GET     DiscOp.s                ; Deals with most disc operations
        GET     FileMan.s               ; Handles file operations - See keyword table
        GET     Filer.s                 ; Routines called by 'FileMan'
        GET     Directory.s             ; move to and cat directory
        GET     EntryFile.s             ; deals with FSEntry_File
        GET     Open.s                  ; deals with open / close extras
        GET     SWI.s                   ; deals with the SWI CDFS_...
        GET     Error.s                 ; Deals with errors from SWI XCD_...
        GET     Tables.s                ; Unchanging tables
        GET     StarHelp.s              ; RISC OS 3 Contains *help routines
        GET     WordTable3.s            ; RISC OS 3 Contains keyword table ( *CDFS, *PLAY ... )
        GET     Variables.s             ; Layout of variables in workspace
        GET     ByteCopy.s
        GET     Free.s                  ; Support for Free module

      [ debug
        InsertNDRDebugRoutines
      ]

        LTORG

        END


