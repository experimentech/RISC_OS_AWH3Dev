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
#include "Tester.h"
#include "logger.h"

void os_findclose( int *file )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_find close( %d ) ", *file );

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Find, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_FSAccessViolation:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0xff );
        }

        logprintf( "\n" );
}

void os_findin( char *file )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_find in( %s ) ", file );

        r.r[0] = 0x4f;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_Find, &r, &newr );

        if ( err )
        {
                if ( (err->errnum & FileError_Mask) == Error_FSAccessViolation )
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
                check_regs_unchanged( &r, &newr, 0x6 );

                r.r[0] = 0;
                r.r[1] = newr.r[0];

                err = _kernel_swi( OS_Args, &r, &r );
        
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while getting sequential file pointer " );
                }
                else if ( r.r[2] != 0 )
                {
                        problems++;
                        logprintf( "sequential file pointer not zero " );
                }

                r.r[1] = newr.r[0];
                r.r[0] = 0;

                err = _kernel_swi( OS_Find, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while closing the openned file " );
                }
        }

        logprintf( "\n" );
}

void os_findout( char *file )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;
        int old_access;

        logprintf( "os_find out( %s ) ", file );

        r.r[0] = 17;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_File, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading access before operation\n" );
                return;
        }

        old_access = r.r[5];

        r.r[0] = 0x8f;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_Find, &r, &newr );

        if ( err )
        {
                if ( ( (err->errnum & FileError_Mask) == Error_FSAccessViolation && (old_access & 0x22) != 0x22 ) || /* access violation and *somebody* doesn't have write access */
                     ( (err->errnum & FileError_Mask) == Error_FSAccessViolation && (old_access & 0x8) != 0 ) || /* access violation and file was locked */
                        err->errnum == Error_FSLocked ||
                       (err->errnum & FileError_Mask) == Error_DirectoryFull )
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
                check_regs_unchanged( &r, &newr, 0x6 );

                r.r[0] = 0;
                r.r[1] = newr.r[0];

                err = _kernel_swi( OS_Args, &r, &r );
        
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while getting sequential file pointer " );
                }
                else if ( r.r[2] != 0 )
                {
                        problems++;
                        logprintf( "sequential file pointer not zero " );
                }

                r.r[0] = 2;
                r.r[1] = newr.r[0];

                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading extent to check it " );
                }
                else if ( r.r[2] != 0 )
                {
                        problems++;
                        logprintf( "extent not set to zero " );
                }

                r.r[0] = 17;
                r.r[1] = (int)file;
                err = _kernel_swi( OS_File, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new access " );
                }
                else if ( r.r[5] != old_access )
                {
                        problems++;
                        logprintf( "access changed " );
                }

                r.r[1] = newr.r[0];
                r.r[0] = 0;

                err = _kernel_swi( OS_Find, &r, &r );

                if ( err )
                {
                        switch( err->errnum & FileError_Mask )
                        {
                        case Error_FSAccessViolation:
                                break;

                        default:
                                pout_error( err );
                                logprintf( "while closing the openned file " );
                                break;
                        }
                }
        }

        logprintf( "\n" );
}

void os_findup( char *file )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_find up( %s ) ", file );


        r.r[0] = 0x4f;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_Find, &r, &newr );

        if ( err )
        {
                if ( (err->errnum & FileError_Mask) == Error_FSAccessViolation )
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
                check_regs_unchanged( &r, &newr, 0x6 );

                r.r[0] = 0;
                r.r[1] = newr.r[0];

                err = _kernel_swi( OS_Args, &r, &r );
        
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while getting sequential file pointer " );
                }
                else if ( r.r[2] != 0 )
                {
                        problems++;
                        logprintf( "sequential file pointer not zero " );
                }

                r.r[1] = newr.r[0];
                r.r[0] = 0;

                err = _kernel_swi( OS_Find, &r, &r );

                if ( err )
                {
                        switch( err->errnum & FileError_Mask )
                        {
                        case Error_FSAccessViolation:
                                break;

                        default:
                                pout_error( err );
                                logprintf( "while closing the openned file " );
                                break;
                        }
                }
        }

        logprintf( "\n" );
}
