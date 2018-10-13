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
/*
     File and memory management for Filer_Action

Revision History:

0.07  13-May-90  ARW  Totally new implementation to old interface
*/

#define Timing 0

/*

Theory:

(1) read blocks (or all) of source file(s) into a contiguous chunk of store
    - extend as necessary up to next slot size
    - be prepared to lose information if slot size has to be shrunk

(2) write blocks to destination file(s)

(3) repeat until done

Notes:

(a) dynamically resize the block quanta for source and destination according
    to the real time it took: its programmed to update the user information
    (or allow other tasks in) around time_quanta (may get to 2*time_quanta).
    Hysteresis built in to the change in block size:
    - growth: <4096: +1024 AND NOT 1023
              <16K:  +4K AND NOT (4K-1)
              else:  double size
    - shrink: <4096: -256
              <16K:  -1024
              else:  -(quarter size)
    Initial block size is initial_block_size for both (=4096?)

(b) if a file is smaller than src_block, it is *loaded
    if a file is smaller than dest_block, it is *saved
    - these operations are not checked against time_quanta

(c) care needed to ensure that a contiguous block exists and can be moved
    by memcpy when it needs to be (user changes slot allocation - "action_slot").

 JRS 17/1/92 Measure the average transfer rate at the initial block size. If the blocksize
 is reduced below a certain critical value, then the transfer rate is compared with the initial
 value and if it is substantially worse, the value of time_quanta is increased, to allow
 blocksize to increase and get a better transfer rate at the expense of 'lumpy' response.
 Added hysteresis to time_quanta to prevent it always growing and shrinking

*/

#if 0
#define debugmem(k) dprintf k
#else
#define debugmem(k) /* Disabled */
#endif

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <stdlib.h>

#include "kernel.h"
#include "Interface/HighFSI.h"

#include "os.h"
#include "wimp.h"

#include "Options.h"
#include "chains.h"
#include "allerrs.h"
#include "malloc+.h"
#include "memmanage.h"
#include "debug.h"

#if Timing
static clock_t copytime;
#endif

#define No 0
#define Yes (!No)

#define InitialBlockSize 4096
#define SmallBlockSize   3072 /* check the transfer rate is not too low if the blocksize reduces below this */
#define MinimumWorkingSize InitialBlockSize*3

#define NominalTimeQuanta 25 /* cs */
#define MaxTimeQuanta    100
#define TimeQuantaHysteresis 3

/*
     The file headers are held in a doubly linked list, on the malloc+ heap
*/
typedef enum {
    write_not_started,
    write_f_tried_unlock,   /* open/save failed - have tried to unlock it */
    write_f_tried_cdirs,    /* open/save failed - have tried to cdir it */
    write_f_tried_both,     /* open/save failed - have tried both cdirs and unlock */
    write_openit,           /* have created it, now open it */
    write_truncateopen,     /* have opened it now truncate it */
    write_blocks,           /* next thing is writing blocks out */
    write_closeit,          /* next thing is to close it */
    write_adjust_access,    /* next thing is adjust the access */
    write_adjust_info,      /* next thing is adjust the info */
    write_all_done          /* and junk the fh */
}   write_activity;

typedef struct
{
    chain_link      link;
    char            *source_filename;
    int             source_file_handle;
    char            *destination_filename;
    int             destination_file_handle;
    uint32_t        size;
    int             reload;
    int             execute;
    int             attributes;
    int             objecttype;
    BOOL            forceit;
    uint32_t        read_to;
    uint32_t        written_to;
    write_activity  write_state;
    int             start_of_buffer;        /* offset into memory */

#ifdef USE_PROGRESS_BAR
    uint32_t        total_progress;
    uint32_t        read_progress;
    uint32_t        write_progress;
#endif
}   files_header;

/*
     Structures for copying files
*/
static chain_header files_chain;        /* All the files registered with memmanage */
static int application_max_size;
static char *buffer_base_address;       /* Base of buffer area */
static int buffer_offset;               /* offset to add to bottom, top, and any other offsets into the area */
                                        /* used when the area contents are shuffled */
static int buffer_bottom;               /* offset to 1st used byte in buffer area */
static int buffer_top;                  /* offset to top free section in buffer area */
static int buffer_end;                  /* offset to end of buffer area */
static int src_block_size;
static int dest_block_size;
static int time_quanta = NominalTimeQuanta;
static int minimum_block_size = 512;

BOOL  finished_obj_was_file;
char *finished_obj_source_name;

/* JRS addition 16/1/92 */
/* accumulate transfer times at initial blocksize to compare timings at smaller
 * blocksizes to detect when the time per byte increases unacceptably. This triggers
 * an increase in time_quanta which causes the blocksize to grow and the overall
 * transfer rate to improve */

#define timing_Reading 0
#define timing_Writing 1

#define timing_NAccumulated 4  /* accumulate this many timings to average out variation */

static struct
{
    int rate; /* transfer rate calculated from accumulator and blocksize */
    int accumulator;
    int naccumulated;
}   timing[2]; /* read and write initial timing */
/*
     Rate evaluation functions
*/

static void timing_init(void)
{
    int rw;
    for (rw = 0; rw < 2; rw++) /* reading and writing */
    {
        timing[rw].rate = 0;
        timing[rw].accumulator = 0;
        timing[rw].naccumulated = 0;
    }
}

static int t__accumulatortorate(int accumulated_time, int blocksize)
{ /* convert an accumulated timing to a transfer rate value */
    if (accumulated_time < 1) accumulated_time = 1; /* ensure no div by zero */
    debugmem(( "t__accumulatortorate: %d,%d->%d\n", accumulated_time, blocksize,(blocksize<<8) / accumulated_time));

    return (blocksize<<8) / accumulated_time; /* shift is to gain integer value range */
}

