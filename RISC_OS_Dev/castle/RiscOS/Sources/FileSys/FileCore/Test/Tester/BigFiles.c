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
#include <stdint.h>
#include "kernel.h"
#include "swis.h"
#include "tester.h"
#include "logger.h"

void big_file_test( char *name )
{
        _kernel_oserror *err;
        _kernel_swi_regs r;
        _kernel_swi_regs newr;
        uint64_t offset;
        uint32_t i;
        int      handle;

        logprintf( "big_file_test( \"%s\" ) ", name );

        r.r[0] = 55;
        r.r[1] = (int)"$";
        err = _kernel_swi( OS_FSControl, &r, &r );
        if ( (err != NULL) || (r.r[1] == 0) )
        {
                /* Implies not a big enough disc for 4GB file, non fatal fail */
                logprintf( "skipped due to lack of free space\n" );
                return;
        }

        /* Create large maximal +ve */
        r.r[0] = 11;
        r.r[1] = (int)name;
        r.r[2] = 0xFFD;
        r.r[4] = 0;
        r.r[5] = (int)0x7FFFFFFF;
        err = _kernel_swi( OS_File, &r, &r);
        if ( err != NULL )
        {
                /* Failed to create the object */
                pout_error( err );
                logprintf( "on create of maximal +ve object\n" );
                return;
        }

        /* Re open */
        r.r[0] = 0xCF;
        r.r[1] = (int)name;
        err = _kernel_swi( OS_Find, &r, &r );
        if ( err )
        {
                pout_error( err );
                logprintf( "when opening up\n" );
                return;
        }
        handle = r.r[0];

        /* Set pointer to just short of end */
        r.r[0] = 1;
        r.r[1] = handle;
        r.r[2] = 0x7FFFFF11;
        _kernel_swi( OS_Args, &r, &r );

        /* Write over the threshold to top bit set */
        for ( i = 0;
              i < 256;
              i++)
        {
                r.r[0] = i;
                r.r[1] = handle;
                err = _kernel_swi( OS_BPut, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "when flipping sign of unsigned extent" );
                        goto tidyup;
                }
        }

        /* Check where we are */
        r.r[0] = 0;
        r.r[1] = handle;
        err = _kernel_swi( OS_Args, &r, &newr );
        if ( err )
        {
                pout_error( err );
                logprintf( "when getting pointer" );
                goto tidyup;
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3FB );
                if ( newr.r[2] != (0x7FFFFF11uL + 256) )
                {
                        logprintf( "wrong pointer %u versus %u", newr.r[2], (0x7FFFFF11uL + 256) );
                        goto tidyup;
                }
        }

        /* Read over the boundary */
        r.r[0] = 3;
        r.r[1] = handle;
        r.r[2] = (int)random_write_result;
        r.r[3] = 256;
        r.r[4] = 0x7FFFFF11;
        err = _kernel_swi( OS_GBPB, &r, &r );
        if ( err )
        {
                pout_error( err );
                logprintf( "when reading padding" );
                goto tidyup;
        }
        else
        {
                for ( i = 0;
                      i < 256;
                      i++ )
                {
                        if ( random_write_result[ i ] != i )
                        {
                                logprintf( "sequential bytes not in order at %u", i );
                                goto tidyup;
                        }
                }
        }

        /* Close and delete */
        r.r[0] = 0;
        r.r[1] = handle;
        _kernel_swi( OS_Find, &r, &r );
        r.r[0] = 6;
        r.r[1] = (int)name;
        _kernel_swi( OS_File, &r, &r );
        if ( r.r[4] != (0x7FFFFF11uL + 256) )
        {
                logprintf( "catalogue deletion had wrong length\n" );
                return;
        }

        /* Create large */        
        r.r[0] = 11;
        r.r[1] = (int)name;
        r.r[2] = 0xFFD;
        r.r[4] = 0;
        r.r[5] = (int)0xFFFFF000 + myrand();
        err = _kernel_swi( OS_File, &r, &r);
        if ( err != NULL )
        {
                /* Failed to create the object */
                pout_error( err );
                logprintf( "on create of big object\n" );
                return;
        }

        /* Re open */
        r.r[0] = 0xCF;
        r.r[1] = (int)name;
        err = _kernel_swi( OS_Find, &r, &r );
        if ( err )
        {
                pout_error( err );
                logprintf( "when opening up\n" );
                return;
        }
        handle = r.r[0];

        /* Try to ensure size and check it doesn't wrap to 0 */
        r.r[0] = 6;
        r.r[1] = handle;
        r.r[2] = (int)0xFFFFFFFF;
        err = _kernel_swi( OS_Args, &r, &newr );
        if ( err )
        {
                pout_error( err );
                logprintf( "when ensuring 4G-1" );
                goto tidyup;
        }
        else
        {
                /* Normally R2 gets rounded up to a sector, but not for 4G-1 */
                check_regs_unchanged( &r, &newr, 0x3FF );
        }

        /* Test the write zeros entry */
        r.r[0] = 3;
        r.r[1] = handle;
        r.r[2] = (int)0xFFFFFFFF;
        err = _kernel_swi( OS_Args, &r, &newr );
        if ( err )
        {
                pout_error( err );
                logprintf( "when padding to 4G-1" );
                goto tidyup;
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3FF );
        }
        r.r[0] = 3;
        r.r[1] = handle;
        r.r[2] = (int)random_write_result;
        r.r[3] = 256;
        r.r[4] = (int)0xFFFFFEFF;
        err = _kernel_swi( OS_GBPB, &r, &r );
        if ( err )
        {
                pout_error( err );
                logprintf( "when reading padding" );
                goto tidyup;
        }
        else
        {
                for ( i = 0;
                      i < 256;
                      i++ )
                {
                        if ( random_write_result[ i ] != 0 )
                        {
                                logprintf( "non zero zero padding at 0xFFFFFF%02X", i );
                                goto tidyup;
                        }
                }
        }

        /* Spray some copies of the above test pattern into various
         * places in the test file, not sector aligned of course, that's too easy
         */
        for ( i = 0;
              i < RandomDataAmount;
              i++ )
        {
                random_data_area[ i ] = myrand() & 0xff;
        }

        for ( offset = 0;
              offset < 0x100000000uLL;
              offset = offset + 0x2000000 - 100 )
        {
                r.r[0] = 1;
                r.r[1] = handle;
                r.r[2] = (int)random_data_area;
                r.r[3] = (RandomDataAmount / 100) * 100;
                r.r[4] = (int)offset;
                if ( (uint32_t)(r.r[4] + r.r[3]) < (uint32_t)r.r[4] )
                {
                        /* Overflowed, dial it down a bit */
                        r.r[3] = 0xFFFFFFFF - r.r[4];
                }
                err = _kernel_swi( OS_GBPB, &r, &r );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "writing random data at %u", r.r[4] );
                        goto tidyup;
                }
        }

        r.r[0] = 255;
        r.r[1] = handle;
        err = _kernel_swi( OS_Args, &r, &newr );
        if ( err )
        {
                pout_error( err );
                logprintf( "when flushing 4G-1");
                goto tidyup;
        }
        else
        {
                check_regs_unchanged( &r, &newr, 0x3FF );
        }

        for ( offset = 0;
              offset < 0x100000000uLL;
              offset = offset + 0x2000000 - 100 )
        {
                r.r[0] = 3;
                r.r[1] = handle;
                r.r[2] = (int)random_write_result;
                r.r[3] = (RandomDataAmount / 100) * 100;
                r.r[4] = (int)offset;
                if ( (uint32_t)(r.r[4] + r.r[3]) < (uint32_t)r.r[4] )
                {
                        /* Overflowed, dial it down a bit */
                        r.r[3] = 0xFFFFFFFF - r.r[4];
                }
                err = _kernel_swi( OS_GBPB, &r, &newr );
                if ( err )
                {
                        pout_error( err );
                        logprintf( "reading random data from %u", r.r[4] );
                        goto tidyup;
                }
                else
                {
                        if ( memcmp( random_write_result, random_data_area, r.r[3] ) != 0 )
                        {
                                problems++;
                                logprintf( "data corrupt at %u", r.r[4] );
                        }
                }
        }

tidyup:
        r.r[0] = 0;
        r.r[1] = handle;
        _kernel_swi( OS_Find, &r, &r );

        if ( !problems )
        {
                /* Check type is file and length is 4G-1 */
                check_catalogue_info( name, 1, 0, 0, 0xFFFFFFFF, 0, 0x9 );
        }

        logprintf( "\n" );
}
