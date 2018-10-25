;
; Copyright (c) 2012, RISC OS Open Ltd
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;     * Redistributions of source code must retain the above copyright
;       notice, this list of conditions and the following disclaimer.
;     * Redistributions in binary form must reproduce the above copyright
;       notice, this list of conditions and the following disclaimer in the
;       documentation and/or other materials provided with the distribution.
;     * Neither the name of RISC OS Open Ltd nor the names of its contributors
;       may be used to endorse or promote products derived from this software
;       without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;
;Ports start at PIO. (hdr.AllWinnerH3) &01C20800
;Section 4.22 P316.
;Pn_CFGn reg sets pin mode.
;Pn_DAT pin state?
;This BCM version is nothing like the GPIO I need.
;The template was neater is all.




        AREA    |ARM$$code|, CODE, READONLY, PIC

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:Proc
        GET     hdr.BCM2835
        GET     hdr.StaticWS
        GET     hdr.CastleMacros

        EXPORT  GPIO_InitDevices
        EXPORT  HAL_PlatformName
        IMPORT  memcpy
        IMPORT  HAL_CounterDelay

        MACRO
$class  HALDeviceField $field, $value
        LCLS    myvalue
      [ "$value" = ""
myvalue SETS    "$field"
      |
myvalue SETS    "$value"
      ]
        ASSERT  . - %A0 = HALDevice_$class$field
     [ ?HALDevice_$class$field = 2
        DCW     $myvalue
   ELIF ?HALDevice_$class$field = 4
        DCD     $myvalue
      |
        %       ?HALDevice_$class$field
      ]
        MEND

        MACRO
        FuncSelectTable $limit
        LCLA    pin
        LCLA    grp
        LCLA    reg
pin     SETA    0
        WHILE pin <= $limit
reg     SETA    pin / 10                ; 10 pins per register
grp     SETA    pin % 10                ; 3 bits per pin
        DCB     grp * 3
        DCB     GPFSel0 + (reg * 4)
pin     SETA    pin + 1
        WEND
        MEND

        GBLA    PinDef_List0
        GBLA    PinDef_List1
        GBLA    PinDef_List2
        GBLA    PinDef_List3
        GBLA    PinDef_List4
        GBLA    PinDef_List5
        GBLA    PinDef_Number
        GBLA    PinDef_List
        GBLA    PinDef_Alts
        ; The BCM2835 has a maximum of 6 alternates
AltGPI  *       2_000
AltGPO  *       2_001
Alt0    *       2_100
Alt1    *       2_101
Alt2    *       2_110
Alt3    *       2_111
Alt4    *       2_011
Alt5    *       2_010

        MACRO
        PinStart $pin, $io
PinDef_Number SETA $pin :AND: &1F
      [ ("$io" = "IO") :LOR: ("$io" = "OI")
PinDef_Number SETA PinDef_Number :OR: GPIOEnumerate_PinFlags_Output :OR: GPIOEnumerate_PinFlags_Input
      ]
      [ "$io" = "I"
PinDef_Number SETA PinDef_Number :OR: GPIOEnumerate_PinFlags_Input
      ]
      [ "$io" = "O"
PinDef_Number SETA PinDef_Number :OR: GPIOEnumerate_PinFlags_Output
      ]
PinDef_List0  SETA GPIOEnumerate_GroupListEnd
PinDef_List1  SETA GPIOEnumerate_GroupListEnd
PinDef_List2  SETA GPIOEnumerate_GroupListEnd
PinDef_List3  SETA GPIOEnumerate_GroupListEnd
PinDef_List4  SETA GPIOEnumerate_GroupListEnd
PinDef_List5  SETA GPIOEnumerate_GroupListEnd
PinDef_List   SETA 0
PinDef_Alts   SETA 0
        MEND

        MACRO
        PinBelongsTo $type, $num, $alt
        ASSERT $alt < 32
        ASSERT $num < 256
        ASSERT $type < 65536
        LCLS var
var     SETS "PinDef_List" :CC: (:STR:PinDef_List:RIGHT:1)
$var    SETA ($num) :OR: ($alt :SHL: 8) :OR: ($type :SHL: 16)
PinDef_List SETA PinDef_List + 1
PinDef_Alts SETA PinDef_Alts :OR (1 :SHL: $alt)
        MEND

        MACRO
        PinEnd
        LCLA count
        LCLS var
count   SETA 0
        ; Private word to make searching easier
        DCD  PinDef_List
        ; Always these words
        DCB  PinDef_Number, 0, 0, 0
        DCD  PinDef_Alts
        ; Then dump up to 6 alternates
        WHILE count < PinDef_List
var     SETS "PinDef_List" :CC: (:STR:count:RIGHT:1)
        DCD $var
count   SETA count + 1
        WEND
        ; Terminator
        DCD  GPIOEnumerate_GroupListEnd
        MEND

; GPIO structures
                  ^ 0
                  # HALDevice_GPIO_Size_1_0
WkspType          # 4                   ; GPIORevision_RaspberryPi type
WkspPullEnable    # 4                   ; Soft copies
WkspPullDirection # 4                   ; Soft copies
WkspCopySB        # 4
Wksp_GPIO_Size    # 0
                  ASSERT ?GPIO0Device = Wksp_GPIO_Size
                  ASSERT ?GPIO1Device = Wksp_GPIO_Size

; Template for GPIO interface

