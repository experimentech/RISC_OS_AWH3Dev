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
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sort directory

; In    r1 -> dirviewer block (strange)
;       [r1, #d_viewmode] :SHR: dbb_sortmode =
;         0 (name), 1 (type), 2 (size), 3 (date)

; Out   items re-ordered (blocks only - names are ref by ptrs)

SortDir Entry   "r1-r11"

 [ debug
 DREG r1, "Sorting dirviewer "
 ]
        InvSmiWidth  r1
        LDR     r0, [r1, #d_nfiles]
        CMP     r0, #2
        EXIT    LT                      ; [nothing to do]

        ; Check if there's room in sortingbuffer
        ADR     r10, sortingbuffer      ; r10 -> buffer
        CMP     r0, #sortingbuffer_entries
        BLT     %FT01

        ; If not, try and claim enough memory in RMA
        MOV     r3, r0, LSL #2          ; we want entries * 4 bytes
        MOV     r0, #ModHandReason_Claim
        SWI     XOS_Module
        EXIT    VS                      ; Couldn't claim it
        MOV     r10, r2                 ; r10 -> buffer

; work out correct sorting procedure for HeapSort, and do it!
01
        LDRB    r0, [r1, #d_viewmode]
        TST     r0, #db_sortorder
        ADREQ   r14, sortproctable
        ADRNE   r14, reversesortproctable

        AND     r0, r0, #db_sortmode
        MOV     r0, r0, LSR #dbb_sortmode ; 0..3
 [ debug
 DREG r0, "sort mode (0..3) "
 ]
        LDR     r2, [r14, r0, LSL #2]   ; offset to routine
        ADD     r2, r14, r2             ; r2 -> routine for OS_HeapSort

        LDR     r0, [r1, #d_nfiles]     ; r0 = number of items
        MOV     r3, r1                  ; r3 -> dirviewer^ passed in r12 to sort procs
        ADD     r4, r1, #d_headersize   ; r4 -> base of data
        MOV     r5, #df_size            ; r5 = element size
        MOV     r1, r10                 ; r1 -> array of pointers
 [ debug
 DREG r0,"OS_HeapSort: n ",cc,Integer
 DREG r1,", array ",cc
 DREG r2,", proc ",cc
 DREG r3,", baseaddr ",cc
 DREG r4,", block ",cc
 DREG r5,", size "
 ]
        TST     r1, #2_111 :SHL: 29     ; use old or new SWI depending on
        BNE     %FT20                   ; address
        ORR     r1, r1, #2_11 :SHL: 30  ; Ask HeapSort to build pointer array
                                        ; itself and shuffle data after sorting
        SWI     XOS_HeapSort
        B       %FT25
20      MOV     r7, #2_11 :SHL: 30
        SWI     XOS_HeapSort32
25
        ; if we claimed any RMA for the sort, free it now
        ADR     r0, sortingbuffer
        CMP     r0, r10
        EXIT    EQ                      ; We used sortingbuffer, not RMA

        MOV     r0, #ModHandReason_Free
        MOV     r2, r10
        SWI     XOS_Module
        EXIT

sortproctable

        DCD     sort_name - sortproctable ; directory viewer
        DCD     sort_type - sortproctable
        DCD     sort_size - sortproctable
        DCD     sort_date - sortproctable

reversesortproctable

        DCD     reverse_sort_name - reversesortproctable ; directory viewer
        DCD     reverse_sort_type - reversesortproctable
        DCD     reverse_sort_size - reversesortproctable
        DCD     reverse_sort_date - reversesortproctable

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Sort procedures called in SVC mode, with r13 FD stack

; In    r0 -> first object
;       r1 -> second object
;       r12 -> value from r3 on calling OS_HeapSort

; Out   LT,GE from CMP between first and second objects
;       r0-r3 may be corrupted
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; sort by name:
; -------------
;   names (A..Z)

reverse_sort_name

sort_name Entry
        LDR     r3, [r12, #d_filenames] ; base of filenames
        
        LDR     r2, [r1, #df_fileptr]
 [ not_16bit_offsets
        ADD     r2, r3, r2              ; r2 -> name(r1)
 |
        ADD     r2, r3, r2, LSR #16     ; r2 -> name(r1)
 ]

        LDR     r1, [r0, #df_fileptr]
 [ not_16bit_offsets
        ADD     r1, r3, r1              ; r1 -> name(r0)
 |
        ADD     r1, r3, r1, LSR #16     ; r1 -> name(r0)
 ]

        LDRB    r0, [r12, #d_viewmode]  ; sorting mode

        TST     r0, #db_sortorder
        MOVNE   r3, r1                  ; swap r1 & r2 if reverse sort
        MOVNE   r1, r2
        MOVNE   r2, r3

        TST     r0, #db_sortnumeric
        MOVEQ   r3, #Collate_IgnoreCase
        MOVNE   r3, #Collate_IgnoreCase :OR: Collate_InterpretCardinals

        MOV     r0, #-1                 ; use configured territory
        SWI     XTerritory_Collate
        EXIT    VS
        CMP     r0, #0                  ; set LT, GE depending on which is smaller
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; sort by type:
; -------------
;   untyped files
;   typed files (000..FFF)
;   applications
;   directories

        MACRO
$label  LType   $rd, $rs, $rtemp
$label  LDRB    $rtemp, [$rs, #df_type]
        CMP     $rtemp, #dft_applic
        MOVEQ   $rd, #&1000             ; applications next to last in list
        MOVNE   $rd, #&2000             ; dirs last in list

        CMP     $rtemp, #dft_file
      [ version >= 143
        CMPNE   $rtemp, #dft_partition
      ]
        BNE     %FT01

 ASSERT df_load = 0
 ASSERT df_exec = 4
 ASSERT $rd < $rtemp ; For LDMIA !!!
        LDMIA   $rs, {$rd, $rtemp}

        TEQ     $rd, $rtemp
        MOVEQ   $rd, #-1
        BEQ     %FT01

        CMN     $rd, #&00100000
        MOVCC   $rd, #-1                ; [undated; first in list]
        MOVCS   $rd, $rd, LSL #12
        MOVCS   $rd, $rd, LSR #20
01
        MEND

reverse_sort_type Entry

        LType   r3, r0, r14
        LType   r2, r1, r14
        B       %FT10

sort_type ALTENTRY

        LType   r2, r0, r14
        LType   r3, r1, r14
10
        CMP     r2, r3
        BLEQ    sort_name               ; sort by name if types equal
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; sort by size:
; -------------
;   files (large..0)
;   applications        full size not known, so can't really order by it
;   directories         ditto

        MACRO
$label  LSize   $rdlo, $rdhi, $rs
$label  LDRB    $rdlo, [$rs, #df_type]
 ASSERT dft_dir < dft_applic
 ASSERT dft_file < dft_dir
      [ version >= 143
        TEQ     $rdlo, #dft_partition
        MOVEQ   $rdlo, #dft_file        ; equate partitions to files
      ]
        SUBS    $rdhi, $rdlo, #dft_dir  ; = 0 => 0 = dirs lowest
        MOVGT   $rdhi, #1               ; > 0 => 1 = applications next
        MOVMI   $rdhi, #2               ; < 0 => 2 = files highest
        MOVGE   $rdlo, #0               ; >=0 => apps & dirs have zero size
        LDRMI   $rdlo, [$rs, #df_length]
        MEND

reverse_sort_size Entry "r4, r5"

        LSize   r3, r5, r0
        LSize   r2, r4, r1
        B       %FT10

sort_size ALTENTRY

        LSize   r2, r4, r0
        LSize   r3, r5, r1
10
        SUBS    r14, r3, r2             ; descending order - CMP64
        MOVNE   r14, #Z_bit
        SBCS    r2, r5, r4
      [ No32bitCode
        TEQEQP  r14, pc
      |
        MRSEQ   r4, CPSR
        EOREQ   r4, r4, r14
        MSREQ   CPSR_f, r4
      ]
        BLEQ    sort_name               ; NB. don't corrupt r0,r1 if going
        EXIT                            ; to do sort_name !
        
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; sort by date:
; -------------
;   objects (new..1900)
;
; NB. Getting signed CMP results was difficult

        MACRO
$label  LDate   $rdlo, $rdhi, $rs
$label  LDRB    $rdhi, [$rs, #df_load]  ; High byte of date
        LDR     $rdlo, [$rs, #df_exec]  ; Low word of date
        MEND

reverse_sort_date Entry "r4, r5"

        LDate   r3, r5, r0              ; Get date
        LDate   r2, r4, r1
        B       %FT10

sort_date ALTENTRY

        LDate   r2, r4, r0              ; Get date
        LDate   r3, r5, r1
10
        SUBS    r14, r3, r2             ; descending order - CMP64
        MOVNE   r14, #Z_bit
        SBCS    r2, r5, r4
      [ No32bitCode
        TEQEQP  r14, pc
      |
        MRSEQ   r4, CPSR
        EOREQ   r4, r4, r14
        MSREQ   CPSR_f, r4
      ]
        BLEQ    sort_name               ; NB. don't corrupt r0,r1 if going
        EXIT                            ; to do sort_name !


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; sort for optimal redraw order
; -----------------------------
;
; This is similar to sort_type, except we don't care about the name, but we do
; care about dfs_selected & dfs_opened
;
; Note that R0 & R1 are (reverse) fileinfo numbers, not fileinfo pointers!

sort_redraw ALTENTRY
        ; Get fileinfo pointers. r12 points to end of fileinfo list, so:
        ASSERT  df_size = 7*4
        SUB     r2, r12, r0, LSL #3+2
        SUB     r3, r12, r1, LSL #3+2
        ADD     r0, r2, r0, LSL #2
        ADD     r1, r3, r1, LSL #2

        LType   r2, r0, r14
        LType   r3, r1, r14
        CMP     r2, r3
        BNE     %FT10
        LDRB    r2, [r0, #df_state]
        LDRB    r3, [r1, #df_state]
        AND     r2, r2, #dfs_selected + dfs_opened
        AND     r3, r3, #dfs_selected + dfs_opened
        CMP     r2, r3
10
        EXIT        

        END