static void timing_accumulate(int rw, int t, int blocksize)
/* accumulate a timing for read or write, return Yes if it is full (enough have been accumulated) */
{
    assert((rw==timing_Reading)||(rw==timing_Writing));
    assert(timing[rw].naccumulated < timing_NAccumulated);
    timing[rw].naccumulated++;
    timing[rw].accumulator += t;
    if ( timing[rw].naccumulated >= timing_NAccumulated )
    { /* accumulator is full and rate is not yet calculated; calculate rate */
        assert(timing[rw].rate == 0);
        timing[rw].rate = t__accumulatortorate(timing[rw].accumulator, blocksize);
    }
}

static int timing_accumulating(int rw)
{
    assert((rw==timing_Reading)||(rw==timing_Writing));
    return (timing[rw].naccumulated < timing_NAccumulated);
}

static int timing_poorrate(int rw, int t, int blocksize)
{ /* compare the given time, converted to a rate against the rate for the initial blocksize.
   * Return Yes if it is worse than 2/3 of the initial rate */
    assert((rw==timing_Reading)||(rw==timing_Writing));
    return ( t__accumulatortorate(t * timing_NAccumulated, blocksize) <  (2*timing[rw].rate)/3 );
}


static int application_current_size( void )
{
    int currentslot = -1;
    int nextslot = -1;
    int freepool;

    wimp_slotsize( &currentslot, &nextslot, &freepool );

    return currentslot;
}

static int current_next_slot( void )
{
    int currentslot = -1;
    int nextslot = -1;
    int freepool;

    wimp_slotsize( &currentslot, &nextslot, &freepool );

    return nextslot;
}

/*
    returns amount actually changed by
*/
static int extend_application_slot( int amount )
{
    int oldslot;
    int currentslot;
    int nextslot = -1;
    int freepool;

    if ( amount != 0 )
    {
        oldslot = application_current_size();

        currentslot = oldslot + amount;

        wimp_slotsize( &currentslot, &nextslot, &freepool );

        debugmem(( "extend_application_slot: amount = %d, new size = %d\n",amount,currentslot));

        return currentslot - oldslot;
    }
    else
    {
        return 0;
    }
}

/*
    Ensure that the top to end amount free is at least size
*/
static BOOL buffer_ensure( int size )
{
    if ( buffer_end - buffer_top < size )
    {
        buffer_end += extend_application_slot( size - (buffer_end - buffer_top) );
    }

    return buffer_end - buffer_top >= size;
}

/*
    Grow the buffer so that "size" is available, limiting by application_max_siz.
    Reduces *size to fit space.
    Returns Yes if not enough space available for original requested *size.
*/
static int grow_buffer( int *size )
{
    BOOL answer = No;

    /*
        Upper bound by application_max_size
    */
    if ( (int)(buffer_base_address + *size + buffer_top + buffer_offset) > application_max_size + 0x8000 )
    {
        *size = application_max_size + 0x8000 - (int)(buffer_base_address + buffer_top + buffer_offset);
        answer = Yes;
    }

    /*
        Try to ensure that much space
    */
    answer = answer || !buffer_ensure( *size );

    if ( buffer_end - buffer_top < *size )
    {
        *size = buffer_end - buffer_top;
        answer = Yes;
    }

    return answer;
}

static os_error *close_file( int *handle )
{
    os_regset r;
    os_error *err;

    r.r[0] = 0; /* close file */
    r.r[1] = *handle;

    err = os_find( &r );

    /*
         Even a failed close leaves the file closed afterwards
    */
    *handle = 0;

    return err;
}

/*
     Creates the file to be the given size, dead, with read/write
     access only.
*/
static os_error *create_file_dead( char *filename, uint32_t size )
{
    os_filestr fileplace;
    os_error *err;

    fileplace.action   = OSFile_Create;
    fileplace.name     = filename;
    fileplace.loadaddr = (int) 0xdeaddead;
    fileplace.execaddr = (int) 0xdeaddead;
    fileplace.start    = 0;
    fileplace.end      = (int)size;

    err = os_file( &fileplace );

    if ( err )
         return err;

    fileplace.action = OSFile_WriteAttr;
    fileplace.name = filename;
    fileplace.end = read_attribute | write_attribute;

    return os_file( &fileplace );
}

static os_error *create_directory( char *dirname )
{
    os_filestr fileplace;

    fileplace.action = OSFile_CreateDir;
    fileplace.name = dirname;
    fileplace.start = 0;

    return os_file( &fileplace );
}

static os_error *write_catalogue_information( char *filename, int objecttype, int reload, int execute, int attributes )
{
    os_filestr fileplace;

    if (objecttype == object_directory)
    {
        /* Check if we're overwriting an image file's information from a directory */
        fileplace.action = OSFile_ReadNoPath;
        fileplace.name = filename;
        os_error *err = os_file( &fileplace );
        if ( err != NULL )
            return err;

        if ( fileplace.action != objecttype )
        {
            /* Leave the filetype and user read/write bits alone */
            reload = (reload &~ 0xFFF00) | (fileplace.loadaddr & 0xFFF00);
            attributes = (attributes &~ 3) | (fileplace.end & 3);
        }
    }

    fileplace.action    = OSFile_WriteInfo;
    fileplace.name      = filename;
    fileplace.loadaddr  = reload;
    fileplace.execaddr  = execute;
    fileplace.end       = attributes;

    return os_file( &fileplace );
}