GPIOTemplate
0
        HALDeviceField Type,               HALDeviceType_Comms + HALDeviceComms_GPIO
        HALDeviceField ID,                 HALDeviceID_GPIO_BCM2835
        HALDeviceField Location,           HALDeviceBus_Sys + HALDeviceSysBus_AHB ; Guess
        HALDeviceField Version,            &10000 ; API 1.0
        HALDeviceField Description,        0 ; Filled in at runtime
        HALDeviceField Address,            0 ; Filled in at runtime
        HALDeviceField Reserved1,          0
        HALDeviceField Activate,           GPIO_Activate
        HALDeviceField Deactivate,         GPIO_Deactivate
        HALDeviceField Reset,              GPIO_Reset
        HALDeviceField Sleep,              GPIO_Sleep
        HALDeviceField Device,             -1
        HALDeviceField TestIRQ,            0
        HALDeviceField ClearIRQ,           0
        HALDeviceField Reserved2,          0
GPIO    HALDeviceField Ports,              GPIOPorts
GPIO    HALDeviceField Number,             0 ; also overwritten for extra ports
GPIO    HALDeviceField Enumerate,          GPIOEnumerate
GPIO    HALDeviceField SetDataBits,        GPIOSetDataBits
GPIO    HALDeviceField ClearDataBits,      GPIOClearDataBits
GPIO    HALDeviceField ToggleDataBits,     GPIOToggleDataBits
GPIO    HALDeviceField ReadDataBits,       GPIOReadDataBits
GPIO    HALDeviceField DataDirection,      GPIODataDirection
GPIO    HALDeviceField ReadMode,           GPIOReadMode
GPIO    HALDeviceField WriteMode,          GPIOWriteMode
GPIO    HALDeviceField PullControl,        GPIOPullControl
GPIO    HALDeviceField PullDirection,      GPIOPullDirection
GPIO    HALDeviceField EdgeControl,        GPIOEdgeControl
GPIO    HALDeviceField EdgePollStatus,     GPIOEdgePollStatus
        ASSERT  . - %A0 = HALDevice_GPIO_Size_1_0

GPIO_Description_0
        = "Raspberry Pi GPIO interface pins 0-31", 0
        ALIGN
GPIO_Description_1
        = "Raspberry Pi GPIO interface pins 32-63", 0
        ALIGN

                                 ^       0
GPIORevision_RaspberryPi_B_1     #       1 ; Model B Rev 1.0
GPIORevision_RaspberryPi_B_2     #       1 ; Model B Rev 2.0
GPIORevision_RaspberryPi_A_2     #       1 ; Model A Rev 2.0
GPIORevision_RaspberryPi_BPlus   #       1 ; Model B+
GPIORevision_RaspberryPi_C_1     #       1 ; Model Compute Rev 1.0
GPIORevision_RaspberryPi_APlus   #       1 ; Model A+
GPIORevision_RaspberryPi_Mk2_B_1 #       1 ; Model Pi 2
GPIORevision_RaspberryPi_Zero    #       1 ; Model Zero
GPIORevision_RaspberryPi_Mk3_B_1 #       1 ; Model Pi 3
GPIORevision_RaspberryPi_Max     #       0

Name_B_1 = "Raspberry Pi B PCB 1.0", 0
Name_B_2 = "Raspberry Pi B PCB 2.0", 0
Name_A_2 = "Raspberry Pi A", 0
Name_BPlus = "Raspberry Pi B+", 0
Name_C_1 = "Raspberry Pi Compute Module", 0
Name_APlus = "Raspberry Pi A+", 0
Name_Mk2_B_1 = "Raspberry Pi 2 Model B", 0
Name_Zero = "Raspberry Pi Zero", 0
Name_Mk3_B_1 = "Raspberry Pi 3 Model B", 0
Name_Unknown = "Raspberry Pi Unknown", 0
        ALIGN

GPIO_Board_Names_Table ; same order as GPIORevision_RaspberryPi types
        DCD     Name_B_1
        DCD     Name_B_2
        DCD     Name_A_2
        DCD     Name_BPlus
        DCD     Name_C_1
        DCD     Name_APlus
        DCD     Name_Mk2_B_1
        DCD     Name_Zero
        DCD     Name_Mk3_B_1
        ASSERT  (.-GPIO_Board_Names_Table) :SHR: 2 = GPIORevision_RaspberryPi_Max

; Lookup table to determine board type (old style)
; Ref: http://elinux.org/RPi_HardwareHistory#Board_Revision_History
        MACRO
        BoardType $model, $minrev, $maxrev, $type
        DCD $model
        DCD $minrev
        DCD $maxrev
        DCD GPIORevision_RaspberryPi_$type
        MEND

GPIO_BoardTypes
        BoardType 0, &02, &03, B_1
        BoardType 0, &04, &06, B_2
        BoardType 0, &07, &09, A_2
        BoardType 0, &0d, &0f, B_2
        BoardType 0, &10, &10, BPlus
        BoardType 0, &11, &11, C_1
        BoardType 0, &12, &12, APlus
        BoardType 0, &13, &13, BPlus
        BoardType 0, &14, &14, C_1
        BoardType 0, &15, &15, APlus
GPIO_BoardTypes_End

; Lookup table to determine board type (new style)
; Only the memory amount, model, and revision are significant in this table.


;Only left this entry so I know what else I need to cull.
GPIO_Board_Conversion_Table
        DCD     BoardRevision_Mem_256M+BoardRevision_Model_B+(1:SHL:BoardRevision_Rev_Shift)

        DCD     &FF

        ; Initialise our HAL devices
GPIO_InitDevices
        Entry   "v1"
