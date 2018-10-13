/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "Licence").
 * You may not use this file except in compliance with the Licence.
 *
 * You can obtain a copy of the licence at
 * cddl/RiscOS/Sources/FileSys/SDFS/SDFS/LICENCE.
 * See the Licence for the specific language governing permissions
 * and limitations under the Licence.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the Licence file. If applicable, add the
 * following below this CDDL HEADER, with the fields enclosed by
 * brackets "[]" replaced with your own identifying information:
 * Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright 2012 Ben Avison.  All rights reserved.
 * Use is subject to license terms.
 */

/** \file discop.c
 * Implementation of low-level disc operation handlers.
 */

#include <string.h>
#include "swis.h"

#include "Global/NewErrors.h"

#include "Interface/FileCore.h"
#include "Interface/FileCoreErr.h"
#include "Interface/SDFSErr.h"
#include "Interface/SDIO.h"

#include "cardreg.h"
#include "discop.h"
#include "globals.h"
#include "message.h"
#include "sdio.h"

#include "gpiodebug.h"

/** Timeout to set on SDIO commands (cs) */
#define OP_TIMEOUT (1000)

/** Timeout waiting for card to reach tran state (cs) */
#define TRAN_TIMEOUT (10)

/** FileCore scatter list threshold */
#define SCATTER_THRESHOLD (0xFFFF0000u)

/** Move to the next scatter entry in an array; cope with FileCore-style looped lists */
#define ADVANCE_SCATTER_POINTER(p)                                         \
  do                                                                       \
  {                                                                        \
    (p)++;                                                                 \
    if ((p)->length == 0 && (uintptr_t) (p)->address >= SCATTER_THRESHOLD) \
      (p) = (scatter_t *) ((uintptr_t) (p) + (uintptr_t) (p)->address);    \
  }                                                                        \
  while (0)

/** Round a 32-bit number down to a power-of-2 */
#define ROUND_DOWN_32(number, bits) ((number) & (-1u << (bits)))

/** Round a 64-bit number down to a power-of-2 */
#define ROUND_DOWN_64(number, bits) ((number) & (-1ull << (bits)))

/** Round a 64-bit number up to a power-of-2 */
#define ROUND_UP_64(number, bits) ROUND_DOWN_64(((number) + (1ull << (bits)) - 1), (bits))

/** Table mapping from offsets into SDIODriver's error block to vaguely ST506/IDE-compatible disc error numbers */
static const uint8_t disc_error_lut[][2] = {
    { ErrorNumber_SDIO_DevE31   & 0xFF, 0x0B }, /* Device error - Address out of range    -> INC */
    { ErrorNumber_SDIO_DevE30   & 0xFF, 0x0D }, /* Device error - Address misalign        -> SKE */
    { ErrorNumber_SDIO_DevE29   & 0xFF, 0x0E }, /* Device error - Block length error      -> OVR */
    { ErrorNumber_SDIO_DevE26   & 0xFF, 0x19 }, /* Device error - Write protect violation -> NWR */
    { ErrorNumber_SDIO_DevE23   & 0xFF, 0x03 }, /* Device error - Command CRC error       -> PER */
    { ErrorNumber_SDIO_DevE22   & 0xFF, 0x02 }, /* Device error - Illegal command         -> IVC */
    { ErrorNumber_SDIO_DevE21   & 0xFF, 0x13 }, /* Device error - Device ECC failed       -> DFE */
    { ErrorNumber_SDIO_CTO      & 0xFF, 0x08 }, /* Controller error - Response timeout    -> NRY */
    { ErrorNumber_SDIO_DTO      & 0xFF, 0x23 }, /* Controller error - Data timeout        -> IDE controller timeout */
    /* Other errors allocated numbers outside range used by ST506 or IDE */
    { ErrorNumber_SDIO_Conflict & 0xFF, 0x30 }, /* Controller error - CMD line conflict */
    { ErrorNumber_SDIO_CCRC     & 0xFF, 0x31 }, /* Controller error - Response CRC error */
    { ErrorNumber_SDIO_CEB      & 0xFF, 0x32 }, /* Controller error - Response end bit error */
    { ErrorNumber_SDIO_CIE      & 0xFF, 0x33 }, /* Controller error - Response index error */
    { ErrorNumber_SDIO_DCRC     & 0xFF, 0x34 }, /* Controller error - Data CRC error */
    { ErrorNumber_SDIO_DEB      & 0xFF, 0x35 }, /* Controller error - Data end bit error */
    { ErrorNumber_SDIO_ACE      & 0xFF, 0x36 }  /* Controller error - Auto CMD error */
};

