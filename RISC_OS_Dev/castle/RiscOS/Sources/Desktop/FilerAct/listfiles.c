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
     List files as specified in a selection.

Revision History:

0.00  02-Jun-89  JSR  Created from extracts of c.actionwind.

0.01  27-Jun-89  JSR  Update to cope with arbitrary length file names.

0.02  29-Sep-89  JSR  Use overflowing_ memory allocation routines.
                      Add selection_summary.
                      Add name_of_next_node.

0.03  17-Oct-89  JSR  Upgrade next_nodename and next_filename to not
                      prepend the directory if the directory is a nul
                      string.
*/

#if 0
#define debuglist(k) dprintf k
#else
#define debuglist(k) /* Disabled */
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "Interface/HighFSI.h"

#include "os.h"

#include "Options.h"
#include "malloc+.h"
#include "listfiles.h"
#include "allerrs.h"
#include "debug.h"
#include "memmanage.h"

#define No 0
#define Yes (!No)

#define Directory_Buffer_Size 20
#define Temp_DirBuffer_Size   640

typedef struct
{
     int      load_address;
     int      execution_address;
     uint32_t length;
     int      attributes;
     int      object_type;
     char     *object_name;

     #ifdef USE_PROGRESS_BAR
     void     *chain_ref;
     #endif

}    directory_buffer_entry;

typedef struct Search_Nest_Level
{
     struct Search_Nest_Level *next_search_nest_level;
     int                      offset_to_next_item;
     int                      entries_in_buffer;
     int                      next_entry_to_return;
     directory_buffer_entry   directory_buffer[ Directory_Buffer_Size ];

     #ifdef USE_PROGRESS_BAR
     BOOL                     counted;
     uint32_t                 total_entries;
     int                      total_progress;
     int                      progress_per_object;
     #endif

}    search_nest_level;

typedef struct File_Selection
{
     struct File_Selection *next_file;
     char                  *selection_name;
}    file_selection;

/*
     This enumerates the states for finding the next leaf to process.
*/
typedef enum
{
     Next_Leaf,               /* Find the next leaf at this level */
     Process_Node,            /* Process that found by Next_Leaf */
     Read_Next_Cache_Full,    /* Read another directory cache-full */
     Nest_Into_Directory      /* Start up into a nested directory */
}    next_leaf_state;

typedef struct search_context
{
    search_nest_level *nested_filenames;
    char              *directory;
    file_selection    *selection;
    file_selection    **last_selections_link;
    next_leaf_state   action;
    uint32_t          selections_size;
    int               selections_loadaddr;
    int               selections_execaddr;
    int               selections_attributes;
    int               selections_objecttype;
    int               recursive:1;
    int               directories_first:1;
    int               directories_last:1;
    int               partitions_as_directories:1;

    #ifdef USE_PROGRESS_BAR
    uint32_t          total_entries;
    int               total_progress;
    int               progress_per_object;
    void              *chain_ref;
    #endif

} search_context;

#ifdef USE_PROGRESS_BAR
static uint32_t count_objects_in_dir( char *dir )
{
    os_error   *err;
    os_gbpbstr request;
    char       buff[Temp_DirBuffer_Size];
    int        context = 0, c, num = 0;
    uint32_t   total = 0;

    while (context != -1)
    {
        request.action      = OSGBPB_ReadDirEntries;
        request.file_handle = (int)dir;
        request.data_addr   = buff;
        request.number      = 256;
        request.seq_point   = context;
        request.buf_len     = Temp_DirBuffer_Size;
        request.wild_fld    = 0;

        err = os_gbpb( &request );
        num = request.number;
        c = request.seq_point;
        if (err == NULL)
        {
            if (c == context)
            {
                /*
                   Broken archives cause context to never be updated ... not sure why
                   the SWI does not return an error.
                */
                debuglist(( "count_objects_in_dir: aborting\n" ));
                return 0;
            }

            context = c;
            total += num;
        }
        else
        {
            debuglist(( "count_objects_in_dir: %s\n", err->errmess ));
            return 0;
        }
    }

    return total;
}
#endif

