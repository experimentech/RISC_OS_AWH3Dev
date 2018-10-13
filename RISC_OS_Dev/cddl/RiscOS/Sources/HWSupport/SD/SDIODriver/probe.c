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

/** \file probe.c
 * Probing the MMC/SD bus for devices and identifying their capabilities.
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "Global/HALEntries.h"
#include "Global/NewErrors.h"
#include "Interface/SDIO.h"

#include "globals.h"
#include "message.h"
#include "op.h"
#include "probe.h"
#include "register.h"
#include "swi.h"
#include "util.h"

#define CONTROLLER_RESET_TIMEOUT (1)     /* in cs */
#define CARD_INIT_TIMEOUT        (100)   /* in cs */
#define DATA_TIMEOUT             (500)   /* data line timeout, in ms */
#define POST_SWITCH_DELAY        (8 * 1000000 / 400) /* 8 clock cycles in us */
#define XPC_CURRENT_THRESHOLD    (150)   /* in mA */
#define FIRST_ASSIGNED_MMC_RCA   (2)     /* values 0 and 1 are special purpose */

/** Maximum time bus power is allowed to take to ramp up or down.
 *  MMC and SD agree this is 35 ms max ramp up, but nothing is said about ramp down so I'm assuming it's the same.
 */
#define BUS_POWER_RAMP (35000) /* in us */

/** Minimum time to leave bus at low power to force cards back to high-voltage, 1-bit state.
 *  MMC and SD agree this is 1 ms.
 */
#define BUS_RESET_TIME (1000)  /* in us */

/** Time to allow for card initialisation after power is applied.
 *  Technically, the longest of 1 ms, 74 clock cycles (?), supply ramp-up time (?) and, for MMC cards, the boot operation period.
 *  In practice, some cards (e.g. the C-Guys SDIO WLAN card) actually need far longer to power up, around 100 ms!
 */
#define BUS_INIT_TIME (100000)  /* in us */

#define GET_CMD6_BYTE(bit_index) ((uint32_t) buffer[(512-bit_index)/8-1]) /**< Macro to extract a byte from the CMD6 response. Note that the block is held in big-endian order */
#define GET_CMD8_BYTE(byte_index) ((uint32_t) buffer[byte_index]) /**< Macro to extract a byte from the CMD8 response. Note that the block is held in little-endian order */

static uint32_t set_sdclk(sdhcinode_t *sdhci, uint32_t sloti, uint32_t freq_khz)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdmmcslot_t         *slot = sdhci->slot + sloti;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &slot->wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  uint32_t sdclk;
  if (dev->SetSDCLK)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    sdclk = dev->SetSDCLK(dev, sloti, freq_khz);
  }
  else
  {
    while (1); /* TODO: generic SDHCI implementation */
  }

  /* Now we (at least for some platforms including OMAP and BCM2835) have to
   * recalculate the data timeout counter */
  uint32_t tmclk;
  if (dev->GetTMCLK)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    tmclk = dev->GetTMCLK(dev, sloti);
  }
  else
  {
    while (1); /* TODO: generic SDHCI implementation */
  }

  uint32_t counter = tmclk * DATA_TIMEOUT;
  uint32_t lg2_counter;
  __asm { CLZ lg2_counter, counter }
  lg2_counter = 32 - lg2_counter;
  if (lg2_counter < 13)
    lg2_counter = 13;
  if (lg2_counter > 27)
    lg2_counter = 27;
  REGISTER_WRITE(timeout_control, lg2_counter - 13);
  return sdclk;
}

static void set_vdd(sdhcinode_t *sdhci, uint32_t sloti, uint32_t ocr)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdmmcslot_t         *slot = sdhci->slot + sloti;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &slot->wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  slot->voltage = 0;
  if (ocr & OCR_1_7V_1_95V)
    slot->voltage = 1800;
  if (ocr & (OCR_2_9V_3_0V | OCR_3_0V_3_1V))
    slot->voltage = 3000;
  if (ocr & (OCR_3_2V_3_3V | OCR_3_3V_3_4V))
    slot->voltage = 3300;
  if (dev->SetVdd)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    dev->SetVdd(dev, sloti, slot->voltage);
  }
  else
  {
    /* Generic SDHCI implementation */
    uint32_t setting = 0;
    switch (slot->voltage)
    {
      case 1800: setting = PC_SDVS_1_8V; break;
      case 3000: setting = PC_SDVS_3_0V; break;
      case 3300: setting = PC_SDVS_3_3V; break;
    }
    REGISTER_WRITE(power_control, setting);
    setting |= PC_SDBP; /* has to be a separate write */
    REGISTER_WRITE(power_control, setting);
    register_flush_buffer(dev, sloti, wrbuf); /* we're about to wait, so ensure write has gone through */
    util_microdelay(BUS_POWER_RAMP);
  }
}

static uint32_t get_max_current(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdmmcslot_t         *slot = sdhci->slot + sloti;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &slot->wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  if (dev->GetMaxCurrent)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    return dev->GetMaxCurrent(dev, sloti);
  }
  else
  {
    /* Generic SDHCI implementation */
    uint32_t max_current_cap = REGISTER_READ(maximum_current_capabilities[0]);
    switch (REGISTER_READ(power_control) & PC_SDVS_MASK)
    {
      case PC_SDVS_3_3V: return ((max_current_cap & MCC_3_3V_MASK) >> MCC_3_3V_SHIFT) * 4;
      case PC_SDVS_3_0V: return ((max_current_cap & MCC_3_0V_MASK) >> MCC_3_0V_SHIFT) * 4;
      case PC_SDVS_1_8V: return ((max_current_cap & MCC_1_8V_MASK) >> MCC_1_8V_SHIFT) * 4;
    }
    return 0; /* shouldn't really get here, but compiler moans without */
  }
}

static _kernel_oserror *io_rw_direct(sdhcinode_t *sdhci, uint32_t sloti, bool write, uint32_t fun, uint32_t reg, uint8_t *data)
{
  _kernel_oserror *e;
  uint32_t argument = (write * IO_RW_WRITE) | (fun << IO_RW_FUNCTION_SHIFT) | (reg << IO_RW_REGISTER_SHIFT) | (write ? *data : 0);
  COMMAND_NO_DATA(sdhci->bus, sloti, CMD52_IO_RW_DIRECT, argument, R5sdio, io_rw_direct_blk, e);
  if (e == NULL && !write)
    *data = io_rw_direct_blk.response & R5_DATA_MASK;
  return e;
}

static _kernel_oserror *get_ocr(sdhcinode_t *sdhci, uint32_t sloti, uint32_t cmd, uint32_t extra_bits, uint32_t required_bits, uint32_t *ocr)
{
  _kernel_oserror *e;
  sdmmcslot_t *slot = sdhci->slot + sloti;

  COMMAND_NO_DATA(sdhci->bus, sloti, cmd, extra_bits, R3, send_op_cond_blk, e);
  if (e == NULL)
  {
    uint32_t combined_ocr = slot->controller_ocr & send_op_cond_blk.response;
    if (combined_ocr == 0)
    {
      dprintf("No common voltage between controller and card\n");
      *ocr = OCR_DONTCARE;
    }
    else if (required_bits != 0 && (send_op_cond_blk.response & required_bits) == 0)
    {
      /* This can only be the case for IO OCR */
      dprintf("No IO functions on this card, so not initialising\n");
      *ocr = send_op_cond_blk.response | OCR_DONTCARE;
    }
    else
    {
      /* Perform initialisation, polling for completion */
      int32_t timeout, now;
      _swix(OS_ReadMonotonicTime, _OUT(0), &now);
      timeout = now + CARD_INIT_TIMEOUT + 1;
      do
      {
        COMMAND_NO_DATA(sdhci->bus, sloti, cmd, combined_ocr | extra_bits, R3, send_op_cond_blk, e);
        if (e != NULL)
          break;
        if (send_op_cond_blk.response & OCR_NOT_BUSY)
        {
          /* Card finished initialising - OCR value will now be stable */
          *ocr = send_op_cond_blk.response;
          break;
        }
        _swix(OS_ReadMonotonicTime, _OUT(0), &now);
      }
      while (timeout - now > 0);
      if (timeout - now <= 0)
      {
        dprintf("Timed out waiting for init\n");
        *ocr = OCR_DONTCARE;
      }
    }
  }
  else
    *ocr = OCR_DONTCARE;
  return e;
}

