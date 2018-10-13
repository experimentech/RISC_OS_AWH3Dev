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
/*> c.OpsFind <*/
/*-------------------------------------------------------------------------*/
/* DOSFS image FS 'Find'                        Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"
#include "Interface/HighFSI.h"
#include "Interface/LowFSI.h"
#include "DebugLib/DebugLib.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "ADFSshape.h"
#include "Helpers.h"
#include "Ops.h"
#include "MsgTrans.h"
#include "DOSclusters.h"
#include "DOSnaming.h"
#include "DOSshape.h"
#include "DOSdirs.h"

/*!
 * \param  op Mode to open
 *            0 -> then open for reading             (error if file doesn't exist)
 *            1 -> then open for writing             (create file)
 *            2 -> then open for reading and writing (error if file doesn't exist)
 * \param  fname NULL terminated ASCII pathname, relative to ROOT of image
 * \param  ihand Image handle
 * \param  foff File offset
 * \return Internal file open information, or -1 if failed to open
 */
FS_open_block *DOSFS_open_file(word op, char *fname, DOSdisc *ihand)
{
  DIR_info     *cdir ;           /* directory where the leafname resides */
  char         *DOSname ;        /* full DOS pathname */
  char         *leafname ;       /* pointer to the leafname of "DOSname" */
  char         *roname ;         /* original RISC OS name given */
  int           loop ;           /* general index variable */
  int           createfile = 0 ; /* non-zero if we need to create the file */
  DOS_direntry *dentry ;         /* directory entry pointer */
  FILEhand     *fdesc ;          /* file descriptor for open file */
  time5byte     le ;             /* for load/exec address information */
  char          dosext[8] ;      /* DOS/RISC OS filetype extension */
  word          CLUSTERsize ;    /* CLUSTER size (in bytes) for this image */
 
  dprintf(("","\n\nDOSFS_open_file: op = %d, fname = \"%s\", ihand = &%08X\n",op,fname,(word)ihand));
  CLUSTERsize = cluster_size(&ihand->disc_boot) ;
 
  /* create a open file descriptor (even though we may fail later) */
  if ((fdesc = (FILEhand *)malloc(sizeof(FILEhand))) == NULL)
  {
    return_errorT(FS_open_block *,err_heapexhausted,tok_heapexhausted,0,0) ;
  }

  /* default return information */
  fblock.inhand = fdesc ;        /* internal file handle */
  fblock.buffsize = 0 ;
  fblock.fileext = 0 ;
  fblock.falloc = 0 ;
 
  /* default file descriptor information */
  fdesc->ihand = ihand ;       /* handle onto the image */
  fdesc->opentype = op ;       /* type of open operation */
  fdesc->loadaddr = 0 ;        /* current object load address */
  fdesc->execaddr = 0 ;        /* current object exec address */
  fdesc->startCLUSTER = -1 ;   /* this object has no data */
  fdesc->currentCLUSTER = -1 ; /* nor any current data */
  fdesc->filelen = 0 ;         /* current object length */
  fdesc->indexptr = 0 ;        /* sequential pointer */
  fdesc->modified = FALSE ;    /* buffer unmodified */
  fdesc->filebuff = NULL ;     /* no data buffer */
 
  /* convert "fname" to DOS path format */
  if ((DOSname = (char *)malloc(MaxString)) == NULL)
  {
    free(fdesc) ;
    return_errorT(FS_open_block *, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  if ((roname = (char *)malloc(strlen(fname) + 1)) == NULL)
  {
    free(DOSname) ;
    free(fdesc) ;
    return_errorT(FS_open_block *, err_heapexhausted, tok_heapexhausted, 0, 0) ;
  }
  strcpy(roname,fname) ;     /* take a copy of the original filename */
  fdesc->fname = roname ;    /* and reference it in the file handle structure */
 
  if ((int)convertRISCOStoLFN(fname, DOSname) < 0)
  {
    free(roname);
    free(DOSname);
    free(fdesc);
    return (FS_open_block *)-1;
  }
 
  /* load the desired directory (also returns the leafname) */
  if (resolvePATH(DOSname,&cdir,&leafname,ihand) < 0)
  {
    free(roname) ;
    free(DOSname) ;
    free(fdesc) ;
    return((FS_open_block *)-1) ; /* error already defined */
  }
 
  /* if creating then check that "leafname" does NOT contain wildcards */
  if ((op == fsopen_CreateUpdate) && (leafname != NULL))
  {
    if (checknotwildcarded(leafname, DOSwcmult, DOSwcsing) != NULL)
    {
      free(roname) ;
      free(DOSname) ;
      free(fdesc) ;
      return_error1(FS_open_block *, err_wildcardedname, fname) ;
    }
  }
 
  /* search the loaded directory */
  loop = 0 ;
  if ((dentry = findDIRentry(leafname, cdir, cdir->dir_size, &loop)) != NULL)
  {
    int mode;
    dprintf(("","DOSFS_open_file: object exists\n"));
 
    /* Check that the file is not open but allow multiple read only opens. */
    if ((mode = find_open_file(fname, dentry, ihand)) >= 0 && (mode + op) > 0)
    {
      free(roname);
      free(DOSname);
      free(fdesc);
      return_error1(FS_open_block *, err_fileopen, leafname);
    }
 
    if (!(dentry->FILE_attribute & FILE_subdir) && (op != fsopen_ReadOnly) && (dentry->FILE_attribute & FILE_readonly) != 0)
    {
      free(roname);
      free(DOSname);
      free(fdesc);
      return_error1(FS_open_block *, err_filelocked, leafname);
    }
 
    /* get the MSDOS extension characters */
    (void)after(dosext, leafname, file_sep, 1) ;
 
    /* if creating then we must delete any old copy of the file first */
    if (op == fsopen_CreateUpdate)
    {
      dprintf(("","DOSFS_open_file: delete existing file\n"));
      if ((dentry->FILE_attribute & FILE_subdir) != 0)
      {
        free(roname) ;
        free(DOSname) ;
        free(fdesc) ;
        return_errorT(FS_open_block *, err_notfile, tok_notfile, fname, 0) ;
      }
 
      set_dir_flags(cdir, dir_MODIFIED) ;
      dentry->FILE_status = FILE_deleted ;
      freeclusters(get_FILE_cluster(dentry,ihand),ihand) ;
      createfile = -1 ; /* we need to create a new file */
    }
  }
  else
  {
    dprintf(("","DOSFS_open_file: object does not exist\n"));
    if (op != fsopen_CreateUpdate)
    {
      free(roname) ;
      free(DOSname) ;
      free(fdesc) ;
      return_errorT(FS_open_block *, err_objectnotfound, tok_objectnotfound, fname, 0) ;
    }
 
    dprintf(("","DOSFS_open_file: create operation specified\n"));
    createfile = -1 ;    /* create option specified */
  }
 
  if (createfile != 0)
  {
    set_dir_flags(cdir, dir_LOCKED);
    /* generate a directory entry for the file */
    if (saveFILE(fname, leafname, 0, 0, NULL, 0, &cdir, &dentry, 1, ihand) < 0)
    {
      /* failed to save the file */
      dprintf(("","DOSFS_open_file: failed to save empty file\n"));
      unset_dir_flags(cdir, dir_LOCKED);
      DOS_FAT_RW(Rdata, ihand);
      free_dir_cache(DOSname, ihand);
      free(roname) ;
      free(DOSname) ;
      free(fdesc) ;
      /* the error message should already be defined */
      return((FS_open_block *)-1) ;
    }
    unset_dir_flags(cdir, dir_LOCKED);
 
    /* get the directory entry for this newly created file */
    loop = 0 ;
    if ((dentry = findDIRentry(leafname, cdir, cdir->dir_size, &loop)) == NULL)
    {
      dprintf(("","DOSFS_open_file: failed to find newly created file\n"));
      free(roname) ;
      free(DOSname) ;
      free(fdesc) ;
      return_errorT(FS_open_block *,err_objectnotfound,tok_objectnotfound,fname,0) ;
    }
    /* "dentry" for the newly created file */
    if ((ensure_directory(cdir)!= 0) || (ensure_FATs(ihand) != 0))
    {
      free(roname) ;
      free(DOSname) ;
      free(fdesc) ;
      return((FS_open_block *)-1) ; /* error already defined */
    }
  }
 
  if ((dentry->FILE_attribute & FILE_subdir) == FILE_subdir)
  {
    fblock.information = fsopen_ReadPermission | fsopen_IsDirectory;
  }
  else
  {
    fblock.information = fsopen_ReadPermission | ((op == fsopen_ReadOnly) ? 0 : fsopen_WritePermission);
  }

  dprintf(("","DOSFS_open_file: fdesc (before)     = &%08X\n",(int)fdesc));
  dprintf(("","DOSFS_open_file: FILE_list (before) = &%08X\n",(int)FILE_list));
  fdesc->next = FILE_list ;    /* reference the current open file list */
  FILE_list = fdesc ;          /* place our handle at the head of the list */
  dprintf(("","DOSFS_open_file: FILE_list (after)  = &%08X\n",(int)FILE_list));
 
  /* convert the MSDOS timestamp to a RISC OS 5byte value */
  read_loadexec(dentry, dosext, &le);
 
  fdesc->loadaddr = le.hi ; /* load address */
  fdesc->execaddr = le.lo ; /* exec address */
 
 
  fdesc->startCLUSTER = get_FILE_cluster(dentry,ihand) ;
  fdesc->filelen = dentry->FILE_size ;
  fdesc->indexptr = 0 ;          /* read/write pointer within file */
  fdesc->currentCLUSTER = -1 ;   /* number of currently buffered CLUSTER */
  fdesc->modified = FALSE ;      /* whether CLUSTER has been modified */
  fdesc->filebuff = NULL ;       /* CLUSTER buffer pointer */
 
  /* fblock.information = access flags -> bit 31 WRITE; bit 30 READ
   * fblock.inhand      = internal filesystem handle for this file
   * fblock.buffsize    = buffer size of 2^n (n = 6..10))
   * fblock.fileext     = file length
   * fblock.falloc      = file allocation (buffer multiple)
   */
  fblock.inhand = fdesc ;
  fblock.buffsize = DOSsecsize;  /* suggest buffering sectors to FileSwitch */
  fblock.fileext = dentry->FILE_size ;
  fblock.falloc = ((dentry->FILE_size + (CLUSTERsize - 1)) & -CLUSTERsize) ;
 
  free(DOSname) ;        /* release the translated name buffer */
 
  dprintf(("","DOSFS_open_file: fhand &%08X (len &%08X ptr &%08X)\n",(int)fdesc,fdesc->filelen,fdesc->indexptr));
 
  return &fblock ;       /* and return the open information */
}

/*!
 * \param  fhand Internal handle
 * \param  loadaddr Final load address to stamp
 * \param  execaddr Final exec address to stamp
 * \return -1 if failed to close
 */
int DOSFS_close_file(FILEhand *fhand, word loadaddr, word execaddr)
{
  FILEhand *cptr = NULL ;
  FILEhand *last = NULL ;
 
  dprintf(("","\n\nDOSFS_close_file: fhand = &%08X, load = &%08X, exec = &%08X\n",(word)fhand,loadaddr,execaddr));
 
  /* NOTEs
   * -----
   * If this file was opened with a create operation (OPENOUT) then we should
   * set the closed length to that of the current file pointer. This may
   * involve releasing allocated CLUSTERs aswell as updating the directory
   * information.
   */
 
  /* Search for the file descriptor that we are going to remove */
  last = NULL ;
  for (cptr = FILE_list; (cptr != NULL); cptr = cptr->next)
  {
    dprintf(("","DOSFS_close_file: cptr &%08X ; last &%08X\n",(int)cptr,(int)last));
    if (cptr == fhand)
    {
      dprintf(("","DOSFS_close_file: handle found (filebuff = &%08X, modified = %d)\n",(int)fhand->filebuff,fhand->modified));
 
      /* remove this structure from the list */
      dprintf(("","DOSFS_close_file: removing handle from active list (last = &%08X)\n",(int)last));
      if (last == NULL)
      {
        FILE_list = fhand->next ;
      }
      else
      {
        last->next = fhand->next ;
      }
 
      /* if file opened for writing then flush the buffer if modified */
      if (fhand->filebuff != NULL)
      {
        if (fhand->modified)
        {
          dprintf(("","DOSFS_close_file: flushing cached cluster %d to disk\n",fhand->currentCLUSTER));
          DOS_cluster_RW(Wdata,fhand->currentCLUSTER,0,fhand->filebuff,(secsalloc(fhand->ihand) * DOSsecsize),fhand->ihand) ;
          fhand->modified = FALSE ;
        }
        free(fhand->filebuff) ;
        fhand->filebuff = NULL ;
      }
 
      if (fhand->opentype != 0)
      {
        dprintf(("","DOSFS_close_file: index &%08X (length &%08X)\n",fhand->indexptr,fhand->filelen));
 
        /* update the directory information */
        if (fhand->fname != NULL) /* should never be NULL */
        {
          word bitmap = 0x00000000 ;
          _kernel_swi_regs  rset ;
          _kernel_oserror  *rerror ;
 
          dprintf(("","DOSFS_close_file: filename \"%s\"\n",fhand->fname));
 
          /* update the directory entry load and exec addresses */
          if ((loadaddr & ADFStimestamp) == ADFStimestamp)
          {
             bitmap |= ((1 << wdi_LOAD) | (1 << wdi_EXEC)) ;
          }

          /* (re)write the file length aswell */
          bitmap |= (1 << wdi_FLEN) ;
 
          /* and write the startCLUSTER (in-case this is was an empty file) */
          bitmap |= (1 << wdi_SCLUSTER) ;

          write_dirinfo(fhand->fname, bitmap, loadaddr, execaddr, NULL,
                        fhand->filelen, fhand->startCLUSTER, fhand->ihand) ;
 
          /* Flush the output */
          rset.r[0] = OSArgs_Flush;
          rset.r[1] = (word)((fhand->ihand)->disc_fhand);
          if ((rerror = _kernel_swi(OS_Args, &rset, &rset)) != NULL)
          {
            dprintf(("","DOSFS_close_file: error from OS_Args 255: (&%08X) \"%s\"\n",rerror->errnum,rerror->errmess));
            return_errorX(int, rerror);
          }
        }
      }
 
      /* release the filename buffer if allocated */
      if (fhand->fname != NULL)
      {
        dprintf(("","DOSFS_close_file: releasing filename buffer at &%08X\n",(int)fhand->fname));
        free(fhand->fname) ;
        fhand->fname = NULL ; /* ensure future accesses will fail */
      }
 
      /* Check that we have released all allocated, attached memory buffers */
      dprintf(("","DOSFS_close_file: releasing file handle structure &%08X\n",(int)fhand));
      free(fhand) ;
      return 0 ; /* return to the caller */
    }
    last = cptr ;
  }
 
  dprintf(("","DOSFS_close_file: file handle not recognised\n"));
  return_errorT(int, err_channel, tok_channel, 0, 0) ;
}
