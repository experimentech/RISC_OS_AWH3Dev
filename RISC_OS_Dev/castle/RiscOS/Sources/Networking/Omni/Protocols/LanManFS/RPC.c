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
*
*  RPC.C  -- Remote procedure call routines for
*              interrogating servers
*
*  02-02-95 INH  Original
*  	    	 Added Transact SWI interface
*  25-07-96      Added GetUserHomeDir
*/

#define OMIT_UNUSED_FNS

/* Standard includes */

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <ctype.h>
#include "kernel.h"

/* Our includes */

#include "stdtypes.h"
#include "LanMan.h"
#include "BufLib.h"
#include "NetBIOS.h"
#include "SMB.h"
#include "Xlate.h"  /* For string functions */
#include "Omni.h"
#include "LMVars.h"
#include "RPC.h"

/* Globals ---------------------------- */

char RPC_DebugMsg[100];
int  RPC_ErrorCount=0;

/* Debug routine */

typedef enum
{
  DE_ENUMSHARESNOLOGON = 0,
  DE_ENUMSHARESCALLTO,
  DE_NOMASTERBROWSER,
  DE_ENUMSERVERSNOLOGON,
  DE_ENUMSERVERSCALLTO,
  DE_LOGONUSERNOCONN,
  DE_NETGETUSERINFO
} debug_errs_t;

static err_t debug_err ( err_t res, debug_errs_t token, char *name )
{
  char text[100];

  if ( res != OK )
  {
    sprintf(text, "D%02u", token);
    strcpy(text, MsgLookup(text));
    strcat(text, ": %s"); /* Append the error */
    RPC_ErrorCount++;
    sprintf( RPC_DebugMsg, text, name, MsgError(res)->errmess );
  }
  return res;
}

/* Parameter-assembly subroutines -------------------- */

static struct TransactParms TP;

/* ---------- */

static void addword ( int value )
{
  BYTE *p = TP.parms_in + TP.parms_in_len;
  p[0] = (value & 0xFF);
  p[1] = (value >> 8 );
  TP.parms_in_len+=2;
}

/* ---------- */

static void addlong ( int value )
{
  BYTE *p = TP.parms_in + TP.parms_in_len;
  p[0] = (value & 0xFF);
  p[1] = (value >> 8 );
  p[2] = (value >> 16 );
  p[3] = (value >> 24 );
  TP.parms_in_len+=4;
}

/* ---------- */

static void addstring ( char *str )
{
  BYTE *p = TP.parms_in + TP.parms_in_len;
  int l = strlen(str)+1;
  memcpy ( p, str, l );
  TP.parms_in_len += l;
}

/* ---------- */

static void StartParams ( int func_code, char *in_format, char *out_format,
                           int ret_param_len )
{
  TP.parms_in = SMB_WorkBuf;
  TP.parms_in_len = 0;
  TP.data_in = NULL;
  TP.data_in_len = 0;

  TP.parms_out_buf = SMB_WorkBuf;
  TP.parms_out_maxlen = min(ret_param_len, SMBWORKBUF_SIZE);
  TP.data_out_buf  = SMB_WorkBuf + TP.parms_out_maxlen;
  TP.data_out_maxlen = SMBWORKBUF_SIZE-TP.parms_out_maxlen;

  addword ( func_code );
  addstring ( in_format );
  addstring ( out_format );
}

/* Parameter-return subroutines ====================== */

static int getword ( BYTE *p )
{
  return ( p[0] + (p[1] << 8));
}

/* ----------------- */
#if 0
static int getlong ( BYTE *p )
{
  return ( p[0] + (p[1] << 8) + (p[2] << 16)+ (p[3] << 24));
}
#endif

/* ----------------- */

static BYTE *getpointer ( BYTE *p )
{
  int ptrval;

  ptrval = getword(p) + TP.data_out_len - TP.data_out_maxlen;
  if ( ptrval <= 0 || ptrval >= TP.data_out_len )
    return NULL;

  return TP.data_out_buf + ptrval;
}

/* ============================================ */

static bool check_hidden ( char *name )
{
  while ( *name != 0 )
  {
    if ( name[0] == '$' && name[1] == 0 )
      return false;  /* Name is hidden */
    name++;
  }
  return true;
}

/* ---------------------------- */

