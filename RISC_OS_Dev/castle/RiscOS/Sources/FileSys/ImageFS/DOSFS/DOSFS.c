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
/*> c.DOSFS <*/
/*-------------------------------------------------------------------------*/
/* DOSFS (image filing system module)           Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <ctype.h>
#include <inttypes.h>
#include "kernel.h"
#include "swis.h"
#include "DebugLib/DebugLib.h"
#include "AsmUtils/rminfo.h"
#include "Global/CMOS.h"
#include "Global/OsBytes.h"
#include "Global/FileTypes.h"
#include "Global/Keyboard.h"
#include "Global/Variables.h"
#include "Global/Services.h"
#include "Interface/HighFSI.h"

#undef DOSFS_DiscFormat
#undef DOSFS_LayoutStructure

#include "DOSFS.h"
#include "TIMEconv.h"
#include "Helpers.h"
#include "Ops.h"
#include "MsgTrans.h"
#include "ADFSshape.h"
#include "DOSclusters.h"
#include "DOSnaming.h"
#include "DOSshape.h"
#include "DOSdirs.h"
#include "MultiFS.h"
#include "Statics.h"
#include "DOSFShdr.h"
#include "Accessors.h"

/*-------------------------------------------------------------------------*/
/* global (static) variables used within the module */

FILEhand    *FILE_list = NULL ;           /* Open file handle list */
mapentry    *maplist = NULL ;             /* DOS/RISC OS filetype mapping chain */
int         discopswi = FileCore_DiscOp;  /* Choice of whether we attempt a DiscOp64 or just DiscOp */
int         module_flags = 0 ;            /* Global flags */

/* The following are used for parameter returns to the RISC OS world. They
 * are provided as static structures to ensure they are not de-allocated
 * when we leave the C world (since normal variables are allocated from the
 * stack).
 */
FS_open_block fblock ;
FS_datestamp  tstamp ;
FS_cat_entry  fcat ;
FS_dir_block  dblock ;
FS_free_space fspace ;

/* These are used to create the MessageTrans tokens for the format menu
 * and help text.
 */
#define FORMAT_FMT     "FMT%d"
#define HELP_FMT       "FMTH%d"

/*-------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------*/
/* Register our filing system with RISC OS */

static _kernel_oserror *declare_FS(void *privateword)
{
 _kernel_swi_regs rset ;
 _kernel_oserror *err;
 word             infoblock[9] ; /* nasty constant */

 /* Read the CMOS RAM truncate bit state */
 rset.r[0] = OsByte_ReadCMOS;
 rset.r[1] = FileSwitchCMOS;
 if ((err = _kernel_swi(OS_Byte, &rset, &rset)) != NULL)
  return err;
 if (rset.r[2] & FileSwitchTruncateNamesCMOSBit) {
  dprintf(("","File names will be truncated.\n"));
  module_flags |= TRUNCATE_NAMES;
 } else {
  dprintf(("","Long file names will generate an error.\n"));
  module_flags &= ~TRUNCATE_NAMES;
 }

 /* register our module as an image filing system */
 /* "OS_FSControl" reason 35 */
 infoblock[0] = (word)0x00000000 ; /* bit27 is only significant flag */
 infoblock[1] = (word)FileType_MSDOSDisc ;
 infoblock[2] = ((word)DOSFS_Open     - (word)Image_RO_Base) ;
 infoblock[3] = ((word)DOSFS_GetBytes - (word)Image_RO_Base) ;
 infoblock[4] = ((word)DOSFS_PutBytes - (word)Image_RO_Base) ;
 infoblock[5] = ((word)DOSFS_Args     - (word)Image_RO_Base) ;
 infoblock[6] = ((word)DOSFS_Close    - (word)Image_RO_Base) ;
 infoblock[7] = ((word)DOSFS_File     - (word)Image_RO_Base) ;
 infoblock[8] = ((word)DOSFS_Func     - (word)Image_RO_Base) ;

 rset.r[0] = FSControl_RegisterImageFS;
 rset.r[1] = (word)Image_RO_Base ;
 rset.r[2] = ((word)infoblock - (word)Image_RO_Base) ;
 rset.r[3] = (word)privateword ;

 return(_kernel_swi(OS_FSControl,&rset,&rset)) ;
}

/*-------------------------------------------------------------------------*/
/* select_FS:
 * Select "DOSFS" as the current filing system.
 */
static _kernel_oserror *select_FS(void)
{
 _kernel_swi_regs rset ;

 rset.r[0] = FSControl_SelectFS ;               /* operation */
 rset.r[1] = (unsigned int)Module_Title ;       /* filing system name */
 return(_kernel_swi(OS_FSControl,&rset,&rset)) ;
}

/*-------------------------------------------------------------------------*/

static _kernel_oserror *FSSWI_DiscFormat(_kernel_swi_regs *rset,void *privateword)
{
 /* in:  r0 = pointer to disc format structure to be filled in
  *      r1 = vetting SWI (normally "ADFS_VetFormat")
  *      r2 = r1 parameter to the vetting SWI
  *      r3 = format specifier
  * out: r0 = pointer to disc format specification structure (updated)
  */
 _kernel_swi_regs  urset ;
 _kernel_oserror  *rerror = NULL ;
 format_spec      *fspec ;

 dprintf(("","DOSFS: FSSWI_DiscFormat: r0 = &%08X, r1 = &%08X, r2 = &%08X, r3 = &%08X\n",
             rset->r[0],rset->r[1],rset->r[2],rset->r[3]));

 /* see "format_spec" structure in "MultiFS.h" */
 /* place the desired disk format specification into the referenced structure */
 fspec = &(DOS_formatinfo[DOS_formats[rset->r[3]].findex]) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: found format_spec &%08X\n",(word)fspec)) ;
 (void)memmove((void *)rset->r[0],fspec,sizeof(format_spec)) ;

 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->secsize  = %d\n",fspec->secsize)) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->secstrk  = %d\n",fspec->secstrk)) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->density  = %d\n",fspec->density)) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->options  = &%02X\n",fspec->options)) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->startsec = %d\n",fspec->startsec)) ;
 dprintf(("","DOSFS: FSSWI_DiscFormat: fspec->tracks   = %d\n",fspec->tracks)) ;

 /* "VetFormat" SWI call:
  * in:  r0 = pointer to required format structure
  *      r1 = VetFormat parameter (r2 passed to "DiscFormat")
  * out: registers preserved (but structure possibly upgraded)
  */
 urset.r[0] = rset->r[0] ; /* copy of disc format structure */
 urset.r[1] = rset->r[2] ; /* parameter for the VetFormat call */
 if ((rerror = _kernel_swi(rset->r[1],&urset,&urset)) == NULL)
  {
   /* Re-check that the structure is still acceptable to us:
    *  Fields that cannot change:
    *     fspec->secsize  fspec->secstrk  fspec->density  fspec->options  fspec->startsec  fspec->tracks
    *
    * Fields that can possibly be changed:
    *     fspec->gap1side0  fspec->gap1side1  fspec->gap3
    * Some research is needed here to discover what values are acceptable
    * to standard MS-DOS machines.
    *
    * Fields that are acceptable to change:
    *     fspec->secileave  fspec->sideskew  fspec->trackskew  fspec->fillvalue
    */
   format_spec *rfspec = (format_spec *)urset.r[0] ;
   if ((rfspec->secsize != fspec->secsize) || (rfspec->secstrk != fspec->secstrk) || (rfspec->density != fspec->density) || (rfspec->options != fspec->options) || (rfspec->startsec != fspec->startsec) || (rfspec->tracks != fspec->tracks))
    rerror = global_error(err_badformat) ; /* changes unacceptable to us */
  }

 return(rerror) ;
 UNUSED(privateword) ;
}