static _kernel_oserror *select_deselect_card(sdhcinode_t *sdhci, uint32_t sloti, uint32_t rca, uint32_t *response)
{
  _kernel_oserror *e;
  if (rca == 0)
  {
    COMMAND_NO_DATA(sdhci->bus, sloti, CMD7_SELECT_DESELECT_CARD, 0, R0, deselect_card_blk, e);
  }
  else
  {
    COMMAND_NO_DATA(sdhci->bus, sloti, CMD7_SELECT_DESELECT_CARD, rca << 16, R1, select_card_blk, e);
    if (response != NULL)
      *response = select_card_blk.response;
  }
  return e;
}

static void set_bus_width(sdhcinode_t *sdhci, uint32_t sloti, uint32_t lines)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  if (dev->SetBusWidth)
  {
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    dev->SetBusWidth(dev, sloti, lines);
  }
  else
  {
    /* Generic SDHCI implementation */
    uint8_t hc1 = REGISTER_READ(host_control1);
    if (lines == 4)
      hc1 |= HC1_DTW;
    else
      hc1 &= ~HC1_DTW;
    if (lines == 8)
      hc1 |= HC1_EDTW;
    else
      hc1 &= ~HC1_EDTW;
    REGISTER_WRITE(host_control1, hc1);
  }
}

static _kernel_oserror *read_cis_tuple(sdhcinode_t *sdhci, uint32_t sloti, uint32_t function, uint32_t tuple_code, uint8_t *buffer, size_t bufsize)
{
  _kernel_oserror *e;
  uint32_t head = function == 0 ? CCCR_COMMON_CIS0 : FBR_CIS0(function);
  uint32_t pointer = 0;
  uint8_t byte, code, link;

  e = io_rw_direct(sdhci, sloti, false, 0, head, &byte);
  if (e != NULL)
    return e;
  pointer |= byte;
  e = io_rw_direct(sdhci, sloti, false, 0, head + 1, &byte);
  if (e != NULL)
    return e;
  pointer |= (uint32_t) byte << 8;
  e = io_rw_direct(sdhci, sloti, false, 0, head + 2, &byte);
  if (e != NULL)
    return e;
  pointer |= (uint32_t) byte << 16;

  do
  {
    uint32_t next_pointer = 0;
    bool bad_pointer = pointer < CIS_BASE || pointer >= CIS_LIMIT;
    if (!bad_pointer)
    {
      e = io_rw_direct(sdhci, sloti, false, 0, pointer, &code);
      if (e != NULL)
        return e;
    }
    if (code == CISTPL_NULL || code == CISTPL_END)
      next_pointer = pointer + 1;
    else
    {
      if (pointer + 1 == CIS_LIMIT)
        bad_pointer = true;
      if (!bad_pointer)
      {
        e = io_rw_direct(sdhci, sloti, false, 0, pointer + 1, &link);
        if (e != NULL)
          return e;
        next_pointer = pointer + 2 + link;
      }
    }
    if (next_pointer > CIS_LIMIT)
      bad_pointer = true;
    if (bad_pointer)
    {
      char str_pointer[6];
      sprintf(str_pointer, "%05X", pointer);
      return MESSAGE_ERRORLOOKUP(true, SDIO_BadCIS, str_pointer);
    }
    dprintf("%05X -> tuple %02X\n", pointer, code);
    if (code == tuple_code)
    {
      for (size_t index = 0; pointer + 2 + index < next_pointer && index < bufsize; index++)
      {
        e = io_rw_direct(sdhci, sloti, false, 0, pointer + 2 + index, buffer + index);
        if (e != NULL)
          return e;
      }
      return NULL;
    }
    pointer = next_pointer;
  }
  while (code != CISTPL_END && link != 0xFF);

  return MESSAGE_ERRORLOOKUP(true, SDIO_NoTuple, 0);
}

#define ABORT_PROBE(...)       \
  do                           \
  {                            \
    dprintf(__VA_ARGS__);      \
    return false;              \
  }                            \
  while (0)

static bool resolve_voltage(sdhcinode_t *sdhci, uint32_t sloti, bool supports_CMD8)
{
  _kernel_oserror *e;
  sdmmcslot_t     *slot = sdhci->slot + sloti;
  
  /* Try a CMD5 to identify an SDIO card (some SD cards will also respond).
   * A special argument of 0 seems to be used to merely query the card capabilities.
   * While in idle state, any MMC card(s) should ignore anything except CMD1.
   */
  e = get_ocr(sdhci, sloti, CMD5_IO_SEND_OP_COND, OCR_S18R, OCR_NFUNCTIONS_MASK, &slot->io_ocr);
  if (e == NULL)
  {
    if (!(slot->io_ocr & OCR_MP))
      slot->memory_type = MEMORY_NONE;
    slot->io_functions = (slot->io_ocr & OCR_NFUNCTIONS_MASK) >> OCR_NFUNCTIONS_SHIFT;
    dprintf("Good response to CMD5: %u memory and %u IO functions, OCR=%06X, S18A=%u\n",
        slot->memory_type != MEMORY_NONE,
        slot->io_functions,
        slot->io_ocr & 0xFFFFFF,
        !!(slot->io_ocr & OCR_S18A));
  }
  else
  {
    if (e->errnum != ErrorNumber_SDIO_CTO)
      ABORT_PROBE("IO_SEND_OP_COND returned %s\n", e->errmess);
    dprintf("No response to CMD5\n");
  }

  if (slot->memory_type != MEMORY_NONE)
  {
    /* Try ACMD41 to distinguish v2+ SD memory cards from MMC cards and v1 SD cards.
     * While in idle state, any MMC card(s) should ignore anything except CMD1.
     */
    bool xpc_flag = get_max_current(sdhci, sloti) > XPC_CURRENT_THRESHOLD;
    e = get_ocr(sdhci, sloti, ACMD41_SD_SEND_OP_COND, supports_CMD8 ? OCR_HCS | xpc_flag * OCR_XPC | OCR_S18R : 0, 0, &slot->memory_ocr);
    if (e == NULL)
    {
      slot->memory_type = (supports_CMD8 && (slot->memory_ocr & OCR_CCS)) ? MEMORY_SDHC_SDXC : MEMORY_SD;
      dprintf("Good response to ACMD41: OCR=%06X, CCS=%u, S18A=%u\n",
          slot->memory_ocr & 0xFFFFFF,
          !!(slot->memory_ocr & OCR_CCS),
          !!(slot->memory_ocr & OCR_S18A));
    }
    else
    {
      if (e->errnum != ErrorNumber_SDIO_CTO)
        ABORT_PROBE("SD_SEND_OP_COND returned %s\n", e->errmess);
      dprintf("No response to ACMD41\n");

      /* If we get here, it probably means we have an MMC card.
       * Try CMD1 to get the wired-AND combined OCR of all MMC cards.
       */
      e = get_ocr(sdhci, sloti, CMD1_SEND_OP_COND, OCR_HCS, 0, &slot->memory_ocr);
      if (e != NULL)
        ABORT_PROBE("SEND_OP_COND returned %s\n", e->errmess);
      slot->memory_type = MEMORY_MMC;
      dprintf("Good response to CMD1: OCR=%06X, S18A=%u\n",
          slot->memory_ocr & 0xFFFFFF,
          !!(slot->memory_ocr & OCR_CCS));
    }
  }

  /* TODO: to support dual-voltage supply cards, at this point we would evaluate
   * whether we can set both the controller and card to 1.8V or even (for MMC)
   * 1.2V, and go back and repeat the above (starting from power-cycling the
   * card) at the lower voltage. However, I have been unable to find any such
   * cards in practice, so for now we'll just leave it at 3V (or whatever the
   * highest voltage the controller can supply is).
   */

  /* TODO: For SD and SDIO cards which return S18A in the OCR, at this point we
   * should switch the signalling voltage (i.e. excluding not the supply voltage)
   * to 1.8V, which involves issuing CMD11 to the card. This is mandatory to
   * enable the various high-clock-speed and DDR schemes used in UHS. However
   * the OMAP controller does not support this, so it seems premature to
   * implement it yet.
   */

  return true;
}