static os_error *write_attributes( char *filename, int attributes )
{
    os_filestr fileplace;

    fileplace.action    = OSFile_WriteAttr;
    fileplace.name      = filename;
    fileplace.end       = attributes;

    return os_file( &fileplace );
}

static char *first_dirbreak( char *filename )
{
    char *trypos;
    char *endpos;

    /*
        Point trypos past the -<fsname>- / <fsname>: bit
    */
    if ( filename[0] == '-' )
    {
        /*
            -<fsname>-
        */
        trypos = strchr( filename + 1, '-' ) + 1;
    }
    else if ( filename[0] != ':' )
    {
        /*
            <fsname>: perhaps
        */
        trypos = strchr( filename, ':' );

        if ( trypos == NULL )
        {
            /*
                 It wasn't <fsname>:, never mind
            */
            trypos = filename;
        }
        else
        {
            trypos++;
        }
    }
    else
    {
        trypos = filename;
    }

    /*
        Move trypos past the :<devname> or :<devname>. bit if it's there
    */
    if ( *trypos == ':' )
    {
        endpos = strchr( trypos, '.' );

        if ( endpos == NULL )
        {
            trypos = trypos + strlen( trypos );
        }
        else
        {
            trypos = endpos + 1;
        }
    }

    /*
         Move past the first component (and any $. &. %. @. or \.)
    */
    if ( *trypos != '\0' )
    {
        switch( *trypos )
        {
        case '$':
        case '&':
        case '%':
        case '@':
        case '\\':

            trypos ++;

            if ( *trypos == '.' )
                trypos++;

             /*
                Fall through to skipping over the next component
             */

        default:
            endpos = strchr( trypos, '.' );

            if ( endpos == NULL )
            {
                trypos = trypos + strlen( trypos );
            }
            else
            {
                trypos = endpos;
            }

            break;
        }
    }

    /*
         trypos now points past the first non-special component
         of the filename or at the terminating nul
    */

    return trypos;
}

static os_error *ensure_file_directories( char *filename )
{
    char *currpos;
    os_error *err;

    for ( currpos = first_dirbreak( filename );
          currpos && *currpos;
          currpos = strchr( currpos + 1, '.' ) )
    {
        *currpos = '\0';

        err = create_directory( filename );

        *currpos = '.';

        if ( err )
            return err;
    }

    return NULL;
}

/*
     Ensures files used by fh are closed, and ignores any errors it gets
     back. The destination file, if closed, will be truncated to the
     written_to size, and set to dead.
*/
static void ensure_files_closed( files_header *fh )
{
    if ( fh->destination_file_handle )
        close_file( &fh->destination_file_handle );

    if ( fh->source_file_handle )
        close_file( &fh->source_file_handle );
}

/*
     Totally junk an fh: remove it from the files chain
*/
static void remove_fh( files_header *fh )
{
    chain_remove_link( &fh->link );

    ensure_files_closed( fh );

    if ( fh->start_of_buffer + fh->read_to - fh->written_to >= buffer_top )
    {
        /*
            removing buffer at end
        */

        if ( fh->start_of_buffer < buffer_top )
            buffer_top = fh->start_of_buffer;
    }
    else
    {
        /*
            removing buffer at start
        */
        buffer_bottom += fh->read_to - fh->written_to;
    }

    if ( fh->source_filename )
        overflowing_free( fh->source_filename );

    overflowing_free( fh->destination_filename );
    overflowing_free( fh );
}

/*
     Assuming no buffer in buffer chain, and no open files, remove
     forwards file from files_chain.
*/
static void remove_file_from_chain( void )
{
    chain_link *link = files_chain.forwards;
    files_header *fh;

    if ( !link->forwards )
        return;

    fh = chain_link_Wrapper( link );

    /*
        Special indication that it has been a directory that's just
        been finished
    */
    if ( fh->objecttype == object_directory )
    {
        finished_obj_was_file = No;
    }
    else
    {
        finished_obj_was_file = Yes;
    }

    /*
        Record the source filename of the finished file
    */
    if ( finished_obj_source_name )
        overflowing_free( finished_obj_source_name );

    finished_obj_source_name = fh->source_filename;
    fh->source_filename = NULL;

    remove_fh( fh );
}

/*
     returns the files_handle of the next file to read
*/
static files_header *next_fh_to_read( void )
{
    chain_link *link;
    files_header *fh;

    for ( link = files_chain.forwards; link->forwards; link = link->forwards )
    {
        fh = chain_link_Wrapper( link );

        if ( fh->objecttype != object_directory &&
             ( fh->read_to < fh->size ||
               fh->source_file_handle ) )
        {
            return fh;
        }
    }

    return NULL;
}

/*
     skip a general file
*/
static void skip_file( files_header *fh )
{
    if ( fh == NULL )
        return;

    remove_fh( fh );
}

/*
     algorithms to grow and shrink block size on time out
*/

static int grow( int block )
{
    if ( block < 4096 )
    {
        block = (block + 1024) & ~1023;
    }
    else if ( block < 16384 )
    {
        block = (block + 4096) & ~4095;
    }
    else
    {
        block = (block + (block>>1)) & ~4095;
    }

    debugmem(( "grow: to %d\n", block ));

    return block;
}

static int shrink( int block )
{
    if ( block < 4096 )
    {
        block = (block - 256) & ~255;
    }
    else if ( block < 16384 )
    {
        block = (block - 1024) & ~1023;
    }
    else
    {
        block = (block - (block>>2)) & ~1023;
    }

    if ( block < minimum_block_size )
        block = minimum_block_size;

    debugmem(( "shrink: to %d\n", block ));

    return block;
}

