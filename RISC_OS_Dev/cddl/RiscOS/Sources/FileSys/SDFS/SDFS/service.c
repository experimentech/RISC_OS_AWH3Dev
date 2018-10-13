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

/** \file service.c
 * Implementation of service call handlers.
 */

#include <stdlib.h>
#include <stdio.h>
#include "swis.h"

#include "Global/RISCOS.h"
#include "Global/Upcall.h"
#include "Interface/SDIO.h"

#include "SyncLib/barrier.h"
#include "SyncLib/spinrw.h"

#include "cardreg.h"
#include "globals.h"
#include "service.h"

static void upcall(uint32_t reason, uint8_t drive)
{
  char drive_spec[sizeof FILING_SYSTEM_TITLE "::255"];
  sprintf(drive_spec, FILING_SYSTEM_TITLE "::%u", drive);
  _swix(OS_UpCall, _INR(0,1), reason, drive_spec);
}

void service_SDIOSlotAttached(uint32_t bus, uint32_t slot, bool integrated, bool no_card_detect, bool integrated_mem)
{
  /* Don't provide a drive for non-removable IO slots */
  if (integrated)
    return;

  uint32_t min_drive = integrated_mem ? 4 : 0;
  uint32_t max_drive = min_drive + (integrated_mem ? NUM_WINNIES : NUM_FLOPPIES) - 1;

  /* We need at least one drive to represent this new slot */
  spinrw_write_lock(&g_drive_lock);
  uint32_t i;
  for (i = min_drive; i <= max_drive; i++)
    if (!g_drive[i].slot_attached)
      break;
  if (i <= max_drive)
  {
    g_drive[i].no_card_detect = no_card_detect;
    g_drive[i].card_inserted = false;
    g_drive[i].bus = bus;
    g_drive[i].slot = slot;
    barrier(); /* because we may read these from the background */
    g_drive[i].slot_attached = true;
    upcall(UpCall_DriveAdded, i);
    dprintf("Allocate drive %u for bus %u / slot %u\n", i, bus, slot);
  }
  spinrw_write_unlock(&g_drive_lock);
}

void service_SDIOSlotDetached(uint32_t bus, uint32_t slot, bool integrated, bool no_card_detect, bool integrated_mem)
{
  IGNORE(no_card_detect);
  IGNORE(integrated_mem);

  /* Nothing to do for non-removable IO slots */
  if (integrated)
    return;

  /* Remove all drives associated with this slot */
  spinrw_write_lock(&g_drive_lock);
  uint32_t i;
  for (i = 0; i < NUM_FLOPPIES + NUM_WINNIES; i++)
  {
    if (g_drive[i].slot_attached && g_drive[i].bus == bus && g_drive[i].slot == slot)
    {
      upcall(UpCall_DriveRemoved, i);
      g_drive[i].slot_attached = false;
      dprintf("Deallocate drive %u\n", i);
    }
  }
  spinrw_write_unlock(&g_drive_lock);
}

