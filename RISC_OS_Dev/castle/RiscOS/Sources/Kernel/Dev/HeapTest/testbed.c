/* This source code in this file is licensed to You by Castle Technology
   Limited ("Castle") and its licensors on contractual terms and conditions
   ("Licence") which entitle you freely to modify and/or to distribute this
   source code subject to Your compliance with the terms of the Licence.
   
   This source code has been made available to You without any warranties
   whatsoever. Consequently, Your use, modification and distribution of this
   source code is entirely at Your own risk and neither Castle, its licensors
   nor any other person who has contributed to this source code shall be
   liable to You for any loss or damage which You may suffer as a result of
   Your use, modification or distribution of this source code.
   
   Full details of Your rights and obligations are set out in the Licence.
   You should have received a copy of the Licence with this source code file.
   If You have not received a copy, the text of the Licence is available
   online at www.castle-technology.co.uk/riscosbaselicence.htm
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#include "kernel.h"
#include "swis.h"

#include "Global/Heap.h"
#include "Global/NewErrors.h"

/* Whether to use the XOS_Heap SWI or the local copy of the heap code */
#define USE_LOCAL_OSHEAP

/* Maximum number of allocations to make */
#define MAX_ALLOCS 1024

#define VBIT (1<<28)

#ifdef USE_LOCAL_OSHEAP
extern _kernel_oserror *CallHeap(_kernel_swi_regs *r);
#else
#define CallHeap(R) _kernel_swi(OS_Heap,R,R)
#endif

/* Workspace */
static uint32_t *heap=NULL; /* Main heap */
static uint32_t *backup=NULL; /* Backup copy of heap */
static uint32_t allocsize=0; /* Heap memory block size */
static uint32_t *usedspace=NULL; /* Bitmap of used space; 1 bit per word */
static uint32_t seed=0; /* RNG seed */
static uint32_t sequence=0; /* Number of ops performed */
static uint32_t numblocks=0; /* Number of blocks currently allocated */
static uint32_t blocks[MAX_ALLOCS]; /* Offsets of blocks within heap */
static uint32_t currentop = 0; /* Current heap operation */
static uint32_t opsleft = 0; /* Number of ops left */
static _kernel_swi_regs r;
static _kernel_swi_regs last;

/* Utility functions */

static void init(void)
{
	srand(seed);
	printf("Seed %08x alloc size %08x\n",seed,allocsize);
	/* Make heap 4K aligned */
	heap = (uint32_t *) (((uint32_t) malloc(allocsize+4096)+4095)&0xfffff000);
	/* Same for backup */
	backup = (uint32_t *) (((uint32_t) malloc(allocsize+4096)+4095)&0xfffff000);
	/* Used space map */
	usedspace = (uint32_t *) malloc(((allocsize+31*4)>>7)<<2);
	memset(usedspace,0,((allocsize+31*4)>>7)<<2);
	memset(heap,0,allocsize);
	memset(backup,0,allocsize);
}

static uint32_t getrand(uint32_t max)
{
	uint64_t temp = ((uint64_t) max)*rand();
	return (uint32_t) (temp/RAND_MAX);
}

