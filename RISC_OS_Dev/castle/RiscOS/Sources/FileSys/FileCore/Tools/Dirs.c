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
        Routines to comprehend directories
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "typedefs.h"
#include "EObjects.h"
#include "Dirs.h"
#include "StatEMap.h"
#include "Displays.h"
#include "Reclaim.h"
#include "kernel.h"
#include "typedefs.h"

indirect_disc_address nul_odadd = {0,0,0,0};

unsigned int dir_read_bytes
(
        void const * const where,
        unsigned int how_many
)
{
        unsigned char const *real = where;
        unsigned int result = 0;
        unsigned int shift = 0;

        while ( how_many-- )
        {
                result |= *(real++)<<shift;
                shift += bits_per_byte;
        }

        return result;
}

unsigned int dir_read_load
(
        void const * const directory,
        unsigned int const entry
)
{
        return dir_read_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirLoad), 4 );
}

unsigned int dir_read_exec
(
        void const * const directory,
        unsigned int const entry
)
{
        return dir_read_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirExec), 4 );
}

unsigned int dir_read_len
(
        void const * const directory,
        unsigned int const entry
)
{
        return dir_read_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirLen), 4 );
}

indirect_disc_address dir_read_objectid
(
        void const * const directory,
        unsigned int const entry
)
{
        union
        {
                unsigned int as_int;
                indirect_disc_address as_address;
        }       result;

        result.as_int = dir_read_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirIndDiscAdd), 3 );

        result.as_address.disc_number = 0;

        return result.as_address;
}

unsigned int dir_read_atts
(
        void const * const directory,
        unsigned int const entry
)
{
        return dir_read_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + NewDirAtts), 1 );
}

void dir_write_bytes
(
        void * const where,
        unsigned int how_many,
        unsigned int what
)
{
        unsigned char *real = where;

        while ( how_many-- )
        {
                *real++ = (char)(what & 0xff);
                what = what >> bits_per_byte;
        }
}

void dir_write_len
(
        void const * const directory,
        unsigned int const entry,
        unsigned int what
)
{
        dir_write_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirLen), 4, what );
}

void dir_write_objectid
(
        void const * const directory,
        unsigned int const entry,
        indirect_disc_address odadd
)
{
        dir_write_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + DirIndDiscAdd), 3, *(int *)&odadd );
}

void dir_write_atts
(
        void const * const directory,
        unsigned int const entry,
        unsigned int what
)
{
        dir_write_bytes( (void *)((int)directory + DirFirstEntry + DirEntrySize*entry + NewDirAtts), 1, what );
}

void const * const dir_first_free_entry
(
        disc_record const * const discrec,
        void const * const directory
)
{
        char const * const dir = directory;
        int i;

        for ( i = 0; i < 77; i++ )
        {
                if ( dir[ DirFirstEntry + DirEntrySize * i + DirObName ] == '\0' )
                        return &dir[ DirFirstEntry + DirEntrySize * i ];
        }

        return NULL;
}

int dir_check_byte
(
        char directory[ NewDirLen ]
)
{
        unsigned accumulator = 0;
        unsigned accumuland;
        int pos = 0;
        int endpos;


        endpos = 5;

        /*
                Accumulate whole words
        */
        while ( pos+3 < endpos )
        {
                /*
                        Accumulate words until end of entry reached
                */
                while ( pos+3 < endpos )
                {
                        accumuland = *(unsigned *)&directory[pos];
                        accumulator = accumuland ^ ((accumulator >> 13) | (accumulator << (32-13)));
                        pos += 4;
                }

                /*
                        If more to the directory, carry on
                */
                if ( directory[ endpos ] )
                {
                        endpos += 26;
                }
        }

        /*
                Accumulate bytes until end of start of dir reached
        */
        while ( pos < endpos )
        {
                accumuland = directory[pos];
                accumulator = accumuland ^ ((accumulator >> 13) | (accumulator << (32-13)));
                pos += 1;
        }

        /*
                Accumulate the end structure
        */
/*
        accumuland = directory[NewDirLen-41];
        accumulator = accumuland ^ ((accumulator >> 13) | (accumulator << (32-13)));
*/
        for ( pos = NewDirLen-40; pos < NewDirLen-4; pos += 4 )
        {
                accumuland = *(unsigned *)&directory[pos];
                accumulator = accumuland ^ ((accumulator >> 13) | (accumulator << (32-13)));
        }

        accumulator ^= accumulator >> 16;
        accumulator ^= accumulator >> 8;

        return accumulator & 0xff;
}

