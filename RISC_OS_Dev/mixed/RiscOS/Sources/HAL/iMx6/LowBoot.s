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

; BootLoader stuff for iMx6 HAL
;
; This is the very start of the image, and MUST be on the sd card at
;  offset 0x400 from card start. (3rd sector)
; this leaves space in first sector for standard dos partition table
; and leaves second sector free.
;


; macro to generate a DCD for a word in the other endiness
        MACRO
$label  SSDCD   $value
$label  DCD     (((($value)&255)<<24)\
                        +((($value>>8)&255)<<16)\
                 +((($value>>16)&255)<<8)\
                 +((($value>>24)&255)))
        MEND

        MACRO
$label  CMDDCD  $cmd,$len,$flags
$label  DCD     (((($flags)&255)<<24)\
                 +((($len>>0)&255)<<16)\
                 +((($len>>8)&255)<<8)\
                 +((($cmd)&255)))
        MEND
; Max ram size expected on CS0  (2GB .. 3.75 GB is max that could be addressed
; in 256MB chunks.. => 1/2 GB = 2,1GB = 4 , 1.5GB = 6, 3GB = 12 , 4GB = 16
MaxInstalledCS0RAM  * 15 ;( just under 4GB)
; Highest  ram to check (diagnostics in s.RAM) (in 1/4 GB increments from base
; normally 8 for 2GB Wandboard..!!
MaxCheckRAM         * 8
MaxCheckRAMBoundary  * ((MaxCheckRAM<<28) + &10000000)
;
; compute value needed, start of ram is at 0x10000000 anyway
RamCeiling       * ((((MaxInstalledCS0RAM+1) << 8)-1 ) >>5)
; This is all loaded to ram  at offset 0x400.. after boot sectors of fat disk
Image_Base
; Abs Address of first exec instruction
;  BEWARE .. ram check later on will corrupt the contents of ram at 0x10000000, 0x18000000,
;  and then every 0x08000000 , so DO NOT load to any of these addresses
AbsExec              *  0x17800000 + iMx6LoadLowSize
;
; Abs Address of IVT
AbsIVTAddr           *  AbsExec - iMx6LoadLowSize
;
; Abs Addr of DCD table in memory
AbsDCDAddr           *  AbsIVTAddr + iMx6DCD - iMx6IVT
;
; Abs Address of boot data
AbsBootDataAddr      *  AbsIVTAddr + iMx6BootDat - iMx6IVT
;
; Image start address in RAM .. loc 0 of SD card
AbsImAddr            *  AbsIVTAddr - IVTMediaAddress  ; because IVT at 0x400 in SDcard
;
;  ROM size + sd card offset of ivt
AbsImCpyCount        *  (OSROM_ImageSize*1024) + IVTMediaAddress  + iMx6LoadLowSize;

; IVT header section
iMx6IVT
        CMDDCD  0xD1,0x20,0x40          ; IVT section, its 0x20 bytes
                                        ; long version 0x40
        DCD     AbsExec                 ; abs address initial rom image entry
        DCD     0                       ; =0
        DCD     AbsDCDAddr              ; absolute address of hardware init tab
        DCD     AbsBootDataAddr         ; absolute address to load this
        DCD     AbsIVTAddr              ; absolute image address of all this
        DCD     0
        DCD     0
; end of IVT header section, 8 words (0x20)long

; Boot Data section
iMx6BootDat
        DCD     AbsImAddr               ; abs address in ram to start sd copy
        DCD     AbsImCpyCount           ; Total bytes to copy from SD card
        DCD     0
; end of Boot Data section

; Device Configuration Data section
iMx6DCD
; main header
        CMDDCD  0xd2,iMx6DCDLen,0x40; DCD Header tag. table length, &41 version
; write data header
iMx6RegWrTab
        CMDDCD  0xcc,iMx6RegWrTabLen,0x04 ; &CC write, table length, &04 byte values (with address/data pairs)
        ; set up the DDR pads
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS0;0x020E05A8        ; DRAM SDQS0P iomux pad
        SSDCD   0x30              ;
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS1;0x020E05B0        ; DRAM SDQS1P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS2;0x020E0524        ; DRAM SDQS2P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS3;0x020E051C        ; DRAM SDQS3P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS4;0x020E0518        ; DRAM SDQS4P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS5;0x020E050C        ; DRAM SDQS5P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS6;0x020E05B8        ; DRAM SDQS6P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDQS7;0x020E05C0        ; DRAM SDQS7P iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B0DS;0x020E0784        ; GRP B0DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B1DS;0x020E0788        ; GRP B1DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B2DS;0x020E0794        ; GRP B2DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B3DS;0x020E079C        ; GRP B3DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B4DS;0x020E07A0        ; GRP B4DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B5DS;0x020E07A4        ; GRP B5DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B6DS;0x020E07A8        ; GRP B6DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_B7DS;0x020E0748        ; GRP B7DS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_ADDDS;0x020E074C        ; DRAM GRP_ADDDS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_CTLDS;0x020E078C        ; DRAM GRP_CTLDS iomux pad
        SSDCD   0x30
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM0;0x020E05AC        ; DRAM DQM0 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM1;0x020E05B4        ; DRAM DQM1 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM2;0x020E0528        ; DRAM DQM2 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM3;0x020E0520        ; DRAM DQM3 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM4;0x020E0514        ; DRAM DQM4 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM5;0x020E0510        ; DRAM DQM5 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM6;0x020E05BC        ; DRAM DQM6 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_DQM7;0x020E05C4        ; DRAM DQM7 iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_CAS;0x020E056C        ; DRAM CAS B iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_RAS;0x020E0578        ; DRAM RAS B iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDCLK_0;0x020E0588        ; DRAM SDCLK0P iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDCLK_1;0x020E0594        ; DRAM SDCLK1P iomux pad
        SSDCD   0x020030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_RESET;0x020E057C        ; DRAM RESET iomux pad
        SSDCD   0x0E0030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDCKE0;0x020E0590        ; DRAM SDCKE0 iomux pad
        SSDCD   0x3000
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDCKE1;0x020E0598        ; DRAM SDCKE1 iomux pad
        SSDCD   0x3000
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDODT0;0x020E059C        ; DRAM ODT0 iomux pad
        SSDCD   0x3030
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDODT1;0x020E05A0        ; DRAM ODT1 iomux pad
        SSDCD   0x3030
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_DDRMODE_CTL;0x020E0750        ; DRAM DDRMODE_CTL iomux pad
        SSDCD   0x020000
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_DDRMODE;0x020E0774        ; DRAM DDRMODE iomux pad
        SSDCD   0x020000
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_DDRPKE;0x020E0758        ; DRAM DDRPKE iomux pad
        SSDCD   0x0
        SSDCD   IOMUXC_SW_PAD_CTL_PAD_DRAM_SDBA2;0x020E058C        ; DRAM SDBA2 iomux pad
        SSDCD   0x0
        SSDCD   IOMUXC_SW_PAD_CTL_GRP_DDR_TYPE;0x020E0798        ; DRAM DDRTYPE iomux pad
        SSDCD   0xC0000
;
        SSDCD   0x021B081C        ; MMDC Phy ReadDQ byte 0 delay
        SSDCD   0x33333333
        SSDCD   0x021B0820        ; MMDC Phy ReadDQ byte 1 delay
        SSDCD   0x33333333
        SSDCD   0x021B0824        ; MMDC Phy ReadDQ byte 2 delay
        SSDCD   0x33333333
        SSDCD   0x021B0828        ; MMDC Phy ReadDQ byte 3 delay
        SSDCD   0x33333333
        SSDCD   0x021B481C        ; MMDC2 Phy ReadDQ byte 0 delay
        SSDCD   0x33333333
        SSDCD   0x021B4820        ; MMDC2 Phy ReadDQ byte 1 delay
        SSDCD   0x33333333
        SSDCD   0x021B4824        ; MMDC2 Phy ReadDQ byte 2 delay
        SSDCD   0x33333333
        SSDCD   0x021B4828        ; MMDC2 Phy ReadDQ byte 3 delay
        SSDCD   0x33333333
        SSDCD   0x021B0018        ; MMDC core misc
        SSDCD   0x81740
        SSDCD   0x021B001C        ; MMDC core special command
        SSDCD   0x8000
        SSDCD   0x021B0004        ; MMDC core powerdown
        SSDCD   0x020036
        SSDCD   0x021B000C        ; MMDC core timing 0
        SSDCD   0x898E7974
        SSDCD   0x021B0010        ; MMDC core timing 1
        SSDCD   0xDB538F64
        SSDCD   0x021B0014        ; MMDC core timing 2
        SSDCD   0x1FF00DB
        SSDCD   0x021B002C        ; MMDCcore w/r cmd delay
        SSDCD   0x026D2
        SSDCD   0x021B0030        ; MMDC core out of reset delays
        SSDCD   0x8E1023
        SSDCD   0x021B0008        ; MMDC Core ODT timing control
        SSDCD   0x9444040
        SSDCD   0x021B0004        ; MMDC core powerdown
        SSDCD   0x025576
        SSDCD   0x021B0040        ; MMDC core address space partition
        SSDCD   (RamCeiling)      ; top 7 bits of highest installed RAM address
        ;0x47              ; CS0 ends 0x8effffff
        SSDCD   0x021B0000        ; MMDC Core control reg
        SSDCD   0x841A0000
        SSDCD   0x021B001C        ; MMDC core special command
        SSDCD   0x4088032
        SSDCD   0x021B001C        ; MMDC core special command
        SSDCD   0x8033
        SSDCD   0x021B001C        ; MMDC core special command
        SSDCD   0x428031
        SSDCD   0x021B001C       ; MMDC core special command
        SSDCD   0x19308030
        SSDCD   0x021B001C       ; MMDC core special command
        SSDCD   0x4008040
        SSDCD   0x021B0800       ; MMDC phy za hw ctrl
        SSDCD   0xA1390003
        SSDCD   0x021B4800       ; MMDC2 phy za hw ctrl
        SSDCD   0xA1390003
        SSDCD   0x021B0020       ; MMDC core refresh control
        SSDCD   0x7800
        SSDCD   0x021B0818       ; MMDC Phy ODC ctrl
        SSDCD   0x022227
        SSDCD   0x021B4818       ; MMDC2 Phy ODC ctrl
        SSDCD   0x022227
        SSDCD   0x021B083C       ; MMDC phy rd dqs gating control0
        SSDCD   0x43040319
        SSDCD   0x021B0840       ; MMDC phy rd dqs gating control1
        SSDCD   0x3040279
        SSDCD   0x021B483C       ; MMDC2 phy rd dqs gating control0
        SSDCD   0x43040321
        SSDCD   0x021B4840       ; MMDC2 phy rd dqs gating control1
        SSDCD   0x3030251
        SSDCD   0x021B0848       ; MMDC phy rd delay lines config
        SSDCD   0x4D434248
        SSDCD   0x021B4848       ; MMDC2 phy rd delay lines config
        SSDCD   0x42413C4D
        SSDCD   0x021B0850       ; MMDC phy wr delay lines config
        SSDCD   0x34424543
        SSDCD   0x021B4850       ; MMDC2 phy wr delay lines config
        SSDCD   0x49324933
        SSDCD   0x021B080C       ; MMDC phy write levelling delay control0
        SSDCD   0x1A0017
        SSDCD   0x021B0810       ; MMDC phy write levelling delay control1
        SSDCD   0x1F001F
        SSDCD   0x021B480C       ; MMDC2 phy write levelling delay control0
        SSDCD   0x170027
        SSDCD   0x021B4810       ; MMDC2 phy write levelling delay control1
        SSDCD   0xA001F
        SSDCD   0x021B08B8       ; MMDC Phy measure unit reg
        SSDCD   0x800
        SSDCD   0x021B48B8       ; MMDC2 Phy measure unit reg
        SSDCD   0x800
        SSDCD   0x021B001C       ; MMDC core special command
        SSDCD   0x0
        SSDCD   0x021B0404       ; MMDC core power saving and control
        SSDCD   0x11006
;
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR0_OFFSET);0x020C4068       ; CCM clk gating reg control 0
        SSDCD   0xC03F3F
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR1_OFFSET);0x020C406C       ; CCM clk gating reg control 1
        SSDCD   0x30FC03
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR2_OFFSET);0x020C4070       ; CCM clk gating reg control 2
        SSDCD   0xFFFC000
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR3_OFFSET);0x020C4074       ; CCM clk gating reg control 3
        SSDCD   0x3FF00000
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR4_OFFSET);0x020C4078       ; CCM clk gating reg control 4
        SSDCD   0xFFF300
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR5_OFFSET);0x020C407C       ; CCM clk gating reg control 5
        SSDCD   0xF0000C3
        SSDCD   (CCM_BASE_ADDR+CCM_CCGR6_OFFSET);0x020C4080       ; CCM clk gating reg control 6
        SSDCD   0x3FF
