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
     This header describes the interface to the listing of a selection
     of files.

     All the routines can be retried later if an error is returned.

Revision History:

0.00  02-Jun-89  JSR  Created when routines separated from c.actionwind.
*/

typedef struct search_context *search_handle;

/*
     Allocates and initialises a search context, placing the handle in
     the location specified. The char * is the root directory for the
     search, then first int is the recursive flag, and the second is the
     directories_too flag
*/
extern os_error *create_search_context( search_handle * );

/*
     informs that next node has been deleted
*/
void deleted_next_node( search_handle, char * );

/*
     Sets whether the search is recursive or not
*/
extern void recurse_search_context( search_handle, BOOL );

/*
     Sets whether directories should be returned before their contents.
     This is relevant only when recursing.
*/
extern void return_directories_first( search_handle, BOOL );

/*
     Sets whether directories should be returned after their contents.
     This is relevant only when recursing.
*/
extern void return_directories_last( search_handle, BOOL );

/*
     Sets whether partitions should be treated the same as directories or not.
     This is relevant only when recursing.
*/
extern void treat_partitions_as_directories( search_handle, BOOL );

/*
     Changes the directory throught which the search will take place
*/
os_error *set_directory( search_handle, char *directory );

/*
     Clears out a whole selection
*/
void clear_selection( search_handle );

/*
     Add a selected object to the search context. Selections are passed
     back in the order they where added.
*/
extern os_error *add_selection( search_handle, char *, int );

/*
     Junk a search context neatly
*/
extern void dispose_search_context( search_handle );

/*
     Return the next full object name found. Returns NULL in the pointer
     if none found (end of search). Malloc fails etc return an error
*/
extern os_error *next_nodename( search_handle, char ** );

/*
     Return a summary of the selection left to do
*/
extern os_error *selection_summary( search_handle handle, char **summary );

/*
     Reads parameters of next node - use this for updating oneself after
     an error
*/
extern void read_next_node_parameters( search_handle );

/*
     Returns the size in bytes of the next node:
     No node   -1
     Other     that given by filing system
*/
extern uint32_t size_of_next_node( search_handle );

/*
     Returns the reload address of the next node:
     No node   -1
     Other     that given by filing system
*/
extern int reload_of_next_node( search_handle );

/*
     Returns the execution address of the next node:
     No node   -1
     Other     that given by filing system
*/
extern int execute_of_next_node( search_handle );

/*
     Returns the attriibutes of the next node:
     No node   -1
     Other     that given by filing system
*/
extern int attributes_of_next_node( search_handle );

/*
     Returns the object type of the next node:
     No node   ObjectType_NotFound
     Other     that given by filing system
*/
extern int objecttype_of_next_node( search_handle );

/*
     Returns the name of the next node:
     No node   NULL
     Other     that given by filing system
*/
extern char *name_of_next_node( search_handle );

/*
        Assuming a directory has just been found, return whether this return
        of this directory was before or after its contents.
*/
extern BOOL directory_is_after_contents( search_handle );

/*
     returns non-0 if another node to come
     returns 0 if no more nodes
*/
extern BOOL another_node( search_handle );

/*
        When finding a selection fails call this to skip it.
*/
extern void skip_failed_selection( search_handle );

/*
        Will skip file/directory (and its contents)
*/
extern void skip_list_file( search_handle );

/*
     Step to the next node for return by next_filename.
*/
extern os_error *step_to_next_node( search_handle, uint32_t *progress );

#ifdef USE_PROGRESS_BAR
extern uint32_t progress_of_next_node( search_handle );
extern void **chain_ref_ptr_of_next_node( search_handle );
extern void listfiles_convert_to_copymove( search_handle handle );
#endif
