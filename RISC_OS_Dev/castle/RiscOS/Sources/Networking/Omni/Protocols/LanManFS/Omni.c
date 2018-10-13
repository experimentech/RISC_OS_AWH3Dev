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
/*
*  Lan Manager client
*
*  Omni.C -- OmniFiler interface portions
*
*  Versions
*  13-10-94 INH Original
*  02-07-96     Changes to OmniOp 8
*
*/

/* This manages the following bits:

  (i) Keeps a list of all the server names we have seen,
   in order to provide some server_ids.

  (ii) Keeps a list of all the mount paths we have seen,
   to provide an enumerate-mounts function.

  (iii) Keeps a list of all the current drives (mounts) to
   enable mount name->drive number conversion

  (iv) Does the interface to the Free module

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "kernel.h"
#include "swis.h"

#include "stdtypes.h"
#include "SMB.h"
#include "RPC.h"
#include "LanMan.h"
#include "Printers.h"
#include "VersionNum"
#include "Xlate.h"
#include "LMVars.h"
#include "Stats.h"
#include "Logon.h"
#include "Omni.h"
#include "LanMan_MH.h"

#define INFO_STR_LEN 64
/* Length of info string kept about servers & mounts */

/* ------------------------ */

/* Information on a known mount path or printer name.
   New versions of this have one set of generic list
   handler routines  */

/* Tag for a valid disk name */
#define D_VALID_TAG 0x834EBE92
/* Tag for a valid printer name */
#define P_VALID_TAG 0x945EBE93
/* Tag for a valid server name */
#define S_VALID_TAG 0x4938EE2B
/* Tag for a valid current mount */
#define M_VALID_TAG 0x9384EBE2
/* Tag for an IPC mount */
#define I_VALID_TAG 0x24435049
/* Tag for comms device mount */
#define C_VALID_TAG 0x314D4F43

typedef struct namelist NAMELIST;  /* Our general holds-everything list */

/* Information on a server */
struct server_extra_info
{
  NAMELIST *known_disks;  /* -> list of D_VALID_TAG records */
  NAMELIST *known_printers;  /* -> list of P_VALID_TAG records */
  NAMELIST *known_ipc;  /* list of I_VALID_TAG records */
  NAMELIST *known_comms; /* list of C_VALID_TAG records */
  char      info_string[INFO_STR_LEN];
};

/* Information on a current connection */
struct mount_extra_info
{
  NAMELIST *servername;       /* Server ID -> S_VALID_TAG record*/
  NAMELIST *diskname;        /* Mount path -> D_VALID_TAG record */
  char smb_lettr;   /* SMB deals in drive letters */
  char connected;     /* Non-zero as soon as it is mounted */
};

/* Information on a share */
struct share_extra_info
{
  char      info_string[INFO_STR_LEN];
};

/* Multipurpose name-list structure */
struct namelist
{
  int    tag;                 /* One or other VALID_TAG */
  struct namelist *next;
  char   name[NAME_LIMIT];

  union
  {
    struct mount_extra_info  mount;
    struct server_extra_info server;
    struct share_extra_info share;
  } u;

  struct namelist *master_link;
};

static NAMELIST *MasterList = NULL; /* List of everything we've malloc'd */
static NAMELIST *FreeList = NULL;   /* Used for deleted items */
static NAMELIST *MountsList = NULL; /* Current mounts */
static NAMELIST *ServerList = NULL; /* Known servers (known disks/printers
                                       hang off the side of this list) */

/* Name-list functions ============================================= */

static NAMELIST *alloc_nl(void)
{
  NAMELIST *pNL;

  if ( FreeList != NULL )          /* Salvage deleted items */
  {
    NAMELIST *pLinkSave;

    pNL = FreeList;                /* Recycle one from free list */
    FreeList = FreeList->next;

    pLinkSave = pNL->master_link;  /* Clear everything except master_link */
    memset (pNL, 0, sizeof(NAMELIST));
    pNL->master_link = pLinkSave;
  }
  else
  {
    pNL = (NAMELIST *)malloc(sizeof(NAMELIST));
    if ( pNL == NULL ) /* Bum! */
      return NULL;
    memset (pNL, 0, sizeof(NAMELIST));

    pNL->master_link = MasterList; /* Add it to the master list */
    MasterList = pNL;
  }

  return pNL;
}

/* FreeAllLists() ---------------------------------*/
/* This frees everything we've allocated; it also does some
   heavy deletion of things to prevent grief if it gets called
   twice, etc.
*/
static void FreeAllLists(void)
{
  NAMELIST *pNL, *pNL2;

  pNL = MasterList;
  FreeList = NULL;
  MasterList = NULL;

  while ( pNL != NULL )
  {
    pNL2 = pNL->master_link;
    memset (pNL, 0, sizeof(NAMELIST));
    free(pNL);
    pNL = pNL2;
  }

}

/* AddToList() ------------------------------------*/
/* This adds a given name to a list, and returns a pointer to
   the item. If an item of the same name already exists on
   the list, no allocation is performed; the existing item
   is returned. New allocations have all their 'extra_info'
   fields set to zero.
*/
static NAMELIST *AddToList( NAMELIST **pListHead, int valid_tag,
                              const char *name_in )
{
  NAMELIST *pNL, *pNLprev, *pNLnew;
  int c;
  char namebuf[NAME_LIMIT];

  /* Truncate name appropriately */
  strcpyn ( namebuf, name_in, NAME_LIMIT );

  /* Traverse list */
  for ( pNL= *pListHead, pNLprev = NULL;
        pNL != NULL;
        pNLprev = pNL, pNL = pNL->next )
  {
     c = stricmp ( pNL->name, namebuf );
     if ( c == 0 ) return pNL;  /* Exact match */
     if ( c > 0 )  /* Item goes after pNLprev and before pNL */
       break;
  }

  /* Need to insert item before pNL and after pNLprev.
     pNLprev is NULL if it goes at the head of the list. */

  pNLnew = alloc_nl();

  if ( pNLnew == NULL )  /* Bummer! Failed! */
    return NULL;

  pNLnew->tag = valid_tag;
  strcpy(pNLnew->name, namebuf);
  pNLnew->next = pNL;

  if ( pNLprev == NULL )
    *pListHead = pNLnew;
  else
    pNLprev->next = pNLnew;

  return pNLnew;
}

