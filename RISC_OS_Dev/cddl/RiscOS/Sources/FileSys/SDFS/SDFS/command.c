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

/** \file command.c
 * Implementation of star commands.
 */

#include <stdlib.h>
#include <stddef.h>
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include "swis.h"

#include "Global/CMOS.h"
#include "Global/FSNumbers.h"
#include "Global/OsBytes.h"
#include "Global/RISCOS.h"
#include "Interface/HighFSI.h"

#include "SDFSHdr.h"
#include "command.h"
#include "globals.h"
#include "message.h"

_kernel_oserror *command_sdfs(void)
{
  return _swix(OS_FSControl, _INR(0,1), FSControl_SelectFS, fsnumber_SDFS);
}

_kernel_oserror *command_configure_syntax_sdfsdrive(void)
{
  printf("%s\n", message_lookup_direct("CSDFDRI"));
  return NULL;
}

_kernel_oserror *command_status_sdfsdrive(void)
{
  uint32_t default_drive;
  _swix(OS_Byte, _INR(0,1)|_OUT(2), OsByte_ReadCMOS, DEFAULT_DRIVE_BYTE, &default_drive);
  default_drive = ((default_drive & DEFAULT_DRIVE_MASK) >> DEFAULT_DRIVE_SHIFT) ^ g_default_drive_toggle;
  printf("SDFSdrive  %u\n", default_drive);
  return NULL;
}

_kernel_oserror *command_syntax_sdfsdrive(void)
{
  printf("%s\n", message_lookup_direct("SSDFDRI"));
  return NULL;
}

_kernel_oserror *command_configure_sdfsdrive(const char *drive)
{
  uint32_t default_drive;
  uint32_t cmos;
  char *after;
  errno = 0;
  default_drive = (uint32_t) strtoul(drive, &after, 10);
  if (errno == ERANGE || after == drive)
    return configure_NUMBER_NEEDED;
  if (default_drive > DEFAULT_DRIVE_MASK >> DEFAULT_DRIVE_SHIFT)
    return configure_TOO_LARGE;
  _swix(OS_Byte, _INR(0,1)|_OUT(2), OsByte_ReadCMOS, DEFAULT_DRIVE_BYTE, &cmos);
  cmos = cmos &~ DEFAULT_DRIVE_MASK;
  cmos |= (default_drive ^ g_default_drive_toggle) << DEFAULT_DRIVE_SHIFT;
  _swix(OS_Byte, _INR(0,2), OsByte_WriteCMOS, DEFAULT_DRIVE_BYTE, cmos);
  return NULL;
}
