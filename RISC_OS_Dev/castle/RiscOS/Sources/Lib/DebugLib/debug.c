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
/* File:    debug.c                                                       */
/* Purpose: The file contains the generic routines, exported to callers   */
/*          of DebugLib.  Different output methods are implemented in     */
/*          seperate files.  Buffering and layers specifier parsing are   */
/*          done in seperate files also.                                  */
/*                                                                        */
/* Copyright [1999-2001] Pace Micro Technology PLC.  All rights reserved. */
/*                                                                        */
/* The copyright in this material is owned by Pace Micro Technology PLC   */
/* ("Pace").  This material is regarded as a highly confidential trade    */
/* secret of Pace.  It may not be reproduced, used, sold or in any        */
/* other way exploited or transferred to any third party without the      */
/* prior written permission of Pace.                                      */
/**************************************************************************/

/* -------------------------------------- LIBRARY IMPORTS --------------------------------------- */
#include <stdarg.h>
#include <time.h>
#include <ctype.h>

#include "include.h"

#include "Trace/Trace.h"                /* Trace by JSmith */
#include "remotedb/remote.h"            /* Remote DB code by Rich Buckley */
#include "PDebug/PDebug.h"              /* PDebug by JSmith */

#include "misc.h"
#include "options.h"
#include "debugit.h"
#include "file.h"
#include "pdebug.h"
#include "printf.h"
#include "serial.h"
#include "socket.h"
#include "tml.h"
#include "tracker.h"
#include "buffering.h"
#include "parse.h"
#include "globals.h"
#include "debug.h"
#include "dadebug.h"
#include "brainlink.h"
#include "reporter.h"
#include "syslog.h"
#include "hal.h"

#include "VersionNum"

/* -------------------------------------- GLOBAL VARIABLES -------------------------------------- */

debug_options debug_current_options;

/* -------------------------------------- LOCAL VARIABLES --------------------------------------- */

static const char debug_version_string[] = Module_FullVersion;

static debug_device sysvar_provided_device = UNSET_OUTPUT;    /* The variable to hold output device specified by
                                                                 system variable */

static debug_device sysvar_provided_raw_device = UNSET_OUTPUT; /* The variable to hold the raw output device
                                                                   specified by system variable */

static debug_device sysvar_provided_tracedevice = UNSET_OUTPUT;  /* The variable to hold the trace output device
                                                                    specified by system variable */

static char *debug_level_specifier = NULL;            /* Contents of area-level specifying sys var */

static char debug_buffer[Debug_Buffer_Size];     /* Buffer for debug data */

static int debug_global_indent = 0;

static const char *debug_always_ignore = " PDebug_* Trace_* remote_debug_* debug_* _dprintf _dvprintf"
                                         " _dfprintf ddumpbuf send sendto select socket socketclose"
                                         " recv recvfrom connect gethostbyname";

typedef struct debug_output_method
{
  /* Functions */
  bool (*initialise)(void);
  void (*output)(const char *, size_t);
  void (*quit)(void);

  /* Variables */
  bool open;
  bool start_of_line;
}debug_output_method;

static debug_output_method methods[16] =
{
  {NULL,                 NULL,                   NULL,                 false,  true},   /* NULL_OUTPUT */
  {debug_tracker_init,   debug_tracker_output,   debug_tracker_quit,   false,  true},   /* TRACKER_OUTPUT */
  {NULL,                 debug_printf_output,    NULL,                 false,  true},   /* PRINTF_OUTPUT */
  {NULL,                 NULL,                   NULL,                 false,  true},   /* NOTUSED_OUTPUT */
  {debug_pdebug_init,    debug_pdebug_output,    debug_pdebug_quit,    false,  true},   /* PDEBUG_OUTPUT */
  {debug_socket_init,    debug_socket_output,    debug_socket_quit,    false,  true},   /* SOCKET_OUTPUT */
  {debug_debugit_init,   debug_debugit_output,   NULL,                 false,  true},   /* DEBUGIT_OUTPUT */
  {debug_tml_init,       debug_tml_output,       NULL,                 false,  true},   /* TML_OUTPUT */
  {debug_file_init,      debug_file_output,      debug_file_quit,      false,  true},   /* FILE_OUTPUT */
  {debug_serial_init,    debug_serial_output,    debug_serial_quit,    false,  true},   /* SERIAL_OUTPUT */
  {debug_dadebug_init,   debug_dadebug_output,   NULL,                 false,  true},   /* DADEBUG_OUTPUT */
  {debug_brainlink_init, debug_brainlink_output, debug_brainlink_quit, false,  true},   /* BRAINLINK_OUTPUT */
  {debug_reporter_init,  debug_reporter_output,  debug_reporter_quit,  false,  true},   /* REPORTER_OUTPUT */
  {debug_syslog_init,    debug_syslog_output,    debug_syslog_quit,    false,  true},   /* SYSLOG_OUTPUT */
  {debug_hal_init,       debug_hal_output,       NULL,                 false,  true},   /* HAL_OUTPUT */
  {NULL,                 NULL,                   NULL,                 false,  true}    /* UNSET_OUTPUT */

};

