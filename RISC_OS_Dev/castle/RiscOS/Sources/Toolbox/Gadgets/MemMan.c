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
/* Title:   MemMan.c
 * Purpose: Memory manager module.  This provides a shifting heap.
 * Clients access blocks via handles allowing the blocks to be moved
 * by the manager.  The manager also manages free space at the end
 * of each block enabling small insertions and deletions to be handled
 * efficiently.
 *
 * Revision History
 * rlougher  Nov 96 Created
 * rlougher 17/3/97 Corrected MemChecking code
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "messages.h"
#include "objects/gadgets.h"

#include "MemMan.h"

#ifdef MemCheck_MEMCHECK
#include "MemCheck:MemCheck.h"
#endif

#define HNDL_GRW_BY  128
#define INITIAL_SIZE 4096
#define MAXIMUM_SIZE (16*1024*1024)
#define BLOCK_GAP    512
#define SHRINK_GAP   BLOCK_GAP + BLOCK_GAP / 2


static Handle *handle_list = NULL;
static int    hndl_list_sze = 0;
static int    area_no = 0;
static char   *area_end;
static int    area_free;

_kernel_oserror *grow_handles(void);

_kernel_oserror *initialise_memory(char *area_name)
{
    _kernel_oserror *err;

    if(area_no != 0)
        return make_error(TextGadgets_IntReinitMem, 0);

    /* Create the dynamic area */

    if((err = _swix(OS_DynamicArea,_INR(0,8)|_OUT(1)|_OUT(3),
    	    			   0, -1, INITIAL_SIZE, -1, 1 << 7,
    	    			   MAXIMUM_SIZE, 0, 0, area_name,
    	    			   &area_no, &area_end)) != NULL)
        return err;

    /* Get the real size of the area - this will be rounded up to a
       multiple of the page size */

    if((err = _swix(OS_DynamicArea,_IN(0)|_IN(1)|_OUT(2), 2,
    	      		           area_no, &area_free)) != NULL)
        return err;

    /* Allocate the handle list */


    return grow_handles();
}


_kernel_oserror *release_memory(void)
{
    if(area_no == 0)
        return make_error(TextGadgets_IntNeverInit, 0);

    _swix(OS_DynamicArea,_IN(0)|_IN(1), 1, area_no);
    area_no = 0;
    free(handle_list);
    handle_list = NULL;

    return NULL;
}


_kernel_oserror *grow_handles(void)
{
    int i;

    Handle *new_list = realloc(handle_list, (hndl_list_sze + HNDL_GRW_BY) *
                                sizeof(Handle));
    
    if(new_list == NULL)
        return make_error(TextGadgets_IntMallocFail, 0);

    handle_list = new_list;

    for(i = hndl_list_sze; i < hndl_list_sze + HNDL_GRW_BY; i++)
        handle_list[i].base = NULL;

    hndl_list_sze += HNDL_GRW_BY;

    return NULL;
}


static void update_handles(Handle *handle, int diff)
{
    void *base = handle->base;
    int i;

    for(i = 0; i < hndl_list_sze; i++)
        if(handle_list[i].base > base)
            handle_list[i].base += diff;
}


_kernel_oserror *create_block(int block_size, HandleId *id)
{
    _kernel_oserror *err;
    int i;

    area_free -= block_size + BLOCK_GAP;
    if(area_free < 0)
    {
        /* Need to expand the area */

        int change;
        if((err = _swix(OS_ChangeDynamicArea,_IN(0)|_IN(1)|_OUT(1),
  	       	        area_no, -area_free, &change)) != NULL)
  	{
  	    area_free += block_size + BLOCK_GAP;
            return err;
        }
        area_free += change;
    }

    /* Find free handle */

    for(i = 0; i < hndl_list_sze && handle_list[i].base != NULL; i++);

    if(i == hndl_list_sze)                   /* No free handle */
        if((err = grow_handles()) != NULL)
            return err;

    /* Fill in handle with block details */

    handle_list[i].base = area_end;
    handle_list[i].size = block_size;
    handle_list[i].free = BLOCK_GAP;

    *id = (HandleId) i;
    area_end += block_size + BLOCK_GAP;

#ifdef MemCheck_MEMCHECK
    MemCheck_RegisterFlexBlock((void**)&handle_list[i].base, block_size);
#endif

    return NULL;
}


_kernel_oserror *delete_block(HandleId id)
{
    _kernel_oserror *err;
    char *src;
    int size, change;

    Handle *handle = get_handle(id);

    if(handle->base == NULL)
        return make_error(TextGadgets_IntNoSuchBlock, 0);

    /* Move the blocks above the block down */

    size = handle->size + handle->free;
    src = handle->base + size;

    memmove(handle->base, src, area_end - src);
    area_end -= size;
    area_free += size;

    update_handles(handle, -size);
    handle->base = NULL;

    /* Attempt to shrink the area */

    if((err = _swix(OS_ChangeDynamicArea,_IN(0)|_IN(1)|_OUT(1), area_no,
                    -area_free, &change)) != NULL)
        return err;

    area_free -= change;

#ifdef MemCheck_MEMCHECK
    MemCheck_UnRegisterFlexBlock((void**)&(handle->base));
#endif

    return NULL;
}

