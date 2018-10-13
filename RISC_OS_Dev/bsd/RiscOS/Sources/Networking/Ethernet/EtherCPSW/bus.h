/*
 * Copyright (c) 2014, Elesar Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Elesar Ltd nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef BUS_H
#define BUS_H

/* Logical mapped bus space */
typedef uintptr_t bus_space_tag_t;
typedef uintptr_t bus_space_handle_t;
typedef uintptr_t bus_addr_t;
typedef size_t bus_size_t;

/* Map in IO */
int bus_space_map(bus_space_tag_t, bus_addr_t, bus_size_t,
                  int, bus_space_handle_t *);
void bus_space_unmap(bus_space_tag_t, bus_space_handle_t, bus_size_t);
int bus_space_subregion(bus_space_tag_t, bus_space_handle_t,
                        bus_size_t, bus_size_t, bus_space_handle_t *);

/* Redefine the functions without a handle it so everything fits in APCS registers */
#define bus_space_read_4(a,b,c)             bus_read_4(b,c)
#define bus_space_read_region_4(a,b,c,d,e)  bus_read_region_4(b,c,d,e)
#define bus_space_write_4(a,b,c,d)          bus_write_4(b,c,d)
#define bus_space_write_region_4(a,b,c,d,e) bus_write_region_4(b,c,d,e)
#define bus_space_set_region_4(a,b,c,d,e)   bus_set_region_4(b,c,d,e)

/* IO accesses of various sizes */
uint32_t bus_read_4(bus_space_handle_t, bus_size_t);
void bus_read_region_4(bus_space_handle_t, bus_size_t, uint32_t *, size_t);
void bus_write_4(bus_space_handle_t, bus_size_t, uint32_t);
void bus_write_region_4(bus_space_handle_t, bus_size_t, const uint32_t *, size_t);
void bus_set_region_4(bus_space_handle_t, bus_size_t, uint32_t, size_t);

/* DMA handled bus space */
typedef void *bus_dma_tag_t;
typedef struct
{
	bus_addr_t ds_addr;
	bus_size_t ds_len;
	bus_addr_t ds_logical;
} bus_dma_segment_t;
typedef struct
{
	bus_size_t dm_maxsegsz;
	bus_size_t dm_mapsize;
	int        dm_nsegs;
	bus_dma_segment_t *dm_segs;
} *bus_dmamap_t;
enum
{
	BUS_DMA_READ = 1,
	BUS_DMA_WRITE = 2,
	BUS_DMASYNC_PREREAD = 4,
	BUS_DMASYNC_POSTREAD = 8,
	BUS_DMASYNC_PREWRITE = 16,
	BUS_DMASYNC_POSTWRITE = 32,
	BUS_DMA_WAITOK = 64,
	BUS_DMA_NOWAIT = 128
};
struct proc
{
	int unused;
};
int bus_dmamap_create(bus_dma_tag_t, bus_size_t, int, bus_size_t,
                      bus_size_t, int, bus_dmamap_t *);
void bus_dmamap_destroy(bus_dma_tag_t tag, bus_dmamap_t dmam);
int bus_dmamap_load(bus_dma_tag_t, bus_dmamap_t, void *, bus_size_t, struct proc *, int);
void bus_dmamap_unload(bus_dma_tag_t, bus_dmamap_t);
void bus_dmamap_sync(bus_dma_tag_t, bus_dmamap_t, bus_addr_t, bus_size_t, int);
int bus_dmamap_load_mbuf(bus_dma_tag_t, bus_dmamap_t, struct mbuf *, int);

#endif
