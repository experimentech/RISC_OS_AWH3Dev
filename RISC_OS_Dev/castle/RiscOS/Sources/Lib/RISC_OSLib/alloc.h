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
  Title:        alloc - Storage management (dynamic allocation/deallocation)
  Copyright:    (C) 1987, Acorn Computers Ltd., Cambridge, England.
  Revision: 4.2  LDS, LH 03-Nov-89
*/

#ifndef __alloc__h
#define __alloc__h

#ifndef __stddef__h
#include <stddef.h>
#endif

/* #define CAMEL */
#define BLOCKS_GUARDED */
#define MULTITHREADED */
/* #define GC */
/* #define STATS */
/* #define DEBUG */
/* #define STACKCHECK */
/* #define VERBOSE */
/* #define ANALYSIS prints +No on allocate and -No on deallocate */
/* #define MEMDUMP gives a memory dump to screen and $.memdump when corrupt */
/*
 * if the OSStorage can not be depended upon to allocate areas of the
 *   heap in consistently increasing address order then the following
 *   constant must be set to FALSE.
 */
#define HEAP_ALLOCATED_IN_ASCENDING_ADDRESS_ORDER 1

typedef struct BlockStruct {
#ifdef BLOCKS_GUARDED
  unsigned int guard; /* guard word should contain GuardConstant if all ok */
#endif
  size_t size; /* block size (not including header) in address units. */
               /* The bottom 2 bits of size hold the flags declared below */
  struct BlockStruct *next; /* next and previous are used internaly in */
  struct BlockStruct *previous; /* coalescing and managing free blocks. */
                                /* next is the first word of the user block */
} Block, *BlockP;

#define OK       0
#define FAILED  -1
#define CORRUPT -2
#define MINHEAPERROR -2 /* ensure you update this if you add any new errors */

#define SIZEMASK      0xfffffffc /* all except bottom two bits, when applied */
                                 /* to block.size yields no of address units */
                                 /* of user space in this block. */
#define FREEBIT       (1U<<0) /* if set, indicates that the block is free */
#define HEAPHOLEBIT   (1U<<1) /* block used for marking start of heap hole */
#define GUARDCONSTANT 0x3E694C3C /* not a legal word pointer */
#define BYTESPERWORD  sizeof(int)
/* Block.next offset from Block (in words) */
#define FIRSTUSERWORD ((sizeof(Block)-sizeof(BlockP)*2) / BYTESPERWORD)

extern void _init_alloc(void);
/*
 * Initialise allocate (not to be called by anyone outside the M2Core!)
 */

typedef void FreeProc (BlockP block);
/* block = pointer to start of header of block to be freed */


extern size_t _byte_size(void *p);
/*
 * Return an approximation to the allocated size of the object pointed
 * to by p. The only guarantee is that:-
 *   requested_size(p) <= _byte_size(p) <= allocated_size(p).
 */

extern void *_sys_alloc(size_t n);
/*
 * A paranoid variant of malloc used by the C compiler.
 */

extern int __coalesce(void);
/*
 * Perform a colesce step on the heap. Returns OK or Corrupt.
 */

/* ---------------------------- Debug aids --------------------------------- */

#ifdef BLOCKS_GUARDED
extern void __heap_checking_on_all_deallocates(int on);
/*
 * If on = TRUE, the structure of the heap is checked on every deallocate
 */

extern void __heap_checking_on_all_allocates(int on);
/*
 * If on = TRUE, the structure of the heap is checked on every allocate
 */
#endif

/* ------------------------- Statistics reporting --------------------------*/
typedef enum {
  COALESCE,
  EXTENSION,
  COALESCE_AND_EXTENSION
} Event;

typedef struct StorageInfoStruct {
  BlockP heapLow; /* heap base */
  BlockP heapHigh; /* heap top */
  unsigned int userHeap; /* user part of heap = heapHigh-heapLow-gcbitmaps */
  unsigned int maxHeapRequirement; /* max storage actually requested by user */
  unsigned int currentHeapRequirement;  /* current user requested storage */
  unsigned int coalesces; /* number of coalesces performed, includes number
                             of garbage collections cos a coalesce is done
                             after every garbage collection. */
  unsigned int heapExtensions;    /* number of times that heap is extended */
  unsigned int blocksAllocated;   /* total number of allocates requested */
  unsigned int blocksDeallocated; /* total number of deallocates requested */
  unsigned int bytesAllocated;    /* total number of bytes allocated */
  unsigned int bytesDeallocated;  /* total number of bytes deallocated */
} StorageInfo, *StorageInfoP;

