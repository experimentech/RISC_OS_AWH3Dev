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
*     STDTYPES.H - Header for standard types
*
*     05-02-92 INH    Original
*
*/

#include "DebugLib/DebugLib.h"

#define debug0(f) dprintf((__FILE__, f))
#define debug1(f,a) dprintf((__FILE__, f,a))
#define debug2(f,a,b) dprintf((__FILE__, f,a,b))
#define debug3(f,a,b,c) dprintf((__FILE__, f,a,b,c))

/* For RISCOS */
typedef enum { false, true }    bool;
typedef unsigned char           BYTE;
typedef unsigned short int      WORD;
typedef unsigned int            LONG;
typedef unsigned int            DWORD;
typedef unsigned long long      QWORD;
typedef int                     err_t;

#include "sys/types.h"

#define min(a,b)  ((a)<(b) ? (a):(b))
#define max(a,b)  ((a)>(b) ? (a):(b))

/* Return error codes */
#define  OK               0
#define  EHOWDTHATHAPPEN  0
#define  EBADPARAM        1
#define  ENOCONN          2
#define  EOUTOFMEM        3
#define  ELINKFAILED      4
#define  ENOHANDLES       5
#define  ERXNOTREADY      6
#define  ELINKEXISTS      7
#define  ETIMEOUT         8
#define  ENAMEEXISTS      9
#define  ECANTFINDNAME    10
#define  EDATALEN         11

/* SMB errors */
#define  ESERVERROR       12
#define  EDOSERROR        13
#define  EHARDERROR       14
#define  EPROTOCOLERR     15
#define  ENOMOREFILES     16
#define  EFILENOTFOUND    17
#define  EPATHNOTFOUND    18
#define  ENOFHANDLES      19
#define  ENOACCESS        20
#define  EFILEEXISTS      21
#define  EBADPASSWD       22
#define  EBADNAME         23
#define  EBADDRV          24
#define  ENORISCOS2       25
#define  ENOGBPB          26
#define  ENOUNBUFF        27
#define  ENOTINSTALLED    28
#define  ENOTPRESENT      29
#define  ENOWILDCARD      30
#define  EATTRIBREAD      31
#define  EATTRIBWRITE     32
#define  ESHARING         33
#define  ECONNLIMIT       34
#define  ENOSUCHSHARE     35

/* Installation errors */
#define  ECMDLINE         36
#define  ERISCOSVER       37
#define  EINITFAILED      38
#define  EDRIVERNAME      39
#define  EDRIVERTYPE      40
#define  EDRIVERVER       41

#define  ECONNEXISTS      42
#define  EPACKETTYPE      43
#define  EMBUFMODULE      44

#define  ERPCERROR        45
#define  EDISCFULL        46
#define  EDIRNOTEMPTY     47
#define  EBADRENAME       48
#define  EFILEHANDLE      49

/* NetBIOS-over-IP errors */
#define  ECREATESOCKET    50
#define  ECONNECTSOCKET   51
#define  ECONNREJECT      52
#define  ERETARGET        53
#define  ENOIFADDR        54
#define  ENOSOCKETS       55

/* More errors */
#define  EBOOTREENTRY     56
#define  EBOOTERROR       57
#define  EHOMEDIRNAME     58
#define  EHOMEDIRCONN     59
#define  EUSERUNKNOWN     60
#define  EACCDISABLED     61
#define  ELANMANFSINUSE   62

#define  EUSELASTSETOSERR 0x10000 /* Signifies non-LanMan error */

#define  OPEN_READ        0
#define  OPEN_WRITE       1
#define  OPEN_READWRITE   2

/* DOS attributes */
#define ATTR_NORM 0
#define ATTR_RO   1
#define ATTR_HID  2
#define ATTR_SYS  4
#define ATTR_VOL  8
#define ATTR_DIR  0x10
#define ATTR_ARC  0x20

typedef struct
{
  int  attr;
  uint utime;
  int  length;
  int  riscos_type;
} DOS_ATTRIBS;

/* RISCOS attributes */
#define ROA_READ   ((1<<0) | (1<<4))
#define ROA_WRITE  2
#define ROA_LOCKED 8

typedef struct
{
  uint  loadaddr;
  uint  execaddr;
  uint  flags;
} RISCOS_ATTRIBS;