static err_t RPC_EnumSharesOnConnection ( char drv, char *server )
{
  BYTE *p;
  int i, co;
  err_t res;

  /* Assemble parameters for RPC call */

  StartParams( 0x0000, "WrLeh", "B13BWz", 8 ); /* NetShareEnum */
  addword (0x0001);  /* Detail level */
  addword (TP.data_out_maxlen); /* Return buf size */

  /* Make call */

  res = SMB_Transact ( drv, "\\PIPE\\LANMAN", &TP );
  if ( res != OK )
    return res;

  if ( TP.parms_out_len < 8 )
    return EDATALEN;

  /* Decode returned params */
  p = TP.parms_out_buf;

  if ( getword(p) != 0 )   /* API return code; 0 = success */
    return ERPCERROR;            /* Otherwise, call it 'generic' error */

  co = getword(p+2);  /* Comment offset adjustment - ( why?? ) */

  i = getword(p+4);        /* Number of records returned */
  if ( i*20 > TP.data_out_len )  /* Silly values! */
    return EDATALEN;

  /* Process returned records */

  p = TP.data_out_buf;

  while ( i-- > 0 )
  {
    /* p is the start of the record. The first 13 bytes
       are a share name + null termination. If the share name
       ends in '$', it is hidden and should not be listed.
       [sbrodie: ... except if it's an IPC share, I've decided.  Also
       we store the comments too for *lanman:listfs to display.  Why is there
       a mystical word in the returned param block which is subtracted from
       the offset field? Dunno, but SAMBA does it and Windows 98 needs it.]
    */
    int shrtype = getword(p+14);
    int commoffset = getword(p+16);
    char *comment = commoffset ? ((char *) TP.data_out_buf + commoffset - co) : 0;

    if ( shrtype == SHR_IPC || check_hidden( (char *)p) )
    {
      if ( shrtype == SHR_DISK )
        Omni_AddInfo ( OAI_DISK, server, (char *)p, comment );
      else if ( shrtype == SHR_PRINTER )
        Omni_AddInfo ( OAI_PRINTER, server, (char *)p, comment );
      else if ( shrtype == SHR_IPC )
        Omni_AddInfo ( OAI_IPC, server, (char *)p, comment );
      else if ( shrtype == SHR_COMM )
        Omni_AddInfo ( OAI_DEVICE, server, (char *)p, comment );
    }
    p += 20;
  }

  return OK;
}

/* ---------------------------- */

static err_t RPC_EnumServersOnConnection ( char drv, char *domain )
{
  err_t res;
  BYTE *p;
  int co;
  int i;

  /* NetServerEnum2 */
  StartParams ( 0x0068, "WrLehDz", "B16BBDz", 8 );
  addword (0x0001);  /* Detail level */
  addword (TP.data_out_maxlen); /* Return buf size */
  addlong ((int)0xFFFFFFFF); /* Return all server types */
  addstring ( domain ); /* Domain name */

  /* Make call */

  res = SMB_Transact ( drv, "\\PIPE\\LANMAN", &TP );
  if ( res != OK )
    return res;

  if ( TP.parms_out_len < 8 )
    return EDATALEN;

  /* Decode returned params */
  p = TP.parms_out_buf;

  if ( getword(p) != 0 )   /* API return code; 0 = success */
    return ERPCERROR;

  co = getword(p+2);

  i = getword(p+4);        /* Number of records returned */
  if ( i*26 > TP.data_out_len )  /* Silly values! */
    return EDATALEN;

  /* Process returned records */

  p = TP.data_out_buf;

  while ( i-- > 0 )
  {
    /* p is the start of the record. The first 16 bytes
       are a server name + null termination.
    */
    int commoffset = getword(p+22);
    char *comment = commoffset ? ((char *) TP.data_out_buf + commoffset - co) : 0;

    Omni_AddInfo ( OAI_SERVER, (char *)p, comment, NULL );
    p += 26;
  }

  return OK;
}

/* ---------------------------- */

err_t RPC_EnumerateShares ( char *server  )
{
  char  drv;                /* Connection identifier */
  err_t res;

  /* (i) Connect to IPC share */

  res = SMB_CreateShare ( SHR_IPC, CREATE_NORMAL,
                            server, "IPC$", NULL, NULL, &drv );

  if ( res != OK )
    return debug_err( res, DE_ENUMSHARESNOLOGON, server );

  Omni_AddInfo ( OAI_SERVER, server, SMB_GetConnInfo(drv, GCI_SERVERINFO), NULL );

  res = RPC_EnumSharesOnConnection ( drv, server );

  SMB_DeleteShare ( drv );
  return debug_err( res, DE_ENUMSHARESCALLTO, server );
}


/* ---------------------------------------- */

static char *GetMasterBrowser (char *wg_name)
{
  NETNAME MBname;
  struct FindName_res fnr;
  static char namebuf[16];

  NB_FormatName ( ntMBROWSER, wg_name, &MBname );

  /* Have a 1.5-sec timeout */
  if ( NB_FindNames ( &MBname, ntSERVER, &fnr, 1, 150 ) == 0)
    return NULL;

  NB_DecodeName ( &(fnr.name), namebuf );
  return namebuf;
}

/* ---------------------------------------- */

