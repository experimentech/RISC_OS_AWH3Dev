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

/** \file op.c
 * State machine to handle processing of MMC/SD/SDIO operations.
 * I apologise for the heinous number of gotos in the file,
 * but it goes with the territory of state machines...
 */
#include "swis.h"
#include "kernel.h"

#include "Global/NewErrors.h"
#include "Interface/SDIO.h"

#include "SyncLib/atomic.h"

#include "globals.h"
#include "message.h"
#include "op.h"
#include "register.h"
#include "stuff.h"
#include "util.h"

/* Timeouts are in cs */
#define CMD_INHIBIT_TIMEOUT (1)
#define DAT_INHIBIT_TIMEOUT (1)
#define CTLR_RESET_TIMEOUT  (1)

/** How many times to poll the reset bits before deducing that we missed them ging high */
#define RESET_TRIES (5)

/** Mask of error-generating bits in R1 command response */
#define R1_ERROR_MASK (0xFDF9A080)

/** Mask of error-generating bits in R5 command response */
#define R5_ERROR_MASK (0x0000CB00)

/** FileCore scatter list threshold */
#define SCATTER_THRESHOLD (0xFFFF0000u)

/** Callback function for atomic_process for use when we advance the state
 *  machine within op_poll. At any point we may discover that the op has been
 *  aborted, in which case we don't actually change the state variable.
 *  \arg current_state Current value of state variable.
 *  \arg new_state     Next state requested by atomic_process's caller.
 *  \return            New value of state variable.
 */
static uint32_t switch_state(uint32_t current_state, uint32_t new_state)
{
  return current_state == CMD_STATE_ABORT ? CMD_STATE_ABORT : new_state;
}

static void set_activity(sdhcinode_t *sdhci, uint32_t sloti, uint32_t level)
{
  sdhcidevice_t *dev = sdhci->dev;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  if (dev->SetActivity)
  {
    sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
    register_flush_buffer(dev, sloti, wrbuf); /* ensure writes flushed before calling HAL */
    dev->SetActivity(dev, sloti, level);
  }
  else
  {
    uint8_t hc1 = REGISTER_READ(host_control1);
    if (level)
      hc1 |= HC1_LEDC;
    else
      hc1 &= ~HC1_LEDC;
    REGISTER_WRITE(host_control1, hc1);
  }
}

static uint32_t read_interrupt_status(sdhcinode_t *sdhci, uint32_t sloti, uint16_t *normal_irq)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  uint16_t             error_irq;
  *normal_irq = REGISTER_READ(normal_interrupt_status);
  REGISTER_WRITE(normal_interrupt_status, *normal_irq);
  if ((dev->flags & HALDeviceSDHCI_Flag_ErrIRQbug) == 0 && (*normal_irq & IRQ_ERRI) == 0)
  {
    REGISTER_WRITE(error_interrupt_status, 0);
    return 0; /* quick exit for common case */
  }
  error_irq = REGISTER_READ(error_interrupt_status);
  REGISTER_WRITE(error_interrupt_status, error_irq);
  /* Some interaction between bits must be enforced in software */
  if (error_irq & EIRQ_CTO)
    *normal_irq &= ~IRQ_CC;
  if (*normal_irq & IRQ_TC)
    error_irq &= ~EIRQ_DTO;
  if (error_irq == 0)
    return 0;
  /* Don't do error lookup just yet - error recovery will require us to
   * wait up to 10 ms, in which time the error buffer may be reused */
  if (error_irq == (EIRQ_CCRC | EIRQ_CTO))
    return ErrorNumber_SDIO_Conflict; /* special case */
  size_t leading_zeros;
  __asm { CLZ leading_zeros, error_irq }
  return ErrorNumber_SDIO_CTO + 31 - leading_zeros;
}

static void advance_scatter_pointer(sdioop_t *op)
{
  do
  {
    if (op->list->length == 0 && (uintptr_t) op->list->address >= SCATTER_THRESHOLD)
      op->list = (scatter_t *) ((uintptr_t) op->list + (uintptr_t) op->list->address);
    else
      op->list++;
    op->scatter_offset = 0;
  }
  while (op->scatter_offset >= op->list->length);
}