/*
     This initialises an empty search context.
     The search will return a list of files or directories, which must
     be added to the context after it has been created. The context is
     created recursive.
*/
os_error *create_search_context( search_handle *handle )
{
    search_context *new_context;

    if ( ( new_context = overflowing_malloc( sizeof( search_context ))) != NULL )
    {
        *handle = (search_handle)new_context;
        new_context->directory = NULL;
        new_context->nested_filenames = NULL;
        new_context->selection = NULL;
        new_context->last_selections_link = &new_context->selection;
        new_context->recursive = Yes;
        new_context->directories_first = No;
        new_context->directories_last = No;
        new_context->partitions_as_directories = Yes;
        new_context->action = Process_Node;

        #ifdef USE_PROGRESS_BAR
        new_context->total_entries = 0;
        new_context->total_progress = INT32_MAX;
        new_context->progress_per_object = 0;
        new_context->chain_ref = NULL;
        #endif

        return NULL;
    }
    else
    {
        return error( mb_malloc_failed );
    }
}


static int is_a_directory( search_handle handle, int objecttype )
{
    if ( objecttype == object_directory ||
            (objecttype == (object_directory | object_file) &&
             handle->partitions_as_directories) )
    {
            return Yes;
    }
    else
    {
            return No;
    }
}

/*
     Sets whether the search is recursive or not
*/
void recurse_search_context( search_handle handle, BOOL recursive )
{
    /*
            Make sure when changing to recursive that the children of this
            directory get returned
    */
    if ( !handle->recursive &&
         recursive &&
         is_a_directory( handle, objecttype_of_next_node( handle )) &&
         handle->action == Next_Leaf )
    {
            handle->action = Nest_Into_Directory;
    }

    handle->recursive = recursive != No;
}

/*
    Sets whether directories should be returned before their contents.
    This is relevant only when recursing.
*/
void return_directories_first( search_handle handle, BOOL directories_first )
{
    ((search_context *)handle)->directories_first = directories_first != No;
}

/*
    Sets whether directories should be returned after their contents.
    This is relevant only when recursing.
*/
void return_directories_last( search_handle handle, BOOL directories_last )
{
    handle->directories_last = directories_last != No;
}

/*
     Sets whether partitions should be treated the same as directories or not.
     This is relevant only when recursing.
*/
void treat_partitions_as_directories( search_handle handle, BOOL partitions_are_directories )
{
    handle->partitions_as_directories = partitions_are_directories;
}

/*
     Changes the directory in which the search will take place
*/
os_error *set_directory( search_handle handle, char *directory )
{
     search_context *context = (search_context *)handle;

     if ( context->directory )
     {
         overflowing_free( context->directory );
     }

     if ( ( context->directory = overflowing_malloc( strlen( directory ) + 1 )) != NULL )
     {
         strcpy( context->directory, directory );

         return NULL;
     }
     else
     {
         return error( mb_malloc_failed );
     }
}

/*
     frees the passed selection
*/
static void free_selection( file_selection *selection )
{
     overflowing_free( selection->selection_name );
     overflowing_free( selection );
}

/*
     Clears down a whole selection
*/
void clear_selection( search_handle handle )
{
     search_context *context = (search_context *)handle;
     file_selection *next_selection;
     file_selection *this_selection;

     /*
      Free the chain of selections
     */
     for ( this_selection = context->selection;
       this_selection != NULL;
       this_selection = next_selection )
     {
         next_selection = this_selection->next_file;
         free_selection( this_selection );
     }

     /*
      close off the head of the list
     */
     context->selection = NULL;
     context->last_selections_link = &context->selection;
}

/*
     Add a selection to an initialised search context. The search context
     will return found files in the order in which they were added.
*/
os_error *add_selection( search_handle handle, char *file_name, int wordlen )
{
     file_selection *new_selection;
     search_context *context = (search_context *)handle;

     /*
      These two if statements allocate the new selection structure and
      then some space for the file name. The mallocs are checked to
      work, and if they don't everything is tidied up and an error
      is returned.
     */
     new_selection = overflowing_malloc( sizeof( file_selection ));
     if ( new_selection != NULL )
     {
         new_selection->selection_name = overflowing_malloc( wordlen + 1 );
         if ( new_selection->selection_name != NULL )
         {
              /*
               Everything allocated OK, so copy the string and
               link the new selection onto the end of the list.
              */
              *context->last_selections_link = new_selection;
              strncpy( new_selection->selection_name, file_name, wordlen );
              new_selection->selection_name[ wordlen ] = '\0';
              context->last_selections_link = &new_selection->next_file;
              new_selection->next_file = NULL;

              debuglist(( "context: %x new selection: %s\n", context, new_selection->selection_name ));
              #ifdef USE_PROGRESS_BAR
              context->total_entries++;
              context->progress_per_object = context->total_progress / context->total_entries;
              #endif

              return NULL;
         }
         else
         {
              /*
               No room for selection name.
               Free up the selection structure and tidy up the ends
              */
              overflowing_free( new_selection );

              return error( mb_malloc_failed );
         }
     }
     else
     {
         return error( mb_malloc_failed );
     }
}

