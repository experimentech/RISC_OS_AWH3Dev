/*
 * Copyright (c) 2011, RISC OS Open Ltd
 * All rights reserved.
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
#include "modhead.h"
#include "swis.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include "Global/RISCOS.h"
#include "Global/Services.h"

#include "DebugLib/DebugLib.h"

#include "globals.h"

void *private_word;

cdfs_driver_info_t driver_info;

MessagesFD messages;

#ifdef STANDALONE
extern void* Resources(void);
#endif

_kernel_oserror* module_init(const char *cmd_tail, int podule_base, void *pw)
{
	(void) cmd_tail;
	(void) podule_base;
	(void) pw;
	_kernel_oserror* e = 0;
    
	/* set up debugging */
	debug_initialise(Module_Title, "", "");
	debug_set_device(DADEBUG_OUTPUT);
	debug_set_unbuffered_files(TRUE);
    
	private_word = pw;

	/* Set up messages */
#ifdef STANDALONE
	e = _swix(ResourceFS_RegisterFiles,_IN(0),Resources());
	if(e)
		goto error1;
#endif

	e = _swix(MessageTrans_OpenFile,_INR(0,2),&messages,"Resources:$.Resources.CDFSDriver.SCSI.Messages",0);
	if(e)
		goto error2;

	/* Register with CDFS */
	memset(&driver_info,0,sizeof(driver_info));
	driver_info.infoword = CDOp_MAX
			     | INFOWORD_USE_SCSI_SEEK
			     | INFOWORD_USE_SCSI_INQUIRY
			     | INFOWORD_USE_SCSI_CAPACITY
			     | INFOWORD_USE_SCSI_READY
			     | INFOWORD_USE_SCSI_STOPOPEN
			     | INFOWORD_USE_SCSI_CHECK
			     | INFOWORD_USE_SCSI_STATUS
			     | INFOWORD_USE_SCSI_CONTROL
			     | INFOWORD_USE_SCSI_OP
			     ;
	driver_info.numdrivetypes = DriveType_MAX;
	e = _swix(CD_Register,_INR(0,2),&driver_info,driver_handler,private_word);
	if(e)
		goto error3;
    
	return NULL;

error3:
	_swix(MessageTrans_CloseFile,_IN(0),&messages);
error2:
#ifdef STANDALONE
	_swix(ResourceFS_DeregisterFiles,_IN(0),Resources());
error1:
#endif
	dprintf(("","Failed initialisation: %s\n", e->errmess));
	return e;
}

_kernel_oserror *module_final(int fatal, int podule, void *pw)
{
	(void) fatal;
	(void) podule;
	(void) pw;
	_kernel_oserror *e = 0;

	/* Deregister */
	e = _swix(CD_Unregister,_INR(0,1),&driver_info,driver_handler);
	/* Ignore any errors (CDFSDriver can be killed without our knowledge, which will result in any unregister attempts failing) */
#ifdef DEBUGLIB
	if(e)
		dprintf(("","Warning - Failed to unregister with CDFSDriver. Error %x %s\n",e->errnum,e->errmess));
#endif

	/* Close messages */
	_swix(MessageTrans_CloseFile,_IN(0),&messages);

#ifdef STANDALONE
	_swix(ResourceFS_DeregisterFiles,_IN(0),Resources());
#endif

	return NULL;
}
