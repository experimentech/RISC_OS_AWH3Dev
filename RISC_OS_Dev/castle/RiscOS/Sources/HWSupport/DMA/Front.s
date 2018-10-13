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
; > Sources.Front

;-----------------------------------------------------------------------------
;       Structures and declarations.
;

 [ :LNOT: HAL
; Numbers of channels
NoLogicalChannels       * 7
NoPhysicalChannels      * 6
 ]

; Logical channel block.
                        ^ 0
 [ HAL
lcb_Next                # 4                     ; Link to next block.
lcb_ChannelNo           # 4                     ; Logical channel number.
 ]
lcb_Flags               # 4                     ; Logical channel flags (see below).
lcb_Vector              # 4                     ; Pointer to 5 routine addresses.
lcb_R12                 # 4                     ; Value to pass in r12.
lcb_Queue               # 4                     ; Pointer to physical channel DMA queue.
 [ HAL
lcb_PeripheralRead      # 4                     ; Read address of peripheral device.
lcb_PeripheralWrite     # 4                     ; Write address of peripheral device.
 |
lcb_Physical            # 4                     ; Physical channel number.
 ]

LCBSize                 * :INDEX:@

; Logical channel flags.
lcbf_TransferSize       * &0000001F             ; Mask off DMA transfer size.
lcbf_DMASpeed           * &00000060             ; Mask off DMA cycle speed.
 [ HAL
lcbf_PostDelay          * &00000F00             ; Post-transfer channel delay.
lcbf_NoBursts           * &00001000             ; Disable burst transfers.
lcbf_NoClockSync        * &00002000             ; Disable DMA request synchronisation to clock.
 ]
lcbf_Blocked            * &40000000             ; Logical channel blocked.
 [ :LNOT: HAL
lcbf_Registered         * &80000000             ; Logical channel has been registered.
 ]

; Vector offsets.
                        ^ 0
vector_Enable           # 4                     ; Called to enable device DMA.
vector_Disable          # 4                     ; Called to disable device DMA.
vector_Start            # 4                     ; Called before a DMA is started.
vector_Completed        # 4                     ; Called when a DMA is completed.
vector_DMASync          # 4                     ; Called after every N bytes transferred.

; Page table entry.
                        ^ 0
ptab_Len                # 4                     ; Length of transfer in this page.
ptab_Logical            # 4                     ; Logical address to start transfer.
ptab_Physical           # 4                     ; Corresponding physical address.

PTABSize                * :INDEX:@

; Physical channel DMA queue.
                        ^ 0
dmaq_Head               # 4                     ; Pointer to DMA queue head.
dmaq_Tail               # 4                     ; Pointer to DMA queue tail.
dmaq_Active             # 4                     ; Pointer to DMA active on physical channel.
dmaq_LastBuff           # 4                     ; Pointer to last buffer programmed.
 [ HAL ; extends structure to hold all our info pertaining to a physical channel
dmaq_DMADevice          # 4                     ; Pointer to HAL device for this physical channel.
dmaq_DeviceFeatures     # 4                     ; Flags word / block pointer returned from Features call.
dmaq_Usage              # 4                     ; Number of logical channels using this physical channel.
dmaq_BounceBuff         # PTABSize              ; Fake page table entry pointing at bounce buffer.
dmaq_DescBlockLogical   # 4                     ; Transfer descriptors block (list devices): logical address.
dmaq_DescBlockPhysical  # 4                     ;     "         "        "     "      "      physical address.
dmaq_DescBlockCount     # 4                     ;     "         "        "     "    "  number of entries used.
                        # (((:INDEX:@)+3):AND::NOT:15)+12-(:INDEX:@)
dmaq_Trampoline         # 52                    ; Qword-aligned device vector trampoline for physical channel.
                        # (((:INDEX:@)+15):AND::NOT:15)-(:INDEX:@)
 ]

DMAQSize                * :INDEX:@

 [ HAL
; DMA controller structure.
                        ^ 0
ctrlr_Next              # 4                     ; Link to next block.
ctrlr_Device            # 4                     ; HAL device for this controller.
ctrlr_PhysicalChannels  # 4                     ; Number of physical channels and therefore queues.
ctrlr_DMAQueues         # DMAQSize * 0          ; Array of DMA queue information.

CtrlrSize               * :INDEX: @
 ]

; Data held for a programmed buffer.
                        ^ 0
buff_Ptp                # 4                     ; Pointer to page table entry.
buff_Off                # 4                     ; Offset into scatter list entry.
buff_Len                # 4                     ; Length of transfer.

BuffDataSz              * :INDEX:@

; DMA request block.
                        ^ 0
 [ HAL
dmar_Magic              # 4                     ; Magic word check, since tag = request block pointer now.
dmar_MagicWord          * &72616D64             ; = "dmar"
dmar_TagBits01          # 4                     ; Should match bits 0 and 1 of tag.
dmar_Queue              # 4                     ; The DMA queue to which we belong.
 |
dmar_Tag                # 4                     ; DMA tag.
dmar_PhysBits           * &00000007             ; Bottom 3 bits of tag hold physical channel number.
 ]
dmar_Prev               # 4                     ; Pointer to previous DMA request in queue.
dmar_Next               # 4                     ; Pointer to next DMA request in queue.
dmar_Flags              # 4                     ; DMA request flags (see below).
dmar_R11                # 4                     ; Value to be passed in r11.
dmar_ScatterList        # 4                     ; Scatter list pointer.
dmar_Length             # 4                     ; Length of transfer left (in bytes). Excludes data programmed
                                                ; into buffer(s), reduced under interrupt for list devices.
