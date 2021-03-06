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
/*main.c - entry points for BootCommands module*/

/*History

   12th Sep 1994 J R C Started
   17th Jan 2010 TM    os_CLI_LIMIT_RO4 and some constants replaced by logical name

*/

/*From CLib*/
#include <stdarg.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "kernel.h"

/*From exports*/
#include "Global/NewErrors.h"

/*From OSLib*/
#include "econet.h"
#include "macros.h"
#include "messagetrans.h"
#include "netfs.h"
#include "os.h"
#include "osargs.h"
#include "osbyte.h"
#include "osfile.h"
#include "osfscontrol.h"
#include "osfind.h"
#include "osgbpb.h"
#include "osmodule.h"
#include "resourcefs.h"
#include "wimp.h"
#include "territory.h"

/*From ConfigLib*/
#include "str.h"

/*Local*/
#include "files.h"
#include "main.h"
#include "jc_trace.h" /* avoiding name clash */

static void *Workspace;

static os_error *(*Commands [main_COMMAND_COUNT]) (const char *);

static messagetrans_control_block Control_Block;

/* A useful global buffer */
static char buffer[os_CLI_LIMIT_RO4 + 1];

static os_error *main_error_lookup (int errnum, char *token, ...)

{  va_list list;
   char *p [4];
   int i;
   os_error error_block;

   tracef ("main_error_lookup\n");

   /*Assume that 4 args are always given.*/
   va_start (list, token);
   for (i = 0; i < 4; i++) p [i] = va_arg (list, char *);
   va_end (list);

   error_block.errnum = errnum;
   strcpy (error_block.errmess, token);
   return xmessagetrans_error_lookup (&error_block, &Control_Block, NULL, 0,
         p [0], p[1], p [2], p [3]);
}

static os_error *Register (resourcefs_file *file, char *name,
                           int data_size, byte *data, bits load_addr, bits exec_addr,
                           int *size_out)

{  os_error *error = NULL;
   int fh_size, fd_size, name_len;
   resourcefs_file_header *fh;
   resourcefs_file_data *fd;

   tracef ("Register: file \"%s\", data \"%.*s\"\n" _
         name _ data_size _ data);

   name_len = strlen (name);
   fh_size  = resourcefs_SIZEOF_FILE_HEADER (ALIGN (name_len + 1));
   fd_size  = resourcefs_SIZEOF_FILE_DATA (ALIGN (data_size));

   if (file != NULL)
   {  fh = &file->header;
      fh->data_size = fh_size + fd_size;
      fh->load_addr = load_addr;
      fh->exec_addr = exec_addr;
      fh->size      = data_size;
      fh->attr      = fileswitch_ATTR_OWNER_READ | fileswitch_ATTR_OWNER_WRITE;
      strcpy (fh->name, name);

      fd = (resourcefs_file_data *) &fh->name [ALIGN (name_len + 1)];
      fd->size = data_size + 4;
      memcpy (fd->data, data, data_size);
         /*Supposed to 0-fill this.*/
   }

   if (size_out != NULL) *size_out = fh_size + fd_size;
   tracef ("-> size %d\n" _ fh_size + fd_size);

   return error;
}

static int get_nvm_size(void)

{
   _kernel_swi_regs rg;
   /* check how much to load/save */
   rg.r[0]=0;
   _kernel_swi(OS_NVMemory,&rg,&rg);
   return rg.r[0]?osbyte_CONFIGURE_CHECKSUM+1:rg.r[1];
}

/*------------------------------------------------------------------------*/
static os_error *Add_App (const char *tail)

