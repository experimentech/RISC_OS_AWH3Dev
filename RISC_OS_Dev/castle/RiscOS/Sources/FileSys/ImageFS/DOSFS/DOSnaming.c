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
/*> c.DOSnaming <*/
/*---------------------------------------------------------------------------*/
/* MSDOS to RISCOS name conversion                Copyright (c) 1989 JGSmith */
/*---------------------------------------------------------------------------*/

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <ctype.h>
#include "kernel.h"
#include "DebugLib/DebugLib.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "ADFSshape.h"
#include "Helpers.h"
#include "MsgTrans.h"
#include "DOSnaming.h"
#include "DOSshape.h"
#include "DOSdirs.h"

/*!
 * \brief  Validate that the given character appears in the string
 * \param  string Table to use
 * \param  init Character to check if it is in it
 * \return -1 if the character is in the table
 */
int validchar(char *string, char init)
{
  while (*string != '\0')
  {
    if (*string == init)
      return -1;
    string++;
  }

  return 0;
}

/*!
 * \brief  Map certain characters between filing systems
 * \param  char Character to map
 * \param  fromlist Input table
 * \param  tolist Output table
 * \return Remapped character
 */
char mapchar(char cchr, char *fromlist, char *tolist)
{
  while (*fromlist != '\0')
  {
    if (cchr == *fromlist)
      return *tolist;
    fromlist++;
    tolist++;
  }
  return cchr;
}

/*!
 * \brief  Return the character position of the passed character (or 0 if none)
 * \param  text String to search
 * \param  marker fromlist Input table
 * \param  tolist Output table
 * \return Remapped character
 */
static int chr_pos(char *text, char marker)
{
// int index;
//
// for (index = 0; (text[index] != '\0'); index++)
//  if (text[index] == marker)
//   return(index) ;
  char *index = strrchr(text, marker);
  return (index ? (int)(index - text) : 0);
}

/*!
 * \brief  Return a string containing the text before the given character
 * \param  newptr Pointer to storage for the substring
 * \param  text String to use
 * \param  marker Character to split at
 * \param  npad Terminate with 0 if zero
 * \return The new string
 */
char *before(char *newptr, char *text, char marker, int npad)
{
  int cpos = chr_pos(text, marker);
  if (cpos == 0)
    cpos = strlen(text);
 
  strncpy(newptr, text, cpos);
  if (npad == 0)
    newptr[cpos] = '\0';
 
  return newptr;
}

/*!
 * \brief  Return a string containing the text after the given character
 * \param  newptr Pointer to storage for the substring
 * \param  text String to use
 * \param  marker Character to split at
 * \param  npad Terminate with 0 if zero
 * \return The new string
 */
char *after(char *newptr, char *text, char marker, int npad)
{
  int cpos = chr_pos(text, marker);

  if (cpos != 0)
  {
    if (npad == 0)
      strcpy(newptr, &text[cpos + 1]);
    else
      strncpy(newptr, &(text[cpos + 1]), 4);
  }
  else
  {
    if (npad == 0)
      strcpy(newptr, "");
  }

  return (newptr);
}

/* RISC OS name:
 *      [$.]<path>
 * RISC OS path:
 *      <filename (max. 10 chars)>[.<path element>]
 *
 * DOS name:
 *      [\]<path>
 * DOS path:
 *      <filename (max. 8 chars)>[.<extension (max. 3 chars)>[\<path element>]
 */

/*!
 * \brief  Check that the given DOS names are identical
 * \param  wcname Compare name, possibly including wild cards
 * \param  fname File name
 * \return TRUE when there is a match
 */
