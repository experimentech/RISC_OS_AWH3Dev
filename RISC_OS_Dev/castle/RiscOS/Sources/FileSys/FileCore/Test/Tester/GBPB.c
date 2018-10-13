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
#include "Tester.h"
#include "logger.h"


void os_gbpb2( int *file, unsigned int size )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_sfp;
        unsigned int old_extent;
        unsigned int i;
        unsigned int new_sfp;
        unsigned int new_extent;

        logprintf( "os_gbpb 2( %d, %u ) ", *file, size );

        for ( i = 0;
              i < size;
              i++ )
        {
                random_data_area[ i ] = myrand() & 0xff;
                random_write_result[ i ] = myrand() & 0xff;
        }

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading sequential file pointer at start\n" );
                return;
        }

        old_sfp = (int)r.r[2];

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading extent at start\n" );
                return;
        }

        old_extent = (int)r.r[2];

        r.r[0] = 2;
        r.r[1] = *file;
        r.r[2] = (int)random_data_area;
        r.r[3] = (int)size;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotOpenForUpdate )
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
                check_regs_unchanged( &r, &newr, 0x3 );

                if ( newr.r[3] != 0 )
                {
                        problems++;
                        logprintf( "R3 not returned as 0:is %u ", newr.r[3] );
                }
                if ( newr.r[2] != (int)random_data_area + size )
                {
                        problems++;
                        logprintf( "address past last byte not returned in R2:is %x ", newr.r[2] );
                }
                new_sfp = (unsigned int)newr.r[4];
                if ( old_sfp + size - newr.r[3] != new_sfp )
                {
                        problems++;
                        logprintf( "new sequential file pointer not passed back in R4:is %u ", new_sfp );
                }
                r.r[0] = 0;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading sequential file pointer after operation " );
                }
                else if ( (unsigned int)r.r[2] != new_sfp )
                {
                        problems++;
                        logprintf( "read-back sequential file pointer not equal to new sequential file pointer returned:is %d ", r.r[2] );
                }

                new_extent = old_extent;
                if ( new_sfp > new_extent )
                        new_extent = new_sfp;

                r.r[0] = 2;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new extent " );
                }
                else if ( (unsigned int)r.r[2] != new_extent )
                {
                        problems++;
                        logprintf( "read-back extent not correct:is %u ", r.r[2] );
                }

                r.r[0] = 3;
                r.r[1] = *file;
                r.r[2] = (int)random_write_result;
                r.r[3] = (int)size;
                r.r[4] = (int)old_sfp;

                err = _kernel_swi( OS_GBPB, &r, &r );

                if ( err )
                {
                        if ( err->errnum == Error_NotOpenForReading )
                        {
                                /* do nothing */
                        }
                        else
                        {
                                pout_error( err );
                                logprintf( "while reading back written data " );
                        }
                }
                else if ( memcmp( random_data_area, random_write_result, new_sfp - old_sfp ) != 0 )
                {
                        problems++;
                        logprintf( "data did not read back as written " );
                }
        }

        logprintf( "\n" );
}