typedef struct debug_area_level_pair
{
  const char *area;
  char level;
}debug_area_level_pair;

typedef struct debug_sysvar_area_allowed_pair
{
  const char *area;
  unsigned int allowed;
}debug_sysvar_area_allowed_pair;

typedef enum
{
  positive_match,
  negative_match,
  no_match
}debug_tristate;

static debug_sysvar_area_allowed_pair debug_sysvar_pairs[32];
static int debug_sysvar_num_pairs = 0;

/* ------------------------------------ LOCAL FUNCTIONS ----------------------------------------- */


/************************************************************************/
/* debug_check_level                                                    */
/*                                                                      */
/* Checks the area-level pair passed in a dprintf with the system       */
/* variable specifying what areas and levels are wanted, and returns    */
/* true if the line should be output, and false if it shouldn't         */
/*                                                                      */
/* Parameters: area_level_in - The area-level pair                      */
/*                                                                      */
/* Returns:    true or false.                                           */
/*                                                                      */
/************************************************************************/
static bool debug_check_level (const char *area_level_in)
{
  debug_tristate matched = no_match;
  debug_area_level_pair pairs[16];
  char *step, *match;
  int i = 0, j, num_pairs;
  char *specifier;

#ifdef DEBUG
  if (strcmp (area_level_in, "__DebugLib") == 0)
    return true;
#endif

  /* If we've got no sysyvar area/level pairs, we output */
  if (debug_sysvar_num_pairs == 0)
    return true;

  /* If the area_level is NULL, or an empty string we output */
  if ((area_level_in == NULL) || strlen (area_level_in) == 0)
    return true;

  /*** We're through to here, we're gonna have to do some real matching ***/

  /* Take a copy so we can locally modify it */

  specifier = debug_misc_strdup (area_level_in);

  /* Parse the specifier string into a list of tokens of all the area specifiers */
  step = strtok (specifier, ",");
  pairs[i++].area = step;
  while ((i < 16) && (step = strtok (NULL, ",")) != NULL)
  {
    pairs[i++].area = step;
  };
  num_pairs = i;

  internal_dprintf(("__DebugLib", "num_pairs = %d\n", num_pairs));

  /* Step through the area specifiers */
  for (i=0; i < num_pairs; i++)
  {
    /* First, extract the level from the current specifier */

    /* If there's an _ in the current specifier ... */
    if ((match = strrchr (pairs[i].area, '_')) != NULL)
    {
      *match = '\0';

      /* If there's a number after the _ ... */
      if ((match+1) != NULL)
      {
        /* Extract it */
        pairs[i].level = atoi (match+1);
      }
      else
      {
        /* Else, we default to least verbose */
        pairs[i].level = 0;
      }
    }
    else
    {
      /* Else, we default to least verbose */
      pairs[i].level = 0;
    }

    /* Next, step through the system variable areas, checking for matches with the current specifier */

    for (j=0; j < debug_sysvar_num_pairs; j++)
    {
      /* internal_dprintf (("__DebugLib", "sysvar[%d] = %s (%x)\n", j, sysvar_pairs[j].area,
                            sysvar_pairs[j].allowed)); */
      /* If the current sysvar area matches the current debug specifier area ... */
      if (strcmp (pairs[i].area, debug_sysvar_pairs[j].area) == 0)
      {
        /* Check if the specifier level lies in the included level mask of the sysvar area */
        if ( (debug_sysvar_pairs[j].allowed & _LEVEL_INCLUDED(pairs[i].level)) &&
            !(debug_sysvar_pairs[j].allowed & _LEVEL_EXCLUDED(pairs[i].level)))
        {
          /* Positive match overrides any kind of match */
          matched = positive_match;
        }
        else if ( (debug_sysvar_pairs[j].allowed & _LEVEL_EXCLUDED(pairs[i].level)) &&
                 !(debug_sysvar_pairs[j].allowed & _LEVEL_INCLUDED(pairs[i].level)))
        {
          /* Negative match only overrides a non-match */
          if (matched == no_match)
            matched = negative_match;
        }
      }
      /* Else, if the sysvar specifier is the catchall, and we've not yet decided on match/not match ... */
      else if ((strcmp (debug_sysvar_pairs[j].area, "*") == 0) && (matched == no_match))
      {
        /* Check if the specifier level lies in the allowed levels of the sysvar area */
        if (debug_sysvar_pairs[j].allowed & _LEVEL_INCLUDED(pairs[i].level))
          matched = positive_match;
        else if (debug_sysvar_pairs[j].allowed & _LEVEL_EXCLUDED(pairs[i].level))
          matched = negative_match;
      }
    }
  }

  /* Free up some memory */
  free (specifier);

  if (matched == positive_match)
    return true;
  else
    return false;
}