int namematch(char *wcname,char *fname)
{
  char string1[257];
  char string2[257];
 
  /* Code assumes characters upto (and including) "file_sep" will always fit
   * in RISC OS names.
   */
  before(string1, fname, file_sep, 0);
  before(string2, wcname, file_sep, 0);
  if (wild_card_compare(string1, string2, DOSwcmult, DOSwcsing) == TRUE)
  {
    /* "string1" is the full (non-wildcarded) filename we have matched with */
    /* "string2" is the original (wildcarded) filename we were given on entry */
    after(string1, fname, file_sep, 0);
    after(string2, wcname, file_sep, 0);
 
    if (wild_card_compare(string1, string2, DOSwcmult, DOSwcsing) == TRUE)
      return TRUE;
  }
 
  return FALSE;
}

/*!
 * \brief  Translate a standard RISC OS name into a MS-DOS one
 * \param  source The RISC OS name
 * \param  dest Buffer to receive the DOS one
 * \return Destination buffer pointer
 */
char *convertRISCOStoDOS(char *source, char *dest)
{
  char *csptr = source;
  char *cdptr = dest;
  int   loop;
  int   filesepseen = FALSE; /* if we have seen the file seperator */
  char *cptr;      /* string pointer */
  char  lchr;      /* last character seen */
  int   point = 0; /* position where file extension started */
 
  if ((source == NULL) || (*source == '\0'))
  {
    dprintf(("", "DOSFS: convertRISCOStoDOS: NULL name\n"));
    *dest = '\0';
    return dest;
  }
 
  dprintf(("","DOSFS: convertRISCOStoDOS: \"%s\"", source));
 
  lchr = '\0'; /* no last character */
  cptr = csptr;
  do
  {
    /* Ensure that "/" characters do not appear at the start or end of the name
     * and that "//" sequences are trapped.
     */
    if ((*cptr == '/' && (lchr == '\0' || lchr == *cptr || lchr == '.')) ||
        ((lchr == '/') && ((*cptr == '\0') || (*cptr == '.')))
       )
      return_error1(char *, err_invalidname, source);
 
    lchr = *cptr++; /* remember this character */
  } while (lchr);
 
  if (*csptr == '$')             /* ROOT directory specifier */
  {
    csptr++;
    if (*csptr == '.')           /* RISC OS directory seperator */
    {
      *cdptr++ = dir_sep;        /* MSDOS directory seperator */
      csptr++;
    }
    else
      if (*csptr == '\0')
        *cdptr++ = dir_sep;
      else
        *cdptr++ = '$';
  }
 
  for (loop = 0;;)       /* convert the remainder of the pathname */
  {
    if (*csptr == '\0')  /* end of the source pathname */
    {
      *cdptr = '\0';     /* terminate the destination pathname */
      break;
    }
 
    switch (*csptr)
    {
      case '.':
        /* RISC OS to directory seperator */
        *cdptr++ = dir_sep;
        csptr++;
        loop = 0;
        filesepseen = FALSE; /* for this leafname */
        break;
 
      case '/':
        /* convert to file seperator */
        if (filesepseen)
          return_error1(char *, err_invalidname, source);
        *cdptr++ = file_sep;
        csptr++;
        loop++;
        point = loop;
        filesepseen = TRUE;
        break;
 
      default:
        /* perform standard name mapping */
        if (filesepseen)
        {
          char c = *csptr++;
          /* should never need to truncate the extension */
//        if ((loop - point) >= extsize)
//          return_error1(char *, err_invalidname, source);
//        if (islower(c))
//          c = toupper(c);
          *cdptr++ = mapchar(c, ROmapping, DOSmapping);
        }
        else
        {
          char c = *csptr;
//        if (islower(c))
//          c = toupper(c);
          *cdptr++ = mapchar(c, ROmapping, DOSmapping);
          csptr++;      /* step over this DOS character */
        }
        loop++;
        break;
    }
  }
 
  dprintf(("", " converted to \"%s\"\n", dest));
 
  for (cptr = dest; *cptr; cptr++)
    if (!validchar(valchars, *cptr))
      return_error1(char *, err_invalidname, source);
 
  return dest;
}

/*!
 * \brief  Convert a dir entry into a DOS short filename
 * \param  dentry The dir entry to consider
 * \param  name Buffer to receive the name, at least 8+1+3+1 long
 * \return Name buffer pointer
 */
