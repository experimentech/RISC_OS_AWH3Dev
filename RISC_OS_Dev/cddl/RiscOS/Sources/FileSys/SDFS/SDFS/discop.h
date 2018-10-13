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

#ifndef DISCOP_H
#define DISCOP_H

#include "globals.h"

/** Scatter list entry */
typedef struct
{
  uint8_t *address;
  size_t   length;
}
scatter_t;

typedef union
{
  uint8_t   *block;
  scatter_t *scatter;
}
block_or_scatter_t;

low_level_error_t discop(uint32_t reason, uint32_t flags, uint32_t drive, uint64_t * restrict disc_address, block_or_scatter_t * restrict ptr, size_t * restrict fg_length);

#endif
