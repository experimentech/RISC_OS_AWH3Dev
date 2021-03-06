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
#include <string.h>
#include "kernel.h"
#include "swis.h"
#include "tester.h"
#include "logger.h"

void os_file0( char *name, int load, int exec, unsigned int length )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int i;

        logprintf( "os_file 0( \"%s\", %x, %x, %u ) ", name, load, exec, length );

        for ( i = 0;
              i < length;
              i++ )
        {
                random_data_area[ i ] = myrand() & 0xff;
                random_write_result[ i ] = myrand() & 0xff;
        }

        r.r[0] = 0;
        r.r[1] = (int)name;
        r.r[2] = load;
        r.r[3] = exec;
        r.r[4] = (int)random_data_area;
        r.r[5] = (int)random_data_area + length;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3f );

                check_catalogue_info( name, 0, load, exec, length, 0, 0xe );

                r.r[0] = 16;
                r.r[1] = (int)name;
                r.r[2] = (int)random_write_result;
                r.r[3] = 0;

                err = _kernel_swi( OS_File, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "when reloading saved memory " );
                }
                else
                {
                        if ( memcmp( random_data_area, random_write_result, length ) != 0 )
                        {
                                problems++;
                                logprintf( "data read back not same as data saved " );
                        }
                }
        }

        logprintf( "\n" );
}

void os_file1( char *name, int load, int exec, int attributes )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 1( \"%s\", %x, %x, %x ) ", name, load, exec, attributes );

        r.r[0] = 1;
        r.r[1] = (int)name;
        r.r[2] = load;
        r.r[3] = exec;
        r.r[5] = attributes;

        err = _kernel_swi( OS_File, &r, &newr );

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
                check_regs_unchanged( &r, &newr, 0x3f );

                check_catalogue_info( name, 0, load, exec, 0, attributes, 0x16 );
        }

        logprintf( "\n" );
}

void os_file2( char *name, int load )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 2( \"%s\", %x ) ", name, load );

        r.r[0] = 2;
        r.r[1] = (int)name;
        r.r[2] = load;

        err = _kernel_swi( OS_File, &r, &newr );

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
                check_regs_unchanged( &r, &newr, 0x7 );

                check_catalogue_info( name, 0, load, 0, 0, 0, 0x2 );
        }

        logprintf( "\n" );
}

void os_file3( char *name, int exec )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 3( \"%s\", %x ) ", name, exec );

        r.r[0] = 3;
        r.r[1] = (int)name;
        r.r[3] = exec;

        err = _kernel_swi( OS_File, &r, &newr );

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
                check_regs_unchanged( &r, &newr, 0xb );

                check_catalogue_info( name, 0, 0, exec, 0, 0, 0x4 );
        }

        logprintf( "\n" );
}

void os_file4( char *name, int attributes )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 4( \"%s\", %x ) ", name, attributes );

        r.r[0] = 4;
        r.r[1] = (int)name;
        r.r[5] = attributes;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
                pout_error( err );
        else
        {
                check_regs_unchanged( &r, &newr, 0x23 );

                check_catalogue_info( name, 0, 0, 0, 0, attributes, 0x10 );
        }

        logprintf( "\n" );
}

void os_file6( char *name )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs oldr;
        int directory_not_empty = No;

        logprintf( "os_file 6( \"%s\" ) ", name );

        r.r[0] = 17;
        r.r[1] = (int)name;

        _kernel_swi( OS_File, &r, &oldr );

        if ( oldr.r[0] == 2 )
        {
                char buff[ 500 ];

                r.r[0] = 9;
                r.r[1] = (int)name;
                r.r[2] = (int)buff;
                r.r[3] = sizeof(buff);
                r.r[4] = 0;
                r.r[5] = sizeof(buff);
                r.r[6] = (int)"*";

                err = _kernel_swi( OS_GBPB, &r, &r );

                if ( !err && r.r[3] > 0 )
                        directory_not_empty = Yes;
        }

        r.r[0] = 6;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_File, &r, &r );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_DirNotEmpty:
                        /* error if directory was empty */
                        if ( !directory_not_empty )
                                pout_error( err );
                        break;

                case Error_Locked:
                        /* error if object wasn't locked */
                        if ( (oldr.r[5] & 0x08) == 0 )
                                pout_error( err );
                        break;

                case Error_FSAccessViolation:
                case Error_CantDeleteCurrent:
                case Error_CantDeleteLibrary:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                if ( oldr.r[5] & 0x08 )
                {
                        problems++;
                        logprintf( "object was locked and was deleted " );
                }
                if ( oldr.r[0] != r.r[0] )
                {
                        problems++;
                        logprintf( "object type changed " );
                }
                if ( oldr.r[2] != r.r[2] )
                {
                        problems++;
                        logprintf( "load address changed " );
                }
                if ( oldr.r[3] != r.r[3] )
                {
                        problems++;
                        logprintf( "exec address changed " );
                }
                if ( oldr.r[4] != r.r[4] )
                {
                        problems++;
                        logprintf( "length changed " );
                }
                if ( oldr.r[5] != r.r[5] )
                {
                        problems++;
                        logprintf( "attributes changed " );
                }
                if ( directory_not_empty )
                {
                        problems++;
                        logprintf( "directory wasn't empty but was deleted " );
                }

                r.r[0] = 17;
                r.r[1] = (int)name;

                err = _kernel_swi( OS_File, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "while trying to find the object again " );
                }
                else if ( r.r[0] != 0 )
                {
                        problems++;
                        logprintf( "object present after deletion " );
                }
        }

        logprintf( "\n" );
}

