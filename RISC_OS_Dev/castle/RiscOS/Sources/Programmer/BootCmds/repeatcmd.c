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
/*main.c - Repeat *command*/

/*History

   27th Oct 1994 J R C Written
   16th Dec 1999 SAR   Rewritten to include the '-sort' switch and fill buffer in one go (if possible)
   2nd  Sep 2004 SAR   Added -STB switch to control handling of errors in pre-desktop
   20th Feb 2007 JWB   extended buffer allocation to allow up to 8 retries with extended buffer
   17th Jan 2010 TM    os_CLI_LIMIT_RO4 and usage of OS_HeapSort32
*/

/******************************************************************************
 *
 *             ...IMPORTANT NOTE TO ANYONE WORKING ON THIS CODE...
 *
 * Although the BootCommands module has a *command called "*Repeat", it actually
 * just ends up running a stand-alone application called "Repeat" which is what
 * is built from this source file. This application is installed as:
 *
 *   Resources:$.Resources.BootCmds.Repeat
 *
 * during the "export resources" phase for ROM builds. Thus, if you make edits
 * to this code, you won't see any changes in your ROM build unless you re-run
 * the export resources phase. I hope this saves someone the several hours of
 * frustration I went though...
 */

/*From CLib*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "kernel.h"
#include "swis.h"

/*From OSLib*/
#include "messagetrans.h"
#include "os.h"
#include "osfile.h"
#include "osfscontrol.h"
#include "osgbpb.h"
#include "wimp.h"
#include "wimpspriteop.h"

/*Local*/
#include "main.h"

#ifndef BOOTFX_MAGIC_HANDLE
#define BOOTFX_MAGIC_HANDLE (0xB007CED5)
#endif

