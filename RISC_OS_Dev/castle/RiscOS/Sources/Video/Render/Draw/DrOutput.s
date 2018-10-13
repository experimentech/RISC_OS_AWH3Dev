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
; > DrawMod.sources.DrOutput

;----------------------------------------------------------------------------
;
; The Draw output routines
;
;----------------------------------------------------------------------------

; *********************************
; ***  CHANGE LIST AND HISTORY  ***
; *********************************
;
; 16-Jun-94   AMcC  Replaced ScratchSpaceSize with ?ScratchSpace
;

; My own debugging flags

                GBLL    mydebug
mydebug         SETL    {FALSE} :LAND: BeingDeveloped

                GBLL    debug_clipping
debug_clipping         SETL    {FALSE} :LAND: BeingDeveloped
                GBLL    debug_clipping_buffer
debug_clipping_buffer  SETL    {FALSE} :LAND: BeingDeveloped
                GBLL    debug_clipping_mask
debug_clipping_mask    SETL    {FALSE} :LAND: BeingDeveloped

                GBLL    debug_clipping2
debug_clipping2 SETL    {FALSE} :LAND: BeingDeveloped

                GBLL    fulltrace
fulltrace       SETL    {FALSE} :LAND: BeingDeveloped

; Output path in situ
; ===================
;   Assumes this facility will not be abused (vetted by processpath).

out_replace
        CLRV
        MOV     oldX,newX               ;Update current point
        MOV     oldY,newY
        LDR     outptr,inputptr         ;-> just beyond last element read
        ADD     PC,PC,type,LSL #2       ;Safe, as type known to be in range
        MOV     PC,#0                   ;Should never happen!
        Return                          ;endpathET - finished
        Return                          ;startpathET - no initialisation
        B       out_replace_onepoint    ;movetoET - output one point
        B       out_replace_onepoint    ;specialmovetoET - output one point
        B       out_replace_nopoints    ;closewithgapET - output type only
        B       out_replace_nopoints    ;closewithlineET - output type only
        B       out_replace_threepoints ;beziertoET - output three points
        NOP                             ;gaptoET - fall through, output point
out_replace_onepoint                    ;linetoET - output one point
        STMDB   outptr!,{newX,newY}