;
; SSDCD 0x200c000
; SSDCD 0x77777777
; SSDCD 0x200c004
; SSDCD 0x77777777
; SSDCD 0x200c040
; SSDCD 0x77777777
; SSDCD 0x200c044
; SSDCD 0x77777777
; SSDCD 0x200c048
; SSDCD 0x77777777
; SSDCD 0x200c04c
; SSDCD 0x77777777
; SSDCD 0x200c050
; SSDCD 0x77777777
; SSDCD 0x210c000
; SSDCD 0x77777777
; SSDCD 0x210c004
; SSDCD 0x77777777
; SSDCD 0x210c040
; SSDCD 0x77777777
; SSDCD 0x210c044
; SSDCD 0x77777777
; SSDCD 0x210c048
; SSDCD 0x77777777
; SSDCD 0x210c04c
; SSDCD 0x77777777
; SSDCD 0x210c050
; SSDCD 0x77777777
        SSDCD   IOMUXC_GPR4       ; GPR IOMUXC4
        SSDCD   0xF00000CF
        SSDCD   IOMUXC_GPR6       ; GPR IOMUXC6
        SSDCD   0x7F007F
        SSDCD   IOMUXC_GPR7       ; GPR IOMUXC7
        SSDCD   0x7F007F
;
;       SSDCD   (CCM_BASE_ADDR + CCM_CCOSR_OFFSET) ; CCM clk op source reg
;       SSDCD   0xFB
;
;        SSDCD   (UART1_BASE_ADDR+UART_UCR2_OFFSET)
;        SSDCD  1
;        SSDCD   (UART1_BASE_ADDR+UART_UCR2_OFFSET)
;        SSDCD  0x4066
;        SSDCD   (UART1_BASE_ADDR+UART_UCR1_OFFSET)
;        SSDCD  1
;        SSDCD   (UART1_BASE_ADDR+UART_UCR3_OFFSET)
;        SSDCD  0x4
;        SSDCD   (UART1_BASE_ADDR+UART_UFCR_OFFSET)
;        SSDCD  0xa81
;        SSDCD   (UART1_BASE_ADDR+UART_UBIR_OFFSET)
;        SSDCD  0x4
;        SSDCD   (UART1_BASE_ADDR+UART_UBMR_OFFSET)
;        SSDCD  0xd8
;; tx byte
;        SSDCD   (UART1_BASE_ADDR+UART_UTXD_OFFSET)
;        SSDCD  0x55

