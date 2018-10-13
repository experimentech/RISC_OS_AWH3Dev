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
/* > iso6937.c */

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
#include <stdbool.h>
#include <stdint.h>

#include "encpriv.h"

#include "eightbit.h"
#include "iso2022.h"
#include "iso6937.h"

#include "charsets.h"

typedef enum Accent
{
    None = 0,
    Grave = 1,
    Acute = 2,
    Circumflex = 3,
    Tilde = 4,
    Macron = 5,
    Breve = 6,
    DotAbove = 7,
    Diaeresis = 8,
    RingAbove = 10,
    Cedilla = 11,
    DoubleAcute = 13,
    Ogonek = 14,
    Caron = 15,
}
Accent;

typedef struct Combination
{
    unsigned char letter;
    UCS2 u;
}
Combination;

static const Combination acute_combinations[] =
{
    ' ', 0x00B4,
    'A', 0x00C1,
    'C', 0x0106,
    'E', 0x00C9,
    'I', 0x00CD,
    'L', 0x0139,
    'N', 0x0143,
    'O', 0x00D3,
    'R', 0x0154,
    'S', 0x015A,
    'U', 0x00DA,
    'Y', 0x00DD,
    'Z', 0x0179,
    'a', 0x00E1,
    'c', 0x0107,
    'e', 0x00E9,
    'i', 0x00ED,
    'l', 0x013A,
    'n', 0x0144,
    'o', 0x00F3,
    'r', 0x0155,
    's', 0x015B,
    'u', 0x00FA,
    'y', 0x00FD,
    'z', 0x017A
};

static const Combination grave_combinations[] =
{
    0,   0x0060,
    'A', 0x00C0,
    'E', 0x00C8,
    'I', 0x00CC,
    'O', 0x00D2,
    'U', 0x00D9,
    'a', 0x00E0,
    'e', 0x00E8,
    'i', 0x00EC,
    'o', 0x00F2,
    'u', 0x00F9,
};

static const Combination circumflex_combinations[] =
{
    0,   0x005E,
    'A', 0x00C2,
    'C', 0x0108,
    'E', 0x00CA,
    'G', 0x011C,
    'H', 0x0124,
    'I', 0x00CE,
    'J', 0x0134,
    'O', 0x00D4,
    'S', 0x015C,
    'U', 0x00DB,
    'W', 0x0174,
    'Y', 0x0176,
    'a', 0x00E2,
    'c', 0x0109,
    'e', 0x00EA,
    'g', 0x011D,
    'h', 0x0125,
    'i', 0x00EC,
    'j', 0x0135,
    'o', 0x00F4,
    's', 0x015D,
    'u', 0x00FB,
    'w', 0x0175,
    'y', 0x0177
};

static const Combination diaeresis_combinations[] =
{
    ' ', 0x00A8,
    'A', 0x00C4,
    'E', 0x00CB,
    'I', 0x00CF,
    'O', 0x00D6,
    'U', 0x00DC,
    'Y', 0x0178,
    'a', 0x00E4,
    'e', 0x00EB,
    'i', 0x00EF,
    'o', 0x00F6,
    'u', 0x00FC,
    'y', 0x00FF
};

static const Combination tilde_combinations[] =
{
    0,   0x007E,
    'A', 0x00C3,
    'I', 0x0128,
    'N', 0x00D1,
    'O', 0x00D5,
    'U', 0x0168,
    'a', 0x00E3,
    'i', 0x0129,
    'n', 0x00F1,
    'o', 0x00F5,
    'u', 0x0169
};

static const Combination caron_combinations[] =
{
    ' ', 0x02C7,
    'C', 0x010C,
    'D', 0x010E,
    'E', 0x011A,
    'L', 0x013D,
    'N', 0x0147,
    'R', 0x0158,
    'S', 0x0160,
    'T', 0x0164,
    'Z', 0x017D,
    'c', 0x010D,
    'd', 0x010F,
    'e', 0x011B,
    'l', 0x013E,
    'n', 0x0148,
    'r', 0x0159,
    's', 0x0161,
    't', 0x0165,
    'z', 0x017E
};

static const Combination breve_combinations[] =
{
    ' ', 0x02D8,
    'A', 0x0102,
    'G', 0x011E,
    'U', 0x016C,
    'a', 0x0103,
    'g', 0x011F,
    'u', 0x016D
};

