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

/* armprof.c:  Copyright (C) Codemist Ltd., 1988      */
/* Copyright (C) Acorn Computers Ltd., 1988, 1990     */
/* RISCOS-specific profiling support                  */

#include <stdio.h>

/* HIDDEN EXPORTS */
extern void _mapstore(void);
extern void _fmapstore(char *);
void _write_profile(char *);

#ifdef __STDC__
  #error armprof.c MUST be compiled in -pcc mode
#endif

extern unsigned Image$$RO$$Base, Image$$RO$$Limit, Image$$RW$$Limit;

static unsigned *RO_Base  = &Image$$RO$$Base;
static unsigned *RO_Limit = &Image$$RO$$Limit;
static unsigned *RW_Limit = &Image$$RO$$Limit;

extern void _count(void), _count1(void);

typedef union count_position
/* This defines the format of the word that follows on from a call         */
/* to _count1(). The related constant values are related to the way that   */
/* file-name decoding tables are packed away.                              */
{   int i;
    struct s
    {   unsigned int posn:12,
                     line:16,
                     file:4;
    } s;
} count_position;

#define file_name_map_start 0xfff12340  /* Magic number */
#define file_name_map_end   0x31415926  /* Magic number */

#define word_roundup(s) ((char *)(((int)s + 3) & (~3)))

static char *find_file_map(int p)
{
    int i, w;
    char *s;
    while (((w = *(int *)p) & 0xfffffff0) != file_name_map_start)
    {   if (p >= (int)RO_Limit) return "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
        p += 4;
    }
    s = (char *)(p + 4);
    for ( i = 0; i<=(w & 0xf); i++)
    {   s += 1 + strlen(s);
        s = word_roundup(s);
    }
    if (*(int *)s != file_name_map_end) return find_file_map((int)s);
    return (char *)(p + 4);
}

static void _map_store(FILE *map_file)
{
    unsigned count1 = (unsigned)_count1;    /* address of the fn as an int */
    unsigned p, onthisline = 4, w1 = 0, w2 = 0;
    unsigned ro_base  = (unsigned)RO_Base;
    unsigned ro_limit = (unsigned)RO_Limit;
    unsigned rw_limit = (unsigned)RW_Limit;

    fprintf(map_file,
"\nFunction/statement counts from code base = %.6x to code limit = %.6x\n",
        ro_base, ro_limit);

    for (p = ro_base; p < ro_limit; p += 4)
    {   int w = *(int *)p;
        if ((w & 0xff000000) == 0xeb000000) /* Unconditional BL instruction */
        {   unsigned dest = (p + 8 + ((w << 8) >> 6));
            if (dest != count1 && dest >= ro_base && dest < rw_limit)
            {   /* Try for call through (straight) veneer */
                int b = *(int *)dest;
                if ((b & 0xff000000) == 0xea000000) /* Unconditional B */
                    dest = (dest + 8 + ((b << 8) >> 6));
            }
            if (dest == count1)
            {   if (onthisline == 4) onthisline = 0, fputs("\n   ", map_file);
                ++onthisline;
                fprintf(map_file, " %.6u: %-9u",
                        (*(unsigned *)(p + 8) << 4) >> 16,
                        *(unsigned *)(p + 4));
            }
        }
        if (   ((w & 0xff000000) == 0xe9000000) &&
             ( ((w & 0x00ff0000) == 0x002c0000 && w1 == 0xe1a0b00c) ||
               ((w & 0x00ff0000) == 0x002d0000 && w1 == 0xe1a0c00d) ) &&
             /* STMFD sp!, ..., ; MOV ip, sp  @@@@@, either calling sequence */
             (w2 & 0xffff0000) == 0xff000000)
        {   char *name = (char *)(p - 8 - (w2 & 0xffff));
            if (onthisline != 0) fputc('\n', map_file);
            onthisline = 4;
            fprintf(map_file, "%s", name);
        }
        w2 = w1;
        w1 = w;
    }
    if (onthisline != 0) fputc('\n', map_file);
}