;
; uart1
;        SSDCD   0x020e0280      ; padmux csio_d10
;        SSDCD  0x3              ; alt 3
;        SSDCD   0x020e0284      ; padmux csio_d11
;        SSDCD  0x3              ; alt 3
;        SSDCD   0x020e0920      ; ip sel
;        SSDCD  0x1              ; default
iMx6RegWrTabLen    * .-iMx6RegWrTab

; set data bits section
iMx6gipotabset
;        CMDDCD  0xcc,iMx6gipotabsetLen,0x1c ; &CC wr, tablelen, &1c 4byte values
;                                            ; (with address/mask pairs) set bits
;        SSDCD   (CCM_BASE_ADDR + CCM_CCGR5_OFFSET)
;        SSDCD   0x0f000000                   ; uart clocks on
iMx6gipotabsetLen    * .-iMx6gipotabset

; clear data bits section
iMx6gipotabclr
;        CMDDCD  0xcc,iMx6gipotabclrLen,0x0c ; &CC write, table length, &0c 4byte values
;                                            ; (with address/mask pairs) clear bits
;        SSDCD   (CCM_BASE_ADDR + CCM_CSCDR1_OFFSET)
;        SSDCD   0x0000003f                   ; uart_podf = 0 (div 1)
iMx6gipotabclrLen    * .-iMx6gipotabclr

;  boot table completed
iMx6DCDLen * .-iMx6DCD


; max size of DC array is 1768 bytes
        ASSERT  . - iMx6DCD < 1768

        ALIGN    16
; force this bit to be expected length   .. see components file
        ASSERT  (.- Image_Base) < IVTLoaderSize
        %       IVTLoaderSize - (.- Image_Base)

; Size of this chunk
iMx6LoadLowSize * .-Image_Base


        END