static int testforbpb(ADFS_drecord *dr,char *sector,bool floppy,
                      int *numFATs,uint64_t *FATsize,int *magic,int *ROOTsize,
                      bool *Atari,bool *dblstep,int *numRESVD,word *volumeid)
{
 DOS_bootsector  *bblock = (DOS_bootsector *)sector;
 int discSize, noSides;

 /* Can only make sketchy test for a valid boot block, later test should fail */
 /* if the boot block is not really valid */
#ifdef NONFLOPPIES
 if (sector_size(bblock) == DOSsecsize)
#else
 if (sector_size(bblock) == DOSsecsize || bblock->BOOT_num_fats == 2)
#endif
    {
    /* Get number of sectors and number of sectors per track from BOOT block. */
    word maxsector = max_sector(bblock);
    word notracks = READ_LOHI(bblock->BOOT_secstrack);

    if (notracks == 0) return 1;

    notracks = maxsector / notracks; /* Calculate number of tracks from BOOT block. */
    uint64_t bbsize = ((uint64_t) maxsector) * DOSsecsize; /* Calculate disc size from BOOT block. */
 
    /* Calculate disc size too using disc record info. */
    discSize = (secspertrk(dr) * bytespersec(dr) * notracks) ;

    dprintf(("","DOSFS: testforbpb: discSize = &%08X\n",discSize)) ;
    dprintf(("","DOSFS: testforbpb: check size = &%016" PRIX64 "\n",bbsize)) ;

#ifdef NONFLOPPIES
    /* Now have to cope with solid state media with bits of first track "missing" */
    /* but if it's not a floppy we can't be sure of the real size */
    if (((bbsize < (((uint64_t) discSize) + (((uint64_t) secspertrk(dr))*bytespersec(dr)))) && (bbsize >= discSize)) || !floppy)
#else
    /* Validate the calculated size matches the discsize filecore has guessed */
    /* but if it's not a floppy we can't be sure of the real size*/
    if ((bbsize == discSize) || !floppy)
#endif
       {
       noSides = bblock->BOOT_heads;
       if (noSides > 0)
          {
          /* It's a DOS disc so claim it as one of ours and set up the disc record info. */
          if (bbsize > UINT32_MAX)
          {
            dprintf(("","DOSFS: testforbpb: disc too big\n"));
            return 1;
          }
          *magic = bblock->BOOT_magic;
          *ROOTsize = (READ_LOHI(bblock->BOOT_root_dir) * sizeof(DOS_direntry)) ;
          *FATsize = ((uint64_t) READ_LOHI(bblock->BOOT_FAT_size)) * DOSsecsize;
          *numFATs = bblock->BOOT_num_fats;
          *Atari = (bblock->BOOT_JMP[0] == 0); /* No JMP means Atari */
          *numRESVD = READ_LOHI(bblock->BOOT_reserved) ;
          *dblstep = ((notracks / noSides) == 40);
          if (bblock->BOOT_extra.fat12.sig_rec == 0x29)
             {
             /* There's an extended boot record,note the volume id */
             *volumeid = READ_0123(bblock->BOOT_extra.fat12.volid);
             }
          else if (bblock->BOOT_extra.fat32.BootSig == 0x29)
             {
             /* There's an extended FAT32 boot record,note the volume id */
             *volumeid = READ_0123(bblock->BOOT_extra.fat32.VolID);
             /* use correct ROOTsize */
             if (0 == *ROOTsize)
                *ROOTsize = cluster_size(bblock);
             /* .. and also correct FAT size */
             if (0 == *FATsize)
                {
                *FATsize = ((uint64_t) READ_0123(bblock->BOOT_extra.fat32.FAT_sz)) * DOSsecsize;
                }
             }
          discsize(dr) = (word) bbsize; /* Use bbsize incase FileCore was guessing discSize */
          heads(dr) = noSides;
          if (!floppy) secspertrk(dr) = READ_LOHI(bblock->BOOT_secstrack);
          return 0;
          }
       }
    }
    
 dprintf(("","DOSFS: testforbpb: FileCore and BOOT BLOCK disc sizes differ\n"));
 return 1;
}

static int testforpartition(ADFS_drecord *dr,char *sector,uint64_t *winioffset,
                            int *numFATs,uint64_t *FATsize,int *magic,int *ROOTsize,
                            bool *Atari,bool *dblstep,int *numRESVD,word *volumeid,
                            struct image_accessor *a)
{
 DOS_bootsector  *bblock = (DOS_bootsector *)sector;
 _kernel_oserror *rerror = NULL ; 
 byte  *pentry ;         /* partition description pointer */
 word   winisize = 0 ;   /* media size (sectors) */
 int    index;
 
 /* This may be a partition on a fixed disc though, so let's have a look */
 if (READ_LOHI(bblock->BOOT_extra.fat12.BOOT_signature) != DOS_PARTITION_signature)
    return 1;

 /* If there's a bootable partition,take that in preference to any other */
 for (index=0; index < 4; index++)
     {
     pentry = (byte *)&(bblock->BOOT_extra.fat12.partitions[index*sizeof(partition_entry)]);
     if (pentry[0] == bootable) break;
     }
 if (index == 4)
    {
    /* Try non bootable partitions whose start sector != 0 */
    for (index=0; index < 4; index++)
        {
        pentry = (byte *)&(bblock->BOOT_extra.fat12.partitions[index*sizeof(partition_entry)]);
        if (pentry[2] != 0) break;
        }
    }

 if (index == 4) return 1;

 /* Got a vaguely valid partition,go with it */
 *winioffset = ((uint64_t) loadWORD(pentry+8)) * DOSsecsize;
 winisize = loadWORD(pentry+12);
 dprintf(("","DOSFS: testforpartition: Found partition at winioffset = &%016" PRIX64 "\n",*winioffset));

 dprintf(("","DOSFS: testforpartition: reading sector from &%016" PRIX64 "\n",dr->dr_rootSIN + *winioffset));
 if ((rerror = image_readwrite(*winioffset,
                               sizeof(DOS_bootsector),
                               bblock,
                               ACC_READ+ACC_USE_CACHE,
                               a)) == NULL)
    {
    word fatsize, rootsize, bbsize = max_sector(bblock);

    rootsize = READ_LOHI(bblock->BOOT_root_dir) * sizeof(DOS_direntry);
    if (rootsize == 0)
       {
       /* Adjust to at least 1 cluster */
       rootsize = cluster_size(bblock); 
       }

    fatsize = READ_LOHI(bblock->BOOT_FAT_size); 
    if (fatsize == 0)
       {
       /* Try the FAT32 declaration instead */
       fatsize = READ_0123(bblock->BOOT_extra.fat32.FAT_sz);
       }

    if (bblock->BOOT_extra.fat12.sig_rec == 0x29)
       {
       /* There's an extended boot record,note the volume id */
       *volumeid = READ_0123(bblock->BOOT_extra.fat12.volid);
       }
    if (bblock->BOOT_extra.fat32.BootSig == 0x29)
       {
       /* There's an extended FAT32 boot record,note the volume id */
       *volumeid = READ_0123(bblock->BOOT_extra.fat32.VolID);
       }

    /* A few more sector sanity checks */
    dprintf(("","DOSFS: testforpartition: bbsize=%08X, winisize=%08X, fatsize=%08X sectors\n", bbsize, winisize, fatsize));
    if (bbsize == 0) return 1; /* Bad start */
    if (bbsize > winisize) return 1; /* Image is bigger than the partition table has set aside. */
    if (fatsize > bbsize) return 1; /* FAT is somehow bigger than the entire image. */
    if ((rootsize / DOSsecsize) > bbsize) return 1; /* Root directory takes more sectors than the entire image. */
    uint64_t discsz = *winioffset + ((uint64_t) bbsize)*DOSsecsize;
    if (discsz > UINT32_MAX)
    {
       dprintf(("","DOSFS: disc too big for 32bit discsize\n"));
       return 1; 
    }

    /* It's a DOS disc so claim it as one of ours and set up the disc record info. */
    *magic = bblock->BOOT_magic;
    *ROOTsize = rootsize;
    *FATsize = ((uint64_t) fatsize) * DOSsecsize;
    *numFATs = bblock->BOOT_num_fats;
    *Atari = false; /* Never Atari */
    *numRESVD = READ_LOHI(bblock->BOOT_reserved) ;
    *dblstep = false; /* Never double step */
    discsize(dr) = discsz; /* Update discsize, in case FileCore was guessing the size */
    heads(dr) = 0; /* It's a harddisc */
    secspertrk(dr) = READ_LOHI(bblock->BOOT_secstrack);    
     
    dprintf(("","DOSFS: testforpartition magic=%02X root=%x fat=%" PRIx64 " (x%d copies) resvd=%d\n",(int)*magic,(int)*ROOTsize,*FATsize,(int)*numFATs,(int)*numRESVD));
    return 0;
    }
    
 return 1;
}

