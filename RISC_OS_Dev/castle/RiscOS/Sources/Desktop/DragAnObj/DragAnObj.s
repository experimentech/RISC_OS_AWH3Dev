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
; DragAnObject
;
; purpose: Drags arbirary objects using dragasprite
;
; author: N Kelleher
;
; history: 28-06-94  0.01  created from original prototype
;

        GET     hdr:ListOpts
        GET     hdr:Macros
        GET     hdr:System
        GET     hdr:ModHand
        GET     hdr:Services
        GET     hdr:Proc
        GET     hdr:Wimp
        GET     hdr:Sprite
        GET     hdr:DragASprit
        GET     hdr:MsgTrans
        GET     hdr:FSNumbers
        GET     hdr:NewErrors
        GET     hdr:OSRSI6
        GET     VersionASM

Flag_Function   *       1:SHL:16
Flag_SVC        *       1:SHL:17
Flag_User       *       1:SHL:18

;;-----------------------------------------------------------------------------
;; Define the workspace layout
;;-----------------------------------------------------------------------------


;; Our workspace (private word addresses)


MySWIBase       *       DragAnObjectSWI_Base

;;-----------------------------------------------------------------------------
;; Module header
;;-----------------------------------------------------------------------------

        AREA  |DragAnObj$$Code|, CODE, READONLY, PIC

module_base
        & 0                             ; not an application
        & 0
        & 0
        & 0

        & title -module_base
        & help -module_base
        & 0                             ; no commands
        & MySWIBase
        & swidecode - module_base
        & swinames - module_base
        & 0
  [ :LNOT: No32bitCode
        & 0
        & flags -module_base
  ]

help    = "Drag An Object",9,"$Module_HelpVersion",0
        ALIGN

;;-----------------------------------------------------------------------------
;;-----------------------------------------------------------------------------

        MACRO
        ReadModeVar     $n
        MOV     R0,#-1
        MOV     R1,#$n
        SWI     XOS_ReadModeVariable
        MEND


swidecode
        ; Fast dispatch as we only have two SWIs
        CMP     R11,#1
        BLO     SWIDragAnObjectStart
        Push    "lr"
        BHI     swidecode_badswi
        SWI     XDragASprite_Stop
        Pull    "pc"

swidecode_badswi
        ADR     r0, ErrorBlock_BadSWI
        MOV     r1, #0
        MOV     r2, #0
        MOV     r3, #0
        ADR     r4, title
        MOV     r5, #0
        MOV     r6, #0
        MOV     r7, #0
        SWI     XMessageTrans_ErrorLookup
        Pull    "pc"

ErrorNumber_BadSWI * &1E6
        MakeInternatErrorBlock BadSWI, noalign

title
swinames
        DCB     "DragAnObject",0
        DCB     "Start",0
        DCB     "Stop",0
        DCB     0
my_sp
        DCB     "0",0
        ALIGN

  [ :LNOT: No32bitCode
flags   DCD     ModuleFlag_32bit
  ]

; bbox
xmin    RN      R4
ymin    RN      R5
xmax    RN      R6
ymax    RN      R7


        ^ -12 ,R12
words   #       4
area1   #       4
area2   #       4

SWIDragAnObjectStart
        Entry   "R0-R10"                        ; SWI should preserve all registers unless error
        MOV     R12,R13
        MOV     R1,#0
        Push    "R1"                            ; our variables for memory storage
        Push    "R1"
        Push    "R1"