/* FindInList() -----------------------------------*/
static NAMELIST *FindInList ( NAMELIST *ListHead, const char *name_in )
{
  NAMELIST *pNL;
  int c;
  char namebuf[NAME_LIMIT];

  /* Truncate name appropriately */
  strcpyn ( namebuf, name_in, NAME_LIMIT );

  /* Traverse list */
  for ( pNL= ListHead; pNL != NULL; pNL = pNL->next )
  {
     c = stricmp ( pNL->name, namebuf );
     if ( c == 0 ) return pNL;  /* Exact match */
     if ( c > 0 )  /* Gone past end */
       break;
  }

  return NULL;     /* Not found */
}

/* DeleteFromList() -------------------------------*/
static void DeleteFromList( NAMELIST **pListHead, NAMELIST *item )
{
  NAMELIST *pNL;

  if ( *pListHead == item )  /* First in list */
  {
    *pListHead = item->next;
  }
  else                       /* Search for it in list */
  for ( pNL = *pListHead; pNL != NULL; pNL = pNL->next )
  {
    if ( pNL->next == item )
    {
      pNL->next = item->next;
      break;
    }
  }

  /* Add to freelist */
  item->next = FreeList;
  item->tag  = 0;
  FreeList = item;
}

/* Main Routines =================================================== */

/* FindActiveMount() ------------------------------*/
/* Given a disk (D_VALID_TAG) record, finds out if it is the current
   active mounts list. If so, returns a NAMELIST * for the corresponding
   entry in the list.
   If not, returns NULL.
*/
static NAMELIST *FindActiveMount ( NAMELIST *pD )
{
  NAMELIST *pNL;

  for ( pNL = MountsList; pNL != NULL; pNL = pNL->next )
    if ( pNL->u.mount.diskname == pD )
      return pNL;

  return NULL;
}

/* Validate() -------------------------------------*/
static NAMELIST *Validate(int id, int validtag)
{
  NAMELIST *pNL;
  if ( id != 0 && ((id & 3)== 0) ) /* Aligned pointer check! */
  {
    pNL = (NAMELIST *)id;
    if ( pNL->tag == validtag )
      return pNL;
  }
  return NULL;
}

static char work_buf[80];
static char name_buf[NAME_LIMIT+16];

/* DoCLIop() --------------------------------------*/
/* This does a CLI operation on the given mount. The command
   string should contain a %s at the point where the mount
   name should be put, it will be replaced by "LanMan::mountname"
*/
static err_t DoCLIop ( char *command, int mount_id )
{
  _kernel_swi_regs R;

  NAMELIST *pNL = Validate(mount_id, (int)M_VALID_TAG);

  if ( pNL == NULL )
    return EBADPARAM;

  sprintf( name_buf, FilingSystemName "::%s", pNL->name );
  sprintf( work_buf, command, name_buf );
  R.r[0] = (int) work_buf;
  return MsgSetOSError( _kernel_swi ( XOS_Bit | OS_CLI, &R, &R ));
}

/* MountNameCpy() ---------------------------------*/
static void MountNameCpy ( char *d, char *s )
{
  int n_written=0, c;

  while ( n_written < (NAME_LIMIT-1) )
  {
    c = *s++;
    if ( c==' ' || c=='/' || c=='\\')
      continue;  /* Skip spaces */
    if ( c <' ' || c=='.' || c=='*' || c=='$' )
      break;
    *d++ = c;
    n_written++;
  }

  *d = 0;
}

static int ReentryCount = 0;

/* BootMount() ------------------------------------ */
/* Runs the !ArmBoot file, if such a thing exists. The !ArmBoot file
   may contain perfectly valid *Connect commands, and so this bit
   will be reentrant. The laws are therefore this: nothing following
   the call to DoCLIop must rely on any static variables/buffers which
   are able to be modified by any *command or SWI. As a safeguard, we
   limit the number of times this can be reentered (the limit is
   MAX_DRIVES)
*/
#ifdef CHECK_ARMBOOT_EXISTS
static err_t BootMount_check_file ( NAMELIST *pNLmount, const char *leaf )
{
  int type;
  static char filename[80];
  err_t e;

  sprintf ( filename, FilingSystemName "::%s.$.%s", pNLmount->name, leaf );
  e = MsgSetOSError(_swix(OS_File, _INR(0,1)|_OUT(0), 23, filename, &type));
  if (e == OK) {
    if (type == 0) e = ECANTFINDNAME;
  }
  return e;
}
#endif

static err_t BootMount ( NAMELIST *pNLmount )
{
  _kernel_swi_regs R;
  err_t res;

  /* Attempts to run a !ArmBoot file or applicationn, if it exists */

  if ((_kernel_osbyte(129, 255, 255) & 0xFF00) == 0xFF00) {
     /* SHIFT was depressed, or an error occurred */
     return OK;
  }


#ifdef TRACE
  debug1("BootMount looking for %s\n", work_buf);
#endif

  /* If no such file or directory, we can stop now */
#ifdef CHECK_ARMBOOT_EXISTS
  if (BootMount_check_file(pNLmount, "!ARMBOOT") != OK)
    return OK;
#else
  return OK;
#endif

  /* Safety check */
  if ( ReentryCount >= MAX_DRIVES )
    return EBOOTREENTRY;

  ++ReentryCount;
  R.r[0] = 0; /* Are we running in desktop? */
  if ( _kernel_swi ( XOS_Bit | Wimp_ReadSysInfo, &R, &R ) == NULL &&
       R.r[0] > 0 )
  {
    /* Yes? Filer_run it */
    res = DoCLIop ("Filer_run %s.$.!ArmBoot", (int) pNLmount );
  }
  else
  {
    res = DoCLIop ("Run %s.$.!ArmBoot", (int) pNLmount );
  }
  --ReentryCount;

  /* To avoid confusion, use a different error for !ArmBoot errors */
  if ( res != OK )
    return EBOOTERROR;

  return res;
}

