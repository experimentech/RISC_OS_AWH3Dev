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

/* locale.c: ANSI draft (X3J11 Oct 86) library header, section 4.3 */
/* Copyright (C) Codemist Ltd., 1988 */
/* version 0.01 */

#include <locale.h>
#include <stddef.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>  /* multibyte characters & strings */
#include <limits.h>  /* for CHAR_MAX */

#include "hostsys.h"
#include "kernel.h"
#include "territory.h"
#include "swis.h"

/* #define LC_COLLATE  1
   #define LC_CTYPE    2
   #define LC_MONETARY 4
   #define LC_NUMERIC  8
   #define LC_TIME    16
   #define LC_ALL     31
*/

/* Array indices corresponding to the LC macros above */
#define N_LC_COLLATE  0
#define N_LC_CTYPE    1
#define N_LC_MONETARY 2
#define N_LC_NUMERIC  3
#define N_LC_TIME     4
#define N_LC_MAX      5

extern int _sprintf_lf(char *buff, const char *fmt, ...);

extern int __locales[N_LC_MAX];
int __locales[N_LC_MAX] = {0, 0, 0, 0, 0};

/* lc initialised to C for default */
static struct lconv lc =
{".", "", "", "", "", "", "", "", "", "",
 CHAR_MAX,CHAR_MAX,CHAR_MAX,CHAR_MAX,CHAR_MAX,CHAR_MAX,CHAR_MAX,CHAR_MAX};

/* Tables used by strftime()                                             */

static char *abbrweek[]  = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
static char *fullweek[]  = { "Sunday", "Monday", "Tuesday", "Wednesday",
                             "Thursday", "Friday", "Saturday" };
static char *abbrmonth[] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
static char *fullmonth[] = { "January", "February", "March", "April",
                             "May", "June", "July", "August",
                             "September", "October", "November", "December" };
static char *ampmname[]  = { "AM", "PM" };

extern void _set_ctype(int territory);

extern void _set_strcoll(int territory);

static void setlocales(int category, int *values)
{
    int j;

    for (j = 0; category != 0; category >>= 1, ++j) {
      if (category & 1) __locales[j] = values[j];
    }
}

static int getsymbol(int territory, int idx, int def)
{
  _kernel_swi_regs r;

  if (!territory)
    return def;
  r.r[0] = territory;
  r.r[1] = idx;
  if (!_kernel_swi(Territory_ReadSymbols, &r, &r))
    return r.r[0];
  return def;
}

static void _set_numeric(int territory)
{
    decimal_point = (char *)getsymbol(territory, 0, (int)".");
}

static void setlconv(int category, int *values)
{
  int territory;

  if (category & LC_MONETARY) {
    territory = values[N_LC_MONETARY];
    lc.int_curr_symbol =
        (char *)getsymbol(territory, TERRITORY_INT_CURR_SYMBOL, (int)"");
    lc.currency_symbol =
        (char *)getsymbol(territory, TERRITORY_CURRENCY_SYMBOL, (int)"");
    lc.mon_decimal_point =
        (char *)getsymbol(territory, TERRITORY_MON_DECIMAL_POINT, (int)"");
    lc.mon_thousands_sep =
        (char *)getsymbol(territory, TERRITORY_MON_THOUSANDS_SEP, (int)"");
    lc.mon_grouping =
        (char *)getsymbol(territory, TERRITORY_MON_GROUPING, (int)"");
    lc.positive_sign =
        (char *)getsymbol(territory, TERRITORY_POSITIVE_SIGN, (int)"");
    lc.negative_sign =
        (char *)getsymbol(territory, TERRITORY_NEGATIVE_SIGN, (int)"");
    lc.int_frac_digits =
        getsymbol(territory, TERRITORY_INT_FRAC_DIGITS, CHAR_MAX);
    lc.frac_digits =
        getsymbol(territory, TERRITORY_FRAC_DIGITS, CHAR_MAX);
    lc.p_cs_precedes =
        getsymbol(territory, TERRITORY_P_CS_PRECEDES, CHAR_MAX);
    lc.p_sep_by_space =
        getsymbol(territory, TERRITORY_P_SEP_BY_SPACE, CHAR_MAX);
    lc.n_cs_precedes =
        getsymbol(territory, TERRITORY_N_CS_PRECEDES, CHAR_MAX);
    lc.n_sep_by_space =
        getsymbol(territory, TERRITORY_N_SEP_BY_SPACE, CHAR_MAX);
    lc.p_sign_posn =
        getsymbol(territory, TERRITORY_P_SIGN_POSN, CHAR_MAX);
    lc.n_sign_posn =
        getsymbol(territory, TERRITORY_N_SIGN_POSN, CHAR_MAX);
  }
  if (category & LC_NUMERIC) {
    territory = values[N_LC_NUMERIC];
    lc.decimal_point =
        (char *)getsymbol(territory, TERRITORY_DECIMAL_POINT, (int)".");
    lc.thousands_sep =
        (char *)getsymbol(territory, TERRITORY_THOUSANDS_SEP, (int)"");
    lc.grouping =
        (char *)getsymbol(territory, TERRITORY_GROUPING, (int)"");
  }
}

