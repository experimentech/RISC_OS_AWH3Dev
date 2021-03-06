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
        These sources are concerned with the reclamation of detached objects
*/
#include <stdio.h>
#include <string.h>

#include "kernel.h"

#include "typedefs.h"
#include "EObjects.h"
#include "StatEMap.h"
#include "Dirs.h"
#include "Displays.h"

YesNoAnswer parent_doesnt_child_correctly
(
        disc_record const * const discrec,
        void const * const the_parent,
        void const * const the_child,
        indirect_disc_address dir_address
)
{
        char const * const pb = the_parent;
        char const * const cb = the_child;
        int i;
        char const * const cname = &cb[ NewDirLen + NewDirName ];
        int child_id;
        int child_att;

        for ( i = 0; i < 77; i++ )
        {
                /*
                        End of directory?
                */
                if ( pb[ DirFirstEntry + DirEntrySize * i + DirObName ] == '\0' )
                        break;

                if ( strcmp( &pb[ DirFirstEntry + DirEntrySize * i + DirObName ], cname ) )
                {
                        child_id = dir_read_bytes( &pb[ DirFirstEntry + DirEntrySize * i + DirIndDiscAdd], 3 );
                        child_att = dir_read_bytes( &pb[ DirFirstEntry + DirEntrySize * i + NewDirAtts], 1 );

                        if ( ((indirect_disc_address *)&child_id)->fragment_id == dir_address.fragment_id &&
                                ((indirect_disc_address *)&child_id)->sector_offset == dir_address.sector_offset &&
                                (child_att & Atts_DirBit) != 0 )
                        {
                                return No;
                        }

                        return Yes;
                }
        }

        return Yes;
}



/*
        Return the number of objects needing to be reclaimed
*/
int reclaim_number_of_objects
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        object_record *rover;
        int total_free_objects = 0;

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
                                total_free_objects ++;
                        }
                }
        }

        return total_free_objects;
}