static void dumpheap(uint32_t *h)
{
	fprintf(stderr,"heap @ %p:\nmag %x\nfree %x\nbase %x\nend %x\n",h,h[0],h[1],h[2],h[3]);
	uint32_t free = h[1];
	uint32_t next = 16;
	if(free)
		free += 4;
	while(free)
	{
		if(free > next)
		{
			fprintf(stderr,"allocs between %x and %x:\n",next,free);
			do {
				fprintf(stderr,"%x: alloc size %x\n",next,h[next>>2]);
				if((h[next>>2] > h[2]) || (h[next>>2]+next > h[2]) || (h[next>>2]&3) || !h[next>>2])
				{
					fprintf(stderr,"bad block, skipping rest\n");
					break;
				}
				next += h[next>>2];
			} while(free>next);
			if(free!=next)
				fprintf(stderr,"alloc mismatch! next=%x\n",next);
		}
		fprintf(stderr,"%x: free size %x next %x\n",free,h[(free+4)>>2],h[free>>2]);
		if(h[(free+4)>>2] == h[free>>2])
			fprintf(stderr,"consecutive free blocks!\n");
		next = free+h[(free+4)>>2];
		if((h[free>>2] & 3) || (h[free>>2] >= h[2]) || (h[free>>2]+free >= h[2]))
		{
			fprintf(stderr,"bad next ptr\n");
			return;
		}
		if((h[(free+4)>>2] & 3) || (h[(free+4)>>2] >= h[2]) || (h[(free+4)>>2]+free >= h[2]))
		{
			fprintf(stderr,"bad size\n");
			return;
		}
		if(!h[free>>2])
		{
			fprintf(stderr,"end of free list\n");
			break;
		}
		free = free+h[free>>2];
		if(free<next)
		{
			fprintf(stderr,"next free is inside current?\n");
			return;
		}
	}
	if(free > h[2])
	{
		fprintf(stderr,"free list extends beyond heap end\n");
	}
	if(next > h[2])
	{
		fprintf(stderr,"next ptr beyond heap end\n");
	}
	fprintf(stderr,"end allocs:\n");
	while(next < h[2])
	{
		fprintf(stderr,"%x: alloc size %x\n",next,h[next>>2]);
		if((h[next>>2] > h[2]) || (h[next>>2]+next > h[2]) || (h[next>>2]&3) || !h[next>>2])
		{
			fprintf(stderr,"bad block, skipping rest\n");
			return;
		}
		next += h[next>>2];
	}
	fprintf(stderr,"end\n");
}

static bool heapvalid(uint32_t *h)
{
	uint32_t free = h[1];
	uint32_t next = 16;
	if(free)
		free += 4;
	while(free)
	{
		if(free > next)
		{
			do {
				if((h[next>>2] > h[2]) || (h[next>>2]+next > h[2]) || (h[next>>2]&3) || !h[next>>2])
				{
					return false;
				}
				next += h[next>>2];
			} while(free>next);
			if(free!=next)
				return false;
		}
		if(h[(free+4)>>2] == h[free>>2])
			return false;
		next = free+h[(free+4)>>2];
		if((h[free>>2] & 3) || (h[free>>2] >= h[2]) || (h[free>>2]+free >= h[2]))
		{
			return false;
		}
		if((h[(free+4)>>2] & 3) || (h[(free+4)>>2] >= h[2]) || (h[(free+4)>>2]+free >= h[2]))
		{
			return false;
		}
		if(!h[free>>2])
		{
			break;
		}
		free = free+h[free>>2];
		if(free<next)
		{
			return false;
		}
	}
	if(free > h[2])
	{
		return false;
	}
	if(next > h[2])
	{
		return false;
	}
	while(next < h[2])
	{
		if((h[next>>2] > h[2]) || (h[next>>2]+next > h[2]) || (h[next>>2]&3) || !h[next>>2])
		{
			return false;
		}
		next += h[next>>2];
	}
	return true;
}

static void fail(void)
{
	fprintf(stderr,"Failed on sequence %d\n",sequence);
	fprintf(stderr,"Last op registers:\n");
	for(int i=0;i<5;i++)
		fprintf(stderr,"r%d = %08x\n",i,last.r[i]);
	fprintf(stderr,"Result registers:\n");
	for(int i=0;i<5;i++)
		fprintf(stderr,"r%d = %08x\n",i,r.r[i]);
	fprintf(stderr,"Heap before op:\n");
	dumpheap(backup);
	fprintf(stderr,"Heap after op:\n");
	dumpheap(heap);
	fprintf(stderr,"Allocated blocks:\n");
	for(uint32_t i=0;i<numblocks;i++)
	{
		fprintf(stderr,"%08x\n",blocks[i]);
	}
	exit(1);
}

