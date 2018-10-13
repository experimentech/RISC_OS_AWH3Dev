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

/** \file swi.c
 * Implementation of SWIs.
 */

#include <stdint.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "Global/HALEntries.h"
#include "Global/NewErrors.h"
#include "Global/Services.h"
#include "Interface/SDIO.h"

#include "SyncLib/atomic.h"
#include "SyncLib/barrier.h"

#include "SDIOHdr.h"
#include "device.h"
#include "message.h"
#include "op.h"
#include "probe.h"
#include "register.h"
#include "swi.h"
#include "util.h"

/** Minimum time we have to see the card detect line go active before triggering
 *  the card insertion callback. Measured in cs */
#define CARD_INSERTION_DEBOUNCE_TIME (3)

static bool get_card_detect(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  if (dev->GetCardDetect)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    return dev->GetCardDetect(dev, sloti);
  }
  else
  {
    return REGISTER_READ(present_state) & PS_CD;
  }
}

static bool get_write_protect(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  if (dev->GetWriteProtect)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    return dev->GetWriteProtect(dev, sloti);
  }
  else
  {
    return REGISTER_READ(present_state) & PS_WP;
  }
}

_kernel_oserror *swi_Initialise_reset_bus(uint32_t bus)
{
  sdhcinode_t *sdhci;
  sdhcidevice_t *dev;
  uint32_t sloti;
  _kernel_oserror *e = util_find_bus(bus, &sdhci);
  if (e != NULL)
    return e;
  dev = sdhci->dev;

  for (sloti = 0; sloti < dev->slots; sloti++)
  {
    /* Lock all the slots on this bus */
    e = swi_Control_lock(bus, sloti);
    if (e != NULL)
      goto exit;
  }

  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
  {
    /* Abort any outstanding ops on each slot.
     * No new ones should be started while we hold the "busy" flag. */
    e = swi_Control_abort_all(bus, sloti);
    if (e != NULL)
      goto exit;
  }

  /* Reset the controller */
  dev->dev.Reset(&dev->dev);

  /* Force a (re)poll of all card detect lines */
  for (uint32_t sloti = 0; sloti < sdhci->dev->slots; sloti++)
    swi_Control_poll_card_detect(sdhci->bus, sloti);

  /* Perform card identification process for each slot which has a card present,
   * whether it is newly inserted or not */
  for (uint32_t sloti = 0; sloti < dev->slots; sloti++)
  {
    sdmmcslot_t *slot = sdhci->slot + sloti;
    mutex_lock(&slot->doing_card_detect);
    if (slot->no_card_detect || slot->card_detect_state != CD_VACANT)
    {
      slot->insertion_pending = false; // effectively cancel the callback, because we're going to probe now anyway
      if (slot->card_detect_state != CD_VACANT)
      {
        device_units_detached(sdhci, sloti);
        if (slot->no_card_detect)
          slot->card_detect_state = CD_VACANT;
      }
      if (probe_bus(sdhci, sloti))
      {
        if (slot->no_card_detect)
        {
          slot->card_detect_state = CD_OCCUPIED;
          slot->write_protect = get_write_protect(sdhci, sloti);
        }
        device_units_attached(sdhci, sloti);
      }
    }
    mutex_unlock(&slot->doing_card_detect);
  }

exit:
  for (sloti = 0; sloti < dev->slots; sloti++)
    swi_Control_unlock(bus, sloti);
#ifdef DEBUG_ENABLED
  #include "command.h"
  command_sdiodevices();
  command_sdioslots();
#endif
  spinrw_read_unlock(&g_sdhci_lock);
  return e;
}

