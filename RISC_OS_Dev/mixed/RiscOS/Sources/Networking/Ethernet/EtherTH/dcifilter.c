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


#include <stdlib.h>
#include <string.h>

#include "sys/queue.h"

#include "debug.h"

#include "dcifilter.h"
#include "dcierror.h"
#include "utils.h"

/*
 *      Ethernet 2 (e2) filters can either be:
 *              0 - 1 FRMLVL_E2MONITOR filter handler
 *          or
 *              0 - 1 FRMLVL_E2SINK and/or 0 - many FRMLVL_E2SPECIFIC filter handlers
 *
 *      Ethernet 1 or ieee filters can be:
 *              0 - 1 FRMLVL_IEEE filter handle
 *
 *
 *      To differentiate between ethernet 1 and 2 filters ethernet 2 has an
 *      ethernet frame type > 1500 (ETHERMTU)
 */


typedef struct handler_t
{
        TAILQ_ENTRY(handler_t)  q_next;
        uint32_t                flags;                  /* flags from Filter swi */
        uint32_t                ethertype;              /* See ETHERTYPE_ defines in net/ethernet.h */
        uint32_t                frmlvl;                 /* See FRMLVL_ defines in dcistructs.h */
        uint32_t                addrlvl;                /* See ADDRLVL_ defines in dcistructs.h */
        uint32_t                errlvl;                 /* See ERRLVL_ defines in dcistructs.h */
        void*                   handler_fn_pw_r12;      /* Private word for handler_fn */
        void (*handler_fn)(Dib*, struct mbuf*);         /* handler function - must be called from assembler to set R12 to pw*/
} handler_t;

TAILQ_HEAD(handler_list_t,handler_t);                   /* declares struct handler_list_t */

struct dcifilter_t
{
        handler_t*              ieee;                   /* Ethernet 1 handler */
        struct handler_list_t   e2list;                 /* Ethernet 2 handler list */
        const Dib*              dib;
        uint32_t                unwanted_frames;        /* frames not matched by any filter */
};

#ifdef DEBUGLIB

#define dp(field) dprintf_here(#field" = %d %#p\n", (int32_t)mb->##field, (void*)mb->##field)

static void print_mbuf(const char* name, const struct mbuf* mb)
{
       dprintf_here("mbuf: %s = %#p\n", name, (void*)mb);
       dp(m_next);
       dp(m_list);
       dp(m_off);
       dp(m_len);
       dp(m_inioff);
       dp(m_inilen);
       dp(m_type);
       dp(m_sys1);
       dp(m_sys2);
       dp(m_sys2);
       dp(m_pkthdr.len);
       dp(m_pkthdr.rcvif);
       dprintf_here("\n");

}

static void print_handler_args(handler_t* handler, dci_FilterArgs_t* args)
{
        dprintf_here("hand: fl=%02x et=%04x adl=%02x erl=%02x pw=%#p fn=%#p\n", handler->frmlvl,
                                                                        handler->ethertype,
                                                                        handler->addrlvl,
                                                                        handler->errlvl,
                                                                        (void*)handler->handler_fn_pw_r12,
                                                                        (void*)handler->handler_fn);
        dprintf_here("args: fl=%02x et=%04x adl=%02x erl=%02x pw=%#p fn=%#p\n", GET_FRAMELEVEL(args->frame_type) ,
                                                                        GET_FRAMETYPE(args->frame_type),
                                                                        args->addrlvl,
                                                                        args->errlvl,
                                                                        (void*)args->handler_fn_pw_r12,
                                                                        (void*)args->handler_fn);
}

#endif

