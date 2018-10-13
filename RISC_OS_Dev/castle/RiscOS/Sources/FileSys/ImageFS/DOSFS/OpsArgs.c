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
/*> c.OpsArgs <*/
/*-------------------------------------------------------------------------*/
/* DOSFS image FS 'Args'                        Copyright (c) 1990 JGSmith */
/*-------------------------------------------------------------------------*/

#include <stdlib.h>
#include "DebugLib/DebugLib.h"

#include "DOSFS.h"
#include "DOSshape.h"
#include "Ops.h"
#include "DOSclusters.h"

/*!
 * \param  fhand Internal handle
 * \param  fext New file extent
 * \return -1 if failed to write
 */
int DOSFS_write_extent(FILEhand *fhand, word fext)
{
  dprintf(("","\n\nDOSFS_write_extent: fhand = &%08X, fext = &%08X\n",(int)fhand,fext));
 
  /* We will fall straight through if the extent is identical to the current
   * file length.
   */
  if (fext > fhand->filelen)
  {
    word indexptr = fhand->indexptr ; /* preserve our position over ensure */
    if (DOSFS_write_zeros(fhand,fhand->filelen,(fext - fhand->filelen)) < 0)
    {
      return ((int)-1) ; /* error already defined */
    }
    fhand->indexptr = indexptr ; /* restore file position */
  }
  else
  {
    if (fext < fhand->filelen)
    {
      /* truncate the file to the desired length */
      if (ensure_exact(fhand, fext) < 0)
      {
        return((int)-1) ; /* error already defined */
      }
      fhand->indexptr = fext ; /* new file position */
    }
  }

  dprintf(("","DOSFS_write_extent: fhand &%08X (len &%08X ptr &%08X)\n",
              (int)fhand, fhand->filelen, fhand->indexptr));
  return (0) ;
}

/*!
 * \param  fhand Internal handle
 * \return Allocated size of this file
 */
word DOSFS_alloc(FILEhand *fhand)
{
  int CLUSTERsize ;
 
  dprintf(("","\n\nDOSFS_alloc: fhand = &%08X\n",(int)fhand));
 
  CLUSTERsize = cluster_size(&(fhand->ihand->disc_boot)) ;
 
  /* return the disc space allocated to the file */
  dprintf(("","DOSFS_alloc: fhand &%08X (len &%08X ptr &%08X)\n",(int)fhand,fhand->filelen,fhand->indexptr));

  return((fhand->filelen + (CLUSTERsize - 1)) & -CLUSTERsize) ;
}

/*!
 * \param  fhand Internal handle
 * \return Date stamp assigned to the file
 */
FS_datestamp *DOSFS_flush(FILEhand *fhand)
{
  dprintf(("","\n\nDOSFS_flush: fhand = &%08X\n",(int)fhand));
 
  /* flush the file buffer if modified */
  if ((fhand->filebuff != NULL) && fhand->modified)
  {
    dprintf(("","DOSFS_flush: buffer needs to be written to the file\n"));
    DOS_cluster_RW(Wdata,fhand->currentCLUSTER,0,fhand->filebuff,(secsalloc(fhand->ihand) * DOSsecsize),fhand->ihand) ;
    fhand->modified = FALSE ; /* clear the modified flag */
  }
 
  /* The load/exec addresses returned are those currently in the directory
   * entry for the file.
   */
  tstamp.loadaddr = fhand->loadaddr ;
  tstamp.execaddr = fhand->execaddr ;
 
  dprintf(("","DOSFS_flush: fhand &%08X (len &%08X ptr &%08X)\n",(int)fhand,fhand->filelen,fhand->indexptr));
 
  return (&tstamp) ;
}

/*!
 * \param  fhand Internal handle
 * \param  ensure Space to ensure is set aside (any extension need not be zeroed)
 * \return Date stamp assigned to the file
 */
word DOSFS_ensure(FILEhand *fhand, word ensure)
{
  dprintf(("","\n\nDOSFS_ensure: fhand = &%08X, ensure = &%08X\n",(int)fhand,ensure));
 
  /* Set the file length to at least the desired value "ensure". */
  if (fhand->filelen < ensure)
  {
    if (ensure_exact(fhand, ensure) < 0)
    {
      return -1;
    }
  }
 
  dprintf(("","DOSFS_ensure: fhand &%08X (len &%08X ptr &%08X)\n",(int)fhand,fhand->filelen,fhand->indexptr));

  return (fhand->filelen) ;
}

/*!
 * \param  fhand Internal handle
 * \param  bytes Number bytes to zero
 * \param  foff File offset
 * \return -1 if failed to write
 */
int DOSFS_write_zeros(FILEhand *fhand, word foff, word bytes)
{
  return DOS_bytes_RW(Wzero, 0, bytes, foff, fhand);
}

/*!
 * \param  fhand Internal handle
 * \return Date stamp assigned to the file
 */
FS_datestamp *DOSFS_read_datestamp(FILEhand *fhand)
{
  dprintf(("","\n\nDOSFS_read_datestamp: fhand = &%08X\n",(int)fhand));
 
  /* The load/exec addresses returned are those currently in the directory
   * entry for the file.
   */
  tstamp.loadaddr = fhand->loadaddr ;
  tstamp.execaddr = fhand->execaddr ;
 
  dprintf(("","DOSFS_read_datestamp: fhand &%08X (len &%08X ptr &%08X)\n",(int)fhand,fhand->filelen,fhand->indexptr));

  return (&tstamp) ;
}
