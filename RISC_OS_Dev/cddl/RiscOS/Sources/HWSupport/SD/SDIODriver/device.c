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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "swis.h"

#include "Global/HALEntries.h"
#include "Global/Services.h"
#include "Interface/SDIO.h"

#include "device.h"
#include "globals.h"
#include "register.h"
#include "swi.h"
#include "SDIOHdr.h"
#include "trampoline.h"
#include "util.h"

void device_added(sdhcidevice_t *dev)
{
  /* Ignore device if it's not a recognised major version number */
  if ((dev->dev.version & 0xFFFF0000) != HALDeviceSDHCI_MajorVersion_Original)
    return;

  uint32_t busi;
  sdhcinode_t *sdhci = malloc(sizeof *sdhci + dev->slots * sizeof (sdmmcslot_t));
  if (sdhci == NULL)
    return;

  /* Initialise members of the controller struct */
  sdhci->trampoline = malloc(trampoline_length);
  if (sdhci->trampoline == NULL)
  {
    free(sdhci);
    return;
  }
  memcpy(sdhci->trampoline, dev->dev.devicenumber & (1u<<31) ? trampoline_vectored : trampoline_unshared, trampoline_length);
  sdhci->trampoline[trampoline_offset_pointer] = (uint32_t) sdhci;
  sdhci->trampoline[trampoline_offset_privateword] = (uint32_t) g_module_pw;
  sdhci->trampoline[trampoline_offset_cmhgveneer] = (uint32_t) module_irq_veneer;
  _swix(OS_SynchroniseCodeAreas, _INR(0,2), 1, sdhci->trampoline, (uint32_t)sdhci->trampoline + trampoline_length - 1);

  sdhci->dev = dev;
  sdhci->next = NULL;

  /* Initialise the controller hardware */
  if (dev->dev.Activate(&dev->dev) == false)
  {
    /* Controller initialisation failed */
    free(sdhci->trampoline);
    free(sdhci);
    return;
  }

  /* Initialise members of each slot struct */
  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
  {
    sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
    sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
    bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
    sdmmcslot_t         *slot = sdhci->slot + sloti;

    slot->insertion_pending = false;
    slot->write_protect = true;
    slot->no_card_detect = dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_NoCardDetect;
    slot->busy = MUTEX_UNLOCKED;
    slot->doing_poll = MUTEX_UNLOCKED;
    slot->doing_card_detect = MUTEX_UNLOCKED;
    _swix(OS_ReadMonotonicTime, _OUT(0), &slot->card_detect_debounce_time);
    slot->card_detect_state = CD_DEBOUNCING; /* as though we're at the end of debounce already */
    slot->memory_type = MEMORY_NONE;
    slot->io_functions = 0;
    register_init_buffer(wrbuf);
    slot->op_used = 0;
    slot->op_free = 0;
    slot->op_lock = (const spinlock_t) SPIN_INITIALISER;

    /* Mask all interrupts for this slot */
    REGISTER_WRITE(normal_interrupt_signal_enable, 0);
    REGISTER_WRITE(error_interrupt_signal_enable, 0);
    REGISTER_WRITE(normal_interrupt_status_enable, 0);
    REGISTER_WRITE(error_interrupt_status_enable, 0);

    /* Turn off activity LEDs */
    dev->SetActivity(dev, sloti, HALDeviceSDHCI_ActivityOff);

    /* Read and interpret capabilities for this slot */
    slot->spec_rev = REGISTER_READ(host_controller_version) & HCV_SREV_MASK;
    if (dev->GetCapabilities)
    {
      uint64_t capabilities = dev->GetCapabilities(dev, sloti);
      slot->caps[0] = (uint32_t) capabilities;
      slot->caps[1] = (uint32_t) (capabilities >> 32);
    }
    else
    {
      slot->caps[0] = REGISTER_READ(capabilities[0]);
      slot->caps[1] = slot->spec_rev < HCV_SREV_3_00 ? 0 : REGISTER_READ(capabilities[1]);
    }
    if (dev->GetVddCapabilities)
      slot->voltage_caps = dev->GetVddCapabilities(dev, sloti) * CAP0_VS33;
    else
      slot->voltage_caps = slot->caps[0] & (CAP0_VS33 | CAP0_VS30 | CAP0_VS18);
    slot->controller_ocr = 0;
    if (slot->voltage_caps & CAP0_VS18)
      slot->controller_ocr |= OCR_1_7V_1_95V;
    if (slot->voltage_caps & CAP0_VS30)
      slot->controller_ocr |= OCR_2_9V_3_0V | OCR_3_0V_3_1V;
    if (slot->voltage_caps & CAP0_VS33)
      slot->controller_ocr |= OCR_3_2V_3_3V | OCR_3_3V_3_4V;
    switch (slot->caps[0] & CAP0_MBL_MASK)
    {
      case CAP0_MBL_2048: slot->controller_maxblklen = 11; break;
      case CAP0_MBL_1024: slot->controller_maxblklen = 10; break;
      default:            slot->controller_maxblklen =  9; break;
    }
  }

  /* Find a unique bus number and insert controller block into global list,
   * now that it is fully initialised */
  spinrw_write_lock(&g_sdhci_lock);
  for (busi = 0;; busi++)
  {
    sdhcinode_t *prev, *this;
    for (prev = NULL, this = g_sdhci; this != NULL && this->bus != busi; prev = this, this = this->next);
    if (this == NULL)
    {
      if (prev == NULL)
        g_sdhci = sdhci;
      else
        prev->next = sdhci;
      sdhci->bus = busi;
      break;
    }
  }
  spinrw_write_unlock(&g_sdhci_lock);

  /* In order to keep using sdhci now that it's in the global list, we need a
   * read lock on it. There's a tiny chance that it might have been removed in
   * the window since we released the write lock, so we must find the pointer
   * again even though we already know it. */
  if (util_find_bus(busi, &sdhci) != NULL)
    return;

  /* Install interrupt handler for this controller - needed before we can issue commands */
  _swix(OS_ClaimDeviceVector, _INR(0,2), dev->dev.devicenumber, sdhci->trampoline, dev);
  /* Enable the interrupt in the interrupt controller */
  _swix(OS_Hardware, _IN(0)|_INR(8,9), dev->dev.devicenumber, 0, EntryNo_HAL_IRQEnable);

  /* Issue the service calls so our clients know we're here.
   * Note that we must be ready to handle any SWIs for this bus by this point. */
  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
    _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotAttached,
        (sloti << SDIOSlotAttached_SlotShift) |
        (sdhci->bus << SDIOSlotAttached_BusShift) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_Integrated ? SDIOSlotAttached_Integrated : 0) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_NoCardDetect ? SDIOSlotAttached_NoCardDetect : 0) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_IntegratedMem ? SDIOSlotAttached_IntegratedMem : 0));

  /* Reset and probe the bus */
  if (swi_Initialise_reset_bus(busi) != NULL)
  {
    /* Failed, so clean up */
    spinrw_read_unlock(&g_sdhci_lock);
    device_removed(dev);
    return;
  }

  /* We've finished with the sdhci and slot pointers now */
  spinrw_read_unlock(&g_sdhci_lock);
}