static bool resolve_addresses(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdmmcslot_t     *slot = sdhci->slot + sloti;
  
  /* Read the CID and discover (for SD cards) or assign (for MMC cards) the RCA */
  if (slot->memory_type != MEMORY_NONE)
  {
    uint32_t card = 0;
    do
    {
      COMMAND_NO_DATA(sdhci->bus, sloti, CMD2_ALL_SEND_CID, 0, R2, all_send_cid_blk, e);
      if (slot->memory_type == MEMORY_MMC && card != 0 && e && e->errnum == ErrorNumber_SDIO_CTO)
        break; /* finished enumerating the cards in this slot */
      if (e != NULL)
        ABORT_PROBE("ALL_SEND_CID returned %s\n", e->errmess);
      memcpy(&slot->card[card].cid, all_send_cid_blk.response, 15);

      uint16_t rca;
      if (slot->memory_type == MEMORY_MMC)
      {
        /* TODO: will need a more advanced RCA allocation strategy to support
         * multi-MMC card buses with hot-swappable cards, to ensure cards that
         * aren't removed retain the same RCA. */
        rca = FIRST_ASSIGNED_MMC_RCA + card;
        COMMAND_NO_DATA(sdhci->bus, sloti, CMD3_SET_RELATIVE_ADDR, rca << 16, R1, set_relative_addr_blk, e);
        if (e && e->errnum == ErrorNumber_SDIO_DevE22)
        {
          /* A bug in some MMC cards causes them to return Device error - Illegal command
           * when the RCA has in fact been set successfully. Check if this is the case,
           * and if so then swallow the error. */
          _kernel_oserror *e2;
          COMMAND_NO_DATA(sdhci->bus, sloti, CMD13_SEND_STATUS, rca << 16, R1, send_status_blk, e2);
          if (e2 == NULL)
          {
            dprintf("Ignoring illegal command error reported by CMD3\n");
            e = NULL;
          }
        }
        if (e != NULL)
          ABORT_PROBE("SET_RELATIVE_ADDR returned %s\n", e->errmess);
      }
      else
      {
        COMMAND_NO_DATA(sdhci->bus, sloti, CMD3_SEND_RELATIVE_ADDR, 0, R6, send_relative_addr_blk, e);
        rca = send_relative_addr_blk.response >> 16;
        if (e != NULL)
          ABORT_PROBE("SEND_RELATIVE_ADDR returned %s\n", e->errmess);
      }
      if (card < MAX_CARDS_PER_SLOT)
      {
        slot->card[card].in_use = true;
        slot->card[card].rca = rca;
      }
      dprintf("Card RCA = %04X\n", rca);
      ++card;
    }
    while (slot->memory_type == MEMORY_MMC);
  }
  else
  {
    /* IO-only card */
    slot->card[0].in_use = true;
    memset(&slot->card[0].cid, 0, 15); /* I/O-only cards don't have a CID register */
    COMMAND_NO_DATA(sdhci->bus, sloti, CMD3_SEND_RELATIVE_ADDR, 0, R6, send_relative_addr_blk, e);
    slot->card[0].rca = send_relative_addr_blk.response >> 16;
    if (e != NULL)
      ABORT_PROBE("SEND_RELATIVE_ADDR returned %s\n", e->errmess);
  }

  return true;
}

static bool read_csd(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdmmcslot_t     *slot = sdhci->slot + sloti;

  if (slot->memory_type != MEMORY_NONE)
  {
    for (uint32_t card = 0; card < MAX_CARDS_PER_SLOT; card++)
      if (slot->card[card].in_use)
      {
        /* Read the CSD register from the card. This should work even if the card is locked. */
        /* Unlike most other commands, CMD9 must be issued from stby state, so there is no need to select it first. */
        COMMAND_NO_DATA(sdhci->bus, sloti, CMD9_SEND_CSD, slot->card[card].rca << 16, R2, send_csd_blk, e);
        if (e != NULL)
          ABORT_PROBE("SEND_CSD returned %s\n", e->errmess);
        memcpy(&slot->card[card].csd, send_csd_blk.response, 15);
      }
  }

  return true;
}

static bool read_scr(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdmmcslot_t     *slot = sdhci->slot + sloti;

  slot->scr_valid = false;
  if (slot->memory_type != MEMORY_NONE && slot->memory_type != MEMORY_MMC)
  {
    uint32_t select_card_response;
    e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
    if (e != NULL)
      ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
    if ((select_card_response & R1_CARD_IS_LOCKED) == 0)
    {
      uint8_t bigendian_scr[8];
      COMMAND_DATA(sdhci->bus, sloti,
          ACMD51_SEND_SCR | (3 << SDIOOp_CmdFlg_BlockSplitShift) | (slot->card[0].rca << SDIOOp_CmdFlg_RCAShift),
          0, R1, send_scr_blk, Read, bigendian_scr, 8, e);
      if (e != NULL)
      {
        dprintf("SEND_SCR returned %s\n", e->errmess);
      }
      else
      {
        slot->scr_valid = true;
        /* The SCR arrives in big-endian order. Reverse this for consistency
         * with the way the controller reverses the CID and CSD registers that
         * arrive in R2 responses rather than on the data lines. */
        for (size_t i = 0; i < 8; i++)
          slot->scr[i] = bigendian_scr[7-i];
        dprintf("SD_SPEC=%d\n", cardreg_read_int(slot->scr, SCR_SD_SPEC));
        dprintf("SD_SPEC3=%d\n", cardreg_read_int(slot->scr, SCR_SD_SPEC3));
        dprintf("SD_BUS_WIDTHS=%d\n", cardreg_read_int(slot->scr, SCR_SD_BUS_WIDTHS));
        dprintf("CMD_SUPPORT=%d\n", cardreg_read_int(slot->scr, SCR_CMD_SUPPORT));
      }
    }
    e = select_deselect_card(sdhci, sloti, 0, NULL);
    if (e != NULL)
      ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
  }
  return true;
}