static const Combination doubleacute_combinations[] =
{
    ' ', 0x02DD,
    'O', 0x0150,
    'U', 0x0170,
    'o', 0x0151,
    'u', 0x0171
};

static const Combination ringabove_combinations[] =
{
    ' ', 0x02DA,
    'A', 0x00C5,
    'U', 0x016E,
    'a', 0x00E5,
    'u', 0x016F
};

static const Combination dotabove_combinations[] =
{
    ' ', 0x02D9,
    'C', 0x010A,
    'E', 0x0116,
    'G', 0x0120,
    'I', 0x0130,
    'Z', 0x017B,
    'c', 0x010B,
    'e', 0x0117,
    'g', 0x0121,
    'z', 0x017C
};

static const Combination macron_combinations[] =
{
    ' ', 0x00AF,
    'A', 0x0100,
    'E', 0x0112,
    'I', 0x012A,
    'O', 0x014C,
    'U', 0x016A,
    'a', 0x0101,
    'e', 0x0113,
    'i', 0x012B,
    'o', 0x014D,
    'u', 0x016B
};

static const Combination cedilla_combinations[] =
{
    ' ', 0x00B8,
    'C', 0x00C7,
    'G', 0x0122,
    'K', 0x0136,
    'L', 0x013B,
    'N', 0x0145,
    'R', 0x0156,
    'S', 0x015E, /*check*/
    'T', 0x0162, /*check*/
    'c', 0x00E7,
    'g', 0x0123,
    'k', 0x0137,
    'l', 0x013C,
    'n', 0x0146,
    'r', 0x0157,
    's', 0x015F, /*check*/
    't', 0x0163, /*check*/
};

static const Combination ogonek_combinations[] =
{
    ' ', 0x02DB,
    'A', 0x0104,
    'E', 0x0118,
    'I', 0x012E,
    'U', 0x0172,
    'a', 0x0105,
    'e', 0x0119,
    'i', 0x012F,
    'u', 0x0173
};

typedef struct CombinationList
{
    const Combination *combination;
    size_t ncombinations;
}
CombinationList;

#define ARRAYLEN(a) (sizeof (a)/sizeof (a)[0])
#define COMBENTRY(A,a) [A] = a##_combinations, ARRAYLEN(a##_combinations)

static const CombinationList iso6937_combination_table[16] =
{
    COMBENTRY(Acute, acute),
    COMBENTRY(Grave, grave),
    COMBENTRY(Circumflex, circumflex),
    COMBENTRY(Diaeresis, diaeresis),
    COMBENTRY(Tilde, tilde),
    COMBENTRY(Caron, caron),
    COMBENTRY(Breve, breve),
    COMBENTRY(DoubleAcute, doubleacute),
    COMBENTRY(RingAbove, ringabove),
    COMBENTRY(DotAbove, dotabove),
    COMBENTRY(Macron, macron),
    COMBENTRY(Cedilla, cedilla),
    COMBENTRY(Ogonek, ogonek)
};

static Accent UCStoAccent(UCS4 u)
{
    switch (u)
    {
        default:     return None;
        case 0x0300: return Grave;
        case 0x0301: return Acute;
        case 0x0302: return Circumflex;
        case 0x0303: return Tilde;
        case 0x0304: return Macron;
        case 0x0306: return Breve;
        case 0x0307: return DotAbove;
        case 0x0308: return Diaeresis;
        case 0x030A: return RingAbove;
        case 0x030B: return DoubleAcute;
        case 0x030C: return Caron;
        case 0x0327: return Cedilla;
        case 0x0328: return Ogonek;
    }
}

static int combination_compare(const void *key, const void *member)
{
    const unsigned char *letter = key;
    const Combination *c = member;
    return *letter - c->letter;
}

static UCS4 iso6937_combine(Accent a, unsigned char letter)
{
    const Combination *combinations = iso6937_combination_table[a].combination;
    size_t n = iso6937_combination_table[a].ncombinations;
    Combination *c = bsearch(&letter, combinations, n, sizeof combinations[0], combination_compare);
    if (c)
        return c->u;
    else
        return NULL_UCS4;
}