static uint32_t blocksize(uint32_t offset)
{
	return heap[(offset-4)>>2];
}

static void tryuse(uint32_t offset)
{
	uint32_t len = blocksize(offset);
	if((len-4 > allocsize-offset) || (len & 3) || (len<4))
	{
		fprintf(stderr,"tryuse: Bad block at %08x\n",offset);
		fail();
	}
	offset >>= 2;
	while(len)
	{
		if(usedspace[offset>>5] & (1<<(offset&31)))
		{
			fprintf(stderr,"tryuse: Overlapping block at %08x\n",offset<<2);
			fail();
		}
		usedspace[offset>>5] |= 1<<(offset&31);
		offset++;
		len -= 4;
	}
}

static void tryfree(uint32_t offset)
{
	uint32_t len = blocksize(offset);
	if((len-4 > allocsize-offset) || (len & 3) || (len<4))
	{
		fprintf(stderr,"tryfree: Bad block at %08x\n",offset);
		fail();
	}
	offset >>= 2;
	while(len)
	{
		if(!(usedspace[offset>>5] & (1<<(offset&31))))
		{
			fprintf(stderr,"tryfree: Block at %08x already freed\n",offset<<2);
			fail();
		}
		usedspace[offset>>5] -= 1<<(offset&31);
		offset++;
		len -= 4;
	}
}

/* Main function */