typedef struct EventInfoStruct {
  Event event;
  size_t blockThatCausedEvent; /* size of allocate that caused event */
  unsigned int totalFree;  /* amount of heap that user can actually write to,
                              does not include bitmaps and block overheads */
  unsigned int userHeap;   /* user part of heap = heapHigh-heapLow-gcbitmaps */
  /* the following are changes from previous event */
  unsigned int allocates;        /* number of allocates requested */
  unsigned int bytesAllocated;   /* number of bytes allocated */
  unsigned int deallocates;      /* number of deallocates requested */
  unsigned int bytesDeallocated; /* number of bytes deallocated */
} EventInfo, *EventInfoP;

#ifdef STATS
extern void _GetStorageInfo(StorageInfoP info);
/*
 * Get statistics on the current state of the storage manager
 */

extern int _GetLastEvent(void);
/*
 * returns the number of the last event to happen in the storage manager.
 */

extern int _GetEventData(int event, EventInfoP info);
/*
 * get the record which describes the state of the storage manager for the
 * given event. Returns FALSE if no more records available. All records can
 * be read from GetLastEvent() downwards until FALSE is returned.
 */

extern void _NextHeapElement(
  BlockP *nextBase,         /* updated to point to start of next block */
  unsigned int *guard,      /* value of guard word */
  size_t *size,             /* size of user block in bytes */
  int *free,                /* if true, block is free */
  int *heapHole,            /* if true, block is a heap hole */
  int *bitmap,              /* if true, block is a gc bitmap */
  unsigned int *firstWord); /* first word of the user block */
/*
 * Get data describing the heap block pointed at by nextBase (first block is
 * accessed by nextBase = NIL) nextBase is set to NIL when the last block has
 * been read (not on the attempt to read the last block)
 */
#endif /* stats */


#define BITSIZE(bytes) ((bytes)<<3)
#define BITSPERWORD  BITSIZE(sizeof(int))
#define BITSPERBYTE  (BITSPERWORD/BYTESPERWORD)
/*
 * The following constants are all in address units
 */
/* MAXBYTES should be something outrageously big */
#define MAXBYTES     0x40000000
#define OVERHEAD     (FIRSTUSERWORD * BYTESPERWORD)
#define HOLEOVERHEAD OVERHEAD
#define MINBLOCKSIZE (OVERHEAD + BYTESPERWORD)

/* the following constants are tunable */
/* multiple of required block size needing to be free before coalesce done */
#define BINRANGE     (BYTESPERWORD * 1) /* see assumptions */
#define NBINS        16
#define MAXBINSIZE   (BINRANGE*(NBINS)-1)
#define LARGEBLOCK   512

/*
 * Code macros.
 */
#define SIZE(block) ((size_t)((block)->size & SIZEMASK))
#define BITSTOWORDS(bits) ((bits+(BITSPERWORD-1))/BITSPERWORD)
#define BYTESTOWORDS(bytes) ((bytes+(BYTESPERWORD-1))/BYTESPERWORD)
#define ADDBYTES(bp, bytes) (BlockP)((char *)bp + (bytes))
#define ADDBYTESTO(bp, bytes) bp = (BlockP)((char *)bp + (bytes))
#define PTRDIFF(hi, lo) ((char *)hi - (char *)lo)
#define FREE(block) (FREEBIT & ((BlockP)block)->size)
#define HEAPHOLE(block) (HEAPHOLEBIT & block->size)

#ifdef BLOCKS_GUARDED
#define INVALID(block) (((BlockP)block)->guard != GUARDCONSTANT)
#else
#define INVALID(block) (0)
#endif
#define BADUSERBLOCK(block) (INVALID(ADDBYTES(block,-OVERHEAD)) \
                            || FREE(ADDBYTES(block,-OVERHEAD)))

#endif
