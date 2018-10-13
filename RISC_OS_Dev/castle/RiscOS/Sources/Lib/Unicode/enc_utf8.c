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
/* > enc_utf8.c */

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
#include "utf8.h"

#include "enc_utf8.h"

/*
 * Routines for encoding UTF-8
 * Number: 106
 * Names: UTF-8
 */
static int utf8_reset(Encoding *e, int for_encoding)
{
    UTF8_Encoding *ue = (UTF8_Encoding *) e;

    ue->count = 0;
    ue->first = 1;
    /* No "BOM" by default, but we could add one */
    ue->e.flags |= encoding_FLAG_NO_HEADER;

    return 1;

    NOT_USED(for_encoding);
}

static unsigned int utf8_read(Encoding *e,
                              encoding_read_callback_fn ucs_out,
                              const unsigned char *s,
                              unsigned int n,
                              void *handle)
{
    UTF8_Encoding *ue = (UTF8_Encoding *) e;
    unsigned int count;

    for (count = n; count; count--)
    {
        unsigned char c = *s++;
        UCS4 u;

    retry:
        if (ue->count)
        {
            if (c >= 0x80 && c <= 0xBF)
            {
                *ue->ptr++ = c;
                if (--ue->count == 0)
                    UTF8_to_UCS4(ue->current, &u);
                else
                    continue;
            }
            else
            {
                /* Reset the count of expected continuation bytes */
                ue->count = 0;

                if (ucs_out)
                    if (ucs_out(handle, 0xFFFD))
                    {
                        /* Do not consume the invalid continuation byte */
                        break;
                    }

                goto retry;
            }
        }
        else
        {
            if (c < 0x80)
                u = c;
            else if (c < 0xC0 || c >= 0xFE)
                u = 0xFFFD;
            else
            {
                ue->count = UTF8_seqlen(c) - 1;
                ue->current[0] = c;
                ue->ptr = ue->current + 1;

                continue;
            }
        }

        if (ue->first && u == 0xFEFF)
        {
            ue->first = 0;
            continue;
        }

        ue->first = 0;

        /* Reject surrogates and FFFE/FFFF */
        if ((0xD800 <= u && u <= 0xE000) || u == 0xFFFE || u == 0xFFFF)
            u = 0xFFFD;

        if (ucs_out)
            if (ucs_out(handle, u))
            {
                /* Character has been used, so ensure it's counted */
                count--;
                break;
            }
    }

    return n - count;
}

static int utf8_read_in_multibyte_sequence(EncodingPriv *e)
{
    UTF8_Encoding *ue = (UTF8_Encoding *) e;

    return ue->count > 0;
}

static int utf8_write(EncodingPriv *e, UCS4 u, unsigned char **utf8, int *bufsize)
{
    UTF8_Encoding *ue = (UTF8_Encoding *) e;
    int len;
    int bom = 0;

    if (u == NULL_UCS4)
	return 0;

    len = UTF8_codelen(u);
    if (ue->first && !(ue->e.flags & encoding_FLAG_NO_HEADER))
        bom = 3;

    if ((*bufsize -= bom + len) < 0 || !utf8)
	return 0;

    if (bom) *utf8 = (unsigned char *)UCS4_to_UTF8((char *)*utf8, 0xFEFF);
    *utf8 = (unsigned char *)UCS4_to_UTF8((char *)*utf8, u);

    return 1;
}

EncodingPriv enc_utf8 =
{
    utf8_read,
    utf8_read_in_multibyte_sequence,
    utf8_reset,
    sizeof(UTF8_Encoding) - sizeof(EncodingPriv),
    0, /* utf8_delete */
    0,
    utf8_write,
    0,
    0,
    0
};
