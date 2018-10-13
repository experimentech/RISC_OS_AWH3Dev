/*
 * Copyright (c) 2012, Ben Avison
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the copyright holder nor the names of their
 *       contributors may be used to endorse or promote products derived from
 *       this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef ATOMIC_H
#define ATOMIC_H

#include <stdint.h>

/** \file atomic.h
 *  An implementation of atomic memory accesses that uses ARM's favoured
 *  instructions, dependent upon the current CPU.
 */

/** Atomic read/write of a 32-bit value.
 *  Can be entered in any processor mode.
 *  \arg new_value Value to write.
 *  \arg address   Memory location at which to perform the read/write.
 *  \return        Value that was read.
 */
uint32_t atomic_update(uint32_t new_value, volatile uint32_t *address);

/** Atomic read/write of an 8-bit value.
 *  Can be entered in any processor mode.
 *  \arg new_value Value to write.
 *  \arg address   Memory location at which to perform the read/write.
 *  \return        Value that was read.
 */
uint8_t atomic_update_byte(uint8_t new_value, volatile uint8_t *address);

/** User-defined atomic operation on a 32-bit value.
 *  Can be entered in any processor mode unless you need to support
 *  architecture 5 or earlier, in which case must be entered in privileged mode.
 *  \arg callback Routine to change the value (may be called more than once).
 *  \arg argument Value to pass to callback as its second argument.
 *  \arg address  Memory location at which to operate.
 *  \return       Value that was at location before operation.
 */
uint32_t atomic_process(uint32_t (*callback)(uint32_t, uint32_t), uint32_t argument, volatile uint32_t *address);

#endif
