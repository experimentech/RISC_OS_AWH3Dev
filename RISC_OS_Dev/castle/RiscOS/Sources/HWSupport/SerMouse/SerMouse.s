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
; > Sources.SerMouse

;---------------------------------------------------------------------------
; PointerRequest
;       In:     r0 = reason code (0 = request state)
;               r1 = device type (0 for us)
;       Out:    r2 = signed 32-bit X movement
;               r3 = signed 32-bit Y movement
;
;       Handle requests for mouse movements from the Kernel.
;
PointerRequest
        TEQ     r0, #PointerReason_Request              ; If not requesting then
        BNE     PointerIdentify                         ;   try identify.
        TEQ     r1, #PointerDevice_MicrosoftMouse       ; If not a serial mouse then
        TEQNE   r1, #PointerDevice_MSCMouse
        MOVNE   pc, lr                                  ;   pass on call.

        Push    "r10,r11"

        ADR     lr, MouseData                   ; Get DeltaX, DeltaY and Buttons.
        LDMIA   lr, {r2,r3,r10}

        MOV     lr, #0                          ; Zero DeltaX and DeltaY.
        STR     lr, DeltaX
        STR     lr, DeltaY

        LDRB    r11, LastButtons                ; Get button states on last poll.
        EORS    r11, r11, r10                   ; Get differences.
        Pull    "r10,r11,pc",EQ                 ; Claim vector if none.

        STRB    r10, LastButtons
        Push    "r0,r1,r9"

        TST     r11, #4                         ; Check left (SELECT).
        BEQ     %FT10

        TST     r10, #4
        MOVEQ   r0, #1
        MOVNE   r0, #2
        MOV     r1, #&70
        MOV     r9, #KEYV
        SWI     XOS_CallAVector
10
        TST     r11, #2                          ; Check centre (MENU).
        BEQ     %FT20

        TST     r10, #2
        MOVEQ   r0, #1
        MOVNE   r0, #2
        MOV     r1, #&71
        MOV     r9, #KEYV
        SWI     XOS_CallAVector
20
        TST     r11, #1                          ; Check right (ADJUST).
        Pull    "r0,r1,r9-r11,pc",EQ

        TST     r10, #1
        MOVEQ   r0, #1
        MOVNE   r0, #2
        MOV     r1, #&72
        MOV     r9, #KEYV
        SWI     XOS_CallAVector
        Pull    "r0,r1,r9-r11,pc"                ; Claim call.

;---------------------------------------------------------------------------
; PointerIdentify
;       In:     r0 = reason code 1
;               r1 = pointer to device type record (or 0)
;       Out:    r1 = pointer to updated list
;
;       Identify our pointer device.
;
PointerIdentify
        TEQ     r0, #PointerReason_Selected     ; If selected then
        BEQ     PointerSelected                 ;   initialise.
        TEQ     r0, #PointerReason_Identify     ; If not identify then
        MOVNE   pc, lr                          ;   pass on call.

        Entry   "r2"

        Debug   mod,"SM_PointerIdentify"

        ADR     r2, MSCData
        BL      AddPointerStruct
        EXIT    VS

        ADR     r2, MSData
        BL      AddPointerStruct
        EXIT