int main(void)
{
  struct
  {
    char  *prog;
    char  *command;
    char  *directory;
    osbool directories;
    osbool applications;
    osbool files;
    char  *type;
    char  *tail;
    osbool tasks;
    osbool verbose;
    osbool sort;
    osbool cont;
    char  *progress;
    char   argb [os_CLI_LIMIT_RO4 + 1];
  } argl;
  bool done_initialise = FALSE;
  bits file_type;
  os_error *error = NULL, message;
  char *tail;
  osgbpb_info_stamped *info;
  unsigned int bufclaim    = INITIALENTRYCOUNT;
  unsigned int max_buf     = bufclaim*32;
  char **membuf            = malloc((sizeof(char*)*bufclaim) + max_buf);
  char **objects           = membuf;
  char *buffer             = (char*)membuf + (sizeof(char*)*bufclaim);
  char *buf_pos            = buffer;
  unsigned int obj_pos     = 0;
  unsigned int read        = 0;
  unsigned int entries     = 0;
  unsigned int ent_sz      = 0;
  unsigned int context     = 0;
  unsigned int growth      = 0;
  unsigned int total;
  int pct_start, pct_range = -1;

  /* Check that the buffer allocation was successful */
  if (membuf == NULL)
  {
    static const os_error tmp = { error_STR_OFLO, "StrOFlo" }; /* In global messages */
    error = xmessagetrans_error_lookup(&tmp, 0, 0, 0, 0, 0, 0, 0);
    goto finish;
  }

  /* Check for the presence of the parameter string and get its start address */
  if ((error = xos_get_env(&tail, NULL, NULL)) != NULL) goto finish;

  /* Parse the parameter string (PRM 1-465) */
  if ((error = xos_read_args("prog/a,command/a,directory/a,directories/s,applications/s,files/s,type/k,tail,tasks/s,verbose/s,sort/s,continue=stb/s,progress/k",
                             tail,
                             (char *) &argl,
                             sizeof argl,
                             NULL)
      ) != NULL) goto finish;


  if (!argl.directories && !argl.applications && !argl.files && !argl.type) argl.files = (argl.directories = TRUE);

  #if 0
  /*Canonicalise the name just to see it helps matters any.*/
  if ((error = xosfscontrol_canonicalise_path(argl.directory, directory, NULL, NULL, sizeof directory, NULL)) != NULL) goto finish;
  #endif /*it doesn't. also breaks under RO200. JRC 9th Jan 1995*/

  /* If the specified directory is not actually a directory, exit */
  if (argl.type)
  {
    if ((error = xosfscontrol_file_type_from_string(argl.type, &file_type)) != NULL) goto finish;
  }

  /* Initialise this program as a WIMP task, if the -tasks switch was present */
  if (argl.tasks)
  {
    if ((error = xwimp_initialise(wimp_VERSION_RO2, "Repeat", NULL, NULL, NULL)) != NULL) goto finish;
    done_initialise = TRUE;
  }

  /* Intepret the progress start [0..99] and range [0..100] parameter */
  if (argl.progress != NULL)
  {
    unsigned int range;
    int ret = sscanf(argl.progress, "%u,%u", &pct_start, &range);

    if (ret == 2)
    {
      /* Clamp start point then clip range */
      if (pct_start > 99) pct_start = 99;
      if ((pct_start + range) > 100) range = 100 - pct_start;
      pct_range = range;
    }
  }

  /* Fill a buffer with all the directory entries, and build an array of pointers to the leafname strings */
  while (context != -1)
  {
    error = (os_error *) _swix(OS_GBPB, _INR(0,6) | _OUT(3) | _OUT(4), 12, argl.directory, buf_pos, 255, context, max_buf, 0, &read, &context);

    entries += read;
    if (error != NULL || (entries > bufclaim))
    {
      if(growth++ >= 8)  goto finish;
      /* double our buffer space */
      bufclaim       *= 2;
      max_buf         = bufclaim*32;
      if(membuf = realloc(membuf,(sizeof(char*)*bufclaim) + max_buf), !membuf) goto finish;
      buffer          = (char*)membuf + (sizeof(char*)*bufclaim);
      objects         = membuf;
      buf_pos         = buffer;
      obj_pos         = 0;
      read            = 0;
      entries         = 0;
      context         = 0;
    }
    while (read > 0)
    {
      objects[obj_pos++] = (char*)(buf_pos + 24);
      ent_sz             = (24 + strlen(buf_pos + 24) + 1 /* terminator */ + 3 /* align */) & ~3;
      max_buf           -= ent_sz;
      buf_pos           += ent_sz;
      read              -= 1;
    }
  }

  /* Perform the desired *Command on all the matching objects in the directory */
  if (entries > 0)
  {
    /* Sort the leafname pointer array */
    if (argl.sort)
    {
      error = (os_error *) _swix(OS_HeapSort32, _INR(0,2), entries, objects, 4);
      if (error != NULL) goto finish;
    }

    /* Keep the total entries - it's useful for doing the percent complete calculation */
    total = entries;

    /* Iterate through each of the directory entries in order */
    obj_pos = 0;
    while (entries-- > 0)
    {
      info = (osgbpb_info_stamped *) (objects[obj_pos++] - 24);

      if (pct_range > 0)
      {
        /* Report progress of this repeat command */
        (void) _swix(BootFX_BarUpdate, _INR(0,2), 0, BOOTFX_MAGIC_HANDLE, pct_start + ((pct_range * (total - entries)) / total));
      }

      if (
           ( info->obj_type == osfile_IS_FILE &&
             ( argl.files ||
               (argl.type && info->file_type == file_type)
             )
           )
           ||
           ( info->obj_type == osfile_IS_DIR &&
             ( argl.directories ||
               ( argl.applications && info->name [0] == '!')
             )
           )
         )
      {
        char cmd [os_CLI_LIMIT_RO4 + 1];

        /* Create the CLI string which we're going to execute */
        if (!argl.tail)
        {
          sprintf(cmd, "%s %s.%s", argl.command, argl.directory, info->name);
        }
        else
        {
          sprintf(cmd, "%s %s.%s %s", argl.command, argl.directory, info->name, argl.tail);
        }

        /* Are we doing the command as a WIMP task? */
        if (argl.tasks)
        {
          if (argl.verbose)
          {
            strcpy (message.errmess, cmd);
            (void) xwimp_report_error_by_category(&message,
                                                  wimp_ERROR_BOX_SHORT_TITLE | wimp_ERROR_BOX_NO_BEEP | wimp_ERROR_BOX_LEAVE_OPEN |
                                                  wimp_ERROR_BOX_CATEGORY_INFO << wimp_ERROR_BOX_CATEGORY_SHIFT,
                                                  "Repeat", "information", wimpspriteop_AREA, "...", NULL
                                                 );
            (void) xwimp_report_error(NULL, wimp_ERROR_BOX_CLOSE, NULL, NULL);
          }

          if ((error = xwimp_start_task(cmd, NULL)) != NULL) goto finish;
        }
        /* We're doing the command as a CLI call (eg. outside the desktop) */
        else
        {
          /* Do getenv() before system() so last error isn't "System variable 'foo' not found" */
          char *var = getenv(X_ENVVAR);

          if (argl.verbose) fprintf(stderr, "Repeat: %s\n", cmd);

          if (system(cmd) != 0)
          {
            error = (os_error *) _kernel_last_oserror();
            if (argl.cont)
            {
              /* In continue mode, we put the error message string into X$Error (assuming it's
               * not already set) and continue enumeration...
               */
              int          context = 0;
              os_var_type  vartype = os_VARTYPE_STRING;

              if (var == NULL)
              {
                (void) xos_set_var_val(X_ENVVAR,
                                       (byte *)(error->errmess),
                                       strlen(error->errmess),
                                       context,
                                       vartype,
                                       &context,
                                       &vartype);
              }
              error = NULL;
            }
            else
            {
              /* ...otherwise we break out of the enumeration and output the error */
              goto finish;
            }
          }
        }
      }
    }
  }

/* Exit label */
finish:
  if (membuf != NULL) free(membuf);

  if (done_initialise)
  {
    os_error *error1 = xwimp_close_down(NULL);
    if (error == NULL) error = error1;
  }

  if (error != NULL)
  {
    if(argl.tasks)
    {
      (void) xwimp_report_error(error, NONE, "Repeat", NULL);
    }
    else
    {
      fprintf(stderr, "Repeat: %s\n", error->errmess);
    }
    return 1;
  }
  else
  {
    return 0;
  }
}