/*
    Go through all readable files and discard their buffers if they overhang
    the top of the buffer
*/
static void truncate_overhanging_files( void )
{
    chain_link *link;
    files_header *fh;

    for ( link = files_chain.forwards; link->forwards; link = link->forwards )
    {
        fh = chain_link_Wrapper( link );

        if ( fh->objecttype != object_directory )
        {
            if ( fh->start_of_buffer >= buffer_top )
            {
                /*
                    file buffer starts beyond end of buffer
                */
                fh->start_of_buffer = 0;
                fh->read_to = fh->written_to;
            }
            else if ( fh->start_of_buffer + fh->read_to - fh->written_to > buffer_top )
            {
                /*
                    file buffer hangs over end of buffer
                */
                fh->read_to = buffer_top - (fh->start_of_buffer - fh->written_to);
            }
        }
    }
}

static int memmanage_slotextend( int n, void **p )
{
    int size_grown;
    int movement;

    size_grown = MinimumWorkingSize - (buffer_end + buffer_offset - n);
    if ( size_grown > 0 )
    {
        /*
            Not enough room in current slot, so try to extend
            If fail to extend then can't satisfy request
        */
        buffer_end += extend_application_slot( size_grown );

        if ( buffer_end + buffer_offset - n < MinimumWorkingSize )
            return 0;

        if ( application_max_size < (int)(buffer_base_address + buffer_offset + buffer_end) - 0x8000 )
            application_max_size = (int)(buffer_base_address + buffer_offset + buffer_end) - 0x8000;
    }

    if ( buffer_bottom + buffer_offset >= n )
    {
        /*
            Already enough room below used section - no action necessary
        */
    }
    else if ( buffer_bottom + buffer_offset + buffer_end - buffer_top >= n )
    {
        /*
            Enough room in unused space, but not enough room below
            used section so move used section of buffer up
            to make room.
        */
        memmove( buffer_base_address + n,
            buffer_base_address + buffer_bottom + buffer_offset,
            buffer_top - buffer_bottom );

        movement = n - (buffer_offset + buffer_bottom);
        buffer_end -= movement;
        buffer_offset += movement;
    }
    else
    {
        /*
            Not enough room in the available slot - try to extend
        */
        size_grown = n - (buffer_bottom + buffer_offset + buffer_end - buffer_top);

        (void)grow_buffer( &size_grown );

        memmove( buffer_base_address + n,
            buffer_base_address + buffer_bottom + buffer_offset,
            buffer_end + buffer_offset - n );

        movement = n - (buffer_offset + buffer_bottom);
        buffer_end -= movement;
        buffer_offset += movement;

        if ( buffer_top > buffer_end )
        {
            buffer_top = buffer_end;
            truncate_overhanging_files();
        }
    }

    *p = buffer_base_address;
    buffer_base_address += n;
    buffer_offset -= n;

    return n;
}

/*****************************************************************

Below here is the external interface stuff

*****************************************************************/

/*
     Set the slot size to that passed.
     Return an error if the wimp_slotsize failed or the slot size
      obtained is less than that requested.
*/
void action_slot( int size )
{
    int size_change = size - application_current_size();

    debugmem(( "action_slot: by %d to %d\n", size_change, size ));

    if ( size_change > 0 )
    {
        /*
            Grow slot
        */
        buffer_end += extend_application_slot( size_change );
    }
    else if ( size_change < 0 )
    {
        /*
            Shrink slot
        */

        /*
            Lower-bound size change to ensure we still have MinimumWorkingSize
        */
        if ( buffer_end + buffer_offset + size_change < MinimumWorkingSize )
            size_change = MinimumWorkingSize - buffer_end - buffer_offset;

        if ( buffer_top > buffer_end + size_change )
        {
            /*
                Ensure the data is at the bottom of the buffer area
            */
            debugmem(( "action_slot: Base=%#010x, offset=%d, bottom=%d, top=%d, end=%d\n", (int)buffer_base_address, buffer_offset, buffer_bottom, buffer_top, buffer_end ));
            memmove(
                buffer_base_address,
                buffer_base_address + buffer_bottom + buffer_offset,
                buffer_top - buffer_bottom );

            buffer_end += buffer_bottom + buffer_offset;
            buffer_offset -= buffer_bottom + buffer_offset;
        }

        size_change = extend_application_slot( size_change );

        /*
            Adjust buffer_end by actual amount changed by
        */
        buffer_end += size_change;

        /*
            Upper bound buffer_top by buffer_end
        */
        if ( buffer_top > buffer_end )
            buffer_top = buffer_end;
    }

    truncate_overhanging_files();

    application_max_size = (int)(buffer_base_address + buffer_offset + buffer_end) - 0x8000;
    debugmem(( "action_slot: app max size %d\n", application_max_size ));
    debugmem(( "action_slot: Base=%#010x, offset=%d, bottom=%d, top=%d, end=%d\n", (int)buffer_base_address, buffer_offset, buffer_bottom, buffer_top, buffer_end ));
}

/*
     Initialise to end in suitable place for closedown
*/
os_error *init_memmanagement( void )
{
    /*
        Things that use real memory ( base = null )
    */
    chain_initialise_header( &files_chain );

    /*
        This determines the maximum size we will allow buffer
        allocation to grow to. This starts at the
        current next slot size, then gets adjusted when the
        user drags the memory slider
    */
    application_max_size = current_next_slot();

    /*
        The buffer area
    */
    buffer_base_address = (char *)(application_current_size() + 0x8000);
    buffer_offset = 0;
    buffer_bottom = 0;
    buffer_top = 0;
    buffer_end = 0;

    finished_obj_source_name = NULL;

    (void)_kernel_register_slotextend( memmanage_slotextend );

    return NULL;
}

