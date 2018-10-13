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
; drawfile.s
;
; Rewritten for 32-bit compatibility.
;
; Previous version:
; generated by Norcroft RISC OS ARM C vsn 5.00c (Acorn Computers Ltd) <alpha test> [Aug  3 1994]
;

        AREA |DrawfileVeneers$$code|, CODE, READONLY, PIC

        MACRO
        LDMRet  $regs, $cond
        [ {CONFIG}=26
        LDM$cond.DB   fp,{$regs,sp,pc}^
        |
        LDM$cond.DB   fp,{$regs,sp,pc}
        ]
        MEND

        EXPORT  drawfile_render
drawfile_render
        MOV      ip,sp
        STMDB    sp!,{v1,v2,fp,ip,lr,pc}
        SUB      fp,ip,#4
        LDMIA    ip,{v1,v2}
        SWI      &65540
        MOVVC    a1,#0
        LDMRet   "v1,v2,fp"


        EXPORT  drawfile_bbox
drawfile_bbox
        MOV      ip,sp
        STMDB    sp!,{v1,fp,ip,lr,pc}
        SUB      fp,ip,#4
        LDR      v1,[fp,#4]
        SWI      &65541
        MOVVC    a1,#0
        LDMRet   "v1,fp"


        EXPORT  drawfile_declare_fonts
drawfile_declare_fonts
        MOV      ip,sp
        STMDB    sp!,{fp,ip,lr,pc}
        SUB      fp,ip,#4
        SWI      &65542
        MOVVC    a1,#0
        LDMRet   "fp"


        END
