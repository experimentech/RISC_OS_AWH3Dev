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
/*> c.OpsFile <*/
/*-------------------------------------------------------------------------*/
/* DOSFS image FS 'File'                        Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "kernel.h"
#include "DebugLib/DebugLib.h"
#include "Interface/HighFSI.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "Helpers.h"
#include "Ops.h"
#include "MsgTrans.h"
#include "DOSclusters.h"
#include "DOSnaming.h"
#include "DOSshape.h"
#include "DOSdirs.h"

/*!
 * \param  fn NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ld New load address for the file
 * \param  ex New exec address for the file
 * \param  bs Base address of data in memory (inclusive)
 * \param  end End address of data in memory (exclusive)
 * \param  ihand Image handle
 * \return Leafname string for *OPT 1 style output
 */
char *DOSFS_save_file(char *fn, word ld, word ex, char *bs, char *end, DOSdisc *ihand)
{
  DIR_info     *cdir ;     /* directory where the leafname resides */
  char         *DOSname ;  /* full DOS pathname */
  char         *leafname ; /* pointer to the leafname of "DOSname" */
  DOS_direntry *dentry ;   /* directory entry structure pointer */
  static char   tline[MaxString] = "" ; /* static filename return area */
 
 
  dprintf(("","\n\nDOSFS_save_file: \"%s\"\n",fn));
 
  /* convert "fn" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(char *,err_heapexhausted,tok_heapexhausted,0,0) ;
  }
 
  if ((int)convertRISCOStoLFN(fn, DOSname) < 0)
  {
    free(DOSname);
    return (char *)-1;
  }
 
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname, &cdir, &leafname, ihand) < 0)
  {
    free(DOSname) ;
    return ((char *)-1) ; /* error already defined */
  }
 
  dprintf(("","DOSFS_save_file: cdir = &%08X, cdir->ihand = &%08X\n",(int)cdir,(int)(cdir->ihand)));
 
  set_dir_flags(cdir, dir_LOCKED);
 
  /* create the directory entry and save the file */
  if (saveFILE(fn, leafname, ld, ex, (char *)bs, (word)(end - bs), &cdir, &dentry, 0, ihand) < 0)
  {
    unset_dir_flags(cdir, dir_LOCKED);
    DOS_FAT_RW(Rdata, ihand);
    free_dir_cache(DOSname, ihand);
    free(DOSname) ;
    return ((char *)-1) ; /* error already defined */
  }
  unset_dir_flags(cdir, dir_LOCKED);
 
  /* Do this before freeing DOSname. */
  strcpy(tline, leafname) ;
 
  free(DOSname) ; /* and the pathname buffer */
 
  return tline ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ihand Image handle
 * \return Catalogue entry information
 */
FS_cat_entry *DOSFS_read_cat(char *fname, DOSdisc *ihand)
{
  int           loop ;               /* general loop counter */
  char         *DOSname = NULL ;     /* converted pathname */
  char         *leafname = NULL ;    /* leafname of loaded directory */
  DIR_info     *cdir = NULL ;        /* pointer to the loaded directory */
  DOS_direntry *dentry ;             /* directory entry pointer */
  int           temp;

  dprintf(("","\n\nDOSFS_read_cat: \"%s\"\n",((fname == NULL) ? "" : fname)));
 
  /* defaults */
  fcat.type = object_nothing ;
  fcat.loadaddr = 0x00000000 ;
  fcat.execaddr = 0x00000000 ;
  fcat.filelen  = 0x00000000 ;
  fcat.fileattr = 0x00000000 ;
 
  /* convert "fname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(FS_cat_entry *, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  if ((int)convertRISCOStoLFN(fname, DOSname) < 0)
  {
    free(DOSname);
    return &fcat;    /* Just return file not found. */
  }
 
  /* load the desired directory (also returns the leafname) */
  if (temp = resolvePATH(DOSname,&cdir,&leafname,ihand), temp < 0)
  {
    free(DOSname);
    return &fcat;    /* Just return file not found. */
  }
  dprintf(("","DOSFS_read_cat: leafname = \"%s\"\n",leafname));

  /* search the directory */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname, cdir, cdir->dir_size, &loop)) != NULL)
  {
    time5byte le ;
    char      dosext[8] = {0,0,0,0,0,0,0,0} ;

    dprintf(("","DOSFS_read_cat: file found\n"));

    if (buildFILEname(dentry,DOSname) != NULL)
    {
      (void)after(dosext, DOSname, file_sep, 1) ;
    }

    read_loadexec(dentry, dosext, &le) ; /* get the load/exec information */

    fcat.type = (((dentry->FILE_attribute & FILE_subdir) == 0) ? object_file : object_directory) ;

    /* construct suitable RISC OS fields */
    fcat.loadaddr = le.hi ;
    fcat.execaddr = le.lo ;
    fcat.filelen  = dentry->FILE_size ;
    fcat.fileattr = DOStoRISCOSattributes(dentry) ;
  }
 
  free(DOSname) ;
 
  return &fcat ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ld New load address for the file
 * \param  ex New exec address for the file
 * \param  attr New attributes for the file
 * \param  ihand Image handle
 * \return -1 if failed to write
 */