static int testfor160360k(ADFS_drecord *dr,char *sector,bool floppy,
                          int *numFATs,uint64_t *FATsize,int *magic,int *ROOTsize,
                          bool *Atari,bool *dblstep,int *numRESVD)
{
 /* If we have not claimed the disc then it could still be valid only if it is a 320K or
  * 160K format, both of which have 8 sectors per track (these old formats need not have a
  * valid boot block)
  */
 if (secspertrk(dr) != 8)
    {
    dprintf(("","DOSFS: testfor160360k: not 320K or 160K format 8 sectors per track\n"));
    return 1;
    }
 /* Defaults for 320K and 160K formats */
 *magic = 0;
 /* ROOTsize could be 112 or 64 entries,we'll find out later by inspecting the FAT */
 *FATsize = DOSsecsize;
 *numFATs = 2;
 *Atari = false;
 *numRESVD = 1;
 *dblstep = true;
 /* discsize(dr) = guessed from FAT entry later */
 /* heads(dr) = guessed from FAT entry later */
 /* secspertrk() = no BPB so don't know,but it must be a floppy so don't care either */

 UNUSED(floppy);
 UNUSED(sector);
 UNUSED(ROOTsize);
 return 0;
}

static void validatedosformat(ADFS_drecord *dr,_kernel_swi_regs *rset)
{
 /* In response to Service_IdentifyDisc this will have a few goes at working */
 /* out if this will pass as a DOS disc image. Note that exactly which test  */
 /* is performed depends on whether it's a harddisc or a floppy disc         */

 _kernel_oserror *rerror = NULL ; 
 char *sector,*sectorblock;
 byte *name;
 DOS_bootsector  *bblock;
 bool  dblstep;
 int   numFATs;
 uint64_t FATsize; /* bytes */
 int   numRESVD, ROOTsize;
 int   magic = 0;
 bool  Atari = false;
 int   discID = 0;
 char *buf = 0;
 int   bufsz = 0;
 uint64_t winioffset = 0; /* bytes */
 word  volumeid = 0;
 bool  floppy = !((log2secsize(dr) == 0) || (dr->dr_floppy_density == 0) || (secspertrk(dr) == 0) || (heads(dr) == 0));
 int   loop, step;

 dprintf(("","DOSFS: validatedosformat: treating as a %s disc\n",floppy ? "floppy" : "fixed"));
 /* If it is a floppy then insist on a few floppyesque parameters */
 if (floppy && ((log2secsize(dr) != log2DOSsecsize) || (tracklow(dr) != 1) || (trackskew(dr) != 0)))
    {
    dprintf(("","DOSFS: validatedosformat: floppy fails even basic DOS parameters\n"));
    return;
    }
    
 /* Get some memory to load a sector */
 sector = (char *)malloc(DOSsecsize) ;
 if (sector == NULL)
    {
    dprintf(("","DOSFS: validatedosformat: failed to get memory\n"));
    return;
    }
 bblock = (DOS_bootsector *)sector;

 /* Sector 1, track 0 should always be readable regardless of the specific DOS format */
 image_accessor_disc a = new_image_accessor_disc(dr,rset->r[6],rset->r[8]);

 dprintf(("","DOSFS: validatedosformat: reading sector from &%08X\n",dr->dr_rootSIN));
 /* Try a read of the disc */
 if ((rerror = image_readwrite(0,sizeof(DOS_bootsector),bblock,ACC_READ+ACC_USE_CACHE,&a.a)) != NULL)
    {
    free(sector);
    dprintf(("","DOSFS: validatedosformat: failed to read 0th sector\n"));
    return;
    }

 dprintf(("","DOSFS: validatedosformat: sector read OK\n"));
 /* See if the sector read contains a BPB */
 if (testforbpb(dr,sector,floppy,&numFATs,&FATsize,&magic,&ROOTsize,
                &Atari,&dblstep,&numRESVD,&volumeid))
    {
    /* Crusty 160 & 360k floppies don't need one */
    if (!floppy || testfor160360k(dr,sector,floppy,&numFATs,&FATsize,&magic,&ROOTsize,
                                  &Atari,&dblstep,&numRESVD))
       {
       /* Last ditch attempt scanning for partitions on harddiscs */
       if (floppy || testforpartition(dr,sector,&winioffset,&numFATs,&FATsize,&magic,&ROOTsize,
                                      &Atari,&dblstep,&numRESVD,&volumeid,&a.a))
          {
          free(sector);
          dprintf(("","DOSFS: validatedosformat: shame,not a DOS disc\n"));
          return;
          }
       }
    }

 /* Update the disc record with what we know now */
 put_doublestep(dr, dblstep);
 put_sequence(dr, 0);

 /* Read the FAT.  This will be used to identify a 320K or 160K format if necessary and
  * also to calculate a disc ID to pass back to FileCore.
  */
 dprintf(("","DOSFS: validatedosformat: reading FAT\n"));
 sectorblock = ((FATsize < (1<<30)) ? realloc(sector,(size_t) FATsize) : NULL);
 if (sectorblock == NULL)
    {
    step = DOSsecsize; /* Low on memory,so FAT is read one sector at a time */
    }
 else
    {
    sector = sectorblock;
    step = (int) FATsize;    /* Enough memory to load the whole FAT at once */
    }

 for (uint64_t index = 0; index < FATsize; index += step)
     {
     if ((rerror = image_readwrite(index + ((uint64_t) numRESVD) * DOSsecsize + winioffset,
                                   step,
                                   sector,
                                   ACC_READ + (floppy ? ACC_USE_CACHE : 0),
                                   &a.a)) == NULL)
        {
        /* Check the first byte of the FAT for the 320K or 160K media type. */
        if ((*sector == 0xFE) && (magic==0) && (index==0))
           {
           magic = 0xFE;
           ROOTsize = 64 * sizeof(DOS_direntry);
           discsize(dr) = 0x28000;
           heads(dr) = 1;
           }
        if ((*sector == 0xFF) && (magic==0) && (index==0))
           {
           magic = 0xFF;
           ROOTsize = 112 * sizeof(DOS_direntry);
           discsize(dr) = 0x50000;
           heads(dr) = 2;
           }
        }
     /* We're certain it's a DOS disc so calculate a disc ID from the FAT contents */
     for (loop = 0; loop < step; loop++)
         discID += sector[loop] ;
     }

 /* In all circumstances we'd have deduced the magic number by now */
 if (magic == 0)
    {
    free(sector);
    dprintf(("","DOSFS: validatedosformat: don't know the magic number by any method\n"));
    return;
    }
    
 /* Claim the service and fill in the disc record.    */
 /* Get the default disc name from the Messages file. */
 dprintf(("","DOSFS: validatedosformat: accepted disc type &%02X\n",magic));
 dprintf(("","DOSFS: validatedosformat: cycleID was 0x%x\n", discID));
 dprintf(("","DOSFS: validatedosformat: discsize was 0x%x\n", discsize(dr)));

 /* Lookup default disc name. */
 if ((rerror = msgtrans_lookup("DEFDNM", &buf, &bufsz, 0, 0, 0, 0)) != NULL)
    {
    buf = rerror->errmess;
    bufsz = strlen(buf);
    }
 if (bufsz > 9) bufsz = 9;
 strncpy((char *)(dr->dr_discname), buf, bufsz);
 dr->dr_discname[bufsz] = '\0';

 /* A volume id is better than the default */
 if (volumeid != 0) sprintf((char*)(dr->dr_discname),"%04X-%04X",(volumeid >> 16) & 0xFFFF,volumeid & 0xFFFF);
 
 /* Try to find a volume label on the disc. */
 for (loop = 0; loop < ROOTsize; loop+= DOSsecsize)
     {
     if ((rerror = image_readwrite((numFATs * FATsize) + loop + ((uint64_t) numRESVD) * DOSsecsize + winioffset,
                                   DOSsecsize,
                                   sector,
                                   ACC_READ + (floppy ? ACC_USE_CACHE : 0),
                                   &a.a)) == NULL)
        {
        DOS_direntry *dentry;
        
        int index = 0;
        if ((dentry = findDIRtype((byte)FILE_win95,(byte)FILE_volume,(DOS_direntry *)sector,DOSsecsize,&index)) != NULL)
           {
           char label[discnamesize];

           dprintf(("","DOSFS: validatedosformat: volume label found\n") );
           index = 0;

           /* Copy to our name limit, replacing invalid characters along the way */
           for (name = &dentry->FILE_status; isalnum(*name) && (index < (discnamesize-1)); name++)
           {
             label[index] = mapchar(*name,DOSmapping,ROmapping);
             index++;
           }
           label[index] = '\0'; /* Terminate */
           if (strlen(label) < 2)
           {
             dprintf(("","DOSFS: validatedosformat: volume \"%s\" too short, ignored\n",label));
           }
           else
           {
             strcpy((char *)dr->dr_discname, label);
           }
           break; /* End search */
           }
        }
     }
 dprintf(("","DOSFS: validatedosformat: volume \"%s\" (id=%08x)\n",(char *)dr->dr_discname,volumeid));

#ifndef PRE218
 /* Write format name into buffer. */
 if (rset->r[2] != 0)
    {
    char token[8];
    for (loop = 0; DOS_formats[loop].magic_ID != 0; loop++)
        {
        if (magic == DOS_formats[loop].magic_ID)
           {
           /* If type is &F9 then we need more tests. */
           if (magic == 0xF9)
              {
              if (Atari && strcmp(DOS_formats[loop].idtext, "Atari/M"))
                 continue;
              if (FATsize != ((uint64_t) DOS_formats[loop].secsFAT) * DOSsecsize)
                 continue;
              }
           break;
           }
        }
    sprintf(token, FORMAT_FMT, loop + 1);
    buf = (char *)rset->r[2];
    bufsz = rset->r[3];
    if ((rerror = msgtrans_lookup(token, &buf, &bufsz, 0, 0, 0, 0)) != NULL)
       {
       bufsz = strlen(rerror->errmess);
       strncpy(buf, rerror->errmess, bufsz);
       }
    buf[bufsz] = '\0';
    dprintf(("","DOSFS: validatedosformat: format name = \"%s\"\n", buf));
    }
#endif

 /* Claim the service and fill in the disc record. */
 rset->r[1] = Service_Serviced;
 put_discID(dr, discID);     /* Still pointed to by R5 */
 rset->r[2] = FileType_MSDOSDisc ;    /* filetype to be associated with the disc image */
 rset->r[6] = a.sector_cache_handle ;   /* sector cache handle returned from "FileCore_DiscOp{64}" */
 return;
}