/*
     Free the abstract data type search_context. This is an equivalent
     to free(), but for this data type. It free all things hanging off it
     as well as the base structure.
*/
void dispose_search_context( search_handle handle )
{
     search_context *context = (search_context *)handle;
     search_nest_level *rover;
     search_nest_level *temp_rover;
     int i;

     /*
      Free the search nest level chain
     */
     rover = context->nested_filenames;

     while( rover != NULL )
     {
         temp_rover = rover;
         rover = rover->next_search_nest_level;
         for ( i = 0; i < Directory_Buffer_Size; i++ )
         {
              overflowing_free( temp_rover->directory_buffer[ i ].object_name );
         }
         overflowing_free( temp_rover );
     }

     clear_selection( handle );

     overflowing_free( context->directory );

     overflowing_free( context );
}

static int size_of_next_filename( search_context *context, search_nest_level *nesting )
{
     search_nest_level *nest_level = nesting;
     int returned_length = 0;

     if ( context->directory &&
      context->selection &&
      context->selection->selection_name )
     {
         returned_length = strlen( context->directory );

         /*
              Only Add one in if there's going to be a . in between dir and selection
         */
         if ( returned_length )
              returned_length++;

         returned_length += strlen( context->selection->selection_name );

         if ( context->recursive )
         {
              while (( nest_level != NULL ) && ( nest_level->next_entry_to_return >= 0 ) && ( nest_level->next_entry_to_return < nest_level->entries_in_buffer ))
              {
                  returned_length += 1 + strlen( nest_level->
                                                directory_buffer[ nest_level->next_entry_to_return ].
                                                object_name );
                  nest_level = nest_level->next_search_nest_level;
              }
         }
     }

     return returned_length;
}

/*
     Returns a pointer to the next filename in search_context

     This is a 'malloc'ed piece of memory, which should be 'free'ed when
     it is no longer needed.
*/
static os_error *next_filename( search_context *context, search_nest_level *nesting, char **hook_location )
{
     search_nest_level *nest_level = nesting;
     char *buffer = NULL;
     char *rover;
     int next_filename_size = size_of_next_filename( context, nesting );
     int part_length;

     if ( next_filename_size > 0 )
     {
         buffer = overflowing_malloc( next_filename_size + 1 );

         if ( buffer == NULL )
         {
              return error( mb_malloc_failed );
         }
     }

     if ( buffer != NULL )
     {
         if ( context->directory[0] )
         {
              sprintf( buffer, "%s.%s", context->directory, context->selection->selection_name );
         }
         else
         {
              sprintf( buffer, "%s", context->selection->selection_name );
         }

         rover = buffer + next_filename_size;

         *rover = '\0';

         while (( nest_level != NULL ) && ( nest_level->next_entry_to_return >= 0 ) && ( nest_level->next_entry_to_return < nest_level->entries_in_buffer ))
         {
              part_length = strlen( nest_level->
                directory_buffer[ nest_level->next_entry_to_return ].
                object_name );
              rover -= part_length + 1;

              rover[0] = '.';

              memcpy( &rover[1], nest_level->
                directory_buffer[ nest_level->next_entry_to_return ].
                object_name, part_length );

              nest_level = nest_level->next_search_nest_level;
         }
     }

     *hook_location = buffer;

     return NULL;
}

os_error *next_nodename( search_handle handle, char **hook_location )
{
     search_context *context = (search_context *)handle;
     return next_filename( context, context->nested_filenames, hook_location );
}