_kernel_oserror* dcifilter_new(const Dib* dib, dcifilter_t** out)
{
        if (out == NULL) return dcierror(EINVAL);

        *out = NULL;

        dcifilter_t* filter = calloc(1, sizeof(dcifilter_t));
        if (filter == NULL) return dcierror(ENOMEM);

        TAILQ_INIT(&filter->e2list);
        filter->dib = dib;
        *out        = filter;
        return NULL;
}
void* dcifilter_delete(dcifilter_t* filter)
{
        if (filter == NULL) return NULL;

        while (!TAILQ_EMPTY(&filter->e2list))
        {
                handler_t* item = TAILQ_FIRST(&filter->e2list);
                TAILQ_REMOVE(&filter->e2list, item, q_next);
                free(item);
        }

        if (filter->ieee) free(filter->ieee);

        free(filter);
        return NULL;
}

void dcifilter_release_module(dcifilter_t* filter, void *pw)
{
        if (filter == NULL) return;

        handler_t* handler;
        handler_t* next;
        unsigned int frame_type;
                
        handler = filter->ieee;
        if ((handler != NULL) && (handler->handler_fn_pw_r12 == pw))
        {
                filter->ieee = 0;
                frame_type = 0;
                SET_FRAMETYPE(frame_type, handler->ethertype);
                SET_FRAMELEVEL(frame_type, handler->frmlvl);
                _swix(OS_ServiceCall, _INR(0,4), filter->dib, Service_DCIFrameTypeFree,
                                           frame_type, handler->addrlvl, handler->errlvl);
                dprintf_here("released tp=%x ad=%x er=%x\n", frame_type, handler->addrlvl, handler->errlvl);
                free(handler);
        }

        for (handler = TAILQ_FIRST(&filter->e2list); handler; handler = next)
        {
                next = TAILQ_NEXT(handler, q_next);
                if (handler->handler_fn_pw_r12 == pw)
                {
                        TAILQ_REMOVE(&filter->e2list, handler, q_next);
                        frame_type = 0;
                        SET_FRAMETYPE(frame_type, handler->ethertype);
                        SET_FRAMELEVEL(frame_type, handler->frmlvl);
                        _swix(OS_ServiceCall, _INR(0,4), filter->dib, Service_DCIFrameTypeFree,
                                                      frame_type, handler->addrlvl, handler->errlvl);
                        dprintf_here("released tp=%x ad=%x er=%x\n", frame_type, handler->addrlvl, handler->errlvl);
                        free(handler);
                }
        }
}

uint32_t dcifilter_getUnwantedFrames(dcifilter_t* filter)
{
        return filter == NULL ? 0 : filter->unwanted_frames;
}


static __inline int handler_match_args_claim( handler_t* handler, dci_FilterArgs_t* args)
{
        return (handler->frmlvl            == GET_FRAMELEVEL(args->frame_type) &&
                handler->ethertype         == GET_FRAMETYPE(args->frame_type) &&
                handler->addrlvl           == args->addrlvl &&
                handler->errlvl            == args->errlvl &&
                handler->handler_fn_pw_r12 == args->handler_fn_pw_r12 &&
                handler->handler_fn        == args->handler_fn);
}

static __inline int handler_match_args_release( handler_t* handler, dci_FilterArgs_t* args)
{
        return (handler->frmlvl            == GET_FRAMELEVEL(args->frame_type) &&
                handler->ethertype         == GET_FRAMETYPE(args->frame_type) &&
                handler->handler_fn_pw_r12 == args->handler_fn_pw_r12 &&
                handler->handler_fn        == args->handler_fn);
}

