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

/** \file register.c
 * SDHCI register access.
 */

#include <stdio.h>

#include <stdint.h>

#include "register.h"
  #include "gpiodebug.h"

static void internal_flush_buffer(sdhcidevice_t *dev, uint32_t sloti, sdhci_writebuffer_t * restrict buf)
{
  if (buf->dirty)
  {
    if (dev->WriteRegister)
      dev->WriteRegister(dev, sloti, (void *)buf->reg, *(volatile uint32_t *)buf->reg &~ buf->dirty | buf->value, 4);
    else
      *(volatile uint32_t *)buf->reg = *(volatile uint32_t *)buf->reg &~ buf->dirty | buf->value;
    buf->dirty = 0;
    buf->value = 0;
  }
}

void register_init_buffer(sdhci_writebuffer_t * restrict buf)
{
  buf->lock = (spinlock_t) SPIN_INITIALISER;
  buf->dirty = 0;
  buf->value = 0;
}

void register_flush_buffer(sdhcidevice_t *dev, uint32_t sloti, sdhci_writebuffer_t * restrict buf)
{
  spin_lock(&buf->lock);
  internal_flush_buffer(dev, sloti, buf);
  spin_unlock(&buf->lock);
}

void register_write_buffer_8(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint8_t value, sdhci_writebuffer_t * restrict buf)
{
  size_t shift = (reg & 3) * 8;
  uint32_t mask = 0xFFu << shift;
  spin_lock(&buf->lock);
  /* Do a read-modify-write if we're addressing a different word, or if we're
   * updating bits in the same word that haven't yet been written to hardware */
  if ((reg ^ buf->reg) > 3 || (mask & buf->dirty) != 0)
    internal_flush_buffer(dev, sloti, buf);
  /* Store details of the write into the buffer */
  buf->reg = reg &~ 3;
  buf->dirty |= mask;
  buf->value |= value << shift;
  /* Write out a word if we now have values for all bits */
  if (buf->dirty == -1u)
  {
    if (dev->WriteRegister)
      dev->WriteRegister(dev, sloti, (void *)buf->reg, buf->value, 4);
    else
      *(volatile uint32_t *)buf->reg = buf->value;
    buf->dirty = 0;
    buf->value = 0;
  }
  spin_unlock(&buf->lock);
}

void register_write_buffer_16(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint16_t value, sdhci_writebuffer_t * restrict buf, buffer_lock_override_t override)
{
  size_t shift = (reg & 2) * 8;
  uint32_t mask = 0xFFFFu << shift;
  if ((override & ALREADY_LOCKED) == 0)
    spin_lock(&buf->lock);
  /* Do a read-modify-write if we're addressing a different word, or if we're
   * updating bits in the same word that haven't yet been written to hardware */
  if ((reg ^ buf->reg) > 3 || (mask & buf->dirty) != 0)
    internal_flush_buffer(dev, sloti, buf);
  /* Store details of the write into the buffer */
  buf->reg = reg &~ 3;
  buf->dirty |= mask;
  buf->value |= value << shift;
  /* Write out a word if we now have values for all bits */
  if (buf->dirty == -1u)
  {
    if (dev->WriteRegister)
      dev->WriteRegister(dev, sloti, (void *)buf->reg, buf->value, 4);
    else
      *(volatile uint32_t *)buf->reg = buf->value;
    buf->dirty = 0;
    buf->value = 0;
  }
  if ((override & LEAVE_LOCKED) == 0)
    spin_unlock(&buf->lock);
}

void register_write_buffer_32(sdhcidevice_t *dev, uint32_t sloti, uintptr_t reg, uint32_t value, sdhci_writebuffer_t * restrict buf)
{
  spin_lock(&buf->lock);
  internal_flush_buffer(dev, sloti, (buf));
  if (dev->WriteRegister)
    dev->WriteRegister(dev, sloti, (void *)(reg), (value), 4);
  else
    *(volatile uint32_t *)(reg) = (value);
  spin_unlock(&buf->lock);
}
