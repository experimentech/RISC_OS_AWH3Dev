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
 * mbuf.h
 *
 * Mbuf manager reference C header file. Client's definitions.
 *
 * (C) Copyright ANT Limited, 1994. All rights reserved.
 *
 * Contacts:
 *
 * Postal:  ANT Ltd., PO BOX 300, Cambridge, CB1 2EG, UK.
 * Voice:   01223 567808
 * Fax:     01223 567801
 * Email:   Support@ant.co.uk
 *
 * This header file provides a reference C header file for the
 * facilities offered by the mbuf manager. Three #define's control
 * the precise definitions generated:
 *
 * __STDC__
 *      ANSI C defined facilities are used. This is the encouraged
 *      mode of use.
 *
 * SUPPORT_TRADITIONAL_MBUFS
 *      Additional presentation to existing source code already
 *      written for traditional mbufs.
 *
 * MBCTL_NAME
 *      Defining this macro causes additional #defines to be
 *      elaborated that provide some convenience wrappers. If
 *      the macro is empty, then "mbctl" is assumed. The user
 *      is expected to have defined something very much like:
 *
 *          struct mbctl MBCTL_NAME;
 *
 *      Of course, the struct mbctl referenced should that which
 *      was used during the opening of the mbuf manager session.
 */
/*
 * Copyright (C) 1994 ANT Limited., PO BOX 300, Cambridge, England.
 * All rights reserved.
 * 
 * Redistribution and use in source code and executable binary forms are
 * permitted provided that: (1) source distributions retain this entire
 * copyright notice and comment, and (2) distributions including
 * executable binaries contain the following acknowledgement:
 * 
 * ``This product includes software developed by ANT Limited and its
 * contributors.  Copyright (C) ANT Limited 1994.''
 * 
 * and also in the documentation and other materials provided with the
 * distribution and in all advertising materials mentioning features or
 * use of this software. Neither the name of ANT Limited nor the names of
 * its contributors may be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSER.
 * 
 * NOT INTENDED FOR USE IN LIFE CRITICAL APPLICATIONS.
 *
 */

#ifndef __included_mbuf_h
#define __included_mbuf_h

#define MBUF_MANAGER_VERSION    (1 * 100 + 0)

/*****************************************************************************
 *
 * This structure describes portions of memory being manipulated.
 */

#ifdef __STDC__

#include <stddef.h>

typedef struct mbuf
{
    struct  mbuf       *m_next;         /* next mbuf in chain */
    struct  mbuf       *m_list;         /* next mbuf in list (clients only) */

    ptrdiff_t           m_off;          /* current offset to data from mbuf itself */
    size_t              m_len;          /* current byte count */
    const ptrdiff_t     m_inioff;       /* original offset to data from mbuf itself */
    const size_t        m_inilen;       /* original byte count (for underlying data) */

    unsigned char       m_type;         /* client use only */
    const unsigned char m_sys1;         /* mbuf manager use only */
    const unsigned char m_sys2;         /* mbuf manager use only */
    const unsigned char m_sys3;         /* mbuf manager use only */
} dci4_mbuf;

#else /* __STDC__ */

/* RO indicates a field that is read-only */

struct mbuf
{
    struct  mbuf       *m_next;         /* next mbuf in chain */
    struct  mbuf       *m_list;         /* next mbuf in list (clients only) */

    int                 m_off;          /* current offset to data from mbuf itself */
    unsigned int        m_len;          /* current byte count */
    int                 m_inioff;       /* RO: original offset to data from mbuf itself */
    unsigned int        m_inilen;       /* RO: original byte count (for underlying data) */

    unsigned char       m_type;         /* client use only */
    unsigned char       m_sys1;         /* mbuf manager use only */
    unsigned char       m_sys2;         /* mbuf manager use only */
    unsigned char       m_sys3;         /* mbuf manager use only */
};

#endif /* __STDC__ */

