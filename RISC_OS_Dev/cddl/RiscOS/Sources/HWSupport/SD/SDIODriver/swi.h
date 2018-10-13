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

#ifndef SWI_H
#define SWI_H

#include <stdbool.h>
#include <stdint.h>
#include "kernel.h"
#include "globals.h"
#include "op.h"

_kernel_oserror *swi_Initialise_reset_bus(uint32_t bus);
_kernel_oserror *swi_Initialise_rescan_slot(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_try_lock(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_lock(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_sleep_lock(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_unlock(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_abort_all(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Control_abort_op(uint32_t bus, uint32_t sloti, sdioop_t *op);
_kernel_oserror *swi_Control_poll_card_detect(uint32_t bus, uint32_t sloti);
_kernel_oserror *swi_Enumerate_slots(uint32_t *restrict index, uint32_t *restrict r2);
_kernel_oserror *swi_Enumerate_units(uint32_t bus, uint32_t sloti, uint32_t *restrict index, uint32_t *restrict r2, uint32_t *restrict r3, uint32_t *restrict r4, uint32_t *restrict r5);
_kernel_oserror *swi_ControllerFeatures(uint32_t bus, uint32_t sloti, uint32_t index, uint32_t *value);
_kernel_oserror *swi_ReadRegister(uint32_t bus, uint32_t sloti, uint32_t rca, uint32_t index, void *buffer);
_kernel_oserror *swi_Op(sdioop_block_t *b);
_kernel_oserror *swi_ClaimDeviceVector(uint32_t bus, uint32_t sloti, uint32_t unit, void *handler, void *pw);
_kernel_oserror *swi_ReleaseDeviceVector(uint32_t bus, uint32_t sloti, uint32_t unit, void *handler, void *pw);

#endif
