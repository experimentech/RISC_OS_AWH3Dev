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
/*> c.OpsFunc <*/
/*-------------------------------------------------------------------------*/
/* DOSFS image FS 'Func'                        Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include "kernel.h"
#include "swis.h"
#include "Interface/HighFSI.h"
#include "Interface/FileCore.h"
#include "DebugLib/DebugLib.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "Helpers.h"
#include "Ops.h"
#include "MsgTrans.h"
#include "DOSclusters.h"
#include "DOSnaming.h"
#include "DOSshape.h"
#include "DOSdirs.h"
#include "Accessors.h"

/*!
 * \param  oldname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  newname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ihand Image handle
 * \return -1 if rename failed
 */
int DOSFS_rename(char *oldname,char *newname,DOSdisc *ihand)
{
  DIR_info     *cdir ;         /* directory where the original leafname resides */
  DIR_info     *ndir ;         /* directory where the new leafname resides */
  char         *DOSname ;      /* full DOS pathname */
  char         *leafname ;     /* pointer to the leafname of "DOSname" */
  DOS_direntry *dentry ;       /* directory entry structure pointer */
  DOS_direntry *found ;        /* directory entry structure pointer */
  int           loop ;         /* general index counter */
  int           not_sfn;       /* flag not a valid short name */
  uintptr_t     cdirp;                      /* address of the original dir entries */
  int           numreq, diroffset;          /* number of dir entries needed for the long filename */
  DOS_direntry *lfn[(MaxString + 12) / 13]; /* enough dir entries for the longest long filename */
  char         *longfileholder;             /* for long name */
  char          shortname[14];              /* for short name equivalent */
  DIR_info     *dummy;                      /* parent pointer (not used) */
 
  dprintf(("","\n\nDOSFS_rename: \"%s\" --> \"%s\"\n",oldname,newname));
 
  /* convert "oldname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(int, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  if ((int)convertRISCOStoLFN(oldname, DOSname) < 0)
  {
    free(DOSname);
    return -1;
  }
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname,&cdir,&leafname,ihand) < 0)
  {
    free(DOSname) ;
    return (-1) ; /* error already defined */
  }
 
  dprintf(("","DOSFS_rename: original leafname = \"%s\"\n",leafname));

  /* search the directory for the original entry */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname,cdir,cdir->dir_size,&loop)) == NULL)
  {
    free(DOSname) ;
    return_errorT(int, err_objectnotfound, tok_objectnotfound, oldname, 0) ;
  }
  found = dentry ; /* pointer to "oldname" in directory */
 
  /* check that no wildcard characters exist in the original leafname */
  if (checknotwildcarded(leafname, DOSwcmult, DOSwcsing) != 0)
  {
    free(DOSname) ;
    return_error1(int, err_wildcardedname, oldname) ;
  }
 
  /* If the object to be renamed is a directory then we must ensure that there is
   * no copy of it in the cache so that DOSFS doesn't think that it still exists.
   */
  if (found->FILE_attribute & FILE_subdir)
  {
    /* Reconstruct the full pathname of the directory being renamed. */
    dprintf(("","DOSFS_rename: removing \"%s\" from the directory cache\n",leafname));
    free_dir_cache(restorePATH(DOSname,leafname), ihand);
  }
  else
  {
    /* Its a file, so check if it's open. */
    if (find_open_file(oldname, found, ihand) >= 0)
    {
      free(DOSname);
      return_error1(int, err_fileopen, oldname);
    }
  }
 
  if ((int)convertRISCOStoLFN(newname, DOSname) < 0)
  {
    free(DOSname);
    return -1;
  }
 
  set_dir_flags(cdir, dir_LOCKED);
 
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname,&ndir,&leafname,ihand) < 0)
  {
    unset_dir_flags(cdir, dir_LOCKED);
    free(DOSname) ;
    return (-1) ; /* error already defined */
  }
  unset_dir_flags(cdir, dir_LOCKED);
 
  dprintf(("","DOSFS_rename: new leafname = \"%s\"\n",leafname));
  if (checknotwildcarded(leafname, DOSwcmult, DOSwcsing) != 0)
  {
    free(DOSname) ;
    return_error1(int, err_wildcardedname, newname) ;
  }
 
  /* check to see if we already have a file with the destination name */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname,ndir,ndir->dir_size,&loop)) != NULL)
  {
    /* new name already exists in the destination directory */
    free(DOSname) ;
    return_error0(int, err_alreadyexists) ;
  }
 
  /* Obtain the correct amount of empty directory entries */
  numreq = (strlen(leafname) / 13) + 2;
  dprintf(("","DOSFS_rename: numreq = %d\n",numreq));
 
  if (get_dir_entry_array(lfn, ihand, numreq, &ndir, &dummy, &found) < 0)
  {
    free(DOSname) ;
    return -1;
  }
 
  /* Create 8.3 filename from leafname */
  not_sfn = shorten_lfn(leafname, shortname, ndir);
  dentry = not_sfn ? lfn[numreq-1] : lfn[0];
  
  dprintf(("","DOSFS_rename: long filename = '%s'\n",leafname));
  dprintf(("","DOSFS_rename: short filename = '%s'",shortname));
  dprintf(("","DOSFS_rename: into dentry = %p\n",dentry));
 
  if (not_sfn) MakeLFNEntries(lfn,numreq,leafname,shortname);
  sprintf((char *)&dentry->FILE_status, "%-8.8s%-3s", shortname, &shortname[8]);

  /* copy spare bytes (either JGS info or DRDOS5.0 info) */
  for (loop = 0; (loop < spare1); loop++)
  {
    dentry->FILE_reserved[loop] = found->FILE_reserved[loop] ;
  }
  /* copy file description */
  dentry->FILE_attribute =  found->FILE_attribute;
  dentry->FILE_time = found->FILE_time ;
  dentry->FILE_timeHI = found->FILE_timeHI ;
  dentry->FILE_date = found->FILE_date ;
  dentry->FILE_dateHI = found->FILE_dateHI ;
  dentry->FILE_cluster = found->FILE_cluster ;
  dentry->FILE_clusterHI = found->FILE_clusterHI ;
  dentry->FILE_size = found->FILE_size ;
  set_dir_flags(ndir, dir_MODIFIED) ; /* new directory updated */
 
  longfileholder = malloc(strlen(leafname) + 1);
  if (longfileholder == NULL)
  {
    free(DOSname) ;
    return_errorT(int, err_heapexhausted, tok_heapexhausted, 0, 0);
  }
  strcpy(longfileholder, leafname);
  diroffset = ((int)((int)(dentry) - (DI_Base(ndir))) / sizeof(DOS_direntry));
  (ndir)->lfnp[diroffset] = longfileholder;
 
  dprintf(("","DOSFS_rename: index = %d, pointer = %p, actual = %p\n",diroffset,cdir->lfnp[diroffset], longfileholder));
 
  cdirp = (uintptr_t)DI_Base(cdir);
  dprintf(("","DOSFS_rename: cdirp = %x, found = %x\n",cdirp,(int)found));
  /* ditch original lfnp if there */
  loop = ((int)((int)(found)-(DI_Base(cdir))) / sizeof(DOS_direntry));
  if (cdir->lfnp[loop])
  { 
    free(cdir->lfnp[loop]);
    cdir->lfnp[loop] = NULL;
  }
  
  found->FILE_status = FILE_deleted;
  found--;
  while (((uintptr_t)found >= cdirp) && (found->FILE_attribute == FILE_win95))
  {
    dprintf(("","DOSFS_rename: cdirp = %x, nfound = %x\n",(int)cdirp,(int)found));
    found->FILE_status = FILE_deleted;
    found--;
  }
 
  set_dir_flags(cdir, dir_MODIFIED) ; /* directory updated */
  free(DOSname) ;
 
  if ((ensure_directory(cdir) != 0) || (ensure_directory(ndir) != 0))
  {
    flush_dir_cache(ihand);
    return(-1) ; /* error already defined */
  }
 
  return (0) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  dest Memory address for result
 * \param  num Number of entries requested
 * \param  off Offset into directory to continue from
 * \param  blen Size of buffer at 'dest'
 * \param  ihand Image handle
 * \return -1 if read failed
 */
