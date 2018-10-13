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
; > DeviceFS (main code, module etc..)

; **********************
; ***  Changes List  ***
; **********************

; 02-Apr-91 0.00 DDV Some major redesign work.
; 04-Apr-91      DDV Implemented all device registering.
; 05-Apr-91      DDV Issuing of Service_DeviceFSStarting on a call back added.
; 05-Apr-91      DDV Started filing system bits, split to seperate file.
; 06-Apr-91      DDV Added time stamping device registration (parent), new filing system bits added.
; 06-Apr-91      DDV Added issuing of Service_DeviceFSDying (on reset/finalise)
; 07-Apr-91      DDV Finished directory enumeration.
; 07-Apr-91      DDV Now issues UpCalls to inform the outside world that things have changed.
; 07-Apr-91      DDV Directory structure sorting added.
; 08-Apr-91      DDV Sorted out duplicate files on enumeration, ie. $.test.fred, $.test.fred1 would result in two 'test' entries.
; 08-Apr-91 0.01 DDV Device_CallDevice added.
; 09-Apr-91      DDV Started opening, closing and general transfer operations.
; 09-Apr-91      DDV Changed Device_CallDevice to accept new wacky parameters.
; 09-Apr-91      DDV Called EnumDir event on internal update of dir structure, jumps and no longer issues SWI internally.
; 09-Apr-91      DDV Delinking any device object now remakes all links properly.
; 10-Apr-91      DDV All validation words reset when unlinked, as are original pointers (dr, fr and pr) -> &DEADDEAD
; 10-Apr-91      DDV Added full duplex device flagging and improved flags word validation.
; 10-Apr-91      DDV Added most of the file interfacing.
; 10-Apr-91      DDV Added GBPB calls, added DeviceFS_ReceivedByte and DeviceFS_TransmitByte.
; 11-Apr-91 0.02 DDV Internationalised.
; 11-Apr-91      DDV More robust version of BGET, BPUT and GBPB added.
; 11-Apr-91      DDV Added DeviceFS_Thresold and UpCall decoding added.
; 11-Apr-91 0.03 DDV Changed the handling of Service_Reset, now just marks vectors as not-owned.
; 12-Apr-91      DDV Event_DeviceOverRun added for non-buffered devices.
; 12-Apr-91      DDV Rationalised DeviceCalls, removing HaltRX/TX and ResumeRX/TX.
; 12-Apr-91      DDV Bug fix: service call issued corretly.
; 12-Apr-91      DDV Bug fix: stack inbalance.
; 12-Apr-91      DDV If device is TX and buffer wake up occurs then WakeUpTX sent.
; 12-Apr-91      DDV When last character removed from the buffer then marked as dormant.
; 13-Apr-91      DDV Changed sending of TX on buffered devices as handled above.
; 13-Apr-91      DDV Implementation of special fields added.
; 14-Apr-91      DDV Bug fix: checks r1 not r0 in service handling (international only)
; 14-Apr-91      DDV When device being removed it is called to close with an internal handle of zero.
; 15-Apr-91      DDV r5 on call to open stream on device =-1, no threshold if >-1 on return then threshold setup.
; 15-Apr-91      DDV Reordered the registers on pre-create calls for buffered devices.
; 16-Apr-91      DDV Issuing of stream created messages added.
; 16-Apr-91      DDV Intergration of special field handling finished.
; 16-Apr-91      DDV Bug fix: resets buffer handle to -1.
; 16-Apr-91 0.04 DDV Released for the 2.11 build.
; 18-Apr-91      DDV Copes better with duplicate devices.
; 18-Apr-91      DDV Calling Territory_Collate no longer relies on status of flags on exit.
; 18-Apr-91 0.05 DDV Tightened up the handling of message files.
; 20-Apr-91      DDV Intergrated issuing of Service_DeviceDead.
; 20-Apr-91      DDV Intergrated new special field handling code.
; 20-Apr-91      DDV Changed DeviceFS_DeviceDead; r3 contains 0 if parent else -> device name.
; 21-Apr-91      DDV Bug fix: Expansion of special field strings.
; 21-Apr-91      DDV Bug fix: Access attributes can now return wr, not just exclusing access for read or write.
; 21-Apr-91      DDV Bug fix: Special field parser now ensures that blocks are scanned correctly, skipping unused ones.
; 21-Apr-91      DDV Added decoding for user special fields, ie. passing through if -> 0.
; 21-Apr-91      DDV Improved decoding of my returned block.
; 21-Apr-91 0.06 DDV Removed handling for multiple buffers, cause to many problems.
; 25-Apr-91      DDV Bug fix: Stop non-buffered devices becoming buffered if buffer forced!
; 25-Apr-91      DDV Bug fix: TransmitCharacter no longer explodes on end-of-data.
; 30-Apr-91      DDV Improved linking and unlinking of blocks within the DeviceFS workspace.
; 30-Apr-91 0.07 DDV Bug fix: Deregister by name now works even if the parent handle is invalid.
; 01-May-91      DDV Bug fix: fs_close updates stream counters correctly.
; 01-May-91 0.08 DDV Changed so that set $path variables to include special fields.
; 14-May-91 0.09 DDV Added UpCall_StreamCreated/Closed.
; 31-May-91 0.10 TMD Fixed bug in service code, reorganise some code.
; 04-Jun-91      TMD Fixed bug in filename matching.
; 12-Jul-91      TMD Updated to work with new FileSwitch (filenames don't have "$" on them)
;                    Improved error tidying up in registerdev
; 16-Jul-91      TMD Fixed CallDevice, Threshold so they don't try to translate external errors.
;                    Made unknown SWI use global message
;                    Changed definition of <device>$Path to include a dot at the end.
; 22-Jul-91 0.11 TMD Fixed corruption of r9,r10 (dr,pr) on fs_file ReadInfo
; 29-Jul-91 0.12 TMD Changed wake up TX call to allow devices to stay dormant.
;                    Added reserved field to the device record.
; 31-Jul-91      TMD Service_Reset code only executed on soft reset.
; 01-Aug-91 0.14 TMD "Stream created" call now passes in buffer handle.
; 02-Aug-91      TMD Made Escape error use global message.
; 08-Aug-91      TMD Fixed bug in escape from BGET (returned VC)
; 13-Aug-91      TMD Fixed bug in UpCall handler which stored device's error pointer in wrong place on stack
; 14-Aug-91 0.15 TMD Fixed some erroneous error handling.
; 16-Aug-91      TMD Put in code to issue service to request closure of files.
;                    Changed DeviceFS_CallDevice to return all device's flags, not just V.
;                    Fixed bug that stopped wake-up calls happening.
; 07-Sep-91 0.16 TMD Optimised messages.
;                    Acknowledge escape before returning "Escape" error.
;                    Added stand-alone messages option.
;                    Also purges output buffer on escape from BPUT or GBPB.
; 20-Sep-91 0.17 TMD Fixed bug to do with getting used inputs/outputs wrong after offering
;                     Service_DeviceFSCloseRequest
; 21-Jan-92 0.18 TMD Fixed bug in ScanSpecial in alphabetic checking.
; 03-Feb-92 0.20 TMD Changed version number to be consistent with SrcFiler version.
; 03-Feb-92 0.21 JSR Adjust service call entry for changed Service_MessageFileClosed.
; 20-Feb-92 0.22 TMD Call Buffer_UnlinkDevice when stream closed.
;                    Made it refuse to detach from the buffer if stream is open (bug G-RO-9690).
; 20-Feb-92 0.23 TMD Made OS_GBPB read work, rather than storing the data at location zero.
; 21-Feb-92 0.24 TMD Made DecodeSpecial return errors correctly.
;                    Made ScanSpecial and handle_escape translate their errors.
; 06-Mar-92 0.25 TMD Added detach code which offers Service_DeviceFSCloseRequest.
; 09-Mar-92 0.26 TMD Don't unlink device when freeing file block if we never linked it!
; 03-Jun-93 0.27 SMC Use new buffer manager interface.
;                JSR Optimise CallBuffMan to call with LDMIA
;                    Fix bug in create buffer for TX to quote internal handle, not external one.
;                    Fix bug is fs_get where 2nd time round loop would try args_eof with a duff file handle.
;                    fs_get calls MonitorRX if goes round loop more than once.
;                    fs_put calls MonitorTX if goes round loop more than once.
;                    Fix bug in gbpb_get to not ignore checkescape.
;                    Add MonitorTX to gbpb_put and MonitorRX to gbpb_get.
;                    Fix bug in gbpb_put to not ignore checkescape.
;                    Add MonitorEOF flag to fs_get and fs_gbpb read.
;                    Fix bug in gbpb_put where escape got swallowed by purgebuffer.
;                    Ignore rather than return error on Args_SetEXT. This is to ensure
;                       compatibility with C file I/O.
; 07-Sep-93 0.28 SMC Escape now returns error number 17.
;                    Fixed bug in fs_put where Escape was ignored.
; 04-Feb-94 0.29 TMD Move GET hdr:Territory below GET hdr:NewErrors
; 26-Apr-96 0.30 RWB Implemented OS_Args 2 (Read open file extent) to return
;		     number of bytes in buffer.
; 30-Apr-96 0.31 RWB Implemented OS_Args 9 (IOCtl) to dispatch IOCtl reason call
;                    to underlying device driver.
; 14-May-96 0.32 RWB Overload OS_Args 2 to return free space in buffer if a tx
;		     stream.
; 22-May-96 0.33 RWB Issue an upcall when buffer becomes non-dormant.
;		     Issue upcalls with stream handle when thresholds are passed
; 14-Jun-96 0.34 RWB Pass file switch handle through to device driver during
;		     device initialisation.
; 16-Apr-97 0.35 BAL Added support for non-blocking block reads/writes. Fixed bug
;	  (ARTtmp)   in UpCall handler: send DeviceThreshold upcalls using OS_CallAVector
;		     instead of OS_UpCall so that interrupts aren't enabled.
; 29-Apr-97 0.35 JRC Fix some logic errors; add 'fs' debug flag; use local error buffer.
;         (Spinner)
; 19-May-97 0.36 KJB Merge two version 0.35s.
; 25-Feb-98 0.38 AR  Added checks to flush buffered output to avoid loops on blocked output (monitor TX) (from Spinner 0.36)
; 25-Feb-98 0.38 RWB,AR Fix bug introduced by previous fix for printing. (from Spinner 0.37)
; 05-Aug-99 0.46 KJB Service call table added.
; 04-May-01 0.56 DRE Added taskwindow sleeping
;

                GET     hdr:ListOpts
                GET     hdr:Macros
                GET     hdr:System
                GET     hdr:ModHand
                GET     hdr:PublicWS
                GET     hdr:FSNumbers
                GET     Hdr:HighFSI
                GET     hdr:LowFSI
                GET     hdr:MsgTrans
                GET     hdr:Buffer
                GET     hdr:DeviceFS
                GET     hdr:FileTypes
                GET     hdr:UpCall
                GET     hdr:Services
                GET     hdr:Symbols
                GET     hdr:Variables
                GET     hdr:NewErrors
                GET     hdr:Territory
                GET     hdr:NdrDebug
                GET     hdr:DDVMacros
                GET     hdr:Proc
                GET     hdr:ResourceFS

                GET     VersionASM
                GET     Version
                GET     Errors.s
                GET     Macros.s

                GBLL    standalonemessages
 [ :DEF: standalone
standalonemessages SETL standalone
 |
standalonemessages SETL {FALSE}
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; define register allocation
;

rf                      RN 11           ; -> Return frame
pr                      RN 10           ; -> Parent record
dr                      RN 9            ; -> Device record
fr                      RN 8            ; -> file record (only in file related calls)

; Define global workspace and constants.
;

                        ^ 0, wp
Flags                   # 4             ;  = global state flags used by module
ParentsAt               # 4             ; -> parents in chain
DevicesAt               # 4             ; -> first device in chain
FilesAt                 # 4             ; -> files list

 [ FastBufferMan
BuffManWkSpace          # 4             ; -> Buffer Manager workspace
BuffManService          # 4             ;  = address of Buffer Manager service routine
 ]

                      [ international
MessagesWorkspace       # 16            ; area used by message trans for opening files
error_buffer		# 256		; avoid MessageTrans error buffers
                      ]

workspace               * :INDEX: @

                        ^ 0
device_Next             # 4             ; -> next in link chain
device_Previous         # 4             ; <- previous link in the chain
device_ValidationWord   # 4             ;  = validation word for device records
device_Parent           # 4             ; -> parent record for device
device_NameLength       # 4             ;  = length of filename
device_DeviceName       # 4             ; -> device name
device_Flags            # 4             ;  = flags local to this device object
device_RXBufferFlags    # 4             ;  = RX buffer flags
device_RXBufferSize     # 4             ;  = RX buffer size
device_TXBufferFlags    # 4             ;  = TX buffer flags
device_TXBufferSize     # 4             ;  = TX buffer size
device_SIZE             * :INDEX: @

                        ^ 0
parent_Next             # 4             ; -> next in the parent list
parent_Previous         # 4             ; <- previous link in the parent list
parent_ValidationWord   # 4             ;  = validation word for parent record
parent_ChildCount       # 4             ;  = child count (ie. number of devices attached)
parent_Flags            # 4             ;  = flags for device
parent_EntryPoint       # 4             ;  = entry point for device
parent_PrivateWord      # 4             ;  = private word
parent_Workspace        # 4             ; -> workspace for device
parent_Validation       # 4             ; -> validation string
parent_MaxInputs        # 4             ;  = maximum number of inputs
parent_MaxOutputs       # 4             ;  = maximum number of outputs
parent_UsedInputs       # 4             ;  = used input count / =0 for none
parent_UsedOutputs      # 4             ;  = used outputs / =0 for none
parent_TimeStamp        # 8             ;  = 5 byte time stamp
parent_SIZE             * :INDEX: @

                        ^ 0
file_Next               # 4             ; -> next link in the chain of files
file_Previous           # 4             ; <- previous link in the chain of files
file_BufferHandle       # 4             ;  = buffer handle
file_Device             # 4             ; -> device record
file_Parent             # 4             ; -> parent record
file_RXTXWord           # 4             ;  = TX word / -1 if none
file_Flags              # 4             ;  = internal flags used on files
file_InternalHandle     # 4             ;  = handle used by device driver
file_SpecialField       # 4             ; -> munged special field
file_UserSpecialData    # 4             ; -> user special data blocks (as for parsed decoding)
file_MadeBuffer         # 4             ;  = <> 0 if made buffer, else already existed, so don't remove.
file_FSwitchHandle      # 4             ;  = fileswitch handle
 [ FastBufferMan
file_BufferPrivId       # 4             ;  = Buffer Managers private buffer id (for fast I/O)
 ]
 [ TWSleep
file_PollWord           # 4             ; pollword for taskwindow: 1 => don't call UpCall6, -1 => wakeup
file_Timeout            # 4             ; timeout for sleeping
 ]
file_Error              # 256           ; copy of error block
file_SIZE               * :INDEX: @

                        ^ 0             ; define format of parent device record (on entry to Register)
pr_Flags                # 4
pr_DeviceList           # 4
pr_DeviceEntry          # 4
pr_PrivateWord          # 4
pr_Workspace            # 4
pr_ValidationStringAt   # 4
pr_MaxTX                # 4
pr_MaxRX                # 4
pr_SIZE                 * :INDEX: @

                        ^ 0             ; define format of a device record (on entry to RegisterObject)
dr_DeviceNameOffset     # 4
dr_Flags                # 4
dr_DefaultFlagsRX       # 4
dr_DefaultSizeRX        # 4
dr_DefaultFlagsTX       # 4
dr_DefaultSizeTX        # 4
dr_Reserved             # 4
dr_SIZE                 * :INDEX: @


; define bit field constants

f_InUse                 * 1:SHL:0       ; bit 0  set => DeviceFS threaded, cannot die
f_CallBackPending       * 1:SHL:1       ; bit 1  set => Callback about the be granted
f_UpCallV               * 1:SHL:2       ; bit 2  set => UpCallV owned
f_WeHaveMessages        * 1:SHL:3       ; bit 3  set => messages file is open still

f_ResetMask             * f_UpCallV+ f_CallBackPending+ f_InUse

df_BufferedDevice       * 1:SHL:0       ; bit 0  set => Device can be buffered
df_SetupPathVariable    * 1:SHL:1       ; bit 1  set => Define <device>$Path variable
df_AllowedBits          * df_BufferedDevice+ df_SetupPathVariable

pf_BlockDevice          * 1:SHL:0       ; bit 0 set => Block device (ie. floppy driver)
pf_FullDuplex           * 1:SHL:1       ; bit 1 set => Device supports full duplex operation
pf_MonitorTransfers     * 1:SHL:2       ; bit 2 set => monitor transfers
pf_MonitorEOF           * 1:SHL:3       ; bit 3 set => monitor EOF during read
 [ issue_device_upcalls
pf_DeviceUpcalls	* 1:SHL:4	; bit 4 set => issue stream upcalls on buffer thresholding
pf_AllowedBits          * pf_BlockDevice+ pf_FullDuplex+ pf_MonitorTransfers+ pf_MonitorEOF+ pf_DeviceUpcalls
 |
pf_AllowedBits          * pf_BlockDevice+ pf_FullDuplex+ pf_MonitorTransfers+ pf_MonitorEOF
 ]

ff_FileInputOutput      * 1:SHL:0
ff_FileForTX            * 1:SHL:0       ; bit 0  set => TX
ff_FileForRX            * 0:SHL:0       ; bit 0 clear => RX
ff_NonBlocking		* 1:SHL:29	; bit 29 set => use non-blocking I/O for stream
ff_DeviceLinked         * 1:SHL:30      ; bit 30 set => buffer is linked to device
ff_ModifiedCounters     * 1:SHL:31      ; bit 31 set => modified usage counts

ff_Sleeping             * 0:SHL:0       ; significance of pollword
ff_WakeUp               * 1:SHL:0       ; bit 0 set => normal wakeup
ff_DontSleep            * 1:SHL:1       ; bit 1 set => don't go to sleep
ff_TimedOut             * 1:SHL:2       ; bit 2 set => transaction timed out
ff_Error                * 1:SHL:3       ; bit 3 set => error has occured

object_subdevice        * -1            ; object type returned by findobject if the path is
                                        ; an object inside a device eg "$.Parallel.Fred"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Now define module header.
;
                AREA      |DeviceFS$$Code|, CODE, READONLY, PIC
                ENTRY

module_start    & 0
                & init -module_start                            ; initialisation code
                & final -module_start                           ; finalisation code
                & service -module_start                         ; service handler

                & title -module_start                           ; title string address
                & help -module_start                            ; help string offset
                & 0

                & Module_SWISystemBase + DeviceFSSWI * Module_SWIChunkSize
                & swidespatch -module_start
                & switable -module_start
                & 0
                & 0                                             ; international meessages
        [ :LNOT: No32bitCode
                & ModuleFlags -module_start
        ]

help            = "DeviceFS", 9, "$Module_HelpVersion"
              [ debug
                = " Development version"
              ]
                = 0

fs_banner       = "Acorn "
title
switable        = "DeviceFS", 0
                = "Register", 0
                = "Deregister", 0
                = "RegisterObjects", 0
                = "DeregisterObjects", 0
                = "CallDevice", 0
                = "Threshold", 0
                = "ReceivedCharacter", 0
                = "TransmitCharacter", 0
                = 0

fs_name         = "devices", 0                                  ; filing system name

              [ international
                ! 0, "Internationalised version"
resource_file   = "Resources:$.Resources.DeviceFS.Messages", 0
              ]

devicevarbits   = "DeviceFS$", 0, "$$Options", 0                 ; DeviceFS$<device name>$Options
pathvarbits     = "$$Path", 0, "devices#<FileSwitch$$SpecialField>:$"
pathvarbits2    = ".", 0                                        ; used twice

set_filetype    = "Set File$$Type_FCC Device", 0                 ; setup variable for device file type

                ALIGN

                MakeErrorBlock DeviceFS_BadHandle
                MakeErrorBlock DeviceFS_InUse
                MakeErrorBlock DeviceFS_DeviceNotKnown
                MakeErrorBlock DeviceFS_DeviceInUse
                MakeErrorBlock DeviceFS_OnlyCharDevices
                MakeErrorBlock DeviceFS_BadReserved
                MakeErrorBlock DeviceFS_MustBeBuffered

        [ :LNOT: No32bitCode
ModuleFlags     DCD     ModuleFlag_32bit
        ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; This call handles the claiming of workspace by the module, we must first
; see if the private word is non-zero and only claim workspace if it
; is, then we reset the workspace as required.
;

init            Entry
                LDR     r2, [wp]
                TEQ     r2, #0                                  ; do we need to claim any workspace?
                BNE     %10

		[	debug
		Debug_Open	"<DevDebug>"
		]

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =workspace                          ; amount of workspace needed
                SWI     XOS_Module
                EXIT    VS

                STR     r2, [wp]                                ; setup private word to address workspace
10
                MOV     wp, r2                                  ; wp -> workspace

 [ standalonemessages
                ADRL    r0, resourcefsfiles
                SWI     XResourceFS_RegisterFiles   ; ignore errors (starts on Service_ResourceFSStarting)
 ]

                MOV     r0, #0
                STR     r0, Flags                               ; flags null
                STR     r0, ParentsAt
                STR     r0, DevicesAt                           ; no parents or devices present
                STR     r0, FilesAt
 [ FastBufferMan
                STR     r0, BuffManService
                STR     r0, BuffManWkSpace
 ]

                BL      StartFSystem                            ; attempt to register the filing system
                BL      SetupThreshold
                ADRVCL  r0, set_filetype                        ; attempt to setup alias for file type (device)
                SWIVC   XOS_CLI
                BLVC    StartCallBack                           ; issue start up callback (will return VC/VS -> error block)
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Finalise, this code handles the closing down of the module, this involves releasing
; any extra workspace and removing the filing system reference.
;

final           Entry
                LDR     wp, [wp]                                ; -> workspace

                LDR     r0, Flags
                TST     r0, #f_InUse                            ; is DeviceFS threaded?
                ADRNEL  r0, ErrorBlock_DeviceFS_InUse
                PullEnv NE
                DoError NE                                      ; ensure V set and return error

                TST     r0, #f_CallBackPending                  ; is a callback pending
                ADRNEL  r0, callback
                MOVNE   r1, wp
                SWINE   XOS_RemoveCallBack                      ; remove it

                LDR     r0, ParentsAt                           ; -> parents list (first item infact!)
00
                TEQ     r0, #0                                  ; do I have to remove anymore?
                BEQ     %10

                LDR     r1, [r0, #parent_Next]
                BL      Deregister                              ; deregister the device
                EXIT    VS                                      ; return any errors and abandon the device kill

                MOV     r0, r1                                  ; -> next device (loaded before the remove)
                B       %00
10
                MOV     r1, #Service_DeviceFSDying
                SWI     XOS_ServiceCall                         ; issue service call, asumes r0 is zero

                BL      RemoveFSystem                           ; remove the filing system
                BL      RemoveThreshold
              [ international
                BL      CloseMessages
              ]
 [ standalonemessages
                ADR     R0, resourcefsfiles
                SWI     XResourceFS_DeregisterFiles
 ]

		[	debug
		Debug_Close
		]
                CLRV
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Service handling, this traps things like the machine being reset and
; workspace moving around.
;

                ASSERT  Service_Reset       < Service_FSRedeclare
                ASSERT  Service_FSRedeclare < Service_ResourceFSStarting
servicetable    DCD     0
                DCD     serviceentry - module_start
                DCD     Service_Reset
                DCD     Service_FSRedeclare
 [ standalonemessages
                DCD     Service_ResourceFSStarting
 ]
                DCD     0

                DCD     servicetable - module_start
service         ROUT
                MOV     r0, r0
                TEQ     r1, #Service_FSRedeclare
                TEQNE   r1, #Service_Reset
 [ standalonemessages
                TEQNE   r1, #Service_ResourceFSStarting
 ]
                MOVNE   pc, lr

serviceentry    LDR     wp, [wp]                                ; wp -> workspace

 [ standalonemessages
                TEQ     r1, #Service_ResourceFSStarting
                BNE     %FT10
                Push    "r0-r3,lr"
                ADRL    r0, resourcefsfiles
                MOV     lr, pc
                MOV     pc, r2
                Pull    "r0-r3,pc"
10
 ]
                TEQ     r1, #Service_FSRedeclare                ; could it be a Service_FSRedeclare?
                BEQ     StartFSystem

; must be service reset

                Push    "r0-r2, lr"

                MOV     r0, #&FD                                ; read last reset type
                MOV     r1, #0
                MOV     r2, #&FF
                SWI     XOS_Byte
                TEQ     r1, #0

                Pull    "r0-r2, pc",NE                          ; if hard reset, do nothing

                LDR     r0, Flags
                BIC     r0, r0, #f_ResetMask
                STR     r0, Flags                               ; inform world that the objects have been removed

                BL      SetupThreshold

                Pull    "r0-r2, pc"

                GBLS    conditionalgetbodge
 [ standalonemessages
                GBLS    ApplicationName
ApplicationName SETS    "DeviceFS"
conditionalgetbodge SETS "GET s.ResFiles"
resourcefsfiles
 |
conditionalgetbodge SETS ""
 ]
                $conditionalgetbodge
 [ standalonemessages
                DCD     0
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handle the despatch of SWIs within the system, this simply involves resolving the
; private word pointer and then range checking the specified values.
;

swidespatch     ROUT

                LDR     wp, [wp]                                ; wp -> workspace

                CMP     r11, #(%10 -%00) /4                     ; is the modulo SWI number valid?
                ADDCC   pc, pc, r11, LSL #2
                B       %10

00              B       Register
                B       Deregister
                B       RegisterObj
                B       DeregisterObj
                B       CallDevice
                B       Threshold
                B       ReceivedChar
                B       TransmitChar
10
                ADR     r0, ErrorBlock_DeviceFS_BadSWI          ; return invalid SWI error
 [ international
                B       MakeErrorWithModuleName
 |
                RETURNVS
 ]

                MakeErrorBlock DeviceFS_BadSWI

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: StartCallBack
;
; in:   -
;
; out:  -
;
; This sets up a callback to be issued when the module has been added to the
; active module list.  By default the device is not linked correctly and
; SWIs issued will be ignored, this allows them to issue SWIs as when
; the callback is granted the module will be correctly linked.
;
; A flag is kept to ensure that the module does not die before the callback
; is granted, infact the callback is removed (via OS_RemoveCallBack).
;

StartCallBack   Entry   "r0,r1"
                ADR     r0, callback                            ; -> callback routine
                MOV     r1, wp
                SWI     XOS_AddCallBack
                LDRVC   r0, Flags                               ; mark as callback is pending
                ORRVC   r0, r0, #f_CallBackPending
                STRVC   r0, Flags
                EXIT


; this routine is called as the callback utility.
;

callback        Entry   "r0,r1"
                LDR     r0, Flags
                BIC     r0, r0, #f_CallBackPending
                STR     r0, Flags                               ; clear the callback bit
                MOV     r1, #Service_DeviceFSStarting
                SWI     XOS_ServiceCall                         ; issue the service call
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_Register
;
; in:   r0  = global flags for device
;                       bit 0 clear => character device
;                       bit 0 set => block device
;                       bit 1 clear => device is not full duplex
;                       bit 1 set => device is full duplex
;                       bit 2 clear => don't monitor transfers
;                       bit 2 set => monitor transfers
;
;       r1 -> list of devices to be installed
;                       +0   = offset to device name / =0 no more devices
;                       +4   = flags specific to this incarnation of the device
;                                       bit 0 clear => device not buffered
;                                       bit 0 set => device is buffered
;                                       bit 1 clear => don't setup a path variable for device
;                                       bit 1 set => setup a path variable for device
;
;                       +8   = default flags for the RX buffer of the device
;                       +12  = default size of RX buffers
;                       +16  = default flags for the TX buffer of the device
;                       +20  = default size of TX buffers
;
;                       .... repeating until first word =0.
;
;       r2 -> device entry point
;       r3  = private word
;       r4  = workspace pointer
;       r5 -> validation string / =0 none (pass through to caller)
;       r6  = maximum number of RX devices / =0 for none / =-1 unlimited
;       r7  = maximum number of TX devices / =0 for none / =-1 unlimited
;
; out:  V clear => r0 -> parent record (device handle)
;       V set => r0 -> error block
;
; This code will register the specified list of devices with the device filing system,
; a general record is created for the device and then each sub-device is register
; in a short loop.  If the register fails then the routine will attempt to
; remove all currently associated devices and then return.
;

Register        Entry   "r0-pr"
                MOV     pr, #0                                  ; no parent record yet

                Debug   register, "global flags word",r0
                Debug   register, "list of devices at", r1
                Debug   register, "device entry point", r2
                Debug   register, "private word", r3
                Debug   register, "workspace pointer", r4
                Debug   register, "validation string", r5
                Debug   register, "maximum number of TX devices", r6
                Debug   register, "maximum number of RX devices", r7

                TST     r0, #pf_BlockDevice                     ; is it a block device?
                ADRNEL  r0, ErrorBlock_DeviceFS_OnlyCharDevices
                BNE     %FT20

                BICS    r0, r0, #pf_AllowedBits
                ADRNEL  r0, ErrorBlock_DeviceFS_BadReserved     ; if the reserved bits are non-zero then error
                BNE     %FT20

                MOV     r0, #ModHandReason_Claim
                LDR     r3, =parent_SIZE
                SWI     XOS_Module                              ; attempt to allocate memory for the device
                BVS     %FT10                                   ; if was not possible so tidy and give error back

                MOV     pr, r2                                  ; -> parent record

                Debug   register, "parent block allocated at", r2

                ADRL    r0, Register
                STR     r0, [pr, #parent_ValidationWord]        ; validate block as owned by DeviceFS

                Debug   register, "validation word", r0

                Link    ParentsAt, parent, pr, r0

                MOV     r0, #0
                STR     r0, [pr, #parent_ChildCount]            ; and various other words
                STR     r0, [pr, #parent_UsedInputs]
                STR     r0, [pr, #parent_UsedOutputs]
                STR     r0, [pr, #parent_TimeStamp]
                STR     r0, [pr, #parent_TimeStamp +4]

                MOV     r0, #14
                ADD     r1, pr, #parent_TimeStamp
                MOV     r2, #3
                STRB    r2, [r1]                                ; [r1]  = 3, read time in 5 byte format
                SWI     XOS_Word                                ; via OsWORD
                BVS     %FT05

                LDMVCIA sp, {r0-r7}                             ; what did we have on entry?

                ADDVC   lr, pr, #parent_Flags
                STMVCIA lr, {r0, r2-r7}                         ; write previous flags + new wacky bits of information

                MOVVC   r0, pr                                  ; r0 -> parent record (device handle)
                BLVC    RegisterObj                             ; register the list of devices
                BVC     %FT15
05
                Push    "r0"
                MOVS    r0, pr
                BLNE    Deregister                              ; if it errored then attempt to remove records
                Pull    "r0"                                    ; preserved r0 and ensure that V set
10
                SETV                                            ; ensure that V set
15
                STR     r0, [sp]
                PullEnv
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

; internal error

20
                STR     r0, [sp]
                PullEnv
                DoError

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_Deregister
;
; in:   r0 -> parent record
;
; out:  V clear => device deregistered (all preserved)
;       V set => r0 -> error block.
;
; Remove all devices attached to the parent record.  Then remove device record, will
; give an error if the device is currently linked to anything after all sub-devices
; have been removed, this should close all file objects.
;

Deregister      Entry   "r0-dr"
                MOV     pr, r0                                  ; pr -> parent record (we hope!)

                LDR     r0, [pr, #parent_ValidationWord]
                ADRL    r1, Register
                TEQ     r0, r1                                  ; is it a valid parent block?
                ADRNEL  r0, ErrorBlock_DeviceFS_BadHandle
                BNE     %20                                     ; no, so give an error

                LDR     r1, DevicesAt                           ; -> first block of devices chain
00
                TEQ     r1, #0                                  ; have we finished looking at devices yet?
                BEQ     %05

                LDR     r2, [r1, #device_Parent]
                TEQ     r2, pr                                  ; is the device owned by me?
                LDR     r2, [r1, #device_Next]                  ; get next device pointer no matter what
                BNE     %01

                BL      deregisterdev
                BVS     %10                                     ; should hopefully not give a fatal error (if it does tough!)
01
                MOV     r1, r2
                B       %00                                     ; setup new pointer and loop again
05
                LDR     r0, [pr, #parent_ChildCount]
                TEQ     r0, #0                                  ; have things become really wacky
                ADDR    r0, ErrorBlock_DeviceFS_DeviceInUse, NE
                BNE     %20                                     ; yes, so give an error because child count is non-zero

                MOV     r0, #DeviceCall_Finalise
                MOV     r1, pr
                MOV     r2, #0                                  ; =0, close all streams!
                BL      CallDevice
                BVS     %10                                     ; return any errors that may generate

                Unlink  ParentsAt, parent, pr, r3, r4

                MOV     r0, #0
                LDR     r1, =Service_DeviceDead
                MOV     r2, pr
                MOV     r3, #0                                  ; parent device dying (not a sub-device)
                SWI     XOS_ServiceCall

                LDR     r3, =&DEADDEAD
                STR     r3, [pr, #parent_ValidationWord]        ; zap validation word
                Free    pr
                BVS     %FT10
                MOV     pr, r3

                PullEnv
                RETURNVC                                        ; yippee it all worked ok so return no errors

; external error

10
                STR     r0, [sp]
                PullEnv
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

; internal error

20
                STR     r0, [sp]                                ; store r0 on return frame
                PullEnv                                         ; and return with the V flag set
                DoError                                         ; return an error 'cos it went wrong

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++





; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_RegisterObj
;
; in:   r0 -> parent record
;       r1 -> list of devices to be registed with device (see Register call)
;
; out:  V clear => all devices registered.
;       V set => devices not registered (none will have been registered)
;
; This code will register a list of devices with the specified device record,
; the routine appends them all to the device record specified in r0.
;
; If for any reason this call should fail then the routine will deregister
; the list of devices specified to be registered - eh?!
;

RegisterObj     Entry   "r0-pr"
                MOV     pr, r0                                  ; r0 -> parent record

                LDR     r0, [pr, #parent_ValidationWord]
                ADRL    r2, Register
                TEQ     r0, r2                                  ; is the validation word valid?
                ADRNEL  r0, ErrorBlock_DeviceFS_BadHandle
                BNE     %FT20                                   ; no, so give error because handle is duff
00
                LDR     r0, [r1]
                TEQ     r0, #0                                  ; have we reached the end of the block?
                PullEnv EQ
                RETURNVC EQ                                     ; return because it worked correctly

                BL      registerdev                             ; local register (accepts pr -> parent record)
                ADDVC   r1, r1, #dr_SIZE
                BVC     %BT00                                   ; loop until all possible objects registered

                LDR     r2, [sp, #CallerR1]
                Push    "r0"                                    ; preserve error pointer
05
                LDR     r1, [r2]                                ; end of the object tree?
                TEQ     r1, #0
                Pull    "r0", EQ
                BEQ     %FT10                                   ; yes, so return the error

                ADD     r1, r1, r2                              ; -> device name to remove
                BL      deregisterdev
                ADD     r2, r2, #dr_SIZE
                B       %BT05                                   ; deregistered that doofer so loop (ignoring errors)

; external error

10
                STR     r0, [sp]
                PullEnv
                RETURNVS

; internal error

20
                STR     r0, [sp]
                PullEnv
                DoError                                         ; return error, r0 -> token block

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: registerdev
;
; in:   r1 -> device record to be registered
;       pr -> parent record to associate it with
;
; out:  V clear => device registered
;       V set => r0 -> error block.
;
; This call will register the specified device with the parent object.  It is
; assumed that the parent record pointer has first been validated.  The link
; is built into the device list, the child count is increased and any
; required system variables are defined.
;

registerdev     Entry   "r0-r7, fr, dr"

                LDR     r2, [r1, #dr_DeviceNameOffset]
                ADD     r2, r2, r1                              ; -> device name

                DebugS  registerdev, "attempting register ", r2
                Debug   registerdev, "parent", pr

                Push    "r1"

                MOV     r1, r2
                BL      deregisterdev                           ; attempt to deregister it
                BVC     %FT05                                   ; if that worked then skip error check

                LDR     lr, =ErrorNumber_DeviceFS_DeviceNotKnown
                LDR     r1, [r0]                                ; get error number from the block
                TEQ     r1, lr                                  ; is it an allowed error?
                CLRV    EQ                                      ; yes, so ensure that V clear
05
                Pull    "r1"
                BVS     %FT98                                   ; report the error

                LDR     r0, [r1, #dr_Flags]                     ; get flags
                BICS    r0, r0, #df_AllowedBits                 ; see if any illegal bits
                ADRNEL  r0, ErrorBlock_DeviceFS_BadReserved     ; invalid bit field so complain!
                BNE     %FT99

                Debug   registerdev, "attempting to make device record"

                MOV     r4, r2                                  ;  = start length of the name
10
                LDRB    r0, [r2], #1
                TEQ     r0, #0                                  ; end of title?
                BNE     %BT10                                   ; loop until end reached

                SUB     r4, r2, r4                              ; get length
                MOV     r3, #device_SIZE                        ; length of device block

                Debug   registerdev, "block size needed", r3
                Debug   registerdev, "title length", r4

                MOV     r0, #ModHandReason_Claim
                SWI     XOS_Module
                BVS     %FT98

                MOV     dr, r2                                  ; setup the device record pointer

                Debug   registerdev, "device record at", dr

                ADR     r0, registerdev
                STR     r0, [dr, #device_ValidationWord]        ; validate the block now its linked to the list

                Debug   registerdev, "validation word for device", r0

                STR     pr, [dr, #device_Parent]                ; setup parent record pointer
                STR     r4, [dr, #device_NameLength]            ; store the length of the name

                ASSERT  dr_DeviceNameOffset = 0
                ASSERT  dr_Flags = 4
                ASSERT  dr_DefaultFlagsRX = 8
                ASSERT  dr_DefaultSizeRX = 12
                ASSERT  dr_DefaultFlagsTX = 16
                ASSERT  dr_DefaultSizeTX = 20
                LDMIA   r1, {r0, r2-r6}
                ADD     r0, r0, r1                              ; make name pointer absolute
                ADD     r1, dr, #device_DeviceName

                DebugS  registerdev, "device name is ", r0
                Debug   registerdev, "flags", r2
                Debug   registerdev, "default RX buffer flags", r3
                Debug   registerdev, "default RX buffer size", r4
                Debug   registerdev, "default TX buffer flags", r5
                Debug   registerdev, "default TX buffer size", r6

                ASSERT  device_Flags         = device_DeviceName + 4
                ASSERT  device_RXBufferFlags = device_DeviceName + 8
                ASSERT  device_RXBufferSize  = device_DeviceName + 12
                ASSERT  device_TXBufferFlags = device_DeviceName + 16
                ASSERT  device_TXBufferSize  = device_DeviceName + 20
                STMIA   r1, {r0, r2-r6}                         ; and write the block back into my record block

                Debug   registerdev, "parents device count", r0

                LDR     r3, [dr, #device_NameLength]            ; calculate the amount of space needed for names + paths
                ADD     r3, r3, r3, LSL #1                      ; 3 copies of device name needed
                ADD     r3, r3, #(?devicevarbits)+(?pathvarbits)+2*(?pathvarbits2) ; plus all the surrounding bits
                                                                ; (NB a bit of spurious space reserved for some
                                                                ; of the intermediate nulls, but who cares!)
                MOV     r0, #ModHandReason_Claim
                SWI     XOS_Module                              ; claim this block from the RMA
                BVS     %FT95                                   ; if failed then free device record block then error

                MOV     r7, r2                                  ; -> block claimed

                Debug   registerdev, "temp block at", r7

                ADRL    r0, devicevarbits
                MOV     r1, r7
                BL      CopyNoTerm
                Push    "r0"
                LDR     r0, [dr, #device_DeviceName]
                BL      CopyNoTerm
                Pull    "r0"
                BL      CopyString                              ; r7 -> 'DeviceFS$<device name>$Options'

                MOV     r6, r1

                LDR     r0, [dr, #device_DeviceName]
                BL      CopyNoTerm
                ADRL    r0, pathvarbits
                BL      CopyString                              ; r6 -> '<device name>$Path>
                MOV     r5, r1
                BL      CopyNoTerm
                LDR     r0, [dr, #device_DeviceName]
                BL      CopyNoTerm
                ADRL    r0, pathvarbits2
                BL      CopyString                              ; r5 -> 'devices#<FileSwitch$SpecialField>:$.<device name>.'
                SUB     r8, r1, r5                              ;  = length of string to set up for path variable

                DebugS  registerdev, "options var name", r7
                DebugS  registerdev, "path name ", r6
                DebugS  registerdev, "path to be set to ", r5

                MOV     r0, r7                                  ; -> device options variable name
                MOV     r1, #0
                MOV     r2, #-1                                 ; = -1, check to see if it exists
                MOV     r3, #0
                MOV     r4, #VarType_Expanded
                SWI     XOS_ReadVarVal

                Debug   registerdev, "was the options var already setup", r2

                TEQ     r2, #0                                  ; was the variable already defined? (does not break VC)
                BNE     %FT20

                Debug   registerdev, "attempting to reset it, it was not"

                MOV     r0, r7
                SUB     r1, r6, #1                              ; -> null (used for terminating second var string)
                MOV     r2, #0                                  ;  = length of variable (not used, but mustn't be -ve)
                MOV     r3, #0
                MOV     r4, #VarType_String
                SWI     XOS_SetVarVal                           ; try and setup the variable
                BVS     %FT90                                   ; if failed then free temp area + device block
20
                Debug   registerdev, "attempting to define the path is needed"

                LDR     r0, [dr, #device_Flags]
                TST     r0, #df_SetupPathVariable               ; should I define a path variable?
                BEQ     %FT30

                Debug   registerdev, "registering path variable"

                MOV     r0, r6
                MOV     r1, r5                                  ; -> contents of the variable
                MOV     r2, r8                                  ;  = length of variable to define
                MOV     r3, #0
                MOV     r4, #VarType_Macro
                SWI     XOS_SetVarVal                           ; and attempt to define it
                BVS     %FT90                                   ; returning any errors if they are generated
30
                Debug   registerdev, "finished setting up"

                MOV     r0, #ModHandReason_Free
                MOV     r2, r7
                SWI     XOS_Module                              ; attempt to free temp area claimed earlier

                Debug   registerdev, "about to sort device"

                BL      InsertDeviceIntoList                    ; insert new device into list (preserving
                                                                ; case-insensitive ASCII sort order)

                Debug   registerdev, "finished sorting device"

                LDR     r0, [pr, #parent_ChildCount]
                ADD     r0, r0, #1
                STR     r0, [pr, #parent_ChildCount]            ; increase the parents child count

                MOV     r0, #upfsfile_Create
                BL      IssueUpCall                             ; directory structure has now changed

                Debug   registerdev, "finished registering the device"

                PullEnv
                RETURNVC                                        ; it has worked so return with all preserved + V clear.

; free temporary block and device block, then report external error

90
                Push    "r0"
                MOV     r0, #ModHandReason_Free
                MOV     r2, r7
                SWI     XOS_Module                              ; free my temporary block
                Pull    "r0"                                    ; but ensure that I preserve the original error pointer

; free device block, then report external error

95
                Push    "r0"
                MOV     r0, #ModHandReason_Free
                MOV     r2, dr
                SWI     XOS_Module
                Pull    "r0"

; just report external error, if there is one

98
                STRVS   r0, [sp]
                PullEnv
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

; just report internal error

99
                STR     r0, [sp]
                PullEnv
                DoError                                         ; return an error to the caller

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_DeregisterObj
;
; in:   r0 -> parent record
;       r1 -> device name of the object to remove
;
; out:  V clear => device has been deregistered.
;       V set => device could not be deregistered.
;
; This call will remove a device from the parent specified, this involves searching
; for the device and closing the links around it.  Upon doing this we then
; unset all associated system variables and tidy up memory as required.
;

DeregisterObj   Entry   "r0-pr"

                MOV     pr, r0                                  ; setup parent record

                LDR     r0, [pr, #parent_ValidationWord]
                ADRL    r2, Register
                CMP     r0, r2                                  ; is the parent record handle valid?
                ADRNEL  r0, ErrorBlock_DeviceFS_BadHandle
                BNE     %FT99                                   ; if not report internal error
                BLVC    deregisterdev                           ; if validation did not fail then remove object
                EXIT    VC

                STR     r0, [sp]                                ; stash error pointer if it went wrong
                PullEnv
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

; report internal error

99
                STR     r0, [sp]
                PullEnv
                DoError                                         ; return the error correctly

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: deregisterdev
;
; in:   r1 -> name of device to be deregistered / -> device record
;       pr -> parent record
;
; out:  V clear => object has been removed
;       V set => unable to deregister object, r0 -> possible error block
;
; This routine will deregister the specified device, the device can be specified
; by name or an internal name pointer (used to simplify things).  The routine
; first validates the record pointer, if it is a record pointer then it will
; not attempt to search for the object, the validation is done via checking
; the validation word and the parent pointer.
;
; If the words do not match then we will attempt to search for the name specified
; at r1, this is done by scanning the list of devices and performing a string
; compare on each name, only devices with matching parent words are checked.
;
; When a device is found (to be valid and have a matching name) then the
; block is unlinked from the chain, any system variables are unset and then
; memory if freed.
;
; It is important to note that the options variable is not removed, this remains
; intact to enable a device being loaded to adopt the configuration being
; used currently.
;

deregisterdev   Entry   "r0, r2-r5, pr"

                Debug   deregister, "device to be deregister", r1
                Debug   deregister, "parent is", pr

              [ NoUnaligned
                ; If r1 is a pointer to a string there's no guarantee it will be word aligned
                ASSERT (device_ValidationWord :AND: 3) = 0
                ASSERT (device_Parent :AND: 3) = 0
                TST     r1, #3
                LDREQ   r0, [r1, #device_ValidationWord]
                ADREQL  r2, registerdev                         ; is it a valid block pointer (ie. validation word valid)
                TEQEQ   r0, r2
              |
                LDR     r0, [r1, #device_ValidationWord]
                ADRL    r2, registerdev                         ; is it a valid block pointer (ie. validation word valid)
                TEQ     r0, r2
              ]
                LDREQ   r0, [r1, #device_Parent]                ; is it owned by the correct parent?
                TEQEQ   r0, pr
                MOVEQ   dr, r1                                  ; it was valid so setup the pointer to the device record
                BEQ     %11                                     ; and do not attempt to perform a name search.

                DebugS  deregister, "asked to deregister under name ", r1

                LDR     dr, DevicesAt                           ; r0 -> devices list
00
                TEQ     dr, #0                                  ; end of the list yet?
                ADREQL  r0, ErrorBlock_DeviceFS_DeviceNotKnown
                BEQ     %30                                     ; yes and no match so return an (internal) error

                LDR     r0, [dr, #device_DeviceName]
                MOV     r2, r1                                  ; -> name and temporary copy of my one

                DebugS  deregister, "name to device looking for", r2
                DebugS  deregister, "name of device matching against", r0
10
                LDRB    r3, [r2], #1
                LDRB    r4, [r0], #1
                ASCII_UpperCase r3, lr
                ASCII_UpperCase r4, lr                                ; ensure characters of same case

                TEQ     r3, r4
                LDRNE   dr, [dr, #device_Next]
                BNE     %00                                     ; if not the same character then try next record

                TEQ     r3, #0                                  ; end of string?
                BNE     %10                                     ; nope, so carry on checking

                LDR     pr, [dr, #device_Parent]                ; pr -> parent record
11
                LDR     r0, [dr, #device_Flags]
                TST     r0, #df_SetupPathVariable               ; is a path variable defined?
                BEQ     %15

                Debug   deregister, "unsetting path variable"

                MOV     r0, #ModHandReason_Claim
                LDR     r3, [dr, #device_NameLength]
                ADD     r3, r3, #?pathvarbits
                SWI     XOS_Module                              ; get some workspace to build strings in
                BVS     %20                                     ; that failed so return suitable error

                Debug   deregister, "temp block lives at", r2

                MOV     r5, r2                                  ; -> workspace obtained

                LDR     r0, [dr, #device_DeviceName]
                MOV     r1, r5
                BL      CopyNoTerm                              ; copy device name (without terminator) to buffer
                ADRL    r0, pathvarbits
                BL      CopyString                              ; and terminate with suitable '$Path'

                DebugS  deregister, "unsetting ", r5

                MOV     r0, r5                                  ; -> variable to be removed
                MOV     r2, #-1
                MOV     r3, #0
                SWI     XOS_SetVarVal                           ; attempt to remove the variable

                MOV     r0, #ModHandReason_Free
                MOV     r2, r5
                SWI     XOS_Module                              ; and release the block of workspace
15
                Unlink  DevicesAt, device, dr, r3, r4           ; and then remove the block

                LDR     r0, [pr, #parent_ChildCount]
                SUB     r0, r0, #1
                STR     r0, [pr, #parent_ChildCount]            ; decrease the child count

                Debug   deregister, "updated child count", r0

                MOV     r0, #0
                MOV     r1, #Service_DeviceDead
                LDR     r2, [dr, #device_Parent]
                LDR     r3, [dr, #device_DeviceName]
                SWI     XOS_ServiceCall                         ; issue service to tell world that device dead

                Debug   deregister, "service call issued"

                LDR     r3, =&DEADDEAD
                STR     r3, [dr, #device_ValidationWord]        ; zap validation word
                Free    dr
                BVS     %FT20
                MOV     dr, r3

                MOV     r0, #upfsfile_Delete
                BL      IssueUpCall                             ; inform outside world that directory structure changed

                Debug   deregister, "UpCall issued to refresh directory viewers"

                PullEnv
                RETURNVC                                        ; it worked so ensure that V clear.

20
                STR     r0, [sp]
                PullEnv
                RETURNVS

30
                STR     r0, [sp]
                PullEnv
                DoError                                         ; return error

                LTORG

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_CallDevice
;
; in:   r0  = reason code
;       r1 -> parent record (device handle)
;          -> path (can include "$.")
;           = 0 broadcast to all devices
;
;   r2..r7  = parameters passed to device
;       wp -> workspace
;
; out:  V clear, registers setup as defined by call
;       V set, r0 -> error block.
;
; This code handles broadcasting to various devices to inform them of what is going
; on in the outside world.  The routine should not assume anything about the way that it
; is being called as it is called from various areas within the module.
;

CallDevice      ROUT

                Push    "r1, r8-wp, lr"
                SavePSR lr

                TEQ     r1, #0                                  ; is it a broadcast?
                BNE     %20

                BIC     lr, lr, #V_bit                          ; ensure V clear for return
                Push    "lr"
                LDR     r1, ParentsAt                           ; -> parents list
10
                TEQ     r1, #0                                  ; does a valid record exist?
                BNE     %FT15
                Pull    "lr"
                RestPSR lr
                Pull    "r1, r8-wp, pc"                         ; broadcasts never return errors

15
                BL      CallDevice                              ; oopsy doopsy re-enter to call device
                ADDVS   sp, sp, #4                              ; trash stacked PSR
                BVS     %90

                LDR     r1, [r1, #parent_Next]                  ; assuming it worked get the next parent pointer
                B       %10                                     ; and loop again
20
              [ NoUnaligned
                ; If r1 is a pointer to a string there's no guarantee it will be word aligned
                ASSERT (parent_ValidationWord :AND: 3) = 0
                TST     r1, #3
                LDREQ   r8, [r1, #parent_ValidationWord]
                ADREQL  r9, Register                            ; -> validation word
                TEQEQ   r8, r9                                  ; are they the same?
              |
                LDR     r8, [r1, #parent_ValidationWord]
                ADRL    r9, Register                            ; -> validation word
                TEQ     r8, r9                                  ; are they the same?
              ]
                MOVEQ   pr, r1
                BEQ     %40                                     ; yes, so issue call to this doofer!

                LDR     r8, DevicesAt                           ; -> head of devices list
30
                TEQ     r8, #0                                  ; end of the list?
                Pull    "r1, r8-wp, lr", EQ
                ADREQL  r0, ErrorBlock_DeviceFS_DeviceNotKnown
                DoError EQ                                      ; return the error

                LDRB    r9, [r1]
                TEQ     r9, #"$"
                LDREQB  r9, [r1, #1]
                TEQEQ   r9, #"."                                ; is it prefixed with "$."
                ADDEQ   r1, r1, #2                              ; sure is bob so lets skip the suckers!

                LDR     r9, [r8, #device_DeviceName]
                MOV     r12, r1                                 ; -> name to be scanned
35
                LDRB    r10, [r9], #1
                LDRB    r11, [r12], #1                          ; get two characters
                ASCII_UpperCase r10, lr
                ASCII_UpperCase r11, lr                               ; ensure they are a valid case

                TEQ     r10, r11                                ; are they the same character?
                LDRNE   r8, [r8, #device_Next]                  ; no, so reset the device pointer
                BNE     %30                                     ; and then try another device

                TEQ     r10, #0
                BNE     %35                                     ; if not end of string then loop again

                LDR     pr, [r8, #device_Parent]                ; -> parent record to be called
40
                LDR     r8, [pr, #parent_PrivateWord]
                LDR     wp, [pr, #parent_Workspace]             ; setup important registers

                CLRV                                            ; ensure V clear on entry to device driver
		[	debug
		Debug	fs, "*reason", r0
		LDR	lr, [pr, #parent_EntryPoint]
		Debug	fs, "*call", lr
		]
                MOV     lr, pc
                LDR     pc, [pr, #parent_EntryPoint]            ; jump into device driver
		[	debug
		BVC	%80
		ADD	r0, r0, #4
		DebugS	fs, "*device driver returned error", r0
		SUB	r0, r0, #4
		Debug	fs, "*error buffer", r0
		B	%90
80
		Debug	fs, "*ok"
		]
90
                Pull    "r1, r8-wp, pc"                         ; exit with current NZCV flags, either from device or
                                                                ; indicating error

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_Threshold
;
; in:   r1  = external handle (from DeviceFS on open)
;       r2  = eight bit threshold value to be used / -1 to read
;
; out:  V set, r0 -> error block
;       V clear, preserved.
;
; This call can be used to set the threshold associated with a buffered
; device.
;

Threshold       Entry   "r0-r3"
                LDR     r0, [r1, #file_BufferHandle]
                CMP     r0, #-1                                 ; is the object buffered?
                ADREQL  r0, ErrorBlock_DeviceFS_MustBeBuffered
                BEQ     %90                                     ; return an error if not buffered

                MOV     r1, r2                                  ; setup threshold value to be used
                SWI     XBuffer_Threshold
                STRVC   r1, [sp, #CallerR2]                     ; if it worked write return value and exit
                STRVS   r0, [sp]                                ; return external error
                PullEnv
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

90
                STR     r0, [sp]
                PullEnv
                DoError                                         ; return any errors generated

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SetupThreshold.
;
; This code sets up the vector interception of UpCallV for trapping calls
; to modify the threshold state.  These calls are then mapped onto the
; file handle and then issue and event to the actual device.
;

SetupThreshold  Entry   "r0-r3"
                LDR     r3, Flags
                TST     r3, #f_UpCallV                          ; do I currently own the UpCallV?
                EXIT    NE                                      ; yes, so don't claim again

                MOV     r0, #UpCallV
                ADR     r1, UpCall                              ; -> routine
                MOV     r2, wp                                  ; -> workspace
                SWI     XOS_Claim
                ORRVC   r3, r3, #f_UpCallV
                STRVC   r3, Flags                               ; mark as currently owning the vector

                STRVS   r0, [sp]
                EXIT                                            ; return any errors generated

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RemoveThreshold
;
; This code handles the removal of the threshold routine from within
; devicefs.
;

RemoveThreshold Entry   "r0-r3"
                LDR     r3, Flags
                TST     r3, #f_UpCallV                          ; do I currently have an claim on UpCallV
                EXIT    EQ                                      ; and then return

                MOV     r0, #UpCallV
                ADR     r1, UpCall                              ; -> routine to remove
                MOV     r2, wp
                SWI     XOS_Release
                BICVC   r3, r3, #f_UpCallV
                STRVC   r3, Flags                               ; save the modified flags word

                STRVS   r0, [sp]
                EXIT                                            ; return corrected registers

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Handling of UpCalls.  We are only interested in two UpCalls, these map to
; the halt and resume calls for devices.
;
; The routine needs to match the specified buffer handle to the
; relevant file record and then issue the request to halt or resume.
;

UpCall          ROUT

                TEQ     r0, #UpCall_BufferFilling
                TEQNE   r0, #UpCall_BufferEmptying
                MOVNE   pc, lr                    ; quick check to see if mine

                Push    "r0-r4,pr"

                LDR     r3, FilesAt               ; -> start of the file list
00
                TEQ     r3, #0                    ; end of the files list?
                Pull    "r0-r4,pr", EQ
                MOVEQ   pc, lr                    ; yes, so unstack and then exit

                LDR     pr, [r3, #file_BufferHandle]
                TEQ     pr, r1                    ; is it our buffer?
                LDRNE   r3, [r3, #file_Next]
                BNE     %00                       ; loop until all checked
 [ TWSleep
                LDR     r1, [r3, #file_PollWord]  ; if we're sleeping,
                TEQ     r1, #ff_DontSleep         ;  then
                MOVNE   r1, #ff_WakeUp            ; set the pollword
                STRNE   r1, [r3, #file_PollWord]  ; to wake up a sleeper
 ]

                TEQ     r0, #UpCall_BufferFilling
                MOVEQ   r0, #DeviceCall_Halt
                MOVNE   r0, #DeviceCall_Resume    ; convert to an understandable device call

                LDR     r1, [r3, #file_Parent]
                LDR     r2, [r3, #file_InternalHandle]
                BL      CallDevice
                STRVS   r0, [sp]                  ; write the error address to frame

 [ issue_device_upcalls
; check to see if device driver wants these upcalls forwarding
		BVS	%10
		LDR	pr, [r3, #file_Parent]
		LDR	r1, [pr, #parent_Flags]
		TST	r1, #pf_DeviceUpcalls
		BEQ	%10
; now issue upcalls based on stream handle
; must use OS_CallAVector here _NOT_ OS_UpCall: OS_UpCall enables interrupts (contrary to
; documentation in RISC OS 3 PRMs) - if the UpCall has come as a result of Dual Serial
; removing a byte from the buffer then this will cause reentrancy problems in Dual Serial
; resulting in out-of-order bytes.
		Push	"r9"
                TEQ     r0, #DeviceCall_Halt
                MOVEQ   r0, #UpCall_DeviceThresAbove
                MOVNE   r0, #UpCall_DeviceThresBelow
                LDR     r1, [r3, #file_FSwitchHandle]
		MOV	r9, #UpCallV
		SWI	XOS_CallAVector
		Pull	"r9"
                STRVS   r0, [sp]
10
 ]
                Pull    "r0-r4,pr, lr"            ; balance stack (pull extra one to claim vector)
                RETURNVC VC                                     ; conditional ensures optimal 32-bit code
                RETURNVS VS                                     ; conditional ensures optimal 32-bit code

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_ReceivedCharacter
;
; in:   r0  = byte received
;       r1 -> external handle (from DeviceFS on open)
;
; out:  C set, if byte not transfered, else C clear.
;
; This call is made from the device to DeviceFS to transfer a byte, the
; routine will attempt to insert the data into the buffer.  Although if
; the device is not buffered then it will simply attempt to store it
; away.
;

ReceivedChar    Entry   "r0-r3, fr, r9"

                SavePSR lr
                BIC     lr, lr, #C_bit                          ; clear C bit from saved PSR
                Push    "lr"

                MOV     fr, r1                                  ; -> file record

                LDR     r1, [fr, #file_BufferHandle]
                CMP     r1, #-1                                 ; is a buffer allocated?
                BNE     %20                                     ; yes, so handle as a buffered device

                LDR     r1, [fr, #file_RXTXWord]
                STR     r0, [fr, #file_RXTXWord]                ; get old and store new

                CMP     r1, #-1                                 ; did we over run?
                BEQ     %10

                MOV     r0, #Event_DeviceOverRun                ; r0  = event number (Event_DeviceOverRun)
                LDR     r1, [fr, #file_Parent]                  ; r1  = parent handle (device handle)
                LDR     r2, [fr, #file_FSwitchHandle]           ; r2  = stream handle (from file switch)
                MOV     r3, #0                                  ; r3  = reserved word
                SWI     XOS_GenerateEvent
                BVS     %90                                     ; if it goes sprong then return an error
10
                Pull    "lr"
                RestPSR lr                                      ; make sure C clear on exit
                EXIT

; buffered stream

20
 [ FastBufferMan
                MOV     r2, r0                                  ; want byte to insert in r2
                MOV     r0, #BufferReason_InsertByte
                LDR     r1, [fr, #file_BufferPrivId]            ; buffer managers private buffer id
                CallBuffMan
 |
                MOV     r9, #INSV
                SWI     XOS_CallAVector                         ; attempt to insert into the vector
                BVS     %90                                     ; return any errors from the SWI
 ]
                Pull    "lr"
                ORRCS   lr, lr, #C_bit                          ; guaranteed C_bit is clear
                RestPSR lr                                      ; reflect the C bit correctly
                EXIT

90
                STR     r0, [sp, #4]!                           ; trash stacked PSR
                EXIT                                            ; V must be set to get to here

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DeviceFS_TransmitCharacter
;
; in:   r1  = external handle
;
; out:  C clear;
;               r0  = character to transmit (8 bits)
;       C set;
;               unable to read character to be transmitted
;
;       V set, r0 -> error block!
;
; This call gets a character from DeviceFS that can then be transmitted to
; the outside world.  The routine first checks to see if the device
; is buffered, if not then it will attempt to read the transmit.
;

TransmitChar    Entry   "r1-r3, fr, r9"

                SavePSR lr
                BIC     lr, lr, #C_bit :OR: V_bit               ; clear C and V from return PSR
                Push    "lr"

                MOVS    fr, r1                                  ; -> file record
                MOVEQ   r0, #-1
                BEQ     %30                                     ; return closing stream

                LDR     r1, [fr, #file_BufferHandle]
                CMP     r1, #-1                                 ; is the file buffered?
                BNE     %10                                     ; yes, so attempt to remove from the buffer

                LDR     r0, [fr, #file_RXTXWord]
                CMP     r0, #-1                                 ; is there a character pending?
                MOVNE   r1, #-1
                STRNE   r1, [fr, #file_RXTXWord]                ; if we got a character then reset to -1

                B       %30
10
 [ FastBufferMan
                MOV     r0, #BufferReason_RemoveByte
                LDR     r1, [fr, #file_BufferPrivId]            ; buffer managers private buffer id
                CallBuffMan
                MOVCC   r0, r2
 |
                CLRV
                MOV     r9, #REMV
                SWI     XOS_CallAVector                         ; attempt to remove a character
 ]
 [ debug
                BCS     %FT20
                Debug   transmitchar, "buffer man returned CC"
                B       %FT25
20
                Debug   transmitchar, "buffer man returned CS"
25
 ]
                MOVCS   r0, #-1
30
                Debug   transmitchar, "character", r0

                Pull    "lr"
                CMP     r0, #&100
                BCC     %FT40                                   ; if valid (<256) then clear C and V
                ORR     lr, lr, #C_bit
                CMP     r0, #-1                                 ; is it a buffer empty?
                ORRNE   lr, lr, #V_bit                          ; no, so set V

40
                RestPSR lr
                EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; call: InsertDeviceIntoList
;
; in:   dr -> device record
;
; out:  -
;
; Insert device record dr into the device list, at the correct position to maintain
; case-insensitive ASCII order.
;

InsertDeviceIntoList EntryS "r0-r3"

                Debug   sorting, "about to sort devices"

                LDR     r1, [dr, #device_DeviceName]            ; r1 -> new device's name

                MOV     r0, #0                                  ; r0 -> previous
                LDR     r3, DevicesAt                           ; r3 -> this
10
                TEQ     r3, #0                                  ; end of list?
                BEQ     %FT20                                   ; if so, insert here

                Push    "r0"
                MOV     r0, #-1                                 ; silly value for end of string check
                LDR     r2, [r3, #device_DeviceName]
                BL      CompareStrings
                Pull    "r0"
                BCC     %FT20                                   ; if new name < this name, insert here

                MOV     r0, r3                                  ; new name >= this name, so skip to next
                LDR     r3, [r3, #device_Next]
                B       %BT10

20
                STR     r3, [dr, #device_Next]                  ; set up next[this] and previous[this]
                STR     r0, [dr, #device_Previous]              ; before inserting into list

                TEQ     r0, #0                                  ; if there is a previous
                STRNE   dr, [r0, #device_Next]                  ; then next[previous] := this
                STREQ   dr, DevicesAt

                TEQ     r3, #0                                  ; if there is a next
                STRNE   dr, [r3, #device_Previous]              ; then previous[next] := this

                EXITS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; copy string from r0 -> r1, until last character is a null.  breaks r2
;

CopyString      LDRB    r2, [r0], #1
                STRB    r2, [r1], #1
                TEQ     r2, #0
                BNE     CopyString
                RETURN

; copy string with no null termination, ie. don't write null, r0 -> r1. breaks r2
;

CopyNoTerm      LDRB    r2, [r0], #1
                TEQ     r2, #0
                STRNEB  r2, [r1], #1
                BNE     CopyNoTerm
                RETURN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
;       CompareStrings - Compare two strings (case insensitive on top-bit-clear chars)
;
; in:   r1 -> first string  (null terminated)
;       r2 -> second string (null terminated)
;       r0 -> position in r1 string to stop comparison just before
;
; out:  nZCv if r1 = r2
;       nzCv if r1 > r2
;       Nzcv if r1 < r2
;

CompareStrings Entry "r0-r3"
10
        CMP     r1, r0          ; if reached end of comparison
        EXIT    EQ              ; then say they're equal
        LDRB    r0, [r1], #1
        LDRB    r3, [r2], #1
        ASCII_UpperCase r0, lr
        ASCII_UpperCase r3, lr
        CMP     r0, r3
        EXIT    NE              ; if strings differ then Z=0, N,C from CMP, V=0 (from CMP)
        TEQ     r0, #0          ; have both strings terminated?
        BNE     %BT10           ; if not, then loop
        EXIT                    ; strings are equal, N=0,Z=1 (from TEQ), C=1,V=0 (from CMP)


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Generalised internationalisation routines, these ensure that messages files
; are correctly opened and then return the relevant data.
;
              [ international


; Attempt to open the messages file.

OpenMessages    Entry   "r0-r3"

                LDR     r3, Flags
                TST     r3, #f_WeHaveMessages                   ; do we have an open messages block?
                EXIT    NE                                      ; yes, so don't bother again

                ADR     r0, MessagesWorkspace
                ADRL    r1, resource_file                       ; -> path to be opened
                MOV     r2, #0                                  ; allocate some wacky space in RMA
                SWI     XMessageTrans_OpenFile
                LDRVC   r3, Flags
                ORRVC   r3, r3, #f_WeHaveMessages
                STRVC   r3, Flags                               ; assuming it worked mark as having messages
                EXIT                                            ; returning VC, VS from XSWI!


; Attempt to close the messages file.

CloseMessages   Entry   "r0"
                LDR     r0, Flags
                TST     r0, #f_WeHaveMessages                   ; do we have any messages?
                EXIT    EQ                                      ; and return if not!

                ADR     r0, MessagesWorkspace
                SWI     XMessageTrans_CloseFile                 ; yes, so close the file
                LDRVC   r0, Flags
                BICVC   r0, r0, #f_WeHaveMessages
                STRVC   r0, Flags                               ; mark as we don't have them
                EXIT


; Generate an error based on the error token given.  Does not assume that
; the messages file is open.  Will attempt to open it, then look it up.

MakeErrorWithFS_name Entry "r1-r7"
                ADRL    r4, fs_name
                B       MakeErrorEntry

MakeErrorWithModuleName ALTENTRY
                ADRL    r4, title
                B       MakeErrorEntry


MakeError       ALTENTRY
                MOV     r4, #0
MakeErrorEntry
                BL      OpenMessages

                LDR     r1, Flags
                TST     r1, #f_WeHaveMessages
                PullEnv EQ
                RETURNVS EQ                                     ; if still not open then return with V set

                ADR     r1, MessagesWorkspace                   ; -> message control block
		[	true
		ADR	r2, error_buffer
		MOV	r3, #?error_buffer
		|
                MOV     r2, #0                                  ; no substitution + use internal buffers
                MOV     r3, #0
		]
                MOV     r5, #0
                MOV     r6, #0
                MOV     r7, #0
                SWI     XMessageTrans_ErrorLookup

                BL      CloseMessages                           ; attempt to close the doofer
                SETV

                EXIT                                            ; return, r0 -> block, V set

              ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                GET     FSystem.s
                GET     Special.s


              [ debug                                           ; if a debugging version, then include debugging code
                InsertNDRDebugRoutines
XDebugIt_WriteC   * &4ba82
              ]

                LTORG

                END

