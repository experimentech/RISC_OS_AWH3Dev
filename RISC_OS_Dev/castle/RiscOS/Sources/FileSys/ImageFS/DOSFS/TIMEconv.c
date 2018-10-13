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
/*> c.TIMEconv <*/
/*---------------------------------------------------------------------------*/
/* RISC OS time conversion functions                        (c) 1988 JGSmith */
/*---------------------------------------------------------------------------*/

#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include "kernel.h"
#include "swis.h"
#include "DebugLib/DebugLib.h"
#include "Global/FileTypes.h"
#include "Global/OSWords.h"

#include "DOSFS.h"
#include "TIMEconv.h"
#include "MsgTrans.h"
#include "ADFSshape.h"

/*---------------------------------------------------------------------------*/

static void addoffset(word value,word *lo4bytes,word *hi1byte)
{
 word old_lo4bytes = *lo4bytes ;

 *lo4bytes += value ;

 if (*lo4bytes < old_lo4bytes) /* then a carry must have occured */
  *hi1byte += 1 ;

 return ;
}

/*---------------------------------------------------------------------------*/

static void addleapday(word *lo4bytes,word *hi1byte,word yearLO,word yearHI)
{
 word value = ticksday ;

 if ((yearLO & 0x03) == 0) /* multiple of 4 */
  {
   if (yearLO != 0)        /* multiple of 100 */
    {
     addoffset(value,lo4bytes,hi1byte) ;
     return ;
    }

   if ((yearHI & 0x03) == 0) /* multiple of 400 */
    {
     addoffset(value,lo4bytes,hi1byte) ;
     return ;
    }
  }

 return ;
}

/*---------------------------------------------------------------------------*/
/* I hate having constants in the source... but the  pre-processor will not
 * be able to generate this one
 */
#define to1970 INT64_C(0x336E996A00)
#define to1980 INT64_C(0x3AC7524200)

/*---------------------------------------------------------------------------*/

static int BCDto5byte(BCDtime *intime,time5byte *outtime)
{
 byte standardmonthlens[12] = {
                               31, /* Jan */
                               28, /* Feb */
                               31, /* Mar */
                               30, /* Apr */
                               31, /* May */
                               30, /* Jun */
                               31, /* Jul */
                               31, /* Aug */
                               30, /* Sep */
                               31, /* Oct */
                               30, /* Nov */
                               31, /* Dec */
                              } ;
 word standardmonths[13] ; /* accumulative total of csec offsets for months
                             * calculated at run-time (month 13 should be
                             * identical to the "ticksyear" definition)
                             */
 int    yHI = (intime->year / 100) ;
 int    yLO = (intime->year % 100) ;
 int    months = (intime->month) ;
 int    days = (intime->day) ;
 int    hours = (intime->hour) ;
 int    mins = (intime->minutes) ;
 int    secs = (intime->seconds) ;
 int    csecs = (intime->centiseconds) ;
 word *centiseconds = &(outtime->lo) ;
 word *hibyte = &(outtime->hi) ;

 word value = 0 ; /* temporary store for centisecond increment */
 int   loop ;

 *centiseconds = csecs ;
 *hibyte = 0 ;

 for (loop = 1; (loop < 13); loop++)
  {
   standardmonths[loop - 1] = value ;
   value += (standardmonthlens[loop - 1] * ticksday) ;
  }
 standardmonths[loop - 1] = value ;

 if (standardmonths[loop - 1] != ticksyear)
  {
   dprintf(("", "fatal run-time error: year centi-second total mismatch\n"));
   return(-1) ;
  }

 if (yHI < 19)
  {
   dprintf(("", "BCDto5byte: year less than 1900 (invalid)\n"));
   return(-1) ;
  }

 if (months >= 3) /* have we passed leap day in this year */
  addleapday(centiseconds,hibyte,yLO,yHI) ; /* add day if leap year */

 while (yHI >= 19)   /* don't go earlier than 1900 */
  {
   if (--yLO < 0)
    {
     yLO = 99 ;
     yHI-- ;
    }

   if (yHI >= 19)   /* don't go earlier than 1900 */
    {
     addleapday(centiseconds,hibyte,yLO,yHI) ; /* add day if leap */
     addoffset(ticksyear,centiseconds,hibyte) ;      /* add standard year */
    }
  }

 /* deal with months */
 addoffset(standardmonths[months - 1],centiseconds,hibyte) ;

 /* deal with days */
 if (days != 0)
  while (--days != 0)
   addoffset(ticksday,centiseconds,hibyte) ;

 /* deal with hours */
 while (--hours >= 0)
  addoffset(tickshour,centiseconds,hibyte) ;

 /* deal with minutes */
 while (--mins >= 0)
  addoffset(ticksmin,centiseconds,hibyte) ;

 /* deal with seconds */
 while (--secs >= 0)
  addoffset(tickssec,centiseconds,hibyte) ;

#ifdef TIMEWORK
 dprintf(("", "BCDto5byte: &%02x%08x\n",*hibyte,*centiseconds));
#endif

 return(0) ;
}