int DOSFS_write_cat(char *fname,word ld,word ex,word attr,DOSdisc *ihand)
{
  int state ;

  dprintf(("","\n\nDOSFS_write_cat: \"%s\"\n",fname));

  /* If the object does not exist, DO NOT return an error. If the object is
   * a directory, and the filesystem does NOT support directory attributes and
   * information, then return an error.
   */
  state = write_dirinfo(fname, ((1 << wdi_LOAD) | (1 << wdi_EXEC) | (1 << wdi_ATTR)), ld, ex, attr, NULL, NULL, ihand) ;
  if ((state == -1) && ((_syserr->errnum & err_mask) == err_objectnotfound))
  {
    state = 0 ; /* ignore "file not found" error */
  }

  return state ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ihand Image handle
 * \note   Does not generate an error if the file is not found
 * \return Catalogue entry information of deleted object
 */
FS_cat_entry *DOSFS_delete(char *fname, DOSdisc *ihand)
{
  DIR_info     *cdir ;     /* directory where the leafname resides */
  char         *DOSname ;  /* full DOS pathname */
  char         *leafname ; /* pointer to the leafname of "DOSname" */
  DOS_direntry *dentry ;   /* directory entry structure pointer */
  int           loop ;     /* general index counter */
  int           value = 0; /* general work variable */
 
  dprintf(("","\n\nDOSFS_delete: \"%s\"\n",fname));
 
  /* convert "fname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(FS_cat_entry *,err_heapexhausted,tok_heapexhausted,0,0) ;
  }

  if ((int)convertRISCOStoLFN(fname, DOSname) < 0)
  {
    free(DOSname);
    return (FS_cat_entry *)-1;
  }
 
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname, &cdir, &leafname, ihand) < 0)
  {
    free(DOSname) ;
    return ((FS_cat_entry *)-1) ; /* error already defined */
  }
 
  /* delete the directory entry */
  dprintf(("","DOSFS_delete: leafname = \"%s\"\n",leafname));
 
  /* search the directory (we do not complain if the file is not found) */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname, cdir, cdir->dir_size, &loop)) != NULL)
  {
    time5byte le ;
    char      dosext[8] = {0,0,0,0,0,0,0,0} ;
 
    dprintf(("","DOSFS_delete: file found\n"));
 
    /* Make sure that the file is not open. */
    if (find_open_file(fname, dentry, ihand) >= 0)
    {
      free(DOSname);
      return_error1(FS_cat_entry *, err_fileopen, fname);
    }
 
    if ((dentry->FILE_attribute & FILE_readonly) != 0)
    {
      free(DOSname);
      return_error1(FS_cat_entry *, err_filelocked, fname);
    }
 
    if ((dentry->FILE_attribute & FILE_subdir) != 0)
    {
      /* check that the directory is empty */
      DIR_info *subdir ;
      char     *subleafname ;
 
      dprintf(("","DOSFS_delete: attempt to delete directory\n"));
      dprintf(("","DOSFS_delete: DOSname  = \"%s\"\n",DOSname));
      dprintf(("","DOSFS_delete: leafname = \"%s\"\n",leafname));
 
      /* At the moment "resolvePATH" has special code to deal with the
       * single entry in ROOT. We need to simulate that here.
       */
      /* We want to load the directory that is currently our leafname */
      {
        char *s = leafname, *d = DOSname + strlen(DOSname);
        if (d != DOSname)
        {
          *d++ = '\\';
        }
        do
        {
          *d++ = *s;
        } while (*s++ != '\0');
      }
      strcat(DOSname, "\\*.*");
 
      dprintf(("","DOSFS_delete: DOSname  = \"%s\"\n",DOSname));
 
      set_dir_flags(cdir, dir_LOCKED);

      /* load the desired directory, returning the leafname "*.*" */
      if (resolvePATH(DOSname, &subdir, &subleafname, ihand) < 0)
      {
        unset_dir_flags(cdir, dir_LOCKED);
        free(DOSname) ;
        return((FS_cat_entry *)-1) ; /* error already defined */
      }
      unset_dir_flags(cdir, dir_LOCKED);
 
      loop = 0 ;
      dprintf(("","DOSFS_delete: subleafname = \"%s\"\n",subleafname));
      if (findDIRentry(subleafname, subdir, subdir->dir_size, &loop) != NULL)
      {
        dprintf(("","DOSFS_delete: attempt to delete non-empty directory\n"));
        free(DOSname) ;
        return_error1(FS_cat_entry *,err_notempty,fname) ;
      }
 
      /* Remove this directory and any of its children from the directory cache. */
      free_dir_cache(DOSname, ihand);
    }
 
    /* We have found the file directory entry, so remove the directory entry
     * and then release the cluster chain associated with the object.
     * RISC OS expects a description of the object deleted to be returned.
     */          
    (void)buildFILEname(dentry, DOSname) ;
    (void)after(dosext, DOSname, file_sep, 1) ;
 
    /* construct return information */
    read_loadexec(dentry, dosext, &le);
 
    {
      byte status = dentry->FILE_status;
      int diroffset = (int)((((int)dentry) - (DI_Base(cdir))) / sizeof(DOS_direntry));

      dentry->FILE_status = FILE_deleted;
      dprintf(("","DOSFS_delete: diroffset = %x\n",diroffset));
      if (cdir->lfnp[diroffset] != NULL)
      {
        dprintf(("","DOSFS_delete: removing lfn\n"));
        free(cdir->lfnp[diroffset]);
        cdir->lfnp[diroffset] = NULL;
        DOS_lfnentry *lfndir = ((DOS_lfnentry*)dentry) - 1 ;
        while(lfndir->FILE_attribute == FILE_win95)
        {
          lfndir->FILE_Ordinal = FILE_deleted;
          lfndir--;
          if ((lfndir->FILE_Ordinal & 0x40) == 0) break;
        }
      }
      set_dir_flags(cdir, dir_MODIFIED);
      if (value = ensure_directory(cdir), value == 0)
      {
        freeclusters(get_FILE_cluster(dentry,ihand), ihand);
        if ((value = ensure_FATs(ihand)) == 0)
        {
          /* construct the return information */
          fcat.type     = (((dentry->FILE_attribute & FILE_subdir) == 0) ? object_file : object_directory) ;
          fcat.loadaddr = le.hi ;
          fcat.execaddr = le.lo ;
          fcat.filelen  = dentry->FILE_size ;
          fcat.fileattr = DOStoRISCOSattributes(dentry) ;
        }
      }
      else
      {
        /* If the directory ensure (write) fails eg. because disc is write-protected then
         * we don't free the clusters and don't delete the file.
         */
        flush_dir_cache(ihand);
        dentry->FILE_status = status;
        unset_dir_flags(cdir, dir_MODIFIED);
      }
    }
  }
 
  free(DOSname) ;
 
  dprintf(("","DOSFS_delete: completed OK\n"));
  if (value)
  {
    return ((FS_cat_entry *)-1);
  }
  return &fcat ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ld Load address to give new file
 * \param  ex Exec address to give new file
 * \param  base Base address in memory
 * \param  end End address in memory (used with "base" to derive length)
 * \param  ihand Image handle
 * \return -1 if failed to create
 */