static low_level_error_t transfer_with_retries(uint32_t reason,
                                               uint32_t flags,
                                               drive_t * restrict dr,
                                               uint64_t * restrict disc_address,
                                               block_or_scatter_t * restrict ptr,
                                               size_t * restrict transfer_length)
{
  low_level_error_t e;
  bool single_block = *transfer_length == SECTOR_SIZE;
  int32_t retries = reason == DiscOp_Verify ? VERIFY_RETRIES : RETRIES;
  do
  {
    size_t transferred, not_transferred;
    e.oserror = NULL;
    if (dr->needs_reselect)
    {
      /* First deselect all cards; someone else may have been talking to another one in the
       * same slot, and some cards don't like seeing a select without a preceding deselect */
      COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD7_SELECT_DESELECT_CARD, 0, R0, deselect_card_blk, e.oserror);
      if (e.oserror)
        dprintf("Deselect card returned %s\n", e.oserror->errmess);
      if (e.oserror && e.oserror->errnum == ErrorNumber_Escape)
      {
        e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
        break; /* No retries for this one */
      }
      
      if (!e.oserror)
      {
        /* Now select the card. This gives us an opportunity to detect if the card is locked */
        COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD7_SELECT_DESELECT_CARD, dr->rca << 16, R1, select_card_blk, e.oserror);
        if (e.oserror)
          dprintf("Select card returned %s\n", e.oserror->errmess);
        if (e.oserror && e.oserror->errnum == ErrorNumber_Escape)
        {
          e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
          break; /* No retries for this one */
        }
        if (!e.oserror && select_card_blk.response & R1_CARD_IS_LOCKED)
        {
          dprintf("Select card detected locked card\n");
          e.oserror = MESSAGE_ERRORLOOKUP(true, CardLocked, 0);
          break; /* No retries for this one */
        }
      }
    }
    
    if (dr->needs_wait)
    {
      /* The card must be in tran state before we can continue. If it is not, it is probably
       * because it is still writing data to flash from a previous transfer. This can take a
       * considerable time - I've seen cards that need 3 ms or more - so use a long timeout. */
      int32_t tran_timeout;
      _swix(OS_ReadMonotonicTime, _OUT(0), &tran_timeout);
      tran_timeout += TRAN_TIMEOUT + 1;
      while (!e.oserror)
      {
        COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD13_SEND_STATUS, dr->rca << 16, R1, send_status_blk, e.oserror);
        if (!e.oserror && (send_status_blk.response & R1_CURRENT_STATE_MASK) == R1_CURRENT_STATE_TRAN)
          break;
        int32_t now;
        _swix(OS_ReadMonotonicTime, _OUT(0), &now);
        if (now - tran_timeout >= 0)
          break; /* not good - the card or controler will probably raise an error shortly */
      }
      if (e.oserror && e.oserror->errnum == ErrorNumber_Escape)
      {
        e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
        break; /* No retries for this one */
      }

      if (!e.oserror)
        dr->needs_wait = false;
    }
    
    if (dr->needs_reselect)
    {
      if (!e.oserror)
      {
        /* On-the-wire block length is fixed as 512 bytes by SDHCI for memory access commands.
         * Chances are that some cards out there have only been tested with SDHCI controllers,
         * so it's best to stick to that size whatever controller we're using. */
        COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD16_SET_BLOCKLEN, SECTOR_SIZE, R1, set_blocklen_blk, e.oserror);
        if (e.oserror)
          dprintf("Set blocklen returned %s\n", e.oserror->errmess);
        if (e.oserror && e.oserror->errnum == ErrorNumber_Escape)
        {
          e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
          break; /* No retries for this one */
        }
      }
      
      if (!e.oserror)
        dr->needs_reselect = false;
    }
    
    if (!e.oserror)
    {
      /* Set up the command: it may be single or multi-sector, read or write */
      sdioop_cmdres_R1_t crblock;
      if (single_block)
      {
        crblock.command = reason == DiscOp_WriteSecs ? CMD24_WRITE_BLOCK : CMD17_READ_SINGLE_BLOCK;
      }
      else
      {
        crblock.command = reason == DiscOp_WriteSecs ? CMD25_WRITE_MULTIPLE_BLOCK : CMD18_READ_MULTIPLE_BLOCK;
        if (dr->cmd23_supported)
        {
          /* Card supports CMD23 - use it to improve speed */
          COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD23_SET_BLOCK_COUNT, *transfer_length >> LOG2_SECTOR_SIZE, R1, set_block_count_blk, e.oserror);
          if (e.oserror)
          {
            dprintf("CMD23 error: %s\n", e.oserror->errmess);
            if (e.oserror->errnum == ErrorNumber_Escape)
            {
              e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
              break; /* No retries for this one */
            }
            /* Drop back to CMD12 instead */
            crblock.command |= SDIOOp_CmdFlg_AutoCMD12;
          }
        }
        else
          crblock.command |= SDIOOp_CmdFlg_AutoCMD12;
      }
      crblock.command |= LOG2_SECTOR_SIZE << SDIOOp_CmdFlg_BlockSplitShift;
      crblock.argument = (uint32_t) (dr->sector_addressed ? *disc_address >> LOG2_SECTOR_SIZE : *disc_address);
      dprintf("SDIOOp: flags %08X, resplen %u, command %X, arg %X, ptr %p, len %u, timeout %u -> ",
                                  (dr->slot << SDIOOp_SlotShift) | (dr->bus << SDIOOp_BusShift) | SDIOOp_R1 |
                                  (reason == DiscOp_WriteSecs ? SDIOOp_TransWrite : SDIOOp_TransRead) | flags,
                                  8 + SDIOOp_ResLen_R1,
                                  crblock.command,
                                  crblock.argument,
                                  ptr->block,
                                  *transfer_length,
                                  OP_TIMEOUT);
      e.oserror = sdio_op_fg_data((dr->slot << SDIOOp_SlotShift) | (dr->bus << SDIOOp_BusShift) | SDIOOp_R1 |
                                  (reason == DiscOp_WriteSecs ? SDIOOp_TransWrite : SDIOOp_TransRead) | flags,
                                  8 + SDIOOp_ResLen_R1,
                                  &crblock,
                                  ptr->block, /* either member would do, they're both pointers */
                                  *transfer_length,
                                  OP_TIMEOUT,
                                  &not_transferred);
      dprintf("%s; not_transferred = %u\n", e.oserror ? e.oserror->errmess : "OK", not_transferred);
      /* Advance buffer pointer or scatter list (as appropriate) according to
       * however many bytes we successfully transferred */
      transferred = *transfer_length - not_transferred;
      *disc_address += transferred;
      if (flags & SDIOOp_Scatter)
        while (transferred > 0)
        {
          size_t this_time = MIN(ptr->scatter->length, transferred);
          ptr->scatter->address += this_time;
          if ((ptr->scatter->length -= this_time) == 0)
            ADVANCE_SCATTER_POINTER(ptr->scatter);
          transferred -= this_time;
        }
      else
        ptr->block += transferred;
      *transfer_length = not_transferred;
      
      if (reason == DiscOp_WriteSecs)
        /* Must wait for data to be written to flash before starting any more transfers */
        dr->needs_wait = true;

      if (e.oserror)
      {
        /* SDIODriver's error buffer may be about to be overwritten, ensure we have a safe copy */
        if (e.oserror->errnum == ErrorNumber_Escape)
          e.oserror = MESSAGE_ERRORLOOKUP(true, ExtEscape, 0);
        else
          e.oserror = message_copy(e.oserror);
        if (!single_block)
        {
          /* Send a manual abort command so we can get the card's attention back */
          _kernel_oserror *abort_error;
          int32_t abort_retries = reason == DiscOp_Verify ? VERIFY_RETRIES : RETRIES;
          do
          {
            COMMAND_NO_DATA(dr->bus, dr->slot, SDIOOp_DisableEscape, CMD12_STOP_TRANSMISSION, 0, R1b, stop_transmission_blk, abort_error);
            /* No special case for Escape here - there's already a pending error, and we need to ensure the abort goes through */
          }
          while (abort_error && --abort_retries >= 0);
          dprintf("Abort command result %s\n", abort_error ? abort_error->errmess : "OK");
        }
        
        /* Some cards seem to need to be deselected and reselected after errors */
        if (e.oserror->errnum != ErrorNumber_SDFSExtEscape)
          dr->needs_reselect = true;
        
        if (transferred)
          ++retries; /* At least some data transferred, so it's not fair to decrement the retry count when we loop */
        if (e.oserror->errnum == ErrorNumber_SDFSExtEscape)
          break; /* No retries for this one */
      }
    }
  }
  while (e.oserror != NULL && --retries >= 0);
  return e;
}

