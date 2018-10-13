/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "Licence").
 * You may not use this file except in compliance with the Licence.
 *
 * You can obtain a copy of the licence at
 * cddl/RiscOS/Sources/HWSupport/SD/SDIODriver/LICENCE.
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

/** \file util.c
 * Miscellaneous odds and ends.
 */

#include "swis.h"

#include "Global/HALEntries.h"
#include "Global/NewErrors.h"
#include "Interface/SDIO.h"

#include "SyncLib/spinrw.h"

#include "message.h"
#include "util.h"

/** Convert from bus index to pointer to our struct for it.
 *  If lookup is successful, this function returns with a read lock held on the SDHCI list.
 *  \arg bus   Bus index to lookup
 *  \arg sdhci Pointer through which to return controller block pointer
 *  \return    Pointer to error block in event of unsuccessful lookup
 */
_kernel_oserror *util_find_bus(uint32_t bus, sdhcinode_t **sdhci)
{
  sdhcinode_t *s;
  spinrw_read_lock(&g_sdhci_lock);
  for (s = g_sdhci; s && s->bus != bus; s = s->next);
  if (s == NULL)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadBus, 0);
  }
  *sdhci = s;
  return NULL;
}

/** Convert from bus and slot indexes to pointers to our structs for them.
 *  If lookup is successful, this function returns with a read lock held on the SDHCI list.
 *  \arg bus   Bus index to lookup
 *  \arg sloti Slot index to lookup
 *  \arg sdhci Pointer through which to return controller block pointer
 *  \arg slot  Pointer through which to return slot block pointer
 *  \return    Pointer to error block in event of unsuccessful lookup
 */
_kernel_oserror *util_find_bus_and_slot(uint32_t bus, uint32_t sloti, sdhcinode_t **sdhci, sdmmcslot_t **slot)
{
  sdhcinode_t *s;
  spinrw_read_lock(&g_sdhci_lock);
  for (s = g_sdhci; s && s->bus != bus; s = s->next);
  if (s == NULL)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadBus, 0);
  }
  if (sloti >= s->dev->slots)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadSlot, 0);
  }
  *sdhci = s;
  *slot = s->slot + sloti;
  return NULL;
}

/** Delay for at least the specified number of microseconds */
void util_microdelay(uint32_t us)
{
  _swix(OS_Hardware, _IN(0)|_INR(8,9), us, 0, EntryNo_HAL_CounterDelay);
}
