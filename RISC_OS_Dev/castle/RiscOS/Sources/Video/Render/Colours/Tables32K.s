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
;associated with the 32K tables are two linked lists. The first is
;for the palettes of 32K tables held on resourcefs, and the second
;is for 32K tables held in rma.
;
;Structure is:
;               Palette                Table
;0              Next or 0              Next or 0
;4              Palette size           Palette size
;8              Table size             Table size
;12...          Palette                Palette
;after palette  ROM ptr or 0           CTrans32Kplus header                   
;and then       leafname               32K table data

                    ^ 0
cachedtable_next    # 4
cachedtable_palsize # 4
cachedtable_tabsize # 4
cachedtable_palette # 0

;warning! this routine is written to be fast, and is register intensive
;there are no registers spare in the central routine. note particularly
;that r12 is reused in the main loop (as errorarray).

;returning of colour numbers is the only form supported, likewise transfer
;functions are not supported here - they would slow things up too much!

thiscolour RN 0
blueerrstep RN 6
greenerrstep RN 7
rederrstep RN 8
errorarray RN 12
colourarray RN 10
palette RN 9

        GBLA    red_bits
        GBLA    green_bits
        GBLA    blue_bits
        GBLA    red_shift
        GBLA    green_shift
        GBLA    blue_shift
        GBLL    smallcache

; In:
; R0 = source mode
; R2 = destination mode
; R3 = destination palette
; R4 = pointer to 12 byte output buffer for {"32K.", table pointer, "32K."}
;                                        or {"32K+", table pointer, "32K+"}

; Stack workspace structure
                  ^ 0
make32k_header    # CTrans32Kplus_ExpectedSize
make32k_tablesize # 4
make32k_stacksize # 0

make32Ktable
        Entry   "R0-R12", make32k_stacksize

        Debug   table32K,"_____________________________________________________"
        Debug   table32K,""
        Debug   table32K,"Want to build a 32K table..."

        ROUT

        Debug   table32K,"Stack in is",R13