/*
        Attach the given object to the given directory with the suggested name
*/
YesNoAnswer reclaim_object
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs,
        indirect_disc_address const dir_to_attach_to,
        object_record *its_record,
        indirect_disc_address its_address,
        char const * const suggested_name
)
{
        char the_dirbuffer[ NewDirLen ];
        void *dummy;
        unsigned int from_where;
        unsigned int how_much_left;
        _kernel_oserror *err;
        char *the_free_entry;
        char *the_inserted_entry;
        int i;

        /*
                Read the parent directory
        */
        dummy = the_dirbuffer;
        from_where = 0;
        how_much_left = NewDirLen;
        err = read_object_bytes( &dummy, dir_to_attach_to, &from_where, &how_much_left, discrec, map );

        if ( err )
        {
                printf( "Failed to read directory with ID %#x, going to insert in root directory\n", dir_to_attach_to.fragment_id );
        }

        /*
                If there's enough room for a new entry
        */
        if ( !err && (the_free_entry = (char *)dir_first_free_entry( discrec, the_dirbuffer )) != NULL )
        {
                /*
                        Translate the suggested name to uniqueness
**** skipped - run the disc fixer again if you're worried ****
                */

                /*
                        Find the right position
                */
                for ( i = 0; i < 77; i++ )
                {
                        if ( the_dirbuffer[ DirFirstEntry + DirEntrySize * i + DirObName ] == '\0' )
                                break;

                        if ( caseless_strcmp( suggested_name, &the_dirbuffer[ DirFirstEntry + DirEntrySize * i + DirObName ] ) < 0 )
                                break;
                }

                the_inserted_entry = &the_dirbuffer[ DirFirstEntry + DirEntrySize * i + DirObName ];

                memmove( the_inserted_entry + DirEntrySize,
                        the_inserted_entry,
                        the_free_entry - the_inserted_entry + 1 );

                /*
                        Insert the new entry (at the right position)
                */
                strncpy( &the_inserted_entry[ DirObName ], suggested_name, NameLen );
                dir_write_bytes( &the_inserted_entry[ DirLoad ], 4, 0xfffffd00 );
                dir_write_bytes( &the_inserted_entry[ DirExec ], 4, 0x00000000 );
                if ( its_record->type == directory )
                        dir_write_bytes( &the_inserted_entry[ DirLen ], 4, NewDirLen );
                else
                        dir_write_bytes( &the_inserted_entry[ DirLen ], 4, its_record->size );
                dir_write_bytes( &the_inserted_entry[ DirIndDiscAdd ], 3, *(int *)&its_address );
                dir_write_bytes( &the_inserted_entry[ NewDirAtts ], 1, (its_record->type == directory ? Atts_DirBit : 0) | Atts_ReadBit | Atts_WriteBit );

                printf( "Attching object %d to directry %d", its_record->id, dir_to_attach_to.fragment_id );
                if ( query( "Do you want this done" ) )
                {
                        if ( !writeout_directory( "directory being attached to", the_dirbuffer, dir_to_attach_to, discrec, map ) )
                        {
                                return No;
                        }
                }
                else
                {
                        return No;
                }
        }
        else
        {
                /*
                        reclaim the object to the root directory
                */

                /*
                        Read the root directory
                */
                dummy = the_dirbuffer;
                from_where = 0;
                how_much_left = NewDirLen;
                err = read_object_bytes( &dummy, discrec->root_directory.indirect, &from_where, &how_much_left, discrec, map );

                if ( err )
                {
                        printf( "Failed to read root directory due to a %s (%#010x) error - directories not attachable\n", err->errmess, err->errnum );
                        return No;
                }

                if ( (the_free_entry = (char *)dir_first_free_entry( discrec, the_dirbuffer )) != NULL )
                {
                        /*
                                Translate the suggested name to uniqueness
**** skipped - run the disc fixer again if you're worried ****
                        */

                        /*
                                Insert the new entry (at the end)
                        */
                        strncpy( &the_free_entry[ DirObName ], suggested_name, NameLen );
                        dir_write_bytes( &the_free_entry[ DirExec ], 4, 0xfffffd00 );
                        dir_write_bytes( &the_free_entry[ DirLoad ], 4, 0x00000000 );
                        dir_write_bytes( &the_free_entry[ DirLen ], 4, its_record->size );
                        dir_write_bytes( &the_free_entry[ DirIndDiscAdd ], 3, its_record->id<<8 );
                        dir_write_bytes( &the_free_entry[ NewDirAtts ], 1, (its_record->type == directory ? Atts_DirBit : 0) | Atts_ReadBit | Atts_WriteBit );

                        printf( "Attaching object %d to the root directory", its_record->id );
                        if ( query( "Do you want this done" ))
                        {
                                if ( !writeout_directory( "$", the_dirbuffer, dir_to_attach_to, discrec, map ) )
                                {
                                        return No;
                                }
                        }
                        else
                        {
                                return No;
                        }
                }
                else
                {
                        printf( "Root directory full - empty it using *rename or *delete then re-run this fixer\n" );
                        return No;
                }
        }

        if ( its_address.sector_offset > 0 )
        {
                its_record->status = shared;
        }
        else
        {
                its_record->status = used_once;
        }

        return Yes;
}

/*
        Attach the given directory to the given directory with the suggested name
*/
YesNoAnswer reclaim_directory
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs,
        indirect_disc_address const dir_to_attach,
        indirect_disc_address const dir_to_attach_to
)
{
        object_record *its_record;
        char the_path[100];
        char *suggested_name;
        char the_dirbuffer[ NewDirLen ];
        void *dummy;
        unsigned int from_where;
        unsigned int how_much_left;
        _kernel_oserror *err;

        dummy = the_dirbuffer;
        from_where = 0;
        how_much_left = NewDirLen;
        err = read_object_bytes( &dummy, dir_to_attach, &from_where, &how_much_left, discrec, map );

        if ( err )
        {
                suggested_name = "!";
        }
        else
        {
                suggested_name = &the_dirbuffer[ NewDirLen + NewDirName ];
        }

        its_record = find_obj_rec( all_objs, dir_to_attach.fragment_id );

        if ( its_record && reclaim_object( discrec, map, all_objs, dir_to_attach_to, its_record, dir_to_attach, suggested_name ) )
        {
                /*
                        Mark children as used and fix directories
                */
                sprintf( the_path, "<reclaimed directory '%s' (ID %#x)>", suggested_name, dir_to_attach.fragment_id );
                recurse_accum_directory_stats( all_objs, the_path, dir_to_attach_to, dir_to_attach, discrec, map );

                return Yes;
        }

        return No;
}