#define LC_STR_SIZE 40

char *setlocale(int category, const char *locale)
{
    static char lc_str[LC_STR_SIZE];
    int tmp_locales[N_LC_MAX] = {0, 0, 0, 0, 0};
    _kernel_swi_regs r;
    char *s;
    int i, n, tz;

    /* I expect the category to be a bit-map - complain if out of range  */
    if (((unsigned)category > LC_ALL) || (category == 0))
      /* no can do... */
      return NULL;
    if (locale == NULL) {
      /* get locale */
      _sprintf_lf(lc_str, "=%d,%d,%d,%d,%d",
                  __locales[0], __locales[1], __locales[2], __locales[3], __locales[4]);
      return lc_str;
    } else {
      /* set locale */
      if (strcmp(locale, "ISO8859-1") == 0)
        locale = "UK";
      if (*locale == '=') {
        /* ISO9899 7.11.1.1 Parse the string as given by get locale */
        s = (char *)(locale + 1);
        for (i = 0; i < N_LC_MAX; i++) {
            n = 0;
            while (*s >= '0' && *s <= '9') {
                n = n * 10 + *s - '0';
                s++;
            }
            if (*s == ',') s++;
            tmp_locales[i] = n;
        }
      } else {
        if (*locale == 0 || strcmp(locale, "C") == 0) {
          /* ISO9899 7.11.1.1 Use "" for current locale, "C" for minimal locale */
          n = 0; tz = 0;
          if (!*locale && (_kernel_swi(Territory_Number, &r, &r) == NULL)) {
            n = r.r[0];
            r.r[1] = (int)lc_str;
            r.r[2] = LC_STR_SIZE;
            if (_kernel_swi(Territory_NumberToName, &r, &r) == NULL)
              locale = lc_str;
          }
        } else {
          /* Platform specific, permit the territory name and (optional) standard timezone */
          strncpy(lc_str, locale, LC_STR_SIZE - 1);
          s = strchr(lc_str, '/'); /* eg. "USA/PST" */
          if (s != NULL) *s = 0;
          r.r[0] = TERRITORY_UK;   /* Names must be in english */
          r.r[1] = (int)lc_str;
          if ((_kernel_swi(Territory_NameToNumber, &r, &r) != NULL) || (r.r[0] == 0))
            return NULL;           /* Don't know that name */
          n = r.r[0]; tz = 0;
          if (_kernel_swi(Territory_WriteDirection, &r, &r) != NULL)
            return NULL;           /* Check it's loaded (avoids Territory_Exists Z flag faff) */
          if (s != NULL) {
            locale = lc_str;       /* eg. "USA" */
            s++;                   /* eg. "PST" */
            if (*s) {              /* Null timezone taken as 0th */
              while (1) {
                r.r[0] = n;
                r.r[1] = tz;
                r.r[4] = (int)TERRITORY_TZ_API_EXT;
                if (_kernel_swi(Territory_ReadTimeZones, &r, &r) != NULL)
                  return NULL;     /* No more timezones to match */
                if (strcmp((char *)r.r[0], s) == 0)
                  break;           /* Exact match */
                if (r.r[4])
                  break;           /* Extended API not supported, use 0th */
                tz++;
              }
            }
          }
        }
        for (i = 0; i < N_LC_MAX; i++) {
          if (i == N_LC_TIME)
            tmp_locales[i] = TERRITORY_ENCODE(n, tz); /* Packed format */
          else
            tmp_locales[i] = n;
        }
      }
      setlocales(category, tmp_locales);
      setlconv(category, tmp_locales);
      if (category & LC_CTYPE)
        _set_ctype(tmp_locales[N_LC_CTYPE]);
      if (category & LC_COLLATE)
        _set_strcoll(tmp_locales[N_LC_COLLATE]);
      if (category & LC_NUMERIC)
        _set_numeric(tmp_locales[N_LC_NUMERIC]);
    }
    return (char *)locale;
}