/************************************************************************/
/* debug_level_specifier_print                                          */
/*                                                                      */
/* Ikkle helper function to print out a level specifying "allowed"      */
/* word in a human readable form.                                       */
/*                                                                      */
/* e.g. 01236789                                                        */
/*                                                                      */
/* Parameters: allowed - The level specifying word from a               */
/*                       debug_sysvar_area_allowed_pair.allowed         */
/*                                                                      */
/* Returns:    Pointer to local static string containing human          */
/*             readable representatiom of "allowed".                    */
/*                                                                      */
/************************************************************************/
static const char *debug_level_specifier_print(int allowed)
{
  static char str[11];
  int i;
  char *p = str;

  for (i=0 ; i < 10; i++)
  {
    if ((allowed & _LEVEL_INCLUDED(i)) && !(allowed & _LEVEL_EXCLUDED(i)))
    {
      *p = '0' + i;
      p++;
    }
  }

  *p = '\0';

  return str;
}


/************************************************************************/
/* debug_setup_filename                                                 */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the filename for   */
/* the file output method using either sysvar or param passed into      */
/* debug_initialise                                                     */
/*                                                                      */
/* Parameters: fname  - filename passed in debug_initialise             */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_filename (const char *fname)
{
  char *tmp_sysvar_name;

  tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$Filename_") + 1);
  sprintf (tmp_sysvar_name, "DebugLib$Filename_%s", debug_current_options.taskname);

  if (debug_current_options.filename)
    free (debug_current_options.filename);
  debug_current_options.filename = debug_misc_getenv_malloc (tmp_sysvar_name);
  if (debug_current_options.filename == NULL)
  {
    if (fname && strlen (fname))
    {
      debug_current_options.filename = debug_misc_strdup (fname);
    }
  }

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);
}


/************************************************************************/
/* debug_setup_unbuffered                                               */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the whether files  */
/* should be unbuffered for the file outpit method.                     */
/* debug_initialise                                                     */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_unbuffered (void)
{
  char *tmp_sysvar_name;
  char *tmp_string;

  tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$UnbufferedFiles_") + 1);
  sprintf (tmp_sysvar_name, "DebugLib$UnbufferedFiles_%s", debug_current_options.taskname);

  tmp_string = debug_misc_getenv_malloc (tmp_sysvar_name);
  if (tmp_string != NULL)
  {
    free (tmp_string);
    debug_current_options.unbuffered_files = true;
  }
  else
    debug_current_options.unbuffered_files = false;

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);
}


/************************************************************************/
/* debug_set_level                                                      */
/*                                                                      */
/* A callback used by the level parsing code to fill the structure      */
/* holding the pairs of values that set what debug levels are output.   */
/*                                                                      */
/* Parameters: area - The area name to set                              */
/*             allowed - The allowed mask                               */
/*                                                                      */
/* Returns:    nothing                                                  */
/*                                                                      */
/************************************************************************/
static void debug_set_level (const char *area, unsigned int allowed)
{
  debug_sysvar_pairs[debug_sysvar_num_pairs].area = area;
  debug_sysvar_pairs[debug_sysvar_num_pairs++].allowed = allowed;
}