void service_SDIOUnitAttached(uint32_t bus, uint32_t slot, uint32_t rca, uint32_t unit, uint32_t fic, bool writeprotect, bool mmc, uint64_t capacity, bool called_from_init)
{
  IGNORE(fic);

  /* Don't provide a drive for non-removable IO slots */
  uint32_t slot_handle = 0;
  uint32_t slot_spec;
  while (!_swix(SDIO_Enumerate, _INR(0,1)|_OUTR(1,2),
      SDIOEnumerate_Slots, slot_handle,
      &slot_handle, &slot_spec) && slot_handle != 0)
  {
    if (((slot_spec & SDIOEnumerate_BusMask) >> SDIOEnumerate_BusShift) == bus &&
        ((slot_spec & SDIOEnumerate_SlotMask) >> SDIOEnumerate_SlotShift) == slot)
    {
      if (slot_spec & SDIOEnumerate_Integrated)
        return;
      break;
    }
  }

  /* Read card registers first, so if the SWIs fail we can just pretend the card
   * was never inserted */
  uint32_t memory_ocr;
  reg15_t csd;
  uint8_t scr[8];
  _kernel_oserror *e;
  if (unit == 0 && (e = _swix(SDIO_ReadRegister, _INR(0,2),
                                  SDIORegister_MemoryOCR,
                                  (bus << SDIORegister_BusShift) | (slot << SDIORegister_SlotShift) | (rca << SDIORegister_RCAShift),
                                  &memory_ocr)) != NULL)
  {
    dprintf("SDIO_ReadRegister(MemoryOCR %u %u %04X) failed: %s\n", bus, slot, rca, e->errmess);
    return;
  }
  if ((e = _swix(SDIO_ReadRegister, _INR(0,2),
                    SDIORegister_CSD,
                    (bus << SDIORegister_BusShift) | (slot << SDIORegister_SlotShift) | (rca << SDIORegister_RCAShift),
                    csd)) != NULL)
  {
    dprintf("SDIO_ReadRegister(CSD) failed: %s\n", e->errmess);
    return;
  }
  if (unit == 0 && !mmc && (e = _swix(SDIO_ReadRegister, _INR(0,2),
                                          SDIORegister_SCR,
                                          (bus << SDIORegister_BusShift) | (slot << SDIORegister_SlotShift) | (rca << SDIORegister_RCAShift),
                                          scr)) != NULL)
  {
    dprintf("SDIO_ReadRegister(SCR %u %u %04X) failed: %s\n", bus, slot, rca, e->errmess);
    return;
  }

  /* Look for an empty drive associated with this slot.
   * There should be at least one drive associated with this slot, but if it's
   * already occupied by a card with a different RCA, then we're on a shared MMC
   * bus, and need to allocate another drive to the same slot. */
   
  spinrw_write_lock(&g_drive_lock);
  uint32_t i;
  /* First check to see if this is merely an additional unit for a card we already know about. */
  for (i = 0; i < NUM_FLOPPIES + NUM_WINNIES; i++)
    if (g_drive[i].slot_attached && g_drive[i].card_inserted && g_drive[i].bus == bus && g_drive[i].slot == slot && g_drive[i].rca == rca)
      break;
  if (i == NUM_FLOPPIES + NUM_WINNIES)
  {
    /* Look for an empty drive associated with this slot. */
    for (i = 0; i < NUM_FLOPPIES + NUM_WINNIES; i++)
      if (g_drive[i].slot_attached && !g_drive[i].card_inserted && g_drive[i].bus == bus && g_drive[i].slot == slot)
        break;
    if (i == NUM_FLOPPIES + NUM_WINNIES)
    {
      /* There weren't any empty drives for this slot.
       * See if we can allocate another. */
      uint32_t min_drive = 0;
      uint32_t max_drive = NUM_FLOPPIES - 1;
      uint32_t slot_handle = 0;
      uint32_t slot_spec;
      while (!_swix(SDIO_Enumerate, _INR(0,1)|_OUTR(1,2),
          SDIOEnumerate_Slots, slot_handle,
          &slot_handle, &slot_spec) && slot_handle != 0)
      {
        if ((slot_spec & SDIOEnumerate_BusMask) >> SDIOEnumerate_BusShift == bus &&
            (slot_spec & SDIOEnumerate_SlotMask) >> SDIOEnumerate_SlotShift == slot)
        {
          if (slot_spec & SDIOEnumerate_IntegratedMem)
          {
            min_drive = 4;
            max_drive = 4 + NUM_WINNIES - 1;
          }
          break;
        }
      }
      for (i = min_drive; i <= max_drive; i++)
        if (!g_drive[i].slot_attached)
          break;
      if (i <= max_drive)
      {
        /* Multiple drives for this slot */
        g_drive[i].card_inserted = false;
        g_drive[i].bus = bus;
        g_drive[i].slot = slot;
        barrier(); /* because we may read these from the background */
        g_drive[i].slot_attached = true;
        dprintf("Allocate additional drive %u for bus %u / slot %u\n", i, bus, slot);
      }
      else
        i = NUM_FLOPPIES + NUM_WINNIES;
    }
    dprintf("Drive %u timeout reset due to insertion; sequence %u inserted %u\n", i, g_drive[i].sequence_number, g_drive[i].card_inserted);
    if (i < NUM_FLOPPIES + NUM_WINNIES && !g_drive[i].card_inserted)
    {
      g_drive[i].write_protected = writeprotect;
      g_drive[i].memory_card = false;
      g_drive[i].io_card = false;
      g_drive[i].mmc = mmc;
      g_drive[i].rca = rca;
      barrier(); /* because we may read these from the background */
      spin_lock(&g_drive[i].certainty_lock);
      g_drive[i].certainty = called_from_init ? 0 : FAITH;
      spin_unlock(&g_drive[i].certainty_lock);
      spin_lock(&g_drive[i].sequence_lock);
      g_drive[i].card_inserted = true;
      ++g_drive[i].sequence_number;
      spin_unlock(&g_drive[i].sequence_lock);
    }
  }
  /* Set the memory / IO flag even if we already know about this RCA, so we can
   * tell IO cards apart from combo ones, and IO cards apart from empty slots */
  if (i < NUM_FLOPPIES + NUM_WINNIES)
  {
    if (unit == 0)
    {
      dprintf("Memory card inserted in drive %u\n", i);
      g_drive[i].memory_card = true;

      if (mmc)
        g_drive[i].cmd23_supported = true; /* all MMC cards that support multi-block transfers support CMD23 */
      else
        g_drive[i].cmd23_supported = cardreg_read_int(scr, SCR_CMD_SUPPORT) & 2;
      dprintf("Card support for CMD23 = %u\n", g_drive[i].cmd23_supported);
      /* MMC and SD cards effectively signal sector addressing the same way */
      g_drive[i].sector_addressed = memory_ocr & OCR_CCS;
      /* MMC cards predating spec version 3.1 return illegal command for block data transfer commands */
      g_drive[i].single_blocks = mmc && cardreg_read_int(csd, CSD_SPEC_VERS) < 3;
      /* The very first data transfer must use all the commands */
      g_drive[i].needs_reselect = true;
      g_drive[i].needs_wait = true;
      g_drive[i].slot_claimed = false;
      /* Read the granularity of read and write blocks. MMC doesn't guarantee
       * these match, unlike SD. If a transfer doesn't align to write boundaries
       * then we'll need to read-modify-write, so write alignment must be at
       * least as large as read alignment. */
      g_drive[i].read_block_size = cardreg_read_int(csd, CSD_READ_BL_LEN);
      g_drive[i].write_block_size = cardreg_read_int(csd, CSD_WRITE_BL_LEN);
      g_drive[i].write_block_size = MAX(g_drive[i].write_block_size, g_drive[i].read_block_size);
      /* Apply a lower limit of the sector size. This is because SDHCI says the
       * on-the-wire block size must be fixed at 512 bytes for memory cards,
       * so there's no point in worrying about smaller granularity than that. */
      g_drive[i].read_block_size = MAX(g_drive[i].read_block_size, LOG2_SECTOR_SIZE);
      g_drive[i].write_block_size = MAX(g_drive[i].write_block_size, LOG2_SECTOR_SIZE);
      /* Ensure the buffer we've allocated for this drive is big enough to hold
       * one complete block at write alignment (read alignment cannot be bigger) */
      if (g_drive[i].write_block_size > g_drive[i].block_buffer_size)
      {
        if (g_drive[i].block_buffer)
          free(g_drive[i].block_buffer);
        g_drive[i].block_buffer = malloc(1 << g_drive[i].write_block_size);
        g_drive[i].block_buffer_size = g_drive[i].write_block_size;
        dprintf("Allocated buffer %p, size %u\n", g_drive[i].block_buffer, 1 << g_drive[i].write_block_size);
        if (g_drive[i].block_buffer == NULL)
        {
          g_drive[i].memory_card = false; /* maybe not the best error recovery, but better than a crash */
          g_drive[i].block_buffer_size = 0;
        }
      }
      /* Remember the storage capacity of the card */
      g_drive[i].capacity = capacity;
    }
    else
    {
      dprintf("IO card inserted in drive %u\n", i);
      g_drive[i].io_card = true;
    }
  }
  spinrw_write_unlock(&g_drive_lock);
}