int DOSFS_create(char *fname, word ld, word ex, char *base, char *end, DOSdisc *ihand)
{
  DIR_info     *cdir ;     /* directory where the leafname resides */
  char         *DOSname ;  /* full DOS pathname */
  char         *leafname ; /* pointer to the leafname of "DOSname" */
  DOS_direntry *dentry ;   /* directory entry structure pointer */
  word          length = ((word)end - (word)base) ;
 
  dprintf(("","\n\nDOSFS_create: base &%08X, end &%08X\n",(word)base,(word)end));
  dprintf(("","DOSFS_create: \"%s\" length &%08X (ld: &%08X ex: &%08X)\n",fname,length,ld,ex));
 
  /* convert "fname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(int,err_heapexhausted,tok_heapexhausted,0,0) ;
  }
  if ((int)convertRISCOStoLFN(fname, DOSname) < 0)
  {
    free(DOSname);
    return -1;
  }
 
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname, &cdir, &leafname, ihand) < 0)
  {
    free(DOSname) ;
    return (-1) ; /* error already defined */
  }
 
  /*
   * If a file of the specified name already exists, then delete it. An error
   * should be returned if the file cannot be deleted. The new file should
   * have the same attributes as the old file if one existed, otherwise a
   * suitable default value.
   */
  dprintf(("","DOSFS_create: cdir = &%08X, cdir->ihand = &%08X\n",(int)cdir,(int)(cdir->ihand)));
 
  set_dir_flags(cdir, dir_LOCKED);
 
  /* create the directory entry (using the "saveFILE" primitive) */
  if (saveFILE(fname, leafname, ld, ex, NULL, length, &cdir, &dentry, 1, ihand) < 0)
  {
    unset_dir_flags(cdir, dir_LOCKED);
    DOS_FAT_RW(Rdata, ihand);
    free_dir_cache(DOSname, ihand);
    free(DOSname) ;
    return (-1) ; /* error already defined */
  }
  unset_dir_flags(cdir, dir_LOCKED);
 
  free(DOSname) ; /* and the pathname buffer */
 
  return 0 ;
}