/************************************************************************/
/* debug_setup_level                                                    */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the level          */
/* specifier, which is read from a system variable                      */
/*                                                                      */
/*                                                                      */
/* Parameters: sysvar - system variable specifier from debug_initialise */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_level (const char *sysvar)
{
  char *tmp_sysvar_name;

  /* Check for level sysvar specifier */
  if (sysvar && strlen (sysvar))
  {
    tmp_sysvar_name = debug_misc_strdup (sysvar);
  }
  else
  {
    /* .. Setup a string with the name of the default system variable that will
       specify the debug area/level(s) */
    tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$Level_") + 1);
    sprintf (tmp_sysvar_name, "DebugLib$Level_%s", debug_current_options.taskname);
  }

  if (debug_level_specifier != NULL)
    free (debug_level_specifier);
  debug_level_specifier = debug_misc_getenv_malloc (tmp_sysvar_name);

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);

  if (debug_level_specifier && strlen (debug_level_specifier))
  {
    debug_sysvar_num_pairs = 0;
    debug_parse_levels (debug_set_level, debug_level_specifier);
  }
}


/************************************************************************/
/* debug_setup_device                                                   */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the device used    */
/* for normal debug output. Read from a system variable                 */
/*                                                                      */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_device (void)
{
  char *tmp_sysvar_name;
  char *tmp_string;

  /* Setup a string with the name of the system variable that will
     specify the output device */
  tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$Device_") + 1);
  sprintf (tmp_sysvar_name, "DebugLib$Device_%s", debug_current_options.taskname);

  /* Read the system variable */
  tmp_string = debug_misc_getenv_malloc (tmp_sysvar_name);

  if (tmp_string)
  {
    sysvar_provided_device = (debug_device) atoi (tmp_string);
    debug_set_device (sysvar_provided_device);
    free (tmp_string);
  }

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);
}


/************************************************************************/
/* debug_setup_raw_device                                               */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the device used    */
/* for raw debug output. Read from a system variable                    */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_raw_device (void)
{
  char *tmp_sysvar_name;
  char *tmp_string;

  /* Setup a string with the name of the system variable that will
     specify the output device */
  tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$RawDevice_") + 1);
  sprintf (tmp_sysvar_name, "DebugLib$RawDevice_%s", debug_current_options.taskname);

  /* Read the system variable */
  tmp_string = debug_misc_getenv_malloc (tmp_sysvar_name);

  if (tmp_string)
  {
    sysvar_provided_raw_device = (debug_device) atoi (tmp_string);

    if (sysvar_provided_raw_device != UNSET_OUTPUT)
      debug_current_options.raw_device = sysvar_provided_raw_device;

    free (tmp_string);
  }

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);
}


/************************************************************************/
/* debug_setup_tracedevice                                              */
/*                                                                      */
/* Auxiliary function for debug_initialise.  Sets up the device used    */
/* for trace output. Read from a system variable.                       */
/*                                                                      */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    nothing.                                                 */
/*                                                                      */
/************************************************************************/
static void debug_setup_tracedevice (void)
{
  char *tmp_sysvar_name;
  char *tmp_string;

  /* Setup a string with the name of the system variable that will
     specify the trace output device */
  tmp_sysvar_name = malloc (strlen (debug_current_options.taskname) + strlen ("DebugLib$TraceDevice_") + 1);
  sprintf (tmp_sysvar_name, "DebugLib$TraceDevice_%s", debug_current_options.taskname);

  tmp_string = debug_misc_getenv_malloc (tmp_sysvar_name);

  /* If we got something out of the system variable ... */
  if (tmp_string)
  {
    /* ... convert it to a output device type */
    sysvar_provided_tracedevice = (debug_device) atoi (tmp_string);
    free (tmp_string);
  }

  /* Free up the temp string */
  if (tmp_sysvar_name)
    free (tmp_sysvar_name);
}


/************************************************************************/
/* debug_close_device                                                   */
/*                                                                      */
/* Function closes the currently active device.                         */
/*                                                                      */
/* Parameters: device - integer constant for devices.                   */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
static void debug_close_device (debug_device device)
{
  time_t timer;

  /* Only close the device if it's open */
  if (methods[device].open == true)
  {
    /* And only send the close text if it's not the raw device */
    if (device != debug_current_options.raw_device)
    {
      time (&timer);
      _dfprintf("",device,"\n***** Debug Session Terminated *************************************\n");
      _dfprintf("", device, "Task: %s\n", debug_current_options.taskname);
      _dfprintf("", device, "Time: %s", ctime(&timer));
      _dfprintf("", device, "%s\n", COPYRIGHT_MESSAGE);
      _dfprintf("", device, "********************************************************************\n");
    }

    if (methods[device].quit)
      methods[device].quit();
    methods[device].open = false;

    if (device == debug_current_options.device)
      debug_current_options.device = NULL_OUTPUT;
  }
}