_kernel_oserror *swi_Initialise_rescan_slot(uint32_t bus, uint32_t sloti)
{
  /* Find controller pointer */
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  /* The sequence of operations here matches that in swi_Initialise_reset_bus,
   * except that we don't abort all operations on the slot. This makes this
   * routine suitable for supporting card detection by polling rather than by
   * hardware card detect lines (we don't want to kill any background transfers
   * just because we're polling the card).
   */

  swi_Control_lock(bus, sloti);
  swi_Control_poll_card_detect(sdhci->bus, sloti);
  mutex_lock(&slot->doing_card_detect);
  if (slot->no_card_detect || slot->card_detect_state != CD_VACANT)
  {
    slot->insertion_pending = false; // effectively cancel the callback, because we're going to probe now anyway
    if (slot->card_detect_state != CD_VACANT)
    {
      device_units_detached(sdhci, sloti);
      if (slot->no_card_detect)
        slot->card_detect_state = CD_VACANT;
    }
    if (probe_bus(sdhci, sloti))
    {
      if (slot->no_card_detect)
      {
        slot->card_detect_state = CD_OCCUPIED;
        slot->write_protect = get_write_protect(sdhci, sloti);
      }
      device_units_attached(sdhci, sloti);
    }
  }
  mutex_unlock(&slot->doing_card_detect);
  swi_Control_unlock(bus, sloti);

  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_try_lock(uint32_t bus, uint32_t sloti)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  if (!mutex_try_lock(&slot->busy))
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_SlotInUse, 0);
  }
  _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotAcquired,
      (sloti << SDIOSlotAcquired_SlotShift) | (sdhci->bus << SDIOSlotAcquired_BusShift));
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_lock(uint32_t bus, uint32_t sloti)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  mutex_lock(&slot->busy);
  _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotAcquired,
      (sloti << SDIOSlotAcquired_SlotShift) | (sdhci->bus << SDIOSlotAcquired_BusShift));
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_sleep_lock(uint32_t bus, uint32_t sloti)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  mutex_sleep_lock(&slot->busy);
  _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotAcquired,
      (sloti << SDIOSlotAcquired_SlotShift) | (sdhci->bus << SDIOSlotAcquired_BusShift));
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_unlock(uint32_t bus, uint32_t sloti)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  _swix(OS_ServiceCall, _INR(1,2), Service_SDIOSlotReleased,
      (sloti << SDIOSlotAcquired_SlotShift) | (sdhci->bus << SDIOSlotAcquired_BusShift));
  mutex_unlock(&slot->busy);
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_abort_all(uint32_t bus, uint32_t sloti)
{
  /* Find controller and slot pointers */
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  op_abort_all(slot);
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_abort_op(uint32_t bus, uint32_t sloti, sdioop_t *op)
{
  /* Find controller and slot pointers */
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;
  if (op < slot->op || op >= slot->op + QUEUE_LENGTH)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadOp, 0);
  }

  op_abort(op);
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Control_poll_card_detect(uint32_t bus, uint32_t sloti)
{
  /* Find controller and slot pointers */
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;
  if (slot->no_card_detect)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return NULL;
  }
  if (mutex_try_lock(&slot->doing_card_detect))
  {
    bool present = get_card_detect(sdhci, sloti);
    if (present)
    {
      if (slot->card_detect_state <= CD_DEBOUNCING)
      {
        int32_t now;
        _swix(OS_ReadMonotonicTime, _OUT(0), &now);
        if (slot->card_detect_state == CD_VACANT)
        {
          slot->card_detect_debounce_time = now + CARD_INSERTION_DEBOUNCE_TIME;
          slot->card_detect_state = CD_DEBOUNCING;
        }
        else if (now - slot->card_detect_debounce_time >= 0)
        {
          slot->card_detect_state = CD_OCCUPIED;
          slot->write_protect = get_write_protect(sdhci, sloti);
          slot->insertion_pending = true;
          _swix(OS_AddCallBack, _INR(0,1), module_card_insertion_veneer, g_module_pw);
        }
      }
    }
    else
    {
      /* Unit removed service calls need to be issued in the background in case
       * the foreground is blocked doing an SDIO_Op SWI */
      if (slot->card_detect_state == CD_ANNOUNCED)
        device_units_detached(sdhci, sloti);
      slot->card_detect_state = CD_VACANT;
    }
    mutex_unlock(&slot->doing_card_detect);
  }
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Enumerate_slots(uint32_t *restrict index, uint32_t *restrict r2)
{
  sdhcinode_t *sdhci;
  uint32_t sloti = *index;
  spinrw_read_lock(&g_sdhci_lock);
  for (sdhci = g_sdhci; sdhci; sdhci = sdhci->next)
  {
    if (sloti < sdhci->dev->slots)
    {
      *r2 = (sloti << SDIOEnumerate_SlotShift) |
            (sdhci->bus << SDIOEnumerate_BusShift) |
            (sdhci->dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_Integrated ? SDIOEnumerate_Integrated : 0) |
            (sdhci->dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_NoCardDetect ? SDIOEnumerate_NoCardDetect : 0) |
            (sdhci->dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_IntegratedMem ? SDIOEnumerate_IntegratedMem : 0);
      (*index)++;
      spinrw_read_unlock(&g_sdhci_lock);
      return NULL;
    }
    sloti -= sdhci->dev->slots;
  }
  /* Run out of slots */
  *index = 0;
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_Enumerate_units(uint32_t bus, uint32_t sloti, uint32_t *restrict index, uint32_t *restrict r2, uint32_t *restrict r3, uint32_t *restrict r4, uint32_t *restrict r5)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  uint32_t unit = *index;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;
  if (slot->card_detect_state == CD_ANNOUNCED)
  {
    if (slot->memory_type != MEMORY_NONE)
    {
      for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
      {
        sdmmccard_t *card = slot->card + cardi;
        if (card->in_use)
        {
          if (unit == 0)
          {
            *r2 = (sloti << SDIOEnumerate_SlotShift) |
                  (bus << SDIOEnumerate_BusShift) |
                  (card->rca << SDIOEnumerate_RCAShift);
            *r3 = 0 << SDIOEnumerate_UnitShift;
            if (slot->write_protect)
              *r3 |= SDIOEnumerate_WriteProtect;
            if (slot->memory_type == MEMORY_MMC)
              *r3 |= SDIOEnumerate_MMC;
            *r4 = (uint32_t) card->capacity;
            *r5 = (uint32_t) (card->capacity >> 32);
            (*index)++;
            spinrw_read_unlock(&g_sdhci_lock);
            return NULL;
          }
          unit--;
        }
      }
    }
    if (unit < slot->io_functions)
    {
      uint32_t function = unit + 1;
      *r2 = (sloti << SDIOEnumerate_SlotShift) |
            (bus << SDIOEnumerate_BusShift) |
            (slot->card[0].rca << SDIOEnumerate_RCAShift);
      *r3 = function << SDIOEnumerate_UnitShift;
      *r3 |= slot->fic[function-1] << SDIOEnumerate_FICShift;
      if (slot->write_protect)
        *r3 |= SDIOEnumerate_WriteProtect;
      *r4 = 0;
      *r5 = 0;
      (*index)++;
      spinrw_read_unlock(&g_sdhci_lock);
      return NULL;
    }
  }
  /* Run out of units */
  *index = 0;
  spinrw_read_unlock(&g_sdhci_lock);
  return NULL;
}

