;
; CDDL HEADER START
;
; The contents of this file are subject to the terms of the
; Common Development and Distribution License (the "Licence").
; You may not use this file except in compliance with the Licence.
;
; You can obtain a copy of the licence at
; cddl/RiscOS/Sources/FileSys/SDFS/SDFS/LICENCE.
; See the Licence for the specific language governing permissions
; and limitations under the Licence.
;
; When distributing Covered Code, include this CDDL HEADER in each
; file and include the Licence file. If applicable, add the
; following below this CDDL HEADER, with the fields enclosed by
; brackets "[]" replaced with your own identifying information:
; Portions Copyright [yyyy] [name of copyright owner]
;
; CDDL HEADER END
;
; Copyright 2012 Ben Avison.  All rights reserved.
; Use is subject to license terms.
;

        GBLS    FSName
FSName  SETS    "SDFS"

        GBLS    fcerror
fcerror SETS    "FSErr"

        MACRO
$num    FSErr   $name, $str
        =       "        AddError $FSName.$name, ""$str"", &"
        =       :STR: (&10000 + fsnumber_$FSName:SHL:8 + &$num), 10
        MEND


        GET     ListOpts
        GET     FSNumbers

        AREA    Text, DATA

        ; File header
        =       "; This is an autogenerated file, do not edit", 10, 10

        ; Define all the errors that FileCore generates for the FS
        GET     FileCoreErr

        ; Define additional FS errors
80      FSErr   BadFileCore, FileCore too old
81      FSErr   BadSWI, SWI value out of range for module SDFS
82      FSErr   BadReason, Unknown %0 reason code
83      FSErr   NotMem, Not a memory card
84      FSErr   CardLocked, Card is locked
BB      FSErr   Password, Incorrect password

        ; File footer
        =       10, "        END", 10

        ; Pad to word alignment with newline characters
        ALIGN   4, 0, 10


        END
