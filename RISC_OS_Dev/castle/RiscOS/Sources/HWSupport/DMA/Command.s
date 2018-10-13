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
; > Sources.Command

        ASSERT  international

DMAChannels_Code
        LDR     r12, [r12]
        Entry   "r7-r11"
        LDR     r11, CtrlrList
        TEQ     r11, #0
        EXIT    EQ

        ; Cache information about the logical channel table.
        ADR     r1, I06
        MOV     r2, #0
        BL      MsgTrans_Lookup
        STRVC   r0, Header+4*0
        ADDVC   r1, r0, #1
01      LDRVCB  r2, [r0], #1
        TEQ     r2, #0
        BNE     %BT01
        SUBVC   r1, r0, r1
        STRVCB  r1, Width+1*0

        ADRVC   r1, I07
        MOVVC   r2, #0
        BLVC    MsgTrans_Lookup
        STRVC   r0, Header+4*1
        ADDVC   r1, r0, #1
02      LDRVCB  r2, [r0], #1
        TEQ     r2, #0
        BNE     %BT02
        SUBVC   r1, r0, r1
        STRVCB  r1, Width+1*1

        ADRVC   r1, I08
        MOVVC   r2, #0
        BLVC    MsgTrans_Lookup
        STRVC   r0, Header+4*2
        ADDVC   r1, r0, #1
03      LDRVCB  r2, [r0], #1
        TEQ     r2, #0
        BNE     %BT03
        SUBVC   r1, r0, r1
        STRVCB  r1, Width+1*2
        BVS     %FT90

10      ; Print controller header.
        ADR     r1, I00
        ADR     r2, Scratch
        MOV     r3, #?Scratch
        LDR     r4, [r11, #ctrlr_Device]
        LDR     r4, [r4, #HALDevice_Description]
        BL      MsgTrans_Lookup
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        SWIVC   XOS_NewLine
        BVS     %FT90

        LDR     r10, [r11, #ctrlr_PhysicalChannels]

        ; Count used channels.
        ADD     r6, r11, #ctrlr_DMAQueues + dmaq_Usage
        MOV     r7, r10
        MOV     r9, #0
20      LDR     r14, [r6], #DMAQSize
        TEQ     r14, #0
        ADDNE   r9, r9, #1
        SUBS    r7, r7, #1
        BNE     %BT20

        ; Print number of free channels.
        ADR     r1, I04
        MOV     r2, #0
        BL      MsgTrans_Lookup
        BVS     %FT90
        MOV     r4, r0
        SUB     r0, r10, r9
        CMP     r0, #1
        ADRLO   r1, I01
        ADREQ   r1, I02
        ADRHI   r1, Scratch + ?Scratch - 16
        MOVHI   r2, #16
        SWIHI   XOS_ConvertCardinal4
        MOVHI   r5, r4
        MOVHI   r4, r0
        ADRHI   r1, I03
        ADR     r2, Scratch
        MOV     r3, #?Scratch
        BL      MsgTrans_Lookup
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        BVS     %FT90

        ; Print number of used channels.
        ADR     r1, I05
        MOV     r2, #0
        BL      MsgTrans_Lookup
        BVS     %FT90
        MOV     r4, r0
        MOV     r0, r9
        CMP     r0, #1
        ADRLO   r1, I01
        ADREQ   r1, I02
        ADRHI   r1, Scratch + ?Scratch - 16
        MOVHI   r2, #16
        SWIHI   XOS_ConvertCardinal4
        MOVHI   r5, r4
        MOVHI   r4, r0
        ADRHI   r1, I03
        ADR     r2, Scratch
        MOV     r3, #?Scratch
        BL      MsgTrans_Lookup
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        BVS     %FT90

        TEQ     r9, #0
        BEQ     %FT80
        ASSERT  DMAQSize=112
        MOV     r10, r10, LSL #7
        SUB     r10, r10, r10, LSR #7-4
        ADD     r10, r11, r10
        ADD     r10, r10, #ctrlr_DMAQueues
30      ; Find a used channel
        SUB     r10, r10, #DMAQSize
        LDR     r8, [r10, #dmaq_Usage]
        TEQ     r8, #0
        BEQ     %BT30

        ; Print channel name
        SWI     XOS_NewLine
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVC   r0, [r10, #dmaq_DMADevice]
        LDRVC   r0, [r0, #HALDevice_Description]
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine

        ; Print headers
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVC   r0, Header+4*0
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVC   r0, Header+4*1
        SWIVC   XOS_Write0
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVC   r0, Header+4*2
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVCB  r0, Width+1*0
31      SWIVC   XOS_WriteI+'-'
        BVS     %FT90
        SUBS    r0, r0, #1
        BNE     %BT31
        SWI     XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVCB  r0, Width+1*1
32      SWIVC   XOS_WriteI+'-'
        BVS     %FT90
        SUBS    r0, r0, #1
        BNE     %BT32
        SWI     XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        LDRVCB  r0, Width+1*2
33      SWIVC   XOS_WriteI+'-'
        BVS     %FT90
        SUBS    r0, r0, #1
        BNE     %BT33
        SWI     XOS_NewLine

        ; Find a logical channel that uses this physical channel
        LDR     r7, ChannelList
40      LDR     r0, [r7, #lcb_Queue]
        TEQ     r0, r10
        LDRNE   r7, [r7, #lcb_Next]
        BNE     %BT40

        ; Print logical channel details
        SWI     XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+' '
        SWIVC   XOS_WriteI+'&'
        LDRVC   r0, [r7, #lcb_ChannelNo]
        ADRVC   r1, Scratch
        MOVVC   r2, #16
        SWIVC   XOS_ConvertHex8
        SWIVC   XOS_Write0
        LDRVCB  r0, Width+1*0
        SUBVC   r0, r0, #9-3
41      SWIVC   XOS_WriteI+' '
        BVS     %FT90
        SUBS    r0, r0, #1
        BNE     %BT41
        SWI     XOS_WriteI+'&'
        LDRVC   r0, [r7, #lcb_Vector]
        ADRVC   r1, Scratch
        MOVVC   r2, #16
        SWIVC   XOS_ConvertHex8
        SWIVC   XOS_Write0
        LDRVCB  r0, Width+1*1
        SUBVC   r0, r0, #9-3
42      SWIVC   XOS_WriteI+' '
        BVS     %FT90
        SUBS    r0, r0, #1
        BNE     %BT42
        SWI     XOS_WriteI+'&'
        LDRVC   r0, [r7, #lcb_R12]
        ADRVC   r1, Scratch
        MOVVC   r2, #16
        SWIVC   XOS_ConvertHex8
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        BVS     %FT90

        ; Next logical channel for this physical channel
        SUBS    r8, r8, #1
        LDRNE   r7, [r7, #lcb_Next]
        BNE     %BT40

        ; Next physical channel for this controller
        SUBS    r9, r9, #1
        BNE     %BT30

80      ; Next controller
        LDR     r11, [r11, #ctrlr_Next]
        TEQ     r11, #0
        EXIT    EQ
        SWI     XOS_NewLine
        B       %BT10
90
        EXIT

I00     = "I00", 0
I01     = "I01", 0
I02     = "I02", 0
I03     = "I03", 0
I04     = "I04", 0
I05     = "I05", 0
I06     = "I06", 0
I07     = "I07", 0
I08     = "I08", 0

        ALIGN

        END