static low_level_error_t buffered_transfer(uint32_t reason,
                                           uint32_t flags,
                                           drive_t *dr,
                                           uint64_t buffer_disc_address,
                                           size_t buffer_length,
                                           uint64_t * restrict disc_address,
                                           block_or_scatter_t * restrict ptr,
                                           size_t * restrict total_length)
{
  uint8_t *buffer = dr->block_buffer;
  size_t remaining = buffer_length;
  low_level_error_t e;
  e.number = 0;
  if (reason == DiscOp_WriteSecs)
  {
    /* First read the existing contents of the card */
    e = transfer_with_retries(DiscOp_ReadSecs,
                              flags &~ SDIOOp_Scatter,
                              dr,
                              &buffer_disc_address,
                              (block_or_scatter_t *) &buffer,
                              &remaining);
    /* Reset the pointers for the write operation. Assume success (values aren't used on failure) */
    buffer_disc_address -= buffer_length;
    buffer = dr->block_buffer;
    remaining = buffer_length;
  }
  if (e.number == 0)
  {
    uint8_t *interesting = buffer + (*disc_address - buffer_disc_address);
    size_t interesting_length = buffer + buffer_length - interesting;
    interesting_length = MIN(interesting_length, *total_length);
    if (reason == DiscOp_WriteSecs)
    {
      /* Partially overwrite the buffer with the new data (leave the scatter list entries untouched at this point) */
      block_or_scatter_t from = *ptr;
      uint8_t *to = interesting;
      int32_t count = interesting_length;
      if (flags & SDIOOp_Scatter)
        while (count > 0)
        {
          size_t this_time = MIN(from.scatter->length, count);
          memcpy(to, from.scatter->address, this_time);
          ADVANCE_SCATTER_POINTER(from.scatter); /* doesn't matter if we advance on last iteration */
          to += this_time;
          count -= this_time;
        }
      else
        memcpy(to, from.block, count);
    }
    /* Do the main transfer */
    e = transfer_with_retries(reason,
                              flags &~ SDIOOp_Scatter,
                              dr,
                              &buffer_disc_address,
                              (block_or_scatter_t *) &buffer,
                              &remaining);
    /* Irrespective of whether there was an error or not, update the scatter list etc
     * according to how many bytes were successfully read/written. Note that we have
     * to be able to cope with an error before or after the "interesting" region. */
    int32_t count = buffer - interesting;
    count = MAX(count, 0);
    count = MIN(count, interesting_length);
    *disc_address += count;
    *total_length -= count;
    if (flags & SDIOOp_Scatter)
      while (count > 0)
      {
        size_t this_time = MIN(ptr->scatter->length, count);
        if (reason == DiscOp_ReadSecs)
        {
          memcpy(ptr->scatter->address, interesting, count);
          interesting += count;
        }
        ptr->scatter->address += this_time;
        if ((ptr->scatter->length -= this_time) == 0)
          ADVANCE_SCATTER_POINTER(ptr->scatter);
        count -= this_time;
      }
    else
    {
      if (reason == DiscOp_ReadSecs)
        memcpy(ptr->block, interesting, count);
      ptr->block += count;
    }
  }
  return e;
}