{  struct {char *applications; char argb [os_CLI_LIMIT_RO4 + 1];} argl;
   os_error *error = NULL;
#if 0
   char *leaf_name, name [os_CLI_LIMIT_RO4 + 1], boot_name [os_CLI_LIMIT_RO4 + 1],
      help_name [os_CLI_LIMIT_RO4 + 1], run_name [os_CLI_LIMIT_RO4 + 1],
      boot_data [os_CLI_LIMIT_RO4 + 1], help_data [os_CLI_LIMIT_RO4 + 1],
      run_data [os_CLI_LIMIT_RO4 + 1], canon [os_CLI_LIMIT_RO4 + 1],
      dir_name [os_FILE_NAME_LIMIT + 1], entry [os_FILE_NAME_LIMIT + 1],
      application [os_FILE_NAME_LIMIT + 1];
#else
   char *leaf_name, *name, *boot_name, *help_name, *run_name, *boot_data,
        *help_data, *run_data, *canon, *dir_name, *entry, *application;
#endif
   int boot_type, help_type, sprites_type, resource_size, size, context, found;
   resourcefs_file_list *file_list;
   resourcefs_file *file;
   os_date_and_time *now;
   fileswitch_info_words info_words;

   tracef ("Add_App\n");
   /* Horrible, I know, but better than getting it off the SVC stack like it used to */
   name = (char *)malloc((8 * (os_CLI_LIMIT_RO4 + 1)) + (3 * (os_FILE_NAME_LIMIT + 1)));
   if (!name)
      goto finish;
   boot_name = name + (os_CLI_LIMIT_RO4 + 1);
   help_name = boot_name + (os_CLI_LIMIT_RO4 + 1);
   run_name = help_name + (os_CLI_LIMIT_RO4 + 1);
   boot_data = run_name + (os_CLI_LIMIT_RO4 + 1);
   help_data = boot_data + (os_CLI_LIMIT_RO4 + 1);
   run_data = help_data + (os_CLI_LIMIT_RO4 + 1);
   canon = run_data + (os_CLI_LIMIT_RO4 + 1);
   dir_name = canon + (os_FILE_NAME_LIMIT + 1);
   entry = dir_name + (os_FILE_NAME_LIMIT + 1);
   application = entry + (os_FILE_NAME_LIMIT + 1);

   if ((error = xos_read_args ("applications/a", tail, (char *) &argl,
         sizeof argl, NULL)) != NULL)
      goto finish;

   if ((leaf_name = strrchr (argl.applications, '.')) != NULL)
   {  sprintf (dir_name, "%.*s", leaf_name - argl.applications, argl.applications);
      leaf_name++;
   }
   else
   {  strcpy (dir_name, "@");
      leaf_name = argl.applications;
   }

   /* This if() statement attempts to ensure we don't create app stubs with circular
    * references because the app itself is _already_ in Resources:$.Apps
    */
   error = xosfscontrol_canonicalise_path(dir_name, canon, NULL, NULL, (os_CLI_LIMIT_RO4 + 1), NULL);
   if (error)
      goto finish;
   error = xterritory_collate(-1, canon, RES_APP_PATH, 1, &context);
   if (error || context == 0)
      goto finish;

   context = 0;
   while (context != osgbpb_NO_MORE)
   {  if ((error = xosgbpb_dir_entries (dir_name, (osgbpb_string_list *) entry,
            1, context, (os_FILE_NAME_LIMIT + 1), leaf_name, &found, &context)) != NULL)
         goto finish;

      if (found == 1)
      {  tracef ("new entry is %s\n" _ entry);

         sprintf (application, "%s.%s", dir_name, entry);

         /*We must canonicalise the argument, or else the path names in
            ResourceFS won't be very much use.*/
         if ((error = xosfscontrol_canonicalise_path (application, canon, NULL, NULL, (os_CLI_LIMIT_RO4 + 1), NULL)) != NULL)
            goto finish;

         resource_size = 0;

         /*We make a !Boot file if there is already a !Boot file or a !Sprites file.*/
         sprintf (name, "%s.!Boot", canon);
         tracef ("OSFile_ReadStampedNoPath %s\n" _ name);
         if ((error = xosfile_read_stamped_no_path (name, &boot_type, NULL, NULL, NULL, NULL, NULL)) != NULL)
            goto finish;
         tracef ("boot_type %d\n" _ boot_type);

         sprintf (name, "%s.!Sprites", canon);
         tracef ("OSFile_ReadStampedNoPath %s\n" _ name);
         if ((error = xosfile_read_stamped_no_path (name,
               &sprites_type, NULL, NULL, NULL, NULL, NULL)) != NULL)
            goto finish;
         tracef ("sprites_type %d\n" _ sprites_type);

         if (boot_type != osfile_NOT_FOUND)
            sprintf (boot_data, "/%s.!Boot %%*0\n", canon);
         else if (sprites_type != osfile_NOT_FOUND)
            sprintf (boot_data, "IconSprites %s.!Sprites\n", canon);

         if (boot_type != osfile_NOT_FOUND || sprites_type != osfile_NOT_FOUND)
         {  sprintf (boot_name, "Apps.%s.%s", entry, "!Boot");
            if ((error = Register (NULL, boot_name, strlen (boot_data),
                  (byte *) boot_data, SKIP, SKIP, &size)) != NULL)
               goto finish;
            resource_size += size;
            tracef ("!Boot needs %d bytes\n" _ size);
         }

         /*We make a !Help file if there is one already.*/
         sprintf (name, "%s.!Help", canon);
         tracef ("OSFile_ReadStampedNoPath %s\n" _ name);
         if ((error = xosfile_read_stamped_no_path (name, &help_type, NULL, NULL, NULL, NULL, NULL)) != NULL)
            goto finish;
         tracef ("type %d\n" _ help_type);

         if (help_type != osfile_NOT_FOUND)
         {  sprintf (help_data, "Filer_Run %s.!Help\n", canon);
            tracef ("help_data %s, len %d\n" _ help_data _
                 strlen (help_data));

            sprintf (help_name, "Apps.%s.%s", entry, "!Help");
            tracef ("help_name %s\n" _ help_name);
            if ((error = Register (NULL, help_name, strlen (help_data),
                  (byte *) help_data, SKIP, SKIP, &size)) != NULL)
               goto finish;
            tracef ("size %d\n" _ size);
            resource_size += size;
            tracef ("!Help needs %d bytes\n" _ size);
         }

         /*We always make a !Run file.*/
         sprintf (run_data, "/%s %%*0\n", canon);
         sprintf (run_name, "Apps.%s.%s", entry, "!Run");
         tracef ("run_name %s\n" _ run_name);
         if ((error = Register (NULL, run_name, strlen (run_data), (byte *) run_data, SKIP, SKIP, &size)) != NULL)
            goto finish;
         resource_size += size;
         tracef ("!Run needs %d bytes\n" _ size);

         resource_size += sizeof 0; /*terminator*/

         if ((error = xosmodule_alloc (resource_size, (void **) &file_list)) != NULL)
            goto finish;
         tracef ("allocated %d bytes at 0x%X\n" _ resource_size _ file_list);

         /*Build common load and exec addresses for everything (they're all Obey files).*/
         if ((error = xos_get_env (NULL, NULL, &now)) != NULL)
            goto finish;
         info_words AS addrs.load_addr = 0xFFF00000u | osfile_TYPE_OBEY << osfile_FILE_TYPE_SHIFT;
         memcpy (info_words AS date_and_time, *now,
               sizeof info_words AS date_and_time);

         file = &file_list->file [0]; /*just a cast*/

         /*Now fill in the real buffer.*/
         if (boot_type != osfile_NOT_FOUND || sprites_type != osfile_NOT_FOUND)
         {  if ((error = Register (file, boot_name, strlen (boot_data),
                  (byte *) boot_data, info_words AS addrs.load_addr,
                  info_words AS addrs.exec_addr, &size)) != NULL)
               goto finish;
            *(char **) &file += size;
         }

         if (help_type != osfile_NOT_FOUND)
         {  if ((error = Register (file, help_name, strlen (help_data),
                  (byte *) help_data, info_words AS addrs.load_addr,
                  info_words AS addrs.exec_addr, &size)) != NULL)
               goto finish;
            *(char **) &file += size;
         }

         if ((error = Register (file, run_name, strlen (run_data),
               (byte *) run_data, info_words AS addrs.load_addr,
               info_words AS addrs.exec_addr, &size)) != NULL)
            goto finish;
         *(char **) &file += size;

         /*Terminator.*/
         file->header.data_size = 0;

         /*And now register the whole lot.*/
         if ((error = xresourcefs_register_files (file_list)) != NULL)
            goto finish;

         tracef ("done\n");
       }
   }

finish:
   free(name);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *App_Size (const char *tail)

{  os_error *error = NULL;
   const char *cc;
   char *end;
   int move, size, size_limit;
   unsigned int value;
   byte *ram_limit;

   tracef ("App_Size\n");
   cc = tail;
   while (*cc == ' ')
      cc++;

   if ((error = xos_read_unsigned (NONE, cc, SKIP, &end, (void *) &value)) != NULL)
      goto finish;

   switch (*end)
   {  case 'm': case 'M':
         value *= 1024;
      /*fall through*/

      case 'k': case 'K':
         value *= 1024;
         end++;
      break;
   }

   if ((error = xos_get_env (NULL, &ram_limit, NULL)) != NULL)
      goto finish;
   tracef ("top of application space 0x%X\n" _ ram_limit);

   /*We want to move the R M A by the difference between the application size
      and the value specified.*/
   move = (int) (ram_limit - 0x8000) - value;
   tracef ("wanted move is %d\n" _ move);

   /*How big is the R M A now?*/
   if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
         NULL, &size, &size_limit)) != NULL)
      goto finish;
   tracef ("R M A expansion space %d\n" _ size_limit - size);

   /*Can't move it to more than its size limit.**/
   (void) MINAB (move, size_limit - size);
   tracef ("allowed move is %d\n" _ move);

   /*We don't care if this succeeds or fails - the attempt is the thing.*/
   (void) xos_change_dynamic_area (os_DYNAMIC_AREA_RMA, move, NULL);
   tracef ("done\n");

