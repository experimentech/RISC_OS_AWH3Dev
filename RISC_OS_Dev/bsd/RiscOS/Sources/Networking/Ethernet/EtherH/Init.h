/*
 * Copyright (c) 2002, Design IT
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
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
/**************************************************************************
 * Title:       RISC OS Ethernet Driver Source
 * Authors:     Douglas J. Berry, Gary Stephenson
 * File:        init.h
 *
 * Copyright © 1992 PSI Systems Innovations
 * Copyright © 1994 i-cubed Limited
 * Copyright © 1994 Network Solutions
 * Copyright © 2000 Design IT
 *
 * Initial Revision 1.0         1st December 1994 GS
 *
 * History
 *
 ***************************************************************************/

/*
 * memory testing
 */
#ifdef DRIVER16BIT
#define PAT_LEN         34
#else
#define PAT_LEN         18
#endif
#define PAT_MID         (PAT_LEN >> 1)
#define O(n)            (1 << n)
#define Z(n)            (O(n) ^ 0xffff)

/*
 * loopback testing
 */
#define LB_FIFOLEN      8           /* FIFO length during loopback */
#define TESTP_LEN       60          /* length of loopback test packet */
#define POLYNOMIAL      0x04c11db7  /* polynomial for CRC calculation */

/*
 * timeout values to use during POST
 */
#define CC_TIMEO        (HZ / 12)    /* cable checking (4) */
#define LB_TIMEO        (HZ / 8)    /* loopback transmissions */
#define STP_TIMEO       (HZ / 8)    /* STOP command to set RST */
#define EXCESSIVE_COLL  6          /* used during cable test */

/* no. of bytes to junk when reading CRC from FIFO */
#define N_JUNK          (TESTP_LEN % LB_FIFOLEN)

#if (N_JUNK > (LB_FIFOLEN - CRC_LEN))  /* does CRC wrap around end of FIFO? */
error "Bad value for TESTP_LEN"
#endif /* N_JUNK < 0 */

typedef struct _tp
{
    u_char src_addr[HW_ADDR_LEN];
    u_char dst_addr[HW_ADDR_LEN];
    u_short ptype;
    u_char bulk_data[TESTP_LEN - PACK_HDR_LEN];
    u_char crc_bytes[CRC_LEN];
} TestPacket;

/*
#if sizeof(TestPacket) != (TESTP_LEN + CRC_LEN)
 #ERROR: bad size for TestPacket typedef
#endif
*/

/* MEMC1a testing */
#define MEMC1a 0x112

/*
 * Public functions.
 */
int    eh_post(struct eh_softc *, int);
void   eh_postinit(void);
int    eh_setup(struct eh_softc *);
int    get_goodlink(struct eh_softc *);
void   eh_reset_card(struct eh_softc *);
u_int *eh_set_rom_page(struct eh_softc *, u_int);
u_long calc_crc(u_char *, int);

/*
 * Public data.
 */
extern int          ehcnt;
extern volatile int pre_init;
extern volatile int pre_reset;
extern char         eh_lasterr[];
extern struct       eh_softc *eh_softc[MAX_NUM_SLOTS];

/* EOF init.h */