char *RPC_GetDomainController (char *domain_name)
{
  NETNAME DCname;
  struct FindName_res fnr;
  static char namebuf[16];

  NB_FormatName ( ntPRIMARYDC, domain_name, &DCname );

  /* Have quick 1.5-sec timeout */
  if ( NB_FindNames ( &DCname, ntSERVER, &fnr, 1, 150 ) == 0)
    return NULL;

  NB_DecodeName ( &(fnr.name), namebuf );
  return namebuf;
}


/* ---------------------------- */


err_t RPC_EnumerateServers ( char *workgroup )
{
  char  drv;                /* Connection identifier */
  err_t res;
  char *server;

  /* (i) Connect to IPC share */

  server = GetMasterBrowser ( workgroup );

  if ( server == NULL )
    server = RPC_GetDomainController ( workgroup );

  if ( server == NULL )
    return debug_err( ECANTFINDNAME, DE_NOMASTERBROWSER, workgroup);

  res = SMB_CreateShare ( SHR_IPC, CREATE_NORMAL,
               server, "IPC$", NULL, NULL, &drv );

  if ( res != OK )
    return debug_err( res, DE_ENUMSERVERSNOLOGON, server );

  res = RPC_EnumServersOnConnection ( drv, workgroup );

  SMB_DeleteShare ( drv );
  return debug_err( res, DE_ENUMSERVERSCALLTO, server );
}

/* ---------------------------- */

err_t RPC_LogonUser ( char *server, char *user, char *password,
                         char **pHomeDir )
{
  err_t res;
  char drv;

  /* Trying to connect to the IPC share is as good a method of
     password validation as any */

  res = SMB_CreateShare ( SHR_IPC, CREATE_NEW_USER,
               server, "IPC$", user, password, &drv );

  if ( res != OK )
    return debug_err(res, DE_LOGONUSERNOCONN, user );

  /* NetUserGetInfo */
  StartParams ( 0x0038, "zWrLh",
               "B21BzzzWDDzzDDWWzWzDWb21W", 6 );

  addstring (user);
  addword (11);  /* Detail level */
  addword (TP.data_out_maxlen); /* Return buf size */

  /* Make call */

  res = SMB_Transact ( drv, "\\PIPE\\LANMAN", &TP );

  if ( res == OK )
  {
    if ( TP.parms_out_len < 6 )
      res = EDATALEN;
    else
    {
      switch ( getword ( TP.parms_out_buf ) ) /* return code */
      {
        case 0:
          *pHomeDir = (char *)getpointer( TP.data_out_buf+44 );
          res = OK;
          break;
        case 5: case 65: /* Access denied */
          res = ENOACCESS;
          break;
        case 2221: /* User not found */
          res = EUSERUNKNOWN;
          break;
        case 2239: /* Account disabled */
          res = EACCDISABLED;
          break;
        default:
          res = ERPCERROR;
          break;
      }
    }
  }

  SMB_DeleteShare ( drv );

  return debug_err(res, DE_NETGETUSERINFO, user );
}


/* ---------------------------- */

err_t RPC_NameOp ( int reason, char *name_in, char *buf_out )
{
  char *s;
  /* We assume buf_out can hold a 16-character name including last 0 */

  switch ( reason )
  {
    case NAMEOP_GETLOCAL:
      s = LM_Vars.machinename;
      break;

    case NAMEOP_GETWG:
      s = LM_Vars.workgroup;
      break;

    case NAMEOP_GETBROWSER:
      if ( name_in == NULL ) name_in = LM_Vars.workgroup;

      s = GetMasterBrowser ( name_in );
      if ( s == NULL )
        return ECANTFINDNAME;
      break;

    case NAMEOP_GETDC:
      if ( name_in == NULL ) name_in = LM_Vars.workgroup;

      s = RPC_GetDomainController ( name_in );
      if ( s == NULL )
        return ECANTFINDNAME;
      break;

    default:
      return EBADPARAM;
  }

  strcpy ( buf_out, s );
  return OK;
}

/* ------------------------- */

err_t RPC_Transact ( char *servername, char *pipename, void *pvParmBlk )
{
  char drv;
  err_t res;
  struct TransactParms t;

  /* Connect to IPC share using default user ID/password */

  res = SMB_CreateShare ( SHR_IPC, CREATE_NORMAL,
                            servername, "IPC$", NULL, NULL, &drv );

  if ( res != OK )
    return res;

  memcpy(&t, pvParmBlk, sizeof_TransactParms_external);
#ifdef LONGNAMES
  t.setup_in_len = 0;
  t.setup_out_maxlen = 0;
#endif
  res = SMB_Transact ( drv, pipename, &t );
  SMB_DeleteShare ( drv );
  return res;
}

/* ------------------------- */

bool RPC_Init ( void )
{
  RPC_ErrorCount = 0;
  RPC_DebugMsg[0] = 0;
  return true;
}


