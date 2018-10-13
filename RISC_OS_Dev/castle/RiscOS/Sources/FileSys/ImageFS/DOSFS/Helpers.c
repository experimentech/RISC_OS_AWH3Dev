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
/*> c.Helpers <*/
/*-------------------------------------------------------------------------*/
/* Common utilities for DOS image operations    Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "kernel.h"
#include "swis.h"
#include "Global/FileTypes.h"
#include "Interface/MimeMap.h"
#include "Interface/HighFSI.h"
#include "DebugLib/DebugLib.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "ADFSshape.h"
#include "Helpers.h"
#include "MsgTrans.h"
#include "DOSnaming.h"
#include "DOSclusters.h"
#include "DOSshape.h"

#define ReadOnlyMapsLocked 1
 /* JRS 9/3/92 map DOS ReadOnly bit to RISC OS Locked bit only.
  * This is to fix problem with FilerAction setting access 0 to force-delete.
  * This would get translated into DOS ReadOnly, which would then translate
  * back into Locked and not Write, so the file would end up being locked
  * by setting access 0, which was not the intention.
  */

/* Return mode of access if the given file is open (else return -1). */
int find_open_file(char *fname, DOS_direntry *dentry, DOSdisc *ihand)
{
  FILEhand *cptr;

  int dcluster = get_FILE_cluster(dentry,ihand);

  for (cptr = FILE_list; cptr != NULL; cptr = cptr->next)
    if (cptr->ihand == ihand) {
      if (dcluster == 0) {
        if (wild_card_compare(cptr->fname, fname, ROwcmult, ROwcsing))
          return cptr->opentype;
      } else
        if (dcluster == cptr->startCLUSTER)
          return cptr->opentype;
    }

  dprintf(("","find_open_file: file \"%s\" not open\n",fname));
  return -1;
}

/*-------------------------------------------------------------------------*/

int update_imageID(DOSdisc *ihand)
{
 /* At the moment we just calculate a simple additive checksum from the FAT.
  */
 word              cval = 0x00000000 ; /* image ID value */
 int               loop ;
 char             *FATbuffer ;
 _kernel_swi_regs  rset ;
 _kernel_oserror  *rerror ;

 /* Flush the output */
 rset.r[0] = OSArgs_Flush;
 rset.r[1] = (word)ihand->disc_fhand;
 if ((rerror = _kernel_swi(OS_Args, &rset, &rset)) != NULL) {
  dprintf(("","update_imageID: error from OS_Args 255: (&%08X) \"%s\"\n",rerror->errnum,rerror->errmess));
  return_errorX(int,rerror);
 }

 FATbuffer = (char *)&(ihand->disc_FAT) ;

 for (loop = 0; (loop < ihand->disc_FATsize); loop++)
  cval = cval + FATbuffer[loop] ;

 dprintf(("","update_imageID: sending 0x%x\n", cval));
 rset.r[0] = OSArgs_ImageStampIs ;
 rset.r[1] = (word)ihand->disc_fhand;
 rset.r[2] = cval ; /* and the newly calculated value */
 if ((rerror = _kernel_swi(OS_Args,&rset,&rset)) != NULL)
  {
   dprintf(("","update_imageID: error from OS_Args 8: (&%08X) \"%s\"\n",rerror->errnum,rerror->errmess));
   return_errorX(int,rerror) ;
  }
 ihand->disc_flags &= ~disc_UPDATEID ; /* we have given FileSwitch a new image ID */
 return(0) ;
}

void map_FILE_ROStype(DOS_direntry *dentry,char* dosext,time5byte *le)
{
 _kernel_swi_regs rset ;
 int value = -1;

 /* Try to determine whether this really is a ROS filetype */
 if (((dentry->FILE_reserved[1] & 0xF0) == 0) || ((dentry->FILE_reserved[1] & 0xF0) == 0xF0))
  {
  value = get_FILE_ROStype(dentry);
  /* DOSFS's capable of *SETTYPE &000 also set the top 4 bits */
  if ((value == 0) && ((dentry->FILE_reserved[1] & 0xF0) != 0xF0)) value = -1; 
//  dprintf(("","filetype lookup,found in spare bytes 0x%X3\n", value));
  }
 /* No filetype in the spare bytes,so have a look through DOSmap */
 if (value == -1)
  {
  mapentry *cmap ;
  for (cmap = maplist; (cmap); cmap = cmap->next)
   if (strcmp(dosext, cmap->dosext)==0)
    {
    value = cmap->ROtype;
    dprintf(("","filetype lookup,found in dosmap 0x%X3\n", value));
    break; /* the for loop */
    }
  }
 /* Found neither a filetype nor an override mapping,try MimeMap */
 if (value == -1)
  {
  rset.r[0] = MMM_TYPE_DOT_EXTN;
  rset.r[1] = (int)dosext;
  rset.r[2] = MMM_TYPE_RISCOS;
  if (_kernel_swi(MimeMap_Translate, &rset, &rset) == NULL)
   {
   value = rset.r[3];
   dprintf(("","filetype lookup,found in mimemap 0x%X3\n", value));
   }
  }
 /* Give up,just set it as 'DOStype' */
 if (value == -1)
 {
   dprintf(("","filetype lookup -%s- not found.. default to DOS\n",dosext ));
   value = FileType_MSDOS;
 }
 le->hi = (le->hi & ~ADFStypemask) | (value << ADFStypeshift) ;
 return;
}

/*---------------------------------------------------------------------------*/

void read_loadexec(DOS_direntry *dentry,char *dosext,time5byte *le)
{
 MSDOStoRISCOS(get_FILE_time(dentry),get_FILE_date(dentry),le) ;
 map_FILE_ROStype(dentry,dosext,le);
 return ;
}