struct lconv *localeconv(void)
{
  return &lc;
}

static int findweek(int yday, int startday, int today)
{
    int days_into_this_week = today - startday;
    int last_weekstart;
    if (days_into_this_week < 0) days_into_this_week += 7;
    last_weekstart = yday - days_into_this_week;
    if (last_weekstart <= 0) return 0;
    return last_weekstart/7 + 1;
}

#define CDT_BUFFSIZE 256

static char *getterritorytimeinfo(int territory, const struct tm *tt, char *fmt, char *buff, int swi)
{
    _kernel_swi_regs r;
    int  tm_block[7];
    long long utc_block;

    /* The tm struct came from either gmtime() or localtime() and therefore already     */
    /* has any timezone and daylight saving applied to it as implied by the choice of   */
    /* the 2 functions called. Therefore it needs converting as though it's UTC         */
    /* already. Note that Territory_ConvertOrdinalsToTime applies its own correction    */
    /* based on the active territory (not necessarily the same as the locale set for    */
    /* our client) and since there isn't a UTC equivalent of that SWI until             */
    /* Territory_ConvertTimeFormats comes along (which might not be available on the    */
    /* host OS) we must do the opposite correction to the calculated time. Sigh.        */
    tm_block[0] = 0;
    tm_block[1] = tt->tm_sec;
    tm_block[2] = tt->tm_min;
    tm_block[3] = tt->tm_hour;
    tm_block[4] = tt->tm_mday;
    tm_block[5] = tt->tm_mon + 1;
    tm_block[6] = tt->tm_year + 1900;
    r.r[0] = TERRITORY_UK;
    r.r[1] = (int)&utc_block;
    r.r[2] = (int)tm_block;
    if (_kernel_swi(Territory_ConvertOrdinalsToTime, &r, &r) != NULL)
        return "???";
    if (_kernel_swi(Territory_ReadCurrentTimeZone, &r, &r) != NULL)
        return "???";
    utc_block = utc_block + r.r[1];

    r.r[0] = TERRITORY_EXTRACT(territory);
    r.r[1] = (int)&utc_block;
    r.r[2] = (int)buff;
    r.r[3] = CDT_BUFFSIZE | (1<<30) | (1<<31); /* No DST, R5 cs offset */
    r.r[4] = (int)fmt;
    r.r[5] = 0;
    if (_kernel_swi(swi, &r, &r) != NULL)
        return "???";
    return buff;
}

static char *gettimeinfo(int territory, const struct tm *tt, char *fmt, char *buff)
{
    return getterritorytimeinfo(territory, tt, fmt, buff, Territory_ConvertDateAndTime);
}

static char *gettimedate(int territory, const struct tm *tt, char *buff, int swi)
{
    return getterritorytimeinfo(territory, tt, NULL, buff, swi);
}

static char *gettimezone(int territory, const struct tm *tt, char *buff, int numeric)
{
    _kernel_swi_regs r;

    if (tt->tm_isdst < 0)
        return ""; /* Undetermined */
    r.r[0] = TERRITORY_EXTRACT(territory);
    r.r[1] = TERRITORY_TZ_EXTRACT(territory);
    r.r[4] = (int)TERRITORY_TZ_API_EXT;
    if (_kernel_swi(Territory_ReadTimeZones, &r, &r) != NULL)
        return ""; /* Undetermined */
    if (numeric)
    {
        int offset = tt->tm_isdst ? r.r[3] : r.r[2];

        if (offset < 0)
            offset = -offset, buff[0] = '-';
        else
            buff[0] = '+';
        offset = (offset + 3000) / 6000; /* centiseconds -> minutes */
        sprintf(buff+1, "%.2d%.2d", offset / 60, offset % 60);
    }
    else
    {
        strcpy(buff, tt->tm_isdst ? (char *)r.r[1] : (char *)r.r[0]);
    }
    return buff;
}

static int getdaysinyear(int year)
{
    if (year % 4 != 0) return 365;
    if (year % 100 != 0) return 366;
    if (year % 400 != 0) return 365;
    return 366;
}

