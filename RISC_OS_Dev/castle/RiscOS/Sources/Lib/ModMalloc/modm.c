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
#include <stdlib.h>
#include <string.h>

#include "swis.h"

#include "Desk.Debug.h"
#include "Desk.Error.h"
#include "Desk.LinkList.h"

#ifdef MemCheck_MEMCHECK
#include "MemCheck.MemCheck.h"
#endif

#include "ModMalloc.ModMalloc.h"


typedef struct	{
	Desk_linklist_header	header;
	int			size;	/* Size including header	*/
	}
	ModMalloc_header;

static Desk_linklist_header	ModMalloc_blocks = { NULL, NULL};



#ifdef MemCheck_MEMCHECK
	#pragma -c0
	/* We don't want MemCheck checking accesses from within here...	*/
#endif


#ifdef Desk_DEBUG
	static void	ModMalloc_Debug_ShowBlocks( void)
		{
		ModMalloc_header*	header;
		Desk_Debug2_Printf( Desk_error_PLACE "ModMalloc blocks are:\n");
		for	(
			header = (ModMalloc_header*) Desk_LinkList_FirstItem( &ModMalloc_blocks);
			header;
			header = (ModMalloc_header*) Desk_LinkList_NextItem( &header->header)
			)
			{
			Desk_Debug2_Printf( Desk_error_PLACE "0x%p-0x%p (%i)\n", header+1, (char*) header + header->size, header->size-sizeof( *header));
			}
		Desk_Debug2_Printf( Desk_error_PLACE "\n");
		}
#else
	#define	ModMalloc_Debug_ShowBlocks()
#endif



static _kernel_oserror*	ModMalloc__Free( void* ptr)
	{
	ModMalloc_header*	header;
	_kernel_oserror*	e;

	Desk_Debug_Printf( Desk_error_PLACE "ModMalloc__Free( 0x%p)\n", ptr);
	ModMalloc_Debug_ShowBlocks();

	if ( !ptr)	return NULL;

#ifdef MemCheck_MEMCHECK
	MemCheck_UnRegisterMiscBlock( ptr);
#endif

	header	= ( (ModMalloc_header*) ptr) - 1;

		{
#ifdef MemCheck_MEMCHECK
		MemCheck_checking	oldchecking = MemCheck_SetChecking( 0, 0);
#endif
		#ifdef Desk_DEBUG
			if ( !Desk_LinkList_InList( &ModMalloc_blocks, &header->header))	{
				Desk_Debug_Printf( Desk_error_PLACE "Attempt to free unrecognised modmalloc block 0x%p\n", ptr);
				}
		#endif
		Desk_LinkList_Unlink( &ModMalloc_blocks, &header->header);
#ifdef MemCheck_MEMCHECK
		MemCheck_RestoreChecking( oldchecking);
#endif
		}


	/*last	= header->prev;*/
	e	= _swix( OS_Module, _IN(0)|_IN(2), 7, header);

	if (e)	{
		Desk_Debug_Printf( "ModMalloc_Free 0x%p failed\n", ptr);

		return e;
		}
	/*
	if ( ModMalloc_lastblock == header
	ModMalloc_lastblock = last;
	*/
	return NULL;
	}

void	ModMalloc_Free( void* ptr)
	{
	ModMalloc__Free( ptr);
	}


void	ModMalloc_FreeDownTo( void* first)
	{
	ModMalloc_header*	firstheader = (first) ? ((ModMalloc_header*) first) - 1 : NULL;
	ModMalloc_header*	header;
	Desk_Debug_Printf( "ModMalloc_FreeAll called\n");
	for	(
		header = (ModMalloc_header*) Desk_LinkList_LastItem( &ModMalloc_blocks);
		header;
		header = (ModMalloc_header*) Desk_LinkList_PreviousItem( &header->header)
		)
		{
		Desk_Debug_Printf( "ModMalloc_FreeAll: freeing 0x%p\n", (void *)(header+1));
		if ( ModMalloc__Free( header+1))	{
			Desk_Debug_Printf( "ModMalloc__Free returned error - teminating ModMalloc_FreeDownTo\n");
			break;
			}

		if ( header==firstheader)	break;
		/*
		if ( header==header->prev)	{
			Desk_Debug_Printf( "Circular list - terminating ModMalloc_FreeDownTo\n");
			break;
			}
		*/
		}
	Desk_Debug_Printf( "ModMalloc_FreeAll finished\n");
	}