/*****************************************************************************
 *
 * Some macros for convenience.
 *
 * mtod:
 *
 * Convert the address of an mbuf to the address of the first byte of
 * data that it describes, performing a type conversion for convenience.
 *
 * dtoo:
 *
 * Set the first byte described by an mbuf to the pointer supplied.
 * Typically used when initialising unsafe mbufs.
 *
 * MRESET:
 *
 * Restore an mbuf to its underlying state.
 */


#ifdef __STDC__

#define mtod(mp, type)      ( (type) ( (ptrdiff_t)(mp) + (mp)->m_off ) )
#define dtoo(mp, ptr)       (mp)->m_off = (ptrdiff_t)(ptr) - (ptrdiff_t)(mp)
#define MRESET(mp)          (mp)->m_off = (mp)->m_inioff, (mp)->m_len = (mp)->m_inilen

#else /* __STDC__ */

#define mtod(mp, type)      ( (type) ( (int)mp + (mp)->m_off ) )
#define dtoo(mp, ptr)       (mp)->m_off = (int)(ptr) - (int)(mp)
#define MRESET(mp)          (mp)->m_off = (mp)->m_inioff, (mp)->m_len = (mp)->m_inilen

#endif /* __STDC__ */


/*****************************************************************************
 *
 * Structure used to perform most of the communication and interaction
 * between a client and the mbuf manager.
 */

#ifdef __STDC__

typedef struct mbctl
{
    /* Reserved for mbuf manager use in establishing context */

    int                 opaque;         /* mbuf manager use only */


    /* Client initialises before session is established */

    size_t              mbcsize;        /* size of mbctl structure from client */
    unsigned int        mbcvers;        /* client version of mbuf manager spec */
    unsigned long       flags;          /* */
    size_t              advminubs;      /* Advisory desired minimum underlying block size */
    size_t              advmaxubs;      /* Advisory desired maximum underlying block size */
    size_t              mincontig;      /* client required min ensure_contig value */
    unsigned long       spare1;         /* Must be set to zero on initialisation */


    /* Mbuf manager initialises during session establishment */

    size_t              minubs;         /* Minimum underlying block size */
    size_t              maxubs;         /* Maximum underlying block size */
    size_t              maxcontig;      /* Maximum contiguify block size */
    unsigned long       spare2;         /* Reserved for future use */


    /* Allocation routines */

    struct mbuf *                   /* MBC_DEFAULT */
        (* alloc)
            (struct mbctl *, size_t bytes, void *ptr);

    struct mbuf *                   /* Parameter driven */
        (* alloc_g)
            (struct mbctl *, size_t bytes, void *ptr, unsigned long flags);

    struct mbuf *                   /* MBC_UNSAFE */
        (* alloc_u)
            (struct mbctl *, size_t bytes, void *ptr);

    struct mbuf *                   /* MBC_SINGLE */
        (* alloc_s)
            (struct mbctl *, size_t bytes, void *ptr);

    struct mbuf *                   /* MBC_CLEAR */
        (* alloc_c)
            (struct mbctl *, size_t bytes, void *ptr);


    /* Ensuring routines */

    struct mbuf *
        (* ensure_safe)
            (struct mbctl *, struct mbuf *mp);

    struct mbuf *
        (* ensure_contig)
            (struct mbctl *, struct mbuf *mp, size_t bytes);


    /* Freeing routines */

    void
        (* free)
            (struct mbctl *, struct mbuf *mp);

    void
        (* freem)
            (struct mbctl *, struct mbuf *mp);

    void
        (* dtom_free)
            (struct mbctl *, struct mbuf *mp);

    void
        (* dtom_freem)
            (struct mbctl *, struct mbuf *mp);


    /* Support routines */

    struct mbuf *                   /* No ownership transfer though */
        (* dtom)
            (struct mbctl *, void *ptr);

    int                             /* Client retains mp ownership */
        (* any_unsafe)
            (struct mbctl *, struct mbuf *mp);

    int                             /* Client retains mp ownership */
        (* this_unsafe)
            (struct mbctl *, struct mbuf *mp);

    size_t                          /* Client retains mp ownership */
        (* count_bytes)
            (struct mbctl *, struct mbuf *mp);

    struct mbuf *                   /* Client retains old, new ownership */
        (* cat)
            (struct mbctl *, struct mbuf *old, struct mbuf *new);

    struct mbuf *                   /* Client retains mp ownership */
        (* trim)
            (struct mbctl *, struct mbuf *mp, int bytes, void *ptr);

    struct mbuf *                   /* Client retains mp ownership */
        (* copy)
            (struct mbctl *, struct mbuf *mp, size_t off, size_t len);

    struct mbuf *                   /* Client retains mp ownership */
        (* copy_p)
            (struct mbctl *, struct mbuf *mp, size_t off, size_t len);

    struct mbuf *                   /* Client retains mp ownership */
        (* copy_u)
            (struct mbctl *, struct mbuf *mp, size_t off, size_t len);

    struct mbuf *                   /* Client retains mp ownership */
        (* import)
            (struct mbctl *, struct mbuf *mp, size_t bytes, void *ptr);

    struct mbuf *                   /* Client retains mp ownership */
        (* export)
            (struct mbctl *, struct mbuf *mp, size_t bytes, void *ptr);
} dci4_mbctl;


