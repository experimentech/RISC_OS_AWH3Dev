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
; > StartPage

;..............................................................................
;
; call: StartPage_Code
;
; in:   r0   = copies to do
;       r1   = file handle
;       r2   = strip type
;       r3   = number of blank pixel rows before start of data
;       r4  -> our private pdumper word for job
;       r5   = job workspace
;       r6   = number of blank pixels before start of line
;       r7   = horizontal and vertical resolution packed into a single word.
;
; out:  V clear;
;         r0 = number of copies to be performed
;         r3 = number of blank pixel rows before start of of image
;
;       V set;
;         r0 -> error block.
;
; This routine is called at the start of the page.  The routine will allow
; the PDumper to setup the printer and skip to the correct print position,
; the driver is also passed the number of copies to be performed.  Both
; of these values can be modified.  The device is also passed the horizontal
; margin for its own reference, this cannot be modified and it is assumed
; that the dumping routine will pad the line start with null bytes.
;
; The number of copies when returned should be non-zero, but the vertical
; skip should just be be +VE.
;

StartPage_Colour256 ROUT
StartPage_Multi		ROUT
StartPage_16Bit		ROUT
StartPage_24Bit		ROUT

        Push    "R9,LR"
        MOV     R9,#"3"
        BL      StartPage_General
        Pull    "R9,PC"

StartPage_Monochrome ROUT
StartPage_Grey ROUT

        Push    "R9,LR"
        MOV     R9,#"1"
        BL      StartPage_General
        Pull    "R9,PC"