void os_gbpb1( int *file, unsigned int size, unsigned int location )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_extent;
        unsigned int i;
        unsigned int new_sfp;
        unsigned int new_extent;

        logprintf( "os_gbpb 1( %d, %u, %u ) ", *file, size, location );

        for ( i = 0;
              i < size;
              i++ )
        {
                random_data_area[ i ] = myrand() & 0xff;
                random_write_result[ i ] = myrand() & 0xff;
        }

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading extent at start\n" );
                return;
        }

        old_extent = (unsigned int)r.r[2];

        r.r[0] = 1;
        r.r[1] = *file;
        r.r[2] = (int)random_data_area;
        r.r[3] = (int)size;
        r.r[4] = (int)location;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotOpenForUpdate )
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
                check_regs_unchanged( &r, &newr, 0x3 );

                if ( newr.r[3] != 0 )
                {
                        problems++;
                        logprintf( "R3 not returned as 0:is %u ", newr.r[3] );
                }
                if ( newr.r[2] != (int)random_data_area + size )
                {
                        problems++;
                        logprintf( "address past last byte not returned in R2:is %x ", newr.r[2] );
                }
                new_sfp = (unsigned int)newr.r[4];
                if ( location + size - newr.r[3] != new_sfp )
                {
                        problems++;
                        logprintf( "new sequential file pointer not passed back in R4:is %u ", new_sfp );
                }
                r.r[0] = 0;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading sequential file pointer after operation " );
                }
                else if ( r.r[2] != new_sfp )
                {
                        problems++;
                        logprintf( "read-back sequential file pointer not equal to new sequential file pointer returned:is %d ", r.r[2] );
                }

                new_extent = old_extent;
                if ( new_sfp > new_extent )
                        new_extent = new_sfp;

                r.r[0] = 2;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new extent " );
                }
                else if ( (unsigned int)r.r[2] != new_extent )
                {
                        problems++;
                        logprintf( "read-back extent not correct:is %u ", r.r[2] );
                }

                r.r[0] = 3;
                r.r[1] = *file;
                r.r[2] = (int)random_write_result;
                r.r[3] = (int)size;
                r.r[4] = (int)location;

                err = _kernel_swi( OS_GBPB, &r, &r );

                if ( err )
                {
                        if ( err->errnum == Error_NotOpenForReading )
                        {
                                /* do nothing */
                        }
                        else
                        {
                                pout_error( err );
                                logprintf( "while reading back written data " );
                        }
                }
                else if ( memcmp( random_data_area, random_write_result, new_sfp - location ) != 0 )
                {
                        problems++;
                        logprintf( "data did not read back as written " );
                }

                if ( location > old_extent )
                {
                        r.r[0] = 3;
                        r.r[1] = *file;
                        r.r[2] = (int)random_write_result;
                        r.r[3] = (int)(location - old_extent);
                        r.r[4] = (int)old_extent;

                        err = _kernel_swi( OS_GBPB, &r, &r );

                        if ( err )
                        {
                                if ( err->errnum == Error_NotOpenForReading )
                                {
                                        /* do nothing */
                                }
                                else
                                {
                                        pout_error( err );
                                        logprintf( "while reading back zero-extention of file " );
                                }
                        }
                        else
                        {
                                for ( i = 0;
                                      i < location - old_extent;
                                      i++ )
                                {
                                        if ( random_write_result[ i ] != 0 )
                                        {
                                                problems++;
                                                logprintf( "zero extention of file is non-zero " );
                                                break;
                                        }
                                }
                        }
                }                
        }

        logprintf( "\n" );
}

void os_gbpb4( int *file, unsigned int size )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_sfp;
        unsigned int old_extent;
        unsigned int new_sfp;
        unsigned int transfer_bytes;

        logprintf( "os_gbpb 4( %d, %u ) ", *file, size );

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading sequential file pointer at start\n" );
                return;
        }

        old_sfp = (unsigned int)r.r[2];

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading extent at start\n" );
                return;
        }

        old_extent = (unsigned int)r.r[2];

        r.r[0] = 4;
        r.r[1] = *file;
        r.r[2] = (int)random_data_area;
        r.r[3] = (int)size;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotOpenForReading )
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
                check_regs_unchanged( &r, &newr, 0x3 );

                transfer_bytes = size;
                if ( old_sfp + transfer_bytes > old_extent )
                {
                        transfer_bytes = old_extent - old_sfp;
                }

                if ( (unsigned int)newr.r[3] != size - transfer_bytes )
                {
                        problems++;
                        logprintf( "Bytes transferred not possible transfer size:is %u ", newr.r[3] );
                }
                if ( newr.r[2] != (int)random_data_area + transfer_bytes )
                {
                        problems++;
                        logprintf( "address past last byte not returned in R2:is %x ", newr.r[2] );
                }
                new_sfp = (unsigned int)newr.r[4];
                if ( old_sfp + size - newr.r[3] != new_sfp && old_sfp < old_extent && size > 0 )
                {
                        problems++;
                        logprintf( "new sequential file pointer not passed back in R4:is %u ", newr.r[4] );
                }
                r.r[0] = 0;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading sequential file pointer after operation " );
                }
                else if ( (unsigned int)r.r[2] != new_sfp && old_sfp < old_extent && size > 0 )
                {
                        problems++;
                        logprintf( "read-back sequential file pointer not equal to new sequential file pointer returned:is %d ", r.r[2] );
                }

                r.r[0] = 2;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new extent " );
                }
                else if ( (unsigned int)r.r[2] != old_extent )
                {
                        problems++;
                        logprintf( "extent has changed:is %u ", r.r[2] );
                }
        }

        logprintf( "\n" );
}