dmar_BuffSize           # 4                     ; Size of circular buffer (if used).
dmar_SyncGap            # 4                     ; Number of bytes between DMASync calls (if used).
dmar_Done               # 4                     ; Amount of transfer done (as reflected in scatter list).
dmar_LCB                # 4                     ; Pointer to logical channel block.
dmar_PageTable          # 4                     ; Pointer to page table.
dmar_PageCount          # 4                     ; Number of entries in page table.
 [ HAL
dmar_CurrBuff           # BuffDataSz            ; Data programmed into current buffer.
dmar_NextBuff           # BuffDataSz            ; Data programmed into next buffer.
 |
dmar_BuffA              # BuffDataSz            ; Data programmed into buff A.
dmar_BuffB              # BuffDataSz            ; Data programmed into buff B.
 ]
dmar_BuffLen            # 4                     ; Amount of circular buffer left (if used).
dmar_ProgGap            # 4                     ; Amount of gap left to program (if used).
dmar_PhysSyncGap        * dmar_ProgGap          ; Reuse for low-level sync gap to use for list-type devices.
dmar_Gap                # 4                     ; Amount of gap completed (if used).
 [ HAL
dmar_DoneAtStart        # 4                     ; Amount of transfer done at last call to SetListTransfer.
 ]

DMARSize                * :INDEX:@

; DMA request flags.
dmarf_Direction         * &00000001             ; Direction bit (0=read, 1=write).
dmarf_Circular          * &00000002             ; Scatter list is a circular buffer.
dmarf_Sync              * &00000004             ; Call DMASync callback.
dmarf_DontUpdate        * &00000008             ; Don't update scatter list even if non-circular.
dmarf_Infinite          * &00000010             ; Transfer is infinite length (must be circular).
dmarf_Uncacheable       * &04000000             ; Pages for transfer have been marked as uncacheable.
dmarf_Halted            * &08000000             ; Transfer has been halted due to Service_PagesUnsafe.
dmarf_Blocking          * &10000000             ; DMA request blocking logical queue.
dmarf_BeenActive        * &20000000             ; DMA request has been active before.
dmarf_Suspended         * &40000000             ; DMA request suspended.
dmarf_Completed         * &80000000             ; DMA request has completed.

; Free block.
                        ^ 0
free_Next               # 4                     ; Pointer to next free block.
free_Size               # 4                     ; Size of this free block.

; DMA request block buffer.
                        ^ 0
block_Next              # 4                     ; Pointer to next DMA request buffer block.
 [ HAL
block_Data              # 6 * DMARSize          ; Number of DMA request blocks that we allocate together
 |                                              ; is somewhat arbitrary.
block_Data              # NoPhysicalChannels * DMARSize
 ]

BlockSize               * :INDEX:@

 [ HAL
BOUNCEBUFFSIZE          * 1:SHL:16
 |
IOMD_IOxCURA            * IOMD_IO0CURA-IOMD_IO0CURA
IOMD_IOxENDA            * IOMD_IO0ENDA-IOMD_IO0CURA
IOMD_IOxCURB            * IOMD_IO0CURB-IOMD_IO0CURA
IOMD_IOxENDB            * IOMD_IO0ENDB-IOMD_IO0CURA
IOMD_IOxCR              * IOMD_IO0CR-IOMD_IO0CURA
IOMD_IOxST              * IOMD_IO0ST-IOMD_IO0CURA
 ]

PAGESHIFT       * 12
PAGESIZE        * 1:SHL:PAGESHIFT

ptabf_Unsafe            * &80000000             ; Combined with ptab_Len to mark a page as unsafe.

Memory_LogicalGiven     * 1:SHL:9               ; OS_Memory flags.
Memory_PhysicalGiven    * 1:SHL:10
Memory_PhysicalWanted   * 1:SHL:13
Memory_SetUncacheable   * 2:SHL:14
Memory_SetCacheable     * 3:SHL:14

;-----------------------------------------------------------------------------
;       Workspace layout.
;
workspace       RN      R12
                ^       0,workspace
wsorigin                # 0
 [ international
message_file_open       # 4                             ; Non-0 => message file open.
message_file_block      # 4*4                           ; Message file id block.
 ]
 [ HAL
NextLogicalChannel      # 4                             ; Next logical channel to assign.
ChannelList             # 4                             ; Pointer to list of logical channel blocks.
CtrlrList               # 4                             ; Pointer to list of DMA controllers.
 |
ChannelBlock            # NoLogicalChannels * LCBSize   ; Logical channel blocks.
DMAQueues               # NoPhysicalChannels * DMAQSize ; DMA queue information.
 ]
FreeBlock               # 4                             ; Pointer to linked list of free blocks.
DMABlockHead            # 4                             ; Pointer to list of DMA request block buffers.
TagIndex                # 4                             ; Index for generating DMA request tags.
UnsafePageTable         # 4                             ; Pointer to 3-word per entry table of unsafe pages.
UnsafePageCount         # 4                             ; Number of entries in UnsafePageTable.
 [ HAL
Header                  # 4*3                           ; Titles of table headers in *DMAChannels.
Width                   # 1*3                           ; Widths of table columns in *DMAChannels.
PreReset                # 1                             ; Nonzero if Service_PreReset seen
 AlignSpace
Scratch                 # 256                           ; Temporary workspace.
 ]
 [ debugtab
DebugTableCur           # 4
DebugTable              # 1024
DebugTableEnd           # 0
 ]

max_running_work   *       :INDEX:@

        ! 0, "DMA module workspace is ":CC:(:STR:(:INDEX:@)):CC:" bytes"

        END

