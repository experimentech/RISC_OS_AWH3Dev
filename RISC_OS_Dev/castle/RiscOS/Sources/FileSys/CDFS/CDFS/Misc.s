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
; -> Misc            *COMMANDS


; Preserve R7 - R11
;
; CONTAINS:
;          *Back
;          *Buf         only works if 'debug' = ON
;          *Bye
;          *CDDevices
;          *CDFS
;          *CDSpeed
;          *Con. CDROMDrives
;          *Con. CDROMBuffers
;          *Dismount
;          *Drive
;          *EJECT
;          *Lock
;          *Mount
;          *NoDir
;          *NoLib
;          *NoURD
;          *Play
;          *PlayList
;          *PlayMSF
;          *Stop
;          *Supported
;          *Unlock
;          *URD
;          *WhichDisc





      [ bufferlist                      ; Only works during debugging
Buf_Help ; No help or syntax lookup
Buf_Syntax
        DCB       0
        ALIGN
Buf_Code ; Display buffers
;*************************************************************************

        PushAllWithReturnFrame

        BL      DisplayBuffers

        CLRV
        PullAllFromFrameAndExit

;*************************************************************************

      ]

        LTORG

;*************************************************************************
Bye_Code ROUT ; Closes all files, emptys all drives
;*************************************************************************

        PushAllWithReturnFrame

Shutdown

;**********
; Close all files on filing system
;**********

        MOV     R0, #0
        MOV     R1, #0
        SWI     XOS_Find
        
        CLRV
        PullAllFromFrameAndExit


;*************************************************************************
CDDevices_Code  ROUT                     ; no parameters *CDDevices
;*************************************************************************
; on entry: R1 = number of parameters on line

; on exit : nothing


; layout of display:
;                                                            
;  drive  deviceid     LUN     cardnumber     productid     capacity     Firmware
;  2 + 5  1 + 4        1 + 4   1 + 4          16 + 5        upto 11 + 3  4
;
; ( + 4 indicates number of spaces )

        LDR     r12, [ r12 ]

        PushAllWithReturnFrame
        
        ; R0 -> tempbuffer is used to receive the details of the Inquiry command
        ; R4�= hardspace
        ; R6 -> Buffer is used to hold the characters to be displayed
        ; R7 -> spare control block
        ; R9 = Number of CDROMs found
        
        MOV     R4, #HARDSPACE
                
        MOV     R9, #0
                
        ADRL    R6, buffer

        ADR     r0, message_block
        addr    r1, cddevicesheader_tag
        MOV     r2, r6
        MOV     r3, #128
        SWI     XMessageTrans_GSLookup
        BVS     ErrorExit
        MOV     r0, r2
        SWI     XOS_PrettyPrint

        MOV     R11, R6

and_why_not

;**************
; Check that device is recognised by CDFS
;**************

        MOV     R0, R9
        BL      PreConvertDriveNumberToDeviceID ; on VS R0 -> error block
        BVS     DisplayDevice           ; No such device

;**************
; Inquiry device
;**************

        ADR     R0, tempbuffer
        SWI     XCD_Inquiry             ; R0 -> where to put data,R7 -> control block
        BVS     inquiryerror

;**************
; Drive number, device, card, lun
;**************

;************
; R1 = R9 MOD 10 R4 = R9 DIV 10
;************

        MOV     R1, R9
        
        DivideBy10 R1, R3, R14
        
        ADD     R1, R1, #"0"
        STRB    R1, [ R6 ], #1
        ADD     R3, R3, #"0"
        STRB    R3, [ R6 ], #1
        
        BL      space

        STRB    R4, [ R6 ], #1          ; Extra space

        LDMIA   R7, { R1, R2, R10 }
        
        ADD     R1, R1, #"0"            ; device id
        STRB    R1, [ R6 ], #1          ;
        
        BL      space                   ; R6 -> place to space, R4 = SPACE


        ;------------------------------------------------
        ; The LUN and card number are the wrong way round
        ;------------------------------------------------

        ADD     r1, r10, #"0"           ; card number
        STRB    r1, [ r6 ], #1          
                                        
        BL      space                   
                                        
        ADD     r1, r2, #"0"            ; LUN
        STRB    r1, [ r6 ], #1          
                                        
        BL      space                   

;------------------------------------------------

;**************
; Copy 'CDU-xxxx' to print buffer
;**************

        ADD     R2, R0, #16             ; CD-ROM CDU 6XXX or LMS 212
        ADD     R1, R2, #16             

01

        LDRB    R14, [ R2 ], #1         
                                        
        TEQ     R14, #SPACE             ; Convert spaces to hard spaces
        MOVEQ   R14, #HARDSPACE         
        STRB    R14, [ R6 ], #1
                                        
        TEQ     R1, R2                  
        BNE     %BT01                   
                                        
        BL      space                   ; R6 -> place to space, R4 = SPACE

        STRB    R4, [ R6 ], #1          ; Extra space

;*******************
; Disc capacity
;*******************

        MOV     R10, R6
        SUB     SP, SP, #8
        MOV     R1, SP
        MOV     R0, #LBAFormat
                
        SWI     XCD_DiscUsed
        Pull    "R1,R3"                 ; R1 = number of blocks
                                        ; R3 = size of a block

;****** If unknown then 'Unknown'

        ADRVS   R2, Unknown             ; capacity is unknown
        BVS     %FT05