static bool resolve_bus_width(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdhcidevice_t   *dev = sdhci->dev;
  sdmmcslot_t     *slot = sdhci->slot + sloti;
  uint32_t         select_card_response;
  
  /* Determine the best available bus width and configure it in controller and card. */
  switch (dev->slotinfo[sloti].flags & HALDeviceSDHCI_SlotFlag_BusMask)
  {
    case HALDeviceSDHCI_SlotFlag_Bus8Bit: slot->lines = 8; break;
    case HALDeviceSDHCI_SlotFlag_Bus4Bit: slot->lines = 4; break;
    default:                              slot->lines = 1; break;
  }
  if (slot->memory_type == MEMORY_MMC)
  {
    do
    {
      if (slot->lines != 2)
      {
        bool supported = true;
        dprintf("Trying MMC bus width %u\n", slot->lines);
        /* Prepare for bus test */
        static const uint32_t snd8[2] = { 0xAA55 }, snd4 = 0x5A, snd1 = 0x80;
        const uint32_t *snd_pattern;
        uint32_t rcv_pattern[2], rcv_expected, rcv_mask;
        switch (slot->lines)
        {
          case 8:  snd_pattern = snd8;  rcv_expected = 0x55AA; rcv_mask = 0xFFFF; break;
          case 4:  snd_pattern = &snd4; rcv_expected = 0xA5;   rcv_mask = 0xFF;   break;
          default: snd_pattern = &snd1; rcv_expected = 0x40;   rcv_mask = 0xC0;   break;
        }
        set_bus_width(sdhci, sloti, slot->lines);
        for (uint32_t cardi = 0; supported && cardi < MAX_CARDS_PER_SLOT; cardi++)
        {
          if (slot->card[cardi].in_use)
          {
            bool card_selected = false;
            bool one_bit_card = false;
            uint32_t mmc_vers = cardreg_read_int(slot->card[cardi].csd, CSD_SPEC_VERS);
            dprintf("MMC card version index = %d\n", mmc_vers);
            /* Cards with mmc_vers = 4 have an Extended CSD register and support
             * CMD6 and CMD8. Cards with mmc_vers = 3 do not, and will stop
             * responding if those commands are used. */
            if (mmc_vers < CSD_SPEC_VERS_4_1_4_3)
            {
              /* These cards do not have enough pins to support anything but 1-bit mode */
              one_bit_card = true;
            }
            else
            {
              /* Select the card. This is required before CMD6 anyway, but also
               * lets us detect locked cards, which must remain in 1-bit mode. */
              e = select_deselect_card(sdhci, sloti, slot->card[cardi].rca, &select_card_response);
              if (e != NULL)
                ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
              card_selected = true;
              if (select_card_response & R1_CARD_IS_LOCKED)
                one_bit_card = true;
            }
            if (one_bit_card)
            {
              if (slot->lines > 1)
              {
                slot->lines = 2; /* so all cards are set to 1-bit next time round */
                supported = false;
                break;
              }
            }
            else
            {
              uint32_t arg;
              switch (slot->lines)
              {
                case 8:  arg = EXT_CSD_BUS_WIDTH_8BIT_SDR << SWITCH_VALUE_SHIFT; break;
                case 4:  arg = EXT_CSD_BUS_WIDTH_4BIT_SDR << SWITCH_VALUE_SHIFT; break;
                default: arg = EXT_CSD_BUS_WIDTH_1BIT_SDR << SWITCH_VALUE_SHIFT; break;
              }
              arg |= SWITCH_ACCESS_WRITE_BYTE | (EXT_CSD_BUS_WIDTH << SWITCH_INDEX_SHIFT);
              COMMAND_NO_DATA(sdhci->bus, sloti, CMD6_SWITCH, arg, R1b, switch_blk, e);
              if (e != NULL)
                dprintf("SWITCH returned %s\n", e->errmess);
              if (e == NULL)
              {
                /* Need to use SEND_STATUS here to pick up any errors generated during switch */
                COMMAND_NO_DATA(sdhci->bus, sloti, CMD13_SEND_STATUS, slot->card[cardi].rca << 16, R1, send_status_blk, e);
                if (e != NULL)
                  dprintf("Post-SWITCH SEND_STATUS returned %s\n", e->errmess);
              }
              if (e == NULL)
              {
                COMMAND_DATA(sdhci->bus, sloti, CMD19_BUSTEST_W | (3 << SDIOOp_CmdFlg_BlockSplitShift), 0, R1, bustest_w_blk, Write, (void *) snd_pattern, slot->lines, e);
                if (e && e->errnum == ErrorNumber_SDIO_DTO)
                {
                  dprintf("Ignoring data timeout error reported by CMD19\n");
                  e = NULL;
                }
                if (e != NULL)
                  dprintf("BUSTEST_W returned %s\n", e->errmess);
              }
              if (e == NULL)
              {
                COMMAND_DATA(sdhci->bus, sloti, CMD14_BUSTEST_R | (3 << SDIOOp_CmdFlg_BlockSplitShift), 0, R1, bustest_r_blk, Read, (void *) rcv_pattern, slot->lines, e);
                if (e != NULL)
                  ABORT_PROBE("BUSTEST_R returned %s\n", e->errmess);
              }
              if (e == NULL)
              {
                for (int pass = 0; pass < 2; pass++)
                {
                  const uint32_t *data = pass ? rcv_pattern : snd_pattern;
                  (void) data;
                  dprintf("%s = ", pass ? "Data received" : "Data sent    ");
                  switch (slot->lines)
                  {
                    case 8:  dprintf("%08X %08X\n", data[0], data[1]); break;
                    case 4:  dprintf("%08X\n", data[0]); break;
                    default: dprintf("%02X\n", data[0]); break;
                  }
                }
                rcv_pattern[0] &= rcv_mask;
                if (rcv_pattern[0] != rcv_expected)
                {
                  dprintf("Bus test FAILED!\n");
                  supported = false;
                }
                else
                  dprintf("Bus test successful\n");
              }
              else
                supported = false;
            }
            if (card_selected)
            {
              e = select_deselect_card(sdhci, sloti, 0, NULL);
              if (e != NULL)
                ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
            }
          }
        }
        if (supported)
          break;
      }
      slot->lines >>= 1;
    }
    while (slot->lines != 0);
    if (slot->lines == 0)
      ABORT_PROBE("MMC bus width determination failed\n");
  }
  else
  {
    /* SD, IO-only or combo card case */
    slot->lines = MIN(slot->lines, 4);
    e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
    if (e != NULL)
      ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
    if (select_card_response & R1_CARD_IS_LOCKED)
    {
      slot->lines = 1;
      /* The only command it is sensible for the user to issue in this state is
       * CMD42_LOCK_UNLOCK, and that has to be issued in 1-bit mode. We can't
       * select a wider bus, and we can't query the card to find out whether
       * higher clock speeds (than the basic one given in the CSD) are available. */
    }
    else
    {
      if (slot->io_functions > 0)
      {
        uint8_t card_capability;
        e = io_rw_direct(sdhci, sloti, false, 0, CCCR_CARD_CAPABILITY, &card_capability);
        if (e != NULL)
          ABORT_PROBE("Read of CARD_CAPABILITY returned %s\n", e->errmess);
        if ((card_capability & 0xC0) != 0xC0 && (card_capability & 0xC0) != 0)
          slot->lines = 1; /* low-speed card that does not support 4-bit bus */
      }
      if (slot->memory_type != MEMORY_NONE)
      {
        if (!slot->scr_valid || (cardreg_read_int(slot->scr, SCR_SD_BUS_WIDTHS) & SCR_SD_BUS_WIDTH_4) == 0)
          slot->lines = 1;
      }
      if (slot->io_functions > 0)
      {
        uint8_t bus_interface_control;
        e = io_rw_direct(sdhci, sloti, false, 0, CCCR_BUS_INTERFACE_CONTROL, &bus_interface_control);
        if (e != NULL)
          ABORT_PROBE("Read of BUS_INTERFACE_CONTROL returned %s\n", e->errmess);
        bus_interface_control = bus_interface_control &~ 3 | (slot->lines == 4 ? 2 : 0) | 0x80;
        e = io_rw_direct(sdhci, sloti, true, 0, CCCR_BUS_INTERFACE_CONTROL, &bus_interface_control);
        if (e != NULL)
          ABORT_PROBE("Write of BUS_INTERFACE_CONTROL returned %s\n", e->errmess);
      }
      if (slot->memory_type != MEMORY_NONE)
      {
        COMMAND_NO_DATA(sdhci->bus, sloti, ACMD42_SET_CLR_CARD_DETECT | (slot->card[0].rca << 16), 0, R1, set_clr_card_detect_blk, e);
        if (e != NULL)
          ABORT_PROBE("CLR_CARD_DETECT returned %s\n", e->errmess);
        COMMAND_NO_DATA(sdhci->bus, sloti, ACMD6_SET_BUS_WIDTH | (slot->card[0].rca << 16), slot->lines == 4 ? 2 : 0, R1, set_bus_width_blk, e);
        if (e != NULL)
          ABORT_PROBE("SET_BUS_WIDTH returned %s\n", e->errmess);
      }
    }
    e = select_deselect_card(sdhci, sloti, 0, NULL);
    if (e != NULL)
      ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
  }
  set_bus_width(sdhci, sloti, slot->lines);
  return true;
}

