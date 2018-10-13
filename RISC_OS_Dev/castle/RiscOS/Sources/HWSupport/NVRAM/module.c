/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/* > module.c
 *
 *      RISC OS module related code.
 */

/* From CLib */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kernel.h"
#include "swis.h"

#include "module.h"
#include "nvram.h"
#include "msgfile.h"
#include "error.h"
#include "header.h"

#include "trace.h"


static _kernel_oserror *TinyError;
msgtransblock msgs;
msgtransblock tags;


/*------------------------------------------------------------------------------
 * module_finalise
 *
 *      Module exit handler.
 */
_kernel_oserror *
module_finalise( int fatal, int podule, void *pw )
{
	nvram_finalise();

	if ( TinyError == NULL ) _swix( TinySupport_Die, 0 );

	return NULL;

	NOT_USED( fatal );
	NOT_USED( podule );
	NOT_USED( pw );
}


/*------------------------------------------------------------------------------
 * module_initialise
 *
 *      Module initialisation entry point.
 */
_kernel_oserror *
module_initialise( const char *cmd_tail, int podule_base, void *pw )
{
	_kernel_oserror* err = NULL;

        msgs.filename = MSGFILE_NAME;
        msgs.open = 0;
        tags.filename = TAGFILE_NAME;
        tags.open = 0;

#ifdef DEBUGLIB
	trace_initialise();
#endif

	err = nvram_initialise();

	/* Try to use TinyStubs if possible.
	 */
	if ( err == NULL ) TinyError = _swix( TinySupport_Share, _IN(0), pw );

	if ( err != NULL ) nvram_finalise();

	return msgfile_error_lookup( &msgs, err, NULL );

	NOT_USED( cmd_tail );
	NOT_USED( podule_base );
	NOT_USED( pw );
}


/*------------------------------------------------------------------------------
 * module_swi
 *
 *      Module SWI handler.
 */
_kernel_oserror *
module_swi( int swi_no, _kernel_swi_regs *r, void *pw )
{
	_kernel_oserror *err;

	switch ( swi_no )
	{
                case NVRAM_Read - NVRAM_00:
                        err = nvram_read( (char *)r->r[0], (void *)r->r[1], r->r[2],
                                                &r->r[0] );
                        break;

                case NVRAM_Write - NVRAM_00:
                        err = nvram_write( (char *)r->r[0], (void *)r->r[1], r->r[2],
                                                &r->r[0] );
                        break;

                case NVRAM_Lookup - NVRAM_00:
                        err = nvram_lookup( (char *)r->r[0],
                                                (unsigned int *)&r->r[0], (unsigned int *)&r->r[1], (unsigned int *)&r->r[2], (unsigned int *)&r->r[3] );
                        break;

                case NVRAM_Get - NVRAM_00:
                        err = nvram_get( (char *)r->r[0], (void *)r->r[1], r->r[2],
                                                &r->r[0] );
                        break;

                case NVRAM_Set - NVRAM_00:
                        err = nvram_set( (char *)r->r[0], (void *)r->r[1], r->r[2] );
                        break;

                case NVRAM_GetBytes - NVRAM_00:
                        err = nvram_getbytes( (char *)r->r[0], (void *)r->r[1], r->r[2], r->r[3],
                                                &r->r[0] );
                        break;

                case NVRAM_SetBytes - NVRAM_00:
                        err = nvram_setbytes( (char *)r->r[0], (void *)r->r[1], r->r[2], r->r[3] );
                        break;

                default:
                        return error_BAD_SWI;
	}
	return msgfile_error_lookup( &msgs, err, NULL );

	NOT_USED( pw );
}


/*------------------------------------------------------------------------------
 * module_service
 *
 *      Module service call entry point.
 */
void
module_service( int service_no, _kernel_swi_regs *r, void *pw )
{
	switch ( service_no )
	{
		case Service_MessageFileClosed:
			msgfile_close( &msgs );
			msgfile_close( &tags );
			break;
	}
	NOT_USED( r );
	NOT_USED( pw );
}


#ifdef DEBUG

/*------------------------------------------------------------------------------
 * module_command
 *
 *	Module command handler.
 */
_kernel_oserror *
module_command( char *arg_string, int argc, int cmd_no, void *pw )
{
	_trace_on = (cmd_no == 0);
	return NULL;

	NOT_USED( arg_string );
	NOT_USED( argc );
	NOT_USED( pw );
}

#endif