_kernel_oserror* dcifilter_manage(dcifilter_t* filter, dci_FilterArgs_t* args)
{
        if (filter == NULL || args == NULL) return dcierror(EINVAL);

        switch (GET_FRAMELEVEL(args->frame_type))
        {
                case FRMLVL_E2SINK:
                case FRMLVL_E2MONITOR:
                case FRMLVL_IEEE:
                        if (GET_FRAMETYPE(args->frame_type) != 0) return dcierror(EINVAL);
                        break;
                case FRMLVL_E2SPECIFIC:
                        break;
                default:
                        return dcierror(EINVAL);

        }

        if ((args->filter_flags & FILTER_RELEASE) == FILTER_RELEASE)
        {
                /*
                 * args->addrlvl and args->errlvl are not valid for releasing so
                 * release all entries matching other args.
                 */
                handler_t* handler;
                handler_t* next;
                int released = 0;
                switch (GET_FRAMELEVEL(args->frame_type))
                {
                        case FRMLVL_IEEE:
                                handler = filter->ieee;
                                if (handler == NULL || !handler_match_args_release(handler, args)) break;
                                filter->ieee = 0;
                                _swix(OS_ServiceCall, _INR(0,4), filter->dib, Service_DCIFrameTypeFree,
                                                           args->frame_type, handler->addrlvl, handler->errlvl);
                                dprintf_here("released tp=%x ad=%x er=%x\n", args->frame_type, handler->addrlvl, handler->errlvl);
                                released = 1;
                                free(handler);
                                break;

                        default:
                                for (handler = TAILQ_FIRST(&filter->e2list); handler; handler = next)
                                {
                                        next = TAILQ_NEXT(handler, q_next);
                                        if (!handler_match_args_release(handler, args)) continue;

                                        TAILQ_REMOVE(&filter->e2list, handler, q_next);
                                        _swix(OS_ServiceCall, _INR(0,4), filter->dib, Service_DCIFrameTypeFree,
                                                                      args->frame_type, handler->addrlvl, handler->errlvl);
                                        dprintf_here("released tp=%x ad=%x er=%x\n", args->frame_type, handler->addrlvl, handler->errlvl);
                                        released = 1;
                                        free(handler);
                                }

                                break;
                }

                return released ? NULL : dcierror(EINVAL);
        }
        else /* FILTER_CLAIM */
        {
                handler_t*  handler;

                /*
                 * Ignore duplicates of filters from the same module already registered otherwise
                 * return error to inform caller if a filter of the same type is already registered.
                 */

                switch (GET_FRAMELEVEL(args->frame_type))
                {
                        case FRMLVL_IEEE:
                                if (filter->ieee == NULL) break;
                                if (handler_match_args_claim(filter->ieee, args)) return NULL;
                                return dcierror(INETERR_FILTERGONE);

                        case FRMLVL_E2MONITOR:
                                handler = TAILQ_LAST(&filter->e2list, handler_list_t);
                                if (handler == NULL) break;
                                if (handler_match_args_claim(handler, args)) return NULL;
                                return dcierror(INETERR_FILTERGONE);

                        case FRMLVL_E2SINK:
                                handler = TAILQ_LAST(&filter->e2list, handler_list_t);
                                if (handler == NULL || handler->frmlvl == FRMLVL_E2SPECIFIC) break;

                                /* handler may be FRMLVL_E2MONITOR OR FRMLVL_E2SYNC */
                                if (handler_match_args_claim(handler, args)) return NULL;
                                return dcierror(INETERR_FILTERGONE);

                        case FRMLVL_E2SPECIFIC:
                                TAILQ_FOREACH(handler, &filter->e2list, q_next)
                                {
                                        if (GET_FRAMELEVEL(args->frame_type)    == handler->frmlvl &&
                                            GET_FRAMETYPE(args->frame_type)     == handler->ethertype &&
                                            args->addrlvl                       == handler->addrlvl &&
                                            args->errlvl                        == handler->errlvl)
                                        {
                                                if (handler_match_args_claim(handler, args)) return NULL;
                                                return dcierror(INETERR_FILTERGONE);
                                        }
                                }
               }


                /* nomatch so create a new handler */

                handler = calloc(1, sizeof(handler_t));

                if (handler == NULL) return dcierror(ENOMEM);

                handler->flags             = args->filter_flags;
                handler->ethertype         = GET_FRAMETYPE(args->frame_type);
                handler->frmlvl            = GET_FRAMELEVEL(args->frame_type);
                handler->addrlvl           = args->addrlvl;
                handler->errlvl            = args->errlvl;
                handler->handler_fn_pw_r12 = args->handler_fn_pw_r12;
                handler->handler_fn        = args->handler_fn;

                switch (GET_FRAMELEVEL(args->frame_type))
                {
                        case FRMLVL_E2MONITOR:
                        case FRMLVL_E2SINK:
                                TAILQ_INSERT_TAIL(&filter->e2list, handler, q_next);
                                break;
                        case FRMLVL_E2SPECIFIC:
                                TAILQ_INSERT_HEAD(&filter->e2list, handler, q_next);
                                break;
                        case FRMLVL_IEEE:
                                filter->ieee = handler;
                                break;
                }
                dprintf_here("claimed tp=%x ad=%x er=%x\n", args->frame_type, handler->addrlvl, handler->errlvl);
        }

        return NULL;
}

