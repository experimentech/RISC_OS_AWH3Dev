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
        TTL     DOSFS C Support functions               > s.DOSFSctl
        ; -------------------------------------------------------------------
        ; Copyright (c) 1990, JGSmith
        ; -------------------------------------------------------------------

        AREA    |DOSFS_Support|,CODE,READONLY

        ; -------------------------------------------------------------------
        ; Use internal RMA alloc code
                GBLL    RMAalloc
RMAalloc        SETL    {TRUE}

        IMPORT  |raise|
        IMPORT  |_Lib$Reloc$Off|
        IMPORT  |_syserr|

        EXPORT  |writeWORD|
        EXPORT  |loadWORD|

        ; The following functions seem to have prototypes in <kernel.h>, but
        ; do not appear in the Stubs for SharedCLibrary 3.66.
        [       RMAalloc
        EXPORT  |_kernel_RMAalloc|
        EXPORT  |_kernel_RMAextend|
        EXPORT  |_kernel_RMAfree|
        ]

        ; FileSwitch interface functions
        EXPORT  |DOSFS_Open|
        EXPORT  |DOSFS_GetBytes|
        EXPORT  |DOSFS_PutBytes|
        EXPORT  |DOSFS_Args|
        EXPORT  |DOSFS_Close|
        EXPORT  |DOSFS_File|
        EXPORT  |DOSFS_Func|

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:ModHand
        GET     Hdr:HostFS
        GET     Hdr:Debug
        GET     hdr:NdrDebug
        GET     Hdr:DDVMacros
        GET     Hdr:APCS.<APCS>
        GET     Hdr:CPU.Arch
        GET     MFSmacros.s

      [ :LNOT: No32bitCode :LAND: :LNOT: No26bitCode :LAND: NoARMv3
        !       1, "Disc build variant currently not suitable for ARMv2 targets"
      ]

        ; -------------------------------------------------------------------
        ; Select level of debugging
                GBLL    hostvdu
hostvdu         SETL    {FALSE}         ; TUBE debugging output
debug           SETL    {FALSE}
open            SETD    {FALSE}
bget            SETD    {FALSE}
bput            SETD    {FALSE}
close           SETD    {FALSE}
args            SETD    {FALSE}
file            SETD    {FALSE}
func            SETD    {FALSE}

      [ debug
        InsertNDRDebugRoutines
      ]

        ; -------------------------------------------------------------------
        ; Errors
err_badparargs  *       &00
err_badparfile  *       &01
err_badparfunc  *       &02
err_nostack     *       &15
err_notsupported *      &A5

        ; -------------------------------------------------------------------
        ; Misc constants
spare_word      *       &2053474A               ; "JGS "

        ; -------------------------------------------------------------------
        ; Private (assembler) data
sl_offset       &       |_Lib$Reloc$Off|        ; stack overflow buffer size
|_errptr|       &       |_syserr|               ; pointer to error block
        LTORG

        ; -------------------------------------------------------------------
        ; Filing System interface:

        IMPORT  |DOSFS_open_file|      ; open a file
        IMPORT  |DOSFS_get_bytes|      ; read bytes from an open file
        IMPORT  |DOSFS_put_bytes|      ; write bytes to an open file
        IMPORT  |DOSFS_close_file|     ; close an open file

        IMPORT  |DOSFS_write_extent|   ; write file extent
        IMPORT  |DOSFS_alloc|          ; read size allocated to file
        IMPORT  |DOSFS_flush|          ; flush file buffer
        IMPORT  |DOSFS_ensure|         ; ensure file size
        IMPORT  |DOSFS_write_zeros|    ; write zeros to file
        IMPORT  |DOSFS_read_datestamp| ; read load/exec addresses of open file

        IMPORT  |DOSFS_save_file|      ; save a complete file image
        IMPORT  |DOSFS_read_cat|       ; read catalogue information
        IMPORT  |DOSFS_write_cat|      ; write catalogue information
        IMPORT  |DOSFS_delete|         ; delete object
        IMPORT  |DOSFS_create|         ; create file
        IMPORT  |DOSFS_create_dir|     ; create directory
        IMPORT  |DOSFS_read_block_size| ; return natural block size for image

        IMPORT  |DOSFS_rename|            ; rename object
        IMPORT  |DOSFS_read_dir|          ; read directory entries
        IMPORT  |DOSFS_read_dir_info|     ; read directory entries and info
        IMPORT  |DOSFS_image_open|        ; notification of image file open
        IMPORT  |DOSFS_image_close|       ; notification of image file close
        IMPORT  |DOSFS_defect_list|       ; generate defect list for image
        IMPORT  |DOSFS_add_defect|        ; add a defect into the list
        IMPORT  |DOSFS_read_boot_option|  ; read boot option
        IMPORT  |DOSFS_write_boot_option| ; write boot option
        IMPORT  |DOSFS_used_space_map|    ; generate space map
        IMPORT  |DOSFS_read_free_space|   ; return free space information
        IMPORT  |DOSFS_namedisc|          ; namedisc
        IMPORT  |DOSFS_stampimage|        ; update the image identity
        IMPORT  |DOSFS_objectatoffset|    ; return name of object at offset

        IMPORT  |global_error|            ; generate error message from number

        ; -------------------------------------------------------------------

