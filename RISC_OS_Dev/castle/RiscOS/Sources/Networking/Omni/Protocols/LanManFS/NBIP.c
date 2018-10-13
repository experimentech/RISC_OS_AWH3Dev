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
*  NBIP.C  -- NetBIOS-over-IP implementation
*
*  13-12-95 INH  Original
*  30-12-96 INH  Completed
*
*
*  This file is an implementation of the name service and session
*  service functions for a B (broadcast) node, as defined in
*  RFC1001-1002. It does the following things:
*
*   - locates remote NetBIOS names (i.e. finds IP addresses for them)
*   - maintains & defends local NetBIOS names
*   - establishes sessions with remote hosts & sends & receives data
*      using these sessions.
*
*  We also do a few M-node functions, if a name server is specified
*   by giving its IP address in LanMan$NameServer. This consists
*   largely of sending name registrations, releases, find requests
*   and status requests to the name server as well as to broadcast.
*/

/* Standard includes */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "kernel.h"
#include "os.h"
#include "swis.h"
#include "AsmUtils/callbacks.h"

/* Our includes */

#include "stdtypes.h"
#include "LanMan.h"
#include "BufLib.h"
#include "TCPIP.h"
#include "NetBIOS.h"
#include "Xlate.h"    /* For string functions */
#include "Stats.h"
#include "LMVars.h"
#include "NBIP.h"
#include "LanMan_MH.h"

#define EXPORT static

/* Our definitions ------------------ */

#define EventV         0x10

#define INVALID_SOCKET (-1)

#define MAX_NAMES     (MAX_DRIVES+4)
#define MAX_SESSIONS  (MAX_DRIVES+4)

#define RECV_TIMEOUT  3000 /* Wait time for general receives, in .01s */

/* Time to live values */
#define FIND_TTL     300000
#define REGISTER_TTL 300000


/* Definitions for status field */

#define NAME_FREE       0
#define LCL_AWAIT_ADD   1  /* Local name awaiting registration */
#define LCL_NAME_OK     2  /* Valid local name */
#define LCL_IN_CONFLICT 3  /* Local name in conflict */
#define LCL_AWAIT_RLSE  4  /* Local name about to be released */
#define RMT_AWAIT_FIND  5  /* Remote name currently being searched for */
#define RMT_FOUND       6  /* Remote name, found OK */
#define RMT_CACHED      7  /* Remote name which may be dropped from table */
#define RMT_STATUS_Q    8  /* Remote name doing a status query */

/* ---------------- */

struct status_resp  /* Structure used to process STATUS_RESPONSE */
{
  int    nt_search;           /* Name-type to respond to */
  struct FindName_res *pRes;  /* Pointer to result buf */
  int    spaces_left;         /* Space left in result buf */
};

/* ----------- */

/* We keep both our own names and some remote names in the table,
   to act as a name-to-IP-address cache. Remote names can (and will)
   be chucked out without warning.
*/

typedef struct
{
  int status;

  NETNAME nn;    /* 16-byte NetBIOS name */
  int nbflags;  /* Group status & node type */

  uint TTL_StartTime;  /* Time at which a valid 'time to live' was
       		       	    received */
  uint TTL_Interval;   /* Time to live, in centiseconds */

  struct in_addr IPaddress; /* IP address of this name */
  struct status_resp *pStatResp;  /* Pointer to result buf */
}
  NAME_ENTRY;

/* ----------- */


/* Globals ============================================================= */

static NAME_ENTRY NB_NameTable[MAX_NAMES];
static int        NB_FirstFreeName;
static struct in_addr NB_IPAddress;

#define SCOPE_ID_MAX 80
static BYTE   NB_ScopeID[SCOPE_ID_MAX];
                          /* NetBIOS Scope ID, in compressed format */
static int    NB_ScopeIDlen; /* Length, including terminating zero */

static BYTE   DatagramBuf[576];
static int    NBNS_Socket = INVALID_SOCKET;
                      /* Socket for NBNS server on this machine */
static int    NBNS_RequestCount;

static struct sockaddr *NBNS_Broadcast; /* Ready-made broadcast address */
static struct sockaddr *NBNS_NameServer = NULL; /* IP address of name server */

/* NetBIOS name basics ==================================== */

#ifdef DEBUG
static char *debug_name_buf ( void *pnn_v, char *buf )
{
  BYTE *pnn = pnn_v;
  char lbuf[16];
  memcpy(lbuf, pnn, 16);
  lbuf[15] = '\0';
  sprintf(buf, "<%s[%02X]>", lbuf, pnn[15]);
  return buf;
}

static char *debug_name ( void *pnn )
{
  static char lclbuf[32];
  return debug_name_buf(pnn, lclbuf);
}

static void debug_scope ( BYTE *src )
{
  int i;

  if ( *src == 0 )
    return;

  while ( *src != 0 )
  {
    i = *src;
    if ( i >= 0xC0 )
    {
      printf("->pointer");
      break;
    }
    if ( i >= 0x40 )
    {
      printf("->invalid");
      break;
    }
    printf(".");
    src++;
    while ( i-- > 0 ) printf("%c", *src++);
  }
}
#else
#define debug_name(a)
#define debug_scope(a)
#endif

#ifdef DEBUG
static void show_scope ( BYTE *src )
{
  int i;

  if ( *src == 0 )
  {
    printf("  No NetBIOS scope ID set\n");
    return;
  }

  printf("  NetBIOS scope ID is '");
  while ( *src != 0 )
  {
    i = *src;
    if ( i >= 0x40 )
    {
      printf("(oops)");
      break;
    }
    src++;
    while ( i-- > 0 ) printf("%c", *src++);
    if ( *src != 0 ) printf(".");
  }
  printf("'\n");
}
#endif

/* NETNAME management ==================================== */

EXPORT bool _NB_MatchName ( NETNAME *nn1, NETNAME *nn2 )
{
  return (bool) ( nn1->c4[0] == nn2->c4[0] &&
           nn1->c4[1] == nn2->c4[1] &&
           nn1->c4[2] == nn2->c4[2] &&
           nn1->c4[3] == nn2->c4[3] );
}

/* --------------------- */

EXPORT err_t _NB_FormatName ( nametype_t nt, char *name, NETNAME *res )
{
  int i;

  for ( i=0; i<15; i++)
  {
    if ( name[i] <= 0x20 ) break;
    if (name[i] == '\xA0') res->b[i] = ' ';
    else res->b[i] = toupper(name[i]);
  }

  while (i<15)
    res->b[i++] = 0x20;

  res->b[15] = nt;
  return OK;
}

/* --------------------- */

EXPORT nametype_t _NB_DecodeName ( NETNAME *pnn, char *buf )
{
  BYTE *p = pnn->b;
  char *last_nonsp = buf;
  int i;

  for (i=0; i<15 && *p >= 0x20; ++i)
    *buf++ = *p++;

  *buf = 0;

  while (--buf > last_nonsp) {
    if (*buf == ' ') *buf = 0;
  }

  return (nametype_t) (pnn->b[15]);
}

/* -------------------- */

static uint NB_GetTime (void)
{
  uint tick;

  /* Centisecond tick */
  (void) _swix(OS_ReadMonotonicTime, _OUT(0), &tick);
  return tick;
}


/* NAME_ENTRY management ============================= */

static void FreeNameEntry ( NAME_ENTRY *p )
{
  int n;
  p->status = NAME_FREE;
  n = p - NB_NameTable;

  if (NB_FirstFreeName > n)
    NB_FirstFreeName = n;
}

/* ------------------ */

static void CheckExpiredNames ( void )
{
  int i;
  NAME_ENTRY *pNE;

  pNE = NB_NameTable;
  for ( i=0; i < MAX_NAMES; i++ )
  {
    if ( pNE->status == RMT_CACHED              &&
         (NB_GetTime() - pNE->TTL_StartTime) > pNE->TTL_Interval )
    {
      FreeNameEntry(pNE);
    }
  }
}

/* ------------------ */

