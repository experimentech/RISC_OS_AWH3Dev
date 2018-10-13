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
; s.SWIS

Filter_SWIdecode
        Push    "LR"
        LDR     wsptr,[R12]                     ; wsptr --> workspace

        Debug   xx,"SWI ",r11

        CMP     R11,#maxnewswi
        ADDCC   R14,R11,#(swijptable-swijporg-4)/4    ; bodge factor
        ADDCC   PC,PC,R14,ASL #2                ; go!
swijporg
        Push    "R4"
        ADR     R0,ErrorBlock_BadSWI
        ADRL    R4,Title
        BL      MsgTrans_ErrorLookup
        Pull    "R4,PC"

swijptable
        B       SWIFilter_RegisterPreFilter
        B       SWIFilter_RegisterPostFilter
        B       SWIFilter_DeRegisterPreFilter
        B       SWIFilter_DeRegisterPostFilter
        B       SWIFilter_RegisterRectFilter
        B       SWIFilter_DeRegisterRectFilter
	B	SWIFilter_RegisterCopyFilter
	B	SWIFilter_DeRegisterCopyFilter
	B	SWIFilter_RegisterPostRectFilter
	B	SWIFilter_DeRegisterPostRectFilter
	B	SWIFilter_RegisterPostIconFilter
	B	SWIFilter_DeRegisterPostIconFilter
endswijptable
maxnewswi   *   (endswijptable-swijptable)/4

ErrorBlock_BadSWI
        DCD     0
        DCB     "BadSWI", 0
        ALIGN

Filter_SWInames
        DCB     "Filter",0                ; prefix
        DCB     "RegisterPreFilter",0
        DCB     "RegisterPostFilter",0
        DCB     "DeRegisterPreFilter",0
        DCB     "DeRegisterPostFilter",0
        DCB     "RegisterRectFilter",0
        DCB     "DeRegisterRectFilter",0
	DCB	"RegisterCopyFilter",0
	DCB	"DeRegisterCopyFilter",0
	DCB	"RegisterPostRectFilter",0
	DCB	"DeRegisterPostRectFilter",0
	DCB	"RegisterPostIconFilter",0
	DCB	"DeRegisterPostIconFilter",0
        DCB     0
        ALIGN

;;--------------------------------------------------------------------------
;; Filter_RegisterPreFilter
;;
;; Add a new pre filter to the list of pre filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter is applied.
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterPreFilter

        Push    "r0-r3"

        DebugS  register,"Register pre-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"pre-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r3,LR",VS
        RETURNVS VS                 ; Restore callers flags, and set V