static bool lookup_tran_speed(uint32_t tran_speed, bool is_mmc, uint32_t *frequency)
{
  const uint16_t *freq_lut = is_mmc
      ? (const uint16_t[16]) { 0, 100, 120, 130, 150, 200, 260, 300, 350, 400, 450, 520, 550, 600, 700, 800 }
      : (const uint16_t[16]) { 0, 100, 120, 130, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 700, 800 };
  *frequency = freq_lut[(tran_speed >> 3) & 0xF];
  *frequency *= (const uint32_t [4]) { 1, 10, 100, 1000 } [tran_speed & 0x3];
  if (*frequency == 0 || (tran_speed & 0x84) != 0)
    ABORT_PROBE("Invalid TRAN_SPEED\n");
  return true;
}

static bool resolve_bus_speed(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdmmcslot_t     *slot = sdhci->slot + sloti;
  struct
  {
    bool mmc_26:     1; /* MMC         (26 MHz) */
    bool mmc_52:     1; /* MMC HS      (52 MHz) */
    bool mmc_52_ddr: 1; /* MMC HS DDR  (52 MHz) */
    bool mmc_200:    1; /* MMC HS200  (200 MHz) */
    bool sd_50:      1; /* SD  SDR25   (50 MHz) */
    bool sd_50_ddr:  1; /* SD  DDR50   (50 MHz) */
    bool sd_100:     1; /* SD  SDR50  (100 MHz) */
    bool sd_208:     1; /* SD  SDR104 (208 MHz) */
  } supported = { false };
  slot->freq = -1u;

  /* Discount anything not supported by the controller */
  supported.mmc_26 = true;
  supported.sd_50 = slot->caps[0] & CAP0_HSS;
  supported.mmc_52 = slot->caps[0] & CAP0_HSS;
  dprintf("Controller %s 50/52 MHz operation\n", supported.sd_50 ? "supports" : "doesn't support");
  supported.sd_50_ddr = slot->caps[1] & CAP1_DDR50S;
  supported.mmc_52_ddr = slot->caps[1] & CAP1_DDR50S;
  dprintf("Controller %s 50/52 MHz DDR operation\n", supported.sd_50_ddr ? "supports" : "doesn't support");
  supported.sd_100 = slot->caps[1] & CAP1_SDR50S;
  dprintf("Controller %s 100 MHz operation\n", supported.sd_100 ? "supports" : "doesn't support");
  supported.mmc_200 = slot->caps[1] & CAP1_SDR104S;
  supported.sd_208 = slot->caps[1] & CAP1_SDR104S;
  dprintf("Controller %s 200/208 MHz operation\n", supported.sd_208 ? "supports" : "doesn't support");

  if (slot->memory_type == MEMORY_MMC)
  {
    /* Determine whether high speed modes are supported by MMC cards */
    uint32_t common_type = -1u;
    for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
    {
      if (slot->card[cardi].in_use)
      {
        bool card_selected = false;
        bool standard_speed_card = false;
        uint32_t mmc_vers = cardreg_read_int(slot->card[cardi].csd, CSD_SPEC_VERS);
        /* Cards with mmc_vers = 4 have an Extended CSD register and support
         * CMD6 and CMD8. Cards with mmc_vers = 3 do not, and will stop
         * responding if those commands are used. */
        if (mmc_vers < CSD_SPEC_VERS_4_1_4_3)
        {
          standard_speed_card = true;
        }
        else
        {
          /* Select the card. This is required before CMD6 anyway, but also
           * lets us detect locked cards, which must remain in standard speed. */
          uint32_t select_card_response;
          e = select_deselect_card(sdhci, sloti, slot->card[cardi].rca, &select_card_response);
          if (e != NULL)
            ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
          card_selected = true;
          if (select_card_response & R1_CARD_IS_LOCKED)
            standard_speed_card = true;
        }
        if (standard_speed_card)
        {
          common_type = 0;
        }
        else
        {
          uint8_t buffer[512];
          uint8_t device_type;
          COMMAND_DATA(sdhci->bus, sloti, CMD8_SEND_EXT_CSD | (9 << SDIOOp_CmdFlg_BlockSplitShift), 0, R1, send_ext_csd_blk, Read, buffer, sizeof buffer, e);
          if (e != NULL)
            ABORT_PROBE("SEND_EXT_CSD returned %s\n", e->errmess);
          device_type = GET_CMD8_BYTE(EXT_CSD_DEVICE_TYPE);
          dprintf("MMC card with RCA %04X reports DEVICE_TYPE %02X\n", slot->card[cardi].rca, device_type);
          common_type &= device_type;
        }
        if (card_selected)
        {
          e = select_deselect_card(sdhci, sloti, 0, NULL);
          if (e != NULL)
            ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
        }
      }
    }
    if ((common_type & EXT_CSD_DEVICE_TYPE_HS200_1_8) == 0)
      supported.mmc_200 = false;
    if ((common_type & EXT_CSD_DEVICE_TYPE_HSDDR_1_8_3) == 0)
      supported.mmc_52_ddr = false;
    if ((common_type & EXT_CSD_DEVICE_TYPE_HS) == 0)
      supported.mmc_52 = false;
    if ((common_type & EXT_CSD_DEVICE_TYPE_STD) == 0)
      supported.mmc_26 = false;

    if (supported.mmc_52 || supported.mmc_52_ddr || supported.mmc_200)
    {
      /* Set high speed mode in MMC cards */
      for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
      {
        if (slot->card[cardi].in_use)
        {
          e = select_deselect_card(sdhci, sloti, slot->card[cardi].rca, NULL);
          if (e != NULL)
            ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
          uint32_t arg = supported.mmc_200 ? EXT_CSD_HS_TIMING_TI_HS200 : EXT_CSD_HS_TIMING_TI_HS;
          arg = SWITCH_ACCESS_WRITE_BYTE | (EXT_CSD_HS_TIMING << SWITCH_INDEX_SHIFT) | (arg << SWITCH_VALUE_SHIFT);
          COMMAND_NO_DATA(sdhci->bus, sloti, CMD6_SWITCH, arg, R1b, switch_blk, e);
          if (e != NULL)
            ABORT_PROBE("SWITCH (HS_TIMING) returned %s\n", e->errmess);
          /* Need to use SEND_STATUS here to pick up any errors generated during switch */
          COMMAND_NO_DATA(sdhci->bus, sloti, CMD13_SEND_STATUS, slot->card[cardi].rca << 16, R1, send_status_blk, e);
          if (e != NULL)
            ABORT_PROBE("SEND_STATUS (HS_TIMING) returned %s\n", e->errmess);
          if (!supported.mmc_200 && supported.mmc_52_ddr && slot->lines > 1)
          {
            arg = slot->lines == 8 ? EXT_CSD_BUS_WIDTH_8BIT_DDR : EXT_CSD_BUS_WIDTH_4BIT_DDR;
            arg = SWITCH_ACCESS_WRITE_BYTE | (EXT_CSD_BUS_WIDTH << SWITCH_INDEX_SHIFT) | (arg << SWITCH_VALUE_SHIFT);
            COMMAND_NO_DATA(sdhci->bus, sloti, CMD6_SWITCH, arg, R1b, switch_blk, e);
            if (e != NULL)
              ABORT_PROBE("SWITCH (DDR) returned %s\n", e->errmess);
            /* Need to use SEND_STATUS here to pick up any errors generated during switch */
            COMMAND_NO_DATA(sdhci->bus, sloti, CMD13_SEND_STATUS, slot->card[cardi].rca << 16, R1, send_status_blk, e);
            if (e != NULL)
              ABORT_PROBE("SEND_STATUS (DDR) returned %s\n", e->errmess);
          }
          e = select_deselect_card(sdhci, sloti, 0, NULL);
          if (e != NULL)
            ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
        }
      }
    }

    /* Read supported frequency for MMC cards */
    if (supported.mmc_200)
      slot->freq = 200000;
    else if (supported.mmc_52 || supported.mmc_52_ddr)
      slot->freq = 52000;
    else if (supported.mmc_26)
      slot->freq = 26000;
    else
    {
      /* For MMC cards, unlike SD cards, TRAN_SPEED only applies to standard speed mode */
      for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
      {
        if (slot->card[cardi].in_use)
        {
          uint32_t csd_freq;
          if (!lookup_tran_speed(cardreg_read_int(slot->card[cardi].csd, CSD_TRAN_SPEED), true, &csd_freq))
            return false;
          dprintf("MMC card with RCA %04X reports TRAN_SPEED = %u kHz\n", slot->card[cardi].rca, csd_freq);
          slot->freq = MIN(slot->freq, csd_freq);
        }
      }
    }
  }

  else
  {
    if (slot->io_functions > 0)
    {
      /* Determine whether high speed modes are supported by SDIO functions */
      uint32_t select_card_response;
      e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
      if (e != NULL)
        ABORT_PROBE("SELECT_CARD returned %s\n", e->errmess);
      if (select_card_response & R1_CARD_IS_LOCKED)
      {
        dprintf("Card is locked, so using default speed mode\n");
        supported.sd_50 = false;
        supported.sd_50_ddr = false;
        supported.sd_100 = false;
        supported.sd_208 = false;
      }
      else
      {
        uint8_t bus_speed_select, uhs_i_support;
        e = io_rw_direct(sdhci, sloti, false, 0, CCCR_BUS_SPEED_SELECT, &bus_speed_select);
        if (e != NULL)
          ABORT_PROBE("IO_RW_DIRECT returned %s\n", e->errmess);
        e = io_rw_direct(sdhci, sloti, false, 0, CCCR_UHS_I_SUPPORT, &uhs_i_support);
        if (e != NULL)
          ABORT_PROBE("IO_RW_DIRECT returned %s\n", e->errmess);
        if ((bus_speed_select & CCCR_SHS) == 0)
        {
          dprintf("IO card doesn't support high speed operation\n");
          supported.sd_50 = false;
        }
        if ((uhs_i_support & CCCR_SDDR50) == 0)
        {
          dprintf("IO card doesn't support DDR50 operation\n");
          supported.sd_50_ddr = false;
        }
        if ((uhs_i_support & CCCR_SSDR50) == 0)
        {
          dprintf("IO card doesn't support SDR50 operation\n");
          supported.sd_100 = false;
        }
        if ((uhs_i_support & CCCR_SSDR104) == 0)
        {
          dprintf("IO card doesn't support SDR104 operation\n");
          supported.sd_208 = false;
        }
      }
      e = select_deselect_card(sdhci, sloti, 0, NULL);
      if (e != NULL)
        ABORT_PROBE("SELECT_CARD returned %s\n", e->errmess);
    }
    if (slot->memory_type != MEMORY_NONE)
    {
      /* Determine whether high speed modes are supported by SD card, or by
       * the memory portion of an SDIO combo card */
      bool cmd6_supported;
      if (slot->scr_valid)
      {
        cmd6_supported = cardreg_read_int(slot->scr, SCR_SD_SPEC) != 0;
        dprintf("SCR says %snew enough to support CMD6\n", cmd6_supported ? "" : "not ");
      }
      else
      {
        cmd6_supported = cardreg_read_int(slot->card[0].csd, CSD_CCC) & (1u<<10);
        dprintf("CSD_CCC says %snew enough to support CMD6\n", cmd6_supported ? "" : "not ");
      }

      if (!cmd6_supported)
      {
        supported.sd_50 = false;
        supported.sd_50_ddr = false;
        supported.sd_100 = false;
        supported.sd_208 = false;
      }
      else
      {
        uint32_t select_card_response;
        e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
        if (e != NULL)
          ABORT_PROBE("SELECT_CARD returned %s\n", e->errmess);
        if (select_card_response & R1_CARD_IS_LOCKED)
        {
          dprintf("Card is locked, so using default speed mode\n");
          supported.sd_50 = false;
          supported.sd_50_ddr = false;
          supported.sd_100 = false;
          supported.sd_208 = false;
        }
        else
        {
          uint8_t buffer[64];
          COMMAND_DATA(sdhci->bus, sloti, CMD6_SWITCH_FUNC | (9 << SDIOOp_CmdFlg_BlockSplitShift), SWITCH_FUNC_MODE_CHECK | 0xFFFFFFu, R1, switch_func_blk, Read, buffer, sizeof buffer, e);
          if (e != NULL)
            ABORT_PROBE("SWITCH_FUNC returned %s\n", e->errmess);
          uint16_t function_group_1_info = (GET_CMD6_BYTE(SWITCH_FUNC_FG1INFO1_BYTE) << 8) | GET_CMD6_BYTE(SWITCH_FUNC_FG1INFO0_BYTE);
          if (((ACCESS_MODE_BIT_SDR12 | ACCESS_MODE_BIT_NO_CHANGE) &~ function_group_1_info) != 0)
            ABORT_PROBE("Invalid block returned by SWITCH_FUNC\n");
          if ((function_group_1_info & ACCESS_MODE_BIT_SDR25) == 0)
          {
            dprintf("Memory card doesn't support high speed operation\n");
            supported.sd_50 = false;
          }
          if ((function_group_1_info & ACCESS_MODE_BIT_DDR50) == 0)
          {
            dprintf("Memory card doesn't support DDR50 operation\n");
            supported.sd_50_ddr = false;
          }
          if ((function_group_1_info & ACCESS_MODE_BIT_SDR50) == 0)
          {
            dprintf("Memory card doesn't support SDR50 operation\n");
            supported.sd_100 = false;
          }
          if ((function_group_1_info & ACCESS_MODE_BIT_SDR104) == 0)
          {
            dprintf("Memory card doesn't support SDR104 operation\n");
            supported.sd_208 = false;
          }
        }
        e = select_deselect_card(sdhci, sloti, 0, NULL);
        if (e != NULL)
          ABORT_PROBE("SELECT_CARD returned %s\n", e->errmess);
      }
    }

    if (supported.sd_50 || supported.sd_50_ddr || supported.sd_100 || supported.sd_208)
    {
      uint32_t access_mode;
      if (supported.sd_208)          access_mode = ACCESS_MODE_SDR104;
      else if (supported.sd_100)     access_mode = ACCESS_MODE_SDR50;
      else if (supported.sd_50_ddr) access_mode = ACCESS_MODE_DDR50;
      else                       access_mode = ACCESS_MODE_SDR25;
      if (slot->io_functions > 0)
      {
        /* Set high speed mode in SDIO card */
        uint32_t select_card_response;
        e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
        if (e != NULL)
          ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
        uint8_t bus_speed_select;
        e = io_rw_direct(sdhci, sloti, false, 0, CCCR_BUS_SPEED_SELECT, &bus_speed_select);
        if (e != NULL)
          ABORT_PROBE("IO_RW_DIRECT returned %s\n", e->errmess);
        bus_speed_select = bus_speed_select &~ CCCR_BSS_MASK | (access_mode << CCCR_BSS_SHIFT);
        e = io_rw_direct(sdhci, sloti, true, 0, CCCR_BUS_SPEED_SELECT, &bus_speed_select);
        if (e != NULL)
          ABORT_PROBE("IO_RW_DIRECT returned %s\n", e->errmess);
        /* Now we need to wait 8 cycles */
        util_microdelay(POST_SWITCH_DELAY);
        e = select_deselect_card(sdhci, sloti, 0, NULL);
        if (e != NULL)
          ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
      }
      if (slot->memory_type != MEMORY_NONE)
      {
        /* Set high speed mode in SD card, or in the memory portion of an SDIO combo card */
        uint32_t select_card_response;
        e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
        if (e != NULL)
          ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
        uint8_t buffer[64];
        do
        {
          dprintf("Switching memory card to access mode %d\n", access_mode);
          COMMAND_DATA(sdhci->bus, sloti,
              CMD6_SWITCH_FUNC | (9 << SDIOOp_CmdFlg_BlockSplitShift),
              SWITCH_FUNC_MODE_SWITCH | 0xFFFFF0u | (access_mode << SWITCH_FUNC_ACCESS_MODE_SHIFT),
              R1, switch_func_blk, Read, buffer, sizeof buffer, e);
          if (e != NULL)
            ABORT_PROBE("SWITCH_FUNC returned %s\n", e->errmess);
        }
        while ((GET_CMD6_BYTE(SWITCH_FUNC_FG1RESULT) & SWITCH_FUNC_FG1RESULT_MASK) != access_mode);
        /* Now we need to wait 8 cycles */
        util_microdelay(POST_SWITCH_DELAY);
        e = select_deselect_card(sdhci, sloti, 0, NULL);
        if (e != NULL)
          ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
       }
    }

    if (slot->io_functions > 0)
    {
      /* Read supported frequency for SDIO functions */
      uint32_t select_card_response;
      e = select_deselect_card(sdhci, sloti, slot->card[0].rca, &select_card_response);
      if (e != NULL)
        ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
      uint8_t buffer[4];
      e = read_cis_tuple(sdhci, sloti, 0, CISTPL_FUNCE, buffer, sizeof buffer);
      if (e != NULL)
        ABORT_PROBE("Read of FUNCE tuple returned %s\n", e->errmess);
      uint32_t cid_freq;
      if (!lookup_tran_speed(buffer[3], false, &cid_freq))
        return false;
      dprintf("IO TRAN_SPEED = %u kHz\n", cid_freq);
      slot->freq = MIN(slot->freq, cid_freq);
      e = select_deselect_card(sdhci, sloti, 0, NULL);
      if (e != NULL)
        ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
      if (slot->freq == -1u)
        slot->freq = 400; /* drop back to 400 kHz if we have no information to the contrary */
    }
    if (slot->memory_type != MEMORY_NONE)
    {
      /* Read supported frequency for SD card, or for the memory portion of an SDIO combo card */
      uint32_t csd_freq;
      if (!read_csd(sdhci, sloti))
        return false;
      if (!lookup_tran_speed(cardreg_read_int(slot->card[0].csd, CSD_TRAN_SPEED), false, &csd_freq))
        return false;
      dprintf("TRAN_SPEED = %u kHz\n", csd_freq);
      slot->freq = MIN(slot->freq, csd_freq);
    }
  }

  /* Configure clock speed in the controller */
  slot->freq = set_sdclk(sdhci, sloti, slot->freq);

  /* Deal with the high-speed enable bit in host_control1.
   * This is a curious one; the MMC and SD physical specs say nothing about
   * changes to cycle timing patterns in high speed modes. Yet the preset value
   * registers section of the SDHCI spec implies it should be 0 for 25 MHz 3.3V
   * operation, 1 for 50 MHz 3.3V operation, and don't care for UHS modes.
   * In practice, the OMAP3 controller doesn't implement the bit, and doesn't
   * care how we set it. The BCM2835 does obey the bit, but results vary from
   * card to card, with no obvious pattern - the code below was an attempt to
   * detect which cards accepted the alternate timings. Unfortunately, some
   * cards which pass this test exhibit severe performance degradation and also
   * write corruption (which for some reason is not picked up by data packet
   * CRCs). It seems that the greatest compatibility is achieved by never
   * setting the HSE bit. If this turns out to be required by other controllers
   * (e.g. the OMAP4, whose datasheet does a good job of explaining the timing
   * differences) then this will need to be re-enabled on the basis of a flag
   * from the HAL device.
   */
#if 0
  if (slot->freq > 26000)
  {
    sdhcidevice_t       *dev = sdhci->dev;
    sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
    sdhci_writebuffer_t *wrbuf = &slot->wrbuf;
    bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
    uint8_t              hc1 = REGISTER_READ(host_control1);
    uint32_t             test_number, failures = 0;
    
    hc1 |= HC1_HSE;
    
    REGISTER_WRITE(host_control1, hc1);
    register_flush_buffer(dev, sloti, wrbuf);
    
    for (test_number = 0; test_number < 10; test_number++)
    {
      _kernel_oserror *e;
      COMMAND_NO_DATA(sdhci->bus, sloti, CMD13_SEND_STATUS, sdhci->slot[sloti].card[0].rca << 16, R1, send_status_blk, e);
      if (e && e->errnum == ErrorNumber_SDIO_CTO)
        failures++;
    }
    
    if (failures > test_number / 2)
    {
      hc1 &= ~HC1_HSE;
      
      REGISTER_WRITE(host_control1, hc1);
      register_flush_buffer(dev, sloti, wrbuf);
    }
  }
#endif
  return true;
}

