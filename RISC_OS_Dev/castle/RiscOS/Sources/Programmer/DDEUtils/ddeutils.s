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
; Title:   s.ddeutils
; Purpose: Assembler source for DDEUtils module
;

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Services
        GET     Hdr:OSRSI6
        GET     Hdr:PublicWS
        GET     Hdr:HighFSI
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:Wimp
        GET     Hdr:MsgTrans
        GET     Hdr:ModHand
        GET     hdr.DDEUtils
        GET     VersionASM

; JRF: Debugging. Turn this off for ROMing
                  GBLL  Debug
Debug             SETL  {FALSE};{TRUE};
; use hal_debugtx for debug output
                  GBLL  HALDebug
HALDebug          SETL  {TRUE};{FALSE}

; JRF: Switch added to allow longer filenames to be 'handled'. This may
;      not necessarily fix all the problems that DDEUtils has with them,
;      but will alleviate the majority. Problems may still lie in the
;      throwback handler.
                  GBLL  LongFilenames
LongFilenames     SETL  {TRUE}

; JRF: Set this to the length of filenames that is the maximum you wish
;      to handle
 [ LongFilenames
FilenameLength        * 1024
 |
FilenameLength        * 256
 ]

; JRF: Turn this on and all prefixes passed will be canonicalised for you
                  GBLL  CanonicalisePath
CanonicalisePath  SETL  {TRUE}

; JRF: We should /really/ be checking the strings fit our CL buffer!
                  GBLL  CheckBufferSize
CheckBufferSize   SETL  {TRUE}

                  GBLL  AllowDirChanging
AllowDirChanging  SETL  {TRUE}

; JRF: Allow a lot of the later image file extensions
;      This has NOT been tested and it's a little too late to add them
                  GBLL  HandleImages
HandleImages      SETL  {FALSE}

; DDEUtils error codes
ddeutils_errbase      * ErrorBase_AcornDDE
                      ^ ddeutils_errbase
unk_swi_error         # 1
no_cli_buffer_error   # 1
not_desktop_error     # 1
no_task_error         # 1
already_reg_error     # 1
not_reg_error         # 1
buffer_too_short      # 1

; DDEUtils messages
ddeutils_msgbase             * DDEUtilsSWI_Base
                             ^ 0
msg_throwback_start          # 1
msg_throwback_processingfile # 1
msg_throwback_errorsin       # 1
msg_throwback_errordetails   # 1
msg_throwback_end            # 1
msg_throwback_infoforfile    # 1
msg_throwback_infodetails    # 1

; DDEUtils workspace
                  ^     0, r12
chain             #     4
fname_buffer      #     4
cli_buffer        #     4
cli_size          #     4
receiver_id       #     4
wimp_domain       #     4
workspace_end     #     0

; DDEUtils linked list member
                  ^     0
o_next            #     4
o_wimpdomain      #     4
o_prefix          #     4

        AREA    |ddeutils$$module|, CODE, READONLY

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Header
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
module_start
        DCD     0                          ; Run
        DCD     init - module_start        ; Init
        DCD     finish - module_start      ; Finish
        DCD     service - module_start     ; Service call
        DCD     title - module_start       ; Title
        DCD     help - module_start        ; Help
        DCD     cmd_table - module_start   ; *commands
        DCD     DDEUtilsSWI_Base           ; SWI Base
        DCD     do_swi - module_start      ; SWI Handler
        DCD     swi_table - module_start   ; SWI Table
        DCD     0                          ; SWI Decoder
        DCD     0                          ; Messages filename
        DCD     flags - module_start       ; Module flags

help
        DCB     "DDEUtils", 9
        DCB     Module_MajorVersion, " (", Module_Date, ")", 0
      [ Module_MinorVersion <> ""
        DCB     " ", Module_MinorVersion
      ]
        DCB     0

title
        ; Share title with SWI table
swi_table
        DCB     "DDEUtils", 0
        DCB     "Prefix", 0
        DCB     "SetCLSize", 0
        DCB     "SetCL", 0
        DCB     "GetCLSize", 0
        DCB     "GetCl", 0                 ; Lowercase 'L'? Go figure.
        DCB     "ThrowbackRegister", 0
        DCB     "ThrowbackUnRegister", 0
        DCB     "ThrowbackStart", 0
        DCB     "ThrowbackSend", 0
        DCB     "ThrowbackEnd", 0
        DCB     "ReadPrefix", 0
        DCB     "FlushCL", 0
        DCB     0

cmd_table
        DCB     "Prefix", 0
        ALIGN
        DCD     prefix_cmd - module_start
        DCB     0                          ; Min. parameters
        DCB     1                          ; GSTrans map
        DCB     1                          ; Max. parameters
        DCB     0                          ; Flags
        DCD     prefix_syn - module_start  ; Syntax message
        DCD     prefix_help - module_start ; Help message
        DCD     0                          ; End of command table

prefix_help
        DCB     "*Prefix selects a directory as the current directory unique to the currently executing "
        DCB     "task. *Prefix with no arguments sets the current directory back to the systemwide "
        DCB     "default (as set with *Dir).", 13

prefix_syn
        DCB     "Syntax: *Prefix [<directory>]", 0
        ALIGN

flags
        DCD     ModuleFlag_32bit

ursservtab
        ASSERT  Service_Reset < Service_WimpCloseDown
        DCD     0                          ; Flags
        DCD     ursservice - module_start
        DCD     Service_Reset
        DCD     Service_WimpCloseDown
        DCD     0                          ; Terminator
        DCD     ursservtab - module_start  ; Anchor
service
        MOV     r0,r0                      ; Magic instruction for Ursula despatcher
        TEQ     r1, #Service_Reset
        TEQNE   r1, #Service_WimpCloseDown
        MOVNE   pc,lr
ursservice
        ; Service_Reset
        TEQ     r1, #Service_Reset
        LDREQ   r12,[r12]
        BEQ     reset
        ; else Service_WimpCloseDown
        CMP     r0, #0
        MOVNE   pc, lr
        STMFD   sp!, {r0, lr}
        MOV     r0, #0
        SWI     XDDEUtils_Prefix
        LDMFD   sp!, {r0, pc}