; Link block ^r2 to list.

        LDR     r14,pre_filters
        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,pre_filters

        STR     R14,[r2,#f_mask]    ; Mask is not used for pre_filters.
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register filters "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.
        LDR     R14,[sp,#3*4]
        MOV     R14,R14,ASL #16
        MOV     R14,R14,LSR #16
        STR     R14,[r2,#f_task]    ; Task ID.

        Debug   register,"Pre-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r3,LR"          ; V will be clear
        RETURNVC

; Error exit, freeing claimed block

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,pre_filters
        MOV     R0,#0
        STR     R0,pre_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r3,LR"
        RETURNVS                    ; Restore callers flags, and set V


;;--------------------------------------------------------------------------
;; Filter_RegisterPostFilter
;;
;; Add a new post filter to the list of post filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter is applied.
;;        R4 - Event mask ( 1 bit masks the event out ).
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterPostFilter

        Push    "r0-r4"

        DebugS  register,"Register post-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"post-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Link block ^r2 to list.

        LDR     r14,post_filters

        Debug   register,"Post-filter anchor",r14

        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,post_filters
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register post-filter "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.
        LDR     R14,[sp,#3*4]
        MOV     R14,R14,ASL #16
        MOV     R14,R14,LSR #16
        STR     R14,[r2,#f_task]    ; Task ID.
        LDR     R14,[sp,#4*4]
        STR     R14,[r2,#f_mask]    ; Event mask.

        Debug   register,"Post-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r4,LR"          ; V will be clear
        RETURNVC
        
; Error exit

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,post_filters
        MOV     R0,#0
        STR     R0,post_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r4,LR"
        RETURNVS


;;-------------------------------------------------------------------------
;; find_filter
;;
;; Entry:
;;
;;        R0 - Pointer to name.
;;        R1 - Address
;;        R2 - R12 value
;;        R3 - Task handle
;;        R4 - Pointer to list head.
;; Exit:
;;        If found:
;;                  VC , R4-> filter block.
;;        If not found VS
;;
find_filter

        Push    "LR"

01
        LDR     r4,[r4,#next_ptr]
        CMP     r4,#0
        SETV    EQ
        Pull    "PC",VS            ; Not found.
        LDR     r14,[r4,#f_name]
        TEQ     r14,r0
        BNE     %BT01
        LDR     r14,[r4,#f_address]
        TEQ     r14,r1
        BNE     %BT01
        LDR     r14,[r4,#f_R12]
        TEQ     r14,r2
        BNE     %BT01
        LDR     r14,[r4,#f_task]
        TEQ     r14,r3
        CMPNE   r14,#0
        BNE     %BT01

; All are equal - found wanted filter.

        Pull    "PC"

;;--------------------------------------------------------------------------
;; Filter_DeRegisterPreFilter
;;
;; Remove a pre filter from the list of pre filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter was applied.
;;
;;        All must be the same as those passed to RegisterPreFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterPreFilter

        Push    "r0-r4"

        DebugS  register,"De-register pre-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

        ADR     r4,pre_filters
        MOV     R3,R3,ASL #16
        MOV     R3,R3,LSR #16   ; Task ID
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find pre-filter "

        ADDVS   sp,sp,#4
        ADRVS   r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,pre_filters      ; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

        LDR     r14,pre_filters
        CMP     r14,#0               ; Any filters left?
        MOVEQ   r0,#WimpFilter_PrePoll
        MOVEQ   r1,#0                ;  No then de-register
 [ debugregister
        BNE     %FT00
        Debug   register,"Deregistering pre-filter",r0,r1
00
 ]
        SWIEQ   XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register pre-filter "

        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free pre-filter block "

        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_DeRegisterPostFilter
;;
;; Remove a pre filter from the list of pre filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter was applied.
;;
;;        All must be the same as those passed to RegisterPreFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterPostFilter

        Push    "r0-r4"

        DebugS  register,"De-register post-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

        ADR     r4,post_filters
        MOV     R3,R3,ASL #16
        MOV     R3,R3,LSR #16   ; Task ID
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find post-filter "

        ADRVS   r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        ADDVS   sp,sp,#4
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,post_filters     ; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

        LDR     r14,post_filters
        CMP     r14,#0               ; Any filters left?
        MOVEQ   r0,#WimpFilter_PostPoll
        MOVEQ   r1,#0                ;  No then de-register
 [ debugregister
        BNE     %FT00
        Debug   register,"Deregistering post-filter",r0,r1
00
 ]
        SWIEQ   XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register post-filter "

        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free post-filter block "

        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_RegisterRectFilter
;;
;; Add a new rect filter to the list of rect filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter is applied.
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterRectFilter

        Push    "r0-r3"

        DebugS  register,"Register rect-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"rect-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r3,LR",VS
        RETURNVS VS

; Link block ^r2 to list.

        LDR     r14,rect_filters
        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,rect_filters

        STR     R14,[r2,#f_mask]    ; Mask is not used for rect_filters.
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register filters "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.
        LDR     R14,[sp,#3*4]
        MOV     R14,R14,ASL #16
        MOV     R14,R14,LSR #16
        STR     R14,[r2,#f_task]    ; Task ID.

        Debug   register,"rect-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r3,LR"          ; V will be clear
        RETURNVC
        
; Error exit, freeing claimed block

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,rect_filters
        MOV     R0,#0
        STR     R0,rect_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r3,LR"
        RETURNVS

ErrorBlock_UnknownFilter
        DCD    0
        DCB    "UnkF",0
        ALIGN

;;--------------------------------------------------------------------------
;; Filter_RegisterCopyFilter
;;
;; Add a new rect filter to the list of rect filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterCopyFilter

        Push    "r0-r3"

        DebugS  register,"Register copy-filter",R0,80
        Debug   register,"Name, address, ws",R0,R1,R2

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"copy-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r3,LR",VS
        RETURNVS VS

; Link block ^r2 to list.

        LDR     r14,copy_filters
        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,copy_filters

        STR     R14,[r2,#f_mask]    ; Mask is not used for copy_filters.
        STR     R14,[r2,#f_task]    ; Task is not used for copy_filters.
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register filters "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.

        Debug   register,"copy-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r3,LR"
        RETURNVC

; Error exit, freeing claimed block

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,copy_filters
        MOV     R0,#0
        STR     R0,copy_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r3,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_RegisterPostRectFilter
;;
;; Add a new post-rect filter to the list of post-rect filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter is applied.
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterPostRectFilter

        Push    "r0-r3"

        DebugS  register,"Register post-rect-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"post-rect-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r3,LR",VS
        RETURNVS VS

; Link block ^r2 to list.

        LDR     r14,post_rect_filters
        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,post_rect_filters

        STR     R14,[r2,#f_mask]    ; Mask is not used for post_rect_filters.
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register filters "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.
        LDR     R14,[sp,#3*4]
        MOV     R14,R14,ASL #16
        MOV     R14,R14,LSR #16
        STR     R14,[r2,#f_task]    ; Task ID.

        Debug   register,"post-rect-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r3,LR"
        RETURNVC
        
; Error exit, freeing claimed block

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,post_rect_filters
        MOV     R0,#0
        STR     R0,post_rect_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r3,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_RegisterPostIconFilter
;;
;; Add a new post-icon filter to the list of post-icon filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Address of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter is applied.
;;
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_RegisterPostIconFilter

        Push    "r0-r3"

        DebugS  register,"Register post-icon-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

; Claim block to put data in.

        MOV     r0, #ModHandReason_Claim
        MOV     r3, #f_block_size
        SWI     XOS_Module

        DebugE  register,"post-icon-filter claim failed "

        ADDVS   sp,sp,#4
        Pull    "r1-r3,LR",VS
        RETURNVS VS

; Link block ^r2 to list.

        LDR     r14,post_icon_filters
        STR     r14,[r2,#next_ptr]  ; Point at next block
        CMP     r14,#0
        STRNE   r2,[r14,#prev_ptr]  ; Make next block point at the new block.
        MOV     R14,#0
        STR     R14,[r2,#prev_ptr]  ; This is the first block in the list
        STR     r2,post_icon_filters

        STR     R14,[r2,#f_mask]    ; Mask is not used for post_icon_filters.
        BLEQ    RegisterFilters     ; Register with wimp if this is first filter

        DebugE  register,"Cant register filters "

        BVS     %FT10               ; Jump if no wimp

        LDR     R14,[sp,#0*4]
        STR     R14,[r2,#f_name]    ; name of filter
        LDR     R14,[sp,#1*4]
        STR     R14,[r2,#f_address] ; address of filter
        LDR     R14,[sp,#2*4]
        STR     R14,[r2,#f_R12]     ; R12 for calling filter.
        LDR     R14,[sp,#3*4]
        MOV     R14,R14,ASL #16
        MOV     R14,R14,LSR #16
        STR     R14,[r2,#f_task]    ; Task ID.

        Debug   register,"post-icon-filter registered ok"

; Exit to caller                    ; Preserves caller's flags.

        Pull    "r0-r3,LR"
        RETURNVC
        
; Error exit, freeing claimed block

10      STR     R0,[sp,#0*4]        ; Return error ptr
        LDR     R2,post_icon_filters
        MOV     R0,#0
        STR     R0,post_icon_filters
        MOV     R0,#ModHandReason_Free ; Free the block if error
        SWI     XOS_Module
        Pull    "r0-r3,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_DeRegisterRectFilter
;;
;; Remove a rect filter from the list of rect filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter was applied.
;;
;;        All must be the same as those passed to RegisterRectFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterRectFilter

        Push    "r0-r4"

        DebugS  register,"De-register rect-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

        ADR     r4,rect_filters
        MOV     R3,R3,ASL #16
        MOV     R3,R3,LSR #16   ; Task ID
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find rect-filter "

        ADDVS   sp,sp,#4
        ADRVS   r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,rect_filters      ; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

deregister_rect_for_fake_post_rect
        LDR     r14,rect_filters
        CMP     r14,#0               ; Any filters left?
        MOVEQ   r0,#WimpFilter_GetRectangle
        MOVEQ   r1,#0                ;  No then de-register
 [ debugregister
        BNE     %FT00
        Debug   register,"Deregistering rect-filter",r0,r1
00
 ]
        SWIEQ   XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register rect-filter "

        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free rect-filter block "

	; DeRegisterPostRectFilter can exit through here, so
	; keep the stack usage the same!
        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_DeRegisterPostRectFilter
;;
;; Remove a post-rect filter from the list of rect filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;        R3 - Task handle of task to which filter was applied.
;;
;;        All must be the same as those passed to RegisterPostRectFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterPostRectFilter

        Push    "r0-r4"

        DebugS  register,"De-register post-rect-filter",R0,80
        Debug   register,"Name, address, ws, task",R0,R1,R2,R3

        ADR     r4,post_rect_filters
        MOV     R3,R3,ASL #16
        MOV     R3,R3,LSR #16   ; Task ID
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find post-rect-filter "

        ADDVS   sp,sp,#4
        ADRVS   r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,post_rect_filters; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

        LDR     r14,post_rect_filters
        CMP     r14,#0               ; Any filters left?
	BNE	%FT05

	LDR	r14,fake_postrect	; Consider freeing RectFilter if faking
	TEQ	r14,#0
	BNE	deregister_rect_for_fake_post_rect

        MOV     r0,#WimpFilter_PostGetRectangle
        MOV     r1,#0
 [ debugregister
        Debug   register,"Deregistering post-rect-filter",r0,r1
 ]
        SWI     XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register post-rect-filter "

05
        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free post-rect-filter block "

        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_DeRegisterCopyFilter
;;
;; Remove a copy filter from the list of copy filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;
;;        All must be the same as those passed to RegisterCopyFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterCopyFilter

        Push    "r0-r4"

        DebugS  register,"De-register copy-filter",R0,80
        Debug   register,"Name, address, ws",R0,R1,R2

        ADR     r4,copy_filters
	MOV	r3,#0
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find copy-filter "

        ADDVS   sp,sp,#4
        ADRVS   r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,copy_filters      ; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

        LDR     r14,copy_filters
        CMP     r14,#0               ; Any filters left?
        MOVEQ   r0,#WimpFilter_BlockCopy
        MOVEQ   r1,#0                ;  No then de-register
 [ debugregister
        BNE     %FT00
        Debug   register,"Deregistering copy-filter",r0,r1
00
 ]
        SWIEQ   XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register copy-filter "

        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free copy-filter block "

        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

;;--------------------------------------------------------------------------
;; Filter_DeRegisterPostIconFilter
;;
;; Remove a post-icon filter from the list of posticon filters.
;;
;; Entry:
;;        R0 - Pointer to 0 terminated filter name.
;;        R1 - Addresss of filter.
;;        R2 - Value to be passed in R12.
;;
;;        All must be the same as those passed to RegisterPostIconFilter
;; Exit:
;;        Registers preserved.
;;
;;

SWIFilter_DeRegisterPostIconFilter

        Push    "r0-r4"

        DebugS  register,"De-register post-icon-filter",R0,80
        Debug   register,"Name, address, ws",R0,R1,R2

        ADR     r4,post_icon_filters
        MOV     R3,R3,ASL #16   ; Fixed 31/12/97 SNB.  Used to mov r3, #0
        MOV     R3,R3,LSR #16   ; Task ID
        BL      find_filter     ; Finds the filter in the list

        DebugE  register,"Cant find posticon-filter "

        ADDVS   sp,sp,#4
        ADRVSL  r0,ErrorBlock_UnknownFilter
        BLVS    MsgTrans_ErrorLookup
        Pull    "r1-r4,LR",VS
        RETURNVS VS

; Found filter, remove it from list.

        LDR     r14,[r4,#next_ptr]
        LDR     r0, [r4,#prev_ptr]
        CMP     r0,#0
        STREQ   r14,post_icon_filters ; Next block is now first on the list
        STRNE   r14,[r0,#next_ptr]   ; Or is next of previous block.
        CMP     R14,#0
        STRNE   r0,[R14,#prev_ptr]   ; If there is a next block update its prev_ptr.

        LDR     r14,post_icon_filters
        CMP     r14,#0               ; Any filters left?
        MOVEQ   r0,#WimpFilter_PostIconGetRectangle
        MOVEQ   r1,#0                ;  No then de-register
 [ debugregister
        BNE     %FT00
        Debug   register,"Deregistering post-icon-filter",r0,r1
00
 ]
        SWIEQ   XWimp_RegisterFilter ; Remove filters for speed

        DebugE  register,"Cant de-register post-icon-filter "

        MOV     R0,#ModHandReason_Free ; Now free the block.
        MOV     R2,R4
        SWI     XOS_Module

        DebugE  register,"Cant free post-icon-filter block "

        Pull    "r0-r4,PC",VC

        ADD     sp,sp,#4                ; Drop caller's R0
        Pull    "r1-r4,LR"
        RETURNVS

        LNK     s.MsgTrans