/************************************************************************/
/* debug_output_prefix                                                  */
/*                                                                      */
/* Function outputs the debug output prefix that is needed based on     */
/* the current configuration, and the device identifer that is passed   */
/* in.                                                                  */
/*                                                                      */
/* Parameters: area_level - Levels specified in the _dprintf().         */
/*             device - the debug device to send the buffer to          */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
static void debug_output_prefix (const char *area_level, debug_device device)
{
  if (debug_current_options.taskname_prefix == true  && device != TRACKER_OUTPUT)
  {
    methods[device].output (debug_current_options.taskname, strlen (debug_current_options.taskname));
  }
  if (debug_current_options.stamp_debug == true)
  {
    char buf[20];
    time_t timer;
    struct tm *t;

    time (&timer);

    t = localtime (&timer);

    strftime (buf, sizeof (buf), " %H:%M:%S", t);
    methods[device].output (buf, strlen (buf));
  }
  if (debug_current_options.area_level_prefix == true)
  {
    const char *str;
    char *out;

    if ((area_level == NULL) || (*area_level == '\0'))
      str = "ALERT";
    else
      str = area_level;

    if (debug_current_options.area_pad_limit > 0)
    {
      out = malloc (debug_current_options.area_pad_limit + 1);
      if (out)
      {
        strncpy (out, str, debug_current_options.area_pad_limit);
        if (strlen(str) < debug_current_options.area_pad_limit)
        {
          /* Pad */
          int i;

          for (i=strlen(str) ; i<debug_current_options.area_pad_limit ; i++)
            out[i] = ' ';
          out[i] = '\0';
        }
        else
        {
          /* Truncate */
          out[debug_current_options.area_pad_limit] = '\0';
        }
      }
    }
    else
      out = (char*)str;

    methods[device].output (" [", strlen (" ["));
    methods[device].output (out, strlen (out));
    methods[device].output ("]", strlen ("]"));

    if (debug_current_options.area_pad_limit > 0)
      free (out);
  }
  if ((debug_current_options.taskname_prefix == true  && device != TRACKER_OUTPUT) ||
      (debug_current_options.stamp_debug == true) ||
      (debug_current_options.area_level_prefix == true))
  {
    methods[device].output (": ", strlen (": "));
  }
}


/************************************************************************/
/* debug_output_data                                                    */
/*                                                                      */
/* Function outputs the conventional debuglib output with prefixing,    */
/* timestamping etc.                                                    */
/*                                                                      */
/* Parameters: area_level - Levels specified in the _dprintf().         */
/*             device - the debug device to send the buffer to          */
/*             buffer - data to be streamed.                            */
/* Parameters: void.                                                    */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
static void debug_output_data (const char *area_level, debug_device device, const char *buffer)
{
  if (debug_buff_status.enabled != false)
  {
    debug_buffer_stream (buffer);
  }
  else
  {
    bool rc = true;

    /* If we've been passed an invalid device, don't bother */
    if (device <= NULL_OUTPUT || device >= UNSET_OUTPUT || device == NOTUSED_OUTPUT)
      return;

    /* If the device has no output method, don't bother */
    if (methods[device].output == NULL)
      return;

    /* If we've got an empty string, return too */
    if ((buffer == NULL) || (*buffer == '\0'))
      return;

    /* Check that the output device is open */
    if (methods[device].open == false)
    {
      /* If it's not, initialise it */
      if (methods[device].initialise)
      {
        rc = methods[device].initialise ();
      }
      if (rc == true)
        methods[device].open = true;
    }

    /* And if everything is OK, go ahead and output the buffer */
    if (rc == true)
    {
      const char *stepper = buffer, *match;

      if (methods[device].start_of_line == true)
      {
        debug_output_prefix (area_level, device);
        methods[device].start_of_line = false;
      }
      do
      {
        match = strchr (stepper, '\n');
        if (match)
        {
          /* Output up to and including the \n */
          methods[device].output (stepper, match - stepper + 1);
          stepper = match + 1;
          if (*stepper == NULL)
          {
            /* \n is at the end of "buffer" */
            methods[device].start_of_line = true;
          }
          else
          {
            /* \n in middle of "buffer" */
            debug_output_prefix (area_level, device);
          }
        }
        else
        {
          /* No more \ns */
          methods[device].output (stepper, strlen (stepper));
        }
      }
      while ((match != NULL) && (*stepper != NULL));
    }
  }
}


