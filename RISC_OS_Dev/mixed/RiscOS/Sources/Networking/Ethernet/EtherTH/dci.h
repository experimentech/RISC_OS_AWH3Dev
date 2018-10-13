/*
 * Copyright (c) 2017, Colin Granville
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name Colin Granville may not be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#ifndef DCI_H
#define DCI_H

#include <stdint.h>
#include "sys/types.h"
#include "net/ethernet.h"
#include "sys/dcistructs.h"
#include "swis.h"
/* set up mbuf macros */
#define MBCTL_NAME      mbctl
#define INET
#include "sys/mbuf.h"

/************************************************************************

                   Arguments passed to DCI swis

 ************************************************************************/

/******************************************************
        DCIVersion  SWI - offset 0
        Entry:
                r0 = flags
        Exit:
                r1 = version
 ******************************************************/

typedef struct
{
        unsigned int    flags;
        int             DCIVersion_out;         /* return DCI version supported by the driver */
} dci_DCIVersionArgs_t;

/******************************************************
        Inquire  SWI - offset 1
        Entry:
                r0 = flags
                r1 = unit
        Exit:
                r2 = driver_flags
 ******************************************************/

typedef struct
{
        unsigned int    flags;
        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        int             inquire_flags_out;      /* See INQ_ defines in dcistructs.h */
} dci_InquireArgs_t;

/******************************************************
        GetNetworkMTU  SWI - offset 2
        Entry:
                r0 = flags
                r1 = unit
        Exit:
                r2 = mtu
 ******************************************************/

typedef struct
{
        unsigned int    flags;
        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        int             mtu_out;                /* return mtu */
} dci_GetNetworkMTUArgs_t;

/******************************************************
        SetNetworkMTU  SWI - offset 3
        Entry:
                r0 = flags
                r1 = unit
                r2 = mtu
        Exit:
 ******************************************************/

typedef struct
{
        unsigned int    flags;
        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        int             mtu;                    /* MTU to set */
} dci_SetNetworkMTUArgs_t;

/******************************************************
        Transmit  SWI - offset 4
        Entry:
                r0 = tx_flags
                r1 = unit
                r2 = ethernet packet type
                r3 = pointer to a list of mbufs to send
                r4 = pointer to destination mac address
                r5 = pointer to source mac address if TX_FAKESOURCE is set in flags
        Exit:
 ******************************************************/

typedef struct
{
        unsigned int    tx_flags;               /* See TX_ defines in dcistructs.h */
        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        unsigned int    ethertype;              /* Ethernet frame type. See ETHERTYPE_ defines in net/ethernet.h */
        struct mbuf*    mbuf_list;              /* list of mbufs to send */
        const uint8_t*  dst_net_addr;           /* Destination ethernet address */
        const uint8_t*  src_net_addr;           /* Source ethernet address if TX_FAKESOURCE flag set in flags*/
} dci_TransmitArgs_t;

/******************************************************
        Filter  SWI - offset 5
        Entry:
                r0 = filter flags
                r1 = unit
                r2 = (frame_level << 16) | frame_type
                r3 = address_level
                r4 = error_level
                r5 = handler function private word
                r6 = handler function
        Exit:

        Note:
                This swi manages the claiming or releasing of filters.
 ******************************************************/

typedef struct
{
        unsigned int    filter_flags;           /* See FILTER_ defines in dcistructs.h */
        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        unsigned int    frame_type;             /* (FRMLVL_ << 16) | ETHERTYPE_ See defines in dcistructs.h  and net/ethernet.h*/
        unsigned int    addrlvl;                /* See ADDRLVL_ defines in dcistructs.h  - Not used when releasing filter */
        unsigned int    errlvl;                 /* See ERRLVL_ defines in dcistructs.h   - Not used when releasing filter*/
        void*           handler_fn_pw_r12;      /* Private word for handler_fn */
        void (*handler_fn)(Dib*, struct mbuf*); /* handler function - must be called fro assembler to set R12 to pw*/
} dci_FilterArgs_t;

/******************************************************
        Stats  SWI - offset 6
        Entry:
                r0 = reason code        0 =  Enquire which stats fields are valid.
                                                a struct_stats field value of:
                                                        0 indicates that the field is unused.
                                                       ~0 (ie all bits set) indicates the field is used.
                                        1 =  Read stats
                r1 = unit
                r2 = pointer to struct stats to be filled in by client module
        Exit:
 ******************************************************/

typedef struct
{
        unsigned int    stat_reason_code;
                        #define dci_STAT_INQUIRE 0
                        #define dci_STAT_READ    1

        int             unit;                   /* As supplied by driver when registering interface in dib struct */
        struct stats*   stats;                  /* struct stats filled in by client */
                        #define dci_STAT_VALID  ~0
} dci_StatsArgs_t;

/******************************************************
        Multicast  SWI - offset 7
        Entry:
                r0 = multicast_flags
                r1 = unit
                r2 = ethernet frame type
                r3 = mac address pointer - set by caller
                r4 = ip address pointer  - set by caller
                r5 = handler function private word
                r6 = handler function
        Exit:
 ******************************************************/

typedef struct
{
        unsigned int            multicast_flags;/* See MULTICAST_ defines in dcistructs.h */
        int                     unit;           /* As supplied by driver when registering interface in dib struct */
        unsigned int            ether_type;     /* Ethernet Packet type. See ETHERTYPE_ defines in net/ethernet.h */
        const uint32_t*         net_addr;       /* mac address */
        const uint32_t*         ip_addr;        /* ip adddress */
        void*                   pw;             /* handler function private word */
        void (*handler_fn)(void);               /* handler function */
} dci_MulticastRequestArgs_t;


_kernel_oserror* dci_mbufOpenSession(void);
_kernel_oserror* dci_mbufCloseSession(void);
#endif
