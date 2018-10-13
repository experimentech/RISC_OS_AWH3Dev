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

/** \file miscop.c
 * Implementation of low-level miscellaneous functions.
 */

#include "Interface/FileCore.h"
#include "Interface/FileCoreErr.h"
#include "Interface/SDIO.h"

#include "discop.h"
#include "miscop.h"

/** Time between polls, in cs. This is the same as ADFS uses when drive detection works. */
#define POLL_PERIOD (10)

low_level_error_t miscop_Mount(uint32_t drive, uint32_t byte_address, uint8_t * restrict buffer, size_t length, disc_record_t * restrict disc_record)
{
  low_level_error_t e;
  uint64_t disc_address = (uint64_t) byte_address & LegacyDiscAddress_ByteOffset_Mask;
  IGNORE(disc_record);

  dprintf("Mount - from :%u/%08X to %p, length %u, disc record %p\n",
      drive, byte_address, buffer, length, (void *) disc_record);

  e = discop(DiscOp_ReadSecs, SDIOOp_DisableEscape, drive, &disc_address, (block_or_scatter_t *) &buffer, &length);
  /* Unlike DiscOps, we don't update the pointers on exit */

  return e;
}

void miscop_PollChanged(uint32_t drive, uint32_t * restrict sequence_number, uint32_t * restrict result_flags)
{
  if (drive >= NUM_FLOPPIES + NUM_WINNIES)
  {
    *result_flags = MiscOp_PollChanged_Empty_Flag | MiscOp_PollChanged_EmptyWorks_Flag | MiscOp_PollChanged_ChangedWorks_Flag;
    *sequence_number = 0;
    return;
  }

  spinrw_read_lock(&g_drive_lock);
  bool my_card_inserted = g_drive[drive].slot_attached;
  spin_lock(&g_drive[drive].sequence_lock);
  my_card_inserted &= g_drive[drive].card_inserted;
  uint32_t my_sequence_number = g_drive[drive].sequence_number;
  spin_unlock(&g_drive[drive].sequence_lock);
  spin_lock(&g_drive[drive].certainty_lock);
  uint32_t certain = g_drive[drive].certainty;
  spin_unlock(&g_drive[drive].certainty_lock);
  if (!g_drive[drive].slot_attached || !g_drive[drive].no_card_detect)
    certain = 1;
  spinrw_read_unlock(&g_drive_lock);

  /* Now we have a consistent sequence number and inserted flag, compare it to
   * the caller's world view. */
  if (certain)
    *result_flags = MiscOp_PollChanged_NotChanged_Flag | MiscOp_PollChanged_EmptyWorks_Flag | MiscOp_PollChanged_ChangedWorks_Flag;
  else
    *result_flags = MiscOp_PollChanged_MaybeChanged_Flag | MiscOp_PollChanged_EmptyWorks_Flag | MiscOp_PollChanged_ChangedWorks_Flag;
  if (my_sequence_number != *sequence_number)
    *result_flags = MiscOp_PollChanged_Changed_Flag | MiscOp_PollChanged_EmptyWorks_Flag | MiscOp_PollChanged_ChangedWorks_Flag;
  if (!my_card_inserted && certain)
    *result_flags = MiscOp_PollChanged_Empty_Flag | MiscOp_PollChanged_EmptyWorks_Flag | MiscOp_PollChanged_ChangedWorks_Flag;
  *sequence_number = my_sequence_number;

  dprintf("PollChanged(drive %u) - return flags %03X, sequence_number %u\n", drive, *result_flags, *sequence_number);
}

void miscop_LockDrive(uint32_t drive)
{
  IGNORE(drive);
  /* Could perhaps turn on the LED as the PRM suggests */
}

void miscop_UnlockDrive(uint32_t drive)
{
  IGNORE(drive);
  /* Could perhaps turn off the LED as the PRM suggests */
}

void miscop_PollPeriod(uint32_t drive, uint32_t * restrict poll_period, const char ** restrict media_type_name)
{
  IGNORE(drive);
  *poll_period = POLL_PERIOD;
  *media_type_name = g_media_type_name;
}

void miscop_Eject(uint32_t drive)
{
  /* Can't do this */
  IGNORE(drive);
}

void miscop_DriveStatus(uint32_t drive, uint32_t *status_flags)
{
  spinrw_read_lock(&g_drive_lock);
  *status_flags = g_drive[drive].slot_attached ? 0 : MiscOp_DriveHidden_Flag;
  spinrw_read_unlock(&g_drive_lock);
}
