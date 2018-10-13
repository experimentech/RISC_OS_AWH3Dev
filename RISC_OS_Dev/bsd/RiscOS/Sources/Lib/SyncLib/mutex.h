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

#ifndef MUTEX_H
#define MUTEX_H

#include <stdbool.h>
#include <stdint.h>

/** \file mutex.h
 *  An implementation of a simple mutex. Does not disable interrupts while the
 *  mutex is held, so is suitable for mutexes that are held for an extended
 *  period, but is not appropriate if you need it to always be possible to lock
 *  the mutex from the background (e.g. in an interrupt handler).
 */

/** The data block used to hold the state of a mutex. */
typedef enum
{
  MUTEX_LOCKED,
  MUTEX_UNLOCKED
} mutex_t;

/** Attempt to lock a mutex.
 *  Can be entered in any processor mode.
 *  \arg mutex  Pointer to mutex.
 *  \return     Whether the lock succeeded.
 */
bool mutex_try_lock(mutex_t *mutex);

/** Lock a mutex, waiting (forever if necessary) for it to become available.
 *  Can be entered in any processor mode.
 *  \arg mutex  Pointer to mutex.
 */
void mutex_lock(mutex_t *mutex);

/** Lock a mutex, waiting (forever if necessary) for it to become available, sleeping the current task if necessary.
 *  Can be entered in any processor mode.
 *  \arg mutex  Pointer to mutex.
 */
void mutex_sleep_lock(mutex_t *mutex);

/** Unlock a mutex.
 *  Can be entered in any processor mode.
 *  \arg mutex  Pointer to mutex.
 */
void mutex_unlock(mutex_t *mutex);

#endif