static bool calculate_capacity(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdmmcslot_t *slot = sdhci->slot + sloti;

  if (slot->memory_type != MEMORY_NONE)
  {
    for (uint32_t card = 0; card < MAX_CARDS_PER_SLOT; card++)
      if (slot->card[card].in_use)
      {
        uint32_t read_bl_len = cardreg_read_int(slot->card[card].csd, CSD_READ_BL_LEN);
        uint32_t c_size_mult;
        uint32_t c_size;
        if (slot->memory_type != MEMORY_SDHC_SDXC)
        {
          if (read_bl_len >= 12)
            ABORT_PROBE("Invalid READ_BL_LEN field in CSD: %u\n", read_bl_len);
          c_size_mult = cardreg_read_int(slot->card[card].csd, CSD_C_SIZE_MULT) + 2;
          c_size = cardreg_read_int(slot->card[card].csd, CSD_C_SIZE_MMC_SD) + 1;
          if (slot->memory_type == MEMORY_MMC && (slot->memory_ocr & OCR_ACCESS_MODE_MASK) == OCR_ACCESS_MODE_SECTOR)
          {
            /* It's a > 2GB MMC card, so the capacity is specified in the EXT_CSD instead.
             * We can safely read the EXT_CSD even if the card is locked. */
            _kernel_oserror *e;
            e = select_deselect_card(sdhci, sloti, slot->card[card].rca, NULL);
            if (e != NULL)
              ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
            uint8_t buffer[512];
            COMMAND_DATA(sdhci->bus, sloti, CMD8_SEND_EXT_CSD | (9 << SDIOOp_CmdFlg_BlockSplitShift), 0, R1, send_ext_csd_blk, Read, buffer, sizeof buffer, e);
            if (e != NULL)
              ABORT_PROBE("SEND_EXT_CSD returned %s\n", e->errmess);
            slot->card[card].capacity = GET_CMD8_BYTE(EXT_CSD_SEC_COUNT);
            slot->card[card].capacity |= (uint64_t) GET_CMD8_BYTE(EXT_CSD_SEC_COUNT+1) << 8;
            slot->card[card].capacity |= (uint64_t) GET_CMD8_BYTE(EXT_CSD_SEC_COUNT+2) << 16;
            slot->card[card].capacity |= (uint64_t) GET_CMD8_BYTE(EXT_CSD_SEC_COUNT+3) << 24;
            slot->card[card].capacity <<= 9; /* always measured in 512-byte units */
            e = select_deselect_card(sdhci, sloti, 0, NULL);
            if (e != NULL)
              ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
            continue;
          }
        }
        else
        {
          if (read_bl_len != 9)
            ABORT_PROBE("Invalid READ_BL_LEN field in CSD: %u\n", read_bl_len);
          c_size_mult = 10;
          c_size = cardreg_read_int(slot->card[card].csd, CSD_C_SIZE_SDHC) + 1;
        }
        slot->card[card].capacity = (uint64_t) c_size << (c_size_mult + read_bl_len);
      }
  }
  return true;
}

