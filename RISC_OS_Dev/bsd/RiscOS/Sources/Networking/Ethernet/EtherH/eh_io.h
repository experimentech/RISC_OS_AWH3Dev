/*
 * Copyright (c) 2002, Design IT
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
#ifndef eh_io_h
#define eh_io_h

/*
 * Assembler routines, in Eh_io5_16.s & Eh_io6_16.s
 */
void eh_io_hout_6(u_char *, u_char*, int, u_int *);
void eh_io_out_6(u_char *, u_int *, int, u_int *);
void eh_flush_output_6(u_int *, u_int *);
void eh_io_hout_5(u_char *, u_char*, int, u_int *);
void eh_io_out_5(u_char *, u_int *, int, u_int *);
void eh_flush_output_5(u_int *, u_int *);
#ifdef DRIVER16BIT
void eh_io_out(u_char *, volatile u_int *, int);
void eh_io_in(volatile u_int *, u_char *, int);
#endif

/*
 * Assembler routines, in Eh_io.s
 */
#ifdef DRIVER8BIT
void eh_io_out(u_char *, volatile u_char *, int);
void eh_io_in(volatile u_char *, u_char *, int);
#endif

#endif /* eh_io_h */

/* EOF eh_io.h */
