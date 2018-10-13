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
        SUBT    > Sources.FSCtrl2 - Filing System management routines

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Filing System info block format: What they pass to me
; ======================================================

;     0 +-----------+
;       |  nameptr  | Offset to Filing System name
;       +-----------+
;       | bannerptr | Offset to Filing System banner text, &80000000 -> FSFunc
;       +-----------+
;       |   open    | Offset of routine to open files
;       +-----------+
;       | getbuffer | Offset of routine to fill a file buffer from the FS
;       +-----------+
;       | putbuffer | Offset of routine to put a file buffer to the FS
;       +-----------+
;       |   args    | Offset of routine to control open files
;       +-----------+
;       |   close   | Offset of routine to close open files
;       +-----------+
;       |   file    | Offset of routine to do whole file operations
;       +-----------+
;       |   info    | Word of Filing System type information
;       +-----------+
;       |   func    | Offset of routine to do Filing System functions
;       +-----------+
;       |   gbpb    | Offset of routine to do unbuffered multiple byte transfer
;       +-----------+

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; fscb format
; ===========

;     0 +-------------+
;       |    link     | To next fscb, or Nowt
;       +-------------+
;       |  bannerptr  | Address of Filing System banner text, &80000000 -> FSFunc
;       +-------------+
;       |    open     | Address of routine to open files
;       +-------------+
;       |  getbuffer  | Address of routine to fill a file buffer from the FS
;       +-------------+
;       |  putbuffer  | Address of routine to put a file buffer to the FS
;       +-------------+
;       |    args     | Address of routine to control open files
;       +-------------+
;       |    close    | Address of routine to close open files
;       +-------------+
;       |    file     | Address of routine to do whole file operations
;       +-------------+
;       |    info     | Word of Filing System type information
;       +-------------+
;       |    func     | Address of routine to do Filing System functions
;       +-------------+
;       |    gbpb     | Address of routine to do unbuffered muliple byte transfer
;       +-------------+
;       |  modulebase | Address of Filing System module base
;       +-------------+
;       |   privword  | Address of module's private word
;       +-------------+
;       | modulebase2 | Address of Filing System secondary module base
;       +-------------+
;       |  privword2  | Address of module's secondary private word
;       +-------------+
;       |FirstImagescb| Link to list of MultiFS images on this filing system (non-MultiFS only)
;       +-------------+
;       |    opt 1    | OPT 1 status on this Filing System (Byte)
;       +-------------+
;       |             |
;       ~    name     ~ Filing System name
;       |             |
;       +-------------+

; info word
; =========

; bit31   = 1 -> Filing System supports special fields
;         = 0 -> Filing System does not support special fields

; bit30   = 1 -> Filing System streams are interactive, eg. kbd, vdu
;         = 0 -> Filing System streams are not interactive

; bit29   = 1 -> Filing System supports null length filenames, eg. kbd, vdu
;         = 0 -> Filing System needs non-null filenames

; bit28   = 1 -> Filing System should always be called to open file
;         = 0 -> Filing System must only be called to open file in/up if exist

; bit27   = 1 -> Tell filing system when flushing by calling fsargs_Flush
; bit27   = 0 -> Don't tell filing system when flushing

; bit26   = 1 -> fsfile_ReadInfoNoLength supported
; bit26   = 0 -> fsfile_ReadInfoNoLength not supported

; bit25   = 1 -> fsfunc_FileInfo supported
; bit25   = 0 -> fsfunc_FileInfo not supported

; bit24   = 1 -> fsfunc_SetContexts supported
; bit24   = 0 -> fsfunc_SetContexts not supported

; bit23   = 1 -> All extensions for MultiFS support are supported.
;                 These are (when I wrote this comment):
;                       fsfunc_CanonicaliseSpecialAndDisc
;                       fsfunc_ResolveWildcard
; bit23   = 0 -> They aren't

; bit16   = 1 -> This filing system is read only
;         = 0 -> It isn't - it's read/write instead.

; bits15-8: Minimum number of files openable on filing system (0 means unlimited
;               by the filing system).

; bits7-0: BBC type Filing System identifier

;       0  No Filing System             1  1200 Baud cassette   (NS)
;       2  300 Baud cassette    (NS)    3  ROM Filing System    (NS)
;       4  Acorn DFS            (NS)    5  net:
;       6  Teletext/Telesoft    (NS)    7  IEEE Filing System   (NS)
;       8  adfs:                        9  Unknown - but reserved
;       10 Acorn VFS            (NS)    11 Acorn WDFS           (NS)
;       12 netprint:                    13 null:
;       14 vdu:                         15 bbc:
;       16 Acacia RAM Filing System (?) 17 bbcb:
;       18 rawvdu:                      19 Kbd:
;       20 RawKbd:                      21 DeskFS:
;       22 rfs: (CC)                    23 RAM:
;       24 RISCiXFS:                    25 DigiTape: (DS)
;       26 SCSI:                        27 TVFS: (Watford)
;       28 ScanFS: (Watford)            29 MultiFS:
;       30 fax: (CC)                    31 Z88: (Colton)
;       32 SCSIDeskFS: (JBS)            33 NFS:
;       34 Serial2: (The Soft Option)   35 DFSDeskFS: (PRES)
;       36 DayIBMFS: (Daylight)         37 CDFS: (Next Technology)
;       38 lfs: (CC)                    39 pcfs: (CC)
;       40 BBScanFS: (Beebug)           41 BroadLoader:
;       42 chunkfs: (CC)                43 MSDOS:
;       44 NoRiscFS: (Minerva)          45 Nexus: (SJ)
;       46 Resources:                   47 Pipe:
;       48 NexusFilerFS: (SJ)           49 IDEFS: (Sefan Fr�hling)
;       50 PrintFS: (CC)

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Offsets in a filing system control block

          ^     0
fscb_link       #       4
fscb_startuptext #      4       ; Ptr to text to be printed on Filing System startup
fscb_open       #       4       ; --|
fscb_get        #       4       ;   |
fscb_put        #       4       ;   } Addresses in same order and offset as FS_xxx
fscb_args       #       4       ;   |
fscb_close      #       4       ;   |
fscb_file       #       4       ; --/
fscb_info       #       4
fscb_func       #       4       ; --|
fscb_gbpb       #       4       ; --/

fscb_modulebase  #      4       ; Ptr to module base (for * decoding primarily)
fscb_privwordptr #      4       ; Ptr to module private word (or whatever Bruce says)

fscb_modulebase2  #     4       ; Ptr to secondary module base
fscb_privwordptr2 #     4       ; Ptr to secondary module private word

; MultiFS specific fields
fscb_FirstImagescb #    0       ; Ptr to first scb in list of MultiFS image scbs on this filing system
                                ;   This field is only present on non-MultiFS filing systems. The equivalent
                                ;   on MultiFS filing systems is in the scb of a MultiFS image file
fscb_FileType   #       4       ; FileType for MultiFS filing system

