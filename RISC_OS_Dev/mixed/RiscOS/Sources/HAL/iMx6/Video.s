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

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Machine.<Machine>
        GET     Hdr:ImageSize.<ImageSize>
        $GetIO
        GET     Hdr:Proc

        GET     Hdr:OSEntries
        GET     Hdr:HALEntries
        GET     Hdr:GraphicsV

        GET     hdr.iMx6q
        GET     hdr.iMx6qIRQs
        GET     hdr.StaticWS
        GET     hdr.PRCM
        GET     hdr.GPIO
        GET     hdr.CoPro15ops
        GET     hdr.Timers

        AREA    |Asm$$Code|, CODE, READONLY, PIC

 [ VideoInHAL
        EXPORT  Video_init
        EXPORT  HAL_VideoFlybackDevice
        EXPORT  HAL_VideoSetMode
        EXPORT  HAL_VideoWritePaletteEntry
        EXPORT  HAL_VideoWritePaletteEntries
        EXPORT  HAL_VideoReadPaletteEntry
        EXPORT  HAL_VideoSetInterlace
        EXPORT  HAL_VideoSetBlank
        EXPORT  HAL_VideoSetPowerSave
        EXPORT  HAL_VideoUpdatePointer
        EXPORT  HAL_VideoSetDAG
        EXPORT  HAL_VideoVetMode
        EXPORT  HAL_VideoPixelFormats
        EXPORT  HAL_VideoFeatures
        EXPORT  HAL_VideoBufferAlignment
        EXPORT  HAL_VideoOutputFormat
        EXPORT  HAL_VideoFramestoreAddress
        EXPORT  HAL_VideoStartupMode
        EXPORT  HAL_VideoPixelFormatList
        IMPORT  HDMIAudio_Init
        IMPORT  HAL_CounterDelay
        IMPORT  vtophys
;        IMPORT  PrintInstance
 ]
        EXPORT  VideoDevice_Init


        EXPORT  udivide

        IMPORT  memcpy
 [ Debug
        IMPORT  DebugHALPrint
        IMPORT  DebugHALPrintReg
        IMPORT  DebugHALPrintByte
 ]

        MACRO
        CallOS  $entry
        ASSERT  $entry <= HighestOSEntry
        MOV     lr, pc
        LDR     pc, OSentries + 4*$entry
        MEND

 [ VideoInHAL
        ; Allow disable of hardware pointer for testing
        GBLL    HardwarePointer
HardwarePointer SETL {TRUE}

; macro for bit writing in hdmi registers
        MACRO
        BitWriteByte $workreg, $bits, $mask, $baseaddr, $regoffset
        ldrb    $workreg,[$baseaddr,#$regoffset]
        bic     $workreg,$workreg,#$mask
        orr     $workreg,$workreg,#$bits
        strb    $workreg,[$baseaddr,#$regoffset]
        MEND


Video_init
        Entry    "v1"

        ldr     a1,IPU1_Log
        add     a1, a1, #IPU_IPU_CONF_OFFSET
; DebugReg a1,"startaddr "
        ldr     a2,=&802fffff        ; &802fffffreset all IPU memory regions
        str     a2, [a1, #IPU_IPU_MEM_RST_OFFSET-IPU_IPU_CONF_OFFSET]
11      ldr     a2, [a1, #IPU_IPU_MEM_RST_OFFSET-IPU_IPU_CONF_OFFSET]
        tst     a2, #1<<31
        bne     %bt11                  ; memory not yet cleared
        ldr     a1,IPU1_Log
        add     a1, a1, #IPU_IPU_CONF_OFFSET

; ldr a4, =&1f ;; 32byte
; ldr a3, =&01010101
; add   a1, a1, #&120000
; add a2, a1, #&400
; mov      v1, #0
;1 str v1, [a1], #4
;;  tst a1, a4
;  adds v1, v1, a3
;  movcs v1, #0
;  cmp a1, a2
; blt %bt1

        ; Set ScrInit to a safe value until we get told the real location
        mov     a1, #&10000000
        str     a1, ScrInit

 [ HardwarePointer
        ; Allocate some memory for the pointer image
        ldr     a1, NCNBAllocNext
        ;DebugReg a1, "PointerLog "
        str     a1, PointerLog
        add     a2, a1, #HW_CURSOR_WIDTH*HW_CURSOR_HEIGHT*4
        str     a2, NCNBAllocNext
        bl      vtophys
        str     a1, PointerPhys
        ;DebugReg a1, "PointerPhys "
 ]

        ldr     a2, HDMI_Log
        adrl    a1, modedefv3
        bl      LoadVideoModeFromV3

        bl      InitVideoMode

        bl      HDMIAudio_Init          ; lets try to start HDMI based audio

        EXIT

HAL_VideoSetDAG
        Entry
        ;DebugReg a1, "SetDAG "
        ;DebugReg a2, "addr "
        CMP     a1, #GVDAG_VInit
        STREQ   a2, ScrInit
        moveq   a1, a2, lsr #3          ; physical address/8
        ldreq   a3, =CP_EAB0
        ldreq   a4, IPU1_Log
        addeq   a4, a4, #IPU_MEMORY_OFFSET
        addeq   a4, a4, #23*&40
        bleq    IPU_CPMem_Write

        EXIT

; set DPMS style blanking on or off
; a1 = 1 for display normal, 0 for display blank
; a2 = 0..3 DPMS_State from mdf.
; 0 = no powersaving...
; 1 = standby
; 2 = suspend
; 3 = poweroff
HAL_VideoSetBlank
        Entry   "a2-a4"
        teq     a1, #0
        ldr     a1, =&801f0000          ; clear the power on bit if off needed
        bicne   a1, a1, #&00100000
        bl      HDMI_PhyI2cWrite
        MOV     a1, #0
        EXIT


; Stubs for unused HAL functions

HAL_VideoOutputFormat
HAL_VideoSetInterlace
HAL_VideoSetPowerSave
HAL_VideoReadPaletteEntry
; mov a2,lr
; DebugTX "hal_Vunused"
; mov lr,a2
        MOV     r0, #0
        MOV     pc, lr

; a1 = type
;       0 = normal palette 256 colours
;       1 = border (index 0)
;       2 = pointer (index 1-3) . 0 assumed transparent
; a2 = pointer
; a3 = start index
; a4, if there = number of entries to write
; palette entry format BB GG RR SS
; to display riscos C256 correctly pallette needs to
; be BBGGRRSS  (31..0)
; so actions:
;
; 2: swap BB and GG
; video channel is BB GG RR aa

HAL_VideoWritePaletteEntry
        Entry   "a1,a2,a3,a4,v1,v2,v3"
        add     a2, sp, #1*4            ; a2 loc on stack
        mov     a4, #1
        b       %ft1
HAL_VideoWritePaletteEntries
        Entry   "a1,a2,a3,a4,v1,v2,v3"
1       cmp     a1, #1
        blt     normalpalette
        bgt     pointerpalette

        EXIT
normalpalette
        ldr     v1, IPU1_Log
        add     v1, v1, #IPU_LUT_BASE_ADDR
        ldr     v2, =&ffff0000
        add     v1, v1, a3, lsl #2      ; Convert to word offset
2       ldr     a3, [a2], #4
        and     lr,a3,#&ff000000        ;; get bb
        and     v3,a3,#&00ff0000        ; get gg
        bic     a3, a3, v2              ; clear their homes
        orr     a3, a3, lr, lsr#8
        orr     a3, a3, v3, lsl#8
        eor     a3, a3, #&ff            ; toggle alpha/supremacy bits
        str     a3, [v1], #4
        subs    a4, a4, #1
        bgt     %bt2
        EXIT

pointerpalette
        ADR     lr, PointerPal
        ADD     lr, lr, r2, LSL #2
        STRB    r0, PointerPalDirty
60
        LDR     r0, [r1], #4
        MOV     r0, r0, LSR #8
        ORR     r0, r0, #&ff000000
        STR     r0, [lr], #4
        SUBS    r3, r3, #1
        BNE     %BT60
        ; Ensure first entry is transparent (relied upon by UpdatePointer)
        STR     r3, PointerPal
        EXIT

;a1 = flags
;  bit 0: 1 = enable pointer
;  bit 1: 1 = pointer shape changed
;a2 = x
;a3 = y
;a4 -> pointershape (4 word)
;  width  (8)
;  height (8)
;  pad    (16)
;  buffer logical address (32)
;  buffer physical address (32)
; no return value
; assume ipu1
;
; The IPU makes implementing the pointer rather tricky:
; * We need to manually crop the overlay to the screen (not a big problem,
;    but...)
; * There's no easy way of updating an overlays parameters while it is enabled
;   (there are shadow versions of some registers, but not the IDMAC settings
;    held in CPMem)
; * Something (DMA FIFO?) seems to have great difficulty when the overlay
;   becomes very small
; * Enabling/disabling overlays can also result in glitches (either that or it
;   has to be done at a very precise time within the vsync period)
;
; Luckily we can update the buffer address and overlay X/Y pos without any
; difficulty. So instead of adjusting the overlay size when the pointer goes
; off-screen, we generate a new overlay image containing just the visible
; cursor pixels. And instead of disabling the overlay when we want to hide the
; pointer, we just fill it with the transparent colour.
HAL_VideoUpdatePointer
        Entry   "a1,v1-v5"
 [ HardwarePointer
        ; Default is to claim call (exit with a1 != 0)
        STR     pc, [sp]
        LDR     v1, IPU1_Log
        ADD     v1, v1, #IPU_DP_COM_CONF_SYNC_OFFSET
        ; Disable overlay if pointer is off
        TST     a1, #1
        LDR     lr, [v1]
        BEQ     %FT95
        ; Disable overlay if pointer is completely off-screen
        CMP     a2, #-HW_CURSOR_WIDTH
        CMPGT   a3, #-HW_CURSOR_HEIGHT
        BLE     %FT95
        LDR     v4, mwidth
        LDR     v5, mheight
        CMP     a2, v4
        CMPLT   a3, v5
        BGE     %FT95
        ; Work out overlay position
        MOVS    v2, a2
        MOVLT   v2, #0
        MOVS    v3, a3
        MOVLT   v3, #0
        SUB     v4, v4, #HW_CURSOR_WIDTH
        CMP     v2, v4
        MOVGT   v2, v4
        SUB     v5, v5, #HW_CURSOR_HEIGHT
        CMP     v3, v5
        MOVGT   v3, v5
        ; The position register only has 11 bits of precision for the X & Y
        ; coords. If the mode is larger than 2K in any dimension, then bad
        ; things happen if the pointer enters an area where the lower 11 bits
        ; of the screen pos can match the lower 11 bits of the pointer pos more
        ; than once per frame
        ; For this situation we disable the pointer and exit with the call
        ; unclaimed (a1=0)
        LDR     v4, mwidth
        ORR     v5, v2, #2048
        CMP     v5, v4 ; if (pos OR 2048) < screensize then we're in trouble
        LDRGE   v4, mheight
        ORRGE   v5, v3, #2048
        CMPGE   v5, v4
        MOVLT   a1, #0
        STRLT   a1, [sp]
        BLT     %FT95
        ; Get delta between actual pos and requested pos
        ; Should be from -31 to +31
        SUB     v4, a2, v2
        SUB     v5, a3, v3
        ; Enable overlay
        ORR     lr, lr, #1
        STR     lr, [v1]
        ; Update position
        LDR     lr, [v1, #IPU_DP_FG_POS_SYNC_OFFSET-IPU_DP_COM_CONF_SYNC_OFFSET]
        BFI     lr, v2, #16, #11
        BFI     lr, v3, #0, #11
        STR     lr, [v1, #IPU_DP_FG_POS_SYNC_OFFSET-IPU_DP_COM_CONF_SYNC_OFFSET]
        ; Update image if shape changed, palette changed, or delta changed
        LDRB    v1, PointerPalDirty
        LDR     v2, PointerX
        LDR     v3, PointerY
        TST     a1, #2 ; Shape updated?
        TEQEQ   v1, #0 ; Palette changed?
        TEQEQ   v2, v4 ; Delta changed?
        TEQEQ   v3, v5
        BEQ     %FT90
        MOV     v1, #0
        STRB    v1, PointerPalDirty
        STRB    v1, PointerDisabled
        STR     v4, PointerX
        STR     v5, PointerY
        LDR     a1, PointerLog
        ADR     a2, PointerPal
        LDRB    a3, [a4, #1] ; Get src height
        LDR     a4, [a4, #4] ; Get src image
        MOV     v2, #0 ; Current src Y
        ; a1 = dest addr
        ; a2 = palette
        ; a3 = src height
        ; a4 = src ptr
        ; v1 = temp
        ; v2 = src Y
        ; v3 = temp
        ; v4 = dest X
        ; v5 = dest Y
        ; Skip the first few rows if they're off the dest image
        CMP     v5, #0
        SUBLT   v2, v2, v5
        SUBLT   a4, a4, v5, LSL #HW_CURSOR_WIDTH_POW2-2
        MOVLTS  v5, #0
        ; Fill in first few rows with blank
        BEQ     %FT10
        MOV     v3, #0
        MOV     ip, #0
        ADD     lr, a1, v5, LSL #HW_CURSOR_WIDTH_POW2+2
05
        STMIA   a1!, {v3,ip}
        CMP     a1, lr
        BNE     %BT05
10
        ; Reached end of src image?
        CMP     v2, a3
        BGE     %FT50
        ; Fill in first few pixels with blank
        CMP     v4, #0
        BLE     %FT20
        LDR     v3, [a2]
        ADD     lr, a1, v4, LSL #2
15
        STR     v3, [a1], #4
        CMP     a1, lr
        BNE     %BT15
20
        LDR     lr, =&88888888 ; 32 pixels wide, load new src byte every 4th pixel
        ; Skip pixels which are off the left edge
        RSBS    ip, v4, #0
        ADDGT   a4, a4, ip, LSR #2
        LDRB    v3, [a4], #1
        BLE     %FT25
        MOV     lr, lr, LSR ip
        TST     ip, #1
        MOVNE   v3, v3, LSR #2
        TST     ip, #2
        MOVNE   v3, v3, LSR #4
        MOV     v4, #0
25
        ; Process one pixel
        CMP     v4, #HW_CURSOR_WIDTH
        ANDLO   ip, v3, #3
        LDRLO   ip, [a2, ip, LSL #2]
        STRLO   ip, [a1], #4
        MOV     v3, v3, LSR #2
        ; Advance coordinates
        ADD     v4, v4, #1
        MOVS    lr, lr, LSR #1
        LDRHIB  v3, [a4], #1
        ; Processing stops once we hit right edge of source
        BNE     %BT25
        ; Fill any remaining dest words with blank
        RSBS    lr, v4, #32
        BLE     %FT35
        MOV     v3, #0
30
        STR     v3, [a1], #4
        SUBS    lr, lr, #1
        BNE     %BT30
35
        ; Advance to next row
        SUB     v4, v4, #32
        ADD     v2, v2, #1
        ADD     v5, v5, #1
        ; End if reached end of dest image
        CMP     v5, #HW_CURSOR_HEIGHT
        BLT     %BT10
        EXIT

50
        ; Blank rows at end of image
        RSBS    v5, v5, #HW_CURSOR_HEIGHT
        BLE     %FT90
        ADD     lr, a1, v5, LSL #HW_CURSOR_WIDTH_POW2+2
        MOV     a2, #0
        MOV     a3, #0
        MOV     a4, #0
        MOV     v1, #0
55
        STMIA   a1!, {a2,a3,a4,v1}
        CMP     a1, lr
        BNE     %BT55
90
        EXIT

95
 [ {FALSE}
        ; Disable overlay
        BIC     lr, lr, #1
        STR     lr, [v1]
 |
        LDRB    a1, PointerDisabled
        TEQ     a1, #0
        BNE     %FT99
        ; Disable by filling the image with the transparent colour
        MOV     a1, #1
        STRB    a1, PointerDisabled
        STRB    a1, PointerPalDirty ; Ensure image is rebuilt when pointer next enabled
        MOV     v5, #0
        LDR     a1, PointerLog
        B       %BT50
99
 ]
 ] ; HardwarePointer
        EXIT





; on entry a1-> proposed vidc3 type 3 mode
; small changes allowed
; return a1=0 if mode acceptable, else return a1 =NZ
HAL_VideoVetMode
        Entry   "v1, v2, v3, v4"
        mvn     v1, #&ff
;        DebugReg a1, "Hal_VetMode a1: "
;        DebugReg v1, "Hal_VetMode mask: "
        tst     a1, v1          ; mode pointer or mode type
        bne     %ft1            ; pointer.. go past
        teq     a1, #27         ; let this through
        teqne   a1, #28         ; let this through
        teqne   a1, #31         ; let this through
        teqne   a1, #32         ; let this through
2       movne   a1, #1          ; nz exit to object
        EXIT    NE              ; we object to all other std mode types
1       mov     v1, a1
        ldr     v2, [v1, #VIDCList3_Type]
;        DebugReg v2, "Hal_VetMode with list type "
        ldr     v2, [v1, #VIDCList3_PixelRate]          ; pixel rate
        ldr     a1, =MaxPermittedPixelKHz               ; max pixel rate
        cmp     v2, a1          ; pixel rate too high?.. exit if yes
        EXIT    GT
;        ldr     v2, [v1, #VIDCList3_SyncPol]            ; interlaced
;        and     a1, v2, #(SyncPol_InterlaceSpecified + SyncPol_Interlace)
;        teq     a1, #(SyncPol_InterlaceSpecified + SyncPol_Interlace)
;        EXIT    EQ              ; not happy with interlace
;; need to check control list for interlace stuff

        ldr     v2, [v1, #VIDCList3_PixelDepth]         ; the l2bpp bit
;        DebugReg v2, "Hal_VetMode with l2bpp "
        teq     v2, #5
        teqne   v2, #4
        teqne   v2, #3
        movne   v2, #4
        strne   v2, [v1, #4]
        mov     a1, #0
        EXIT

        teq     v2, #1
        beq     %ft002          ; it was a type 1,, make it a type 3
        ldreq   v2, [v1, #12-4]
        beq     %ft001
        teq     v2, #3
        ldreq   v2, [v1, #4-4]
;        DebugReg v2, "l2bpp found "
001     teq     v2, #5          ; quick check if credible
        teqne   v2, #4
        teqne   v2, #3
        bne     %ft002                  ; dont like it.. copy back our default
        mov a1, #0    ; claim it
        EXIT
002
 DebugTX "*****need to rewrite mode from type 1 to type 3 "
 EXIT
        mov     v1, #modedefv3size
        adrl    v2, modedefv3
003     subs    v1, v1, #4
        movlt   a1, #0    ; claim it
        EXIT    LT
        ldr     v3, [v2, v1]
        str     v3, [a1, v1]
        b       %bt003

;mov a3,lr
; DebugReg a1, "hal_VetMode "
; mov lr,a3
;        MOV     a1, #0           ; claim it..
;        MOV     pc, lr


; a1-> vidc type 3 list.. not debatable.. just do it
; no return value used
HAL_VideoSetMode
        Entry   "v1, v2, v3, v4, sb"
        mov     v1, a1
        bl      LoadVideoModeFromV3
;Setup HDMI
; mHDMI -> HDMIInfo structure
; corrupts a1-a4
        bl      ReInitVideoMode
        EXIT



HAL_VideoFramestoreAddress
        MOV     pc, lr


HAL_VideoFlybackDevice
        MOV     a1, #VIDEO_IRQ
; mov a2,lr
; DebugReg a1, "hal_VFdevice:"
; mov lr,a2
        MOV     pc, lr

HAL_VideoPixelFormats
        MOV     a1, #2_111000   ;8,16,32 bpp only
; mov a2,lr
; DebugReg a1, "hal_PixFMT: "
; mov lr,a2
        MOV     pc, lr

; 1 = hw scroll
; 2 = hw pointer
; 4 = interlace progressive scan
; 8 = separate framestore
; 16 = no vsync irqs
; 32 = framestore address also changes with mode
HAL_VideoFeatures
        MOV     a1, #0
      [ HardwarePointer
        ; Only claim full hardware pointer support if mode is <= 2048x2048
        LDR     a2, mwidth
        LDR     a3, mheight
        CMP     a2, #2048
        CMPLE   a3, #2048
        ORRLE   a1, a1, #GVDisplayFeature_HardwarePointer
      ]
; mov a2,lr
; DebugReg a1,"hal_VFeatures: "
; mov lr,a2
        MOV     pc, lr

HAL_VideoPixelFormatList
        ADR     r0,VPFList
        MOV     r1, #VPFListEntries
; mov r3,lr
; DebugReg r0,"hal_VPixelFormatList: "
; DebugReg r1,"hal_VPixelFormatListlen: "
; mov lr,r3
        MOV     pc,lr
VPFList
                                ; first  12 bytes/3 words per entry
        DCD     255             ;NColour C256 paletted
        DCD     1<<7            ;ModeFlags
        DCD     3               ;L2BPP
        DCD     65535           ;NColour C32K TBGR1555
        DCD     0               ;ModeFlags
        DCD     4               ;L2BPP
        DCD     -1              ;NColour    C16M ..
        DCD     0               ;ModeFlags
        DCD     5               ;L2BPP
VPFListEntries * ((.-VPFList)/12)

HAL_VideoStartupMode
        Entry   "a2, a3, v1, v2, v3, v4"
        mov     v1, a1
        adrl    a1, VIDCList3                ; (a bit of StaticWS)
        adr     lr, startupmode ;
        ldmia   lr, {a2,a3,v1,v2,v3,v4}
        stmia   a1, {a2,a3,v1,v2,v3,v4}
        EXIT
; mov a2,lr
; DebugReg a1,"hal_StartupMode"
; mov lr,a2
;        adr     a1, startupmode
;        MOV     pc, lr



HAL_VideoBufferAlignment
; mov a2,lr
; DebugTX "hal_VBuffAlign"
; mov lr,a2
        MOV     a1, #4
        MOV     pc, lr

; default screen mode selection
; 0 = 640x480@59.9
; 1 = 800x600@56.2
; 2 = 800x600@60.3
; 3 = 1024x768@60
; 4 = 1280x800&59.9
; if wrong, compile will break!!!
DefaultScreenMode * 4

; Set to 1 for VSYNC external to IPU, else 0
VSYNC_EXTERNAL * 1

; set to 1, (C TRUE) for HDMI o/p, 0 (C FALSE) for DVI o/p
SELHDMI * 0

        EXPORT  |ConfigHDMI|
        EXPORT  |LoadDefaultVideoMode|
        EXPORT  |myhdmi_clock_set|
        EXPORT  |ConfigIPU_DI|
; set up some specific register usage
mPANEL RN v3
mVMODE RN v2
mHDMI  RN v1

DefaultVideoMode
 [ DefaultScreenMode = 0
; 640x480@59.9                  ; this is std 640x480 that most monitors do
dvPix   *       25180000        ; pixel clock (Hz)
dvHres  *       640             ;
dvHs1   *       656             ; hsync start
dvHs2   *       752             ; hsync end
dvHs3   *       800             ; h line total
dvVres  *       480             ;
dvVs1   *       489             ; vsync start
dvVs2   *       492             ; vsync end
dvVs3   *       525             ; v line total
dvHpol  *       0               ; hsync polarity 0=-v1, 1=+vs
dvVpol  *       0               ; vsync polarity 0=-v1, 1=+vs
dvHrat  *       4               ; Horiz by
dvVrat  *       3               ; Virt aspect ratio
dvIntrl *       0               ; not interlaced
 |
  [ DefaultScreenMode = 1
; 800x60@56.2                  ; this is std 800x600 that most monitors do
dvPix   *       36000000        ; pixel clock (Hz)
dvHres  *       800             ;
dvHs1   *       824             ; hsync start
dvHs2   *       896             ; hsync end
dvHs3   *       1024            ; h line total
dvVres  *       600             ;
dvVs1   *       601             ; vsync start
dvVs2   *       603             ; vsync end
dvVs3   *       625             ; v line total
dvHpol  *       1               ; hsync polarity 0=-v1, 1=+vs
dvVpol  *       1               ; vsync polarity 0=-v1, 1=+vs
dvHrat  *       4               ; Horiz by
dvVrat  *       3               ; Virt aspect ratio
dvIntrl *       0               ; not interlaced
  |
   [ DefaultScreenMode = 2
; 800x60@60.3                  ; this is std 800x600 that most monitors do
dvPix   *       40000000        ; pixel clock (Hz)
dvHres  *       800             ;
dvHs1   *       840             ; hsync start
dvHs2   *       968             ; hsync end
dvHs3   *       1056            ; h line total
dvVres  *       600             ;
dvVs1   *       601             ; vsync start
dvVs2   *       605             ; vsync end
dvVs3   *       628             ; v line total
dvHpol  *       1               ; hsync polarity 0=-v1, 1=+vs
dvVpol  *       1               ; vsync polarity 0=-v1, 1=+vs
dvHrat  *       4               ; Horiz by
dvVrat  *       3               ; Virt aspect ratio
dvIntrl *       0               ; not interlaced
   |
    [ DefaultScreenMode = 3
; mode 1024x768&60              ; this is std 1024x768 that most monitors do
dvPix   *       65000000        ; pixel clock (Hz)
dvHres  *       1024            ;
dvHs1   *       1048            ; hsync start
dvHs2   *       1184            ; hsync end
dvHs3   *       1344            ; h line total
dvVres  *       768             ;
dvVs1   *       771             ; vsync start
dvVs2   *       777             ; vsync end
dvVs3   *       806             ; v line total
dvHpol  *       0               ; hsync polarity 0=-v1, 1=+vs
dvVpol  *       0               ; vsync polarity 0=-v1, 1=+vs
dvHrat  *       4               ; Horiz by
dvVrat  *       3               ; Virt aspect ratio
dvIntrl *       0               ; not interlaced
    |
     [ DefaultScreenMode = 4
; mode 1280x800&59.9            ; this is std 1280x800 that most monitors do
dvPix   *       71000000        ; pixel clock (Hz)
dvHres  *       1280            ;
dvHs1   *       1328            ; hsync start
dvHs2   *       1360            ; hsync end
dvHs3   *       1440            ; h line total
dvVres  *       800             ;
dvVs1   *       803             ; vsync start
dvVs2   *       809             ; vsync end
dvVs3   *       823             ; v line total
dvHpol  *       1               ; hsync polarity 0=-v1, 1=+vs
dvVpol  *       0               ; vsync polarity 0=-v1, 1=+vs
dvHrat  *       8               ; Horiz by
dvVrat  *       5               ; Virt aspect ratio
dvIntrl *       0               ; not interlaced
    |
     ; if we get here then nothing defines
     ]
    ]
   ]
  ]
 ]

startupmode
        DCD 1                     ; mode selector block format 0
        DCD dvHres                ; x pixels
        DCD dvVres                ; y pixels
        DCD 5                     ; log2bpp = 32
        DCD 60                    ; frame rate or (-1)first match
        DCD -1                    ; end of list, no further mode variables

; must specify interlace, as otherwise the kernel will attempt
; to write this.. it may not be in writable space
modedefv3
        DCD  3                  ;00 type 3 list
        DCD  5                  ;04 bpp
        DCD  dvHs2-dvHs1        ;08 h sync
        DCD  0                  ;0c h back porch
        DCD  dvHs3-dvHs2        ;10 h left border
        DCD  dvHres             ;14 h pixels
        DCD  dvHs1-dvHres       ;18 h right border
        DCD  0                  ;1c h front porch
        DCD  dvVs2-dvVs1        ;20 v sync
        DCD  0                  ;24 v back porch
        DCD  dvVs3-dvVs2        ;28 v left border
        DCD  dvVres             ;2c v pixels
        DCD  dvVs1-dvVres       ;30 v right border
        DCD  0                  ;34 v front porch
        DCD  dvPix/1000         ;38 pixel rate KHz
        DCD  ((dvIntrl<<3)+(1<<2)) + (dvHpol<<0) + (dvVpol<<1) ;3c sync flags -ve vsync interlace speccd .. no interlace
        DCD  -1                 ;40 list end
modedefv3size     * .-modedefv3
        ASSERT    modedefv3size=VIDCList3_Size

InitVideoMode
        Entry   "a1, a2, sb"
        adrl    a2, myHDMI_vmode_infos
        str     a2, video_mode
;        bl      PrintInstance
        bl      ReInitVideoMode
        EXIT

ReInitVideoMode
        Entry   "a1, a2, sb"
        adrl    a1, myHDMI_infos
        bl      ConfigHDMI
        mov     a1, #1
        bl      ipu_disable_display
        adrl    a1, myHDMI_infos
        bl      ReInitHDMIPhy
;        bl      PrintInstance
        bl      ips_hdmi_stream

        ; Changing mode seems to reset all the interrupt enable bits
        ; Make sure VSync IRQ is still enabled (and all others disabled)
        ldr     a1, IPU1_Log
        add     a1, a1, #IPU_REGISTERS_OFFSET
        add     a2, a1, #IPU_IPU_INT_CTRL_15_OFFSET-IPU_REGISTERS_OFFSET
        add     a1, a1, #IPU_IPU_INT_CTRL_1_OFFSET-IPU_REGISTERS_OFFSET
        mov     a3, #0
12
        teq     a1, a2
        str     a3, [a1], #4
        bne     %bt12
        ; Enable vsync IRQ for DI 0 (DI_VSYNC_PRE_0 in IPU1_INT_CTRL_15)
        mov     a1, #1<<14
        str     a1, [a2]

        EXIT


; load a video mode, and set up a display panel to exactly
; starting with vidclist type 3
; on entry a1->vidc3 list
; represent that
; note TRUE = 1, FALSE = 0
        EXPORT  |LoadVideoModeFromV3|
LoadVideoModeFromV3
        Entry   "a1,a2,a3,a4,v1,v2,sb"
        adrl    a2, myHDMI_vmode_infos
        str     a2, video_mode           ; assemble it
        mov     a3, a1                   ; get list pointer out of the way
; now the videomode and panel stuff
; the software below needs 4 parameters from the VIDC3List
; displayed_pixels, distance to sync start, sync width, distance to line end
        ldr     a2, [a3, # VIDCList3_PixelDepth]
        str     a2, ml2bpp
; DebugRegNCR a2, "L3bpp="
        ldr     a2, [a3, # VIDCList3_PixelRate]
        str     a2,mPixelClock           ; 1KHz res
; DebugReg a2, "ClkKhz="
        mov     a1, #1000
        mul     a2, a1, a2               ; in Hz
        str     a2,mpixel_clock
; displayed pixels
        ldr     a2, [a3, # VIDCList3_HorizDisplaySize] ;
        str     a2, mwidth
        str     a2, mHActive
; DebugRegNCR a2, "X="
        mov     v1, a2             ; line dots
; distance to sync start
        ldr     a1, [a3, # VIDCList3_HorizLeftBorder] ;
        ldr     a2, [a3, # VIDCList3_HorizBackPorch] ;
        add     a2, a2, a1
; DebugRegNCR a2, "Rborder="
        str     a2, mHSyncOffset
        str     a2, mhsync_start_width
        add     v1, v1, a2         ; add to line dots
; sync width
        ldr     a4, [a3, # VIDCList3_HorizSyncWidth] ;
        str     a4, mHSyncPulseWidth
        str     a4, mhsync_width
; DebugRegNCR a4, "Sync="
        add     v1, v1, a4         ; add to line dots
        add     a4, a4, a2         ; add to non display dots
; distance to end of line
        ldr     a1, [a3, # VIDCList3_HorizRightBorder] ;
        ldr     a2, [a3, # VIDCList3_HorizFrontPorch] ;
        add     a2, a2, a1
        str     a2, mhsync_end_width
; DebugReg a2, "Lborder="
        add     v1, v1, a2         ; total h dots
        add     a4, a2, a4         ; add to non display dots
        str     a4, mHBlanking

; displayed lines
        ldr     a2, [a3, # VIDCList3_VertiDisplaySize] ;
        str     a2, mVActive
        str     a2, mheight
; DebugRegNCR a2, "Y="
        mov     v2, a2             ; lines
; distance to sync start
        ldr     a1, [a3, # VIDCList3_VertiTopBorder] ;
        ldr     a2, [a3, # VIDCList3_VertiBackPorch] ;
        add     a4, a2, a1
; DebugRegNCR a4, "Bborder="
        str     a4, mVSyncOffset
        str     a4, mvsync_start_width
        add     v2, v2, a4         ; add to lines
; sync width
        ldr     a2, [a3, # VIDCList3_VertiSyncWidth] ;
        str     a2, mVSyncPulseWidth
        str     a2, mvsync_width
; DebugRegNCR a2, "Sync="
        add     v2, v2, a2         ; add to lines
        add     a4, a4, a2         ; add to non display lines

        ldr     a1, [a3, # VIDCList3_VertiBottomBorder] ;
        ldr     a2, [a3, # VIDCList3_VertiFrontPorch] ;
        add     a2, a2, a1
; DebugReg a2, "Tborder="
        str     a2, mvsync_end_width
        add     v2, v2, a2         ; total v lines
        add     a2, a2, a4         ; total non display lines
        str     a2, mVBlanking
        mul     a2, v2, v1         ; compute frame clock needed
        mov     a1, #1000
        bl      udivide
        ldr     a2, mpixel_clock   ; in KHz
        bl      udivide
        str     a1, mRefreshRate   ; frame rate
        str     a1, mrefresh_rate

        ldr     a1, [a3, # VIDCList3_SyncPol] ;
; DebugReg a1, "syncpol "
        and     a2, a1, #1 << 0           ; hsync polarity
        str     a2, mHSyncPolarity
        str     a2, mhsync_pol
        and     a2, a1, #1 << 1           ; vsync polarity
        mov     a2, a2, lsr #1
        str     a2, mVSyncPolarity
        str     a2, mvsync_pol
        and     a2, a1, #3 << 2           ; interlace valid + en
        teq     a2, #3 << 2               ; valid and enabled?
        moveq   a2, #1
        movne   a2, #0
        str     a2,mInterlaced
        str     a2,mpinterlaced
        ; we'll assume no extended vidclist parameters.
        ; thats all we can get from the VIDClist
        ; the rest is up to us....

; basic HDMI_Info structure
        mov     a2, #HDMI_eRGB
        str     a2, enc_in_format
        str     a2, enc_out_format
        mov     a2, #8                         ; keep 8bit so far
        str     a2, enc_color_depth

        mov     a2, #HDMI_eITU601
        str     a2, colorimetry

        mov     a2, #0
        str     a2, pix_repet_factor
        str     a2, hdcp_enable


        mov     a2,#dvHrat
        str     a2,mHImageSize            ; panel info.. not used atm
        mov     a2,#dvVrat
        str     a2,mVImageSize            ; panel info.. not used atm
        mov     a2,#0
        str     a2,mHBorder
        str     a2,mVBorder
        str     a2,mPixelRepetitionInput

        ldr     a2, =&00434241           ; text string ABC
        str     a2, mpanel_name
        mov     a2, #1
        str     a2, mpanel_id           ; a fabrication.. hope not needed
        mov     a2, #5                  ; hdmi display device .. is it needed?
        str     a2, mpanel_type
        mov     a2, #5                  ; DCMAP_GBR888
        str     a2, mcolorimetry
        mov     a2, #0                  ; 1 = clock external to IPU
        str     a2, mclk_sel            ; clk int/external to disp unit
        mov     a2, #0
        str     a2, mclk_pol            ; clk polarity into hdmi
        mov     a2, #1                  ; 1 = C TRUE
        str     a2, mdrdy_pol           ; data ready polarity into hdmi
        str     a2, mDataEnablePolarity
        mov     a2, #1
        str     a2, mdata_pol           ; data polarity into hdmi
        ; the following values are preset.. need checking
        mov     a2, #SELHDMI
        str     a2, mHdmiDviSel
        mov     a2, #0
        str     a2, mRVBlankInOSC
        str     a2, mCode
        mov     a2, #00                 ; give at least 01 delay h2v (line start to video)
        str     a2, mdelay_h2v
        mov     a2, #0
        str     a2, mpanel_init         ; ensure not used
        str     a2, mpanel_deinit       ; ensure not used
; adrl a1,myHDMI_infos
; bl    PrintInstance
        EXIT
        LTORG                           ; dump the literals...

; load a default video mode, and set up a display panel to exactly
; represent that
; note TRUE = 1, FALSE = 0
LoadDefaultVideoMode
        adrl    a1, modedefv3
        b       LoadVideoModeFromV3



;void hdmi_clock_set(int ipu_index, uint32_t pclk)
;
;
;
myhdmi_clock_set
        Entry   "a1,a2,a3,a4,sb"
        teq     a1, #1                  ; ipu1 or 2?

; set up PLL5, VideoPLL
; clocks on
; video pll rate = fref*(divselect + (VIDEO_NUM/VIDEO_DENOM))
; fref = 24MHz, divselect min 27, max 54 => divselect 27 gives fout=648. 650/24 = 27.08333
; so .08333333 = 100 000 000 / 1 200 000 005
;  gives video pll =650MHz then div 2 = 325MHz
        ldr     a2, CCMAn_Log
        ldr     a3, =10000000
        str     a3, [a2,#HW_CCM_ANALOG_PLL_VIDEO_NUM_ADDR]   ; must be less than denom
        ldr     a3, =1200000005
        str     a3, [a2,#HW_CCM_ANALOG_PLL_VIDEO_DENOM_ADDR]
;       pll enabled, bypass on, div_select=27 , post_div= 2
        ldr     a4, =((27<<0) + (1<<13) + (1<<16) + (1<<19))
        str     a4, [a2,#HW_CCM_ANALOG_PLL_VIDEO_ADDR]
111
        ldr     a3, [a2,#HW_CCM_ANALOG_PLL_VIDEO_ADDR]
;  DebugReg a3, "pll ready? "
        tst     a3, #1<<31
        beq     %bt111                  ; wait for PLL Lock
; video pll now locked
        bic     a3, a4, #(1<<16)        ; clear bypass bit
        str     a4, [a2,#HW_CCM_ANALOG_PLL_VIDEO_ADDR]
; Video PLL giving out 325MHz
;
; now set PFD1_fraction to give 445MHz from PLL3 (USB1 PLL 480MHz)
        ldr     a3, [a2,#HW_CCM_ANALOG_PFD_480_ADDR]
        bic     a3, a3, #(&3f<<8)       ; PFD1_FRAC
        orr     a3, a3, #(&13<<8)       ; PFD1_FRAC for 445 MHz
        str     a3, [a2,#HW_CCM_ANALOG_PFD_480_ADDR]

        ldr     a2, CCM_Base
        ldr     a3, [a2, #CCM_CS2CDR_OFFSET]
        bic     a3, a3, # (7<<9)        ; ldb_di0_clk select from PLL5 (325MHz) (0)
        str     a3, [a2, #CCM_CS2CDR_OFFSET]

        ldr     a3, [a2, #CCM_CHSCCDR_OFFSET]
        bic     a3, a3, # (7<<0)        ; ldb_di0_clk field clr
        orr     a3, a3, # (3<<0)        ; ipu1_di0 clock from ldb_di0_clk
        bic     a3, a3, # (7<<9)
        orr     a3, a3, # (3<<9)        ; ipu1_di1 clock from ldb_di0_clk
        str     a3, [a2, #CCM_CHSCCDR_OFFSET]

        ldr     a3, [a2, #CCM_CSCMR2_OFFSET]
        bic     a3, a3, # (3<<10)        ; div ldb_di0_clk and ldb_di1_clk by 3.5  = 90MHz
        str     a3, [a2, #CCM_CSCMR2_OFFSET]

        ldr     a3, [a2, #CCM_CSCDR2_OFFSET]
        bic     a3, a3, # (7<<0)
        orr     a3, a3, # (3<<0)        ; ipu2_di0 clock from ldb_di0_clk
        bic     a3, a3, # (7<<9)
        orr     a3, a3, # (3<<9)        ; ipu2_di1 clock from ldb_di0_clk
        str     a3, [a2, #CCM_CSCDR2_OFFSET]
; IPU clock is 90MHz


; cfg IPU HSP clocks
; used if di_clk_srce set as internal to IPU
; currently set to 264MHz from main 528MHzPLL" o/p
        mov     a1, #&1f
        ldr     a3, [a2, #CCM_CSCDR3_OFFSET]   ; IPU HSC clk
        bic     a3, a3, a1, lsl #9      ; clear all fields ipu1 clk
        bic     a3, a3, a1, lsl #14     ; clear all fields ipu2 clk
        orr     a3, a3, #((0<<0)+(1<<2))<<9  ; ipu1 hsc from 528MHZ pfd podf=1 (528/2=264MHz)
        orr     a3, a3, #((0<<0)+(1<<2))<<14 ; ipu2 hsc from 528MHZ pfd podf=1 (528/2=264MHz)
        str     a3, [a2, #CCM_CSCDR3_OFFSET]
        EXIT
        LTORG

;Setup HDMI
; a1 -> HDMIInfo structure
; corrupts a1-a4
ConfigHDMI
        Entry   "mHDMI,mVMODE,v3,v4,v5,sb"
; DebugReg a1, "ConfigHDMI "
        mov     mHDMI, a1                       ; preserve the HDMIInfo pointer
        ldr     mVMODE, [mHDMI, #video_mode-myHDMI_infos] ; get pointer
        ; enable HDMI clocks in CCGR2
        ; 5-4, and 1-0 are HDMI clocks
        ;; done in HAL startup ATM
        ldr     a2, CCM_Base
        ldr     a3, [a2,#CCM_CCGR2_OFFSET]
        orr     a3, a3, #((3<<4) + (3<<0))  ; HDMI clocks on
        str     a3, [a2,#CCM_CCGR2_OFFSET]
        ldr     a3, [a2,#CCM_CCGR3_OFFSET]
        orr     a3, a3, #((3<<2) + (3<<0))  ; IPU Di0 clocks on
        str     a3, [a2,#CCM_CCGR3_OFFSET]
; configure pins
; set up the DDC lines for HDMI
        ldr     a2, IOMUXC_Base
;    [ {FALSE} ; The below is wrong, it's I2C1 which is used for DDC. Not sure yet if HDMI needs exclusive use or whether it can be shared with the HAL I2C API.
;       ; pin enable
;        ldr     a3, =IOMuxPadHDMIDDC            ; pad drive stuff
;        str    a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_COL3-IOMUXC_BASE_ADDR]
;        str    a3, [a2,#IOMUXC_SW_PAD_CTL_PAD_KEY_ROW3-IOMUXC_BASE_ADDR]
;       ; input select
;       ; the IOMUXC_HDMI_TX_ICECIN_SELECT_INPUT is not used on wandboard
;        mov    a3, #SEL_KEY_COL3_ALT2
;        str    a3, [a2,#IOMUXC_HDMI_TX_II2C_MSTH13TDDC_SCLIN_SELECT_INPUT-IOMUXC_BASE_ADDR]
;        mov    a3, #SEL_KEY_ROW3_ALT2
;        str    a3, [a2,#IOMUXC_HDMI_TX_II2C_MSTH13TDDC_SDAIN_SELECT_INPUT-IOMUXC_BASE_ADDR]
;        ; pad mode & bypass
;       mov     a3, #2 ;      | (SION_ENABLED<<4)    ; alt2, SION  not enabled
;        str    a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_COL3-IOMUXC_BASE_ADDR]
;        str    a3, [a2,#IOMUXC_SW_MUX_CTL_PAD_KEY_ROW3-IOMUXC_BASE_ADDR]
;    ]
;        bl     myhdmi_clock_set
; select HDMI input source
        ldr     a3, [a2, #IOMUXC_GPR3-IOMUXC_BASE_ADDR]
        bic     a3, a3, a1,lsl #2          ; HDMI src = (0 = IPU1_DI0)
        str     a3, [a2, #IOMUXC_GPR3-IOMUXC_BASE_ADDR]


; configure frame composer
        ldr     a2,HDMI_Log     ; base address of HDMI stuff
                                ; now get frame composer base
        add     a2, a2, #HDMI_FC_INVIDCONF - HDMI_BASE_ADDR
        ; build up the HDMI_FC_INVIDCONF value

        ldr     a3, [mHDMI, #hdcp_enable-myHDMI_infos]
        teq     a3, #0
        movs    a1, a3
        movne   a1, #1<<7      ; HDCP_KEEPOUT
        ldr     a3,[mVMODE,#mVSyncPolarity-myHDMI_vmode_infos]
        and     a3, a3, #1
        orr     a1, a1, a3, lsl #6   ; VSYNC_IN_POLARITY
        ldr     a3,[mVMODE,#mHSyncPolarity-myHDMI_vmode_infos]
        and     a3, a3, #1
        orr     a1, a1, a3, lsl #5   ; HSYNC_IN_POLARITY
        ldr     a3,[mVMODE,#mDataEnablePolarity-myHDMI_vmode_infos]
        and     a3, a3, #1
        orr     a1, a1, a3, lsl #4   ; DE_IN_POLARITY
        ldr     a3,[mVMODE,#mHdmiDviSel-myHDMI_vmode_infos]
        and     a3, a3, #1
        orr     a1, a1, a3, lsl #3   ; DVI_MODEZ
        ldr     a3,[mVMODE,#mCode-myHDMI_vmode_infos]
        teq     a3, #39        ; mode 39?
        ldr     a3,[mVMODE,#mInterlaced-myHDMI_vmode_infos]
        andnes  a3, a3, #1   ;
        orrne   a1, a1, #1   ; R_V_BLANK_IN_OSC set 1 if interlaced not mode 39
        and     a3, a3, #1
        orr     a1, a1, a3, lsl #0   ; IN_I_P
        strb    a1, [a2, #HDMI_FC_INVIDCONF-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mHActive-myHDMI_vmode_infos]
; DebugReg a1, "FC_INHACTIV "
        strb    a1, [a2, #HDMI_FC_INHACTV0-HDMI_FC_INVIDCONF]
        mov     a1, a1, lsr #8
        bic     a1, a1, #3<<5
        strb    a1, [a2, #HDMI_FC_INHACTV1-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mVActive-myHDMI_vmode_infos]
; DebugReg a1, "FC_INVACTIV "
        strb    a1, [a2, #HDMI_FC_INVACTV0-HDMI_FC_INVIDCONF]
        mov     a1, a1, lsr #8
        bic     a1, a1, #3<<5
        strb    a1, [a2, #HDMI_FC_INVACTV1-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mHBlanking-myHDMI_vmode_infos]
; DebugReg a1, "HBlanking "
        strb    a1, [a2, #HDMI_FC_INHBLANK0-HDMI_FC_INVIDCONF]
        mov     a1, a1, lsr #8
        bic     a1, a1, #3<<5
        strb    a1, [a2, #HDMI_FC_INHBLANK1-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mVBlanking-myHDMI_vmode_infos]
; DebugReg a1, "FC_INVBLANK "
        strb    a1, [a2, #HDMI_FC_INVBLANK-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mHSyncOffset-myHDMI_vmode_infos]
; DebugReg a1, "FC_HSYNCINDELAY "
        strb    a1, [a2, #HDMI_FC_HSYNCINDELAY0-HDMI_FC_INVIDCONF]
        mov     a1, a1, lsr #8
        bic     a1, a1, #3<<5
        strb    a1, [a2, #HDMI_FC_HSYNCINDELAY1-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mHSyncPulseWidth-myHDMI_vmode_infos]
; DebugReg a1, "FC_HSYNCWIDTH "
        strb    a1, [a2, #HDMI_FC_HSYNCINWIDTH0-HDMI_FC_INVIDCONF]
        mov     a1, a1, lsr #8
        bic     a1, a1, #&1c<<5
        strb    a1, [a2, #HDMI_FC_HSYNCINWIDTH1-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mVSyncOffset-myHDMI_vmode_infos]
; DebugReg a1, "FC_VSYNCOFFSET "
        strb    a1, [a2, #HDMI_FC_VSYNCINDELAY-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mVSyncPulseWidth-myHDMI_vmode_infos]
; DebugReg a1, "FC_VSYNCWIDTH "
        strb    a1, [a2, #HDMI_FC_VSYNCINWIDTH-HDMI_FC_INVIDCONF]

        mov     a1, #12    ; control period min duration
        strb    a1, [a2, #HDMI_FC_CTRLDUR-HDMI_FC_INVIDCONF]
        mov     a1, #32    ;
        strb    a1, [a2, #HDMI_FC_EXCTRLDUR-HDMI_FC_INVIDCONF]
        mov     a1, #1     ;
        strb    a1, [a2, #HDMI_FC_EXCTRLSPAC-HDMI_FC_INVIDCONF]

        mov     a1, #&0b    ;
        strb    a1, [a2, #HDMI_FC_CH0PREAM-HDMI_FC_INVIDCONF]
        mov     a1, #&16    ;
        strb    a1, [a2, #HDMI_FC_CH1PREAM-HDMI_FC_INVIDCONF]
        mov     a1, #&21    ;
        strb    a1, [a2, #HDMI_FC_CH2PREAM-HDMI_FC_INVIDCONF]

        ldr     a1, [mVMODE,#mPixelRepetitionInput-myHDMI_vmode_infos]
        add     a1, a1, #1
        mov     a1, a1, lsl #4
        strb    a1, [a2, #HDMI_FC_PRCONF-HDMI_FC_INVIDCONF]

; mute audio for present time
        mov     a1, #0
        strb    a1, [a2, #HDMI_FC_AUDSCONF-HDMI_FC_INVIDCONF]

; configure video packetiser
; first check some encodings
        mov     v3, #0                  ; color_depth
        mov     v4, #0                  ; remap_size
        mov     v5, #0                  ; output_select
        ldr     a1, [mHDMI,#enc_out_format-myHDMI_infos]
        teq     a1, #HDMI_eRGB
        teqne   a1, #HDMI_eYCC444
        bne     %ft1
        ldr     a1, [mHDMI, #enc_color_depth-myHDMI_infos]
        teq     a1, #0
        moveq   v5, #3
        teq     a1, #8
        moveq   v3, #4
        moveq   v5, #3
        teq     a1, #10
        moveq   v3, #5
        teq     a1, #12
        moveq   v3, #6
        teq     a1, #16
        moveq   v3, #7
        b       %ft2
1
        teq     a1, #HDMI_eYCC422
        bne     %ft2
        ldr     a1, [mHDMI, #enc_color_depth-myHDMI_infos]
        teq     a1, #0
        teqne   a1, #8
        moveq   v4, #0
        teq     a1, #10
        moveq   v4, #1
        teq     a1, #12
        moveq   v4, #2
        mov     v5, #1
2
        ldr     a2, HDMI_Log    ; base address of HDMI stuff
        add     a2, a2, #HDMI_VP_STATUS - HDMI_BASE_ADDR
        ldr     a1, [mHDMI, #pix_repet_factor-myHDMI_infos]
        bic     lr, a1, #&f0
        orr     lr, lr, v3, lsl #4
        strb    lr, [a2, #HDMI_VP_PR_CD-HDMI_VP_STATUS]
; build   a1 = HDMI_VP_CONF, a3 = HDMI_VP_STUFF, a4 = HDMI_VP_REMAP
        cmp     a1, #1
        movgt   a1, # (1<<4) + (0<<2) ; Pr_EN + BYPASS_SELECT
        movle   a1, # (0<<4) + (1<<2)
        mov     a3, # (1<<5)          ; IDEFAULT_PHASE
        and     a4, v4, #3            ; YCC422_SIZE
        teq     v5, #0
        orreq   a1, a1, #(0<<6)+(1<<5)+(0<<3) ;BYPASS_EN+PP_EN+YCC422_EN
        teq     v5, #1
        orreq   a1, a1, #(0<<6)+(0<<5)+(1<<3) ;BYPASS_EN+PP_EN+YCC422_EN
        teq     v5, #2
        teqne   v5, #3
        orreq   a1, a1, #(1<<6)+(0<<5)+(0<<3) ;BYPASS_EN+PP_EN+YCC422_EN
        orr     a3, a3, #(1<<2)+(1<<1)        ;YCC422_STUFFING _+PP_STUFFING
        and     v5, v5, #3
        orr     a1, a1, v5                    ; output selection
        strb    a4, [a2, #HDMI_VP_REMAP-HDMI_VP_STATUS]
        strb    a3, [a2, #HDMI_VP_STUFF-HDMI_VP_STATUS]
        strb    a1, [a2, #HDMI_VP_CONF-HDMI_VP_STATUS]

; check color space interpolation
; + setup CSC coefficients
        ldr     a2,HDMI_Log     ; base address of HDMI stuff
        add     a2, a2, #HDMI_CSC_CFG - HDMI_BASE_ADDR
        ldr     v3, [mHDMI, #enc_out_format-myHDMI_infos]
        ldr     v5, [mHDMI, #enc_in_format-myHDMI_infos]
        teq     v5, #HDMI_eYCC422
        bne     %ft1
        teq     v3, #HDMI_eRGB
        teqne   v3, #HDMI_eYCC444             ; color space interpolation?
        moveq   a1, #(1<<4)                   ; yes
1       mov     a1, #0                        ; no
        ldr     a3, [mHDMI, #enc_color_depth-myHDMI_infos]
        mov     a4, #7                  ; depth 16 default
        teq     a3, #12
        moveq   a4, #6                  ; depth 12
        teq     a3, #10
        moveq   a4, #5                  ; depth 10
        teq     a3, #8
        moveq   a4, #4                  ; depth 8
        strb    a4, [a2, #HDMI_CSC_SCALE - HDMI_CSC_CFG]
        teq     v3, v5                       ; color space conversion needed?
        orrne   a1, a1, #(1<<0)              ; yes.. set color space decimation
        strb    a1, [a2, #HDMI_CSC_CFG - HDMI_CSC_CFG]  ; set HDMI_CSC_CFG

        add     a2, a2, #HDMI_CSC_COEF_A1_MSB - HDMI_CSC_CFG
        ldrb    a4, [a2, #HDMI_CSC_SCALE - HDMI_CSC_COEF_A1_MSB]
        orr     a4, a4, #(1<<0)   ;CSC_SCALE

        beq     %ft20                        ; no color space conversion
        teq     v3, #HDMI_eRGB
        bne     %ft10
        ldr     v4, [mHDMI, #colorimetry-myHDMI_infos]
        teq     v4, #HDMI_eITU601
        adreql  a1, RGBoutITU601
        adrnel  a1, RGBoutITU709
        b       %ft21
10
        teq     v5, #HDMI_eRGB
        bne     %ft20
        ldr     v4, [mHDMI, #colorimetry-myHDMI_infos]
        teq     v4, #HDMI_eITU601
        adreql  a1, RGBinITU601
        adrnel  a1, RGBinITU709
        b       %ft21
20
        adrl    a1, CSCDefault
21
        add     a3, a2, #24
1       ldrb    a4, [a1], #1
        strb    a4, [a2], #1
        cmp     a2, a3
        blt     %bt1

; setup video sampler
; .. color_format
        ldr     v3, [mHDMI, #enc_color_depth-myHDMI_infos]
        ldr     v5, [mHDMI, #enc_in_format-myHDMI_infos]
        mov     a1, #0
        teq     v5, #HDMI_eRGB
        bne     %ft1
        teq     v3, #8
        moveq   a1, #&01
        teq     v3, #10
        moveq   a1, #&03
        teq     v3, #12
        moveq   a1, #&05
        teq     v3, #16
        moveq   a1, #&07
        b       %ft3

1       teq     v5, #HDMI_eYCC444
        bne     %ft2
        teq     v3, #8
        moveq   a1, #&09
        teq     v3, #10
        moveq   a1, #&0b
        teq     v3, #12
        moveq   a1, #&0d
        teq     v3, #16
        moveq   a1, #&0f
        b       %ft3

2       ;teq    v5, #HDMI_eYCC422
        teq     v3, #8
        moveq   a1, #&16
        teq     v3, #10
        moveq   a1, #&14
        teq     v3, #12
        moveq   a1, #&12
3
        ldr     a2,HDMI_Log     ; base address of HDMI stuff
                                ; color_format in bottom 5 bits, and
                                ; int DE gen off
        strb    a1, [a2, #HDMI_TX_INVID0 - HDMI_BASE_ADDR]
        mov     a1, #7
        strb    a1, [a2, #HDMI_TX_INSTUFFING - HDMI_BASE_ADDR]
        mov     a1, #0
        strb    a1, [a2, #HDMI_TX_GYDATA0  - HDMI_BASE_ADDR]
        strb    a1, [a2, #HDMI_TX_GYDATA1  - HDMI_BASE_ADDR]
        strb    a1, [a2, #HDMI_TX_RCRDATA0 - HDMI_BASE_ADDR]
        strb    a1, [a2, #HDMI_TX_RCRDATA1 - HDMI_BASE_ADDR]
        strb    a1, [a2, #HDMI_TX_BCBDATA0 - HDMI_BASE_ADDR]
        strb    a1, [a2, #HDMI_TX_BCBDATA1 - HDMI_BASE_ADDR]

; Configure HDCP .. (disable)
        ldr     a3, [mVMODE,#mDataEnablePolarity-myHDMI_vmode_infos]
        ldr     a2, HDMI_Log    ; base address of HDMI stuff
        add     a2, a2, #HDMI_A_HDCPCFG0 - HDMI_BASE_ADDR
        ldrb    a1, [a2, #HDMI_A_HDCPCFG0 - HDMI_A_HDCPCFG0]
        bic     a1, a1, #(1<<2)   ; clr RXDetect bit
        strb    a1, [a2, #HDMI_A_HDCPCFG0 - HDMI_A_HDCPCFG0]
        ldrb    a1, [a2, #HDMI_A_VIDPOLCFG - HDMI_A_HDCPCFG0]
        teq     a3, #0
        biceq   a1, a1, #(1<<4)   ; clr data_en_pol bit
        orrne   a1, a1, #(1<<4)   ; or set data_en_pol bit
        strb    a1, [a2, #HDMI_A_VIDPOLCFG - HDMI_A_HDCPCFG0]
        ldrb    a1, [a2, #HDMI_A_HDCPCFG1 - HDMI_A_HDCPCFG0]
        orr     a1, a1, #(1<<1)   ; set encrypt disable bit
        strb    a1, [a2, #HDMI_A_HDCPCFG1 - HDMI_A_HDCPCFG0]
        EXIT

;Setup HDMI
; mHDMI -> HDMIInfo structure
;
ReInitHDMIPhy
        Entry   "a1-a4,mHDMI,mVMODE,v3,v4,v5,sb"
        mov     mHDMI, a1                       ; preserve the HDMIInfo pointer
        ldr     mVMODE, [mHDMI, #video_mode-myHDMI_infos] ; get pointer
        ldr     a1,[mVMODE,#mPixelClock-myHDMI_vmode_infos]
        mov     a2, #1           ; pixel rep =1 (could be 2 or 4)(commented out)
        orr     a2,a2,#(8<<8)    ; 8bits per compenent
        orr     a2,a2,#(1<<16)   ; DE polarity true
        mov     a3,#0            ; all opts off ( C false)
; DebugReg a1, "Freq "
; DebugReg a2, "bits "
        bl      hdmi_phy_config
        EXIT

        LTORG
; ColorSpaceCorrection coefficient tables
CSCDefault
        DCD     &00000020
        DCD     &00000000
        DCD     &00200000
        DCD     &00000000
        DCD     &00000000
        DCD     &00000020

RGBoutITU601
        DCD     &26690020
        DCD     &0e01fd74
        DCD     &dd2c0020
        DCD     &9a7e0000
        DCD     &00000020
        DCD     &3b7eb438

RGBoutITU709
        DCD     &06710020
        DCD     &a700027a
        DCD     &64320020
        DCD     &6d7e0000
        DCD     &00000020
        DCD     &257e613b

RGBinITU601
        DCD     &22139125
        DCD     &00004b07
        DCD     &00203565
        DCD     &0002cc7a
        DCD     &3475cd6a
        DCD     &00020020

RGBinITU709
        DCD     &9b0dc52d
        DCD     &00009e04
        DCD     &0020f063
        DCD     &0002117d
        DCD     &ab785667
        DCD     &00020020

; configure hdmi_phy
; a1 = pixel clock in KHz
; a2 = pixel repetition rate + (component bits/colour <<8) + (DE Polarit7<<16)
; a3 = cscOn + audioOn<<8 + cecOn<<16 + hdcpOn<<24 .. 1=off, 0=n (C FALSE - NZ)
;    hdmi_phy_configure(pclk, 0, 8, FALSE, FALSE, FALSE, FALSE);
;       IMPORT  hdmi_phy_configure
        EXPORT  hdmi_phy_config
hdmi_phy_config
        Entry   "mHDMI,mVMODE,v3,v4,v5,sb"
; n.b. keep a1,a2,a3 safe for moment
        ldr     v3, HDMI_Log    ; base address of HDMI stuff
        add     v3, v3, #HDMI_PHY_CONF0 - HDMI_BASE_ADDR
        add     v4, v3, #HDMI_MC_CLKDIS-1  - HDMI_PHY_CONF0

        mov     a4, #&ff
        strb    a4, [v3, #HDMI_PHY_MASK0 - HDMI_PHY_CONF0]

;       sort DE polarity bit
        tst     a2,#&ff0000     ; DE polarity?
        ldrb    a4, [v3, #HDMI_PHY_CONF0 - HDMI_PHY_CONF0]
        biceq   a4,a4,#(1<<1)
        orrne   a4,a4,#(1<<1)
        strb    a4, [v3, #HDMI_PHY_CONF0 - HDMI_PHY_CONF0]

;       power enable,TDMS en,  and if_sel low
;       if sel
        BitWriteByte a4, ((0<<0)), ((1<<0)), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
;       TMDS en
        BitWriteByte a4, ((1<<6)), ((1<<6)), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
;       phy power en
        BitWriteByte a4, ((1<<7)), ((1<<7)), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
;
        mov     a4, #0
        tst     a3, #1          ; cscOn bit
        movne   a4, #1          ; feedthrough off
        strb    a4, [v4, #HDMI_MC_FLOWCTRL - HDMI_MC_CLKDIS+1 ]

        mov     a4, #0         ; pixelclk and tmdsclk disable
        movne   a4, #(1<<4)    ; cscClk
        tst     a2, #&ff       ; pixel rep rate NZ?
        orrne   a4,a4,#(1<<2)  ; pRepClk
        tst     a3, #&ff00
        orrne   a4,a4,#(1<<3)  ; audClk
        tst     a3, #&ff0000
        orrne   a4,a4,#(1<<5)  ; cecClk
        tst     a3, #&ff000000
        orrne   a4,a4,#(1<<6)  ; hdcpClk
        strb    a4, [v4, #HDMI_MC_CLKDIS - HDMI_MC_CLKDIS+1 ]
;       gen2_pon=0 gen2_pddg=1
        BitWriteByte a4, ((1<<3)+(0<<4)), ((1<<3)+(1<<4)), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
;       reset the phy
        BitWriteByte a4, 1, 1, v4, HDMI_MC_PHYRSTZ - HDMI_MC_CLKDIS+1
        BitWriteByte a4, 0, 1, v4, HDMI_MC_PHYRSTZ - HDMI_MC_CLKDIS+1
;       reset heacphy
        BitWriteByte a4, 1, 1, v4, HDMI_MC_HEACPHY_RST - HDMI_MC_CLKDIS+1
;       phy test clr set
        BitWriteByte a4, (1<<5), (1<<5), v3, HDMI_PHY_TST0 - HDMI_PHY_CONF0
;       set 12c address to phy
        mov     a4 , #&69       ; i2c slave address
        strb    a4, [v3, #HDMI_PHY_I2CM_SLAVE_ADDR - HDMI_PHY_CONF0]
;       phy test clr clear
        BitWriteByte a4, (0<<5), (1<<5), v3, HDMI_PHY_TST0 - HDMI_PHY_CONF0

; now get the clock if there
; if clock is recognised, it'll program it, otherwise it'll program a default
        bl      PhyClkCompute

; write the common bits
        adrl    v4, PixTabCommon
        ldr     a1,[v4],#4
        bl      HDMI_PhyI2cWrite
        ldr     a1,[v4],#4
        bl      HDMI_PhyI2cWrite
        ldr     a1,[v4],#4
        bl      HDMI_PhyI2cWrite
        ldr     a1,[v4],#4
        bl      HDMI_PhyI2cWrite
        mov     a1, v5              ; its later... write reg &0e
        bl      HDMI_PhyI2cWrite
        ldr     a1,[v4],#4
        bl      HDMI_PhyI2cWrite


;       gen2_pon=1
        BitWriteByte a1, (1<<3), (1<<3), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
;       gen2_pddq=0
        BitWriteByte a1, (0<<4), (1<<4), v3, HDMI_PHY_CONF0 - HDMI_PHY_CONF0
        add     a3, v3, #HDMI_BASE_ADDR - HDMI_PHY_CONF0

        MOV     a1, #100*1024 ; 100msec ish
        BL      HAL_CounterDelay
        ldrb    a4, [a3,#HDMI_IH_PHY_STAT0 - HDMI_BASE_ADDR]
        EXIT
; Phy i2c setup data for different pixel clocks
; Hi 16 bits value to write, bottom 8 bits register to write
PixTabCommon
        DCD     0x00000013;   reg 0x13 // PLLPHBYCTRL (bypass and adjust off)
        DCD     0x00060017;   reg 0x17 // MSMCTRL (tdms=mpll fb clk)
        DCD     0x00050019;   reg 0x19 // TXTERM (133.33 Ohm)
        DCD     0x80090009;   reg 0x09 // CKSYMTXCTRL (override set .. ignored)
        DCD     0x80000005;   reg 0x05 // CKCALCTRL   (override set.. ignored)
PixTabCommonLen * .- PixTabCommon



HDMI_PhyI2cWrite
        Entry   "v1,v2,sb"
; DebugReg a1,"PhyWrite "
        ldr     v1, HDMI_Log
        add     v2, v1, #HDMI_PHY_CONF0 - HDMI_BASE_ADDR
;
        mov     a2, #&03              ; clear the operation IRQ bits
        strb    a2, [v1,#HDMI_IH_I2CMPHY_STAT0 - HDMI_BASE_ADDR]
        strb    a1, [v2, #HDMI_PHY_I2CM_ADDRESS_ADDR - HDMI_PHY_CONF0]
        mov     a2,a1, lsr #24  ; hi data bits
        strb    a2, [v2, #HDMI_PHY_I2CM_DATAO_1_ADDR - HDMI_PHY_CONF0]
        mov     a2,a1, lsr #16  ; lo data bits
        strb    a2, [v2, #HDMI_PHY_I2CM_DATAO_0_ADDR - HDMI_PHY_CONF0]
        mov     a1,#(1<<4)      ; write operation
        strb    a1,[v2, #HDMI_PHY_I2CM_OPERATION_ADDR - HDMI_PHY_CONF0]
        MOV     a3, #1*1024     ; 1msec ish
HDMI_PhyI2cDone
        ldrb    a2, [v1,#HDMI_IH_I2CMPHY_STAT0 - HDMI_BASE_ADDR]
        tst     a2, # ((1<<0)+(1<<1)); phy error or phy done
        bne     HDMI_PhyI2cexit
        MOV     a1, #1 ; 1usec ish
        BL      HAL_CounterDelay
        subs    a3,a3,#1
        bgt     HDMI_PhyI2cDone        ; not timed out
        mov     a1, #1          ; error exit
        EXIT
HDMI_PhyI2cexit
        tst     a2, #(1<<0)
        movne   a1, #1           ; error exit
        moveq   a1, #0           ; completed
        EXIT

HDMI_PhyI2cRead
        Entry   "v1,v2,sb"
        EXIT

; compute optimum phy clk control stuff for current o/p
; a1 = pixel clock in 1KHz
; a2 = pixel repetition rate + (component bits/colour <<8) + (DE Polarit7<<16)
; on exit v5 = reg&0e value to write
PhyClkCompute
        Entry   "a1-a4, v1-v4"
; DebugTXS "PhyClkCompute "
; DebugRegNCR a1, "f= "
; DebugReg a2, "bits= "
; 1 compute the clock range into v4 for reg15 use
; clock into v3 for reg10 use
        mov     v3, #2_011100
        orr     v3, v3, #2_100100 << 6
        mov     v4, #0
        ldr     v2, =45250              ; 45.25MHz
        cmp     a1, v2
        ble     clockknown
        mov     v4, #1
        ldr     v2, =65000              ; 65.0MHz
        cmp     a1, v2
        bicgt   v3, v3, #2_111111 << 6       ;
        orrgt   v3, v3, #2_011011 << 6       ; flag over 65
        ldr     v2, =92500              ; 92.5MHz
        cmp     a1, v2
        ble     clockknown
        bic     v3, v3, #2_111111 << 6
        orr     v3, v3, #2_100100 << 6
        mov     v4, #2
        ldr     v2, =130000             ; 130.0MHz
        cmp     a1, v2
        bicgt   v3, v3, #2_111111 << 6
        orrgt   v3, v3, #2_011011 << 6       ; flag over 130
        ldr     v2, =184500             ; 184.5MHz
        cmp     a1, v2
        ble     clockknown
        mov     v4, #3
clockknown

; compute reg 6 value to v2
        mov     v2, #0
        and     v1, a2, #&ff00          ; get bits/colour
        teq     v1, #10
        moveq   v2, #1
        teq     v1, #12
        moveq   v2, #2
        teq     v1, #16
        moveq   v2, #3                  ; prep_div[1..0]
        mov     v2, v2, lsl #(6+4)         ; tx and clk edge rates slow
        teq     v4, #0
        orreq   v2, v2, #2_1111
        teq     v4, #1
        orreq   v2, v2, #2_1010
        teq     v4, #2
        orreq   v2, v2, #2_0101
        mov     v2, v2, lsl #3        ; pll and mpll prog div control
; **** at this point, since RISCOS only uses 8 bit colour depth
; **** we don't cover other bit depths
        mov     v2, v2, lsl #(2)        ; pixel rep 0, colour depth 8 = 0
        and     v1, v2, #&6000          ; get prep_div colour bits
        orr     v2, v2, v1, lsr #13
; compute reg&e value to v1
        ldr     v1, =150000000          ; 150MHz
        cmp     a1, v1
        movlt   v1, #&0210
        ldrge   v1, =&0129

        mov     v2, v2, lsl #16
        add     a1, v2, #CREGS_PLL_DIV_ADDR
; DebugRegNCR a1, "Reg &06= "
        bl      HDMI_PhyI2cWrite

; write out reg 0x10
        mov     v3, v3, lsl #16
        add     a1, v3, #CREGS_PLL_PROP_INT_CNTRL_ADDR
; DebugRegNCR a1, "Reg &10= "
        bl      HDMI_PhyI2cWrite

; write out reg 0x15
        add     v4, v4, v4, lsl #2
        mov     v4, v4, lsl #16
        add     a1, v4, #CREGS_PLL_GMP_CNTRL_ADDR
; DebugRegNCR a1, "Reg &15= "
        bl      HDMI_PhyI2cWrite
        mov     v1, v1, lsl #16
        add     v5, v1, #CREGS_VLEVCTRL_ADDR ; used later
; DebugReg v5, "Reg &0e= "
;        bl     HDMI_PhyI2cWrite

        EXIT


; Configure IPU's display interface
;void ipu_di_config(uint32_t ipu_index, uint32_t di, ips_dev_panel_t * panel)
; so
; a1 = ipu_index (0 or 1)
; a2 = display channel in IPU (0 or 1) (di)
; a3 -> display panel definition
ConfigIPU_DI
        Entry   "a1,a2,a3,a4,v1,v2,mPANEL,v4,v5,sb"
        mov     mPANEL, a3
        orr     v2, a1, a2, lsl #8      ; combine ipu and di<<8 to v2
        tst     v2, #1<<8               ; DI 0 or 1
        ldreq   v1, IPU1_Log            ; base register address
        ldrne   v1, IPU2_Log            ;
        add     v1, v1, #IPU_DI0_GENERAL_OFFSET
; compute di waveform vertical up/down stuff
; (Set up pixel clock cfom CLKGEN0/1 register pair)
        ldr     a1, [mPANEL, #mvsync_start_width - myHDMI_dev_panel]
        ldr     a2, [mPANEL, #mvsync_end_width - myHDMI_dev_panel]
        add     a2, a2, a1
        ldr     a1, [mPANEL, #mvsync_width - myHDMI_dev_panel]
        add     a2, a2, a1
        ldr     a1, [mPANEL, #mheight - myHDMI_dev_panel]
        add     a2, a2, a1
        add     a2, a2, #1              ; vTotal +1 (Screen Height+1)
        mov     a1, #&1000
        sub     a1, a1, #1              ; derive mask &fff
        and     v4, a1, a2
        str     v4, [v1, #IPU_DI0_SCR_CONF_OFFSET-IPU_DI0_GENERAL_OFFSET]
; DebugReg v4,"set display height +1 to dio scr conf "
; compute pixel clock period stuff
        ldr     a4, [mPANEL, #mclk_sel - myHDMI_dev_panel]
        teq     a4, #1
; desired pixel clock for panel to v2
        ldr     a1, [mPANEL, #mpixel_clock - myHDMI_dev_panel]
        ldrne   a2, = IPU_DEFAULT_WORK_CLOCK
        moveq   a2, a1
; DebugReg a1, "pixel clk "
        mov     a1, a1, lsr #4          ; there are 4bits of hex decimal place (!!)
; DebugReg a2, "default pixel clk "
        bl      udivide
;  DebugReg a1, "Result "
        and     a2, a1, #&f             ; a2 is base 16 decimal bit
        mov     a1, a1, lsr #4          ; a1 result
; set di pointer config
;    /* config PIN_15(DRDY signal)
;       set DI_PIN15 to be waveform according to DI data wave set 2 pointer 0 */
;    ipu_di_pointer_config(ipu_index, di, 0, div - 1, div - 1, 0, &pt[0]);
        sub     a3, a1, #1
        add     a3, a3, a3,lsl #8
        mov     a3, a3, lsl #16
        add     a3, a3, #(2<<8)         ; pt[4] = 2 , rest of pt = 0
        tst     v2, #1<<8               ; DI 0 or 1
        ; use first pointerset (offset 0*4)
        add     v4, v1, #IPU_DI0_DW_GEN_0_OFFSET-IPU_DI0_GENERAL_OFFSET
        addne   v4, v4, #IPU_DI1_DW_GEN_0_OFFSET-IPU_DI0_DW_GEN_0_OFFSET
        str     a3, [v4]
;  DebugReg a3, "wrote to DW Gen0 "
; set up and down of datawave set 2
;    ipu_di_waveform_config(ipu_index, di, 0, 2, 0, div * 2)
        mov     a3, a1, lsl #1           ; one bit for fraction part
        mov     a3, a3, lsl #16          ; set for up, down at 0
        tst     v2, #1<<8               ; DI 0 or 1
        ; use first pointerset (offset 0*4) waveset (2*0x30)
        add     v4, v1, #((IPU_DI0_DW_SET0_0_OFFSET-IPU_DI0_GENERAL_OFFSET)+(4*0)+(2*&30))
        addne   v4, v4, #IPU_DI1_DW_GEN_0_OFFSET-IPU_DI0_DW_GEN_0_OFFSET
        str     a3, [v4]
;  DebugReg a3, "wrote to DWSet2 "
;  DebugReg v4, " at addr  "
        mov     a3, a1, lsl #4           ; whole number part
        add     a3, a3, a2               ; fractional part
; DebugReg a1, "startstuff "
;        teq    a1, #1
;        mov    a2, a1, lsl # 1
;        subne  a2, a2, #1
;    ipu_di_bsclk_gen(ipu_index, di,fracdiv /*div << 4*/, clkUp, clkDown);
;        orr    a4, a1, a2, lsl #16      ; up and down edge bits
        mov     a4, #1<<16              ; up at 0, down at 1
        tst     v2, #1<<8               ; DI 0 or 1
        add     v4, v1, #IPU_DI0_BS_CLKGEN0_OFFSET-IPU_DI0_GENERAL_OFFSET
        addne   v4, v4, #IPU_DI1_GENERAL_OFFSET-IPU_DI0_GENERAL_OFFSET
        str     a3, [v4]
        str     a4, [v4, #IPU_DI0_BS_CLKGEN1_OFFSET-IPU_DI0_BS_CLKGEN0_OFFSET]
;  DebugReg a3, "wrote to clkgen0 "
;  DebugReg a4, "wrote to clkgen1 "

; now let us set up the various sync waveforms
; all driven from the pixel clock
;       DI0 configuration:
;       hsync           ------   DI0 pin 2
;       vsync           ------   DI0 pin 3
;       data_en         ------   DI0 pin 15
;       clk             ------   DI0 disp clk
;       COUNTER 2       ------   VSYNC
;       COUNTER 3       ------   HSYNC
;
; compute base address needed
        tst     v2, #1<<8               ; DI 0 or 1
        mov     v4, v1
        addne   v4, v4, #IPU_DI1_DW_GEN_0_OFFSET-IPU_DI0_DW_GEN_0_OFFSET
; Internal HSYNC -- this defines the total horizontal clocks
        ldr     a3, [mPANEL, #mhsync_start_width - myHDMI_dev_panel]
        ldr     a4, [mPANEL, #mhsync_end_width - myHDMI_dev_panel]
        add     a4, a4, a3
        ldr     a3, [mPANEL, #mhsync_width - myHDMI_dev_panel]
        add     a4, a4, a3
        ldr     a3, [mPANEL, #mwidth - myHDMI_dev_panel]
        add     a4, a4, a3
        sub     v5, a4, #1              ; hTotal -1 (Screen Width-1)
; DebugReg v5 ,"total line dots .. sync is 1 dot wide at start "
        mov     a1, v5, lsl #16         ; Counter (horizontal screen width)
                                        ; no start delay
        mov     a2, #(1) <<16           ; clk srce = bitclock (pixel clk)
        ldr     a3, =&10000000          ; autoreload, counter falling edge after 1 cycle

        mov     a4, #InternalHSYNCCntr  ; first counter (1)(internal hsync), step/repeat = 0
        bl      WriteDIWave             ;
; Output HSYNC   ... this windows the actual video pixels
        mov     a1, v5, lsl #16         ; Counter (horizontal screen width)
                                        ; no start delay
        mov     a2, #(1) <<16           ; clk srce = bitclock (pixel clk)
        ldr     a4, [mPANEL, #mdelay_h2v - myHDMI_dev_panel] ; delay start to video start
        orr     a1, a1, a4, lsl #3      ; start delay
        orr     a2, a2, #( 1)           ; clk srce = bitclock (pixel clk)
        ldr     a3, =&10000000          ; autoreload
        ldr     a4, [mPANEL, #mhsync_width - myHDMI_dev_panel] ; visible width
        orr     a3, a3, a4, lsl #17     ; falling edge pos (allow for fraction bit)
; DebugReg a3, "H start in bottom 16- end edge in top 16 "
        mov     a4, #OutputHSYNCCntr    ; second counter (2)(o/p hsync) and step/repeat = 0
        bl      WriteDIWave
; Output VSync   .. outpt VSYNC
        ldr     a3, [mPANEL, #mvsync_start_width - myHDMI_dev_panel]
        ldr     a4, [mPANEL, #mvsync_end_width - myHDMI_dev_panel]
        add     a4, a4, a3
        ldr     a3, [mPANEL, #mvsync_width - myHDMI_dev_panel]
        add     a4, a4, a3
        ldr     a3, [mPANEL, #mheight - myHDMI_dev_panel]
        add     a4, a4, a3
        sub     a1, a4, #1              ; vTotal -1 (Screen Height-1)
; DebugRegNCR a1, "total line count "
        mov     a1, a1, lsl #16         ; Counter (vertical screen height)
                                        ; no start delay
        mov     a2, #(InternalHSYNCCntr+1) <<16 ; clk srce = internal hsync counter
        ldr     a3, =&30002000          ; autoreload , polgenen 1, poltrigsel 2
        ldr     a4, [mPANEL, #mvsync_width - myHDMI_dev_panel]
        orr     a3, a3, a4, lsl #17         ; falling edge pos (allow for fraction bit)
; DebugReg a3, "V sync start in bottom 16- end edge in top 16 "
        mov     a4, #OutputVSYNCCntr    ; third counter (3)(o/p vsync) and step/repeat = 0
        bl      WriteDIWave
; Active Lines start points
        ldr     a1, [mPANEL, #mvsync_start_width - myHDMI_dev_panel]
                                        ; clock delay
        mov     a2, #(OutputHSYNCCntr + 1) <<16       ; clk srce o/p hsync
        orr     a2, a2, #(OutputHSYNCCntr + 1)        ; delay clk srce o/p hsync
        mov     a3, #&0000000           ; no autoreload
        orr     a3, a3, #(OutputVSYNCCntr + 1)<<25    ; count clr from vsync
        ldr     a4, [mPANEL, #mheight - myHDMI_dev_panel]
        mov     a4, a4, lsl #8          ; step repeat count
; DebugRegNCR a1, "VSync start line "
; DebugReg a4, "v repeat count "
        orr     a4, a4, #ActiveLineCntr ; fourth counter(5) = activelinestart
        bl      WriteDIWave
; Active clock start point
        ldr     a1, [mPANEL, #mhsync_start_width - myHDMI_dev_panel] ; delay count
        mov     a2, #(1) <<16           ; use bit clock for counter
        orr     a2, a2, #( 1)           ; use bitclock for delay
        mov     a3, #(ActiveLineCntr+1)<<25; counter cleared by hsync

        ldr     a4, [mPANEL, #mwidth - myHDMI_dev_panel]
        mov     a4, a4, lsl #8
; DebugReg a4, "Active hStart point "
        orr     a4, a4,#ActivePixelCntr ; fifth counter (6) = active pixel start
        bl      WriteDIWave
; now tie this all together and turn on using the active data
;  used for fifth counter above
;    ipu_di_interface_set(ipu_index, di, panel, 2, vsync_sel, hsync_sel);
        mov     a1, #2                  ; line_prediction .. start data 2 lines early
        mov     a2, #OutputVSYNCCntr-1  ; vsync source is vsync o/p counter
        mov     a3, #OutputHSYNCCntr-1  ; hsync source is hsync o/p counter
        bl      StartDIWave
        EXIT

; program up a DI waveform
; entry:
; v1 ->  IPU_DI0_GENERAL_OFFSET
; a1 = counter value << 16
;    + counter start delay
; a2 = counter clock srce << 16
;    + start clock source
; a3 = Polarity en <<29 (2 bit)
;    + autoreload <<28 (1 bit)
;    + counter clear source<<25 (3 bit)
;    + counter fall edge position<<16 (8bit + 1 fraction bit)
;    + counter toggle trigger select <<12 (3bit)
;    + counter polarity clr select <<9 (3 bit)
;    + counter rise edge position<<0 (8bit + 1 fraction bit)
; a4 = waveset number to program (starting at 1)
;    + step/repeat value<<8 (9 bits)
; v2 = ipu and di<<8
WriteDIWave
        Entry  "a4,v1,v2,v4"
; DebugReg a1, "Wave: Cnt<<16 +delay "
; DebugReg a2, "CntSrce<<16 + start srce "
; DebugReg a3, "fall(8.1)<<16 +togTrig<<12+ rise(8.1) "

; DebugReg v2,"Write DI Waveset for ipu and di<<8 "
        orr     a1, a2, a1, lsl #3      ; combine the waveset0 bits
; compute base address needed
        tst     v2, #1<<8               ; DI 0 or 1
                                        ; correct IPU already selected
                                        ; if NE, allow for DI1 instead
        addne   v1, v1, #IPU_DI1_DW_GEN_0_OFFSET-IPU_DI0_DW_GEN_0_OFFSET

        and     v2, a4, #7              ; isolate the clkset bits
        add     v4, v1, v2, lsl #2              ; 4 bytes per set
        sub     v4, v4, #4              ; -4 offset allows for first counter being no 1
        str     a1, [v4, #IPU_DI0_SW_GEN0_1_OFFSET-IPU_DI0_GENERAL_OFFSET]
        str     a3, [v4, #IPU_DI0_SW_GEN1_1_OFFSET-IPU_DI0_GENERAL_OFFSET]
; DebugReg a1," DIWave0  "
; DebugReg a3," DIWave1            "
        mov     a1, #&1000
        sub     a1, a1, #1              ; 0xfff
        sub     a4, a4, #1              ; compensate for first counter known as 1
        tst     a4, #1                  ; even or odd?
        mov     a2, a4, lsr #8          ; even
        movne   a2, a2, lsl #16         ; odd half
        movne   a1, a1, lsl #16         ; get relevant mask bits
        and     a4, a4, #6              ; isolate counter select bits less lsb`
        add     v1, v1, a4, lsl #1      ; 2 entries per word         `
        ldr     a3, [v1, #IPU_DI0_STP_REP_1_OFFSET-IPU_DI0_GENERAL_OFFSET]
        bic     a3, a3, a1
        orr     a3, a3, a2
        str     a3, [v1, #IPU_DI0_STP_REP_1_OFFSET-IPU_DI0_GENERAL_OFFSET]
; DebugReg a3," step repeat                   "
; DebugCR


        EXIT

; Triggerup a DI waveform set
; entry:
; v1 ->  IPU_DI0_GENERAL_OFFSET
; a1 = line_prediction value
; a2 = vsync source counter
; a3 = hsync source counter
; v2 = ipu and di<<8
; v3 = mPANEL -> panel description
;void ipu_di_interface_set(uint32_t ipu_index, uint32_t di, ips_dev_panel_t * panel,
;                          uint32_t line_prediction, uint32_t vsync_sel, uint32_t hsync_sel)
StartDIWave
        Entry  "a4,v1,v2,v4"
; DebugRegNCR v2,"Start DI Waveset for ipu and di<<8 "
; DebugRegNCR a2,"Start waveset vsync src counter "
; DebugReg a3,"  hsync src counter "
; compute base address needed
        tst     v2, #1<<8               ; DI 0 or 1
                                        ; correct IPU already selected
        addne   v4, v1, #IPU_DI1_DW_GEN_0_OFFSET-IPU_DI0_DW_GEN_0_OFFSET
        moveq   v4, v1
        orr     a1, a1, a2, lsl #13     ; combine
        str     a1, [v4, #IPU_DI0_SYNC_AS_GEN_OFFSET-IPU_DI0_GENERAL_OFFSET]
        ldr     a1, [v4, #IPU_DI0_GENERAL_OFFSET-IPU_DI0_GENERAL_OFFSET]

        mov     a1, a3, lsl #28         ; select line counter clock source
                                        ; and set dio o/p clock active low
        orr     a1, a1, #VSYNC_EXTERNAL << 21
        ldr     a4, [mPANEL, #mclk_sel - myHDMI_dev_panel]
        and     a4, a4, #1
        orr     a1, a1, a4,lsl #20      ; set for external clock if needed
        ldr     a4, [mPANEL, #mvsync_pol - myHDMI_dev_panel]
        and     a4, a4, #1
        orr     a1, a1, a4, lsl a2      ; toggle vsync o/p polarity if needed
        ldr     a4, [mPANEL, #mhsync_pol - myHDMI_dev_panel]
        and     a4, a4, #1
        orr     a1, a1, a4, lsl a3      ; toggle hsync o/p polarity if needed
        str     a1, [v4, #IPU_DI0_GENERAL_OFFSET-IPU_DI0_GENERAL_OFFSET]

        mov     a1, #0
        ldr     a4, [mPANEL, #mdrdy_pol - myHDMI_dev_panel]
        and     a4, a4, #1
        orr     a1, a1, a4, lsl #4      ; toggle drdy_polarity_15 pin polarity if needed
        ldr     a4, [mPANEL, #mdata_pol - myHDMI_dev_panel]
        and     a4, a4, #1
        orrne   a1, a1, a4, lsl #7      ; toggle data polarity pin if needed
        str     a1, [v4, #IPU_DI0_POL_OFFSET-IPU_DI0_GENERAL_OFFSET]

        sub     v1, v1, #IPU_DI0_GENERAL_OFFSET-IPU_IPU_CONF_OFFSET
        ldr     a1, [v1, #IPU_IPU_DISP_GEN_OFFSET-IPU_IPU_CONF_OFFSET]
        tst     v2, #1<<8               ; DI 0 or 1
        orreq   a1, a1, #1<<24          ; DI0 counter release
        orrne   a1, a1, #1<<25          ; DI1 counter release
        str     a1, [v1, #IPU_IPU_DISP_GEN_OFFSET-IPU_IPU_CONF_OFFSET]

        EXIT


; IPU cpmem access routines.
; these are 160 bit megawords. each channel as 2
; entry:
;       a1 ignored
;       a2 ignored
;       a3 = CPMem Field word
;            ((0|1)<<0 + startbit<<8 + field width<<16)
;       a4 = channel base address
; ASSUMES that all bits are within 1 megaword.
; exit:
;       a1 = contents
;       a2-a4 preserved
;
IPU_CPMem_Read
        Entry   "a2,a3,a4,v1,v2,v3,v4,v5"
; DebugReg a3," a3 "
; DebugReg a4," a4 "
        tst     a3, #&1                 ; check for megaword 1
        addne   a4, a4, #8*4            ; offset to word 1
        mov     a3, a3, lsr #8          ; and remove the bit
        and     v1, a3, #&1f            ; get start bit in word
        bic     a2, a3, #&1f            ; and start word
        bic     a2, a2, #&ff00          ; clear out the field width bits
; DebugReg v1, " in wrd start bit: "
        add     v2, a4, a2, lsr #3      ; get start word address
        mov     a4, a3, lsr #8          ; word field size
; DebugReg a4, " fieldsize: "
        mov     a3, #1
        mov     a3, a3, lsl a4
        sub     a3, a3, #1              ; convert a3 to bitmask
; DebugReg a3, " mask: "
        movs    v3, a3, lsl v1          ; put mask in place, mask overflow if CS
                                        ; now v1 = start bit in word
                                        ;     v2 = start word address
                                        ;     a3 = field mask
                                        ;     a4 = field width
        bcc     %ft01                   ; no mask overflow between words
        rsb     a4, v1, #32             ; bits in next word
        mov     v4, a3, lsr a4          ; remaining mask bits
        ; v2 = 1st word addr
        ; a4 = bits not in 2nd word
        ; v4 = mask
        ldr     a2, [v2, #4]
; DebugReg a2," 1read :        "
; DebugReg v2," 1reading from: +4: "
; DebugReg v4," 1masking        : "
        and     a2, a2, v4
        mov     a2, a2, lsl a4
; DebugReg a4," 1left shift   "

01
        ; v3 = current word mask
        ; v2 = address
        ; v1 = start bit position
        ldr     a1, [v2]
; DebugReg a1," 2read :        "
; DebugReg v2," 2reading from: : "
; DebugReg v3," 2masking        : "
; DebugReg v1," 2rightshift      : "
        and     a1, a1, v3
        mov     a1, a1, lsr v1
        orr     a1, a1, a2
; DebugReg a1,"             read result      : "
        EXIT
        LTORG

; IPU cpmem access routines.
; these are 160 bit megawords. each channel as 2
; entry:
;       a1 data to write
;       a2 ignored
;       a3 = CPMem Field word
;            ((0|1)<<0 + startbit<<8 + field width<<16)
;       a4 = channel base address
; ASSUMES that all bits are within 1 megaword.
; exit:
;       a1 = contents
;       a2-a4 preserved
;
        EXPORT  |IPU_CPMem_Write|
IPU_CPMem_Write
        Entry   "a1,a2,a3,a4,v1,v2,v3,v4,v5"
; DebugReg a1," write "
; DebugReg a3," a3 "
; DebugReg a4," a4 "
        tst     a3, #&1                 ; check for megaword 1
        addne   a4, a4, #8*4            ; offset to word 1
        mov     a3, a3, lsr #8          ; and remove the bit
        and     v1, a3, #&1f            ; get start bit in word
        bic     a2, a3, #&1f            ; and start word
        bic     a2, a2, #&ff00          ; clear out the field width bits
; DebugReg v1, " in wrd start bit: "
        add     v2, a4, a2, lsr #3      ; get start word address
        mov     a4, a3, lsr #8          ; word field size
; DebugReg a4, " fieldsize: "
        mov     a3, #1
        mov     a3, a3, lsl a4
        sub     a3, a3, #1              ; convert a3 to bitmask
; DebugReg a3, " mask: "
        movs    v3, a3, lsl v1          ; put mask in place, mask overflow if CS
                                        ; now v1 = start bit in word
                                        ;     v2 = start word address
                                        ;     a3 = field mask
                                        ;     a4 = field width
        bcc     %ft01                   ; no mask overflow between words
        rsb     a4, v1, #32             ; bits in next word
        mov     v4, a3, lsr a4          ; remaining mask bits
        ; a1 = data
        ; v2 = 1st word addr
        ; a4 = bits not in 2nd word
        ; v4 = mask
        ldr     a2, [v2, #4]
; DebugReg a2," 3read :        "
; DebugReg v2," 3reading from: +4: "
; DebugReg v4," 3masking        : "
        bic     a2, a2, v4              ; clear them
        orr     a2, a2, a1, lsr a4      ; new bits in place
; DebugReg a4," 3left shift   "
        str     a2, [v2, #4]            ; and write back
; DebugReg a2,"           3wrote to +4      : "

01
        ; a1 = data to write
        ; v3 = current word mask
        ; v2 = address
        ; v1 = start bit position
        ldr     a2, [v2]
; DebugReg a2," 4read :        "
; DebugReg v2," 4reading from: : "
; DebugReg v3," 4maskingv        : "
; DebugReg a3," 4maskinga        : "
; DebugReg v1," 4rightshift      : "
        bic     a2, a2, v3              ; clear old data
        mov     a1, a1, lsl v1          ; shift bits up
; DebugReg a1,"4try write "
        and     a1, a1, v3              ; and mask
        orr     a2, a1, a2              ;combine
        str     a2, [v2]
; DebugReg a2,"           4wrote          : "
        EXIT

; Setup Image DMA controller
; on entry,
; a1 = ipu index  (1 or 2)
; a2 -> idmac config structure
; (structure defined wrt v4)
        EXPORT  |IDMACSetup|
IDMACSetup
        Entry   "a2, a3, a4, v1, v2, v3, v4, sb"
; use a1 to get channel address to sb
        teq     a1, #1                  ; IPU 1 or 2
        ldreq   v4, IPU1_Log            ; base register address
        ldrne   v4, IPU2_Log            ;
        add     v2, v4, #IPU_MEMORY_OFFSET
        add     v4, v4, #IPU_REGISTERS_OFFSET
        mov     v3, a2                  ; config structure address (map v3 in hdr:cpmem)
; DebugReg v2,"ipumem "
; DebugReg v4,"ipureg "
; turn channel off
        ldr     a4, iii_channel
        mov     a3, a4, lsr #5          ; word offset
        and     a1, a4, #&1f            ; bit in word
        mov     a2, #1
        mov     a2, a2, lsl a1          ; enable bit
        mov     a3, a3, lsl #2          ; convert to word offset
        add     a3, a3, #IPU_IDMAC_CH_EN_1_OFFSET - IPU_IDMAC_CONF_OFFSET
        add     a3, a3, #IPU_IDMAC_CONF_OFFSET - IPU_REGISTERS_OFFSET
        add     a3, a3, v4              ; compute enable address
; DebugReg a3,"ipur en addr "
        ldr     a1, [a3]
        bic     a1, a1, a2              ; turn channel off
        str     a1, [a3]
; DebugReg a2, "off: clr bit "
; DebugReg a3, "at addr "
        Push    "a2, a3"                ; remember these
; clear channel to 0  (a4 = channel)
; DebugReg a4, "channel number "
        add     a4, v2, a4, lsl #6      ; &40 per cpmem megaword pair
                                        ; a4 = base of channel
; DebugReg a4, "channel base address "
        mov     a1, #&40
        mov     a2, #0
1       subs    a1, a1, #4
        str     a2, [a4, a1]
        bgt     %bt1

; set addr0
        ldr     a1, iii_addr0
        mov     a1, a1, lsr #3          ; physical address/8
        ldr     a3, =CP_EAB0
        bl      IPU_CPMem_Write

; set addr1
        ldr     a1, iii_addr1
        mov     a1, a1, lsr #3          ; physical address/8
        ldr     a3, =CP_EAB1
        bl      IPU_CPMem_Write
; set width
        ldr     a1, iii_width
        sub     a1, a1, #1              ; width-1
        ldr     a3, =CP_FW
        bl      IPU_CPMem_Write
; set height
        ldr     a1, iii_height
        sub     a1, a1, #1              ; height-1
        ldr     a3, =CP_FH
        bl      IPU_CPMem_Write
; sort out pixel format
        ldr     a2, iii_pixel_format
; DebugReg a2, "Pixel format "
        mov     a1, a2
        ldr     a3, =CP_PFS
        bl      IPU_CPMem_Write
        ldr     a1, iii_npb                ;  pixels in burst???
        ldr     a3, =CP_NPB
        bl      IPU_CPMem_Write
        ; a2 = pixel format
        ; a4 -> channel base
        ; v3 -> ipu_idmac_info structure
; DebugReg a2, "Pixel format "
        teq     a2, #NON_INTERLEAVED_YUV444
        bne     %ft01
        ldr     v1, iii_u_offset
        mov     a1, v1, lsr #3
        ldr     a3, =CPN_UBO
        bl      IPU_CPMem_Write
        mov     a1, v1, lsr #2
        ldr     a3, =CPN_VBO
        bl      IPU_CPMem_Write
010     ldr     v2, iii_sl
        sub     a1, v2, #1
        ldr     a3, =CPN_SLUV
        bl      IPU_CPMem_Write
011     ldr     v1, iii_so
        ldr     v2, iii_sl
        teq     v1, #1
        moveq   v1, v2, lsl #1
        subeq   v1, v1, #1
        moveq   a1, v2, lsr #3
        subne   v1, v2, #1
        ldreq   a3, =CP_ILO
        bleq    IPU_CPMem_Write
        mov     a1, v1
        ldr     a3, =CPN_SLY
        bl      IPU_CPMem_Write

        b       %ft99

01
        teq     a2, #NON_INTERLEAVED_YUV422
        bne     %ft02
        ldr     v1, iii_u_offset
        mov     a1, v1, lsr #3
        ldr     a3, =CPN_UBO
        bl      IPU_CPMem_Write
        mov     a1, #3
        mul     a1, v1, a1
        mov     a1, a1, lsr #4
        ldr     a3, =CPN_VBO
        bl      IPU_CPMem_Write
021     mov     a1, v1, lsr #1
        sub     a1, a1, #1
        ldr     a3, =CPN_SLUV
        bl      IPU_CPMem_Write
        b       %bt011
02
        teq     a2, #NON_INTERLEAVED_YUV420
        bne     %ft03
        ldr     v1, iii_u_offset
        mov     a1, #5
        mul     a1, v1, a1
        mov     a1, a1, lsr #5
        ldr     a3, =CPN_UBO
        bl      IPU_CPMem_Write
        mov     a1, v1, lsr #2
        ldr     a3, =CPN_VBO
        bl      IPU_CPMem_Write
        b       %bt021
        b       %ft99
03
        teq     a2, #PARTIAL_INTERLEAVED_YUV422
        bne     %ft04
031     ldr     v1, iii_u_offset
        mov     a1, v1, lsr #3
        ldr     a3, =CPN_UBO
        bl      IPU_CPMem_Write
        ldr     a3, =CPN_VBO
        bl      IPU_CPMem_Write
        b       %bt010

04
        teq     a2, #PARTIAL_INTERLEAVED_YUV420
        bne     %ft05
        b       %bt031
05
        teq     a2, #INTERLEAVED_LUT
        bne     %ft06
        mov     a1, #5  ;8bpp
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #8
        ldr     a3, =CPI_OFS0          ; red
        bl      IPU_CPMem_Write
        mov     a1, #16
        ldr     a3, =CPI_OFS1          ; green
        bl      IPU_CPMem_Write
        mov     a1, #24
        ldr     a3, =CPI_OFS2          ; blue
        bl      IPU_CPMem_Write
        mov     a1, #0                 ; alpha
        ldr     a3, =CPI_OFS3
        bl      IPU_CPMem_Write
        b       %ft071
06
        teq     a2, #INTERLEAVED_GENERIC
        bne     %ft07
        b       %ft99
07
        teq     a2, #INTERLEAVED_ARGB8888
        bne     %ft08
        mov     a1, #0
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #24
        ldr     a3, =CPI_OFS0          ; red
        bl      IPU_CPMem_Write
        mov     a1, #8
        ldr     a3, =CPI_OFS1          ; green
        bl      IPU_CPMem_Write
        mov     a1, #16
        ldr     a3, =CPI_OFS2          ; blue
        bl      IPU_CPMem_Write
        mov     a1, #0
        ldr     a3, =CPI_OFS3          ; alpha
        bl      IPU_CPMem_Write
071     ldr     v1, iii_so             ; so 1 = interlaced
        ldr     v2, iii_sl
        teq     v1, #1                 ; eq = interlaced
        moveq   v1, v2, lsl #1
        subeq   v1, v1, #1
        moveq   a1, v2, lsr #3         ; interlace offset 1 line ??
        subne   v1, v2, #1
        ldreq   a3, =CP_ILO            ; interlace offset/8
        bleq    IPU_CPMem_Write
        mov     a1, v1
        ldr     a3, =CPI_SL
        bl      IPU_CPMem_Write

        b       %ft99
08
        teq     a2, #INTERLEAVED_ABGR8888
        bne     %ft081
        mov     a1, #0
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #8-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #16
        ldr     a3, =CPI_OFS0          ; red
        bl      IPU_CPMem_Write
        mov     a1, #8
        ldr     a3, =CPI_OFS1          ; green
        bl      IPU_CPMem_Write
        mov     a1, #24
        ldr     a3, =CPI_OFS2          ; blue
        bl      IPU_CPMem_Write
        mov     a1, #0                 ; alpha
        ldr     a3, =CPI_OFS3
        bl      IPU_CPMem_Write
        b       %bt071

        b       %ft99
081
        teq     a2, #INTERLEAVED_RGB
        bne     %ft09
; DebugReg a2, "IL RGB reached "
        b       %ft99
09
        teq     a2, #INTERLEAVED_BGR
        bne     %ft091
        b       %ft99
091
        teq     a2, #INTERLEAVED_RGBLUT8
        bne     %ft0911
; DebugReg a2, "IL RGBLUT8 reached "
        b       %ft99
0911
        teq     a2, #INTERLEAVED_RGB565
        bne     %ft10
; DebugReg a2, "IL rgb565 reached "
        mov     a1, #3
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #6-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #0-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #0
        ldr     a3, =CPI_OFS0
        bl      IPU_CPMem_Write
        mov     a1, #5
        ldr     a3, =CPI_OFS1
        bl      IPU_CPMem_Write
        mov     a1, #11
        ldr     a3, =CPI_OFS2
        bl      IPU_CPMem_Write
        mov     a1, #16
        ldr     a3, =CPI_OFS3
        bl      IPU_CPMem_Write
        b       %bt071


10
        teq     a2, #INTERLEAVED_BGR565
        bne     %ft101
; DebugReg a2, "IL bgr565 reached "
        mov     a1, #3
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #6-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #0-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #11
        ldr     a3, =CPI_OFS0
        bl      IPU_CPMem_Write
        mov     a1, #5
        ldr     a3, =CPI_OFS1
        bl      IPU_CPMem_Write
        mov     a1, #10
        ldr     a3, =CPI_OFS2
        bl      IPU_CPMem_Write
        mov     a1, #16
        ldr     a3, =CPI_OFS3
        bl      IPU_CPMem_Write
        b       %bt071


101
        teq     a2, #INTERLEAVED_ABGR1555
        bne     %ft1011
; DebugReg a2, "IL il_abgr1555 reached "
        mov     a1, #3
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #1-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #6
        ldr     a3, =CPI_OFS0
        bl      IPU_CPMem_Write
        mov     a1, #1
        ldr     a3, =CPI_OFS1
        bl      IPU_CPMem_Write
        mov     a1, #11
        ldr     a3, =CPI_OFS2
        bl      IPU_CPMem_Write
        mov     a1, #0
        ldr     a3, =CPI_OFS3
        bl      IPU_CPMem_Write
        b       %bt071


1011

        teq     a2, #INTERLEAVED_TBGR1555
        bne     %ft10111
;; DebugReg a2, "IL il_tbgr1555 reached "
        mov     a1, #3
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID0
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID1
        bl      IPU_CPMem_Write
        mov     a1, #5-1
        ldr     a3, =CPI_WID2
        bl      IPU_CPMem_Write
        mov     a1, #1-1
        ldr     a3, =CP_WID3
        bl      IPU_CPMem_Write
        mov     a1, #6
        ldr     a3, =CPI_OFS0           ;red
        bl      IPU_CPMem_Write
        mov     a1, #1
        ldr     a3, =CPI_OFS1           ;green
        bl      IPU_CPMem_Write
        mov     a1, #11
        ldr     a3, =CPI_OFS2           ;blue
        bl      IPU_CPMem_Write
        mov     a1, #0
        ldr     a3, =CPI_OFS3           ; alpha ...
        bl      IPU_CPMem_Write
        b       %bt071


10111
        teq     a2, #INTERLEAVED_Y1U1Y2V1
        bne     %ft11

        b       %ft99
11
        teq     a2, #INTERLEAVED_Y2U1Y1V1
        bne     %ft12

        b       %ft99
12
        teq     a2, #INTERLEAVED_U1Y1V1Y2
        bne     %ft13

        b       %ft99
13
        teq     a2, #INTERLEAVED_U1Y2V1Y1
        bne     %ft14
        mov     a1, #3
        ldr     a3, =CPI_BPP
        bl      IPU_CPMem_Write
        b       %bt011
14
     DebugReg a2,"Unknown idmac colour format ******"
99
; set pixels per burst
        ldr     a1, iii_npb
        ldr     a3, =CP_NPB
        bl      IPU_CPMem_Write
        ldr     a1, iii_so
        ldr     a3, =CP_SO
        bl      IPU_CPMem_Write
        ldr     a1, iii_ilo
        ldr     a3, =CP_ILO
        bl      IPU_CPMem_Write
; setup rotate
        ldr     a1, iii_rot
        ldr     a3, =CP_ROT
        bl      IPU_CPMem_Write
; setup vf
        ldr     a1, iii_vf
        ldr     a3, =CP_VF
        bl      IPU_CPMem_Write
; setup hf
        ldr     a1, iii_hf
        ldr     a3, =CP_HF
        bl      IPU_CPMem_Write
; setup block mode (bm)
        ldr     a1, iii_bm
        ldr     a3, =CP_BM
        bl      IPU_CPMem_Write
 ;DebugReg a4, "channel base address "
 Push "a1,a2,a3,a4,v1,v2"
 ldmia a4,{a1,a2,a3,v1,v2}
 ;DebugReg a1, "CPMem0-0 "
 ;DebugReg a2, "CPMem0-2 "
 ;DebugReg a3, "CPMem0-3 "
 ;DebugReg v1, "CPMem0-4 "
 ;DebugReg v2, "CPMem0-5 "
 add    a4, a4, #&20
 ldmia a4,{a1,a2,a3,v1,v2}
 ;DebugReg a1, "CPMem1-0 "
 ;DebugReg a2, "CPMem1-2 "
 ;DebugReg a3, "CPMem1-3 "
 ;DebugReg v1, "CPMem1-4 "
 ;DebugReg v2, "CPMem1-5 "
 Pull "a1,a2,a3,a4,v1,v2"
; setup buffering mode
mode2chanoffset * IPU_IDMAC_CONF_OFFSET - IPU_REGISTERS_OFFSET
        Pull    "a2, a3"                ; recover channel on/off data
        ldr     a1, iii_addr1
        teq     a1, #0                  ; single buffer (eq) or  double buffer
        sub     a1, a3, #mode2chanoffset
        ldr     v1, [a1,#IPU_IPU_CH_DB_MODE_SEL_0_OFFSET -IPU_IDMAC_CH_EN_1_OFFSET + mode2chanoffset]
        biceq   v1, v1, a2              ; single
        orrne   v1, v1, a2              ;double
        str     v1, [a1,#IPU_IPU_CH_DB_MODE_SEL_0_OFFSET -IPU_IDMAC_CH_EN_1_OFFSET+ mode2chanoffset]



; reenable channel
        ldr     a1, [a3]
        orr     a1, a1, a2              ; turn channel on
        str     a1, [a3]
;     DebugReg a3,"just turned idmac on at addr "
;     DebugReg a1,"with "
        EXIT

; IPU software reset
;int32_t ipu_sw_reset(int32_t ipu_index, int32_t timeout)
; return true if ok, else false (C)
        EXPORT  |ipu_sw_reset|
ipu_sw_reset
        Entry   " a2, a3, a4, sb"
        ldr     a3, SRC_Log
        teq     a1, #1
        moveq   a1, #1<<3       ; reset for ipu1
        movne   a1, #1<<&c      ; reset for ipu2
        ldr     a4, [a3]
        orr     a4, a4, a1
; DebugReg a4,"Reading  "
        str     a4, [a3]        ; reset it
1       ldr     a4, [a3]
; DebugReg a4,"Reading  "
        ands    a4, a4, a1
        EXIT    EQ
        subs    a2, a2, #1
        bne     %bt1
        subs    a1, a2, #1
        EXIT

;int32_t ips_hdmi_stream(void)
; default to ipu index 1
ips_hdmi_stream
        Entry   "v1, v2, v3, v4, sb"
; first set up the hdmi clock
        mov     a1, #1
        ldr     a2, mpixel_clock
; DebugReg a2, "Pix Clk "
        bl      myhdmi_clock_set
        mov     a1, #1
        mov     a2, #1000
        bl      ipu_sw_reset    ;(ignore possible timeout)
        adrl    a1, myHDMI_dev_panel
        Push    "a1"
        mov     a1, #1
        ldr     a2, ScrInit
        mov     a3, #0
        ldr     a4, ml2bpp
; DebugReg a4, "ihs has pix format "
        teq     a4, #5
        moveq   a4, #INTERLEAVED_ABGR8888         ; C16M
        beq     %ft1
        teq     a4, #4
        moveq   a4, #INTERLEAVED_TBGR1555         ; C32K
        movne   a4, #INTERLEAVED_LUT          ; C256, using palette
1
;       IMPORT  |ipu_display_setup|
        bl      ipu_display_setup
        Pull    "a2"            ; clean stack

        ; ipu_display_setup will have set up some basic parameters for the FIFO allocation
        ; However we want to tweak them to give as much FIFO space as possible to the BG overlay
        ; The FIFO is 512 x 128bits in size and must be shared between the FG and BG overlays
        ; Unfortunately we can only allocate space in powers of two, so will allocate half to each
        mov     a1, #DMFC_BURST_32X128 ; Maximum burst size
        Push    "a1"
        mov     a1, #1
        mov     a2, #MEM_TO_DP_BG_CH23
        mov     a3, #DMFC_FIFO_256X128 ; FG gets 50%
        mov     a4, #0                 ; from a base of 0*64*128
        IMPORT  ipu_dmfc_alloc
        bl      ipu_dmfc_alloc
        mov     a1, #1
        mov     a2, #MEM_TO_DP_FG_CH27
        mov     a3, #DMFC_FIFO_32X128 ; BG gets 32x128 - HACK - if this is any larger bad things happen!
        mov     a4, #4                 ; from a base of 4*64*128
        bl      ipu_dmfc_alloc
        Pull    "a1"
        mov     a1, #1
        bl      ipu_enable_display
        EXIT


 [ HardwarePointer
; ConfigurePointerChannel
; use idmac channel 27
; a1 = ipu index
; a2 = addr
; a3 = height
; a4 = width
; v1 = pixel format
ConfigurePointerChannel
        Entry   "v1, v2, v3, sb"
        sub     sp, sp, #ipu_idmac_info_size
        mov     v3, sp          ; get structure space
        Push    "a1, a2, a3, a4"
        mov     a1, #0
        mov     a2, #ipu_idmac_info_size
 ;DebugTX "ConfigurePointerChannel"
 ;DebugReg a2, "iii_size "
1       subs    a2, a2, #4
        strge   a1, [v3, a2]
        bgt     %bt1            ; zero it
        str     a1, iii_so
        mov     a1, #MEM_TO_DP_FG_CH27
        str     a1, iii_channel
        Pull    "a1, a2, a3, a4"
        ldr     v1, [sp, #ipu_idmac_info_size]        ; pixel format
 ;DebugReg v1, "pixformat "
        str     a2, iii_addr0
 ;DebugReg a2, "addr0 "
        str     a3, iii_width
 ;DebugReg a3, "width "
        str     a4, iii_height
 ;DebugReg a4, "height "
        str     v1, iii_pixel_format
        teq     v1, #INTERLEAVED_ARGB8888
        teqne   v1, #INTERLEAVED_ABGR8888
        moveq   a3, a3, lsl #2          ; width*4
        streq   a3, iii_sl
        moveq   a2, #0
        streq   a2, iii_u_offset
        beq     %ft1
        and     a2, v1, #&f
        cmp     a2, #INTERLEAVED_RGB
        movge   a3, a3, lsl #1          ; width*2
        strge   a3, iii_sl
        movge   a2, #0
        strge   a2, iii_u_offset
        bge     %ft1
        str     a3, iii_sl
        mul     a3, v1, a3
        str     a3, iii_u_offset
1
        mov     a4, #15
        str     a4, iii_npb

        mov     a2, v3
        bl      IDMACSetup

        add     sp, sp, #ipu_idmac_info_size  ; restore
        EXIT
 ] ; HardwarePointer

; ConfigureDisplayChannel
; use idmac channel 23
; ipu_disp_bg_idmac_config(uint32_t ipu_index, uint32_t addr0, uint32_t addr1, ;            uint32_t width, uint32_t height, uint32_t pixel_format)
        EXPORT  ipu_disp_bg_idmac_config
ipu_disp_bg_idmac_config
ConfigureDisplayChannel
        Entry   "v1, v2, v3, sb"
        sub     sp, sp, #ipu_idmac_info_size
        mov     v3, sp          ; get structure space
        Push    "a1, a2, a3, a4"
        mov     a1, #0
        mov     a2, #ipu_idmac_info_size
;; DebugReg a2, "iii_size "
1       subs    a2, a2, #4
        strge   a1, [v3, a2]
        bgt     %bt1            ; zero it
        str     a1, iii_so
        mov     a1, #MEM_TO_DP_BG_CH23
        str     a1, iii_channel
        Pull    "a1, a2, a3, a4"
        ldr     v1, [sp, #(5*4)+ipu_idmac_info_size]        ; height
        ldr     v2, [sp, #(6*4)+ipu_idmac_info_size]        ; pixel format
;; DebugReg v1, "height "
; DebugReg v2, "pixformat "
        str     a2, iii_addr0
; DebugReg a2, "addr0 "
        str     a3, iii_addr1
; DebugReg a3, "addr1 "
        str     a4, iii_width
; DebugReg a4, "width "
        str     v1, iii_height
        str     v2, iii_pixel_format
        teq     v2, #INTERLEAVED_ARGB8888
        teqne   v2, #INTERLEAVED_ABGR8888
        moveq   a4, a4, lsl #2          ; width*4
        streq   a4, iii_sl
        moveq   a2, #0
        streq   a2, iii_u_offset
        beq     %ft1
        and     a2, v2, #&f
        cmp     a2, #INTERLEAVED_RGB
        movge   a4, a4, lsl #1          ; width*2
        strge   a4, iii_sl
        movge   a2, #0
        strge   a2, iii_u_offset
        bge     %ft1
        str     a4, iii_sl
        mul     a4, v1, a4
        str     a4, iii_u_offset
1
        mov     a4, #15
        str     a4, iii_npb

        mov     a2, v3
        bl      IDMACSetup

        add     sp, sp, #ipu_idmac_info_size  ; restore
        EXIT

; ipu_common stuff
;
; uint32_t ipu_read(index,reg)
        EXPORT  |ipu_read|
ipu_read
        Entry   "sb"
        teq     a1, #1
        ldreq   a1, IPU1_Log
        ldrne   a1, IPU2_Log
        ldr     a1, [a1, a2]
        EXIT

; uint32_t ipu_write(index,reg,data)
        EXPORT  |ipu_write|
ipu_write
        Entry   "a1,a2,sb"
        teq     a1, #1
        ldreq   a1, IPU1_Log
        ldrne   a1, IPU2_Log
        str     a3, [a1, a2]
        EXIT

; uint32_t ipu_write_field(index,reg,mask,data)
        EXPORT  |ipu_write_field|
ipu_write_field
        Entry   "a1,a2,a3,a4,v1,v2,sb"
        teq     a1, #1
        ldreq   v1, IPU1_Log
        ldrne   v1, IPU2_Log
        ldr     a1, [v1, a2]
        mvn     v2, a3
        and     a1,  a1, v2       ; data &= !mask
        mov     v2, #0
        sub     v2, v2, a3        ; -mask
        and     v2, a3, v2        ; mask & -mask
        mul     a4, v2, a4        ; data & this
        orr     a1, a1, a4
        str     a1, [v1, a2]
        EXIT

; ipu_enable_display(index)
        EXPORT  |ipu_enable_display|
ipu_enable_display
        Entry   "a1,a2,a3,a4,sb"
        mov     a2, #IPU_IPU_CONF_OFFSET
        mov     a4, #1            ; all on
        mov     a3, #IPU_IPU_CONF__DI0_EN
        bl      ipu_write_field
;       mov     a3, #IPU_IPU_CONF__DI1_EN
;       bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DP_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DC_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DMFC_EN
        bl      ipu_write_field

        EXIT

; ipu_disable_display(index)
        EXPORT  |ipu_disable_display|
ipu_disable_display
        Entry   "a1,a2,a3,a4,sb"
        mov     a2, #IPU_IPU_CONF_OFFSET
        mov     a4, #0            ; all off
        mov     a3, #IPU_IPU_CONF__DI0_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DI1_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DP_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DC_EN
        bl      ipu_write_field
        mov     a3, #IPU_IPU_CONF__DMFC_EN
        bl      ipu_write_field

        EXIT

; int32_t need_csc(int32_t i, int32_t o)
        EXPORT  |need_csc|
need_csc
        Entry   "a1,a2,a3,a4,sb"
        and     a1, a1, #&f
        teq     a1, #INTERLEAVED_RGB
        beq     %ft1
        cmp     a2, #DCMAP_BRG888
        bgt     %ft2            ; need to return1
1       cmp     a2, #DCMAP_BRG888
        mov     a1, #0
        EXIT    GT
2       mov     a1, #1
        EXIT

;void ipu_display_setup(
; a1=   uint32_t ipu_index,
; a2=   uint32_t mem_addr0,
; a3=   uint32_t mem_addr1,
; a4=   uint32_t mem_colorimetry,
; (sp)=      ips_dev_panel_t * panel)
ipu_display_setup
; EXPORT ipstst
;ipstst
        Entry   "a1,a2,a3,a4,v1,v2,v3,v4,sb"
        ldr     v1,[sp,#4*10]
; DebugReg v1, "Panel "
        teq     a4, #INTERLEAVED_LUT    ; colorimetry is LUT?
        andne   v2, a4, #&f
        teqne   v2, # INTERLEAVED_RGB
        moveq   v2, #MEM_RGB
        movne   v2, #MEM_YUV            ; incoming colour type
        ldr     v3, [v1, #mcolorimetry-mpanel_name]
        teq     v3, #DCMAP_YUV888
        teqne   v3, #DCMAP_UVY888
        teqne   v3, #DCMAP_VYU888
        teqne   v3, #DCMAP_YUVA8888
        moveq   v3, #MEM_YUV
        movne   v3, #MEM_RGB            ; output colour type
        teq     v2, #MEM_RGB
        teqeq   v3, #MEM_YUV
        moveq   v2, #CSC_RGB_YUV
        beq     %ft1
        teq     v3, #MEM_RGB
        teqeq   v2, #MEM_YUV
        moveq   v2, #CSC_YUV_RGB
        movne   v2, #CSC_NO_CSC
1
;        IMPORT  ipu_disp_bg_idmac_config
        Push    "a1, a2, a3, a4"
        mov     v4, a1                  ; remember ipu_index
        ldr     v3, [v1, #mheight-mpanel_name]
        Push    "a4"                  ; parameters to stack in correct order
        Push    "v3"                  ; parameters to stack in correct order
        ldr     a4, [v1, #mwidth-mpanel_name]
        bl      ipu_disp_bg_idmac_config
        Pull    "a4,v3"
        Pull    "a1, a2, a3, a4"
        mov     v4, a1                  ; remember ipu_index

 [ HardwarePointer
        Push    "a2-v1"
        ldr     a2, PointerPhys
        mov     a3, #HW_CURSOR_WIDTH
        mov     a4, #HW_CURSOR_HEIGHT
        mov     v1, #INTERLEAVED_ABGR8888
        bl      ConfigurePointerChannel
        Pull    "a2-v1"
 ]

        IMPORT  ipu_dmfc_config
        mov     a1, v4
        mov     a2, #MEM_TO_DP_BG_CH23
        bl      ipu_dmfc_config

 [ HardwarePointer
        mov     a1, v4
        mov     a2, #MEM_TO_DP_FG_CH27
        bl      ipu_dmfc_config
 ]

        IMPORT  ipu_dc_config
        ldr     a4, [v1, #mcolorimetry-mpanel_name]
        Push    "a4"                    ; colorimetry
        mov     a3, #0                  ; di 0
        mov     a1, v4
        mov     a2, #MEM_TO_DP_BG_CH23
        ldr     a4, [v1, #mwidth-mpanel_name]
        bl      ipu_dc_config

        IMPORT  ipu_dp_config
        mov     a3, #0
        mov     a4, #0
        Push    "a3, a4"
        mov     a2, v2                  ; csc type
        mov     a1, v4
        bl      ipu_dp_config
        Pull    "a3, a4"                ; clear stack
        Pull    "a4"                    ; recover colorimetry
        mov     a1, v4
        mov     a2, #0                  ; di 0
        mov     a3, v1                  ; panel pointer
        bl      ConfigIPU_DI

 ;DebugReg a1, "Panel init done "

        EXIT


 ] ; VideoInHAL


VideoDevice_Init
        ; Not much to do here - just register our HAL device
        Push    "v1,lr"
        ADRL    v1, VideoDevice
        MOV     a1, v1
        ADR     a2, VideoDeviceTemplate
        MOV     a3, #Video_DeviceSize
        BL      memcpy
        MOV     a1, v1
        ADRL    a2, VideoWorkspace
        STR     a2, [a1, #HALDevice_VDUDeviceSpecificField]
        LDR     a1, CCM_Base
        STR     a1, [a2, #VDUDevSpec_CCM_Base]
        LDR     a1, IOMUXC_Base
        STR     a1, [a2, #VDUDevSpec_IOMUXC_Base]
        LDR     a1, HDMI_Log
        STR     a1, [a2, #VDUDevSpec_HDMI_Log]
        LDR     a1, SRC_Log
        STR     a1, [a2, #VDUDevSpec_SRC_Log]
        LDR     a1, IPU1_Log
        STR     a1, [a2, #VDUDevSpec_IPU1_Log]
        LDR     a1, IPU2_Log
        STR     a1, [a2, #VDUDevSpec_IPU2_Log]
        LDR     a1, CCMAn_Log
        STR     a1, [a2, #VDUDevSpec_CCMAn_Log]
        MOV     a1, #0
        MOV     a2, v1
        CallOS  OS_AddDevice
        Pull    "v1,pc"

VideoDeviceTemplate
        DCW     HALDeviceType_Video + HALDeviceVideo_VDU
        DCW     HALDeviceID_VDU_IMX6
        DCD     HALDeviceBus_Sys + HALDeviceSysBus_AXI

        DCD     0               ; API version 0
        DCD     VideoDevice_Desc
        DCD     0               ; Address - filled in later
        %       12              ; Reserved
        DCD     VideoDevice_Activate
        DCD     VideoDevice_Deactivate
        DCD     VideoDevice_Reset
        DCD     VideoDevice_Sleep
        DCD     VIDEO_IRQ       ; Device interrupt
        DCD     0               ; TestIRQ cannot be called
        %       8
        DCD     0               ; Pointer to device-specific field - filled in later
        ASSERT (. - VideoDeviceTemplate) = HALDevice_VDU_Size
        DCD     VDUDevSpec_Size ; VDUDevSpec size field
      [ VideoInHAL
        DCD     1               ; Flags field
      |
        DCD     0               ; Flags field
      ]
        DCD     HDMI_IRQ        ; HDMI tx irq device number
        DCD     0               ; CCM_Base - filled in later
        DCD     0               ; IOMUXC_Base - filled in later
        DCD     0               ; HDMI_Log - filled in later
        DCD     0               ; SRC_Log - filled in later
        DCD     0               ; IPU1_Log - filled in later
        DCD     0               ; IPU2_Log - filled in later
        DCD     0               ; CCMAn_Log - filled in later
        ASSERT (. - VideoDeviceTemplate) = Video_DeviceSize

VideoDevice_Desc
        =       "i.Mx6 video controller", 0
        ALIGN

VideoDevice_Activate
        MOV     a1, #1
        MOV     pc, lr

VideoDevice_Deactivate
VideoDevice_Reset
        MOV     pc, lr

VideoDevice_Sleep
        MOV     a1, #0
        MOV     pc, lr

; unsigned divide routine, lifted from clib
udivide
; Unsigned divide of a2 by a1: returns quotient in a1, remainder in a2
        Entry   "a3,ip"
        MOV     a3, #0
        RSBS    ip, a1, a2, LSR #3
        BCC     u_sh2
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&FF000000
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, a2, LSR #8
        BCC     u_sh7
        MOV     a1, a1, LSL #8
        ORR     a3, a3, #&00FF0000
        RSBS    ip, a1, a2, LSR #8
        MOVCS   a1, a1, LSL #8
        ORRCS   a3, a3, #&0000FF00
        RSBS    ip, a1, a2, LSR #4
        BCC     u_sh3
        RSBS    ip, a1, #0
        BCS     dividebyzero
u_loop  MOVCS   a1, a1, LSR #8
u_sh7   RSBS    ip, a1, a2, LSR #7
        SUBCS   a2, a2, a1, LSL #7
        ADC     a3, a3, a3
u_sh6   RSBS    ip, a1, a2, LSR #6
        SUBCS   a2, a2, a1, LSL #6
        ADC     a3, a3, a3
u_sh5   RSBS    ip, a1, a2, LSR #5
        SUBCS   a2, a2, a1, LSL #5
        ADC     a3, a3, a3
u_sh4   RSBS    ip, a1, a2, LSR #4
        SUBCS   a2, a2, a1, LSL #4
        ADC     a3, a3, a3
u_sh3   RSBS    ip, a1, a2, LSR #3
        SUBCS   a2, a2, a1, LSL #3
        ADC     a3, a3, a3
u_sh2   RSBS    ip, a1, a2, LSR #2
        SUBCS   a2, a2, a1, LSL #2
        ADC     a3, a3, a3
u_sh1   RSBS    ip, a1, a2, LSR #1
        SUBCS   a2, a2, a1, LSL #1
        ADC     a3, a3, a3
u_sh0   RSBS    ip, a1, a2
        SUBCS   a2, a2, a1
        ADCS    a3, a3, a3
        BCS     u_loop
        MOV     a1, a3
        EXIT
dividebyzero                            ; for our use .. not really trapping divide by zero
        mov     a1, #0
        mov     a2, #0
        EXIT

        END