; R3 -> box we're going to drag
        LDMIA   R3,{xmin-ymax}

        MOV     R10,#0
        ADR     R1,area1                        ; init updates store
        BL      initarea

        MOV     R10,#1
        ADR     R1,area2
        BL      initarea

        LDR     R1,area2
        MOV     R2,#-1
        BL      setarea

        MOV     R2,#0
        LDR     R1,area1
        BL      setarea

        BL      output
        LDR     R1,area2
        BL      output

        LDR     R2,area1
        BL      writemask

        LDR     R2,area2                        ; no longer required
        MOV     R0,#ModHandReason_Free
        SWI     XOS_Module
        MOV     R0,#0
        STR     R0,area2

        LDR     R0,[R12, #Proc_RegOffset]
        LDR     R3,[R12, #Proc_RegOffset + 12]
        LDR     R4,[R12, #Proc_RegOffset + 16]
        LDR     R1,area1
        ADR     R2,my_sp

        MOV     R0,R0,LSL #16                   ; top 16 flags are reserved
        MOV     R0,R0,LSR #16                   ; for us; clear for DragASprite
        SWI     XDragASprite_Start

daoexit
        STRVS   R0,[R12]
        SavePSR R4                              ; preserve error condition

        LDR     R2,area1
        TEQ     R2,#0
        MOVNE   R0,#ModHandReason_Free
        SWINE   XOS_Module                      ; ignore errors as we're trying to free up memory

        LDR     R2,area2
        TEQ     R2,#0
        MOVNE   R0,#ModHandReason_Free
        SWINE   XOS_Module                      ; ignore errors as we're trying to free up memory

        MOV     R13,R12
        RestPSR R4,,f                           ; restore error condition
        NOP
        EXIT

initarea
; R1 -> sprite area
        Push    "R0-R3,lr"

        MOV     R0,#ModHandReason_Claim
        BL      workoutsize
        SWI     XOS_Module

        STRVC   R2,[R1]
        STRVC   R3,[R2,#saEnd]
        MOVVC   R0,#16
        STRVC   R0,[R2,#saFirst]
        LDRVC   R0,=SpriteReason_ClearSprites + 256
        MOVVC   R1,R2
        SWIVC   XOS_SpriteOp

        ADRVC   R2,my_sp
        LDRVC   R0,=SpriteReason_GetSpriteUserCoords + 256
        MOVVC   R3,#0                           ; no palette
        SWIVC   XOS_SpriteOp
        BVS     daoexit

        TEQ     R10,#1                           ; no mask required?

        ADRNE   R2,my_sp
        LDRNE   R0,=SpriteReason_CreateMask + 256
        SWINE   XOS_SpriteOp
        BVS     daoexit

        LDR     R0,[R1,#saEnd]                  ; shrink it down.
        LDR     R3,[R1,#saFree]
        SUB     R3,R3,R0

        MOV     R0,#ModHandReason_ExtendBlock
        MOV     R2,R1
        SWI     XOS_Module

        LDRVC   R0,[sp,#4]
        STRVC   R2,[R0]                         ; just in case its moved

        Pull    "R0-R3,PC"

        MACRO
$lab    spritedata      $area,$out,$end
$lab
        LDR     $out,[$area,#saFirst]
        ADD     $out,$out,$area                         ; pointer to first sprite
        LDR     R14,[$out,#spImage]
        LDR     $end,[$out,#spTrans]
        TEQ     $end,R14
        LDREQ   $end,[$out,#spNext]
        ADD     $end,$end,$out
        SUB     $end,$end,#4
        ADD     $out,$out,R14

        MEND

setarea
; R2 = value to set sprite words to
; R1 -> sprite area
        Push    "R0-R3,lr"
        spritedata      R1,R3,R0

05
        STR     R2,[R3],#4
        CMP     R3,R0
        BLE     %BT05

        Pull    "R0-R3,PC"

output
; R1 -> sprite area
        Push    "R0-R3,lr"

        ADR     R2,my_sp
        LDR     R0,=SpriteReason_SwitchOutputToSprite + 256
        MOV     R3,#0                                           ; no save area yet!
        SWI     XOS_SpriteOp
        BVS     daoexit

        BL      setupvduvars
        BL      render

        LDR     R0,=SpriteReason_SwitchOutputToSprite + 256     ; try and switch back
                                                                ; even if error?
        SWI     XOS_SpriteOp

        Pull    "R0-R3,PC"

setupvduvars
; after switching output to a sprite, the vdu 5 char size is reset to the kernel default
; the wimp expects differently! To get Wimp_PlotIcon to work properly this needs changing.
        Push    "R0-R3,lr"
; dodgy bit of code from the wimp sources (02)
; builds a VDU 23,17,7,flags,x;y;0,0     - see PRM 1-600
        ReadModeVar 4
        MOV     r3,r2
        ReadModeVar 5
        MOV     r1,#16

        MOV     r1,r1,ASR r3
        MOV     r3,#32 :SHL: 16
        ORR     r1,r1,r3, ASR r2                ; build up x;y;

        LDR     r0,hdrword
        MOV     r2,#0
        Push    "r0-r2"
        MOV     r0,sp
        MOV     r1,#10
        SWI     XOS_WriteN
        ADD     sp,sp,#12

        Pull    "R0-R3,PC"

; vdu 23 sequence
hdrword
        DCB     23,17,7,6

render
; R12 -> regs stacked up
;   R0 -> DAS flags except bit 16-18 give call information
;   R1 -> render func or SWI no.
;   R2 -> regs/params for call
; constructs SWI XXX Pull PC on stack
        Push    "R0-R10,lr"

        LDR     R0,[R12]
        TST     R0,#Flag_Function
        BNE     renderfunc

        LDR     R14,[R12,#8]
        LDMIA   R14,{R0-R9}
        LDR     R10,[R12,#4]
        SWI     XOS_CallASWI
        Pull    "R0-R10,PC"

; This was always somewhat broken. Stewart has "optimised" the code from
; its original form, not changing its broken meaning, which never matched
; the intent.
;
; Bit 17 clear was supposed to indicate "call me in user mode". What actually
; happened was R10 was set to 0, and you were called in SVC mode. This sort
; of worked, as long as you didn't call C library functions that cared about
; mode or accessed statics, and you didn't overflow your stack.
;
; But in a 32-bit system, R10 being 0 causes stack overflow errors, followed
; by aborts, as 0 looks higher than the SVC stack pointer.
;
; To fix at least this problem, R10 is now set to the hard bottom of the
; SVC stack for the "user mode" option. This will prevent overflow errors,
; and will cause aborts if anyone actually tries to get static relocation
; offsets. Otherwise we leave bit 17 as is, as who knows what potential
; clients may be doing, given our erratic behaviour. In particular a module
; client could conceivably be calling us with bit 17 clear.
;
; A new bit 18 now does a REAL call in user mode. User R10,R11,R13 are
; recovered from the SVC stack & banked registers and we switch to user mode.
; For this to work, whatever SWI veneer was used by the C program must have
; left R10 and R11 intact; _kernel_swi is fine, _swi was broken in RO 3.7
; but was fixed in the patches.
renderfunc
        TST     R0,#Flag_User
        BNE     renderuserfunc

        TST     R0,#Flag_SVC                                    ; Z set if notamod
        LDR     R14,[R12,#8]
        LDMIA   R14,{R0-R3}                                     ; only a1 - a4 under APCS

        Push    "R12"                                           ; APCS will trash this

        MOV     R10,sp, LSR #20                                 ; for stack limit checking
        MOV     R10,R10, LSL #20
        ADDNE   R10,R10,#540

        MOV     R14,PC
        LDR     PC,[R12,#4]
        Pull    "R12"
        Pull    "R0-R10,PC"

renderuserfunc
        MOV     R0,#6
        MOV     R1,#0
        MOV     R2,#OSRSI6_SVCSTK
        SWI     XOS_ReadSysInfo                                 ; Request SVC stack top
        MOVVS   R2,#&01C00000                                   ; If not available
        ADDVS   R2,R2,#&2000                                    ; assume old position
        SUB     R4,R2,#12                                       ; R4 -> user {R10,R11,R12}

        LDR     R5,[R12,#8]                                     ; R5 -> params

        Push    "R11-R12"                                       ; we'll trash these

        LDMIA   R4,{R10,R11}                                    ; restore user SL,FP

        SWI     XOS_LeaveOS                                     ; 32-bit systems use this
        TEQVSP  PC,#0                                           ; if it fails must be 26-bit

        LDMIA   R5,{R0-R3}                                      ; only a1 - a4 under APCS
        Push    "R14"                                           ; push user R14 onto user stack

        MOV     R14,PC
        LDR     PC,[R12,#4]                                     ; make the call

        Pull    "R14"                                           ; restore user R14

        SWI     XOS_EnterOS

        Pull    "R11-R12"
        Pull    "R0-R10,PC"

writemask
; R1,R2 -> sprite areas, update R2's mask
; can corrupt all regs
        Push    "R14"

        spritedata      R2,R4,R5
        spritedata      R1,R6,R0
        ADD     R8,R5,#4                                        ; mask is 4 bytes on.

        LDR     R14,[R2,#saFirst]
        ADD     R7,R2,R14
        LDR     R14,[R7,#spMode]
        CMP     R14,#256

        LDR     R14,[R7,#spWidth]
        ADD     R14,R14,#1
        STR     R14,words

        MOVLT   R7,#0                                           ; old or new style?

        MOV     R0,#-1
        MOV     R1,#9
        SWI     XOS_ReadModeVariable
; R2 has log2bpp

        MOV     R0,#1
        MOV     R2,R0, LSL R2
        MOV     R3,R0, LSL R2
        SUB     R3,R3,#1                                        ; R2 is amount to shift for each pixel
                                                                ; R3 is mask for each pixel

        TEQ     R7,#0
        BEQ     samedepth

onedeep
; the mask and sprite have different depths
        CMP     R4,R5
        Pull    "PC",GT

        LDR     R7,words
01
        MOV     R10,#1                                          ; mask shift
        MOV     R9,#0                                           ; mask to write
03
        MOV     R11,#0                                          ; data shift
        LDR     R0,[R4],#4
        LDR     R1,[R6],#4

05
        AND     R14,R0,R3
        TEQ     R14,#0
        ANDEQ   R14,R1,R3
        TEQEQ   R14,R3                                           ; if both equal, then we didn't write in here
        ORRNE   R9,R9, R10

        MOV     R0,R0, LSR R2
        MOV     R1,R1, LSR R2
        MOV     R10,R10,LSL #1

        TEQ     R10,#0
        STREQ   R9,[R8],#4

        ADD     R11,R11,R2
        TEQ     R11,#32
        BNE     %BT05                                           ; still processing word

        SUBS    R7,R7,#1
        TEQNE   R10,#0
        BNE     %BT03

        TEQ     R7,#0
        BNE     %BT01

        TEQ     R10,#0
        STRNE   R9,[R8],#4                                      ; wont have been stored

        B       onedeep

samedepth
; the mask and sprite have the same depth
        LDR     R0,[R4],#4
        LDR     R1,[R6],#4
        MOV     R10,#0                                          ; mask shift
        MOV     R9,#0                                           ; mask to write
05
        AND     R14,R0,R3
        AND     R7,R1,R3
        TEQ     R14,#0
        TEQEQ   R7,R3                                           ; if both equal, then we didn't write in here
        ORRNE   R9,R9,R3, LSL R10
        MOV     R0,R0, LSR R2
        MOV     R1,R1, LSR R2
        ADD     R10,R10,R2
        TEQ     R10,#32
        BNE     %BT05
        STR     R9,[R8],#4
        CMP     R4,R5
        BLE     samedepth

        Pull    "PC"

workoutsize
; xmin-ymax have size in OS units
; R10 says whether mask (ie 2x required)
; R3 out has memory required.
        Entry   "R0-R2,R4-R5"
        SUB     R4,xmax,xmin
        SUB     R3,ymax,ymin

        MOV     R0,#-1
        MOV     R1,#9
        SWI     XOS_ReadModeVariable
        BVS     daoexit
        MOV     R5,R2

        MOV     R1,#4
        SWI     XOS_ReadModeVariable
        BVS     daoexit
        MOV     R4,R4, LSR R2                   ; x pixels
        MOV     R4,R4, LSL R5                   ; x bits

        MOV     R1,#5
        SWI     XOS_ReadModeVariable
        BVS     daoexit
        MOV     R3,R3, LSR R2                   ; y pixels

        ADD     R4,R4,#127
        BIC     R4,R4,#63
        MOV     R4,R4, LSR #3                   ; bytes per line

        MLA     R3,R4,R3,R4

        ADD     R3,R3,#64                      ; sprite overhead + a bit

        TEQ     R10,#1
        ADDNE   R3,R3,R3

        ADD     R3,R3,#64                       ; CB overhead...

        EXIT

        END
