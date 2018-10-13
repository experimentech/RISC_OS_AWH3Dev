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

; this is included if the IIC and other means don't provice CMOS access
; it was basically a dump from a working iyonix
;
        AREA    |ARM$$data|, CODE, READONLY, PIC

        EXPORT  SoftCMOS
        LTORG
SoftCMOSStart  * .
SoftCMOS
        DCD     &EB00FE00       ; &EB00FE00 ;&EB00FE00 ;DCD &EB00FE00
        DCD     &00001A00       ; &00001A00 ;&00001A00 ;DCD &00000800
        DCD     &54100000       ; &54100000 ;&54100000 ;DCD &54100000
        DCD     &2C0A0820       ; &2C0A0820 ;&2C0A0820 ;DCD &2C0A0820
        DCD     &00000290       ; &00000290 ;&00000291 ;DCD &00000291
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000703       ; &00000703 ;&00000703 ;DCD &00000703
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&000000E0 ;DCD &000000E0
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00001000       ; &00001000 ;&0000000A ;DCD &0000000A
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&01000000 ;DCD &01000000
        DCD     &01000000       ; &01000000 ;&01000000 ;DCD &01000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00001400       ; &00001400 ;&0000140E ;DCD &0000140D
        DCD     &40407CA4       ; &41407CA4 ;&40407CA4 ;DCD &40407CA4
        DCD     &00C101FF       ; &00C001FF ;&00C101FF ;DCD &00C101FF
        DCD     &00000011       ; &00000011 ;&00000001 ;DCD &00000001
        DCD     &00400800       ; &00400800 ;&00400805 ;DCD &00400805
        DCD     &000000F0       ; &000000F0 ;&000000F0 ;DCD &000000F0
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000B00       ; &00000B00 ;&00010B00 ;DCD &00010B00
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &50027600       ; &54027600 ;&50027600 ;DCD &50027600
        DCD     &00406F00       ; &00406F00 ;&00406F00 ;DCD &00406F00
        DCD     &3C280040       ; &3C280040 ;&3C280040 ;DCD &3C280040
        DCD     &00000010       ; &00000010 ;&00000010 ;DCD &00000010
        DCD     &00000020       ; &00000020 ;&F0000000 ;DCD &F0000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00800010       ; &00800010 ;&00800009 ;DCD &00800009
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &00000000       ; &00000000 ;&00668003 ;DCD &00668003
        DCD     &00000000       ; &00000000 ;&00000000 ;DCD &00000000
        DCD     &01EA0000       ; &05EA0000 ;&96EA0000 ;DCD &83EA0000
        DCD     &FFFFFFFF
        DCD     &FFFFFFFF
        DCD     &FFFFFFFF
        DCD     &FFFFFFFF

SoftCMOSSize    * . - SoftCMOSStart

        END
