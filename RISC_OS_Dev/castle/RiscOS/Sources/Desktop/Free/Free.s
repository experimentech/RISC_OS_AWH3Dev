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
; > s.Front

;;-----------------------------------------------------------------------------
;; Wimp utility:  FreeSpace
;;
;; Change list
;; 09-Sep-90    0.01    Started.
;; 01-Nov-90    0.02    Centre window on mouse.
;; 12-Dec-90    0.03    Fixed bug, svc_reset didn't preserve r1.
;; 17-Mar-91    0.04    Fixed bug - svc_reset freed list of known Filing systems.
;;                      Fixed bug - Name legth is no longer than 10 on ADFS / SCSI /RAMFS
;;                      Fixed bug - ADFS / SCSI now cope with unnamed discs.
;; 08-Apr-91    0.05    Added Messages list and pass 300 to Wimp_Initialise
;; 20-May-91    0.06    Fixed bug, pull "r1-r3,pc on error from adfs/scsifs/ramfs_freespace
;;                      Fixed bug, was unable to cope with 10 character names.
;; 22-Jul-91    0.07    Free space on Econet is now smaller of User free space and disc free space.
;; 28-Jul-91    0.08    Fixed bug, lost station & net number in some Econet cases.
;;                      Fixed bug, opened window with wrong info if got an error while reading space.
;; 28-Aug-91    0.09    Removed ADFS alias setting.
;; 05-Sep-91    0.10    Doesn't free workspace on die.
;; 29-Oct-91    0.12    Templates now help in Messages module, no longer need ResourceFS.
;; 12-Dec-91    0.13    Errors mow held in Messages module and looked up using MessageTrans.
;; 21-Feb-92    0.16    Changed upcall handler to work with reason 512 (extending file)
;; 27-Feb-92    0.17    Fixed internationalisation bug (used wrong title length)
;; 11-Apr-92    0.21    Fixed handling of UpCall close and extend files to construct name
;;                        from file handle. Avoids embarasing requests for dodgy disc names
;;                        and keeps free space updated correctly.
;; 14-Jul-92  0.22 OSS  Changed Wimp_CloseWindow to Wimp_DeleteWindow.
;; 22-Jul-93  0.23 ECN  Look up "Unknown Free SWI" message
;; 17-Sep-93  0.24 TMD  Changed computation of bar sizes to use floating point, to avoid overflow bug.
;; 01-Nov-94  0.27 amg  Convert to handle 64 bit disc size throughout, and start using
;;                      _FreeSpace64 for ADFS & SCSIFS. Bar calculation no longer FP.
;; 17-Nov-94  0.28 amg  Sort out some bad coding in SCSIFS (doesn't return 'SWI not known'!)
;;-----------------------------------------------------------------------------
;; Wish list
;;-----------------------------------------------------------------------------

        AREA    |Free$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Services
        GET     Hdr:FSNumbers
        GET     Hdr:HighFSI
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:Proc
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:CMOS
        GET     Hdr:MsgTrans
        GET     Hdr:ResourceFS
        GET     Hdr:ADFS
        GET     Hdr:RamFS
        GET     Hdr:SCSIFS
        GET     Hdr:Econet
	GET	Hdr:PCCardFS
        GET     Hdr:UpCall
        GET     Hdr:HostFS
        GET     Hdr:NdrDebug
        GET     Hdr:ExtraLong
        GET     Hdr:Free

        GET     VersionASM

  [ :LNOT: :DEF: standalone
        GBLL    standalone
standalone      SETL    {FALSE}
  ]

;       General tracing
        GBLL    debugxx
        GBLL    hostvdu
debug   SETL    {FALSE}
debugxx SETL    {FALSE}
hostvdu SETL    {TRUE}

;       Options switches
        GBLL    fix_silly_sizes
fix_silly_sizes SETL {TRUE}     ; checks for free > size

;       Local macros
        MACRO
        CMPSTR     $a,$b
        Push       "r0,r1,LR"
        MOV        r0,$a
        MOV        r1,$b
        BL         stricmp
        Pull       "r0,r1,LR"
        MEND

;       Linked window block structure (active and buffered)
                ^       0
next_ptr        #       4       ;       Pointer to next in chain                ( <= 0 if none)
prev_ptr        #       4       ;       Pointer to previous entry in chain      ( <= 0 if none)
window_handle   #       4       ;       Window handle for this window.
window_fs       #       4       ;       Filing system for this window.
window_size_lo  #       4       ;       Total space on the disc (low word).
window_size_hi  #       4       ;       Total space on the disc (high word).
window_free_lo  #       4       ;       Free space on the disc (low word).
window_free_hi  #       4       ;       Free space on the disc (high word).
window_used_lo  #       4       ;       Space used on the disc (low word).
window_used_hi  #       4       ;       Space used on the disc (high word).
window_device   #       4       ;       Pointer to Device ID for this window.
window_update   #       4       ;       Flag to show that the window is out of step
window_discname #       4       ;       Pointer to device name.
no_change       #       4       ;       flag to indicate whether I need to rewrite the textual fields
size_ascii      #       4       ;       value for the textual field
used_ascii      #       4       ;       value for the textual field
free_ascii      #       4       ;       value for the textual field
window_namelength #     4       ;       Length of name.
        ASSERT  next_ptr=0
window_block_size      *      (@-next_ptr)

;       Linked block structure for FS entry points.
                ^       0
fs_next         #       4       ;       Pointer to next in chain                ( <= 0 if none)
fs_prev         #       4       ;       Pointer to previous entry in chain      ( <= 0 if none)
fs_number       #       4       ;       FS number.
fs_entry        #       4       ;       Entry point address
fs_r12          #       4       ;       R12 on entry.
        ASSERT  fs_next=0
fs_block_size      *      (@-fs_next)


;       Workspace layout
                ^       0, R12
wsorigin        #       0

mytaskhandle    #       4       ; put here so we know where it is
windows_ptr     #       4       ; head of list of buffered files
poll_word       #       4       ; To let forground task know about service calls.
full_bar        #       4       ; Size of 100% bar.
fs_list         #       4       ; List of FS entry points
disc_name       #       4       ; Disc name for filecore
disc_desc       #      64       ; Disc descriptor for filecore
message_fblock  #      16       ; MessageTrans file descriptor block
message_fopen   #       4       ; Message file open flag
message_bytes   #      16       ; Lookup of international 'bytes'

indirected_data_offset * (@-wsorigin)
indirected_data #     512       ; Data area for indirected data from the template file

        AlignSpace      16
dataarea        #       &100    ; wimp data block
windowarea      #       &300    ; Place to store window template.

stackbot        #       &200    ;  stack at most 512 bytes long
stacktop        #       0

max_running_work   *       (@-wsorigin)
; -----------------------------------------------------------------------------
; Icon values in template
icon_Free       *       2
icon_FreeBar    *       4
icon_Used       *       6
icon_UsedBar    *       8
icon_Size       *       10
icon_SizeBar    *       12
; -----------------------------------------------------------------------------
        LNK     ModHead.s

