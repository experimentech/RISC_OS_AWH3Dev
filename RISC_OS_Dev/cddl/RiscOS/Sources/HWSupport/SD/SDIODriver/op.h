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

#ifndef OP_H
#define OP_H

#include <stdbool.h>
#include <stdint.h>
#include "globals.h"

typedef struct
{
  /* r0 */
  union
  {
    struct
    {
      unsigned slot:       8;
      unsigned bus:        8;
      bool     chk_busy:   1;
      bool     chk_crc:    1;
      bool     chk_index:  1;
      bool     chk_r1:     1;
      bool     chk_r5:     1;
      unsigned reserved1:  3;
      unsigned dir:        2;
      bool     scatter:    1;
      bool     no_escape:  1;
      unsigned reserved2:  1;
      bool     bg:         1;
      unsigned reserved3:  2;
    } bits;
    uint32_t word;
  } r0;
  /* r1 */
  union
  {
    size_t cmdres_len;
    void  *op_handle;
  } r1;
  /* r2 */
  union
  {
    sdioop_cmdres_R0_t     *R0;
    sdioop_cmdres_R1_t     *R1;
    sdioop_cmdres_R1b_t    *R1b;
    sdioop_cmdres_R2_t     *R2;
    sdioop_cmdres_R3_t     *R3;
    sdioop_cmdres_R4mmc_t  *R4mmc;
    sdioop_cmdres_R4sdio_t *R4sdio;
    sdioop_cmdres_R5mmc_t  *R5mmc;
    sdioop_cmdres_R5sdio_t *R5sdio;
    sdioop_cmdres_R6_t     *R6;
    sdioop_cmdres_R7_t     *R7;
  } cmdres;
  /* r3 */
  union
  {
    uint8_t   *block;
    scatter_t *scatter;
  } data;
  /* r4 */
  size_t data_len;
  /* r5 */
  union
  {
    uint32_t timeout;
    void    *callback_r5;
  } r5;
  /* r6 */
  void (*callback)(void);
  /* r7 */
  void *callback_r12;
} sdioop_block_t;

void op_abort(sdioop_t *op);
void op_abort_all(sdmmcslot_t *slot);
void op_poll(sdhcinode_t *sdhci, uint32_t sloti);

#endif
