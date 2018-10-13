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
; > Macros

; Useful macros for building linked lists of memory blocks.

linkmacro       SETD    false
unlinkmacro     SETD    false


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Link two blocks together within the directory structures ensuring that all
; links are validated.
;
; Corrupts temp and flags
;

                MACRO
$label          Link    $parent, $linkname, $pointer, $temp

$label          LDR     $temp, $parent

                Debuga  linkmacro, "link: linking record at", $pointer
                Debug   linkmacro, ", before", $temp

                STR     $pointer, $parent                       ; make first link of block to head of list

                TEQ     $temp, #0
                STRNE   $pointer, [$temp, #$linkname._Previous] ; and setup a previous link if possible

                Debug   linkmacro, "link: back pointer set to", $temp

                STR     $temp, [$pointer, #$linkname._Next]     ; link new block to next block correctly
                MOV     $temp, #0
                STR     $temp, [$pointer, #$linkname._Previous] ; and reset new blocks previous pointer

                MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Unlink blocks from the internal link list structure.
;
; next, previous and flags corrupt.
;
                MACRO
$label          Unlink  $parent, $linkname, $pointer, $next, $previous

$label
                ASSERT  $linkname._Previous = $linkname._Next + 4
                ADD     $next, $pointer, #$linkname._Next
                LDMIA   $next, {$next, $previous}               ; get links

                Debug   unlinkmacro, "unlink: unlinking record at", $pointer
                Debuga  unlinkmacro, "unlink: next pointer is", $next
                Debug   unlinkmacro, ", back pointer is", $previous

                TEQ     $previous, #0                           ; was my previous pointer back home?
                STREQ   $next, $parent                          ; yes, so store in global
                STRNE   $next, [$previous, #$linkname._Next]    ; otherwise make a new previous pointer

                TEQ     $next, #0                               ; did I have a following block?
                STRNE   $previous, [$next, #$linkname._Previous]

                MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Frees blocks previously claimed from RMA.
;
; r0, r2 corrupt.
;
; r0 may point at an error block if V set.
;
                MACRO
                Free    $pointer
                MOV     r0, #ModHandReason_Free
              [ "$pointer"<>"r2"
                !       0, "free: free having to move record pointer from $pointer to r2"
                MOV     r2, $pointer                            ; ensure -> block is in r2
              ]
                SWI     XOS_Module                              ; and free the block

                MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++




; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Calls buffer manager service routine
;
                MACRO
$label          CallBuffMan     $cc

$label          Push    "r12"                                   ; save our workspace ptr
                ADR$cc   r12, BuffManWkSpace                    ; place of buffman wkspace and entry
                MOV$cc   lr, pc                                 ; return address
                ASSERT  BuffManService = BuffManWkSpace+4
                LDM$cc.IA r12, {r12, pc}                        ; load buffman wkspace and entry
                Pull    "r12"                                   ; restore our workspace ptr

                MEND

; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

                END
