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
#include <stdio.h>
#include "kernel.h"
#include "swis.h"
#include "tester.h"
#include "logger.h"

void os_args0( int *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 0( %d ) ", *file );

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );

                r.r[0] = 2;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while getting extent of file " );
                }
                else
                {
                        if ( (unsigned int)r.r[2] < (unsigned int)newr.r[2] )
                        {
                                problems++;
                                logprintf( "sequential file pointer beyond file extent " );
                        }
                }
        }

        logprintf( "\n" );
}

void os_args1( int *file, unsigned int pointer )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_extent;
        unsigned int i;

        logprintf( "os_args 1( %d, %u ) ", *file, pointer );

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading file extent\n" );
                return;
        }

        old_extent = (unsigned int)r.r[2];

        r.r[0] = 1;
        r.r[1] = *file;
        r.r[2] = (int)pointer;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_OutsideFile && pointer > old_extent )
                {
                        /* do nothing */
                }
                else
                {
                        pout_error( err );
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x7 );

                r.r[0] = 0;
                r.r[1] = *file;

                err = _kernel_swi( OS_Args, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new sequential file pointer " );
                }
                else if ( pointer != (unsigned int)newr.r[2] )
                {
                        problems++;
                        logprintf( "new sequential file pointer not same as set one " );
                }
                else if ( pointer > old_extent )
                {
                        r.r[0] = 2;
                        r.r[1] = *file;

                        err = _kernel_swi( OS_Args, &r, &r );

                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while reading new file extent\n" );
                                return;
                        }

                        if ( r.r[2] != pointer )
                        {
                                problems++;
                                logprintf( "new extended file size isn't same as new pointer\n" );
                                return;
                        }

                        r.r[0] = 1;
                        r.r[1] = *file;
                        r.r[2] = (int)old_extent;

                        err = _kernel_swi( OS_Args, &r, &r );

                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while moving pointer to check for zero extension\n" );
                        }

                        for ( i = old_extent;
                              i < pointer;
                              i++ )
                        {
                                r.r[1] = *file;

                                err = _kernel_swi( OS_BGet, &r, &r );

                                if ( err )
                                {
                                        if ( err->errnum == Error_NotOpenForReading )
                                        {
                                                /* do nothing */
                                        }
                                        else
                                        {
                                                pout_error( err );
                                                logprintf( "while checking zero extention of file\n" );
                                        }

                                        return;
                                }

                                if ( r.r[0] != 0 )
                                {
                                        problems++;
                                        logprintf( "zero extention isn't all zeros\n" );
                                        return;
                                }
                        }
                }
        }

        logprintf( "\n" );
}

void os_args2( int *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 2( %d ) ", *file );

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );

                r.r[0] = 0;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while getting sequential file pointer of file " );
                }
                else
                {
                        if ( (unsigned int)r.r[2] > (unsigned int)newr.r[2] )
                        {
                                problems++;
                                logprintf( "sequential file pointer beyond file extent " );
                        }
                }
        }

        logprintf( "\n" );
}

void os_args3( int *file, unsigned int extent )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_pointer;
        unsigned int old_extent;
        unsigned int i;

        logprintf( "os_args 3( %d, %u ) ", *file, extent );

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading file's sequential pointer\n" );
                return;
        }

        old_pointer = (unsigned int)r.r[2];

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading file's extent\n" );
                return;
        }

        old_extent = (unsigned int)r.r[2];

        r.r[0] = 3;
        r.r[1] = *file;
        r.r[2] = (int)extent;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                if ( err->errnum != Error_NotOpenForUpdate )
                        pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x7 );

                r.r[0] = 2;
                r.r[1] = *file;

                err = _kernel_swi( OS_Args, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new extent " );
                }
                else if ( extent != (unsigned int)newr.r[2] )
                {
                        problems++;
                        logprintf( "new extent not same as set one " );
                }
                else if ( extent < old_pointer )
                {
                        r.r[0] = 0;
                        r.r[1] = *file;

                        err = _kernel_swi( OS_Args, &r, &r );

                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while reading new sequential file pointer\n" );
                                return;
                        }

                        if ( r.r[2] != extent )
                        {
                                problems++;
                                logprintf( "new pointer not dropped to extent\n" );
                                return;
                        }
                }
                else if ( extent > old_extent )
                {
                        r.r[0] = 1;
                        r.r[1] = *file;
                        r.r[2] = (int)old_extent;

                        err = _kernel_swi( OS_Args, &r, &r );

                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while moving pointer to check for zero extension\n" );
                        }
                        for ( i = old_extent;
                              i < extent;
                              i++ )
                        {
                                r.r[1] = *file;

                                err = _kernel_swi( OS_BGet, &r, &r );

                                if ( err )
                                {
                                        if ( err->errnum == Error_NotOpenForReading )
                                        {
                                                /* do nothing */
                                        }
                                        else
                                        {
                                                pout_error( err );
                                                logprintf( "while checking zero extention of file\n" );
                                        }
                                        return;
                                }

                                if ( r.r[0] != 0 )
                                {
                                        problems++;
                                        logprintf( "zero extention isn't all zeros\n" );
                                        return;
                                }
                        }
                }
        }

        logprintf( "\n" );
}

void os_args4( int *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 4( %d ) ", *file );

        r.r[0] = 4;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );
        }

        logprintf( "\n" );
}

void os_args5( int *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 5( %d ) ", *file );

        r.r[0] = 5;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );
        }

        logprintf( "\n" );
}

void os_args6( int *file, unsigned int ensure )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 6( %d, %u ) ", *file, ensure );

        r.r[0] = 6;
        r.r[1] = *file;
        r.r[2] = (int)ensure;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );
        }

        logprintf( "\n" );
}

void os_args255( int *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_args 255( %d ) ", *file );

        r.r[0] = 255;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x7 );
        }

        logprintf( "\n" );
}