/*
        writeout the directory fixing the checkbyte as we go
*/
YesNoAnswer writeout_directory
(
        char const * const dirname,
        char directory[ NewDirLen ],
        indirect_disc_address dir,
        disc_record const * const discrec,
        void const * const map
)
{
        _kernel_oserror *err;
        void *dirp = directory;
        unsigned int from_where = 0;
        unsigned int how_much = NewDirLen;

        /*
                Fix the checkbyte
        */
        directory[ NewDirLen + DirCheckByte ] = dir_check_byte( directory );

        /*
                If anything has been fixed, then write out the directory
        */
        err = write_object_bytes( &dirp, dir, &from_where, &how_much, discrec, map );

        if ( err )
        {
                printf( "Failed to write directory %s due to %s.\n", dirname, err->errmess );
                return No;
        }
        else
        {
                printf( "Directory %s written to disc\n", dirname );
                return Yes;
        }
}

void nul_terminate
(
        char *str
)
{
        while ( *str > ' ' )
        {
                str++;
        }

        *str = '\0';
}

int isbadfilename
(
        char *str
)
{
        if ( strlen( str ) > 10 )
                return Yes;

        if ( *str == '\0' )
                return Yes;

        while ( *str )
        {
                if ( *str < 32 || strchr( "\"#$%&*.:@\\^|\x7f", *str ) != NULL )
                {
                        return Yes;
                }

                str++;
        }

        return No;
}

int caseless_strcmp( const char *a, const char *b )
{
        int d;

        while ( *a || *b )
        {
                d = toupper( *(a++) ) - toupper( *(b++) );
                if ( d )
                        return d;
        }

        return 0;
}

YesNoAnswer directory_utterly_broken
(
        char directory[ NewDirLen ],
        disc_record const * const discrec
)
{
        int i;
        char previous_name[ NameLen+1 ];
        char this_name[ NameLen+1 ];

        previous_name[0] = '\0';
        this_name[10] = '\0';

        /*
                Check start and end master sequence numbers match
        */
        if ( directory[ StartMasSeq ] != directory[ NewDirLen + EndMasSeq ] )
        {
                return Yes;
        }

        /*
                Check start and end names match, and are one of 'Hugo' or 'Nick'
        */
        if ( directory[ StartName ] != directory[ NewDirLen + EndName ] |
                directory[ StartName+1 ] != directory[ NewDirLen + EndName+1 ] |
                directory[ StartName+2 ] != directory[ NewDirLen + EndName+2 ] |
                directory[ StartName+3 ] != directory[ NewDirLen + EndName+3 ] )
        {
                return Yes;
        }
        else if ( ( directory[ StartName ] == 'N' &&
                        directory[ StartName + 1 ] == 'i' &&
                        directory[ StartName + 2 ] == 'c' &&
                        directory[ StartName + 3 ] == 'k' ) ||
                  ( directory[ StartName ] == 'H' &&
                        directory[ StartName + 1 ] == 'u' &&
                        directory[ StartName + 2 ] == 'g' &&
                        directory[ StartName + 3 ] == 'o' ) )
        {
                /* Do nothing - it's right */
        }
        else
        {
                return Yes;
        }

        /*
                Check the names are good, and in order
        */
        for ( i = 0; i < 77; i++ )
        {
                memcpy( this_name, &directory[ DirFirstEntry + DirEntrySize*i + DirObName ], NameLen );
                nul_terminate( this_name );

                if ( this_name [ 0 ] == '\0' )
                        break;

                if ( isbadfilename( this_name ))
                {
                        return Yes;
                }
                else if ( caseless_strcmp( previous_name, this_name ) >= 0 )
                {
                        return Yes;
                }
                else
                {
                        strcpy( previous_name, this_name );
                }
        }

        /*
                Check the checkbyte is correct
        */
        if ( dir_check_byte( directory ) != directory[ NewDirLen + DirCheckByte ] )
        {
                return Yes;
        }

        return No;
}

