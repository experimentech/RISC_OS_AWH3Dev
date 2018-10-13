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

#ifndef COMMAND_H
#define COMMAND_H

#include <stdarg.h>
#include "kernel.h"

_kernel_oserror *command_sdfs(void);
_kernel_oserror *command_configure_syntax_sdfsdrive(void);
_kernel_oserror *command_status_sdfsdrive(void);
_kernel_oserror *command_syntax_sdfsdrive(void);
_kernel_oserror *command_configure_sdfsdrive(const char *drive);

#endif