void device_removed(sdhcidevice_t *dev)
{
  /* Ignore device if it's not a recognised major version number */
  if ((dev->dev.version & 0xFFFF0000) != HALDeviceSDHCI_MajorVersion_Original)
    return;

  sdhcinode_t *prev, *sdhci;

  /* First thing to do is issue the service calls, while the bus index is still
   * guaranteed to be unique. Do this while holding a read lock - it we make a
   * service call with a write lock held, we'd get deadlocks if anyone tries to
   * call any of our SWIs from the service call handler. */
  spinrw_read_lock(&g_sdhci_lock);
  for (prev = NULL, sdhci = g_sdhci; sdhci != NULL && sdhci->dev != dev; prev = sdhci, sdhci = sdhci->next);
  if (sdhci == NULL) /* shouldn't happen, but just in case */
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return;
  }
  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
  {
    sdmmcslot_t *slot = sdhci->slot + sloti;
    mutex_lock(&slot->doing_card_detect); /* might as well leave it claimed now */
    if (slot->card_detect_state == CD_ANNOUNCED)
      device_units_detached(sdhci, sloti);
    _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotDetached,
        (sloti << SDIOSlotAttached_SlotShift) |
        (sdhci->bus << SDIOSlotAttached_BusShift) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_Integrated ? SDIOSlotAttached_Integrated : 0) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_NoCardDetect ? SDIOSlotAttached_NoCardDetect : 0) |
        (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_IntegratedMem ? SDIOSlotAttached_IntegratedMem : 0));
  }
  spinrw_read_unlock(&g_sdhci_lock);

  /* Find controller struct from HAL device pointer, and delink it from the list
   * of controllers. This time we need a write lock. */
  spinrw_write_lock(&g_sdhci_lock);
  for (prev = NULL, sdhci = g_sdhci; sdhci != NULL && sdhci->dev != dev; prev = sdhci, sdhci = sdhci->next);
  if (sdhci == NULL) /* shouldn't happen, but just in case */
  {
    spinrw_write_unlock(&g_sdhci_lock);
    return;
  }
  if (prev == NULL)
    g_sdhci = sdhci->next;
  else
    prev->next = sdhci->next;
  spinrw_write_unlock(&g_sdhci_lock);

  /* Mask interrupts in the SD controller */
  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
  {
    sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
    sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
    bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;

    REGISTER_WRITE(normal_interrupt_signal_enable, 0);
    REGISTER_WRITE(error_interrupt_signal_enable, 0);
    REGISTER_WRITE(normal_interrupt_status_enable, 0);
    REGISTER_WRITE(error_interrupt_status_enable, 0);
  }

  /* Leave the interrupt enabled in the interrupt controller as per standard RISC OS practice */

  /* Deregister interrupt handler */
  _swix(OS_ReleaseDeviceVector, _INR(0,2), dev->dev.devicenumber, sdhci->trampoline, dev);

  /* Tell the HAL device to do its own cleanup */
  dev->dev.Deactivate(&dev->dev);

  /* Release memory */
  free(sdhci->trampoline);
  free(sdhci);
}

