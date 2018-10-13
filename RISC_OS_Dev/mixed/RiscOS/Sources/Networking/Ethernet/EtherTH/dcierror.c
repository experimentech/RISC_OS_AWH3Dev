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


#include "dcierror.h"
#include <stdio.h>
#include "ModuleHdr.h"
#include "dci.h"
#include "debug.h"

static int message_block[4];
static int messages_loaded;


_kernel_oserror* dcierror(int errnum)
{
        struct
        {
                int     errnum;
                char    errmess[32];
        } err;

        if (!(errnum <= ELAST ||
              errnum >= INETERR_IFBAD && errnum <= INETERR_FILTERGONE)) errnum = EINVAL;

        err.errnum = errnum + (errnum <= ELAST ? DCI4ERRORBLOCK : 0);

        sprintf(err.errmess, "E%d:dci error %d", err.errnum - DCI4ERRORBLOCK,  err.errnum - DCI4ERRORBLOCK);
        return _swix(MessageTrans_ErrorLookup, _INR(0,2), &err, message_block, 0);
}

_kernel_oserror* dcierror_init(void)
{
        if (messages_loaded != 0) return NULL;

        _kernel_oserror* e;

        e = _swix(MessageTrans_OpenFile, _INR(0,2), message_block, Module_MessagesFile, 0);

        if (e == NULL) messages_loaded = 1;

        return e;
}

void dcierror_final(void)
{
    if (messages_loaded == 0) return;

    _swix(MessageTrans_CloseFile, _IN(0), message_block);

    messages_loaded = 0;
}




