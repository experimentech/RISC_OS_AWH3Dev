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

#ifndef SERVICE_H
#define SERVICE_H

#include <stdint.h>
#include <stdbool.h>
#include "kernel.h"

void service_SDIOSlotAttached(uint32_t bus, uint32_t slot, bool integrated, bool no_card_detect, bool integrated_mem);
void service_SDIOSlotDetached(uint32_t bus, uint32_t slot, bool integrated, bool no_card_detect, bool integrated_mem);
void service_SDIOUnitAttached(uint32_t bus, uint32_t slot, uint32_t rca, uint32_t unit, uint32_t fic, bool writeprotect, bool mmc, uint64_t capacity, bool called_from_init);
void service_SDIOUnitDetached(uint32_t bus, uint32_t slot, uint32_t rca, uint32_t unit, uint32_t fic, bool writeprotect, bool mmc);
void service_SDIOSlotReleased(uint32_t bus, uint32_t slot);

#endif