void check_and_fix_directory
(
        char const * const dirname,
        char directory[ NewDirLen ],
        indirect_disc_address parent_dir,
        indirect_disc_address dir,
        disc_record const * const discrec,
        void const * const map
)
{
        YesNoAnswer fix_parent = No;
        YesNoAnswer fix_sequences = No;
        YesNoAnswer fix_names = No;
        YesNoAnswer fix_checkbyte = No;
        YesNoAnswer fix_entries[ 77 ];
        YesNoAnswer truncate_here[ 77 ];
        YesNoAnswer fix_dirlens[ 77 ];
        int i;
        int j;
        char previous_name[ NameLen+1 ];
        char this_name[ NameLen+1 ];
        int t;
        indirect_disc_address parent_in_dir;

        previous_name[0] = '\0';
        this_name[10] = '\0';

        /*
                Initialise the entry names to fix to be none
        */
        for ( i = 0; i < 77; i++ )
        {
                fix_entries[ i ] = No;
                fix_dirlens[ i ] = No;
                truncate_here[ i ] = No;
        }

        /*
                Check start and end master sequence numbers match
        */
        if ( directory[ StartMasSeq ] != directory[ NewDirLen + EndMasSeq ] )
        {
                printf( "Directory %s has mismatched sequences numbers: Start=%d; End=%d\n", dirname, directory[ StartMasSeq ], directory[ NewDirLen + EndMasSeq ] );
                if ( query( "Do you want them fixed" ))
                {
                        fix_sequences = Yes;
                        fix_checkbyte = Yes;
                }
        }

        /*
                Check start and end names match, and are one of 'Hugo' or 'Nick'
        */
        if ( directory[ StartName ] != directory[ NewDirLen + EndName ] |
                directory[ StartName+1 ] != directory[ NewDirLen + EndName+1 ] |
                directory[ StartName+2 ] != directory[ NewDirLen + EndName+2 ] |
                directory[ StartName+3 ] != directory[ NewDirLen + EndName+3 ] )
        {
                printf( "Directory %s has mismatched start and end names: Start=%c%c%c%c; End=%c%c%c%c\n", dirname,
                        directory[ StartName ], directory[ StartName+1 ], directory[ StartName+2 ], directory[ StartName+3 ],
                        directory[ NewDirLen + EndName ], directory[ NewDirLen + EndName+1 ], directory[ NewDirLen + EndName+2 ], directory[ NewDirLen + EndName+3 ] );

                if ( query( "Do you want them fixed" ))
                {
                        fix_names = Yes;
                        fix_checkbyte = Yes;
                }
        }
        else if ( ( directory[ StartName ] == 'N' &&
                        directory[ StartName + 1 ] == 'i' &&
                        directory[ StartName + 2 ] == 'c' &&
                        directory[ StartName + 3 ] == 'k' ) ||
                  ( directory[ StartName ] == 'H' &&
                        directory[ StartName + 1 ] == 'u' &&
                        directory[ StartName + 2 ] == 'g' &&
                        directory[ StartName + 3 ] == 'o' ) )
        {
                /* Do nothing - it's right */
        }
        else
        {
                printf( "Directory %s doesn't have Hugo or Nick as its name: it is %c%c%c%c\n", dirname,
                        directory[ StartName ], directory[ StartName+1 ], directory[ StartName+2 ], directory[ StartName+3 ] );

                if ( query( "Do you want them fixed" ))
                {
                        fix_names = Yes;
                        fix_checkbyte = Yes;
                }
        }

        /*
                Check parent address
        */
        t = dir_read_bytes( &directory[ NewDirLen + NewDirParent ], 3 );
        parent_in_dir = *(indirect_disc_address *)&t;
        if ( parent_in_dir.fragment_id != parent_dir.fragment_id ||
                parent_in_dir.sector_offset != parent_dir.sector_offset )
        {
                printf( "Directory %s has parent field of %#x, and a parent of %#x\n", dirname, *(int *)&parent_in_dir, *(int *)&parent_dir );

                if ( query( "Do you want this fixed" ))
                {
                        fix_parent = Yes;
                        fix_checkbyte = Yes;
                }
        }

        /*
                Check the names are good, and in order
        */
        for ( i = 0; i < 77; i++ )
        {
                if ( directory[ DirFirstEntry + DirEntrySize*i + DirObName ] == '\0' )
                        break;

                memcpy( this_name, &directory[ DirFirstEntry + DirEntrySize*i + DirObName ], NameLen );
                nul_terminate( this_name );

                if ( (dir_read_atts( directory, i ) & Atts_DirBit) != 0 &&
                        dir_read_len( directory, i ) != NewDirLen )
                {
                        printf( "Directory %d in directory %s has length %d stored\n", i, dirname, dir_read_len( directory, i ) );
                        if ( query( "Do you want this length corrected" ))
                        {
                                fix_dirlens[ i ] = Yes;
                                fix_checkbyte = Yes;
                        }
                }

                if ( isbadfilename( this_name ))
                {
                        printf( "Name %d in directory %s is bad: it is '%s'\n", i, dirname, this_name );

                        if ( query( "Do you want it fixed" ))
                        {
                                fix_entries[ i ] = Yes;
                                fix_checkbyte = Yes;
                        }
                }
                else if ( caseless_strcmp( previous_name, this_name ) >= 0 )
                {
                        printf( "Name %d in directory %s is out of order: previous name is '%s'; this name is '%s'\n",
                                i, dirname, previous_name, this_name );

                        if ( query( "Do you want it fixed" ))
                        {
                                fix_entries[ i ] = Yes;
                                fix_checkbyte = Yes;
                        }
                        if ( query( "Do you want the directory truncated here" ))
                        {
                                truncate_here[ i ] = Yes;
                                fix_checkbyte = Yes;
                        }
                }
                else
                {
                        strcpy( previous_name, this_name );
                }
        }

        /*
                Check the checkbyte is correct
        */
        if ( dir_check_byte( directory ) != directory[ NewDirLen + DirCheckByte ] )
        {
                printf( "Directory %s has incorrect check byte: it is %#04X and should be %#04X\n", dirname,
                        directory[ NewDirLen + DirCheckByte ], dir_check_byte( directory ) );

                if ( fix_checkbyte )
                {
                        printf( "It will be fixed as a consequence of other fixes\n" );
                }
                else if ( query( "Do you want it fixed" ))
                {
                        fix_checkbyte = Yes;
                }
        }

        /*
                Fix the start and end sequence numbers to be the same
        */
        if ( fix_sequences )
        {
                 directory[ NewDirLen + EndMasSeq ] = directory[ StartMasSeq ];
        }

        /*
                Fix the start and end names
        */
        if ( fix_names )
        {
                if ( directory[ StartName ] != directory[ NewDirLen + EndName ] |
                        directory[ StartName+1 ] != directory[ NewDirLen + EndName+1 ] |
                        directory[ StartName+2 ] != directory[ NewDirLen + EndName+2 ] |
                        directory[ StartName+3 ] != directory[ NewDirLen + EndName+3 ] )
                {
                        /*
                                Fix names which are different to each other
                        */
                        if ( ( directory[ StartName ] == 'N' &&
                                directory[ StartName + 1 ] == 'i' &&
                                directory[ StartName + 2 ] == 'c' &&
                                directory[ StartName + 3 ] == 'k' ) ||
                          ( directory[ StartName ] == 'H' &&
                                directory[ StartName + 1 ] == 'u' &&
                                directory[ StartName + 2 ] == 'g' &&
                                directory[ StartName + 3 ] == 'o' ) )
                        {
                                /*
                                        Copy good start name over end name
                                */
                                directory[ NewDirLen + EndName ] = directory[ StartName ];
                                directory[ NewDirLen + EndName+1 ] = directory[ StartName+1 ];
                                directory[ NewDirLen + EndName+2 ] = directory[ StartName+2 ];
                                directory[ NewDirLen + EndName+3 ] = directory[ StartName+3 ];
                        }
                        else if ( ( directory[ NewDirLen + EndName ] == 'N' &&
                                directory[ NewDirLen + EndName + 1 ] == 'i' &&
                                directory[ NewDirLen + EndName + 2 ] == 'c' &&
                                directory[ NewDirLen + EndName + 3 ] == 'k' ) ||
                          ( directory[ NewDirLen + EndName ] == 'H' &&
                                directory[ NewDirLen + EndName + 1 ] == 'u' &&
                                directory[ NewDirLen + EndName + 2 ] == 'g' &&
                                directory[ NewDirLen + EndName + 3 ] == 'o' ) )
                        {
                                /*
                                        Copy good end name over bad start name
                                */
                                directory[ StartName ] = directory[ NewDirLen + EndName ];
                                directory[ StartName+1 ] = directory[ NewDirLen + EndName+1 ];
                                directory[ StartName+2 ] = directory[ NewDirLen + EndName+2 ];
                                directory[ StartName+3 ] = directory[ NewDirLen + EndName+3 ];
                        }
                        else
                        {
                                /*
                                        Set both bad names to 'Nick'
                                */
                                directory[ StartName ] = 'N';
                                directory[ StartName+1 ] = 'i';
                                directory[ StartName+2 ] = 'c';
                                directory[ StartName+3 ] = 'k';
                                directory[ NewDirLen + EndName ] = 'N';
                                directory[ NewDirLen + EndName+1 ] = 'i';
                                directory[ NewDirLen + EndName+2 ] = 'c';
                                directory[ NewDirLen + EndName+3 ] = 'k';
                        }
                }
                else
                {
                        /*
                                Set both bad names to 'Nick'
                        */
                        directory[ StartName ] = 'N';
                        directory[ StartName+1 ] = 'i';
                        directory[ StartName+2 ] = 'c';
                        directory[ StartName+3 ] = 'k';
                        directory[ NewDirLen + EndName ] = 'N';
                        directory[ NewDirLen + EndName+1 ] = 'i';
                        directory[ NewDirLen + EndName+2 ] = 'c';
                        directory[ NewDirLen + EndName+3 ] = 'k';
                }
        }

        /*
                Fix the parent
        */
        if ( fix_parent )
        {
                dir_write_bytes( &directory[ NewDirLen + NewDirParent ], 3, *(int *)&parent_dir );
        }

        /*
                Fix the names
        */
        previous_name[ 0 ] = '\0';
        for ( i = 0; i < 77; i++ )
        {
                if ( fix_dirlens[ i ] )
                {
                        dir_write_len( directory, i, NewDirLen );
                }

                if ( fix_entries[ i ] )
                {
                        /*
                                Generate next valid name from previous name
                        */
                        strcpy( this_name, previous_name );

                        if ( strlen( previous_name ) >= NameLen )
                        {
                                while ( strlen( this_name ) > 0 && this_name[ strlen( this_name ) - 1 ] == 255 )
                                {
                                        this_name[ strlen( this_name ) - 1 ] = '\0';
                                }

                                if ( strlen( this_name ) == 0 )
                                {
                                        for ( j = 0; j < NameLen; j++ )
                                        {
                                                /*
                                                        BOG IT! Run out of names - generate the last possible name
                                                */
                                                this_name[ j ] = 255;
                                        }
                                }
                                else
                                {
                                        /*
                                                The next NameLen char long name
                                        */
                                        this_name[ strlen( this_name ) - 1 ] += 1;
                                }
                        }
                        else
                        {
                                /*
                                        The minimally next name
                                */
                                strcat( this_name, "!" );
                        }

                        /*
                                Copy the name across
                        */
                        for ( j = 0; this_name[ j ]; j++ )
                        {
                                directory[ DirFirstEntry + DirEntrySize*i + DirObName + j ] = this_name[ j ];
                        }

                        directory[ DirFirstEntry + DirEntrySize*i + DirObName + j ] = 0x0d;
                }
                else if ( truncate_here[ i ] )
                {
                        directory[ DirFirstEntry + DirEntrySize*i + DirObName + 0 ] = 0;
                }
                else
                {
                        memcpy( this_name, &directory[ DirFirstEntry + DirEntrySize*i + DirObName ], NameLen );
                        nul_terminate( this_name );
                }

                strcpy( previous_name, this_name );
        }

        /*
                Fix the checkbyte has nothing to do as it's a consequence of writeout_directory
        */

        /*
                If anything has been fixed, then write out the directory
        */
        if ( fix_sequences || fix_names || fix_parent || fix_checkbyte )
        {
                (void)writeout_directory( dirname, directory, dir, discrec, map );
        }
}

