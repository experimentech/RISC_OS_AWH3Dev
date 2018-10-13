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
/* > mkunictype.c */

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

/*
 * The ideographs for unictype_is_ideograph() are derived from code
 * points listed in doc/PropList320 which are categorised as
 *   ; Ideographic                  or
 *   ; IDS_Binary_Operator          or
 *   ; IDS_Trinary_Operator         or
 *   ; Radical                      or
 *   ; Unified_Ideograph
 * and which are small enough to fit into a UCS2 argument.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "unictype.h"

#define range_UNKNOWN	0
#define range_SINGLE	1
#define range_START	2
#define range_END	3

#define cat(a,b)	(((a) << 8) | (b))

#define FILE_HDR			\
	"/* > unictype.c */\n"	\
	"/* Generated file - do not edit by hand */\n"	\
	"#include \"unictype.h\"\n"

#define FILE_FTR				\
	"int unictype_lookup(UCS2 c)\n"	\
	"{\n"					\
	" unsigned val = (unicode_type_ref[c >> 8]) [(c >> 3) & 0x1F];\n" \
	" int i = (c & 7);\n"			\
	" return ((val >> (i*4)) & 15);\n"	\
	"}\n\n"					\
	""					\
	"void unictype_init(void)\n"		\
	"{\n"					\
	"}\n\n"					\
	""					\
	"int unictype_is_ideograph(UCS2 u)\n"	\
	"{\n"					\
	" if (u < 0x2E80) return 0;\n"		\
	" if (u <= 0x2E99) return 1;\n"		\
	" if (u < 0x2E9B) return 0;\n"		\
	" if (u <= 0x2EF3) return 1;\n"		\
	" if (u < 0x2F00) return 0;\n"		\
	" if (u <= 0x2FD5) return 1;\n"		\
	" if (u < 0x2FF0) return 0;\n"		\
	" if (u <= 0x2FFB) return 1;\n"		\
	" if (u < 0x3006) return 0;\n"		\
	" if (u <= 0x3007) return 1;\n"		\
	" if (u < 0x3021) return 0;\n"		\
	" if (u <= 0x3029) return 1;\n"		\
	" if (u < 0x3038) return 0;\n"		\
	" if (u <= 0x303A) return 1;\n"		\
	" if (u < 0x3400) return 0;\n"		\
	" if (u <= 0x4DB5) return 1;\n"		\
	" if (u < 0x4E00) return 0;\n"		\
	" if (u <= 0x9FA5) return 1;\n"		\
	" if (u < 0xF900) return 0;\n"		\
	" if (u <= 0xFA2D) return 1;\n"		\
	" if (u < 0xFA0E) return 0;\n"		\
	" if (u <= 0xFA0F) return 1;\n"		\
	" if (u == 0xFA11) return 1;\n"		\
	" if (u < 0xFA13) return 0;\n"		\
	" if (u <= 0xFA14) return 1;\n"		\
	" if (u == 0xFA1F) return 1;\n"		\
	" if (u == 0xFA21) return 1;\n"		\
	" if (u < 0xFA23) return 0;\n"		\
	" if (u <= 0xFA24) return 1;\n"		\
	" if (u < 0xFA27) return 0;\n"		\
	" if (u <= 0xFA29) return 1;\n"		\
	" return 0;\n"				\
	"}\n\n"					\
	"/* eof unictype.c */\n"

#define TABLE_HDR	"static unsigned unicode_type[%d][32]={\n"
#define TABLE_ENTRY_HDR	"{\n"
#define TABLE_ENTRY	" 0x%02x%02x%02x%02x"
#define TABLE_ENTRY_FTR	"}\n"
#define TABLE_FTR	"};\n"

#define REF_HDR		"static unsigned *unicode_type_ref[256]={\n"
#define REF_ENTRY	" unicode_type[%d],\n"
#define REF_FTR		"};\n"


typedef struct
{
    unsigned int code;
    int type;
    int range;
} unicode_char_info;


static int debug = 1;

static int category_to_type(int category)
{
    switch (category)
    {
    case cat('M', 'n'):
    case cat('M', 'c'):
    case cat('M', 'e'):
	return unictype_MARK;

    case cat('N', 'd'):
    case cat('N', 'l'):
    case cat('N', 'o'):
	return unictype_NUMBER;

    case cat('C', 'c'):
    case cat('C', 'f'):
    case cat('Z', 's'):
	return unictype_SEPARATOR_SPACE;

    case cat('Z', 'l'):
    case cat('Z', 'p'):
	return unictype_SEPARATOR_PARA;

    case cat('C', 'o'):
    case cat('C', 'n'):
    case cat('C', 's'):
    case cat('L', 'u'):
    case cat('L', 'l'):
    case cat('L', 't'):
    case cat('L', 'o'):
    case cat('L', 'm'):		/* SJM: this is a spacing character not a mark */
    case cat('S', 'k'):
	return unictype_LETTER;

    case cat('P', 'd'):
	return unictype_PUNCTUATION_DASH;

    case cat('P', 's'):
    case cat('P', 'i'):
	return unictype_PUNCTUATION_OPEN;

    case cat('P', 'e'):
    case cat('P', 'o'):
    case cat('P', 'c'):
    case cat('P', 'f'):
	return unictype_PUNCTUATION_CLOSE;

    case cat('S', 'm'):
    case cat('S', 'c'):
    case cat('S', 'o'):
	return unictype_SYMBOL;
    }

    return unictype_UNKNOWN;
}