;What's this GPIO 0 and 1?
        ; Copy dev struct to WS & fill in the non template items
        ADRL    a1, GPIO0Device
        ADR     a2, GPIOTemplate
        MOV     a3, #HALDevice_GPIO_Size_1_0
        BL      memcpy

        MOV     a2, #0
        STR     a2, [a1, #WkspPullEnable]
        STR     a2, [a1, #WkspPullDirection]
        STR     sb, [a1, #WkspCopySB]

        ADRL    a2, GPIO_Description_0
        STR     a2, [a1, #HALDevice_Description]
        LDR     a4, PeriBase
        ADD     a4, a4, #GPIO_Base
        STR     a4, [a1, #HALDevice_Address]
        MOV     a2, #0
        STR     a2, [a1, #HALDevice_GPIONumber]

        ; Copy dev struct to WS & fill in the non template items
        ADRL    a1, GPIO1Device
        ADR     a2, GPIOTemplate
        MOV     a3, #HALDevice_GPIO_Size_1_0
        BL      memcpy

        MOV     a2, #0
        STR     a2, [a1, #WkspPullEnable]
        STR     a2, [a1, #WkspPullDirection]
        STR     sb, [a1, #WkspCopySB]

        ADRL    a2, GPIO_Description_1
        STR     a2, [a1, #HALDevice_Description]
        LDR     a4, PeriBase
        ADD     a4, a4, #GPIO_Base
        STR     a4, [a1, #HALDevice_Address]
        MOV     a2, #1
        STR     a2, [a1, #HALDevice_GPIONumber]

        ; Only register if it's a model known to us
        BL      GPIO_Get_Platform
        CMP     a1, #-1
        EXIT    EQ
        MOV     v1, a1

        ; Found a match, add devices to list
        MOV     a1, #0
        ADRL    a2, GPIO0Device
        STR     v1, [a2, #WkspType]
      [ :LNOT: JTAG ; Play it safe, we don't want software messing with the JTAG GPIOs
        CallOS  OS_AddDevice            ; register device0
      ]

        MOV     a1, #0
        ADRL    a2, GPIO1Device
        STR     v1, [a2, #WkspType]
      [ :LNOT: JTAG ; Play it safe, we don't want software messing with the JTAG GPIOs
        CallOS  OS_AddDevice            ; register device1
      ]
        EXIT

GPIO_Activate
        MOV     a1, #1
GPIO_Deactivate
GPIO_Reset
        MOV     pc, lr

GPIO_Sleep
        MOV     a1, #0
        MOV     pc, lr

; Name the platform for debug dumps and similar
; Return a1 = zero terminated string
HAL_PlatformName
        Entry
        BL      GPIO_Get_Platform
        CMP     a1, #-1
        ADREQL  a1, Name_Unknown
        ADRNE   a2, GPIO_Board_Names_Table
        LDRNE   a1, [a2, a1, LSL #2]
        EXIT


GPIOSetDataBits
        MOV     a3, #GPSet0
        B       GPIO_Data_Common        ; tail call

; int GPIOClearDataBits(struct gpiodevice *, int bits)
; Enter with a1 = device struct pointer
;            a2 = any bit set will cause that pin to be cleared
; Return     a1 = previous value
GPIOClearDataBits
        MOV     a3, #GPClr0
        B       GPIO_Data_Common        ; tail call

; int GPIOReadDataBits(struct gpiodevice *)
; Enter with a1 = device struct pointer
; Return     a1 = previous value
GPIOReadDataBits
        MOV     a3, #GPLev0
        B       GPIO_Data_Common        ; tail call

; void GPIOToggleDataBits(struct gpiodevice *, int bits)
; Enter with a1 = device struct pointer
;            a2 = any bit set will cause that pin to be toggled from its current value
GPIOToggleDataBits
        Entry   "v1-v4"
        MOVS    v2, a2
        EXIT    EQ                      ; nothing to do
        MOV     v1, a1

        PHPSEI  v4                      ; go atomic

        BL      GPIOReadDataBits
        MOV     v3, a1

        ANDS    a2, v2, v3              ; only our bits
        MOVNE   a1, v1
        BLNE    GPIOClearDataBits

        MVN     v3, v3                  ; invert bits
        ANDS    a2, v2, v3              ; only our bits
        MOVNE   a1, v1
        BLNE    GPIOSetDataBits

        PLP     v4                      ; restore interrupt state
        EXIT

; int GPIODataDirection(struct gpiodevice *, int pins, int dir)
; Enter with a1 = device struct pointer
;            a2 = bits to change
;            a3 = direction to set the bits to (1=input 0=output)
; Return     a1 = previous data direction bits (or current if pins=0)
GPIODataDirection
        Entry   "v1-v5"

        ; On the Pi the data direction is scattered across multiple
        ; registers, and changing direction also needs a mode change.
        ; They are, however, individually controllable (groups of 1 pin).
        MOV     v1, a1
        MOV     v2, a2
        MOV     v3, a3

        MOV     v4, #0                  ; pin to change
        MOV     v5, #0                  ; old direction bits
10
        MOV     v5, v5, LSR #1
        MOVS    v2, v2, LSR #1
        MOVCC   a3, #-1
        BCC     %FT20                   ; leave alone

        TST     v3, #1
        MOVNE   a3, #AltGPI             ; input
        MOVEQ   a3, #AltGPO             ; output
20
        MOV     a2, v4
        MOV     a1, v1
        BL      GPIO_Mode_Common
        TEQ     a1, #AltGPI             ; previously input?
        ORREQ   v5, v5, #1:SHL:31
        MOV     v3, v3, LSR #1
        ADD     v4, v4, #1
        CMP     v4, #32
        BNE     %BT10

        MOV     a1, v5
        EXIT

; struct onepin *GPIOEnumerate(struct gpiodevice *, int *carryon)
; Enter with a1 = device struct pointer
;            a2 = pointer to continuation value (0 to start)
; Return     a1 = pointer to pin info for one more pin
;            continuation value updated (-1 if no more)
GPIOEnumerate
        Entry   "v1-v3"
        LDR     v1, [a1, #WkspType]
        LDR     a1, [a1, #HALDevice_GPIONumber]
        ADRL    a4, GPIOFreeToUse
        MOV     ip, #GPIOPorts * 4
        MLA     a4, v1, ip, a4          ; address of GPIOFreeToUse for this type
        LDR     v1, [a4, a1, LSL #2]    ; mask of valid on this port for this target

        LDR     a3, [a2]                ; just use the continuation value as a bit position
        CMP     a3, #32
        BCS     %FT60                   ; invalid always

        CMP     a3, #0
        BNE     %FT20                   ; not the start condition

        MOVS    ip, v1
        BEQ     %FT60                   ; no valid pins
10
        ; find first set
        MOVS    ip, ip, LSR #1
        ADDCC   a3, a3, #1
        BCC     %BT10
20
        MOV     ip, #1
        TST     v1, ip, LSL a3
        BEQ     %FT60                   ; invalid on this target

        ADRL    v2, GPIOPortTables
        LDR     v2, [v2, a1, LSL #2]    ; start of pin data
        MOV     v3, #0
30
        LDR     ip, [v2], #4            ; fetch & skip private word
        CMP     ip, #-1
        BEQ     %FT60                   ; no more

        TEQ     v3, a3
        MOVEQ   a1, v2
        BEQ     %FT40

        ADD     v2, v2, #GPIOEnumerate_GroupList ; account for fixed items
        ADD     ip, ip, #1              ; account for list terminator
        ASSERT  GPIOGroupList_Size = 4
        ADD     v2, v2, ip, LSL #2      ; account for list entries
        ADD     v3, v3, #1
        B       %BT30
40
        ; find next set
        ADD     v3, v3, #1
        CMP     v3, #32
        MOVNES  v1, v1, LSR v3
        BEQ     %FT70
50
        MOVS    v1, v1, LSR #1
        ADDCC   v3, v3, #1
        BCC     %BT50

        STR     v3, [a2]
        EXIT
60
        MOV     a1, #0                  ; nothing
70
        MOV     ip, #-1                 ; no more
        STR     ip, [a2]
        EXIT

; enum HAL_GPIOReadMode(struct gpiodevice *, int pin)
; Enter with a1 = device struct pointer
;            a2 = pin (singular) to change
; Return     a1 = current mode
GPIOReadMode
        MOV     a3, #-1
        B       GPIO_Mode_Common        ; tail call

; enum GPIOWriteMode(struct gpiodevice *, int pin, enum useage)
; Enter with a1 = device struct pointer
;            a2 = pin (singular) to change
;            a3 = new mode (opaque value from Enumerate)
; Return     a1 = previous mode
GPIOWriteMode
        B       GPIO_Mode_Common        ; tail call

; int GPIOPullControl(struct gpiodevice *, int pins, int enable)
; Enter with a1 = device struct pointer
;            a2 = bits to change
;            a3 = pull resistor enables for those pins
; Return     a1 = previous pull enable bits (or current if pins=0)
GPIOPullControl
        Entry   "v1"
        LDR     v1, [a1, #WkspPullEnable]
        AND     a3, a3, a2              ; discard spurious set bits
        BIC     a2, v1, a2
        ORR     a2, a3, a2              ; new soft copy
        STR     a2, [a1, #WkspPullEnable]
        TEQ     v1, a2
        MOVEQ   a1, v1                  ; no enables changed
        EXIT    EQ

        LDR     a3, [a1, #WkspPullDirection]
        BL      GPIO_Pull_Common
        MOV     a1, v1
        EXIT

; int GPIOPullDirection(struct gpiodevice *, int pins, int up)
; Enter with a1 = device struct pointer
;            a2 = bits to change
;            a3 = bits to set as pull up else pull down
; Return     a1 = previous pull direction bits (or current if pins=0)
GPIOPullDirection
        Entry   "v1"
        LDR     v1, [a1, #WkspPullDirection]
        AND     a3, a3, a2              ; discard spurious set bits
        BIC     a2, v1, a2
        ORR     a2, a3, a2              ; new soft copy
        STR     a2, [a1, #WkspPullDirection]
        LDR     a4, [a1, #WkspPullEnable]
        AND     a2, a2, a4
        AND     a3, v1, a4
        TEQ     a2, a3
        MOVEQ   a1, v1                  ; no enabled sense change
        EXIT    EQ

        MOV     a3, a2
        MOV     a2, a4
        BL      GPIO_Pull_Common
        MOV     a1, v1
        EXIT

; void GPIOEdgeControl(struct gpiodevice *, int pins, int *enable, int *edge, int *risehigh)
; Enter with a1 = device struct pointer
;            a2 = bits to change
;            a3 = pointer to bits to enable detection on
;            a4 = pointer to bits set for edge mode (else level)
;        [sp+0] = pointer to bits set to detect on rising/high (else falling/low)
GPIOEdgeControl
        LDR     ip, [sp, #0]

        Entry   "v1-v5"
        Push    "a3-a4, ip"

        LDR     v1, [a1, #HALDevice_Address]
        LDR     a1, [a1, #HALDevice_GPIONumber]
        ASSERT  GPREDE0 + 4 = GPREDE1
        ASSERT  GPFEDE0 + 4 = GPFEDE1
        ASSERT  GPHIDE0 + 4 = GPHIDE1
        ASSERT  GPLODE0 + 4 = GPLODE1
        ADD     v1, v1, a1, LSL #2

        LDR     a3, [a3]                ; pick up new values
        LDR     a4, [a4]
        LDR     ip, [ip]

        PHPSEI  v2                      ; go atomic

        LDR     v3, [v1, #GPREDE0]
        LDR     a1, [v1, #GPFEDE0]
        MOV     v5, v3                  ; rising = rising
        ORR     v4, v3, a1              ; OR(rising,falling) = edge
        ORR     v3, v3, a1              ; OR(rising,falling) = edge enable
        LDR     lr, [v1, #GPHIDE0]
        LDR     a1, [v1, #GPLODE0]
        ORR     v5, v5, lr              ; OR(rising,high) = rising/high
        ORR     a1, a1, lr
        ORR     v3, v3, a1              ; OR(edge enable,OR(high,low)) = enable
        TEQ     a2, #0
        BEQ     %FT10

        LDR     a1, [v1, #GPREDE0]
        BIC     a1, a1, a2              ; disable by default
        AND     lr, a3, a4
        AND     lr, lr, ip
        ORR     a1, a1, lr              ; AND(enable,edge,rising) = rising
        STR     a1, [v1, #GPREDE0]

        LDR     a1, [v1, #GPFEDE0]
        BIC     a1, a1, a2              ; disable by default
        AND     lr, a3, a4
        BIC     lr, lr, ip
        ORR     a1, a1, lr              ; AND(enable,edge,NOT(rising)) = falling
        STR     a1, [v1, #GPFEDE0]

        LDR     a1, [v1, #GPHIDE0]
        BIC     a1, a1, a2              ; disable by default
        BIC     lr, a3, a4
        AND     lr, lr, ip
        ORR     a1, a1, lr              ; AND(enable,NOT(edge),rising) = high
        STR     a1, [v1, #GPHIDE0]

        LDR     a1, [v1, #GPLODE0]
        BIC     a1, a1, a2              ; disable by default
        BIC     lr, a3, a4
        BIC     lr, lr, ip
        ORR     a1, a1, lr              ; AND(enable,NOT(edge),NOT(rising)) = low
        STR     a1, [v1, #GPLODE0]
10
        PLP     v2                      ; restore interrupt state

        Pull    "a3-a4, ip"
        STR     v3, [a3]                ; write out previous values
        STR     v4, [a4]
        STR     v5, [ip]
        EXIT

; int GPIOEdgePollStatus(struct gpiodevice *, int collect)
; Enter with a1 = device struct pointer
;            a2 = clear these bits having polled the status
; Return     a1 = states latched in edge/level since last poll
GPIOEdgePollStatus
        MOV     a3, #GPPEDS0
        B       GPIO_Data_Common        ; tail call

; Pin function selection
; Enter with a1 = device pointer
;            a2 = pin (0-31)
;            a3 = mode to set to (or -1 to just read)
; Return     a1 = previous mode, or -1 if invalid request
GPIO_Mode_Common
        Entry   "v1-v5"
        LDR     v2, [a1, #HALDevice_Address]
        LDR     v1, [a1, #WkspType]
        LDR     a1, [a1, #HALDevice_GPIONumber]
        ADR     a4, GPIOFreeToUse
        MOV     ip, #GPIOPorts * 4
        MLA     a4, v1, ip, a4          ; address of GPIOFreeToUse for this type
        LDR     v1, [a4, a1, LSL #2]    ; mask of valid on this port for this target

        MOV     a4, #1
        MOV     a4, a4, LSL a2
        TST     a4, v1
        MOVEQ   a1, #-1
        EXIT    EQ                      ; not a valid pin to change

        MOV     v3, #2_111
        ADD     v4, a2, a1, LSL #5      ; flatten port and pin to 0-63

        ADR     a4, GPIO_FuncSelect_Table
        ADD     a4, a4, v4, LSL #1
        LDRH    a4, [a4]                ; reg/grp pair
        AND     v4, a4, #255            ; grp
        MOV     lr, #2_111              ; mode mask

        PHPSEI  ip                      ; go atomic

        LDR     a2, [v2, a4, LSR #8]
        CMP     a3, #-1                 ; just reading?
        BICNE   a1, a2, lr, LSL v4
        ORRNE   a1, a1, a3, LSL v4
        DataSyncBarrier a3, NE          ; resync before/after peripheral
        STRNE   a1, [v2, a4, LSR #8]

        PLP     ip

        MOV     a1, a2, LSR v4
        AND     a1, a1, #2_111

        EXIT

; Port wide pull resistor modifier
; Enter with a1 = device pointer
;            a2 = enables
;            a3 = sense
GPIO_Pull_Common
        Entry   "v1-v4, sb"
        LDR     v1, [a1, #HALDevice_Address]
        LDR     sb, [a1, #WkspCopySB]
        LDR     a1, [a1, #HALDevice_GPIONumber]
        ASSERT  GPPUDCK0 + 4 = GPPUDCK1
        MOV     a4, #GPPUDCK0
        ADD     v4, a4, a1, LSL #2
        MOV     v2, a2
        MOV     v3, a3

        MOV     a1, #2_00               ; disable pullup/down
        MVNS    a2, v2                  ; NOT(enable) = disable
        BLNE    %FT10

        MOV     a1, #2_01               ; pull down
        MVN     a2, v3
        ANDS    a2, a2, v2              ; AND(NOT(sense),enable) = pull downs
        BLNE    %FT10

        MOV     a1, #2_10               ; pull up
        ANDS    a2, v3, v2              ; AND(sense,enable) = pull ups
        BLNE    %FT10

        MOV     a1, #0                  ; rest
        STR     a1, [v1, #GPPUPDEN]
        STR     a1, [v1, v2]
        EXIT
10
        Push    "a2, lr"
        STR     a1, [v1, #GPPUPDEN]
        MOV     a1, #50                 ; guess
        BL      HAL_CounterDelay
        Pull    "a2, lr"
        STR     a2, [v1, v2]
        MOV     a1, #50                 ; guess
        B       HAL_CounterDelay

; Port wide pin modifier
; Enter with a1 = device pointer
;            a2 = bit set of pins
;            a3 = GPIO peripheral register offset (or GPLev0 to just read)
; Return     a1 = previous value
GPIO_Data_Common
        Entry   "v1-v2"
        LDR     v2, [a1, #HALDevice_Address]
        LDR     a1, [a1, #HALDevice_GPIONumber]
        ASSERT  GPSet0  + 4 = GPSet1
        ASSERT  GPClr0  + 4 = GPClr1
        ASSERT  GPLev0  + 4 = GPLev1
        ASSERT  GPPEDS0 + 4 = GPPEDS1
        ADD     a4, a3, a1, LSL #2
        ADR     v1, GPIOPORT
        LDR     v1, [v1, a1, LSL #2]    ; mask of invalid

        CMP     a3, #GPLev0
        DataSyncBarrier ip              ; resync before/after peripheral
        LDR     a1, [v2, a4]
        AND     a1, a1, v1
        ANDNE   a2, a2, v1
        STRNE   a2, [v2, a4]
        DataSyncBarrier ip, NE          ; resync before/after peripheral

        EXIT

; Available pins in the GPIO peripheral
GPIOPORT
        DCD     2_11111111111111111111111111111111      ; 31-0
        DCD     2_00000000001111111111111111111111      ; 53-32
GPIOPORTEND
GPIOPorts       *       (GPIOPORTEND-GPIOPORT):SHR:2

; Function Select register offset/bits lookup table
GPIO_FuncSelect_Table
        FuncSelectTable 53
        ALIGN

      [ {FALSE}
; Alt table 8 bytes per port 1st byte = mode 0 etc, &FF = not available
; Ref: section 6.2 of BCM2835 ARM peripherals datasheet
GPIO_Alt_Table
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 0
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 1
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 2
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 3
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 4
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 5
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 6
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 7

        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 8
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 9
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 10
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 11
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 12
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 13
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 14
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF, 2_010 ; 15

        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 16
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 17
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 18
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 19
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 20
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011, 2_010 ; 21
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011,   &FF ; 22
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011,   &FF ; 23

        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011,   &FF ; 24
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111, 2_011,   &FF ; 25
        DCB     2_000, 2_001,   &FF,   &FF,   &FF, 2_111, 2_011,   &FF ; 26
        DCB     2_000, 2_001,   &FF,   &FF,   &FF, 2_111, 2_011,   &FF ; 27
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 28
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 29
        DCB     2_000, 2_001,   &FF, 2_101, 2_110,   &FF,   &FF, 2_010 ; 30
        DCB     2_000, 2_001,   &FF, 2_101, 2_110,   &FF,   &FF, 2_010 ; 31

        DCB     2_000, 2_001, 2_100, 2_101,   &FF, 2_111,   &FF, 2_010 ; 32
        DCB     2_000, 2_001, 2_100, 2_101,   &FF, 2_111,   &FF, 2_010 ; 33
        DCB     2_000, 2_001,   &FF, 2_101,   &FF, 2_111,   &FF, 2_010 ; 34
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF,   &FF,   &FF ; 35
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 36
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 37
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 38
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF,   &FF,   &FF ; 39

        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF, 2_011, 2_010 ; 40
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF, 2_011, 2_010 ; 41
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF, 2_011, 2_010 ; 42
        DCB     2_000, 2_001, 2_100, 2_101,   &FF,   &FF, 2_011, 2_010 ; 43
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF, 2_011,   &FF ; 44
        DCB     2_000, 2_001, 2_100, 2_101, 2_110,   &FF, 2_011,   &FF ; 45
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 46
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 47

        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 48
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 49
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 50
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 51
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 52
        DCB     2_000, 2_001,   &FF,   &FF,   &FF,   &FF,   &FF,   &FF ; 53
        ALIGN
      ]

; Available pins per target board
; Ref: http://elinux.org/RPi_BCM2835_GPIOs
GPIOFreeToUse
        DCD     2_00000011111001101100111110010011      ; B rev 1
        DCD     2_00000000000000000000000000000000
        DCD     2_00001011110001101100111110011100      ; B rev 2
        DCD     2_00000000000000000000000000000000
        DCD     2_00001011110001101100111110011100      ; A rev 2
        DCD     2_00000000000000000000000000000000
        DCD     2_00001111111111111111111111111111      ; B+
        DCD     2_00000000000000000000000000000000
        DCD     2_11111111111111111111111111111111      ; Compute rev 1
        DCD     2_00000000000000001111111111111111
        DCD     2_00001111111111111111111111111111      ; A+
        DCD     2_00000000000000000000000000000000
        DCD     2_00001111111111111111111111111111      ; 2B
        DCD     2_00000000000000000000000000000000
        DCD     2_00001111111111111111111111111111      ; zero
        DCD     2_00000000000000000000000000000000
        DCD     2_00001111111111111111111111111111      ; 3B
        DCD     2_00000000000000000000000000000000

; Pin enumerations
GPIO_Port0_Table
        PinStart     0, IO
        PinBelongsTo GPIOType_GPIO, 0, AltGPI   ; GPIO
        PinBelongsTo GPIOType_I2C, 0, Alt0      ; I2C0 SDA
        PinEnd
        PinStart     1, IO
        PinBelongsTo GPIOType_GPIO, 1, AltGPI   ; GPIO
        PinBelongsTo GPIOType_I2C, 0, Alt0      ; I2C0 SCL
        PinEnd
        PinStart     2, IO
        PinBelongsTo GPIOType_GPIO, 2, AltGPI   ; GPIO
        PinBelongsTo GPIOType_I2C, 1, Alt0      ; I2C1 SDA
        PinEnd
        PinStart     3, IO
        PinBelongsTo GPIOType_GPIO, 3, AltGPI   ; GPIO
        PinBelongsTo GPIOType_I2C, 1, Alt0      ; I2C1 SCL
        PinEnd
        PinStart     4, IO
        PinBelongsTo GPIOType_GPIO, 4, AltGPI   ; GPIO
        PinBelongsTo GPIOType_GPCLK, 0, Alt0    ; GPCLK0
        PinEnd
        PinStart     5, IO
        PinBelongsTo GPIOType_GPIO, 5, AltGPI   ; GPIO
        PinBelongsTo GPIOType_GPCLK, 1, Alt0    ; GPCLK1
        PinEnd
        PinStart     6, IO
        PinBelongsTo GPIOType_GPIO, 6, AltGPI   ; GPIO
        PinBelongsTo GPIOType_GPCLK, 2, Alt0    ; GPCLK2
        PinEnd
        PinStart     7, IO
        PinBelongsTo GPIOType_GPIO, 7, AltGPI   ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 CE1
        PinEnd
        PinStart     8, IO
        PinBelongsTo GPIOType_GPIO, 8, AltGPI   ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 CE0
        PinEnd
        PinStart     9, IO
        PinBelongsTo GPIOType_GPIO, 9, AltGPI   ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 MISO
        PinEnd
        PinStart     10, IO
        PinBelongsTo GPIOType_GPIO, 10, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 MOSI
        PinEnd
        PinStart     11, IO
        PinBelongsTo GPIOType_GPIO, 11, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 SCLK
        PinEnd
        PinStart     12, IO
        PinBelongsTo GPIOType_GPIO, 12, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PWM, 0, Alt0      ; PWM0
        PinEnd
        PinStart     13, IO
        PinBelongsTo GPIOType_GPIO, 13, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PWM, 1, Alt0      ; PWM1
        PinEnd
        PinStart     14, IO
        PinBelongsTo GPIOType_GPIO, 14, AltGPI  ; GPIO
        PinBelongsTo GPIOType_UART, 0, Alt0     ; UART0 TXD
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 TXD
        PinEnd
        PinStart     15, IO
        PinBelongsTo GPIOType_GPIO, 15, AltGPI  ; GPIO
        PinBelongsTo GPIOType_UART, 0, Alt0     ; UART0 RXD
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 RXD
        PinEnd
        PinStart     16, IO
        PinBelongsTo GPIOType_GPIO, 16, AltGPI  ; GPIO
        PinBelongsTo GPIOType_UART, 0, Alt0     ; UART0 CTS
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 CE2
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 CTS
        PinEnd
        PinStart     17, IO
        PinBelongsTo GPIOType_GPIO, 17, AltGPI  ; GPIO
        PinBelongsTo GPIOType_UART, 0, Alt0     ; UART0 RTS
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 CE1
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 RTS
        PinEnd
        PinStart     18, IO
        PinBelongsTo GPIOType_GPIO, 18, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt0      ; PCM0 CLK
        PinBelongsTo GPIOType_BSC, 0, Alt3      ; BSC0 SDA/MOSI
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 CE0
        PinBelongsTo GPIOType_PWM, 0, Alt5      ; PWM0
        PinEnd
        PinStart     19, IO
        PinBelongsTo GPIOType_GPIO, 19, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt0      ; PCM0 FS
        PinBelongsTo GPIOType_BSC, 0, Alt3      ; BSC0 SCL/SCLK
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 MISO
        PinBelongsTo GPIOType_PWM, 1, Alt5      ; PWM1
        PinEnd
        PinStart     20, IO
        PinBelongsTo GPIOType_GPIO, 20, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt0      ; PCM0 DIN
        PinBelongsTo GPIOType_BSC, 0, Alt3      ; BSC0 MISO
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 MOSI
        PinBelongsTo GPIOType_GPCLK, 0, Alt5    ; GPCLK0
        PinEnd
        PinStart     21, IO
        PinBelongsTo GPIOType_GPIO, 21, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt0      ; PCM0 DOUT
        PinBelongsTo GPIOType_BSC, 0, Alt3      ; BSC0 CE
        PinBelongsTo GPIOType_SPI, 1, Alt4      ; SPI1 SCLK
        PinBelongsTo GPIOType_GPCLK, 0, Alt5    ; GPCLK1
        PinEnd
        PinStart     22, IO
        PinBelongsTo GPIOType_GPIO, 22, AltGPI  ; GPIO
        PinEnd
        PinStart     23, IO
        PinBelongsTo GPIOType_GPIO, 23, AltGPI  ; GPIO
        PinEnd
        PinStart     24, IO
        PinBelongsTo GPIOType_GPIO, 24, AltGPI  ; GPIO
        PinEnd
        PinStart     25, IO
        PinBelongsTo GPIOType_GPIO, 25, AltGPI  ; GPIO
        PinEnd
        PinStart     26, IO
        PinBelongsTo GPIOType_GPIO, 26, AltGPI  ; GPIO
        PinEnd
        PinStart     27, IO
        PinBelongsTo GPIOType_GPIO, 27, AltGPI  ; GPIO
        PinEnd
        PinStart     28, IO
        PinBelongsTo GPIOType_GPIO, 28, AltGPI  ; GPIO
        PinBelongsTo GPIOType_I2C, 0, Alt0      ; I2C0 SDA
        PinBelongsTo GPIOType_PCM, 0, Alt2      ; PCM0 CLK
        PinEnd
        PinStart     29, IO
        PinBelongsTo GPIOType_GPIO, 29, AltGPI  ; GPIO
        PinBelongsTo GPIOType_I2C, 0, Alt0      ; I2C0 SCL
        PinBelongsTo GPIOType_PCM, 0, Alt2      ; PCM0 FS
        PinEnd
        PinStart     30, IO
        PinBelongsTo GPIOType_GPIO, 30, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt2      ; PCM0 DIN
        PinEnd
        PinStart     31, IO
        PinBelongsTo GPIOType_GPIO, 31, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PCM, 0, Alt2      ; PCM0 DOUT
        PinEnd

        ; Table ends
        DCD     -1

GPIO_Port1_Table
        PinStart     32, IO
        PinBelongsTo GPIOType_GPIO, 32, AltGPI  ; GPIO
        PinBelongsTo GPIOType_GPCLK, 0, Alt0    ; GPCLK0
        PinBelongsTo GPIOType_UART, 0, Alt3     ; UART0 TXD
        PinBelongsTo GPIOType_UART, 0, Alt5     ; UART1 TXD
        PinEnd
        PinStart     33, IO
        PinBelongsTo GPIOType_GPIO, 33, AltGPI  ; GPIO
        PinBelongsTo GPIOType_UART, 0, Alt3     ; UART0 RXD
        PinBelongsTo GPIOType_UART, 0, Alt5     ; UART1 RXD
        PinEnd
        PinStart     34, IO
        PinBelongsTo GPIOType_GPIO, 34, AltGPI  ; GPIO
        PinBelongsTo GPIOType_GPCLK, 0, Alt0    ; GPCLK0
        PinEnd
        PinStart     35, IO
        PinBelongsTo GPIOType_GPIO, 35, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 CE1
        PinEnd
        PinStart     36, IO
        PinBelongsTo GPIOType_GPIO, 36, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 CE0
        PinBelongsTo GPIOType_UART, 0, Alt2     ; UART0 TXD
        PinEnd
        PinStart     37, IO
        PinBelongsTo GPIOType_GPIO, 37, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 MISO
        PinBelongsTo GPIOType_UART, 0, Alt2     ; UART0 RXD
        PinEnd
        PinStart     38, IO
        PinBelongsTo GPIOType_GPIO, 38, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 MOSI
        PinBelongsTo GPIOType_UART, 0, Alt2     ; UART0 RTS
        PinEnd
        PinStart     39, IO
        PinBelongsTo GPIOType_GPIO, 39, AltGPI  ; GPIO
        PinBelongsTo GPIOType_SPI, 0, Alt0      ; SPI0 SCLK
        PinBelongsTo GPIOType_UART, 0, Alt2     ; UART0 CTS
        PinEnd
        PinStart     40, IO
        PinBelongsTo GPIOType_GPIO, 40, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PWM, 0, Alt0      ; PWM0
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 MISO
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 TXD
        PinEnd
        PinStart     41, IO
        PinBelongsTo GPIOType_GPIO, 41, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PWM, 1, Alt0      ; PWM1
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 MOSI
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 RXD
        PinEnd
        PinStart     42, IO
        PinBelongsTo GPIOType_GPIO, 42, AltGPI  ; GPIO
        PinBelongsTo GPIOType_GPCLK, 1, Alt0    ; GPCLK1
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 SCLK
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 RTS
        PinEnd
        PinStart     43, IO
        PinBelongsTo GPIOType_GPIO, 43, AltGPI  ; GPIO
        PinBelongsTo GPIOType_GPCLK, 2, Alt0    ; GPCLK2
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 CE0
        PinBelongsTo GPIOType_UART, 1, Alt5     ; UART1 CTS
        PinEnd
        PinStart     44, IO
        PinBelongsTo GPIOType_GPIO, 44, AltGPI  ; GPIO
        PinBelongsTo GPIOType_GPCLK, 1, Alt0    ; GPCLK1
        PinBelongsTo GPIOType_I2C, 0, Alt1      ; I2C0 SDA
        PinBelongsTo GPIOType_I2C, 1, Alt2      ; I2C1 SDA
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 CE1
        PinEnd
        PinStart     45, IO
        PinBelongsTo GPIOType_GPIO, 45, AltGPI  ; GPIO
        PinBelongsTo GPIOType_PWM, 1, Alt0      ; PWM1
        PinBelongsTo GPIOType_I2C, 0, Alt1      ; I2C0 SCL
        PinBelongsTo GPIOType_I2C, 1, Alt2      ; I2C1 SCL
        PinBelongsTo GPIOType_SPI, 2, Alt4      ; SPI2 CE2
        PinEnd
        PinStart     46, IO
        PinBelongsTo GPIOType_GPIO, 46, AltGPI  ; GPIO
        PinEnd
        PinStart     47, IO
        PinBelongsTo GPIOType_GPIO, 47, AltGPI  ; GPIO
        PinEnd
        PinStart     48, IO
        PinBelongsTo GPIOType_GPIO, 48, AltGPI  ; GPIO
        PinEnd
        PinStart     49, IO
        PinBelongsTo GPIOType_GPIO, 49, AltGPI  ; GPIO
        PinEnd
        PinStart     50, IO
        PinBelongsTo GPIOType_GPIO, 50, AltGPI  ; GPIO
        PinEnd
        PinStart     51, IO
        PinBelongsTo GPIOType_GPIO, 51, AltGPI  ; GPIO
        PinEnd
        PinStart     52, IO
        PinBelongsTo GPIOType_GPIO, 52, AltGPI  ; GPIO
        PinEnd
        PinStart     53, IO
        PinBelongsTo GPIOType_GPIO, 53, AltGPI  ; GPIO
        PinEnd

        ; Table ends
        DCD     -1

GPIOPortTables
        DCD     GPIO_Port0_Table
        DCD     GPIO_Port1_Table

        END
