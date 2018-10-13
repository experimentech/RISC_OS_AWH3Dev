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

#ifndef FREE_H
#define FREE_H

#include <stdint.h>
#include "kernel.h"

/** First word of workspace to pass to free_veneer */
extern void *free_handle;

/** Initialisation function, must be called before free_veneer */
void free_init(void);

/** Entry point from Free module */
void free_veneer(void);

_kernel_oserror *free_handler(_kernel_swi_regs *r, uint32_t *return_flags);

#endif