void os_gbpb3( int *file, unsigned int size, unsigned int location )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        unsigned int old_extent;
        unsigned int old_sfp;
        unsigned int new_sfp;
        unsigned int transfer_bytes;

        logprintf( "os_gbpb 3( %d, %u, %u ) ", *file, size, location );

        r.r[0] = 0;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading sequential file pointer at start\n" );
                return;
        }

        old_sfp = (unsigned int)r.r[2];

        r.r[0] = 2;
        r.r[1] = *file;

        err = _kernel_swi( OS_Args, &r, &r );

        if ( err )
        {
                pout_error( err );
                logprintf( "while reading extent at start\n" );
                return;
        }

        old_extent = (unsigned int)r.r[2];

        r.r[0] = 3;
        r.r[1] = *file;
        r.r[2] = (int)random_data_area;
        r.r[3] = (int)size;
        r.r[4] = (int)location;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                if ( err->errnum == Error_NotOpenForReading )
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
                check_regs_unchanged( &r, &newr, 0x3 );

                if ( location >= old_extent )
                {
                        if ( newr.r[2] != (int)random_data_area )
                        {
                                problems++;
                                logprintf( "data destination pointer has been advanced when not bytes should have been transfered:is %x ", newr.r[2] );
                        }
                        if ( (unsigned int)newr.r[3] != size )
                        {
                                problems++;
                                logprintf( "location to transfer from is beyond end of file and the number of bytes not transfered is not equal to the requested transfer size: is %u ", r.r[3] );
                        }

                        r.r[0] = 0;
                        r.r[1] = *file;
                        err = _kernel_swi( OS_Args, &r, &r );
                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while reading sequential file pointer after operation " );
                        }
                        else if ( old_sfp != (unsigned int)r.r[2] )
                        {
                                problems++;
                                logprintf( "sequential file pointer has changed:is %d ", r.r[2] );
                        }
                }
                else
                {
                        transfer_bytes = size;
                        if ( location + transfer_bytes > old_extent )
                        {
                                transfer_bytes = old_extent - location;
                        }

                        if ( (unsigned int)newr.r[3] != size - transfer_bytes )
                        {
                                problems++;
                                logprintf( "Bytes transferred not possible transfer size:is %u ", newr.r[3] );
                        }
                        if ( newr.r[2] != (int)random_data_area + transfer_bytes )
                        {
                                problems++;
                                logprintf( "address past last byte not returned in R2:is %d ", newr.r[2] );
                        }
                        new_sfp = (unsigned int)newr.r[4];
                        if ( location + size - newr.r[3] != new_sfp && transfer_bytes > 0 )
                        {
                                problems++;
                                logprintf( "new sequential file pointer not passed back in R4:is %u ", newr.r[4] );
                        }
                        r.r[0] = 0;
                        r.r[1] = *file;
                        err = _kernel_swi( OS_Args, &r, &r );
                        if ( err )
                        {
                                pout_error( err );
                                logprintf( "while reading sequential file pointer after operation " );
                        }
                        else if ( (unsigned int)r.r[2] != new_sfp && transfer_bytes > 0 )
                        {
                                problems++;
                                logprintf( "read-back sequential file pointer not equal to new sequential file pointer returned:is %d ", r.r[2] );
                        }
                }

                r.r[0] = 2;
                r.r[1] = *file;
                err = _kernel_swi( OS_Args, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "while reading new extent " );
                }
                else if ( (unsigned int)r.r[2] != old_extent )
                {
                        problems++;
                        logprintf( "extent has changed:is %u ", r.r[2] );
                }
        }

        logprintf( "\n" );
}