#if TRACE
   if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
         NULL, &size, NULL)) != NULL)
      goto finish;
   tracef ("RMA size at end 0x%X\n" _ size);
#endif

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *App_Slot (const char *tail)

{  os_error *error = NULL;
   const char *cc;
   char *end;
   int move, size, size_limit, r;
   unsigned int value;
   byte *ram_limit;

   tracef ("App_Slot\n");
   cc = tail;
   while (*cc == ' ')
      cc++;

   if ((error = xos_read_unsigned (NONE, cc, SKIP, &end, (void *) &value)) != NULL)
      goto finish;

   switch (*end)
   {  case 'm': case 'M':
         value *= 1024;
      /*fall through*/

      case 'k': case 'K':
         value *= 1024;
         end++;
      break;
   }

   if ((error = xos_get_env (NULL, &ram_limit, NULL)) != NULL)
      goto finish;
   tracef ("top of application space 0x%X\n" _ ram_limit);

   /*We want to move by the difference between the application size
      and the value specified.*/
   move = (int) (ram_limit - 0x8000) - value;
   tracef ("wanted move is %d\n" _ move);

   /*What OS capabilities do we have*/
   if ((error = xos_byte (osbyte_IN_KEY, 0, 255, &r, NULL)) != NULL)
                goto finish;

   if (r >= 0xA5)
      {
      tracef ("look to the freepool\n");

      /* OS 3.50 and later juggle ram between the app slot and the free pool */
      if ((error = xos_change_dynamic_area (os_DYNAMIC_AREA_FREE_POOL, move, NULL)) != NULL)
         goto finish;
      }
   else
      {
      tracef ("look to the RMA\n");

      /* OS pre 3.50 so juggle ram between the app slot and the RMA */
      if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
            NULL, &size, &size_limit)) != NULL)
         goto finish;
      tracef ("R M A expansion space %d\n" _ size_limit - size);

      /*Can't move it to more than its size limit.**/
      (void) MINAB (move, size_limit - size);
      tracef ("allowed move is %d\n" _ move);

      /*We don't care if this succeeds or fails - the attempt is the thing.*/
      (void) xos_change_dynamic_area (os_DYNAMIC_AREA_RMA, move, NULL);
      }

   tracef ("done\n");

