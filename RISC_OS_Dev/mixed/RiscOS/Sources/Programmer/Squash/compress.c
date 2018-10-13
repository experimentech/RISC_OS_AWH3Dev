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
/* -> c.compress
 * An LZW compression and decompression module
 * Author: J.G.Thackray
 * Copyright (c) 1990 Acorn Computers Ltd.
 * Version 0.01 - Initial version
 *         0.02 - Assembler swis added
 *         0.03 - First restartable swi added (compress_store_store)
 *         0.04 - First cut at all swis added
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "swis.h"
#include "Global/NewErrors.h"

#include "debug.h"
#include "cssr.h"
#include "zssr.h"
#include "SquashHdr.h"

extern int zcat_store_ass( char *input, char *output, unsigned int length, char *workspace );
extern int compress_store_ass( char *input, char *output, unsigned int length, char *workspace );

#define UNUSED(x)       (x = x)
#define FALSE           0
#define TRUE            (!FALSE)

/*
 * Required work space sizes for compress and decompress.
 */
#define COMP_WORKSZ     (31 * 1024)
#define DECOMP_WORKSZ   (17 * 1024)

/*
 * Masks for the flag bits in r0.
 */
#define SquashContinue  0x01
#define SquashMoreInput 0x02
#define SquashFast      0x04
#define SquashWorkSize  0x08
#define SquashLastFlag  0x10 /* First available flag bit in r0. */

/*
 * Error numbers
 */
#define Squash_bad_SWI           0
#define Squash_bad_address       1
#define Squash_corrupt_input     2
#define Squash_corrupt_workspace 3
#define Squash_bad_parameters    4

static _kernel_oserror *
error_return( int num )
{
        static int msgblock[4];
        static int msgopen = FALSE;
        struct
        {
                int  errnum;
                char errtok[8];
        } interr;

        if (!msgopen)
        {
                _kernel_oserror *e;

                e = _swix(MessageTrans_OpenFile, _INR(0,2),
                          msgblock, "Resources:$.Resources.Squash.Messages", 0);
                if (e != NULL) return e;
                msgopen = TRUE;
        }

        interr.errnum = CompressErrors + num;
        sprintf(interr.errtok, "COM%d", num);

        return _swix(MessageTrans_ErrorLookup, _INR(0,3),
                     &interr, msgblock, 0, 0);
}

static int
check_address( unsigned int addr, unsigned int length )
{
        int flags;

        _swix(OS_ValidateAddress, _INR(0,1) | _OUT(_FLAGS),
                                  addr, addr + length,
                                  &flags);
        return (flags & _C) ? -1 : 0;  
}