os_error *selection_summary( search_handle handle, char **summary )
{
    search_context *context = (search_context *)handle;
    char *cont;

    if ( context->selection == NULL )
    {
        cont = msgs_lookup("93"); /* 'nothing' */
    }
    else if ( context->selection->next_file == NULL )
    {
        cont = context->selection->selection_name;
    }
    else
    {
        cont = msgs_lookup("92"); /* 'many' */
    }

    *summary = overflowing_malloc( strlen( context->directory ) + 1 + strlen( cont ) + 1 );

    if ( *summary == NULL )
        return error( mb_malloc_failed );

    sprintf( *summary, "%s.%s", context->directory, cont );

    return NULL;
}

/*
     Finds the degree by which mstring matches the current next node.
     It returns the next mismatching position, and other information
     concerning where the mismatch occured
*/
static char *first_position_not_matched( search_handle handle, search_nest_level *nl, char *mstring,
     search_nest_level **deepest_match, search_nest_level **shallowest_non_match )
{
     char *matched_position;
     char *ms;
     int dl;
     int sl;

     if ( nl == NULL )
     {
         matched_position = mstring;

         dl = strlen( handle->directory );

         if ( strncmp( handle->directory, matched_position, dl ) != 0 )
              return NULL;

         matched_position += dl;

         if ( *matched_position != '.' )
              return NULL;

         matched_position += 1;

         sl = strlen( handle->selection->selection_name );

         if ( strncmp( handle->selection->selection_name, matched_position, sl ) != 0 )
              return NULL;

         matched_position += sl;

         return matched_position;
     }
     else
     {
         matched_position = first_position_not_matched( handle, nl->next_search_nest_level, mstring,
              deepest_match, shallowest_non_match );

         if ( matched_position == NULL )
              return NULL;

         ms = nl->directory_buffer[ nl->next_entry_to_return ].object_name;
         sl = strlen( ms );

         if ( *matched_position == '.' &&
              strncmp( matched_position + 1, ms, sl ) == 0 )
         {
              matched_position += 1 + sl;

              *deepest_match = nl;
         }
         else
         {
              if ( nl->next_search_nest_level == *deepest_match )
              {
                  *shallowest_non_match = nl;
              }
         }

         return matched_position;
     }
}

/*
    Informs that next node has been deleted
*/
void deleted_next_node( search_handle handle, char *deleted_node )
{
    if ( handle->nested_filenames && handle->selection )
    {
        char *matched_position;
        search_nest_level *deepest_match = NULL;
        search_nest_level *shallowest_non_match = NULL;

        matched_position = first_position_not_matched( handle, handle->nested_filenames, deleted_node, &deepest_match, &shallowest_non_match );

        if ( matched_position != NULL )
        {
            /*
             Deleted node is before something in shallowest non-match
            */
            if ( matched_position == strrchr( deleted_node, '.' ) &&
                 shallowest_non_match != NULL )
            {
                    shallowest_non_match->offset_to_next_item--;
            }

            /*
             Deleted is current node or a parent of it (gulp!)
            */
            if ( *matched_position == '\0' &&
                 deepest_match != NULL )
            {
                    deepest_match->offset_to_next_item--;
            }
        }
    }
}

/*
     Read the parameters for the next node, don't update
     if an error occurs
*/
void read_next_node_parameters( search_handle handle )
{
    os_filestr fileplace;
    char *filename;
    os_error *err;

    err = next_nodename( handle, &filename );

    if ( err || filename == NULL )
            return;

    fileplace.action = OSFile_ReadInfo;
    fileplace.name = filename;

    err = os_file( &fileplace );

    if ( err )
            return;

    handle->selections_size       = fileplace.start;
    handle->selections_loadaddr   = fileplace.loadaddr;
    handle->selections_execaddr   = fileplace.execaddr;
    handle->selections_attributes = fileplace.end;
}

typedef enum {
  the_size, the_load_address, the_execute_address, the_attributes, the_type, the_name
  #ifdef USE_PROGRESS_BAR
  , the_progress, the_ref_ptr
  #endif
} which_thing;