#if TRACE
   if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
         NULL, &size, NULL)) != NULL)
      goto finish;
   tracef ("RMA size at end 0x%X\n" _ size);
#endif

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Add_To_RMA (const char *tail)

{  os_error *error = NULL;
   const char *cc;
   char *end;
   unsigned int value;

   tracef ("Add_To_RMA\n");
   cc = tail;
   while (*cc == ' ')
      cc++;

   if ((error = xos_read_unsigned (NONE, cc, SKIP, &end, (void *) &value)) != NULL)
      goto finish;

   switch (*end)
   {  case 'm': case 'M':
         value *= 1024;
      /*fall through*/

      case 'k': case 'K':
         value *= 1024;
         end++;
      break;
   }

   /*Pass back any problems verbatim*/
   if ((error = xos_change_dynamic_area (os_DYNAMIC_AREA_RMA, value, NULL)) != NULL)
      goto finish;

   tracef ("done\n");

#if TRACE
   if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
         NULL, &size, NULL)) != NULL)
      goto finish;
   tracef ("RMA size at end 0x%X\n" _ size);
#endif

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Do (const char *tail)

{  os_error *error = NULL;
   bits psr;

   tracef ("Do\n");

   if ((error = xos_gs_trans (tail, buffer, sizeof buffer, NULL,
         &psr)) != NULL)
      goto finish;

   if ((psr & _C) != NONE)
   {  error = main_error_lookup (error_BUFF_OVERFLOW, "BufOFlo");
      goto finish;
   }

   if ((error = xos_cli (buffer)) != NULL)
      goto finish;

finish:
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *If_There (const char *tail)

{  os_error *error = NULL;
   const char *cc;
   int i, obj_type;

   tracef ("If_There\n");

   /*Skip leading spaces.*/
   cc = tail;
   while (*cc == ' ')
      cc++;

   /*Copy non-spaces into |s| - this is the file name.*/
   i = 0;
   while (*cc > ' ')
      buffer[i++] = *cc++;
   buffer[i] = '\0';
   tracef ("file name \"%s\"\n" _ buffer);

   /*So, is it there?*/
   /*Fix MED-3984: if this fails, behave as if the file were absent. JRC 19th
      Dec 1994*/
   if (xosfile_read_stamped_no_path (buffer, &obj_type, NULL, NULL, NULL, NULL,
         NULL) != NULL)
      obj_type = osfile_NOT_FOUND;

   /*Wizard wheeze to avoid parsing the rest of the line.*/
   sprintf (buffer, "If %d%.*s",
         obj_type != osfile_NOT_FOUND, str_len (cc), cc);
   /*Fix bizarre fault - strip trailing spaces. J R C 23rd Feb 1995*/
   for (i = strlen (buffer) - 1; buffer [i] == ' '; i--)
      buffer [i] = '\0';
   tracef ("command \"%s\"\n" _ buffer);

   if ((error = xos_cli (buffer)) != NULL)
   {  /*Fix MED-3984: if this gives a syntax error, change it to our own
         message by deliberataly causing an IfThere syntax error*/
      if (error->errnum == error_SYNTAX)
         error = xos_cli ("IfThere");
      goto finish;
   }

finish:
   return error;
}
/*--------------------------------------------------------------------*/
static os_error *Load_CMOS (const char *tail)

{  struct {char *file; char argb [os_CLI_LIMIT_RO4 + 1];} argl;
   bool done_open = FALSE;
   os_f f;
   int r, w, i, size, obj_type, bootversion = 370, fileversion, xsum, fxsum;
   bits file_type;
   os_error *error = NULL;
   const char *osversion;
   int nvmsize = get_nvm_size();

   tracef ("Load_CMOS\n");

   if ((error = xos_read_args ("file/a", tail, (char *) &argl,
         sizeof argl, NULL)) != NULL)
      goto finish;

   if ((error = xosfile_read_stamped_no_path (argl.file, &obj_type,
         NULL, NULL, &size, NULL, &file_type)) != NULL)
      goto finish;

   if (obj_type != osfile_IS_FILE)
   {  error = xosfile_make_error (argl.file, obj_type);
      goto finish;
   }

   if ((error = xosfind_openin (osfind_NO_PATH | osfind_ERROR_IF_ABSENT |
         osfind_ERROR_IF_DIR, argl.file, NULL, &f)) != NULL)
      goto finish;
   done_open = TRUE;

   if (size != 240 && size != 244 && size != (nvmsize+4))
   {
      error = main_error_lookup (ErrorBase_BootCommands + 0, "BadFile");
      goto finish; /* Not a configuration */
   }

   osversion = getenv("Boot$OSVersion");
   if (osversion != NULL)
   {
      if ((error = xos_read_unsigned (os_READ_CONTROL_TERMINATED | (os_read_unsigned_flags)10,
                                      osversion, NULL, SKIP,(bits *) &bootversion)) != NULL)
         goto finish; /* Read the os version number x100 */;
   }
      
   /* Old file formats will only be valid pre-Ursula */
   if (size == 240 && bootversion > 370)
   {
     error = main_error_lookup (ErrorBase_BootCommands + 1, "BadVer");
     goto finish;
   }
     
   /* Check the file's OS version number (if any) matches the machine */
   if (size == nvmsize+4)
   {
     if ((error = xosgbpb_read_at (f, (byte *) &fileversion, sizeof (fileversion), nvmsize, NULL)) != NULL)
        goto finish;
     if (fileversion != bootversion)
     {
       xosfind_close (f);
       error = main_error_lookup (ErrorBase_BootCommands + 1, "BadVer");
       goto finish;
     }
     if ((error = xosargs_set_ptr (f, 0)) != NULL)
        goto finish;
   }

   /* Ensure the file's checksum byte is correct */
   xsum = CMOSxseed;
   for (i = 0; i < 239; i++)
   {
   if ((error = xosgbpb_read (f, (byte *) &w, 1, NULL)) != NULL)
         /*(Note that the top 24 bits of |w| are garbage.)*/
      goto finish;
   xsum += (w & 0xFF);
   }
   /* fetch the checksum */
   if ((error = xosgbpb_read (f, (byte *) &fxsum, 1, NULL)) != NULL)
         /*(Note that the top 24 bits of |w| are garbage.)*/
      goto finish;

   if(nvmsize > 256)
   {
     /* bytes 240 to 255 are ignored */
     for (i = 240; i <= 255; i++)
     {
     if ((error = xosgbpb_read (f, (byte *) &w, 1, NULL)) != NULL)
           /*(Note that the top 24 bits of |w| are garbage.)*/
        goto finish;
     }
     for (i = 256; i < nvmsize; i++)
     {
     if ((error = xosgbpb_read (f, (byte *) &w, 1, NULL)) != NULL)
           /*(Note that the top 24 bits of |w| are garbage.)*/
        goto finish;
     xsum += (w & 0xFF);
     }
   }

   if ((xsum & 0xFF) != (fxsum & 0xFF))
   {
     xosfind_close (f);
     error = main_error_lookup (ErrorBase_BootCommands + 0, "BadFile");
     goto finish;
   }
   if ((error = xosargs_set_ptr (f, 0)) != NULL)
      goto finish;

   /* Actually load the values */
   for (i = 0; i < nvmsize; i++)
   {
      if ((error = xosgbpb_read (f, (byte *) &w, 1, NULL)) != NULL)
            /*(Note that the top 24 bits of |w| are garbage.)*/
         goto finish;

      switch (i)
      {  case osbyte_CONFIGURE_DST:
         {  /*Do not load bit 7.*/
            if((error = xos_byte (osbyte_READ_CMOS, i, SKIP, NULL, &r)) != NULL)
               goto finish;

            if ((error = xos_byte (osbyte_WRITE_CMOS, i,
                  w & ~osbyte_CONFIGURE_DST_MASK |
                  r & osbyte_CONFIGURE_DST_MASK,
                  NULL, NULL)) != NULL)
               goto finish;
            /* adjust the checksum */
            fxsum -= w&osbyte_CONFIGURE_DST_MASK;
            fxsum += r&osbyte_CONFIGURE_DST_MASK;
         }
         break;

         case osbyte_CONFIGURE_YEAR0:
         case osbyte_CONFIGURE_YEAR1:
         {
            /*Do nothing (but adjust checksum) - these are never loaded.*/
            if((error = xos_byte (osbyte_READ_CMOS, i, SKIP, NULL, &r)) != NULL)
               goto finish;
            fxsum -= w&0xff;
            fxsum += r&0xff;
         }
         break;

         default:
            if ((error = xos_byte (osbyte_WRITE_CMOS, i, w, NULL, NULL)) !=
                  NULL)
               goto finish;
         break;
      }
   }
   /* write in the checksum as recorded and amended .. */
   error = xos_byte (osbyte_WRITE_CMOS, 239, fxsum, NULL, NULL);

finish:
   if (done_open)
   {  os_error *error1 = xosfind_close (f);
      if (error == NULL) error = error1;
   }

   /*Never return an error from here - it would just mess up the boot
      sequence. J R C 23rd Aug 1995*/
   if (error != NULL) fprintf (stderr, "%s\n", error->errmess);

   return NULL;
}
/*--------------------------------------------------------------------*/
static os_error *Save_CMOS (const char *tail)

{  struct {char *file; char argb [os_CLI_LIMIT_RO4 + 1];} argl;
   bool done_open = FALSE;
   os_f f;
   int r, i;
   os_error *error = NULL;
   const char *osversion;
   int size = get_nvm_size();

   tracef ("Save_CMOS\n");

   if ((error = xos_read_args ("file/a", tail, (char *) &argl,
         sizeof argl, NULL)) != NULL)
      goto finish;

   if ((error = xosfind_openout (osfind_NO_PATH | osfind_ERROR_IF_DIR,
         argl.file, NULL, &f)) != NULL)
      goto finish; /* Check the file can be written to */
   done_open = TRUE;

   for (i = 0; i < size; i++)
   {  if ((error = xos_byte (osbyte_READ_CMOS, i, SKIP, NULL, &r)) !=
            NULL)
         goto finish;
      if ((error = xosgbpb_write (f, (byte *) &r, 1, NULL)) != NULL)
         goto finish; /* Put the byte from CMOS */
   }

   osversion = getenv("Boot$OSVersion");
   if (osversion != NULL)
      {
      /* If we can't read the variable just save the 240 byte CMOS */
      if ((error = xos_read_unsigned (os_READ_CONTROL_TERMINATED | (os_read_unsigned_flags)10,
                                      osversion, NULL, SKIP,(bits *) &r)) != NULL)
         goto finish; /* Read the os version number x100 */;
      if ((error = xosgbpb_write (f, (byte *) &r, 4, NULL)) != NULL)
         goto finish; /* Append the word to the CMOS file */
      }
   else
      {
      /* Variable not found. If we're on RISC OS 5 try computing the value manually
         This helps OMAP machines which lack CMOS widgets; unless the OS version is present the HAL won't pick up the CMOS contents */
      if ((error = xosmodule_enumerate_rom_with_info (0,-1,NULL,NULL,NULL,NULL,NULL,&r)) != NULL)
         goto finish;
      if ((r>>16) != 5) /* RISC OS 5? */
         goto finish;
      r = ((r & 0xf000) >> 12)*10 + 500; /* Drop 2nd digit from version, as per BootVars */
      if ((error = xosgbpb_write (f, (byte *) &r, 4, NULL)) != NULL)
         goto finish; /* Append the word to the CMOS file */
      }

finish:
   if (done_open)
   {  os_error *error1 = xosfind_close (f);
      error = xosfile_set_type (argl.file, osfile_TYPE_CONFIG);
      if (error == NULL) error = error1;
   }

   tracef ("Save_CMOS DONE\n");
   if (error != NULL)
      tracef ("with error %s\n" _ error->errmess);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Repeat (const char *tail)

{  os_error *error = NULL;

   tracef ("Repeat\n");

   /*Repeat is done by running a file, since it is then running in USR mode
      and handlers work.*/
   sprintf (buffer, "Resources:$.Resources.BootCmds.Repeat %.*s",
         str_len (tail), tail);
   tracef ("/%s\n" _ buffer);
   if ((error = xosfscontrol_run (buffer)) != NULL)
      goto finish;

   #if 0
   /*Repeat is done by entering the module, since it is then running in USR mode
      and handlers work.*/
   if ((error = xosmodule_enter ("BootCommands", tail)) != NULL)
      goto finish;
   #endif

finish:
   tracef ("Repeat DONE\n");
   if (error != NULL)
      tracef ("with error %s\n" _ error->errmess);
   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Safe_Logon (const char *tail)

{  struct safelogon_args {char *fs, *user, *password; char argb [os_CLI_LIMIT_RO4 + 1];} *argl;
   int station, net, context, collate;
   fileswitch_fs_no temp_fs;
   netfs_file_server_context file_server_context;
   char *end;
   bool logon_required = TRUE, found_fs, named_fs;
   os_error *error = NULL;

   tracef ("Safe_Logon\n");

   argl = malloc(sizeof(struct safelogon_args));
   if (argl == 0)
       goto finish;

   /*Fix bug: check that the temporary filing system is indeed NetFS. JRC
      16th Feb 1995*/
   if ((error = xosargs_read_temporary_fs (&temp_fs)) != NULL)
      goto finish;

   if (temp_fs == fileswitch_FS_NUMBER_NETFS)
   {  if ((error = xos_read_args ("fs/a,user/a,password", tail,
            (char *) argl, sizeof *argl, NULL)) != NULL)
         goto finish;

      tracef ("fs \"%s\"\n" _ argl->fs);
      tracef ("user \"%s\"\n" _ argl->user);
      tracef ("password \"%s\"\n" _
            argl->password != NULL? argl->password: "NULL");

      /*If the first character of the fs is not ':', we steer clear.*/
      if (argl->fs [0] == ':')
      {  argl->fs++;

         /*Station number or name?*/
         named_fs = xeconet_read_station_number (argl->fs, NULL, &station,
               &net) != NULL;
         if (named_fs)
            tracef ("fs is named \"%s\"\n" _ argl->fs);
         else
            tracef ("fs is numbered %d.%d\n" _ net _ station);

         context = 0;
         while (TRUE)
         {  if ((error = xnetfs_enumerate_fs_contexts (context,
                  &file_server_context, sizeof file_server_context, 1,
                  &context, NULL)) != NULL)
               goto finish;
            if (context == netfs_NO_MORE) break;

            /*The useful parts of this are space-terminated.*/
            if ((end = strchr (file_server_context.disc_name, ' ')) != NULL)
               *end = '\0';
            if ((end = strchr (file_server_context.user_name, ' ')) != NULL)
               *end = '\0';

            tracef ("found fs %d.%d = \"%s\", user \"%s\"\n" _
                  file_server_context.net_no _
                  file_server_context.station_no _
                  file_server_context.disc_name _
                  file_server_context.user_name);

            if (named_fs)
            {  if ((error = xterritory_collate (territory_CURRENT, argl->fs,
                     file_server_context.disc_name, territory_IGNORE_CASE,
                     &collate)) != NULL)
                  goto finish;

               found_fs = collate == 0;
            }
            else
               found_fs = file_server_context.station_no == station &&
                  file_server_context.net_no == net;

            if (found_fs)
            {  if ((error = xterritory_collate (territory_CURRENT, argl->user,
                     file_server_context.user_name, territory_IGNORE_CASE,
                     &collate)) != NULL)
                  goto finish;

               if (collate == 0)
               {  /*We have found a match, and are about to set
                     |logon_required| to FALSE. One more thing to check,
                     though: does the file server agree that we are logged
                     on? JRC 19th Dec 1994*/
                  netfs_read_user_info info;

                  sprintf (info AS request.user_name, "%s\r", argl->user);

                  tracef ("doing fs op ...\n");
                  if ((error = xnetfs_do_fs_op_to_given_fs
                        (netfs_FS_OP_READ_USER_INFO, (netfs_op *) &info,
                        strlen (info AS request.user_name), sizeof info,
                        file_server_context.station_no,
                        file_server_context.net_no, NULL, NULL)) != NULL)
                     goto finish;

                  tracef ("privilege byte 0x%X\n" _ info AS reply.privilege);
                  tracef ("station %d\n" _ info AS reply.station);
                  tracef ("net %d\n" _ info AS reply.net);

                  logon_required = FALSE;
                  break;
   }  }  }  }  }

finish:
   free(argl);
   /*Ignore errors up to this point. If there have been any, it's a safe bet
      that |logon_required| is TRUE.*/
   if (error != NULL)
      tracef ("LOGON because of error %s\n" _ error->errmess);
   error = NULL;

   /*If that user is not logged on to that file server, do it now.*/
   if (logon_required)
   {
      sprintf (buffer, "%%Logon %.*s", str_len (tail), tail);
         /*Not Net:%%Logon! JRC 17th Feb 1995*/
      error = xos_cli (buffer);
   }

   return error;
}
/*------------------------------------------------------------------------*/
static os_error *Shrink_RMA(const char *tail)

{
   os_error *error = NULL;
   int size;

   tracef("Shrink_RMA\n");

   if ((error = xos_read_dynamic_area (os_DYNAMIC_AREA_RMA,
         NULL, &size, NULL)) != NULL)
      goto finish;

   /*Ignore any errors here*/
   (void) xos_change_dynamic_area (os_DYNAMIC_AREA_RMA, -size, NULL);

   tracef ("done\n");

finish:
   return error;

   NOT_USED( tail );
}
/*------------------------------------------------------------------------*/
static os_error *Free_Pool(const char *tail)

{
   int next_size;
   os_error *err = xwimp_slot_size( -1, -1, NULL, &next_size, NULL );
   if ( err == NULL )
   {
      int app_size;
      err = xos_change_environment( 0x0E, 0, 0, 0, (void **)&app_size, NULL, NULL );
      if ( err == NULL ) err = xos_read_dynamic_area( 6, NULL, NULL, NULL );
      if ( err == NULL ) err = xos_change_dynamic_area( 6, app_size-next_size, NULL );
   }
   return err;

   NOT_USED( tail );
}
/*------------------------------------------------------------------------*/
static os_error *X (const char *tail)

{  os_error    *error   = NULL;
   int          context = 0;
   os_var_type  vartype = os_VARTYPE_STRING;

   tracef ("X\n");

   error = xos_cli(tail);
   if (error != NULL)
   {
     if (getenv(X_ENVVAR) == NULL)
     {
       error = xos_set_var_val(X_ENVVAR,
                               (byte *)(error->errmess),
                               strlen(error->errmess),
                               context,
                               vartype,
                               &context,
                               &vartype);
     }
     else
     {
       error = NULL;
     }
   }

   return error;
}

/*------------------------------------------------------------------------*/
_kernel_oserror *main_initialise (char *tail, int podule_base,
      void *workspace)

{  os_error *error = NULL;
   bool done_open_file = FALSE;
   char *message_file_name;
#ifdef STANDALONE
   bool registered_messages = FALSE;
#endif

   NOT_USED (tail)
   NOT_USED (podule_base)

   Workspace = workspace;

   if ((error = trace_initialise ("BootCommands$Trace")) != NULL)
      goto finish;

   tracef ("main_initialise\n");

   if (getenv ("BootCommands$Path") == NULL)
      message_file_name = "Resources:Resources.BootCmds.Messages";
   else
      message_file_name = "BootCommands:Messages";

#ifdef STANDALONE
   if ((error = xresourcefs_register_files (files_messages ())) != NULL)
      goto finish;
   registered_messages = TRUE;
#endif

   /*Load files.*/
   if ((error = xmessagetrans_open_file (&Control_Block, message_file_name,
         NULL)) != NULL)
      goto finish;
   done_open_file = TRUE;

   Commands [main_ADD_APP]    = &Add_App;
   Commands [main_APP_SIZE]   = &App_Size;
   Commands [main_DO]         = &Do;
   Commands [main_IF_THERE]   = &If_There;
   Commands [main_LOAD_CMOS]  = &Load_CMOS;
   Commands [main_SAVE_CMOS]  = &Save_CMOS;
   Commands [main_REPEAT]     = &Repeat;
   Commands [main_SAFE_LOGON] = &Safe_Logon;
   Commands [main_FREE_POOL]  = &Free_Pool;
   Commands [main_SHRINK_RMA] = &Shrink_RMA;
   Commands [main_ADD_TO_RMA] = &Add_To_RMA;
   Commands [main_APP_SLOT]   = &App_Slot;
   Commands [main_X]          = &X;

finish:
   if (error != NULL)
   {  tracef ("ERROR: \"%s\" (error 0x%X)\n" _ error->errmess _ error->errnum);

      if (done_open_file)
      {  os_error *error1;

         error1 = xmessagetrans_close_file (&Control_Block);
         if (error == NULL) error = error1;
      }

#ifdef STANDALONE
      if (registered_messages)
      {  os_error *error1;

         error1 = xresourcefs_deregister_files (files_messages ());
         if (error == NULL) error = error1;
      }
#endif
   }

   return (_kernel_oserror *) error;
}
/*------------------------------------------------------------------------*/
_kernel_oserror *main_terminate (bool fatal, int instance, void *workspace)

{  os_error *error = NULL;

   NOT_USED (fatal)
   NOT_USED (instance)
   NOT_USED (workspace)

   tracef ("main_terminate\n");

   if ((error = xmessagetrans_close_file (&Control_Block)) != NULL)
      goto finish;

#ifdef STANDALONE
   if ((error = xresourcefs_deregister_files (files_messages ())) != NULL)
      goto finish;
#endif

finish:
   {  os_error *error1 = trace_terminate ();
      if (error == NULL) error = error1;
   }

   return (_kernel_oserror *) error;
}
/*------------------------------------------------------------------------*/
_kernel_oserror *main_command (const char *tail, int argc, int cmd_no,
                               void *workspace)

{
   NOT_USED (argc)
   NOT_USED (workspace)

   tracef ("main_command: tail \"%.*s\"\n" _ str_len (tail) _ tail);

   return (_kernel_oserror *)(*Commands [cmd_no]) (tail);
}
/*------------------------------------------------------------------------*/