void recurse_directory_display
(
        char const * const prefix,
        indirect_disc_address dir,
        disc_record * discrec,
        void const * const map
)
{
        char *next_prefix = malloc( strlen( prefix ) + 12 );
        char directory[ NewDirLen ];
        char name[ NameLen+1 ];
        void *dirp = directory;
        unsigned int from_where;
        unsigned int how_much;
        _kernel_oserror *err;
        unsigned int rover;
        unsigned int entryno;
        int i;

        from_where = 0;
        how_much = NewDirLen;
        err = read_object_bytes( &dirp, dir, &from_where, &how_much, discrec, map );

        if ( err )
        {
                printf( "Failed to read directory %s due to %s.\n", prefix, err->errmess );

                free( next_prefix );

                return;
        }

        for ( entryno = 0, rover = DirFirstEntry;
                directory[rover];
                entryno ++, rover += DirEntrySize )
        {
                strcpy( next_prefix, prefix );
                strcat( next_prefix, "." );

                for ( i = 0; i < NameLen && directory[ rover+i ] > ' '; i++ )
                        name[ i ] = directory[ rover+i ];

                name[ i ] = '\0';

                strcat( next_prefix, name );

                if ( dir_read_atts( directory, entryno ) & Atts_DirBit )
                {
                        recurse_directory_display( next_prefix, dir_read_objectid( directory, entryno ), discrec, map );
                }
                else
                {
                        printf( "%s\n", next_prefix );
                }
        }

        free( next_prefix );
}


