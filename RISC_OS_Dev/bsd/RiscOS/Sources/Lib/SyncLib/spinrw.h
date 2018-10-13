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

#ifndef SPINRW_H
#define SPINRW_H

#include <stdbool.h>
#include <stdint.h>

/** \file spinrw.h
 *  An implementation of an SVC-mode read-write spin lock.
 *
 *  The lock can be held only once for writing, but multiple times for reading.
 *  It can only be held for reading or writing, not both at the same time.
 *
 *  While the lock is held for writing, interrupts are disabled on the CPU
 *  holding the lock, so it is always possible to claim a read lock from
 *  interrupt context.
 *
 *  Interrupts are *not* disabled while one or more read locks are held. This
 *  allows read locks to be held for extended periods, but means that claiming a
 *  write lock from interrupt context can fail. For this reason, you may wish to
 *  design your software such that write locks are only ever claimed from the
 *  foreground.
 */

/** The data block used to hold the state of a spinlock. */
typedef struct
{
  uint32_t opaque[4];
} spinrwlock_t;

/** Use this to initialise any new read-write spin locks you create. */
#define SPINRW_INITIALISER { 1, 0, 0, 1 }

/** Attempt to claim a write lock. Will fail if the lock is already held for
 *  either reading or writing. If it succeeds, IRQs are disabled.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 *  \return    Whether the lock succeeded.
 */
bool spinrw_try_write_lock(spinrwlock_t *lock);

/** Wait (forever if necessary) until the lock is not held for reading or
 *  writing, then claim a write lock and disable IRQs.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 */
void spinrw_write_lock(spinrwlock_t *lock);

/** Wait (forever if necessary) until the lock is not held for reading or
 *  writing, sleeping the current task if necessary, then claim a write lock and
 *  disable IRQs.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 */
void spinrw_sleep_write_lock(spinrwlock_t *lock);

/** Release a write lock and restore the IRQ disable state to how it was when
 *  the write lock was claimed.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 */
void spinrw_write_unlock(spinrwlock_t *lock);

/** Wait (forever if necessary) for any other CPU that holds the lock for
 *  writing to release it, then increment the number of times the lock is held
 *  for reading.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 */
void spinrw_read_lock(spinrwlock_t *lock);

/** Decrement the number of times the lock is held for reading.
 *  Must be entered in privileged mode.
 *  \arg lock  Pointer to spinrwlock block.
 */
void spinrw_read_unlock(spinrwlock_t *lock);

#endif