static _kernel_oserror *deferred_error_lookup(uint32_t number)
{
  switch (number)
  {
#define ERROR_CASE(name) case ErrorNumber_##name: return MESSAGE_ERRORLOOKUP(true, name, 0);
    ERROR_CASE(SDIO_CMDTO)
    ERROR_CASE(SDIO_DATTO)
    ERROR_CASE(SDIO_Abort)
    ERROR_CASE(SDIO_Conflict)
    ERROR_CASE(SDIO_CTO)
    ERROR_CASE(SDIO_CCRC)
    ERROR_CASE(SDIO_CEB)
    ERROR_CASE(SDIO_CIE)
    ERROR_CASE(SDIO_DTO)
    ERROR_CASE(SDIO_DCRC)
    ERROR_CASE(SDIO_DEB)
    ERROR_CASE(SDIO_CLE)
    ERROR_CASE(SDIO_ACE)
    ERROR_CASE(SDIO_ADE)
    ERROR_CASE(SDIO_TE)
    ERROR_CASE(SDIO_C12)
    ERROR_CASE(SDIO_DevE07)
    ERROR_CASE(SDIO_DevE13)
    ERROR_CASE(SDIO_DevE15)
    ERROR_CASE(SDIO_DevE16)
    ERROR_CASE(SDIO_DevE19)
    ERROR_CASE(SDIO_DevE20)
    ERROR_CASE(SDIO_DevE21)
    ERROR_CASE(SDIO_DevE22)
    ERROR_CASE(SDIO_DevE23)
    ERROR_CASE(SDIO_DevE24)
    ERROR_CASE(SDIO_DevE26)
    ERROR_CASE(SDIO_DevE27)
    ERROR_CASE(SDIO_DevE28)
    ERROR_CASE(SDIO_DevE29)
    ERROR_CASE(SDIO_DevE30)
    ERROR_CASE(SDIO_DevE31)
    ERROR_CASE(SDIO_IODevE00)
    ERROR_CASE(SDIO_IODevE01)
    ERROR_CASE(SDIO_IODevE03)
    ERROR_CASE(SDIO_IODevE06)
    ERROR_CASE(SDIO_IODevE07)
    default: return NULL;
  }
}

static void op_do_callback(_kernel_oserror *e, sdioop_t *op)
{
  if (op->callback != NULL)
  {
    /* Time for some inline assembler magic :) */
    __asm {
      MOV r0, e
      MOV r4, op->total_length
      MOV r5, op->callback_r5
      MOV r12, op->callback_r12
      MSR CPSR_f, e == NULL ? 0 : 1<<28
      BLX op->callback, {r0,r4,r5,r12,pc}
    }
  }
}

/** Callback function for atomic_process for use when we abort an op.
 *  \arg current_state Current value of state variable.
 *  \arg unused        Unused argument.
 *  \return            New value of state variable.
 */
static uint32_t set_abort_state(uint32_t current_state, uint32_t unused)
{
  IGNORE(unused);
  return current_state == CMD_STATE_READY ? CMD_STATE_NEVER_STARTED : CMD_STATE_ABORT;
}

void op_abort(sdioop_t *op)
{
  if (atomic_process(set_abort_state, 0, &op->state) == CMD_STATE_READY)
  {
    /* In this case it could be an indefinitely long wait before the state
     * machine for this op gets processed (we could be stuck in an earlier op
     * in the queue) so issue the callback routine synchronous to this call
     * rather that from within op_poll(). */
    op_do_callback(MESSAGE_ERRORLOOKUP(true, SDIO_Abort, 0), op);
  }
  /* Otherwise, and assuming the op hasn't already completed, the callback will
   * still be issued at some later time, but no more than CTLR_RESET_TIMEOUT
   * later (currently 20 ms, allowing for rounding) */
}

void op_abort_all(sdmmcslot_t *slot)
{
  size_t op_index = slot->op_used;
  size_t op_free  = slot->op_free;
  while (op_index != op_free)
  {
    op_abort(slot->op + op_index);
    if (++op_index == QUEUE_LENGTH)
      op_index = 0;
  }
}