void recurse_accum_directory_stats
(
        object_record *all_obj_recs,
        char const * const prefix,
        indirect_disc_address parent_dir,
        indirect_disc_address dir,
        disc_record const * const discrec,
        void const * const map
)
{
        char *next_prefix = malloc( strlen( prefix ) + 12 );
        char directory_buffer[ NewDirLen ];
        char name[ NameLen+1 ];
        void *dirp = directory_buffer;
        unsigned int from_where;
        unsigned int how_much;
        _kernel_oserror *err;
        unsigned int rover;
        unsigned int entryno;
        indirect_disc_address odadd;
        object_record *this_objs_record;
        int i;

        from_where = 0;
        how_much = NewDirLen;
        err = read_object_bytes( &dirp, dir, &from_where, &how_much, discrec, map );

        if ( err )
        {
                printf( "Failed to read directory %s due to %s.\n", prefix, err->errmess );

                free( next_prefix );

                return;
        }

        check_and_fix_directory( prefix, directory_buffer, parent_dir, dir, discrec, map );

        for ( entryno = 0, rover = DirFirstEntry;
                directory_buffer[rover];
                entryno ++, rover += DirEntrySize )
        {
                strcpy( next_prefix, prefix );
                strcat( next_prefix, "." );

                for ( i = 0; i < NameLen && directory_buffer[ rover+i ] > ' '; i++ )
                        name[ i ] = directory_buffer[ rover+i ];

                name[ i ] = '\0';

                strcat( next_prefix, name );

                odadd = dir_read_objectid( directory_buffer, entryno );

                /*
                        Ensure the unused field is zero
                */
                if ( odadd.unused != 0 )
                {
                        printf( "Object %s has an unused field of %x\n", next_prefix, odadd.unused );

                        if ( query( "Do you want this zeroed" ))
                        {
                                odadd.unused = 0;
                                dir_write_objectid( directory_buffer, entryno, odadd );
                                writeout_directory( prefix, directory_buffer, dir, discrec, map );
                        }
                }

                this_objs_record = find_obj_rec( all_obj_recs, odadd.fragment_id );

                if ( this_objs_record )
                {
                        /*
                                Immediate information about object
                        */
                        if ( this_objs_record->size < dir_read_len( directory_buffer, entryno ) )
                        {
                                printf( "Object &%X (length %d) is too small for %s (length %d)\n", odadd.fragment_id, dir_read_len( directory_buffer, entryno ), next_prefix, this_objs_record->size );
                                if ( query( "Do you want the length truncated" ))
                                {
                                        dir_write_len( directory_buffer, entryno, this_objs_record->size );
                                        writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                }
                        }

                        /*
                                Don't allow refences to
                                        (i) the bad block list: 1
                                        (ii) the map and root directory: 2
                        */
                        if ( this_objs_record->id == 1 ||
                                (this_objs_record->id == 2 && odadd.sector_offset == 0) )
                        {
                                switch ( this_objs_record->id )
                                {
                                case 1:
                                        printf( "Entry %s refers to the bad block object\n", next_prefix );
                                        break;
                                case 2:
                                        printf( "Entry %s refers to the map/root/boot block object\n", next_prefix );
                                        break;
                                }

                                if ( query( "Do you want it detached and truncated" ))
                                {
                                        dir_write_len( directory_buffer, entryno, 0 );
                                        dir_write_objectid( directory_buffer, entryno, nul_odadd );
                                        writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                }
                        }

                        /*
                                Don't allow non-shared directories GT NewDirSize
                        */
                        if ( (dir_read_atts( directory_buffer, entryno ) & Atts_DirBit) &&
                                odadd.sector_offset == 0 &&
                                this_objs_record->size > NewDirLen )
                        {
                                printf( "Directory %s is unshared\n", next_prefix );
                                if ( query( "Do you want it made shared" ))
                                {
                                        odadd.sector_offset = 1;
                                        dir_write_objectid( directory_buffer, entryno, odadd );
                                        writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                }
                        }

                        /*
                                Stats for second pass
                        */
                        switch( this_objs_record->status )
                        {
                        case unused:
                                if ( (dir_read_atts( directory_buffer, entryno ) & Atts_DirBit) == 0 )
                                {
                                        this_objs_record->used_from_directory = dir;
                                }
                                else
                                {
                                        this_objs_record->used_from_directory = dir_read_objectid( directory_buffer, entryno );
                                }

                                if ( odadd.sector_offset )
                                {
                                        this_objs_record->status = shared;
                                }
                                else
                                {
                                        this_objs_record->status = used_once;
                                }
                                break;

                        case used_once:
                                this_objs_record->status = used_many;
                                break;

                        case shared:
                        case shared_across_directories:
                                if ( !odadd.sector_offset )
                                {
                                        this_objs_record->status = used_many;
                                }
                                else if ( this_objs_record->used_from_directory.fragment_id != dir.fragment_id &&
                                        (dir_read_atts( directory_buffer, entryno ) & Atts_DirBit) == 0 )
                                {
                                        this_objs_record->status = shared_across_directories;
                                }
                                break;

                        case used_many:
                                break;

                        default:
                                printf( "internal structure not initialised - giving up!\n" );
                                exit(0);
                        }
                }
                else
                {
                        if ( dir_read_len( directory_buffer, entryno ) > 0 )
                        {
                                printf( "No fragments for %s - it's length is %d\n", next_prefix, dir_read_len( directory_buffer, entryno ) );

                                if ( query( "Do you want the length set to 0" ))
                                {
                                        dir_write_len( directory_buffer, entryno, 0 );
                                        dir_write_objectid( directory_buffer, entryno, nul_odadd );
                                        writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                }
                        }
                }

                if ( dir_read_atts( directory_buffer, entryno ) & Atts_DirBit )
                {
                        if ( !this_objs_record )
                        {
                                printf( "Directory %s has no fragments assigned to it\n", next_prefix );

                                if ( query( "Do you want it downgraded to a file" ))
                                {
                                        dir_write_atts( directory_buffer, entryno, dir_read_atts( directory_buffer, entryno ) & ~Atts_DirBit );
                                        writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                }
                        }
                        else
                        {
                                if ( odadd.fragment_id == 2 )
                                        this_objs_record->type = root_directory;
                                else
                                        this_objs_record->type = directory;

                                if ( dir_read_len( directory_buffer, entryno ) < NewDirLen &&
                                        this_objs_record->size >= NewDirLen )
                                {
                                        printf( "Directory %s has a length recorded shorter than needed\n", next_prefix );

                                        if ( query( "Do you want the length upgraded to be its actual length" ))
                                        {
                                                dir_write_len( directory_buffer, entryno, this_objs_record->size );
                                                writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                        }
                                }
                                else if ( this_objs_record->size < NewDirLen )
                                {
                                        printf( "Directory %s is not big enough to be a directory\n", next_prefix );

                                        if ( query( "Do you want it dowgraded to a file" ))
                                        {
                                                dir_write_atts( directory_buffer, entryno, dir_read_atts( directory_buffer, entryno ) & ~Atts_DirBit );
                                                writeout_directory( prefix, directory_buffer, dir, discrec, map );
                                        }
                                }
                                else
                                {
                                        recurse_accum_directory_stats( all_obj_recs, next_prefix, dir, odadd, discrec, map );
                                }
                        }
                }
                else
                {
                        if ( this_objs_record )
                        {
                                this_objs_record->type = file;
                        }
                }
        }

        free( next_prefix );
}

