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

void os_fscontrol0( char *name )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 0( \"%s\" ) ", name );

        r.r[0] = 0;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );

                logprintf( "\nCatalogue of current directory:\n" );

                r.r[0] = 5;
                r.r[1] = (int)"";
                err = _kernel_swi( OS_FSControl, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while trying to catalogue current directory\n" );
                        return;
                }

                logprintf( "Catalogue of \"%s\":\n", name );

                r.r[0] = 5;
                r.r[1] = (int)name;

                err = _kernel_swi( OS_FSControl, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while trying to catalogue directory by name" );
                }
        }

        logprintf( "\n" );
}

void os_fscontrol1( char *name )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 1( \"%s\" ) ", name );

        r.r[0] = 1;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );

                logprintf( "\nCatalogue of library directory:\n" );

                r.r[0] = 5;
                r.r[1] = (int)"%";
                err = _kernel_swi( OS_FSControl, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while trying to catalogue library directory\n" );
                        return;
                }

                logprintf( "Catalogue of \"%s\":\n", name );

                r.r[0] = 5;
                r.r[1] = (int)name;

                err = _kernel_swi( OS_FSControl, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while trying to catalogue directory by name" );
                }
        }

        logprintf( "\n" );
}

void os_fscontrol5( char *name )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 5( \"%s\" ) ", name );

        r.r[0] = 5;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotFound )
                {
                        /* do nothing */
                }
                else
                {
                        pout_error( err );
                }
        }
        logprintf( "\n" );
}

void os_fscontrol6( char *name )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 6( \"%s\" ) ", name );

        r.r[0] = 6;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotFound )
                {
                        /* do nothing */
                }
                else
                {
                        pout_error( err );
                }
        }
        logprintf( "\n" );
}

void os_fscontrol7( void )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 7() " );

        r.r[0] = 7;
        r.r[1] = (int)"";

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                if ( err->errnum == ErrorNumber_NFS_directory_unset ||
                        err->errnum == Error_NotFound )
                {
                        /* do nothing */
                }
                else
                {
                        pout_error( err );
                }
        }
        logprintf( "\n" );
}

void os_fscontrol8( void )
{
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_oserror *err;

        logprintf( "os_fscontrol 8() " );

        r.r[0] = 8;
        r.r[1] = (int)"";

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                if ( err->errnum == ErrorNumber_NFS_directory_unset ||
                        err->errnum == Error_NotFound )
                {
                        /* do nothing */
                }
                else
                {
                        pout_error( err );
                }
        }
        logprintf( "\n" );
}

void os_fscontrol9( char *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_fscontrol 9( \"%s\" ) ", file );

        r.r[0] = 9;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x1 );
        }

        logprintf( "\n" );
}

void os_fscontrol24( char *file, char *opts )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_fscontrol 24( \"%s\", \"%s\" ) ", file, opts );

        r.r[0] = 24;
        r.r[1] = (int)file;
        r.r[2] = (int)opts;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                switch ( err->errnum & FileError_Mask )
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
                check_regs_unchanged( &r, &newr, 0x7 );
        }

        logprintf( "\n" );
}

void os_fscontrol25( char *from, char *to )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        _kernel_swi_regs oldattrs;

        logprintf( "os_fscontrol 25( \"%s\", \"%s\" ) ", from, to );

        r.r[0] = 17;
        r.r[1] = (int)from;

        err = _kernel_swi( OS_File, &r, &oldattrs );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading old attributes of object\n" );

                return;
        }

        r.r[0] = 25;
        r.r[1] = (int)from;
        r.r[2] = (int)to;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                switch ( err->errnum & FileError_Mask )
                {
                case Error_FSLocked:
                case Error_BadRENAME:
                case Error_Locked:
                case Error_FileOpen:
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                case Error_NotSameDisc:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x7 );

                r.r[0] = 17;
                r.r[1] = (int)from;

                err = _kernel_swi( OS_File, &r, &r );

                if ( (!err && r.r[0] != 0) ||
                        (err && err->errnum != Error_NotFound) )
                {
                        problems++;
                        logprintf( "renameing from still exists " );
                }

                r.r[0] = 17;
                r.r[1] = (int)to;

                err = _kernel_swi( OS_File, &r, &r );

                if ( err || (!err && r.r[0] == 0) )
                {
                        problems++;
                        logprintf( "renaming to doesn't exist " );
                }
                else
                {
                        if ( r.r[2] != oldattrs.r[2] )
                        {
                                problems++;
                                logprintf( "load address changed (%#010x to %#010x) ", oldattrs.r[2], r.r[2] );
                        }
                        if ( r.r[3] != oldattrs.r[3] )
                        {
                                problems++;
                                logprintf( "execute address changed (%#010x to %#010x) ", oldattrs.r[3], r.r[3] );
                        }
                        if ( r.r[4] != oldattrs.r[4] )
                        {
                                problems++;
                                logprintf( "length changed (%u to %u) ", oldattrs.r[4], r.r[4] );
                        }
                        if ( r.r[5] != oldattrs.r[5] )
                        {
                                problems++;
                                logprintf( "attributes changed (%#010x to %#010x) ", oldattrs.r[5], r.r[5] );
                        }
                }
        }

        logprintf( "\n" );
}

void os_fscontrol32( char *file )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_fscontrol 32( \"%s\" ) ", file );

        r.r[0] = 32;
        r.r[1] = (int)file;

        err = _kernel_swi( OS_FSControl, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x1 );
        }

        logprintf( "\n" );
}