reset
        ; Really should clear the chain here...
        STMFD   sp!, {r0, lr}
        BL      claimvectors
        LDMFD   sp!, {r0, pc}

filetype_fd3
        DCB     "File$$Type_FD3", 0
debimage
        DCB     "DebImage", 0
runtype_fd3
        DCB     "Alias$@RunType_FD3", 0
debugaif
        DCB     "DebugAIF %*0", 0
loadtype_fd3
        DCB     "Alias$@LoadType_FD3", 0
loadaif
        DCB     "Load %0 8000", 0
filetype_fe1
        DCB     "File$$Type_FE1", 0
makefile
        DCB     "Makefile", 0
runtype_fe1
        DCB     "Alias$@RunType_FE1", 0
make
        DCB     "DDE:!Make %*0", 0
prefix_dir
        DCB     "Prefix$$Dir", 0
        ALIGN

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Initialisation and finalisation
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
init
        STMFD   sp!, {r7, r8, r9, r10, r11, lr}
        ADR     r0, filetype_fd3
        ADR     r1, debimage
        BL      initvar
        ADR     r0, runtype_fd3
        ADR     r1, debugaif
        BL      initvar
        ADR     r0, loadtype_fd3
        ADR     r1, loadaif
        BL      initvar
        ADR     r0, filetype_fe1
        ADR     r1, makefile
        BL      initvar
        ADR     r0, runtype_fe1
        ADR     r1, make
        BL      initvar

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #:INDEX: workspace_end
        SWI     XOS_Module                 ; claim our module workspace
        STRVC   r2,[r12]
        MOVVC   r12,r2

        MOVVC   r0, #0
        STRVC   r0, chain
        STRVC   r0, cli_buffer
        STRVC   r0, cli_size
        STRVC   r0, receiver_id

        BVS     %FT10
        MOV     r0, #6
        MOV     r1, #0
        MOV     r2, #OSRSI6_DomainId
        SWI     XOS_ReadSysInfo
        MOVVS   r2, #0
        TEQ     r2, #0
        LDREQ   r2, =Legacy_DomainId
        STR     r2, wimp_domain

        BL      claimvectors
        MOVVC   r0, #ModHandReason_Claim
        MOVVC   r3, #FilenameLength * 2
        SWIVC   XOS_Module
        STRVC   r2, fname_buffer
        ADRVC   r0, prefix_dir
        ADRVC   r1, prefix_dir_code
        MOVVC   r2, #prefix_dir_code_end - prefix_dir_code
        MOVVC   r3, #0
        MOVVC   r4, #VarType_Code
        SWIVC   XOS_SetVarVal
10
        LDMFD   sp!, {r7, r8, r9, r10, r11, lr}
xferv
        TEQ     pc, pc
        MOVEQ   pc, lr
        ORRVS   lr, lr, #V_bit
        MOVS    pc, lr

xfervc
        TEQ     pc, pc
        MOVEQ   pc, lr
        BIC     lr, lr, #C_bit
        ORRCS   lr, lr, #C_bit
        ORRVS   lr, lr, #V_bit
        MOVS    pc, lr

claimvectors
        STMFD   sp!, {r2, r3, lr}
        MOV     r2,r12
        MOV     r0, #FileV
        TEQ     pc, pc
        ADREQL  r1, file_handler_32
        ADRNEL  r1, file_handler_26
        SWI     XOS_Claim
        MOVVS   r3, r0
        BVS     %FT01
        MOV     r0, #GBPBV
        TEQ     pc, pc
        ADREQL  r1, gbpb_handler_32
        ADRNEL  r1, gbpb_handler_26
        SWI     XOS_Claim
        MOVVS   r3, r0
        BVS     %FT02
        MOV     r0, #FindV
        TEQ     pc, pc
        ADREQL  r1, find_handler_32
        ADRNEL  r1, find_handler_26
        SWI     XOS_Claim
        MOVVS   r3, r0
        BVS     %FT03
        MOV     r0, #FSCV
        TEQ     pc, pc
        ADREQL  r1, fscontrol_handler_32
        ADRNEL  r1, fscontrol_handler_26
        SWI     XOS_Claim
        MOVVS   r3, r0
        BVS     %FT04
        LDMFD   sp!, {r2,r3,pc}

        ; these are the failure cases
04
        MOV     r0, #FindV
        TEQ     pc, pc
        ADREQL  r1, find_handler_32
        ADRNEL  r1, find_handler_26
        SWI     XOS_Release
03
        MOV     r0, #GBPBV
        TEQ     pc, pc
        ADREQL  r1, gbpb_handler_32
        ADRNEL  r1, gbpb_handler_26
        SWI     XOS_Release
02
        MOV     r0, #FileV
        TEQ     pc, pc
        ADREQL  r1, file_handler_32
        ADRNEL  r1, file_handler_26
        SWI     XOS_Release
01
        MOV     r0,r3
        LDMFD   sp!, {r2,r3,lr}
        B       return_setv