int main(int argc,char **argv)
{
	_kernel_oserror *err;

	/* TODO - Take parameters from command line */
	_swix(OS_ReadMonotonicTime,_OUT(0),&seed);
	allocsize = 8*1024;

	init();

	/* Initialise heap */
	r.r[0] = HeapReason_Init;
	r.r[1] = (int) heap;
	r.r[3] = allocsize;
	err = CallHeap(&r);
	if(err)
	{
		fprintf(stderr,"Heap initialise failed! %s\n",err->errmess);
		exit(1);
	}
	usedspace[0] = 0xf;

	/* Begin tests */
	uint32_t temp,temp2,temp3,temp4;
	while(heapvalid(heap))
	{
		if(!opsleft)
		{
			opsleft = getrand(128);
			switch(getrand(4))
			{
			case 0:
				currentop = HeapReason_Get;
				break;
			case 1:
				currentop = HeapReason_Free;
				break;
			case 2:
				currentop = HeapReason_ExtendBlock;
				break;
			default:
				currentop = HeapReason_GetAligned;
				break;
			}
		}
		if(!(sequence&0xffff))
		{
//			printf(".");
			dumpheap(heap);
		}
		sequence++;
		r.r[0] = currentop;
		memcpy(backup,heap,allocsize);
		switch(currentop)
		{
		case HeapReason_Get:
			if(numblocks == MAX_ALLOCS)
			{
				opsleft = 0;
				break;
			}
			r.r[3] = temp = getrand(allocsize>>5)+1;
			last = r;
			err = CallHeap(&r);
			if(err)
			{
				if(err->errnum != ErrorNumber_HeapFail_Alloc)
				{
					fprintf(stderr,"Failed allocating %08x bytes: %s\n",temp,err->errmess);
					fail();
				}
			}
			else
			{
				temp2 = blocks[numblocks++] = r.r[2]-((uint32_t)heap);
				if(blocksize(temp2) < temp+4)
				{
					fprintf(stderr,"Failed to allocate requested block size: %08x bytes at %08x\n",temp,temp2);
					fail();
				}
				tryuse(temp2);
			}
			break;
		case HeapReason_Free:
			if(!numblocks)
			{
				opsleft = 0;
				break;
			}
			temp = getrand(numblocks);
			r.r[2] = blocks[temp]+((uint32_t) heap);
			tryfree(blocks[temp]); /* Must free beforehand */
			last = r;
			err = CallHeap(&r);
			if(err)
			{
				fprintf(stderr,"Failed freeing block at %08x: %s\n",blocks[temp],err->errmess);
				fail();
			}
			blocks[temp] = blocks[--numblocks];
			break;
		case HeapReason_ExtendBlock:
			if(!numblocks)
			{
				opsleft = 0;
				break;
			}
			temp = getrand(numblocks);
			r.r[2] = blocks[temp]+((uint32_t) heap);
			temp2 = getrand(allocsize>>4)-(allocsize>>5);
			r.r[3] = temp2;
			temp3 = blocksize(blocks[temp]);
			tryfree(blocks[temp]); /* Must free beforehand */
			last = r;
			err = CallHeap(&r);
			if(err)
			{
				if(err->errnum != ErrorNumber_HeapFail_Alloc)
				{
					fprintf(stderr,"Failed resizing block at %08x by %08x bytes: %s\n",blocks[temp],(int) temp2,err->errmess);
					fail();
				}
				if(blocksize(blocks[temp]) != temp3)
				{
					fprintf(stderr,"Resize failed but block size changed\n");
					fail();
				}
				tryuse(blocks[temp]);
			}
			else
			{
				if(r.r[2] && (r.r[2] != 0xffffffff))
				{
					if((int) (temp3+temp2) <= 4)
					{
						fprintf(stderr,"Resized block was kept when it should have been freed: block %08x by %08x\n",blocks[temp],(int) temp2);
						fail();
					}
					blocks[temp] = r.r[2]-((uint32_t)heap);
					tryuse(blocks[temp]);
					if((blocksize(blocks[temp])-(temp3+temp2)) > 7)
					{
						fprintf(stderr,"Failed to resize block by required amount: block %08x by %08x\n",blocks[temp],(int) temp2);
						fail();
					}
				}
				else
				{
					if((int) (temp3+temp2) > 4)
					{
						fprintf(stderr,"Resized block was freed when it should have remained: block %08x by %08x\n",blocks[temp],(int) temp2);
						fail();
					}
					blocks[temp] = blocks[--numblocks];
				}
			}
			break;
		case HeapReason_GetAligned:
			if(numblocks == MAX_ALLOCS)
			{
				opsleft = 0;
				break;
			}
			r.r[3] = temp = getrand(allocsize>>4)+1;
			temp2 = 4<<getrand(9); /* Max 2K alignment (heap 4K aligned) */
			temp3 = temp2*(1<<getrand(5));
			if(temp3 > 4096) /* Max 2K boundary (heap 4K aligned) */
				temp3 = 2048;
			if(temp3 < temp)
				temp3 = 0;
			r.r[2] = temp2;
			r.r[4] = temp3;
			last = r;
			err = CallHeap(&r);
			if(err)
			{
				if(err->errnum != ErrorNumber_HeapFail_Alloc)
				{
					fprintf(stderr,"Failed allocating %08x bytes at alignment %08x boundary %08x: %s\n",temp,temp2,temp3,err->errmess);
					fail();
				}
			}
			else
			{
				temp4 = blocks[numblocks++] = r.r[2]-((uint32_t) heap);
				if(blocksize(temp4) < temp+4)
				{
					fprintf(stderr,"Failed to allocate requested block size: %08x bytes at alignment %08x boundary %08x at %08x\n",temp,temp2,temp3,temp4);
					fail();
				}
				if(temp4 & (temp2-1))
				{
					fprintf(stderr,"Block allocated at wrong alignment: %08x bytes at alignment %08x boundary %08x at %08x\n",temp,temp2,temp3,temp4);
					fail();
				}
				if(temp3 && ((temp4 & ~(temp3-1)) != ((temp4+temp-1) & ~(temp3-1))))
				{
					fprintf(stderr,"Block crosses boundary: %08x bytes at alignment %08x boundary %08x at %08x\n",temp,temp2,temp3,temp4);
					fail();
				}
				tryuse(temp4);
			}
			break;
		}
		if(opsleft)
			opsleft--;
	}
	fprintf(stderr,"Heap corruption detected!\n");
	fail();
	return 0;
}