/* Omni_MountServer() ------------------------------- */
/* Makes a connection to a server;
   it is the XXXX_OmniOp 0 SWI.
*/
err_t Omni_MountServer ( char *servname, char *userID, char *passwd,
         char *mountname, char *mountpath, int *mount_id_out )
{
  err_t res;
  char namebuf[NAME_LIMIT];
  NAMELIST *pNLmount, *pNLsrv;

  *mount_id_out = 0;

#ifdef TRACE
  debug3("Omni_MountServer: %p %p %p\n", mountname, servname, mountpath);
#endif

  if ( mountname == NULL || servname == NULL || mountpath == NULL )
    return EBADPARAM;

  MountNameCpy ( namebuf, mountname );

  /* Check for mount with same name */

  pNLmount = AddToList ( &MountsList, (int)M_VALID_TAG, namebuf );

  if ( pNLmount == NULL )    /* Out of memory -oops! */
    return ECONNLIMIT;

  if ( pNLmount->u.mount.connected != 0 )
  {
    /* Mount name exists - delete it so we can reuse it */
    SMB_DeleteShare (pNLmount->u.mount.smb_lettr);
  }

  /* Connect or amend connection details */

  res = SMB_CreateShare ( SHR_DISK, CREATE_NEW_USER | CREATE_NEW_SHARE,
              servname, mountpath, userID, passwd,
              &(pNLmount->u.mount.smb_lettr) );

  if ( res != OK ) /* Didn't work. Forget it */
  {
#ifdef TRACE
    debug0("SMB_CreateShare failed\n");
#endif
    DeleteFromList ( &MountsList, pNLmount );
    return res;
  }

  /* Yes, it worked: update our known-server & known-shares lists */

  pNLmount->u.mount.connected  = 1;

  pNLsrv = AddToList ( &ServerList, S_VALID_TAG, servname );
  pNLmount->u.mount.servername = pNLsrv;

  if ( pNLsrv != NULL )
  {
    pNLmount->u.mount.diskname =
      AddToList ( &pNLsrv->u.server.known_disks, (int)D_VALID_TAG, mountpath );
  }
  else                /* Out of memory - carry on anyway */
  {
    pNLmount->u.mount.diskname  = NULL;
  }

  /* Indicate success to !Omni. This is now independent of whether we
     return an error or not */

  *mount_id_out = (int) (pNLmount);

  /* The connection to the server might have changed & new browse
      info might be available */

  Omni_RecheckInfo(RI_SERVERS);
  Omni_RecheckInfo(RI_PRINTERS);

  /* Done - try to run !ArmBoot file */

  return BootMount ( pNLmount );
}

/* Omni_DismountServer() --------------------------*/
/* Does XXXX_OmniOp 1 */
err_t Omni_DismountServer ( int mount_id )
{
  NAMELIST *pNL = Validate(mount_id, (int)M_VALID_TAG);

  if ( pNL == NULL )
    return EBADPARAM;

  /* Disregard errors! Disconnect anyway! */

  DoCLIop ("Filer_CloseDir %s.$", mount_id );
  SMB_DeleteShare (pNL->u.mount.smb_lettr);
  DeleteFromList(&MountsList, pNL);
  return OK;
}

/* Omni_FreeSpace() -------------------------------*/
/* Does XXXX_OmniOp 2 */
static uint size_clip ( uint val, uint limit, uint blksize )
{
  return (val > limit) ? 0xFFFFFFFFU : val * blksize;
}

static err_t Omni_DetermineFreeSpace ( int mount_id,
       struct disk_size_response *DSR)
{
  NAMELIST *pNL = Validate(mount_id, (int)M_VALID_TAG);

  if ( pNL == NULL )
    return EBADPARAM;

  return SMB_GetFreeSpace ( pNL->u.mount.smb_lettr, DSR );
}

static err_t Omni_FreeSpace ( int mount_id,
       int *freespace_out, int *usedspace_out, int *totspace_out )
{
  struct disk_size_response DSR;
  uint blklimit;
  err_t res;

  res = Omni_DetermineFreeSpace ( mount_id, &DSR );
  if ( res != OK )
    return res;

  /* Make sure we don't overflow.
     Free space in bytes is DSR.blksize * DSR.freeblks */

  blklimit = 0xFFFFFFFFU / DSR.blksize;

  *freespace_out = size_clip( DSR.freeblks, blklimit, DSR.blksize );
  *totspace_out  = size_clip( DSR.totalblks, blklimit, DSR.blksize );
  *usedspace_out  = size_clip( DSR.totalblks-DSR.freeblks,
                                             blklimit, DSR.blksize );

  return OK;
}

/* Omni_FreeSpace64() ------------------------------*/
/* Does XXXX_OmniOp 4 */
static err_t Omni_FreeSpace64 ( int mount_id, int *success,
       QWORD *freespace_out, QWORD *usedspace_out, QWORD *totspace_out )
{
  struct disk_size_response DSR;
  err_t res;
  uint  used;
  
  res = Omni_DetermineFreeSpace ( mount_id, &DSR );
  if ( res != OK )
    return res;

  /* DWORD*DWORD => QWORD result */
  *freespace_out = (QWORD)DSR.freeblks * DSR.blksize;
  *totspace_out = (QWORD)DSR.totalblks * DSR.blksize;
  used = DSR.totalblks - DSR.freeblks; 
  *usedspace_out = (QWORD)used * DSR.blksize;
  *success = 0;

  return OK;
}

/* Subroutines to help enumeration routines ======================== */
static char *enum_ptr;
static int   enum_bytes_left;

static bool enum_align_ptr(void)
{
  int p = (int) enum_ptr;
  p = (-p) & 3; /* Number of bytes needed to align pointer to a word */

  if ( enum_bytes_left < p )
    return false;

  enum_bytes_left -= p;
  enum_ptr += p;
  return true;
}

static bool enum_write_word( int val )
{
  if ( enum_bytes_left < 4 )
    return false;

  *((int *)enum_ptr) = val;

  enum_bytes_left -= 4;
  enum_ptr += 4;
  return true;
}

static bool enum_write_string( char *str, int maxlen )
  /* maxlen is maximum length including null terminator */
{
  int len = strlen(str)+1;
  if ( len > maxlen ) len = maxlen;

  if ( enum_bytes_left < len )
    return false;

  memcpy ( enum_ptr, str, len );
  enum_ptr[len-1] = 0;
  enum_bytes_left -= len;
  enum_ptr += len;
  return true;
}

/* Omni_ListServers() -----------------------------*/
/* Does XXXX_OmniOp 3 */
static err_t Omni_ListServers ( char *buf_ptr, int buf_size, int token_in,
              const char **pNextByte_out, int *pToken_out )
{
  /* If token_in is 0 we start from the beginning of the list;
     if not it should be a pToken_out which we previously
     supplied. Our tokens will be pointers to entries in
     the server list */

  NAMELIST *pNL;
  char *next_byte_written;

  /* Check token_in */

  if ( token_in == 0 )
  {
    if ( LM_Vars.logged_on )
      RPC_EnumerateServers( LM_Vars.workgroup );
    pNL = ServerList;
  }
  else
  {
    pNL = Validate(token_in, S_VALID_TAG );
    if ( pNL == NULL )
      return EBADPARAM;
  }

  /* Write data */

  enum_ptr = buf_ptr;
  enum_bytes_left = buf_size;
  next_byte_written = buf_ptr;

  while ( pNL != NULL )
  {
    if ( enum_write_word( (int) pNL ) &&
         enum_write_string ( pNL->name, 16 ) &&
         enum_write_string ( pNL->name, 32 ) &&
         enum_write_string ( pNL->u.server.info_string, 64 ) &&
         enum_align_ptr()
       )
    {
      /* Record written OK */
      next_byte_written = enum_ptr;
      pNL = pNL->next;
    }
    else /* Can't fit this record in! */
      break;
  }

  /* Done! pNL is the next record which would have been
     written, or NULL if we're all done */

  *pNextByte_out = next_byte_written;
  *pToken_out = (int) pNL;
  return OK;
}

