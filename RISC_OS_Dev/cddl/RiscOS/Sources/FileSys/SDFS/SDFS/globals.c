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

/** \file globals.c
 * Definitions of global variables.
 */

#include "globals.h"

uint32_t     g_message_fd[4];
void        *g_module_pw;
void        *g_filecore_pw;
void       (*g_filecore_callback_floppy_op_completed)(void);
void       (*g_filecore_callback_winnie_op_completed)(void);
char         g_media_type_name[MEDIA_TYPE_NAME_LEN];
drive_t      g_drive[NUM_FLOPPIES + NUM_WINNIES];
spinrwlock_t g_drive_lock = SPINRW_INITIALISER;
uint8_t      g_default_drive_toggle;