void _mapstore()
{
    _map_store(stderr);
}

void _fmapstore(char *filename)
{
    FILE *map_file = fopen(filename, "w");
    if (map_file == NULL)
    {   fprintf(stderr, "\nUnable to open %s for execution profile log\n",
                        filename);
        return;
    }
    _map_store(map_file);
    fclose(map_file);
    fprintf(stderr, "\nProfile information written to %s\n", filename);
}

void _write_profile(char *filename)
{
/* Create a (binary) file containing execution profile information for     */
/* the current program. The format is eccentric, and must be kept in step  */
/* with (a) parts of armgen.c that generate code that collects statistics  */
/* and (b) code in misc.c that reads in the binary file created here and   */
/* displays the counts attached to a source listing of the original code.  */
    int count1 = (int)_count1;
    int p, w1 = 0, w2 = 0, pass, nfiles = 0, namebytes = 0, ncounts = 0;
    int global_name_offset[256];
    char *global_file_map[256]; /* Limits total number of files allowed */
    FILE *map_file = fopen(filename, "wb");
    char *file_map;
    if (map_file == NULL)
    {   fprintf(stderr, "\nUnable to open %s for execution profile log\n",
                        filename);
        return;
    }
    for (pass = 1; pass <=2; pass++)
    {
        if (pass == 2)
        /* Write file header indicating size of sub-parts */
        {   fwrite("\xff*COUNTFILE*", 4, 3, map_file);
            fwrite(&namebytes, 4, 1, map_file);
            fwrite(&nfiles,    4, 1, map_file);
            fwrite(&ncounts,   4, 1, map_file);
            for (p = 0; p < nfiles; p++)
            {   char *ss = global_file_map[p];
                int len = 1 + strlen(ss);
                len = ((len + 3) & (~3)) / 4;
                fwrite(ss, 4, len, map_file);
            }
            for (p = 0; p < nfiles; p++)
                fwrite(&global_name_offset[p], 4, 1, map_file);
        }
        file_map = NULL;
        for (p = (int)RO_Base; p < (int)RO_Limit; p += 4)
        {   int w = *(int *)p;
            if ((w & 0xff000000) == 0xeb000000) /* BL instruction */
            {   int dest = (p + 8 + ((w << 8) >> 6));
                if (dest != count1 &&
                    dest >= (int)RO_Base && dest < (int)RO_Limit)
                {   /* Try for call through (straight) veneer */
                    int b = *(int *)dest;
                    if ((b & 0xff000000) == 0xea000000) /* Unconditional B */
                        dest = (dest + 8 + ((b << 8) >> 6));
                }
                if (dest == count1)
                {   count_position k;
                    int i;
                    char *s;
                    if (file_map == NULL ||
                        (int)file_map <= p) file_map = find_file_map(p+12);
                    s = file_map;
                    k.i = *(int *)(p + 8);
                    for (i = 0; i<k.s.file; i++)
                    {   s += 1 + strlen(s);
                        s = word_roundup(s);
                    }
                    if (pass == 1)
                    {   int i;
                        for (i = 0;;i++)
                        {   if (i >= nfiles)
                            {   global_name_offset[nfiles] = namebytes;
                                global_file_map[nfiles++] = s;
                                namebytes += 1 + strlen(s);
                                namebytes = (namebytes + 3) & (~3);
                                break;
                            }
                            else if (strcmp(s,global_file_map[i]) ==0) break;
                        }
                        ncounts++;
                    }
                    else
                    {   int i;
                        for (i = 0; strcmp(s, global_file_map[i]) !=0; i++);
                        fwrite((int *)(p + 4), 4, 1, map_file);
                        i = (k.s.line & 0xffff) | (i << 16);
                        fwrite(&i, 4, 1, map_file);
                    }
                    p += 8;
                }
            }
            w2 = w1;
            w1 = w;
        }
    }
    fwrite("\xff*ENDCOUNT*\n", 4, 3, map_file); /* Trailer data */
    fclose(map_file);
    fprintf(stderr, "\nProfile information written to %s\n", filename);
}