void service_SDIOUnitDetached(uint32_t bus, uint32_t slot, uint32_t rca, uint32_t unit, uint32_t fic, bool writeprotect, bool mmc)
{
  IGNORE(unit);
  IGNORE(fic);
  IGNORE(writeprotect);
  IGNORE(mmc);
  
  /* Nothing to do for non-removable IO slots */
  uint32_t slot_handle = 0;
  uint32_t slot_spec;
  while (!_swix(SDIO_Enumerate, _INR(0,1)|_OUTR(1,2),
      SDIOEnumerate_Slots, slot_handle,
      &slot_handle, &slot_spec) && slot_handle != 0)
  {
    if (((slot_spec & SDIOEnumerate_BusMask) >> SDIOEnumerate_BusShift) == bus &&
        ((slot_spec & SDIOEnumerate_SlotMask) >> SDIOEnumerate_SlotShift) == slot)
    {
      if (slot_spec & SDIOEnumerate_Integrated)
        return;
      break;
    }
  }

  /* There will normally be exactly one drive associated with this bus/slot/RCA
   * combination - the only exceptions are if allocation failed, or if this is
   * not the first unit to be removed for this card. */

  /* We can't use locking here, because unlike the other service calls, this one
   * can be issued from the background. Instead, we need to be very careful about
   * the ordering which we test things, and insert memory barriers. */

  dprintf("Removal: drive 0 attached %u inserted %u bus %u slot %u rca %04X; compare %u/%u/%04X; seqno %u\n",
      g_drive[0].slot_attached, g_drive[0].card_inserted, g_drive[0].bus, g_drive[0].slot, g_drive[0].rca,
      bus, slot, rca, g_drive[0].sequence_number);
  uint32_t i;
  for (i = 0; i < NUM_FLOPPIES + NUM_WINNIES; i++)
  {
    if (g_drive[i].slot_attached)
    {
      barrier();
      if (g_drive[i].card_inserted)
      {
        barrier();
        if (g_drive[i].bus == bus && g_drive[i].slot == slot && g_drive[i].rca == rca)
        {
          spin_lock(&g_drive[i].certainty_lock);
          g_drive[i].certainty = FAITH;
          spin_unlock(&g_drive[i].certainty_lock);
          spin_lock(&g_drive[i].sequence_lock);
          g_drive[i].card_inserted = false;
          ++g_drive[i].sequence_number;
          spin_unlock(&g_drive[i].sequence_lock);
          if (g_drive[i].memory_card)
          {
            _swix(SDIO_Control, _INR(0,1), SDIOControl_AbortAll, (slot << SDIOControl_SlotShift) | (bus << SDIOControl_BusShift));
          }
          dprintf("%s card removed from drive %u; ",
              g_drive[i].memory_card && g_drive[i].io_card ? "Combo" :
              g_drive[i].memory_card ? "Memory" : "IO", i);
          break;
        }
      }
    }
  }
}

void service_SDIOSlotReleased(uint32_t bus, uint32_t slot)
{
  /* This service call is also called from the background, so again we can't use
   * locking and must rely on memory barriers instead. Also note that multiple
   * drives may correspond to this slot */
  uint32_t i;
  for (i = 0; i < NUM_FLOPPIES + NUM_WINNIES; i++)
  {
    if (g_drive[i].slot_attached)
    {
      barrier();
      /* Our behaviour doesn't depend upon whether card_inserted is true or not */
      if (g_drive[i].bus == bus && g_drive[i].slot == slot)
      {
        if (g_drive[i].slot_claimed)
          /* This just means we've finished using this drive ourselves */
          g_drive[i].slot_claimed = false;
        else
        {
          /* Someone else has been using this slot, or we've just finished
           * using a different drive in the same slot. Disable optimisations
           * for the next time we use this drive. */
          g_drive[i].needs_reselect = true;
          g_drive[i].needs_wait = true;
        }
        dprintf("Slot attached to drive %u being released, so reset timeout\n", i);
        spin_lock(&g_drive[i].certainty_lock);
        g_drive[i].certainty = FAITH;
        spin_unlock(&g_drive[i].certainty_lock);
      }
    }
  }
}