prefix_dir_code
        B       dir_code_write
        ; prefix_dir read code
        ; <= r0-> value
        STR     lr, [sp, #-4]!
        MOV     r0,#0
        SWI     XDDEUtils_ReadPrefix
        MOVVS   r0,#0
        CMP     r0,#0                      ; was it invalid ?
        MOVEQ   r0,#0
        MOVEQ   r2,#0
        LDREQ   pc, [sp], #4               ; yes
        ; now we need to find the length of the directory
        MOV     r1,r0
01
        LDRB    r2,[r1],#1
        CMP     r2,#' '
        BCS     %BT01
        SUB     r2,r1,r0
        SUB     r2,r2,#1                   ; and we increased over the terminator
        LDR     pc, [sp], #4

dir_code_write
        STMFD   sp!, {r0, lr}
        MOV     r0, r1
        SWI     XDDEUtils_Prefix
        ADDS    r0, r0, #0                 ; clear V
        LDMFD   sp!, {r0, pc}
prefix_dir_code_end

finish
        MOV     r6, lr
        LDR     r12, [r12]
        MOV     r0, #ModHandReason_Free
        LDR     r2, fname_buffer
        CMP     r2, #0
        SWINE   XOS_Module

        LDR     r2, cli_buffer
        CMP     r2, #0
        SWINE   XOS_Module

        LDR     r2, chain
        MOV     r1, #0
        STR     r1, chain
        STR     r1, fname_buffer
        STR     r1, cli_buffer
        STR     r1, cli_size
        STR     r1, receiver_id

finish1
        CMP     r2, #0
        BEQ     finish2
        LDR     r5, [r2,#o_next]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOV     r2, r5
        BVC     finish1

finish2
        MOV     r2, r12
        MOV     r0, #FileV
        TEQ     pc, pc
        ADREQL  r1, file_handler_32
        ADRNEL  r1, file_handler_26
        SWI     XOS_Release
        MOV     r0, #GBPBV
        TEQ     pc, pc
        ADREQ   r1, gbpb_handler_32
        ADRNE   r1, gbpb_handler_26
        SWI     XOS_Release
        MOV     r0, #FindV
        TEQ     pc, pc
        ADREQ   r1, find_handler_32
        ADRNE   r1, find_handler_26
        SWI     XOS_Release
        MOV     r0, #FSCV
        TEQ     pc, pc
        ADREQL  r1, fscontrol_handler_32
        ADRNEL  r1, fscontrol_handler_26
        SWI     XOS_Release
        MOV     r2, r12                    ; free our main workspace
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        CMP     r0, #0
        MOV     pc, r6

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; SWI despatch
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
do_swi
        STR     lr,[sp,#-4]!
        LDR     r12,[r12]                  ; read workspace pointer
        BL      do_swi_orig
        TEQ     pc, pc
        LDREQ   pc,[sp],#4                 ; 32-bit return corrupting flags
        LDMVCFD sp!,{pc}^                  ; 26-bit return without error
        LDR     lr,[sp],#4                 ; 26-bit return with error
        ORRS    pc,lr,#V_bit

do_swi_orig
        CMP     r11,#first_unused_swi
        ADDLT   pc,pc,r11,LSL #2
        B       module_swierror
lowest_swi
        B       doswi_prefix
        B       doswi_setclsize
        B       doswi_setcl
        B       doswi_getclsize
        B       doswi_getcl
        B       doswi_throwbackregister
        B       doswi_throwbackunregister
        B       doswi_throwbackstart
        B       doswi_throwbacksend
        B       doswi_throwbackend
        B       doswi_readprefix
        B       doswi_flushcl
highest_swi
first_unused_swi *      (highest_swi - lowest_swi) / 4

module_swierror
        STMFD   sp!, {r1-r4, lr}
        ADR     r0,msg_swierror
        MOV     r1,#0
        MOV     r2,#0
        ADRL    r4,title
        SWI     XMessageTrans_ErrorLookup
        LDMFD   sp!,{r1-r4,pc}

msg_swierror
        DCD     ErrorNumber_ModuleBadSWI
        DCB     "BadSWI",0
        ALIGN

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Prefixer
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
add_prefix
        ; Entry: VC
        ;        R1  = Filename
        ;        R11 = Filename buffer
        ;        R8  = Task block
        ; Exit:  R11, LR = ???
        ;        R1  = Preserved
        ;        R11 = Preserved
        ;        R8  = New Filename (R1 or R11 on entry)
        ;        CS  => No prefix added (filename contained root char)
        SUBS    r0, r0, #0                 ; set C
add_prefix0
        STMFD   sp!, {r0-r4, r5, lr}       ; r5 is placeholder
        MRS     lr, CPSR                   ; NOP on old machine
        STR     lr, [sp, #20]
  [ Debug
    [ HALDebug
 DebugTX01 r1,"Before add_prefix: "
    |
        STMFD   sp!, {r0-r2}
        SWI     OS_WriteS
        DCB     "Before add_prefix: ", 0
        ALIGN
        MOV     r2, r1
write_name0
        LDRB    r0, [r2], #1
        CMP     r0, #' '+1
        SWICS   OS_WriteC
        CMP     r0, #' '+1
        BCS     write_name0
        SWI     OS_NewLine
        LDMFD   sp!,{r0-r2}
    ]
  ]
        MOV     r2, r1
add_prefix1
        LDRB    r0, [r2], #1
        CMP     r0, #':'
        CMPNE   r0, #'$'
        CMPNE   r0, #'&'
        CMPNE   r0, #'%'
        CMPNE   r0, #'<'
        MOVEQ   r8, r1
        BEQ     add_prefix5
        CMP     r0, #' ' + 1
        BCS     add_prefix1
        MOV     r2, r1
        LDRB    r0, [r2]
        CMP     r0, #'@'
        BNE     add_prefix2
        LDRB    r0, [r2, #1]!
        CMP     r0, #'.'
        ADDEQ   r2, r2, #1
add_prefix2
        MOV     r3, r11
        ADD     r8, r8, #o_prefix
add_prefix3
        LDRB    r0, [r8], #1
        CMP     r0, #' ' + 1
        STRCSB  r0, [r3], #1
        BCS     add_prefix3
        LDRB    r0, [r2]
        CMP     r0, #' ' + 1
        MOVCS   r0, #'.'
        STRCSB  r0, [r3], #1
add_prefix4
        LDRB    r0, [r2], #1
        CMP     r0, #' ' + 1
        MOVCC   r0, #0
        STRB    r0, [r3], #1
        BCS     add_prefix4
        MOV     r8, r11

  [ Debug
    [ HALDebug
 DebugTX01 r8, "After add_prefix: "
    |
        SWI     OS_WriteS
        DCB     4, "After add_prefix: ", 0
        ALIGN
        MOV     r2, r8
01
        LDRB    r0, [r2], #1
        CMP     r0, #' '+1
        SWICS   OS_WriteC
        CMP     r0, #' '+1
        BCS     %BT01
        SWI     OS_NewLine
    ]
  ]
        LDMFD   sp, {r0, r1, r2, r3, r4, lr}
        BIC     lr, lr, #C_bit
        STR     lr, [sp, #20]
        B       add_prefix5

strip_hats
        SUBS    r0, r0, #0                 ; set carry
strip_hats0
        STMFD   sp!, {r0, r1, r2, r3, r4, r5, lr}
        MRS     lr, CPSR                   ; NOP on old machine
        STR     lr, [sp, #20]
add_prefix5
        MOV     r2, r8
        MOV     r1, r11
        MOV     r3, r1
        MOV     r4, r3
add_prefix6
        LDRB    r0, [r2], #1
        STRB    r0, [r1], #1
        CMP     r0, #'.'
        LDREQB  lr, [r2]
        CMPEQ   lr, #'^'
        BNE     add_prefix9
        LDRB    lr, [r3]
        CMP     lr, #'$'
        CMPNE   lr, #'@'
        CMPNE   lr, #'%'
        CMPNE   lr, #'&'
        CMPNE   lr, #'<'
        CMPNE   lr, #'^'
        MOVEQ   r0, #'!'                   ; R0 > ' ' and != '.'
        BEQ     add_prefix9
add_prefix7
        LDRB    lr, [r2], #1
        CMP     lr, #'.'
        CMPNE   lr, #' '
        BHI     add_prefix7
        SUB     r2, r2, #1
        CMP     r3, r4
        STREQB  lr, [r3]
add_prefix8
        LDRB    lr, [r2], #1
        STRNEB  lr, [r3], #1
        CMP     lr, #' '
        BHI     add_prefix8
        MOV     r8, r11
        LDR     r2, [sp, #20]
        BIC     r2, r2, #C_bit
        STR     r2, [sp, #20]
        B       add_prefix5
add_prefix9
        CMP     r0, #':'
        MOVEQ   r4, r1
        MOVEQ   r3, r1
        CMP     r0, #'.'
        SUBEQ   r3, r1, #1
        CMP     r0, #' '
        BHI     add_prefix6
  [ Debug
    [ HALDebug
 DebugTX01 r8, "After stripping ^s "
    |
        SWI     OS_WriteS
        DCB     4, "After stripping ^s ", 0
        ALIGN
        SWI     OS_NewLine
        MOV     r2, r8
write_name1
        LDRB    r0, [r2], #1
        CMP     r0, #' '+1
        SWICS   OS_WriteC
        CMP     r0, #' '+1
        BCS     write_name1
        SWI     OS_NewLine
    ]
  ]
        LDMFD   sp!, {r0, r1, r2, r3, r4, lr}
        TEQ     pc, pc
        BNE     add_prefix_ret_26
        MSR     CPSR_f, lr
        LDR     pc, [sp], #4

add_prefix_ret_26
        TEQP    pc, lr
        NOP                                ; banked register follows
        LDR     pc, [sp], #4

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Vector claimaints
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
find_handler_26
        STR     lr, [sp, #-4]!
        STR     pc, [sp, #-4]!
        BL      find_handler_32
        NOP
        ADD     sp, sp, #4
        LDMVCFD sp!, {pc}^
        LDR     lr, [sp], #4
        ORRS    pc, lr, #V_bit

find_handler_32
        TST     r0, #open_write :OR: open_read
        MOVEQ   pc, lr                     ; must be a close operation
        STR     r0, [sp, #-4]!
        AND     r0, r0, #open_pathbits
        TEQ     r0, #open_pathvar          ; explicit path variable supplied
        TEQNE   r0, #open_pathstring       ; explicit path string supplied
        LDR     r0, [sp], #4
        BNE     common_handler_external_entry
        CMP     r0, #0                     ; clear V
        MOV     pc, lr

gbpb_handler_26
        STR     lr, [sp, #-4]!
        STR     pc, [sp, #-4]!
        BL      gbpb_handler_32
        NOP
        ADD     sp, sp, #4
        LDMVCFD sp!, {pc}^
        LDR     lr, [sp], #4
        ORRS    pc, lr, #V_bit

gbpb_handler_32
        CMP     r0, #OSGBPB_ReadDirEntries
        MOVLO   pc, lr                     ; V clear
        ASSERT  OSGBPB_ReadDirEntriesFileType > OSGBPB_ReadDirEntries
        CMP     r0, #OSGBPB_ReadDirEntriesFileType
        BLS     common_handler_external_entry
        CMP     r0, #0                     ; V clear
        MOV     pc, lr

file_handler_26
        STR     lr, [sp, #-4]!
        STR     pc, [sp, #-4]!
        BL      file_handler_32
        NOP
        ADD     sp, sp, #4
        LDMVCFD sp!, {pc}^
        LDR     lr, [sp], #4
        ORRS    pc, lr, #V_bit

file_handler_32
        CMP     r0, #OSFile_LoadPath       ; Respect path string and path variables
        CMPNE   r0, #OSFile_LoadPathVar
        CMPNE   r0, #OSFile_ReadPath
        CMPNE   r0, #OSFile_ReadPathVar
        CMPNE   r0, #OSFile_ReadWithTypePath
        CMPNE   r0, #OSFile_ReadWithTypePathVar
        BNE     common_handler_external_entry
        CMP     r0, #0                     ; V clear
        MOV     pc, lr

common_handler_external_entry
        ; R1 = pointer to name to use
        STMFD   sp!, {r8, r11, lr}
  [ Debug
    [ HALDebug
 DebugRegNCR r0,""
 DebugRegNCR r1,""
 DebugTX01 r1, "common file handler: "
    |
        STMFD   sp!, {r0, r1}
        SWI     OS_WriteS
        DCB     4, "common file handler: ", 0
        ALIGN
01
        LDRB    r0, [r1], #1
        CMP     r0, #' '+1
        SWICS   OS_WriteC
        CMP     r0, #' '+1
        BHS     %BT01
        SWI     OS_NewLine
        LDMFD   sp!, {r0, r1}
    ]
  ]
        LDR     r8, chain
        LDR     lr, wimp_domain
        LDR     lr, [lr]                   ; lr = domainid
common_handler1
        CMP     r8, #0
        BEQ     common_handler2
        LDR     r11, [r8, #o_wimpdomain]
        CMP     r11, lr                    ; hunt for domainid in linked list of tasks
        LDRNE   r8, [r8, #o_next]
        BNE     common_handler1
        LDR     r11, fname_buffer
        BL      add_prefix
common_handler3
        MOV     r12,r8                     ; hold dir block otherwise this gets very icky
        LDMFD   sp!, {r8, r11, lr}
        MOVCS   pc, lr
        TEQ     pc, pc
        LDRNE   lr, [sp, #4]               ; get real pass-on address from 26-bit veneer
        TEQNEP  pc, lr                     ; restore vector's entry flags
        NOP                                ; banked register follows
        STR     r1, [sp, #-4]!
        MOV     r1, r12
        STR     pc, [sp, #-4]!             ; store PC+8 (Architecture 4) or PC+12
        MOV     pc, lr
        NOP                                ; so that PC+8 is ok

common_upcall
        LDMFD   sp!, {r1, lr}              ; target of stored PC
        B       xfervc

common_handler2
        LDR     r11, fname_buffer
        MOV     r8, r1
        BL      strip_hats
        B       common_handler3

fscontrol_handler_26
        STR     lr, [sp, #-4]!
        STR     pc, [sp, #-4]!
        BL      fscontrol_handler_32
        NOP
        ADD     sp, sp, #4
        LDMVCFD sp!, {pc}^
        LDR     lr, [sp], #4
        ORRS    pc, lr, #V_bit

fscontrol_handler_32
        CMP     r0, #FSControl_Access
        BLS     fscontrol_lownumbered
        ASSERT  (FSControl_Rename > FSControl_Access) :LAND: (FSControl_Rename < FSControl_Copy)
        CMP     r0, #FSControl_Copy
        BLS     copy_or_rename
        CMP     r0, #FSControl_CanonicalisePath
        BEQ     fscontrol_canon
        CMPNE   r0, #FSControl_Count
        CMPNE   r0, #FSControl_FileInfo
        CMPNE   r0, #FSControl_InfoToFileType
  [ HandleImages
        CMPNE   r0, #41                    ; return defects for image
        CMPNE   r0, #42                    ; map out defects for image
        CMPNE   r0, #46                    ; return used space map for image
        CMPNE   r0, #47                    ; read boot for disc/image
        CMPNE   r0, #48                    ; write boot for disc/image
        CMPNE   r0, #49                    ; read free space for disc/image
        CMPNE   r0, #50                    ; rename disc/image
        ; CMPNE   r0, #51                  ; update stamp (should already be canonical, I think - JRF)
        CMPNE   r0, #52                    ; find object at offset
        CMPNE   r0, #55                    ; read freespace (large)
        CMPNE   r0, #56                    ; read defects (large)
        CMPNE   r0, #57                    ; map out defect (large)
  ]
        BEQ     common_handler_external_entry
  [ AllowDirChanging
        CMP     r0, #FSControl_SetDir
        BEQ     fscontrol_set_dir
        CMP     r0, #FSControl_NoDir
        BEQ     fscontrol_unset_dir
  ]
        CMP     r0, r0
        MOV     pc, lr

fscontrol_canon
        ORRS    r0, r3, r4                 ; only process if the path variable & path string are absent
        MOV     r0, #FSControl_CanonicalisePath
        MOVNE   pc, lr
        B       common_handler_external_entry

fscontrol_lownumbered
        CMP     r0, #FSControl_Cat
        CMPNE   r0, #FSControl_Ex
        CMPNE   r0, #FSControl_Info
        CMPNE   r0, #FSControl_Access
        BEQ     common_handler_external_entry
  [ AllowDirChanging
        CMP     r0, #FSControl_Dir
        BEQ     fscontrol_change_dir
  ]
        CMP     r0, r0
        MOV     pc, lr

  [ AllowDirChanging
fscontrol_unset_dir
        STMFD   sp!, {r0, lr}
        MOV     r0, #0
        SWI     XDDEUtils_ReadPrefix       ; read context
        BVS     %FT01
        TEQ     r0, #0
        LDMEQFD sp!, {r0, pc}
        MOV     r0, #0
        SWI     XDDEUtils_Prefix
        BVS     %FT01

fscontrol_set_dir
        CMP     r2, #Dir_Current
        MOVNE   pc, lr                     ; only process if 'set CSD'

        STMFD   sp!, {r0, lr}
        MOV     r0, #0
        SWI     XDDEUtils_ReadPrefix       ; read context
        BVS     %FT01
        CMP     r0, #0
        LDMEQFD sp!, {r0, pc}
        MOV     r0, r1
        SWI     XDDEUtils_Prefix
01
        STRVS   r0, [sp, #0]
        LDMFD   sp!, {r0, lr}
        LDR     pc, [sp], #4

fscontrol_change_dir
        STMFD   sp!, {r0-r5, lr}
        MOV     r0, #0
        SWI     XDDEUtils_ReadPrefix       ; read context
        BVS     %FT01
        TEQ     r0, #0
        LDMEQFD sp!, {r0-r5,pc}
        MOV     r0, #OSFile_ReadInfo
        SWI     XOS_File
        TST     r0, #object_directory      ; also catches image files
        BEQ     %FT02
        MOV     r0, r1
        SWI     XDDEUtils_Prefix
01
        STRVS   r0, [sp, #0]
        LDMFD   sp!, {r0-r5, lr}
        LDR     pc, [sp], #4
02
        MOV     r0, #OSFile_MakeError
        MOV     r2, #&100                  ; Directory 'wibble' not found
        SWI     XOS_File
        ADD     sp, sp, #4                 ; skip r0
        LDMFD   sp!, {r1-r5, lr}
        LDR     pc, [sp], #4
  ]

copy_or_rename
        STMFD   sp!, {r1, r2}
        SUB     sp, sp, #4                 ; avoid storing LR + PC together
        STMFD   sp!, {r8-r11, lr}
        STR     pc, [sp, #5 * 4]           ; store PC+8 or PC+12
        B       copy_or_rename1
        NOP                                ; so that PC+8 is ok

copy_or_rename_upcall                      ; target of stored PC
        LDMFD   sp!, {r1, r2, lr}
        B       xfervc

copy_or_rename1
        ADR     r8, chain
copy_or_rename1b
        LDR     r8, [r8]
        CMP     r8, #0
        BEQ     copy_or_rename2
        LDR     lr, wimp_domain
        LDR     lr, [lr]
        LDR     r11, [r8, #o_wimpdomain]
        CMP     r11, lr
        BNE     copy_or_rename1b
        LDR     r11, fname_buffer
        MOV     r9, r8
        BL      add_prefix
        MOV     r10, r8
        MOV     r8, r9
        ADD     r11, r11, #FilenameLength
        MOV     r9, r1
        MOV     r1, r2
        BL      add_prefix0
copy_or_rename3
        MOV     r1, r9
        MOVCC   r2, r8
        MOVCC   r1, r10
        LDMFD   sp!, {r8-r11, lr}
        ADDCS   sp, sp, #12
        MOVCS   pc, lr
        TEQ     pc, pc
        LDRNE   lr, [sp, #16]              ; get real pass-on address from 26-bit veneer
        MOVNES  pc, lr
        MOV     pc, lr

copy_or_rename2
        LDR     r11, fname_buffer
        MOV     r8, r1
        BL      strip_hats
        MOV     r10, r8
        ADD     r11, r11, #FilenameLength
        MOV     r9, r1
        MOV     r8, r2
        BL      strip_hats0
        B       copy_or_rename3

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_Prefix
; ---------------
; Entry: R0  = pointer to null terminated directory name, or zero to clear
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_prefix
        STMFD   sp!, {r1, r2, r3, r8, lr}
        MOVS    r10, r0
        BEQ     %FT01                      ; they gave 0
        LDRB    r0,[r10]
        CMP     r0,#' '
        BLO     %FT01                      ; it was a null command

  [ CanonicalisePath
        STMFD   sp!, {r4, r5}
        MOV     r0,#FSControl_CanonicalisePath
        MOV     r1,r10
        LDR     r2,fname_buffer
        MOV     r3,#0                      ; no path var
        MOV     r4,#0                      ; 0
        MOV     r5,#FilenameLength
        SWI     XOS_FSControl              ; canonicalise it!
        LDRVC   r10,fname_buffer
        LDMFD   sp!, { r4, r5 }
01
  ]

  [ Debug
    [ HALDebug
 DebugTX01 r10, "attempting to set prefix: "
    |
        STMFD   sp!, {r0, r2}              ; Stack registers
        SWI     OS_WriteS
        DCB     4, "attempting to set prefix: ", 0
        ALIGN
        MOV     r2, r10
01
        LDRB    r0, [r2], #1
        CMP     r0, #' '+1
        SWICS   OS_WriteC
        CMP     r0, #' '+1
        BCS     %BT01
        SWI     OS_NewLine
        LDMFD   sp!,{r0,r2}                ; Unstack registers
    ]
  ]

        ASSERT  DDEUtils_Prefix = DDEUtilsSWI_Base
        LDR     r11, wimp_domain
        LDR     r11, [r11]
        ADR     r8, chain
        LDR     r2, chain
do_swi1
        TEQ     r2, #0
        BEQ     do_swi2
        LDR     r1, [r2, #o_wimpdomain]
        TEQ     r1, r11
        ADDNE   r8, r2, #o_next            ; r8 = last next pointer addr
        LDRNE   r2, [r2, #o_next]          ; r2 = this pointer
        BNE     do_swi1
        LDR     r3, [r2, #o_next]          ; read this next
        STR     r3, [r8]                   ; store as last next
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOVVC   r2,r3
        BVC     do_swi1
        LDMFD   sp!, {r1, r2, r3, r8, pc}  ; V set

do_swi2
        ADDS    r0, r10, #0
        LDMEQFD sp!, {r1, r2, r3, r8, pc}  ; V clear
        LDRB    r1, [r0]
        CMP     r1, #' ' + 1
        LDMLOFD sp!, {r1, r2, r3, r8, pc}  ; V clear
        MOV     r3, #0
do_swi3
        LDRB    r1, [r0], #1
        ADD     r3, r3, #1
        CMP     r1, #' ' + 1
        BCS     do_swi3
        ADD     r3, r3, #o_prefix
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        LDMVSFD sp!, {r1, r2, r3, r8, pc}  ; V set
        STR     r2, [r8]                   ; store over last next pointer (!)
        MOV     r0, #0
        STR     r0, [r2], #4               ; next
        STR     r11, [r2], #4              ; domain
                                           ; prefix follows
        MOV     r0, r10
do_swi4
        LDRB    r1, [r10], #1
        STRB    r1, [r2], #1
        CMP     r1, #' ' + 1
        MOVHS   r3, r1
        BHS     do_swi4
        CMP     r3, #'.'
        STREQB  r1, [r2, #-2]
        MOV     r3,#0
        STRB    r3, [r2, #-1]              ; store it as terminated
        LDMFD   sp!, {r1, r2, r3, r8, pc}  ; V clear

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ReadPrefix
; -------------------
; Entry: R0  = task handle or 0 for current task
; Exit:  R0  = pointer to prefix dir for that task or 0 if none.
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_readprefix
        MOVS    r11, r0, LSL #16
        LDREQ   r11, wimp_domain
        LDREQ   r11, [r11]
        MOVEQ   r11, r11, ROR #16
        MOV     r0, #0
        STMFD   sp!, {r1, r2, r8, lr}
        LDR     r8, chain

doswi_readprefix1
        CMP     r8, #0
        LDMEQFD sp!, {r1, r2, r8, pc}
        LDR     r2, [r8,#o_next]
        LDR     r1, [r8, #o_wimpdomain]
        CMP     r11, r1, ROR #16
        ADDEQ   r0, r8, #o_prefix
        LDMEQFD sp!, {r1, r2, r8, pc}
        MOV     r8, r2
        B       doswi_readprefix1

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_GetClSize
; ------------------
; Exit:  R0  = size
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_getclsize
        LDR     r0, cli_size
        MOV     pc, lr

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_GetCl
; --------------
; Entry: R0  = pointer to buffer to copy into
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_getcl
        LDR     r11, cli_buffer
        CMP     r11, #0
        MOVEQ   r12, #0
        STREQB  r12, [r0]
        MOVEQ   pc, lr
        STMFD   sp!, {r2, r8, lr}
        MOV     r8, #0
        STR     r8, cli_buffer
        STR     r8, cli_size
        MOV     r2, r11
        MOV     r8, r0
getcl1
        LDRB    r10, [r11], #1
        STRB    r10, [r0], #1
        CMP     r10, #' '
        BHS     getcl1
        MOV     r10, #0
        STRB    r10, [r0, #-1]
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOVVC   r0, r8
        LDMFD   sp!, {r2, r8, lr}
        B       xferv

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_FlushCL
; ----------------
; Entry: Nothing
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_flushcl
        LDR     r11, cli_buffer
        CMP     r11, #0
        MOVEQ   pc, lr
        STMFD   sp!, {r2, lr}
        MOV     lr, #0
        STR     lr, cli_buffer
        STR     lr, cli_size
        MOV     r2, r11
        MOV     r11, r0
        MOV     r0, #ModHandReason_Free
        SWI     XOS_Module
        MOVVC   r0, r11
        LDMFD   sp!, {r2, lr}
        B       xferv

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_SetCLSize
; ------------------
; Entry: R0  = size
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_setclsize
        STMFD   sp!, {r1, r2, r3, lr}
        MOV     r3, r0
        LDR     r2, cli_buffer
        CMP     r2, #0
        MOVNE   r0, #ModHandReason_Free
        SWINE   XOS_Module
        LDMVSFD sp!, {r1, r2, r3, pc}
  [ {FALSE}
        CMP     r3, #0
        LDMEQFD sp!, {r1, r2, r3, pc}
  ]
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        MOVVS   r1, #0
        STRVS   r1, cli_buffer
        STRVS   r1, cli_size
        STRVC   r2, cli_buffer
        STRVC   r3, cli_size
        MOVVC   r0, r2
        LDMFD   sp!, {r1, r2, r3, lr}
        B       xferv

no_cli_buffer_msg
        DCD     no_cli_buffer_error
        DCB     "CLI buffer not set", 0
        ALIGN

do_no_cli_buffer
        ADR     r0, no_cli_buffer_msg
        B       return_setv

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_SetCL
; --------------
; Entry: R0  = pointer to null terminated command tail
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_setcl
        LDR     r11, cli_buffer
        CMP     r11, #0
        BEQ     do_no_cli_buffer
        STMFD   sp!, {r0, r1, lr}
        LDR     r1, cli_size
setcl1
        LDRB    r10, [r0], #1
        STRB    r10, [r11], #1
  [ CheckBufferSize
        SUBS    r1,r1,#1
        BMI     do_buffer_too_short
  ]
        CMP     r10, #' '
        BCS     setcl1
        LDMFD   sp!, {r0, r1, pc}
  [ CheckBufferSize
do_buffer_too_short
        LDMFD   sp!, {r0, r1, lr}
        ADR     r0, buffer_too_short_msg
        B       return_setv

buffer_too_short_msg
        DCD     buffer_too_short
        DCB     "CLI buffer too short", 0
        ALIGN
  ]

prefix_cmd
        MOV     r6, lr
        SWI     XDDEUtils_Prefix
        MOV     pc, r6

not_desktop_msg
        DCD     not_desktop_error
        DCB     "Throwback not available outside the desktop", 0
        ALIGN

no_task_msg
        DCD     no_task_error
        DCB     "No task registered for throwback", 0
        ALIGN

already_reg_msg
        DCD     already_reg_error
        DCB     "Another task is registered for throwback", 0
        ALIGN

not_reg_msg
        DCD     not_reg_error
        DCB     "Task not registered for throwback", 0
        ALIGN


        ; check if we're in the desktop or not
checkactivetasks
        STMFD   sp!, {r0, lr}
        MOV     r0, #0
        SWI     XWimp_ReadSysInfo
        MOVVS   r0, #0
        CMP     r0, #0
        LDMFD   sp!, {r0, lr}
        MOVNE   pc, lr
        ADR     r0, not_desktop_msg
        B       return_setv

do_no_task
        ADR     r0, no_task_msg
return_setv
        TEQ     pc, pc
        ORRNES  pc, lr, #V_bit
        MSR     CPSR_f, #V_bit
        MOV     pc, lr

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ThrowbackEnd
; ---------------------
; Entry: Nothing
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_throwbackend
        STMFD   sp!, {r0-r4, r9, lr}
        BL      checkactivetasks
        ADDVS   sp,sp,#4
        LDMVSFD sp!, {r1-r4, r9, pc}
        LDR     r9, receiver_id
        CMP     r9, #0
        LDMEQFD sp!, {r0-r4, r9, lr}
        BEQ     do_no_task

        MOV     r0, #msg_throwback_end
startorendmsg
        MOV     r1, #0                  ; No string
stringonlymsg1
        MVN     r3, #0                  ; No line no.
        MVN     r4, #0                  ; No error level
        BL      sendmessage
throwback_vsret
        ADDVS   sp, sp, #4
        LDRVC   r0, [sp], #4
        LDMFD   sp!, {r1-r4, r9, lr}
        B       xferv


stringonlymsg
        STMFD   sp!, {r0-r4, r9, lr}
        B       stringonlymsg1

throwback_err
        DCB     "Throwback error", 13, 10, 0
        ALIGN

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ThrowbackRegister
; --------------------------
; Entry: R0  = task handle
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_throwbackregister
        STMFD   sp!, {r0, r9, lr}
        BL      checkactivetasks
        ADDVS   sp,sp,#4
        LDMVSFD sp!, {r9, pc}
        LDR     r9, receiver_id
        CMP     r9, #0
        LDMFD   sp!, {r0, r9, lr}
        ADRNE   r0, already_reg_msg
        BNE     return_setv
        STR     r0, receiver_id
        MOV     pc, lr

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ThrowbackUnregister
; ----------------------------
; Entry: R0  = task handle
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_throwbackunregister
        STMFD   sp!, {r0, r9, lr}
        BL      checkactivetasks
        ADDVS   sp,sp,#4
        LDMVSFD sp!, {r9, pc}
        LDR     r9, receiver_id
        CMP     r9, r0
        MOVEQ   r0, #0
        STREQ   r0, receiver_id
        LDMFD   sp!, {r0, r9, lr}
        ADRNE   r0, not_reg_msg
        BNE     return_setv
        MOV     pc, lr

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ThrowbackStart
; -----------------------
; Entry: Nothing
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_throwbackstart
        STMFD   sp!, {r0-r4, r9, lr}
        BL      checkactivetasks
        ADDVS   sp,sp,#4
        LDMVSFD sp!, {r1-r4, r9, pc}
        LDR     r9, receiver_id
        CMP     r9, #0
        LDMEQFD sp!, {r0-r4, r9, lr}
        BEQ     do_no_task

        MOV     r0, #msg_throwback_start
        B       startorendmsg

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DDEUtils_ThrowbackSend
; ----------------------
; Entry: R0  = subreason code
;        R2-R5 dependant on subreason
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
doswi_throwbacksend
        STMFD   sp!, {r0-r4, r9, lr}
        BL      checkactivetasks
        ADDVS   sp,sp,#4
        LDMVSFD sp!, {r1-r4, r9, pc}
        LDR     r9, receiver_id
        CMP     r9, #0
        LDMEQFD sp!, {r0-r4, r9, lr}
        BEQ     do_no_task

        TEQ     pc, pc
        ADRNE   lr, tap_handler_26      ; For the 26 bit case, arrange the same stack as
        ORRNE   lr, lr, #SVC_mode       ; though entered via the veneer added to all the 26 bit
                                        ; vectors (in SVC mode with NZCV clear).
                                        ; For the 32 bit case, it's a harmless extra push of LR.
        STR     lr, [sp, #-4]!
        BL      throwback_add_prefix
        ADD     sp, sp, #4

        B       throwback_vsret

        ; support for ThrowbackSend
        ; R0 = subreason code
        ; R2 = filename to prefix
        ; R3-R5 dependant on subreason
throwback_add_prefix
        STR     lr, [sp, #-4]!
        MOV     r1, r2
        BL      common_handler_external_entry
tap_handler_26
        STMFD   sp!, {r0, r3, r4}
        MOV     lr, r0
        CMP     lr, #Throwback_ReasonInfoDetails
        MOVEQ   r0, #msg_throwback_infoforfile
        CMP     lr, #Throwback_ReasonProcessing
        MOVEQ   r0, #msg_throwback_processingfile
        CMP     lr, #Throwback_ReasonErrorDetails
        MOVEQ   r0, #msg_throwback_errorsin
        BL      stringonlymsg
        LDRVC   r0, [sp], #4
        ADDVS   sp, sp, #4
        LDMFD   sp!, {r3, r4}
        BVS     %FT10
        CMP     r0, #Throwback_ReasonProcessing
        LDREQ   pc, [sp], #4
        CMP     r0, #Throwback_ReasonInfoDetails
        MOVEQ   r0, #msg_throwback_infodetails
        MOVNE   r0, #msg_throwback_errordetails
        MOV     r1, r5
        BL      sendmessage
10
        LDR     lr, [sp], #4
        B       xferv

        ; R0 = message id
        ; R1 = string       0 => no string
        ; R3 = line no     -1 => no line no
        ; R4 = error level -1 => no errorlevel
sendmessage
        STR     lr, [sp, #-4]!
  [ Debug
        STMFD   sp!, {r0, r1, r2, r3}
        MOV     r3, r1
        SWI     OS_WriteS
        DCB     4, "Message id = ", 0
        ALIGN
        ADR     r1, hbuff
        MOV     r2, #12
        SWI     OS_ConvertHex8
        SWI     OS_Write0
        SWI     OS_WriteS
        DCB     13, 10, 0
        ALIGN
        MOV     r0, r3
        SWI     OS_Write0
        SWI     OS_WriteS
        DCB     13, 10, 5, 0
        ALIGN
        LDMFD   sp!, {r0, r1, r2, r3}
        B       %FT01
hbuff
        %       256
01
  ]
        MOV     r2, r1
        MOVS    lr, r1
        BEQ     sendmessage2
sendmessage1
        LDRB    r2, [lr], #1
        CMP     r2, #0
        BNE     sendmessage1
        SUB     r2, lr, r1
sendmessage2
        ADD     r2, r2, #31
        BIC     r2, r2, #3
        MOV     lr, sp
        SUB     sp, sp, r2
        STR     r2, [sp]
        ADD     r2, sp, #12
        STR     lr, [sp, #-4]!
        MOV     lr, #0
        STR     lr, [r2], #4
        ADD     r0, r0, #ddeutils_msgbase :AND: &FFF000
        ADD     r0, r0, #ddeutils_msgbase :AND: &000FFF
        STR     r0, [r2], #4
        CMN     r3, #1
        STRNE   r3, [r2], #4
        CMN     r4, #1
        STRNE   r4, [r2], #4
        CMP     r1, #0
        BEQ     sendmessage4
sendmessage3
        LDRB    lr, [r1], #1
        STRB    lr, [r2], #1
        CMP     lr, #0
        BNE     sendmessage3
sendmessage4
        MOV     r0, #17
        ADD     r1, sp, #4
        MOV     r2, r9
        LDR     lr, [r1]                   ; length of msg
        CMP     lr, #256
        MOVGT   lr, #256
        STRGT   lr, [r1]                   ; 256 is max size of msg
        MOVGT   lr, #0
        STRGTB  lr, [r1, #255]
        SWI     XWimp_SendMessage
        LDR     sp, [sp]
        LDR     lr, [sp], #4
        B       xferv

initvar
        STMFD   sp!, {r4, lr}
        MOV     r3, r1
initvar1
        LDRB    r2, [r3], #1
        CMP     r2, #' '
        BCS     initvar1
        SUB     r2, r3, r1
        MOV     r3, #0
        MOV     r4, #0
        SWI     XOS_SetVarVal
        LDMFD   sp!, {r4, pc}
  [ HALDebug
        GET     s.debug
  ]
        END