static void getiso8601week(char *buff, int spec, int year, int wday, int yday)
{
    int start_of_week, week;
    if (--wday < 0) wday += 7; /* convert from Sun = 0 to Mon = 0 */

    start_of_week = yday - wday; /* day number (-6 to 365) of start of this week */
    do
    {
        week = (start_of_week+7+3) / 7; /* basic week number (0-53) */
        if (week == 0)
        {
            /* This week belongs to last year - go round again */
            start_of_week += getdaysinyear(--year);
        }
        else if (week == 53 && start_of_week >= getdaysinyear(year)-3)
        {
            /* <=3 days of week 53 fall in this year, so we treat it as week 1 of next year */
            week = 1;
            ++year;
        }
    }
    while (week == 0);

    switch (spec)
    {
        case 'g': sprintf(buff, "%.2d", year % 100); break;
        case 'G': sprintf(buff, "%d", year); break;
        case 'V': sprintf(buff, "%.2d", week); break;
    }
}

size_t strftime(char *s, size_t maxsize, const char *fmt, const struct tm *tt)
{
    int p = 0, c;
    char *ss, buff[CDT_BUFFSIZE];
    int territory;

    if (maxsize==0) return 0;
    territory = __locales[N_LC_TIME];
#define push(ch) { s[p++]=(ch); if (p>=maxsize) return 0; }
    for (;;)
    {   switch (c = *fmt++)
        {
    case 0: s[p] = 0;
            return p;
    default:
            push(c);
            continue;
    case '%':
            ss = buff;
            c = *fmt++;
            if (c == 'E' || c == 'O') /* Ignore C99 modifiers */
                c = *fmt++;
            switch (c)
            {
        default:            /* Unknown directive - leave uninterpreted   */
                push('%');  /* NB undefined behaviour according to ANSI  */
                fmt--;
                continue;
        case 'a':
                if (territory)
                    ss = gettimeinfo(territory, tt, "%W3", buff);
                else
                    ss = abbrweek[tt->tm_wday];
                break;
        case 'A':
                if (territory)
                    ss = gettimeinfo(territory, tt, "%WE", buff);
                else
                    ss = fullweek[tt->tm_wday];
                break;
        case 'b': case 'h':
                if (territory)
                    ss = gettimeinfo(territory, tt, "%M3", buff);
                else
                    ss = abbrmonth[tt->tm_mon];
                break;
        case 'B':
                if (territory)
                    ss = gettimeinfo(territory, tt, "%MO", buff);
                else
                    ss = fullmonth[tt->tm_mon];
                break;
        case 'c':
                if (territory)
                    ss = gettimedate(territory, tt, ss, Territory_ConvertStandardDateAndTime);
                else
                    /* Format for "C" locale changed as per C99 "%a %b %e %T %Y" */
                    sprintf(ss, "%s %s %2d %.2d:%.2d:%.2d %d",
                                tt->tm_wday < 7U ? abbrweek[tt->tm_wday] : "???",
                                abbrmonth[tt->tm_mon], tt->tm_mday,
                                tt->tm_hour, tt->tm_min, tt->tm_sec, tt->tm_year + 1900);
                break;
        case 'C':
                sprintf(ss, "%.2d", (tt->tm_year + 1900) / 100);
                break;
        case 'd':
                sprintf(ss, "%.2d", tt->tm_mday);
                break;
        case 'D':
                sprintf(ss, "%.2d/%.2d/%.2d", tt->tm_mon + 1, tt->tm_mday, tt->tm_year % 100);
                break;
        case 'e':
                sprintf(ss, "%2d", tt->tm_mday);
                break;
        case 'F':
                sprintf(ss, "%d-%.2d-%2.d", tt->tm_year + 1900, tt->tm_mon + 1, tt->tm_mday);
                break;
        case 'g': case 'G': case 'V':
                getiso8601week(ss, c, tt->tm_year + 1900, tt->tm_wday, tt->tm_yday);
                break;
        case 'H':
                sprintf(ss, "%.2d", tt->tm_hour);
                break;
        case 'I':
                sprintf(ss, "%.2d", (tt->tm_hour + 11)%12 + 1);
                break;
        case 'j':
                sprintf(ss, "%.3d", tt->tm_yday + 1);
                break;
        case 'm':
                sprintf(ss, "%.2d", tt->tm_mon + 1);
                break;
        case 'M':
                sprintf(ss, "%.2d", tt->tm_min);
                break;
        case 'n':
                strcpy(ss, "\n");
                break;
        case 'p':
/* I am worried here re 12.00 AM/PM and times near same.                 */
                if (territory)
                    ss = gettimeinfo(territory, tt, "%AM", buff);
                else
                    ss = ampmname[tt->tm_hour >= 12];
                break;
        case 'r':
                if (territory)
                    ss = gettimeinfo(territory, tt, "%12:%MI:%SE %AM", buff);
                else
                    sprintf(ss, "%.2d:%.2d:%.2d %s",
                            (tt->tm_hour + 11) % 12 + 1, tt->tm_min, tt->tm_sec,
                            ampmname[tt->tm_hour >= 12]);
                break;
        case 'R':
                sprintf(ss, "%.2d:%.2d", tt->tm_hour, tt->tm_min);
                break;
        case 'S':
                sprintf(ss, "%.2d", tt->tm_sec);
                break;
        case 't':
                strcpy(ss, "\t");
                break;
        case 'T':
                sprintf(ss, "%.2d:%.2d:%.2d", tt->tm_hour, tt->tm_min, tt->tm_sec);
                break;
        case 'u':
                sprintf(ss, "%.1d", (tt->tm_wday + 6)%7 + 1);
                break;
        case 'U':
                sprintf(ss, "%.2d", findweek(tt->tm_yday, 0, tt->tm_wday));
                break;
        case 'w':
                sprintf(ss, "%.1d", tt->tm_wday);
                break;
        case 'W':
                sprintf(ss, "%.2d", findweek(tt->tm_yday, 1, tt->tm_wday));
                break;
        case 'x':
                if (territory)
                    ss = gettimedate(territory, tt, ss, Territory_ConvertStandardDate);
                else
                    /* Format for "C" locale changed as per C99 */
                    sprintf(ss, "%.2d/%.2d/%.2d",
                            tt->tm_mon + 1, tt->tm_mday, tt->tm_year % 100);
                break;
        case 'X':
                if (territory)
                    ss = gettimedate(territory, tt, ss, Territory_ConvertStandardTime);
                else
                    sprintf(ss, "%.2d:%.2d:%.2d",
                            tt->tm_hour, tt->tm_min, tt->tm_sec);
                break;
        case 'y':
                sprintf(ss, "%.2d", tt->tm_year % 100);
                break;
        case 'Y':
                sprintf(ss, "%d", tt->tm_year + 1900);
                break;
        case 'z': case 'Z':
                if (territory)
                    ss = gettimezone(territory, tt, buff, c == 'z');
                else
                    ss = "";
                break;
        case '%':
                push('%');
                continue;
            }
            while ((c = *ss++) != 0) push(c);
            continue;
        }
#undef push
    }
}