; find out the number of colours
        FRAMLDR R0,,R2                              ;recover stacked R2
        Debug   table32K,"Target mode",R0
        MOV     R1,#VduExt_Log2BPP
        SWI     XOS_ReadModeVariable                ;read the log2bpp for this mode
        BVS     exit_32k
        MOV     R0,#1
        MOV     R6,R2                               ;save the log2bpp
        MOV     R1,R0,LSL R2                        ;convert log2bpp to bpp
        MOV     R11,R0,LSL R1                       ;convert bpp to #colours (256 for 8bpp)
        Debug   table32K,"Palette entries",R11

        FRAMLDR R5,,R3                              ;get stacked R3 back
                                                    ;either => palette,
                                                    ;       0 for default for mode
                                                    ;       -1 for current
        Debug   table32K,"stacked R3",R5

        CMP     R5,#-1
        BEQ     %FT23                               ; -1 - use current palette
        CMP     R5,#0
        MOVNE   palette,R5
        BNE     %FT24                               ;palette supplied - use it

        ;we want the default palette for the mode
        ADRL    R7,defpals
        LDR     R8,[R7,R6,LSL #2]

        CMP     R6,#3                               ;use the copy in defpals
        MOVCC   palette,R8
        BCC     %FT24
23

; get the memory for it                             ;claim space to keep palette
        MOV     R0,#6                               ;size=#colours * 4
        MOV     R3,R11,LSL #2
        SWI     XOS_Module
        Debug   table32K,"claiming for palette",R3
        BVS     exit_32k
        MOV     palette,R2
        FRAMLDR R0,,R12                             ;fetch R12, workspace pointer
        STR     palette,[R0,#temp_palette]          ;ensure we can deallocate on die
                                                    ;(if necessary)

        ; if R5=0 and R6=3 here, we have to copy over and
        ; create a full 256 palette

        CMP     R5,#0
        CMPEQ   R6,#3
        BNE     %FT22                               ;check for 8bpp and use defpal

        ADRL    R7,modetwofivesix                   ;the condensed palette data
        MOV     R6,#0                               ;colour index
        MOV     R1,#&88000000                       ;mask 1
        MOV     R2,#&00880000                       ;mask 2
        MOV     R3,#&00440000                       ;mask 3
        MOV     R4,#&00008800                       ;mask 4
        MOV     R5,R9                               ;pointer to palette space

50      LDR     R0,[R7,R6,LSL #2]                   ;get the first word
        ORR     R0,R0,R0,LSR #4                     ;duplicate top nibble into bottom

        ORR     R8,R0,R1                            ;or in mask 1
        ORR     R8,R8,R2                            ;and mask 2
        STR     R8,[R5],#64                         ;store in first quarter, and increment
                                                    ;to second quarter

        ORR     R8,R8,R4                            ;or in mask 3
        STR     R8,[R5],#128                        ;store in second quarter, and increment
                                                    ;to fourth quarter

        ORR     R8,R8,R3                            ;or in mask 4
        STR     R8,[R5],#-64                        ;store in fourth quarter, and decrement
                                                    ;to third quarter

        EOR     R8,R8,R4                            ;eor out mask 3
        STR     R8,[R5],#-124                       ;store in third quarter, and move back
                                                    ;to *next* entry in first quarter

        ADD     R6,R6,#1                            ;next colour
        CMP     R6,#16                              ;done 16 yet ?
        BCC     %BT50                               ;continue

        B       %FT24
22
                                                    ;we want the default palette
        MOV     R0,#-1
        MOV     R1,R0
        MOV     R2,palette
        MOV     R3,R11,LSL #2
        MOV     R4,#0
        Debug   table32K,"Calling ReadPalette",R0,R1,R2,R3,R4
        SWI     ColourTrans_ReadPalette
        BVS     exit_32k

        SWI     ColourTrans_InvalidateCache
        Debug   table32K,"Invalidating cache"

; and now - it's showtime.....
24

; work out how many colours are in the source mode, and if we need to do
; red/blue swapping

        FRAMLDR R0                          ; recover R0
        MOV     R1,#VduExt_NColour
        SWI     XOS_ReadModeVariable
        BVS     exit_32k
        CMP     R2,#65536
        MOV     R3,R2
        MOVHI   R0,#32768                   ; Only produce standard 32K table for >16bpp source mode
        MOVHI   R3,#65536
        MOVHI   R10,#0
        SUBHI   R3,R3,#1
        BHI     %FT30
        MOV     R1,#VduExt_ModeFlags
        SWI     XOS_ReadModeVariable
        BVS     exit_32k
        TST     R2,#ModeFlag_64k
        BIC     R10,R2,#ModeFlag_DataFormatSub_Alpha ; Keep just the RGB order+64K flag. Source alpha is ignored in all current table formats.
        MOVNE   R0,#65536
        BNE     %FT30
        ADD     R0,R3,#1
        CMP     R0,#4096
        MOVNE   R0,#32768
30
        Debug table32K,"Lookup table entries",R0
        Debug table32K,"mode flags =",R10
        Debug table32K,"NColour =",R3

        ; Set up the header structure held on the stack
        STR     R3,[SP,#make32k_header+CTrans32Kplus_SrcNColour]
        STR     R10,[SP,#make32k_header+CTrans32Kplus_SrcModeFlags]
        MOV     LR,#4 ; Always 16bpp source
        STR     LR,[SP,#make32k_header+CTrans32Kplus_SrcLog2BPP]
        STR     R11,[SP,#make32k_header+CTrans32Kplus_DestCount]
        ASSERT  CTrans32Kplus_HeaderSize = CTrans32Kplus_TableFormat+2
        LDR     LR,=0+(CTrans32Kplus_ExpectedSize<<16)
        STR     LR,[SP,#make32k_header+CTrans32Kplus_TableFormat]
        ; And remember the number of table entries
        STR     R0,[SP,#make32k_tablesize]

; we may be able to save ourselves some work here.....

; check down the anchor_tables and anchor_resourcefs chains
; if we find it in anchor_tables we already have a ready-made 32K table
; if we find it in anchor_resourcefs we turn this link into a anchor_table
;   entry and load the table from resourcefs

; first test is whether the palette size (#4 in both structures) = R11 LSL #2
; r1-r8 are free at the moment

; check the extant tables first....

        [ debugtable32K
        STMFD R13!,{R0-R8}
        MOV R8,palette
        LDMFD R8!,{R0-R7}
        Debug table32K,"First sixteen words of palette...."
        Debug table32K,"",R0,R1,R2,R3
        Debug table32K,"",R4,R5,R6,R7
        LDMFD R8!,{R0-R7}
        Debug table32K,"",R0,R1,R2,R3
        Debug table32K,"",R4,R5,R6,R7
        LDMFD R13!,{R0-R8}
        ]

        FRAMLDR R3,,R12                     ; recover R12
        LDR     R3,[R3,#anchor_tables]
        TEQ     R3,#0
        BEQ     %FT70                       ; branch if no cached tables
71
        ASSERT  cachedtable_palsize = 4
        ASSERT  cachedtable_tabsize = 8
        LDMIB   R3,{R4,R6}                  ; collect size

        Debug   table32K,"size of palette table =",R4
        Debug   table32K,"size of lookup table =",R6
        CMP     R4,R11,LSL #2
        CMPEQ   R6,R0
        BNE     %FT76                       ; size is wrong

        ; Check the 32K+ header
        ASSERT  CTrans32Kplus_ExpectedSize = 5*4
        ADD     R6,R3,#cachedtable_palette
        ADD     R6,R6,R11,LSL #2
        ADD     R5,SP,#make32k_header
        LDMIA   R6!,{R4,R7}
        LDMIA   R5!,{R2,LR}
        Debug   table32K,"SrcNColour = ",R4
        Debug   table32K,"SrcModeFlags = ",R7
        CMP     R4,R2
        CMPEQ   R7,LR
        LDMEQIA R6!,{R4,R7,LR}
        DebugIf EQ,table32K,"SrcLog2BPP = ",R4
        DebugIf EQ,table32K,"DestCount = ",R7
        DebugIf EQ,table32K,"TableFormat = ",LR
        LDMEQIA R5,{R2,R5}
        CMPEQ   R4,R2
        CMPEQ   R7,R5
        CMPEQ   LR,#0+(CTrans32Kplus_ExpectedSize<<16)
        BNE     %FT76

        ; header is a match - check the entries
        ADD     R6,R3,#cachedtable_palette  ; r6=pointer to one to test
                                            ; palette = our one
        MOV     R7,R11,LSL #2
77
        SUBS    R7,R7,#4
        BMI     %FT78                       ; if we run out of colours both are the same

        LDR     R5,[palette,R7]
        LDR     R8,[R6,R7]
        Debug   table32K,"palette value, table value",R5,R8
        TEQ     R5,R8
        BNE     %FT76                       ;failed - try another
        B       %BT77                       ;matched - try next colour

78                                          ;we have a match!
        Debug   table32K,"we found it (table exists)!!!!!"
        ADD     R6,R6,R11,LSL #2
        ADD     R6,R6,#CTrans32Kplus_ExpectedSize
        B       %FT83                       ;return table

76
        LDR     R4,[R3,#cachedtable_next]   ;read the next pointer
        TEQ     R4,#0
        MOVNE   R3,R4                       ;go round again whilst not at end of chain
        BNE     %BT71


70
        ; Check whether this is the right palette for a table held in resourcefs

        ; At the moment we only support old-style "32K." tables from
        ; resourcefs, so our header held on the stack must match the format
        ; required for that
        
        ASSERT  CTrans32Kplus_SrcNColour = 0
        ASSERT  CTrans32Kplus_SrcModeFlags = 4
        ASSERT  CTrans32Kplus_SrcLog2BPP = 8
        ASSERT  CTrans32Kplus_DestCount = 12
        ASSERT  CTrans32Kplus_TableFormat = 16
        ASSERT  CTrans32Kplus_HeaderSize = 18
        ASSERT  CTrans32Kplus_ExpectedSize = 5*4
        ADD     R2,SP,#make32k_header
        LDMIA   R2,{R2-R6}
        ADD     R2,R2,#1
        CMP     R3,#0
        CMPEQ   R4,#4
        CMPEQ   R2,#65536
        ; R5 check not needed here, handled below
        CMPEQ   R6,#0+(CTrans32Kplus_ExpectedSize<<16)
        DebugIf NE,table32K,"wrong format for resourcefs table"
        BNE     %FT80                       ;wrong format for resourcefs tables

        FRAMLDR R3,,R12
        LDR     R3,[R3,#anchor_resourcefs]
        TEQ     R3,#0
        BEQ     %FT80                       ;branch if no resourcefs tables
72
        ASSERT  cachedtable_palsize = 4
        ASSERT  cachedtable_tabsize = 8
        LDMIB   R3,{R4,R6}                  ; collect size

        Debug   table32K,"size of resourcefs palette =",R4
        Debug   table32K,"size of resourcefs table =",R6

        CMP     R4,R11,LSL #2
        CMPEQ   R6,R0
        BNE     %FT73                       ;wrong number of colours - next!

        ; header is a match - check the entries
        ADD     R6,R3,#cachedtable_palette  ;r6=pointer to one to test
                                            ;palette = our one
        MOV     R7,R11,LSL #2
74
        SUBS    R7,R7,#4
        BMI     %FT75                       ;run out of colours ? matched if so

        LDR     R5,[palette,R7]
        LDR     R8,[R6,R7]
        TEQ     R5,R8
        Debug   table32K,"(resourcefs) palette value, table value",R5,R8
        BNE     %FT73                       ;failed - try another
        B       %BT74                       ;matched - try next colour

75      ;we have a match!
        Debug   table32K,"we found it (need to load table)!!!!!"

        ;instead of using colourarray as scratchspace we use [WP,#temp_gbpb]
        ;registers in at this point:
        ;R6->first word of palette data (ie resourcefs info block + 8)

        SUB     R8, R6, #cachedtable_palette ;now R8->start of record

        ; build filename at WP,#temp_gbpb. safe to use as WP now, since both
        ; errorarray and colourarray are not used yet here

        LDR     R3, [R6, #cachedtable_palsize-cachedtable_palette] ;length of palette table
        ADD     R6, R6, R3
        LDR     R3,[R6]
        Debug   table32K,"cached resourcefs pointer is",R3
        CMP     R3,#0
        MOVNE   R6,R3
        BNE     %FT86

        FRAMLDR WP            
        ADD     colourarray, WP, #temp_gbpb ;point at workspace

        ADRL    R3,tablepath                ;pathname for table in resourcefs
        ADD     R4,colourarray,#16          ;scratchspace for name
91
        LDRB    R5,[R3],#1                  ;copy the path, excluding terminator
        TEQ     R5,#0
        STRNEB  R5,[R4],#1
        BNE     %BT91
        ADD     LR,R6,#4                    ;leafname pointer
92
        LDRB    R5,[LR],#1                  ;copy the name, including terminator
        STRB    R5,[R4],#1
        TEQ     R5,#0
        BNE     %BT92

        MOV     R0,colourarray              ;use first four words as MessageTrans descriptor
        ADD     R1,R0,#16
        Debug   table32K,"full filename at",R1

        ; we need to findout if we can reference it directly or not

        Debug   table32K,"checking for resourcefs"
        ; open file
        MOV     r0, #OSFind_ReadFile
        Debug   table32K," -opening file"
        SWI     XOS_Find
        BVS     exit_32k
        MOV     r4,r0

        ; get internal handle
        MOV     r0, #FSControl_ReadFSHandle
        MOV     r1, r4
        Debug   table32K," -checking FS information"
        SWI     XOS_FSControl
        MOVVS   r3, #0                      ; if error, remember that we didn't get it
        MOVVC   r3, r1                      ; r6 = location of data in ROM
        AND     r2, r2, #&FF                ; get fsinfoword
        TEQ     r2, # fsnumber_resourcefs   ; is it resourcefs ?
        MOVNE   r3, #0

        ; close file
        MOV     r0, #0
        MOV     r1, r4
        Debug   table32K," -closing file"
        SWI     XOS_Find
        BVS     exit_32k

        Debug   table32K,"ROM data = ",r3
        ; did we fail to find the information we wanted ?
        TEQ     r3,#0
        BEQ     %FT84                       ; jump out and do the load anyhow

        LDR     r0,[r3]
        LDR     r1,sqshtag
        TEQ     r0,r1
        BEQ     %FT84
        STR     r3,[r6]                     ; set ROM pointer
        MOV     r6,r3
        Debug   table32K,"Not squashed, we have our data"
        B       %FT86

84      ;entry where filename is in colourarray at +16
        ADD     R1,colourarray,#16
85      ;file needs expanding - build a full record for it

        ;R1 points at assembled filename
        ;R8 is start of record

        ADD     R6, R8, #cachedtable_palette ;point at the palette entries

                                            ;next thing is to build a full
                                            ;entry for this one - the palette is in
                                            ;memory, but the table is still in
                                            ;resourcefs
        MOV     R0,#ModHandReason_Claim
        LDR     R5,[R8,#cachedtable_tabsize] ;32K for the table
        ADD     R3,R5,#cachedtable_palette+CTrans32Kplus_ExpectedSize  ;space needed for header
        ADD     R3,R3,R11,LSL #2            ;space for colours
        Debug   table32K,"claiming for table",R3
        SWI     XOS_Module
        BVS     %FT73
        STR     R5,[R2,#cachedtable_tabsize] ; store table size
                                            ;link it in to the table chain (at the
                                            ;beginning for speed in retrieval)

        MOV     R5,R2                       ;save the start of the block
        FRAMLDR R3,,R12                     ;recover workspace pointer
        LDR     R4,[R3,#anchor_tables]      ;get the anchor value
        STR     R2,[R3,#anchor_tables]      ;replace it with this one
        ASSERT  cachedtable_next = 0
        STR     R4,[R2],#4                  ;and link from this one to the old one

        MOV     R3,R11,LSL #2
        ASSERT  cachedtable_palsize = 4
        STR     R3,[R2],#8                  ;set the palette size (R2 now -> palette)

        ASSERT  cachedtable_palette = 12
81      LDR     R7,[R6],#4                  ;copy the palette entries across
        STR     R7,[R2],#4
        SUBS    R3,R3,#4
        BNE     %BT81                       ;both structures are same up until the end
                                            ;of the palette data.

        ; Copy over the 32K+ header
        ASSERT  CTrans32Kplus_ExpectedSize = 5*4
        ADD     R0,SP,#make32k_header
        LDMIA   R0,{R0,R3,R6,R10,LR}
        STMIA   R2!,{R0,R3,R6,R10,LR}
        

        MOV     R6,R2
        Debug   table32K,"Loading via load_and_unsquash"
        BL      load_and_unsquash
        LDRVS   R0,[SP,#make32k_tablesize]
        LDRVS   R10,[SP,#make32k_header+CTrans32Kplus_SrcModeFlags]
        BVS     %FT80
        Debug   table32K,"Loaded via load_and_unsquash"

        Debug   table32K,"Successfully loaded file"

83
        ;colourarray wasn't claimed from rma, so don't release it!
86

        MOV     colourarray,R6               ;return colourarray=table location

        ; just the palette to release
        B       release_palette

73
        LDR     R4,[R3,#cachedtable_next]    ;fetch the next link
        TEQ     R4,#0                        ;and go round again if not null
        MOVNE   R3,R4
        BNE     %BT72

80
        ;unfortunately this is a brand new palette, so we have to make a 32K table

; new later location to avoid the disruption caused by transient claims for tables
; which turn out to be available from reourcefs

; allocate memory for scratch table

        MOV     R5,R0
        MOV     R0,#ModHandReason_Claim
        ADD     R3,R5,R11,LSL #2
        ADD     R3,R3,#cachedtable_palette+CTrans32Kplus_ExpectedSize
        SWI     XOS_Module
        Debug   table32K,"claiming for scratchtable",R3
        BVS     exit_32k
        MOV     R8,R10                              ;protect modeflags (currently in R10, i.e. colourarray)
        MOV     colourarray,R2
        STR     colourarray,[WP,#temp_table]        ;save location in workspace so it can
                                                    ;be deallocated if still active when
                                                    ;CTrans dies

        Debug   table32K,"Table will be at ",colourarray
        STR     R5,[colourarray,#cachedtable_tabsize] ; store table size

        MOV     R0,#ModHandReason_Claim             ;claim 32K for the error array
        MOV     R3,R5                               ;(holds the error value for the current
                                                    ;colour choice in the 32K array)
        Debug   table32K,"claiming for errorarray",R3
        SWI     XOS_Module
        BVS     exit_32k
        STR     R2,[WP,#temp_errortable]            ;save location in workspace so it can
                                                    ;be deallocated if still active when
                                                    ;CTrans dies
        MOV     errorarray,R2

        Debug   table32K,"errorarray",errorarray

; ***** errorarray = r12 - don't use WP anymore

        ;change colourarray so it points at the 32K block rather than the start of
        ;the claimed area

        Debug   table32K,"Changing colourarray from",colourarray
        MOV     R1,R11,LSL #2
        STR     R1,[colourarray,#cachedtable_palsize] ;set up the palette size
        ADD     colourarray,colourarray,#cachedtable_palette ;add on overhead for next pointer & size word
84      SUBS    R1,R1,#4
        LDR     R2,[palette,R1]              ;copy across palette entries from wherever
        STR     R2,[colourarray,R1]          ;they came from
        BNE     %BT84

        MOV     palette,colourarray          ;point algorithm at the palette

        ; Copy over the 32K+ header, and move colourarray to the 32K space
        ASSERT  CTrans32Kplus_ExpectedSize = 5*4
        ADD     R0,SP,#make32k_header
        LDMIA   R0,{R0-R3,LR}
        ADD     colourarray,colourarray,R11,LSL #2
        STMIA   colourarray!,{R0-R3,LR}

        Debug   table32K,"to",colourarray

        ; Pull in the main algorithm
        ; We have six versions, for the different pixel formats and RGB orders
        ; supported

        LDR     R0,[palette,#cachedtable_tabsize-cachedtable_palette] ; recover table size
        ASSERT  ModeFlag_DataFormatSub_RGB = 4:SHL:12
        AND     R8,R8,#ModeFlag_DataFormatSub_RGB
        CMP     R0,#32768
        ADDLT   R8,R8,#8:SHL:12
        ADDGT   R8,R8,#16:SHL:12
        ADD     PC,PC,R8,LSR #12
        NOP
        B       make32K_32K_BGR
        B       make32K_32K_RGB
        B       make32K_4K_BGR
        B       make32K_4K_RGB
        B       make32K_64K_BGR
        B       make32K_64K_RGB

; Assume ARMv7+ has large enough caches to not need the small cache optimisation. Ideally we'd query the kernel at runtime for the cache size, but for now this will do.
smallcache  SETL NoARMv7

        ; 32K cases
make32K_32K_BGR
red_bits    SETA 5
green_bits  SETA 5
blue_bits   SETA 5
red_shift   SETA 16-5
green_shift SETA 24-5
blue_shift  SETA 32-5
        GET      TablesAlgo.s
        B        make32K_finishing

make32K_32K_RGB
red_shift   SETA 32-5
blue_shift  SETA 16-5
        GET      TablesAlgo.s
        B        make32K_finishing

        ; 4K cases
make32K_4K_BGR
red_bits    SETA 4
green_bits  SETA 4
blue_bits   SETA 4
red_shift   SETA 16-4
green_shift SETA 24-4
blue_shift  SETA 32-4
        GET      TablesAlgo.s
        B        make32K_finishing

make32K_4K_RGB
red_shift   SETA 32-4
blue_shift  SETA 16-4
        GET      TablesAlgo.s
        B        make32K_finishing

        ; 64K cases
make32K_64K_BGR
red_bits    SETA 5
green_bits  SETA 6
blue_bits   SETA 5
red_shift   SETA 16-5
green_shift SETA 24-6
blue_shift  SETA 32-5
        GET      TablesAlgo.s
        B        make32K_finishing

make32K_64K_RGB
red_shift   SETA 32-5
blue_shift  SETA 16-5
        GET      TablesAlgo.s
        ; Fall through....

make32K_finishing
        ;link the table in
        SUB     R5,colourarray,#cachedtable_palette+CTrans32Kplus_ExpectedSize
        SUB     R5,R5,R11,LSL #2            ; set r5 to start of claimed space

        Debug   table32K,"Linking into tables as",R5

        FRAMLDR R2,,R12                     ; fetch the anchor for the tables
        LDR     R3,[R2,#anchor_tables]      ; fetch the present first entry
        STR     R5,[R2,#anchor_tables]      ; store this as new first entry
        STR     R3,[R5,#cachedtable_next]   ; and link from this one to old first entry
        MOV     R5,#0
        STR     R5,[R2,#temp_table]         ; forget about having claimed it - it is
                                             ; now covered in the anchor_tables chain
        ; moved here so we don't get fussy when all that's been returned is a pointer
        ; to a rom table
        [ immortal
        STRVC   LR,[R2,#persist]             ; refuse to die - we have passed out addresses
                                             ; of rma we claimed
        ]

found_a_table
        Debug   table32K,"Found/Built a table - freeing workspace"
        MOV     R0,#ModHandReason_Free
        MOV     R2,errorarray                ; release the guard array & palette
        SWI     XOS_Module
        Debug   table32K,"freeing errorarray"
release_palette
        MOV     R0,#ModHandReason_Free
        MOV     R2,palette
        SWI     XOS_Module
        Debug   table32K,"freeing palette"

        FRAMLDR R5,,R12                      ;fetch stacked R12

        MOV     R4,#0
        STR     R4,[R5,#temp_palette]
        STR     R4,[R5,#temp_errortable]     ; and mark them as released
        CLRV

exit_32k
        FRAMSTR R0,VS                        ; store error pointer if an error occurred
        BVS     exit_32k_error

        FRAMLDR R4                           ; fetch callers R4 (where to put selecttable)

        ; Work out if this needs to be a "32K." or "32K+" table
        ASSERT  CTrans32Kplus_SrcNColour = 0
        ASSERT  CTrans32Kplus_SrcModeFlags = 4
        ASSERT  CTrans32Kplus_SrcLog2BPP = 8
        ADD     R0,SP,#make32k_header
        LDMIA   R0,{R0-R2}
        ADD     R0,R0,#1
        CMP     R1,#0
        CMPEQ   R2,#4
        CMPEQ   R0,#65536
        LDREQ   R0,thirtytwok
        LDRNE   R0,thirtytwokplus
        DebugIf NE,table32K,"Returning 32K+ table"
        STR     R0,[R4,#0]                   ; store the first guardword
        Debug   table32K,"Returned table pointer is",colourarray
        STR     colourarray,[R4,#4]          ; the pointer to the 32K table
        STR     R0,[R4,#8]                   ; and the second guardword

        MOV     R10,#12                      ; set R10 (size of generated table) to 12
        FRAMSTR R10           

exit_32k_error
        [ debugtable32K
        PullEnv                              ; get registers back
        Debug   table32K,"32K return",R0,R1,R2,R3,R4
        Debug   table32K,"stack out is",R13
        MOV     R15,R14
        |
        EXIT
        ]

sqshtag
        = "SQSH"

thirtytwok
        =       "32K."

thirtytwokplus
        =       "32K+"

tablepath = "Resources:$.Resources.Colours.Tables.",0
        ALIGN

; load file and unsquash it if necessary
; => r1-> filename
;    r2-> 32k block to put it in
load_and_unsquash ROUT
        Push     "r1-r8,lr"

        Debug    table32K,"load and unsquash"

        MOV      r7,r2                    ; remember 'real' 32k table pointer
        MOV      r0,#OSFile_ReadInfo
        DebugS   table32K,"readinfo on file ",R1
        SWI      XOS_File
        BVS      %FT80

        MOV      r6,r0
        MOV      r0,#FSControl_InfoToFileType
        SWI      XOS_FSControl
        BVS      %FT80
        Debug    table32K,"to filetype gave ",R2

        SUB      r2,r2,#FileType_Squash :AND: &f00
        TEQ      r2,#FileType_Squash :AND: &0ff
        BNE      %FT90                             ; it's not squashed

        Debug    table32K,"it's squashed; we need to unsquash it"
        ; it's a squash file; we need to
        ;  1 find workspace needed
        ;  2 allocate memory for ws and file
        ;  3 load file
        ;  4 unsquash the file into destination block
        ;  5 unallocate memory

        ; do 1.
        MOV      r0,#2_1000         ; we know it should fit
        MOV      r1,#-1
        SWI      Squash_Decompress
        BVS      %FT80
        ADD      r3,r0,r4           ; amount of space we need
        Debug    table32K,"squash needs ",R0

        ; do 2.
        MOV      R0,#ModHandReason_Claim
        Debug    table32K,"claiming workspace for unsquash ",R3
        SWI      XOS_Module
        BVS      %FT80

        MOV      r8,r2              ; r8-> workspace

        ; do 3.
        MOV      r0,#OSFile_LoadNoPath
        LDR      r1,[sp]            ; re-read filename
        MOV      r3,#0
        Debug    table32K,"loading file to ",R2
        SWI      XOS_File
        BVS      %FT85

        ; do 4.
        MOV      r0,#2_0100         ; we know it should fit
        ADD      r1,r8,r4           ; workspace is at the end
        ADD      r1,r1,#3
        BIC      r1,r1,#3           ; align it
        ADD      r2,r8,#20          ; input pointer
        SUB      r3,r4,#20          ; input size
        MOV      r4,r7              ; output pointer
        MOV      r5,#&8000          ; output size = 32k
        Debug    table32K,"decompressing file"
        SWI      XSquash_Decompress
        BVS      %FT85

        ; do 5.
        MOV      R0,#ModHandReason_Free
        MOV      R2,R8
        Debug    table32K,"releasing workspace for unsquash ",R2
        SWI      XOS_Module
;         BVS      %FT80

80
        Debug    table32K,"returning..."
        Pull     "r1-r8,pc"

85
        Debug    table32K,"error while in processing code ",R2
        MOV      R3,r0

        MOV      R0,#ModHandReason_Free
        MOV      R2,R8
        Debug    table32K,"releasing workspace for unsquash ",R2
        SWI      XOS_Module

        MOV      R0,R3
        SETV
        B        %BT80

90
        Debug    table32K,"loading normal file to ",R7
        MOV      r0,#OSFile_LoadNoPath
        MOV      r2,r7
        MOV      r3,#0
        SWI      XOS_File
        B        %BT80

        END