/*-------------------------------------------------------------------------*/
/* NOTE: This code currently only deals with floppy structures             */

static _kernel_oserror *FSSWI_LayoutStructure(_kernel_swi_regs *rset,void *privateword)
{
 /* in:  r0 = disc structure identifier (r5 from "Service_IdentifyFormat")
  *      r1 = pointer to -1 terminated list of bad blocks
  *      r2 = pointer to NULL terminated disc name
  *      r3 = file handle of system image
  * out:
  */
 _kernel_swi_regs  reglist ;
 _kernel_oserror  *rerror = NULL ;
  char *sector = NULL;

 dprintf(("", "DOSFS: FSSWI_LayoutStructure: r0 = &%08X, r1 = &%08X, r2 = &%08X, r3 = &%08X\n",rset->r[0],rset->r[1],rset->r[2],rset->r[3]));

 /* Bounds check */
 if (rset->r[0] > 8) {
     rerror = global_error(err_badformat);
     return(rerror);    /* Quit! */
 }

 /* Place default BOOT BLOCK (shape defined by r0 on entry) */
 if ((sector = (char *)malloc(DOSsecsize)) != NULL)
  {
   DOS_bootsector *dbsector = (DOS_bootsector *)sector; /* BOOT BLOCK for image */
   int findex = DOS_formats[rset->r[0]].findex ;
   int maxsect = (DOS_formatinfo[findex].secstrk * DOS_formatinfo[findex].tracks) ;

   dprintf(("","Findex = %d\n", findex));

   *dbsector = *(default_dbsector) ; /* copy the structure across */
   /* write format specific information (dictated by entry r0 parameter) */
   dbsector->BOOT_secalloc = DOS_formats[rset->r[0]].secsclus;
   dbsector->BOOT_root_dir = DOS_formats[rset->r[0]].rootsize;
   /* dbsector->BOOT_root_dirHI = 0x00; */
   dbsector->BOOT_max_sect = ((maxsect >> 0) & 0xFF) ;
   dbsector->BOOT_max_sectHI = ((maxsect >> 8) & 0xFF) ;
   dbsector->BOOT_magic = DOS_formats[rset->r[0]].magic_ID ;
   dbsector->BOOT_secstrack = ((DOS_formatinfo[findex].secstrk >> 0) & 0xFF) ;
   dbsector->BOOT_secstrackHI = ((DOS_formatinfo[findex].secstrk >> 8) & 0xFF) ;
   dbsector->BOOT_FAT_size = DOS_formats[rset->r[0]].secsFAT;
   /* dbsector->BOOT_FAT_sizeHI = 0x00; */
   switch (DOS_formatinfo[findex].options & sideinfomask) {
    case o_alternate:
    case o_sequence:
     dbsector->BOOT_heads = 2;
     break;
    default:
     dbsector->BOOT_heads = 1;
   }

   /* Special code for Atari formats */
   if ((strcmp(DOS_formats[rset->r[0]].idtext,"Atari/M") == 0) || (strcmp(DOS_formats[rset->r[0]].idtext,"Atari/N") == 0))
    {
     /* Atari formats have no jmp instruction in the boot block,and a 24bit volume serial number in the OEM id */
     dbsector->BOOT_JMP[0] =  dbsector->BOOT_JMP[1] = dbsector->BOOT_JMP[2] = 0;
     dbsector->BOOT_OEM[5] = (rand() & 0xFF) ;
     dbsector->BOOT_OEM[6] = (rand() & 0xFF) ;
     dbsector->BOOT_OEM[7] = (rand() & 0xFF) ;
    }

   /* write the BOOT BLOCK into the image */
   reglist.r[0] = OSGBPB_WriteAtGiven ;    /* write operation */
   reglist.r[1] = rset->r[3] ;             /* FileSwitch handle */
   reglist.r[2] = (word)dbsector ;         /* data address */
   reglist.r[3] = DOSsecsize ;             /* amount of data */
   reglist.r[4] = 0x00000000 ;             /* destination image offset */
   reglist.r[5] = NULL ;
   reglist.r[6] = NULL ;
   if ((rerror = _kernel_swi(OS_GBPB,&reglist,&reglist)) == NULL)
    {
     int   FATsize = (dbsector->BOOT_FAT_size|(dbsector->BOOT_FAT_sizeHI<<8));
     int   numFATs = dbsector->BOOT_num_fats;
     word  ROOTsize = ((dbsector->BOOT_root_dir | (dbsector->BOOT_root_dirHI << 8)) * sizeof(DOS_direntry)) / DOSsecsize;
     word offset = ((DOS_FAT_sector - 1) * DOSsecsize) ;
     int  loop ; /* general index counter */

     for (loop = 0; loop < DOSsecsize; loop++)
      sector[loop] = '\0' ; /* zero sector buffer */
     /* Can no longer take data from dbsector. */

     /* Create FATs */
     while (numFATs--) {
      sector[0] = DOS_formats[rset->r[0]].magic_ID ;
      sector[1] = 0xFF ;
      sector[2] = 0xFF ;
      for (loop = 0; loop < FATsize; loop++) {
       reglist.r[0] = OSGBPB_WriteAtGiven ;    /* write operation */
       reglist.r[1] = rset->r[3] ;             /* FileSwitch handle */
       reglist.r[2] = (word)sector ;           /* data address */
       reglist.r[3] = DOSsecsize ;             /* amount of data */
       reglist.r[4] = offset ;                 /* destination image offset */
       reglist.r[5] = NULL ;
       reglist.r[6] = NULL ;
       if ((rerror = _kernel_swi(OS_GBPB,&reglist,&reglist)) != NULL)
        break ; /* out of the FAT writing loop */
       offset += DOSsecsize ;
       if (loop)
        continue;
       sector[0] = sector[1] = sector[2] = 0;
      }
     }

     if (rerror == NULL) {
      DOS_direntry *dentry = (DOS_direntry *)sector ;
      time5byte     formTIME ;

      get_RISCOS_TIME(&formTIME) ;

      /* place the default disc name into the first slot */
      put_FILE_time(dentry->FILE_time,dentry->FILE_timeHI,RISCOStoTIME(&formTIME)) ;
      put_FILE_date(dentry->FILE_date,dentry->FILE_dateHI,RISCOStoDATE(&formTIME)) ;

      /* Copy title into block,pad with spaces (not nulls),and mark as a volume title */

      memset((char *)&(dentry->FILE_status),32,namsize+extsize);
      memcpy((char *)&(dentry->FILE_status),(char *)rset->r[2],strlen((char *)rset->r[2]));
      dentry->FILE_attribute = (FILE_volume | FILE_archive) ;

      /* Write the root directory. */
      for (loop = 0; loop < ROOTsize; loop++) {
       int i;
       reglist.r[0] = OSGBPB_WriteAtGiven ; /* write operation */
       reglist.r[1] = rset->r[3] ;          /* FileSwitch handle */
       reglist.r[2] = (word)sector ;        /* data address */
       reglist.r[3] = DOSsecsize ;          /* amount of data */
       reglist.r[4] = offset ;              /* destination image offset */
       reglist.r[5] = NULL ;
       reglist.r[6] = NULL ;
       if ((rerror = _kernel_swi(OS_GBPB,&reglist,&reglist)) != NULL)
        break;
       offset += DOSsecsize;
       if (loop)
        continue;
       for (i = 0; i < sizeof(DOS_direntry); i++)
        sector[i] = 0;
      }
     }
    }
   free(sector) ;
  }
 else
  rerror = global_errorT(err_heapexhausted, tok_heapexhausted, 0, 0) ;

 return(rerror) ;
 UNUSED(privateword) ;
}

