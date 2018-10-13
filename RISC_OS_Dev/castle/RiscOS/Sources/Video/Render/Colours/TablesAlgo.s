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

; Core algorithm for 16bpp-to-palette lookup table generation
; This is too big to fit in a macro, so as a workaround it's in its own file
; so it can get GET'd multiple times by Tables32K

; This is an implementation of the following algorithm:
;
; for(thiscolour)
; {
;     for(r,g,b)
;     {
;        myerror = abs(r-palette[thiscolour].r)
;                + abs(g-palette[thiscolour].g)
;                + abs(b-palette[thiscolour].b);
;        if (myerror < errorarray[r,g,b])
;        {
;           colourarray[r,g,b] = thiscolour;
;           errorarray[r,g,b] = myerror;
;        }
;     }
; }
;
; The previous version of this code used to calculate a fresh value of myerror
; for each iteration of the loop. However that's a bit wasteful, because the
; error will change in a very predictable way as we move through the colour
; space - it's quicker to calculate an initial error for the first entry and
; then update it using derivatives.
;
; The old code also used to use three registers to track the current red, green
; and blue values and then combine them into the colour value for each and
; every iteration. Again, this is wasteful; all we need to do is track the
; colour value and then check for when one component overflows into the next
; (as we need to detect when to apply different error derivatives)
;
; Instructions have also been interleaved where possible to help dual-issue on
; superscalar ARMs
;

  [ smallcache
; This version has been optimised for CPUs with small data caches, i.e.
; smaller than the combined colourarray & errorarray sizes. The loops have
; been rearranged to the following:
;
; for(b)
; {
;     for(thiscolour)
;     {
;         for(r,g)
;         {
;             ...
;         }
;     }
; }
;
; This allows colourarray to be processed in a series of chunks, each chunk
; small enough to fit in the cache. Additionally errorarray can be shrunk to
; the size of one chunk.
;
; Note that on machines with larger caches, or no cache at all, this version
; will hurt performance due to the palette being iterated more times
  ]

; Input regs:
;   palette = dest palette ptr
;   colourarray = dest array for storing lookup table
;   R11 = number of palette entries
;   errorarray = temp array for storing error values
; Input variables:
;   red_bits = number of bits of red bits in 16bpp pixel
;   green_bits = number of bits of blue bits
;   blue_bits = number of bits of green bits
;   red_shift = position of lowest red bit in palette entry
;   green_shift = position of lowest green bit
;   blue_shift = position of lowest blue bit
;
; Note that red/blue swapping can be performed by swapping red_shift and
; blue_shift 

        ; Some assumptions are made about the formats we'll be dealing with
        ASSERT  red_bits = blue_bits
        ASSERT  green_bits >= red_bits
        ASSERT  ((1<<green_bits)-1)*3 < 255
      [ :LNOT: :DEF: errshift
        GBLA    errshift
        GBLA    redmask
        GBLA    greenmask
        GBLA    bluemask
      ]
errshift SETA   $green_bits-$blue_bits       ; How much we need to shift red & blue errors
redmask SETA    (1<<red_bits)-1              ; Red mask in 16bpp pixel
greenmask SETA  ((1<<green_bits)-1)<<red_bits
bluemask SETA   ((1<<blue_bits)-1)<<(red_bits+green_bits)

      [ :LNOT: smallcache
        Push    "palette"                    ;save R9

        MOV     R2,#-1                       ;Set up the errorarray with the worst
        MOV     R3,R2                        ;possible result so that all entries
        MOV     R4,R2                        ;will get changed
        MOV     R5,R2
        MOV     R6,R2
        MOV     R7,R2
        MOV     R8,R2
        MOV     R9,R2
        ADD     R1,errorarray,#redmask+greenmask+bluemask+1 ;set up to word above top of array
15
        STMDB   R1!,{R2-R9}                  ;do 8 words at a time
        ;Debug   table32K,"Stored eight words at",R1
        CMP     R1,errorarray
        BHI     %BT15

        Pull    "palette"                    ;recover R9

        Push    "R11"                        ; stick the palette size on the stack, we ned the extra register
      |
        MOV     R2,#0
20
        MOV     R1,#-1
        MOV     R3,#-1
        MOV     R4,#-1
        MOV     R5,#-1
        ADD     R14,errorarray,#redmask+greenmask+1
21
        STMDB   R14!,{R1,R3-R5}              ;clear errorarray to max value
        CMP     R14,errorarray               ;ready for processing this chunk
        BHI     %BT21
      ]                
        MOV     thiscolour,#0                ; colour number being processed
      
