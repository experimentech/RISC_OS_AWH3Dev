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

/** \file swi.c
 * Implementation of SWI handlers for FS-specific SWIs.
 */

#include <stddef.h>
#include "kernel.h"

#include "Global/NewErrors.h"
#include "Interface/SDFS.h"
#include "Interface/SDFSErr.h"

#include "SyncLib/spinrw.h"

#include "globals.h"
#include "message.h"
#include "swi.h"

_kernel_oserror *swi_ReadCardInfo(uint32_t reason, uint32_t drive, _kernel_swi_regs *r)
{
  _kernel_oserror *e = NULL;

  if (drive > NUM_FLOPPIES + NUM_WINNIES)
    return MESSAGE_ERRORLOOKUP(true, BadDrive, 0);

  spinrw_read_lock(&g_drive_lock);
  drive_t *dr = g_drive + drive;

  if (!dr->slot_attached || !dr->card_inserted)
  {
    e = MESSAGE_ERRORLOOKUP(true, DriveEmpty, 0);
    spinrw_read_unlock(&g_drive_lock);
    return e;
  }

  if (!dr->memory_card)
  {
    e = MESSAGE_ERRORLOOKUP(true, NotMem, 0);
    spinrw_read_unlock(&g_drive_lock);
    return e;
  }

  switch (reason)
  {
    case SDFSReadCardInfo_Size:
      r->r[2] = (uint32_t) g_drive[drive].capacity;
      r->r[3] = (uint32_t) (g_drive[drive].capacity >> 32);
      break;

    case SDFSReadCardInfo_Location:
      r->r[2] = (g_drive[drive].slot << 0) |
                (g_drive[drive].bus << 8) |
                (g_drive[drive].rca << 16);
      break;

    default:
      e = MESSAGE_ERRORLOOKUP(true, BadReason, "SDFS_ReadCardInfo");
      break;
  }

  spinrw_read_unlock(&g_drive_lock);
  return e;
}