/*-------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------*/
/* Vector through to the relevant SWI handler */
_kernel_oserror *fs_swi(int swi_no,_kernel_swi_regs *rset,void *privateword)
{
 switch(swi_no + DOSFS_00)
  {
   case DOSFS_DiscFormat :
             return(FSSWI_DiscFormat(rset,privateword)) ;
             break ;

   case DOSFS_LayoutStructure :
             return(FSSWI_LayoutStructure(rset,privateword)) ;
             break ;

   default : /* unknown */
             dprintf(("","DOSFS: return unknown SWI (%d) error\n",swi_no) );
             return global_errorT(err_badswi, tok_badswi, "DOSFS", 0);
             break ;
  }

 return(NULL) ;
}

/*-------------------------------------------------------------------------*/
/* Provide handlers for the services we intercept */

void fs_service(int service_number,_kernel_swi_regs *rset,void *privateword)
{
 /* Note: We should NOT perform any IO from these functions */
 switch (service_number)
  {
   case 0x11 : /* Service_Memory */
               /* if (rset->r[2] == module base addr) then claim this call */
               if (rset->r[2] == Image_RO_Base)
                {
                 dprintf(("","DOSFS: Service_Memory (0x11): matched\n")) ;
                 rset->r[1] = Service_Serviced ; /* claim this service */
                }
               break ;

   case 0x12 : /* Service_StartUpFS */
               select_FS() ;
               break ;

   case 0x27 : /* Service_Reset */
               dprintf(("","DOSFS: Service_Reset: called\n")) ;
               break ;

   case 0x40 : /* Service_FSRedeclare */
               declare_FS(privateword) ;
               break ;

   case 0x5C : /* Service_WimpSaveDesktop */
               dprintf(("","DOSFS: Service_WimpSaveDesktop: called\n")) ;
               dprintf(("","DOSFS: WimpSaveDesktop: r0 = &%08X\n",rset->r[0])) ;
               dprintf(("","DOSFS: WimpSaveDesktop: r1 = &%08X\n",rset->r[1])) ;
               dprintf(("","DOSFS: WimpSaveDesktop: r2 = &%08X\n",rset->r[2])) ;
               /* r0 = 0x00 */
               /* r1 = 0x5C - Service_WimpSaveDesktop */
               /* r2 = FileSwitch file handle */
               {
                _kernel_oserror  *rerror = NULL ;
                _kernel_swi_regs  reglist ;
                mapentry         *cptr = maplist ;
                char             *tbuff ;

                tbuff = (char *)malloc(strlen("DOSMap DOS FFF\n") + 1) ;
                /* we do not do anything if we failed to alloc memory */
                if (tbuff != NULL)
                 {
                  for (; (cptr != NULL); cptr = cptr->next)
                   {
                    int loop ;
                    sprintf(tbuff,"DOSMap ") ;
                    for (loop = 0; (loop < 7); loop++)
                     {
                      char cchr = (*(char*)(cptr->dosext + (loop ))) ;
                      cchr = (((cchr > ' ') && (cchr != 0x7F)) ? cchr : ' ') ;
                      sprintf(&tbuff[strlen(tbuff)],"%c",cchr) ;
                     }
                    sprintf(&tbuff[strlen(tbuff)]," %03X\n",cptr->ROtype) ;
                    reglist.r[0] = OSGBPB_WriteAtPTR ; /* write operation */
                    reglist.r[1] = rset->r[2] ; /* FileSwitch handle */
                    reglist.r[2] = (word)tbuff ; /* data address */
                    reglist.r[3] = strlen(tbuff) ; /* amount of data */
                    reglist.r[4] = NULL ; /* destination image offset */
                    reglist.r[5] = NULL ;
                    reglist.r[6] = NULL ;
                    if ((rerror = _kernel_swi(OS_GBPB,&reglist,&reglist)) != NULL)
                     {
                      rset->r[0] = (word)rerror ; /* pointer to error block */
                      rset->r[1] = Service_Serviced ;
                      break ; /* out of for loop */
                     }
                   }
                  free(tbuff) ;
                 }
               }
               break ;
#ifndef ROM
   case 0x60 : /* Service_ResourceFSStarting */
               (*(void (*)(void *, void *, void *, void *))rset->r[2])(dosfs_msgarea(), 0, 0, (void *)rset->r[3]);
               break;
#endif
   case 0x69 : /* Service_IdentifyDisc */
               /* in:   r1 = Service_IdentifyDisc */
               /*       r2 = Pointer to buffer for format name */
               /*       r3 = Length of format name buffer */
               /*       r5 = pointer to disc record */
               /*       r6 = sector cache handle */
               /*       r8 = pointer to filecore instance private word */
               /* out:  r1 = Service_Serviced (NULL) */
               /*       r2 = filetype number for given disc format */
               /*       r5 = pointer to disc record (possibly updated) */
               /*       r6 = new sector cache handle */
               /*       r8 = preserved */
               dprintf(("", "DOSFS: Service_IdentifyDisc: r5 = &%08X, r6 = &%08X, r8 = &%08X\n",
                            rset->r[5],rset->r[6],rset->r[8]));
               {
                ADFS_drecord *dr = (ADFS_drecord *)rset->r[5] ;

                dprintf(("","DOSFS: Service_IdentifyDisc: log2secsize(dr) = %d\n",log2secsize(dr))) ;
                dprintf(("","DOSFS: Service_IdentifyDisc: secspertrk(dr) = %d\n",secspertrk(dr))) ;
                dprintf(("","DOSFS: Service_IdentifyDisc: heads(dr) = %d\n",heads(dr)));
                dprintf(("","DOSFS: Service_IdentifyDisc: dr->dr_floppy_density = %d\n",dr->dr_floppy_density)) ;
                dprintf(("","DOSFS: Service_IdentifyDisc: discsize(dr) = &%X\n",discsize(dr)));
                dprintf(("","DOSFS: Service_IdentifyDisc: doublestep(dr) = %d\n",doublestep(dr)));
                dprintf(("","DOSFS: Service_IdentifyDisc: sequence(dr) = %d\n",sequence(dr)));
                dprintf(("","DOSFS: Service_IdentifyDisc: tracklow(dr) = %d\n",tracklow(dr)) );
                dprintf(("","DOSFS: Service_IdentifyDisc: trackskew(dr) = %d\n",trackskew(dr)) );
                dprintf(("","DOSFS: Service_IdentifyDisc: disctype(dr) = &%03X\n",disctype(dr)) );
                dprintf(("","DOSFS: Service_IdentifyDisc: bigflag = &%X\n",dr->dr_bigflag) );

                validatedosformat(dr, rset);
                dprintf(("","DOSFS: Service_IdentifyDisc: exit with r1 = &%X\n",rset->r[1]));
               }
               break ;

   case 0x6A : /* Service_EnumerateFormats */
               /* in:   r0 = 0 */
               /*       r1 = Service_EnumerateFormats */
               /* out:  r0 = pointer to linked list of format specifications (as RMA blocks) */
               /*       r1 = preserved */
               {
                format_info **next ;
                int          loop ;

                dprintf(("","DOSFS: Service_EnumerateFormats: called\n") );

                /* set next to point to the next place to store a format_info pointer */
                next = (format_info **)&(rset->r[2]);
                while (*next != NULL)
                 next = &((*next)->link);

                /* see "format_info" structure in "MultiFS.h" */
                for (loop = 0; (DOS_formats[loop].magic_ID != 0x00); loop++)
                 if (DOS_formats[loop].idtext != NULL && DOS_formats[loop].in_menu) /* we support this format */
                  {
                   format_info *finfo = (format_info *)_kernel_RMAalloc(sizeof(format_info)) ;
                   char        *menu_text = 0;
                   char        *help_text = 0;
                   int         menusz;
                   int         helpsz;
                   _kernel_oserror *err;
                   char        token[8];

                   if (finfo == NULL)
                     continue;

                   /* get the text from the Messages file - to be safe do the copying here in case */
                   /* message trans uses the same buffer for both calls */
                   sprintf(token, FORMAT_FMT, loop + 1);
                   if ((err = msgtrans_lookup(token, &menu_text, &menusz, 0, 0, 0, 0)) != NULL) {
                     menu_text = err->errmess;
                     menusz = strlen(menu_text);
                   }
                   finfo->menu_text = _kernel_RMAalloc(menusz + 1) ;
                   if (finfo->menu_text != NULL) {
                     strncpy(finfo->menu_text, menu_text, menusz);
                     ((char *)(finfo->menu_text))[menusz] = '\0';
                     sprintf(token, HELP_FMT, loop + 1);
                     if ((err = msgtrans_lookup(token, &help_text, &helpsz, 0, 0, 0, 0)) != NULL) {
                       help_text = err->errmess;
                       helpsz = strlen(help_text);
                     }
                     finfo->help_text = _kernel_RMAalloc(helpsz + 1) ;
                     if (finfo->help_text != NULL) {
                       strncpy(finfo->help_text, help_text, helpsz);
                       ((char *)(finfo->help_text))[helpsz] = '\0';
                       finfo->link = NULL ; /* no next block at the moment */
                       finfo->format_SWI = DOSFS_DiscFormat ;
                       finfo->format_r0 = loop ;
                       finfo->layout_SWI = DOSFS_LayoutStructure ;
                       finfo->layout_r0 = loop ;
                       finfo->flags = EnumFormats_HasFormatParam;
                       finfo->format_desc = DOS_formats[loop].idtext;

                       /* add this description onto the end of the list */
                       *next = finfo;
                       next = &(finfo->link);
                     } else {
                       free(finfo->menu_text);
                       free(finfo);
                     }
                   } else {
                    free(finfo);
                   }
                  }
               }
               break ;

   case 0x6B : /* Service_IdentifyFormat */
               /* in:   r0 = ptr to NULL terminated ASCII format identifier
                *       r1 = Service_IdentifyFormat
                * out:  r0 = preserved
                *       r1 = Service_Serviced (NULL)
                *       r2 = SWI number to call to obtain "DOSFS_DiscFormat"
                *       r3 = r3 parameter to be used for "DOSFS_DiscFormat" SWI
                *       r4 = SWI number to call to obtain "DOSFS_LayoutStructure"
                *       r5 = r0 parameter to be used for "DOSFS_LayoutStructure" SWI
                */
               {
                int loop ;

                dprintf(("","DOSFS: Service_IdentifyFormat: r0 = \"%s\"\n",(char *)(rset->r[0]))) ;

                /* I use my wild-card compare function since it automatically deals with
                 * case equality, where "strcmp" does not.
                 */
                for (loop = 0; (DOS_formats[loop].magic_ID != 0x00); loop++)
                 if (DOS_formats[loop].idtext != NULL)
                  if (wild_card_compare((char *)rset->r[0],DOS_formats[loop].idtext,ROwcmult,ROwcsing))
                   break ;

                if (DOS_formats[loop].magic_ID != 0x00)
                 {
                  dprintf(("","DOSFS: Service_IdentifyFormat: %s\n",DOS_formats[loop].idtext)) ;

                  rset->r[1] = Service_Serviced ;
                  rset->r[2] = DOSFS_DiscFormat ;       /* our format SWI */
                  rset->r[3] = loop ;                   /* "DOS_formats" table index */
                  rset->r[4] = DOSFS_LayoutStructure ;  /* our layout SWI */
                  rset->r[5] = loop ;                   /* "DOS_formats" table index */
                 }
               }
               break ;

   case 0x6C : /* Service_DisplayFormatHelp */
               /* in:   r0 = &00
                *       r1 = Service_HelpFormat
                * out:  NO ERROR : preserved
                *       ERROR    : r0 = pointer to error block
                *                  r1 = Service_Serviced
                *
                * This should list the formats it will respond to in
                * "Service_IdentifyFormat". The listing should be performed
                * using "OS_WriteC", "OS_Write0" or "OS_WriteS".
                */
               dprintf(("","DOSFS: Service_FormatHelp: called\n") );
               {
                int            loop ;
                for (loop = 0; (DOS_formats[loop].magic_ID != 0x00); loop++)
                 if (DOS_formats[loop].idtext != NULL)
                  {
                   _kernel_swi_regs  urset ;
                   _kernel_oserror  *rerror ;
                   char        *buf = 0;
                   int         bufsz = 0;
                   char        token[8];

                   /* get the text from the Messages file */
                   sprintf(token, HELP_FMT, loop + 1);
                   if ((rerror = msgtrans_lookup(token, &buf, &bufsz, 0, 0, 0, 0)) != NULL) 
                    {
                     buf = rerror->errmess;
                     bufsz = strlen(rerror->errmess);
                    }
                   urset.r[0] = (word)buf;
                   urset.r[1] = bufsz;
                   rerror = _kernel_swi(OS_WriteN, &urset, &urset);

                   if (rerror == NULL)
                    rerror = _kernel_swi(OS_NewLine,&urset,&urset) ;

                   if (rerror != NULL)
                    {
                     rset->r[0] = (word)rerror ; /* pointer to standard error block */
                     rset->r[1] = Service_Serviced ;
                     return ;
                    }
                  }
               }
               break ;

   default   : /* unknown - do nothing */
               break ;
  }

 return ;
}