StartPage_General

        PDumper_Entry "R0-R2,R4,R6-R8"

        LDRB    R8,[R5,#pd_private_flags]
        TST     R8,#pdf_SupportsYOffset
        MOVNE   R8,#0                   ;supports Y Offset - zero the counter
        MOVEQ   R8,#&80000000           ;does not - set disable flag
        STR     R8,pending_blank_lines

        LDR     R8,[R5,#pd_linelength]
        Push    "R8"
        LDRB    R8,[R5,#pd_private_flags]

        ADD     R5,R5,#pd_data
        PDumper_AdjustFeed R6,R3,R5,R14

        STR     R1,FileHandle           ;Stash the stream handle
        PDumper_Reset

        [ PrefixWithZeroes
        Push    "R0, R2"
        MOV     R2, #1024 * 10   ; The HP driver sends 10K as the default
        MOV     R0, #0
5
        SWI     XOS_BPut
        BVS     %f6                ; defeatest approach. Error => stop trying
        SUBS    R2, R2, #1
        BNE     %b5
6
        Pull    "R0, R2"
        ]


; HzN
        ADRL    R2,StartFlag           ;If not first page of job skip some parts...
        LDRB    R4,[R2]
        CMP     R4,#0
        BNE     %F92
        MOV     R4,#"0"
        STRB    R4,[R2]
;       B       %F91

;HzN First page of a job: run with outputting all

91
        ADRL	R2,reset               ;Send the reset sequence
        PDumper_PrintCountedString R2,R4,LR

;       Duplex mode...: None, Short, Long, Rotating
        LDRB    R0,[R5,#pd_data_zero_skip] ; duplex flag is in here...
        ADD     R0,R5,R0                   ; go there
;       PDumper_PrintCountedString R0 would print it now... so I took the code from there

        LDRB    R2,[R0]                    ;Get the length of the string to print
        TEQ     R2, #0
        LDREQ   R2,[R0],#4
        MOVEQ   R2,R2,LSR#8                ;in both cases R2 is now the length
        ADDNE   R0, R0, #1
        LDREQ   R0, [R0]                   ;in both cases R0 now points to the string start
        
        TEQ     R2,#0                      ;Length = 0
        MOVEQ   R2,#"N"                    ;Nothing = No duplex
        LDRNEB  R2,[R0],#1                 ;Get the byte

        ADRL    R4,RotateMode
        MOV     R0,#0
        STRB    R0,[R4]                    ; rotate off by default...
        ADRL    R0,duplexNone              ; duplex off by default...
        TEQ     R2,#"S"
        ADREQL  R0,duplexShort             ; duplex short
        TEQ     R2,#"L"
        ADREQL  R0,duplexLong              ; duplex long
        TEQ     R2,#"R"
        ADREQL  R0,duplexShort             ; duplex rotating (based on duplex short)
        MOVEQ   R2,#"E"                    ; I start with an odd page (so I pretend the last one was even)
        STREQB  R2,[R4]                    ; rotate on (starting with non-rotated page)
        PDumper_PrintCountedString R0,R4,LR

; HzN Moved copies to here ...

        TST     R8,#pdf_MultiCopies     ;Does this printer support multiple copies?
        BEQ     %FT11

        Debug   StartPage,"Device supports multi-copy sequences"

        ADRL    R2,setcopies            ;Define the number of copies
        PDumper_PrintCountedString R2,R4,LR
; HzN RobStrings is not needed anymore
; [  RobStrings
        LDR     R0, [R13, #4]           ; recover copy count from TOS -4
; ]
        BL      print_number
        MOV     R0,#"X"
        PDumper_OutputReg R0            ;Terminate the escape sequence
11

      [ Module_Version >= 012
        BL      sendextra               ;Send contents of the extra escape sequence var
      ]

        ADRL    R0,reset2               ;Disable page skipping
        PDumper_PrintCountedString R0,R4,LR

        ADRL    R0,setdpi               ;Setup the resolution
        PDumper_PrintCountedString R0,R4,LR
        MOV     R4,R7,LSR #16
        BIC     R7,R7,R4,LSL #16        ;R4 =vertical, R7 =horizontal
        MOV     R0,R7
        BL      print_number            ;Output the horizontal resolution

        MOV     R0,#"R"                 ;Have to finish that string now
        PDumper_OutputReg R0            ;Because of new code!

;New section for outputing the StartPage code (normally null!)
        LDRB    R0,[R5,#pd_data_page_start]
        TEQ     R0,#0
        BEQ     %FT42
        ADD     R0,R5,R0
        PDumper_PrintCountedString R0,R2,LR  ;do need R5 now in fact
42

        B         %F93

; HzN further pages of a job: just computing positions (I tried without this and the driver hangs...)

92

        MOV     R4,R7,LSR #16
        BIC     R7,R7,R4,LSL #16        ;R4 =vertical, R7 =horizontal

;       B       %F93


; HzN: Common part from here on ...

93

;       Duplex mode...: None, Short, Long, Rotating
        ADRL    R2,RotateMode
        LDRB    R0,[R2]                    ; get rotate mode...
        TEQ     R0,#0                      ; off
        BEQ     %FT95                      ; yes, off

        CMP     R0,#"O"                    ; last page was odd?
        MOVEQ   R0,#"E"                    ; now I want it even
        MOVNE   R0,#"O"                    ; it's an odd page
        STRB    R0,[R2]                    ; save this info for the next page
        LDRNEB  R0,[R5,#pd_data_pass4_start]    ; Odd  page cmd
        LDREQB  R0,[R5,#pd_data_pass4_start_2]  ; Even page cmd
        TEQ     R0,#0
        BEQ     %FT95
        ADD     R0,R5,R0
        PDumper_PrintCountedString R0,R2,LR

95

        TST     R8,#pdf_DeciPoints
        ADREQL  R0,cursorpos             ;Define the cursor position
        ADRNEL  R0,dcursorpos            ;depends on positioning style

        PDumper_PrintCountedString R0,R2,R5

        TST     R8,#pdf_DeciPoints
        LDREQ   R2,=300
        LDRNE   R2,=720
        MUL     R3,R2,R3                ;vertical *pointsize
        DivRem  R0,R3,R4,LR             ;(vertical *pointsize)/vertical resolution
        BL      print_number

        TST     R8,#pdf_DeciPoints
        ADREQL  R3,cursorpos2           ;Set the horizontal one aswell
        ADRNEL  R3,dcursorpos2
        PDumper_PrintCountedString R3,R5,LR

        MUL     R6,R2,R6
        DivRem  R0,R6,R7,LR             ;(horizontal *pointsize)/horizontal resolution
        BL      print_number

        TST     R8,#pdf_DeciPoints
        ADREQL  R3,curposend            
        ADRNEL  R3,dcurposend
        PDumper_PrintCountedString R3,R5,LR
        
        TST     R8,#pdf_DeciPoints
        ADREQL  R0,graphicswidth        ;Set the width (depends on dpi?)
        ADRNEL  R0,dgraphicswidth
        PDumper_PrintCountedString R0,R4,R5

        Pull    "R0"
        BL      print_number            ;Picture width (pinched from job_ws)
        MOV     R0,#"s"
        PDumper_OutputReg R0

        TEQ     R9,#"1"                 ;SMC: If not a colour print job and not a colour printer then skip planes command.
        TSTEQ   R8,#pdf_SupportsColour
        ADREQL	R0,startgraphics2
        BEQ     %FT30

        [ FourPlanes
        TEQ     R9,#"1"                 ;Is this a colour dump?
        TSTNE   R8,#pdf_FourPlanes      ;Is is a four-plane device?
        BEQ     %FT20
        MOV     R9,#"-"
        PDumper_OutputReg R9
        MOV     R9,#"4"
20
        ]

        PDumper_OutputReg R9            ;Colour planes (entry R9="1" or "3")

        ADRL	R0,startgraphics        ;Put into a suitable graphics mode
30
        PDumper_PrintCountedString R0,R4,R5

        PDumper_EmptyBuffer             ;Flush buffer to the file

        MOV     R3,#0                   ;Vertical margin taken care of

        TST     R8,#pdf_MultiCopies
        MOVNE   LR,#1
        STRNE   LR,[SP]                 ;And store a suitable value to indicate copies handled by device


        PDumper_Exit

;HzN - the new flag for start of job
StartFlag       = 0                     ; set to 0 in start job, non zero else

; No more RobStrings flag
; [  RobStrings
reset           = 11,27,"%-12345X",27,"E"
; |
;reset           = 2,27,"E"
; ]

; HzN - some things for duplex printing
RotateMode      = 0                     ; 0 off, 'O' for odd pages, 'E' for even ones (to be rotated)
duplexNone      = 5,27,"&l0S"
duplexShort     = 5,27,"&l1S"
duplexLong      = 5,27,"&l2S"
;rotateOff       = 12,27,"&l-42u-396Z" ; Odd  pages not rotated
;rotateOdd       = 17,27,"&l0O",27,"&l-42u-396Z" ; Odd  pages not rotated
;rotateEven      = 17,27,"&l2O",27,"&l-42u+396Z" ; Even pages     rotated

reset2          = 5,27,"&l0L"
setcopies       = 3,27,"&l"
setdpi          = 3,27,"*t"

cursorpos       = 3,27,"*p"
cursorpos2      = 1,"y"
curposend       = 1,"X"
graphicswidth   = 3,27,"*r"

dcursorpos      = 3,27,"&a"             ; tc
dcursorpos2     = 1,"v"                 ; tc
dcurposend      = 1,"H"                 ; tc
dgraphicswidth  = 3,27,"*r"             ; tc

startgraphics   = 3,"u1A"               ; tc
startgraphics2  = 2,"1A"                ; SMC

        ALIGN

;..............................................................................

        GetIf   ^.Generic.SendExtra.s, Module_Version >= 012
$GetConditionally

;..............................................................................
;
; Output the number in R0 as an ASCII string.
;
; in    R0 number to send
; out   V =1 => R0 -> error block

print_number ROUT

        EntryS  "r0-r2", 8              ;Allow a maxmimum of eight characters

        ADD     R1,SP,#1
        MOV     R2,#8                   ;->buffer and its size
        SWI     XOS_BinaryToDecimal

        STRB    R2,[R1,#-1]!            ;Stash the sequence length before printing
        PDumper_PrintCountedString R1,R0,LR

        EXITS

        END