/*
    Returns one of the values associated with the next node.
    If the node doesn't exist the value not_found is returned.
*/
static int thing_of_next_node( search_handle handle, which_thing thing, int not_found )
{
    search_context *context = (search_context *)handle;
    search_nest_level *nf;

    if ( context->selection )
    {
        if ( (nf = context->nested_filenames) == NULL )
        {
            switch( thing )
            {
            case the_size:
                return (int) context->selections_size;
            case the_load_address:
                return context->selections_loadaddr;
            case the_execute_address:
                return context->selections_execaddr;
            case the_attributes:
                return context->selections_attributes;
            case the_type:
                return context->selections_objecttype;
            case the_name:
                return (int) context->selection->selection_name;

            #ifdef USE_PROGRESS_BAR
            case the_progress:
                if (context->selections_objecttype == object_directory)
                {
                    debuglist(( "ponn: selection: %08x\n", 0 ));
                    return 0;
                }
                else
                {
                    debuglist(( "ponn: selection: %08x\n", context->progress_per_object ));
                    return context->progress_per_object;
                }

            case the_ref_ptr:
                return (int) &context->chain_ref;
            #endif

            } /* end switch */
        }
        else
        {
            directory_buffer_entry *d;

            d = nf->directory_buffer + nf->next_entry_to_return;

            switch( thing )
            {
            case the_size:
                return (int) d->length;
            case the_load_address:
                return d->load_address;
            case the_execute_address:
                return d->execution_address;
            case the_attributes:
                return d->attributes;
            case the_type:
                return d->object_type;
            case the_name:
                return (int) d->object_name;

            #ifdef USE_PROGRESS_BAR
            case the_progress:
                if (d->object_type == object_directory)
                {
                    debuglist(( "ponn: nested: %08x\n", 0 ));
                    return 0;
                }
                else
                {
                    debuglist(( "ponn: nested: %08x\n", nf->progress_per_object ));
                    return nf->progress_per_object;
                }

            case the_ref_ptr:
                return (int) &d->chain_ref;
            #endif

            }
        }
    }

    debuglist(( "tonn: not found\n" ));

    return not_found;
}

uint32_t size_of_next_node( search_handle handle )
{
    return (uint32_t)thing_of_next_node( handle, the_size, 0 );
}

int reload_of_next_node( search_handle handle )
{
    return thing_of_next_node( handle, the_load_address, -1 );
}

int execute_of_next_node( search_handle handle )
{
    return thing_of_next_node( handle, the_execute_address, -1 );
}

int attributes_of_next_node( search_handle handle )
{
    return thing_of_next_node( handle, the_attributes, -1 );
}

int objecttype_of_next_node( search_handle handle )
{
    return thing_of_next_node( handle, the_type, object_nothing );
}

char *name_of_next_node( search_handle handle )
{
    return (char *)thing_of_next_node( handle, the_name, NULL );
}

#ifdef USE_PROGRESS_BAR
uint32_t progress_of_next_node( search_handle handle )
{
    return (uint32_t)thing_of_next_node( handle, the_progress, 0 );
}


void **chain_ref_ptr_of_next_node( search_handle handle )
{
    return (void **)thing_of_next_node( handle, the_ref_ptr, NULL );
}
#endif

/*
    Assuming a directory has just been found, return whether this return
    of this directory was before or after its contents.
*/
BOOL directory_is_after_contents( search_handle handle )
{
    search_context *context = (search_context *)handle;

    return context->action == Next_Leaf;
}

/*
     Returns 0 if no more nodes
     Returns non-0 if more nodes
*/
BOOL another_node( search_handle handle )
{
    return ((search_context *)handle)->selection != NULL;
}

/*
    When finding a selection fails call this to skip it.
*/
void skip_failed_selection( search_handle handle )
{
    search_context *context = (search_context *)handle;

    switch ( context->action )
    {
    case Next_Leaf:
        /*
        Can't generate an error in this state
        */
        break;

    case Process_Node:
        context->action = Next_Leaf;
        break;

    case Read_Next_Cache_Full:
        /*
        This forces un-nesting then continuing at the upper level
        */
        context->nested_filenames->offset_to_next_item = -1;
        break;

    case Nest_Into_Directory:
        context->action = Next_Leaf;
        break;
    }
}

void skip_list_file( search_handle handle )
{
    search_context *context = (search_context *)handle;

    context->action = Next_Leaf;
}