/************************************************************************/
/* debug_trace_enter                                                    */
/*                                                                      */
/* Function is called when a function is entered provided trace is      */
/* running.                                                             */
/*                                                                      */
/* Parameters: format - fprintf configuration.                          */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
static void debug_trace_enter (const char *fname)
{
  int i = 0;
  char *buffer;
  char buffer2[256];

  buffer = malloc (strlen ("Trace: 999:")+(strlen(" |")*debug_global_indent)+strlen(" \n")+strlen (fname)+1);

  if (buffer)
  {
    sprintf (buffer, "Trace: %3d:", debug_global_indent);

    for (i = 0; i < debug_global_indent; i++)
    {
      strcat (buffer, " |");
    }
    sprintf (buffer2, " %s\n", fname);
    strcat (buffer, buffer2);

    _dfprintf ("Trace", debug_current_options.trace_device, buffer);

    free (buffer);
  }

  debug_global_indent++;
}


/************************************************************************/
/* debug_trace_exit                                                     */
/*                                                                      */
/* Function is called when a function is exited provided trace is       */
/* running.                                                             */
/*                                                                      */
/* Parameters: format - fprintf configuration.                          */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
static void debug_trace_exit (const char* fname)
{
  int i = 0;
  char *buffer;
  char buffer2[256];

  buffer = malloc (strlen ("Trace: 999:")+(strlen(" |")*debug_global_indent)+strlen("~\n")+strlen (fname)+1);

  if (buffer)
  {
    sprintf (buffer, "Trace: %3d:", debug_global_indent-1);

    for (i=0; i < debug_global_indent-1; i++)
    {
      strcat (buffer, " |");
    }

    sprintf (buffer2, "~%s\n", fname);
    strcat (buffer, buffer2);

    _dfprintf ("Trace", debug_current_options.trace_device, buffer);

    free (buffer);
  }

  debug_global_indent--;
}


/************************************************************************/
/* debug_terminate                                                      */
/*                                                                      */
/* Function terminates the current debug session.                       */
/*                                                                      */
/* Parameters: none                                                     */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_terminate (void)
{
  int i;

  for (i = (NULL_OUTPUT+1); i < UNSET_OUTPUT; i++)
    debug_close_device ((debug_device)i);
}


/* --------------------------------- EXPORTED FUNCTIONS -------------------------------------- */


/************************************************************************/
/* debug_initialise                                                     */
/*                                                                      */
/* Function initialises the library                                     */
/*                                                                      */
/* Parameters: name - name of app that is calling the library.          */
/*             fame - file for debug output to FILE                     */
/*             sysvar - System Variable to override default area/level  */
/*                      specifiying system variable. Uses default if    */
/*                      NULL or "" is passed.                           */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_initialise (const char *name, const char *fname, const char *sysvar)
{
  /* Set up our atexit handler */
  atexit(debug_terminate);

  /* Set default DebugLib options */
  debug_options_initialise ();

  /* Setup taskname */
  if (debug_current_options.taskname)
    free (debug_current_options.taskname);
  if (name && *name)
    debug_current_options.taskname = debug_misc_strdup (name);
  else
    debug_current_options.taskname = debug_misc_strdup ("DefaultName");

  /* Setup filename */
  debug_setup_filename (fname);

  /* Setup whether we should be doing unbuffered file writes */
  debug_setup_unbuffered ();

  /* Setup the level specifier */
  debug_setup_level (sysvar);

  /* Setup the device */
  debug_setup_device ();

  /* Setup the raw device */
  debug_setup_raw_device ();

  /* Setup the trace device */
  debug_setup_tracedevice ();

  /* Setup the buffering code */
  debug_buffer_startup();
}


/************************************************************************/
/* debug_read_device                                                    */
/*                                                                      */
/* Function returns the identifier of the currently active debug output */
/* device.                                                              */
/*                                                                      */
/* Parameters: void.                                                    */
/*                                                                      */
/* Returns:    debug device identifier.                                 */
/*                                                                      */
/************************************************************************/
debug_device debug_read_device (void)
{
  debug_device device = UNSET_OUTPUT;

  if (sysvar_provided_device != UNSET_OUTPUT)
    device = sysvar_provided_device;
  else
    device = debug_current_options.device;

  return device;
}


