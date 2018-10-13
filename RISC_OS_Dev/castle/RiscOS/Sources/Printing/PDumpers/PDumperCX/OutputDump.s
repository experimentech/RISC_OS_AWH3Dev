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
; > OutputDump

;------------------------------------------------------------------------------
;
; Canon Extended Mode device
; ----------------
;
; The configuration word contains a set of control flags which are used
; to indicate which type of dump is to be performed:
;
;       bit 0 set   => perform compression on data section
;       bit 1 set   => don't perform start of page feed (for roll devices)
;

;------------------------------------------------------------------------------

        GET     ^.Generic.OutputDump.s

;Macro to perform bit transforms on the data about to be sent to the
;device, this should be called proir to doing a counted string output
;it will preserve the start and size registers but will destory
;the three temporary registers.
        MACRO
$l      CXTranspose $start,$size,$temp1,$temp2,$temp3
$l
        Push    "$start,$size"  ;Preserve start and end points correctly
00
        SUBS    $size,$size,#1  ;Have we finished sending the line yet?
        BLT     %FT20           ;Yes so exit the main loop

        LDRB    $temp1,[$start],#1
        MOV     $temp1,$temp1,LSL #24
        MOV     $temp2,#8       ;Reverse the top eight bits of $temp1
10
        MOVS    $temp1,$temp1,LSL #1
        MOV     $temp3,$temp3,RRX
        SUBS    $temp2,$temp2,#1
        BNE     %BT10           ;Loop back until all bits transposed

        MOV     $temp3,$temp3,LSR #24
        STRB    $temp3,[$start,#-1]
        B       %BT00           ;Make byte to be stored (copy top 8 bits down) and loop again
20
        Pull    "$start,$size"
        MEND


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Send a line of data uncompressed to the device.
;
;  in: R0 ->Line data
;      R3 Length of the line to send in bytes
;      R6 = scan number (0 for mono)
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sendCX_compressoff ROUT

        EntryS  "R0-R4,R7"

        Debuga  Dump,"Length of line to send",R3
        Debug   Dump," from",R0

        MOV     R0,#pd_data_line_start
        ADD     R0,R0,R6,LSL#1             ;offset for the relevant ribbon
        BL      SendAString                ;this is for ribbon choosing

;Now start the graphics
;;;        ADR     R0,CX_offstart             ;Not compressed
;;;        PDumper_PrintCountedString R0,R2,LR

;Number of data bytes next
        ADD  R2,R3,#1   ;raster bytes + 1
        PDumper_PrintBinaryPair R2,R0

;colour
        ADR  R2,CX_colournames
        LDRB R2,[R2,R6]
        PDumper_OutputReg R2

;Send the data
        LDR     R0,[SP,#Proc_RegOffset]    ;Get the length and the width
        PDumper_PrintLengthString R0,R3,R1

        EXITS

;;;CX_offstart
;;;       =        6,27,"(","b",1,0,0
;;;        ALIGN

CX_colournames
       =        "K","Y","M","C","K"
       ALIGN

SendAString
       STMFD    SP!,{R2,LR}
       LDRB     R0,[R7,R0]
       CMP      R0,#0
       LDMEQFD  SP!,{R2,PC}
       ADD      R0,R7,R0
       PDumper_PrintCountedString R0,R2,LR
       LDMFD    SP!,{R2,PC}

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Send a line in Packbits compression.
;
;  in: R0 ->Data line
;      R3 Length of the line to send
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sendCX_compressed
        EntryS  "R0-R8"

        MOV     R8,#0           ;Do not send any data as R1=0
        BL      compressCX      ;And return the size back in R1

        Debuga  Dump,"Scan to get length of line at",R0
        Debug   Dump,", yeilds length of",R1

        MOV     R0,#pd_data_line_start
        ADD     R0,R0,R6,LSL#1             ;offset for the relevant ribbon
        BL      SendAString                ;this is for ribbon choosing

;Now start the graphics
;;;        ADR     R0,CX_onstart             ;It is compressed
;;;        PDumper_PrintCountedString R0,R2,LR

;Number of data bytes next
        ADD  R2,R1,#1   ;(compressed) raster bytes + 1
        PDumper_PrintBinaryPair R2,R0   ; Say how many bits involved

;colour
        ADR  R2,CX_colournames
        LDRB R2,[R2,R6]
        PDumper_OutputReg R2

        ASSERT (Proc_RegOffset = 0) :LOR: (Proc_RegOffset = 4)
        [ Proc_RegOffset = 0
        LDMIA   SP,{R0-R3}
        |
        LDMIB   SP,{R0-R3}
        ]

        MOV     R8,#-1          ;This time output the real data
        BL      compressCX

        EXITS

;;;CX_onstart
;;;       =        6,27,"(","b",1,0,1
;;;        ALIGN

;..............................................................................
;
; Perform CanonX graphics compression (level 2) on the scan line specified, returning
; the length of the generated data and spooling data to the specified
; stream if required.
;
; in    R0 ->Line to compress
;       R3 byte length of the line
;       R8 flag to indicate if data should be sent
;
; out   R0 ->Byte after line sent
;       R1 length of data sent to stream
;       R3 preserved

debugDump SETL false

compressCX ROUT

        EntryS  "R3,R6-R7"

        MOV     R1,#0           ;Amount of data spat out so far
        ADD     R3,R0,R3        ;End point of the current line
        MOV     R4,#-1          ;No image data has been sent

        Debuga  Dump,"Compress line from",R0
        Debug   Dump," to",R3

compressCX_loop
        Debug   Dump,"Looping and checking byte from",R0

        TEQ     R0,R3           ;Has the line expired?
        BLEQ    compressCX_flush
        EXITS   EQ

        LDRB    R6,[R0],#1      ;Get a character
        TEQ     R0,R3           ;End of the line, ie. only a single byte remaining?
        BEQ     compressCX_single

        LDRB    R7,[R0]         ;Get the next byte to check for run lengthing
        TEQ     R6,R7           ;Is it a run length starting?
        BEQ     compressCX_scanrun

compressCX_single
        CMP     R4,#-1          ;Is there any image data already?
        SUBEQ   R4,R0,#1        ;Nope so back step and reset the length
        MOVEQ   R5,#0
        ADD     R5,R5,#1        ;Otherwise just update the length and loop again until finished
        B       compressCX_loop

;..............................................................................
;
; As a two byte sequence has been found we attempt to scan forward looking
; for a run length.  Once this has been scanned we then break it up
; into 128 character runs that are then sent to the stream if R8 is
; none zero.
;
; in    R0 ->character following start of section
;       R1 number of bytes already sent in this line
;       R3 ->end of line
;       R6 character obtained
;       R8 flag to indicate if data should be sent
;
; out   R0 updated (must be <= R3)
;       R1 updated
;       R8 preserved

compressCX_scanrun
        SUB     R7,R0,#1        ;Setup to contain the a copy of the start of the run length

        Debug   Dump,"Scanning a run length from",R7

compressCX_looprun
        TEQ     R0,R3           ;Have we reached the end of the line yet?
        BEQ     compressCX_finished

        LDRB    LR,[R0],#1      ;Get a character
        TEQ     LR,R6           ;Is it the same as the previous one?
        BEQ     compressCX_looprun

        SUB     R0,R0,#1        ;Backstep as this character is different

compressCX_finished
        Push    "R2,R7"         ;Store away the important registers
        BL      compressCX_flush
        Pull    "R2,R7"         ;Flush the image data preceeding the run and then restore registers

        SUBS    R7,R0,R7        ;Get the length of the run area
        BEQ     compressCX_loop ;If it is zero (by accident) then skip back

compressCX_flushrunlength
        Debug   Dump,"Flushing run length",R7

        Push    "R7"

        CMP     R7,#128         ;Can I send this section of data without clipping it?
        MOVGT   R7,#128         ;Truncate if too big man
        SUB     R7,R7,#1        ;Get the length -1
        RSB     R7,R7,#0        ;and then make -ve as run length info stored as -ve value

        ADD     R1,R1,#2        ;We will output two bytes so increase the bytes sent register

        TEQ     R8,#0           ;Do I need to write anything to the stream?
        BEQ     compressCX_flushrunskip

        PDumper_OutputReg R7    ;Send the length and then the byte to be replicated
        PDumper_OutputReg R6

compressCX_flushrunskip
        Pull    "R7"            ;Restore the length remaining
        SUBS    R7,R7,#128      ;Decrease the counter
        BGT     compressCX_flushrunlength
        B       compressCX_loop ;Try some more data and stream that to the file

;..............................................................................
;
; Flush data to the stream, this routine is a general one called to flush
; any image data to the stream that is pointed to by R4 (and if R8 is non-zero).
;
; in    R1 number of bytes sent so far
;       R4 ->start of image data to be sent / =-1 for no image data
;       R5 length of image section to send / if R4 =-1 then ignored
;       R8 flag to indicate if data should be sent (<>0 then send)
;
; out   R1 updated
;       R4 -1 to indicate no image data remaining
;       R5 corrupt
;       R8 preserved

compressCX_flush
        EntryS  "R2"
        CMP     R4,#-1          ;Is there any image data worth sending?
        EXITS   EQ              ;Nope so return now


compressCX_flushloop
        Debug   Dump,"Flushing image data length",R5

        Push    "R5"            ;Store the length of the run section

        CMP     R5,#128         ;Do I need to truncate it (ie. is it more than 128 characters)
        MOVGT   R5,#128         ;Yup so truncate
        ADD     R1,R1,#1
        ADD     R1,R1,R5        ;Sending the length byte followed by the actual data for the section

        TEQ     R8,#0           ;Do we need to send any data to the stream?
        BEQ     compressCX_flushskip

        SUB     R2,R5,#1        ;Decrease the length so stored as length -1
        PDumper_OutputReg R2
        PDumper_PrintLengthString R4,R5,R2

compressCX_flushskip
        Pull    "R5"            ;Data has been spat out and R5 will have been corrupted so restore
        SUBS    R5,R5,#128
        BGT     compressCX_flushloop

        MOV     R4,#-1          ;Mark as their being no image data queued up
        EXITS

;..............................................................................
;
; Output monochrome sprite to the current file.
;
;  in: R0 ->Strip
;      R1 dump width in bytes
;      R2 dump height in rows
;      R3 row width in bytes (>=R3)
;      R5 Row width in bytes
;      R7 ->Job workspace
;
; out: -

output_mono_sprite ROUT
        Push    "R1-R4"
        MUL     R3,R5,R4
        CXTranspose R0,R3,R1,R2,R4
        Pull    "R1-R4"
        B       output_mono_sprite_norev

;all the following entries assume bit-reversal-within-byte not needed
output_mono_spriteR ROUT
;version without ribbon setting
        EntryS  "R1,R9"
        MOV     R3,R5
        B       output_mono_altentryR

output_mono_sprite_norev ROUT

        MOV     R3,R5           ;Get the byte width of the image correct

output_mono_altentry ALTENTRY

        MOV     R6,#0           ;Set to ribbon number 0

output_mono_altentryR ROUT

;set R8 to indicate whether compression occurs
        LDRB    R8,[R7,#pd_private_flags]
        Debug   DumpMJS,"PDumper byte contains",R8
        ADD     R7,R7,#pd_data             ;offset to the actual string data
10
        SWI     XOS_ReadEscapeState
        EXITS   CS              ;Return if escape pressed

        Push    "R3"            ;Get the line width
        MOV     R9,R3           ;save original length in R9
15
        SUBS    R3,R3,#1
        BMI     %20             ;Any more bytes pending?

        LDRB    LR,[R0,R3]
        TEQ     LR,#0           ;Is there a valid byte here?
        BEQ     %15
20
        ADDS    R3,R3,#1        ;Account for pre-index
        BEQ     %FT30           ;Don't bother if no data

        LDR     R9, pending_line_ends
        CMP     R9, #&80000000  ; &80000000 means line-return sent
        MOVEQ   R9, #0
        STREQ   R9, pending_line_ends
        CMP     R9, #0
        BEQ     %FT25             ;no pending vertical white space
; those pending line-ends now become a vertical move
        Debug   DumpMJS,"pending line-ends now vertical move ",R9
        Push    "R0-R3"
22
        MOV     R3,R9
        CMP     R3,#&1700       ;Canon state maximum skip value of &17FF
        MOVGT   R3,#&1700
        ADR     R0, CX_relvertical
        PDumper_PrintCountedString R0, R1, R2
        PDumper_PrintBinaryPair_HighFirst R3, R1
        SUB     R9,R9,R3
        CMP     R9,#0
        BNE     %BT22
        STR     R9, pending_line_ends ;now 0
        Pull    "R0-R3"

25
;;;        Push    "R0-R4"
;;;        PDumper_GetLeftMargin R4
;;;        LDRB    R1, [R7, #pd_data_zero_skip]
;;;        ADD     R1, R7, R1
;;;        PDumper_PrintCountedString R1,R2,LR
;;;        PDumper_PrintBinaryPair R4,R2
;;;        Pull    "R0-R4"

;amusing note:
;The df_Compression flag is bit 0, which is controlled by 'Horizontal' (1)
;or 'Vertical' (0) Output order in graphics mode in !PrintEdit for dp class.
;For PDumperCX, the compression setting in page start string must match compression setting.
        TST     R8,#df_Compression
        BLEQ    sendCX_compressoff
        BLNE    sendCX_compressed
        B       %FT35

30
;only send one line-return, count line-ends and convert to vertical move later
        Push    "R0"
        TEQ     R6,#0
        TEQNE   R6,#4
        BEQ     %FT32
;we have a line-return
        LDR     R9, pending_line_ends
        CMP     R9, #0          ;have we already sent a line-return, or are line-ends pending?
        BNE     %45             ;if so, send no more (redundant)
        MOV     R9, #&80000000  ;flag line-return seen and sent
        STR     R9, pending_line_ends
        MOV     R0,#pd_data_line_return
        B       %FT40
32
;we have a line-end
        LDR     R9, pending_line_ends
        CMP     R9, #&80000000
        MOVEQ   R9, #0
        ADD     R9, R9, #1      ;count line-ends
        Debug   DumpMJS,"line-ends = ",R9
        STR     R9, pending_line_ends
        B       %FT45

35
;And finally output the line_end, or a line_return if ribbon number not 0 or 4
        Push    "R0"
        MOV     R0,#pd_data_line_end
        TEQ     R6,#0
        TEQNE   R6,#4
        MOVNE   R0,#pd_data_line_return
40
        BL      SendAString
45
        Pull    "R0"

        Pull    "R3"            ;Restore real line length

        ADD     R0,R0,R5
        SUBS    R4,R4,#1
        BNE     %BT10           ;Loop back until all scan lines checked

        EXITS

CX_relvertical
        DCB     5               ;length
        DCB     27,"(","e",2,0
        ALIGN

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; in:   r0  -> strip
;       r3   = dump width
;       r4   = dump height
;       r5   = row width in bytes ( >= r3 )
;       r7  -> job workspace
;
; Ouput the 8BPP strip in colour. Bytes are KCMY, and have to be rearranged
; in situ, in order to do compression sensibly. The rearrangement is only
; possible, if like output_grey_sprite, the area of memory written lags
; behind the area read from. There is unfortunately a lower bound for this
; which has to be treated as a special case....
; Start is %0000KCMY %0000KCMY %0000KCMY ....
; Finish is %YYYYYYYY %YYYYYYYY... %MMMMMMMM... %CCCCCCCC.... %KKKKKKKK...
; First occupies N bytes
; Latter occupies (N/8+1)*4 at most
; First phase packs info into upper N/2+1 bytes at most

output_colour_sprite ROUT

        EntryS  "R0-R2,R4,R6-R8"
        TEQ     R3,#0           ;Ignore zero widths!
        EXITS   EQ


        Debug   Dump,"Converting colour to monochrome"
        Debuga  Dump,"At",R0
        Debuga  Dump,", Width",R3
        Debuga  Dump,", Height",R4
        Debuga  Dump,", Byte width",R5
        Debug   Dump,", Workspace at",R7

colourCX_lineloop

        Push    "R0,R3-R5,R7"         ;will need this again

;assumes width (pixels) is multiple of 8 (should be ensured by PDriverDP)
longCX_colour
        Push    "R0,R3,R7,R9"   ;Need to keep position of strip for output
        Push    "R0,R3"         ;and for CMYK scanning

        ADD     R0,R0,R3        ;->Scan line end to shuffle up
        MOV     R1,R0           ;second pointer for save

        MOV     R9, #1          ;R9 will be set false if we notice whole row is not white
                                ;(excluding last pixel of odd row - tough!)

10      SUB     R0,R0,#8
        LDMIA   R0,{R4,R7}      ;load next 8 pixels
        ORRS    R4,R4,R7,LSL #4 ;munge together (8 KCMY nibbles)
        MOVNE   R9, #0          ;reset whole-row white flag if necessary
        STR     R4,[R1,#-4]!    ;store for next pass
        SUBS    R3,R3,#8
        BNE     %BT10

        Pull    "R0,R3"         ;Restore the line start, count
        CMP     R9, #1          ;was whole row white?
        BNE     %FT15
;let's skip a whole load of work
        LDR     R9, pending_line_ends
        CMP     R9, #&80000000  ; &80000000 means line-return sent
        MOVEQ   R9, #0
        ADD     R9, R9, #1      ; another line-end (white row skip)
        STR     R9, pending_line_ends
        Pull    "R0,R3,R7,R9"
        B       colourCX_nextline

15
        MOV     R4,#1           ;Current ribbon, start at Y
        ORR     R9,R4,R4,LSL #4
        ORR     R9,R9,R9,LSL #8
        ORR     R9,R9,R9,LSL #16;ribbon bits, all 8 nibbles, start at Y (&11111111)
20
        MOV     R7,#0           ;byte so far
        Push    "R1,R3"         ;Read from here for each pass
        B       %FT30
25
        STRB    R7,[R0],#1
        SUBS    R3,R3,#8
        BLE     %FT35
30
        LDR     R8,[R1],#4      ;get 8 KCMY nibbles
        TST     R8,R9           ;check for none of 8 nibbles set against ribbon
        BEQ     %BT25           ;skip nibble-wise checks if none
        TST     R8,R4           ;check for nibble 0 set against ribbon
        ORRNE   R7,R7,#1:SHL:7  ;set bit 7 if match (bits required reversed in byte)
        TST     R8,R4,LSL #8    ;repeat for other 7 nibbles
        ORRNE   R7,R7,#1:SHL:6
        TST     R8,R4,LSL #16
        ORRNE   R7,R7,#1:SHL:5
        TST     R8,R4,LSL #24
        ORRNE   R7,R7,#1:SHL:4
        TST     R8,R4,LSL #4
        ORRNE   R7,R7,#1:SHL:3
        TST     R8,R4,LSL #12
        ORRNE   R7,R7,#1:SHL:2
        TST     R8,R4,LSL #20
        ORRNE   R7,R7,#1:SHL:1
        TST     R8,R4,LSL #28
        ORRNE   R7,R7,#1:SHL:0
        STRB    R7,[R0],#1      ;a byte of ribbon colour now ready to store
        MOV     R7, #0          ;clear ribbon colour bits again
        SUBS    R3,R3,#8
        BGT     %BT30
35
        Pull    "R1,R3"         ;Get the input data back
        MOV     R4,R4,LSL #1    ;Next ribbon (1 bit mask)
        MOV     R9,R9,LSL #1    ;Next ribbon (8 bit mask)
        ANDS    R4,R4,#15       ;Check if bit is in range
        BNE     %BT20

        Pull    "R0,R3,R7,R9"

colourCX_rearranged
        BL      colourCX_colourstrip

colourCX_nextline

        Pull    "R0,R3-R5,R7"
        ADD     R0,R0,R5        ;Adjust the line pointer
        SUBS    R4,R4,#1
        BGT     colourCX_lineloop ;Loop back until all bits tested

colourCX_exit
        EXITS

colourCX_colourstrip
;So now can do four output_mono_strip's from R0 width R3 job R7 ribbon R1
        Push    "LR"

        ADD     R5,R3,#7
        MOV     R5,R5,LSR#3
        MOV     R4,#1
        MOV     R6,#1                          ;Ribbon number
10
        Push    "R0,R3,R4,R5,R6,R7"               ;Keep this lot for each pass

;        Debug   DumpMJS,"output_monospriteR ribbon ",R6
        BL      output_mono_spriteR

        Pull    "R0,R3,R4,R5,R6,R7"
        BVS     %FT20                          ;Bombed already
        ADD     R0,R0,R5
        ADD     R6,R6,#1
        CMP     R6,#4
        BLE     %BT10
20
        Pull    "PC"

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; in:   r0  -> strip
;       r3   = dump width
;       r4   = dump height
;       r5   = row width in bytes ( >= r3 )
;       r7  -> job workspace
;
; Output and 8BPP strip for the current device, this is done by converting
; the data from the 8BPP data to the 1BPP data suitable for printing via
; the monochrome output routines
;
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

output_grey_sprite ROUT

        Push    "R0-R2,R4,R6-R8,LR"

        Debug   Dump,"Converting to monochrome"
        Debuga  Dump,"At",R0
        Debuga  Dump,", Width",R3
        Debuga  Dump,", Height",R4
        Debuga  Dump,", Byte width",R5
        Debug   Dump,", Workspace at",R7

        MOV     R1,R0           ;->Scan line to convert
        MOV     R2,#1:SHL:7     ;Bit to modify in source data
10
        Push    "R1,R3-R5"      ;Store the byte width of the line

;we know width is a multiple of 8, so gulp 8 pixels at a time
15
        SUBS    R3,R3,#8
        BLT     %FT20
        LDMIA   R1!,{R6,R7}     ;next 8 pixels
        ORRS    R4,R6,R7        ;all white?
        STREQB  R4,[R0],#1
        BEQ     %BT15           ;fast route if so
        MOV     R4,#0
        TST     R6,#1:SHL:3     ;K bit of 1st pixel
        ORRNE   R4,R4,#1:SHL:7
        TST     R6,#1:SHL:11    ;K bit of 2nd pixel
        ORRNE   R4,R4,#1:SHL:6
        TST     R6,#1:SHL:19
        ORRNE   R4,R4,#1:SHL:5
        TST     R6,#1:SHL:27
        ORRNE   R4,R4,#1:SHL:4
        TST     R7,#1:SHL:3
        ORRNE   R4,R4,#1:SHL:3
        TST     R7,#1:SHL:11
        ORRNE   R4,R4,#1:SHL:2
        TST     R7,#1:SHL:19
        ORRNE   R4,R4,#1:SHL:1
        TST     R7,#1:SHL:27
        ORRNE   R4,R4,#1:SHL:0
        STRB    R4,[R0],#1
        B       %BT15

20
        ADD     R0,R0,#3
        BIC     R0,R0,#3        ;Align to a word boundary (nb - pad bytes contain junk!)

        Pull    "R1,R3-R5"
        ADD     R1,R1,R5        ;Adjust the line pointer
        SUBS    R4,R4,#1
        BGT     %BT10           ;Loop back until all bits tested

        ADD     R3,R3,#7
        MOV     R3,R3,LSR #3    ;Ensure a nice byte width of the scan
        ADD     R5,R3,#3
        BIC     R5,R5,#3        ;Word align the width of the strip

        Pull    "R0-R2,R4,R6-R8,LR"
        B       output_mono_altentry

;..............................................................................

        END