_kernel_oserror *swi_ControllerFeatures(uint32_t bus, uint32_t sloti, uint32_t index, uint32_t *value)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  switch (index)
  {
    case SDIOController_MaxBlockLen:
      *value = slot->controller_maxblklen;
      break;
    default:
      e = MESSAGE_ERRORLOOKUP(true, SDIO_BadReason, "SDIO_ControllerFeatures");
      break;
  }

  spinrw_read_unlock(&g_sdhci_lock);
  return e;
}

_kernel_oserror *swi_ReadRegister(uint32_t bus, uint32_t sloti, uint32_t rca, uint32_t index, void *buffer)
{
  sdhcinode_t *sdhci;
  sdmmcslot_t *slot;
  uint32_t cardi;
  sdmmccard_t *card = NULL;
  _kernel_oserror *e = util_find_bus_and_slot(bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;
  for (cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
  {
    card = slot->card + cardi;
    if (card->in_use && card->rca == rca)
      break;
  }
  if (cardi == MAX_CARDS_PER_SLOT)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadRCA, 0);
  }

  switch (index)
  {
    case SDIORegister_MemoryOCR:
      if (slot->memory_type != MEMORY_NONE)
        memcpy(buffer, &slot->memory_ocr, sizeof slot->memory_ocr);
      else
        e = MESSAGE_ERRORLOOKUP(true, SDIO_BadReason, "SDIO_ReadRegister");
      break;
    case SDIORegister_IOOCR:
      if (slot->io_functions > 0)
        memcpy(buffer, &slot->io_ocr, sizeof slot->io_ocr);
      else
        e = MESSAGE_ERRORLOOKUP(true, SDIO_BadReason, "SDIO_ReadRegister");
      break;
    case SDIORegister_CID:
      memcpy(buffer, card->cid, sizeof card->cid);
      break;
    case SDIORegister_CSD:
      memcpy(buffer, card->csd, sizeof card->csd);
      break;
    case SDIORegister_SCR:
      memcpy(buffer, slot->scr, sizeof slot->scr);
      break;
    default:
      e = MESSAGE_ERRORLOOKUP(true, SDIO_BadReason, "SDIO_ReadRegister");
      break;
  }

  spinrw_read_unlock(&g_sdhci_lock);
  return e;
}