static NAME_ENTRY *AllocNameEntry (int stat)
{
  int i;

  CheckExpiredNames(); /* Make some space if possible */

  for ( i=NB_FirstFreeName; i < MAX_NAMES; i++)
    if ( NB_NameTable[i].status == NAME_FREE )
    {
      NB_NameTable[i].status = stat;
      NB_FirstFreeName = i+1;
      return &NB_NameTable[i];
    }

  /* No more space. Chuck out the first cached remote name we find */

  for ( i=0; i < MAX_NAMES; i++ )
    if ( NB_NameTable[i].status == RMT_CACHED )
    {
      NB_FirstFreeName = i+1;
      NB_NameTable[i].status = stat;
      return &NB_NameTable[i];
    }

  return NULL;
}

/* --------------- */

static NAME_ENTRY *FindNameEntry ( NETNAME *pNN )
{
  int i;
  NAME_ENTRY *pNE;
  pNE = NB_NameTable;

  for ( i=0; i < MAX_NAMES; i++ )
  {
    if ( pNE->status != NAME_FREE )
    {
      if ( _NB_MatchName ( pNN, &(pNE->nn) ) )
        return pNE;
    }
    pNE++;
  }

  return NULL;
}

/* NBNS Subroutines ================================= */

/* Struct in_addr's always contain addresses in network byte order, so
   the integer value of the s_addr field, as perceived by C, will vary
   between big-endian and little-endian implementations. Hence, we have
   to phrase our routines in such a way that they are independent of
   the endian-ness (preferably by not treating struct in_addr as an
   integer value at all). The union below helps */

union in_addr_byte
{
  struct in_addr ina;
  BYTE   nb[4];
};

/* ------------------- */

static struct sockaddr_in NameServer_sin;

static void SetupNameServer ( void )
{
  if (NBNS_NameServer == NULL)
  {
    char *ns_addr = getenv("LanMan$NameServer");
    union in_addr_byte iab;
    int b0, b1, b2, b3;

    if ((ns_addr == NULL) || (sscanf(ns_addr, "%d.%d.%d.%d",&b0, &b1, &b2, &b3) != 4))
    {
      b0 = RdCMOS(NBNSIPCMOS0);
      b1 = RdCMOS(NBNSIPCMOS1);
      b2 = RdCMOS(NBNSIPCMOS2);
      b3 = RdCMOS(NBNSIPCMOS3);
    }
    if ( ((b0 != 0) && (b0 != 127) && (b0 <= 223))  &&  ((b3 != 0) && (b3 != 255)) )
    {
      iab.nb[0]=b0, iab.nb[1] = b1, iab.nb[2] = b2, iab.nb[3] = b3;
      NameServer_sin.sin_family = AF_INET;
      NameServer_sin.sin_port   = htons(NBNS_PORT);
      NameServer_sin.sin_addr   = iab.ina;
      NBNS_NameServer = (struct sockaddr *) &NameServer_sin;
    }
  }
}

/* ----------------- */


/* Given a scope ID (e.g. "netbios.ibm.com"), converts this to the
   NBNS compacted format.
*/

static void SetScopeID ( char *src )
{
  int i, l;
  char *p;

  if ( src==NULL) src = "";

  NB_ScopeIDlen=0;

  /* Get number of characters to next dot, or if no more dots, to end
     of string. If it's too long, it gets rudely truncated! */

  do
  {
    p = strchr(src, '.');  /* Find '.' */
    if (p == NULL)         /* Last bit */
      l = strlen(src);
    else
      l = p-src;           /* Length to dot */

    if ( l == 0  /* No more */ ||
         l >= 64 /* Illegal */ ||
         NB_ScopeIDlen+l+1 >= SCOPE_ID_MAX )
      break;

    NB_ScopeID [NB_ScopeIDlen++] = l;
    for ( i=0; i<l; i++ )
      NB_ScopeID [NB_ScopeIDlen++] = toupper(*src++);
    src++; /* Skip 'dot' if present */
  }
    while ( p != NULL );

  NB_ScopeID [NB_ScopeIDlen] = 0;
  NB_ScopeIDlen++;
}

/* ---------------------------------------- */

