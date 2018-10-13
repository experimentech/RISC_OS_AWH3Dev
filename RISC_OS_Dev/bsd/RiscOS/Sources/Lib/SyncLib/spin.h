/*
 * Copyright (c) 2011, Ben Avison
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

#ifndef SPIN_H
#define SPIN_H

#include <stdint.h>

/** \file spin.h
 *  An implementation of a simple SVC-mode spin lock. Only one CPU can hold it
 *  at a time, and interrupts are disabled on the CPU that holds it, to avoid
 *  any re-entrancy concerns.
 */

/** The data block used to hold the state of a spinlock. */
typedef struct
{
  uint32_t opaque[2];
} spinlock_t;

/** Use this to initialise any new spin locks you create. */
#define SPIN_INITIALISER { 1, 0 }

/** Disable IRQs and, if on a SMP system, wait (forever if necessary) for any
 *  other CPU using this lock to release it, and claim it ourselves.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinlock block.
 */
void spin_lock(spinlock_t *lock);

/** Release the lock and restore the IRQ disable state to how it was when the
 *  lock was claimed.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinlock block.
 */
void spin_unlock(spinlock_t *lock);

#endif