_kernel_oserror *swi_Op(sdioop_block_t *b)
{
  int32_t now, timeout;
  sdhcinode_t *sdhci;
  uint32_t sloti = b->r0.bits.slot;
  sdmmcslot_t *slot;

  /* Set timeout time */
  if (!b->r0.bits.bg)
  {
    _swix(OS_ReadMonotonicTime, _OUT(0), &timeout);
    if (b->r5.timeout == 0)
      timeout += 0x7fffffff; /* 248 days, near enough infinite */
    else
      timeout += b->r5.timeout + 1; /* add 1 to compensate for first tick being < 1cs */
  }

  /* Find controller and slot pointers */
  _kernel_oserror *e = util_find_bus_and_slot(b->r0.bits.bus, sloti, &sdhci, &slot);
  if (e != NULL)
    return e;

  /* Calculate command first, since it can result in an error */
  uint16_t command = (b->cmdres.R0->command << CMD_INDEX_SHIFT) & CMD_INDEX_MASK;
  if (b->r0.bits.chk_crc)
    command |= CMD_CCCE;
  if (b->r0.bits.chk_index)
    command |= CMD_CICE;
  if (b->r1.cmdres_len == 8)
    command |= CMD_RSP_NONE;
  else if (b->r1.cmdres_len == 8+15)
    command |= CMD_RSP_136;
  else if (b->r1.cmdres_len != 8+4)
  {
    spinrw_read_unlock(&g_sdhci_lock);
    return MESSAGE_ERRORLOOKUP(true, SDIO_BadCRLen, 0);
  }
  else if (b->r0.bits.chk_busy)
    command |= CMD_RSP_48_BUSY;
  else
    command |= CMD_RSP_48;
  switch (b->cmdres.R0->command & (SDIOOp_CmdFlg_CmdMask | SDIOOp_CmdFlg_AppCmd))
  {
    case CMD12_STOP_TRANSMISSION:
      command |= CMD_TYPE_ABORT;
      break;
    case CMD52_IO_RW_DIRECT:
      if ((b->cmdres.R0->argument & IO_RW_WRITE) != 0 &&
          (b->cmdres.R0->argument & IO_RW_FUNCTION_MASK) == 0)
      {
        /* Write to the CIA - see whether it was one of the special registers */
        switch ((b->cmdres.R0->argument & IO_RW_REGISTER_MASK) >> IO_RW_REGISTER_SHIFT)
        {
          case CCCR_IO_ABORT:
            command |= CMD_TYPE_ABORT;
            break;
          case CCCR_BUS_SUSPEND:
            command |= CMD_TYPE_SUSPEND;
            break;
          case CCCR_FUNCTION_SELECT:
            command |= CMD_TYPE_RESUME;
            break;
        }
      }
      break;
  }
  if (b->data_len > 0)
    command |= CMD_DP;

  /* Calculate data sizes - this can also result in an error */
  uint32_t total_length = b->data_len;
  uint32_t block_split = 1 << ((b->cmdres.R0->command & SDIOOp_CmdFlg_BlockSplitMask) >> SDIOOp_CmdFlg_BlockSplitShift);
  uint32_t block_size = MIN(total_length, block_split);
  uint32_t block_count;
  if (block_size == 0)
    block_count = 0;
  else
  {
    block_count = total_length / block_size;
    if (total_length % block_size != 0)
    {
      spinrw_read_unlock(&g_sdhci_lock);
      return MESSAGE_ERRORLOOKUP(true, SDIO_PartBlk, 0);
    }
    if (block_count >= 0x10000)
    {
      spinrw_read_unlock(&g_sdhci_lock);
      return MESSAGE_ERRORLOOKUP(true, SDIO_TooLong, 0);
    }
  }

  /* Grab 1 (or 2 for app commands) op blocks for this slot to hold our op details */
  sdioop_t *op;
  do
  {
    size_t ops_needed = b->cmdres.R0->command & SDIOOp_CmdFlg_AppCmd ? 2 : 1;
    size_t max_ops_used = QUEUE_LENGTH - ops_needed;
    spin_lock(&slot->op_lock);
    size_t ops_used = (slot->op_free - slot->op_used + QUEUE_LENGTH) % QUEUE_LENGTH;
    if (ops_used < max_ops_used)
    {
      size_t i = slot->op_free;
      if (ops_needed == 2)
      {
        op = slot->op + i;
        if (++i == QUEUE_LENGTH)
          i = 0;
        /* Fill in the op block for CMD55 to indicate that the following command is an application command */
        op->state = CMD_STATE_READY;
        op->chk_r1 = true;
        op->chk_r5 = false;
        op->transfer_mode = 0;
        op->command = (CMD55_APP_CMD << CMD_INDEX_SHIFT) | CMD_CCCE | CMD_CICE | CMD_RSP_48;
        op->argument = b->cmdres.R0->command & SDIOOp_CmdFlg_RCAMask;
        op->response = &b->cmdres.R1->response;
        op->block_size = 0;
        op->block_count = 0;
        op->total_length = 0;
        op->callback = NULL;
      }
      op = slot->op + i;
      if (++i == QUEUE_LENGTH)
        i = 0;
      slot->op_free = i;
      break;
    }
    spin_unlock(&slot->op_lock);
    if (b->r0.bits.bg)
    {
      spinrw_read_unlock(&g_sdhci_lock);
      return MESSAGE_ERRORLOOKUP(true, SDIO_QueueFull, 0);
    }
    _swix(OS_ReadMonotonicTime, _OUT(0), &now);
    if (now - timeout >= 0)
    {
      spinrw_read_unlock(&g_sdhci_lock);
      return MESSAGE_ERRORLOOKUP(true, SDIO_QueueTO, 0);
    }
  }
  while (true);

  /* Fill in the op block */
  op->state = CMD_STATE_READY;
  op->chk_r1 = b->r0.bits.chk_r1;
  op->chk_r5 = b->r0.bits.chk_r5;
  op->transfer_mode = (block_count > 1 ? TM_MSBS | TM_BCE : 0) |
                      (b->r0.bits.dir == (SDIOOp_TransRead >> SDIOOp_TransShift) ? TM_DDIR : 0) |
                      (b->cmdres.R0->command & SDIOOp_CmdFlg_AutoCMD12 ? TM_ACEN_CMD12 : 0);
  op->command = command;
  op->argument = b->cmdres.R0->argument;
  op->response = b->cmdres.R2->response;

  op->scatter_offset = 0;
  if (b->r0.bits.scatter)
    op->list = b->data.scatter;
  else
  {
    op->surrogate.address = b->data.block;
    op->surrogate.length = b->data_len;
    op->list = &op->surrogate;
  }

  op->block_size = block_size;
  op->block_count = block_count;
  op->total_length = total_length;

  volatile uintptr_t op_status = -1;
  volatile size_t    fg_not_transferred;
  if (b->r0.bits.bg)
  {
    op->callback = b->callback;
    op->callback_r5 = b->r5.callback_r5;
    op->callback_r12 = b->callback_r12;
  }
  else
  {
    extern void fgopcb(void);
    op->callback = fgopcb;
    op->callback_r5 = (void *) &fg_not_transferred;
    op->callback_r12 = (void *) &op_status;
  }

  spin_unlock(&slot->op_lock);

  /* Now either exit (for background ops) or block (for foreground ops) */
  if (b->r0.bits.bg)
  {
    b->r0.word = 0;
    b->r1.op_handle = op;
    spinrw_read_unlock(&g_sdhci_lock);
    return NULL;
  }
  else
  {
    while (op_status == -1)
    {
      bool timed_out = false;
      bool escape = false;
      _swix(OS_ReadMonotonicTime, _OUT(0), &now);
      timed_out = now - timeout >= 0;
      if (!b->r0.bits.no_escape)
      {
        uint32_t flags;
        _swix(OS_ReadEscapeState, _OUT(_FLAGS), &flags);
        if (flags & _C)
        {
          escape = true;
          _swix(OS_Byte, _IN(0), 124); /* clear escape condition */
        }
      }
      if (timed_out || escape)
      {
        swi_Control_abort_op(b->r0.bits.bus, sloti, op);
        do
        {
          op_poll(sdhci, sloti);
        } while (op_status == -1);
        b->r0.word = 0;
        b->data_len = fg_not_transferred;
        spinrw_read_unlock(&g_sdhci_lock);
        if (escape)
          return MESSAGE_ERRORLOOKUP(false, Escape, 0);
        else
          return MESSAGE_ERRORLOOKUP(true, SDIO_OpTO, 0);
      }

      op_poll(sdhci, sloti);
    }
    b->r0.word = 0;
    b->data_len = fg_not_transferred;
    spinrw_read_unlock(&g_sdhci_lock);
    return (_kernel_oserror *) op_status;
  }
}

_kernel_oserror *swi_ClaimDeviceVector(uint32_t bus, uint32_t slot, uint32_t unit, void *handler, void *pw)
{
  IGNORE(bus);
  IGNORE(slot);
  IGNORE(unit);
  IGNORE(handler);
  IGNORE(pw);
  return NULL;
}

_kernel_oserror *swi_ReleaseDeviceVector(uint32_t bus, uint32_t slot, uint32_t unit, void *handler, void *pw)
{
  IGNORE(bus);
  IGNORE(slot);
  IGNORE(unit);
  IGNORE(handler);
  IGNORE(pw);
  return NULL;
}