out_replace_nopoints
        STRB    type,[outptr,#-4]!
        Return

out_replace_threepoints
        STMDB   outptr!,{cont1X,cont1Y,cont2X,cont2Y,newX,newY}
        STRB    type,[outptr,#-4]!
        Return

; Output by filling path normally
; ===============================
;
; This is done by constructing an edge table, then filling the result when
; the end of the path comes along.
;
; The edge table consists of one or more chunks of workspace, each one of
; size ScratchSpaceSize. The first chunk is ScratchSpace itself. The first
; word of each chunk is a link pointer to the next word. This is followed by
; up to "edgesinchunk" edges (and only the last chunk may contain less than
; "edgesinchunk" edges).
;
; Each edge contains 5 words, as follows:
;
;   Offset 0:  Flags: Not all of these are initially generated. Eventually,
;              they have the following meanings:
;                Bit 0 is set to the parity of the Y co-ordinate of the pixel
;                  associated with the low endpoint of the edge (this is used
;                  to detect cases where the edge does not contribute to
;                  winding numbers on its final scan line and ends outside a
;                  diamond).
;                Bit 1 is set when the algorithm has finished with the edge.
;                Bit 2 is set if the edge ends above the centre of its pixel
;                  and inside that pixel's diamond. (With the result that it
;                  does not contribute to winding numbers on its final scan
;                  line.)
;                Bit 3 is used internally to indicate that the edge does not
;                  cross the centre of the current scan line (and so does not
;                  contribute to winding numbers for this scan line).
;                Bit 4 is set if the edge is a "gap" - i.e. it does not
;                  contribute to boundary/non-boundary decisions.
;                Bits 28-29 contain the winding number change on going left
;                  to right through the edge (-1, 0 or 1).
;                Bits 30-31 contain direction of X movement (-1 or 1).
;   Offset 4:  X co-ordinate of lower endpoint (units 1/256 of a pixel).
;   Offset 8:  Y co-ordinate of lower endpoint (units 1/256 of a pixel).
;   Offset 12: X co-ordinate of upper endpoint (units 1/256 of a pixel).
;   Offset 16: Y co-ordinate of upper endpoint (units 1/256 of a pixel).
;
; This is always addressed via a pointer to the Y co-ordinate of the upper
; point - hence the following definitions.

chunksize               EQU     ?ScratchSpace
chunkheadersize         EQU     4
edgesize                EQU     20

edgepointeroffset       EQU     edgesize-4

usablechunksize         EQU     chunksize-chunkheadersize
edgesinchunk            EQU     usablechunksize/edgesize

firstedgeinchunk        EQU     chunkheadersize + edgepointeroffset

                        ^       -edgepointeroffset
lineflags               #       4
lowerX                  #       4
lowerY                  #       4
upperX                  #       4
upperY                  #       4

lf_parity       EQU     2_1
lf_done         EQU     2_10
lf_endshigh     EQU     2_100
lf_nocross      EQU     2_1000
lf_notbdry      EQU     2_10000

out_fill

        [       fulltrace
        Push    "R0-R11,LR"
        MOV     R3,#0
dumploop
        LDR     R0,[R13,R3]
        ADR     R1,dumpno
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     " "
dumpno
        DCB     "00000000",0
        ALIGN
        ADD     R3,R3,#4
        TST     R3,#15
        SWIEQ   OS_NewLine
        CMP     R3,#48
        BLO     dumploop
        SWI     OS_NewLine
        Pull    "R0-R11,LR"
        ]

        Push    "R11,LR"
        MOV     R11,#0                  ;Signal not a gap
        ADD     PC,PC,type,LSL #2       ;Split according to type
        MOV     PC,#0                   ;Should never happen
        B       out_fill_dofill         ;endpathET - do the fill
        B       out_fill_init           ;startpathET - initialise
        B       out_fill_subpathstart   ;movetoET - new subpath
        B       out_fill_subpathstart   ;specialmovetoET - new subpath
        MOV     R11,#lf_notbdry         ;closewithgapET - add gap edge
        B       out_fill_addedge        ;closewithlineET - add edge
        B       pathnotflat             ;beziertoET - error!
        MOV     R11,#lf_notbdry         ;gaptoET - add gap edge
out_fill_addedge                        ;linetoET - add edge
        Push    "newX,newY"
        ADR     t1,orgx                 ;Get graphics origin in t1,t2,
        LDMIA   t1,{t1,t2,R8,R14}       ;  xfactor in R8 and yfactor in R14
        ASSERT  (orgy=orgx+4):LAND:(xfactor=orgx+8):LAND:(yfactor=orgx+12)
        CMP     newY,oldY               ;Find upper end point
        CMPEQ   oldX,newX               ;Horizontal lines should go right
        ADDGE   t3,oldX,t1,LSL #coord_shift     ;Put origin-adjusted lower
        ADDGE   t4,oldY,t2,LSL #coord_shift     ;  point in t3,t4; origin-
        ADDGE   newX,newX,t1,LSL #coord_shift   ;  adjusted upper point in
        ADDGE   newY,newY,t2,LSL #coord_shift   ;  newX,newY
        ADDLT   t3,newX,t1,LSL #coord_shift     ;Ditto for other ordering
        ADDLT   t4,newY,t2,LSL #coord_shift
        ADDLT   newX,oldX,t1,LSL #coord_shift
        ADDLT   newY,oldY,t2,LSL #coord_shift
        MOV     t3,t3,ASR R8            ;Change units from fractions of OS
        MOV     t4,t4,ASR R14           ;  units to fractions of pixels
        MOV     newX,newX,ASR R8
        MOV     newY,newY,ASR R14
        LDR     t2,currentwinding       ;Produce correct left->right winding
        RSBGE   t2,t2,#0                ;  number change for this edge
        MOV     t2,t2,ASL #30           ;In correct two bits
        ORR     t2,R11,t2,LSR #2
        LDR     R14,changedboxaddr      ;Update bounding box if necessary
        LDR     R14,[R14]
        TST     R14,#1
        BLNE    out_fill_updatebox
        ADR     t1,brow                 ;Filter out edges totally above, to
        LDMIA   t1,{t1,R8,R14}          ;  right of or below graphics window
        ASSERT  (rcol=brow+4):LAND:(trow=brow+8)
        CMP     R8,t3,ASR #coord_shift          ;Note that all these
        CMPLT   R8,newX,ASR #coord_shift        ;  comparisons clear V, as
        BLT     out_fill_ignoreedge             ;  both operands must have
        CMP     t1,t4,ASR #coord_shift          ;  well under 30 significant
        CMPGT   t1,newY,ASR #coord_shift        ;  bits. So V is correct if
        BGT     out_fill_ignoreedge             ;  any of the branches is
        CMP     R14,t4,ASR #coord_shift         ;  taken.
        CMPLT   R14,newY,ASR #coord_shift
        BLT     out_fill_ignoreedge
        SUBS    outcnt,outcnt,#edgesize ;Check there's space. V cleared
        BLLO    out_fill_getmorespace   ;If not, try to get more space
        BVS     out_fill_errorfinish8   ;If error, correct stack & pass back
        STMIA   outptr!,{t2,t3,t4,newX,newY}    ;Store edge
        LDR     t1,edgecount            ;Count it
        ADD     t1,t1,#1
        STR     t1,edgecount
out_fill_ignoreedge                     ;V must be clear at this point
        Pull    "oldX,oldY,R11,PC"      ;Surreptitious move from newX/Y

out_fill_getmorespace
        Push    "R0,R2,R3,LR"
        MOV     R0,#ModHandReason_Claim ;Claim the new chunk of workspace
        LDR     R3,=?ScratchSpace
        SWI     XOS_Module
        Pull    "R1,R2,R3,PC",VS        ;If error, return without changing R0
        LDR     R14,workspacehead       ;If first extra chunk, record where
        TEQ     R14,#0                  ;  it is.
        STREQ   R2,workspacehead
        LDR     R14,currentchunk        ;Link the new chunk into the end of
        STR     R2,[R14]                ;  the chain (must be end rather than
        STR     R2,currentchunk         ;  start to make pointer table code
        MOV     R0,#0                   ;  below work).
        STMIA   R2!,{R0}
        MOV     outptr,R2
        LDR     outcnt,=usablechunksize-edgesize
                                        ;Set up size, excluding chunk header
                                        ;  and current edge
        Pull    "R0,R2,R3,PC"

out_fill_updatebox
        Push    "newX,newY,LR"
        MOV     newX,newX,ASR #coord_shift
        MOV     newY,newY,ASR #coord_shift
        BL      updatebox
        MOV     newX,t3,ASR #coord_shift
        MOV     newY,t4,ASR #coord_shift
        BL      updatebox
        Pull    "newX,newY,PC"

out_subpaths_subpathstart               ;Special out_subpaths entry point
        MOV     R14,#1
        STR     R14,gotasubpath

; Start a new subpath

out_fill_subpathstart
        SUBS    t1,type,#specialmovetoET        ;Create subpath's winding no.
        LDRNE   t1,userspacewinding             ;(0 if "non-winding" subpath)
        STR     t1,currentwinding               ;Store it
        MOV     oldX,newX                       ;Now just update registers
        MOV     oldY,newY                       ;  and return
        CLRV
        Pull    "R11,PC"

out_subpaths_subrinit                   ;Special out_subpaths entry points
        Push    "R11,LR"
out_subpaths_init
        MOV     R14,#0
        STR     R14,gotasubpath

; Start of path - do two things:
;   (a) Initialise workspace areas

out_fill_init
        ADR     outptr,ScratchSpace     ;Use ScratchSpace initially
        STR     outptr,currentchunk     ;ScratchSpace is the current chunk
        LDR     outcnt,=usablechunksize-edgesize
                                        ;Set up size, excluding chunk header
                                        ;  and dummy edge set up below
        MOV     t1,#0
        STMIA   outptr!,{t1}            ;Just ScratchSpace used so far
        MOV     t1,#1                   ;Initialise edge count - dummy
        STR     t1,edgecount            ;  edge will be in table

;   (b) Create a dummy edge that will prevent the filling routine
;       from falling off the start of the edge table.

        MOV     t3,#&80000000           ;Dummy edge as low as possible,
        MOV     t4,#&80000000           ;  because we plot downwards.
        [       FastEasyFills
        ADD     t4,t4,#pixelsize        ;Avoid being upset by subpixel
                                        ;  offsets
        ]
        STMIA   outptr!,{t2,t3,t4}      ;Store edge. Note (a) lineflags
        STMIA   outptr!,{t3,t4}         ;  irrelevant; (b) code space more
                                        ;  important than speed here.

; And return

        Pull    "R11,PC"

        LTORG

out_subpaths_subrdofill                 ;Special out_subpaths entry points
        Push    "R11,LR"
out_subpaths_dofill
        LDR     R14,gotasubpath
        TEQ     R14,#0
        Pull    "R11,PC",EQ

; All edges have been accumulated. Now do the fill.
;    Note R0-R8 are all free at present.
;
; We want to sort the edges by their top Y co-ordinate. To do
; this, we use OS_HeapSort on a table of pointers to the edges.
;   First, find space for the table of pointers.

out_fill_dofill
        LDR     R1,edgecount            ;Get space required
        CMP     outcnt,R1,LSL #2        ;Is there enough around at present?
        MOVHS   R2,outptr               ;If so, reserve it
        ADDHS   outptr,outptr,R1,LSL #2
        SUBHS   outcnt,outcnt,R1,LSL #2
        BHS     out_fill_gotpointers
        MOV     R0,#ModHandReason_Claim ;If not, go and claim enough
        MOV     R3,R1,LSL #2
        SWI     XOS_Module
        BVS     out_fill_errorfinish    ;Pass errors back to caller
        STR     R2,extrachunk           ;Record existence of claimed block
out_fill_gotpointers
        ADR     R14,outptrandcnt        ;Store details of remaining workspace
        STMIA   R14,{outptr,outcnt}
        STR     R2,pointers             ;Set up pointers start

; R0 and R3-R10 are free.
; R1 contains number of edges.
; R2 points to pointers table space.
; Now construct the pointers.

        ADR     R3,ScratchSpace         ;First chunk of edges
out_fill_nextchunk
        LDR     R0,=edgesinchunk        ;Number of edges before next chunk
        ADD     R4,R3,#firstedgeinchunk ;High Y of first edge in chunk
out_fill_savepointer
        STMIA   R2!,{R4}                ;Save pointer in table
        ADD     R4,R4,#edgesize         ;Advance one edge
        SUBS    R1,R1,#1                ;One edge less to do
        SUBNES  R0,R0,#1                ;One edge less in this chunk
        BNE     out_fill_savepointer    ;Loop if edge is where expected
        TEQ     R1,#0                   ;Any more edges to do?
        LDRNE   R3,[R3]                 ;If so, they're in next chunk, so
        BNE     out_fill_nextchunk      ;  move to next chunk and continue
        STR     R2,endpointers          ;Record end of pointer table
        STR     R2,endwaiting           ;Initialise other pointers needed
        STR     R2,startactive          ;  below

; Pointers table is now complete. Sort it.

        LDR     R0,edgecount            ;Number of entries to sort
        LDR     R1,pointers             ;Where the entries are
        MOV     R2,#3                   ;Sort as pointers to signed integers
        TST     R1,#7:SHL:29
        BNE     out_fill_sort32
        SWI     XOS_HeapSort
        B       out_fill_done_sort
out_fill_sort32
        MOV     R7,#0
        SWI     XOS_HeapSort32
out_fill_done_sort
        BVS     out_fill_errorfinish    ;Pass errors back to caller

; Modify the fill style, so that f_fullexterior still indicates whether
; non-boundary exterior pixels are plotted, but:
;
;   f_exteriorboundary indicates whether there is a difference between
;     plotting non-boundary and boundary exterior pixels.
;
;   f_interiorboundary indicates whether there is a difference between
;     plotting boundary exterior and boundary interior pixels.
;
;   f_fullinterior indicates whether there is a difference between
;     plotting boundary and non-boundary internal pixels.

        LDR     R0,flags
        AND     R14,R0,#f_fullexterior + f_exteriorbdry + f_interiorbdry
        EOR     R0,R0,R14,LSL #1
        ASSERT  f_exteriorbdry = f_fullexterior:SHL:1
        ASSERT  f_interiorbdry = f_exteriorbdry:SHL:1
        ASSERT  f_fullinterior = f_interiorbdry:SHL:1
        STR     R0,fillstyle

; We're now ready to start the main plotting loop. This scans pixel lines,
; from the top to the bottom of the graphics window. (This order is chosen
; because it reduces the chance of "tears" on the display as the shape is
; being plotted.)
;
; When an edge is activated, the format of its five word area changes, to
; the following:
;   Offset 0:  Flags as above, now fully generated.
;   Offset 4:  Target co-ordinate - an X co-ordinate if ABS(deltaX) >
;              ABS(deltaY), otherwise a Y co-ordinate.
;   Offset 8:  ABS(deltaX).
;   Offset 12: ABS(deltaY).
;   Offset 16: Pointer to end of second five word area (detailed below).
;
; Furthermore, a second five word area is generated for the line. This
; contains the following details:
;   Offset 0:  Bresenham control value for current pixel.
;   Offset 4:  X co-ordinate of current pixel. The current pixel is the first
;              pixel that will be plotted on the next scan line.
;   Offset 8:  Left end of boundary for current scan line.
;   Offset 12: Right end of boundary for current scan line.
;   Offset 16: First pixel on current scan line for which the winding number
;              change comes into effect. If there is no such pixel, this
;              contains &7FFFFFFF.
; This five word area is again pointed at via its last word.
;
; A modified Bresenham algorithm is used to keep track of the edges. Details
; of this are as follows:
;   We know that the edge is going downwards. We reverse the X co-ordinate
; if necessary to ensure that it is going rightwards. All references below to
; "left" and "right" refer to the situation after this possible reversal,
; unless otherwise stated.
;   Imagine a linear function defined on the plane to take values of 0 at
; the initial and final points (to subpixel accuracy) of the edge - this
; specifies the function up to multiplication by a constant. We can determine
; which side of the edge any given point is by looking at the sign of this
; function. Furthermore, given the value of the function at a given point, we
; can calculate the value of the function at a given displacement from this
; point by adding a constant times
;
;    (Ydisplacement * ABS(deltaX) + Xdisplacement * ABS(deltaY))
;
; to the given value. We choose the linear function such that this constant
; is -1: this means that the specified point lies below or to the left of the
; edge if the linear function is positive and above or to the right of the
; edge if it is negative. If the function turns out to be zero, this means
; that the point lies precisely on the edge. To avoid problems with this, we
; deem the edge to be positioned very slightly to the (real - i.e. not taking
; account of the reversal) right of and even more slightly above its real
; position. In practice, the way this is implemented is to take the value of
; the function at the edge's endpoints to be zero if deltaX is positive and
; -1 otherwise, and then treat zero as being positive.
;   We use the "inscribed diamond" criterion to choose which pixels are
; boundary pixels. Except in the end pixels of the edge, this merely requires
; us to check the value of the function at some of the corners of the
; diamond. To keep track of winding numbers, we need to examine the value of
; the function at the centre of the pixel. So we only need to look at the
; value of the function at half-pixel increments. Rather than continually
; shifting deltaX/Y left by coord_shift-1, we deal with this by shifting the
; function's value right by the same amount: the low order bits clearly make
; no difference to the decision as to which side of the edge the point is on,
; and can never be changed by a half pixel movement.
;   Things are a bit trickier for the first and last pixels of the edge, for
; which we have to work out whether they are included in the line. We have to
; use the full "inscribed diamond" criterion for these (attempts to avoid
; doing so will result in - among other things - surplus pixels being plotted
; in Bezier curves, with the problem getting worse as the flatness is
; decreased). If the endpoints lie inside a pixel's diamond, we treat them as
; belonging to that pixel. If they lie outside a pixel's diamond, we treat
; them as belonging to the next pixel up and to the left of them. (The point
; of this is to set up the current X and Y values as conveniently as
; possible.) Reasonably simple rules can then be used to find the exact end
; pixels of the edge.
;
; A certain amount of memory management has to be done while all this is
; going on. In general, the active edges are pointed to by the pointers
; between [startactive] and [endpointers], while edges awaiting activation
; are pointed to by the pointers between [pointers] and [endwaiting]. The
; active edges are shuffled up as edges become inactive.
;   A list of available 5 word areas is kept. Whenever one is needed, this
; list is used in the first place. If it is empty, another is generated from
; the unused workspace. If there is insufficient workspace, a new workspace
; chunk is claimed. When an edge is inactivated, both 5 word areas used by it
; are reclaimed.
;   Note that this list is chained in the same way as above - i.e. a pointer
; at the end of each area pointing at the end of the next area.
;
; An additional refinement is that the Bresenham value is held for the centre
; right point of the current pixel if the line's major direction is Y, and
; for the bottom centre point if the major direction is X.
;
; Use of registers throughout this loop:
;   R1 holds the current Y co-ordinate.

; Layouts of areas described above.

        ^       -edgepointeroffset
        #       4               ;(Still called lineflags)
target  #       4
deltaX  #       4
deltaY  #       4
linkptr #       4

        ^       -edgepointeroffset
bres    #       4
currX   #       4
leftX   #       4
rightX  #       4
crossX  #       4

        MOV     R14,#0          ;Initialise five word area list
        STR     R14,fivewordlist

        LDR     R1,trow         ;Initialise Y co-ordinate

        [       FastEasyFills
; If the fill style was &30-&33 (plot precisely the interior) or &0C-&0F
; (plot precisely the exterior), we can use much simpler code than general
; fill styles require, as we only need to calculate and work with crossing
; X on each scan line, not with left X and right X. The modified fill style
; can be tested for these cases very easily.

        AND     R0,R0,#f_exteriorbdry + f_interiorbdry + f_fullinterior
        TEQ     R0,#f_interiorbdry
        BEQ     out_qfill
        ]

out_fill_rowloop

        [       mydebug

        Push    "R0,R1,R2"
        MOV     R0,R1
        ADR     R1,%f90
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     12,"Scan line "
90
        DCB     "00000000",0
        ALIGN
        Pull    "R0,R1,R2"

        ]

; Advance each of the currently active edges, working out how they
; intersect this scan line.
;
; Use of registers:
;   R1 holds the current Y co-ordinate.
;   R10 points to start of list of active edges.
;   R11 points to current active edge.

        ADR     R14,startactive
        LDMIA   R14,{R10,R11}
        ASSERT  endpointers = startactive + 4
        CMP     R11,R10
        BLS     out_fill_possibleskip   ;Branch if no active edges
out_fill_advanceloop
        LDR     R9,[R11,#-4]!
        Push    "R10,R11"

        [       mydebug

        Push    "R0,R1,R2"
        LDR     R0,[R11]
        ADR     R1,%f90
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     13,10,"Advance edge at "
90
        DCB     "00000000",0
        ALIGN
        Pull    "R0,R1,R2"

        ]

; Set up for out_fill_doscan and call it.

        LDMDA   R9,{R0,R2,R3,R4,R5}
        ASSERT  lineflags = -16
        ASSERT  target = -12
        ASSERT  deltaX = -8
        ASSERT  deltaY = -4
        ASSERT  linkptr = 0
        ADD     R14,R5,#bres
        LDMIA   R14,{R6,R7}
        ASSERT  currX = bres + 4
        BL      out_fill_doscan

; Loop for next edge to advance.

        Pull    "R10,R11"
        CMP     R11,R10                 ;Advance to next active edge and loop
        BHI     out_fill_advanceloop
out_fill_advanceend

        [       mydebug

        Push    "R0,R1,R2"
        MOV     R0,R1
        ADR     R1,%f90
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     13,10,"Now scan line "
90
        DCB     "00000000",0
        ALIGN
        Pull    "R0,R1,R2"

        ]

; Activate any new edges and work out how they intersect this scan
; line. Note that the dummy edge put into the edge table means we don't
; have to check for overflowing the end of the table.
;
; Use of registers:
;   R0 holds current edge's flags.
;   R1 holds the current Y co-ordinate.
;   R3 holds ABS(deltaX).
;   R4 holds ABS(deltaY).
;   R5 holds lowerX.
;   R6 holds lowerY.
;   R7 holds upperX.
;   R8 holds upperY.
;   R9 points at edge currently being considered.
;   R10 points at pointer to edge currently being considered.
;   R11 points at first active edge pointer.

        LDR     R10,endwaiting          ;Note R11 is already set up correctly
out_fill_activateloop
        LDR     R9,[R10,#-4]!           ;Get edge pointer
        LDMDA   R9,{R0,R5-R8}           ;Get flags and co-ordinates
        ASSERT  lineflags = -16
        ASSERT  lowerX = -12
        ASSERT  lowerY = -8
        ASSERT  upperX = -4
        ASSERT  upperY = 0
        CMP     R1,R8,ASR #coord_shift  ;Does this edge need activating?
        BGT     out_fill_activateend    ;Finished activating edges if not

        [       mydebug

        Push    "R0,R1,R2"
        MOV     R0,R9
        ADR     R1,%f90
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     13,10,"Activate edge at "
90
        DCB     "00000000",0
        ALIGN
        Pull    "R0,R1,R2"

        ]

; Calculate ABS(deltaX) and ABS(deltaY).

        SUBS    R3,R7,R5
        RSBLT   R3,R3,#0
        SUB     R4,R8,R6                ;Must be correct sign

; Record direction of line as 1 or -1 in top two bits of flags

        ORR     R0,R0,#&40000000
        ORRGE   R0,R0,#&80000000        ;GE if line goes leftwards

; Now split lowerX/Y into pixel and subpixel components. The latter are
; put in R2 and R14. Subpixel X is reversed if line goes leftwards.

        AND     R2,R5,#subpixelmask
        MOV     R5,R5,ASR #coord_shift
        RSBGE   R2,R2,#pixelsize-1      ;Still GE if line goes leftwards
        AND     R14,R6,#subpixelmask
        MOV     R6,R6,ASR #coord_shift

; Change subpixel Y into distance from centre, then use this to discover
; whether lower end lies outside and to left of diamond. If so, shift one
; pixel to left.
;   Then, whether or not this shift occurs, change subpixel X into distance
; from right of pixel. Use this to discover whether lower end now lies
; outside the top right of the diamond. If so, shift one pixel upwards.

        SUB     R14,R14,#halfpixelsize  ;Change subpixel Y
        CMP     R2,R14                  ;Test whether outside upper left
        CMNGE   R2,R14                  ;If not, try lower left
        SUBLT   R5,R5,R0,ASR #30        ;If outside left, move X left; note
                                        ;  subpixel position is now distance
                                        ;  from right of pixel
        SUBGE   R2,R2,#pixelsize        ;Otherwise, shift to right of pixel
        CMN     R2,R14                  ;Test whether outside upper right
        ADDGE   R6,R6,#1                ;If so, move up one pixel and
        SUBGE   R14,R14,#pixelsize      ;  adjust subpixel position

; Now the endpoint either lies in a diamond or outside it to its lower right.
; This allows us to set the remaining two flags in R0 correctly, and also to
; set the target co-ordinate according to the magnitudes of deltaX and
; deltaY. Put target co-ordinate in R2.

        CMP     R14,#0                  ;Ends in upper half of diamond?
        ORRGE   R0,R0,#lf_endshigh      ;Set flag if so.
        TST     R6,#1                   ;Transfer Y parity to flags
        ORRNE   R0,R0,#lf_parity
        CMP     R4,R3                   ;Compare delta's
        MOVGE   R2,R6                   ;Set target accordingly
        MOVLT   R2,R5

; We're now ready to obtain the second control area for this edge. We want
; a pointer to it in R5 (lower endpoint is no longer needed).

        LDR     R5,fivewordlist         ;Is there one waiting around?
        TEQ     R5,#0
        LDRNE   R14,[R5,#linkptr]       ;If so, remove it from list
        STRNE   R14,fivewordlist
        BNE     out_fill_gotsecondarea
        Push    "outptr,outcnt"         ;If not, try to get it from
        ADR     R6,outptrandcnt         ;  remaining workspace
        LDMIA   R6,{outptr,outcnt}
        SUBS    outcnt,outcnt,#edgesize ;Check there's space. V cleared
        BLLO    out_fill_getmorespace   ;If not, try to get more space.
                                        ;Now VS <=> space claimed & failed
        ADDVC   R5,outptr,#edgepointeroffset    ;Point correctly at five word
                                                ;  area in workspace
        ADDVC   outptr,outptr,#edgesize
        STMVCIA R6,{outptr,outcnt}
        Pull    "outptr,outcnt"
        BVS     out_fill_errorfinish    ;Pass errors back, now stack correct
out_fill_gotsecondarea

; Now we're ready to store the first control area and add edge to active
; list.

        STMDA   R9,{R0,R2,R3,R4,R5}
        ASSERT  lineflags = -16
        ASSERT  target = -12
        ASSERT  deltaX = -8
        ASSERT  deltaY = -4
        ASSERT  linkptr = 0
        STR     R9,[R11,#-4]!

; Next, we must calculate values for the second control area. Time to give
; a new register usage, I think:
;
; Use of registers:
;   R0 holds current edge's flags.
;   R1 holds the current Y co-ordinate.
;   R2 holds the target co-ordinate.
;   R3 holds ABS(deltaX).
;   R4 holds ABS(deltaY).
;   R5 points to the edge's second control area.
;   R6 holds Bresenham value.
;   R7 holds upperX.
;   R8 holds upperY.
;   R9 points at edge currently being considered.
;   R10 points at pointer to edge currently being considered.
;   R11 points at first active edge pointer.

        Push    "R10,R11"

; Determine current pixel at upper endpoint by the same method as was used
; at the lower endpoint. First split into pixel and subpixel components -
; subpixel X in R10, subpixel Y in R11.

        AND     R10,R7,#subpixelmask
        MOV     R7,R7,ASR #coord_shift
        TEQ     R0,#0                   ;sets MI if line goes leftwards
        RSBMI   R10,R10,#pixelsize-1
        AND     R11,R8,#subpixelmask
        MOV     R8,R8,ASR #coord_shift

; As before, shift pixel if endpoint lies outside diamond, until it lies to
; the lower right of the pixel's diamond.

        SUB     R11,R11,#halfpixelsize  ;Offset subpixel Y to centre
        CMP     R10,R11                 ;Test whether outside upper left
        CMNGE   R10,R11                 ;If not, try lower left
        SUBLT   R7,R7,R0,ASR #30        ;If outside left, move X left; note
                                        ;  subpixel position is now distance
                                        ;  from right of pixel
        SUBGE   R10,R10,#pixelsize      ;Otherwise, shift to right of pixel
        CMN     R10,R11                 ;Test whether outside upper right
        ADDGE   R8,R8,#1                ;If so, move up one pixel and
        SUBGE   R11,R11,#pixelsize      ;  adjust subpixel position

; Now calculate Bresenham value at centre of current pixel, in R6. Note that
; for the purpose of correctly determining whether the endpoint lies inside
; its pixel's diamond, R10 has been deliberately made one too small if the
; line goes leftwards. This is corrected for here.
;   So we need to calculate 0 if line goes right or -1 if it goes leftwards,
; plus subpixel X from centre of pixel times ABS(deltaY), plus subpixel Y
; from centre of pixel times ABS(deltaX). Subpixel Y is already in the
; correct form, but subpixel X needs working on.
;   Double precision arithmetic will be needed during this calculation if
; pixelsize * ABS(deltaX) + pixelsize * ABS(deltaY) can exceed the signed
; integer range, i.e. if ABS(deltaX)+ABS(deltaY) >= &80000000/pixelsize.

        ADD     R14,R3,R4               ;ABS(deltaX)+ABS(deltaY)
        CMP     R14,#&80000000:SHR:coord_shift
        BLO     out_fill_spbres

out_fill_dpbres
        Push    "R0,R4,R5,R7"
        MOVS    R7,R0,ASR #32           ;Initialise R7 to 0 if line goes
                                        ;  right, -1 if left. Also set C if
                                        ;  and only if line goes left
        ADC     R0,R10,#halfpixelsize   ;Produce corrected subpixel X
        SSmultD R0,R4,R4,R5             ;subpixelX * ABS(deltaY) into R4,R5
        ADDS    R6,R4,R7                ;Accumulate into R6,R7
        ADC     R7,R5,R7
        MOV     R0,R11                  ;R11 not usable by arith_SSmultD
        SSmultD R0,R3,R4,R5             ;subpixelY * ABS(deltaX) into R4,R5
        ADDS    R6,R4,R6                ;Accumulate into R6,R7
        ADC     R7,R5,R7
        MOV     R6,R6,LSR #coord_shift-1        ;Change units to half pixels
        ORR     R6,R6,R7,LSL #33-coord_shift
        Pull    "R0,R4,R5,R7"
        B       out_fill_bresdone

out_fill_spbres
        MOVS    R6,R0,ASR #32           ;Initialise R6 to 0 if line goes
                                        ;  right, -1 if left. Also set C if
                                        ;  and only if line goes left
        ADC     R14,R10,#halfpixelsize  ;Produce corrected subpixel X
        MLA     R6,R14,R4,R6            ;Accumulate subpixelX * ABS(deltaY)
        MLA     R6,R11,R3,R6            ;Accumulate subpixelY * ABS(deltaX)
        MOV     R6,R6,ASR #coord_shift-1        ;Change units to half pixels

out_fill_bresdone

        CMP     R4,R3                   ;Offset Bresenham value according
        SUBGE   R6,R6,R4                ;  to major direction
        ADDLT   R6,R6,R3

; If pixel Y now lies above current Y, we need to advance the edge until we
; re-enter this scan line. This can happen in two ways:
;   (a) The edge started above the top line of the graphics window, and is
;       effectively being clipped.
;   (b) The edge started outside and above its pixel's diamond, and was
;       shifted up a pixel in the code above.
; Both cases need to be treated the same way - namely advance until we enter
; the current scan line, then generate data normally for the current scan
; line.

        [       FastYClipping

; If pixel Y is more than one greater than current Y, we are definitely in
; case (a) above, and will use some fast clipping code to get down to having
; pixel Y = current Y + 1.

        SUBS    R8,R8,R1
        BLE     out_fill_noclipping
        SUBS    R8,R8,#1
        BLGT    out_fill_fastclip

; Now we've just got to enter the current scan line

        CMP     R4,R3                   ;Split according to major co-ordinate
        BGE     out_fill_clippingY

out_fill_clippingX

        [       FastHorizEdges
; If the edge is horizontal and we've got here, we must be at the correct
; place already. We use this fact to avoid zero-division problems.

        TEQ     R4,#0
        BEQ     out_fill_clippingXloop
        CMP     R4,R6,ASR #FastHorizEdgeParam+1 ;Use fast code?
        BLLE    out_fill_fasthoriz
        ]

out_fill_clippingXloop

        CMP     R7,R2                   ;Target X reached?
        BEQ     out_fill_diesatonce     ;If so, edge dies without any effect
        ADD     R7,R7,R0,ASR #30        ;Otherwise, advance in X direction
        SUBS    R6,R6,R4,ASL #1         ;  and modify Bresenham value
        BGE     out_fill_clippingXloop  ;Loop if no scan line advance
        ADD     R6,R6,R3,ASL #1         ;Modify Bresenham value for Y move
        B       out_fill_activated      ;Branch to common code

out_fill_clippingY
        CMP     R1,R2                   ;Target Y reached?
        BLT     out_fill_diesatonce     ;If so, edge dies without any effect
        ADDS    R6,R6,R3,ASL #1         ;Modify Bresenham value for Y move
        ADDGE   R7,R7,R0,ASR #30        ;If an X move is needed, make the
        SUBGE   R6,R6,R4,ASL #1         ;  move and modify Bresenham value
        B       out_fill_activated      ;Branch to common code

out_fill_fastclip
        Push    "R1,R2,R7,LR"
        MOV     R7,R6,ASR #31           ;Sign extend Bresenham value
        MOV     R8,R8,ASL #1
        SSmultD R8,R3,R1,R2             ;2*(no. Y steps) * deltaX into R1,R2
        ADDS    R6,R6,R1                ;Accumulate into Bresenham value
        ADCS    R7,R7,R2
        MOVMI   R8,#0                   ;Check for still being to the right
        BMI     out_fill_fastclipdone   ;  of the edge
        BL      arith_DSdivS            ;Divide by deltaY - cannot be divide
        DCB     R6,R4,R8,0              ;  by zero or overflow because edges
                                        ;  above graphics window were
                                        ;  filtered out
        BIC     R8,R8,#1                ;Round odd results down
        CMP     R4,R3                   ;Adjust for varying offset position,
        ADDGE   R8,R8,#2                ;  according to major direction
        SSmultD R8,R4,R1,R2             ;2*(no. X steps) * deltaY into R1,R2
        SUB     R6,R6,R1                ;Not interested in high word!
out_fill_fastclipdone
        Pull    "R1,R2,R7"
        TEQ     R0,#0                   ;Move X co-ord. in right direction
        ADDPL   R7,R7,R8,ASR #1
        SUBMI   R7,R7,R8,ASR #1
        Pull    "PC"

        |

        CMP     R8,R1
        BLE     out_fill_noclipping
        CMP     R4,R3                   ;Split according to major co-ordinate
        BGE     out_fill_clippingY

out_fill_clippingX

        [       FastHorizEdges
; If the edge is horizontal and we've got here, we must be at the correct
; place already. We use this fact to avoid zero-division problems.

        TEQ     R4,#0
        BEQ     out_fill_clippingXloop
        CMP     R4,R6,ASR #FastHorizEdgeParam+1 ;Use fast code?
        BLLE    out_fill_fasthoriz
        ]

out_fill_clippingXloop
        CMP     R7,R2                   ;Target X reached?
        BEQ     out_fill_diesatonce     ;If so, edge dies without any effect
        ADD     R7,R7,R0,ASR #30        ;Otherwise, advance in X direction
        SUBS    R6,R6,R4,ASL #1         ;  and modify Bresenham value
        BGE     out_fill_clippingX      ;Loop if no scan line advance
        SUB     R8,R8,#1                ;Otherwise, go down
        ADD     R6,R6,R3,ASL #1         ;  and modify Bresenham value
        CMP     R8,R1                   ;Far enough down yet?
        BGT     out_fill_clippingXloop  ;Loop if not
        B       out_fill_activated      ;Branch to common code

out_fill_clippingY
        CMP     R1,R2                   ;Target Y reached?
        BLT     out_fill_diesatonce     ;If so, edge dies without any effect
out_fill_clippingYloop
        SUB     R8,R8,#1                ;Advance in Y direction
        ADDS    R6,R6,R3,ASL #1         ;  and modify Bresenham value
        ADDGE   R7,R7,R0,ASR #30        ;If an X move is needed, make the
        SUBGE   R6,R6,R4,ASL #1         ;  move and modify Bresenham value
        CMP     R8,R1                   ;Far enough down yet?
        BGT     out_fill_clippingYloop  ;Loop if not
        B       out_fill_activated      ;Branch to common code

        ]

        [       FastHorizEdges
; Subroutine to advance a long way horizontally by long division rather than
; repeated subtraction. Must not be called if R4 (= ABS(deltaY)) is zero.

out_fill_fasthoriz
        Push    "R14"
        MOV     R4,R4,ASL #1
        DivRem2 R10,R6,R4,R14           ;Divide Bresenham value by 2*deltaY
        MOV     R4,R4,ASR #1            ;  (note that result is <= &7FFFFFFF)
        TEQ     R0,#0                   ;Split according to whether edge
        BMI     out_fill_fasthorizleft  ;  goes left or right
out_fill_fasthorizright
        ADDS    R7,R7,R10               ;If right, move X position,
        MOVVS   R7,R2                   ;  avoiding overflow problems,
        CMP     R7,R2                   ;  and not going beyond target X
        MOVGT   R7,R2
        Pull    "PC"
out_fill_fasthorizleft
        SUBS    R7,R7,R10               ;Do similar things for left move
        MOVVS   R7,R2
        CMP     R7,R2
        MOVLT   R7,R2
        Pull    "PC"
        ]

out_fill_diesatonce
        ORR     R0,R0,#lf_done+lf_nocross       ;Signal line finished
        STR     R0,[R9,#lineflags]
out_fill_lineempty
        ADD     R6,R6,R3,ASL #1         ;Bresenham change for going down a
                                        ;  scan line. Irrelevant but harmless
                                        ;  if line is dying.
out_fill_lineemptyYdone
        MOV     R8,R7                   ;Make left and right X identical
        MOV     R10,R7
        MOV     R11,#&7FFFFFFF          ;And there is no crossing
        STMDA   R5,{R6,R7,R8,R10,R11}
        ASSERT  bres = -16
        ASSERT  currX = -12
        ASSERT  leftX = -8
        ASSERT  rightX = -4
        ASSERT  crossX = 0
        B       out_fill_fullyactivated

; Pixel Y and current Y are the same. Now we hope to do the scan line
; normally. This gets a bit complicated:
;   First, if the endpoint lies below the centre of the pixel, there is no
; crossing on this scan line.
;   Then if the endpoint lies inside the pixel's diamond, we can treat the
; scan line normally.
;   If the endpoint lies outside the pixel's diamond, we must split according
; to the major direction of the line:
;   (a) If the major direction is X, we advance one pixel in the X direction
;       and test if that pixel is included. If it is, we can work normally
;       from that pixel. If it isn't, this scan line is empty and the next
;       scan line starts from the new X value.
;   (b) If the major direction is Y, this scan line is definitely empty, and
;       we simply have to find the correct pixel on the next scan line.

out_fill_noclipping
        CMP     R11,#0                  ;Test if start below pixel centre
        ORRLT   R0,R0,#lf_nocross       ;Indicate no crossing if so
        CMP     R10,R11                 ;Test whether inside diamond
        BLT     out_fill_activated      ;Branch to common code if so
        CMP     R4,R3                   ;Split according to major direction
        BLT     out_fill_lowstartX

out_fill_lowstartY
        CMP     R1,R2                   ;Target Y reached?
        BEQ     out_fill_diesatonce     ;If so, line is finished.
        ADDS    R6,R6,R3,ASL #1         ;Go down a line
        ADDGE   R7,R7,R0,ASR #30        ;If X move required, advance X and
        SUBGE   R6,R6,R4,ASL #1         ;  adjust Bresenham value for move
        B       out_fill_lineemptyYdone ;Line is empty. Y move already done.

out_fill_lowstartX
        CMP     R7,R2                   ;Target X reached?
        BEQ     out_fill_diesatonce     ;If so, line is finished.
        ADD     R7,R7,R0,ASR #30        ;Advance X
        SUBS    R6,R6,R4,ASL #1         ;Adjust Bresenham value for X move
        BLT     out_fill_lineempty      ;Branch if edge leaves this scan line
                                        ;  without entering a diamond

; Now we are ready to process the scan line normally and loop

out_fill_activated
        BL      out_fill_doscan
out_fill_fullyactivated
        Pull    "R10,R11"
        B       out_fill_activateloop   ;And loop for another edge

out_fill_activateend
        ADD     R10,R10,#4              ;Replace non-activated edge
        ADR     R14,endwaiting
        STMIA   R14,{R10,R11}
        ASSERT  startactive = endwaiting + 4

; Plot appropriate parts of this scan line.
;
; First, we sort the active edges by their left X value. We use a bubble sort
; working upwards through the active edge pointers for this purpose. Reasons:
;
;   (a) There will usually be few active edges.
;   (b) Pointers to the active edges that have just been activated and which
;       are therefore likely to be moved a long way are at the bottom of the
;       list of active edge pointers.
;   (c) Pointers to active edges that have not just been activated will
;       already be in their correct order for the previous scan line. This is
;       unlikely to differ much from the order for this scan line.
;
; Use of registers:
;   R3 holds old active edge pointer.
;   R4 holds old left X value.
;   R5 holds new active edge pointer.
;   R6 holds new left X value.
;   R7 points to current position in list of active edge pointers.
;   R8 points to current bound to sort.
;   R9 points to new bound to sort.
;   R10 points to first active edge pointer.
;   R11 points beyond last active edge pointer.

        ADR     R14,startactive
        LDMIA   R14,{R10,R11}
        ASSERT  endpointers = startactive + 4
        CMP     R11,R10
        BLS     out_fill_sortend
        MOV     R9,R11
out_fill_sortpass
        SUB     R8,R9,#4
        MOV     R9,R10
        MOV     R7,R10
        CMP     R7,R8
        BHS     out_fill_sortend
        LDR     R3,[R7]
        LDR     R4,[R3,#linkptr]
        LDR     R4,[R4,#leftX]
out_fill_sortloop
        LDR     R5,[R7,#4]!
        LDR     R6,[R5,#linkptr]
        LDR     R6,[R6,#leftX]
        CMP     R4,R6
        STRLE   R3,[R7,#-4]
        MOVLE   R3,R5
        MOVLE   R4,R6
        STRGT   R5,[R7,#-4]
        MOVGT   R9,R7
        CMP     R7,R8
        BLO     out_fill_sortloop
        STR     R3,[R7]
        B       out_fill_sortpass

out_fill_sortend

; Now we are set to do the plotting. This is done by merging together
; adjacent pieces of boundary, then checking the point where we enter the
; merged piece of boundary, the various points within it where the edges
; cross the centre of the scan line and the point where we leave the boundary
; to see whether we change between plotting and not plotting.
;
; We distinguish two cases:
;
; (a) If interior boundary pixels are plotted the same way as exterior
;     boundary pixels, we know that the entire merged piece of boundary is
;     either plotted or not plotted. We can simply add up the winding number
;     changes without regard to their order or the places where they occur.
;     This is referred to below as the easy case.
;
; (b) If interior boundary pixels are plotted differently to exterior
;     boundary pixels, we have to look at each crossing in the correct
;     order. This is referred to below as the hard case. We use a set of
;     straightforward linear searches through the edges to do this: it will
;     be rare that there are many edges involved, so a more sophisticated
;     algorithm is not justified.
;
; Use of registers:
;   R0 contains the left end of the line segment to be plotted.
;   R1 contains the current Y co-ordinate.
;   R4 contains total winding number change in the merged piece of boundary.
;   R5 contains the fill style, in a modified form. We use the f_fullexterior
;      bit to indicate whether we are currently plotting.
;   R6 contains the current winding number.
;   R7 contains the left end of the merged piece of boundary.
;   R8 contains the right end of the merged piece of boundary.
;   R9 points to the first edge in the merged piece of boundary.
;   R10 points just beyond the last edge in the merged piece of boundary.
;   R11 points just beyond the last active edge.

        MOV     R0,#&80000000           ;Left end at "-infinity" if plotting
                                        ;  full exterior pixels
        LDR     R5,fillstyle            ;Pick up (modified) fill style
        MOV     R6,#0                   ;Winding number initially zero
                                        ;Note R10 and R11 already set up
out_fill_mergedboundaryloop
        CMP     R10,R11                 ;No more active edges?
        BHS     out_fill_finishscanline ;If not, go and finish this scan line
        MOV     R9,R10                  ;Otherwise, remember where start is

; Generate merged piece of boundary, counting winding number changes in the
; process.

        MOV     R7,#&7FFFFFFF           ;Initialise merged boundary ends
        MOV     R8,#&80000000
        MOV     R4,#0                   ;And winding number change
out_fill_mergeloop
        LDR     R14,[R10],#4            ;Get this active edge's leftX and
        LDR     R14,[R14,#linkptr]      ;  rightX
        ADD     R14,R14,#leftX
        LDMIA   R14,{R2,R3,R14}
        ASSERT  rightX = leftX + 4
        ASSERT  crossX = leftX + 8
        CMP     R2,R8                   ;If new leftX beyond current merged
        CMPGT   R2,R7                   ;  boundary, we've got all we want,
        SUBGT   R10,R10,#4              ;  so step back over unused edge
        BGT     out_fill_merged         ;  and exit merging loop
        CMP     R7,R2                   ;Update left end (only happens first
        MOVGT   R7,R2                   ;  time round)
        CMP     R8,R3                   ;Update right end (can happen every
        MOVLT   R8,R3                   ;  time)
        CMP     R14,#&7FFFFFFF          ;Check for no-crossing case
        LDRNE   R14,[R10,#-4]           ;If not, add in winding number change
        LDRNE   R14,[R14,#lineflags]
        MOVNE   R14,R14,ASL #2
        ADDNE   R4,R4,R14,ASR #30
        CMP     R10,R11                 ;If there is another edge,
        BLO     out_fill_mergeloop      ;  try to merge it as well

; We've now got the merged boundary segment. Check it against the graphics
; window. We've finished if it lies totally beyond the right hand side.

out_fill_merged
        LDR     R14,rcol
        CMP     R7,R14                  ;Beyond right hand side?
        BGT     out_fill_finishscanline ;If so, we're finished

; First deal with start of merged piece of boundary. Check whether we have
; to change our plotting state.

        TST     R5,#f_inside            ;Are we in the interior?
        MOVNE   R14,#f_fullinterior     ;Choose which flag to test
        MOVEQ   R14,#f_exteriorbdry     ;  accordingly
        TST     R5,R14                  ;If we do have to, deal with
        MOVNE   R2,R7                   ;  change at left end of merged
        BLNE    out_fill_plottingchange ;  boundary

; Decide whether to use the easy case code.

        TST     R5,#f_interiorbdry
        BEQ     out_fill_easycase

; This is the hard case. Next we have to deal with each of the crossings, in
; order of increasing crossX. This is done by simply scanning through the
; edges involved as many times as necessary, looking for the smallest crossX
; that has not been processed yet.
;   A possible future optimisation is to use a more sophisticated searching
; algorithm in the (rare) case of there being many edges involved in the
; merged piece of boundary.
;
; We use R7 to hold the point we've got up to, R2 to hold the lowest crossX
; value encountered, R3 to point to the current edge, R4 to hold the total
; change in winding number at the lowest crossX encountered.

out_fill_hardcase
        MOV     R3,R9                   ;Start at beginning of merged section
        MOV     R2,#&7FFFFFFE           ;Signal we haven't found anything yet
                                        ;  (Don't use &7FFFFFFF because it
                                        ;  will increase time spent on some
                                        ;  "non-winding" edges.)
out_fill_scanedges
        LDR     R14,[R3],#4             ;Advance to next edge, getting
        LDR     R14,[R14,#linkptr]      ;  crossX in the process.
        LDR     R14,[R14,#crossX]
        CMP     R14,R7                  ;Below where we are interested in?
        BLT     out_fill_uninteresting
        CMP     R2,R14                  ;Lower than current lowest crossX?
        MOVGT   R2,R14                  ;If so, change to this crossX and
        MOVGT   R4,#0                   ;  re-initialise winding no. change
        LDRGE   R14,[R3,#-4]            ;If lower or equal, get winding
        LDRGE   R14,[R14,#lineflags]    ;  number change for this edge and
        MOVGE   R14,R14,ASL #2          ;  add it into total
        ADDGE   R4,R4,R14,ASR #30
out_fill_uninteresting
        CMP     R3,R10                  ;Still in merged section?
        BLT     out_fill_scanedges      ;Loop if so
        CMP     R2,#&7FFFFFFE                   ;Did we find anything? If
        BEQ     out_fill_finishmergedsection    ;  not, rejoin with easy case
        ADD     R7,R2,#1                ;Restrict interesting area for next
                                        ;  iteration

; We now know there is a winding number change at the point indicated in R2.
; We need to know whether this actually corresponds to an inside/outside
; change. If it does, we call the "plotting state change" routine.
;   For details of the code to determine whether a particular winding number
; means inside or outside, see the comments in the easy case code below.

        ADD     R6,R6,R4
        MOVS    R14,R5,LSL #31          ;Sets Z for non-zero and even-odd
                                        ;  rules, C for even-odd and positive
                                        ;  only rules
        ASSERT  r_nonzero = 0
        ASSERT  r_negative = 1
        ASSERT  r_evenodd = 2
        ASSERT  r_positive = 3
        MOV     R14,R6
        RSBHI   R14,R14,#0              ;Done only if positive only rule!
        MOVNE   R14,R14,ASR #31
        ANDCS   R14,R14,#1
        TEQ     R14,#0                  ;Loop if exterior before and after
        TSTEQ   R5,#f_inside
        BEQ     out_fill_hardcase
        TEQ     R14,#0                  ;Loop if interior before and after,
        TSTNE   R5,#f_inside            ;  otherwise change plotting state,
        EOREQ   R5,R5,#f_inside         ;  call "plotting state change"
        BLEQ    out_fill_plottingchange ;  routine and loop
        B       out_fill_hardcase

out_fill_easycase

; Next change the winding number and re-determine whether we are inside or
; outside. This uses some tricky code, based on the following facts:
;
; For non-zero rule:
;
;   exterior  <=>  winding = 0
;
; For negative only rule:
;
;   exterior  <=>  ASR(winding, 31) = 0
;
; For even-odd rule:
;
;   exterior  <=>  winding AND 1 = 0
;
; For positive only rule:
;
;   exterior  <=>  ASR(-winding, 31) AND 1 = 0

        ADD     R6,R6,R4
        MOVS    R14,R5,LSL #31          ;Sets Z for non-zero and even-odd
                                        ;  rules, C for even-odd and positive
                                        ;  only rules
        ASSERT  r_nonzero = 0
        ASSERT  r_negative = 1
        ASSERT  r_evenodd = 2
        ASSERT  r_positive = 3
        MOV     R14,R6
        RSBHI   R14,R14,#0              ;Done only if positive only rule!
        MOVNE   R14,R14,ASR #31
        ANDCS   R14,R14,#1
        TEQ     R14,#0                  ;Now Z set <=> exterior
        BICEQ   R5,R5,#f_inside         ;Update flag
        ORRNE   R5,R5,#f_inside

; Now deal with end of merged piece of boundary. Check whether we have
; to change our plotting state.

out_fill_finishmergedsection
        TST     R5,#f_inside            ;Are we in the interior?
        MOVNE   R14,#f_fullinterior     ;Choose which flag to test
        MOVEQ   R14,#f_exteriorbdry     ;  accordingly
        TST     R5,R14                  ;If we do have to, deal with
        MOVNE   R2,R8                   ;  change at right end of merged
        BLNE    out_fill_plottingchange ;  boundary

        B       out_fill_mergedboundaryloop

        LTORG

; The following piece of code does a fast skip down the graphics window in
; the case that there are no active edges and the full exterior pixels are
; not being plotted.

out_fill_possibleskip
        LDR     R14,fillstyle           ;Check whether full exterior pixels
        TST     R14,#f_fullexterior     ;  are to be plotted - we cannot skip
        BNE     out_fill_advanceend     ;  fast if they are
        LDR     R14,endwaiting          ;If not, find out what the scan line
        LDR     R14,[R14,#-4]           ;  containing the upper end of the
        LDR     R14,[R14,#upperY]       ;  next edge is
        CMP     R1,R14,ASR #coord_shift ;Move down to it if it lies below our
        MOVGT   R1,R14,ASR #coord_shift ;  current scan line
        LDRGT   R14,brow                ;If this happened, check if finished
        CMPGT   R14,R1
        BLE     out_fill_advanceend     ;Re-enter loop if we didn't skip down
                                        ;  or if we did and stayed above the
                                        ;  bottom of the graphics window
        B       out_fill_finish         ;Otherwise, finalise and return

out_fill_finishscanline

; We want to finish the current segment if we're in "plotting" state. We
; do this by simply specifying that there is a change in state at +infinity.

        MOV     R2,#&7FFFFFFF
        BL      out_fill_plottingchange

; Destroy any edges that have now finished.
;
; Use of registers:
;   R1 holds the current Y co-ordinate.
;   R8 contains current edge pointer.
;   R9 points to last active edge in new list.
;   R10 points to start of list of active edges.
;   R11 points to current active edge from old list.

        ADR     R14,startactive
        LDMIA   R14,{R10,R11}
        ASSERT  endpointers = startactive + 4
        CMP     R11,R10
        BLS     out_fill_destroyend     ;Branch if no active edges
        MOV     R9,R11
out_fill_destroyloop
        LDR     R8,[R11,#-4]!           ;Get next edge pointer
        LDR     R14,[R8,#lineflags]     ;Finished with this edge?
        TST     R14,#lf_done
        STREQ   R8,[R9,#-4]!            ;Store it in new list if not
        LDRNE   R14,fivewordlist        ;If so, chain both five word areas
        STRNE   R8,fivewordlist         ;  for the finished edge onto the
        LDRNE   R8,[R8,#linkptr]        ;  list of free five word areas
        STRNE   R14,[R8,#linkptr]

        [       mydebug

        BEQ     %f99
        Push    "R0,R1,R2"
        LDR     R0,[R11]
        ADR     R1,%f90
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     13,10,"Destroy edge at "
90
        DCB     "00000000",0
        ALIGN
        Pull    "R0,R1,R2"
99

        ]

        CMP     R11,R10                 ;And loop for further active edges
        BHI     out_fill_destroyloop
        STR     R9,startactive          ;Store new active edge list start
out_fill_destroyend

; And loop for next scan line if necessary.

        [       mydebug

        Push    "R0"
        SWI     OS_WriteS
        DCB     13,10,"Done.",0
        ALIGN
        SWI     OS_ReadC
        Pull    "R0"

        ]

        SUB     R1,R1,#1                ;Move down a row
        LDR     R14,brow                ;Off bottom of graphics window?
        CMP     R1,R14
        BGE     out_fill_rowloop        ;Loop if not

        GET     DrQFill.s

out_fill_finish
        BL      out_fill_finalise       ;Free all workspace
        Pull    "R11,PC"                ;And return

; The following code deals with errors in the above, making certain that
; everything is finalised correctly.

out_fill_errorfinish8
        ADD     R13,R13,#8              ;Correct stack and fall through to...
out_fill_errorfinish
        BL      out_fill_finalise       ;Free all workspace
        SETV                            ;There's definitely an error!
        Pull    "R11,PC"                ;And return

        LTORG

; Subroutine to free all workspace claimed by out_fill.
; Exits with R0,R1,R9-R13 preserved and V clear if no freeing error happens.
; Otherwise R0 points to error block and V is set.

out_fill_finalise
        Push    "R0,LR"
        BL      freeworkspace           ;Free all temporary workspace
        Pull    "R0,PC",VC
        Pull    "R1,PC"                 ;Avoid corrupting R0 on error

; Subroutine to process a scan line normally.
;
; Entry:  R0 holds flags.
;         R1 holds current Y.
;         R2 holds target X if ABS(deltaX) > ABS(deltaY), target Y otherwise.
;         R3 holds ABS(deltaX).
;         R4 holds ABS(deltaY).
;         R5 points to edge's second control area.
;         R6 holds Bresenham value.
;         R7 holds current X.
;         R9 points to edge's first control area.
;
; Exit:   R0 modified by having lf_done and lf_nocross set as appropriate.
;         R1-R5,R9 preserved.
;         R6,R7 updated to correct initial values for next scan line.
;         R8 holds left X.
;         R10 holds right X.
;         R11 holds crossing X.

out_fill_doscan
        MOV     R8,R7                   ;Initialise left X
        CMP     R4,R3                   ;Split according to major direction
        BLT     out_fill_doscanX

out_fill_doscanY
        ADD     R10,R7,R0,ASR #30       ;Generate right X
        CMN     R6,R4                   ;Shift crossing if pixel below edge
        MOVGE   R11,R10
        MOVLT   R11,R7
        ADDS    R6,R6,R3,ASL #1         ;Adjust Bresenham value for Y move
        MOVGE   R7,R10                  ;If X move required, make it
        SUBGE   R6,R6,R4,ASL #1         ;  and adjust Bresenham value for it
        CMP     R1,R2                   ;Target Y reached?
        BNE     out_fill_doscantidy     ;Go to common code if not

out_fill_doscanYdone
        TSTEQ   R0,#lf_endshigh         ;If so, there is no crossing if edge
        ORRNE   R0,R0,#lf_nocross       ;  ends inside high half of diamond
        ORR     R0,R0,#lf_done          ;And line is certainly done
        STR     R0,[R9,#lineflags]
        B       out_fill_doscantidy

out_fill_doscanXdone1
        ADD     R11,R7,R0,ASR #30       ;Set crossing X appropriately
out_fill_doscanXdone2                   ;Have reached target X. Edge is
                                        ;  certainly finished, but is there a
                                        ;  crossing on this final scan line?
        EOR     R10,R1,R0               ;If Y parity is wrong, there cannot
        ASSERT  lf_parity = 1           ;  be. If Y parity is right, we can
        ANDS    R10,R10,#1              ;  treat this the same way as above
        ADD     R10,R7,R0,ASR #30       ;Generate right X

        [       FastHorizEdges
        Pull    "R14"
        ]

        B       out_fill_doscanYdone    ;Branch; NE if certainly no crossing,
                                        ;  EQ if yet to be determined

out_fill_doscanX

        [       FastHorizEdges
        Push    "R14"
        TEQ     R4,#0                   ;Avoid zero-division problems (and do
        MOVEQ   R7,R2                   ;  horizontal edges very fast!)
        BEQ     out_fill_doscanXdone2   ;  (NB crossing X must be irrelevant)
        ]

        SUBS    R6,R6,R3                ;First loop will find crossing X, for
        BLT     out_fill_doscanXskip1   ;  which we need to look at the pixel
                                        ;  centre Bresenham value

        [       FastHorizEdges
        CMP     R4,R6,ASR #FastHorizEdgeParam+1 ;Use fast code?
        BLLE    out_fill_fasthoriz
        ]

out_fill_doscanXloop1
        CMP     R7,R2                   ;Target X reached?
        BEQ     out_fill_doscanXdone1   ;If so, finish appropriately
        ADD     R7,R7,R0,ASR #30        ;Advance X
        SUBS    R6,R6,R4,ASL #1         ;Adjust Bresenham value for X move
        BGE     out_fill_doscanXloop1   ;Loop if no scan line advance
out_fill_doscanXskip1
        MOV     R11,R7                  ;Save crossing X
        ADDS    R6,R6,R3                ;Second loop will find right X, so
        BLT     out_fill_doscanXskip2   ;  adjust Bresenham value back again

        [       FastHorizEdges
        CMP     R4,R6,ASR #FastHorizEdgeParam+1 ;Use fast code?
        BLLE    out_fill_fasthoriz
        ]

out_fill_doscanXloop2
        CMP     R7,R2                   ;Target X reached?
        BEQ     out_fill_doscanXdone2   ;If so, finish appropriately
        ADD     R7,R7,R0,ASR #30        ;Advance X
        SUBS    R6,R6,R4,ASL #1         ;Adjust Bresenham value for X move
        BGE     out_fill_doscanXloop2   ;Loop if no scan line advance
out_fill_doscanXskip2
        ADD     R6,R6,R3,ASL #1         ;Adjust Bresenham value for Y move
        MOV     R10,R7                  ;Set right X appropriately

        [       FastHorizEdges
        Pull    "R14"
        ]

out_fill_doscantidy
        TEQ     R0,#0                   ;Sets MI if edge goes leftwards
        EORMI   R8,R8,R10
        EORMI   R10,R10,R8
        EORMI   R8,R8,R10
        ADDMI   R8,R8,#1
        ADDMI   R10,R10,#1
        ADDMI   R11,R11,#1
        TST     R0,#lf_notbdry          ;Sets NE if edge is a "gap"
        MOVNE   R8,R11
        MOVNE   R10,R11
        TST     R0,#lf_nocross          ;Sets NE if there is no crossing
        MOVNE   R11,#&7FFFFFFF
        STMDA   R5,{R6,R7,R8,R10,R11}
        ASSERT  bres = -16
        ASSERT  currX = -12
        ASSERT  leftX = -8
        ASSERT  rightX = -4
        ASSERT  crossX = 0
        NoErrorReturn

; Subroutine to deal with a change in whether we are plotting or not.
;
; Entry:  R0 holds left end of line (if starting in "plotting" state).
;         R1 holds Y co-ordinate.
;         R2 holds point where change happens.
;         R5 holds modified fill style and other flags.
;
; Exit:   R0,R5 updated.
;         R2,R3 corrupt.
;         All other registers preserved.

out_fill_plottingchange
        TST     R5,#f_fullexterior      ;Are we in "plotting" state?
        EOR     R5,R5,#f_fullexterior   ;Change our state regardless
        MOVEQ   R0,R2                   ;If entering plotting state, set
                                        ;  left end of line
        CMPNE   R0,R2                   ;Return at once if entering
        MOVEQ   PC,LR                   ;  "plotting" state or if nothing
                                        ;  to plot
   [ ClippedFills
        TST     R5,#f_buffer :OR: f_mask
        BNE     out_fill_clippedchange
   ]

        SUB     R2,R2,#1                ;Do the plot, taking care about
                                        ;  HLINE's inclusive right ends (ours
                                        ;  are exclusive)

        [       BackgroundAvail
        LDR     R3,flags
        TST     R3,#usebackground
        MOVEQ   R3,#1                   ;Fill with foreground colour
        MOVNE   R3,#3                   ;  or background as required
        |
        MOV     R3,#1                   ;Fill with foreground colour
        ]

        [       mydebug

        Push    "R0,R1,R2,LR"
        ADR     R1,%f90
        MOV     R2,#5
        SWI     OS_ConvertHex4
        LDR     R0,[R13,#8]
        ADR     R1,%f91
        MOV     R2,#5
        SWI     OS_ConvertHex4
        MOV     R0,#" "
        STRB    R0,%f90+4
        SWI     OS_WriteS
        DCB     13,10,"Plot segment from "
90
        DCB     "0000 to "
91
        DCB     "0000",0
        ALIGN
        Pull    "R0,R1,R2,LR"

        ]

        LDR     PC,hline                ;Do HLINE and return


  [ ClippedFills
; Subroutine to remember scanline plotting 'chunks' for later masking
; OR to plot a scanline, masked using the clipping buffer we built up
;    previously
;
; Entry:  R0 holds left end of line (if starting in "plotting" state).
;         R1 holds Y co-ordinate.
;         R2 holds point where change happens.
;         R5 holds flags (f_buffer set if we're buffering,
;                         f_mask set if we're masking)
;
; Exit:   All registers preserved.

out_fill_clippedchange
         Push    "r0-r5,lr"
         TST     r5,#f_buffer
         BEQ     out_fill_clipped_mask
  [ debug_clipping
         SWI     &100+60
  ]
         LDR     r3,clipsize
         LDR     r4,clipused
         ADD     r14,r4,#3*4  ; 3 words per entry
         CMP     r14,r3
         BGT     %FT90
         STR     r14,clipused
10
         LDR     r5,clipagainst

        [       debug_clipping_buffer
        Push    "R0,R1,R2,LR"

        MOV     r0,r1

        SUB     sp,sp,#12
        MOV     r1,sp
        MOV     R2,#12
        SWI     OS_ConvertHex8
        SWI     XOS_WriteS
        = "Y = ",0
        ALIGN
        MOV     r0,sp
        SWI     XOS_Write0

        MOV     r0,r4

        MOV     r1,sp
        MOV     R2,#12
        SWI     OS_ConvertHex8
        SWI     XOS_WriteS
        = ", offset = ",0
        ALIGN
        MOV     r0,sp
        SWI     XOS_Write0

        SWI     XOS_NewLine
        ADD     sp,sp,#12
        Pull    "R0,R1,R2,LR"
        ]

         ADD     r5,r5,r4
         STMIA   r5,{r0,r1,r2}   ; store our clip block
         LDR     r5,clipcount
         ADD     r5,r5,#1
         STR     r5,clipcount
50
         Pull    "r0-r5,pc"
55
   [ debug_clipping_buffer
         SWI     &100+"!"
         ADD     r0,r0,#4
         SWI     XOS_Write0
   ]
         Pull    "r0-r5,pc"

; increase the size of the buffer
90
         TEQ     r3,#0
         MOVEQ   r0,#ModHandReason_Claim
         LDRNE   r2,clipagainst
         MOVNE   r0,#ModHandReason_ExtendBlock
         MOV     r3,#256
         SWI     XOS_Module
         BVS     %BT55
   [ debug_clipping_buffer
         SWI     &100+"+"
   ]
         STR     r2,clipagainst
         LDR     r3,clipsize
         ADD     r3,r3,#256
         STR     r3,clipsize
         ADD     r14,r4,#3*4
         STR     r14,clipused
   [       debug_clipping2
        Push    "R0,R1,R2,LR"

        MOV     r0,r4

        SUB     sp,sp,#12
        MOV     r1,sp
        MOV     R2,#12
        SWI     OS_ConvertHex8
        SWI     XOS_WriteS
        = "offset = ",0
        ALIGN
        MOV     r0,sp
        SWI     XOS_Write0

        SWI     XOS_NewLine
        ADD     sp,sp,#12
        Pull    "R0,R1,R2,LR"
   ]

         LDMIA   sp,{r0-r2}
         B       %BT10

;**** WARNING - SIMPLE CODE WARNING ******
; ok, this is the scarey one. Given that we don't know the line we'll be
; plotting next, we have to work out what to plot where from the mask
out_fill_clipped_mask
   [ debug_clipping_mask
         SWI     XOS_NewLine
   ]
         LDR     r5,clipagainst
         LDR     r4,clipused
         ADD     r4,r4,r5      ; after end of buffer
         B       %FT115
110
         ADD     r5,r5,#3*4
115
         CMP     r5,r4
         BHS     %BT50

         LDR     r3,[r5,#4]   ; get y

        [       debug_clipping_mask
        Push    "R0,R1,R2,LR"

        MOV     r0,r3

        SUB     sp,sp,#12
        MOV     r1,sp
        MOV     R2,#12
        SWI     OS_ConvertHex8
        SWI     XOS_WriteS
        = "Y = ",0
        ALIGN
        MOV     r0,sp
        SWI     XOS_Write0

        LDR     r0,[sp,#12+0*4]

        MOV     r1,sp
        MOV     R2,#12
        SWI     OS_ConvertHex8
        SWI     XOS_WriteS
        = ", ourY = ",0
        ALIGN

        MOV     r0,sp
        SWI     XOS_Write0
        SWI     XOS_NewLine
        ADD     sp,sp,#12
        Pull    "R0,R1,R2,LR"
        ]


         CMP     r3,r1
;          BLT     %BT50        ; > our y, so can't be in the list
         BNE     %BT110

    ; we've found one of the y positions
;          SWI     &100+63
         LDR     r3,[r5,#0]   ; get left of clipped path
         LDR     r14,[r5,#8]  ; get right of clipped path
         CMP     r3,r2
         BGT     %BT110       ; left> our right, so it's not useful to us
         CMP     r14,r0
         BLT     %BT110       ; right< our left, so it's not useful to us

    ; r0 = max (r0,r3)
         CMP     r3,r0
         MOVGT   r0,r3

    ; r2 = min (r2,r3)
         CMP     r14,r2
         MOVLT   r2,r14

        SUB     R2,R2,#1                ;Do the plot, taking care about
                                        ;  HLINE's inclusive right ends (ours
                                        ;  are exclusive)

    ; now set up the colours to use and plot it
        [       BackgroundAvail
        LDR     R3,flags
        TST     R3,#usebackground
        MOVEQ   R3,#1                   ;Fill with foreground colour
        MOVNE   R3,#3                   ;  or background as required
        |
        MOV     R3,#1                   ;Fill with foreground colour
        ]

         MOV     lr,pc
         LDR     pc,hline

         LDMIA   sp,{r0-r2}   ; restore our bounds for the next 'bit'
         B       %BT110
 ]


; Output by filling path subpath by subpath
; =========================================
;   This is very similar to out_fill, the only difference being that we
; plot and re-initialise whenever a new subpath is started.

out_subpaths

        [       fulltrace
        Push    "R0-R11,LR"
        MOV     R3,#0
dumploopS
        LDR     R0,[R13,R3]
        ADR     R1,dumpnoS
        MOV     R2,#9
        SWI     OS_ConvertHex8
        SWI     OS_WriteS
        DCB     " "
dumpnoS
        DCB     "00000000",0
        ALIGN
        ADD     R3,R3,#4
        TST     R3,#15
        SWIEQ   OS_NewLine
        CMP     R3,#48
        BLO     dumploopS
        SWI     OS_NewLine
        Pull    "R0-R11,LR"
        ]

        Push    "R11,LR"
        MOV     R11,#0                  ;Signal not a gap
        ADD     PC,PC,type,LSL #2       ;Split according to type
        MOV     PC,#0                   ;Should never happen
        B       out_subpaths_dofill     ;endpathET - do the fill
        B       out_subpaths_init       ;startpathET - initialise
        B       out_subpaths_newsubpath ;movetoET - new subpath
        B       out_subpaths_newsubpath ;specialmovetoET - new subpath
        MOV     R11,#lf_notbdry         ;closewithgapET - add gap edge
        B       out_subpaths_addedge    ;closewithlineET - add edge
        B       pathnotflat             ;beziertoET - error!
        MOV     R11,#lf_notbdry         ;gaptoET - add gap edge
out_subpaths_addedge                    ;linetoET - add edge
        MOV     R14,#1
        STR     R14,gotasubpath
        B       out_fill_addedge

out_subpaths_newsubpath
        Push    "newX,newY,type"
        BL      out_subpaths_subrdofill
        BLVC    out_subpaths_subrinit
        Pull    "newX,newY,type"
        BVC     out_subpaths_subpathstart
        Pull    "R11,PC"

; Count required length of output buffer
; ======================================

out_count
        MOV     oldX,newX               ;Update current point
        MOV     oldY,newY
        CMP     type,#startpathET       ;Do correct thing according to type
        ASSERT  endpathET = 0
        ASSERT  startpathET = 1
        MOVEQ   outcnt,#0               ;Initialise count if start of path
out_count_ldr
        LDRHI   outptr,[PC,type,LSL #2] ;Add correct length if not start or
        ADDHI   outcnt,outcnt,outptr    ;  end of path
        ADDLO   R0,outcnt,#8            ;Produce result if end of path
        Return                          ;Return in all cases
        ASSERT  . = out_count_ldr + 16
        DCD     12                      ;movetoET element length
        DCD     12                      ;specialmovetoET element length
        DCD     4                       ;closewithgapET element length
        DCD     4                       ;closewithlineET element length
        DCD     28                      ;beziertoET element length
        DCD     12                      ;gaptoET element length
        DCD     12                      ;linetoET element length

; Output bounding box of path
; ===========================

out_box
        Push    "newX,newY,LR"
        CMP     type,#startpathET       ;Note V is clear from here on
        ASSERT  endpathET = 0
        ASSERT  startpathET = 1
        BLO     out_box_returnresult
        BLEQ    initbox
        Pull    "oldX,oldY,PC",EQ
        BL      updatebox
        CMP     type,#beziertoET
        Pull    "oldX,oldY,PC",NE
        MOV     newX,cont1X
        MOV     newY,cont1Y
        BL      updatebox
        MOV     newX,cont2X
        MOV     newY,cont2Y
        BL      updatebox
        Pull    "oldX,oldY,PC"

out_box_returnresult
        ADR     R14,boundingbox
        LDMIA   R14,{t1,t2,t3,t4}
        LDR     R14,flags
        TST     R14,#f_r7isthirtytwobit
        LDR     R14,outputtype
        BICEQ   R14,R14,#&80000000      ; only zap flag in address if asked for
        STMIA   R14,{t1,t2,t3,t4}
        Pull    "oldX,oldY,PC"

; Subroutine to update this module's bounding box variable with the point
; held in newX,newY. Preserves R0-R13 and flags.

updatebox
        Push    "t1,t2,t3,t4,outcnt,LR"
        SavePSR outcnt
        ADR     R14,boundingbox
        LDMIA   R14,{t1,t2,t3,t4}
        CMP     t1,newX
        MOVGT   t1,newX
        CMP     t2,newY
        MOVGT   t2,newY
        CMP     t3,newX
        MOVLT   t3,newX
        CMP     t4,newY
        MOVLT   t4,newY
commonbox
        ADR     R14,boundingbox
        STMIA   R14,{t1,t2,t3,t4}
        RestPSR outcnt,,f
        Pull    "t1,t2,t3,t4,outcnt,PC"

; Subroutine to initialise this module's bounding box variable. Preserves
; R0-R13 and flags.

initbox
        Push    "t1,t2,t3,t4,outcnt,LR"
        SavePSR outcnt
        MOV     t1,#&7FFFFFFF
        MOV     t2,#&7FFFFFFF
        MOV     t3,#&80000000
        MOV     t4,#&80000000
        B       commonbox

; Subroutine to update the OS_ChangedBox variable from this module's bounding
; box variable. Preserves R0-R13.

updatechangedbox
        Push    "R0-R8,LR"
        ADR     R8,boundingbox
        LDMIA   R8,{R0-R3}
        ADR     R8,lcol
        LDMIA   R8,{R4-R7}
        ASSERT  brow = lcol+4
        ASSERT  rcol = lcol+8
        ASSERT  trow = lcol+12
        LDR     R8,flags
        TST     R8,#f_fullexterior      ;May have changed any pixel if we
        MOVNE   R0,#&80000000           ;  were plotting full exterior pixels
        MOVNE   R1,#&80000000
        MOVNE   R2,#&7FFFFFFF
        MOVNE   R3,#&7FFFFFFF
        CMP     R0,R4                   ;Intersect my bounding box and the
        MOVLT   R0,R4                   ;  graphics window
        CMP     R1,R5
        MOVLT   R1,R5
        CMP     R2,R6
        MOVGT   R2,R6
        CMP     R3,R7
        MOVGT   R3,R7
        CMP     R0,R2                   ;Anything changed? Return if not
        CMPLE   R1,R3
        Pull    "R0-R8,PC",GT
        LDR     R8,changedboxaddr       ;Produce union with OS's ChangedBox
        LDMIB   R8,{R4-R7}
        CMP     R4,R0
        MOVGT   R4,R0
        CMP     R5,R1
        MOVGT   R5,R1
        CMP     R6,R2
        MOVLT   R6,R2
        CMP     R7,R3
        MOVLT   R7,R3
        STMIB   R8,{R4-R7}
        Pull    "R0-R8,PC"

; Output to specified path
; ========================

out_path
        MOV     oldX,newX               ;Update current point
        MOV     oldY,newY
        ADD     PC,PC,type,LSL #2       ;Safe, as type known to be in range
        MOV     PC,#0                   ;Should never happen!
        B       out_path_endpath        ;endpathET - finish
        B       out_path_init           ;startpathET - initialise registers
        B       out_path_onepoint       ;movetoET - output one point
        B       out_path_onepoint       ;specialmovetoET - output one point
        B       out_path_nopoints       ;closewithgapET - output type only
        B       out_path_nopoints       ;closewithlineET - output type only
        B       out_path_threepoints    ;beziertoET - output three points
        NOP                             ;gaptoET - fall through, output point
out_path_onepoint                       ;linetoET - output one point
        SUBS    outcnt,outcnt,#12
        STMHSIA outptr!,{type}
        STMHSIA outptr!,{newX,newY}
        Return  HS
bufferfull
        ADR     R0,ErrorBlock_PathFull
        STMDB   sp!, {lr}
        BL      CopyError
        LDMIA   sp!, {lr}
        ErrorReturn

out_path_threepoints
        SUBS    outcnt,outcnt,#28
        STMHSIA outptr!,{type}
        STMHSIA outptr!,{cont1X,cont1Y,cont2X,cont2Y,newX,newY}
        Return  HS
        B       bufferfull

out_path_nopoints
        SUBS    outcnt,outcnt,#4
        STMHSIA outptr!,{type}
        Return  HS
        B       bufferfull

out_path_endpath
        STMIA   outptr,{type,outcnt}    ;Note there is always space
        MOV     R0,outptr               ;Suitable return value
        Return

out_path_init
        LDR     outptr,outputtype       ;Get output pointer
        LDR     outcnt,[outptr,#4]      ;  and output length
        Return

        MakeInternatErrorBlock  PathFull,,M07

pathnotflat
        ADR     R0,ErrorBlock_PathNotFlat
        BL      CopyError
        Pull    "R11,PC"

pathnotflat2
        ADR     R0,ErrorBlock_PathNotFlat
        B       errorandpullpc

        MakeInternatErrorBlock  PathNotFlat,,M08

        LNK     DrArith.s