os_error *step_to_next_node( search_handle handle, uint32_t *progress )
{
    search_context *context = (search_context *)handle;
    search_nest_level *temp_context;
    os_gbpbstr gbpbplace;
    os_filestr fileplace;
    char temp_directory_buffer[ Temp_DirBuffer_Size ];
    int i;
    int pos;
    BOOL resolved = No;
    os_error *err = NULL;
    file_selection *next_selection;
    int objecttype;

    debuglist(( "\nstep_to_next_node\n" ));

    /*
        While the answer hasn't resolved itself and there's no error
        then try the next step of resolving the answer
    */
    while( !resolved && !err )
    {
        switch( context->action )
        {
        case Next_Leaf:
            /*
                Step to the next leaf at this nesting level
            */
            debuglist(( "Next_Leaf " ));
            if ( context->nested_filenames == NULL )
            {
                /*
                    Get next selection
                */
                next_selection = context->selection->next_file;
                free_selection( context->selection );
                context->selection = next_selection;

                debuglist(( "get next selection" ));

                context->action = Process_Node;
            }
            else
            {
                /*
                    Get next cached entry
                */
                context->nested_filenames->next_entry_to_return++;
                if ( context->nested_filenames->next_entry_to_return >=
                 context->nested_filenames->entries_in_buffer )
                {
                    /*
                        We've run out of cached entries
                    */
                    debuglist(( "cache empty " ));
                    context->action = Read_Next_Cache_Full;
                }
                else
                {
                    /*
                        Found an entry in the cache, so let's
                        process it
                    */
                    debuglist(( "cache ok " ));
                    context->action = Process_Node;
                }
            }
            break;

        case Process_Node:
            /*
                Process the node as supplied by Next_Leaf
            */
            debuglist(( "Process_Node " ));
            if ( context->selection == NULL )
            {
                /*
                    No more entries in the selection, so we've
                    resolved what happens next
                */
                debuglist(( "resolved all " ));
                resolved = Yes;
            }
            else
            {
                /*
                    Get type of node if needed
                */
                debuglist(( "%s ", name_of_next_node( context ) ));
                if ( context->nested_filenames == NULL )
                {
                    fileplace.action = OSFile_ReadNoPath;
                    err = next_filename( context, context->nested_filenames, &fileplace.name );
                    debuglist(( "%s ", fileplace.name ));

                    if ( err )
                    {
                        debuglist(( "err\n" ));
                        continue;
                    }

                    err = os_file( &fileplace );

                    if ( err )
                    {
                        overflowing_free( fileplace.name );
                        debuglist(( " error\n" ));
                        continue;
                    }

                    /*
                        Didn't find a selection - generate an error.
                    */
                    if ( fileplace.action == object_nothing )
                    {
                        fileplace.loadaddr = fileplace.action;
                        fileplace.action = OSFile_MakeError;
                        err = os_file( &fileplace );
                        overflowing_free( fileplace.name );
                        debuglist(( " not found\n" ));
                        continue;
                    }

                    overflowing_free( fileplace.name );

                    context->selections_objecttype = fileplace.action;
                    context->selections_size = fileplace.start;
                    context->selections_loadaddr = fileplace.loadaddr;
                    context->selections_execaddr = fileplace.execaddr;
                    context->selections_attributes = fileplace.end;
                } /* end if (nested_filenames == NULL) */

                objecttype = objecttype_of_next_node( (search_handle)context );

                if ( objecttype == object_nothing )
                {
                    /*
                        Didn't find that, so go around
                        for another time - nothing to do here
                    */
                    debuglist(( "not found " ));

                    context->action = Next_Leaf;
                }
                else if ( context->recursive &&
                      is_a_directory( context, objecttype ) )
                {
                    /*
                        If we are returning directories first, then
                        we have resolved it at this level
                    */
                    debuglist(( "directory " ));
                    resolved = context->directories_first;

                    context->action = Nest_Into_Directory;
                }
                else
                {
                    /*
                        Found a file or we found a directory
                        when not recursing, in which case
                        we've found something worth while and
                        so we've resolved things.
                    */
                    resolved = Yes;
                    context->action = Next_Leaf;
                    debuglist(( "resolved " ));

                }
            }
            break;

        case Read_Next_Cache_Full:
            /*
                If run out of entries in this directory
            */
            debuglist(( "Read_Next_Cache_Full " ));
            if ( context->nested_filenames->offset_to_next_item == -1 )
            {
                #ifdef USE_PROGRESS_BAR
                search_nest_level *nf = context->nested_filenames;
                int p = 0;

                /*
                   Compensate for rounding errors by adding the 'spare' progress
                   Isn't totally accurate if copying, as the actual progress values
                   used will have been halved.
                */
                p = nf->total_progress - (nf->total_entries * nf->progress_per_object);
                if (p > 0) *progress += (uint32_t)p;
                debuglist(( "finished %d entries (total %08x) extra progress +%08x", nf->total_entries, nf->total_progress, p ));
                #else
                IGNORE(progress);
                #endif

                /*
                    Down down one level
                */
                temp_context = context->nested_filenames->next_search_nest_level;
                for ( i = 0; i < Directory_Buffer_Size; i++ )
                {
                    overflowing_free( context->nested_filenames->directory_buffer[ i ].object_name );
                }
                overflowing_free( context->nested_filenames );
                context->nested_filenames = temp_context;

                /*
                    Return the directory after all the files in it
                */
                resolved = context->directories_last;

                context->action = Next_Leaf;
            }
            else
            {
                char **filename_store;
                search_nest_level *nf = context->nested_filenames;

                /*
                    Read more of this directory
                */
                gbpbplace.action      = OSGBPB_ReadDirEntriesInfo;

                err = next_filename( context, nf->next_search_nest_level, (char **)&gbpbplace.file_handle );

                if ( err )
                    continue;

                debuglist(( "%s ", (char *)gbpbplace.file_handle ));


                #ifdef USE_PROGRESS_BAR
                if (!nf->counted)
                {
                    nf->total_entries = count_objects_in_dir( (char *)gbpbplace.file_handle );
                    nf->counted = Yes;
                    if (nf->total_entries != 0)
                    {
                        nf->progress_per_object = nf->total_progress / nf->total_entries;
                    }
                    else
                    {
                        void *ref;

                        /*
                           Modify progress values so that half the progress for the dir is
                           added when the dir is finished (in the rounding process above)
                           and the other half when written. We have to do this now as when
                           the dir was added to the chain, we didn't know it was empty.
                           Of course if the dir is not in the chain, we are not copying, and
                           so we add all the progress for this dir at once.
                        */

                        if (nf->next_search_nest_level == NULL)
                        {
                            /* top level */
                            ref = context->chain_ref;
                        }
                        else
                        {
                            int i = nf->next_search_nest_level->next_entry_to_return;
                            ref = nf->next_search_nest_level->directory_buffer[i].chain_ref;
                        }

                        if (ref != NULL)
                        {
                            nf->total_progress /= 2;
                            nf->progress_per_object = 0;
                            modify_chain_file_progress(ref, nf->total_progress);
                        }

                    } /* end if (total_entries > 0) */

                    debuglist(( "%d entries %08x total progress %08x per object ", nf->total_entries, nf->total_progress, nf->progress_per_object ));

                } /* end if (!counted) */

                #endif

                gbpbplace.data_addr   = &temp_directory_buffer;
                gbpbplace.number      = Directory_Buffer_Size;
                gbpbplace.seq_point   = context->nested_filenames->offset_to_next_item;
                gbpbplace.buf_len     = Temp_DirBuffer_Size;
                gbpbplace.wild_fld    = "*";

                err = os_gbpb( &gbpbplace );
                overflowing_free( (void *)gbpbplace.file_handle );

                if ( err )
                {
                    if ( (err->errnum & FileError_Mask) == ErrorNumber_NotFound )
                    {
                        /*
                                Cancel the error
                        */
                        err = NULL;

                        /*
                             Down down one level
                        */
                        temp_context = context->nested_filenames->next_search_nest_level;
                        for ( i = 0; i < Directory_Buffer_Size; i++ )
                        {
                                overflowing_free( context->nested_filenames->directory_buffer[ i ].object_name );
                        }
                        overflowing_free( context->nested_filenames );
                        context->nested_filenames = temp_context;

                        /*
                                Don't return the directory, as it
                                doesn't exist!
                        */

                        context->action = Next_Leaf;
                    }

                    continue;
                }

                for ( i = 0, pos = 0; i < gbpbplace.number; i++ )
                {
                    context->nested_filenames->directory_buffer[ i ].load_address      = *(int *)&temp_directory_buffer[ pos ];
                    pos += sizeof(int);
                    context->nested_filenames->directory_buffer[ i ].execution_address = *(int *)&temp_directory_buffer[ pos ];
                    pos += sizeof(int);
                    context->nested_filenames->directory_buffer[ i ].length            = *(uint32_t *)&temp_directory_buffer[ pos ];
                    pos += sizeof(uint32_t);
                    context->nested_filenames->directory_buffer[ i ].attributes        = *(int *)&temp_directory_buffer[ pos ];
                    pos += sizeof(int);
                    context->nested_filenames->directory_buffer[ i ].object_type       = *(int *)&temp_directory_buffer[ pos ];
                    pos += sizeof(int);

                    /*
                        Free the filename if there's one there
                    */
                    filename_store = &context->nested_filenames->directory_buffer[ i ].object_name;
                    if ( *filename_store )
                    {
                        overflowing_free ( *filename_store );
                        *filename_store = NULL;
                    }

                    /*
                        Allocate some space for the file name
                    */
                    if ( ( *filename_store = overflowing_malloc( strlen( &temp_directory_buffer[ pos ] ) + 1 ) ) == NULL )
                    {
                        /*
                                If the allocation failed, free everything up
                        */
                        int j;

                        for ( j = 0; j < i; j++ )
                        {
                                overflowing_free( context->nested_filenames->directory_buffer[ j ].object_name );
                                context->nested_filenames->directory_buffer[ j ].object_name = NULL;
                        }

                        err = error( mb_malloc_failed );

                        break;
                    }

                    strcpy( *filename_store, &temp_directory_buffer[ pos ] );

                    pos += strlen( &temp_directory_buffer[ pos ] ) + 1;

                    /* round pos up to a word boundary */
                    pos = (( pos + 3 ) / 4 ) * 4;
                }

                if ( err )
                    break;

                context->nested_filenames->offset_to_next_item = gbpbplace.seq_point;
                context->nested_filenames->entries_in_buffer = gbpbplace.number;
                context->nested_filenames->next_entry_to_return = -1;

                context->action = Next_Leaf;
            }
        break;

        case Nest_Into_Directory:
            /*
                Go down into the next nesting level
            */
            debuglist(( "Nest_Into_Directory " ));

            temp_context = context->nested_filenames;

            context->nested_filenames = overflowing_malloc( sizeof( search_nest_level ));
            if ( context->nested_filenames == NULL )
            {
                context->nested_filenames = temp_context;
                err = error( mb_malloc_failed );
                continue;
            }

            context->nested_filenames->next_search_nest_level = temp_context;
            context->nested_filenames->offset_to_next_item = 0;
            context->nested_filenames->entries_in_buffer = 0;
            context->nested_filenames->next_entry_to_return = -1;

            #ifdef USE_PROGRESS_BAR
            if (temp_context != NULL)
            {
              context->nested_filenames->total_progress = temp_context->progress_per_object;
            }
            else
            {
              context->nested_filenames->total_progress = context->progress_per_object;
            }
            /* Default values, will be overwitten if this object is a dir */
            context->nested_filenames->progress_per_object = 0;
            context->nested_filenames->total_entries = 0;
            context->nested_filenames->counted = No;
            #endif

            for ( i = 0; i < Directory_Buffer_Size; i++ )
            {
                context->nested_filenames->directory_buffer[ i ].object_name = NULL;
                #ifdef USE_PROGRESS_BAR
                context->nested_filenames->directory_buffer[ i ].chain_ref = NULL;
                #endif
            }

            context->action = Next_Leaf;

            break;

        default:  /* disaster!!!!! */
            err = error( mb_unexpected_state );
            break;
        } /* end switch */

        debuglist(( "\n" ));

    } /* end while */

    return err;
}


#ifdef USE_PROGRESS_BAR
void listfiles_convert_to_copymove( search_handle handle )
{
  search_context *context = (search_context *)handle;

  if (context == NULL) return;

  context->total_progress /= 2;
}
#endif