static bool read_fic(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror *e;
  sdmmcslot_t *slot = sdhci->slot + sloti;
  if (slot->io_functions == 0) /* Only SDIO cards have FICs */
    return true;
  e = select_deselect_card(sdhci, sloti, slot->card[0].rca, NULL);
  if (e != NULL)
    ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
  for (size_t function = 1; function <= slot->io_functions; function++)
  {
    uint8_t fic;
    _kernel_oserror *e = io_rw_direct(sdhci, sloti, false, 0, FBR_STANDARD_FIC(function), &fic);
    if (e != NULL)
      ABORT_PROBE("Read of FIC returned %s\n", e->errmess);
    fic = (fic & FBR_STANDARD_FIC_MASK);
    if (fic == FBR_STANDARD_FIC_USE_EXTENDED)
    {
      e = io_rw_direct(sdhci, sloti, false, 0, FBR_EXTENDED_FIC(function), &fic);
      if (e != NULL)
        ABORT_PROBE("Read of extended FIC returned %s\n", e->errmess);
    }
    slot->fic[function-1] = fic;

    uint8_t buffer[2];
    e = read_cis_tuple(sdhci, sloti, function, CISTPL_FUNCID, buffer, sizeof buffer);
    if (e != NULL)
      ABORT_PROBE("Read of FUNCID tuple returned %s\n", e->errmess);
    dprintf("Card function code %d\n", buffer[0]);
  }
  e = select_deselect_card(sdhci, sloti, 0, NULL);
  if (e != NULL)
    ABORT_PROBE("SELECT_DESELECT_CARD returned %s\n", e->errmess);
  return true;
}