void os_gbpb5( void )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 5() " );

        r.r[0] = 5;
        r.r[2] = (int)random_data_area;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x5 );
        }

        logprintf( "\n" );
}


void os_gbpb6( void )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 6() " );

        r.r[0] = 6;
        r.r[2] = (int)random_data_area;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x5 );

                if ( random_data_area[0] != '\0' )
                {
                        problems++;
                        logprintf( "first byte isn't zero:is %d ", random_data_area[0] );
                }

                if ( random_data_area[ 2 + random_data_area[1] ] != 0 &&
                        random_data_area[ 2 + random_data_area[1] ] != 0xff )
                {
                        problems++;
                        logprintf( "privilege bytes isn't 0 or &ff:is %d ", random_data_area[ 2 + random_data_area[1] ] );
                }
        }

        logprintf( "\n" );
}


void os_gbpb7( void )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 7() " );

        r.r[0] = 7;
        r.r[2] = (int)random_data_area;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x5 );

                if ( random_data_area[0] != '\0' )
                {
                        problems++;
                        logprintf( "first byte isn't zero:is %d ", random_data_area[0] );
                }

                if ( random_data_area[ 2 + random_data_area[1] ] != 0 &&
                        random_data_area[ 2 + random_data_area[1] ] != 0xff )
                {
                        problems++;
                        logprintf( "privilege bytes isn't 0 or &ff:is %d ", random_data_area[ 2 + random_data_area[1] ] );
                }
        }

        logprintf( "\n" );
}


void os_gbpb8( int number )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 8( %d ) ", number );

        r.r[0] = 8;
        r.r[2] = (int)random_data_area;
        r.r[3] = number;
        r.r[4] = 0;

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                if ( (err->errnum & FileError_Mask) == Error_DoesNotExist ||
                        err->errnum == Error_FSDoesNotExist )
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
                check_regs_unchanged( &r, &newr, 0x5 );
        }

        logprintf( "\n" );
}

void os_gbpb9( char *name, int number )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 10( %s, %d ) ", name, number );

        r.r[0] = 9;
        r.r[1] = (int)name;
        r.r[2] = (int)random_data_area;
        r.r[3] = number;
        r.r[4] = 0;
        r.r[5] = sizeof(random_data_area);
        r.r[6] = (int)"*";

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x67 );
        }

        logprintf( "\n" );
}

void os_gbpb10( char *name, int number )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 10( %s, %d ) ", name, number );

        r.r[0] = 10;
        r.r[1] = (int)name;
        r.r[2] = (int)random_data_area;
        r.r[3] = number;
        r.r[4] = 0;
        r.r[5] = sizeof(random_data_area);
        r.r[6] = (int)"*";

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x67 );
        }

        logprintf( "\n" );
}

void os_gbpb11( char *name, int number )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;

        logprintf( "os_gbpb 11( %s, %d ) ", name, number );

        r.r[0] = 11;
        r.r[1] = (int)name;
        r.r[2] = (int)random_data_area;
        r.r[3] = number;
        r.r[4] = 0;
        r.r[5] = sizeof(random_data_area);
        r.r[6] = (int)"*";

        err = _kernel_swi( OS_GBPB, &r, &newr );

        if ( err )
        {
                pout_error( err );
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x67 );
        }

        logprintf( "\n" );
}