/* Omni_ListMounts() ------------------------------*/
/* Does XXXX_OmniOp 4 */
static err_t Omni_ListMounts (
     char *buf_ptr, int buf_size, int token_in,
     int server_id, char *server_name,
     const char **pNextByte_out, int *pToken_out )
{
  /* If token_in is 0 we start from the beginning of the list;
     if not it should be a pToken_out which we previously
     supplied. Here, tokens will be pointers to entries on the
     known_disks list for each server. */

  NAMELIST *pNLsrv;
  NAMELIST *pNLdisk;
  char *next_byte_written;


  /* If token_in is non-NULL, we're in the middle */

  if ( token_in != 0 )
  {
    pNLdisk = Validate(token_in, (int)D_VALID_TAG);
    if ( pNLdisk == NULL )
      return EBADPARAM;
  }
  else if ( server_id != 0 ) /* Use given server ID */
  {
    pNLsrv = Validate(server_id, S_VALID_TAG);
    if ( pNLsrv == NULL )
      return EBADPARAM;

    /* Get disk/printer shares for this server */
    if ( LM_Vars.logged_on )
      RPC_EnumerateShares ( pNLsrv->name );

    pNLdisk = pNLsrv->u.server.known_disks;
  }
  else /* Use given server name */
  {
    /* Attempt to contact server - it will be added to list if OK */
    if ( LM_Vars.logged_on )
      RPC_EnumerateShares ( server_name );

    pNLsrv = FindInList(ServerList, server_name);
    if ( pNLsrv == NULL )  /* Not found - give zero results */
      pNLdisk = NULL;
    else
      pNLdisk = pNLsrv->u.server.known_disks;
  }

  /* Now list known mounts ------------ */

  enum_ptr = buf_ptr;
  enum_bytes_left = buf_size;
  next_byte_written = buf_ptr;

  while ( pNLdisk != NULL )
  {
    if ( enum_write_word( (int) FindActiveMount(pNLdisk) ) &&
         enum_write_string ( pNLdisk->name, 16 ) &&
         enum_write_string ( pNLdisk->name, 32 ) &&
         enum_align_ptr()
       )
    {
      /* Record written OK */
      next_byte_written = enum_ptr;
      pNLdisk = pNLdisk->next;
    }
    else /* Can't fit this record in! */
      break;
  }

  /* Done ! pNLdisk is the next record which would have been
     written, or NULL if we're all done */

  *pNextByte_out = next_byte_written;
  *pToken_out = (int) pNLdisk;
  return OK;
}

/* Omni_ListActiveMounts() ------------------------*/
/* Does XXXX_OmniOp 5 */
static err_t Omni_ListActiveMounts ( char *buf_ptr, int buf_size,
    int token_in, const char **pNextByte_out, int *pToken_out )
{
  /* Here, the token_in/token_out numbers will pointers to entries in
     the MountsList list.
  */

  char *next_byte_written;
  NAMELIST *pNL;


  if ( token_in == 0 )
    pNL = MountsList;
  else
  {
    pNL = Validate(token_in, (int)M_VALID_TAG);
    if ( pNL == NULL )
      return EBADPARAM;
  }

  enum_ptr = buf_ptr;
  enum_bytes_left = buf_size;
  next_byte_written = buf_ptr;

  while ( pNL != NULL )
  {
    if ( enum_write_word ( (int) (pNL->u.mount.servername) ) && /* Server ID */
         enum_write_word ( (int) pNL ) && /* Mount ID */
         enum_write_string ( pNL->name, 16 ) &&
         enum_align_ptr()
       )
    {
      next_byte_written = enum_ptr; /* Written OK */
      pNL = pNL->next;
    }
    else /* Record wouldn't fit */
      break;
  }

  /* Search complete if pNL == NULL, or pNL = next record if not */

  *pNextByte_out = next_byte_written;
  *pToken_out = (int) pNL;
  return OK;
}

/* Omni_ListPrinters() ------------------------*/
/* Does XXXX_OmniOp 16 */
static err_t Omni_ListPrinters ( char *buf_ptr, int buf_size,
    int token_in, const char **pNextByte_out, int *pToken_out )
{
  /* Here, the token_in/token_out numbers will be pointers
     to an entry on the known_printers list for each
     server. Unfortunately, we have to flatten the servers/
     printers list, hence this may get a little slow.
  */

  NAMELIST *pNLsrv;    /* Pointer in servers list */
  NAMELIST *pNLprn;    /* Current printer */
  NAMELIST *pNLstart;  /* Printer at which to start enumerating */

  char *next_byte_written;

  /* Check token_in */

  if ( token_in == 0 )
    pNLstart = NULL;
  else
  {
    pNLstart = Validate ( token_in, (int)P_VALID_TAG );
    if ( pNLstart == NULL )
      return EBADPARAM;
  }

  /* ------- */

  enum_ptr = buf_ptr;
  enum_bytes_left = buf_size;
  next_byte_written = buf_ptr;
  pNLprn = NULL;  /* In case no servers! */

  for ( pNLsrv = ServerList; pNLsrv != NULL; pNLsrv = pNLsrv->next )
    for ( pNLprn = pNLsrv->u.server.known_printers; pNLprn != NULL;
                                            pNLprn = pNLprn->next )
    {
      if ( pNLstart == NULL || pNLprn == pNLstart )
      {
        /* Write record */
        if ( enum_write_word( 0 ) &&  /* Flags */
             enum_write_string ( pNLprn->name, 24 ) && /* Printer name */
             enum_write_string ( pNLsrv->name, 64 ) && /* Server name */
             enum_align_ptr()
           )
        {
          next_byte_written = enum_ptr;
        }
        else
          goto out_of_buffer;

        /* Record written OK */
      }
    }

  /* Done ! pNLprn is NULL if we finished OK, or a pointer to the
     printer record which we were about to write when we ran out
     of buffer */

out_of_buffer:
  *pNextByte_out = next_byte_written;
  *pToken_out = (int) pNLprn;
  return OK;
}

