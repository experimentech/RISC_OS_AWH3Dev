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
; > Sources.Browser

        AREA    |AlarmBrowser$$Code|, CODE, READONLY, PIC

        GET     Hdr:ListOpts
        GET     Hdr:Macros
        GET     Hdr:System
        GET     Hdr:FSNumbers
        GET     Hdr:NewErrors
        GET     Hdr:Wimp
        GET     Hdr:MsgTrans
        GET     Hdr:Territory

; *****************************************************************************
;
; Workspace
;

                  ^ 0
alarm_next        # 4                   ; ptr to next alarm in this linked list           
alarm_prev        # 4                   ; ptr to previous alarm in list                   
alarm_fileptr     # 4                   ; ptr to alarm in data file                       
alarm_year        # 4                   ; *local* year for alarm to go off on             
alarm_month       # 4                   ; *local* month for alarm to go off on            
alarm_date        # 4                   ; *local* date for alarm to go off on             
alarm_hours       # 4                   ; *local* hours for alarm to go off on            
alarm_minutes     # 4                   ; *local* minutes for alarm to go off on          
valid_year        # 4                   ; original *local* year for alarm to go off on    
valid_month       # 4                   ; original *local* month for alarm to go off on   
valid_date        # 4                   ; original *local* date for alarm to go off on    
valid_hours       # 4                   ; original *local* hours for alarm to go off on   
valid_minutes     # 4                   ; original *local* minutes for alarm to go off on
alarm_line1       # 41                  ; line 1 of the alarm text                           
alarm_line2       # 41                  ; line 2 of the alarm text                           
alarm_line3       # 41                  ; line 3 of the alarm text                           
alarm_repeating   # 1                   ; is this a repeating alarm?                         
alarm_repeat_rate # 1                   ; repeat rate for this alarm                         
alarm_repeat_mult # 1                   ; repeat multiplier for this alarm                   
alarm_urgent      # 1                   ; is this an urgent alarm?                           
alarm_applalarm   # 1                   ; is this an application alarm?                      
alarm_taskalarm   # 1                   ; is this a task alarm?                              
alarm_fvdywk      # 1                   ; does this alarm fit into a working week?           
alarm_selected    # 1                   ; has this alarm been selected on the viewer?        
alarm_SIZE        # 1                   ;
                                  
; *****************************************************************************
;
; Code to redraw the alarm browser
;
; On entry, R0 = more%
;           R1 = buff%
;           R2 = alarm_head%
;           R3 = msg_desc%
;

table
        B       start
        DCD     0                       ; right hand limit of day icon
        DCD     0                       ; right hand limit of date icon
        DCD     0                       ; right hand limit of time icon
        DCD     0                       ; right hand end of message icon
start
        Push    "LR"
        STR     R1, buff
        STR     R2, alarm_head
        STR     R3, msg_desc