/*-------------------------------------------------------------------------*/

_kernel_oserror *fs_commands(const char *argv,int argc,int command,void *privateword)
{
 _kernel_swi_regs  rset ;
 _kernel_oserror  *rerror = NULL ;

 switch (command)
  {
   case CMD_DOSMap :
             {
              int         loop ;
              char        dosext[8] = {0,0,0,0,0,0,0,0} ; /* DOS extension */
              word        ROtype = 0x000 ;      /* RISC OS filetype */
              mapentry   *cptr ;
              const char *tptr ;
              char *buf = NULL;
              int bufsz = 0;

              dprintf(("","fs_command: DOSMap\n") );
              /* arg0 (optional) : DOS extension */
              /* arg1 (optional) : RISC OS filetype */
              /* If "arg0" is NOT present then we display the current mappings.
               * If "arg1" is NOT present the mapping for the given DOS
               * extension will be removed.
               */

              if (argc == 0) /* display current mappings if no parameters */
               {
                if ((cptr = maplist) == NULL)
                {
                 if ( (rerror = msgtrans_lookup("NOMAP", &buf, &bufsz, NULL, NULL, NULL, NULL)) != NULL )
                 {
                  buf = rerror->errmess;
                  bufsz = strlen( buf );
                 }
                 fwrite( buf, 1, bufsz, stdout );
                 putchar( '\n' );
                }
                else
                 {
                  int exttab, texttab, typetab, linelen;
                  buf = NULL;
                  if ( (rerror = msgtrans_lookup("DOSExt", &buf, &bufsz, NULL, NULL, NULL, NULL)) != NULL )
                  {
                   buf = rerror->errmess;
                   bufsz = strlen( buf );
                  }
                  fwrite( buf, 1, bufsz, stdout );
                  exttab = (bufsz-3)/2;
                  texttab = bufsz-exttab-1;
                  buf = NULL;
                  if ( (rerror = msgtrans_lookup("ROType", &buf, &bufsz, NULL, NULL, NULL, NULL)) != NULL )
                  {
                   buf = rerror->errmess;
                   bufsz = strlen( buf );
                  }
                  printf( "  " );
                  fwrite( buf, 1, bufsz, stdout );
                  putchar( '\n' );
                  if ( bufsz < 12 ) bufsz = 12;
                  typetab = bufsz-11;
                  linelen = exttab+3+texttab+bufsz;
                  for ( loop=linelen; loop--; ) putchar( '-' );
                  putchar('\n');

                  for (; (cptr != NULL); cptr = cptr->next)
                   {
                    for ( loop=exttab; loop--; ) putchar( ' ' );

                    for (loop = 0; (loop < 7); loop++)
                     {
                      char cchr = (*(char*)(cptr->dosext + (loop))) ;
                      putchar( (((cchr > ' ') && (cchr != 0x7F)) ? cchr : ' ') );
                     }

                    for ( loop=texttab; loop--; ) putchar( ' ' );

                    rset.r[0] = FSControl_ReadFileType ;
                    rset.r[2] = (word)cptr->ROtype ;
                    if ((rerror = _kernel_swi(OS_FSControl,&rset,&rset)) != NULL)
                     {
                      /* Just print spaces if unknown (or error returned) */
                      rset.r[2] = 0x20202020 ;
                      rset.r[3] = 0x20202020 ;
                     }

                    for (loop = 0; (loop < 4); loop++)
                     printf("%c",(char)((rset.r[2] >> (loop * 8)) & 0xFF)) ;
                    for (loop = 0; (loop < 4); loop++)
                     printf("%c",(char)((rset.r[3] >> (loop * 8)) & 0xFF)) ;

                    for ( loop=typetab; loop--; ) putchar( ' ' );
                    printf("%03X\n",cptr->ROtype) ;
                   }
                  for ( loop=linelen; loop--; ) putchar( '-' );
                  putchar( '\n' );
                 }
               }
              else
               {
                /* convert the DOS extension given to upper-case */
                for (loop=0; (argv[loop] && (argv[loop] != ' ')); loop++)
                 {
                  int c = toupper(argv[loop]);
                  if (validchar(valchars,c))
                   dosext[loop] = c  ;
                  else
                   {
                    rerror = global_error(err_invalidchar) ;
                    break ; /* from the "for" loop */
                   }
                 }

                if (!rerror) /* no error defined yet */
                 {
                  if (loop > 3)
                   rerror = global_error(err_toolong) ;
                  else
                   {
                    if (argc == 1)
                     {
                      mapentry *last = maplist ;
                      /* release this mapping */
                      for (cptr = last; (cptr != NULL); cptr = last->next)
                       if (strcmp(dosext, cptr->dosext)==0)
                        {
                         dprintf(("","DOSMap: entry found\n")) ;
                         /* release this mapping */
                         if (cptr == maplist)
                          maplist = cptr->next ;   /* new root mapping */
                         else
                          last->next = cptr->next ;/* step over this mapping */
                         free(cptr) ;              /* release this mapping */
                         break ;                   /* and exit the for loop */
                        }
                       else
                        last = cptr ;              /* remember this entry */
                     }
                    else
                     {
                      for (; (argv[loop] && (argv[loop] == ' ')); loop++) ;
                      /* convert the RISC OS filetype given to a 12bit number */
                      tptr = &argv[loop] ;
                      for (loop = 0; (tptr[loop]); loop++)
                       if (validchar("0123456789ABCDEFabcdef",tptr[loop]))
                        {
                         int cval ;
                         if (tptr[loop] > '9')
                          cval = (toupper(tptr[loop]) - ('A' - 10)) ;
                         else
                          cval = tptr[loop] ;
                         cval = cval - '0' ;
                         ROtype = (ROtype | (cval << (loop * 8))) ;
                        }
                       else
                        {
                         loop = 0 ;
                         break ;
                        }

                      if (loop == 0)
                       {
                        rset.r[0] = FSControl_FileTypeFromString ;
                        rset.r[1] = (word)tptr ;
                        if ((rerror = _kernel_swi(OS_FSControl,&rset,&rset)) == NULL)
                         ROtype = rset.r[2] ;
                       }
                      if (rerror == NULL)
                       {
                        /* check if the DOS extension exists */
                        for (cptr = maplist; (cptr != NULL); cptr = cptr->next)
                         if (strcmp(dosext, cptr->dosext)==0)
                          {
                           dprintf(("","DOSMap: resetting %s to &%03X\n",dosext,ROtype));
                           cptr->ROtype = ROtype ;   /* replace mapping */
                           break ;                   /* and exit the for loop */
                          }

                        if (cptr == NULL)
                         {
                          mapentry *newmapping ;
                          if ((newmapping = (mapentry *)calloc(sizeof(mapentry),1)) == NULL)
                           rerror = global_errorT(err_heapexhausted, tok_heapexhausted, 0, 0) ;
                          else
                           {
                            /* insert the mapping into the list */
                            dprintf(("","DOSMap: newmapping %s to &%03X\n",dosext,ROtype) );
                            newmapping->next = maplist ;
                            strcpy(newmapping->dosext, dosext) ;
                            newmapping->ROtype = ROtype ;
                            maplist = newmapping ;
                           }
                         }
                       }
                     }
                   }
                 }
               }
             }
             break ;

   case CMD_CopyBoot :
             {
              int             loop ;
              char           *cptr ; /* used during arg processing */
              int             srcdrive = -1 ;
              int             destdrive = -1 ;
              DOS_bootsector *srcblock = NULL ;
              DOS_bootsector *destblock = NULL ;
              int             nfloppies = 0 ;
              char            tmpcmd[256] ;     /* simple hack-around original code which modified command line */

              dprintf(("","fs_command: CopyBoot\n")) ;

              rerror = _kernel_swi(ADFS_Drives,&rset,&rset) ;
              if (rerror == NULL)
               {
                nfloppies = rset.r[1] ;

                /* arg0 : source drive */
                /* arg1 : destination drive */

                /* step upto first */
                for (; (*argv && (*argv == ' ')); argv++) ;
                strncpy(tmpcmd, argv, 255); tmpcmd[255] = '\0';
                cptr = strtok(tmpcmd," \t") ; /* first argument */
                if (cptr != NULL)
                 srcdrive = atoi(cptr) ;
                cptr = strtok(NULL," \t") ; /* second argument */
                if (cptr != NULL)
                 destdrive = atoi(cptr) ;

                if (((srcdrive < 0) || (srcdrive >= nfloppies)) || ((destdrive < 0) || (destdrive >= nfloppies)))
                 {
                  /* Bad drive specifier given (not a valid floppy drive) */
                  rerror = global_error(err_baddrive) ;
                 }
                else
                 {
                  dprintf(("","CopyBoot: src %d dest %d\n",srcdrive,destdrive)) ;

                  srcblock = (DOS_bootsector *)malloc(sizeof(DOS_bootsector)) ;
                  destblock = (DOS_bootsector *)malloc(sizeof(DOS_bootsector)) ;
                  if ((srcblock == NULL) || (destblock == NULL))
                   {
                    if (srcblock != NULL)
                     free(srcblock) ;
                    rerror = global_errorT(err_heapexhausted, tok_heapexhausted, 0, 0) ;
                   }
                  else
                   {
                    char                 tmpstr[8];
                    int                  fhand = 0 ; /* open file handle */

                    /* Load the BOOT BLOCK from the source drive */
                    sprintf(tmpstr,"adfs::%d",srcdrive) ;
                    rset.r[0] = open_read | open_default;
                    rset.r[1] = (int)tmpstr;
                    rerror = _kernel_swi(OS_Find, &rset, &rset);
                    fhand = rset.r[0];
                    if (rerror != NULL || fhand == 0)
                     {
                      dprintf(("","CMD_CopyBoot: failed to open source image\n") );
                      rerror = global_errorT(err_objectnotfound,tok_objectnotfound,tmpstr,0) ;
                     }
                    else
                     {
                      /* read the BOOT BLOCK from the image */
                      rset.r[0] = OSGBPB_ReadFromGiven;
                      rset.r[1] = fhand;
                      rset.r[2] = (int)srcblock;
                      rset.r[3] = sizeof(DOS_bootsector);
                      rset.r[4] = 0x00000000;
                      rerror = _kernel_swi(OS_GBPB, &rset, &rset);
                      if (rerror != NULL || rset.r[3] != 0)
                        rerror = global_error(err_readfailed) ;

                      /* close the image file */
                      rset.r[0] = 0;
                      rset.r[1] = fhand;
                      _kernel_swi(OS_Find, &rset, &rset);
                      if (rerror == NULL)
                       {
                        dprintf(("","CMD_CopyBoot: source secsize = %d\n", READ_LOHI(srcblock->BOOT_secsize)));
                        dprintf(("","CMD_CopyBoot: source secalloc = %d\n", srcblock->BOOT_secalloc));
                        dprintf(("","CMD_CopyBoot: source reserved = %d\n", READ_LOHI(srcblock->BOOT_reserved)));
                        dprintf(("","CMD_CopyBoot: source num_fats = %d\n", srcblock->BOOT_num_fats));
                        dprintf(("","CMD_CopyBoot: source root size = %d\n", READ_LOHI(srcblock->BOOT_root_dir)));
                        dprintf(("","CMD_CopyBoot: source max_sect = %d\n", READ_LOHI(srcblock->BOOT_max_sect)));
                        dprintf(("","CMD_CopyBoot: source magic = &%02X\n", srcblock->BOOT_magic));
                        dprintf(("","CMD_CopyBoot: source FAT_size = %d\n", READ_LOHI(srcblock->BOOT_FAT_size)));
                        dprintf(("","CMD_CopyBoot: source secstrack = %d\n", READ_LOHI(srcblock->BOOT_secstrack)));
                        dprintf(("","CMD_CopyBoot: source heads = %d\n", READ_LOHI(srcblock->BOOT_heads)));
                        dprintf(("","CMD_CopyBoot: source hidden = %d\n", READ_0123(srcblock->hidden)));

                        if (rerror == NULL)
                         {
                          /* If the source drive and destination drive are the
                           * same then prompt for the disc to be changed.
                           */
                          if (srcdrive == destdrive)
                           {
                            char *buf = NULL;
                            int bufsz;
                            if ( (rerror = msgtrans_lookup("Prompt1", &buf, &bufsz, NULL, NULL, NULL, NULL)) != NULL )
                            {
                             buf = rerror->errmess;
                             bufsz = strlen( buf );
                            }
                            fwrite( buf, 1, bufsz, stdout );
                            /* We need to take account of ESCAPE here */
                            rset.r[0] = OsByte_ScanKeyboardFrom16;
                            do
                            {
                              rerror = _kernel_swi(OS_Byte,&rset,&rset) ;
                            } while ((rerror == NULL) && (rset.r[1] != KeyScan_Space) && (rset.r[1] != KeyScan_Escape)) ;
                            putchar( '\n' );
                            if (rerror != NULL)
                             rerror = global_error(err_keyboardread);
                            else if (rset.r[1] == KeyScan_Escape) {
                             dprintf(("","CMD_CopyBoot: Escape\n")) ;
                             _gerror.errnum = 17 ; /* NASTY CONSTANT */
                             buf = _gerror.errmess;
                             bufsz = 252;
                             if ( (rerror = msgtrans_lookup("Escape", &buf, &bufsz, NULL, NULL, NULL, NULL)) != NULL )
                             {
                              _gerror.errnum = rerror->errnum;
                              strcpy( _gerror.errmess, rerror->errmess );
                             }
                            }
                           }

                          if (rerror == NULL)
                           {
                            /* Load the BOOT BLOCK from the destination drive */
                            sprintf(tmpstr,"adfs::%d",destdrive) ;
                            rset.r[0] = open_write | open_read | open_default;
                            rset.r[1] = (int)tmpstr;
                            rerror = _kernel_swi(OS_Find, &rset, &rset);
                            fhand = rset.r[0];
                            if (rerror != NULL || fhand == 0)
                             {
                              dprintf(("","CMD_CopyBoot: failed to open dest image\n")) ;
                              rerror = global_errorT(err_objectnotfound,tok_objectnotfound,tmpstr,0) ;
                             }
                            else
                             {
                              /* read the BOOT BLOCK from the image */
                              rset.r[0] = OSGBPB_ReadFromGiven;
                              rset.r[1] = fhand;
                              rset.r[2] = (int)destblock;
                              rset.r[3] = sizeof(DOS_bootsector);
                              rset.r[4] = 0x00000000;
                              rerror = _kernel_swi(OS_GBPB, &rset, &rset);
                              if (rerror != NULL || rset.r[3] != 0)
                                rerror = global_error(err_readfailed) ;
                              else
                               {
                                if (rerror == NULL)
                                 {
                                  /* Copy the 3byte JMP, OEM information and
                                   * boot code from the source to the destination buffer,
                                   * zero the hidden sectors and 32b sector count (it's
                                   * a floppy!), and ensure a boot signature is present.
                                   */
                                  for (loop = 0; (loop < 3); loop++)
                                   destblock->BOOT_JMP[loop] = srcblock->BOOT_JMP[loop] ;

                                  for (loop = 0; (loop < 8); loop++)
                                   destblock->BOOT_OEM[loop] = srcblock->BOOT_OEM[loop] ;

                                  memcpy(&destblock->BOOT_extra.fat12,
                                         &srcblock->BOOT_extra.fat12,
                                         sizeof(srcblock->BOOT_extra.fat12)) ;

                                  destblock->hidden0 = destblock->hidden1 =
                                  destblock->hidden2 = destblock->hidden3 = 0; /* Floppy */
                                  destblock->big_sect0 = destblock->big_sect1 =
                                  destblock->big_sect2 = destblock->big_sect3 = 0; /* Floppy */

                                  destblock->BOOT_extra.fat12.BOOT_signature = 0x55 ;
                                  destblock->BOOT_extra.fat12.BOOT_signatureHI = 0xAA ;

                                  /* Save the BOOT BLOCK back to the destination drive */
                                  rset.r[0] = OSGBPB_WriteAtGiven;
                                  rset.r[1] = fhand;
                                  rset.r[2] = (int)destblock;
                                  rset.r[3] = sizeof(DOS_bootsector);
                                  rset.r[4] = 0x00000000;
                                  if (_kernel_swi(OS_GBPB, &rset, &rset) != NULL)
                                    rerror = global_error(err_writefailed) ;
                                 }
                               }
                              /* close the image file */
                              rset.r[0] = 0;
                              rset.r[1] = fhand;
                              _kernel_swi(OS_Find, &rset, &rset);
                             }
                           }
                         }
                       }
                     }
                    free(srcblock) ;
                    free(destblock) ;
                   }
                 }
               }
             }
             break ;

   default : /* unknown */
             break ;
  }

 return(rerror) ;
 UNUSED(argv) ;
 UNUSED(argc) ;
 UNUSED(privateword) ;
}