static int decode_line(char *cp, unicode_char_info *info)
{
    int c;
    int field = 0;
    char *fstart;

    if (*cp == 0)
	return 0;

    fstart = cp;
    while ((c = *cp++) != 0)
    {
	if (c == ';' || c == '\n')
	{
	    switch (field)
	    {
	    case 0:
		info->code = (int)strtoul(fstart, NULL, 16);
		if (info->code > (UCS2)~0)
		    return 0; /* Out of range for UCS2 */
		break;
	    case 1:
		if (strncmp(cp-7, "First>;", sizeof("First>;")-1) == 0)
		    info->range = range_START;
		else if (strncmp(cp-6, "Last>;", sizeof("Last>;")-1) == 0)
		    info->range = range_END;
		else
		    info->range = range_SINGLE;
		break;
	    case 2:
		info->type = category_to_type((fstart[0] << 8) | fstart[1]);
		if (info->type == unictype_UNKNOWN)
		    fprintf(stderr, "%04X: unknown category \"%c%c\"",
		                    info->code, fstart[0], fstart[1]);
		break;
	    }

	    fstart = cp;
	    field++;
	}
    }

    if (debug >= 3)
	fprintf(stderr, "%04x: %d %d\n", info->code, info->type, info->range);

    return 1;
}

static void write_nybble(unsigned char *ptr, int index, int value)
{
    unsigned char c = ptr[index/2];
    if (index & 1)
	c = (unsigned char)((c & 0x0f) | (value << 4));
    else
	c = (unsigned char)((c & 0xf0) | (value));
    ptr[index/2] = c;
}


static unsigned char *table_ptr[256];
static int table_ref[256];

int main(int argc, char *argv[])
{
    FILE *f_in = stdin;
    int i, j;
    int n_refs;
    unicode_char_info info_last;
    int first;

    if (argc == 2)
    {
	debug = atoi(argv[1]);
    }

    for (i = 0; i < 256; i++)
    {
	table_ptr[i] = calloc(128, 1);
	table_ref[i] = 0;
    }

    info_last.range = range_UNKNOWN;
    info_last.code = 0;
    info_last.type = 0;
    while (!feof(f_in) && !ferror(f_in))
    {
	char buf[512];
	unicode_char_info info;

	fgets(buf, sizeof(buf), stdin);

	if (decode_line(buf, &info))
	{
	    if (info.range == range_SINGLE)
	    {
		unsigned char *line = table_ptr[info.code >> 8];
		write_nybble(line, info.code & 0xff, info.type);
	    }
	    else if (info.range == range_START)
	    {
		info_last = info;
	    }
	    else if (info.range == range_END)
	    {
		if (info_last.range == range_START)
		{
		    for (i = info_last.code; i <= info.code; i++)
		    {
			unsigned char *line = table_ptr[i >> 8];
			write_nybble(line, i & 0xff, info.type);
		    }
		    info_last.range = range_UNKNOWN;
		}
	    }
	}
    }

    n_refs = 0;
    for (i = 0; i < 256; i++)
    {
	if (debug >= 2)
	    fprintf(stderr, "Checking table %d\n", i);

	if (table_ptr[i])
	{
	    for (j = i+1; j < 256; j++)
		if (table_ptr[j] &&
		    memcmp(table_ptr[i], table_ptr[j], 128) == 0)
		{
		    table_ref[j] = n_refs;

		    free(table_ptr[j]);
		    table_ptr[j] = 0;

		    if (debug >= 3)
			fprintf(stderr, " table %d matches\n", j);
		}

	    table_ref[i] = n_refs++;
	}
    }


    printf( FILE_HDR );

    printf( TABLE_HDR, n_refs );

    first = 1;
    for (i = 0; i < 256; i++)
    {
	unsigned char *ptr = table_ptr[i];

	if (ptr)
	{
	    if (debug >= 2)
		fprintf(stderr, "Writing table %d\n", i);

	    if (first)
		first = 0;
	    else
		printf( "," );

	    printf( TABLE_ENTRY_HDR );

	    for (j = 0; j < 128; j+=4)
	    {
#if 1
		printf( TABLE_ENTRY, ptr[j+3], ptr[j+2], ptr[j+1], ptr[j+0] );
#else
		int k;
		for (k = 0; k < 8; k++)
		{
		    printf( TABLE_ENTRY, ptr[j+k] );
		    if (k != 7)
			printf(", ");
		}
#endif
		if (j != 128 - 4)
		    printf( ",\n" );
		else
		    printf( "\n" );
	    }

	    printf( TABLE_ENTRY_FTR );
	}
    }

    printf( TABLE_FTR );

    printf( REF_HDR );

    for (i = 0; i < 256; i++)
    {
	if (debug >= 2)
	    fprintf(stderr, "Writing table ref %d to %d\n", i, table_ref[i]);

	printf( REF_ENTRY, table_ref[i] );
    }

    printf( REF_FTR );

    printf( FILE_FTR );

    if (debug)
	fprintf(stderr, "Number of tables %d\n", n_refs);

    for (i = 0; i < 256; i++)
	if (table_ptr[i])
	    free(table_ptr[i]);

    return EXIT_SUCCESS;
}

/* eof mkunictype.c */