/* Omni_OpenRoot () -------------------------------*/
/* Triggers a filer_opendir on the root directory for a given mount */

static err_t Omni_OpenRoot ( int mount_id )
{
  return DoCLIop ("Filer_OpenDir %s.$", mount_id );
}

/* Omni_OpenUserRoot () ---------------------------*/
/* Triggers a filer_opendir on the user's home directory for a given mount */
static err_t Omni_OpenUserRoot ( int mount_id )
{
  return DoCLIop ("Filer_OpenDir %s.$", mount_id );
}

/* Omni_GetNewMountInfo() -------------------------*/
/* Works out whether a new password or userID will be needed for
   a new mount on an existing server.

   (02-07-96) This is called when a user double-clicks on an icon in
   the available-mounts window for a particular server. This is called
   with the server id and the (as I understand it) short name of the
   mount, and we get to say whether we have all the information we
   need to mount it.
*/
static err_t Omni_GetNewMountInfo ( int server_id, char *MountPath,
                                       int *pFlags_out )
{
  const char *flags;
  NAMELIST *pSrv, *pNL;

  (void) MountPath;

  pSrv = Validate(server_id, S_VALID_TAG);

  if ( pSrv == NULL )
    return EBADPARAM;

  for ( pNL = MountsList; pNL != NULL; pNL = pNL->next )
  {
    if ( pNL->u.mount.servername == pSrv )
    {
      /* This server is connected somewhere */
      flags = SMB_GetConnInfo( pNL->u.mount.smb_lettr, GCI_LOGONTYPE );

      if ( flags == NULL ) /* Never heard of it */
        return EBADPARAM;

      if ( flags[0] == GCIF_USERLOGON ) /* Doesn't need userID or passwd */
        *pFlags_out = RC_NEEDS_MOUNTPATH | RC_DOES_FILES;
      else                /* WFWG-type machine */
        *pFlags_out = RC_NEEDS_PASSWD | RC_NEEDS_MOUNTPATH | RC_DOES_FILES;
                          /* Needs password per share attached */

      return OK;
    }
  }

  /* No, we're not connected. Are we logged on ? */
  if ( LM_Vars.logged_on )
  {
    *pFlags_out = RC_NEEDS_MOUNTPATH | RC_DOES_FILES;
  }
  else
  {
    *pFlags_out = RC_NEEDS_USERID | RC_NEEDS_PASSWD | RC_NEEDS_MOUNTPATH |
                RC_DOES_FILES;
  }
  return OK;
}

/* Omni_GetMountInfo() ----------------------------*/
/* Gets info about an existing mount */
err_t Omni_GetMountInfo ( int mount_id, const char **pServName,
     const char **pUserName, const char **pMountName, const char **pMountPath, int *pServerID )
{
  char smbletter;
  NAMELIST *pNL = Validate(mount_id, (int)M_VALID_TAG);

  if ( pNL == NULL )
    return EBADPARAM;

  *pMountName = pNL->name;
  *pServerID = (int) (pNL->u.mount.servername);

  smbletter = pNL->u.mount.smb_lettr;

  *pServName = SMB_GetConnInfo ( smbletter, GCI_SERVER );
  *pUserName = SMB_GetConnInfo ( smbletter, GCI_USER );
  *pMountPath = SMB_GetConnInfo ( smbletter, GCI_SHARE );

  return OK;
}

/* Exported functions ============================================== */

static bool Omni_Registered = false;

/* Omni_GetDrvLetter() ----------------------------*/
/* Gets an SMB drive letter given a mount name.
   Returns 0 if not found. 'Name' should be not contain
   spaces or invalid chars, otherwise it won't be found.
*/
char Omni_GetDrvLetter ( char *name )
{
  NAMELIST *pNL = FindInList ( MountsList, name );

  if ( pNL != NULL )
    return pNL->u.mount.smb_lettr;

  return 0;
}


/* Omni_GetMountID() ------------------------------*/
/* This should be used when the mount name is from dodgy
   sources, as it will do 'MountNameCpy' processing on it first.
*/
int Omni_GetMountID ( char *name )
{
  char lclname[NAME_LIMIT];
  MountNameCpy(lclname, name);
  return (int) FindInList(MountsList, lclname);
}

/* Omni_GetDefaultType() --------------------------*/
/* Attempts to ask OmniFiler for the type for a given file name */
err_t Omni_GetDefaultType ( char *name, int * pType_out )
{
  _kernel_swi_regs R;
  _kernel_oserror *pE;

  char tmpbuf  [NAME_LIMIT];
  char tmpbuf2 [NAME_LIMIT];

  if ( !Omni_Registered )
    return ENOTPRESENT;

  R.r[0] = LanMan_OmniOp; /* Client ID */
  R.r[1] = (int) name;
  R.r[2] = (int) tmpbuf;  /* We ignore the name it returns! */
  R.r[3] = (int) tmpbuf2; /* Flags string */
  pE = _kernel_swi ( SWI_Omni_ConvertClientToAcorn, &R, &R );
  if ( pE != NULL )
    return ENOTPRESENT;

  if ( R.r[0] < 0 )
    return ENOTPRESENT;

  *pType_out = R.r[0];
  return OK;
}