void os_file7( char *name, int load, int exec, unsigned int start, unsigned int end )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 7( \"%s\", %x, %x, %x, %x ) ", name, load, exec, start, end );

        r.r[0] = 7;
        r.r[1] = (int)name;
        r.r[2] = load;
        r.r[3] = exec;
        r.r[4] = (int)start;
        r.r[5] = (int)end;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_TypesDontMatch:
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3f );
                check_catalogue_info( name, 1, load, exec, end - start, 0, 0xf );
        }

        logprintf( "\n" );
}

void os_file8( char *name, int ents )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 8( \"%s\", %d ) ", name, ents );

        r.r[0] = 8;
        r.r[1] = (int)name;
        r.r[4] = ents;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_TypesDontMatch:
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x13 );
                check_catalogue_info( name, 2, 0, 0, 0, 0, 0x1 );
        }

        logprintf( "\n" );
}

void os_file9( char *name )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 9( \"%s\" ) ", name );

        r.r[0] = 9;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                if ( (err->errnum & FileError_Mask) != Error_FSAccessViolation )
                        pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3 );
        }

        logprintf( "\n" );
}

void os_file10( char *name, int type, unsigned int length )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int i;

        logprintf( "os_file 10( \"%s\", %x, %u ) ", name, type, length );

        for ( i = 0;
              i < length;
              i++ )
        {
                random_data_area[ i ] = myrand() & 0xff;
                random_write_result[ i ] = myrand() & 0xff;
        }

        r.r[0] = 10;
        r.r[1] = (int)name;
        r.r[2] = type;
        r.r[4] = (int)random_data_area;
        r.r[5] = (int)random_data_area + length;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x37 );

                check_catalogue_info( name, 0, type<<8, 0, length, 0, 0x28 );

                r.r[0] = 16;
                r.r[1] = (int)name;
                r.r[2] = (int)random_write_result;
                r.r[3] = 0;

                err = _kernel_swi( OS_File, &r, &r );

                if ( err )
                {
                        pout_error( err );
                        logprintf( "when reloading saved memory " );
                }
                else
                {
                        if ( memcmp( random_data_area, random_write_result, length ) != 0 )
                        {
                                problems++;
                                logprintf( "data read back not same as data saved " );
                        }
                }
        }

        logprintf( "\n" );
}

void os_file11( char *name, int type, unsigned int start, unsigned int end )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 11( \"%s\", %x, %x, %x ) ", name, type, start, end );

        r.r[0] = 11;
        r.r[1] = (int)name;
        r.r[2] = type;
        r.r[4] = start;
        r.r[5] = end;

        err = _kernel_swi( OS_File, &r, &newr );

        if ( err )
        {
                switch( err->errnum & FileError_Mask )
                {
                case Error_TypesDontMatch:
                case Error_FSAccessViolation:
                case Error_DirectoryFull:
                        break;

                default:
                        pout_error( err );
                        break;
                }
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x37 );
                check_catalogue_info( name, 1, type<<8, 0, end - start, 0, 0x29 );
        }

        logprintf( "\n" );
}

void os_file16( char *name )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs oldr;

        logprintf( "os_file 16( \"%s\" ) ", name );

        r.r[0] = 17;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_File, &r, &oldr );

        if ( err )
        {
                pout_error( err );
                logprintf( "while getting attributes before loading\n" );
                return;
        }

#if BigFiles
        if ( (unsigned int)oldr.r[4] > RandomDataAmount )
        {
                logprintf( "too big to load\n" );
                return;
        }
#endif

        r.r[0] = 16;
        r.r[1] = (int)name;
        r.r[2] = (int)random_write_result;
        r.r[3] = 0;

        err = _kernel_swi( OS_File, &r, &r );

        if ( err )
        {
                if ( (err->errnum & FileError_Mask) == Error_FSAccessViolation ||
                        err->errnum == Error_AccessViolation )
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
                check_regs_unchanged( &oldr, &r, 0x3f );
        }

        logprintf( "\n" );
}

void os_file17( char *name )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;

        logprintf( "os_file 17( \"%s\" ) ", name );

        r.r[0] = 17;
        r.r[1] = (int)name;

        err = _kernel_swi( OS_File, &r, &r );

        if ( err )
                pout_error( err );
        else
        {
        }

        logprintf( "\n" );
}

void os_file18( char *name, int type )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_file 18( \"%s\", %x ) ", name, type );

        r.r[0] = 18;
        r.r[1] = (int)name;
        r.r[2] = type;

        err = _kernel_swi( OS_File, &r, &newr );

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
                check_regs_unchanged( &r, &newr, 0x3f );

                check_catalogue_info( name, 0, type<<8, 0, 0, 0, 0x20 );
        }

        logprintf( "\n" );
}