static int convert5bytetoBCD(time5byte *intime,BCDtime *outtime)
{
 /* convert the 5byte centisecond time from 00:00:00 1 Jan 1900 into BCD */
 /* NOTE: this can be done by calculating the centi-second time from
  *       00:00:00 1 Jan 1970 (i.e. the UNIX representation) and using the
  *       library function "struct tm *gmtime(time_t *timer)" to convert
  *       to a BCD form...
  *
  *       "00:00:00 1 Jan 1900" -> "00:00:00 1 Jan 1970" = &336E996A00
  */
 time_t     since1970 ;
 struct tm *unixtime ;
 int64_t   delta ;
 int64_t   quotient ;

#ifdef TIMEWORK
 dprintf(("", "convert5bytetoBCD: now  &%02x%08x\n",intime->hi,intime->lo));
 dprintf(("", "convert5bytetoBCD: 1970 &%010"PRIx64"\n",to1970));
#endif

 /* calculate centi-second difference (limit it at "00:00:00 1 Jan 1970"
  * to ensure it can be represented as a DOS time) */
 delta = ((int64_t) intime->hi << 32) + intime->lo - to1970 ;
 if (delta < to1980 - to1970)
   delta = to1980 - to1970;

#ifdef TIMEWORK
 dprintf(("", "convert5bytetoBCD: delta &%010"PRIx64"\n",delta));
#endif

 /* the UNIX time is only a 32bit seconds (as opposed to 40bit centi-seconds)
  * quantity
  */
 /* Make sure we always round up. */
 quotient = (delta + (tickssec - 1)) / tickssec;

#ifdef TIMEWORK
 dprintf(("", "convert5bytetoBCD: delta (as secs) &%08x\n",(time_t) quotient));
#endif

 /* this gives us the number of seconds since 00:00:00 1 Jan 1970 */

 since1970 = (time_t) quotient ; /* largest possible for the moment */

 unixtime = gmtime(&since1970) ;

 /* transfer the data from the library structure */
 outtime->year = unixtime->tm_year + 1900 ;
 outtime->month = unixtime->tm_mon + 1 ;
 outtime->day = unixtime->tm_mday;
 outtime->hour = unixtime->tm_hour ;
 outtime->minutes = unixtime->tm_min ;
 outtime->seconds = unixtime->tm_sec ;
 outtime->centiseconds = 0 ;

 /* completed successfully */
 return(0) ;
}

/*---------------------------------------------------------------------------*/
/* time and date conversions:
 *  MSDOStoRISCOS     : convert MSDOS date & time to RISC OS date/time
 *  MSDOStoSTRING     : convert MSDOS date & time to RISC OS style string (unused)
 *  RISCOStoTIME      : convert RISC OS date/time to MSDOS TIME
 *  RISCOStoDATE      : convert RISC OS date/time to MSDOS DATE
 */

