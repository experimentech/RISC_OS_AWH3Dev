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

/* time.c: ANSI draft (X3J11 Oct 86) section 4.12 code */
/* Copyright (C) Codemist Ltd, 1988 */
/* version 0.02a */

#include <time.h>
#include <stdio.h>
#include <string.h>
#include <locale.h>

#include "kernel.h"
#include "territory.h"
#include "swis.h"

/* Array indices corresponding to the LC macros above */
#define N_LC_COLLATE  0
#define N_LC_CTYPE    1
#define N_LC_MONETARY 2
#define N_LC_NUMERIC  3
#define N_LC_TIME     4
#define N_LC_ALL      5

extern int __locales[5];

/* NB strftime() is in locale.c since it seems VERY locale-dependent      */

/* In NorCroft C time() yields the unix result of an unsigned int holding */
/* seconds since 1 Jan 1970.                                              */
/* clock() returns an unsigned int with ticks of cpu time.                */

/* N.B. clock() and time() are defined in armsys.c                        */

static const int monlen[13] = { 31,29,31,30,31,30,31,31,30,31,30,31,0x40000000 };

double difftime(time_t time1, time_t time0)
{   return (double)time1 - (double)time0;
}


static int tm_carry(int *a, int b, int q)
{   /* *a = (*a + b) % q, return (*a + b)/q.  Care with overflow.          */
    int aa = *a;
    int hi = (aa >> 16) + (b >> 16);    /* NB signed shift arithmetic here */
    int lo = (aa & 0xffff) + (b & 0xffff);
    lo += (hi % q) << 16;
    hi = hi / q;
    aa = lo % q;
    lo = lo / q;
    while (aa < 0)
    {   aa += q;
        lo -= 1;
    }
    *a = aa;        /* remainder is positive here */
    return (hi << 16) + lo;
}

static struct tm *time_to_tm(struct tm *_tms, time_t t, int dst)
{
    int i = 0, yr;

    /* unix time already in seconds (since 1-Jan-1970) ... */
    _tms->tm_sec = t % 60; t /= 60;
    _tms->tm_min = t % 60; t /= 60;
    _tms->tm_hour = t % 24; t /= 24;
/* The next line converts *timer arg into days since 1-Jan-1900 from t which
   now holds days since 1-Jan-1970.  Now there are really only 17 leap years
   in this range 04,08,...,68 but we use 18 so that we do not have to do
   special case code for 1900 which was not a leap year.  Of course this
   cannot give problems as pre-1970 times are not representable in *timer. */
    t += 70*365 + 18;
    _tms->tm_wday = t % 7;               /* it just happens to be so */
    yr = 4 * (t / (365*4+1)); t %= (365*4+1);
    if (t >= 366) yr += (t-1) / 365, t = (t-1) % 365;
    _tms->tm_year = yr; /* Add in magic timebase */
    _tms->tm_yday = t;
    if ((yr & 3) != 0 && t >= 31+28) t++;
    while (t >= monlen[i]) t -= monlen[i++];
    _tms->tm_mday = t+1;
    _tms->tm_mon = i;
    _tms->tm_isdst = dst;
    return _tms;
}

