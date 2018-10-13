/*
 * Copyright (c) 2012, RISC OS Open Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of RISC OS Open Ltd nor the names of its contributors
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

/* Redefine the functions without a handle it so everything fits in APCS registers */ 
#define bus_space_read_1(a,b,c)            bus_read_1(a + (b * 0),c)
#define bus_space_read_2(a,b,c)            bus_read_2(a + (b * 0),c)
#define bus_space_read_multi_1(a,b,c,d,e)  bus_read_multi_1(a + (b * 0),c,d,e)
#define bus_space_read_multi_2(a,b,c,d,e)  bus_read_multi_2(a + (b * 0),c,d,e)
#define bus_space_write_1(a,b,c,d)         bus_write_1(a + (b * 0),c,d)
#define bus_space_write_2(a,b,c,d)         bus_write_2(a + (b * 0),c,d)
#define bus_space_write_multi_1(a,b,c,d,e) bus_write_multi_1(a + (b * 0),c,d,e)
#define bus_space_write_multi_2(a,b,c,d,e) bus_write_multi_2(a + (b * 0),c,d,e) 
                                                                                  
/* IO accesses of various sizes */
uint8_t bus_read_1(uintptr_t, uintptr_t);
uint16_t bus_read_2(uintptr_t, uintptr_t);
void bus_read_multi_1(uintptr_t, uintptr_t, uint8_t *, size_t);
void bus_read_multi_2(uintptr_t, uintptr_t, uint16_t *, size_t);
void bus_write_1(uintptr_t, uintptr_t, uint8_t);
void bus_write_2(uintptr_t, uintptr_t, uint16_t);
void bus_write_multi_1(uintptr_t, uintptr_t, const uint8_t *, size_t);
void bus_write_multi_2(uintptr_t, uintptr_t, const uint16_t *, size_t);

#endif
