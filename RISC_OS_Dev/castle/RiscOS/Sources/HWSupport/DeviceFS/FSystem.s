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
; > FSystem (filing system interface, stream handling)



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                MakeErrorBlock DeviceFS_BadOp
                MakeErrorBlock DeviceFS_Escape
                MakeErrorBlock DeviceFS_CannotDetach
		MakeErrorBlock DeviceFS_BadIOCtlReasonCode
                MakeErrorBlock DeviceFS_Timeout

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

flush		SETD	false	;debug for file flushing
close		SETD	true	;sets the close debug flag, somehow not visable from version

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; perform an escape check, set r0 -> error block if escape is pressed.
;

checkescape     Entry
 [ Use0PageForESC
                MOV     lr, #0
                LDRB    lr, [lr, #ESC_Status]
                TST     lr, #&40                                ; if ESC flag clear
                EXIT    EQ                                      ; then exit
 |
                SWI     XOS_ReadEscapeState                     ; C set if escape held
                EXIT    VS                                      ; exit if an error
                EXIT    CC                                      ; or if no escape
 ]

		Debug	fs, "escape read in DeviceFS!"
                Push    "r1,r2"
                MOV     r0, #&7E                                ; acknowledge escape
                SWI     XOS_Byte
                Pull    "r1,r2"

                ADR     r0, ErrorBlock_DeviceFS_Escape          ; so set r0 -> error block
                PullEnv
                DoError                                         ; translate error and return V set

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

 [ TWSleep
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call this timeout after the delay time.  it must wake up the task and make
; it non-blocking so as to return to the user.
;
; On entry, r12 = context, IRQs disabled
; must preserve all registers
;

timeout
                Entry   "r0"
                MOV     r0, #ff_TimedOut
                STR     r0, [r12, #file_PollWord]   ; r12 was fr when registered
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; sleep receiving until pollword non-zero or error
;
sleep_on_tx     Entry   "r0-r2"
                ADR     r1, checkfileTX_sleep
                B       %f5

sleep_on_rx     ALTENTRY
                ADR     r1, checkfileRX_sleep
5
                Push    "r1"                        ; save r1 for later

                MOV     r0, #9
                MOV     r2, fr
                SWI     XOS_CallEvery

                LDR     r0, [fr, #file_Timeout]
                TEQ     r0, #0
                BEQ     %f10

                ADR     r1, timeout
                MOV     r2, fr
                SWI     XOS_CallAfter
10
                ADD     r1, fr, #file_PollWord
                MOV     r0, #UpCall_Sleep
                Debug   fs, "Pollword", r1
                SWI     XOS_UpCall

                SWI     XOS_LeaveOS                             ; trigger callbacks too
                SWI     XOS_EnterOS


                ADR     r0, timeout
                MOV     r1, fr
                SWI     XOS_RemoveTickerEvent

                Pull    "r0"                                    ; restore old r1 into r0
                SWI     XOS_RemoveTickerEvent

                PHPSEI  r1                                      ; disable interrupts so that there is no IRQ hole
                LDR     r0, [fr, #file_PollWord]
                Debug   fs, "Pollword contents now: ", r0
                TEQ     r0, #0
                TEQNE   r0, #ff_WakeUp
                MOVEQ   r0, #ff_Sleeping                        ; we must mark as sleeping as soon as possible,
                STREQ   r0, [fr, #file_PollWord]                ; so that we get woken up correctly
                PLP     r1
                EXIT    EQ

                TST     r0, #ff_TimedOut :OR: ff_Error
                EXIT    EQ                                      ; awake, no timeout and no error

                TST     r0, #ff_TimedOut
                PullEnv
                ADRNE   r0, ErrorBlock_DeviceFS_Timeout         ; so set r0 -> error block
                DoError NE                                      ; translate error and return V set

                ADD     r0, fr, #file_Error                     ; not a time out, implies file error
 [ debug
                ADD     r0, r0, #4
		DebugS	fs, "waking up with error: ", r0
                SUB     r0, r0, #4
 ]
                SETV
                MOV     pc, lr


checkfileTX_sleep Entry "fr"
                MOV     fr, r12
                BL      checkfileTXOK
                EXIT    VC
                B       %f10

checkfileRX_sleep ALTENTRY
                MOV     fr, r12
                BL      checkfileRXOK
                EXIT    VC
10
                Push    "r0-r3"
                ADD     r2, fr, #file_Error
                MOV     r1, #252
20
                LDR     r3, [r0, r1]
                STR     r3, [r2, r1]
                SUBS    r1, r1, #4
                BGE     %b20

                LDR     r2, [fr, #file_PollWord]
                ORR     r2, r2, #ff_Error
                STR     r2, [fr, #file_PollWord]

                Pull    "r0-r3"

                CLRV
                EXIT



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 ]
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; StartFSystem, this simply registers the filing system with FileSwitch, no
; errors are reported and no global states are setup.
;

StartFSystem    Entry   "r0-r3"
                MOV     r0, #FSControl_AddFS
                ADRL    r1, module_start                        ; -> base of module
                LDR     r2, =fs_control -module_start           ;  = offset of block from module base
                MOV     r3, wp                                  ; -> workspace
                SWI     XOS_FSControl
                CLRV
                EXIT

                LTORG

; control block used by the module to register itself with FileSwitch as a suitable
; filing system.

fs_control	&		fs_name -module_start		; -> fs name, eg: ADFS
		&		fs_banner -module_start		; -> fs startup banner, eg. Acorn ADFS
		&		fs_open -module_start		; -> fs open
		&		fs_get -module_start		; -> fs get bytes
		&		fs_put -module_start		; -> fs put bytes
		&		fs_args -module_start		; -> fs args
		&		fs_close -module_start		; -> fs close
		&		fs_file -module_start		; -> fs file
fs_infoword	&		fsinfo_special+ fsinfo_flushnotify+ fsinfo_dontusesave+ fsinfo_extrainfo+ fsnumber_DeviceFS
		&		fs_func -module_start		; -> fs func
		[		false
		=		0
		|
		&		fs_gbpb -module_start           ; -> gbpb routine
		]
		&		fsextra_IOCtl

fs_badop
                ADR     r0, ErrorBlock_DeviceFS_BadOp
 [ international
                B       MakeErrorWithFS_name                    ; "Bad operation on filing system devices:"
 |
                RETURNVS
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This code will remove the filing system from FileSwitch.  The code simply
; removes it and returns no errors if it went wrong.
;

RemoveFSystem   Entry   "r0-r1"
                MOV     r0, #FSControl_RemoveFS
                ADRL    r1, fs_name                             ; -> fs name to be removed
                SWI     XOS_FSControl
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: IssueUpCall
;
; in:   r0  = reason code for up call
;
; out:  -
;
; This call issues an UpCall to the outside world.  The routine will
; call the UpCallV to inform tasks such as filer that the directory
; structure has changed.
;

IssueUpCall     Entry   "r0-r9"
                MOV     r9, r0                                  ;  = reason code
                LDR     r8, fs_infoword                         ;  = fsystem information word
                MOV     r6, #0                                  ;  = no special fields
                ADR     r1, null
                MOV     r0, #UpCall_ModifyingFile
                SWI     XOS_UpCall                              ; ignore any errors
                CLRV
                EXIT

null            = 0                                             ; no string so whole structure marked invalid!
                ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_open
;
; This routine handles the opening of files (devices) within the system, this
; involves locating the parent device, seeing if the object can be opened, allocating
; a file block and then validating this within the linked list.
;
; When the block is created it contains the following parameters:
;
;  -> next pointer
;  <- back pointer
;   = validation word
;   = handle (0)
;
; The handle is not validated until the file has finally been opened and we are sure
; that nothing else can go wrong.
;

fs_open         ROUT

                Debug   open, "fsopen reason", r0
                Debug   fs, "fs_open ", r0

                TEQ     r0, #fsopen_ReadOnly
                TEQNE   r0, #fsopen_Update
                BNE     fs_badop                                ; was it a valid reason code

                Push    "r0-pr, lr"

                MOV     fr, #0                                  ; setup the file record pointer

                BL      findobject                              ; setup other important registers
                CMP     r0, #object_subdevice                   ; if a subdevice, eg "$.Parallel.Fred"
                MOVEQ   r0, #object_file                        ; then treat as "$.Parallel" for now

                TEQ     r0, #object_file
                BNE     %80                                     ; don't open the file

                TEQ     pr, #0
                TEQNE   dr, #0
                BEQ     %80                                     ; not linked to any valid record and exit

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =file_SIZE                          ; allocation size
                SWI     XOS_Module
                BVS     %90                                     ; if it goes wrong then deallocate blocks

                MOV     fr, r2                                  ; fr -> file record

                Debug   open, "file record at", fr

                Link    FilesAt, file, fr, r0                   ; link file record

                MOV     r0, #0                                  ; reset most words to zero
                STR     r0, [fr, #file_MadeBuffer]
                STR     r0, [fr, #file_Flags]
                STR     r0, [fr, #file_SpecialField]
                STR     r0, [fr, #file_InternalHandle]          ; magic value that allows the finalise to be issued
                STR     dr, [fr, #file_Device]
                STR     pr, [fr, #file_Parent]
 [ TWSleep
                MOV     r0, #ff_DontSleep
                STR     r0, [fr, #file_PollWord]
 ]

                MOV     r0, #-1                                 ; and indicate that no pending data
                STR     r0, [fr, #file_RXTXWord]
                STR     r0, [fr, #file_BufferHandle]

                ADD     r0, sp, #CallerR0
                LDMIA   r0, {r0, r1}
                LDR     r3, [sp, #CallerR3]
                LDR     r6, [sp, #CallerR6]                     ; get special fields and parameters

                BL      HandleSpecial
                BVS     %90                                     ; attempt to decode special fields and return

                STR     r3, [fr, #file_FSwitchHandle]           ; I need a copy of the fileswitch handle

                Debug   open, "open type", r0
                DebugS  open, "path ", r1
                Debug   open, "file switch handle", r3

                TEQ     r0, #fsopen_ReadOnly                    ; despatch to relevant open handler
                BEQ     open_input
                B       open_output
70
                Debug   open, "opening has worked, info word", r0
                Debug   open, "my internal handle", r1
                Debug   open, "buffer size allocated", r2

                ADD     sp, sp, #CallerR5                       ; skip unimportant registers on frame
                Push    "r0-r4"

                MOV     r0, #DeviceCall_StreamCreated
                LDR     r1, [fr, #file_Parent]                  ; handle to call is the parents
                LDR     r2, [fr, #file_InternalHandle]          ; giving it the internal handle
                LDR     r3, [fr, #file_BufferHandle]
                MOV     r5, r3                                  ; save buffer handle for the UpCall
                BL      CallDevice
                BVS     %FT90

                LDR     r2, [fr, #file_Flags]
                TST     r2, #ff_FileForTX                       ; is it for RX or TX?
                MOVEQ   r2, #0
                MOVNE   r2, #-1

                MOV     r0, #UpCall_StreamCreated
                MOV     r1, pr                                  ; -> parent record
                LDR     r3, [fr, #file_FSwitchHandle]
                LDR     r4, [fr, #file_InternalHandle]
                SWI     XOS_UpCall

		[	false
		; Tell FileSwitch that this is not a buffered device, so it doesn't call fs_gbpb.
		LDR	r0, [sp]
		BIC	r0, r0, #1 :SHL: 28
		STR	r0, [sp]
		Debug	fs, "fs file info word ", r0
		]

                Pull    "r0-pr, pc",VC                          ; return as the file object has been created OK
90
                Debug   open, "failing to open, returning error"

                TEQ     fr, #0
                BLNE    removefileblock                         ; remove the file node keeping r0 intact!

                ADD     sp, sp, #4
                Pull    "r1-pr, lr"
                RETURNVS


80
                Debug   open, "failing to open, returning a null handle"

                TEQ     fr, #0
                BLNE    removefileblock
                Pull    "r0-pr, lr"
                SUBS    r1, r1, r1                              ; R1=0 means file not opened.  Clears V.
                RETURN                                          ; remove file node and return duff handle


; attempt to create a stream for input, this involves creating any buffers required and
; stuff like that.
;

open_input
                LDR     r5, [pr, #parent_Flags]
                TST     r5, #pf_FullDuplex                      ; is the device full duplex
                BNE     %FT05                                   ; if so, then skip

                LDR     r5, [pr, #parent_UsedOutputs]           ; not full duplex, so if any outputs in use
                TEQ     r5, #0                                  ; we've got trouble
                BEQ     %FT05

                BL      RequestCloseOutputs                     ; try offering service to close r5 output streams
                BNE     %BT80                                   ; if failed then return zero handle

05
                LDR     r5, [pr, #parent_MaxInputs]
                LDR     r6, [pr, #parent_UsedInputs]

                Debug   open, "max RX streams",r5
                Debug   open, "used RX streams",r6

                CMP     r5, #-1
                BEQ     %FT10                                   ; no limit on number of inputs

                CMP     r6, r5                                  ; are all the inputs used yet?
                BLT     %FT10                                   ; no, so OK to continue

                MOV     r5, #1                                  ; need to close one input
                BL      RequestCloseInputs
                BNE     %BT80                                   ; if failed then return zero handle

                LDR     r6, [pr, #parent_UsedInputs]            ; reload since it will have changed
10
                ADD     r6, r6, #1
                STR     r6, [pr, #parent_UsedInputs]            ; store a modified input counter

                LDR     r3, [fr, #file_Flags]
                ORR     r3,r3, #ff_FileForRX :OR: ff_ModifiedCounters ; being used for RX
                STR     r3, [fr, #file_Flags]                   ; stash these flags

                Debug   open, "file flags", r3

                LDR     r6, [fr, #file_UserSpecialData]         ; -> decoded special field string
                MOV     r2, fr                                  ;  = internal handle
		LDR	r4, [fr, #file_FSwitchHandle]
                MOV     r1, pr
                MOV     r0, #DeviceCall_Initialise
                BL      CallDevice                              ; attempt to call the device
                STRVC   r2, [fr, #file_InternalHandle]
                BLVC    make_buffer                             ; make a usable buffer (if needed)
                BVS     %90                                     ; if failed then return error

                MOV     r1, fr                                  ; setup the new handle as required
                MOV     r2, #0                                  ; tell fileswitch it is un-buffered

                MOV     r0, #fsopen_ReadPermission
                LDR     r3, [fr, #file_BufferHandle]
                CMP     r3, #-1                                 ; is there a buffer attached to this file object?
                ORRNE   r0, r0, #fsopen_UnbufferedGBPB          ; yes, so mark as supporting unbuffered GBPB

                B       %70                                     ; it is valid so mark as so!



; attempt to create a stream for output, this involves creating any buffers required and
; stuff like that.
;

open_output
                LDR     r5, [pr, #parent_Flags]
                TST     r5, #pf_FullDuplex                      ; is the device full duplex?
                BNE     %FT15                                   ; if so, then skip

                LDR     r5, [pr, #parent_UsedInputs]            ; not full duplex, so if any inputs in use
                TEQ     r5, #0                                  ; we've got trouble
                BEQ     %FT15

                BL      RequestCloseInputs                      ; try offering service to close r5 input streams
                BNE     %BT80                                   ; if failed then return zero handle

15
                LDR     r5, [pr, #parent_MaxOutputs]
                LDR     r6, [pr, #parent_UsedOutputs]

                Debug   open, "max TX streams", r5
                Debug   open, "used TX streams", r6

                CMP     r5, #-1
                BEQ     %FT20                                   ; no limit on number of outputs

                CMP     r6, r5                                  ; are all the outputs used yet?
                BLT     %FT20                                   ; no, so OK to continue

                MOV     r5, #1                                  ; need to close one output
                BL      RequestCloseOutputs
                BNE     %BT80                                   ; if failed then return zero handle

                LDR     r6, [pr, #parent_UsedOutputs]           ; reload since it will have changed
20
                ADD     r6, r6, #1
                STR     r6, [pr, #parent_UsedOutputs]           ; store a modified input counter

                LDR     r3, [fr, #file_Flags]
                ORR     r3, r3, #ff_FileForTX :OR: ff_ModifiedCounters ; being used for TX
                STR     r3, [fr, #file_Flags]                   ; stash some important flags

                Debug   open, "file flags", r3

                LDR     r6, [fr, #file_UserSpecialData]         ; -> decoded special field string
		LDR	r4, [fr, #file_FSwitchHandle]
                MOV     r2, fr
                MOV     r1, pr
                MOV     r0, #DeviceCall_Initialise
                BL      CallDevice                              ; call the device
                STRVC   r2, [fr, #file_InternalHandle]
                BLVC    make_buffer                             ; make a usable buffer (if needed)
                BVS     %90                                     ; if that fails then attempt to create the buffer

                MOV     r1, fr                                  ; setup the new handle as required
                MOV     r2, #0                                  ; tell fileswitch it is un-buffered

                MOV     r0, #fsopen_WritePermission
                LDR     r3, [fr, #file_BufferHandle]
                CMP     r3, #-1                                 ; is there a buffer attached to this file object?
                ORRNE   r0, r0, #fsopen_UnbufferedGBPB          ; yes, so mark as supporting unbuffered GBPB

                B       %70                                     ; it is valid so mark as so!



; now the fun really starts, we must attempt to create a buffer for the buffered
; devices and ignore it if this is not possible.  The routine reads the
; information about the buffer that is going to be created, if one does
; not exist then it will create one, if one does exist then we attempt to
; use that.
;

make_buffer     ROUT

                Push    "r3, lr"

                LDR     r0, [dr, #device_Flags]
                TST     r0, #df_BufferedDevice                  ; is it a buffered device?
                Pull    "r3, pc", EQ                            ; no, so we cannot even consider creating a buffer

                Debug   open, "device must be buffered"

                LDR     r0, [fr, #file_Flags]
                TST     r0, #ff_FileForTX                       ; is it a RX or TX buffer?
                MOVEQ   r0, #DeviceCall_CreateBufferRX
                ADDEQ   r3, dr, #device_RXBufferFlags
                MOVNE   r0, #DeviceCall_CreateBufferTX
                ADDNE   r3, dr, #device_TXBufferFlags
                ASSERT  device_RXBufferFlags + 4 = device_RXBufferSize
                ASSERT  device_TXBufferFlags + 4 = device_TXBufferSize
                LDMIA   r3, {r3, r4}                            ; get the buffer flags + size

                Debug   open, "suggested buffer flags", r3
                Debug   open, "suggested buffer size", r4

                MOV     r1, pr
                LDR     r2, [fr, #file_InternalHandle]          ; giving it the internal handle
                LDR     r5, [fr, #file_BufferHandle]
                MOV     r6, #-1                                 ; no threshold at the moment
                BL      CallDevice
                Pull    "r3, pc", VS                            ; it went wrong so give up now buster

                ; Buffer_Create will create a buffer size of r4 -1 or r4 -4
                ; depending on word aligned flag. So r4 is increased so that
                ; we get the size requested.
                TST     r3, #BufferFlags_WordAlignedInserts
                ADDEQ   r4, r4, #1
                ADDNE   r4, r4, #4

                Debug   open, "modified flags for buffer", r3
                Debug   open, "modified buffer size", r4
                Debug   open, "first buffer handle", r5
                Debug   open, "modified threshold value", r6

                MOV     r0, r5                                  ; r0 = buffer handle

 [ FastBufferMan
05
                SWI     XBuffer_InternalInfo                    ; want buffer manager's private buffer id
                STRVC   r0, [fr, #file_BufferPrivId]            ; store private buffer id
                STRVC   r1, BuffManService                      ; keep service routine addr up to date
                STRVC   r2, BuffManWkSpace                      ; keep buffer manager workspace ptr up to date
                BVC     %FT10

                Debug   open, "buffer #1 does not already exist"

                Push    "r3-r5"
                Pull    "r0-r2"                                 ; want flags, size and handle in r0-r2
                SWI     XBuffer_Create                          ; for buffer create
                Pull    "r3, pc", VS

                STR     pc, [fr, #file_MadeBuffer]              ; <>0 if buffer was made
                MOV     r5, r0                                  ; save buffer handle in r5
                B       %BT05
10
                MOV     r0, r5                                  ; move buffer handle back into r0
 |
                Push    "r3-r6"
                SWI     XBuffer_GetInfo                         ; does it exist already?
                Pull    "r0-r2, r6"                             ; restore registers no matter what
                MOVVC   r0, r2                                  ; if already exists then make r0 = buffer handle
                BVC     %10                                     ; it does so don't create the doofer

                Debug   open, "buffer #1 does not already exist"

                SWI     XBuffer_Create                          ; attempt to create the first buffer
                Pull    "r3, pc", VS                            ; and if we can't (ie. error) then give up now

                STR     pc, [fr, #file_MadeBuffer]              ; <>0 if buffer was made
10
 ]
                Debug   open, "handle of the first buffer", r0

                STR     r0, [fr, #file_BufferHandle]

                Debug   open, "setting modified flags for buffer", r3

                MOV     r2, #0                                  ; AND mask
                MOV     r1, r3                                  ; EOR bits (=set)
                SWI     XBuffer_ModifyFlags
                Pull    "r3, pc", VS

                LDR     r1, [fr, #file_Flags]
 [ wakeup_data_present
		TST	r1, #ff_FileForTX
		ADRNE	r1, wakeup			; normal tx wakeup
		ADREQ	r1, wakeup_rx			; special rx wakeup
 |
                ANDS    r1, r1, #ff_FileForTX                   ; if an output device (r1<>0)
                ADRNE   r1, wakeup                              ; then use real wake up code else use none
 ]
                ADRL    r2, detach                              ; try to close stream if someone tries to detach
                MOV     r3, fr
                MOV     r4, wp                                  ; workspace + private word

                Debug   open, "attempting to link to buffer", r0
                Debug   open, "wake up routine at", r1
                Debug   open, "detach routine at", r2
                Debug   open, "file record", fr
                Debug   open, "workspace at", wp

                SWI     XBuffer_LinkDevice                      ; attempt to link the device to the buffer
                Pull    "r3, pc", VS                            ; return if went wrong!!!

                LDR     r1, [fr, #file_Flags]                   ; set flag that indicates
                ORR     r1, r1, #ff_DeviceLinked                ; device is linked
                STR     r1, [fr, #file_Flags]

                Debug   open, "handle", r0
                Debug   open, "threshold about to be set to", r6

                MOVS    r1, r6                                  ; if -VE then don't set threshold
                SWIPL   XBuffer_Threshold

                Pull    "r3, pc"                                ; return VS, VC from the previous call, r0 correct if needed


; wake up code, this is called when some data is inserted into a dormant TX buffer.
; after calling device, r0 = 0 if the device wishes to remain dormant, otherwise preserved

wakeup          EntryS  "r0-r3"
                LDR     r2, [r8, #file_InternalHandle]          ; if device being opened or closed
                TEQ     r2, #0
                EXITS   EQ                                      ; then ignore
                MOV     r0, #DeviceCall_WakeUpTX
                LDR     r1, [r8, #file_Parent]
                BL      CallDevice                              ; attempt to wake up device
                EXITS   VS                                      ; if we got an error, go no further
                TEQ     r0, #DeviceCall_WakeUpTX                ; if device wishes to become active
                EXITS   EQ                                      ; then do nothing, buffer manager assumes this
                LDR     r0, [r8, #file_BufferHandle]
                MOV     r1, #0
                MOV     r2, #:NOT: BufferFlags_NotDormant       ; indicate dormant
                SWI     XBuffer_ModifyFlags
                EXITS

 [ wakeup_data_present
; wake up code, this is called when some data is inserted into a dormant RX buffer.
wakeup_rx	Entry	"r0-r9"				; Stack everything, in case CallAVector corrupts it

                ASSERT (IRQ_mode :AND: :NOT: SVC_mode) = 0

                SavePSR r2
                ORR     r0, r2, #SVC_mode
                RestPSR r0,,cf                          ; set SVC mode
                NOP

		Push	"r2,lr"				; Preserve r2 and lr across CallAVector
		MOV	r0, #UpCall_DeviceRxDataPresent
                LDR     r1, [r8, #file_FSwitchHandle]
;		SWI	XOS_UpCall
		MOV	r9, #UpCallV
		SWI	XOS_CallAVector
		Pull	"r2,lr"

                RestPSR r2,,cf
		NOP

 [ TWSleep
                LDR     r0, [r8, #file_PollWord]
                TEQ     r0, #ff_DontSleep
                MOVNE   r0, #ff_WakeUp
                STRNE   r0, [r8, #file_PollWord]
                Debug   fs, "Waking up pollword"
 ]
		EXIT
 ]
; detach code, this is called when someone tries to deregister the buffer, or link it some other device

detach          Entry   "r0-r2"
                MOV     r1, #Service_DeviceFSCloseRequest
                LDR     r2, [r8, #file_FSwitchHandle]           ; get file handle
                SWI     XOS_ServiceCall
                CMP     r1, #Service_Serviced                   ; if someone responded (then Z set, V cleared)
                PullEnv
                MOVEQ   pc, lr
                ADRL    r0, ErrorBlock_DeviceFS_CannotDetach    ; else return error
                DoError

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       RequestCloseInputs - Issue services to request the closing of a number of input streams
;       RequestCloseOutputs - Ditto for output streams
;
; in:   r5 = number of streams that need closing
;       pr -> parent record of device that we want to free streams on
;       fr -> file record we're currently working on, so ignore that one
;
; out:  EQ => succeeded in closing enough
;       NE => failed to close enough

RequestCloseInputs Entry "r0-r3,r5"

        Debug   open, "RequestCloseInputs called"

        MOV     r3, #ff_FileForRX
        B       RequestCloseStreams

RequestCloseOutputs ALTENTRY

        Debug   open, "RequestCloseOutputs called"

        MOV     r3, #ff_FileForTX
RequestCloseStreams

        Debug   open, "Number of streams to close", r5

        LDR     r0, FilesAt
10
        TEQ     r0, #0                          ; if at end of files list
        BEQ     %FT90                           ; then no more files to try

        TEQ     r0, fr                          ; if it's the one we're building
        LDREQ   r0, [r0, #file_Next]            ; then ignore it
        BEQ     %BT10

        LDR     lr, [r0, #file_Parent]
        TEQ     lr, pr                          ; if the right device

        LDREQ   lr, [r0, #file_Flags]
        ANDEQ   lr, lr, #ff_FileInputOutput
        TEQEQ   lr, r3                          ; then check for right input/output type

        LDREQ   r2, [r0, #file_FSwitchHandle]   ; if OK then load fileswitch handle
        LDR     r0, [r0, #file_Next]            ; always move onto next file (as current file may close under our feet)
        BNE     %BT10                           ; if no good then goto next file

        Debug   open, "Issuing service to close handle", r2

        MOV     r1, #Service_DeviceFSCloseRequest
        SWI     XOS_ServiceCall
        TEQ     r1, #Service_Serviced           ; if that file was closed for us
        SUBEQS  r5, r5, #1                      ; then one less file to close
        BNE     %BT10                           ; if no response for that file, or still more to do, then loop
90
        TEQ     r5, #0                          ; set EQ if successfully closed the required number of files
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_get
;
; Get a single byte from the filing system, this involves waking the device,
; seeing if the device is buffered and reading the non-buffering word
; or extracting a character from the buffer.
;

fs_get          Entry   "r0-r2, fr,pr"

		Debug	fs, "fs_get"

                MOV     fr, r1                                  ; -> file record
                LDR     pr, [fr, #file_Parent]

                MOV     r0, #DeviceCall_WakeUpRX
                MOV     r1, pr
                LDR     r2, [fr, #file_InternalHandle]
                MOV     r3, #1                                  ; since we support unbuffered GBPB, FileSwitch only
                                                                ; calls this entry point to handle OS_BGet
                BL      CallDevice                              ; ensure wake for calling
                BVS     %FT30                                   ; return an error

                B       %FT01


00
                BL      checkfileRXOK
                BVS     %FT30

                LDR     r1, [pr, #parent_Flags]
                TST     r1, #pf_MonitorEOF
                BEQ     %FT01

                MOV     r1, fr                                  ; -> file record
                BL      checkeof                                ; read the EOF status
                BCS     %FT40                                   ; give up if EOF

01

                BL      checkescape                             ; is escape pressed
                BVS     %FT30                                   ; yes then return the escape error

                LDR     r1, [fr, #file_BufferHandle]
                CMP     r1, #-1                                 ; is the device buffered?
                BNE     %FT10

                LDR     r0, [fr, #file_RXTXWord]
                CMP     r0, #-1                                 ; is there a pending word
                MOVCC   r1, #-1
                STRCC   r1, [fr, #file_RXTXWord]                ; yes, we have it so reset the word to a new state
                B       %FT20
10
 [ FastBufferMan
                MOV     r0, #BufferReason_RemoveByte
                LDR     r1, [fr, #file_BufferPrivId]            ; get buffer manager private buffer id
                CallBuffMan
                MOVCC   r0, r2
 |
                CLRV                                            ; ensure V clear to remove character
                Push    "r1-r2, r9"
                MOV     r9, #REMV
                SWI     XOS_CallAVector                         ; attempt to remove the byte
                Pull    "r1-r2, r9"                             ; preserve important registers
 ]
                BVS     %FT30                                   ; return any errors
 [ TWSleep
20

                BCC     %FT25                                   ; if data was returned don't loop
                LDR     r1, [fr, #file_PollWord]
                TEQ     r1, #ff_DontSleep
                BEQ     %BT00                                   ; we don't want to sleep

                ASSERT  (BufferReason_RemoveByte <> -1)
                CMP     r0, #-1                                 ; if we're not buffered, r0 = -1 here.
                MOVEQ   r1, #ff_WakeUp                        ; reset pollword if we're buffered, if not then
                STREQ   r1, [fr, #file_PollWord]                ; we can't set a pollword to wake us up
                BL      sleep_on_rx
                BVS     %FT30

                B       %BT00                                   ; loop again to make sure actually received data
25
 |
                BCS     %BT00                                   ; loop again to make sure actually received data
 ]
                STR     r0, [sp, #CallerR0]                     ; write to return frame

                BL      %FT80                                   ; SleepRX - ignore error returned

                CLC                                             ; ensure C and V clear on return
                PullEnv
                MOV     pc, lr
30
                STR     r0, [sp, #CallerR0]                     ; ensure error pointer on return frame valid

                BL      %FT80                                   ; SleepRX - ignore error returned

                PullEnv
                RETURNVS                                        ; return the error

40
                BL      %FT80

                PullEnv
                SEC                                             ; C set, V clear - EOF encountered
                MOV     pc, lr


80              ; SleepRX - corrupts r0, r1 and r2
                MOV     r0, #DeviceCall_SleepRX
                MOV     r1, pr
                LDR     r2, [fr, #file_InternalHandle]
                B       CallDevice



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; In
;  fr
; Out
; V and r0=error possible
checkfileRXOK   Entry "r0-r2"
                MOV     r0, #DeviceCall_MonitorRX
                B       %FT10

checkfileTXOK   ALTENTRY
                MOV     r0, #DeviceCall_MonitorTX
10
                LDR     r1, [fr, #file_Parent]
                LDR     r2, [r1, #parent_Flags]
                TST     r2, #ParentFlag_MonitorTransfers
		DebugIf	NE, fs, "monitor calls supported"
		DebugIf	EQ, fs, "monitor calls not supported"
		EXIT	EQ

                LDR	r2, [fr, #file_InternalHandle]
                BL	CallDevice		;ensure wake for calling
		STRVS   r0, [sp]		;logic changed to be independent of flags on entry
						;JRC Tue 29th April 1997
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_put
;
; Put a byte to a device, this involves the following.  Inserting some
; data into a buffer (if applicable), writing the RXTX word with this
; piece of data and then waking the device up.

fs_put		Entry	"r0-r2, fr, r9"

		Debug	fs, "fs_put"

 [ debug
		Push	"r0-r3"

		;Check page 0 escape flag
                MOV	r0, #0
                LDRB	r0, [r0, #ESC_Status]
		BIC	r0, r0, #&CF
		Debug	fs, "ESC_Status", r0

		MOV	r1, #0                  ; ready for OS_ChangeEnvironment
		;Check SWI version of escape flag
		SWI	XOS_ReadEscapeState
                ADC     r0, r1, #0
		Debug	fs, "ReadEscapeState", r0

		MOV	r0, #9 ;escape
		MOV	r2, #0
		MOV	r3, #0
		SWI	XOS_ChangeEnvironment
		Debug	fs, "esc handler", r1

		MOV	r0, #10 ;event
		MOV	r1, #0
		MOV	r2, #0
		MOV	r3, #0
		SWI	XOS_ChangeEnvironment
		Debug	fs, "event handler", r1

		Pull	"r0-r3"
 ]

		MOV	fr, r1					; -> file record

		LDR	r1, [fr, #file_BufferHandle]
		CMP	r1, #-1					; is the object buffered?
 [ FastBufferMan
		MOVNE	r2, r0					; need byte in r2
		LDRNE	r1, [fr, #file_BufferPrivId]		; get buffer managers private buffer id
 |
		MOVNE	r9, #INSV				; saves an extra label
 ]
		BNE	%10

		; Non-buffered device
00
		BL	checkescape				; is an escape pending?
		BVS	%99

		BL	checkfileTXOK
		BVS	%99

		LDR	r1, [fr, #file_RXTXWord]
		CMP	r1, #-1					; is the RX/TX word free yet?
 [ TWSleep
		BEQ	%05					; yes, so don't loop again
                LDR     r1, [fr, #file_PollWord]
                TEQ     r1, #ff_DontSleep
                BEQ     %00                                     ; we don't want to sleep

                BL      sleep_on_tx
                BVS     %FT99

                B       %00                                     ; loop again
5
 |
		BNE	%00					; no, so loop again
 ]
		STR	r0, [fr, #file_RXTXWord]		; yes, so write the word in now

		MOV	r0, #DeviceCall_WakeUpTX
		LDR	r1, [fr, #file_Parent]
		LDR	r2, [fr, #file_InternalHandle]
		BL	CallDevice				; wake up for transmit now
		B	%99

		; Buffered device
10
		BL	checkescape				; is an escape pending
		BLVS	purgeoutputbuffer			; if so then purge output buffer
		BVS	%99

		BL	checkfileTXOK
		BLVS	purgeoutputbuffer			; if an error then purge output buffer
		BVS	%99

 [ FastBufferMan
		MOV	r0, #BufferReason_InsertByte
		CallBuffMan					; r1,r2 already set up
 |
		SWI	XOS_CallAVector
 ]
		BVS	%99					; return any errors that may occur
 [ TWSleep
		BCC	%20					; don't loop if inserted
                LDR     r1, [fr, #file_PollWord]
                TEQ     r1, #ff_DontSleep
                BEQ     %10                                     ; we don't want to sleep

;                MOV     r1, #ff_Sleeping                        ; reset pollword
;                STR     r1, [fr, #file_PollWord]

                BL      sleep_on_tx
                BVS     %FT99

		B	%10					; keep looping
20
 |
		BCS	%10					; keep looping until inserted
 ]

		CLRV
99		STRVS	r0, [sp]
		PullEnv
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_args
;
; Handle the fs_args entry, this is used for streams to read EOF, flush streams
; etc.
;

fs_args         ROUT

		Debug	fs, "fs_args", r0

                Debug   args, "fs_args called with reason code", r0

                CMP     r0, #fsargs_SetEXT                      ; ignore SetEXT
                MOVEQ   pc, lr

                TEQ     r0, #fsargs_SetPTR
                TEQNE   r0, #fsargs_EnsureSize
                TEQNE   r0, #fsargs_WriteZeroes
                BEQ     fs_badop                ; these ones give nice errors

                TEQ     r0, #fsargs_ReadPTR
                TEQNE   r0, #fsargs_ReadSize
                SUBEQS  r2, r2, r2              ; return 0, Z still set, clear V
                MOVEQ   pc, lr

                TEQ	r0, #fsargs_ReadEXT
		BEQ	args_ext

		TEQ	r0, #fsargs_IOCtl
		BEQ	args_ioctl

                TEQ     r0, #fsargs_ReadLoadExec
                BEQ     args_loadexec

                TEQ     r0, #fsargs_Flush               ; is it a flush?
                BEQ     args_flush

                TEQ     r0, #fsargs_EOFCheck            ; is it a eof read?
                BEQ     args_eof                        ; then do it

                B       fs_badop

; handle ioctl's

args_ioctl	ROUT
		Entry	"r0-r3, fr,pr"

		LDR	r0, [r2, #0]			; load ioctl reason codes and flags
		BIC	r0, r0, #&ff00ffff
		TEQ	r0, #&00ff0000
                BNE     %FT05
		BL	ioctl_miscop
		B	%10				; only V flag corrupted so OK

; catch remaining cases and pass into device driver
05
                MOV     fr, r1                     	; -> file record
		LDR	pr, [fr, #file_Parent]

                MOV     r0, #DeviceCall_IOCtl
                MOV     r1, pr
		MOV	r3, r2				; shift r2 up a reg
                LDR     r2, [fr, #file_InternalHandle]
                BL      CallDevice

10
                STRVS   r0, [sp]
                EXIT


; deal with non-device specific ioctls

ioctl_miscop	ROUT

		LDR	r0, [r2, #0]			; load ioctl reason codes and flags

; mask off top 16 bits of r0 to obtain reason code
		MOV	r0, r0, LSL #16
		MOV	r0, r0, LSR #16

                CMP     r0, #(%20-%10)/4		; validate reason code
                ADDCC   pc, pc, r0, LSL #2 		; despatch
		B	%20
10
		MOV	pc, lr				; 0 nothing
		B	ioctl_miscop_nonblock		; 1 set non-blocking I/O
                MOV     pc, lr                          ; 2 buffer threshold
                MOV     pc, lr                          ; 3 flush stream buffers
                B       ioctl_miscop_sleep              ; 4 sleeping I/O (Calls UpCall 6)
                B       ioctl_miscop_timeout            ; 5 timeout if sleeping, 0 means sleep forever
20
                PullEnv
                MOVEQ   pc, lr                          ; V must be clear to get here
		ADRL	r0, ErrorBlock_DeviceFS_BadIOCtlReasonCode
                DoError


ioctl_miscop_nonblock
		ROUT
		LDR	r0, [r2, #0]			; load ioctl reason codes and flags

		MOV	fr, r1				; -> file record
		LDR	r1, [fr, #file_Flags]

		TST	r0, #&80000000			; test write flag
		BEQ	%10

		LDR	r3, [r2, #4]			; load ioctl data word
		CMP	r3, #0
		BICEQ	r1, r1, #ff_NonBlocking		; clear non-blocking I/O enabled flag
		CMP	r3, #1
		ORREQ	r1, r1, #ff_NonBlocking		; set non-blocking I/O enabled flag
		STR	r1, [fr, #file_Flags]		; write back flags
10
		TST	r0, #&40000000			; test read flag
		BEQ	%20

		TST	r1, #ff_NonBlocking		; test non-blocking I/O enabled flag
		MOVNE	r0, #1				; non-blocking I/O enabled
		MOVEQ	r0, #0				; non-blocking I/O disabled
		STR	r0, [r2, #4]			; store result in ioctl block
20
                CLRV
		MOV	pc, lr

ioctl_miscop_sleep
                ROUT
		LDR	r0, [r2, #0]			; load ioctl reason codes and flags

		MOV	fr, r1				; -> file record
		LDR	r1, [fr, #file_PollWord]

		TST	r0, #&80000000			; test write flag
		BEQ	%10

		LDR	r3, [r2, #4]			; load ioctl data word
		CMP	r3, #0
                MOVEQ   r1, #ff_DontSleep               ; sleeping disabled
                MOVNE   r1, #ff_WakeUp                  ; sleeping enabled
		STR	r1, [fr, #file_PollWord]	; write back
10
		TST	r0, #&40000000			; test read flag
		BEQ	%20

                TEQ     r1, #ff_DontSleep               ; test if we're not going to sleep
		MOVEQ	r0, #1				; sleeping disabled
		MOVNE	r0, #0				; sleeping enabled
		STR	r0, [r2, #4]			; store result in ioctl block
20
                CLRV
		MOV	pc, lr

ioctl_miscop_timeout
                ROUT
		LDR	r0, [r2, #0]			; load ioctl reason codes and flags

		MOV	fr, r1				; -> file record
		LDR	r1, [fr, #file_Timeout]

		TST	r0, #&80000000			; test write flag
		BEQ	%10

		LDR	r3, [r2, #4]			; load ioctl data word
		STR	r3, [fr, #file_Timeout]	        ; write back
10
		TST	r0, #&40000000			; test read flag
		BEQ	%20

		STR	r1, [r2, #4]			; store result in ioctl block
20
                CLRV
		MOV	pc, lr

; handle checking of the file extent

args_ext	Entry	"r0-r1,r3-r6, fr"

                MOV     fr, r1                     	; -> file record

                LDR     r0, [fr, #file_BufferHandle]
                CMP     r0, #-1                         ; is the object buffered
                BEQ     %FT10				; look at rx/tx word

; is this a tx stream
		LDR	r0, [fr, #file_Flags]
		TST	r0, #ff_FileForTX
		BNE	%5

 [ FastBufferMan
                MOV     r0, #BufferReason_UsedSpace
                LDR     r1, [fr, #file_BufferPrivId]
                CallBuffMan
 |
                SWI     XBuffer_GetInfo
 ]
                STRVS   r0, [sp]
 [ :LNOT: FastBufferMan
                MOVVC   r2, r6
 ]
		EXIT
5
; deal with tx stream
 [ FastBufferMan
                MOV     r0, #BufferReason_FreeSpace
                LDR     r1, [fr, #file_BufferPrivId]
                CallBuffMan
 |
                SWI     XBuffer_GetInfo
 ]
                STRVS   r0, [sp]
 [ :LNOT: FastBufferMan
                MOVVC	r2, r5
 ]
		EXIT

10
; handle the case where none-buffered, just a word
                LDR     r0, [fr, #file_RXTXWord]
                CMP     r0, #-1                    	; RX/TX word full
		MOVEQ	r2, #0				; no
		MOVNE	r2, #1				; yes
; is this a tx stream
		LDR	r0, [fr, #file_Flags]
		TST	r0, #ff_FileForTX
		EXIT	EQ

		CMP	r2, #0
		MOVEQ	r2, #1
		MOVNE	r2, #0

		EXIT

; handle checking the EOF flag within the system.  Could return errors, assumes
; that r1 on entry contains the internal handle passed to and from fileswitch to
; the filing system.

checkeof        Entry   "r2"                                    ; internal routine,
                BL      args_eof
                CMPVC   r2, #1                                  ; exits CS for EOF, else CC
                EXIT


args_eof        Entry   "r0,r1,r3-r6, fr"

                Debug   eof, "args_eof called"

                MOV     fr, r1                                  ; -> file record

                LDR     r0, [fr, #file_BufferHandle]
                CMP     r0, #-1                                 ; is the object buffered?
                BEQ     %FT10                                   ; no, so check the RX/TX word

 [ FastBufferMan
                MOV     r0, #BufferReason_UsedSpace
                LDR     r1, [fr, #file_BufferPrivId]            ; get buffer managers private buffer id
                CallBuffMan
 |
                SWI     XBuffer_GetInfo                         ; try to read information about this buffer
 ]

05
                STRVS   r0, [sp]
                EXIT    VS

 [ FastBufferMan
                TEQ     r2, #0                                  ; any chars in buffer?
 |
                TEQ     r6, #0                                  ; any chars in buffer?
 ]
                BNE     %FT25
                B       %FT20

10
                LDR     r0, [fr, #file_RXTXWord]
                CMP     r0, #-1                                 ; does the RX/TX word contain any data?
                BNE     %FT25
20
                MOV     r0, #DeviceCall_EndOfData
                LDR     r1, [fr, #file_Parent]
                LDR     r2, [fr, #file_InternalHandle]
                MOV     r3, #-1                                 ; pass -1 to get EOF if device does not modify
                BL      CallDevice
                BVS     %BT05                                   ; if it fails then returns error to outside world

                CMP     r3, #-1
25
 [ debug
                BEQ     %FT26
                Debug   eof, "Indicating not EOF"
                B       %FT27
26
                Debug   eof, "Indicating EOF"
27
 ]
                MOVEQ   r2, #-1                                 ; no data, indicate EOF
                MOVNE   r2, #0                                  ; otherwise indicate not EOF
                CLRV
                EXIT


; flush a stream.  Wait for the stream to empty, calling OS_ReadEscape state to allow
; quick exit from these operations.
;

args_flush      Entry   "r1-r3,fr"

		Debug	flush, "Entered Flush"
                ADDS    fr, r1, #0                              ; clear V!
                LDR     r0, [r1, #file_Flags]
                TST     r0, #ff_FileForTX                       ; is the file an output object
                EXIT    EQ                                      ; no, so return now
10
                BLVC    checkeof                                ; CS = exit loop until EOF or Escape pressed
		DebugIf CS, flush, "Exited  Flush EOF"
                EXIT    CS                                      ; normal exit eof found

                BLVC    checkescape                             ; VS = exit not always enabled
                BLVC    checkfileTXOK                           ; VS = exit Monitor TX for errors call 12.
		DebugE  flush, "Exited  Flush forced exit"
                EXIT    VS                                      ; return the error (if one)
 [ TWSleep
                MOV     fr, r1
                LDR     r0, [fr, #file_PollWord]
                TEQ     r0, #ff_DontSleep
                BEQ     %BT10                                   ; we don't want to sleep

                LDR     r1, [fr, #file_BufferHandle]
                CMP     r1, #-1                                 ; is the device buffered?

                MOVEQ   r1, #ff_WakeUp                          ; reset pollword if we're buffered, if not then
                STREQ   r1, [fr, #file_PollWord]                ; we can't set a pollword to wake us up

                BL      sleep_on_tx

                MOV     r1, fr
 ]
                B       %BT10                                   ; if C clear then still no end of data

; get load and exec address of a stream and return them back to the caller.
;

args_loadexec   MOV     r2, #0
                SUBS    r3, r3, r3                              ; R3=0, clears V
                MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_close
;
; The code handles the closing of a file within the filing system, this involves
; unlinking the device from the buffer and then closing down the device.
;

fs_close        Entry   "r0, dr, pr"

                Debug   close,"Closing file"
                Debug   fs, "fs_close"

                MOV     fr, r1                                  ; fr is the file handle to be used
                BL      removefileblock                         ; and then remove the block associated with it

 [ TWSleep
                STRVS   r0, [sp, #Proc_RegOffset]
 ]
                EXIT


removefileblock Entry   "r0-r5, dr, pr"                         ; attempt to zap record at 'FR'

                Debug   close,"removing file block"
                LDR     r5, [fr, #file_Flags]                   ; get global flags word
                Debug   close,"file flags ", r5
                Debug   close,"file record is", fr

 [ TWSleep
                MOV     r0, #UpCall_SleepNoMore
                ADD     r1, fr, #file_PollWord
                Debug   fs, "Unsleeping pollword", r1
                SWI     XOS_UpCall
                STRVS   r0, [sp, #Proc_RegOffset]
                EXIT    VS
 ]

                ADD     dr, fr, #file_Device
                LDMIA   dr, {dr, pr}                            ; get parent + device records

                LDR     r2, [fr, #file_InternalHandle]
                TEQ     r2, #0                                  ; was the device setup?
                BEQ     %FT10

                MOV     r0, #DeviceCall_Finalise
                MOV     r1, pr
                BL      CallDevice                              ; attempt to close down the device
                BVS     %FT90                                   ; if device refuses, then fail operation

                Debug   close,"device call succeeded"

                LDR     r4, [fr, #file_InternalHandle]
                MOV     r0, #0
                STR     r0, [fr, #file_InternalHandle]          ; indicate we've successfully closed stream
10
                LDR     r0, [fr, #file_BufferHandle]
                CMP     r0, #-1                                 ; is a buffer allocated
                BEQ     %FT20                                   ; no, so skip

                LDR     r1, [fr, #file_Flags]                   ; did we link the device to the buffer?
                TST     r1, #ff_DeviceLinked
                BEQ     %FT12                                   ; no, so skip

                MOV     r1, r0                                  ; save buffer handle, in case of error
                SWI     XBuffer_UnlinkDevice                    ; unlink device from buffer
                MOV     r0, r1                                  ; restore buffer handle

                Debug   close,"unlinked buffer from device"
12
                LDR     r1, [fr, #file_MadeBuffer]
                TEQ     r1, #0                                  ; and if it is did we create the buffer
                BEQ     %FT15                                   ; no, so attempt to skip the removal

                SWI     XBuffer_Remove                          ; remove buffer, but ignore errors
                                                                ; (we've started closing so we'll finish!)

                Debug   close,"removed the buffer"

                MOV     r0, #0
                STR     r0, [fr, #file_MadeBuffer]
15
                MOV     r0, #-1
                STR     r0, [fr, #file_BufferHandle]            ; mark as buffer no longer important
 [ FastBufferMan
                STR     r0, [fr, #file_BufferPrivId]            ; nullify buffer manager private buffer id
 ]
20
                LDR     r2, [fr, #file_SpecialField]
                TEQ     r2, #0                                  ; is there an allocation for special field decoding?
                BEQ     %FT30

                MOV     r0, #ModHandReason_Free                 ; attempt to release it
                SWI     XOS_Module                              ; (again ignore errors, cos it's too late)

                MOV     r0, #0
                STR     r0, [fr, #file_SpecialField]            ; mark as now released incase called again
30
                LDR     r5, [fr, #file_Flags]                   ; get global flags word
                Debug   close,"file flags ", r5
                TST     r5, #ff_FileForTX                       ; is it for RX or TX?
                MOVEQ   r2, #0
                MOVNE   r2, #-1

                MOV     r0, #UpCall_StreamClosed
                MOV     r1, pr                                  ; -> parent record
                LDR     r3, [fr, #file_FSwitchHandle]
                SWI     XOS_UpCall                              ; broadcast to the UpCallV

                Debug   close,"broadcast UpCall_StreamClosed"

                Unlink  FilesAt, file, fr, r3, r4               ; unlink and free the file object (ignore errors)
                Free    fr

                TST     r5, #ff_FileForTX                       ; is it a TX file
                ADDEQ   r0, pr, #parent_UsedInputs
                ADDNE   r0, pr, #parent_UsedOutputs

                TST     r5, #ff_ModifiedCounters                ; had we actually modified the counters?
                LDRNE   r1, [r0]
                SUBNE   r1, r1, #1
                STRNE   r1, [r0]                                ; update the used inputs/outputs counters

                [ debug
                BEQ     %f40
                Debug   close,"number of used streams now ",r1
40
                ]

                LDR     fr, =&DEADDEAD                          ; invalidate the file record pointer

                CLRV
                EXIT

; external error

90
                Debug   close,"error removing file block"

                STR     r0, [sp]                                ; return an error to the outside world
                PullEnv
                SETV
                MOV     pc, lr

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_file
;
; This is used for reading information about devices and other data, only
; a couple of objects are supported within device fs.
;

fs_file         ROUT

                Debug   file, "fs_file called with reason code", r0
                Debug   fs, "fs_file ", r0

                CMP     r0, #fsfile_WriteInfo
                CMPNE   r0, #fsfile_WriteLoad
                CMPNE   r0, #fsfile_WriteExec
                CMPNE   r0, #fsfile_WriteAttr
                CMPNE   r0, #fsfile_Create
                MOVEQ   pc, lr                                  ; ignore all these

                CMP     r0, #fsfile_ReadInfo                    ; read info on a file?
                BNE     fs_badop                                ; no, then can't do any others, so error

; fsfile_ReadInfo

                Push    "dr, pr, lr"                            ; save dr, pr round call
                BL      findobject
                CMP     r0, #object_subdevice                   ; if a sub-device it doesn't exist
                MOVEQ   r0, #object_nothing                     ; for the purposes of OS_File 5
                Pull    "dr, pr, pc"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_func.
;
; Handle fs func operations within DeviceFS.
;

fs_func         ROUT

                Debug   func, "fs_func called with reason code", r0
                Debug   fs, "fs_func ", r0

                TEQ     r0, #fsfunc_ReadDirEntries              ; if directory enumeration then allow
                TEQNE   r0, #fsfunc_ReadDirEntriesInfo
                TEQNE   r0, #fsfunc_CatalogObjects
                BEQ     file_enumdir

                TEQ     r0, #fsfunc_Dir                         ; fault the following....
                TEQNE   r0, #fsfunc_Lib
                TEQNE   r0, #fsfunc_Cat
                TEQNE   r0, #fsfunc_Ex
                TEQNE   r0, #fsfunc_LCat
                TEQNE   r0, #fsfunc_LEx
                TEQNE   r0, #fsfunc_Info
                TEQNE   r0, #fsfunc_Opt
                TEQNE   r0, #fsfunc_Rename
                TEQNE   r0, #fsfunc_Access
                TEQNE   r0, #fsfunc_ReadDiscName
                TEQNE   r0, #fsfunc_ReadCSDName
                TEQNE   r0, #fsfunc_ReadLIBName
                TEQNE   r0, #fsfunc_SetContexts
                TEQNE   r0, #fsfunc_FileInfo
                BEQ     fs_badop

                CLRV
                MOV     pc, lr                                  ; others such as boot, shutdown are ignored


; Directory enumeration, this is quite a complex operation.  Firstly
; we need to match all objects the meet the specified path.  The handle
; returned for reading the next entry contains the counter for skipping
; entries that have been processed.
;
; The routine works like this:
;
; It locates an object that matches the specified path, if it has already
; seen this object (ie. skip counter is still +ve) then it will skip it
; and update the skip counter (subtract 1), this continues until the skip
; counter is equal to zero at which point data starts being returned.
;
; We then have an entry, we see if this record will fit into the specified
; buffer, if not then we return its handle (the skip pointer to get to this
; object).  When an item is written we then carry on scanning until the next
; object picked from the tree has a different leaf name to the one we last wrote,
; if this does not fit then we will return, and so on....
;
; Reading all objects beginning "$."
;
; Index         Name                    Written         Reason
; 0             $.aardvark              yes             unique
; 1             $.parallel.device       yes             unique
; 2             $.parallel.zoot         no              same path at top level
; 3             $.quick                 yes             unique
;

; in:   r0 = 14, 15 or 19
;       r1 -> directory name (not wildcarded any more)
;       r2 -> buffer for data
;       r3 = number of object names to read
;       r4 = index of first item to read in directory (0 => start of directory)
;       r5 = buffer length
;       r6 -> special field if present, else 0
;
; out:  r3 = number of names read
;       r4 = index of next item to read (-1 if you were at end and didn't return any this call ie r3=0)


file_enumdir    Entry   "r0-r2, r5-r7, dr, pr"

                CMP     r3, #0                                  ; if asking for none
                EXIT    EQ                                      ; then return straight away

                MOV     r2, r1                                  ; -> path to enumerate
                MOV     r1, #0                                  ; and broadcast it to all devices
                MOV     r0, #DeviceCall_EnumDir                 ; about to enumerate directory
                BL      CallDevice

                LDMIA   sp, {r0-r2}                             ; pull parameters (as CallDevice corrupts the important ones!)

                ADD     r5, r5, r2                              ; setup buffer end pointer

                DebugS  enumdir, "directory to enum ", r1
                Debug   enumdir, "record count", r3
                Debug   enumdir, "to", r2
                Debug   enumdir, "until", r5
                Debug   enumdir, "offset", r4
                DebugS  enumdir, "special field ", r6

                BL      skipdollar                              ; skip "$" or "$."

                MOV     r7, #0                                  ; setup the skip counter

                LDR     dr, DevicesAt                           ; -> start of the devices list
00
                SUBS    lr, r7, r4                              ; number returned so far (-ve => still skipping)
                CMPCS   lr, r3                                  ; if we've returned all the requested items
                BCS     %FT90                                   ; then setup skip counter and then return

                TEQ     dr, #0                                  ; end of the devices search?
                BEQ     %FT88                                   ; yes, so we didn't deliver all

                LDR     r0, [dr, #device_DeviceName]            ; -> start of the filename
                Push    "r1, r7"                                ; preserve for next record scan

                Debug   enumdir, "trying record at", dr
                DebugS  enumdir, "it has the following name ", r0

                LDRB    r7, [r1]                                ; if directory to scan = "$"
                TEQ     r7, #0
                BEQ     %FT12                                   ; then match anything
05
                LDRB    r6, [r0], #1
                LDRB    r7, [r1], #1                            ; get two characters?
                ASCII_UpperCase r6, lr
                ASCII_UpperCase r7, lr                                ; ensure they are the same case

                TEQ     r6, r7                                  ; are they the same character?
                BNE     %FT10                                   ; no, so skip

                TEQ     r7, #0                                  ; if haven't terminated
                BNE     %BT05                                   ; then loop, else directory was a file, so ignore
07
                Pull    "r1, r7"
                LDR     dr, [dr, #device_Next]
                B       %BT00

10
                TEQ     r7, #0                                  ; if end of match string?
                TEQEQ   r6, #"."                                ; and device name is a directory reference, then OK
                BNE     %BT07                                   ; else try again for next record

; we have a match; r0 -> leaf part of name

12
                Pull    "r1, r7"                                ; restore pushed registers
                MOV     lr, #0                                  ; zero length counter
15
                LDRB    r8, [r0, lr]
                ADD     lr, lr, #1                              ; no, so increase the index
                TEQ     r8, #0
                TEQNE   r8, #"."                                ; end of the leaf section to be copied?
                BNE     %BT15

                CMP     r7, r4                                  ; if current index is < than requested one
                BCC     %FT25                                   ; then don't copy record, but do skip all identical ones

                Debug   enumdir, "writing record at", r2
                Debug   enumdir, "length of leaf to be copied", lr

                Push    "lr"                                    ; save length indication

                ADD     lr, lr, r2                              ; buffer address + length of name (including null)
                LDR     r6, [sp, #4]                            ; reload type of operation
                CMP     r6, #fsfunc_ReadDirEntriesInfo          ; if ReadDirEntriesInfo
                ADDEQ   lr, lr, #&14+3                          ; then add length of faff
                ADDHI   lr, lr, #&1D+3                          ; if CatalogObjects then more faff
                BICCS   lr, lr, #3                              ; if not ReadDirEntries then word align it
                CMP     lr, r5                                  ; is there enough room to copy record?
                Pull    "lr", HI                                ; if not then restore stack
                SUBHI   lr, r7, r4                              ; and indicate number copied
                BHI     %FT90                                   ; and finish

                Push    "r0,r1, r3-r5, lr"

                CMP     r6, #fsfunc_ReadDirEntries
                BEQ     %FT20                                   ; if ReadDirEntries then don't output info

                TEQ     r8, #"."                                ; is it a directory or a device?
                MOVEQ   r1, #object_directory
                LDREQ   r3, =FileType_Data:SHL:8                ; setup objects type + file type
                MOVNE   r1, #object_file
                LDRNE   r3, =FileType_Device:SHL:8
                STR     r1, [r2, #&10]                          ; store its object type

                Debug   enumdir, "object type", r1
                Debug   enumdir, "file type (shifted left 8)", r3

                ORR     r3, r3, #&FF:SHL:24
                ORR     r3, r3, #&F0:SHL:16                     ; sure is a file type of a load address

                LDR     pr, [dr, #device_Parent]                ; load the parent pointer, to get time stamp

                ADD     r4, pr, #parent_TimeStamp
                LDMIA   r4, {r4, r5}                            ; get the the bits of the time stamp
                ORR     r3, r3, r5                              ; and munge byte 5 of the time stamp into the load address

                CMP     r6, #fsfunc_CatalogObjects
                STREQ   r4, [r2, #&18]                          ; store bottom 4 bytes of time
                STREQB  r5, [r2, #&1C]                          ; and top byte of time
                STREQ   dr, [r2, #&14]                          ; store device record as SIN

                Debug   enumdir, "load + exec", r3, r4

                STR     r3, [r2, #&00]
                STR     r4, [r2, #&04]                          ; write the load + exec addresses

                MOV     r3, #0
                STR     r3, [r2, #&08]                          ; and then write its length

                ADD     r4, pr, #parent_MaxInputs
                LDMIA   r4, {r4, r5}                            ; get the i/o stream counts

                TEQ     r4, #0                                  ; does this device have input streams?
                ORRNE   r3, r3, #read_attribute
                TEQ     r5, #0
                ORRNE   r3, r3, #write_attribute
                STR     r3, [r2, #&0C]

                Debug   enumdir, "attributes", r3

                CMP     r6, #fsfunc_CatalogObjects
                ADDNE   r2, r2, #&14                            ; r2 -> destination address for name section
                ADDEQ   r2, r2, #&1D
20
                LDRB    r4, [r0], #1
                TEQ     r4, #0
                TEQNE   r4, #"."
                MOVEQ   r4, #0
                STRB    r4, [r2], #1                            ; copy a section of the name down
                BNE     %BT20                                   ; and loop until all copied (null or '.')

                Pull    "r0,r1, r3-r5, lr"
                MOV     r2, lr                                  ; move buffer pointer on
                Pull    "lr"                                    ; restore length indication

; skip all following device names with same leading part as the object we've just returned
; eg if cataloguing "Serial" and just returned "fred" for "Serial.fred.jim"
; then skip "Serial.fred.nosbod", "Serial.fred.sheila" etc

25
                ADD     r7, r7, #1                              ; one more entry processed
                ADD     r0, r0, lr                              ; r0 -> "j" in "Serial.fred.jim"
                Push    "r1, r2"
                LDR     r1, [dr, #device_DeviceName]            ; r1 -> start of device name, eg "Serial.fred.jim"
30
                LDR     dr, [dr, #device_Next]
                TEQ     dr, #0                                  ; end of the list?
                BEQ     %FT40                                   ; then no more skips

                LDR     r2, [dr, #device_DeviceName]
                BL      CompareStrings                          ; compare r1, r2 up to but not including r0
                BEQ     %BT30                                   ; if the same then skip
40
                Pull    "r1, r2"
                B       %BT00


88
                CMP     lr, #0                                  ; if we didn't return any because there weren't any
                MOVLE   lr, #0
                MOVLE   r7, #-1                                 ; then return with -1 in r4
90
                MOV     r4, r7                                  ; return index of next item
                ADDS    r3, lr, #0                              ; number of items returned (V cleared!)
                EXIT                                            ; and then return quickly

                LTORG

; in:   R1 -> wildcarded pathname
; out:  R1 -> pathname, with "$." removed

skipdollar      Entry
                LDRB    lr, [r1]
                CMP     lr, #"$"
                EXIT    NE
                LDRB    lr, [r1, #1]
                CMP     lr, #" "
                ADDLS   r1, r1, #1              ; skip "$"
                CMP     lr, #"."
                ADDEQ   r1, r1, #2              ; skip "$."
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fs_gbpb
;
; Write multiple blocks of data to a stream, can assume that the device
; is buffered and write directly into the buffer as required.
;

fs_gbpb         ROUT

                Debug   gbpb, "fs_gbpb called with reason code", r0
                Debug   fs, "fs_gbpb ", r0
		[	debug
		Push	r0
		MOV	r0, sp
		Debug	fs, "entry sp", r0
		Pull	r0
		]

                TEQ     r0, #2
                TEQNE   r0, #4                                  ; is the operation valid?
                BNE     fs_badop                                ; no, so give an error

                TEQ     r0, #2
                BEQ     gbpb_put


; read a largish lump from the device.

gbpb_get        Entry   "r0-r3, fr, r9, pr"

                MOV     fr, r1                                  ; -> file record
                LDR     pr, [fr, #file_Parent]

                MOV     r0, #DeviceCall_WakeUpRX
                MOV     r1, pr
                LDR     r2, [fr, #file_InternalHandle]
                BL      CallDevice                              ; ensure wake for calling
                BVS     %FT90                                   ; return an error

                ADD     r1, sp, #CallerR2
                LDMIA   r1, {r2-r3}                             ; get entry registers

		LDR	r4, [fr, #file_Flags]
                B       %FT12

10
                BLVC    checkfileRXOK
                BVS     %FT90

                LDR     r1, [pr, #parent_Flags]
                TST     r1, #pf_MonitorEOF
                BEQ     %FT11

                MOV     r1, fr
                BL      checkeof
                BCS     %FT20

11
		TST	r4, #ff_NonBlocking			; is this stream non-blocking?
		BNE	%FT20					; if so, finish now

12
                BL      checkescape                             ; if escape not pressed
 [ FastBufferMan
                MOVVC   r0, #BufferReason_RemoveBlock
                LDR     r1, [fr, #file_BufferPrivId]            ; get buffer managers private buffer id
                CallBuffMan VC                                  ; r2,r3 already set up
 |
                LDR     r1, [fr, #file_BufferHandle]
                ORR     r1, r1, #1:SHL:31                       ; mark for a block transfer
                MOV     r9, #REMV                               ; vector to be called
                SWIVC   XOS_CallAVector                         ; then try remove
 ]
                BVS     %FT90                                   ; either escape pressed or REMV gave error

                TEQ     r3, #0                                  ; all the data obtained?
 [ TWSleep
                BEQ     %FT20
                LDR     r1, [fr, #file_PollWord]
                TEQ     r1, #ff_DontSleep
                BEQ     %BT10

;                MOV     r1, #ff_Sleeping                        ; reset pollword
;                STR     r1, [fr, #file_PollWord]

                BL      sleep_on_rx

                B       %BT10
 |
                BNE     %BT10                                   ; no, so loop again until done
 ]
20
                LDR     r4, [sp, #CallerR3]                     ; How many did we ask for?
                SUB     r4, r4, r3                              ; file ptr = 0 + initial request - amount left
                ADD     r0, sp, #CallerR2
                STMIA   r0, {r2-r3}                             ; stash register list

                MOV     r0, #DeviceCall_SleepRX
                MOV     r1, pr
                LDR     r2, [fr, #file_InternalHandle]
                BL      CallDevice                              ; call the device

                CLRV
                EXIT                                            ; yippee it all worked

; (external) error

90
                STR     r0, [sp, #CallerR0]                     ; stash error pointer

                LDR     r4, [sp, #CallerR3]
                SUB     r4, r4, r3
                ADD     r0, sp, #CallerR2
                STMIA   r0, {r2-r3}                             ; stash register list

                MOV     r0, #DeviceCall_SleepRX
                LDR     r1, [fr, #file_Parent]
                LDR     r2, [fr, #file_InternalHandle]
                BL      CallDevice                              ; hold on device, sleep for a little while

                PullEnv
                SETV
                MOV     pc, lr                                  ; return the error


; Give a huge lump of data to the device.

gbpb_put        Entry   "r0-r3, fr, r9"

		[		false
		Push		"r0-r3"

		;Check page 0 escape flag
                MOV		r0, #0
                LDRB		r0, [r0, #ESC_Status]
		BIC		r0, r0, #&CF
		Debug		fs, "ESC_Status", r0

		;Check SWI version of escape flag
		MOV		r1, #0
		SWI		XOS_ReadEscapeState
                ADC             r0, r1, #0
		Debug		fs, "ReadEscapeState", r0

		MOV		r0, #9 ;escape
		MOV		r2, #0
		MOV		r3, #0
		SWI		XOS_ChangeEnvironment
		Debug		fs, "esc handler", r1

		MOV		r0, #10 ;event
		MOV		r1, #0
		MOV		r2, #0
		MOV		r3, #0
		SWI		XOS_ChangeEnvironment
		Debug		fs, "event handler", r1

		Pull		"r0-r3"
		]

                MOV     fr, r1

		LDR	r4, [fr, #file_Flags]

 [ FastBufferMan
                LDR     r1, [fr, #file_BufferPrivId]            ; get buffer managers private buffer id
 |
                LDR     r1, [fr, #file_BufferHandle]
                ORR     r1, r1, #1:SHL:31                       ; it is a block insert
                MOV     r9, #INSV
 ]
		;Loop till data written
00
		Debug	fs, "fsgbpb_put", r3
                BLVC    checkescape
		DebugIf	VS, fs, "detected escape---purging output buffer"
		BLVS	purgeoutputbuffer
		BVS	%90

                BL      checkfileTXOK
		BLVS	purgeoutputbuffer			; if an error then purge output buffer
                BVS     %90

 [ FastBufferMan
                MOV	r0, #BufferReason_InsertBlock
                CallBuffMan					; r2,r3 already set up
 |
                SWI	XOS_CallAVector                         ; attempt to write the block to the device
 ]
                BVS     %90

		TST	r4, #ff_NonBlocking			; is this stream non-blocking?
		BNE	%FT02					; if so, finish now

                TEQ     r3, #0                                  ; all written yet?
 [ TWSleep
                BEQ     %01
                LDR     r0, [fr, #file_PollWord]
                TEQ     r1, #ff_DontSleep
                BEQ     %00

;                MOV     r1, #ff_Sleeping                        ; reset pollword
;                STR     r1, [fr, #file_PollWord]

                BL      sleep_on_tx

 [ FastBufferMan
                LDR     r1, [fr, #file_BufferPrivId]            ; get buffer managers private buffer id
 |
                LDR     r1, [fr, #file_BufferHandle]
                ORR     r1, r1, #1:SHL:31                       ; it is a block insert
 ]
                B       %00
01
 |
                BNE     %00
 ]
		Debug	fs, "fsgbpb_put done"

02
                LDR     r4, [sp, #CallerR3]                     ; How many did we ask for?
                SUB     r4, r4, r3                              ; how many we transferred
                ADDS    r0, sp, #CallerR2                       ; clears V
                STMIA   r0, {r2-r3}                             ; write the data to the return frame

		[	debug
		PullEnv
		Push	r0
		MOV	r0, sp
		Debug	fs, "gbpb no error---exit sp", r0
		Pull	r0
		MOV	pc, lr
		|
                EXIT                                            ; and then restore stack pointer
		]

; (external) error

90
                LDR     r4, [sp, #CallerR3]
                SUB     r4, r4, r3                              ; how many we transferred
                ADD     r1, sp, #CallerR2
                STMIA   r1, {r2, r3}                            ; setup the return frame parameters

                STR     r0, [sp]
                PullEnv
		[	debug
		Push	r0
		MOV	r0, sp
		Debug	fs, "gbpb error---exit sp", r0
		Pull	r0
		]
                SETV
                MOV     pc, lr                                  ; return the error

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: purgeoutputbuffer
;

 [ FastBufferMan

purgeoutputbuffer EntryS "r0"
; in:   r1 = buffer managers private buffer id
; out:  all registers preserved
                MOV     r0, #BufferReason_PurgeBuffer
                CallBuffMan
                EXITS

 |

purgeoutputbuffer EntryS "r0-r2,r9"
; in:   r1 = buffer handle
; out:  all registers preserved
                MOV     r9, #CNPV
                SETV                    ; indicate purge, not count
                SWI     XOS_CallAVector
                EXITS

 ]


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: findobject
;
; in:   r1 -> path of object to find
;
; out:  r0  = object type
;       r1 preserved
;       r2  = load address
;       r3  = execution address
;       r4  = file length
;       r5  = access attributes
;       dr -> device record
;       pr -> parent record
;
; This routine will locate an object within DeviceFS, the object is searched
; for and suitable data is returned about it, ie. its load, exec and attributes.
;
; The routine works by first checking to see if it is the root directory that is
; being searched for, if it is then the routine will return a wacky bit of information
; about it.  Otherwise it attempts to match the specified path to the list of devices,
; all devices are stored with the root included in their names (in the filename) we then
; match as much as possible, if a complete path is not specified, ie. a match is found that
; does not terminate at the final character of the path then the object is give
; a directory type, else it is given the device type. Also if the path
; specified is a sub-path of a device (eg $.Parallel.Fred), return object
; type object_subdevice.

findobject      Entry   "r1,r6,r7"

                BL      skipdollar

                LDRB    r0, [r1]                                ; are we matching the root directory?
                CMP     r0, #0                                  ; clears V for safety
                BEQ     %FT30                                   ; [filename is "$"]

                LDR     dr, DevicesAt                           ; -> start of devices list
00
                TEQ     dr, #0                                  ; end of the devices chain yet?
                MOVEQ   r0, #object_nothing
                EXIT    EQ                                      ; yes, so return that object not found

                LDR     r0, [dr, #device_DeviceName]            ; -> start of filename to be checked against
                MOV     r2, #0                                  ;  = index's into the filenames
10
                LDRB    r3, [r0, r2]
                LDRB    r4, [r1, r2]                            ; get two characters
                ASCII_UpperCase r3, lr
                ASCII_UpperCase r4, lr

                TEQ     r3, r4                                  ; are they the same?
                BEQ     %15                                     ; yes.

                TEQ     r3, #0                                  ; if device name has terminated
                TEQEQ   r4, #"."                                ; and user name has dot, then return subdevice type
                BEQ     %20

                TEQ     r4, #0                                  ; if user name has terminated
                TEQEQ   r3, #"."                                ; and device name has dot, then matched a director
                LDRNE   dr, [dr, #device_Next]                  ; if that fails then skip to the next record
                BNE     %00
15
                TEQ     r4, #0                                  ; end of the strings?
                ADDNE   r2, r2, #1                              ; no, so increase lengths to be valid
                BNE     %10
20
                LDR     pr, [dr, #device_Parent]                ; -> parent object thing...

                TEQ     r4, #0                                  ; if a subdevice (r4<>0)
                MOVNE   r0, #object_subdevice                   ; then return type subdevice
                MOVEQ   r0, #object_file                        ; otherwise assume type file for now
                LDR     r2, =(FileType_Device:SHL:8):OR:&FFF00000 ; setup file type accordingly

                TEQ     r3, #0                                  ; have we matched with an actual device?
                MOVNE   r0, #object_directory                   ; no, then is a directory above it
                LDRNE   r2, =(FileType_Data:SHL:8):OR:&FFF00000

                ADD     r3, pr, #parent_TimeStamp               ; -> parent time stamp
                LDMIA   r3, {r3, r4}
                ORR     r2, r2, r4                              ; munge into the bottom 8bits of the load address

                MOV     r4, #0                                  ; no length on DeviceFS objects
                MOV     r5, #0                                  ; and access attributes =0

                ADD     r6, pr, #parent_MaxInputs
                LDMIA   r6, {r6, r7}                            ; get the i/o stream counts

                TEQ     r6, #0                                  ; does this device have input streams?
                ORRNE   r5, r5, #read_attribute
                TEQ     r7, #0
                ORRNE   r5, r5, #write_attribute

                EXIT

; perform info on "$"

30
                MOV     r0, #object_directory
                MOV     r2, #0                                  ; no load address
                MOV     r3, #0                                  ; no exec address
                MOV     r4, #0                                  ; size is not important either
                MOV     r5, #read_attribute+ write_attribute
                MOV     dr, #0
                MOV     pr, #0                                  ; setup parent and device records
                EXIT                                            ; and return because "$" is a special case

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; handlespecial, this code handles the decoding of the special field block.
;
; This is actually performed within the special field parsing code which actually
; handles the decoding of the strings and setting up a return block.  This code
; will take the specified values and setup the file record to reflect the
; contents.
;

                        ^ 0, r6
sp_buffer               # 4             ; Buffer number
sp_block                # 4             ; blocking
sp_sleep                # 4             ; sleep
sp_timeout              # 4             ; time to sleep for
sp_size                 * :INDEX:@

; decoding validation string for internal commands.

internal        = "buffer/Nnoblock,block/Snosleep,sleep/Stimeout/N", 0
                ALIGN

HandleSpecial   Entry   "r0-r6"

                BL      DecodeSpecial
                STRVS   r0, [sp]
                BVS     %90                                     ; finished decoding because it went really wrong!

                LDR     r5, =&DEADDEAD
                STR     r6, [fr, #file_SpecialField]            ; -> decoded special field string

                LDR     r0, sp_buffer
                TEQ     r0, r5                                  ; did they specifiy a 'buffer/n' parameter
                BEQ     %10                                     ; obviously not....

                LDR     r1, [dr, #device_Flags]
                TST     r1, #df_BufferedDevice                  ; is the buffer allowed to be buffered?
                MOVEQ   r0, #-1                                 ; if not then stuff the user buffer handle
                STR     r0, [fr, #file_BufferHandle]
10
                LDR     r0, sp_block                            ; maybe set the non-blocking bit
                TEQ     r0, #0
                LDR     r0, [fr, #file_Flags]
                ORREQ   r0, r0, #ff_NonBlocking
                BICNE   r0, r0, #ff_NonBlocking                 ; "block" or unspecified
                STR     r0, [fr, #file_Flags]
 [ TWSleep
                LDR     r0, sp_sleep                            ; maybe set the sleeping word
                TEQ     r0, #1
                MOVEQ   r0, #ff_Sleeping
                MOVNE   r0, #ff_DontSleep                       ; "nosleep" or unspecified
                STR     r0, [fr, #file_PollWord]

                LDR     r0, sp_timeout                          ; set the timeout for sleeping
                TEQ     r0, r5
                MOVEQ   r0, #0
                STR     r0, [fr, #file_Timeout]
 ]
                ADD     r6, r6, #sp_size
                LDR     r0, [pr, #parent_Validation]
                CMP     r0, #0                                  ; do I need to pass the decoded block? (clears V)
                LDREQ   r6, [sp, #CallerR6]                     ; no, so -> original version
                STR     r6, [fr, #file_UserSpecialData]
90
                EXIT                                            ; V bit is set/clear as required by here



; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



                END
