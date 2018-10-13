/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/**************************************************************************/
/* File:   options.h                                                      */
/*                                                                        */
/* Copyright [1999-2001] Pace Micro Technology PLC.  All rights reserved. */
/*                                                                        */
/* The copyright in this material is owned by Pace Micro Technology PLC   */
/* ("Pace").  This material is regarded as a highly confidential trade    */
/* secret of Pace.  It may not be reproduced, used, sold or in any        */
/* other way exploited or transferred to any third party without the      */
/* prior written permission of Pace.                                      */
/**************************************************************************/

#ifndef __options_h
#define __options_h

/* Defines */

/* Default ddumpbuf width */
#define DumpWidth_DefaultWidth 16u

/* Default padding limit for area name in debug output */
#define AreaPadLimit_DefaultLimit 16u

/* Types */

typedef struct debug_options
{
  char *taskname;
  char *filename;
  debug_device device;
  debug_device raw_device;
  debug_device trace_device;
  bool taskname_prefix;
  bool area_level_prefix;
  bool stamp_debug;
  bool screen_cornering;
  bool unbuffered_files;
  bool serial_lf;
  int serial_port_speed;
  int serial_port_number;
  size_t dump_width;
  size_t area_pad_limit;
}debug_options;

/* Functions */

void debug_options_initialise (void);
void debug_get_internal_options (debug_options *);
void debug_set_internal_options (debug_options);
void debug_set_internal_options_raw (void);

#endif