static void recurse_summarise_directory_stats
(
        object_record *all_obj_recs,
        char const * const prefix,
        indirect_disc_address dir,
        disc_record const * const discrec,
        void const * const map
)
{
        char *next_prefix = malloc( strlen( prefix ) + 12 );
        char directory[ NewDirLen ];
        char name[ NameLen+1 ];
        void *dirp = directory;
        unsigned int from_where;
        unsigned int how_much;
        _kernel_oserror *err;
        unsigned int rover;
        unsigned int entryno;
        indirect_disc_address odadd;
        object_record *this_objs_record;
        int i;

        from_where = 0;
        how_much = NewDirLen;
        err = read_object_bytes( &dirp, dir, &from_where, &how_much, discrec, map );

        if ( err )
        {
                printf( "Failed to read directory %s due to %s.\n", prefix, err->errmess );

                free( next_prefix );

                return;
        }

        for ( entryno = 0, rover = DirFirstEntry;
                directory[rover];
                entryno ++, rover += DirEntrySize )
        {
                strcpy( next_prefix, prefix );
                strcat( next_prefix, "." );

                for ( i = 0; i < NameLen && directory[ rover+i ] > ' '; i++ )
                        name[ i ] = directory[ rover+i ];

                name[ i ] = '\0';

                strcat( next_prefix, name );

                odadd = dir_read_objectid( directory, entryno );

                this_objs_record = find_obj_rec( all_obj_recs, odadd.fragment_id );

                if ( this_objs_record )
                {
                        /*
                                
                        */
                        switch( this_objs_record->status )
                        {
                        case used_many:
                                printf( "Object &%X illegally shared by %s (&%X)\n", odadd.fragment_id, next_prefix, *(int *)&odadd );
                                break;

                        case shared_across_directories:
                                printf( "Object &%X illegally shared across directories by %s (&%X)\n", odadd.fragment_id, next_prefix, *(int *)&odadd );
                                break;

                        default:
                                /*
                                        No problem
                                */
                                break;
                        }
                }

                if ( dir_read_atts( directory, entryno ) & Atts_DirBit &&
                        this_objs_record )
                {
                        recurse_summarise_directory_stats( all_obj_recs, next_prefix, odadd, discrec, map );
                }
        }

        free( next_prefix );
}