time_t mktime(struct tm *timeptr)
{   /* ISO9899 7.23.2.3 (2) says that the components may take ANY values   */
    /* and that somehow mktime() should normalise these into a form that   */
    /* is in range.  This leaves the question - what is month -9 or +123?  */
    /* the code below resolves by normalising from seconds upwards,        */
    /* propagating any carries up to the year component then checking for  */
    /* overflow.                                                           */
    /* Also note that struct tm is allowed to have signed values in it for */
    /* the purposes of this function even though normalized times all have */
    /* just positive entries.                                              */
    time_t t;
    int w, v, yday, offset, territory;
    int sec = timeptr->tm_sec;
    int min = timeptr->tm_min;
    int hour = timeptr->tm_hour;
    int mday = timeptr->tm_mday;
    int mon = timeptr->tm_mon;
    int year = timeptr->tm_year;
    int quadyear = 0;
    _kernel_swi_regs r;

    /* The next line is a simple test that detects some gross overflows    */
    if (year > 0x40000000 || year < -0x40000000) return (time_t)-1;

    /* Work out what the timezone/DST correction is */
    territory = __locales[N_LC_TIME];
    if (!territory) {
        r.r[0] = -1; /* If C locale use current configured territory */
    } else {
        r.r[0] = TERRITORY_EXTRACT(territory);
        r.r[1] = TERRITORY_TZ_EXTRACT(territory);
        r.r[4] = TERRITORY_TZ_API_EXT; /* If not supported, never mind */
    }
    if (_kernel_swi(Territory_ReadTimeZones, &r, &r) == NULL) {
        offset = (timeptr->tm_isdst > 0) ? r.r[3] : r.r[2];
        offset = offset / 100; /* centiseconds -> seconds */
    } else {
        offset = 0;
    }

    /* we really do have to propagate carries up it seems                  */
    /* careful about overflow for divide, but not carry add.               */
    w = tm_carry(&sec,-offset,60); /* leaves 0 <= sec < 60  */
    w = tm_carry(&min,w,60);       /* leaves 0 <= min < 60  */
    w = tm_carry(&hour,w,24);      /* leaves 0 <= hour < 24 */
    quadyear = tm_carry(&mday,w - 1,(4*365+1));  /* 0 <= mday < 4 years    */

    /* The next line can not possibly result in year overflowing since the */
    /* initial value was checked earlier and the month can only cause a    */
    /* carry of size up to MAXINT/12 with quadyear limited to MAXINT/365.  */
    year += quadyear*4 + tm_carry(&mon,0,12);
    /* at last the mday is in 0..4*365 and the mon in 0..11                */

#define notleapyear(year) (((year) & 3)!=0)
    /* Note that 1900 is not in the range of valid dates and so I will     */
    /* fudge the issue about it not being a leap year.                     */

    while (mday >= monlen[mon])
    {   mday -= monlen[mon++];
        if (mon==2 && notleapyear(year)) mday++;
        else if (mon == 12) mon = 0, year++;
    }
    if (mon==1 && mday==28 && notleapyear(year)) mon++, mday=0;

#define YEARS (0x7fffffff/60/60/24/365 + 1)
    if (year < 70 || year > 70+2*YEARS) return (time_t)-1;
#undef YEARS

    yday = mday;
    {   int i;
        for (i = 0; i<mon; i++) yday += monlen[i];
    }
    if (mon > 1 && notleapyear(year)) yday--;

    v = (365*4+1)*(year/4) + 365*(year & 3) + yday;
    if (!notleapyear(year)) v--;
    /* v is now the number of days since 1 Jan 1900, and I have subtracted */
    /* a sly 1 to adjust for 1900 not being a leap year.                   */

#undef notleapyear

    /* Adjust for a base at 1 Jan 1970 which is 17 leap years since 1900   */

#define DAYS ((70*365)+17)
    t = min + 60*(hour + 24*(v - DAYS));
#undef DAYS
    {   int thi = ((int)t >> 16)*60;
        int tlo = ((int)t & 0xffff)*60 + sec;
        thi += (tlo >> 16) & 0xffff;
        t = (time_t)((thi << 16) | (tlo & 0xffff));
        if ((thi & 0xffff0000) != 0) return (time_t)-1;
    }

    /* Update the local time block by reapplying timezone/DST              */
    {   long long sum;
        sum = t + (long long)offset;
        if ((time_t)sum != sum) return (time_t)-1;
        time_to_tm(timeptr, (time_t)sum, timeptr->tm_isdst);
    }

    return t;
    /* Now I know why Unix didn't have this                                */
}

char *asctime(const struct tm *timeptr)
{   static char _timebuf[26+(8+3*9+7)];  /* slop in case illegal args */
    sprintf(_timebuf, "%.3s %.3s%3d %.2d:%.2d:%.2d %d\n",
       "SunMonTueWedThuFriSat" + (timeptr -> tm_wday)*3,
       "JanFebMarAprMayJunJulAugSepOctNovDecBad" + (timeptr -> tm_mon)*3,
       timeptr -> tm_mday,
       timeptr -> tm_hour, timeptr -> tm_min, timeptr -> tm_sec,
       timeptr -> tm_year + 1900);
    return _timebuf;
}

char *ctime(const time_t *timer)
{   return asctime(localtime(timer));
}

struct tm *gmtime(const time_t *timer)
{
    static struct tm _tms;
    time_t t;

    t = *timer;
    if (t == (time_t)-1) {
        memset(&_tms, 0, sizeof(_tms));
        _tms.tm_mday = 1; /* 1st day of 1900 */
        return &_tms;
    }

    return time_to_tm(&_tms, t, 0); /* Gregorian calendar, no DST */
}

struct tm *localtime(const time_t *timer)
{
    time_t t;
    static struct tm _tms;
    int dst;
    int territory;
    int v;
    _kernel_swi_regs r;

    t = *timer;
    if (t == (time_t)-1) {
        memset(&_tms, 0, sizeof(_tms));
        _tms.tm_mday = 1; /* 1st day of 1900 */
        return &_tms;
    }

    /* Read CMOS for DST flag in bit 7 */
    dst = -1;
    v = _kernel_osbyte(161, 220 /* AlarmAndTimeCMOS */, 0);
    if (v >= 0)
        dst = v & 0x8000;

    territory = __locales[N_LC_TIME];
    if (!territory) {
        /* C locale uses currently configured offset */
        if (_kernel_swi(Territory_ReadCurrentTimeZone, &r, &r) == NULL) {
            t += r.r[1] / 100; /* centiseconds -> seconds */
        }
    } else {
        /* Specific locale */
        r.r[0] = TERRITORY_EXTRACT(territory);
        r.r[1] = TERRITORY_TZ_EXTRACT(territory);
        r.r[4] = TERRITORY_TZ_API_EXT; /* If not supported, never mind */
        if (_kernel_swi(Territory_ReadTimeZones, &r, &r) == NULL) {
            v = (dst == 0x8000) ? r.r[3] : r.r[2];
            t += v / 100; /* centiseconds -> seconds */
        }
    }

    /* Already corrected for locale, so just need to mangle it */
    /* into a suitable structure                               */
    return time_to_tm(&_tms, t, dst);
}

/* end of time.c */