YesNoAnswer reclaim_file
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs,
        indirect_disc_address const obj_to_attach
)
{
        object_record *its_record;
        char suggested_name[ 20 ];

        its_record = find_obj_rec( all_objs, obj_to_attach.fragment_id );

        if ( its_record )
        {
                sprintf( suggested_name, "OB%08x", obj_to_attach.fragment_id );
                return reclaim_object( discrec, map, all_objs, discrec->root_directory.indirect, its_record, obj_to_attach, suggested_name );
        }

        return No;
}

/*
        For each free object check whether it's a directory
*/
void reclaim_identify_directories
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        object_record *rover;
        char the_dirbuffer[ NewDirLen ];
        void *dummy;
        unsigned int from_where;
        unsigned int how_much_left;
        _kernel_oserror *err;
        indirect_disc_address dir_address;

        for ( rover = all_objs;
                rover;
                rover = rover->next )
        {
                if ( rover->status == unused && rover->size >= NewDirLen )
                {
                        dummy = the_dirbuffer;
                        from_where = 0;
                        how_much_left = NewDirLen;
                        dir_address.disc_number = discrec->root_directory.indirect.disc_number;
                        dir_address.fragment_id = rover->id;
                        dir_address.sector_offset = 0;
                        err = read_object_bytes( &dummy, dir_address, &from_where, &how_much_left, discrec, map );
                        if ( err )
                        {
                                printf( "Failed to read object %#x due to a %s (%#010x) error\n", rover->id, err->errmess, err->errnum );
                                printf( "Classing this as a file for reclamation purposes\n" );
                                rover->type = file;
                                continue;
                        }

                        if ( directory_utterly_broken( the_dirbuffer, discrec ))
                        {
                                rover->type = file;
                        }
                        else
                        {
                                rover->type = directory;
                        }
                }
        }
}

int reclaim_number_of_loose_directories
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        int number_of_loose_directories = 0;
        object_record *rover;

        for ( rover = all_objs;
                rover;
                rover = rover->next )
        {
                if ( rover->status == unused && rover->type == directory )
                {
                        number_of_loose_directories++;
                }
        }

        return number_of_loose_directories;
}