char *buildFILEname(DOS_direntry * dentry,char *name)
{
  char *cptr = (char *)&(dentry->FILE_status);
  int   index;
  int   loop;

  dprintf(("", "buildFILEname: dentry:%p\n", dentry));
 
  /* "dentry" should contain a valid filename */
  /* copy prefix characters (or upto a space) into the filename buffer */
  for (index=0; ((cptr[index] > ' ') && (index < namsize)); index++)
    name[index] = cptr[index];
 
  /* copy suffix characters (or upto a space) into the filename buffer */
  for (loop=0; ((dentry->FILE_extension[loop] > ' ') && (loop < extsize)); loop++)
  {
    if (loop == 0) /* the first character of the extension */
      name[index++] = file_sep; /* then place in the file_seperator */
    name[index++] = dentry->FILE_extension[loop];
  }
 
  /* terminate the name */
  name[index] = '\0';
  dprintf(("", "buildFILEname: got:%s\n", name));
 
  return name;
}

/*!
 * \brief  Calculates the LFN checksum of an 11 bytes DOS filename
 * \param  filename The filename to use
 * \return The checksum
 */
byte lfnchecksum(const char *filename)
{
  byte checksum = 0;
  byte lsb;
  int  i;

  for (i = 0; i < 11; i++)
  {
    lsb = (checksum & 0x1); /* Save the lsb */
    checksum = checksum >> 1; /* Shift the byte */
    lsb = lsb << 7; /* Turn saved lsb into msb */
    checksum |= lsb;
    checksum += filename[i];
  }
 
  return checksum;
}

/*!
 * \brief  Shorten part of a DOS filename
 * \param  longfname The part of filename to start with (ie. base name, or extension)
 * \param  buff Pointer to a buffer for the short result
 * \param  limit Maximum number of characters to output
 * \return TRUE if copying was not an identity transform
 */
static int shorten_part(const char *longfname, char *buff, size_t limit)
{
  size_t i, j;
  int    identity = TRUE;

  for (i = 0, j = 0; j < limit; i++)
  {
    if ((longfname[i] == '.') || (longfname[i] == '\0'))
    {
      /* Reached the end of the base name */
      break;
    }
    if (strchr("+,;=[]", longfname[i]) != NULL)
    {
      /* Substitute forbidden short name characters */
      buff[j++] = '_';
      identity = FALSE;
      continue;
    }
    if (longfname[i] == ' ')
    {
      /* Swallow spaces */
      identity = FALSE;
      continue;
    }
    buff[j++] = toupper(longfname[i]);
  }
  buff[j] = '\0';

  return !identity;
}

int shorten_lfn(char *longfname, char *shortname, DIR_info *cdir)
{
  size_t i;
  int    retval, nondot, tilde;
  char  *extension;
  char   basebuff[8+1];
  char   extbuff[1+3+1];
  char   compbuff[8+1+3+1];

  /* Build the base name up to 8 long starting at the first non dot */
  for (i = 0; longfname[i] == '.'; i++)
  {
  }
  nondot = i;
  tilde = shorten_part(&longfname[i], basebuff, 8);
 
  /* Locate the outermost extension and truncate to 3 letters */
  extension = strrchr(longfname, '.');
  if ((extension == NULL) || (&extension[1] == &longfname[nondot]))
  {
    /* No extension, or found dot was at the start before the base name */
    extension = ".";
  }
  shorten_part(&extension[1], &extbuff[1], 3);
  extbuff[0] = '.';
  dprintf(("", "shorten_lfn '%s' => base '%s' & ext '%s'\n", longfname, basebuff, extbuff));

  /* If a tilde was needed, inject it */
  if (tilde)
  {
    int  index, length;
    char fmt[] = "%0.?s~%u%s";

    if (strlen(basebuff) <= 2)
    {
      /* Bit short, add a few digits */
      sprintf(compbuff, "%04X", time(NULL));
      strcat(basebuff, compbuff);
    }
    length = MIN(strlen(basebuff), 6);
    fmt[3] = '0' + length;
    for (i = 1; i <= 99; i++)
    {
      if ((i == 10) && (length == 6)) fmt[3]--; /* Budge an extra digit */
      sprintf(compbuff, fmt, basebuff, i, extbuff);
      index = 0;
      if (findDIRentry(compbuff, cdir, cdir->dir_size, &index) == NULL)
      {
        /* No match, so we can use that tilde suffix */
        break;
      }
    }
    dprintf(("", "            tilde needed, clear to use '%s'\n", compbuff));
  }
  else
  {
    strcpy(compbuff, basebuff);
    strcat(compbuff, extbuff);
    dprintf(("", "            composite '%s'\n", compbuff));
  }

  /* See if the short candidate is the same as the long one */
  retval = strcmp(longfname, compbuff);
  if (retval == 0)
  {
    dprintf(("", "            long will do as short\n"));
  }

  /* Rejig the short name into its dotless form ready to put into a dir entry */
  *strchr(compbuff, '.') = '\0';
  sprintf(shortname, "%-8.8s%-3s", compbuff, &extbuff[1]);
  dprintf(("", "            dir entry '%s'\n", shortname));

  return retval;
}