/* OmniOp_SWI() -----------------------------------*/
/* Provides the LanMan_OmniOp SWI handler */
_kernel_oserror *OmniOp_SWI ( _kernel_swi_regs *R )
{
  err_t res;

  debug1(" Omni Op(%d):", R->r[0]);

#define Rin_int(a)   (R->r[a])
#define Rout_int(a) &(R->r[a])
#define Rin_chr(a)   (char *)(R->r[a])
#define Rout_chr(a)  (const char **)&(R->r[a])

  switch ( R->r[0] )
  {
    case 0:  /* Mount */
      res = Omni_MountServer ( Rin_chr(1),
                               Rin_chr(2),
                               Rin_chr(3),
                               Rin_chr(4),
                               Rin_chr(5),
                               Rout_int(1) );
      break;

    case 1:  /* Dismount */
      res = Omni_DismountServer ( Rin_int(1) );
      break;

    case 2:  /* Freespace */
      res = Omni_FreeSpace ( Rin_int(1),
                             Rout_int(1), Rout_int(2), Rout_int(3) );
      break;

    case 3:  /* Enumerate servers */
      res = Omni_ListServers ( Rin_chr(1),
                               Rin_int(2),
                               Rin_int(3),
                               Rout_chr(1),
                               Rout_int(3) );
      break;

    case 4:  /* Enumerate mounts */
      res = Omni_ListMounts  ( Rin_chr(1),
                               Rin_int(2),
                               Rin_int(3),
                               Rin_int(4),
                               Rin_chr(5),
                               Rout_chr(1),
                               Rout_int(3) );
      break;

    case 5:  /* Enumerate active mounts */
      res = Omni_ListActiveMounts  ( Rin_chr(1),
                               Rin_int(2),
                               Rin_int(3),
                               Rout_chr(1),
                               Rout_int(3) );
      break;

    case 6:  /* Open root of mount */
      res = Omni_OpenRoot ( Rin_int(1) );
      break;

    case 7:  /* Open user root of mount */
      res = Omni_OpenUserRoot ( Rin_int(1) );
      break;

    case 8:  /* Get new mount info */
      res = Omni_GetNewMountInfo ( Rin_int(1),
                                   Rin_chr(2),
                                   Rout_int(1) );
      break;

    case 9:  /* Get active mount info */
      res = Omni_GetMountInfo ( Rin_int(1),
                                Rout_chr(1),
                                Rout_chr(2),
                                Rout_chr(3),
                                Rout_chr(4),
                                Rout_int(6) );
      R->r[5] = (int)""; /* Auth server */
      break;

    case 10: /* Create print job */
      res = Prn_CreateJob ( Rin_chr(1),  /* Server name */
                            Rin_chr(2),  /* Printer name */
                            Rin_chr(3),  /* User name */
                            Rin_chr(4),  /* Password */
                            Rout_int(1)); /* Job handle */
      break;

    case 11: /* Send to print job */
      res = Prn_WriteData ( Rin_int(1), /* Job ID */
                            Rin_chr(2), /* data pointer */
                            Rin_int(3) ); /* Data length */

      if ( res == OK ) R->r[3] = 0;
      break;

    case 12: /* End print job */
      res = Prn_CloseJob ( Rin_int(1), /* Job ID */
                           false );
      break;

    case 13: /* Abort print job */
      res = Prn_CloseJob ( Rin_int(1), /* Job ID */
                           true );
      break;

    case 14: /* Get print job info */
      res = Prn_GetJobStatus ( Rin_int(1), /* Job ID */
                (struct JobStatus *) &(R->r[1]) );
                /* Fill in R1 through R6 */
      break;


    case 15: /* Clear print job */
      res = Prn_ClearJob ( Rin_int(1) ); /* Job ID */
      break;

    case 16: /* Enumerate printers */
      res = Omni_ListPrinters ( Rin_chr(1),
                                Rin_int(2),
                                Rin_int(3),
                                Rout_chr(1),
                                Rout_int(3) );
      break;

    default:
      res = ENOTPRESENT;
  }

  return MsgError(res);
}

/* Omni_FreeOp_SWI() ------------------------------*/
/* This is not strictly OmniClient. Instead it is for use by
   the Free module. On exit, set R1 to 0 if we want the Z
   bit set on return.
*/
static char *ExtractName ( char * s )
{
  char *p = strrchr(s, ':');   /* Finds last ':' in name */
  if ( p != NULL )
    return p+1;
  else
    return s;
}

_kernel_oserror *Omni_FreeOp_SWI (_kernel_swi_regs *R )
{
  switch ( R->r[0] )
  {
    case 0:  /* Bizarre no-op */
      return NULL;

    case 1: /* Get Device Name */
      /* On entry R->r[3] points to a "device name/id" string
         It seems we have to return a copy of the device name.
         As I don't know what this is supposed to be for, I'm
         just going to copy the name. */
      {
        char *s = (char *)(R->r[3]);
        char *d = (char *)(R->r[2]);
        sprintf ( d, FilingSystemName "::%s", s );
        R->r[0] = strlen(d) + 1 /* Terminator */;
        return NULL;
      }

    case 2:   /* Get free space on device */
      /* R->r[3] on entry points to a device name.
         Methinks this is the same as returned from
         case 1 */
      {
        int m_id = Omni_GetMountID ( ExtractName( (char *)(R->r[3]) ));
        if ( m_id == 0 )
          return MsgError(EBADDRV);

        return MsgError ( Omni_FreeSpace ( m_id,
           (int *)(R->r[2]+4) /* freespace_out */,
           (int *)(R->r[2]+8) /* usedspace_out */,
           (int *)(R->r[2])   /* totspace_out */ ) );
      }

    case 3:   /* Compare device */
      /* I think we're given a file name & have to work out
         if it's on our device. Return R->r[1] = 1 if not, R->r[1] = 0
         if so. */
      {
        char *s, *d;
        R->r[1] = 1;  /* Assume failure */

        s = ExtractName( (char *)(R->r[2]) ); /* File name */
        d = ExtractName( (char *)(R->r[3]) ); /* Our device name */

        while ( toupper(*s) == toupper(*d) ) s++, d++;

        if ( *d == 0 && (*s == 0 || *s == '.') )
          R->r[1] = 0;

        return NULL;
      }

    case 4:   /* Get free space on device (64 bit) */
      /* R->r[3] on entry points to a device name.
         Methinks this is the same as returned from
         case 1 */
      /* This code can be entered directly by Cmd_FREE */
      {
        int m_id = Omni_GetMountID ( ExtractName( (char *)(R->r[3]) ));
        if ( m_id == 0 )
          return MsgError(EBADDRV);

        return MsgError ( Omni_FreeSpace64 ( m_id,
           (int *)&(R->r[0]),       /* zero it on success */
           (QWORD *)(R->r[2]+8)  /* freespace_out */,
           (QWORD *)(R->r[2]+16) /* usedspace_out */,
           (QWORD *)(R->r[2]+0)  /* totspace_out */ ) );
      }

    default:
      break;
  }

  return MsgError(EBADPARAM);
}

/* Omni_RecheckInfo() -----------------------------*/
/* This is called after *Commands or other actions which
   might change the available mounts or network information.
   It basically calls Omni_EnumerateMounts.
*/
void Omni_RecheckInfo( int flags )
{
  _kernel_swi_regs R;

  if ( Omni_Registered )
  {
    R.r[0] = LanMan_OmniOp; /* Client ID */
    R.r[1] = flags;  /* Enumerate servers/mounts */;
    _kernel_swi ( SWI_Omni_EnumerateMounts, &R, &R );
  }
}

