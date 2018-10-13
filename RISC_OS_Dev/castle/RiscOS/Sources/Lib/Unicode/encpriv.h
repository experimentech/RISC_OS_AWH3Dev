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
/* > encpriv.h */

/**************************************************************************/
/*                                                                        */
/* Copyright [1997-2003] All rights reserved.                             */
/*                                                                        */
/* This file may be included in profit making or non profit making        */
/* software on any system running any version of RISC OS, provided it was */
/* used along with a licensed binary of Unicode Lib                       */
/* It is supplied "as is" without warranty, express or implied, of        */
/* merchantability for any purpose.                                       */
/* No liability can be claimed for any direct or indirect loss            */
/**************************************************************************/

#ifndef unicode_encpriv_h
#define unicode_encpriv_h

#include "encoding.h"

typedef struct EncodingPriv EncodingPriv;

typedef int (*encoding_reset_fn)(EncodingPriv *, int for_encoding);

typedef unsigned int (*encoding_read_fn)(EncodingPriv *e,
				encoding_read_callback_fn ucs_out,
				const unsigned char *s,
				unsigned int n,
				void *handle);

typedef int (*encoding_read_in_multibyte_sequence_fn)(EncodingPriv *e);

typedef int (*encoding_write_fn)(EncodingPriv *e, UCS4 c, unsigned char **buf, int *bufsize);

typedef struct EncList EncList;

struct EncList
{
    int identifier;
    int max_char_size;		/* maximum size of an encoded character in bytes, 0 means could be huge */
    const char *names;
    const char *lang;			/* default language for this encoding */
    EncodingPriv *encoding;
    const char *preload;
    const char *encoder_data;
};

/*
 * An Encoding structure provides a uniform interface to a document
 * encoding (such as ISO 8859/1, Shift-JIS, KSC 5601-1987), with
 * utilities for conversion to and from UTF-8 and UCS-4.
 */

struct EncodingPriv
{
    /* values set up by the encoding scheme */
    encoding_read_fn read;
    encoding_read_in_multibyte_sequence_fn read_in_multibyte_sequence;
    encoding_reset_fn reset;

    int ws_size;

    void (*delete_enc)(EncodingPriv *);
    void (*enable_iso2022)(EncodingPriv *);

    encoding_write_fn write;

    /* generic data storage */
    EncList *list_entry;
    int for_encoding;
    unsigned int flags;
};

/* Exported function pointers for the library internal use only */

extern encoding_alloc_fn encoding__alloc;
extern encoding_free_fn encoding__free;

/* Encoding table functions */

typedef struct table_info *encoding_table;

extern UCS2 *encoding_table_ptr(encoding_table t);
extern int encoding_n_table_entries(encoding_table t);
extern int encoding_lookup_in_table(UCS4 u, encoding_table t);

/*
 * Load a named map file into a malloc block, or return a pointer to it if in
 * ResourceFS.
 */

extern encoding_table encoding_load_map_file(const char *fname);
extern void encoding_discard_map_file(encoding_table t);

/*
 * Load the encoding file represented by the given leaf name and return
 *  pointer to the table in memory
 *  the number of entries in the table
 *  whether the table needs to be freed with encoding__free() when we're finished with it.
 * Return value is whether the table was loladed successfully or not.
 */

extern int encoding__load_map_file(const char *leaf, UCS2 **ptable, int *pn_entries, int *palloc);

#ifdef __riscos
#define DIR_SEP		"."
#define DIR_WILD	"*"
#else
#define DIR_SEP		"/"
#define DIR_WILD	""
#endif

#ifdef LAYERS

/* include debugging when built as part of branched */
# include "layers.h"
# include "layers_dbg.h"
DECLARE_DBG(uni)
# define UNIDBG(x)  DBGMACRO(uni,x)
# define UNIDBGN(x) DBGNMACRO(uni,x)

#else /* !LAYERS */

#ifndef NOT_USED
#define NOT_USED(a)	a=a
#endif

#ifdef DEBUG

void uni_dprintf (const char *format, ...);

# define UNIDBG(a) uni_dprintf a
#else
# define UNIDBG(a)
#endif

#endif /* !LAYERS */

#endif