#include <stdio.h>
void op_poll(sdhcinode_t *sdhci, uint32_t sloti)
{
  sdhcidevice_t       *dev = sdhci->dev;
  sdmmcslot_t         *slot = sdhci->slot + sloti;
  sdhci_regset_t      *regs = dev->slotinfo[sloti].stdregs;
  sdhci_writebuffer_t *wrbuf = &sdhci->slot[sloti].wrbuf;
  bool                 force32 = dev->flags & HALDeviceSDHCI_Flag_32bit;
  size_t               op_index = slot->op_used;

  /* Serialise entry to function */
  if (!mutex_try_lock(&slot->doing_poll))
    return;

  while (op_index != slot->op_free)
  {
    sdioop_t *op = slot->op + op_index;
    uint16_t irqs;
    _kernel_oserror *e = NULL;
    int32_t now;
    _swix(OS_ReadMonotonicTime, _OUT(0), &now);

    switch (op->state)
    {
      case CMD_STATE_READY:
        op->error = 0;
        if (atomic_process(switch_state, CMD_STATE_WAIT_CMD_INHIBIT, &op->state) == CMD_STATE_ABORT)
          goto abort;
        op->timeout = now + CMD_INHIBIT_TIMEOUT + 1;
        /* drop through */

      case CMD_STATE_WAIT_CMD_INHIBIT:
        if (REGISTER_READ(present_state) & PS_CMDI)
        {
          if (now - op->timeout >= 0)
          {
            op->error = ErrorNumber_SDIO_CMDTO;
            goto reset;
          }
          /* Wait for CMD line to be free */
          /* Enable command complete IRQ so we get called back as soon as this happens */
          REGISTER_WRITE(normal_interrupt_status_enable, IRQ_CC);
          REGISTER_WRITE(error_interrupt_status_enable, 0);
          goto exit;
        }
        /* Ack the CC IRQ, just in case */
        REGISTER_WRITE(normal_interrupt_status, IRQ_CC);
        REGISTER_WRITE(error_interrupt_status, 0);
        
        /* I'm going to add an additional check to that in the SDHCI spec before
         * skipping the DAT line check - I think it shouldn't be allowed for any
         * commands that use data transfer, as well as for those that use busy
         * signalling on DAT0. */
        if (((op->command & CMD_RSP_MASK) != CMD_RSP_48_BUSY && op->total_length == 0) ||
            (op->command & CMD_TYPE_MASK) == CMD_TYPE_ABORT)
          goto new_command_can_be_issued;

        if (atomic_process(switch_state, CMD_STATE_WAIT_DAT_INHIBIT, &op->state) == CMD_STATE_ABORT)
          goto abort;
        op->timeout = now + DAT_INHIBIT_TIMEOUT + 1;
        /* drop through */

      case CMD_STATE_WAIT_DAT_INHIBIT:
        if (REGISTER_READ(present_state) & PS_DATI)
        {
          if (now - op->timeout >= 0)
          {
            op->error = ErrorNumber_SDIO_DATTO;
            goto reset;
          }
          /* Wait for DAT line to be free */
          /* Enable transfer complete IRQ so we get called back as soon as this happens */
          REGISTER_WRITE(normal_interrupt_status_enable, IRQ_TC);
          REGISTER_WRITE(error_interrupt_status_enable, 0);
          goto exit;
        }
        /* Ack the TC IRQ, just in case */
        REGISTER_WRITE(normal_interrupt_status, IRQ_TC);
        REGISTER_WRITE(error_interrupt_status, 0);

new_command_can_be_issued:
        /* Illuminate the activity LED */
        set_activity(sdhci, sloti, op->total_length > 0 && (op->transfer_mode & TM_DDIR) == 0 ? HALDeviceSDHCI_ActivityWrite : HALDeviceSDHCI_ActivityRead);

        /* The OMAP manual recommends masking interrupts that we don't expect.
         * This should be harmless on other implementations.
         * We don't use OMAP's CERR feature (hardware checking of R1 responses)
         * since this is not portable. */
        {
          uint16_t normal_irqs = IRQ_CC;
          if (op->total_length > 0)
          {
            normal_irqs |= IRQ_TC;
            normal_irqs |= op->transfer_mode & TM_DDIR ? IRQ_BRR : IRQ_BWR;
          }
          REGISTER_WRITE(normal_interrupt_status_enable, normal_irqs);
          uint16_t error_irqs = EIRQ_CEB;
          if ((op->command & CMD_RSP_MASK) != CMD_RSP_NONE)
            error_irqs |= EIRQ_CTO;
          if (op->command & CMD_CCCE)
            error_irqs |= EIRQ_CCRC;
          if (op->command & CMD_CICE)
            error_irqs |= EIRQ_CIE;
          if (op->total_length > 0)
          {
            error_irqs |= EIRQ_DTO | EIRQ_DCRC | EIRQ_DEB;
            if ((op->transfer_mode & TM_ACEN_MASK) == TM_ACEN_CMD12)
              error_irqs |= EIRQ_ACE;
          }
          REGISTER_WRITE(error_interrupt_status_enable, error_irqs);
        }

        if (op->total_length > 0)
        {
          REGISTER_WRITE(block_size, op->block_size << BS_TBS_SHIFT);
          REGISTER_WRITE(block_count, op->block_count);
        }
        REGISTER_WRITE(argument1, op->argument);
        if ((dev->dev.version & 0xFFFF) >= HALDeviceSDHCI_MinorVersion_HasTrigger &&
            dev->TriggerCommand)
        {
          dev->TriggerCommand(dev, sloti, op->transfer_mode, op->command);
        }
        else
        {
          /* The next 2 writes must be atomic in case they get converted to a
           * single 32-bit write, because the register is write-sensitive */
          REGISTER_WRITE16_LEAVE_LOCKED(force32, (uintptr_t) &regs->transfer_mode, op->transfer_mode, wrbuf);
          REGISTER_WRITE16_ALREADY_LOCKED(force32, (uintptr_t) &regs->command, op->command, wrbuf);
        }
        if (atomic_process(switch_state, CMD_STATE_WAIT_COMMAND_COMPLETE, &op->state) == CMD_STATE_ABORT)
          goto abort;
        /* drop through */

      case CMD_STATE_WAIT_COMMAND_COMPLETE:
        op->error = read_interrupt_status(sdhci, sloti, &irqs);
        if (op->error != 0)
        {
          goto reset;
        }
        if ((irqs & IRQ_CC) == 0)
        {
          /* Timeouts are left for the next layer up to handle, so just exit here */
          goto exit;
        }

        /* Read the response if any */
        switch (op->command & CMD_RSP_MASK)
        {
          case CMD_RSP_48:
          case CMD_RSP_48_BUSY:
            *(uint32_t *) op->response = REGISTER_READ(response.word);
            if (op->chk_r1)
            {
              uint32_t errors = *(uint32_t *) op->response & R1_ERROR_MASK;
              if (errors != 0)
              {
                size_t leading_zeros;
                __asm { CLZ leading_zeros, errors }
                op->error = ErrorBase_SDIO + 0xC0 + 31 - leading_zeros;
                /* I'm going to disagree with the flowchart in the SD standard:
                 * if the card has reported an error here it makes little sense
                 * to continue attempting a data transfer operation, so just
                 * report the error now. */
                goto reset;
              }
            }
            if (op->chk_r5)
            {
              uint32_t errors = *(uint32_t *) op->response & R5_ERROR_MASK;
              if (errors != 0)
              {
                size_t leading_zeros;
                __asm { CLZ leading_zeros, errors }
                op->error = ErrorBase_SDIO + 0xE0 + 31 - leading_zeros - 8;
                /* I'm going to disagree with the flowchart in the SD standard:
                 * if the card has reported an error here it makes little sense
                 * to continue attempting a data transfer operation, so just
                 * report the error now. */
                goto reset;
              }
            }
            break;
          case CMD_RSP_136:
            /* Leave the endianness as it is in registers - this is the reverse
             * of the order in which they were transmitted on the wire, so it
             * means that multibyte integers can be interpreted as little-endian,
             * but does mean that strings have to be printed out in reverse order.
             */
            {
              bool offset = dev->flags & HALDeviceSDHCI_Flag_R2bug;
              for (size_t i = 0; i < 15; i++)
                ((uint8_t *) op->response)[i] = REGISTER_READ(response.byte[i+offset]);
            }
            break;
        }

        if (op->total_length == 0)
        {
          op->state = CMD_STATE_COMPLETED;
          break;
        }
        if (op->transfer_mode & TM_DDIR)
          goto read;

        /* Write data */
        if (atomic_process(switch_state, CMD_STATE_WAIT_BUFFER_WRITE_READY, &op->state) == CMD_STATE_ABORT)
          goto abort;
        if (REGISTER_READ(present_state) & PS_BWE)
          goto write_ready;
        /* else drop through */

      case CMD_STATE_WAIT_BUFFER_WRITE_READY:
        do
        {
          size_t   block_index; /* bytes into current block */
          uint32_t word;        /* word value to poke */
          size_t   bits;        /* how many bits of word have been constructed */
          size_t   fast_bytes;  /* how many bytes we can do using aligned word accesses */
          op->error = read_interrupt_status(sdhci, sloti, &irqs);
          if (op->error != 0)
          {
            goto reset;
          }
          if ((REGISTER_READ(present_state) & PS_BWE) == 0)
          {
            /* Timeouts are left for the next layer up to handle, so just exit here */
            goto exit;
          }
write_ready:
          block_index = 0;
          word = 0;
          bits = 0;
          do
          {
            /* Note that this code bypasses the write buffer for accessing the data register -
             * this is OK even with the BM2835 with its timing bug
             */
            if (op->scatter_offset >= op->list->length)
              advance_scatter_pointer(op);
            if (bits == 0 && (((uintptr_t) op->list->address + op->scatter_offset) & 3) == 0 &&
                (fast_bytes = MIN(op->list->length - op->scatter_offset, op->block_size - block_index) &~ 3) > 0)
            {
              uint32_t *word_ptr = (uint32_t *) (op->list->address + op->scatter_offset);
              op->scatter_offset += fast_bytes;
              block_index += fast_bytes;
              stuff_write((volatile uint32_t *)&regs->data, word_ptr, fast_bytes);
            }
            else
            {
              word |= op->list->address[op->scatter_offset++] << bits;
              if ((bits += 8) == 32)
              {
                *(volatile uint32_t *)(&regs->data) = word; /* cast needed to remove __packed */
                word = 0;
                bits = 0;
              }
              ++block_index;
            }
          }
          while (block_index < op->block_size);
          if (bits != 0) /* partial word at end - controller should ignore extra bytes */
            *(volatile uint32_t *)(&regs->data) = word; /* cast needed to remove __packed */
        }
        while (--op->block_count > 0);
        goto wait_for_transfer_complete;

read:
        /* Read data */
        if (atomic_process(switch_state, CMD_STATE_WAIT_BUFFER_READ_READY, &op->state) == CMD_STATE_ABORT)
          goto abort;
        if (REGISTER_READ(present_state) & PS_BRE)
          goto read_ready;
        /* else drop through */

      case CMD_STATE_WAIT_BUFFER_READ_READY:
        do
        {
          size_t   block_index; /* bytes into current block */
          uint32_t word;        /* peeked word value */
          size_t   bits;        /* how many bits of word have been stored in RAM */
          size_t   fast_bytes;  /* how many bytes we can do using aligned word accesses */
          op->error = read_interrupt_status(sdhci, sloti, &irqs);
          if (op->error != 0)
          {
            goto reset;
          }
          if ((REGISTER_READ(present_state) & PS_BRE) == 0)
          {
            /* Timeouts are left for the next layer up to handle, so just exit here */
            goto exit;
          }
read_ready:
          block_index = 0;
          word = 0;
          bits = 0;
          do
          {
            if (bits == 0 && (((uintptr_t) op->list->address + op->scatter_offset) & 3) == 0 &&
                (fast_bytes = MIN(op->list->length - op->scatter_offset, op->block_size - block_index) &~ 3) > 0)
            {
              uint32_t *word_ptr = (uint32_t *) (op->list->address + op->scatter_offset);
              op->scatter_offset += fast_bytes;
              block_index += fast_bytes;
              op->total_length -= fast_bytes;
              stuff_read(word_ptr, (volatile uint32_t *)&regs->data, fast_bytes);
            }
            else
            {
              if (bits == 0)
                word = REGISTER_READ(data);
              if (op->scatter_offset >= op->list->length)
                advance_scatter_pointer(op);
              op->list->address[op->scatter_offset++] = word >> bits;
              if ((bits += 8) == 32)
                bits = 0;
              op->total_length--;
              ++block_index;
            }
          }
          while (block_index < op->block_size);
        }
        while (--op->block_count > 0);
        /* drop through */

wait_for_transfer_complete:
        if (atomic_process(switch_state, CMD_STATE_WAIT_TRANSFER_COMPLETE, &op->state) == CMD_STATE_ABORT)
          goto abort;
        if (irqs & IRQ_TC)
        {
          if ((op->transfer_mode & TM_DDIR) == 0)
            /* Only now that we know a write was successful, mark as no more to do */
            op->total_length = 0;
          op->state = CMD_STATE_COMPLETED;
          break;
        }
        /* else drop through */

      case CMD_STATE_WAIT_TRANSFER_COMPLETE:
        op->error = read_interrupt_status(sdhci, sloti, &irqs);
        if (op->error != 0)
        {
          goto reset;
        }
        if ((irqs & IRQ_TC) == 0)
        {
          /* Timeouts are left for the next layer up to handle, so just exit here */
          goto exit;
        }
        if ((op->transfer_mode & TM_DDIR) == 0)
          /* Only now that we know a write was successful, mark as no more to do */
          op->total_length = 0;
        op->state = CMD_STATE_COMPLETED;
        break;

      case CMD_STATE_ABORT:
abort:
        op->error = ErrorNumber_SDIO_Abort;
reset:
        /* The OMAP4 controller requires that the command and data line parts
         * of the controller are reset sequentially. The OMAP3 and BCM2835
         * don't have this requirement, but equally they don't mind being
         * reset sequentially.
         * To make things more fun, the OMAP4 doesn't start doing the reset
         * for a couple of microseconds, so the SRC/SRD bits may read as
         * zero before reset has started as well as after it has completed.
         * Because we're operating with interrupts enabled, it is therefore
         * possible that we miss the bits reading as one altogether! Solve this
         * with a timeout. Because the timeout is so short, threading out of
         * op_poll (and potentially waiting 10 ms for the next TickerV) is
         * overkill; I think a few microseconds delay in an interrupt handler
         * is probably acceptable. */
        REGISTER_WRITE(software_reset, SR_SRC);
        register_flush_buffer(dev, sloti, wrbuf);
        for (uint32_t tries = RESET_TRIES; tries > 0; tries--)
        {
          if (REGISTER_READ(software_reset) & SR_SRC)
            break;
          util_microdelay(1);
        }
        op->state = CMD_STATE_WAIT_RESET_CMD;
        op->timeout = now + CTLR_RESET_TIMEOUT + 1;
        /* drop through */

      case CMD_STATE_WAIT_RESET_CMD:
        if ((REGISTER_READ(software_reset) & SR_SRC) != 0)
        {
          if (now - op->timeout >= 0)
          {
            /* We unfortunately can't report this failure because by definition
             * we already have an outstanding error if we are here. Instead,
             * just try clearing the reset register ourselves (it's what the
             * OpenBSD driver does in this eventuality). */
            REGISTER_WRITE(software_reset, 0);
            register_flush_buffer(dev, sloti, wrbuf);
          }
          else
          {
            /* Wait for reset to complete */
            goto exit;
          }
        }
        REGISTER_WRITE(software_reset, SR_SRD);
        register_flush_buffer(dev, sloti, wrbuf);
        for (uint32_t tries = RESET_TRIES; tries > 0; tries--)
        {
          if (REGISTER_READ(software_reset) & SR_SRD)
            break;
          util_microdelay(1);
        }
        op->state = CMD_STATE_WAIT_RESET_DAT;
        op->timeout = now + CTLR_RESET_TIMEOUT + 1;
        /* drop through */

      case CMD_STATE_WAIT_RESET_DAT:
        if ((REGISTER_READ(software_reset) & SR_SRD) != 0)
        {
          if (now - op->timeout >= 0)
          {
            /* We unfortunately can't report this failure because by definition
             * we already have an outstanding error if we are here. Instead,
             * just try clearing the reset register ourselves (it's what the
             * OpenBSD driver does in this eventuality). */
            REGISTER_WRITE(software_reset, 0);
            register_flush_buffer(dev, sloti, wrbuf);
          }
          else
          {
            /* Wait for reset to complete */
            goto exit;
          }
        }
        /* Reset has finished */
        e = deferred_error_lookup(op->error);
        op->state = CMD_STATE_COMPLETED;
        break;
    }

    /* If we get here then the command has completed, successful or not */
    if (op->state != CMD_STATE_NEVER_STARTED)
    {
      /* Turn off the activity LED */
      set_activity(sdhci, sloti, HALDeviceSDHCI_ActivityOff);
      op_do_callback(e, op);
    }

    if (++op_index == QUEUE_LENGTH)
      op_index = 0;
    slot->op_used = op_index;
  }
  /* drop through */

exit:
  /* End serialisation */
  mutex_unlock(&slot->doing_poll);
}