entry
        TEQ     R0, #0
        Pull    "PC", EQ
        LDR     R2, buff
        LDR     R3, [R2, #4]
        LDR     R4, [R2, #20]
        SUB     R3, R3, R4              ; x% = buff%!4 - buff%!20
        LDR     R4, [R2, #16]           
        LDR     R5, [R2, #24]           
        SUB     R4, R4, R5              
        SUB     R4, R4, #52             ; y% = buff%!16 - buff%!24 - 52
        LDR     R5, [R2, #40]           
        SUB     R5, R4, R5              
        DivRem  R6, R5, #48, R7, norem  ; y1% = (y% - buff%!40) DIV 48
        LDR     R5, [R2, #32]           
        SUB     R5, R4, R5              
        DivRem  R7, R5, #48, R0, norem  ; y2% = (y% - buff%!32) DIV 48
        LDR     R2, alarm_head          
        ; register usage so far
        ; R2 - alarm_head% ie p%
        ; R3 - x%
        ; R4 - y%
        ; R6 - y1%
        ; R7 - y2%
        ; R5 and R0 corrupt
        CMP     R6, #0                  
        MOVLT   R6, #0                  ; if y1%<0 y1%=0
        CMP     R7, R6                  ; if y2%>=y1% then
        BLT     get_rectangle           
        MVN     R4, #51                 ; y% = -52
        TEQ     R6, #0                  ; if y1%<>0 (ie if we've got lines to skip)
        BEQ     do_loop                 
        MOV     R5, #0                  ; for i%=0 TO y1%-1
skip_lines
        SUB     R4, R4, #48             ; y%-=48
        TEQ     R2, #0                  ; if p%<>0
        LDRNE   R2, [R2, #alarm_next]   ; then p%=!(p%+alarm_next%)
        MOVEQ   R5, R6                  ; else if p%=0, get out of the loop
        ADD     R5, R5, #1              
        CMP     R5, R6                  
        BLT     skip_lines              ; next
do_loop
        MOV     R5, R6                  ; for i%=y1% TO y2%
        ADD     R7, R7, #1              ; (makes the next test easier)
do_loop_loop
        TEQ     R2, #0                  ; if p%<>0
        BLNE    create_entry            ; PROCcreate_entry(y%,p%)
        TEQ     R2, #0                  ; if p%<>0 (it can change, so we need to test again)
        LDRNE   R2, [R2, #alarm_next]   ; then p%=!(p%+alarm_next%)
        ADD     R5, R5, #1              
        CMP     R5, R7                  
        BLT     do_loop_loop            ; next
get_rectangle
        LDR     R1, buff
        SWI     Wimp_GetRectangle
        B       entry

create_entry
        ; plots the alarm pointed to by R2 at the vertical offset in R4
        ;
        ; NB! Because the alarm time can shift [due to repeating in a
        ; working week], the browser always uses the original date and
        ; time.
        Push    "R2,R5-R7,LR"
        Push    "R2"                    ; save it again 'cos it gets used
        MOV     R5, R2
        ADR     R2, u_string
        MOV     R0, #0
        STR     R0, [R2]                ; centi-seconds
        STR     R0, [R2, #4]            ; seconds
        LDR     R0, [R5, #alarm_minutes]
        STR     R0, [R2, #8]
        LDR     R0, [R5, #alarm_hours]
        STR     R0, [R2, #12]
        LDR     R0, [R5, #alarm_date]
        STR     R0, [R2, #16]
        LDR     R0, [R5, #alarm_month]
        STR     R0, [R2, #20]
        LDR     R0, [R5, #alarm_year]
        STR     R0, [R2, #24]
        ADR     R1, fivebt
        MVN     R0, #0
        SWI     Territory_ConvertOrdinalsToTime
        Pull    "R2"
        
        ; do the day of the alarm
        ADR     R1, brwsA2              
        LDR     R5, left_mask           
        MOV     R6, #0                  ; left bounding edge
        LDR     R7, table+4             ; right bounding edge
        BL      do_part_of_the_display
          
        ; do the date of the alarm
        ADR     R1, brwsA3
        LDR     R5, right_mask
        LDR     R6, table+4
        LDR     R7, table+8
        BL      do_part_of_the_display

        ; do the time of the alarm
        ADR     R1, brwsA4
        LDR     R5, right_mask
        LDR     R6, table+8
        LDR     R7, table+12
        BL      do_part_of_the_display

        ; now finally do the string part
        LDRB    R0, [R2, #alarm_applalarm]
        TEQ     R0, #0
        BNE     ce_appl_alarm

        LDRB    R0, [R2, #alarm_taskalarm]
        TEQ     R0, #0
        BEQ     ce_normal_alarm

        ; task alarm
        ADR     R5, u_string            ; need to build up the string
        ADD     R6, R2, #alarm_line1    ; first of all, concatenate
        BL      copy_string             ; the 3 lines into u_string
        ADD     R6, R2, #alarm_line2    
        BL      copy_string             
        ADD     R6, R2, #alarm_line3    
        BL      copy_string             

        Push    "R0-R7"
        ADR     R2, t_string            ; now reform the whole string
        MOV     R0, #32                 
        STRB    R0, [R2], #1            ; start the string with a space
        LDR     R0, msg_desc            
        ADR     R1, brwsA1              
        MOV     R3, #256                
        ADR     R4, u_string            
        MOV     R5, #0                  
        MOV     R6, #0                  
        MOV     R7, #0                  
        SWI     XMessageTrans_Lookup
        MOVVS   R3, #0                  ; if error occured, reset pointer to start
        MOV     R0, #13                 
        STRB    R0, [R2, R3]            
        Pull    "R0-R7"
        B       ce_display_string

ce_appl_alarm
        Push    "R0-R7"
        ADD     R4, R2, #alarm_line1
        ADR     R2, t_string            
        MOV     R0, #32                 
        STRB    R0, [R2], #1            ; start the string with a space
        LDR     R0, msg_desc            
        ADR     R1, brwsA5              
        MOV     R3, #256                
        MOV     R5, #0                  
        MOV     R6, #0                  
        MOV     R7, #0                  
        SWI     XMessageTrans_Lookup
        MOVVS   R3, #0                  ; if error occured, reset pointer to start
        MOV     R0, #13                 
        STRB    R0, [R2, R3]            
        Pull    "R0-R7"
        B       ce_display_string

ce_normal_alarm
        ADR     R5, t_string            
        MOV     R0, #32                 
        STRB    R0, [R5], #1            ; start the string with a space
        ADD     R6, R2, #alarm_line1   
        BL      copy_string             
        ADD     R6, R2, #alarm_line2   
        LDRB    R0, [R6]                ; only copy line 2
        TEQ     R0, #13                 ; if there is something there
        MOVNE   R0, #32                 ; but separate with a space
        STRNEB  R0, [R5], #1            
        BLNE    copy_string             
        ADD     R6, R2, #alarm_line3
        LDRB    R0, [R6]                ; only copy line 3
        TEQ     R0, #13                 ; if there is something there
        MOVNE   R0, #32                 ; but separate with a space
        STRNEB  R0, [R5], #1            
        BLNE    copy_string             

ce_display_string
        LDR     R5, left_mask
        LDR     R6, table+12
        LDR     R7, table+16
        BL      plot_icon

        SUB     R4, R4, #48             ; y%-=48
        Pull    "R2,R5-R7,PC"

do_part_of_the_display
        ; on entry, R1 points to the token name, R5,R6 and R7 are set for plot_icon
        Push    "R0-R7,LR"
        LDR     R0, msg_desc            ; get the format string
        ADR     R2, t_string            ; and put it into t_string+90
        ADD     R2, R2, #90             
        MOV     R3, #81                 
        MOV     R4, #0                  
        MOV     R5, #0                  
        MOV     R6, #0                  
        MOV     R7, #0                  
        SWI     XMessageTrans_Lookup
        MOVVS   R0, #0                  
        STRVS   R0, [R2]                
        ADR     R0, fivebt              ; convert the alarm's date into a string
        ADR     R1, t_string            
        MOV     R2, #81                 
        ADD     R3, R1, #90             ; using the format previously got
        SWI     OS_ConvertDateAndTime   ; should be X
        Pull    "R0-R7,LR"
        ; ****************************** and drop into plot_icon

plot_icon
        ; on entry, R5 holds the mask, R6 holds the left bounding edge
        ; and R7 holds the right bounding edge
        Push    "R0-R7,LR"
        STR     R5, q_buff_mask         
        ADR     R5, t_string            
        MOV     R3, R5                  ; keep a copy of the pointer
pi_length
        LDRB    R0, [R5]                ; need to work out how long
        TEQ     R0, #13                 ; the string is
        TEQNE   R0, #10                 
        TEQNE   R0, #0                  
        ADDNE   R5, R5, #1              
        BNE     pi_length               
        SUB     R5, R5, R3              ; length in R5
        ADD     R5, R5, #1              
                                        
        ADR     R1, q_buff              ; now build the PlotIcon block
        STR     R6, [R1]                ; left hand edge
        SUB     R0, R4, #48             ; y%-48
        STR     R0, [R1, #4]            
        STR     R7, [R1, #8]            ; right hand edge
        STR     R4, [R1, #12]           
        LDR     R4, [R1, #16]           ; deselect the icon by default
        BIC     R4, R4, #(1<<21)        
        LDRB    R0, [R2, #alarm_selected]
        TEQ     R0, #0                  ; then select it if necessary
        ORRNE   R4, R4, #(1<<21)
        LDRB    R0, [R2, #alarm_applalarm]
        TEQ     R0, #0                  ; cannot select application alarms
        BICNE   R4, R4, #(15<<24)       ; so show it in a lighter grey
        ORRNE   R4, R4, #(4<<24)
        STR     R4, [R1, #16]           
        STR     R3, [R1, #20]           ; pointer to the string
        STR     R5, [R1, #28]           ; string length
        SWI     Wimp_PlotIcon
        Pull    "R0-R7,PC"

copy_string
        ; copies the string pointed to by R6
        ; into R5, stopping at CR or NULL or LF
        LDRB    R0, [R6], #1
        TEQ     R0, #13
        TEQNE   R0, #10
        TEQNE   R0, #0
        STRNEB  R0, [R5], #1
        BNE     copy_string
        MOV     R0, #0
        STRB    R0, [R5]
        MOV     PC, LR

buff
        DCD     0
alarm_head
        DCD     0
msg_desc
        DCD     0
fivebt
        DCD     0
        DCD     0

brwsA1
        DCB     "BrwsA1", 0
        ALIGN
brwsA2
        DCB     "BrwsA2", 0
        ALIGN
brwsA3
        DCB     "BrwsA3", 0
        ALIGN
brwsA4
        DCB     "BrwsA4", 0
        ALIGN
brwsA5
        DCB     "BrwsA5", 0
        ALIGN

q_buff
        DCD     0                       ; +0
        DCD     0                       ; +4
        DCD     0                       ; +8
        DCD     0                       ; +12
q_buff_mask                             ;      2 2222 2222 1111 1111 11
                                        ;      8 7654 3210 9876 5432 1098 7654 3210
        DCD     &77006311               ; +16 %1 0111 0000 0000 0110 0011 0001 0001
        DCD     0                       ; +20
        DCD     -1                      ; +24
        DCD     0                       ; +28

left_mask
        DCD     &77006111
right_mask
        DCD     &77006311

t_string
        SPACE   256
u_string
        SPACE   256

        END
