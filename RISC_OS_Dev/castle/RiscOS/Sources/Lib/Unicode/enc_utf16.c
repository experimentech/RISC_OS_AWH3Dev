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
/* > enc_utf16 */

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

#include "enc_utf16.h"

typedef struct UTF16_Encoding
{
    EncodingPriv e;
    UCS2 prev_surrogate;
    unsigned char prev;
    unsigned char sync;
    unsigned char first;
} UTF16_Encoding;

/*
 * Routines for encoding UTF-16
 * Number: 1010
 * Names: UNICODE-1-0
 *        UNICODE-1-1
 *        UNICODE-2-0
 *        UNICODE-2-0-UTF-16  etc etc
 */
static int utf16_reset(Encoding *e, int for_encoding)
{
    UTF16_Encoding *ue = (UTF16_Encoding *) e;

    ue->prev_surrogate = 0;
    ue->sync = 0;
    ue->first = 1;

    return 1;

    NOT_USED(for_encoding);
}

static unsigned int utf16_read(Encoding *e,
                              encoding_read_callback_fn ucs_out,
                              const unsigned char *s,
                              unsigned int n,
                              void *handle)
{
    UTF16_Encoding *ue = (UTF16_Encoding *) e;
    unsigned int count;

    for (count = n; count; count--)
    {
        unsigned char c = *s++;
        UCS4 u;

        if (ue->sync)
        {
            ue->sync = 0;

            if (ue->e.flags & encoding_FLAG_LITTLE_ENDIAN)
                u = (c << 8) | ue->prev;
            else
                u = (ue->prev << 8) | c;

            if (ue->prev_surrogate)
            {
                if (u < 0xDC00 || u >= 0xE000)
                    u = 0xFFFD;
                else
                    u = 0x10000 + ((ue->prev_surrogate - 0xD800) << 10)
                                + u - 0xDC00;
                ue->prev_surrogate = 0;
            }
            else if (u >= 0xD800 && u < 0xDC00)
            {
                ue->prev_surrogate = u;
                continue;
            }
            else if (u == 0xFFFE)
            {
                ue->e.flags ^= encoding_FLAG_LITTLE_ENDIAN;
                u = 0xFEFF;
            }
        }
        else
        {
            ue->sync = 1;
            ue->prev = c;
            continue;
        }

        /* Strip BOM */
        if (ue->first && u == 0xFEFF)
        {
            ue->first = 0;
            continue;
        }

        ue->first = 0;

        if (ucs_out)
            if (ucs_out(handle, u))
            {
                /* The character has been used, so ensure its counted */
                count--;
                break;
            }
    }

    return n - count;
}

static int utf16_read_in_multibyte_sequence(EncodingPriv *e)
{
    UTF16_Encoding *ue = (UTF16_Encoding *) e;

    return ue->sync != 0 || ue->prev_surrogate != 0;
}

static unsigned char *write_be(unsigned char *p, UCS2 u)
{
    *p++ = u >> 8;
    *p++ = u & 0xff;

    return p;
}

static unsigned char *write_le(unsigned char *p, UCS2 u)
{
    *p++ = u & 0xff;
    *p++ = u >> 8;

    return p;
}

static int utf16_write(EncodingPriv *e, UCS4 u, unsigned char **putf16, int *bufsize)
{
    UTF16_Encoding *ue = (UTF16_Encoding *) e;
    unsigned int flags = ue->e.flags;
    unsigned char *utf16;
    UCS2 c = 0, cc = 0;
    int bom = 0;

    if (u == NULL_UCS4)
	return 0;

    utf16 = *putf16;

    if (ue->first && !(flags & encoding_FLAG_NO_HEADER))
        bom = 2;

    if (u < 0x00010000)
    {
	c = u;
    }
    else if (u < 0x00110000)
    {
	c  = (u - 0x00010000) / 0x400 + 0xD800;
	cc = (u - 0x00010000) % 0x400 + 0xDC00;
    }
    else
    {
	c = 0xFFFD;
    }

    if ((*bufsize -= (cc ? 4 : 2) + bom) < 0 || !putf16)
	return 0;

    ue->first = 0;

    if (bom)
    {
        if (flags & encoding_FLAG_LITTLE_ENDIAN)
            utf16 = write_le(utf16, 0xFEFF);
        else
            utf16 = write_be(utf16, 0xFEFF);
    }

    if (flags & encoding_FLAG_LITTLE_ENDIAN)
        utf16 = write_le(utf16, c);
    else
        utf16 = write_be(utf16, c);

    if (cc)
    {
        if (flags & encoding_FLAG_LITTLE_ENDIAN)
            utf16 = write_le(utf16, cc);
        else
            utf16 = write_be(utf16, cc);
    }

    *putf16 = utf16;

    return 1;
}

EncodingPriv enc_utf16 =
{
    utf16_read,
    utf16_read_in_multibyte_sequence,
    utf16_reset,
    sizeof(UTF16_Encoding) - sizeof(EncodingPriv),
    0, /* utf16_delete */
    0,
    utf16_write,
    0,
    0,
    0
};