#define STATE_DEPENDENT_ENCODINGS 0

int mblen(const char *s, size_t n)
{   if (s == 0) return STATE_DEPENDENT_ENCODINGS;
/* @@@ ANSI ambiguity: if n=0 and *s=0 then return 0 or -1?                 */
/* @@@ LDS: for consistency with mbtowc, return -1                          */
    if (n == 0) return -1;
    if (*s == 0) return 0;
    return 1;
}

int mbtowc(wchar_t *pwc, const char *s, size_t n)
{   if (s == 0) return STATE_DEPENDENT_ENCODINGS;
/* @@@ ANSI ambiguity: if n=0 and *s=0 then return 0 or -1?                 */
/* @@@ LDS At most n chars of s are examined, ergo must return -1.          */
    if (n == 0) return -1;
    else
    {   wchar_t wc = *(unsigned char *)s;
        if (pwc) *pwc = wc;
        return (wc != 0);
    }
}

int wctomb(char *s, wchar_t w)
{   if (s == 0) return STATE_DEPENDENT_ENCODINGS;
/* @@@ ANSI ambiguity: what return (and setting for s) if w == 0?           */
/* @@@ LDS The CVS suggests return #chars stored; I agree this is rational. */
    if ((unsigned)w > (unsigned char)-1) return -1;
    *s = w;
    return 1;
}

size_t mbstowcs(wchar_t *pwcs, const char *s, size_t n)
{
/* @@@ ANSI ambiguity: if n=0 then is *s read?                              */
    size_t r = 0;
    for (; n != 0; n--)
    {   if ((pwcs[r] = ((unsigned char *)s)[r]) == 0) return r;
        r++;
    }
    return r;
}

size_t wcstombs(char *s, const wchar_t *pwcs, size_t n)
{
/* @@@ ANSI ambiguity: if n=0 then is *pwcs read?  Also invalidity check?   */
    size_t r = 0;
    for (; n != 0; n--)
    {   wchar_t w = pwcs[r];
        if ((unsigned)w > (unsigned char)-1) return (size_t)-1;
        if ((s[r] = w) == 0) return r;
        r++;
    }
    return r;
}

/* end of locale.c */