/*
     Get into a fit state for copying. The chains and area
     pointers should already been zeroed out by calling
     init_memmangement. This routine starts off flex and heap,
     which grab more wimp space, which is why this part of the
     initialisation is left out of the general initialisation
     sequence. The routine also tries to grab a buffer, just to
     make sure this is feasible. No buffer => No copying!
*/
os_error *init_for_copying( void )
{
#if Timing
    copytime = clock();
#endif
    src_block_size = InitialBlockSize;
    dest_block_size = InitialBlockSize;
    timing_init();

    if ( buffer_ensure( MinimumWorkingSize ) )
    {
        if ( application_max_size < application_current_size() )
            application_max_size = application_current_size();

        return NULL;
    }
    else
    {
        return error( mb_slotsize_too_small ); /* was mb_malloc_failed */
    }
}

/*
     Misc. ESSENTIAL tidying up:
      Close down any open files
*/
void closedown_memmanagement( void )
{
    chain_link *link;
    files_header *fh;

    for ( link = files_chain.forwards; link->forwards; link = link->forwards )
    {
        fh = chain_link_Wrapper( link );

        ensure_files_closed( fh );
    }
#if Timing
    copytime = clock() - copytime;
    werr(0, "time taken for file copy = %d.%02ds", copytime/100, copytime%100);
#endif
#ifdef debug
#ifdef debugfile
    if ( debugf != NULL ) fclose( debugf );
#endif
#endif
}

/*
     Add a file to the end of the files chain
*/
os_error *add_file_to_chain( char *destination, char *source,
                             uint32_t size, int reload, int execute, int attributes, int objecttype,
                             BOOL forceit, BOOL *i_am_full
                             #ifdef USE_PROGRESS_BAR
                             , uint32_t progress, void **ref
                             #endif
                           )
{
    files_header *fh;

    fh = overflowing_malloc( sizeof( files_header ));
    if ( fh )
    {
        fh->source_filename = overflowing_malloc( strlen( source ) + 1 );

        if ( fh->source_filename )
        {
            fh->destination_filename = overflowing_malloc( strlen( destination ) + 1 );

            if ( fh->destination_filename )
            {
                /*
                     Initialise the structure
                */
                strcpy( fh->source_filename, source );
                fh->source_file_handle = 0;
                strcpy( fh->destination_filename, destination );
                fh->destination_file_handle = 0;
                fh->size = size;
                fh->reload = reload;
                fh->execute = execute;
                fh->attributes = attributes;
                fh->objecttype = objecttype;
                fh->forceit = forceit;
                fh->read_to = 0;
                fh->written_to = 0;
                fh->write_state = write_not_started;
                fh->start_of_buffer = 0;

                #ifdef USE_PROGRESS_BAR
                fh->total_progress = progress / 2;
                fh->write_progress = fh->read_progress = fh->total_progress;
                if (ref != NULL) *ref = fh;
                debugmem(( "add_file_to_chain: %s type %d progress %08x\n", destination, objecttype, fh->total_progress ));
                #endif

                /*
                     link to backwards end of files chain
                */
                chain_insert_before_header( &fh->link, fh, &files_chain );

                *i_am_full = No;

                return NULL;
            }

            overflowing_free( fh->source_filename );
        }

        overflowing_free( fh );
    }

    *i_am_full = Yes;

    /*
         one of the heap_allocs failed
    */
    return error( mb_malloc_failed );
}


#ifdef USE_PROGRESS_BAR
void modify_chain_file_progress(void *ref, uint32_t progress)
{
  files_header *fh = (files_header *)ref;

  if (fh != NULL)
  {
    debugmem(( "\nmodify chain: %s %x\n", fh->destination_filename, progress ));
    fh->write_progress = fh->total_progress = progress;
  }
}
#endif


