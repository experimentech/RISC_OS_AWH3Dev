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
*  Stats.C -- Statistics gathering
*
*  Versions
*  21-08-95 INH Original
*
*/

/* Standard includes */

#include <stdio.h>

/* Our includes */

#include "stdtypes.h"
#include "Stats.h"

int Stat_StatTable [STA_MAXSTATS];
int Stat_ClassMask;

struct stat_info
{
  int stat_no;
  int sclass;
  char *name;
};

#ifdef DEBUG
static struct stat_info statinfo[] =
{
  STA_SERIOUS_BARF, SCLASS_GENERAL,  "Internal errors",
  STA_NETTX_PKTS,   SCLASS_NETBEUI,  "Total Tx packets",
  STA_NETRX_EVTS,   SCLASS_NETBEUI,  "Total Rx events",
  STA_NETRX_PKTS,   SCLASS_NETBEUI,  "Total Rx packets",
  STA_NETRX_OWNTX,  SCLASS_NETBEUI,  "Rx: Own transmission",

  STA_LLCRX_PKTS,   SCLASS_NETBEUI,  "LLC: Rx pkts total",
  STA_LLCRX_NOCONN, SCLASS_NETBEUI,  "LLC: Ignored rx packets",
  STA_LLCRX_TOOSHORT,SCLASS_NETBEUI, "LLC: Rx Too short",
  STA_LLCRX_UIDATA, SCLASS_NETBEUI,  "LLC: Rx Datagram",
  STA_LLCRX_UFORMAT,SCLASS_NETBEUI,  "LLC: Rx U-format",

  STA_LLCRX_SFORMAT,SCLASS_NETBEUI,  "LLC: Rx S-format",
  STA_LLCRX_IFORMAT,SCLASS_NETBEUI,  "LLC: Rx I-format",
  STA_LLCRX_DATA,   SCLASS_NETBEUI,  "LLC: Rx Data pkts accepted",
  STA_LLCRX_REJDATA,SCLASS_NETBEUI,  "LLC: Rx Data pkts rejected",
  STA_LLC_TXPACKETS,SCLASS_NETBEUI,  "LLC: Tx Data pkts sent",

  STA_LLCRX_PKTACKS,SCLASS_NETBEUI,  "LLC: Tx Data pkts acked",
  STA_LLCRX_REJECTS,SCLASS_NETBEUI,  "LLC: Tx Data pkts rejected",
  STA_LLCRX_RESENDS,SCLASS_NETBEUI,  "LLC: Tx Data pkts re-sent",
  STA_LLC_OPENREQ,  SCLASS_NETBEUI,  "LLC: Open Conn requests",
  STA_LLCRX_CONN,   SCLASS_NETBEUI,  "LLC: Connections made",

  STA_LLC_CLOSEREQ, SCLASS_NETBEUI,  "LLC: Close Conn requests",
  STA_LLCRX_DISCON, SCLASS_NETBEUI,  "LLC: Connections ended",
  STA_LLCRX_FRMR,   SCLASS_NETBEUI,  "LLC: Abort with FRMR error",
  STA_LLCRX_DISC,   SCLASS_NETBEUI,  "LLC: Abort with DISC req",
  STA_LLC_T1FAIL,   SCLASS_NETBEUI,  "LLC: Abort with T1 timeout",

  STA_LLCRX_UNKNOWNU, SCLASS_NETBEUI,"LLC: Unknown U-format pkt",
  STA_LLC_T1EXPIRE, SCLASS_NETBEUI,  "LLC: T1 timeouts",

  STA_IP_EVENTS,    SCLASS_IP,       "IP:  Internet events",
  STA_IP_RXDGRAM,   SCLASS_IP,       "IP:  Receive datagrams",


  -1, 0, NULL
};

/* -------------- */

void Stat_Show ( void )
{
  int i;
  for ( i=0; statinfo[i].stat_no >= 0; i++ )
  {
    if ( statinfo[i].sclass & Stat_ClassMask )
      printf("%-30s: %d\n", statinfo[i].name,
             Stat_StatTable[statinfo[i].stat_no] );
  }
  printf("\n");
}
#endif

/* ------------- */

bool Stat_Init ( void )
{
  int i;

  Stat_ClassMask = SCLASS_GENERAL;
  for (i=0; i<STA_MAXSTATS; i++)
    Stat_StatTable[i] = 0;

  return true;
}