/************************************************************************/
/* debug_set_device                                                     */
/*                                                                      */
/* Function selects the debug output device                             */
/*                                                                      */
/* Parameters: device - device specifer.                                */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_set_device (debug_device device)
{
  time_t timer;
  bool rc = false;

  /* Fault invalid devices */
  if (device < NULL_OUTPUT || device > UNSET_OUTPUT)
    return;

  if (debug_buff_status.enabled == false)
  {
    /* Buffering is off, so proceed */

    /* If we've been provided with an output device by a sysvar, we want to
       override the the requested output device with the one in the sysvar */
    if (sysvar_provided_device != UNSET_OUTPUT)
      device = sysvar_provided_device;

    if ((device == debug_current_options.device) &&
        (methods[device].open == true))
    {
      /* No need to do anything, escape */
      return;
    }

    /* Close down previous debug output */
    debug_close_device (debug_current_options.device);

    if (methods[device].initialise)
      rc = methods[device].initialise();
    else
      rc = true;

    /* If we've initialised correctly, set the debug device and output DebugLib header */
    if (rc == true)
    {
      methods[device].open = true;
      debug_current_options.device = device;

      time (&timer);
      _dprintf ("", "\n***** Debug Session Started **************************************\n");
      _dprintf ("", "%s\n", COPYRIGHT_MESSAGE);
      _dprintf ("", "System: DebugLib %s\n", debug_version());
      _dprintf ("", "        remotedb %s\n", remote_debug_version());
      _dprintf ("", "        PDebug %s\n", PDebug_Version());
      _dprintf ("", "Task:   %s\n", debug_current_options.taskname);
      _dprintf ("", "Time:   %s", ctime(&timer));
      {
        if (debug_sysvar_num_pairs < 1)
        {
          _dprintf ("", "Levels: Not specified.\n");
        }
        else
        {
          int i;

          _dprintf ("", "Levels:\n");

          for (i=0 ; i < debug_sysvar_num_pairs; i++)
          {
            _dprintf ("", "       Area: %s - %s\n", debug_sysvar_pairs[i].area,
                      debug_level_specifier_print(debug_sysvar_pairs[i].allowed));
          }
        }
      }
      _dprintf ("", "******************************************************************\n");
    }
  }
  else
  {
    if (sysvar_provided_device != UNSET_OUTPUT)
      device = sysvar_provided_device;

    debug_current_options.device = device;
  }
}


/************************************************************************/
/* debug_set_raw_device                                                 */
/*                                                                      */
/* Function sets up the raw device.                                     */
/*                                                                      */
/* Parameters: void.                                                    */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_set_raw_device (debug_device device)
{
  if (sysvar_provided_raw_device == UNSET_OUTPUT)
    debug_current_options.raw_device = device;
}


/************************************************************************/
/* debug_output                                                         */
/*                                                                      */
/* Function sends the debugging data to a valid location.               */
/*                                                                      */
/* Parameters: flags      - Bit 0 set:   Output raw                     */
/*                          Bit 0 unset: Output full info.              */
/*             area_level - Levels specified in the _dprintf().         */
/*             device - the debug device to send the buffer to          */
/*             buffer - data to be streamed.                            */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_output (unsigned int flags, const char *area_level, debug_device device,
                   const char *buffer)
{
  debug_options		local_opts;

  if (flags & 1u)
  {
    /* Bit 0 set, output raw with no timestamping, levelling, prefixing etc. */
    debug_get_internal_options(&local_opts);
    debug_set_internal_options_raw();
    debug_output_data (area_level, device, buffer);
    debug_set_internal_options(local_opts);
  }
  else
  {
    /* Bit 0 unset, output info based on options */
    debug_output_data (area_level, device, buffer);
  }
}


/************************************************************************/
/* _dvprintf                                                            */
/*                                                                      */
/* Function is equilivant to vprintf for debugging.                     */
/*                                                                      */
/*                                                                      */
/* Parameters: void.                                                    */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void _dvprintf(const char *area_level, const char *format, const va_list arg)
{
  if (debug_check_level (area_level) == true)
  {
    vsprintf (debug_buffer, format, arg);
    debug_output (0, area_level, debug_current_options.device, debug_buffer);
  }
}


/************************************************************************/
/* _dprintf                                                             */
/*                                                                      */
/* Function sends the data to the current output device                 */
/*                                                                      */
/* Parameters: format - printf configuration.                           */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void _dprintf (const char *area_level, const char *format, ...)
{
  va_list p;

  va_start (p, format);
  _dvprintf(area_level, format, p);
  va_end (p);
}


/************************************************************************/
/* _dprintf_raw                                                         */
/*                                                                      */
/* Function sends the data to the current output device                 */
/*                                                                      */
/* Parameters: void *  - Use by Dr. Smith's.                            */
/*             format  - printf args.                                   */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void _dprintf_raw (void *ref, const char *format, ...)
{
  va_list p;

  IGNORE(ref);

  va_start (p, format);

  /* We don't want level checking in here, so we won't be calling _dvprintf() */
  vsprintf(debug_buffer, format, p);
  debug_output(1, "", debug_current_options.raw_device, debug_buffer);

  va_end (p);
}


