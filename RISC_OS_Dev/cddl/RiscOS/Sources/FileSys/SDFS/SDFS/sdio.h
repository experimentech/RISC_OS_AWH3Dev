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

#ifndef SDIO_H
#define SDIO_H

#include <stddef.h>
#include <stdint.h>
#include "kernel.h"

extern _kernel_oserror *sdio_op_fg_nodata(uint32_t flags, size_t crlen, void *crblock, uint32_t timeout);
extern _kernel_oserror *sdio_op_fg_data(uint32_t flags, size_t crlen, void *crblock, void *data, size_t datalen, uint32_t timeout, size_t *remaining);

#endif