AddPointerStruct
; In:   r1 = pointer to device type record list or 0
;       r2 = pointer to device data
; Out:  r1 = pointer to extended list
        Entry   "r0-r4"

        LDRB    r4, [r2], #1                    ; r4=device type, r2->device name/token

  [ international
        MOV     r1, r2
        MOV     r2, #0
        BL      MsgTrans_Lookup                 ; r2->device name looked up
        EXIT    VS                              ; If lookup fails then don't add our record to list.
  ]
        MOV     r1, r2                          ; Save pointer to device name.
        BL      strlen                          ; r3=length of string pointed to by r2
        ADD     r3, r3, #MinPointerRecordSize   ; Includes byte for string terminator.
        MOV     r0, #ModHandReason_Claim        ; Claim space for a device type record.
        SWI     XOS_Module
        EXIT    VS

        LDR     r0, [sp, #4]                    ; Get back pointer to list we were passed.
        STR     r0, [r2, #PointerNext]          ; Tag it onto ours.
        MOV     r0, #0
        STR     r0, [r2, #PointerFlags]         ; No flags.
        STRB    r4, [r2, #PointerType]

        ADD     r0, r2, #PointerName
        BL      strcpy                          ; Copy name into record (r1 to r0).
        STR     r2, [sp, #4]                    ; Pass on updated record pointer.

        EXIT

strlen
; In:   r2->control char terminated string
; Out:  r3=length of string
        Entry   "r2"
        MOV     r3, #0
01
        LDRB    lr, [r2], #1
        CMP     lr, #" "
        ADDCS   r3, r3, #1
        BCS     %BT01
        EXIT

strcpy
; In:   r0->null terminated destination string
;       r1->control char terminated source string
        Entry   "r0,r1"
01
        LDRB    lr, [r1], #1
        CMP     lr, #" "
        STRCSB  lr, [r0], #1
        BCS     %BT01
        MOV     lr, #0
        STRB    lr, [r0]
        EXIT

MSCData
        DCB     PointerDevice_MSCMouse
 [ international
        DCB     "MSCName",0
 |
        DCB     "Mouse Systems Corp mouse",0
 ]

MSData
        DCB     PointerDevice_MicrosoftMouse
 [ international
        DCB     "MSName",0
 |
        DCB     "Microsoft mouse",0
 ]
        ALIGN

;---------------------------------------------------------------------------
; PointerSelected
;       In:     r1 = device type
;
;       Enable serial mouse if the type is one of ours, disable if not.
;
PointerSelected
        TEQ     r1, #PointerDevice_MicrosoftMouse       ; If not ours then
        TEQNE   r1, #PointerDevice_MSCMouse
        BNE     Disable                                 ;   make sure we're disabled.

        Entry

        Debug   mod,"SM_Enable"

        BL      MouseInit                               ; Initialise mouse.
        BL      Configure                               ; Configure serial.
        BL      Enable                                  ; Open serial, start interpreting.

        EXIT

;---------------------------------------------------------------------------
; MouseInit
;       r1 = mouse type
;
;       Initialise serial mouse.
;
MouseInit
        Entry

        Debug   mod,"SM_MouseInit"

        MOV     lr, #0                          ; Initialise mouse data.
        STR     lr, DeltaX
        STR     lr, DeltaY
        STR     lr, Buttons
        ADR     lr, MouseIdle
        STR     lr, State

        EXIT

;---------------------------------------------------------------------------
; Enable
;
;       Ensure that the serial input stream is open.
;
Enable
        Entry   "r0-r2"

        LDR     r1, SerialInHandle
        TEQ     r1, #0                          ; If serial already open then
        EXIT    NE                              ;   exit.

        Debug   mod,"SM_Enable"

        MOV     r0, #0                          ; Not locked yet.
        STRB    r0, Locked

        BL      OpenSerial

        MOVVC   r0, #TickerV                    ; Start interpreting serial input.
        ADRVC   r1, TickerVHandler
        MOVVC   r2, r12
        SWIVC   XOS_Claim

        STRVS   r0, [sp]

        EXIT

;---------------------------------------------------------------------------
; OpenSerial
;
;       Ensure that the serial input stream is open.
;
OpenSerial
        Entry   "r0-r2", 64

        MOV     r2, sp
        ADR     r1, SerialInFilename
10
        LDRB    r0, [r1], #1
        CMP     r0, #0
        STRNEB  r0, [r2], #1
        BNE     %BT10        

        MOV     r0, #SerialOp_GetDeviceName
        SWI     XOS_SerialOp
        ; r1 should now be correct device name or preserved on error
        ; i.e. left pointing at our default name
        ADD     lr, sp, #63
20
        SUBS    r0, r1, lr                      ; Basic buffer overflow check
        LDRNEB  r0, [r1], #1
        CMPNE   r0, #0
        STRB    r0, [r2], #1
        BNE     %BT20

        MOV     r0, #open_read :OR: open_mustopen       ; Open serial device for input.
        MOV     r1, sp
        SWI     XOS_Find
        STRVS   r0, [sp, #Proc_RegOffset]
        MOVVS   r0, #0
        STR     r0, SerialInHandle              ; Store handle, mark serial as open.

        EXIT

SerialInFilename
        DCB     "Devices:$.", 0, "Serial",0
        ALIGN

;---------------------------------------------------------------------------
; Disable
;
;       Close the serial input stream if it's open.
;
Disable
        EntryS  "r0-r2"

        Debug   mod,"SM_Disable"

        MOV     r0, #TickerV
        ADR     r1, TickerVHandler
        MOV     r2, r12
        SWI     XOS_Release

        LDR     r1, SerialInHandle
        TEQ     r1, #0
        MOVNE   r0, #OSFind_Close
        STRNE   r0, SerialInHandle
        SWINE   XOS_Find

        EXITS

;---------------------------------------------------------------------------
; Configure
;
;       Configure serial.
;
Configure
        Entry   "r0-r2"

        Debug   mod,"SM_Configure"

        MOV     r0, #SerialOp_Status            ; Set up serial status.
        MOV     r1, #&00000036                  ; RTS high, ignore ~CTS, DTR high, ignore ~DSR, ignore ~DCD
        MOV     r2, #&FFFFFF00
        SWI     XOS_SerialOp
        BVS     %FT99

        MOV     r0, #SerialOp_DataFormat        ; Set up data format.
        MOV     r1, #&00000000                  ; 8bit word, 1 stop bit, no parity.
        SWI     XOS_SerialOp
        BVS     %FT99

        MOV     r0, #SerialOp_RXBaud            ; Set input baud rate
        MOV     r1, #4                          ; to 1200bits/sec.
        SWI     XOS_SerialOp
99
        STRVS   r0, [sp]
        EXIT

        END