/* Modified to return the progress value of the finished file	*/
os_error *read_a_block( BOOL *i_am_full, BOOL *need_another_file, BOOL *that_finished_a_file, uint32_t *progress )
{
    files_header *fh;
    os_regset    r;
    os_error     *err;
    os_gbpbstr   gbpbplace;
    int          size_needed;
    uint32_t     start_read_to;
    clock_t      t;

    *i_am_full = No;
    *that_finished_a_file = No;

    fh = next_fh_to_read();

    if ( !fh )
    {
        *need_another_file = Yes;

        return NULL;
    }

    *need_another_file = No;

    debugmem(( "read_a_block: from %s\n", fh->source_filename ));

    start_read_to = fh->read_to;

    /*
         If we have to do some reading
    */
    if ( fh->read_to < fh->size )
    {
        debugmem(( "R" ));
        /*
            Work out how much buffer is needed...
        */

        /*
            Upper bound to src_block_size and amount to read in file
        */
        if ( fh->size - fh->read_to > src_block_size )
        {
            size_needed = src_block_size;
        }
        else
        {
            /* This calculation fits in a signed integer provided src_block_size < 2G */
            size_needed = fh->size - fh->read_to;
        }

        /*
             Ensure word-alignment of file ptr and buffer address
             equal, to ensure DMA operation on DMA-capable disc
             systems (eg Iyonix ADFS).
        */
        if ( fh->read_to == fh->written_to &&
             (buffer_top & 3) != (fh->read_to & 3) )
        {
            int pad = ((fh->read_to & 3) - (buffer_top & 3)) & 3;
            *i_am_full = grow_buffer( &pad );
            if ( pad <= 0)
                return NULL;
            buffer_top += pad;
        }
        /*
             Enlarge the buffer (if possible)
        */
        *i_am_full = grow_buffer( &size_needed );

        if ( size_needed <= 0 )
            return NULL;

        /*
            Set up new buffer
        */
        if ( fh->read_to == fh->written_to )
        {
            fh->start_of_buffer = buffer_top;
        }

        /*
             Sub-optimal case: read file in chunks

             If the file isn't open yet, then open it
        */
        if ( fh->source_file_handle == 0 )
        {
            debugmem(( "O" ));
            r.r[0] = open_read | open_nopath | open_nodir | open_mustopen;
            r.r[1] = (int)fh->source_filename;

            err = os_find( &r );

            if ( err )
                return err;

            fh->source_file_handle = r.r[0];
        }

        t = clock();

        /*
            Read a block into the buffer.
        */
        gbpbplace.action = OSGBPB_ReadFromGiven;
        gbpbplace.file_handle = fh->source_file_handle;
        gbpbplace.data_addr = buffer_base_address + buffer_offset + buffer_top;
        gbpbplace.number = size_needed;
        gbpbplace.seq_point = fh->read_to;

        debugmem(( "read_a_block: buf %x + %u [%u-%u]\n", buffer_base_address, buffer_offset,
                                                          buffer_bottom, buffer_top ));
        debugmem(( "read_a_block: (%d,%d<-%d)\n", gbpbplace.data_addr, gbpbplace.number, gbpbplace.seq_point ));

        err = os_gbpb( &gbpbplace );
        if ( err )
            return err;

        fh->read_to += size_needed;
        buffer_top += size_needed;

        if (src_block_size == size_needed)
        {  /* only time full block transfers */
            t = clock() - t;
            if ( timing_accumulating(timing_Reading) )
            { /* accumulating initial timings */
                assert(src_block_size == InitialBlockSize);
                timing_accumulate(timing_Reading, t, src_block_size);
            }
            else if (time_quanta < MaxTimeQuanta)
            {
                if ( (src_block_size <= SmallBlockSize)
                  && timing_poorrate(timing_Reading, t, src_block_size) )
                { /* if the transfer rate is suffering at this small blocksize,
                   * increase time_quanta to cause the blocksize to grow */
                    if (time_quanta < MaxTimeQuanta) time_quanta *= 2;
                    debugmem(( "read_a_block: time_quanta to %d\n", time_quanta));
                }
                if ( t < time_quanta - TimeQuantaHysteresis) src_block_size = grow( src_block_size );
                if ( t > time_quanta + TimeQuantaHysteresis) src_block_size = shrink( src_block_size );
            }
        }

        if ( fh->read_to >= fh->size )
        {
            debugmem(( "C" ));
            err = close_file( &fh->source_file_handle );
            if ( err )
                return err;
        }
    }

    /*
         If we've finished reading the file
    */
    if ( fh->read_to >= fh->size )
    {
        *that_finished_a_file = Yes;

        #ifdef USE_PROGRESS_BAR
        *progress = fh->read_progress;
        #else
        IGNORE(progress);
        #endif

        /*
            If there isn't another file to read, tell the client about
            it now.
        */
        if ( next_fh_to_read() == NULL )
            *need_another_file = Yes;
    }
    #ifdef USE_PROGRESS_BAR
    else
    {
        uint64_t p;
        uint32_t b;

        b = fh->read_to - start_read_to; /* bytes read this time */
        p = (fh->total_progress * (uint64_t)b) / fh->size;

        fh->read_progress -= (uint32_t) p;
        *progress = (uint32_t) p;

        debugmem(( "partial read: %u bytes / %u = %08x progress\n", b, fh->size, *progress ));
    }
    #endif

    debugmem(( "X\n" ));

    return NULL;
}

void skip_file_read( void )
{
    skip_file( next_fh_to_read() );
}