#else /* __STDC__ */


struct mbctl
{
    /* Reserved for mbuf manager use in establishing context */

    int                 opaque;         /* mbuf manager use only */


    /* Client initialises before session is established */

    unsigned int        mbcsize;        /* size of mbctl structure from client */
    unsigned int        mbcvers;        /* client version of mbuf manager spec */
    unsigned long       flags;          /* */
    unsigned int        advminubs;      /* Advisory desired minimum underlying block size */
    unsigned int        advmaxubs;      /* Advisory desired maximum underlying block size */
    unsigned int        mincontig;      /* client required min ensure_contig value */
    unsigned long       spare1;         /* Must be set to zero on initialisation */


    /* Mbuf manager initialises during session establishment */

    unsigned int        minubs;         /* Minimum underlying block size */
    unsigned int        maxubs;         /* Maximum underlying block size */
    unsigned int        maxcontig;      /* Maximum contiguify block size */
    unsigned long       spare2;         /* Reserved for future use */


    /* Allocation routines */

    struct mbuf *                   /* MBC_DEFAULT */
        (* alloc)
            ( /* struct mbctl *, unsigned int bytes, char *ptr */ );

    struct mbuf *                   /* Parameter driven */
        (* alloc_g)
            ( /* struct mbctl *, unsigned int bytes, char *ptr, unsigned long flags */ );

    struct mbuf *                   /* MBC_UNSAFE */
        (* alloc_u)
            ( /* struct mbctl *, unsigned int bytes, char *ptr */ );

    struct mbuf *                   /* MBC_SINGLE */
        (* alloc_s)
            ( /* struct mbctl *, unsigned int bytes, char *ptr */ );

    struct mbuf *                   /* MBC_CLEAR */
        (* alloc_c)
            ( /* struct mbctl *, unsigned int bytes, char *ptr */ );


    /* Ensuring routines */

    struct mbuf *
        (* ensure_safe)
            ( /* struct mbctl *, struct mbuf *mp */ );

