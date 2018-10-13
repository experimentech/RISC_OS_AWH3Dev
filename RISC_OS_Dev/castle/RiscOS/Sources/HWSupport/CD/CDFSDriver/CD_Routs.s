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
; -> CD_Routs














; This contains the general routines that all soft drivers may use (if they're lazy)



















; Routines in here:
;                  cd_checkdrive
;                  cd_control
;                  cd_converttolba
;                  cd_converttomsf
;                  cd_discused
;                  cd_driveready
;                  cd_drivestatus
;                  cd_inquiry
;                  cd_lasterror
;                  cd_opendrawer
;                  cd_prefetch
;                  cd_readdata
;                  cd_readuserdata
;                  cd_reset
;                  cd_seekto
;                  cd_stopdisc
;                  cd_version


;-----------------------------------------------------------------------------------------------
cd_version ROUT
;
; on entry:
;          nothing needed
; on exit:
;          r0 -> version string ( word 0 = version number * 100, word 1 .. = null term. string )
;
;-----------------------------------------------------------------------------------------------

 ADR       r0, VersionMessage
 STR       r0, [sp, #0*4]
 SWIExitVC

VersionMessage DCD Module_Version
                 = "$Module_FullVersion", " CD_SWI control module by Eesox", 0
 ALIGN

;-----------------------------------------------------------------------------------------------
cd_lasterror ROUT
;
; on entry:
;          nothing needed
; on exit:
;          r0 = number of last error, or 0 if none
;
;-----------------------------------------------------------------------------------------------

 LDR       r0, LastErrorNumber
 STR       r0, [sp, #0*4]
 SWIExitVC



;-----------------------------------------------------------------------------------------------
cd_prefetch ROUT
;
; on entry:
;          r0 =   addressing mode
;          r1 =   block number
;          r7 ->  control block
; on exit:
;          if error then r0-> error block, else all regs preserved
;
;-----------------------------------------------------------------------------------------------
 MOV       r2, #1
 ADR       r3, buffer + 32
 MOV       r4, #1      ; Allow to run on

;-----------------------------------------------------------------------------------------------
cd_readdata ROUT
;
; on entry:
;          r0 =   addressing mode
;          r1 =   block number
;          r2 =   number of blocks
;          r3 ->  where to put data
;          r4 =   number of bytes from each block wanted
;          r7 ->  control block
;          r12 -> my workspace
;          r13 -> full descending stack
; on exit:
;          if error then r0-> error block, else all regs preserved
;
;-----------------------------------------------------------------------------------------------

; r8  = scsi device id
; r9  = card number
; r10 = lun

 Push      "r0-r4"

 Debug "cd_readdata",NL

01

 LDMIA     r7, { r8, r9, r10 }


 MUL       r4, r2, r4

;---------------------
; Set up the cdb block
;---------------------
 MOV       r5, #&28
 ORR       r5, r5, r10, LSL #8+5
 MOV       r6, r2, LSR #8         ; Number of blocks
 MOV       r6, r6, LSL #24        ;
 AND       r14, r2, #255          ;
 ADR       r2, buffer
 STMIA     r2, { r5, r6, r14 }



; R0 = address mode, R1 = address, RETURNS R1 = address

 BL        ConvertToLBA

;------------------
; put in start pos
;------------------
 STRVCB    r1, buffer + 5
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 4
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 3
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 2


;--------------------
; Do the SCSI command
;--------------------
 ORRVC     r0, r8, r9,  LSL #3                 ; card number
 ORRVC     r0, r0, r10, LSL #5                 ; lun
 ORRVC     r0, r0, #escapepolloff + readdata   ; prevent 'escape key'

; r1 = size of cdb
 MOVVC     r1, #10

; r2 -> cdb

; r3 -> put data here

; r4 = number of bytes returned

 MOVVC     r5, #0

 MOVVC     r8, #1

 SWIVC     XSCSI_Op

 Pull      "r1-r5"

 SWIExitVC VC


 LDR       r6, [ r0 ]


;-----------------------------------------------
; If the error is 'Busy' because playing audio
; then StopDisc and try again
;-----------------------------------------------
 LDR       r14, =Busy
 TEQ       r6, r14
 BNE       %FT80
 Push      "r1-r5"
 SWI       XCD_StopDisc
 LDMFD     r13, { r0 - r4 }
 B         %BT01

80

;-----------------------------------------------
; If the error is "Illegal Request", "DataProtect" or "Blank check"
; THEN make it WrongDataMode
;-----------------------------------------------
 LDR       r14, =IllegalRequest
 SUBS      r6, r6, r14
 SUBNES    r6, r6, #(DataProtect - IllegalRequest)
 SUBNES    r6, r6, #(BlankCheck  - DataProtect)
 addr      r0, WrongDataMode, EQ
;-----------------------------------------------
 BEQ       error_handler_lookup
 B         error_handler

;-----------------------------------------------------------------------------------------------
cd_seekto ROUT
;
; on entry:
;          r0 =   addressing mode
;          r1 =   block number
; on exit:
;          if error then r0-> error block, else all regs preserved
;
;-----------------------------------------------------------------------------------------------


 Push      "r0-r1"

 Debug "cd_seekto",NL

01

 LDMIA     r7, { r8, r9, r10 }


;---------------------
; Set up the cdb block
;---------------------
 MOV       r4, #&2b
 ORR       r4, r4, r10, LSL #8+5
 MOV       r5, #0
 MOV       r6, #0
 ADR       r2, buffer
 STMIA     r2, { r4, r5, r6 }



; R0 = address mode, R1 = address, RETURNS R1 = address

 BL        ConvertToLBA

;------------------
; put in start pos
;------------------
 STRVCB    r1, buffer + 5
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 4
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 3
 MOVVC     r1, r1, LSR #8
 STRVCB    r1, buffer + 2


;--------------------
; Do the SCSI command
;--------------------
 BLVC      space_saver

; r1 = size of cdb
 MOVVC     r1, #10

; r2 -> cdb

; r4 = number of bytes returned
 MOVVC     r4, #0

 SWIVC     XSCSI_Op

 Pull      "r1-r2"

 SWIExitVC VC

;-----------------------------------------------
; If the error is 'Busy' because playing audio
; then StopDisc and try again
;-----------------------------------------------
 LDR       r14, =Busy
 LDR       r6, [ r0 ]
 TEQ       r6, r14
 BNE       error_handler
 Push      "r1-r2"
 SWI       XCD_StopDisc
 LDMFD     r13, { r0 - r1 }
 B         %BT01

;-----------------------------------------------------------------------------------------------
cd_inquiry ROUT
;
; on entry:
;          r0 -> place to put the inquiry data
;          r7 -> control block
; on exit:
;
;-----------------------------------------------------------------------------------------------

 Debug "cd_enquiry",NL

; r3 -> store here
 MOV       r6, r0

 BL        space_saver

 MOV       r3, r6

;--------------------------------
; SCSI Inquiry command
;--------------------------------
 ORR       r0, r0, #escapepolloff + readdata   ; prevent 'escape key'

 ADR       r14, cdb_inquiry
 LDMIA     r14, { r4, r5 }
 ORR       r4, r4, r10, LSL #8+5
 STMIA     r2, { r4, r5 }

 MOV       r4, #36

 MOV       r5, #0

 SWI       XSCSI_Op

 BVS       error_handler

 SWIExitVC

;-----------------------------------------------------------------------------------------------
cd_discused ROUT
;
; on entry:
;          r0 =  addressing mode that the disc length should be returned in
;          r1 -> storage area to put data in
;          r7 -> control block
; on exit:
;
;-----------------------------------------------------------------------------------------------

; r3 -> store here

;--------------------------------
; SCSI ReadCapacity command
;--------------------------------

 Debug "cd_discused",NL

 BL        space_saver

 ORR       r0, r0, #escapepolloff + readdata   ; prevent 'escape key'

 MOV       r1, #10

 MOV       r4, #&25
 ORR       r4, r4, r10, LSL #8+5
 MOV       r6, #0
 STMIA     r2, { r4, r5, r6 }

 ADR       r3, buffer + 12

 MOV       r4, #8

 SWI       XSCSI_Op

 BVS       error_handler

;----------------------------------------------
; Convert the disc length into the correct mode
;----------------------------------------------

; get r0 and r1 original values
 LDMFD     r13, { r0-r11, r14 }

 ADR       r5, buffer + 12
 LDMIA     r5, { r3, r6 }

 MOV       r5, #255
 ORR       r5, r5, r5, LSL #16

 AND       r2, r5, r3, ROR #24         ; CHANGE REGISTER FROM MSB/LSB TO LSB/HSB
 AND       r4, r5, r3
 ORR       r2, r2, r4, ROR #8          ; R2 = number of blocks on a disc

 AND       r7, r5, r6, ROR #24         ; CHANGE REGISTER FROM MSB/LSB TO LSB/HSB
 AND       r4, r5, r6
 ORR       r7, r7, r4, ROR#8           ; R7 = size of a block


 STR       r7, [ r1, #4 ]

; If not in mode 0 then convert to other
 TEQ       r0, #LBAFormat
 ADDNE     r2, r2, #( MaxNumberOfBlocks + 1 ) * 2 + 1     ; ie point to lead out address

 TEQ       r0, #MSFFormat
 STRNE     r2, [ r1 ]
 SWIExitVC NE



;------------------------
; Convert from LBA to MSF
;------------------------
 MOV       r0, #LBAFormat
 MOV       r3, r1
 MOV       r1, r2

 BL        ConvertToMSF

 BVS       error_handler

; save the important bits in the users area
 STR       r1, [ r3 ]

 SWIExitVC

;-----------------------------------------------------------------------------------------------
cd_driveready ROUT
;
; on entry:
;          r7 -> control block
; on exit:
;          r0 = 0 if drive is OK, else r0 = 1
;
;-----------------------------------------------------------------------------------------------

 Debug "cd_driveready",NL

; r3 -> store here

;--------------------------------
; SCSI TestUnitReady command
;--------------------------------
 BL        space_saver

 MOV       r4, r10, LSL #8+5
 STMIA     r2, { r4, r5 }

 MOV       r4, #8

 SWI       XSCSI_Op

 MOVVC     r0, #0
 STRVC     r0, [sp, #0*4]
 SWIExitVC VC

;------------------------------------------
; If UnitAttention then update disc changed
;------------------------------------------
 LDR       r1, [ r0 ]
 LDR       r2, =UnitAttention
 TEQ       r2, r1
 LDRNE     r2, =CheckCondition
 TEQNE     r2, r1
 BEQ       error_handler

;------------------------------------------
 MOV       r0, #1
 STR       r0, [sp, #0*4]
 SWIExitVC

;-----------------------------------------------------------------------------------------------
cd_stopdisc ROUT
;
; on entry:
;          r7 -> control block
; on exit:
;          usual error stuff
;
;-----------------------------------------------------------------------------------------------

 Debug "cd_stopdisc",NL

;--------------------------------
; SCSI Stop disc command
;--------------------------------
 BL        space_saver

 MOV       r4, #&1b
 ORR       r4, r4, r10, LSL #8+5
 STMIA     r2, { r4, r5 }

 MOV       r4, #0

 SWI       XSCSI_Op

 BVS       error_handler

 SWIExitVC


;-----------------------------------------------------------------------------------------------
cd_opendrawer ROUT
;
; on entry:
;          r7 -> control block
; on exit:
;          usual error stuff
;
;-----------------------------------------------------------------------------------------------

 Debug "cd_opendrawer",NL

;--------------------------------
; SCSI Start/Stop unit command
;--------------------------------
 BL        space_saver

 MOV       r4, #&1b
 ORR       r4, r4, r10, LSL #8+5
 MOV       r14, #2
 STMIA     r2, { r4, r14 }

 MOV       r4, #8

 SWI       XSCSI_Op

 SWIExitVC VC

;--------------------------------------------------
; If Illegal Request then the drawer must be locked
;--------------------------------------------------
 LDR       r1, [ r0 ]
 LDR       r2, =IllegalRequest
 TEQ       r1, r2
 addr      r0, DrawerLocked, EQ
 BEQ       error_handler_lookup
 B         error_handler

;-----------------------------------------------------------------------------------------------
cd_converttolba ROUT
; on entry:
;          r0 = address mode
;          r1 = address
; on exit:
;          if oVerflow set then r0 -> error block
;          r1 = new address
;
;-----------------------------------------------------------------------------------------------

 BL        ConvertToLBA

 BVS       error_handler

 STR       r1, [ r13, #4 ]

 SWIExitVC


;-----------------------------------------------------------------------------------------------
cd_converttomsf ROUT
; on entry:
;          r0 = address mode
;          r1 = address
; on exit:
;          if oVerflow set then r0 -> error block
;          r1 = new address
;
;-----------------------------------------------------------------------------------------------

 BL        ConvertToMSF

 BVS       error_handler

 STR       r1, [ r13, #4 ]

 SWIExitVC


;-----------------------------------------------------------------------------------------------
cd_drivestatus ROUT
;
; on entry:
;          r7 -> control block
; on exit:
;          r0 = status { 1=OK, 2=BUSY, 4=NOTREADY, 8=UNAVAILABLE }
;-----------------------------------------------------------------------------------------------

 Debug "cd_drivestatus",NL

; r3 -> store here

;--------------------------------
; SCSI TestUnitReady command
;--------------------------------
 BL        space_saver

 MOV       r4, r10, LSL #8+5
 STMIA     r2, { r4, r5 }

 MOV       r4, #8

 SWI       XSCSI_Op

;---------------
; Everything OK
;---------------

 MOVVC     r0, #1
 STRVC     r0, [sp, #0*4]
 SWIExitVC VC

;---------------------
; What error occured ?
;---------------------
 LDR       r1, [ r0 ]

; Not ready
 LDR       r14, =NotReady
 SUBS      r14, r1, r14
 SUBNES    r14, r14, #&201d0 - NotReady    ; Unknown error
 MOVEQ     r0, #4
 STREQ     r0, [sp, #0*4]
 SWIExitVC EQ

; Busy
 LDR       r14, =Busy
 TEQ       r1, r14
 LDRNE     r14, =NoSense
 TEQNE     r1, r14
 MOVEQ     r0, #2
 STREQ     r0, [sp, #0*4]
 SWIExitVC EQ

; No drive - unavailable
 LDR       r14, =ErrorNumber_SCSI_Timeout
 TEQ       r1, r14
 MOVEQ     r0, #8
 STREQ     r0, [sp, #0*4]
 SWIExitVC EQ

;-----------------
; Some other error
;-----------------
 B         error_handler


;-----------------------------------------------------------------------------------------------
cd_control ROUT
;
; on entry:
;          r0 = 0, 1 or 2 to set the level of error response
;          r7 -> control block
; on exit:
;          usual error stuff
;-----------------------------------------------------------------------------------------------
;--------------------
; Only 0 to 2 allowed
;--------------------
 CMP       r0, #2
 addr      r0, InvalidParameter, CS
 BCS       error_handler_lookup

 MOV       r2, r0

 LDMIA     r7, { r1, r3, r8 }
 ORR       r1, r1, r3, LSL #3
 ORR       r1, r1, r8, LSL #5

 MOV       r0, #4
 MOV       r8, #accesskey
 SWI       XSCSI_Control

 BVS       error_handler

 SWIExitVC


;-----------------------------------------------------------------------------------------------
cd_reset ROUT
;
; on entry:
;          r7 ->  control block
; on exit:
;          if error then r0-> error block, else all regs preserved
;
;-----------------------------------------------------------------------------------------------

 LDMIA     r7, { r1, r2, r3 }

 ORR       r1, r1, r2, LSL #3
 ORR       r1, r1, r3, LSL #5

 MOV       r0, #1

 MOV       r8, #1

 SWI       XSCSI_Initialise

 BVS       error_handler

 SWIExitVC


;-----------------------------------------------------------------------------------------------
cd_checkdrive ROUT
;
; on entry:
;          r7 -> control block
; on exit:
;          usual error stuff
;          r0 = drive status bits
;-----------------------------------------------------------------------------------------------

 Debug "cd_checkdrive",NL

;--------------------------------
; SCSI SendDiagnostics command
;--------------------------------
 BL        space_saver

 MOV       r4, #&1d
 ORR       r4, r4, r10, LSL #8+5
 ORR       r4, r4, #1:SHL:10
 STMIA     r2, { r4, r5 }

 MOV       r4, #0

 SWI       XSCSI_Op

;-------------------------
; Is it a hardware error ?
;-------------------------
 TEQVC     r0, r0
 LDRVS     r1, [ r0 ]
 LDRVS     r2, =HardwareError
 TEQVS     r1, r2

 BNE       error_handler     ; [ no ]

;-------------------------

 MOVVC     r0, #0
 MOVVS     r0, #15
 STR       r0, [sp, #0*4]
 SWIExitVC

;-----------------------------------------------------------------------------------------------
cd_scsiuserop ROUT
;
; on entry:
;          r0-r5 as for SCSI_Op (but no device info in R0)
;          r7 -> control block
; on exit:
;          usual error stuff
;-----------------------------------------------------------------------------------------------

 Debug "cd_scsiuserop",NL

 LDMIA     r7, { r8, r9, r10 }
 ORR       r0, r0, r8                          ; device
 ORR       r0, r0, r9,  LSL #3                 ; card number
 ORR       r0, r0, r10, LSL #5                 ; lun
 ORR       r0, r0, #escapepolloff              ; prevent 'escape key'
 MOV       r8, #1

 SWI       XSCSI_Op

 BVS       error_handler_manyregs

 SWIExitVC

;-----------------------------------------------------------------------------------------------
cd_readuserdata ROUT
;
; The purpose of this call: is to load just user data from mode 2 form 1 or 2 blocks.  This
; part will also work out if it is possible to use a 'complex' scatter list method to improve
; performance.
;
; on entry:
;          r0 =  addressing mode (0, 1 or 2)
;          r1 =  start block
;          r2 =  number of bytes to load (also indicates size of 'r3' buffer)
;          r3 -> put data here
;          r4 =  byte offset in start block to start from
;          r7 -> control block
; on exit:
;          usual error stuff
;          r1 =  last block loaded
;          r4 =  byte offset in last block of next byte
;-----------------------------------------------------------------------------------------------

;---------------------------------------------
; Does this SCSI card support scatter lists ?
;---------------------------------------------

 B         cd_readuserdata_plain

;---------------------------------------------
; Convert block to logical block address
;---------------------------------------------

; BL        ConvertToLBA
; BVS       error_handler

;-----------------------------------------------------------------------------------------------
cd_readuserdata_plain ROUT
;
; The purpose of this call: is to load just user data from mode 2 form 1 or 2 blocks.  This
; 'plain' method will use normal CD_ReadData commands.  SCSI and non-SCSI drives should work
; this way.
;
; on entry:
;          r0 =  addressing mode
;          r1 =  start block
;          r2 =  number of bytes to load (also indicates size of 'r3' buffer)
;          r3 -> put data here
;          r4 =  byte offset in start block to start from
;          r7 -> control block
; on exit:
;          usual error stuff
;          r1 =  last block loaded
;          r4 =  byte offset in last block of next byte
;-----------------------------------------------------------------------------------------------

;---------------------------------------------
; Convert block to logical block address
;---------------------------------------------

 BL        ConvertToLBA
 BVS       error_handler



 [ debug=ON
 Debug     "StartBlock = &"
 MOV       r6, r1
 DebugDisplay r6
 SWI XOS_NewLine
 Debug     "StartByte = &"
 DebugDisplay r4
 SWI XOS_NewLine
 Debug     "NBytes = &"
 DebugDisplay r2
 SWI XOS_NewLine
 ]


 MOV       r6, r4
 MOV       r4, r1
 MOV       r5, r3

; r0 =
; r1 =
; r2 =  number of bytes to load
; r3 =
; r4 =  block
; r5 -> memory
; r6 =  byte offset in first block
; r7 -> control block


; Alogorithm:
;            REPEAT
;                work out number of blocks that can be loaded
;                load the number of blocks
;                shuffle blocks
;            UNTIL <= 1 block left to load
;
;            Load last block into my buffer
;            Copy out last bytes


RUDP_Repeat
;----------------------
;            REPEAT
;----------------------

;------------------------------------------------------------------
;                work out number of bytes storage space available
;------------------------------------------------------------------
 MOV       r10, r2

;------------------------------------------------------------------
;                work out number of blocks that can be loaded
;------------------------------------------------------------------
 LDR       r9, =mode2datasize
 DivRem    r8, r10, r9, r14

 TEQ       r8, # 0
 BEQ       RUDP_LastBlock

;------------------------------------------------------------------
;                load the number of blocks
;------------------------------------------------------------------

;          r0 =   addressing mode
;          r1 =   block number
;          r2 =   number of blocks
;          r3 ->  where to put data
;          r4 =   number of bytes from each block wanted
;          r7 ->  control block

 Push      "r1 - r5"

 MOV       r0, # LBAFormat
 MOV       r1, r4
 MOV       r2, r8
 MOV       r3, r5
 LDR       r4, =mode2datasize

 SWI       XCD_ReadData

 Pull      "r1 - r5"

 BVS       error_handler

;------------------------------------------------------------------
;                shuffle blocks
;------------------------------------------------------------------

; r0  =
; r1  =  memory to copy from
; r2  =  memory to copy to
; r3  =  USERDATA_MODE2FORM2
; r4  =  block
; r5  -> memory to copy to
; r6  =  number of blocks left to shuffle
; r7  -> control block
; r8  =  mode2datasize
; r9  =  number of bytes loaded
; r10 =  byte offset in first block

 Push      "r0-r4, r6-r8, r10"

 MOV       r10, r6
 MOV       r6, r8

 LDR       r8, =mode2datasize

 ADD       r1, r5, # MODE2__TOTALHEADERSIZE
 ADD       r1, r1, r10
 MOV       r2, r5

 MOV       r9, # 0

RUDP_ShuffleBlocks

 MOV       r4, # USERDATA__MODE2FORM1

; Is the data in mode 2 form 2 ?
 SUB       r14, r1, r10
 LDRB      r14, [ r14, # (MODE2__HEADER_SIZE + MODE2__SUB_HEADER_SUBMODE) - MODE2__TOTALHEADERSIZE ]
 TST       r14, # SUBMODE__FORM
 ADDNE     r4, r4, # USERDATA__MODE2FORM2 - USERDATA__MODE2FORM1



 SUB       r3, r4, r10

 BL        cd_bytecopyinternal

 ADD       r1, r1, r8
 SUB       r1, r1, r10

 ADD       r2, r2, r3


; count number of bytes copied
 ADD       r9, r9, r3

 MOV       r10, # 0

 SUBS      r6, r6, # 1
 BGT       RUDP_ShuffleBlocks

 MOV       r5, r2

 Pull      "r0-r4, r6-r8, r10"

 MOV       r6, # 0

; r0 =  drive number
; r1 =
; r2 =  number of blocks
; r3 =
; r4 =  block
; r5 -> memory
; r6 =  byte offset in block to start from (0 at the moment)
; r7 -> control block


 Debug " CopiedLots = &"
 DebugDisplay r9


 ADD       r4, r4, r8
 SUB       r2, r2, r9

;------------------------------------------------------------------
;            UNTIL <= 1 block left to load
;------------------------------------------------------------------

 LDR       r14, =mode2datasize
 CMP       r2, r14
 BGT       RUDP_Repeat

;------------------------------------------------------------------
;            Load last block into my buffer
;------------------------------------------------------------------
RUDP_LastBlock

;------------------------------------------------------------------
;            Copy out last bytes
;------------------------------------------------------------------

 Push      "r0-r4"

 SUBS      r9, r2, #0 ; clears V, also equivalent to CMP r2, #0

 MOV       r0, # LBAFormat
 MOV       r1, r4
 MOV       r2, # 1
 ADR       r3, buffer
 LDR       r4, =mode2datasize

;          r0 =   addressing mode
;          r1 =   block number
;          r2 =   number of blocks
;          r3 ->  where to put data
;          r4 =   number of bytes from each block wanted
;          r7 ->  control block

 SWIGT     XCD_ReadData
 BVS       error_handler

; r1 =  memory to copy from (buffer + 12 + byte offset)
 ADR       r1, buffer + MODE2__TOTALHEADERSIZE

; r2 =  memory to copy to
 MOV       r2, r5



 MOV       r14, # USERDATA__MODE2FORM1

; Is the data in mode 2 form 2 ?
 LDRB      r3, [ r1, # (MODE2__HEADER_SIZE + MODE2__SUB_HEADER_SUBMODE) - MODE2__TOTALHEADERSIZE ]
 TST       r3, # SUBMODE__FORM
 ADDNE     r14, r14, # USERDATA__MODE2FORM2 - USERDATA__MODE2FORM1




 SUB       r14, r14, r6

 ADD       r1, r1, r6

 CMP       r9, r14
 MOVGT     r9, r14

; r3 =  2324 - byte offset, or bytes left to copy, whichever is smaller
 MOVS      r3, r9

 ADD       r5, r5, r3

 BLGT      cd_bytecopyinternal

 Pull      "r0-r4"


 SUBS      r2, r2, r9
 MOVGT     r6, # 0
 ADDGT     r4, r4, # 1
 BGT       RUDP_LastBlock


; return values
;          r1 =  last block loaded
;          r4 =  byte offset in last block of next byte

 ADDS      r9, r9, r6

 LDR       r14, =USERDATA__MODE2FORM2

 MOVEQ     r9, r14

 CMP       r9, r14
 MOVGE     r9, # 0
 ADDGE     r4, r4, # 1
 ADDLT     r9, r9, # 1
 STR       r9, [ r13, # 4*4 ]
 STR       r4, [ r13, # 4*1 ]


 [ debug=ON
 SWI XOS_NewLine
 SWI XOS_NewLine
 ]


 SWIExitVC



;-----------------------------------------------------------------------------------------------
cd_seekuserdata ROUT
;
; The purpose of this call is to find where a particular byte of user data starts in a
; consecutive number of mode 2 form 1 or 2 blocks.  The drive is not expected to seek or load
; any information, just report at what block, and what offset the byte occurs.  This will try
; to use a SCSI scatter list to improve performance.
;
; on entry:
;          r0 =  addressing mode (0, 1 or 2)
;          r1 =  start block (starting from byte 0 of this block)
;          r2 =  byte offset to search for (first position is 0)
;          r7 -> control block
; on exit:
;          usual error stuff
;          r1 =  block found at (in addressing mode of r0 on entry)
;          r2 =  byte offset in block
; all other registers preserved
;-----------------------------------------------------------------------------------------------

;---------------------------------------------
; Does this SCSI card support scatter lists ?
;---------------------------------------------

 B         cd_seekuserdata_plain

;---------------------------------------------
; Convert block to logical block address
;---------------------------------------------

; BL        ConvertToLBA
; BVS       error_handler

;-----------------------------------------------------------------------------------------------
cd_seekuserdata_plain ROUT
;
; The purpose of this call is to find where a particular byte of user data starts in a
; consecutive number of mode 2 form 1 or 2 blocks.  The drive is not expected to seek or load
; any information, just report at what block, and what offset the byte occurs.  Being 'plain'
; it has to make do with current CD_ SWIs so that SCSI and non-SCSI commands work.
;
; on entry:
;          r0 =  addressing mode (0, 1 or 2)
;          r1 =  start block (starting from byte 0 of this block)
;          r2 =  byte offset to search for (first position is 0)
;          r7 -> control block
; on exit:
;          usual error stuff
;          r1 =  block found at (in addressing mode of r0 on entry)
;          r2 =  byte offset in block
; all other registers preserved
;-----------------------------------------------------------------------------------------------

;---------------------------------------------
; Convert block to logical block address
;---------------------------------------------

 BL        ConvertToLBA
 BVS       error_handler


;-------------------------------------------------------------------
; Byte offset of less than 2048 means it must be in the first block
;-------------------------------------------------------------------
 CMP       r2, # USERDATA__MODE2FORM1
 SWIExitVC LT


;---------------------------------------------
; Assume mode 2 form 2 ?
;---------------------------------------------

 LDR       r3, =USERDATA__MODE2FORM2
 DivRem    r4, r2, r3, r14

 ADD       r1, r1, r4

; r0 = addressing format
; r1 = block
; r2 = byte offset

 TEQ       r0, # MSFFormat
 MOVEQ     r0, # LBAFormat
 BLEQ      ConvertToMSF

 TEQ       r0, # PBFormat
 ADDEQ     r1, r1, # 75*2

 STR       r1, [ r13, # 4*1 ]
 STR       r2, [ r13, # 4*2 ]

 SWIExitVC



;-----------------------------------------------------------------------------------------------
; Routine to load default values and save space
;-----------------------------------------------------------------------------------------------
space_saver ROUT
 LDMIA     r7, { r8, r9, r10 }

 ORR       r0, r8, r9,  LSL #3                 ; card number
 ORR       r0, r0, r10, LSL #5                 ; lun
 ORR       r0, r0, #escapepolloff + nodata     ; prevent 'escape key'
 MOV       r1, #6
 ADR       r2, buffer
 MOV       r3, #0
 MOV       r5, #0
 MOV       r8, #1

 MOV       pc, r14





;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------





 END