static os_error *int_write_a_block( BOOL *i_am_empty, BOOL *that_finished_a_file, uint32_t *progress )
{
    os_gbpbstr   gbpbplace;
    os_filestr   fileplace;
    files_header *fh;
    os_regset    r;
    os_error     *err = NULL;
    int          amount_to_write;
    uint32_t     start_written_to;
    clock_t      t;
    static BOOL  dont_set_dir_info = No;

    *i_am_empty = No;
    *that_finished_a_file = No;

    /*
        no more files to write?
    */
    if ( !files_chain.forwards->forwards )
    {
        *i_am_empty = Yes;

        return NULL;
    }

    fh = chain_link_Wrapper( files_chain.forwards );

    debugmem(( "int_write_a_block to %s\n", fh->destination_filename ));

    /*
        no more buffer to write when there's more file to write?
    */
    if ( fh->objecttype != object_directory &&
        fh->read_to - fh->written_to == 0 &&
        fh->written_to < fh->size )
    {
        *i_am_empty = Yes;

        return NULL;
    }

    start_written_to = fh->written_to;

    debugmem(( "W" ));

    /*
        amount_to_write is lesser of a dest_block_size and the amount buffered of the file
    */
    if ( fh->read_to - fh->written_to > dest_block_size )
    {
        amount_to_write = dest_block_size;
    }
    else
    {
        /* This calculation fits in a signed integer provided dest_block_size < 2G */
        amount_to_write = fh->read_to - fh->written_to;
    }

    while ( !err &&
           ( fh->write_state == write_not_started ||
         fh->write_state == write_f_tried_unlock ||
         fh->write_state == write_f_tried_cdirs ||
         fh->write_state == write_f_tried_both ))
    {
        if ( fh->objecttype == object_directory )
        {
            debugmem(( "D" ));
            /*
                Start up directory
            */
            err = create_directory( fh->destination_filename );

            if ( !err )
                fh->write_state = dont_set_dir_info ?
                            write_adjust_access :
                            write_adjust_info;
        }
        else
        {
            /*
                Start up file (or partition)
            */
            if ( fh->size <= amount_to_write )
            {
                debugmem(( "S" ));
                /*
                    Optimised case - try save
                */
                fileplace.action = OSFile_Save;
                fileplace.name = fh->destination_filename;
                fileplace.loadaddr = fh->reload;
                fileplace.execaddr = fh->execute;
                fileplace.start = (int)(buffer_base_address + buffer_offset + fh->start_of_buffer);
                fileplace.end = fileplace.start + fh->size;

                err = os_file( &fileplace );

                if ( !err )
                {
                    fh->written_to = fh->size;
                    fh->start_of_buffer += fh->size;
                    buffer_bottom += fh->size;

                    fh->write_state = write_adjust_access;
                }
            }
            else
            {
                debugmem(( "c" ));
                /*
                    Sub-optimal case - open, GBPB, close
                */
                err = create_file_dead( fh->destination_filename, fh->size );

                if ( !err )
                {
                    fh->write_state = write_openit;
                }
            }
        }

        if ( err )
        {
            if ( (err->errnum & FileError_Mask) == ErrorNumber_Locked &&
                fh->forceit &&
                fh->write_state != write_f_tried_unlock &&
                fh->write_state != write_f_tried_both )
            {
                /*
                    We haven't tried unlocking yet - give it a go
                */
                fileplace.action = OSFile_WriteAttr;
                fileplace.name = fh->destination_filename;
                fileplace.end = read_attribute | write_attribute;

                os_file( &fileplace );  /* ignore any error back */

                err = NULL;

                if ( fh->write_state == write_not_started )
                    fh->write_state = write_f_tried_unlock;
                else if ( fh->write_state == write_f_tried_cdirs )
                    fh->write_state = write_f_tried_both;
            }
            else if ( ((err->errnum & FileError_Mask) == ErrorNumber_NotFound ||
                   err->errnum == ErrorNumber_CantOpenFile) &&
                   fh->write_state != write_f_tried_cdirs &&
                   fh->write_state != write_f_tried_both )
            {
                /*
                    We haven't tried cdirs yet - give it a go
                */
                err = ensure_file_directories( fh->destination_filename );

                if ( !err )
                {
                    /*
                        no error - try opening/saving again, but don't retry cdirs on fail
                    */
                    if ( fh->write_state == write_not_started )
                        fh->write_state = write_f_tried_cdirs;
                    else if ( fh->write_state == write_f_tried_unlock )
                        fh->write_state = write_f_tried_both;
                }
            }
        }
    }

    if ( !err && fh->write_state == write_openit )
    {
        debugmem(( "O" ));
        /*
            Open it up. The file has been successfully created if we're here, so
            any failures at this point are bad news.
        */
        r.r[0] = open_update | open_nopath | open_nodir | open_mustopen;
        r.r[1] = (int)fh->destination_filename;

        err = os_find( &r );

        if ( !err )
        {
            fh->write_state = write_truncateopen;
            fh->destination_file_handle = r.r[0];
        }
    }

    if ( !err && fh->write_state == write_truncateopen )
    {
        debugmem(( "T" ));
        /*
            Once the file's open set its extent to 0. This
            prevents FileSwitch loading before update on
            blocks of the file.
        */
        r.r[0] = OSArgs_SetEXT;
        r.r[1] = (int)fh->destination_file_handle;
        r.r[2] = 0; /* to 0 */

        err = os_args( &r );

        if ( !err )
        {
            fh->write_state = write_blocks;
        }
    }

    if ( !err && fh->write_state == write_blocks )
    {
        /*
            Write a block out
        */
        gbpbplace.action = OSGBPB_WriteAtGiven;
        gbpbplace.file_handle = fh->destination_file_handle;
        gbpbplace.data_addr = buffer_base_address + buffer_offset + fh->start_of_buffer;
        gbpbplace.number = amount_to_write;
        gbpbplace.seq_point = fh->written_to;

        debugmem(( "int_write_a_block: buf %x + %d [%d-%d]\n", buffer_base_address, buffer_offset,
                                                               buffer_bottom, buffer_top ));
        debugmem(( "int_write_a_block: w(%d,%u->%u)", (int)gbpbplace.data_addr, gbpbplace.number, gbpbplace.seq_point ));

        t = clock();

        err = os_gbpb( &gbpbplace );

        if ( !err )
        {
            if (dest_block_size == amount_to_write)
            {  /* only time full block transfers */
                t = clock() - t;
                if ( timing_accumulating(timing_Writing) )
                { /* accumulating initial timings */
                    assert(dest_block_size == InitialBlockSize);
                    timing_accumulate(timing_Writing, t, dest_block_size);
                }
                else
                {
                    if ( (dest_block_size <= SmallBlockSize)
                      && timing_poorrate(timing_Writing, t, dest_block_size) )
                    { /* if the transfer rate is suffering at this small blocksize,
                       * increase time_quanta to cause the blocksize to grow */
                        if (time_quanta < MaxTimeQuanta) time_quanta *= 2;
                        debugmem(( "int_write_a_block: time_quanta to %d\n", time_quanta ));
                    }
                    if ( t < time_quanta - TimeQuantaHysteresis) dest_block_size = grow( dest_block_size );
                    if ( t > time_quanta + TimeQuantaHysteresis) dest_block_size = shrink( dest_block_size );
                }
            }
            fh->written_to += amount_to_write;
            fh->start_of_buffer += amount_to_write;
            buffer_bottom += amount_to_write;

            if ( fh->written_to >= fh->size )
                fh->write_state = write_closeit;
        }
    }

    if ( !err && fh->write_state == write_closeit )
    {
        debugmem(( "C" ));
        err = close_file( &fh->destination_file_handle );

        /*
            Regardless of whether the close worked, the file will be closed,
            so always move onto adjusting the file's info
        */
        fh->write_state = write_adjust_info;
    }

    if ( !err && fh->write_state == write_adjust_info )
    {
        debugmem(( "I" ));
        /*
            Always adjust the info as it's almost always wrong
        */
        err = write_catalogue_information(
              fh->destination_filename,
              fh->objecttype,
              fh->reload,
              fh->execute,
              fh->attributes );

        if ( err && fh->objecttype == object_directory)
        {
            /* Some FS's can't do this for a directory - back
               off to just doing the access permission.
             */
            err = NULL;
            dont_set_dir_info = Yes;
            fh->write_state = write_adjust_access;
        }
        else if ( !err )
            fh->write_state = write_all_done;
    }

    if ( !err && fh->write_state == write_adjust_access )
    {
        debugmem(( "A" ));
        /*
            Only adjust attributes if they're non-default ones
        */
        err = write_attributes(
              fh->destination_filename,
              fh->attributes );

        if ( !err )
            fh->write_state = write_all_done;
    }

    if ( !err && fh->write_state == write_all_done )
    {
        *that_finished_a_file = Yes;
        #ifdef USE_PROGRESS_BAR
        *progress = fh->write_progress;
        #else
        IGNORE(progress);
        #endif

        remove_file_from_chain();
    }
    #ifdef USE_PROGRESS_BAR
    else
    {
        uint64_t p;
        uint32_t b;

        if ( err ) return err;

        b = fh->written_to - start_written_to; /* bytes written this time */
        p = (fh->total_progress * (uint64_t)b) / fh->size;
        
        fh->write_progress -= (uint32_t) p;
        *progress = (uint32_t) p;
        
        debugmem(( "partial write: %u bytes / %u = %08x progress\n", b, fh->size, *progress ));
    }
    #endif

    debugmem(( "X\n" ));

    return err;
}