/*-------------------------------------------------------------------------*/

_kernel_oserror *shutdown_fs(int fatal, int podule, void *pw)
{
 _kernel_swi_regs rset ;
 mapentry *cptr ;

 dprintf(("","DOSFS: shutdown_fs called\n")) ;

 /* JRS 26/3/92: free all DOS name mappings */
 while (maplist != NULL)
 {
   cptr = maplist;
   maplist = maplist->next;
   free(cptr) ;
 }

 /* Deregister our image type (ignoring errors) */
 rset.r[0] = FSControl_DeRegisterImageFS;
 rset.r[1] = FileType_MSDOSDisc ;  /* image type we provide support for */
 (void)_kernel_swi(OS_FSControl,&rset,&rset) ;

 /* Close messages file, remove from ResourceFS if RAM loaded */
 msgtrans_closefile();
#ifndef ROM
 _swix(ResourceFS_DeregisterFiles, _IN(0), dosfs_msgarea());
#endif

 UNUSED(fatal);
 UNUSED(podule);
 UNUSED(pw);
 return NULL;
}

/*-------------------------------------------------------------------------*/

_kernel_oserror *init_fs(const char *cmd_tail,int podule_base,void *privateword)
{
 _kernel_oserror  *syserr ;
 _kernel_swi_regs r;

  /* set up debugging */
  debug_initialise ("DOSFS", "", 0);
//  debug_set_device(DEBUGIT_OUTPUT);
//  debug_set_device(HAL_OUTPUT);
  debug_set_device(PRINTF_OUTPUT);
  debug_set_unbuffered_files (TRUE);
  debug_set_stamp_debug (TRUE);

 dprintf(("","DOSFS: init_fs: entered\n"));
 _syserr = &_gerror ;              /* reference the static global error area */

#ifndef ROM
 /* Register the messages for RAM based modules */
 r.r[0] = (int)dosfs_msgarea();
 syserr = _kernel_swi(ResourceFS_RegisterFiles, &r, &r);
 if (syserr != NULL) return syserr;
 dprintf(("","DOSFS: messages registered\n"));
#endif

 if ((syserr = declare_FS(privateword)) != NULL)
  dprintf(("","DOSFS: init_fs: &%08X \"%s\"\n",syserr->errnum,syserr->errmess)) ;

 r.r[0] = (int)"File$Type_FC8";
 r.r[1] = (int)"DOSDisc";
 r.r[2] = 7;
 r.r[3] = 0;
 r.r[4] = VarType_String;
 /* Ignore error here, if setting the variable fails then "fc8" will be used. */
 (void)_kernel_swi(OS_SetVarVal, &r, &r);

 r.r[0] = (int)"File$Type_FE4";
 r.r[1] = (int)"DOS";
 r.r[2] = 3;
 r.r[3] = 0;
 r.r[4] = VarType_String;
 /* Ignore error here, if setting the variable fails then "fc4" will be used. */
 (void)_kernel_swi(OS_SetVarVal, &r, &r);

 r.r[1] = (int)"FileCore_DiscOp64";
 if (_kernel_swi(OS_SWINumberFromString, &r, &r)==NULL) discopswi = r.r[0];
 
 dprintf(("","DOSFS: init_fs: exiting\n") );
 return(0) ;
 UNUSED(podule_base) ;
 UNUSED(cmd_tail) ;
}

/*-------------------------------------------------------------------------*/
/*> EOF c.DOSFS <*/