/* Omni_Register() --------------------------------*/
static void Omni_Register(void)
{
  char titlebar[24];  /* Title bar - 24 max */
  char infobox[3*32]; /* Info box - 3x32 max */

  strcpy( titlebar, MsgLookup("_Version") ); /* Temp copy */
  sprintf( infobox, "%s\n"
                    "\xA9 Acorn Computers Ltd, 1997\n"
                    "%s",
                    ( Stat_ClassMask & SCLASS_IP ) ? MsgLookup("WhoTCPIP")
                                                   : MsgLookup("WhoBEUI"),
                    titlebar );
  strncpy( titlebar, MsgLookup("DispName"), sizeof(titlebar) );

  if ( _swix( SWI_Omni_RegisterClient, _INR(0,6),
              LanMan_OmniOp, /* Client ID */
              RC_NEEDS_USERID | RC_NEEDS_PASSWD | RC_NEEDS_MOUNTPATH |
              RC_DOES_FILES | RC_EXTN_CHAR('.') |
              RC_DOES_PRINT | RC_NEEDS_PRINTPWD,
              "lmicon", /* Sprite name - 12 max */
              titlebar, /* Title bar - 24 max */
              infobox,  /* Info box - 3x32 max */
              0, /* Site ID (ignored) */
              FilingSystemName ) == NULL )
    Omni_Registered = true;
}

/* Omni_Free_Register() ---------------------------*/
static void Omni_Free_Register(bool OnNotOff)
{
  _kernel_swi_regs R;

  R.r[0] = Our_FS_Number;
  R.r[1] = (int) Free_ServiceRoutine;  /* Exported by s.Interface */
  R.r[2] = 0;  /* R12 value, don't care */

  if ( OnNotOff )
    _kernel_swi ( Free_Register, &R, &R );
  else
    _kernel_swi ( Free_DeRegister, &R, &R );
}

/* Omni_StartUp() ---------------------------------*/
/* Attempts to register us with OmniFiler and the
   Free module. Called when the module loads.
*/
void Omni_StartUp ( void )
{
  if ( !Omni_Registered )
    Omni_Register();

  Omni_Free_Register(true);
}

/* Omni_Shutdown() --------------------------------*/
/* This is called if we're about to die.
   If so, we should deregister ourselves with OmniFiler, and
   free any alloc'd memory.
*/
void Omni_Shutdown ( void )
{
  _kernel_swi_regs R;

  /* Free memory */

  FreeAllLists();
  ServerList = NULL;
  MountsList = NULL;

  /* De-register if we're registered */

  if ( Omni_Registered )
  {
    R.r[0] = LanMan_OmniOp;
    _kernel_swi ( SWI_Omni_DeregisterClient, &R, &R );
    Omni_Registered = false;
  }

  Omni_Free_Register(false);
}

/* Omni_ClearLists() ------------------------------*/
/* This is called when a *LMLOGOFF or similar is done,
   and deletes all servers which we don't currently have
   a connection to */
void Omni_ClearLists ( void )
{
  NAMELIST *pNLsrv, *pNLdisk, *pNLtmp;

  pNLsrv = ServerList;
  while ( pNLsrv != NULL )
  {
    /* Free disks that aren't in use */

    pNLdisk = pNLsrv->u.server.known_disks;
    while ( pNLdisk != NULL )
    {
      if ( FindActiveMount ( pNLdisk ) == NULL )
      {
        pNLtmp = pNLdisk->next;
        DeleteFromList ( &pNLsrv->u.server.known_disks, pNLdisk );
        pNLdisk = pNLtmp;
      }
      else
        pNLdisk = pNLdisk->next;
    }

    /* Free printers from list (keep deleting them 'til they don't
       come back) */
    while ( pNLsrv->u.server.known_printers != NULL )
      DeleteFromList ( &(pNLsrv->u.server.known_printers),
                         pNLsrv->u.server.known_printers );

    while ( pNLsrv->u.server.known_ipc != NULL )
      DeleteFromList ( &(pNLsrv->u.server.known_ipc),
                         pNLsrv->u.server.known_ipc );

    while ( pNLsrv->u.server.known_comms != NULL )
      DeleteFromList ( &(pNLsrv->u.server.known_comms),
                         pNLsrv->u.server.known_comms );

    /* If the server has no active mounts left, delete it too */

    if ( pNLsrv->u.server.known_disks == NULL )
    {
      pNLtmp = pNLsrv->next;
      DeleteFromList ( &ServerList, pNLsrv );
      pNLsrv = pNLtmp;
    }
    else
      pNLsrv = pNLsrv->next;
  }

}

/* Omni_ServiceCall() -----------------------------*/
void Omni_ServiceCall ( _kernel_swi_regs *R )
{
  switch ( R->r[0] )
  {
    case 0:  /* OmniFiler is starting up */
      Omni_Register();
      Lgn_Register();
      break;

    case 1: /* Filer is dying. We should do so too */
      Omni_Registered = false;
      OmniS_Suicide("LanManFS");
      break;

    default:
      break;
  }
}

/* Omni_AddInfo()----------------------------------*/
void Omni_AddInfo ( int flags, const char *serv_name, const char *string, const char *comment )
{
  NAMELIST *pNLsrv, **list;
  int tag = 0;

  pNLsrv = AddToList ( &ServerList, S_VALID_TAG, serv_name );
  if ( pNLsrv == NULL )  /* Couldn't add it */
    return;

  switch ( flags )
  {
    case OAI_SERVER:
      /* Amend information about server */
      if ( string != NULL )
        strcpyn ( pNLsrv->u.server.info_string, string, INFO_STR_LEN );
      return;

    case OAI_DISK:
      tag = (int)D_VALID_TAG;
      list = &pNLsrv->u.server.known_disks;
      break;

    case OAI_PRINTER:
      tag = (int)P_VALID_TAG;
      list = &pNLsrv->u.server.known_printers;
      break;

    case OAI_IPC:
      tag = (int)I_VALID_TAG;
      list = &pNLsrv->u.server.known_ipc;
      break;

    case OAI_DEVICE:
      tag = (int)C_VALID_TAG;
      list = &pNLsrv->u.server.known_comms;
      break;

    default:
      return;
  }

  AddToList ( list, tag, string );
  pNLsrv = FindInList(*list, string);
  if (pNLsrv != NULL) {
    if (comment != NULL) {
      strcpyn ( pNLsrv->u.share.info_string, comment, INFO_STR_LEN );
    }
    else {
      pNLsrv->u.share.info_string[0] = '\0';
    }
  }
}

/* Omni_DumpServers() -----------------------------*/
_kernel_oserror *Omni_DumpServers(void)
{
        err_t res;
        int token;
        const char *eptr;
        res = Omni_ListServers(0,0,0,&eptr,&token);
        if (res != OK) return MsgError(res);
        Omni_Debug();
        return NULL;
}