void MSDOStoRISCOS(word MStime,word MSdate,time5byte *outtime)
{
 /* this generates RISC OS style LOAD and EXEC addresses containing the
  * given MSDOS time/date
  * The RISC OS file type is set to "DOS"
  *
  * load address: = &FFFtttdd
  * exec address: = &dddddddd
  * dddddddddd is the (5byte) centisecond time from 00:00:00 on 1st Jan 1900
  *
  * if an invalid time is given, then the default time (above) is returned
  */
 BCDtime otime ;

 otime.year = (((MSdate & year_mask) >> year_shift) + 1980) ;
 otime.month = ((MSdate & mon_mask) >> mon_shift) ;
 otime.day = ((MSdate & day_mask) >> day_shift) ;
 otime.hour = ((MStime & hour_mask) >> hour_shift) ;
 otime.minutes = ((MStime & min_mask) >> min_shift) ;
 otime.seconds = (((MStime & sec_mask) >> sec_shift) * 2) ;
 otime.centiseconds = 0 ;

 if ((BCDto5byte(&otime,outtime) < 0) || (MStime==0 && MSdate==0))
  {
  outtime->hi = ((ADFStimestamp | 0x00) & ~ADFStypemask) ;
  outtime->lo = 0x00000000 ;
  }
 else
  outtime->hi = ((ADFStimestamp | (outtime->hi & 0xFF)) & ~ADFStypemask) ;

 /* and add in the DOS file-type identifier */
 outtime->hi |= (FileType_MSDOS << ADFStypeshift) ;

 return ;
}

/*---------------------------------------------------------------------------*/
#if 0 /* not used at the moment */
char *MSDOStoSTRING(word MSDOStime,word MSDOSdate)
{
 /* convert time/date to standard time string */
 time5byte         ROStime ;
 char             *buffer ;
 _kernel_swi_regs  reglist ;
 _kernel_oserror  *rerror ;

 /* The function prototype could be changed to allow the buffer to be
  * passed into the function. Thus saving the overhead of calling malloc
  * and free for each use of MSDOStoSTRING. At the moment however there is
  * only one user of this function.
  */

 if ((buffer = malloc(MaxString)) == NULL)
  return(NULL) ;

 MSDOStoRISCOS(MSDOStime,MSDOSdate,&ROStime) ;

 reglist.r[0] = (word)&ROStime ;
 reglist.r[1] = (word)buffer ;
 reglist.r[2] = (MaxString - 1) ;
 if ((rerror = _kernel_swi(OS_ConvertStandardDateAndTime,&reglist,&reglist)) != NULL)
 {
  free(buffer) ;
  return(NULL) ;
 }

 return(buffer) ;
}
#endif
/*---------------------------------------------------------------------------*/

word RISCOStoTIME(time5byte *ROStime)
{
 /* convert RISC OS 5 byte time/date into the 16bit MSDOS time */
 word   DOStime ;
 BCDtime fulltime ;

 convert5bytetoBCD(ROStime,&fulltime) ;

 /* NOTE: this rounds the seconds up to the next 2second boundary (not down) */
 DOStime = ((fulltime.hour << hour_shift) & hour_mask) | ((fulltime.minutes << min_shift) & min_mask) | ((((fulltime.seconds + 1) >> 1) << sec_shift) & sec_mask) ;

 return(DOStime) ;
}

/*---------------------------------------------------------------------------*/

word RISCOStoDATE(time5byte *ROStime)
{
 /* convert RISC OS 5 byte time/date into the 16bit MSDOS date */
 word   DOSdate ;
 BCDtime fulltime ;

 convert5bytetoBCD(ROStime,&fulltime) ;

 DOSdate = (((fulltime.year - 1980) << year_shift) & year_mask) | ((fulltime.month << mon_shift) & mon_mask) | ((fulltime.day << day_shift) & day_mask) ;

 return(DOSdate) ;
}

/*---------------------------------------------------------------------------*/
/* return RISC OS centi-second time (based at 1 Jan 1900, UTC) */

time5byte *get_RISCOS_TIME(time5byte *timebuff)
{
 time5byte        *newTIME ;
 _kernel_swi_regs  reglist ;

 newTIME = ((timebuff == NULL) ? (time5byte *)malloc(sizeof(time5byte)) : timebuff) ;

 /* specify the format we wish to read the clock in */
 newTIME->lo = OWReadRTC_5ByteInt ;

 reglist.r[0] = OsWord_ReadRealTimeClock ;
 reglist.r[1] = (word)newTIME ;

 _kernel_swi(OS_Word,&reglist,&reglist) ;

 /* remove any extra bytes */
 newTIME->hi = (newTIME->hi & 0xFF) ;

 return(newTIME) ;
}

/*---------------------------------------------------------------------------*/
/*> c.TIMEconv <*/