void	ModMalloc_FreeAll( void)
	{
	ModMalloc_FreeDownTo( NULL);
	}


void*	ModMalloc_Malloc( size_t size)
	{
	ModMalloc_header*	header;
	_kernel_oserror*	e;
	/*
	static int		inited = 0;

	if (!inited)	{
		inited = 1;
		atexit( ModMalloc_FreeAll);
		}
	*/
	ModMalloc_Debug_ShowBlocks();
	size += sizeof( ModMalloc_header);
	e = _swix( OS_Module, _IN(0)|_IN(3)|_OUT(2), 6, size, &header);
	if (e)	{
		Desk_Debug_Printf( "ModMalloc_Malloc can't allocate memory\n");
		return NULL;
		}


#ifdef MemCheck_MEMCHECK
	MemCheck_RegisterMiscBlock( header, sizeof( *header));
#endif

	/*header->prev	= ModMalloc_lastblock;*/
	header->size	= size;
	/*ModMalloc_lastblock = header;*/

	/*
	#ifdef MemCheck_MEMCHECK
		memcpy( &ModMalloc_blocks, "\0\0\0\0\0\0\0\0", 8);
	#endif
	*/

	// Make sure previous item (if it exists) is known to MemCheck while we are adding to the link list.
#ifdef MemCheck_MEMCHECK
	if ( Desk_LinkList_LastItem( &ModMalloc_blocks))
		MemCheck_RegisterMiscBlock( Desk_LinkList_LastItem( &ModMalloc_blocks), sizeof( ModMalloc_header));
#endif

	Desk_LinkList_AddToTail( &ModMalloc_blocks, &header->header);

#ifdef MemCheck_MEMCHECK
	if ( Desk_LinkList_PreviousItem( &header->header))
		MemCheck_UnRegisterMiscBlock( Desk_LinkList_PreviousItem( &header->header));

	MemCheck_UnRegisterMiscBlock( header);

	MemCheck_RegisterMiscBlock( header+1, size - sizeof( ModMalloc_header));
#endif

	return (void*) (header+1);
	}




#define	ModMalloc_MIN( x, y)	( (x<y) ? x : y)

void*	ModMalloc_Realloc( void* ptr, size_t newsize)
	{
	ModMalloc_header*	header = ( (ModMalloc_header*) ptr) - 1;
	ModMalloc_header*	newheader;
	Desk_linklist_header*	oldprev;
	Desk_os_error*		e;

#ifdef MemCheck_MEMCHECK
	MemCheck_RegisterMiscBlock( header, sizeof( *header));
#endif

	oldprev = Desk_LinkList_PreviousItem( &header->header);
	Desk_LinkList_Unlink( &ModMalloc_blocks, &header->header);

	newsize += sizeof( ModMalloc_header);

	e = _swix( OS_Module, _IN(0)|_INR(2,3)|_OUT(2), 13, header, newsize-header->size, &newheader);

	if ( e)	{
		Desk_LinkList_InsertAfter( &ModMalloc_blocks, oldprev, &header->header);
#ifdef MemCheck_MEMCHECK
		MemCheck_UnRegisterMiscBlock( header);
#endif
		return NULL;
		}

#ifdef MemCheck_MEMCHECK
	MemCheck_UnRegisterMiscBlock( header);
	MemCheck_RegisterMiscBlock( newheader, sizeof( *newheader));
#endif

	newheader->size = newsize;
	Desk_LinkList_InsertAfter( &ModMalloc_blocks, oldprev, &newheader->header);
#ifdef MemCheck_MEMCHECK
	MemCheck_UnRegisterMiscBlock( newheader);
#endif

	return newheader+1;
	}




void*	ModMalloc_Calloc( size_t n, size_t size)
	{
	void*	ptr = ModMalloc_Malloc( n*size);
	ModMalloc_Debug_ShowBlocks();
	if (!ptr)	{
		Desk_Debug_Printf( "ModMalloc_Calloc failed\n");
		return ptr;
		}
	memset( ptr, 0, n*size);
	/*
	Don't need to call MeMCheck functions
	here - done by ModMalloc_Malloc/Free
	 */
	return ptr;
	}