bool probe_bus(sdhcinode_t *sdhci, uint32_t sloti)
{
  _kernel_oserror     *e;
  sdhcidevice_t       *dev = sdhci->dev;
  sdmmcslot_t         *slot = sdhci->slot + sloti;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &slot->wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  bool                 supports_CMD8;

  slot->memory_type = MEMORY_IDENTIFYING;
  slot->io_functions = 0;
  for (uint32_t cardi = 0; cardi < MAX_CARDS_PER_SLOT; cardi++)
    slot->card[cardi].in_use = false;

  /* Power cycle the card */
  set_vdd(sdhci, sloti, 0);
  util_microdelay(BUS_RESET_TIME);
  set_vdd(sdhci, sloti, slot->controller_ocr);
  util_microdelay(BUS_INIT_TIME);

  /* Do the OMAP post-power-on magic */
  if (dev->PostPowerOn)
    dev->PostPowerOn(dev, sloti);

  /* Reset the controller state machine */
  {
    int32_t timeout, now;
    _swix(OS_ReadMonotonicTime, _OUT(0), &timeout);
    timeout += CONTROLLER_RESET_TIMEOUT + 1;
    REGISTER_WRITE(software_reset, SR_SRC);
    register_flush_buffer(dev, sloti, wrbuf);
    do
      _swix(OS_ReadMonotonicTime, _OUT(0), &now);
    while (timeout - now > 0 && (REGISTER_READ(software_reset) & SR_SRC) != 0);
    if (timeout - now <= 0)
      ABORT_PROBE("Timed out waiting for slot reset\n");
  }

  /* Configure bus for identification */
  set_sdclk(sdhci, sloti, 400); /* 400 kHz clock during identification */
  set_bus_width(sdhci, sloti, 1);
  REGISTER_WRITE(host_control1, REGISTER_READ(host_control1) &~ HC1_HSE);
  register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
  if (dev->SetBusMode)
    dev->SetBusMode(dev, sloti, true); /* open-drain mode */

  /* Reset the IO portion of a device first, ignoring any errors */
  {
    _kernel_oserror *e2;
    COMMAND_NO_DATA(sdhci->bus, sloti, CMD3_SEND_RELATIVE_ADDR, 0, R6, send_relative_addr_blk, e2);
    select_deselect_card(sdhci, sloti, send_relative_addr_blk.response >> 16, NULL);
    uint8_t reset_bit = 8;
    io_rw_direct(sdhci, sloti, true, 0, CCCR_IO_ABORT, &reset_bit);
  }

  /* Send all devices in slot to idle state */
  COMMAND_NO_DATA(sdhci->bus, sloti, CMD0_GO_IDLE_STATE, 0, R0, go_idle_blk, e);
  if (e != NULL)
    ABORT_PROBE("GO_IDLE_STATE returned %s\n", e->errmess);

  /* As per SD specs (which contradict the flowcharts in the OMAP datasheet),
   * issue CMD8 first, which checks for a voltage mismatch and tells
   * dual-voltage and HC/XC SD cards to enable the 1.8V and CCS bits in the OCR
   * respectively. If it fails, it also tells us we should avoid setting the
   * HCS bit in ACMD41 and potentially confusing a version 1 SD card.
   * Technically, this only needs to be done some time before ACMD41.
   * While in idle state, any MMC card(s) should ignore anything except CMD1.
   */
  COMMAND_NO_DATA(sdhci->bus, sloti, CMD8_SEND_IF_COND, 0x1AA, R7, send_if_cond_blk, e);
  if (e != NULL && e->errnum != ErrorNumber_SDIO_CTO)
    ABORT_PROBE("SEND_IF_COND returned %s\n", e->errmess);
  if (e == NULL && send_if_cond_blk.response != 0x1AA)
    ABORT_PROBE("SEND_IF_COND echo failure\n");
  supports_CMD8 = e == NULL;
  dprintf("%s response to CMD8\n", supports_CMD8 ? "Good" : "No");

  if (!resolve_voltage(sdhci, sloti, supports_CMD8))
    return false;

  if (!resolve_addresses(sdhci, sloti))
    return false;

  /* Configure bus to push-pull mode. Clock must remain at 400 kHz until CMD9 has finished. */
  register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
  if (dev->SetBusMode)
    dev->SetBusMode(dev, sloti, false);
  set_bus_width(sdhci, sloti, 1);

  if (!read_csd(sdhci, sloti))
    return false;

  if (!read_scr(sdhci, sloti))
    return false;

  if (!resolve_bus_width(sdhci, sloti))
    return false;

  if (!resolve_bus_speed(sdhci, sloti))
    return false;

  if (!calculate_capacity(sdhci, sloti))
    return false;

  if (!read_fic(sdhci, sloti))
    return false;

  return true;
}