/*---------------------------------------------------------------------------*/

void update_loadexec(DOS_direntry *dentry,word ld,word ex)
{
 time5byte     updateTIME ; /* local time described in passed addresses */
 int           cROStype = ((ld & ADFStypemask) >> ADFStypeshift) ;

 dprintf(("","update_loadexec: dentry = &%08X, ld = &%08X, ex = &%08X\n",(word)dentry,ld,ex));

 if (cROStype == FileType_MSDOS)
  {
   erase_ROStype(dentry) ; /* remove any possible RISC OS file-type */
  }
 else
  {
   put_FILE_ROStype(dentry,cROStype) ;
  }

 /* update the timestamp */
 updateTIME.lo = ex ;
 updateTIME.hi = (ld & 0xFF) ;
 put_FILE_time(dentry->FILE_time,dentry->FILE_timeHI,RISCOStoTIME(&updateTIME));
 put_FILE_date(dentry->FILE_date,dentry->FILE_dateHI,RISCOStoDATE(&updateTIME));

 return ;                    
}

/*---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------*
 * compare two objects
 *
 * in:  fptr -> full object name (NULL terminated)
 *      gptr -> wildcarded object name (NULL terminated)
 * out: boolean flag - TRUE (matched) - FALSE (failed match)
 */
int wild_card_compare(char *fptr, char *gptr, char wcmult, char wcsing)
{

// dprintf(("","WCC: fptr = \"%s\", gptr = \"%s\"\n",fptr,gptr));

 if (*fptr == '\0')
  {
   /* end of full name */
   if (*gptr == wcmult) /* if multiple wildcard character then continue */
   {
    return(wild_card_compare(fptr,&gptr[1],wcmult,wcsing)) ;
   }
   else
   {
    return(*gptr == '\0') ; /* matched if end of wildcarded name */
   }
  }
                     
 if (*gptr == '\0')
 {
  return(FALSE) ; /* end of wildcarded name reached before full name */
 }
 /* check if this character matches */
 if ( (toupper(*fptr) == toupper(*gptr)) || (*gptr == wcsing))
 {
  return(wild_card_compare(&fptr[1],&gptr[1],wcmult,wcsing)) ; /* yes - then continue */
 }

 if (*gptr == wcmult) /* if multiple wildcard character, check both paths */
 {
  return(wild_card_compare(fptr,&gptr[1],wcmult,wcsing)||wild_card_compare(&fptr[1],gptr,wcmult,wcsing)) ;
 }
 else
 {
  return(FALSE) ; /* characters do not match */
 }
}

/*-------------------------------------------------------------------------*/
/* Check if the given text string contains wildcard characters */

int checknotwildcarded(char *name, char wcmult, char wcsing)
{
 for (; (*name); name++)
  if ((*name == wcmult) || (*name == wcsing))
   return(-1) ; /* wildcard character has been found */

 return(0) ; /* OK : does not contain wildcard characters */
}

/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------*/
/* attributes: */

word DOStoRISCOSattributes(DOS_direntry *dentry)
{
 word aval = 0x00000000 ;
 int   loop ;

 /* produce RISC OS type attributes for the given DOS directory entry */

 /* all objects start read/write */
 if ((dentry->FILE_attribute & FILE_subdir) == 0)
  aval |= (read_attribute | write_attribute) ;

 for (loop=0; (loop < 8); loop++)
  {
   if ((dentry->FILE_attribute & (1 << loop)) != 0)
    {
     switch (1 << loop)
      {
       case FILE_readonly :
#if !ReadOnlyMapsLocked /* JRS 9/3/92 map DOS ReadOnly bit to RISC OS Locked bit only */
                            aval &= ~write_attribute ;
#endif
                            aval |= locked_attribute ;
                            break ;

/* JRS: 4/3/92 This conflicts with NetFS use of these bits */
       case FILE_hidden   : if ((dentry->FILE_attribute & NetFSattributebits)==0)
                             aval |= objecthidden ;
                            break ;

       case FILE_system   : if ((dentry->FILE_attribute & NetFSattributebits)==0)
                             aval |= objectsystem ;
                            break ;

       case FILE_archive  : if ((dentry->FILE_attribute & NetFSattributebits)==0)
                             aval |= objectupdated ;
                            break ;

       default            : break ;     /* no action on undefined flags */
      }
    }
  }

 return(aval) ;
}

/*---------------------------------------------------------------------------*/

unsigned char RISCOStoDOSattributes(word ROSattr)
{
 byte aval = 0x00 ;

 /* produce DOS type attributes for the given RISC OS attribute flags */

 /* NOT owner write then set the readonly flag */
#if ReadOnlyMapsLocked /* JRS 9/3/92 map DOS ReadOnly bit to RISC OS Locked bit only */
 if (ROSattr & locked_attribute)
#else
 if ((ROSattr & write_attribute) == 0 || (ROSattr & locked_attribute) != 0)
#endif
  aval |= FILE_readonly ;

 /* JRS: 4/3/92 HORRIBLE! This conficts with NetFS use of these bits
  * Check if the NetFS bits are zero, and assume they are ours if so */
 if ((ROSattr & NetFSattributebits & ~extraDOSattributebits) == 0)
  {
  /* check for the special flags we have placed in the ADFS unused area */
  if ((ROSattr & objecthidden) != 0)
   aval |= FILE_hidden ;

  if ((ROSattr & objectsystem) != 0)
   aval |= FILE_system ;

  if ((ROSattr & objectupdated) != 0)
   aval |= FILE_archive ;
  }

 return(aval) ;
}