25
        LDR     R1,[palette,thiscolour,LSL #2] ; fetch current palette entry

        ;do the indexing the quick and dirty way, ie *32 /256
        ;rather than *31 /255
      [ NoARMT2
        AND     R3,R1,#((1<<blue_bits)-1)<<blue_shift ;mask each down to five bits
        AND     R4,R1,#((1<<green_bits)-1)<<green_shift
        AND     R5,R1,#((1<<red_bits)-1)<<red_shift

        MOV     R3,R3,LSR #blue_shift        ; r3 = blue
        MOV     R4,R4,LSR #green_shift       ; r4 = green
        MOV     R5,R5,LSR #red_shift         ; r5 = red
      |
        UBFX    R3,R1,#blue_shift,#blue_bits   ; r3 = blue
        UBFX    R4,R1,#green_shift,#green_bits ; r4 = green
        UBFX    R5,R1,#red_shift,#red_bits     ; r4 = red
      ]

      [ :LNOT: smallcache
        MOV     R2, #0                       ; current table index
        
        ADD     R1, R4, R3, LSL #errshift
        ADD     R1, R1, R5, LSL #errshift    ; error of first table entry

        MOV     blueerrstep, #-1<<errshift   ; error will decrease as we get closer
      |
        SUBS    R1,R3,R2,LSR #red_bits+green_bits ; get blue error
        RSBLT   R1,R1,#0
        ADD     R1,R4,R1,LSL #errshift
        ADD     R1,R1,R5,LSL #errshift       ; error for start of this chunk
      ]
        MOV     greenerrstep, #-1
        MOV     rederrstep, #-1<<errshift
        
        ORR     R3,R5,R3,LSL #red_bits+green_bits
        ORR     R3,R3,R4,LSL #red_bits       ; index of R1 in colourarray

        ; Map colour R3 to palette entry R2. This is technically redundant,
        ; but is done to ensure a match with the behaviour of the original
        ; algorithm
      [ :LNOT: smallcache
        STRB    R2,[errorarray,R3]
        STRB    thiscolour,[colourarray,R3]
      |
        SUB     R14,R3,R2
        CMP     R14,#redmask+greenmask+1
        STRLOB  R2,[errorarray,R14]
        STRLOB  thiscolour,[colourarray,R3]
      ]

        ; Calculate the values used to rewind the error value once we wrap
        ; around off the end of the red or green channels.
        ; This is calculated as follows:
        ; * As we step through the red spectrum, the error value will decrease
        ;   R5 times and then increase (32-R5) times.
        ; * This is a net change of 32-2*R5 compared to the initial error
        ; * So to restore the original error value, add on -(32-2*R5)
        ; * Rearrange: -(32-2*R5) -> 2*R5-32 -> 2*(R5-16)
      [ errshift > 0
        MOV     R5, R5, LSL #errshift
      ]
        SUB     R4, R4, #(1<<(green_bits-1)) ; error rewind values
        SUB     R5, R5, #(1<<(green_bits-1))

35
      [ :LNOT: smallcache
        LDRB    R11,[errorarray],#1          ; fetch current error from there
        EOR     R14,R2,R3                    ; EOR to check if any components have hit colour R3 (and therefore if error steps need updating)
        CMP     R1,R11
      |
        LDRB    blueerrstep,[errorarray],#1  ; blueerrstep not needed, use it as temp isntead of R11
        EOR     R14,R2,R3
        CMP     R1,blueerrstep
      ]
        BGE     %FT36                        ; This branch makes a significant difference on some machines!
        STRB    R1,[errorarray,#-1]          ; update if necessary
        STRB    thiscolour,[colourarray,R2]
36
        TST     R14,#redmask                 ; red value matches?
        ADD     R2, R2, #1                   ; step table index
        MOVEQ   rederrstep, #1<<errshift     ; red error will increase
        TST     R2, #redmask                 ; red wrapped?
        ADD     R1, R1, rederrstep           ; adjust error
        BNE     %BT35
        ADD     R1, R1, R5, LSL #1           ; rewind red error
        TST     R14,#greenmask               ; green value matches?
        MOV     rederrstep, #-1<<errshift
        MOVEQ   greenerrstep, #1             ; green error will increase
        TST     R2, #greenmask               ; green wrapped?
        ADD     R1, R1, greenerrstep         ; adjust by green error
        BNE     %BT35

      [ :LNOT: smallcache
        ADD     R1, R1, R4, LSL #1           ; rewind green error
        TST     R14, #bluemask               ; blue value matches?
        MOV     greenerrstep, #-1
        MOVEQ   blueerrstep, #1<<errshift    ; blue error will increase
        TST     R2, #bluemask                ; blue wrapped?
        ADD     R1, R1, blueerrstep
        BNE     %BT35

        LDR     R11, [SP]                    ; recover palette size

        ADD     thiscolour,thiscolour,#1     ; next colour
        SUB     errorarray,errorarray,#redmask+greenmask+bluemask+1 ; rewind errorarray
        CMP     thiscolour,R11

        BCC     %BT25                        ; around again until we've done all colours

        Pull    "r11"
      |
        ADD     thiscolour,thiscolour,#1     ; next colour
        SUB     errorarray,errorarray,#redmask+greenmask+1 ; rewind errorarray
        CMP     thiscolour,R11

        SUBCC   R2,R2,#redmask+greenmask+1
        BCC     %BT25                        ; around again until we've done all colours

        TST     R2,#bluemask
        BNE     %BT20                        ; process the other chunks
      ]

        END