/*!
 * \brief  Build an array of long filename entries from its name and short name
 * \param  lfn Allocated array of dir entries
 * \param  numreq Number of dir entries allocated
 * \param  leafname The long name to encode
 * \param  shortname The short name to encode
 */
void MakeLFNEntries(DOS_direntry * lfn[],int numreq,char* leafname,char* shortname)
{
  int lfnnum, i;
  DOS_lfnentry *lfnentry;
  int charnum = 0;
  int nullreached = 0;
  
  for (i = (numreq - 2), lfnnum = 0; i >= 0; i--, lfnnum++)
  {
    /* Create the long file name structures */
    lfnentry = (DOS_lfnentry *)lfn[i];
    lfnentry->FILE_Ordinal = ((lfnnum & 0x3F) + 1);
    if (i == 0) lfnentry->FILE_Ordinal |= 0x40; /* Last entry */
    lfnentry->FILE_attribute = FILE_win95;
    lfnentry->reserved1 = lfnentry->reserved2 = lfnentry->reserved3 = 0; 

    /* Weave the name */
    lfnentry->FILE_uchar0_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar0    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar1_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar1    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar2_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar2    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar3_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar3    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar4_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar4    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar5_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar5    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar6_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar6    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar7_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar7    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar8_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar8    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar9_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar9    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar10_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar10    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar11_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar11    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;
    lfnentry->FILE_uchar12_hi = (nullreached)?0xFF:0;
    lfnentry->FILE_uchar12    = (nullreached)?0xFF:leafname[charnum];
    if (leafname[charnum] == '\0') nullreached = 1;
    charnum++;

    lfnentry->FILE_checksum = lfnchecksum(shortname);
  }
}

/*!
 * \brief  Translate a standard RISC OS name into an extended DOS one
 * \param  source The RISC OS name
 * \param  dest Buffer to receive the DOS one
 * \return Destination buffer pointer
 */
