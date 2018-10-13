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

/** \file free.c
 * Entry points from the Free module.
 */

#include <stddef.h>
#include <string.h>
#include <stdint.h>
#include "swis.h"

#include "Interface/Free.h"

#include "free.h"
#include "globals.h"

#define FILECORE_DISCNAME_MAX (10)

/** Data block for free_get_space */
typedef struct
{
  uint32_t total;
  uint32_t free;
  uint32_t used;
} free_space_t;

/** Data block for free_get_space */
typedef struct
{
  uint64_t total;
  uint64_t free;
  uint64_t used;
} free_space64_t;

/** Like strncpy, but the input string may be terminated by any control character */
static char *strncpy_ctrl(char *destination, const char *source, size_t num)
{
  const char *in = source;
  char *out = destination;
  while (out < destination + num && (unsigned char) *in >= ' ')
    *out++ = *in++;
  while (out < destination + num)
    *out++ = '\0';
  return destination;
}

static _kernel_oserror *get_space(const char *disc_specifier, uint64_t *total, uint64_t *free, uint64_t *used)
{
  disc_record_t record;
  uint32_t free_lo, free_hi;
  _kernel_oserror *e = _swix(SDFS_DescribeDisc, _INR(0,1), disc_specifier, &record);
  if (!e)
    e = _swix(SDFS_FreeSpace64, _IN(0)|_OUTR(0,1), disc_specifier, &free_lo, &free_hi);
  if (e)
  {
    /* For example, at the time of writing, FileCore_FreeSpace64 fails if the disc is FAT formatted */
    free_hi = 0;
    e = _swix(SDFS_FreeSpace, _IN(0)|_OUT(0), disc_specifier, &free_lo);
  }
  if (e)
    return e;
  
  *total = record.disc_size + ((uint64_t) record.disc_size_2 << 32);
  *free  = free_lo + ((uint64_t) free_hi << 32);
  *used  = *total - *free;
  return NULL;
}

static _kernel_oserror *free_get_name(char *buffer, const char *disc_specifier, size_t *return_length)
{
  disc_record_t record;
  _kernel_oserror *e = _swix(SDFS_DescribeDisc, _INR(0,1), disc_specifier, &record);
  if (e)
    return e;

  strncpy_ctrl(buffer, (char *) record.disc_name, FILECORE_DISCNAME_MAX);
  if (buffer[0] == 0)
  {
    buffer[0] = ':';
    strncpy_ctrl(buffer + 1, disc_specifier, 9);
  }
  buffer[FILECORE_DISCNAME_MAX] = '\0';
  *return_length = strlen(buffer) + 1;
  return NULL;
}

static _kernel_oserror *free_get_space(free_space_t *buffer, const char *disc_specifier)
{
  uint64_t total, free, used;
  _kernel_oserror *e = get_space(disc_specifier, &total, &free, &used);
  if (e)
    return e;
  buffer->total = total >= 1ull<<32 ? -1u : (uint32_t) total;
  buffer->free  = free  >= 1ull<<32 ? -1u : (uint32_t) free;
  buffer->used  = used  >= 1ull<<32 ? -1u : (uint32_t) used;
  return NULL;
}

static _kernel_oserror *free_compare_path(const char *filename, const char *disc_specifier, uint32_t *return_flags)
{
  _kernel_oserror *e = NULL;
  char file_disc_spec[FILECORE_DISCNAME_MAX + 1];
  char file_disc_name[FILECORE_DISCNAME_MAX + 1];
  /* This algorithm is based on that used by Free internally for ADFS */
  const char *p = strchr(filename, '.');
  size_t len = p == NULL ? FILECORE_DISCNAME_MAX : MIN(FILECORE_DISCNAME_MAX, p - filename);
  strncpy(file_disc_spec, filename, len);
  file_disc_spec[len] = '\0';
  e = free_get_name(file_disc_name, file_disc_spec, &len);
  if (e)
    return e;
  *return_flags = strcmp(file_disc_name, disc_specifier) ? 0 : _Z;
  return NULL;
}

static _kernel_oserror *free_get_space64(free_space64_t *buffer, const char *disc_specifier)
{
  return get_space(disc_specifier, &buffer->total, &buffer->free, &buffer->used);
}

_kernel_oserror *free_handler(_kernel_swi_regs *r, uint32_t *return_flags)
{
  *return_flags = 0;
  switch (r->r[0])
  {
    case FreeReason_GetName:
      return free_get_name((char *) r->r[2], (const char *) r->r[3], (size_t *) &r->r[0]);
    case FreeReason_GetSpace:
      return free_get_space((free_space_t *) r->r[2], (const char *) r->r[3]);
    case FreeReason_ComparePath:
      return free_compare_path((const char *) r->r[2], (const char *) r->r[3], return_flags);
    case FreeReason_GetSpace64:
      r->r[0] = 0;
      return free_get_space64((free_space64_t *) r->r[2], (const char *) r->r[3]);
  }
  return NULL;
}
