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

/** \file cardreg.c
 * Routines to decode card registers.
 */

#include <string.h>
#include <stdint.h>

#include "cardreg.h"
#include "globals.h"
#include "message.h"

uint32_t cardreg_read_int(uint8_t *reg, bitfield_t where)
{
  uint32_t result = 0;
  size_t   result_bit = 0;

  where.hi++; /* convert to exclusive max */
  if (where.crc_omitted)
  {
    /* Adjust offsets to compensate for CRC byte being omitted */
    where.hi -= 8;
    where.lo -= 8;
  }

  do
  {
    size_t  bits_this_time = MIN(8 - (where.lo & 7), where.hi - where.lo);
    uint8_t byte = reg[where.lo / 8] >> (where.lo & 7);
    byte &= (1 << bits_this_time) - 1;
    result |= byte << result_bit;
    result_bit += bits_this_time;
    where.lo += bits_this_time;
  }
  while (where.lo != where.hi);

  return result;
}

const char *cardreg_read_string(uint8_t *reg, bitfield_t where, char *buffer)
{
  /* Adjust offsets to compensate for CRC byte being omitted */
  where.hi -= 8;
  where.lo -= 8;

  /* Convert to byte offsets - it is assumed that strings are byte-aligned */
  where.hi /= 8;
  where.lo /= 8;

  /* Check for non-printable characters in string */
  for (size_t i = where.lo; i <= where.hi; i++)
  {
    if (reg[i] < ' ' || reg[i] == 127)
      return message_lookup_direct("BadString");
  }

  /* The string is held in reverse order in the register block, so copy it
   * into the supplied buffer. Assume the buffer is big enough. */
  size_t length = where.hi - where.lo + 1;
  for (size_t i = 0; i < length; i++)
    buffer[i] = reg[where.hi-i];
  buffer[length] = '\0';
  return buffer;
}

const char *cardreg_lookup_manufacturer(const char *code)
{
  /* I'm not aware that the allocations have been publicly documented, so this
   * table has been constructed by experimentation, Googling and some guesswork */
  static const struct
  {
    char code[3];
    char full[12];
  }
  lut[] = {
      { "KG", "KingMax" },
      { "PA", "Panasonic" },
      { "SD", "SanDisk" },
      { "SM", "Samsung" },
      { "TM", "Toshiba" },
      { "TS", "Transcend" },
  };

  for (size_t i = 0; i < sizeof lut / sizeof *lut; i++)
  {
    if (strcmp(code, lut[i].code) == 0)
      return lut[i].full;
  }

  /*  Give up, just use the 2-character code */
  return code;
}