os_error *write_a_block( BOOL *i_am_empty, BOOL *that_finished_a_file, uint32_t *progress )
{
    os_error *err = int_write_a_block( i_am_empty, that_finished_a_file, progress );

    if ( *i_am_empty )
    {
        buffer_end += buffer_offset;
        buffer_offset = buffer_bottom = buffer_top = 0;
    }

    return err;
}

void skip_file_write( void )
{
    if ( files_chain.forwards->forwards )
    {
        skip_file( chain_link_Wrapper( files_chain.forwards ));
    }
}

char *next_file_to_be_written( void )
{
    files_header *fh;

    if ( files_chain.forwards->forwards )
    {
        fh = chain_link_Wrapper( files_chain.forwards );

        return fh->destination_filename;
    }
    else
    {
        return NULL;
    }
}

char *next_file_to_be_read( void )
{
    files_header *fh = next_fh_to_read();

    if ( fh != NULL )
        return fh->source_filename;
    else
        return NULL;
}

void restart_file_read( void )
{
    files_header *fh = next_fh_to_read();

    debugmem(( "restart_file_read: fh=&08X\n", (int)fh ));

    if ( fh != NULL )
    {
        ensure_files_closed( fh );
        buffer_top -= fh->read_to;
        if ( buffer_top < 0 ) buffer_bottom = buffer_top = buffer_offset = 0;
        fh->read_to = 0;
        fh->written_to = 0;
        fh->write_state = write_not_started;
    }
}

void restart_file_write( void )
{
    files_header *fh = chain_link_Wrapper( files_chain.forwards );

    debugmem(( "restart_file_write: fh=&08X\n", (int)fh ));

    if ( fh != NULL )
    {
        /* Only restart file if we still have all of its contents so far.
         * If we don't then we can't just read from the start because we might
         * overwrite another file's data so just do nothing (== retry).
         */
        int file_start = fh->start_of_buffer - fh->written_to;
        if ( file_start >= 0 )
        {
            ensure_files_closed( fh );
            fh->start_of_buffer = file_start;
            buffer_bottom -= fh->written_to;
            fh->written_to = 0;
            fh->write_state = write_not_started;
            debugmem(( "restart_file_write: start_of_buffer=%08X, buffer_bottom=%08X\n", fh->start_of_buffer, buffer_bottom ));
        }
    }
}

uint32_t bytes_left_to_read( void )
{
    files_header *fh = next_fh_to_read();

    if ( fh )
    {
        return fh->size - fh->read_to;
    }
    else
    {
        return 0;
    }
}

uint32_t bytes_left_to_write( void )
{
    files_header *fh;

    if ( files_chain.forwards->forwards )
    {
        fh = chain_link_Wrapper( files_chain.forwards );

        return fh->size - fh->written_to;
    }
    else
    {
        return 0;
    }
}

void copy_go_faster( BOOL do_it )
{
    if ( do_it )
    {
        /*
            Go faster
        */

        time_quanta = MaxTimeQuanta;      /* centi-seconds */

        minimum_block_size = 15*1024; /* bytes: optimised for econet */

        if ( src_block_size < minimum_block_size )
            src_block_size = minimum_block_size;
        if ( dest_block_size < minimum_block_size )
            dest_block_size = minimum_block_size;
    }
    else
    {
        /*
            Go slower
        */

        time_quanta = NominalTimeQuanta;

        minimum_block_size = 512;
    }
}
