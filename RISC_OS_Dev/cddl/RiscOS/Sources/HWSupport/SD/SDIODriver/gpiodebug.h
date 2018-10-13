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

#ifndef GPIODEBUG_H
#define GPIODEBUG_H

#ifdef GPIODEBUG

#include <stdint.h>

/* Use the GPIO lines as a bitfield */
#define GPIO_ERROR      (0x80)
#define GPIO_WRITING    (0x40)
#define GPIO_STATE_MASK (0x3F)

void gpiodebug_init(void);
void gpiodebug_set(uint8_t mask, uint8_t toggle);

#else

#define gpiodebug_init(x)
#define gpiodebug_set(x,y)

#endif

#endif