low_level_error_t discop(uint32_t reason,
                         uint32_t flags,
                         uint32_t drive,
                         uint64_t * restrict disc_address,
                         block_or_scatter_t * restrict ptr,
                         size_t * restrict fg_length)
{
  low_level_error_t e;
  e.number = 0;
  spinrw_read_lock(&g_drive_lock);
  drive_t *dr = g_drive + drive;
  uint64_t address_limit;

  if (drive >= NUM_FLOPPIES + NUM_WINNIES)
  {
    dprintf("Bad drive number: %u\n", drive);
    e.number = BadDriveErr;
    goto exit;
  }

  if (dr->slot_attached && dr->no_card_detect && dr->certainty == 0)
  {
    _kernel_oserror *err = _swix(SDIO_Control, _INR(0,1), SDIOControl_TryLock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
    if (err)
    {
      if (err->errnum != ErrorNumber_SDIO_SlotInUse)
      {
        e.oserror = err;
        dprintf("Slot lock returned %s\n", e.oserror->errmess);
        goto exit;
      }
      /* otherwise the slot is currently in use, so obviously not in a timeout state */
    }
    else
    {
      dr->slot_claimed = true;
      dprintf("Need to probe for card presence\n");
      bool rescan_needed = !dr->card_inserted;
      if (dr->card_inserted)
      {
        COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD7_SELECT_DESELECT_CARD, 0, R0, deselect_card_blk, err);
        if (err)
        {
          e.oserror = err->errnum == ErrorNumber_Escape ? MESSAGE_ERRORLOOKUP(true, ExtEscape, 0) : err;
          dprintf("Deselect prior to probe returned %s\n", e.oserror->errmess);
          _swix(SDIO_Control, _INR(0,1), SDIOControl_Unlock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
          goto exit;
        }
        COMMAND_NO_DATA(dr->bus, dr->slot, flags & SDIOOp_DisableEscape, CMD7_SELECT_DESELECT_CARD, dr->rca << 16, R1, select_card_blk, err);
        if (err)
        {
          if (err->errnum != ErrorNumber_SDIO_CTO)
          {
            e.oserror = err->errnum == ErrorNumber_Escape ? MESSAGE_ERRORLOOKUP(true, ExtEscape, 0) : err;
            dprintf("Probe for RCA %04X returned %s\n", dr->rca, e.oserror->errmess);
            _swix(SDIO_Control, _INR(0,1), SDIOControl_Unlock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
            goto exit;
          }
          else
          {
            dprintf("Probe for RCA %04X met with no response\n", dr->rca);
            rescan_needed = true;
          }
        }
        else
          dprintf("Probe for RCA %04X successful\n", dr->rca);
      }
      _swix(SDIO_Control, _INR(0,1), SDIOControl_Unlock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
      if (rescan_needed)
      {
        /* Because we know we've already managed to acquire the lock, we know
         * it's actually OK to do this, even though it's nominally non-reentrant */
        dprintf("Rescan slot\n");
        spinrw_read_unlock(&g_drive_lock); // we're going to want to claim a write lock on g_drive when we're re-entered
        e.oserror = _swix(SDIO_Initialise, _INR(0,1), SDIOInitialise_RescanSlot, (dr->bus << SDIORescanSlot_BusShift) | (dr->slot << SDIORescanSlot_SlotShift));
        spinrw_read_lock(&g_drive_lock);
        if (e.oserror)
          dprintf("Rescan slot returned %s\n", e.oserror->errmess);
      }
    }
  }

  if (!dr->slot_attached || !dr->card_inserted)
  {
    dprintf("Slot %sattached, card %sinserted\n", dr->slot_attached ? "" : "not ", dr->card_inserted ? "" : "not ");
    e.number = DriveEmptyErr;
    goto exit;
  }

  if (!dr->memory_card)
  {
    dprintf("Not a memory card\n");
    e.oserror = MESSAGE_ERRORLOOKUP(true, NotMem, 0);
    goto exit;
  }

  if (reason == DiscOp_WriteSecs && dr->write_protected)
  {
    dprintf("Write protected\n");
    e.number = WriteProtErr;
    goto exit;
  }

  address_limit = 1ull << 32;
  if (dr->sector_addressed)
    address_limit <<= LOG2_SECTOR_SIZE;
  if (*disc_address + *fg_length > address_limit || !IS_SECTOR_ALIGNED(*disc_address))
  {
    dprintf("Disc address range :%u/%016llX-%016llX, limit %016llX, %ssector aligned\n",
        drive, *disc_address, *disc_address + *fg_length, address_limit, IS_SECTOR_ALIGNED(*disc_address) ? "is " : "not ");
    e.number = BadParmsErr;
    goto exit;
  }

#ifndef ENABLE_BACKGROUND_TRANSFERS
  if (flags & SDIOOp_Background)
  {
    dprintf("Background transfer not supported\n");
    e.number = BadParmsErr;
    goto exit;
  }
#endif

//  if ((flags & SDIOOp_Scatter) == 0)
//  {
//    uint32_t flags;
//    _swix(OS_ValidateAddress, _INR(0,1)|_OUT(_FLAGS), ptr->block, ptr->block + *fg_length, &flags);
//    dprintf("Validate flags 0x%X\n", flags);
//    if (flags & _C)
//      while (1);
//    if (flags & _N) // should be C but I want to trap with JTAG
//    {
//      dprintf("No memory at address\n");
//      e.oserror = (_kernel_oserror *) "\0\0\0\0No memory at address";
//      goto exit;
//    }
//  }

  if (*fg_length == 0)
  {
    dprintf("Foreground length 0\n");
    goto exit;
  }

  e.oserror = _swix(SDIO_Control, _INR(0,1), SDIOControl_Lock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
  if (e.oserror)
  {
    dprintf("Slot lock returned %s\n", e.oserror->errmess);
    goto exit;
  }
  dr->slot_claimed = true;

  /* Now we need to subdivide the operation into chunks that are acceptable to
   * the SD command set - and some further restrictions imposed by SDHCI as well.
   * Some cards may be a bit more forgiving, but SDHC cards are amongst the most
   * fussy and they're only going to become more common, so rather than write a
   * separate code path for older cards that won't be tested properly, we assume
   * the worst case. Constraints are:
   * - must start and end on read/write block boundaries (may require read-modify-write)
   * - must not exceed 65535*512-byte blocks (SDHCI limitation)
   * - must not exceed 4MB (for some controllers when operating in UHS mode)
   * - some MMC cards have 4K sectors, and all operations must be done in multiples
   *     of 8*512-byte blocks (we can make this fall out of the block boundary restriction)
   * - SDIODriver has no verify operation, so we fake it by reading to our buffer
   */
  { /* remove warnings about jump past initialisation of variables */
    uint32_t align_size = reason == DiscOp_WriteSecs ? dr->write_block_size : dr->read_block_size;
    uint64_t start_down = ROUND_DOWN_64(*disc_address, align_size);
    uint64_t end_down = ROUND_DOWN_64(*disc_address + *fg_length, align_size);
    uint64_t end_up = ROUND_UP_64(*disc_address + *fg_length, align_size);
    uint32_t chunk_size = ROUND_DOWN_32(0xFFFF << LOG2_SECTOR_SIZE, align_size);
    if (dr->single_blocks)
      chunk_size = 1 << LOG2_SECTOR_SIZE;
    dprintf("align=%u, %016llX/%016llX/%016llX, chunk=%08X\n", align_size, start_down, end_down, end_up, chunk_size);
    block_or_scatter_t ptr_for_verify_ops;
    if (reason == DiscOp_Verify)
    {
      ptr = &ptr_for_verify_ops; /* so we don't corrupt R3 on exit */
      flags &= ~SDIOOp_Scatter; /* silly if it's set, but PRM allows it */
      chunk_size = 1u << align_size;
    }

    if (*disc_address != start_down)
    {
      if (reason == DiscOp_Verify)
        ptr->block = dr->block_buffer;
      e = buffered_transfer(reason, flags, dr, start_down, 1u << align_size, disc_address, ptr, fg_length);
    }
    while (e.number == 0 && *disc_address < end_down)
    {
      size_t transfer_length = (size_t) MIN(chunk_size, end_down - *disc_address);
      size_t remain = transfer_length;
      if (reason == DiscOp_Verify)
        ptr->block = dr->block_buffer;
      e = transfer_with_retries(reason, flags, dr, disc_address, ptr, &remain);
      *fg_length -= transfer_length - remain;
    }
    if (e.number == 0 && *disc_address < end_up && *fg_length != 0)
    {
      if (reason == DiscOp_Verify)
        ptr->block = dr->block_buffer;
      e = buffered_transfer(reason, flags, dr, end_down, 1u << align_size, disc_address, ptr, fg_length);
    }
  }
  
  if (e.oserror != 0)
  {
    /* Convert into a disc error if possible */
    if ((e.oserror->errnum &~ 0xFF) == ErrorBase_SDIO)
      for (size_t i = 0; i < sizeof disc_error_lut / sizeof *disc_error_lut; ++i)
        if ((e.oserror->errnum & 0xFF) == disc_error_lut[i][0])
        {
          dr->disc_error.drive = dr - g_drive;
          dr->disc_error.disc_error = disc_error_lut[i][1];
          dr->disc_error.unused_MBZ = 0;
          dr->disc_error.byte = *disc_address;
          e.new_disc_error = &dr->disc_error;
          e.flag.new_disc_error = true;
          break;
        }

    /* See if the real reason for the error is that the card was removed.
     * Note that this doesn't work for 8-bit cards on the beagleboard -
     * the connection with DAT4-7 is lost before the CD switch releases! */
    _swix(SDIO_Control, _INR(0,1), SDIOControl_PollCardDetect, (dr->slot << SDIOControl_SlotShift) | (dr->bus << SDIOControl_BusShift));
    if (!dr->card_inserted)
      e.number = DriveEmptyErr;
  }
  _swix(SDIO_Control, _INR(0,1), SDIOControl_Unlock, (dr->bus << SDIOControl_BusShift) | (dr->slot << SDIOControl_SlotShift));
exit:
  spinrw_read_unlock(&g_drive_lock);
  return e;
}
