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
; -> Variables ( see $.CDFS.Test )

;----------------------------------------------------------------------------------------------
; Variables claimed in RMA
;----------------------------------------------------------------------------------------------

                        ^ 0, r12        ; link variables to workspace register

Start                   # 0                     
                                        
message_block           # 5 * 4         ; Used for MessageTrans (v2.17 onwards & RISC OS 3)
                                        
stackreturn             # 4                     
temp1                   # 4                     
temp2                   # 4                     
temp3                   # 4                     
verytemporary           # 4
swi_verytemporary       # 4            ; used by swi's to pass errors around stack pops

tempLength              # 4            ; these 4 used by 'Dir'
tempBlockSize           # 4            
tempInk                 # 4            
tempBlock               # 4            

maxnumberofdrives       # 4            ; max number of drives available
maxnumberofbuffers      # 4            ; max number of pointers available

lastdiscnumber          # 4            ; See 'Search' ; 15
lastblocknumber         # 4            ;
lastobjectnumber        # 4            ;
                            
discbufferpointer       # 4            ; Place to get K from     } keep together
disclastpointer         # 4            ; -> bottom of last entry }
discbuffersize          # 4            ; Number of K to be used  }

discnumberofdirinbuffer # 4
tempbufferpointer       # 4            ; used by 'Dir'
pointerToBufferList     # 4            ; points at list of discs buffered
maindirpointer          # 4            ; See 'Directory' ( temp pointer )
bufferedblockdiscnumber # 4            ; GBPB is faster with this
bufferedblocknumber     # 4            ;

olddrivenumber          # 1            ; 1
CurrentDriveNumber      # 1            ; 2
tempdrivenumber         # 1            ; 3
tempDisctype            # 1            ; 4
numberofdrives          # 1            ; 1
numberofbuffersused     # 1            ; 2
truncation              # 1            ; 3 truncate names left/right/not
max_truncation          # 1            ; 4 max truncation for this ROS version

sparecontrolblock       # 20
TempArea                # 256
tempbuffer              # 256

OpenFileList            # MAXNUMBEROFOPENFILES * 4
sparedirectorybuffer    # SIZEOFBUFFER + :INDEX:DiscBuff_MainDirBuffer
ListOfDrivesAttached    # ((MAXNUMBEROFDRIVESSUPPORTED+4):OR:3):EOR:3
ListOfDiscsInDrives     # ( MAXNUMBEROFDRIVESSUPPORTED * 4 )
discsMounted            # ( MAXNUMBEROFDRIVESSUPPORTED * 4 )
DiscNameList            # ( MAXLENGTHOFDISCNAME * MAXNUMBEROFDRIVESSUPPORTED )
buffer                  # SIZEOFBUFFER

DriveTypes              # MAXNUMBEROFDRIVESSUPPORTED

 [ log
log_memory              # 4*1024*10
log_pointer             # 4
 ]

 ! 0, "CDFS workspace is ":CC:(:STR:(:INDEX:@)):CC:" bytes"

SIZEOFRMA               * @ - Start

        END
