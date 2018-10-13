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
/* > eightbit.c */

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

#include "eightbit.h"

/*
 * Routines for KOI-8R (Cyrillic)
 * Number: 2084
 * Names: KOI8-R
 *        csKOI8R
 */

int eightbit_reset(Encoding *e, int for_encoding)
{
    EightBit_Encoding *ee = (EightBit_Encoding *) e;

    if (!ee->table)
        ee->table = encoding_load_map_file(e->list_entry->preload);

    return ee->table != NULL;

    NOT_USED(for_encoding);
}

unsigned int eightbit_read(EncodingPriv *e,
			   encoding_read_callback_fn ucs_out,
                           const unsigned char *s,
                           unsigned int n,
                           void *handle)
{
    EightBit_Encoding *ee = (EightBit_Encoding *) e;
    unsigned int count;
    UCS2 *table = encoding_table_ptr(ee->table);

    for (count = n; count; count--)
    {
        unsigned char c = *s++;
        UCS4 u = c < 0x80 ? c : table[c - 0x80];

        if (u == NULL_UCS2)
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

int eightbit_read_in_multibyte_sequence(EncodingPriv *e)
{
    return 0;

    NOT_USED(e);
}

int eightbit_write(EncodingPriv *e, UCS4 u, unsigned char **s, int *bufsize)
{
    EightBit_Encoding *ee = (EightBit_Encoding *) e;
    int i, c;

    if (u == NULL_UCS4)
	return 0;

    if ( --(*bufsize) < 0 || !s)
	return 0;

    if (u < 0x80)
	c = u;
    else if ((i = encoding_lookup_in_table(u, ee->table)) != -1)
	c = i + 0x80;
    else if (e->for_encoding == encoding_WRITE_STRICT)
	return -1;
    else
	c = '?';

    (*s)[0] = c;
    (*s)++;
    return 1;
}

void eightbit_delete(EncodingPriv *e)
{
    EightBit_Encoding *ee = (EightBit_Encoding *) e;
    if (ee->table)
	encoding_discard_map_file(ee->table);
}

EncodingPriv enc_eightbit =
{
    eightbit_read,
    eightbit_read_in_multibyte_sequence,
    eightbit_reset,
    sizeof(EightBit_Encoding) - sizeof(EncodingPriv),
    eightbit_delete,
    0,
    eightbit_write,
    0,
    0,
    0
};