/*
        Attach any directories which are loose in a reclaim fashion
*/
void reclaim_loose_directories
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        object_record *rover;
        object_record *parent_record;
        char the_dirbuffer[ NewDirLen ];
        char the_other_dirbuffer[ NewDirLen ];
        void *dummy;
        unsigned int from_where;
        unsigned int how_much_left;
        _kernel_oserror *err;
        indirect_disc_address dir_address;
        indirect_disc_address parent_address;
        int parent_id;
        YesNoAnswer a_directory_was_attached;

        /*
                While there are any loose directories left
        */
        while ( reclaim_number_of_loose_directories( discrec, map, all_objs ) > 0 )
        {
                /*
                        Try attaching easy loose directories until no more will attach
                */
                do
                {
                        a_directory_was_attached = No;

                        /*
                                Attach any loose directories whose:
                                        parent is an attached directory
                                        or parent doesn't exist as a directory
                        */
                        for ( rover = all_objs;
                                rover;
                                rover = rover->next )
                        {
                                if ( rover->status == unused && rover->type == directory )
                                {
                                        dummy = the_dirbuffer;
                                        from_where = 0;
                                        how_much_left = NewDirLen;
                                        dir_address.disc_number = discrec->root_directory.indirect.disc_number;
                                        dir_address.fragment_id = rover->id;
                                        dir_address.sector_offset = 1;
                                        err = read_object_bytes( &dummy, dir_address, &from_where, &how_much_left, discrec, map );

                                        /*
                                                Skip unreadable directories
                                        */
                                        if ( err )
                                                continue;

                                        /*
                                                Read the parent
                                        */
                                        parent_id = dir_read_bytes( the_dirbuffer + NewDirLen + NewDirParent, 3 );
                                        parent_address = *(indirect_disc_address *)&parent_id;
                                        parent_address.disc_number = discrec->root_directory.indirect.disc_number;

                                        parent_record = find_obj_rec( all_objs, parent_address.fragment_id );
                                        if ( parent_record &&
                                                parent_record->status != unused &&
                                                parent_record->status != unknown &&
                                                ( parent_record->type == directory ||
                                                  parent_record->type == root_directory ) )
                                        {
                                                /*
                                                        If the parent exists, is used and is a directory
                                                        then attach to the parent
                                                */
                                                reclaim_directory( discrec, map, all_objs, dir_address, parent_address );
                                                a_directory_was_attached = Yes;
                                        }
                                        else if ( !parent_record ||
                                                parent_record->type == file ||
                                                parent_record->type == bad_block )
                                        {
                                                /*
                                                        If the parent doesn't exist, or isn't a directory
                                                        then attach to the root directory
                                                */
                                                reclaim_directory( discrec, map, all_objs, dir_address, discrec->root_directory.indirect );
                                                a_directory_was_attached = Yes;
                                        }
                                }
                        }
                }
                while ( a_directory_was_attached );

                a_directory_was_attached = No;

                /*
                        Find a loose directory whose parent doesn't child it correctly
                */
                for ( rover = all_objs;
                        rover;
                        rover = rover->next )
                {
                        if ( rover->status == unused && rover->type == directory )
                        {
                                dummy = the_dirbuffer;
                                from_where = 0;
                                how_much_left = NewDirLen;
                                dir_address.disc_number = discrec->root_directory.indirect.disc_number;
                                dir_address.fragment_id = rover->id;
                                dir_address.sector_offset = 1;
                                err = read_object_bytes( &dummy, dir_address, &from_where, &how_much_left, discrec, map );

                                /*
                                        Skip unreadable directories
                                */
                                if ( err )
                                        continue;

                                /*
                                        Read the parent
                                */
                                parent_id = dir_read_bytes( the_dirbuffer + NewDirLen + NewDirParent, 3 );
                                parent_address = *(indirect_disc_address *)&parent_id;
                                parent_address.disc_number = discrec->root_directory.indirect.disc_number;

                                dummy = the_other_dirbuffer;
                                from_where = 0;
                                how_much_left = NewDirLen;
                                err = read_object_bytes( &dummy, parent_address, &from_where, &how_much_left, discrec, map );

                                if ( err ||
                                        parent_doesnt_child_correctly( discrec, the_other_dirbuffer, the_dirbuffer, dir_address ) )
                                {
                                        reclaim_directory( discrec, map, all_objs, dir_address, discrec->root_directory.indirect );
                                        a_directory_was_attached = Yes;
                                        break;
                                }
                        }
                }

                /*
                        Must be a duff parent or duff parent pointer generating a loop
                        hence, after breaking the duff loop have another go using the
                        previous algorithm.
                */
                if ( a_directory_was_attached )
                        continue;

                /*
                        At this stage if there's any loose directories then they *all* have
                        loose parents who child them correctly, ie its a well formed, detached
                        loop - break it!
                */

                /*
                        Find a loose directory
                */
                for ( rover = all_objs;
                        rover;
                        rover = rover->next )
                {
                        /*
                                Any loose directory is getting attached ***NOW***
                        */
                        if ( rover->status == unused && rover->type == directory )
                        {
                                dir_address.fragment_id = rover->id;
                                dir_address.sector_offset = 1;
                                reclaim_directory( discrec, map, all_objs, dir_address, discrec->root_directory.indirect );
                                break;  /* to try the other algorithms first */
                        }
                }
        }
}

/*
        Attach and files which are loose in a reclaim fashion
*/
void reclaim_loose_files
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{
        object_record *rover;
        indirect_disc_address odadd;

        /*
                Find the loose files
        */
        for ( rover = all_objs;
                rover;
                rover = rover->next )
        {
                /*
                        Any loose file is getting attached ***NOW***
                */
                if ( rover->status == unused &&
                        rover->type == file &&
                        rover->id > 2 )
                {
                        odadd.sector_offset = 0;
                        odadd.fragment_id = rover->id;
                        odadd.disc_number = discrec->root_directory.indirect.disc_number;
                        reclaim_file( discrec, map, all_objs, odadd );
                }
        }
}

/*
        Perform reclaim processing
*/
void reclaim_the_objects
(
        disc_record const * const discrec,
        void const * const map,
        object_record *all_objs
)
{

        printf( "Performing reclamation of free objects\n" );

        printf( "Pass 1 - determination of directories\n" );

        reclaim_identify_directories( discrec, map, all_objs );

        printf( "Pass 2 - reattach loose directories\n" );

        reclaim_loose_directories( discrec, map, all_objs );

        printf( "Pass 3 - reattach remaining loose files\n" );

        reclaim_loose_files( discrec, map, all_objs );

}