FS_dir_block *DOSFS_read_dir(char *fname, void *dest, word num, word off, word blen, DOSdisc *ihand)
{
  dprintf(("","\n\nDOSFS_read_dir: \"%s\" (dest = &%08X) %d %d %d\n",((fname == "") ? "NULLptr" : fname),dest,num,off,blen));

  return (read_dir(0, fname, dest, num, off, blen, ihand)) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  dest Memory address for result
 * \param  num Number of entries requested
 * \param  off Offset into directory to continue from
 * \param  blen Size of buffer at 'dest'
 * \param  ihand Image handle
 * \return -1 if read failed
 */
FS_dir_block *DOSFS_read_dir_info(char *fname, void *dest, word num, word off, word blen, DOSdisc *ihand)
{
  dprintf(("","\n\nDOSFS_read_dir_info: \"%s\" (dest = &%08X) %d %d %d\n",((fname == "") ? "NULLptr" : fname),dest,num,off,blen));

  return (read_dir(-1, fname, dest, num, off, blen, ihand)) ;
}

/*!
 * \param  fshand FileSwitch image handle
 * \param  buffsize Buffer size hint, or 0 if not known
 * \return Image FS handle
 */
DOSdisc *DOSFS_image_open(word fshand, word buffsize)
{
  DOS_bootsector   *dboot = NULL ;   /* cached disc boot block */
  byte             *pentry ;         /* wini partition description pointer */
  uint64_t          winioffset = 0 ; /* partition start within wini images */
  DOSdisc          *ddisc = NULL ;   /* cached disc description */
  byte              numFATs ;        /* number of FATs in the image */
  word              FATsize ;        /* size of FAT in bytes */
  word              FATentries ;     /* number of entries in FAT */
  word              numRESVD ;       /* number of reserved (unused) sectors */
  word              ROOTsize ;       /* size of ROOT directory in sectors */
  int               loop ;           /* general counter */
  uint64_t          discaddress = 0x00000000 ;
  int               totsec = 0, datasec = 0;  /* Split of sectors */
  int               CountOfClusters = 0;      /* Expressed as clusters */
  int               RootDirSectors;
  _kernel_oserror  *rerror ;                  /* for standard RISC OS error structures */
#ifdef NO_FAT32
  static const _kernel_oserror noFAT32support = { 0, "FAT32 support absent"};
#endif
  image_accessor_file a = new_image_accessor_file(fshand);
  word partsize = a.size/DOSsecsize; /* partition size (sectors) */
 
  dprintf(("","\n\nDOSFS_image_open: fshand = &%08X, buffsize = &%08X\n",fshand,buffsize));
  /* We can assume that FileSwitch has only called us with files of the correct
   * type (ie. we need perform no 12bit filetype identification on the passed
   * FileSwitch handle).
   */
 
  /* Construct an internal file handle structure that contains the FileSwitch
   * handle, plus any other useful information. We will return the pointer to
   * this structure as the image handle.
   *
   * We need to distinguish between DOS and Atari floppies and DOS winchesters
   * (Winchesters use the "disc_winioffset" word, for floppies this needs to
   * be initialised to 0x00000000).
   */
 
  /* CACHE the "disc" information */
  if ((dboot = (DOS_bootsector *)malloc(sizeof(DOS_bootsector))) == NULL)
  {
    dprintf(("","DOSFS_image_open: unable to allocate memory for BOOT sector\n"));
    return_errorT(DOSdisc *, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
 
  dprintf(("","DOSFS_image_open: dboot = &%08X\n",(int)dboot));
 
  /* At the moment there is no simple way of differentaiting between winchester
   * partitions and those of floppy images. MS-DOS manages by the explicit
   * drive hardware differences. We are accessing the disc images via the same
   * file interface.
   * The following code performs a few simple checks to differentiate between
   * the image types.
   */
 
  /* read the BOOT BLOCK from the image */
  /* This code RELIES on (DOS_BOOT_sector == DOS_PARTITION_sector) */
  discaddress = (DOS_BOOT_sector - 1) * DOSsecsize ;
  if ((rerror = image_readwrite(discaddress, /* offset within FileSwitch file */
                                DOSsecsize, /* fixed in MS-DOS */
                                dboot, /* destination address */
                                ACC_READ, /* read operation */
                                &a.a)) != NULL)
  {
    free(dboot) ;
    return_errorX(DOSdisc *, rerror) ;    /* error already defined */
  }
 
  /* If this doesn't look like a BOOT block then try a partition. */
#ifdef NONFLOPPIES
  if (sector_size(dboot) != DOSsecsize)
#else
  if (sector_size(dboot) != DOSsecsize || dboot->BOOT_num_fats != 2)
#endif
  {
    DOS_partition    *DOSpart = NULL ; /* winchester partition information */
    dprintf(("","DOSFS_image_open: not a BOOT block, could be a partition.\n"));
    DOSpart = (DOS_partition *)dboot ;
  
    /* Look for the partition with the "boot_ind" set to "bootable" */
    pentry = (byte *)&(DOSpart->p0_boot_ind) ;
    for (loop=0; (loop < 4); loop++)
    {
      if (pentry[0] == bootable) break ;
      pentry += sizeof(partition_entry) ;
    }
    dprintf(("","DOSFS_image_open: partition %d may be bootable.\n",loop));
  
    if (loop == 4)
    {
      /* No bootable partition found - try to validify one of the partitions as
       * non-bootable, otherwise this can't be a valid DOS partition.
       */
      dprintf(("","DOSFS_image_open: not a bootable partition.\n"));
      pentry = (byte *)&(DOSpart->p0_boot_ind);
      for (loop = 0; loop < 4; loop++)
      {
#ifdef OLD_PARTITION_TEST
        if (pentry[4] == partition_DOS || pentry[4] == partition_DR || pentry[4] == partition_NCR)
#else
        if (pentry[2] != 0) /* If start sector != 0 then we have found a possible partition table entry. */
#endif
        {
          break;
        }
        pentry += sizeof(partition_entry);
      }
    }
 
    if (loop != 4)
    {
      dprintf(("","DOSFS_image_open: partition type %d\n",pentry[4]));
   
      /* The following sector number, should be equivalent to that used to
       * construct the "disc_winioffset" variable.
       * DOS BOOT sector = WiniSector(pentry[3],pentry[1],pentry[2])
       */
      winioffset = ((uint64_t)loadWORD(pentry+8) * DOSsecsize);
      dprintf(("","DOSFS_image_open: winioffset = &%016" PRIX64 "\n",winioffset));
   
      /* Our system can now cope with winchester partitions with more than 0xFFFF
       * sectors
       */
      partsize = loadWORD(pentry+12);
   
      discaddress = ((DOS_BOOT_sector - 1) * DOSsecsize) + winioffset ;
      if ((rerror = image_readwrite(discaddress,
                                    DOSsecsize,
                                    dboot,
                                    ACC_READ,
                                    &a.a)) != NULL)
      {
        free(dboot) ;
        return_errorX(DOSdisc *, rerror) ;
      }
   
      /* I am not sure if all MS-DOS BOOT BLOCKs contain a similar signature to
       * that provided in winchester PARTITION BLOCKs. MS-DOS 3.31 seems to do
       * so, and this may form another validation check on the destination BOOT
       * BLOCK. **** research into this ****
       */
   
#ifdef NONFLOPPIES
      if (sector_size(dboot) != DOSsecsize)
#else
      if ((sector_size(dboot) != DOSsecsize) || (dboot->BOOT_num_fats != 2) || (max_sector(dboot) != partsize))
#endif
      {
        dprintf(("","DOSFS_image_open: invalid partition BOOT block\n"));
        free(dboot) ;
        return_error0(DOSdisc *,err_notDOSimage) ;
      }
    }
    else
    {
      dprintf(("","DOSFS_image_open: image is not a DOS partition (could be 320K or 160K format)\n"));
      /* Could still be a DOS 320K or 160K format as they do not need a valid boot block,
       * fake the info in the boot block (if it's not one of these then catch it later). */
      dboot->BOOT_secsize = 0x00;
      dboot->BOOT_secsizeHI = 0x02;
      dboot->BOOT_reserved = 0x01;
      dboot->BOOT_reservedHI = 0x00;
      dboot->BOOT_num_fats = 0x02;
      dboot->BOOT_magic = 0x00;
      dboot->BOOT_FAT_size = 0x01;
      dboot->BOOT_FAT_sizeHI = 0x00;
      dboot->BOOT_secstrack = 0x08;
      dboot->BOOT_secstrackHI = 0x00;
      dboot->hidden0 = 0x00;
      dboot->hidden1 = 0x00;
      partsize = a.size/DOSsecsize;
    }
  }
 
  /* number of File Allocation Tables */
  numFATs = dboot->BOOT_num_fats ;

  /* number of reserved (unusable) sectors */
  numRESVD = READ_LOHI(dboot->BOOT_reserved);
 
  dprintf(("","DOSFS_image_open: DOSsecsize = %x\n",DOSsecsize));
  dprintf(("","DOSFS_image_open: numFATs    = %d\n",numFATs));
  dprintf(("","DOSFS_image_open: numRESVD   = %d\n",numRESVD));
 
  dprintf(("","DOSFS_image_open: sectors per cluster = %x\n",dboot->BOOT_secalloc));
  dprintf(("","DOSFS_image_open: sector size = %d\n",READ_LOHI(dboot->BOOT_secsize)));
  dprintf(("","DOSFS_image_open: cluster size = %d\n",dboot->BOOT_secalloc * READ_LOHI(dboot->BOOT_secsize)));
 
  RootDirSectors = READ_LOHI(dboot->BOOT_root_dir) * sizeof(DOS_direntry); /* Bytes */
  RootDirSectors = (RootDirSectors + (DOSsecsize - 1)) / DOSsecsize; /* Sectors */
  dprintf(("","DOSFS_image_open: RootDirSectors = %d\n",RootDirSectors));

  if (READ_LOHI(dboot->BOOT_FAT_size) != 0)
  {
    FATsize = READ_LOHI(dboot->BOOT_FAT_size);
  }
  else
  {
    /* It's FAT32 */
    FATsize = READ_0123(dboot->BOOT_extra.fat32.FAT_sz);
  }
  if( READ_LOHI(dboot->BOOT_max_sect) != 0)
  {
    /* Limited 16 bit size */
    totsec = READ_LOHI(dboot->BOOT_max_sect);
  }
  else
  {
    totsec = READ_0123(dboot->big_sect);
  }
  datasec = totsec - (READ_LOHI(dboot->BOOT_reserved) + (numFATs * FATsize) + RootDirSectors);
  dprintf(("","DOSFS_image_open: FATsize = %x\n",FATsize));
  dprintf(("","DOSFS_image_open: totsec = %x\n",totsec));
  /* In the case where it's a 320K/160K floppy, we won't know secalloc until we
   * deduce it from the FAT, which we don't read until later. However,
   * CountOfClusters is only used for distinguishing FAT12/Fat16/FAT32, and for
   * these purposes, assuming 1 sector per cluster will be fine */
  CountOfClusters = dboot->BOOT_secalloc > 0 ? datasec / dboot->BOOT_secalloc : datasec;
  dprintf(("","DOSFS_image_open: CountOfClusters = %x\n",CountOfClusters));

  /* Sanity check some values */
  if (winioffset + (((uint64_t) totsec) * DOSsecsize) > a.size)
  {
    dprintf(("","DOSFS_image_open: filesystem exceeds extent of image file\n"));
    free(dboot);
    return_error0(DOSdisc *, err_notDOSimage);
  }
  if (totsec > partsize)
  {
    dprintf(("","DOSFS_image_open: filesystem larger than partition\n"));
    free(dboot);
    return_error0(DOSdisc *, err_notDOSimage);
  }
  if ((FATsize > ((1<<30) / DOSsecsize)) /* Arbitrary 1GB max FAT size (to avoid overflow in malloc calculation below) */
   || (winioffset > UINT32_MAX)) /* We use 32bit winioffset */
  {
    dprintf(("","DOSFS_image_open: disc too big\n"));
    free(dboot) ;
    return_error0(DOSdisc *, err_disctoobig) ;
  }
 
  /* allocate a DOS disc description structure large enough to hold a FAT
   * copy. Note: the disc description structure already includes a single "FAT"
   * sector.
   */
  if ((ddisc = (DOSdisc *)malloc(sizeof(DOSdisc) + ((FATsize*DOSsecsize) - sizeof(fFAT_sector)))) == NULL)
  {
    dprintf(("","DOSFS_image_open: unable to allocate memory for disc description\n"));
    free(dboot) ;
    return_errorT(DOSdisc *, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  dprintf(("","DOSFS_image_open: ddisc = &%08X\n",(int)ddisc));
  
  if(RootDirSectors != 0)
  {
    if (CountOfClusters < 4085)
    {
      dprintf(("","DOSFS_image_open: Volume is FAT12\n"));
      ddisc->disc_FATentry = 12;
    }
    else
    {
      if (CountOfClusters < 65525)
      {
        dprintf(("","DOSFS_image_open: Volume is FAT16\n"));
        ddisc->disc_FATentry = 16;
      }
      else
      {
        dprintf(("","DOSFS_image_open: Volume is FAT32\n"));
        ddisc->disc_FATentry = 32;
#ifdef NO_FAT32
        free(dboot);
        free(ddisc);
        return_errorX(DOSdisc *, &noFAT32support);    /* error for diagnostics */
#endif
      }
    }
  }
  else
  {
    dprintf(("","DOSFS_image_open: Volume is FAT32\n"));
    ddisc->disc_FATentry = 32;
#ifdef NO_FAT32
    free(dboot);
    free(ddisc);
    return_errorX(DOSdisc *, &noFAT32support);    /* error for diagnostics */
#endif
  }

  if (ddisc->disc_FATentry == 32)
  {
    ddisc->disc_RootCluster = READ_0123(dboot->BOOT_extra.fat32.RootClus);
  }
  else
  {
    ddisc->disc_RootCluster  = 0;
  }
  dprintf(("","DOSFS_image_open: No. of root entries = %x F32 cl:%x\n",
              READ_LOHI(dboot->BOOT_root_dir),ddisc->disc_RootCluster));
 
  /* remember the FileSwitch handle */
  ddisc->disc_fhand = fshand ;           /* FileSwitch handle of image file */
  ddisc->disc_winioffset = (word) winioffset ;  /* offset into image */
 
  ddisc->disc_FATsecs = FATsize ;            /* remember how many sectors the FAT is */
  ddisc->disc_FATsize = FATsize * DOSsecsize;/* remember how big the FAT is */
  ddisc->disc_secsize = DOSsecsize;
  ddisc->disc_RESVDsec = numRESVD;
 
  /* Copy the boot block into the disc description. */
  ddisc->disc_boot = *dboot ;           /* copy the disc boot sector */
 
  /* release the copy we originally allocated */
  free(dboot) ;

  /* but keep the pointer around for short-hand work */
  dboot = &(ddisc->disc_boot) ;
 
  ddisc->disc_FATentries = 0; /* Stop DOS_FAT_RW attempting to count the free clusters. */
 
  if (DOS_FAT_RW(Rdata, ddisc) < 0)
  {
    dprintf(("","DOSFS_image_open: unable to load DOS FAT sector(s)\n"));
    free(ddisc) ;
    /* error message should already be defined */
    return_error0(DOSdisc *, err_fatloadfailed);
  }
 
  /* If the magic ID in the boot block is 0x00 then this is a 320K or 160K format
   * which needs some info to be filled in depending on the first byte of the FAT.
   */
  if (dboot->BOOT_magic == 0x00)
  {
    dboot->BOOT_magic = *((char *)&(ddisc->disc_FAT));
    if (dboot->BOOT_magic == 0xFE)
    {
      dboot->BOOT_secalloc = 0x01;
      dboot->BOOT_root_dir = 0x40;
      dboot->BOOT_root_dirHI = 0x00;
      dboot->BOOT_max_sect = 0x40;
      dboot->BOOT_max_sectHI = 0x01;
      dboot->BOOT_heads = 0x01;
      dboot->BOOT_headsHI = 0x00;
    }
    else
    {
      if (dboot->BOOT_magic == 0xFF)
      {
        dboot->BOOT_secalloc = 0x02;
        dboot->BOOT_root_dir = 0x70;
        dboot->BOOT_root_dirHI = 0x00;
        dboot->BOOT_max_sect = 0x80;
        dboot->BOOT_max_sectHI = 0x02;
        dboot->BOOT_heads = 0x02;
        dboot->BOOT_headsHI = 0x00;
      }
      else
      {
        dprintf(("","DOSFS_image_open: not a valid DOS image\n"));
        free(ddisc);
        return_error0(DOSdisc *, err_notDOSimage);
      }
    }
  }

  /* size of the ROOT directory in sectors */
  ROOTsize = ((READ_LOHI(dboot->BOOT_root_dir) * sizeof(DOS_direntry))+(DOSsecsize-1)) / DOSsecsize ;
  ddisc->disc_ROOTsize = ROOTsize ;      /* in sectors */
  dprintf(("","DOSFS_image_open: ROOTsize   = &%08X\n",ROOTsize));
 
  /* place remaining information into the disc description record */
  dprintf(("","DOSFS_image_open: numFATs = %x, FATsize = %x, DOSsecsize = %x, ROOTsize = %x\n",numFATs,FATsize,DOSsecsize,ROOTsize));
  ddisc->disc_startsec =  numRESVD + (numFATs * FATsize) + ROOTsize +1; /* ensure '1 based' sector count (as used later!) */
  dprintf(("","DOSFS_image_open: Data Start Sector (2nd cluster) = %x\n",ddisc->disc_startsec));
 
  dprintf(("","DOSFS_image_open: disc_ROOTsize = %d\n",ROOTsize));
  dprintf(("","DOSFS_image_open: disc_startsec = %d\n",ddisc->disc_startsec));
 
 
  dprintf(("","DOSFS_image_open: Size of fat entry = %d\n",ddisc->disc_FATentry));
  /* calculate the number of available cluster entries */
  /* clarification needed here:
   * max_sector() returns the total number of sectors on the disc
   * disc_startsec is the 1-based index of the first sector on the disc used for file storage.
   * Thus the number of sectors available for file storage is (total sectors - (startsec-1))
   */
  FATentries = (max_sector(dboot) - (ddisc->disc_startsec-1)) / dboot->BOOT_secalloc ;
  dprintf(("","DOSFS_image_open: FATentries = %x (%d)\n",FATentries,FATentries));
 
  ddisc->disc_FATentries = FATentries ; /* number of cluster entries */
 
  /* DOS_FAT_RW will not have filled in the disc_freeclusters field so we must do that here. */
  ddisc->disc_freeclusters = countfreeclusters(ddisc);
 
  /* We have successfully loaded all the information we need */
  ddisc->disc_flags = disc_UPDATEID ; /* next update should generate new disc ID */
 
  dprintf(("","DOSFS_image_open: ddisc = &%08X\n",(int)ddisc));
 
  dprintf(("","DOSFS_image_open: disc_FAT = %x\n",(int)&ddisc->disc_FAT));
 
  UNUSED(buffsize) ; /* for the moment */
  return(ddisc) ;
}

/*!
 * \param  Image FS handle
 * \return -1 if an error occurred in closing
 */
int DOSFS_image_close(DOSdisc *ihand)
{
  dprintf(("","\n\nDOSFS_image_close: ihand = &%08X\n",(word)ihand));
 
  /* All files opened onto this image should have been closed. This call
   * should just ensure any buffered data and then release the resources
   * attached to the image.
   */
 
  /* Flush the directory cache. */
  flush_dir_cache(ihand);
 
  /* If we just cache the FAT copies (and do not write-back during normal
   * operation) then we should write all the FAT copies to the image at
   * this point. At the moment we always ensure the FAT copies.
   */
  ensure_FATs(ihand);
 
  free(ihand) ;

  return (0) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  buffer Memory address for result
 * \param  blen Size of buffer
 * \param  ihand Image handle
 * \return -1 if defect list read failed
 */
int DOSFS_defect_list(char *fname, word *buffer, word blen, DOSdisc *ihand)
{
  int             limit ;                         /* end of list */
  int             index;
 
  dprintf(("","DOSFS_defect_list: buffer &%08X (blen &%08X) ihand &%08X\n",buffer,blen,(int)ihand));
 
  /* Fill the supplied buffer with the byte offsets of the defects
   * within the image, terminated with a defect list terminator word.
   * It is an error for the specified filename to not be a ROOT object,
   * though DOSFS currently ignores this.
   *
   * We should search the FAT for CLUSTER_bad values that are NOT part
   * of a file chain. The offset we return is true byte offset within
   * the image, ie. we count previous bad CLUSTERs as data.
   */
 
  /* Scan the FAT returning information about BAD CLUSTERs */
  limit = (blen / sizeof(int)) - 1 ;
 
  index = CLUSTER_first(ihand);
  do
  {
    int  secs;
    word addr;
    int  cluster = findCLUSTERtype(ihand, &index, CLUSTER_bad(ihand));

    if (cluster < 0)
    {
      break;
    }
    secs = secsalloc(ihand);
    addr = ((cluster - CLUSTER_first(ihand)) * secs + ihand->disc_startsec - 1) * DOSsecsize + ihand->disc_winioffset;
    if ((limit -= secs) < 0)
    {
      secs += limit;
    }
    while (secs--)
    {
      *buffer = addr;
      buffer++;
      dprintf(("","DOSFS_defect_list: found &%08X\n", addr));
      addr += DOSsecsize;
    }
    index++;
  } while (limit > 0);
 
  /* We left enough room (in the calculation above) for the terminator */
  /* NOTE: At the moment we do not generate an error if there are more
   *       BAD CLUSTERs than will fit into the passed buffer.
   */
  *buffer = DefectList_End ; /* terminate the list */
  UNUSED(fname) ;
  return (0) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  offset Byte offset to map out as defective
 * \param  ihand Image handle
 * \return -1 if defect list add failed
 */
int DOSFS_add_defect(char *fname, word offset, DOSdisc *ihand)
{
  int CLUSTER ;
  int nextCLUSTER ;
 
  dprintf(("","DOSFS_add_defect: \"%s\" &%08X\n",fname,offset));
 
  /* It is an error for the specified filename to not be a ROOT object
   * an error should be returned if the defect cannot be mapped out.
   *
   * if the CLUSTER is part of a file chain then we cannot map it out
   * if it is CLUSTER_bad then it is already mapped out
   * if it is >= CLUSTER_resvd then we cannot map it out
   *
   * it can only be mapped out if it is CLUSTER_unused
   *
   * All we do to map the CLUSTER out is update the FAT. The FAT will then
   * be un-usable by DOS filing systems.
   */
 
  /* Convert byte "offset" to CLUSTER address */
  CLUSTER = ((offset - ihand->disc_winioffset) / DOSsecsize - ihand->disc_startsec + 1) /
            secsalloc(ihand) + CLUSTER_first(ihand);
 
  /* Load the FAT entry at the given CLUSTER */
  nextCLUSTER = getnextCLUSTER(CLUSTER,ihand) ;
  if (nextCLUSTER < CLUSTER_first(ihand)) /* JRS 9/3/92 ensure within FAT */
  {
    return_error0(int, err_clusterchain) ;
  }

  /* If it is CLUSTER_bad then it is already mapped out */
  if (nextCLUSTER != CLUSTER_bad(ihand))
  {
    /* Otherwise check if the CLUSTER is being used */
    if (nextCLUSTER == CLUSTER_unused(ihand))
    {
      writenextCLUSTER(CLUSTER,CLUSTER_bad(ihand),ihand) ;
      if (ensure_FATs(ihand) < 0)
      {
        return((int)-1) ; /* error already defined */
      }
      (ihand->disc_freeclusters)--;
    }
    else
    {
      return_error0(int, err_clusterinuse) ;
    }
  }
  UNUSED(fname);
  return (0) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ihand Image handle
 * \return Boot option
 */
word DOSFS_read_boot_option(char *fname, DOSdisc *ihand)
{
  /* The *OPT 4 boot option is fixed, since there's nowhere to store it on a DOS disc, but it's
   * far more useful for that fixed value to be 2, so we can run a modern boot sequence from it
   */
  dprintf(("","DOSFS_read_boot_option: \"%s\" always returning 2\n",fname));
  UNUSED(fname) ;
  UNUSED(ihand) ;
  return (2) ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  newoption Option to set
 * \param  ihand Image handle
 * \return Error
 */
int DOSFS_write_boot_option(char *fname, word newoption, DOSdisc *ihand)
{
  dprintf(("","DOSFS_write_boot_option: \"%s\" &%02X\n",fname,newoption));
  UNUSED(fname) ;
  UNUSED(newoption) ;
  UNUSED(ihand) ;
  return_error0(int, err_nobootoption) ;
}

/*!
 * \param  buffer Memory address for result
 * \param  blen Size of buffer
 * \param  ihand Image handle
 * \return -1 if used space map read failed
 */
int DOSFS_used_space_map(char *buffer, word blen, DOSdisc *ihand)
{
  int          loop;
  fFAT_sector *dFAT = &(ihand->disc_FAT);
  word         dval;
  word         mask;
  int         *bufp = (int *)((int)buffer & 0xFFFFFFFC);    /* Points to aligned buffer word. */
  int          offset = ((int)buffer & 0x3) << 3;           /* Initial offset into aligned buffer word. */
  int          secalloc = secsalloc(ihand);
 
  dprintf(("","DOSFS_used_space_map: buffer &%08X (blen &%08X) ihand &%08X\n",(word)buffer,blen,(word)ihand));
 
  /* Set all bits and the zero those which correspond to unused sectors.
   * This ensures that things like the FATs and the root directory are copied.
   */
  for (loop = 0; loop < blen; loop++)
  {
    *buffer++ = 0xFF;
  }
  /* buffer now points to the first byte past the end. */
 
  /* Create a mask with as many bits set as there are sectors in a cluster. */
  mask = (1 << secalloc) - 1;
 
  /* Point to the word which contains the 1st bit corresponding to the 1st cluster. */
  offset += ihand->disc_startsec - 1; /* JRS 22/4/92 added -1 since startsec is 1-based, though 0-based is expected for buffer */
  bufp += offset >> 5;
  offset &= 0x1F;
 
  /* Set bits word by word. */
  dval = *bufp;
  for (loop = CLUSTER_first(ihand); loop < ihand->disc_FATentries; loop++)
  {
    word bitaddress = (ihand->disc_FATentry * loop) ;
    word byteaddress = ((bitaddress >> 3) + (word)dFAT) ;
    word shift = (bitaddress & 0x00000007) ;
    word datavalue = loadWORD((char *)byteaddress) ;
    int  cluster = (int)((datavalue >> shift) & FAT_entry_mask(ihand)) ;

    if (cluster == CLUSTER_unused(ihand))
    {
      dval &= ~(mask << offset);
    }
    offset += secalloc;
    if (offset >= 32)
    {
      /* Write out that word */
      *bufp++ = dval;
      dval = *bufp;
      offset &= 0x1F;
      if (cluster == CLUSTER_unused(ihand))
      {
        dval &= ~(mask >> (secalloc - offset));
      }
    }
 
    /* Make sure we don't write past the end of the buffer. */
    if (((uintptr_t)bufp + (offset >> 3)) >= (uintptr_t)buffer) break;
  }
  /* Any partial dval */
  *bufp = dval;
 
  return(0) ;
}

/*!
 * \param  ihand Image handle
 * \return Space available in bytes
 */
FS_free_space *DOSFS_read_free_space(DOSdisc *ihand)
{
  word            unitsize ;                      /* CLUSTER size */
  DOS_bootsector *DOSboot = &(ihand->disc_boot) ; /* short-hand */
 
  dprintf(("","DOSFS_read_free_space: ihand = &%08X\n",(word)ihand));
 
  /* Return the free space information for the given image. */
  unitsize = cluster_size(DOSboot) ;
 
  fspace.freespace = ihand->disc_freeclusters;
  fspace.freespace *= unitsize ;
  fspace.largestobject = fspace.freespace ;
  fspace.discsize = max_sector(DOSboot) * DOSsecsize ;
 
  dprintf(("","DOSFS_read_free_space: returning %d\n", fspace.freespace));
  return (&fspace) ;
}

/*!
 * \param  newname Disc title
 * \param  ihand Image handle
 * \return -1 if failed to set
 */
int DOSFS_namedisc(char *newname,DOSdisc *ihand)
{
  int           numFATs = ihand->disc_boot.BOOT_num_fats ;
  int           FATsize = ihand->disc_FATsize ;
  int           ROOTsize = (ihand->disc_ROOTsize * DOSsecsize) ;
  DOS_direntry *rootdir = NULL ;
  DIR_info     *dirstruct;
 
  dprintf(("","DOSFS_namedisc: \"%s\" (ihand = &%08X)\n",((newname == NULL)?"<NULL>":newname),(int)ihand));
 
  /* Name the referenced image "newname". Under MS-DOS this involves updating
   * the volume entry in the ROOT directory (or creating a new one).
   */
 
  {
    int           index ;
    DOS_direntry *dentry ;
    char         *namebuff = NULL ;
    time5byte     nameTIME ;
    int           rootsec = ((((numFATs * FATsize) + DOSsecsize) / DOSsecsize) + 1) ;
 
    /* Load the ROOT directory */
    if ((int)(dirstruct = loadDIR("", ihand)) < 0)
    {
      return -1;
    }
    rootdir = (DOS_direntry*)DI_Base(dirstruct) ;
 
    /* check ROOTsize (could be wrong for FAT32) */
    if (ROOTsize == 0)
    {
      ROOTsize = dirstruct->dir_size ;
      rootsec  = dirstruct->dir_sector ;
    }
 
    /* Search for a volume entry */
    index = 0 ;
    if ((dentry = findDIRtype((byte)FILE_win95, (byte)FILE_volume, rootdir, ROOTsize, &index)) == NULL)
    {
      /* No existing one, look for a free slot */
      dentry = findemptyDIRentry(rootdir, ROOTsize) ;
    }
    if (dentry == NULL)
    {
      /* There are no free slots in the ROOT directory */
      return_error0(int, err_dirfull) ;
    }
 
    /* zero the directory entry before placing our information */
    memset(dentry, 0, sizeof(DOS_direntry));

    /* write the given discname into the "dentry" */
    namebuff = (char *)&(dentry->FILE_status) ;
    for (index = 0; (index < (namsize + extsize)); index++)
    {
      /* copy upto the first space or NULL character */
      if (*newname && (*newname != ' '))
      {
        *namebuff++ = *newname++ ;
      }
      else
      {
        break ; /* the for loop */
      }
    }

    /* pad upto the limit with spaces */
    for (; (index < (namsize + extsize)); index++)
    {
      *namebuff++ = ' ' ;
    }

    /* mark the directory entry as a "volume" */
    dentry->FILE_attribute = (FILE_volume | FILE_archive) ;
    get_RISCOS_TIME(&nameTIME) ;
    put_FILE_time(dentry->FILE_time,dentry->FILE_timeHI,RISCOStoTIME(&nameTIME)) ;
    put_FILE_date(dentry->FILE_date,dentry->FILE_dateHI,RISCOStoDATE(&nameTIME)) ;
    put_FILE_cluster(dentry,0x00000000,ihand) ;
    dentry->FILE_size = 0x00000000 ; /* labels have no size */
 
    /* Save the (modified) ROOT directory */
    if (DOS_image_RW(Wdata,rootsec,0,(byte *)rootdir,ROOTsize,ihand) < 0)
    {
      free_dir_cache("", ihand);
      return((int)-1) ; /* error already defined */
    }
  }
 
  return(0) ;
}

/*!
 * \param  type Reason for stamp
 * \param  ihand Image handle
 * \return -1 if failed to stamp
 */
int DOSFS_stampimage(int type, DOSdisc *ihand)
{
  dprintf(("","DOSFS_stampimage: type %d (ihand = &%08X)\n",type,(int)ihand));

  /* This call should either update the image's unique identification number
   * (ie. the value returned in the DiscID field of the disc record on an
   * IdentifyDisc call) immediately or as part of the next image update.
   * This is then used by FileCore to keep track of discs when it performs
   * IdentifyDisc calls. When the identity has been updated we should perform
   * an "OS_Args 8" (OSArgs_ImageStampIs) to inform FileCore of the new ID.
   *     OS_Args
   *             r0 = 8
   *             r1 = image file handle
   *             r2 = new image identity
   */
  if (type == FSControl_StampImage_NextUpdate)
  {
    ihand->disc_flags = disc_UPDATEID | disc_CHANGED ;
  }
  if (type == FSControl_StampImage_Now)
  {
    return (update_imageID(ihand)) ;
  }
  
  return(0) ;
}

/*!
 * \param  offset Byte offset to return information for
 * \param  buffer Buffer for result
 * \param  blen Size of buffer
 * \param  ihand Image handle
 * \return -1 if failed to set
 */
int DOSFS_objectatoffset(int offset, char *buffer, int blen, DOSdisc *ihand)
{
  int allocsize = (secsalloc(ihand) * DOSsecsize) ; /* size of a CLUSTER */
  int offCLUSTER ;  /* CLUSTER in which the given offset lies */
  int nextCLUSTER ; /* CLUSTER referenced by offset CLUSTER (offCLUSTER) */
  int state ;
 
  dprintf(("","DOSFS_objectatoffset: offset &%08X, buffer &%08X (len &%08X) (ihand = &%08X)\n",offset,(int)buffer,blen,(int)ihand));
 
  /* Return the type of the object found at the given image offset. If the
   * object has a suitable path, then it should be returned in passed
   * buffer (with a leading directory seperator "." character).
   *
   * type 0 - offset is free, defect or beyond the end of the image
   *      1 - offset is allocated but not a file/directory (eg. FAT)
   *      2 - offset is in single object
   *      3 - offset is in multiple objects
   *
   * Return codes 2 and 3 should place the object name into the buffer.
   */
 
  /* For DOS discs we can easily spot the system areas of the image, and
   * areas that have NOT yet been allocated. However, to find the name of
   * an object we will have to scan every directory until we find an
   * object whose chain contains the CLUSTER at the given offset.
   */
 
  /* CLUSTER align (downwards) the passed offset */
  offCLUSTER = (offset / allocsize) ;
  dprintf(("","DOSFS_objectatoffset: offCLUSTER = &%03X\n",offCLUSTER));
 
  if (CLUSTERtoSECTOR(offCLUSTER,ihand) < ihand->disc_startsec)
  {
    dprintf(("","DOSFS_objectatoffset: CLUSTER in system area (returning 1)\n"));
    return (1) ; /* CLUSTER is in the system area */
  }
 
  nextCLUSTER = getnextCLUSTER(offCLUSTER,ihand) ;
  if (nextCLUSTER < CLUSTER_first(ihand))  /* JRS 9/3/92 ensure within FAT */
  {
    return_error0(int, err_clusterchain) ;
  }

  if ((nextCLUSTER == CLUSTER_unused(ihand)) || (nextCLUSTER == CLUSTER_bad(ihand)))
  {
    dprintf(("","DOSFS_objectatoffset: CLUSTER in free or bad (returning 0)\n"));
    return (0) ; /* CLUSTER is free or bad */
  }
 
  /* Under DOSFS a CLUSTER can only be used by one object. Therefore we never
   * return reason code 3 (offset used by multiple objects). If we reach here
   * we must place the object name into the passed buffer and return reason
   * code 2.
   */
  /* We need to scan from the root directory all file (and directory) chains,
   * until we find a file which contains a reference to "offCLUSTER".
   */
  *buffer = '\0';    /* Start from root directory. */
  if ((state = findCLUSTER(offCLUSTER, buffer, blen, ihand)) == 0)
  {
    dprintf(("","DOSFS_objectatoffset: CLUSTER could not be found in a chain\n"));
    return(0) ; /* We could NOT find the CLUSTER in any chain */
  }
  if (state < 0)
  {
    return(-1) ; /* error already defined */
  }

  /* The above "findCLUSTER" call will have filled the buffer suitably */
  return(2) ; /* CLUSTER is in use */
}
