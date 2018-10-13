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
;;
;; Change list
;;            0.01   16-Nov-1990  Started.
;;            0.02   23-May-1991  Added task=0 for all tasks.
;;            0.03   29-May-1991  Fixed bug, find_filter didn't return errors
;;            0.07   16-Apr-1992  Respond to Service_WimpRegisterFilters, fixes RP-1637.
;;                                * Deregistration ensures that only the low 16 bits of the task handle
;;                                 �match since only these are saved in the filter block.  Fixes RP-2404
;;                                * Delay registering with wimp until first filter registered.  This
;;                                  avoids unnecessary degradation in WimpPoll performance
;;            0.08   22-Apr-1992  Broadcasts two new service calls, one when installed, one when removed.
;;
;;-----------------------------------------------------------------------------
;; Wish list
;;-----------------------------------------------------------------------------

        AREA    |FilterManager$$Code|, CODE, READONLY, PIC

Module_BaseAddr

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:Machine.<Machine>
        GET     Hdr:APCS.<APCS>
        GET     Hdr:Services
        GET     Hdr:VduExt
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:Variables
        GET     Hdr:Proc
        GET     Hdr:Sprite
        GET     Hdr:Wimp
        GET     Hdr:WimpSpace
        GET     Hdr:Messages
        GET     Hdr:FilerAct
        GET     Hdr:MsgTrans
        GET     Hdr:MsgMenus
        GET     Hdr:ResourceFS
        GET     Hdr:ColourTran
        GET     Hdr:Hourglass
        GET     Hdr:NdrDebug
        GET     Hdr:Switcher

        GET     VersionASM

        GBLL    hostvdu
        GBLL    debugxx
        GBLL    debugregister

    [ :LNOT: :DEF: standalone
        GBLL    standalone
standalone      SETL {FALSE}            ; Build-in Messages file and i/f to ResourceFS
    ]
    [ :LNOT: :DEF: international_help
        GBLL    international_help
international_help SETL {TRUE}          ; Default to RISC OS 3.60+ internationalisation
    ]

debug           SETL {FALSE}            ; ONLY FALSE IF NO DEBUGGING
hostvdu         SETL {TRUE}             ; True to send debug to tube

debugxx         SETL {FALSE}            ; General debugging.
debugregister   SETL {FALSE}            ; Register/de-register

wsptr           RN      R12

; ----------------------------------------------------------------------------------------------------------------------
;      Filter block structure
                ^       0
next_ptr        #       4       ;       Pointer to next in chain                (-1 if none)
prev_ptr        #       4       ;       Pointer to previous entry in chain      (-1 if none)
f_task          #       4       ;       Task ID for which the filter is to be called.
f_mask          #       4       ;       Event mask.
f_address       #       4       ;       Address to call.
f_R12           #       4       ;       Value in R12 when calling.
f_name          #       4       ;       Pointer to filter name.
f_block_size      *      (@-next_ptr)

        ASSERT  next_ptr=0
; ----------------------------------------------------------------------------------------------------------------------
;       Workspace layout

workspace       RN      R12
                ^       0,workspace
wsorigin        #       0

callbackpending #       4               ; non-zero if callback is pending
pre_filters     #       4
post_filters    #       4
rect_filters    #       4
copy_filters	#	4
post_rect_filters #	4
post_icon_filters #	4
convert_buffer  #       20
message_block   #       16
flags           #       4
filter_text     #       4
task_text       #       4
mask_text       #       4
all_text        #       4
fake_postrect	#	4		; do we want to fake the post-rectangle filter? (Wimp < 3.86)
get_handle_from_r10 #   4               ; do we get the window handle from r10 or the stack
                                        ; for get-rectangle filters? (from r10 for Wimp > 3.99)

f_messagesopen  *       (1:SHL:0)

max_running_work   *       (@-wsorigin)


        LNK     s.ModHead

