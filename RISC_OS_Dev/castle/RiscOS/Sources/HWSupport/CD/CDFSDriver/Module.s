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
; -> module















; This contains the following routines:

; initialisingcode
; finalisingcode















;-----------------------------------------------------------------------------------------------
initialisingcode ROUT
; on entry:
;          r10 -> enviroment string ( see page 631 )
;          r11 = I/O base or instantiation number
;          r12 -> currently preferred instantiation of module ( private word )
;          r13 -> supervisor stack
; on exit:
;
;
;        Set up variables with default values
;-----------------------------------------------------------------------------------------------

 Push       r14

;-----------------------------------------------------------------------------------------------
; Read and check configured number of drives.
;-----------------------------------------------------------------------------------------------

 [ CheckConfiguredDrives=ON

         MOV         r0, #OsByte_ReadCMOS
         MOV         r1, #CDROMFSCMOS        ; Cmos RAM location
         SWI         XOS_Byte                ; R2 = contents of location

         TST         r2, #BITSUSEDBYDRIVENUMBER
         BNE         %FT00

         SUB         r13, r13, #16              ; local buffer for MessageTrans file descriptor
         MOV         r0, r13                    ; open message file
         ADRL        r1, message_file_name
         MOV         r2, #0
         SWI         XMessageTrans_OpenFile

         ADRVCL      r0, NoConfiguredDrive      ; lookup error (or use error from OpenFile)
         MOVVC       r1, r13
         SWIVC       XMessageTrans_ErrorLookup

         MOV         r1, r0                     ; at this point we definitely have an error of some sort
         MOV         r0, r13
         SWI         XMessageTrans_CloseFile
         MOV         r0, r1                     ; ignore any error from CloseFile

         ADD         r13, r13, #16              ; free buffer and return error (don't start up)
         VSET
         Pull        pc
00

 ]

;----------------------------
; Check for re-initialisation
;----------------------------
 LDR        r1, [ r12 ]
 TEQ        r1, #0
 BLNE       FreeWorkspace


;----------------------------
; Claim space from RMA
;----------------------------

 MOV        r0, #ModHandReason_Claim
 LDR        r3, =SizeOfWorkSpace
 SWI        XOS_Module

 Pull       pc, VS


 STR        r2, [ r12 ]

 MOV        r12, r2

;----------------------------
; Clear workspace
;----------------------------

 MOV        r1, #0

clear_workspace
 STR        r1, [ r2 ], #4
 SUBS       r3, r3, #4
 BGT        clear_workspace


;----------------------------------------------------
; Claim the Unknown SWI vector - trap for CD_Register
;----------------------------------------------------
 MOV        r0, #&18      ; unknown swi vector
 ADR        r1, unknown_swi_handler
 MOV        r2, r12
 SWI        XOS_Claim

;-------------------------------------------------
; Look for soft-loadable drivers and rmreinit them
;-------------------------------------------------
; r1 =  loop count
; r3 -> module name
; r4 -> CDFSSoft

 MOV        r1, #0
 MOV        r2, #0

more_modules
 MOV        r0, #ModHandReason_GetNames
 SWI        XOS_Module        ; r1 incremented
 BVS        no_more

; compare the name of the module with the name 'CDFSSoft'
 ADR        r4, CDFSSoft
 MOV        r5, #?CDFSSoft
 LDR        r0, [ r3, #&10 ]
 ADD        r3, r3, r0
 MOV        r6, r3
01
 LDRB       r0,  [ r6 ], #1


 LDRB       r14, [ r4 ], #1
 TEQ        r0, r14
 MOVNE      r5, #1
 SUBS       r5, r5, #1
 BNE        %BT01


 TEQ        r0, r14
 BNE        more_modules

;--------------------
; Rmreinit the module
;--------------------
 MOV        r4, r1

 MOV        r0, #ModHandReason_ReInit
 MOV        r1, r3
 SWI        XOS_Module

 MOV        r1, r4

 B          more_modules


no_more

;-------------------------------------------------
; Release the Unknown SWI vector
;-------------------------------------------------
 MOV        r0, #&18      ; unknown swi vector
 ADR        r1, unknown_swi_handler
 MOV        r2, r12
 SWI        XOS_Release

;-------------------------------------------------
 VCLEAR
 Pull       pc


CDFSSoft = "CDFSSoft"
 ALIGN

;-----------------------------------------------------------------------------------------------
finalisingcode
FreeWorkspace  ROUT
;
; on entry:
;          r12 -> private word
;          r13 -> Full descending stack
; on exit:
;          r0-r2, r14 corrupted
;
;        Set up variables with default values
;-----------------------------------------------------------------------------------------------

 MOV        r6, r14


;-----------------------------------------------------------------------------
; Move through the list of soft-load modules and decrease the registered count ??
; I probably don't need to 'cause next time this is loaded the soft-loads are reinitted
;-----------------------------------------------------------------------------


;---------------------------------------------------------------------------
; Free workspace - don't report an error 'cause that really screws things up
;---------------------------------------------------------------------------
 MOV        r0, #ModHandReason_Free
 LDR        r2, [ r12 ]
 SWI        XOS_Module

 VCLEAR
 MOV        pc, r6


;-----------------------------------------------------------------------------------------------
unknown_swi_handler ROUT
;
; on entry:
;           r0 - r8 = SWI parameters
;           r11     = SWI number
; on exit:
;
;
; This traps the SWI CD_Register and CD_Unegister and passes it on
;-----------------------------------------------------------------------------------------------
; XCD_Register = &41260+(1<<17)

 Push       r14

;---------------------------------
; XCD_Register or XCD_Unregister ?
;---------------------------------

 SUB        r14, r11, #&00260      ; XCD_Register
 SUBS       r14, r14, #&41000
 CMPNE      r14, #1                ; XCD_Unregister
 ; since SWI &80000000 can't happen, this clears V, which is the only flag requirement for next claimant

 Pull       pc, NE

;---------------------------------
; XCD_Register ?
;---------------------------------
 TEQ        r14, #0

 Pull       r14

 Push       "r0-r11"                  ; claim the vector when the SWI handler returns

 ; It's probably not worth forcibly enabling interrupts for these
 BEQ        cd_register
 B          cd_unregister

;---------------------------------


;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------

 LTORG

 END
