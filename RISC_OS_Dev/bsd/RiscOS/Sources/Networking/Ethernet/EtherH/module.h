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
#ifndef Module_h
#define Module_h

#define MICRODELAY(n) eh_microdelay((n),(const char *)en->cntrl_reg)
#define UNUSED(k)     (k)=(k)
#define MIN(a,b)      (((a)<(b))?(a):(b))
#define MAX(a,b)      (((a)>(b))?(a):(b))

/*
 * Message aliases.
 */
enum
{
    M0_WARNING_UK_INTERFACE = 0,
    M1_WARNING_UK_MAU,
    M2_EXPANSION_SLOT,
    M3_NETWORK_SLOT,
    M4_DIAG_START,
    M5_DIAG_FINISH,
    M6_STAT_HEADING,
    M7_STAT_MEASURE,
    M8_STAT_LOCATION,
    M9_STAT_EUI48,
    M10_STAT_CONTROLLER,
    M11_TYPE_VIRTUAL,
    M12_TYPE_FAULTY,
    M13_TYPE_ETHERLAN,
    M14_STAT_UNIT,
    M15_STAT_DRIVER,
    M16_STAT_MEDIA,
    M17_STAT_AUTHOR,
    M18_PACKET_SENT,
    M19_PACKET_RECEIVED,
    M20_STAT_BUFFER,
    M21_MAU_NONE,
    M22_MAU_10BT,
    M23_MAU_10B2,
    M24_MAU_MICRO_10BT,
    M25_MAU_MICRO_10B2,
    M26_MAU_UK,
    M27_MAU_INTEGRATED_10BT,
    M28_MAU_INTEGRATED_10B2,
    M29_MAU_INTEGRATED_UK,
    M30_IO_SEND_ERR,
    M31_IO_RECEIVE_ERR,
    M32_IO_COLLISIONS,
    M33_IO_REJECTS,
    M34_IO_NOMBUFS,
    M35_DMA_AVAILABLE,
    M36_DMA_UNAVAILABLE,
    M37_IO_OVERWRITES,
    M38_LINK_GOOD,
    M39_LINK_BAD,
    M40_POLARITY_CORRECT,
    M41_POLARITY_INCORRECT,
    M42_STAT_LINK,
    M43_FRAME_CLIENTS,
    M44_FRAME_TYPE,
    M45_MCAST_NOT_ENABLED,
    M46_MCAST_NON_ZERO,
    M47_MCAST_SUMMARY,
    M48_MCAST_REGS,
    M49_MODE_HEADER,
    M50_MODE_NORMAL,
    M51_MODE_MULTICAST,
    M52_MODE_PROMISCUOUS,
    M53_MODE_UNKNOWN,
    M54_MODE_WITH_ERRORS,
    M55_MODE_WITHOUT_ERRORS,
    M56_DRIVER_WARNING,
    M57_DRIVER_NOT_INIT,
    M58_DRIVER_NO_MBM,
    M59_DRIVER_LAST_LOG,
    M60_DRIVER_LAST_ERR
};
    
/*
 * Public functions.
 */
int eh_dciversion(_kernel_swi_regs *);
int eh_inquire(_kernel_swi_regs *);
int eh_getnetworkmtu(_kernel_swi_regs *);
int eh_setnetworkmtu(_kernel_swi_regs *);
int eh_transmit(_kernel_swi_regs *);
int eh_filter(_kernel_swi_regs *);
int eh_stats(_kernel_swi_regs *);
int eh_multicastrequest(_kernel_swi_regs *);
int free_filter(struct eh_softc *, int, u_char *);
_kernel_oserror *eh_error(int);
const char *eh_message(int, const char *, const char *, const char *);
const char *eh_sprint_mac(const u_char *);
void eh_call_protocol(DibRef, struct mbuf *, void *, int);
void eh_microdelay(int, const char *);
_kernel_oserror *mb_closesession(void);

/*
 * Public data.
 */
extern volatile int mbuf_present;
extern void *module_wsp;

#endif /* Module_h */

/* EOF Module.h */
