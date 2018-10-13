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

#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>
#include "kernel.h"

#include "globals.h"

_kernel_oserror *util_find_bus(uint32_t bus, sdhcinode_t **sdhci);
_kernel_oserror *util_find_bus_and_slot(uint32_t bus, uint32_t sloti, sdhcinode_t **sdhci, sdmmcslot_t **slot);
void util_microdelay(uint32_t us);

#endif