#ifdef MemCheck_MEMCHECK
static _kernel_oserror *extend_block2(HandleId id, int pos, int size)
#else
_kernel_oserror *extend_block(HandleId id, int pos, int size)
#endif
{
    _kernel_oserror *err;

    Handle *handle = get_handle(id);

    if(handle->base == NULL)
        return make_error(TextGadgets_IntNoSuchBlock, 0);

    handle->free -= size;
    if(handle->free < 0)
    {
        /* Need to expand the block */
        char *end, *src;
        int diff = BLOCK_GAP - handle->free;
        area_free -= diff;
        if(area_free < 0)
        {
            /* Need to expand area - not big enough to hold block */
            int change;
            if((err = _swix(OS_ChangeDynamicArea,_IN(0)|_IN(1)|_OUT(1),
                            area_no, -area_free, &change)) != NULL)
            {
                area_free += diff;
                handle->free += size;
                return err;
            }
            area_free += change;
        }
        /* Move the upper blocks up */
        end = handle->base + handle->size + size;
        src = end + handle->free;
        memmove(end + BLOCK_GAP, src, area_end - src);

        area_end += diff;
        handle->free = BLOCK_GAP;

        update_handles(handle, diff);
    }

    if(pos < handle->size)
    {
        /* Not extending at the end - move upper part of block up */
        char *src = handle->base + pos;
        memmove(src + size, src, handle->size - pos);
    }

    handle->size += size;
    return NULL;
}

#ifdef MemCheck_MEMCHECK
_kernel_oserror *extend_block(HandleId id, int pos, int size)
{
    MemCheck_checking oldchecking = MemCheck_SetChecking(0, 0);
    _kernel_oserror *e = extend_block2(id, pos, size);
    if (!e)
    {
        Handle *handle = get_handle(id);
        MemCheck_ResizeFlexBlock((void**)&(handle->base), handle->size);
    }
    MemCheck_RestoreChecking(oldchecking);
    return e;
}
#endif

#ifdef MemCheck_MEMCHECK
static _kernel_oserror *shrink_block2(HandleId id, int pos, int size)
#else
_kernel_oserror *shrink_block(HandleId id, int pos, int size)
#endif
{
    _kernel_oserror *err;
    int diff;
    Handle *handle = get_handle(id);

    if(handle->base == NULL)
        return make_error(TextGadgets_IntNoSuchBlock, 0);

    if((diff = handle->size - pos - size) > 0)
    {
        /* Shrinking in the middle - need to move upper part of block down */
        char *dest = handle->base + pos;
        memmove(dest, dest + size, diff);
    }
    else
        size += diff;

    handle->size -= size;
    handle->free += size;

    if(handle->free > SHRINK_GAP)
    {
        /* Space at the end of the block is getting large - compact */

        char *end = handle->base + handle->size;
        char *src = end + handle->free;
        int diff = handle->free - BLOCK_GAP;
        int change;

        memmove(end + BLOCK_GAP, src, area_end - src);
        area_free += diff;
        area_end -= diff;

        handle->free = BLOCK_GAP;
        update_handles(handle, -diff);

        /* Attempt to shrink the area */

        if((err = _swix(OS_ChangeDynamicArea,_IN(0)|_IN(1)|_OUT(1),
                        area_no, -area_free, &change)) != NULL)
            return err;

        area_free -= change;
    }
    return NULL;
}

#ifdef MemCheck_MEMCHECK
_kernel_oserror *shrink_block(HandleId id, int pos, int size)
{
    MemCheck_checking oldchecking = MemCheck_SetChecking(0, 0);
    _kernel_oserror *e = shrink_block2(id, pos, size);
    if (!e)
    {
        Handle *handle = get_handle(id);
        MemCheck_ResizeFlexBlock((void**)&(handle->base), handle->size);
    }
    MemCheck_RestoreChecking(oldchecking);
    return e;
}
#endif

#if 0
void print_info(FILE *out)
{
    int i;

    fprintf(out, "\nHEAP INFORMATION\n----------------\n\n");
    fprintf(out, "Area no: %d\nArea free: %d\n\n", area_no, area_free);

    for(i = 0; i < hndl_list_sze; i++)
        if(handle_list[i].base != NULL)
        {
            fprintf(out, "Handle no: %d\n", i);
            fprintf(out, "\tbase address: %d\n", (int) handle_list[i].base);
            fprintf(out, "\tsize        : %d\n", handle_list[i].size);
            fprintf(out, "\tfree        : %d\n", handle_list[i].free);
        }
}
#endif

Handle *get_handle(HandleId id)
{
    return &handle_list[id];
}