_kernel_oserror *
Squash_swi( int swi_no, _kernel_swi_regs *r, void *private_word )
{
        UNUSED( private_word );

        switch ( swi_no )
        {
                case Squash_Compress - Squash_00:

                        if ( r->r[0] & SquashWorkSize )
                        {
                                if ( r->r[0] != SquashWorkSize )
                                        return error_return( Squash_bad_parameters );
                                r->r[0] = COMP_WORKSZ;
                                if ( r->r[1] != -1 )
                                        r->r[1] = 12 + 3 * r->r[1] / 2;         /* max output size */
                                return NULL;
                        }

                        if ( check_address( r->r[1], 0 ) || check_address( r->r[4], r->r[5] ) )
                                return error_return( Squash_bad_address );

                        if ( (unsigned int)r->r[0] >= SquashLastFlag )
                                return error_return( Squash_bad_parameters );

                        {
                                /* Fast <=> from scratch to end and enough output space worst case */
                                int fast = (r->r[0] & (SquashContinue | SquashMoreInput)) == 0
                                                && 3 + r->r[3]*3/2 <= r->r[5];
                                char *input = (char *)r->r[2];

                                if ( fast )
                                {
                                        unsigned int output_used;
#ifdef Workspace
#undef Workspace
#endif
#define Workspace (5003*4)
                                        tracef0( "Squash: using fast compress\n" );

                                        output_used = compress_store_ass( input, (char *)r->r[4], r->r[3], (char *)r->r[1] );

                                        r->r[2] += r->r[3];             /* Where input starts */
                                        r->r[3] = 0;                    /* Input remaining */
                                        r->r[4] += output_used;         /* Where output starts */
                                        r->r[5] -= output_used;         /* Output remaining */
                                        r->r[0] = 0;                    /* Result */
                                }
                                else
                                {
                                        unsigned int output_size = r->r[5];
                                        compress_state *state = (compress_state *)r->r[1];
#ifdef Workspace
#undef Workspace
#endif
#define Workspace sizeof(compress_state)
                                        tracef0( "Squash: using state compress" );

                                        if ( !(r->r[0] & SquashContinue) )
                                        {
                                                /* Start from scratch */
                                                state->starting = 1;
                                        }

                                        r->r[0] = compress_store_store( &input, r->r[3], (char *)r->r[4],
                                                        (unsigned int *)r->r+5, state, r->r[0] & SquashMoreInput );

                                        if ( r->r[0] > output_failed )
                                                switch ( r->r[0] )
                                                {
                                                        case output_ws_corrupt:
                                                                return error_return( Squash_corrupt_workspace );
                                                }

                                        r->r[3] -= (int)input - r->r[2];        /* Input remaining */
                                        r->r[2] = (int)input;                   /* Where input starts */
                                        r->r[4] += r->r[5];                     /* Where output starts */
                                        r->r[5] = output_size - r->r[5];        /* Output remaining */
                                }
                        }

                        break;

                 case Squash_Decompress - Squash_00:

#ifdef Workspace
#undef Workspace
#endif
#define Workspace sizeof(zcat_state)
                        if ( r->r[0] & SquashWorkSize )
                        {
                                if ( r->r[0] != SquashWorkSize )
                                        return error_return( Squash_bad_parameters );

                                r->r[0] = DECOMP_WORKSZ;
                                r->r[1] = -1;                   /* Can't determine max output size */
                                return NULL;
                        }

                        if ( check_address( r->r[1], 0 ) || check_address( r->r[4], r->r[5] ) )
                                return error_return( Squash_bad_address );

                        if ( (unsigned int)r->r[0] >= SquashLastFlag )
                                return error_return( Squash_bad_parameters );

                        {
                                unsigned int output_used;
                                char *input = (char *)r->r[2];

                                if ( r->r[0] & SquashFast )
                                {
#ifdef Workspace
#undef Workspace
#endif
#define Workspace 0x4100
                                        tracef0( "Squash: using fast decompress\n" );

                                        output_used = zcat_store_ass( input, (char *)r->r[4], r->r[3], (char *)r->r[1] );

                                        r->r[2] += r->r[3];             /* Where input starts */
                                        r->r[3] = 0;                    /* Input remaining */
                                        r->r[4] += output_used;         /* Where output starts */
                                        r->r[5] -= output_used;         /* Output remaining */
                                        r->r[0] = 0;                    /* Result */
                                        break;
                                }
                                else
                                {
#ifdef Workspace
#undef Workspace
#endif
#define Workspace sizeof(compress_state)
                                        zcat_result result;
                                        zcat_state *state = (zcat_state *)r->r[1];
                                        unsigned int input_available = r->r[3];

                                        tracef0( "Squash: using state decompress\n" );

                                        if ( !(r->r[0] & SquashContinue) )
                                        {
                                                /* Start from scratch */
                                                state->starting = 1;
                                        }

                                        output_used = zcat_store_store( input, (char *)r->r[4], (unsigned int *)r->r+3,
                                                                r->r[5], r->r[0] & SquashMoreInput, state, &result );

                                        if ( result > zcat_failed )
                                                switch ( result )
                                                {
                                                        case zcat_input_corrupt:
                                                                return error_return( Squash_corrupt_input );
                                                        case zcat_ws_corrupt:
                                                                return error_return( Squash_corrupt_workspace );
                                                }

                                        r->r[0] = result;
                                        r->r[2] += input_available - r->r[3];   /* Where input starts */
                                        r->r[4] += output_used;                 /* Where output starts */
                                        r->r[5] -= output_used;                 /* Output remaining */
                                }
                        }

                        break;

                default:
                        return error_BAD_SWI;

        }

        return NULL;
}

/* End compress.c */