    struct mbuf *
        (* ensure_contig)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int bytes */ );


    /* Freeing routines */

    void
        (* free)
            ( /* struct mbctl *, struct mbuf *mp */ );

    void
        (* freem)
            ( /* struct mbctl *, struct mbuf *mp */ );

    void
        (* dtom_free)
            ( /* struct mbctl *, struct mbuf *mp */ );

    void
        (* dtom_freem)
            ( /* struct mbctl *, struct mbuf *mp */ );


    /* Support routines */

    struct mbuf *                   /* No ownership transfer though */
        (* dtom)
            ( /* struct mbctl *, char *ptr */ );

    int                             /* Client retains mp ownership */
        (* any_unsafe)
            ( /* struct mbctl *, struct mbuf *mp */ );

    int                             /* Client retains mp ownership */
        (* this_unsafe)
            ( /* struct mbctl *, struct mbuf *mp */ );

    unsigned int                          /* Client retains mp ownership */
        (* count_bytes)
            ( /* struct mbctl *, struct mbuf *mp */ );

    struct mbuf *                   /* Client retains old, new ownership */
        (* cat)
            ( /* struct mbctl *, struct mbuf *old, struct mbuf *new */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* trim)
            ( /* struct mbctl *, struct mbuf *mp, int bytes, char *ptr */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* copy)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int off, unsigned int len */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* copy_p)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int off, unsigned int len */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* copy_u)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int off, unsigned int len */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* import)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int bytes, char *ptr */ );

    struct mbuf *                   /* Client retains mp ownership */
        (* export)
            ( /* struct mbctl *, struct mbuf *mp, unsigned int bytes, char *ptr */ );
};

#endif /* __STDC__ */

/*****************************************************************************
 *
 * Values of bits used as a bitset to the alloc_g allocator routine.
 */

#define MBC_DEFAULT         0x00000000ul
#define MBC_UNSAFE          0x00000001ul
#define MBC_SINGLE          0x00000002ul
#define MBC_CLEAR           0x00000004ul
#define MBC_DTOMABLE        0x00000008ul	/* not used */
#define MBC_DONTWAIT	    0x00000010ul	/* not used */

/* In flags field of mbctl during session opening */

#define MBC_USERMODE	    0x80000000ul


/* See specification for uses */
/* Huge and easily testable */

#define M_COPYALL           0x7f000000

/*****************************************************************************
 *
 * SWI interface
 */

#define Mbuf_SWI           0x4A580

#define Mbuf_OpenSession   (Mbuf_SWI + 0)
#define Mbuf_CloseSession  (Mbuf_SWI + 1)
#define Mbuf_Memory        (Mbuf_SWI + 2)
#define Mbuf_Statistic     (Mbuf_SWI + 3)
#define Mbuf_Control       (Mbuf_SWI + 4)

/* Statistic SWI uses the statistic interface from "dci4stat.h" */

/* Notification of arrival and depature of Mbuf Manager */

#define Service_MbufManagerStatus	0xA2

#define MbufManagerStatus_Started      	0
#define MbufManagerStatus_Stopping	1
#define MbufManagerStatus_Scavenge	2

/*****************************************************************************
 *
 * Support for users of traditional mbufs
 */

/* Traditional BSD mbuf types */
/* Types 1 and 2 are used by DCI4 in general */

#define MT_FREE         0
#define MT_DATA         1	/* driver to protocol */
#define MT_HEADER       2	/* driver to protocol */
#define MT_SOCKET       3
#define MT_PCB          4
#define MT_RTABLE       5
#define MT_HTABLE       6
#define MT_ATABLE       7
#define MT_SONAME       8
#define MT_ZOMBIE       9
#define MT_SOOPTS       10
#define MT_FTABLE       11
#define MT_RIGHTS       12
#define MT_IFADDR       13

#ifdef SUPPORT_TRADITIONAL_MBUFS


#include "bsdmbuf.h"


#endif /* SUPPORT_TRADITIONAL_MBUFS */

/*****************************************************************************
 *
 * Some optional macros. These are purely to provide a more convenient
 * accessed to the defined facilities. Invdivivual definitions can be
 * prevented by pre-defining the relevant macro name before including
 * this file.
 */

#if defined(MBCTL_NAME) && ! defined(SUPPORT_TRADITIONAL_MBUFS)