;****** ELSE convert blocksize to Megabytes

        MOV     R14, R1, LSL #16
        MOV     R1, R1, LSR #16         ; r1 = mshw of block count
        MOV     R0, r14, LSR #16        ; r0 = lshw of block count

        MUL     R14, R1, R3
        MUL     R0, R3, R0
        MOV     R1, R14, LSR #16
        ADDS    R0, R0, R14, LSL #16
        ADC     R1, R1, #0              ; r0,r1 are lsw,msw of disc size

        MOVS    R0, R0, LSR #20
        ORR     R0, R0, R1, LSL #12     ; Crude, but definitely covers 0 to 9999 MB
        ADDCS   R0, R0, #1

        TEQ     R0, #1
        ADREQ   R2, OneMegaByte         ; Singular
        BEQ     %FT05

        MOV     R1, R6                  ; R1 -> buffer to put
        MOV     R2, #20                 ; R2 = length of buffer
        SWI     XOS_ConvertCardinal2    ; While OS_ConvertFileSize almost does what is desired, it
        MOV     R6, R1                  ; jumps at 4096 and we're more interested in fine MB than coarse GB
        ADR     R2, MegaBytes
05
        LDRB    R14, [ R2 ], #1
        TEQ     R14, #0                 ; strcpy(R6, R2)
        STRNEB  R14, [ R6 ], #1
        BNE     %BT05

        SUB     R2, R6, R10             ; Length of capacity
        SUB     R2, R2, #14 - 8         ; Padding correction after 8 spaces
        BL      space                   ; R6 -> place to space, R4 = SPACE
        BL      space                   
        SUB     R6, R6, R2

;*******************
; Firmware revision number, eg '2.01'
;*******************

        LDR     R2, tempbuffer + 32
13
        STRB    R2, [ R6 ], #1
        MOVS    R2, R2, LSR #8
        BNE     %BT13
                
        MOV     R3, #13
        STRB    R3, [ R6 ], #1

inquiryerror

        ADD     R9, R9, #1
        LDRB    R14, numberofdrives     ; any more drives to look for ?
        CMP     R14, R9
        BHS     and_why_not             ; [ yes ]

;*********************
; Display number of CDROMs found     R9 = number found
;*********************

DisplayDevice

        TEQ     R9, #0
        MOVNE   R0, R11                 ; Some drive(s) were found
        MOVNE   R4, #0
        STRNEB  R4, [ R6 ]
        BNE     %FT10

        ADR     r0, message_block       ; No drive was found
        addr    r1, nodrivesfound_tag
        MOV     r2, r6
        MOV     r3, #128
        ASSERT  ?buffer >= 128
        SWI     XMessageTrans_Lookup
        ADDVS   r0, r0, #4              ; Show the error instead
        MOVVC   r0, r2
10
        SWI     XOS_PrettyPrint
        TEQ     r9, #0
        SWIEQ   XOS_NewLine
        
        CLRV
        PullAllFromFrameAndExit

Unknown
        DCB     "Unknown", 0
MegaBytes
        DCB     HARDSPACE, "Mbytes", 0
OneMegaByte
        DCB     "1", HARDSPACE, "Mbyte", 0        
        ALIGN

space
        STRB    R4, [ R6 ], #1
        STRB    R4, [ R6 ], #1
        STRB    R4, [ R6 ], #1
        STRB    R4, [ R6 ], #1
        MOV     PC, R14

