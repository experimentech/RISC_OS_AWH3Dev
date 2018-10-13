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

#ifndef MISCOP_H
#define MISCOP_H

#include <stdint.h>

#include "globals.h"

low_level_error_t miscop_Mount(uint32_t drive, uint32_t byte_address, uint8_t * restrict buffer, size_t length, disc_record_t * restrict disc_record);
void miscop_PollChanged(uint32_t drive, uint32_t * restrict sequence_number, uint32_t * restrict result_flags);
void miscop_LockDrive(uint32_t drive);
void miscop_UnlockDrive(uint32_t drive);
void miscop_PollPeriod(uint32_t drive, uint32_t * restrict poll_period, const char ** restrict media_type_name);
void miscop_Eject(uint32_t drive);
void miscop_DriveStatus(uint32_t drive, uint32_t *status_flags);

#endif
