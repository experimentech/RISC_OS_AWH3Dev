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

/** \file globals.c
 * Definitions of global variables.
 */

#include "globals.h"

sdhcinode_t *g_sdhci;
spinrwlock_t g_sdhci_lock = SPINRW_INITIALISER;
uint32_t     g_message_fd[4];
void        *g_module_pw;