static int iso6937_find_accent_pair(UCS4 u)
{
    int a, i;

    for (a = 1; a <= 15; a++)
    {
        if (iso6937_combination_table[a].combination)
        {
            for (i = 0; i < iso6937_combination_table[a].ncombinations; i++)
            {
                if (iso6937_combination_table[a].combination[i].u == u)
                {
                    return (0xC0+a) + (iso6937_combination_table[a].combination[i].letter << 8);
                }
            }
        }
    }
    return -1;
}

/*
 * ISO 6937 handling is not integrated into the framework of general
 * ISO 2022 handling. This could be done, if the core 2022 handler
 * did the conversion of combining characters.
 */

static int iso6937_reset(Encoding *e, int for_encoding)
{
    ISO6937_Encoding *ie = (ISO6937_Encoding *) e;

    /* Fudge the DVB variant with added euro sign */
    ie->euro = ie->e.list_entry->identifier == csISO6937DVB;

    ie->accent = None;

    if (!ie->table)
        ie->table = iso2022_find_table(96, 0x52);

    return ie->table != NULL;

    NOT_USED(for_encoding);
}


static unsigned int iso6937_read(Encoding *e,
			         encoding_read_callback_fn ucs_out,
                                 const unsigned char *s,
                                 unsigned int n,
                                 void *handle)
{
    ISO6937_Encoding *ie = (ISO6937_Encoding *) e;
    unsigned int count;
    UCS2 *table = encoding_table_ptr(ie->table);

    for (count = n; count; count--)
    {
        unsigned char c = *s++;
        UCS4 u;

    retry:
        if (ie->accent)
        {
            u = iso6937_combine((Accent) ie->accent, c);
            if (u == NULL_UCS4)
            {
                /* Bad combination - spit out spacing accent then retry */
                if (ucs_out)
                    if (ucs_out(handle, iso6937_combination_table[ie->accent].combination[0].u))
                    {
                        /* Character has been used, so ensure it's counted */
                        count--;
                        break;
                    }

                ie->accent = None;

                goto retry;
            }
            ie->accent = None;
        }
        else
        {
            u = c < 0xA0 ? c : table[c - 0xA0];

            if (u == NULL_UCS2)
            {
                if (c == 0xA4 && ie->euro)
                    u = 0x20AC;
                else
                    u = 0xFFFD;
            }

            if (u >= 0x0300 && u < 0x0370)
            {
                ie->accent = UCStoAccent(u);
                if (ie->accent)
                    continue;
            }
        }

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

static int iso6937_read_in_multibyte_sequence(EncodingPriv *e)
{
    ISO6937_Encoding *ie = (ISO6937_Encoding *) e;

    return ie->accent != None;
}

static int iso6937_write(EncodingPriv *e, UCS4 u, unsigned char **s, int *bufsize)
{
    ISO6937_Encoding *ie = (ISO6937_Encoding *) e;
    int i, c, cc = 0;

    if (u == NULL_UCS4)
	return 0;

    if (u < 0xA0)
	c = u;
    else if ((i = encoding_lookup_in_table(u, ie->table)) != -1)
	c = i + 0xA0;
    else if (u == 0x20AC && ie->euro)
        c = 0xA4;
    else if (u == 0x00D0)
        c = 0xE2; /* unify Eth with Dstroke */
    else if ((i = iso6937_find_accent_pair(u)) != -1)
        c = i & 0xFF, cc = i >> 8;
    else if (e->for_encoding == encoding_WRITE_STRICT)
	return -1;
    else
	c = '?';

    if ((*bufsize -= (cc ? 2 : 1)) < 0 || !s)
	return 0;

    *(*s)++ = c;
    if (cc)
        *(*s)++ = cc;
    return 1;
}

static void iso6937_delete(EncodingPriv *e)
{
    ISO6937_Encoding *ie = (ISO6937_Encoding *) e;
    if (ie->table)
	encoding_discard_map_file(ie->table);
}

EncodingPriv enc_iso6937 =
{
    iso6937_read,
    iso6937_read_in_multibyte_sequence,
    iso6937_reset,
    sizeof(ISO6937_Encoding) - sizeof(EncodingPriv),
    iso6937_delete,
    0,
    iso6937_write,
    0,
    0,
    0
};