typedef struct
{
        uint8_t dst_addr[ETHER_ADDR_LEN];
        uint8_t src_addr[ETHER_ADDR_LEN];
        uint8_t ethertype[ETHER_TYPE_LEN];
                #define PACKET_ETHERTYPE(p) ((p->ethertype[0] << 8) | p->ethertype[1])

} packet_t;


static handler_t* dcifilter_selectHandler(dcifilter_t* filter, packet_t* packet, uint32_t packet_type, uint32_t has_errors)
{
        uint32_t errlvl = has_errors ? ERRLVL_ERRORS : ERRLVL_NO_ERRORS;
        uint32_t addrlvl = packet_type ? ADDRLVL_SPECIFIC : ADDRLVL_SPECIFIC;/* todo */

        uint32_t ethertype = PACKET_ETHERTYPE(packet);

        if (ethertype <= ETHERMTU) /* FRMLVL_IEEE */
        {
             return filter->ieee;
        }

        /*  Ethernet 2 packet */

        handler_t* handler;
        TAILQ_FOREACH(handler, &filter->e2list, q_next)
        {
                if (ethertype == handler->ethertype &&
                 /* addrlvl   == handler->addrlvl && */
                    errlvl    == handler->errlvl ) return handler;

                if (handler->frmlvl != FRMLVL_E2SPECIFIC) return handler; /* sink or monitor matches any packet */

        }

        return NULL;
}


int dcifilter_receivedPacket(dcifilter_t* filter, uint8_t* data, size_t size, uint32_t packet_type, bool has_errors)
{
        if (filter == NULL || data == NULL) return DCIFILTER_BLOCKED;

        packet_t* packet = (void*)data;

        handler_t* handler = dcifilter_selectHandler(filter, packet, packet_type, has_errors);
        if (handler == NULL)
        {
                filter->unwanted_frames++;
                return DCIFILTER_OK;
        }

        struct mbuf* mb         = m_alloc_s(sizeof (RxHdr), 0);
        struct mbuf* mbdata     = m_alloc(size - ETHER_HDR_LEN, data + ETHER_HDR_LEN);

        if (mb == NULL || mbdata == NULL)
        {
                if (mb     != NULL) m_freem(mb);
                if (mbdata != NULL) m_freem(mbdata);
                filter->unwanted_frames++;
                return DCIFILTER_BLOCKED;
        }

        mb->m_type = MT_HEADER;
        for (struct mbuf* m = mbdata; m; m = m->m_next) m->m_type = MT_DATA;

        m_cat(mb, mbdata);

        RxHdrRef rxh = mtod(mb, RxHdrRef);
        memset(rxh, 0, sizeof (RxHdr));
        memcpy(rxh->rx_dst_addr, packet->dst_addr, ETHER_ADDR_LEN);
        memcpy(rxh->rx_src_addr, packet->src_addr, ETHER_ADDR_LEN);
        rxh->rx_frame_type = PACKET_ETHERTYPE(packet);

        if (handler->flags & FILTER_NO_UNSAFE)
        {
                m_ensure_safe(mb);
        }

        __asm
        {
          mov r0,  filter->dib
          mov r1,  mb
          mov r12, handler->handler_fn_pw_r12;
          blx handler->handler_fn,{r0,r1,r12},{},{LR,PSR}
        }

        return DCIFILTER_OK;
}
