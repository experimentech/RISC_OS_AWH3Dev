/*
 * Copyright (c) 2017, Colin Granville
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * The name Colin Granville may not be used to endorse or promote
 *       products derived from this software without specific prior written
 *       permission.
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


#include <stdlib.h>
#include <ctype.h>

#include "Global/HALEntries.h"
#include "Global/OSMisc.h"
#include "swis.h"
#include "utils.h"
#include "debug.h"

static void*            counter_delay_fn;
static unsigned int     counter_delay_pw;
static void*            DMB_write_fn;
static void*            counter_read_fn;
static unsigned int     counter_read_pw;

/* Initialise on first use. If there is no counter delay_us returns immediately */
_kernel_oserror* utils_initialise(void)
{
        _kernel_oserror* err;
        err =_swix(OS_Hardware, _INR(8,9) | _OUTR(0,1), OSHW_LookupRoutine, EntryNo_HAL_CounterDelay,
                                                           &counter_delay_fn, &counter_delay_pw);
        if (err != NULL) return err;

        err =_swix(OS_Hardware, _INR(8,9) | _OUTR(0,1), OSHW_LookupRoutine, EntryNo_HAL_CounterRead,
                                                           &counter_read_fn, &counter_read_pw);
        if (err != NULL) return err;

        err =_swix(OS_MMUControl, _IN(0) | _OUT(0), (MMUCReason_GetARMop | (ARMop_DMB_Write << 16)), &DMB_write_fn);
        return err;
}


void* utils_get_hal_pw(void)
{
        return (void*) counter_delay_pw;
}

void utils_delay_us(uint32_t micro_secs)
{
        if (counter_delay_fn != NULL)
        {
                __asm
                {
                        MOV     r0, micro_secs
                        MOV     r9, counter_delay_pw
                        BLX     counter_delay_fn, {R0, R9}, {}, {LR,PSR}
                }
        }
}


void utils_DMB_write(void)
{
        if (DMB_write_fn != NULL)
        {
                __asm
                {
                        BLX     DMB_write_fn, {}, {}, {R0, LR, PSR}
                }
        }
}

uint32_t utils_counter_us(void)
{
        if (counter_read_fn != NULL)
        {
                uint32_t count;
                __asm
                {
                        MOV     r9, counter_read_pw
                        BLX     counter_read_fn, {R9}, {R0}, {LR, PSR}
                        MOV     count, r0;
                }
                return count;
        }
        return 0;
}

uint32_t utils_clock_cs(void)
{
        uint32_t tm;
        _swix(OS_ReadMonotonicTime, _OUT(0), &tm);
        return tm;
}

size_t utils_enumerate_args(const char** argpos, const char** start)
{
        if (argpos == NULL || *argpos == NULL || start == NULL) return 0;

        const char* p;

        for (p = *argpos; *p == ' '; p++) {}

        if (*p < ' ') return 0;
        char delim = ' ';
        if (*p == '\"')
        {
                p++;
                delim = '\"';
        }

        *start = p;
        for (;*p != delim; p++)
        {
                if (*p < ' ')
                {
                        if (delim == '\"') return 0;
                        break;
                }
        }

        *argpos = p + (delim == '\"' ? 1 : 0);
        return p - *start;
}

bool utils_match_arg(const char* str, const char* arg, size_t argsize)
{
        for (size_t i = 0; i < argsize; i++, str++, arg++)
        {
                if (*str < ' ' || *arg < ' ') return false;
                if (toupper(*str) != toupper(*arg)) return false;
        }
        return true;
}

bool utils_get_arg_number(const char* arg, size_t argsize, uint32_t* number)
{
        if (arg == NULL || number == NULL) return false;
        uint32_t val = 0;
        for (size_t i = 0; i < argsize; i++)
        {
                if (!isdigit(arg[i])) return false;
                val = val * 10 + (arg[i] - '0');
        }
        *number = val;
        return true;
}
