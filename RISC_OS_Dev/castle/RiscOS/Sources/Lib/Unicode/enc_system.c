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
/* > enc_system.c */

/**************************************************************************/
/*                                                                        */
/* Copyright [1997-2000] Pace Micro Technology PLC.  All rights reserved. */
/*                                                                        */
/* The copyright in this material is owned by Pace Micro Technology PLC   */
/* ("Pace").  This material is regarded as a highly confidential trade    */
/* secret of Pace.  It may not be reproduced, used, sold or in any        */
/* other way exploited or transferred to any third party without the      */
/* prior written permission of Pace.                                      */
/**************************************************************************/

#include <stdlib.h>

#include "encpriv.h"

#include "enc_utf8.h"
#include "enc_system.h"

typedef struct System_Encoding
{
    UTF8_Encoding ue;
    char is_utf8;
    const UCS4 *lookup;
} System_Encoding;


/*
 * Routines for current system alphabet
 * Number: 4999
 * Names: x-System
 *        x-Current
 */

static int system_reset(Encoding *e, int for_encoding)
{
    System_Encoding *se = (System_Encoding *) e;
    int alphabet = encoding_current_alphabet();

    if (enc_utf8.reset)
        enc_utf8.reset(e, for_encoding);

    if (alphabet == 111)
    {
        e->read = enc_utf8.read;
        e->read_in_multibyte_sequence = enc_utf8.read_in_multibyte_sequence;
        e->write = enc_utf8.write;
    }
    else
    {
        e->read = enc_system.read;
        e->read_in_multibyte_sequence = enc_system.read_in_multibyte_sequence;
        e->write = enc_system.write;
        se->lookup = encoding_alphabet_ucs_table(alphabet);
    }

    return 1;
}

static unsigned int system_read(EncodingPriv *e,
        		        encoding_read_callback_fn ucs_out,
                                const unsigned char *s,
                                unsigned int n,
                                void *handle)
{
    System_Encoding *se = (System_Encoding *) e;
    unsigned int count;

    for (count = n; count; count--)
    {
        unsigned char c = *s++;
        UCS4 u;

        if (se->lookup)
            u = se->lookup[(unsigned int)c];
        else
            u = c;

        if (u == NULL_UCS4)
            u = 0xFFFD;

        if (ucs_out)
            if (ucs_out(handle, u))
            {
                /* Character has been used, so ensure its counted */
                count--;
                break;
            }
    }

    return n - count;
}

static int system_read_in_multibyte_sequence(EncodingPriv *e)
{
    return 0;

    NOT_USED(e);
}

static int system_write(EncodingPriv *e, UCS4 u, unsigned char **s, int *bufsize)
{
    System_Encoding *se = (System_Encoding *) e;
    int i, c = -1;

    if (u == NULL_UCS4)
	return 0;

    if ( --(*bufsize) < 0 || !s)
	return 0;

retry:

    if (se->lookup)
    {
        for (i = 0; i < 256; i++)
            if (se->lookup[i] == u)
            {
                c = i;
                break;
            }
    }
    else if (u < 0x100)
    {
        c = u;
    }

    if (c == -1)
    {
        if (e->for_encoding == encoding_WRITE_STRICT)
	    return -1;
        else if (u == 0x0110)
        {
            u = 0x00D0;
            goto retry;
        }
        else
            c = '?';
    }

    (*s)[0] = c;
    (*s)++;
    return 1;
}

static void system_delete(EncodingPriv *e)
{
    if (enc_utf8.delete_enc)
        enc_utf8.delete_enc(e);
}

EncodingPriv enc_system =
{
    system_read,
    system_read_in_multibyte_sequence,
    system_reset,
    sizeof(System_Encoding) - sizeof(EncodingPriv),
    system_delete,
    0,
    system_write,
    0,
    0,
    0
};