static void issue_unit_service_calls(sdhcinode_t *sdhci, uint32_t sloti, uint32_t service)
{
  sdmmcslot_t *slot = sdhci->slot + sloti;
  for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
  {
    sdmmccard_t *card = slot->card + cardi;
    if (card->in_use)
    {
      uint32_t r2 = (sloti << SDIOUnitAttached_SlotShift) |
          (sdhci->bus << SDIOUnitAttached_BusShift) |
          (card->rca << SDIOUnitAttached_RCAShift);
      if (slot->memory_type != MEMORY_NONE)
      {
        uint32_t r3 = 0 << SDIOUnitAttached_UnitShift;
        if (slot->write_protect)
          r3 |= SDIOUnitAttached_WriteProtect;
        if (slot->memory_type == MEMORY_MMC)
          r3 |= SDIOUnitAttached_MMC;
        _swix(OS_ServiceCall, _INR(1,5), service, r2, r3, (uint32_t) card->capacity, (uint32_t) (card->capacity >> 32));
      }
      for (uint32_t function = 1; function <= slot->io_functions; function++)
      {
        uint32_t r3 = function << SDIOUnitAttached_UnitShift;
        r3 |= slot->fic[function-1] << SDIOUnitAttached_FICShift;
        if (slot->write_protect)
          r3 |= SDIOUnitAttached_WriteProtect;
        _swix(OS_ServiceCall, _INR(1,5), service, r2, r3, 0, 0);
      }
    }
  }
}

void device_units_attached(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdmmcslot_t *slot = sdhci->slot + sloti;
  /* Assume the doing_card_detect mutex is already held on entry */
  if (slot->card_detect_state == CD_OCCUPIED)
  {
    issue_unit_service_calls(sdhci, sloti, Service_SDIOUnitAttached);
    slot->card_detect_state = CD_ANNOUNCED;
  }
  dprintf("Card inserted (write-protect = %d)\n", slot->write_protect);
}

void device_units_detached(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdmmcslot_t *slot = sdhci->slot + sloti;
  /* Assume the doing_card_detect mutex is already held on entry */
  if (slot->card_detect_state == CD_ANNOUNCED)
  {
    issue_unit_service_calls(sdhci, sloti, Service_SDIOUnitDetached);
    slot->card_detect_state = CD_OCCUPIED;
  }
  dprintf("Card removed  ");
}