fscb_extra      #       4       ; extra info
fscb_opt1       #       1       ; Current OPT 1 value for Filing System (0 to start)
fscb_name       #       1       ; Dynamic sizing of name field, but 1 for 0 terminator

fscb_size *     :INDEX: @

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Notes on numbers and names:

;       Numbers may only be used to select or lookup filing systems
;       Names MUST be used for Add, AddSecondary and Remove ops

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; AddFSEntry. Top level FSControl entry
; ==========
;
; Add a Filing System from a loaded module to those that FileSwitch knows about
; Can be used to update the given fscb too (if it already exists)

; In    r1 -> Filing System module base
;       r2 = Offset of Filing System info block in module
;       r3 = Module private word^ for Filing System to be entered with
;          (conventionally st. LDR wp,[r12] will be executed on all fs entries)

; Out   VC: Added to Filing System chain / Updated fscb
;       VS: fail


AddFSEntry NewSwiEntry "r0-r8, fscb"

        MOV     r5, r1                  ; r5 -> Module base
        ADD     r6, r1, r2              ; r6 -> Filing System info block
        MOV     r7, r3                  ; r7 -> Module workspace

        LDR     r1, [r6, #FS_name]      ; Module offset to Filing System name
        TEQ     r1, #0                  ; Is it duff ?
        MOVEQ   r1, r14
        ADDNE   r1, r1, r5              ; Add in module base
 [ :LNOT: No26bitCode
        TST     r1, #&FC000000          ; Real ARM address (byte aligned) ?
        MOVNE   r1, r14
 ]
        MOV     r4, r1                  ; Save name^ for copying later
 [ debugcontrol
 LDRB r14,[r6,#FS_info]
 DREG r14,"Adding Filing System number ",cc,Byte
 DSTRING r1," "
 DREG r5, "Module base      "
 DREG r7, "Module workspace "
 DREG r6, "FS info block    "
 ]
        MOV     r0, #1                  ; <> 0 -> only CtrlChar terminators
        BL      LookupFSName            ; Does FS (r1 -> name) already exist ?
        BVS     %FA99 ; SwiExit         ; And as an aside, is it actually valid

        TEQ     fscb, #Nowt             ; fscb^ ~= Nowt if found
        MOVNE   r2, fscb                ; Update existing FS block if found
        BNE     %FT30

        BL      strlen                  ; How long am the name ?
        ADD     r3, r3, #fscb_size      ; Get space for the fscb + name
        BL      SMustGetArea            ; 0 allowed for already in fscb_size
        BVS     %FA99 ; SwiExit

30 ; r2 now points to a block we can fill with the Filing System entry points

        STR     r5, [r2, #fscb_modulebase]  ; Must store module base
                                            ; For Filing System *cmd decoder
        STR     r7, [r2, #fscb_privwordptr] ; Store Filing System word^

        MOV     r14, #0                 ; These not present yet
        STR     r14, [r2, #fscb_modulebase2]
        STR     r14, [r2, #fscb_privwordptr2]

; Maybe load OPT 1 default from CMOS ?

        MOV     r14, #0                 ; Starting OPT 1 setting is 0
        STRB    r14, [r2, #fscb_opt1]

; Slapped wrists for people who give me a naff banner string too

        LDR     r0, [r6, #FS_startuptext]
        CMP     r0, #-1                 ; -> call FSFunc to print it
        BEQ     %FT13
        TEQ     r0, #0
        ADDNE   r0, r0, r5              ; If not zero, add in module base
 [ :LNOT: No26bitCode
        TSTNE   r0, #&FC000000          ; Real ARM address (byte aligned )?
        MOVNE   r0, #0
 ]
13      STR     r0, [r2, #fscb_startuptext]

; FS_open to FS_gbpb are module offsets to add to module base in the new fscb
; Calculate addresses that FileSwitch will be calling in this Filing System
; Those that are invalid (ie offset of 0 or final address invalid) are given
; the 'naffup' default so that LowLevel isn't blown away

        addr    r7, Lowlevel_UnsupportedFSEntry
        ADD     r8, r7, #(Lowlevel_UnalignedFSEntry-Lowlevel_UnsupportedFSEntry)

        ASSERT  FS_open = fscb_open ; Must be in the same order at the same offset !

        MOV     r1, #FS_open            ; First entry to copy
15      LDR     r0, [r6, r1]            ; Src = entry point offset
        TEQ     r0, #0                  ; No entry point for this routine ?
        MOVEQ   r0, r7                  ; Give default 'dunno' entry if so
        ADDNE   r0, r0, r5
        TST     r0, #3                  ; Formed a real ARM address ?
                                        ; This MUST be word aligned (code)
        MOVNE   r0, r8                  ; Give default 'hate' entry if not
        STR     r0, [r2, r1]            ; Dest = real address in module
        CMP     r1, #FS_gbpb            ; Last entry to copy
        ADDNE   r1, r1, #4
        BNE     %BT15

        LDR     r0, [r6, #FS_info]      ; Copy FS information word
        STR     r0, [r2, #fscb_info]    ; Don't put before table copy !
        TST     r0, #fsinfo_extrainfo
        LDRNE   r0, [r6, #FS_extra]
        MOVEQ   r0, #0
        STR     r0, [r2, #fscb_extra]

        ADD     r3, r2, #fscb_name      ; r3 := r2+fscb_name -> space for name
20      LDRB    r0, [r4], #1            ; Copy FS name into fscb
        CMP     r0, #space              ; CtrlChar or space terminates
        MOVLS   r0, #0                  ; 0 terminator when stored in fscb
        STRB    r0, [r3], #1
        BHI     %BT20

        ; Zero the MultiFS file list
        MOV     r0, #Nowt
        STR     r0, [r2, #fscb_FirstImagescb]

        TEQ     fscb, #Nowt             ; New block to link to head of chain ?
        LDREQ   r14, fschain
        STREQ   r14, [r2, #fscb_link]
        STREQ   r2, fschain             ; Splat ! It's now on the chain

99
        SwiExit

98
        ; Error exit when new fscb claimed, but one of the directories failed to be replaced
        Push    r0                                      ; Save original error

        ; Free the unwanted fscb
        BL      SFreeArea

        SETV
        Pull    r0                                      ; Original error

        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; AddSecondaryFSEntry. Top level FSControl entry
; ===================
;
; Add secondary module base and wsptr to existing Filing System entry

; In    r1 -> Filing System name
;       r2 = Secondary module base
;       r3 = Secondary module wsptr

; Out   VC: added
;       VS: UK FS error or Bad FS name

AddSecondaryFSEntry NewSwiEntry "r0, r1, r3, fscb"

 [ debugcontrol
 DSTRING r1, "Adding secondary FS for "
 DREG r2, "Module base 2      "
 DREG r3, "Module workspace 2 "
 ]
        MOV     r0, #1                  ; <> 0 -> only CtrlChar terminators
        BL      LookupFSName
        BVS     %FA50 ; SwiExit

        CMP     fscb, #Nowt             ; fscb^ ~= Nowt if found. VClear
        addr    r0, MagicErrorBlock_FSDoesntExist, EQ
        BLEQ    MagicCopyErrorSpan      ; needs r0,r1,r3

                                        ; Update existing FS block if found
        STRVC   r2, [fscb, #fscb_modulebase2]
        LDRVC   r3, [fp, #4*2]
        STRVC   r3, [fscb, #fscb_privwordptr2]

50
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; AddImageFSEntry. Top level FSControl entry
; ===============
;
; Add a Filing System from a loaded module to those that FileSwitch knows about
; Can be used to update the given fscb too (if it already exists)

; In    r1 -> Filing System module base
;       r2 = Offset of Filing System info block in module
;       r3 = Module private word^ for Filing System to be entered with
;          (conventionally st. LDR wp,[r12] will be executed on all fs entries)

; Out   VC: Added to Filing System chain / Updated fscb
;       VS: fail

AddImageFSEntry NewSwiEntry "r0-r8, fscb"

        MOV     r5, r1                          ; r5 -> Module base
        ADD     r6, r1, r2                      ; r6 -> Filing System info block
        MOV     r7, r3                          ; r7 -> Module workspace

 [ debugcontrol
 LDRB r14,[r6,#IFS_filetype]
 DREG r14,"Adding Image Filing System type ",cc
 DREG r5, "Module base      "
 DREG r7, "Module workspace "
 DREG r6, "FS info block    "
 ]
        LDR     r1, [r6, #IFS_filetype]
        BL      LookupIFSType                   ; Does IFS (r1=filetype) already exist ?

        TEQ     fscb, #Nowt                     ; fscb^ ~= Nowt if found
        MOVNE   r2, fscb                        ; Update existing FS block if found
        BNE     %FT30

        ; Get space for the fscb
        MOV     r3, #fscb_size
        BL      SMustGetArea
        BVS     %FA99 ; SwiExit

30 ; r2 now points to a block we can fill with the Filing System entry points

        STR     r5, [r2, #fscb_modulebase]      ; Must store module base
                                                ; For Filing System *cmd decoder
        STR     r7, [r2, #fscb_privwordptr]     ; Store Filing System word^

        MOV     r14, #0                         ; These not present yet (or ever for IFSs)
        STR     r14, [r2, #fscb_modulebase2]
        STR     r14, [r2, #fscb_privwordptr2]

        ; Starting OPT 1 setting is 0
        MOV     r14, #0
        STRB    r14, [r2, #fscb_opt1]

        ; 0 => Lookup default banner string, just in case
        STR     r14, [r2, #fscb_startuptext]

; FS_open to FS_gbpb are module offsets to add to module base in the new fscb
; Calculate addresses that FileSwitch will be calling in this Filing System
; Those that are invalid (ie offset of 0 or final address invalid) are given
; the 'naffup' default so that LowLevel isn't blown away

        addr    r7, Lowlevel_UnsupportedFSEntry
        ADD     r8, r7, #(Lowlevel_UnalignedFSEntry-Lowlevel_UnsupportedFSEntry)

        ASSERT  IFS_open = fscb_open ; Must be in the same order at the same offset !

        MOV     r1, #IFS_open           ; First entry to copy
15      LDR     r0, [r6, r1]            ; Src = entry point offset
        TEQ     r0, #0                  ; No entry point for this routine ?
        MOVEQ   r0, r7                  ; Give default 'dunno' entry if so
        ADDNE   r0, r0, r5
        TST     r0, #3                  ; Formed a real ARM address ?
                                        ; This MUST be word aligned (code)
        MOVNE   r0, r8                  ; Give default 'hate' entry if not
        TEQ     r1, #IFS_func           ; fsinfo at start of IFS block
        STRNE   r0, [r2, r1]            ; Dest = real address in module
        STREQ   r0, [r2, #fscb_func]
        CMP     r1, #IFS_func           ; Last entry to copy
        ADDNE   r1, r1, #4
        BNE     %BT15
        STR     r8, [r2, #fscb_gbpb]    ; Tidy up gbpb to the hate entry as shouldn't ever get called

        ; Copy FS information word with bad bits masked off
        LDR     r0, [r6, #IFS_info]
        BIC     r0, r0, #fsinfo_notforMultiFS
        STR     r0, [r2, #fscb_info]

        ; Zero out the extras - they're not for MultiFSs
        MOV     r0, #0
        STR     r0, [r2, #fscb_extra]

        ; Copy FileType
        LDR     r0, [r6, #IFS_filetype]
 [ debugcontrol
 DREG   r0, "Copying filetype across:"
 ]
        STR     r0, [r2, #fscb_FileType]

        TEQ     fscb, #Nowt             ; New block to link to head of chain ?
        LDREQ   r14, fschain
        STREQ   r14, [r2, #fscb_link]
        STREQ   r2, fschain             ; Splat ! It's now on the chain

99
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LookupFSEntry. Top level FSControl entry
; =============
;
; Search Filing System chain for matching Filing System name/number

; In    r1 > 255 -> Filing System name, term (see r2)
;          < 256  = Filing System number
;       r2  <> 0 -> only CtrlChar terms allowed
;            = 0 -> CtrlChar and '#',':','-' terms allowed

; Out   VC      r1 = filing system number
;               r2 = valid fscb^ corresponding to name
;                    0 if not found
;       VS      Bad Filing System name error set if bad term or duff chars

LookupFSEntry NewSwiEntry "r0,r3,fscb"

        BICS    r14, r1, #&FF           ; Valid address ?
        BNE     %FT10
        BL      LookupFSNumber
        B       %FT20

10      MOV     r0, r2                  ; <> 0 only allow CtrlChar terminators
        BL      LookupFSName            ; 0 allows '#',':','-' extra terms

20      BVS     %FA30 ; SwiExit
        TEQ     fscb, #Nowt             ; NB. Leave V unperturbed
        MOVEQ   fscb, #0                ; Wot the punter expects, 'spose
        LDRNEB  r1, [fscb, #fscb_info]  ; Return filing system number
        MOV     r2, fscb                ; and fscb^. Yuk!

30
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LookupFSNumber
; ==============
;
; Search Filing System chain for matching Filing System number

; In    r1 = Filing System number

; Out   fscb^ valid or Nowt if not found. VClear always

LookupFSNumber Entry

        LDR     fscb, fschain           ; Point to first fscb

10      CMP     fscb, #Nowt             ; End of fs chain ?
        LDRNEB  r14, [fscb, #fscb_info]
        CMPNE   r1, r14                 ; If matched, fscb valid
        EXIT    EQ                      ; VClear

        LDR     fscb, [fscb, #fscb_link] ; Try next fscb then
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LookupFSName
; ============
;
; Search Filing System chain for matching Filing System name

; Allows '#', '-', ':' terminators for internal porpoises
; Externals may have to check terms and present stripped

; In    r0 = 0 to allow :, # or - to terminate FSName cleanly
;          <>0 to disallow them
;       r1 -> Filing System name

; Out   if found: r1 -> terminating char, fscb^ valid
;                 r3 = span
;       if not  : r1 unchanged, fscb = Nowt
;                 r3 = span
;
LookupFSName Entry "r4"
        MOV     r4, r0
        BL      PoliceFSNameWithError
        BLVC    FindFSName
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FindFSName
;
; In    r1 -> FSName
;       r4 = 0 to allow :, # and - as name terminators as well as ctrl chars
;
; Out   Found:
;               r1 -> terminating char in FSName
;               fscb = pointer to fscb
;       Not found:
;               r1 unchanged
;               fscb = Nowt
;
FindFSName Entry "r0,r2,r3,r5"
        LDR     fscb, fschain

10      TEQ     fscb, #Nowt
        EXIT    EQ

        ; Don't even try to match against image filing systems
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        BEQ     %FT35

        MOV     r2, r1                  ; r2 -> Filing System name to test
        ADD     r5, fscb, #fscb_name    ; r5 -> fscb name field

15      LDRB    r3, [r5], #1            ; Char from fscb
        LDRB    r0, [r2], #1
        CMP     r3, #space-1            ; Ended fscb name ?
        TEQHI   r3, #delete
        MOVLSS  r3, #0
        BNE     %FA20
        BL      IsFSNameTerm            ; Ended supplied name ?
        SUBEQ   r1, r2, #1              ; r1 -> term char
        EXIT    EQ

20
        Internat_CaseConvertLoad r14,Lower
        TEQ     r14, #Nowt
        BEQ     %FT25                   ; No territory loaded, no case
                                        ; conversion table. Use ASCII.
        Internat_LowerCase r0, r14
        Internat_LowerCase r3, r14
        B       %FT30
25
        ASCII_LowerCase r0, r14
        ASCII_LowerCase r3, r14
30
        TEQ     r0, r3                  ; Loop if still matching
        BEQ     %BT15

35
        LDR     fscb, [fscb, #fscb_link] ; Try next fscb then
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LookupIFSType
;
; In    r1 = IFS file type
;
; Out   fscb = Nowt or fscb^ for image FS
;
LookupIFSType Entry
        LDR     fscb, fschain

10      TEQ     fscb, #Nowt
        EXIT    EQ

        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        LDREQ   r14, [fscb, #fscb_FileType]
        TEQEQ   r14, r1
        EXIT    EQ

        LDR     fscb, [fscb, #fscb_link]
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; IsFSNameTerm
;
; In    r0 = char to test
;       r4 = 0 to accept :, - and # as well as ctrl chars
;
; Out
;       NE (and in versions < 1.70: VS and BadFSName error set) if not
;       EQ (and in versions < 1.70: VC) is is

IsFSNameTerm

 [ No26bitCode
        ASSERT  space = &20             ; also assume r0 < 256
        TST     r0, #&E0
        MOVEQ   pc, lr                  ; sneaky, huh?
 |
        CMP     r0, #space              ; CtrlChar is always term
        ORRLOS  pc, lr, #Z_bit          ; EQ
 ]

        TEQ     r0, #":"                ; For fsname:
        TEQNE   r0, #"-"                ; For -fsname-
        TEQNE   r0, #"#"                ; For -fsname#special-
                                        ;  or fsname#special:

        TEQEQ   r4, #0                  ; Only allow EQ if r4 is right value
        MOV     pc, lr


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PoliceFSNameWithError
;
; In    r4 = 0 to accept :, - and # as valid terminators as well as ctrl/chars
;       r1 -> FSName
;
; Out   r1 -> terminating char
;       r3 = length of name to (but excluding) terminating char
;
PoliceFSNameWithError Entry "r0"
        MOV     r3, #0

01      LDRB    r0, [r1, r3]            ; Is it terminated correctly ?
        BL      IsAlphanumeric          ; Good char ?
        ADDCS   r3, r3, #1
        BCS     %BT01                   ; Loop if so

        ; Check name isn't zero length
        TEQ     r3, #0
        BEQ     %FA90

        ; Check terminator is valid
        BL      IsFSNameTerm
        EXIT    EQ

90      addr    r0, ErrorBlock_BadFilingSystemName
        BL      CopyError
        EXIT


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SelectFSEntry. Top level FSControl entry
; =============
;
; Find a Filing System by name / number and select it as current

; In    r1  > 255 -> Filing System name terminated by '#', '-' or CtrlChar
;          <= 255: Filing System number
;           =   0: Go into no selected Filing System state

; Out   VC: Selected by name or number, or failed to select by number
;       VS: Failed to select by name only

SelectFSEntry NewSwiEntry "r0, r1, r2, r3, fscb"

        BICS    r14, r1, #&FF           ; Valid address ?
        BNE     %FT50

        TEQ     r1, #0                  ; No sel fs ?
        MOVEQ   fscb, #Nowt
        BEQ     %FT10

        BL      LookupFSNumber
        TEQ     fscb, #Nowt             ; Found it ?
        BEQ     %FA20 ; SwiExit         ; No error if selecting by number

10
        MOV     r2, fscb
        BL      SetCurrentFS
        BLVC    SetTempFS
20
        SwiExit


50      MOV     r0, #0                  ; 0 -> any old junk terminators
        BL      LookupFSName
        BVS     %BA20 ; SwiExit

        TEQ     fscb, #Nowt             ; Found it ?
        BNE     %BT10

        addr    r0, MagicErrorBlock_FSDoesntExist ; Error if selecting by name
        BL      MagicCopyErrorSpan      ; needs r0,r1,r3
        B       %BA20 ; SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PrintFilingSystemText
; =====================
;
; Output the startup text string associated with the current Filing System

; NB. AddFS has already defaulted null or bad entries to a sensible string

; In   fscb^ valid or Nowt

UntitledFSToken DCB     "UntFS",0
                ALIGN

PrintFilingSystemText Entry "r0-r5, r6, fscb" ; FSFunc only preserves r6 up

 [ debugcontrol
 DLINE "FS startup banner: ",cc
 ]
        CMP     fscb, #Nowt             ; No msg if no sel fs
        EXIT    EQ                      ; VClear

        LDR     r0, [fscb, #fscb_startuptext]
        CMP     r0, #-1
        BEQ     %FT90
        CMP     r0, #0
        BNE     %FT40

        ADR     r0, UntitledFSToken     ; Look up untitled FS start up text.
        BL      message_lookup
        ADDVS   r0, r0, #4              ; Print error if look up failed.
40
        SWI     XOS_Write0              ; Print the string.
        SWIVC   XOS_NewLine
50      SWIVC   XOS_NewLine
        BLVS    CopyErrorExternal
        EXIT

90      MOV     r0, #fsfunc_PrintBanner
        MOV     r6, #0                  ; Use current context
        BL      CallFSFunc_Given        ; Use fscb^
        EXIT    VS
        B       %BT50                   ; Print another newline

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; BootupFSEntry. Top level FSControl entry
; =============
;
; Ask current Filing System to perform autoboot action, eg. '%LOGON Boot'

; Out   VC: Booted ok (or no sel fs)
;       VS: fail

BootupFSEntry NewSwiEntry "r0-r5, r6, fscb" ; FSFunc only preserves r6 up

        BL      ReadCurrentFS
        SwiExit VS
        MOV     fscb, r0
        CMP     fscb, #Nowt             ; VClear
 [ debugcontrol
 BEQ %FT01
 Push r1
 ADD r1, fscb, #fscb_name ; r1 -> fscb name field
 DSTRING r1,"Booting on "
 Pull r1
01
 ]
        MOVNE   r0, #fsfunc_Bootup
        MOVNE   r6, #0                  ; Use current context
        BLNE    CallFSFunc_Given        ; Use fscb^
        SwiExit                         ; Not an error if no current FS

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RemoveFSEntry. Top level FSControl entry
; =============
;
; Remove a Filing System from from Filing System chain by name only

; Mustn't call FS eg. to close files; it may not be reentrant (Nick wants this)

; In    r1 > 255 -> Filing System name, CtrlChar
;          < 256 = Filing System number - which will fail; stops accidental rem

; Out   VC: Removed, all registers preserved
;       VS: fail

RemoveFSEntry NewSwiEntry "r0, r1, r3, fscb"

        BICS    r14, r1, #&FF           ; Valid address ?
        addr    r0, ErrorBlock_CantRemoveFSByNumber, EQ
        BLEQ    CopyError
        BVS     %FT70

        MOV     r0, #0                  ; 0 -> any old junk terminators
        BL      LookupFSName
        BVS     %FA70 ; SwiExit

        TEQ     fscb, #Nowt             ; Error if named FS not found
        addr    r0, MagicErrorBlock_FSDoesntExist, EQ
        BLEQ    MagicCopyErrorSpan      ; needs r0,r1,r3

        BLVC    RemoveFS                ; Of given fscb

70
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RemoveImageFSEntry. Top level FSControl entry
; ==================
;
; Remove an Image Filing System from from Filing System chain by file type

; In    r1 = file type of IFS to remove

; Out   VC: Removed, all registers preserved
;       VS: fail

RemoveImageFSEntry NewSwiEntry "r0, r1, r3, fscb"

        BL      LookupIFSType

 [ debugcontrol
        DREG    fscb, "Removing image filing system at "
 ]

        TEQ     fscb, #Nowt             ; Error if named FS not found
        addr    r0, ErrorBlock_UnknownFilingSystem, EQ
        BLEQ    CopyError

        BLVC    RemoveFS                ; Of given fscb

70
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RemoveFS
; ========
;
; Remove a Filing System from Filing System chain, and return space

; In    fscb^

; Out   VC: Removed or not found
;       VS: failed to free block

RemoveFS Entry "r0, r2"

 [ debugcontrol
 Push r1
 ADD r1, fscb, #fscb_name
 DSTRING r1,"Removing Filing System "
 Pull r1
 ]
        ; Close all open files on this filing system
        BL      CloseAllFilesOnThisFS

        ADR     r0, (fschain-fscb_link) ; Find your fscb first

; r0 -> fscb before the one to try

10      LDR     r14, [r0, #fscb_link]
        CMP     r14, #Nowt              ; End of chain ?
        EXIT    EQ
        CMP     r14, fscb
        MOVNE   r0, r14
        BNE     %BT10

        LDR     r14, [fscb, #fscb_link] ; Put our link back in his
        STR     r14, [r0,   #fscb_link]

        MOV     r2, fscb                ; Free the space
        BL      SFreeArea
        EXIT                            ; V from freeing block

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadFSNameEntry. Top level FSControl entry
; ===============
;
; Decode the given fs number into a filename

; In    r1 = fs number
;       r2 -> core
;       r3 = size of core

; Out   name in core (zero terminated), else Buffer overflow

ReadFSNameEntry NewSwiEntry "r1-r3, fscb"

 [ debugcontrol
 DREG r1, "Read FSName for fs number "
 ]
        BL      LookupFSNumber
        TEQ     fscb, #Nowt             ; Found it ?
        ADDNE   r1, fscb, #fscb_name
        addr    r1, anull, EQ
 [ debugcontrol
 DSTRING r1, "Found filing system "
 ]

10      SUBS    r3, r3, #1
        addr    r0, ErrorBlock_BuffOverflow, MI ; [buffer too small]
        BLMI    CopyError
        BVS     %FT90

        LDRB    r14, [r1], #1
        STRB    r14, [r2], #1
        CMP     r14, #0
        BNE     %BT10

90
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; FileTypeFromStringEntry. Top level FSControl entry
; =======================
;
; Decode the given string into a filetype

; In    r1 -> string (ctrl char terminated, trailing spaces skipped)

; Out   r2 = file type (bottom 12 bits)

             ^  0, sp
fts_result   #  256                     ; Can't read a variable into ScrSpace
                                        ; as it might be a macro variable
fts_size     *  :INDEX: @

ftslocalframesize * localframesize + fts_size


WildFileType
        DCB     "File$$Type_"
FileTypePrefixOff * .-WildFileType
        DCB     "*"                     ; Shared zero with ...
fsw_Null ; Can't be local, unfortunately
        DCB     0
        ALIGN


FileTypeFromStringEntry NewSwiEntry "r0-r1, r3-r7",fts ; extra local frame

        BL      FS_SkipSpaces
        MOV     r7, r1                  ; keep for later
        BCC     %FT40                   ; Fault with 'Bad number'


        BL      strlen                  ; Strip trailing spaces orf
        ADD     r5, r1, r3              ; r5 -> end of string (non-null)
05      LDRB    r14, [r5, #-1]!
        CMP     r14, #space
        BEQ     %BT05
        ADD     r5, r5, #1              ; r5 -> end of string (space or CtrlCh)
        SUB     r5, r5, r1              ; r5 = length of bit to compare
 [ debugcontrol
 DREG r5, "length of source string "
 ]

        addr    r6, fsw_Null            ; Null string (shared)-> read first vbl

10 ; Loop over variables (quicker than doing all 4096, he claims)

        addr    r0, WildFileType        ; Template to match
        ADR     r1, fts_result          ; Lookup that variable please
        MOV     r2, #?fts_result        ; Read into stack frame
        MOV     r3, r6                  ; last matched variable
        MOV     r4, #VarType_Expanded
        SWI     XOS_ReadVarVal          ; r3 -> next one to try
        BVS     %FT40                   ; try number instead (ended)
        MOV     r6, r3                  ; remember variable
        CMP     r2, #0
        BEQ     %BT10
 [ debugcontrol
 MOV r14, #0
 STRB r14, [r1, r2]
 DSTRING r1, "read variable "
 ]


        ADD     r3, r1, r2              ; r3 -> end of string (non-null),unterm
15      LDRB    r14, [r3, #-1]!
        CMP     r14, #space
        BEQ     %BT15
        ADD     r3, r3, #1              ; r3 -> end of string (space or unterm)
        SUB     r3, r3, r1              ; r3 = length of bit to compare
 [ debugcontrol
 DREG r3, "length of comparison string "
 ]

        CMP     r3, r5                  ; Same lengths ?
        BNE     %BT10

        MOV     r2, r7                  ; Same as our string (r1in sp-skipped)?
        BL      strncmp                 ; strings unterminated, so use count
 [ debugcontrol
 BEQ %FT9900
 DLINE " NE"
 B %FT9901
9900
 DLINE " EQ"
9901
 ]
        BNE     %BT10                   ; [nope, loop]

        LDR     r0, =(2_101 :SHL: 29) + 16 ; Default base 16, no bad terms
        ADD     r1, r6, #FileTypePrefixOff ; Skip prefix, read number
        LDR     r2, =&FFF               ; Restrict range 000..FFF
        SWI     XOS_ReadUnsigned
        BVS     %BT10                   ; loop if number no good

        B       %FA90 ; SwiExit

        LTORG


; Try number then

40      LDR     r0, =(2_101 :SHL: 29) + 16 ; Default base 16, no bad terms
        MOV     r1, r7
        LDR     r2, =&FFF               ; Restrict range 000..FFF
 [ debugcontrol
 DSTRING r1, "Try reading as number "
 ]
        SWI     XOS_ReadUnsigned        ; Read type
 [ debugcontrol
 BVS %FT00
 DREG r2, "file type "
00
 ]
        addr    r0, ErrorBlock_BadFileType, VS ; Make new error
        BLVS    CopyError

90
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadFileTypeEntry. Top level FSControl entry
; =================
;
; Decode the given filetype into a 4 char sequence

; In    r2 = file type (bottom 12 bits)

; Out   r2, r3 = text form as chars in registers

ReadFileTypeEntry NewSwiEntry

        BL      DecodeFileType
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Decode the given filetype into a 4 char sequence

; In    r2 = file type (bottom 12 bits)

; Out   r2, r3 = text form as chars in registers

             ^  0, sp
dft_varname  #  32                      ; Variable name is small ~13 currently
dft_result   #  256                     ; Can't read a variable into ScrSpace
                                        ; as it might be a macro variable
dft_size     *  :INDEX: @

DecodeFileType Entry "r0-r2, r4" ; Result r2 poked into stack

        SUB     sp, sp, #dft_size       ; Room for the variable string + result

 [ debugcontrol
 DREG r2,"File type is &",,Word
 ]
        MOV     r2, r2, LSL #(32-12)    ; Mask out any junk
        MOV     r2, r2, LSR #(32-12)
        STR     r2, [sp, #dft_size + 4*2] ; Note clean value

        ADR     r3, dft_varname
        ADR     r4, dft_VariablePrefix
05      LDRB    r14, [r4], #1           ; Copy variable name in
        TEQ     r14, #0
        STRNEB  r14, [r3], #1           ; No terminator; leave r3 -> next byte
        BNE     %BT05

        BL      ConvertHex3

        ADR     r0, dft_varname         ; Point at string again
        ADR     r1, dft_result          ; Lookup that variable please
        MOV     r2, #?dft_result        ; Read into stack frame
        addr    r3, anull
        BL      SReadVariable           ; VS -> exists, buffer overflow. Tough
        BVS     %FT99                   ; Get out
        BEQ     %FT50                   ; [null expansion -> Unknown file type]

        MOV     r0, #8
        MOV     r2, #&FF
30      LDRB    r14, [r1], #1
        TST     r14, r2                 ; If we've had zero, then pretend zero
        MOVEQ   r2, #0                  ; all the time, so we pad with spaces
        MOVEQ   r14, #space
        STREQB  r14, [r1, #-1]
        SUBS    r0, r0, #1
        BNE     %BT30

 [ debugcontrol
 Push "r1, lr"
 MOV r14, #0
 STRB r14, dft_result+8+(4*2) ; Correct for having stacked r1, lr
 ADR r1, dft_result+(4*2)
 DSTRING r1, "File type "
 Pull "r1, lr"
 ]
        ADR     r14, dft_result
        LDMIA   r14, {r2, r3}
        B       %FT98


50      LDR     r2, [sp, #dft_size + 4*2]
        MOV     r1, #Service_LookupFileType
        SWI     XOS_ServiceCall         ; Anybody want to claim it ?
        CMP     r1, #Service_Serviced
        BEQ     %FT98

        MOV     r14, #"&"               ; Build '&xyz' in r2
        STRB    r14, dft_result
        ADR     r3, dft_result+1
        BL      ConvertHex3
        LDR     r2, dft_result
        LDR     r3, FourSpaces          ; '    ' in r3

98      STR     r2, [sp, #dft_size + 4*2]

99      ADD     sp, sp, #dft_size
        EXIT


dft_VariablePrefix
        DCB     "File$$Type_"           ; Shared zero with ...
66
        DCB     0
        ALIGN

FourSpaces DCB  "    "                  ; Picked up as a word

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = 4 chars, LSB first

; Out   VC: ok
;       VS: error in r0, not copied

PrintR0Chars Entry

        SWI     XOS_WriteC
        MOVVC   r0, r0, ROR #8
        SWIVC   XOS_WriteC
        MOVVC   r0, r0, ROR #8
        SWIVC   XOS_WriteC
        MOVVC   r0, r0, ROR #8
        SWIVC   XOS_WriteC
        MOVVC   r0, r0, ROR #8          ; Back to the start
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; RestoreCurrEntry. Top level FSControl entry
; ================
;
; In    currentfs is valid fscb^ to reselect

RestoreCurrEntry NewSwiEntry "r0,r2"
        BL      ReadCurrentFS
        MOVVC   r2, r0
        BLVC    SetTempFS
 [ debugcontrol
        DLINE   "Exit RestreCurrEntry",cc
        BVC     %FT01
        DLINE   " with error",cc
01
        DLINE   ""
        LDR     r0, globalerror
        DREG    r0,"globalerror before exit is "
 ]
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadTempModEntry. Top level FSControl entry
; ================
;
; Tells us where the temporary (may be current) selected Filing System is

; Out   r1 = module base of Filing System, 0 if none selected
;       r2 = ptr to private word

ReadTempModEntry NewSwiEntry "r0"
        BL      ReadTempFS
        BVS     %FT90
        TEQ     r0, #Nowt
        MOVEQ   r1, #0
        LDRNE   r1, [r0, #fscb_modulebase]
        LDRNE   r2, [r0, #fscb_privwordptr]
90
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadSecModEntry. Top level FSControl entry
; ===============
;
; Tells us where the temporary (may be current) selected Filing System
; secondary module is

; Out   r1 = secondary module base, 0 if no fs selected
;       r2 = ptr to private word

ReadSecModEntry NewSwiEntry "r0"
        BL      ReadTempFS
        BVS     %FT10
        TEQ     r0, #Nowt
        MOVEQ   r1, #0
        LDRNE   r1, [r0, #fscb_modulebase2]
        LDRNE   r2, [r0, #fscb_privwordptr2]

10
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ReadFSHandle. Top level FSControl entry
; ============
;
; Convert the given FileSwitch handle into a 32 bit Filing System handle

; If handle invalid, a Filing System handle of 0 is returned (not valid too)

; In    r1 = FileSwitch handle

; Out   r1 = Filing System handle
;       r2 = Filing System information word

ReadFSHandle ROUT ; NB. No local frame, just dealing with global state

        SUB     r2, r1, #1              ; Only 1..MaxHandle valid
        CMP     r2, #MaxHandle
        ADRLO   r14, streamtable
        LDRLO   r2, [r14, r1, LSL #2]   ; Get scb^
        ADRHSL  r2, UnallocatedStream   ; No stream if invalid
        LDR     r14, [r2, #:INDEX: scb_status]
        TST     r14, #scb_unallocated   ; Valid stream ?
        MOVNE   r1, #0                  ; No FS handle then, is there ?
        MOVNE   r2, #0                  ; Zero information word if not
        LDREQ   r1, [r2, #:INDEX: scb_fshandle] ; Get scb^.fshandle
        LDREQ   r2, [r2, #:INDEX: scb_fscb]     ; Get scb^.fscb
        LDREQ   r2, [r2, #fscb_info]            ; Get fscb^.info
 [ No26bitCode
        CLRV
        Pull    pc                      ; Claim vector.
 |
        Pull    pc,,^                   ; Claim vector. Assumes VClear in lr
 ]

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ShutFilesEntry
; ==============
;
; Flush and close all files on all Filing Systems (*SHUT equivalent)

; In    no parms

; Out   VC: all files closed
;       VS: failed to close one or more files

ShutFilesEntry NewSwiEntry

        BL      CloseAllFilesEverywhere
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; ShutDownEntry
; =============
;
; Flush and close all files on all Filing Systems (*SHUT equivalent)
; then make them park. Ignore errors until they're all dead !

; In    no parms

; Out   VC: all files closed, everyone asleep
;       VS: failed to close one or more files, or sleep failed

ShutDownEntry NewSwiEntry "r0-r5, r6, fscb" ; FSFunc only preserves r6 up

        BL      CloseAllFilesEverywhere ; So all they have to do is park

        LDR     fscb, fschain           ; Point to first fscb

10      CMP     fscb, #Nowt             ; End of fs chain ?
        SwiExit EQ                      ; Errors picked up by exit check

 [ debugcontrol
 BEQ %FT01
 Push r1
 ADD r1, fscb, #fscb_name ; r1 -> fscb name field
 DSTRING r1, "Shutting down "
 Pull r1
01
 ]
        ; MultiFS filing systems don't understand shutting down as such
        LDRB    r14, [fscb, #fscb_info]
        TEQ     r14, #0
        LDREQ   fscb, [fscb, #fscb_link] ; Do next fs then
        BEQ     %BA10

        MOV     r0, #fsfunc_ShutDown
        MOV     r6, #0                  ; Use current context
        BL      CallFSFunc_Given        ; Use fscb^

        LDR     fscb, [fscb, #fscb_link] ; Do next fs then
        B       %BT10

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; LookForAGoodTerm
; ================

; In    r2 -> name to parse; must only have alphanumerics before the given term
;             or any chars accepted after possible special
;       r0 = term to match against; either ':' or '-'

; Out   EQ name ok; term found before end of name
;       NE term not found before end of name, or non-alphas before # char

LookForAGoodTerm Entry "r0, r2, r4"

        MOV     r4, r0                  ; IsAlphanumeric uses r0

10      LDRB    r0, [r2], #1
        CMP     r0, r4                  ; Finished match ?
        BEQ     %FT80
        CMP     r0, #"#"                ; Just look for term after specials
        BEQ     %FT20
        BL      IsAlphanumeric          ; Catches end of name too !
        BCS     %BT10
        EXIT                            ; CC -> NE

20      LDRB    r0, [r2], #1
        CMP     r0, #space+1            ; Need explicit end of name check
        EXIT    LO                      ; LO -> NE
        TEQ     r0, #","
        BNE     %FT30
        MOVS    r0, #1                  ; Set NE on encountering a ,
        EXIT
30
        CMP     r0, r4
        BNE     %BT20

80 ; Found term - did we have any characters before it though ?

        LDR     r14, [sp, #4]           ; r2in
        SUB     r14, r2, r14
        CMP     r14, #1+1               ; LO -> term found immediately (NE)
        CMPHS   r14, r14                ; EQ -> term found ok
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; SetFromNameEntry. Top level FSControl entry
; ================
;
; Allow setting of tempfs by Filing System name eg. for XOS_CLI

; In    r1 -> name; allow #:- terms + strip 'em

; Out   r1 -> part of name past the fsspec if there was one
;       r2 = -1: no fs specified, tempfs unmolested
;          >= 0: old Filing System to be reselected at end of OSCLI etc.
;       r3 = pointer to special
;       tempfs defaults to old tempfs and may be modified by the SetFSForOp

SetFromNameEntry NewSwiEntry "r0,r1,r4,r5,r6,fscb"
 [ debugcontrol
        DSTRING r1, "Command in is "
 ]

        ; Extract the FS prefix
        BL      FSPath_FindFSPrefix
        MOVVC   r5, r2
        MOVVC   r6, r3
        MOVVC   r0, #0          ; Don't give error if does not exist
        BLVC    FSPath_ExtractFS
        BVS     %FT90

        ; Was it present (and matched a FS)?
        TEQ     r2, #0
        MOVEQ   r2, #-1
        BEQ     %FT90

        STR     r1, [fp, #1*4]

        ; Set TempFS to the one specified
        MOV     r2, fscb
        BL      SetTempFS
        LDRVCB  r2, [fscb, #fscb_info]

90
 [ debugcontrol
        BVS     %FT01
        LDR     r1, [fp, #1*4]
        DSTRING r1, "Command tail is "
        DREG    r2, "FS # = "
        DSTRING r3, "Special="
01
 ]
        SwiExit

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; <name term>           ::=     CtrlChar | space

; <digit>               ::=     0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9

; <letter>              ::=     A | B | C | D | E | F | G | H | I | J | K | L
;                             | M | N | O | P | Q | R | S | T | U | V | W | X
;                             | Y | Z | a | b | c | d | e | f | g | h | i | j
;                             | k | l | m | n | o | p | q | r | s | t | u | v
;                             | w | x | y | z | <any top bit set char>

; <alphanumeric>        ::=     <letter> | <digit> | _

; <allowed char>        ::=     <alphanumeric>
;                             | <left angle bracket> | <right angle bracket>
;                             | <left curly bracket> | <right curly bracket>
;                             | <left round bracket> | <right round bracket>
;                             | ! | ' | = | ~ | ` | + | / | ? | ;

; <wild char>           ::=     # | *

; <allowed/wild char>   ::=     <allowed char> | <wild char>

; <absolute char>       ::=     $ | & | % | @ | backslash

; <passed name>         ::=     <filename> <name term>
;                             | " <filename> "

; <filename>            ::=     [<file system spec>] <pathname>

; <file system spec>    ::=     <file system name> [# <special cpt>] :
;                             | # <special cpt> :
;                             | - <file system name> [# <special cpt>] -
;                             | - # <special cpt> -

; <file system name>    ::=     <letter> [<letter>]n

; <special cpt>         ::=     [<allowed/wild char> | . ]n

; <pathname>            ::=     <null>
;                             | [<absolute char> .] <media name>
;                             | [<devicespec> [. $ .]] <media name>

; <device spec>         ::=     : [<allowed/wild char> | - | <absolute char>]n

; <media name>          ::=     {<filename cpt> .} <filename cpt>

; <filename cpt>        ::=     [<allowed char> | <wild char>]n
;                             | ^

; Where { }    means 0 or more ...
;       [ ](n) means optionally one (or 1..n) ...
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PoliceName
; ==========
;
; Given a pathname, make sure it conforms to general rules

; In    r1 -> <pathname>, 0 terminated

; Out   VC -> ok, things set up
;       VS -> fail, no error set

PoliceName Entry "r0-r1"

 [ debugname
 DSTRING r1,"Policing name "
 ]
        MOV     r14, #0

        LDRB    r0, [r1], #1            ; Get first char of name
        CMP     r0, #0                  ; Completely null ?
        EXIT    EQ                      ; Ok by me (FS dependent), VClear

        ; Do we have :<device spec> ?
        TEQ     r0, #":"                ; Device name / drive number ?
        BNE     %FT20                   ; Nope, try absolute spec then

        ; We have :<device spec>

        ; Make sure there's at least one character to the disc name
        LDRB    r0, [r1], #1
        TEQ     r0, #0
        TEQNE   r0, #"."
        BLNE    IsBad
        BEQ     %FA90

        ; Then check the rest of the characters in the disc name
10      LDRB    r0, [r1], #1            ; Get more chars from device name
        TEQ     r0, #0                  ; Device name only ?
        EXIT    EQ
        TEQ     r0, #"."                ; Dot also ends device name
        BLNE    IsBad                   ; Loop over allowed chars
        BNE     %BT10

        TEQ     r0, #"."                ; Must now have dot (null done above)
        BNE     %FA90                   ; Error if not

        LDRB    r0, [r1], #1            ; Get next char after dot


20      BL      IsAbsolute              ; Absolute spec ?
        BEQ     %FT80

; If not, then drop through then with NE so we don't load the next char ...


; Parse a filename component. Must not have a leading special in it

30      LDREQB  r0, [r1], #1            ; Get first char of new component
        TEQ     r0, #"^"                ; Relative symbol (parent) ?
        BEQ     %FT80                   ; Can have many of these
        TEQ     r0, #0                  ; Can't be a null component
        TEQNE   r0, #"."                ; ie. end of name or another dot
        BLNE    IsAbsolute              ; Can't be an absolute char
        BLNE    IsBad
        BEQ     %FA90

40      TEQ     r0, #"*"                ; Wild char ?
        TEQNE   r0, #"#"

        LDRB    r0, [r1], #1            ; Get more chars from component
        CMP     r0, #0                  ; Finished name ?
        EXIT    EQ                      ; VClear
        TEQ     r0, #"."                ; Finished component ?
        MOVEQ   r14, #0                 ; Reset flag if we've finished this
        BEQ     %BT30                   ; Go for another component, EQ (load)

        TEQ     r0, #"$"                ; Valid char in cpt ?
        BLNE    IsBad                   ; Only $ and junk disallowed now
        BNE     %BT40                   ; Loop over filename component

90      SETV
        EXIT


; Got absolute (or relative) path prefix
; Must now have a dot (+ more) or end of name

80      LDRB    r0, [r1], #1            ; Got a dot ?
        TEQ     r0, #"."                ; Looping or end of name ?
        BEQ     %BT30                   ; Go for another component, EQ (load)
        CMP     r0, #0                  ; Finished name ? VClear
        SETV    NE                      ; Anything else is bad
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Most of the time we want to give an error

PoliceNameWithError Entry

        BL      PoliceName
        BLVS    SetMagicBadFileName     ; VSet too
 [ debugname
 EXIT VS
 DLINE "Name ok: "
 ]
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; PoliceSpecial
;
; In    r1 -> special field to be policed (ctrl char or : terminated)
;
; Out   VSet if bad, no error set
;
PoliceSpecial Entry "r0,r1"
05
        LDRB    r0, [r1], #1
        CMP     r0, #space-1
        TEQHI   r0, #delete
        TEQHI   r0, #":"
        BLS     %FT10
        BL      IsBad
        BNE     %BT05
        SETV
        EXIT

10
        CLRV
        EXIT

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Returns EQ if not allowed in a filename component or device name, NE if ok

IsBad   CMP     r0, #space              ; Space or CtrlChar is bad for you
        CMPLS   r0, r0                  ; EQ if one of those
        TEQNE   r0, #delete             ; Delete is pretty useless too
        TEQNE   r0, #":"                ; Colon is drive specifier
 [ False ; Bruce likes commas
        TEQNE   r0, #","                ; Comma is path separator
 ]
        TEQNE   r0, #solidus            ; Solidus and quotes may be confusing
        TEQNE   r0, #quote              ; to file servers and the like
        MOV     pc, lr


IsAbsolute
        TEQ     r0, #"$"                ; Device root
        TEQNE   r0, #"&"                ; URD
        TEQNE   r0, #"@"                ; CSD
        TEQNE   r0, #"%"                ; LIB. New symbol
        TEQNE   r0, #"\\"               ; PSD. New symbol
        MOV     pc, lr

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; In    r0 = char

; Out   CS -> alphanumeric (a-z,0-9,_); CC otherwise

IsAlphanumeric

        CMP     r0, #"_"                ; Must check first to prevent > '_' in
        MOVEQ   pc, lr                  ; CS

        Entry                           ; Need r14 temp
        CMP     r0, #"0"
        RSBCSS  r14, r0, #"9"
        EXIT    CS
        CMP     r0, #"A"
        RSBCSS  r14, r0, #"Z"
        EXIT    CS
        CMP     r0, #"a"
        RSBCSS  r14, r0, #"z"
        EXIT

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

        LTORG

        END