#ifndef m_alloc
#define m_alloc(b,p)            (*MBCTL_NAME.alloc) (&MBCTL_NAME, (b), (p))
#endif
#ifndef m_alloc_g
#define m_alloc_g(b,p,f)        (*MBCTL_NAME.alloc_g) (&MBCTL_NAME, (b), (p), (f))
#endif
#ifndef m_alloc_s
#define m_alloc_s(b,p)          (*MBCTL_NAME.alloc_s) (&MBCTL_NAME, (b), (p))
#endif
#ifndef m_alloc_c
#define m_alloc_c(b,p)          (*MBCTL_NAME.alloc_c) (&MBCTL_NAME, (b), (p))
#endif
#ifndef m_alloc_u
#define m_alloc_u(b,p)          (*MBCTL_NAME.alloc_u) (&MBCTL_NAME, (b), (p))
#endif

#ifndef m_ensure_safe
#define m_ensure_safe(m)        (*MBCTL_NAME.ensure_safe) (&MBCTL_NAME, (m))
#endif
#ifndef m_ensure_contig
#define m_ensure_contig(m,n)    (*MBCTL_NAME.ensure_contig) (&MBCTL_NAME, (m), (n))
#endif

#ifndef m_free
#define m_free(m)               (*MBCTL_NAME.free) (&MBCTL_NAME, (m))
#endif
#ifndef m_freem
#define m_freem(m)              (*MBCTL_NAME.freem) (&MBCTL_NAME, (m))
#endif
#ifndef m_dtom_free
#define m_dtom_free(m)          (*MBCTL_NAME.dtom_free) (&MBCTL_NAME, (m))
#endif
#ifndef m_dtom_freem
#define m_dtom_freem(m)         (*MBCTL_NAME.dtom_freem) (&MBCTL_NAME, (m))
#endif

#ifndef m_dtom
#define m_dtom(d)               (*MBCTL_NAME.dtom) (&MBCTL_NAME, (d))
#endif
#ifndef m_any_unsafe
#define m_any_unsafe(m)         (*MBCTL_NAME.any_unsafe) (&MBCTL_NAME, (m))
#endif
#ifndef m_this_unsafe
#define m_this_unsafe(m)        (*MBCTL_NAME.this_unsafe) (&MBCTL_NAME, (m))
#endif
#ifndef m_count_bytes
#define m_count_bytes(m)        (*MBCTL_NAME.count_bytes) (&MBCTL_NAME, (m))
#endif
#ifndef m_cat
#define m_cat(m,n)              (*MBCTL_NAME.cat) (&MBCTL_NAME, (m), (n))
#endif
#ifndef m_trim
#define m_trim(m,n,p)           (*MBCTL_NAME.trim) (&MBCTL_NAME, (m), (n), (p))
#endif

#ifndef m_copy
#define m_copy(m,o,l)           (*MBCTL_NAME.copy) (&MBCTL_NAME, (m), (o), (l))
#endif
#ifndef m_copy_p
#define m_copy_p(m,o,l)         (*MBCTL_NAME.copy_p) (&MBCTL_NAME, (m), (o), (l))
#endif
#ifndef m_copy_u
#define m_copy_u(m,o,l)         (*MBCTL_NAME.copy_u) (&MBCTL_NAME, (m), (o), (l))
#endif

#ifndef m_import
#define m_import(m,n,p)         (*MBCTL_NAME.import) (&MBCTL_NAME, (m), (n), (p))
#endif
#ifndef m_export
#define m_export(m,n,p)         (*MBCTL_NAME.export) (&MBCTL_NAME, (m), (n), (p))
#endif

#ifndef dtom
#define dtom(d)                 m_dtom(d)
#endif

#endif /* defined(MBCTL_NAME) && ! defined(SUPPORT_TRADITIONAL_MBUFS) */


#ifdef MBCTL_NAME

extern struct mbctl MBCTL_NAME;

#endif

/*****************************************************************************/


#endif /* __included_mbuf_h */

/* eof mbuf.h */