DOSFS_Open
        ;Debug   open,"DOSFS_Open",r0,r1,r6
                        ; a1 == r0      type of open to perform
                        ; a2 == r1      pointer to NULL terminated filename
        MOV     a3,r6   ; a3 == r6      image handle for this file

        Ccall   |DOSFS_open_file|
        [ :LNOT: No32bitCode
        LDMVCIA r0,{r0-r4}              ; r0 = pointer to information block
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit             ; error -> r0 = ptr to error block
        LDMIA   r0,{r0-r4}              ; r0 = pointer to information block as below
        BICS    pc,lr,#V_bit
        ]
        ; r0 == file information word
        ; r1 == filing system handle (0 = "not found")
        ; r2 == buffer size (0 if file is unbuffered, 2^n (n = 6..10))
        ; r3 == file extent (buffered files only)
        ; r4 == current file allocation (in buffer size multiples)

        ; -------------------------------------------------------------------

DOSFS_GetBytes
        ;Debug   bget,"DOSFS_GetBytes",r1,r2,r3,r4
        MOV     a1,r1           ; r1 = filing system handle
        MOV     a2,r2           ; r2 = memory address for data
        MOV     a3,r3           ; r3 = number of bytes to transfer
        MOV     a4,r4           ; r4 = file offset (PTR#)
        Ccall   |DOSFS_get_bytes|
        ; r0 = byte read if unbuffered
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------

DOSFS_PutBytes
        ;Debug   bput,"DOSFS_PutBytes",r1,r2,r3,r4
        MOV     a1,r1           ; r1 = filing system handle
        MOV     a2,r2           ; r2 = memory address of data
        MOV     a3,r3           ; r3 = number of bytes to transfer
        MOV     a4,r4           ; r4 = file offset (PTR#)
        Ccall   |DOSFS_put_bytes|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------

DOSFS_Close
        ;Debug   close,"DOSFS_Close",r1,r2,r3
        MOV     a1,r1           ; r1 = filing system handle
        MOV     a2,r2           ; r2 = new load address for file
        MOV     a3,r3           ; r3 = new exec address for file
        Ccall   |DOSFS_close_file|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------

DOSFS_Args
        ;Debug   args,"DOSFS_Args",r0
        ; r0 reason code:
        ; &03 = write file extent (|DOSFS_write_extent|)
        ;       in:     r1 = filing system handle
        ;               r2 = new file extent
        ;       out:    no conditions
        ;
        ; &04 = read size allocated to file (|DOSFS_alloc|)
        ;       in:     r1 = filing system handle
        ;       out:    r2 = size allocated to file by filing system
        ;
        ; &06 = flush file buffer (|DOSFS_flush|)
        ;       in:     r1 = filing system handle
        ;       out:    r2 = load address of file (or 0)
        ;               r3 = exec address of file (or 0)
        ;
        ; &07 = ensure file size (|DOSFS_ensure|)
        ;       in:     r1 = filing system handle
        ;               r2 = size of file to ensure
        ;       out:    r2 = size of file actually ensured
        ;
        ; &08 = write zeroes to file (|DOS_write_zeros|)
        ;       in:     r1 = file handle
        ;               r2 = file address to write zeros at
        ;               r3 = number of zeros to write
        ;
        ; &09 = read load/exec addresses (|DOS_read_datestamp|)
        ;       in:     r1 = file handle
        ;       out:    r2 = load address of file
        ;               r3 = execute address of file
        ;
        CMP     r0,#args_table_entries
        BGT     DOS_args_badparameter
        ADD     pc,pc,r0,LSL #2
        &       spare_word                      ; DO NOT REMOVE OR ADD CODE
args_table_start
        B       DOS_notsupported                ; 00 / 0
        B       DOS_notsupported                ; 01 / 1
        B       DOS_notsupported                ; 02 / 2
        B       |call_DOSFS_write_extent|       ; 03 / 3
        B       |call_DOSFS_alloc|              ; 04 / 4
        B       DOS_notsupported                ; 05 / 5
        B       |call_DOSFS_flush|              ; 06 / 6
        B       |call_DOSFS_ensure|             ; 07 / 7
        B       |call_DOSFS_write_zeros|        ; 08 / 8
        B       |call_DOSFS_read_datestamp|     ; 09 / 9
args_table_end
args_table_entries      *       ((args_table_end - args_table_start) / 4)

DOS_args_badparameter
        MOV     a1,#err_badparargs
        Ccall   |global_error|
        [ :LNOT: No32bitCode
        MSR     CPSR_f,#V_bit            ; global_error doesn't return -1,hence Ccall doesn't set V for us
        MOV     pc,lr
        |
        ORRS    pc,lr,#V_bit
        ]

|call_DOSFS_write_extent|
        MOV     a1,r1                   ; filing system handle
        MOV     a2,r2                   ; new file extent
        Ccall   |DOSFS_write_extent|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_alloc|
        MOV     a1,r1                   ; filing system handle
        Ccall   |DOSFS_alloc|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_flush|
        MOV     a1,r1                   ; filing system handle
        Ccall   |DOSFS_flush|
        [ :LNOT: No32bitCode
        LDMVCIA r0,{r2,r3}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        LDMIA   r0,{r2,r3}
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_ensure|
        MOV     a1,r1                   ; filing system handle
        MOV     a2,r2                   ; size to ensure
        Ccall   |DOSFS_ensure|
        [ :LNOT: No32bitCode
        MOVVC   r2,a1                   ; actual size ensured
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r2,a1                   ; actual size ensured
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_write_zeros|
        MOV     a1,r1                   ; filing system handle
        MOV     a2,r2                   ; offset within file
        MOV     a3,r3                   ; number of zeros to write
        Ccall   |DOSFS_write_zeros|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_datestamp|
        MOV     a1,r1                   ; filing system handle
        Ccall   |DOSFS_read_datestamp|
        [ :LNOT: No32bitCode
        LDMVCIA r0,{r2,r3}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        LDMIA   r0,{r2,r3}
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------

DOSFS_File
        ;Debug   file,"DOSFS_File",r0
        ; r0 reason code:
        ;
        ; &00 = save file (|DOSFS_save_file|)
        ;       in:     r1 = pointer to NULL terminated filename
        ;               r2 = load address of file
        ;               r3 = exec address of file
        ;               r4 = start address in memory of data
        ;               r5 = end address in memory (plus one)
        ;               r6 = filing system image handle
        ;       out:    r6 = pointer to leafname (*OPT 1 n printing)
        ;
        ; &01 = write catalogue information (|DOSFS_write_cat|)
        ;       in:     r1 = pointer to NULL terminated wildcarded filename
        ;               r2 = load address to associate with file
        ;               r3 = exec address to associate with file
        ;               r5 = attributes to associate with file
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &05 = read catalogue information (|DOSFS_read_cat|)
        ;       in:     r1 = pointer to NULL terminated wildcarded filename
        ;               r6 = filing system image handle
        ;       out:    r0 = object type
        ;               r2 = load address
        ;               r3 = exec address
        ;               r4 = file length
        ;               r5 = file attributes
        ;
        ; &06 = delete object (|DOSFS_delete|)
        ;       in:     r1 = pointer to NULL terminated filename
        ;               r6 = filing system image handle
        ;       out:    r0 = object type
        ;               r2 = load address
        ;               r3 = exec address
        ;               r4 = file length
        ;               r5 = file attributes
        ;
        ; &07 = create file (|DOSFS_create|)
        ;       in:     r1 = pointer to NULL terminated filename
        ;               r2 = load address to associate with file
        ;               r3 = exec address to associate with file
        ;               r4 = length
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &08 = create directory (|DOSFS_create_dir|)
        ;       in:     r1 = pointer to NULL terminated directory name
        ;               r2 = load address (new feature)
        ;               r3 = exec address (new feature)
        ;               r4 = number of entries (0 for default)
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &0A = read block size (|DOSFS_read_block_size|)
        ;       in:     r1 = pointer to NULL terminated file name
        ;               r6 = filing system image handle
        ;       out:    r2 = natural block size of the file in bytes
        ;
        CMP     r0,#file_table_entries
        BGT     DOS_file_badparameter
        ADD     pc,pc,r0,LSL #2
        &       spare_word              ; DO NOT REMOVE OR ADD CODE
file_table_start
        B       |call_DOSFS_save_file|          ; 00 / 0
        B       |call_DOSFS_write_cat|          ; 01 / 1
        B       DOS_notsupported                ; 02 / 2
        B       DOS_notsupported                ; 03 / 3
        B       DOS_notsupported                ; 04 / 4
        B       |call_DOSFS_read_cat|           ; 05 / 5
        B       |call_DOSFS_delete|             ; 06 / 6
        B       |call_DOSFS_create|             ; 07 / 7
        B       |call_DOSFS_create_dir|         ; 08 / 8
        B       DOS_notsupported                ; 09 / 9
        B       |call_DOSFS_read_block_size|    ; 0A / 10
file_table_end
file_table_entries      *       ((file_table_end - file_table_start) / 4)

DOS_file_badparameter
        MOV     a1,#err_badparfile
        Ccall   |global_error|
        [ :LNOT: No32bitCode
        MSR     CPSR_f,#V_bit            ; global_error doesn't return -1,hence Ccall doesn't set V for us
        MOV     pc,lr
        |
        ORRS    pc,lr,#V_bit
        ]

|call_DOSFS_save_file|
        MOV     a1,r1                      ; filename
        MOV     a2,r2                      ; load address
        MOV     a3,r3                      ; exec address
        MOV     a4,r4                      ; start address
        Ccall   |DOSFS_save_file|,2,r5-r6  ; end addr and filing system ihand
        [ :LNOT: No32bitCode
        MOVVC   r6,a1                      ; "*OPT 1 n" leafname
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r6,a1                      ; "*OPT 1 n" leafname
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_write_cat|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; load address
        MOV     a3,r3                   ; exec address
        MOV     a4,r5                   ; attributes
        Ccall   |DOSFS_write_cat|,1,r6  ; filing system image handle
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_cat|
        MOV     a1,r1                   ; filename
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_read_cat|
        [ :LNOT: No32bitCode
        ; r0 = pointer to structure containing return information
        LDMVCIA r0,{r0,r2-r5}           ; r6 should be preserved
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        ; r0 = pointer to structure containing return information
        LDMIA   r0,{r0,r2-r5}           ; r6 should be preserved
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_delete|
        MOV     a1,r1                   ; filename
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_delete|
        [ :LNOT: No32bitCode
        ; r0 = pointer to structure containing return information
        LDMVCIA r0,{r0,r2-r5}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        ; r0 = pointer to structure containing return information
        LDMIA   r0,{r0,r2-r5}
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_create|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; load address
        MOV     a3,r3                   ; exec address
        MOV     a4,r4                   ; start address
        Ccall   |DOSFS_create|,2,r5-r6  ; end addr and filing system ihand
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_create_dir|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; r2 = load address
        MOV     a3,r3                   ; r3 = exec address
        MOV     a4,r4                   ; number of entries
        Ccall   |DOSFS_create_dir|,1,r6 ; r6 = filing system image handle
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_block_size|
        MOV     a1,r1                   ; filename
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_read_block_size|
        [ :LNOT: No32bitCode
        MOVVC   r2,r0                   ; block size
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r2,r0                   ; block size
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------

DOSFS_Func
        ;Debug   func,"DOSFS_Func",r0
        ; r0 reason code:
        ;
        ; &08 = rename object (|DOSFS_rename|)
        ;       in:     r1 = pointer to NULL terminated filename
        ;               r2 = pointer to NULL terminated NEW filename
        ;               r6 = filing system image handle
        ;       out:    r1 = rename completion state
        ;
        ; &0E = read directory entries (|DOSFS_read_dir|)
        ;       in:     r1 = pointer to NULL terminated wildcarded dirname
        ;               r2 = data destination memory address
        ;               r3 = number of objects to read
        ;               r4 = offset of first object within directory
        ;               r5 = buffer length
        ;               r6 = filing system image handle
        ;       out:    r3 = number of objects read
        ;               r4 = offset of next item in directory (-1 if end)
        ;
        ; &0F = read directory entries and info. (|DOSFS_read_dir_info|)
        ;       in:     r1 = pointer to NULL terminated wildcarded dirname
        ;               r2 = data destination memory address
        ;               r3 = number of objects to read
        ;               r4 = offset of first object within directory
        ;               r5 = buffer length
        ;               r6 = filing system image handle
        ;       out:    r3 = number of records read
        ;               r4 = offset of next item in directory (-1 if end)
        ;
        ; &15 = notification of new image file (|DOSFS_image_open|)
        ;       in:     r1 = FileSwitch handle for file
        ;               r2 = buffer size for file (0 not known)
        ;       out:    r1 = filing system image handle
        ;
        ; &16 = notification of image file being closed (|DOSFS_image_close|)
        ;       in:     r1 = filing system image handle
        ;       out:    no conditions
        ;
        ; &19 = fill buffer with defect information (|DOSFS_defect_list|)
        ;       in:     r1 = pointer to NULL terminated filename
        ;               r2 = start of buffer in memory
        ;               r5 = buffer length
        ;               r6 = filing system image handle
        ;       out: no conditions
        ;
        ; &1A = add a defect into the image mapping (|DOSFS_add_defect|)
        ;       in:     r1 = ptr to NULL terminated filename in ROOT dir.
        ;               r2 = byte offset to start of defect
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &1B = read boot option (|DOSFS_read_boot_option|)
        ;       in:     r1 = pointer to NULL terminated name of object on
        ;                    thing whose boot option is to be read
        ;               r6 = filing system image handle
        ;       out:    r2 = boot option (as defined in *OPT 4,n)
        ;
        ; &1C = write boot option (|DOSFS_write_boot_option|)
        ;       in:     r1 = pointer to NULL terminated name of object on
        ;                    thing whose boot option is to be written
        ;               r2 = new boot option (as defined in *OPT 4,n)
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &1D = construct used space map (|DOSFS_used_space_map|)
        ;       in:     r2 = buffer for map (pre-filled with 0s)
        ;               r5 = size of buffer
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &1E = read free space (|DOSFS_read_free_space|)
        ;       in:     r6 = filing system image handle
        ;       out:    r0 = free space
        ;               r1 = size of biggest object that can be created
        ;               r2 = size of disc (image)
        ;
        ; &1F = name disc (|DOSFS_namedisc|)
        ;       in:     r2 = pointer to NULL terminated disc name
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &20 = update image identity (DOSFS_stampimage)
        ;       in:     r2 = stamp control information
        ;               r6 = filing system image handle
        ;       out:    no conditions
        ;
        ; &21 = return object identity (DOSFS_objectatoffset)
        ;       in:     r2 = byte offset into image file
        ;               r3 = pointer to buffer to receive object name
        ;               r4 = buffer length
        ;               r6 = filing system image handle
        ;       out:    r2 = type of object found
        ;
        CMP     r0,#func_table_entries
        BGT     DOS_func_badparameter
        ADD     pc,pc,r0,LSL #2
        &       spare_word                      ; DO NOT REMOVE OR ADD CODE
func_table_start
        B       DOS_notsupported                ; 00 / 0
        B       DOS_notsupported                ; 01 / 1
        B       DOS_notsupported                ; 02 / 2
        B       DOS_notsupported                ; 03 / 3
        B       DOS_notsupported                ; 04 / 4
        B       DOS_notsupported                ; 05 / 5
        B       DOS_notsupported                ; 06 / 6
        B       DOS_notsupported                ; 07 / 7
        B       |call_DOSFS_rename|             ; 08 / 8
        B       DOS_notsupported                ; 09 / 9
        B       DOS_notsupported                ; 0A / 10
        B       DOS_notsupported                ; 0B / 11
        B       DOS_notsupported                ; 0C / 12
        B       DOS_notsupported                ; 0D / 13
        B       |call_DOSFS_read_dir|           ; 0E / 14
        B       |call_DOSFS_read_dir_info|      ; 0F / 15
        B       DOS_notsupported                ; 10 / 16
        B       DOS_notsupported                ; 11 / 17
        B       DOS_notsupported                ; 12 / 18
        B       DOS_notsupported                ; 13 / 19
        B       DOS_notsupported                ; 14 / 20
        B       |call_DOSFS_image_open|         ; 15 / 21
        B       |call_DOSFS_image_close|        ; 16 / 22
        B       DOS_notsupported                ; 17 / 23
        B       DOS_notsupported                ; 18 / 24
        B       |call_DOSFS_defect_list|        ; 19 / 25
        B       |call_DOSFS_add_defect|         ; 1A / 26
        B       |call_DOSFS_read_boot_option|   ; 1B / 27
        B       |call_DOSFS_write_boot_option|  ; 1C / 28
        B       |call_DOSFS_used_space_map|     ; 1D / 29
        B       |call_DOSFS_read_free_space|    ; 1E / 30
        B       |call_DOSFS_namedisc|           ; 1F / 31
        B       |call_DOSFS_stampimage|         ; 20 / 32
        B       |call_DOSFS_objectatoffset|     ; 21 / 33
func_table_end
func_table_entries      *       ((func_table_end - func_table_start) / 4)

DOS_func_badparameter
        MOV     r0,#err_badparfunc
        Ccall   |global_error|
        [ :LNOT: No32bitCode
        MSR     CPSR_f,#V_bit            ; global_error doesn't return -1,hence Ccall doesn't set V for us
        MOV     pc,lr
        |
        ORRS    pc,lr,#V_bit
        ]

|call_DOSFS_rename|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; new filename
        MOV     a3,r6                   ; filing system image handle
        Ccall   |DOSFS_rename|
        [ :LNOT: No32bitCode
        MOVVC   r1,r0
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r1,r0                   ; state
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_dir|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; data destination
        MOV     a3,r3                   ; number of objects
        MOV     a4,r4                   ; object offset
        Ccall   |DOSFS_read_dir|,2,r5-r6
        [ :LNOT: No32bitCode
        ; r0 = pointer to structure containing return information
        LDMVCIA r0,{r3-r4}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        ; r0 = pointer to structure containing return information
        LDMIA   r0,{r3-r4}
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_dir_info|
        MOV     a1,r1                   ; filename
        MOV     a2,r2                   ; data destination
        MOV     a3,r3                   ; number of objects
        MOV     a4,r4                   ; object offset
        Ccall   |DOSFS_read_dir_info|,2,r5-r6
        [ :LNOT: No32bitCode
        LDMVCIA r0,{r3-r4}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        ; r0 = pointer to structure containing return information
        LDMIA   r0,{r3-r4}
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_image_open|
        MOV     a1,r1                   ; FileSwitch file handle
        MOV     a2,r2                   ; buffer size
        Ccall   |DOSFS_image_open|
        [ :LNOT: No32bitCode
        MOVVC   r1,r0
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit             ; error return
        ; r0 = filing system image handle
        MOV     r1,r0
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_image_close|
        MOV     a1,r1                   ; filing system image handle
        Ccall   |DOSFS_image_close|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_defect_list|
        MOV     a1,r1                   ; pointer to filename
        MOV     a2,r2                   ; buffer address
        MOV     a3,r5                   ; buffer length
        MOV     a4,r6                   ; filing system image handle
        Ccall   |DOSFS_defect_list|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_add_defect|
        MOV     a1,r1                   ; pointer to filename
        MOV     a2,r2                   ; defect address
        MOV     a3,r6                   ; filing system image handle
        Ccall   |DOSFS_add_defect|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_boot_option|
        MOV     a1,r1                   ; filename
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_read_boot_option|
        [ :LNOT: No32bitCode
        MOVVC   r2,r0                   ; boot option
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r2,r0                   ; boot option
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_write_boot_option|
        MOV     a1,r1                   ; pointer to filename
        MOV     a2,r2                   ; new boot option
        MOV     a3,r6                   ; filing system image handle
        Ccall   |DOSFS_write_boot_option|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_used_space_map|
        MOV     a1,r2                   ; buffer start address
        MOV     a2,r5                   ; buffer size
        MOV     a3,r6                   ; filing system image handle
        Ccall   |DOSFS_used_space_map|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_read_free_space|
        MOV     a1,r6                   ; filing system image handle
        Ccall   |DOSFS_read_free_space|
        [ :LNOT: No32bitCode
        ; r0 = pointer to structure containing return information
        LDMVCIA r0,{r0,r1,r2}
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        ; r0 = pointer to structure containing return information
        LDMIA   r0,{r0,r1,r2}
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_namedisc|
        MOV     a1,r2                   ; NULL terminated discname
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_namedisc|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_stampimage|
        MOV     a1,r2                   ; identity update control information
        MOV     a2,r6                   ; filing system image handle
        Ccall   |DOSFS_stampimage|
        [ :LNOT: No32bitCode
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        BICS    pc,lr,#V_bit
        ]

|call_DOSFS_objectatoffset|
        MOV     a1,r2                   ; byte offset into image
        MOV     a2,r3                   ; object name buffer
        MOV     a3,r4                   ; buffer length
        MOV     a4,r6                   ; filing system image handle
        Ccall   |DOSFS_objectatoffset|
        [ :LNOT: No32bitCode
        MOVVC   r2,r0                   ; object type at entry offset
        MOV     pc,lr
        |
        ORRVSS  pc,lr,#V_bit
        MOV     r2,r0                   ; object type at entry offset
        BICS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------
        ; Called when an unrecognised reason code is presented
DOS_notsupported
        ; There should be no stacked state at this point
        MOV     a1,#err_notsupported
        Ccall   |global_error|
        [ :LNOT: No32bitCode
        MSR     CPSR_f,#V_bit            ; global_error doesn't return -1,hence Ccall doesn't set V for us
        MOV     pc,lr
        |
        ORRS    pc,lr,#V_bit
        ]

        ; Called when a "Ccall" will fail due to insufficient stack.
DOS_not_enough_stack
        [ :LNOT: No32bitCode
        Pull    "lr"
        MSR     CPSR_cxsf,lr
        ] 
        Pull    "sl,fp,lr"     ; recover entry registers
        MOV     a1, #err_nostack ; There should be no stacked state at this point
        Ccall   |global_error| ; now,just for fun,we'll call Ccall again
        [ :LNOT: No32bitCode
        MSR     CPSR_f,#V_bit   ; global_error doesn't return -1,hence Ccall doesn't set V for us
        MOV     pc,lr
        |
        ORRS    pc,lr,#V_bit
        ]

        ; -------------------------------------------------------------------
        ; Provide a simple function to write a WORD to a non-aligned address
|writeWORD|
        ; in:   r0 = byte aligned address
        ;       r1 = 32bit value to be written
    [ NoARMv6 :LOR: NoUnaligned
        ANDS    r2,r0,#&03      ; r2 = byte index
        STREQ   r1,[r0,#&00]    ; word-aligned (perform write)
        Return  ,LinkNotStacked,EQ ; and exit quickly

        ; non-word aligned data
        FunctionEntry "r4,r5,r6"
      [ SupportARMv6
        BIC     r0,r0,#&03      ; r0 = base word index
      ]
        LDMIA   r0,{r4,r5}      ; load the two words our word lives in
        MOV     r2,r2,LSL #3    ; r2 = r2 * 8
        RSB     r3,r2,#32       ; r3 = 32 - r2
        MOV     r4,r4,LSL r3    ; clear the top-bits
        MOV     r6,r1,LSL r2    ; shift up the lo-bits
        ORR     r4,r6,r4,LSR r3 ; re-build the lo-word
        MOV     r5,r5,LSR r2    ; clear the lo-bits
        MOV     r6,r1,LSR r3    ; shift down the top-bits
        ORR     r5,r6,r5,LSL r2 ; re-build the hi-word
        STMIA   r0,{r4,r5}      ; store modified words
        Return  "r4,r5,r6"
    |
        STR     r1,[r0,#&00]    ; ARMv6+ can do unaligned writes
        Return  ,LinkNotStacked ; and exit quickly
    ]

        ; -------------------------------------------------------------------
        ; Provide a simple function to load a WORD from a non-aligned address
|loadWORD|
        ; in:   r0 = byte aligned address
    [ NoARMv6 :LOR: NoUnaligned
        ANDS    r2,r0,#&03      ; r2 = byte index
        LDREQ   r0,[r0,#&00]    ; word-aligned (perform read)
        Return  ,LinkNotStacked,EQ ; and exit quickly
        ; non-word aligned data
        FunctionEntry "r4"
      [ SupportARMv6
        BIC     r0,r0,#&03      ; r0 = base word index
      ]
        LDMIA   r0,{r3,r4}      ; load the two words our word lives in
        MOV     r2,r2,LSL #3    ; r2 = r2 * 8        ; shift amount
        RSB     r1,r2,#32       ; r1 = 32 - r2       ; opposite shift amount
        MOV     r0,r3,LSR r2    ; shift down lo-bits from lo-word
        ORR     r0,r0,r4,LSL r1 ; shift up hi-bits from hi-word
        Return  "r4"
    |
        LDR     r0,[r0,#&00]    ; ARMv6+ can do unaligned loads
        Return  ,LinkNotStacked ; and exit quickly
    ]

        ; -------------------------------------------------------------------
        ; A handful of RMA alloc bits
     [  RMAalloc
|_kernel_RMAalloc|
        MOVS    r3,a1
        Return  ,LinkNotStacked,EQ      ; exit quickly if NULL length
        MOV     ip,lr
        MOV     r0,#ModHandReason_Claim
        SWI     XOS_Module
        MOVVS   a1,#&0000000            ; return NULL if failed to alloc
        MOVVC   a1,r2                   ; otherwise base address
        Return  ,LinkNotStacked,,ip

        ; -------------------------------------------------------------------

|_kernel_RMAextend|
        CMP     a1,#&00000000
        MOVEQ   a1,a2                   ; NULL pointer, so act as realloc()
        BEQ     |_kernel_RMAalloc|      ; perform an allocation
        CMP     a2,#&00000000
        BEQ     |_kernel_RMAfree|       ; if size is zero, then perform free()
        MOV     ip,lr
        LDR     r3,[a1,#-4]             ; get length word preceding base
        SUB     r3,r3,a2                ; subtract new length (giving delta)
        MOV     r2,a1                   ; the current base address
        MOV     r0,#ModHandReason_ExtendBlock
        SWI     XOS_Module
        MOVVS   a1,#&0000000            ; NULL returned if extend failed
        MOVVC   a1,r2                   ; otherwise base address returned
        Return  ,LinkNotStacked,,ip

        ; -------------------------------------------------------------------

|_kernel_RMAfree|
        MOV     ip,lr
        MOVS    r2,a1                   ; base address of allocated memory
        MOVNE   r0,#ModHandReason_Free
        SWINE   XOS_Module              ; if not NULL then release memory
        MOV     a1,#&00000000           ; and the address is now NULL
        Return  ,LinkNotStacked,,ip
     ]

        LTORG

        END