;----------------------------------------------------------------------------------------------
; *CDSpeed
; If '*CDSpeed' without any parameters, then current speed for current drive returned
; if '*CDSpeed <d>' then current speed for drive 'd' returned
; if '*CDSpeed <d> <s>' then set the speed for drive 'd' to 's'.  If 's' == 255 then set to
;     maximum.  1 is standard, 2 is double.
CDSpeed_Code ROUT
;----------------------------------------------------------------------------------------------
; on entry:
;          r0 -> parameter line
;          r1 =  number of parameters on line

        PushAllWithReturnFrame
        
        MOV     r4, r1

        ;----------------
        ; Current drive ?
        ;----------------
        CMP     r1, #1
        
        BLGE    atoi
        BVS     ErrorExit
        MOVGT   r3, r0
        MOVGE   r0, r2
        LDRLTB  r0, CurrentDriveNumber

        ;----------------
        ; Device number ?
        ;----------------
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, returns R7 -> block
        BVS     ErrorExit

        ;---------------------
        ; Get current settings
        ;---------------------
        ADR     r0, TempArea            
        SWI     XCD_GetParameters       ; r0->storage area, r7->block
        BVS     ErrorExit               

        ;--------------------------
        ; Display current setting ?
        ;--------------------------
        CMP     r4, #2
        BGE     %FT01
        
        MOV     r1, r0
        LDRB    r0, [ r1, #12 ]
        MOV     r2, #4
        SWI     XOS_BinaryToDecimal
        MOV     r0, r1
 
        Push    "r0-r3"
        ADR     r0, message_block
        addr    r1, currentspeed_tag
        ADR     r2, TempArea + 100
        MOV     r3, #128
        SWI     XMessageTrans_Lookup
        BVS     ErrorExit
        MOV     r0, r2
        SWI     XOS_Write0
        Pull    "r0-r3"

        MOV     r1, r2
        SWI     XOS_WriteN
        SWI     XOS_NewLine
        B       common_end

;--------------
; Set speed
;--------------
01

;------------------------------
; Decode the string to a number
;------------------------------
        MOV     r4, r0
        MOV     r0, r3
        BL      atoi
        BVS     ErrorExit
        STRB    r2, [ r4, #12 ]

;----------------
; Change CD speed
;----------------
        MOV     r0, r4
        SWI     XCD_SetParameters
                
        B       common_end


;*************************************************************************
; This is the *CONFIGURE CDROMBuffers
;*************************************************************************

; on entry:
;          R0 = 0   THEN *CONFIGURE with no option
;          R0 = 1   THEN *STATUS
;          R0 <> 0 AND R0 <> 1 THEN *CONFIGURE R0 -> string

; This works out if a *configure or *status has been performed

CDROMBuffers_Code ROUT

        LDR R12, [ R12 ]
        
        PushAllWithReturnFrame
                                        ; Just print the configure description
        CMP     R0, #1                  ; message
        BHI     SetNumberOfBuffers      ;  *CONFIGURE number
        BEQ     %FT10
        
        ADR     R0, ConfigureMessageForBuffers ; Show *CONFIGURE syntax
        SWI     XOS_PrettyPrint
        SWIVC   XOS_NewLine

        PullAllFromFrameAndExit

10
        ; Print *STATUS of CDROMBuffers
        ADR     R0, ConfigureMessageForBuffers ; Display 'CDROMBuffers '
        MOV     R1, #13                 ;
        SWI     XOS_WriteN              ;
                
        SWI     XCDFS_GetBufferSize     ; RETURNS R0 = 0 to 7
                
        BL      ConvertBufferSizeToReal ; R0 = bit values, RETURNS R1 = buffer actual
                
        MOV     R0, R1
        ADR     R1, TempArea
        MOV     R2, #20
        SWI     XOS_ConvertCardinal2    ; see page 602  ( integers from 0 to 65535 )
                
        SWI     XOS_PrettyPrint
        SWI     XOS_WriteI + "K"
        SWI     XOS_NewLine
                
        CLRV
        PullAllFromFrameAndExit

;**************
SetNumberOfBuffers
;**************

; This gets the value currently stored in CMOS ram
; then combines it with the desired setting, so that the other bits
; in the byte are preserved

        MOV     R1, R0                  ; R1 -> string
        
        MOV     R0, #10                 ; base 10
        
        ; restrict number to be in range 0 - maxnumberofdrivessupported
        
        ORR     R0, R0, #(1:SHL:29)
        MOV     R2, #MAXBUFFERSIZE
        SWI     XOS_ReadUnsigned
        
        PullAllFromFrame VS             ; Indicate 'Parameter too big'
        MOVVS   R0, #2                  ;
        MOVVS   PC, R14                 ;

        MOV     R0, R2
        BL      ConvertRealBufferToSize ; R0 = number of K, RETURNS R1 = bit setting
        
        MOV     R0, R1
        SWI     XCDFS_SetBufferSize
        B       common_end

ConfigureMessage
        DCB     "CDROMDrives <D>", 0
ConfigureMessageForBuffers
        DCB     "CDROMBuffers <D>[K]", 0
        ALIGN

;*************************************************************************
; This is the *CONFIGURE CDROMDrives
;*************************************************************************

; on entry:
;          R0 = 0   THEN *CONFIGURE with no option
;          R0 = 1   THEN *STATUS
;          R0 <> 0 AND R0 <> 1 THEN *CONFIGURE R0 -> string

; This works out if a *configure or *status has been performed

CDROMDrives_Code ROUT

        LDR     R12, [ R12 ]
        
        PushAllWithReturnFrame
                                        ; Just print the configure description
        CMP     R0, #1                  ; message
        BHI     SetNumberOfDrives       ;  *CONFIGURE number
        BEQ     %FT10

        ADR     R0, ConfigureMessage    ; Show *CONFIGURE syntax
        SWI     XOS_PrettyPrint
        SWIVC   XOS_NewLine

        PullAllFromFrameAndExit

10
        ; Print *STATUS of CDROMDrives

        ADR     R0, ConfigureMessage    ; Display 'CDROMDrives '
        MOV     R1, #12
        SWI     XOS_WriteN              ;
                
        SWI     XCDFS_GetNumberOfDrives ; RETURNS R0 = number of drives conf.
        BVS     ErrorExit
                
        ADR     R1, TempArea
        MOV     R2, #20
        SWI     XOS_ConvertCardinal1    ; see page 602
                
        SWI     XOS_PrettyPrint
        SWI     XOS_NewLine
                
        CLRV
        PullAllFromFrameAndExit

;**************
SetNumberOfDrives
;**************

; This gets the value currently stored in CMOS ram
; then combines it with the desired setting, so that the other bits
; in the byte are preserved


        ; Make the string into a real number
        
        MOV     R1, R0                  ; R1 -> string
        MOV     R0, #10                 ; base 10
        
        ; restrict number to be in range 0 - maxnumberofdrivessupported
        
        ORR     R0, R0, #(1:SHL:29)
        MOV     R2, #MAXNUMBEROFDRIVESSUPPORTED
        SWI     XOS_ReadUnsigned
        
        PullAllFromFrame VS             ; Indicate 'Parameter too big'
        MOVVS   R0, #2                  ;
        MOVVS   PC, R14                 ;
        
        ; This gets the value currently stored in CMOS ram
        
        MOV     R0, R2
        SWI     XCDFS_SetNumberOfDrives
        
        STRVS   R0, [R13]               ; Indicate the unknown error to FS
        PullAllFromFrame VS             ;
        MOVVS   PC, R14                 ;
        
        PullAllFromFrameAndExit

;*************************************************************************
Dismount_Code ROUT  ; *Dismount drive number or disc name
;*************************************************************************

; R0 -> parameters passed in
; R1 = number of parameters

        PushAllWithReturnFrame

;******************
; Were any parameters following *Dismount ?
;******************

        TEQ     R1, #0                  ;
        LDREQB  R0, CurrentDriveNumber  ; [ no - so dismount current drive ]
        BEQ     %FT04                   ;

;******************
; If a ':' was the first char of the parameter THEN ignore it
;******************

        Push    "R0"
                
        LDRB    R1, [ R0 ]
        TEQ     R1, #":"
        ADDEQ   R0, R0, #1

;******************
; Validate the parameter for valid characters
;******************

        BL      CheckDiscName           ; R0 -> string

        Pull    "R0"

;******************
; Copy parameter into 'TempArea' prefixed with ':' if necessary
;******************

 ; Make sure that the name or number is prefixed with ":"

        MOV     R1, #":"
        ADR     R2, TempArea
        MOV     R3, R2
                
        STRB    R1, [ R2 ], #1
                
        LDRB    R1, [ R0 ], #1
        TEQ     R1, #":"
        STRNEB  R1, [ R2 ], #1

03

        LDRB    R1, [ R0 ], #1
        STRB    R1, [ R2 ], #1
        TEQ     R1, #0
                
        BNE     %BT03

;******************
; Prompt for disc to be inserted ( as it isn't buffered )
;******************

        ADD     R0, R3, #1
        BL      FindDiscNameInList
        CMP     R1, #-1
        SUBEQ   R0,R0,#1
        BLEQ    FindDriveNumber         ; R0 -> name or number, RETURNS R1 = drive

;******************
; Now I know the drive number !
;******************

        MOV     R0, R1
04

;******************
; Wipe the disc name from the list of discs mounted
;******************

        LDR     R2, =:INDEX:DiscNameList
      [ MAXLENGTHOFDISCNAME<>32
        MOV     R3, #MAXLENGTHOFDISCNAME
        MLA     R4, R3, R0, R2
      |
        ADD     R4, R2, R0, LSL #5
      ]
        MOV     R3, #0
        STRB    R3, [ R4, R12 ]!
                
        ADRL    R14, discsMounted
        STR     R3, [ R14, R0, LSL #2 ]

;******************
; Remove the disc number from the list of discs mounted
;******************

        ADRL    R14, ListOfDiscsInDrives
        LDR     R0, [ R14, R0, LSL #2 ]!
        STR     R3, [ R14 ]
                
        BL      PreConvertDriveNumberToDeviceID
        SWI     XCD_DiscHasChanged
        BVS     ErrorExit

;******************
; Close all the files on the disc
; R0 = unique number
;******************

;**********
; Make sure that all files related to this disc are closed
;**********

        ; R0 = disc
        ; R1 = block
        ; R2 -> buffer list
        LDR     R2, pointerToBufferList

;**********
; Close all directory buffers on the disc
;**********

01

        LDMIA   R2!, { R1, R4, R5, R6 } ; R1 = disc, R4 = buffer, R5 = block
                                        ; r6=offset
        TEQ     R4, #0                  ; Last entry in list ?
        BEQ     %FT02                   ; [ yes ]
        
        
        TEQ     R1, R0
        BNE     %BT01
                
        MOV     R1, R5
        BL      DeleteBuffer            ; R0 = unique number, R1 = block number
        LDR     R2, pointerToBufferList ; start from begining again
        
        B       %BT01

02

;**********
; Close all files on the disc
;**********

        ; R0 = disc number to look for
        ; R1 -> current pointer in list
        ; R2 = number searched so far ( 255 to 0 ) BACKWARDS !
        ; R3 = disc number of little buffer
        ; R4 -> little buffer
        ADRL    R1, OpenFileList        ; This list contains pointers to small
                                        ; buffers for each open file or 0
        MOV     R2, #MAXNUMBEROFOPENFILES - 3   ; From 253 to 0

05

        LDR     R4, [ R1 ], #4
                
        SUBS    R2, R2, #1              ; Reached end ?
        PullAllFromFrame EQ             ;
        MOVEQ   PC, R14                 ; [ yes ]  V is clear
                                        
        TEQ     R4, #0                  ; Number not used ?
        BEQ     %BT05                   ; [ not used ]

        LDR     R3, [ R4, #DISCNUMBEROPEN ] ; Does this buffer come from this disc ?
        TEQ     R3, R0
        BNE     %BT05
                                        ;
        Push    "R0-R1"                 ; [ yes ] - so close that file
        
        MOV     R0, #0
        LDR     R1, [ R4, #FILESWITCHHANDLE ]
        SWI     XOS_Find

        Pull    "R0-R1"
        
        B       %BT05

;*************************************************************************
; This is the *EJECT command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

Eject_Code

        PushAllWithReturnFrame

        TEQ     R1, #1

;*****************
; Deal with parameter
;*****************

        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
        
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> block
        
        SWIVC   XCD_OpenDrawer
        
        B       common_end

;*************************************************************************
; This is the *LOCK command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

Lock_Code

        PushAllWithReturnFrame

        TEQ     R1, #1

;*****************
; Deal with parameter
;*****************

        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
        
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> control block
        
        MOVVC   R0, #1
        
        SWIVC   XCD_EjectButton

        B       common_end


;*************************************************************************
Drive_Code ROUT     ; *Drive is now implemented as *Mount
Mount_Code ROUT     ; *Mount drive number or disc name
;*************************************************************************

; R0 -> parameters passed in ( terminated by a char < 32 )
; R1 = number of parameters

        PushAllWithReturnFrame

        ; IF NOTHING SUPPLIED THEN COPY IN THE CSD DISC NAME/ DRIVE NUMBER

        TEQ     R1, #0
        ; MB FIX
        ; this caused attempted writing to ROM doh!
        ; original code: ADREQ R0, BlankPath     ; R0 -> '$'
        ; instead of that, construct a "$" string in the tenpbuffer area and use that
        ADREQ   R0,tempbuffer
        MOVEQ   R1,#"$"
        STREQB  R1,[R0,#0]
        MOVEQ   R1,#0
        STREQB  R1,[R0,#1]
        ; end MB FIX
        MOVEQ   r6, #0

        BEQ     SetDir_fixed_for_mount

;*****************
; Deal with parameter
;*****************

        ; Make sure that the name or number is prefixed with ":"

        ADR     R2, tempbuffer
        MOV     R3, R2
        
        LDRB    R1, [ R0 ]
        TEQ     R1, #":"
        MOVNE   R1, #":"
        ADDEQ   R0, R0, #1
        STRB    R1, [ R2 ], #1

01

        LDRB   R1, [ R0 ], #1
        CMP    R1, #32
        STRGTB R1, [ R2 ], #1
        BGT    %BT01
        
        MOV    R1, #"."
        STRB   R1, [ R2 ], #1
        MOV    R1, #"$"
        STRB   R1, [ R2 ], #1
        MOV    R1, #0
        STRB   R1, [ R2 ], #1
        
        MOV    R0, R3
        MOV    r6, #0

        B      SetDir_fixed_for_mount   ; R0 -> path

BlankPath
        DCB    "$", 0
        ALIGN


;*************************************************************************
; This is the *PLAY command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=1 then use current drive,
;          r1=2 then use drive specified

Play_Code

        PushAllWithReturnFrame
        
        TEQ     R1, #2

;*****************
; Deal with parameter
;*****************

        BL      atoi                    ; r0->first parameter, RETURNS r0->next param (if any),
                                        ; RETURNS r2=value
        BVS     ErrorExit
        
        Push    "R2"

;****************
; Make sure that that track exists
;****************

;*****************
; Find number of tracks on disc
;*****************

        BLEQ    atoi
        ADDVS   R13, R13, #4
        BVS     ErrorExit
        
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
        ADR     R1, TempArea
        
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> control block
        
        MOVVC   R0, #0
        SWIVC   XCD_EnquireTrack
        BVS     ErrorExit
                
        Pull    "R2"
                
        LDRB    R6, [ R1, #0 ]          ; start track
        LDRB    R14, [ R1, #1 ]         ; end track
        CMP     R2, R14                 ; number too big ?

        MOVGT   r0, #ERROR_TOOBIG
        BGT     ErrorExit

        CMP     R2, R6                  ; number too small ?

        MOVLT   r0, #ERROR_TOOSMALL
        BLT     ErrorExit

;****************
; Play track
;****************


        MOV     R1, #&FF                ; R1 = play to end of disc
                                        ; ( or to start of a data track )
        MOV     R0, R2                  ; R2 contains the integer result
        SWI     XCD_PlayTrack
        
        B       common_end

;---------------------------------------------------------------------------
atoi        ; convert ascii to integer
;---------------------------------------------------------------------------

; on entry:
;          r0->ascii value
; on exit:
;          r0->next parameter or end_of_string+1
;          r1 corrupted
;          r2=integer
;          V set if error (we don't know how much to adjust SP by before
;            branching to ErrorExit ourselves) else flags preserved

        Push    "R14"
        MRS     R1, CPSR
        TEQ     PC, PC
        Push    "R1", EQ
        
        MOV     R1, R0
        MOV     R0, #10+(1:SHL:31)      ; make sure terminator is control char or space
        SWI     XOS_ReadUnsigned
        
        MOVVC   R0, R1
        
        TEQ     PC, PC
        Pull    "R1", EQ
        Pull    "PC", VS
        Pull    "PC", NE, ^
        MSR     CPSR_f, R1
        Pull    "PC"


;*************************************************************************
; This is the *PlayList command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

; R6 = current track
; R7 -> spare control block
; R9 -> current position in buffer
; R10 = start track
; R11 = end track
; temp3 = current track

PlayList_Code

        PushAllWithReturnFrame
        
        TEQ     R1, #1

;*****************
; Deal with parameter(s)
;*****************

        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
        
        BL     PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> control block
        
        
        ADRL    R1, buffer              ; storage area = buffer
        MOVVC   R0, #0
        SWIVC   XCD_EnquireTrack
        BVS     ErrorExit
        
        LDRB    R10, [ R1 ]             ; start track
        LDRB    R11, [ R1, #1 ]         ; end track
        MOV     R6, R10                 ; current track
        
        MOV     R9, R1

        ADR     r0, message_block
        addr    r1, playlist_tag
        MOV     r2, r9
        MOV     r3, #128
        SWI     XMessageTrans_Lookup
        BVS     ErrorExit
        MOV     r0, r2
        SWI     XOS_Write0
        SWI     XOS_NewLine

PlayListLoop            ; loop

        MOV     R0, R6
        ADD     R1, R12, #:INDEX:TempArea
        SWI     XCD_EnquireTrack
        BVS     ErrorExit

;****************
; DISPLAY TRACK
;****************

        ADR     r0, message_block
        addr    r1, track_tag
        MOV     r2, r9
        MOV     r3, #128
        SWI     XMessageTrans_GSLookup
        BVS     ErrorExit
        ADD     r9, r2, r3

        MOV     R0, R6
        MOV     R1, R9
        MOV     R2, #255
                
        CMP     R0, #10
        MOVLT   R14, #"0"
        STRLTB  R14, [ R1 ], #1

        SWI     XOS_ConvertCardinal1    ; R0 = value, R1->buffer, R2=buffersize
                                        ; RETURNS R0->buffer,R1->end,R2=bytes left

        MOV     R9, R1
        MOV     R14, #HARDSPACE
12
        TST     R9, #3
        STRNEB  R14, [ R9 ], #1
        BNE     %BT12
                
        LDRB    R14, TempArea + 4       ; If control bits AND 1 = 0 THEN audio
        TST     R14, #1                 ; ELSE data

        ADR     r0, message_block
        addr    r1, audio_tag, EQ
        addr    r1, data_tag, NE
        MOV     r2, r9
        MOV     r3, #128
        SWI     XMessageTrans_GSLookup
        BVS     ErrorExit
        ADD     r9, r2, r3

;****************
; MM:SS:FF
;****************

        ; R5 = LBA of start of track
        ; R6 = frames
        ; R3 = seconds
        ; R0 = minutes
        LDR     R5, TempArea
        ADD     R5, R5, #150

                                                      ; R3 = address DIV 75
                                                      ;
        DivRem  R3, R5, #MaxNumberOfBlocks + 1, R14   ; R5 = address MOD 75
       
        DivRem  R0, R3, #MaxNumberOfSeconds + 1, R14  ; R0 = ( address / 75 ) / 60
                                                      ;
                                                      ; R3 = ( address/75 ) MOD 60

        MOV     R8, #":"
        MOV     R4, #"0"
                
        MOV     R1, R9
        CMP     R0, #10
        STRLTB  R4, [ R1 ], #1
        SWI     XOS_ConvertCardinal1    ; R0 = value, R1->buffer, R2=buffersize
                                        ; RETURNS R0->buffer,R1->end,R2=bytes left

        STRB    R8, [ R1 ], #1
        
        MOV     R0, R3
        CMP     R0, #10
        STRLTB  R4, [ R1 ], #1
        SWI     XOS_ConvertCardinal1    ; R0 = value, R1->buffer, R2=buffersize
        
        STRB    R8, [ R1 ], #1
        
        MOV     R0, R5
        CMP     R0, #10
        STRLTB  R4, [ R1 ], #1
        SWI     XOS_ConvertCardinal1    ; R0 = value, R1->buffer, R2=buffersize
        
        MOV     R9, R1
        
        MOV     R0, #HARDSPACE
13
        ADD     R14, R9, #1             ; Word align for "Track"
        TST     R14, #3
        STRNEB  R0, [ R9 ], #1
        BNE     %BT13

;****************
; LINE FEED
;****************

        MOV     R0, #NEWLINE
        STRB    R0, [ R9 ], #1

;****************
; NEXT loop
;****************

        ADD     R6, R6, #1              ;  Increment current_track%
                
        CMP     R6, #99                 ;  Make sure that can't infinite loop
        CMPLE   R6, R11
                
        BLE     PlayListLoop

;****************
; empty buffer
;****************

        MOV     R0, #0                  ; terminator
        STRB    R0, [ R9 ]
        
        ADRL    R0, buffer
        MOV     R9, R0
                
        SWI     XOS_PrettyPrint

;***************
; Print "Total of "      ; finish_track% - start_track% + 1; " tracks "
;***************

        ADR     r0, message_block
        addr    r1, total_tag
        ADR     r2, TempArea
        MOV     r3, #128
        ASSERT  ?TempArea >= 128
        SWI     XMessageTrans_GSLookup
        MOVVC   r0, r2
        ADDVS   r0, r0, #4
        SWI     XOS_Write0

        SUB     R0, R11, R10
        ADD     R0, R0, #1
        MOV     R3, R0                  ; Copy for after SWI

        ADR     R1, TempArea
        MOV     R2, #3
        ASSERT  ?TempArea >= 3
        SWI     XOS_ConvertCardinal1

        CMP     R3, #10                 ; Pad when < 10
        SWICC   XOS_WriteI + "0"
        SWI     XOS_Write0

        ADR     r0, message_block
        addr    r1, tracks2_tag
        ADR     r2, TempArea
        MOV     r3, #128
        ASSERT  ?TempArea >= 128
        SWI     XMessageTrans_GSLookup
        MOVVC   r0, r2
        ADDVS   r0, r0, #4
        SWI     XOS_PrettyPrint


        MOV     R0, #MSFFormat
        ADR     R1, TempArea
        SWI     XCD_DiscUsed
        BVS     ErrorExit
                
        LDR     R6, [ R1 ]              ; R0 = end of disc

        MOV     R1, R9
        MOV     R2, #255
        MOV     R7, #":"
        MOV     R8, #"0"

;**********************
; MINUTES

        MOV     R0, R6, ASR #16         ; MINUTES
        AND     R0, R0, #&FF            ;
                
        CMP     R0, #10
        STRLTB  R8, [ R1 ], #1          ; '0'
        
        SWI     XOS_ConvertCardinal1    ; R0 = value,R1->buffer,R2=sizeofbuffer
                                        ; RETURNS R0 -> buffer,R1->end,R2=bytes left
        STRB    R7, [ R1 ], #1          ; ':'

; SECONDS

        MOV     R0, R6, ASR #8          ; SECONDS
        AND     R0, R0, #&FF            ;
                
        CMP     R0, #10
        STRLTB  R8, [ R1 ], #1          ; '0'
        
        SWI     XOS_ConvertCardinal1    ; R0 = value,R1->buffer,R2=sizeofbuffer
                                        ; RETURNS R0 -> buffer,R1->end,R2=bytes left
        STRB    R7, [ R1 ], #1          ; ':'

; FRAMES

        AND     R0, R6, #&FF            ;
                
        CMP     R0, #10
        STRLTB  R8, [ R1 ], #1          ; '0'
        
        SWI     XOS_ConvertCardinal1    ; R0 = value,R1->buffer,R2=sizeofbuffer
                                        ; RETURNS R0 -> buffer,R1->end,R2=bytes left

        MOV     R0, R9
        SWI     XOS_Write0
                
        SWI     XOS_NewLine
                
        CLRV
        PullAllFromFrameAndExit

;*************************************************************************
PlayMSF_Code ROUT ; Plays from time 1 to time 2
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=2 then use current drive,
;          r1=3 then use drive specified

        PushAllWithReturnFrame

;******************
; Check parameters for correctness - should be 'MM:SS:FF'
;******************

        MOV     R2, R0
                
        MOV     R5, #2

01
        BL      %FT10                   ; check for '0' to '9', R4 corrupted
        BL      %FT10                   ; check for '0' to '9', R4 corrupted
        
        LDRB    R3, [ R2 ], #1       
        TEQ     R3, #":"             
        BNE     %FT01                
        
        SUBS    R5, R5, #1
        BNE     %BT01
        
        BL      %FT10                   ; check for '0' to '9', R4 corrupted
        BL      %FT10                   ; check for '0' to '9', R4 corrupted
        
        SUB     R14, R2, R0             ; Check the second parameter ?
        CMP     R14, #8                 ;
        BLT     %BT01                   ; [ yes ]

;******************
; Convert the parameters to numbers and store them in registers
; These are then sent to CD_PlayAudio SWI in MSF form ( mode 1 )
;******************

; R8 = first parameter
; R9 = second parameter

;**************
; Set R8 to imposs. value for first parameter
; This means that a general proc. can be made for converting text to
; digit
;**************

        MOV     R8, #-1

;**************
; R2 -> start of parameters following '*PlayMSF'
; This works out from the characters given, to an MSF value
;**************

        MOV     R2, R0

;**************

03

        BL      %FT20
        ADD     R9, R3, R4, ASL #1
                
        BL      %FT20
        ADD     R3, R3, R4, ASL #1
        ORR     R9, R3, R9, ASL #8
                
        BL      %FT20
        ADD     R3, R3, R4, ASL #1
        ORR     R9, R3, R9, ASL #8

;*************
; Do the second parameter ?
;*************

        CMP     R8, #-1                 ; If R8 = -1 Then do the second parameter
        MOVEQ   R8, R9                  ;
        BEQ     %BT03                   ;

;******************
; Send parameters to current drive number [drive] specified ?
;******************

        TEQ     R1, #3
        MOVEQ   R0, R2
        BLEQ    atoi
        BVS     ErrorExit
        MOVEQ   R0, R2
        LDRNEB  R0, CurrentDriveNumber

        BL      PreConvertDriveNumberToDeviceID

        MOVVC   R0, #1
        MOVVC   R1, R8
        MOVVC   R2, R9
                
        SWIVC   XCD_PlayAudio
        BVS     ErrorExit

        B       %FT02

;******************
; Resolve digits from characters
;******************

20
        LDRB    R4, [ R2 ], #1          ;
        LDRB    R3, [ R2 ], #2          ; Move past ':'
        SUB     R4, R4, #"0"            ; R4 = M
        SUB     R3, R3, #"0"            ; R3 = M
                
        ADD     R4, R4, R4, ASL #2      ; R9 = First digit * 10
                
        MOV     PC, R14

;******************
; Check for a digit
;******************

10
        LDRB    R3, [ R2 ], #1
        CMP     R3, #"0"                
        RSBHSS  R4, R3, #"9"+1          
        MOVHI   PC, R14                 ; ALLOW TO RUN ON

;******************
01     ; Incorrect syntax on parameter line
;******************

        ADR     r0, message_block
        addr    r1, playmsf_tag
        ADR     r2, TempArea
        MOV     r3, #128
        SWI     XMessageTrans_Lookup
        BVS     ErrorExit
        MOV     r0, r2
        SWI     XOS_PrettyPrint
        SWI     XOS_NewLine
02
        CLRV
        PullAllFromFrameAndExit


;*************************************************************************
; This is the *STOP command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

Stop_Code

        PushAllWithReturnFrame

        TEQ     R1, #1

;*****************
; Deal with parameter
;*****************

        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
                
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> control block
                
        SWIVC   XCD_StopDisc
                
        B       common_end

;*************************************************************************
; This is the *Supported command - lists drives recognised by CDFS
;*************************************************************************

Supported_Code
        
        Push    "R14"
                
        ADR     r0, message_block
        ADR     r1, drivessupported
        ADR     r2, tempbuffer
        MOV     r3, #256
        SWI     XMessageTrans_Lookup
        Pull    "PC", VS
        MOV     r0, r2
        SWI     XOS_PrettyPrint         ; SMC: Why??
        SWI     XOS_NewLine
                
        CLRV
        Pull    "PC"

drivessupported
        DCB     "dr",0
        ALIGN

;*************************************************************************
; This is the *UNLOCK command
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

Unlock_Code

        PushAllWithReturnFrame
        
        TEQ     R1, #1

;*****************
; Deal with parameter
;*****************

        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2
                
        BL      PreConvertDriveNumberToDeviceID ; R0 = drive number, R7 -> control block
                
        MOVVC   R0, #0
                
        SWIVC   XCD_EjectButton

common_end

        BVS    ErrorExit
        PullAllFromFrameAndExit

;*************************************************************************
WhichDisc_Code ROUT        ; displays a unique number for the disc in the drive
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

        PushAllWithReturnFrame
        
        TEQ     R1, #1                  ; Optional drive parameter?
        BLEQ    atoi
        BVS     ErrorExit
        LDRNEB  R0, CurrentDriveNumber
        MOVEQ   R0, R2

        BL      PreGetUniqueNumber      ; R0 = drive number
                                        ; RETURNS R1 = uid, R2 = changed/notchanged flag
        
        MOV     R0, R1                  ; R0 = value to be converted
        ADR     R1, TempArea            ; R1 -> place to put string
        MOV     R2, #?TempArea
        SWI     XOS_ConvertCardinal4
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine
        
        CLRV
        PullAllFromFrameAndExit

;*************************************************************************
Free_Code ROUT        ; displays used space
;*************************************************************************

; on entry:
;          r0->command tail
;          R1=number of parameters
;          r1=0 then use current drive,
;          r1=1 then use drive specified

        PushAllWithReturnFrame

;******************
; Were any parameters following *Free ?
;******************

        TEQ     R1, #0                  ;
        LDREQB  R0, CurrentDriveNumber  ; [ no - so dismount current drive ]
        BEQ     %FT04                   ;

;******************
; If a ':' was the first char of the parameter THEN ignore it
;******************

        Push    "R0"

        LDRB    R1, [ R0 ]
        TEQ     R1, #":"
        ADDEQ   R0, R0, #1

;******************
; Validate the parameter for valid characters
;******************

        BL      CheckDiscName           ; R0 -> string
        
        Pull    "R0"

;******************
; Copy parameter into 'TempArea' prefixed with ':' if necessary
;******************

        ; Make sure that the name or number is prefixed with ":"
        MOV     R1, #":"
        ADR     R2, TempArea
        MOV     R3, R2

        STRB    R1, [ R2 ], #1
                
        LDRB    R1, [ R0 ], #1
        TEQ     R1, #":"
        STRNEB  R1, [ R2 ], #1
03
        LDRB    R1, [ R0 ], #1
        STRB    R1, [ R2 ], #1
        TEQ     R1, #0
        BNE     %BT03

;******************
; Prompt for disc to be inserted ( as it isn't buffered )
;******************

        ADD     R0, R3, #1
        BL      FindDiscNameInList
        CMP     R1, #-1
        SUBEQ   R0,R0,#1
        BLEQ    FindDriveNumber         ; R0 -> name or number, RETURNS R1 = drive

;******************
; Now I know the drive number !
;******************

        MOV     R0, R1

04
        BL      PreConvertDriveNumberToDeviceID
        
        SUBVC   sp, sp, #8
        MOVVC   r0, #LBAFormat
        MOVVC   r1, sp
        SWIVC   XCD_DiscUsed
        BVS     ErrorExit
        
        Pull    "r1,r2"
        
        MOV     r14, r1, LSL #16
        MOV     r1, r1, LSR #16         ; r1 = mshw of block count
        MOV     r0, r14, LSR #16        ; r0 = lshw of block count
        
        MUL     r14, r1, r2
        MUL     r3, r2, r0
        MOV     r4, r14, LSR #16
        ADDS    r3, r3, r14, LSL #16    ; r3 = lsw of usage
        ADCS    r4, r4, #0              ; r4 = msw of usage
        BNE     %FT64                   ; big disc?

        ; 32-bit size case
        MOV     r0, r3
        ADR     r1, TempArea
        MOV     r2, #9
        SWI     XOS_ConvertHex8         ; build bytecount as hex

        MOVS    r0, r3, LSR #20
        ADC     r0, r0, #0
        ADR     r1, TempArea+32
        MOV     r2, #11
        SWI     XOS_ConvertInteger4     ; build round-to-nearest megabytes as integer

        B       %FT70

64
        ; 64-bit size case
        MOV     r0, r4
        ADR     r1, TempArea
        MOV     r2, #17
        SWI     XOS_ConvertHex8
        MOV     r0, r3
        SWI     XOS_ConvertHex8         ; build bytecount as hex
        
        MOVS    r0, r3, LSR #20
        ADC     r0, r0, r4, LSL #12
        ADR     r1, TempArea+32
        MOV     r2, #11
        SWI     XOS_ConvertInteger4     ; build round-to-nearest megabytes as integer

70
        ADR     r0, message_block
        ADRL    r1, free_tag
        ADR     r2, TempArea+64
        MOV     r3, #128
        ADR     r4, TempArea
        ADR     r5, TempArea+32
        SWI     XMessageTrans_Lookup
        MOVVC   r0, r2
        SWIVC   XOS_Write0
        SWIVC   XOS_NewLine

        B       common_end

;*************************************************************************
;*************************************************************************

        LTORG

        END