static uint GetLong( BYTE *p)
{
  return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

/* ---------- */

static BYTE *PutLong ( BYTE *ptr, uint v )
{
  *ptr++ = (v >> 24);
  *ptr++ = (v >> 16);
  *ptr++ = (v >> 8);
  *ptr++ = v;
  return ptr;
}

/* ---------- */


static struct in_addr GetIPAddr( BYTE *p)
{
  union in_addr_byte ib;
  ib.nb[0] = p[0];
  ib.nb[1] = p[1];
  ib.nb[2] = p[2];
  ib.nb[3] = p[3];
  return ib.ina;
}

/* ---------- */

static BYTE *PutIPAddr ( BYTE *ptr, struct in_addr ia )
{
  union in_addr_byte ib;
  ib.ina = ia;
  *ptr++ = ib.nb[0];
  *ptr++ = ib.nb[1];
  *ptr++ = ib.nb[2];
  *ptr++ = ib.nb[3];
  return ptr;
}

/* ------------- */

static uint GetShort( BYTE *p)
{
  return (p[0] << 8) | p[1];
}

/* ------------- */

static BYTE *PutShort ( BYTE *ptr, uint v )
{
  *ptr++ = (v >> 8);
  *ptr++ = v;
  return ptr;
}

/* --------------- */

static BYTE *PutNetname ( BYTE *ptr, NETNAME *pNN )
{
  /* Put NetBIOS name in a compressed ASCII-coded representation */
  int i,c;
  BYTE *p;

  p = pNN->b; /* Pointer to first part of name */

  *ptr++ = 32;   /* This is always 32 characters */

  for (i=0; i<16; i++)
  {
    c = *p++;
    *ptr++ = 'A' + ((c >> 4) & 0xF);
    *ptr++ = 'A' + (c & 0xF);
  }

  memcpy ( ptr, NB_ScopeID, NB_ScopeIDlen );
  return ptr + NB_ScopeIDlen;
}

/* --------------- */

static BYTE *PutNetnameIndirect ( BYTE *ptr, BYTE *name,
				BYTE *buf_start )
{
  int c = name-buf_start;

  if ( c > 0 && c <= 0x3FFF )
    ptr=PutShort(ptr, c|0xC000 );
  else
  {
    STAT(STA_SERIOUS_BARF);
    *ptr++ = 0;
  }

  return ptr;
}

/* -------------- */

static BYTE *PutResourceInfo ( BYTE *p, NAME_ENTRY *pNE, uint ttl )
{
  p = PutLong ( p, ttl );
  p = PutShort ( p, 0x0006 );  /* 6 extra data bytes */
  p = PutShort ( p, pNE->nbflags );
  return PutIPAddr ( p, pNE->IPaddress );
}

/* -------------- */

static BYTE *CreateNBNSheader(BYTE *ptr, int opcode, int trn_ID )
{
  /* Creates an NBNS header */
  ptr = PutShort(ptr, trn_ID);  /* Create new request ID */
  ptr = PutShort(ptr, opcode & 0xFFFF);
  ptr = PutShort(ptr, (opcode & HAS_QUERY) ? 1 : 0);
  ptr = PutShort(ptr, (opcode & HAS_ANSWER) ? 1 : 0);
  ptr = PutShort(ptr, (opcode & HAS_AUTHORITY) ? 1 : 0);
  return PutShort(ptr, (opcode & HAS_ADDITIONAL) ? 1 : 0);
}

/* Transmit routines ============================================ */

static void SendDatagram ( struct sockaddr *pDst, BYTE *start, BYTE *end )
{
  dprintf((__FILE__, "SendDatagram ID:&%04x to %s\n", GetShort(start),
    inet_ntoa(((struct sockaddr_in *) pDst)->sin_addr)));
  sendto ( NBNS_Socket, start, end-start, 0, pDst,
               sizeof(struct sockaddr_in) );
}

/* --------------------- */

static void SendRegisterRequest ( struct sockaddr *pDst, NAME_ENTRY *pNE )
{
  BYTE *p, *name_p;

  p = CreateNBNSheader(DatagramBuf, NAME_REG_REQUEST, ++NBNS_RequestCount);
  name_p = p;
  p = PutNetname( p, &(pNE->nn) );  /* Query section */
  p = PutLong (p, INET_NAME_TAG );
  /* Resource section, using a name pointer */
  p = PutNetnameIndirect ( p, name_p, DatagramBuf );
  p = PutLong (p, INET_NAME_TAG );
  p = PutResourceInfo (p, pNE, REGISTER_TTL );

  SendDatagram ( pDst, DatagramBuf, p );
}

/* --------------------- */

static void SendReleaseRequest ( struct sockaddr *pDst, NAME_ENTRY *pNE )
{
  BYTE *p, *name_p;

  p = CreateNBNSheader(DatagramBuf, NAME_RLSE_REQUEST, ++NBNS_RequestCount);
  name_p = p;
  p = PutNetname( p, &(pNE->nn) );  /* Query section */
  p = PutLong (p, INET_NAME_TAG );
  /* Resource section, using a name pointer */
  p = PutNetnameIndirect ( p, name_p, DatagramBuf );
  p = PutLong (p, INET_NAME_TAG );
  p = PutResourceInfo (p, pNE, 0 );

  SendDatagram ( pDst, DatagramBuf, p );
}

/* --------------------- */

static void SendFindRequest ( struct sockaddr *pDst, NAME_ENTRY *pNE )
{
  BYTE *p;

  p = CreateNBNSheader(DatagramBuf, NAME_FIND_REQUEST, ++NBNS_RequestCount);
  p = PutNetname( p, &(pNE->nn) );  /* Query section */
  p = PutLong (p, INET_NAME_TAG );


#ifdef DEBUG
  {
          struct sockaddr_in *sin = (void *) pDst;
          debug2("SendFindRequest (%s)-> [%s]\n",
            debug_name(&(pNE->nn)),
            inet_ntoa(sin->sin_addr));
  }
#endif
  SendDatagram ( pDst, DatagramBuf, p );
}

/* --------------------- */

static void SendStatusRequest ( struct sockaddr *pDst, NAME_ENTRY *pNE )
{
  BYTE *p;

  p = CreateNBNSheader(DatagramBuf,NAME_STATUS_REQUEST,++NBNS_RequestCount);
  p = PutNetname( p, &(pNE->nn) );  /* Query section */
  p = PutLong (p, INET_STATUS_TAG );

  dprintf((__FILE__, "SendStatusRequest (%s)\n", debug_name(&(pNE->nn))));

  SendDatagram ( pDst, DatagramBuf, p );
}

/* Name Decoding subroutines ==================================== */

/* Read RFC-1001 for more info on the bizarre network name
   representation scheme.
*/

static bool ValidateName( BYTE *src, BYTE *buf_start, BYTE *buf_end )
{
  int c, loopy_count;

  loopy_count = 0;

  while( src >= buf_start && src < buf_end && loopy_count++ < 100 )
  {
    c = *src;

    if ( c == 0 )    /* Reached the end without incident */
      return true;
    else if ( c < 0x40 )  /* Ordinary name length segment */
      src += (c+1);
    else if ( c >= 0xC0 ) /* Name pointer */
    {
      if ( src+2 > buf_end ) return false;
      src = buf_start + (GetShort(src) & 0x3FFF);
    }
    else                  /* Invalid */
    {
      debug1("Invalid byte %Xh in name\n", c );
      return false;
    }
  }

  /* Get here if we go wrong somewhere e.g. name is truncated */
  debug0("Invalid name - exceeded length\n");
  return false;
}

/* -------------- */

static BYTE *FindNameEnd ( BYTE *src )
{
  int c;
  while ( c=src[0], c != 0 )
  {
    if ( c >= 0xC0 ) /* Pointer */
      return src+2;
    src += (c+1);
  }
  return src+1;
}

/* --------------------- */


/* ChasePointer is a subroutine for FindNBNSName.
   It keeps following a pointer in an encoded representation to find
   out where it starts.
*/

static BYTE *ChasePointer( BYTE *src, BYTE *buf_start )
{
  while( src[0] >= 0xC0 )
    src = buf_start + (GetShort(src) & 0x3FFF);

  return src;
}


/* FindNBNSName decodes the encoded name representation in NBNS
   packets (dear Anne, why oh why...?) and searches the name table
   for a match. All names of interest are kept in the table, so
   this is the only place that name decoding needs to be done.

   It returns NULL if the name is badly-formed, not found in the
   table, or exceeds the end of the buffer as given by buf_end.

   It should be called only with names which have passed ValidateName(),
   otherwise all sorts may happen.
*/

static NAME_ENTRY *FindNBNSName ( BYTE *src, BYTE *buf_start)
{
  NETNAME netname;
  BYTE *id;
  int i;

  /* Find first bit of name */

  src=ChasePointer(src, buf_start);

  if ( src[0] != 32 )  /* Encoded NetBIOS name is always 32 characters */
    return NULL;

  /* src points to the encoded NetBIOS name - decode it now */

  src++;
  for (i=0; i<16; i++)
  {
    netname.b[i] = ( (src[0] -'A') << 4 ) + src[1] - 'A';
    src+=2;
  }

  debug1("Name=%s", debug_name(&netname)); debug_scope (src); debug0("\n");

  /* Now check NetBIOS scope ID */

  id = NB_ScopeID;

  while (1)
  {
    src = ChasePointer(src, buf_start);
    i = src[0];      /* Length of this segment */
    if ( i != id[0] ) /* Length mismatch */
      return NULL;
    if ( i == 0 )      /* The end */
      break;
    if ( memcmp (src+1, id+1, i) != 0 )
      return NULL;
    src += i+1;
    id  += i+1;
  }

  /* Now check name table */
  return FindNameEntry ( &netname );
}


/* ---------------- */

struct NBNS_packet
{
  struct sockaddr from;
  int   trn_id;     /* Transaction ID */
  int   opcode;     /* Opcode */
  int   n_query;    /* No. of query records */
  int   n_answer;   /* No. of answer records */
  int   n_auth;     /* No. of authority records */
  int   n_add;      /* No. of additional records */
  BYTE *buf_start;  /* Start of raw data */
  BYTE *buf_end;    /* Last byte of raw data plus one */
  BYTE *record_ptr; /* Current record pointer, for GetNextRecord */
};

struct NBNS_resource_record
{
  NAME_ENTRY *pName;
  int  name_tag;
  int  time_to_live;
  int  data_length;
  BYTE *data_ptr;
};

/* ------------------------------- */

#define GET_QUERY    0
#define GET_RESOURCE 1

static bool GetNBNSRecord ( struct NBNS_packet *pNBP,
                          struct NBNS_resource_record *pDst, int flg )
{
  BYTE *src = pNBP->record_ptr;

  /* Name truncated or garbage? */
  if ( !ValidateName(src, pNBP->buf_start, pNBP->buf_end) )
  {
    debug0("Name truncated\n");
    return false;
  }

  /* Is name known to us? */
  pDst->pName = FindNBNSName ( src, pNBP->buf_start );
  if ( pDst->pName == NULL ) debug0("Name unknown to us\n");

  src = FindNameEnd ( src );

  if ( flg & GET_RESOURCE )
  {
    if ( src + 10 > pNBP->buf_end )
    {
      debug0("Resource truncated\n");
      return false;
    }

    pDst->name_tag = GetLong(src);
    pDst->time_to_live = GetLong(src+4);
    pDst->data_length = GetShort(src+8);

    src += 10;
    pDst->data_ptr = src;

    if ( src + pDst->data_length > pNBP->buf_end )
    {
      /* Benign truncation - we give all the data that's available */
      pDst->data_length = pNBP->buf_end - src;
    }

    src += pDst->data_length;
  }
  else
  {
    if ( src + 4 > pNBP->buf_end )
    {
      debug0("Query truncated\n");
      return false;
    }

    pDst->name_tag = GetLong(src);
    pDst->time_to_live = 0;
    pDst->data_length = 0;

    src += 4;
  }

  pNBP->record_ptr = src;
  return true;
}

/* Receive processing routines ======================================= */

static void NameFindRequest ( struct NBNS_packet *pNBP,
                              struct NBNS_resource_record *pNBRR )
{
  NAME_ENTRY *pNE = pNBRR->pName;
  BYTE *p;

  if ( pNE->status == LCL_NAME_OK )
  {
    p = CreateNBNSheader ( DatagramBuf, NAME_FIND_REPLY, pNBP->trn_id );
    p = PutNetname ( p, &(pNE->nn) );
    p = PutLong (p, INET_NAME_TAG );
    p = PutResourceInfo(p, pNE, FIND_TTL);

    sendto ( NBNS_Socket, DatagramBuf, p-DatagramBuf, 0,
               &(pNBP->from), sizeof(pNBP->from) );
  }
}

/* ---------------- */

static void NameRegisterRequest ( struct NBNS_packet *pNBP,
                              struct NBNS_resource_record *pNBRR_query )
{
  NAME_ENTRY *pNE;
  struct NBNS_resource_record NBR_add;
  BYTE *p;

  pNE = pNBRR_query->pName;

  /* Get additional record, containing group status & IP address */

  if ( /* Are all the parameters OK */
       pNE->status != LCL_NAME_OK    ||
       pNBP->n_add < 1              ||
       !GetNBNSRecord( pNBP, &NBR_add, GET_RESOURCE ) ||
       NBR_add.data_length < 6
     )
  {
    return;
  }

  /* Are they both group names? If so, don't worry */

  if ( (GetShort (NBR_add.data_ptr) & NBFLG_GROUP) != 0  &&
       (pNE->nbflags & NBFLG_GROUP)  != 0
     )
  {
    return;
  }

  /* If the IP addresses match, panic not */
  if ( GetIPAddr(NBR_add.data_ptr+2).s_addr == pNE->IPaddress.s_addr )
  {
    return;
  }

  /* Send a negative name registration response with our details */

  p = CreateNBNSheader ( DatagramBuf, NAME_REG_REPLY | ST_ACT_ERR,
                           pNBP->trn_id );
  p = PutNetname ( p, &(pNE->nn) );
  p = PutLong (p, INET_NAME_TAG );
  p = PutResourceInfo(p, pNE, REGISTER_TTL);

  sendto ( NBNS_Socket, DatagramBuf, p-DatagramBuf, 0,
             &(pNBP->from), sizeof(pNBP->from) );

}

/* ---------------------------- */

static void NameFindReply ( struct NBNS_packet *pNBP,
                            struct NBNS_resource_record *pNBRR )
{
  NAME_ENTRY *pNE = pNBRR->pName;
  BYTE *dp = pNBRR->data_ptr;

  /* Are we waiting for a reply? Is this the one? */

  if ( (pNBP->opcode & OPC_STATUS_MASK) == ST_OK &&
       pNE->status == RMT_AWAIT_FIND             &&
       pNBRR->data_length >= 6  /* At least one entry in reply */
     )
  {
    debug0("NameFindReply - found\n");
    pNE->status = RMT_FOUND;
    pNE->nbflags = GetShort(dp);
    pNE->IPaddress = GetIPAddr(dp+2);

    /* Process time-to-live in milliseconds */
    pNE->TTL_StartTime = NB_GetTime();

    if ( pNBRR->time_to_live > 0 )
      pNE->TTL_Interval = pNBRR->time_to_live/10;
    else
      pNE->TTL_Interval = FIND_TTL/10;
  }
}

/* ---------------------------- */

static void NameStatusReply ( struct NBNS_packet *pNBP,
                            struct NBNS_resource_record *pNBRR )
{
  struct status_resp *pSR;
  BYTE *dp;
  int n, flg;

  (void) pNBP; /* Don't use it for now */

  /* Are we waiting for a status reply? */
  dp = pNBRR->data_ptr;
  pSR = pNBRR->pName->pStatResp;

  if ( pSR == NULL ||
       pNBRR->pName->status != RMT_STATUS_Q  ||
       pNBRR->data_length < 1  /* At least one byte for name */
     )
  {
    debug0("Puzzling status response\n");
    return;
  }

  n = *dp++; /* Number of names returned */
  if (n*18 >= pNBRR->data_length)
  {
    n =  (pNBRR->data_length-1) / 18;
  }

  debug3("Status: %d names, type %Xh, %d spc\n", n, pSR->nt_search,
                   pSR->spaces_left);

  ddumpbuf(__FILE__, dp, n*18, 0);


  while( pSR->spaces_left > 0  && n-- > 0 )
  {
#ifdef DEBUG
    char namebuf[32];
    dprintf((__FILE__, "Found %s\n", debug_name_buf(dp, namebuf)));
#endif
    /* dp points to a network name */
    if ( pSR->nt_search == ANY_NAME_TYPE ||
         pSR->nt_search == dp[15] )
    {
      memcpy ( &(pSR->pRes->name), dp, 16 );
      pSR->pRes->type = (nametype_t) (dp[15]);
      flg = GetShort(dp+16);
      pSR->pRes->flags = (flg & NBFLG_GROUP) ? FN_GROUPNAME : 0;
      pSR->spaces_left--;
      pSR->pRes++;
    }
    dp+=18;
  }

  while (n-- > 0)
  {
    debug1("Found but ignoring %s\n", debug_name( dp ));
    dp+=18;
  }
}

/* ---------------------------- */
#ifdef DEBUG
static void debug_opc(struct NBNS_packet *p)
{
  static const char *statuses[16] = {
    "OK", "FMT_ERR", "SRV_ERR", "NAM_ERR", "IMP_ERR", "RFS_ERR", "ACT_ERR", "CFT_ERR"
  };
  static const char *opcodes[16] = {
    "FIND", "1", "2", "3", "4", "REGISTER", "RELEASE", "WACK", "REFRESH", "9", "10"
  };
  static char flags[256];
  const char *opcode, *status, *reply;

  reply = (p->opcode & OPC_REPLY) ? "Reply" : "Query";
  *flags = '\0';

  if (p->opcode & OPC_AUTHORITY) strcat(flags, "AUTH ");
  if (p->opcode & OPC_TRUNCATED) strcat(flags, "TRUNC ");
  if (p->opcode & OPC_REC_DESIRED) strcat(flags, "REC_DESIRED ");
  if (p->opcode & OPC_REC_AVAIL) strcat(flags, "REC_AVAIL ");
  if (p->opcode & OPC_BROADCAST) strcat(flags, "BROADCAST ");

  opcode = opcodes[(p->opcode & OPC_OPCODE_MASK) >> 11];
  status = (p->opcode & OPC_REPLY) ? statuses[(p->opcode & OPC_STATUS_MASK)] : "";

  dprintf((__FILE__, "* %s ID:&%04x %s %s\n", reply, p->trn_id,
    opcode?opcode:"<UNKNOWN>", status?status:"<UNKNOWN>"));
  dprintf((__FILE__, "n_query: %d, n_answer: %d, n_auth: %d, n_add: %d\n",
    p->n_query, p->n_answer, p->n_auth, p->n_add));
}
#endif

static void NBNS_ProcessDatagram (
                 struct sockaddr *pFrom, BYTE *buf, int len )
{
  struct NBNS_packet NBP;
  struct NBNS_resource_record NBRR;

#ifdef DEBUG
  {
    struct sockaddr_in *from2 = (struct sockaddr_in *)pFrom;
    debug3("Datagram from inaddr %s, port %d, len %d\n",
            inet_ntoa(from2->sin_addr), ntohs(from2->sin_port), len );
  }
#endif

  if ( len < 12 ) /* Too short for header */
    return;

  NBP.from   = *pFrom;
  NBP.trn_id = GetShort(buf+0);    /* Transaction ID */
  NBP.opcode = GetShort(buf+2);    /* Opcode, status & flags */
  NBP.n_query = GetShort(buf+4);
  NBP.n_answer = GetShort(buf+6);
  NBP.n_auth = GetShort(buf+8);
  NBP.n_add = GetShort(buf+10);

  NBP.buf_start = buf;
  NBP.buf_end = buf+len;
  NBP.record_ptr = buf+12;

#ifdef DEBUG
  debug_opc(&NBP);
#endif

  if ( NBP.opcode & OPC_REPLY )
  {
    /* Response to one of our questions, either a name registration request,
       or a name query request */

    if ( NBP.n_answer >=1 &&
         GetNBNSRecord( &NBP, &NBRR, GET_RESOURCE ) &&
         NBRR.pName != NULL )
    {
      if ( NBRR.name_tag == INET_NAME_TAG )
      {
        switch ( NBP.opcode & OPC_OPCODE_MASK )
        {
          case OPC_FIND: /* Name find reply */
            NameFindReply ( &NBP, &NBRR );
            break;

          case OPC_REGISTER: /* Name registration reply */
              /* If this is a negative reply, & it's a local name,
                mark it as in-conflict */

            if ((NBP.opcode & OPC_STATUS_MASK) != ST_OK)
            {
              if ( NBRR.pName->status == LCL_AWAIT_ADD ||
                   NBRR.pName->status == LCL_NAME_OK
                 )
              {
                NBRR.pName->status = LCL_IN_CONFLICT;
              }
            }
            break;

          default:
            debug0("Unknown reply\n");
            break;
        }
      }
      else if ( NBRR.name_tag == INET_STATUS_TAG )
      {
        if ( (NBP.opcode & OPC_OPCODE_MASK) == OPC_FIND  &&
             (NBP.opcode & OPC_STATUS_MASK) == ST_OK)
        {
          NameStatusReply ( &NBP, &NBRR );
        }
      }
    }
  }
  else
  {
    /* Request to us from someone else  */

    if ( NBP.n_query >=1 &&
         GetNBNSRecord( &NBP, &NBRR, GET_QUERY ) &&
         NBRR.pName != NULL )
    {
      if ( NBRR.name_tag == INET_NAME_TAG )
        switch ( NBP.opcode & OPC_OPCODE_MASK )
        {
          case OPC_FIND: /* Name find request */
            NameFindRequest ( &NBP, &NBRR );
            break;

          case OPC_REGISTER: /* Name registration request */
            NameRegisterRequest ( &NBP, &NBRR );
            break;

          case OPC_RELEASE: /* Name release request */
            if ( NBRR.pName->status == RMT_CACHED )
              FreeNameEntry ( NBRR.pName );
            break;

          default:
            break;

        }
    }
  }
}


/* Event and callback functions ==================================== */

/* Under RISCOS, background processing is done by having a system
   event - the Internet event - which gets called every time a socket
   receives something (amongst other things). This lets us schedule
   a callback to pick up the data and process it.
*/

extern void EventFn (void);   /* Provided by CMHG */
extern void NBIP_CallbackFn(void);

/* EventFn() ------------------------------------------ */

static bool EventsClaimed=false;
static bool CallbackSet = false;

/* ---------------- */

int EventFn_handler ( _kernel_swi_regs *R, void *pw )
{
  (void) pw;

  if ( R->r[0] == Internet_Event &&
       R->r[1] == 1 && /* ensure it was the data arrived event! */
       R->r[2] == NBNS_Socket &&
       NBNS_Socket != INVALID_SOCKET &&
       !CallbackSet )
  {
    STAT(STA_IP_EVENTS);
    CallbackSet = true;
    _swix(OS_AddCallBack, _INR(0,1), NBIP_CallbackFn, LM_pw);
  }

  return 1; /* Don't claim, others may wish to know */
}

static void RemoveCallbacks(void)
{
  _swix(OS_RemoveCallBack, _INR(0,1), NBIP_CallbackFn, LM_pw);
  CallbackSet = false;
}

/* -------------------------------- */

static int NBIP_CallbackFn_handler(void)
{
  fd_set read_set;
  struct timeval tv;
  int    len, flen;
  struct sockaddr sa;


  CallbackSet = false;

  while (NBNS_Socket != INVALID_SOCKET) /* Do as many packets as we can */
  {
    tv.tv_sec=0;
    tv.tv_usec=0;

    FD_ZERO(&read_set);
    FD_SET( NBNS_Socket, &read_set );

    if ( select ( NBNS_Socket + 1, &read_set, NULL, NULL, &tv ) == 0 )
      break;

    flen = sizeof(sa);
    len = recvfrom ( NBNS_Socket, DatagramBuf, sizeof(DatagramBuf),
                     0, &sa, &flen );
    if ( len > 0 )
    {
      STAT(STA_IP_RXDGRAM);
      NBNS_ProcessDatagram ( &sa, DatagramBuf, len );
    }
  }

  return 1;
}

int NBIP_CallbackFn_handler_ctrl(_kernel_swi_regs *r, void *pw)
{
  (void) r;
  (void) pw;
  return NBIP_CallbackFn_handler();
}


/* Exported routines: name service & general =========================== */

/* -------------------- */

/* This function will return a pointer to a NAME_ENTRY structure
   if the name can be found. The status field will be set to RMT_FOUND
   to ensure that the name entry is not disposed of before it can be
   used. After it has been used, it should be set to RMT_CACHED, to
   allow it to be dropped from the table after a while.
*/

static NAME_ENTRY *FindRemoteName ( NETNAME *pnn )
{
  int i;
  uint tstart;
  char plain_name[NAME_LIMIT];
  NAME_ENTRY *pNE;
  struct hostent *pHE;

  debug1("Find remote name %s\n", debug_name(pnn));

  /* Check name cache */

  CheckExpiredNames();

  pNE = FindNameEntry ( pnn );

  if ( pNE != NULL )  /* Found it */
  {
    if ( pNE->status == RMT_FOUND || pNE->status == RMT_CACHED )
    {
      pNE->status = RMT_FOUND;
      return pNE;
    }
    return NULL;     /* Local name - can't be found */
  }

  /* Try to find it by broadcast, then ask name server */

  pNE = AllocNameEntry(RMT_AWAIT_FIND);
  if ( pNE==NULL )        /* No spaces left */
    return NULL;

  pNE->nn    = *pnn;   /* Copy name */
  pNE->pStatResp = NULL; /* for safety */

  for ( i=3; i>=0; i-- )
  {
    if ( i > 0 )  /* Send 3 broadcasts */
    {
      debug0("Broadcast find request\n");
      SendFindRequest ( NBNS_Broadcast, pNE );
    }
    else          /* Ask name server */
    {
      SetupNameServer();
      if ( NBNS_NameServer == NULL )
        break;
      debug0("Send find request to nameserver\n");
      SendFindRequest ( NBNS_NameServer, pNE );
    }

    tstart = NB_GetTime();
    do
    {
      usermode_donothing();
      NBIP_CallbackFn_handler();
      if (pNE->status == RMT_FOUND)
      {
        debug1("Name found at %X\n", pNE->IPaddress.s_addr);
        return pNE;
      }
    }
      while ( (NB_GetTime() - tstart) < 50 );
  }

  /* Still no joy - can we look it up in hosts file? */

  _NB_DecodeName ( pnn, plain_name );
  strcpyn_lower ( plain_name, plain_name, NAME_LIMIT );

  debug0("Looking up name in hosts file\n");

  pHE = gethostbyname ( plain_name );
  if ( pHE != NULL &&
       pHE->h_addr_list != NULL &&
       pHE->h_addr_list[0] != NULL )
  {
    pNE->status = RMT_FOUND;
    pNE->nbflags = NBFLG_UNIQUE | NBFLG_BNODE; /* Don't know - make it up */
    pNE->TTL_StartTime = NB_GetTime();
    pNE->TTL_Interval = 1; /* Doesn't last for long */
    pNE->IPaddress = GetIPAddr ( (BYTE *) (pHE->h_addr_list[0]) );
    debug1("Name found in hosts at %X\n", pNE->IPaddress.s_addr);
    return pNE;
  }

  FreeNameEntry(pNE);
  return NULL;
}


/* ----------------------- */



static NAME_ENTRY *ValidatehName( hNAME hName )
{
  NAME_ENTRY *pN = (NAME_ENTRY *)hName;
  if ( pN != NULL )
  {
          debug1("Status => %d\n", pN->status);
    if ( (pN->status == LCL_NAME_OK) || (pN->status == LCL_IN_CONFLICT) )
      return pN;
  }

  return NULL;
}

/* ----------------- */

EXPORT err_t _NB_AddLocalName ( nametype_t nt, char *name, hNAME *phName )
{
  NAME_ENTRY *pNE;
  NETNAME netname;
  int i;
  uint tstart;

  debug1("Add name '%s'\n", name );

  _NB_FormatName ( nt, name, &netname );

  pNE = FindNameEntry ( &netname );
  if ( pNE != NULL )  /* Either local or remote */
    return ENAMEEXISTS;

  pNE = AllocNameEntry(LCL_AWAIT_ADD);
  if ( pNE == NULL )
    return ENOHANDLES;

  pNE->IPaddress = NB_IPAddress;
  pNE->nbflags   = NBFLG_UNIQUE | NBFLG_BNODE;
  pNE->nn = netname;
  pNE->pStatResp = NULL;

  for ( i=3; i >= 0; i-- )  /* 3 opportunities to complain */
  {
    if ( i > 0 ) /* Broadcast 3 times */
    {
      SendRegisterRequest ( NBNS_Broadcast, pNE );
    }
    else /* Then check with the nameserver if present */
    {
      SetupNameServer();
      if ( NBNS_NameServer == NULL )
        break;
      SendRegisterRequest ( NBNS_NameServer, pNE );
    }

    tstart = NB_GetTime();
    do
    {
      usermode_donothing();
      NBIP_CallbackFn_handler();
      if ( pNE->status == LCL_IN_CONFLICT )  /* Failed */
      {
        FreeNameEntry(pNE);
        return ENAMEEXISTS;
      }
    }
      while ( (NB_GetTime() - tstart) < 50 );
  }

  /* No-one complained */

  pNE->status = LCL_NAME_OK;
  *phName = (hNAME) pNE;
  return OK;
}


/* ----------------------- */

EXPORT err_t _NB_RemoveLocalName ( hNAME hName )
{
  NAME_ENTRY *pNE;
  int i;
  uint tstart;

  pNE = ValidatehName(hName);
  if ( pNE == NULL )
    return EBADPARAM;

  /* Should vape all connections to this name */

  if ( pNE->status != LCL_IN_CONFLICT )
  {
    for ( i=0; i<3; i++ )
    {
      SendReleaseRequest ( NBNS_Broadcast, pNE );
      tstart = NB_GetTime();
      do
      {
        usermode_donothing();
        NBIP_CallbackFn_handler();
      }
        while ( (NB_GetTime() - tstart) < 50 );
    }

    /* Tell name server if we have one */
    if ( NBNS_NameServer != NULL )
      SendReleaseRequest ( NBNS_NameServer, pNE );
  }

  FreeNameEntry(pNE);
  return OK;
}

/* ----------------------- */

EXPORT int _NB_FindNames ( NETNAME *pnnFind,
                   nametype_t ntFind,
                   struct FindName_res *pResults,
                   int results_max,
                   int timeout )
{
  NAME_ENTRY   *pNE;
  struct status_resp SR;
  uint tstart;

  pNE = AllocNameEntry(RMT_STATUS_Q);
  if ( pNE == NULL )
    return 0;

  debug2("Find name %s type %Xh\n", debug_name(pnnFind), ntFind);

  SR.nt_search = ntFind;
  SR.pRes = pResults;
  SR.spaces_left = results_max;

  pNE->nn = *pnnFind;
  pNE->pStatResp = &SR;

  /* Try broadcast to start with */
  SendStatusRequest( NBNS_Broadcast, pNE);

  tstart = NB_GetTime();
  do
  {
    usermode_donothing();
    NBIP_CallbackFn_handler();
  }
    while ( SR.spaces_left > 0 && (NB_GetTime() - tstart) < timeout );

  /* If more to do, ask the name server */

  if ( SR.spaces_left == 0 ) goto search_done;

  SetupNameServer();
  if ( NBNS_NameServer == NULL ) goto search_done;

  SendStatusRequest ( NBNS_NameServer, pNE);

  tstart = NB_GetTime();
  do
  {
    usermode_donothing();
    NBIP_CallbackFn_handler();
  }
    while ( SR.spaces_left > 0 && (NB_GetTime() - tstart) < timeout );

search_done:
  FreeNameEntry(pNE);
  return results_max - SR.spaces_left;
}


/* Session service *************************************************** */

#define SESS_FREE      0
#define SESS_CONNECTED 1

typedef struct
{
  int status;
  int sid;    /* Socket ID */
  bool LinkOK;
  NAME_ENTRY *lcl_name;
  struct sockaddr_in rmt_addr;
}
  NBIP_SESSION;

static NBIP_SESSION NB_Sessions[MAX_SESSIONS];

/* ------------------------ */

static NBIP_SESSION *AllocSession ( void )
{
  int i;
  for (i=0; i < MAX_SESSIONS; i++)
    if ( NB_Sessions[i].status == SESS_FREE )
      return &NB_Sessions[i];
  return NULL;
}

/* ------------------------ */

static void FreeSession (NBIP_SESSION *pNS)
{
  pNS->status = SESS_FREE;
}

/* ----------------- */

static NBIP_SESSION *ValidatehSession( hSESSION hSess )
{
  NBIP_SESSION *pN = (NBIP_SESSION *)hSess;
  if ( pN != NULL && pN->status == SESS_CONNECTED )
    return pN;

  return NULL;
}

/* ------------------- */

static bool ReadData ( int sid, BYTE *where, int len, uint timeout, int flags )
{
  uint tstart;
  fd_set read_set;
  struct timeval tv;
  int rdlen;

  tstart = NB_GetTime();

  while ( len > 0 )
  {
    usermode_donothing();   /* Let IP do its thing */
    NBIP_CallbackFn_handler(); /* Process any datagrams */

    tv.tv_sec=0;
    tv.tv_usec=0;

    FD_ZERO(&read_set);
    FD_SET( sid, &read_set );
    /* SNB: Changed first param to sid+1 - is more efficient as Internet module
     * no longer has to search entire array for set bits */
    if ( select ( sid + 1, &read_set, NULL, NULL, &tv ) != 0 )
    {
      rdlen = recv ( sid, where, len, flags );
      if ( rdlen > 0 )
      {
        if (flags & MSG_PEEK) break;
        len -= rdlen;
        where += rdlen;
        tstart = NB_GetTime();
        continue;
      }
    }

    if ( timeout == 0 ) return true; /* No timeout requested, so none occurs */
    if ( NB_GetTime() - tstart > timeout )
    {
      if ( timeout > 0) debug1("Timeout after %dcs\n", timeout);
      return false;
    }
  }

  return true;
}

/* --------------- */

static err_t ConnectAttempt ( NBIP_SESSION *pNS, NETNAME *pnnFarEnd )
{
  struct sockaddr_in sa;
  BYTE *p;   uint len;

  debug2("Attempting to connect - addr=%Xh, port %d\n",
     pNS->rmt_addr.sin_addr.s_addr, ntohs(pNS->rmt_addr.sin_port) );

  /* Entered with pNS->sid = a socket descriptor, and pNS->rmt_addr is
     a starting IP address & port number. This should
     attempt to bind(), connect(), then establish a session with
     the far end. Can return ERETARGET with pNS->rmt_addr set to a
     new address, in which case it will get called again with a
     new socket */

  sa.sin_family = AF_INET;
  sa.sin_port   = 0;       /* Alloc a port */
  sa.sin_addr.s_addr = INADDR_ANY;

  if ( bind ( pNS->sid, (struct sockaddr *)&sa, sizeof(sa) ) != 0 )
    return ECREATESOCKET;

  /* Try to connect to remote end */

  if ( connect ( pNS->sid, (struct sockaddr *)(&pNS->rmt_addr),
                     sizeof(pNS->rmt_addr) ) != 0 )
    return ECONNECTSOCKET;

  /* OK, we're connected - try a 'session request' */

  p = DatagramBuf;
  *p++ = NBIP_SESS_REQUEST;
  *p++ = 0; /* Flags */
  p+=2;     /* Skip length for now */
  p = DatagramBuf+4;
  p = PutNetname ( p, pnnFarEnd );  /* Called name */
  p = PutNetname ( p, &(pNS->lcl_name->nn) ); /* Calling name */
  len = p-DatagramBuf;
  PutShort(DatagramBuf+2, len-4);

  if ( send ( pNS->sid, DatagramBuf, len, 0 ) != len )
    return ECONNECTSOCKET;
  debug0("Sent session request: ");

  /* Now get reply */

  if ( !ReadData(pNS->sid, DatagramBuf, 4, RECV_TIMEOUT, 0) )
    return ETIMEOUT;

  switch ( DatagramBuf[0] )
  {
    case NBIP_SESS_OK: /* Well and good */
      return OK;

    case NBIP_SESS_REJECT:
      return ECONNREJECT;

    case NBIP_SESS_RETARGET:
      if ( !ReadData( pNS->sid, DatagramBuf, 6, RECV_TIMEOUT, 0) )
        return EDATALEN;
      pNS->rmt_addr.sin_addr = GetIPAddr( DatagramBuf );
      pNS->rmt_addr.sin_port = htons(GetShort( DatagramBuf+4 ));
      debug2("Retargeted to %Xh, port %d\n",
        pNS->rmt_addr.sin_addr.s_addr, ntohs(pNS->rmt_addr.sin_port) );
      return ERETARGET;
  }

  return ECONNECTSOCKET;
}

/* ------------------------ */

EXPORT err_t _NB_OpenSession ( hNAME hLocalName, NETNAME *pnnFarEnd,
                              hSESSION *phSession )
{
  NBIP_SESSION *pNS;
  NAME_ENTRY   *lcl_end, *far_end;
  err_t res;
  int retargets=0;

  /* Check parameters */
  debug0("ValidatehName..\n");
  lcl_end = ValidatehName(hLocalName);
  if ( lcl_end == NULL || lcl_end->status != LCL_NAME_OK )
    return EBADPARAM;

  /* Try to find remote end */
  debug0("FindRemoteName..\n");
  far_end = FindRemoteName ( pnnFarEnd );
  if ( far_end == NULL )
    return ECANTFINDNAME;

  /* Alloc session details */

  pNS = AllocSession();
  if ( pNS == NULL )
    return ENOHANDLES;

  pNS->lcl_name = lcl_end;
  pNS->rmt_addr.sin_family = AF_INET;
  pNS->rmt_addr.sin_addr   = far_end->IPaddress;
  pNS->rmt_addr.sin_port   = htons(NBIP_SESSION_PORT);
  far_end->status = RMT_CACHED;  /* No longer needed */

  /* Create socket for connection, with retries */
  do
  {
    pNS->sid = socket ( PF_INET, SOCK_STREAM, 0 );
    if ( pNS->sid == INVALID_SOCKET )
    {
      res = ECREATESOCKET;
      break;
    }
    res = ConnectAttempt ( pNS, pnnFarEnd );
    /* May return 'ERETARGET' - this isn't really an error */
    if ( res == OK )
    {
      pNS->status = SESS_CONNECTED;
      pNS->LinkOK = true;
      *phSession = (hSESSION) pNS;
      return OK;
    }
    debug1("ConnectAttempt, error %d\n", res);
    socketclose ( pNS->sid );
  }
    while ( res == ERETARGET && ++retargets < 10 );

  /* Failed - don't even keep the remote name's IP address in cache */
  FreeSession(pNS);
  FreeNameEntry ( far_end );
  debug1("NB_OpenSession(IP) returning (res=%d)\n", res);
  return res;
}


/* ----------------------- */

#define IOV_MAX 4

EXPORT err_t _NB_SendData ( hSESSION hS, BUFCHAIN Data )
{
  NBIP_SESSION *pNS;
  BYTE hdr[4];
  int  i, len;
  struct GBP_in_out GBP;
  struct iovec iov[IOV_MAX];

  len = ChainLen(Data);
  if ( len >= 0x20000 )
  {
    FreeChain(Data);
    return EDATALEN;
  }

  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
  {
    FreeChain(Data);
    return EBADPARAM;
  }

  PutLong( hdr, len | (NBIP_SESS_DATA << 24) );

  /* We could just send the header. Instead, adding it to the chain
     gives better performance */

  GBP.pChain = Data = AddChain(Data, hdr, 4);
  if (Data == NULL)
    return ENOBUFS;

  do
  {
    i=len=0;
    while (i<IOV_MAX && GetBlockPointer(&GBP) )
    {
      iov[i].iov_base = (char *)GBP.pBlock;
      iov[i].iov_len = GBP.BlockLen;
      len+=GBP.BlockLen;
      i++;
    }

    if ( socketwritev(pNS->sid, iov, i) != len )
    {
      FreeChain(Data);
      pNS->LinkOK = false;
      return ELINKFAILED;
    }
  }
    while ( i==IOV_MAX );

  usermode_donothing();
  FreeChain(Data);
  return OK;
}

/* ----------------------- */

EXPORT err_t _NB_SendBlockData ( hSESSION hS, BYTE *where, uint datalen )
{
  NBIP_SESSION *pNS;
  BYTE hdr[4];
  err_t res;
  struct iovec iov[2];

  while ( datalen > 0x10000 ) /* Max 64K in one go */
  {
    res = _NB_SendBlockData ( hS, where, 0x10000 );
    if ( res != OK )
      return res;
    where += 0x10000;
    datalen -= 0x10000;
  }

  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return EBADPARAM;

  /* Send header */
  PutLong( hdr, datalen | (NBIP_SESS_DATA << 24) );
  iov[0].iov_base = (char *)hdr;
  iov[0].iov_len  = 4;
  iov[1].iov_base = (char *) where;
  iov[1].iov_len  = datalen;

  if ( socketwritev ( pNS->sid, iov, 2 ) != (datalen+4) )
  {
    pNS->LinkOK = false;
    return ELINKFAILED;
  }

  usermode_donothing();
  return OK;
}

/* ----------------------- */

EXPORT err_t _NB_ClearRxQueue ( hSESSION hS )
{
#ifdef LONGNAMES
  NBIP_SESSION *pNS;
  BYTE buf[4];

  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return EBADPARAM;
  if ( !ReadData(pNS->sid, buf, 4, 0, MSG_PEEK) )
  {
    return OK;
  }
  return ERXNOTREADY;
#endif
  (void) hS;
  /* ClearRxQueue - not needed? !! */
  return OK;
}

/* ----------------------- */

EXPORT err_t _NB_GetData ( hSESSION hS, BUFCHAIN *pOutData, int timeout )
{
  BUFCHAIN Chain;
  struct GBP_in_out GBP;
  NBIP_SESSION *pNS;
  BYTE hdr[4];
  uint  len;

  debug0(" Rd");

  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return EBADPARAM;

  /* Get header */
retry:
  if ( !ReadData(pNS->sid, hdr, 4, timeout, 0) )
  {
    pNS->LinkOK = false;
    return ETIMEOUT;
  }

  len = GetLong(hdr);
  if ( (len >> 24) != NBIP_SESS_DATA ) /* Keepalive packet? */
  {
    debug1("  Packet header %Xh", len);
    goto retry;
  }

  len &= 0x1FFFF; /* Max 128K of data */
  Chain = AllocBlankChain(len);
  if ( Chain == NULL )
    return ENOBUFS;

  GBP.pChain = Chain;

  while ( GetBlockPointer(&GBP) )
  {
    if ( !ReadData(pNS->sid, GBP.pBlock, GBP.BlockLen, timeout, 0) )
    {
      pNS->LinkOK = false;
      FreeChain(Chain);
      return ETIMEOUT;
    }
  }

  debug1("=%d\n", len);

  *pOutData = Chain;
  return OK;
}

/* ----------------------- */

EXPORT err_t _NB_GetBlockData ( hSESSION hS, BYTE *where, uint *len_in_out,
                                                  int timeout )
{
  NBIP_SESSION *pNS;
  BYTE hdr[4];
  uint  len;

  debug0(" RdB");

  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return EBADPARAM;

  /* Get header */
retry:
  if ( !ReadData(pNS->sid, hdr, 4, timeout, 0) )
  {
    pNS->LinkOK = false;
    return ETIMEOUT;
  }

  len = GetLong(hdr);
  if ( (len >> 24) != NBIP_SESS_DATA ) /* Keepalive packet? */
  {
    debug1("Packet header %Xh", len);
    goto retry;
  }

  len &= 0x1FFFF; /* Max 128K of data */
  if ( !ReadData(pNS->sid, where, len, timeout, 0) )
  {
    pNS->LinkOK = false;
    return ETIMEOUT;
  }

  debug1("=%d\n", len);
  *len_in_out = len;
  return OK;
}

/* ----------------------- */

EXPORT bool _NB_LinkOK ( hSESSION hS )
{
  NBIP_SESSION *pNS;
  pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return false;
  return pNS->LinkOK;
}

/* ----------------------- */

EXPORT err_t _NB_CloseSession ( hSESSION hS )
{
  NBIP_SESSION *pNS;

  debug0("CloseSession()\n");

  pNS = ValidatehSession(hS);
  if ( pNS != NULL )
  {
    /* Kill the connection, that's it */
    socketclose(pNS->sid);
    FreeSession(pNS);
  }
  return OK;
}

/* ----------------------- */

EXPORT char * _NB_DescribeLink ( hSESSION hS )
{
  static char namebuf[40];
  NBIP_SESSION *pNS = ValidatehSession(hS);
  if ( pNS == NULL )
    return NULL;

  sprintf(namebuf, "%s port %d", inet_ntoa(pNS->rmt_addr.sin_addr),
                                 htons(pNS->rmt_addr.sin_port ));

  return namebuf;
}


/* Init & Shutdown routines ====================================== */

EXPORT void _NB_Shutdown(void)
{
  int i;
  /* Important: we de-register the event handler first, because
     socketclose() calls the internet event. We don't want this
     setting a callback, because we'll be dead by the time it happens */

  if ( EventsClaimed )
  {
    EventsClaimed = false;
    _swix(OS_Release, _INR(0,2), EventV, (int)EventFn, LM_pw);
    _swix(OS_Byte, _INR(0,1), 13, Internet_Event); /* Disable event */
  }

  if ( NBNS_Socket != INVALID_SOCKET )
  {
    socketclose(NBNS_Socket);
    NBNS_Socket = INVALID_SOCKET;
  }

  for (i=0; i < MAX_SESSIONS; i++)
    if ( NB_Sessions[i].status == SESS_CONNECTED )
    {
      socketclose ( NB_Sessions[i].sid );
      NB_Sessions[i].status = SESS_FREE;
    }

  RemoveCallbacks();
}

/* NB_Startup() -----------------------------------------------------

   On startup, we have to

   i) Set the NetBIOS scope ID
   ii)  create a socket for the NBNS daemon
   iii) install an Internet Event handler
   iv) register our name on the net

*/

static int On  = 1;

static struct sockaddr_in Broadcast_sin;


EXPORT err_t _NB_Startup(void)
{
  err_t res;
  int i;
  struct sockaddr_in sa;
  struct ifreq IFR;

  debug0("Starting TCP/IP transport\n");

  /* Clear out name table & session table */

  for ( i=0; i < MAX_NAMES; i++ )
    NB_NameTable[i].status = NAME_FREE;

  for (i=0; i < MAX_SESSIONS; i++)
    NB_Sessions[i].status = SESS_FREE;

  NB_FirstFreeName = 0;
  NBNS_RequestCount = 0;

  Stat_ClassMask |= SCLASS_IP;

  SetScopeID(getenv("LanMan$ScopeID"));

  /* Set up broadcast addresses */

  Broadcast_sin.sin_family = AF_INET;
  Broadcast_sin.sin_port   = htons(NBNS_PORT);
  Broadcast_sin.sin_addr.s_addr = INADDR_BROADCAST;
  NBNS_Broadcast = (struct sockaddr *) &Broadcast_sin;

  /* Create a socket for the NBNS server (checks TCPIP works!) */

  NBNS_Socket = socket ( PF_INET, SOCK_DGRAM, 0 );
  if ( NBNS_Socket == INVALID_SOCKET )
  {
    debug0("Couldn't create socket\n");
    return ENOSOCKETS;
  }

  /* Get a network address */

  strcpy ( IFR.ifr_name, LM_Vars.drivername );
      /* Will be Inet$EtherType unless overridden */

  if ( socketioctl ( NBNS_Socket, SIOCGIFADDR, (char *)&IFR ) < 0 )
  {
    debug1("Couldn't find IP address for interface '%s'\n",
           LM_Vars.drivername);
    (void) socketclose(NBNS_Socket);
    NBNS_Socket = INVALID_SOCKET;
    return ENOIFADDR;
  }

  NB_IPAddress = ((struct sockaddr_in *)&IFR.ifr_addr)->sin_addr;

  /* Invent machine name from host address if needs be */

  if ( LM_Vars.machinename[0] == 0 )
  {
    union in_addr_byte iab;
    iab.ina = NB_IPAddress;

    sprintf( LM_Vars.machinename, "ARMIP%02X%02X%02X%02X",
                iab.nb[0], iab.nb[1], iab.nb[2], iab.nb[3] );
  }

#ifdef DEBUG
  show_scope(NB_ScopeID);
  debug2("Machine name is '%s', IP address %s\n", LM_Vars.machinename,
         inet_ntoa ( NB_IPAddress ));
#endif

  /* Bind socket */
  sa.sin_family = AF_INET;
  sa.sin_port   = htons(NBNS_PORT);
  sa.sin_addr.s_addr = INADDR_ANY;

  if ( bind( NBNS_Socket, (struct sockaddr *)&sa, sizeof(sa) ) < 0 )
  {
    /* Socket will be closed on exit */
    debug0("Couldn't bind socket\n");
    (void) socketclose(NBNS_Socket);
    NBNS_Socket = INVALID_SOCKET;
    return ENOSOCKETS;
  }

  /* Allow broadcasts */
  setsockopt ( NBNS_Socket, SOL_SOCKET, SO_BROADCAST, &On, sizeof(int));

  /* Generate events */
  socketioctl ( NBNS_Socket, FIOASYNC, &On );

  /* It's now ready for action - set up internet event handler */

  /*CallbackSet = false;*/
  if (!EventsClaimed)
  {
    _swix(OS_Claim, _INR(0,2), EventV, (int) EventFn, LM_pw);
    _swix(OS_Byte, _INR(0,1), 14, Internet_Event);  /* Enable event */
    EventsClaimed = true;
    debug0("Events claimed\n");
  }

//  strcpy ( LM_Vars.drivername, "TCP/IP");

  /* Now try to register name... */

  debug1("Setting our local name as `%s'\n", LM_Vars.machinename);
  res = _NB_AddLocalName ( ntMACHINE, LM_Vars.machinename, &NB_MachineName);
  if (res != OK)
    _NB_Shutdown();

  return res;
}

/* NB_InternetGone() ---------------------------

  The Internet module has disappeared.  Mark all sessions as disconnected and
  pray that a new Internet module comes back before anything tries to do
  anything with a session.

 */

static void _NB_InternetGone(void)
{
  int i;

  for (i=0; i < MAX_SESSIONS; ++i) {
    if (NB_Sessions[i].status == SESS_CONNECTED) {
      NB_Sessions[i].sid = INVALID_SOCKET;
      NB_Sessions[i].LinkOK = false;
    }
  }

  NBNS_Socket = INVALID_SOCKET;

  RemoveCallbacks();
}

/* NB_InternetInit() ---------------------------

  The Internet module has arrived.  Mark all sessions as disconnected and
  try to re-initialise things.  However, we must be careful - only do this
  if we saw the old Internet module dying, because this might just be the
  main ROM one sending the service call on a callback.  We must only reinit
  if we saw a dying service call.

 */

static void _NB_InternetInit(void)
{
  if (NBNS_Socket == INVALID_SOCKET)
  {

    int i;

    for (i=0; i < MAX_SESSIONS; ++i) {
      if (NB_Sessions[i].status == SESS_CONNECTED) {
        NB_Sessions[i].sid = INVALID_SOCKET;
        NB_Sessions[i].LinkOK = false;
      }
    }

    _NB_Startup();
  }
}

/* Setup routine ------------------------------- */

static struct NETBIOS_TRANSPORT NBIP_Transport;

void NB_NBIP_Setup ( void )
{
  struct NETBIOS_TRANSPORT *p;
  NB_ActiveTransport = p = &NBIP_Transport;

  p->pfnStartup	 = _NB_Startup;
  p->pfnShutdown = _NB_Shutdown;
  p->pfnFormatName = _NB_FormatName;
  p->pfnDecodeName = _NB_DecodeName;
  p->pfnMatchName = _NB_MatchName;
  p->pfnAddLocalName = _NB_AddLocalName;
  p->pfnRemoveLocalName = _NB_RemoveLocalName;
  p->pfnOpenSession = _NB_OpenSession;
  p->pfnSendData = _NB_SendData;
  p->pfnSendBlockData = _NB_SendBlockData;
  p->pfnClearRxQueue = _NB_ClearRxQueue;
  p->pfnGetData = _NB_GetData;
  p->pfnGetBlockData = _NB_GetBlockData;
  p->pfnLinkOK = _NB_LinkOK;
  p->pfnCloseSession = _NB_CloseSession;
  p->pfnFindNames = _NB_FindNames;
  p->pfnDescribeLink = _NB_DescribeLink;
  p->pfnInternetGone = _NB_InternetGone;
  p->pfnInternetInit = _NB_InternetInit;
}