void summarise_under_usages
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        object_record *rover;
        int loose_objects = 0;

        for ( rover = all_objs;
                rover;
                rover = rover->next )
        {
                if ( rover->status == unused )
                {
                        if ( rover->id == 1 )
                        {
                                printf( "%d bytes given over to mapping out bad blocks in %d fragments\n", rover->size, rover->fragments );
                        }
                        else if ( rover->id == 2 )
                        {
/*
        Insert checking of object 2 verses map and directory requirements
*/
                                printf( "Root directory and map object is %d bytes in %d fragments\n", rover->size, rover->fragments );
                        }
                        else
                        {
                                loose_objects++;
/*
                                printf( "Object &%X (%d bytes in %d fragments) unused:", rover->id, rover->size, rover->fragments );
                                diplay_objects_fragments( rover->id, discrec, map );
*/
                        }
                }
        }

        if ( loose_objects )
        {
                printf( "There are %d loose objects\n", loose_objects );
                if ( query( "Do you want them reclaimed" ) )
                {
                        reclaim_the_objects( discrec, map, all_objs );
                }
        }
}

void accum_and_display_directory_stats
(
        disc_record const * const discrec,
        void const * const map
)
{
        object_record *all_objs;

        printf( "Pass 1 - identify all fragments in the map\n" );

        accumulate_fragments( discrec, map, &all_objs );

        printf( "Pass 2 - wander the directory tree checking lengths in directories against objects in the map\n" );

        recurse_accum_directory_stats( all_objs, "$", discrec->root_directory.indirect, discrec->root_directory.indirect, discrec, map );

        printf( "Pass 3 - analyse under usages\n" );

        summarise_under_usages( discrec, map, all_objs );

        printf( "Pass 4 - analyse over usages\n" );

        recurse_summarise_directory_stats( all_objs, "$", discrec->root_directory.indirect, discrec, map );

        junk_fragment_list( all_objs );
}