/*!
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ld Load address to give directory
 * \param  ex Exec address to give directory
 * \param  size Number of directory entries required
 * \param  ihand Image handle
 * \return -1 if failed to create
 */
int DOSFS_create_dir(char *fname, word ld, word ex, word size, DOSdisc *ihand)
{
  DIR_info     *cdir ;                      /* directory where the leafname resides */
  char         *DOSname ;                   /* full DOS pathname */
  char         *leafname ;                  /* pointer to the leafname of "DOSname" */
  DOS_direntry *dentry ;                    /* directory entry structure pointer */
  DIR_info     *pdir = NULL ;               /* parent directory (if required) */
  char         *memaddr ;                   /* memory buffer for new directory image */
  int           CLUSTERsize ;               /* size of a CLUSTER in bytes */
  int           CLUSTERs_required ;         /* number of CLUSTERs required for dir */
  int           loop ;                      /* general index counter */
  int           startCLUSTER ;              /* CLUSTER where the directory starts */
  time5byte     saveTIME ;                  /* time the directory was created */
  int           ROOTcluster ;               /* CLUSTER for the ROOT of the filesystem */
  int           not_sfn;                    /* flag not a valid short name */
  int           numreq, diroffset;          /* number of dir entries needed for the long filename */
  DOS_direntry *lfn[(MaxString + 12) / 13]; /* enough dir entries for the longest long filename */
  char         *longfileholder;             /* for long name */
  char          shortname[14];              /* for short name equivalent */

  dprintf(("","\n\nDOSFS_create_dir: \"%s\"\n",fname));
 
  /* convert "fname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    return_errorT(int, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  if ((int)convertRISCOStoLFN(fname, DOSname) < 0)
  {
    free(DOSname);
    return -1;
  }
 
  /* resolve the path (ie. load the directory the file is in) */
  if (resolvePATH(DOSname, &cdir, &leafname, ihand) < 0)
  {
    free(DOSname) ;
    return (-1) ; /* error already defined */
  }
 
  /* create the directory entry */
  dprintf(("","DOSFS_create_dir: \"%s\" in dir &%08X\n",leafname,(word)cdir));
 
  /* directories are initially given 1 cluster (is this the same as MS-DOS?) */
  CLUSTERsize = cluster_size(&(ihand->disc_boot)) ;
  CLUSTERs_required = 1 ;
 
  /* If "cdir->dir_root == -1" then the parent DIR is the ROOT directory.
   * The ROOT directory does not live in the normal disc data area (i.e. cluster
   * area). This means that it cannot be allocated a CLUSTER number. It also
   * means that the ROOT directory CANNOT be extended.
   */
  if (cdir->dir_root == -1)
  {
    ROOTcluster = 0 ; /* ROOT directory has CLUSTER 0 (for convenience) */
  }
  else
  {
    ROOTcluster = SECTORtoCLUSTER(cdir->dir_sector,ihand) ;
  }
 
  /*
   * If the directory already exists, then try renaming it (the case of certain
   * letters in the name may have changed). Do not return an error if the
   * rename fails.
   */
  dprintf(("","DOSFS_create_dir: parent directory type = %d\n",cdir->dir_root));
  dprintf(("","DOSFS_create_dir: parent directory sector = %d\n",cdir->dir_sector));
  dprintf(("","DOSFS_create_dir: CLUSTERsize = &%08X\n",CLUSTERsize));
  dprintf(("","DOSFS_create_dir: parent directory cluster = &%03X\n",ROOTcluster));
 
  /* allocate memory buffer for the new directory */
  if ((memaddr = (char *)calloc(1, CLUSTERs_required * CLUSTERsize)) == NULL)
  {
    free(DOSname) ;
    return_errorT(int, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
 
  /* check to see if the directory already exists */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname,cdir,cdir->dir_size,&loop)) != NULL)
  {
    /* object already exists */
    free(DOSname) ;
    free(memaddr) ;
    if ((dentry->FILE_status != FILE_directory) && ((dentry->FILE_attribute & FILE_subdir) == 0))
    {
      /* object already exists as a file */
      return_errorT(int, err_badtypes, "TypsBad", NULL, NULL) ;
    }
    /* object exists as a directory, do not generate an error */
    /* Since MS-DOS is only upper-case we don't need to worry about preserving
     * the case of the name given on entry.
     */
    return(0) ;
  }
 
  dprintf(("","DOSFS_create_dir: does NOT already exist\n"));

  /* Try to allocate the long filename array. The leafname has a NULL
   * terminator, rounded up to the nearest block of 13, plus one extra
   * for the DOS short name   length + 1 + 12 + 1 = length + 2
   *                          ---------------       ------
   *                                 13               13
   */
  numreq = (strlen(leafname) / 13) + 2;
  dprintf(("","DOSFS_create_dir: numreq = %d\n",numreq));
  if (get_dir_entry_array(lfn, ihand, numreq, &cdir, &pdir,NULL) < 0)
  {
    free(DOSname);
    free(memaddr);
    return -1;
  }
 
  /* "dentry" = pointer to the directory entry to create */
  if ((startCLUSTER = claimfreeclusters(CLUSTERs_required, ihand)) < 0)
  {
    free(DOSname);
    free(memaddr);
    return -1;
  }
 
  /* Create 8.3 filename from leafname */
  not_sfn = shorten_lfn(leafname, shortname, cdir);
  dentry = not_sfn ? lfn[numreq - 1] : lfn[0];
 
  dprintf(("","saveDIR: long filename = '%s'\n",leafname));
  dprintf(("","saveDIR: short filename = '%s'\n",shortname));
 
  if (not_sfn) MakeLFNEntries(lfn, numreq, leafname, shortname);
  sprintf((char *)&dentry->FILE_status, "%-8.8s%-3s", shortname, &shortname[8]);

  /* mark the object as a directory */
  dentry->FILE_attribute = FILE_subdir; /* JRS removed (| FILE_archive) here 6/3/92 */
  memset((char *)&(dentry->FILE_reserved),0,spare1) ; /* ZERO "spare1" bytes */
  dentry->FILE_size = 0; /* JRS 6/3/92 DOS directories have size set to 0. Removed: (CLUSTERs_required * CLUSTERsize) ;*/
  dprintf(("","DOSFS_create_dir: dir size written = &%08X\n",dentry->FILE_size));

  /* use the passed load/exec addresses */
  saveTIME.lo = ex ;
  saveTIME.hi = (ld & 0xFF) ;
  put_FILE_time(dentry->FILE_time,dentry->FILE_timeHI,RISCOStoTIME(&saveTIME)) ;
  put_FILE_date(dentry->FILE_date,dentry->FILE_dateHI,RISCOStoDATE(&saveTIME)) ;
  put_FILE_cluster(dentry,startCLUSTER,ihand) ;
 
  longfileholder = (char *)malloc(strlen(leafname) + 1);
  if (longfileholder == NULL)
  {
    free(DOSname);
    free(memaddr);
    return_errorT(int, err_heapexhausted, tok_heapexhausted, 0, 0);
  }
  strcpy(longfileholder, leafname);

  diroffset = (int)((int)(dentry) - DI_Base(cdir)) / sizeof(DOS_direntry);
  (cdir)->lfnp[diroffset] = longfileholder;
  dprintf(("","DOSFS_create_dir: index = %d, pointer = %p, actual = %p\n",diroffset,(cdir)->lfnp[diroffset], longfileholder));

  set_dir_flags(cdir, dir_MODIFIED) ; /* directory has been updated */
 
  /* construct a default directory */
  {
    DOS_direntry *direntries ;
  
    for (loop=0; (loop < (CLUSTERs_required * CLUSTERsize)); loop++)
    {
      memaddr[loop] = NULL ;
    }

    /* make "." */
    direntries = (DOS_direntry *)&(memaddr[0]) ;
    sprintf((char *)&(direntries->FILE_status),".          ") ;
    direntries->FILE_attribute = FILE_subdir ;
    memset((char *)&(direntries->FILE_reserved),0,spare1) ; /* ZERO spare1 bytes */
    put_FILE_time(direntries->FILE_time,direntries->FILE_timeHI,RISCOStoTIME(&saveTIME)) ;
    put_FILE_date(direntries->FILE_date,direntries->FILE_dateHI,RISCOStoDATE(&saveTIME)) ;
    put_FILE_cluster(direntries,startCLUSTER,ihand) ;
    direntries->FILE_size = 0x00000000 ;      /* special directory */
  
    /* make ".." */
    direntries = (DOS_direntry *)&(memaddr[1 * sizeof(DOS_direntry)]) ;
    sprintf((char *)&(direntries->FILE_status),"..         ") ;
    direntries->FILE_attribute = FILE_subdir ;
    memset((char *)&(direntries->FILE_reserved),0,spare1) ; /* ZERO spare1 bytes */
    put_FILE_time(direntries->FILE_time,direntries->FILE_timeHI,RISCOStoTIME(&saveTIME)) ;
    put_FILE_date(direntries->FILE_date,direntries->FILE_dateHI,RISCOStoDATE(&saveTIME)) ;
    put_FILE_cluster(direntries,ROOTcluster,ihand) ;
    direntries->FILE_size = 0x00000000 ;      /* special directory */
  }
 
  /* copy the data from memory into the allocated clusters */
  if (DOS_object_RW(Wdata, startCLUSTER, memaddr, (CLUSTERs_required * CLUSTERsize), ihand) != 0)
  {
    DOS_FAT_RW(Rdata, ihand);
    flush_dir_cache(ihand);
    free(DOSname) ;
    free(memaddr) ;
    return -1;
  }
 
  free(DOSname) ;
  free(memaddr) ;

  if (pdir != NULL)
  {
    if (ensure_directory(pdir) != 0)
    {
      return -1;
    }
  }
 
  if ((ensure_directory(cdir) != 0) || (ensure_FATs(ihand) != 0))
  {
    return (-1) ; /* error already defined */
  }
 
  return (0) ;
  UNUSED(size) ;
}

/*!
 * \param  fname Filename for which the block size is required
 * \param  ihand Image handle
 * \return Natural block size in bytes
 */
word DOSFS_read_block_size(char *fname,DOSdisc *ihand)
{
  int CLUSTERsize = cluster_size(&(ihand->disc_boot)) ;

  dprintf(("","DOSFS_read_block_size: \"%s\"; ihand = &%08X\n",fname,(word)ihand));
  UNUSED(fname) ;
  return (CLUSTERsize) ;
}