/************************************************************************/
/* _dfprintf                                                            */
/*                                                                      */
/* Function sends the data to the specified stream.                     */
/*                                                                      */
/* Parameters: format - fprintf configuration.                          */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void _dfprintf (const char *area_level, debug_device device, const char *format, ...)
{
  va_list p;

  if (debug_check_level (area_level) == true)
  {
    va_start (p, format);
    vsprintf (debug_buffer, format, p);
    va_end (p);

    debug_output (0, area_level, device, debug_buffer);
  }
}


/************************************************************************/
/* ddumpbuf                                                             */
/*                                                                      */
/* Function to dump a buffer to the current output device               */
/*                                                                      */
/* Parameters: buffer - data to dump                                    */
/*             size   - amount of data to dump                          */
/*             offset - offset to add to addresses                      */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void ddumpbuf (const char *area_level, const void *buffer, size_t size, size_t offset)
{
  if (debug_check_level (area_level) == true)
  {
    const size_t width = debug_current_options.dump_width;
    const size_t end = ((size + width - 1) / width) * width;
    const char *membuf = buffer;

    size_t i = 0, j;
    char *db;

    db = debug_buffer;
    *db = 0;

    while (i < end)
    {
      if ((i % width) == 0)
      {
        if (i)
        {
          db += sprintf (db, ": ");
          for (j = i - width; j != i; ++j)
          {
            db += sprintf (db, "%c", (membuf[j]>=32 && membuf[j] != 0x7f) ? membuf[j] : '.');
          }
          sprintf (db, "\n");
          debug_output (0, area_level, debug_current_options.device, debug_buffer);
          db = debug_buffer;
        }
        db += sprintf (db, "%04x: ", i + offset);
      }

      if (i>=size)
      {
        db += sprintf (db, "   ");
      }
      else
      {
        db += sprintf (db, "%02x ", membuf[i]);
      }
      ++i;
    }

    if (i)
    {
      for (db += sprintf (db, ": "), j = i - width; j != i; ++j)
      {
        db += sprintf (db, "%c", j>=size ? ' ' : (membuf[j]>=32 && membuf[j] != 0x7f) ? membuf[j] : '.');
      }
      sprintf (db, "\n");
      debug_output (0, area_level, debug_current_options.device, debug_buffer);
    }
  }
}


/************************************************************************/
/* debug_beep                                                           */
/*                                                                      */
/* Function makes a beep when called                                    */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_beep (void)
{
  _swix (OS_WriteI + 7, 0);
}


/************************************************************************/
/* debug_version                                                        */
/*                                                                      */
/* Function returns the library's version number.                       */
/*                                                                      */
/* Parameters: none.                                                    */
/*                                                                      */
/* Returns:    Pointer to const string containg version number.         */
/*                                                                      */
/************************************************************************/
const char *debug_version (void)
{
  return debug_version_string;
}


/************************************************************************/
/* debug_initialise_trace                                               */
/*                                                                      */
/* Function initialises the trace library.                              */
/*                                                                      */
/* Parameters: stream - Debug output stream to use.                     */
/*             fns    - Functions to ignore                             */
/*                                                                      */
/* Returns:    void.                                                    */
/*                                                                      */
/************************************************************************/
void debug_initialise_trace (debug_device device, const char *fns)
{
  char *ignore_fns;
  int len, len2;

  if (sysvar_provided_tracedevice == UNSET_OUTPUT)
    debug_current_options.trace_device = device;
  else
    debug_current_options.trace_device = sysvar_provided_tracedevice;

  debug_global_indent++;

  if (fns == NULL)
    len2 = 0;
  else
    len2 = strlen (fns);

  len = len2 + strlen (debug_always_ignore) + 1;

  if ((ignore_fns = malloc (len)) == NULL)
  {
    return;
  }

  /* Buffer allocated, so add the PDebug, Trace and remotedb functions onto the end of the list */

  if (len2 > 0)
    strcpy (ignore_fns, fns);
  else
    ignore_fns[0] = '\0';

  strcat (ignore_fns, debug_always_ignore);

  Trace_IgnoreFunctions (ignore_fns);
  Trace_SetHandlers (
                     (Trace_fnstarthandler)debug_trace_enter,
                     (Trace_fnstophandler)debug_trace_exit
                    );
  Trace_InterceptAllFunctions ();

  free (ignore_fns);
}