/* Omni_DumpSharesPrint() -------------------------*/
static void Omni_DumpSharesPrint(NAMELIST *pNL, const char *type)
{
  for (; pNL != NULL; pNL = pNL->next) {
    printf("  %-16s  %-10s  %s\n", pNL->name, type, pNL->u.share.info_string);
  }
}

/* Omni_DumpServersPrint() ------------------------*/
static void Omni_DumpServersPrint(NAMELIST *pNL)
{
  for (; pNL != NULL; pNL = pNL->next) {
    printf("  %-16s  %s\n", pNL->name, pNL->u.server.info_string);
  }
}

/* Omni_DumpShares() ------------------------------*/
_kernel_oserror *Omni_DumpShares(char *server_name)
{
        err_t res;
        int token;
        char heading[2+16/* Name */+2+10/* Type */+2+16/* Notes */+1/* Term */];
        char *score;
        const char *eptr;
        NAMELIST *pserv;

        /* Don't give a XXXX about getting the info back - just force the RPC
         * call to execute and stuff all the data into the data structures and
         * we'll go through the data structures ourselves, tvm.
         */
        res = Omni_ListMounts(0, 0, 0, 0, server_name, &eptr, &token);
        if (res != OK) return MsgError(res);

        pserv = FindInList(ServerList, server_name);
        if (pserv != NULL && pserv->tag == S_VALID_TAG) {
                /* Keep in sync with Omni_DumpSharesPrint() spacing */
                sprintf(heading, "  %s", MsgLookup("HdrShares"));
                printf("%s\n", heading);
                score = heading; /* Replace text with underscore */
                while (*score) {
                  if (*score != ' ') *score = '-';
                  score++;
                }
                printf("%s\n", heading);

                Omni_DumpSharesPrint(pserv->u.server.known_disks, MsgLookup("Type0"));
                Omni_DumpSharesPrint(pserv->u.server.known_printers, MsgLookup("Type1"));
                Omni_DumpSharesPrint(pserv->u.server.known_ipc, MsgLookup("Type3"));
                Omni_DumpSharesPrint(pserv->u.server.known_comms, MsgLookup("Type2"));

                /* Keep in sync with Omni_DumpServersPrint() spacing */
                sprintf(heading, "  %s", MsgLookup("HdrServrs"));
                printf("\n%s\n", heading);
                score = heading; /* Replace text with underscore */
                while (*score) {
                  if (*score != ' ') *score = '-';
                  score++;
                }
                printf("%s\n", heading);

                Omni_DumpServersPrint(ServerList);
        }
        return NULL;
}

/* Omni_Debug() -----------------------------------*/
static void showname ( NAMELIST *pNL )
{
  if ( pNL == NULL )
    printf("%s ", MsgLookup("NoUser"));
  else
    printf("'%s' ", pNL->name);
}

static void showlist ( NAMELIST *pNL )
{
  while (1)
  {
    showname( pNL ); /* Show something if pNL is NULL on entry */
    if (pNL == NULL) break;
    pNL = pNL->next;
    if (pNL == NULL) break;
  }
}

void Omni_Debug ( void )
{
  NAMELIST *pNL;
  char fmt[12];
  char temp[20];

  sprintf(fmt, "%%-%ds : %%s\n", strlen(MsgLookup("NameL")));

  printf(fmt, MsgLookup("NameH"), LM_Vars.machinename);
  printf(fmt, MsgLookup("NameD"), LM_Vars.drivername);
  sprintf(temp, "%d", LM_Vars.namemode);
  printf(fmt, MsgLookup("NameM"), temp);
  strcpy(temp, Omni_Registered ? MsgLookup("Start")
                               : MsgLookup("NotStart"));
  printf(fmt, MsgLookup("NameO"), temp);
  strcpy(temp, LM_Vars.logged_on ? LM_Vars.workgroup
                                 : MsgLookup("NotLogon"));  
  printf(fmt, MsgLookup("NameW"), temp);

  if ( LM_Vars.logged_on )
  {
    /* Extra info for a logged on domain */
    printf(fmt, MsgLookup("NameU"), LM_Vars.username);

    if ( Lgn_PrimaryDCName[0] != 0 )
    {
      printf(fmt, MsgLookup("NameP"), Lgn_PrimaryDCName);
    }

    strcpy(temp, MsgLookup("NoHome"));
    printf(fmt, MsgLookup("NamHD"), (Lgn_HomeDirName[0] != 0) ? Lgn_HomeShareName
                                                              : temp);
    if ( Lgn_HomeDirName[0] != 0 )
    {
      printf(fmt, MsgLookup("NamHS"), Lgn_HomeServerName);
      printf(fmt, MsgLookup("NamHP"), Lgn_HomeDirName);
    }
  }

  for ( pNL = ServerList; pNL != NULL; pNL = pNL->next )
  {
    printf("\n%s '%s': '%s'", MsgLookup("Serv"), pNL->name,
           pNL->u.server.info_string);
    printf("\n  %s : ", MsgLookup("Drvs"));
    showlist(pNL->u.server.known_disks);
    printf("\n  %s : ", MsgLookup("Prns"));
    showlist(pNL->u.server.known_printers);
  }
  if (ServerList != NULL) printf("\n");

  for ( pNL = MountsList; pNL != NULL; pNL = pNL->next )
  {
    printf("\n%s '%s': ", MsgLookup("Mnt"), pNL->name);
    showname( pNL->u.mount.diskname );
    printf("%s ", MsgLookup("On"));
    showname( pNL->u.mount.servername );
    printf("%s '%s'",
            MsgLookup("User"),
            SMB_GetConnInfo ( pNL->u.mount.smb_lettr, GCI_USER ) );
  }
  if (MountsList != NULL) printf("\n");

#ifdef DEBUG
  {
    int i;

    printf("\n");
    for ( i='A'; i <= 'Z'; i++ )
      if ( SMB_GetConnInfo(i, GCI_SERVER) != NULL )
      {
        printf("Connection %c: %s share on \\\\%s\\%s, user %s\n",
          i, SMB_GetConnInfo(i, GCI_SHARETYPE),
             SMB_GetConnInfo(i, GCI_SERVER),
             SMB_GetConnInfo(i, GCI_SHARE),
             SMB_GetConnInfo(i, GCI_USER) );
      }
  }
#endif

  if ( RPC_ErrorCount > 0 )
  {
    printf("\n%d %s\n", RPC_ErrorCount, MsgLookup("LocProb"));
    printf("%s - %s\n", MsgLookup("LocDesc"), RPC_DebugMsg);
  }
}