char *convertRISCOStoLFN(char *source, char *dest)
{
  char *csptr = source;
  char *cdptr = dest;
  int   loop;
  int   filesepseen = FALSE; /* if we have seen the file seperator */
  char *cptr;      /* string pointer */
  char  lchr;      /* last character seen */
  int   point = 0; /* position where file extension started */
 
  if ((source == NULL) || (*source == '\0'))
  {
    dprintf(("", "DOSFS: convertRISCOStoLFN: NULL name\n"));
    *dest = '\0';
    return dest;
  }
 
  dprintf(("", "DOSFS: convertRISCOStoLFN: \"%s\"",source));
 
  lchr = '\0'; /* no last character */
  cptr = csptr;
  do
  {
    /* Ensure that "/" characters do not appear at the start or end of the name
     * and that "//" sequences are trapped.
     */
//   if ((*cptr == '/' && (lchr == '\0' || lchr == *cptr || lchr == '.')) ||
//       ((lchr == '/') && ((*cptr == '\0') || (*cptr == '.')))
//      )
//     return_error1(char *,err_invalidname,source) ;
 
    lchr = *cptr++; /* remember this character */
  } while (lchr);
 
  if (*csptr == '$')             /* ROOT directory specifier */
  {
    csptr++;
    if (*csptr == '.')           /* RISC OS directory seperator */
    {
      *cdptr++ = dir_sep;        /* MSDOS directory seperator */
      csptr++;
    }
    else
      if (*csptr == '\0')
        *cdptr++ = dir_sep;
      else
        *cdptr++ = '$';
  }
 
  for (loop = 0;;)       /* convert the remainder of the pathname */
  {
    if (*csptr == '\0')  /* end of the source pathname */
    {
      *cdptr = '\0';     /* terminate the destination pathname */
      break;
    }
 
    switch (*csptr)
    {
      case '.':
        /* RISC OS to directory seperator */
        *cdptr++ = dir_sep;
        csptr++;
        loop = 0;
        filesepseen = FALSE; /* for this leafname */
        break;
 
      case '/':
        /* convert to file seperator */
//      if (filesepseen)
//        return_error1(char *, err_invalidname, source);
        *cdptr++ = file_sep;
        csptr++;
        loop++;
        point = loop;
//      filesepseen = TRUE;
        break;
 
      default:
        /* perform standard name mapping */
//      if (filesepseen)
//      {
//        char c = *csptr++;
        /* should never need to truncate the extension */
//        if ((loop - point) >= extsize)
//         return_error1(char *, err_invalidname, source);
//        if (islower(c))
//         c = toupper(c);
//        *cdptr++ = mapchar(c, ROmapping, DOSmapping);
//      }
//      else
//      {
        if (loop < 255)    /* characters left */
        {
          char c = *csptr;
//        if (islower(c))
//          c = toupper(c);
          *cdptr++ = mapchar(c, ROmapping, DOSmapping);
        }
        else
        {
          if (!(module_flags & TRUNCATE_NAMES))
            return_errorT(char *, err_nametoolong, tok_nametoolong, source, "255");
        }
        csptr++;      /* step over this DOS character */
//      }
      loop++;
      break;
     }
  }
 
  dprintf(("", " converted to \"%s\"\n", dest));
 
// for (cptr = dest; *cptr; cptr++)
//   if (!validchar(valchars,*cptr))
//     return_error1(char *, err_invalidname, source);
 
  return dest;
}

/*!
 * \brief  Translate an extended DOS name into a RISC OS one
 * \param  source The DOS name
 * \param  dest Buffer to receive the RISC OS one
 * \return Destination buffer pointer
 */
char *convertDOStoRISCOS(char *source, char *dest)
{
  char *csptr = source;
  char *cdptr = dest;
  int   loop;
 
  dprintf(("", "DOSFS: convertDOStoRISCOS: \"%s\" ",source));
 
  if (*csptr == dir_sep)
    *cdptr++ = '$';
 
  for (loop = 0;;)
  {
    if (*csptr =='\0')   /* end of the source pathname */
    {
      *cdptr = '\0';     /* terminate filename */
      break;             /* the for loop */
    }
 
    switch (*csptr)
    {
      case file_sep:
        /* convert the character to "/" */
        *cdptr++ = '/';
        csptr++;
        loop++;
        break;
 
      case dir_sep:
        /* convert to RISC OS directory seperator */
        *cdptr++ = '.';
        loop = 0;
        csptr++;
        break;
 
      default:
        /* perform standard name mapping */
        /* we never truncate here, it's up to the outside world */
        *cdptr++ = mapchar(*csptr, DOSmapping, ROmapping);
        csptr++;
        loop++;
        break;
    }
  }
 
  dprintf(("", "converted to \"%s\"\n", dest));
  return dest;
}
